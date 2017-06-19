/*===---- avx512vlcdintrin.h - AVX512VL and AVX512CD intrinsics ---------------------------===
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
#error "Never use <avx512vlcdintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512VLCDINTRIN_H
#define __AVX512VLCDINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512vl,avx512cd")))


static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_broadcastmb_epi64 (__mmask8 __A)
{
  return (__m128i) __builtin_ia32_broadcastmb128 (__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcastmb_epi64 (__mmask8 __A)
{
  return (__m256i) __builtin_ia32_broadcastmb256 (__A);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_broadcastmw_epi32 (__mmask16 __A)
{
  return (__m128i) __builtin_ia32_broadcastmw128 (__A);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcastmw_epi32 (__mmask16 __A)
{
  return (__m256i) __builtin_ia32_broadcastmw256 (__A);
}


static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_conflict_epi64 (__m128i __A)
{
  return (__m128i) __builtin_ia32_vpconflictdi_128_mask ((__v2di) __A,
               (__v2di) _mm_undefined_si128 (),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_conflict_epi64 (__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vpconflictdi_128_mask ((__v2di) __A,
               (__v2di) __W,
               (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_conflict_epi64 (__mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vpconflictdi_128_mask ((__v2di) __A,
               (__v2di)
               _mm_setzero_di (),
               (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_conflict_epi64 (__m256i __A)
{
  return (__m256i) __builtin_ia32_vpconflictdi_256_mask ((__v4di) __A,
               (__v4di)  _mm256_undefined_si256 (),
               (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_conflict_epi64 (__m256i __W, __mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vpconflictdi_256_mask ((__v4di) __A,
               (__v4di) __W,
               (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_conflict_epi64 (__mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vpconflictdi_256_mask ((__v4di) __A,
               (__v4di) _mm256_setzero_si256 (),
               (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_conflict_epi32 (__m128i __A)
{
  return (__m128i) __builtin_ia32_vpconflictsi_128_mask ((__v4si) __A,
               (__v4si) _mm_undefined_si128 (),
               (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_conflict_epi32 (__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vpconflictsi_128_mask ((__v4si) __A,
               (__v4si) __W,
               (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_conflict_epi32 (__mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vpconflictsi_128_mask ((__v4si) __A,
               (__v4si) _mm_setzero_si128 (),
               (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_conflict_epi32 (__m256i __A)
{
  return (__m256i) __builtin_ia32_vpconflictsi_256_mask ((__v8si) __A,
               (__v8si) _mm256_undefined_si256 (),
               (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_conflict_epi32 (__m256i __W, __mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vpconflictsi_256_mask ((__v8si) __A,
               (__v8si) __W,
               (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_conflict_epi32 (__mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vpconflictsi_256_mask ((__v8si) __A,
               (__v8si)
               _mm256_setzero_si256 (),
               (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_lzcnt_epi32 (__m128i __A)
{
  return (__m128i) __builtin_ia32_vplzcntd_128_mask ((__v4si) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_lzcnt_epi32 (__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vplzcntd_128_mask ((__v4si) __A,
                 (__v4si) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_lzcnt_epi32 (__mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vplzcntd_128_mask ((__v4si) __A,
                 (__v4si)
                 _mm_setzero_si128 (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_lzcnt_epi32 (__m256i __A)
{
  return (__m256i) __builtin_ia32_vplzcntd_256_mask ((__v8si) __A,
                 (__v8si)
                 _mm256_setzero_si256 (),
                 (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_lzcnt_epi32 (__m256i __W, __mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vplzcntd_256_mask ((__v8si) __A,
                 (__v8si) __W,
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_lzcnt_epi32 (__mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vplzcntd_256_mask ((__v8si) __A,
                 (__v8si)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_lzcnt_epi64 (__m128i __A)
{
  return (__m128i) __builtin_ia32_vplzcntq_128_mask ((__v2di) __A,
                 (__v2di)
                 _mm_setzero_di (),
                 (__mmask8) -1);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_lzcnt_epi64 (__m128i __W, __mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vplzcntq_128_mask ((__v2di) __A,
                 (__v2di) __W,
                 (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_lzcnt_epi64 (__mmask8 __U, __m128i __A)
{
  return (__m128i) __builtin_ia32_vplzcntq_128_mask ((__v2di) __A,
                 (__v2di)
                 _mm_setzero_di (),
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_lzcnt_epi64 (__m256i __A)
{
  return (__m256i) __builtin_ia32_vplzcntq_256_mask ((__v4di) __A,
                 (__v4di)
                 _mm256_setzero_si256 (),
                 (__mmask8) -1);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_lzcnt_epi64 (__m256i __W, __mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vplzcntq_256_mask ((__v4di) __A,
                 (__v4di) __W,
                 (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_lzcnt_epi64 (__mmask8 __U, __m256i __A)
{
  return (__m256i) __builtin_ia32_vplzcntq_256_mask ((__v4di) __A,
                 (__v4di)
                 _mm256_setzero_si256 (),
                 (__mmask8) __U);
}

#undef __DEFAULT_FN_ATTRS

#endif /* __AVX512VLCDINTRIN_H */
