import os
import time
import requests


def _host() -> str:
    return os.environ["DATABRICKS_HOST"].rstrip("/")


def _token() -> str:
    return os.environ["DATABRICKS_TOKEN"]


def _warehouse_id() -> str:
    return os.environ["DATABRICKS_WAREHOUSE_ID"]


def _headers() -> dict:
    return {"Authorization": f"Bearer {_token()}"}


def get_table_metadata(full_table_name: str) -> dict:
    """Fetch table/view metadata from Unity Catalog REST API.
    full_table_name: 'catalog.schema.table'
    Returns dict with name, comment, columns (with comments), table_type.
    """
    resp = requests.get(
        f"{_host()}/api/2.0/unity-catalog/tables/{full_table_name}",
        headers=_headers(),
    )
    resp.raise_for_status()
    data = resp.json()
    columns = []
    for col in data.get("columns", []):
        columns.append({
            "name": col.get("name"),
            "type": col.get("type_name"),
            "comment": col.get("comment", ""),
        })
    return {
        "name": data.get("name"),
        "full_name": data.get("full_name"),
        "table_type": data.get("table_type"),
        "comment": data.get("comment", ""),
        "columns": columns,
    }


def run_sql(sql: str, catalog: str = "nyc_taxi", schema: str = "demo") -> list[dict]:
    """Execute SQL via Databricks Statement Execution API."""
    resp = requests.post(
        f"{_host()}/api/2.0/sql/statements/",
        headers=_headers(),
        json={
            "warehouse_id": _warehouse_id(),
            "statement": sql,
            "catalog": catalog,
            "schema": schema,
            "wait_timeout": "30s",
        },
    )
    resp.raise_for_status()
    result = resp.json()

    status = result.get("status", {}).get("state")
    stmt_id = result.get("statement_id")

    while status in ("PENDING", "RUNNING"):
        time.sleep(1)
        poll = requests.get(
            f"{_host()}/api/2.0/sql/statements/{stmt_id}",
            headers=_headers(),
        )
        poll.raise_for_status()
        result = poll.json()
        status = result.get("status", {}).get("state")

    if status == "FAILED":
        error = result.get("status", {}).get("error", {})
        raise RuntimeError(f"SQL failed: {error.get('message', result)}")

    manifest = result.get("manifest", {})
    col_names = [c["name"] for c in manifest.get("schema", {}).get("columns", [])]

    rows = []
    for chunk in result.get("result", {}).get("data_array", []):
        rows.append(dict(zip(col_names, chunk)))

    return rows
