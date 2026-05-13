# Offline VM Runbook

## 1. Prepare From Laptop

```powershell
cd C:\Users\flatline\Documents\dba-automation-portal
.\scripts\prepare-offline-assets.ps1
```

If script execution is blocked:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-offline-assets.ps1
```

Artifacts produced:

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

## 2. Copy To VM

```powershell
scp -r C:\Users\flatline\Documents\dba-automation-portal oracle@<vm>:/tmp/
```

## 3. Install Semaphore UI

Prepare `/dbaportal` as a dedicated mountpoint first if the VM has a separate disk/LV for the portal.

```bash
cd /tmp/dba-automation-portal
sudo bash scripts/install-semaphore-offline.sh \
  --admin-password '<change-this-password>'
```

The installer uses SQLite at:

```text
/dbaportal/semaphore/semaphore.sqlite
```

All growing portal data is kept under `/dbaportal`.

## 4. Import Automation Projects

```bash
sudo bash scripts/import-project-bundles.sh
```

Projects are imported to:

```text
/dbaportal/automation/projects
```

## 5. Publish Portal Local Git Repository

```bash
sudo bash scripts/publish-portal-repo.sh
```

Repository URL for Semaphore UI:

```text
file:///dbaportal/automation/git/dba-automation-portal.git
```

## 6. Health Check

```bash
sudo bash scripts/portal-health-check.sh
```

## 7. Bootstrap Semaphore Templates

```bash
python3.12 scripts/bootstrap-semaphore-api.py \
  --url http://localhost:3000 \
  --username admin \
  --password '<change-this-password>'
```

This creates the `DBA Automation` project, local repository, local inventory, default environment, and DBA task templates.

If the API bootstrap fails because of a Semaphore UI API change, create the same resources manually from:

```text
semaphore/catalog.md
```

## 8. Create Semaphore Templates Manually

Open:

```text
http://<vm-ip>:3000
```

Follow:

```text
semaphore/catalog.md
```

## 9. Backup

```bash
sudo bash scripts/backup-portal.sh
```

Restore:

```bash
sudo bash scripts/restore-portal.sh --archive /dbaportal/backups/<backup>.tar.gz
```

## 10. Update Code Later

From laptop:

```powershell
.\scripts\prepare-offline-assets.ps1 -SkipSemaphoreDownload
```

Copy the new `.bundle` files to VM, then:

```bash
cd /tmp/dba-automation-portal
sudo bash scripts/import-project-bundles.sh
sudo bash scripts/publish-portal-repo.sh
```

`import-project-bundles.sh` keeps an existing `inventory/targets.csv` on the VM, so hosts added from the portal are not overwritten during code refresh.
