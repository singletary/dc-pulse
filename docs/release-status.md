# Release status

Last updated: July 22, 2026

This is the canonical source for DC Pulse distribution state and immediate release gates. Other documents should link here instead of copying build availability that can drift.

## Distribution

- Marketing version: **1.0**
- External TestFlight: **build 6**
- Internal TestFlight: **build 7**
- Build 7 external availability: **not yet assigned to external testers**
- Public App Store: **not submitted for review**

## Immediate gate

1. Complete build 7's internal TestFlight verification.
2. Assign build 7 to the intended external testing group after any required Beta App Review approval.
3. Run the focused external soak covering correctness, performance, migration, navigation, accessibility, location behavior, Map density, watched items, alerts, photo input, and official handoffs.
4. Triage external findings before selecting a build for public App Review.

Any replacement for build 7 must use a higher build number. Signing, capabilities, entitlements, bundle identifiers, certificates, provisioning, and Apple-account configuration remain manually controlled and must not be changed without explicit approval.

## Capability gate

Background App Refresh remains planned. `BGTaskScheduler` registration and Background Modes/background fetch require explicit approval before implementation.

For active engineering priorities, see the [ranked roadmap](roadmap.md). For completed delivery history, see [release history](release-history.md). For distribution steps, see the [TestFlight checklist](testflight-release.md).
