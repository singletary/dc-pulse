# Data sources

## Live schema smoke audit — July 12, 2026

A read-only, one-record query against each production layer confirmed that every field selected by the repositories is still present with the expected ArcGIS field type, point geometry is returned with `outSR=4326`, and each response includes transfer-limit metadata. Representative identities observed during the audit were namespaced by source and were not added to fixtures:

- 311 layer 21: `SERVICEREQUESTID`, service/category/status/detail, date, address, ward, and coordinate fields verified.
- Building Permits layer 18: `PERMIT_ID`, type/subtype/category/status, work description, issue/update date, address/area, coordinate, zoning, SSL, and fee fields verified.
- DDOT layer 48: tracking/permit identifiers, lifecycle dates/status, address/permittee/work detail, work-type flags, coordinate, and edit date verified.

The audit demonstrates current schema compatibility, not an availability guarantee. Fixture-backed adapter tests remain the deterministic boundary verification, and live failures must continue to degrade independently by source.

On July 13, 2026, a read-only grouped-statistics query was also verified against 311 layer 21 using `outStatistics`, `groupByFieldsForStatistics=SERVICECODEDESCRIPTION`, and the app's spatial parameters. The response included `Graffiti Removal` (four records within the tested half-mile/30-day context), confirming that its earlier UI absence came from newest-page sampling rather than a missing source category. DC Pulse now uses grouped counts for its complete category catalog and nearby trend comparisons, then uses a source-specific targeted query when a 311 category is selected on Map.

## Planned ArcGIS Feature Services

| Dataset | MVP role | Integration state |
|---|---|---|
| 311 City Service Requests | First live vertical slice; nearby requests from a selected time range | Verified 2026 layer; live repository implemented |
| 2026 Building Permits | Building activity layer | Verified 2026 layer; live repository implemented |
| 2026 DDOT Construction Permits | Transportation/public-space construction layer | Verified 2026 layer; live repository implemented |

## DC Health restaurant inspections

DC Health's authoritative public inspection search is `https://dc.healthinspections.us/?a=Inspections`. A read-only review on July 13, 2026 confirmed that it exposes establishment, permit, inspection type/date, and detailed HTML inspection reports. Those reports contain Priority, Priority Foundation, and Core violation counts. DC Health explicitly uses pass/fail inspections and does not publish letter grades, percentages, or restaurant ratings.

The public portal is a server-rendered ColdFusion search form, not a documented JSON, ArcGIS, or other supported application interface. The generic official destinations exposed by the current TestFlight build do not provide a useful location-centered report experience and must not be described as nearby inspection integration. The normalized `RestaurantInspection` model remains ready for a future source adapter. Nearby restaurant results must not ship until DC Health or its publisher provides a stable contract or an alternative ingestion approach passes explicit legal, reliability, caching, rate-limit, freshness, and maintenance review. HTML scraping is not considered a verified production source by default.

Closures must receive the strongest visual treatment because DC Health uses them for imminent public-health risks. Priority and Priority Foundation violations follow; Core violations remain visible but must not be presented as equivalent to closure. Inspection reports are point-in-time observations, not permanent ratings of an establishment.

When an approved inspection feed becomes available, a nearby map centers on the active DC Pulse search location and respects its radius. The Map defaults to closures, follow-up-required inspections, and inspections with at least one Priority violation. An explicit filter may reveal all supported outcomes. The filter must explain that hidden results are routine or lower-severity records, not missing data. Each marker must open establishment, inspection date/outcome, notable violations, and authoritative attribution.

## Flock and public surveillance cameras

MPD's [submitted 2026 performance-hearing response](https://dccouncil.gov/wp-content/uploads/2026/03/SUBMITTED_MPD-2026-Perf-Hrg-Questions-and-Attachments_02-23-26_v2.pdf) reports that, as of January 2026, Flock Safety owned and operated nine fixed CCTVs, 67 fixed license-plate readers, and four mobile license-plate readers connected to MPD's surveillance environment. The response provides counts, not a Flock-specific list of fixed coordinates; mobile readers do not have stable map locations.

MPD separately publishes neighborhood CCTV locations, and DC GIS publishes DDOT traffic CCTV and automated safety-camera layers. Those sources describe different camera programs and cannot be relabeled as Flock. DC Pulse will not infer a camera's vendor from appearance, proximity, or a generic CCTV record.

A future **Flock cameras** overlay must be off by default and enabled explicitly in Settings. Each displayed point must carry its source, observation or publication date, camera type, whether the location is authoritative or crowdsourced, and a report-correction path. A crowdsourced source such as OpenStreetMap/DeFlock requires a license and reliability review, visible attribution, bounded caching, and language that the map may be incomplete or outdated before integration.

## DC 311 submission

The configured official website fallback is `https://311.dc.gov/citizen/s/`. DC also documents phone, text, X, portal, and an official mobile app, but no supported public write API has been verified. Because the website rendered unreliably during physical-iPhone testing, the current handoff prefers the official DC311 app and presents the website only as an explicit fallback after copying the reviewed draft.

DC Pulse can safely prepare a request draft: the person selects or takes a photo, Apple's on-device Vision framework suggests a broad civic category, and current location or manual address supplies the report location. Photo location metadata is not read. Every inferred field is editable. The app copies reviewed details and opens the official portal; it does not claim that a request was submitted and does not upload the photo during analysis. True in-app submission requires a supported DC contract and a confirmation identifier returned by DC.

Ward fallback centers are derived from the authoritative DC GIS **Ward - 2022** polygon layer at `https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Administrative_Other_Boundaries/MapServer/53`.

The authoritative 2026 311 layer is `https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/ServiceRequests/FeatureServer/21`. Its metadata and a live spatial/date query were verified on July 11, 2026. It supports point geometry, distance queries, ordering, pagination, JSON, a 1,000-record service maximum, and WGS84 output. A redacted representative fixture is checked in.

The layer's `DETAILS` field supplies the public submitter description when present. Layer metadata declares `hasAttachments: false`, exposes no photo URL field, and defines no relationships for comments or status history, so the current public source cannot supply submitted images or follow-up comments.

The public ArcGIS record includes a stable service-request identifier, but no verified human-readable per-record URL for the newer 311 Salesforce experience was found. DC Pulse displays that request ID with source attribution and does not construct an unverified portal link. A direct link should only be added after DC publishes a stable public lookup contract and it is tested against live records.

The layer is stored in Maryland State Plane (`wkid=26985`), so WGS84 point queries must send `inSR=4326` as well as `outSR=4326`. Omitting `inSR` can yield an empty response even for valid DC longitude/latitude coordinates.

The authoritative 2026 Building Permits layer is `https://maps2.dcgis.dc.gov/dcgis/rest/services/FEEDS/DCRA/FeatureServer/18`. Its metadata and a live spatial/date query were verified July 12, 2026. The Department of Buildings layer supports point-distance queries, WGS84 output, ordering by `ISSUE_DATE`, pagination, and a 2,000-record service maximum. It is stored in Maryland State Plane (`wkid=26985`), so queries also specify `inSR=4326`.

Building permits map independently through `BuildingPermitAdapter`. Stable identity comes from `PERMIT_ID`; the normalized issue date comes from `ISSUE_DATE`; type, subtype, status, work description, address, ward or neighborhood cluster, fees, zoning, and square/lot remain source-owned mappings. Coordinates reported as `0,0` or outside DC are excluded from Map without dropping the list record, matching the source publisher's geocoding warning.

The authoritative 2026 DDOT Construction Permits layer is `https://maps2.dcgis.dc.gov/dcgis/rest/services/FEEDS/DDOT/FeatureServer/48`. Its metadata and live spatial/date queries were verified July 12, 2026. The layer supports point-distance queries, WGS84 output, ordering, pagination, and a 1,000-record maximum. It is stored in Maryland State Plane (`wkid=26985`), so WGS84 searches specify `inSR=4326`.

DDOT records map independently through `DDOTConstructionPermitAdapter`. Identity prefers `PERMITNUMBER` and falls back to `TRACKINGNUMBER`. `APPLICATIONDATE` defines recent activity because valid submissions often have future effective dates and no issued date; issue, effective, and expiration dates remain permit-specific details. Boolean source flags normalize excavation, fixtures, paving, landscaping, projections, and public-space rental into a human-readable subtype. Invalid or out-of-area coordinates are omitted without dropping the list record.

## Query contract
Nearby requests use `geometry=<longitude>,<latitude>`, `geometryType=esriGeometryPoint`, `spatialRel=esriSpatialRelIntersects`, `distance=1`, `units=esriSRUnit_StatuteMile`, and `outSR=4326`. Queries also support `where`, selected `outFields`, offsets/counts, ordering when supported, returned geometry, and `f=json`.

The 311 repository uses `ADDDATE >= DATE 'yyyy-MM-dd'` and orders by `ADDDATE DESC`. Building Permits uses `ISSUE_DATE >= DATE 'yyyy-MM-dd'` and orders by `ISSUE_DATE DESC`. DDOT uses `APPLICATIONDATE >= DATE 'yyyy-MM-dd'` and orders by `APPLICATIONDATE DESC`. `CombinedPulseRepository` queries all three sources independently, balances each page across sources, merges normalized records by date, and preserves healthy results with a visible warning if one public service fails.

## Resilience rules
- Continue pagination while `exceededTransferLimit` is true, advancing by the number of returned features (or the requested page size when appropriate).
- Treat ArcGIS error envelopes as failures regardless of HTTP status.
- Tolerate absent optional attributes, but reject/quarantine records that cannot produce a stable identifier or required domain values.
- Accept explicitly supported epoch-millisecond and textual date formats per source adapter.
- Missing coordinates may remain valid for list presentation, but cannot produce a map annotation.
- Preserve a link/attribution to the authoritative DC source.
