#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "DBA Automation Portal health check"
echo "Date: $(date -Is)"
echo "User: $(id)"
echo "Task directory: ${SCRIPT_DIR}"
echo

python3.12 --version 2>/dev/null || python3 --version 2>/dev/null || true
git --version
ssh -V 2>&1 || true
echo

PROJECT_BASE="${DBA_AUTOMATION_PROJECT_BASE:-/dbaportal/automation/projects}"
for project in \
  oracle-install-replication-framework \
  oracle-replication-framework \
  oracle-patch-framework
do
  path="${PROJECT_BASE}/${project}"
  if [[ -d "${path}/.git" ]]; then
    branch="$(git -C "${path}" symbolic-ref --quiet --short HEAD 2>/dev/null || echo detached)"
    commit="$(git -C "${path}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "OK ${project}: ${branch} ${commit}"
  else
    echo "MISSING ${project}: ${path}"
  fi
done
