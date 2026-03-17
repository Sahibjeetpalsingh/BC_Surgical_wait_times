# BC Surgical Wait Times — Data Pipeline

A portfolio-quality end-to-end data pipeline built on BC's publicly published quarterly surgical wait times dataset (2009/10–2024/25).

## What This Project Demonstrates

- **Analytical rigour:** Every cleaning decision is documented with reasoning, not just code
- **Data quality thinking:** Pre-aggregated rollup rows, structural null suppression, COVID discontinuity, and provisional data are each handled with separate, explicit logic
- **SQL design:** Fact table with 5 pre-built analytical views, each answering a specific stakeholder question
- **Stakeholder framing:** Three audience tiers (executive, policy, hospital manager) with a tiered dashboard
- **Full stack:** Python (pandas/openpyxl/DuckDB) → SQL (DuckDB views) → Power BI

## Dataset

**Source:** BC Ministry of Health, Surgical Wait Times
**File:** `data/raw/2009_2025-quarterly-surgical_wait_times-final.xlsx`
**Coverage:** FY2009/10–FY2024/25, quarterly, province-wide
**Rows:** 202,953 (source) → ~155,000 (after removing pre-aggregated rollup rows)
**Dimensions:** 7 health authorities, 66 hospitals, 85 procedure groups

## The 5 Questions This Analysis Answers

| # | Question | SQL View |
|---|----------|----------|
| Q1 | Is BC's surgical backlog recovering post-COVID? | `view_covid_recovery` |
| Q2 | Which health authorities have the longest wait times, and is the gap widening? | `view_regional_wait_times` |
| Q3 | Which procedure types have the most patients waiting, 5-year change? | `view_procedure_volume_trends` |
| Q4 | Are high-volume procedures meeting BC's wait time targets? | `view_benchmark_compliance` |
| Q5 | Which hospitals are statistical outliers vs. provincial average? | `view_hospital_outliers` |

## Project Structure

```
├── data/
│   ├── raw/        # Source file — never modified
│   ├── interim/    # Cleaned CSV (human-readable output)
│   └── processed/  # DuckDB analytical database
├── pipeline/
│   ├── constants.py             # Shared constants for all steps
│   ├── 01_load_inspect.py       # Load & document raw data
│   ├── 02_clean.py              # Drop rollups, classify nulls
│   ├── 03_type_cast.py          # Type casting & standardisation
│   ├── 04_derive_columns.py     # Helper columns (sort keys, flags)
│   ├── 05_export.py             # Export to CSV + DuckDB
│   ├── 06_validate.py           # 8-assertion validation suite
│   └── run_pipeline.py          # Orchestrator
├── sql/
│   ├── schema/                  # Fact table DDL
│   ├── views/                   # 5 analytical views (one per question)
│   └── validation/              # 4 post-load SQL checks
├── powerbi/                     # Power BI workbook
├── docs/
│   ├── README.md                # This file
│   ├── data_dictionary.md       # Column definitions + view documentation
│   ├── assumptions_log.md       # Every analytical decision with reasoning
│   ├── limitations_disclosure.md # What this data cannot answer
│   └── pipeline_runbook.md      # How to update for new quarterly releases
└── requirements.txt
```

## How to Reproduce

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

### 2. Confirm source file is in place

The source file should be at:
```
data/raw/2009_2025-quarterly-surgical_wait_times-final.xlsx
```

### 3. Run the pipeline

```bash
python -m pipeline.run_pipeline
```

This will:
- Load and inspect the source file (writes `docs/inspection_log.md`)
- Clean: remove pre-aggregated rows, classify null patterns
- Type-cast and standardise
- Derive helper columns (sort keys, COVID flag, provisional flag)
- Export to `data/interim/surgical_wait_times_cleaned.csv` and `data/processed/surgical_wait_times.duckdb`
- Run 8 validation assertions (PASS/FAIL/WARN)

### 4. Run SQL validation checks (optional)

```bash
duckdb data/processed/surgical_wait_times.duckdb < sql/validation/post_load_checks.sql
```

### 5. Open Power BI

Open `powerbi/bc_surgical_waits.pbix` and refresh the data source to connect to the DuckDB file.

## Key Data Quality Notes

1. **Pre-aggregated rows:** The source file contains rollup rows ("All Facilities", "All Procedures", "All Health Authorities") that cause double-counting if summed. These are dropped. All aggregations are computed from facility-level records.
2. **Wait time definition:** P50 and P90 are *completed-case* metrics — patients still waiting are excluded. Long waiters are invisible in the percentile columns.
3. **COVID discontinuity:** FY2020/21 and FY2021/22 are flagged. Trend lines should not be drawn continuously across this period.
4. **2024/25 is provisional:** Data was not yet complete at time of last file modification (March 8, 2025).

For full detail, see [docs/data_dictionary.md](data_dictionary.md), [docs/assumptions_log.md](assumptions_log.md), and [docs/limitations_disclosure.md](limitations_disclosure.md).

## Stack

| Layer | Technology |
|-------|-----------|
| Data ingestion | Python 3.10+, pandas, openpyxl |
| Analytical database | DuckDB |
| SQL views | DuckDB SQL |
| Dashboard | Power BI Desktop |
| Documentation | Markdown |
