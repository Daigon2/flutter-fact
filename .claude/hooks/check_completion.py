#!/usr/bin/env python3
"""Non-blocking completion reminder based on changed project files."""
import json
import subprocess
import sys

try:
    json.load(sys.stdin)
except Exception:
    pass

result = subprocess.run(
    ["git", "diff", "--name-only"],
    capture_output=True,
    text=True,
)
changed = [line for line in result.stdout.splitlines() if line.strip()]
dart_changed = any(p.endswith(".dart") for p in changed)
migration_changed = any(p.startswith("supabase/") for p in changed)

messages = []
if dart_changed:
    messages.append("Dart files changed: run format, analyze, custom_lint and affected tests before completion.")
if migration_changed:
    messages.append("Supabase files changed: verify migration compatibility and RLS positive/negative tests.")

if messages:
    print("\n".join(messages))
sys.exit(0)
