---
name: refactor
description: Refactor FACT code while preserving observable behavior and accepted architecture.
---

# Refactor

Input: `$ARGUMENTS`

A refactor preserves observable behavior unless separately specified.

1. Define the smell and desired boundary.
2. Identify behavioral safety net.
3. Add characterization tests when coverage is weak.
4. Split mechanical movement from behavior changes.
5. Keep public contracts stable unless approved.
6. Run architecture and performance checks.
7. Remove obsolete code and documentation.
8. Report whether behavior remained unchanged.

## References

Load the owning feature, affected tests, `docs/architecture/dependency-rules.md`, and only the relevant engineering standards.
