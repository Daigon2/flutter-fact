---
id: ENG-PRINCIPLES
status: accepted
owner: engineering
scope:
  - all
load_when:
  - implementation
  - review
---

# FACT Engineering Handbook v1.0

## 1. Purpose

This handbook defines the engineering system used to build the FACT Flutter application. It applies equally to human contributors and AI agents.

The handbook complements the architecture baseline:

- Architecture defines where responsibilities belong.
- Engineering standards define how work is implemented and verified.
- AI collaboration rules will later define how agents execute this work.

## 2. Engineering values

### Correctness before speed

Fast delivery is useful only when behavior remains trustworthy. Collection, progression, identity, rewards and synchronization receive stronger verification than cosmetic UI changes.

### Simplicity before abstraction

Introduce the smallest design that solves the current problem while preserving architecture boundaries.

### Explicit behavior

State changes, side effects, ownership and failure modes must be visible in code.

### Small changes

Prefer small pull requests with one coherent outcome. Large changes are split by behavior or layer where they can remain independently valid.

### Tests as executable expectations

Tests describe behavior, invariants and public contracts. They should survive internal refactoring.

### Warnings are work

Analyzer, lint, test and CI warnings are not accepted as background noise.

### Production ownership

The author of a change considers observability, failure recovery, data migration, rollback and user impact.

### Same bar for AI and humans

Generated code is reviewed, tested and held to the same standards. AI output is never accepted solely because it compiles.

## 3. Standard delivery loop

```text
Understand requirement
  ↓
Identify owning feature and affected architecture
  ↓
Define behavior and edge cases
  ↓
Implement smallest coherent change
  ↓
Add or update tests
  ↓
Run local quality gates
  ↓
Self-review diff
  ↓
Open pull request
  ↓
Automated checks + code review
  ↓
Merge
  ↓
Observe release
```

## 4. Required local verification

Before a pull request is marked ready:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart run tool/check_architecture.dart
```

Riverpod lint is deliberately absent from this list: `riverpod_lint` via
`custom_lint` is currently not installable. `quality-gates.md`, section "Accepted
deviation: no Riverpod lint", holds the dependency chain, the rules that remain
review-only and the condition for reinstating the requirement.
`tool/check_architecture.dart` replaces the boundary part of that coverage, not
the Riverpod-specific rules.

Add integration, backend or platform-specific checks when the change affects those areas.

## 5. Change classification

### Low risk

Examples:

- copy changes;
- local styling;
- isolated noninteractive widget;
- documentation.

Requires focused verification and appropriate tests where behavior exists.

### Medium risk

Examples:

- new screen;
- state-flow change;
- repository query;
- navigation change;
- analytics instrumentation.

Requires unit/widget tests and explicit manual verification.

### High risk

Examples:

- authentication;
- authorization;
- collection/reward logic;
- sync and persistence;
- schema migrations;
- background work;
- account deletion;
- payments if introduced.

Requires design review, negative tests, integration coverage, rollout/rollback plan and observability.

## 6. Escalation triggers

A contributor or agent must request an architectural/product decision before:

- changing domain ownership;
- introducing a new framework;
- changing persistence semantics;
- changing authentication or authorization;
- creating a new cross-feature dependency;
- changing reward economy;
- changing public deep links;
- collecting new sensitive data;
- introducing recurring cost or vendor lock-in;
- violating an accepted ADR.
