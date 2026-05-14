#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/oracle-install-replication.sh" "ACTION=install-db-software" "DRY_RUN=true" "$@"