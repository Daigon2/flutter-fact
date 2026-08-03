---
id: AI-EVALUATION
status: accepted
owner: ai
scope:
  - ai
load_when:
  - evaluation
  - ai_metrics
---

# AI Quality Metrics

Metrics are diagnostic, not individual performance targets.

## Outcome metrics

- accepted changes without rework;
- defects found after merge;
- escaped architecture violations;
- rollback/revert rate;
- flaky tests introduced;
- security/privacy findings;
- cycle time by risk class.

## Process metrics

- percentage of claims backed by executed checks;
- unnecessary files changed per task;
- review finding precision;
- human escalations that were necessary;
- missed Level 3–4 escalations;
- context loaded versus used;
- repeated correction frequency.

## System metrics

- hook failure and latency;
- agent invocation frequency and usefulness;
- skill completion success;
- CLAUDE.md/rule size and contradiction count;
- stale documentation findings.

Do not optimize token count at the cost of correctness. Do not reward agents for avoiding escalation.
