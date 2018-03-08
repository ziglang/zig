/*===------------- avx512vbmi2intrin.h - VBMI2 intrinsics ------------------===
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
#error "Never use <avx512vbmi2intrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512VBMI2INTRIN_H
#define __AVX512VBMI2INTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512vbmi2")))


static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_compress_epi16(__m512i __S, __mmask32 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_compresshi512_mask ((__v32hi) __D,
              (__v32hi) __S,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_compress_epi16(__mmask32 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_compresshi512_mask ((__v32hi) __D,
              (__v32hi) _mm512_setzero_hi(),
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_compress_epi8(__m512i __S, __mmask64 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_compressqi512_mask ((__v64qi) __D,
              (__v64qi) __S,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_compress_epi8(__mmask64 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_compressqi512_mask ((__v64qi) __D,
              (__v64qi) _mm512_setzero_qi(),
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm512_mask_compressstoreu_epi16(void *__P, __mmask32 __U, __m512i __D)
{
  __builtin_ia32_compressstorehi512_mask ((__v32hi *) __P, (__v32hi) __D,
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm512_mask_compressstoreu_epi8(void *__P, __mmask64 __U, __m512i __D)
{
  __builtin_ia32_compressstoreqi512_mask ((__v64qi *) __P, (__v64qi) __D,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_expand_epi16(__m512i __S, __mmask32 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_expandhi512_mask ((__v32hi) __D,
              (__v32hi) __S,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_expand_epi16(__mmask32 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_expandhi512_mask ((__v32hi) __D,
              (__v32hi) _mm512_setzero_hi(),
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_expand_epi8(__m512i __S, __mmask64 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_expandqi512_mask ((__v64qi) __D,
              (__v64qi) __S,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_expand_epi8(__mmask64 __U, __m512i __D)
{
  return (__m512i) __builtin_ia32_expandqi512_mask ((__v64qi) __D,
              (__v64qi) _mm512_setzero_qi(),
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_expandloadu_epi16(__m512i __S, __mmask32 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_expandloadhi512_mask ((const __v32hi *)__P,
              (__v32hi) __S,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_expandloadu_epi16(__mmask32 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_expandloadhi512_mask ((const __v32hi *)__P,
              (__v32hi) _mm512_setzero_hi(),
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_expandloadu_epi8(__m512i __S, __mmask64 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_expandloadqi512_mask ((const __v64qi *)__P,
              (__v64qi) __S,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_expandloadu_epi8(__mmask64 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_expandloadqi512_mask ((const __v64qi *)__P,
              (__v64qi) _mm512_setzero_qi(),
              __U);
}

#define _mm512_mask_shldi_epi64(S, U, A, B, I) __extension__ ({ \
  (__m512i)__builtin_ia32_vpshldq512_mask((__v8di)(A), \
                                          (__v8di)(B), \
                                          (int)(I), \
                                          (__v8di)(S), \
                                          (__mmask8)(U)); })

#define _mm512_maskz_shldi_epi64(U, A, B, I) \
  _mm512_mask_shldi_epi64(_mm512_setzero_hi(), (U), (A), (B), (I))

#define _mm512_shldi_epi64(A, B, I) \
  _mm512_mask_shldi_epi64(_mm512_undefined(), (__mmask8)(-1), (A), (B), (I))

#define _mm512_mask_shldi_epi32(S, U, A, B, I) __extension__ ({ \
  (__m512i)__builtin_ia32_vpshldd512_mask((__v16si)(A), \
                                          (__v16si)(B), \
                                          (int)(I), \
                                          (__v16si)(S), \
                                          (__mmask16)(U)); })

#define _mm512_maskz_shldi_epi32(U, A, B, I) \
  _mm512_mask_shldi_epi32(_mm512_setzero_hi(), (U), (A), (B), (I))

#define _mm512_shldi_epi32(A, B, I) \
  _mm512_mask_shldi_epi32(_mm512_undefined(), (__mmask16)(-1), (A), (B), (I))

#define _mm512_mask_shldi_epi16(S, U, A, B, I) __extension__ ({ \
  (__m512i)__builtin_ia32_vpshldw512_mask((__v32hi)(A), \
                                          (__v32hi)(B), \
                                          (int)(I), \
                                          (__v32hi)(S), \
                                          (__mmask32)(U)); })

#define _mm512_maskz_shldi_epi16(U, A, B, I) \
  _mm512_mask_shldi_epi16(_mm512_setzero_hi(), (U), (A), (B), (I))

#define _mm512_shldi_epi16(A, B, I) \
  _mm512_mask_shldi_epi16(_mm512_undefined(), (__mmask32)(-1), (A), (B), (I))

#define _mm512_mask_shrdi_epi64(S, U, A, B, I) __extension__ ({ \
  (__m512i)__builtin_ia32_vpshrdq512_mask((__v8di)(A), \
                                          (__v8di)(B), \
                                          (int)(I), \
                                          (__v8di)(S), \
                                          (__mmask8)(U)); })

#define _mm512_maskz_shrdi_epi64(U, A, B, I) \
  _mm512_mask_shrdi_epi64(_mm512_setzero_hi(), (U), (A), (B), (I))

#define _mm512_shrdi_epi64(A, B, I) \
  _mm512_mask_shrdi_epi64(_mm512_undefined(), (__mmask8)(-1), (A), (B), (I))

#define _mm512_mask_shrdi_epi32(S, U, A, B, I) __extension__ ({ \
  (__m512i)__builtin_ia32_vpshrdd512_mask((__v16si)(A), \
                                          (__v16si)(B), \
                                          (int)(I), \
                                          (__v16si)(S), \
                                          (__mmask16)(U)); })

#define _mm512_maskz_shrdi_epi32(U, A, B, I) \
  _mm512_mask_shrdi_epi32(_mm512_setzero_hi(), (U), (A), (B), (I))

#define _mm512_shrdi_epi32(A, B, I) \
  _mm512_mask_shrdi_epi32(_mm512_undefined(), (__mmask16)(-1), (A), (B), (I))

#define _mm512_mask_shrdi_epi16(S, U, A, B, I) __extension__ ({ \
  (__m512i)__builtin_ia32_vpshrdw512_mask((__v32hi)(A), \
                                          (__v32hi)(B), \
                                          (int)(I), \
                                          (__v32hi)(S), \
                                          (__mmask32)(U)); })

#define _mm512_maskz_shrdi_epi16(U, A, B, I) \
  _mm512_mask_shrdi_epi16(_mm512_setzero_hi(), (U), (A), (B), (I))

#define _mm512_shrdi_epi16(A, B, I) \
  _mm512_mask_shrdi_epi16(_mm512_undefined(), (__mmask32)(-1), (A), (B), (I))

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_shldv_epi64(__m512i __S, __mmask8 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvq512_mask ((__v8di) __S,
              (__v8di) __A,
              (__v8di) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_shldv_epi64(__mmask8 __U, __m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvq512_maskz ((__v8di) __S,
              (__v8di) __A,
              (__v8di) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_shldv_epi64(__m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvq512_mask ((__v8di) __S,
              (__v8di) __A,
              (__v8di) __B,
              (__mmask8) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_shldv_epi32(__m512i __S, __mmask16 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvd512_mask ((__v16si) __S,
              (__v16si) __A,
              (__v16si) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_shldv_epi32(__mmask16 __U, __m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvd512_maskz ((__v16si) __S,
              (__v16si) __A,
              (__v16si) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_shldv_epi32(__m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvd512_mask ((__v16si) __S,
              (__v16si) __A,
              (__v16si) __B,
              (__mmask16) -1);
}


static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_shldv_epi16(__m512i __S, __mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvw512_mask ((__v32hi) __S,
              (__v32hi) __A,
              (__v32hi) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_shldv_epi16(__mmask32 __U, __m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvw512_maskz ((__v32hi) __S,
              (__v32hi) __A,
              (__v32hi) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_shldv_epi16(__m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshldvw512_mask ((__v32hi) __S,
              (__v32hi) __A,
              (__v32hi) __B,
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_shrdv_epi64(__m512i __S, __mmask8 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvq512_mask ((__v8di) __S,
              (__v8di) __A,
              (__v8di) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_shrdv_epi64(__mmask8 __U, __m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvq512_maskz ((__v8di) __S,
              (__v8di) __A,
              (__v8di) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_shrdv_epi64(__m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvq512_mask ((__v8di) __S,
              (__v8di) __A,
              (__v8di) __B,
              (__mmask8) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_shrdv_epi32(__m512i __S, __mmask16 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvd512_mask ((__v16si) __S,
              (__v16si) __A,
              (__v16si) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_shrdv_epi32(__mmask16 __U, __m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvd512_maskz ((__v16si) __S,
              (__v16si) __A,
              (__v16si) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_shrdv_epi32(__m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvd512_mask ((__v16si) __S,
              (__v16si) __A,
              (__v16si) __B,
              (__mmask16) -1);
}


static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_shrdv_epi16(__m512i __S, __mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvw512_mask ((__v32hi) __S,
              (__v32hi) __A,
              (__v32hi) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_shrdv_epi16(__mmask32 __U, __m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvw512_maskz ((__v32hi) __S,
              (__v32hi) __A,
              (__v32hi) __B,
              __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_shrdv_epi16(__m512i __S, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpshrdvw512_mask ((__v32hi) __S,
              (__v32hi) __A,
              (__v32hi) __B,
              (__mmask32) -1);
}


#undef __DEFAULT_FN_ATTRS

#endif

