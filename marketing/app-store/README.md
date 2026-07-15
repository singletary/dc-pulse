# App Store assets

This directory contains the canonical App Store screenshot package for DC Pulse 1.0.

## Generate

Install or otherwise make `sharp` available to Node, then run:

```sh
node marketing/app-store/generate-screenshots.mjs
```

The generator reads the privacy-reviewed captures in `source` and writes the final files to `screenshots/en-US/iPhone-6.9`.

## Output contract

- 1320 × 2868 pixels (Apple's accepted 6.9-inch portrait size)
- PNG without an alpha channel
- English (U.S.)
- Ordered by the numeric filename prefix

The source captures are staged at a well-known public Downtown DC landmark. Do not replace them with captures from a developer or tester's actual location, saved Home, email, or other personal data.
