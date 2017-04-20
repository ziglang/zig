/*===---- avx512dqintrin.h - AVX512DQ intrinsics ---------------------------===
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
#error "Never use <avx512dqintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512DQINTRIN_H
#define __AVX512DQINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__))

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mullo_epi64 (__m512i __A, __m512i __B) {
  return (__m512i) ((__v8di) __A * (__v8di) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mullo_epi64 (__m512i __W, __mmask8 __U, __m512i __A, __m512i __B) {
  return (__m512i) __builtin_ia32_pmullq512_mask ((__v8di) __A,
              (__v8di) __B,
              (__v8di) __W,
              (__mmask8) __U);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mullo_epi64 (__mmask8 __U, __m512i __A, __m512i __B) {
  return (__m512i) __builtin_ia32_pmullq512_mask ((__v8di) __A,
              (__v8di) __B,
              (__v8di)
              _mm512_setzero_si512 (),
              (__mmask8) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_xor_pd (__m512d __A, __m512d __B) {
  return (__m512d) ((__v8di) __A ^ (__v8di) __B);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_xor_pd (__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_xorpd512_mask ((__v8df) __A,
             (__v8df) __B,
             (__v8df) __W,
             (__mmask8) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_xor_pd (__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_xorpd512_mask ((__v8df) __A,
             (__v8df) __B,
             (__v8df)
             _mm512_setzero_pd (),
             (__mmask8) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_xor_ps (__m512 __A, __m512 __B) {
  return (__m512) ((__v16si) __A ^ (__v16si) __B);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_xor_ps (__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_xorps512_mask ((__v16sf) __A,
            (__v16sf) __B,
            (__v16sf) __W,
            (__mmask16) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_xor_ps (__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_xorps512_mask ((__v16sf) __A,
            (__v16sf) __B,
            (__v16sf)
            _mm512_setzero_ps (),
            (__mmask16) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_or_pd (__m512d __A, __m512d __B) {
  return (__m512d) ((__v8di) __A | (__v8di) __B);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_or_pd (__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_orpd512_mask ((__v8df) __A,
            (__v8df) __B,
            (__v8df) __W,
            (__mmask8) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_or_pd (__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_orpd512_mask ((__v8df) __A,
            (__v8df) __B,
            (__v8df)
            _mm512_setzero_pd (),
            (__mmask8) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_or_ps (__m512 __A, __m512 __B) {
  return (__m512) ((__v16si) __A | (__v16si) __B);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_or_ps (__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_orps512_mask ((__v16sf) __A,
                 (__v16sf) __B,
                 (__v16sf) __W,
                 (__mmask16) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_or_ps (__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_orps512_mask ((__v16sf) __A,
                 (__v16sf) __B,
                 (__v16sf)
                 _mm512_setzero_ps (),
                 (__mmask16) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_and_pd (__m512d __A, __m512d __B) {
  return (__m512d) ((__v8di) __A & (__v8di) __B);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_and_pd (__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_andpd512_mask ((__v8df) __A,
             (__v8df) __B,
             (__v8df) __W,
             (__mmask8) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_and_pd (__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_andpd512_mask ((__v8df) __A,
             (__v8df) __B,
             (__v8df)
             _mm512_setzero_pd (),
             (__mmask8) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_and_ps (__m512 __A, __m512 __B) {
  return (__m512) ((__v16si) __A & (__v16si) __B);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_and_ps (__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_andps512_mask ((__v16sf) __A,
            (__v16sf) __B,
            (__v16sf) __W,
            (__mmask16) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_and_ps (__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_andps512_mask ((__v16sf) __A,
            (__v16sf) __B,
            (__v16sf)
            _mm512_setzero_ps (),
            (__mmask16) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_andnot_pd (__m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_andnpd512_mask ((__v8df) __A,
              (__v8df) __B,
              (__v8df)
              _mm512_setzero_pd (),
              (__mmask8) -1);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_andnot_pd (__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_andnpd512_mask ((__v8df) __A,
              (__v8df) __B,
              (__v8df) __W,
              (__mmask8) __U);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_andnot_pd (__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d) __builtin_ia32_andnpd512_mask ((__v8df) __A,
              (__v8df) __B,
              (__v8df)
              _mm512_setzero_pd (),
              (__mmask8) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_andnot_ps (__m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_andnps512_mask ((__v16sf) __A,
             (__v16sf) __B,
             (__v16sf)
             _mm512_setzero_ps (),
             (__mmask16) -1);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_andnot_ps (__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_andnps512_mask ((__v16sf) __A,
             (__v16sf) __B,
             (__v16sf) __W,
             (__mmask16) __U);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_andnot_ps (__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512) __builtin_ia32_andnps512_mask ((__v16sf) __A,
             (__v16sf) __B,
             (__v16sf)
             _mm512_setzero_ps (),
             (__mmask16) __U);
}

#undef __DEFAULT_FN_ATTRS

#endif
