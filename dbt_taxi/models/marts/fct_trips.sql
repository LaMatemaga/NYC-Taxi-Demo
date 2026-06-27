{{ config(materialized='table') }}

select
    -- date & time dimensions
    t.trip_date,
    t.trip_year,
    t.trip_month,
    t.trip_week,
    t.trip_weekday,
    t.trip_weekday_num,
    t.pickup_time,
    t.pickup_time_block,
    t.pickup_hour,

    -- flags
    t.is_peak,
    t.is_weekend,
    t.is_holiday,
    t.is_card_payment,
    t.is_airport_pickup,

    -- location dimensions
    t.pickup_location_id  as pickup_zone_id,
    pz.zone_name          as pickup_zone_name,
    pz.borough            as pickup_borough,
    t.dropoff_location_id as dropoff_zone_id,
    dz.zone_name          as dropoff_zone_name,
    dz.borough            as dropoff_borough,

    -- categorical dimensions
    t.vendor_id,
    t.payment_type,
    t.payment_type_name,
    t.rate_code,
    t.rate_code_name,
    t.passenger_count,
    t.store_and_fwd_flag,

    -- timestamps (keep for lineage)
    t.pickup_datetime,
    t.dropoff_datetime,

    -- raw amounts
    t.trip_distance,
    t.trip_duration_minutes,
    t.fare_amount,
    t.extra,
    t.mta_tax,
    t.tip_amount,
    t.tolls_amount,
    t.imp_surcharge,
    t.airport_fee,
    t.total_amount

from {{ ref('stg_yellow_trips') }} t
left join {{ ref('stg_taxi_zones') }} pz
    on t.pickup_location_id = pz.zone_id
left join {{ ref('stg_taxi_zones') }} dz
    on t.dropoff_location_id = dz.zone_id

where t.trip_year in (2020, 2021, 2022)
