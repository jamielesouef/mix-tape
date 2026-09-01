#!/bin/bash
#
#  check-spdx.sh
#  MixTape
#
#  Created by Jamie Le Souëf on 01/09/2026.
#
# Asserts the SPDX licence header on every Swift source file in the repository.
#
# Two rules, keyed on the filename so the exemption is machine-checkable:
#
#   * A file named Package.swift must carry "// swift-tools-version:" on line 1
#     and its directory's SPDX identifier on line 2. Swift parses the
#     tools-version line positionally, so it cannot be displaced.
#   * Every other .swift file must carry its directory's SPDX identifier on
#     line 1.
#
# A path this script cannot read is a FAILURE, never a skip. Reporting "clean"
# for a directory that was never opened is the exact failure mode this check
# exists to prevent.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

licence_for_path() {
  case "$1" in
    Server/*) echo "AGPL-3.0-only" ;;
    App/*|Shared/*) echo "MIT" ;;
    *) echo "" ;;
  esac
}

# The file list comes from git: tracked files plus new ones that are not
# ignored. A plain `find` would walk Server/.build/checkouts and assert this
# repository's licence over every vendored dependency.
if ! files=$(git ls-files --cached --others --exclude-standard -- '*.swift'); then
  echo "FAIL: could not list Swift files with git ls-files"
  exit 1
fi

if [ -z "$files" ]; then
  echo "FAIL: no Swift files found — the file list is empty, which means the walk is broken, not that the repository is clean"
  exit 1
fi

checked=0

while IFS= read -r file; do
  [ -z "$file" ] && continue

  directory=$(dirname "$file")
  if [ ! -d "$directory" ] || [ ! -r "$directory" ] || [ ! -x "$directory" ]; then
    fail "$directory is missing or unreadable — refusing to skip it"
    continue
  fi

  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    fail "$file is missing or unreadable — refusing to skip it"
    continue
  fi

  licence=$(licence_for_path "$file")
  if [ -z "$licence" ]; then
    fail "$file is outside Shared/, App/ and Server/, so no licence can be derived for it"
    continue
  fi

  expected="// SPDX-License-Identifier: $licence"
  line1=$(sed -n '1p' "$file")
  line2=$(sed -n '2p' "$file")

  if [ "$(basename "$file")" = "Package.swift" ]; then
    case "$line1" in
      "// swift-tools-version:"*) ;;
      *) fail "$file line 1 is not a swift-tools-version line: $line1" ;;
    esac
    if [ "$line2" != "$expected" ]; then
      fail "$file line 2 should be '$expected' but is '$line2'"
    fi
  else
    if [ "$line1" != "$expected" ]; then
      fail "$file line 1 should be '$expected' but is '$line1'"
    fi
  fi

  checked=$((checked + 1))
done <<< "$files"

if [ "$failures" -ne 0 ]; then
  echo "check-spdx: $failures problem(s) across $checked file(s) checked"
  exit 1
fi

echo "check-spdx: $checked Swift file(s) carry the correct SPDX header"
