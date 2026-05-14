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
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

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

"${PYTHON_BIN}" --version
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
echo "Patch media detail"
set +e
"${PYTHON_BIN}" - "${PROJECT_ROOT}/manifests/${PATCH_ID}.yaml" "${REPO_BASE}/${PATCH_ID}" "${PROJECT_ROOT}/manifests/sql" <<'PY'
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
repo = Path(sys.argv[2])
sql_dir = Path(sys.argv[3])

def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value

data = {}
if manifest.is_file():
    for raw in manifest.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = strip_quotes(value.split("#", 1)[0].strip())

failures = 0
for key in ("opatch_zip", "gi_zip", "dbru_zip", "ojvm_zip"):
    name = data.get(key, "")
    if not name:
        print(f"FAIL {key}: missing in manifest")
        failures += 1
        continue
    path = repo / name
    if path.is_file():
        print(f"OK   {key}: {path}")
    else:
        print(f"FAIL {key}: {path}")
        failures += 1

sql_name = data.get("pre_datapatch_sql", "")
if sql_name:
    path = sql_dir / sql_name
    if path.is_file():
        print(f"OK   pre_datapatch_sql: {path}")
    else:
        print(f"FAIL pre_datapatch_sql: {path}")
        failures += 1
else:
    print("OK   pre_datapatch_sql: not configured")

raise SystemExit(failures)
PY
media_rc=$?
set -e
if [[ "${media_rc}" -ne 0 ]]; then
  failures=$((failures + media_rc))
fi

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
