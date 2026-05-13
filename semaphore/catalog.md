# Semaphore UI Catalog

Gunakan catalog ini setelah `scripts/install-semaphore-offline.sh`, `scripts/import-project-bundles.sh`, dan `scripts/publish-portal-repo.sh` selesai dijalankan di VM.

## Project

Create Project:

```text
Name: DBA Automation
```

## Repository

Create Repository:

```text
Name: dba-automation-portal
URL: file:///dbaportal/automation/git/dba-automation-portal.git
Branch: master
```

Jika UI meminta credential untuk repository lokal, pilih credential type yang paling minimal atau empty/none jika tersedia.

## Template 1: Portal Health Check

```text
Name: 00 - Portal Health Check
App: Bash
Repository: dba-automation-portal
Script: tasks/health-check.sh
```

Survey Variables: tidak ada.

## Template 2: Oracle Install + Replication

```text
Name: 10 - Oracle Install Replication
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-install-replication.sh
```

Survey Variables:

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `ACTION` | Enum | Yes | `validate-config` | `validate-config,doctor,inventory,precheck,prepare-os,verify-installer,prepare-storage-rules,install-grid,configure-asm-storage,install-db-software,update-opatch,analyze-patch,apply-grid-patch,apply-db-patch,apply-ojvm-patch,datapatch,patch-inventory,create-database,setup-active-dataguard,setup-dataguard-broker,validate-deployment,generate-plan,generate-report,switchover,failover,collect-diagnostics,cleanup-lab,rollback-framework` |
| `CONFIG` | String | Yes | `configs/sample-rac-dg.json` | Relative path inside install framework repo |
| `DRY_RUN` | Enum | Yes | `true` | `true,false` |
| `EXTRA_ARGS` | String | No | empty | Example: `--allow-storage-changes` or `--allow-patch-apply` |

Recommended first runs:

```text
ACTION=validate-config CONFIG=configs/sample-rac-dg.json
ACTION=generate-plan CONFIG=configs/sample-rac-dg.json
ACTION=precheck CONFIG=configs/sample-rac-dg.json DRY_RUN=true
```

## Template 3: Oracle Data Guard Replication

```text
Name: 20 - Oracle Data Guard Replication
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-replication.sh
```

Survey Variables:

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `ACTION` | Enum | Yes | `validate-config` | `init-config,validate-config,setup-ssh,plan,render,run` |
| `CONFIG` | String | Yes | `configs/profiles/rac-2node-broker.json` | Relative path inside replication framework repo |
| `PROFILE` | Enum | No | `rac-2node-broker` | `single-gi-physical,rac-2node-physical,rac-2node-broker`; used by `init-config` |
| `OUTPUT_CONFIG` | String | No | `configs/my-dg.json` | Used by `init-config` |
| `RENDER_DIR` | String | No | `rendered/my-dg` | Used by `render` |
| `DRY_RUN` | Enum | Yes | `true` | `true,false`; used by `setup-ssh` and `run` |
| `EXECUTE` | Enum | Yes | `false` | `true,false`; required for real setup/run |
| `YES` | Enum | Yes | `false` | `true,false`; required with `EXECUTE=true` |
| `FROM_STAGE` | String | No | empty | Used by `run` |
| `TO_STAGE` | String | No | empty | Used by `run` |
| `EXTRA_ARGS` | String | No | empty | Extra CLI arguments |

Recommended first runs:

```text
ACTION=validate-config CONFIG=configs/profiles/rac-2node-broker.json
ACTION=plan CONFIG=configs/profiles/rac-2node-broker.json
ACTION=render CONFIG=configs/profiles/rac-2node-broker.json RENDER_DIR=rendered/my-dg
ACTION=run CONFIG=configs/profiles/rac-2node-broker.json DRY_RUN=true EXECUTE=false
```

## Patch Templates

Gunakan urutan ini sebagai operator flow:

```text
Patch / 00 Health Check
Patch / 01 Add Host
Patch / 02 Inventory
Patch / 03 Status
Patch / 04 Dry Run Full Pipeline
Patch / 05 Precheck
Patch / 06 Full Patch
Patch / 07 Resume
Patch / 08 List Reports
Patch / 09 Export Report
Patch / 99 Advanced Phase
```

### Patch / 00 Health Check

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-health-check.sh
```

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `PATCH_ID` | String | Yes | `19.30` | Patch repository/manifest to validate |
| `HOSTS` | String | No | empty | Optional comma-separated host inventory check |
| `CHECK_SSH` | Enum | Yes | `false` | `false,true`; true checks SSH batch mode |

### Patch / 01 Add Host

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-add-host.sh
```

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `HOSTS` | String | Yes | empty | Comma-separated hosts/IPs |
| `APP_NAME` | String | Yes | empty | Application name in patch inventory |
| `DB_HOME` | String | Yes | `/u01/app/oracle/product/19c/dbhome_1` | Oracle DB home |
| `GRID_HOME` | String | No | empty | Empty for Single FS |
| `DB_USER` | String | Yes | `oracle` | Oracle software owner |
| `GRID_USER` | String | No | empty | Empty for Single FS |
| `ALLOW_EXISTING_APP` | Enum | Yes | `false` | `false,true`; true when adding another node for same app |
| `ALLOW_APP_CONFIG_DRIFT` | Enum | Yes | `false` | `false,true`; use only when app rows intentionally differ |
| `DRY_RUN` | Enum | Yes | `true` | `true,false`; dry-run does not SSH or update inventory |
| `SKIP_SSH_COPY_ID` | Enum | Yes | `true` | `true,false`; keep true when runner SSH key is already installed |
| `CONFIRM_ADD_HOST` | String | No | empty | Must be `ADD` when `DRY_RUN=false` |

Recommended first runs:

```text
HOSTS=<host> APP_NAME=<app> DB_HOME=/u01/app/oracle/product/19c/dbhome_1 DB_USER=oracle DRY_RUN=true
HOSTS=<host> APP_NAME=<app> DB_HOME=/u01/app/oracle/product/19c/dbhome_1 DB_USER=oracle DRY_RUN=false SKIP_SSH_COPY_ID=true
```

### Patch / 02 Inventory

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-inventory.sh
```

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `APP_NAME` | String | No | empty | Optional app filter |
| `HOSTS` | String | No | empty | Optional comma-separated host filter |

### Patch / 03 Status

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-status.sh
```

| Name | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `PATCH_ID` | String | Yes | `19.30` | Must exist in `manifests/` |
| `HOSTS` | String | Yes | empty | Comma-separated hosts/IPs |
| `OPERATOR` | String | Yes | empty | Operator name used by prior run |
| `RESUME_FROM_RUN_ID` | String | No | empty | Limit status up to a specific run |

### Patch / 04 Dry Run Full Pipeline

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-dry-run.sh
```

### Patch / 05 Precheck

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-precheck.sh
```

### Patch / 06 Full Patch

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-full.sh
```

Requires `CONFIRM_FULL_PATCH=RUN`.

### Patch / 07 Resume

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-resume.sh
```

### Patch / 99 Advanced Phase

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch.sh
```

### Patch / 08 List Reports

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-list-reports.sh
```

Optional filters: `PATCH_ID`, `OPERATOR`, `HOSTS`, and `LIMIT`.

### Patch / 09 Export Report

```text
App: Bash
Repository: dba-automation-portal
Script: tasks/oracle-patch-export-report.sh
```

Use `RUN_ID` for a specific report, or filters `PATCH_ID`, `OPERATOR`, and `HOSTS` to export the latest matching report. Default export path is `/dbaportal/exports/patch-reports`.

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

## Operational Guardrails

- Jalankan health check setelah import bundle.
- Jalankan validate/plan/dry-run sebelum task yang mengubah target.
- Jalankan Add Host dengan `DRY_RUN=true` sebelum update inventory.
- Jalankan Add Host real hanya dengan `CONFIRM_ADD_HOST=ADD`.
- Jalankan Full Patch hanya dengan `CONFIRM_FULL_PATCH=RUN`.
- Simpan `run_id` dari log patch untuk resume.
- Jangan isi password di `EXTRA_ARGS`; gunakan secret/survey secret Semaphore jika nanti dibutuhkan.
- Untuk VM offline, update code hanya lewat `assets/repos/*.bundle` dari laptop.
