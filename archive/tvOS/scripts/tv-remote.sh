#!/usr/bin/env bash
# Drives a booted tvOS simulator from the command line: Siri Remote presses and typed text.
#
#   ./scripts/tv-remote.sh <udid> right right down select
#   ./scripts/tv-remote.sh <udid> 'type:localhost:8096' down down select
#
# Actions: up, down, left, right, select (Return), menu (Escape), 0xNN (raw HID usage), type:TEXT.
# Each press is followed by a 0.4 s settle so focus has moved before the next one; screenshot
# with `xcrun simctl io <udid> screenshot` between calls to see where focus landed.
#
# Why: on CoreSimulator 1155.4 (Xcode 27) `idb ui remote` and the Xcode 26.6 Simulator.app keyboard
# are both refused for tvOS ("Keyboard HID is suppressed"), and the machine has no Xcode 27
# Simulator.app. scripts/tvkey.m talks to the guest's `dtuhidd` directly; see its header.
# Compiles on first use into the Xcode DerivedData-style cache below (not the repo).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source="$here/tvkey.m"
cache="${TMPDIR:-/tmp}/mixtape-tv-remote"
binary="$cache/tvkey"

mkdir -p "$cache"
if [[ ! -x "$binary" || "$source" -nt "$binary" ]]; then
    clang -fobjc-arc -framework Foundation -F/Library/Developer/PrivateFrameworks -framework CoreSimulator \
        -o "$binary" "$source"
fi

exec "$binary" "$@"
