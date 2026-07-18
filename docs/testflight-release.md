# TestFlight release checklist

DC Pulse 1.0 (5) has completed its initial internal physical-iPhone pass and is submitted for external TestFlight beta review. Use this checklist for review follow-up, external distribution, and every replacement build. It does not authorize changes to signing, the development team, provisioning, entitlements, or the bundle identifier.

## Known issues

- Restaurant Health is a data-gated preview and does not yet provide live nearby inspection reports or a report map.
- **Report to 311** prepares and copies an editable draft, then hands off to the official DC311 app or website; DC Pulse does not directly submit the request. The official website can be unreliable on some devices, so the app route is preferred.
- Watch alerts are evaluated when DC Pulse refreshes matching data. Immediate remote push and guaranteed background delivery are not part of this build.
- Map coverage is deliberately bounded for performance. The app guarantees that its close-in quarter-mile pass is merged into wider-radius results, but very dense long-range searches may not display every older record.
- Public DC datasets can be delayed, incomplete, temporarily unavailable, or use inconsistent status wording. Healthy sources remain visible when another source fails.
- Notification rows now use category-aware symbols and direct detail navigation. Automatic archival of completed watches remains planned.
- **Check This Request in DC 311** copies the public request ID and opens the official service for manual paste/search; it does not claim an unverified record-specific deep link.

## Before upload

- Build and test the app on an available iPhone Simulator.
- Run a Release build and Xcode static analysis.
- Create and validate an iOS archive using the existing automatic-signing configuration.
- Inspect the archive for the DC Pulse icon, `PrivacyInfo.xcprivacy`, version `1.0` (`5`), iPhone device family, location usage description, and the non-exempt-encryption declaration.
- Smoke test on a physical iPhone before inviting external testers.
- Confirm the privacy, support, and marketing URLs in App Store Connect.
- Reconcile App Store privacy answers with `docs/app-store-readiness.md` and the published privacy policy.

## Suggested TestFlight information

**Beta description**

DC Pulse makes it easier to see recent DC 311 requests and public permit activity near you, around an address, or in a selected ward. Explore the map, filter nearby records, follow places, save a home location, watch individual items, and review local request trends.

**What to test**

- Allow location access and confirm nearby results match the simulated or physical location.
- Cold-launch the app and confirm the Near You summary appears promptly without first loading an unrelated default location.
- Open Map and check that it becomes interactive promptly while additional markers load progressively.
- Change radius, time range, data source, status, and request-type filters.
- At one unchanged center, verify that records visible at 0.25 mile remain available at 0.5 and 1 mile. Change several filters quickly, then use **Reset** and confirm all sources/statuses/categories, 0.5 mile, and 30 days return without moving the center.
- Pan within DC and use Search This Area; use the location button to return to the current location.
- Open single and grouped map markers and confirm detail navigation and dismissal.
- Browse and sort Requests, including requests around followed places, then pull to refresh and confirm the active location and sort/filter choices remain intact.
- Save Home, follow a place, watch an item, and exercise notification permission and manual refresh flows.
- In Places > Alerts, independently toggle **Watched status changes** and **New items near Home**. Confirm the nearby choice is unavailable until auto-watch is enabled and that each preference survives a relaunch.
- In Places, swipe an active watch to **Archive**, restore it from the **Archived** section, and confirm its Item Details watch action changes to **Restore Watch** while archived. Archived records should remain readable but should not be included in **Check Watched Items Now**.
- Try denied, approximate, and out-of-DC location paths, plus offline and slow-network recovery.
- Verify the X status-update composer and DC reporting handoffs, but do not submit a real report solely for testing.
- Open **Report an Issue to 311** and verify **Choose Photo** opens Photos while **Take Photo** opens the camera. Use a non-sensitive test image, confirm the suggested type remains editable, dismiss the keyboard, and verify the continuation control stays reachable. Confirm the handoff offers the official app and website fallback without claiming submission.
- Verify camera denial, a photo without location metadata, current-location fallback, and manual address entry. Do not use a personal photo in App Store screenshots or shared test evidence.
- Watch a newly opened request and confirm its automatic New-to-Active aging does not create a notification; confirm a meaningful Active-to-Resolved change still does.
- Open the notification inbox and confirm each row has an appropriate category/source symbol, unread state remains distinguishable, and tapping opens the referenced details.
- From Item Details, copy individual fields and **Copy All Details**; for a permit, verify **Copy Report Details** prepares useful, displayed context without hidden coordinates.
- From a 311 item, verify the request-ID confirmation copies the exact identifier and opens the official search destination without implying a direct record link.
- Open **About DC Pulse** from Places and verify version/build, website, support, privacy, GitHub, license, attribution, and independent-app disclosure both online and offline where applicable.
- With system alerts enabled, confirm lock-screen notification text does not contain a street address while the in-app inbox retains the useful record detail.
- With auto-watch enabled, confirm a newly discovered nearby item can create a privacy-safe system alert and that tapping it opens the saved record.
- Open **Restaurant Health Inspections** only to verify that its data-gated explanation is clear. Nearby restaurant report verification begins after a dependable source interface is approved.

**Feedback contact**

Use the monitored feedback email configured privately in App Store Connect;
do not commit a private review or account address to the repository. Public
support is available at `https://dcpulseapp.com/#support`.

## Physical-iPhone pass

Test once on Wi-Fi and once on cellular. Include a cold launch, background/foreground cycle, Light and Dark Mode, a large Dynamic Type size, and VoiceOver labels for the primary controls. Confirm saved Home, followed places, watched items, and cached results survive a relaunch. Delete and reinstall the beta once to verify first-run permission and empty-state behavior.

Notifications currently use on-device refresh checks rather than a push-notification server, so status alerts are evaluated when the app refreshes data. Test that behavior as implemented; do not describe it as immediate remote push.

## Apple-account steps

1. In Xcode Organizer, select the validated archive and choose **Distribute App > App Store Connect > Upload**.
2. Keep the existing bundle identifier and signing configuration. Stop if Xcode requests a different team, certificate, profile, entitlement, or identifier.
3. In App Store Connect, wait for processing, complete export-compliance and beta information, then add the build to an internal testing group.
4. Install through TestFlight on the physical iPhone and complete the pass above.
5. After Beta App Review approval, add build 5 to the intended external group, verify the public TestFlight link and tester-facing **What to Test** text, and monitor early feedback before broader promotion.
6. Increment the build number before uploading any replacement build; the next 1.0 upload must be greater than build `5`.

External testing can begin after Apple approves the submitted beta review and the build is assigned to the intended external group.
