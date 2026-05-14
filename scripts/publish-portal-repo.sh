#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/publish-portal-repo.sh [--portal-root /dbaportal] [--bare-path /dbaportal/automation/git/dba-automation-portal.git]
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run as root or with sudo." >&2
    exit 1
  fi
}

main() {
  require_root

  local portal_data_root="/dbaportal"
  local bare_path=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --portal-root) portal_data_root="${2:-}"; shift 2 ;;
      --bare-path) bare_path="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
  done

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local portal_root
  portal_root="$(cd "${script_dir}/.." && pwd)"
  if [[ -z "${bare_path}" ]]; then
    bare_path="${portal_data_root}/automation/git/dba-automation-portal.git"
  fi

  local work_path="${portal_data_root}/automation/git/dba-automation-portal-work"

  git config --global --add safe.directory "${bare_path}" >/dev/null 2>&1 || true
  git config --global --add safe.directory "${work_path}" >/dev/null 2>&1 || true

  install -d -o semaphore -g semaphore -m 0755 "$(dirname "${bare_path}")"
  rm -rf "${work_path}"
  install -d -o semaphore -g semaphore -m 0755 "${work_path}"

  (
    cd "${portal_root}"
    tar \
      --exclude='./.git' \
      --exclude='./assets/semaphore_*' \
      --exclude='./assets/repos/*.bundle' \
      --exclude='./assets/repos/*.worktree.tar.gz' \
      --exclude='./assets/checksums/*.sha256' \
      -cf - .
  ) | tar -xf - -C "${work_path}"

  git -C "${work_path}" init
  git -C "${work_path}" config user.name "DBA Automation Portal"
  git -C "${work_path}" config user.email "dba-automation@localhost"
  git -C "${work_path}" add .
  git -C "${work_path}" commit -m "Publish DBA automation portal"

  if [[ ! -d "${bare_path}" ]]; then
    git clone --bare "${work_path}" "${bare_path}"
  else
    git -C "${work_path}" remote add portal "${bare_path}"
    git -c safe.directory="${bare_path}" -C "${work_path}" push --mirror portal
  fi

  chown -R semaphore:semaphore "${work_path}" "${bare_path}"

  echo "Portal repository published:"
  echo "file://${bare_path}"
}

main "$@"
