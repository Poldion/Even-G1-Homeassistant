// Small C API around liblc3 used by the Even G1 app through dart:ffi.
//
// The G1 microphone streams LC3 audio: 16 kHz, mono, 10 ms frames,
// 20 bytes per frame (10 frames per 200 byte BLE packet).

#ifndef G1_LC3_CODEC_H
#define G1_LC3_CODEC_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Creates a decoder. Returns NULL for unsupported parameters.
FFI_PLUGIN_EXPORT void *g1_lc3_decoder_new(int frame_us, int sample_rate);

// Number of PCM samples produced per frame.
FFI_PLUGIN_EXPORT int g1_lc3_frame_samples(int frame_us, int sample_rate);

// Decodes `in_len / frame_bytes` frames from `in` into 16 bit signed PCM
// samples in `out` (which must hold frames * frame_samples samples).
// Passing in == NULL runs packet loss concealment for one frame.
// Returns the number of samples written or -1 on error.
FFI_PLUGIN_EXPORT int g1_lc3_decode(void *decoder, const uint8_t *in, int in_len,
                                    int frame_bytes, int16_t *out);

FFI_PLUGIN_EXPORT void g1_lc3_decoder_free(void *decoder);

#ifdef __cplusplus
}
#endif

#endif
