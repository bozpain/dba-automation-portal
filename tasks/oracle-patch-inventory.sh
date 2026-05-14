#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
parse_survey_args "$@"

PROJECT_ROOT="${ORACLE_PATCH_ROOT:-/dbaportal/automation/projects/oracle-patch-framework}"
APP_NAME="$(get_arg APP_NAME "")"
HOSTS="$(get_arg HOSTS "")"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

require_project_root "${PROJECT_ROOT}" "inventory/targets.csv"

inventory="${PROJECT_ROOT}/inventory/targets.csv"

echo "Oracle Patch inventory"
echo "Inventory: ${inventory}"
echo

"${PYTHON_BIN}" - "${inventory}" "${APP_NAME}" "${HOSTS}" <<'PY'
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

inventory = Path(sys.argv[1])
app_filter = sys.argv[2].strip()
host_filter = {h.strip() for h in sys.argv[3].split(",") if h.strip()}
required = ["host", "app_name", "db_home", "grid_home", "db_user", "grid_user"]

reader = csv.DictReader(inventory.open(newline="", encoding="utf-8"))
if not reader.fieldnames:
    raise SystemExit("ERROR: inventory has no header")
missing = [name for name in required if name not in reader.fieldnames]
if missing:
    raise SystemExit(f"ERROR: missing columns: {', '.join(missing)}")

rows = list(reader)

if app_filter:
    rows = [row for row in rows if row.get("app_name") == app_filter]
if host_filter:
    rows = [row for row in rows if row.get("host") in host_filter]

print(f"Rows: {len(rows)}")
for row in rows:
    print(
        "{host} app={app_name} db_home={db_home} grid_home={grid_home} "
        "db_user={db_user} grid_user={grid_user}".format(**row)
    )

print()
all_rows = list(csv.DictReader(inventory.open(newline="", encoding="utf-8")))
host_counts = Counter(row["host"] for row in all_rows)
duplicates = sorted(host for host, count in host_counts.items() if count > 1)
if duplicates:
    print("DUPLICATE_HOSTS=" + ",".join(duplicates))
else:
    print("DUPLICATE_HOSTS=none")

apps = defaultdict(set)
for row in all_rows:
    key = (row["db_home"], row["grid_home"], row["db_user"], row["grid_user"])
    apps[row["app_name"]].add(key)
drift = sorted(app for app, values in apps.items() if len(values) > 1)
if drift:
    print("APP_CONFIG_DRIFT=" + ",".join(drift))
else:
    print("APP_CONFIG_DRIFT=none")
PY
