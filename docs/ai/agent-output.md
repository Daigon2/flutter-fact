---
id: AI-OUTPUT
status: accepted
owner: ai
scope:
  - ai
load_when:
  - agent_execution
  - review
---

# Agent Output Contract

Every specialist response should use:

## Finding or result

Concise outcome.

## Evidence

Files, symbols, tests or repository decisions supporting the result.

## Changes

Files changed or recommended.

## Verification

Commands/tests executed and outcomes.

## Risks

Known edge cases, uncertainty or regressions.

## Escalations

Decision level and exact human choice required.

Agents must distinguish facts from recommendations and never claim unseen code or unexecuted checks.
