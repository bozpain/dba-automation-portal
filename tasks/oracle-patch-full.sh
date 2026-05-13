#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

CONFIRM_FULL_PATCH="$(get_arg CONFIRM_FULL_PATCH "")"
if [[ "${CONFIRM_FULL_PATCH}" != "RUN" ]]; then
  echo "ERROR: Full Patch requires CONFIRM_FULL_PATCH=RUN" >&2
  exit 1
fi

exec "${SCRIPT_DIR}/oracle-patch.sh" PHASE=full DRY_RUN=false "$@"
