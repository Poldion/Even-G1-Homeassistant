// Run with LC3_CODEC_LIBRARY pointing to a host build of src/ (see README).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lc3_codec/lc3_codec.dart';

void main() {
  final hasLibrary = Platform.environment.containsKey('LC3_CODEC_LIBRARY');

  test('decodes a 1 kHz sine encoded with liblc3', () {
    final lc3 = File('test/fixtures/sine_1khz.lc3').readAsBytesSync();
    final decoder = Lc3Decoder();
    // The G1 sends 200 byte packets = 10 frames.
    final pcm = BytesBuilder();
    for (var i = 0; i < lc3.length; i += 200) {
      pcm.add(decoder.decode(Uint8List.sublistView(lc3, i, i + 200)));
    }
    decoder.dispose();

    final bytes = pcm.toBytes();
    expect(bytes.length, 50 * 160 * 2);
    final samples = Int16List.sublistView(bytes);

    // Skip the codec delay, then correlate with 1 kHz and compare to 500 Hz.
    double power(int hz) {
      var re = 0.0, im = 0.0;
      for (var n = 1600; n < samples.length; n++) {
        re += samples[n] * cos(2 * pi * hz * n / 16000);
        im += samples[n] * sin(2 * pi * hz * n / 16000);
      }
      return sqrt(re * re + im * im);
    }

    expect(power(1000), greaterThan(power(500) * 20));
    final peak = samples.skip(1600).map((s) => s.abs()).reduce(max);
    expect(peak, inInclusiveRange(6000, 10000));
  }, skip: !hasLibrary);

  test('concealment produces one frame', () {
    final decoder = Lc3Decoder();
    expect(decoder.conceal().length, 320);
    decoder.dispose();
    expect(() => decoder.decode(Uint8List(20)), throwsStateError);
  }, skip: !hasLibrary);
}
