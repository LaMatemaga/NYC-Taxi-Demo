from pydantic import BaseModel

class AgentResponse(BaseModel):
    question: str
    sql: str | None = None
    answer: str
    reasoning: str
    tool_calls: list[str] | None = None
