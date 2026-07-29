#!/bin/bash

set -euo pipefail

if [[ $# -lt 3 || $# -gt 6 ]]; then
    echo "usage: $0 <simulator-udid> <DCPulse.app> <output.csv> [run-pairs=5] [timeout-seconds=75] [radius=0.5]" >&2
    exit 64
fi

device_udid=$1
app_path=$2
output_csv=$3
run_pairs=${4:-5}
timeout_seconds=${5:-75}
radius=${6:-0.5}
bundle_id=com.dcpulseapp.DCPulse
script_directory=$(cd "$(dirname "$0")" && pwd)
summarizer="$script_directory/summarize-map-performance.swift"

if [[ ! -d "$app_path" ]]; then
    echo "App bundle not found: $app_path" >&2
    exit 66
fi

if [[ ! -f "$summarizer" ]]; then
    echo "Summarizer not found: $summarizer" >&2
    exit 66
fi

mkdir -p "$(dirname "$output_csv")"
case "$radius" in
    0.25|0.5|1) ;;
    *)
        echo "radius must be 0.25, 0.5, or 1" >&2
        exit 64
        ;;
esac

echo "radius,cache,run,launch_to_initial_s,launch_to_interactive_s,launch_to_first_markers_s,interactive_s,first_markers_s,close_in_s,bounded_s,coverage_session_s,final_items,outcome,dc311_total_s,building_permits_total_s,ddot_permits_total_s,failed_source_requests,dc311_failures,building_permits_failures,ddot_permits_failures" > "$output_csv"

xcrun simctl boot "$device_udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_udid" -b

capture_run() {
    local cache_state=$1
    local run_number=$2
    local resets_install=$3
    local log_file
    local launch_output
    local process_id
    local completed=0

    log_file=$(mktemp -t dc-pulse-map-performance.XXXXXX)
    trap 'rm -f "$log_file"' RETURN

    xcrun simctl terminate "$device_udid" "$bundle_id" >/dev/null 2>&1 || true
    if [[ "$resets_install" == "yes" ]]; then
        xcrun simctl uninstall "$device_udid" "$bundle_id" >/dev/null 2>&1 || true
        xcrun simctl install "$device_udid" "$app_path"
    fi

    launch_output=$(env SIMCTL_CHILD_DCPULSE_MAP_PERFORMANCE_AUTOLAUNCH=1 \
        SIMCTL_CHILD_DCPULSE_MAP_PERFORMANCE_RADIUS="$radius" \
        xcrun simctl launch "$device_udid" "$bundle_id")
    process_id=${launch_output##*: }

    for ((second = 0; second < timeout_seconds; second++)); do
        xcrun simctl spawn "$device_udid" log show \
            --last 2m --info --debug --signpost --style ndjson \
            --predicate "processIdentifier == $process_id AND subsystem == \"$bundle_id\" AND category == \"MapPerformance\" AND signpostName == \"Bounded Map Coverage Complete\"" \
            > "$log_file" 2>/dev/null
        if rg -q '"signpostName":"Bounded Map Coverage Complete"' "$log_file"; then
            completed=1
            break
        fi
        sleep 1
    done

    if [[ "$completed" -ne 1 ]]; then
        echo "Run $run_number ($cache_state) did not complete within ${timeout_seconds}s." >&2
        return 1
    fi

    xcrun simctl spawn "$device_udid" log show \
        --last 2m --info --debug --signpost --style ndjson \
        --predicate "processIdentifier == $process_id AND subsystem == \"$bundle_id\" AND category == \"MapPerformance\" AND (signpostName == \"App Launch Started\" OR signpostName == \"Initial Nearby Results Ready\" OR signpostName == \"Map Presentation Started\" OR signpostName == \"Map Interactive\" OR signpostName == \"First Map Markers\" OR signpostName == \"Close-in Coverage Complete\" OR signpostName == \"Selected Radius Coverage Complete\" OR signpostName == \"Bounded Map Coverage Complete\" OR signpostName == \"Map Coverage Session\" OR signpostName == \"Map Source Request\")" \
        > "$log_file" 2>/dev/null

    xcrun swift "$summarizer" "$radius" "$cache_state" "$run_number" < "$log_file" >> "$output_csv"
    echo "Recorded $cache_state run $run_number."
}

for ((run = 1; run <= run_pairs; run++)); do
    capture_run cold "$run" yes
    capture_run warm "$run" no
done

xcrun simctl terminate "$device_udid" "$bundle_id" >/dev/null 2>&1 || true
echo "Wrote $output_csv"
