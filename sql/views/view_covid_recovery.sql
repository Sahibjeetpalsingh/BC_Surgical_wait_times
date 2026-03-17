-- This view shows province totals by quarter.
-- It also compares each quarter with the 2018/19 average.

CREATE OR REPLACE VIEW view_covid_recovery AS
WITH quarterly_totals AS (
    SELECT
        fiscal_year,
        fiscal_year_start,
        quarter,
        quarter_number,
        period_sort_key,
        covid_flag,
        provisional_flag,
        SUM(waiting) AS total_waiting,
        SUM(completed) AS total_completed
    FROM fact_surgical_waits
    GROUP BY
        fiscal_year,
        fiscal_year_start,
        quarter,
        quarter_number,
        period_sort_key,
        covid_flag,
        provisional_flag
),
baseline AS (
    SELECT
        AVG(total_waiting) AS baseline_avg_waiting,
        AVG(total_completed) AS baseline_avg_completed
    FROM quarterly_totals
    WHERE fiscal_year_start = 2018
)
SELECT
    q.fiscal_year,
    q.fiscal_year_start,
    q.quarter,
    q.quarter_number,
    q.period_sort_key,
    q.covid_flag,
    q.provisional_flag,
    q.total_waiting,
    q.total_completed,
    ROUND(q.total_completed * 100.0 / NULLIF(q.total_waiting + q.total_completed, 0), 1) AS completion_rate_pct,
    ROUND(b.baseline_avg_waiting, 0) AS baseline_avg_waiting_2018_19,
    ROUND(b.baseline_avg_completed, 0) AS baseline_avg_completed_2018_19,
    ROUND((q.total_waiting - b.baseline_avg_waiting) * 100.0 / NULLIF(b.baseline_avg_waiting, 0), 1) AS waiting_vs_baseline_pct
FROM quarterly_totals q
CROSS JOIN baseline b
ORDER BY q.period_sort_key;
