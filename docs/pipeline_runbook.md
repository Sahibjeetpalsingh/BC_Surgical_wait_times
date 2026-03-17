# Pipeline Runbook

## Overview

This runbook describes how to rerun the pipeline when a new quarterly data release is published by BC Ministry of Health. Estimated time: 15–30 minutes including verification.

---

## Prerequisites

- Python 3.10+ with dependencies installed: `pip install -r requirements.txt`
- DuckDB CLI (optional, for manual validation queries)
- Power BI Desktop with the DuckDB ODBC connector or DirectQuery setup

---

## Step 1: Download and Stage the New Source File

1. Download the updated Excel file from BC Ministry of Health's surgical wait times page.
2. Place the new file at `data/raw/` — do not overwrite the previous file; rename the old file with a date suffix (e.g., `...-final_2025-03-08.xlsx`) before adding the new one.
3. Update the `RAW_FILE` constant in `pipeline/constants.py` if the filename has changed.
4. Record the new file's last modified date and a SHA-256 hash for the README.

---

## Step 2: Check Schema Compatibility

Before running the pipeline, verify the new file has the same 9 columns in the same order:

```
FISCAL_YEAR, QUARTER, HEALTH_AUTHORITY, HOSPITAL_NAME, PROCEDURE_GROUP,
WAITING, COMPLETED, PERCENTILE_COMP_50TH, PERCENTILE_COMP_90TH
```

Check for:
- [ ] Any new columns added
- [ ] Any columns renamed or reordered
- [ ] Any new sentinel values (a new "All X" category would require updating `AGGREGATE_SENTINELS` in `constants.py`)
- [ ] New health authorities or hospitals (especially if BC restructures regional boundaries)
- [ ] New or renamed procedure groups (especially changes to "All Other Procedures")

---

## Step 3: Update Constants If Needed

If a new fiscal year is the current provisional year, update `PROVISIONAL_FISCAL_YEAR` in `pipeline/constants.py`.

If the dataset now covers 17 fiscal years, update `EXPECTED_FISCAL_YEAR_COUNT`.

If BC confirms 2024/25 is finalised, update the provisional flag logic.

---

## Step 4: Run the Full Pipeline

From the project root directory:

```bash
python -m pipeline.run_pipeline
```

Expected output:
```
BC SURGICAL WAIT TIMES — DATA PIPELINE
============================================================
Loading: data/raw/...xlsx
  Shape: XXX,XXX rows × 9 columns
  ...
Step 2: Dropping aggregate rows and classifying nulls...
  ...
Step 6: Running post-export validation...
  PASS [1] Row count: ...
  PASS [2] ...
  ...
All validations passed.
```

---

## Step 5: Compare Against Prior Run

After a clean validation run, compare these metrics against the prior run:

| Metric | Prior value | New value | Delta | Expected? |
|--------|-------------|-----------|-------|-----------|
| Total rows (post-clean) | — | — | — | +~2,000–4,000 per new quarter |
| P50 null rate | ~36% | — | — | Stable ±2% |
| anomalous_percentile count | 54 | — | — | Should be 54 unless dataset revised |
| Total WAITING (latest quarter) | — | — | — | Context-dependent |

If the anomalous_percentile count changes from 54, investigate which rows changed. Prior-quarter revisions by BC may have corrected or added anomalous records.

---

## Step 6: Run SQL Validation Checks

```bash
duckdb data/processed/surgical_wait_times.duckdb < sql/validation/post_load_checks.sql
```

All four checks should return `PASS`. Investigate any `FAIL` or `WARN` before proceeding.

---

## Step 7: Refresh Power BI

1. Open `powerbi/bc_surgical_waits.pbix`
2. Refresh the data source (Home → Refresh)
3. Verify the `provisional_flag` slicer now includes the new fiscal year
4. Check that the COVID band on the Executive page is still correctly positioned
5. Spot-check the latest quarter's waiting volume against the raw file

---

## Troubleshooting

### Error: UnicodeDecodeError when reading Excel file

The source file contains at least one hospital name with special characters (Sechelt/shəshəlh). The pipeline explicitly handles UTF-8 encoding in `03_type_cast.py`. If this error appears, check that:
- The new source file was saved with UTF-8 encoding
- The `openpyxl` engine is being used (not `xlrd`)

### Error: DuckDB OperationalError — database is locked

Power BI may hold the DuckDB file open. Close Power BI before running the pipeline export step (`05_export.py`). The pipeline drops and recreates the database file — it cannot write to an open file.

### Validation FAIL [1]: Row count mismatch between DataFrame and database

Most likely cause: the CSV export succeeded but the DuckDB export was interrupted. Delete `data/processed/surgical_wait_times.duckdb` and rerun `05_export.py` → `06_validate.py`.

### Validation WARN [8]: anomalous_percentile count changed from 54

BC sometimes revises prior-quarter data. Run this query to see which rows changed:

```sql
SELECT fiscal_year, quarter, health_authority, hospital_name, procedure_group,
       completed, percentile_comp_50th
FROM fact_surgical_waits
WHERE anomalous_percentile = TRUE
ORDER BY fiscal_year, quarter;
```

Compare to the previously known 54 rows. Update `EXPECTED_ANOMALOUS_PERCENTILE_ROWS` in `constants.py` if the count has legitimately changed, and document the change in `assumptions_log.md`.

### New procedure group appears in "All Other Procedures" migration

If a procedure newly appears in the 85 named groups that previously was captured in "All Other Procedures", its trend will show an apparent spike from zero — it's not new activity, it's reclassified activity. Do not interpret as real growth. Document the change in `assumptions_log.md`.
