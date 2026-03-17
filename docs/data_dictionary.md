# Data Dictionary

## Domain Glossary

**Fiscal year (BC):** April 1 to March 31. "2023/24" means April 1, 2023 to March 31, 2024.
**Q1:** April–June. **Q2:** July–September. **Q3:** October–December. **Q4:** January–March.
**Health authority:** One of six regional health authorities in BC plus Provincial Health Services Authority (PHSA).
**Completed-case wait time:** The number of days from when a patient was added to the surgical wait list to when their surgery was completed — measured only for patients whose surgery was completed within the reporting quarter. Patients still waiting at quarter-end are excluded.
**Structural suppression:** When the number of completed cases for a procedure/facility/period is too small (BC threshold: approximately 5 cases), BC does not publish percentile values to protect against statistical instability and potential patient re-identification. These cells are deliberately blank, not missing by error.
**P50 (50th percentile):** The median wait time — half of completed patients in that period waited this long or less.
**P90 (90th percentile):** 90% of completed patients waited this long or less. 10% waited longer.

---

## Source File Columns

These are the original nine columns from the source Excel file.

| Column | Type | Nullable | Description | Caveats |
|--------|------|----------|-------------|---------|
| `FISCAL_YEAR` | String | No | BC fiscal year label, e.g. "2023/24" | Sorted by `fiscal_year_start` (integer), not alphabetically |
| `QUARTER` | String | No | Quarter within fiscal year: Q1, Q2, Q3, Q4 | Q1 = April–June; not calendar-year quarters |
| `HEALTH_AUTHORITY` | String | No | Regional health authority or "All Health Authorities" aggregate | "All Health Authorities" rows are pre-aggregated rollups and are **dropped** in cleaning |
| `HOSPITAL_NAME` | String | No | Specific hospital or "All Facilities" | "All Facilities" rows are pre-aggregated rollups and are **dropped** in cleaning |
| `PROCEDURE_GROUP` | String | No | Surgical procedure category or "All Procedures" / "All Other Procedures" | "All Procedures" rows dropped. "All Other Procedures" retained but excluded from trend analysis due to composition drift |
| `WAITING` | Integer | No | Patients on the wait list at **end of quarter** for this facility/procedure | Snapshot, not cumulative. Does not count patients who entered and left the queue during the quarter |
| `COMPLETED` | Integer | No | Surgeries completed within the quarter | Includes elective and semi-urgent; urgency tier not captured |
| `PERCENTILE_COMP_50TH` | Float | Yes | Median days from wait-list entry to surgery, for cases completed that quarter | 36.4% structurally suppressed (small sample); rounded to 1 decimal in pipeline |
| `PERCENTILE_COMP_90TH` | Float | Yes | 90th percentile wait days, same population | Same suppression pattern as P50 |

---

## Derived Columns (added by pipeline)

These columns do not exist in the source file. They are computed in `pipeline/04_derive_columns.py` and stored in the fact table.

| Column | Type | Description | Derivation |
|--------|------|-------------|------------|
| `fiscal_year_start` | Integer | Starting calendar year of the fiscal year | First 4 characters of `FISCAL_YEAR` as integer. "2023/24" → 2023 |
| `quarter_number` | Integer | Quarter as integer 1–4 | Q1→1, Q2→2, Q3→3, Q4→4 |
| `period_sort_key` | Integer | Monotonically increasing sort key for time series | `fiscal_year_start * 10 + quarter_number`. "2023/24 Q3" → 20233 |
| `covid_flag` | Boolean | True for the two peak COVID disruption fiscal years | True where `fiscal_year_start` ∈ {2020, 2021} (FY2020/21 and FY2021/22) |
| `provisional_flag` | Boolean | True for data not yet finalised | True where `FISCAL_YEAR = "2024/25"` |
| `percentile_suppressed` | Boolean | True where percentile columns are null | True wherever `PERCENTILE_COMP_50TH IS NULL`. Indicates structural suppression, not data error |
| `anomalous_percentile` | Boolean | True for the 54 rows with completed surgeries but null percentiles | True where `COMPLETED > 0 AND PERCENTILE_COMP_50TH IS NULL`. Distinct from structural suppression |

---

## Fact Table: `fact_surgical_waits`

All source columns plus all derived columns. Natural primary key is the five-column composite:
`(fiscal_year, quarter, health_authority, hospital_name, procedure_group)`

Aggregate sentinel rows are excluded — this table contains only granular (facility + procedure level) records.

---

## SQL Views

### `view_covid_recovery`
**Question answered:** Is BC's surgical backlog recovering post-COVID?

| Column | Description |
|--------|-------------|
| `fiscal_year`, `quarter`, `period_sort_key` | Time dimensions |
| `covid_flag`, `provisional_flag` | Pass-through flags |
| `total_waiting` | Province-wide sum of WAITING for that quarter |
| `total_completed` | Province-wide sum of COMPLETED |
| `completion_rate_pct` | `total_completed / (total_waiting + total_completed) × 100` |
| `baseline_avg_waiting_2018_19` | Average quarterly WAITING in FY2018/19 (same value on every row) |
| `waiting_vs_baseline_pct` | `(total_waiting − baseline) / baseline × 100`. Positive = above baseline |

**Includes all rows** — no percentile filter. Volume-only view.

---

### `view_regional_wait_times`
**Question answered:** Which health authorities have the longest median wait times, and is the gap widening or narrowing?

| Column | Description |
|--------|-------------|
| `health_authority`, `fiscal_year`, `quarter`, `period_sort_key` | Dimensions |
| `weighted_avg_p50` / `weighted_avg_p90` | Volume-weighted average of facility P50/P90 (days) |
| `weighted_avg_p50_weeks` / `weighted_avg_p90_weeks` | Same, converted to weeks |
| `provincial_p50` / `provincial_p90` | Provincial benchmark for same period |
| `gap_vs_provincial_p50_days` | Positive = longer waits than provincial average |

**Filters:** `percentile_suppressed = FALSE`, excludes "All Other Procedures".
**Limitation:** Weighted average of P50 values is not a true statistical median — it approximates the median of medians, which is the closest possible aggregate with pre-computed percentile data.

---

### `view_procedure_volume_trends`
**Question answered:** Which procedure types have the most patients waiting, and how has that changed over 5 years?

| Column | Description |
|--------|-------------|
| `procedure_group`, `fiscal_year`, `fiscal_year_start` | Dimensions |
| `annual_waiting` / `annual_completed` | Annual totals (sum of all 4 quarters) |
| `waiting_5yr_ago` | Annual waiting for same procedure 5 years prior (NULL if unavailable) |
| `waiting_5yr_change_abs` / `waiting_5yr_change_pct` | Absolute and percentage change |
| `rank_by_waiting` | Procedure rank within fiscal year by waiting volume (1 = most) |

**Excludes** "All Other Procedures". Annual granularity (quarterly detail too noisy for procedure trends).

---

### `view_benchmark_compliance`
**Question answered:** Are high-volume procedures meeting BC wait time targets?

| Column | Description |
|--------|-------------|
| `procedure_group`, `health_authority`, period columns | Dimensions |
| `weighted_avg_p50` / `weighted_avg_p90` | Volume-weighted average P50/P90 (days) |
| `p50_threshold_days` / `p90_threshold_days` | 182 / 364 days |
| `p50_compliant` | TRUE if weighted P50 ≤ 182 days |
| `p90_compliant` | TRUE if weighted P90 ≤ 364 days |
| `fully_compliant` | TRUE if both thresholds met. NULL if either percentile unavailable |

**Scope:** Top-quartile procedures by WAITING volume in FY2023/24 only. Low-volume procedures excluded — one outlier case would dominate.

---

### `view_hospital_outliers`
**Question answered:** Which hospitals are outliers vs. the provincial average for the same procedure and quarter?

| Column | Description |
|--------|-------------|
| `hospital_name`, `health_authority`, `procedure_group`, period columns | Dimensions |
| `hospital_p50` / `hospital_p90` | Hospital-level weighted average P50/P90 |
| `provincial_avg_p50` / `provincial_std_p50` | Provincial mean and std dev for same procedure + period |
| `deviation_from_avg_pct` | `(hospital_p50 − provincial_avg) / provincial_avg × 100` |
| `z_score_p50` | Standard deviations from provincial mean. NULL if std = 0 |
| `outlier_flag` | TRUE if `|z_score_p50| > 2.0` |
| `outlier_direction` | "high", "low", or "within_range" |
| `total_waiting` | Volume — apply threshold filter before interpreting outlier flags |

**Limitation:** Low-volume hospitals can show extreme z-scores due to statistical variance. Always apply `total_waiting > N` filter.
