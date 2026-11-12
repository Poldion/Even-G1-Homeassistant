import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../g1/g1_connection.dart';
import '../g1/protocol.dart';
import '../l10n/l10n.dart';
import 'sk_anim.dart';
import 'sk_asm.dart';
import 'sk_clock.dart';
import 'sk_emoji.dart';
import 'sk_font.dart';
import 'sk_icons.dart';
import 'sk_lib.dart';
import 'sk_link.dart';
import 'sk_program.dart';
import 'sk_protocol.dart';
import 'sk_style.dart';
import 'sk_video.dart';

/// One arm running g1v0.
class _SkArm {
  _SkArm(this.side, this.device);

  final G1Side side;
  final BluetoothDevice? device;
  BluetoothCharacteristic? cmd;
  BluetoothCharacteristic? ctrl;
  StreamSubscription<List<int>>? evtSub;
  StreamSubscription<BluetoothConnectionState>? stateSub;
  late final SkLink link;
  bool ready = false;
  bool settingUp = false;
  bool probing = false;
  int mtu = 23;

  /// Epoch of the arm's session (VM.md §6.2); null before the first.
  int? epoch;

  /// The session [epoch] has this app's font in its arena.
  bool fontLoaded = false;
  SkHello? hello;

  int tag = 0;
  final Map<int, Completer<SkEvent>> replies = {};
  Future<void> writes = Future.value();

  /// Replaces the BLE writes in tests: channel 0 = CMD, 1 = CTRL.
  Future<void> Function(int channel, Uint8List data)? writeOverride;

  /// Offset of the arm's clock, for drawing both eyes at once.
  final SkClock clock = SkClock();

  /// The resident program runs (this session), with the gesture detector
  /// and its role on the arm-to-arm link (SkResident.peer*).
  bool resident = false;
  bool residentGestures = false;
  int residentPeer = 0;

  /// Address of the dashboard clock's digits in the program's text (0: the
  /// app filled in the time).
  int clockAt = 0;

  /// Icons in the arena of the current session.
  final Set<String> icons = {};

  /// Emojis (codepoints) in this session's font slots.
  final Set<int> emojis = {};

  int? battery;
  int? inCase;
  int? worn;
  int? caseLid;
}

/// Connection to G1 glasses whose arms run ScouterKit's g1v0 firmware
/// (github.com/mafik/scouter_kit) instead of Even's.
///
/// Offers what the app uses from [G1Connection]: texts are drawn with the
/// font in [fontAsset] (uploaded into each arm's memory once per session),
/// TouchBar gestures arrive as the same events as with Even's firmware
/// (long press = Assist, triple tap = silent mode, which the app keeps
/// itself), the right arm's microphone streams LC3 like Even's.
///
/// While an arm lies in the charging case nothing is drawn on it: lit pixels
/// disturb the case's charging link (VM.md §6.6, the library's PanelPolicy).
class ScouterConnection extends G1Connection {
  ScouterConnection({Future<SkFont> Function()? font})
    : _fontLoader = font ?? loadFont;

  /// Connection with simulated arms for tests: [write] receives every write
  /// (channel 0 = CMD, 1 = CTRL), [receive] feeds events.
  @visibleForTesting
  ScouterConnection.fake(
    Future<void> Function(G1Side side, int channel, Uint8List data) write, {
    required SkFont font,
  }) : _fontLoader = (() async => font) {
    _fake = true;
    for (final side in G1Side.values) {
      final arm = _newArm(side, null)
        ..writeOverride = (channel, data) => write(side, channel, data);
      _arms[side] = arm;
    }
  }

  static const fontAsset = 'assets/scouter/departure_mono_11.skf';

  static Future<SkFont>? _font;

  /// Departure Mono, 11 px drawn ×2 (22 px, 28 px per line, 14 px per
  /// character), only the characters [SkFont.textCodepoint] needs.
  /// The font at its own size (labels), the same glyph indices.
  static Future<SkFont> loadSmallFont() => _smallFont ??= rootBundle
      .load(fontAsset)
      .then(
        (d) =>
            SkFont.parse(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes))
                .scaled(1, keep: SkFont.textCodepoint),
      );
  static Future<SkFont>? _smallFont;

  static Future<SkFont> loadFont() => _font ??= rootBundle
      .load(fontAsset)
      .then(
        (d) =>
            SkFont.parse(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes))
                .scaled(2, keep: SkFont.textCodepoint),
      );

  final Future<SkFont> Function() _fontLoader;
  SkFont? _loadedFont;

  /// The text font with empty slots for emojis (SkEmoji).
  Future<SkFont> _textFont() async =>
      _loadedFont ??= (await _fontLoader()).withSlots(
        SkEmoji.slots,
        advance: SkEmoji.advance,
        slotBytes: SkEmoji.slotBytes,
      );

  /// Emoji codepoint → slot, the same on both arms.
  final Map<int, int> _emojiSlots = {};

  /// [text] ready to draw: emojis get a slot in the font (mapped for
  /// [SkFont.encode] and the width) and are copied into the slots of
  /// [arms] that miss them. When the slots run full they start over, and
  /// the dashboard on the arms is written again.
  Future<String> _emojify(String text, Iterable<_SkArm> arms) async {
    final font = await _textFont();
    final clean = SkEmoji.clean(text);
    final wanted = <int>{};
    SkFont? emoji;
    for (final cp in clean.runes) {
      // Text, and the private use area (the clock's placeholder).
      if (cp < 0x2190 || (cp >= 0xE000 && cp <= 0xF8FF)) continue;
      final g = font.glyphOrNull(cp);
      if (g != null && g < font.firstSlot) continue; // the text font's own
      emoji ??= await SkEmoji.load();
      if (emoji.glyphOrNull(cp) != null) wanted.add(cp);
    }
    if (wanted.isEmpty) return clean;
    final fresh = wanted.where((cp) => !_emojiSlots.containsKey(cp)).length;
    if (_emojiSlots.length + fresh > font.slotCount) {
      _emojiSlots.clear();
      font.unmapFrom(font.firstSlot);
      for (final a in _arms.values) {
        a.emojis.clear();
      }
      _debug(tr.skLogEmojiReset);
      for (final a in _arms.values.where((a) => a.ready && a.resident)) {
        if (!arms.contains(a)) unawaited(_writeDashboard(a, redraw: true));
      }
    }
    for (final cp in wanted) {
      final k = _emojiSlots.putIfAbsent(cp, () => _emojiSlots.length);
      font.map(cp, font.firstSlot + k);
    }
    for (final arm in arms) {
      final missing = wanted.where((cp) => !arm.emojis.contains(cp)).toList();
      if (missing.isEmpty) continue;
      final maxCode = arm.link.maxPacket - 2;
      final packets = <Uint8List>[];
      var code = SkCode();
      for (final cp in missing) {
        final g = emoji!.glyphData(emoji.glyphOrNull(cp)!);
        final at = font.slotAt(_emojiSlots[cp]!);
        final entry = ByteData(12)
          ..setUint32(0, at.bitmap * 8, Endian.little)
          ..setUint8(4, g.w)
          ..setUint8(5, g.h)
          ..setUint8(6, SkEmoji.advance)
          ..setInt16(8, g.xOff, Endian.little)
          ..setInt16(10, g.yOff, Endian.little);
        if (code.length + 10 + g.bits.length + 12 > maxCode) {
          packets.add(code.take());
          code = SkCode();
        }
        // The bitmap first, then the entry that points to it.
        code
          ..write(SkArena.font + at.bitmap, g.bits)
          ..write(SkArena.font + at.entry, entry.buffer.asUint8List());
      }
      if (code.length > 0) packets.add(code.take());
      if (await arm.link.run(packets)) arm.emojis.addAll(missing);
    }
    return clean;
  }

  SkFont? _loadedSmall;

  Future<SkFont> _small() async =>
      _loadedSmall ??= _fake ? await _fontLoader() : await loadSmallFont();
  bool _fake = false;
  bool _disposed = false;
  final Map<G1Side, _SkArm> _arms = {};
  bool _wanted = false;
  Timer? _reconnectTimer;
  Timer? _probeTimer;
  Timer? _batteryTimer;
  Timer? _micTimer;
  Timer? _clockTimer;
  bool _micOn = false;
  bool _fast = false;

  /// The navigation's arrow (SkIcons.navigation), sent with each text.
  Uint8List? _navigationIcon;

  @override
  void setNavigationIcon(Uint8List? icon) => _navigationIcon =
      icon != null && icon.length == SkIcons.bytes ? icon : null;

  /// A video plays (hidden player): nothing else draws meanwhile.
  bool _video = false;
  bool get videoPlaying => _video;
  bool _silent = false;
  bool _headUp = false;
  int _headUpAngle = 30;
  bool _caseNoted = false;

  /// Top of the text block on the panel, from the display height (0–8).
  int textTop = 140;

  static const textLeft = 24;
  static const textLevel = 15;

  /// Free rows kept below the text block.
  static const textBottom = 16;

  /// Pixel sizes of the bundled font (Departure Mono drawn ×2).
  static const _lineSpacing = 28;
  static const _advance = 14;

  int get _lineHeight => _loadedFont?.lineSpacing ?? _lineSpacing;

  /// Lines from [textTop] down to the panel's bottom (11 at the default
  /// height, instead of Even's 5).
  @override
  int get displayLines =>
      max(1, (SkPanel.height - textBottom - textTop) ~/ _lineHeight);

  /// The font is monospaced: 42 characters on the 640 px line.
  @override
  int get displayColumns => (SkPanel.width - 2 * textLeft) ~/ _advance;

  /// Left edge of the text beside a notification icon.
  static const iconTextLeft = textLeft + SkIcons.size + 12;

  static int _textWidth(String? icon) =>
      SkPanel.width - textLeft - (icon == null ? textLeft : iconTextLeft);

  @override
  Future<List<String>> layoutPages(String text, {String? icon}) async {
    final font = await _textFont();
    // Emojis need their slot (width) before the text is wrapped.
    final lines = wrap(font, await _emojify(text, const []), _textWidth(icon));
    if (lines.isEmpty) return [''];
    final n = displayLines;
    return [
      for (var i = 0; i < lines.length; i += n)
        lines.sublist(i, min(i + n, lines.length)).join('\n'),
    ];
  }

  @override
  String get firmwareName => 'ScouterKit (g1v0)';

  String? _armVersion(G1Side side) => _arms[side]?.hello?.version;

  /// Firmware of the arms, e.g. "ScouterKit g1v0 0.5.60", both when the arms
  /// differ.
  @override
  String? get firmwareVersion {
    final l = _armVersion(G1Side.left), r = _armVersion(G1Side.right);
    if (l == null && r == null) return null;
    if (l == r || r == null) return 'ScouterKit g1v0 $l';
    if (l == null) return 'ScouterKit g1v0 $r';
    return 'ScouterKit g1v0 L $l, R $r';
  }

  @override
  bool get connected => _arms.length == 2 && _arms.values.every((a) => a.ready);

  @override
  String get status {
    if (connected) return tr.g1StatusConnected;
    if (!_wanted && !_fake) return tr.g1StatusDisconnected;
    final l = _arms[G1Side.left]?.ready ?? false;
    final r = _arms[G1Side.right]?.ready ?? false;
    if (l || r) return tr.g1StatusConnectingOne(l ? 'L' : 'R');
    return tr.g1StatusConnecting;
  }

  void _debug(String message) => note(message);

  _SkArm _newArm(G1Side side, BluetoothDevice? device) {
    final arm = _SkArm(side, device);
    arm.link = SkLink(
      (packet) => _writeChannel(arm, 0, packet),
      log: (m) => _debug('${side.code}: $m'),
    );
    return arm;
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Scans for arms advertising as `G1v0_L` / `G1v0_R`, grouped by the pair
  /// ID of their scan response.
  static Stream<List<G1Pair>> scan({
    Duration timeout = const Duration(seconds: 15),
  }) {
    final pairs = <String, G1Pair>{};
    final controller = StreamController<List<G1Pair>>();
    late StreamSubscription<List<ScanResult>> sub;

    controller.onListen = () async {
      sub = FlutterBluePlus.onScanResults.listen((results) {
        var changed = false;
        for (final r in results) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          final ad = SkAdvert.parse(name, r.advertisementData.manufacturerData);
          if (ad == null) continue;
          final key = ad.pairId.isEmpty ? '?' : ad.pairId;
          final pair = pairs.putIfAbsent(key, () => G1Pair(key));
          final id = r.device.remoteId.str;
          final label = ad.safeMode ? '$name (sicherer Modus)' : name;
          if (ad.left && pair.leftId != id) {
            pair
              ..leftId = id
              ..leftName = label;
            changed = true;
          } else if (!ad.left && pair.rightId != id) {
            pair
              ..rightId = id
              ..rightName = label;
            changed = true;
          }
        }
        if (changed) controller.add(pairs.values.toList());
      });
      try {
        await FlutterBluePlus.startScan(
          timeout: timeout,
          withServices: [SkUuids.service],
          androidCheckLocationServices: false,
        );
        await FlutterBluePlus.isScanning.where((s) => !s).first;
      } catch (e) {
        controller.addError(e);
      }
      await sub.cancel();
      await controller.close();
    };
    controller.onCancel = () async {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    };
    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Connection handling
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String leftId, String rightId) async {
    await disconnect();
    _wanted = true;
    _arms[G1Side.left] = _newArm(G1Side.left, BluetoothDevice.fromId(leftId));
    _arms[G1Side.right] = _newArm(
      G1Side.right,
      BluetoothDevice.fromId(rightId),
    );
    notifyListeners();
    await Future.wait(_arms.values.map(_connectArm));
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
    _reconnectTimer?.cancel();
    _probeTimer?.cancel();
    _batteryTimer?.cancel();
    _micTimer?.cancel();
    _clockTimer?.cancel();
    _micOn = false;
    for (final arm in _arms.values) {
      await arm.stateSub?.cancel();
      await arm.evtSub?.cancel();
      _armDown(arm);
      arm.link.dispose();
      try {
        await arm.device?.disconnect();
      } catch (_) {}
    }
    if (!_fake) _arms.clear();
    notifyListeners();
  }

  void _armDown(_SkArm arm) {
    arm.ready = false;
    arm.settingUp = false;
    arm.probing = false;
    arm.link.down();
    for (final c in arm.replies.values) {
      if (!c.isCompleted) c.completeError(TimeoutException('link down'));
    }
    arm.replies.clear();
  }

  Future<void> _connectArm(_SkArm arm) async {
    final device = arm.device;
    if (device == null) return;
    arm.stateSub ??= device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected &&
          (arm.ready || arm.settingUp)) {
        _debug('${arm.side.name} arm disconnected');
        _armDown(arm);
        notifyListeners();
        _scheduleReconnect();
      }
    });
    try {
      _debug('connecting ${arm.side.name} arm (${device.remoteId})');
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 20),
        mtu: null,
      );
      if (Platform.isAndroid) {
        await device.requestMtu(247);
        await device.requestConnectionPriority(
          connectionPriorityRequest: _priority(arm),
        );
      }
      arm.mtu = device.mtuNow;
      final services = await device.discoverServices();
      final service = services.where((s) => s.uuid == SkUuids.service);
      if (service.isEmpty) {
        _debug(tr.skLogNoService(arm.side.name));
        throw StateError('no g1v0 service');
      }
      final chars = service.first.characteristics;
      arm.cmd = chars.firstWhere((c) => c.uuid == SkUuids.cmd);
      arm.ctrl = chars.firstWhere((c) => c.uuid == SkUuids.ctrl);
      final evt = chars.firstWhere((c) => c.uuid == SkUuids.evt);
      await arm.evtSub?.cancel();
      arm.evtSub = evt.onValueReceived.listen(
        (v) => _onEvent(arm, Uint8List.fromList(v)),
      );
      await evt.setNotifyValue(true);
      await _setup(arm);
    } catch (e) {
      _debug('connecting ${arm.side.name} arm failed: $e');
      _armDown(arm);
      notifyListeners();
      _scheduleReconnect();
    }
  }

  ConnectionPriority _priority(_SkArm arm) =>
      _fast || _video || (_micOn && arm.side == G1Side.right)
      ? ConnectionPriority.high
      : ConnectionPriority.balanced;

  void _scheduleReconnect() {
    if (!_wanted || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      for (final arm in _arms.values) {
        if (!arm.ready && !arm.settingUp && _wanted) {
          try {
            await arm.device?.disconnect();
          } catch (_) {}
          await _connectArm(arm);
        }
      }
    });
  }

  /// HELLO, the session (a new one uploads the font), the reported events
  /// and the arm's state.
  Future<void> _setup(_SkArm arm) async {
    if (arm.settingUp) return;
    arm.settingUp = true;
    try {
      final reply = await _ctrl(arm, SkCtrl.hello, const []);
      if (reply == null || reply.status != 0 || reply.body.length < 35) {
        await _explainNoAnswer(arm);
        throw StateError('no HELLO');
      }
      final hello = SkHello(reply.body);
      if (hello.protocol != 5) {
        _wanted = false;
        _debug(tr.skLogProtocol(arm.side.name, hello.protocol));
        throw StateError('protocol ${hello.protocol}');
      }
      arm.hello = hello;
      if (hello.left != (arm.side == G1Side.left)) {
        _debug(tr.skLogOtherArm(arm.side.name));
      }
      if (hello.safeMode) {
        _debug(tr.skLogSafeMode(arm.side.name));
      }
      await _ensureBond(arm, hello);

      final maxPacket = min(min(hello.maxPacket, arm.mtu - 3), 244);
      if (arm.epoch == reply.epoch && arm.fontLoaded) {
        // Same session: arena and window as the arm left them.
        arm.link.start(hello.rxNext, hello.execNext, hello.credits, maxPacket);
      } else {
        final reset = await _ctrl(arm, SkCtrl.resetSession, const [1]);
        if (reset == null || reset.status != 0 || reset.body.length < 37) {
          throw StateError('RESET_SESSION failed');
        }
        final h = SkHello(Uint8List.sublistView(reset.body, 2));
        arm.epoch = reset.epoch;
        arm.fontLoaded = false;
        arm.icons.clear();
        arm.emojis.clear();
        arm.clock.reset();
        arm.resident = false;
        arm.link.reset();
        arm.link.start(h.rxNext, h.execNext, h.credits, maxPacket);
        final font = await _textFont();
        final t0 = DateTime.now();
        final lib = SkLib.build();
        final ok = await arm.link.run([
          ...skUpload(SkArena.font, font.blob, maxPacket - 2),
          ...skUpload(SkArena.smallFont, (await _small()).blob, maxPacket - 2),
          // Frames and animations (SkLib), called by later packets.
          ...skUpload(SkLib.pool, lib.pool, maxPacket - 2),
          ...skUpload(SkLib.code, lib.code, maxPacket - 2),
        ]);
        if (!ok) throw StateError('font upload failed');
        arm.fontLoaded = true;
        _debug(
          tr.skLogFontLoaded(
            arm.side.code,
            font.blob.length,
            DateTime.now().difference(t0).inMilliseconds,
          ),
        );
      }
      await _reportEvents(arm);
      await _readState(arm);
      arm.ready = true;
      await _updateResident(arm);
      _debug(
        hello.encrypted
            ? tr.skLogArmReadyEncrypted(arm.side.name, hello.version)
            : tr.skLogArmReady(arm.side.name, hello.version),
      );
      notifyListeners();
      if (connected) _onBothConnected();
    } finally {
      arm.settingUp = false;
    }
  }

  /// Out of the case an arm obeys only a bonded, encrypted host and ignores
  /// everything else, so a missing answer usually means a missing bond.
  Future<void> _explainNoAnswer(_SkArm arm) async {
    final device = arm.device;
    if (device == null || !Platform.isAndroid) return;
    final bond = await device.bondState.first;
    if (bond != BluetoothBondState.bonded) {
      _debug(tr.skLogNoAnswerNotBonded(arm.side.name));
    }
  }

  /// Bonds only while the arm says it is bondable (in the charging case):
  /// a refused pairing attempt costs the arm's oldest bond (VM.md §6.1).
  Future<void> _ensureBond(_SkArm arm, SkHello hello) async {
    final device = arm.device;
    if (device == null || !Platform.isAndroid) return;
    final bond = await device.bondState.first;
    if (bond == BluetoothBondState.bonded) return;
    if (!hello.bondable) {
      _debug(tr.skLogNotBonded(arm.side.name));
      return;
    }
    _debug(tr.skLogBonding(arm.side.name));
    try {
      await device.createBond(timeout: 30);
    } catch (e) {
      _debug(tr.skLogBondFailed(arm.side.name, '$e'));
    }
  }

  int _eventMask(_SkArm arm) {
    var mask =
        1 << SkTrigger.touch |
        1 << SkTrigger.wear |
        1 << SkTrigger.battery |
        1 << SkTrigger.caseState;
    // The light sensor reports changes while the offset mode needs them.
    if (arm.side == G1Side.right && _offsetLevels != null && !_offsetOnArms) {
      mask |= 1 << SkTrigger.light;
    }
    // With the resident program the right arm reports the head's moves
    // itself (NOTIFY), and the program owns the tilt range.
    if (arm.side == G1Side.right && !arm.resident) {
      mask |= 1 << SkTrigger.tilt;
    }
    return mask;
  }

  Future<void> _reportEvents(_SkArm arm) async {
    final mask = _eventMask(arm);
    final r = await _ctrl(arm, SkCtrl.events, [mask & 0xff, mask >> 8]);
    if (r == null || r.status != 0) {
      _debug(tr.skLogEventsRejected(arm.side.code));
    }
    if (arm.side == G1Side.right && !arm.resident) {
      _headUp = false;
      await _setTiltRange(arm);
    }
  }

  // ---------------------------------------------------------------------------
  // Resident program (SkResident): dashboard on head up, head gestures
  // ---------------------------------------------------------------------------

  bool _dashboardOnHeadUp = false;
  String _dashboardText = '';
  G1TextStyle _dashboardStyle = G1TextStyle.plain;
  bool _headGestures = false;

  /// Bands of the dashboard as last written (SkResident.rows).
  int _residentRows = 0;

  /// The app reaches Home Assistant (status line otherwise).
  bool _haOnline = true;

  @override
  Future<void> setHomeAssistantOnline(bool online) async {
    if (online == _haOnline) return;
    _haOnline = online;
    for (final arm in _arms.values.where((a) => a.ready && a.resident)) {
      await arm.link.run([
        (SkCode()
              ..write(
                SkResident.haOffline.address,
                SkLib.u32s([online ? 0 : 1]),
              )
              ..raise(SkTrigger.user2))
            .take(),
      ]);
    }
  }

  @override
  bool get showsDashboardItself =>
      _dashboardOnHeadUp &&
      _arms.length == 2 &&
      _arms.values.every((a) => a.ready && a.resident);

  /// Plays the silent mode animation on both eyes at the same moment
  /// (SkAnimation); the panels are off again at its end.
  @override
  Future<void> playSilentModeAnimation(bool on, {bool lab = false}) async {
    if (_video) return;
    final font = await _textFont();
    final arms = _targets().where((a) => a.inCase != 1).toList();
    if (arms.isEmpty) return;
    final cx = SkPanel.width ~/ 2, cy = textTop + 2 * _lineHeight;
    final anim = switch ((on, lab)) {
      (true, false) => SkAnimation.sleep(font, cx: cx, cy: cy),
      (false, false) => SkAnimation.wake(font, cx: cx, cy: cy),
      (true, true) => SkAnimation.labSleep(font, cx: cx, cy: cy),
      (false, true) => SkAnimation.labWake(font, cx: cx, cy: cy),
    };
    final synced = arms.length == 2 && arms.every((a) => a.clock.known);
    // Time for the first packets to arrive before the first frame.
    final at = SkClock.hostNow() + _drawLeadUs(arms) + 150000;
    _debug(on ? tr.skLogAnimationOn : tr.skLogAnimationOff);
    await Future.wait(
      arms.map(
        (a) => a.link.run(
          anim.code(
            font,
            maxCode: a.link.maxPacket - 2,
            start: synced ? a.clock.toArm(at) : null,
          ),
        ),
      ),
    );
  }

  /// Plays a video on both eyes (the hidden player): [frames] frames of
  /// [width] × [height] at [fps], 1 bit per pixel ([SkVideoEncoder]),
  /// [read] gives [count] of them from [start] on. Each frame goes as a
  /// `VIDEO` record (VM.md §3.7) that both arms decode and show at the same
  /// moment; a frame the link cannot deliver in time is skipped.
  /// [onStart] runs when the first frame shows (the sound), [onProgress]
  /// after each frame, [stopped] ends the video early.
  Future<SkVideoEnd> playVideo({
    required int width,
    required int height,
    required double fps,
    required int frames,
    required Future<Uint8List> Function(int start, int count) read,
    void Function()? onStart,
    void Function(int frame, int skipped)? onProgress,
    bool Function()? stopped,
  }) async {
    final arms = _targets().where((a) => a.inCase != 1).toList();
    if (arms.isEmpty || _video) return SkVideoEnd.unavailable;
    if (arms.length == 2 && !arms.every((a) => a.clock.known)) {
      await _syncClocks();
    }
    if (!arms.every((a) => a.clock.known)) return SkVideoEnd.unavailable;
    _video = true;
    await _updatePriority();
    final layout = SkVideoLayout(width, height);
    final encoder = SkVideoEncoder(width, height);
    final maxCode = arms.map((a) => a.link.maxPacket).reduce(min) - 2;
    final frameBytes = encoder.stride * height;
    var end = SkVideoEnd.done;
    final inFlight = {for (final a in arms) a: 0};
    var failed = false;
    Timer? startTimer;
    try {
      // The app shows something (busy = 1, shown = 0): a black panel.
      final start =
          (SkCode()..write(SkResident.busy.address, const [
                1,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
              ]))
              .take();
      final ok = await Future.wait(
        arms.map((a) => a.link.run([start, layout.startCode()])),
      );
      if (!ok.every((r) => r)) return end = SkVideoEnd.failed;
      _debug(tr.skLogVideo('$width', '$height', fps.toStringAsFixed(1)));

      // Frames in batches, one batch ahead.
      const batch = 6;
      final pending = <int, Future<Uint8List>>{};
      Future<Uint8List> frameAt(int k) async {
        final first = k - k % batch;
        pending.removeWhere((b, _) => b < first);
        Future<Uint8List> load(int b) =>
            pending[b] ??= read(b, min(batch, frames - b));
        final data = load(first);
        if (first + batch < frames) load(first + batch);
        final bytes = await data;
        final o = (k - first) * frameBytes;
        if (bytes.length < o + frameBytes) return Uint8List(frameBytes);
        return Uint8List.sublistView(bytes, o, o + frameBytes);
      }

      final periodUs = 1e6 / fps;
      final leadUs = 400000 + _drawLeadUs(arms);
      final ahead = leadUs ~/ periodUs + 2;
      final t0 = SkClock.hostNow() + leadUs + 300000;
      int untilUs(int hostUs) =>
          ((hostUs - SkClock.hostNow()) & 0xffffffff).toSigned(32);
      Uint8List? shown;
      var skipped = 0, lastDue = t0;
      for (var k = 0; k < frames; k++) {
        if (failed) return end = SkVideoEnd.failed;
        if (stopped?.call() == true) return end = SkVideoEnd.stopped;
        final due = (t0 + (k * periodUs).round()) & 0xffffffff;
        final wait = untilUs(due) - leadUs;
        if (wait > 0) await Future.delayed(Duration(microseconds: wait));
        final waited = Stopwatch()..start();
        while (inFlight.values.any((n) => n >= ahead)) {
          if (failed) return end = SkVideoEnd.failed;
          if (waited.elapsed > const Duration(seconds: 10)) {
            return end = SkVideoEnd.failed;
          }
          await Future.delayed(const Duration(milliseconds: 3));
        }
        if (k == 0 && onStart != null) {
          startTimer = Timer(
            Duration(microseconds: max(0, untilUs(t0))),
            onStart,
          );
        }
        // Behind: on to the frame that is due now.
        if (shown != null && untilUs(due) < leadUs ~/ 2) {
          skipped++;
          onProgress?.call(k, skipped);
          continue;
        }
        final frame = await frameAt(k);
        if (shown != null && untilUs(due) < 0) {
          // Decoded too late.
          skipped++;
          onProgress?.call(k, skipped);
          continue;
        }
        if (shown != null && listEquals(frame, shown)) {
          onProgress?.call(k, skipped);
          continue;
        }
        final record = encoder.encode(
          frame,
          redraw: shown == null,
          maxBytes: SkVideoLayout.recordMax,
        );
        if (record == null) {
          skipped++;
          continue;
        }
        shown = frame;
        lastDue = due;
        for (final arm in arms) {
          inFlight[arm] = inFlight[arm]! + 1;
          arm.link
              .run(
                layout.frameCode(
                  record,
                  arm.clock.toArm(due),
                  maxCode: maxCode,
                ),
              )
              .then((ok) {
                inFlight[arm] = inFlight[arm]! - 1;
                if (!ok) failed = true;
              });
        }
        onProgress?.call(k, skipped);
      }
      // Until the last frame shows, and its packets are done.
      final left = untilUs(lastDue);
      if (left > 0) await Future.delayed(Duration(microseconds: left));
      final waited = Stopwatch()..start();
      while (inFlight.values.any((n) => n > 0) &&
          waited.elapsed < const Duration(seconds: 5)) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return end;
    } finally {
      if (end != SkVideoEnd.done) startTimer?.cancel();
      _video = false;
      _debug(tr.skLogVideoEnd(end.name));
      await _updatePriority();
      await blankScreen();
    }
  }

  /// The program always runs: clock, status line, microphone stand,
  /// keeping both eyes in step; the dashboard and the gestures are options.
  bool _wantsResident(_SkArm arm) => true;

  @override
  Future<void> setDashboard({
    required bool onHeadUp,
    required String text,
    G1TextStyle style = G1TextStyle.plain,
  }) async {
    final changed =
        onHeadUp != _dashboardOnHeadUp ||
        text != _dashboardText ||
        style != _dashboardStyle;
    _dashboardOnHeadUp = onHeadUp;
    _dashboardText = text;
    _dashboardStyle = style;
    if (!changed) return;
    for (final arm in _arms.values.where((a) => a.ready)) {
      if (arm.resident == _wantsResident(arm)) {
        if (arm.resident) await _writeDashboard(arm, redraw: true);
      } else {
        await _updateResident(arm);
      }
    }
    notifyListeners();
  }

  @override
  Future<void> setHeadGestures(bool enabled) async {
    if (enabled == _headGestures) return;
    _headGestures = enabled;
    final arm = _arms[G1Side.right];
    if (arm != null && arm.ready) await _updateResident(arm);
  }

  /// Starts, restarts (other variant) or stops the resident program.
  Future<void> _updateResident(_SkArm arm) async {
    final want = _wantsResident(arm);
    final gestures = _headGestures && arm.side == G1Side.right;
    if (!want) {
      if (arm.resident) {
        await _ctrl(arm, SkCtrl.vmStop, const []);
        arm.resident = false;
        _debug(tr.skLogProgramStopped(arm.side.code));
        await _reportEvents(arm);
      }
      return;
    }
    final peer = _peerRole(arm);
    if (arm.resident &&
        arm.residentGestures == gestures &&
        arm.residentPeer == peer) {
      await _writeDashboard(arm, redraw: true);
      return;
    }
    final font = await _textFont();
    final p = SkResident.build(
      gestures: gestures,
      peer: peer,
      micArm: arm.side == G1Side.right,
    );
    final maxCode = arm.link.maxPacket - 2;
    final ok = await arm.link.run([
      ...skUpload(SkResident.pool, p.pool, maxCode),
      ...skUpload(SkResident.code, p.code, maxCode),
      ...skUpload(SkResident.table, p.table, maxCode),
      _residentState(font),
      // The arms agree on the head over their own link (kept across
      // VM_START).
      if (peer != SkResident.peerNone)
        (SkCode()..sysWrite(SkProp.peerLink, 1)).take(),
    ]);
    if (!ok || !await _writeDashboard(arm)) {
      _debug(tr.skLogProgramNotLoaded(arm.side.code));
      return;
    }
    final t = SkResident.table;
    final r = await _ctrl(arm, SkCtrl.vmStart, [
      t & 0xff,
      t >> 8 & 0xff,
      t >> 16 & 0xff,
      t >> 24 & 0xff,
    ]);
    if (r == null || r.status != 0) {
      _debug(tr.skLogVmStartRejected(arm.side.code));
      return;
    }
    arm.resident = true;
    arm.residentGestures = gestures;
    arm.residentPeer = peer;
    _debug(
      gestures
          ? tr.skLogProgramRunningGestures(arm.side.code, p.code.length)
          : tr.skLogProgramRunning(arm.side.code, p.code.length),
    );
    await _reportEvents(arm);
    notifyListeners();
  }

  /// Both arms' firmware has the arm-to-arm message link (HELLO triggers
  /// bit 9): the right arm decides the head state for both.
  int _peerRole(_SkArm arm) {
    bool linked(_SkArm? a) =>
        a?.hello == null || (a!.hello!.triggers >> SkTrigger.peer) & 1 == 1;
    final other = _arms[arm.side == G1Side.left ? G1Side.right : G1Side.left];
    if (arm.hello == null || !linked(arm) || !linked(other)) {
      return SkResident.peerNone;
    }
    return arm.side == G1Side.right
        ? SkResident.peerLeader
        : SkResident.peerFollower;
  }

  /// Host code for the program's settings words.
  Uint8List _residentState(SkFont font) {
    final d = ByteData(40);
    void w(SkW word, int v) =>
        d.setUint32(word.address - SkResident.state, v, Endian.little);
    w(SkResident.angle, _headUpAngle);
    w(
      SkResident.flags,
      (_dashboardOnHeadUp ? SkResident.flagDashboard : 0) |
          (_headGestures ? SkResident.flagGestures : 0),
    );
    w(SkResident.left, textLeft);
    w(SkResident.ascent, font.ascent);
    w(SkResident.rows, _residentRows);
    w(SkResident.lineHeight, font.lineSpacing);
    // busy, shown, count, up stay as they are (bytes 0–15 not written).
    final code = SkCode()
      ..write(SkResident.angle.address, d.buffer.asUint8List(16, 24));
    return code.take();
  }

  /// Writes the dashboard's lines into the program's area; with [redraw]
  /// the program draws them again if they are shown (USER0).
  Future<bool> _writeDashboard(_SkArm arm, {bool redraw = false}) async {
    final font = await _textFont();
    final maxCode = arm.link.maxPacket - 2;
    // The program keeps the clock if this arm's time is known; "00:00"
    // holds the place of its digits.
    final raw = await _emojify(
      _dashboardText.isEmpty ? 'Home Assistant' : _dashboardText,
      [arm],
    );
    final ownClock = raw.contains(clockToken) && arm.clock.known;
    final bands = dashboardBands(
      font,
      ownClock
          ? withClock(raw.replaceFirst(clockToken, '00:00'))
          : withClock(raw),
      _dashboardStyle,
      top: textTop,
      rows: min(displayLines, SkResident.maxLines),
    );
    final text = BytesBuilder();
    final rects = <SkRect>[];
    final table = BytesBuilder();
    for (final band in bands) {
      final glyphs = band.text == null
          ? const <int>[]
          : font.encode(band.text!);
      final at = SkResident.text + text.length;
      if (at + glyphs.length > SkResident.textEnd) break;
      if (rects.length + band.rects.length > SkResident.maxRects) break;
      if (table.length ~/ (4 * SkResident.entryWords) >=
          SkResident.maxEntries) {
        break;
      }
      text.add(glyphs);
      table.add(
        SkLib.u32s([
          band.x,
          band.y,
          glyphs.isEmpty ? 0 : at,
          glyphs.length,
          rects.length,
          band.rects.length,
          band.level,
        ]),
      );
      rects.addAll(band.rects);
    }
    _residentRows = table.length ~/ (4 * SkResident.entryWords);
    // The clock's digits: the first "00:00" in the bands' texts.
    var clockAt = 0;
    if (ownClock) {
      var at = SkResident.text;
      for (final band in bands) {
        final t = band.text;
        if (t == null) continue;
        final i = t.indexOf('00:00');
        if (i >= 0) {
          clockAt = at + font.encode(t.substring(0, i)).length;
          break;
        }
        at += font.encode(t).length;
      }
    }
    arm.clockAt = clockAt;
    final status = dashboardStatusAt(
      font,
      raw,
      _dashboardStyle,
      top: textTop,
      rows: min(displayLines, SkResident.maxLines),
    );
    List<int> u32(int v) => [v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24];
    final codes = <Uint8List>[
      // No lines while they change, so the program never draws half of them.
      (SkCode()..write(SkResident.count.address, u32(0))).take(),
      ...skUpload(SkResident.text, text.toBytes(), maxCode),
      ...skUpload(SkResident.lines, table.toBytes(), maxCode),
      ...skUpload(
        SkResident.rects,
        Uint8List.fromList(
          SkLib.u32s([
            for (final r in rects) ...[r.x, r.y, r.w, r.h, r.level],
          ]),
        ),
        maxCode,
      ),
      _residentState(font),
      _clockCode(arm),
      ...await _labelCode(arm),
      (SkCode()
            ..write(
              SkResident.haOffline.address,
              // y 0 means none: the symbols need a row at least.
              SkLib.u32s([_haOnline ? 0 : 1, max(1, status.y), 0]),
            )
            ..write(
              SkResident.statusX.address,
              SkLib.u32s([status.x, status.ground]),
            )
            ..write(SkResident.statusInk.address, SkLib.u32s([status.ink])))
          .take(),
    ];
    final last = SkCode()..write(SkResident.count.address, u32(_residentRows));
    if (redraw) last.raise(SkTrigger.user0);
    codes.add(last.take());
    return arm.link.run(codes);
  }

  /// Host code that sets the program's clock: where its digits are, when
  /// the current minute began in [arm]'s time and which minute of the day
  /// it is; USER1 lets the program arm its timer for the next minute.
  Uint8List _clockCode(_SkArm arm) {
    final code = SkCode();
    if (arm.clockAt == 0 || !arm.clock.known) {
      code.write(SkResident.clockAt.address, SkLib.u32s([0]));
      return code.take();
    }
    final now = DateTime.now();
    final intoMinute =
        now.second * 1000000 + now.millisecond * 1000 + now.microsecond;
    final minuteStart = arm.clock.toArm(SkClock.hostNow() - intoMinute);
    code
      ..write(
        SkResident.clockAt.address,
        SkLib.u32s([arm.clockAt, minuteStart, now.hour * 60 + now.minute]),
      )
      ..raise(SkTrigger.user1);
    return code.take();
  }

  /// Sets the clocks again after a clock sync (drift, a new time zone), or
  /// writes the dashboard anew once the arm's time became known.
  Future<void> _refreshClocks() async {
    if (!_dashboardText.contains(clockToken)) return;
    for (final arm in _arms.values.where((a) => a.ready && a.resident)) {
      if (arm.clockAt == 0) {
        await _writeDashboard(arm, redraw: true);
      } else {
        await arm.link.run([_clockCode(arm)]);
      }
    }
  }

  /// Where the dashboard's label goes (see [SkLayout.labelAt]).
  static ({int x, int y}) dashboardLabelAt(
    SkFont font,
    String text,
    G1TextStyle style, {
    required int top,
    required int rows,
  }) => SkLayout.of(
    font,
    wrap(font, text, SkPanel.width - 2 * textLeft).take(rows).toList(),
    style,
    top: top,
    left: textLeft,
  ).labelAt(SkResident.labelH, left: textLeft, top: top);

  /// Where the connection symbols go with the dashboard: its top right.
  @visibleForTesting
  static ({int x, int y, int ground, int ink}) dashboardStatusAt(
    SkFont font,
    String text,
    G1TextStyle style, {
    required int top,
    required int rows,
  }) {
    final layout = SkLayout.of(
      font,
      wrap(font, text, SkPanel.width - 2 * textLeft).take(rows).toList(),
      style,
      top: top,
      left: textLeft,
    );
    final at = layout.statusAt(left: textLeft, top: top);
    final levels = layout.statusLevels;
    return (x: at.x, y: at.y, ground: levels.ground, ink: levels.ink);
  }

  /// The label shown with the dashboard (null: none).
  String? _dashboardLabel;

  @override
  Future<void> setDashboardLabel(String? label) async {
    if (label == _dashboardLabel) return;
    _dashboardLabel = label;
    for (final arm in _arms.values.where((a) => a.ready && a.resident)) {
      await arm.link.run([
        ...await _labelCode(arm),
        (SkCode()..raise(SkTrigger.user0)).take(),
      ]);
    }
  }

  /// Host code for the program's label words and glyphs.
  Future<List<Uint8List>> _labelCode(_SkArm arm) async {
    final font = await _textFont();
    final small = await _small();
    final label = _dashboardLabel;
    final glyphs = label == null ? const <int>[] : small.encode(label);
    final n = min(glyphs.length, SkResident.labelMax);
    final at = dashboardLabelAt(
      font,
      _dashboardText.isEmpty ? 'Home Assistant' : _dashboardText,
      _dashboardStyle,
      top: textTop,
      rows: min(displayLines, SkResident.maxLines),
    );
    return [
      if (n > 0)
        ...skUpload(
          SkResident.labelText,
          Uint8List.fromList(glyphs.sublist(0, n)),
          arm.link.maxPacket - 2,
        ),
      (SkCode()..write(
            SkResident.labelN.address,
            SkLib.u32s([
              n,
              at.x,
              at.y,
              label == null ? 0 : small.width(label) + 8,
              labelBase(small),
            ]),
          ))
          .take(),
    ];
  }

  /// The dashboard as the resident program draws it: bands of one line's
  /// height, each with its text and the frame cut to it. Bands without
  /// text come first, so the text bands drawn after them are not covered.
  @visibleForTesting
  static List<({int x, int y, String? text, List<SkRect> rects, int level})>
  dashboardBands(
    SkFont font,
    String text,
    G1TextStyle style, {
    required int top,
    required int rows,
  }) {
    final lh = font.lineSpacing;
    final layout = SkLayout.of(
      font,
      wrap(font, text, SkPanel.width - 2 * textLeft).take(rows).toList(),
      style,
      top: top,
      left: textLeft,
    );
    final decor = layout.decor;
    List<SkRect> cut(int y) => [for (final r in decor) ?r.clip(y, lh)];
    final bands =
        <({int x, int y, String? text, List<SkRect> rects, int level})>[];
    // Rows below the text that held lines before (cleared).
    final lines = layout.lines;
    var y = lines.isEmpty ? top : lines.last.y + lh;
    for (var i = lines.length; i < rows; i++, y += lh) {
      if (y + lh > SkPanel.height) break;
      bands.add((x: 0, y: y, text: null, rects: cut(y), level: 0));
    }
    // Frame, rule and brackets outside the text bands.
    final extra = <int>{
      if (decor.isNotEmpty) decor.map((r) => r.y).reduce(min),
      if (decor.isNotEmpty) decor.map((r) => r.bottom).reduce(max) - lh,
      // The gap below a title (card, title, lab).
      if (lines.length > 1 && lines[1].y > lines[0].y + lh) lines.first.y + lh,
      // Where a label may stand: redrawn when it goes away.
      layout.labelAt(SkResident.labelH, left: textLeft, top: top).y,
    };
    for (final e in extra) {
      if (e < 0 || lines.any((l) => l.y == e)) continue;
      bands.add((x: 0, y: e, text: null, rects: cut(e), level: 0));
    }
    for (final line in lines) {
      bands.add((
        x: line.x,
        y: line.y,
        text: line.text,
        rects: cut(line.y),
        level: line.level + (line.bold ? SkResident.bold : 0),
      ));
    }
    // The program composes the bands in the frame: each inside the panel.
    return [
      for (final b in bands)
        if (b.y >= 0 && b.y + lh <= SkPanel.height) b,
    ];
  }

  void _onNotify(_SkArm arm, int a, int b) {
    if (a == SkResident.notifyHead) {
      // Both arms see the head move; the right one reports it.
      if (arm.side != G1Side.right) return;
      _headUp = b == 1;
      _emit(arm.side, _headUp ? G1Event.headUp : G1Event.headDown);
      // The program drew the dashboard: the light sensor runs now.
      if (_headUp) _scheduleLightRead();
    } else if (a == SkResident.notifyGesture) {
      if (b == SkResident.nod) _emit(arm.side, G1Event.nod);
      if (b == SkResident.shake) _emit(arm.side, G1Event.headShake);
    }
  }

  Future<bool> _setTiltRange(_SkArm arm) {
    final code = SkCode();
    if (_headUp) {
      code
        ..sysWrite(SkProp.pitchLo, _headUpAngle - 10)
        ..sysWrite(SkProp.pitchHi, 90);
    } else {
      code
        ..sysWrite(SkProp.pitchLo, -90)
        ..sysWrite(SkProp.pitchHi, _headUpAngle);
    }
    return arm.link.run([code.take()]);
  }

  static const _stateProps = [
    SkProp.battPct,
    SkProp.inCase,
    SkProp.worn,
    SkProp.caseLid,
    SkProp.caseCharging,
    SkProp.caseBattPct,
    SkProp.brightness,
  ];

  Future<void> _readState(_SkArm arm) async {
    final values = await _props(arm, _stateProps);
    if (values == null) return;
    int? known(int v, int max) => v == SkProp.unknown || v > max ? null : v;
    arm.battery = known(values[0], 100);
    arm.inCase = known(values[1], 1);
    arm.worn = known(values[2], 1);
    arm.caseLid = known(values[3], 1);
    final caseCharging = known(values[4], 1);
    final caseBattery = known(values[5], 100);
    if (caseCharging != null) this.caseCharging = caseCharging == 1;
    if (caseBattery != null) batteryCase = caseBattery;
    final level = known(values[6], SkPanel.maxBrightness);
    if (level != null && arm.side == G1Side.right) {
      brightnessPercent = G1Brightness.percent(level);
    }
    _applyArmState();
  }

  void _applyArmState() {
    batteryLeft = _arms[G1Side.left]?.battery ?? batteryLeft;
    batteryRight = _arms[G1Side.right]?.battery ?? batteryRight;
    final arms = _arms.values;
    String? state;
    final inCase = arms.where((a) => a.inCase == 1);
    if (inCase.isNotEmpty) {
      state = inCase.any((a) => a.caseLid == 1) ? 'case_closed' : 'case_open';
    } else if (arms.any((a) => a.worn == 1)) {
      state = 'worn';
    } else if (arms.any((a) => a.worn == 0)) {
      state = 'not_worn';
    }
    if (state != null && state != wearState) {
      wearState = state;
      _debug(tr.g1LogWearState(state));
    }
    if (inCase.isEmpty) _caseNoted = false;
    notifyListeners();
  }

  void _onBothConnected() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _probe(),
    );
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshBattery(),
    );
    // The arms' clocks drift by up to ~130 ppm (VM.md §7).
    unawaited(_syncClocks());
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _syncClocks(rounds: 4),
    );
  }

  /// `PING` rounds on both arms for the clock model.
  Future<void> _syncClocks({int rounds = 8}) async {
    for (final arm in _arms.values) {
      for (var i = 0; i < rounds && arm.ready; i++) {
        final sent = SkClock.hostNow();
        final r = await _ctrl(
          arm,
          SkCtrl.ping,
          [sent & 0xff, sent >> 8 & 0xff, sent >> 16 & 0xff, sent >> 24 & 0xff],
          tries: 1,
          timeout: const Duration(milliseconds: 500),
        );
        final received = SkClock.hostNow();
        if (r == null || r.status != 0 || r.body.length < 12) continue;
        final d = ByteData.sublistView(r.body);
        if (d.getUint32(0, Endian.little) != sent) continue;
        arm.clock.add(
          sent: sent,
          armRx: d.getUint32(4, Endian.little),
          armTx: d.getUint32(8, Endian.little),
          received: received,
        );
      }
    }
    await _refreshClocks();
  }

  /// When both arms should draw: two connection intervals, the clocks'
  /// error and 15 ms for the arm (VM.md §7), at least 40 ms.
  int _drawLeadUs(Iterable<_SkArm> arms) {
    final interval = (_fast || _video || _micOn) ? 15000 : 50000;
    final error = arms.map((a) => a.clock.errorUs).fold(0, max);
    return max(40000, 2 * interval + error + 15000);
  }

  /// Packets wait but no ACK came for a while: the last one may be lost, so
  /// the window is asked for with HELLO (VM.md §6.2).
  Future<void> _probe() async {
    for (final arm in _arms.values) {
      if (!arm.ready || arm.probing || !arm.link.waiting) continue;
      if (DateTime.now().difference(arm.link.lastHeard) <
          const Duration(milliseconds: 400)) {
        continue;
      }
      arm.probing = true;
      try {
        final r = await _ctrl(arm, SkCtrl.hello, const []);
        if (r == null || r.status != 0 || r.body.length < 35) continue;
        if (r.epoch != arm.epoch) {
          _resync(arm);
          continue;
        }
        final h = SkHello(r.body);
        arm.link.onAck(h.rxNext, h.execNext, h.credits, 0);
      } finally {
        arm.probing = false;
      }
    }
  }

  /// The arm started a new session (a reboot): its memory is gone.
  void _resync(_SkArm arm) {
    if (arm.settingUp) return;
    _debug(tr.skLogNewSession(arm.side.name));
    arm.ready = false;
    arm.fontLoaded = false;
    arm.link.down();
    notifyListeners();
    unawaited(
      _setup(arm).catchError((Object e) {
        _debug(tr.skLogResetupFailed(arm.side.name, '$e'));
        _scheduleReconnect();
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Writes, control requests, events
  // ---------------------------------------------------------------------------

  Future<void> _writeChannel(_SkArm arm, int channel, Uint8List data) {
    final override = arm.writeOverride;
    if (override != null) return override(channel, data);
    final char = channel == 0 ? arm.cmd : arm.ctrl;
    if (char == null) return Future.error(StateError('not connected'));
    // One write at a time per arm.
    final result = arm.writes.then(
      (_) => char.write(data, withoutResponse: true, timeout: 3),
    );
    arm.writes = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Sends a control request and waits for its reply; tries again with a
  /// new tag after a timeout. Null without a reply.
  Future<SkEvent?> _ctrl(
    _SkArm arm,
    int op,
    List<int> body, {
    Duration timeout = const Duration(milliseconds: 1000),
    int tries = 3,
  }) async {
    for (var i = 0; i < tries; i++) {
      arm.tag = arm.tag % 255 + 1;
      final tag = arm.tag;
      final completer = Completer<SkEvent>();
      arm.replies[tag] = completer;
      try {
        await _writeChannel(arm, 1, Uint8List.fromList([op, tag, ...body]));
        final reply = await completer.future.timeout(timeout);
        if (reply.replyOp == op) return reply;
      } catch (e) {
        if (e is! TimeoutException) {
          _debug('CTRL 0x${op.toRadixString(16)}: $e');
        }
      } finally {
        arm.replies.remove(tag);
      }
    }
    return null;
  }

  /// Reads properties (at most 12).
  Future<List<int>?> _props(_SkArm arm, List<int> ids) async {
    final r = await _ctrl(arm, SkCtrl.props, ids);
    if (r == null || r.status != 0 || r.body.length < ids.length * 4) {
      return null;
    }
    final d = ByteData.sublistView(r.body);
    return [
      for (var i = 0; i < ids.length; i++) d.getUint32(i * 4, Endian.little),
    ];
  }

  /// Feeds an event as if it came from the arm (tests).
  @visibleForTesting
  void receive(G1Side side, Uint8List data) {
    final arm = _arms[side];
    if (arm != null) _onEvent(arm, data);
  }

  void _onEvent(_SkArm arm, Uint8List data) {
    if (data.length < 9) return;
    final e = SkEvent(data);
    if (e.isReply) {
      final c = arm.replies[e.tag];
      if (c != null && !c.isCompleted) c.complete(e);
      return;
    }
    if (arm.ready && arm.epoch != null && e.epoch != arm.epoch) {
      _resync(arm);
      return;
    }
    switch (e.type) {
      case SkEvt.ack when data.length >= 18:
        arm.link.onAck(e.u16(9), e.u16(11), e.u8(13), e.u32(14));
      case SkEvt.error when data.length >= 22:
        _debug(
          tr.skLogPacketError(
            arm.side.code,
            e.u16(9),
            skErrorName(e.u8(13)),
            e.u8(12).toRadixString(16),
            e.u32(14),
          ),
        );
        arm.link.onError(e.u16(9));
      case SkEvt.notice when data.length >= 10:
        _onNotice(arm, e.u8(9), Uint8List.sublistView(data, 10));
      case SkEvt.micData when data.length >= 12:
        if (arm.side == G1Side.right && data.length > 12) {
          emitAudio(Uint8List.sublistView(data, 12));
        }
      case SkEvt.notify when data.length >= 20:
        _onNotify(arm, e.u32(12), e.u32(16));
      case SkEvt.halt when data.length >= 20:
        _debug(
          tr.skLogProgramHalted(
            arm.side.code,
            skErrorName(e.u8(15)),
            e.u32(10).toRadixString(16),
            e.u8(14).toRadixString(16),
          ),
        );
        arm.resident = false;
        unawaited(_reportEvents(arm));
        notifyListeners();
      case SkEvt.input when data.length >= 16:
        _onInput(arm, e.u8(11), e.u32(12));
    }
  }

  void _onNotice(_SkArm arm, int kind, Uint8List body) {
    switch (kind) {
      case 4:
        _debug(tr.skLogEncrypted(arm.side.code));
      case 5:
        final reason = body.isEmpty ? 0 : body[0];
        _debug(tr.skLogMicStopped(arm.side.code, reason));
      case 3:
        _debug(tr.skLogDisplayError(arm.side.code));
    }
  }

  void _emit(G1Side side, int code) => emitEvent(
    G1TouchEvent(side, code, Uint8List.fromList([G1Cmd.event, code])),
  );

  void _onInput(_SkArm arm, int trigger, int value) {
    switch (trigger) {
      case SkTrigger.touch:
        switch (value) {
          case SkGesture.tap:
            _emit(arm.side, G1Event.singleTap);
          case SkGesture.doubleTap:
            _emit(arm.side, G1Event.doubleTap);
          case SkGesture.tripleTap:
            // g1v0 has no silent mode: the app keeps it.
            _silent = !_silent;
            _emit(
              arm.side,
              _silent ? G1Event.silentModeOn : G1Event.silentModeOff,
            );
          // Left long press: Assist, as with Even's firmware; the right one
          // is a gesture of its own (Even's firmware keeps it for QuickNote).
          case SkGesture.longStart:
            _emit(
              arm.side,
              arm.side == G1Side.left
                  ? G1Event.longPressStart
                  : G1Event.rightHoldStart,
            );
          case SkGesture.longEnd:
            _emit(
              arm.side,
              arm.side == G1Side.left
                  ? G1Event.longPressStop
                  : G1Event.rightHoldStop,
            );
        }
      case SkTrigger.wear:
        arm.worn = value > 1 ? null : value;
        _applyArmState();
      case SkTrigger.battery:
        if (value <= 100) arm.battery = value;
        _applyArmState();
      case SkTrigger.caseState:
        arm.inCase = value & 1;
        arm.caseLid = (value >> 1) & 1;
        if (arm.inCase == 1) {
          caseCharging = (value >> 2) & 1 == 1;
          final pct = (value >> 8) & 0xff;
          if (pct <= 100) batteryCase = pct;
        }
        _applyArmState();
      case SkTrigger.light when arm.side == G1Side.right:
        unawaited(_applyLight(value));
      case SkTrigger.tilt when arm.side == G1Side.right:
        final pitch = value.toSigned(32);
        final up = pitch > _headUpAngle;
        final down = pitch < _headUpAngle - 10;
        if (!_headUp && up) {
          _headUp = true;
          _emit(arm.side, G1Event.headUp);
        } else if (_headUp && down) {
          _headUp = false;
          _emit(arm.side, G1Event.headDown);
        } else {
          return;
        }
        unawaited(_setTiltRange(arm));
    }
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  @override
  Future<void> refreshBattery() async {
    for (final arm in _arms.values) {
      if (!arm.ready) continue;
      final v = await _props(arm, const [SkProp.battPct]);
      if (v != null && v[0] <= 100) arm.battery = v[0];
    }
    _applyArmState();
  }

  Iterable<_SkArm> _targets({bool left = true, bool right = true}) => _arms
      .values
      .where((a) => a.ready && (a.side == G1Side.left ? left : right));

  /// Runs the same host code on the selected arms.
  Future<bool> _runOn(
    List<Uint8List> codes, {
    bool left = true,
    bool right = true,
  }) async {
    final arms = _targets(left: left, right: right).toList();
    if (arms.isEmpty) return false;
    final results = await Future.wait(arms.map((a) => a.link.run(codes)));
    return results.every((r) => r);
  }

  @override
  Future<bool> sendText(
    String text, {
    String? icon,
    G1TextStyle style = G1TextStyle.plain,
    String? label,
    bool? serverOnline,
  }) async {
    if (_video) return true;
    final font = await _textFont();
    final small = await _small();
    _appShowing = true;
    final arms = _targets().where((a) {
      if (a.inCase != 1) return true;
      if (!_caseNoted) {
        _caseNoted = true;
        _debug(tr.skLogInCase);
      }
      return false;
    }).toList();
    if (arms.isEmpty) return _targets().isNotEmpty;
    final maxCode = arms.map((a) => a.link.maxPacket).reduce(min) - 2;
    // The navigation's arrow goes with the text, the others from slots.
    final iconData = icon == SkIcons.navigation ? _navigationIcon : null;
    if (icon == SkIcons.navigation) icon = null;
    final name = icon == null ? null : _iconName(icon);
    if (name != null) {
      final data = await SkIcons.load(name);
      await Future.wait(arms.map((a) => _uploadIcon(a, name, data)));
    }
    final iconAt = name == null ? null : SkIcons.slot(name, SkArena.icons);
    // Emojis into the arms' font slots first.
    text = await _emojify(text, arms);
    final synced = arms.length == 2 && arms.every((a) => a.clock.known);
    List<Uint8List> codes(_SkArm arm) => textCode(
      font,
      text,
      top: textTop,
      maxCode: maxCode,
      icon: iconAt,
      iconData: iconData,
      serverOnline: serverOnline,
      draw: !synced,
      style: style,
      label: label,
      smallFont: small,
      micStand: _micOn && arm.side == G1Side.right,
    );
    final results = await Future.wait(arms.map((a) => a.link.run(codes(a))));
    if (!synced || !results.every((r) => r)) return results.every((r) => r);
    // Both frames are ready: both eyes show them at the same moment.
    final at = SkClock.hostNow() + _drawLeadUs(arms);
    final shown = await Future.wait(
      arms.map((a) => a.link.run([drawAtCode(a.clock.toArm(at))])),
    );
    _scheduleLightRead();
    return shown.every((r) => r);
  }

  /// Host code that waits until [armTime] and shows the frame.
  @visibleForTesting
  static Uint8List drawAtCode(int armTime) {
    final code = SkCode()
      ..sleepUntil(armTime)
      ..draw(
        SkArena.frame,
        SkPanel.stride,
        0,
        0,
        0,
        0,
        SkPanel.width,
        SkPanel.height,
      );
    return code.take();
  }

  static String _iconName(String icon) =>
      SkIcons.names.contains(icon) ? icon : SkIcons.generic;

  /// Uploads an icon into its slot once per session.
  Future<void> _uploadIcon(_SkArm arm, String name, Uint8List data) async {
    if (arm.icons.contains(name)) return;
    final ok = await arm.link.run(
      skUpload(SkIcons.slot(name, SkArena.icons), data, arm.link.maxPacket - 2),
    );
    if (ok) arm.icons.add(name);
  }

  /// Host code that draws [text] (lines split at '\n', wrapped to the panel)
  /// into the arena's frame and shows it, in packets of at most [maxCode]
  /// bytes. A [style] other than plain draws its frame with [SkLib].
  @visibleForTesting
  static List<Uint8List> textCode(
    SkFont font,
    String text, {
    int top = 140,
    required int maxCode,
    int? icon,
    Uint8List? iconData,
    bool draw = true,
    G1TextStyle style = G1TextStyle.plain,
    bool micStand = false,
    String? label,
    SkFont? smallFont,
    bool? serverOnline,
  }) {
    final withIcon = icon != null || iconData != null;
    final left = withIcon ? iconTextLeft : textLeft;
    final layout = SkLayout.of(
      font,
      wrap(font, text, SkPanel.width - textLeft - left),
      withIcon ? G1TextStyle.plain : style,
      top: top,
      left: left,
    );
    final packets = <Uint8List>[];
    var code = SkCode();
    void room(int bytes) {
      if (code.length + bytes > maxCode) {
        packets.add(code.take());
        code = SkCode();
      }
    }

    // The app shows something: the resident program draws nothing now
    // (busy = 1, shown = 0).
    code.write(SkResident.busy.address, const [1, 0, 0, 0, 0, 0, 0, 0]);
    room(skOpSize(7));
    code.fill(
      SkArena.frame,
      SkPanel.stride,
      0,
      0,
      SkPanel.width,
      SkPanel.height,
      0,
    );
    if (iconData != null) {
      // An icon that comes with the text (the navigation's arrow): its rows
      // straight into the frame, beside the text.
      for (var r = 0; r < SkIcons.size; r++) {
        room(5 + SkIcons.stride);
        code.write(
          SkArena.frame + (top + r) * SkPanel.stride + textLeft ~/ 2,
          iconData.sublist(r * SkIcons.stride, (r + 1) * SkIcons.stride),
        );
      }
    } else if (icon != null) {
      // The app's icon beside the text, its top at the first line's top.
      room(skOpSize(12));
      code.blit(
        icon,
        SkIcons.stride,
        SkArena.frame,
        SkPanel.stride,
        textLeft,
        top,
        SkIcons.size,
        SkIcons.size,
      );
    }
    final box = layout.box;
    if (box != null) {
      room(5 + 28 + 4);
      SkLib.drawBox(code, box);
    }
    final small = smallFont ?? font;
    final extra = [
      ...layout.extra,
      // The microphone's stand under the firmware's indicator (right arm).
      if (micStand)
        for (final (x, y, w, h) in SkResident.standRects)
          SkRect(x, y, w, h, SkResident.standLevel),
      // The label's background: it cuts the frame's line.
      if (label != null)
        SkRect(
          layout.labelAt(SkResident.labelH, left: left, top: top).x,
          layout.labelAt(SkResident.labelH, left: left, top: top).y,
          small.width(label) + 8,
          SkResident.labelH,
          0,
        ),
    ];
    if (extra.isNotEmpty) {
      // Rule, bars and brackets (lab design) with the library.
      SkLib.drawRects(() => code, extra, room);
    }
    var textAt = SkArena.text;
    for (final line in layout.lines) {
      final glyphs = font.encode(line.text);
      if (glyphs.isEmpty) continue;
      if (textAt + glyphs.length > SkArena.text + SkArena.textSize) break;
      // The glyph indices and the GLYPHS that draws them, in one packet.
      final chunk = min(glyphs.length, maxCode - skOpSize(9) - 5);
      room(5 + chunk + skOpSize(9) * (line.bold ? 2 : 1));
      code.write(textAt, glyphs.sublist(0, chunk));
      for (final dx in [if (line.bold) 1, 0]) {
        code.glyphs(
          SkArena.font,
          SkArena.frame,
          SkPanel.stride,
          line.x + dx,
          line.y + font.ascent,
          line.level,
          textAt,
          chunk,
        );
      }
      textAt += chunk;
    }
    if (label != null) {
      final at = layout.labelAt(SkResident.labelH, left: left, top: top);
      final glyphs = small.encode(label);
      if (textAt + glyphs.length <= SkArena.text + SkArena.textSize) {
        room(5 + glyphs.length + skOpSize(9));
        code.write(textAt, glyphs);
        code.glyphs(
          smallFont == null ? SkArena.font : SkArena.smallFont,
          SkArena.frame,
          SkPanel.stride,
          at.x + 4,
          at.y + labelBase(small),
          SkResident.labelLevel,
          textAt,
          glyphs.length,
        );
      }
    }
    if (serverOnline != null) {
      // A dashboard: the connection symbols (the phone is there, it sends
      // this), the server struck through while Home Assistant is away.
      final at = layout.statusAt(left: left, top: top);
      final levels = layout.statusLevels;
      final rects = [
        (0, 0, SkStatusIcons.width, SkStatusIcons.height, false),
        ...SkStatusIcons.phone,
        ...SkStatusIcons.server,
      ];
      for (final (x, y, w, h, on) in rects) {
        room(skOpSize(7));
        code.fill(
          SkArena.frame,
          SkPanel.stride,
          at.x + x,
          at.y + y,
          w,
          h,
          on ? levels.ink : levels.ground,
        );
      }
      if (!serverOnline) {
        for (final (x0, y0, x1, y1, on) in SkStatusIcons.serverStrike) {
          room(skOpSize(7));
          code.line(
            SkArena.frame,
            SkPanel.stride,
            at.x + x0,
            at.y + y0,
            at.x + x1,
            at.y + y1,
            on ? levels.ink : levels.ground,
          );
        }
      }
    }
    if (draw) {
      room(skOpSize(8));
      code.draw(
        SkArena.frame,
        SkPanel.stride,
        0,
        0,
        0,
        0,
        SkPanel.width,
        SkPanel.height,
      );
    }
    if (code.length > 0) packets.add(code.take());
    return packets;
  }

  /// The baseline of a label of [SkResident.labelH] rows in [font].
  static int labelBase(SkFont font) =>
      (SkResident.labelH - font.ascent - font.descent) ~/ 2 + font.ascent;

  /// Splits [text] into lines at most [width] pixels wide (at spaces where
  /// possible). Empty lines are kept (vertical spacing).
  static List<String> wrap(SkFont font, String text, int width) {
    final out = <String>[];
    final raw = text.split('\n');
    while (raw.isNotEmpty && raw.last.trim().isEmpty) {
      raw.removeLast();
    }
    for (final line in raw) {
      var rest = line.trimRight();
      if (rest.isEmpty) {
        out.add('');
        continue;
      }
      while (rest.isNotEmpty) {
        if (font.width(rest) <= width) {
          out.add(rest);
          break;
        }
        // Longest prefix that fits.
        final runes = rest.runes.toList();
        var fit = 0;
        var w = 0;
        while (fit < runes.length) {
          w += font.advanceOf(font.glyphOf(runes[fit]));
          if (w > width) break;
          fit++;
        }
        var cut = fit;
        final space = String.fromCharCodes(runes.sublist(0, fit))
            .lastIndexOf(' ');
        if (space > 0) {
          cut = String.fromCharCodes(runes.sublist(0, space)).runes.length;
        }
        if (cut == 0) cut = max(1, fit);
        out.add(String.fromCharCodes(runes.sublist(0, cut)).trimRight());
        rest = String.fromCharCodes(runes.sublist(cut)).trimLeft();
      }
    }
    return out;
  }

  /// Switches the panels off: a black but lit panel still costs ≈ 4.6 mA
  /// (VM.md §6.6). The next text powers them on again (≈ 71 ms).
  @override
  Future<bool> blankScreen() {
    if (_video) return Future.value(true);
    _appShowing = false;
    final code = SkCode()
      ..write(SkResident.busy.address, const [0, 0, 0, 0])
      ..sysWrite(SkProp.panel, 0)
      // The microphone keeps the panel on: the program draws its stand.
      ..raise(SkTrigger.user3);
    return _runOn([code.take()]);
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  @override
  Future<bool> setBrightness(int percent, {required bool auto}) =>
      setBrightnessLevel(
        (percent.clamp(0, 100) * SkPanel.maxBrightness / 100).round(),
        auto: auto,
      );

  /// The light sensor is on the right arm; with automatic brightness the
  /// left arm follows the right one over the arm-to-arm link (VM.md §6.7).
  // ---------------------------------------------------------------------------
  // Automatic brightness with an offset
  // ---------------------------------------------------------------------------

  /// Offset in levels while the app runs the automatic brightness itself.
  int? _offsetLevels;
  int? _offsetApplied;
  Timer? _lightTimer;

  /// g1v0's automatic brightness has no offset either, but its light sensor
  /// (right arm, measuring while the panel is on, VM.md §6.7) reports when
  /// the light leaves a range: the app then sets stock's level for that light
  /// plus the offset on both eyes, and a new range around the reading.
  @override
  Future<void> setAutoBrightnessOffset(int levels) async {
    final starting = _offsetLevels == null;
    _offsetLevels = levels;
    _offsetApplied = null;
    final right = _arms[G1Side.right];
    if (right == null || !right.ready) return;
    if (_offsetOnArms) {
      await _offsetToArms(levels);
      return;
    }
    if (starting) {
      final code = SkCode()
        ..sysWrite(SkProp.autoBrightness, 0)
        ..sysWrite(SkProp.lightLo, 0)
        ..sysWrite(SkProp.lightHi, 0x7fffffff);
      await _runOn([code.take()]);
      await _reportEvents(right);
    }
    _scheduleLightRead();
  }

  /// The arms keep the offset themselves: the right arm's program sets the
  /// level from its light sensor, the left arm follows over their link.
  bool get _offsetOnArms {
    final left = _arms[G1Side.left], right = _arms[G1Side.right];
    return left != null &&
        right != null &&
        left.resident &&
        right.resident &&
        left.residentPeer == SkResident.peerFollower &&
        right.residentPeer == SkResident.peerLeader;
  }

  Future<void> _offsetToArms(int levels) async {
    _lightTimer?.cancel();
    final right = _arms[G1Side.right]!, left = _arms[G1Side.left]!;
    await right.link.run([
      (SkCode()
            ..sysWrite(SkProp.autoBrightness, 0)
            // A first reading above 0 leaves this range: LIGHT fires.
            ..sysWrite(SkProp.lightLo, 0)
            ..sysWrite(SkProp.lightHi, 0)
            ..write(
              SkResident.lightOn.address,
              SkLib.u32s([1, levels, 0xffffffff]),
            ))
          .take(),
    ]);
    await left.link.run([
      (SkCode()
            ..sysWrite(SkProp.peerLink, 1)
            ..sysWrite(SkProp.autoBrightness, 1))
          .take(),
    ]);
    await _reportEvents(right);
    _debug(tr.skLogOffsetOnArms('${levels >= 0 ? '+' : ''}$levels'));
  }

  Future<void> _stopOffset() async {
    if (_offsetLevels == null) return;
    _offsetLevels = null;
    _lightTimer?.cancel();
    final r = _arms[G1Side.right];
    if (r != null && r.ready && r.resident) {
      await r.link.run([
        (SkCode()..write(SkResident.lightOn.address, SkLib.u32s([0]))).take(),
      ]);
    }
    final right = _arms[G1Side.right];
    if (right != null && right.ready) await _reportEvents(right);
  }

  /// The sensor converts every 800 ms once the panel is on: read it a
  /// moment after something was drawn.
  void _scheduleLightRead() {
    if (_offsetLevels == null || _offsetOnArms) return;
    _lightTimer?.cancel();
    _lightTimer = Timer(const Duration(milliseconds: 1200), () async {
      final right = _arms[G1Side.right];
      if (right == null || !right.ready || _offsetLevels == null) return;
      final v = await _props(right, const [SkProp.light]);
      if (v != null && v[0] != SkProp.unknown) await _applyLight(v[0]);
    });
  }

  /// Stock's level for an ambient light in lux (VM.md §6.7).
  @visibleForTesting
  static int stockLevel(int lux) {
    if (lux < 50) return lux ~/ 5;
    if (lux < 200) return 10 + (lux - 50) ~/ 10;
    if (lux < 1000) return 25 + (lux - 200) ~/ 50;
    if (lux < 2000) return 41;
    return 42;
  }

  /// [light] in 0.01 lux.
  Future<void> _applyLight(int light) async {
    final offset = _offsetLevels;
    if (offset == null) return;
    final level = (stockLevel(light ~/ 100) + offset).clamp(
      0,
      SkPanel.maxBrightness,
    );
    // A range around the reading: ±25 %, at least ±2 lux.
    final margin = max(light ~/ 4, 200);
    final range = SkCode()
      ..sysWrite(SkProp.lightLo, max(0, light - margin))
      ..sysWrite(SkProp.lightHi, light + margin);
    await _arms[G1Side.right]?.link.run([range.take()]);
    if (level == _offsetApplied) return;
    _offsetApplied = level;
    final code = SkCode()..sysWrite(SkProp.brightness, level);
    await _runOn([code.take()]);
    brightnessPercent = G1Brightness.percent(level);
    _debug(
      tr.skLogAutoBrightness(
        light ~/ 100,
        stockLevel(light ~/ 100),
        '${offset >= 0 ? '+' : ''}$offset',
        level,
      ),
    );
    notifyListeners();
  }

  @override
  Future<bool> setBrightnessLevel(int level, {required bool auto}) async {
    await _stopOffset();
    final l = level.clamp(0, SkPanel.maxBrightness);
    final code = SkCode();
    if (auto) {
      code
        ..sysWrite(SkProp.peerLink, 1)
        ..sysWrite(SkProp.brightness, l)
        ..sysWrite(SkProp.autoBrightness, 1);
    } else {
      code
        ..sysWrite(SkProp.autoBrightness, 0)
        ..sysWrite(SkProp.brightness, l);
    }
    final ok = await _runOn([code.take()]);
    brightnessPercent = G1Brightness.percent(l);
    notifyListeners();
    return ok;
  }

  @override
  Future<({int percent, bool auto})?> readBrightness() async {
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready) return null;
    final v = await _props(arm, const [
      SkProp.brightness,
      SkProp.autoBrightness,
    ]);
    if (v == null || v[0] > SkPanel.maxBrightness) return null;
    return (percent: G1Brightness.percent(v[0]), auto: v[1] == 1);
  }

  @override
  Future<int?> readBrightnessLevel() async {
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready) return null;
    final v = await _props(arm, const [SkProp.brightness]);
    if (v == null || v[0] > SkPanel.maxBrightness) return null;
    return v[0];
  }

  /// g1v0 always detects wear; there is nothing to switch.
  @override
  Future<bool> setWearDetection(bool enabled) async => true;

  @override
  Future<bool?> readWearDetection() async => true;

  /// g1v0 has no silent mode: the app keeps it (triple tap toggles it).
  @override
  Future<bool> setSilentMode(bool enabled) async {
    _silent = enabled;
    return true;
  }

  @override
  Future<bool> setHeadUpAngle(int angle) async {
    _headUpAngle = angle.clamp(0, 60);
    final font = await _textFont();
    for (final arm in _arms.values.where((a) => a.ready && a.resident)) {
      await arm.link.run([_residentState(font)]);
    }
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready || arm.resident) return true;
    return _setTiltRange(arm);
  }

  /// The height (0–8) moves the text block.
  @override
  Future<bool> setDisplayHeight(int height) async {
    textTop = 60 + height.clamp(0, 8) * 20;
    // Fewer or more lines fit now (Home Assistant's dashboard follows).
    notifyListeners();
    for (final arm in _arms.values.where((a) => a.ready && a.resident)) {
      await _writeDashboard(arm);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Microphone and link
  // ---------------------------------------------------------------------------

  /// The right arm's microphone at 16 kbps: 20-byte LC3 frames of 10 ms as
  /// with Even's firmware. The arm holds it for a lease of 2 s, renewed here
  /// every 0.8 s (VM.md §6.5); it needs an encrypted link.
  @override
  Future<bool> setMic(bool enable) async {
    final arm = _arms[G1Side.right];
    if (arm == null || !arm.ready) return false;
    if (!enable) {
      _micTimer?.cancel();
      _micOn = false;
      final r = await _ctrl(arm, SkCtrl.mic, const [0, 0]);
      unawaited(_updatePriority());
      unawaited(_micStand(arm, false));
      return r != null && r.status == 0;
    }
    _micOn = true;
    unawaited(_updatePriority());
    final ok = await _renewMic(arm);
    unawaited(_micStand(arm, true));
    _micTimer?.cancel();
    _micTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_micOn && arm.ready) unawaited(_renewMic(arm));
    });
    return ok;
  }

  /// The app shows a text (its frame is on the panel).
  bool _appShowing = false;

  /// Tells the right arm's program about the microphone (it draws the
  /// stand); over an app text the stand is cleared here.
  Future<void> _micStand(_SkArm arm, bool on) async {
    final code = SkCode()
      ..write(SkResident.micOn.address, SkLib.u32s([on ? 1 : 0]))
      ..raise(SkTrigger.user3);
    if (!on && _appShowing) {
      code
        ..fill(
          SkArena.frame,
          SkPanel.stride,
          SkResident.standX,
          SkResident.standY,
          SkResident.standW,
          SkResident.standH,
          0,
        )
        ..draw(
          SkArena.frame,
          SkPanel.stride,
          SkResident.standX,
          SkResident.standY,
          SkResident.standX,
          SkResident.standY,
          SkResident.standW,
          SkResident.standH,
        );
    }
    await arm.link.run([code.take()]);
  }

  Future<bool> _renewMic(_SkArm arm) async {
    final r = await _ctrl(arm, SkCtrl.mic, const [1, 1], tries: 1);
    if (r == null) return false;
    if (r.status != 0) {
      _debug(tr.skLogMic(skErrorName(r.status)));
      if (r.status == 12) {
        _debug(tr.skLogMicNeedsEncryption);
      }
      return false;
    }
    return true;
  }

  @override
  Future<void> setFastConnection(bool fast) async {
    if (fast == _fast) return;
    _fast = fast;
    _debug(fast ? tr.g1LogConnectionFast : tr.g1LogConnectionSaving);
    await _updatePriority();
  }

  Future<void> _updatePriority() async {
    if (!Platform.isAndroid || _fake) return;
    for (final arm in _arms.values) {
      final device = arm.device;
      if (device == null || !arm.ready) continue;
      try {
        await device.requestConnectionPriority(
          connectionPriorityRequest: _priority(arm),
        );
      } catch (e) {
        _debug('connection priority ${arm.side.name}: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  /// Marks the fake arms as set up with [epoch] (tests).
  @visibleForTesting
  void fakeReady({int epoch = 1, int maxPacket = 244}) {
    for (final arm in _arms.values) {
      arm
        ..epoch = epoch
        ..fontLoaded = true
        ..ready = true;
      arm.link.start(0, 0, SkLink.window, maxPacket);
    }
    notifyListeners();
  }

  /// Takes the PING rounds of the clock model (tests).
  @visibleForTesting
  Future<void> fakeSyncClocks() => _syncClocks();

  /// Runs the setup of both fake arms (tests).
  @visibleForTesting
  Future<void> fakeSetup() => Future.wait(_arms.values.map((a) => _setup(a)));

  /// Async work (a disconnect, a setup) may finish after [dispose].
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _probeTimer?.cancel();
    _batteryTimer?.cancel();
    _micTimer?.cancel();
    _clockTimer?.cancel();
    _lightTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final arm in _arms.values) {
      arm.link.dispose();
    }
    super.dispose();
  }
}
