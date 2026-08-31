# S003 raw findings — run 2026-08-31 against /Volumes/Music/Music

Library: 1175 audio files, 196 album directories, 166 distinct album titles, 60 artist folders.
Containers: 728 .m4a, 340 .mp3, 107 .flac. No .wav, .aiff, .aac, .aif present.
Method: ffprobe -v quiet -print_format json -show_format -show_streams over every file; jq aggregation.

Q1 album-artist coverage: 479/1175 = 40.8%.
  flac 107/107 (100%) · m4a 197/728 (27%) · mp3 175/340 (51%)
  By directory: 72 of 196 dirs have album_artist on no file at all.
  Of those 72: 7 have >1 distinct artist (Various Artists rule fires), 65 are single-artist (fall back to artist).

Q2 streams-only tags: ZERO. Every file has format.tags. 0 files with no tags anywhere.
  streams[].tags carry only: language, creation_time, encoder, comment, handler_name, title — nothing album-related.

Q3 unlisted tag keys in real use:
  TPA = 122 files, mp3 only. ID3v2.2 "part of set" = DISC NUMBER. Never co-occurs with `disc` (TPA-only 122, disc-only 559, both 0).
  FLAC MIXES CASE within one file: ALBUM/TITLE/ARTIST/DATE uppercase, but album_artist/track/disc lowercase.
  `compilation` = 782 files (199 set to "1"). iTunes flag.
  Other ID3v2.2 frames seen: TSA, TS2, TT1, TSC, TSP, TSS, TCM, TST, TBP. Sort/composer frames, not needed.
  Also: sort_album, sort_artist, sort_album_artist, iTunNORM, iTunSMPB, gapless_playback.

Q4 attached_pic by container:
  flac 107/107 have it, codec mjpeg. The plan's FLAC worry is UNFOUNDED.
  m4a  82/728 (11%), codecs mjpeg + png.
  mp3   0/340. Zero. No mp3 has any video stream at all. Verified directly, not just from cache.
  Album dirs with any embedded artwork: 25 of 196. Without: 171.
  cover.jpg/folder.jpg/front.jpg on disk: 3 files total.
  => 171 of 196 album dirs (87%) have NO artwork source of any kind.

Q5 disc markers and disc tags:
  Titles carrying a disc marker: 2 of 166 distinct titles.
    "Digital Domain [Disc 1]"  (disc tag 1/2, album_artist null)
    "Digital Domain - Nikfish.com.au [Disc 2]"  (disc tag 2/2, album_artist null)
    NOTE: stripping the trailing marker leaves "Digital Domain" vs "Digital Domain - Nikfish.com.au".
    F6 stripping alone does NOT group this pair. Their disc TAGS are correct.
  disc tag present: 681 files. In N/M form: 681 (100%). Bare N: 0.
  Distinct disc values: 1/1 x557, 1/2 x71, 2/2 x50, 3/3 x1, 2/3 x1, 1/3 x1.
  => discCount is always populated on this library. 004's max-reconciliation never fires here.
  Multi-disc releases present: The Wall (Remastered 2011 Version), Pharmacy Volumes 1/2/3/5,
    Back 2 Back Vol.2, Bass Station Global Movement 1, Hard Trance, Live At Trance Escape,
    Live at SSL Crash Part 2001, Digital Domain.

Compilation-flag reliability (tested, NOT recommended for adoption):
  compilation="1" but single artist in dir: 41 dirs. compilation absent/0 but multi-artist: 16 dirs.
  => the iTunes flag disagrees with reality in 57 of 196 dirs. Do not key on it.
  The plan's own rule (no album_artist anywhere in dir AND >1 distinct artist) fires on only 7 dirs.

Evidence JSON kept, alongside this file: flac-mixed-case-tags.json, mp3-TPA-disc-tag.json, disc-marker-in-title.json
Full probe set (1175 files, 4.7 MB) NOT kept — regenerable in ~2 min, see README.md
