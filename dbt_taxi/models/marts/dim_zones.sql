{{ config(materialized='table') }}

select
    zone_id,
    zone_name,
    borough
from {{ ref('stg_taxi_zones') }}
