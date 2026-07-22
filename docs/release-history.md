# Release history

This document preserves completed delivery milestones that would otherwise obscure active work in the [ranked roadmap](roadmap.md). It is a product and engineering history, not App Store release notes.

## Foundation and early beta

- Established the feature-oriented MVVM structure, normalized `PulseItem` boundary, reusable ArcGIS networking, source adapters, fixtures, and tests.
- Added live nearby DC 311, Building Permit, and DDOT Construction Permit data with partial-source failure handling.
- Added Map, Requests, Places, Item Details, followed places, Home, watched items, and the notification inbox.
- Cleaned the Swift 6 actor-isolation warning baseline and completed live one-record schema smoke audits for all three ArcGIS layers.
- Added the privacy manifest, copy-ready App Store metadata and review notes, and reproducible 6.9- and 6.5-inch screenshot sets.

## Builds 3 and 4

- Build 3 made the 311 draft keyboard dismissible, kept its continuation action reachable, and added an official DC311 app handoff with an explicit website fallback.
- Build 4 added denser progressive Map loading, explicit close-in quarter-mile coverage, consistent expandable filters, and atomic filter reset.
- Build 4 moved Requests nearby to complete grouped status/category totals instead of partial loaded-page counts.
- Build 4 added Requests pull-to-refresh, distinct privacy-preserving Photos and Camera inputs, and silent age-derived New-to-Active watch presentation changes.

## Build 5 and subsequent stabilization

- Cold launch briefly waits for requested location instead of starting a redundant fallback query.
- Map coverage arrives progressively without a blocking overlay; slow individual sources time out without withholding healthy results.
- Close-in and selected-radius Map retrieval use concurrent independent page budgets, reject stale passes, and preserve radius inclusion more reliably.
- Denied, unavailable, nearby out-of-area, and distant location states retain useful, accurately labeled DC results with recovery actions.
- Complete 311 summaries retry transient failures and never substitute misleading first-page totals when grouped queries are unavailable.
- About DC Pulse provides installed version/build, public links, offline MIT terms, attribution, and the independent-app disclaimer.
- Notification rows use category symbols; lock-screen alerts omit street addresses while the private inbox retains useful context.
- Item Details supports explicit field copying, privacy-bounded bulk copying, permit-report context, and an honest DC 311 request-ID lookup handoff.
- System-alert preferences independently control watched status changes and newly discovered auto-watched items near Home.
- Trend snapshots retain source, geography, radius, period, comparison windows, refresh date, and explainable cached context.
- Watched records distinguish explicit and automatic origin, use configurable resolved-item grace periods, and move expired watches into a restorable archive.
- Deterministic UI coverage verifies archive restoration across relaunch and followed-place navigation into the correct Map context.

## Build 7 internal TestFlight scope

- Primary record availability is isolated from auxiliary pagination and Map coverage warnings.
- Recovered datasets clear stale warnings, while incomplete dense coverage remains a Map-local condition.
- Requests nearby supports visible New, Active, and Resolved scopes backed by complete grouped category totals.
- The initial category summary remains concise and expands deterministically when more complete totals are available.
- Lifecycle transition snapshots are separated from the current observation index and use a documented one-year retention and migration policy.
- Trend context and status/category responses remain generation-safe during rapid radius, location, period, and status changes.

Current distribution is maintained in [release status](release-status.md).
