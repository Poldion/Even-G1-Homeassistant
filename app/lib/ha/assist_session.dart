import 'dart:async';
import 'dart:typed_data';

import 'ha_client.dart';
import '../l10n/l10n.dart';

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
/// Uses the `even_g1/assist_run` command of the integration. It runs the
/// Assist pipeline configured in Home Assistant from `stt` to `intent`
/// without voice activity detection, so the recording lasts exactly as long
/// as the touch bar is held. Speech recognition happens in Home Assistant.
class AssistSession {
  AssistSession(
    this.client, {
    required this.entryId,
    this.conversationId,
    this.onTranscript,
  });

  final HaClient client;
  final String entryId;
  final String? conversationId;

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
      'type': 'even_g1/assist_run',
      'entry_id': entryId,
      'conversation_id': ?conversationId,
    });
    _subscription!.events.listen(
      _onEvent,
      onDone: () {
        _complete(
          AssistResult(
            query: _query,
            response: '',
            error: tr.coreHaConnectionLost,
          ),
        );
      },
    );
  }

  void _onEvent(Map<String, dynamic> event) {
    final data = (event['data'] as Map?)?.cast<String, dynamic>() ?? {};
    switch (event['type']) {
      case 'audio-ready':
        _handlerId = data['handler_id'] as int?;
        if (_handlerId == null) return;
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
          AssistResult(
            query: _query,
            response: '',
            error: tr.coreAssistNoAnswer,
          ),
        );
    }
  }

  String _errorText(String? code, String? message) {
    return switch (code) {
      'stt-no-text-recognized' => tr.coreSttNothing,
      'stt-stream-failed' => tr.coreSttFailed,
      'stt-provider-missing' ||
      'stt-provider-unsupported-metadata' => tr.coreSttMissing,
      _ => message ?? code ?? tr.coreUnknownError,
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
    _complete(
      AssistResult(query: _query, response: '', error: tr.coreCancelled),
    );
  }
}
