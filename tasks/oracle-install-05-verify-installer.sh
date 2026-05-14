#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/oracle-install-replication.sh" "ACTION=verify-installer" "DRY_RUN=true" "$@"