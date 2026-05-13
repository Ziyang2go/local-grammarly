#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


def load_env(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        os.environ.setdefault(key.strip(), val.strip().strip('"').strip("'"))


load_env(SCRIPT_DIR / ".env")

API_KEY = os.environ.get("GROQ_API_KEY")
MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")
ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"

PROMPTS = {
    "rephrase": """You rephrase Slack messages written by a non-native English speaker.

Rules:
- Make the text clear, natural, and grammatically correct English.
- Preserve the original meaning, tone, and level of formality.
- Keep it conversational — this is Slack, not a formal letter. Do not over-formalize.
- Keep code, URLs, usernames, channel names, and @mentions exactly as-is.
- Return ONLY the rephrased text. No preamble, no quotes, no explanation.""",

    "write": """You write Slack messages for the user from a short instruction. The instruction may be in imperfect English — interpret intent generously.

Rules:
- Write a clear, natural, friendly Slack message that fulfills the instruction.
- Match the tone implied by the instruction (casual, professional, urgent, etc.).
- Keep it conversational — this is Slack, not a formal letter.
- Keep code, URLs, usernames, channel names, and @mentions exactly as the user wrote them.
- Return ONLY the message text. No preamble, no quotes, no explanation.""",
}


def call_llm(system: str, user: str) -> str:
    if not API_KEY:
        sys.stderr.write("GROQ_API_KEY not set in .env\n")
        return user

    payload = json.dumps({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.3,
    }).encode()

    req = urllib.request.Request(
        ENDPOINT,
        data=payload,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
            "User-Agent": "slack-grammarly/1.0",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.load(resp)
        return data["choices"][0]["message"]["content"].strip()
    except Exception as e:
        sys.stderr.write(f"LLM call failed: {e}\n")
        return user


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=list(PROMPTS.keys()), default="rephrase")
    args = parser.parse_args()

    text = sys.stdin.read()
    if not text.strip():
        sys.exit(0)
    sys.stdout.write(call_llm(PROMPTS[args.mode], text))
