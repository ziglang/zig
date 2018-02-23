/*===------------- avx512bwintrin.h - AVX512BW intrinsics ------------------===
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
#error "Never use <avx512bwintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512BWINTRIN_H
#define __AVX512BWINTRIN_H

typedef unsigned int __mmask32;
typedef unsigned long long __mmask64;

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512bw")))

static  __inline __m512i __DEFAULT_FN_ATTRS
_mm512_setzero_qi(void) {
  return (__m512i)(__v64qi){ 0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0 };
}

static  __inline __m512i __DEFAULT_FN_ATTRS
_mm512_setzero_hi(void) {
  return (__m512i)(__v32hi){ 0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0,
                             0, 0, 0, 0, 0, 0, 0, 0 };
}

/* Integer compare */

#define _mm512_cmp_epi8_mask(a, b, p) __extension__ ({ \
  (__mmask64)__builtin_ia32_cmpb512_mask((__v64qi)(__m512i)(a), \
                                         (__v64qi)(__m512i)(b), (int)(p), \
                                         (__mmask64)-1); })

#define _mm512_mask_cmp_epi8_mask(m, a, b, p) __extension__ ({ \
  (__mmask64)__builtin_ia32_cmpb512_mask((__v64qi)(__m512i)(a), \
                                         (__v64qi)(__m512i)(b), (int)(p), \
                                         (__mmask64)(m)); })

#define _mm512_cmp_epu8_mask(a, b, p) __extension__ ({ \
  (__mmask64)__builtin_ia32_ucmpb512_mask((__v64qi)(__m512i)(a), \
                                          (__v64qi)(__m512i)(b), (int)(p), \
                                          (__mmask64)-1); })

#define _mm512_mask_cmp_epu8_mask(m, a, b, p) __extension__ ({ \
  (__mmask64)__builtin_ia32_ucmpb512_mask((__v64qi)(__m512i)(a), \
                                          (__v64qi)(__m512i)(b), (int)(p), \
                                          (__mmask64)(m)); })

#define _mm512_cmp_epi16_mask(a, b, p) __extension__ ({ \
  (__mmask32)__builtin_ia32_cmpw512_mask((__v32hi)(__m512i)(a), \
                                         (__v32hi)(__m512i)(b), (int)(p), \
                                         (__mmask32)-1); })

#define _mm512_mask_cmp_epi16_mask(m, a, b, p) __extension__ ({ \
  (__mmask32)__builtin_ia32_cmpw512_mask((__v32hi)(__m512i)(a), \
                                         (__v32hi)(__m512i)(b), (int)(p), \
                                         (__mmask32)(m)); })

#define _mm512_cmp_epu16_mask(a, b, p) __extension__ ({ \
  (__mmask32)__builtin_ia32_ucmpw512_mask((__v32hi)(__m512i)(a), \
                                          (__v32hi)(__m512i)(b), (int)(p), \
                                          (__mmask32)-1); })

#define _mm512_mask_cmp_epu16_mask(m, a, b, p) __extension__ ({ \
  (__mmask32)__builtin_ia32_ucmpw512_mask((__v32hi)(__m512i)(a), \
                                          (__v32hi)(__m512i)(b), (int)(p), \
                                          (__mmask32)(m)); })

#define _mm512_cmpeq_epi8_mask(A, B) \
    _mm512_cmp_epi8_mask((A), (B), _MM_CMPINT_EQ)
#define _mm512_mask_cmpeq_epi8_mask(k, A, B) \
    _mm512_mask_cmp_epi8_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm512_cmpge_epi8_mask(A, B) \
    _mm512_cmp_epi8_mask((A), (B), _MM_CMPINT_GE)
#define _mm512_mask_cmpge_epi8_mask(k, A, B) \
    _mm512_mask_cmp_epi8_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm512_cmpgt_epi8_mask(A, B) \
    _mm512_cmp_epi8_mask((A), (B), _MM_CMPINT_GT)
#define _mm512_mask_cmpgt_epi8_mask(k, A, B) \
    _mm512_mask_cmp_epi8_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm512_cmple_epi8_mask(A, B) \
    _mm512_cmp_epi8_mask((A), (B), _MM_CMPINT_LE)
#define _mm512_mask_cmple_epi8_mask(k, A, B) \
    _mm512_mask_cmp_epi8_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm512_cmplt_epi8_mask(A, B) \
    _mm512_cmp_epi8_mask((A), (B), _MM_CMPINT_LT)
#define _mm512_mask_cmplt_epi8_mask(k, A, B) \
    _mm512_mask_cmp_epi8_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm512_cmpneq_epi8_mask(A, B) \
    _mm512_cmp_epi8_mask((A), (B), _MM_CMPINT_NE)
#define _mm512_mask_cmpneq_epi8_mask(k, A, B) \
    _mm512_mask_cmp_epi8_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm512_cmpeq_epu8_mask(A, B) \
    _mm512_cmp_epu8_mask((A), (B), _MM_CMPINT_EQ)
#define _mm512_mask_cmpeq_epu8_mask(k, A, B) \
    _mm512_mask_cmp_epu8_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm512_cmpge_epu8_mask(A, B) \
    _mm512_cmp_epu8_mask((A), (B), _MM_CMPINT_GE)
#define _mm512_mask_cmpge_epu8_mask(k, A, B) \
    _mm512_mask_cmp_epu8_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm512_cmpgt_epu8_mask(A, B) \
    _mm512_cmp_epu8_mask((A), (B), _MM_CMPINT_GT)
#define _mm512_mask_cmpgt_epu8_mask(k, A, B) \
    _mm512_mask_cmp_epu8_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm512_cmple_epu8_mask(A, B) \
    _mm512_cmp_epu8_mask((A), (B), _MM_CMPINT_LE)
#define _mm512_mask_cmple_epu8_mask(k, A, B) \
    _mm512_mask_cmp_epu8_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm512_cmplt_epu8_mask(A, B) \
    _mm512_cmp_epu8_mask((A), (B), _MM_CMPINT_LT)
#define _mm512_mask_cmplt_epu8_mask(k, A, B) \
    _mm512_mask_cmp_epu8_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm512_cmpneq_epu8_mask(A, B) \
    _mm512_cmp_epu8_mask((A), (B), _MM_CMPINT_NE)
#define _mm512_mask_cmpneq_epu8_mask(k, A, B) \
    _mm512_mask_cmp_epu8_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm512_cmpeq_epi16_mask(A, B) \
    _mm512_cmp_epi16_mask((A), (B), _MM_CMPINT_EQ)
#define _mm512_mask_cmpeq_epi16_mask(k, A, B) \
    _mm512_mask_cmp_epi16_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm512_cmpge_epi16_mask(A, B) \
    _mm512_cmp_epi16_mask((A), (B), _MM_CMPINT_GE)
#define _mm512_mask_cmpge_epi16_mask(k, A, B) \
    _mm512_mask_cmp_epi16_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm512_cmpgt_epi16_mask(A, B) \
    _mm512_cmp_epi16_mask((A), (B), _MM_CMPINT_GT)
#define _mm512_mask_cmpgt_epi16_mask(k, A, B) \
    _mm512_mask_cmp_epi16_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm512_cmple_epi16_mask(A, B) \
    _mm512_cmp_epi16_mask((A), (B), _MM_CMPINT_LE)
#define _mm512_mask_cmple_epi16_mask(k, A, B) \
    _mm512_mask_cmp_epi16_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm512_cmplt_epi16_mask(A, B) \
    _mm512_cmp_epi16_mask((A), (B), _MM_CMPINT_LT)
#define _mm512_mask_cmplt_epi16_mask(k, A, B) \
    _mm512_mask_cmp_epi16_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm512_cmpneq_epi16_mask(A, B) \
    _mm512_cmp_epi16_mask((A), (B), _MM_CMPINT_NE)
#define _mm512_mask_cmpneq_epi16_mask(k, A, B) \
    _mm512_mask_cmp_epi16_mask((k), (A), (B), _MM_CMPINT_NE)

#define _mm512_cmpeq_epu16_mask(A, B) \
    _mm512_cmp_epu16_mask((A), (B), _MM_CMPINT_EQ)
#define _mm512_mask_cmpeq_epu16_mask(k, A, B) \
    _mm512_mask_cmp_epu16_mask((k), (A), (B), _MM_CMPINT_EQ)
#define _mm512_cmpge_epu16_mask(A, B) \
    _mm512_cmp_epu16_mask((A), (B), _MM_CMPINT_GE)
#define _mm512_mask_cmpge_epu16_mask(k, A, B) \
    _mm512_mask_cmp_epu16_mask((k), (A), (B), _MM_CMPINT_GE)
#define _mm512_cmpgt_epu16_mask(A, B) \
    _mm512_cmp_epu16_mask((A), (B), _MM_CMPINT_GT)
#define _mm512_mask_cmpgt_epu16_mask(k, A, B) \
    _mm512_mask_cmp_epu16_mask((k), (A), (B), _MM_CMPINT_GT)
#define _mm512_cmple_epu16_mask(A, B) \
    _mm512_cmp_epu16_mask((A), (B), _MM_CMPINT_LE)
#define _mm512_mask_cmple_epu16_mask(k, A, B) \
    _mm512_mask_cmp_epu16_mask((k), (A), (B), _MM_CMPINT_LE)
#define _mm512_cmplt_epu16_mask(A, B) \
    _mm512_cmp_epu16_mask((A), (B), _MM_CMPINT_LT)
#define _mm512_mask_cmplt_epu16_mask(k, A, B) \
    _mm512_mask_cmp_epu16_mask((k), (A), (B), _MM_CMPINT_LT)
#define _mm512_cmpneq_epu16_mask(A, B) \
    _mm512_cmp_epu16_mask((A), (B), _MM_CMPINT_NE)
#define _mm512_mask_cmpneq_epu16_mask(k, A, B) \
    _mm512_mask_cmp_epu16_mask((k), (A), (B), _MM_CMPINT_NE)

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_add_epi8 (__m512i __A, __m512i __B) {
  return (__m512i) ((__v64qu) __A + (__v64qu) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_add_epi8(__m512i __W, __mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                             (__v64qi)_mm512_add_epi8(__A, __B),
                                             (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_add_epi8(__mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                             (__v64qi)_mm512_add_epi8(__A, __B),
                                             (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_sub_epi8 (__m512i __A, __m512i __B) {
  return (__m512i) ((__v64qu) __A - (__v64qu) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_sub_epi8(__m512i __W, __mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                             (__v64qi)_mm512_sub_epi8(__A, __B),
                                             (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_sub_epi8(__mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                             (__v64qi)_mm512_sub_epi8(__A, __B),
                                             (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_add_epi16 (__m512i __A, __m512i __B) {
  return (__m512i) ((__v32hu) __A + (__v32hu) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_add_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_add_epi16(__A, __B),
                                             (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_add_epi16(__mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_add_epi16(__A, __B),
                                             (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_sub_epi16 (__m512i __A, __m512i __B) {
  return (__m512i) ((__v32hu) __A - (__v32hu) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_sub_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_sub_epi16(__A, __B),
                                             (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_sub_epi16(__mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_sub_epi16(__A, __B),
                                             (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mullo_epi16 (__m512i __A, __m512i __B) {
  return (__m512i) ((__v32hu) __A * (__v32hu) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mullo_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_mullo_epi16(__A, __B),
                                             (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mullo_epi16(__mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_mullo_epi16(__A, __B),
                                             (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_blend_epi8 (__mmask64 __U, __m512i __A, __m512i __W)
{
  return (__m512i) __builtin_ia32_selectb_512 ((__mmask64) __U,
              (__v64qi) __W,
              (__v64qi) __A);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_blend_epi16 (__mmask32 __U, __m512i __A, __m512i __W)
{
  return (__m512i) __builtin_ia32_selectw_512 ((__mmask32) __U,
              (__v32hi) __W,
              (__v32hi) __A);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_abs_epi8 (__m512i __A)
{
  return (__m512i) __builtin_ia32_pabsb512_mask ((__v64qi) __A,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_abs_epi8 (__m512i __W, __mmask64 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_pabsb512_mask ((__v64qi) __A,
              (__v64qi) __W,
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_abs_epi8 (__mmask64 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_pabsb512_mask ((__v64qi) __A,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_abs_epi16 (__m512i __A)
{
  return (__m512i) __builtin_ia32_pabsw512_mask ((__v32hi) __A,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_abs_epi16 (__m512i __W, __mmask32 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_pabsw512_mask ((__v32hi) __A,
              (__v32hi) __W,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_abs_epi16 (__mmask32 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_pabsw512_mask ((__v32hi) __A,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_packs_epi32(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_packssdw512((__v16si)__A, (__v16si)__B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_packs_epi32(__mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__M,
                                       (__v32hi)_mm512_packs_epi32(__A, __B),
                                       (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_packs_epi32(__m512i __W, __mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__M,
                                       (__v32hi)_mm512_packs_epi32(__A, __B),
                                       (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_packs_epi16(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_packsswb512((__v32hi)__A, (__v32hi) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_packs_epi16(__m512i __W, __mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__M,
                                        (__v64qi)_mm512_packs_epi16(__A, __B),
                                        (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_packs_epi16(__mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__M,
                                        (__v64qi)_mm512_packs_epi16(__A, __B),
                                        (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_packus_epi32(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_packusdw512((__v16si) __A, (__v16si) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_packus_epi32(__mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__M,
                                       (__v32hi)_mm512_packus_epi32(__A, __B),
                                       (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_packus_epi32(__m512i __W, __mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__M,
                                       (__v32hi)_mm512_packus_epi32(__A, __B),
                                       (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_packus_epi16(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_packuswb512((__v32hi) __A, (__v32hi) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_packus_epi16(__m512i __W, __mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__M,
                                        (__v64qi)_mm512_packus_epi16(__A, __B),
                                        (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_packus_epi16(__mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__M,
                                        (__v64qi)_mm512_packus_epi16(__A, __B),
                                        (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_adds_epi8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_adds_epi8 (__m512i __W, __mmask64 __U, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_paddsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_adds_epi8 (__mmask64 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_adds_epi16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_adds_epi16 (__m512i __W, __mmask32 __U, __m512i __A,
      __m512i __B)
{
  return (__m512i) __builtin_ia32_paddsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_adds_epi16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_adds_epu8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddusb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_adds_epu8 (__m512i __W, __mmask64 __U, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_paddusb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_adds_epu8 (__mmask64 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddusb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_adds_epu16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddusw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_adds_epu16 (__m512i __W, __mmask32 __U, __m512i __A,
      __m512i __B)
{
  return (__m512i) __builtin_ia32_paddusw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_adds_epu16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_paddusw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_avg_epu8 (__m512i __A, __m512i __B)
{
  typedef unsigned short __v64hu __attribute__((__vector_size__(128)));
  return (__m512i)__builtin_convertvector(
              ((__builtin_convertvector((__v64qu) __A, __v64hu) +
                __builtin_convertvector((__v64qu) __B, __v64hu)) + 1)
                >> 1, __v64qu);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_avg_epu8 (__m512i __W, __mmask64 __U, __m512i __A,
          __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
              (__v64qi)_mm512_avg_epu8(__A, __B),
              (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_avg_epu8 (__mmask64 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
              (__v64qi)_mm512_avg_epu8(__A, __B),
              (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_avg_epu16 (__m512i __A, __m512i __B)
{
  typedef unsigned int __v32su __attribute__((__vector_size__(128)));
  return (__m512i)__builtin_convertvector(
              ((__builtin_convertvector((__v32hu) __A, __v32su) +
                __builtin_convertvector((__v32hu) __B, __v32su)) + 1)
                >> 1, __v32hu);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_avg_epu16 (__m512i __W, __mmask32 __U, __m512i __A,
           __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
              (__v32hi)_mm512_avg_epu16(__A, __B),
              (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_avg_epu16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
              (__v32hi)_mm512_avg_epu16(__A, __B),
              (__v32hi) _mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_max_epi8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_max_epi8 (__mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_max_epi8 (__m512i __W, __mmask64 __M, __m512i __A,
          __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_max_epi16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_max_epi16 (__mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_max_epi16 (__m512i __W, __mmask32 __M, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_max_epu8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxub512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_max_epu8 (__mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxub512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_max_epu8 (__m512i __W, __mmask64 __M, __m512i __A,
          __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxub512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_max_epu16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxuw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_max_epu16 (__mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxuw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_max_epu16 (__m512i __W, __mmask32 __M, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_pmaxuw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_min_epi8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_min_epi8 (__mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_min_epi8 (__m512i __W, __mmask64 __M, __m512i __A,
          __m512i __B)
{
  return (__m512i) __builtin_ia32_pminsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_min_epi16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_min_epi16 (__mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_min_epi16 (__m512i __W, __mmask32 __M, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_pminsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_min_epu8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminub512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_min_epu8 (__mmask64 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminub512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_min_epu8 (__m512i __W, __mmask64 __M, __m512i __A,
          __m512i __B)
{
  return (__m512i) __builtin_ia32_pminub512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_min_epu16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminuw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_min_epu16 (__mmask32 __M, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pminuw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_min_epu16 (__m512i __W, __mmask32 __M, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_pminuw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_shuffle_epi8(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_pshufb512((__v64qi)__A,(__v64qi)__B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_shuffle_epi8(__m512i __W, __mmask64 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                         (__v64qi)_mm512_shuffle_epi8(__A, __B),
                                         (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_shuffle_epi8(__mmask64 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                         (__v64qi)_mm512_shuffle_epi8(__A, __B),
                                         (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_subs_epi8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_subs_epi8 (__m512i __W, __mmask64 __U, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_psubsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_subs_epi8 (__mmask64 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubsb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_subs_epi16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_subs_epi16 (__m512i __W, __mmask32 __U, __m512i __A,
      __m512i __B)
{
  return (__m512i) __builtin_ia32_psubsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_subs_epi16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubsw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_subs_epu8 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubusb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_subs_epu8 (__m512i __W, __mmask64 __U, __m512i __A,
           __m512i __B)
{
  return (__m512i) __builtin_ia32_psubusb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) __W,
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_subs_epu8 (__mmask64 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubusb512_mask ((__v64qi) __A,
              (__v64qi) __B,
              (__v64qi) _mm512_setzero_qi(),
              (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_subs_epu16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubusw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_subs_epu16 (__m512i __W, __mmask32 __U, __m512i __A,
      __m512i __B)
{
  return (__m512i) __builtin_ia32_psubusw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_subs_epu16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_psubusw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask2_permutex2var_epi16 (__m512i __A, __m512i __I,
         __mmask32 __U, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpermi2varhi512_mask ((__v32hi) __A,
              (__v32hi) __I /* idx */ ,
              (__v32hi) __B,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_permutex2var_epi16 (__m512i __A, __m512i __I, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpermt2varhi512_mask ((__v32hi) __I /* idx */,
              (__v32hi) __A,
              (__v32hi) __B,
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_permutex2var_epi16 (__m512i __A, __mmask32 __U,
        __m512i __I, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpermt2varhi512_mask ((__v32hi) __I /* idx */,
              (__v32hi) __A,
              (__v32hi) __B,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_permutex2var_epi16 (__mmask32 __U, __m512i __A,
         __m512i __I, __m512i __B)
{
  return (__m512i) __builtin_ia32_vpermt2varhi512_maskz ((__v32hi) __I
              /* idx */ ,
              (__v32hi) __A,
              (__v32hi) __B,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mulhrs_epi16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhrsw512_mask ((__v32hi) __A,
                (__v32hi) __B,
                (__v32hi) _mm512_setzero_hi(),
                (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mulhrs_epi16 (__m512i __W, __mmask32 __U, __m512i __A,
        __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhrsw512_mask ((__v32hi) __A,
                (__v32hi) __B,
                (__v32hi) __W,
                (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mulhrs_epi16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhrsw512_mask ((__v32hi) __A,
                (__v32hi) __B,
                (__v32hi) _mm512_setzero_hi(),
                (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mulhi_epi16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mulhi_epi16 (__m512i __W, __mmask32 __U, __m512i __A,
       __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) __W,
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mulhi_epi16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhw512_mask ((__v32hi) __A,
              (__v32hi) __B,
              (__v32hi) _mm512_setzero_hi(),
              (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mulhi_epu16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhuw512_mask ((__v32hi) __A,
               (__v32hi) __B,
               (__v32hi) _mm512_setzero_hi(),
               (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mulhi_epu16 (__m512i __W, __mmask32 __U, __m512i __A,
       __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhuw512_mask ((__v32hi) __A,
               (__v32hi) __B,
               (__v32hi) __W,
               (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mulhi_epu16 (__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_pmulhuw512_mask ((__v32hi) __A,
               (__v32hi) __B,
               (__v32hi) _mm512_setzero_hi(),
               (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maddubs_epi16 (__m512i __X, __m512i __Y) {
  return (__m512i) __builtin_ia32_pmaddubsw512_mask ((__v64qi) __X,
                 (__v64qi) __Y,
                 (__v32hi) _mm512_setzero_hi(),
                 (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_maddubs_epi16 (__m512i __W, __mmask32 __U, __m512i __X,
         __m512i __Y) {
  return (__m512i) __builtin_ia32_pmaddubsw512_mask ((__v64qi) __X,
                 (__v64qi) __Y,
                 (__v32hi) __W,
                 (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_maddubs_epi16 (__mmask32 __U, __m512i __X, __m512i __Y) {
  return (__m512i) __builtin_ia32_pmaddubsw512_mask ((__v64qi) __X,
                 (__v64qi) __Y,
                 (__v32hi) _mm512_setzero_hi(),
                 (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_madd_epi16 (__m512i __A, __m512i __B) {
  return (__m512i) __builtin_ia32_pmaddwd512_mask ((__v32hi) __A,
               (__v32hi) __B,
               (__v16si) _mm512_setzero_si512(),
               (__mmask16) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_madd_epi16 (__m512i __W, __mmask16 __U, __m512i __A,
      __m512i __B) {
  return (__m512i) __builtin_ia32_pmaddwd512_mask ((__v32hi) __A,
               (__v32hi) __B,
               (__v16si) __W,
               (__mmask16) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_madd_epi16 (__mmask16 __U, __m512i __A, __m512i __B) {
  return (__m512i) __builtin_ia32_pmaddwd512_mask ((__v32hi) __A,
               (__v32hi) __B,
               (__v16si) _mm512_setzero_si512(),
               (__mmask16) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_cvtsepi16_epi8 (__m512i __A) {
  return (__m256i) __builtin_ia32_pmovswb512_mask ((__v32hi) __A,
               (__v32qi)_mm256_setzero_si256(),
               (__mmask32) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_mask_cvtsepi16_epi8 (__m256i __O, __mmask32 __M, __m512i __A) {
  return (__m256i) __builtin_ia32_pmovswb512_mask ((__v32hi) __A,
               (__v32qi)__O,
               __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtsepi16_epi8 (__mmask32 __M, __m512i __A) {
  return (__m256i) __builtin_ia32_pmovswb512_mask ((__v32hi) __A,
               (__v32qi) _mm256_setzero_si256(),
               __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_cvtusepi16_epi8 (__m512i __A) {
  return (__m256i) __builtin_ia32_pmovuswb512_mask ((__v32hi) __A,
                (__v32qi) _mm256_setzero_si256(),
                (__mmask32) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_mask_cvtusepi16_epi8 (__m256i __O, __mmask32 __M, __m512i __A) {
  return (__m256i) __builtin_ia32_pmovuswb512_mask ((__v32hi) __A,
                (__v32qi) __O,
                __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtusepi16_epi8 (__mmask32 __M, __m512i __A) {
  return (__m256i) __builtin_ia32_pmovuswb512_mask ((__v32hi) __A,
                (__v32qi) _mm256_setzero_si256(),
                __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_cvtepi16_epi8 (__m512i __A) {
  return (__m256i) __builtin_ia32_pmovwb512_mask ((__v32hi) __A,
              (__v32qi) _mm256_setzero_si256(),
              (__mmask32) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_mask_cvtepi16_epi8 (__m256i __O, __mmask32 __M, __m512i __A) {
  return (__m256i) __builtin_ia32_pmovwb512_mask ((__v32hi) __A,
              (__v32qi) __O,
              __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtepi16_epi8 (__mmask32 __M, __m512i __A) {
  return (__m256i) __builtin_ia32_pmovwb512_mask ((__v32hi) __A,
              (__v32qi) _mm256_setzero_si256(),
              __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm512_mask_cvtepi16_storeu_epi8 (void * __P, __mmask32 __M, __m512i __A)
{
  __builtin_ia32_pmovwb512mem_mask ((__v32qi *) __P, (__v32hi) __A, __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm512_mask_cvtsepi16_storeu_epi8 (void * __P, __mmask32 __M, __m512i __A)
{
  __builtin_ia32_pmovswb512mem_mask ((__v32qi *) __P, (__v32hi) __A, __M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm512_mask_cvtusepi16_storeu_epi8 (void * __P, __mmask32 __M, __m512i __A)
{
  __builtin_ia32_pmovuswb512mem_mask ((__v32qi *) __P, (__v32hi) __A, __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_unpackhi_epi8(__m512i __A, __m512i __B) {
  return (__m512i)__builtin_shufflevector((__v64qi)__A, (__v64qi)__B,
                                          8,  64+8,   9, 64+9,
                                          10, 64+10, 11, 64+11,
                                          12, 64+12, 13, 64+13,
                                          14, 64+14, 15, 64+15,
                                          24, 64+24, 25, 64+25,
                                          26, 64+26, 27, 64+27,
                                          28, 64+28, 29, 64+29,
                                          30, 64+30, 31, 64+31,
                                          40, 64+40, 41, 64+41,
                                          42, 64+42, 43, 64+43,
                                          44, 64+44, 45, 64+45,
                                          46, 64+46, 47, 64+47,
                                          56, 64+56, 57, 64+57,
                                          58, 64+58, 59, 64+59,
                                          60, 64+60, 61, 64+61,
                                          62, 64+62, 63, 64+63);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_unpackhi_epi8(__m512i __W, __mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                        (__v64qi)_mm512_unpackhi_epi8(__A, __B),
                                        (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_unpackhi_epi8(__mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                        (__v64qi)_mm512_unpackhi_epi8(__A, __B),
                                        (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_unpackhi_epi16(__m512i __A, __m512i __B) {
  return (__m512i)__builtin_shufflevector((__v32hi)__A, (__v32hi)__B,
                                          4,  32+4,   5, 32+5,
                                          6,  32+6,   7, 32+7,
                                          12, 32+12, 13, 32+13,
                                          14, 32+14, 15, 32+15,
                                          20, 32+20, 21, 32+21,
                                          22, 32+22, 23, 32+23,
                                          28, 32+28, 29, 32+29,
                                          30, 32+30, 31, 32+31);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_unpackhi_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                       (__v32hi)_mm512_unpackhi_epi16(__A, __B),
                                       (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_unpackhi_epi16(__mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                       (__v32hi)_mm512_unpackhi_epi16(__A, __B),
                                       (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_unpacklo_epi8(__m512i __A, __m512i __B) {
  return (__m512i)__builtin_shufflevector((__v64qi)__A, (__v64qi)__B,
                                          0,  64+0,   1, 64+1,
                                          2,  64+2,   3, 64+3,
                                          4,  64+4,   5, 64+5,
                                          6,  64+6,   7, 64+7,
                                          16, 64+16, 17, 64+17,
                                          18, 64+18, 19, 64+19,
                                          20, 64+20, 21, 64+21,
                                          22, 64+22, 23, 64+23,
                                          32, 64+32, 33, 64+33,
                                          34, 64+34, 35, 64+35,
                                          36, 64+36, 37, 64+37,
                                          38, 64+38, 39, 64+39,
                                          48, 64+48, 49, 64+49,
                                          50, 64+50, 51, 64+51,
                                          52, 64+52, 53, 64+53,
                                          54, 64+54, 55, 64+55);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_unpacklo_epi8(__m512i __W, __mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                        (__v64qi)_mm512_unpacklo_epi8(__A, __B),
                                        (__v64qi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_unpacklo_epi8(__mmask64 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectb_512((__mmask64)__U,
                                        (__v64qi)_mm512_unpacklo_epi8(__A, __B),
                                        (__v64qi)_mm512_setzero_qi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_unpacklo_epi16(__m512i __A, __m512i __B) {
  return (__m512i)__builtin_shufflevector((__v32hi)__A, (__v32hi)__B,
                                          0,  32+0,   1, 32+1,
                                          2,  32+2,   3, 32+3,
                                          8,  32+8,   9, 32+9,
                                          10, 32+10, 11, 32+11,
                                          16, 32+16, 17, 32+17,
                                          18, 32+18, 19, 32+19,
                                          24, 32+24, 25, 32+25,
                                          26, 32+26, 27, 32+27);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_unpacklo_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                       (__v32hi)_mm512_unpacklo_epi16(__A, __B),
                                       (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_unpacklo_epi16(__mmask32 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                       (__v32hi)_mm512_unpacklo_epi16(__A, __B),
                                       (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvtepi8_epi16(__m256i __A)
{
  /* This function always performs a signed extension, but __v32qi is a char
     which may be signed or unsigned, so use __v32qs. */
  return (__m512i)__builtin_convertvector((__v32qs)__A, __v32hi);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvtepi8_epi16(__m512i __W, __mmask32 __U, __m256i __A)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_cvtepi8_epi16(__A),
                                             (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtepi8_epi16(__mmask32 __U, __m256i __A)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_cvtepi8_epi16(__A),
                                             (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvtepu8_epi16(__m256i __A)
{
  return (__m512i)__builtin_convertvector((__v32qu)__A, __v32hi);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvtepu8_epi16(__m512i __W, __mmask32 __U, __m256i __A)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_cvtepu8_epi16(__A),
                                             (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtepu8_epi16(__mmask32 __U, __m256i __A)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                             (__v32hi)_mm512_cvtepu8_epi16(__A),
                                             (__v32hi)_mm512_setzero_hi());
}


#define _mm512_shufflehi_epi16(A, imm) __extension__ ({ \
  (__m512i)__builtin_shufflevector((__v32hi)(__m512i)(A), \
                                   (__v32hi)_mm512_undefined_epi32(), \
                                   0, 1, 2, 3, \
                                   4  + (((imm) >> 0) & 0x3), \
                                   4  + (((imm) >> 2) & 0x3), \
                                   4  + (((imm) >> 4) & 0x3), \
                                   4  + (((imm) >> 6) & 0x3), \
                                   8, 9, 10, 11, \
                                   12 + (((imm) >> 0) & 0x3), \
                                   12 + (((imm) >> 2) & 0x3), \
                                   12 + (((imm) >> 4) & 0x3), \
                                   12 + (((imm) >> 6) & 0x3), \
                                   16, 17, 18, 19, \
                                   20 + (((imm) >> 0) & 0x3), \
                                   20 + (((imm) >> 2) & 0x3), \
                                   20 + (((imm) >> 4) & 0x3), \
                                   20 + (((imm) >> 6) & 0x3), \
                                   24, 25, 26, 27, \
                                   28 + (((imm) >> 0) & 0x3), \
                                   28 + (((imm) >> 2) & 0x3), \
                                   28 + (((imm) >> 4) & 0x3), \
                                   28 + (((imm) >> 6) & 0x3)); })

#define _mm512_mask_shufflehi_epi16(W, U, A, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectw_512((__mmask32)(U), \
                                      (__v32hi)_mm512_shufflehi_epi16((A), \
                                                                      (imm)), \
                                      (__v32hi)(__m512i)(W)); })

#define _mm512_maskz_shufflehi_epi16(U, A, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectw_512((__mmask32)(U), \
                                      (__v32hi)_mm512_shufflehi_epi16((A), \
                                                                      (imm)), \
                                      (__v32hi)_mm512_setzero_hi()); })

#define _mm512_shufflelo_epi16(A, imm) __extension__ ({ \
  (__m512i)__builtin_shufflevector((__v32hi)(__m512i)(A), \
                                   (__v32hi)_mm512_undefined_epi32(), \
                                   0 + (((imm) >> 0) & 0x3), \
                                   0 + (((imm) >> 2) & 0x3), \
                                   0 + (((imm) >> 4) & 0x3), \
                                   0 + (((imm) >> 6) & 0x3), \
                                   4, 5, 6, 7, \
                                   8 + (((imm) >> 0) & 0x3), \
                                   8 + (((imm) >> 2) & 0x3), \
                                   8 + (((imm) >> 4) & 0x3), \
                                   8 + (((imm) >> 6) & 0x3), \
                                   12, 13, 14, 15, \
                                   16 + (((imm) >> 0) & 0x3), \
                                   16 + (((imm) >> 2) & 0x3), \
                                   16 + (((imm) >> 4) & 0x3), \
                                   16 + (((imm) >> 6) & 0x3), \
                                   20, 21, 22, 23, \
                                   24 + (((imm) >> 0) & 0x3), \
                                   24 + (((imm) >> 2) & 0x3), \
                                   24 + (((imm) >> 4) & 0x3), \
                                   24 + (((imm) >> 6) & 0x3), \
                                   28, 29, 30, 31); })


#define _mm512_mask_shufflelo_epi16(W, U, A, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectw_512((__mmask32)(U), \
                                      (__v32hi)_mm512_shufflelo_epi16((A), \
                                                                      (imm)), \
                                      (__v32hi)(__m512i)(W)); })


#define _mm512_maskz_shufflelo_epi16(U, A, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectw_512((__mmask32)(U), \
                                      (__v32hi)_mm512_shufflelo_epi16((A), \
                                                                      (imm)), \
                                      (__v32hi)_mm512_setzero_hi()); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_sllv_epi16(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_psllv32hi((__v32hi) __A, (__v32hi) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_sllv_epi16 (__m512i __W, __mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                           (__v32hi)_mm512_sllv_epi16(__A, __B),
                                           (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_sllv_epi16(__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                           (__v32hi)_mm512_sllv_epi16(__A, __B),
                                           (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_sll_epi16(__m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_psllw512((__v32hi) __A, (__v8hi) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_sll_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                          (__v32hi)_mm512_sll_epi16(__A, __B),
                                          (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_sll_epi16(__mmask32 __U, __m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                          (__v32hi)_mm512_sll_epi16(__A, __B),
                                          (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_slli_epi16(__m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_psllwi512((__v32hi)__A, __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_slli_epi16(__m512i __W, __mmask32 __U, __m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                         (__v32hi)_mm512_slli_epi16(__A, __B),
                                         (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_slli_epi16(__mmask32 __U, __m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                         (__v32hi)_mm512_slli_epi16(__A, __B),
                                         (__v32hi)_mm512_setzero_hi());
}

#define _mm512_bslli_epi128(a, imm) __extension__ ({ \
  (__m512i)__builtin_shufflevector(                                          \
       (__v64qi)_mm512_setzero_si512(),                                      \
       (__v64qi)(__m512i)(a),                                                \
       ((char)(imm)&0xF0) ?  0 : ((char)(imm)>0x0 ? 16 :  64) - (char)(imm), \
       ((char)(imm)&0xF0) ?  1 : ((char)(imm)>0x1 ? 17 :  65) - (char)(imm), \
       ((char)(imm)&0xF0) ?  2 : ((char)(imm)>0x2 ? 18 :  66) - (char)(imm), \
       ((char)(imm)&0xF0) ?  3 : ((char)(imm)>0x3 ? 19 :  67) - (char)(imm), \
       ((char)(imm)&0xF0) ?  4 : ((char)(imm)>0x4 ? 20 :  68) - (char)(imm), \
       ((char)(imm)&0xF0) ?  5 : ((char)(imm)>0x5 ? 21 :  69) - (char)(imm), \
       ((char)(imm)&0xF0) ?  6 : ((char)(imm)>0x6 ? 22 :  70) - (char)(imm), \
       ((char)(imm)&0xF0) ?  7 : ((char)(imm)>0x7 ? 23 :  71) - (char)(imm), \
       ((char)(imm)&0xF0) ?  8 : ((char)(imm)>0x8 ? 24 :  72) - (char)(imm), \
       ((char)(imm)&0xF0) ?  9 : ((char)(imm)>0x9 ? 25 :  73) - (char)(imm), \
       ((char)(imm)&0xF0) ? 10 : ((char)(imm)>0xA ? 26 :  74) - (char)(imm), \
       ((char)(imm)&0xF0) ? 11 : ((char)(imm)>0xB ? 27 :  75) - (char)(imm), \
       ((char)(imm)&0xF0) ? 12 : ((char)(imm)>0xC ? 28 :  76) - (char)(imm), \
       ((char)(imm)&0xF0) ? 13 : ((char)(imm)>0xD ? 29 :  77) - (char)(imm), \
       ((char)(imm)&0xF0) ? 14 : ((char)(imm)>0xE ? 30 :  78) - (char)(imm), \
       ((char)(imm)&0xF0) ? 15 : ((char)(imm)>0xF ? 31 :  79) - (char)(imm), \
       ((char)(imm)&0xF0) ? 16 : ((char)(imm)>0x0 ? 32 :  80) - (char)(imm), \
       ((char)(imm)&0xF0) ? 17 : ((char)(imm)>0x1 ? 33 :  81) - (char)(imm), \
       ((char)(imm)&0xF0) ? 18 : ((char)(imm)>0x2 ? 34 :  82) - (char)(imm), \
       ((char)(imm)&0xF0) ? 19 : ((char)(imm)>0x3 ? 35 :  83) - (char)(imm), \
       ((char)(imm)&0xF0) ? 20 : ((char)(imm)>0x4 ? 36 :  84) - (char)(imm), \
       ((char)(imm)&0xF0) ? 21 : ((char)(imm)>0x5 ? 37 :  85) - (char)(imm), \
       ((char)(imm)&0xF0) ? 22 : ((char)(imm)>0x6 ? 38 :  86) - (char)(imm), \
       ((char)(imm)&0xF0) ? 23 : ((char)(imm)>0x7 ? 39 :  87) - (char)(imm), \
       ((char)(imm)&0xF0) ? 24 : ((char)(imm)>0x8 ? 40 :  88) - (char)(imm), \
       ((char)(imm)&0xF0) ? 25 : ((char)(imm)>0x9 ? 41 :  89) - (char)(imm), \
       ((char)(imm)&0xF0) ? 26 : ((char)(imm)>0xA ? 42 :  90) - (char)(imm), \
       ((char)(imm)&0xF0) ? 27 : ((char)(imm)>0xB ? 43 :  91) - (char)(imm), \
       ((char)(imm)&0xF0) ? 28 : ((char)(imm)>0xC ? 44 :  92) - (char)(imm), \
       ((char)(imm)&0xF0) ? 29 : ((char)(imm)>0xD ? 45 :  93) - (char)(imm), \
       ((char)(imm)&0xF0) ? 30 : ((char)(imm)>0xE ? 46 :  94) - (char)(imm), \
       ((char)(imm)&0xF0) ? 31 : ((char)(imm)>0xF ? 47 :  95) - (char)(imm), \
       ((char)(imm)&0xF0) ? 32 : ((char)(imm)>0x0 ? 48 :  96) - (char)(imm), \
       ((char)(imm)&0xF0) ? 33 : ((char)(imm)>0x1 ? 49 :  97) - (char)(imm), \
       ((char)(imm)&0xF0) ? 34 : ((char)(imm)>0x2 ? 50 :  98) - (char)(imm), \
       ((char)(imm)&0xF0) ? 35 : ((char)(imm)>0x3 ? 51 :  99) - (char)(imm), \
       ((char)(imm)&0xF0) ? 36 : ((char)(imm)>0x4 ? 52 : 100) - (char)(imm), \
       ((char)(imm)&0xF0) ? 37 : ((char)(imm)>0x5 ? 53 : 101) - (char)(imm), \
       ((char)(imm)&0xF0) ? 38 : ((char)(imm)>0x6 ? 54 : 102) - (char)(imm), \
       ((char)(imm)&0xF0) ? 39 : ((char)(imm)>0x7 ? 55 : 103) - (char)(imm), \
       ((char)(imm)&0xF0) ? 40 : ((char)(imm)>0x8 ? 56 : 104) - (char)(imm), \
       ((char)(imm)&0xF0) ? 41 : ((char)(imm)>0x9 ? 57 : 105) - (char)(imm), \
       ((char)(imm)&0xF0) ? 42 : ((char)(imm)>0xA ? 58 : 106) - (char)(imm), \
       ((char)(imm)&0xF0) ? 43 : ((char)(imm)>0xB ? 59 : 107) - (char)(imm), \
       ((char)(imm)&0xF0) ? 44 : ((char)(imm)>0xC ? 60 : 108) - (char)(imm), \
       ((char)(imm)&0xF0) ? 45 : ((char)(imm)>0xD ? 61 : 109) - (char)(imm), \
       ((char)(imm)&0xF0) ? 46 : ((char)(imm)>0xE ? 62 : 110) - (char)(imm), \
       ((char)(imm)&0xF0) ? 47 : ((char)(imm)>0xF ? 63 : 111) - (char)(imm), \
       ((char)(imm)&0xF0) ? 48 : ((char)(imm)>0x0 ? 64 : 112) - (char)(imm), \
       ((char)(imm)&0xF0) ? 49 : ((char)(imm)>0x1 ? 65 : 113) - (char)(imm), \
       ((char)(imm)&0xF0) ? 50 : ((char)(imm)>0x2 ? 66 : 114) - (char)(imm), \
       ((char)(imm)&0xF0) ? 51 : ((char)(imm)>0x3 ? 67 : 115) - (char)(imm), \
       ((char)(imm)&0xF0) ? 52 : ((char)(imm)>0x4 ? 68 : 116) - (char)(imm), \
       ((char)(imm)&0xF0) ? 53 : ((char)(imm)>0x5 ? 69 : 117) - (char)(imm), \
       ((char)(imm)&0xF0) ? 54 : ((char)(imm)>0x6 ? 70 : 118) - (char)(imm), \
       ((char)(imm)&0xF0) ? 55 : ((char)(imm)>0x7 ? 71 : 119) - (char)(imm), \
       ((char)(imm)&0xF0) ? 56 : ((char)(imm)>0x8 ? 72 : 120) - (char)(imm), \
       ((char)(imm)&0xF0) ? 57 : ((char)(imm)>0x9 ? 73 : 121) - (char)(imm), \
       ((char)(imm)&0xF0) ? 58 : ((char)(imm)>0xA ? 74 : 122) - (char)(imm), \
       ((char)(imm)&0xF0) ? 59 : ((char)(imm)>0xB ? 75 : 123) - (char)(imm), \
       ((char)(imm)&0xF0) ? 60 : ((char)(imm)>0xC ? 76 : 124) - (char)(imm), \
       ((char)(imm)&0xF0) ? 61 : ((char)(imm)>0xD ? 77 : 125) - (char)(imm), \
       ((char)(imm)&0xF0) ? 62 : ((char)(imm)>0xE ? 78 : 126) - (char)(imm), \
       ((char)(imm)&0xF0) ? 63 : ((char)(imm)>0xF ? 79 : 127) - (char)(imm)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_srlv_epi16(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_psrlv32hi((__v32hi)__A, (__v32hi)__B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_srlv_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                           (__v32hi)_mm512_srlv_epi16(__A, __B),
                                           (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_srlv_epi16(__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                           (__v32hi)_mm512_srlv_epi16(__A, __B),
                                           (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_srav_epi16(__m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_psrav32hi((__v32hi)__A, (__v32hi)__B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_srav_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                           (__v32hi)_mm512_srav_epi16(__A, __B),
                                           (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_srav_epi16(__mmask32 __U, __m512i __A, __m512i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                           (__v32hi)_mm512_srav_epi16(__A, __B),
                                           (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_sra_epi16(__m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_psraw512((__v32hi) __A, (__v8hi) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_sra_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                          (__v32hi)_mm512_sra_epi16(__A, __B),
                                          (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_sra_epi16(__mmask32 __U, __m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                          (__v32hi)_mm512_sra_epi16(__A, __B),
                                          (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_srai_epi16(__m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_psrawi512((__v32hi)__A, __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_srai_epi16(__m512i __W, __mmask32 __U, __m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                         (__v32hi)_mm512_srai_epi16(__A, __B),
                                         (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_srai_epi16(__mmask32 __U, __m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                         (__v32hi)_mm512_srai_epi16(__A, __B),
                                         (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_srl_epi16(__m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_psrlw512((__v32hi) __A, (__v8hi) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_srl_epi16(__m512i __W, __mmask32 __U, __m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                          (__v32hi)_mm512_srl_epi16(__A, __B),
                                          (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_srl_epi16(__mmask32 __U, __m512i __A, __m128i __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                          (__v32hi)_mm512_srl_epi16(__A, __B),
                                          (__v32hi)_mm512_setzero_hi());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_srli_epi16(__m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_psrlwi512((__v32hi)__A, __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_srli_epi16(__m512i __W, __mmask32 __U, __m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                         (__v32hi)_mm512_srli_epi16(__A, __B),
                                         (__v32hi)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_srli_epi16(__mmask32 __U, __m512i __A, int __B)
{
  return (__m512i)__builtin_ia32_selectw_512((__mmask32)__U,
                                         (__v32hi)_mm512_srli_epi16(__A, __B),
                                         (__v32hi)_mm512_setzero_hi());
}

#define _mm512_bsrli_epi128(a, imm) __extension__ ({ \
  (__m512i)__builtin_shufflevector(                     \
      (__v64qi)(__m512i)(a),                      \
      (__v64qi)_mm512_setzero_si512(),            \
      ((char)(imm)&0xF0) ?  64 : (char)(imm) + ((char)(imm)>0xF ?  48 : 0),  \
      ((char)(imm)&0xF0) ?  65 : (char)(imm) + ((char)(imm)>0xE ?  49 : 1),  \
      ((char)(imm)&0xF0) ?  66 : (char)(imm) + ((char)(imm)>0xD ?  50 : 2),  \
      ((char)(imm)&0xF0) ?  67 : (char)(imm) + ((char)(imm)>0xC ?  51 : 3),  \
      ((char)(imm)&0xF0) ?  68 : (char)(imm) + ((char)(imm)>0xB ?  52 : 4),  \
      ((char)(imm)&0xF0) ?  69 : (char)(imm) + ((char)(imm)>0xA ?  53 : 5),  \
      ((char)(imm)&0xF0) ?  70 : (char)(imm) + ((char)(imm)>0x9 ?  54 : 6),  \
      ((char)(imm)&0xF0) ?  71 : (char)(imm) + ((char)(imm)>0x8 ?  55 : 7),  \
      ((char)(imm)&0xF0) ?  72 : (char)(imm) + ((char)(imm)>0x7 ?  56 : 8),  \
      ((char)(imm)&0xF0) ?  73 : (char)(imm) + ((char)(imm)>0x6 ?  57 : 9),  \
      ((char)(imm)&0xF0) ?  74 : (char)(imm) + ((char)(imm)>0x5 ?  58 : 10), \
      ((char)(imm)&0xF0) ?  75 : (char)(imm) + ((char)(imm)>0x4 ?  59 : 11), \
      ((char)(imm)&0xF0) ?  76 : (char)(imm) + ((char)(imm)>0x3 ?  60 : 12), \
      ((char)(imm)&0xF0) ?  77 : (char)(imm) + ((char)(imm)>0x2 ?  61 : 13), \
      ((char)(imm)&0xF0) ?  78 : (char)(imm) + ((char)(imm)>0x1 ?  62 : 14), \
      ((char)(imm)&0xF0) ?  79 : (char)(imm) + ((char)(imm)>0x0 ?  63 : 15), \
      ((char)(imm)&0xF0) ?  80 : (char)(imm) + ((char)(imm)>0xF ?  64 : 16), \
      ((char)(imm)&0xF0) ?  81 : (char)(imm) + ((char)(imm)>0xE ?  65 : 17), \
      ((char)(imm)&0xF0) ?  82 : (char)(imm) + ((char)(imm)>0xD ?  66 : 18), \
      ((char)(imm)&0xF0) ?  83 : (char)(imm) + ((char)(imm)>0xC ?  67 : 19), \
      ((char)(imm)&0xF0) ?  84 : (char)(imm) + ((char)(imm)>0xB ?  68 : 20), \
      ((char)(imm)&0xF0) ?  85 : (char)(imm) + ((char)(imm)>0xA ?  69 : 21), \
      ((char)(imm)&0xF0) ?  86 : (char)(imm) + ((char)(imm)>0x9 ?  70 : 22), \
      ((char)(imm)&0xF0) ?  87 : (char)(imm) + ((char)(imm)>0x8 ?  71 : 23), \
      ((char)(imm)&0xF0) ?  88 : (char)(imm) + ((char)(imm)>0x7 ?  72 : 24), \
      ((char)(imm)&0xF0) ?  89 : (char)(imm) + ((char)(imm)>0x6 ?  73 : 25), \
      ((char)(imm)&0xF0) ?  90 : (char)(imm) + ((char)(imm)>0x5 ?  74 : 26), \
      ((char)(imm)&0xF0) ?  91 : (char)(imm) + ((char)(imm)>0x4 ?  75 : 27), \
      ((char)(imm)&0xF0) ?  92 : (char)(imm) + ((char)(imm)>0x3 ?  76 : 28), \
      ((char)(imm)&0xF0) ?  93 : (char)(imm) + ((char)(imm)>0x2 ?  77 : 29), \
      ((char)(imm)&0xF0) ?  94 : (char)(imm) + ((char)(imm)>0x1 ?  78 : 30), \
      ((char)(imm)&0xF0) ?  95 : (char)(imm) + ((char)(imm)>0x0 ?  79 : 31), \
      ((char)(imm)&0xF0) ?  96 : (char)(imm) + ((char)(imm)>0xF ?  80 : 32), \
      ((char)(imm)&0xF0) ?  97 : (char)(imm) + ((char)(imm)>0xE ?  81 : 33), \
      ((char)(imm)&0xF0) ?  98 : (char)(imm) + ((char)(imm)>0xD ?  82 : 34), \
      ((char)(imm)&0xF0) ?  99 : (char)(imm) + ((char)(imm)>0xC ?  83 : 35), \
      ((char)(imm)&0xF0) ? 100 : (char)(imm) + ((char)(imm)>0xB ?  84 : 36), \
      ((char)(imm)&0xF0) ? 101 : (char)(imm) + ((char)(imm)>0xA ?  85 : 37), \
      ((char)(imm)&0xF0) ? 102 : (char)(imm) + ((char)(imm)>0x9 ?  86 : 38), \
      ((char)(imm)&0xF0) ? 103 : (char)(imm) + ((char)(imm)>0x8 ?  87 : 39), \
      ((char)(imm)&0xF0) ? 104 : (char)(imm) + ((char)(imm)>0x7 ?  88 : 40), \
      ((char)(imm)&0xF0) ? 105 : (char)(imm) + ((char)(imm)>0x6 ?  89 : 41), \
      ((char)(imm)&0xF0) ? 106 : (char)(imm) + ((char)(imm)>0x5 ?  90 : 42), \
      ((char)(imm)&0xF0) ? 107 : (char)(imm) + ((char)(imm)>0x4 ?  91 : 43), \
      ((char)(imm)&0xF0) ? 108 : (char)(imm) + ((char)(imm)>0x3 ?  92 : 44), \
      ((char)(imm)&0xF0) ? 109 : (char)(imm) + ((char)(imm)>0x2 ?  93 : 45), \
      ((char)(imm)&0xF0) ? 110 : (char)(imm) + ((char)(imm)>0x1 ?  94 : 46), \
      ((char)(imm)&0xF0) ? 111 : (char)(imm) + ((char)(imm)>0x0 ?  95 : 47), \
      ((char)(imm)&0xF0) ? 112 : (char)(imm) + ((char)(imm)>0xF ?  96 : 48), \
      ((char)(imm)&0xF0) ? 113 : (char)(imm) + ((char)(imm)>0xE ?  97 : 49), \
      ((char)(imm)&0xF0) ? 114 : (char)(imm) + ((char)(imm)>0xD ?  98 : 50), \
      ((char)(imm)&0xF0) ? 115 : (char)(imm) + ((char)(imm)>0xC ?  99 : 51), \
      ((char)(imm)&0xF0) ? 116 : (char)(imm) + ((char)(imm)>0xB ? 100 : 52), \
      ((char)(imm)&0xF0) ? 117 : (char)(imm) + ((char)(imm)>0xA ? 101 : 53), \
      ((char)(imm)&0xF0) ? 118 : (char)(imm) + ((char)(imm)>0x9 ? 102 : 54), \
      ((char)(imm)&0xF0) ? 119 : (char)(imm) + ((char)(imm)>0x8 ? 103 : 55), \
      ((char)(imm)&0xF0) ? 120 : (char)(imm) + ((char)(imm)>0x7 ? 104 : 56), \
      ((char)(imm)&0xF0) ? 121 : (char)(imm) + ((char)(imm)>0x6 ? 105 : 57), \
      ((char)(imm)&0xF0) ? 122 : (char)(imm) + ((char)(imm)>0x5 ? 106 : 58), \
      ((char)(imm)&0xF0) ? 123 : (char)(imm) + ((char)(imm)>0x4 ? 107 : 59), \
      ((char)(imm)&0xF0) ? 124 : (char)(imm) + ((char)(imm)>0x3 ? 108 : 60), \
      ((char)(imm)&0xF0) ? 125 : (char)(imm) + ((char)(imm)>0x2 ? 109 : 61), \
      ((char)(imm)&0xF0) ? 126 : (char)(imm) + ((char)(imm)>0x1 ? 110 : 62), \
      ((char)(imm)&0xF0) ? 127 : (char)(imm) + ((char)(imm)>0x0 ? 111 : 63)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mov_epi16 (__m512i __W, __mmask32 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_selectw_512 ((__mmask32) __U,
                (__v32hi) __A,
                (__v32hi) __W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mov_epi16 (__mmask32 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_selectw_512 ((__mmask32) __U,
                (__v32hi) __A,
                (__v32hi) _mm512_setzero_hi ());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mov_epi8 (__m512i __W, __mmask64 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_selectb_512 ((__mmask64) __U,
                (__v64qi) __A,
                (__v64qi) __W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mov_epi8 (__mmask64 __U, __m512i __A)
{
  return (__m512i) __builtin_ia32_selectb_512 ((__mmask64) __U,
                (__v64qi) __A,
                (__v64qi) _mm512_setzero_hi ());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_set1_epi8 (__m512i __O, __mmask64 __M, char __A)
{
  return (__m512i) __builtin_ia32_selectb_512(__M,
                                              (__v64qi)_mm512_set1_epi8(__A),
                                              (__v64qi) __O);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_set1_epi8 (__mmask64 __M, char __A)
{
  return (__m512i) __builtin_ia32_selectb_512(__M,
                                              (__v64qi) _mm512_set1_epi8(__A),
                                              (__v64qi) _mm512_setzero_si512());
}

static __inline__ __mmask64 __DEFAULT_FN_ATTRS
_mm512_kunpackd (__mmask64 __A, __mmask64 __B)
{
  return (__mmask64)  (( __A  & 0xFFFFFFFF) | ( __B << 32));
}

static __inline__ __mmask32 __DEFAULT_FN_ATTRS
_mm512_kunpackw (__mmask32 __A, __mmask32 __B)
{
return (__mmask32)  (( __A  & 0xFFFF) | ( __B << 16));
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_loadu_epi16 (__m512i __W, __mmask32 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_loaddquhi512_mask ((__v32hi *) __P,
                 (__v32hi) __W,
                 (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_loadu_epi16 (__mmask32 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_loaddquhi512_mask ((__v32hi *) __P,
                 (__v32hi)
                 _mm512_setzero_hi (),
                 (__mmask32) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_loadu_epi8 (__m512i __W, __mmask64 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_loaddquqi512_mask ((__v64qi *) __P,
                 (__v64qi) __W,
                 (__mmask64) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_loadu_epi8 (__mmask64 __U, void const *__P)
{
  return (__m512i) __builtin_ia32_loaddquqi512_mask ((__v64qi *) __P,
                 (__v64qi)
                 _mm512_setzero_hi (),
                 (__mmask64) __U);
}
static __inline__ void __DEFAULT_FN_ATTRS
_mm512_mask_storeu_epi16 (void *__P, __mmask32 __U, __m512i __A)
{
  __builtin_ia32_storedquhi512_mask ((__v32hi *) __P,
             (__v32hi) __A,
             (__mmask32) __U);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm512_mask_storeu_epi8 (void *__P, __mmask64 __U, __m512i __A)
{
  __builtin_ia32_storedquqi512_mask ((__v64qi *) __P,
             (__v64qi) __A,
             (__mmask64) __U);
}

static __inline__ __mmask64 __DEFAULT_FN_ATTRS
_mm512_test_epi8_mask (__m512i __A, __m512i __B)
{
  return _mm512_cmpneq_epi8_mask (_mm512_and_epi32 (__A, __B),
                                  _mm512_setzero_qi());
}

static __inline__ __mmask64 __DEFAULT_FN_ATTRS
_mm512_mask_test_epi8_mask (__mmask64 __U, __m512i __A, __m512i __B)
{
  return _mm512_mask_cmpneq_epi8_mask (__U, _mm512_and_epi32 (__A, __B),
                                       _mm512_setzero_qi());
}

static __inline__ __mmask32 __DEFAULT_FN_ATTRS
_mm512_test_epi16_mask (__m512i __A, __m512i __B)
{
  return _mm512_cmpneq_epi16_mask (_mm512_and_epi32 (__A, __B),
                                   _mm512_setzero_qi());
}

static __inline__ __mmask32 __DEFAULT_FN_ATTRS
_mm512_mask_test_epi16_mask (__mmask32 __U, __m512i __A, __m512i __B)
{
  return _mm512_mask_cmpneq_epi16_mask (__U, _mm512_and_epi32 (__A, __B),
                                        _mm512_setzero_qi());
}

static __inline__ __mmask64 __DEFAULT_FN_ATTRS
_mm512_testn_epi8_mask (__m512i __A, __m512i __B)
{
  return _mm512_cmpeq_epi8_mask (_mm512_and_epi32 (__A, __B), _mm512_setzero_qi());
}

static __inline__ __mmask64 __DEFAULT_FN_ATTRS
_mm512_mask_testn_epi8_mask (__mmask64 __U, __m512i __A, __m512i __B)
{
  return _mm512_mask_cmpeq_epi8_mask (__U, _mm512_and_epi32 (__A, __B),
                                      _mm512_setzero_qi());
}

static __inline__ __mmask32 __DEFAULT_FN_ATTRS
_mm512_testn_epi16_mask (__m512i __A, __m512i __B)
{
  return _mm512_cmpeq_epi16_mask (_mm512_and_epi32 (__A, __B),
                                  _mm512_setzero_qi());
}

static __inline__ __mmask32 __DEFAULT_FN_ATTRS
_mm512_mask_testn_epi16_mask (__mmask32 __U, __m512i __A, __m512i __B)
{
  return _mm512_mask_cmpeq_epi16_mask (__U, _mm512_and_epi32 (__A, __B),
                                       _mm512_setzero_qi());
}

static __inline__ __mmask64 __DEFAULT_FN_ATTRS
_mm512_movepi8_mask (__m512i __A)
{
  return (__mmask64) __builtin_ia32_cvtb2mask512 ((__v64qi) __A);
}

static __inline__ __mmask32 __DEFAULT_FN_ATTRS
_mm512_movepi16_mask (__m512i __A)
{
  return (__mmask32) __builtin_ia32_cvtw2mask512 ((__v32hi) __A);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_movm_epi8 (__mmask64 __A)
{
  return (__m512i) __builtin_ia32_cvtmask2b512 (__A);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_movm_epi16 (__mmask32 __A)
{
  return (__m512i) __builtin_ia32_cvtmask2w512 (__A);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_broadcastb_epi8 (__m128i __A)
{
  return (__m512i)__builtin_shufflevector((__v16qi) __A,
                                          (__v16qi)_mm_undefined_si128(),
                                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_broadcastb_epi8 (__m512i __O, __mmask64 __M, __m128i __A)
{
  return (__m512i)__builtin_ia32_selectb_512(__M,
                                             (__v64qi) _mm512_broadcastb_epi8(__A),
                                             (__v64qi) __O);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_broadcastb_epi8 (__mmask64 __M, __m128i __A)
{
  return (__m512i)__builtin_ia32_selectb_512(__M,
                                             (__v64qi) _mm512_broadcastb_epi8(__A),
                                             (__v64qi) _mm512_setzero_si512());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_set1_epi16 (__m512i __O, __mmask32 __M, short __A)
{
  return (__m512i) __builtin_ia32_selectw_512(__M,
                                              (__v32hi) _mm512_set1_epi16(__A),
                                              (__v32hi) __O);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_set1_epi16 (__mmask32 __M, short __A)
{
  return (__m512i) __builtin_ia32_selectw_512(__M,
                                              (__v32hi) _mm512_set1_epi16(__A),
                                              (__v32hi) _mm512_setzero_si512());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_broadcastw_epi16 (__m128i __A)
{
  return (__m512i)__builtin_shufflevector((__v8hi) __A,
                                          (__v8hi)_mm_undefined_si128(),
                                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_broadcastw_epi16 (__m512i __O, __mmask32 __M, __m128i __A)
{
  return (__m512i)__builtin_ia32_selectw_512(__M,
                                             (__v32hi) _mm512_broadcastw_epi16(__A),
                                             (__v32hi) __O);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_broadcastw_epi16 (__mmask32 __M, __m128i __A)
{
  return (__m512i)__builtin_ia32_selectw_512(__M,
                                             (__v32hi) _mm512_broadcastw_epi16(__A),
                                             (__v32hi) _mm512_setzero_si512());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_permutexvar_epi16 (__m512i __A, __m512i __B)
{
  return (__m512i) __builtin_ia32_permvarhi512_mask ((__v32hi) __B,
                 (__v32hi) __A,
                 (__v32hi) _mm512_undefined_epi32 (),
                 (__mmask32) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_permutexvar_epi16 (__mmask32 __M, __m512i __A,
        __m512i __B)
{
  return (__m512i) __builtin_ia32_permvarhi512_mask ((__v32hi) __B,
                 (__v32hi) __A,
                 (__v32hi) _mm512_setzero_hi(),
                 (__mmask32) __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_permutexvar_epi16 (__m512i __W, __mmask32 __M, __m512i __A,
             __m512i __B)
{
  return (__m512i) __builtin_ia32_permvarhi512_mask ((__v32hi) __B,
                 (__v32hi) __A,
                 (__v32hi) __W,
                 (__mmask32) __M);
}

#define _mm512_alignr_epi8(A, B, N) __extension__ ({\
  (__m512i)__builtin_ia32_palignr512_mask((__v64qi)(__m512i)(A), \
                                          (__v64qi)(__m512i)(B), (int)(N), \
                                          (__v64qi)_mm512_undefined_pd(), \
                                          (__mmask64)-1); })

#define _mm512_mask_alignr_epi8(W, U, A, B, N) __extension__({\
  (__m512i)__builtin_ia32_palignr512_mask((__v64qi)(__m512i)(A), \
                                          (__v64qi)(__m512i)(B), (int)(N), \
                                          (__v64qi)(__m512i)(W), \
                                          (__mmask64)(U)); })

#define _mm512_maskz_alignr_epi8(U, A, B, N) __extension__({\
  (__m512i)__builtin_ia32_palignr512_mask((__v64qi)(__m512i)(A), \
                                          (__v64qi)(__m512i)(B), (int)(N), \
                                          (__v64qi)_mm512_setzero_si512(), \
                                          (__mmask64)(U)); })

#define _mm512_dbsad_epu8(A, B, imm) __extension__ ({\
  (__m512i)__builtin_ia32_dbpsadbw512_mask((__v64qi)(__m512i)(A), \
                                           (__v64qi)(__m512i)(B), (int)(imm), \
                                           (__v32hi)_mm512_undefined_epi32(), \
                                           (__mmask32)-1); })

#define _mm512_mask_dbsad_epu8(W, U, A, B, imm) ({\
  (__m512i)__builtin_ia32_dbpsadbw512_mask((__v64qi)(__m512i)(A), \
                                           (__v64qi)(__m512i)(B), (int)(imm), \
                                           (__v32hi)(__m512i)(W), \
                                           (__mmask32)(U)); })

#define _mm512_maskz_dbsad_epu8(U, A, B, imm) ({\
  (__m512i)__builtin_ia32_dbpsadbw512_mask((__v64qi)(__m512i)(A), \
                                           (__v64qi)(__m512i)(B), (int)(imm), \
                                           (__v32hi)_mm512_setzero_hi(), \
                                           (__mmask32)(U)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_sad_epu8 (__m512i __A, __m512i __B)
{
 return (__m512i) __builtin_ia32_psadbw512 ((__v64qi) __A,
               (__v64qi) __B);
}



#undef __DEFAULT_FN_ATTRS

#endif
