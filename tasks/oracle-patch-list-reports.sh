#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_PATCH_ROOT:-/dbaportal/automation/projects/oracle-patch-framework}"
PATCH_ID="$(get_arg PATCH_ID "")"
OPERATOR="$(get_arg OPERATOR "")"
HOSTS="$(get_arg HOSTS "")"
LIMIT="$(get_arg LIMIT 20)"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

require_project_root "${PROJECT_ROOT}" "runtime"

"${PYTHON_BIN}" - "${PROJECT_ROOT}" "${PATCH_ID}" "${OPERATOR}" "${HOSTS}" "${LIMIT}" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
patch_id = sys.argv[2].strip()
operator = sys.argv[3].strip()
hosts_filter = {h.strip() for h in sys.argv[4].split(",") if h.strip()}
limit = int(sys.argv[5] or "20")

runs_dir = root / "runtime" / "runs"
reports_dir = root / "runtime" / "reports"

items = []
for state_file in runs_dir.glob("*/state.json"):
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    if patch_id and state.get("patch_id") != patch_id:
        continue
    if operator and state.get("operator") != operator:
        continue
    state_hosts = set((state.get("hosts") or {}).keys())
    if hosts_filter and state_hosts != hosts_filter:
        continue
    run_id = state.get("run_id") or state_file.parent.name
    report = reports_dir / f"{run_id}.html"
    summary = state_file.parent / "summary.json"
    items.append(
        {
            "mtime": state_file.stat().st_mtime,
            "run_id": run_id,
            "phase": state.get("phase"),
            "status": state.get("status"),
            "patch_id": state.get("patch_id"),
            "operator": state.get("operator"),
            "hosts": ",".join(sorted(state_hosts)),
            "report": str(report) if report.is_file() else "-",
            "summary": str(summary) if summary.is_file() else "-",
            "error": state.get("error_summary") or "-",
        }
    )

items.sort(key=lambda item: item["mtime"], reverse=True)
if not items:
    print("No reports/run states found for the selected filters.")
    raise SystemExit(0)

for item in items[:limit]:
    print(
        "RUN_ID={run_id} STATUS={status} PHASE={phase} PATCH_ID={patch_id} OPERATOR={operator}".format(**item)
    )
    print(f"  HOSTS={item['hosts']}")
    print(f"  REPORT_PATH={item['report']}")
    print(f"  SUMMARY_PATH={item['summary']}")
    if item["error"] != "-":
        print(f"  ERROR={item['error']}")
PY
