# Changelog

*Deutsche Fassung: [CHANGELOG_DE.md](CHANGELOG_DE.md)*

Only the things that matter to someone using or adapting this package. The
blow-by-blow of how it was arrived at is not here.

Tested on a **Volla Phone Plinius** (`ansuz`), Ubuntu Touch 24.04.4, arm64.
Not verified on any other device.

---

## 2026-08-09 — first working version

Firefox runs on Ubuntu Touch with rendering, touch navigation, the on-screen
keyboard and mobile page layouts.

### Added

- **A GTK3 input method module for Maliit** (`src/gtk-im-maliit/`). Ubuntu Touch
  ships a Maliit input context for Qt only, so no GTK application could raise
  the on-screen keyboard. Lomiri even sets `GTK_IM_MODULE=maliit`, but no such
  GTK module exists on the device. This one speaks Maliit's D-Bus protocol
  directly and works on Wayland and XWayland alike. Includes word suggestions
  and word replacement.
- **A profile helper** (`src/ut-profile-init/`) so the browser profile survives
  upgrades.
- Click packaging, a Lomiri launcher, and Ubuntu Touch preference defaults.

### The problems that had to be solved

Each of these is a genuine Ubuntu Touch constraint, not a Firefox bug:

- **Firefox from the OpenStore never starts.** It is Mozilla's *snap*, and
  `snap-confine` cannot acquire `cap_dac_override` on Ubuntu Touch's root
  filesystem, so confinement aborts before the browser runs. Nothing to do with
  Firefox; this package avoids snap entirely.
- **Click confinement forbids running system utilities.** There is no general
  exec rule for `/usr/bin`, so a launcher calling `readlink`, `dirname` or
  `mkdir` dies immediately. The launcher uses shell built-ins only — and because
  it cannot create a directory, pinning the profile needed a small compiled
  helper.
- **`lomiri-app-launch` sets `XDG_DATA_HOME` to a path confinement forbids
  writing to.** The launcher recomputes the XDG variables under the package
  name.
- **`--profile` does not create a missing directory.** Gecko fails and shows a
  modal error dialog instead of a browser window.
- **Mir does not display the `wl_subsurface` Gecko draws page content into.**
  The window is mapped, sized and painted, and is completely transparent. The
  package therefore runs Firefox through **XWayland**, where no subsurface is
  involved.
- **Mir implements no text-input Wayland protocol.** A `WAYLAND_DEBUG` trace
  shows no `zwp_text_input_*` and no `zwp_input_method`, so GTK's `im-wayland.so`
  cannot work either. This is why the keyboard had to be written against
  Maliit's D-Bus interface.
- **Gecko disables the touchscreen on X11.** It calls
  `gdk_disable_multidevice()` unless `MOZ_USE_XINPUT2=1` is set; upstream's only
  automatic exception is the Steam Deck. Without it there is no scrolling or
  zooming.
- **Sites serve desktop layouts.** Gecko derives its user agent from the
  platform, so Ubuntu Touch looks like desktop Linux and Wikipedia never offers
  its mobile site. Fixed with a user-agent override plus meta-viewport support.
- **The window is drawn partly off-screen.** Two causes: GTK's client-side
  decorations add shadow margins wider than the panel, and Gecko restores a
  saved window position that nothing under Lomiri constrains. Decorations are
  disabled and the profile helper seeds a sane initial geometry.
- **The profile was recreated repeatedly, losing bookmarks and history.** Gecko
  selects a profile using the install path, which contains the click version, so
  every upgrade looked like a new installation. Stale lock files caused the same
  thing without any version change. The launcher now pins one fixed profile.

### Notes for anyone adapting this

- Firefox is **not modified**. If you are considering forking Mozilla's
  repository for an Ubuntu Touch port, you almost certainly do not need to.
- `GTK_IM_MODULE=wayland` **crashes** Firefox under X11, roughly 0.2 s into
  startup, inside GTK's input-method code. Do not set it on the X11 path.
- GTK passes the module path from `immodules.cache` straight to `dlopen()`; it
  does not resolve a relative path against the cache's directory. Keep the entry
  relative — an absolute path fails `click-review` — and put the click directory
  on `LD_LIBRARY_PATH`.
- Maliit's client object path is `/com/meego/inputmethod/inputcontext`, with
  **no trailing "1"**, even though the interface is
  `com.meego.inputmethod.inputcontext1`. Getting this wrong lets the keyboard
  appear while silently dropping every keystroke.
- Apps cannot be tested from a terminal. Mir refuses Wayland connections from
  processes it did not start, so Firefox must be launched from the app grid.
- Do not kill Firefox with `pkill`. Lomiri never sees a clean exit for an app it
  is not managing, after which launching silently fails — and the stale profile
  locks left behind were what caused the profile churn above.
