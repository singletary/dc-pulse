# TestFlight release checklist

Use this checklist for internal verification, external distribution, and replacement builds. Current build availability and the immediate gate live in [release status](release-status.md). This checklist does not authorize changes to signing, the development team, provisioning, entitlements, or the bundle identifier.

## Known issues

- Restaurant Health is a data-gated preview and does not yet provide live nearby inspection reports or a report map.
- **Report to 311** prepares and copies an editable draft, then hands off to the official DC311 app or website; DC Pulse does not directly submit the request. The official website can be unreliable on some devices, so the app route is preferred.
- Watch alerts are evaluated when DC Pulse refreshes matching data. Immediate remote push and guaranteed background delivery are not part of this build.
- Map coverage is deliberately bounded for performance. The app guarantees that its close-in quarter-mile pass is merged into wider-radius results, but very dense long-range searches may not display every older record.
- Public DC datasets can be delayed, incomplete, temporarily unavailable, or use inconsistent status wording. Healthy sources remain visible when another source fails.
- Notification rows use category-aware symbols and direct detail navigation. Completed watches now move into a visible, restorable archive after the configured grace period.
- **Check This Request in DC 311** copies the public request ID and opens the official service for manual paste/search; it does not claim an unverified record-specific deep link.

## Before external distribution

- Install the processed build from TestFlight on a physical iPhone and complete the pass below.
- Confirm the privacy, support, and marketing URLs in App Store Connect.
- Reconcile App Store privacy answers with [App Store readiness](app-store-readiness.md) and the published privacy policy.
- Complete any required Beta App Review information and assign the verified build to the intended external group.
- Verify the public TestFlight link and tester-facing **What to Test** text, then monitor early feedback before broader promotion.

## Before any replacement upload

- Build and test the app on an available iPhone Simulator.
- Run a Release build and Xcode static analysis.
- Create and validate an iOS archive using the existing automatic-signing configuration.
- Inspect the archive for the DC Pulse icon, `PrivacyInfo.xcprivacy`, the intended version/build, iPhone device family, location usage description, and the non-exempt-encryption declaration.
- Smoke test on a physical iPhone.
- Increment the build number beyond every build already uploaded to App Store Connect.

## Suggested TestFlight information

**Beta description**

DC Pulse makes it easier to see recent DC 311 requests and public permit activity near you, around an address, or in a selected ward. Explore the map, filter nearby records, follow places, save a home location, watch individual items, and review local request trends.

**What to test**

- Check Near You’s snapshot, status totals, noteworthy items, and Neighborhood Summary. Confirm only live features are shown.
- Keep Map open while changing location, address, or ward. Confirm close-in and full-radius markers refresh for the new area without stale results.
- Try 0.25, 0.5, and 1 mile plus each time range. Change filters quickly, use Reset, and test partial-coverage details and Retry.
- Relaunch the same area. Cached markers should appear quickly, show when they were updated, and remain usable if one public source fails.
- Save Home, follow a place, watch and archive an item, then relaunch. Confirm saved choices and detail navigation persist.
- Check denied or approximate location, offline recovery, largest text, VoiceOver, and Light/Dark Mode. Report clipping, confusing announcements, stale data, or crashes.

**Feedback contact**

Use the monitored feedback email configured privately in App Store Connect;
do not commit a private review or account address to the repository. Public
support is available at `https://dcpulseapp.com/#support`.

## Physical-iPhone pass

Test once on Wi-Fi and once on cellular. Include a cold launch, background/foreground cycle, Light and Dark Mode, a large Dynamic Type size, and VoiceOver labels for the primary controls. Confirm saved Home, followed places, watched items, and cached results survive a relaunch. Delete and reinstall the beta once to verify first-run permission and empty-state behavior.

Notifications currently use on-device refresh checks rather than a push-notification server, so status alerts are evaluated when the app refreshes data. Test that behavior as implemented; do not describe it as immediate remote push.

## Replacement upload steps

1. In Xcode Organizer, select the validated archive and choose **Distribute App > App Store Connect > Upload**.
2. Keep the existing bundle identifier and signing configuration. Stop if Xcode requests a different team, certificate, profile, entitlement, or identifier.
3. In App Store Connect, wait for processing, complete export-compliance and beta information, then add the build to an internal testing group.
4. Install through TestFlight on a physical iPhone and complete the **What to Test** and physical-device passes.
5. Return to **Before external distribution** above after internal verification.

External testing can begin after any required Beta App Review approval and assignment to the intended external group.
