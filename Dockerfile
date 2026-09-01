# Mix Tape server image.
#
# Two stages. The build stage is pinned to swift:6.2-noble deliberately: the
# Shared package compiles under both the server and the app, so the container's
# Swift level is the ceiling for the whole repository. A tag newer than the
# local toolchain would let a construct pass on the Mac and fail here. See
# docs/slices/003-docker-image-and-ci.md, Section 6.
#
# Layer order is load-bearing. Dependencies resolve BEFORE the sources are
# copied, so editing a Swift file does not re-fetch Hummingbird.

FROM swift:6.2-noble AS build

WORKDIR /src

# Shared is a path dependency of Server, so it has to exist before resolve runs.
# It changes far less often than the server sources.
COPY Shared Shared

# Manifest and lockfile only — this is the layer that must survive a source edit.
COPY Server/Package.swift Server/Package.resolved Server/
WORKDIR /src/Server
RUN swift package resolve

# Sources last. Everything above this line stays cached when they change.
COPY Server/Sources Sources

# Tests are copied too, in their own layer. Without them SwiftPM's path
# inference for the ServerTests target falls back onto Sources/Server and the
# manifest fails to load with "overlapping sources" — the package is invalid in
# a tree missing a directory it never names. Last, so a test edit leaves the
# source layer cached.
COPY Server/Tests Tests
RUN swift build -c release --static-swift-stdlib \
  && install -D "$(swift build -c release --static-swift-stdlib --show-bin-path)/Server" /out/Server

FROM ubuntu:noble AS runtime

# ffmpeg supplies ffprobe for tag scanning and ffmpeg for artwork extraction.
# Both are invoked as binaries, never linked, which keeps the licence clean.
# ca-certificates is needed to verify Apple's identity-token endpoint.
RUN apt-get update \
  && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# --static-swift-stdlib means the Swift runtime is inside the binary. Nothing
# under /usr/lib/swift exists in this image, and an acceptance criterion checks it.
COPY --from=build /out/Server /usr/local/bin/Server

RUN useradd --create-home --shell /usr/sbin/nologin mixtape

# Create the state directories and hand them to the unprivileged user BEFORE
# switching to it. Docker initialises an empty named volume from the image's
# contents and ownership at the mount point — so if these do not exist here,
# the volume mounts root-owned and the server cannot write its own data.
RUN mkdir -p /var/lib/mixtape/data /var/lib/mixtape/cache \
  && chown -R mixtape:mixtape /var/lib/mixtape

USER mixtape
WORKDIR /home/mixtape

ENV MIXTAPE_DATA_DIR=/var/lib/mixtape/data \
    MIXTAPE_CACHE_DIR=/var/lib/mixtape/cache \
    MIXTAPE_MUSIC_DIR=/music

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/Server"]
