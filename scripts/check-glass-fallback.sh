#!/bin/sh
# Reduce Transparency backstop (engineering doc §9 "Chrome", §12.15; slice 012).
#
# Every Liquid Glass surface the app draws goes through Shared/GlassChrome.swift, which
# carries the opaque fallback. A raw .glassEffect( anywhere else is a surface with no
# fallback. So is a Material, a .bar background, a blur, or a system container that
# renders glass on the app's behalf.
#
# The check is PER SITE, not per file. An earlier version passed a whole file as soon as
# the string accessibilityReduceTransparency appeared anywhere in it, so a second,
# ungated Material in the same file was invisible. Each flagged line must now carry its
# own marker:
#
#     .someTranslucentThing()  // glass-fallback: <why this site is safe>
#
# or have that marker on the line immediately above it. Acknowledged sites are printed on
# every run, so the inventory of translucency in this app stays visible rather than
# decaying into a silent allowlist.
#
# Exit 0 when clean, 1 with the offending lines otherwise.
set -u
cd "$(dirname "$0")/.." || exit 2
DIRS="source"
for dir in $DIRS; do
    [ -d "$dir" ] || { echo "missing $dir"; exit 2; }
done
status=0

# A line is exempt when it carries the marker, or the comment block directly above it does.
# Walk up through contiguous comment lines only, so a marker cannot drift away from its
# site and keep exempting it.
marked() {
    sed -n "${2}p" "$1" | grep -q 'glass-fallback:' && return 0
    n=$(($2 - 1))
    while [ "$n" -ge 1 ]; do
        above=$(sed -n "${n}p" "$1")
        printf '%s' "$above" | grep -qE '^[[:space:]]*(//|$)' || return 1
        printf '%s' "$above" | grep -q 'glass-fallback:' && return 0
        n=$((n - 1))
    done
    return 1
}

# check <label> <extended-regex>
check() {
    label=$1
    # GlassChrome.swift is the one sanctioned home of .glassEffect and owns the fallback.
    hits=$(grep -rnE --include='*.swift' "$2" $DIRS 2>/dev/null | grep -v '/Shared/GlassChrome\.swift:' || true)
    [ -n "$hits" ] || return 0
    # Split on newlines with a for loop, not `| while read`: a pipeline runs the loop in a
    # subshell and the status=1 below would be lost.
    saved=$IFS
    IFS='
'
    for hit in $hits; do
        file=${hit%%:*}
        rest=${hit#*:}
        line=${rest%%:*}
        code=${rest#*:}
        if marked "$file" "$line"; then
            echo "  ok   $label — $file:$line"
        else
            echo "  MISS $label with no Reduce Transparency fallback — $file:$line"
            echo "       $(printf '%s' "$code" | sed 's/^[[:space:]]*//')"
            status=1
        fi
    done
    IFS=$saved
}

# Every spelling that puts translucency on screen.
check 'Material token'   '\.(ultraThin|thin|regular|thick|ultraThick)Material\b'
# The prefix form the token pattern misses.
check 'Material prefix'  '\bMaterial\.(ultraThin|thin|regular|thick|ultraThick|bar)\b'
# The real spelling of the bar material. The previous pattern looked for `.barMaterial`,
# a token SwiftUI has never had, so this whole family went unchecked.
check 'bar background'   '\.background\(([^)]*, *)?\.bar\b'
check 'blur'             '\.blur\(|\bvisualEffect\('
# Containers the system draws as Liquid Glass on the app's behalf.
check 'system glass'     '\btabViewBottomAccessory\b'
check 'glassEffect'      '\.glassEffect\('

[ "$status" -eq 0 ] && echo "glass fallback OK"
exit "$status"
