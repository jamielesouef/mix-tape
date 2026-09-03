#!/bin/sh
# Layer-import backstop for what Package.swift cannot express.
# Engineering doc §3; SPEC-DECISIONS.md decisions 1 and 36.
# Exit 0 when clean, 1 with the offending lines when a forbidden import exists.
set -u
cd "$(dirname "$0")/.." || exit 2
SRC=MixtapeKit/Sources
[ -d "$SRC" ] || { echo "missing $SRC"; exit 2; }
status=0

# $1 = target directory under Sources, $2 = alternation of forbidden module names
forbid() {
    pattern="^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+((struct|class|enum|protocol|func|var|let|typealias)[[:space:]]+)?($2)([[:space:]]|$|\.)"
    hits=$(grep -rnE --include='*.swift' "$pattern" "$SRC/$1" 2>/dev/null || true)
    if [ -n "$hits" ]; then
        echo "$1 must not import $2:"
        echo "$hits"
        status=1
    fi
}

frameworks='SwiftUI|Observation|UIKit|AVFoundation'
forbid MixtapeDomain "$frameworks"
forbid MixtapeUseCase "$frameworks"
forbid MixtapeDomain 'Mixtape[A-Za-z]+'
forbid MixtapeUseCase 'MixtapeInfrastructure|MixtapeData|MixtapeServices|MixtapePresentation'
forbid MixtapeInfrastructure 'MixtapeUseCase|MixtapeData|MixtapeServices|MixtapePresentation'
forbid MixtapeData 'MixtapeServices|MixtapePresentation'
forbid MixtapeServices 'MixtapeData|MixtapePresentation'
forbid MixtapePresentation 'MixtapeData|MixtapeUseCase|MixtapeInfrastructure'

[ "$status" -eq 0 ] && echo "layer imports OK"
exit "$status"
