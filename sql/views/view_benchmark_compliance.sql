-- This view checks if high-volume procedures meet the BC targets.
-- P50 target = 182 days and P90 target = 364 days.

CREATE OR REPLACE VIEW view_benchmark_compliance AS
WITH clean_rows AS (
    SELECT *
    FROM fact_surgical_waits
    WHERE percentile_suppressed = FALSE
      AND procedure_group != 'All Other Procedures'
),
high_volume_procedures AS (
    SELECT procedure_group
    FROM (
        SELECT
            procedure_group,
            SUM(waiting) AS total_waiting,
            NTILE(4) OVER (ORDER BY SUM(waiting)) AS volume_quartile
        FROM fact_surgical_waits
        WHERE fiscal_year_start = 2023
          AND procedure_group != 'All Other Procedures'
        GROUP BY procedure_group
    ) x
    WHERE volume_quartile = 4
),
grouped_rows AS (
    SELECT
        c.procedure_group,
        c.health_authority,
        c.fiscal_year,
        c.fiscal_year_start,
        c.quarter,
        c.quarter_number,
        c.period_sort_key,
        c.covid_flag,
        c.provisional_flag,
        SUM(c.waiting) AS total_waiting,
        SUM(c.completed) AS total_completed,
        ROUND(SUM(c.percentile_comp_50th * c.completed) / NULLIF(SUM(c.completed), 0), 1) AS weighted_avg_p50,
        ROUND(SUM(c.percentile_comp_90th * c.completed) / NULLIF(SUM(c.completed), 0), 1) AS weighted_avg_p90
    FROM clean_rows c
    INNER JOIN high_volume_procedures h
        ON c.procedure_group = h.procedure_group
    GROUP BY
        c.procedure_group,
        c.health_authority,
        c.fiscal_year,
        c.fiscal_year_start,
        c.quarter,
        c.quarter_number,
        c.period_sort_key,
        c.covid_flag,
        c.provisional_flag
)
SELECT
    g.procedure_group,
    g.health_authority,
    g.fiscal_year,
    g.fiscal_year_start,
    g.quarter,
    g.quarter_number,
    g.period_sort_key,
    g.covid_flag,
    g.provisional_flag,
    g.total_waiting,
    g.total_completed,
    g.weighted_avg_p50,
    g.weighted_avg_p90,
    182 AS p50_threshold_days,
    364 AS p90_threshold_days,
    CASE
        WHEN g.weighted_avg_p50 IS NULL THEN NULL
        WHEN g.weighted_avg_p50 <= 182 THEN TRUE
        ELSE FALSE
    END AS p50_compliant,
    CASE
        WHEN g.weighted_avg_p90 IS NULL THEN NULL
        WHEN g.weighted_avg_p90 <= 364 THEN TRUE
        ELSE FALSE
    END AS p90_compliant,
    CASE
        WHEN g.weighted_avg_p50 IS NULL OR g.weighted_avg_p90 IS NULL THEN NULL
        WHEN g.weighted_avg_p50 <= 182 AND g.weighted_avg_p90 <= 364 THEN TRUE
        ELSE FALSE
    END AS fully_compliant
FROM grouped_rows g
ORDER BY g.period_sort_key, g.procedure_group, g.health_authority;
