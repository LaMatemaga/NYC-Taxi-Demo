-- The metric view can't be created inside the foreign catalog (nyc_taxi_bq) — federation is read-only.
-- You need to create it in your local Databricks catalog instead, pointing its source at the federated table.
--CREATE CATALOG IF NOT EXISTS nyc_taxi;
--CREATE SCHEMA IF NOT EXISTS nyc_taxi.demo;

CREATE OR REPLACE VIEW nyc_taxi.demo.taxi_metrics
COMMENT 'NYC Yellow Taxi trip metrics for 2020-2022 (90M+ trips across 3 full years).
Source: NYC Taxi & Limousine Commission (TLC) public trip record data, federated from BigQuery via dbt.
Grain: one row per individual trip record. Dimensions and raw fare columns are exposed directly.

HOW TO QUERY THIS TABLE:
- This is a row-level fact table. Use COUNT(*) for trip counts and standard aggregations (SUM, AVG, MIN, MAX).
- Filter dimensions normally: WHERE trip_year = 2022 AND pickup_borough = ''Manhattan''.

CRITICAL DATA CAVEATS:
1. TIP DATA IS INCOMPLETE: tip_amount is ONLY recorded for credit card payments
   (payment_type_name = ''Credit card''). Cash tips are NEVER captured by the taxi meter
   and appear as $0.00. This means all tip metrics (avg_tip_pct, avg_tip_amount,
   total_tips, min_tip, max_tip) are meaningful ONLY when filtered to credit card
   payments. Including cash payments will artificially deflate tip averages.
2. AIRPORT FEE: airport_fee ($1.75) applies ONLY to pickups at LaGuardia (LGA) and
   JFK airports. It is $0 for all other locations. The is_airport_pickup flag marks
   these trips.
3. SURCHARGES: total_surcharges combines three separate charges: extra (rush hour
   and overnight surcharges), mta_tax ($0.50 flat), and improvement surcharge ($0.30 flat).
4. FARE PER MILE: avg_fare_per_mile excludes trips shorter than 0.1 miles to avoid
   division-by-near-zero distortion.
5. PEAK HOURS: is_peak = true when pickup is 7-10am OR 4-7pm on any day (weekday or weekend).
6. HOLIDAYS: is_holiday covers all US federal holidays 2020-2022 including observed dates
   (e.g., if July 4 falls on Saturday, Friday July 3 is also flagged).
7. PASSENGER COUNT: self-reported by driver, may be inaccurate. 0 usually means not recorded.
8. STORE AND FORWARD: trips with store_and_fwd_flag = ''Y'' were recorded in the vehicle''s
   memory due to lack of connectivity and uploaded later — timestamps may be less precise.
9. SOURCE FILTERING: trips with fare <= $0, distance <= 0, null pickup/dropoff locations,
   or timestamps outside 2020-2022 have already been removed from this dataset.'
WITH METRICS
LANGUAGE YAML
AS
$$
version: 1.1

source: nyc_taxi_bq.nyc_taxi_demo.fct_trips

comment: |-
  NYC Yellow Taxi trip metrics for 2020-2022 (90M+ trips across 3 full years).
  Source: NYC Taxi & Limousine Commission (TLC) public trip record data, federated from BigQuery via dbt.
  Grain: one row per individual trip record. Dimensions and raw fare columns are exposed directly.

  HOW TO QUERY THIS TABLE:
  - This is a row-level fact table. Use COUNT(*) for trip counts and standard aggregations (SUM, AVG, MIN, MAX).
  - Filter dimensions normally: WHERE trip_year = 2022 AND pickup_borough = 'Manhattan'.

  CRITICAL DATA CAVEATS:
  1. TIP DATA IS INCOMPLETE: tip_amount is ONLY recorded for credit card payments
     (payment_type_name = 'Credit card'). Cash tips are NEVER captured by the meter
     and appear as $0.00. This means all tip metrics (avg_tip_pct, avg_tip_amount,
     total_tips, min_tip, max_tip) are meaningful ONLY when filtered to credit card
     payments. Including cash payments will artificially deflate tip averages.
  2. AIRPORT FEE: airport_fee ($1.75) applies ONLY to pickups at LaGuardia (LGA) and
     JFK airports. It is $0 for all other locations. The is_airport_pickup flag marks
     these trips.
  3. SURCHARGES: total_surcharges combines three separate charges: extra (rush hour
     and overnight surcharges), mta_tax ($0.50 flat), and improvement_surcharge ($0.30 flat).
  4. FARE PER MILE: avg_fare_per_mile excludes trips shorter than 0.1 miles to avoid
     division-by-near-zero distortion.
  5. PEAK HOURS: is_peak = true when pickup is 7-10am OR 4-7pm on any day (weekday or weekend).
  6. HOLIDAYS: is_holiday covers all US federal holidays 2020-2022 including observed dates
     (e.g., if July 4 falls on Saturday, Friday July 3 is also flagged).
  7. PASSENGER COUNT: self-reported by driver, may be inaccurate. 0 usually means not recorded.
  8. STORE AND FORWARD: trips with store_and_fwd_flag = 'Y' were recorded in the vehicle's
     memory due to lack of connectivity and uploaded later — timestamps may be less precise.
  9. SOURCE FILTERING: trips with fare <= $0, distance <= 0, null pickup/dropoff locations,
     or timestamps outside 2020-2022 have already been removed from this dataset.

dimensions:
  - name: trip_date
    expr: trip_date
    comment: "Pickup date in yyyy-mm-dd format. Use this for daily trends, day-level comparisons, and date range filters. To aggregate by month or year, use trip_month and trip_year instead."
    display_name: Trip Date
    format:
      type: date
      date_format: year_month_day
      leading_zeros: true
    synonyms:
      - date
      - pickup_date
      - day

  - name: trip_year
    expr: trip_year
    comment: "Year of pickup (2020, 2021, or 2022). Use for year-over-year comparisons. Full calendar years available for all three years."
    display_name: Year
    synonyms:
      - year
      - yr

  - name: trip_month
    expr: trip_month
    comment: Month number (1 = January through 12 = December). Use with trip_year for month-over-month or same-month year-over-year analysis.
    display_name: Month
    synonyms:
      - month
      - mo

  - name: trip_week
    expr: trip_week
    comment: ISO week number (1-53). Week 1 is the first week with a Thursday in it. Use for weekly seasonality and week-over-week comparisons.
    display_name: Week Number
    synonyms:
      - week
      - week_number
      - iso_week

  - name: trip_weekday
    expr: trip_weekday
    comment: "Full day name (Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday). Use for day-of-week patterns. Combine with is_weekend for weekday vs weekend analysis."
    display_name: Day of Week
    synonyms:
      - weekday
      - day_of_week
      - day_name

  - name: pickup_time_block
    expr: pickup_time_block
    comment: "Pickup time rounded down to the nearest 10-minute block in hh:m0 format (e.g., 08:30, 14:10). Use for intraday demand patterns at finer granularity than hourly. 144 blocks per day."
    display_name: Time Block (10 min)
    synonyms:
      - time_block
      - time_bucket
      - time_interval

  - name: pickup_hour
    expr: pickup_hour
    comment: "Hour of pickup (0-23, where 0 = midnight, 12 = noon, 23 = 11pm). Use for hourly demand patterns, shift analysis, or time-of-day pricing studies."
    display_name: Pickup Hour
    synonyms:
      - hour
      - hour_of_day

  - name: is_peak
    expr: is_peak
    comment: "True if pickup occurred during peak commute hours: 7am-10am or 4pm-7pm, any day. Note: this includes weekends and holidays — filter additionally by is_weekend or is_holiday if you want workday-only peak analysis."
    display_name: Peak Hours
    synonyms:
      - peak_hours
      - rush_hour
      - peak
      - commute_hours

  - name: is_weekend
    expr: is_weekend
    comment: True if the trip date is Saturday or Sunday. Use for weekday vs weekend demand comparisons. Combine with is_peak and is_holiday for richer segmentation.
    display_name: Weekend
    synonyms:
      - weekend
      - saturday_or_sunday

  - name: is_holiday
    expr: is_holiday
    comment: "True if the trip date is a US federal holiday or its observed date. Covers New Year's, MLK Day, Presidents' Day, Memorial Day, Juneteenth, Independence Day, Labor Day, Columbus Day, Veterans Day, Thanksgiving, and Christmas for all three years (2020-2022). When a holiday falls on a weekend, the adjacent observed weekday is also flagged."
    display_name: Holiday
    synonyms:
      - holiday
      - federal_holiday
      - public_holiday

  - name: is_airport_pickup
    expr: is_airport_pickup
    comment: "True when the trip originated at LaGuardia (LGA) or JFK airport, identified by a non-zero airport_fee. Newark (EWR) is in New Jersey and is NOT included. Use to compare airport vs city pickups."
    display_name: Airport Pickup
    synonyms:
      - airport
      - airport_trip
      - lga_jfk

  - name: pickup_zone_name
    expr: pickup_zone_name
    comment: "Official TLC taxi zone name where the trip started (e.g., 'Upper East Side North', 'JFK Airport', 'Times Sq/Theatre District'). NYC has 263 taxi zones. Use for origin analysis and route-level patterns."
    display_name: Pickup Zone
    synonyms:
      - pickup_zone
      - pickup_location
      - origin
      - from_zone

  - name: pickup_borough
    expr: pickup_borough
    comment: "Borough of the pickup zone: Manhattan, Brooklyn, Queens, Bronx, Staten Island, or EWR (Newark airport area). Most yellow taxi trips start in Manhattan."
    display_name: Pickup Borough
    synonyms:
      - origin_borough
      - pickup_boro
      - from_borough

  - name: dropoff_zone_name
    expr: dropoff_zone_name
    comment: Official TLC taxi zone name where the trip ended. Use with pickup_zone_name to analyze popular routes and origin-destination pairs.
    display_name: Dropoff Zone
    synonyms:
      - dropoff_zone
      - dropoff_location
      - destination
      - to_zone

  - name: dropoff_borough
    expr: dropoff_borough
    comment: "Borough of the dropoff zone: Manhattan, Brooklyn, Queens, Bronx, Staten Island, or EWR. Use to analyze cross-borough travel patterns."
    display_name: Dropoff Borough
    synonyms:
      - destination_borough
      - dropoff_boro
      - to_borough

  - name: payment_type_name
    expr: payment_type_name
    comment: "How the passenger paid: Credit card, Cash, No charge, Dispute, Unknown, Voided, or Flex Fare. IMPORTANT: tip data is ONLY available for 'Credit card' payments. Always filter to Credit card before analyzing tips."
    display_name: Payment Method
    synonyms:
      - payment_type
      - payment_method
      - pay_type
      - how_paid

  - name: rate_code_name
    expr: rate_code_name
    comment: "Fare rate applied to the trip: Standard (meter rate), JFK (flat $70 to/from Manhattan), Newark, Nassau/Westchester, Negotiated (agreed fare), or Group ride. Use to segment by trip type and pricing structure."
    display_name: Rate Code
    synonyms:
      - rate_code
      - rate_type
      - fare_type
      - pricing_tier

  - name: vendor_id
    expr: vendor_id
    comment: "Technology provider that supplied the trip record: 1 = Creative Mobile Technologies (CMT), 2 = Curb Mobility (formerly VeriFone). Use to compare data quality or coverage between vendors."
    display_name: Vendor
    synonyms:
      - vendor
      - provider
      - tpep_vendor

  - name: passenger_count
    expr: passenger_count
    comment: Number of passengers as entered by the driver. Ranges from 0-9 but values above 6 are rare and may be errors. 0 usually means the driver did not enter a count. Use for occupancy analysis but note this is self-reported and not always accurate.
    display_name: Passengers
    synonyms:
      - passengers
      - riders
      - pax
      - party_size

  - name: store_and_fwd_flag
    expr: store_and_fwd_flag
    comment: Y = trip data was stored in vehicle memory and uploaded later due to no server connection. N = trip data was sent to the server in real time. Stored-and-forwarded trips may have less precise timestamps. The vast majority of trips are N (real time).
    display_name: Store & Forward
    synonyms:
      - store_forward
      - connectivity
      - offline_trip

measures:
  - name: total_trips
    expr: COUNT(*)
    comment: "Total number of taxi trips. This is the fundamental volume metric. Each row is one trip, so COUNT(*) gives the correct count."
    display_name: Total Trips
    format:
      type: number
      decimal_places:
        type: exact
        places: 0
      abbreviation: compact
    synonyms:
      - trip_count
      - rides
      - num_trips
      - number_of_trips
      - ride_count
      - volume

  - name: total_passengers
    expr: SUM(passenger_count)
    comment: "Sum of all reported passenger counts. Divide by total_trips for average occupancy. Note: passenger_count is driver-entered and 0 means not recorded, so this may undercount."
    display_name: Total Passengers
    format:
      type: number
      decimal_places:
        type: exact
        places: 0
      abbreviation: compact
    synonyms:
      - passenger_total
      - total_riders
      - total_pax
      - ridership

  - name: total_fare
    expr: SUM(fare_amount)
    comment: "Sum of meter fare amounts across all trips. This is the base fare charged by the meter — it does NOT include tips, tolls, surcharges, or airport fees. For total charges, use total_revenue instead."
    display_name: Total Fare
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - fare_total
      - gross_fare
      - meter_total
      - fare_revenue

  - name: total_tips
    expr: SUM(CASE WHEN is_card_payment THEN tip_amount ELSE 0 END)
    comment: "Sum of tip amounts. CRITICAL: only includes credit card tips. Cash tips are NEVER recorded by the taxi meter and are NOT in this data. When analyzing tips, ALWAYS filter to payment_type_name = 'Credit card' to avoid misleading results. Including cash trips makes tips appear artificially low."
    display_name: Total Tips
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - tip_total
      - tips
      - gratuity
      - total_gratuity

  - name: total_tolls
    expr: SUM(tolls_amount)
    comment: "Sum of all toll charges. Common toll routes include trips to/from JFK, LaGuardia, and cross-river bridges/tunnels. Zero for trips that don't pass through toll points."
    display_name: Total Tolls
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - tolls
      - toll_total
      - toll_revenue

  - name: total_airport_fees
    expr: SUM(COALESCE(airport_fee, 0))
    comment: Sum of airport pickup fees ($1.75 per trip at LGA or JFK). Zero for all non-airport pickups. Only meaningful when filtered to is_airport_pickup = true or airport zones.
    display_name: Total Airport Fees
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - airport_fee_total
      - airport_charges
      - airport_surcharge

  - name: total_surcharges
    expr: SUM(extra + mta_tax + imp_surcharge)
    comment: "Sum of extra charges, MTA tax ($0.50 flat), and improvement surcharge ($0.30 flat). The 'extra' component includes rush hour surcharge ($1.00 Mon-Fri 4-8pm) and overnight surcharge ($0.50 8pm-6am). Use to understand the non-fare cost burden on riders."
    display_name: Total Surcharges
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - surcharge_total
      - fees
      - extra_charges
      - additional_charges

  - name: total_revenue
    expr: SUM(total_amount)
    comment: "Sum of total_amount — the complete amount charged to the passenger including fare, tips, tolls, surcharges, and airport fees. This is the most comprehensive revenue metric. Note: cash tips are excluded (not recorded), so true revenue from cash trips is higher."
    display_name: Total Revenue
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - revenue
      - gross_revenue
      - total_sales
      - total_amount
      - gmv
      - earnings

  - name: avg_trip_distance
    expr: AVG(trip_distance)
    comment: "Average trip distance in miles. Typical Manhattan trip is 1-3 miles, airport trips are 10-20 miles. Use to understand trip length patterns by zone, time, or segment."
    display_name: Avg Trip Distance (mi)
    format:
      type: number
      decimal_places:
        type: max
        places: 2
    synonyms:
      - average_distance
      - mean_distance
      - miles_per_trip
      - trip_length

  - name: avg_trip_duration
    expr: AVG(trip_duration_minutes)
    comment: Weighted average trip duration in minutes. Includes time in traffic. Compare with avg_trip_distance to understand speed/congestion patterns. Peak hours typically show longer durations for the same distance.
    display_name: Avg Trip Duration (min)
    format:
      type: number
      decimal_places:
        type: max
        places: 1
    synonyms:
      - average_duration
      - mean_duration
      - minutes_per_trip
      - trip_time
      - ride_time

  - name: avg_fare
    expr: AVG(fare_amount)
    comment: "Average meter fare per trip in dollars. This is the base fare only — does not include tips, tolls, or surcharges. Compare across zones, times, or rate codes to understand pricing patterns. JFK flat rate trips will show ~$70."
    display_name: Avg Fare
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_fare
      - mean_fare
      - fare_per_trip
      - fare_per_ride

  - name: avg_total_amount
    expr: AVG(total_amount)
    comment: Average total amount charged per trip including all components (fare + tips + tolls + surcharges + airport fee). Represents the true average cost to the passenger (except for unrecorded cash tips).
    display_name: Avg Total Amount
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_total
      - mean_total
      - cost_per_trip
      - price_per_ride

  - name: avg_tip_pct
    expr: "AVG(CASE WHEN is_card_payment THEN tip_amount / NULLIF(fare_amount, 0) * 100 END)"
    comment: Average tip as a percentage of fare. ONLY meaningful for credit card payments. Typical range is 15-25%. Values near 0% likely indicate cash payments were incorrectly included. Always filter to payment_type_name = 'Credit card'.
    display_name: Avg Tip %
    format:
      type: percentage
      decimal_places:
        type: max
        places: 1
    synonyms:
      - tip_percentage
      - tip_rate
      - tip_percent
      - tipping_rate
      - gratuity_rate

  - name: avg_tip_amount
    expr: "AVG(CASE WHEN is_card_payment THEN tip_amount END)"
    comment: "Average tip amount in dollars per trip. ONLY meaningful for credit card payments. If this value seems surprisingly low, check whether cash payments are included in the filter — they contribute $0 tips and drag down the average."
    display_name: Avg Tip
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_tip
      - mean_tip
      - tip_per_trip
      - tip_per_ride

  - name: avg_fare_per_mile
    expr: "SUM(fare_amount) / NULLIF(SUM(CASE WHEN trip_distance > 0.1 THEN trip_distance END), 0)"
    comment: "Average fare charged per mile driven. Useful for comparing pricing efficiency across zones, times, and rate codes. Higher values indicate slower/congested routes (meter runs on time too) or premium rate codes. Excludes trips under 0.1 miles."
    display_name: Avg Fare/Mile
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - fare_per_mile
      - cost_per_mile
      - price_per_mile
      - rate_per_mile
      - unit_rate

  - name: avg_tolls
    expr: AVG(tolls_amount)
    comment: "Average toll amount per trip. Most trips have $0 tolls. Higher values indicate routes through toll bridges/tunnels (e.g., to/from airports, cross-river trips)."
    display_name: Avg Tolls
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_tolls
      - tolls_per_trip
      - mean_tolls

  - name: avg_airport_fee
    expr: AVG(COALESCE(airport_fee, 0))
    comment: "Average airport fee per trip. Only $1.75 for LGA/JFK pickups, $0 everywhere else. Useful as a proxy for airport trip share when divided by the fee amount ($1.75)."
    display_name: Avg Airport Fee
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_airport_fee
      - airport_fee_per_trip

  - name: avg_surcharges
    expr: AVG(extra + mta_tax + imp_surcharge)
    comment: "Average surcharges per trip (rush hour extra + overnight extra + MTA tax + improvement surcharge). Baseline is ~$0.80 (MTA + improvement), higher values indicate more peak/overnight trips in the group."
    display_name: Avg Surcharges
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_surcharge
      - surcharge_per_trip
      - fees_per_trip

  - name: avg_passenger_count
    expr: AVG(passenger_count)
    comment: "Average number of passengers per trip. Typical value is 1.3-1.5. Values near 0 indicate many trips where drivers did not enter passenger count. Self-reported, not verified. Use for rough occupancy estimates only."
    display_name: Avg Passengers
    format:
      type: number
      decimal_places:
        type: max
        places: 1
    synonyms:
      - average_passengers
      - pax_per_trip
      - riders_per_trip
      - occupancy

  - name: min_fare
    expr: MIN(fare_amount)
    comment: Lowest fare observed in the group. The NYC taxi minimum fare is $3.00 (initial charge). Values below $3 may exist due to rate adjustments or data anomalies.
    display_name: Min Fare
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - lowest_fare
      - minimum_fare
      - cheapest_trip

  - name: max_fare
    expr: MAX(fare_amount)
    comment: "Highest fare observed in the group. Extremely high values (>$200) are typically negotiated rate trips, out-of-city trips, or potential data errors."
    display_name: Max Fare
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - highest_fare
      - maximum_fare
      - most_expensive_trip

  - name: min_trip_distance
    expr: MIN(trip_distance)
    comment: Shortest trip distance in miles in the group. Very short trips (<0.1 mi) are already filtered out in the source data.
    display_name: Min Distance (mi)
    format:
      type: number
      decimal_places:
        type: max
        places: 2
    synonyms:
      - shortest_trip
      - minimum_distance
      - shortest_ride

  - name: max_trip_distance
    expr: MAX(trip_distance)
    comment: Longest trip distance in miles in the group. Very long trips (>50 mi) are typically to/from distant suburbs or airports and may use negotiated or out-of-city rates.
    display_name: Max Distance (mi)
    format:
      type: number
      decimal_places:
        type: max
        places: 2
    synonyms:
      - longest_trip
      - maximum_distance
      - farthest_trip
      - longest_ride

  - name: min_tip
    expr: MIN(CASE WHEN is_card_payment THEN tip_amount END)
    comment: Lowest tip amount observed. ONLY for credit card payments. $0 tips on credit cards do occur (passenger selects no tip). Cash tips are not recorded and are excluded.
    display_name: Min Tip
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - lowest_tip
      - minimum_tip
      - smallest_tip

  - name: max_tip
    expr: MAX(CASE WHEN is_card_payment THEN tip_amount END)
    comment: Highest tip amount observed. ONLY for credit card payments. Very large tips (>$50) are rare and may represent generous riders or data entry errors.
    display_name: Max Tip
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - highest_tip
      - maximum_tip
      - biggest_tip
      - largest_tip
$$;