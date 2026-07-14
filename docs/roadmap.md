# Ranked roadmap

This roadmap orders work by release value, correctness risk, and dependency. Items inside a priority are listed in recommended execution order.

## Progress recorded July 12, 2026

- Completed: Swift 6 actor-isolation warning cleanup for the current test suite.
- Completed: live one-record schema smoke audit for all three ArcGIS layers.
- Completed: privacy manifest with app-local UserDefaults required reason and an App Store privacy/readiness draft.
- Completed: capability-neutral watched-item identifier refresh, partial-failure isolation, persisted last-check timestamps, manual refresh, status-transition alerts, and notification-tap routing.
- Remaining capability gate: `BGTaskScheduler` registration and Background Modes/background fetch approval.

## 1. Release stability and data correctness — critical

- Run a repeatable physical-iPhone regression pass covering location authorization, out-of-DC recovery, initial loading, radius/time changes, followed-place browsing, map clustering, X compose, and notification authorization.
- Keep the Swift 6 actor-isolation warning baseline clean as new tests and concurrency boundaries are added.
- Add UI coverage for followed-place selection, loading/error recovery, item detail actions, and watched-item state restoration.
- Repeat the live 311, Building Permit, and DDOT field audit before each TestFlight release and update fixtures when a schema changes.
- Add lightweight diagnostics for refresh failures without collecting precise location or home-address telemetry.

## 2. App Store release readiness — critical

- Finalize bundle display metadata, version/build numbering, privacy descriptions, support URL, privacy-policy URL, and App Store copy.
- Complete accessibility, Dynamic Type, VoiceOver, Reduce Motion, Light/Dark Mode, and small-screen checks.
- Produce final screenshots and verify the production app icon across required sizes.
- Archive and validate a release build, then complete TestFlight internal testing before App Review submission.
- Do not change signing, capabilities, entitlements, bundle identifiers, or Apple-account configuration without explicit approval.

## 3. Opportunistic background notifications — high

Background App Refresh is the selected first-release delivery model. It is useful but scheduled at iOS's discretion; DC Pulse must not promise immediate alerts.

### Refresh foundation

- Add an injectable background-refresh scheduler; the refresh coordinator is complete and unit tested without `BGTaskScheduler`.
- Register an app-refresh task at launch, reschedule after every execution, and submit the next request whenever the app enters the background.
- Set an expiration handler, cancel in-flight work cleanly, report task success accurately, and use retry/backoff after network failures.
- Preserve the completed last-attempt/last-success persistence and Places “Last watch check” status in the background adapter.
- Coalesce foreground and background refreshes so the same item cannot create duplicate alerts.

### Watch reconciliation

- Reuse the completed source-identifier refresh for every explicitly watched request or permit independently of the visible map.
- Add source-specific identifier queries for 311, Building Permits, and DDOT permits; batch identifiers where the ArcGIS service permits it.
- Refresh auto-watch regions around Home using the selected 0.1- or 0.25-mile distance and a bounded recent time window.
- Persist enough comparison state to detect new nearby items and status changes across launches.
- Deduplicate notifications by source, record identifier, event type, and observed state.

### Notification experience

- Keep notification permission tied to explicit alert or auto-watch opt-in.
- Add separate preferences for watched-item status changes and new items near Home.
- Preserve the completed notification-to-Item Details routing and explicit unavailable-record fallback.
- Use source-aware titles and include only non-sensitive context on the lock screen.
- Add an in-app explanation that delivery timing is controlled by iOS Background App Refresh settings.
- Provide recovery UI when notifications or Background App Refresh are disabled in Settings.

### Verification and capability gate

- Add fixture-backed tests for identifier refresh, new-item detection, status transitions, deduplication, cancellation, expiration, retry/backoff, and tap routing.
- Test background launch and refresh on a physical iPhone under allowed, denied, offline, low-power, and terminated-app conditions.
- Enabling Background Modes/background fetch changes app capabilities and must receive explicit approval before implementation.
- Defer server polling and APNs until product use demonstrates a need for more reliable or timely delivery.

## 4. Trustworthy trends and history — high

- Keep `PulseObservationRecord` as the on-device normalized request index, but separate “records observed” from historical state snapshots.
- Add observation snapshots only where status-history analysis needs them; avoid unbounded duplicate storage.
- **Completed foundation:** nearby 311 trends and the Map category catalog now use complete grouped ArcGIS statistics for two equal comparison periods; trend rows open the selected category on Map, where a targeted query retrieves its records.
- Store trend query provenance, geography, period, and refresh date so the UI can explain exactly what a percentage represents.
- Add retention and migration rules and verify trend calculations across radius, followed-place, and time-range changes.

## 5. Item-detail depth and civic actions — medium

- Continue investigating verified 311 photo/comment fields and human-readable record links without scraping private or unstable Salesforce pages.
- Improve official violation-reporting handoffs if DOB or DDOT publishes supported address- or permit-specific parameters.
- **Completed foundation:** a photo-first 311 draft flow uses on-device Vision classification, reads embedded DC photo location when available, supports current-location/address fallback, requires user review, and hands a copied draft to the official portal.
- Replace the official-portal handoff with true in-app submission only if DC publishes or grants a supported write contract. Never depend on private Salesforce endpoints or represent a draft as submitted.
- Evaluate a category-specific model only with a representative, licensed, privacy-reviewed dataset; generic image classification must remain a suggestion rather than an automated decision.

## 6. Additional civic datasets — medium

- **Completed foundation:** restaurant inspection domain semantics highlight closures, follow-up requirements, and Priority/Priority Foundation violations without inventing letter grades or scores; the app links to authoritative DC Health search, guidance, and closure pages.
- Obtain or verify a stable, supported inspection data interface before adding nearby results. The current public portal is server-rendered HTML and must not be treated as a durable API without publisher approval.
- Add new datasets only with source-specific mapping, fixtures, partial-failure behavior, filters, attribution, and accessibility coverage.

## 7. Later product expansion — deferred

- Widgets for Home and followed places.
- Remote push notifications backed by a privacy-conscious polling service and APNs.
- Longer-term trend dashboards and export.
- Additional notification geographies beyond Home after the first background-refresh model is proven.
