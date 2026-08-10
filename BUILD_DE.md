# Firefox auf das Ubuntu-Touch-Telefon bringen

> **Hinweis zur Übersetzung:** Dieses Dokument wurde von einem KI-Assistenten aus
> dem Englischen übersetzt. Maßgeblich ist die englische Fassung
> [BUILD.md](BUILD.md).

Eine Schritt-für-Schritt-Anleitung. Programmierkenntnisse sind nicht nötig. Es
werden einige Befehle genau so eingetippt, wie sie hier stehen, und einmal das
Passwort des Telefons.

**Bitte vorher den [Hinweis lesen, auf welchen Telefonen das getestet wurde](README_DE.md#bitte-zuerst-lesen).**

---

## Was gebraucht wird

- Das Ubuntu-Touch-Telefon
- Ein Computer mit Linux (oder Windows mit WSL2, oder ein Mac)
- **Ein USB-Kabel, das Daten überträgt** — viele billige Kabel laden nur

## Welcher Weg?

Es gibt zwei Wege. **Weg 1 funktioniert heute schon.**

| | **Selbst bauen** | **Fertiges Paket** |
| --- | --- | --- |
| Verfügbar | jetzt | sobald Pakete veröffentlicht sind |
| Dauer | 10–20 Minuten | etwa 1 Minute |
| Benötigt | `adb` **und Docker** | `adb` |

**Weg 1** verwenden, solange kein veröffentlichtes Paket existiert.

---

# Weg 1 — selbst bauen

Der Computer lädt Mozillas offizielles Firefox herunter und verpackt es. Dafür
wird Docker benötigt — der einzige etwas sperrige Teil dieser Anleitung.

## Schritt 1: `adb` und Docker installieren

`adb` ist das Programm, das über USB mit dem Telefon spricht. Ein Terminal
öffnen und die zum System passenden Zeilen ausführen:

```sh
sudo apt install adb docker.io        # Ubuntu, Debian, Mint
sudo dnf install android-tools docker # Fedora
sudo pacman -S android-tools docker   # Arch
```

Anschließend dem eigenen Konto die Docker-Nutzung erlauben:

```sh
sudo usermod -aG docker $USER
```

**Jetzt abmelden und wieder anmelden** (oder den Computer neu starten). Dieser
Schritt wird leicht übersehen; ohne ihn bricht der Installer ab und weist darauf
hin.

Prüfen, ob es geklappt hat — es sollten Informationen erscheinen, keine
Fehlermeldung:

```sh
docker info
```

## Schritt 2: das Telefon vorbereiten

Auf dem Telefon: **Systemeinstellungen → Info → Entwicklermodus** einschalten.
Falls zuerst ein Sperrbildschirm-Code verlangt wird, diesen einrichten — genau
dieser Code wird in Schritt 4 gebraucht.

Nun das Telefon per USB-Kabel mit dem Computer verbinden. Das Telefon fragt, ob
diesem Computer vertraut werden soll. **Bestätigen.**

## Schritt 3: Dateien holen und Installer starten

```sh
git clone https://github.com/TheSittingPenguin96/firefox-ut.git
cd firefox-ut
./install.sh
```

Kein `git` vorhanden? Das Repository auf seiner Webseite als ZIP herunterladen,
entpacken, im entpackten Ordner ein Terminal öffnen und dort `./install.sh`
ausführen.

Er wird:

1. prüfen, ob der Computer alles Nötige hat
2. das Telefon finden und dessen Bildschirmgröße auslesen
3. anzeigen, was er tun wird, und nachfragen
4. Mozillas offizielles Firefox herunterladen (etwa 90 MB)
5. einen Bau-Container vorbereiten (etwa 400 MB, nur beim ersten Mal)
6. die App bauen und auf das Telefon kopieren
7. sie installieren

Die Schritte 4 und 5 dauern am längsten. **Am Telefon wird bis Schritt 7 nichts
verändert**, und vorher wird nachgefragt. Mit **Enter** bestätigen.

## Schritt 4: das Passwort des Telefons eingeben

Das Telefon fragt nach dem Code, mit dem es entsperrt wird. Eingeben und Enter
drücken. Während der Eingabe erscheint nichts — das ist normal.

## Schritt 5: Firefox öffnen

**Firefox** in der App-Übersicht des Telefons suchen und antippen.

> Der Start muss über die App-Übersicht erfolgen. Aus einem Terminal heraus
> lässt Ubuntu Touch die App nicht starten — das ist eine Regel des Systems,
> kein Fehler.

**Fertig.**

---

# Weg 2 — ein fertiges Paket

*Das funktioniert erst, sobald Pakete veröffentlicht sind. Gibt es noch keine,
Weg 1 verwenden.*

Es wird nichts kompiliert, Docker ist also nicht nötig, und es dauert etwa eine
Minute.

`adb` installieren und das Telefon genau wie in Weg 1, Schritt 1 und 2,
vorbereiten — Docker kann dabei entfallen. Dann:

```sh
git clone https://github.com/TheSittingPenguin96/firefox-ut.git
cd firefox-ut
./install-release.sh
```

Wurde eine Paketdatei direkt übergeben, diese stattdessen installieren:

```sh
./install-release.sh datei.click
```

Anschließend das Passwort des Telefons eingeben und Firefox über die
App-Übersicht öffnen, genau wie in Weg 1, Schritt 4 und 5.

## Wenn etwas schiefgeht

Nichts davon beschädigt das Telefon. Schlimmstenfalls wird die App nicht
installiert und man entfernt sie oder versucht es erneut.

| Meldung | Was tun |
| --- | --- |
| „no phone detected over USB“ | [docs/CONNECTING_DE.md](docs/CONNECTING_DE.md) |
| „phone not authorised“ | Abfrage auf dem Bildschirm des Telefons bestätigen |
| „insufficient USB permissions“ | [docs/CONNECTING_DE.md](docs/CONNECTING_DE.md), Abschnitt „no permissions“ |
| „cannot use docker“ | Das Ab- und Anmelden nach `usermod` wurde übersprungen |
| Firefox läuft, verhält sich aber merkwürdig | [docs/TROUBLESHOOTING_DE.md](docs/TROUBLESHOOTING_DE.md) |

## Wieder entfernen

```sh
adb shell -t -t "sudo click unregister --user=phablet firefox.ut"
```

## Später aktualisieren

Einfach denselben Installer erneut ausführen. Lesezeichen, Verlauf und
Einstellungen bleiben erhalten.

## Was tatsächlich installiert wurde

Mozillas **offizielles** Firefox für ARM64, unverändert, so verpackt, dass
Ubuntu Touch es ausführen kann, mit für ein Telefon passenden Einstellungen und
einer Bildschirmtastatur, die Ubuntu Touch für diese Art von Anwendung sonst
nicht bereitstellt.

Firefox selbst wird in keiner Weise verändert. Einzelheiten in
[docs/HOW-IT-WORKS_DE.md](docs/HOW-IT-WORKS_DE.md).
