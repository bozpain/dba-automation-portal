# DBA Automation Portal

Portal operasional untuk mengonsolidasikan tiga framework DBA automation ke Semaphore UI:

- `oracle-install-replication-framework`
- `oracle-replication-framework`
- `oracle-patch-framework`

Desain ini dibuat untuk kondisi target VM tidak punya internet umum. Semua artifact yang butuh internet diambil dari laptop, lalu dipindahkan ke VM. VM cukup memakai repo Oracle/Yum untuk paket OS seperti `git`, `python3.12`, dan `openssh-clients`.

## Architecture

```text
Laptop with internet
  |
  | prepare offline assets + git bundles
  v
Target VM
  /dbaportal/
    bin/semaphore
    semaphore/config.json
    semaphore/semaphore.sqlite
    semaphore/tmp/
    automation/git/dba-automation-portal.git
    automation/projects/
      oracle-install-replication-framework
      oracle-replication-framework
      oracle-patch-framework
    backups/
```

Semaphore UI menjalankan Bash task dari repo portal lokal. Task wrapper di folder `tasks/` lalu memanggil entry point masing-masing framework di `/dbaportal/automation/projects`.

File kecil systemd tetap berada di `/etc/systemd/system/semaphore.service`, tetapi semua data yang tumbuh berada di mountpoint `/dbaportal`.

## Laptop Preparation

Jalankan dari laptop di folder `dba-automation-portal`:

```powershell
.\scripts\prepare-offline-assets.ps1
```

Jika PowerShell execution policy memblokir script, pakai proses one-shot:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-offline-assets.ps1
```

Script ini akan:

- Download binary Semaphore UI Linux AMD64 ke `assets/`.
- Membuat checksum lokal.
- Membuat git bundle dan snapshot worktree untuk tiga project sibling di folder Documents.

Copy folder `dba-automation-portal` ke VM, contoh:

```powershell
scp -r C:\Users\flatline\Documents\dba-automation-portal oracle@<vm>:/tmp/
```

## VM Installation

Di VM:

```bash
cd /tmp/dba-automation-portal
sudo bash scripts/install-semaphore-offline.sh
sudo bash scripts/import-project-bundles.sh
sudo bash scripts/publish-portal-repo.sh
sudo bash scripts/portal-health-check.sh
```

Setelah service hidup, buka:

```text
http://<vm-ip>:3000
```

Default admin dibuat oleh installer:

- Login: `admin`
- Password: gunakan nilai `--admin-password` saat install, atau default lab `ChangeMe_OnlyForLab_2026!`

Ganti password sebelum dipakai production.

## Semaphore Configuration

Opsi paling cepat adalah bootstrap via API:

```bash
python3.12 scripts/bootstrap-semaphore-api.py \
  --url http://localhost:3000 \
  --username admin \
  --password '<admin-password>'
```

Script ini membuat:

- Project `DBA Automation`
- Repository lokal `dba-automation-portal`
- Key `None`
- Inventory `Local Runner`
- Environment default
- Bash task templates untuk health check, install/replication, Data Guard, dan Oracle Patch

Jika API Semaphore berubah atau bootstrap gagal, ikuti catalog manual di:

- `semaphore/catalog.md`

Untuk workflow Oracle Patch harian, baca:

- `docs/patch-operator-flow.md`

Catalog tersebut berisi template Bash yang perlu dibuat di Semaphore UI. Setiap template memakai repository:

```text
file:///dbaportal/automation/git/dba-automation-portal.git
```

## Task Wrappers

| Wrapper | Framework | Entry point |
| --- | --- | --- |
| `tasks/oracle-install-replication.sh` | Install + replication | `python main.py <action>` |
| `tasks/oracle-replication.sh` | Data Guard only | `python3.12 scripts/dgctl.py <action>` |
| `tasks/oracle-patch-health-check.sh` | Oracle patch runner preflight | local checks + optional SSH check |
| `tasks/oracle-patch-add-host.sh` | Oracle patch inventory onboarding | `./scripts/add_host.sh` |
| `tasks/oracle-patch-inventory.sh` | Oracle patch inventory view | inventory CSV validation |
| `tasks/oracle-patch-status.sh` | Oracle patch monitoring | `./scripts/run_patch.sh status` |
| `tasks/oracle-patch-dry-run.sh` | Oracle patch dry-run | `./scripts/run_patch.sh full --dry-run` |
| `tasks/oracle-patch-precheck.sh` | Oracle patch precheck | `./scripts/run_patch.sh precheck` |
| `tasks/oracle-patch-full.sh` | Oracle patch execution | `./scripts/run_patch.sh full` |
| `tasks/oracle-patch-resume.sh` | Oracle patch recovery | `./scripts/run_patch.sh resume` |
| `tasks/oracle-patch.sh` | Oracle patch advanced/manual phase | `./scripts/run_patch.sh <phase>` |
| `tasks/health-check.sh` | Portal validation | local checks |

## Offline Rule

Jangan jalankan `git clone` dari internet di VM. Update project dilakukan dari laptop dengan membuat bundle baru:

```powershell
.\scripts\prepare-offline-assets.ps1 -SkipSemaphoreDownload
```

Lalu copy ulang `assets/repos/*.bundle` ke VM dan jalankan:

```bash
sudo bash scripts/import-project-bundles.sh
sudo bash scripts/publish-portal-repo.sh
```

`scripts/import-project-bundles.sh` mempertahankan `inventory/targets.csv` yang sudah diupdate dari portal supaya hasil Add Host tidak tertimpa saat code refresh.

## Backup

Backup portal di VM:

```bash
sudo bash scripts/backup-portal.sh
```

Restore:

```bash
sudo bash scripts/restore-portal.sh --archive /dbaportal/backups/<backup>.tar.gz
```
