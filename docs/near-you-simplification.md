# Near You simplification decision

Status: direction selected; task validation and production implementation pending

Owner: product and iOS

Decision date: July 28, 2026

Roadmap priority: P1

## Goal

Make the first screen answer **What changed near this place?** before it asks people to configure, filter, or explore. Preserve the current data-integrity rules, accessibility states, and routes into Map, Requests, Places, Notifications, 311 reporting, and Restaurant Health.

This is a low-fidelity information-architecture decision. It does not authorize production UI changes by itself.

## Audit method

Each current element is scored from 1 (low) to 5 (high). Higher vertical and accessibility cost is worse. “Primary” means the element directly answers the first-screen question; “supporting” means it remains useful but should not compete above the fold; “destination” means it belongs behind a focused route or in another tab.

| Current element | User value | Frequency | Urgency | Personalization | Reliability | Duplication | Vertical cost | Accessibility cost | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Location, radius, and period context | 5 | 5 | 5 | 4 | 5 | 2 | 3 | 2 | Primary, compressed into one context control |
| Save-Home and location recovery guidance | 4 | 2 | 3 | 5 | 4 | 3 | 4 | 4 | Contextual prompt; never lead the first-run screen |
| New, Active, and Resolved totals | 5 | 5 | 5 | 2 | 5 when complete | 2 | 2 | 2 | Primary snapshot |
| Selected-status controls and list route | 4 | 3 | 3 | 2 | 5 | 3 | 3 | 3 | Keep as direct snapshot interaction |
| Category totals and expansion | 4 | 3 | 2 | 2 | 5 when complete | 4 | 5 | 4 | Move behind Neighborhood Summary |
| Trends and provenance | 4 | 2 | 3 | 2 | 5 when complete | 4 | 5 | 5 | Show at most one insight; move full set behind summary |
| My requests/Home state | 4 after setup | 3 after setup | 4 when changed | 5 | 4 | 3 | 4 | 4 | Supporting personalized card below the primary snapshot |
| Noteworthy records | 5 | 5 | 5 | 3 | 4 | 2 | 5 at ten rows | 4 | Primary, capped at three records |
| Source and partial warnings | 5 | event-driven | 5 | 1 | 5 | 2 | 2 | 3 | Primary when present, immediately before affected content |
| Ward/address exploration | 4 | 2 | 2 | 3 | 5 | 5 | 3 | 3 | Consolidate into location control and Places |
| 311 reporting | 5 | 2 | 5 when needed | 2 | 5 | 2 | 2 | 2 | Keep discoverable as a civic action, outside the snapshot |
| Restaurant Health entry | 3 | 1 | 3 | 2 | 5 for current honest handoff | 3 | 2 | 2 | Secondary civic destination |
| Notifications toolbar action | 5 with watches | 3 | 5 when unread | 5 | 5 | 2 | 1 | 2 | Keep in toolbar |
| Manual refresh toolbar action | 4 | 2 | 3 | 1 | 5 | 3 with pull-to-refresh | 1 | 2 | Remove duplicate button; retain pull-to-refresh and recovery retry |

## Concepts

Every wireframe uses the same nominal phone width and content order. Bracketed rows are controls or navigation routes. The wireframes deliberately avoid final color, typography, and component decisions.

### Option A — Snapshot first

```text
┌──────────────────────────────┐
│ Near You               🔔    │
│ [ Downtown DC · 0.5 mi  › ]  │
│   Last 30 days               │
│                              │
│  NEW       ACTIVE   RESOLVED │
│   12         34        18    │
│                              │
│ ↗ Potholes increased nearby  │
│ [ Neighborhood summary   › ] │
│                              │
│ Noteworthy                   │
│ • 311 request row            │
│ • Building permit row        │
│ • DDOT permit row            │
│ [ See all nearby activity › ]│
│                              │
│ At Home / Save Home prompt   │
│ Civic actions               ›│
└──────────────────────────────┘
```

Primary task path: understand the place and status totals, scan one insight and three records, then choose deeper summary or activity.

### Option B — Personalized first

```text
┌──────────────────────────────┐
│ Near You               🔔    │
│ [ Home · 0.5 mi          › ] │
│                              │
│ At Home                     │
│ 2 watched changes            │
│ • Watched request row        │
│ • New permit nearby          │
│                              │
│  NEW       ACTIVE   RESOLVED │
│   12         34        18    │
│                              │
│ Nearby snapshot              │
│ ↗ Potholes increased         │
│ • Noteworthy record          │
│ [ Neighborhood summary   › ] │
│                              │
│ Civic actions               ›│
└──────────────────────────────┘
```

Primary task path: review personally relevant changes, then scan the broader neighborhood.

### Option C — Map preview first

```text
┌──────────────────────────────┐
│ Near You               🔔    │
│ [ Downtown DC · 0.5 mi  › ]  │
│ ┌──────────────────────────┐ │
│ │       map preview        │ │
│ │    ●  ◉  ●      ●       │ │
│ │ [ Explore full Map  › ]  │ │
│ └──────────────────────────┘ │
│                              │
│  NEW       ACTIVE   RESOLVED │
│   12         34        18    │
│                              │
│ One noteworthy change        │
│ • 311 request row            │
│ [ Neighborhood summary   › ] │
│                              │
│ At Home / Save Home prompt   │
└──────────────────────────────┘
```

Primary task path: orient geographically, open Map if needed, then scan status.

## Required state comparison

The same information priority is preserved in every state; state changes do not reorder the screen.

| State | Option A — Snapshot first | Option B — Personalized first | Option C — Map preview first |
| --- | --- | --- | --- |
| Loaded | Context → totals → one insight → three records | Context → Home changes → totals → short snapshot | Context → map preview → totals → one record |
| Loading | Context stays interactive; totals use labeled placeholders; three record skeletons | Home card and neighborhood totals both need independent loading states | Preview, annotations, totals, and records create three concurrent loading regions |
| Partial warning | Warning follows context and precedes totals; healthy totals/records remain | Warning must distinguish Home/watch freshness from nearby-source freshness | Warning must distinguish preview coverage from summary coverage |
| No Home | One compact prompt appears after nearby value is established | Primary region becomes setup-heavy or requires a different first-run hierarchy | Prompt appears below preview and snapshot |
| Largest accessibility text | Totals stack vertically; insight and rows retain one reading order | Personalized and neighborhood regions create a longer route to general status | Preview consumes height without adding VoiceOver value; map route must replace visual detail |

## Comparison

Scores use 1 (weak) to 5 (strong). Implementation cost is reversed: 5 means lowest cost.

| Criterion | Snapshot first | Personalized first | Map preview first |
| --- | ---: | ---: | ---: |
| First-run usefulness | 5 | 2 | 4 |
| Returning-user usefulness | 4 | 5 | 4 |
| Time to identify nearby change | 5 | 3 | 3 |
| Few competing actions above fold | 5 | 3 | 3 |
| Low duplication with other tabs | 5 | 4 | 2 |
| Stable hierarchy across Home states | 5 | 2 | 4 |
| Dynamic Type and VoiceOver clarity | 5 | 3 | 2 |
| Partial-data clarity | 5 | 3 | 2 |
| Low implementation/performance cost | 5 | 4 | 1 |
| **Total** | **44** | **29** | **25** |

## Decision

Select **Option A — Snapshot first** for task validation and production planning.

It is the only concept that keeps one stable first-run and returning-user hierarchy, answers the product’s primary question without setup, and reduces duplication without adding Map rendering work. Option B gives Home users stronger personalization but makes the first screen conditional and setup-led. Option C provides attractive orientation but duplicates the Map tab and adds the most loading, performance, and accessibility complexity during an active Map-performance workstream.

### Selected production hierarchy

1. Compact place context control containing place, radius, and period.
2. Complete New, Active, and Resolved snapshot with direct status exploration.
3. One strongest reliable neighborhood insight. Prefer a trend; fall back to the leading category; omit the region when complete insight data is unavailable.
4. Up to three noteworthy records, with source warnings immediately before affected content.
5. **Neighborhood summary** destination for complete categories, trends, provenance, and status-scoped exploration.
6. Contextual Home card: changes when configured, a compact prompt when not.
7. Civic actions destination for 311 reporting and Restaurant Health.
8. Notifications remain in the toolbar. Pull-to-refresh remains; the duplicate toolbar refresh button is removed only after retry/recovery affordances are verified.

Ward and address exploration move into the place context control and Places rather than remaining a competing bottom section.

## State acceptance criteria

- Loading preserves the selected place context and uses descriptive labels rather than unverifiable percentage progress.
- Complete totals are never replaced by partial loaded-page counts.
- Partial warnings identify what may be incomplete and leave healthy content usable.
- No-Home state shows nearby value before asking for setup.
- At accessibility sizes, the three status metrics stack rather than compress or truncate.
- VoiceOver order matches the selected hierarchy and does not enter decorative emoji or a duplicate map preview.
- The first noteworthy record is reachable without traversing expanded category or trend lists.
- Every moved action retains a named, testable destination before the production hierarchy ships.

## Validation plan

Before implementation is treated as complete, run five moderated or dogfood task passes in loaded, loading, partial, no-Home, and accessibility-size states:

1. Identify the current place and time window.
2. Say which lifecycle status has the most requests.
3. Identify one meaningful nearby change.
4. Open the complete neighborhood summary.
5. Find Home changes or begin Home setup.
6. Start a 311 report and find Restaurant Health.
7. Change the search area.

Record task completion, hesitation, wrong destinations, VoiceOver reading-order issues, first-record scroll depth, and any action lost in consolidation. Do not use preference alone as the adoption signal.

## Implementation slices after validation

1. Extract a Neighborhood Summary destination using the existing complete category and trend data.
2. Recompose `PulseView` around the selected hierarchy without changing retrieval semantics.
3. Consolidate area exploration and civic actions only after destination coverage exists.
4. Add deterministic presentation tests for insight fallback, partial warnings, no-Home behavior, and status ordering.
5. Run smallest-screen, largest-Dynamic-Type, VoiceOver, and physical-device checks before closing the roadmap item.
