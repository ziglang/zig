/*===---- avx10_2niintrin.h - AVX10.2 new instruction intrinsics -----------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */
#ifndef __IMMINTRIN_H
#error "Never use <avx10_2niintrin.h> directly; include <immintrin.h> instead."
#endif

#ifdef __SSE2__

#ifndef __AVX10_2NIINTRIN_H
#define __AVX10_2NIINTRIN_H

#define __DEFAULT_FN_ATTRS128                                                  \
  __attribute__((__always_inline__, __nodebug__, __target__("avx10.2-256"),    \
                 __min_vector_width__(128)))
#define __DEFAULT_FN_ATTRS256                                                  \
  __attribute__((__always_inline__, __nodebug__, __target__("avx10.2-256"),    \
                 __min_vector_width__(256)))

/* VNNI FP16 */
static __inline__ __m128 __DEFAULT_FN_ATTRS128 _mm_dpph_ps(__m128 __W,
                                                           __m128h __A,
                                                           __m128h __B) {
  return (__m128)__builtin_ia32_vdpphps128((__v4sf)__W, (__v8hf)__A,
                                           (__v8hf)__B);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128 _mm_mask_dpph_ps(__m128 __W,
                                                                __mmask8 __U,
                                                                __m128h __A,
                                                                __m128h __B) {
  return (__m128)__builtin_ia32_selectps_128(
      (__mmask8)__U, (__v4sf)_mm_dpph_ps(__W, __A, __B), (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128 _mm_maskz_dpph_ps(__mmask8 __U,
                                                                 __m128 __W,
                                                                 __m128h __A,
                                                                 __m128h __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_dpph_ps(__W, __A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256 _mm256_dpph_ps(__m256 __W,
                                                              __m256h __A,
                                                              __m256h __B) {
  return (__m256)__builtin_ia32_vdpphps256((__v8sf)__W, (__v16hf)__A,
                                           (__v16hf)__B);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_mask_dpph_ps(__m256 __W, __mmask8 __U, __m256h __A, __m256h __B) {
  return (__m256)__builtin_ia32_selectps_256(
      (__mmask8)__U, (__v8sf)_mm256_dpph_ps(__W, __A, __B), (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_maskz_dpph_ps(__mmask8 __U, __m256 __W, __m256h __A, __m256h __B) {
  return (__m256)__builtin_ia32_selectps_256(
      (__mmask8)__U, (__v8sf)_mm256_dpph_ps(__W, __A, __B),
      (__v8sf)_mm256_setzero_ps());
}

/* VMPSADBW */
#define _mm_mask_mpsadbw_epu8(W, U, A, B, imm)                                 \
  ((__m128i)__builtin_ia32_selectw_128(                                        \
      (__mmask8)(U), (__v8hi)_mm_mpsadbw_epu8((A), (B), (imm)),                \
      (__v8hi)(__m128i)(W)))

#define _mm_maskz_mpsadbw_epu8(U, A, B, imm)                                   \
  ((__m128i)__builtin_ia32_selectw_128(                                        \
      (__mmask8)(U), (__v8hi)_mm_mpsadbw_epu8((A), (B), (imm)),                \
      (__v8hi)_mm_setzero_si128()))

#define _mm256_mask_mpsadbw_epu8(W, U, A, B, imm)                              \
  ((__m256i)__builtin_ia32_selectw_256(                                        \
      (__mmask16)(U), (__v16hi)_mm256_mpsadbw_epu8((A), (B), (imm)),           \
      (__v16hi)(__m256i)(W)))

#define _mm256_maskz_mpsadbw_epu8(U, A, B, imm)                                \
  ((__m256i)__builtin_ia32_selectw_256(                                        \
      (__mmask16)(U), (__v16hi)_mm256_mpsadbw_epu8((A), (B), (imm)),           \
      (__v16hi)_mm256_setzero_si256()))

/* VNNI INT8 */
static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbssd_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbssd_epi32(__W, __A, __B), (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbssd_epi32(__mmask8 __U, __m128i __W, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbssd_epi32(__W, __A, __B),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbssd_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbssd_epi32(__W, __A, __B), (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpbssd_epi32(__mmask8 __U, __m256i __W, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbssd_epi32(__W, __A, __B),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbssds_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbssds_epi32(__W, __A, __B), (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbssds_epi32(__mmask8 __U, __m128i __W, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbssds_epi32(__W, __A, __B),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbssds_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbssds_epi32(__W, __A, __B), (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_maskz_dpbssds_epi32(
    __mmask8 __U, __m256i __W, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbssds_epi32(__W, __A, __B),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbsud_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbsud_epi32(__W, __A, __B), (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbsud_epi32(__mmask8 __U, __m128i __W, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbsud_epi32(__W, __A, __B),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbsud_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbsud_epi32(__W, __A, __B), (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpbsud_epi32(__mmask8 __U, __m256i __W, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbsud_epi32(__W, __A, __B),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbsuds_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbsuds_epi32(__W, __A, __B), (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbsuds_epi32(__mmask8 __U, __m128i __W, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbsuds_epi32(__W, __A, __B),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbsuds_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbsuds_epi32(__W, __A, __B), (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_maskz_dpbsuds_epi32(
    __mmask8 __U, __m256i __W, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbsuds_epi32(__W, __A, __B),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbuud_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbuud_epi32(__W, __A, __B), (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbuud_epi32(__mmask8 __U, __m128i __W, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbuud_epi32(__W, __A, __B),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbuud_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbuud_epi32(__W, __A, __B), (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpbuud_epi32(__mmask8 __U, __m256i __W, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbuud_epi32(__W, __A, __B),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbuuds_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbuuds_epi32(__W, __A, __B), (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbuuds_epi32(__mmask8 __U, __m128i __W, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128(
      __U, (__v4si)_mm_dpbuuds_epi32(__W, __A, __B),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbuuds_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbuuds_epi32(__W, __A, __B), (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_maskz_dpbuuds_epi32(
    __mmask8 __U, __m256i __W, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256(
      __U, (__v8si)_mm256_dpbuuds_epi32(__W, __A, __B),
      (__v8si)_mm256_setzero_si256());
}

/* VNNI INT16 */
static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwsud_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwsud_epi32(__A, __B, __C), (__v4si)__A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwsud_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwsud_epi32(__A, __B, __C),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwsud_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwsud_epi32(__A, __B, __C), (__v8si)__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpwsud_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwsud_epi32(__A, __B, __C),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwsuds_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwsuds_epi32(__A, __B, __C), (__v4si)__A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwsuds_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwsuds_epi32(__A, __B, __C),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwsuds_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwsuds_epi32(__A, __B, __C), (__v8si)__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_maskz_dpwsuds_epi32(
    __m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwsuds_epi32(__A, __B, __C),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwusd_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwusd_epi32(__A, __B, __C), (__v4si)__A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwusd_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwusd_epi32(__A, __B, __C),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwusd_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwusd_epi32(__A, __B, __C), (__v8si)__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpwusd_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwusd_epi32(__A, __B, __C),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwusds_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwusds_epi32(__A, __B, __C), (__v4si)__A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwusds_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwusds_epi32(__A, __B, __C),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwusds_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwusds_epi32(__A, __B, __C), (__v8si)__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_maskz_dpwusds_epi32(
    __m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwusds_epi32(__A, __B, __C),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwuud_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwuud_epi32(__A, __B, __C), (__v4si)__A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwuud_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwuud_epi32(__A, __B, __C),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwuud_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwuud_epi32(__A, __B, __C), (__v8si)__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpwuud_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwuud_epi32(__A, __B, __C),
      (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwuuds_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwuuds_epi32(__A, __B, __C), (__v4si)__A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwuuds_epi32(__m128i __A, __mmask8 __U, __m128i __B, __m128i __C) {
  return (__m128i)__builtin_ia32_selectd_128(
      (__mmask8)__U, (__v4si)_mm_dpwuuds_epi32(__A, __B, __C),
      (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwuuds_epi32(__m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwuuds_epi32(__A, __B, __C), (__v8si)__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256 _mm256_maskz_dpwuuds_epi32(
    __m256i __A, __mmask8 __U, __m256i __B, __m256i __C) {
  return (__m256i)__builtin_ia32_selectd_256(
      (__mmask8)__U, (__v8si)_mm256_dpwuuds_epi32(__A, __B, __C),
      (__v8si)_mm256_setzero_si256());
}

/* YMM Rounding */
#define _mm256_add_round_pd(A, B, R)                                           \
  ((__m256d)__builtin_ia32_vaddpd256_round((__v4df)(__m256d)(A),               \
                                           (__v4df)(__m256d)(B), (int)(R)))

#define _mm256_mask_add_round_pd(W, U, A, B, R)                                \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_add_round_pd((A), (B), (R)),               \
      (__v4df)(__m256d)(W)))

#define _mm256_maskz_add_round_pd(U, A, B, R)                                  \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_add_round_pd((A), (B), (R)),               \
      (__v4df)_mm256_setzero_pd()))

#define _mm256_add_round_ph(A, B, R)                                           \
  ((__m256h)__builtin_ia32_vaddph256_round((__v16hf)(__m256h)(A),              \
                                           (__v16hf)(__m256h)(B), (int)(R)))

#define _mm256_mask_add_round_ph(W, U, A, B, R)                                \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_add_round_ph((A), (B), (R)),             \
      (__v16hf)(__m256h)(W)))

#define _mm256_maskz_add_round_ph(U, A, B, R)                                  \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_add_round_ph((A), (B), (R)),             \
      (__v16hf)_mm256_setzero_ph()))

#define _mm256_add_round_ps(A, B, R)                                           \
  ((__m256)__builtin_ia32_vaddps256_round((__v8sf)(__m256)(A),                 \
                                          (__v8sf)(__m256)(B), (int)(R)))

#define _mm256_mask_add_round_ps(W, U, A, B, R)                                \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_add_round_ps((A), (B), (R)),               \
      (__v8sf)(__m256)(W)))

#define _mm256_maskz_add_round_ps(U, A, B, R)                                  \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_add_round_ps((A), (B), (R)),               \
      (__v8sf)_mm256_setzero_ps()))

#define _mm256_cmp_round_pd_mask(A, B, P, R)                                   \
  ((__mmask8)__builtin_ia32_vcmppd256_round_mask(                              \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (int)(P), (__mmask8)-1,      \
      (int)(R)))

#define _mm256_mask_cmp_round_pd_mask(U, A, B, P, R)                           \
  ((__mmask8)__builtin_ia32_vcmppd256_round_mask(                              \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (int)(P), (__mmask8)(U),     \
      (int)(R)))

#define _mm256_cmp_round_ph_mask(A, B, P, R)                                   \
  ((__mmask16)__builtin_ia32_vcmpph256_round_mask(                             \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (int)(P), (__mmask16)-1,   \
      (int)(R)))

#define _mm256_mask_cmp_round_ph_mask(U, A, B, P, R)                           \
  ((__mmask16)__builtin_ia32_vcmpph256_round_mask(                             \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (int)(P), (__mmask16)(U),  \
      (int)(R)))

#define _mm256_cmp_round_ps_mask(A, B, P, R)                                   \
  ((__mmask8)__builtin_ia32_vcmpps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (int)(P), (__mmask8)-1,        \
      (int)(R)))

#define _mm256_mask_cmp_round_ps_mask(U, A, B, P, R)                           \
  ((__mmask8)__builtin_ia32_vcmpps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (int)(P), (__mmask8)(U),       \
      (int)(R)))

#define _mm256_cvt_roundepi32_ph(A, R)                                         \
  ((__m128h)__builtin_ia32_vcvtdq2ph256_round_mask(                            \
      (__v8si)(A), (__v8hf)_mm_undefined_ph(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvt_roundepi32_ph(W, U, A, R)                              \
  ((__m128h)__builtin_ia32_vcvtdq2ph256_round_mask((__v8si)(A), (__v8hf)(W),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepi32_ph(U, A, R)                                \
  ((__m128h)__builtin_ia32_vcvtdq2ph256_round_mask(                            \
      (__v8si)(A), (__v8hf)_mm_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundepi32_ps(A, R)                                         \
  ((__m256)__builtin_ia32_vcvtdq2ps256_round_mask((__v8si)(__m256i)(A),        \
                                                  (__v8sf)_mm256_setzero_ps(), \
                                                  (__mmask8)-1, (int)(R)))

#define _mm256_mask_cvt_roundepi32_ps(W, U, A, R)                              \
  ((__m256)__builtin_ia32_vcvtdq2ps256_round_mask(                             \
      (__v8si)(__m256i)(A), (__v8sf)(__m256)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepi32_ps(U, A, R)                                \
  ((__m256)__builtin_ia32_vcvtdq2ps256_round_mask((__v8si)(__m256i)(A),        \
                                                  (__v8sf)_mm256_setzero_ps(), \
                                                  (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundpd_epi32(A, R)                                         \
  ((__m128i)__builtin_ia32_vcvtpd2dq256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4si)_mm_setzero_si128(), (__mmask8)-1,         \
      (int)(R)))

#define _mm256_mask_cvt_roundpd_epi32(W, U, A, R)                              \
  ((__m128i)__builtin_ia32_vcvtpd2dq256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4si)(__m128i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundpd_epi32(U, A, R)                                \
  ((__m128i)__builtin_ia32_vcvtpd2dq256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4si)_mm_setzero_si128(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_cvt_roundpd_ph(A, R)                                            \
  ((__m128h)__builtin_ia32_vcvtpd2ph256_round_mask(                            \
      (__v4df)(A), (__v8hf)_mm_undefined_ph(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvt_roundpd_ph(W, U, A, R)                                 \
  ((__m128h)__builtin_ia32_vcvtpd2ph256_round_mask((__v4df)(A), (__v8hf)(W),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundpd_ph(U, A, R)                                   \
  ((__m128h)__builtin_ia32_vcvtpd2ph256_round_mask(                            \
      (__v4df)(A), (__v8hf)_mm_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundpd_ps(A, R)                                            \
  ((__m128)__builtin_ia32_vcvtpd2ps256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4sf)_mm_setzero_ps(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_cvt_roundpd_ps(W, U, A, R)                                 \
  ((__m128)__builtin_ia32_vcvtpd2ps256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4sf)(__m128)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundpd_ps(U, A, R)                                   \
  ((__m128)__builtin_ia32_vcvtpd2ps256_round_mask((__v4df)(__m256d)(A),        \
                                                  (__v4sf)_mm_setzero_ps(),    \
                                                  (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundpd_epi64(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtpd2qq256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)-1,      \
      (int)(R)))

#define _mm256_mask_cvt_roundpd_epi64(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtpd2qq256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4di)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundpd_epi64(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtpd2qq256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)(U),     \
      (int)(R)))

#define _mm256_cvt_roundpd_epu32(A, R)                                         \
  ((__m128i)__builtin_ia32_vcvtpd2udq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4su)_mm_setzero_si128(), (__mmask8)-1,         \
      (int)(R)))

#define _mm256_mask_cvt_roundpd_epu32(W, U, A, R)                              \
  ((__m128i)__builtin_ia32_vcvtpd2udq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4su)(__m128i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundpd_epu32(U, A, R)                                \
  ((__m128i)__builtin_ia32_vcvtpd2udq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4su)_mm_setzero_si128(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_cvt_roundpd_epu64(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtpd2uqq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)-1,      \
      (int)(R)))

#define _mm256_mask_cvt_roundpd_epu64(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtpd2uqq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4du)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundpd_epu64(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtpd2uqq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)(U),     \
      (int)(R)))

#define _mm256_cvt_roundph_epi32(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtph2dq256_round_mask(                            \
      (__v8hf)(A), (__v8si)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvt_roundph_epi32(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtph2dq256_round_mask((__v8hf)(A), (__v8si)(W),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundph_epi32(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtph2dq256_round_mask(                            \
      (__v8hf)(A), (__v8si)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundph_pd(A, R)                                            \
  ((__m256d)__builtin_ia32_vcvtph2pd256_round_mask(                            \
      (__v8hf)(A), (__v4df)_mm256_undefined_pd(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvt_roundph_pd(W, U, A, R)                                 \
  ((__m256d)__builtin_ia32_vcvtph2pd256_round_mask((__v8hf)(A), (__v4df)(W),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundph_pd(U, A, R)                                   \
  ((__m256d)__builtin_ia32_vcvtph2pd256_round_mask(                            \
      (__v8hf)(A), (__v4df)_mm256_setzero_pd(), (__mmask8)(U), (int)(R)))

#define _mm256_cvtx_roundph_ps(A, R)                                           \
  ((__m256)__builtin_ia32_vcvtph2psx256_round_mask(                            \
      (__v8hf)(A), (__v8sf)_mm256_undefined_ps(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvtx_roundph_ps(W, U, A, R)                                \
  ((__m256)__builtin_ia32_vcvtph2psx256_round_mask((__v8hf)(A), (__v8sf)(W),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtx_roundph_ps(U, A, R)                                  \
  ((__m256)__builtin_ia32_vcvtph2psx256_round_mask(                            \
      (__v8hf)(A), (__v8sf)_mm256_setzero_ps(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundph_epi64(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtph2qq256_round_mask(                            \
      (__v8hf)(A), (__v4di)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvt_roundph_epi64(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtph2qq256_round_mask((__v8hf)(A), (__v4di)(W),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundph_epi64(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtph2qq256_round_mask(                            \
      (__v8hf)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundph_epu32(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtph2udq256_round_mask(                           \
      (__v8hf)(A), (__v8su)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvt_roundph_epu32(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtph2udq256_round_mask((__v8hf)(A), (__v8su)(W),  \
                                                    (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundph_epu32(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtph2udq256_round_mask(                           \
      (__v8hf)(A), (__v8su)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundph_epu64(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtph2uqq256_round_mask(                           \
      (__v8hf)(A), (__v4du)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvt_roundph_epu64(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtph2uqq256_round_mask((__v8hf)(A), (__v4du)(W),  \
                                                    (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundph_epu64(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtph2uqq256_round_mask(                           \
      (__v8hf)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundph_epu16(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtph2uw256_round_mask(                            \
      (__v16hf)(A), (__v16hu)_mm256_undefined_si256(), (__mmask16)(-1),        \
      (int)(R)))

#define _mm256_mask_cvt_roundph_epu16(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtph2uw256_round_mask((__v16hf)(A), (__v16hu)(W), \
                                                   (__mmask16)(U), (int)(R)))

#define _mm256_maskz_cvt_roundph_epu16(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtph2uw256_round_mask(                            \
      (__v16hf)(A), (__v16hu)_mm256_setzero_si256(), (__mmask16)(U),           \
      (int)(R)))

#define _mm256_cvt_roundph_epi16(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtph2w256_round_mask(                             \
      (__v16hf)(A), (__v16hi)_mm256_undefined_si256(), (__mmask16)(-1),        \
      (int)(R)))

#define _mm256_mask_cvt_roundph_epi16(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtph2w256_round_mask((__v16hf)(A), (__v16hi)(W),  \
                                                  (__mmask16)(U), (int)(R)))

#define _mm256_maskz_cvt_roundph_epi16(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtph2w256_round_mask(                             \
      (__v16hf)(A), (__v16hi)_mm256_setzero_si256(), (__mmask16)(U),           \
      (int)(R)))

#define _mm256_cvt_roundps_epi32(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtps2dq256_round_mask(                            \
      (__v8sf)(__m256)(A), (__v8si)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvt_roundps_epi32(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtps2dq256_round_mask(                            \
      (__v8sf)(__m256)(A), (__v8si)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundps_epi32(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtps2dq256_round_mask(                            \
      (__v8sf)(__m256)(A), (__v8si)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvt_roundps_pd(A, R)                                            \
  ((__m256d)__builtin_ia32_vcvtps2pd256_round_mask(                            \
      (__v4sf)(__m128)(A), (__v4df)_mm256_undefined_pd(), (__mmask8)-1,        \
      (int)(R)))

#define _mm256_mask_cvt_roundps_pd(W, U, A, R)                                 \
  ((__m256d)__builtin_ia32_vcvtps2pd256_round_mask(                            \
      (__v4sf)(__m128)(A), (__v4df)(__m256d)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundps_pd(U, A, R)                                   \
  ((__m256d)__builtin_ia32_vcvtps2pd256_round_mask(                            \
      (__v4sf)(__m128)(A), (__v4df)_mm256_setzero_pd(), (__mmask8)(U),         \
      (int)(R)))

#define _mm256_cvt_roundps_ph(A, I)                                            \
  ((__m128i)__builtin_ia32_vcvtps2ph256_mask((__v8sf)(__m256)(A), (int)(I),    \
                                             (__v8hi)_mm_undefined_si128(),    \
                                             (__mmask8)-1))

/* FIXME: We may use these way in future.
#define _mm256_cvt_roundps_ph(A, I)                                            \
  ((__m128i)__builtin_ia32_vcvtps2ph256_round_mask(                            \
      (__v8sf)(__m256)(A), (int)(I), (__v8hi)_mm_undefined_si128(),            \
      (__mmask8)-1))
#define _mm256_mask_cvt_roundps_ph(U, W, A, I)                                 \
  ((__m128i)__builtin_ia32_vcvtps2ph256_round_mask(                            \
      (__v8sf)(__m256)(A), (int)(I), (__v8hi)(__m128i)(U), (__mmask8)(W)))
#define _mm256_maskz_cvt_roundps_ph(W, A, I)                                   \
  ((__m128i)__builtin_ia32_vcvtps2ph256_round_mask(                            \
      (__v8sf)(__m256)(A), (int)(I), (__v8hi)_mm_setzero_si128(),              \
      (__mmask8)(W))) */

#define _mm256_cvtx_roundps_ph(A, R)                                           \
  ((__m128h)__builtin_ia32_vcvtps2phx256_round_mask(                           \
      (__v8sf)(A), (__v8hf)_mm_undefined_ph(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvtx_roundps_ph(W, U, A, R)                                \
  ((__m128h)__builtin_ia32_vcvtps2phx256_round_mask((__v8sf)(A), (__v8hf)(W),  \
                                                    (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtx_roundps_ph(U, A, R)                                  \
  ((__m128h)__builtin_ia32_vcvtps2phx256_round_mask(                           \
      (__v8sf)(A), (__v8hf)_mm_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundps_epi64(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtps2qq256_round_mask(                            \
      (__v4sf)(__m128)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvt_roundps_epi64(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtps2qq256_round_mask(                            \
      (__v4sf)(__m128)(A), (__v4di)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundps_epi64(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtps2qq256_round_mask(                            \
      (__v4sf)(__m128)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvt_roundps_epu32(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtps2udq256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8su)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvt_roundps_epu32(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtps2udq256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8su)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundps_epu32(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtps2udq256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8su)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvt_roundps_epu64(A, R)                                         \
  ((__m256i)__builtin_ia32_vcvtps2uqq256_round_mask(                           \
      (__v4sf)(__m128)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvt_roundps_epu64(W, U, A, R)                              \
  ((__m256i)__builtin_ia32_vcvtps2uqq256_round_mask(                           \
      (__v4sf)(__m128)(A), (__v4du)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundps_epu64(U, A, R)                                \
  ((__m256i)__builtin_ia32_vcvtps2uqq256_round_mask(                           \
      (__v4sf)(__m128)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvt_roundepi64_pd(A, R)                                         \
  ((__m256d)__builtin_ia32_vcvtqq2pd256_round_mask(                            \
      (__v4di)(__m256i)(A), (__v4df)_mm256_setzero_pd(), (__mmask8)-1,         \
      (int)(R)))

#define _mm256_mask_cvt_roundepi64_pd(W, U, A, R)                              \
  ((__m256d)__builtin_ia32_vcvtqq2pd256_round_mask(                            \
      (__v4di)(__m256i)(A), (__v4df)(__m256d)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepi64_pd(U, A, R)                                \
  ((__m256d)__builtin_ia32_vcvtqq2pd256_round_mask(                            \
      (__v4di)(__m256i)(A), (__v4df)_mm256_setzero_pd(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_cvt_roundepi64_ph(A, R)                                         \
  ((__m128h)__builtin_ia32_vcvtqq2ph256_round_mask(                            \
      (__v4di)(A), (__v8hf)_mm_undefined_ph(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvt_roundepi64_ph(W, U, A, R)                              \
  ((__m128h)__builtin_ia32_vcvtqq2ph256_round_mask((__v4di)(A), (__v8hf)(W),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepi64_ph(U, A, R)                                \
  ((__m128h)__builtin_ia32_vcvtqq2ph256_round_mask(                            \
      (__v4di)(A), (__v8hf)_mm_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundepi64_ps(A, R)                                         \
  ((__m128)__builtin_ia32_vcvtqq2ps256_round_mask(                             \
      (__v4di)(__m256i)(A), (__v4sf)_mm_setzero_ps(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_cvt_roundepi64_ps(W, U, A, R)                              \
  ((__m128)__builtin_ia32_vcvtqq2ps256_round_mask(                             \
      (__v4di)(__m256i)(A), (__v4sf)(__m128)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepi64_ps(U, A, R)                                \
  ((__m128)__builtin_ia32_vcvtqq2ps256_round_mask((__v4di)(__m256i)(A),        \
                                                  (__v4sf)_mm_setzero_ps(),    \
                                                  (__mmask8)(U), (int)(R)))

#define _mm256_cvtt_roundpd_epi32(A, R)                                        \
  ((__m128i)__builtin_ia32_vcvttpd2dq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4si)_mm_setzero_si128(), (__mmask8)-1,         \
      (int)(R)))

#define _mm256_mask_cvtt_roundpd_epi32(W, U, A, R)                             \
  ((__m128i)__builtin_ia32_vcvttpd2dq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4si)(__m128i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundpd_epi32(U, A, R)                               \
  ((__m128i)__builtin_ia32_vcvttpd2dq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4si)_mm_setzero_si128(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_cvtt_roundpd_epi64(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttpd2qq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)-1,      \
      (int)(R)))

#define _mm256_mask_cvtt_roundpd_epi64(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttpd2qq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4di)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundpd_epi64(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttpd2qq256_round_mask(                           \
      (__v4df)(__m256d)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)(U),     \
      (int)(R)))

#define _mm256_cvtt_roundpd_epu32(A, R)                                        \
  ((__m128i)__builtin_ia32_vcvttpd2udq256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4su)_mm_setzero_si128(), (__mmask8)-1,         \
      (int)(R)))

#define _mm256_mask_cvtt_roundpd_epu32(W, U, A, R)                             \
  ((__m128i)__builtin_ia32_vcvttpd2udq256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4su)(__m128i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundpd_epu32(U, A, R)                               \
  ((__m128i)__builtin_ia32_vcvttpd2udq256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4su)_mm_setzero_si128(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_cvtt_roundpd_epu64(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttpd2uqq256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)-1,      \
      (int)(R)))

#define _mm256_mask_cvtt_roundpd_epu64(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttpd2uqq256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4du)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundpd_epu64(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttpd2uqq256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)(U),     \
      (int)(R)))

#define _mm256_cvtt_roundph_epi32(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttph2dq256_round_mask(                           \
      (__v8hf)(A), (__v8si)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvtt_roundph_epi32(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttph2dq256_round_mask((__v8hf)(A), (__v8si)(W),  \
                                                    (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundph_epi32(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttph2dq256_round_mask(                           \
      (__v8hf)(A), (__v8si)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvtt_roundph_epi64(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttph2qq256_round_mask(                           \
      (__v8hf)(A), (__v4di)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvtt_roundph_epi64(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttph2qq256_round_mask((__v8hf)(A), (__v4di)(W),  \
                                                    (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundph_epi64(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttph2qq256_round_mask(                           \
      (__v8hf)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvtt_roundph_epu32(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttph2udq256_round_mask(                          \
      (__v8hf)(A), (__v8su)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvtt_roundph_epu32(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttph2udq256_round_mask((__v8hf)(A), (__v8su)(W), \
                                                     (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundph_epu32(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttph2udq256_round_mask(                          \
      (__v8hf)(A), (__v8su)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvtt_roundph_epu64(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttph2uqq256_round_mask(                          \
      (__v8hf)(A), (__v4du)_mm256_undefined_si256(), (__mmask8)(-1),           \
      (int)(R)))

#define _mm256_mask_cvtt_roundph_epu64(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttph2uqq256_round_mask((__v8hf)(A), (__v4du)(W), \
                                                     (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundph_epu64(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttph2uqq256_round_mask(                          \
      (__v8hf)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)(U), (int)(R)))

#define _mm256_cvtt_roundph_epu16(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttph2uw256_round_mask(                           \
      (__v16hf)(A), (__v16hu)_mm256_undefined_si256(), (__mmask16)(-1),        \
      (int)(R)))

#define _mm256_mask_cvtt_roundph_epu16(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttph2uw256_round_mask(                           \
      (__v16hf)(A), (__v16hu)(W), (__mmask16)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundph_epu16(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttph2uw256_round_mask(                           \
      (__v16hf)(A), (__v16hu)_mm256_setzero_si256(), (__mmask16)(U),           \
      (int)(R)))

#define _mm256_cvtt_roundph_epi16(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttph2w256_round_mask(                            \
      (__v16hf)(A), (__v16hi)_mm256_undefined_si256(), (__mmask16)(-1),        \
      (int)(R)))

#define _mm256_mask_cvtt_roundph_epi16(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttph2w256_round_mask((__v16hf)(A), (__v16hi)(W), \
                                                   (__mmask16)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundph_epi16(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttph2w256_round_mask(                            \
      (__v16hf)(A), (__v16hi)_mm256_setzero_si256(), (__mmask16)(U),           \
      (int)(R)))

#define _mm256_cvtt_roundps_epi32(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttps2dq256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8si)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvtt_roundps_epi32(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttps2dq256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8si)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundps_epi32(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttps2dq256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8si)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvtt_roundps_epi64(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttps2qq256_round_mask(                           \
      (__v4sf)(__m128)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvtt_roundps_epi64(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttps2qq256_round_mask(                           \
      (__v4sf)(__m128)(A), (__v4di)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundps_epi64(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttps2qq256_round_mask(                           \
      (__v4sf)(__m128)(A), (__v4di)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvtt_roundps_epu32(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttps2udq256_round_mask(                          \
      (__v8sf)(__m256)(A), (__v8su)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvtt_roundps_epu32(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttps2udq256_round_mask(                          \
      (__v8sf)(__m256)(A), (__v8su)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundps_epu32(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttps2udq256_round_mask(                          \
      (__v8sf)(__m256)(A), (__v8su)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvtt_roundps_epu64(A, R)                                        \
  ((__m256i)__builtin_ia32_vcvttps2uqq256_round_mask(                          \
      (__v4sf)(__m128)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_cvtt_roundps_epu64(W, U, A, R)                             \
  ((__m256i)__builtin_ia32_vcvttps2uqq256_round_mask(                          \
      (__v4sf)(__m128)(A), (__v4du)(__m256i)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvtt_roundps_epu64(U, A, R)                               \
  ((__m256i)__builtin_ia32_vcvttps2uqq256_round_mask(                          \
      (__v4sf)(__m128)(A), (__v4du)_mm256_setzero_si256(), (__mmask8)(U),      \
      (int)(R)))

#define _mm256_cvt_roundepu32_ph(A, R)                                         \
  ((__m128h)__builtin_ia32_vcvtudq2ph256_round_mask(                           \
      (__v8su)(A), (__v8hf)_mm_undefined_ph(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvt_roundepu32_ph(W, U, A, R)                              \
  ((__m128h)__builtin_ia32_vcvtudq2ph256_round_mask((__v8su)(A), (__v8hf)(W),  \
                                                    (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepu32_ph(U, A, R)                                \
  ((__m128h)__builtin_ia32_vcvtudq2ph256_round_mask(                           \
      (__v8su)(A), (__v8hf)_mm_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundepu32_ps(A, R)                                         \
  ((__m256)__builtin_ia32_vcvtudq2ps256_round_mask(                            \
      (__v8su)(__m256i)(A), (__v8sf)_mm256_setzero_ps(), (__mmask8)-1,         \
      (int)(R)))

#define _mm256_mask_cvt_roundepu32_ps(W, U, A, R)                              \
  ((__m256)__builtin_ia32_vcvtudq2ps256_round_mask(                            \
      (__v8su)(__m256i)(A), (__v8sf)(__m256)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepu32_ps(U, A, R)                                \
  ((__m256)__builtin_ia32_vcvtudq2ps256_round_mask(                            \
      (__v8su)(__m256i)(A), (__v8sf)_mm256_setzero_ps(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_cvt_roundepu64_pd(A, R)                                         \
  ((__m256d)__builtin_ia32_vcvtuqq2pd256_round_mask(                           \
      (__v4du)(__m256i)(A), (__v4df)_mm256_setzero_pd(), (__mmask8)-1,         \
      (int)(R)))

#define _mm256_mask_cvt_roundepu64_pd(W, U, A, R)                              \
  ((__m256d)__builtin_ia32_vcvtuqq2pd256_round_mask(                           \
      (__v4du)(__m256i)(A), (__v4df)(__m256d)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepu64_pd(U, A, R)                                \
  ((__m256d)__builtin_ia32_vcvtuqq2pd256_round_mask(                           \
      (__v4du)(__m256i)(A), (__v4df)_mm256_setzero_pd(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_cvt_roundepu64_ph(A, R)                                         \
  ((__m128h)__builtin_ia32_vcvtuqq2ph256_round_mask(                           \
      (__v4du)(A), (__v8hf)_mm_undefined_ph(), (__mmask8)(-1), (int)(R)))

#define _mm256_mask_cvt_roundepu64_ph(W, U, A, R)                              \
  ((__m128h)__builtin_ia32_vcvtuqq2ph256_round_mask((__v4du)(A), (__v8hf)(W),  \
                                                    (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepu64_ph(U, A, R)                                \
  ((__m128h)__builtin_ia32_vcvtuqq2ph256_round_mask(                           \
      (__v4du)(A), (__v8hf)_mm_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundepu64_ps(A, R)                                         \
  ((__m128)__builtin_ia32_vcvtuqq2ps256_round_mask(                            \
      (__v4du)(__m256i)(A), (__v4sf)_mm_setzero_ps(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_cvt_roundepu64_ps(W, U, A, R)                              \
  ((__m128)__builtin_ia32_vcvtuqq2ps256_round_mask(                            \
      (__v4du)(__m256i)(A), (__v4sf)(__m128)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepu64_ps(U, A, R)                                \
  ((__m128)__builtin_ia32_vcvtuqq2ps256_round_mask((__v4du)(__m256i)(A),       \
                                                   (__v4sf)_mm_setzero_ps(),   \
                                                   (__mmask8)(U), (int)(R)))

#define _mm256_cvt_roundepu16_ph(A, R)                                         \
  ((__m256h)__builtin_ia32_vcvtuw2ph256_round_mask(                            \
      (__v16hu)(A), (__v16hf)_mm256_undefined_ph(), (__mmask16)(-1),           \
      (int)(R)))

#define _mm256_mask_cvt_roundepu16_ph(W, U, A, R)                              \
  ((__m256h)__builtin_ia32_vcvtuw2ph256_round_mask((__v16hu)(A), (__v16hf)(W), \
                                                   (__mmask16)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepu16_ph(U, A, R)                                \
  ((__m256h)__builtin_ia32_vcvtuw2ph256_round_mask(                            \
      (__v16hu)(A), (__v16hf)_mm256_setzero_ph(), (__mmask16)(U), (int)(R)))

#define _mm256_cvt_roundepi16_ph(A, R)                                         \
  ((__m256h)__builtin_ia32_vcvtw2ph256_round_mask(                             \
      (__v16hi)(A), (__v16hf)_mm256_undefined_ph(), (__mmask16)(-1),           \
      (int)(R)))

#define _mm256_mask_cvt_roundepi16_ph(W, U, A, R)                              \
  ((__m256h)__builtin_ia32_vcvtw2ph256_round_mask((__v16hi)(A), (__v16hf)(W),  \
                                                  (__mmask16)(U), (int)(R)))

#define _mm256_maskz_cvt_roundepi16_ph(U, A, R)                                \
  ((__m256h)__builtin_ia32_vcvtw2ph256_round_mask(                             \
      (__v16hi)(A), (__v16hf)_mm256_setzero_ph(), (__mmask16)(U), (int)(R)))

#define _mm256_div_round_pd(A, B, R)                                           \
  ((__m256d)__builtin_ia32_vdivpd256_round((__v4df)(__m256d)(A),               \
                                           (__v4df)(__m256d)(B), (int)(R)))

#define _mm256_mask_div_round_pd(W, U, A, B, R)                                \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_div_round_pd((A), (B), (R)),               \
      (__v4df)(__m256d)(W)))

#define _mm256_maskz_div_round_pd(U, A, B, R)                                  \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_div_round_pd((A), (B), (R)),               \
      (__v4df)_mm256_setzero_pd()))

#define _mm256_div_round_ph(A, B, R)                                           \
  ((__m256h)__builtin_ia32_vdivph256_round((__v16hf)(__m256h)(A),              \
                                           (__v16hf)(__m256h)(B), (int)(R)))

#define _mm256_mask_div_round_ph(W, U, A, B, R)                                \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_div_round_ph((A), (B), (R)),             \
      (__v16hf)(__m256h)(W)))

#define _mm256_maskz_div_round_ph(U, A, B, R)                                  \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_div_round_ph((A), (B), (R)),             \
      (__v16hf)_mm256_setzero_ph()))

#define _mm256_div_round_ps(A, B, R)                                           \
  ((__m256)__builtin_ia32_vdivps256_round((__v8sf)(__m256)(A),                 \
                                          (__v8sf)(__m256)(B), (int)(R)))

#define _mm256_mask_div_round_ps(W, U, A, B, R)                                \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_div_round_ps((A), (B), (R)),               \
      (__v8sf)(__m256)(W)))

#define _mm256_maskz_div_round_ps(U, A, B, R)                                  \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_div_round_ps((A), (B), (R)),               \
      (__v8sf)_mm256_setzero_ps()))

#define _mm256_fcmadd_round_pch(A, B, C, R)                                    \
  ((__m256h)__builtin_ia32_vfcmaddcph256_round_mask3(                          \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fcmadd_round_pch(A, U, B, C, R)                            \
  ((__m256h)__builtin_ia32_vfcmaddcph256_round_mask(                           \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fcmadd_round_pch(A, B, C, U, R)                           \
  ((__m256h)__builtin_ia32_vfcmaddcph256_round_mask3(                          \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fcmadd_round_pch(U, A, B, C, R)                           \
  ((__m256h)__builtin_ia32_vfcmaddcph256_round_maskz(                          \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_cmul_round_pch(A, B, R)                                         \
  ((__m256h)__builtin_ia32_vfcmulcph256_round_mask(                            \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B),                              \
      (__v8sf)(__m256h)_mm256_undefined_ph(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_cmul_round_pch(W, U, A, B, R)                              \
  ((__m256h)__builtin_ia32_vfcmulcph256_round_mask(                            \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(W),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_cmul_round_pch(U, A, B, R)                                \
  ((__m256h)__builtin_ia32_vfcmulcph256_round_mask(                            \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B),                              \
      (__v8sf)(__m256h)_mm256_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_fixupimm_round_pd(A, B, C, imm, R)                              \
  ((__m256d)__builtin_ia32_vfixupimmpd256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4di)(__m256i)(C),        \
      (int)(imm), (__mmask8)-1, (int)(R)))

#define _mm256_mask_fixupimm_round_pd(A, U, B, C, imm, R)                      \
  ((__m256d)__builtin_ia32_vfixupimmpd256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4di)(__m256i)(C),        \
      (int)(imm), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fixupimm_round_pd(U, A, B, C, imm, R)                     \
  ((__m256d)__builtin_ia32_vfixupimmpd256_round_maskz(                         \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4di)(__m256i)(C),        \
      (int)(imm), (__mmask8)(U), (int)(R)))

#define _mm256_fixupimm_round_ps(A, B, C, imm, R)                              \
  ((__m256)__builtin_ia32_vfixupimmps256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8si)(__m256i)(C),          \
      (int)(imm), (__mmask8)-1, (int)(R)))

#define _mm256_mask_fixupimm_round_ps(A, U, B, C, imm, R)                      \
  ((__m256)__builtin_ia32_vfixupimmps256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8si)(__m256i)(C),          \
      (int)(imm), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fixupimm_round_ps(U, A, B, C, imm, R)                     \
  ((__m256)__builtin_ia32_vfixupimmps256_round_maskz(                          \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8si)(__m256i)(C),          \
      (int)(imm), (__mmask8)(U), (int)(R)))

#define _mm256_fmadd_round_pd(A, B, C, R)                                      \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmadd_round_pd(A, U, B, C, R)                              \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmadd_round_pd(A, B, C, U, R)                             \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask3(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmadd_round_pd(U, A, B, C, R)                             \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_maskz(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmsub_round_pd(A, B, C, R)                                      \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),       \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmsub_round_pd(A, U, B, C, R)                              \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmsub_round_pd(U, A, B, C, R)                             \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_maskz(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_fnmadd_round_pd(A, B, C, R)                                     \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      -(__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),       \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask3_fnmadd_round_pd(A, B, C, U, R)                            \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask3(                            \
      -(__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fnmadd_round_pd(U, A, B, C, R)                            \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_maskz(                            \
      -(__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_fnmsub_round_pd(A, B, C, R)                                     \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      -(__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),      \
      (__mmask8)-1, (int)(R)))

#define _mm256_maskz_fnmsub_round_pd(U, A, B, C, R)                            \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_maskz(                            \
      -(__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),      \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmadd_round_ph(A, B, C, R)                                      \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)-1, (int)(R)))

#define _mm256_mask_fmadd_round_ph(A, U, B, C, R)                              \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_mask3_fmadd_round_ph(A, B, C, U, R)                             \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask3(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_fmadd_round_ph(U, A, B, C, R)                             \
  ((__m256h)__builtin_ia32_vfmaddph256_round_maskz(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_fmsub_round_ph(A, B, C, R)                                      \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),    \
      (__mmask16)-1, (int)(R)))

#define _mm256_mask_fmsub_round_ph(A, U, B, C, R)                              \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_fmsub_round_ph(U, A, B, C, R)                             \
  ((__m256h)__builtin_ia32_vfmaddph256_round_maskz(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_fnmadd_round_ph(A, B, C, R)                                     \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), -(__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),    \
      (__mmask16)-1, (int)(R)))

#define _mm256_mask3_fnmadd_round_ph(A, B, C, U, R)                            \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask3(                            \
      -(__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_fnmadd_round_ph(U, A, B, C, R)                            \
  ((__m256h)__builtin_ia32_vfmaddph256_round_maskz(                            \
      -(__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_fnmsub_round_ph(A, B, C, R)                                     \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), -(__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),   \
      (__mmask16)-1, (int)(R)))

#define _mm256_maskz_fnmsub_round_ph(U, A, B, C, R)                            \
  ((__m256h)__builtin_ia32_vfmaddph256_round_maskz(                            \
      -(__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),   \
      (__mmask16)(U), (int)(R)))

#define _mm256_fmadd_round_ps(A, B, C, R)                                      \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmadd_round_ps(A, U, B, C, R)                              \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmadd_round_ps(A, B, C, U, R)                             \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask3(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmadd_round_ps(U, A, B, C, R)                             \
  ((__m256)__builtin_ia32_vfmaddps256_round_maskz(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmsub_round_ps(A, B, C, R)                                      \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),          \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmsub_round_ps(A, U, B, C, R)                              \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmsub_round_ps(U, A, B, C, R)                             \
  ((__m256)__builtin_ia32_vfmaddps256_round_maskz(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))

#define _mm256_fnmadd_round_ps(A, B, C, R)                                     \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), -(__v8sf)(__m256)(B), (__v8sf)(__m256)(C),          \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask3_fnmadd_round_ps(A, B, C, U, R)                            \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask3(                             \
      -(__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fnmadd_round_ps(U, A, B, C, R)                            \
  ((__m256)__builtin_ia32_vfmaddps256_round_maskz(                             \
      -(__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))

#define _mm256_fnmsub_round_ps(A, B, C, R)                                     \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), -(__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),         \
      (__mmask8)-1, (int)(R)))

#define _mm256_maskz_fnmsub_round_ps(U, A, B, C, R)                            \
  ((__m256)__builtin_ia32_vfmaddps256_round_maskz(                             \
      -(__v8sf)(__m256)(A), (__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),         \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmadd_round_pch(A, B, C, R)                                     \
  ((__m256h)__builtin_ia32_vfmaddcph256_round_mask3(                           \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmadd_round_pch(A, U, B, C, R)                             \
  ((__m256h)__builtin_ia32_vfmaddcph256_round_mask(                            \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmadd_round_pch(A, B, C, U, R)                            \
  ((__m256h)__builtin_ia32_vfmaddcph256_round_mask3(                           \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmadd_round_pch(U, A, B, C, R)                            \
  ((__m256h)__builtin_ia32_vfmaddcph256_round_maskz(                           \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmaddsub_round_pd(A, B, C, R)                                   \
  ((__m256d)__builtin_ia32_vfmaddsubpd256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmaddsub_round_pd(A, U, B, C, R)                           \
  ((__m256d)__builtin_ia32_vfmaddsubpd256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmaddsub_round_pd(A, B, C, U, R)                          \
  ((__m256d)__builtin_ia32_vfmaddsubpd256_round_mask3(                         \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmaddsub_round_pd(U, A, B, C, R)                          \
  ((__m256d)__builtin_ia32_vfmaddsubpd256_round_maskz(                         \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmsubadd_round_pd(A, B, C, R)                                   \
  ((__m256d)__builtin_ia32_vfmaddsubpd256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),       \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmsubadd_round_pd(A, U, B, C, R)                           \
  ((__m256d)__builtin_ia32_vfmaddsubpd256_round_mask(                          \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmsubadd_round_pd(U, A, B, C, R)                          \
  ((__m256d)__builtin_ia32_vfmaddsubpd256_round_maskz(                         \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmaddsub_round_ph(A, B, C, R)                                   \
  ((__m256h)__builtin_ia32_vfmaddsubph256_round_mask(                          \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)-1, (int)(R)))

#define _mm256_mask_fmaddsub_round_ph(A, U, B, C, R)                           \
  ((__m256h)__builtin_ia32_vfmaddsubph256_round_mask(                          \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_mask3_fmaddsub_round_ph(A, B, C, U, R)                          \
  ((__m256h)__builtin_ia32_vfmaddsubph256_round_mask3(                         \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_fmaddsub_round_ph(U, A, B, C, R)                          \
  ((__m256h)__builtin_ia32_vfmaddsubph256_round_maskz(                         \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_fmsubadd_round_ph(A, B, C, R)                                   \
  ((__m256h)__builtin_ia32_vfmaddsubph256_round_mask(                          \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),    \
      (__mmask16)-1, (int)(R)))

#define _mm256_mask_fmsubadd_round_ph(A, U, B, C, R)                           \
  ((__m256h)__builtin_ia32_vfmaddsubph256_round_mask(                          \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_fmsubadd_round_ph(U, A, B, C, R)                          \
  ((__m256h)__builtin_ia32_vfmaddsubph256_round_maskz(                         \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_fmaddsub_round_ps(A, B, C, R)                                   \
  ((__m256)__builtin_ia32_vfmaddsubps256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmaddsub_round_ps(A, U, B, C, R)                           \
  ((__m256)__builtin_ia32_vfmaddsubps256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmaddsub_round_ps(A, B, C, U, R)                          \
  ((__m256)__builtin_ia32_vfmaddsubps256_round_mask3(                          \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmaddsub_round_ps(U, A, B, C, R)                          \
  ((__m256)__builtin_ia32_vfmaddsubps256_round_maskz(                          \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_fmsubadd_round_ps(A, B, C, R)                                   \
  ((__m256)__builtin_ia32_vfmaddsubps256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),          \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_fmsubadd_round_ps(A, U, B, C, R)                           \
  ((__m256)__builtin_ia32_vfmaddsubps256_round_mask(                           \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_fmsubadd_round_ps(U, A, B, C, R)                          \
  ((__m256)__builtin_ia32_vfmaddsubps256_round_maskz(                          \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))
#define _mm256_mask3_fmsub_round_pd(A, B, C, U, R)                             \
  ((__m256d)__builtin_ia32_vfmsubpd256_round_mask3(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmsubadd_round_pd(A, B, C, U, R)                          \
  ((__m256d)__builtin_ia32_vfmsubaddpd256_round_mask3(                         \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask_fnmadd_round_pd(A, U, B, C, R)                             \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      (__v4df)(__m256d)(A), -(__v4df)(__m256d)(B), (__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask_fnmsub_round_pd(A, U, B, C, R)                             \
  ((__m256d)__builtin_ia32_vfmaddpd256_round_mask(                             \
      (__v4df)(__m256d)(A), -(__v4df)(__m256d)(B), -(__v4df)(__m256d)(C),      \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fnmsub_round_pd(A, B, C, U, R)                            \
  ((__m256d)__builtin_ia32_vfmsubpd256_round_mask3(                            \
      -(__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(C),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmsub_round_ph(A, B, C, U, R)                             \
  ((__m256h)__builtin_ia32_vfmsubph256_round_mask3(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_mask3_fmsubadd_round_ph(A, B, C, U, R)                          \
  ((__m256h)__builtin_ia32_vfmsubaddph256_round_mask3(                         \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_mask_fnmadd_round_ph(A, U, B, C, R)                             \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), -(__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_mask_fnmsub_round_ph(A, U, B, C, R)                             \
  ((__m256h)__builtin_ia32_vfmaddph256_round_mask(                             \
      (__v16hf)(__m256h)(A), -(__v16hf)(__m256h)(B), -(__v16hf)(__m256h)(C),   \
      (__mmask16)(U), (int)(R)))

#define _mm256_mask3_fnmsub_round_ph(A, B, C, U, R)                            \
  ((__m256h)__builtin_ia32_vfmsubph256_round_mask3(                            \
      -(__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(C),    \
      (__mmask16)(U), (int)(R)))

#define _mm256_mask3_fmsub_round_ps(A, B, C, U, R)                             \
  ((__m256)__builtin_ia32_vfmsubps256_round_mask3(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fmsubadd_round_ps(A, B, C, U, R)                          \
  ((__m256)__builtin_ia32_vfmsubaddps256_round_mask3(                          \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask_fnmadd_round_ps(A, U, B, C, R)                             \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), -(__v8sf)(__m256)(B), (__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask_fnmsub_round_ps(A, U, B, C, R)                             \
  ((__m256)__builtin_ia32_vfmaddps256_round_mask(                              \
      (__v8sf)(__m256)(A), -(__v8sf)(__m256)(B), -(__v8sf)(__m256)(C),         \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask3_fnmsub_round_ps(A, B, C, U, R)                            \
  ((__m256)__builtin_ia32_vfmsubps256_round_mask3(                             \
      -(__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(C),          \
      (__mmask8)(U), (int)(R)))

#define _mm256_mul_round_pch(A, B, R)                                          \
  ((__m256h)__builtin_ia32_vfmulcph256_round_mask(                             \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B),                              \
      (__v8sf)(__m256h)_mm256_undefined_ph(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_mul_round_pch(W, U, A, B, R)                               \
  ((__m256h)__builtin_ia32_vfmulcph256_round_mask(                             \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B), (__v8sf)(__m256h)(W),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_mul_round_pch(U, A, B, R)                                 \
  ((__m256h)__builtin_ia32_vfmulcph256_round_mask(                             \
      (__v8sf)(__m256h)(A), (__v8sf)(__m256h)(B),                              \
      (__v8sf)(__m256h)_mm256_setzero_ph(), (__mmask8)(U), (int)(R)))

#define _mm256_getexp_round_pd(A, R)                                           \
  ((__m256d)__builtin_ia32_vgetexppd256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4df)_mm256_undefined_pd(), (__mmask8)-1,       \
      (int)(R)))

#define _mm256_mask_getexp_round_pd(W, U, A, R)                                \
  ((__m256d)__builtin_ia32_vgetexppd256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_getexp_round_pd(U, A, R)                                  \
  ((__m256d)__builtin_ia32_vgetexppd256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4df)_mm256_setzero_pd(), (__mmask8)(U),        \
      (int)(R)))

#define _mm256_getexp_round_ph(A, R)                                           \
  ((__m256h)__builtin_ia32_vgetexpph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (__v16hf)_mm256_undefined_ph(), (__mmask16)-1,    \
      (int)(R)))

#define _mm256_mask_getexp_round_ph(W, U, A, R)                                \
  ((__m256h)__builtin_ia32_vgetexpph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(W), (__mmask16)(U), (int)(R)))

#define _mm256_maskz_getexp_round_ph(U, A, R)                                  \
  ((__m256h)__builtin_ia32_vgetexpph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (__v16hf)_mm256_setzero_ph(), (__mmask16)(U),     \
      (int)(R)))

#define _mm256_getexp_round_ps(A, R)                                           \
  ((__m256)__builtin_ia32_vgetexpps256_round_mask(                             \
      (__v8sf)(__m256)(A), (__v8sf)_mm256_undefined_ps(), (__mmask8)-1,        \
      (int)(R)))

#define _mm256_mask_getexp_round_ps(W, U, A, R)                                \
  ((__m256)__builtin_ia32_vgetexpps256_round_mask(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_getexp_round_ps(U, A, R)                                  \
  ((__m256)__builtin_ia32_vgetexpps256_round_mask((__v8sf)(__m256)(A),         \
                                                  (__v8sf)_mm256_setzero_ps(), \
                                                  (__mmask8)(U), (int)(R)))

#define _mm256_getmant_round_pd(A, B, C, R)                                    \
  ((__m256d)__builtin_ia32_vgetmantpd256_round_mask(                           \
      (__v4df)(__m256d)(A), (int)(((C) << 2) | (B)),                           \
      (__v4df)_mm256_undefined_pd(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_getmant_round_pd(W, U, A, B, C, R)                         \
  ((__m256d)__builtin_ia32_vgetmantpd256_round_mask(                           \
      (__v4df)(__m256d)(A), (int)(((C) << 2) | (B)), (__v4df)(__m256d)(W),     \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_getmant_round_pd(U, A, B, C, R)                           \
  ((__m256d)__builtin_ia32_vgetmantpd256_round_mask(                           \
      (__v4df)(__m256d)(A), (int)(((C) << 2) | (B)),                           \
      (__v4df)_mm256_setzero_pd(), (__mmask8)(U), (int)(R)))

#define _mm256_getmant_round_ph(A, B, C, R)                                    \
  ((__m256h)__builtin_ia32_vgetmantph256_round_mask(                           \
      (__v16hf)(__m256h)(A), (int)(((C) << 2) | (B)),                          \
      (__v16hf)_mm256_undefined_ph(), (__mmask16)-1, (int)(R)))

#define _mm256_mask_getmant_round_ph(W, U, A, B, C, R)                         \
  ((__m256h)__builtin_ia32_vgetmantph256_round_mask(                           \
      (__v16hf)(__m256h)(A), (int)(((C) << 2) | (B)), (__v16hf)(__m256h)(W),   \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_getmant_round_ph(U, A, B, C, R)                           \
  ((__m256h)__builtin_ia32_vgetmantph256_round_mask(                           \
      (__v16hf)(__m256h)(A), (int)(((C) << 2) | (B)),                          \
      (__v16hf)_mm256_setzero_ph(), (__mmask16)(U), (int)(R)))

#define _mm256_getmant_round_ps(A, B, C, R)                                    \
  ((__m256)__builtin_ia32_vgetmantps256_round_mask(                            \
      (__v8sf)(__m256)(A), (int)(((C) << 2) | (B)),                            \
      (__v8sf)_mm256_undefined_ps(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_getmant_round_ps(W, U, A, B, C, R)                         \
  ((__m256)__builtin_ia32_vgetmantps256_round_mask(                            \
      (__v8sf)(__m256)(A), (int)(((C) << 2) | (B)), (__v8sf)(__m256)(W),       \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_getmant_round_ps(U, A, B, C, R)                           \
  ((__m256)__builtin_ia32_vgetmantps256_round_mask(                            \
      (__v8sf)(__m256)(A), (int)(((C) << 2) | (B)),                            \
      (__v8sf)_mm256_setzero_ps(), (__mmask8)(U), (int)(R)))

#define _mm256_max_round_pd(A, B, R)                                           \
  ((__m256d)__builtin_ia32_vmaxpd256_round((__v4df)(__m256d)(A),               \
                                           (__v4df)(__m256d)(B), (int)(R)))

#define _mm256_mask_max_round_pd(W, U, A, B, R)                                \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_max_round_pd((A), (B), (R)),               \
      (__v4df)(__m256d)(W)))

#define _mm256_maskz_max_round_pd(U, A, B, R)                                  \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_max_round_pd((A), (B), (R)),               \
      (__v4df)_mm256_setzero_pd()))

#define _mm256_max_round_ph(A, B, R)                                           \
  ((__m256h)__builtin_ia32_vmaxph256_round((__v16hf)(__m256h)(A),              \
                                           (__v16hf)(__m256h)(B), (int)(R)))

#define _mm256_mask_max_round_ph(W, U, A, B, R)                                \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_max_round_ph((A), (B), (R)),             \
      (__v16hf)(__m256h)(W)))

#define _mm256_maskz_max_round_ph(U, A, B, R)                                  \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_max_round_ph((A), (B), (R)),             \
      (__v16hf)_mm256_setzero_ph()))

#define _mm256_max_round_ps(A, B, R)                                           \
  ((__m256)__builtin_ia32_vmaxps256_round((__v8sf)(__m256)(A),                 \
                                          (__v8sf)(__m256)(B), (int)(R)))

#define _mm256_mask_max_round_ps(W, U, A, B, R)                                \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_max_round_ps((A), (B), (R)),               \
      (__v8sf)(__m256)(W)))

#define _mm256_maskz_max_round_ps(U, A, B, R)                                  \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_max_round_ps((A), (B), (R)),               \
      (__v8sf)_mm256_setzero_ps()))

#define _mm256_min_round_pd(A, B, R)                                           \
  ((__m256d)__builtin_ia32_vminpd256_round((__v4df)(__m256d)(A),               \
                                           (__v4df)(__m256d)(B), (int)(R)))

#define _mm256_mask_min_round_pd(W, U, A, B, R)                                \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_min_round_pd((A), (B), (R)),               \
      (__v4df)(__m256d)(W)))

#define _mm256_maskz_min_round_pd(U, A, B, R)                                  \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_min_round_pd((A), (B), (R)),               \
      (__v4df)_mm256_setzero_pd()))

#define _mm256_min_round_ph(A, B, R)                                           \
  ((__m256h)__builtin_ia32_vminph256_round((__v16hf)(__m256h)(A),              \
                                           (__v16hf)(__m256h)(B), (int)(R)))

#define _mm256_mask_min_round_ph(W, U, A, B, R)                                \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_min_round_ph((A), (B), (R)),             \
      (__v16hf)(__m256h)(W)))

#define _mm256_maskz_min_round_ph(U, A, B, R)                                  \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_min_round_ph((A), (B), (R)),             \
      (__v16hf)_mm256_setzero_ph()))

#define _mm256_min_round_ps(A, B, R)                                           \
  ((__m256)__builtin_ia32_vminps256_round((__v8sf)(__m256)(A),                 \
                                          (__v8sf)(__m256)(B), (int)(R)))

#define _mm256_mask_min_round_ps(W, U, A, B, R)                                \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_min_round_ps((A), (B), (R)),               \
      (__v8sf)(__m256)(W)))

#define _mm256_maskz_min_round_ps(U, A, B, R)                                  \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_min_round_ps((A), (B), (R)),               \
      (__v8sf)_mm256_setzero_ps()))

#define _mm256_mul_round_pd(A, B, R)                                           \
  ((__m256d)__builtin_ia32_vmulpd256_round((__v4df)(__m256d)(A),               \
                                           (__v4df)(__m256d)(B), (int)(R)))

#define _mm256_mask_mul_round_pd(W, U, A, B, R)                                \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_mul_round_pd((A), (B), (R)),               \
      (__v4df)(__m256d)(W)))

#define _mm256_maskz_mul_round_pd(U, A, B, R)                                  \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_mul_round_pd((A), (B), (R)),               \
      (__v4df)_mm256_setzero_pd()))

#define _mm256_mul_round_ph(A, B, R)                                           \
  ((__m256h)__builtin_ia32_vmulph256_round((__v16hf)(__m256h)(A),              \
                                           (__v16hf)(__m256h)(B), (int)(R)))

#define _mm256_mask_mul_round_ph(W, U, A, B, R)                                \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_mul_round_ph((A), (B), (R)),             \
      (__v16hf)(__m256h)(W)))

#define _mm256_maskz_mul_round_ph(U, A, B, R)                                  \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_mul_round_ph((A), (B), (R)),             \
      (__v16hf)_mm256_setzero_ph()))

#define _mm256_mul_round_ps(A, B, R)                                           \
  ((__m256)__builtin_ia32_vmulps256_round((__v8sf)(__m256)(A),                 \
                                          (__v8sf)(__m256)(B), (int)(R)))

#define _mm256_mask_mul_round_ps(W, U, A, B, R)                                \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_mul_round_ps((A), (B), (R)),               \
      (__v8sf)(__m256)(W)))

#define _mm256_maskz_mul_round_ps(U, A, B, R)                                  \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_mul_round_ps((A), (B), (R)),               \
      (__v8sf)_mm256_setzero_ps()))

#define _mm256_range_round_pd(A, B, C, R)                                      \
  ((__m256d)__builtin_ia32_vrangepd256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (int)(C),                    \
      (__v4df)_mm256_setzero_pd(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_range_round_pd(W, U, A, B, C, R)                           \
  ((__m256d)__builtin_ia32_vrangepd256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (int)(C),                    \
      (__v4df)(__m256d)(W), (__mmask8)(U), (int)(R)))

#define _mm256_maskz_range_round_pd(U, A, B, C, R)                             \
  ((__m256d)__builtin_ia32_vrangepd256_round_mask(                             \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (int)(C),                    \
      (__v4df)_mm256_setzero_pd(), (__mmask8)(U), (int)(R)))

#define _mm256_range_round_ps(A, B, C, R)                                      \
  ((__m256)__builtin_ia32_vrangeps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (int)(C),                      \
      (__v8sf)_mm256_setzero_ps(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_range_round_ps(W, U, A, B, C, R)                           \
  ((__m256)__builtin_ia32_vrangeps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (int)(C), (__v8sf)(__m256)(W), \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_range_round_ps(U, A, B, C, R)                             \
  ((__m256)__builtin_ia32_vrangeps256_round_mask(                              \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (int)(C),                      \
      (__v8sf)_mm256_setzero_ps(), (__mmask8)(U), (int)(R)))

#define _mm256_reduce_round_pd(A, B, R)                                        \
  ((__m256d)__builtin_ia32_vreducepd256_round_mask(                            \
      (__v4df)(__m256d)(A), (int)(B), (__v4df)_mm256_setzero_pd(),             \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_reduce_round_pd(W, U, A, B, R)                             \
  ((__m256d)__builtin_ia32_vreducepd256_round_mask(                            \
      (__v4df)(__m256d)(A), (int)(B), (__v4df)(__m256d)(W), (__mmask8)(U),     \
      (int)(R)))

#define _mm256_maskz_reduce_round_pd(U, A, B, R)                               \
  ((__m256d)__builtin_ia32_vreducepd256_round_mask(                            \
      (__v4df)(__m256d)(A), (int)(B), (__v4df)_mm256_setzero_pd(),             \
      (__mmask8)(U), (int)(R)))

#define _mm256_mask_reduce_round_ph(W, U, A, imm, R)                           \
  ((__m256h)__builtin_ia32_vreduceph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (int)(imm), (__v16hf)(__m256h)(W),                \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_reduce_round_ph(U, A, imm, R)                             \
  ((__m256h)__builtin_ia32_vreduceph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (int)(imm), (__v16hf)_mm256_setzero_ph(),         \
      (__mmask16)(U), (int)(R)))

#define _mm256_reduce_round_ph(A, imm, R)                                      \
  ((__m256h)__builtin_ia32_vreduceph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (int)(imm), (__v16hf)_mm256_undefined_ph(),       \
      (__mmask16)-1, (int)(R)))

#define _mm256_reduce_round_ps(A, B, R)                                        \
  ((__m256)__builtin_ia32_vreduceps256_round_mask(                             \
      (__v8sf)(__m256)(A), (int)(B), (__v8sf)_mm256_setzero_ps(),              \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_reduce_round_ps(W, U, A, B, R)                             \
  ((__m256)__builtin_ia32_vreduceps256_round_mask(                             \
      (__v8sf)(__m256)(A), (int)(B), (__v8sf)(__m256)(W), (__mmask8)(U),       \
      (int)(R)))

#define _mm256_maskz_reduce_round_ps(U, A, B, R)                               \
  ((__m256)__builtin_ia32_vreduceps256_round_mask(                             \
      (__v8sf)(__m256)(A), (int)(B), (__v8sf)_mm256_setzero_ps(),              \
      (__mmask8)(U), (int)(R)))

#define _mm256_roundscale_round_pd(A, imm, R)                                  \
  ((__m256d)__builtin_ia32_vrndscalepd256_round_mask(                          \
      (__v4df)(__m256d)(A), (int)(imm), (__v4df)_mm256_undefined_pd(),         \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_roundscale_round_pd(A, B, C, imm, R)                       \
  ((__m256d)__builtin_ia32_vrndscalepd256_round_mask(                          \
      (__v4df)(__m256d)(C), (int)(imm), (__v4df)(__m256d)(A), (__mmask8)(B),   \
      (int)(R)))

#define _mm256_maskz_roundscale_round_pd(A, B, imm, R)                         \
  ((__m256d)__builtin_ia32_vrndscalepd256_round_mask(                          \
      (__v4df)(__m256d)(B), (int)(imm), (__v4df)_mm256_setzero_pd(),           \
      (__mmask8)(A), (int)(R)))

#define _mm256_roundscale_round_ph(A, imm, R)                                  \
  ((__m256h)__builtin_ia32_vrndscaleph256_round_mask(                          \
      (__v16hf)(__m256h)(A), (int)(imm), (__v16hf)_mm256_undefined_ph(),       \
      (__mmask16)-1, (int)(R)))

#define _mm256_mask_roundscale_round_ph(A, B, C, imm, R)                       \
  ((__m256h)__builtin_ia32_vrndscaleph256_round_mask(                          \
      (__v16hf)(__m256h)(C), (int)(imm), (__v16hf)(__m256h)(A),                \
      (__mmask16)(B), (int)(R)))

#define _mm256_maskz_roundscale_round_ph(A, B, imm, R)                         \
  ((__m256h)__builtin_ia32_vrndscaleph256_round_mask(                          \
      (__v16hf)(__m256h)(B), (int)(imm), (__v16hf)_mm256_setzero_ph(),         \
      (__mmask16)(A), (int)(R)))

#define _mm256_roundscale_round_ps(A, imm, R)                                  \
  ((__m256)__builtin_ia32_vrndscaleps256_round_mask(                           \
      (__v8sf)(__m256)(A), (int)(imm), (__v8sf)_mm256_undefined_ps(),          \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_roundscale_round_ps(A, B, C, imm, R)                       \
  ((__m256)__builtin_ia32_vrndscaleps256_round_mask(                           \
      (__v8sf)(__m256)(C), (int)(imm), (__v8sf)(__m256)(A), (__mmask8)(B),     \
      (int)(R)))

#define _mm256_maskz_roundscale_round_ps(A, B, imm, R)                         \
  ((__m256)__builtin_ia32_vrndscaleps256_round_mask(                           \
      (__v8sf)(__m256)(B), (int)(imm), (__v8sf)_mm256_setzero_ps(),            \
      (__mmask8)(A), (int)(R)))

#define _mm256_scalef_round_pd(A, B, R)                                        \
  ((__m256d)__builtin_ia32_vscalefpd256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B),                              \
      (__v4df)_mm256_undefined_pd(), (__mmask8)-1, (int)(R)))

#define _mm256_mask_scalef_round_pd(W, U, A, B, R)                             \
  ((__m256d)__builtin_ia32_vscalefpd256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)(__m256d)(W),        \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_scalef_round_pd(U, A, B, R)                               \
  ((__m256d)__builtin_ia32_vscalefpd256_round_mask(                            \
      (__v4df)(__m256d)(A), (__v4df)(__m256d)(B), (__v4df)_mm256_setzero_pd(), \
      (__mmask8)(U), (int)(R)))

#define _mm256_scalef_round_ph(A, B, R)                                        \
  ((__m256h)__builtin_ia32_vscalefph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B),                            \
      (__v16hf)_mm256_undefined_ph(), (__mmask16)-1, (int)(R)))

#define _mm256_mask_scalef_round_ph(W, U, A, B, R)                             \
  ((__m256h)__builtin_ia32_vscalefph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B), (__v16hf)(__m256h)(W),     \
      (__mmask16)(U), (int)(R)))

#define _mm256_maskz_scalef_round_ph(U, A, B, R)                               \
  ((__m256h)__builtin_ia32_vscalefph256_round_mask(                            \
      (__v16hf)(__m256h)(A), (__v16hf)(__m256h)(B),                            \
      (__v16hf)_mm256_setzero_ph(), (__mmask16)(U), (int)(R)))

#define _mm256_scalef_round_ps(A, B, R)                                        \
  ((__m256)__builtin_ia32_vscalefps256_round_mask(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)_mm256_undefined_ps(), \
      (__mmask8)-1, (int)(R)))

#define _mm256_mask_scalef_round_ps(W, U, A, B, R)                             \
  ((__m256)__builtin_ia32_vscalefps256_round_mask(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)(__m256)(W),           \
      (__mmask8)(U), (int)(R)))

#define _mm256_maskz_scalef_round_ps(U, A, B, R)                               \
  ((__m256)__builtin_ia32_vscalefps256_round_mask(                             \
      (__v8sf)(__m256)(A), (__v8sf)(__m256)(B), (__v8sf)_mm256_setzero_ps(),   \
      (__mmask8)(U), (int)(R)))

#define _mm256_sqrt_round_pd(A, R)                                             \
  ((__m256d)__builtin_ia32_vsqrtpd256_round((__v4df)(__m256d)(A), (int)(R)))

#define _mm256_mask_sqrt_round_pd(W, U, A, R)                                  \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_sqrt_round_pd((A), (R)),                   \
      (__v4df)(__m256d)(W)))

#define _mm256_maskz_sqrt_round_pd(U, A, R)                                    \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_sqrt_round_pd((A), (R)),                   \
      (__v4df)_mm256_setzero_pd()))

#define _mm256_sqrt_round_ph(A, R)                                             \
  ((__m256h)__builtin_ia32_vsqrtph256_round((__v16hf)(__m256h)(A), (int)(R)))

#define _mm256_mask_sqrt_round_ph(W, U, A, R)                                  \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_sqrt_round_ph((A), (R)),                 \
      (__v16hf)(__m256h)(W)))

#define _mm256_maskz_sqrt_round_ph(U, A, R)                                    \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_sqrt_round_ph((A), (R)),                 \
      (__v16hf)_mm256_setzero_ph()))

#define _mm256_sqrt_round_ps(A, R)                                             \
  ((__m256)__builtin_ia32_vsqrtps256_round((__v8sf)(__m256)(A), (int)(R)))

#define _mm256_mask_sqrt_round_ps(W, U, A, R)                                  \
  ((__m256)__builtin_ia32_selectps_256((__mmask8)(U),                          \
                                       (__v8sf)_mm256_sqrt_round_ps((A), (R)), \
                                       (__v8sf)(__m256)(W)))

#define _mm256_maskz_sqrt_round_ps(U, A, R)                                    \
  ((__m256)__builtin_ia32_selectps_256((__mmask8)(U),                          \
                                       (__v8sf)_mm256_sqrt_round_ps((A), (R)), \
                                       (__v8sf)_mm256_setzero_ps()))

#define _mm256_sub_round_pd(A, B, R)                                           \
  ((__m256d)__builtin_ia32_vsubpd256_round((__v4df)(__m256d)(A),               \
                                           (__v4df)(__m256d)(B), (int)(R)))

#define _mm256_mask_sub_round_pd(W, U, A, B, R)                                \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_sub_round_pd((A), (B), (R)),               \
      (__v4df)(__m256d)(W)))

#define _mm256_maskz_sub_round_pd(U, A, B, R)                                  \
  ((__m256d)__builtin_ia32_selectpd_256(                                       \
      (__mmask8)(U), (__v4df)_mm256_sub_round_pd((A), (B), (R)),               \
      (__v4df)_mm256_setzero_pd()))

#define _mm256_sub_round_ph(A, B, R)                                           \
  ((__m256h)__builtin_ia32_vsubph256_round((__v16hf)(__m256h)(A),              \
                                           (__v16hf)(__m256h)(B), (int)(R)))

#define _mm256_mask_sub_round_ph(W, U, A, B, R)                                \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_sub_round_ph((A), (B), (R)),             \
      (__v16hf)(__m256h)(W)))

#define _mm256_maskz_sub_round_ph(U, A, B, R)                                  \
  ((__m256h)__builtin_ia32_selectph_256(                                       \
      (__mmask16)(U), (__v16hf)_mm256_sub_round_ph((A), (B), (R)),             \
      (__v16hf)_mm256_setzero_ph()))

#define _mm256_sub_round_ps(A, B, R)                                           \
  ((__m256)__builtin_ia32_vsubps256_round((__v8sf)(__m256)(A),                 \
                                          (__v8sf)(__m256)(B), (int)(R)))

#define _mm256_mask_sub_round_ps(W, U, A, B, R)                                \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_sub_round_ps((A), (B), (R)),               \
      (__v8sf)(__m256)(W)))

#define _mm256_maskz_sub_round_ps(U, A, B, R)                                  \
  ((__m256)__builtin_ia32_selectps_256(                                        \
      (__mmask8)(U), (__v8sf)_mm256_sub_round_ps((A), (B), (R)),               \
      (__v8sf)_mm256_setzero_ps()))

#undef __DEFAULT_FN_ATTRS256
#undef __DEFAULT_FN_ATTRS128

#endif /* __AVX10_2NIINTRIN_H */
#endif /* __SSE2__ */
