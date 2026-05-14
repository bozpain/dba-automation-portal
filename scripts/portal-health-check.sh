#!/usr/bin/env bash
set -euo pipefail

failures=0
PORTAL_ROOT="${DBA_PORTAL_ROOT:-/dbaportal}"

check() {
  local label="$1"
  shift
  if "$@" >/tmp/dba-portal-check.out 2>&1; then
    echo "OK   ${label}"
  else
    echo "FAIL ${label}"
    sed 's/^/     /' /tmp/dba-portal-check.out
    failures=$((failures + 1))
  fi
}

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

echo "DBA Automation Portal VM health check"
echo "Date: $(date -Is)"
echo

check "semaphore binary" "${PORTAL_ROOT}/bin/semaphore" version
check "git" git --version
check "python3.12" python3.12 --version
check "ssh client" ssh -V

check_path "Portal root" "${PORTAL_ROOT}"
check_path "Semaphore config" "${PORTAL_ROOT}/semaphore/config.json"
check_path "Semaphore database dir" "${PORTAL_ROOT}/semaphore"
check_path "Portal bare repo" "${PORTAL_ROOT}/automation/git/dba-automation-portal.git"
check_path "Project root" "${PORTAL_ROOT}/automation/projects"

if command -v systemctl >/dev/null 2>&1; then
  check "semaphore service active" systemctl is-active --quiet semaphore
fi

for project in \
  oracle-install-replication-framework \
  oracle-replication-framework \
  oracle-patch-framework
do
  repo="${PORTAL_ROOT}/automation/projects/${project}"
  if [[ -d "${repo}/.git" ]]; then
    commit="$(git -c safe.directory="${repo}" -C "${repo}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "OK   ${project}: ${commit}"
  else
    echo "FAIL ${project}: missing ${repo}"
    failures=$((failures + 1))
  fi
done

echo
if [[ "${failures}" -gt 0 ]]; then
  echo "Health check failed: ${failures} issue(s)"
  exit 1
fi

echo "Health check passed."
