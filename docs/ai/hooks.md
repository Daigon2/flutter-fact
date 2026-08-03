---
id: AI-HOOKS
status: accepted
owner: ai
scope:
  - ai
  - automation
load_when:
  - hook_change
  - security
---

# Hooks Policy

## Purpose

Hooks enforce deterministic, narrow controls at lifecycle boundaries.

## Good hook uses

- block sensitive paths;
- format changed Dart files;
- validate generated files;
- prevent dangerous commands;
- remind or run bounded checks;
- record non-sensitive operational metadata.

## Bad hook uses

- hidden product decisions;
- broad autonomous code rewrites;
- slow full test suites after every edit;
- sending source code to unapproved external services;
- bypassing repository permissions;
- relying on fragile natural-language interpretation for critical security.

## Failure behavior

Security and destructive-operation hooks fail closed. Formatting and advisory hooks may fail with a visible diagnostic. CI remains the final quality authority.

## Maintenance

Hook scripts are code: lint, test and review them. Keep latency low and output actionable.
