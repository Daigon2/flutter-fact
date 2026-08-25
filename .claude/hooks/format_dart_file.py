#!/usr/bin/env python3
"""Format a Dart file after Claude edits it, when a file path is present.

Windows: `dart` liegt hier nicht im PATH, deshalb PATH-Suche mit SDK-Fallback.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

FALLBACK_DART = [r"C:\flutter-fresh\bin\dart.bat", r"C:\flutter-fresh\bin\dart"]


def find_dart():
    found = shutil.which("dart")
    if found:
        return found
    for candidate in FALLBACK_DART:
        if os.path.exists(candidate):
            return candidate
    return None


try:
    payload = json.loads(sys.stdin.read().lstrip("\ufeff"))
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input", {})
raw = tool_input.get("file_path") or tool_input.get("path")
if not isinstance(raw, str):
    sys.exit(0)

path = Path(raw)
if path.suffix != ".dart" or not path.exists():
    sys.exit(0)

dart = find_dart()
if dart is None:
    sys.exit(0)

result = subprocess.run([dart, "format", str(path)], capture_output=True, text=True)
if result.returncode != 0:
    print(result.stderr or result.stdout, file=sys.stderr)
    sys.exit(result.returncode)
