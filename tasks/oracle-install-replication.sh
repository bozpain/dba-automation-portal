#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_INSTALL_REPLICATION_ROOT:-/dbaportal/automation/projects/oracle-install-replication-framework}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"
export ORACLE_AUTO_REPORT_PUBLISH_PATH="${ORACLE_AUTO_REPORT_PUBLISH_PATH:-${DBA_PORTAL_ROOT:-/dbaportal}/exports/install-reports}"
export ORACLE_AUTO_REPORT_URL_BASE="${ORACLE_AUTO_REPORT_URL_BASE:-http://${DBA_CONTROL_HOST:-localhost}:8080/install-reports}"

ACTION="$(get_arg ACTION validate-config)"
CONFIG="$(get_arg CONFIG configs/gcp-single-gi-lab.json)"
DRY_RUN="$(get_arg DRY_RUN false)"
FROM_PHASE="$(get_arg FROM_PHASE "")"
TO_PHASE="$(get_arg TO_PHASE "")"
EXTRA_ARGS="$(get_arg EXTRA_ARGS "")"
ASM_STORAGE_MODE="$(get_arg ASM_STORAGE_MODE "")"
DATAGUARD_MODE="$(get_arg DATAGUARD_MODE "")"

require_project_root "${PROJECT_ROOT}" "main.py"
safe_rel_path "${CONFIG}" "CONFIG"

case "${ACTION}" in
  validate-config|doctor|inventory|precheck|full|resume|prepare-os|verify-installer|prepare-storage-rules|prepare-storage|install-grid|configure-asm-storage|install-db-software|update-opatch|analyze-patch|apply-grid-patch|apply-db-patch|apply-ojvm-patch|datapatch|patch-inventory|apply-patch|create-database|configure-dataguard|validate-deployment|generate-plan|generate-report|switchover|failover|collect-diagnostics|cleanup-lab|rollback-framework)
    ;;
  *)
    echo "ERROR: unsupported ACTION for oracle-install-replication: ${ACTION}" >&2
    exit 1
    ;;
esac

if [[ -n "${DATAGUARD_MODE}" ]]; then
  case "${DATAGUARD_MODE}" in
    manual|broker)
      ;;
    *)
      echo "ERROR: unsupported DATAGUARD_MODE: ${DATAGUARD_MODE}" >&2
      exit 1
      ;;
  esac
fi

if [[ -n "${ASM_STORAGE_MODE}" ]]; then
  case "${ASM_STORAGE_MODE}" in
    raw|asmlibv3|afd)
      ;;
    *)
      echo "ERROR: unsupported ASM_STORAGE_MODE: ${ASM_STORAGE_MODE}" >&2
      exit 1
      ;;
  esac
fi

cd "${PROJECT_ROOT}"

cmd=("${PYTHON_BIN}" "main.py" "${ACTION}" "--config" "${CONFIG}")
if [[ -n "${ASM_STORAGE_MODE}" ]]; then
  cmd+=("--asm-storage-mode" "${ASM_STORAGE_MODE}")
fi

if [[ -n "${DATAGUARD_MODE}" ]]; then
  cmd+=("--dataguard-mode" "${DATAGUARD_MODE}")
fi

case "${ACTION}" in
  full|resume|prepare-storage-rules|prepare-storage|configure-asm-storage)
    cmd+=("--allow-storage-changes")
    ;;
esac

case "${ACTION}" in
  full|resume|update-opatch|analyze-patch|apply-grid-patch|apply-db-patch|apply-ojvm-patch|datapatch|apply-patch)
    cmd+=("--allow-patch-apply")
    ;;
esac

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
