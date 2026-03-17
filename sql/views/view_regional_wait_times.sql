-- This view shows average wait times by health authority.
-- It also compares each authority with the province average.

CREATE OR REPLACE VIEW view_regional_wait_times AS
WITH clean_rows AS (
    SELECT *
    FROM fact_surgical_waits
    WHERE percentile_suppressed = FALSE
      AND procedure_group != 'All Other Procedures'
),
regional_summary AS (
    SELECT
        health_authority,
        fiscal_year,
        fiscal_year_start,
        quarter,
        quarter_number,
        period_sort_key,
        covid_flag,
        provisional_flag,
        SUM(completed) AS total_completed,
        SUM(waiting) AS total_waiting,
        ROUND(SUM(percentile_comp_50th * completed) / NULLIF(SUM(completed), 0), 1) AS weighted_avg_p50,
        ROUND(SUM(percentile_comp_90th * completed) / NULLIF(SUM(completed), 0), 1) AS weighted_avg_p90
    FROM clean_rows
    GROUP BY
        health_authority,
        fiscal_year,
        fiscal_year_start,
        quarter,
        quarter_number,
        period_sort_key,
        covid_flag,
        provisional_flag
),
province_summary AS (
    SELECT
        period_sort_key,
        ROUND(SUM(percentile_comp_50th * completed) / NULLIF(SUM(completed), 0), 1) AS provincial_p50,
        ROUND(SUM(percentile_comp_90th * completed) / NULLIF(SUM(completed), 0), 1) AS provincial_p90
    FROM clean_rows
    GROUP BY period_sort_key
)
SELECT
    r.health_authority,
    r.fiscal_year,
    r.fiscal_year_start,
    r.quarter,
    r.quarter_number,
    r.period_sort_key,
    r.covid_flag,
    r.provisional_flag,
    r.total_completed,
    r.total_waiting,
    r.weighted_avg_p50,
    r.weighted_avg_p90,
    ROUND(r.weighted_avg_p50 / 7.0, 1) AS weighted_avg_p50_weeks,
    ROUND(r.weighted_avg_p90 / 7.0, 1) AS weighted_avg_p90_weeks,
    p.provincial_p50,
    p.provincial_p90,
    ROUND(p.provincial_p50 / 7.0, 1) AS provincial_p50_weeks,
    ROUND(p.provincial_p90 / 7.0, 1) AS provincial_p90_weeks,
    ROUND(r.weighted_avg_p50 - p.provincial_p50, 1) AS gap_vs_provincial_p50_days,
    ROUND(r.weighted_avg_p90 - p.provincial_p90, 1) AS gap_vs_provincial_p90_days
FROM regional_summary r
LEFT JOIN province_summary p
    ON r.period_sort_key = p.period_sort_key
ORDER BY r.period_sort_key, r.health_authority;
