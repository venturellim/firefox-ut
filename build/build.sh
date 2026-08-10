#!/usr/bin/env bash
#
# Build the Ubuntu Touch Firefox click package.
#
# Downloads Mozilla's official linux-aarch64 Firefox, compiles the two small
# native helpers, and packages everything as a click. Nothing here modifies
# Firefox, and no Firefox source tree is required.
#
# Requirements: docker, and either wget or python3.
#
#   ./build/build.sh                    # latest known-good Firefox release
#   FF_VERSION=155.0 ./build/build.sh   # a specific Firefox release

set -euo pipefail

FF_VERSION="${FF_VERSION:-153.0.3}"
PKG_VERSION="${PKG_VERSION:-${FF_VERSION}.1}"
PKG_NAME="${PKG_NAME:-firefox.ut}"
PKG_TITLE="${PKG_TITLE:-Firefox}"
MAINTAINER="${MAINTAINER:-Ubuntu Touch user <nobody@localhost>}"
DPPX="${DPPX:-}"   # screen scale; empty keeps the packaged default
ARCH="${ARCH:-arm64}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
WORK="${WORK:-$ROOT/.build}"
IMAGE="${IMAGE:-firefox-ut-builder}"

DL="$WORK/dl"
TREE="$WORK/click-root"
TARBALL="$DL/firefox-${FF_VERSION}-aarch64.tar.xz"
CLICK="${PKG_NAME}_${PKG_VERSION}_${ARCH}.click"

URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/${FF_VERSION}/linux-aarch64/en-US/firefox-${FF_VERSION}.tar.xz"

echo "==> Firefox ${FF_VERSION}  ->  ${PKG_NAME} ${PKG_VERSION} (${ARCH})"

mkdir -p "$DL"

# --- 1. Mozilla's official build -------------------------------------------
# Ubuntu Touch 24.04 is aarch64 with glibc 2.39, exactly what this build
# targets: every library it needs is already in the UT rootfs.
if [[ ! -f "$TARBALL" ]]; then
    echo "==> downloading $URL"
    if command -v wget >/dev/null; then
        wget -q --show-progress -O "$TARBALL.part" "$URL"
    else
        python3 -c "
import shutil, sys, urllib.request
req = urllib.request.Request(sys.argv[1], headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=300) as r, open(sys.argv[2], 'wb') as f:
    shutil.copyfileobj(r, f)" "$URL" "$TARBALL.part"
    fi
    mv "$TARBALL.part" "$TARBALL"
fi

# --- 2. Builder image ------------------------------------------------------
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "==> building the builder image (one time, a few minutes)"
    docker build -t "$IMAGE" "$HERE"
fi

# --- 3. Payload ------------------------------------------------------------
echo "==> assembling"
rm -rf "$TREE"
mkdir -p "$TREE"
tar -xJf "$TARBALL" -C "$TREE"
mv "$TREE/firefox" "$TREE/gecko"

# The click payload is mounted read-only, so the updater can never work.
rm -f "$TREE/gecko/updater" "$TREE/gecko/updater.ini" \
      "$TREE/gecko/update-settings.ini"

install -Dm644 "$ROOT/prefs/ut-defaults.js" "$TREE/gecko/defaults/pref/ut-defaults.js"
# Screen scale is the one setting that genuinely depends on the handset, so it
# is substituted into the copy rather than edited in the repository.
if [[ -n "$DPPX" ]]; then
    sed -i "s|^pref(\"layout.css.devPixelsPerPx\".*|pref(\"layout.css.devPixelsPerPx\", \"$DPPX\");|" \
        "$TREE/gecko/defaults/pref/ut-defaults.js"
fi
install -Dm644 "$ROOT/prefs/policies.json"  "$TREE/gecko/distribution/policies.json"

install -Dm755 "$ROOT/click/firefox-ut"      "$TREE/firefox-ut"
install -Dm644 "$ROOT/click/firefox.apparmor" "$TREE/firefox.apparmor"
sed -e "s/@TITLE@/${PKG_TITLE}/" "$ROOT/click/firefox.desktop" > "$TREE/firefox.desktop"
install -Dm644 "$TREE/gecko/browser/chrome/icons/default/default128.png" \
               "$TREE/assets/firefox.png"

sed -e "s/@VERSION@/${PKG_VERSION}/" -e "s/@ARCH@/${ARCH}/" \
    -e "s/@NAME@/${PKG_NAME}/"      -e "s/@TITLE@/${PKG_TITLE}/" \
    -e "s|@MAINTAINER@|${MAINTAINER}|" \
    "$ROOT/click/manifest.json.in" > "$TREE/manifest.json"

# GTK reads the module path from this cache and passes it straight to dlopen(),
# so it is left relative and the launcher puts the click directory on
# LD_LIBRARY_PATH. An absolute path here also fails click-review.
cat > "$TREE/immodules.cache" <<'EOF'
# GTK+ Input Method Modules file
"im-maliit.so"
"maliit" "Maliit" "gtk30" "" ""

EOF

# --- 4. Native helpers + package -------------------------------------------
echo "==> compiling helpers and building the click"
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:$ROOT" -w "$WORK" "$IMAGE" \
    bash -euc "
        CC=aarch64-linux-gnu-gcc
        # /usr/share/pkgconfig matters as well: the arch-independent .pc files
        # (xproto, shared-mime-info, ...) live there, and without it pkg-config
        # fails and silently returns empty CFLAGS.
        export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
        export PKG_CONFIG_PATH=\$PKG_CONFIG_LIBDIR

        \$CC -shared -fPIC -O2 -Wall \
            \$(pkg-config --cflags gtk+-3.0) \
            -o '$TREE/im-maliit.so' \
            '$ROOT/src/gtk-im-maliit/im-maliit.c' \
            \$(pkg-config --libs gtk+-3.0 gio-2.0)

        \$CC -O2 -Wall \
            -o '$TREE/ut-profile-init' \
            '$ROOT/src/ut-profile-init/ut-profile-init.c'

        chmod 755 '$TREE/ut-profile-init'
        click build '$TREE' >/dev/null
        click-review './$CLICK' || true
    "

echo
ls -la "$WORK/$CLICK"
echo
echo "Install it with:  ./build/install-device.sh"
