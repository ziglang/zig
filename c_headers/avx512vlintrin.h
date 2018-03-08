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

#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512vl")))

/* Doesn't require avx512vl, used in avx512dqintrin.h */
static  __inline __m128i __attribute__((__always_inline__, __nodebug__, __target__("avx512f")))
_mm_setzero_di(void) {
  return (__m128i)(__v2di){ 0LL, 0LL};
}

/* Integer compare */

#define _mm_cmpeq_epi32_mask(A, B) \
    _mm_cmp_epi32_mask((A), (B), _MM_CMPINT_EQ)
#define _mm_mask_cmpeq_epi32_mask(k, A, B) \
    _mm_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm_cmpge_epi32_mask(A, B) \
    _mm_cmp_epi32_mask((A), (B), _MM_CMPINT_GE)
#define _mm_mask_cmpge_epi32_mask(k, A, B) \
    _mm_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm_cmpgt_epi32_mask(A, B) \
    _mm_cmp_epi32_mask((A), (B), _MM_CMPINT_GT)
#define _mm_mask_cmpgt_epi32_mask(k, A, B) \
    _mm_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm_cmple_epi32_mask(A, B) \
    _mm_cmp_epi32_mask((A), (B), _MM_CMPINT_LE)
#define _mm_mask_cmple_epi32_mask(k, A, B) \
    _mm_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm_cmplt_epi32_mask(A, B) \
    _mm_cmp_epi32_mask((A), (B), _MM_CMPINT_LT)
#define _mm_mask_cmplt_epi32_mask(k, A, B) \
    _mm_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm_cmpneq_epi32_mask(A, B) \
    _mm_cmp_epi32_mask((A), (B), _MM_CMPINT_NE)
#define _mm_mask_cmpneq_epi32_mask(k, A, B) \
    _mm_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm256_cmpeq_epi32_mask(A, B) \
    _mm256_cmp_epi32_mask((A), (B), _MM_CMPINT_EQ)
#define _mm256_mask_cmpeq_epi32_mask(k, A, B) \
    _mm256_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm256_cmpge_epi32_mask(A, B) \
    _mm256_cmp_epi32_mask((A), (B), _MM_CMPINT_GE)
#define _mm256_mask_cmpge_epi32_mask(k, A, B) \
    _mm256_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm256_cmpgt_epi32_mask(A, B) \
    _mm256_cmp_epi32_mask((A), (B), _MM_CMPINT_GT)
#define _mm256_mask_cmpgt_epi32_mask(k, A, B) \
    _mm256_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm256_cmple_epi32_mask(A, B) \
    _mm256_cmp_epi32_mask((A), (B), _MM_CMPINT_LE)
#define _mm256_mask_cmple_epi32_mask(k, A, B) \
    _mm256_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm256_cmplt_epi32_mask(A, B) \
    _mm256_cmp_epi32_mask((A), (B), _MM_CMPINT_LT)
#define _mm256_mask_cmplt_epi32_mask(k, A, B) \
    _mm256_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm256_cmpneq_epi32_mask(A, B) \
    _mm256_cmp_epi32_mask((A), (B), _MM_CMPINT_NE)
#define _mm256_mask_cmpneq_epi32_mask(k, A, B) \
    _mm256_mask_cmp_epi32_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm_cmpeq_epu32_mask(A, B) \
    _mm_cmp_epu32_mask((A), (B), _MM_CMPINT_EQ)
#define _mm_mask_cmpeq_epu32_mask(k, A, B) \
    _mm_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm_cmpge_epu32_mask(A, B) \
    _mm_cmp_epu32_mask((A), (B), _MM_CMPINT_GE)
#define _mm_mask_cmpge_epu32_mask(k, A, B) \
    _mm_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm_cmpgt_epu32_mask(A, B) \
    _mm_cmp_epu32_mask((A), (B), _MM_CMPINT_GT)
#define _mm_mask_cmpgt_epu32_mask(k, A, B) \
    _mm_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm_cmple_epu32_mask(A, B) \
    _mm_cmp_epu32_mask((A), (B), _MM_CMPINT_LE)
#define _mm_mask_cmple_epu32_mask(k, A, B) \
    _mm_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm_cmplt_epu32_mask(A, B) \
    _mm_cmp_epu32_mask((A), (B), _MM_CMPINT_LT)
#define _mm_mask_cmplt_epu32_mask(k, A, B) \
    _mm_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm_cmpneq_epu32_mask(A, B) \
    _mm_cmp_epu32_mask((A), (B), _MM_CMPINT_NE)
#define _mm_mask_cmpneq_epu32_mask(k, A, B) \
    _mm_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm256_cmpeq_epu32_mask(A, B) \
    _mm256_cmp_epu32_mask((A), (B), _MM_CMPINT_EQ)
#define _mm256_mask_cmpeq_epu32_mask(k, A, B) \
    _mm256_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm256_cmpge_epu32_mask(A, B) \
    _mm256_cmp_epu32_mask((A), (B), _MM_CMPINT_GE)
#define _mm256_mask_cmpge_epu32_mask(k, A, B) \
    _mm256_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm256_cmpgt_epu32_mask(A, B) \
    _mm256_cmp_epu32_mask((A), (B), _MM_CMPINT_GT)
#define _mm256_mask_cmpgt_epu32_mask(k, A, B) \
    _mm256_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm256_cmple_epu32_mask(A, B) \
    _mm256_cmp_epu32_mask((A), (B), _MM_CMPINT_LE)
#define _mm256_mask_cmple_epu32_mask(k, A, B) \
    _mm256_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm256_cmplt_epu32_mask(A, B) \
    _mm256_cmp_epu32_mask((A), (B), _MM_CMPINT_LT)
#define _mm256_mask_cmplt_epu32_mask(k, A, B) \
    _mm256_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm256_cmpneq_epu32_mask(A, B) \
    _mm256_cmp_epu32_mask((A), (B), _MM_CMPINT_NE)
#define _mm256_mask_cmpneq_epu32_mask(k, A, B) \
    _mm256_mask_cmp_epu32_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm_cmpeq_epi64_mask(A, B) \
    _mm_cmp_epi64_mask((A), (B), _MM_CMPINT_EQ)
#define _mm_mask_cmpeq_epi64_mask(k, A, B) \
    _mm_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm_cmpge_epi64_mask(A, B) \
    _mm_cmp_epi64_mask((A), (B), _MM_CMPINT_GE)
#define _mm_mask_cmpge_epi64_mask(k, A, B) \
    _mm_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm_cmpgt_epi64_mask(A, B) \
    _mm_cmp_epi64_mask((A), (B), _MM_CMPINT_GT)
#define _mm_mask_cmpgt_epi64_mask(k, A, B) \
    _mm_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm_cmple_epi64_mask(A, B) \
    _mm_cmp_epi64_mask((A), (B), _MM_CMPINT_LE)
#define _mm_mask_cmple_epi64_mask(k, A, B) \
    _mm_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm_cmplt_epi64_mask(A, B) \
    _mm_cmp_epi64_mask((A), (B), _MM_CMPINT_LT)
#define _mm_mask_cmplt_epi64_mask(k, A, B) \
    _mm_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm_cmpneq_epi64_mask(A, B) \
    _mm_cmp_epi64_mask((A), (B), _MM_CMPINT_NE)
#define _mm_mask_cmpneq_epi64_mask(k, A, B) \
    _mm_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm256_cmpeq_epi64_mask(A, B) \
    _mm256_cmp_epi64_mask((A), (B), _MM_CMPINT_EQ)
#define _mm256_mask_cmpeq_epi64_mask(k, A, B) \
    _mm256_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm256_cmpge_epi64_mask(A, B) \
    _mm256_cmp_epi64_mask((A), (B), _MM_CMPINT_GE)
#define _mm256_mask_cmpge_epi64_mask(k, A, B) \
    _mm256_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm256_cmpgt_epi64_mask(A, B) \
    _mm256_cmp_epi64_mask((A), (B), _MM_CMPINT_GT)
#define _mm256_mask_cmpgt_epi64_mask(k, A, B) \
    _mm256_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm256_cmple_epi64_mask(A, B) \
    _mm256_cmp_epi64_mask((A), (B), _MM_CMPINT_LE)
#define _mm256_mask_cmple_epi64_mask(k, A, B) \
    _mm256_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm256_cmplt_epi64_mask(A, B) \
    _mm256_cmp_epi64_mask((A), (B), _MM_CMPINT_LT)
#define _mm256_mask_cmplt_epi64_mask(k, A, B) \
    _mm256_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm256_cmpneq_epi64_mask(A, B) \
    _mm256_cmp_epi64_mask((A), (B), _MM_CMPINT_NE)
#define _mm256_mask_cmpneq_epi64_mask(k, A, B) \
    _mm256_mask_cmp_epi64_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm_cmpeq_epu64_mask(A, B) \
    _mm_cmp_epu64_mask((A), (B), _MM_CMPINT_EQ)
#define _mm_mask_cmpeq_epu64_mask(k, A, B) \
    _mm_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm_cmpge_epu64_mask(A, B) \
    _mm_cmp_epu64_mask((A), (B), _MM_CMPINT_GE)
#define _mm_mask_cmpge_epu64_mask(k, A, B) \
    _mm_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm_cmpgt_epu64_mask(A, B) \
    _mm_cmp_epu64_mask((A), (B), _MM_CMPINT_GT)
#define _mm_mask_cmpgt_epu64_mask(k, A, B) \
    _mm_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm_cmple_epu64_mask(A, B) \
    _mm_cmp_epu64_mask((A), (B), _MM_CMPINT_LE)
#define _mm_mask_cmple_epu64_mask(k, A, B) \
    _mm_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm_cmplt_epu64_mask(A, B) \
    _mm_cmp_epu64_mask((A), (B), _MM_CMPINT_LT)
#define _mm_mask_cmplt_epu64_mask(k, A, B) \
    _mm_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm_cmpneq_epu64_mask(A, B) \
    _mm_cmp_epu64_mask((A), (B), _MM_CMPINT_NE)
#define _mm_mask_cmpneq_epu64_mask(k, A, B) \
    _mm_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm256_cmpeq_epu64_mask(A, B) \
    _mm256_cmp_epu64_mask((A), (B), _MM_CMPINT_EQ)
#define _mm256_mask_cmpeq_epu64_mask(k, A, B) \
    _mm256_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm256_cmpge_epu64_mask(A, B) \
    _mm256_cmp_epu64_mask((A), (B), _MM_CMPINT_GE)
#define _mm256_mask_cmpge_epu64_mask(k, A, B) \
    _mm256_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm256_cmpgt_epu64_mask(A, B) \
    _mm256_cmp_epu64_mask((A), (B), _MM_CMPINT_GT)
#define _mm256_mask_cmpgt_epu64_mask(k, A, B) \
    _mm256_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm256_cmple_epu64_mask(A, B) \
    _mm256_cmp_epu64_mask((A), (B), _MM_CMPINT_LE)
#define _mm256_mask_cmple_epu64_mask(k, A, B) \
    _mm256_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm256_cmplt_epu64_mask(A, B) \
    _mm256_cmp_epu64_mask((A), (B), _MM_CMPINT_LT)
#define _mm256_mask_cmplt_epu64_mask(k, A, B) \
    _mm256_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm256_cmpneq_epu64_mask(A, B) \
    _mm256_cmp_epu64_mask((A), (B), _MM_CMPINT_NE)
#define _mm256_mask_cmpneq_epu64_mask(k, A, B) \
    _mm256_mask_cmp_epu64_mask((k), (A), (B), _MM_CMPINT_NE)

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_add_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_add_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_add_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_add_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_add_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_add_epi64(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_add_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_add_epi64(__A, __B),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sub_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_sub_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sub_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_sub_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sub_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_sub_epi64(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sub_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_sub_epi64(__A, __B),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_add_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_add_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_add_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_add_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_add_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_add_epi64(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_add_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_add_epi64(__A, __B),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sub_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sub_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sub_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sub_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sub_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_sub_epi64(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sub_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_sub_epi64(__A, __B),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mul_epi32(__m256i __W, __mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__M,
                                             (__v4di)_mm256_mul_epi32(__X, __Y),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mul_epi32(__mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__M,
                                             (__v4di)_mm256_mul_epi32(__X, __Y),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mul_epi32(__m128i __W, __mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__M,
                                             (__v2di)_mm_mul_epi32(__X, __Y),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mul_epi32(__mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__M,
                                             (__v2di)_mm_mul_epi32(__X, __Y),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mul_epu32(__m256i __W, __mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__M,
                                             (__v4di)_mm256_mul_epu32(__X, __Y),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mul_epu32(__mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__M,
                                             (__v4di)_mm256_mul_epu32(__X, __Y),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mul_epu32(__m128i __W, __mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__M,
                                             (__v2di)_mm_mul_epu32(__X, __Y),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mul_epu32(__mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__M,
                                             (__v2di)_mm_mul_epu32(__X, __Y),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mullo_epi32(__mmask8 __M, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_mullo_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mullo_epi32(__m256i __W, __mmask8 __M, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_mullo_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mullo_epi32(__mmask8 __M, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_mullo_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mullo_epi32(__m128i __W, __mmask8 __M, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_mullo_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_and_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_and_si256(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_and_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_and_epi32(_mm256_setzero_si256(), __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_and_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_and_si128(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_and_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_and_epi32(_mm_setzero_si128(), __U, __A, __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_andnot_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                          (__v8si)_mm256_andnot_si256(__A, __B),
                                          (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_andnot_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_andnot_epi32(_mm256_setzero_si256(),
                                           __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_andnot_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_andnot_si128(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_andnot_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_andnot_epi32(_mm_setzero_si128(), __U, __A, __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_or_epi32 (__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_or_si256(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_or_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_or_epi32(_mm256_setzero_si256(), __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_or_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_or_si128(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_or_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_or_epi32(_mm_setzero_si128(), __U, __A, __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_xor_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_xor_si256(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_xor_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_xor_epi32(_mm256_setzero_si256(), __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_xor_epi32(__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_xor_si128(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_xor_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_xor_epi32(_mm_setzero_si128(), __U, __A, __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_and_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_and_si256(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_and_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_and_epi64(_mm256_setzero_si256(), __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_and_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_and_si128(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_and_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_and_epi64(_mm_setzero_si128(), __U, __A, __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_andnot_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                          (__v4di)_mm256_andnot_si256(__A, __B),
                                          (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_andnot_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_andnot_epi64(_mm256_setzero_si256(),
                                           __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_andnot_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_andnot_si128(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_andnot_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_andnot_epi64(_mm_setzero_si128(), __U, __A, __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_or_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_or_si256(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_or_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_or_epi64(_mm256_setzero_si256(), __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_or_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_or_si128(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_or_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_or_epi64(_mm_setzero_si128(), __U, __A, __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_xor_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_xor_si256(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_xor_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)_mm256_mask_xor_epi64(_mm256_setzero_si256(), __U, __A, __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_xor_epi64(__m128i __W, __mmask8 __U, __m128i __A,
        __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_xor_si128(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_xor_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)_mm_mask_xor_epi64(_mm_setzero_si128(), __U, __A, __B);
}

#define _mm_cmp_epi32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)(__m128i)(a), \
                                        (__v4si)(__m128i)(b), (int)(p), \
                                        (__mmask8)-1); })

#define _mm_mask_cmp_epi32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd128_mask((__v4si)(__m128i)(a), \
                                        (__v4si)(__m128i)(b), (int)(p), \
                                        (__mmask8)(m)); })

#define _mm_cmp_epu32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)(__m128i)(a), \
                                         (__v4si)(__m128i)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm_mask_cmp_epu32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd128_mask((__v4si)(__m128i)(a), \
                                         (__v4si)(__m128i)(b), (int)(p), \
                                         (__mmask8)(m)); })

#define _mm256_cmp_epi32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)(__m256i)(a), \
                                        (__v8si)(__m256i)(b), (int)(p), \
                                        (__mmask8)-1); })

#define _mm256_mask_cmp_epi32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpd256_mask((__v8si)(__m256i)(a), \
                                        (__v8si)(__m256i)(b), (int)(p), \
                                        (__mmask8)(m)); })

#define _mm256_cmp_epu32_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)(__m256i)(a), \
                                         (__v8si)(__m256i)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm256_mask_cmp_epu32_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpd256_mask((__v8si)(__m256i)(a), \
                                         (__v8si)(__m256i)(b), (int)(p), \
                                         (__mmask8)(m)); })

#define _mm_cmp_epi64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)(__m128i)(a), \
                                        (__v2di)(__m128i)(b), (int)(p), \
                                        (__mmask8)-1); })

#define _mm_mask_cmp_epi64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq128_mask((__v2di)(__m128i)(a), \
                                        (__v2di)(__m128i)(b), (int)(p), \
                                        (__mmask8)(m)); })

#define _mm_cmp_epu64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)(__m128i)(a), \
                                         (__v2di)(__m128i)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm_mask_cmp_epu64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq128_mask((__v2di)(__m128i)(a), \
                                         (__v2di)(__m128i)(b), (int)(p), \
                                         (__mmask8)(m)); })

#define _mm256_cmp_epi64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)(__m256i)(a), \
                                        (__v4di)(__m256i)(b), (int)(p), \
                                        (__mmask8)-1); })

#define _mm256_mask_cmp_epi64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpq256_mask((__v4di)(__m256i)(a), \
                                        (__v4di)(__m256i)(b), (int)(p), \
                                        (__mmask8)(m)); })

#define _mm256_cmp_epu64_mask(a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)(__m256i)(a), \
                                         (__v4di)(__m256i)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm256_mask_cmp_epu64_mask(m, a, b, p) __extension__ ({ \
  (__mmask8)__builtin_ia32_ucmpq256_mask((__v4di)(__m256i)(a), \
                                         (__v4di)(__m256i)(b), (int)(p), \
                                         (__mmask8)(m)); })

#define _mm256_cmp_ps_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps256_mask((__v8sf)(__m256)(a), \
                                         (__v8sf)(__m256)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm256_mask_cmp_ps_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps256_mask((__v8sf)(__m256)(a), \
                                         (__v8sf)(__m256)(b), (int)(p), \
                                         (__mmask8)(m)); })

#define _mm256_cmp_pd_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd256_mask((__v4df)(__m256d)(a), \
                                         (__v4df)(__m256d)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm256_mask_cmp_pd_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd256_mask((__v4df)(__m256d)(a), \
                                         (__v4df)(__m256d)(b), (int)(p), \
                                         (__mmask8)(m)); })

#define _mm_cmp_ps_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps128_mask((__v4sf)(__m128)(a), \
                                         (__v4sf)(__m128)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm_mask_cmp_ps_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmpps128_mask((__v4sf)(__m128)(a), \
                                         (__v4sf)(__m128)(b), (int)(p), \
                                         (__mmask8)(m)); })

#define _mm_cmp_pd_mask(a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd128_mask((__v2df)(__m128d)(a), \
                                         (__v2df)(__m128d)(b), (int)(p), \
                                         (__mmask8)-1); })

#define _mm_mask_cmp_pd_mask(m, a, b, p)  __extension__ ({ \
  (__mmask8)__builtin_ia32_cmppd128_mask((__v2df)(__m128d)(a), \
                                         (__v2df)(__m128d)(b), (int)(p), \
                                         (__mmask8)(m)); })

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

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_add_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_add_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_add_pd(__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_add_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_add_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_add_pd(__A, __B),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_add_pd(__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_add_pd(__A, __B),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_add_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_add_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_add_ps(__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_add_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_add_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_add_ps(__A, __B),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_add_ps(__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_add_ps(__A, __B),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_blend_epi32 (__mmask8 __U, __m128i __A, __m128i __W) {
  return (__m128i) __builtin_ia32_selectd_128 ((__mmask8) __U,
                (__v4si) __W,
                (__v4si) __A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_blend_epi32 (__mmask8 __U, __m256i __A, __m256i __W) {
  return (__m256i) __builtin_ia32_selectd_256 ((__mmask8) __U,
                (__v8si) __W,
                (__v8si) __A);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_blend_pd (__mmask8 __U, __m128d __A, __m128d __W) {
  return (__m128d) __builtin_ia32_selectpd_128 ((__mmask8) __U,
                 (__v2df) __W,
                 (__v2df) __A);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_blend_pd (__mmask8 __U, __m256d __A, __m256d __W) {
  return (__m256d) __builtin_ia32_selectpd_256 ((__mmask8) __U,
                 (__v4df) __W,
                 (__v4df) __A);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_blend_ps (__mmask8 __U, __m128 __A, __m128 __W) {
  return (__m128) __builtin_ia32_selectps_128 ((__mmask8) __U,
                (__v4sf) __W,
                (__v4sf) __A);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_blend_ps (__mmask8 __U, __m256 __A, __m256 __W) {
  return (__m256) __builtin_ia32_selectps_256 ((__mmask8) __U,
                (__v8sf) __W,
                (__v8sf) __A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_blend_epi64 (__mmask8 __U, __m128i __A, __m128i __W) {
  return (__m128i) __builtin_ia32_selectq_128 ((__mmask8) __U,
                (__v2di) __W,
                (__v2di) __A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_blend_epi64 (__mmask8 __U, __m256i __A, __m256i __W) {
  return (__m256i) __builtin_ia32_selectq_256 ((__mmask8) __U,
                (__v4di) __W,
                (__v4di) __A);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_compress_pd (__m128d __W, __mmask8 __U, __m128d __A) {
  return (__m128d) __builtin_ia32_compressdf128_mask ((__v2df) __A,
                  (__v2df) __W,
                  (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_compress_pd (__mmask8 __U, __m128d __A) {
  return (__m128d) __builtin_ia32_compressdf128_mask ((__v2df) __A,
                  (__v2df)
                  _mm_setzero_pd (),
                  (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_compress_pd (__m256d __W, __mmask8 __U, __m256d __A) {
  return (__m256d) __builtin_ia32_compressdf256_mask ((__v4df) __A,
                  (__v4df) __W,
                  (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_compress_pd (__mmask8 __U, __m256d __A) {
  return (__m256d) __builtin_ia32_compressdf256_mask ((__v4df) __A,
                  (__v4df)
                  _mm256_setzero_pd (),
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_compress_epi64 (__m128i __W, __mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_compressdi128_mask ((__v2di) __A,
                  (__v2di) __W,
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_compress_epi64 (__mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_compressdi128_mask ((__v2di) __A,
                  (__v2di)
                  _mm_setzero_si128 (),
                  (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_compress_epi64 (__m256i __W, __mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_compressdi256_mask ((__v4di) __A,
                  (__v4di) __W,
                  (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_compress_epi64 (__mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_compressdi256_mask ((__v4di) __A,
                  (__v4di)
                  _mm256_setzero_si256 (),
                  (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_compress_ps (__m128 __W, __mmask8 __U, __m128 __A) {
  return (__m128) __builtin_ia32_compresssf128_mask ((__v4sf) __A,
                 (__v4sf) __W,
                 (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_compress_ps (__mmask8 __U, __m128 __A) {
  return (__m128) __builtin_ia32_compresssf128_mask ((__v4sf) __A,
                 (__v4sf)
                 _mm_setzero_ps (),
                 (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_compress_ps (__m256 __W, __mmask8 __U, __m256 __A) {
  return (__m256) __builtin_ia32_compresssf256_mask ((__v8sf) __A,
                 (__v8sf) __W,
                 (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_compress_ps (__mmask8 __U, __m256 __A) {
  return (__m256) __builtin_ia32_compresssf256_mask ((__v8sf) __A,
                 (__v8sf)
                 _mm256_setzero_ps (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_compress_epi32 (__m128i __W, __mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_compresssi128_mask ((__v4si) __A,
                  (__v4si) __W,
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_compress_epi32 (__mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_compresssi128_mask ((__v4si) __A,
                  (__v4si)
                  _mm_setzero_si128 (),
                  (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_compress_epi32 (__m256i __W, __mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_compresssi256_mask ((__v8si) __A,
                  (__v8si) __W,
                  (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_compress_epi32 (__mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_compresssi256_mask ((__v8si) __A,
                  (__v8si)
                  _mm256_setzero_si256 (),
                  (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_compressstoreu_pd (void *__P, __mmask8 __U, __m128d __A) {
  __builtin_ia32_compressstoredf128_mask ((__v2df *) __P,
            (__v2df) __A,
            (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_compressstoreu_pd (void *__P, __mmask8 __U, __m256d __A) {
  __builtin_ia32_compressstoredf256_mask ((__v4df *) __P,
            (__v4df) __A,
            (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_compressstoreu_epi64 (void *__P, __mmask8 __U, __m128i __A) {
  __builtin_ia32_compressstoredi128_mask ((__v2di *) __P,
            (__v2di) __A,
            (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_compressstoreu_epi64 (void *__P, __mmask8 __U, __m256i __A) {
  __builtin_ia32_compressstoredi256_mask ((__v4di *) __P,
            (__v4di) __A,
            (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_compressstoreu_ps (void *__P, __mmask8 __U, __m128 __A) {
  __builtin_ia32_compressstoresf128_mask ((__v4sf *) __P,
            (__v4sf) __A,
            (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_compressstoreu_ps (void *__P, __mmask8 __U, __m256 __A) {
  __builtin_ia32_compressstoresf256_mask ((__v8sf *) __P,
            (__v8sf) __A,
            (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_compressstoreu_epi32 (void *__P, __mmask8 __U, __m128i __A) {
  __builtin_ia32_compressstoresi128_mask ((__v4si *) __P,
            (__v4si) __A,
            (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_compressstoreu_epi32 (void *__P, __mmask8 __U, __m256i __A) {
  __builtin_ia32_compressstoresi256_mask ((__v8si *) __P,
            (__v8si) __A,
            (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_cvtepi32_pd (__m128d __W, __mmask8 __U, __m128i __A) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8) __U,
                                              (__v2df)_mm_cvtepi32_pd(__A),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi32_pd (__mmask8 __U, __m128i __A) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8) __U,
                                              (__v2df)_mm_cvtepi32_pd(__A),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi32_pd (__m256d __W, __mmask8 __U, __m128i __A) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8) __U,
                                              (__v4df)_mm256_cvtepi32_pd(__A),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi32_pd (__mmask8 __U, __m128i __A) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8) __U,
                                              (__v4df)_mm256_cvtepi32_pd(__A),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_cvtepi32_ps (__m128 __W, __mmask8 __U, __m128i __A) {
  return (__m128) __builtin_ia32_cvtdq2ps128_mask ((__v4si) __A,
               (__v4sf) __W,
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi32_ps (__mmask16 __U, __m128i __A) {
  return (__m128) __builtin_ia32_cvtdq2ps128_mask ((__v4si) __A,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi32_ps (__m256 __W, __mmask8 __U, __m256i __A) {
  return (__m256) __builtin_ia32_cvtdq2ps256_mask ((__v8si) __A,
               (__v8sf) __W,
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi32_ps (__mmask16 __U, __m256i __A) {
  return (__m256) __builtin_ia32_cvtdq2ps256_mask ((__v8si) __A,
               (__v8sf)
               _mm256_setzero_ps (),
               (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtpd_epi32 (__m128i __W, __mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvtpd2dq128_mask ((__v2df) __A,
                (__v4si) __W,
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtpd_epi32 (__mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvtpd2dq128_mask ((__v2df) __A,
                (__v4si)
                _mm_setzero_si128 (),
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtpd_epi32 (__m128i __W, __mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvtpd2dq256_mask ((__v4df) __A,
                (__v4si) __W,
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtpd_epi32 (__mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvtpd2dq256_mask ((__v4df) __A,
                (__v4si)
                _mm_setzero_si128 (),
                (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_cvtpd_ps (__m128 __W, __mmask8 __U, __m128d __A) {
  return (__m128) __builtin_ia32_cvtpd2ps_mask ((__v2df) __A,
            (__v4sf) __W,
            (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_cvtpd_ps (__mmask8 __U, __m128d __A) {
  return (__m128) __builtin_ia32_cvtpd2ps_mask ((__v2df) __A,
            (__v4sf)
            _mm_setzero_ps (),
            (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm256_mask_cvtpd_ps (__m128 __W, __mmask8 __U, __m256d __A) {
  return (__m128) __builtin_ia32_cvtpd2ps256_mask ((__v4df) __A,
               (__v4sf) __W,
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm256_maskz_cvtpd_ps (__mmask8 __U, __m256d __A) {
  return (__m128) __builtin_ia32_cvtpd2ps256_mask ((__v4df) __A,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtpd_epu32 (__m128d __A) {
  return (__m128i) __builtin_ia32_cvtpd2udq128_mask ((__v2df) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtpd_epu32 (__m128i __W, __mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvtpd2udq128_mask ((__v2df) __A,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtpd_epu32 (__mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvtpd2udq128_mask ((__v2df) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtpd_epu32 (__m256d __A) {
  return (__m128i) __builtin_ia32_cvtpd2udq256_mask ((__v4df) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtpd_epu32 (__m128i __W, __mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvtpd2udq256_mask ((__v4df) __A,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtpd_epu32 (__mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvtpd2udq256_mask ((__v4df) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtps_epi32 (__m128i __W, __mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvtps2dq128_mask ((__v4sf) __A,
                (__v4si) __W,
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtps_epi32 (__mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvtps2dq128_mask ((__v4sf) __A,
                (__v4si)
                _mm_setzero_si128 (),
                (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtps_epi32 (__m256i __W, __mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvtps2dq256_mask ((__v8sf) __A,
                (__v8si) __W,
                (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtps_epi32 (__mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvtps2dq256_mask ((__v8sf) __A,
                (__v8si)
                _mm256_setzero_si256 (),
                (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_cvtps_pd (__m128d __W, __mmask8 __U, __m128 __A) {
  return (__m128d) __builtin_ia32_cvtps2pd128_mask ((__v4sf) __A,
                (__v2df) __W,
                (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_cvtps_pd (__mmask8 __U, __m128 __A) {
  return (__m128d) __builtin_ia32_cvtps2pd128_mask ((__v4sf) __A,
                (__v2df)
                _mm_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_cvtps_pd (__m256d __W, __mmask8 __U, __m128 __A) {
  return (__m256d) __builtin_ia32_cvtps2pd256_mask ((__v4sf) __A,
                (__v4df) __W,
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_cvtps_pd (__mmask8 __U, __m128 __A) {
  return (__m256d) __builtin_ia32_cvtps2pd256_mask ((__v4sf) __A,
                (__v4df)
                _mm256_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtps_epu32 (__m128 __A) {
  return (__m128i) __builtin_ia32_cvtps2udq128_mask ((__v4sf) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtps_epu32 (__m128i __W, __mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvtps2udq128_mask ((__v4sf) __A,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtps_epu32 (__mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvtps2udq128_mask ((__v4sf) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtps_epu32 (__m256 __A) {
  return (__m256i) __builtin_ia32_cvtps2udq256_mask ((__v8sf) __A,
                 (__v8si)
                 _mm256_setzero_si256 (),
                 (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtps_epu32 (__m256i __W, __mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvtps2udq256_mask ((__v8sf) __A,
                 (__v8si) __W,
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtps_epu32 (__mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvtps2udq256_mask ((__v8sf) __A,
                 (__v8si)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvttpd_epi32 (__m128i __W, __mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvttpd2dq128_mask ((__v2df) __A,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvttpd_epi32 (__mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvttpd2dq128_mask ((__v2df) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvttpd_epi32 (__m128i __W, __mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvttpd2dq256_mask ((__v4df) __A,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvttpd_epi32 (__mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvttpd2dq256_mask ((__v4df) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvttpd_epu32 (__m128d __A) {
  return (__m128i) __builtin_ia32_cvttpd2udq128_mask ((__v2df) __A,
                  (__v4si)
                  _mm_setzero_si128 (),
                  (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvttpd_epu32 (__m128i __W, __mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvttpd2udq128_mask ((__v2df) __A,
                  (__v4si) __W,
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvttpd_epu32 (__mmask8 __U, __m128d __A) {
  return (__m128i) __builtin_ia32_cvttpd2udq128_mask ((__v2df) __A,
                  (__v4si)
                  _mm_setzero_si128 (),
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvttpd_epu32 (__m256d __A) {
  return (__m128i) __builtin_ia32_cvttpd2udq256_mask ((__v4df) __A,
                  (__v4si)
                  _mm_setzero_si128 (),
                  (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvttpd_epu32 (__m128i __W, __mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvttpd2udq256_mask ((__v4df) __A,
                  (__v4si) __W,
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvttpd_epu32 (__mmask8 __U, __m256d __A) {
  return (__m128i) __builtin_ia32_cvttpd2udq256_mask ((__v4df) __A,
                  (__v4si)
                  _mm_setzero_si128 (),
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvttps_epi32 (__m128i __W, __mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvttps2dq128_mask ((__v4sf) __A,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvttps_epi32 (__mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvttps2dq128_mask ((__v4sf) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvttps_epi32 (__m256i __W, __mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvttps2dq256_mask ((__v8sf) __A,
                 (__v8si) __W,
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvttps_epi32 (__mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvttps2dq256_mask ((__v8sf) __A,
                 (__v8si)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvttps_epu32 (__m128 __A) {
  return (__m128i) __builtin_ia32_cvttps2udq128_mask ((__v4sf) __A,
                  (__v4si)
                  _mm_setzero_si128 (),
                  (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvttps_epu32 (__m128i __W, __mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvttps2udq128_mask ((__v4sf) __A,
                  (__v4si) __W,
                  (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvttps_epu32 (__mmask8 __U, __m128 __A) {
  return (__m128i) __builtin_ia32_cvttps2udq128_mask ((__v4sf) __A,
                  (__v4si)
                  _mm_setzero_si128 (),
                  (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvttps_epu32 (__m256 __A) {
  return (__m256i) __builtin_ia32_cvttps2udq256_mask ((__v8sf) __A,
                  (__v8si)
                  _mm256_setzero_si256 (),
                  (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvttps_epu32 (__m256i __W, __mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvttps2udq256_mask ((__v8sf) __A,
                  (__v8si) __W,
                  (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvttps_epu32 (__mmask8 __U, __m256 __A) {
  return (__m256i) __builtin_ia32_cvttps2udq256_mask ((__v8sf) __A,
                  (__v8si)
                  _mm256_setzero_si256 (),
                  (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_cvtepu32_pd (__m128i __A) {
  return (__m128d) __builtin_convertvector(
      __builtin_shufflevector((__v4su)__A, (__v4su)__A, 0, 1), __v2df);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_cvtepu32_pd (__m128d __W, __mmask8 __U, __m128i __A) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8) __U,
                                              (__v2df)_mm_cvtepu32_pd(__A),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_cvtepu32_pd (__mmask8 __U, __m128i __A) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8) __U,
                                              (__v2df)_mm_cvtepu32_pd(__A),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_cvtepu32_pd (__m128i __A) {
  return (__m256d)__builtin_convertvector((__v4su)__A, __v4df);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_cvtepu32_pd (__m256d __W, __mmask8 __U, __m128i __A) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8) __U,
                                              (__v4df)_mm256_cvtepu32_pd(__A),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepu32_pd (__mmask8 __U, __m128i __A) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8) __U,
                                              (__v4df)_mm256_cvtepu32_pd(__A),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_cvtepu32_ps (__m128i __A) {
  return (__m128) __builtin_ia32_cvtudq2ps128_mask ((__v4si) __A,
                (__v4sf)
                _mm_setzero_ps (),
                (__mmask8) -1);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_cvtepu32_ps (__m128 __W, __mmask8 __U, __m128i __A) {
  return (__m128) __builtin_ia32_cvtudq2ps128_mask ((__v4si) __A,
                (__v4sf) __W,
                (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_cvtepu32_ps (__mmask8 __U, __m128i __A) {
  return (__m128) __builtin_ia32_cvtudq2ps128_mask ((__v4si) __A,
                (__v4sf)
                _mm_setzero_ps (),
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_cvtepu32_ps (__m256i __A) {
  return (__m256) __builtin_ia32_cvtudq2ps256_mask ((__v8si) __A,
                (__v8sf)
                _mm256_setzero_ps (),
                (__mmask8) -1);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_cvtepu32_ps (__m256 __W, __mmask8 __U, __m256i __A) {
  return (__m256) __builtin_ia32_cvtudq2ps256_mask ((__v8si) __A,
                (__v8sf) __W,
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepu32_ps (__mmask8 __U, __m256i __A) {
  return (__m256) __builtin_ia32_cvtudq2ps256_mask ((__v8si) __A,
                (__v8sf)
                _mm256_setzero_ps (),
                (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_div_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_div_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_div_pd(__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_div_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_div_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_div_pd(__A, __B),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_div_pd(__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_div_pd(__A, __B),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_div_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_div_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_div_ps(__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_div_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_div_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_div_ps(__A, __B),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_div_ps(__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_div_ps(__A, __B),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_expand_pd (__m128d __W, __mmask8 __U, __m128d __A) {
  return (__m128d) __builtin_ia32_expanddf128_mask ((__v2df) __A,
                (__v2df) __W,
                (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_expand_pd (__mmask8 __U, __m128d __A) {
  return (__m128d) __builtin_ia32_expanddf128_mask ((__v2df) __A,
                 (__v2df)
                 _mm_setzero_pd (),
                 (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_expand_pd (__m256d __W, __mmask8 __U, __m256d __A) {
  return (__m256d) __builtin_ia32_expanddf256_mask ((__v4df) __A,
                (__v4df) __W,
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_expand_pd (__mmask8 __U, __m256d __A) {
  return (__m256d) __builtin_ia32_expanddf256_mask ((__v4df) __A,
                 (__v4df)
                 _mm256_setzero_pd (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_expand_epi64 (__m128i __W, __mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_expanddi128_mask ((__v2di) __A,
                (__v2di) __W,
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_expand_epi64 (__mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_expanddi128_mask ((__v2di) __A,
                 (__v2di)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expand_epi64 (__m256i __W, __mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_expanddi256_mask ((__v4di) __A,
                (__v4di) __W,
                (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expand_epi64 (__mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_expanddi256_mask ((__v4di) __A,
                 (__v4di)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_expandloadu_pd (__m128d __W, __mmask8 __U, void const *__P) {
  return (__m128d) __builtin_ia32_expandloaddf128_mask ((__v2df *) __P,
              (__v2df) __W,
              (__mmask8)
              __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_expandloadu_pd (__mmask8 __U, void const *__P) {
  return (__m128d) __builtin_ia32_expandloaddf128_mask ((__v2df *) __P,
               (__v2df)
               _mm_setzero_pd (),
               (__mmask8)
               __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_expandloadu_pd (__m256d __W, __mmask8 __U, void const *__P) {
  return (__m256d) __builtin_ia32_expandloaddf256_mask ((__v4df *) __P,
              (__v4df) __W,
              (__mmask8)
              __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_expandloadu_pd (__mmask8 __U, void const *__P) {
  return (__m256d) __builtin_ia32_expandloaddf256_mask ((__v4df *) __P,
               (__v4df)
               _mm256_setzero_pd (),
               (__mmask8)
               __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_expandloadu_epi64 (__m128i __W, __mmask8 __U, void const *__P) {
  return (__m128i) __builtin_ia32_expandloaddi128_mask ((__v2di *) __P,
              (__v2di) __W,
              (__mmask8)
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_expandloadu_epi64 (__mmask8 __U, void const *__P) {
  return (__m128i) __builtin_ia32_expandloaddi128_mask ((__v2di *) __P,
               (__v2di)
               _mm_setzero_si128 (),
               (__mmask8)
               __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expandloadu_epi64 (__m256i __W, __mmask8 __U,
             void const *__P) {
  return (__m256i) __builtin_ia32_expandloaddi256_mask ((__v4di *) __P,
              (__v4di) __W,
              (__mmask8)
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expandloadu_epi64 (__mmask8 __U, void const *__P) {
  return (__m256i) __builtin_ia32_expandloaddi256_mask ((__v4di *) __P,
               (__v4di)
               _mm256_setzero_si256 (),
               (__mmask8)
               __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_expandloadu_ps (__m128 __W, __mmask8 __U, void const *__P) {
  return (__m128) __builtin_ia32_expandloadsf128_mask ((__v4sf *) __P,
                   (__v4sf) __W,
                   (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_expandloadu_ps (__mmask8 __U, void const *__P) {
  return (__m128) __builtin_ia32_expandloadsf128_mask ((__v4sf *) __P,
              (__v4sf)
              _mm_setzero_ps (),
              (__mmask8)
              __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_expandloadu_ps (__m256 __W, __mmask8 __U, void const *__P) {
  return (__m256) __builtin_ia32_expandloadsf256_mask ((__v8sf *) __P,
                   (__v8sf) __W,
                   (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_expandloadu_ps (__mmask8 __U, void const *__P) {
  return (__m256) __builtin_ia32_expandloadsf256_mask ((__v8sf *) __P,
              (__v8sf)
              _mm256_setzero_ps (),
              (__mmask8)
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_expandloadu_epi32 (__m128i __W, __mmask8 __U, void const *__P) {
  return (__m128i) __builtin_ia32_expandloadsi128_mask ((__v4si *) __P,
              (__v4si) __W,
              (__mmask8)
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_expandloadu_epi32 (__mmask8 __U, void const *__P) {
  return (__m128i) __builtin_ia32_expandloadsi128_mask ((__v4si *) __P,
               (__v4si)
               _mm_setzero_si128 (),
               (__mmask8)     __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expandloadu_epi32 (__m256i __W, __mmask8 __U,
             void const *__P) {
  return (__m256i) __builtin_ia32_expandloadsi256_mask ((__v8si *) __P,
              (__v8si) __W,
              (__mmask8)
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expandloadu_epi32 (__mmask8 __U, void const *__P) {
  return (__m256i) __builtin_ia32_expandloadsi256_mask ((__v8si *) __P,
               (__v8si)
               _mm256_setzero_si256 (),
               (__mmask8)
               __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_expand_ps (__m128 __W, __mmask8 __U, __m128 __A) {
  return (__m128) __builtin_ia32_expandsf128_mask ((__v4sf) __A,
               (__v4sf) __W,
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_expand_ps (__mmask8 __U, __m128 __A) {
  return (__m128) __builtin_ia32_expandsf128_mask ((__v4sf) __A,
                (__v4sf)
                _mm_setzero_ps (),
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_expand_ps (__m256 __W, __mmask8 __U, __m256 __A) {
  return (__m256) __builtin_ia32_expandsf256_mask ((__v8sf) __A,
               (__v8sf) __W,
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_expand_ps (__mmask8 __U, __m256 __A) {
  return (__m256) __builtin_ia32_expandsf256_mask ((__v8sf) __A,
                (__v8sf)
                _mm256_setzero_ps (),
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_expand_epi32 (__m128i __W, __mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_expandsi128_mask ((__v4si) __A,
                (__v4si) __W,
                (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_expand_epi32 (__mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_expandsi128_mask ((__v4si) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_expand_epi32 (__m256i __W, __mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_expandsi256_mask ((__v8si) __A,
                (__v8si) __W,
                (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_expand_epi32 (__mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_expandsi256_mask ((__v8si) __A,
                 (__v8si)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_getexp_pd (__m128d __A) {
  return (__m128d) __builtin_ia32_getexppd128_mask ((__v2df) __A,
                (__v2df)
                _mm_setzero_pd (),
                (__mmask8) -1);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_getexp_pd (__m128d __W, __mmask8 __U, __m128d __A) {
  return (__m128d) __builtin_ia32_getexppd128_mask ((__v2df) __A,
                (__v2df) __W,
                (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_getexp_pd (__mmask8 __U, __m128d __A) {
  return (__m128d) __builtin_ia32_getexppd128_mask ((__v2df) __A,
                (__v2df)
                _mm_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_getexp_pd (__m256d __A) {
  return (__m256d) __builtin_ia32_getexppd256_mask ((__v4df) __A,
                (__v4df)
                _mm256_setzero_pd (),
                (__mmask8) -1);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_getexp_pd (__m256d __W, __mmask8 __U, __m256d __A) {
  return (__m256d) __builtin_ia32_getexppd256_mask ((__v4df) __A,
                (__v4df) __W,
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_getexp_pd (__mmask8 __U, __m256d __A) {
  return (__m256d) __builtin_ia32_getexppd256_mask ((__v4df) __A,
                (__v4df)
                _mm256_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_getexp_ps (__m128 __A) {
  return (__m128) __builtin_ia32_getexpps128_mask ((__v4sf) __A,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) -1);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_getexp_ps (__m128 __W, __mmask8 __U, __m128 __A) {
  return (__m128) __builtin_ia32_getexpps128_mask ((__v4sf) __A,
               (__v4sf) __W,
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_getexp_ps (__mmask8 __U, __m128 __A) {
  return (__m128) __builtin_ia32_getexpps128_mask ((__v4sf) __A,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_getexp_ps (__m256 __A) {
  return (__m256) __builtin_ia32_getexpps256_mask ((__v8sf) __A,
               (__v8sf)
               _mm256_setzero_ps (),
               (__mmask8) -1);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_getexp_ps (__m256 __W, __mmask8 __U, __m256 __A) {
  return (__m256) __builtin_ia32_getexpps256_mask ((__v8sf) __A,
               (__v8sf) __W,
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_getexp_ps (__mmask8 __U, __m256 __A) {
  return (__m256) __builtin_ia32_getexpps256_mask ((__v8sf) __A,
               (__v8sf)
               _mm256_setzero_ps (),
               (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_max_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_max_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_max_pd(__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_max_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_max_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_max_pd(__A, __B),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_max_pd(__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_max_pd(__A, __B),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_max_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_max_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_max_ps(__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_max_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_max_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_max_ps(__A, __B),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_max_ps(__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_max_ps(__A, __B),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_min_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_min_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_min_pd(__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_min_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_min_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_min_pd(__A, __B),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_min_pd(__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_min_pd(__A, __B),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_min_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_min_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_min_ps(__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_min_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_min_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_min_ps(__A, __B),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_min_ps(__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_min_ps(__A, __B),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_mul_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_mul_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_mul_pd(__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_mul_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_mul_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_mul_pd(__A, __B),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_mul_pd(__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_mul_pd(__A, __B),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_mul_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_mul_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_mul_ps(__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_mul_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_mul_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_mul_ps(__A, __B),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_mul_ps(__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_mul_ps(__A, __B),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_abs_epi32(__m128i __W, __mmask8 __U, __m128i __A) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_abs_epi32(__A),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_abs_epi32(__mmask8 __U, __m128i __A) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_abs_epi32(__A),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_abs_epi32(__m256i __W, __mmask8 __U, __m256i __A) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask16)__U,
                                             (__v8si)_mm256_abs_epi32(__A),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_abs_epi32(__mmask8 __U, __m256i __A) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask16)__U,
                                             (__v8si)_mm256_abs_epi32(__A),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_abs_epi64 (__m128i __A) {
  return (__m128i) __builtin_ia32_pabsq128_mask ((__v2di) __A,
             (__v2di)
             _mm_setzero_si128 (),
             (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_abs_epi64 (__m128i __W, __mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_pabsq128_mask ((__v2di) __A,
             (__v2di) __W,
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_abs_epi64 (__mmask8 __U, __m128i __A) {
  return (__m128i) __builtin_ia32_pabsq128_mask ((__v2di) __A,
             (__v2di)
             _mm_setzero_si128 (),
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_abs_epi64 (__m256i __A) {
  return (__m256i) __builtin_ia32_pabsq256_mask ((__v4di) __A,
             (__v4di)
             _mm256_setzero_si256 (),
             (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_abs_epi64 (__m256i __W, __mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_pabsq256_mask ((__v4di) __A,
             (__v4di) __W,
             (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_abs_epi64 (__mmask8 __U, __m256i __A) {
  return (__m256i) __builtin_ia32_pabsq256_mask ((__v4di) __A,
             (__v4di)
             _mm256_setzero_si256 (),
             (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_max_epi32(__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_max_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_max_epi32(__m128i __W, __mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_max_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_max_epi32(__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_max_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_max_epi32(__m256i __W, __mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_max_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_max_epi64 (__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pmaxsq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_max_epi64 (__m128i __W, __mmask8 __M, __m128i __A,
        __m128i __B) {
  return (__m128i) __builtin_ia32_pmaxsq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_max_epi64 (__m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pmaxsq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_max_epi64 (__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pmaxsq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_max_epi64 (__m256i __W, __mmask8 __M, __m256i __A,
           __m256i __B) {
  return (__m256i) __builtin_ia32_pmaxsq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W, __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epi64 (__m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pmaxsq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_max_epu32(__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_max_epu32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_max_epu32(__m128i __W, __mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_max_epu32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_max_epu32(__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_max_epu32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_max_epu32(__m256i __W, __mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_max_epu32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_max_epu64 (__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pmaxuq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_max_epu64 (__m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pmaxuq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_max_epu64 (__m128i __W, __mmask8 __M, __m128i __A,
        __m128i __B) {
  return (__m128i) __builtin_ia32_pmaxuq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W, __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_max_epu64 (__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pmaxuq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epu64 (__m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pmaxuq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_max_epu64 (__m256i __W, __mmask8 __M, __m256i __A,
           __m256i __B) {
  return (__m256i) __builtin_ia32_pmaxuq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_min_epi32(__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_min_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_min_epi32(__m128i __W, __mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_min_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_min_epi32(__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_min_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_min_epi32(__m256i __W, __mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_min_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_min_epi64 (__m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pminsq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_min_epi64 (__m128i __W, __mmask8 __M, __m128i __A,
        __m128i __B) {
  return (__m128i) __builtin_ia32_pminsq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_min_epi64 (__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pminsq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epi64 (__m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pminsq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_min_epi64 (__m256i __W, __mmask8 __M, __m256i __A,
           __m256i __B) {
  return (__m256i) __builtin_ia32_pminsq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W, __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_min_epi64 (__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pminsq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_min_epu32(__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_min_epu32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_min_epu32(__m128i __W, __mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__M,
                                             (__v4si)_mm_min_epu32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_min_epu32(__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_min_epu32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_min_epu32(__m256i __W, __mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                             (__v8si)_mm256_min_epu32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_min_epu64 (__m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pminuq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_min_epu64 (__m128i __W, __mmask8 __M, __m128i __A,
        __m128i __B) {
  return (__m128i) __builtin_ia32_pminuq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_min_epu64 (__mmask8 __M, __m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pminuq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epu64 (__m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pminuq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_min_epu64 (__m256i __W, __mmask8 __M, __m256i __A,
           __m256i __B) {
  return (__m256i) __builtin_ia32_pminuq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W, __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_min_epu64 (__mmask8 __M, __m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pminuq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              __M);
}

#define _mm_roundscale_pd(A, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_rndscalepd_128_mask((__v2df)(__m128d)(A), \
                                              (int)(imm), \
                                              (__v2df)_mm_setzero_pd(), \
                                              (__mmask8)-1); })


#define _mm_mask_roundscale_pd(W, U, A, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_rndscalepd_128_mask((__v2df)(__m128d)(A), \
                                              (int)(imm), \
                                              (__v2df)(__m128d)(W), \
                                              (__mmask8)(U)); })


#define _mm_maskz_roundscale_pd(U, A, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_rndscalepd_128_mask((__v2df)(__m128d)(A), \
                                              (int)(imm), \
                                              (__v2df)_mm_setzero_pd(), \
                                              (__mmask8)(U)); })


#define _mm256_roundscale_pd(A, imm) __extension__ ({ \
  (__m256d)__builtin_ia32_rndscalepd_256_mask((__v4df)(__m256d)(A), \
                                              (int)(imm), \
                                              (__v4df)_mm256_setzero_pd(), \
                                              (__mmask8)-1); })


#define _mm256_mask_roundscale_pd(W, U, A, imm) __extension__ ({ \
  (__m256d)__builtin_ia32_rndscalepd_256_mask((__v4df)(__m256d)(A), \
                                              (int)(imm), \
                                              (__v4df)(__m256d)(W), \
                                              (__mmask8)(U)); })


#define _mm256_maskz_roundscale_pd(U, A, imm)  __extension__ ({ \
  (__m256d)__builtin_ia32_rndscalepd_256_mask((__v4df)(__m256d)(A), \
                                              (int)(imm), \
                                              (__v4df)_mm256_setzero_pd(), \
                                              (__mmask8)(U)); })

#define _mm_roundscale_ps(A, imm)  __extension__ ({ \
  (__m128)__builtin_ia32_rndscaleps_128_mask((__v4sf)(__m128)(A), (int)(imm), \
                                             (__v4sf)_mm_setzero_ps(), \
                                             (__mmask8)-1); })


#define _mm_mask_roundscale_ps(W, U, A, imm)  __extension__ ({ \
  (__m128)__builtin_ia32_rndscaleps_128_mask((__v4sf)(__m128)(A), (int)(imm), \
                                             (__v4sf)(__m128)(W), \
                                             (__mmask8)(U)); })


#define _mm_maskz_roundscale_ps(U, A, imm)  __extension__ ({ \
  (__m128)__builtin_ia32_rndscaleps_128_mask((__v4sf)(__m128)(A), (int)(imm), \
                                             (__v4sf)_mm_setzero_ps(), \
                                             (__mmask8)(U)); })

#define _mm256_roundscale_ps(A, imm)  __extension__ ({ \
  (__m256)__builtin_ia32_rndscaleps_256_mask((__v8sf)(__m256)(A), (int)(imm), \
                                             (__v8sf)_mm256_setzero_ps(), \
                                             (__mmask8)-1); })

#define _mm256_mask_roundscale_ps(W, U, A, imm)  __extension__ ({ \
  (__m256)__builtin_ia32_rndscaleps_256_mask((__v8sf)(__m256)(A), (int)(imm), \
                                             (__v8sf)(__m256)(W), \
                                             (__mmask8)(U)); })


#define _mm256_maskz_roundscale_ps(U, A, imm)  __extension__ ({ \
  (__m256)__builtin_ia32_rndscaleps_256_mask((__v8sf)(__m256)(A), (int)(imm), \
                                             (__v8sf)_mm256_setzero_ps(), \
                                             (__mmask8)(U)); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_scalef_pd (__m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_scalefpd128_mask ((__v2df) __A,
                (__v2df) __B,
                (__v2df)
                _mm_setzero_pd (),
                (__mmask8) -1);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_scalef_pd (__m128d __W, __mmask8 __U, __m128d __A,
        __m128d __B) {
  return (__m128d) __builtin_ia32_scalefpd128_mask ((__v2df) __A,
                (__v2df) __B,
                (__v2df) __W,
                (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_scalef_pd (__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_scalefpd128_mask ((__v2df) __A,
                (__v2df) __B,
                (__v2df)
                _mm_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_scalef_pd (__m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_scalefpd256_mask ((__v4df) __A,
                (__v4df) __B,
                (__v4df)
                _mm256_setzero_pd (),
                (__mmask8) -1);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_scalef_pd (__m256d __W, __mmask8 __U, __m256d __A,
           __m256d __B) {
  return (__m256d) __builtin_ia32_scalefpd256_mask ((__v4df) __A,
                (__v4df) __B,
                (__v4df) __W,
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_scalef_pd (__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_scalefpd256_mask ((__v4df) __A,
                (__v4df) __B,
                (__v4df)
                _mm256_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_scalef_ps (__m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_scalefps128_mask ((__v4sf) __A,
               (__v4sf) __B,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) -1);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_scalef_ps (__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_scalefps128_mask ((__v4sf) __A,
               (__v4sf) __B,
               (__v4sf) __W,
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_scalef_ps (__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_scalefps128_mask ((__v4sf) __A,
               (__v4sf) __B,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_scalef_ps (__m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_scalefps256_mask ((__v8sf) __A,
               (__v8sf) __B,
               (__v8sf)
               _mm256_setzero_ps (),
               (__mmask8) -1);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_scalef_ps (__m256 __W, __mmask8 __U, __m256 __A,
           __m256 __B) {
  return (__m256) __builtin_ia32_scalefps256_mask ((__v8sf) __A,
               (__v8sf) __B,
               (__v8sf) __W,
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_scalef_ps (__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_scalefps256_mask ((__v8sf) __A,
               (__v8sf) __B,
               (__v8sf)
               _mm256_setzero_ps (),
               (__mmask8) __U);
}

#define _mm_i64scatter_pd(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv2df((double *)(addr), (__mmask8)-1, \
                               (__v2di)(__m128i)(index), \
                               (__v2df)(__m128d)(v1), (int)(scale)); })

#define _mm_mask_i64scatter_pd(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv2df((double *)(addr), (__mmask8)(mask), \
                               (__v2di)(__m128i)(index), \
                               (__v2df)(__m128d)(v1), (int)(scale)); })

#define _mm_i64scatter_epi64(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv2di((long long *)(addr), (__mmask8)-1, \
                               (__v2di)(__m128i)(index), \
                               (__v2di)(__m128i)(v1), (int)(scale)); })

#define _mm_mask_i64scatter_epi64(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv2di((long long *)(addr), (__mmask8)(mask), \
                               (__v2di)(__m128i)(index), \
                               (__v2di)(__m128i)(v1), (int)(scale)); })

#define _mm256_i64scatter_pd(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4df((double *)(addr), (__mmask8)-1, \
                               (__v4di)(__m256i)(index), \
                               (__v4df)(__m256d)(v1), (int)(scale)); })

#define _mm256_mask_i64scatter_pd(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4df((double *)(addr), (__mmask8)(mask), \
                               (__v4di)(__m256i)(index), \
                               (__v4df)(__m256d)(v1), (int)(scale)); })

#define _mm256_i64scatter_epi64(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4di((long long *)(addr), (__mmask8)-1, \
                               (__v4di)(__m256i)(index), \
                               (__v4di)(__m256i)(v1), (int)(scale)); })

#define _mm256_mask_i64scatter_epi64(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4di((long long *)(addr), (__mmask8)(mask), \
                               (__v4di)(__m256i)(index), \
                               (__v4di)(__m256i)(v1), (int)(scale)); })

#define _mm_i64scatter_ps(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4sf((float *)(addr), (__mmask8)-1, \
                               (__v2di)(__m128i)(index), (__v4sf)(__m128)(v1), \
                               (int)(scale)); })

#define _mm_mask_i64scatter_ps(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4sf((float *)(addr), (__mmask8)(mask), \
                               (__v2di)(__m128i)(index), (__v4sf)(__m128)(v1), \
                               (int)(scale)); })

#define _mm_i64scatter_epi32(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4si((int *)(addr), (__mmask8)-1, \
                               (__v2di)(__m128i)(index), \
                               (__v4si)(__m128i)(v1), (int)(scale)); })

#define _mm_mask_i64scatter_epi32(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv4si((int *)(addr), (__mmask8)(mask), \
                               (__v2di)(__m128i)(index), \
                               (__v4si)(__m128i)(v1), (int)(scale)); })

#define _mm256_i64scatter_ps(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv8sf((float *)(addr), (__mmask8)-1, \
                               (__v4di)(__m256i)(index), (__v4sf)(__m128)(v1), \
                               (int)(scale)); })

#define _mm256_mask_i64scatter_ps(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv8sf((float *)(addr), (__mmask8)(mask), \
                               (__v4di)(__m256i)(index), (__v4sf)(__m128)(v1), \
                               (int)(scale)); })

#define _mm256_i64scatter_epi32(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scatterdiv8si((int *)(addr), (__mmask8)-1, \
                               (__v4di)(__m256i)(index), \
                               (__v4si)(__m128i)(v1), (int)(scale)); })

#define _mm256_mask_i64scatter_epi32(addr, mask, index, v1, scale) __extension__ ({  \
  __builtin_ia32_scatterdiv8si((int *)(addr), (__mmask8)(mask), \
                               (__v4di)(__m256i)(index), \
                               (__v4si)(__m128i)(v1), (int)(scale)); })

#define _mm_i32scatter_pd(addr, index, v1, scale) __extension__ ({      \
  __builtin_ia32_scattersiv2df((double *)(addr), (__mmask8)-1, \
                               (__v4si)(__m128i)(index), \
                               (__v2df)(__m128d)(v1), (int)(scale)); })

#define _mm_mask_i32scatter_pd(addr, mask, index, v1, scale) __extension__ ({        \
  __builtin_ia32_scattersiv2df((double *)(addr), (__mmask8)(mask), \
                               (__v4si)(__m128i)(index), \
                               (__v2df)(__m128d)(v1), (int)(scale)); })

#define _mm_i32scatter_epi64(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv2di((long long *)(addr), (__mmask8)-1, \
                               (__v4si)(__m128i)(index), \
                               (__v2di)(__m128i)(v1), (int)(scale)); })

#define _mm_mask_i32scatter_epi64(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv2di((long long *)(addr), (__mmask8)(mask), \
                               (__v4si)(__m128i)(index), \
                               (__v2di)(__m128i)(v1), (int)(scale)); })

#define _mm256_i32scatter_pd(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4df((double *)(addr), (__mmask8)-1, \
                               (__v4si)(__m128i)(index), \
                               (__v4df)(__m256d)(v1), (int)(scale)); })

#define _mm256_mask_i32scatter_pd(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4df((double *)(addr), (__mmask8)(mask), \
                               (__v4si)(__m128i)(index), \
                               (__v4df)(__m256d)(v1), (int)(scale)); })

#define _mm256_i32scatter_epi64(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4di((long long *)(addr), (__mmask8)-1, \
                               (__v4si)(__m128i)(index), \
                               (__v4di)(__m256i)(v1), (int)(scale)); })

#define _mm256_mask_i32scatter_epi64(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4di((long long *)(addr), (__mmask8)(mask), \
                               (__v4si)(__m128i)(index), \
                               (__v4di)(__m256i)(v1), (int)(scale)); })

#define _mm_i32scatter_ps(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4sf((float *)(addr), (__mmask8)-1, \
                               (__v4si)(__m128i)(index), (__v4sf)(__m128)(v1), \
                               (int)(scale)); })

#define _mm_mask_i32scatter_ps(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4sf((float *)(addr), (__mmask8)(mask), \
                               (__v4si)(__m128i)(index), (__v4sf)(__m128)(v1), \
                               (int)(scale)); })

#define _mm_i32scatter_epi32(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4si((int *)(addr), (__mmask8)-1, \
                               (__v4si)(__m128i)(index), \
                               (__v4si)(__m128i)(v1), (int)(scale)); })

#define _mm_mask_i32scatter_epi32(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv4si((int *)(addr), (__mmask8)(mask), \
                               (__v4si)(__m128i)(index), \
                               (__v4si)(__m128i)(v1), (int)(scale)); })

#define _mm256_i32scatter_ps(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv8sf((float *)(addr), (__mmask8)-1, \
                               (__v8si)(__m256i)(index), (__v8sf)(__m256)(v1), \
                               (int)(scale)); })

#define _mm256_mask_i32scatter_ps(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv8sf((float *)(addr), (__mmask8)(mask), \
                               (__v8si)(__m256i)(index), (__v8sf)(__m256)(v1), \
                               (int)(scale)); })

#define _mm256_i32scatter_epi32(addr, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv8si((int *)(addr), (__mmask8)-1, \
                               (__v8si)(__m256i)(index), \
                               (__v8si)(__m256i)(v1), (int)(scale)); })

#define _mm256_mask_i32scatter_epi32(addr, mask, index, v1, scale) __extension__ ({ \
  __builtin_ia32_scattersiv8si((int *)(addr), (__mmask8)(mask), \
                               (__v8si)(__m256i)(index), \
                               (__v8si)(__m256i)(v1), (int)(scale)); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_sqrt_pd(__m128d __W, __mmask8 __U, __m128d __A) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_sqrt_pd(__A),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_sqrt_pd(__mmask8 __U, __m128d __A) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_sqrt_pd(__A),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_sqrt_pd(__m256d __W, __mmask8 __U, __m256d __A) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_sqrt_pd(__A),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_sqrt_pd(__mmask8 __U, __m256d __A) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_sqrt_pd(__A),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_sqrt_ps(__m128 __W, __mmask8 __U, __m128 __A) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_sqrt_ps(__A),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_sqrt_ps(__mmask8 __U, __m128 __A) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_sqrt_ps(__A),
                                             (__v4sf)_mm_setzero_pd());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_sqrt_ps(__m256 __W, __mmask8 __U, __m256 __A) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_sqrt_ps(__A),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_sqrt_ps(__mmask8 __U, __m256 __A) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_sqrt_ps(__A),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_sub_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_sub_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_sub_pd(__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_sub_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_sub_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_sub_pd(__A, __B),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_sub_pd(__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_sub_pd(__A, __B),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_sub_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_sub_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_sub_ps(__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_sub_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_sub_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_sub_ps(__A, __B),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_sub_ps(__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_sub_ps(__A, __B),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask2_permutex2var_epi32 (__m128i __A, __m128i __I, __mmask8 __U,
            __m128i __B) {
  return (__m128i) __builtin_ia32_vpermi2vard128_mask ((__v4si) __A,
                   (__v4si) __I
                   /* idx */ ,
                   (__v4si) __B,
                   (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask2_permutex2var_epi32 (__m256i __A, __m256i __I,
         __mmask8 __U, __m256i __B) {
  return (__m256i) __builtin_ia32_vpermi2vard256_mask ((__v8si) __A,
                   (__v8si) __I
                   /* idx */ ,
                   (__v8si) __B,
                   (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask2_permutex2var_pd (__m128d __A, __m128i __I, __mmask8 __U,
         __m128d __B) {
  return (__m128d) __builtin_ia32_vpermi2varpd128_mask ((__v2df) __A,
              (__v2di) __I
              /* idx */ ,
              (__v2df) __B,
              (__mmask8)
              __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask2_permutex2var_pd (__m256d __A, __m256i __I, __mmask8 __U,
            __m256d __B) {
  return (__m256d) __builtin_ia32_vpermi2varpd256_mask ((__v4df) __A,
              (__v4di) __I
              /* idx */ ,
              (__v4df) __B,
              (__mmask8)
              __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask2_permutex2var_ps (__m128 __A, __m128i __I, __mmask8 __U,
         __m128 __B) {
  return (__m128) __builtin_ia32_vpermi2varps128_mask ((__v4sf) __A,
                   (__v4si) __I
                   /* idx */ ,
                   (__v4sf) __B,
                   (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask2_permutex2var_ps (__m256 __A, __m256i __I, __mmask8 __U,
            __m256 __B) {
  return (__m256) __builtin_ia32_vpermi2varps256_mask ((__v8sf) __A,
                   (__v8si) __I
                   /* idx */ ,
                   (__v8sf) __B,
                   (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask2_permutex2var_epi64 (__m128i __A, __m128i __I, __mmask8 __U,
            __m128i __B) {
  return (__m128i) __builtin_ia32_vpermi2varq128_mask ((__v2di) __A,
                   (__v2di) __I
                   /* idx */ ,
                   (__v2di) __B,
                   (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask2_permutex2var_epi64 (__m256i __A, __m256i __I,
         __mmask8 __U, __m256i __B) {
  return (__m256i) __builtin_ia32_vpermi2varq256_mask ((__v4di) __A,
                   (__v4di) __I
                   /* idx */ ,
                   (__v4di) __B,
                   (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_permutex2var_epi32 (__m128i __A, __m128i __I, __m128i __B) {
  return (__m128i) __builtin_ia32_vpermt2vard128_mask ((__v4si) __I
                   /* idx */ ,
                   (__v4si) __A,
                   (__v4si) __B,
                   (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_permutex2var_epi32 (__m128i __A, __mmask8 __U, __m128i __I,
           __m128i __B) {
  return (__m128i) __builtin_ia32_vpermt2vard128_mask ((__v4si) __I
                   /* idx */ ,
                   (__v4si) __A,
                   (__v4si) __B,
                   (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_permutex2var_epi32 (__mmask8 __U, __m128i __A, __m128i __I,
            __m128i __B) {
  return (__m128i) __builtin_ia32_vpermt2vard128_maskz ((__v4si) __I
              /* idx */ ,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8)
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_permutex2var_epi32 (__m256i __A, __m256i __I, __m256i __B) {
  return (__m256i) __builtin_ia32_vpermt2vard256_mask ((__v8si) __I
                   /* idx */ ,
                   (__v8si) __A,
                   (__v8si) __B,
                   (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_permutex2var_epi32 (__m256i __A, __mmask8 __U, __m256i __I,
        __m256i __B) {
  return (__m256i) __builtin_ia32_vpermt2vard256_mask ((__v8si) __I
                   /* idx */ ,
                   (__v8si) __A,
                   (__v8si) __B,
                   (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_permutex2var_epi32 (__mmask8 __U, __m256i __A,
         __m256i __I, __m256i __B) {
  return (__m256i) __builtin_ia32_vpermt2vard256_maskz ((__v8si) __I
              /* idx */ ,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8)
              __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_permutex2var_pd (__m128d __A, __m128i __I, __m128d __B) {
  return (__m128d) __builtin_ia32_vpermt2varpd128_mask ((__v2di) __I
              /* idx */ ,
              (__v2df) __A,
              (__v2df) __B,
              (__mmask8) -
              1);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_permutex2var_pd (__m128d __A, __mmask8 __U, __m128i __I,
        __m128d __B) {
  return (__m128d) __builtin_ia32_vpermt2varpd128_mask ((__v2di) __I
              /* idx */ ,
              (__v2df) __A,
              (__v2df) __B,
              (__mmask8)
              __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_permutex2var_pd (__mmask8 __U, __m128d __A, __m128i __I,
         __m128d __B) {
  return (__m128d) __builtin_ia32_vpermt2varpd128_maskz ((__v2di) __I
               /* idx */ ,
               (__v2df) __A,
               (__v2df) __B,
               (__mmask8)
               __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_permutex2var_pd (__m256d __A, __m256i __I, __m256d __B) {
  return (__m256d) __builtin_ia32_vpermt2varpd256_mask ((__v4di) __I
              /* idx */ ,
              (__v4df) __A,
              (__v4df) __B,
              (__mmask8) -
              1);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_permutex2var_pd (__m256d __A, __mmask8 __U, __m256i __I,
           __m256d __B) {
  return (__m256d) __builtin_ia32_vpermt2varpd256_mask ((__v4di) __I
              /* idx */ ,
              (__v4df) __A,
              (__v4df) __B,
              (__mmask8)
              __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_permutex2var_pd (__mmask8 __U, __m256d __A, __m256i __I,
            __m256d __B) {
  return (__m256d) __builtin_ia32_vpermt2varpd256_maskz ((__v4di) __I
               /* idx */ ,
               (__v4df) __A,
               (__v4df) __B,
               (__mmask8)
               __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_permutex2var_ps (__m128 __A, __m128i __I, __m128 __B) {
  return (__m128) __builtin_ia32_vpermt2varps128_mask ((__v4si) __I
                   /* idx */ ,
                   (__v4sf) __A,
                   (__v4sf) __B,
                   (__mmask8) -1);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_permutex2var_ps (__m128 __A, __mmask8 __U, __m128i __I,
        __m128 __B) {
  return (__m128) __builtin_ia32_vpermt2varps128_mask ((__v4si) __I
                   /* idx */ ,
                   (__v4sf) __A,
                   (__v4sf) __B,
                   (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_permutex2var_ps (__mmask8 __U, __m128 __A, __m128i __I,
         __m128 __B) {
  return (__m128) __builtin_ia32_vpermt2varps128_maskz ((__v4si) __I
              /* idx */ ,
              (__v4sf) __A,
              (__v4sf) __B,
              (__mmask8)
              __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_permutex2var_ps (__m256 __A, __m256i __I, __m256 __B) {
  return (__m256) __builtin_ia32_vpermt2varps256_mask ((__v8si) __I
                   /* idx */ ,
                   (__v8sf) __A,
                   (__v8sf) __B,
                   (__mmask8) -1);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_permutex2var_ps (__m256 __A, __mmask8 __U, __m256i __I,
           __m256 __B) {
  return (__m256) __builtin_ia32_vpermt2varps256_mask ((__v8si) __I
                   /* idx */ ,
                   (__v8sf) __A,
                   (__v8sf) __B,
                   (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_permutex2var_ps (__mmask8 __U, __m256 __A, __m256i __I,
            __m256 __B) {
  return (__m256) __builtin_ia32_vpermt2varps256_maskz ((__v8si) __I
              /* idx */ ,
              (__v8sf) __A,
              (__v8sf) __B,
              (__mmask8)
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_permutex2var_epi64 (__m128i __A, __m128i __I, __m128i __B) {
  return (__m128i) __builtin_ia32_vpermt2varq128_mask ((__v2di) __I
                   /* idx */ ,
                   (__v2di) __A,
                   (__v2di) __B,
                   (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_permutex2var_epi64 (__m128i __A, __mmask8 __U, __m128i __I,
           __m128i __B) {
  return (__m128i) __builtin_ia32_vpermt2varq128_mask ((__v2di) __I
                   /* idx */ ,
                   (__v2di) __A,
                   (__v2di) __B,
                   (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_permutex2var_epi64 (__mmask8 __U, __m128i __A, __m128i __I,
            __m128i __B) {
  return (__m128i) __builtin_ia32_vpermt2varq128_maskz ((__v2di) __I
              /* idx */ ,
              (__v2di) __A,
              (__v2di) __B,
              (__mmask8)
              __U);
}


static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_permutex2var_epi64 (__m256i __A, __m256i __I, __m256i __B) {
  return (__m256i) __builtin_ia32_vpermt2varq256_mask ((__v4di) __I
                   /* idx */ ,
                   (__v4di) __A,
                   (__v4di) __B,
                   (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_permutex2var_epi64 (__m256i __A, __mmask8 __U, __m256i __I,
        __m256i __B) {
  return (__m256i) __builtin_ia32_vpermt2varq256_mask ((__v4di) __I
                   /* idx */ ,
                   (__v4di) __A,
                   (__v4di) __B,
                   (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_permutex2var_epi64 (__mmask8 __U, __m256i __A,
         __m256i __I, __m256i __B) {
  return (__m256i) __builtin_ia32_vpermt2varq256_maskz ((__v4di) __I
              /* idx */ ,
              (__v4di) __A,
              (__v4di) __B,
              (__mmask8)
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi8_epi32(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepi8_epi32(__A),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi8_epi32(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepi8_epi32(__A),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi8_epi32 (__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepi8_epi32(__A),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi8_epi32 (__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepi8_epi32(__A),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi8_epi64(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepi8_epi64(__A),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi8_epi64(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepi8_epi64(__A),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi8_epi64(__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepi8_epi64(__A),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi8_epi64(__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepi8_epi64(__A),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi32_epi64(__m128i __W, __mmask8 __U, __m128i __X)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepi32_epi64(__X),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi32_epi64(__mmask8 __U, __m128i __X)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepi32_epi64(__X),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi32_epi64(__m256i __W, __mmask8 __U, __m128i __X)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepi32_epi64(__X),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi32_epi64(__mmask8 __U, __m128i __X)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepi32_epi64(__X),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi16_epi32(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepi16_epi32(__A),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi16_epi32(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepi16_epi32(__A),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi16_epi32(__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepi16_epi32(__A),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi16_epi32 (__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepi16_epi32(__A),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi16_epi64(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepi16_epi64(__A),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi16_epi64(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepi16_epi64(__A),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi16_epi64(__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepi16_epi64(__A),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi16_epi64(__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepi16_epi64(__A),
                                             (__v4di)_mm256_setzero_si256());
}


static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepu8_epi32(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepu8_epi32(__A),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepu8_epi32(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepu8_epi32(__A),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepu8_epi32(__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepu8_epi32(__A),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepu8_epi32(__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepu8_epi32(__A),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepu8_epi64(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepu8_epi64(__A),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepu8_epi64(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepu8_epi64(__A),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepu8_epi64(__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepu8_epi64(__A),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepu8_epi64 (__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepu8_epi64(__A),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepu32_epi64(__m128i __W, __mmask8 __U, __m128i __X)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepu32_epi64(__X),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepu32_epi64(__mmask8 __U, __m128i __X)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepu32_epi64(__X),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepu32_epi64(__m256i __W, __mmask8 __U, __m128i __X)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepu32_epi64(__X),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepu32_epi64(__mmask8 __U, __m128i __X)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepu32_epi64(__X),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepu16_epi32(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepu16_epi32(__A),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepu16_epi32(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_cvtepu16_epi32(__A),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepu16_epi32(__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepu16_epi32(__A),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepu16_epi32(__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_cvtepu16_epi32(__A),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepu16_epi64(__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepu16_epi64(__A),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepu16_epi64(__mmask8 __U, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_cvtepu16_epi64(__A),
                                             (__v2di)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepu16_epi64(__m256i __W, __mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepu16_epi64(__A),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepu16_epi64(__mmask8 __U, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_cvtepu16_epi64(__A),
                                             (__v4di)_mm256_setzero_si256());
}


#define _mm_rol_epi32(a, b) __extension__ ({\
  (__m128i)__builtin_ia32_prold128_mask((__v4si)(__m128i)(a), (int)(b), \
                                        (__v4si)_mm_setzero_si128(), \
                                        (__mmask8)-1); })

#define _mm_mask_rol_epi32(w, u, a, b) __extension__ ({\
  (__m128i)__builtin_ia32_prold128_mask((__v4si)(__m128i)(a), (int)(b), \
                                        (__v4si)(__m128i)(w), (__mmask8)(u)); })

#define _mm_maskz_rol_epi32(u, a, b) __extension__ ({\
  (__m128i)__builtin_ia32_prold128_mask((__v4si)(__m128i)(a), (int)(b), \
                                        (__v4si)_mm_setzero_si128(), \
                                        (__mmask8)(u)); })

#define _mm256_rol_epi32(a, b) __extension__ ({\
  (__m256i)__builtin_ia32_prold256_mask((__v8si)(__m256i)(a), (int)(b), \
                                        (__v8si)_mm256_setzero_si256(), \
                                        (__mmask8)-1); })

#define _mm256_mask_rol_epi32(w, u, a, b) __extension__ ({\
  (__m256i)__builtin_ia32_prold256_mask((__v8si)(__m256i)(a), (int)(b), \
                                        (__v8si)(__m256i)(w), (__mmask8)(u)); })

#define _mm256_maskz_rol_epi32(u, a, b) __extension__ ({\
  (__m256i)__builtin_ia32_prold256_mask((__v8si)(__m256i)(a), (int)(b), \
                                        (__v8si)_mm256_setzero_si256(), \
                                        (__mmask8)(u)); })

#define _mm_rol_epi64(a, b) __extension__ ({\
  (__m128i)__builtin_ia32_prolq128_mask((__v2di)(__m128i)(a), (int)(b), \
                                        (__v2di)_mm_setzero_di(), \
                                        (__mmask8)-1); })

#define _mm_mask_rol_epi64(w, u, a, b) __extension__ ({\
  (__m128i)__builtin_ia32_prolq128_mask((__v2di)(__m128i)(a), (int)(b), \
                                        (__v2di)(__m128i)(w), (__mmask8)(u)); })

#define _mm_maskz_rol_epi64(u, a, b) __extension__ ({\
  (__m128i)__builtin_ia32_prolq128_mask((__v2di)(__m128i)(a), (int)(b), \
                                        (__v2di)_mm_setzero_di(), \
                                        (__mmask8)(u)); })

#define _mm256_rol_epi64(a, b) __extension__ ({\
  (__m256i)__builtin_ia32_prolq256_mask((__v4di)(__m256i)(a), (int)(b), \
                                        (__v4di)_mm256_setzero_si256(), \
                                        (__mmask8)-1); })

#define _mm256_mask_rol_epi64(w, u, a, b) __extension__ ({\
  (__m256i)__builtin_ia32_prolq256_mask((__v4di)(__m256i)(a), (int)(b), \
                                        (__v4di)(__m256i)(w), (__mmask8)(u)); })

#define _mm256_maskz_rol_epi64(u, a, b) __extension__ ({\
  (__m256i)__builtin_ia32_prolq256_mask((__v4di)(__m256i)(a), (int)(b), \
                                        (__v4di)_mm256_setzero_si256(), \
                                        (__mmask8)(u)); })

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_rolv_epi32 (__m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prolvd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si)
              _mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_rolv_epi32 (__m128i __W, __mmask8 __U, __m128i __A,
         __m128i __B)
{
  return (__m128i) __builtin_ia32_prolvd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si) __W,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_rolv_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prolvd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si)
              _mm_setzero_si128 (),
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_rolv_epi32 (__m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prolvd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_rolv_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
      __m256i __B)
{
  return (__m256i) __builtin_ia32_prolvd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si) __W,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_rolv_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prolvd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si)
              _mm256_setzero_si256 (),
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_rolv_epi64 (__m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prolvq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_di (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_rolv_epi64 (__m128i __W, __mmask8 __U, __m128i __A,
         __m128i __B)
{
  return (__m128i) __builtin_ia32_prolvq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_rolv_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prolvq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_di (),
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_rolv_epi64 (__m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prolvq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_rolv_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
      __m256i __B)
{
  return (__m256i) __builtin_ia32_prolvq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_rolv_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prolvq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) __U);
}

#define _mm_ror_epi32(A, B) __extension__ ({ \
  (__m128i)__builtin_ia32_prord128_mask((__v4si)(__m128i)(A), (int)(B), \
                                        (__v4si)_mm_setzero_si128(), \
                                        (__mmask8)-1); })

#define _mm_mask_ror_epi32(W, U, A, B) __extension__ ({ \
  (__m128i)__builtin_ia32_prord128_mask((__v4si)(__m128i)(A), (int)(B), \
                                        (__v4si)(__m128i)(W), (__mmask8)(U)); })

#define _mm_maskz_ror_epi32(U, A, B) __extension__ ({ \
  (__m128i)__builtin_ia32_prord128_mask((__v4si)(__m128i)(A), (int)(B), \
                                        (__v4si)_mm_setzero_si128(), \
                                        (__mmask8)(U)); })

#define _mm256_ror_epi32(A, B) __extension__ ({ \
  (__m256i)__builtin_ia32_prord256_mask((__v8si)(__m256i)(A), (int)(B), \
                                        (__v8si)_mm256_setzero_si256(), \
                                        (__mmask8)-1); })

#define _mm256_mask_ror_epi32(W, U, A, B) __extension__ ({ \
  (__m256i)__builtin_ia32_prord256_mask((__v8si)(__m256i)(A), (int)(B), \
                                        (__v8si)(__m256i)(W), (__mmask8)(U)); })

#define _mm256_maskz_ror_epi32(U, A, B) __extension__ ({ \
  (__m256i)__builtin_ia32_prord256_mask((__v8si)(__m256i)(A), (int)(B), \
                                        (__v8si)_mm256_setzero_si256(), \
                                        (__mmask8)(U)); })

#define _mm_ror_epi64(A, B) __extension__ ({ \
  (__m128i)__builtin_ia32_prorq128_mask((__v2di)(__m128i)(A), (int)(B), \
                                        (__v2di)_mm_setzero_di(), \
                                        (__mmask8)-1); })

#define _mm_mask_ror_epi64(W, U, A, B) __extension__ ({ \
  (__m128i)__builtin_ia32_prorq128_mask((__v2di)(__m128i)(A), (int)(B), \
                                        (__v2di)(__m128i)(W), (__mmask8)(U)); })

#define _mm_maskz_ror_epi64(U, A, B) __extension__ ({ \
  (__m128i)__builtin_ia32_prorq128_mask((__v2di)(__m128i)(A), (int)(B), \
                                        (__v2di)_mm_setzero_di(), \
                                        (__mmask8)(U)); })

#define _mm256_ror_epi64(A, B) __extension__ ({ \
  (__m256i)__builtin_ia32_prorq256_mask((__v4di)(__m256i)(A), (int)(B), \
                                        (__v4di)_mm256_setzero_si256(), \
                                        (__mmask8)-1); })

#define _mm256_mask_ror_epi64(W, U, A, B) __extension__ ({ \
  (__m256i)__builtin_ia32_prorq256_mask((__v4di)(__m256i)(A), (int)(B), \
                                        (__v4di)(__m256i)(W), (__mmask8)(U)); })

#define _mm256_maskz_ror_epi64(U, A, B) __extension__ ({ \
  (__m256i)__builtin_ia32_prorq256_mask((__v4di)(__m256i)(A), (int)(B), \
                                        (__v4di)_mm256_setzero_si256(), \
                                        (__mmask8)(U)); })

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sll_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sll_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sll_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sll_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sll_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_sll_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sll_epi32(__mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_sll_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_slli_epi32(__m128i __W, __mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_slli_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_slli_epi32(__mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_slli_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_slli_epi32(__m256i __W, __mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_slli_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_slli_epi32(__mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_slli_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sll_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_sll_epi64(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sll_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_sll_epi64(__A, __B),
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sll_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_sll_epi64(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sll_epi64(__mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_sll_epi64(__A, __B),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_slli_epi64(__m128i __W, __mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_slli_epi64(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_slli_epi64(__mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_slli_epi64(__A, __B),
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_slli_epi64(__m256i __W, __mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_slli_epi64(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_slli_epi64(__mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_slli_epi64(__A, __B),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_rorv_epi32 (__m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prorvd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si)
              _mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_rorv_epi32 (__m128i __W, __mmask8 __U, __m128i __A,
         __m128i __B)
{
  return (__m128i) __builtin_ia32_prorvd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si) __W,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_rorv_epi32 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prorvd128_mask ((__v4si) __A,
              (__v4si) __B,
              (__v4si)
              _mm_setzero_si128 (),
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_rorv_epi32 (__m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prorvd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_rorv_epi32 (__m256i __W, __mmask8 __U, __m256i __A,
      __m256i __B)
{
  return (__m256i) __builtin_ia32_prorvd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si) __W,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_rorv_epi32 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prorvd256_mask ((__v8si) __A,
              (__v8si) __B,
              (__v8si)
              _mm256_setzero_si256 (),
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_rorv_epi64 (__m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prorvq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_di (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_rorv_epi64 (__m128i __W, __mmask8 __U, __m128i __A,
         __m128i __B)
{
  return (__m128i) __builtin_ia32_prorvq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_rorv_epi64 (__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_prorvq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_di (),
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_rorv_epi64 (__m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prorvq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_rorv_epi64 (__m256i __W, __mmask8 __U, __m256i __A,
      __m256i __B)
{
  return (__m256i) __builtin_ia32_prorvq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_rorv_epi64 (__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_prorvq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sllv_epi64(__m128i __W, __mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_sllv_epi64(__X, __Y),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sllv_epi64(__mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_sllv_epi64(__X, __Y),
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sllv_epi64(__m256i __W, __mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                            (__v4di)_mm256_sllv_epi64(__X, __Y),
                                            (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sllv_epi64(__mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                            (__v4di)_mm256_sllv_epi64(__X, __Y),
                                            (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sllv_epi32(__m128i __W, __mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sllv_epi32(__X, __Y),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sllv_epi32(__mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sllv_epi32(__X, __Y),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sllv_epi32(__m256i __W, __mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                            (__v8si)_mm256_sllv_epi32(__X, __Y),
                                            (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sllv_epi32(__mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                            (__v8si)_mm256_sllv_epi32(__X, __Y),
                                            (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srlv_epi64(__m128i __W, __mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srlv_epi64(__X, __Y),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srlv_epi64(__mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srlv_epi64(__X, __Y),
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srlv_epi64(__m256i __W, __mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                            (__v4di)_mm256_srlv_epi64(__X, __Y),
                                            (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srlv_epi64(__mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                            (__v4di)_mm256_srlv_epi64(__X, __Y),
                                            (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srlv_epi32(__m128i __W, __mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                            (__v4si)_mm_srlv_epi32(__X, __Y),
                                            (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srlv_epi32(__mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                            (__v4si)_mm_srlv_epi32(__X, __Y),
                                            (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srlv_epi32(__m256i __W, __mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                            (__v8si)_mm256_srlv_epi32(__X, __Y),
                                            (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srlv_epi32(__mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                            (__v8si)_mm256_srlv_epi32(__X, __Y),
                                            (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srl_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_srl_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srl_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_srl_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srl_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_srl_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srl_epi32(__mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_srl_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srli_epi32(__m128i __W, __mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_srli_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srli_epi32(__mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_srli_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srli_epi32(__m256i __W, __mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_srli_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srli_epi32(__mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_srli_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srl_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srl_epi64(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srl_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srl_epi64(__A, __B),
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srl_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_srl_epi64(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srl_epi64(__mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_srl_epi64(__A, __B),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srli_epi64(__m128i __W, __mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srli_epi64(__A, __B),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srli_epi64(__mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srli_epi64(__A, __B),
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srli_epi64(__m256i __W, __mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_srli_epi64(__A, __B),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srli_epi64(__mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_srli_epi64(__A, __B),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srav_epi32(__m128i __W, __mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                            (__v4si)_mm_srav_epi32(__X, __Y),
                                            (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srav_epi32(__mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                            (__v4si)_mm_srav_epi32(__X, __Y),
                                            (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srav_epi32(__m256i __W, __mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                            (__v8si)_mm256_srav_epi32(__X, __Y),
                                            (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srav_epi32(__mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                            (__v8si)_mm256_srav_epi32(__X, __Y),
                                            (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_srav_epi64(__m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_psravq128((__v2di)__X, (__v2di)__Y);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srav_epi64(__m128i __W, __mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srav_epi64(__X, __Y),
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srav_epi64(__mmask8 __U, __m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                             (__v2di)_mm_srav_epi64(__X, __Y),
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srav_epi64(__m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_psravq256((__v4di)__X, (__v4di) __Y);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srav_epi64(__m256i __W, __mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_srav_epi64(__X, __Y),
                                             (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srav_epi64 (__mmask8 __U, __m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                             (__v4di)_mm256_srav_epi64(__X, __Y),
                                             (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mov_epi32 (__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_selectd_128 ((__mmask8) __U,
                 (__v4si) __A,
                 (__v4si) __W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mov_epi32 (__mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_selectd_128 ((__mmask8) __U,
                 (__v4si) __A,
                 (__v4si) _mm_setzero_si128 ());
}


static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mov_epi32 (__m256i __W, __mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_selectd_256 ((__mmask8) __U,
                 (__v8si) __A,
                 (__v8si) __W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mov_epi32 (__mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_selectd_256 ((__mmask8) __U,
                 (__v8si) __A,
                 (__v8si) _mm256_setzero_si256 ());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_load_epi32 (__m128i __W, __mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_movdqa32load128_mask ((__v4si *) __P,
              (__v4si) __W,
              (__mmask8)
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_load_epi32 (__mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_movdqa32load128_mask ((__v4si *) __P,
              (__v4si)
              _mm_setzero_si128 (),
              (__mmask8)
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_load_epi32 (__m256i __W, __mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_movdqa32load256_mask ((__v8si *) __P,
              (__v8si) __W,
              (__mmask8)
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_load_epi32 (__mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_movdqa32load256_mask ((__v8si *) __P,
              (__v8si)
              _mm256_setzero_si256 (),
              (__mmask8)
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_store_epi32 (void *__P, __mmask8 __U, __m128i __A)
{
  __builtin_ia32_movdqa32store128_mask ((__v4si *) __P,
          (__v4si) __A,
          (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_store_epi32 (void *__P, __mmask8 __U, __m256i __A)
{
  __builtin_ia32_movdqa32store256_mask ((__v8si *) __P,
          (__v8si) __A,
          (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mov_epi64 (__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_selectq_128 ((__mmask8) __U,
                 (__v2di) __A,
                 (__v2di) __W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mov_epi64 (__mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_selectq_128 ((__mmask8) __U,
                 (__v2di) __A,
                 (__v2di) _mm_setzero_di ());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mov_epi64 (__m256i __W, __mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_selectq_256 ((__mmask8) __U,
                 (__v4di) __A,
                 (__v4di) __W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mov_epi64 (__mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_selectq_256 ((__mmask8) __U,
                 (__v4di) __A,
                 (__v4di) _mm256_setzero_si256 ());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_load_epi64 (__m128i __W, __mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_movdqa64load128_mask ((__v2di *) __P,
              (__v2di) __W,
              (__mmask8)
              __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_load_epi64 (__mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_movdqa64load128_mask ((__v2di *) __P,
              (__v2di)
              _mm_setzero_di (),
              (__mmask8)
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_load_epi64 (__m256i __W, __mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_movdqa64load256_mask ((__v4di *) __P,
              (__v4di) __W,
              (__mmask8)
              __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_load_epi64 (__mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_movdqa64load256_mask ((__v4di *) __P,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8)
              __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_store_epi64 (void *__P, __mmask8 __U, __m128i __A)
{
  __builtin_ia32_movdqa64store128_mask ((__v2di *) __P,
          (__v2di) __A,
          (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_store_epi64 (void *__P, __mmask8 __U, __m256i __A)
{
  __builtin_ia32_movdqa64store256_mask ((__v4di *) __P,
          (__v4di) __A,
          (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_movedup_pd (__m128d __W, __mmask8 __U, __m128d __A)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_movedup_pd(__A),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_movedup_pd (__mmask8 __U, __m128d __A)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_movedup_pd(__A),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_movedup_pd (__m256d __W, __mmask8 __U, __m256d __A)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_movedup_pd(__A),
                                              (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_movedup_pd (__mmask8 __U, __m256d __A)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                              (__v4df)_mm256_movedup_pd(__A),
                                              (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_set1_epi32(__m128i __O, __mmask8 __M, int __A)
{
   return (__m128i)__builtin_ia32_selectd_128(__M,
                                              (__v4si) _mm_set1_epi32(__A),
                                              (__v4si)__O);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_set1_epi32( __mmask8 __M, int __A)
{
   return (__m128i)__builtin_ia32_selectd_128(__M,
                                              (__v4si) _mm_set1_epi32(__A),
                                              (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_set1_epi32(__m256i __O, __mmask8 __M, int __A)
{
   return (__m256i)__builtin_ia32_selectd_256(__M,
                                              (__v8si) _mm256_set1_epi32(__A),
                                              (__v8si)__O);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_set1_epi32( __mmask8 __M, int __A)
{
   return (__m256i)__builtin_ia32_selectd_256(__M,
                                              (__v8si) _mm256_set1_epi32(__A),
                                              (__v8si)_mm256_setzero_si256());
}


#ifdef __x86_64__
static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_set1_epi64 (__m128i __O, __mmask8 __M, long long __A)
{
  return (__m128i) __builtin_ia32_selectq_128(__M,
                                              (__v2di) _mm_set1_epi64x(__A),
                                              (__v2di) __O);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_set1_epi64 (__mmask8 __M, long long __A)
{
  return (__m128i) __builtin_ia32_selectq_128(__M,
                                              (__v2di) _mm_set1_epi64x(__A),
                                              (__v2di) _mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_set1_epi64 (__m256i __O, __mmask8 __M, long long __A)
{
  return (__m256i) __builtin_ia32_selectq_256(__M,
                                              (__v4di) _mm256_set1_epi64x(__A),
                                              (__v4di) __O) ;
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_set1_epi64 (__mmask8 __M, long long __A)
{
   return (__m256i) __builtin_ia32_selectq_256(__M,
                                               (__v4di) _mm256_set1_epi64x(__A),
                                               (__v4di) _mm256_setzero_si256());
}
  
#endif

#define _mm_fixupimm_pd(A, B, C, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_fixupimmpd128_mask((__v2df)(__m128d)(A), \
                                             (__v2df)(__m128d)(B), \
                                             (__v2di)(__m128i)(C), (int)(imm), \
                                             (__mmask8)-1); })

#define _mm_mask_fixupimm_pd(A, U, B, C, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_fixupimmpd128_mask((__v2df)(__m128d)(A), \
                                             (__v2df)(__m128d)(B), \
                                             (__v2di)(__m128i)(C), (int)(imm), \
                                             (__mmask8)(U)); })

#define _mm_maskz_fixupimm_pd(U, A, B, C, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_fixupimmpd128_maskz((__v2df)(__m128d)(A), \
                                              (__v2df)(__m128d)(B), \
                                              (__v2di)(__m128i)(C), \
                                              (int)(imm), (__mmask8)(U)); })

#define _mm256_fixupimm_pd(A, B, C, imm) __extension__ ({ \
  (__m256d)__builtin_ia32_fixupimmpd256_mask((__v4df)(__m256d)(A), \
                                             (__v4df)(__m256d)(B), \
                                             (__v4di)(__m256i)(C), (int)(imm), \
                                             (__mmask8)-1); })

#define _mm256_mask_fixupimm_pd(A, U, B, C, imm) __extension__ ({ \
  (__m256d)__builtin_ia32_fixupimmpd256_mask((__v4df)(__m256d)(A), \
                                             (__v4df)(__m256d)(B), \
                                             (__v4di)(__m256i)(C), (int)(imm), \
                                             (__mmask8)(U)); })

#define _mm256_maskz_fixupimm_pd(U, A, B, C, imm) __extension__ ({ \
  (__m256d)__builtin_ia32_fixupimmpd256_maskz((__v4df)(__m256d)(A), \
                                              (__v4df)(__m256d)(B), \
                                              (__v4di)(__m256i)(C), \
                                              (int)(imm), (__mmask8)(U)); })

#define _mm_fixupimm_ps(A, B, C, imm) __extension__ ({ \
  (__m128)__builtin_ia32_fixupimmps128_mask((__v4sf)(__m128)(A), \
                                            (__v4sf)(__m128)(B), \
                                            (__v4si)(__m128i)(C), (int)(imm), \
                                            (__mmask8)-1); })

#define _mm_mask_fixupimm_ps(A, U, B, C, imm) __extension__ ({ \
  (__m128)__builtin_ia32_fixupimmps128_mask((__v4sf)(__m128)(A), \
                                            (__v4sf)(__m128)(B), \
                                            (__v4si)(__m128i)(C), (int)(imm), \
                                            (__mmask8)(U)); })

#define _mm_maskz_fixupimm_ps(U, A, B, C, imm) __extension__ ({ \
  (__m128)__builtin_ia32_fixupimmps128_maskz((__v4sf)(__m128)(A), \
                                             (__v4sf)(__m128)(B), \
                                             (__v4si)(__m128i)(C), (int)(imm), \
                                             (__mmask8)(U)); })

#define _mm256_fixupimm_ps(A, B, C, imm) __extension__ ({ \
  (__m256)__builtin_ia32_fixupimmps256_mask((__v8sf)(__m256)(A), \
                                            (__v8sf)(__m256)(B), \
                                            (__v8si)(__m256i)(C), (int)(imm), \
                                            (__mmask8)-1); })

#define _mm256_mask_fixupimm_ps(A, U, B, C, imm) __extension__ ({ \
  (__m256)__builtin_ia32_fixupimmps256_mask((__v8sf)(__m256)(A), \
                                            (__v8sf)(__m256)(B), \
                                            (__v8si)(__m256i)(C), (int)(imm), \
                                            (__mmask8)(U)); })

#define _mm256_maskz_fixupimm_ps(U, A, B, C, imm) __extension__ ({ \
  (__m256)__builtin_ia32_fixupimmps256_maskz((__v8sf)(__m256)(A), \
                                             (__v8sf)(__m256)(B), \
                                             (__v8si)(__m256i)(C), (int)(imm), \
                                             (__mmask8)(U)); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_load_pd (__m128d __W, __mmask8 __U, void const *__P)
{
  return (__m128d) __builtin_ia32_loadapd128_mask ((__v2df *) __P,
               (__v2df) __W,
               (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_load_pd (__mmask8 __U, void const *__P)
{
  return (__m128d) __builtin_ia32_loadapd128_mask ((__v2df *) __P,
               (__v2df)
               _mm_setzero_pd (),
               (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_load_pd (__m256d __W, __mmask8 __U, void const *__P)
{
  return (__m256d) __builtin_ia32_loadapd256_mask ((__v4df *) __P,
               (__v4df) __W,
               (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_load_pd (__mmask8 __U, void const *__P)
{
  return (__m256d) __builtin_ia32_loadapd256_mask ((__v4df *) __P,
               (__v4df)
               _mm256_setzero_pd (),
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_load_ps (__m128 __W, __mmask8 __U, void const *__P)
{
  return (__m128) __builtin_ia32_loadaps128_mask ((__v4sf *) __P,
              (__v4sf) __W,
              (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_load_ps (__mmask8 __U, void const *__P)
{
  return (__m128) __builtin_ia32_loadaps128_mask ((__v4sf *) __P,
              (__v4sf)
              _mm_setzero_ps (),
              (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_load_ps (__m256 __W, __mmask8 __U, void const *__P)
{
  return (__m256) __builtin_ia32_loadaps256_mask ((__v8sf *) __P,
              (__v8sf) __W,
              (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_load_ps (__mmask8 __U, void const *__P)
{
  return (__m256) __builtin_ia32_loadaps256_mask ((__v8sf *) __P,
              (__v8sf)
              _mm256_setzero_ps (),
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_loadu_epi64 (__m128i __W, __mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_loaddqudi128_mask ((__v2di *) __P,
                 (__v2di) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_loadu_epi64 (__mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_loaddqudi128_mask ((__v2di *) __P,
                 (__v2di)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_loadu_epi64 (__m256i __W, __mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_loaddqudi256_mask ((__v4di *) __P,
                 (__v4di) __W,
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_loadu_epi64 (__mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_loaddqudi256_mask ((__v4di *) __P,
                 (__v4di)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_loadu_epi32 (__m128i __W, __mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_loaddqusi128_mask ((__v4si *) __P,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_loadu_epi32 (__mmask8 __U, void const *__P)
{
  return (__m128i) __builtin_ia32_loaddqusi128_mask ((__v4si *) __P,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_loadu_epi32 (__m256i __W, __mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_loaddqusi256_mask ((__v8si *) __P,
                 (__v8si) __W,
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_loadu_epi32 (__mmask8 __U, void const *__P)
{
  return (__m256i) __builtin_ia32_loaddqusi256_mask ((__v8si *) __P,
                 (__v8si)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_loadu_pd (__m128d __W, __mmask8 __U, void const *__P)
{
  return (__m128d) __builtin_ia32_loadupd128_mask ((__v2df *) __P,
               (__v2df) __W,
               (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_loadu_pd (__mmask8 __U, void const *__P)
{
  return (__m128d) __builtin_ia32_loadupd128_mask ((__v2df *) __P,
               (__v2df)
               _mm_setzero_pd (),
               (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_loadu_pd (__m256d __W, __mmask8 __U, void const *__P)
{
  return (__m256d) __builtin_ia32_loadupd256_mask ((__v4df *) __P,
               (__v4df) __W,
               (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_loadu_pd (__mmask8 __U, void const *__P)
{
  return (__m256d) __builtin_ia32_loadupd256_mask ((__v4df *) __P,
               (__v4df)
               _mm256_setzero_pd (),
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_loadu_ps (__m128 __W, __mmask8 __U, void const *__P)
{
  return (__m128) __builtin_ia32_loadups128_mask ((__v4sf *) __P,
              (__v4sf) __W,
              (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_loadu_ps (__mmask8 __U, void const *__P)
{
  return (__m128) __builtin_ia32_loadups128_mask ((__v4sf *) __P,
              (__v4sf)
              _mm_setzero_ps (),
              (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_loadu_ps (__m256 __W, __mmask8 __U, void const *__P)
{
  return (__m256) __builtin_ia32_loadups256_mask ((__v8sf *) __P,
              (__v8sf) __W,
              (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_loadu_ps (__mmask8 __U, void const *__P)
{
  return (__m256) __builtin_ia32_loadups256_mask ((__v8sf *) __P,
              (__v8sf)
              _mm256_setzero_ps (),
              (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_store_pd (void *__P, __mmask8 __U, __m128d __A)
{
  __builtin_ia32_storeapd128_mask ((__v2df *) __P,
           (__v2df) __A,
           (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_store_pd (void *__P, __mmask8 __U, __m256d __A)
{
  __builtin_ia32_storeapd256_mask ((__v4df *) __P,
           (__v4df) __A,
           (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_store_ps (void *__P, __mmask8 __U, __m128 __A)
{
  __builtin_ia32_storeaps128_mask ((__v4sf *) __P,
           (__v4sf) __A,
           (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_store_ps (void *__P, __mmask8 __U, __m256 __A)
{
  __builtin_ia32_storeaps256_mask ((__v8sf *) __P,
           (__v8sf) __A,
           (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_storeu_epi64 (void *__P, __mmask8 __U, __m128i __A)
{
  __builtin_ia32_storedqudi128_mask ((__v2di *) __P,
             (__v2di) __A,
             (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_storeu_epi64 (void *__P, __mmask8 __U, __m256i __A)
{
  __builtin_ia32_storedqudi256_mask ((__v4di *) __P,
             (__v4di) __A,
             (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_storeu_epi32 (void *__P, __mmask8 __U, __m128i __A)
{
  __builtin_ia32_storedqusi128_mask ((__v4si *) __P,
             (__v4si) __A,
             (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_storeu_epi32 (void *__P, __mmask8 __U, __m256i __A)
{
  __builtin_ia32_storedqusi256_mask ((__v8si *) __P,
             (__v8si) __A,
             (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_storeu_pd (void *__P, __mmask8 __U, __m128d __A)
{
  __builtin_ia32_storeupd128_mask ((__v2df *) __P,
           (__v2df) __A,
           (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_storeu_pd (void *__P, __mmask8 __U, __m256d __A)
{
  __builtin_ia32_storeupd256_mask ((__v4df *) __P,
           (__v4df) __A,
           (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_storeu_ps (void *__P, __mmask8 __U, __m128 __A)
{
  __builtin_ia32_storeups128_mask ((__v4sf *) __P,
           (__v4sf) __A,
           (__mmask8) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_storeu_ps (void *__P, __mmask8 __U, __m256 __A)
{
  __builtin_ia32_storeups256_mask ((__v8sf *) __P,
           (__v8sf) __A,
           (__mmask8) __U);
}


static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_unpackhi_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_unpackhi_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_unpackhi_pd(__mmask8 __U, __m128d __A, __m128d __B)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_unpackhi_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_unpackhi_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                           (__v4df)_mm256_unpackhi_pd(__A, __B),
                                           (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_unpackhi_pd(__mmask8 __U, __m256d __A, __m256d __B)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                           (__v4df)_mm256_unpackhi_pd(__A, __B),
                                           (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_unpackhi_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_unpackhi_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_unpackhi_ps(__mmask8 __U, __m128 __A, __m128 __B)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_unpackhi_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_unpackhi_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                           (__v8sf)_mm256_unpackhi_ps(__A, __B),
                                           (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_unpackhi_ps(__mmask8 __U, __m256 __A, __m256 __B)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                           (__v8sf)_mm256_unpackhi_ps(__A, __B),
                                           (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_unpacklo_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128d __B)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_unpacklo_pd(__A, __B),
                                              (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_unpacklo_pd(__mmask8 __U, __m128d __A, __m128d __B)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                              (__v2df)_mm_unpacklo_pd(__A, __B),
                                              (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_unpacklo_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256d __B)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                           (__v4df)_mm256_unpacklo_pd(__A, __B),
                                           (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_unpacklo_pd(__mmask8 __U, __m256d __A, __m256d __B)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                           (__v4df)_mm256_unpacklo_pd(__A, __B),
                                           (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_unpacklo_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128 __B)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_unpacklo_ps(__A, __B),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_unpacklo_ps(__mmask8 __U, __m128 __A, __m128 __B)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_unpacklo_ps(__A, __B),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_unpacklo_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256 __B)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                           (__v8sf)_mm256_unpacklo_ps(__A, __B),
                                           (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_unpacklo_ps(__mmask8 __U, __m256 __A, __m256 __B)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                           (__v8sf)_mm256_unpacklo_ps(__A, __B),
                                           (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_rcp14_pd (__m128d __A)
{
  return (__m128d) __builtin_ia32_rcp14pd128_mask ((__v2df) __A,
                (__v2df)
                _mm_setzero_pd (),
                (__mmask8) -1);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_rcp14_pd (__m128d __W, __mmask8 __U, __m128d __A)
{
  return (__m128d) __builtin_ia32_rcp14pd128_mask ((__v2df) __A,
                (__v2df) __W,
                (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_rcp14_pd (__mmask8 __U, __m128d __A)
{
  return (__m128d) __builtin_ia32_rcp14pd128_mask ((__v2df) __A,
                (__v2df)
                _mm_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_rcp14_pd (__m256d __A)
{
  return (__m256d) __builtin_ia32_rcp14pd256_mask ((__v4df) __A,
                (__v4df)
                _mm256_setzero_pd (),
                (__mmask8) -1);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_rcp14_pd (__m256d __W, __mmask8 __U, __m256d __A)
{
  return (__m256d) __builtin_ia32_rcp14pd256_mask ((__v4df) __A,
                (__v4df) __W,
                (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_rcp14_pd (__mmask8 __U, __m256d __A)
{
  return (__m256d) __builtin_ia32_rcp14pd256_mask ((__v4df) __A,
                (__v4df)
                _mm256_setzero_pd (),
                (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_rcp14_ps (__m128 __A)
{
  return (__m128) __builtin_ia32_rcp14ps128_mask ((__v4sf) __A,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) -1);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_rcp14_ps (__m128 __W, __mmask8 __U, __m128 __A)
{
  return (__m128) __builtin_ia32_rcp14ps128_mask ((__v4sf) __A,
               (__v4sf) __W,
               (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_rcp14_ps (__mmask8 __U, __m128 __A)
{
  return (__m128) __builtin_ia32_rcp14ps128_mask ((__v4sf) __A,
               (__v4sf)
               _mm_setzero_ps (),
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_rcp14_ps (__m256 __A)
{
  return (__m256) __builtin_ia32_rcp14ps256_mask ((__v8sf) __A,
               (__v8sf)
               _mm256_setzero_ps (),
               (__mmask8) -1);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_rcp14_ps (__m256 __W, __mmask8 __U, __m256 __A)
{
  return (__m256) __builtin_ia32_rcp14ps256_mask ((__v8sf) __A,
               (__v8sf) __W,
               (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_rcp14_ps (__mmask8 __U, __m256 __A)
{
  return (__m256) __builtin_ia32_rcp14ps256_mask ((__v8sf) __A,
               (__v8sf)
               _mm256_setzero_ps (),
               (__mmask8) __U);
}

#define _mm_mask_permute_pd(W, U, X, C) __extension__ ({ \
  (__m128d)__builtin_ia32_selectpd_128((__mmask8)(U), \
                                       (__v2df)_mm_permute_pd((X), (C)), \
                                       (__v2df)(__m128d)(W)); })

#define _mm_maskz_permute_pd(U, X, C) __extension__ ({ \
  (__m128d)__builtin_ia32_selectpd_128((__mmask8)(U), \
                                       (__v2df)_mm_permute_pd((X), (C)), \
                                       (__v2df)_mm_setzero_pd()); })

#define _mm256_mask_permute_pd(W, U, X, C) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                       (__v4df)_mm256_permute_pd((X), (C)), \
                                       (__v4df)(__m256d)(W)); })

#define _mm256_maskz_permute_pd(U, X, C) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                       (__v4df)_mm256_permute_pd((X), (C)), \
                                       (__v4df)_mm256_setzero_pd()); })

#define _mm_mask_permute_ps(W, U, X, C) __extension__ ({ \
  (__m128)__builtin_ia32_selectps_128((__mmask8)(U), \
                                      (__v4sf)_mm_permute_ps((X), (C)), \
                                      (__v4sf)(__m128)(W)); })

#define _mm_maskz_permute_ps(U, X, C) __extension__ ({ \
  (__m128)__builtin_ia32_selectps_128((__mmask8)(U), \
                                      (__v4sf)_mm_permute_ps((X), (C)), \
                                      (__v4sf)_mm_setzero_ps()); })

#define _mm256_mask_permute_ps(W, U, X, C) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                      (__v8sf)_mm256_permute_ps((X), (C)), \
                                      (__v8sf)(__m256)(W)); })

#define _mm256_maskz_permute_ps(U, X, C) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                      (__v8sf)_mm256_permute_ps((X), (C)), \
                                      (__v8sf)_mm256_setzero_ps()); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_permutevar_pd(__m128d __W, __mmask8 __U, __m128d __A, __m128i __C)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                            (__v2df)_mm_permutevar_pd(__A, __C),
                                            (__v2df)__W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_permutevar_pd(__mmask8 __U, __m128d __A, __m128i __C)
{
  return (__m128d)__builtin_ia32_selectpd_128((__mmask8)__U,
                                            (__v2df)_mm_permutevar_pd(__A, __C),
                                            (__v2df)_mm_setzero_pd());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_permutevar_pd(__m256d __W, __mmask8 __U, __m256d __A, __m256i __C)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                         (__v4df)_mm256_permutevar_pd(__A, __C),
                                         (__v4df)__W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_permutevar_pd(__mmask8 __U, __m256d __A, __m256i __C)
{
  return (__m256d)__builtin_ia32_selectpd_256((__mmask8)__U,
                                         (__v4df)_mm256_permutevar_pd(__A, __C),
                                         (__v4df)_mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_permutevar_ps(__m128 __W, __mmask8 __U, __m128 __A, __m128i __C)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                            (__v4sf)_mm_permutevar_ps(__A, __C),
                                            (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_permutevar_ps(__mmask8 __U, __m128 __A, __m128i __C)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                            (__v4sf)_mm_permutevar_ps(__A, __C),
                                            (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_permutevar_ps(__m256 __W, __mmask8 __U, __m256 __A, __m256i __C)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                          (__v8sf)_mm256_permutevar_ps(__A, __C),
                                          (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_permutevar_ps(__mmask8 __U, __m256 __A, __m256i __C)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                          (__v8sf)_mm256_permutevar_ps(__A, __C),
                                          (__v8sf)_mm256_setzero_ps());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_test_epi32_mask (__m128i __A, __m128i __B)
{
  return _mm_cmpneq_epi32_mask (_mm_and_si128 (__A, __B), _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_test_epi32_mask (__mmask8 __U, __m128i __A, __m128i __B)
{
  return _mm_mask_cmpneq_epi32_mask (__U, _mm_and_si128 (__A, __B),
                                     _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_test_epi32_mask (__m256i __A, __m256i __B)
{
  return _mm256_cmpneq_epi32_mask (_mm256_and_si256 (__A, __B),
                                   _mm256_setzero_si256());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_test_epi32_mask (__mmask8 __U, __m256i __A, __m256i __B)
{
  return _mm256_mask_cmpneq_epi32_mask (__U, _mm256_and_si256 (__A, __B),
                                        _mm256_setzero_si256());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_test_epi64_mask (__m128i __A, __m128i __B)
{
  return _mm_cmpneq_epi64_mask (_mm_and_si128 (__A, __B), _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_test_epi64_mask (__mmask8 __U, __m128i __A, __m128i __B)
{
  return _mm_mask_cmpneq_epi64_mask (__U, _mm_and_si128 (__A, __B),
                                     _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_test_epi64_mask (__m256i __A, __m256i __B)
{
  return _mm256_cmpneq_epi64_mask (_mm256_and_si256 (__A, __B),
                                   _mm256_setzero_si256());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_test_epi64_mask (__mmask8 __U, __m256i __A, __m256i __B)
{
  return _mm256_mask_cmpneq_epi64_mask (__U, _mm256_and_si256 (__A, __B),
                                        _mm256_setzero_si256());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_testn_epi32_mask (__m128i __A, __m128i __B)
{
  return _mm_cmpeq_epi32_mask (_mm_and_si128 (__A, __B), _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_testn_epi32_mask (__mmask8 __U, __m128i __A, __m128i __B)
{
  return _mm_mask_cmpeq_epi32_mask (__U, _mm_and_si128 (__A, __B),
                                    _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_testn_epi32_mask (__m256i __A, __m256i __B)
{
  return _mm256_cmpeq_epi32_mask (_mm256_and_si256 (__A, __B),
                                  _mm256_setzero_si256());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_testn_epi32_mask (__mmask8 __U, __m256i __A, __m256i __B)
{
  return _mm256_mask_cmpeq_epi32_mask (__U, _mm256_and_si256 (__A, __B),
                                       _mm256_setzero_si256());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_testn_epi64_mask (__m128i __A, __m128i __B)
{
  return _mm_cmpeq_epi64_mask (_mm_and_si128 (__A, __B), _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm_mask_testn_epi64_mask (__mmask8 __U, __m128i __A, __m128i __B)
{
  return _mm_mask_cmpeq_epi64_mask (__U, _mm_and_si128 (__A, __B),
                                    _mm_setzero_di());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_testn_epi64_mask (__m256i __A, __m256i __B)
{
  return _mm256_cmpeq_epi64_mask (_mm256_and_si256 (__A, __B),
                                  _mm256_setzero_si256());
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm256_mask_testn_epi64_mask (__mmask8 __U, __m256i __A, __m256i __B)
{
  return _mm256_mask_cmpeq_epi64_mask (__U, _mm256_and_si256 (__A, __B),
                                       _mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_unpackhi_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                           (__v4si)_mm_unpackhi_epi32(__A, __B),
                                           (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_unpackhi_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                           (__v4si)_mm_unpackhi_epi32(__A, __B),
                                           (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_unpackhi_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                        (__v8si)_mm256_unpackhi_epi32(__A, __B),
                                        (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_unpackhi_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                        (__v8si)_mm256_unpackhi_epi32(__A, __B),
                                        (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_unpackhi_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                           (__v2di)_mm_unpackhi_epi64(__A, __B),
                                           (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_unpackhi_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                           (__v2di)_mm_unpackhi_epi64(__A, __B),
                                           (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_unpackhi_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                        (__v4di)_mm256_unpackhi_epi64(__A, __B),
                                        (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_unpackhi_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                        (__v4di)_mm256_unpackhi_epi64(__A, __B),
                                        (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_unpacklo_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                           (__v4si)_mm_unpacklo_epi32(__A, __B),
                                           (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_unpacklo_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                           (__v4si)_mm_unpacklo_epi32(__A, __B),
                                           (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_unpacklo_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                        (__v8si)_mm256_unpacklo_epi32(__A, __B),
                                        (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_unpacklo_epi32(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                        (__v8si)_mm256_unpacklo_epi32(__A, __B),
                                        (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_unpacklo_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                           (__v2di)_mm_unpacklo_epi64(__A, __B),
                                           (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_unpacklo_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U,
                                           (__v2di)_mm_unpacklo_epi64(__A, __B),
                                           (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_unpacklo_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                        (__v4di)_mm256_unpacklo_epi64(__A, __B),
                                        (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_unpacklo_epi64(__mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U,
                                        (__v4di)_mm256_unpacklo_epi64(__A, __B),
                                        (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sra_epi32(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sra_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sra_epi32(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_sra_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sra_epi32(__m256i __W, __mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_sra_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sra_epi32(__mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_sra_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srai_epi32(__m128i __W, __mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_srai_epi32(__A, __B),
                                             (__v4si)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srai_epi32(__mmask8 __U, __m128i __A, int __B)
{
  return (__m128i)__builtin_ia32_selectd_128((__mmask8)__U,
                                             (__v4si)_mm_srai_epi32(__A, __B),
                                             (__v4si)_mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srai_epi32(__m256i __W, __mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_srai_epi32(__A, __B),
                                             (__v8si)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srai_epi32(__mmask8 __U, __m256i __A, int __B)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__U,
                                             (__v8si)_mm256_srai_epi32(__A, __B),
                                             (__v8si)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_sra_epi64(__m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_psraq128((__v2di)__A, (__v2di)__B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_sra_epi64(__m128i __W, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U, \
                                             (__v2di)_mm_sra_epi64(__A, __B), \
                                             (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_sra_epi64(__mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U, \
                                             (__v2di)_mm_sra_epi64(__A, __B), \
                                             (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sra_epi64(__m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_psraq256((__v4di) __A, (__v2di) __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_sra_epi64(__m256i __W, __mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U, \
                                           (__v4di)_mm256_sra_epi64(__A, __B), \
                                           (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_sra_epi64(__mmask8 __U, __m256i __A, __m128i __B)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U, \
                                           (__v4di)_mm256_sra_epi64(__A, __B), \
                                           (__v4di)_mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_srai_epi64(__m128i __A, int __imm)
{
  return (__m128i)__builtin_ia32_psraqi128((__v2di)__A, __imm);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_srai_epi64(__m128i __W, __mmask8 __U, __m128i __A, int __imm)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U, \
                                           (__v2di)_mm_srai_epi64(__A, __imm), \
                                           (__v2di)__W);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_srai_epi64(__mmask8 __U, __m128i __A, int __imm)
{
  return (__m128i)__builtin_ia32_selectq_128((__mmask8)__U, \
                                           (__v2di)_mm_srai_epi64(__A, __imm), \
                                           (__v2di)_mm_setzero_di());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srai_epi64(__m256i __A, int __imm)
{
  return (__m256i)__builtin_ia32_psraqi256((__v4di)__A, __imm);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_srai_epi64(__m256i __W, __mmask8 __U, __m256i __A, int __imm)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U, \
                                        (__v4di)_mm256_srai_epi64(__A, __imm), \
                                        (__v4di)__W);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_srai_epi64(__mmask8 __U, __m256i __A, int __imm)
{
  return (__m256i)__builtin_ia32_selectq_256((__mmask8)__U, \
                                        (__v4di)_mm256_srai_epi64(__A, __imm), \
                                        (__v4di)_mm256_setzero_si256());
}

#define _mm_ternarylogic_epi32(A, B, C, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_pternlogd128_mask((__v4si)(__m128i)(A), \
                                            (__v4si)(__m128i)(B), \
                                            (__v4si)(__m128i)(C), (int)(imm), \
                                            (__mmask8)-1); })

#define _mm_mask_ternarylogic_epi32(A, U, B, C, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_pternlogd128_mask((__v4si)(__m128i)(A), \
                                            (__v4si)(__m128i)(B), \
                                            (__v4si)(__m128i)(C), (int)(imm), \
                                            (__mmask8)(U)); })

#define _mm_maskz_ternarylogic_epi32(U, A, B, C, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_pternlogd128_maskz((__v4si)(__m128i)(A), \
                                             (__v4si)(__m128i)(B), \
                                             (__v4si)(__m128i)(C), (int)(imm), \
                                             (__mmask8)(U)); })

#define _mm256_ternarylogic_epi32(A, B, C, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_pternlogd256_mask((__v8si)(__m256i)(A), \
                                            (__v8si)(__m256i)(B), \
                                            (__v8si)(__m256i)(C), (int)(imm), \
                                            (__mmask8)-1); })

#define _mm256_mask_ternarylogic_epi32(A, U, B, C, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_pternlogd256_mask((__v8si)(__m256i)(A), \
                                            (__v8si)(__m256i)(B), \
                                            (__v8si)(__m256i)(C), (int)(imm), \
                                            (__mmask8)(U)); })

#define _mm256_maskz_ternarylogic_epi32(U, A, B, C, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_pternlogd256_maskz((__v8si)(__m256i)(A), \
                                             (__v8si)(__m256i)(B), \
                                             (__v8si)(__m256i)(C), (int)(imm), \
                                             (__mmask8)(U)); })

#define _mm_ternarylogic_epi64(A, B, C, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_pternlogq128_mask((__v2di)(__m128i)(A), \
                                            (__v2di)(__m128i)(B), \
                                            (__v2di)(__m128i)(C), (int)(imm), \
                                            (__mmask8)-1); })

#define _mm_mask_ternarylogic_epi64(A, U, B, C, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_pternlogq128_mask((__v2di)(__m128i)(A), \
                                            (__v2di)(__m128i)(B), \
                                            (__v2di)(__m128i)(C), (int)(imm), \
                                            (__mmask8)(U)); })

#define _mm_maskz_ternarylogic_epi64(U, A, B, C, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_pternlogq128_maskz((__v2di)(__m128i)(A), \
                                             (__v2di)(__m128i)(B), \
                                             (__v2di)(__m128i)(C), (int)(imm), \
                                             (__mmask8)(U)); })

#define _mm256_ternarylogic_epi64(A, B, C, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_pternlogq256_mask((__v4di)(__m256i)(A), \
                                            (__v4di)(__m256i)(B), \
                                            (__v4di)(__m256i)(C), (int)(imm), \
                                            (__mmask8)-1); })

#define _mm256_mask_ternarylogic_epi64(A, U, B, C, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_pternlogq256_mask((__v4di)(__m256i)(A), \
                                            (__v4di)(__m256i)(B), \
                                            (__v4di)(__m256i)(C), (int)(imm), \
                                            (__mmask8)(U)); })

#define _mm256_maskz_ternarylogic_epi64(U, A, B, C, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_pternlogq256_maskz((__v4di)(__m256i)(A), \
                                             (__v4di)(__m256i)(B), \
                                             (__v4di)(__m256i)(C), (int)(imm), \
                                             (__mmask8)(U)); })



#define _mm256_shuffle_f32x4(A, B, imm) __extension__ ({ \
  (__m256)__builtin_shufflevector((__v8sf)(__m256)(A), \
                                  (__v8sf)(__m256)(B), \
                                   0 + ((((imm) >> 0) & 0x1) * 4), \
                                   1 + ((((imm) >> 0) & 0x1) * 4), \
                                   2 + ((((imm) >> 0) & 0x1) * 4), \
                                   3 + ((((imm) >> 0) & 0x1) * 4), \
                                   8 + ((((imm) >> 1) & 0x1) * 4), \
                                   9 + ((((imm) >> 1) & 0x1) * 4), \
                                   10 + ((((imm) >> 1) & 0x1) * 4), \
                                   11 + ((((imm) >> 1) & 0x1) * 4)); })                                  

#define _mm256_mask_shuffle_f32x4(W, U, A, B, imm) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                      (__v8sf)_mm256_shuffle_f32x4((A), (B), (imm)), \
                                      (__v8sf)(__m256)(W)); })

#define _mm256_maskz_shuffle_f32x4(U, A, B, imm) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                      (__v8sf)_mm256_shuffle_f32x4((A), (B), (imm)), \
                                      (__v8sf)_mm256_setzero_ps()); })

#define _mm256_shuffle_f64x2(A, B, imm) __extension__ ({ \
  (__m256d)__builtin_shufflevector((__v4df)(__m256d)(A), \
                                   (__v4df)(__m256d)(B), \
                                   0 + ((((imm) >> 0) & 0x1) * 2), \
                                   1 + ((((imm) >> 0) & 0x1) * 2), \
                                   4 + ((((imm) >> 1) & 0x1) * 2), \
                                   5 + ((((imm) >> 1) & 0x1) * 2)); })

#define _mm256_mask_shuffle_f64x2(W, U, A, B, imm) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                      (__v4df)_mm256_shuffle_f64x2((A), (B), (imm)), \
                                      (__v4df)(__m256)(W)); })

#define _mm256_maskz_shuffle_f64x2(U, A, B, imm) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                      (__v4df)_mm256_shuffle_f64x2((A), (B), (imm)), \
                                      (__v4df)_mm256_setzero_pd()); })

#define _mm256_shuffle_i32x4(A, B, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v4di)(__m256i)(A), \
                                   (__v4di)(__m256i)(B), \
                                   0 + ((((imm) >> 0) & 0x1) * 2), \
                                   1 + ((((imm) >> 0) & 0x1) * 2), \
                                   4 + ((((imm) >> 1) & 0x1) * 2), \
                                   5 + ((((imm) >> 1) & 0x1) * 2)); })

#define _mm256_mask_shuffle_i32x4(W, U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                      (__v8si)_mm256_shuffle_i32x4((A), (B), (imm)), \
                                      (__v8si)(__m256)(W)); })

#define _mm256_maskz_shuffle_i32x4(U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                      (__v8si)_mm256_shuffle_i32x4((A), (B), (imm)), \
                                      (__v8si)_mm256_setzero_si256()); })

#define _mm256_shuffle_i64x2(A, B, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v4di)(__m256i)(A), \
                                   (__v4di)(__m256i)(B), \
                                   0 + ((((imm) >> 0) & 0x1) * 2), \
                                   1 + ((((imm) >> 0) & 0x1) * 2), \
                                   4 + ((((imm) >> 1) & 0x1) * 2), \
                                   5 + ((((imm) >> 1) & 0x1) * 2)); })

#define _mm256_mask_shuffle_i64x2(W, U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectq_256((__mmask8)(U), \
                                      (__v4di)_mm256_shuffle_i64x2((A), (B), (imm)), \
                                      (__v4di)(__m256)(W)); })


#define _mm256_maskz_shuffle_i64x2(U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectq_256((__mmask8)(U), \
                                      (__v4di)_mm256_shuffle_i64x2((A), (B), (imm)), \
                                      (__v4di)_mm256_setzero_si256()); })

#define _mm_mask_shuffle_pd(W, U, A, B, M) __extension__ ({ \
  (__m128d)__builtin_ia32_selectpd_128((__mmask8)(U), \
                                       (__v2df)_mm_shuffle_pd((A), (B), (M)), \
                                       (__v2df)(__m128d)(W)); })

#define _mm_maskz_shuffle_pd(U, A, B, M) __extension__ ({ \
  (__m128d)__builtin_ia32_selectpd_128((__mmask8)(U), \
                                       (__v2df)_mm_shuffle_pd((A), (B), (M)), \
                                       (__v2df)_mm_setzero_pd()); })

#define _mm256_mask_shuffle_pd(W, U, A, B, M) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                       (__v4df)_mm256_shuffle_pd((A), (B), (M)), \
                                       (__v4df)(__m256d)(W)); })

#define _mm256_maskz_shuffle_pd(U, A, B, M) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                       (__v4df)_mm256_shuffle_pd((A), (B), (M)), \
                                       (__v4df)_mm256_setzero_pd()); })

#define _mm_mask_shuffle_ps(W, U, A, B, M) __extension__ ({ \
  (__m128)__builtin_ia32_selectps_128((__mmask8)(U), \
                                      (__v4sf)_mm_shuffle_ps((A), (B), (M)), \
                                      (__v4sf)(__m128)(W)); })

#define _mm_maskz_shuffle_ps(U, A, B, M) __extension__ ({ \
  (__m128)__builtin_ia32_selectps_128((__mmask8)(U), \
                                      (__v4sf)_mm_shuffle_ps((A), (B), (M)), \
                                      (__v4sf)_mm_setzero_ps()); })

#define _mm256_mask_shuffle_ps(W, U, A, B, M) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                      (__v8sf)_mm256_shuffle_ps((A), (B), (M)), \
                                      (__v8sf)(__m256)(W)); })

#define _mm256_maskz_shuffle_ps(U, A, B, M) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                      (__v8sf)_mm256_shuffle_ps((A), (B), (M)), \
                                      (__v8sf)_mm256_setzero_ps()); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_rsqrt14_pd (__m128d __A)
{
  return (__m128d) __builtin_ia32_rsqrt14pd128_mask ((__v2df) __A,
                 (__v2df)
                 _mm_setzero_pd (),
                 (__mmask8) -1);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_rsqrt14_pd (__m128d __W, __mmask8 __U, __m128d __A)
{
  return (__m128d) __builtin_ia32_rsqrt14pd128_mask ((__v2df) __A,
                 (__v2df) __W,
                 (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_rsqrt14_pd (__mmask8 __U, __m128d __A)
{
  return (__m128d) __builtin_ia32_rsqrt14pd128_mask ((__v2df) __A,
                 (__v2df)
                 _mm_setzero_pd (),
                 (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_rsqrt14_pd (__m256d __A)
{
  return (__m256d) __builtin_ia32_rsqrt14pd256_mask ((__v4df) __A,
                 (__v4df)
                 _mm256_setzero_pd (),
                 (__mmask8) -1);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_rsqrt14_pd (__m256d __W, __mmask8 __U, __m256d __A)
{
  return (__m256d) __builtin_ia32_rsqrt14pd256_mask ((__v4df) __A,
                 (__v4df) __W,
                 (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_rsqrt14_pd (__mmask8 __U, __m256d __A)
{
  return (__m256d) __builtin_ia32_rsqrt14pd256_mask ((__v4df) __A,
                 (__v4df)
                 _mm256_setzero_pd (),
                 (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_rsqrt14_ps (__m128 __A)
{
  return (__m128) __builtin_ia32_rsqrt14ps128_mask ((__v4sf) __A,
                (__v4sf)
                _mm_setzero_ps (),
                (__mmask8) -1);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_rsqrt14_ps (__m128 __W, __mmask8 __U, __m128 __A)
{
  return (__m128) __builtin_ia32_rsqrt14ps128_mask ((__v4sf) __A,
                (__v4sf) __W,
                (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_rsqrt14_ps (__mmask8 __U, __m128 __A)
{
  return (__m128) __builtin_ia32_rsqrt14ps128_mask ((__v4sf) __A,
                (__v4sf)
                _mm_setzero_ps (),
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_rsqrt14_ps (__m256 __A)
{
  return (__m256) __builtin_ia32_rsqrt14ps256_mask ((__v8sf) __A,
                (__v8sf)
                _mm256_setzero_ps (),
                (__mmask8) -1);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_rsqrt14_ps (__m256 __W, __mmask8 __U, __m256 __A)
{
  return (__m256) __builtin_ia32_rsqrt14ps256_mask ((__v8sf) __A,
                (__v8sf) __W,
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_rsqrt14_ps (__mmask8 __U, __m256 __A)
{
  return (__m256) __builtin_ia32_rsqrt14ps256_mask ((__v8sf) __A,
                (__v8sf)
                _mm256_setzero_ps (),
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_broadcast_f32x4(__m128 __A)
{
  return (__m256)__builtin_shufflevector((__v4sf)__A, (__v4sf)__A,
                                         0, 1, 2, 3, 0, 1, 2, 3);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_broadcast_f32x4(__m256 __O, __mmask8 __M, __m128 __A)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__M,
                                            (__v8sf)_mm256_broadcast_f32x4(__A),
                                            (__v8sf)__O);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_broadcast_f32x4 (__mmask8 __M, __m128 __A)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__M,
                                            (__v8sf)_mm256_broadcast_f32x4(__A),
                                            (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcast_i32x4(__m128i __A)
{
  return (__m256i)__builtin_shufflevector((__v4si)__A, (__v4si)__A,
                                          0, 1, 2, 3, 0, 1, 2, 3);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_broadcast_i32x4(__m256i __O, __mmask8 __M, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                            (__v8si)_mm256_broadcast_i32x4(__A),
                                            (__v8si)__O);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_broadcast_i32x4(__mmask8 __M, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256((__mmask8)__M,
                                            (__v8si)_mm256_broadcast_i32x4(__A),
                                            (__v8si)_mm256_setzero_si256());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_broadcastsd_pd (__m256d __O, __mmask8 __M, __m128d __A)
{
  return (__m256d)__builtin_ia32_selectpd_256(__M,
                                              (__v4df) _mm256_broadcastsd_pd(__A),
                                              (__v4df) __O);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_broadcastsd_pd (__mmask8 __M, __m128d __A)
{
  return (__m256d)__builtin_ia32_selectpd_256(__M,
                                              (__v4df) _mm256_broadcastsd_pd(__A),
                                              (__v4df) _mm256_setzero_pd());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_broadcastss_ps (__m128 __O, __mmask8 __M, __m128 __A)
{
  return (__m128)__builtin_ia32_selectps_128(__M,
                                             (__v4sf) _mm_broadcastss_ps(__A),
                                             (__v4sf) __O);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_broadcastss_ps (__mmask8 __M, __m128 __A)
{
  return (__m128)__builtin_ia32_selectps_128(__M,
                                             (__v4sf) _mm_broadcastss_ps(__A),
                                             (__v4sf) _mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_broadcastss_ps (__m256 __O, __mmask8 __M, __m128 __A)
{
  return (__m256)__builtin_ia32_selectps_256(__M,
                                             (__v8sf) _mm256_broadcastss_ps(__A),
                                             (__v8sf) __O);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_broadcastss_ps (__mmask8 __M, __m128 __A)
{
  return (__m256)__builtin_ia32_selectps_256(__M,
                                             (__v8sf) _mm256_broadcastss_ps(__A),
                                             (__v8sf) _mm256_setzero_ps());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_broadcastd_epi32 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128(__M,
                                             (__v4si) _mm_broadcastd_epi32(__A),
                                             (__v4si) __O);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_broadcastd_epi32 (__mmask8 __M, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectd_128(__M,
                                             (__v4si) _mm_broadcastd_epi32(__A),
                                             (__v4si) _mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_broadcastd_epi32 (__m256i __O, __mmask8 __M, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256(__M,
                                             (__v8si) _mm256_broadcastd_epi32(__A),
                                             (__v8si) __O);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_broadcastd_epi32 (__mmask8 __M, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectd_256(__M,
                                             (__v8si) _mm256_broadcastd_epi32(__A),
                                             (__v8si) _mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_broadcastq_epi64 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128(__M,
                                             (__v2di) _mm_broadcastq_epi64(__A),
                                             (__v2di) __O);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_broadcastq_epi64 (__mmask8 __M, __m128i __A)
{
  return (__m128i)__builtin_ia32_selectq_128(__M,
                                             (__v2di) _mm_broadcastq_epi64(__A),
                                             (__v2di) _mm_setzero_si128());
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_broadcastq_epi64 (__m256i __O, __mmask8 __M, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256(__M,
                                             (__v4di) _mm256_broadcastq_epi64(__A),
                                             (__v4di) __O);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_broadcastq_epi64 (__mmask8 __M, __m128i __A)
{
  return (__m256i)__builtin_ia32_selectq_256(__M,
                                             (__v4di) _mm256_broadcastq_epi64(__A),
                                             (__v4di) _mm256_setzero_si256());
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtsepi32_epi8 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsdb128_mask ((__v4si) __A,
               (__v16qi)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi32_epi8 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsdb128_mask ((__v4si) __A,
               (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtsepi32_epi8 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsdb128_mask ((__v4si) __A,
               (__v16qi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi32_storeu_epi8 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovsdb128mem_mask ((__v16qi *) __P, (__v4si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtsepi32_epi8 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsdb256_mask ((__v8si) __A,
               (__v16qi)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi32_epi8 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsdb256_mask ((__v8si) __A,
               (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtsepi32_epi8 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsdb256_mask ((__v8si) __A,
               (__v16qi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi32_storeu_epi8 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovsdb256mem_mask ((__v16qi *) __P, (__v8si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtsepi32_epi16 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsdw128_mask ((__v4si) __A,
               (__v8hi)_mm_setzero_si128 (),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi32_epi16 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsdw128_mask ((__v4si) __A,
               (__v8hi)__O,
               __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtsepi32_epi16 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsdw128_mask ((__v4si) __A,
               (__v8hi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi32_storeu_epi16 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovsdw128mem_mask ((__v8hi *) __P, (__v4si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtsepi32_epi16 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsdw256_mask ((__v8si) __A,
               (__v8hi)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi32_epi16 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsdw256_mask ((__v8si) __A,
               (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtsepi32_epi16 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsdw256_mask ((__v8si) __A,
               (__v8hi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi32_storeu_epi16 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovsdw256mem_mask ((__v8hi *) __P, (__v8si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtsepi64_epi8 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqb128_mask ((__v2di) __A,
               (__v16qi)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi64_epi8 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqb128_mask ((__v2di) __A,
               (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtsepi64_epi8 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqb128_mask ((__v2di) __A,
               (__v16qi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi64_storeu_epi8 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovsqb128mem_mask ((__v16qi *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtsepi64_epi8 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqb256_mask ((__v4di) __A,
               (__v16qi)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi64_epi8 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqb256_mask ((__v4di) __A,
               (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtsepi64_epi8 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqb256_mask ((__v4di) __A,
               (__v16qi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi64_storeu_epi8 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovsqb256mem_mask ((__v16qi *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtsepi64_epi32 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqd128_mask ((__v2di) __A,
               (__v4si)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi64_epi32 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqd128_mask ((__v2di) __A,
               (__v4si) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtsepi64_epi32 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqd128_mask ((__v2di) __A,
               (__v4si) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi64_storeu_epi32 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovsqd128mem_mask ((__v4si *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtsepi64_epi32 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqd256_mask ((__v4di) __A,
               (__v4si)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi64_epi32 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqd256_mask ((__v4di) __A,
               (__v4si)__O,
               __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtsepi64_epi32 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqd256_mask ((__v4di) __A,
               (__v4si) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi64_storeu_epi32 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovsqd256mem_mask ((__v4si *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtsepi64_epi16 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqw128_mask ((__v2di) __A,
               (__v8hi)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi64_epi16 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqw128_mask ((__v2di) __A,
               (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtsepi64_epi16 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovsqw128_mask ((__v2di) __A,
               (__v8hi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtsepi64_storeu_epi16 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovsqw128mem_mask ((__v8hi *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtsepi64_epi16 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqw256_mask ((__v4di) __A,
               (__v8hi)_mm_undefined_si128(),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi64_epi16 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqw256_mask ((__v4di) __A,
               (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtsepi64_epi16 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovsqw256_mask ((__v4di) __A,
               (__v8hi) _mm_setzero_si128 (),
               __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtsepi64_storeu_epi16 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovsqw256mem_mask ((__v8hi *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtusepi32_epi8 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusdb128_mask ((__v4si) __A,
                (__v16qi)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi32_epi8 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusdb128_mask ((__v4si) __A,
                (__v16qi) __O,
                __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtusepi32_epi8 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusdb128_mask ((__v4si) __A,
                (__v16qi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi32_storeu_epi8 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovusdb128mem_mask ((__v16qi *) __P, (__v4si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtusepi32_epi8 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusdb256_mask ((__v8si) __A,
                (__v16qi)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi32_epi8 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusdb256_mask ((__v8si) __A,
                (__v16qi) __O,
                __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtusepi32_epi8 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusdb256_mask ((__v8si) __A,
                (__v16qi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi32_storeu_epi8 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovusdb256mem_mask ((__v16qi*) __P, (__v8si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtusepi32_epi16 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusdw128_mask ((__v4si) __A,
                (__v8hi)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi32_epi16 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusdw128_mask ((__v4si) __A,
                (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtusepi32_epi16 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusdw128_mask ((__v4si) __A,
                (__v8hi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi32_storeu_epi16 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovusdw128mem_mask ((__v8hi *) __P, (__v4si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtusepi32_epi16 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusdw256_mask ((__v8si) __A,
                (__v8hi) _mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi32_epi16 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusdw256_mask ((__v8si) __A,
                (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtusepi32_epi16 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusdw256_mask ((__v8si) __A,
                (__v8hi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi32_storeu_epi16 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovusdw256mem_mask ((__v8hi *) __P, (__v8si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtusepi64_epi8 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqb128_mask ((__v2di) __A,
                (__v16qi)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi64_epi8 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqb128_mask ((__v2di) __A,
                (__v16qi) __O,
                __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtusepi64_epi8 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqb128_mask ((__v2di) __A,
                (__v16qi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi64_storeu_epi8 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovusqb128mem_mask ((__v16qi *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtusepi64_epi8 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqb256_mask ((__v4di) __A,
                (__v16qi)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi64_epi8 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqb256_mask ((__v4di) __A,
                (__v16qi) __O,
                __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtusepi64_epi8 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqb256_mask ((__v4di) __A,
                (__v16qi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi64_storeu_epi8 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovusqb256mem_mask ((__v16qi *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtusepi64_epi32 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqd128_mask ((__v2di) __A,
                (__v4si)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi64_epi32 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqd128_mask ((__v2di) __A,
                (__v4si) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtusepi64_epi32 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqd128_mask ((__v2di) __A,
                (__v4si) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi64_storeu_epi32 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovusqd128mem_mask ((__v4si *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtusepi64_epi32 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqd256_mask ((__v4di) __A,
                (__v4si)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi64_epi32 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqd256_mask ((__v4di) __A,
                (__v4si) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtusepi64_epi32 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqd256_mask ((__v4di) __A,
                (__v4si) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi64_storeu_epi32 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovusqd256mem_mask ((__v4si *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtusepi64_epi16 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqw128_mask ((__v2di) __A,
                (__v8hi)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi64_epi16 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqw128_mask ((__v2di) __A,
                (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtusepi64_epi16 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovusqw128_mask ((__v2di) __A,
                (__v8hi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtusepi64_storeu_epi16 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovusqw128mem_mask ((__v8hi *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtusepi64_epi16 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqw256_mask ((__v4di) __A,
                (__v8hi)_mm_undefined_si128(),
                (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi64_epi16 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqw256_mask ((__v4di) __A,
                (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtusepi64_epi16 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovusqw256_mask ((__v4di) __A,
                (__v8hi) _mm_setzero_si128 (),
                __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtusepi64_storeu_epi16 (void * __P, __mmask8 __M, __m256i __A)
{
  return __builtin_ia32_pmovusqw256mem_mask ((__v8hi *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi32_epi8 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovdb128_mask ((__v4si) __A,
              (__v16qi)_mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi32_epi8 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovdb128_mask ((__v4si) __A,
              (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi32_epi8 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovdb128_mask ((__v4si) __A,
              (__v16qi)
              _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtepi32_storeu_epi8 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovdb128mem_mask ((__v16qi *) __P, (__v4si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtepi32_epi8 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovdb256_mask ((__v8si) __A,
              (__v16qi)_mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi32_epi8 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovdb256_mask ((__v8si) __A,
              (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi32_epi8 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovdb256_mask ((__v8si) __A,
              (__v16qi) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi32_storeu_epi8 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovdb256mem_mask ((__v16qi *) __P, (__v8si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi32_epi16 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovdw128_mask ((__v4si) __A,
              (__v8hi) _mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi32_epi16 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovdw128_mask ((__v4si) __A,
              (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi32_epi16 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovdw128_mask ((__v4si) __A,
              (__v8hi) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtepi32_storeu_epi16 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovdw128mem_mask ((__v8hi *) __P, (__v4si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtepi32_epi16 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovdw256_mask ((__v8si) __A,
              (__v8hi)_mm_setzero_si128 (),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi32_epi16 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovdw256_mask ((__v8si) __A,
              (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi32_epi16 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovdw256_mask ((__v8si) __A,
              (__v8hi) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi32_storeu_epi16 (void *  __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovdw256mem_mask ((__v8hi *) __P, (__v8si) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi64_epi8 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqb128_mask ((__v2di) __A,
              (__v16qi) _mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi64_epi8 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqb128_mask ((__v2di) __A,
              (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi64_epi8 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqb128_mask ((__v2di) __A,
              (__v16qi) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtepi64_storeu_epi8 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovqb128mem_mask ((__v16qi *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtepi64_epi8 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqb256_mask ((__v4di) __A,
              (__v16qi) _mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi64_epi8 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqb256_mask ((__v4di) __A,
              (__v16qi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi64_epi8 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqb256_mask ((__v4di) __A,
              (__v16qi) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi64_storeu_epi8 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovqb256mem_mask ((__v16qi *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi64_epi32 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqd128_mask ((__v2di) __A,
              (__v4si)_mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi64_epi32 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqd128_mask ((__v2di) __A,
              (__v4si) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi64_epi32 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqd128_mask ((__v2di) __A,
              (__v4si) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtepi64_storeu_epi32 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovqd128mem_mask ((__v4si *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtepi64_epi32 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqd256_mask ((__v4di) __A,
              (__v4si) _mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi64_epi32 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqd256_mask ((__v4di) __A,
              (__v4si) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi64_epi32 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqd256_mask ((__v4di) __A,
              (__v4si) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi64_storeu_epi32 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovqd256mem_mask ((__v4si *) __P, (__v4di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi64_epi16 (__m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqw128_mask ((__v2di) __A,
              (__v8hi) _mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtepi64_epi16 (__m128i __O, __mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqw128_mask ((__v2di) __A,
              (__v8hi)__O,
              __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtepi64_epi16 (__mmask8 __M, __m128i __A)
{
  return (__m128i) __builtin_ia32_pmovqw128_mask ((__v2di) __A,
              (__v8hi) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_mask_cvtepi64_storeu_epi16 (void * __P, __mmask8 __M, __m128i __A)
{
  __builtin_ia32_pmovqw128mem_mask ((__v8hi *) __P, (__v2di) __A, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_cvtepi64_epi16 (__m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqw256_mask ((__v4di) __A,
              (__v8hi)_mm_undefined_si128(),
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi64_epi16 (__m128i __O, __mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqw256_mask ((__v4di) __A,
              (__v8hi) __O, __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtepi64_epi16 (__mmask8 __M, __m256i __A)
{
  return (__m128i) __builtin_ia32_pmovqw256_mask ((__v4di) __A,
              (__v8hi) _mm_setzero_si128 (),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_mask_cvtepi64_storeu_epi16 (void * __P, __mmask8 __M, __m256i __A)
{
  __builtin_ia32_pmovqw256mem_mask ((__v8hi *) __P, (__v4di) __A, __M);
}

#define _mm256_extractf32x4_ps(A, imm) __extension__ ({ \
  (__m128)__builtin_shufflevector((__v8sf)(__m256)(A),           \
                                  (__v8sf)_mm256_undefined_ps(), \
                                  ((imm) & 1) ? 4 : 0,           \
                                  ((imm) & 1) ? 5 : 1,           \
                                  ((imm) & 1) ? 6 : 2,           \
                                  ((imm) & 1) ? 7 : 3); })

#define _mm256_mask_extractf32x4_ps(W, U, A, imm) __extension__ ({ \
  (__m128)__builtin_ia32_selectps_128((__mmask8)(U), \
                                   (__v4sf)_mm256_extractf32x4_ps((A), (imm)), \
                                   (__v4sf)(W)); })

#define _mm256_maskz_extractf32x4_ps(U, A, imm) __extension__ ({ \
  (__m128)__builtin_ia32_selectps_128((__mmask8)(U), \
                                   (__v4sf)_mm256_extractf32x4_ps((A), (imm)), \
                                   (__v4sf)_mm_setzero_ps()); })

#define _mm256_extracti32x4_epi32(A, imm) __extension__ ({ \
  (__m128i)__builtin_shufflevector((__v8si)(__m256)(A),              \
                                   (__v8si)_mm256_undefined_si256(), \
                                   ((imm) & 1) ? 4 : 0,              \
                                   ((imm) & 1) ? 5 : 1,              \
                                   ((imm) & 1) ? 6 : 2,              \
                                   ((imm) & 1) ? 7 : 3); })

#define _mm256_mask_extracti32x4_epi32(W, U, A, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_selectd_128((__mmask8)(U), \
                                (__v4si)_mm256_extracti32x4_epi32((A), (imm)), \
                                (__v4si)(W)); })

#define _mm256_maskz_extracti32x4_epi32(U, A, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_selectd_128((__mmask8)(U), \
                                (__v4si)_mm256_extracti32x4_epi32((A), (imm)), \
                                (__v4si)_mm_setzero_si128()); })

#define _mm256_insertf32x4(A, B, imm) __extension__ ({ \
  (__m256)__builtin_shufflevector((__v8sf)(A), \
                                  (__v8sf)_mm256_castps128_ps256((__m128)(B)), \
                                  ((imm) & 0x1) ?  0 :  8, \
                                  ((imm) & 0x1) ?  1 :  9, \
                                  ((imm) & 0x1) ?  2 : 10, \
                                  ((imm) & 0x1) ?  3 : 11, \
                                  ((imm) & 0x1) ?  8 :  4, \
                                  ((imm) & 0x1) ?  9 :  5, \
                                  ((imm) & 0x1) ? 10 :  6, \
                                  ((imm) & 0x1) ? 11 :  7); })

#define _mm256_mask_insertf32x4(W, U, A, B, imm) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                  (__v8sf)_mm256_insertf32x4((A), (B), (imm)), \
                                  (__v8sf)(W)); })

#define _mm256_maskz_insertf32x4(U, A, B, imm) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                  (__v8sf)_mm256_insertf32x4((A), (B), (imm)), \
                                  (__v8sf)_mm256_setzero_ps()); })

#define _mm256_inserti32x4(A, B, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v8si)(A), \
                                 (__v8si)_mm256_castsi128_si256((__m128i)(B)), \
                                 ((imm) & 0x1) ?  0 :  8, \
                                 ((imm) & 0x1) ?  1 :  9, \
                                 ((imm) & 0x1) ?  2 : 10, \
                                 ((imm) & 0x1) ?  3 : 11, \
                                 ((imm) & 0x1) ?  8 :  4, \
                                 ((imm) & 0x1) ?  9 :  5, \
                                 ((imm) & 0x1) ? 10 :  6, \
                                 ((imm) & 0x1) ? 11 :  7); })

#define _mm256_mask_inserti32x4(W, U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                  (__v8si)_mm256_inserti32x4((A), (B), (imm)), \
                                  (__v8si)(W)); })

#define _mm256_maskz_inserti32x4(U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                  (__v8si)_mm256_inserti32x4((A), (B), (imm)), \
                                  (__v8si)_mm256_setzero_si256()); })

#define _mm_getmant_pd(A, B, C) __extension__({\
  (__m128d)__builtin_ia32_getmantpd128_mask((__v2df)(__m128d)(A), \
                                            (int)(((C)<<2) | (B)), \
                                            (__v2df)_mm_setzero_pd(), \
                                            (__mmask8)-1); })

#define _mm_mask_getmant_pd(W, U, A, B, C) __extension__({\
  (__m128d)__builtin_ia32_getmantpd128_mask((__v2df)(__m128d)(A), \
                                            (int)(((C)<<2) | (B)), \
                                            (__v2df)(__m128d)(W), \
                                            (__mmask8)(U)); })

#define _mm_maskz_getmant_pd(U, A, B, C) __extension__({\
  (__m128d)__builtin_ia32_getmantpd128_mask((__v2df)(__m128d)(A), \
                                            (int)(((C)<<2) | (B)), \
                                            (__v2df)_mm_setzero_pd(), \
                                            (__mmask8)(U)); })

#define _mm256_getmant_pd(A, B, C) __extension__ ({ \
  (__m256d)__builtin_ia32_getmantpd256_mask((__v4df)(__m256d)(A), \
                                            (int)(((C)<<2) | (B)), \
                                            (__v4df)_mm256_setzero_pd(), \
                                            (__mmask8)-1); })

#define _mm256_mask_getmant_pd(W, U, A, B, C) __extension__ ({ \
  (__m256d)__builtin_ia32_getmantpd256_mask((__v4df)(__m256d)(A), \
                                            (int)(((C)<<2) | (B)), \
                                            (__v4df)(__m256d)(W), \
                                            (__mmask8)(U)); })

#define _mm256_maskz_getmant_pd(U, A, B, C) __extension__ ({ \
  (__m256d)__builtin_ia32_getmantpd256_mask((__v4df)(__m256d)(A), \
                                            (int)(((C)<<2) | (B)), \
                                            (__v4df)_mm256_setzero_pd(), \
                                            (__mmask8)(U)); })

#define _mm_getmant_ps(A, B, C) __extension__ ({ \
  (__m128)__builtin_ia32_getmantps128_mask((__v4sf)(__m128)(A), \
                                           (int)(((C)<<2) | (B)), \
                                           (__v4sf)_mm_setzero_ps(), \
                                           (__mmask8)-1); })

#define _mm_mask_getmant_ps(W, U, A, B, C) __extension__ ({ \
  (__m128)__builtin_ia32_getmantps128_mask((__v4sf)(__m128)(A), \
                                           (int)(((C)<<2) | (B)), \
                                           (__v4sf)(__m128)(W), \
                                           (__mmask8)(U)); })

#define _mm_maskz_getmant_ps(U, A, B, C) __extension__ ({ \
  (__m128)__builtin_ia32_getmantps128_mask((__v4sf)(__m128)(A), \
                                           (int)(((C)<<2) | (B)), \
                                           (__v4sf)_mm_setzero_ps(), \
                                           (__mmask8)(U)); })

#define _mm256_getmant_ps(A, B, C) __extension__ ({ \
  (__m256)__builtin_ia32_getmantps256_mask((__v8sf)(__m256)(A), \
                                           (int)(((C)<<2) | (B)), \
                                           (__v8sf)_mm256_setzero_ps(), \
                                           (__mmask8)-1); })

#define _mm256_mask_getmant_ps(W, U, A, B, C) __extension__ ({ \
  (__m256)__builtin_ia32_getmantps256_mask((__v8sf)(__m256)(A), \
                                           (int)(((C)<<2) | (B)), \
                                           (__v8sf)(__m256)(W), \
                                           (__mmask8)(U)); })

#define _mm256_maskz_getmant_ps(U, A, B, C) __extension__ ({ \
  (__m256)__builtin_ia32_getmantps256_mask((__v8sf)(__m256)(A), \
                                           (int)(((C)<<2) | (B)), \
                                           (__v8sf)_mm256_setzero_ps(), \
                                           (__mmask8)(U)); })

#define _mm_mmask_i64gather_pd(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128d)__builtin_ia32_gather3div2df((__v2df)(__m128d)(v1_old), \
                                        (double const *)(addr), \
                                        (__v2di)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm_mmask_i64gather_epi64(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128i)__builtin_ia32_gather3div2di((__v2di)(__m128i)(v1_old), \
                                        (long long const *)(addr), \
                                        (__v2di)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i64gather_pd(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m256d)__builtin_ia32_gather3div4df((__v4df)(__m256d)(v1_old), \
                                        (double const *)(addr), \
                                        (__v4di)(__m256i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i64gather_epi64(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m256i)__builtin_ia32_gather3div4di((__v4di)(__m256i)(v1_old), \
                                        (long long const *)(addr), \
                                        (__v4di)(__m256i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm_mmask_i64gather_ps(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128)__builtin_ia32_gather3div4sf((__v4sf)(__m128)(v1_old), \
                                       (float const *)(addr), \
                                       (__v2di)(__m128i)(index), \
                                       (__mmask8)(mask), (int)(scale)); })

#define _mm_mmask_i64gather_epi32(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128i)__builtin_ia32_gather3div4si((__v4si)(__m128i)(v1_old), \
                                        (int const *)(addr), \
                                        (__v2di)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i64gather_ps(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128)__builtin_ia32_gather3div8sf((__v4sf)(__m128)(v1_old), \
                                       (float const *)(addr), \
                                       (__v4di)(__m256i)(index), \
                                       (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i64gather_epi32(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128i)__builtin_ia32_gather3div8si((__v4si)(__m128i)(v1_old), \
                                        (int const *)(addr), \
                                        (__v4di)(__m256i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm_mmask_i32gather_pd(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128d)__builtin_ia32_gather3siv2df((__v2df)(__m128d)(v1_old), \
                                        (double const *)(addr), \
                                        (__v4si)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm_mmask_i32gather_epi64(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128i)__builtin_ia32_gather3siv2di((__v2di)(__m128i)(v1_old), \
                                        (long long const *)(addr), \
                                        (__v4si)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i32gather_pd(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m256d)__builtin_ia32_gather3siv4df((__v4df)(__m256d)(v1_old), \
                                        (double const *)(addr), \
                                        (__v4si)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i32gather_epi64(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m256i)__builtin_ia32_gather3siv4di((__v4di)(__m256i)(v1_old), \
                                        (long long const *)(addr), \
                                        (__v4si)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm_mmask_i32gather_ps(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128)__builtin_ia32_gather3siv4sf((__v4sf)(__m128)(v1_old), \
                                       (float const *)(addr), \
                                       (__v4si)(__m128i)(index), \
                                       (__mmask8)(mask), (int)(scale)); })

#define _mm_mmask_i32gather_epi32(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m128i)__builtin_ia32_gather3siv4si((__v4si)(__m128i)(v1_old), \
                                        (int const *)(addr), \
                                        (__v4si)(__m128i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i32gather_ps(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m256)__builtin_ia32_gather3siv8sf((__v8sf)(__m256)(v1_old), \
                                       (float const *)(addr), \
                                       (__v8si)(__m256i)(index), \
                                       (__mmask8)(mask), (int)(scale)); })

#define _mm256_mmask_i32gather_epi32(v1_old, mask, index, addr, scale) __extension__ ({\
  (__m256i)__builtin_ia32_gather3siv8si((__v8si)(__m256i)(v1_old), \
                                        (int const *)(addr), \
                                        (__v8si)(__m256i)(index), \
                                        (__mmask8)(mask), (int)(scale)); })

#define _mm256_permutex_pd(X, C) __extension__ ({ \
  (__m256d)__builtin_shufflevector((__v4df)(__m256d)(X), \
                                   (__v4df)_mm256_undefined_pd(), \
                                   ((C) >> 0) & 0x3, ((C) >> 2) & 0x3, \
                                   ((C) >> 4) & 0x3, ((C) >> 6) & 0x3); })

#define _mm256_mask_permutex_pd(W, U, X, C) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                       (__v4df)_mm256_permutex_pd((X), (C)), \
                                       (__v4df)(__m256d)(W)); })

#define _mm256_maskz_permutex_pd(U, X, C) __extension__ ({ \
  (__m256d)__builtin_ia32_selectpd_256((__mmask8)(U), \
                                       (__v4df)_mm256_permutex_pd((X), (C)), \
                                       (__v4df)_mm256_setzero_pd()); })

#define _mm256_permutex_epi64(X, C) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v4di)(__m256i)(X), \
                                   (__v4di)_mm256_undefined_si256(), \
                                   ((C) >> 0) & 0x3, ((C) >> 2) & 0x3, \
                                   ((C) >> 4) & 0x3, ((C) >> 6) & 0x3); })

#define _mm256_mask_permutex_epi64(W, U, X, C) __extension__ ({ \
  (__m256i)__builtin_ia32_selectq_256((__mmask8)(U), \
                                      (__v4di)_mm256_permutex_epi64((X), (C)), \
                                      (__v4di)(__m256i)(W)); })

#define _mm256_maskz_permutex_epi64(U, X, C) __extension__ ({ \
  (__m256i)__builtin_ia32_selectq_256((__mmask8)(U), \
                                      (__v4di)_mm256_permutex_epi64((X), (C)), \
                                      (__v4di)_mm256_setzero_si256()); })

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_permutexvar_pd (__m256i __X, __m256d __Y)
{
  return (__m256d) __builtin_ia32_permvardf256_mask ((__v4df) __Y,
                 (__v4di) __X,
                 (__v4df) _mm256_undefined_si256 (),
                 (__mmask8) -1);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_permutexvar_pd (__m256d __W, __mmask8 __U, __m256i __X,
          __m256d __Y)
{
  return (__m256d) __builtin_ia32_permvardf256_mask ((__v4df) __Y,
                 (__v4di) __X,
                 (__v4df) __W,
                 (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_permutexvar_pd (__mmask8 __U, __m256i __X, __m256d __Y)
{
  return (__m256d) __builtin_ia32_permvardf256_mask ((__v4df) __Y,
                 (__v4di) __X,
                 (__v4df) _mm256_setzero_pd (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_permutexvar_epi64 (__mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i) __builtin_ia32_permvardi256_mask ((__v4di) __Y,
                 (__v4di) __X,
                 (__v4di) _mm256_setzero_si256 (),
                 (__mmask8) __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_permutexvar_epi64 ( __m256i __X, __m256i __Y)
{
  return (__m256i) __builtin_ia32_permvardi256_mask ((__v4di) __Y,
                 (__v4di) __X,
                 (__v4di) _mm256_undefined_si256 (),
                 (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_permutexvar_epi64 (__m256i __W, __mmask8 __M, __m256i __X,
             __m256i __Y)
{
  return (__m256i) __builtin_ia32_permvardi256_mask ((__v4di) __Y,
                 (__v4di) __X,
                 (__v4di) __W,
                 __M);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_permutexvar_ps (__m256 __W, __mmask8 __U, __m256i __X,
          __m256 __Y)
{
  return (__m256) __builtin_ia32_permvarsf256_mask ((__v8sf) __Y,
                (__v8si) __X,
                (__v8sf) __W,
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_permutexvar_ps (__mmask8 __U, __m256i __X, __m256 __Y)
{
  return (__m256) __builtin_ia32_permvarsf256_mask ((__v8sf) __Y,
                (__v8si) __X,
                (__v8sf) _mm256_setzero_ps (),
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_permutexvar_ps (__m256i __X, __m256 __Y)
{
  return (__m256) __builtin_ia32_permvarsf256_mask ((__v8sf) __Y,
                (__v8si) __X,
                (__v8sf) _mm256_undefined_si256 (),
                (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_permutexvar_epi32 (__mmask8 __M, __m256i __X, __m256i __Y)
{
  return (__m256i) __builtin_ia32_permvarsi256_mask ((__v8si) __Y,
                 (__v8si) __X,
                 (__v8si) _mm256_setzero_si256 (),
                 __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_permutexvar_epi32 (__m256i __W, __mmask8 __M, __m256i __X,
             __m256i __Y)
{
  return (__m256i) __builtin_ia32_permvarsi256_mask ((__v8si) __Y,
                 (__v8si) __X,
                 (__v8si) __W,
                 (__mmask8) __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_permutexvar_epi32 (__m256i __X, __m256i __Y)
{
  return (__m256i) __builtin_ia32_permvarsi256_mask ((__v8si) __Y,
                 (__v8si) __X,
                 (__v8si) _mm256_undefined_si256(),
                 (__mmask8) -1);
}

#define _mm_alignr_epi32(A, B, imm) __extension__ ({ \
  (__m128i)__builtin_shufflevector((__v4si)(__m128i)(B), \
                                   (__v4si)(__m128i)(A), \
                                   ((int)(imm) & 0x3) + 0, \
                                   ((int)(imm) & 0x3) + 1, \
                                   ((int)(imm) & 0x3) + 2, \
                                   ((int)(imm) & 0x3) + 3); })

#define _mm_mask_alignr_epi32(W, U, A, B, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_selectd_128((__mmask8)(U), \
                                    (__v4si)_mm_alignr_epi32((A), (B), (imm)), \
                                    (__v4si)(__m128i)(W)); })

#define _mm_maskz_alignr_epi32(U, A, B, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_selectd_128((__mmask8)(U), \
                                    (__v4si)_mm_alignr_epi32((A), (B), (imm)), \
                                    (__v4si)_mm_setzero_si128()); })

#define _mm256_alignr_epi32(A, B, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v8si)(__m256i)(B), \
                                   (__v8si)(__m256i)(A), \
                                   ((int)(imm) & 0x7) + 0, \
                                   ((int)(imm) & 0x7) + 1, \
                                   ((int)(imm) & 0x7) + 2, \
                                   ((int)(imm) & 0x7) + 3, \
                                   ((int)(imm) & 0x7) + 4, \
                                   ((int)(imm) & 0x7) + 5, \
                                   ((int)(imm) & 0x7) + 6, \
                                   ((int)(imm) & 0x7) + 7); })

#define _mm256_mask_alignr_epi32(W, U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                 (__v8si)_mm256_alignr_epi32((A), (B), (imm)), \
                                 (__v8si)(__m256i)(W)); })

#define _mm256_maskz_alignr_epi32(U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                 (__v8si)_mm256_alignr_epi32((A), (B), (imm)), \
                                 (__v8si)_mm256_setzero_si256()); })

#define _mm_alignr_epi64(A, B, imm) __extension__ ({ \
  (__m128i)__builtin_shufflevector((__v2di)(__m128i)(B), \
                                   (__v2di)(__m128i)(A), \
                                   ((int)(imm) & 0x1) + 0, \
                                   ((int)(imm) & 0x1) + 1); })

#define _mm_mask_alignr_epi64(W, U, A, B, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_selectq_128((__mmask8)(U), \
                                    (__v2di)_mm_alignr_epi64((A), (B), (imm)), \
                                    (__v2di)(__m128i)(W)); })

#define _mm_maskz_alignr_epi64(U, A, B, imm) __extension__ ({ \
  (__m128i)__builtin_ia32_selectq_128((__mmask8)(U), \
                                    (__v2di)_mm_alignr_epi64((A), (B), (imm)), \
                                    (__v2di)_mm_setzero_di()); })

#define _mm256_alignr_epi64(A, B, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v4di)(__m256i)(B), \
                                   (__v4di)(__m256i)(A), \
                                   ((int)(imm) & 0x3) + 0, \
                                   ((int)(imm) & 0x3) + 1, \
                                   ((int)(imm) & 0x3) + 2, \
                                   ((int)(imm) & 0x3) + 3); })

#define _mm256_mask_alignr_epi64(W, U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectq_256((__mmask8)(U), \
                                 (__v4di)_mm256_alignr_epi64((A), (B), (imm)), \
                                 (__v4di)(__m256i)(W)); })

#define _mm256_maskz_alignr_epi64(U, A, B, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectq_256((__mmask8)(U), \
                                 (__v4di)_mm256_alignr_epi64((A), (B), (imm)), \
                                 (__v4di)_mm256_setzero_si256()); })

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_movehdup_ps (__m128 __W, __mmask8 __U, __m128 __A)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_movehdup_ps(__A),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_movehdup_ps (__mmask8 __U, __m128 __A)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_movehdup_ps(__A),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_movehdup_ps (__m256 __W, __mmask8 __U, __m256 __A)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_movehdup_ps(__A),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_movehdup_ps (__mmask8 __U, __m256 __A)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_movehdup_ps(__A),
                                             (__v8sf)_mm256_setzero_ps());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_moveldup_ps (__m128 __W, __mmask8 __U, __m128 __A)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_moveldup_ps(__A),
                                             (__v4sf)__W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_moveldup_ps (__mmask8 __U, __m128 __A)
{
  return (__m128)__builtin_ia32_selectps_128((__mmask8)__U,
                                             (__v4sf)_mm_moveldup_ps(__A),
                                             (__v4sf)_mm_setzero_ps());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_moveldup_ps (__m256 __W, __mmask8 __U, __m256 __A)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_moveldup_ps(__A),
                                             (__v8sf)__W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_moveldup_ps (__mmask8 __U, __m256 __A)
{
  return (__m256)__builtin_ia32_selectps_256((__mmask8)__U,
                                             (__v8sf)_mm256_moveldup_ps(__A),
                                             (__v8sf)_mm256_setzero_ps());
}

#define _mm256_mask_shuffle_epi32(W, U, A, I) __extension__({\
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                      (__v8si)_mm256_shuffle_epi32((A), (I)), \
                                      (__v8si)(__m256i)(W)); })

#define _mm256_maskz_shuffle_epi32(U, A, I) __extension__({\
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                      (__v8si)_mm256_shuffle_epi32((A), (I)), \
                                      (__v8si)_mm256_setzero_si256()); })

#define _mm_mask_shuffle_epi32(W, U, A, I) __extension__({\
  (__m128i)__builtin_ia32_selectd_128((__mmask8)(U), \
                                      (__v4si)_mm_shuffle_epi32((A), (I)), \
                                      (__v4si)(__m128i)(W)); })

#define _mm_maskz_shuffle_epi32(U, A, I) __extension__({\
  (__m128i)__builtin_ia32_selectd_128((__mmask8)(U), \
                                      (__v4si)_mm_shuffle_epi32((A), (I)), \
                                      (__v4si)_mm_setzero_si128()); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_mov_pd (__m128d __W, __mmask8 __U, __m128d __A)
{
  return (__m128d) __builtin_ia32_selectpd_128 ((__mmask8) __U,
              (__v2df) __A,
              (__v2df) __W);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_mov_pd (__mmask8 __U, __m128d __A)
{
  return (__m128d) __builtin_ia32_selectpd_128 ((__mmask8) __U,
              (__v2df) __A,
              (__v2df) _mm_setzero_pd ());
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_mov_pd (__m256d __W, __mmask8 __U, __m256d __A)
{
  return (__m256d) __builtin_ia32_selectpd_256 ((__mmask8) __U,
              (__v4df) __A,
              (__v4df) __W);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_mov_pd (__mmask8 __U, __m256d __A)
{
  return (__m256d) __builtin_ia32_selectpd_256 ((__mmask8) __U,
              (__v4df) __A,
              (__v4df) _mm256_setzero_pd ());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_mov_ps (__m128 __W, __mmask8 __U, __m128 __A)
{
  return (__m128) __builtin_ia32_selectps_128 ((__mmask8) __U,
             (__v4sf) __A,
             (__v4sf) __W);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_mov_ps (__mmask8 __U, __m128 __A)
{
  return (__m128) __builtin_ia32_selectps_128 ((__mmask8) __U,
             (__v4sf) __A,
             (__v4sf) _mm_setzero_ps ());
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_mov_ps (__m256 __W, __mmask8 __U, __m256 __A)
{
  return (__m256) __builtin_ia32_selectps_256 ((__mmask8) __U,
             (__v8sf) __A,
             (__v8sf) __W);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_mov_ps (__mmask8 __U, __m256 __A)
{
  return (__m256) __builtin_ia32_selectps_256 ((__mmask8) __U,
             (__v8sf) __A,
             (__v8sf) _mm256_setzero_ps ());
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_cvtph_ps (__m128 __W, __mmask8 __U, __m128i __A)
{
  return (__m128) __builtin_ia32_vcvtph2ps_mask ((__v8hi) __A,
             (__v4sf) __W,
             (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_cvtph_ps (__mmask8 __U, __m128i __A)
{
  return (__m128) __builtin_ia32_vcvtph2ps_mask ((__v8hi) __A,
             (__v4sf)
             _mm_setzero_ps (),
             (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_cvtph_ps (__m256 __W, __mmask8 __U, __m128i __A)
{
  return (__m256) __builtin_ia32_vcvtph2ps256_mask ((__v8hi) __A,
                (__v8sf) __W,
                (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_cvtph_ps (__mmask8 __U, __m128i __A)
{
  return (__m256) __builtin_ia32_vcvtph2ps256_mask ((__v8hi) __A,
                (__v8sf)
                _mm256_setzero_ps (),
                (__mmask8) __U);
}

static __inline __m128i __DEFAULT_FN_ATTRS
_mm_mask_cvtps_ph (__m128i __W, __mmask8 __U, __m128 __A)
{
  return (__m128i) __builtin_ia32_vcvtps2ph_mask ((__v4sf) __A, _MM_FROUND_CUR_DIRECTION,
                                                  (__v8hi) __W,
                                                  (__mmask8) __U);
}

static __inline __m128i __DEFAULT_FN_ATTRS
_mm_maskz_cvtps_ph (__mmask8 __U, __m128 __A)
{
  return (__m128i) __builtin_ia32_vcvtps2ph_mask ((__v4sf) __A, _MM_FROUND_CUR_DIRECTION,
                                                  (__v8hi) _mm_setzero_si128 (),
                                                  (__mmask8) __U);
}

#define _mm_mask_cvt_roundps_ph(W, U, A, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vcvtps2ph_mask((__v4sf)(__m128)(A), (int)(I), \
                                         (__v8hi)(__m128i)(W), \
                                         (__mmask8)(U)); })

#define _mm_maskz_cvt_roundps_ph(U, A, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vcvtps2ph_mask((__v4sf)(__m128)(A), (int)(I), \
                                         (__v8hi)_mm_setzero_si128(), \
                                         (__mmask8)(U)); })

static __inline __m128i __DEFAULT_FN_ATTRS
_mm256_mask_cvtps_ph (__m128i __W, __mmask8 __U, __m256 __A)
{
  return (__m128i) __builtin_ia32_vcvtps2ph256_mask ((__v8sf) __A, _MM_FROUND_CUR_DIRECTION,
                                                      (__v8hi) __W,
                                                      (__mmask8) __U);
}

static __inline __m128i __DEFAULT_FN_ATTRS
_mm256_maskz_cvtps_ph ( __mmask8 __U, __m256 __A)
{
  return (__m128i) __builtin_ia32_vcvtps2ph256_mask ((__v8sf) __A, _MM_FROUND_CUR_DIRECTION,
                                                      (__v8hi) _mm_setzero_si128(),
                                                      (__mmask8) __U);
}
#define _mm256_mask_cvt_roundps_ph(W, U, A, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vcvtps2ph256_mask((__v8sf)(__m256)(A), (int)(I), \
                                            (__v8hi)(__m128i)(W), \
                                            (__mmask8)(U)); })

#define _mm256_maskz_cvt_roundps_ph(U, A, I) __extension__ ({ \
  (__m128i)__builtin_ia32_vcvtps2ph256_mask((__v8sf)(__m256)(A), (int)(I), \
                                            (__v8hi)_mm_setzero_si128(), \
                                            (__mmask8)(U)); })


#undef __DEFAULT_FN_ATTRS

#endif /* __AVX512VLINTRIN_H */
