#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_PATCH_ROOT:-/dbaportal/automation/projects/oracle-patch-framework}"

PHASE="$(get_arg PHASE precheck)"
PATCH_ID="$(get_arg PATCH_ID 19.30)"
HOSTS="$(get_arg HOSTS "")"
OPERATOR="$(get_arg OPERATOR "")"
CHANGE_ID="$(get_arg CHANGE_ID "")"
ENVIRONMENT="$(get_arg ENVIRONMENT "")"
RUN_REASON="$(get_arg RUN_REASON "")"
RESUME_FROM_RUN_ID="$(get_arg RESUME_FROM_RUN_ID "")"
EXTRA_ARGS="$(get_arg EXTRA_ARGS "")"
CONFIRM_FULL_PATCH="$(get_arg CONFIRM_FULL_PATCH "")"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

require_project_root "${PROJECT_ROOT}" "scripts/run_patch.sh"
require_non_empty "${HOSTS}" "HOSTS"
require_non_empty "${OPERATOR}" "OPERATOR"

case "${PHASE}" in
  precheck|execute|apply|ojvm|datapatch|postcheck|full|resume|status)
    ;;
  *)
    echo "ERROR: unsupported PHASE for oracle-patch: ${PHASE}" >&2
    exit 1
    ;;
esac

cd "${PROJECT_ROOT}"

if [[ "${PHASE}" == "full" ]] && ! bool_arg DRY_RUN false && [[ "${CONFIRM_FULL_PATCH}" != "RUN" ]]; then
  echo "ERROR: Full patch execution requires CONFIRM_FULL_PATCH=RUN" >&2
  exit 1
fi

safe_host_name() {
  local value="$1"
  value="${value//\//_}"
  value="${value//\\/_}"
  value="${value//:/_}"
  value="${value// /_}"
  printf '%s' "${value}"
}

lock_is_terminal() {
  local run_id="$1"
  local state_file="${PROJECT_ROOT}/runtime/runs/${run_id}/state.json"
  [[ -f "${state_file}" ]] || return 1
  "${PYTHON_BIN}" - "${state_file}" <<'PY'
import json
import sys
from pathlib import Path

state = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
raise SystemExit(0 if str(state.get("status", "")).upper() in {"SUCCESS", "FAILED", "STOPPED"} else 1)
PY
}

check_active_locks() {
  bool_arg DRY_RUN false && return 0
  [[ "${PHASE}" == "status" ]] && return 0

  local locks_dir="${PROJECT_ROOT}/runtime/locks"
  [[ -d "${locks_dir}" ]] || return 0

  local raw_host host safe lock_file run_id status_line owner_line
  IFS=',' read -ra requested_hosts <<< "${HOSTS}"
  for raw_host in "${requested_hosts[@]}"; do
    host="$(echo "${raw_host}" | xargs)"
    [[ -n "${host}" ]] || continue
    safe="$(safe_host_name "${host}")"
    lock_file="${locks_dir}/host_${safe}.lock"
    [[ -f "${lock_file}" ]] || continue

    run_id="$(awk -F= '$1=="run_id" {print $2}' "${lock_file}" | tail -n 1)"
    if [[ -n "${run_id}" ]] && lock_is_terminal "${run_id}"; then
      echo "WARN: stale terminal lock found for ${host}: ${lock_file}. Framework can reclaim it."
      continue
    fi

    owner_line="$(awk -F= '$1=="owner" {print $2}' "${lock_file}" | tail -n 1)"
    status_line="host=${host} owner=${owner_line:-unknown} run_id=${run_id:-unknown} lock=${lock_file}"
    echo "ERROR: active patch lock detected before task start: ${status_line}" >&2
    exit 1
  done
}

check_active_locks

cmd=("./scripts/run_patch.sh" "${PHASE}" "${PATCH_ID}" "--hosts" "${HOSTS}" "--operator" "${OPERATOR}")

if [[ -n "${CHANGE_ID}" ]]; then
  cmd+=("--change-id" "${CHANGE_ID}")
fi

if [[ -n "${ENVIRONMENT}" ]]; then
  cmd+=("--environment" "${ENVIRONMENT}")
fi

if [[ -n "${RUN_REASON}" ]]; then
  cmd+=("--run-reason" "${RUN_REASON}")
fi

if bool_arg DRY_RUN false; then
  cmd+=("--dry-run")
fi

if bool_arg FORCE_RUN false; then
  cmd+=("--force-run")
fi

if [[ -n "${RESUME_FROM_RUN_ID}" ]]; then
  cmd+=("--resume-from-run-id" "${RESUME_FROM_RUN_ID}")
fi

append_extra_args cmd "${EXTRA_ARGS}"
print_command "${cmd[@]}"
"${cmd[@]}"
