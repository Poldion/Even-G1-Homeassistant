#include "lc3_codec.h"

#include <stdlib.h>

#include "lc3.h"

typedef struct {
  lc3_decoder_t decoder;
  int frame_samples;
  void *mem;
} g1_decoder;

void *g1_lc3_decoder_new(int frame_us, int sample_rate) {
  unsigned size = lc3_decoder_size(frame_us, sample_rate);
  int samples = lc3_frame_samples(frame_us, sample_rate);
  if (size == 0 || samples <= 0) return NULL;

  g1_decoder *d = (g1_decoder *)calloc(1, sizeof(g1_decoder));
  if (!d) return NULL;
  d->mem = malloc(size);
  if (!d->mem) {
    free(d);
    return NULL;
  }
  d->decoder = lc3_setup_decoder(frame_us, sample_rate, 0, d->mem);
  d->frame_samples = samples;
  if (!d->decoder) {
    free(d->mem);
    free(d);
    return NULL;
  }
  return d;
}

int g1_lc3_frame_samples(int frame_us, int sample_rate) {
  return lc3_frame_samples(frame_us, sample_rate);
}

int g1_lc3_decode(void *decoder, const uint8_t *in, int in_len, int frame_bytes,
                  int16_t *out) {
  g1_decoder *d = (g1_decoder *)decoder;
  if (!d || !out || frame_bytes <= 0) return -1;

  if (in == NULL) {
    lc3_decode(d->decoder, NULL, 0, LC3_PCM_FORMAT_S16, out, 1);
    return d->frame_samples;
  }

  int frames = in_len / frame_bytes;
  for (int i = 0; i < frames; i++) {
    lc3_decode(d->decoder, in + i * frame_bytes, frame_bytes,
               LC3_PCM_FORMAT_S16, out + i * d->frame_samples, 1);
  }
  return frames * d->frame_samples;
}

void g1_lc3_decoder_free(void *decoder) {
  g1_decoder *d = (g1_decoder *)decoder;
  if (!d) return;
  free(d->mem);
  free(d);
}
