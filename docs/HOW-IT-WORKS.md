# How it works

*Deutsche Fassung: [HOW-IT-WORKS_DE.md](HOW-IT-WORKS_DE.md)*

Observed on a **Volla Phone Plinius** (`ansuz`), Ubuntu Touch 24.04.4,
channel `24.04-1.x/arm64/android9plus/stable`, aarch64, glibc 2.39, Lomiri/Mir,
1080x2400. Behaviour on other devices is untested.

Why each piece of this package exists, and the Ubuntu Touch behaviour behind it.



---

## The one-paragraph version

Firefox needs **no source changes** to run on Ubuntu Touch. Mozilla's official
`linux-aarch64` build runs as-is — UT 24.04 has GTK3 and glibc 2.39, exactly
what it targets, and `ldd` reports zero missing libraries. Everything that was
broken lived in **packaging, AppArmor confinement, and gaps in Ubuntu Touch's
own platform**. The single piece of new code this port required is a GTK input
method module for Maliit, because Ubuntu Touch ships one only for Qt.

---

## Things that look like blockers and are not

Save yourself the time; each of these was investigated and ruled out.

- **"Gecko won't run on UT."** It runs unmodified.
- **"You'll need to patch Firefox."** No Gecko patch is in this port.
- **"Building Firefox will be the hard part."** The aarch64 cross-build is a
  supported upstream configuration (`linux64-aarch64/opt` in
  `taskcluster/kinds/build/linux.yml`) and took 2h11m on a 2012 laptop.
- **"EGL/Mali is broken so you need software rendering."** Hardware rendering
  works. A startup segfault that looked like EGL was Gecko painting a modal
  profile-error dialog; fix the profile and the crash goes away. Software
  WebRender is *worse* here — it logs
  `RenderCompositorSWGL failed mapping default framebuffer`.
- **"Lomiri isn't managing the app."** `an app that's not in the Launcher
  model` and `AppMan is not managing` are normal — a known-good click logs them
  identically.
- **"Fix Wayland rendering to get the keyboard."** It would not help. See below.

## The real constraints

### Mir accepts no outside Wayland clients

Mir rejects connections from processes it did not start. The socket connects,
the handshake is refused, and Gecko reports
`we don't have any display, WAYLAND_DISPLAY='wayland-0'`.

**Firefox can only be tested as an installed click launched from the app grid.**
There is no shortcut. Do not `pkill` Gecko behind Lomiri's back either: Lomiri
never sees a clean exit for an app it is not managing, after which
`lomiri-app-launch` silently fails and `lomiri-app-stop` hangs. Recovering means
tapping the icon.

### Confinement forbids system utilities

The click AppArmor profile grants `mrklix` on the click payload and `mrwklix` on
`~/.local/share/<pkg>/`, but has **no general `/usr/bin/*` exec rule** — only
`qmlscene`, `qtchooser`, `cordova-ubuntu*` and `gst-plugin-scanner`. A launcher
that runs `readlink`, `dirname`, `mkdir`, `date` or `id` dies with
`Permission denied` and `exit 126`. The launcher here is **shell built-ins only**.

Writable paths are all `<xdg-base>/<package-name>/`. Note that
`lomiri-app-launch` sets `XDG_DATA_HOME` to the *unconfined* `~/.local/share`,
so recompute the XDG variables rather than trusting them.

### `--profile` does not create its directory

Gecko fails and raises a modal error dialog instead of a browser window. This is
**not** a confinement effect — it reproduces unconfined. Since the launcher also
cannot `mkdir`, the fix is to drop `--profile` and point `HOME` at the app's
confined storage: Gecko's *profile manager* takes a different code path and
creates the entire tree, `HOME` included.

### Mir does not display Gecko's content subsurface

Gecko draws page content into a `wl_subsurface`
(`widget/gtk/MozContainerWayland.cpp`). Mir maps it, accepts the buffer, and
never shows it — `TODO: wl_subsurface.visiblity not implemented`. With
client-side decorations the toplevel carries only the shadow, so the result is a
fully transparent window that looks like a crash but is not: the surface is
mapped, sized, buffered and painted.

**This port therefore runs Gecko through XWayland**, where no subsurface is
involved. `/usr/bin/Xwayland` and `/tmp/.X11-unix/X0` already exist on the
device and confinement permits the socket. Gecko confirms a real X window by
logging a non-zero `XID`.

### Mir implements no text-input protocol

A `WAYLAND_DEBUG=1` registry trace shows the compositor advertising only:

```
android_wlegl  wl_compositor  wl_data_device_manager  wl_output  wl_seat
wl_shell  wl_shm  wl_subcompositor  xdg_wm_base  zxdg_shell_v6
```

No `zwp_text_input_v1/v2/v3`, no `zwp_input_method`. **Fixing the subsurface
problem would have produced a rendering browser that still could not type.**
Check this before investing in Wayland work.

### Ubuntu Touch has no GTK input module for Maliit

Lomiri sets `GTK_IM_MODULE=maliit`, but only a *Qt5* input context exists on the
device. The variable is vestigial and no GTK application can raise the keyboard.
This port supplies the missing piece:
[`src/gtk-im-maliit/`](../src/gtk-im-maliit/) — a standalone GTK3 module
speaking Maliit's D-Bus protocol, useful to any GTK app on Ubuntu Touch.

Two traps when packaging it, both documented in its README:

- GTK passes the module path from `immodules.cache` **straight to `dlopen()`**;
  it does *not* resolve a relative path against the cache directory. Keep the
  name relative (absolute paths fail `click-review`'s `lint:hardcoded_paths`)
  and put the click directory on `LD_LIBRARY_PATH`.
- The Maliit client object path is `/com/meego/inputmethod/inputcontext` —
  **no trailing "1"**, though the interface has one. Getting this wrong lets the
  keyboard appear while silently dropping every keystroke.

### X11 needs touch and decorations dealt with explicitly

- **Touch.** Gecko calls `gdk_disable_multidevice()` on X11 unless
  `MOZ_USE_XINPUT2=1`, which disables the touchscreen. Upstream's only automatic
  exception is the Steam Deck (`toolkit/xre/nsAppRunner.cpp`). Touch arrives
  natively on Wayland, so this is purely a cost of the XWayland route.
- **`GTK_IM_MODULE=wayland` segfaults under X11**, 0.16 s into startup, inside
  `gtk_im_multicontext_set_context_id` -> `wl_proxy_get_version` with no Wayland
  display. Never set it on this path.
- **Decorations.** GTK's client-side decorations add shadow margins (measured
  26px left and right), making the toplevel wider than the panel and pushing
  content off-screen. `MOZ_GTK_TITLEBAR_DECORATION=none` disables them; Lomiri
  manages windows anyway.

### Sites serve desktop layouts by default

Gecko derives its user agent from the platform, so Ubuntu Touch looks like
desktop Linux and Wikipedia never offers its mobile site.
`general.useragent.override` plus `dom.meta-viewport.enabled` fixes this; see
`prefs/ut-defaults.js`.
