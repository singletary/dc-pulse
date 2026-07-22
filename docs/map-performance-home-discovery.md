# Map performance and Near You discovery

Status: planned

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
