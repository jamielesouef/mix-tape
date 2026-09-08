#!/bin/sh
# Slice gate (CLAUDE.md "Slice gate criteria"): build both schemes, run the unit tests on both with
# the UI bundles skipped, then the layer, glass and lint scripts.
#
# Usage: ./scripts/gate.sh          — no arguments. The expected test counts come from
# docs/slices/test-count.txt, per suite, and are checked twice (SPEC-DECISIONS.md decision 38,
# slice 013): against the source tree before anything builds, and against each result bundle
# after the run. Exit 0 with a test missing, moved or skipped is a gate failure.
#
# Every run appends one line to .gate-log (gitignored): start time, commit, per-scheme
# total/failed/skipped, PASS or FAIL and the failing step. The previous run's output directory
# survives as "$out.prev" so its result bundles can still be read.
set -u
cd "$(dirname "$0")/.." || exit 2
manifest=docs/slices/test-count.txt
out=${GATE_OUT:-${TMPDIR:-/tmp}/mixtape-gate}
log=.gate-log
sha=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
started=$(date '+%Y-%m-%dT%H:%M:%S')
ios_counts=-
tv_counts=-

record() {
    printf '%s %s ios=%s tvos=%s %s\n' "$started" "$sha" "$ios_counts" "$tv_counts" "$*" >> "$log"
}
fail() {
    echo "GATE FAILED: $*"
    record "FAIL $*"
    exit 1
}

[ $# -eq 0 ] || fail "gate.sh takes no arguments; the expected counts live in $manifest"
[ -f "$manifest" ] || fail "missing $manifest"
command -v jq > /dev/null || fail "jq is required to read the result bundles"

# "<suite> <count>" lines, comments and blanks dropped.
suites=$(grep -vE '^[[:space:]]*(#|$)' "$manifest")
[ -n "$suites" ] || fail "$manifest names no suites"
expected_total=0
for n in $(printf '%s\n' "$suites" | awk '{ print $2 }'); do
    expected_total=$((expected_total + n))
done

# 1. The source tree must agree with the manifest before a ten-minute build proves it.
printf '%s\n' "$suites" | while read -r suite expected; do
    dir="MixtapeKit/Tests/$suite"
    [ -d "$dir" ] || { echo "  $suite: no directory at $dir"; exit 1; }
    declared=$(grep -rhE '^[[:space:]]*@Test\b' "$dir" --include='*.swift' | wc -l | tr -d ' ')
    if [ "$declared" != "$expected" ]; then
        echo "  $suite declares $declared @Test but $manifest expects $expected"
        exit 1
    fi
done || fail "test manifest — update $manifest deliberately, in the commit that changes the tests"
echo "test manifest: $expected_total @Test declarations across $(printf '%s\n' "$suites" | wc -l | tr -d ' ') suites"

rm -rf "$out.prev"
[ -d "$out" ] && mv "$out" "$out.prev"
mkdir -p "$out"

# First available simulator UDID for the platform named in $1 (iOS or tvOS).
simulator() {
    xcrun simctl list devices available | awk -v os="-- $1 " '
        index($0, os) == 1 { inside = 1; next }
        /^-- / { inside = 0 }
        inside && match($0, /\([0-9A-F]+-[0-9A-F-]+\)/) {
            print substr($0, RSTART + 1, RLENGTH - 2); exit
        }'
}
ios=$(simulator iOS)
tv=$(simulator tvOS)
[ -n "$ios" ] && [ -n "$tv" ] || fail "no available iOS or tvOS simulator"
echo "simulators: iOS=$ios tvOS=$tv"

step=
run() {
    echo "== $*"
    if ! "$@" > "$out/$step.log" 2>&1; then
        grep -E "error:|Testing failed|TEST FAILED|BUILD FAILED|^\s+(Call|Cannot|Missing|Use of|Type|Value|Argument)" "$out/$step.log" | cut -c1-300 | head -40
        tail -20 "$out/$step.log"
        fail "$step (log: $out/$step.log)"
    fi
}

step=build-ios
run xcodebuild build -project MixTape.xcodeproj -scheme iOS -destination 'generic/platform=iOS Simulator' -quiet
step=build-tvos
run xcodebuild build -project MixTape.xcodeproj -scheme tvOS -destination 'generic/platform=tvOS Simulator' -quiet
step=test-ios
run xcodebuild test -project MixTape.xcodeproj -scheme iOS -destination "platform=iOS Simulator,id=$ios" \
    -skip-testing:iOSUITests -resultBundlePath "$out/ios.xcresult" -quiet
step=test-tvos
run xcodebuild test -project MixTape.xcodeproj -scheme tvOS -destination "platform=tvOS Simulator,id=$tv" \
    -skip-testing:tvOSUITests -resultBundlePath "$out/tvos.xcresult" -quiet

# 2. Each bundle ran exactly the manifest's count for every suite: a test that is declared but
# disabled, or that ran under another suite, shows up here and nowhere earlier.
count() {
    bundle=$1
    name=$(basename "$bundle" .xcresult)
    xcrun xcresulttool get test-results summary --path "$bundle" > "$out/$name-summary.json"
    xcrun xcresulttool get test-results tests --path "$bundle" > "$out/$name-tests.json"
    total=$(jq -r '.totalTestCount' "$out/$name-summary.json")
    failed=$(jq -r '.failedTests' "$out/$name-summary.json")
    skipped=$(jq -r '.skippedTests' "$out/$name-summary.json")
    counts="$total/$failed/$skipped"
    echo "$name: total=$total failed=$failed skipped=$skipped (expected $expected_total/0/0)"
    [ "$total" = "$expected_total" ] && [ "$failed" = "0" ] && [ "$skipped" = "0" ] || return 1
    printf '%s\n' "$suites" | while read -r suite expected; do
        ran=$(jq -r --arg suite "$suite" '
            [.. | objects | select(.nodeType == "Unit test bundle" and .name == $suite)
               | .. | objects | select(.nodeType == "Test Case")] | length' "$out/$name-tests.json")
        echo "  $suite ran $ran (expected $expected)"
        [ "$ran" = "$expected" ] || exit 1
    done
}
count "$out/ios.xcresult"
ios_status=$?
ios_counts=${counts:-?}
[ "$ios_status" -eq 0 ] || fail "test count (iOS)"
count "$out/tvos.xcresult"
tv_status=$?
tv_counts=${counts:-?}
[ "$tv_status" -eq 0 ] || fail "test count (tvOS)"

echo "== ./scripts/check-layer-imports.sh"
./scripts/check-layer-imports.sh || fail "layer imports"
echo "== ./scripts/check-glass-fallback.sh"
./scripts/check-glass-fallback.sh || fail "glass fallback"
echo "== swiftformat --lint ."
swiftformat --lint . || fail "swiftformat"
record PASS
echo "GATE PASSED (logged to $log; previous run kept at $out.prev)"
