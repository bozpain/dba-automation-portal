#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_PATCH_ROOT:-/dbaportal/automation/projects/oracle-patch-framework}"

HOSTS="$(get_arg HOSTS "")"
APP_NAME="$(get_arg APP_NAME "")"
DB_HOME="$(get_arg DB_HOME "")"
GRID_HOME="$(get_arg GRID_HOME "")"
DB_USER="$(get_arg DB_USER "oracle")"
GRID_USER="$(get_arg GRID_USER "")"

require_project_root "${PROJECT_ROOT}" "scripts/add_host.sh"
require_non_empty "${HOSTS}" "HOSTS"
require_non_empty "${APP_NAME}" "APP_NAME"
require_non_empty "${DB_HOME}" "DB_HOME"
require_non_empty "${DB_USER}" "DB_USER"

cd "${PROJECT_ROOT}"

cmd=(
  "./scripts/add_host.sh"
  "--hosts" "${HOSTS}"
  "--app-name" "${APP_NAME}"
  "--db-home" "${DB_HOME}"
  "--db-user" "${DB_USER}"
)

if [[ -n "${GRID_HOME}" ]]; then
  cmd+=("--grid-home" "${GRID_HOME}")
fi

if [[ -n "${GRID_USER}" ]]; then
  cmd+=("--grid-user" "${GRID_USER}")
fi

if bool_arg ALLOW_EXISTING_APP false; then
  cmd+=("--allow-existing-app")
fi

if bool_arg ALLOW_APP_CONFIG_DRIFT false; then
  cmd+=("--allow-app-config-drift")
fi

if bool_arg DRY_RUN true; then
  cmd+=("--dry-run")
fi

if bool_arg SKIP_SSH_COPY_ID true; then
  cmd+=("--skip-ssh-copy-id")
fi

print_command "${cmd[@]}"
"${cmd[@]}"
