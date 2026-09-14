#!/bin/sh
# Compact failure reporter for gate.sh.
#
# Usage: ./scripts/xcreport.sh <step> <logfile> [xcresult-path]
#
# Prints a deduplicated, path-stripped failure summary small enough that an
# agent never needs to open the raw xcodebuild log. Raw logs are the single
# largest token sink in this repo's workflow: a failing build writes thousands
# of lines, of which a handful are the diagnosis and the rest is ceremony.
#
# Every cap reports what it suppressed -- a report that silently truncates is
# worse than no report, because it reads as complete.
set -u

step=${1:?usage: xcreport.sh <step> <logfile> [xcresult]}
log=${2:?usage: xcreport.sh <step> <logfile> [xcresult]}
result=${3:-}
root=$(cd "$(dirname "$0")/.." && pwd)
max=${XCREPORT_MAX:-25}

# Absolute paths cost ~40 chars a line and carry no information the agent needs.
strip() { sed -e "s#$root/##g" -e 's#^ *//*private/var/folders/[^ ]*/##'; }

# Print at most $max lines of $1, then say how many were dropped.
capped() {
    n=$(printf '%s\n' "$1" | grep -c .)
    [ "$n" -eq 0 ] && return 1
    printf '%s\n' "$1" | head -n "$max"
    [ "$n" -gt "$max" ] && printf '  ... and %d more (see %s)\n' "$((n - max))" "$log"
    return 0
}

printf '\n--- %s FAILED ---\n' "$step"

# 1. Compile/link diagnostics. Swift repeats the same error once per compilation
#    unit and per architecture, so dedupe collapses a lot. Dedupe preserves
#    log order -- the first error is usually the root cause and later ones
#    cascade from it, so an alphabetical sort would let the cap drop the
#    one line that actually matters.
errs=$(grep -hE 'error:' "$log" 2>/dev/null \
        | grep -vE '^ *(\^|~|\|)' \
        | sed 's/^ *//' | strip | cut -c1-240 | awk '!seen[$0]++')
if capped "$errs"; then :; fi

# 2. Test failures. The result bundle is structured; the log is not. Prefer it.
if [ -n "$result" ] && [ -e "$result" ] && command -v jq > /dev/null 2>&1; then
    tests=$(xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null \
            | jq -r '.testFailures[]? |
                "\(.targetName // "?") \(.testName // "?"): \(
                    (.failureText // "") | gsub("\n"; " ") )"' 2>/dev/null \
            | strip | cut -c1-240)
    if [ -n "${tests:-}" ]; then
        printf 'test failures:\n'
        capped "$tests" || true
    fi
fi

# 3. Fallback: Swift Testing / XCTest issues straight from the log, for the case
#    where the run died before a result bundle was written.
if [ -z "${errs:-}" ] && [ -z "${tests:-}" ]; then
    issues=$(grep -hE 'recorded an issue|Expectation failed|XCTAssert.*failed|Fatal error|BUILD FAILED|TEST FAILED|does not contain|Unable to find a destination' "$log" 2>/dev/null \
             | sed 's/^ *//' | strip | cut -c1-240 | awk '!seen[$0]++')
    capped "$issues" || printf 'No diagnostic lines matched. Last 15 lines:\n%s\n' \
        "$(tail -15 "$log" | strip | cut -c1-240)"
fi

printf -- '--- end %s ---\n' "$step"
