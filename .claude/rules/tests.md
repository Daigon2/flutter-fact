---
paths:
  - "test/**"
  - "integration_test/**"
---

# Test invariants

- Follow `docs/engineering/testing.md`.
- Test behavior and contracts, not private implementation.
- Control time, randomness, network and persistence.
- Cover negative and boundary paths for high-risk logic.
- Never use arbitrary sleep-based waiting.
- Treat flaky tests as defects.
