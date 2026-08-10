# Connecting your phone to your computer

*Deutsche Fassung: [CONNECTING_DE.md](CONNECTING_DE.md)*

`install.sh` talks to your phone over the USB cable. This page is only needed if
it says it cannot find your phone.

You do **not** need SSH, WiFi, or any network setup. Just the cable.

---

## The three things that must be true

### 1. A cable that carries data

Many USB cables only charge. If the phone charges but nothing else happens, try
a different cable — ideally the one that came with the phone.

### 2. Developer Mode is switched on

On the phone:

**Settings → About → Developer Mode → switch it on**

If you have no lock-screen passcode set, the phone will insist you set one
first. That passcode is also what you will type when the app is installed, so
pick something you can enter easily.

### 3. Your computer is trusted

The first time you connect, the phone shows a prompt asking whether to allow
this computer. Accept it. If you missed it, unplug and replug the cable.

## Installing the `adb` command

`install.sh` will tell you if this is missing.

| System | Command |
| --- | --- |
| Ubuntu, Debian, Mint | `sudo apt install adb` |
| Fedora | `sudo dnf install android-tools` |
| Arch | `sudo pacman -S android-tools` |
| macOS (Homebrew) | `brew install android-platform-tools` |
| Windows | Use WSL2 and follow the Ubuntu line above |

## Checking it worked

```sh
adb devices
```

A working connection looks like one of these:

```
List of devices attached
1234567890abcdef        device
```

```
List of devices attached
(no serial number)      device
```

The word **`device`** on the right is what matters. Some phones report no serial
number at all — that is normal and fine.

## When it does not work

### `unauthorized`

```
List of devices attached
1234567890abcdef        unauthorized
```

The phone has not been told to trust this computer. Look at the phone's screen
and accept the prompt. If no prompt appears, unplug and replug, or switch
Developer Mode off and on again.

### `no permissions`

```
List of devices attached
1234567890abcdef        no permissions; see [http://developer.android.com/tools/device.html]
```

This is a **Linux-only** problem: your user account is not allowed to talk to
the USB device. Fix it once, like this.

Find your phone's ID:

```sh
lsusb
```

Look for the line naming your phone, for example:

```
Bus 003 Device 035: ID 0e8d:201d MediaTek Inc. Volla Phone Plinius
```

The part before the colon (`0e8d` above) is the vendor ID. Create a rule using
your own value:

```sh
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/51-ubuntu-touch.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Then unplug the phone, plug it back in, and run `adb kill-server` followed by
`adb devices`.

### Nothing listed at all

- Try another cable, and another USB port.
- Check Developer Mode really is on — it can switch itself off after a system
  update.
- Restart the connection: `adb kill-server && adb devices`.
- Reboot the phone.

### `more than one device`

`install.sh` refuses to guess. Unplug any other phones, tablets or emulators.

## After the install

You do not need `adb` again unless you want to update or remove Firefox. It
changes nothing on the phone by itself.

To remove Firefox later:

```sh
adb shell -t -t "sudo click unregister --user=phablet firefox.ut"
```

## For developers

If you are debugging rather than installing, `adb shell` gives you a shell on
the phone, and the logs are in the journal:

```sh
adb shell "journalctl --user -n 200 --no-pager | grep -i firefox"
```

[TROUBLESHOOTING.md](TROUBLESHOOTING.md) covers what to look for. SSH over WiFi
is an alternative to `adb shell`, but nothing in this project requires it.
