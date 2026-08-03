---
name: fix-bug
description: Diagnose and fix a FACT defect from evidence and root cause, with a regression test and minimal scope.
---

# Fix Bug

Input: `$ARGUMENTS`

Follow the canonical bug workflow below.

Do not begin by guessing a patch. Establish expected/actual behavior, inspect the first incorrect state, create a falsifiable hypothesis, and add a regression test where feasible.

Return root cause, fix, verification and remaining uncertainty.

## Canonical workflow

1. State expected versus actual behavior.
2. Reproduce or establish reliable evidence.
3. Locate the first incorrect state or boundary, not merely the visible symptom.
4. Form a falsifiable root-cause hypothesis.
5. Add a failing regression test where feasible.
6. Implement the smallest root-cause fix.
7. Run nearby and broad tests.
8. Check whether the same defect pattern exists elsewhere.
9. Avoid unrelated cleanup.
10. Document unresolved uncertainty and monitoring needs.

## References

Load only the task-relevant documents selected by `docs/ai/context-routing.md`. Do not duplicate their rules here.
