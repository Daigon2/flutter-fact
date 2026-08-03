---
id: ENG-DOD
status: accepted
owner: engineering
scope:
  - all
load_when:
  - task_completion
  - pull_request
---

# Definition of Done

A change is done only when all applicable items are satisfied.

## Product and behavior

- [ ] Acceptance criteria are met.
- [ ] Empty, loading, error and retry behavior are defined.
- [ ] Accessibility and localization are considered.
- [ ] Analytics behavior is deliberate, including no-event decisions.

## Architecture

- [ ] Owning feature is clear.
- [ ] Dependency rules are respected.
- [ ] No unnecessary new abstraction or package was introduced.
- [ ] ADR/open-decision impact was checked.
- [ ] Multi-city assumptions are preserved.

## Implementation

- [ ] Code is formatted and analyzer-clean.
- [ ] State is immutable.
- [ ] Errors are not silently swallowed.
- [ ] No secrets or sensitive logs are added.
- [ ] TODOs have owner/issue/removal condition.
- [ ] Generated code is current.

## Tests

- [ ] Relevant unit/notifier/widget/integration tests exist.
- [ ] Boundary and negative cases are covered.
- [ ] Tests are deterministic.
- [ ] Manual verification is documented where required.

## Data and backend

- [ ] Migrations are forward-safe and reviewed.
- [ ] RLS/authorization is tested.
- [ ] Offline/sync behavior is defined.
- [ ] Idempotency is considered for retried writes.
- [ ] Rollback/data recovery is considered.

## Review and release

- [ ] PR template is complete.
- [ ] Final diff was self-reviewed.
- [ ] CI passes.
- [ ] UI evidence is attached where applicable.
- [ ] Observability and rollout risk are addressed.
- [ ] Documentation is updated.

A checkbox may be marked not applicable only when the reason is obvious or stated.
