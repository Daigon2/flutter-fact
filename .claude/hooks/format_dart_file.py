#!/usr/bin/env python3
"""Format a Dart file after Claude edits it, when a file path is present."""
import json
import subprocess
import sys
from pathlib import Path

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input", {})
raw = tool_input.get("file_path") or tool_input.get("path")
if not isinstance(raw, str):
    sys.exit(0)

path = Path(raw)
if path.suffix != ".dart" or not path.exists():
    sys.exit(0)

result = subprocess.run(["dart", "format", str(path)], capture_output=True, text=True)
if result.returncode != 0:
    print(result.stderr or result.stdout, file=sys.stderr)
    sys.exit(result.returncode)
