---
id: AI-ESCALATION
status: accepted
owner: ai
scope:
  - ai
load_when:
  - task_classification
  - decision
---

# Escalation Matrix

## Level 0 – Mechanical

Agent decides and executes.

Examples:

- formatting;
- generated code refresh;
- obvious typo;
- test fixture update following an unchanged contract.

Requirements: verify and report.

## Level 1 – Local engineering

Agent decides within existing standards.

Examples:

- private refactoring inside one feature;
- extracting a widget;
- adding tests;
- choosing clear names;
- implementing explicitly specified UI behavior.

Requirements: self-review; no durable decision record unless a new pattern emerges.

## Level 2 – Local design

Agent may propose and usually implement when one option clearly fits accepted architecture.

Examples:

- new repository method;
- feature-local interface;
- notifier state shape;
- feature-internal mapper or use case;
- small performance optimization backed by measurement.

Requirements: document rationale in PR/task summary. Escalate if alternatives materially affect future work.

## Level 3 – Human approval required

Stop before implementation or isolate behind a reversible proposal.

Examples:

- new package;
- public contract;
- schema migration;
- cross-feature dependency;
- offline conflict policy;
- analytics event with new data;
- deep-link behavior;
- significant user-visible behavior not specified;
- broad refactoring.

## Level 4 – Explicit owner/risk approval

Examples:

- auth/authorization changes;
- sensitive personal/location data;
- destructive migration;
- recurring vendor cost;
- reward economy;
- account deletion;
- security control weakening;
- irreversible lock-in;
- production incident action.

## Conflict rule

When two repository sources disagree, do not choose silently. Identify both, follow the higher-priority accepted source if clear, and create an escalation if not.
