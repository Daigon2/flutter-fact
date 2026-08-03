---
paths:
  - "supabase/**"
  - "lib/**/data/**"
---

# Supabase invariants

- Follow ADR-001 and `docs/engineering/security.md`.
- Treat the client as untrusted; enforce authorization server-side.
- Keep Supabase/DTO types inside data adapters.
- Retried writes are idempotent where duplication is harmful.
- Migrations require compatibility, RLS tests and rollback consideration.
- Prevent account-scoped cache leakage after logout or account changes.
