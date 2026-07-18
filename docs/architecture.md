# Architecture

## Shape
DC Pulse uses feature-oriented MVVM. `App` composes tabs and dependencies. Each feature owns its views and view models. Shared domain concepts live in `Core/Models`; infrastructure lives in focused `Core` modules. The initial views use `SampleData`; swapping to repositories should not change their domain inputs.

```text
SwiftUI feature view → feature view model → repository protocol
                                            ↓
                              source-specific ArcGIS adapter
                                            ↓
                                  ArcGISClient / URLSession
```

## Domain boundary
`PulseItem` is the normalized record consumed by features. It carries source identity, lifecycle dates, location, agency, source details, and attribution. Source-specific adapters—not views or the generic client—interpret field names, inconsistent dates, missing coordinates, and malformed values.

`PulseItem.ID` combines dataset and source record identity to avoid collisions. `PulseItem.SourceAttribute` retains display-safe dataset-specific values for Item Details without leaking transport objects.

## ArcGIS transport
`ArcGISQuery` creates query items for where clauses, selected fields, optional point/radius spatial constraints, pagination, ordering, and JSON output. `ArcGISClientProtocol` makes the layer URL injectable. `URLSessionArcGISClient`:

- validates HTTP status,
- recognizes ArcGIS error envelopes even on HTTP 200,
- decodes generic features and pagination metadata,
- exposes cancellation from URLSession,
- distinguishes invalid requests, transport, HTTP, server, and decoding failures.

Only authoritative layer URLs are configured after metadata and live-query verification. The 2026 311, Building Permits, and DDOT Construction Permits layers are live; each adapter owns its attribute interpretation and normalization policy.

## State and future work
`PulseDataStore` loads 311, Building Permit, and DDOT Construction Permit repositories through `CombinedPulseRepository` for the shared Pulse, Activity, and Map experiences. Each source receives its own pagination offset and balanced result share; normalized results are merged newest-first. A failed source produces a non-blocking warning when another source succeeds, while total source failure remains an actionable error. The half-mile default reduces dense DC result sets; quarter-mile and one-mile options trigger a shared reload. `LocationService` automatically requests Core Location authorization and provides a best-effort reverse-geocoded search label. `DCLocationRoutingPolicy` keeps the raw device result separate from the effective query center: in-area coordinates remain current location, nearby out-of-area coordinates route to an inset point in the supported DC service envelope, and distant coordinates route to a stable Downtown DC fallback. Adjusted and fallback coordinates are never exposed as current location or offered as Home. Ward selection and MapKit-backed DC address search provide explicit recovery paths.

If location is denied, restricted, fails, or resolves outside the supported area, Near You explains the active fallback with non-blocking recovery actions for Settings, retry, ward browsing, and address search. It does not interrupt launch with a ward modal. Deterministic Ward 1–8 search centers are bounding-box centers derived from DC GIS's authoritative 2022 Ward polygons (Administrative Other Boundaries, layer 53), verified July 11, 2026.

The most recent successful search is cached locally for ten minutes so repeat launches can render immediately; pull-to-refresh and the refresh button force a live update. A single home address and coordinate remain persisted behind `HomeLocationStore`, while `FollowedPlace` stores multiple additional addresses in SwiftData. Selecting a followed place loads its coordinate and transfers the user to the Map. Follow controls compare both rounded coordinates and normalized addresses so an already-saved place is visibly disabled instead of duplicated.

Noteworthy ranking gives permits within one tenth of a mile of the saved home a deliberate priority, then ranks lifecycle state and recency. This policy lives outside the view so its behavior remains testable and can evolve with user preferences.

## Watches, notifications, and history

`WatchedPulseItem` stores a normalized item snapshot, source-namespaced identity, watch date, last-seen date, and status transition state. Fresh results reconcile matching watches and Places surfaces changed records. `AutoWatchSettingsStore` persists an explicit opt-in and a 0.1- or 0.25-mile home radius. `AutoWatchPolicy` adds new 311 records and permits from refreshed nearby results while excluding older active 311 records and existing watches. `InAppNotification` provides a durable, on-device inbox for watched status transitions and newly auto-watched items near Home. Event keys deduplicate equivalent discoveries, while read state and the saved normalized item snapshot let the inbox remain useful without Apple notification permission or a network connection. The app can use background refresh for opportunistic updates, but reliable status-change push notifications require a minimal service that polls authoritative sources, deduplicates changes, and sends APNs notifications without storing unnecessary personal address data. Home coordinates should remain on-device where possible; any future server enrollment must use coarse watch regions or opaque identifiers and document retention clearly.

`NotificationService` requests local notification authorization only from the explicit Alerts control in Places. When launch, foreground, or user-initiated refresh reconciliation finds a watched status transition, it always records the event in the in-app inbox and, when authorized, also schedules a source-identifiable local notification; the app delegate permits presentation while DC Pulse is foregrounded. Returning to the foreground checks watched items when the last attempt is at least 15 minutes old. Background app refresh is intentionally not enabled yet because it requires the `fetch` Background Modes capability. Server-backed APNs remains the reliable long-term delivery mechanism.

Auto-watch remains usable as an on-device watch list even if notification access is denied, but enabling it initiates the same explicit system authorization flow used by the Alerts control. Status-summary navigation uses one selected status destination and direct item-detail links; this avoids ambiguous multiple-link activation inside a single `List` row on iOS 26.

`WatchedItemRefreshCoordinator` now queries each watched record by its source identifier independently of the active map geography, isolates partial source failures, and produces deterministic transition/missing-record results. Launch and manual Places refreshes reconcile these results into SwiftData, persist last-attempt/success timestamps, and schedule local transition alerts. Notification payloads retain source-namespaced identity, and tapping an alert routes to the saved Item Details snapshot or an explicit unavailable state. This coordinator is the capability-neutral core that a future `BGTaskScheduler` adapter will invoke.

`PulseObservationRecord` retains one evolving normalized observation per source-namespaced item for future history and notification work. User-facing nearby trends do not depend on that partial local history: `ServiceRequest311TrendRepository` performs two grouped ArcGIS count queries for equal recent and previous halves of the selected period and active radius. The resulting snapshot supplies both ranked changes and the complete 311 category catalog. Equal counts and categories with fewer than four combined records are suppressed from trends, while all returned categories remain filterable. Restaurant inspections will use their own adapter and repository after the authoritative service is verified, following the same source-isolation boundary as permits and 311.

## Map rendering

`ClusteredPulseMap` wraps `MKMapView` at the feature boundary so MapKit can perform native screen-density clustering. Views still receive normalized `PulseItem` values only. Individual annotations retain status colors and source glyphs; cluster selection produces the same unified item group used by Item Details navigation. Programmatic camera requests carry an incrementing identity so current-location, radius, ward, address, and search-this-area changes recenter without fighting user-driven map gestures. Annotation updates are identity-diffed so launch prefetch pages append only new markers instead of repeatedly removing and rebuilding the full map; existing markers remain visible with a linear update indicator during context changes. Map filters use expandable Data, Status, Time Range, Search Radius, and Category submenus. Selecting a complete-catalog 311 category performs a targeted bounded query, so lower-frequency types are not lost merely because they were absent from the newest general page.

The radius overlay keeps its boundary at every zoom level but removes the interior tint once all four visible-map corners are inside the searched radius. This preserves geographic context when the boundary is visible without washing out the map during close inspection.
## New civic-action boundaries

`Features/Report311` owns the photo-first request draft. `ReportPhotoAnalyzing` isolates image understanding from SwiftUI and currently uses Apple's on-device Vision classifier. Photo metadata is not read; the existing location service supplies a current DC location when permission is available, and manual address entry remains the fallback. The Photos picker and camera are separate, explicitly labeled inputs. The primary action remains visible above the keyboard and copies the reviewed draft before offering the official DC311 app and an explicit website fallback. A future direct-submission client must be a separately injected protocol backed by a documented DC interface.

`Features/Health` owns restaurant inspection semantics independently from `PulseItem`. Restaurant inspections have source-specific outcomes and violation classes that do not map honestly to request/permit statuses. Current generic destination links are informational placeholders, not nearby report integration. A future live repository will normalize an approved DC Health response into `RestaurantInspection` and drive a location/radius-aware map; server-rendered HTML is not consumed by views and is not currently treated as a production transport contract.

Restaurant map visibility is intentionally asymmetric: closures and inspections containing a Priority violation are highlighted by default. Follow-up-only, Priority Foundation, Core, restored, passed, and unknown results remain discoverable through an explicit **All restaurant inspections** filter. This keeps routine inspection history from overwhelming the primary request-and-permit map.

Surveillance-camera locations must be a separate opt-in map overlay that is off by default and controlled from Settings. A Flock-specific layer may ship only when every point comes from a documented public source with licensing, freshness, source labeling, and uncertainty behavior. General MPD/DDOT CCTV or automated traffic-enforcement locations must never be presented as Flock cameras.
