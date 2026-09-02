# FACT Repository Instructions

## Mission

Build FACT as a secure, maintainable, multi-city Flutter app for iOS and Android. Repository documents are the source of truth; chat history is not.

## Source priority

1. Current explicit human instruction
2. Accepted product decisions and ADRs
3. Architecture documents
4. Engineering standards
5. Feature documentation and tests
6. Existing implementation patterns
7. Agent assumptions

Report conflicts instead of choosing silently.

## Global invariants

- Use pragmatic feature-first Clean Architecture.
- Riverpod 3 handles shared state and dependency composition.
- `go_router` handles typed navigation.
- Domain code imports no Flutter, Riverpod or Supabase.
- Widgets do not access repositories or vendor clients.
- Business concepts do not move into `core` for convenience.
- Preserve multi-city behavior; Munich is launch content, not a hard-coded architecture assumption.
- The mobile client is untrusted; authorization is server-enforced.

## Task routing

**Read `HANDOFF.md` first.** It states where the rebuild stands, what happened last, what comes next, and what is machine-specific about the setup. It is the only file that must be read on every session, and it is kept short on purpose.

Then use `docs/ai/context-routing.md` to load only the documents relevant to the task. Do not read all of `docs/` by default. `START_HERE.md` is onboarding material for a new contributor, not a per-task requirement.

Use skills for repeatable workflows and specialist agents only when isolated context adds value.

## Escalation

Follow `docs/ai/escalation.md`. Obtain human approval before new packages, schema/sync semantics, auth/security changes, new sensitive data, cross-feature/public contracts, recurring cost, reward economy changes or accepted-ADR violations.

## Completion

Run applicable checks from `docs/engineering/quality-gates.md`, self-review the final diff, and report:

- behavior changed;
- key files;
- checks actually executed;
- unresolved risk;
- decisions still requiring approval.

Never claim an unexecuted check passed.

When a rebuild step is finished, update `HANDOFF.md` in the same change: current state, what comes next, and one protocol entry. Record what was **surprising**, because that is the part nobody can read back out of the code. Detail belongs in `REBUILD_STATUS.md`, which tracks all 50 steps, the open decisions and the data contract traps. Keep the two apart: `HANDOFF.md` is the entry point, `REBUILD_STATUS.md` is the reference. Two documents repeating each other will drift, and a stale document is worse than none.

## Reference repository (read-only)

The FACT monorepo is a separate repository and is **never modified from here**.
It is the behavioral source of truth, not an architectural one, and **not a
quality standard**. See "The PWA is a reference, not a gold standard" below
before treating anything you find there as a template.

Path: `C:\Users\Janek Postpischil\OneDrive\DokumenteClaudeSortierung\Documents\01_Persönliches\12_Claude\Claude Code\Fact`

| Path there | What it is | How to use it |
|---|---|---|
| `02_Frontend/app/` | Live PWA (fact-cityguide.netlify.app) | Canonical source for behavior, copy, i18n keys and design tokens. Read only. |
| `08_Flutter/` | Frozen provider-based port | Look up how MapLibre markers, the 3D avatar WebView and geofencing were solved. Never copy code without rebuilding it against the target architecture. |
| `03_Backend/`, `supabase/` | Schema, RLS, RPCs | Shared with the PWA. Any change is a Level 3 decision and happens in that repository, not here. |
| `06_Planung/specs/` | Rebuild parity spec | Lists the PWA features this rebuild must cover, with file and line references into `02_Frontend/app/`. |

When PWA behavior and an accepted ADR disagree: keep the behavior, follow the
ADR for structure, and report the conflict instead of resolving it silently.

### The PWA is a reference, not a gold standard

Owner's instruction, 02.09.2026: "Die PWA ist nicht der Goldstandard, sondern
alles hier ist da, den Code besser zu machen und Fehler aufzudecken." Finding
and fixing the source's defects is a **purpose** of this rebuild, not a side
effect.

So separate two things that both look like a deviation:

- **Behavior** the source defines (a flow, a rule, a threshold, a piece of
  copy) is the reference. Follow it, and report a conflict with an ADR rather
  than resolving it yourself.
- **A measured defect** is a finding, never a template. Build it correctly,
  record the deviation with the source reference, and file the source's defect
  as a register entry.

Worked examples of the second kind, all measured: a puzzle that cannot be
solved in English because the expected answer is German data (E-08); a screen
showing its own i18n key because the key does not exist (E-28, E-63); a `||`
fallback that can never fire because `t()` returns the key (E-63); points
promised at 1.5x and credited at 1x (E-44).

**English-speaking users see English.** Hardcoded German without an i18n key
is a defect of the source, not parity to preserve. Where the source has no
wording, the missing text is a content question for the owner, not a licence to
ship the German one.

Do not ask whether an obvious defect should be reproduced. Fix it, write down
what you measured, and flag it. If the correct behavior needs a wording, a
colour or a flow decision, that part goes to the owner; the defect itself does
not.

## Windows realities

- Flutter SDK lives at `C:\flutter-fresh` and is not on PATH. `C:\flutter` is broken.
- Prefer `dart analyze` over `flutter analyze` when the Flutter tool stalls.
- This repository sits outside OneDrive on a pure ASCII path on purpose. Release
  builds fail from the OneDrive path because of the non-ASCII directory name.
- The shell is PowerShell. Backslash is not a line continuation character.
- **The shell cannot write UTF-8, and this bites every German string.** Measured
  02.09.2026: a heredoc body and command-line arguments both pass through a
  legacy codepage, so `python -c 'print("Übergabe: schließen")'` arrives as
  `?bergabe: schlie?en`. Reading, `grep`, `sed` on ASCII patterns and launching
  a script file all work fine; only text going **through** the command line is
  mangled.

  Consequences, both of which cost time in this session before the cause was
  known: ASCII transliterations (`fuer`, `haengt`) appearing in documents that
  require real umlauts, and Python `SyntaxError` on German quotation marks,
  because `„…"` closes a `"`-delimited literal while the intended closer is `“`.

  So: any script containing German text goes into a **file** via the write tool
  and is then executed. Never a heredoc, never `python -c`. If a one-liner is
  unavoidable, keep it ASCII-only and use `\uXXXX` escapes.
- **`dart format` writes before it sets the exit code.** Use
  `dart format --output=none --set-exit-if-changed lib test tool`, exactly as
  `docs/engineering/quality-gates.md` spells it. Without `--output=none` the
  gate reformats files as a side effect, which on 02.09.2026 rewrote six files
  belonging to a concurrently running agent.
