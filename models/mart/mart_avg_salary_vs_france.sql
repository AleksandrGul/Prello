{{ config(
    materialized='table'
) }}

WITH salary_cte AS (
    -- Step 1: Calculate the average salary per department per year
    SELECT
        department_name,
        department_code,
        municipality_code,
        year_date,
        AVG(avg_net_salary) AS avg_sal_by_dept_code
    FROM {{ ref("int_econmic_by_region") }}
    WHERE year_date >= '2015-01-01' and avg_net_salary != 0 and avg_net_salary is not null
    GROUP BY department_code, department_name, municipality_code, year_date
),

median_cte AS (
    -- Step 2: Calculate the median salary per year
    SELECT 
        year_date,
        department_name,
        department_code,
        municipality_code,
        avg_sal_by_dept_code,
        PERCENTILE_CONT(avg_sal_by_dept_code, 0.5) OVER (PARTITION BY year_date) AS median_salary
    FROM salary_cte
),

ratio_cte AS (
    -- Step 3: Compute the ratio of avg salary to median salary
    SELECT 
        department_name,
        department_code,
        municipality_code,
        year_date,
        avg_sal_by_dept_code,
        median_salary,
        avg_sal_by_dept_code / NULLIF(median_salary, 0) AS avg_ratio
    FROM median_cte
),

growth_cte AS (
    -- Step 4: Compute the year-on-year growth ratio
    SELECT 
        department_name,
        department_code,
        municipality_code,
        year_date,
        avg_sal_by_dept_code,
        median_salary,
        avg_ratio,
        (avg_ratio - LAG(avg_ratio) OVER (PARTITION BY municipality_code ORDER BY year_date )) / NULLIF(LAG(avg_ratio) OVER (
        PARTITION BY municipality_code, municipality_code ORDER BY year_date ), 0) AS year_growth_ratio
    FROM ratio_cte
)

-- Step 5: Select final results
SELECT * FROM growth_cte
where department_code is not null
ORDER BY department_name, department_code, municipality_code, year_date
