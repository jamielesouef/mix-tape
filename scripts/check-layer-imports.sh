#!/bin/sh
# Layer-import backstop for what Package.swift cannot express.
# Engineering doc §3 and §10; SPEC-DECISIONS.md decisions 1 and 36.
# Exit 0 when clean, 1 with the offending lines when a forbidden import exists.
set -u
cd "$(dirname "$0")/.." || exit 2
SRC=MixtapeKit/Sources
APPS=Apps
# The composition root (§10) is the one file that sees all six layers.
ROOT=Apps/Shared/AppContainer.swift
for dir in "$SRC" "$APPS"; do
    [ -d "$dir" ] || { echo "missing $dir"; exit 2; }
done
[ -f "$ROOT" ] || { echo "missing $ROOT"; exit 2; }
status=0

# $1 = directory to scan, $2 = alternation of forbidden module names, $3 = optional path to exempt
forbid() {
    pattern="^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+((struct|class|enum|protocol|func|var|let|typealias)[[:space:]]+)?($2)([[:space:]]|$|\.)"
    hits=$(grep -rnE --include='*.swift' "$pattern" "$1" 2>/dev/null | grep -v "^${3:-}:" || true)
    if [ -n "$hits" ]; then
        echo "$1 must not import $2:"
        echo "$hits"
        status=1
    fi
}

frameworks='SwiftUI|Observation|UIKit|AVFoundation'
forbid "$SRC/MixtapeDomain" "$frameworks"
forbid "$SRC/MixtapeUseCase" "$frameworks"
forbid "$SRC/MixtapeDomain" 'Mixtape[A-Za-z]+'
forbid "$SRC/MixtapeUseCase" 'MixtapeInfrastructure|MixtapeData|MixtapeServices|MixtapePresentation'
forbid "$SRC/MixtapeInfrastructure" 'MixtapeUseCase|MixtapeData|MixtapeServices|MixtapePresentation'
forbid "$SRC/MixtapeData" 'MixtapeServices|MixtapePresentation'
forbid "$SRC/MixtapeServices" 'MixtapeData|MixtapePresentation'
forbid "$SRC/MixtapePresentation" 'MixtapeData|MixtapeUseCase|MixtapeInfrastructure'
# App targets see Presentation (and Services, for the environment) — everything below that is
# the composition root's alone (slice 013).
forbid "$APPS" 'MixtapeData|MixtapeUseCase|MixtapeInfrastructure' "$ROOT"

[ "$status" -eq 0 ] && echo "layer imports OK"
exit "$status"
