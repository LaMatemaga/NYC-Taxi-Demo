{{ config(materialized='view') }}

select
    zone_id,
    any_value(zone_name) as zone_name,
    any_value(borough) as borough
from {{ source('nyc_taxi', 'taxi_zone_geom') }}
group by zone_id
