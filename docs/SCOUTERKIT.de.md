# ScouterKit (g1v0)

[English](SCOUTERKIT.md) | **Deutsch**

[ScouterKit](https://github.com/mafik/scouter_kit) ist eine freie Ersatz-Firmware
(`g1v0`) für die beiden Bügel der Even G1. Seit 0.25.0 arbeitet die App nur
noch mit g1v0. Brillen mit Evens eigener Firmware brauchen die App 0.24.x, die
letzte Version dafür; sie wird nicht mehr weiterentwickelt.

> **Lies das ganz, bevor du etwas installierst.** Das Aufspielen von g1v0 lässt
> sich nicht ungeschehen machen, und ein Fehler kann einen Bügel unbrauchbar
> machen. Die App selbst flasht nichts: Das Installieren geschieht mit den
> Werkzeugen von ScouterKit, Schritt für Schritt von Hand.

## Was sich gegenüber Evens Firmware ändert

| | Even-Firmware | g1v0 (ScouterKit) |
| --- | --- | --- |
| Offizielle Even-App | ja | **nein** |
| Even-Dashboard, Even AI, Übersetzung, Navigation | ja | nein |
| Benachrichtigungen | eigene Anzeige der Brille | als Text der App, mit dem Symbol der App |
| Anzeige | 576 × 136 px, 5 Zeilen à ~30 Zeichen | 640 × 480 px, Text zeichnet die App, 11 Zeilen à 42 Zeichen (Standardhöhe) |
| Beide Augen gleichzeitig | nicht garantiert | ja, beide zeichnen im selben Moment |
| Assist (Touchbar halten), Mikrofon | ja | ja (rechter Bügel, LC3 16 kbit/s wie bisher) |
| Tippen, Doppeltippen | ja | ja |
| Rechts gedrückt halten | Firmware (QuickNote) | eigene Geste für Home Assistant |
| Nicken, Kopfschütteln | nein | ja, einschaltbar (Gyrosensor des rechten Bügels) |
| Dreifach tippen = Ruhemodus | Firmware | die App merkt sich den Ruhemodus |
| Kopf heben (Dashboard) | Firmware | ein Programm auf den Bügeln zeigt das Dashboard selbst |
| Trageerkennung | an-/abschaltbar | immer an |
| Helligkeit, automatische Helligkeit | ja | ja (links folgt dem rechten Lichtsensor), mit Offset |
| Aufnahme | keine Anzeige | Quadrat der Firmware oben rechts im rechten Auge, solange das Mikrofon an ist |
| Anzeigehöhe und -distanz | beides | Höhe (verschiebt den Textblock) |
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
3. Die App installieren (0.25.0 oder neuer). Sie arbeitet nur mit g1v0; mit
   Evens Firmware verbindet sie sich nicht.

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

1. Brille ins **offene Ladeetui** legen und *Nach Brillen suchen*. Die Bügel
   heißen `G1v0_L` / `G1v0_R`. Das Paar antippen.
2. Die App koppelt die Bügel nur, solange sie im Etui liegen. Ein Bügel
   speichert drei Kopplungen, der PC und das Handy passen beide hinein.
3. Beim ersten Verbinden nach jedem Neustart der Bügel lädt die App ihre
   Schrift in den Speicher der Bügel, das dauert ein paar Sekunden. Im
   Diagnose-Log steht `Schrift geladen`.

## Zurück zur Even-Firmware

```bash
scripts/fetch_stock.sh 1.6.6
.venv/bin/python flash.py --ble NEUE_LINKS_ADRESSE --side L restore 1.6.6
```

Danach den rechten Bügel genauso zurückspielen. Dann im PC die Kopplungen
entfernen (`bluetoothctl remove ADRESSE`) und die Brille in der Even-App neu
koppeln. Mit Evens Firmware braucht diese App die Version 0.24.x (die neuere
vorher deinstallieren; Android installiert keine ältere Version über eine
neuere).

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
- **Uhr** (`TIMER`, `USER1`): Die App schreibt, wo die Ziffern `HH:MM` des
  Dashboards stehen, die Bügelzeit, zu der die aktuelle Minute begann, und
  welche Minute des Tages es ist. Das Programm zählt zu jeder vollen Minute
  weiter (auch ohne Handy), schreibt die Ziffern (Glyphen 0–9) und zeichnet
  neu, wenn das Dashboard zu sehen ist. Die App stellt die Zeit nach jedem
  Uhrenabgleich (alle 3 Minuten) neu.
- **Emojis**: Die Schrift auf den Bügeln hat nach ihren eigenen Glyphen 160
  leere Plätze. Enthält ein Text ein Emoji, kopiert die App dessen 1-Bit-Glyphe
  (Noto Emoji, 22 px, aus `app/assets/scouter/emoji_22.skf`) in einen freien
  Platz auf beiden Bügeln (rund 75 Byte) und kodiert das Emoji mit dieser
  Glyphe. So zeichnet `GLYPHS` es in der Zeile, in den Texten der App wie im
  Dashboard des Programms. Sind die Plätze voll, werden sie neu belegt.
- **Mikrofon und Hinweis** (`USER3`, rechter Bügel): Solange das Mikrofon
  an ist, zeichnet das Programm einen Ständer (Halterung, Stiel, Fuß) unter
  das 16 × 16 große Quadrat, das die Firmware bei (620, 4) zeichnet (VM.md
  §6.5, es lässt sich weder ändern noch ausblenden), auch nach einem
  `PANEL` = 0, das die Anzeige wegen des Mikrofons nicht ausschaltet. Ein
  Hinweis in der Schrift in Originalgröße (11 px, mit der 22-px-Schrift
  geladen) steht während einer Aufnahme auf der oberen Rahmenlinie.
- **Verbindungssymbole**: ein Handy und ein Server oben rechts am
  Dashboard (spiegelbildlich zum Aufnahme-Hinweis), mit `FILL` gezeichnet;
  `LINE` streicht den Server durch, solange die App Home Assistant als
  unerreichbar meldet (`USER2`), und beide, solange das eigene `LINK` des
  Bügels 0 ist. Es prüft alle 5 s erneut.
- **Wachhund** (alle 5 s): Jeder Bügel schaltet seine Anzeige ab, solange
  der Kopf unten ist und die App nichts zeigt (auch gleich nach einem
  Neustart, der das Bild der Anzeige stehen lässt), und der rechte Bügel
  wiederholt dem linken seinen Kopfzustand. Eine verlorene Nachricht oder ein
  Neustart heilt sich so binnen 5 Sekunden.
- **Beide Augen zusammen** (Funkverbindung der Bügel, VM.md §6.9): Nur der
  rechte Bügel folgt der Neigung. Bei einem Wechsel schickt er dem linken
  `PEER_SEND` 1 (hoch) oder 2 (runter) und schaltet 150 ms später; der
  `PEER`-Handler des linken schaltet zur Sendezeit plus denselben 150 ms
  (`PEER_T_US`). Zwei Bügel mit eigenen Sensoren sind sich so an der
  Schwelle nicht mehr uneinig. Firmware ohne die Verbindung (`HELLO`
  Trigger-Bit 9 nicht gesetzt): Jeder Bügel entscheidet selbst.
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
- Helligkeit mit Offset, auf der Brille: Das Programm des rechten Bügels
  behandelt `LIGHT` selbst. Verlässt das Licht den Bereich ±25 % (mindestens
  ±2 Lux) um die letzte Messung, rechnet es die Stufe mit der Tabelle der
  Firmware aus, addiert den Offset, begrenzt auf 0–42, schreibt `BRIGHTNESS`
  und setzt den nächsten Bereich; der Wachhund wiederholt das alle 5 s. Der
  linke Bügel läuft mit `AUTO_BRIGHTNESS` = 1 und übernimmt die Stufe des
  rechten über die Funkverbindung der Bügel (VM.md §6.9). Ein Handy braucht
  es dafür nicht. Firmware ohne die Verbindung: Die App macht es wie bisher
  aus den `LIGHT`-Ereignissen.
- Eine neue *Epoche* bedeutet, dass der Bügel neu gestartet ist und sein
  Speicher leer ist. Die App richtet ihn dann neu ein und lädt die Schrift
  erneut.
