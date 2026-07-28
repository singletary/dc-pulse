# Map performance and Near You discovery

Status: in progress

Owner: product and iOS

Added: July 22, 2026

Roadmap priorities: P0 Map clarity and baseline; P1 caching, Near You simplification, and radius decision

## Purpose

This brief turns reported Map loading problems, a crowded Near You screen, and questions about caching and search radius into measurable work. It is a discovery and decision document, not authorization to change retrieval limits, product defaults, or the production interface without reviewing the evidence.

Update this file with dated measurements, screenshots, findings, and decisions. Keep the ranked summary in [roadmap.md](roadmap.md) short.

## Reported problems to reproduce

- Map population feels slow.
- The loading card below Filters shows an indeterminate linear progress indicator rather than live completion and its text can be truncated.
- After loading, a triangle notice beginning **Some map results…** can be truncated and cannot be opened for details.
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

Signpost metadata is intentionally limited to a public dataset label, coverage-pass label, radius bucket, pagination offset/limit, outcome, byte count, and item count. It never includes coordinates, addresses, saved-place names, request identifiers, complete URLs, query clauses, device/account identifiers, or photo data. Signposts are inspected locally in an attached Instruments session; DC Pulse does not upload them, persist them in app storage, or operate a diagnostics backend. This preserves the current **Developer analytics: No** and **Diagnostics collected by the developer: No** disclosures.

### Repeatable capture procedure

1. Use Instruments’ **Points of Interest** instrument and select the `MapPerformance` category.
2. Record the device model, OS, app commit/build, radius, period, network condition, and whether the app cache is cold or warm. Do not record a coordinate or address.
3. Start capture before launching or opening Map. Stop after **Bounded Map Coverage Complete** or the explicit partial result.
4. Run each scenario at least five times without changing retrieval limits. For a cold run, reinstall or clear only the app container; for a warm run, first complete the same radius/period context within the ten-minute cache lifetime.
5. Record elapsed time from the initiating action to **Map Interactive**, **First Map Markers**, **Close-in Coverage Complete**, and **Bounded Map Coverage Complete**, plus their item counts.
6. Report median, p90, and worst elapsed time. Keep Simulator and physical-iPhone results in separate tables and retain `.trace` files only in approved private test storage.

Use this row shape for every scenario:

| Environment | Cache | Radius | Period | Network | Runs | Interactive median/p90/worst | First markers median/p90/worst | Close-in median/p90/worst | Bounded median/p90/worst | Final items | Partial sources |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- | ---: | --- |
| Pending | Cold/Warm | 0.25/0.5/1 mi | 30 days/densest | Wi-Fi/constrained/offline recovery | 5+ | Pending | Pending | Pending | Pending | Pending | Pending |

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

This store is not wired into `PulseDataStore` yet. The next prototype slice must define the versioned payload/migration from the current ten-minute `UserDefaults` entry, expose an honest cached timestamp in Map UI, and run fresh per-source reconciliation without turning stale cache into authoritative data.

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

## P1 workstream — Near You simplification

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

## Deliverables and exit criteria

- Dated baseline results with raw scenario counts and summarized median/p90 timings.
- Screenshots of every loading/warning defect and the revised states.
- A source capability table for incremental refresh.
- A bounded cache design with migration and failure semantics.
- Three Near You concept sets and a recorded selection decision.
- A radius recommendation backed by correctness, latency, density, and usefulness evidence.
- Separate implementation issues or PRs with acceptance criteria derived from the chosen decisions.

Discovery is complete when the team can explain where Map time is spent, what a partial warning means, which cached data can safely appear, which Near You hierarchy to build, and why the selected default radius is useful rather than merely faster.
