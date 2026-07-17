<div align="center">
  <img src="DCPulse/DCPulse/Assets.xcassets/AppIcon.appiconset/DC-Pulse-App-Icon.png" width="128" height="128" alt="DC Pulse app icon">
  <h1>DC Pulse</h1>
  <p><strong>See what’s changing around you in Washington, DC.</strong></p>
  <p>
    <a href="https://dcpulseapp.com">Website</a> ·
    <a href="https://dcpulseapp.com/#privacy">Privacy</a> ·
    <a href="https://dcpulseapp.com/#support">Support</a> ·
    <a href="docs/product-plan.md">Product plan</a> ·
    <a href="LICENSE">MIT License</a>
  </p>
</div>

DC Pulse is a native, map-forward iPhone app for exploring recent public activity around a location in Washington, DC. It turns DC’s ArcGIS and Open Data services into one approachable view of 311 service requests, building permits, and DDOT construction permits—without exposing people to raw GIS complexity.

> **Project status:** Pre-release. Version 1.0 (build 5) has completed its initial internal physical-iPhone pass and has been submitted for external TestFlight beta review. It has not been submitted for public App Store review.

<p align="center">
  <img src="marketing/app-store/screenshots/en-US/iPhone-6.9/01-near-you.png" width="23%" alt="DC Pulse Near You screen">
  <img src="marketing/app-store/screenshots/en-US/iPhone-6.9/02-map.png" width="23%" alt="DC Pulse map screen">
  <img src="marketing/app-store/screenshots/en-US/iPhone-6.9/03-requests.png" width="23%" alt="DC Pulse requests screen">
  <img src="marketing/app-store/screenshots/en-US/iPhone-6.9/04-places.png" width="23%" alt="DC Pulse places screen">
</p>

## What DC Pulse does

- **Near You** summarizes nearby requests, noteworthy changes, leading categories, and local trends.
- **Map** combines three public datasets with native clustering, lifecycle colors, search-area context, and expandable filters.
- **Requests** provides a chronological, sortable list for the current search or a followed place.
- **Places** saves Home and other meaningful DC locations on-device for quick return visits.
- **Item Details** normalizes dates, status, agency, address, source attributes, and official civic-action destinations.
- **Watches** track selected public records on-device and can produce local alerts when an in-app refresh detects a status change.
- **Report to 311 (beta)** turns a deliberately selected or captured photo into an editable, on-device request draft before an official DC app or website handoff.
- **Restaurant Health (data-gated)** models DC's real pass/fail and violation terminology. Nearby inspection reports and a useful inspection map will ship only after a dependable source contract or a separately reviewed ingestion approach is established.

Location is requested only to perform a nearby search. If a usable DC location is unavailable, people can browse by ward or search around a DC address. The default search covers **half a mile** and the **last 30 days**, with additional radius and time options available on Map.

## Current TestFlight focus

Build 5 is intentionally focused on reliability rather than adding another broad feature. External beta review is pending; once approved, testing should concentrate on:

1. Preserve close-in map records at wider radii, progressively load denser coverage, and expose an atomic **Reset** for all filters.
2. Keep Near You status and category summaries coherent by using complete grouped totals rather than a partial first page.
3. Add native pull-to-refresh to Requests, separate photo-library and camera actions, and suppress recency-only New-to-Active watch alerts.
4. Repeat the physical-iPhone regression pass for location, filters, watched-item navigation, local alerts, photo input, and external handoffs before opening external testing.
5. Investigate a durable restaurant-inspection feed and supported direct-311 contract after the external-beta stabilization pass.

Build 5 also removes redundant cold-launch requests, lets the Map become interactive while additional coverage arrives progressively, and isolates slow public-data sources so healthy results are not held up indefinitely.

Notification category icons, richer trends, widgets, and optional civic overlays remain planned, but they follow the submission-path and release-quality work above. See the [ranked roadmap](docs/roadmap.md) for acceptance criteria and dependency gates.

## Data sources

Each source has its own adapter and repository; source-specific ArcGIS records never reach SwiftUI views.

| Source | Current integration |
| --- | --- |
| DC 311 City Service Requests | Live 2026 layer, category counts, trends, and targeted filtering |
| DC Building Permits | Live 2026 layer with permit-specific normalization |
| DDOT Construction Permits | Live 2026 layer with public-space work details |

The verified endpoints, schema notes, query contract, and known source limitations are documented in [Data sources](docs/data-sources.md). Public records can be delayed, incomplete, or changed by their publishers; DC Pulse is not an official DC government service.

## Privacy by design

DC Pulse has no account system, advertising SDK, analytics SDK, or custom backend. Home, followed places, watched items, cached results, and preferences stay in on-device storage. Nearby searches send the selected coordinate and query parameters directly to the relevant DC ArcGIS service, without a DC Pulse account or device identifier. Photo classification for a 311 draft runs on-device; DC Pulse does not read photo location metadata, upload the photo, or submit the request.

See [App Store readiness](docs/app-store-readiness.md) for the current privacy inventory and disclosure assumptions.

## Architecture

DC Pulse uses feature-oriented MVVM with protocol-backed networking and location dependencies.

```text
SwiftUI feature view → feature view model → repository protocol
                                            ↓
                              source-specific ArcGIS adapter
                                            ↓
                                  ArcGIS client / URLSession
```

```text
DCPulse/DCPulse/
├── App/                 App composition and shared state
├── Core/
│   ├── Location/        Core Location boundary
│   ├── Models/          Unified domain and persistence models
│   ├── Networking/      ArcGIS query, client, and pagination
│   └── Notifications/   Watch reconciliation and local alerts
├── DesignSystem/        Reusable native components
├── Features/            Near You, Map, Requests, Places, Item Details, Health, Report 311
└── Resources/Fixtures/  Redacted representative payloads
```

The complete design and data-flow decisions live in [Architecture](docs/architecture.md).

## Development

The project is intentionally dependency-light and uses Swift, SwiftUI, MapKit, Core Location, SwiftData, URLSession, and XCTest. The current project is verified with Xcode 26.6 and targets iPhone on iOS 26.5 or later.

Open [DCPulse.xcodeproj](DCPulse/DCPulse.xcodeproj) and use the shared `DCPulse` scheme, or build from the command line:

```sh
xcrun simctl list devices available

xcodebuild \
  -project DCPulse/DCPulse.xcodeproj \
  -scheme DCPulse \
  -destination 'platform=iOS Simulator,name=<available iPhone>' \
  build

xcodebuild \
  -project DCPulse/DCPulse.xcodeproj \
  -scheme DCPulse \
  -destination 'platform=iOS Simulator,name=<available iPhone>' \
  test
```

Never change the development team, signing configuration, entitlements, provisioning, or bundle identifiers without explicit project-owner approval.

## Documentation

- [Product plan](docs/product-plan.md) — vision, screen plan, defaults, and delivery sequence
- [Architecture](docs/architecture.md) — boundaries, state, networking, watches, trends, and map rendering
- [Data sources](docs/data-sources.md) — authoritative layers, mappings, and resilience rules
- [Ranked roadmap](docs/roadmap.md) — release priorities and future work
- [App Store readiness](docs/app-store-readiness.md) — privacy, metadata, and device quality gates
- [App Store listing](docs/app-store-listing.md) — copy-ready metadata, privacy answers, review notes, and screenshot sequence
- [TestFlight checklist](docs/testflight-release.md) — internal beta preparation and smoke test

## Contributing and security

DC Pulse is open source under the [MIT License](LICENSE). Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) before proposing a change. Please report security or privacy concerns privately according to [SECURITY.md](SECURITY.md), especially if they involve a precise location, saved address, credential, or unpublished vulnerability.

## Acknowledgments

DC Pulse is made possible by public data published by the Government of the District of Columbia. It is an independent project and is not endorsed by, affiliated with, or a substitute for DC 311 or any District agency. For emergencies, call 911; use official DC services to submit or confirm government requests.
