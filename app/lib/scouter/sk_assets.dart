import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'sk_protocol.dart';

/// The arm's asset store (VM.md §6.10, firmware 0.5.56 and later): data
/// blobs in its flash that survive a reboot and a new session. The app
/// keeps fonts, the drawing library and the resident program there and
/// brings them back into the arena with `ASSET_LOAD` in milliseconds
/// instead of uploading them over Bluetooth every time.
class SkAssets {
  /// An asset's ID: the first 16 bytes of the SHA-256 of its body.
  static Uint8List id(List<int> body) =>
      Uint8List.fromList(sha256.convert(body).bytes.sublist(0, 16));

  static String hex(List<int> id) =>
      id.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Asset types (the arm keeps them but ignores them).
  static const typeFont = 1;
  static const typeRaw = 4;

  /// Largest body.
  static const maxSize = 262144;

  /// Where the ID goes for `ASSET_LOAD` (the app's text area, unused while
  /// an arm is set up).
  static const idScratch = SkArena.text;

  /// The first firmware with the store.
  static bool supported(String version) {
    final v = version.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (v.length < 3) {
      v.add(0);
    }
    return v[0] > 0 || v[1] > 5 || (v[1] == 5 && v[2] >= 56);
  }

  /// Host code that loads the asset [id] (of [n] bytes) into [dst].
  static Uint8List loadCode(Uint8List id, int dst, int n) {
    final code = SkCode()
      ..write(idScratch, id)
      ..op(SkOp.assetLoad, [idScratch, dst, 0, n]);
    return code.take();
  }

  /// The body of `ASSET_PUT`: the range [address]…+[size] of the arena,
  /// staged there already, is stored under [id].
  static List<int> putBody(Uint8List id, int address, int size, int type) {
    final b = ByteData(25);
    for (var i = 0; i < 16; i++) {
      b.setUint8(i, id[i]);
    }
    b
      ..setUint32(16, address, Endian.little)
      ..setUint32(20, size, Endian.little)
      ..setUint8(24, type);
    return b.buffer.asUint8List();
  }

  /// The IDs and sizes in an `ASSET_LIST` reply's body (0: total, 1:
  /// first, then 32-byte entries).
  static ({int total, List<({String id, int size})> entries}) parseList(
    Uint8List body,
  ) {
    if (body.length < 2) return (total: 0, entries: const []);
    final d = ByteData.sublistView(body);
    final entries = <({String id, int size})>[];
    for (var o = 2; o + 32 <= body.length; o += 32) {
      entries.add((
        id: hex(body.sublist(o, o + 16)),
        size: d.getUint32(o + 20, Endian.little),
      ));
    }
    return (total: body[0], entries: entries);
  }
}
