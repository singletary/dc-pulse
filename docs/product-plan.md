# Product plan

## Vision
DC Pulse answers “What’s changing around me today?” with a professional native civic/GIS experience that hides raw GIS complexity. The product is restrained, modern, accessible, map-forward, and supports Dynamic Type, Dark Mode, and excellent loading, empty, and error states.

## Defaults
- Search radius: half a statute mile by default, with quarter-mile and one-mile options, from the user or selected followed place.
- Time period: the last 30 days.
- No authentication or custom backend for MVP.

## Original screens
1. **Pulse:** snapshot of new, active, and recently resolved activity, category summaries, and noteworthy changes.
2. **Map:** MapKit map with multiple layers; dataset, category, status, time, and search-radius filters; clustering at density; annotation selection opens Item Details.
3. **Activity:** chronological nearby timeline with sorting/filtering, a followed-location browser, and clear source, status, date, category, and distance.
4. **Places:** save a home address and follow multiple meaningful DC addresses. Followed places persist with SwiftData and open directly on the Map.
5. **Item Details:** title/category, status, relevant dates, agency, address/position, dataset-specific attributes, and original-source attribution.

## Delivery sequence

The current ranked execution plan is maintained in [roadmap.md](roadmap.md). It treats opportunistic Background App Refresh as the first notification delivery model and defers server-backed APNs until product use justifies it.
- **Phase 0 — foundation:** documentation, feature MVVM layout, domain model, reusable ArcGIS query/client, fixture tests, and polished sample-data shell.
- **Current vertical slice — 311:** query a selected nearby radius and 30 days, render live states in Pulse, Activity, Map, and Item Details, and incrementally load 30-record pages as users browse.
- **Status semantics:** unresolved records opened within 48 hours are New; older unresolved records are Active; source statuses containing closed, completed, or resolved are Resolved.
- **Verified time ranges:** 30 days, 90 days, six months, and year to date. A true rolling year requires querying and merging the prior-year service layer.
- **Location-aware 311:** request when-in-use location automatically at launch; retain Downtown DC as the fallback; refresh shared features and map context when a valid DC location arrives.
- **Search clarity:** show the exact search center on Map, a nearby reverse-geocoded label when available, visible loading state, responsive result limits, and Ward 1–8 fallback browsing.
- **Building Permits:** verified live 2026 source with an independent adapter, combined nearby results, source filters, partial-failure handling, and permit-specific details.
- **DDOT permits:** verified live 2026 source with an independent adapter, application-date semantics, combined nearby results, source filters, partial-failure handling, and permit-specific details.
- **Map depth:** native MapKit clustering now groups dense nearby annotations dynamically while retaining source glyphs and lifecycle colors for individual items.
- **Product depth:** expand followed places and on-device watch preferences with background refresh, notifications, and widgets.

## Planned product depth

- **Civic actions:** provide an official DC 311 submission/check-status destination and a native X compose handoff with a pre-filled status-update request, falling back to the web composer when X is not installed. The user reviews and sends the post in X; DC Pulse never posts on their behalf.
- **Permit safety:** permit details expose an official violation-reporting action without implying that the permit itself is a violation. Building permits open DOB's illegal-construction inspection form; DDOT public-space permits use DC 311, the reporting path specified by DDOT. The permit reference and address remain visible for the user to include because neither official destination supports a verified record-specific deep link.
- **Watching:** individual requests and permits can be saved on-device and reconciled when fresh matching data is loaded. An opt-in auto-watch rule saves new 311 requests and permits within 0.1 or 0.25 mile of home when those records are refreshed.
- **Notifications:** watched-item local alerts are explicitly opt-in and fire when an in-app refresh detects a status change. Enabling auto-watch prompts for notification access when the system has not asked yet; permission is never requested at first launch. Reliable background or remote change notifications still require Background Modes or a small server-side polling and push service.
- **History and trends:** persist normalized observations for future history while using complete grouped ArcGIS counts to compare equal halves of the selected date range for nearby 311 categories. Suppress equal and low-sample comparisons, make trend rows map-explorable, and retain query context in the UI; future releases can expand this into longer historical series.
- **Places and permits:** prioritize building and construction permits within 0.1 mile of a saved home, and later allow permit watches for every followed address.
- **Health data:** evaluate restaurant inspection and violation services as an independent vertical slice only after their authoritative fields, update behavior, and public endpoints are verified.

## MVP quality bar
No source-specific response object reaches SwiftUI. Malformed records are handled at the adapter boundary. Network errors are actionable, empty results are useful, source attribution is visible, and fixture-only work is never described as live integration.
