#!/usr/bin/env bash
#
# Firefox for Ubuntu Touch -- install the ready-made app.
#
# Downloads the published package and installs it on your phone over USB.
# Nothing is compiled, so this needs no Docker and takes about a minute.
#
#     ./install-release.sh                  download the latest release
#     ./install-release.sh some-file.click  install a file you already have
#     ./install-release.sh --yes            no questions (for scripting)
#
# The only thing you type is your phone's lock-screen password, once.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Please run this with bash:  ./install-release.sh" >&2
    exit 1
fi

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

# Where the published packages live. Set this to your own fork if you have one.
REPO="${REPO:-TheSittingPenguin96/firefox-ut}"
PKG_NAME="${PKG_NAME:-firefox.ut}"

LOCAL_CLICK=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        *.click)  LOCAL_CLICK="$arg" ;;
    esac
done

cat <<EOF

${B}Firefox for Ubuntu Touch${R}

This installs the ready-made app on your phone over USB. Nothing is compiled.

EOF

# --------------------------------------------------------------------------
step "Checking your computer"
if [[ -n "$LOCAL_CLICK" ]]; then
    need_tools adb
else
    need_tools adb
    if ! command -v wget >/dev/null && ! command -v python3 >/dev/null; then
        die "need either wget or python3 to download the package"
    fi
fi
ok "everything needed is present"

# --------------------------------------------------------------------------
step "Looking for your phone"
find_phone

step "Reading your phone"
read_phone

# --------------------------------------------------------------------------
step "Getting the app"

if [[ -n "$LOCAL_CLICK" ]]; then
    [[ -f "$LOCAL_CLICK" ]] || die "no such file: $LOCAL_CLICK"
    CLICK="$LOCAL_CLICK"
    ok "using $(basename "$CLICK")"
else
    if [[ -z "$REPO" ]]; then
        cat <<'EOF'

    This copy has no download location set, so there is nothing to fetch.

    Either:
      - pass a package you already have:   ./install-release.sh file.click
      - or build one yourself:             ./install.sh  (see BUILD.md)
      - or set the repository to fetch from:
            REPO=owner/repository ./install-release.sh

EOF
        die "no release location configured"
    fi

    mkdir -p "$HERE/.build"
    api="https://api.github.com/repos/$REPO/releases/latest"
    say "    Looking up the latest release of $REPO"

    if command -v python3 >/dev/null; then
        read -r url name < <(python3 - "$api" <<'PY'
import json, sys, urllib.request
req = urllib.request.Request(sys.argv[1], headers={"User-Agent": "firefox-ut"})
try:
    data = json.load(urllib.request.urlopen(req, timeout=60))
except Exception as e:
    print("", ""); sys.exit(0)
for a in data.get("assets", []):
    if a.get("name", "").endswith(".click"):
        print(a["browser_download_url"], a["name"]); break
else:
    print("", "")
PY
        ) || true
    else
        url=$(wget -qO- "$api" | grep -o '"browser_download_url": *"[^"]*\.click"' | head -1 | cut -d'"' -f4)
        name=$(basename "${url:-}")
    fi

    if [[ -z "${url:-}" ]]; then
        cat <<'EOF'

    No ready-made package has been published yet.

    Build one instead -- see BUILD.md, "Route 1 -- build it yourself":
        ./install.sh

EOF
        die "no published package available"
    fi

    CLICK="$HERE/.build/$name"
    if [[ -f "$CLICK" ]]; then
        ok "already downloaded: $name"
    else
        say "    Downloading $name (about 100 MB)"
        if command -v wget >/dev/null; then
            wget -q --show-progress -O "$CLICK.part" "$url"
        else
            python3 -c "
import shutil, sys, urllib.request
req = urllib.request.Request(sys.argv[1], headers={'User-Agent': 'firefox-ut'})
with urllib.request.urlopen(req, timeout=600) as r, open(sys.argv[2], 'wb') as f:
    shutil.copyfileobj(r, f)" "$url" "$CLICK.part"
        fi
        mv "$CLICK.part" "$CLICK"
        ok "downloaded"
    fi
fi

# --------------------------------------------------------------------------
step "Ready to install"
say "    Package: $(basename "$CLICK")"
say "    Your phone will ask for its lock-screen password."
say ""
ask_yes_no "Continue?" || { say ""; say "    Nothing was changed."; exit 0; }

install_click "$CLICK" "$PKG_NAME"
