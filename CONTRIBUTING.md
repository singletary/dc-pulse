# Contributing to DC Pulse

Thank you for helping make DC public information easier to understand. DC Pulse is currently a pre-release project in internal and external TestFlight testing, so changes should stay focused, reviewable, and safe for a future App Store submission.

## Before starting

1. Read `AGENTS.md` for repository-wide architecture and verification requirements.
2. Read and follow `CODE_OF_CONDUCT.md` in every project space.
3. Review the relevant product and architecture documentation in `docs/`.
4. Open an issue before work that materially changes product behavior, adds a dataset, introduces a dependency, or affects privacy.
5. Never include a real home address, precise private location, API credential, signing asset, or Apple account information in code, fixtures, screenshots, logs, issues, or pull requests.

## Architecture expectations

- Keep SwiftUI views and view models under `Features/<Feature>`.
- Put shared domain concepts in `Core/Models`, transport code in `Core/Networking`, and location behavior in `Core/Location`.
- Give every external dataset its own response mapping boundary. Source-specific ArcGIS types must not reach views.
- Inject networking, clocks, location, and other side effects behind protocols where tests benefit.
- Prefer Apple frameworks and straightforward Swift over additional dependencies or speculative abstractions.
- Preserve Dynamic Type, VoiceOver, Dark Mode, useful loading states, empty states, and actionable errors.

## Data and fixture rules

- Verify authoritative fields and endpoints before describing an integration as live.
- Add redacted, representative fixtures for transport and adapter behavior.
- Do not copy a payload containing a resident’s narrative, name, precise private location, or other unnecessary personal detail into the repository.
- Treat missing coordinates, inconsistent dates, transfer limits, ArcGIS error envelopes, and partial source failure as normal boundary cases.

## Pull-request workflow

Create a focused branch, make the smallest coherent change, and explain the user-visible outcome in the pull request. Include tests for mapping, networking, persistence, or policy changes where applicable.

Before requesting review:

```sh
xcrun simctl list devices available
xcodebuild -project DCPulse/DCPulse.xcodeproj -scheme DCPulse -destination 'platform=iOS Simulator,name=<available iPhone>' build
xcodebuild -project DCPulse/DCPulse.xcodeproj -scheme DCPulse -destination 'platform=iOS Simulator,name=<available iPhone>' test
```

Also inspect `git diff` for accidental files, private data, and unrelated changes. UI changes should include a privacy-safe screenshot or recording when useful.

## Release-sensitive settings

Do not change the development team, certificates, provisioning, signing style, capabilities, entitlements, bundle identifiers, versioning, or Apple account configuration without explicit approval from the project owner.

## Reporting a problem

Use a GitHub issue for reproducible product defects that contain no sensitive information. Follow `SECURITY.md` for vulnerabilities, privacy issues, or reports that require private details.
