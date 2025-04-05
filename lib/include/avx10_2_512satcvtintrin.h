/*===------ avx10_2_512satcvtintrin.h - AVX10_2_512SATCVT intrinsics -------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */
#ifndef __IMMINTRIN_H
#error                                                                         \
    "Never use <avx10_2_512satcvtintrin.h> directly; include <immintrin.h> instead."
#endif // __IMMINTRIN_H

#ifndef __AVX10_2_512SATCVTINTRIN_H
#define __AVX10_2_512SATCVTINTRIN_H

#define _mm512_ipcvtbf16_epi8(A)                                               \
  ((__m512i)__builtin_ia32_vcvtbf162ibs512((__v32bf)(__m512bh)(A)))

#define _mm512_mask_ipcvtbf16_epi8(W, U, A)                                    \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvtbf16_epi8(A),      \
                                       (__v32hi)(__m512i)(W)))

#define _mm512_maskz_ipcvtbf16_epi8(U, A)                                      \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvtbf16_epi8(A),      \
                                       (__v32hi)_mm512_setzero_si512()))

#define _mm512_ipcvtbf16_epu8(A)                                               \
  ((__m512i)__builtin_ia32_vcvtbf162iubs512((__v32bf)(__m512bh)(A)))

#define _mm512_mask_ipcvtbf16_epu8(W, U, A)                                    \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvtbf16_epu8(A),      \
                                       (__v32hi)(__m512i)(W)))

#define _mm512_maskz_ipcvtbf16_epu8(U, A)                                      \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvtbf16_epu8(A),      \
                                       (__v32hi)_mm512_setzero_si512()))

#define _mm512_ipcvttbf16_epi8(A)                                              \
  ((__m512i)__builtin_ia32_vcvttbf162ibs512((__v32bf)(__m512bh)(A)))

#define _mm512_mask_ipcvttbf16_epi8(W, U, A)                                   \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvttbf16_epi8(A),     \
                                       (__v32hi)(__m512i)(W)))

#define _mm512_maskz_ipcvttbf16_epi8(U, A)                                     \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvttbf16_epi8(A),     \
                                       (__v32hi)_mm512_setzero_si512()))

#define _mm512_ipcvttbf16_epu8(A)                                              \
  ((__m512i)__builtin_ia32_vcvttbf162iubs512((__v32bf)(__m512bh)(A)))

#define _mm512_mask_ipcvttbf16_epu8(W, U, A)                                   \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvttbf16_epu8(A),     \
                                       (__v32hi)(__m512i)(W)))

#define _mm512_maskz_ipcvttbf16_epu8(U, A)                                     \
  ((__m512i)__builtin_ia32_selectw_512((__mmask32)(U),                         \
                                       (__v32hi)_mm512_ipcvttbf16_epu8(A),     \
                                       (__v32hi)_mm512_setzero_si512()))

#define _mm512_ipcvtph_epi8(A)                                                 \
  ((__m512i)__builtin_ia32_vcvtph2ibs512_mask(                                 \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)-1,   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvtph_epi8(W, U, A)                                      \
  ((__m512i)__builtin_ia32_vcvtph2ibs512_mask((__v32hf)(__m512h)(A),           \
                                              (__v32hu)(W), (__mmask32)(U),    \
                                              _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvtph_epi8(U, A)                                        \
  ((__m512i)__builtin_ia32_vcvtph2ibs512_mask(                                 \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)(U),  \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvt_roundph_epi8(A, R)                                        \
  ((__m512i)__builtin_ia32_vcvtph2ibs512_mask((__v32hf)(__m512h)(A),           \
                                              (__v32hu)_mm512_setzero_si512(), \
                                              (__mmask32)-1, (const int)R))

#define _mm512_mask_ipcvt_roundph_epi8(W, U, A, R)                             \
  ((__m512i)__builtin_ia32_vcvtph2ibs512_mask(                                 \
      (__v32hf)(__m512h)(A), (__v32hu)(W), (__mmask32)(U), (const int)R))

#define _mm512_maskz_ipcvt_roundph_epi8(U, A, R)                               \
  ((__m512i)__builtin_ia32_vcvtph2ibs512_mask((__v32hf)(__m512h)(A),           \
                                              (__v32hu)_mm512_setzero_si512(), \
                                              (__mmask32)(U), (const int)R))

#define _mm512_ipcvtph_epu8(A)                                                 \
  ((__m512i)__builtin_ia32_vcvtph2iubs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)-1,   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvtph_epu8(W, U, A)                                      \
  ((__m512i)__builtin_ia32_vcvtph2iubs512_mask((__v32hf)(__m512h)(A),          \
                                               (__v32hu)(W), (__mmask32)(U),   \
                                               _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvtph_epu8(U, A)                                        \
  ((__m512i)__builtin_ia32_vcvtph2iubs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)(U),  \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvt_roundph_epu8(A, R)                                        \
  ((__m512i)__builtin_ia32_vcvtph2iubs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)-1,   \
      (const int)R))

#define _mm512_mask_ipcvt_roundph_epu8(W, U, A, R)                             \
  ((__m512i)__builtin_ia32_vcvtph2iubs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)(W), (__mmask32)(U), (const int)R))

#define _mm512_maskz_ipcvt_roundph_epu8(U, A, R)                               \
  ((__m512i)__builtin_ia32_vcvtph2iubs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)(U),  \
      (const int)R))

#define _mm512_ipcvtps_epi8(A)                                                 \
  ((__m512i)__builtin_ia32_vcvtps2ibs512_mask(                                 \
      (__v16sf)(__m512)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)-1,    \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvtps_epi8(W, U, A)                                      \
  ((__m512i)__builtin_ia32_vcvtps2ibs512_mask((__v16sf)(__m512)(A),            \
                                              (__v16su)(W), (__mmask16)(U),    \
                                              _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvtps_epi8(U, A)                                        \
  ((__m512i)__builtin_ia32_vcvtps2ibs512_mask(                                 \
      (__v16sf)(__m512)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)(U),   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvt_roundps_epi8(A, R)                                        \
  ((__m512i)__builtin_ia32_vcvtps2ibs512_mask((__v16sf)(__m512)(A),            \
                                              (__v16su)_mm512_setzero_si512(), \
                                              (__mmask16)-1, (const int)R))

#define _mm512_mask_ipcvt_roundps_epi8(W, U, A, R)                             \
  ((__m512i)__builtin_ia32_vcvtps2ibs512_mask(                                 \
      (__v16sf)(__m512)(A), (__v16su)(W), (__mmask16)(U), (const int)R))

#define _mm512_maskz_ipcvt_roundps_epi8(U, A, R)                               \
  ((__m512i)__builtin_ia32_vcvtps2ibs512_mask((__v16sf)(__m512)(A),            \
                                              (__v16su)_mm512_setzero_si512(), \
                                              (__mmask16)(U), (const int)R))

#define _mm512_ipcvtps_epu8(A)                                                 \
  ((__m512i)__builtin_ia32_vcvtps2iubs512_mask(                                \
      (__v16sf)(__m512)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)-1,    \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvtps_epu8(W, U, A)                                      \
  ((__m512i)__builtin_ia32_vcvtps2iubs512_mask((__v16sf)(__m512)(A),           \
                                               (__v16su)(W), (__mmask16)(U),   \
                                               _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvtps_epu8(U, A)                                        \
  ((__m512i)__builtin_ia32_vcvtps2iubs512_mask(                                \
      (__v16sf)(__m512)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)(U),   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvt_roundps_epu8(A, R)                                        \
  ((__m512i)__builtin_ia32_vcvtps2iubs512_mask(                                \
      (__v16sf)(__m512)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)-1,    \
      (const int)R))

#define _mm512_mask_ipcvt_roundps_epu8(W, U, A, R)                             \
  ((__m512i)__builtin_ia32_vcvtps2iubs512_mask(                                \
      (__v16sf)(__m512)(A), (__v16su)(W), (__mmask16)(U), (const int)R))

#define _mm512_maskz_ipcvt_roundps_epu8(U, A, R)                               \
  ((__m512i)__builtin_ia32_vcvtps2iubs512_mask(                                \
      (__v16sf)(__m512)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)(U),   \
      (const int)R))

#define _mm512_ipcvttph_epi8(A)                                                \
  ((__m512i)__builtin_ia32_vcvttph2ibs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)-1,   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvttph_epi8(W, U, A)                                     \
  ((__m512i)__builtin_ia32_vcvttph2ibs512_mask((__v32hf)(__m512h)(A),          \
                                               (__v32hu)(W), (__mmask32)(U),   \
                                               _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvttph_epi8(U, A)                                       \
  ((__m512i)__builtin_ia32_vcvttph2ibs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)(U),  \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvtt_roundph_epi8(A, S)                                       \
  ((__m512i)__builtin_ia32_vcvttph2ibs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)-1,   \
      S))

#define _mm512_mask_ipcvtt_roundph_epi8(W, U, A, S)                            \
  ((__m512i)__builtin_ia32_vcvttph2ibs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)(W), (__mmask32)(U), S))

#define _mm512_maskz_ipcvtt_roundph_epi8(U, A, S)                              \
  ((__m512i)__builtin_ia32_vcvttph2ibs512_mask(                                \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)(U),  \
      S))

#define _mm512_ipcvttph_epu8(A)                                                \
  ((__m512i)__builtin_ia32_vcvttph2iubs512_mask(                               \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)-1,   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvttph_epu8(W, U, A)                                     \
  ((__m512i)__builtin_ia32_vcvttph2iubs512_mask((__v32hf)(__m512h)(A),         \
                                                (__v32hu)(W), (__mmask32)(U),  \
                                                _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvttph_epu8(U, A)                                       \
  ((__m512i)__builtin_ia32_vcvttph2iubs512_mask(                               \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)(U),  \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvtt_roundph_epu8(A, S)                                       \
  ((__m512i)__builtin_ia32_vcvttph2iubs512_mask(                               \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)-1,   \
      S))

#define _mm512_mask_ipcvtt_roundph_epu8(W, U, A, S)                            \
  ((__m512i)__builtin_ia32_vcvttph2iubs512_mask(                               \
      (__v32hf)(__m512h)(A), (__v32hu)(W), (__mmask32)(U), S))

#define _mm512_maskz_ipcvtt_roundph_epu8(U, A, S)                              \
  ((__m512i)__builtin_ia32_vcvttph2iubs512_mask(                               \
      (__v32hf)(__m512h)(A), (__v32hu)_mm512_setzero_si512(), (__mmask32)(U),  \
      S))

#define _mm512_ipcvttps_epi8(A)                                                \
  ((__m512i)__builtin_ia32_vcvttps2ibs512_mask(                                \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)-1,   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvttps_epi8(W, U, A)                                     \
  ((__m512i)__builtin_ia32_vcvttps2ibs512_mask((__v16sf)(__m512h)(A),          \
                                               (__v16su)(W), (__mmask16)(U),   \
                                               _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvttps_epi8(U, A)                                       \
  ((__m512i)__builtin_ia32_vcvttps2ibs512_mask(                                \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)(U),  \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvtt_roundps_epi8(A, S)                                       \
  ((__m512i)__builtin_ia32_vcvttps2ibs512_mask(                                \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)-1,   \
      S))

#define _mm512_mask_ipcvtt_roundps_epi8(W, U, A, S)                            \
  ((__m512i)__builtin_ia32_vcvttps2ibs512_mask(                                \
      (__v16sf)(__m512h)(A), (__v16su)(W), (__mmask16)(U), S))

#define _mm512_maskz_ipcvtt_roundps_epi8(U, A, S)                              \
  ((__m512i)__builtin_ia32_vcvttps2ibs512_mask(                                \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)(U),  \
      S))

#define _mm512_ipcvttps_epu8(A)                                                \
  ((__m512i)__builtin_ia32_vcvttps2iubs512_mask(                               \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)-1,   \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_mask_ipcvttps_epu8(W, U, A)                                     \
  ((__m512i)__builtin_ia32_vcvttps2iubs512_mask((__v16sf)(__m512h)(A),         \
                                                (__v16su)(W), (__mmask16)(U),  \
                                                _MM_FROUND_CUR_DIRECTION))

#define _mm512_maskz_ipcvttps_epu8(U, A)                                       \
  ((__m512i)__builtin_ia32_vcvttps2iubs512_mask(                               \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)(U),  \
      _MM_FROUND_CUR_DIRECTION))

#define _mm512_ipcvtt_roundps_epu8(A, S)                                       \
  ((__m512i)__builtin_ia32_vcvttps2iubs512_mask(                               \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)-1,   \
      S))

#define _mm512_mask_ipcvtt_roundps_epu8(W, U, A, S)                            \
  ((__m512i)__builtin_ia32_vcvttps2iubs512_mask(                               \
      (__v16sf)(__m512h)(A), (__v16su)(W), (__mmask16)(U), S))

#define _mm512_maskz_ipcvtt_roundps_epu8(U, A, S)                              \
  ((__m512i)__builtin_ia32_vcvttps2iubs512_mask(                               \
      (__v16sf)(__m512h)(A), (__v16su)_mm512_setzero_si512(), (__mmask16)(U),  \
      S))

#endif // __AVX10_2_512SATCVTINTRIN_H
