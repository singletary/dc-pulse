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

Only the authoritative 2026 311 layer URL is configured after metadata and live-query verification. Dataset adapters each own attribute interpretation and normalization policy; future permit URLs remain unconfigured until separately verified.

## State and future work
`PulseDataStore` loads the first live 311 repository for the shared Pulse, Activity, and Map experiences and exposes idle/loading/content/empty/error state. Its half-mile default reduces dense DC result sets; quarter-mile and one-mile options trigger a shared reload. The repository requests the newest 30 records first, then Pulse and Activity request subsequent 30-record ArcGIS pages as the user reaches the end of the list. Page offsets advance by the source feature count, and `exceededTransferLimit` determines whether more data is available. `LocationService` wraps Core Location authorization, one-shot location updates, and a best-effort reverse-geocoded search label. Downtown DC is the privacy-preserving fallback until the user explicitly selects **Use My Location**; every successful update refreshes all shared features, even when Simulator returns the same coordinate. Map always displays and centers on a dedicated search-center marker.

If location is denied, restricted, fails, or produces no nearby results, Pulse offers a ward picker. Its deterministic Ward 1–8 search centers are bounding-box centers derived from DC GIS's authoritative 2022 Ward polygons (Administrative Other Boundaries, layer 53), verified July 11, 2026. SwiftData will later back Places and preferences. Caching and refresh stay behind repository protocols.
