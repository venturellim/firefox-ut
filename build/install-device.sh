#!/usr/bin/env bash
#
# Push the click to a connected Ubuntu Touch device and print the install
# command.
#
# The install itself needs root, and Ubuntu Touch's sudo insists on the
# lock-screen password being typed interactively -- it cannot be piped. So this
# transfers the package and hands you the exact command to run.

set -euo pipefail

FF_VERSION="${FF_VERSION:-153.0.3}"
PKG_VERSION="${PKG_VERSION:-${FF_VERSION}.1}"
PKG_NAME="${PKG_NAME:-firefox.ut}"
ARCH="${ARCH:-arm64}"
DEVICE="${DEVICE:-}"          # ssh host alias, e.g. DEVICE=myphone

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
WORK="${WORK:-$ROOT/.build}"

CLICK="$WORK/${PKG_NAME}_${PKG_VERSION}_${ARCH}.click"
REMOTE="/home/phablet/$(basename "$CLICK")"

[[ -f "$CLICK" ]] || { echo "no click at $CLICK -- run build/build.sh first" >&2; exit 1; }

echo "==> $(basename "$CLICK") ($(du -h "$CLICK" | cut -f1))"

if [[ -z "$DEVICE" ]] && command -v adb >/dev/null && adb devices | grep -q "device$"; then
    adb push "$CLICK" "$REMOTE"
elif [[ -n "$DEVICE" ]]; then
    scp "$CLICK" "$DEVICE:$REMOTE"
else
    echo "No adb device found. Set DEVICE to an ssh host alias, e.g." >&2
    echo "  DEVICE=myphone $0" >&2
    exit 1
fi

cat <<EOF

==> Pushed to $REMOTE

On the phone (this asks for your lock-screen password):

    sudo click install --user=phablet --allow-unauthenticated $REMOTE

Two errors during install are expected and harmless:
  - "Unable to connect to user bus: Cannot autolaunch D-Bus without X11 \$DISPLAY"
  - "Error removing /var/cache/apparmor/click_...<old-version>"

Then launch Firefox from the app grid. It will not run if started from a
terminal: Mir only accepts Wayland connections from apps it started itself.

If something goes wrong:  journalctl --user -n 100 --no-pager | grep firefox
EOF
