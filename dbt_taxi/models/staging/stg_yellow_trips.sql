{{ config(materialized='view') }}

with source as (
    select *
    from {{ source('nyc_taxi', 'tlc_yellow_trips_2020') }}

    union all

    select *
    from {{ source('nyc_taxi', 'tlc_yellow_trips_2021') }}

    union all

    select *
    from {{ source('nyc_taxi', 'tlc_yellow_trips_2022') }}
),

us_holidays as (
    select holiday_date from unnest([
        -- 2021
        date '2021-01-01',   -- New Year's Day
        date '2021-01-18',   -- MLK Day
        date '2021-02-15',   -- Presidents' Day
        date '2021-05-31',   -- Memorial Day
        date '2021-06-18',   -- Juneteenth observed (Jun 19 = Sat)
        date '2021-07-04',   -- Independence Day
        date '2021-07-05',   -- Independence Day observed (Jul 4 = Sun)
        date '2021-09-06',   -- Labor Day
        date '2021-10-11',   -- Columbus Day
        date '2021-11-11',   -- Veterans Day
        date '2021-11-25',   -- Thanksgiving
        date '2021-12-24',   -- Christmas observed (Dec 25 = Sat)
        date '2021-12-25',   -- Christmas
        -- 2022
        date '2022-01-01',   -- New Year's Day
        date '2022-01-17',   -- MLK Day
        date '2022-02-21',   -- Presidents' Day
        date '2022-05-30',   -- Memorial Day
        date '2022-06-19',   -- Juneteenth
        date '2022-06-20',   -- Juneteenth observed (Jun 19 = Sun)
        date '2022-07-04',   -- Independence Day
        date '2022-09-05',   -- Labor Day
        date '2022-10-10',   -- Columbus Day
        date '2022-11-11',   -- Veterans Day
        date '2022-11-24',   -- Thanksgiving
        date '2022-12-25',   -- Christmas
        date '2022-12-26',   -- Christmas observed (Dec 25 = Sun)
        -- 2020
        date '2020-01-01',   -- New Year's Day
        date '2020-01-20',   -- MLK Day
        date '2020-02-17',   -- Presidents' Day
        date '2020-05-25',   -- Memorial Day
        date '2020-07-03',   -- Independence Day observed (Jul 4 = Sat)
        date '2020-07-04',   -- Independence Day
        date '2020-09-07',   -- Labor Day
        date '2020-10-12',   -- Columbus Day
        date '2020-11-11',   -- Veterans Day
        date '2020-11-26',   -- Thanksgiving
        date '2020-12-25'    -- Christmas
    ]) as holiday_date
),

cleaned as (
    select
        vendor_id,
        pickup_datetime,
        dropoff_datetime,
        passenger_count,
        cast(trip_distance as float64) as trip_distance,
        rate_code,
        store_and_fwd_flag,
        payment_type,
        cast(fare_amount as float64) as fare_amount,
        cast(extra as float64) as extra,
        cast(mta_tax as float64) as mta_tax,
        cast(tip_amount as float64) as tip_amount,
        cast(tolls_amount as float64) as tolls_amount,
        cast(imp_surcharge as float64) as imp_surcharge,
        cast(airport_fee as float64) as airport_fee,
        cast(total_amount as float64) as total_amount,
        pickup_location_id,
        dropoff_location_id,
        data_file_year,
        data_file_month,

        -- date dimensions
        date(pickup_datetime) as trip_date,
        extract(year from pickup_datetime) as trip_year,
        extract(month from pickup_datetime) as trip_month,
        extract(isoweek from pickup_datetime) as trip_week,
        format_date('%A', date(pickup_datetime)) as trip_weekday,
        case extract(dayofweek from pickup_datetime)
            when 1 then 7  -- Sunday → 7
            else extract(dayofweek from pickup_datetime) - 1
        end as trip_weekday_num,

        -- time dimensions
        format_timestamp('%H:%M', pickup_datetime) as pickup_time,
        concat(
            format_timestamp('%H', pickup_datetime), ':',
            lpad(cast(cast(floor(extract(minute from pickup_datetime) / 10) * 10 as int64) as string), 2, '0')
        ) as pickup_time_block,
        extract(hour from pickup_datetime) as pickup_hour,

        -- derived flags
        timestamp_diff(dropoff_datetime, pickup_datetime, minute) as trip_duration_minutes,

        case
            when extract(hour from pickup_datetime) between 7 and 9
              or extract(hour from pickup_datetime) between 16 and 18
            then true
            else false
        end as is_peak,

        case
            when extract(dayofweek from pickup_datetime) in (1, 7)
            then true
            else false
        end as is_weekend,

        case
            when date(pickup_datetime) in (select holiday_date from us_holidays)
            then true
            else false
        end as is_holiday,

        case when payment_type = '1' then true else false end as is_card_payment,

        case when coalesce(airport_fee, 0) > 0 then true else false end as is_airport_pickup,

        -- human-readable labels
        case payment_type
            when '0' then 'Flex Fare'
            when '1' then 'Credit card'
            when '2' then 'Cash'
            when '3' then 'No charge'
            when '4' then 'Dispute'
            when '5' then 'Unknown'
            when '6' then 'Voided'
            else 'Other'
        end as payment_type_name,

        case rate_code
            when '1' then 'Standard'
            when '2' then 'JFK'
            when '3' then 'Newark'
            when '4' then 'Nassau/Westchester'
            when '5' then 'Negotiated'
            when '6' then 'Group ride'
            when '99' then 'Unknown'
            else 'Other'
        end as rate_code_name

    from source
    where fare_amount > 0
      and trip_distance > 0
      and pickup_location_id is not null
      and dropoff_location_id is not null
)

select * from cleaned
