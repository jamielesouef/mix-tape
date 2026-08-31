# S003 evidence

Three representative `ffprobe` outputs kept from the S003 spike run of 2026-08-31, plus [`findings.md`](findings.md) with every count the spike produced.

The full probe set — 1175 files, 4.7 MB — was deliberately **not** kept. It is generated data, it goes stale the moment anything is retagged, and it regenerates in about two minutes from the command below. These three files were kept because each is an awkward case the counts alone do not convey.

| File | Why it is here |
|---|---|
| [`flac-mixed-case-tags.json`](flac-mixed-case-tags.json) | A FLAC file mixing case *within a single tag set* — `ALBUM`, `TITLE`, `ARTIST`, `DATE` uppercase alongside `album_artist`, `track`, `disc` lowercase. This is the evidence behind slice 004's case-insensitive whole-key lookup |
| [`mp3-TPA-disc-tag.json`](mp3-TPA-disc-tag.json) | An mp3 carrying its disc number in the ID3v2.2 `TPA` frame rather than `disc`. 122 files in the library do this, and `TPA` never co-occurs with `disc` |
| [`disc-marker-in-title.json`](disc-marker-in-title.json) | One half of the `Digital Domain [Disc 1]` / `Digital Domain - Nikfish.com.au [Disc 2]` pair — the case that defeats fork **F6**, because stripping the trailing marker still leaves two different titles |

## Regenerating the full set

Requires `ffprobe` and `jq`, and the music volume attached.

```sh
MUSIC=/Volumes/Music/Music
OUT=/tmp/probe
mkdir -p "$OUT"
find "$MUSIC" -type f \( -iname '*.flac' -o -iname '*.m4a' -o -iname '*.mp3' \
  -o -iname '*.aac' -o -iname '*.wav' -o -iname '*.aiff' -o -iname '*.aif' \) -print0 \
  | xargs -0 -P 8 -I{} sh -c '
      f="$1"; o="$2"
      n=$(printf "%s" "$f" | shasum | cut -c1-16)
      ffprobe -v quiet -print_format json -show_format -show_streams "$f" \
        | jq --arg p "$f" ".sourcePath = \$p" > "$o/$n.json" 2>/dev/null
    ' _ {} "$OUT"
```

Every file carries an added `sourcePath` key so an aggregate can be grouped back by directory. The `jq` one-liners that produced each figure in `findings.md` are recorded beside the figures in [`../S003-ffprobe-tag-shapes.md`](../S003-ffprobe-tag-shapes.md).
