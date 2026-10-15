# Even G1 ↔ Home Assistant – App

Flutter-App, die die Even Realities G1 per Bluetooth mit Home Assistant verbindet.
Einrichtung und Funktionsumfang: siehe [README im Hauptverzeichnis](../README.md).

## Aufbau

| Datei | Aufgabe |
| --- | --- |
| `lib/g1/protocol.dart` | BLE-Protokoll der G1 (Befehle, Pakete, Gesten) |
| `lib/g1/g1_connection.dart` | Verbindung zu beiden Bügeln, Request/Response, Heartbeat, Akku |
| `lib/g1/text_layout.dart` / `display.dart` | Zeilenumbruch, Seiten, automatisches/manuelles Blättern |
| `lib/ha/ha_client.dart` | Minimaler Home-Assistant-Websocket-Client |
| `lib/ha/assist_session.dart` | Ein Lauf der Assist-Pipeline (Audio → Antworttext) |
| `lib/bridge.dart` | Verbindet Brille und Home Assistant |
| `lib/ui/` | Status- und Einstellungsseite |
| `packages/lc3_codec/` | LC3-Decoder (liblc3) per `dart:ffi` |
