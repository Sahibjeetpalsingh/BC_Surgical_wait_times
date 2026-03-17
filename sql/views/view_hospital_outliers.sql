-- This view finds hospitals that are far from the province average.
-- A hospital is an outlier when the z-score is above 2 or below -2.

CREATE OR REPLACE VIEW view_hospital_outliers AS
WITH clean_rows AS (
    SELECT *
    FROM fact_surgical_waits
    WHERE percentile_suppressed = FALSE
      AND procedure_group != 'All Other Procedures'
),
hospital_summary AS (
    SELECT
        hospital_name,
        health_authority,
        procedure_group,
        fiscal_year,
        fiscal_year_start,
        quarter,
        quarter_number,
        period_sort_key,
        covid_flag,
        provisional_flag,
        SUM(waiting) AS total_waiting,
        SUM(completed) AS total_completed,
        ROUND(SUM(percentile_comp_50th * completed) / NULLIF(SUM(completed), 0), 1) AS hospital_p50,
        ROUND(SUM(percentile_comp_90th * completed) / NULLIF(SUM(completed), 0), 1) AS hospital_p90
    FROM clean_rows
    GROUP BY
        hospital_name,
        health_authority,
        procedure_group,
        fiscal_year,
        fiscal_year_start,
        quarter,
        quarter_number,
        period_sort_key,
        covid_flag,
        provisional_flag
),
province_stats AS (
    SELECT
        procedure_group,
        period_sort_key,
        AVG(hospital_p50) AS provincial_avg_p50,
        STDDEV(hospital_p50) AS provincial_std_p50,
        AVG(hospital_p90) AS provincial_avg_p90,
        STDDEV(hospital_p90) AS provincial_std_p90,
        COUNT(*) AS reporting_hospital_count
    FROM hospital_summary
    WHERE hospital_p50 IS NOT NULL
    GROUP BY procedure_group, period_sort_key
),
scored_rows AS (
    SELECT
        h.hospital_name,
        h.health_authority,
        h.procedure_group,
        h.fiscal_year,
        h.fiscal_year_start,
        h.quarter,
        h.quarter_number,
        h.period_sort_key,
        h.covid_flag,
        h.provisional_flag,
        h.total_waiting,
        h.total_completed,
        h.hospital_p50,
        h.hospital_p90,
        ROUND(p.provincial_avg_p50, 1) AS provincial_avg_p50,
        ROUND(p.provincial_std_p50, 1) AS provincial_std_p50,
        ROUND(p.provincial_avg_p90, 1) AS provincial_avg_p90,
        p.reporting_hospital_count,
        ROUND((h.hospital_p50 - p.provincial_avg_p50) * 100.0 / NULLIF(p.provincial_avg_p50, 0), 1) AS deviation_from_avg_pct,
        ROUND((h.hospital_p50 - p.provincial_avg_p50) / NULLIF(p.provincial_std_p50, 0), 2) AS z_score_p50
    FROM hospital_summary h
    LEFT JOIN province_stats p
        ON h.procedure_group = p.procedure_group
       AND h.period_sort_key = p.period_sort_key
)
SELECT
    s.*,
    CASE
        WHEN s.z_score_p50 IS NULL THEN NULL
        WHEN ABS(s.z_score_p50) > 2.0 THEN TRUE
        ELSE FALSE
    END AS outlier_flag,
    CASE
        WHEN s.z_score_p50 IS NULL THEN NULL
        WHEN s.z_score_p50 > 2.0 THEN 'high'
        WHEN s.z_score_p50 < -2.0 THEN 'low'
        ELSE 'within_range'
    END AS outlier_direction
FROM scored_rows s
ORDER BY s.period_sort_key, s.procedure_group, ABS(COALESCE(s.z_score_p50, 0)) DESC;
