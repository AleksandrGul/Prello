{{ config(
    materialized='table'
) }}

WITH population_data AS (
    SELECT
        department_code,
        department_name,
        a.municipality_code,
        EXTRACT(YEAR FROM year_date) AS sales_year,
        cast(population as int64) as population
    FROM {{ ref('stg_raw__population_by_municipality') }} as a
        left join {{ref("stg_raw__geographical_referential")}} as b on a.municipality_code = b.municipality_code
    GROUP BY department_code, department_name, a.municipality_code, sales_year, population
),
sales_data AS (
    SELECT
        department_code,
        department_name,
        d.municipality_code,
        EXTRACT(YEAR FROM sales_date) AS sales_year,
        SUM(sales_amount) AS total_sales_municip
    FROM {{ ref('int_notary_real_estate_sales') }} as d
    left join {{ref("stg_raw__geographical_referential")}} as c on d.municipality_code = c.municipality_code
    GROUP BY department_code, department_name, d.municipality_code, sales_year
)
SELECT
    s.department_code,
    s.department_name,
    p.municipality_code,
    s.sales_year,
    s.total_sales_municip,
    p.population,
    SAFE_DIVIDE(s.total_sales_municip, p.population) AS sales_per_citizen
FROM sales_data s
LEFT JOIN population_data p
    ON s.department_code = p.department_code
    AND s.sales_year = p.sales_year
where s.department_code is not null
order by s.department_code, s.department_name
