import 'dart:async';
import 'dart:typed_data';

import 'ha_client.dart';

class AssistResult {
  AssistResult({
    required this.query,
    required this.response,
    this.conversationId,
    this.continueConversation = false,
    this.error,
  });

  final String query;
  final String response;
  final String? conversationId;
  final bool continueConversation;
  final String? error;
}

/// One run of an Assist pipeline: speech (16 kHz PCM) in, text answer out.
///
/// Uses the `assist_pipeline/run` websocket command from `stt` to `intent`.
/// The glasses have no speaker, so text-to-speech is skipped.
class AssistSession {
  AssistSession(
    this.client, {
    this.pipelineId,
    this.conversationId,
    this.deviceId,
    this.onTranscript,
  });

  final HaClient client;
  final String? pipelineId;
  final String? conversationId;
  final String? deviceId;

  /// Called as soon as the speech was recognized.
  final void Function(String text)? onTranscript;

  HaSubscription? _subscription;
  int? _handlerId;
  final _buffer = BytesBuilder();
  bool _audioDone = false;
  bool _sttDone = false;
  String _query = '';
  final _result = Completer<AssistResult>();

  Future<AssistResult> get result => _result.future;

  Future<void> start() async {
    _subscription = await client.subscribe({
      'type': 'assist_pipeline/run',
      'start_stage': 'stt',
      'end_stage': 'intent',
      'input': {'sample_rate': 16000},
      'pipeline': ?pipelineId,
      'conversation_id': ?conversationId,
      'device_id': ?deviceId,
      'timeout': 120,
    });
    _subscription!.events.listen(
      _onEvent,
      onDone: () {
        _complete(
          AssistResult(
            query: _query,
            response: '',
            error: 'Verbindung zu Home Assistant verloren',
          ),
        );
      },
    );
  }

  void _onEvent(Map<String, dynamic> event) {
    final data = (event['data'] as Map?)?.cast<String, dynamic>() ?? {};
    switch (event['type']) {
      case 'run-start':
        final runner = (data['runner_data'] as Map?) ?? {};
        _handlerId = runner['stt_binary_handler_id'] as int?;
        if (_buffer.isNotEmpty) _sendAudio(_buffer.takeBytes());
        if (_audioDone) _sendEnd();
      case 'stt-end':
        _sttDone = true;
        final output = (data['stt_output'] as Map?) ?? {};
        _query = (output['text'] as String? ?? '').trim();
        onTranscript?.call(_query);
      case 'intent-end':
        final output = (data['intent_output'] as Map?) ?? {};
        final response = (output['response'] as Map?) ?? {};
        final speech = ((response['speech'] as Map?)?['plain'] as Map?) ?? {};
        _complete(
          AssistResult(
            query: _query,
            response: (speech['speech'] as String? ?? '').trim(),
            conversationId: output['conversation_id'] as String?,
            continueConversation: output['continue_conversation'] == true,
          ),
        );
      case 'error':
        _complete(
          AssistResult(
            query: _query,
            response: '',
            error: _errorText(
              data['code'] as String?,
              data['message'] as String?,
            ),
          ),
        );
      case 'run-end':
        _complete(
          AssistResult(query: _query, response: '', error: 'Keine Antwort'),
        );
    }
  }

  String _errorText(String? code, String? message) {
    return switch (code) {
      'stt-no-text-recognized' => 'Ich habe nichts verstanden.',
      'stt-stream-failed' => 'Spracherkennung fehlgeschlagen.',
      'stt-provider-missing' || 'stt-provider-unsupported-metadata' =>
        'Keine Spracherkennung in der Assist-Pipeline konfiguriert.',
      _ => message ?? code ?? 'Unbekannter Fehler',
    };
  }

  /// Adds 16 kHz, 16 bit mono PCM audio.
  void addAudio(Uint8List pcm) {
    if (_audioDone || _sttDone || pcm.isEmpty) return;
    if (_handlerId == null) {
      _buffer.add(pcm);
    } else {
      _sendAudio(pcm);
    }
  }

  /// Signals the end of the speech (touch bar released).
  void finishAudio() {
    if (_audioDone) return;
    _audioDone = true;
    if (_handlerId != null) _sendEnd();
  }

  void _sendAudio(Uint8List pcm) {
    final message = Uint8List(pcm.length + 1)
      ..[0] = _handlerId!
      ..setRange(1, pcm.length + 1, pcm);
    client.sendBinary(message);
  }

  void _sendEnd() {
    if (_sttDone) return;
    client.sendBinary(Uint8List.fromList([_handlerId!]));
  }

  void _complete(AssistResult result) {
    if (_result.isCompleted) return;
    _result.complete(result);
    _subscription?.cancel();
  }

  Future<void> cancel() async {
    _complete(AssistResult(query: _query, response: '', error: 'Abgebrochen'));
  }
}
