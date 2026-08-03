---
id: ARCH-CROSSCUT
status: accepted
owner: architecture
scope:
  - flutter
  - backend
load_when:
  - location
  - permissions
  - analytics
  - security
  - localization
---

# Cross-Cutting Concerns

## Error handling

- Expected business failures are typed.
- Infrastructure exceptions are translated at the data/service boundary.
- Unexpected errors are logged with stack traces and reported to crash reporting.
- UI errors contain a message key, recovery action and optional diagnostic code.
- Sensitive backend details are never shown to users.

## Logging

- Use structured logs.
- Log event name, feature, operation and correlation context.
- Never log access tokens, precise sensitive location history, email contents or private profile data.
- Debug logging and production telemetry have separate sinks.
- Each asynchronous workflow should be traceable without relying on free-form print statements.

## Analytics

- Analytics is accessed through an app-level contract.
- Features own semantic event definitions.
- Event names and properties are versioned and documented.
- Analytics must not drive core business correctness.
- Consent and privacy rules are enforced centrally.
- Avoid precise location analytics unless explicitly justified and consented.

## Crash reporting

- Vendor integration is isolated under `services/crash_reporting`.
- Expected domain failures are not crashes.
- User and environment context is minimized and privacy-reviewed.

## Configuration and environments

At minimum:

- local/development;
- staging;
- production.

Environment configuration includes Supabase endpoint/key, deep-link domains, analytics state, feature flags and map configuration. Secrets must not be committed. Client publishable keys are treated according to Supabase's security model; authorization remains enforced by backend policies.

## Feature flags

- App-wide flag transport lives under services.
- Flag interpretation belongs to the owning feature.
- Flags are not permanent architecture branches.
- Each temporary flag has an owner and removal condition.

## Location

- Device location access is mediated by a location service contract.
- Permission state is distinct from location availability.
- Domain code receives coordinates/location snapshots, not plugin objects.
- Features must handle denied, approximate, stale and unavailable location.
- Collection eligibility must not rely exclusively on easily spoofable client logic where abuse matters.

## Permissions

- Permission requests happen in context and after explanation.
- Permission plugin APIs remain outside feature domain/application logic.
- Settings redirects are presentation concerns.

## Deep links

- Deep links enter through app routing.
- Auth callback links are separated from content links.
- Unknown or unavailable city/fact/tour links produce recoverable fallback screens.
- Link parsing is typed and tested.

## Push notifications

- Transport and token lifecycle live under services.
- Notification payloads route to typed app destinations.
- Features define semantic notification handling.
- Push delivery is not treated as guaranteed.
- Duplicate and stale notifications are safe.

## Localization

- No user-visible strings in domain or data.
- Content language and UI language are distinct concepts.
- City/fact content may require fallback rules independent of app localization.
- All production screens support text expansion and pluralization.

## Accessibility

- Semantic labels for interactive map and gamification controls.
- Dynamic text scaling.
- Sufficient touch targets.
- Non-color-only state communication.
- Reduced motion support where animations are nonessential.

## Security and privacy

- Supabase Row Level Security and server-side validation are mandatory for protected data.
- Client checks improve UX but are not authorization.
- Sensitive writes should be idempotent and auditable where appropriate.
- Account deletion and export implications must be designed before launch.
- Data minimization applies to analytics, logs and location history.

## Performance

- Map rendering and marker updates are profiled separately from ordinary screens.
- Large fact collections use pagination/spatial queries.
- Images are resized and cached intentionally.
- Provider invalidation is scoped; global rebuild patterns are avoided.
- Performance budgets are added during implementation after measuring target devices.
