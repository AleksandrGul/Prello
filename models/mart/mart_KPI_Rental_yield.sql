{{ config(
    materialized='table'
) }}

with rp as (SELECT
    a.municipality_code,
    cast(round(SUM(b.population)) as int64) as population,
    AVG((COALESCE(rental_max_apartment, 0) + COALESCE(rental_min_apartment, 0)) / 2) AS rental_appart,
    AVG((COALESCE(rental_med_house, 0) + COALESCE(rental_max_house, 0) + COALESCE(rental_min_house, 0)) / 3) AS rental_house
  FROM {{ ref("stg_raw__real_estate_info_by_municipality") }} as a
  LEFT JOIN {{ ref("stg_raw__population_by_municipality") }} as b ON a.municipality_code = b.municipality_code
  where rental_med_house != 0 and rental_min_house != 0 and rental_max_house != 0 and rental_med_house is not null and rental_min_house is not null and rental_max_house is not null
  GROUP BY municipality_code),
fs as (
   SELECT
    municipality_code,
    sales_price_m_2,
    surface,
    premise_type
  FROM {{ ref("int_notary_real_estate_sales")}}
  Where sales_price_m_2 != 0 and sales_price_m_2 is not null)

select 
geo.department_code,
geo.department_name,
rp.municipality_code,
rp.population,
rp.rental_appart,
rp.rental_house,
fs.sales_price_m_2,
fs.premise_type,
fs.surface,
  CASE
    WHEN fs.premise_type = 'Appartement' THEN (rp.rental_appart * 12 / fs.sales_price_m_2)
    WHEN fs.premise_type = 'Maison' THEN (rp.rental_house * 12 / fs.sales_price_m_2)
  END AS yield_rental,
  CASE
    WHEN fs.premise_type = 'Appartement' THEN 1 / (rp.rental_appart * 12 / fs.sales_price_m_2)
    WHEN fs.premise_type = 'Maison' THEN 1 / (rp.rental_house * 12 / fs.sales_price_m_2)
  END AS BEP_in_years 
  from rp 
left join fs on rp.municipality_code = fs.municipality_code
left join {{ref("stg_raw__geographical_referential")}} as geo on rp.municipality_code = geo.municipality_code 
where premise_type is not null and fs.sales_price_m_2 is not null and fs.sales_price_m_2 != 0
order by geo.department_code, geo.department_name, rp.municipality_code, premise_type
