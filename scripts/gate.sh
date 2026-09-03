#!/bin/sh
# Slice gate (CLAUDE.md "Slice gate criteria"): build both schemes, run the unit
# tests on both with the UI bundles skipped, run the layer script, lint.
# Usage: ./scripts/gate.sh <expected-test-count>
# The executed test count is asserted per scheme from the result bundle
# (SPEC-DECISIONS.md decision 38): exit 0 with fewer tests is a gate failure.
set -u
cd "$(dirname "$0")/.." || exit 2
expected=${1:?usage: gate.sh <expected-test-count>}
out=${GATE_OUT:-${TMPDIR:-/tmp}/mixtape-gate}
rm -rf "$out"
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
[ -n "$ios" ] && [ -n "$tv" ] || { echo "no available iOS or tvOS simulator"; exit 2; }
echo "simulators: iOS=$ios tvOS=$tv"

step=
run() {
    echo "== $*"
    if ! "$@" > "$out/$step.log" 2>&1; then
        grep -E 'error:|failed|FAIL' "$out/$step.log" | head -40
        tail -20 "$out/$step.log"
        echo "GATE FAILED at $step (log: $out/$step.log)"
        exit 1
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

field() { printf '%s' "$1" | grep -oE "\"$2\" *: *[0-9]+" | grep -oE '[0-9]+$' | head -1; }
count() {
    summary=$(xcrun xcresulttool get test-results summary --path "$1")
    total=$(field "$summary" totalTestCount)
    failed=$(field "$summary" failedTests)
    skipped=$(field "$summary" skippedTests)
    echo "$(basename "$1"): total=${total:-?} failed=${failed:-?} skipped=${skipped:-?} (expected $expected/0/0)"
    if [ "${total:-x}" != "$expected" ] || [ "${failed:-x}" != "0" ] || [ "${skipped:-x}" != "0" ]; then
        echo "GATE FAILED: test count"
        exit 1
    fi
    tests=$(xcrun xcresulttool get test-results tests --path "$1")
    for suite in MixtapeDomainTests MixtapeUseCaseTests MixtapeServicesTests MixtapeDataTests; do
        printf '%s' "$tests" | grep -q "\"$suite\"" || { echo "GATE FAILED: $suite did not run"; exit 1; }
    done
}
count "$out/ios.xcresult"
count "$out/tvos.xcresult"

echo "== ./scripts/check-layer-imports.sh"
./scripts/check-layer-imports.sh || { echo "GATE FAILED: layer imports"; exit 1; }
echo "== swiftformat --lint ."
swiftformat --lint . || { echo "GATE FAILED: swiftformat"; exit 1; }
echo "GATE PASSED"
