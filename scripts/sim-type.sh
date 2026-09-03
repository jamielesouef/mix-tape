#!/bin/sh
# Types a value from .jellyfin-dev.env into the focused simulator text field through idb, so
# the literal never appears in a command line you type, a tool argument or a log
# (SPEC-DECISIONS.md 45, 46). Usage: ./scripts/sim-type.sh <ENV_KEY> [udid]
set -u
cd "$(dirname "$0")/.." || exit 2
key=${1:?usage: sim-type.sh <ENV_KEY> [udid]}
udid=${2:-booted}
value=$(grep "^${key}=" .jellyfin-dev.env | head -1 | cut -d= -f2-)
[ -n "$value" ] || { echo "$key not set in .jellyfin-dev.env"; exit 2; }
PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
idb ui text --udid "$udid" "$value" > /dev/null
echo "typed $key (${#value} characters)"
