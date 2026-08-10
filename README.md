# Firefox for Ubuntu Touch

Packages **Mozilla's official Firefox** as a click app for Ubuntu Touch 24.04,
with the on-screen keyboard, touch navigation and mobile page layouts working.

*Deutsche Fassung: [README_DE.md](README_DE.md)*

---

## Read this first

**This has only been tested on one device: a Volla Phone Plinius**
(codename `ansuz`, channel `24.04-1.x/arm64/android9plus/stable`, Ubuntu
24.04.4). It is **not guaranteed to work on any other device**, including other
phones running Ubuntu Touch 24.04.x.

Nothing here is device-specific by design, so other 24.04 arm64 devices have a
fair chance of working — but that is an expectation, not a test result. Two
things in particular could differ on your hardware:

- the screen size, which affects the scale set in `prefs/ut-defaults.js`
- the graphics stack, which is where a device with a different GPU is most
  likely to behave differently

This is unofficial, unaffiliated with Mozilla and with UBports, and comes with
no warranty or support.

## What this is, and what it is not

It is a **packaging project**. Firefox itself is not modified, forked or
patched — the click contains Mozilla's official `linux-aarch64` build exactly as
they ship it. Ubuntu Touch 24.04 is aarch64 with glibc 2.39, which is precisely
what that build targets, so every library it needs is already on the device.

Everything that makes it work is a launcher script, a preferences file, a click
manifest, and two small programs that are **not part of Firefox**:

| Component | What it does |
| --- | --- |
| `click/firefox-ut` | launcher: sets the environment Firefox needs under Lomiri |
| `prefs/ut-defaults.js` | mobile user agent, touch, zoom, scaling |
| `src/gtk-im-maliit/` | **GTK3 input method module for Maliit** — the on-screen keyboard |
| `src/ut-profile-init/` | ~90 lines of C so the profile survives upgrades |

The keyboard module is the interesting part, and it is useful well beyond
Firefox: Ubuntu Touch ships a Maliit input context for **Qt only**, so *no GTK
application on Ubuntu Touch can raise the on-screen keyboard*. This module fills
that gap and should work for any GTK3 app. See
[src/gtk-im-maliit/README.md](src/gtk-im-maliit/README.md).

## What works

- Renders full screen, correct geometry
- Touch scrolling, pinch zoom, double-tap zoom
- On-screen keyboard, including word suggestions and word replacement
- Mobile page layouts (sites serve their phone versions)
- Profile survives upgrades — bookmarks and history are kept

## Known limitations

- A second entry named **"X11 support"** appears in the app switcher alongside
  Firefox. It is cosmetic. Firefox runs through XWayland, and Lomiri shows the
  XWayland client as its own app.
- **Firefox runs under XWayland, not natively on Wayland.** Mir does not display
  the `wl_subsurface` that Gecko draws page content into, so the native Wayland
  path produces a transparent window. See [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).
- **No automatic updates.** The click payload is read-only, so the updater is
  removed. Rebuild and reinstall to update.
- The mobile user agent is a **literal string** in `prefs/ut-defaults.js` and
  does not track the Firefox version. Update it when you bump Firefox.
- The scale (`layout.css.devPixelsPerPx`, currently `2.0`) suits a 1080x2400
  panel. Change it for a different screen.

## Getting it onto your phone

**New to this? Read [BUILD.md](BUILD.md)** — a step-by-step guide that assumes no
programming knowledge. The summary is below.

You need a computer, a USB cable, and Developer Mode switched on
(**Settings -> About -> Developer Mode**). There are two routes.

### Route 1 — install the ready-made app

Quickest, and needs only `adb`. Nothing is compiled.

```sh
./install-release.sh                 # fetch the published package
./install-release.sh some.click      # or install a file you already have
```

### Route 2 — build it yourself

Needs `adb` **and Docker**. Takes 10-20 minutes, mostly downloading.

```sh
./install.sh
```

Either way the script checks your computer, finds the phone, reads its screen
size, shows what it will do and asks once. The only thing you type is **your
phone's lock-screen password**, when the phone asks for it.

Then open **Firefox** from the app grid. It must be started from the app grid —
Ubuntu Touch will not let it run from a terminal.

If the phone is not found, see [docs/CONNECTING.md](docs/CONNECTING.md).

To remove it:

```sh
adb shell -t -t "sudo click unregister --user=phablet firefox.ut"
```

### Changing how it is built

`install.sh` passes these through to `build/build.sh`, which can also be run on
its own:

`FF_VERSION` (which Firefox release), `PKG_NAME` (`<app>.<name>`; for the
OpenStore this must match your account), `PKG_TITLE`, `MAINTAINER`, `DPPX`
(screen scale — worked out from the phone automatically).

## Redistribution and trademarks

The build script downloads Mozilla's official, **branded** Firefox at build
time; this repository contains no Mozilla code or binaries.

If you intend to **distribute** the resulting click — on the OpenStore, for
example — be aware that redistributing official Firefox binaries under the
Firefox name and logo is governed by
[Mozilla's trademark policy](https://www.mozilla.org/foundation/trademarks/policy/),
and that this package modifies default settings. Getting that right is your
responsibility. Building it for your own phone is not affected.

## Licence

The code in this repository — the installer scripts, the packaging, and the two
C programs — is **GPL-3.0-or-later**. See [LICENSE](LICENSE).

Firefox itself is **not** covered by that and is **not** included here. It is
Mozilla's, under the MPL-2.0, and is downloaded from Mozilla at build time.

## Documentation

- [BUILD.md](BUILD.md) — step-by-step guide for non-technical users
- [docs/CONNECTING.md](docs/CONNECTING.md) — getting your phone talking to your
  computer, if the installer cannot find it
- [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) — why each piece is needed, and
  the Ubuntu Touch constraints behind it
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — diagnosing problems on
  device
- [CHANGELOG.md](CHANGELOG.md) — what was found and fixed
- [src/gtk-im-maliit/README.md](src/gtk-im-maliit/README.md) — the keyboard
  module and Maliit's D-Bus protocol
