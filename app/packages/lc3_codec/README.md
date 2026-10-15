# lc3_codec

Tiny Flutter FFI plugin that bundles [google/liblc3](https://github.com/google/liblc3)
(Apache 2.0, see `src/liblc3/LICENSE`, commit `efe84d3`) and exposes an LC3
decoder to Dart. Used to decode the G1 microphone stream (16 kHz, 10 ms
frames, 20 bytes per frame) to 16 bit PCM for Home Assistant Assist.

Running the tests on a desktop:

```sh
cmake -S src -B build && cmake --build build
LC3_CODEC_LIBRARY=build/liblc3_codec.so flutter test
```
