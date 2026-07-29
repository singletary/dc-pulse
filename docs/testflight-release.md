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

Build 9 includes Build 8’s simpler Near You experience and Map reliability work, then refines the snapshot with saved-Home recognition, four dynamic insights, quieter detail copying, and more relevant Home alerts. These changes do not expand data collection.

- Check Near You’s totals, noteworthy items, and four insight rows. Select New, Active, and Resolved; confirm the rows update, and tap the selected status again to show all.
- Save the current location as Home. Confirm the Home icon appears, unfinished features stay hidden, and insight emoji and ↑/↓ trends match their request types.
- Change Map location, address, ward, radius, time range, and filters quickly. Confirm close-in and full-radius markers refresh without stale-area results.
- Test Map Reset, partial-coverage details, Retry, and relaunch. Cached markers should appear quickly and remain useful if one public source fails.
- Open Item Details. Confirm fields have no distracting copy icons but still copy by touch-and-hold, text selection, VoiceOver actions, and Copy All.
- Test Home auto-watch at 0.1 and 0.25 mile. “New near Home” inbox and system alerts should only appear for items within 0.1 mile after a refresh.
- Check followed places, watches, archive/restore, denied or approximate location, offline recovery, largest text, VoiceOver, and Light/Dark Mode.

**Feedback contact**

Use the monitored feedback email configured privately in App Store Connect;
do not commit a private review or account address to the repository. Public
support is available at `https://dcpulseapp.com/#support`.

## Physical-iPhone pass

Test once on Wi-Fi and once on cellular. Include a cold launch, background/foreground cycle, Light and Dark Mode, a large Dynamic Type size, and VoiceOver labels for the primary controls. Confirm saved Home, followed places, watched items, and cached results survive a relaunch. Delete and reinstall the beta once to verify first-run permission and empty-state behavior.

Notifications currently use on-device refresh checks rather than a push-notification server, so status alerts are evaluated when the app refreshes data. Test that behavior as implemented; do not describe it as immediate remote push.

## Replacement upload steps

1. Before archiving, open **Xcode > Settings > Accounts** and confirm the existing account has App Store Connect access. Re-authentication is a manual account-owner action.
2. Run the read-only signing-session preflight below. Stop before archiving if it does not pass.
3. Archive to Xcode’s standard Organizer location; do not use a temporary `-archivePath`.
4. Prefer `xcodebuild -exportArchive` with export method `app-store-connect` and destination `upload`. Organizer fallback must use **Distribute App > App Store Connect**. Never use **TestFlight Internal Only**; the full App Store Connect route supports testing and release.
5. Use existing signing assets only. Never pass `-allowProvisioningUpdates`; stop if Xcode requests account, team, certificate, profile, entitlement, identifier, or provisioning changes.
6. In App Store Connect, wait for processing, complete export-compliance and beta information, then assign the build to the intended TestFlight groups.
7. Install through TestFlight on a physical iPhone and complete the **What to Test** and physical-device passes.
8. Return to **Before external distribution** above after internal verification.

## Signing-session reliability

Run the fail-fast check in the logged-in Mac user session immediately before the archive:

```sh
scripts/testflight-signing-preflight.sh
```

The script requires accessible login-keychain settings and at least one valid
code-signing identity. Its checks are read-only. It does not unlock, repair, or
change Keychain.

If either check fails, or if signing reports `errSecInternalComponent`,
`errSecAuthFailed`, or `CSSMERR_CSP_OPERATION_AUTH_DENIED`:

1. Stop immediately. Do not retry through both CLI and Organizer.
2. Do not run `security unlock-keychain`, `set-key-partition-list`, change private-key Access Control, replace certificates, or regenerate profiles automatically.
3. Save the focused `securityd` and `codesign` log window for diagnosis.
4. Let the account owner restore the macOS login/security session, normally by logging out or restarting, before making one new preflight and archive attempt.
5. If the condition recurs after a clean login, collect a sysdiagnose and file Apple Feedback rather than changing signing assets speculatively.

The July 28, 2026 failure was not a missing certificate or an archive-setting
problem. macOS reported the keychain as unlocked, then denied the signing key's
integrity/authentication operation. The identical certificate, profile, and CLI
archive succeeded after restart without a keychain or project change. Treat this
signature as a transient macOS security-session failure. Nearby Xcode credential
and iCloud-keychain errors were present in the log, but their causal relationship
is unproven.

External testing can begin after any required Beta App Review approval and assignment to the intended external group.
