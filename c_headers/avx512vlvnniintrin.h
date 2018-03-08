/*===------------- avx512vlvnniintrin.h - VNNI intrinsics ------------------===
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
#error "Never use <avx512vlvnniintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512VLVNNIINTRIN_H
#define __AVX512VLVNNIINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512vl,avx512vnni")))


static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_dpbusd_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpbusd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_dpbusd_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpbusd256_maskz ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_dpbusd_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpbusd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_dpbusds_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpbusds256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_dpbusds_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpbusds256_maskz ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_dpbusds_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpbusds256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_dpwssd_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpwssd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_dpwssd_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpwssd256_maskz ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_dpwssd_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpwssd256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_dpwssds_epi32(__m256i __S, __mmask8 __U, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpwssds256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_dpwssds_epi32(__mmask8 __U, __m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpwssds256_maskz ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_dpwssds_epi32(__m256i __S, __m256i __A, __m256i __B)
{
  return (__m256i) __builtin_ia32_vpdpwssds256_mask ((__v8si) __S,
              (__v8si) __A,
              (__v8si) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_dpbusd_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpbusd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_dpbusd_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpbusd128_maskz ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_dpbusd_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpbusd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_dpbusds_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpbusds128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_dpbusds_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpbusds128_maskz ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_dpbusds_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpbusds128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_dpwssd_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpwssd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_dpwssd_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpwssd128_maskz ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_dpwssd_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpwssd128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_mask_dpwssds_epi32(__m128i __S, __mmask8 __U, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpwssds128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_maskz_dpwssds_epi32(__mmask8 __U, __m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpwssds128_maskz ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm128_dpwssds_epi32(__m128i __S, __m128i __A, __m128i __B)
{
  return (__m128i) __builtin_ia32_vpdpwssds128_mask ((__v4si) __S,
              (__v4si) __A,
              (__v4si) __B,
              (__mmask8) -1);
}


#undef __DEFAULT_FN_ATTRS

#endif
