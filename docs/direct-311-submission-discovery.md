# Direct DC 311 submission discovery

Status: supported user-controlled handoffs improved; direct submission remains contract-gated

Last checked: July 29, 2026

## Decision

DC Pulse must not submit a DC 311 request directly yet. The District documents
several public, user-controlled submission channels, but the current review did
not find a documented production API contract that DC Pulse can safely adopt.
The app should continue to prepare an editable local draft and hand control to
an official channel.

DC Pulse now offers these supported handoffs:

- the District's [DC311 mobile app](https://ouc.dc.gov/page/dc-311-mobile-app);
- the official [311 Online portal](https://311.dc.gov/citizen/s/); and
- Text DC311 at `32311`, where the person sends `NEW` for a new request or
  `STATUS` for an existing request and follows the official prompts.

Opening Messages does not send anything. DC Pulse does not prefill or send a
message, transfer the selected photo, represent the draft as submitted, or
invent a confirmation number. The reviewed text remains on the pasteboard only
after the person explicitly chooses the handoff.

## Evidence reviewed

The current [OUC 311 overview](https://ouc.dc.gov/page/311-city-services) lists
phone, Text DC311, X, 311 Online, and the official mobile app as submission
channels. It says every submitted request receives a confirmation number that
can be checked through the portal, app, Text DC311, live chat, or phone.

The current [Text to 311 instructions](https://ouc.dc.gov/service/text-311)
document `NEW`/`MENU` at `32311` for submission and `STATUS` for status checks.
Only a featured subset is handled directly in the text flow; other categories
redirect to 311 Online.

The [DC311 mobile-app page](https://ouc.dc.gov/page/dc-311-mobile-app) documents
photo-initiated requests, picture geolocation, duplicate detection, activity
tracking, and completed lifecycle views. It does not publish an app URL scheme,
universal-link parameter contract, partner SDK, or third-party submission
contract. Therefore DC Pulse links to the official App Store listing rather
than guessing a private deep link.

The public [2026 Service Requests ArcGIS layer](https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/ServiceRequests/FeatureServer/21)
supports reading public records. Its service description and capabilities do
not constitute a supported intake contract, and DC Pulse must not treat its
editable field metadata as authorization to write.

## Legacy Open311 assessment

The [Open311 server registry](https://wiki.open311.org/GeoReport_v2/Servers/)
still lists a Washington, DC GeoReport v2 production base at:

`http://app.311.dc.gov/cwi/Open311/v2/`

Read-only availability checks on July 29, 2026 found:

- the documented HTTP discovery and services requests timed out;
- the HTTPS variants redirected and then returned HTTP 522; and
- the current `https://311.dc.gov/citizen/s/` portal returned HTTP 200.

The registry has no DC API-key request link, test endpoint, current DC API
documentation, service-level expectations, or terms. Historical District
documents describe Open311 and third-party integrations, but they do not prove
that this legacy endpoint remains a supported public production intake route
in 2026.

No POST, live service request, portal automation, authentication attempt, or
private Salesforce inspection was performed.

## Contract questions that remain open

Before direct submission can be designed, OUC/OCTO must provide or confirm:

1. the supported production and non-production endpoints;
2. partner eligibility, API-key or OAuth issuance, and credential storage rules;
3. current service codes, required fields, conditional metadata, and validation;
4. address/geocoding requirements and whether approximate coordinates are valid;
5. photo formats, size limits, metadata handling, upload sequence, and retention;
6. requester contact, anonymous-submission, consent, and privacy requirements;
7. rate limits, quotas, retry guidance, maintenance windows, and support contacts;
8. duplicate detection and a client idempotency contract;
9. cancellation and timeout semantics;
10. the authoritative success response and DC confirmation-number lifecycle;
11. terms of use, attribution, audit, accessibility, and incident obligations;
12. whether a documented universal link or app-to-app handoff can accept reviewed
    category, description, location, and photo inputs without private interfaces.

## Safe non-production verification plan

If the District confirms a supported route:

1. obtain written integration terms and a dedicated test environment or explicit
   permission for named non-service test categories;
2. implement the client behind an injected protocol with redacted diagnostics;
3. validate service definitions and required fields before allowing submission;
4. use a client-generated idempotency key and reject duplicate taps locally;
5. keep category, description, location, contact fields, and photo editable;
6. treat timeouts as unknown outcomes until the server can resolve idempotency;
7. show "submitted" only after receiving and validating a DC confirmation number;
8. retain the official app, portal, and text handoffs as recovery paths;
9. add fixture-backed success, validation, auth, rate-limit, timeout,
   cancellation, malformed-response, and duplicate tests; and
10. perform a deliberately approved end-to-end test without creating a false
    public service request.
