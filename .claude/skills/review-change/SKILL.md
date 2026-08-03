---
name: review-change
description: Perform an independent FACT code review using the engineering and AI review standards.
---

# Review Change

Input: `$ARGUMENTS`

Use the canonical review procedure below and `docs/engineering/review.md`.

Review correctness, security/privacy, architecture, lifecycle/concurrency, data/sync, tests, maintainability and rollout.

Return only evidence-backed findings ordered by severity, followed by a concise overall assessment.

## Canonical workflow

Review independently from the implementation narrative.

Order:

1. user-visible correctness;
2. data loss/security/privacy;
3. architecture and ownership;
4. state lifecycle/concurrency;
5. offline, retry and duplicate behavior;
6. test adequacy;
7. readability and maintainability;
8. performance;
9. documentation and rollout.

Findings use:

```text
Severity: blocking | high | medium | low | suggestion
Location:
Problem:
Impact:
Evidence:
Recommended direction:
```

Do not manufacture findings to appear thorough. Explicitly state when no blocking issue is found.

## References

Load only the task-relevant documents selected by `docs/ai/context-routing.md`. Do not duplicate their rules here.
