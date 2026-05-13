# Oracle Patch Operator Flow

Gunakan template `Patch / ...` di project Semaphore `DBA Automation`.

## Recommended Flow

1. `Patch / 00 Health Check`
   Validasi runner, repo patch, manifest, ZIP media detail, inventory, runtime, dan optional SSH batch mode.

2. `Patch / 01 Add Host`
   Jalankan `DRY_RUN=true` dulu. Setelah preview benar, jalankan `DRY_RUN=false`.
   Real update wajib `CONFIRM_ADD_HOST=ADD` dan akan membuat backup inventory.

3. `Patch / 02 Inventory`
   Cek host sudah masuk inventory, tidak ada duplicate host, dan tidak ada app config drift.

4. `Patch / 03 Status`
   Lihat status run sebelumnya untuk host/operator/patch yang sama.

5. `Patch / 04 Dry Run Full Pipeline`
   Preview full pipeline. Tidak membuat lock, state, report, atau remote change.

6. `Patch / 05 Precheck`
   Jalankan precheck real. Jika gagal, perbaiki dulu sebelum full patch.

7. `Patch / 06 Full Patch`
   Wajib isi `CONFIRM_FULL_PATCH=RUN`. Gunakan setelah dry-run dan precheck direview.

8. `Patch / 07 Resume`
   Pakai `RUN_ID` dari log gagal atau report sebelumnya.

9. `Patch / 08 List Reports`
   Cari run, summary, dan report HTML dari eksekusi sebelumnya.

10. `Patch / 09 Export Report`
   Copy report HTML ke `/dbaportal/exports/patch-reports` untuk evidence handover.

11. `Patch / 99 Advanced Phase`
   Untuk DBA yang perlu menjalankan phase manual seperti `execute`, `apply`, `ojvm`, `datapatch`, atau `postcheck`.

## Important Fields

| Field | Meaning |
| --- | --- |
| `PATCH_ID` | Manifest patch, contoh `19.30` |
| `HOSTS` | Host/IP comma-separated sesuai inventory |
| `OPERATOR` | Nama operator untuk audit dan resume lookup |
| `CHANGE_ID` | Nomor change/request |
| `ENVIRONMENT` | `lab`, `dev`, `sit`, `uat`, `prod`, atau `drc` |
| `RUN_REASON` | Keterangan singkat change window |
| `FORCE_RUN` | Bypass target-state auto-skip; gunakan hanya setelah review |
| `RUN_ID` | ID eksekusi yang muncul di log; dipakai untuk resume |
| `CONFIRM_ADD_HOST` | Wajib `ADD` untuk Add Host real |
| `CONFIRM_FULL_PATCH` | Wajib `RUN` untuk Full Patch real |

## Semaphore Log Markers

Framework mencetak marker yang mudah dicari:

```text
RUN_ID=<run_id>
REPORT_PATH=<html_report_path>
SUMMARY_PATH=<summary_json_path>
INVENTORY_BACKUP=<backup_csv_path>
```

Simpan dua nilai ini di evidence change.

## Production Checklist

- Health check sukses.
- Host ada di inventory dan app config drift sudah dipahami.
- Patch ZIP lengkap di `/u01/oracle-patch/repo/<PATCH_ID>`.
- Dry-run full pipeline sudah direview.
- Precheck sukses.
- `CHANGE_ID` diisi.
- `CONFIRM_FULL_PATCH=RUN` hanya diisi saat benar-benar masuk execution window.

## Evidence

Setelah run selesai:

1. Jalankan `Patch / 08 List Reports`.
2. Jalankan `Patch / 09 Export Report` dengan `RUN_ID` yang dipilih.
3. Ambil file dari `/dbaportal/exports/patch-reports`.
