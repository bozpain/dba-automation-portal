#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_INSTALL_REPLICATION_ROOT:-/dbaportal/automation/projects/oracle-install-replication-framework}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"
CONFIG="$(get_arg CONFIG configs/gcp-single-gi-lab.json)"
MODE="$(get_arg MODE "")"
DRY_RUN="$(get_arg DRY_RUN true)"
EXTRA_ARGS="$(get_arg EXTRA_ARGS "")"

require_project_root "${PROJECT_ROOT}" "main.py"
safe_rel_path "${CONFIG}" "CONFIG"

case "${MODE}" in
  manual|broker)
    ;;
  *)
    echo "ERROR: MODE must be selected in the portal and must be one of: manual, broker." >&2
    exit 1
    ;;
esac

cd "${PROJECT_ROOT}"

run_action() {
  local action="$1"
  local cmd=("${PYTHON_BIN}" "main.py" "${action}" "--config" "${CONFIG}" "--dataguard-mode" "${MODE}")

  if [[ "${DRY_RUN,,}" == "true" ]]; then
    cmd+=("--dry-run")
  fi

  append_extra_args cmd "${EXTRA_ARGS}"
  print_command "${cmd[@]}"
  "${cmd[@]}"
}

run_action configure-dataguard
