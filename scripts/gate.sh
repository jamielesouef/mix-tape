#!/bin/sh
# Slice gate (CLAUDE.md "Slice gate criteria"): build the one scheme, run the unit tests with the
# UI bundle skipped, then the layer, glass and lint scripts.
#
# Usage: ./scripts/gate.sh -- no arguments.
#
# The per-suite count manifest this script used to read (docs/slices/test-count.txt) was deleted
# with the rest of the slice documents. What it protected -- a test that is silently skipped or
# disabled still passing the gate -- is now enforced straight off the result bundle: failed and
# skipped must both be zero, and the total is printed on every run so a drop is visible in the log.
#
# Every run appends one line to .gate-log (gitignored): start time, commit, total/failed/skipped,
# PASS or FAIL and the failing step. The previous run's output directory survives as "$out.prev"
# so its result bundle can still be read.
set -u
cd "$(dirname "$0")/.." || exit 2
out=${GATE_OUT:-${TMPDIR:-/tmp}/mixtape-gate}
log=.gate-log
sha=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
started=$(date '+%Y-%m-%dT%H:%M:%S')
counts=-

record() {
    printf '%s %s tests=%s %s\n' "$started" "$sha" "$counts" "$*" >> "$log"
}
fail() {
    echo "GATE FAILED: $*"
    record "FAIL $*"
    exit 1
}

[ $# -eq 0 ] || fail "gate.sh takes no arguments"
command -v jq > /dev/null || fail "jq is required to read the result bundle"
command -v swiftformat > /dev/null || fail "swiftformat is not installed (gate criterion 4)"

rm -rf "$out.prev"
[ -d "$out" ] && mv "$out" "$out.prev"
mkdir -p "$out"

# First available iOS simulator. Resolved at runtime: a pinned OS version fails as a destination
# error that reads like a project fault.
ios=$(xcrun simctl list devices available | awk '
    index($0, "-- iOS ") == 1 { inside = 1; next }
    /^-- / { inside = 0 }
    inside && match($0, /\([0-9A-F]+-[0-9A-F-]+\)/) {
        print substr($0, RSTART + 1, RLENGTH - 2); exit
    }')
[ -n "$ios" ] || fail "no available iOS simulator"
echo "simulator: $ios"

step=
run() {
    echo "== $*"
    if ! "$@" > "$out/$step.log" 2>&1; then
        grep -E "error:|Testing failed|TEST FAILED|BUILD FAILED" "$out/$step.log" | cut -c1-300 | head -40
        tail -20 "$out/$step.log"
        fail "$step (log: $out/$step.log)"
    fi
}

step=build
run xcodebuild build -project MixTape.xcodeproj -scheme Mixtape \
    -destination 'generic/platform=iOS Simulator' -quiet
step=test
run xcodebuild test -project MixTape.xcodeproj -scheme Mixtape \
    -destination "platform=iOS Simulator,id=$ios" \
    -skip-testing:MixtapeUITests -resultBundlePath "$out/Mixtape.xcresult" -quiet

xcrun xcresulttool get test-results summary --path "$out/Mixtape.xcresult" > "$out/summary.json"
total=$(jq -r '.totalTestCount' "$out/summary.json")
failed=$(jq -r '.failedTests' "$out/summary.json")
skipped=$(jq -r '.skippedTests' "$out/summary.json")
counts="$total/$failed/$skipped"
echo "tests: total=$total failed=$failed skipped=$skipped"
[ "$failed" = "0" ] || fail "$failed failing test(s)"
[ "$skipped" = "0" ] || fail "$skipped skipped test(s) -- skipping a unit test is never a way to pass"

echo "== ./scripts/check-layer-imports.sh"
./scripts/check-layer-imports.sh || fail "layer imports"
echo "== ./scripts/check-glass-fallback.sh"
./scripts/check-glass-fallback.sh || fail "glass fallback"
echo "== swiftformat --lint ."
swiftformat --lint . || fail "swiftformat"
record PASS
echo "GATE PASSED (logged to $log; previous run kept at $out.prev)"
