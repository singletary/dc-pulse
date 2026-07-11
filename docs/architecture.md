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
`PulseDataStore` loads the first live 311 repository for the shared Pulse, Activity, and Map experiences and exposes idle/loading/content/empty/error state. `LocationService` wraps Core Location authorization and one-shot location updates. Downtown DC is the privacy-preserving fallback until the user explicitly selects **Use My Location**; a successful update refreshes all shared features and recenters the map. SwiftData will later back Places and preferences. Caching and refresh stay behind repository protocols.
