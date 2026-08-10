# Fehlersuche

> **Hinweis zur Übersetzung:** Dieses Dokument wurde von einem KI-Assistenten aus
> dem Englischen übersetzt. Maßgeblich ist die englische Fassung
> [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Zuerst: überhaupt etwas sehen

Das Startskript schreibt nach stdout, was Lomiri mitschneidet:

```sh
journalctl --user -n 200 --no-pager | grep -iE "firefox|aa-exec"
```

Zeilen, die mit `firefox-ut:` beginnen, stammen aus dem Startskript und zeigen,
welche Pfade und welches Display gewählt wurden.

## Einstellungen ändern, ohne neu zu bauen

Das Startskript liest `~/.local/share/<paket>/ut-env.sh`, falls vorhanden. Damit
lässt sich die Umgebung direkt auf dem Gerät ändern:

```sh
cat > ~/.local/share/firefox.deinname/ut-env.sh <<'EOF'
export MOZ_LOG_FILE=/home/phablet/.local/share/firefox.deinname/ff.log
export MOZ_LOG="Widget:4"
exec 2> /home/phablet/.local/share/firefox.deinname/stderr.log
EOF
```

Shell-Umleitungen funktionieren, externe Befehle nicht (siehe unten).

**Diese Datei anschließend löschen.** Sie liegt im App-Speicher, nicht im
schreibgeschützten Paket, übersteht also Neuinstallationen und überschreibt
stillschweigend die mitgelieferte Konfiguration. Eine vergessene `ut-env.sh`
wird sehr leicht für einen Rückschritt gehalten.

Einstellungen lassen sich genauso ohne Neubau über eine `user.js` im Profil
ändern:

```sh
echo 'user_pref("layout.css.devPixelsPerPx", "2.5");' \
  >> ~/.local/share/firefox.deinname/profile/user.js
```

Firefox muss **geschlossen** sein, wenn im Profil etwas geändert wird — beim
Beenden wird `prefs.js` neu geschrieben und überschreibt die Änderung.

## Symptome

### Es passiert nichts, oder die App beendet sich sofort

Im Journal nach `exit 126` oder `Permission denied` mit einem Befehl wie
`readlink`, `dirname` oder `mkdir` suchen. Die Click-Sandbox hat keine
allgemeine Ausführungsregel für `/usr/bin`; ein Startskript, das irgendein
Systemprogramm aufruft, bricht sofort ab. Nur Shell-eigene Befehle verwenden.

### Das Fenster ist transparent, oder es ist nur der Hintergrund zu sehen

Vermutlich läuft die App unter Wayland statt unter XWayland. Prüfen mit:

```sh
journalctl --user -n 100 --no-pager | grep "firefox-ut: WAYLAND_DISPLAY"
```

Dort sollte `<unset>` stehen. Erscheint `wayland-0`, aktiviert etwas das
Wayland-Backend erneut — meist eine übrig gebliebene `ut-env.sh`.

Mir stellt die `wl_subsurface`, in die Gecko den Seiteninhalt zeichnet, nicht
dar; der native Wayland-Weg ergibt daher ein eingebundenes, gezeichnetes und
vollständig transparentes Fenster.

### Absturz etwa 0,2 Sekunden nach dem Start

Nach folgender Zeile suchen:

```
gtk_im_multicontext_set_context_id ... wl_proxy_get_version
```

Das ist `GTK_IM_MODULE=wayland` unter X11: GTK lädt `im-wayland.so`, das ohne
Wayland-Display in libwayland aufruft und einen Nullzeiger dereferenziert. Auf
dem X11-Weg muss der Wert `maliit` lauten, niemals `wayland`.

### Es erscheint keine Tastatur

```sh
journalctl --user -n 200 --no-pager | grep -iE "im-maliit|IM context"
```

- `im-maliit.so: cannot open shared object file` — GTK übergibt den Pfad aus
  `immodules.cache` direkt an `dlopen()`; das Paketverzeichnis muss deshalb in
  `LD_LIBRARY_PATH` stehen.
- `Loading IM context type 'maliit' failed` — das Modul wurde gefunden, ließ sich
  aber nicht laden; meist eine ABI-Abweichung zum GTK des Geräts.
- Gar keine Ausgabe — prüfen, ob `GTK_IM_MODULE` und `GTK_IM_MODULE_FILE` gesetzt
  sind.

Prüfen, ob Maliit selbst erreichbar ist:

```sh
gdbus call --session --dest org.maliit.server \
  --object-path /org/maliit/server/address \
  --method org.freedesktop.DBus.Properties.Get \
  org.maliit.Server.Address address
```

### Die Tastatur erscheint, aber Tippen bewirkt nichts

Mit hoher Wahrscheinlichkeit stimmt der Client-Objektpfad nicht. Er lautet
`/com/meego/inputmethod/inputcontext` — **ohne angehängte „1“** —, während die
Schnittstelle sehr wohl `com.meego.inputmethod.inputcontext1` heißt. Das Anzeigen
der Tastatur ist ein ausgehender Aufruf und funktioniert unabhängig davon;
Tastenanschläge kommen dagegen am exportierten Objekt an und werden verworfen,
wenn es nicht dort liegt, wo Maliit sie erwartet.

### Vorschläge ersetzen nichts, oder Text wird verdoppelt

`commitString` enthält einen Ersetzungsbereich, der vor dem Einfügen mit
`gtk_im_context_delete_surrounding()` angewendet werden muss. Wird er ignoriert,
hängt ein vervollständigtes Wort an das getippte an.

### Touch scrollt oder zoomt nicht

`MOZ_USE_XINPUT2=1` muss gesetzt sein. Ohne diese Variable ruft Gecko unter X11
`gdk_disable_multidevice()` auf und schaltet damit den Touchscreen ab; die
einzige automatische Ausnahme im Original ist das Steam Deck.

### Ein Teil des Fensters liegt außerhalb des Bildschirms

Zwei voneinander unabhängige Ursachen:

- GTKs clientseitige Fensterdekorationen fügen Schattenränder hinzu, die breiter
  als das Display sind. `MOZ_GTK_TITLEBAR_DECORATION=none` setzen.
- Gecko stellt eine **gespeicherte Fensterposition** aus der `xulstore.json` im
  Profil wieder her, und unter Lomiri begrenzt niemand einen ungünstigen Wert.
  Prüfen mit:

```sh
cat ~/.local/share/firefox.deinname/profile/xulstore.json
```

Ein negativer `screenX`-Wert ist das verräterische Zeichen. Firefox schließen und
die Datei entweder löschen oder auf
`"sizemode":"maximized","screenX":"0","screenY":"0"` setzen.

### Lesezeichen und Verlauf verschwinden nach einem Update

Das Profil wird nicht festgelegt. Prüfen, ob das Startskript
`--profile ~/.local/share/<paket>/profile` übergibt und ob `ut-profile-init`
ausgeführt wurde — ohne das Verzeichnis zeigt Gecko statt eines Browserfensters
einen modalen Fehlerdialog.

Andernfalls wählt Gecko das Profil über den **Installationspfad**, der die
Paketversion enthält; jedes Update sieht damit wie eine Neuinstallation aus.
Übrig gebliebene Sperrdateien bewirken dasselbe ohne Versionsänderung:

```sh
ls ~/.local/share/<paket>/.config/mozilla/firefox/*/lock
```

## Zwei Dinge, die Zeit kosten

**Firefox lässt sich nicht aus einem Terminal starten.** Mir verweigert
Wayland-Verbindungen von Prozessen, die es nicht selbst gestartet hat; der Start
muss über die App-Übersicht erfolgen. Über SSH oder ADB scheitert er stets mit
`we don't have any display`.

**Nicht mit `pkill` beenden.** Lomiri bekommt für eine nicht von ihm verwaltete
App kein sauberes Ende mit; danach schlägt `lomiri-app-launch` stillschweigend
fehl, und `lomiri-app-stop` hängt. Außerdem bleiben Profilsperren zurück, was zur
Vermehrung der Profile führt. Stattdessen die App über die App-Übersicht
schließen.

## Einen echten Absturz-Stack bekommen

Deutlich schneller als Raten. Minidumps landen im Profil:

```sh
ls ~/.local/share/<paket>/profile/minidumps/
```

Eine Datei auf einen Rechner kopieren und gegen Mozillas öffentlichen
Symbolserver auflösen — das funktioniert für offizielle Firefox-Builds:

```sh
minidump-stackwalk --symbols-url=https://symbols.mozilla.org/ --human x.dmp
```

`minidump-stackwalk` stammt aus
[rust-minidump](https://github.com/rust-minidump/rust-minidump).
