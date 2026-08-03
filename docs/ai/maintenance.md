---
id: AI-MAINTENANCE
status: accepted
owner: ai
scope:
  - ai
load_when:
  - ai_system_review
  - continuous_improvement
---

# Continuous Improvement

## Learning loop

After meaningful tasks, ask:

- What correction was repeated?
- Which missing repository fact caused wasted exploration?
- Which rule was ambiguous or conflicting?
- Which check could become deterministic?
- Which agent/skill was unnecessary?
- Which failure escaped tests or review?

## Promotion paths

- repeated universal fact → root `CLAUDE.md`;
- path-specific invariant → `.claude/rules/`;
- repeatable procedure → skill;
- specialized context-heavy responsibility → agent;
- mandatory lifecycle action → hook/CI;
- costly durable decision → ADR;
- temporary observation → task notes only.

## Change discipline

AI-system changes require review like production code. Measure whether they reduce errors or context, not whether they sound sophisticated.

## Quarterly hygiene

- remove obsolete rules;
- detect contradictions;
- review agent overlap;
- audit tool permissions;
- inspect hook latency/failures;
- verify docs against code;
- review auto-memory content;
- update evaluation tasks.
