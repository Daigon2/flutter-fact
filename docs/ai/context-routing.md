---
id: AI-CONTEXT
status: accepted
owner: ai
scope:
  - ai
load_when:
  - task_routing
  - orchestration
  - context_management
---

# Context Routing

## Principle

Context quality matters more than context volume.

## Context tiers

### Tier A – Always loaded

- root `CLAUDE.md`;
- small project metadata;
- currently active human instruction.

### Tier B – Task-selected

- owning feature;
- relevant ADRs;
- affected architecture/engineering standards;
- current issue/specification;
- affected tests.

### Tier C – On-demand reference

- detailed procedures in skills;
- historical decisions;
- neighboring features;
- operational runbooks.

### Tier D – Avoid unless required

- unrelated features;
- entire generated files;
- old chat transcripts;
- broad logs;
- complete dependency documentation.

## Context packet

Every delegated task should contain:

```text
Outcome
Scope
Owning feature
Relevant files
Applicable decisions
Constraints
Expected output
Verification
Escalation triggers
```

Do not pass the entire parent conversation by default.

## Exploration budget

Start narrow:

1. repository tree and named files;
2. symbols and direct callers;
3. tests;
4. adjacent contracts;
5. broader search only when evidence demands it.

## Compaction resilience

Durable task facts belong in repository files or the current task specification. Do not rely on conversation-only memory for architectural constraints.

## Deterministic task routes

## Global rule

Load the smallest sufficient context packet. Start with the task and code; add documents because a decision or risk requires them, not because they exist.

## Always loaded

1. Current human request
2. Root `CLAUDE.md`
3. Matching path-scoped `.claude/rules/*`

`START_HERE.md` is onboarding material, not a per-task requirement.

## Task routing table

| Task type | Required | Conditional | Exclude by default |
|---|---|---|---|
| Small Flutter UI change | Flutter rule, affected feature code/tests | Flutter standard, navigation/state ADR | Product roadmap, backend, release, AI metrics |
| New Flutter feature | Implement-feature skill, feature/product spec, owning domain, relevant ADRs, Flutter/testing standards | Offline, security, navigation, data flow | Unrelated feature docs and all ADRs |
| Supabase migration/RLS | Supabase rule, affected schema, ADR-001, security, data contract tests | Offline/sync, operations | Flutter UI standards |
| Bug fix | Fix-bug skill, affected code/tests, expected behavior source | relevant ADR/standard | Broad architecture unless root cause crosses boundaries |
| Refactor | Refactor skill, dependency rules, affected contracts/tests | architecture overview, ADR | Product docs unless behavior might change |
| Code review | Review skill, actual diff, affected standards/tests | security, ADR, offline | Full product and AI system docs |
| Architecture proposal | Architecture overview, domain map, dependency rules, relevant ADRs/open decisions | quality attributes, data/offline | Coding detail not implicated |
| Package addition | Package governance, affected architecture, security | vendor docs, release | Unrelated feature docs |
| Release/incident | Operations runbook, security, actual change/logs | feature contracts, migrations | General AI docs |
| Documentation change | Documentation standard, canonical source, affected code/decision | ADR template | Unrelated standards |
| AI system maintenance | AI operating model, context routing, evaluation, affected agent/skill/hook | engineering quality gates | Product details except evaluation task needs |

## Document budget

Typical task: 1 global instruction + 1 rule/skill + 1–3 canonical docs + affected code/tests.

Escalate context only when:

- a source conflict appears;
- a public contract changes;
- the task crosses feature or trust boundaries;
- persistence, auth, privacy, cost or offline semantics are involved;
- verification reveals a broader issue.

## Router algorithm

```text
classify task
→ identify owning feature and changed paths
→ load matching scoped rule
→ identify decision/risk categories
→ load one canonical document per category
→ inspect code and tests
→ expand only on evidence
```

## Anti-patterns

- reading every ADR;
- reading all engineering standards before a typo fix;
- putting complete standards into agent prompts;
- loading phase completion reports;
- treating README indexes as authoritative over canonical documents;
- semantic-searching broadly before checking obvious owning files.
