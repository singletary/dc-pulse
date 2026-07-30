# Map performance and Near You discovery

Status: in progress

Owner: product and iOS

Added: July 22, 2026

Roadmap priorities: P0 live Map progress, coverage reliability, shared retrieval/caching, and baseline; P1 Near You validation and radius decision

## Purpose

This brief turns reported Map loading problems, a crowded Near You screen, and questions about caching and search radius into measurable work. It is a discovery and decision document, not authorization to change retrieval limits, product defaults, or the production interface without reviewing the evidence.

Update this file with dated measurements, screenshots, findings, and decisions. Keep the ranked summary in [roadmap.md](roadmap.md) short.

## Reported problems to reproduce

- Map population feels slow.
- The loading card below Filters looks like a progress bar but does not report live completion, including compatible loading already started for Near You during app launch.
- After loading, a triangle notice beginning **Some map results…** can be truncated and cannot be opened for details.
- The recurring **Map coverage is incomplete. Existing markers remain available.** message exposes internal terminology, does not tell the person what failed or what to do, and may indicate a fixable retrieval defect rather than an exceptional partial-source condition.
- Moving from Near You to Map may repeat compatible DC 311 retrieval instead of reusing cached results or joining work already in flight.
- Near You presents enough sections and actions that the primary value is becoming difficult to scan.
- It is unclear whether a smaller default radius would improve the experience enough to offset reduced local coverage.

Treat these as user reports until each condition has a repeatable reproduction and recorded environment.

## Current implementation baseline

Code inspection establishes the following starting point:

- The initial nearby load requests a small combined page while status totals, trends, and category totals load concurrently.
- Opening Map starts dense coverage after a short delay. For radii above 0.25 mile, close-in and selected-radius coverage run concurrently with independent budgets.
- Each coverage pass can merge up to 600 returned items in 150-item combined pages. The combined repository divides each page among DC 311, Building Permits, and DDOT Construction Permits and gives each source a four-second timeout.
- A half- or one-mile dense search can therefore attempt as many as four combined page cycles per coverage pass, or up to 24 source-page attempts across the two passes, beyond the initial load. Actual work stops earlier when sources report no additional pages.
- The loading card is indeterminate. It does not currently expose completed stages, page counts, source completion, or a total.
- Map warnings collapse direct coverage failure and partial source-page failure into one compact, noninteractive notice.
- The app already persists one cache context in `UserDefaults` for ten minutes. It includes normalized items and summaries, but expired entries are not shown, only one search context is retained, and the cache is not a stale-while-revalidate or per-source delta store.

These facts suggest testable hypotheses; they do not establish the dominant cause of latency.

## P0 follow-up — live progress, failure elimination, and shared retrieval

Added July 28, 2026 as the next implementation priority after the current release
gate.

### Required investigation

1. Reproduce every path that presents the incomplete-coverage warning and trace it
   to the exact pass, page, source, timeout, cancellation, stale generation, or
   merge decision.
2. Distinguish genuine partial public-source availability from app-created
   failures such as duplicate work, overly aggressive timeouts, request
   competition, cancellation races, page-budget exhaustion, or discarded
   compatible results.
3. Inventory every launch, Near You, summary, and Map request by normalized
   context. Identify which DC 311 pages and summaries can be shared, coalesced,
   cached, or batched without changing visible correctness.
4. Define one observable loading model owned below the views so Near You and Map
   can display the same in-flight work and accepted results.

### Acceptance criteria

- The Map indicator advances from actual accepted work. It may use defensible
  source/page units or named stages, but it must not imply precision the
  repository cannot measure.
- Compatible loading begun during launch appears as current progress when the
  person opens Map; progress does not restart merely because the tab changed.
- Map renders compatible cached or already-accepted Home results immediately,
  joins equivalent in-flight requests, and requests only missing coverage.
- Instrumented cold-launch-to-Map and warm-Home-to-Map tests demonstrate fewer
  DC 311 calls than the current implementation, with no missing same-context
  records and no regression for explicit refresh or changed filters/location.
- The known incomplete-coverage reproduction is fixed. Deterministic tests cover
  its root cause and ensure healthy sources are not mislabeled as failed.
- When a public source is genuinely partial or unavailable, primary copy says
  what did not update and whether visible results are still usable; details may
  retain technical pass/source information for diagnosis.
- Retry requests only failed or missing work when safe, remains accessible, and
  does not duplicate an equivalent request already in flight.
- Progress and warning diagnostics remain local and exclude precise coordinates,
  saved addresses, request URLs, record identifiers, and device/account data.

## P0 workstream A — Map status clarity

### July 28, 2026 implementation

- Coverage warnings now retain the affected close-in or selected-radius pass and the source warning returned for that pass.
- The compact warning explicitly preserves the usability of existing markers and opens an accessible detail sheet with pass-specific information and a real Map coverage retry action.
- Loading copy now names the bounded coverage being loaded instead of implying numeric progress that the app cannot defend.
- Simulator and physical-device reproduction-matrix results remain to be recorded before this workstream is complete.

### Reproduction matrix

Test on the smallest supported iPhone and a current Pro-size iPhone, using the default and largest accessibility text sizes:

| Dimension | Required cases |
| --- | --- |
| Launch | clean install, cold launch with cache, warm launch |
| Radius | 0.25, 0.5, and 1 mile |
| Period | 30 days and the densest supported period |
| Network | normal Wi-Fi, constrained/high-latency, offline recovery |
| Source state | all healthy, each single source delayed/failed, all failed |
| Interaction | open Map during initial load, rapid filter changes, leave and return, retry |
| Accessibility | default text, largest text, VoiceOver, Light and Dark Mode |

For every failure or warning, record the accepted load generation, coverage pass, page offset, source, timeout/error class, visible marker count, and whether cached data remained available. Diagnostics must not retain precise location or saved addresses.

### UX acceptance criteria

- The control and status text do not truncate at supported Dynamic Type sizes.
- Progress is described as measurable completion only when the app has a defensible numerator and denominator. Otherwise it uses staged language such as **Loading DC 311** or **Adding permits**.
- The map remains interactive after its first useful marker set is visible.
- A partial warning states what is incomplete and whether existing markers remain usable.
- The warning opens an accessible detail surface with affected sources/passes, retry, and dismissal.
- Retry invokes a real supported action; copy does not claim that Map supports pull-to-refresh unless that interaction is implemented.
- VoiceOver announces loading transitions without repeatedly interrupting map exploration.

## P0 workstream B — Performance baseline

### July 28, 2026 instrumentation

The app now emits local Apple signposts in the `MapPerformance` category for coverage sessions and passes, per-source requests, ArcGIS transport and decoding, adapter mapping, item merging, cache encoding, annotation diff/application, and clustering stabilization. Milestone events cover Map construction, first markers, each coverage page, close-in completion, selected-radius completion, and final bounded coverage.

Signpost metadata is intentionally limited to a public dataset label, coverage-pass label, radius bucket, pagination offset/limit, outcome, byte count, and item count. It never includes coordinates, addresses, saved-place names, request identifiers, complete URLs, query clauses, device/account identifiers, or photo data. Signposts are inspected locally through Instruments or the Simulator unified log; DC Pulse does not upload them, persist them in app storage, or operate a diagnostics backend. This preserves the current **Developer analytics: No** and **Diagnostics collected by the developer: No** disclosures.

Each concurrent interval now receives a unique signpost ID. This is required to pair overlapping close-in and selected-radius source requests correctly when exporting unified-log data; the previous default exclusive ID could not support defensible per-source attribution.

### Repeatable capture procedure

1. Build a Debug app for the target Simulator without changing retrieval limits.
2. Run `scripts/capture-map-performance-baseline.sh <simulator-udid> <path-to-DCPulse.app> <private-output.csv>`. The default is five paired cold/warm runs with a 75-second completion timeout.
3. The Debug-only launch hook waits for the initial location context to finish loading, emits **Map Presentation Started**, and then opens Map. It is excluded from Release builds and does not alter TestFlight or App Store navigation.
4. The script reinstalls only the app for each cold run, immediately reuses that completed context for the paired warm run, waits for **Bounded Map Coverage Complete**, and summarizes only approved signpost fields.
5. For Instruments or physical-iPhone captures, record the device model, OS, app commit/build, radius, period, network condition, and whether the app cache is cold or warm. Do not record a coordinate or address.
6. Report median, nearest-rank p90, and worst elapsed time. Keep Simulator and physical-iPhone results separate and retain raw `.trace` or CSV files only in approved private test storage. The CSV separates app-deadline timeouts from other failures and reports only source names and page offsets; it never records a coordinate, address, or record identifier.

Use this row shape for every scenario:

| Environment | Cache | Radius | Period | Network | Runs | Interactive median/p90/worst | First markers median/p90/worst | Close-in median/p90/worst | Bounded median/p90/worst | Final items | Partial sources |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- | ---: | --- |
| Pending | Cold/Warm | 0.25/0.5/1 mi | 30 days/densest | Wi-Fi/constrained/offline recovery | 5+ | Pending | Pending | Pending | Pending | Pending | Pending |

### July 28, 2026 first repeatable Simulator baseline

The first automated matrix used an iPhone 17 Pro Simulator on iOS 26.5, the default 0.5-mile/30-day context, normal Wi-Fi, and five paired cold/warm runs. With five samples, nearest-rank p90 is also the observed worst value.

| Environment | Cache | Radius | Period | Network | Runs | Interactive median/p90/worst | First markers median/p90/worst | Close-in median/p90/worst | Bounded median/p90/worst | Final items | Partial sources |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- | ---: | --- |
| iPhone 17 Pro Simulator, iOS 26.5 | Cold | 0.5 mi | 30 days | Normal Wi-Fi | 5 | 0.098 / 0.142 / 0.142 s | 0.186 / 0.253 / 0.253 s | 11.865 / 12.962 / 12.962 s | 24.052 / 32.399 / 32.399 s | Median 553; range 479–575 | Every run partial; 2–11 failed source requests |
| iPhone 17 Pro Simulator, iOS 26.5 | Warm | 0.5 mi | 30 days | Normal Wi-Fi | 5 | 0.113 / 0.119 / 0.119 s | 0.279 / 0.285 / 0.285 s | 10.151 / 12.446 / 12.446 s | 23.912 / 27.078 / 27.078 s | Median 575; range 549–613 | Every run partial; 2–5 failed source requests |

This establishes a Simulator baseline, not a physical-device or broad-scenario baseline. Map construction and first useful rendering are not the dominant delay in this scenario: the Map is interactive in under 0.15 seconds and shows first markers in under 0.29 seconds across every run. Full bounded coverage remains slow and variable.

Summed request time across the two concurrent radius passes further narrows the bottleneck. DC 311 source requests consumed a median 29.437 seconds cold and 30.212 seconds warm; Building Permits consumed 11.479 and 15.606 seconds with one 40.447-second cold outlier; DDOT consumed 1.539 and 1.440 seconds. These are overlapping aggregate durations and must not be added or treated as wall-clock time. They show that live pagination and source failures dominate, while annotation presentation does not.

Warm cache made hundreds of markers available immediately but did not materially reduce bounded live reconciliation time. Because all ten runs completed partial, no retrieval-limit, timeout, default-radius, or cache-adoption decision should be made from this matrix alone. The next measurement slice should identify the exact failed source/offset distribution, repeat 0.25 and 1 mile, and reproduce on a physical iPhone before changing production behavior.

### July 29, 2026 all-radius Simulator baseline

The capture path now accepts an explicit 0.25-, 0.5-, or 1-mile radius and records app-launch, initial-results, Map-presentation, interaction, and marker milestones separately. This avoids treating a clock that starts after initial loading as warm-launch evidence. The following five-pair matrix used the same iPhone 17 Pro Simulator, iOS 26.5, 30-day Downtown DC context, normal Wi-Fi, and implementation commit candidate.

| Radius | Cache | Runs | Interactive median/p90/worst | First markers median/p90/worst | Close-in median/p90/worst | Bounded median/p90/worst | Final items | Partial sources |
| --- | --- | ---: | --- | --- | --- | --- | ---: | --- |
| 0.25 mi | Cold | 5 | 0.093 / 0.104 / 0.104 s | 0.171 / 0.193 / 0.193 s | N/A | 6.588 / 10.568 / 10.568 s | Median 125; range 125–151 | Every run; one failed DC 311 request |
| 0.25 mi | Warm | 5 | 0.084 / 0.111 / 0.111 s | 0.201 / 0.244 / 0.244 s | N/A | 6.801 / 10.151 / 10.151 s | Median 151; range 125–151 | Every run; one failed DC 311 request |
| 0.5 mi | Cold | 5 | 0.076 / 0.094 / 0.094 s | 0.144 / 0.164 / 0.164 s | 9.264 / 13.096 / 13.096 s | 21.186 / 21.695 / 21.695 s | Median 584; range 543–642 | Every run; 1–2 failed DC 311 requests |
| 0.5 mi | Warm | 5 | 0.099 / 0.121 / 0.121 s | 0.230 / 0.250 / 0.250 s | 9.041 / 9.864 / 9.864 s | 18.738 / 19.944 / 19.944 s | Median 620; range 578–644 | Every run; 1–2 failed DC 311 requests |
| 1 mi | Cold | 5 | 0.091 / 0.093 / 0.093 s | 0.175 / 0.180 / 0.180 s | 9.531 / 10.310 / 10.310 s | 9.563 / 10.344 / 10.344 s | Median 685; range 685–685 | Every run; one failed DC 311 request |
| 1 mi | Warm | 5 | 0.106 / 0.109 / 0.109 s | 0.203 / 0.213 / 0.213 s | 9.467 / 9.729 / 9.729 s | 9.498 / 9.769 / 9.769 s | Median 685; range 685–685 | Every run; one failed DC 311 request |

The 1-mile bounded milestone follows the close-in milestone because both independent passes reach their configured budgets at nearly the same time; its 685-item result is the deduplicated union, not proof that authoritative pagination completed. The 0.5-mile result takes longer because its selected-radius pass continues returning pages while the 1-mile pass reaches the bounded item budget sooner. This is why the UI and document call the milestone **bounded** rather than **complete** coverage.

DC 311 remained the dominant accumulated request cost and the only failing source in this matrix. The result closes the missing normal-Wi-Fi Simulator radius slice but not constrained, offline-recovery, multi-neighborhood, or physical-iPhone validation.

### Missing-record trace procedure

Start with the capture CSV’s failed source and page offset. The combined repository’s requested limit shows the per-source allocation; the next offset and `hasMore` state show whether ArcGIS transfer-limit paging continued. Cache reconciliation then classifies that source refresh as complete, partial, or failed without treating absence after a failed page as deletion.

For a record available to the presentation layer, run the same source-namespaced identifier through `MapItemPipeline.disposition(of:)`. The result identifies source, status, or category filtering; a missing coordinate; final annotation eligibility; or that the identifier was never received. The aggregate `Trace` exposes only stage counts and is safe for diagnostics. `ClusteredPulseMap` now receives exactly the pipeline’s annotation-eligible set, so clustering cannot silently introduce an additional record filter.

### July 29, 2026 launch-to-marker cache evidence

A second five-pair default-radius capture started its clock at app initialization. Cold launch reached initial nearby results in a 3.568-second median and first Map markers in 3.710 seconds. Warm launch restored matching cached results in 1.927 seconds and reached first markers in 2.145 seconds: a 1.565-second, roughly 42% median improvement. Map-presentation-to-marker time itself was slightly higher warm (0.229 versus 0.143 seconds), which confirms that the material benefit occurs before Map presentation, where the protected cache replaces initial network waiting.

One cold outlier retained only 44 items after four source failures, while cached warm runs retained 544–620. Together with deterministic corruption, expiration, multi-context isolation, partial-source, and timestamp-preservation tests, the evidence supports adopting the cached-first design. It does not make bounded live reconciliation faster, and it does not close the repeated DC 311 partial-source defect.

### July 29, 2026 same-build warning-reproduction check

After the request-reuse and warning-copy changes, one cold/warm pair at every
radius was captured from the same Debug build on the iPhone 17 Pro Simulator,
iOS 26.5, 30-day Downtown DC context, and normal Wi-Fi. Timings below start at
app launch. All six runs reached bounded coverage with zero failed or timed-out
source requests; the formerly recurring partial DC 311 warning did not
reproduce.

| Radius | Cache | Initial results | Interactive | First markers | Close-in | Bounded | Final items |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.25 mi | Cold | 3.402 s | 5.110 s | 5.176 s | N/A | 19.932 s | 218 |
| 0.25 mi | Warm | 1.915 s | 3.642 s | 3.743 s | N/A | 21.184 s | 218 |
| 0.5 mi | Cold | 3.546 s | 3.630 s | 3.712 s | 16.161 s | 21.825 s | 680 |
| 0.5 mi | Warm | 1.944 s | 2.052 s | 2.186 s | 17.523 s | 22.449 s | 683 |
| 1 mi | Cold | 3.675 s | 8.964 s | 9.032 s | 17.191 s | 17.233 s | 761 |
| 1 mi | Warm | 1.909 s | 3.616 s | 3.722 s | 17.425 s | 17.441 s | 761 |

This is evidence that the warning is not currently reproducible in the normal
Wi-Fi Simulator path, not proof that the public source can never be partial.
Constrained/high-latency, offline recovery, repeated samples, and physical
iPhone runs remain required. No timeout or retrieval-limit change is justified
by this small successful slice.

### Milestones

Measure wall-clock time from the initiating action to:

1. Map visible and interactive.
2. First marker or cluster visible.
3. Useful close-in coverage visible.
4. Selected-radius bounded coverage complete or explicitly partial.

Record marker/item counts at milestones 2–4. Report median, p90, and worst observed time across at least five runs per scenario; separate Simulator results from physical-iPhone results.

### Attribution

Instrument signposts around:

- Each source request, offset, radius pass, response size, and outcome.
- URLSession transfer versus JSON decoding and adapter mapping.
- Deduplication, sorting, main-actor merge, and cache encoding.
- Annotation diff/application and MapKit clustering stabilization.
- Cancellation, stale-generation rejection, and repeated work after filter changes.

### Hypotheses to test in order

1. A slow source repeatedly consumes most of the four-second timeout across pagination cycles.
2. The overlapping quarter-mile and selected-radius passes transfer and decode too many duplicate records.
3. The response requests more fields or geometry detail than marker rendering needs.
4. Replacing/sorting the full observable item array on every page causes expensive annotation rebuilds.
5. MapKit clustering, rather than transport, dominates after several hundred annotations.
6. Summary requests compete with Map coverage for connections or server capacity.

Do not increase timeouts, raise result limits, or serialize the two passes until measurements identify the limiting stage.

## P1 workstream — Cached-first and incremental refresh

### July 28, 2026 source capability audit and reconciliation prototype

A read-only production metadata audit confirmed that all three ArcGIS layers support pagination, ordering, standard `where` filters, and date fields that the adapters already normalize into `PulseItem.updatedAt`. None of the layers advertises sync change tracking, historic-moment queries, archiving, or a server change feed (`syncCanReturnChanges` is false). An update timestamp can identify records to refetch, but it cannot prove that an absent record was deleted or moved outside the bounded query.

| Source | Stable identity | Update field | Filtering/ordering | Change feed | Prototype classification |
| --- | --- | --- | --- | --- | --- |
| DC 311 | `SERVICEREQUESTID` | `EDITED` | Supported | None | Overlapping-window reconciliation |
| Building Permits | `PERMIT_ID` | `LASTMODIFIEDDATE` | Supported | None | Overlapping-window reconciliation |
| DDOT Construction Permits | `PERMITNUMBER`, falling back to `TRACKINGNUMBER` | `EDITED` | Supported | None | Overlapping-window reconciliation |

The storage-independent `MapCacheReconciler` prototype therefore accepts an explicit coverage result per source. A complete authoritative bounded refresh replaces only that source's cached slice. A partial refresh overlays new and changed stable identities without deleting unseen cached records. A failed source leaves its cached slice intact while healthy sources reconcile independently. Source-mismatched records are rejected at the boundary.

This prototype does not yet change production loading or persistence. It establishes deterministic deletion and partial-failure semantics before selecting a bounded file-backed or SwiftData store. Cached coordinates and records remain on device and are excluded from diagnostics.

### July 28, 2026 bounded-store decision and implementation

The prototype selects a file-backed Codable archive rather than adding Map cache entities to SwiftData. Followed places, watches, notifications, and observation history are durable user data whose model migrations must be preserved. Map results are replaceable public-data snapshots; keeping their versioned archive separate makes corruption recovery, schema invalidation, and complete eviction explicit without risking the durable SwiftData container.

`FileBackedMapCacheStore` is injected behind `MapCacheStoreProtocol`. It uses a rounded three-decimal center bucket plus radius, period, and schema generation as the context key; exact coordinates may exist only inside the on-device opaque payload. The production policy retains at most six contexts, 3,600 total items, 16 MiB of encoded payloads, and 24 hours of candidate stale data. Reads discard expired, future-schema, or corrupt archives as empty. Saves use atomic writes with iOS complete-file-protection-unless-open, deduplicate contexts, and evict oldest records to satisfy every cap.

### July 28, 2026 versioned payload and legacy migration

`PulseDataStore` now persists a versioned Codable payload through `MapCacheStoreProtocol` and restores matching rounded search contexts independently. It verifies payload version, saved timestamp, item count, and derived context before accepting a record. Matching restores preserve the caller's requested exact center rather than replacing it with the cached coordinate; only an explicit most-recent restore adopts the saved search context.

The existing ten-minute freshness rule remains in force. The 24-hour store window is only candidate storage for the later stale-while-revalidate prototype and is never presented as fresh by this slice. A valid legacy `UserDefaults` cache is migrated only after the protected file-store write succeeds, then the legacy cache key is removed. Corrupt, future-dated, incomplete-summary, mismatched-context, or unknown-version payloads fall through to a live request.

`lastUpdated` is explicit observable store state for Map disclosure UI.

### July 28, 2026 cached-first production prototype

Map now keeps a matching protected-cache candidate for up to 24 hours, labels cached markers with their actual update time, and distinguishes results older than the ten-minute freshness window. Fresh cache hits still avoid an unnecessary initial request; stale hits remain visible while a live request proceeds. A failed or cancelled live request leaves the cached markers usable instead of replacing the screen with an error.

Bounded Map coverage now feeds the storage-independent `MapCacheReconciler`. A source slice is replaced only when that source returned fresh records and the selected-radius pagination completed without a source warning. Partial and failed sources retain their cached records, and an aggregate response with no record for a source is treated conservatively rather than interpreted as proof of deletion. Partial reconciliations are persisted with the original cache timestamp so a relaunch keeps useful fresh overlays without relabeling retained records as newly updated.

The cache remains on device and the status UI discloses only relative age; it does not add coordinates, addresses, record identifiers, or saved-place names to diagnostics. Performance measurements and the decision gate below remain open before this prototype is considered adopted.

### Target behavior

- A matching cached map appears immediately with a visible **Updated …** timestamp.
- Fresh sources reconcile independently; one failed source does not discard healthy fresh data or its previous cached records.
- New and changed records replace cached records by stable source identifier.
- Deletion/absence is accepted only after a successful authoritative refresh covering the relevant window, never after timeout, cancellation, or partial pagination.
- Cache entries are bounded by age, number of rounded search contexts, and total item count.
- Saved coordinates remain on device and are never added to diagnostics.

### Discovery steps

1. Audit every layer for a reliable server-side edit/update timestamp, supported ordering, and `where` filtering.
2. Classify each source as true incremental, overlapping-window reconciliation, or full bounded refresh.
3. Compare a SwiftData cache with a file-backed Codable store; do not grow the existing single `UserDefaults` blob into an unbounded database.
4. Define a rounded search-context key containing center bucket, radius, period, source, and schema generation.
5. Prototype stale-while-revalidate behavior with injected clocks and repositories.
6. Test schema migration, expiration, corruption, offline launch, partial-source refresh, cancellation, and storage eviction.

### Decision gate

Adopt the approach only if warm-launch time to useful markers improves materially without introducing misleading deletions, cross-location cache leakage, excessive storage, or complex source-specific behavior that cannot be tested deterministically.

### July 29, 2026 adoption decision

Adopt the bounded file-backed cache and conservative source-scoped reconciliation.

The launch-to-marker matrix shows a material warm improvement, while deterministic tests cover context isolation, schema rejection, expiration, corruption recovery, bounded eviction, complete-source replacement, partial overlays, and failed-source retention. The design preserves the original cache timestamp when stale records survive reconciliation and never interprets an aggregate missing source as authoritative deletion. Keep the existing size, age, and context caps. Continue measuring live reconciliation separately because cached-first presentation does not solve public-source pagination latency or partial responses.

## P1 workstream — Near You simplification

### July 28, 2026 content audit and concept decision

The scored audit, consistent low-fidelity state mockups, comparison, selected hierarchy, and task-validation plan are recorded in [Near You simplification decision](near-you-simplification.md).

**Option A — Snapshot first** is selected for validation and production planning. It establishes one stable hierarchy for first-run and returning users, puts place context and complete lifecycle totals first, limits the first screen to one reliable insight and three noteworthy records, and moves full categories and trends into a Neighborhood Summary destination. Home becomes contextual supporting content rather than an initial setup gate. The selection avoids adding a duplicate Map preview while Map performance remains an open P0 workstream.

The decision record did not itself change the app screen; production implementation was subsequently approved and is recorded below.

### July 28, 2026 Snapshot-first implementation

The approved hierarchy is now implemented in production SwiftUI. Near You shows compact search context, complete lifecycle totals, up to four reliable insights, three noteworthy records, a focused Neighborhood Summary destination, and contextual Home content. Selecting New, Active, or Resolved refreshes those insight rows from complete matching category totals; tapping the selected metric again returns to all statuses without a redundant selection or list-route row. Ward/address selection remains available in the search context. The duplicate toolbar refresh action is removed while pull-to-refresh and explicit recovery actions remain.

City Services is intentionally hidden until its direct 311/reporting and nearby Restaurant Health destinations satisfy their separate live-data gates. Simulator visual inspection and deterministic presentation tests are complete; physical-device, largest-Dynamic-Type, VoiceOver, and task-based validation remain open.

### Content audit

Score each current element on user value, use frequency, urgency, duplication with another tab, personalization, data reliability, vertical cost, and accessibility cost. The current audit must cover:

- Search radius, time period, location, save-Home, and recovery controls.
- New, Active, and Resolved totals plus selected-status controls.
- Category summary and expansion.
- Trends and explanatory provenance.
- My requests/Home state.
- Noteworthy records and source warnings.
- Ward/address exploration, 311 reporting, and Restaurant Health entry points.
- Notification and refresh toolbar actions.

### Concepts to mock up

#### Option A — Snapshot first (recommended starting point)

Lead with location context, the three status totals, one strongest insight, and three noteworthy records. Put expanded categories and trends behind a single **See neighborhood summary** destination. Move area selection to the location control and keep civic actions in their most relevant destinations.

Strengths: fastest scan, lowest duplication, useful without Home setup.

Risk: trends and category breadth become one step deeper.

#### Option B — Personalized first

Lead with watched/Home changes, followed by nearby status totals and a short local snapshot. Collapse setup prompts after Home is configured.

Strengths: strongest returning-user value and clear alert relevance.

Risk: weaker first-run experience and more conditional layouts.

#### Option C — Map preview first

Lead with a compact, noninteractive or low-interaction map preview, status totals, and one noteworthy change; open the full Map for exploration.

Strengths: immediate geographic orientation.

Risk: added rendering cost and visual density could work against both simplification and performance goals.

### Mockup set and review criteria

Produce a consistent phone-sized mockup for each option in these states: loaded, loading, partial warning, no Home, and largest accessibility text. Review:

- Time to identify what changed nearby.
- Number of competing primary actions above the fold.
- Scroll depth to the first record and secondary features.
- Duplication with Map, Requests, Places, and Notifications.
- Dynamic Type and VoiceOver reading order.
- Data dependencies and implementation cost.
- Whether cached or partially unavailable data remains understandable.

Record the selected direction and rejected tradeoffs in this document before implementation. Do not treat a visual preference review as evidence that the information hierarchy works; validate the selected prototype with task-based use.

## P1 workstream — Default radius decision

Compare 0.25 and 0.5 miles only after radius-inclusion correctness is verified and the performance baseline exists.

| Measure | Question |
| --- | --- |
| Latency | How much do first-useful and completed-coverage times improve? |
| Request cost | How many pages, bytes, duplicates, and timeouts are avoided? |
| Usefulness | How often does the smaller radius return enough meaningful activity? |
| Legibility | Does it materially reduce cluster density and occlusion? |
| Predictability | Can the app preserve the person's last explicit choice? |
| Equity | Does a smaller radius underserve lower-density parts of DC? |

Candidate outcomes are: retain 0.5 mile after performance work; default current-location searches to 0.25 mile with a clear expansion action; or investigate a density-adaptive first view. Do not choose the adaptive option unless its behavior can be explained accessibly and remains predictable.

### July 29, 2026 default-radius decision

Retain 0.5 mile as the default and preserve the person’s explicit radius choice.

At the measured dense Downtown DC context, 0.25 mile materially improved bounded latency: cold median fell from 21.186 to 6.588 seconds and warm median from 18.738 to 6.801 seconds. It also reduced the median visible result set from 584 to 125 cold and 620 to 151 warm. All 0.25-mile runs still returned more than 100 items, so it remained meaningful at this location, and deterministic close-in merging verifies that wider-radius passes retain compatible quarter-mile identifiers.

That evidence does not justify making the smaller radius universal. Every run at both radii remained partial, so the smaller radius would conceal neither the reliability defect nor its warning. The sample is one high-density location and provides no equity evidence for lower-density parts of the District. A density-adaptive default would also be less predictable and harder to explain accessibly. Retaining 0.5 mile preserves broader neighborhood usefulness while the app addresses DC 311 pagination; 0.25 mile remains an explicit, clearly labeled option for people who prefer a tighter view.

## Deliverables and exit criteria

- Dated baseline results with raw scenario counts and summarized median/p90 timings.
- Screenshots of every loading/warning defect and the revised states.
- A source capability table for incremental refresh.
- A bounded cache design with migration and failure semantics.
- Three Near You concept sets and a recorded selection decision.
- A radius recommendation backed by correctness, latency, density, and usefulness evidence.
- Separate implementation issues or PRs with acceptance criteria derived from the chosen decisions.

Discovery is complete when the team can explain where Map time is spent, what a partial warning means, which cached data can safely appear, which Near You hierarchy to build, and why the selected default radius is useful rather than merely faster.
