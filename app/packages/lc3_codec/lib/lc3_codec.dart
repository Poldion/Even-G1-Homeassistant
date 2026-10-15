/// LC3 decoder for the Even G1 microphone stream (wraps google/liblc3).
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const String _libName = 'lc3_codec';

DynamicLibrary _open() {
  final override = Platform.environment['LC3_CODEC_LIBRARY'];
  if (override != null) return DynamicLibrary.open(override);
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) return DynamicLibrary.open('$_libName.dll');
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}

final DynamicLibrary _lib = _open();

final _decoderNew = _lib
    .lookupFunction<
      Pointer<Void> Function(Int32, Int32),
      Pointer<Void> Function(int, int)
    >('g1_lc3_decoder_new');
final _frameSamples = _lib
    .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
      'g1_lc3_frame_samples',
    );
final _decode = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Int32,
        Int32,
        Pointer<Int16>,
      ),
      int Function(Pointer<Void>, Pointer<Uint8>, int, int, Pointer<Int16>)
    >('g1_lc3_decode');
final _decoderFree = _lib
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'g1_lc3_decoder_free',
    );

/// Stateful LC3 decoder. Create one per audio stream and [dispose] it.
class Lc3Decoder {
  Lc3Decoder({
    this.frameUs = 10000,
    this.sampleRate = 16000,
    this.frameBytes = 20,
  }) : _handle = _decoderNew(frameUs, sampleRate),
       frameSamples = _frameSamples(frameUs, sampleRate) {
    if (_handle == nullptr) {
      throw ArgumentError('Unsupported LC3 parameters $frameUs/$sampleRate');
    }
  }

  final int frameUs;
  final int sampleRate;
  final int frameBytes;
  final int frameSamples;
  Pointer<Void> _handle;

  /// Decodes LC3 data (a multiple of [frameBytes]) into 16 bit little endian
  /// mono PCM bytes.
  Uint8List decode(Uint8List lc3) {
    if (_handle == nullptr) throw StateError('Decoder disposed');
    final frames = lc3.length ~/ frameBytes;
    if (frames == 0) return Uint8List(0);
    final input = malloc<Uint8>(lc3.length);
    final output = malloc<Int16>(frames * frameSamples);
    try {
      input.asTypedList(lc3.length).setAll(0, lc3);
      final samples = _decode(_handle, input, lc3.length, frameBytes, output);
      if (samples < 0) throw StateError('LC3 decoding failed');
      return Uint8List.fromList(output.cast<Uint8>().asTypedList(samples * 2));
    } finally {
      malloc.free(input);
      malloc.free(output);
    }
  }

  /// Produces one frame of packet loss concealment (e.g. for a lost packet).
  Uint8List conceal() {
    if (_handle == nullptr) throw StateError('Decoder disposed');
    final output = malloc<Int16>(frameSamples);
    try {
      final samples = _decode(_handle, nullptr, 0, frameBytes, output);
      return Uint8List.fromList(output.cast<Uint8>().asTypedList(samples * 2));
    } finally {
      malloc.free(output);
    }
  }

  void dispose() {
    if (_handle != nullptr) {
      _decoderFree(_handle);
      _handle = nullptr;
    }
  }
}
