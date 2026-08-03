#!/usr/bin/env python3
"""Block reads/writes of sensitive repository paths from Claude Code hooks."""
import json
import sys
from pathlib import Path

DENIED_PARTS = {".env", "secrets", "credentials.json", "service-account.json"}
DENIED_SUFFIXES = {".jks", ".keystore", ".p12", ".pem"}

def collect_paths(value):
    paths = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in {"file_path", "path", "notebook_path"} and isinstance(child, str):
                paths.append(child)
            else:
                paths.extend(collect_paths(child))
    elif isinstance(value, list):
        for child in value:
            paths.extend(collect_paths(child))
    return paths

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)

for raw in collect_paths(payload):
    path = Path(raw)
    if any(part in DENIED_PARTS or part.startswith(".env") for part in path.parts):
        print(json.dumps({"decision": "block", "reason": f"Sensitive path denied: {raw}"}))
        sys.exit(2)
    if path.suffix.lower() in DENIED_SUFFIXES:
        print(json.dumps({"decision": "block", "reason": f"Sensitive credential file denied: {raw}"}))
        sys.exit(2)

sys.exit(0)
