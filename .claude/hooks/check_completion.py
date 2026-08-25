#!/usr/bin/env python3
"""Non-blocking completion reminder based on changed project files."""
import json
import subprocess
import sys

try:
    json.loads(sys.stdin.read().lstrip("\ufeff"))
except Exception:
    pass

# -uall: ohne das meldet git bei neuen Ordnern nur den Ordner selbst, dann
# bleiben frisch angelegte Dateien unsichtbar. git diff wuerde sie ganz uebersehen.
result = subprocess.run(
    ["git", "status", "--porcelain", "-uall"], capture_output=True, text=True
)
changed = [
    line[3:].strip().strip('"').replace("\\", "/")
    for line in result.stdout.splitlines()
    if len(line) > 3
]

messages = []
if any(p.endswith(".dart") for p in changed):
    messages.append(
        "Dart files changed: run format, analyze, custom_lint and affected tests "
        "before completion."
    )
if any(p.startswith("supabase/") for p in changed):
    messages.append(
        "Supabase files changed: verify migration compatibility and RLS "
        "positive/negative tests."
    )

if messages:
    print("\n".join(messages))
sys.exit(0)
