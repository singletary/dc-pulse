# Restaurant inspection feed contract

Status: local boundary implemented; no production feed approved

Last reviewed: July 29, 2026

## Release boundary

This contract prepares DC Pulse to consume a future approved restaurant
inspection feed. It does not authorize scraping, define a production endpoint,
or expose Restaurant Health on Near You or Map.

The current authoritative public experience remains the DC Health inspection
database. DC Health says it performs pass/fail inspections, publishes reports
after program-manager review, and may take from 24 hours to seven days to post
them. No documented JSON, ArcGIS, or other supported machine interface was
found in the current source review.

Until DC Health or an approved publisher provides a stable contract:

- the restaurant feature remains hidden from Near You;
- generic portal links are not described as nearby results;
- the app does not scrape the HTML search form or inspection reports; and
- no production repository or network client is connected to this adapter.

## Version 1 envelope

The fixture-backed boundary expects:

```json
{
  "version": 1,
  "schema": "dc-pulse.restaurant-inspections.v1",
  "generatedAt": "2026-07-29T16:00:00Z",
  "attribution": "DC Health",
  "sourceURL": "https://dchealth.dc.gov/service/division-food",
  "records": []
}
```

Every record must provide:

- stable permit and inspection identifiers;
- establishment name and display address;
- optional ward;
- valid coordinates inside the supported DC service envelope;
- inspection date and type;
- one recognized outcome;
- nonnegative Priority, Priority Foundation, and Core counts; and
- an HTTPS authoritative report URL.

The normalized model retains the envelope generation date, attribution, and
source URL so every future result can explain its source and freshness.

## Fail-closed behavior

The adapter publishes no records when:

- the kill switch is off;
- the configured maximum age is nonfinite or not positive;
- JSON or required fields cannot be decoded;
- the payload version is unsupported;
- the schema fingerprint changes;
- the generation timestamp is in the future or older than the configured
  maximum age;
- attribution is empty or the source URL is not HTTPS; or
- any record has empty identity/display fields, invalid/out-of-DC coordinates,
  negative counts, a date after feed generation, or a non-HTTPS report URL.

Rejecting the full feed avoids presenting a partially misinterpreted schema as
healthy data. A future repository may retain a separately validated older
snapshot, but it must label that snapshot stale and must not silently convert
an adapter failure into an empty successful result.

## Query and presentation policy

A future map query must use the active DC Pulse search center and a finite,
positive radius. Results are sorted by newest inspection date.

The default attention filter includes:

- closures;
- follow-up-required inspections;
- inspections with Priority violations; and
- inspections with Priority Foundation violations.

The explicit all-results filter additionally includes passed, restored,
unknown, and Core-only records. Inspection observations are not restaurant
grades, scores, or permanent ratings.

## Approval checklist for a real feed

Before connecting transport or exposing results:

1. identify the publisher and obtain written permission or documented public
   interface terms;
2. establish update cadence, maximum supported staleness, retention, rate
   limits, caching, and incident contacts;
3. confirm stable identifiers, coordinates, outcomes, violation definitions,
   report links, and closure/restoration semantics;
4. define change notification or schema-version ownership;
5. configure monitored freshness and error metrics without collecting user
   search coordinates;
6. establish a remotely operable or release-controlled kill switch;
7. validate representative, malformed, changed-schema, stale, empty, and
   partial-source payloads;
8. perform accessibility and physical-device Map validation; and
9. review legal, privacy, attribution, maintenance, and operating costs if the
   source requires server-side ingestion.
