#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../App"

LAYERS=(AppDomain AppUseCase AppServices AppInfrastructure AppData AppPresentation)

violations=0

fail() {
  echo "error: $1"
  violations=1
}

# Prints "<line>: <module>" for every import line in a file, tolerating
# attributes (@preconcurrency, @_exported, ...), access modifiers (public/
# private/internal/package import), submodule imports (import struct Mod.Sym),
# trailing "//" comments, trailing whitespace and CRLF line endings.
imported_modules() {
  awk '
    {
      line = $0
      sub(/\r$/, "", line)
      sub(/\/\/.*/, "", line)
      if (line ~ /^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|private|internal|package)[[:space:]]+)?import[[:space:]]+/) {
        rest = line
        sub(/^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|private|internal|package)[[:space:]]+)?import[[:space:]]+/, "", rest)
        sub(/^(struct|class|enum|protocol|typealias|func|var|let)[[:space:]]+/, "", rest)
        sub(/^[[:space:]]+/, "", rest)
        n = split(rest, parts, /[^A-Za-z0-9_]/)
        if (parts[1] != "") print NR": " parts[1]
      }
    }
  ' "$1"
}

# Prints every line of a file except lines inside a #Preview { ... } block, so
# the Presentation type-name rule below doesn't fire on preview fixtures.
lines_outside_previews() {
  awk '
    BEGIN { in_preview = 0; depth = 0 }
    {
      line = $0
      if (in_preview == 0) {
        if (line ~ /#Preview/) {
          in_preview = 1
          depth = 0
          opens = gsub(/\{/, "{", line)
          closes = gsub(/\}/, "}", line)
          depth += opens - closes
          next
        }
        print NR": " $0
        next
      }
      opens = gsub(/\{/, "{", line)
      closes = gsub(/\}/, "}", line)
      depth += opens - closes
      if (depth <= 0) { in_preview = 0 }
    }
  ' "$1"
}

forbidden_imports_for_layer() {
  case "$1" in
    AppDomain|AppUseCase)
      echo "SwiftUI Observation UIKit AppKit SwiftData CoreGraphics Combine"
      ;;
    AppServices)
      echo "SwiftUI UIKit AppKit SwiftData CoreGraphics Combine"
      ;;
    AppInfrastructure)
      echo "SwiftUI Observation SwiftData Combine"
      ;;
    AppData)
      echo "SwiftUI Observation Combine"
      ;;
    AppPresentation)
      echo "SwiftData Combine"
      ;;
  esac
}

# --- per-layer import checks ------------------------------------------------
# A layer directory that is missing or unreadable is a hard failure, never a
# skip: a renamed or deleted layer must not report clean.

for layer in "${LAYERS[@]}"; do
  layer_dir="$APP_DIR/$layer"

  if [ ! -d "$layer_dir" ] || [ ! -r "$layer_dir" ]; then
    fail "$layer/ is missing or unreadable at $layer_dir — cannot verify its imports"
    continue
  fi

  forbidden="$(forbidden_imports_for_layer "$layer")"

  while IFS= read -r -d '' file; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      module="${hit#*: }"
      for banned in $forbidden; do
        if [ "$module" = "$banned" ]; then
          fail "$layer/ must not import $banned — ${file#"$APP_DIR/"}:${hit%%:*}"
        fi
      done
    done < <(imported_modules "$file")
  done < <(find "$layer_dir" -name '*.swift' -print0)
done

# AppData/Persistence/ is the one place SwiftData is allowed (SwiftData
# ModelContainer, @Model types and store actors live there per the layer
# table's exception). Everywhere else in AppData, SwiftData is still banned.
appdata_dir="$APP_DIR/AppData"
if [ -d "$appdata_dir" ] && [ -r "$appdata_dir" ]; then
  while IFS= read -r -d '' file; do
    case "$file" in
      "$appdata_dir"/Persistence/*) continue ;;
    esac
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      module="${hit#*: }"
      if [ "$module" = "SwiftData" ]; then
        fail "AppData/ (outside Persistence/) must not import SwiftData — ${file#"$APP_DIR/"}:${hit%%:*}"
      fi
    done < <(imported_modules "$file")
  done < <(find "$appdata_dir" -name '*.swift' -print0)
fi

# --- banned type-name references --------------------------------------------
# Six layers share one build target, so there is no module boundary — an
# import check is structurally blind to a type reference that crosses layers.
# These catch the shape an import check cannot see (Blocker 2: a service
# constructing a type that only AppData should know about).

domain_usecase_dirs=("$APP_DIR/AppDomain" "$APP_DIR/AppUseCase")
for layer_dir in "${domain_usecase_dirs[@]}"; do
  [ -d "$layer_dir" ] && [ -r "$layer_dir" ] || continue
  matches=$(grep -rnE 'URLSession|APIClient|ModelContainer' "$layer_dir" --include="*.swift" || true)
  if [ -n "$matches" ]; then
    fail "${layer_dir#"$APP_DIR/"}/ must not reference URLSession, APIClient or ModelContainer:"
    echo "$matches"
  fi
done

# AppServices may reference a *RepositoryProtocol (the abstraction it depends
# on) or a Mock*/Stub* test double (C3's blessed second conformer, now living
# in AppUseCase beside the protocol) but never a concrete repository
# implementation — that would mean a service reaching into AppData directly.
services_dir="$APP_DIR/AppServices"
if [ -d "$services_dir" ] && [ -r "$services_dir" ]; then
  while IFS= read -r -d '' file; do
    while IFS=: read -r lineno content; do
      [ -n "$lineno" ] || continue
      scrubbed=$(printf '%s' "$content" | sed -E 's/(Mock|Stub)[A-Za-z0-9]*Repository//g')
      if printf '%s' "$scrubbed" | grep -qE '[A-Z][A-Za-z0-9]*Repository\b'; then
        fail "AppServices/ must not reference a concrete *Repository type (only *RepositoryProtocol, or a Mock*/Stub* test double, is layer-legal) — ${file#"$APP_DIR/"}:$lineno: $content"
      fi
    done < <(grep -nE '[A-Z][A-Za-z0-9]*Repository\b' "$file" || true)
  done < <(find "$services_dir" -name '*.swift' -print0)
fi

# A view's signature must not name a use case or repository type; the service
# is responsible for shaping data for it. #Preview fixtures are exempt — they
# legitimately wire a Mock*Repository/UseCase for the canvas.
presentation_dir="$APP_DIR/AppPresentation"
if [ -d "$presentation_dir" ] && [ -r "$presentation_dir" ]; then
  while IFS= read -r -d '' file; do
    matches=$(lines_outside_previews "$file" | grep -E 'UseCase|Repository' || true)
    if [ -n "$matches" ]; then
      fail "AppPresentation/ must not reference a UseCase or Repository type outside #Preview — ${file#"$APP_DIR/"}:"
      echo "$matches"
    fi
  done < <(find "$presentation_dir" -name '*.swift' -print0)
fi

# Mock*/Stub* test doubles are the second conformer of a repository protocol
# (C3) and belong beside the protocol in AppUseCase, never defined in AppData
# — that is Blocker 2's exact shape, from the other end: it doesn't matter
# whether anything still references it, a stray double defined in AppData is
# itself the drift.
if [ -d "$appdata_dir" ] && [ -r "$appdata_dir" ]; then
  matches=$(grep -rnE '(struct|class|enum|actor)[[:space:]]+(Mock|Stub)[A-Za-z0-9]*' "$appdata_dir" --include="*.swift" || true)
  if [ -n "$matches" ]; then
    fail "AppData/ must not define a Mock*/Stub* test double — it belongs beside its protocol in AppUseCase:"
    echo "$matches"
  fi
fi

if [ "$violations" -ne 0 ]; then
  exit 1
fi

echo "check-layer-imports: all six layers are clean"
