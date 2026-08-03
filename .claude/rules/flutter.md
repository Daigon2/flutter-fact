---
paths:
  - "lib/**/*.dart"
  - "test/**/*.dart"
---

# Flutter invariants

- Follow `docs/engineering/flutter.md` and the owning feature architecture.
- Keep widgets declarative; shared mutable state uses Riverpod.
- Domain imports no Flutter, Riverpod or Supabase.
- Use typed routes; navigation remains in presentation.
- Do not access repositories from widgets.
- Preserve lifecycle safety after async gaps.
- Load `docs/engineering/testing.md` when behavior changes.
