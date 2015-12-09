/*===---- avx512vlintrin.h - AVX512VL intrinsics ---------------------------===
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __IMMINTRIN_H
#error "Never use <avx512vlintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512VLINTRIN_H
#define __AVX512VLINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__))

/* Integer compare */

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpeq_epi32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqd128_mask((__v4si)__a, (__v4si)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpeq_epi32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqd128_mask((__v4si)__a, (__v4si)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpeq_epu32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 0,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpeq_epu32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 0,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpeq_epi32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqd256_mask((__v8si)__a, (__v8si)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpeq_epi32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqd256_mask((__v8si)__a, (__v8si)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpeq_epu32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 0,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpeq_epu32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 0,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpeq_epi64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqq128_mask((__v2di)__a, (__v2di)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpeq_epi64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqq128_mask((__v2di)__a, (__v2di)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpeq_epu64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 0,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpeq_epu64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 0,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpeq_epi64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqq256_mask((__v4di)__a, (__v4di)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpeq_epi64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpeqq256_mask((__v4di)__a, (__v4di)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpeq_epu64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 0,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpeq_epu64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 0,
                                                __u);
}


static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpge_epi32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 5,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpge_epi32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 5,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpge_epu32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 5,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpge_epu32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 5,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpge_epi32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 5,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpge_epi32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 5,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpge_epu32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 5,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpge_epu32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 5,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpge_epi64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 5,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpge_epi64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 5,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpge_epu64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 5,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpge_epu64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 5,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpge_epi64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 5,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpge_epi64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 5,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpge_epu64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 5,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpge_epu64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 5,
                                                __u);
}




static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpgt_epi32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtd128_mask((__v4si)__a, (__v4si)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpgt_epi32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtd128_mask((__v4si)__a, (__v4si)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpgt_epu32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 6,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpgt_epu32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 6,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpgt_epi32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtd256_mask((__v8si)__a, (__v8si)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpgt_epi32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtd256_mask((__v8si)__a, (__v8si)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpgt_epu32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 6,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpgt_epu32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 6,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpgt_epi64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtq128_mask((__v2di)__a, (__v2di)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpgt_epi64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtq128_mask((__v2di)__a, (__v2di)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpgt_epu64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 6,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpgt_epu64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 6,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpgt_epi64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtq256_mask((__v4di)__a, (__v4di)__b,
                                                  (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpgt_epi64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_pcmpgtq256_mask((__v4di)__a, (__v4di)__b,
                                                  __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpgt_epu64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 6,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpgt_epu64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 6,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmple_epi32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 2,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmple_epi32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 2,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmple_epu32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 2,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmple_epu32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 2,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmple_epi32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 2,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmple_epi32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 2,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmple_epu32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 2,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmple_epu32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 2,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmple_epi64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 2,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmple_epi64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 2,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmple_epu64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 2,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmple_epu64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 2,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmple_epi64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 2,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmple_epi64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 2,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmple_epu64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 2,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmple_epu64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 2,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmplt_epi32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 1,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmplt_epi32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 1,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmplt_epu32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 1,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmplt_epu32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 1,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmplt_epi32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 1,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmplt_epi32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 1,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmplt_epu32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 1,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmplt_epu32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 1,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmplt_epi64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 1,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmplt_epi64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 1,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmplt_epu64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 1,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmplt_epu64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 1,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmplt_epi64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 1,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmplt_epi64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 1,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmplt_epu64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 1,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmplt_epu64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 1,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpneq_epi32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 4,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpneq_epi32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)__a, (__v4si)__b, 4,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpneq_epu32_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 4,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpneq_epu32_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)__a, (__v4si)__b, 4,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpneq_epi32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 4,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpneq_epi32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)__a, (__v8si)__b, 4,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpneq_epu32_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 4,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpneq_epu32_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)__a, (__v8si)__b, 4,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpneq_epi64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 4,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpneq_epi64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)__a, (__v2di)__b, 4,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_cmpneq_epu64_mask(__m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 4,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_cmpneq_epu64_mask(__mmask8 __u, __m128i __a, __m128i __b) {
  return (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)__a, (__v2di)__b, 4,
                                                __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpneq_epi64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 4,
                                               (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpneq_epi64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)__a, (__v4di)__b, 4,
                                               __u);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_cmpneq_epu64_mask(__m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 4,
                                                (__mmask8)-1);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_cmpneq_epu64_mask(__mmask8 __u, __m256i __a, __m256i __b) {
  return (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)__a, (__v4di)__b, 4,
                                                __u);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_add_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_paddd256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_add_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_paddd256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_add_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_paddq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_add_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_paddq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sub_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_psubd256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sub_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_psubd256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sub_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_psubq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sub_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_psubq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_add_epi32 (__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i) __builtin_ia32_paddd128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_add_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_paddd128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_add_epi64 (__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i) __builtin_ia32_paddq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_add_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_paddq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sub_epi32 (__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i) __builtin_ia32_psubd128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sub_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_psubd128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sub_epi64 (__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i) __builtin_ia32_psubq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sub_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_psubq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mul_epi32 (__m256i __W, __mmask8 __M, __m256i __X,
           __m256i __Y)
{
  return (__m256i) __builtin_ia32_pmuldq256_mask ((__v8si) __X,
              (__v8si) __Y,
              (__v4di) __W, __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mul_epi32 (__mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i) __builtin_ia32_pmuldq256_mask ((__v8si) __X,
              (__v8si) __Y,
              (__v4di)
              _mm256_setzero_si256 (),
              __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mul_epi32 (__m128i __W, __mmask8 __M, __m128i __X,
        __m128i __Y)
{
  return (__m128i) __builtin_ia32_pmuldq128_mask ((__v4si) __X,
              (__v4si) __Y,
              (__v2di) __W, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mul_epi32 (__mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i) __builtin_ia32_pmuldq128_mask ((__v4si) __X,
              (__v4si) __Y,
              (__v2di)
              _mm_setzero_si128 (),
              __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mul_epu32 (__m256i __W, __mmask8 __M, __m256i __X,
           __m256i __Y)
{
  return (__m256i) __builtin_ia32_pmuludq256_mask ((__v8si) __X,
               (__v8si) __Y,
               (__v4di) __W, __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mul_epu32 (__mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i) __builtin_ia32_pmuludq256_mask ((__v8si) __X,
               (__v8si) __Y,
               (__v4di)
               _mm256_setzero_si256 (),
               __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mul_epu32 (__m128i __W, __mmask8 __M, __m128i __X,
        __m128i __Y)
{
  return (__m128i) __builtin_ia32_pmuludq128_mask ((__v4si) __X,
               (__v4si) __Y,
               (__v2di) __W, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mul_epu32 (__mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i) __builtin_ia32_pmuludq128_mask ((__v4si) __X,
               (__v4si) __Y,
               (__v2di)
               _mm_setzero_si128 (),
               __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mullo_epi32 (__mmask8 __M, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pmulld256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si)
              _mm256_setzero_si256 (),
              __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mullo_epi32 (__m256i __W, __mmask8 __M, __m256i __A,
       __m256i __B)
{
  return (__m256i) __builtin_ia32_pmulld256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si) __W, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mullo_epi32 (__mmask8 __M, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pmulld128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si)
              _mm_setzero_si128 (),
              __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mullo_epi32 (__m128i __W, __mmask16 __M, __m128i __A,
          __m128i __B)
{
  return (__m128i) __builtin_ia32_pmulld128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si) __W, __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_and_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_pandd256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_and_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pandd256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_and_epi32 (__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pandd128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_and_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pandd128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_andnot_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
        __m256i __B)
{
  return (__m256i) __builtin_ia32_pandnd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si) __W,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_andnot_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pandnd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si)
              _mm256_setzero_si256 (),
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_andnot_epi32 (__m128i __W, __mmask8 __U, __m128i __A,
           __m128i __B)
{
  return (__m128i) __builtin_ia32_pandnd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si) __W,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_andnot_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pandnd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si)
              _mm_setzero_si128 (),
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_or_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
          __m256i __B)
{
  return (__m256i) __builtin_ia32_pord256_mask ((__v8si) __A,
            (__v8si) __B,
            (__v8si) __W,
            (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_or_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pord256_mask ((__v8si) __A,
            (__v8si) __B,
            (__v8si)
            _mm256_setzero_si256 (),
            (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_or_epi32 (__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pord128_mask ((__v4si) __A,
            (__v4si) __B,
            (__v4si) __W,
            (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_or_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pord128_mask ((__v4si) __A,
            (__v4si) __B,
            (__v4si)
            _mm_setzero_si128 (),
            (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_xor_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_pxord256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_xor_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pxord256_mask ((__v8si) __A,
             (__v8si) __B,
             (__v8si)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_xor_epi32 (__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i) __builtin_ia32_pxord128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_xor_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pxord128_mask ((__v4si) __A,
             (__v4si) __B,
             (__v4si)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_and_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_pandq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di) __W, __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_and_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pandq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di)
             _mm256_setzero_pd (),
             __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_and_epi64 (__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i) __builtin_ia32_pandq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di) __W, __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_and_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pandq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di)
             _mm_setzero_pd (),
             __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_andnot_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
        __m256i __B)
{
  return (__m256i) __builtin_ia32_pandnq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W, __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_andnot_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pandnq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_pd (),
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_andnot_epi64 (__m128i __W, __mmask8 __U, __m128i __A,
           __m128i __B)
{
  return (__m128i) __builtin_ia32_pandnq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W, __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_andnot_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pandnq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_pd (),
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_or_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
          __m256i __B)
{
  return (__m256i) __builtin_ia32_porq256_mask ((__v4di) __A,
            (__v4di) __B,
            (__v4di) __W,
            (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_or_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_porq256_mask ((__v4di) __A,
            (__v4di) __B,
            (__v4di)
            _mm256_setzero_si256 (),
            (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_or_epi64 (__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_porq128_mask ((__v2di) __A,
            (__v2di) __B,
            (__v2di) __W,
            (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_or_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_porq128_mask ((__v2di) __A,
            (__v2di) __B,
            (__v2di)
            _mm_setzero_si128 (),
            (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_xor_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
           __m256i __B)
{
  return (__m256i) __builtin_ia32_pxorq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_xor_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_pxorq256_mask ((__v4di) __A,
             (__v4di) __B,
             (__v4di)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_xor_epi64 (__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i) __builtin_ia32_pxorq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_xor_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_pxorq128_mask ((__v2di) __A,
             (__v2di) __B,
             (__v2di)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

#define _mm_cmp_epi32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)(__m128i)(a), \
                                        (__v4si)(__m128i)(b), \
                                        (p), (__mmask8)-1); })

#define _mm_mask_cmp_epi32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)(__m128i)(a), \
                                        (__v4si)(__m128i)(b), \
                                        (p), (__mmask8)(m)); })

#define _mm_cmp_epu32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)(__m128i)(a), \
                                         (__v4si)(__m128i)(b), \
                                         (p), (__mmask8)-1); })

#define _mm_mask_cmp_epu32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)(__m128i)(a), \
                                         (__v4si)(__m128i)(b), \
                                         (p), (__mmask8)(m)); })

#define _mm256_cmp_epi32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)(__m256i)(a), \
                                        (__v8si)(__m256i)(b), \
                                        (p), (__mmask8)-1); })

#define _mm256_mask_cmp_epi32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)(__m256i)(a), \
                                        (__v8si)(__m256i)(b), \
                                        (p), (__mmask8)(m)); })

#define _mm256_cmp_epu32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)(__m256i)(a), \
                                         (__v8si)(__m256i)(b), \
                                         (p), (__mmask8)-1); })

#define _mm256_mask_cmp_epu32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)(__m256i)(a), \
                                         (__v8si)(__m256i)(b), \
                                         (p), (__mmask8)(m)); })

#define _mm_cmp_epi64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)(__m128i)(a), \
                                        (__v2di)(__m128i)(b), \
                                        (p), (__mmask8)-1); })

#define _mm_mask_cmp_epi64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)(__m128i)(a), \
                                        (__v2di)(__m128i)(b), \
                                        (p), (__mmask8)(m)); })

#define _mm_cmp_epu64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)(__m128i)(a), \
                                         (__v2di)(__m128i)(b), \
                                         (p), (__mmask8)-1); })

#define _mm_mask_cmp_epu64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)(__m128i)(a), \
                                         (__v2di)(__m128i)(b), \
                                         (p), (__mmask8)(m)); })

#define _mm256_cmp_epi64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)(__m256i)(a), \
                                        (__v4di)(__m256i)(b), \
                                        (p), (__mmask8)-1); })

#define _mm256_mask_cmp_epi64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)(__m256i)(a), \
                                        (__v4di)(__m256i)(b), \
                                        (p), (__mmask8)(m)); })

#define _mm256_cmp_epu64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)(__m256i)(a), \
                                         (__v4di)(__m256i)(b), \
                                         (p), (__mmask8)-1); })

#define _mm256_mask_cmp_epu64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)(__m256i)(a), \
                                         (__v4di)(__m256i)(b), \
                                         (p), (__mmask8)(m)); })

#define _mm256_cmp_ps_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps256_mask((__v8sf)(__m256)(a), \
                                         (__v8sf)(__m256)(b), \
                                         (p), (__mmask8)-1); })

#define _mm256_mask_cmp_ps_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps256_mask((__v8sf)(__m256)(a), \
                                         (__v8sf)(__m256)(b), \
                                         (p), (__mmask8)(m)); })

#define _mm256_cmp_pd_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd256_mask((__v4df)(__m256)(a), \
                                         (__v4df)(__m256)(b), \
                                         (p), (__mmask8)-1); })

#define _mm256_mask_cmp_pd_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd256_mask((__v4df)(__m256)(a), \
                                         (__v4df)(__m256)(b), \
                                         (p), (__mmask8)(m)); })

#define _mm128_cmp_ps_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps128_mask((__v4sf)(__m128)(a), \
                                         (__v4sf)(__m128)(b), \
                                         (p), (__mmask8)-1); })

#define _mm128_mask_cmp_ps_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps128_mask((__v4sf)(__m128)(a), \
                                         (__v4sf)(__m128)(b), \
                                         (p), (__mmask8)(m)); })

#define _mm128_cmp_pd_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd128_mask((__v2df)(__m128)(a), \
                                         (__v2df)(__m128)(b), \
                                         (p), (__mmask8)-1); })

#define _mm128_mask_cmp_pd_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd128_mask((__v2df)(__m128)(a), \
                                         (__v2df)(__m128)(b), \
                                         (p), (__mmask8)(m)); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_fmadd_pd(__m128d __A, __mmask8 __U, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_mask ((__v2df) __A,
                                                    (__v2df) __B,
                                                    (__v2df) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask3_fmadd_pd(__m128d __A, __m128d __B, __m128d __C, __mmask8 __U)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_mask3 ((__v2df) __A,
                                                     (__v2df) __B,
                                                     (__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_fmadd_pd(__mmask8 __U, __m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_maskz ((__v2df) __A,
                                                     (__v2df) __B,
                                                     (__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_fmsub_pd(__m128d __A, __mmask8 __U, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_mask ((__v2df) __A,
                                                    (__v2df) __B,
                                                    -(__v2df) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_fmsub_pd(__mmask8 __U, __m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_maskz ((__v2df) __A,
                                                     (__v2df) __B,
                                                     -(__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask3_fnmadd_pd(__m128d __A, __m128d __B, __m128d __C, __mmask8 __U)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_mask3 (-(__v2df) __A,
                                                     (__v2df) __B,
                                                     (__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_fnmadd_pd(__mmask8 __U, __m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_maskz (-(__v2df) __A,
                                                     (__v2df) __B,
                                                     (__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_fnmsub_pd(__mmask8 __U, __m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddpd128_maskz (-(__v2df) __A,
                                                     (__v2df) __B,
                                                     -(__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_fmadd_pd(__m256d __A, __mmask8 __U, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_mask ((__v4df) __A,
                                                    (__v4df) __B,
                                                    (__v4df) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask3_fmadd_pd(__m256d __A, __m256d __B, __m256d __C, __mmask8 __U)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_mask3 ((__v4df) __A,
                                                     (__v4df) __B,
                                                     (__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_fmadd_pd(__mmask8 __U, __m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_maskz ((__v4df) __A,
                                                     (__v4df) __B,
                                                     (__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_fmsub_pd(__m256d __A, __mmask8 __U, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_mask ((__v4df) __A,
                                                    (__v4df) __B,
                                                    -(__v4df) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_fmsub_pd(__mmask8 __U, __m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_maskz ((__v4df) __A,
                                                     (__v4df) __B,
                                                     -(__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask3_fnmadd_pd(__m256d __A, __m256d __B, __m256d __C, __mmask8 __U)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_mask3 (-(__v4df) __A,
                                                     (__v4df) __B,
                                                     (__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_fnmadd_pd(__mmask8 __U, __m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_maskz (-(__v4df) __A,
                                                     (__v4df) __B,
                                                     (__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_fnmsub_pd(__mmask8 __U, __m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddpd256_maskz (-(__v4df) __A,
                                                     (__v4df) __B,
                                                     -(__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_fmadd_ps(__m128 __A, __mmask8 __U, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddps128_mask ((__v4sf) __A,
                                                   (__v4sf) __B,
                                                   (__v4sf) __C,
                                                   (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask3_fmadd_ps(__m128 __A, __m128 __B, __m128 __C, __mmask8 __U)
{
  return (__m128) __builtin_ia32_vfmaddps128_mask3 ((__v4sf) __A,
                                                    (__v4sf) __B,
                                                    (__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_fmadd_ps(__mmask8 __U, __m128 __A, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddps128_maskz ((__v4sf) __A,
                                                    (__v4sf) __B,
                                                    (__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_fmsub_ps(__m128 __A, __mmask8 __U, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddps128_mask ((__v4sf) __A,
                                                   (__v4sf) __B,
                                                   -(__v4sf) __C,
                                                   (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_fmsub_ps(__mmask8 __U, __m128 __A, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddps128_maskz ((__v4sf) __A,
                                                    (__v4sf) __B,
                                                    -(__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask3_fnmadd_ps(__m128 __A, __m128 __B, __m128 __C, __mmask8 __U)
{
  return (__m128) __builtin_ia32_vfmaddps128_mask3 (-(__v4sf) __A,
                                                    (__v4sf) __B,
                                                    (__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_fnmadd_ps(__mmask8 __U, __m128 __A, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddps128_maskz (-(__v4sf) __A,
                                                    (__v4sf) __B,
                                                    (__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_fnmsub_ps(__mmask8 __U, __m128 __A, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddps128_maskz (-(__v4sf) __A,
                                                    (__v4sf) __B,
                                                    -(__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_fmadd_ps(__m256 __A, __mmask8 __U, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddps256_mask ((__v8sf) __A,
                                                   (__v8sf) __B,
                                                   (__v8sf) __C,
                                                   (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask3_fmadd_ps(__m256 __A, __m256 __B, __m256 __C, __mmask8 __U)
{
  return (__m256) __builtin_ia32_vfmaddps256_mask3 ((__v8sf) __A,
                                                    (__v8sf) __B,
                                                    (__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_fmadd_ps(__mmask8 __U, __m256 __A, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddps256_maskz ((__v8sf) __A,
                                                    (__v8sf) __B,
                                                    (__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_fmsub_ps(__m256 __A, __mmask8 __U, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddps256_mask ((__v8sf) __A,
                                                   (__v8sf) __B,
                                                   -(__v8sf) __C,
                                                   (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_fmsub_ps(__mmask8 __U, __m256 __A, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddps256_maskz ((__v8sf) __A,
                                                    (__v8sf) __B,
                                                    -(__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask3_fnmadd_ps(__m256 __A, __m256 __B, __m256 __C, __mmask8 __U)
{
  return (__m256) __builtin_ia32_vfmaddps256_mask3 (-(__v8sf) __A,
                                                    (__v8sf) __B,
                                                    (__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_fnmadd_ps(__mmask8 __U, __m256 __A, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddps256_maskz (-(__v8sf) __A,
                                                    (__v8sf) __B,
                                                    (__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_fnmsub_ps(__mmask8 __U, __m256 __A, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddps256_maskz (-(__v8sf) __A,
                                                    (__v8sf) __B,
                                                    -(__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_fmaddsub_pd(__m128d __A, __mmask8 __U, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddsubpd128_mask ((__v2df) __A,
                                                       (__v2df) __B,
                                                       (__v2df) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask3_fmaddsub_pd(__m128d __A, __m128d __B, __m128d __C, __mmask8 __U)
{
  return (__m128d) __builtin_ia32_vfmaddsubpd128_mask3 ((__v2df) __A,
                                                        (__v2df) __B,
                                                        (__v2df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_fmaddsub_pd(__mmask8 __U, __m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddsubpd128_maskz ((__v2df) __A,
                                                        (__v2df) __B,
                                                        (__v2df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_fmsubadd_pd(__m128d __A, __mmask8 __U, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddsubpd128_mask ((__v2df) __A,
                                                       (__v2df) __B,
                                                       -(__v2df) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_fmsubadd_pd(__mmask8 __U, __m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfmaddsubpd128_maskz ((__v2df) __A,
                                                        (__v2df) __B,
                                                        -(__v2df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_fmaddsub_pd(__m256d __A, __mmask8 __U, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddsubpd256_mask ((__v4df) __A,
                                                       (__v4df) __B,
                                                       (__v4df) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask3_fmaddsub_pd(__m256d __A, __m256d __B, __m256d __C, __mmask8 __U)
{
  return (__m256d) __builtin_ia32_vfmaddsubpd256_mask3 ((__v4df) __A,
                                                        (__v4df) __B,
                                                        (__v4df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_fmaddsub_pd(__mmask8 __U, __m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddsubpd256_maskz ((__v4df) __A,
                                                        (__v4df) __B,
                                                        (__v4df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_fmsubadd_pd(__m256d __A, __mmask8 __U, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddsubpd256_mask ((__v4df) __A,
                                                       (__v4df) __B,
                                                       -(__v4df) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_fmsubadd_pd(__mmask8 __U, __m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfmaddsubpd256_maskz ((__v4df) __A,
                                                        (__v4df) __B,
                                                        -(__v4df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_fmaddsub_ps(__m128 __A, __mmask8 __U, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddsubps128_mask ((__v4sf) __A,
                                                      (__v4sf) __B,
                                                      (__v4sf) __C,
                                                      (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask3_fmaddsub_ps(__m128 __A, __m128 __B, __m128 __C, __mmask8 __U)
{
  return (__m128) __builtin_ia32_vfmaddsubps128_mask3 ((__v4sf) __A,
                                                       (__v4sf) __B,
                                                       (__v4sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_fmaddsub_ps(__mmask8 __U, __m128 __A, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddsubps128_maskz ((__v4sf) __A,
                                                       (__v4sf) __B,
                                                       (__v4sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_fmsubadd_ps(__m128 __A, __mmask8 __U, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddsubps128_mask ((__v4sf) __A,
                                                      (__v4sf) __B,
                                                      -(__v4sf) __C,
                                                      (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_fmsubadd_ps(__mmask8 __U, __m128 __A, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfmaddsubps128_maskz ((__v4sf) __A,
                                                       (__v4sf) __B,
                                                       -(__v4sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_fmaddsub_ps(__m256 __A, __mmask8 __U, __m256 __B,
                         __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddsubps256_mask ((__v8sf) __A,
                                                      (__v8sf) __B,
                                                      (__v8sf) __C,
                                                      (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask3_fmaddsub_ps(__m256 __A, __m256 __B, __m256 __C, __mmask8 __U)
{
  return (__m256) __builtin_ia32_vfmaddsubps256_mask3 ((__v8sf) __A,
                                                       (__v8sf) __B,
                                                       (__v8sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_fmaddsub_ps(__mmask8 __U, __m256 __A, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddsubps256_maskz ((__v8sf) __A,
                                                       (__v8sf) __B,
                                                       (__v8sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_fmsubadd_ps(__m256 __A, __mmask8 __U, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddsubps256_mask ((__v8sf) __A,
                                                      (__v8sf) __B,
                                                      -(__v8sf) __C,
                                                      (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_fmsubadd_ps(__mmask8 __U, __m256 __A, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfmaddsubps256_maskz ((__v8sf) __A,
                                                       (__v8sf) __B,
                                                       -(__v8sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask3_fmsub_pd(__m128d __A, __m128d __B, __m128d __C, __mmask8 __U)
{
  return (__m128d) __builtin_ia32_vfmsubpd128_mask3 ((__v2df) __A,
                                                     (__v2df) __B,
                                                     (__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask3_fmsub_pd(__m256d __A, __m256d __B, __m256d __C, __mmask8 __U)
{
  return (__m256d) __builtin_ia32_vfmsubpd256_mask3 ((__v4df) __A,
                                                     (__v4df) __B,
                                                     (__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask3_fmsub_ps(__m128 __A, __m128 __B, __m128 __C, __mmask8 __U)
{
  return (__m128) __builtin_ia32_vfmsubps128_mask3 ((__v4sf) __A,
                                                    (__v4sf) __B,
                                                    (__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask3_fmsub_ps(__m256 __A, __m256 __B, __m256 __C, __mmask8 __U)
{
  return (__m256) __builtin_ia32_vfmsubps256_mask3 ((__v8sf) __A,
                                                    (__v8sf) __B,
                                                    (__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask3_fmsubadd_pd(__m128d __A, __m128d __B, __m128d __C, __mmask8 __U)
{
  return (__m128d) __builtin_ia32_vfmsubaddpd128_mask3 ((__v2df) __A,
                                                        (__v2df) __B,
                                                        (__v2df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask3_fmsubadd_pd(__m256d __A, __m256d __B, __m256d __C, __mmask8 __U)
{
  return (__m256d) __builtin_ia32_vfmsubaddpd256_mask3 ((__v4df) __A,
                                                        (__v4df) __B,
                                                        (__v4df) __C,
                                                        (__mmask8)
                                                        __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask3_fmsubadd_ps(__m128 __A, __m128 __B, __m128 __C, __mmask8 __U)
{
  return (__m128) __builtin_ia32_vfmsubaddps128_mask3 ((__v4sf) __A,
                                                       (__v4sf) __B,
                                                       (__v4sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask3_fmsubadd_ps(__m256 __A, __m256 __B, __m256 __C, __mmask8 __U)
{
  return (__m256) __builtin_ia32_vfmsubaddps256_mask3 ((__v8sf) __A,
                                                       (__v8sf) __B,
                                                       (__v8sf) __C,
                                                       (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_fnmadd_pd(__m128d __A, __mmask8 __U, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfnmaddpd128_mask ((__v2df) __A,
                                                     (__v2df) __B,
                                                     (__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_fnmadd_pd(__m256d __A, __mmask8 __U, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfnmaddpd256_mask ((__v4df) __A,
                                                     (__v4df) __B,
                                                     (__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_fnmadd_ps(__m128 __A, __mmask8 __U, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfnmaddps128_mask ((__v4sf) __A,
                                                    (__v4sf) __B,
                                                    (__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_fnmadd_ps(__m256 __A, __mmask8 __U, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfnmaddps256_mask ((__v8sf) __A,
                                                    (__v8sf) __B,
                                                    (__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_fnmsub_pd(__m128d __A, __mmask8 __U, __m128d __B, __m128d __C)
{
  return (__m128d) __builtin_ia32_vfnmsubpd128_mask ((__v2df) __A,
                                                     (__v2df) __B,
                                                     (__v2df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask3_fnmsub_pd(__m128d __A, __m128d __B, __m128d __C, __mmask8 __U)
{
  return (__m128d) __builtin_ia32_vfnmsubpd128_mask3 ((__v2df) __A,
                                                      (__v2df) __B,
                                                      (__v2df) __C,
                                                      (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_fnmsub_pd(__m256d __A, __mmask8 __U, __m256d __B, __m256d __C)
{
  return (__m256d) __builtin_ia32_vfnmsubpd256_mask ((__v4df) __A,
                                                     (__v4df) __B,
                                                     (__v4df) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask3_fnmsub_pd(__m256d __A, __m256d __B, __m256d __C, __mmask8 __U)
{
  return (__m256d) __builtin_ia32_vfnmsubpd256_mask3 ((__v4df) __A,
                                                      (__v4df) __B,
                                                      (__v4df) __C,
                                                      (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_fnmsub_ps(__m128 __A, __mmask8 __U, __m128 __B, __m128 __C)
{
  return (__m128) __builtin_ia32_vfnmsubps128_mask ((__v4sf) __A,
                                                    (__v4sf) __B,
                                                    (__v4sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask3_fnmsub_ps(__m128 __A, __m128 __B, __m128 __C, __mmask8 __U)
{
  return (__m128) __builtin_ia32_vfnmsubps128_mask3 ((__v4sf) __A,
                                                     (__v4sf) __B,
                                                     (__v4sf) __C,
                                                     (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_fnmsub_ps(__m256 __A, __mmask8 __U, __m256 __B, __m256 __C)
{
  return (__m256) __builtin_ia32_vfnmsubps256_mask ((__v8sf) __A,
                                                    (__v8sf) __B,
                                                    (__v8sf) __C,
                                                    (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask3_fnmsub_ps(__m256 __A, __m256 __B, __m256 __C, __mmask8 __U)
{
  return (__m256) __builtin_ia32_vfnmsubps256_mask3 ((__v8sf) __A,
                                                     (__v8sf) __B,
                                                     (__v8sf) __C,
                                                     (__mmask8) __U);
}

#undef __DEFAULT_FN_ATTRS

#endif /* __AVX512VLINTRIN_H */
