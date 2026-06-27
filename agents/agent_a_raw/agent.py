from google import genai
from google.genai import types

from agents.common.gemini_client import get_client, MODEL
from agents.common.bq import run_query
from agents.common.schemas import AgentResponse
from agents.agent_a_raw.prompt import get_system_prompt

EXECUTE_SQL_TOOL = types.FunctionDeclaration(
    name="execute_sql",
    description="Execute a BigQuery SQL query and return results as JSON rows.",
    parameters=types.Schema(
        type=types.Type.OBJECT,
        properties={"sql": types.Schema(type=types.Type.STRING, description="The SQL query to execute")},
        required=["sql"],
    ),
)


def ask(question: str) -> AgentResponse:
    client = get_client()

    messages = [types.Content(role="user", parts=[types.Part.from_text(text=question)])]

    response = client.models.generate_content(
        model=MODEL,
        contents=messages,
        config=types.GenerateContentConfig(
            system_instruction=get_system_prompt(),
            tools=[types.Tool(function_declarations=[EXECUTE_SQL_TOOL])],
            temperature=0.0,
        ),
    )

    sql_used = None
    tool_calls = []
    final_text = ""

    for _ in range(5):
        candidate = response.candidates[0]
        part = candidate.content.parts[0]

        if part.function_call:
            fc = part.function_call
            sql = fc.args["sql"]
            sql_used = sql
            tool_calls.append(f"execute_sql({sql[:80]}...)")

            try:
                rows = run_query(sql)
                result_text = str(rows[:20])
            except Exception as e:
                result_text = f"ERROR: {e}"

            messages.append(candidate.content)
            messages.append(
                types.Content(
                    role="user",
                    parts=[types.Part.from_function_response(name="execute_sql", response={"result": result_text})],
                )
            )

            response = client.models.generate_content(
                model=MODEL,
                contents=messages,
                config=types.GenerateContentConfig(
                    system_instruction=get_system_prompt(),
                    tools=[types.Tool(function_declarations=[EXECUTE_SQL_TOOL])],
                    temperature=0.0,
                ),
            )
        else:
            final_text = part.text
            break

    return AgentResponse(
        question=question,
        sql=sql_used,
        answer=final_text,
        reasoning="Agent A: raw SQL against unstructured tables, no guardrails.",
        tool_calls=tool_calls,
    )
