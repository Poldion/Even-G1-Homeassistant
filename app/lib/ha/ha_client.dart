import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class HaException implements Exception {
  HaException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'Home Assistant: $message ($code)';
}

/// A subscription: the command result followed by a stream of events.
class HaSubscription {
  HaSubscription(this.id, this.events, this._client);

  final int id;
  final Stream<Map<String, dynamic>> events;
  final HaClient _client;

  Future<void> cancel() => _client._unsubscribe(id);
}

/// Minimal Home Assistant websocket API client.
class HaClient {
  HaClient(this.baseUrl, this.token);

  final String baseUrl;
  final String token;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  int _id = 0;
  final _results = <int, Completer<dynamic>>{};
  final _subscriptions = <int, StreamController<Map<String, dynamic>>>{};
  final _closed = Completer<void>();
  String? haVersion;

  /// Completes when the connection is closed.
  Future<void> get closed => _closed.future;

  static Uri websocketUri(String baseUrl) {
    var url = baseUrl.trim();
    if (!url.contains('://')) url = 'http://$url';
    final uri = Uri.parse(url);
    final scheme = switch (uri.scheme) {
      'https' || 'wss' => 'wss',
      _ => 'ws',
    };
    var path = uri.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    if (!path.endsWith('/api/websocket')) path = '$path/api/websocket';
    return uri.replace(scheme: scheme, path: path, query: null);
  }

  /// Connects and authenticates.
  Future<void> connect() async {
    final channel = WebSocketChannel.connect(websocketUri(baseUrl));
    _channel = channel;
    await channel.ready.timeout(const Duration(seconds: 15));

    final auth = Completer<void>();
    _sub = channel.stream.listen(
      (raw) {
        if (raw is! String) return;
        final decoded = jsonDecode(raw);
        final messages = decoded is List ? decoded : [decoded];
        for (final m in messages.cast<Map<String, dynamic>>()) {
          switch (m['type']) {
            case 'auth_required':
              channel.sink.add(
                jsonEncode({'type': 'auth', 'access_token': token}),
              );
            case 'auth_ok':
              haVersion = m['ha_version'] as String?;
              if (!auth.isCompleted) auth.complete();
            case 'auth_invalid':
              if (!auth.isCompleted) {
                auth.completeError(
                  HaException('auth_invalid', '${m['message']}'),
                );
              }
            default:
              _handle(m);
          }
        }
      },
      onDone: _onClosed,
      onError: (Object e) {
        if (!auth.isCompleted) auth.completeError(e);
        _onClosed();
      },
    );
    await auth.future.timeout(const Duration(seconds: 15));
  }

  void _handle(Map<String, dynamic> m) {
    final id = m['id'] as int?;
    if (id == null) return;
    switch (m['type']) {
      case 'result':
        final completer = _results.remove(id);
        if (completer == null) return;
        if (m['success'] == true) {
          completer.complete(m['result']);
        } else {
          final error = (m['error'] as Map?) ?? {};
          completer.completeError(
            HaException('${error['code']}', '${error['message']}'),
          );
          _subscriptions.remove(id)?.close();
        }
      case 'event':
        _subscriptions[id]?.add(Map<String, dynamic>.from(m['event'] as Map));
      case 'pong':
        _results.remove(id)?.complete(null);
    }
  }

  void _onClosed() {
    for (final c in _results.values) {
      if (!c.isCompleted) {
        c.completeError(HaException('closed', 'Connection closed'));
      }
    }
    _results.clear();
    for (final s in _subscriptions.values) {
      s.close();
    }
    _subscriptions.clear();
    if (!_closed.isCompleted) _closed.complete();
  }

  int _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null || _closed.isCompleted) {
      throw HaException('closed', 'Not connected');
    }
    final id = ++_id;
    channel.sink.add(jsonEncode({...message, 'id': id}));
    return id;
  }

  /// Sends a command and returns its result.
  Future<dynamic> call(
    Map<String, dynamic> message, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    final completer = Completer<dynamic>();
    final id = _send(message);
    _results[id] = completer;
    return completer.future.timeout(timeout);
  }

  /// Sends a subscription command. Throws if Home Assistant rejects it.
  Future<HaSubscription> subscribe(Map<String, dynamic> message) async {
    final controller = StreamController<Map<String, dynamic>>();
    final completer = Completer<dynamic>();
    final id = _send(message);
    _results[id] = completer;
    _subscriptions[id] = controller;
    await completer.future.timeout(const Duration(seconds: 30));
    return HaSubscription(id, controller.stream, this);
  }

  Future<void> _unsubscribe(int id) async {
    final controller = _subscriptions.remove(id);
    if (controller == null) return;
    // Not awaited: completes only once a listener drained the stream.
    unawaited(controller.close());
    if (_closed.isCompleted) return;
    try {
      await call({'type': 'unsubscribe_events', 'subscription': id});
    } catch (_) {}
  }

  /// Sends a binary message (used for assist audio).
  void sendBinary(Uint8List data) {
    final channel = _channel;
    if (channel == null || _closed.isCompleted) return;
    channel.sink.add(data);
  }

  Future<void> ping() =>
      call({'type': 'ping'}, timeout: const Duration(seconds: 10));

  Future<void> close() async {
    _onClosed();
    await _sub?.cancel();
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
