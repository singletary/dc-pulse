# DC Pulse

DC Pulse is a native, map-forward iPhone app that answers: **“What’s changing around me today?”** It translates Washington, DC public ArcGIS/Open Data into an approachable view of recent 311 requests, building permits, and DDOT construction permits.

The app provides navigable Pulse, Map, Activity, Places, and Item Details experiences. Its first verified live vertical slice loads 2026 DC 311 requests around Downtown DC or the user's current location using a **half-mile** default radius and **last-30-days** period. Users can switch between quarter-mile, half-mile, and one-mile searches. Building and DDOT permit endpoints remain intentionally unconfigured until independently verified.

## Open the project

Open `DCPulse/DCPulse.xcodeproj` in Xcode. The existing `DCPulse` scheme contains the application, unit-test, and UI-test targets. The project currently targets iOS 26.5 as created; signing and bundle identifiers must not be changed without explicit approval.

## Command-line verification

```sh
xcrun simctl list devices available
xcodebuild -project DCPulse/DCPulse.xcodeproj -scheme DCPulse -destination 'platform=iOS Simulator,name=<available iPhone>' build
xcodebuild -project DCPulse/DCPulse.xcodeproj -scheme DCPulse -destination 'platform=iOS Simulator,name=<available iPhone>' test
```

See [the product plan](docs/product-plan.md), [architecture](docs/architecture.md), and [data sources](docs/data-sources.md).
