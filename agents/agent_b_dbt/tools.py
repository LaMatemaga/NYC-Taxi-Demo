import json

from google.genai import types

from agents.common.databricks import get_table_metadata, run_sql

METRIC_VIEWS = {
    "taxi_metrics": "nyc_taxi.demo.taxi_metrics",
    "taxi_metrics_monthly": "nyc_taxi.demo.taxi_metrics_monthly",
}


def build_model_context() -> str:
    sections = []
    for short_name, full_name in METRIC_VIEWS.items():
        try:
            meta = get_table_metadata(full_name)
        except Exception as e:
            sections.append(f"WARNING: could not load {full_name}: {e}")
            continue

        lines = [
            f"## Metric View: {full_name}",
            f"Type: {meta['table_type']}",
            f"Description: {meta['comment']}",
            "",
            "Columns:",
        ]
        for col in meta["columns"]:
            comment = f" — {col['comment']}" if col["comment"] else ""
            lines.append(f"  - {col['name']} ({col['type']}){comment}")
        sections.append("\n".join(lines))

    return "\n\n".join(sections)


def _classify_columns(meta: dict) -> dict:
    metric_prefixes = (
        "total_", "avg_", "min_", "max_",
        "prev_month_", "prev_year_", "prev_quarter_",
        "mom_", "yoy_", "qoq_", "quarter_",
    )
    dimensions = []
    measures = []
    for col in meta["columns"]:
        entry = {"name": col["name"], "type": col["type"], "description": col["comment"]}
        if col["name"].startswith(metric_prefixes):
            measures.append(entry)
        else:
            dimensions.append(entry)
    return {"dimensions": dimensions, "measures": measures}


TOOL_DECLARATIONS = [
    types.FunctionDeclaration(
        name="get_table_info",
        description=(
            "Get full documentation for a metric view from the Databricks Unity Catalog, "
            "including all column descriptions, data types, and caveats. "
            "Available views: taxi_metrics (detail, per-trip grain) and "
            "taxi_metrics_monthly (monthly aggregated, for MoM/YoY/QoQ trend analysis)."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "table_name": types.Schema(
                    type=types.Type.STRING,
                    description="View name: 'taxi_metrics' or 'taxi_metrics_monthly'",
                ),
            },
        ),
    ),
    types.FunctionDeclaration(
        name="list_columns",
        description=(
            "List all columns in a metric view grouped by type (dimensions vs measures). "
            "Available views: taxi_metrics, taxi_metrics_monthly."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "table_name": types.Schema(
                    type=types.Type.STRING,
                    description="View name: 'taxi_metrics' or 'taxi_metrics_monthly'",
                ),
            },
        ),
    ),
    types.FunctionDeclaration(
        name="query_metrics",
        description=(
            "Run a SQL query through Databricks SQL against the metric views. "
            "The query MUST only reference taxi_metrics and/or taxi_metrics_monthly "
            "in the nyc_taxi.demo schema."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "sql": types.Schema(
                    type=types.Type.STRING,
                    description="SQL query against the metric views",
                ),
            },
            required=["sql"],
        ),
    ),
]


def _resolve_view(args: dict) -> str | None:
    name = args.get("table_name", "taxi_metrics") or "taxi_metrics"
    if name in METRIC_VIEWS:
        return name
    return None


def handle_tool_call(name: str, args: dict) -> str:
    if name == "get_table_info":
        view = _resolve_view(args)
        if not view:
            return f"ERROR: unknown view. Available: {', '.join(METRIC_VIEWS.keys())}"
        try:
            meta = get_table_metadata(METRIC_VIEWS[view])
            return json.dumps(meta, indent=2)
        except Exception as e:
            return f"ERROR: {e}"

    elif name == "list_columns":
        view = _resolve_view(args)
        if not view:
            return f"ERROR: unknown view. Available: {', '.join(METRIC_VIEWS.keys())}"
        try:
            meta = get_table_metadata(METRIC_VIEWS[view])
            return json.dumps(_classify_columns(meta), indent=2)
        except Exception as e:
            return f"ERROR: {e}"

    elif name == "query_metrics":
        sql = args["sql"]
        try:
            rows = run_sql(sql)
            return json.dumps(rows[:50], indent=2, default=str)
        except Exception as e:
            return f"ERROR: {e}"

    return f"ERROR: unknown tool '{name}'"
