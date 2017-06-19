/*===------------- avx512ifmavlintrin.h - IFMA intrinsics ------------------===
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
#error "Never use <avx512ifmavlintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __IFMAVLINTRIN_H
#define __IFMAVLINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512ifma,avx512vl")))



static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_madd52hi_epu64 (__m128i __X, __m128i __Y, __m128i __Z)
{
  return (__m128i) __builtin_ia32_vpmadd52huq128_mask ((__v2di) __X,
                   (__v2di) __Y,
                   (__v2di) __Z,
                   (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_madd52hi_epu64 (__m128i __W, __mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i) __builtin_ia32_vpmadd52huq128_mask ((__v2di) __W,
                   (__v2di) __X,
                   (__v2di) __Y,
                   (__mmask8) __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_madd52hi_epu64 (__mmask8 __M, __m128i __X, __m128i __Y, __m128i __Z)
{
  return (__m128i) __builtin_ia32_vpmadd52huq128_maskz ((__v2di) __X,
              (__v2di) __Y,
              (__v2di) __Z,
              (__mmask8) __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_madd52hi_epu64 (__m256i __X, __m256i __Y, __m256i __Z)
{
  return (__m256i) __builtin_ia32_vpmadd52huq256_mask ((__v4di) __X,
                   (__v4di) __Y,
                   (__v4di) __Z,
                   (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_madd52hi_epu64 (__m256i __W, __mmask8 __M, __m256i __X,
          __m256i __Y)
{
  return (__m256i) __builtin_ia32_vpmadd52huq256_mask ((__v4di) __W,
                   (__v4di) __X,
                   (__v4di) __Y,
                   (__mmask8) __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_madd52hi_epu64 (__mmask8 __M, __m256i __X, __m256i __Y, __m256i __Z)
{
  return (__m256i) __builtin_ia32_vpmadd52huq256_maskz ((__v4di) __X,
              (__v4di) __Y,
              (__v4di) __Z,
              (__mmask8) __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_madd52lo_epu64 (__m128i __X, __m128i __Y, __m128i __Z)
{
  return (__m128i) __builtin_ia32_vpmadd52luq128_mask ((__v2di) __X,
                   (__v2di) __Y,
                   (__v2di) __Z,
                   (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_madd52lo_epu64 (__m128i __W, __mmask8 __M, __m128i __X, __m128i __Y)
{
  return (__m128i) __builtin_ia32_vpmadd52luq128_mask ((__v2di) __W,
                   (__v2di) __X,
                   (__v2di) __Y,
                   (__mmask8) __M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_madd52lo_epu64 (__mmask8 __M, __m128i __X, __m128i __Y, __m128i __Z)
{
  return (__m128i) __builtin_ia32_vpmadd52luq128_maskz ((__v2di) __X,
              (__v2di) __Y,
              (__v2di) __Z,
              (__mmask8) __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_madd52lo_epu64 (__m256i __X, __m256i __Y, __m256i __Z)
{
  return (__m256i) __builtin_ia32_vpmadd52luq256_mask ((__v4di) __X,
                   (__v4di) __Y,
                   (__v4di) __Z,
                   (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_madd52lo_epu64 (__m256i __W, __mmask8 __M, __m256i __X,
          __m256i __Y)
{
  return (__m256i) __builtin_ia32_vpmadd52luq256_mask ((__v4di) __W,
                   (__v4di) __X,
                   (__v4di) __Y,
                   (__mmask8) __M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_madd52lo_epu64 (__mmask8 __M, __m256i __X, __m256i __Y, __m256i __Z)
{
  return (__m256i) __builtin_ia32_vpmadd52luq256_maskz ((__v4di) __X,
              (__v4di) __Y,
              (__v4di) __Z,
              (__mmask8) __M);
}


#undef __DEFAULT_FN_ATTRS

#endif
