# Limitations Disclosure

This document describes limitations that should be communicated alongside findings.
It is intended for stakeholders, report audiences, and dashboard consumers.

---

## 1. Wait Times Reflect Completed Cases Only — Long Waiters Are Invisible

The P50 and P90 metrics in this analysis are **completed-case wait times**. They measure the wait time of patients whose surgery was completed within the reporting quarter. Patients who are still waiting at the end of the quarter are entirely excluded from the percentile calculation.

**Practical implication:** If a hospital clears its backlog by treating short-wait cases first and deferring the longest-waiting patients, the P50 and P90 will improve even while the worst-off patients experience longer waits. The WAITING column (total patients on list at quarter-end) is a better indicator of backlog severity; the percentiles reflect recent throughput.

**Disclosure required for:** Any chart showing P50 or P90 trends, and any benchmark compliance finding.

---

## 2. Percentile Suppression Biases Averages Upward

36.4% of percentile values are suppressed (set to null) because case counts fell below BC's reporting threshold. Suppression is more common for small hospitals and rare procedures.

**Practical implication:** Regional and provincial averages computed from the remaining non-suppressed rows over-represent high-volume facilities. The hospitals and procedures with the most extreme (longest) wait times are disproportionately suppressed, meaning averages likely understate true system-wide wait times. Northern Health has the highest suppression rate and is the most affected by this bias.

**Disclosure required for:** Any regional average, any provincial summary, any benchmark compliance rate.

---

## 3. Urgency Mix Is Not Captured

This dataset does not separate elective, semi-urgent, and urgent surgery. A health authority that refers or transfers its most urgent cases elsewhere will show lower wait times on paper — not because it performs better, but because its remaining caseload is less complex.

**Practical implication:** Cross-hospital and cross-region comparisons should be interpreted at the procedure level, not as general performance comparisons. Even procedure-level comparisons can be affected if the severity distribution within a procedure category differs by location.

**Disclosure required for:** All comparative charts, regional benchmarking, hospital outlier analysis.

---

## 4. COVID Years Are Not Comparable to Pre/Post-COVID Years

Fiscal years 2020/21 and 2021/22 represent a period of extraordinary surgical deferral due to COVID-19. Wait times and volumes during these years reflect policy decisions and capacity constraints, not system performance in a steady-state context.

**Practical implication:** Any trend line that crosses the COVID period without annotation is misleading. Recovery analysis should compare the most recent years to the 2018/19 pre-COVID baseline, not to 2020/21 or 2021/22.

**Disclosure required for:** All trend charts spanning 2019/20 to 2022/23. COVID years should be shaded or marked with a visual break rather than connected by a continuous line.

---

## 5. 2024/25 Data Is Provisional

The source file was last modified March 8, 2025. Fiscal year 2024/25 ends March 31, 2025 — the Q4 data (January–March 2025) was not yet complete at the time of analysis. BC Ministry of Health routinely revises prior-quarter data in subsequent releases.

**Practical implication:** 2024/25 figures should be treated as preliminary. They should not be used as the basis for conclusions about trends or benchmark compliance without confirming they have been finalised.

**Disclosure required for:** Any chart or table that includes FY2024/25 data. These data points should be visually distinguished (e.g., dashed line, different marker style, asterisk notation).

---

## 6. Aggregation Method: Weighted Average, Not True Median

Regional and provincial P50/P90 values are computed as volume-weighted averages of facility-level reported percentiles, not as true statistical medians across all patients. A true aggregate median would require individual patient records.

**Practical implication:** The weighted average is a reasonable approximation but not mathematically equivalent to the median of the full patient population. It may differ from a true median if the distribution of wait times within facilities is highly skewed.

**Disclosure required for:** Any regional or provincial average wait time figure, any benchmark compliance rate based on aggregated percentiles.

---

## 7. Hospital Outlier Classification Assumes Normal Distribution

The z-score method used to identify hospital outliers assumes that wait times across hospitals are approximately normally distributed for a given procedure and period. Healthcare wait time distributions are typically right-skewed.

**Practical implication:** In skewed distributions, the z-score method may over-identify outliers on the short-wait end (left tail) relative to a percentile-rank approach. A hospital classified as a "low outlier" (unusually short waits) may simply reflect a small, high-performing facility rather than a systemic difference.

Always apply a volume threshold filter (minimum patients waiting) when reviewing hospital outliers, as small hospitals generate extreme z-scores due to statistical variance rather than systemic performance differences.

**Disclosure required for:** Any hospital outlier table or scatter plot.

---

## 8. No Population Denominator — Access Rates Cannot Be Computed

The dataset contains counts of patients waiting and surgeries completed, but no population data. It is not possible to compute per-capita surgical access rates, age-standardised rates, or relative under-service rates by region.

**Practical implication:** Northern Health may have high absolute wait times in part because its population is geographically dispersed and access barriers are structural, not just throughput-related. Volume comparisons across regions with very different populations are descriptive only.

**Disclosure required for:** Any regional comparison presented to policy audiences.

---

## 9. No Outcome Data — Quality Cannot Be Assessed

The dataset measures when surgery occurred but not what happened after. There is no information on surgical complications, readmissions, functional outcomes, or whether the clinical outcome was affected by wait time duration.

**Practical implication:** Shorter wait times are not always better if they result in lower-quality surgery or insufficient pre-operative preparation. This analysis measures access, not quality.

**Disclosure required for:** Any executive summary or policy recommendation derived from this analysis.

---

## 10. Coding and Reporting Variation Across Facilities

Individual hospitals may apply different conventions when recording wait-list entry dates, removing patients from the list, or classifying procedures into the 85 reported groups. These variations are not documented and cannot be quantified from the published data.

**Practical implication:** Like-for-like comparisons between hospitals should be made at the procedure-group level (to reduce scope for classification differences) and interpreted with caution, particularly for hospital outlier analysis.

**Disclosure required for:** Hospital-level comparisons, particularly the outlier analysis page.
