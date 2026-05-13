#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_REPLICATION_ROOT:-/dbaportal/automation/projects/oracle-replication-framework}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

ACTION="$(get_arg ACTION validate-config)"
CONFIG="$(get_arg CONFIG configs/profiles/rac-2node-broker.json)"
PROFILE="$(get_arg PROFILE rac-2node-broker)"
OUTPUT_CONFIG="$(get_arg OUTPUT_CONFIG configs/my-dg.json)"
RENDER_DIR="$(get_arg RENDER_DIR rendered/my-dg)"
FROM_STAGE="$(get_arg FROM_STAGE "")"
TO_STAGE="$(get_arg TO_STAGE "")"
EXTRA_ARGS="$(get_arg EXTRA_ARGS "")"

require_project_root "${PROJECT_ROOT}" "scripts/dgctl.py"

case "${ACTION}" in
  init-config|validate-config|setup-ssh|plan|render|run)
    ;;
  *)
    echo "ERROR: unsupported ACTION for oracle-replication: ${ACTION}" >&2
    exit 1
    ;;
esac

cd "${PROJECT_ROOT}"

case "${ACTION}" in
  init-config)
    safe_rel_path "${OUTPUT_CONFIG}" "OUTPUT_CONFIG"
    cmd=("${PYTHON_BIN}" "scripts/dgctl.py" "init-config" "--profile" "${PROFILE}" "--output" "${OUTPUT_CONFIG}")
    ;;
  render)
    safe_rel_path "${CONFIG}" "CONFIG"
    safe_rel_path "${RENDER_DIR}" "RENDER_DIR"
    cmd=("${PYTHON_BIN}" "scripts/dgctl.py" "render" "--config" "${CONFIG}" "--render-dir" "${RENDER_DIR}")
    ;;
  *)
    safe_rel_path "${CONFIG}" "CONFIG"
    cmd=("${PYTHON_BIN}" "scripts/dgctl.py" "${ACTION}" "--config" "${CONFIG}")
    ;;
esac

if bool_arg DRY_RUN false; then
  case "${ACTION}" in
    setup-ssh|run)
      cmd+=("--dry-run")
      ;;
  esac
fi

if bool_arg EXECUTE false; then
  case "${ACTION}" in
    setup-ssh|run)
      cmd+=("--execute")
      ;;
  esac
fi

if bool_arg YES false; then
  case "${ACTION}" in
    setup-ssh|run)
      cmd+=("--yes")
      ;;
  esac
fi

if [[ "${ACTION}" == "run" ]]; then
  if [[ -n "${FROM_STAGE}" ]]; then
    cmd+=("--from-stage" "${FROM_STAGE}")
  fi
  if [[ -n "${TO_STAGE}" ]]; then
    cmd+=("--to-stage" "${TO_STAGE}")
  fi
fi

append_extra_args cmd "${EXTRA_ARGS}"
print_command "${cmd[@]}"
"${cmd[@]}"
