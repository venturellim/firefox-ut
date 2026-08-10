# Änderungsprotokoll

> **Hinweis zur Übersetzung:** Dieses Dokument wurde von einem KI-Assistenten aus
> dem Englischen übersetzt. Maßgeblich ist die englische Fassung
> [CHANGELOG.md](CHANGELOG.md).

Nur das, was für die Nutzung oder Anpassung dieses Pakets relevant ist. Der
ausführliche Weg dorthin steht hier nicht.

Getestet auf einem **Volla Phone Plinius** (`ansuz`), Ubuntu Touch 24.04.4,
arm64. Auf keinem anderen Gerät überprüft.

---

## 2026-08-09 — erste funktionierende Fassung

Firefox läuft unter Ubuntu Touch mit Darstellung, Touch-Bedienung,
Bildschirmtastatur und mobilen Seitenlayouts.

### Hinzugefügt

- **Ein GTK3-Eingabemethodenmodul für Maliit** (`src/gtk-im-maliit/`). Ubuntu
  Touch liefert einen Maliit-Eingabekontext nur für Qt aus, daher konnte keine
  GTK-Anwendung die Bildschirmtastatur öffnen. Lomiri setzt sogar
  `GTK_IM_MODULE=maliit`, ein solches GTK-Modul existiert auf dem Gerät jedoch
  nicht. Dieses Modul spricht Maliits D-Bus-Protokoll direkt und funktioniert
  unter Wayland wie unter XWayland. Einschließlich Wortvorschlägen und
  Wortersetzung.
- **Ein Profil-Hilfsprogramm** (`src/ut-profile-init/`), damit das Browserprofil
  Updates übersteht.
- Click-Paketierung, ein Lomiri-Startskript und Ubuntu-Touch-Voreinstellungen.

### Die Probleme, die gelöst werden mussten

Jedes davon ist eine echte Eigenheit von Ubuntu Touch, kein Firefox-Fehler:

- **Firefox aus dem OpenStore startet überhaupt nicht.** Es handelt sich um
  Mozillas *Snap*, und `snap-confine` kann auf dem Dateisystem von Ubuntu Touch
  kein `cap_dac_override` erlangen; die Sandbox bricht ab, bevor der Browser
  läuft. Das hat mit Firefox nichts zu tun — dieses Paket verzichtet vollständig
  auf Snap.
- **Die Click-Sandbox verbietet das Ausführen von Systemprogrammen.** Es gibt
  keine allgemeine Ausführungsregel für `/usr/bin`; ein Startskript, das
  `readlink`, `dirname` oder `mkdir` aufruft, bricht sofort ab. Das Startskript
  verwendet ausschließlich Shell-eigene Befehle — und weil es kein Verzeichnis
  anlegen kann, brauchte das Festlegen des Profils ein kleines kompiliertes
  Hilfsprogramm.
- **`lomiri-app-launch` setzt `XDG_DATA_HOME` auf einen Pfad, in den die Sandbox
  nicht schreiben lässt.** Das Startskript berechnet die XDG-Variablen unterhalb
  des Paketnamens neu.
- **`--profile` legt ein fehlendes Verzeichnis nicht an.** Gecko scheitert und
  zeigt statt eines Browserfensters einen modalen Fehlerdialog.
- **Mir stellt die `wl_subsurface` nicht dar, in die Gecko den Seiteninhalt
  zeichnet.** Das Fenster wird eingebunden, bemessen und gezeichnet — und ist
  vollständig transparent. Das Paket führt Firefox deshalb über **XWayland**
  aus, wo keine Subsurface beteiligt ist.
- **Mir implementiert kein Wayland-Protokoll für Texteingabe.** Eine Aufzeichnung
  mit `WAYLAND_DEBUG` zeigt weder `zwp_text_input_*` noch `zwp_input_method`;
  GTKs `im-wayland.so` kann daher ebenfalls nicht funktionieren. Deshalb musste
  die Tastatur gegen Maliits D-Bus-Schnittstelle geschrieben werden.
- **Gecko deaktiviert den Touchscreen unter X11.** Ohne `MOZ_USE_XINPUT2=1` ruft
  es `gdk_disable_multidevice()` auf; die einzige automatische Ausnahme im
  Original ist das Steam Deck. Ohne diese Variable gibt es weder Scrollen noch
  Zoomen.
- **Webseiten liefern Desktop-Layouts aus.** Gecko bildet seine Browser-Kennung
  aus der Plattform, wodurch Ubuntu Touch wie Desktop-Linux aussieht und
  Wikipedia nie seine mobile Fassung anbietet. Behoben durch das Überschreiben
  der Kennung und die Unterstützung von `meta viewport`.
- **Das Fenster wird teilweise außerhalb des Bildschirms gezeichnet.** Zwei
  Ursachen: GTKs clientseitige Fensterdekorationen fügen Schattenränder hinzu,
  die breiter als das Display sind, und Gecko stellt eine gespeicherte
  Fensterposition wieder her, die unter Lomiri niemand begrenzt. Die
  Dekorationen werden abgeschaltet, und das Hilfsprogramm legt eine sinnvolle
  Startgeometrie an.
- **Das Profil wurde immer wieder neu angelegt, samt Verlust von Lesezeichen und
  Verlauf.** Gecko wählt das Profil anhand des Installationspfads, der die
  Click-Version enthält — jedes Update sah deshalb wie eine Neuinstallation aus.
  Übrig gebliebene Sperrdateien lösten dasselbe ohne jede Versionsänderung aus.
  Das Startskript legt nun ein festes Profil fest.

### Hinweise für alle, die das anpassen

- Firefox wird **nicht verändert**. Wer erwägt, Mozillas Repository für eine
  Ubuntu-Touch-Portierung zu forken, braucht das höchstwahrscheinlich nicht.
- `GTK_IM_MODULE=wayland` lässt Firefox unter X11 **abstürzen**, rund 0,2
  Sekunden nach dem Start, im Eingabemethoden-Code von GTK. Auf dem X11-Weg
  niemals setzen.
- GTK übergibt den Modulpfad aus `immodules.cache` direkt an `dlopen()` und löst
  einen relativen Pfad nicht gegenüber dem Verzeichnis der Cache-Datei auf. Den
  Eintrag relativ halten — ein absoluter Pfad scheitert an `click-review` — und
  das Click-Verzeichnis in `LD_LIBRARY_PATH` aufnehmen.
- Maliits Client-Objektpfad lautet `/com/meego/inputmethod/inputcontext`,
  **ohne angehängte „1“**, obwohl die Schnittstelle
  `com.meego.inputmethod.inputcontext1` heißt. Wer das verwechselt, bekommt eine
  sichtbare Tastatur, deren Tastenanschläge allesamt verworfen werden.
- Apps lassen sich nicht aus einem Terminal testen. Mir verweigert
  Wayland-Verbindungen von Prozessen, die es nicht selbst gestartet hat; Firefox
  muss über die App-Übersicht gestartet werden.
- Firefox nicht mit `pkill` beenden. Lomiri bekommt für eine nicht von ihm
  verwaltete App kein sauberes Ende mit, danach schlägt jeder Start stillschweigend
  fehl — und die zurückbleibenden Profilsperren waren die Ursache für die oben
  beschriebene Profilvermehrung.
