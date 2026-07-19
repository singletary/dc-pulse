# Ranked roadmap

This roadmap orders work by release value, correctness risk, and dependency. Items inside a priority are listed in recommended execution order.

## Current release state — July 18, 2026

- TestFlight: version 1.0 (build 5) completed its initial internal physical-iPhone pass and is submitted for external beta review. No public App Store submission has been made.
- Completed: Swift 6 actor-isolation warning cleanup for the current test suite.
- Completed: live one-record schema smoke audit for all three ArcGIS layers.
- Completed: privacy manifest with app-local UserDefaults required reason, copy-ready App Store metadata/review notes, and four privacy-reviewed 6.9-inch screenshots.
- Completed: capability-neutral watched-item identifier refresh, partial-failure isolation, persisted last-check timestamps, manual and throttled foreground refresh, status-transition alerts, notification-tap routing, and an on-device notification inbox with unread history.
- Completed for build 3: dismissible 311 draft keyboard, a keyboard-visible continuation control, and an official DC311 app handoff with an explicit website fallback.
- Completed for build 4: Map progressively loads a denser bounded set, explicitly merges close-in quarter-mile coverage into wider searches, shows loading progress, keeps every filter family in a consistent expandable section, and offers an atomic default-filter reset without moving the search center.
- Completed for build 4: **Requests nearby** uses complete period category counts from the grouped trend query rather than partial loaded-page counts; the cache generation was advanced to prevent stale summaries.
- Completed for build 4: Requests supports native pull-to-refresh; **Choose Photo** uses the privacy-preserving Photos picker while **Take Photo** remains a separate camera action.
- Completed for build 4: an age-derived New-to-Active presentation change is silent for watched items and cannot create an inbox or system notification event.
- Completed for build 5: cold launch waits briefly for the requested location instead of starting a redundant fallback search, Map coverage arrives progressively without a blocking overlay, watch synchronization is debounced, and slow individual data sources time out without withholding healthy results.
- Completed after build 5: location-denied and unavailable launches retain useful, labeled Downtown DC results with Settings, ward, address, and retry recovery; nearby out-of-area coordinates route to an inset supported DC search center, while distant locations use the same stable fallback. Adjusted coordinates remain distinct from current location and cannot be saved as Home. Four deterministic routing tests cover in-area, nearby, distant, and malformed-longitude inputs.
- Completed after build 5: complete 311 status/category summaries retry once after a transient failure, and Near You explicitly withholds unavailable totals instead of substituting misleading counts from the first loaded page. Focused tests cover persistent and recoverable summary failures.
- Completed after build 5: Places now links to a native About DC Pulse surface with installed version/build, public website/support/privacy/GitHub links, offline MIT terms, DC public-data attribution, and the independent-app disclaimer. URL and offline-content tests cover the trust boundary.
- Completed after build 5: notification rows use the same tested request-category symbols as Near You, while unread state remains a separate accessible indicator.
- Completed after build 5: Item Details exposes selectable values, explicit per-field copy controls, a privacy-bounded Copy All Details summary, and a purpose-built Copy Report Details handoff for permit violations.
- Completed after build 5: a 311 item can copy its exact request ID and, after explicit confirmation, open the official DC 311 service with clear paste/search guidance instead of pretending a stable per-record URL exists.
- Completed after build 5: Map close-in coverage and selected-radius coverage use independent, concurrent bounded page budgets, so merged quarter-mile items cannot suppress wider-radius pagination or double the wait serially; either pass can succeed independently and stale coverage passes are rejected.
- Completed after build 5: Map keeps visible progress active through dense coverage, rejects stale category presentation during rapid changes, and uses context-correct compact, plural, hyphenated, and VoiceOver-friendly radius wording.
- Completed after build 5: system status notifications omit street addresses from lock-screen content, while the private in-app inbox retains useful detail; Alerts and Notifications now state that updates arrive only after refresh and are not immediate.
- Completed after build 5: system-alert preferences independently control watched status changes and new auto-watched items near Home. Newly discovered nearby-item alerts use privacy-safe lock-screen copy and open the saved public record; existing watched-alert preferences migrate forward.
- Completed after build 5: trend snapshots retain their DC 311 source, search coordinate, radius, selected period, comparison windows, and refresh date. Near You presents that context without exposing raw coordinates, so cached comparisons remain explainable.
- Completed after build 5: watched records now distinguish explicit and automatic origin, retain resolved items through default 30- and 7-day grace windows respectively, move expired watches into a visible restorable archive, and exclude archived items from routine refresh batches. Manual Archive and Restore actions preserve the saved record and notification history.
- Completed after build 5: Places offers a persisted 7-, 30-, 90-day, or Never archive preference for explicitly watched resolved items. Auto-watched items retain their documented seven-day window independently.
- Immediate release gate: address any Beta App Review feedback, then run a focused external TestFlight soak and triage tester-reported correctness, performance, navigation, and accessibility defects before public App Store review.
- Remaining capability gate: `BGTaskScheduler` registration and Background Modes/background fetch approval.

## 1. Release stability and data correctness — critical

- Reproduce the radius inclusion failure and trace a missing nearby record through every boundary: raw ArcGIS pages, `exceededTransferLimit` handling, per-source page allocation, cache entries, data-store acceptance, source/category/status filters, clustering, and final annotations. Distinguish a record that was never fetched from one fetched but hidden or replaced during rendering.
- Define and test the radius inclusion invariant: for the same center, sources, statuses, categories, and period, every identifier returned at 0.25 miles must also be available at 0.5 and 1 mile. Account explicitly for source failures and server-side result limits rather than silently weakening the invariant.
- Choose the final loading strategy only after finding the cause. Candidate solutions may include completing required pagination, changing result ordering to prioritize proximity where the service supports it, separating map retrieval from list pagination, or another bounded approach that guarantees nearby records without making broad searches unacceptably slow.
- **Completed corrective boundary:** close-in and selected-radius map retrieval now have independent bounded pagination passes. A large close-in merge cannot consume the selected-radius budget, a failed close-in pass cannot prevent the main pass, and stale coverage tasks cannot merge into a newer run. Continue physical-device verification of the full radius inclusion invariant before treating the issue as closed.
- Do not change the default radius merely to conceal incomplete wider-radius results. After correctness and performance are verified, separately evaluate 0.25 versus 0.5 miles as the initial product default based on usefulness, density, map legibility, and request latency while keeping the user's last explicit choice predictable.
- **Completed:** distance copy uses compact **0.25 mi / 0.5 mi / 1 mi** summaries, plural standalone measurements, hyphenated radius phrases, and natural VoiceOver labels such as “half-mile radius.”
- **Completed foundation:** complete status totals and category/trend statistics are guarded by the accepted load generation, cached only with their search context, retried once after transient failure, and never replaced by partial first-page counts when their source query remains unavailable.
- Continue adding deterministic coverage for delayed/out-of-order summary responses, cancellation, cache hit followed by refresh, and rapid location/radius/time changes. Preserve the last coherent summary during a replacement load if external testing shows the current explicit loading state is too disruptive.
- **Completed foundation:** use one stable, privacy-safe Downtown DC fallback for denied, restricted, unavailable, and distant location states; show non-blocking Settings, retry, ward, and address recovery; never launch a repeated ward chooser.
- **Completed foundation:** keep raw device coordinates distinct from the effective query center. Nearby out-of-area locations route to an inset point in the supported service envelope, while adjusted and fallback searches are never labeled current location or persisted as Home.
- Before App Store release, validate the 25-mile near/far threshold, approximate-location behavior, every side of the actual District boundary, banner recovery, relaunch, and later transition to a valid in-DC location on physical iPhones. Replace the rectangular service envelope with an authoritative local DC boundary polygon if edge testing finds misleading centers.
- **Completed foundation:** filter changes reject stale category presentation, reset pagination correctly, keep loading feedback visible through dense coverage, and preserve healthy source results during partial failure. Continue a physical-iPhone stress pass with rapid source, category, status, radius, and time changes.
- **Completed:** **Reset Filters** is distinct from current location and atomically restores every source, all statuses and categories, the half-mile radius, and last 30 days without moving the search center.
- **Completed:** Requests supports native pull-to-refresh for the active location or followed place while preserving the current browsing and sort context.
- Continue deterministic and physical-device coverage for cancellation races, cache separation, rapid repeated changes, offline recovery, empty responses, partial source failures, and the same-center radius inclusion invariant.
- **Completed in build 3:** the new-311 draft supports keyboard dismissal, keeps its continuation action reachable, and has UI coverage for continuing while the keyboard is visible.
- **Completed in build 3:** the 311 handoff offers the official DC311 app as its primary route and retains the official website as an explicit fallback instead of silently opening a blank page.
- Run a repeatable physical-iPhone regression pass covering location authorization, out-of-DC recovery, initial loading, radius/time changes, followed-place browsing, map clustering, X compose, and notification authorization.
- Keep the Swift 6 actor-isolation warning baseline clean as new tests and concurrency boundaries are added.
- **Completed:** deterministic UI coverage proves an archived watch can be restored across relaunch and a followed place opens the Map with its saved search context, without relying on live ArcGIS data. Continue adding UI coverage for loading/error recovery and item-detail actions.
- Repeat the live 311, Building Permit, and DDOT field audit before each TestFlight release and update fixtures when a schema changes.
- Add lightweight diagnostics for refresh failures without collecting precise location or home-address telemetry.

## 2. App Store release readiness — critical

- **Completed package:** bundle display metadata, version/build inventory, privacy disclosure draft, support/privacy/marketing URLs, App Store copy, review notes, and screenshot sequence are documented in `app-store-listing.md`.
- Complete accessibility, Dynamic Type, VoiceOver, Reduce Motion, Light/Dark Mode, and small-screen checks.
- **Completed assets:** four colorful screenshot compositions use Apple’s Simulator-derived continuous display mask, Simulator-measured device proportions, and storefront-readable headlines; matching 6.9-inch and 6.5-inch sets are produced by a reproducible generator. Verify the production icon and any additional required device-class presentation before submission.
- **Completed:** About DC Pulse is reachable from Places and includes installed version/build, public website/support/privacy/GitHub links, offline MIT terms, DC public-data attribution, the independent/non-government-service disclaimer, and a clear distinction between app-source licensing and publisher-owned data terms. If package dependencies are added later, generate dependency-specific notices from verified license metadata.
- Build 5 is submitted for external TestFlight beta review; complete its external beta pass before public App Review submission.
- Complete App Store Connect age rating, privacy questionnaire, review contact, export-compliance, build selection, and manual-release configuration without submitting until the physical-device pass is stable.
- Do not change signing, capabilities, entitlements, bundle identifiers, or Apple-account configuration without explicit approval.

## 3. Direct 311 submission discovery — high, contract-gated

This is the highest-priority product-development track after the current TestFlight stabilization pass. Do not begin implementation until the discovery work identifies how the recently reported third-party app submits requests and whether that mechanism is supported, permissioned, and suitable for production use.

- Fix the existing photo-source routing before deeper submission work: **Take a Photo** must present the camera and **Choose a Photo** must present the system photo picker. Keep their labels, icons, accessibility hints, and permission explanations consistent with the source each action actually opens.
- Handle camera unavailability, denied or restricted camera access, limited Photos access, cancellation, picker errors, and re-selection without losing the rest of the draft. Prefer the privacy-preserving system photo picker and avoid requesting broad photo-library access when item-level selection is sufficient.
- Add focused tests for both source actions and their cancellation/error paths, plus a physical-iPhone check that confirms the selected image reaches the same on-device analysis and editable review flow regardless of its source.
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
- Separate source lifecycle status from the derived **New** recency presentation. An item aging from **New** to **Active** without an underlying source-status change must update its visual grouping silently and must not generate a watched-item notification, notification-history entry, badge increment, or duplicate event.
- Define notification-worthy transitions from normalized source semantics, such as active to resolved/closed, resolved to reopened, or another materially changed source state. Add clock-injected tests around the newness cutoff, app relaunch, cache refresh, delayed records, and simultaneous timestamp/source-status updates so a recency-only transition can never masquerade as a civic status change.
- **Completed foundation:** terminal-state watches are never silently deleted. Explicit watches retain a normalized resolved record for 30 days by default and automatic watches for 7 days before moving to a restorable **Archived** section and leaving routine refresh batches.
- **Completed foundation:** terminal decisions use the adapters' normalized `.resolved` state, so source-specific raw wording stays outside the lifecycle policy. A record that reopens during its grace period cancels pending archival and resumes normal watch behavior.
- **Completed preference:** notification history and the last observed details survive archival; Places provides **Archive** and **Restore** actions plus a persisted 7-day, 30-day, 90-day, or Never preference for explicit watches. Auto-watches remain fixed at seven days. Add bounded archive retention only after external-beta behavior is understood.
- **Completed restoration boundary:** clock-injected model tests cover closure, configurable grace-period expiry, reopening, and manual archive/restore; deterministic UI coverage verifies restoration across app relaunch. Continue coverage for missing source records, differing source status vocabularies, and explicit exclusion of archived items from normal refresh batches.

### Notification experience

- Keep notification permission tied to explicit alert or auto-watch opt-in.
- **Completed:** separate persisted system-alert preferences control watched-item status changes and new items near Home. Auto-watch opt-in enables the nearby choice after authorization, and disabling system permission does not erase the person's saved preferences.
- Preserve the completed notification-to-Item Details routing and explicit unavailable-record fallback.
- **Completed:** notification rows use source/category symbols shared with Near You, preserve unread state separately, and expose an accessible category label.
- **Completed privacy boundary:** system notifications use source/category-aware titles and status transitions but omit street addresses from lock-screen content; full details remain in the in-app inbox.
- **Completed current-build disclosure:** Alerts and Notifications explain that updates arrive after a data refresh and are not immediate. Once background refresh is enabled, expand this copy to explain that scheduling is controlled by iOS.
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
- **Completed:** store trend query provenance for data source, geography, radius, selected period, comparison windows, and refresh date; Near You explains the current context and cached freshness without showing raw coordinates.
- Add retention and migration rules and verify trend calculations across radius, followed-place, and time-range changes.

## 7. Item-detail depth and civic actions — medium

- **Completed foundation:** the 311 **Request ID** is individually copyable and **Check This Request in DC 311** copies the identifier, explains the paste/search step, and opens the verified official HTTPS service only after confirmation. It does not claim a stable per-record portal URL.
- Validate the copy/paste/status-search handoff on a physical iPhone, including cancellation and an unavailable official site. Consider a separate **Check by Text** action only if its exact 32311 message flow is verified against current official guidance.
- Investigate whether the public Salesforce experience exposes a reasonably stable mapping from `SERVICEREQUESTID` to its request-detail navigation state through a public page response, supported API, documented mobile deep link, or another permissioned interface. Document the distinction between the public confirmation number and any internal Salesforce record identifier, authentication requirements, terms, rate limits, and whether anonymous deep links remain valid across sessions.
- If the only candidate is undocumented but publicly observable, require a reliability and privacy review, representative live-ID verification, monitoring for portal changes, a remote disable/kill-switch strategy, and the official search-page fallback before considering it for production. Do not scrape authenticated pages, persist private Salesforce identifiers unnecessarily, automate account access, or construct guessed detail URLs.
- **Completed:** every value in the general **Details** section and location metadata is selectable and has an accessible explicit copy action; **Copy All Details** includes source-aware labels and excludes undisplayed precise coordinates.
- **Completed:** **Report a Possible Violation** exposes reference, address, request type, and work description with individual copy controls plus a concise **Copy Report Details** action.
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
