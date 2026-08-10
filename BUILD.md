# Getting Firefox onto your Ubuntu Touch phone

*Deutsche Fassung: [BUILD_DE.md](BUILD_DE.md)*

A step-by-step guide. No programming knowledge needed. You will type a handful
of commands exactly as written, and your phone's password once.

**Before you start, read [the warning about which phones this was tested on](README.md#read-this-first).**

---

## What you need

- Your Ubuntu Touch phone
- A computer running Linux (or Windows with WSL2, or a Mac)
- **A USB cable that carries data** — many cheap cables only charge

## Which route?

There are two ways. **Route 1 works today.**

| | **Build it yourself** | **Ready-made package** |
| --- | --- | --- |
| Available | now | once packages are published |
| Time | 10-20 minutes | about 1 minute |
| Needs | `adb` **and Docker** | `adb` |

Follow **Route 1** unless a released package exists.

---

# Route 1 — build it yourself

Your computer downloads Mozilla's official Firefox and packages it. This needs
Docker, which is the only awkward part of this guide.

## Step 1: install `adb` and Docker

`adb` is the program that talks to your phone over USB. Open a terminal and run
the lines for your system:

```sh
sudo apt install adb docker.io        # Ubuntu, Debian, Mint
sudo dnf install android-tools docker # Fedora
sudo pacman -S android-tools docker   # Arch
```

Then allow your account to use Docker:

```sh
sudo usermod -aG docker $USER
```

**Now log out and log back in** (or restart the computer). This step is easy to
miss, and without it the installer will stop and tell you to do it.

Check it worked — this should print information, not an error:

```sh
docker info
```

## Step 2: prepare the phone

On the phone: **Settings → About → Developer Mode**, and switch it on. If it
asks you to set a lock-screen passcode first, do that — you will need the same
passcode in Step 4.

Now connect the phone to the computer with the USB cable. The phone will ask
whether to trust this computer. **Accept.**

## Step 3: get these files and run the installer

```sh
git clone https://github.com/TheSittingPenguin96/firefox-ut.git
cd firefox-ut
./install.sh
```

No `git`? Download the repository as a ZIP from its web page, unpack it, then
open a terminal in the unpacked folder and run `./install.sh` there.

It will:

1. check your computer has what it needs
2. find your phone and read its screen size
3. show you what it is about to do, and ask
4. download Mozilla's official Firefox (about 90 MB)
5. prepare a build container (about 400 MB, first time only)
6. build the app and copy it to the phone
7. install it

Steps 4 and 5 are the slow ones. **Nothing on your phone is changed until step
7**, and it asks before starting. Press **Enter** to accept.

## Step 4: type your phone's password

The phone asks for the passcode you unlock it with. Type it and press Enter.
Nothing appears as you type — that is normal.

## Step 5: open Firefox

Find **Firefox** in the app grid on the phone and tap it.

> It must be started from the app grid. Ubuntu Touch will not let it start from
> a terminal — that is a rule of the system, not a fault.

**Done.**

---

# Route 2 — a ready-made package

*This works only once packages have been published. If there are none yet, use
Route 1.*

Nothing is compiled, so Docker is not needed and it takes about a minute.

Install `adb` and prepare the phone exactly as in Route 1, Steps 1 and 2 —
but you can skip installing Docker. Then:

```sh
git clone https://github.com/TheSittingPenguin96/firefox-ut.git
cd firefox-ut
./install-release.sh
```

If you were given a package file directly, install that instead:

```sh
./install-release.sh some-file.click
```

Then type your phone's password and open Firefox from the app grid, exactly as
in Route 1, Steps 4 and 5.

## If something goes wrong

Nothing here damages the phone. Worst case, the app does not install and you
remove it or try again.

| What you see | What to do |
| --- | --- |
| "no phone detected over USB" | [docs/CONNECTING.md](docs/CONNECTING.md) |
| "phone not authorised" | Accept the prompt on the phone's screen |
| "insufficient USB permissions" | [docs/CONNECTING.md](docs/CONNECTING.md), section "no permissions" |
| "cannot use docker" | You missed the log-out-and-back-in after `usermod` |
| Firefox installed but misbehaves | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |

## Removing it again

```sh
adb shell -t -t "sudo click unregister --user=phablet firefox.ut"
```

## Updating later

Run the same installer again. Your bookmarks, history and settings are kept.

## What you actually installed

Mozilla's **official** Firefox for ARM64, unmodified, wrapped so Ubuntu Touch
can run it, with settings suited to a phone and an on-screen keyboard that
Ubuntu Touch is otherwise missing for this kind of app.

Firefox itself is not modified in any way. Details in
[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).
