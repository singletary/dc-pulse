# Data sources

## Planned ArcGIS Feature Services

| Dataset | MVP role | Integration state |
|---|---|---|
| 311 City Service Requests | First live vertical slice; nearby activity from the last 30 days | Verified 2026 layer; live repository implemented |
| 2026 Building Permits | Building activity layer | Planned; independent adapter required |
| 2026 DDOT Construction Permits | Transportation/construction layer | Planned; independent adapter required |

The authoritative 2026 311 layer is `https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/ServiceRequests/FeatureServer/21`. Its metadata and a live spatial/date query were verified on July 11, 2026. It supports point geometry, distance queries, ordering, pagination, JSON, a 1,000-record service maximum, and WGS84 output. A redacted representative fixture is checked in.

The layer is stored in Maryland State Plane (`wkid=26985`), so WGS84 point queries must send `inSR=4326` as well as `outSR=4326`. Omitting `inSR` can yield an empty response even for valid DC longitude/latitude coordinates.

## Query contract
Nearby requests use `geometry=<longitude>,<latitude>`, `geometryType=esriGeometryPoint`, `spatialRel=esriSpatialRelIntersects`, `distance=1`, `units=esriSRUnit_StatuteMile`, and `outSR=4326`. Queries also support `where`, selected `outFields`, offsets/counts, ordering when supported, returned geometry, and `f=json`.

The 311 repository uses `ADDDATE >= DATE 'yyyy-MM-dd'`, orders by `ADDDATE DESC`, and maps the verified 2026 fields through `ServiceRequest311Adapter`. Other datasets must independently verify their date fields and syntax.

## Resilience rules
- Continue pagination while `exceededTransferLimit` is true, advancing by the number of returned features (or the requested page size when appropriate).
- Treat ArcGIS error envelopes as failures regardless of HTTP status.
- Tolerate absent optional attributes, but reject/quarantine records that cannot produce a stable identifier or required domain values.
- Accept explicitly supported epoch-millisecond and textual date formats per source adapter.
- Missing coordinates may remain valid for list presentation, but cannot produce a map annotation.
- Preserve a link/attribution to the authoritative DC source.
