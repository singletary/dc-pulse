#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
icon="$root/DCPulse/DCPulse/Assets.xcassets/AppIcon.appiconset/DC-Pulse-App-Icon.png"
privacy_manifest="$root/DCPulse/DCPulse/PrivacyInfo.xcprivacy"
about_content="$root/DCPulse/DCPulse/Features/About/AboutContent.swift"

check_image() {
    file=$1
    expected_width=$2
    expected_height=$3
    metadata=$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$file")
    echo "$metadata" | grep -q "pixelWidth: $expected_width"
    echo "$metadata" | grep -q "pixelHeight: $expected_height"
    echo "$metadata" | grep -q "hasAlpha: no"
}

check_screenshot_set() {
    directory=$1
    width=$2
    height=$3
    count=0
    for file in "$directory"/*.png; do
        check_image "$file" "$width" "$height"
        count=$((count + 1))
    done
    test "$count" -eq 4
}

check_image "$icon" 1024 1024
check_screenshot_set \
    "$root/marketing/app-store/screenshots/en-US/iPhone-6.9" \
    1320 \
    2868
check_screenshot_set \
    "$root/marketing/app-store/screenshots/en-US/iPhone-6.5" \
    1284 \
    2778
plutil -lint "$privacy_manifest" >/dev/null

grep -q "independent application" "$about_content"
grep -q "DC 311" "$about_content"
grep -q "DC Department of Buildings" "$about_content"
grep -q "District Department of Transportation" "$about_content"

page=$(mktemp)
trap 'rm -f "$page"' EXIT
curl -L --fail --silent --show-error --max-time 20 \
    "https://dcpulseapp.com/" \
    -o "$page"
grep -q 'id="privacy"' "$page"
grep -q 'id="support"' "$page"
grep -q "independent application" "$page"
curl -L --fail --silent --show-error --max-time 20 \
    "https://dcpulseapp.com/support" \
    -o /dev/null

echo "Release asset audit passed."
