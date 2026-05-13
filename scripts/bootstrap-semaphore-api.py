#!/usr/bin/env python3
"""Bootstrap the DBA Automation project in Semaphore UI.

This script uses only the Python standard library so it can run on the offline
VM after Semaphore is installed. It is intentionally idempotent: existing
resources are reused by name.
"""

from __future__ import annotations

import argparse
import json
import sys
from http.cookiejar import CookieJar
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import HTTPCookieProcessor, Request, build_opener


class ApiError(RuntimeError):
    pass


class SemaphoreApi:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/") + "/"
        self.cookies = CookieJar()
        self.opener = build_opener(HTTPCookieProcessor(self.cookies))
        self.token: str | None = None

    def request(self, method: str, path: str, body: Any | None = None) -> Any:
        url = urljoin(self.base_url, path.lstrip("/"))
        data = None
        headers = {"Accept": "application/json"}
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        req = Request(url, data=data, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=30) as response:
                raw = response.read().decode("utf-8")
                if not raw:
                    return None
                try:
                    return json.loads(raw)
                except json.JSONDecodeError:
                    return raw
        except HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            raise ApiError(f"{method} {path} failed: HTTP {exc.code}: {details}") from exc
        except URLError as exc:
            raise ApiError(f"{method} {path} failed: {exc}") from exc

    def login(self, username: str, password: str) -> None:
        self.request("POST", "/api/auth/login", {"auth": username, "password": password})

    def create_token(self) -> str:
        result = self.request("POST", "/api/user/tokens")
        if not isinstance(result, dict) or not result.get("id"):
            raise ApiError(f"Unexpected token response: {result!r}")
        self.token = str(result["id"])
        return self.token


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def load_catalog(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def first_id(items: Any, name: str) -> int | None:
    if not isinstance(items, list):
        return None
    for item in items:
        if isinstance(item, dict) and item.get("name") == name and item.get("id") is not None:
            return int(item["id"])
    return None


def create_or_get(api: SemaphoreApi, list_path: str, create_path: str, name: str, payload: dict[str, Any]) -> int:
    existing = first_id(api.request("GET", list_path), name)
    if existing is not None:
        print(f"OK existing: {name} (id={existing})")
        return existing

    created = api.request("POST", create_path, payload)
    if isinstance(created, dict) and created.get("id") is not None:
        new_id = int(created["id"])
        print(f"OK created: {name} (id={new_id})")
        return new_id

    existing = first_id(api.request("GET", list_path), name)
    if existing is not None:
        print(f"OK created: {name} (id={existing})")
        return existing

    raise ApiError(f"Could not create/find {name}; response was {created!r}")


def survey_var_payload(item: dict[str, Any]) -> dict[str, Any]:
    payload = {
        "name": item["name"],
        "title": item.get("title", item["name"]),
        "type": item.get("type", "string"),
        "required": bool(item.get("required", False)),
    }
    if item.get("default") is not None:
        payload["default_value"] = item.get("default")
        payload["default"] = item.get("default")
    if item.get("values"):
        payload["values"] = item["values"]
        payload["enum_values"] = {value.strip(): value.strip() for value in item["values"].split(",") if value.strip()}
    return payload


def bootstrap(api: SemaphoreApi, catalog: dict[str, Any]) -> None:
    project_cfg = catalog["project"]
    project_id = create_or_get(
        api,
        "/api/projects",
        "/api/projects",
        project_cfg["name"],
        {
            "name": project_cfg["name"],
            "alert": bool(project_cfg.get("alert", False)),
            "max_parallel_tasks": int(project_cfg.get("max_parallel_tasks", 1)),
        },
    )

    key_cfg = catalog["key"]
    key_id = create_or_get(
        api,
        f"/api/project/{project_id}/keys",
        f"/api/project/{project_id}/keys",
        key_cfg["name"],
        {
            "name": key_cfg["name"],
            "type": "none",
            "project_id": project_id,
        },
    )

    repo_cfg = catalog["repository"]
    repo_id = create_or_get(
        api,
        f"/api/project/{project_id}/repositories",
        f"/api/project/{project_id}/repositories",
        repo_cfg["name"],
        {
            "name": repo_cfg["name"],
            "project_id": project_id,
            "git_url": repo_cfg["url"],
            "url": repo_cfg["url"],
            "branch": repo_cfg.get("branch", ""),
            "ssh_key_id": key_id,
        },
    )

    inv_cfg = catalog["inventory"]
    inventory_id = create_or_get(
        api,
        f"/api/project/{project_id}/inventory",
        f"/api/project/{project_id}/inventory",
        inv_cfg["name"],
        {
            "name": inv_cfg["name"],
            "project_id": project_id,
            "type": "static",
            "inventory": inv_cfg["inventory"],
            "ssh_key_id": key_id,
        },
    )

    env_cfg = catalog["environment"]
    environment_id = create_or_get(
        api,
        f"/api/project/{project_id}/environment",
        f"/api/project/{project_id}/environment",
        env_cfg["name"],
        {
            "name": env_cfg["name"],
            "project_id": project_id,
            "json": json.dumps(env_cfg.get("env", {}), sort_keys=True),
            "env": json.dumps(env_cfg.get("env", {}), sort_keys=True),
            "secrets": "[]",
        },
    )

    for template in catalog["templates"]:
        payload = {
            "name": template["name"],
            "description": template.get("description", ""),
            "project_id": project_id,
            "repository_id": repo_id,
            "inventory_id": inventory_id,
            "environment_id": environment_id,
            "app": template.get("app", "bash"),
            "playbook": template["script"],
            "type": "task",
            "arguments": template.get("arguments", []),
            "allow_override_args_in_task": bool(template.get("allow_override_args_in_task", False)),
            "survey_vars": [survey_var_payload(v) for v in template.get("survey_vars", [])],
        }
        create_or_get(
            api,
            f"/api/project/{project_id}/templates",
            f"/api/project/{project_id}/templates",
            template["name"],
            payload,
        )

    print()
    print("Bootstrap completed.")
    print(f"Project: {project_cfg['name']} (id={project_id})")
    print(f"Repository: {repo_cfg['url']}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bootstrap DBA Automation in Semaphore UI")
    parser.add_argument("--url", default="http://localhost:3000", help="Semaphore base URL")
    parser.add_argument("--username", default="admin", help="Semaphore admin login")
    parser.add_argument("--password", required=True, help="Semaphore admin password")
    parser.add_argument(
        "--catalog",
        default=str(repo_root() / "semaphore" / "bootstrap.json"),
        help="Bootstrap catalog JSON",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    api = SemaphoreApi(args.url)
    try:
        api.login(args.username, args.password)
        api.create_token()
        bootstrap(api, load_catalog(Path(args.catalog)))
    except ApiError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        print("Tip: if this is a newer Semaphore UI API change, create the catalog manually from semaphore/catalog.md.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
