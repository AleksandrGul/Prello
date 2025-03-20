select
department_code,
department_name,
a.municipality_code,
INITCAP(REPLACE(poi, '_', ' ')) as poi,
COUNT(poi) as nb_poi,
AVG(importance) as avg_importance_per_poi

from  {{ref ('int_tourism')}} as a 
left join {{ref ('stg_raw__geographical_referential')}} as b 
on a.municipality_code = b.municipality_code 
where department_code IS NOT NULL
GROUP BY 
department_code,
department_name,
a.municipality_code,
poi
ORDER BY department_code, department_name