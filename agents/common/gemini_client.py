import os
from google import genai

def get_client() -> genai.Client:
    api_key = os.environ["GEMINI_API_KEY"]
    return genai.Client(api_key=api_key)

MODEL = "gemini-2.5-flash"
