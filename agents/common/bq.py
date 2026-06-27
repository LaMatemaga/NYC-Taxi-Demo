import os
from google.cloud import bigquery

def get_bq_client() -> bigquery.Client:
    project = os.environ["GCP_PROJECT"]
    return bigquery.Client(project=project)

def run_query(sql: str) -> list[dict]:
    client = get_bq_client()
    result = client.query(sql).result()
    return [dict(row) for row in result]
