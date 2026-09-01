---
id: ENG-SECURITY
status: accepted
owner: security
scope:
  - flutter
  - backend
load_when:
  - auth
  - authorization
  - location
  - sensitive_data
  - migration
---

# Secure Development Standard

## 1. Trust boundaries

The mobile client is untrusted.

Never rely on client code for:

- authorization;
- reward entitlement;
- anti-abuse enforcement;
- trusted timestamps;
- permanent identity proof;
- protected data filtering.

Use Supabase RLS, database constraints, trusted functions and backend validation.

### No exception, decided 2026-08-31

Two of the bullets above were put up for an exception and the exception was
refused, in these words: *"Keine Ausnahme von security.md"* (architect, on E-19).
Both are now standing rules of the rebuild, and both are stated positively so
they can be applied rather than only cited:

- **The client never determines a credited amount.** Every credit comes from a
  server call that derives the amount itself. Decided by the product owner on
  2026-08-31 while answering the reward economy.
- **The client never computes time a reward depends on.** Not a session end, not
  a bonus factor. The client may show a countdown; the server decides when the
  session ended and what it was worth.

**What this costs, so nobody has to rediscover it.** The 45-minute timer and the
final-points factor of 1.5 are client-side in the behavioural source. The session
end in phase 5 is therefore **not** buildable with parity until the backend
change exists: displaying the run is in scope, turning it into points is not. A
client-side timer here would be exactly the exception that was refused.

Related open findings, all recorded in `REBUILD_STATUS.md`: E-06 and E-24 leave
the amount and the profile row writable today, and E-52, E-54 and E-55 extend
that to foreign accounts, group coin farming and the leaderboard tables. A clean
client does not fix any of them.

## 2. Secrets

Do not commit:

- service-role keys;
- signing credentials;
- private API secrets;
- production configuration files containing secrets;
- de-obfuscation symbols to public storage.

Client publishable keys are not authorization. Protect data through policies.

## 3. Authentication

- Tokens are handled through supported secure mechanisms.
- Auth state transitions are centralized.
- Deep-link callbacks are validated.
- Logout clears sensitive local state.
- Account switching cannot expose prior-user cached data.
- Session expiry and revocation are handled explicitly.

## 4. Authorization

Every protected table/view/function has an explicit authorization model and tests.

Test:

- owner access;
- other-user denial;
- anonymous denial/allowance as designed;
- update/delete restrictions;
- privilege escalation;
- malformed IDs;
- indirect access through joins/functions.

## 5. Input validation

Validate at every trust boundary:

- deep links;
- notification payloads;
- remote data;
- local persisted migrations;
- user-generated fields;
- server function inputs.

Domain constructors protect invariants, but backend validation remains mandatory.

## 6. Location privacy

- Collect only precision needed for the feature.
- Avoid long-term location history unless explicitly designed and consented.
- Do not log precise coordinates.
- Explain permission purpose in context.
- Handle approximate location.
- Review spoofing risk for collection/reward actions.

## 7. Storage

Classify local data:

- public cache;
- account-scoped cache;
- sensitive credentials/tokens;
- pending mutations;
- diagnostic data.

Clear account-scoped data on logout/account change. Use secure storage only for secrets, not as a general database.

## 8. Logging and analytics

Never record:

- tokens;
- passwords;
- sensitive profile fields;
- exact private location trails;
- full backend responses containing personal data.

Use pseudonymous identifiers only when justified.

## 9. Dependencies

- Add packages through package governance.
- Review maintenance, ownership, licenses and native permissions.
- Patch vulnerable dependencies promptly.
- Remove unused packages.

## 10. Release hardening

- Production uses release builds.
- Symbol files are retained securely when obfuscation is enabled.
- Debug menus and test endpoints are disabled.
- Environment configuration is verified.
- Privacy disclosures match actual behavior.

## 11. Incident readiness

Security-sensitive features define:

- detection signal;
- containment action;
- affected-data assessment;
- rollback/disable mechanism;
- responsible owner.
