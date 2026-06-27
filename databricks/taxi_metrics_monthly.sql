CREATE OR REPLACE VIEW nyc_taxi.demo.taxi_metrics_monthly
COMMENT 'Monthly trend analysis for NYC Yellow Taxi trips (2020-2022).
Same source as taxi_metrics but intended for monthly aggregation.
Dimensions are kept at borough level (not zone) to reduce cardinality.

HOW TO USE FOR TIME-OVER-TIME ANALYSIS:
- Month-over-Month (MoM): use LAG() over (ORDER BY trip_year, trip_month)
  to get the previous month''s value, then compute % change.
- Same-month Year-over-Year (YoY): use LAG() over (PARTITION BY trip_month
  ORDER BY trip_year) to compare Jan 2022 vs Jan 2021 vs Jan 2020.
- Quarter-over-Quarter (QoQ): first GROUP BY CEIL(trip_month/3) as quarter,
  then LAG() over (ORDER BY trip_year, quarter).

EXAMPLE — MoM revenue change:
  WITH monthly AS (
    SELECT trip_year, trip_month,
           MEASURE(total_revenue) AS revenue
    FROM nyc_taxi.demo.taxi_metrics_monthly
    GROUP BY trip_year, trip_month
  )
  SELECT *, LAG(revenue) OVER (ORDER BY trip_year, trip_month) AS prev_month,
         ROUND((revenue - LAG(revenue) OVER (ORDER BY trip_year, trip_month))
         / LAG(revenue) OVER (ORDER BY trip_year, trip_month) * 100, 2) AS mom_pct
  FROM monthly ORDER BY trip_year, trip_month

EXAMPLE — Same-month YoY trip count:
  WITH monthly AS (
    SELECT trip_year, trip_month,
           MEASURE(total_trips) AS trips
    FROM nyc_taxi.demo.taxi_metrics_monthly
    GROUP BY trip_year, trip_month
  )
  SELECT *, LAG(trips) OVER (PARTITION BY trip_month ORDER BY trip_year) AS prev_year,
         ROUND((trips - LAG(trips) OVER (PARTITION BY trip_month ORDER BY trip_year))
         / LAG(trips) OVER (PARTITION BY trip_month ORDER BY trip_year) * 100, 2) AS yoy_pct
  FROM monthly ORDER BY trip_year, trip_month

CRITICAL CAVEATS:
- Same tip caveat: tip metrics ONLY reflect credit card payments.
- ToT comparisons will be NULL for the first period (no prior period).
- MoM across Dec→Jan crosses year boundaries — ORDER BY trip_year, trip_month handles this.
- Each row is one trip. Use COUNT(*) for trip counts and standard aggregations.'
WITH METRICS
LANGUAGE YAML
AS
$$
version: 1.1

source: nyc_taxi_bq.nyc_taxi_demo.fct_trips

comment: |-
  Monthly trend analysis for NYC Yellow Taxi trips (2020-2022).
  Same source as taxi_metrics but intended for monthly aggregation.
  Dimensions are kept at borough level (not zone) to reduce cardinality.

  HOW TO USE FOR TIME-OVER-TIME ANALYSIS:
  - Month-over-Month (MoM): use LAG() over (ORDER BY trip_year, trip_month)
    to get the previous month's value, then compute % change.
  - Same-month Year-over-Year (YoY): use LAG() over (PARTITION BY trip_month
    ORDER BY trip_year) to compare Jan 2022 vs Jan 2021 vs Jan 2020.
  - Quarter-over-Quarter (QoQ): first GROUP BY CEIL(trip_month/3) as quarter,
    then LAG() over (ORDER BY trip_year, quarter).

  EXAMPLE — MoM revenue change:
    WITH monthly AS (
      SELECT trip_year, trip_month,
             MEASURE(total_revenue) AS revenue
      FROM nyc_taxi.demo.taxi_metrics_monthly
      GROUP BY trip_year, trip_month
    )
    SELECT *, LAG(revenue) OVER (ORDER BY trip_year, trip_month) AS prev_month,
           ROUND((revenue - LAG(revenue) OVER (ORDER BY trip_year, trip_month))
           / LAG(revenue) OVER (ORDER BY trip_year, trip_month) * 100, 2) AS mom_pct
    FROM monthly ORDER BY trip_year, trip_month

  EXAMPLE — Same-month YoY trip count:
    WITH monthly AS (
      SELECT trip_year, trip_month,
             MEASURE(total_trips) AS trips
      FROM nyc_taxi.demo.taxi_metrics_monthly
      GROUP BY trip_year, trip_month
    )
    SELECT *, LAG(trips) OVER (PARTITION BY trip_month ORDER BY trip_year) AS prev_year,
           ROUND((trips - LAG(trips) OVER (PARTITION BY trip_month ORDER BY trip_year))
           / LAG(trips) OVER (PARTITION BY trip_month ORDER BY trip_year) * 100, 2) AS yoy_pct
    FROM monthly ORDER BY trip_year, trip_month

  CRITICAL CAVEATS:
  - Same tip caveat: tip metrics ONLY reflect credit card payments.
  - ToT comparisons will be NULL for the first period (no prior period).
  - MoM across Dec→Jan crosses year boundaries — ORDER BY trip_year, trip_month handles this.
  - Each row is one trip. Use COUNT(*) for trip counts and standard aggregations.

dimensions:
  - name: trip_year
    expr: trip_year
    comment: "Year of pickup (2020, 2021, 2022). PARTITION BY trip_month ORDER BY trip_year for same-month YoY comparisons."
    display_name: Year
    synonyms:
      - year
      - yr

  - name: trip_month
    expr: trip_month
    comment: Month number (1-12). Use with trip_year for monthly trends. CEIL(trip_month / 3) gives the quarter number (1-4).
    display_name: Month
    synonyms:
      - month
      - mo

  - name: pickup_borough
    expr: pickup_borough
    comment: "Borough of pickup: Manhattan, Brooklyn, Queens, Bronx, Staten Island, or EWR."
    display_name: Pickup Borough
    synonyms:
      - origin_borough
      - pickup_boro
      - from_borough

  - name: dropoff_borough
    expr: dropoff_borough
    comment: Borough of dropoff. Use with pickup_borough for cross-borough trends.
    display_name: Dropoff Borough
    synonyms:
      - destination_borough
      - dropoff_boro
      - to_borough

  - name: payment_type_name
    expr: payment_type_name
    comment: "Credit card, Cash, etc. IMPORTANT: filter to 'Credit card' before analyzing tips."
    display_name: Payment Method
    synonyms:
      - payment_type
      - payment_method
      - how_paid

  - name: is_peak
    expr: is_peak
    comment: True if pickup during 7-10am or 4-7pm.
    display_name: Peak Hours
    synonyms:
      - peak_hours
      - rush_hour
      - peak

  - name: is_weekend
    expr: is_weekend
    comment: True if Saturday or Sunday.
    display_name: Weekend
    synonyms:
      - weekend
      - saturday_or_sunday

  - name: is_airport_pickup
    expr: is_airport_pickup
    comment: True for LaGuardia or JFK pickups.
    display_name: Airport Pickup
    synonyms:
      - airport
      - airport_trip
      - lga_jfk

measures:
  - name: total_trips
    expr: COUNT(*)
    comment: "Total trips. Use COUNT(*) for trip counts. For MoM: LAG(MEASURE(total_trips)) OVER (ORDER BY trip_year, trip_month)."
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
      - volume
      - num_trips

  - name: total_revenue
    expr: SUM(total_amount)
    comment: "Sum of total_amount (fare + tips + tolls + surcharges + airport fees). For MoM: LAG(MEASURE(total_revenue)) OVER (ORDER BY trip_year, trip_month)."
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
      - earnings

  - name: total_fare
    expr: SUM(fare_amount)
    comment: "Sum of meter fare only. Does NOT include tips, tolls, or surcharges."
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

  - name: total_tips
    expr: SUM(CASE WHEN is_card_payment THEN tip_amount ELSE 0 END)
    comment: Sum of tips — ONLY credit card payments. Cash tips are NEVER recorded. Always filter to payment_type_name = 'Credit card'.
    display_name: Total Tips
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
      abbreviation: compact
    synonyms:
      - tips
      - gratuity
      - tip_total

  - name: total_tolls
    expr: SUM(tolls_amount)
    comment: Sum of toll charges. Zero for trips without toll crossings.
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

  - name: total_surcharges
    expr: SUM(extra + mta_tax + imp_surcharge)
    comment: Sum of extra + MTA tax ($0.50) + improvement surcharge ($0.30).
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

  - name: avg_fare
    expr: AVG(fare_amount)
    comment: "Average meter fare per trip. For YoY: compare this value across same months in different years."
    display_name: Avg Fare
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_fare
      - fare_per_trip
      - mean_fare

  - name: avg_tip_pct
    expr: "AVG(CASE WHEN is_card_payment THEN tip_amount / NULLIF(fare_amount, 0) * 100 END)"
    comment: "Average tip as % of fare. ONLY for credit card payments. For YoY: compare absolute change (not % change) since this is already a percentage."
    display_name: Avg Tip %
    format:
      type: percentage
      decimal_places:
        type: max
        places: 1
    synonyms:
      - tip_percentage
      - tip_rate
      - tipping_rate

  - name: avg_trip_distance
    expr: AVG(trip_distance)
    comment: Average trip distance in miles.
    display_name: Avg Distance (mi)
    format:
      type: number
      decimal_places:
        type: max
        places: 2
    synonyms:
      - average_distance
      - miles_per_trip
      - trip_length

  - name: avg_trip_duration
    expr: AVG(trip_duration_minutes)
    comment: Average trip duration in minutes.
    display_name: Avg Duration (min)
    format:
      type: number
      decimal_places:
        type: max
        places: 1
    synonyms:
      - average_duration
      - minutes_per_trip
      - trip_time

  - name: avg_total_amount
    expr: AVG(total_amount)
    comment: Average total charged per trip (fare + tips + tolls + surcharges).
    display_name: Avg Total Amount
    format:
      type: currency
      currency_code: USD
      decimal_places:
        type: exact
        places: 2
    synonyms:
      - average_total
      - cost_per_trip
      - price_per_ride

  - name: avg_passenger_count
    expr: AVG(passenger_count)
    comment: "Average passengers per trip. Self-reported, may undercount."
    display_name: Avg Passengers
    format:
      type: number
      decimal_places:
        type: max
        places: 1
    synonyms:
      - average_passengers
      - occupancy
      - pax_per_trip
$$;