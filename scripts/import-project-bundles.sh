#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/import-project-bundles.sh [--portal-root /dbaportal] [--target-root /dbaportal/automation/projects]
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run as root or with sudo." >&2
    exit 1
  fi
}

default_branch() {
  local repo="$1"
  git -C "${repo}" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "main"
}

main() {
  require_root

  local portal_data_root="/dbaportal"
  local target_root=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --portal-root) portal_data_root="${2:-}"; shift 2 ;;
      --target-root) target_root="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
  done

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local portal_root
  portal_root="$(cd "${script_dir}/.." && pwd)"
  local bundle_dir="${portal_root}/assets/repos"

  if [[ -z "${target_root}" ]]; then
    target_root="${portal_data_root}/automation/projects"
  fi

  install -d -o semaphore -g semaphore -m 0755 "${target_root}"

  shopt -s nullglob
  local bundles=("${bundle_dir}"/*.bundle)
  if [[ "${#bundles[@]}" -eq 0 ]]; then
    echo "ERROR: no git bundles found in ${bundle_dir}." >&2
    exit 1
  fi

  for bundle in "${bundles[@]}"; do
    local name
    name="$(basename "${bundle}" .bundle)"
    local dest="${target_root}/${name}"

    if [[ ! -d "${dest}/.git" ]]; then
      echo "Cloning ${name}"
      git clone "${bundle}" "${dest}"
    else
      echo "Updating ${name}"
      local branch
      branch="$(default_branch "${dest}")"
      git -C "${dest}" fetch "${bundle}" "+refs/heads/*:refs/remotes/bundle/*" "+refs/tags/*:refs/tags/*"
      if git -C "${dest}" rev-parse --verify "refs/remotes/bundle/${branch}" >/dev/null 2>&1; then
        git -C "${dest}" merge --ff-only "refs/remotes/bundle/${branch}" || {
          echo "WARN: ${name} has local changes or diverged history; leaving working tree unchanged."
        }
      fi
    fi

    local snapshot="${bundle_dir}/${name}.worktree.tar.gz"
    if [[ -f "${snapshot}" ]]; then
      echo "Overlaying worktree snapshot for ${name}"
      local preserved_inventory=""
      if [[ -f "${dest}/inventory/targets.csv" ]]; then
        preserved_inventory="$(mktemp)"
        cp "${dest}/inventory/targets.csv" "${preserved_inventory}"
      fi
      tar -xzf "${snapshot}" -C "${dest}"
      if [[ -n "${preserved_inventory}" && -f "${preserved_inventory}" ]]; then
        install -d "${dest}/inventory"
        cp "${preserved_inventory}" "${dest}/inventory/targets.csv"
        rm -f "${preserved_inventory}"
      fi
    fi

    find "${dest}/scripts" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    chown -R semaphore:semaphore "${dest}"
  done

  echo "Project bundles imported to ${target_root}"
}

main "$@"
