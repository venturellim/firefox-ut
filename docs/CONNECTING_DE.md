# Das Telefon mit dem Computer verbinden

> **Hinweis zur Übersetzung:** Dieses Dokument wurde von einem KI-Assistenten aus
> dem Englischen übersetzt. Maßgeblich ist die englische Fassung
> [CONNECTING.md](CONNECTING.md).

`install.sh` spricht über das USB-Kabel mit dem Telefon. Diese Seite wird nur
gebraucht, wenn das Skript meldet, dass es kein Telefon findet.

SSH, WLAN oder sonstige Netzwerkeinrichtung sind **nicht** nötig. Nur das Kabel.

---

## Drei Voraussetzungen

### 1. Ein Kabel, das Daten überträgt

Viele USB-Kabel laden nur. Wenn das Telefon lädt, aber sonst nichts passiert, ein
anderes Kabel probieren — am besten das mitgelieferte.

### 2. Der Entwicklermodus ist eingeschaltet

Auf dem Telefon:

**Systemeinstellungen → Info → Entwicklermodus → einschalten**

Ist noch kein Sperrbildschirm-Code gesetzt, verlangt das Telefon zuerst einen.
Genau diesen Code gibt man später auch bei der Installation ein — also einen
wählen, der sich bequem eintippen lässt.

### 3. Der Computer ist als vertrauenswürdig bestätigt

Beim ersten Verbinden zeigt das Telefon eine Abfrage, ob diesem Computer vertraut
werden soll. Bestätigen. Wurde sie übersehen: Kabel abziehen und wieder
anstecken.

## Den Befehl `adb` installieren

`install.sh` meldet sich, falls er fehlt.

| System | Befehl |
| --- | --- |
| Ubuntu, Debian, Mint | `sudo apt install adb` |
| Fedora | `sudo dnf install android-tools` |
| Arch | `sudo pacman -S android-tools` |
| macOS (Homebrew) | `brew install android-platform-tools` |
| Windows | WSL2 verwenden und der Ubuntu-Zeile folgen |

## Prüfen, ob es geklappt hat

```sh
adb devices
```

Eine funktionierende Verbindung sieht so aus:

```
List of devices attached
1234567890abcdef        device
```

```
List of devices attached
(no serial number)      device
```

Entscheidend ist das Wort **`device`** rechts. Manche Telefone melden gar keine
Seriennummer — das ist normal und unproblematisch.

## Wenn es nicht funktioniert

### `unauthorized`

```
List of devices attached
1234567890abcdef        unauthorized
```

Dem Computer wurde noch nicht vertraut. Auf den Bildschirm des Telefons schauen
und die Abfrage bestätigen. Erscheint keine Abfrage: Kabel neu anstecken oder den
Entwicklermodus aus- und wieder einschalten.

### `no permissions`

```
List of devices attached
1234567890abcdef        no permissions; see [http://developer.android.com/tools/device.html]
```

Das ist ein Problem **nur unter Linux**: Das eigene Benutzerkonto darf nicht auf
das USB-Gerät zugreifen. Einmalig so beheben.

Die Kennung des Telefons ermitteln:

```sh
lsusb
```

Nach der Zeile mit dem Telefon suchen, zum Beispiel:

```
Bus 003 Device 035: ID 0e8d:201d MediaTek Inc. Volla Phone Plinius
```

Der Teil vor dem Doppelpunkt (oben `0e8d`) ist die Hersteller-Kennung. Mit dem
eigenen Wert eine Regel anlegen:

```sh
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/51-ubuntu-touch.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Anschließend das Telefon ab- und wieder anstecken, danach `adb kill-server` und
`adb devices` ausführen.

### Es wird überhaupt nichts angezeigt

- Ein anderes Kabel und einen anderen USB-Anschluss probieren.
- Prüfen, ob der Entwicklermodus wirklich an ist — nach einem Systemupdate kann
  er sich abschalten.
- Verbindung neu starten: `adb kill-server && adb devices`.
- Das Telefon neu starten.

### `more than one device`

`install.sh` rät nicht. Andere Telefone, Tablets oder Emulatoren abziehen.

## Nach der Installation

`adb` wird erst wieder gebraucht, wenn Firefox aktualisiert oder entfernt werden
soll. Von sich aus verändert es nichts am Telefon.

Firefox später entfernen:

```sh
adb shell -t -t "sudo click unregister --user=phablet firefox.ut"
```

## Für Entwickler

Wer nicht installiert, sondern Fehler sucht: `adb shell` öffnet eine Shell auf
dem Telefon, die Protokolle stehen im Journal:

```sh
adb shell "journalctl --user -n 200 --no-pager | grep -i firefox"
```

[TROUBLESHOOTING_DE.md](TROUBLESHOOTING_DE.md) beschreibt, worauf zu achten ist.
SSH über WLAN ist eine Alternative zu `adb shell`, für dieses Projekt aber
nirgends erforderlich.
