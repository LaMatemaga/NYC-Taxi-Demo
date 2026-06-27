"""Side-by-side comparison: Agent A (raw) vs Agent B (dbt)."""

import sys
import os
from pathlib import Path
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from agents.agent_a_raw.agent import ask as ask_a
from agents.agent_b_dbt.agent import ask as ask_b

QUESTIONS = [
    "What are the top 5 pickup zones by average number of trips per day during peak hours?",
    "What is the average tip percentage by payment type?",
    "What is the average fare per mile for taxi trips?",
    "How did trip volume change from 2020 to 2021?",
    "What's the average fare for JFK trips?",
    "How much revenue comes from airport fees?",
    "What was the month-over-month revenue trend in 2022?",
]


def run_comparison():
    for i, question in enumerate(QUESTIONS, 1):
        print(f"\n{'='*80}")
        print(f"QUESTION {i}: {question}")
        print('='*80)

        print(f"\n--- AGENT A (raw SQL) ---")
        try:
            resp_a = ask_a(question)
            print(f"SQL: {resp_a.sql}")
            print(f"Answer: {resp_a.answer}")
            if resp_a.tool_calls:
                print(f"Tool calls: {resp_a.tool_calls}")
        except Exception as e:
            print(f"ERROR: {e}")

        print(f"\n--- AGENT B (dbt-constrained) ---")
        try:
            resp_b = ask_b(question)
            print(f"SQL: {resp_b.sql}")
            print(f"Answer: {resp_b.answer}")
            if resp_b.tool_calls:
                print(f"Tool calls: {resp_b.tool_calls}")
        except Exception as e:
            print(f"ERROR: {e}")


if __name__ == "__main__":
    run_comparison()
