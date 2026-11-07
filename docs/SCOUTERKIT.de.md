# ScouterKit (g1v0) statt Even-Firmware

[English](SCOUTERKIT.md) | **Deutsch**

[ScouterKit](https://github.com/mafik/scouter_kit) ist eine freie Ersatz-Firmware
(`g1v0`) für die beiden Bügel der Even G1. Die App kann mit
beiden Firmwares arbeiten: mit Evens eigener Firmware (Standard) oder mit g1v0.

> **Lies das ganz, bevor du etwas installierst.** Das Aufspielen von g1v0 lässt
> sich nicht ungeschehen machen, und ein Fehler kann einen Bügel unbrauchbar
> machen. Die App selbst flasht nichts: Das Installieren geschieht mit den
> Werkzeugen von ScouterKit, Schritt für Schritt von Hand.

## Was sich ändert

| | Even-Firmware | g1v0 (ScouterKit) |
| --- | --- | --- |
| Offizielle Even-App | ja | **nein** |
| Even-Dashboard, Even AI, Übersetzung, Navigation | ja | nein |
| Benachrichtigungen | eigene Anzeige der Brille | als Text der App, mit dem Symbol der App |
| Anzeige | 576 × 136 px, Text der Firmware, 5 Zeilen à ~30 Zeichen | 640 × 480 px, Text zeichnet die App, 11 Zeilen à 42 Zeichen (Standardhöhe) |
| Beide Augen gleichzeitig | nicht garantiert (die App prüft und schickt nach) | ja, beide zeichnen im selben Moment |
| Assist (Touchbar halten), Mikrofon | ja | ja (rechter Bügel, LC3 16 kbit/s wie bisher) |
| Tippen, Doppeltippen | ja | ja |
| Rechts gedrückt halten | Firmware (QuickNote) | eigene Geste für Home Assistant |
| Nicken, Kopfschütteln | nein | ja, einschaltbar (Gyrosensor des rechten Bügels) |
| Dreifach tippen = Ruhemodus | Firmware | die App merkt sich den Ruhemodus |
| Kopf heben (Dashboard) | Firmware | ein Programm auf den Bügeln zeigt das Dashboard selbst |
| Trageerkennung | an-/abschaltbar | immer an (Schalter hat keine Wirkung) |
| Helligkeit, automatische Helligkeit | ja | ja (links folgt dem rechten Lichtsensor) |
| Helligkeits-Offset | ja (Messung alle zwei Minuten) | ja (der Lichtsensor meldet Änderungen, solange etwas angezeigt wird) |
| Aufnahmepunkt | `o` oben rechts, abschaltbar | Quadrat der Firmware oben rechts im rechten Auge, solange das Mikrofon an ist |
| Anzeigehöhe | ja | verschiebt den Textblock; die Distanz hat keine Wirkung |
| Updates | über die Even-App | nur über ScouterKits Werkzeuge |

Liegt ein Bügel im Ladeetui, zeichnet die App auf ihm nichts: Leuchtende
Pixel stören die Ladeverbindung des Etuis (VM.md §6.6).

## Risiken (aus ScouterKits Anleitung, Stand 2026-11-05)

- **Kein Weg zurück zur jetzigen Firmware.** Zurück geht nur zu Evens
  öffentlicher 1.6.6 (oder 1.5.6, 1.3.6). Das Zurückspielen wurde im
  Emulator und auf einem Entwicklungsboard geprobt, **nicht auf einer echten
  Brille**. Dabei gehen Evens CJK-Schriften und Demo-Bilder verloren.
- **Ein Image, das Bluetooth nicht startet, macht den Bügel unbrauchbar.**
  Retten lässt er sich dann nur, indem man ihn öffnet und über den Debug-Port
  neu beschreibt. Das löscht den Bootloader und die Werkseinstellungen.
  Installiere nur Images, die ScouterKits Emulator-Tests bestanden haben
  (`scripts/gate.sh`).
- **Stromausfall während der ersten ~20 s** nach dem Bestätigen: Installiere
  nur mit geladenen Bügeln im Etui, das Etui am USB-Netzteil.
- Das Projekt ist **sehr jung**: Es wurde am 2026-11-05 veröffentlicht und an
  einem einzigen Brillenpaar entwickelt (beide Bügel mit Even 1.6.3). Mit
  aufgesetzter Brille wurde es kaum getestet.
- Die **Garantie** erlischt vermutlich.
- Im Ladeetui nimmt ein Bügel Befehle und Firmware von **jedem** Bluetooth-Gerät
  in der Nähe an (wie bei Even). Außerhalb des Etuis gehorcht er nur
  gekoppelten Geräten.

Punkte ohne Rückweg, in dieser Reihenfolge: (1) den PC mit den Bügeln koppeln
(das Handy verliert seine Kopplung), (2) die Installation auf dem linken Bügel
bestätigen, (3) dasselbe auf dem rechten.

## Vorher

1. **Firmware-Stand notieren.** In der Even-App unter Einstellungen → Über die
   Brille. Ist sie neuer als 1.6.6, ist sie nach dem Wechsel endgültig weg.
2. Beide Bügel und das Etui **voll laden**.
3. Die App ab Version 0.17.0 installieren (stabiler Kanal). Sie unterstützt
   beide Firmwares; mit Even-Firmware und der Einstellung „Even“ verhält sie
   sich wie bisher.

## Was du brauchst

- Einen **Linux-Rechner mit Bluetooth LE**, BlueZ 5.82 getestet. Windows und
  WSL gehen nicht, weil WSL kein Bluetooth hat. Es geht zum Beispiel mit einem
  Ubuntu-Live-USB-Stick auf einem PC mit Bluetooth, mit einem Raspberry Pi 4/5
  oder einem Linux-Notebook.
- Zum Bauen des Images: rootless podman, git, curl und etwa 4 GB Platz. Das
  Bauen geht auch auf einem anderen Linux-Rechner oder in WSL2. Das fertige
  Image `app_update.bin` kopierst du dann auf den Rechner mit Bluetooth.
- Python 3.10 oder neuer mit `bleak`, `Pillow` und `pyserial`.

## Installieren (nach ScouterKits `g1_firmware/README.md`)

Die Befehle laufen im Ordner `g1_firmware/` von ScouterKit. Maßgeblich ist
deren aktuelle Anleitung. Lies sie vor jedem Schritt nach, denn das Projekt
ändert sich schnell.

```bash
git clone https://github.com/mafik/scouter_kit && cd scouter_kit/g1_firmware
python3 -m venv .venv && .venv/bin/pip install -r ../tools/requirements.txt
scripts/setup.sh build            # einmal: Container, NCS, Evens 1.6.6-Images
scripts/build.sh 0.5.60           # Version wie in ScouterKits Anleitung
scripts/setup.sh emulator         # einmal
scripts/gate.sh 0.5.60 all        # ALLE Tests müssen bestehen
```

Dann, **einen Bügel nach dem anderen, links zuerst**:

1. Brille ins Etui, Deckel offen, Etui am USB. Bluetooth am Handy aus.
2. `bluetoothctl`: `agent NoInputNoOutput`, `default-agent`, `pairable on`,
   `scan le`, bis `Even G1_NN_L_…` erscheint (Adresse notieren), `scan off`,
   `pair LINKS_ADRESSE`, `quit`.
3. Prüfen, nichts wird geändert:
   `.venv/bin/python flash.py --ble LINKS_ADRESSE --stock list`
4. Installieren:
   `.venv/bin/python flash.py --ble LINKS_ADRESSE --stock --side L install work/build/g1v0-v0560/zephyr/app_update.bin`
   Das Werkzeug lädt das Image hoch (Even läuft weiter, Abbruch ist hier noch
   folgenlos) und fragt dann nach `yes`. **Erst dieses `yes` ist endgültig.**
   Den Bügel danach nicht aus dem Etui nehmen. Er meldet sich als `G1v0_L` mit
   einer **neuen Adresse**.
5. PC neu koppeln (im Etui): `bluetoothctl pairable on`, dann
   `.venv/bin/python ../tools/arm_pair.py NEUE_ADRESSE`.
6. Prüfen: `.venv/bin/python ../tools/g1host.py --ble NEUE_ADRESSE hello`
   zeigt `"proto": 5`. Mit `... grid --label LEFT --verify` erscheint ein
   Testgitter im linken Glas.
7. Rechter Bügel: Schritte 2–6 mit `--side R` und `--label RIGHT`.

Ein Bügel mit g1v0 neben einem mit Even-Firmware wird nicht unterstützt.
Mach beide, oder spiel den ersten zurück.

## Mit der App verbinden

1. In der App unter *Einstellungen → Brille* **ScouterKit** wählen, die App
   schließen und wieder öffnen.
2. Brille ins **offene Ladeetui** legen und *Nach Brillen suchen*. Die Bügel
   heißen `G1v0_L` / `G1v0_R`. Das Paar antippen.
3. Die App koppelt die Bügel nur, solange sie im Etui liegen. Ein Bügel
   speichert drei Kopplungen, der PC und das Handy passen beide hinein.
4. Beim ersten Verbinden nach jedem Neustart der Bügel lädt die App ihre
   Schrift in den Speicher der Bügel, das dauert ein paar Sekunden. Im
   Diagnose-Log steht `Schrift geladen`.

Zurück zu Even: In der App **Even** wählen, neu starten und die Brille in der
Even-App koppeln.

## Zurück zur Even-Firmware

```bash
scripts/fetch_stock.sh 1.6.6
.venv/bin/python flash.py --ble NEUE_LINKS_ADRESSE --side L restore 1.6.6
```

Danach den rechten Bügel genauso zurückspielen. Dann im PC die Kopplungen
entfernen (`bluetoothctl remove ADRESSE`) und die Brille in der Even-App neu
koppeln.

## Hilfe bei Problemen (Kurzfassung)

- **Bügel taucht nach der Installation nicht auf:** Lass ihn ein paar Minuten
  im Etui am USB liegen. Der Bootloader wiederholt einen unterbrochenen
  Kopiervorgang, ein Watchdog startet ihn neu.
- **Er heißt `G1v0S_L` / `G1v0S_R`:** Er ist im sicheren Modus (nach drei
  Fehlstarts). Die Anzeige ist aus, Updates gehen. Siehe ScouterKits Anleitung
  unter *Recovery*.
- **Die App verbindet sich außerhalb des Etuis nicht:** Der Bügel ist nicht mit
  dem Handy gekoppelt. Leg die Brille ins offene Etui und verbinde neu.
- **Das Mikrofon geht nicht:** g1v0 verlangt eine verschlüsselte Verbindung,
  also eine Kopplung, auch im Etui.

## Programm auf den Bügeln

Ist in Home Assistant das Dashboard beim Hochschauen eingestellt (oder sind
die Kopfgesten an), lädt die App beim Verbinden ein kleines Programm in jeden
Bügel und startet es (`VM_START`, VM.md §5). Es liegt im Bereich hinter dem
Bildpuffer (`0x35800`–`0x40000`) und läuft nur im Arbeitsspeicher; nach einem
Neustart des Bügels ist es weg, und die App lädt es neu.

- **Hochschauen** (`TILT`): Das Programm zeichnet die Dashboard-Zeilen, die die
  App vorher hineingeschrieben hat, Zeile für Zeile über einen eigenen
  Streifen und zeigt sie. Beim Runterschauen schaltet es die Anzeige ab. Es
  zeichnet nichts, solange die App selbst etwas anzeigt (`busy`). Neue Inhalte
  zeichnet es auf ein `USER0` der App neu, wenn das Dashboard gerade zu sehen
  ist. Den Kopf meldet der rechte Bügel mit `NOTIFY 1, 1/0`.
- **Kopfgesten** (rechter Bügel, `TIMER` alle 20 ms): Gyrosensor mit 52 Hz.
  Ein Schwung zählt ab 90 °/s und wenn er mindestens doppelt so schnell ist
  wie um die andere Achse; zwei Richtungswechsel um die x-Achse innerhalb von
  0,4 s sind ein Nicken, drei um die y-Achse ein Kopfschütteln
  (`NOTIFY 2, 1/2`).
- Das Programm wurde mit ScouterKits Interpreter (`src/vm`) geprüft: Hoch-
  und Runterschauen, belegte Anzeige, Nicken, Kopfschütteln, langsame und
  diagonale Bewegungen.

## Designs und Animationen

Mit der Schrift lädt die App eine kleine Bibliothek in jeden Bügel
(`app/lib/scouter/sk_lib.dart`, `0x3E000`–`0x3F400`). Pakete rufen sie mit
`CALL` auf:

- `box` zeichnet einen Rahmen mit abgeschrägten Ecken (zwei Pixel breit) in
  den Bildpuffer. Daraus entstehen die Dashboard-Designs, der Text beim
  Zuhören und die Statusmeldungen von Assist. Das Programm auf den Bügeln
  zeichnet dieselben Rahmen streifenweise aus Rechtecken; beide Wege ergeben
  im Interpreter dasselbe Bild.
- `scene` zeichnet ein Einzelbild einer Animation: einen Bereich löschen,
  den Rahmen, bis zu zwei Textzeilen, dann nur diesen Bereich zeigen
  (`DRAW`, etwa 10 ms). Die App schickt alle Bilder vorab als Pakete, die mit
  `SLEEP_UNTIL` auf ihre Zeit in der Uhr des jeweiligen Bügels warten. So
  laufen beide Augen mit 30 Bildern pro Sekunde gleichzeitig, unabhängig von
  der Funkverbindung (VM.md §7). Ein Bild kostet rund 70 Byte.
- `rects` zeichnet eine Liste von Rechtecken. Die Szene zeichnet eine feste
  Liste (Klammern und Leiste des Labor-Sets) vor ihrem Rahmen und eine
  wechselnde (Cursor, Scanline, eine dunkle Maske) nach ihren Texten; ein
  Bild kann auch nur die ersten Bytes eines Textes zeigen (Tippen). Der
  dunkle Titel des Labor-Dashboards ist Text der Stufe 0 auf einer hellen
  Leiste (`GLYPHS` im Modus `MASK`), in der App wie im Programm auf den
  Bügeln.

## Technik

Die App spricht Protokoll 5 von ScouterKit (`g1_firmware/docs/VM.md`):

- Dienst `f3da4d59-…4400`: `CMD` (Pakete mit Befehlen), `CTRL`
  (Steuerungsanfragen), `EVT` (Ereignisse).
- Pakete haben eine Sequenznummer. Die App schickt höchstens so viele, wie
  der Bügel freigegeben hat (32). Lücken, die die selektive Bestätigung
  meldet, und nach Zeitüberschreitung (RFC 6298) unbestätigte Pakete schickt
  sie erneut (`app/lib/scouter/sk_link.dart`).
- Text: Die App lädt einmal pro Sitzung die Schrift *Departure Mono*
  (OFL-Lizenz, 11 px, auf 22 px verdoppelt, nur lateinische Zeichen und
  Satzzeichen, 422 Zeichen in etwa 16 KB) in den Speicher jedes Bügels. Pro Text löscht
  `FILL` den Bildpuffer, `GLYPHS` zeichnet jede Zeile und `DRAW` zeigt das
  Bild auf einmal. Ausblenden schaltet die Anzeige mit `PANEL` = 0 ganz ab,
  denn auch ein schwarzes, eingeschaltetes Display braucht Strom.
- Ereignisse: Touchbar, Tragen, Akku und Etui kommen als `INPUT`. Die
  Kopfneigung meldet der rechte Bügel, sobald sie einen Bereich verlässt,
  den die App setzt.
- Mikrofon: `MIC` mit 16 kbit/s. Die Bügel geben es nach 2 s von selbst frei,
  deshalb erneuert die App die Freigabe alle 0,8 s.
- Beide Augen gleichzeitig: Die App misst den Uhrenversatz jedes Bügels mit
  `PING` (alle 3 Minuten), bereitet das Bild auf beiden vor und schickt dann
  jedem `SLEEP_UNTIL T` + `DRAW`, mit `T` in der Uhr des Bügels (VM.md §7).
- Helligkeit mit Offset: `AUTO_BRIGHTNESS` = 0, das `LIGHT`-Bit in `EVENTS`.
  Verlässt das Licht den Bereich ±25 % um die letzte Messung, rechnet die App
  die Stufe mit der Tabelle der Firmware aus und addiert den Offset.
- Eine neue *Epoche* bedeutet, dass der Bügel neu gestartet ist und sein
  Speicher leer ist. Die App richtet ihn dann neu ein und lädt die Schrift
  erneut.
