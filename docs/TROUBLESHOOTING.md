# Troubleshooting

*Deutsche Fassung: [TROUBLESHOOTING_DE.md](TROUBLESHOOTING_DE.md)*

## First: how to see anything at all

The launcher prints to stdout, which Lomiri captures:

```sh
journalctl --user -n 200 --no-pager | grep -iE "firefox|aa-exec"
```

Lines beginning `firefox-ut:` come from the launcher and show which paths and
display it chose.

## Changing settings without rebuilding

The launcher sources `~/.local/share/<package>/ut-env.sh` if it exists, so the
environment can be changed on the device:

```sh
cat > ~/.local/share/firefox.yourname/ut-env.sh <<'EOF'
export MOZ_LOG_FILE=/home/phablet/.local/share/firefox.yourname/ff.log
export MOZ_LOG="Widget:4"
exec 2> /home/phablet/.local/share/firefox.yourname/stderr.log
EOF
```

Shell redirection works; external commands do not (see below).

**Delete this file when you are done.** It lives in app storage, not in the
read-only package, so it survives reinstalls and will silently override the
packaged configuration. A forgotten `ut-env.sh` is very easy to mistake for a
regression.

Preferences can be changed the same way, without rebuilding, via `user.js` in
the profile:

```sh
echo 'user_pref("layout.css.devPixelsPerPx", "2.5");' \
  >> ~/.local/share/firefox.yourname/profile/user.js
```

Firefox must be **closed** when you edit anything in the profile — it rewrites
`prefs.js` on exit and will overwrite your change.

## Symptoms

### Nothing happens, or the app exits immediately

Check the journal for `exit 126` or `Permission denied` naming a command such as
`readlink`, `dirname` or `mkdir`. Click confinement has no general exec rule for
`/usr/bin`, so a launcher that calls any system utility dies instantly. Use
shell built-ins only.

### The window is transparent, or you see only the wallpaper

The app is probably running on Wayland rather than XWayland. Confirm with:

```sh
journalctl --user -n 100 --no-pager | grep "firefox-ut: WAYLAND_DISPLAY"
```

It should print `<unset>`. If it shows `wayland-0`, something is re-enabling the
Wayland backend — most likely a leftover `ut-env.sh`.

Mir does not display the `wl_subsurface` that Gecko draws page content into, so
the native Wayland path yields a mapped, painted, entirely transparent window.

### It crashes about 0.2 s after starting

Check for:

```
gtk_im_multicontext_set_context_id ... wl_proxy_get_version
```

That is `GTK_IM_MODULE=wayland` under X11: GTK loads `im-wayland.so`, which
calls into libwayland with no Wayland display and dereferences NULL. It must be
`maliit`, never `wayland`, on the X11 path.

### No keyboard appears

```sh
journalctl --user -n 200 --no-pager | grep -iE "im-maliit|IM context"
```

- `im-maliit.so: cannot open shared object file` — GTK passes the path from
  `immodules.cache` straight to `dlopen()`, so the package directory has to be
  on `LD_LIBRARY_PATH`.
- `Loading IM context type 'maliit' failed` — the module was found but would not
  load; usually an ABI mismatch with the device's GTK.
- Nothing at all — check `GTK_IM_MODULE` and `GTK_IM_MODULE_FILE` are set.

Confirm Maliit itself is reachable:

```sh
gdbus call --session --dest org.maliit.server \
  --object-path /org/maliit/server/address \
  --method org.freedesktop.DBus.Properties.Get \
  org.maliit.Server.Address address
```

### The keyboard appears but typing does nothing

The client object path is almost certainly wrong. It is
`/com/meego/inputmethod/inputcontext` — **no trailing "1"** — while the
interface *is* `com.meego.inputmethod.inputcontext1`. Showing the keyboard is an
outbound call and works regardless; keystrokes come back to the exported object
and are dropped if it is not where Maliit expects.

### Suggestions replace nothing, or text is duplicated

`commitString` carries a replace range that has to be applied with
`gtk_im_context_delete_surrounding()` before committing. Ignore it and a
completed word is appended to the one you typed.

### Touch does not scroll or zoom

`MOZ_USE_XINPUT2=1` must be set. On X11 Gecko calls `gdk_disable_multidevice()`
without it, which disables the touchscreen; upstream's only automatic exception
is the Steam Deck.

### Part of the window is off-screen

Two separate causes:

- GTK client-side decorations add shadow margins wider than the panel. Set
  `MOZ_GTK_TITLEBAR_DECORATION=none`.
- Gecko restores a **saved window position** from `xulstore.json` in the
  profile, and nothing under Lomiri constrains a bad one. Check it:

```sh
cat ~/.local/share/firefox.yourname/profile/xulstore.json
```

A negative `screenX` is the giveaway. Close Firefox, then either delete the file
or set `"sizemode":"maximized","screenX":"0","screenY":"0"`.

### Bookmarks and history disappear after an update

The profile is not being pinned. Check the launcher passes
`--profile ~/.local/share/<package>/profile`, and that `ut-profile-init` ran —
without it the directory does not exist and Gecko shows a modal error dialog
instead of a browser window.

Gecko otherwise picks a profile using the **install path**, which contains the
package version, so every upgrade looks like a fresh installation. Stale lock
files cause the same thing with no version change:

```sh
ls ~/.local/share/<package>/.config/mozilla/firefox/*/lock
```

## Two things that will waste your time

**Firefox cannot be launched from a terminal.** Mir refuses Wayland connections
from processes it did not start, so it must be started from the app grid. Over
ssh or adb it always fails with `we don't have any display`.

**Do not kill it with `pkill`.** Lomiri never sees a clean exit for an app it is
not managing, after which `lomiri-app-launch` silently fails to start anything
and `lomiri-app-stop` hangs. It also leaves stale profile locks, which is what
causes profiles to multiply. Close the app from the app switcher instead.

## Getting a real crash stack

Far quicker than guessing. Minidumps land in the profile:

```sh
ls ~/.local/share/<package>/profile/minidumps/
```

Copy one to a computer and symbolize it against Mozilla's public symbol server —
this works for official Firefox builds:

```sh
minidump-stackwalk --symbols-url=https://symbols.mozilla.org/ --human x.dmp
```

`minidump-stackwalk` comes from
[rust-minidump](https://github.com/rust-minidump/rust-minidump).
