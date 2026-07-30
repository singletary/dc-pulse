# Ranked roadmap

This roadmap contains active work only, ordered by release value, correctness risk, and dependency. See [release status](release-status.md) for current TestFlight availability and [release history](release-history.md) for completed milestones.

## Immediate release gates — critical

- Complete the current internal TestFlight verification, external assignment, and focused external soak described in [release status](release-status.md) before public App Review.
- Triage correctness, performance, migration, navigation, accessibility, location, dense Map, watched-item, alert, photo-input, and official-handoff findings.
- Complete App Store Connect age rating, privacy questionnaire, review contact, export compliance, build selection, and manual-release configuration only after the physical-device and external-beta gates are stable.
- Keep signing, capabilities, entitlements, bundle identifiers, certificates, provisioning, and Apple-account configuration unchanged without explicit approval.

## Near-term discovery TODO — P0/P1

The measurement plan, test matrix, home-screen concepts, and decision gates are maintained in [Map performance and Near You discovery](map-performance-home-discovery.md).

- [ ] **P0 — Make Map loading reliable, concise, and request-efficient.** This is the next product-engineering item after the current release gate. Keep routine refresh status quiet; rewrite incomplete-coverage messages in plain, actionable language; reproduce and fix the failure that surfaces the warning; and share/coalesce Home and Map retrieval so opening Map reuses already-loaded records instead of repeating equivalent DC 311 work.
  - July 30 tester feedback completed for build 11: the persistent text below the Map filters now shows only **Last refreshed …** during normal loaded, cached, and background-refresh states. Loading-completion, cached-marker, coverage, and similar explanatory text remain hidden unless an actionable error or partial-source failure needs to be communicated. Accessible error details and recovery actions remain available when an error is present.
  - July 30 internal TestFlight follow-up reopens this presentation work at P0: reproduce and trace the recurring **Some nearby results did not update…** state to its exact source/pass failure before changing its semantics; replace the large inline warning with a compact accessible warning icon beside **Last refreshed …**, with details and Retry available on demand; and ensure a visible progress bar advances from the real accepted completed/total coverage work whenever Map data is loading.
  - July 30 navigation follow-up: after leaving and returning to Map, the warning disappeared but **Last refreshed …** did not advance. Trace whether the warning was merely cleared during view reconstruction, the failed source actually recovered, or an accepted refresh completed without publishing its timestamp. Tab navigation alone must never fabricate a refresh time; a successfully accepted refresh must update it consistently across tab changes.
  - Preserve **Last refreshed …** while a refresh is in flight, but do not let the timestamp replace or conceal live loading progress. Determinate progress must reflect defensible repository-owned units and reach completion with the accepted result generation; use an accessible indeterminate state only when a total genuinely cannot be known.
  - Before any refresh timestamp exists, use only a compact accessible activity indicator. Do not expose internal stages, completed-unit copy, or invented precision in the routine Map interface.
  - Instrument request identity, context, source, page, cache hit, coalescing, cancellation, and completion without recording precise coordinates or saved addresses.
  - Prove with deterministic tests and request-count measurements that Home-to-Map navigation does not duplicate compatible DC 311 calls, while explicit refreshes and changed search contexts still fetch correctly.
  - Partial data should remain usable, but the interface must name what could not update, what the person can still see, and what Retry will do. Do not expose internal phrases such as **map coverage is incomplete** as the primary user message.
  - July 29 progress: Map uses determinate completed/total coverage passes, partial copy is plain and actionable, and selected-radius coverage continues the live Near You page chain instead of repeating page zero. A deterministic in-flight test now proves Map waits for and reuses the active Near You page before planning missing coverage.
  - July 29 follow-up: one same-build cold/warm pair at every radius completed on normal Wi-Fi with zero failed or timed-out source requests, so the formerly recurring DC 311 warning did not reproduce. Constrained/offline, repeated-sample, and physical-iPhone reproduction remain open.
  - July 29 follow-up: source-request diagnostics now distinguish the app deadline from transport/decode failure and retain only source, radius bucket, and page offset. DC 311 has an isolated eight-second deadline while the other public sources retain four seconds; deterministic coverage proves the override does not repeat healthy-source work. A same-build live matrix is still required before closing the blocker.
- [ ] **P0 — Establish a repeatable Map performance baseline.** Measure cold and warm time to interaction, first markers, useful close-in coverage, and completed bounded coverage for every radius. Attribute time to transport, pagination, decoding, mapping, merging, annotations, and clustering.
  - Five-pair iPhone 17 Pro Simulator baselines now cover 0.25, 0.5, and 1 mile for the 30-day context. Launch-to-first-markers improves from a 3.710-second cold median to 2.145 seconds warm at the default radius; bounded coverage remains partial in every run and live DC 311 pagination is still the leading cost. Constrained/offline and physical-iPhone matrices remain open.
  - July 29 follow-up: the capture CSV now separates timed-out requests and records privacy-safe failed source/offset pairs, so the next normal, constrained, offline-recovery, and physical runs can distinguish an app deadline from public-service failure.
- [ ] **P1 — Validate the simplified Near You snapshot.** Complete task, accessibility, and physical-device validation for the implemented Snapshot-first hierarchy, dynamic status insights, and saved-Home context.
  - Content audit and three-concept state comparison completed July 28. Snapshot-first is implemented with a focused Neighborhood Summary and up to four status-aware insights.
  - July 29 progress: automated task paths pass in the full UI suite; a largest-accessibility-text check now verifies the search context, all status controls, and Neighborhood Summary reachability on the smallest compatible installed Simulator. VoiceOver and physical-iPhone validation remain open.
  - July 29 follow-up: the focused spoken-description audit and explicit 44-point target checks cover the search context, status controls, and Neighborhood Summary. A broader audit exercise also found and corrected status-text contrast, relative-time clipping, and multiline At Home copy; screen-wide heuristic findings without an identifiable element remain unsuitable as a release gate. Manual VoiceOver order/rotor and physical-iPhone validation remain open.
  - Keep City Services hidden on Near You until supported direct 311 functionality or another approved reporting path is live and nearby Restaurant Health results have a dependable reviewed source.

## 1. Release stability and data correctness — critical

- [x] Trace any missing nearby record through ArcGIS paging, transfer limits, per-source allocation, cache acceptance, filtering, clustering, and final annotations. Source signposts expose privacy-safe radius/offset/deadline outcomes; repository and cache tests cover allocation, transfer continuation, and reconciliation; `MapItemPipeline` gives an in-memory disposition from received record through filter, coordinate eligibility, and final annotation without logging identifiers.
- [x] Define and test the same-center radius inclusion invariant: with equal filters and period, every identifier returned at 0.25 mile must remain available at 0.5 and 1 mile, subject only to explicit source failure. The deterministic test deliberately omits close-in records from wider source responses and proves the independent close-in pass restores the full identifier subset at both wider radii.
- [ ] Verify the current independent close-in and selected-radius passes on physical iPhones before treating radius inclusion as closed.
  - July 29 attempt: the paired iPhone is discoverable, but Xcode reports Developer Mode disabled. No signing or device settings were changed. Physical coverage remains open until the device is explicitly prepared for development.
- [x] Add deterministic coverage for delayed and out-of-order summaries, cancellation, cache-hit refresh, rapid context changes, offline recovery, partial sources, and stale-generation rejection.
  - July 29 completion: focused store tests now prove that a slower earlier location cannot replace the latest context, cancellation publishes no late page, transient/out-of-order summaries cannot replace newer state, fresh cache hits avoid duplicate work, stale cache survives offline refresh failure, partial sources reconcile independently, and old schema generations are rejected.
- [ ] Validate approximate location, the 25-mile near/far threshold, every side of the District boundary, relaunch recovery, and later transition to a valid in-DC location. Replace the rectangular service envelope if physical testing finds misleading edge behavior.
  - July 29 progress: deterministic policy tests cover approximate accuracy, inclusive north/south/east/west boundaries, immediately outside every side, measured points on both sides of the 25-mile threshold, authorized relaunch, permission recovery, and a later transition from outside DC to a valid current location. Physical validation of those flows remains open.
- [ ] Run a physical-device stress pass with rapid source, category, status, radius, period, location, and reset changes.
  - Blocked by the same Developer Mode requirement above; Simulator context-switch and stale-result rejection coverage passes.
- [x] Repeat the live 311, Building Permit, and DDOT schema audit before each TestFlight release and update fixtures when contracts change.
  - July 29 audit: all three live layers remain queryable point layers and contain every field required by their current adapters. `scripts/audit-live-arcgis-schemas.sh` makes this a reproducible pre-release gate; it must be rerun for every future candidate. No fixture update was required.
- [x] Add privacy-safe diagnostics for refresh and coverage failures without collecting precise location or saved addresses.
  - Refresh, pagination, and coverage failures now emit only source/pass labels, approved radius buckets, pagination limits/offsets, and retained item counts. Tests reject the private coordinate and place-name examples from recorded contexts.

## 2. App Store release readiness — critical

- [ ] Complete accessibility, Dynamic Type, VoiceOver, Reduce Motion, Light/Dark Mode, and smallest-screen checks.
  - July 29 progress: iPhone 17e UI checks pass at the largest accessibility text size, the focused accessibility-description audit passes, and all four Light/Dark portrait/landscape launch configurations pass. Copy confirmations now suppress their transition when Reduce Motion is enabled. Manual VoiceOver order/rotor and physical-device checks remain open.
- [ ] Verify production icon, screenshots, privacy report, public URLs, About content, attribution, and the independent-app disclosure in the selected release build.
  - July 30 progress: the 1024-pixel icon and both four-image screenshot sets have exact dimensions and no alpha; the source and archived privacy manifests validate; public marketing, privacy, and support routes respond; and About plus the website retain attribution and independent-app disclosures. `scripts/audit-release-assets.sh` reproduces these checks. Build 10 was archived and uploaded successfully; processed-build and physical-device verification remain open.
- [ ] Complete the focused external beta pass described in [release status](release-status.md) before public App Review.
  - Build 10 was uploaded to App Store Connect on July 30. Processing, internal physical-iPhone verification, and tester-group assignment remain open; no tester groups were changed automatically.
- [x] Use [App Store readiness](app-store-readiness.md) as the operational gate and [App Store listing](app-store-listing.md) as copy-ready metadata.

## 3. Direct 311 submission discovery — high, contract-gated

This remains the highest-priority product-development track after TestFlight stabilization. Do not implement direct submission until discovery identifies a supported, permissioned, production-appropriate mechanism.

- [x] Finish locally testable camera-unavailable, denied/restricted camera, cancellation, picker-error, and reselection behavior without losing the draft. Permission and photo-analysis races now have deterministic coverage; limited-library and physical Camera/Photos validation remain in the next item.
- Verify on a physical iPhone that Camera and Photos reach the same on-device analysis and editable review flow.
- [x] Identify the currently documented DC 311 routes and assess the legacy Open311 endpoint, partner/deep-link evidence, and unsafe private alternatives.
  - July 29 completion: current OUC sources confirm the official app, portal, phone, X, and Text DC311 channels. Read-only checks found the legacy Open311 endpoint unreachable and no current key, test, terms, or support contract. DC Pulse now offers user-controlled `NEW` and `STATUS` text handoffs without sending or pre-filling a message. See [Direct DC 311 submission discovery](direct-311-submission-discovery.md).
- [x] Document the direct-submission contract questions and a safe non-production verification approach.
  - Authentication, fields, service definitions, photo handling, contact/privacy rules, rate limits, idempotency, cancellation, confirmation behavior, terms, and an approval-gated test plan are recorded in the discovery document. Direct submission remains blocked pending a supported District contract.
- Do not automate the public portal, depend on private Salesforce interfaces, or send live test requests without deliberate approval.
- If a supported route exists, design an injected client with idempotency, cancellation, validation, retry boundaries, and a returned DC confirmation number while preserving official handoff fallback.
- Keep every inferred photo/category/location value editable and never represent a draft as submitted without DC confirmation.

## 4. Nearby restaurant inspection ingestion — high, data-gated

- Ship nearby inspection results only after verifying a stable supported source or approving a separately reviewed ingestion service.
  - July 29 follow-up: current DC Health guidance still points to the HTML inspection database and confirms pass/fail reporting plus a 24-hour-to-seven-day publication review window; no supported machine interface was found. Live exposure remains blocked.
- Center the future map on the active search location and default to closures, follow-up-required inspections, and Priority/Priority Foundation violations, with an explicit all-reports filter.
  - July 29 completion: the transport-independent query boundary now enforces the active center, finite positive radius, attention/all filter semantics, and newest-first ordering with deterministic tests.
- Include establishment, inspection date, outcome, notable violations, freshness, and authoritative attribution in every result.
  - July 29 completion: the normalized inspection model and version 1 fixture retain every required field plus coordinates, feed generation date, source URL, and report URL.
- If scraping is the only route, require a legal, reliability, caching, rate-limit, maintenance, and operating-cost review; run it as monitored server-side ingestion rather than on-device scraping.
- Add versioned payloads, source-change detection, fixture/schema tests, stale-data warnings, health monitoring, and a kill switch before exposure.
  - July 29 progress: a versioned adapter now fails closed for disabled, malformed, unsupported-version, changed-schema, stale/future, unattributed, insecure, out-of-DC, and invalid-count feeds. The errors provide future stale/health state inputs; production monitoring and a remotely operable switch remain dependent on an approved transport.
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

- Validate DC 311 request-ID search, paste behavior, cancellation, and official-site failure on a physical iPhone.
- Investigate only supported or permissioned record-detail links; do not guess URLs, scrape authenticated pages, or persist private Salesforce identifiers.
- Improve official permit-violation handoffs only when DOB or DDOT publishes supported address- or permit-specific parameters.
- [x] Add focused tests for source-specific summaries, missing fields, stable formatting, and exclusion of hidden coordinates or irrelevant attributes.
  - July 29 completion: focused item-detail tests now cover DC 311 and DDOT source-specific identifiers/date labels, whitespace-only optional fields, curated attributes, stable field order, and exclusion of address, narrative, and coordinate context from Copy All Details.

## 7. Additional civic datasets — medium

- Add datasets only with source-specific adapters, fixtures, partial-failure behavior, filters, attribution, accessibility, freshness, and a documented user need.

## 8. Later product expansion — deferred

- Reassess Siri/App Intents civic queries only after iOS 27 and its public SDK behavior are stable; preserve scope, freshness, location privacy, and filtered-app handoff.
- Add a Settings-controlled Flock camera overlay only after a licensed, attributable, freshness-aware location source is verified; do not relabel generic camera layers.
- Consider widgets for Home and followed places, longer-term trend dashboards/export, and additional notification geographies after the first background-refresh model is proven.
- Consider privacy-conscious server polling and APNs only if opportunistic refresh is insufficient for demonstrated user needs.
