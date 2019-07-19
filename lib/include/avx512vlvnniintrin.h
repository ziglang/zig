/*===------------- avx512vlvnniintrin.h - VNNI intrinsics ------------------===
 *
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */
#ifndef __IMMINTRIN_H
#error "Never use <avx512vlvnniintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512VLVNNIINTRIN_H
#define __AVX512VLVNNIINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS128 __attribute__((__always_inline__, __nodebug__, __target__("avx512vl,avx512vnni"), __min_vector_width__(128)))
#define __DEFAULT_FN_ATTRS256 __attribute__((__always_inline__, __nodebug__, __target__("avx512vl,avx512vnni"), __min_vector_width__(256)))


static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_dpbusd_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_vpdpbusd256((__v8si)__S, (__v8si)__A,
                                             (__v8si)__B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbusd_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                     (__v8si)_mm256_dpbusd_epi32(__S, __A, __B),
                                     (__v8si)__S);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpbusd_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                     (__v8si)_mm256_dpbusd_epi32(__S, __A, __B),
                                     (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_dpbusds_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_vpdpbusds256((__v8si)__S, (__v8si)__A,
                                              (__v8si)__B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpbusds_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                    (__v8si)_mm256_dpbusds_epi32(__S, __A, __B),
                                    (__v8si)__S);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpbusds_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                     (__v8si)_mm256_dpbusds_epi32(__S, __A, __B),
                                     (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_dpwssd_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_vpdpwssd256((__v8si)__S, (__v8si)__A,
                                             (__v8si)__B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwssd_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                     (__v8si)_mm256_dpwssd_epi32(__S, __A, __B),
                                     (__v8si)__S);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpwssd_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                     (__v8si)_mm256_dpwssd_epi32(__S, __A, __B),
                                     (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_dpwssds_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_vpdpwssds256((__v8si)__S, (__v8si)__A,
                                              (__v8si)__B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_mask_dpwssds_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                    (__v8si)_mm256_dpwssds_epi32(__S, __A, __B),
                                    (__v8si)__S);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS256
_mm256_maskz_dpwssds_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256(__U,
                                    (__v8si)_mm256_dpwssds_epi32(__S, __A, __B),
                                    (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_dpbusd_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_vpdpbusd128((__v4si)__S, (__v4si)__A,
                                             (__v4si)__B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbusd_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                        (__v4si)_mm_dpbusd_epi32(__S, __A, __B),
                                        (__v4si)__S);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbusd_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                        (__v4si)_mm_dpbusd_epi32(__S, __A, __B),
                                        (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_dpbusds_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_vpdpbusds128((__v4si)__S, (__v4si)__A,
                                              (__v4si)__B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpbusds_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                       (__v4si)_mm_dpbusds_epi32(__S, __A, __B),
                                       (__v4si)__S);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpbusds_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                       (__v4si)_mm_dpbusds_epi32(__S, __A, __B),
                                       (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_dpwssd_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_vpdpwssd128((__v4si)__S, (__v4si)__A,
                                             (__v4si)__B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwssd_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                        (__v4si)_mm_dpwssd_epi32(__S, __A, __B),
                                        (__v4si)__S);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwssd_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                        (__v4si)_mm_dpwssd_epi32(__S, __A, __B),
                                        (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_dpwssds_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_vpdpwssds128((__v4si)__S, (__v4si)__A,
                                              (__v4si)__B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_mask_dpwssds_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                       (__v4si)_mm_dpwssds_epi32(__S, __A, __B),
                                       (__v4si)__S);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS128
_mm_maskz_dpwssds_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128(__U,
                                       (__v4si)_mm_dpwssds_epi32(__S, __A, __B),
                                       (__v4si)_mm_setzero_si128());
}

#undef __DEFAULT_FN_ATTRS128
#undef __DEFAULT_FN_ATTRS256

#endif
