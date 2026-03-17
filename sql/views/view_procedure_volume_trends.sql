-- This view shows yearly totals for each procedure.
-- It also compares each year with the same procedure 5 years earlier.

CREATE OR REPLACE VIEW view_procedure_volume_trends AS
WITH annual AS (
    SELECT
        procedure_group,
        fiscal_year,
        fiscal_year_start,
        MAX(CAST(covid_flag AS INTEGER)) AS covid_flag,
        MAX(CAST(provisional_flag AS INTEGER)) AS provisional_flag,
        SUM(waiting) AS annual_waiting,
        SUM(completed) AS annual_completed
    FROM fact_surgical_waits
    WHERE procedure_group != 'All Other Procedures'
    GROUP BY procedure_group, fiscal_year, fiscal_year_start
),
comparison AS (
    SELECT
        a.procedure_group,
        a.fiscal_year,
        a.fiscal_year_start,
        a.covid_flag,
        a.provisional_flag,
        a.annual_waiting,
        a.annual_completed,
        p.annual_waiting AS waiting_5yr_ago,
        p.annual_completed AS completed_5yr_ago,
        CASE
            WHEN p.annual_waiting IS NOT NULL THEN a.annual_waiting - p.annual_waiting
        END AS waiting_5yr_change_abs,
        CASE
            WHEN p.annual_waiting IS NOT NULL AND p.annual_waiting > 0 THEN
                ROUND((a.annual_waiting - p.annual_waiting) * 100.0 / p.annual_waiting, 1)
        END AS waiting_5yr_change_pct
    FROM annual a
    LEFT JOIN annual p
        ON a.procedure_group = p.procedure_group
       AND a.fiscal_year_start = p.fiscal_year_start + 5
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY fiscal_year_start
            ORDER BY annual_waiting DESC
        ) AS rank_by_waiting
    FROM comparison
)
SELECT *
FROM ranked
ORDER BY fiscal_year_start DESC, rank_by_waiting;
