# Firefox für Ubuntu Touch

> **Hinweis zur Übersetzung:** Dieses Dokument wurde von einem KI-Assistenten aus
> dem Englischen übersetzt. Maßgeblich ist die englische Fassung
> [README.md](README.md). Bei Widersprüchen oder Unklarheiten gilt das englische
> Original.

Paketiert **Mozillas offizielles Firefox** als Click-App für Ubuntu Touch 24.04,
mit funktionierender Bildschirmtastatur, Touch-Bedienung und mobilen
Seitenlayouts.

---

## Bitte zuerst lesen

**Getestet wurde ausschließlich auf einem Gerät: einem Volla Phone Plinius**
(Codename `ansuz`, Kanal `24.04-1.x/arm64/android9plus/stable`, Ubuntu 24.04.4).
Es gibt **keine Garantie, dass es auf anderen Geräten funktioniert**, auch nicht
auf anderen Telefonen mit Ubuntu Touch 24.04.x.

Nichts davon ist bewusst gerätespezifisch, andere 24.04-arm64-Geräte haben also
durchaus Chancen — das ist jedoch eine Erwartung und kein Testergebnis. Zwei
Punkte können sich auf anderer Hardware besonders unterscheiden:

- die Bildschirmgröße, die den Skalierungswert in `prefs/ut-defaults.js`
  beeinflusst
- der Grafik-Stack, wo ein Gerät mit anderer GPU am ehesten abweichend reagiert

Dieses Projekt ist inoffiziell, steht in keiner Verbindung zu Mozilla oder
UBports und kommt ohne Gewährleistung oder Support.

## Was das ist — und was nicht

Es ist ein **Paketierungsprojekt**. Firefox selbst wird nicht verändert, geforkt
oder gepatcht: Das Click-Paket enthält Mozillas offiziellen
`linux-aarch64`-Build genau so, wie Mozilla ihn ausliefert. Ubuntu Touch 24.04
ist aarch64 mit glibc 2.39 — exakt das Ziel dieses Builds. Alle benötigten
Bibliotheken sind auf dem Gerät bereits vorhanden.

Zum Funktionieren gehören lediglich ein Startskript, eine Einstellungsdatei, ein
Click-Manifest und zwei kleine Programme, die **nicht Teil von Firefox** sind:

| Bestandteil | Aufgabe |
| --- | --- |
| `click/firefox-ut` | Startskript: setzt die unter Lomiri nötige Umgebung |
| `prefs/ut-defaults.js` | mobile Kennung, Touch, Zoom, Skalierung |
| `src/gtk-im-maliit/` | **GTK3-Eingabemethodenmodul für Maliit** — die Bildschirmtastatur |
| `src/ut-profile-init/` | ca. 90 Zeilen C, damit das Profil Updates übersteht |

Das Tastaturmodul ist der eigentlich interessante Teil und weit über Firefox
hinaus nützlich: Ubuntu Touch liefert einen Maliit-Eingabekontext **nur für Qt**
aus. Daher kann *keine GTK-Anwendung unter Ubuntu Touch die Bildschirmtastatur
öffnen*. Dieses Modul schließt die Lücke und sollte für jede GTK3-Anwendung
funktionieren. Siehe [src/gtk-im-maliit/README.md](src/gtk-im-maliit/README.md).

## Was funktioniert

- Vollbilddarstellung mit korrekter Fenstergeometrie
- Touch-Scrollen, Pinch-Zoom, Doppeltipp-Zoom
- Bildschirmtastatur inklusive Wortvorschlägen und Wortersetzung
- Mobile Seitenlayouts (Webseiten liefern ihre Handy-Versionen aus)
- Das Profil übersteht Updates — Lesezeichen und Verlauf bleiben erhalten

## Bekannte Einschränkungen

- Neben Firefox erscheint ein zweiter Eintrag namens **„X11 support“** in der
  App-Übersicht. Das ist rein kosmetisch: Firefox läuft über XWayland, und
  Lomiri zeigt den XWayland-Client als eigene App an.
- **Firefox läuft über XWayland, nicht nativ unter Wayland.** Mir stellt die
  `wl_subsurface` nicht dar, in die Gecko den Seiteninhalt zeichnet; nativ unter
  Wayland bleibt das Fenster deshalb transparent. Siehe
  [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).
- **Keine automatischen Updates.** Die Click-Nutzlast ist schreibgeschützt, der
  Updater wird entfernt. Für ein Update neu bauen und neu installieren.
- Die mobile Browser-Kennung steht als **feste Zeichenkette** in
  `prefs/ut-defaults.js` und folgt der Firefox-Version nicht automatisch. Beim
  Anheben der Firefox-Version bitte mit anpassen.
- Der Skalierungswert (`layout.css.devPixelsPerPx`, derzeit `2.0`) passt zu einem
  1080x2400-Display. Für andere Bildschirme anpassen.

## Auf das Telefon bringen

**Neu dabei? [BUILD_DE.md](BUILD_DE.md) lesen** — eine Schritt-für-Schritt-Anleitung
ohne vorausgesetzte Programmierkenntnisse. Nachfolgend die Kurzfassung.

Benötigt werden ein Computer, ein USB-Kabel und der eingeschaltete
Entwicklermodus (**Systemeinstellungen -> Info -> Entwicklermodus**). Es gibt
zwei Wege.

### Weg 1 — das fertige Paket installieren

Am schnellsten, benötigt nur `adb`. Es wird nichts kompiliert.

```sh
./install-release.sh                 # veröffentlichtes Paket holen
./install-release.sh datei.click     # oder eine vorhandene Datei installieren
```

### Weg 2 — selbst bauen

Benötigt `adb` **und Docker**. Dauert 10–20 Minuten, überwiegend Downloads.

```sh
./install.sh
```

In beiden Fällen prüft das Skript den Computer, findet das Telefon, liest dessen
Bildschirmgröße, zeigt an, was es tun wird, und fragt einmal nach. Einzugeben ist
lediglich **das Sperrbildschirm-Passwort des Telefons**, wenn das Telefon danach
fragt.

Danach **Firefox** über die App-Übersicht öffnen. Der Start muss über die
App-Übersicht erfolgen — aus einem Terminal heraus lässt Ubuntu Touch die App
nicht laufen.

Wird das Telefon nicht gefunden: [docs/CONNECTING_DE.md](docs/CONNECTING_DE.md).

Zum Entfernen:

```sh
adb shell -t -t "sudo click unregister --user=phablet firefox.ut"
```

### Den Bau anpassen

`install.sh` reicht diese Variablen an `build/build.sh` weiter, das sich auch
einzeln aufrufen lässt:

`FF_VERSION` (welche Firefox-Version), `PKG_NAME` (`<app>.<name>`; für den
OpenStore muss der Namensteil dem eigenen Konto entsprechen), `PKG_TITLE`,
`MAINTAINER`, `DPPX` (Bildschirmskalierung — wird automatisch vom Telefon
ermittelt).

## Weitergabe und Markenrechte

Das Build-Skript lädt Mozillas offizielles, **markenrechtlich geschütztes**
Firefox zur Bauzeit herunter; dieses Repository enthält weder Mozilla-Code noch
Mozilla-Binärdateien.

Wer das entstehende Click-Paket **weitergeben** möchte — etwa über den
OpenStore — sollte beachten, dass die Weitergabe offizieller Firefox-Binärdateien
unter dem Firefox-Namen und -Logo der
[Markenrichtlinie von Mozilla](https://www.mozilla.org/foundation/trademarks/policy/)
unterliegt und dass dieses Paket Standardeinstellungen verändert. Die Einhaltung
liegt in Ihrer Verantwortung. Für den Bau auf dem eigenen Telefon gilt das nicht.

## Lizenz

Der Code in diesem Repository — die Installationsskripte, die Paketierung und
die beiden C-Programme — steht unter **GPL-3.0-or-later**, siehe
[LICENSE](LICENSE).

Firefox selbst fällt **nicht** darunter und ist hier **nicht** enthalten. Es
gehört Mozilla, steht unter der MPL-2.0 und wird zur Bauzeit von Mozilla
heruntergeladen.

## Dokumentation

- [BUILD_DE.md](BUILD_DE.md) — Schritt-für-Schritt-Anleitung ohne Vorkenntnisse
- [docs/CONNECTING_DE.md](docs/CONNECTING_DE.md) — das Telefon mit dem Computer
  verbinden, falls der Installer es nicht findet
- [docs/HOW-IT-WORKS_DE.md](docs/HOW-IT-WORKS_DE.md) — warum jeder Bestandteil
  nötig ist und welche Ubuntu-Touch-Eigenheiten dahinterstecken
- [docs/TROUBLESHOOTING_DE.md](docs/TROUBLESHOOTING_DE.md) — Fehlersuche auf dem
  Gerät
- [CHANGELOG_DE.md](CHANGELOG_DE.md) — was gefunden und behoben wurde
- [src/gtk-im-maliit/README.md](src/gtk-im-maliit/README.md) — das Tastaturmodul
  und Maliits D-Bus-Protokoll

Das Modul-README (`src/gtk-im-maliit/README.md`) liegt nur auf Englisch vor,
da es sich an Entwickler richtet.
