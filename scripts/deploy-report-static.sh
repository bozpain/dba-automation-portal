#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-rori_learning@34.170.193.77}"
PORT="${DBA_REPORT_STATIC_PORT:-8080}"
PORTAL_ROOT="${DBA_PORTAL_ROOT:-/dbaportal}"
REPORT_HOST="${DBA_CONTROL_HOST:-localhost}"
SERVICE_NAME="dba-report-static.service"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVICE_FILE="${REPO_ROOT}/config/${SERVICE_NAME}"

if [[ ! -f "${SERVICE_FILE}" ]]; then
  echo "ERROR: service file not found: ${SERVICE_FILE}" >&2
  exit 1
fi

echo "Deploying ${SERVICE_NAME} to ${TARGET}"
echo "Reports root: ${PORTAL_ROOT}/exports"
echo "Report URL base: http://${REPORT_HOST}:${PORT}/install-reports"

ssh "${TARGET}" "sudo install -d -o semaphore -g semaphore -m 0755 '${PORTAL_ROOT}/exports' '${PORTAL_ROOT}/exports/install-reports'"
ssh "${TARGET}" "cat > /tmp/${SERVICE_NAME}" < "${SERVICE_FILE}"
ssh "${TARGET}" "sudo install -o root -g root -m 0644 /tmp/${SERVICE_NAME} /etc/systemd/system/${SERVICE_NAME} && rm -f /tmp/${SERVICE_NAME}"
ssh "${TARGET}" "sudo systemctl daemon-reload && sudo systemctl enable --now ${SERVICE_NAME} && sudo systemctl restart ${SERVICE_NAME}"
ssh "${TARGET}" "sudo systemctl --no-pager --full status ${SERVICE_NAME} | head -25"

echo "Done."
