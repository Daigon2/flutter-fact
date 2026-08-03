---
id: AI-AGENTS
status: accepted
owner: ai
scope:
  - ai
load_when:
  - agent_selection
  - agent_change
---

# Agent Catalog

## `fact-orchestrator`

Classifies complex work, builds context packets, delegates focused tasks and synthesizes results. It should not edit code merely because it can; specialists execute when delegation adds value.

## `architecture-guardian`

Read-focused architecture analysis. Identifies ownership, dependency violations, ADR impact and required decisions.

## `flutter-feature-engineer`

Implements scoped Flutter feature work using existing architecture, Riverpod and go_router conventions.

## `supabase-backend-engineer`

Implements or analyzes migrations, policies, functions, data adapters and synchronization semantics.

## `test-engineer`

Designs and implements risk-based tests. Diagnoses flaky or insufficient tests.

## `code-reviewer`

Independent, read-only review of a diff or change set. Prioritizes correctness, architecture, security and tests.

## `documentation-maintainer`

Updates durable repository documents without inventing decisions.

## Delegation principle

Use the fewest agents needed. Parallelize only independent investigations. One accountable agent/main conversation synthesizes conflicting results.
