/*===--------------- avx10_2convertintrin.h - AVX10_2CONVERT ---------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */
#ifndef __IMMINTRIN_H
#error                                                                         \
    "Never use <avx10_2convertintrin.h> directly; include <immintrin.h> instead."
#endif // __IMMINTRIN_H

#ifdef __SSE2__

#ifndef __AVX10_2CONVERTINTRIN_H
#define __AVX10_2CONVERTINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS128                                                  \
  __attribute__((__always_inline__, __nodebug__, __target__("avx10.2-256"),    \
                 __min_vector_width__(128)))
#define __DEFAULT_FN_ATTRS256                                                  \
  __attribute__((__always_inline__, __nodebug__, __target__("avx10.2-256"),    \
                 __min_vector_width__(256)))

static __inline__ __m128h __DEFAULT_FN_ATTRS128 _mm_cvtx2ps_ph(__m128 __A,
                                                               __m128 __B) {
  return (__m128h)__builtin_ia32_vcvt2ps2phx128_mask(
      (__v4sf)__A, (__v4sf)__B, (__v8hf)_mm_setzero_ph(), (__mmask8)(-1));
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128
_mm_mask_cvtx2ps_ph(__m128h __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128h)__builtin_ia32_vcvt2ps2phx128_mask(
      (__v4sf)__A, (__v4sf)__B, (__v8hf)__W, (__mmask8)__U);
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128
_mm_maskz_cvtx2ps_ph(__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128h)__builtin_ia32_vcvt2ps2phx128_mask(
      (__v4sf)__A, (__v4sf)__B, (__v8hf)_mm_setzero_ph(), (__mmask8)__U);
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256 _mm256_cvtx2ps_ph(__m256 __A,
                                                                  __m256 __B) {
  return (__m256h)__builtin_ia32_vcvt2ps2phx256_mask(
      (__v8sf)__A, (__v8sf)__B, (__v16hf)_mm256_setzero_ph(), (__mmask16)(-1),
      _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256
_mm256_mask_cvtx2ps_ph(__m256h __W, __mmask16 __U, __m256 __A, __m256 __B) {
  return (__m256h)__builtin_ia32_vcvt2ps2phx256_mask(
      (__v8sf)__A, (__v8sf)__B, (__v16hf)__W, (__mmask16)__U,
      _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtx2ps_ph(__mmask16 __U, __m256 __A, __m256 __B) {
  return (__m256h)__builtin_ia32_vcvt2ps2phx256_mask(
      (__v8sf)__A, (__v8sf)__B, (__v16hf)_mm256_setzero_ph(), (__mmask16)__U,
      _MM_FROUND_CUR_DIRECTION);
}

#define _mm256_cvtx_round2ps_ph(A, B, R)                                       \
  ((__m256h)__builtin_ia32_vcvt2ps2phx256_mask(                                \
      (__v8sf)(A), (__v8sf)(B), (__v16hf)_mm256_undefined_ph(),                \
      (__mmask16)(-1), (const int)(R)))

#define _mm256_mask_cvtx_round2ps_ph(W, U, A, B, R)                            \
  ((__m256h)__builtin_ia32_vcvt2ps2phx256_mask(                                \
      (__v8sf)(A), (__v8sf)(B), (__v16hf)(W), (__mmask16)(U), (const int)(R)))

#define _mm256_maskz_cvtx_round2ps_ph(U, A, B, R)                              \
  ((__m256h)__builtin_ia32_vcvt2ps2phx256_mask(                                \
      (__v8sf)(A), (__v8sf)(B), (__v16hf)(_mm256_setzero_ph()),                \
      (__mmask16)(U), (const int)(R)))

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvtbiasph_bf8(__m128i __A,
                                                                  __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtbiasph_bf8(__m128i __W, __mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtbiasph_bf8(__mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_cvtbiasph_bf8(__m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_undefined_si128(),
      (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_mask_cvtbiasph_bf8(
    __m128i __W, __mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtbiasph_bf8(__mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_cvtbiassph_bf8(__m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8s_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtbiassph_bf8(__m128i __W, __mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8s_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtbiassph_bf8(__mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8s_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_cvtbiassph_bf8(__m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8s_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_undefined_si128(),
      (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_mask_cvtbiassph_bf8(
    __m128i __W, __mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8s_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtbiassph_bf8(__mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2bf8s_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvtbiasph_hf8(__m128i __A,
                                                                  __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtbiasph_hf8(__m128i __W, __mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtbiasph_hf8(__mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_cvtbiasph_hf8(__m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_undefined_si128(),
      (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_mask_cvtbiasph_hf8(
    __m128i __W, __mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtbiasph_hf8(__mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_cvtbiassph_hf8(__m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8s_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtbiassph_hf8(__m128i __W, __mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8s_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtbiassph_hf8(__mmask8 __U, __m128i __A, __m128h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8s_128_mask(
      (__v16qi)__A, (__v8hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_cvtbiassph_hf8(__m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8s_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_undefined_si128(),
      (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_mask_cvtbiassph_hf8(
    __m128i __W, __mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8s_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtbiassph_hf8(__mmask16 __U, __m256i __A, __m256h __B) {
  return (__m128i)__builtin_ia32_vcvtbiasph2hf8s_256_mask(
      (__v32qi)__A, (__v16hf)__B, (__v16qi)(__m128i)_mm_setzero_si128(),
      (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvt2ph_bf8(__m128h __A,
                                                               __m128h __B) {
  return (__m128i)__builtin_ia32_vcvt2ph2bf8_128((__v8hf)(__A), (__v8hf)(__B));
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvt2ph_bf8(__m128i __W, __mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvt2ph_bf8(__A, __B), (__v16qi)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvt2ph_bf8(__mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvt2ph_bf8(__A, __B),
      (__v16qi)(__m128i)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_cvt2ph_bf8(__m256h __A,
                                                                  __m256h __B) {
  return (__m256i)__builtin_ia32_vcvt2ph2bf8_256((__v16hf)(__A),
                                                 (__v16hf)(__B));
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_cvt2ph_bf8(__m256i __W, __mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvt2ph_bf8(__A, __B), (__v32qi)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvt2ph_bf8(__mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvt2ph_bf8(__A, __B),
      (__v32qi)(__m256i)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvts2ph_bf8(__m128h __A,
                                                                __m128h __B) {
  return (__m128i)__builtin_ia32_vcvt2ph2bf8s_128((__v8hf)(__A), (__v8hf)(__B));
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvts2ph_bf8(__m128i __W, __mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvts2ph_bf8(__A, __B), (__v16qi)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvts2ph_bf8(__mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvts2ph_bf8(__A, __B),
      (__v16qi)(__m128i)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_cvts2ph_bf8(__m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_vcvt2ph2bf8s_256((__v16hf)(__A),
                                                  (__v16hf)(__B));
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_cvts2ph_bf8(__m256i __W, __mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvts2ph_bf8(__A, __B), (__v32qi)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvts2ph_bf8(__mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvts2ph_bf8(__A, __B),
      (__v32qi)(__m256i)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvt2ph_hf8(__m128h __A,
                                                               __m128h __B) {
  return (__m128i)__builtin_ia32_vcvt2ph2hf8_128((__v8hf)(__A), (__v8hf)(__B));
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvt2ph_hf8(__m128i __W, __mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvt2ph_hf8(__A, __B), (__v16qi)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvt2ph_hf8(__mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvt2ph_hf8(__A, __B),
      (__v16qi)(__m128i)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_cvt2ph_hf8(__m256h __A,
                                                                  __m256h __B) {
  return (__m256i)__builtin_ia32_vcvt2ph2hf8_256((__v16hf)(__A),
                                                 (__v16hf)(__B));
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_cvt2ph_hf8(__m256i __W, __mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvt2ph_hf8(__A, __B), (__v32qi)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvt2ph_hf8(__mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvt2ph_hf8(__A, __B),
      (__v32qi)(__m256i)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvts2ph_hf8(__m128h __A,
                                                                __m128h __B) {
  return (__m128i)__builtin_ia32_vcvt2ph2hf8s_128((__v8hf)(__A), (__v8hf)(__B));
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvts2ph_hf8(__m128i __W, __mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvts2ph_hf8(__A, __B), (__v16qi)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvts2ph_hf8(__mmask16 __U, __m128h __A, __m128h __B) {
  return (__m128i)__builtin_ia32_selectb_128(
      (__mmask16)__U, (__v16qi)_mm_cvts2ph_hf8(__A, __B),
      (__v16qi)(__m128i)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_cvts2ph_hf8(__m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_vcvt2ph2hf8s_256((__v16hf)(__A),
                                                  (__v16hf)(__B));
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_cvts2ph_hf8(__m256i __W, __mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvts2ph_hf8(__A, __B), (__v32qi)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvts2ph_hf8(__mmask32 __U, __m256h __A, __m256h __B) {
  return (__m256i)__builtin_ia32_selectb_256(
      (__mmask16)__U, (__v32qi)_mm256_cvts2ph_hf8(__A, __B),
      (__v32qi)(__m256i)_mm256_setzero_si256());
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128 _mm_cvthf8(__m128i __A) {
  return (__m128h)__builtin_ia32_vcvthf8_2ph128_mask(
      (__v16qi)__A, (__v8hf)(__m128h)_mm_undefined_ph(), (__mmask8)-1);
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128 _mm_mask_cvthf8(__m128h __W,
                                                                __mmask8 __U,
                                                                __m128i __A) {
  return (__m128h)__builtin_ia32_vcvthf8_2ph128_mask(
      (__v16qi)__A, (__v8hf)(__m128h)__W, (__mmask8)__U);
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128 _mm_maskz_cvthf8(__mmask8 __U,
                                                                 __m128i __A) {
  return (__m128h)__builtin_ia32_vcvthf8_2ph128_mask(
      (__v16qi)__A, (__v8hf)(__m128h)_mm_setzero_ph(), (__mmask8)__U);
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256 _mm256_cvthf8(__m128i __A) {
  return (__m256h)__builtin_ia32_vcvthf8_2ph256_mask(
      (__v16qi)__A, (__v16hf)(__m256h)_mm256_undefined_ph(), (__mmask16)-1);
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256
_mm256_mask_cvthf8(__m256h __W, __mmask16 __U, __m128i __A) {
  return (__m256h)__builtin_ia32_vcvthf8_2ph256_mask(
      (__v16qi)__A, (__v16hf)(__m256h)__W, (__mmask16)__U);
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256
_mm256_maskz_cvthf8(__mmask16 __U, __m128i __A) {
  return (__m256h)__builtin_ia32_vcvthf8_2ph256_mask(
      (__v16qi)__A, (__v16hf)(__m256h)_mm256_setzero_ph(), (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvtph_bf8(__m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtph_bf8(__m128i __W, __mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtph_bf8(__mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_cvtph_bf8(__m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_mask_cvtph_bf8(__m128i __W, __mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtph_bf8(__mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvtsph_bf8(__m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8s_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtsph_bf8(__m128i __W, __mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8s_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtsph_bf8(__mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8s_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_cvtsph_bf8(__m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8s_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_mask_cvtsph_bf8(__m128i __W, __mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8s_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtsph_bf8(__mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2bf8s_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvtph_hf8(__m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtph_hf8(__m128i __W, __mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtph_hf8(__mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_cvtph_hf8(__m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_mask_cvtph_hf8(__m128i __W, __mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtph_hf8(__mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128 _mm_cvtsph_hf8(__m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8s_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask8)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_cvtsph_hf8(__m128i __W, __mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8s_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)__W, (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_cvtsph_hf8(__mmask8 __U, __m128h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8s_128_mask(
      (__v8hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask8)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256 _mm256_cvtsph_hf8(__m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8s_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_undefined_si128(), (__mmask16)-1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_mask_cvtsph_hf8(__m128i __W, __mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8s_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)__W, (__mmask16)__U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtsph_hf8(__mmask16 __U, __m256h __A) {
  return (__m128i)__builtin_ia32_vcvtph2hf8s_256_mask(
      (__v16hf)__A, (__v16qi)(__m128i)_mm_setzero_si128(), (__mmask16)__U);
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128 _mm_cvtbf8_ph(__m128i __A) {
  return _mm_castsi128_ph(_mm_slli_epi16(_mm_cvtepi8_epi16(__A), 8));
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128
_mm_mask_cvtbf8_ph(__m128h __S, __mmask8 __U, __m128i __A) {
  return _mm_castsi128_ph(
      _mm_mask_slli_epi16((__m128i)__S, __U, _mm_cvtepi8_epi16(__A), 8));
}

static __inline__ __m128h __DEFAULT_FN_ATTRS128
_mm_maskz_cvtbf8_ph(__mmask8 __U, __m128i __A) {
  return _mm_castsi128_ph(_mm_slli_epi16(_mm_maskz_cvtepi8_epi16(__U, __A), 8));
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256 _mm256_cvtbf8_ph(__m128i __A) {
  return _mm256_castsi256_ph(_mm256_slli_epi16(_mm256_cvtepi8_epi16(__A), 8));
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256
_mm256_mask_cvtbf8_ph(__m256h __S, __mmask16 __U, __m128i __A) {
  return _mm256_castsi256_ph(
      _mm256_mask_slli_epi16((__m256i)__S, __U, _mm256_cvtepi8_epi16(__A), 8));
}

static __inline__ __m256h __DEFAULT_FN_ATTRS256
_mm256_maskz_cvtbf8_ph(__mmask16 __U, __m128i __A) {
  return _mm256_castsi256_ph(
      _mm256_slli_epi16(_mm256_maskz_cvtepi8_epi16(__U, __A), 8));
}

#undef __DEFAULT_FN_ATTRS128
#undef __DEFAULT_FN_ATTRS256

#endif // __AVX10_2CONVERTINTRIN_H
#endif // __SSE2__
