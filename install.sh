#!/usr/bin/env bash
#
# Firefox for Ubuntu Touch -- guided installer.
#
# Run this on a computer with the phone connected by USB. It checks what is
# needed, looks at your phone, builds the package and installs it. The only
# thing you have to type is your phone's lock-screen password, once.
#
#     ./install.sh          guided
#     ./install.sh --yes    no questions (for scripting)
#
# No programming knowledge required. Nothing is changed on the phone until you
# have been shown what will happen and have agreed to it.

# This script uses bash features. Running it with "sh install.sh" fails in
# confusing ways, so say so plainly instead.
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Please run this with bash:  ./install.sh   (not 'sh install.sh')" >&2
    exit 1
fi

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FF_VERSION="${FF_VERSION:-153.0.3}"
PKG_NAME="${PKG_NAME:-firefox.ut}"
PKG_VERSION="${PKG_VERSION:-${FF_VERSION}.1}"
ARCH=arm64
CLICK_FILE="${PKG_NAME}_${PKG_VERSION}_${ARCH}.click"
CLICK_PATH="$HERE/.build/$CLICK_FILE"

# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

[[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]] && ASSUME_YES=1

cat <<EOF

${B}Firefox for Ubuntu Touch${R}

This will build Firefox as an app for your Ubuntu Touch phone and install it
over USB. It takes roughly 10 to 20 minutes the first time, mostly downloading.

${DIM}Firefox itself is not modified. This packages Mozilla's official build,
adds an on-screen keyboard that Ubuntu Touch is missing for this kind of app,
and configures it for a phone screen.${R}
EOF

# --------------------------------------------------------------------------
step "Checking your computer"

need_tools docker adb tar
if ! command -v wget >/dev/null && ! command -v python3 >/dev/null; then
    die "need either wget or python3 to download Firefox"
fi
ok "docker, adb and the download tools are present"

if ! docker info >/dev/null 2>&1; then
    say ""
    say "    Docker is installed but this user cannot talk to it."
    say "    Usually this is fixed with:"
    say "        sudo usermod -aG docker \$USER"
    say "    then log out and back in (or reboot)."
    die "cannot use docker"
fi
ok "docker is usable"

# --------------------------------------------------------------------------
step "Looking for your phone"
find_phone

step "Reading your phone"
read_phone
dppx="$DPPX"

# --------------------------------------------------------------------------
step "Ready to go"

cat <<EOF
    This will:
      1. download Mozilla's official Firefox for ARM64  (about 90 MB)
      2. prepare a build container                      (about 400 MB, once)
      3. build the app and copy it to your phone
      4. install it -- your phone will ask for your lock-screen password

    Nothing on the phone is modified until step 4.
EOF
say ""
ask_yes_no "Continue?" || { say ""; say "    Nothing was changed."; exit 0; }

# --------------------------------------------------------------------------
step "Building (this is the slow part)"

FF_VERSION="$FF_VERSION" PKG_NAME="$PKG_NAME" PKG_VERSION="$PKG_VERSION" \
DPPX="$dppx" "$HERE/build/build.sh"

[[ -f "$CLICK_PATH" ]] || die "the build did not produce $CLICK_FILE"
ok "built $CLICK_FILE"

install_click "$CLICK_PATH" "$PKG_NAME"
