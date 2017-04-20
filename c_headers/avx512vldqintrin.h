/*===---- avx512vldqintrin.h - AVX512VL and AVX512DQ intrinsics ---------------------------===
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
#error "Never use <avx512vldqintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512VLDQINTRIN_H
#define __AVX512VLDQINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__))

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mullo_epi64 (__m256i __A, __m256i __B) {
  return (__m256i) ((__v4di) __A * (__v4di) __B);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mask_mullo_epi64 (__m256i __W, __mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pmullq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di) __W,
              (__mmask8) __U);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskz_mullo_epi64 (__mmask8 __U, __m256i __A, __m256i __B) {
  return (__m256i) __builtin_ia32_pmullq256_mask ((__v4di) __A,
              (__v4di) __B,
              (__v4di)
              _mm256_setzero_si256 (),
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mullo_epi64 (__m128i __A, __m128i __B) {
  return (__m128i) ((__v2di) __A * (__v2di) __B);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_mask_mullo_epi64 (__m128i __W, __mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pmullq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di) __W,
              (__mmask8) __U);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskz_mullo_epi64 (__mmask8 __U, __m128i __A, __m128i __B) {
  return (__m128i) __builtin_ia32_pmullq128_mask ((__v2di) __A,
              (__v2di) __B,
              (__v2di)
              _mm_setzero_si128 (),
              (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_andnot_pd (__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_andnpd256_mask ((__v4df) __A,
              (__v4df) __B,
              (__v4df) __W,
              (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_andnot_pd (__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_andnpd256_mask ((__v4df) __A,
              (__v4df) __B,
              (__v4df)
              _mm256_setzero_pd (),
              (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_andnot_pd (__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_andnpd128_mask ((__v2df) __A,
              (__v2df) __B,
              (__v2df) __W,
              (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_andnot_pd (__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_andnpd128_mask ((__v2df) __A,
              (__v2df) __B,
              (__v2df)
              _mm_setzero_pd (),
              (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_andnot_ps (__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_andnps256_mask ((__v8sf) __A,
             (__v8sf) __B,
             (__v8sf) __W,
             (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_andnot_ps (__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_andnps256_mask ((__v8sf) __A,
             (__v8sf) __B,
             (__v8sf)
             _mm256_setzero_ps (),
             (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_andnot_ps (__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_andnps128_mask ((__v4sf) __A,
             (__v4sf) __B,
             (__v4sf) __W,
             (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_andnot_ps (__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_andnps128_mask ((__v4sf) __A,
             (__v4sf) __B,
             (__v4sf)
             _mm_setzero_ps (),
             (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_and_pd (__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_andpd256_mask ((__v4df) __A,
             (__v4df) __B,
             (__v4df) __W,
             (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_and_pd (__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_andpd256_mask ((__v4df) __A,
             (__v4df) __B,
             (__v4df)
             _mm256_setzero_pd (),
             (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_and_pd (__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_andpd128_mask ((__v2df) __A,
             (__v2df) __B,
             (__v2df) __W,
             (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_and_pd (__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_andpd128_mask ((__v2df) __A,
             (__v2df) __B,
             (__v2df)
             _mm_setzero_pd (),
             (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_and_ps (__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_andps256_mask ((__v8sf) __A,
            (__v8sf) __B,
            (__v8sf) __W,
            (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_and_ps (__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_andps256_mask ((__v8sf) __A,
            (__v8sf) __B,
            (__v8sf)
            _mm256_setzero_ps (),
            (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_and_ps (__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_andps128_mask ((__v4sf) __A,
            (__v4sf) __B,
            (__v4sf) __W,
            (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_and_ps (__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_andps128_mask ((__v4sf) __A,
            (__v4sf) __B,
            (__v4sf)
            _mm_setzero_ps (),
            (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_xor_pd (__m256d __W, __mmask8 __U, __m256d __A,
        __m256d __B) {
  return (__m256d) __builtin_ia32_xorpd256_mask ((__v4df) __A,
             (__v4df) __B,
             (__v4df) __W,
             (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_xor_pd (__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_xorpd256_mask ((__v4df) __A,
             (__v4df) __B,
             (__v4df)
             _mm256_setzero_pd (),
             (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_xor_pd (__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_xorpd128_mask ((__v2df) __A,
             (__v2df) __B,
             (__v2df) __W,
             (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_xor_pd (__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_xorpd128_mask ((__v2df) __A,
             (__v2df) __B,
             (__v2df)
             _mm_setzero_pd (),
             (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_xor_ps (__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_xorps256_mask ((__v8sf) __A,
            (__v8sf) __B,
            (__v8sf) __W,
            (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_xor_ps (__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_xorps256_mask ((__v8sf) __A,
            (__v8sf) __B,
            (__v8sf)
            _mm256_setzero_ps (),
            (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_xor_ps (__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_xorps128_mask ((__v4sf) __A,
            (__v4sf) __B,
            (__v4sf) __W,
            (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_xor_ps (__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_xorps128_mask ((__v4sf) __A,
            (__v4sf) __B,
            (__v4sf)
            _mm_setzero_ps (),
            (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_mask_or_pd (__m256d __W, __mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_orpd256_mask ((__v4df) __A,
            (__v4df) __B,
            (__v4df) __W,
            (__mmask8) __U);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_maskz_or_pd (__mmask8 __U, __m256d __A, __m256d __B) {
  return (__m256d) __builtin_ia32_orpd256_mask ((__v4df) __A,
            (__v4df) __B,
            (__v4df)
            _mm256_setzero_pd (),
            (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_mask_or_pd (__m128d __W, __mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_orpd128_mask ((__v2df) __A,
            (__v2df) __B,
            (__v2df) __W,
            (__mmask8) __U);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_maskz_or_pd (__mmask8 __U, __m128d __A, __m128d __B) {
  return (__m128d) __builtin_ia32_orpd128_mask ((__v2df) __A,
            (__v2df) __B,
            (__v2df)
            _mm_setzero_pd (),
            (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_mask_or_ps (__m256 __W, __mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_orps256_mask ((__v8sf) __A,
                 (__v8sf) __B,
                 (__v8sf) __W,
                 (__mmask8) __U);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_maskz_or_ps (__mmask8 __U, __m256 __A, __m256 __B) {
  return (__m256) __builtin_ia32_orps256_mask ((__v8sf) __A,
                 (__v8sf) __B,
                 (__v8sf)
                 _mm256_setzero_ps (),
                 (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_mask_or_ps (__m128 __W, __mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_orps128_mask ((__v4sf) __A,
                 (__v4sf) __B,
                 (__v4sf) __W,
                 (__mmask8) __U);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_maskz_or_ps (__mmask8 __U, __m128 __A, __m128 __B) {
  return (__m128) __builtin_ia32_orps128_mask ((__v4sf) __A,
                 (__v4sf) __B,
                 (__v4sf)
                 _mm_setzero_ps (),
                 (__mmask8) __U);
}

#undef __DEFAULT_FN_ATTRS

#endif
