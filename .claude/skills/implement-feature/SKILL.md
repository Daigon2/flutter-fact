---
name: implement-feature
description: Plan and implement a scoped FACT feature using the repository architecture, engineering standards, tests, and escalation rules.
---

# Implement Feature

Input: `$ARGUMENTS`

1. Convert the request into acceptance criteria.
2. Identify owning feature, layers and risk.
3. Read relevant ADR, architecture, engineering and feature docs.
4. Inspect current code and tests.
5. List Level 3–4 decisions before changing code.
6. Implement the smallest vertical slice.
7. Add tests proportional to risk.
8. Run focused and repository quality gates.
9. Self-review the final diff.
10. Update documentation.
11. Return the standard completion summary.

Use specialists only when their isolated context adds value.

## Canonical workflow

1. Translate the request into observable acceptance criteria.
2. Identify owning domain and feature maturity level.
3. Inspect existing UI, state, repository and tests.
4. Classify decisions and escalate Level 3–4 items.
5. Design the smallest vertical slice.
6. Implement from domain/data contracts toward presentation when contracts change; otherwise follow the narrowest safe path.
7. Add tests by risk.
8. Run focused checks, then broad quality gates.
9. Self-review for scope, architecture, security, accessibility and offline behavior.
10. Request independent review for medium/high-risk work.
11. Update documentation and decision registers.
12. Report behavior, verification and risk.

## References

Load only the task-relevant documents selected by `docs/ai/context-routing.md`. Do not duplicate their rules here.
