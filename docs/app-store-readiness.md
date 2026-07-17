# App Store readiness

## Current build metadata

- Display name: **DC Pulse**
- Bundle identifier: `com.dcpulseapp.DCPulse`
- Marketing version: `1.0`
- Build number: `5`
- Distribution state: initial internal physical-iPhone pass complete; submitted for external TestFlight beta review
- Supported device family: iPhone
- Location permission: When In Use only
- Camera permission: requested only when the person chooses **Take Photo** in the 311 draft flow
- Authentication, advertising, analytics SDKs, and custom backend: none
- Non-exempt encryption: none; the app uses Apple-provided networking and declares this in its Info.plist

Signing, capabilities, entitlements, bundle identifiers, and Apple-account configuration require explicit approval before changes.

## Current external-beta gates

- Address any Beta App Review feedback, then verify build 5's map radius/filter-reset behavior, coherent Near You totals, Requests pull-to-refresh, distinct Photos/Camera actions, and progressive initial loading with external testers.
- Monitor the external beta for correctness, performance, crash, navigation, accessibility, and public-data reliability feedback before public App Store review.
- Keep restaurant inspection language data-gated until a nearby report map is backed by a dependable, reviewed source.

The copy-ready listing, review notes, privacy recommendation, and final colorful light-mode screenshot sequences for the 6.9-inch and 6.5-inch App Store slots are maintained in `docs/app-store-listing.md` and `marketing/app-store`.

## Privacy behavior and draft disclosure

DC Pulse does not use tracking or advertising and does not operate a backend. Home, followed places, watched items, preferences, cached results, and normalized trend observations remain in the app's on-device storage.

When a person searches near their current location or a selected place, the search coordinate, radius, time range, and ArcGIS query are sent directly to the relevant DC government ArcGIS Feature Service to return nearby public records. DC Pulse does not send a device identifier, account identifier, saved “Home” label, or contact information with that query. The privacy policy must describe this transient third-party service request and link to the applicable DC privacy information.

For a photo-first 311 draft, image classification runs on-device with Apple's Vision framework. DC Pulse does not read embedded GPS metadata; it uses the phone's current DC location only when location access is available, with manual address entry as the fallback. The image and draft remain local until the person explicitly continues to the official DC 311 portal; DC Pulse does not submit or upload the photo itself. The reviewed text draft is written to the system pasteboard only when the person taps **Continue in DC 311**.

Based on the current implementation:

- Tracking: **No**
- Data linked to the user by DC Pulse: **None**
- Data used for advertising: **None**
- Developer analytics or diagnostics collection: **None**
- Precise location stored on-device: **Yes, only when the person saves Home/current location**
- Precise/search location transmitted to DC ArcGIS to service a nearby-data request: **Yes**
- Selected 311 draft photo uploaded by DC Pulse: **No**
- On-device photo classification: **Yes, only after explicit photo selection or capture**

App Store Connect answers must be re-audited immediately before submission against the published privacy policy and any new SDK, backend, diagnostics, or notification implementation.

## Privacy manifest

`PrivacyInfo.xcprivacy` declares:

- no tracking,
- no data collected by the app developer,
- `NSPrivacyAccessedAPICategoryUserDefaults` with approved reason `CA92.1` for app-only preferences and cache metadata.

Generate the archive privacy report in Xcode before TestFlight submission and reconcile it with App Store Connect.

## Public URLs

- Privacy policy: `https://dcpulseapp.com/#privacy`
- Support page: `https://dcpulseapp.com/#support`
- Marketing page: `https://dcpulseapp.com`

The privacy policy should explain location use, direct DC ArcGIS requests, on-device Home/follow/watch storage, retention controls, notification behavior, and how deleting the app removes local data.

## Physical-device quality gates

- Location: allow, deny, approximate location, out-of-DC location, and Settings recovery.
- Notifications: allow, deny, manual watched-item check, foreground banner, and notification tap routing.
- Appearance: Light/Dark Mode, large accessibility text, Reduce Motion, and VoiceOver.
- Networking: Wi-Fi, cellular, airplane mode, slow connection, and recovery after returning online.
- Persistence: cold launch, reinstall expectations, Home/follow/watch retention, and cache expiration.
- External handoffs: X native composer, DC 311, DOB violation form, and DDOT/DC 311 reporting.
- Camera/photo draft: camera permission, Photos picker, location permission/denial, current-location fallback, manual address, and official-portal handoff.
- Release: archive validation, privacy report review, TestFlight install, and crash-free smoke test.

The current minimum deployment target is iOS 26.5. Lowering it would broaden device support, but requires a separate compatibility pass because the app uses current MapKit and geocoding APIs. Do not change it as part of routine release preparation.
