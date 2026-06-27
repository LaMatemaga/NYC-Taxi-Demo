# Demo Questions

Ask both Agent A and Agent B the same questions and compare answers.
Run: `.\.venv\Scripts\python.exe demo\run_compare.py`

## 1. Avg trips per zone during peak hours
> "What are the top 5 pickup zones by average number of trips per day during peak hours?"

**Agent A:** Returns raw zone IDs instead of names. Defines peak hours wrong (4-8pm instead of 7-10am + 4-7pm).
**Agent B:** Reads `is_peak` definition from semantic layer, returns zone names, cites peak hours definition.

---

## 2. Average tip % by payment type (THE KILLER)
> "What is the average tip percentage by payment type?"

**Agent A:** Computes tip % for ALL payment types. Cash trips show 0% — misleading because cash tips aren't recorded, not because riders don't tip. Presents this confidently without caveat.
**Agent B:** Returns NULL for non-credit-card payments and explains why: tip data is only captured for credit card transactions. Cites the semantic layer caveat.

---

## 3. Average fare per mile
> "What is the average fare per mile for taxi trips?"

**Agent A:** Same answer ($2.38), no caveats.
**Agent B:** Same answer + notes trips under 0.1 miles are excluded to avoid distortion.

---

## 4. Trip volume change 2020 → 2021
> "How did trip volume change from 2020 to 2021?"

**Agent A:** Struggles with column names, answer truncated/empty.
**Agent B:** Uses taxi_metrics_monthly with LAG(), returns +25.34% with exact counts (24.2M → 30.4M).

---

## 5. Average fare for JFK trips
> "What's the average fare for JFK trips?"

**Agent A:** Fails — can't find location column name.
**Agent B:** Uses `is_airport_pickup` flag, returns $40.36 with context about LGA/JFK.

---

## 6. Airport fee revenue
> "How much revenue comes from airport fees?"

**Agent A:** Correct answer ($5.15M), no context.
**Agent B:** Same answer + explains airport_fee is $1.75 only at LGA/JFK.

---

## 7. Month-over-month revenue trend 2022
> "What was the month-over-month revenue trend in 2022?"

**Agent A:** Burns 3 retries guessing column names, truncated answer.
**Agent B:** Full MoM table with LAG() pattern from docs. Catches December anomaly ($1,185 revenue) and flags it as likely incomplete data.
