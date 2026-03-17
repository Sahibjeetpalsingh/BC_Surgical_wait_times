# Assumptions Log

Each assumption is documented with:
- **The assumption** — stated precisely
- **Reasoning** — why this choice was made
- **Alternative considered** — what was rejected and why
- **Invalidating condition** — what new information would require revisiting this decision

---

## A1 — Pre-aggregated rows use OR logic for removal

**Assumption:** A row is classified as a pre-aggregated rollup and dropped if ANY ONE of its three categorical dimensions (HOSPITAL_NAME, PROCEDURE_GROUP, HEALTH_AUTHORITY) contains a sentinel value ("All Facilities", "All Procedures", "All Health Authorities").

**Reasoning:** A row that is aggregated on even one dimension inflates counts if summed. For example, a row with HOSPITAL_NAME = "All Facilities" but a specific procedure group represents all hospitals' volume for that procedure — summing it with the individual hospital rows would count that procedure's volume twice.

**Alternative considered:** AND logic (remove only rows where all three dimensions are aggregated). Rejected because partial rollup rows also cause double-counting.

**Invalidating condition:** If a future data release introduces a legitimate facility named "All Facilities" or a procedure category named "All Procedures", this filter would incorrectly drop real data. Always verify sentinel counts before and after dropping.

---

## A2 — Percentile nulls are structural suppression, not missing data errors

**Assumption:** The 36.4% null rate in PERCENTILE_COMP_50TH and PERCENTILE_COMP_90TH is intentional suppression applied by BC Ministry of Health when completed case counts fall below a threshold (~5 cases). These values are not imputed.

**Reasoning:** Investigation confirmed: median COMPLETED = 0 for null-percentile rows; minimum COMPLETED in non-null rows = 5; null rates are stable across all 16 fiscal years (no temporal drift that would suggest a data quality event); nulls are perfectly synchronised across both percentile columns (no case where one is null but not the other).

**Alternative considered:** Treating nulls as data entry errors and imputing (e.g., forward-fill from prior quarter, or zero). Rejected because there is no central estimate that would be meaningful — a suppressed cell represents "we don't know" not "zero wait time".

**Invalidating condition:** If BC Ministry of Health documentation states a different suppression rule, or if a future data release includes documentation flags that identify suppression separately.

---

## A3 — 54 anomalous rows classified separately from structural suppression

**Assumption:** 54 rows where COMPLETED > 0 but percentile is null represent a distinct data phenomenon (individual wait-time records missing even though surgery count was recorded) and should be flagged with `anomalous_percentile = TRUE` separately from `percentile_suppressed`.

**Reasoning:** These rows do not fit the suppression logic (completed > 0 and often completed > 5). They are concentrated in specific Northern Health procedures in specific years. Treating them as structural suppression would obscure the anomaly.

**Alternative considered:** Merging with `percentile_suppressed`. Rejected because it prevents downstream analysts from distinguishing the two phenomena.

**Invalidating condition:** If BC confirms these rows are part of the suppression policy (e.g., a rule where percentiles are suppressed even when completed count is above threshold if individual record data quality is insufficient). In that case, `anomalous_percentile` rows should be merged into `percentile_suppressed`.

---

## A4 — COVID disruption period = FY2020/21 and FY2021/22 only

**Assumption:** The covid_flag covers fiscal years with `fiscal_year_start` in {2020, 2021}, i.e., April 2020 – March 2022. Q4 of FY2019/20 (January–March 2020) is NOT flagged.

**Reasoning:** BC announced major surgical deferrals in March 2020. However, Q4 2019/20 represents January and February 2020 (two months of normal operation) plus the last two weeks of March. Flagging the entire quarter would distort the 2018/19 baseline, which is the primary pre-COVID reference point throughout the analysis.

**Alternative considered:** Flagging from Q4 2019/20. Rejected because it would partially contaminate the 2018/19 baseline calculation and make the COVID period harder to demarcate cleanly.

**Invalidating condition:** If the analysis requires sub-quarterly precision (e.g., tracking the exact onset of surgical deferrals), Q4 2019/20 should be split and partially flagged, which is not possible with this quarterly data.

---

## A5 — 2024/25 classified as provisional for entire fiscal year

**Assumption:** All rows with FISCAL_YEAR = "2024/25" are flagged as provisional, including Q1–Q3 which are before the file modification date.

**Reasoning:** The source file was last modified March 8, 2025. Q4 2024/25 (January–March 2025) cannot be complete. Since the entire fiscal year shares a file publication, treating the year as provisional is conservative and appropriate.

**Alternative considered:** Flagging only Q4 2024/25. Rejected because earlier quarters may also have been revised (BC routinely corrects prior-quarter data in new releases). Provisionally flagging the whole year is safer.

**Invalidating condition:** If BC publishes release notes confirming Q1–Q3 2024/25 are finalised, the flag could be narrowed to Q4 only.

---

## A6 — "All Other Procedures" excluded from trend analysis

**Assumption:** Rows where `PROCEDURE_GROUP = "All Other Procedures"` are excluded from `view_procedure_volume_trends`, `view_regional_wait_times`, `view_benchmark_compliance`, and `view_hospital_outliers`.

**Reasoning:** This is a residual category capturing procedures not given their own named group. As new named groups are added over the 16-year dataset, previously uncategorised procedures migrate out of "All Other Procedures". A declining trend in this bucket likely reflects reclassification, not a real reduction in procedure volume.

**Alternative considered:** Including it with a disclaimer. Rejected because the direction of the trend is genuinely uninterpretable — it is impossible to separate real volume change from reclassification without procedure-level raw data not available here.

**Invalidating condition:** If BC provides documentation showing the definition of "All Other Procedures" has been stable throughout the dataset period (i.e., no reclassifications occurred).

---

## A7 — Weighted average of P50 used as regional aggregate (not median of medians)

**Assumption:** When aggregating facility-level P50 values to health authority or province level, we use a volume-weighted average (weights = completed case count). This is not a true statistical median.

**Reasoning:** A true median of percentile values requires individual patient-level records. The source data provides pre-computed percentiles per facility/procedure/quarter. A weighted average is the closest valid aggregate. Unweighted average would give equal weight to a 50-case hospital and a 5,000-case hospital.

**Alternative considered:** Unweighted average. Rejected because smaller facilities would disproportionately influence the aggregate, producing an unrepresentative provincial figure.

**Invalidating condition:** If patient-level data becomes available, the aggregate should be recomputed as a true percentile across all patients.

---

## A8 — 2-sigma threshold (|z| > 2.0) for hospital outlier classification

**Assumption:** A hospital is classified as an outlier in `view_hospital_outliers` if its z-score (standardised deviation from provincial mean P50 for the same procedure + period) exceeds 2.0 in absolute value.

**Reasoning:** 2 standard deviations is the conventional threshold in healthcare benchmarking and quality improvement literature. It balances sensitivity (catching genuine outliers) with specificity (not flagging normal variation). At a normal distribution, ~5% of observations would exceed this threshold by chance.

**Alternative considered:** 1.5-sigma (more sensitive). Rejected because it would flag too many low-volume hospitals where natural variance is high. Also considered 3-sigma (more conservative). Rejected because it might miss hospitals with genuine systemic issues.

**Invalidating condition:** If the distribution of wait times across hospitals is shown to be highly skewed (as it often is in healthcare data), the z-score approach may need to be replaced with a percentile-rank approach or interquartile range method.

---

## A9 — Percentile columns rounded to 1 decimal place

**Assumption:** PERCENTILE_COMP_50TH and PERCENTILE_COMP_90TH are rounded to 1 decimal place to resolve floating-point representation artifacts from Excel (e.g., 17.899999999999999 → 17.9).

**Reasoning:** The source data reports wait times in tenths of days. Rounding to 0 decimal places would discard legitimate sub-day precision. Rounding to 1 decimal corrects the artifacts without losing meaningful precision.

**Invalidating condition:** If a value in the source data is genuinely intended to have more than 1 decimal place of precision (e.g., 17.85 representing a meaningful difference from 17.9). Given the clinical context, sub-day precision beyond tenths is not operationally meaningful.

---

## A10 — High-volume procedures defined by top quartile in FY2023/24

**Assumption:** In `view_benchmark_compliance`, "high-volume procedures" are defined as those in the top quartile (NTILE 4) by total WAITING in FY2023/24 (the most recent complete fiscal year).

**Reasoning:** Benchmark compliance is most clinically meaningful for procedures where many patients are affected. A high non-compliance rate for a procedure with 5 patients waiting has less systemic impact than for one with 5,000.

**Alternative considered:** Using a fixed patient count threshold (e.g., > 500 waiting). Rejected because a fixed threshold is sensitive to overall system size — appropriate thresholds change as the system grows or contracts. A relative quartile approach is more stable.

**Invalidating condition:** If the analysis is requested specifically for a low-volume procedure (e.g., to investigate a complaint about a specific service), the high-volume filter should be removed for that analysis.
