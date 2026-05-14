#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_REPLICATION_ROOT:-/dbaportal/automation/projects/oracle-replication-framework}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"
CONFIG="$(get_arg CONFIG configs/profiles/single-gi-physical.json)"

require_project_root "${PROJECT_ROOT}" "scripts/dgctl.py"
safe_rel_path "${CONFIG}" "CONFIG"

cd "${PROJECT_ROOT}"

echo "== Oracle Replication Framework Health Check =="
echo "Project root : ${PROJECT_ROOT}"
echo "Config       : ${CONFIG}"
echo

echo "-- Runtime --"
print_command "${PYTHON_BIN}" --version
"${PYTHON_BIN}" --version

for required_bin in ssh scp bash find mktemp; do
  if command -v "${required_bin}" >/dev/null 2>&1; then
    echo "OK ${required_bin}: $(command -v "${required_bin}")"
  else
    echo "ERROR: required binary not found: ${required_bin}" >&2
    exit 1
  fi
done

for optional_bin in ssh-copy-id sshpass; do
  if command -v "${optional_bin}" >/dev/null 2>&1; then
    echo "OK ${optional_bin}: $(command -v "${optional_bin}")"
  else
    echo "WARN optional binary not found: ${optional_bin}"
  fi
done

echo
echo "-- Config structure --"
"${PYTHON_BIN}" - "${CONFIG}" <<'PY'
import importlib.util
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
module_path = Path("scripts/dgctl.py")
spec = importlib.util.spec_from_file_location("dgctl", module_path)
if spec is None or spec.loader is None:
    raise SystemExit(f"ERROR: cannot import {module_path}")
dgctl = importlib.util.module_from_spec(spec)
sys.modules["dgctl"] = dgctl
spec.loader.exec_module(dgctl)

cfg = dgctl.load_config(config_path)
print(f"OK config can be loaded: {config_path}")
print(f"Primary: {cfg['primary']['db_unique_name']} -> Standby: {cfg['standby']['db_unique_name']}")
print(f"Actions: {len(dgctl.actions(cfg))}")

issues = dgctl.collect_config_issues(cfg)
if issues:
    print("WARN config review items:")
    for issue in issues:
        print(f"- {issue}")
PY

echo
echo "-- Render and syntax --"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dg-health.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

print_command "${PYTHON_BIN}" scripts/dgctl.py render --config "${CONFIG}" --render-dir "${tmp_dir}/rendered"
"${PYTHON_BIN}" scripts/dgctl.py render --config "${CONFIG}" --render-dir "${tmp_dir}/rendered"

syntax_count=0
while IFS= read -r -d '' script_path; do
  bash -n "${script_path}"
  syntax_count=$((syntax_count + 1))
done < <(find "${tmp_dir}/rendered" -type f -name '*.sh' -print0)
echo "OK rendered shell syntax: ${syntax_count} scripts"

echo
echo "Health check completed. Use 02 Validate Config for strict target validation."
