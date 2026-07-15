# TestFlight release checklist

DC Pulse 1.0 (2) is the current internal TestFlight build and is installed on a physical iPhone. This checklist records its regression pass and prepares the next replacement build after critical fixes. It does not authorize changes to signing, the development team, provisioning, entitlements, or the bundle identifier.

## Known build 2 issues to verify and close

- The keyboard in the new-311 request details flow cannot be dismissed reliably and may cover the continuation control.
- **Continue in DC 311** can open a black page instead of a usable official destination.
- Restaurant Health currently exposes generic official destinations rather than useful nearby inspection results; do not represent it as a live nearby-inspections integration.
- Notification rows use generic unread dots; source/category icons are planned after the release-blocking submission defects.

## Before upload

- Build and test the app on an available iPhone Simulator.
- Run a Release build and Xcode static analysis.
- Create and validate an iOS archive using the existing automatic-signing configuration.
- Inspect the archive for the DC Pulse icon, `PrivacyInfo.xcprivacy`, version `1.0` (`2`), iPhone device family, location usage description, and the non-exempt-encryption declaration.
- Smoke test on a physical iPhone before inviting external testers.
- Confirm the privacy, support, and marketing URLs in App Store Connect.
- Reconcile App Store privacy answers with `docs/app-store-readiness.md` and the published privacy policy.

## Suggested TestFlight information

**Beta description**

DC Pulse makes it easier to see recent DC 311 requests and public permit activity near you, around an address, or in a selected ward. Explore the map, filter nearby records, follow places, save a home location, watch individual items, and review local request trends.

**What to test**

- Allow location access and confirm nearby results match the simulated or physical location.
- Open Map and check that it becomes interactive promptly while additional markers load progressively.
- Change radius, time range, data source, status, and request-type filters.
- Pan within DC and use Search This Area; use the location button to return to the current location.
- Open single and grouped map markers and confirm detail navigation and dismissal.
- Browse and sort Requests, including requests around followed places.
- Save Home, follow a place, watch an item, and exercise notification permission and manual refresh flows.
- Try denied, approximate, and out-of-DC location paths, plus offline and slow-network recovery.
- Verify the X status-update composer and DC reporting handoffs, but do not submit a real report solely for testing.
- Open **Report an Issue to 311**, choose a non-sensitive test image, confirm the suggested type remains editable, dismiss the keyboard, and verify the continuation control stays reachable. Confirm that Continue opens a useful official destination or documented fallback without claiming submission.
- Verify camera denial, a photo without location metadata, current-location fallback, and manual address entry. Do not use a personal photo in App Store screenshots or shared test evidence.
- Open **Restaurant Health Inspections** only to document the current generic-link limitation, Dynamic Type, and VoiceOver labels. Nearby restaurant map/report verification begins after a dependable source interface is approved.

**Feedback email**

`support@dcpulseapp.com`

## Physical-iPhone pass

Test once on Wi-Fi and once on cellular. Include a cold launch, background/foreground cycle, Light and Dark Mode, a large Dynamic Type size, and VoiceOver labels for the primary controls. Confirm saved Home, followed places, watched items, and cached results survive a relaunch. Delete and reinstall the beta once to verify first-run permission and empty-state behavior.

Notifications currently use on-device refresh checks rather than a push-notification server, so status alerts are evaluated when the app refreshes data. Test that behavior as implemented; do not describe it as immediate remote push.

## Apple-account steps

1. In Xcode Organizer, select the validated archive and choose **Distribute App > App Store Connect > Upload**.
2. Keep the existing bundle identifier and signing configuration. Stop if Xcode requests a different team, certificate, profile, entitlement, or identifier.
3. In App Store Connect, wait for processing, complete export-compliance and beta information, then add the build to an internal testing group.
4. Install through TestFlight on the physical iPhone and complete the pass above.
5. Increment the build number before uploading any replacement build; the next 1.0 upload must be greater than build `2`.

External testing can follow only after the internal pass is stable and Apple has approved any required beta review.
