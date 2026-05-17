# Semaphore UI Catalog

Gunakan catalog ini setelah `scripts/install-semaphore-offline.sh`, `scripts/import-project-bundles.sh`, dan `scripts/publish-portal-repo.sh` selesai dijalankan di VM.

Bootstrap membuat beberapa Project agar daftar template tidak terlalu panjang.

## Shared Setup

Semua Project memakai repository, inventory, credential, dan environment yang sama:

```text
Repository: dba-automation-portal
URL: file:///dbaportal/automation/git/dba-automation-portal.git
Branch: master
Inventory: Local Runner
Environment: DBA Automation Defaults
```

## Project: DBA / Portal Ops

Untuk operasi portal dan health check runner.

```text
00 Portal Health Check
```

Survey Variables: tidak ada.

## Project: Oracle / Patch

Untuk patching database/GI yang sudah ada.

```text
00 Health Check
01 Add Host
02 Inventory
03 Status
04 Dry Run Full Pipeline
05 Precheck
06 Full Patch
07 Resume
08 List Reports
09 Export Report
99 Advanced Phase
```

Recommended first runs:

```text
00 Health Check
01 Add Host  (DRY_RUN=true)
02 Inventory
04 Dry Run Full Pipeline
```

Common patch run variables for templates `04`, `05`, `06`, `07`, and `99`:

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `PATCH_ID` | String | Yes | `19.30` | Must exist in `manifests/` |
| `HOSTS` | String | Yes | empty | Comma-separated hosts/IPs |
| `OPERATOR` | String | Yes | empty | Operator name for audit trail |
| `CHANGE_ID` | String | Depends | empty | Required for Full Patch, optional elsewhere |
| `ENVIRONMENT` | Enum | Depends | `lab` | `lab,dev,sit,uat,prod,drc`; required for Full Patch |
| `RUN_REASON` | String | No | empty | Short reason for audit trail |
| `FORCE_RUN` | Enum | Yes | `false` | `false,true`; use only after review |
| `CONFIRM_FULL_PATCH` | String | Full Patch only | empty | Must be `RUN` for Full Patch |
| `RESUME_FROM_RUN_ID` | String | Resume only | empty | Required for Resume |
| `PHASE` | Advanced only | `status` | `precheck,execute,apply,ojvm,datapatch,postcheck,full,resume,status` |
| `DRY_RUN` | Advanced only | `true` | `true,false` |
| `EXTRA_ARGS` | Advanced only | empty | Extra CLI arguments |

## Project: Oracle / Install

Untuk fresh build: OS preparation, Grid/ASM, DB software, manifest-driven patch during install, operator-selected ASM storage, create database, lalu optional Active Data Guard/Broker.

```text
00 Health Check
01 Validate Config
02 Generate Plan
03 Precheck
04 Prepare OS
05 Verify Installer
06 Prepare Storage Rules
07 Install Grid
08 Configure ASM
09 Install DB Software
10 Apply OJVM Patch
11 Create Database
12 Patch Inventory
13 Configure Data Guard
14 Validate Deployment
15 Generate Report
16 Full Workflow
17 Resume Workflow
99 Advanced Phase
```

Common survey variables:

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `CONFIG` | String | Yes | `configs/gcp-single-gi-lab.json` | Relative path inside install framework repo. `installer.patch_manifest` points to a manifest that defines base ZIPs, ASMLIB RPMs, OPatch/RU/OJVM ZIPs, and patch directories. Config still controls ASM disk sources (`uuid`/`DM_UUID`, `id_serial`/`ID_SERIAL`, `id_wwn`/`ID_WWN`, or `path`). |
| `ASM_STORAGE_MODE` | Enum | Yes | `raw` | `raw,asmlibv3,afd`; passed to `--asm-storage-mode`. Use `raw` for GCP/by-id VM disks, `asmlibv3` for Oracle ASMLIB v3 labels, or `afd` for ASM Filter Driver labels. |
| `DRY_RUN` | Enum | Execute steps only | `true` | `true,false`; keep true until reviewed |
| `FROM_PHASE` | String | No | empty | Optional start phase for Full/Resume workflow |
| `TO_PHASE` | String | No | empty | Optional stop phase for Full/Resume workflow |
| `EXTRA_ARGS` | String | No | empty | Enter only extra CLI flags; do not prefix with `EXTRA_ARGS=`. The portal wrapper already appends storage/patch guardrails for real storage, patch, full, and resume actions. `03 Precheck` already defaults to `--continue-on-fail`; add `--no-resume` only when you intentionally want a fresh audit run. |

Recommended first runs:

```text
01 Validate Config
02 Generate Plan
03 Precheck  (DRY_RUN=true)
```

Use `99 Advanced Phase` only for manual actions not exposed as a dedicated template, including legacy compatibility `prepare-storage` and aggregate `apply-patch`. Prefer `06 Prepare Storage Rules` for the selected storage mode; keep the same `ASM_STORAGE_MODE` for `06`, `07`, `08`, `16`, and `17`.
Use `07 Install Grid` and `09 Install DB Software` knowing their install-home step reruns by default: unconfigured homes are cleaned, base homes are unzipped again, and OPatch is refreshed before RU apply.

`13 Configure Data Guard` supports `MODE=config`, `MODE=active-dataguard`, or `MODE=broker`. `MODE=config` follows `dataguard.configuration_method` from the selected JSON config.

Use `16 Full Workflow` for the consolidated install plus replication run. Keep
`DRY_RUN=true` for review; for real execution add the required guardrails in
`EXTRA_ARGS` only for additional flags; the wrapper already appends `--allow-storage-changes` and `--allow-patch-apply` where required.
Use `17 Resume Workflow` after a stopped/failed workflow, optionally with
`FROM_PHASE` and `TO_PHASE`.

## Project: Oracle / Replication

Untuk database/GI/ASM yang sudah ada, lalu setup Data Guard/replication saja.

```text
00 Health Check
01 Init Config
02 Validate Config
03 Setup SSH
04 Plan
05 Render
06 Run
99 Advanced Phase
```

Common survey variables:

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `CONFIG` | String | Yes | `configs/profiles/single-gi-physical.json` | Relative path inside replication framework repo |
| `PROFILE` | Enum | Init only | `single-gi-physical` | `single-gi-physical,rac-2node-physical,rac-2node-broker` |
| `OUTPUT_CONFIG` | String | Init only | `configs/my-dg.json` | Output generated by `Init Config` |
| `RENDER_DIR` | String | Render only | `rendered/my-dg` | Generated artifact directory |
| `DRY_RUN` | Enum | Setup/Run only | `true` | `true,false` |
| `EXECUTE` | Enum | Setup/Run only | `false` | Real execution requires `true` |
| `YES` | Enum | Setup/Run only | `false` | Real execution confirmation |
| `FROM_STAGE` | String | Run only | empty | Optional stage start |
| `TO_STAGE` | String | Run only | empty | Optional stage stop |
| `EXTRA_ARGS` | String | No | empty | Extra CLI arguments |

Recommended first runs:

```text
01 Init Config
02 Validate Config
04 Plan
05 Render
06 Run  (DRY_RUN=true EXECUTE=false)
```

`Validate Config` memang akan menolak nilai `example.com`; copy profile ke config final dan isi hostname/IP real sebelum change window.

## Operational Guardrails

- Jalankan health check setelah import bundle.
- Jalankan validate/plan/dry-run sebelum task yang mengubah target.
- Jalankan Add Host dengan `DRY_RUN=true` sebelum update inventory.
- Jalankan Add Host real hanya dengan `CONFIRM_ADD_HOST=ADD`.
- Jalankan Full Patch hanya dengan `CONFIRM_FULL_PATCH=RUN`.
- Simpan `run_id` dari log patch untuk resume.
- Jangan isi password di `EXTRA_ARGS`; gunakan secret/survey secret Semaphore jika nanti dibutuhkan.
- Untuk VM offline, update code hanya lewat `assets/repos/*.bundle` dari laptop.
