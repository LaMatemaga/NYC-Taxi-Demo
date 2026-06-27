# Agentes de datos que no inventan: construyendo confianza con dbt y Gemini

> Same model. Same data. Radically different results.

This project demonstrates how a **semantic layer** transforms an unreliable AI data agent into a trustworthy one. Two agents built with Gemini 2.5 Flash query the same 90M NYC yellow taxi trips (2020-2022) — one with raw SQL, one through Databricks Unity Catalog metric views. The governed agent scores **?/7**, the raw one **?/7**.

The thesis: **you don't need a more powerful model — you need better definitions.**

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  AGENT A — No context                                    │
│  Pregunta → Gemini Flash → SQL (guessing) → BigQuery     │
│                         ↺ retry (up to 5x)               │
│                                           → ?/7 ❌       │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  AGENT B — Governed                                      │
│  Pregunta → Gemini Flash → UC Metadata → Databricks SQL  │
│                          → Federation → BigQuery → ?/7✅ │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  DATA LAYER                                              │
│  dbt (staging+marts) → BigQuery (fct_trips)              │
│                      → Databricks Foreign Catalog        │
│                      → Unity Catalog Metric Views        │
└──────────────────────────────────────────────────────────┘
```

An SVG version of this diagram is available at `demo/notes/architecture.svg` (importable into draw.io).

## Prerequisites

- **Python 3.10+**
- **GCP account** with a project and BigQuery access
- **Databricks workspace** (free edition on GCP works) with Unity Catalog enabled
- **Gemini API key** from [Google AI Studio](https://aistudio.google.com/apikey)
- **gcloud CLI** installed and authenticated

## Step 1 — Clone and install

```bash
git clone https://github.com/YOUR_USER/nyc-taxi-trust-demo.git
cd nyc-taxi-trust-demo

python -m venv .venv
# Windows
.\.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

pip install -e .
```

## Step 2 — Configure environment variables

Copy the example and fill in your values:

```bash
cp .env.example .env
```

```env
GEMINI_API_KEY=your-gemini-api-key
GCP_PROJECT=your-gcp-project-id
BQ_DATASET=nyc_taxi_demo

DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
DATABRICKS_TOKEN=your-personal-access-token
DATABRICKS_WAREHOUSE_ID=your-sql-warehouse-id
```

## Step 3 — Authenticate with GCP

Use Application Default Credentials (no service account keys):

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_GCP_PROJECT_ID
```

## Step 4 — Run dbt to build the data layer

dbt reads from BigQuery's public NYC TLC taxi datasets and builds a clean fact table in your project.

```bash
cd dbt_taxi
dbt deps
dbt build
cd ..
```

This creates:

| Model | Type | Description |
|-------|------|-------------|
| `stg_yellow_trips` | view | Cleaned UNION of 2020+2021+2022 trips. Adds derived dimensions (is_peak, is_weekend, is_holiday, etc.). |
| `stg_taxi_zones` | view | Zone lookup (zone_name, borough). |
| `dim_zones` | table | Zone dimension. |
| `fct_trips` | table | **~90M rows.** Detail fact table — one row per trip. Joins zone names. This is the table both agents query. |

> **Note:** The dbt profile (`dbt_taxi/profiles.yml`) uses `method: oauth`. Make sure your ADC credentials are active.

## Step 5 — Set up Databricks (Agent B)

Agent B needs a Databricks workspace with Unity Catalog. If you're using Databricks Free Edition on GCP:

### 5a. Create a foreign catalog to BigQuery

In the Databricks SQL editor:

```sql
-- Create a connection to BigQuery (one-time setup)
CREATE CONNECTION bq_connection
TYPE bigquery
OPTIONS (
  GoogleServiceAccountKeyJson '{{secrets/your-scope/bq-sa-key}}'
);

-- Create a foreign catalog that mirrors your BigQuery dataset
CREATE FOREIGN CATALOG nyc_taxi_bq
USING CONNECTION bq_connection
OPTIONS (database 'YOUR_GCP_PROJECT_ID');

-- Verify it works
SELECT * FROM nyc_taxi_bq.nyc_taxi_demo.fct_trips LIMIT 5;
```

### 5b. Create the metric views

Create a schema and two metric views that add the semantic layer on top of `fct_trips`:

```sql
CREATE SCHEMA IF NOT EXISTS nyc_taxi.demo;
```

Then run the SQL files in the Databricks SQL editor:

- [`databricks/taxi_metrics.sql`](databricks/taxi_metrics.sql) — detail-level metric view (one row per trip). Includes 15 dimensions and 12 measures with rich comments, synonyms, and caveats.
- [`databricks/taxi_metrics_monthly.sql`](databricks/taxi_metrics_monthly.sql) — monthly aggregation view for trend analysis. Includes ready-to-use SQL patterns for MoM, YoY, and QoQ comparisons.

### 5c. Generate a personal access token

1. In Databricks, go to **Settings > Developer > Access tokens**
2. Click **Generate new token**
3. Copy the token into your `.env` as `DATABRICKS_TOKEN`

### 5d. Get your SQL warehouse ID

1. Go to **SQL Warehouses** in Databricks
2. Click on your warehouse → the URL contains the ID: `.../sql/warehouses/YOUR_ID`
3. Copy it into `.env` as `DATABRICKS_WAREHOUSE_ID`

## Step 6 — Test the agents

```bash
# Set encoding (Windows only)
# PowerShell: $env:PYTHONIOENCODING='utf-8'
# cmd: set PYTHONIOENCODING=utf-8

# Test Agent A (raw SQL, no context)
python -c "from agents.agent_a_raw.agent import ask; r=ask('How many trips in 2021?'); print(r.answer)"

# Test Agent B (governed, semantic layer)
python -c "from agents.agent_b_dbt.agent import ask; r=ask('How many trips in 2021?'); print(r.answer)"
```

## Step 7 — Run the comparison

```bash
python demo/run_compare.py
```

This runs 7 questions through both agents side-by-side:

| # | Question | Agent A | Agent B |
|---|----------|---------|---------|
| 1 | Top 5 pickup zones during peak hours | Raw IDs, wrong peak definition | Zone names, correct definition |
| 2 | Average tip % by payment type | Cash = 0% (misleading) | Cash = NULL + caveat |
| 3 | Average fare per mile | $2.38, no caveats | $2.38 + excludes < 0.1 mi |
| 4 | Trip volume change 2020 → 2021 | Empty/truncated | +25.34% with exact counts |
| 5 | Average fare for JFK trips | Can't find columns | $40.36 + LGA/JFK context |
| 6 | Airport fee revenue | $5.15M, no context | $5.15M + explains the fee |
| 7 | MoM revenue trend 2022 | Burns retries, truncated | Full table + catches Dec anomaly |

**Result: Agent A 2/7 vs Agent B 7/7**

## How it works

### Agent A — raw SQL

Agent A receives only the table name (`fct_trips`) in its system prompt. It must guess column names, has no documentation about data caveats, and retries up to 5 times when queries fail.

### Agent B — governed

Agent B first calls the Databricks Unity Catalog REST API to read metric view metadata: column comments, synonyms, display formats, and measure definitions. This context is injected into the system prompt before any SQL is written. The agent queries through Databricks SQL using `MEASURE()` syntax, which routes through Lakehouse Federation back to BigQuery — no data copied.

### The key insight

The dangerous hallucination isn't wrong facts — it's wrong *definitions*. When Agent A reports cash tips as 0%, it's not making up a number. The query is technically correct. But the answer tells the wrong story because the agent doesn't know that cash tips aren't recorded.

The semantic layer (metric views with rich comments, synonyms, and caveats) gives the agent the business context it needs to interpret data correctly — and to know what it *can't* know.

## Project structure

```
.
├── agents/
│   ├── agent_a_raw/            # Agent with no context
│   │   ├── agent.py            # Gemini agentic loop (5 iterations max)
│   │   └── prompt.py           # System prompt — only table name
│   ├── agent_b_dbt/            # Agent with semantic layer
│   │   ├── agent.py            # Gemini agentic loop + metadata injection
│   │   ├── prompt.py           # System prompt template with rules
│   │   └── tools.py            # get_table_info, list_columns, query_metrics
│   └── common/
│       ├── bq.py               # BigQuery client (ADC auth)
│       ├── databricks.py       # Databricks REST API client
│       └── gemini_client.py    # Gemini client (2.5 Flash)
├── databricks/
│   ├── taxi_metrics.sql        # Detail-level metric view (semantic layer)
│   └── taxi_metrics_monthly.sql # Monthly metric view for trend analysis
├── dbt_taxi/
│   ├── models/
│   │   ├── staging/            # stg_yellow_trips, stg_taxi_zones
│   │   └── marts/              # fct_trips, dim_zones
│   ├── profiles.yml            # BigQuery connection (oauth)
│   └── dbt_project.yml
├── demo/
│   ├── run_compare.py          # Side-by-side comparison script
│   └── questions.md            # Questions with expected behaviors
├── .env.example
└── pyproject.toml
```

## Tech stack

| Component | Tool | Role |
|-----------|------|------|
| LLM | Gemini 2.5 Flash | Cheapest Google model — proves reliability comes from context, not power |
| Transformations | dbt + BigQuery | Staging, cleaning, fact table |
| Semantic layer | Databricks Unity Catalog | Metric views with comments, synonyms, caveats, MEASURE() |
| Federation | Lakehouse Federation | Databricks reads BigQuery without copying data |
| Auth | GCP ADC + Databricks PAT | No service account key files |

## License

MIT
