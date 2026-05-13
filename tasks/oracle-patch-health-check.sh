#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_PATCH_ROOT:-/dbaportal/automation/projects/oracle-patch-framework}"
PATCH_ID="$(get_arg PATCH_ID 19.30)"
HOSTS="$(get_arg HOSTS "")"
REPO_BASE="${OPF_REPO_BASE:-/u01/oracle-patch/repo}"
SOURCE_BASE="${OPF_SOURCE_BASE:-/u01/sources}"

require_project_root "${PROJECT_ROOT}" "scripts/run_patch.sh"

echo "Oracle Patch portal health check"
echo "Date: $(date -Is)"
echo "Project root: ${PROJECT_ROOT}"
echo "Patch ID: ${PATCH_ID}"
echo

check_path() {
  local label="$1"
  local path="$2"
  if [[ -e "${path}" ]]; then
    echo "OK   ${label}: ${path}"
  else
    echo "FAIL ${label}: ${path}"
    failures=$((failures + 1))
  fi
}

check_writable() {
  local label="$1"
  local path="$2"
  if [[ -d "${path}" && -w "${path}" ]]; then
    echo "OK   ${label} writable: ${path}"
  else
    echo "FAIL ${label} not writable: ${path}"
    failures=$((failures + 1))
  fi
}

failures=0

python3.12 --version
git --version
ssh -V 2>&1 || true
echo

check_path "inventory" "${PROJECT_ROOT}/inventory/targets.csv"
check_path "manifest" "${PROJECT_ROOT}/manifests/${PATCH_ID}.yaml"
check_path "repo base" "${REPO_BASE}"
check_path "patch repo" "${REPO_BASE}/${PATCH_ID}"
check_path "source base" "${SOURCE_BASE}"
mkdir -p "${PROJECT_ROOT}/runtime"
check_writable "runtime" "${PROJECT_ROOT}/runtime"

echo
if [[ -n "${HOSTS}" ]]; then
  IFS=',' read -ra host_array <<< "${HOSTS}"
  echo "Host inventory lookup"
  for raw_host in "${host_array[@]}"; do
    host="$(echo "${raw_host}" | xargs)"
    [[ -n "${host}" ]] || continue
    if awk -F',' -v host="${host}" 'NR > 1 && $1 == host { found = 1 } END { exit found ? 0 : 1 }' "${PROJECT_ROOT}/inventory/targets.csv"; then
      echo "OK   ${host} exists in inventory"
      if bool_arg CHECK_SSH false; then
        if ssh -o BatchMode=yes -o ConnectTimeout=10 "${OPF_SSH_USER:-db.testing}@${host}" hostname >/dev/null 2>&1; then
          echo "OK   ${host} SSH batch mode"
        else
          echo "FAIL ${host} SSH batch mode"
          failures=$((failures + 1))
        fi
      fi
    else
      echo "FAIL ${host} missing from inventory"
      failures=$((failures + 1))
    fi
  done
else
  echo "HOSTS not provided; skipping host-specific checks."
fi

echo
if [[ "${failures}" -gt 0 ]]; then
  echo "Patch health check failed: ${failures} issue(s)"
  exit 1
fi

echo "Patch health check passed."
