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
