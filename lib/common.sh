# Shared helpers for install.sh and install-release.sh.
#
# Sourced, not executed. Both entry points talk to the phone the same way, so
# the phone-handling lives here once.

if [[ -t 1 ]]; then
    B=$'\e[1m'; DIM=$'\e[2m'; R=$'\e[0m'; GRN=$'\e[32m'; YEL=$'\e[33m'; RED=$'\e[31m'
else
    B=""; DIM=""; R=""; GRN=""; YEL=""; RED=""
fi

say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$R"; }
ok()   { printf '    %s[ok]%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '    %s[!]%s  %s\n' "$YEL" "$R" "$*"; }
die()  { printf '\n%serror:%s %s\n\n' "$RED" "$R" "$*" >&2; exit 1; }

ASSUME_YES="${ASSUME_YES:-0}"

ask_yes_no() {
    local q="$1" a
    if [[ "$ASSUME_YES" == "1" ]]; then
        printf '    %s [Y/n] y\n' "$q"
        return 0
    fi
    while true; do
        read -r -p "    $q [Y/n] " a </dev/tty || a=n
        case "${a:-y}" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo])     return 1 ;;
        esac
    done
}

need_tools() {   # need_tools adb wget ...
    local missing=() t
    for t in "$@"; do
        command -v "$t" >/dev/null || missing+=("$t")
    done
    if (( ${#missing[@]} )); then
        say "    Missing: ${missing[*]}"
        say ""
        say "    On Ubuntu, Debian or Mint:   sudo apt install ${missing[*]}"
        say "    On Fedora:                   sudo dnf install ${missing[*]}"
        say ""
        say "    (the adb command is called 'android-tools' on Fedora and Arch)"
        die "please install the missing programs and run this again"
    fi
}

find_phone() {
    adb start-server >/dev/null 2>&1 || true

    # adb separates serial and state with a TAB, and the serial may contain
    # spaces -- some phones report it literally as "(no serial number)".
    # Splitting on whitespace finds no phone at all on those.
    local devices unauth noperm
    devices=$(adb devices | awk -F'\t' 'NR>1 && $2=="device"' | wc -l)
    unauth=$(adb devices  | awk -F'\t' 'NR>1 && $2=="unauthorized"' | wc -l)
    noperm=$(adb devices  | awk -F'\t' 'NR>1 && $2 ~ /no permissions/' | wc -l)

    if (( noperm > 0 )); then
        say ""
        say "    Your phone is connected, but this computer is not allowed to"
        say "    talk to it. On Linux this needs a one-time permissions rule."
        say "    docs/CONNECTING.md explains it under \"no permissions\"."
        die "insufficient USB permissions"
    fi

    if (( unauth > 0 )); then
        say ""
        say "    Your phone is connected but has not allowed this computer yet."
        say "    Look at the phone's screen and accept the request, then run"
        say "    this again.  More help: docs/CONNECTING.md"
        die "phone not authorised"
    fi

    if (( devices == 0 )); then
        cat <<'EOF'

    No phone found. On the phone, check that:

      1. It is connected by USB (try a different cable -- some only charge).
      2. Developer Mode is on:
             Settings -> About -> Developer Mode -> switch it on
         It will ask you to set a lock-screen passcode first if you have none.
      3. When the phone asks whether to trust this computer, accept.

    More help: docs/CONNECTING.md

EOF
        die "no phone detected over USB"
    fi

    (( devices == 1 )) || die "more than one device is connected -- unplug the others"
    ok "phone connected"
}

# Sets MODEL, UTVER, CHANNEL, RES and DPPX.
read_phone() {
    MODEL=$(adb shell "cat /etc/machine-info 2>/dev/null | sed -n 's/PRETTY_HOSTNAME=//p' | tr -d '\"\r'" 2>/dev/null || true)
    CHANNEL=$(adb shell "sed -n 's/^channel: //p' /etc/system-image/channel.ini 2>/dev/null | tr -d '\r'" 2>/dev/null || true)
    UTVER=$(adb shell ". /etc/os-release 2>/dev/null; echo \$VERSION_ID" 2>/dev/null | tr -d '\r' || true)
    RES=$(adb shell "cat /sys/class/drm/*/modes 2>/dev/null | head -1 | tr -d '\r'" 2>/dev/null || true)

    [[ -n "$MODEL" ]] || MODEL="(unknown)"
    [[ -n "$UTVER" ]] || UTVER="(unknown)"

    say "    Device      : $MODEL"
    say "    Ubuntu Touch: $UTVER"
    say "    Channel     : ${CHANNEL:-(unknown)}"
    say "    Screen      : ${RES:-(unknown)}"

    case "$UTVER" in
        24.04*)      ok "supported Ubuntu Touch version" ;;
        "(unknown)") warn "could not read the Ubuntu Touch version; continuing" ;;
        *)           warn "this was made for Ubuntu Touch 24.04; yours says $UTVER" ;;
    esac

    # Screen scale is the one setting that genuinely depends on the handset.
    local width="${RES%%x*}"
    if [[ "$width" =~ ^[0-9]+$ ]] && (( width > 0 )); then
        DPPX=$(awk -v w="$width" 'BEGIN{ v=w/540; v=int(v*2+0.5)/2; if(v<1)v=1; printf "%.1f", v }')
    else
        DPPX="2.0"
    fi

    if [[ "$MODEL" != *"Plinius"* ]]; then
        say ""
        warn "This has only ever been tested on a Volla Phone Plinius."
        warn "It may work on your device, but nobody has tried. Nothing is"
        warn "permanently changed -- you can uninstall it afterwards."
    fi
}

# install_click <local .click file> <package name>
install_click() {
    local click="$1" pkg="$2"
    local remote="/home/phablet/$(basename "$click")"

    step "Copying to the phone"
    adb push "$click" "$remote" >/dev/null
    ok "copied"

    step "Installing"
    cat <<EOF
    Your phone will now ask for your ${B}lock-screen password${R} -- the code or
    password you use to unlock the phone. Type it and press Enter.

    ${DIM}It is not shown as you type, and it is not stored anywhere.${R}

EOF

    # Two -t options force a remote PTY, which sudo needs in order to prompt.
    # A single -t is silently downgraded when stdin is not a terminal.
    set +e
    adb shell -t -t "sudo click install --user=phablet --allow-unauthenticated '$remote'"
    local rc=$?
    set -e

    if (( rc != 0 )); then
        say ""
        warn "The install command reported a problem."
        warn "If you mistyped the password, just run this again."
    fi

    local installed
    installed=$(adb shell "click list 2>/dev/null | grep -c '$pkg'" 2>/dev/null | tr -d '\r' || echo 0)
    [[ "$installed" != "0" ]] || die "Firefox is not in the phone's app list -- the install did not complete"

    adb shell "rm -f '$remote'" >/dev/null 2>&1 || true

    cat <<EOF

${GRN}${B}Done.${R}

    Open ${B}Firefox${R} from the app grid on your phone.

    ${DIM}It must be started from the app grid -- Ubuntu Touch will not let it
    run if you start it from a terminal.${R}

    Problems?  docs/TROUBLESHOOTING.md
    To remove: adb shell -t -t "sudo click unregister --user=phablet $pkg"

EOF
}
