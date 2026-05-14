#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/backup-portal.sh [--portal-root /dbaportal] [--output-dir /dbaportal/backups]
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
  local output_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --portal-root) portal_data_root="${2:-}"; shift 2 ;;
      --output-dir) output_dir="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
  done

  if [[ -z "${output_dir}" ]]; then
    output_dir="${portal_data_root}/backups"
  fi

  local stamp archive tmpdir
  stamp="$(date +%Y%m%d_%H%M%S)"
  archive="${output_dir}/dba-automation-portal-${stamp}.tar.gz"
  tmpdir="$(mktemp -d)"

  install -d -m 0750 "${output_dir}"
  install -d "${tmpdir}/dbaportal"

  cp -a "${portal_data_root}/semaphore" "${tmpdir}/dbaportal/" 2>/dev/null || true
  cp -a "${portal_data_root}/automation" "${tmpdir}/dbaportal/" 2>/dev/null || true

  tar -C "${tmpdir}" -czf "${archive}" .
  rm -rf "${tmpdir}"
  chmod 0600 "${archive}"

  echo "Backup created: ${archive}"
}

main "$@"
