<div align="center">

# DBA Automation Portal Deployment Guide

**Production-style runbook for installing, bootstrapping, operating, and maintaining the DBA Automation Portal.**

![Install](https://img.shields.io/badge/Install-Offline%20VM-2563EB?style=for-the-badge)
![Storage](https://img.shields.io/badge/Storage-%2Fdbaportal-7C3AED?style=for-the-badge)
![Semaphore](https://img.shields.io/badge/Semaphore%20UI-Templates-16A34A?style=for-the-badge)
![Oracle](https://img.shields.io/badge/Oracle-Patch%20%2F%20DG%20%2F%20Install-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![Evidence](https://img.shields.io/badge/Evidence-HTML%20Reports-F97316?style=for-the-badge)

</div>

---

## 🧭 Architecture

![DBA Automation Portal Architecture](assets/dba-automation-portal-architecture.svg)

### Runtime Layout

```text
/dbaportal/
  bin/semaphore
  semaphore/
    config.json
    semaphore.sqlite
    tmp/
    logs/
  automation/
    git/dba-automation-portal.git
    git/dba-automation-portal-work/
    projects/
      oracle-install-replication-framework
      oracle-replication-framework
      oracle-patch-framework
  backups/
  exports/
    patch-reports/
```

| Path | Purpose |
| --- | --- |
| `/dbaportal/bin` | Semaphore binary |
| `/dbaportal/semaphore` | Semaphore config, SQLite DB, temporary task workspace |
| `/dbaportal/automation/git` | Local bare repository used by Semaphore |
| `/dbaportal/automation/projects` | Imported automation frameworks |
| `/dbaportal/backups` | Portal backup archives |
| `/dbaportal/exports/patch-reports` | Exported patch evidence |

Systemd unit remains at `/etc/systemd/system/semaphore.service`; all growing data is under `/dbaportal`.

---

## ✅ Prerequisites

### Laptop

| Requirement | Purpose |
| --- | --- |
| Internet access | Download Semaphore UI binary |
| Git | Create repository bundles |
| PowerShell | Run offline asset preparation script |
| `scp` or equivalent | Copy portal package to VM |

### Target VM

| Requirement | Purpose |
| --- | --- |
| Oracle Linux with yum/dnf access | Install OS packages from approved repo |
| `/dbaportal` mountpoint | Controlled growth for portal data |
| Network to Oracle DB targets | Run SSH-based automation |
| Python 3.12 | Run framework scripts |
| SSH client | Connect to target hosts |

Recommended OS packages:

```bash
sudo dnf install -y git openssh-clients python3.12 tar gzip shadow-utils util-linux
```

The installer can install these automatically unless `--skip-dnf` is used.

---

## 📦 1. Prepare Offline Assets From Laptop

From the laptop:

```powershell
cd C:\Users\flatline\Documents\dba-automation-portal
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-offline-assets.ps1
```

For code refresh without re-downloading Semaphore:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-offline-assets.ps1 -SkipSemaphoreDownload
```

Generated artifacts:

```text
assets/semaphore_<version>_linux_amd64.tar.gz
assets/repos/oracle-install-replication-framework.bundle
assets/repos/oracle-install-replication-framework.worktree.tar.gz
assets/repos/oracle-replication-framework.bundle
assets/repos/oracle-replication-framework.worktree.tar.gz
assets/repos/oracle-patch-framework.bundle
assets/repos/oracle-patch-framework.worktree.tar.gz
assets/checksums/*.sha256
```

Copy to VM:

```powershell
scp -r C:\Users\flatline\Documents\dba-automation-portal oracle@<vm>:/tmp/
```

---

## 🏗️ 2. Install Semaphore UI On VM

Prepare `/dbaportal` first if it is a dedicated disk or LVM mount.

```bash
cd /tmp/dba-automation-portal
sudo bash scripts/install-semaphore-offline.sh \
  --admin-password '<change-this-password>'
```

Optional parameters:

| Parameter | Default | Purpose |
| --- | --- | --- |
| `--portal-root` | `/dbaportal` | Data mountpoint |
| `--port` | `3000` | Semaphore UI HTTP port |
| `--admin-login` | `admin` | Initial admin login |
| `--admin-name` | `DBA Admin` | Initial admin display name |
| `--admin-email` | `admin@localhost` | Initial admin email |
| `--admin-password` | lab default | Initial admin password |
| `--skip-dnf` | off | Skip package install |
| `--skip-admin` | off | Skip admin creation |

The installer creates:

```text
/dbaportal/bin/semaphore
/dbaportal/semaphore/config.json
/dbaportal/semaphore/semaphore.sqlite
/dbaportal/automation/projects
/dbaportal/automation/git
/dbaportal/backups
/dbaportal/exports/patch-reports
```

It also writes:

```text
/etc/systemd/system/semaphore.service
```

Service commands:

```bash
sudo systemctl status semaphore
sudo systemctl restart semaphore
sudo journalctl -u semaphore -f
```

Open:

```text
http://<vm-ip>:3000
```

---

## 🗂️ 3. Import Automation Projects

```bash
cd /tmp/dba-automation-portal
sudo bash scripts/import-project-bundles.sh
```

Projects are imported to:

```text
/dbaportal/automation/projects
```

The importer overlays `.worktree.tar.gz` snapshots after bundle clone/fetch. Existing `inventory/targets.csv` on VM is preserved, so hosts added through the portal are not overwritten during code refresh.

---

## 🔗 4. Publish Portal Local Repository

Semaphore runs task scripts from a local bare git repository:

```bash
sudo bash scripts/publish-portal-repo.sh
```

Repository URL:

```text
file:///dbaportal/automation/git/dba-automation-portal.git
```

---

## 🩺 5. Validate Portal Health

```bash
sudo bash scripts/portal-health-check.sh
```

This checks:

| Check | Expected |
| --- | --- |
| Semaphore binary | `/dbaportal/bin/semaphore` |
| Config | `/dbaportal/semaphore/config.json` |
| Database directory | `/dbaportal/semaphore` |
| Portal bare repo | `/dbaportal/automation/git/dba-automation-portal.git` |
| Automation projects | `/dbaportal/automation/projects/*` |
| Service | `semaphore` active |

---

## 🎛️ 6. Bootstrap Semaphore Project

Run after the service is online:

```bash
python3.12 scripts/bootstrap-semaphore-api.py \
  --url http://localhost:3000 \
  --username admin \
  --password '<change-this-password>'
```

Bootstrap creates:

| Resource | Name |
| --- | --- |
| Project | `DBA Automation` |
| Repository | `dba-automation-portal` |
| Key | `None` |
| Inventory | `Local Runner` |
| Environment | `DBA Automation Defaults` |
| Templates | Portal, install/replication, Data Guard, patch operations |

If API bootstrap fails because of a Semaphore UI API change, create resources manually from:

```text
semaphore/catalog.md
```

---

## 🧩 7. Task Template Map

### Portal

| Template | Purpose |
| --- | --- |
| `DBA / 00 Portal Health Check` | Validate local runner and imported projects |

### Install + Replication

| Template | Purpose |
| --- | --- |
| `DBA / 10 Oracle Install Replication` | Run manifest-driven install, auto ASM storage, GI/DB, ADG, broker, and report actions |

### Data Guard

| Template | Purpose |
| --- | --- |
| `DBA / 20 Oracle Data Guard Replication` | Init config, validate, render, setup SSH, staged run |

### Oracle Patch

| Template | Purpose |
| --- | --- |
| `Patch / 00 Health Check` | Runner, manifest, ZIP media, inventory, SSH checks |
| `Patch / 01 Add Host` | Add host to patch inventory with backup and confirmation gate |
| `Patch / 02 Inventory` | View inventory, duplicate hosts, app config drift |
| `Patch / 03 Status` | Show latest patch status and resume hints |
| `Patch / 04 Dry Run Full Pipeline` | Preview full patch flow |
| `Patch / 05 Precheck` | Run real precheck |
| `Patch / 06 Full Patch` | Execute full patch with `CONFIRM_FULL_PATCH=RUN` |
| `Patch / 07 Resume` | Resume from a failed run ID |
| `Patch / 08 List Reports` | List run states, summaries, and report paths |
| `Patch / 09 Export Report` | Export HTML report to `/dbaportal/exports/patch-reports` |
| `Patch / 99 Advanced Phase` | Manual phase runner for DBA-controlled execution |

---

## 🩺 8. Oracle Patch Operator Flow

Recommended production flow:

```text
Health Check -> Add Host dry-run -> Add Host real -> Inventory -> Status
-> Dry Run Full Pipeline -> Precheck -> Full Patch -> List/Export Report
```

Important markers in Semaphore logs:

```text
RUN_ID=<run_id>
REPORT_PATH=<html_report_path>
SUMMARY_PATH=<summary_json_path>
INVENTORY_BACKUP=<backup_csv_path>
```

Guardrails:

| Guardrail | Required value |
| --- | --- |
| Add Host real update | `CONFIRM_ADD_HOST=ADD` |
| Full Patch real execution | `CONFIRM_FULL_PATCH=RUN` |
| Full Patch audit | `CHANGE_ID`, `ENVIRONMENT`, `RUN_REASON` |

Full patch evidence can be exported to:

```text
/dbaportal/exports/patch-reports
```

Detailed daily flow:

```text
docs/patch-operator-flow.md
```

---

## 🔄 9. Code Refresh

From laptop:

```powershell
cd C:\Users\flatline\Documents\dba-automation-portal
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-offline-assets.ps1 -SkipSemaphoreDownload
```

Copy updated `assets/repos/*` to VM, then:

```bash
cd /tmp/dba-automation-portal
sudo bash scripts/import-project-bundles.sh
sudo bash scripts/publish-portal-repo.sh
sudo systemctl restart semaphore
```

If templates changed, run bootstrap again:

```bash
python3.12 scripts/bootstrap-semaphore-api.py \
  --url http://localhost:3000 \
  --username admin \
  --password '<admin-password>'
```

---

## 💾 10. Backup And Restore

Backup:

```bash
sudo bash scripts/backup-portal.sh
```

Default output:

```text
/dbaportal/backups/dba-automation-portal-<timestamp>.tar.gz
```

Restore:

```bash
sudo bash scripts/restore-portal.sh \
  --archive /dbaportal/backups/<backup>.tar.gz
```

Backup includes:

| Included | Path |
| --- | --- |
| Semaphore config and DB | `/dbaportal/semaphore` |
| Local git repo and projects | `/dbaportal/automation` |

---

## 🛡️ 11. Security Notes

| Area | Recommendation |
| --- | --- |
| Admin password | Change immediately after installation |
| Port exposure | Restrict port `3000` to operator network |
| SSH keys | Pre-stage runner SSH keys for non-interactive task execution |
| Full patch | Require `CONFIRM_FULL_PATCH=RUN` and a valid `CHANGE_ID` |
| Backups | Protect `/dbaportal/backups` with restricted permissions |
| Secrets | Do not pass passwords in `EXTRA_ARGS` |

---

## 🧯 12. Troubleshooting

### Semaphore service does not start

```bash
sudo systemctl status semaphore
sudo journalctl -u semaphore -n 100 --no-pager
```

Check:

```text
/dbaportal/semaphore/config.json
/dbaportal/semaphore/semaphore.sqlite
/dbaportal/bin/semaphore
```

### Bootstrap API fails

Use manual catalog:

```text
semaphore/catalog.md
```

Then verify repository URL:

```text
file:///dbaportal/automation/git/dba-automation-portal.git
```

### Patch task cannot find project

Run:

```bash
sudo bash scripts/import-project-bundles.sh
sudo bash scripts/portal-health-check.sh
```

Expected project path:

```text
/dbaportal/automation/projects/oracle-patch-framework
```

### Full patch blocked by confirmation gate

Set:

```text
CONFIRM_FULL_PATCH=RUN
```

### Add Host blocked by confirmation gate

Set:

```text
CONFIRM_ADD_HOST=ADD
```

### Active lock detected

Use:

```text
Patch / 03 Status
Patch / 07 Resume
```

Inspect locks:

```text
/dbaportal/automation/projects/oracle-patch-framework/runtime/locks
```

---

## 📋 13. Production Checklist

| Item | Status |
| --- | --- |
| `/dbaportal` mounted and sized | ☐ |
| Semaphore installed and service active | ☐ |
| Project bundles imported | ☐ |
| Portal local repo published | ☐ |
| Bootstrap completed | ☐ |
| Portal health check passed | ☐ |
| Patch health check passed | ☐ |
| Backup tested | ☐ |
| Operator access validated | ☐ |
| Patch report export tested | ☐ |

