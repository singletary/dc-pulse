# App Store listing — version 1.0

This document is the canonical draft for the first public DC Pulse App Store listing. Character limits were checked against Apple's July 2026 App Store Connect reference. Copy should be pasted as plain text.

## Product page

**Name** — 8 of 30 characters

> DC Pulse

**Subtitle** — 29 of 30 characters

> DC requests, permits & places

**Promotional text** — 150 characters

> Explore nearby 311 requests and public permits, follow places that matter, watch status changes, and understand what’s changing across Washington, DC.

**Description**

> See what’s changing around you in Washington, DC.
>
> DC Pulse brings nearby 311 service requests, building permits, and DDOT construction permits into one approachable, map-forward iPhone app. Start with what’s happening near you, explore another address or ward, and open any record for clear source-specific details.
>
> EXPLORE NEARBY
>
> • See new, active, and recently resolved 311 requests
> • Discover building and public-space construction permits
> • Browse a chronological list or explore an interactive clustered map
> • Choose a quarter-mile, half-mile, or one-mile search radius
> • Compare the last 30 days with broader time ranges
>
> FOLLOW WHAT MATTERS
>
> • Save Home and follow other DC locations
> • Watch individual requests and permits
> • Review status changes in an on-device notification inbox
> • Automatically watch newly discovered items close to Home
> • See nearby 311 trends and noteworthy changes
>
> TAKE THE NEXT STEP
>
> • Start a 311 draft with a photo and an editable on-device category suggestion
> • Continue to the official DC 311 portal to review and submit
> • Open official reporting destinations for possible permit violations
>
> BUILT WITH PRIVACY IN MIND
>
> DC Pulse has no account system, advertising, or developer analytics. Saved places, watches, preferences, cached results, and the notification inbox remain on your device. Photo suggestions are generated on-device. Location access is optional—you can browse by ward or search around a DC address instead.
>
> DC Pulse is an independent application and is not an official application of the Government of the District of Columbia. Public-record availability, accuracy, categorization, geocoding, and update timing depend on the source agencies. DC Pulse does not create, manage, resolve, approve, or verify government requests or permits.

**Keywords** — 88 of 100 bytes

> 311,civic,permits,construction,neighborhood,map,open data,service requests,DDOT,district

**Support URL**

> https://dcpulseapp.com/#support

The support section must provide a monitored private contact form before App Review.

**Marketing URL**

> https://dcpulseapp.com

**Privacy Policy URL**

> https://dcpulseapp.com/#privacy

**Copyright**

> 2026 Michael Singletary

App Store Connect adds the copyright symbol automatically.

## Classification and availability recommendations

- Primary category: **Reference**
- Secondary category: **Navigation**
- Primary language: **English (U.S.)**
- Initial availability: **United States**
- License agreement: Apple's standard EULA
- Release option: **Manually release this version** for the first public launch
- Content rights: **Yes, the app accesses third-party public records.** DC government/DC Open Data attribution is included, and the app links to authoritative sources.
- Age rating: expected to be the lowest general-audience rating, subject to completing Apple's current questionnaire truthfully. DC Pulse does not provide unrestricted web access, social networking, chat, purchases, gambling, or in-app user publishing.

## App Privacy recommendation

- Tracking: **No**
- Data linked to the user: **No**
- Advertising or third-party advertising: **No**
- Developer analytics: **No**
- Diagnostics collected by the developer: **No**
- Photos or videos collected by DC Pulse: **No**; 311 draft analysis is on-device and the app does not upload the selected photo.
- Contact information collected by the iOS app: **No**; support-form collection occurs on the separate website and is described in the web privacy policy.

Use the conservative disclosure below unless the DC ArcGIS publisher confirms that the coordinate is discarded immediately after servicing each request:

- **Precise Location** — collected, not linked to identity, not used for tracking, used only for **App Functionality**. The selected search coordinate is transmitted directly to DC government ArcGIS services to return nearby records. DC Pulse does not operate an intermediary server or attach an account/device identifier.

This product-page disclosure is separate from `PrivacyInfo.xcprivacy`, which correctly declares that the app developer does not collect data and that on-device preferences use the approved UserDefaults required-reason API.

## App Review information

**Sign-in required:** No.

**Review notes**

> DC Pulse is an independent viewer for public Washington, DC records. No account, subscription, purchase, or demo credentials are required.
>
> Location permission is optional. To exercise the main experience, allow location while using the app, or choose Browse by Ward / Search Around a DC Address from Near You or Places. The app accepts only coordinates inside the Washington, DC service area.
>
> Map and Requests combine three public sources: DC 311 City Service Requests, 2026 Building Permits, and 2026 DDOT Construction Permits. Public services may respond at different speeds; a source-specific warning is shown if one source is temporarily unavailable.
>
> Watch alerts are evaluated when the app refreshes public data, including launch, foreground refresh, and eligible background refresh. They are not represented as immediate server push notifications. The notification inbox is stored on-device.
>
> Report an Issue to 311 creates an editable draft and performs photo classification on-device. DC Pulse does not read photo GPS metadata, upload the photo, or claim submission. Continue in DC 311 copies the reviewed text and opens the official portal, where the user completes any official transaction.
>
> Restaurant Health is data-gated. The current generic DC Health destinations are not represented as nearby inspection integration. Before advertising this feature, DC Pulse must either provide a useful location-centered map backed by an approved source or remove the placeholder destinations from the release candidate.
>
> DC Pulse is not affiliated with or endorsed by the Government of the District of Columbia. Source attribution and limitations are visible in the app and at https://dcpulseapp.com/#data.

App Review contact first/last name, telephone number, and account email must be entered privately by the account holder. Use a monitored private address and reachable phone number for Apple's review contact fields; do not commit them to the repository.

## Screenshot sequence

All launch screenshots use real application UI staged around a well-known public landmark in **Downtown DC**. Any visible addresses are public records in that demonstration area. They contain no coordinate, saved Home, email, or location associated with the developer or tester. Matching sets are generated for App Store Connect's 6.9-inch (1320 × 2868) and 6.5-inch (1284 × 2778) portrait slots.

1. **Your neighborhood, at a glance.** — Near You overview, status totals, categories, and trends
2. **See what’s changing around you.** — clustered map, search radius, and mixed public sources
3. **Requests and permits, together.** — chronological Requests view
4. **Follow the places that matter.** — Home, wards, address search, and followed places

The colorful light-mode compositions present each unmodified capture within Apple’s native
iPhone 17 Pro continuous display geometry, generated from an iOS Simulator alpha
mask. Their restrained device presentation uses proportions measured from the
Simulator’s iPhone 17 Pro window, with large storefront-readable headlines.

## Still required before public App Review

- Complete the external TestFlight pass for build 5, including its distinct photo-library/camera actions and official DC311 app handoff plus website fallback.
- Do not advertise nearby restaurant inspections until a useful map is backed by an approved source; remove or clearly limit the placeholder experience if it is not ready.
- Confirm the monitored private contact form remains available at the public support URL.
- Complete the age-rating questionnaire in App Store Connect.
- Complete the App Privacy questionnaire using the audited answers above.
- Enter the private App Review contact phone number and email.
- Select build 1.0, complete export compliance, and choose manual release.
- Finish the physical-device quality gates in `docs/app-store-readiness.md`.
- Do not submit for public App Review until the external TestFlight pass is stable.
