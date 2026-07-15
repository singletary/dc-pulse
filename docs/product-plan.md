# Product plan

## Vision
DC Pulse answers “What’s changing around me today?” with a professional native civic/GIS experience that hides raw GIS complexity. The product is restrained, modern, accessible, map-forward, and supports Dynamic Type, Dark Mode, and excellent loading, empty, and error states.

## Defaults
- Search radius: half a statute mile by default, with quarter-mile and one-mile options, from the user or selected followed place.
- Time period: the last 30 days.
- No authentication or custom backend for MVP.

## Original screens
1. **Pulse (now Near You):** snapshot of new, active, and recently resolved requests, category summaries, and noteworthy changes.
2. **Map:** MapKit map with multiple layers; dataset, category, status, time, and search-radius filters; clustering at density; annotation selection opens Item Details.
3. **Activity (now Requests):** chronological nearby timeline with sorting/filtering, a followed-location browser, and clear source, status, date, category, and distance.
4. **Places:** save a home address and follow multiple meaningful DC addresses. Followed places persist with SwiftData and open directly on the Map.
5. **Item Details:** title/category, status, relevant dates, agency, address/position, dataset-specific attributes, and original-source attribution.

## Delivery sequence

The current ranked execution plan is maintained in [roadmap.md](roadmap.md). Version 1.0 (build 2) is in internal TestFlight testing. The next build prioritizes the 311 text-entry and official-portal handoff defects, followed by a physical-device regression pass. It treats opportunistic Background App Refresh as the first notification delivery model and defers server-backed APNs until product use justifies it.
- **Phase 0 — foundation:** documentation, feature MVVM layout, domain model, reusable ArcGIS query/client, fixture tests, and polished sample-data shell.
- **Current live product slice:** query 311, Building Permit, and DDOT Construction Permit sources independently; render normalized results in Near You, Requests, Map, and Item Details; preserve healthy sources during partial failures; and load additional records progressively.
- **Status semantics:** unresolved records opened within 48 hours are New; older unresolved records are Active; source statuses containing closed, completed, or resolved are Resolved.
- **Verified time ranges:** 30 days, 90 days, six months, and year to date. A true rolling year requires querying and merging the prior-year service layer.
- **Location-aware 311:** request when-in-use location automatically at launch; retain Downtown DC as the fallback; refresh shared features and map context when a valid DC location arrives.
- **Search clarity:** show the exact search center on Map, a nearby reverse-geocoded label when available, visible loading state, responsive result limits, and Ward 1–8 fallback browsing.
- **Building Permits:** verified live 2026 source with an independent adapter, combined nearby results, source filters, partial-failure handling, and permit-specific details.
- **DDOT permits:** verified live 2026 source with an independent adapter, application-date semantics, combined nearby results, source filters, partial-failure handling, and permit-specific details.
- **Map depth:** native MapKit clustering now groups dense nearby annotations dynamically while retaining source glyphs and lifecycle colors for individual items.
- **Product depth:** Home and followed places, item watches, auto-watch rules, an on-device notification inbox, local alerts on detected refresh changes, and complete nearby 311 trend/category queries are implemented. Background scheduling, notification preferences, notification-row category icons, and widgets remain planned.

## Planned product depth

- **Civic actions:** provide an official DC 311 submission/check-status destination and a native X compose handoff with a pre-filled status-update request, falling back to the web composer when X is not installed. The user reviews and sends the post in X; DC Pulse never posts on their behalf. Before the next TestFlight build, fix keyboard dismissal/reachability in the 311 draft and replace the current black-page portal result with a verified launch path plus fallback.
- **Permit safety:** permit details expose an official violation-reporting action without implying that the permit itself is a violation. Building permits open DOB's illegal-construction inspection form; DDOT public-space permits use DC 311, the reporting path specified by DDOT. The permit reference and address remain visible for the user to include because neither official destination supports a verified record-specific deep link.
- **Watching:** individual requests and permits can be saved on-device and reconciled when fresh matching data is loaded. An opt-in auto-watch rule saves new 311 requests and permits within 0.1 or 0.25 mile of home when those records are refreshed.
- **Notifications:** a persistent in-app inbox records watched-item status changes and newly auto-watched records near Home, with unread state and direct Item Details navigation. It works without system notification permission. Local system alerts remain explicitly opt-in and fire when an app refresh detects a status change; enabling auto-watch prompts for permission when the system has not asked yet. Launch, manual refresh, and throttled foreground refresh all reconcile watches. Reliable background or remote delivery still requires Background Modes or a small server-side polling and push service.
- **History and trends:** persist normalized observations for future history while using complete grouped ArcGIS counts to compare equal halves of the selected date range for nearby 311 categories. Suppress equal and low-sample comparisons, make trend rows map-explorable, and retain query context in the UI; future releases can expand this into longer historical series.
- **Places and permits:** prioritize building and construction permits within 0.1 mile of a saved home, and later allow permit watches for every followed address.
- **Health data:** replace generic destination links with a nearby inspection map only after authoritative fields, update behavior, and a dependable source interface are verified. Default visibility should emphasize closures, follow-up-required inspections, and Priority/Priority Foundation violations; an explicit filter reveals all supported reports.

## MVP quality bar
No source-specific response object reaches SwiftUI. Malformed records are handled at the adapter boundary. Network errors are actionable, empty results are useful, source attribution is visible, and fixture-only work is never described as live integration.
## Near-term civic actions

DC Pulse should reduce the work required to report a neighborhood issue without obscuring where the official transaction occurs. The photo-first flow suggests a broad 311 category and location, keeps those suggestions editable, and never submits without an explicit final action. Until DC offers a supported write contract, the official DC 311 portal remains responsible for authentication, required fields, photo upload, submission, and confirmation numbers. The handoff must be verified on a physical iPhone and must fail usefully when the portal cannot render; a blank embedded page is not an acceptable release state.

Restaurant health is a distinct experience rather than another 311 category. It should prioritize closures and unresolved Priority/Priority Foundation violations, show inspection history in context, and avoid grades or scores that DC Health does not publish. Nearby integration follows only after a stable official data interface is verified.

On Map, only closures and inspections with Priority violations appear automatically; an **All restaurant inspections** filter reveals the complete supported result set. Surveillance-camera locations are a separate Settings-controlled overlay that is off by default. Camera vendor and type must come from the cited source rather than inference.
