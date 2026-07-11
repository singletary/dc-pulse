# Product plan

## Vision
DC Pulse answers “What’s changing around me today?” with a professional native civic/GIS experience that hides raw GIS complexity. The product is restrained, modern, accessible, map-forward, and supports Dynamic Type, Dark Mode, and excellent loading, empty, and error states.

## Defaults
- Search radius: half a statute mile by default, with quarter-mile and one-mile options, from the user or selected followed place.
- Time period: the last 30 days.
- No authentication or custom backend for MVP.

## Original screens
1. **Pulse:** snapshot of new, active, and recently resolved activity, category summaries, and noteworthy changes.
2. **Map:** MapKit map with multiple layers; dataset, category, status, and time filters; clustering at density; annotation selection opens Item Details.
3. **Activity:** chronological nearby timeline with sorting/filtering and clear source, status, date, category, and distance.
4. **Places:** save and follow meaningful locations. Persistence may follow in a later SwiftData phase; the feature boundary remains now.
5. **Item Details:** title/category, status, relevant dates, agency, address/position, dataset-specific attributes, and original-source attribution.

## Delivery sequence
- **Phase 0 — foundation:** documentation, feature MVVM layout, domain model, reusable ArcGIS query/client, fixture tests, and polished sample-data shell.
- **Current vertical slice — 311:** query a selected nearby radius and 30 days, render live states in Pulse, Activity, Map, and Item Details, and incrementally load 30-record pages as users browse.
- **Location-aware 311:** request when-in-use location only after an explicit user action; retain Downtown DC as the fallback; refresh shared features and map context when a location arrives.
- **Search clarity:** show the exact search center on Map, a nearby reverse-geocoded label when available, visible loading state, responsive result limits, and Ward 1–8 fallback browsing.
- **Permits:** independently verify and adapt 2026 Building Permits and 2026 DDOT Construction Permits; add layer filters and clustering.
- **Product depth:** followed-place persistence and preferences with SwiftData, caching/background refresh, notifications, and widgets.

## MVP quality bar
No source-specific response object reaches SwiftUI. Malformed records are handled at the adapter boundary. Network errors are actionable, empty results are useful, source attribution is visible, and fixture-only work is never described as live integration.
