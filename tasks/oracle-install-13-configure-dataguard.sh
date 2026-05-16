#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_INSTALL_REPLICATION_ROOT:-/dbaportal/automation/projects/oracle-install-replication-framework}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"
CONFIG="$(get_arg CONFIG configs/gcp-single-gi-lab.json)"
MODE="$(get_arg MODE config)"
DRY_RUN="$(get_arg DRY_RUN true)"
EXTRA_ARGS="$(get_arg EXTRA_ARGS "")"

require_project_root "${PROJECT_ROOT}" "main.py"
safe_rel_path "${CONFIG}" "CONFIG"

case "${MODE}" in
  config|active-dataguard|broker)
    ;;
  *)
    echo "ERROR: MODE must be one of: config, active-dataguard, broker." >&2
    exit 1
    ;;
esac

cd "${PROJECT_ROOT}"

if [[ "${MODE}" == "config" ]]; then
  MODE="$("${PYTHON_BIN}" - "${CONFIG}" <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
method = str(config.get("dataguard", {}).get("configuration_method", "")).lower()
print("broker" if method == "broker" else "active-dataguard")
PY
)"
fi

run_action() {
  local action="$1"
  local cmd=("${PYTHON_BIN}" "main.py" "${action}" "--config" "${CONFIG}")

  if [[ "${DRY_RUN,,}" == "true" ]]; then
    cmd+=("--dry-run")
  fi

  append_extra_args cmd "${EXTRA_ARGS}"
  print_command "${cmd[@]}"
  "${cmd[@]}"
}

run_action setup-active-dataguard

if [[ "${MODE}" == "broker" ]]; then
  run_action setup-dataguard-broker
fi
