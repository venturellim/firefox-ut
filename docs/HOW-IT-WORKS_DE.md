# Wie es funktioniert

> **Hinweis zur Übersetzung:** Dieses Dokument wurde von einem KI-Assistenten aus
> dem Englischen übersetzt. Maßgeblich ist die englische Fassung
> [HOW-IT-WORKS.md](HOW-IT-WORKS.md).

Beobachtet auf einem **Volla Phone Plinius** (`ansuz`), Ubuntu Touch 24.04.4,
Kanal `24.04-1.x/arm64/android9plus/stable`, aarch64, glibc 2.39, Lomiri/Mir,
1080x2400. Das Verhalten auf anderen Geräten ist ungetestet.

Warum jeder Bestandteil dieses Pakets nötig ist und welches
Ubuntu-Touch-Verhalten dahintersteckt.

---

## Die Kurzfassung

Firefox braucht **keine Quellcode-Änderungen**, um unter Ubuntu Touch zu laufen.
Mozillas offizieller `linux-aarch64`-Build läuft unverändert — Ubuntu Touch 24.04
bringt GTK3 und glibc 2.39 mit, exakt das Ziel dieses Builds, und `ldd` meldet
**keine** fehlende Bibliothek. Alles, was nicht funktionierte, lag in der
**Paketierung, der Sandbox und in Lücken der Ubuntu-Touch-Plattform selbst**. Das
einzige neu geschriebene Stück Code ist ein GTK-Eingabemethodenmodul für Maliit,
weil Ubuntu Touch ein solches nur für Qt mitbringt.

## Was wie ein Hindernis aussieht, aber keines ist

Das spart Zeit; jeder Punkt wurde untersucht und ausgeschlossen.

- **„Gecko läuft nicht unter Ubuntu Touch.“** Es läuft unverändert.
- **„Firefox muss portiert oder stark gepatcht werden.“** In diesem Paket steckt
  kein einziger Gecko-Patch.
- **„Das Bauen von Firefox wird der schwierige Teil.“** Der
  aarch64-Cross-Build ist eine offiziell unterstützte Konfiguration und dauerte
  auf einem Laptop von 2012 rund 2 Stunden — er war am Ende gar nicht nötig.
- **„EGL/Mali ist kaputt, also braucht es Software-Rendering.“**
  Hardware-Rendering funktioniert. Ein Absturz beim Start, der nach EGL aussah,
  war Gecko beim Zeichnen eines modalen Profil-Fehlerdialogs. Software-WebRender
  ist hier sogar schlechter.
- **„Lomiri verwaltet die App nicht.“** Meldungen wie *„an app that's not in the
  Launcher model“* und *„AppMan is not managing“* sind normal — eine
  nachweislich funktionierende App protokolliert dasselbe.
- **„Wayland-Darstellung reparieren, dann kommt die Tastatur.“** Das würde nicht
  helfen; siehe unten.

## Die tatsächlichen Einschränkungen

### Mir nimmt keine fremden Wayland-Clients an

Mir weist Verbindungen von Prozessen ab, die es nicht selbst gestartet hat. Der
Socket verbindet sich, der Handshake wird abgelehnt, und Gecko meldet
`we don't have any display, WAYLAND_DISPLAY='wayland-0'`.

**Firefox lässt sich nur als installiertes Click testen, gestartet über die
App-Übersicht.** Einen Umweg gibt es nicht. Gecko außerdem nicht mit `pkill`
beenden: Lomiri bekommt für eine nicht von ihm verwaltete App kein sauberes Ende
mit, danach schlägt `lomiri-app-launch` stillschweigend fehl und
`lomiri-app-stop` hängt.

### Die Sandbox verbietet Systemprogramme

Das AppArmor-Profil erlaubt `mrklix` auf die Click-Nutzlast und `mrwklix` auf
`~/.local/share/<paket>/`, hat aber **keine allgemeine Ausführungsregel für
`/usr/bin`** — nur `qmlscene`, `qtchooser`, `cordova-ubuntu*` und
`gst-plugin-scanner`. Ein Startskript, das `readlink`, `dirname`, `mkdir`, `date`
oder `id` aufruft, stirbt mit `Permission denied` und `exit 126`. Das Startskript
hier nutzt **ausschließlich Shell-eigene Befehle**.

Beschreibbar sind ausschließlich Pfade unterhalb von
`<xdg-basis>/<paketname>/`. Zu beachten: `lomiri-app-launch` setzt
`XDG_DATA_HOME` auf das **unbeschränkte** `~/.local/share`, die XDG-Variablen
müssen also neu berechnet statt übernommen werden.

### `--profile` legt sein Verzeichnis nicht an

Gecko scheitert und zeigt statt eines Browserfensters einen modalen
Fehlerdialog. Das ist **kein** Effekt der Sandbox — es tritt auch ohne sie auf.
Da das Startskript zudem kein `mkdir` ausführen kann, lautet die Lösung: auf
`--profile` verzichten und `HOME` auf den abgeschotteten App-Speicher zeigen
lassen. Gecko legt über die *Profilverwaltung* den gesamten Baum an,
einschließlich `HOME`. (Dieses Paket legt das Profil dennoch fest und bringt dafür
ein kleines Hilfsprogramm mit, damit Updates keine Daten verlieren.)

### Mir stellt Geckos Inhalts-Subsurface nicht dar

Gecko zeichnet den Seiteninhalt in eine `wl_subsurface`. Mir bindet sie ein,
nimmt den Puffer an und zeigt sie nie an —
`TODO: wl_subsurface.visiblity not implemented`. Mit clientseitigen
Dekorationen trägt die Hauptfläche nur den Schatten; das Ergebnis ist ein völlig
transparentes Fenster, das wie ein Absturz aussieht, aber keiner ist: Die Fläche
ist eingebunden, bemessen, gepuffert und gezeichnet.

**Dieses Paket führt Gecko deshalb über XWayland aus**, wo keine Subsurface
beteiligt ist. `/usr/bin/Xwayland` und `/tmp/.X11-unix/X0` existieren auf dem
Gerät bereits, und die Sandbox erlaubt den Socket.

### Mir implementiert kein Texteingabe-Protokoll

Eine Registry-Aufzeichnung mit `WAYLAND_DEBUG=1` zeigt ausschließlich:

```
android_wlegl  wl_compositor  wl_data_device_manager  wl_output  wl_seat
wl_shell  wl_shm  wl_subcompositor  xdg_wm_base  zxdg_shell_v6
```

Kein `zwp_text_input_v1/v2/v3`, kein `zwp_input_method`. **Die Subsurface zu
reparieren hätte einen darstellenden Browser ergeben, in dem man weiterhin nicht
tippen kann.** Diesen Punkt prüfen, bevor man Arbeit in Wayland steckt.

### Ubuntu Touch hat kein GTK-Eingabemodul für Maliit

Lomiri setzt `GTK_IM_MODULE=maliit`, auf dem Gerät existiert jedoch nur ein
*Qt5*-Eingabekontext. Die Variable läuft ins Leere, und keine GTK-Anwendung kann
die Tastatur öffnen. Dieses Paket liefert das fehlende Stück:
[`src/gtk-im-maliit/`](../src/gtk-im-maliit/) — ein eigenständiges GTK3-Modul,
das Maliits D-Bus-Protokoll spricht und für jede GTK-App unter Ubuntu Touch
nützlich ist.

Zwei Fallstricke beim Paketieren, beide in dessen README beschrieben:

- GTK übergibt den Modulpfad aus `immodules.cache` **direkt an `dlopen()`** und
  löst einen relativen Pfad nicht gegenüber dem Cache-Verzeichnis auf. Den Namen
  relativ halten (absolute Pfade scheitern an `click-review`) und das
  Click-Verzeichnis in `LD_LIBRARY_PATH` aufnehmen.
- Maliits Client-Objektpfad lautet `/com/meego/inputmethod/inputcontext` —
  **ohne angehängte „1“**, obwohl die Schnittstelle eine trägt. Wer das
  verwechselt, sieht die Tastatur, verliert aber jeden Tastenanschlag.

### Unter X11 müssen Touch und Dekorationen ausdrücklich behandelt werden

- **Touch.** Gecko ruft unter X11 `gdk_disable_multidevice()` auf, sofern nicht
  `MOZ_USE_XINPUT2=1` gesetzt ist, und schaltet damit den Touchscreen ab. Die
  einzige automatische Ausnahme im Original ist das Steam Deck. Unter Wayland
  kommt Touch von selbst an; das ist also ein reiner Preis des XWayland-Wegs.
- **`GTK_IM_MODULE=wayland` stürzt unter X11 ab**, 0,16 Sekunden nach dem Start,
  in `gtk_im_multicontext_set_context_id` -> `wl_proxy_get_version` ohne
  Wayland-Display. Auf diesem Weg niemals setzen.
- **Dekorationen.** GTKs clientseitige Dekorationen fügen Schattenränder hinzu
  (gemessen 26 px links und rechts), wodurch die Fensterfläche breiter als das
  Display wird und Inhalt hinausragt. `MOZ_GTK_TITLEBAR_DECORATION=none`
  schaltet sie ab; Lomiri verwaltet die Fenster ohnehin selbst.

### Webseiten liefern standardmäßig Desktop-Layouts

Gecko bildet seine Browser-Kennung aus der Plattform, wodurch Ubuntu Touch wie
Desktop-Linux aussieht und Wikipedia nie seine mobile Fassung anbietet.
`general.useragent.override` zusammen mit `dom.meta-viewport.enabled` behebt das;
siehe `prefs/ut-defaults.js`.
