"""Smoke tests — verify agents can be imported and basic structures work."""

import json
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

from agents.common.schemas import AgentResponse


def test_agent_response_schema():
    r = AgentResponse(
        question="test?",
        sql="SELECT 1",
        answer="42",
        reasoning="test",
        tool_calls=["execute_sql(SELECT 1)"],
    )
    assert r.question == "test?"
    assert r.sql == "SELECT 1"


def test_agent_a_importable():
    from agents.agent_a_raw import agent
    assert hasattr(agent, "ask")


def test_agent_b_importable():
    from agents.agent_b_dbt import agent
    assert hasattr(agent, "ask")


def test_agent_b_tools_load_manifest(tmp_path):
    manifest = {
        "nodes": {
            "model.dbt_taxi.fct_trips": {
                "resource_type": "model",
                "name": "fct_trips",
                "description": "Fact table",
                "columns": {"fare_amount": {"description": "The fare"}},
                "relation_name": "`project.dataset.fct_trips`",
            }
        }
    }
    manifest_file = tmp_path / "manifest.json"
    manifest_file.write_text(json.dumps(manifest))

    from agents.agent_b_dbt.tools import get_available_models
    models = get_available_models(manifest)
    assert len(models) == 1
    assert models[0]["name"] == "fct_trips"
