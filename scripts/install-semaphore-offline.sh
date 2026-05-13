#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/install-semaphore-offline.sh [options]

Options:
  --admin-login <login>       Default: admin
  --admin-name <name>         Default: DBA Admin
  --admin-email <email>       Default: admin@localhost
  --admin-password <password> Default: ChangeMe_OnlyForLab_2026!
  --port <port>               Default: 3000
  --portal-root <path>        Default: /dbaportal
  --skip-dnf                  Do not install OS packages
  --skip-admin                Do not create/update admin user
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run as root or with sudo." >&2
    exit 1
  fi
}

rand_b64() {
  head -c32 /dev/urandom | base64
}

run_as_semaphore() {
  local portal_root="$1"
  shift
  runuser -u semaphore -- env HOME="${portal_root}/home/semaphore" "$@"
}

main() {
  require_root

  local admin_login="admin"
  local admin_name="DBA Admin"
  local admin_email="admin@localhost"
  local admin_password="ChangeMe_OnlyForLab_2026!"
  local port="3000"
  local portal_data_root="/dbaportal"
  local skip_dnf="false"
  local skip_admin="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --admin-login) admin_login="${2:-}"; shift 2 ;;
      --admin-name) admin_name="${2:-}"; shift 2 ;;
      --admin-email) admin_email="${2:-}"; shift 2 ;;
      --admin-password) admin_password="${2:-}"; shift 2 ;;
      --port) port="${2:-}"; shift 2 ;;
      --portal-root) portal_data_root="${2:-}"; shift 2 ;;
      --skip-dnf) skip_dnf="true"; shift ;;
      --skip-admin) skip_admin="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
  done

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local portal_root
  portal_root="$(cd "${script_dir}/.." && pwd)"

  local asset
  asset="$(find "${portal_root}/assets" -maxdepth 1 -type f -name 'semaphore_*_linux_amd64.tar.gz' | sort -V | tail -n 1 || true)"
  if [[ -z "${asset}" ]]; then
    echo "ERROR: Semaphore binary archive not found in ${portal_root}/assets." >&2
    echo "Run scripts/prepare-offline-assets.ps1 on the laptop first." >&2
    exit 1
  fi

  if [[ "${skip_dnf}" != "true" ]]; then
    dnf install -y git openssh-clients python3.12 tar gzip shadow-utils util-linux
  fi

  if ! id semaphore >/dev/null 2>&1; then
    useradd --system --home-dir "${portal_data_root}/home/semaphore" --shell /sbin/nologin semaphore
  fi

  install -d -o root -g root -m 0755 "${portal_data_root}"
  install -d -o root -g root -m 0755 "${portal_data_root}/bin"
  install -d -o semaphore -g semaphore -m 0750 \
    "${portal_data_root}/home/semaphore" \
    "${portal_data_root}/semaphore" \
    "${portal_data_root}/semaphore/tmp" \
    "${portal_data_root}/semaphore/logs" \
    "${portal_data_root}/tmp"
  install -d -o semaphore -g semaphore -m 0755 \
    "${portal_data_root}/automation" \
    "${portal_data_root}/automation/projects" \
    "${portal_data_root}/automation/git" \
    "${portal_data_root}/backups" \
    "${portal_data_root}/exports" \
    "${portal_data_root}/exports/patch-reports"

  local tmpdir
  tmpdir="$(mktemp -d)"
  tar -xzf "${asset}" -C "${tmpdir}"
  if [[ ! -f "${tmpdir}/semaphore" ]]; then
    echo "ERROR: archive did not contain expected semaphore binary." >&2
    exit 1
  fi
  install -o root -g root -m 0755 "${tmpdir}/semaphore" "${portal_data_root}/bin/semaphore"
  ln -sfn "${portal_data_root}/bin/semaphore" /usr/local/bin/semaphore
  rm -rf "${tmpdir}"

  local access_key cookie_hash cookie_encryption
  access_key="$(rand_b64)"
  cookie_hash="$(rand_b64)"
  cookie_encryption="$(rand_b64)"

  cat > "${portal_data_root}/semaphore/config.json" <<EOF
{
  "dialect": "sqlite",
  "sqlite": {
    "host": "${portal_data_root}/semaphore/semaphore.sqlite"
  },
  "port": "${port}",
  "interface": "",
  "tmp_path": "${portal_data_root}/semaphore/tmp",
  "web_host": "",
  "cookie_hash": "${cookie_hash}",
  "cookie_encryption": "${cookie_encryption}",
  "access_key_encryption": "${access_key}",
  "max_parallel_tasks": 1,
  "max_tasks_per_template": 100,
  "schedule": {
    "timezone": "Asia/Jakarta"
  }
}
EOF
  chown root:semaphore "${portal_data_root}/semaphore/config.json"
  chmod 0640 "${portal_data_root}/semaphore/config.json"

  sed "s#__DBA_PORTAL_ROOT__#${portal_data_root}#g" "${portal_root}/config/semaphore.service" \
    > /etc/systemd/system/semaphore.service
  chmod 0644 /etc/systemd/system/semaphore.service
  systemctl daemon-reload

  set +e
  run_as_semaphore "${portal_data_root}" "${portal_data_root}/bin/semaphore" migrate --config "${portal_data_root}/semaphore/config.json"
  local migrate_rc=$?
  set -e
  if [[ "${migrate_rc}" -ne 0 ]]; then
    echo "WARN: 'semaphore migrate' returned ${migrate_rc}. Continuing; newer versions may migrate on server startup."
  fi

  if [[ "${skip_admin}" != "true" ]]; then
    set +e
    run_as_semaphore "${portal_data_root}" "${portal_data_root}/bin/semaphore" user add \
      --admin \
      --login "${admin_login}" \
      --name "${admin_name}" \
      --email "${admin_email}" \
      --password "${admin_password}" \
      --config "${portal_data_root}/semaphore/config.json"
    local user_rc=$?
    set -e
    if [[ "${user_rc}" -ne 0 ]]; then
      echo "WARN: admin user creation returned ${user_rc}. If the user already exists, this is safe to ignore."
    fi
  fi

  systemctl enable --now semaphore
  systemctl --no-pager status semaphore || true

  echo
  echo "Semaphore UI is installed."
  echo "URL: http://<vm-ip>:${port}"
  echo "Admin login: ${admin_login}"
  echo "Portal root: ${portal_data_root}"
  echo "Config: ${portal_data_root}/semaphore/config.json"
}

main "$@"
