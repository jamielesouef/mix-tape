#!/bin/sh
# Reduce Transparency backstop (engineering doc §9 "Chrome", §12.15; slice 012).
# Every Liquid Glass surface goes through Shared/GlassChrome.swift, which carries the
# opaque fallback, so a raw .glassEffect( anywhere else is a surface with no fallback.
# A Material (.ultraThinMaterial and friends) is the same defect unless the file that
# draws it also reads accessibilityReduceTransparency.
# Exit 0 when clean, 1 with the offending lines otherwise.
set -u
cd "$(dirname "$0")/.." || exit 2
SRC=MixtapeKit/Sources
[ -d "$SRC" ] || { echo "missing $SRC"; exit 2; }
status=0

hits=$(grep -rn --include='*.swift' '\.glassEffect(' "$SRC" | grep -v '/Shared/GlassChrome\.swift:' || true)
if [ -n "$hits" ]; then
    echo "glassEffect outside GlassChrome.swift (use .glassChrome()):"
    echo "$hits"
    status=1
fi

for file in $(grep -rl --include='*.swift' -E '\.(ultraThin|thin|regular|thick|ultraThick|bar)Material\b' "$SRC"); do
    if ! grep -q 'accessibilityReduceTransparency' "$file"; then
        echo "Material without a Reduce Transparency fallback: $file"
        status=1
    fi
done

[ "$status" -eq 0 ] && echo "glass fallback OK"
exit "$status"
