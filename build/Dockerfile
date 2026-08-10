# Reproducible builder for the Ubuntu Touch Firefox click.
#
# Starts from Clickable's official UT 24.04 arm64 container, which already has
# the aarch64 cross-compiler and the click tooling, and adds the GTK3 arm64
# development files that the Maliit input module needs. Those are not in the
# base image, which is the only reason this Dockerfile exists.
FROM clickable/amd64-ut24.04-1.x-arm64

RUN dpkg --add-architecture arm64 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libgtk-3-dev:arm64 \
        libglib2.0-dev:arm64 && \
    rm -rf /var/lib/apt/lists/*
