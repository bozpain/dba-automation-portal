#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/restore-portal.sh --archive <backup.tar.gz> [--portal-root /dbaportal]
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

  local archive=""
  local portal_data_root="/dbaportal"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --archive) archive="${2:-}"; shift 2 ;;
      --portal-root) portal_data_root="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
  done

  if [[ -z "${archive}" || ! -f "${archive}" ]]; then
    echo "ERROR: --archive is required and must point to an existing file." >&2
    exit 1
  fi

  systemctl stop semaphore 2>/dev/null || true

  local tmpdir
  tmpdir="$(mktemp -d)"
  tar -xzf "${archive}" -C "${tmpdir}"

  install -d "${portal_data_root}"
  if [[ -d "${tmpdir}/dbaportal/semaphore" ]]; then
    rm -rf "${portal_data_root}/semaphore"
    cp -a "${tmpdir}/dbaportal/semaphore" "${portal_data_root}/"
  fi
  if [[ -d "${tmpdir}/dbaportal/automation" ]]; then
    rm -rf "${portal_data_root}/automation"
    cp -a "${tmpdir}/dbaportal/automation" "${portal_data_root}/"
  fi

  chown -R semaphore:semaphore "${portal_data_root}/semaphore" "${portal_data_root}/automation" 2>/dev/null || true
  chown root:semaphore "${portal_data_root}/semaphore/config.json" 2>/dev/null || true
  chmod 0640 "${portal_data_root}/semaphore/config.json" 2>/dev/null || true

  rm -rf "${tmpdir}"
  systemctl start semaphore 2>/dev/null || true

  echo "Restore completed from ${archive}"
}

main "$@"
