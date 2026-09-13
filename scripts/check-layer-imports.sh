#!/bin/sh
# Layer-import backstop (engineering doc §3 and §10).
#
# The six layers used to be six SPM targets, and the compiler refused a wrong-direction
# import on its own. They are now six folders inside one app module, so the compiler
# enforces nothing and this script is the only check left. It can still catch the
# framework rule -- Domain and UseCase must stay free of UI and platform frameworks --
# but a Presentation file importing a Data type is now invisible to every tool here.
#
# Exit 0 when clean, 1 with the offending lines when a forbidden import exists.
set -u
cd "$(dirname "$0")/.." || exit 2
SRC=source
[ -d "$SRC" ] || { echo "missing $SRC"; exit 2; }
status=0

# $1 = directory to scan, $2 = alternation of forbidden module names
forbid() {
    pattern="^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+((struct|class|enum|protocol|func|var|let|typealias)[[:space:]]+)?($2)([[:space:]]|$|\.)"
    hits=$(grep -rnE --include='*.swift' "$pattern" "$1" 2>/dev/null || true)
    if [ -n "$hits" ]; then
        echo "$1 must not import $2:"
        echo "$hits"
        status=1
    fi
}

frameworks='SwiftUI|Observation|UIKit|AVFoundation|MobileVLCKit'
forbid "$SRC/Domain" "$frameworks"
forbid "$SRC/UseCase" "$frameworks"

[ "$status" -eq 0 ] && echo "layer imports OK"
exit "$status"
