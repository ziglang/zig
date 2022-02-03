/*===---- smmintrin.h - Implementation of SSE4 intrinsics on PowerPC -------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

/* Implemented from the specification included in the Intel C++ Compiler
   User Guide and Reference, version 9.0.

   NOTE: This is NOT a complete implementation of the SSE4 intrinsics!  */

#ifndef NO_WARN_X86_INTRINSICS
/* This header is distributed to simplify porting x86_64 code that
   makes explicit use of Intel intrinsics to powerp64/powerpc64le.

   It is the user's responsibility to determine if the results are
   acceptable and make additional changes as necessary.

   Note that much code that uses Intel intrinsics can be rewritten in
   standard C or GNU C extensions, which are more portable and better
   optimized across multiple targets.  */
#error                                                                         \
    "Please read comment above.  Use -DNO_WARN_X86_INTRINSICS to disable this error."
#endif

#ifndef SMMINTRIN_H_
#define SMMINTRIN_H_

#if defined(__ppc64__) && (defined(__linux__) || defined(__FreeBSD__))

#include <altivec.h>
#include <tmmintrin.h>

extern __inline int
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_extract_epi8(__m128i __X, const int __N) {
  return (unsigned char)((__v16qi)__X)[__N & 15];
}

extern __inline int
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_extract_epi32(__m128i __X, const int __N) {
  return ((__v4si)__X)[__N & 3];
}

extern __inline int
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_extract_epi64(__m128i __X, const int __N) {
  return ((__v2di)__X)[__N & 1];
}

extern __inline int
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_extract_ps(__m128 __X, const int __N) {
  return ((__v4si)__X)[__N & 3];
}

extern __inline __m128i
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_blend_epi16(__m128i __A, __m128i __B, const int __imm8) {
  __v16qi __charmask = vec_splats((signed char)__imm8);
  __charmask = vec_gb(__charmask);
  __v8hu __shortmask = (__v8hu)vec_unpackh(__charmask);
#ifdef __BIG_ENDIAN__
  __shortmask = vec_reve(__shortmask);
#endif
  return (__m128i)vec_sel((__v8hu)__A, (__v8hu)__B, __shortmask);
}

extern __inline __m128i
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_blendv_epi8(__m128i __A, __m128i __B, __m128i __mask) {
  const __v16qu __seven = vec_splats((unsigned char)0x07);
  __v16qu __lmask = vec_sra((__v16qu)__mask, __seven);
  return (__m128i)vec_sel((__v16qu)__A, (__v16qu)__B, __lmask);
}

extern __inline __m128i
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_insert_epi8(__m128i const __A, int const __D, int const __N) {
  __v16qi result = (__v16qi)__A;
  result[__N & 0xf] = __D;
  return (__m128i)result;
}

extern __inline __m128i
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_insert_epi32(__m128i const __A, int const __D, int const __N) {
  __v4si result = (__v4si)__A;
  result[__N & 3] = __D;
  return (__m128i)result;
}

extern __inline __m128i
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_insert_epi64(__m128i const __A, long long const __D, int const __N) {
  __v2di result = (__v2di)__A;
  result[__N & 1] = __D;
  return (__m128i)result;
}

#else
#include_next <smmintrin.h>
#endif /* defined(__ppc64__) && (defined(__linux__) || defined(__FreeBSD__))   \
        */

#endif /* _SMMINTRIN_H_ */
