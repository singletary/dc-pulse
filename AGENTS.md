# DC Pulse Repository Guidance

## Architecture
- Use feature-oriented MVVM: SwiftUI views and view models live under `Features/<Feature>`.
- Put shared domain types in `Core/Models`, transport code in `Core/Networking`, and location services in `Core/Location`.
- Keep ArcGIS/source response types out of views. Each dataset must own an adapter that maps its schema to `PulseItem`.
- Inject networking, clocks, and location dependencies behind protocols. Prefer Swift, SwiftUI, MapKit, Core Location, and URLSession over third-party packages.
- Preserve accessible loading, empty, and error states, Dynamic Type, Dark Mode, and native navigation patterns.

## Layout
- `DCPulse/DCPulse/App`: app entry point and root navigation
- `DCPulse/DCPulse/Core`: shared networking, models, and location infrastructure
- `DCPulse/DCPulse/Features`: Pulse, Map, Activity, Places, and Item Details
- `DCPulse/DCPulse/DesignSystem`: reusable visual components and tokens
- `DCPulse/DCPulse/Resources/Fixtures`: non-production sample payloads
- `DCPulse/DCPulseTests`: unit tests mirroring production areas
- `docs`: product, architecture, and data-source decisions

## Build and test
Discover an installed destination with `xcrun simctl list devices available`, then run:

```sh
xcodebuild -project DCPulse/DCPulse.xcodeproj -scheme DCPulse -destination 'platform=iOS Simulator,name=<available iPhone>' build
xcodebuild -project DCPulse/DCPulse.xcodeproj -scheme DCPulse -destination 'platform=iOS Simulator,name=<available iPhone>' test
```

## Verification
- Build the app for an available iPhone Simulator and run all unit tests before handoff.
- Add fixture-backed tests for transport and adapter boundary behavior; never claim live integration from fixture-only verification.
- Check `git diff` and preserve unrelated/user-owned changes.
- Never change signing settings, development teams, certificates, provisioning, entitlements, bundle identifiers, or Apple account configuration without explicit approval.
