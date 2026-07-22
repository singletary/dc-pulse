# Ranked roadmap

This roadmap contains active work only, ordered by release value, correctness risk, and dependency. See [release status](release-status.md) for current TestFlight availability and [release history](release-history.md) for completed milestones.

## Immediate release gates — critical

- Complete the current internal TestFlight verification, external assignment, and focused external soak described in [release status](release-status.md) before public App Review.
- Triage correctness, performance, migration, navigation, accessibility, location, dense Map, watched-item, alert, photo-input, and official-handoff findings.
- Complete App Store Connect age rating, privacy questionnaire, review contact, export compliance, build selection, and manual-release configuration only after the physical-device and external-beta gates are stable.
- Keep signing, capabilities, entitlements, bundle identifiers, certificates, provisioning, and Apple-account configuration unchanged without explicit approval.

## Near-term discovery TODO — P0/P1

The measurement plan, test matrix, home-screen concepts, and decision gates are maintained in [Map performance and Near You discovery](map-performance-home-discovery.md).

- [ ] **P0 — Make Map loading and partial-failure status legible and actionable.** Reproduce truncation, identify the exact pass and source behind each warning, use honest staged or measurable progress, and provide accessible detail and retry actions.
- [ ] **P0 — Establish a repeatable Map performance baseline.** Measure cold and warm time to interaction, first markers, useful close-in coverage, and completed bounded coverage for every radius. Attribute time to transport, pagination, decoding, mapping, merging, annotations, and clustering.
- [ ] **P1 — Prototype cached-first Map loading with per-source reconciliation.** Evaluate a bounded multi-context cache that can show labeled cached markers immediately, refresh sources independently, use reliable update fields where supported, and preserve cached records through partial failures.
- [ ] **P1 — Simplify Near You around one primary snapshot.** Audit usefulness and duplication, review Snapshot-first, Personalized-first, and Map-preview concepts, and record the selected hierarchy before implementation.
- [ ] **P1 — Decide the default radius from evidence.** Compare 0.25 and 0.5 miles for correctness, latency, request volume, meaningful-result rate, density, legibility, and usefulness. Do not reduce the radius to conceal incomplete or slow loading.

## 1. Release stability and data correctness — critical

- Trace any missing nearby record through ArcGIS paging, transfer limits, per-source allocation, cache acceptance, filtering, clustering, and final annotations.
- Define and test the same-center radius inclusion invariant: with equal filters and period, every identifier returned at 0.25 mile must remain available at 0.5 and 1 mile, subject only to explicit source failure.
- Verify the current independent close-in and selected-radius passes on physical iPhones before treating radius inclusion as closed.
- Add deterministic coverage for delayed and out-of-order summaries, cancellation, cache-hit refresh, rapid context changes, offline recovery, partial sources, and stale-generation rejection.
- Validate approximate location, the 25-mile near/far threshold, every side of the District boundary, relaunch recovery, and later transition to a valid in-DC location. Replace the rectangular service envelope if physical testing finds misleading edge behavior.
- Run a physical-device stress pass with rapid source, category, status, radius, period, location, and reset changes.
- Repeat the live 311, Building Permit, and DDOT schema audit before each TestFlight release and update fixtures when contracts change.
- Add privacy-safe diagnostics for refresh and coverage failures without collecting precise location or saved addresses.

## 2. App Store release readiness — critical

- Complete accessibility, Dynamic Type, VoiceOver, Reduce Motion, Light/Dark Mode, and smallest-screen checks.
- Verify production icon, screenshots, privacy report, public URLs, About content, attribution, and the independent-app disclosure in the selected release build.
- Complete the focused external beta pass described in [release status](release-status.md) before public App Review.
- Use [App Store readiness](app-store-readiness.md) as the operational gate and [App Store listing](app-store-listing.md) as copy-ready metadata.

## 3. Direct 311 submission discovery — high, contract-gated

This remains the highest-priority product-development track after TestFlight stabilization. Do not implement direct submission until discovery identifies a supported, permissioned, production-appropriate mechanism.

- Finish camera-unavailable, denied/restricted camera, limited Photos, cancellation, picker-error, and reselection behavior without losing the draft.
- Verify on a physical iPhone that Camera and Photos reach the same on-device analysis and editable review flow.
- Identify how recently reported third-party apps submit DC 311 requests: documented API, partner agreement, supported deep link, web parameters, or an unofficial endpoint.
- Document authentication, fields, categories, photo handling, rate limits, terms, confirmation behavior, and a safe non-production verification approach.
- Do not automate the public portal, depend on private Salesforce interfaces, or send live test requests without deliberate approval.
- If a supported route exists, design an injected client with idempotency, cancellation, validation, retry boundaries, and a returned DC confirmation number while preserving official handoff fallback.
- Keep every inferred photo/category/location value editable and never represent a draft as submitted without DC confirmation.

## 4. Nearby restaurant inspection ingestion — high, data-gated

- Ship nearby inspection results only after verifying a stable supported source or approving a separately reviewed ingestion service.
- Center the future map on the active search location and default to closures, follow-up-required inspections, and Priority/Priority Foundation violations, with an explicit all-reports filter.
- Include establishment, inspection date, outcome, notable violations, freshness, and authoritative attribution in every result.
- If scraping is the only route, require a legal, reliability, caching, rate-limit, maintenance, and operating-cost review; run it as monitored server-side ingestion rather than on-device scraping.
- Add versioned payloads, source-change detection, fixture/schema tests, stale-data warnings, health monitoring, and a kill switch before exposure.
- Until useful nearby data exists, do not present generic links as location-specific reports.

## 5. Opportunistic background notifications — high, capability-gated

- Add an injectable background-refresh scheduler, register and reschedule app-refresh work, handle expiration/cancellation, report success accurately, and apply retry/backoff.
- Coalesce foreground and background refreshes to prevent duplicate alerts.
- Add source-specific identifier refresh and batching for 311, Building Permits, and DDOT permits.
- Refresh auto-watch regions with bounded recent windows and deduplicate events by source, identifier, event type, and observed state.
- Preserve the distinction between normalized lifecycle changes and silent age-derived New-to-Active presentation changes.
- Add recovery UI when notifications or Background App Refresh are disabled.
- Test allowed, denied, offline, low-power, expired, and terminated-app behavior on physical iPhones.
- Obtain explicit approval before enabling Background Modes/background fetch. Defer server polling and APNs until product use demonstrates the need.

## 6. Item-detail depth and civic actions — medium

- Simplify repeated field-copy affordances while preserving discoverable tap-to-copy, accessible announcements, and clearly labeled bulk actions.
- Validate DC 311 request-ID search, paste behavior, cancellation, and official-site failure on a physical iPhone.
- Investigate only supported or permissioned record-detail links; do not guess URLs, scrape authenticated pages, or persist private Salesforce identifiers.
- Improve official permit-violation handoffs only when DOB or DDOT publishes supported address- or permit-specific parameters.
- Add focused tests for source-specific summaries, missing fields, stable formatting, and exclusion of hidden coordinates or irrelevant attributes.

## 7. Additional civic datasets — medium

- Add datasets only with source-specific adapters, fixtures, partial-failure behavior, filters, attribution, accessibility, freshness, and a documented user need.

## 8. Later product expansion — deferred

- Reassess Siri/App Intents civic queries only after iOS 27 and its public SDK behavior are stable; preserve scope, freshness, location privacy, and filtered-app handoff.
- Add a Settings-controlled Flock camera overlay only after a licensed, attributable, freshness-aware location source is verified; do not relabel generic camera layers.
- Consider widgets for Home and followed places, longer-term trend dashboards/export, and additional notification geographies after the first background-refresh model is proven.
- Consider privacy-conscious server polling and APNs only if opportunistic refresh is insufficient for demonstrated user needs.
