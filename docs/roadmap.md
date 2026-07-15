# Ranked roadmap

This roadmap orders work by release value, correctness risk, and dependency. Items inside a priority are listed in recommended execution order.

## Current release state — July 14, 2026

- Internal TestFlight: version 1.0 (build 2) is installed on a physical iPhone; build 3 has been uploaded for internal testing. No public App Store submission has been made.
- Completed: Swift 6 actor-isolation warning cleanup for the current test suite.
- Completed: live one-record schema smoke audit for all three ArcGIS layers.
- Completed: privacy manifest with app-local UserDefaults required reason, copy-ready App Store metadata/review notes, and four privacy-reviewed 6.9-inch screenshots.
- Completed: capability-neutral watched-item identifier refresh, partial-failure isolation, persisted last-check timestamps, manual and throttled foreground refresh, status-transition alerts, notification-tap routing, and an on-device notification inbox with unread history.
- Completed for build 3: dismissible 311 draft keyboard, a keyboard-visible continuation control, and an official DC311 app handoff with an explicit website fallback.
- Immediate release gate: complete the build 3 physical-iPhone regression pass before external TestFlight distribution.
- Newly observed release risk: changing Map filters can intermittently leave the map sparsely populated instead of completing the expected replacement load. Reproduce and resolve this before treating the external beta as stable.
- Newly observed release risk: reducing the Map radius from 0.5 miles to 0.25 miles can reveal very close records that were absent from the wider search. For an unchanged center and filters, the smaller-radius identifiers must be a subset of the larger-radius identifiers; investigate this correctness violation before external beta expansion.
- Newly observed release risk: **Requests nearby** can show three implausible one-request category totals even after the status totals above it have refreshed; a manual refresh then corrects the categories. Treat this as a data-coherence defect before external beta expansion.
- Remaining capability gate: `BGTaskScheduler` registration and Background Modes/background fetch approval.

## 1. Release stability and data correctness — critical

- Reproduce the radius inclusion failure and trace a missing nearby record through every boundary: raw ArcGIS pages, `exceededTransferLimit` handling, per-source page allocation, cache entries, data-store acceptance, source/category/status filters, clustering, and final annotations. Distinguish a record that was never fetched from one fetched but hidden or replaced during rendering.
- Define and test the radius inclusion invariant: for the same center, sources, statuses, categories, and period, every identifier returned at 0.25 miles must also be available at 0.5 and 1 mile. Account explicitly for source failures and server-side result limits rather than silently weakening the invariant.
- Choose the final loading strategy only after finding the cause. Candidate solutions may include completing required pagination, changing result ordering to prioritize proximity where the service supports it, separating map retrieval from list pagination, or another bounded approach that guarantees nearby records without making broad searches unacceptably slow.
- Do not change the default radius merely to conceal incomplete wider-radius results. After correctness and performance are verified, separately evaluate 0.25 versus 0.5 miles as the initial product default based on usefulness, density, map legibility, and request latency while keeping the user's last explicit choice predictable.
- Standardize distance copy: use compact labels such as **0.25 mi**, **0.5 mi**, and **1 mi** in controls; use **0.5 miles** when the measurement stands alone and **0.5-mile radius** when it modifies a noun. Provide natural VoiceOver labels such as “half-mile radius.”
- Diagnose why the Near You status totals and **Requests nearby** category summary can complete with different or partial generations of data. Audit initial-load ordering, independent summary tasks, cache freshness, cancellation, error fallback, pagination/statistics responses, and whether a partial result is being published as final.
- Make the status totals, category summary, active coordinate, radius, and period share an explicit load context and refresh generation. Do not present category counts as current until they correspond to the same accepted context as the totals above; discard stale completions and distinguish a genuine small result from an incomplete summary.
- Ensure automatic initial loading reaches the same stable result as manual refresh without requiring user intervention. Preserve the last coherent summary during a replacement load or show a clear loading/error state rather than three misleading placeholder-like counts.
- Add deterministic tests for cold launch, cache hit followed by refresh, delayed/out-of-order summary responses, cancellation, partial source failure, rapid location/radius/time changes, and manual refresh. Assert that the category summary cannot publish against mismatched totals or context.
- Diagnose intermittent incomplete Map results after changing source, category, status, radius, or time filters. Verify request cancellation, stale-response rejection, pagination reset, targeted-category loading, cache keys, loading-state transitions, and rapid successive changes without assuming which layer is responsible.
- Make each accepted filter change produce one coherent result transaction: retain or clearly cover the previous annotations while loading, replace them only with results for the current filter state, complete required pagination, and never allow an older request to overwrite a newer selection.
- Add a prominent **Reset Filters** action distinct from the current-location control. It should atomically restore the documented Map defaults—every default data source, all statuses and request types, the default radius, and the last-30-days period—then force a trustworthy reload for the active search center.
- Keep location behavior separate: resetting filters must not unexpectedly move the map or change the active search center; the existing current-location action remains responsible for returning to the user's location.
- Add deterministic tests for individual changes, reset behavior, cancellation races, cache separation, empty responses, partial source failures, and rapid multi-filter changes. Include a physical-iPhone regression that compares fresh launch, changed filters, and reset results for the same location.
- **Completed in build 3:** the new-311 draft supports keyboard dismissal, keeps its continuation action reachable, and has UI coverage for continuing while the keyboard is visible.
- **Completed in build 3:** the 311 handoff offers the official DC311 app as its primary route and retains the official website as an explicit fallback instead of silently opening a blank page.
- Run a repeatable physical-iPhone regression pass covering location authorization, out-of-DC recovery, initial loading, radius/time changes, followed-place browsing, map clustering, X compose, and notification authorization.
- Keep the Swift 6 actor-isolation warning baseline clean as new tests and concurrency boundaries are added.
- Add UI coverage for followed-place selection, loading/error recovery, item detail actions, and watched-item state restoration.
- Repeat the live 311, Building Permit, and DDOT field audit before each TestFlight release and update fixtures when a schema changes.
- Add lightweight diagnostics for refresh failures without collecting precise location or home-address telemetry.

## 2. App Store release readiness — critical

- **Completed package:** bundle display metadata, version/build inventory, privacy disclosure draft, support/privacy/marketing URLs, App Store copy, review notes, and screenshot sequence are documented in `app-store-listing.md`.
- Complete accessibility, Dynamic Type, VoiceOver, Reduce Motion, Light/Dark Mode, and small-screen checks.
- **Completed assets:** four final light-mode screenshot compositions, generated for both the 6.9-inch and 6.5-inch App Store slots, and a reproducible generator are checked in; verify the production icon and any additional required device-class presentation before submission.
- Archive and validate the replacement build after the critical 311 fixes, then complete internal TestFlight testing before App Review submission.
- Complete App Store Connect age rating, privacy questionnaire, review contact, export-compliance, build selection, and manual-release configuration without submitting until the physical-device pass is stable.
- Do not change signing, capabilities, entitlements, bundle identifiers, or Apple-account configuration without explicit approval.

## 3. Direct 311 submission discovery — high, contract-gated

This is the highest-priority product-development track after the current TestFlight stabilization pass. Do not begin implementation until the discovery work identifies how the recently reported third-party app submits requests and whether that mechanism is supported, permissioned, and suitable for production use.

- Locate and review the recent coverage of another app offering direct DC 311 submission, identify the app, and determine the actual integration mechanism rather than inferring it from the user experience.
- Establish whether submission uses a documented public API, a partner agreement, an official mobile deep link, supported web parameters, or an unofficial/private endpoint. Record authentication, required fields, category identifiers, photo handling, rate limits, terms, and confirmation behavior.
- Do not send test requests to DC, automate the public portal, depend on private Salesforce interfaces, or claim feasibility until the mechanism and authorization are verified. Any live submission test must be deliberate, clearly labeled, and approved first.
- If a production-appropriate route exists, introduce an injected submission client with idempotency protection, cancellation, structured validation errors, retry boundaries, and a returned DC confirmation number. Preserve the official handoff as a fallback.
- Build on the completed photo-first draft: run image understanding on-device, suggest the service category and useful description fields, use current phone location only with permission, and keep every inferred value editable before the user explicitly submits.
- Treat AI output as assistance rather than fact. Show what was inferred, make uncertainty understandable, never silently submit, and avoid uploading the image anywhere except the user-approved official submission destination.
- Add fixture-backed contract tests and a safe non-production verification strategy before enabling direct submission in a TestFlight build.

## 4. Nearby restaurant inspection ingestion — high, data-gated

- Replace the current generic inspection-page links with a useful in-app nearby-inspections map once a reliable inspection feed is available; center it on the active search location and respect the selected radius.
- Keep the default map focused on closures, follow-up-required inspections, and Priority/Priority Foundation violations, with an explicit filter to reveal all supported reports.
- Make every restaurant marker open a clear inspection summary with establishment, inspection date, outcome, notable violations, and authoritative source attribution.
- Verify a stable supported data interface first. If no durable public interface exists, complete a legal, reliability, caching, rate-limit, and maintenance review before approving any scraper-backed service.
- If scraping is the only viable route, design it as a scheduled server-side ingestion pipeline rather than on-device scraping. Normalize and cache only public inspection records, minimize requests to the source, publish freshness timestamps and attribution, and fail safely when the source markup changes.
- During the future discovery phase, compare a small Cloudflare Worker/cron/storage service with an appropriate Sites-hosted data approach. Choose only after documenting operational cost, access controls, cache behavior, monitoring, data retention, and how the iOS app receives a stable versioned payload.
- Add source-change detection, schema/fixture tests, stale-data warnings, health monitoring, and a kill switch before exposing scraper-backed data to users.
- Until nearby inspection data is genuinely available, avoid presenting generic links as though they lead to location-specific reports.

## 5. Opportunistic background notifications — high

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
- Replace generic notification-row dots with source/category icons shared with Near You, while preserving unread state through a separate tint or indicator and accessible labels.
- Use source-aware titles and include only non-sensitive context on the lock screen.
- Add an in-app explanation that delivery timing is controlled by iOS Background App Refresh settings.
- Provide recovery UI when notifications or Background App Refresh are disabled in Settings.

### Verification and capability gate

- Add fixture-backed tests for identifier refresh, new-item detection, status transitions, deduplication, cancellation, expiration, retry/backoff, and tap routing.
- Test background launch and refresh on a physical iPhone under allowed, denied, offline, low-power, and terminated-app conditions.
- Enabling Background Modes/background fetch changes app capabilities and must receive explicit approval before implementation.
- Defer server polling and APNs until product use demonstrates a need for more reliable or timely delivery.

## 6. Trustworthy trends and history — high

- Keep `PulseObservationRecord` as the on-device normalized request index, but separate “records observed” from historical state snapshots.
- Add observation snapshots only where status-history analysis needs them; avoid unbounded duplicate storage.
- **Completed foundation:** nearby 311 trends and the Map category catalog now use complete grouped ArcGIS statistics for two equal comparison periods; trend rows open the selected category on Map, where a targeted query retrieves its records.
- Store trend query provenance, geography, period, and refresh date so the UI can explain exactly what a percentage represents.
- Add retention and migration rules and verify trend calculations across radius, followed-place, and time-range changes.

## 7. Item-detail depth and civic actions — medium

- Make every user-visible value in the general **Details** section selectable or explicitly copyable, not only the fields used for violation reporting. Provide accessible copy actions for identifiers, dates, agency, address, category/subtype, status, and dataset-specific values while preserving the existing visual hierarchy.
- Consider a single **Copy Details** summary in addition to individual field actions, with source-aware labels and stable formatting. Copy only information already visible on screen; never include hidden attributes or undisplayed precise coordinates.
- Make the fields shown under **Report a Possible Violation** deliberately copyable before opening the official reporting site. Support copying individual values such as permit/reference number, address, request type, and work description, plus a single **Copy Report Details** action that produces a concise labeled summary suitable for pasting into the destination form.
- Keep pasteboard writes tied to an explicit user action, provide clear copied confirmation without blocking navigation, preserve Dynamic Type and VoiceOver labels, and avoid copying hidden attributes or precise coordinates that are not already presented to the user.
- Add tests for source-specific summary contents, missing optional fields, stable formatting, and exclusion of sensitive or irrelevant attributes; include a physical-iPhone handoff check that copies, opens the official site, and pastes successfully.
- Continue investigating verified 311 photo/comment fields and human-readable record links without scraping private or unstable Salesforce pages.
- Improve official violation-reporting handoffs if DOB or DDOT publishes supported address- or permit-specific parameters.
- **Completed foundation:** a photo-first 311 draft flow uses on-device Vision classification, does not read photo location metadata, supports current-location/address fallback, requires user review, and hands a copied draft to the official portal.
- Apply the findings and safety requirements from the priority direct-submission discovery above; never represent a draft as submitted without a confirmation identifier returned by DC.
- Evaluate a category-specific model only with a representative, licensed, privacy-reviewed dataset; generic image classification must remain a suggestion rather than an automated decision.

## 8. Additional civic datasets — medium

- **Completed restaurant foundation:** inspection domain semantics highlight closures, follow-up requirements, and Priority/Priority Foundation violations without inventing letter grades or scores; the default-visibility policy is defined for the nearby map planned above.
- Add new datasets only with source-specific mapping, fixtures, partial-failure behavior, filters, attribution, and accessibility coverage.

## 9. Later product expansion — deferred

- Add a Settings-controlled Flock camera overlay that is off by default only after a licensed, attributable, freshness-aware location source is verified. MPD's published 2026 response confirms Flock camera counts but does not provide a Flock-specific coordinate feed; never relabel generic MPD or DDOT camera layers.
- Widgets for Home and followed places.
- Remote push notifications backed by a privacy-conscious polling service and APNs.
- Longer-term trend dashboards and export.
- Additional notification geographies beyond Home after the first background-refresh model is proven.
