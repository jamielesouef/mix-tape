# Jellyfin API specification

[jellyfin-openapi.json](jellyfin-openapi.json) is the specification served by the
Jellyfin instance this project is built against, pulled from
`http://localhost:8096/api-docs/openapi.json` on 2026-09-03.

- Jellyfin API version: **10.11.11** (`info.version` and `info.x-jellyfin-version`).
- OpenAPI specification version: **3.0.1** (`openapi`).
- 315 paths.
- Source: the running server itself, not a published mirror.

## Why the running server and not the published stable spec

This file previously held Jellyfin **12.0.0** (OpenAPI 3.0.4, 294 paths),
downloaded from the official stable mirror. The local server runs **10.11.11**,
and the two differ in a way that matters to this build.

The overlap is large — 293 shared paths, and every endpoint V1 needs is in both.
But the 12.0.0 spec is **missing 22 paths the running server has**, and two of
them are on V1's critical path:

- `/Videos/{itemId}/master.m3u8`
- `/Audio/{itemId}/master.m3u8`

Those are the HLS transcode URLs behind `PlaybackMethod.transcodeHLS` and the
music HLS fallback. Implementing against the 12.0.0 spec means implementing
those two paths from nothing, or silently omitting them.

The difference runs the other way too, but harmlessly: exactly one path exists in
12.0.0 and not on the server (`/Items/{itemId}/Collections`), and collections are
out of scope for V1. Component schemas are 357 in both, differing by two names in
each direction.

## Refreshing this file

The compose file in the main repo runs image `mixtape-jellyfin:local`, built from Jellyfin 10.11.11; this repo's `docker-compose.yml` pins `jellyfin/jellyfin:10.11.11` so a fresh environment gets the version the spec and fixtures were captured from (slice 019). When either image is rebuilt or the server upgraded, re-pull the spec and re-check:

```bash
curl -s http://localhost:8096/api-docs/openapi.json -o docs/jellyfin-openapi.json
python3 -c "import json;d=json.load(open('docs/jellyfin-openapi.json'));print(d['info']['version'], len(d['paths']))"
```
