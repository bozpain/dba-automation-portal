#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_INSTALL_REPLICATION_ROOT:-/dbaportal/automation/projects/oracle-install-replication-framework}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

ACTION="$(get_arg ACTION validate-config)"
CONFIG="$(get_arg CONFIG configs/gcp-single-gi-lab.json)"
DRY_RUN="$(get_arg DRY_RUN false)"
FROM_PHASE="$(get_arg FROM_PHASE "")"
TO_PHASE="$(get_arg TO_PHASE "")"
EXTRA_ARGS="$(get_arg EXTRA_ARGS "")"

require_project_root "${PROJECT_ROOT}" "main.py"
safe_rel_path "${CONFIG}" "CONFIG"

case "${ACTION}" in
  validate-config|doctor|inventory|precheck|full|resume|prepare-target-secrets|prepare-os|verify-installer|prepare-storage-rules|install-grid|configure-asm-storage|install-db-software|update-opatch|analyze-patch|apply-grid-patch|apply-db-patch|apply-ojvm-patch|datapatch|patch-inventory|create-database|setup-active-dataguard|setup-dataguard-broker|validate-deployment|generate-plan|generate-report|switchover|failover|collect-diagnostics|cleanup-lab|rollback-framework)
    ;;
  *)
    echo "ERROR: unsupported ACTION for oracle-install-replication: ${ACTION}" >&2
    exit 1
    ;;
esac

cd "${PROJECT_ROOT}"

cmd=("${PYTHON_BIN}" "main.py" "${ACTION}" "--config" "${CONFIG}")

if [[ "${DRY_RUN,,}" == "true" ]]; then
  case "${ACTION}" in
    validate-config|doctor|generate-plan|generate-report)
      ;;
    *)
      cmd+=("--dry-run")
      ;;
  esac
fi

if [[ -n "${FROM_PHASE}" ]]; then
  cmd+=("--from-phase" "${FROM_PHASE}")
fi

if [[ -n "${TO_PHASE}" ]]; then
  cmd+=("--to-phase" "${TO_PHASE}")
fi

append_extra_args cmd "${EXTRA_ARGS}"
print_command "${cmd[@]}"
"${cmd[@]}"
