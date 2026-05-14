#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_PATCH_ROOT:-/dbaportal/automation/projects/oracle-patch-framework}"
PORTAL_ROOT="${DBA_PORTAL_ROOT:-/dbaportal}"
RUN_ID="$(get_arg RUN_ID "")"
PATCH_ID="$(get_arg PATCH_ID "")"
OPERATOR="$(get_arg OPERATOR "")"
HOSTS="$(get_arg HOSTS "")"
EXPORT_DIR="$(get_arg EXPORT_DIR "${PORTAL_ROOT}/exports/patch-reports")"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

require_project_root "${PROJECT_ROOT}" "runtime"

"${PYTHON_BIN}" - "${PROJECT_ROOT}" "${EXPORT_DIR}" "${RUN_ID}" "${PATCH_ID}" "${OPERATOR}" "${HOSTS}" <<'PY'
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
export_dir = Path(sys.argv[2])
run_id_filter = sys.argv[3].strip()
patch_id = sys.argv[4].strip()
operator = sys.argv[5].strip()
hosts_filter = {h.strip() for h in sys.argv[6].split(",") if h.strip()}

runs_dir = root / "runtime" / "runs"
reports_dir = root / "runtime" / "reports"

candidate = None
for state_file in runs_dir.glob("*/state.json"):
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    run_id = state.get("run_id") or state_file.parent.name
    if run_id_filter and run_id != run_id_filter:
        continue
    if patch_id and state.get("patch_id") != patch_id:
        continue
    if operator and state.get("operator") != operator:
        continue
    state_hosts = set((state.get("hosts") or {}).keys())
    if hosts_filter and state_hosts != hosts_filter:
        continue
    report = reports_dir / f"{run_id}.html"
    if not report.is_file():
        continue
    item = (state_file.stat().st_mtime, run_id, report, state_file.parent / "summary.json")
    if candidate is None or item[0] > candidate[0]:
        candidate = item

if candidate is None:
    raise SystemExit("ERROR: no matching HTML report found")

_, run_id, report, summary = candidate
export_dir.mkdir(parents=True, exist_ok=True)
target_report = export_dir / report.name
shutil.copy2(report, target_report)
print(f"RUN_ID={run_id}")
print(f"REPORT_PATH={report}")
print(f"EXPORT_PATH={target_report}")

if summary.is_file():
    target_summary = export_dir / summary.name.replace("summary", f"{run_id}.summary")
    shutil.copy2(summary, target_summary)
    print(f"SUMMARY_EXPORT_PATH={target_summary}")
PY
