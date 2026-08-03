---
id: ENG-GIT-PRS
status: accepted
owner: engineering
scope:
  - workflow
load_when:
  - pull_request
  - merge
---

# Git and Pull Request Workflow

## Branching

Use short-lived branches from the main integration branch.

Suggested names:

```text
feature/fact-details
fix/collection-retry
refactor/facts-mapping
chore/update-flutter
```

Avoid long-lived personal or environment branches.

## Commits

Commits should be coherent and buildable where practical.

Use imperative subjects:

```text
Add pending state to collection flow
Fix duplicate fact collection retry
Extract city selection policy
```

Do not require artificial micro-commits. Do not mix unrelated cleanup into a feature commit.

## Pull request size

A PR should deliver one coherent outcome.

Split when:

- review requires understanding several unrelated behaviors;
- architecture and feature work can be introduced safely in sequence;
- generated/mechanical changes hide behavioral changes;
- migration and cleanup can be separated.

Large PRs require an explicit review guide.

## Draft pull requests

Use draft status for early architecture/API feedback. Draft does not waive CI quality once marked ready.

## Required PR content

- purpose and user impact;
- owning feature;
- architecture/layers affected;
- screenshots/video for UI changes;
- testing performed;
- failure/edge cases;
- offline implications;
- schema or migration impact;
- analytics/privacy impact;
- rollout/rollback notes;
- related issue/decision.

## Review standard

Reviewers evaluate:

1. Correctness and edge cases
2. Architecture and ownership
3. Security/privacy
4. State and lifecycle
5. Tests
6. Readability
7. Performance where relevant
8. Migration/rollback
9. Observability
10. Scope discipline

Comments distinguish:

- **blocking** – must change;
- **question** – clarification required;
- **suggestion** – optional improvement;
- **nit** – non-blocking polish.

## Merge rules

A PR may merge when:

- required checks pass;
- blocking review comments are resolved;
- required approvals exist;
- generated code is current;
- migrations and release notes are included where needed;
- the author has self-reviewed the final diff.

Use squash merge by default unless preserving a curated commit series has clear value.

## Direct pushes

Direct pushes to the protected main branch are forbidden except documented emergency procedures.
