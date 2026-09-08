# Jellyfin API specification

[jellyfin-openapi.json](jellyfin-openapi.json) is a local copy of Jellyfin's published stable OpenAPI specification, downloaded on 2026-09-03.

- Jellyfin API version: **12.0.0** (`info.version` and `info.x-jellyfin-version`).
- OpenAPI specification version: **3.0.4** (`openapi`).
- Source: [Official Jellyfin mirror — stable specification](https://lon1.mirror.jellyfin.org/files/openapi/jellyfin-openapi-stable.json).
- Interactive documentation: [api.jellyfin.org](https://api.jellyfin.org/).

The source URL tracks the latest stable specification; this checked-in copy preserves the downloaded version. The Dockerfile uses `jellyfin/jellyfin:latest`, so verify the running server version before assuming it matches this specification.
