# im-maliit — a GTK3 input method module for Maliit

Lets **GTK applications use Ubuntu Touch's on-screen keyboard**.

This is independent of Firefox. It lives in this tree only because the Firefox
port is what needed it first; it should work for any GTK3 app on Ubuntu Touch,
and it is deliberately written to be lifted out into its own project.

## Why this is needed

Lomiri's session sets `GTK_IM_MODULE=maliit`, but **no GTK module by that name
exists on the device** — Ubuntu Touch ships a Maliit input context for *Qt*
(`libmaliitplatforminputcontextplugin.so`) and nothing for GTK. So the variable
is vestigial and GTK apps simply never raise the keyboard.

The obvious alternative does not work either. GTK's `im-wayland.so` drives an
on-screen keyboard through the Wayland text-input protocol, but Mir on Ubuntu
Touch 24.04 does not implement it. A `WAYLAND_DEBUG=1` registry trace on a Volla
Phone Plinius shows the compositor advertising only:

```
android_wlegl  wl_compositor  wl_data_device_manager  wl_output  wl_seat
wl_shell  wl_shm  wl_subcompositor  xdg_wm_base  zxdg_shell_v6
```

No `zwp_text_input_v1/v2/v3`, no `zwp_input_method`.

This module therefore talks to Maliit over **D-Bus**, the same way the Qt plugin
does, which works on Wayland and through XWayland alike.

## Protocol

As implemented by `maliit-framework` 2.3.0:

| Step | Detail |
| --- | --- |
| Discover | session bus, `org.maliit.server`, object `/org/maliit/server/address`, property `org.maliit.Server.Address.address` |
| Connect | peer connection to that address, in practice `/run/user/<uid>/maliit-server` |
| Call | `com.meego.inputmethod.uiserver1` at `/com/meego/inputmethod/uiserver1` |
| Export | `com.meego.inputmethod.inputcontext1` at `/com/meego/inputmethod/inputcontext` |

Note the asymmetry in that last row: the **interface** ends in `1`, the
**object path** does not. maliit-framework registers the client adaptor at
`InputContextAdaptorPath` in `connection/dbusserverconnection.cpp`. Exporting at
`.../inputcontext1` still lets the keyboard appear — the show request is
outbound — but silently drops every `commitString` and `keyEvent` coming back.

Outbound: `activateContext`, `updateWidgetInformation`, `showInputMethod`,
`hideInputMethod`, `reset`.

Inbound: `commitString` and `updatePreedit` become GTK `commit` and
`preedit-changed`; `keyEvent` carries editing keys as **Qt::Key** values, which
are mapped to GDK keyvals and injected with `gdk_event_put()`. Methods with
return values (`preeditRectangle`, `selection`) must always be answered or the
server blocks.

Interface definitions:
<https://github.com/maliit/framework/tree/master/dbus_interfaces>

## Confinement

The peer socket is `/run/user/<uid>/maliit-server`, and Ubuntu Touch's click
AppArmor policy **already grants** `/{,var/}run/user/*/maliit-server rw` plus
D-Bus access to `org.maliit.server`. A confined click app needs no policy
changes and no new `policy_groups`.

## Building

```sh
./build.sh          # -> ~/build/firefox-ut/im-maliit/im-maliit.so
```

Cross-compiles for aarch64 using clang and the aarch64 sysroot that
`mach bootstrap` already provides (`~/.mozbuild/clang`,
`~/.mozbuild/sysroot-aarch64-linux-gnu`), so no extra toolchain is needed.
`-fuse-ld=lld` is required: the host `ld` cannot target aarch64.

Outside this tree, any aarch64 cross-toolchain with GTK3 headers works; the
module depends only on GTK3, GLib and GIO.

## Shipping it in a click

Put `im-maliit.so` in the click and point GTK at it:

```sh
export GTK_IM_MODULE=maliit
export GTK_IM_MODULE_FILE="$APP_DIR/immodules.cache"
```

with an `immodules.cache` of:

```
# GTK+ Input Method Modules file
"im-maliit.so"
"maliit" "Maliit" "gtk30" "" ""

```

The module path is left **relative** on purpose: GTK resolves it against the
directory containing the cache, which keeps the package relocatable and avoids
`click-review`'s `lint:hardcoded_paths` failure on `/opt/click.ubuntu.com/`.

## Status and limitations

Early. Known gaps:

- No surrounding-text or cursor-rectangle reporting, so Maliit cannot do
  word prediction or position itself around the caret. `updateWidgetInformation`
  sends only `focusState` and sensible defaults.
- `contentType` is always 0 (free text) — no email/number/URL keyboard layouts.
- Selection and copy/paste callbacks are acknowledged but ignored.
- Key events are injected with no modifier state.
- Only tested against maliit-framework 2.3.0 on Ubuntu Touch 24.04, aarch64.

## Licence

GPL-3.0-or-later. See the `LICENSE` file at the root of this repository.

This module is self-contained and has no Firefox dependency — it links only
against GTK3, GLib and GIO. If you want it for another GTK application on Ubuntu
Touch, take `im-maliit.c` and this README; nothing else here is needed.
