from google.genai import types

from agents.common.gemini_client import get_client, MODEL
from agents.common.schemas import AgentResponse
from agents.agent_b_dbt.prompt import SYSTEM_PROMPT_TEMPLATE
from agents.agent_b_dbt.tools import (
    TOOL_DECLARATIONS,
    build_model_context,
    handle_tool_call,
)


def ask(question: str) -> AgentResponse:
    model_context = build_model_context()
    system_prompt = SYSTEM_PROMPT_TEMPLATE.format(model_context=model_context)

    client = get_client()
    messages = [types.Content(role="user", parts=[types.Part.from_text(text=question)])]

    response = client.models.generate_content(
        model=MODEL,
        contents=messages,
        config=types.GenerateContentConfig(
            system_instruction=system_prompt,
            tools=[types.Tool(function_declarations=TOOL_DECLARATIONS)],
            temperature=0.0,
        ),
    )

    sql_used = None
    tool_calls = []
    final_text = ""

    for _ in range(10):
        candidate = response.candidates[0]
        part = candidate.content.parts[0]

        if part.function_call:
            fc = part.function_call
            tool_calls.append(f"{fc.name}({dict(fc.args)})")

            result = handle_tool_call(fc.name, dict(fc.args))
            if fc.name == "query_metrics":
                sql_used = fc.args.get("sql")

            messages.append(candidate.content)
            messages.append(
                types.Content(
                    role="user",
                    parts=[types.Part.from_function_response(name=fc.name, response={"result": result})],
                )
            )

            response = client.models.generate_content(
                model=MODEL,
                contents=messages,
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    tools=[types.Tool(function_declarations=TOOL_DECLARATIONS)],
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
        reasoning="Agent B: constrained to Databricks Unity Catalog metric views with governed semantic layer.",
        tool_calls=tool_calls,
    )
