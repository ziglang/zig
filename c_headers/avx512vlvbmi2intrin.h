/*===------------- avx512vlvbmi2intrin.h - VBMI2 intrinsics -----------------===
 *
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
#error "Never use <avx512vlvbmi2intrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512VLVBMI2INTRIN_H
#define __AVX512VLVBMI2INTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512vl,avx512vbmi2")))

static  __inline __m128i __DEFAULT_FN_ATTRS
_mm128_setzero_hi(void) {
  return (__m128i)(__v8hi){ 0, 0, 0, 0, 0, 0, 0, 0 };
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_compress_epi16(__m128i __S, __mmask8 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_compresshi128_mask ((__v8hi) __D,
              (__v8hi) __S,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_compress_epi16(__mmask8 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_compresshi128_mask ((__v8hi) __D,
              (__v8hi) _mm128_setzero_hi(),
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_compress_epi8(__m128i __S, __mmask16 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_compressqi128_mask ((__v16qi) __D,
              (__v16qi) __S,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_compress_epi8(__mmask16 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_compressqi128_mask ((__v16qi) __D,
              (__v16qi) _mm128_setzero_hi(),
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm128_mask_compressstoreu_epi16(void *__P, __mmask8 __U, __m128i __D)
{
  __builtin_ia32_compressstorehi128_mask ((__v8hi *) __P, (__v8hi) __D,
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm128_mask_compressstoreu_epi8(void *__P, __mmask16 __U, __m128i __D)
{
  __builtin_ia32_compressstoreqi128_mask ((__v16qi *) __P, (__v16qi) __D,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_expand_epi16(__m128i __S, __mmask8 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_expandhi128_mask ((__v8hi) __D,
              (__v8hi) __S,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_expand_epi16(__mmask8 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_expandhi128_mask ((__v8hi) __D,
              (__v8hi) _mm128_setzero_hi(),
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_expand_epi8(__m128i __S, __mmask16 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_expandqi128_mask ((__v16qi) __D,
              (__v16qi) __S,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_expand_epi8(__mmask16 __U, __m128i __D)
{
  return (__m128i) __builtin_ia32_expandqi128_mask ((__v16qi) __D,
              (__v16qi) _mm128_setzero_hi(),
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_expandloadu_epi16(__m128i __S, __mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_expandloadhi128_mask ((const __v8hi *)__P,
              (__v8hi) __S,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_expandloadu_epi16(__mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_expandloadhi128_mask ((const __v8hi *)__P,
              (__v8hi) _mm128_setzero_hi(),
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_expandloadu_epi8(__m128i __S, __mmask16 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_expandloadqi128_mask ((const __v16qi *)__P,
              (__v16qi) __S,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_expandloadu_epi8(__mmask16 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_expandloadqi128_mask ((const __v16qi *)__P,
              (__v16qi) _mm128_setzero_hi(),
              __U);
}

static  __inline __m256i __DEFAULT_FN_ATTRS
_mm256_setzero_hi(void) {
  return (__m256i)(__v16hi){ 0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0 };
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_compress_epi16(__m256i __S, __mmask16 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_compresshi256_mask ((__v16hi) __D,
              (__v16hi) __S,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_compress_epi16(__mmask16 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_compresshi256_mask ((__v16hi) __D,
              (__v16hi) _mm256_setzero_hi(),
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_compress_epi8(__m256i __S, __mmask32 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_compressqi256_mask ((__v32qi) __D,
              (__v32qi) __S,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_compress_epi8(__mmask32 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_compressqi256_mask ((__v32qi) __D,
              (__v32qi) _mm256_setzero_hi(),
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_compressstoreu_epi16(void *__P, __mmask16 __U, __m256i __D)
{
  __builtin_ia32_compressstorehi256_mask ((__v16hi *) __P, (__v16hi) __D,
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_compressstoreu_epi8(void *__P, __mmask32 __U, __m256i __D)
{
  __builtin_ia32_compressstoreqi256_mask ((__v32qi *) __P, (__v32qi) __D,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expand_epi16(__m256i __S, __mmask16 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_expandhi256_mask ((__v16hi) __D,
              (__v16hi) __S,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expand_epi16(__mmask16 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_expandhi256_mask ((__v16hi) __D,
              (__v16hi) _mm256_setzero_hi(),
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expand_epi8(__m256i __S, __mmask32 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_expandqi256_mask ((__v32qi) __D,
              (__v32qi) __S,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expand_epi8(__mmask32 __U, __m256i __D)
{
  return (__m256i) __builtin_ia32_expandqi256_mask ((__v32qi) __D,
              (__v32qi) _mm256_setzero_hi(),
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expandloadu_epi16(__m256i __S, __mmask16 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_expandloadhi256_mask ((const __v16hi *)__P,
              (__v16hi) __S,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expandloadu_epi16(__mmask16 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_expandloadhi256_mask ((const __v16hi *)__P,
              (__v16hi) _mm256_setzero_hi(),
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expandloadu_epi8(__m256i __S, __mmask32 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_expandloadqi256_mask ((const __v32qi *)__P,
              (__v32qi) __S,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expandloadu_epi8(__mmask32 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_expandloadqi256_mask ((const __v32qi *)__P,
              (__v32qi) _mm256_setzero_hi(),
              __U);
}

#define _mm256_mask_shldi_epi64(S, U, A, B, I) __extension__ ({ \
  (__m256i)__builtin_ia32_vpshldq256_mask((__v4di)(A), \
                                          (__v4di)(B), \
                                          (int)(I), \
                                          (__v4di)(S), \
                                          (__mmask8)(U)); })

#define _mm256_maskz_shldi_epi64(U, A, B, I) \
  _mm256_mask_shldi_epi64(_mm256_setzero_hi(), (U), (A), (B), (I))

#define _mm256_shldi_epi64(A, B, I) \
  _mm256_mask_shldi_epi64(_mm256_undefined_si256(), (__mmask8)(-1), (A), (B), (I))

#define _mm128_mask_shldi_epi64(S, U, A, B, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vpshldq128_mask((__v2di)(A), \
                                          (__v2di)(B), \
                                          (int)(I), \
                                          (__v2di)(S), \
                                          (__mmask8)(U)); })

#define _mm128_maskz_shldi_epi64(U, A, B, I) \
  _mm128_mask_shldi_epi64(_mm128_setzero_hi(), (U), (A), (B), (I))

#define _mm128_shldi_epi64(A, B, I) \
  _mm128_mask_shldi_epi64(_mm_undefined_si128(), (__mmask8)(-1), (A), (B), (I))

#define _mm256_mask_shldi_epi32(S, U, A, B, I) __extension__ ({ \
  (__m256i)__builtin_ia32_vpshldd256_mask((__v8si)(A), \
                                          (__v8si)(B), \
                                          (int)(I), \
                                          (__v8si)(S), \
                                          (__mmask8)(U)); })

#define _mm256_maskz_shldi_epi32(U, A, B, I) \
  _mm256_mask_shldi_epi32(_mm256_setzero_hi(), (U), (A), (B), (I))

#define _mm256_shldi_epi32(A, B, I) \
  _mm256_mask_shldi_epi32(_mm256_undefined_si256(), (__mmask8)(-1), (A), (B), (I))

#define _mm128_mask_shldi_epi32(S, U, A, B, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vpshldd128_mask((__v4si)(A), \
                                          (__v4si)(B), \
                                          (int)(I), \
                                          (__v4si)(S), \
                                          (__mmask8)(U)); })

#define _mm128_maskz_shldi_epi32(U, A, B, I) \
  _mm128_mask_shldi_epi32(_mm128_setzero_hi(), (U), (A), (B), (I))

#define _mm128_shldi_epi32(A, B, I) \
  _mm128_mask_shldi_epi32(_mm_undefined_si128(), (__mmask8)(-1), (A), (B), (I))

#define _mm256_mask_shldi_epi16(S, U, A, B, I) __extension__ ({ \
  (__m256i)__builtin_ia32_vpshldw256_mask((__v16hi)(A), \
                                          (__v16hi)(B), \
                                          (int)(I), \
                                          (__v16hi)(S), \
                                          (__mmask16)(U)); })

#define _mm256_maskz_shldi_epi16(U, A, B, I) \
  _mm256_mask_shldi_epi16(_mm256_setzero_hi(), (U), (A), (B), (I))

#define _mm256_shldi_epi16(A, B, I) \
  _mm256_mask_shldi_epi16(_mm256_undefined_si256(), (__mmask8)(-1), (A), (B), (I))

#define _mm128_mask_shldi_epi16(S, U, A, B, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vpshldw128_mask((__v8hi)(A), \
                                          (__v8hi)(B), \
                                          (int)(I), \
                                          (__v8hi)(S), \
                                          (__mmask8)(U)); })

#define _mm128_maskz_shldi_epi16(U, A, B, I) \
  _mm128_mask_shldi_epi16(_mm128_setzero_hi(), (U), (A), (B), (I))

#define _mm128_shldi_epi16(A, B, I) \
  _mm128_mask_shldi_epi16(_mm_undefined_si128(), (__mmask8)(-1), (A), (B), (I))

#define _mm256_mask_shrdi_epi64(S, U, A, B, I) __extension__ ({ \
  (__m256i)__builtin_ia32_vpshrdq256_mask((__v4di)(A), \
                                          (__v4di)(B), \
                                          (int)(I), \
                                          (__v4di)(S), \
                                          (__mmask8)(U)); })

#define _mm256_maskz_shrdi_epi64(U, A, B, I) \
  _mm256_mask_shrdi_epi64(_mm256_setzero_hi(), (U), (A), (B), (I))

#define _mm256_shrdi_epi64(A, B, I) \
  _mm256_mask_shrdi_epi64(_mm256_undefined_si256(), (__mmask8)(-1), (A), (B), (I))

#define _mm128_mask_shrdi_epi64(S, U, A, B, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vpshrdq128_mask((__v2di)(A), \
                                          (__v2di)(B), \
                                          (int)(I), \
                                          (__v2di)(S), \
                                          (__mmask8)(U)); })

#define _mm128_maskz_shrdi_epi64(U, A, B, I) \
  _mm128_mask_shrdi_epi64(_mm128_setzero_hi(), (U), (A), (B), (I))

#define _mm128_shrdi_epi64(A, B, I) \
  _mm128_mask_shrdi_epi64(_mm_undefined_si128(), (__mmask8)(-1), (A), (B), (I))

#define _mm256_mask_shrdi_epi32(S, U, A, B, I) __extension__ ({ \
  (__m256i)__builtin_ia32_vpshrdd256_mask((__v8si)(A), \
                                          (__v8si)(B), \
                                          (int)(I), \
                                          (__v8si)(S), \
                                          (__mmask8)(U)); })

#define _mm256_maskz_shrdi_epi32(U, A, B, I) \
  _mm256_mask_shrdi_epi32(_mm256_setzero_hi(), (U), (A), (B), (I))

#define _mm256_shrdi_epi32(A, B, I) \
  _mm256_mask_shrdi_epi32(_mm256_undefined_si256(), (__mmask8)(-1), (A), (B), (I))

#define _mm128_mask_shrdi_epi32(S, U, A, B, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vpshrdd128_mask((__v4si)(A), \
                                          (__v4si)(B), \
                                          (int)(I), \
                                          (__v4si)(S), \
                                          (__mmask8)(U)); })

#define _mm128_maskz_shrdi_epi32(U, A, B, I) \
  _mm128_mask_shrdi_epi32(_mm128_setzero_hi(), (U), (A), (B), (I))

#define _mm128_shrdi_epi32(A, B, I) \
  _mm128_mask_shrdi_epi32(_mm_undefined_si128(), (__mmask8)(-1), (A), (B), (I))

#define _mm256_mask_shrdi_epi16(S, U, A, B, I) __extension__ ({ \
  (__m256i)__builtin_ia32_vpshrdw256_mask((__v16hi)(A), \
                                          (__v16hi)(B), \
                                          (int)(I), \
                                          (__v16hi)(S), \
                                          (__mmask16)(U)); })

#define _mm256_maskz_shrdi_epi16(U, A, B, I) \
  _mm256_mask_shrdi_epi16(_mm256_setzero_hi(), (U), (A), (B), (I))

#define _mm256_shrdi_epi16(A, B, I) \
  _mm256_mask_shrdi_epi16(_mm256_undefined_si256(), (__mmask8)(-1), (A), (B), (I))

#define _mm128_mask_shrdi_epi16(S, U, A, B, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vpshrdw128_mask((__v8hi)(A), \
                                          (__v8hi)(B), \
                                          (int)(I), \
                                          (__v8hi)(S), \
                                          (__mmask8)(U)); })

#define _mm128_maskz_shrdi_epi16(U, A, B, I) \
  _mm128_mask_shrdi_epi16(_mm128_setzero_hi(), (U), (A), (B), (I))

#define _mm128_shrdi_epi16(A, B, I) \
  _mm128_mask_shrdi_epi16(_mm_undefined_si128(), (__mmask8)(-1), (A), (B), (I))

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_shldv_epi64(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvq256_mask ((__v4di) __S,
              (__v4di) __A,
              (__v4di) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_shldv_epi64(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvq256_maskz ((__v4di) __S,
              (__v4di) __A,
              (__v4di) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_shldv_epi64(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvq256_mask ((__v4di) __S,
              (__v4di) __A,
              (__v4di) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_shldv_epi64(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvq128_mask ((__v2di) __S,
              (__v2di) __A,
              (__v2di) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_shldv_epi64(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvq128_maskz ((__v2di) __S,
              (__v2di) __A,
              (__v2di) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_shldv_epi64(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvq128_mask ((__v2di) __S,
              (__v2di) __A,
              (__v2di) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_shldv_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_shldv_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvd256_maskz ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_shldv_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_shldv_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_shldv_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvd128_maskz ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_shldv_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_shldv_epi16(__m256i __S, __mmask16 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvw256_mask ((__v16hi) __S,
              (__v16hi) __A,
              (__v16hi) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_shldv_epi16(__mmask16 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvw256_maskz ((__v16hi) __S,
              (__v16hi) __A,
              (__v16hi) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_shldv_epi16(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshldvw256_mask ((__v16hi) __S,
              (__v16hi) __A,
              (__v16hi) __B,
              (__mmask16) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_shldv_epi16(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvw128_mask ((__v8hi) __S,
              (__v8hi) __A,
              (__v8hi) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_shldv_epi16(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvw128_maskz ((__v8hi) __S,
              (__v8hi) __A,
              (__v8hi) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_shldv_epi16(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshldvw128_mask ((__v8hi) __S,
              (__v8hi) __A,
              (__v8hi) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_shrdv_epi64(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvq256_mask ((__v4di) __S,
              (__v4di) __A,
              (__v4di) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_shrdv_epi64(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvq256_maskz ((__v4di) __S,
              (__v4di) __A,
              (__v4di) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_shrdv_epi64(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvq256_mask ((__v4di) __S,
              (__v4di) __A,
              (__v4di) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_shrdv_epi64(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvq128_mask ((__v2di) __S,
              (__v2di) __A,
              (__v2di) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_shrdv_epi64(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvq128_maskz ((__v2di) __S,
              (__v2di) __A,
              (__v2di) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_shrdv_epi64(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvq128_mask ((__v2di) __S,
              (__v2di) __A,
              (__v2di) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_shrdv_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_shrdv_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvd256_maskz ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_shrdv_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_shrdv_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_shrdv_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvd128_maskz ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_shrdv_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_shrdv_epi16(__m256i __S, __mmask16 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvw256_mask ((__v16hi) __S,
              (__v16hi) __A,
              (__v16hi) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_shrdv_epi16(__mmask16 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvw256_maskz ((__v16hi) __S,
              (__v16hi) __A,
              (__v16hi) __B,
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_shrdv_epi16(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpshrdvw256_mask ((__v16hi) __S,
              (__v16hi) __A,
              (__v16hi) __B,
              (__mmask16) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_shrdv_epi16(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvw128_mask ((__v8hi) __S,
              (__v8hi) __A,
              (__v8hi) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_shrdv_epi16(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvw128_maskz ((__v8hi) __S,
              (__v8hi) __A,
              (__v8hi) __B,
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_shrdv_epi16(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpshrdvw128_mask ((__v8hi) __S,
              (__v8hi) __A,
              (__v8hi) __B,
              (__mmask8) -1);
}


#undef __DEFAULT_FN_ATTRS

#endif
