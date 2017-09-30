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
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx512dq")))

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mullo_epi64 (__m512i __A, __m512i __B) {
  return (__m512i) ((__v8du) __A * (__v8du) __B);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_mullo_epi64(__m512i __W, __mmask8 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectq_512((__mmask8)__U,
                                             (__v8di)_mm512_mullo_epi64(__A, __B),
                                             (__v8di)__W);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_mullo_epi64(__mmask8 __U, __m512i __A, __m512i __B) {
  return (__m512i)__builtin_ia32_selectq_512((__mmask8)__U,
                                             (__v8di)_mm512_mullo_epi64(__A, __B),
                                             (__v8di)_mm512_setzero_si512());
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_xor_pd(__m512d __A, __m512d __B) {
  return (__m512d)((__v8du)__A ^ (__v8du)__B);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_xor_pd(__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_xor_pd(__A, __B),
                                              (__v8df)__W);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_xor_pd(__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_xor_pd(__A, __B),
                                              (__v8df)_mm512_setzero_pd());
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_xor_ps (__m512 __A, __m512 __B) {
  return (__m512)((__v16su)__A ^ (__v16su)__B);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_xor_ps(__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_xor_ps(__A, __B),
                                             (__v16sf)__W);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_xor_ps(__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_xor_ps(__A, __B),
                                             (__v16sf)_mm512_setzero_ps());
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_or_pd(__m512d __A, __m512d __B) {
  return (__m512d)((__v8du)__A | (__v8du)__B);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_or_pd(__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_or_pd(__A, __B),
                                              (__v8df)__W);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_or_pd(__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_or_pd(__A, __B),
                                              (__v8df)_mm512_setzero_pd());
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_or_ps(__m512 __A, __m512 __B) {
  return (__m512)((__v16su)__A | (__v16su)__B);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_or_ps(__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_or_ps(__A, __B),
                                             (__v16sf)__W);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_or_ps(__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_or_ps(__A, __B),
                                             (__v16sf)_mm512_setzero_ps());
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_and_pd(__m512d __A, __m512d __B) {
  return (__m512d)((__v8du)__A & (__v8du)__B);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_and_pd(__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_and_pd(__A, __B),
                                              (__v8df)__W);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_and_pd(__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_and_pd(__A, __B),
                                              (__v8df)_mm512_setzero_pd());
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_and_ps(__m512 __A, __m512 __B) {
  return (__m512)((__v16su)__A & (__v16su)__B);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_and_ps(__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_and_ps(__A, __B),
                                             (__v16sf)__W);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_and_ps(__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_and_ps(__A, __B),
                                             (__v16sf)_mm512_setzero_ps());
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_andnot_pd(__m512d __A, __m512d __B) {
  return (__m512d)(~(__v8du)__A & (__v8du)__B);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_andnot_pd(__m512d __W, __mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_andnot_pd(__A, __B),
                                              (__v8df)__W);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_andnot_pd(__mmask8 __U, __m512d __A, __m512d __B) {
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__U,
                                              (__v8df)_mm512_andnot_pd(__A, __B),
                                              (__v8df)_mm512_setzero_pd());
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_andnot_ps(__m512 __A, __m512 __B) {
  return (__m512)(~(__v16su)__A & (__v16su)__B);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_andnot_ps(__m512 __W, __mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_andnot_ps(__A, __B),
                                             (__v16sf)__W);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_andnot_ps(__mmask16 __U, __m512 __A, __m512 __B) {
  return (__m512)__builtin_ia32_selectps_512((__mmask16)__U,
                                             (__v16sf)_mm512_andnot_ps(__A, __B),
                                             (__v16sf)_mm512_setzero_ps());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvtpd_epi64 (__m512d __A) {
  return (__m512i) __builtin_ia32_cvtpd2qq512_mask ((__v8df) __A,
                (__v8di) _mm512_setzero_si512(),
                (__mmask8) -1,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvtpd_epi64 (__m512i __W, __mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvtpd2qq512_mask ((__v8df) __A,
                (__v8di) __W,
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtpd_epi64 (__mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvtpd2qq512_mask ((__v8df) __A,
                (__v8di) _mm512_setzero_si512(),
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundpd_epi64(A, R) __extension__ ({              \
  (__m512i)__builtin_ia32_cvtpd2qq512_mask((__v8df)(__m512d)(A), \
                                           (__v8di)_mm512_setzero_si512(), \
                                           (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundpd_epi64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvtpd2qq512_mask((__v8df)(__m512d)(A), \
                                           (__v8di)(__m512i)(W), \
                                           (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvt_roundpd_epi64(U, A, R) __extension__ ({   \
  (__m512i)__builtin_ia32_cvtpd2qq512_mask((__v8df)(__m512d)(A), \
                                           (__v8di)_mm512_setzero_si512(), \
                                           (__mmask8)(U), (int)(R)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvtpd_epu64 (__m512d __A) {
  return (__m512i) __builtin_ia32_cvtpd2uqq512_mask ((__v8df) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) -1,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvtpd_epu64 (__m512i __W, __mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvtpd2uqq512_mask ((__v8df) __A,
                 (__v8di) __W,
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtpd_epu64 (__mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvtpd2uqq512_mask ((__v8df) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundpd_epu64(A, R) __extension__ ({               \
  (__m512i)__builtin_ia32_cvtpd2uqq512_mask((__v8df)(__m512d)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundpd_epu64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvtpd2uqq512_mask((__v8df)(__m512d)(A), \
                                            (__v8di)(__m512i)(W), \
                                            (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvt_roundpd_epu64(U, A, R) __extension__ ({     \
  (__m512i)__builtin_ia32_cvtpd2uqq512_mask((__v8df)(__m512d)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)(U), (int)(R)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvtps_epi64 (__m256 __A) {
  return (__m512i) __builtin_ia32_cvtps2qq512_mask ((__v8sf) __A,
                (__v8di) _mm512_setzero_si512(),
                (__mmask8) -1,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvtps_epi64 (__m512i __W, __mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvtps2qq512_mask ((__v8sf) __A,
                (__v8di) __W,
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtps_epi64 (__mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvtps2qq512_mask ((__v8sf) __A,
                (__v8di) _mm512_setzero_si512(),
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundps_epi64(A, R) __extension__ ({             \
  (__m512i)__builtin_ia32_cvtps2qq512_mask((__v8sf)(__m256)(A), \
                                           (__v8di)_mm512_setzero_si512(), \
                                           (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundps_epi64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvtps2qq512_mask((__v8sf)(__m256)(A), \
                                           (__v8di)(__m512i)(W), \
                                           (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvt_roundps_epi64(U, A, R) __extension__ ({   \
  (__m512i)__builtin_ia32_cvtps2qq512_mask((__v8sf)(__m256)(A), \
                                           (__v8di)_mm512_setzero_si512(), \
                                           (__mmask8)(U), (int)(R)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvtps_epu64 (__m256 __A) {
  return (__m512i) __builtin_ia32_cvtps2uqq512_mask ((__v8sf) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) -1,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvtps_epu64 (__m512i __W, __mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvtps2uqq512_mask ((__v8sf) __A,
                 (__v8di) __W,
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvtps_epu64 (__mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvtps2uqq512_mask ((__v8sf) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundps_epu64(A, R) __extension__ ({              \
  (__m512i)__builtin_ia32_cvtps2uqq512_mask((__v8sf)(__m256)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundps_epu64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvtps2uqq512_mask((__v8sf)(__m256)(A), \
                                            (__v8di)(__m512i)(W), \
                                            (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvt_roundps_epu64(U, A, R) __extension__ ({   \
  (__m512i)__builtin_ia32_cvtps2uqq512_mask((__v8sf)(__m256)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)(U), (int)(R)); })


static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_cvtepi64_pd (__m512i __A) {
  return (__m512d) __builtin_ia32_cvtqq2pd512_mask ((__v8di) __A,
                (__v8df) _mm512_setzero_pd(),
                (__mmask8) -1,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_cvtepi64_pd (__m512d __W, __mmask8 __U, __m512i __A) {
  return (__m512d) __builtin_ia32_cvtqq2pd512_mask ((__v8di) __A,
                (__v8df) __W,
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_cvtepi64_pd (__mmask8 __U, __m512i __A) {
  return (__m512d) __builtin_ia32_cvtqq2pd512_mask ((__v8di) __A,
                (__v8df) _mm512_setzero_pd(),
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundepi64_pd(A, R) __extension__ ({          \
  (__m512d)__builtin_ia32_cvtqq2pd512_mask((__v8di)(__m512i)(A), \
                                           (__v8df)_mm512_setzero_pd(), \
                                           (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundepi64_pd(W, U, A, R) __extension__ ({ \
  (__m512d)__builtin_ia32_cvtqq2pd512_mask((__v8di)(__m512i)(A), \
                                           (__v8df)(__m512d)(W), \
                                           (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvt_roundepi64_pd(U, A, R) __extension__ ({ \
  (__m512d)__builtin_ia32_cvtqq2pd512_mask((__v8di)(__m512i)(A), \
                                           (__v8df)_mm512_setzero_pd(), \
                                           (__mmask8)(U), (int)(R)); })

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm512_cvtepi64_ps (__m512i __A) {
  return (__m256) __builtin_ia32_cvtqq2ps512_mask ((__v8di) __A,
               (__v8sf) _mm256_setzero_ps(),
               (__mmask8) -1,
               _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm512_mask_cvtepi64_ps (__m256 __W, __mmask8 __U, __m512i __A) {
  return (__m256) __builtin_ia32_cvtqq2ps512_mask ((__v8di) __A,
               (__v8sf) __W,
               (__mmask8) __U,
               _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm512_maskz_cvtepi64_ps (__mmask8 __U, __m512i __A) {
  return (__m256) __builtin_ia32_cvtqq2ps512_mask ((__v8di) __A,
               (__v8sf) _mm256_setzero_ps(),
               (__mmask8) __U,
               _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundepi64_ps(A, R) __extension__ ({        \
  (__m256)__builtin_ia32_cvtqq2ps512_mask((__v8di)(__m512i)(A), \
                                          (__v8sf)_mm256_setzero_ps(), \
                                          (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundepi64_ps(W, U, A, R) __extension__ ({ \
  (__m256)__builtin_ia32_cvtqq2ps512_mask((__v8di)(__m512i)(A), \
                                          (__v8sf)(__m256)(W), (__mmask8)(U), \
                                          (int)(R)); })

#define _mm512_maskz_cvt_roundepi64_ps(U, A, R) __extension__ ({ \
  (__m256)__builtin_ia32_cvtqq2ps512_mask((__v8di)(__m512i)(A), \
                                          (__v8sf)_mm256_setzero_ps(), \
                                          (__mmask8)(U), (int)(R)); })


static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvttpd_epi64 (__m512d __A) {
  return (__m512i) __builtin_ia32_cvttpd2qq512_mask ((__v8df) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) -1,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvttpd_epi64 (__m512i __W, __mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvttpd2qq512_mask ((__v8df) __A,
                 (__v8di) __W,
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvttpd_epi64 (__mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvttpd2qq512_mask ((__v8df) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvtt_roundpd_epi64(A, R) __extension__ ({             \
  (__m512i)__builtin_ia32_cvttpd2qq512_mask((__v8df)(__m512d)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvtt_roundpd_epi64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvttpd2qq512_mask((__v8df)(__m512d)(A), \
                                            (__v8di)(__m512i)(W), \
                                            (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvtt_roundpd_epi64(U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvttpd2qq512_mask((__v8df)(__m512d)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)(U), (int)(R)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvttpd_epu64 (__m512d __A) {
  return (__m512i) __builtin_ia32_cvttpd2uqq512_mask ((__v8df) __A,
                  (__v8di) _mm512_setzero_si512(),
                  (__mmask8) -1,
                  _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvttpd_epu64 (__m512i __W, __mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvttpd2uqq512_mask ((__v8df) __A,
                  (__v8di) __W,
                  (__mmask8) __U,
                  _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvttpd_epu64 (__mmask8 __U, __m512d __A) {
  return (__m512i) __builtin_ia32_cvttpd2uqq512_mask ((__v8df) __A,
                  (__v8di) _mm512_setzero_si512(),
                  (__mmask8) __U,
                  _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvtt_roundpd_epu64(A, R) __extension__ ({              \
  (__m512i)__builtin_ia32_cvttpd2uqq512_mask((__v8df)(__m512d)(A), \
                                             (__v8di)_mm512_setzero_si512(), \
                                             (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvtt_roundpd_epu64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvttpd2uqq512_mask((__v8df)(__m512d)(A), \
                                             (__v8di)(__m512i)(W), \
                                             (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvtt_roundpd_epu64(U, A, R) __extension__ ({   \
  (__m512i)__builtin_ia32_cvttpd2uqq512_mask((__v8df)(__m512d)(A), \
                                             (__v8di)_mm512_setzero_si512(), \
                                             (__mmask8)(U), (int)(R)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvttps_epi64 (__m256 __A) {
  return (__m512i) __builtin_ia32_cvttps2qq512_mask ((__v8sf) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) -1,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvttps_epi64 (__m512i __W, __mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvttps2qq512_mask ((__v8sf) __A,
                 (__v8di) __W,
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvttps_epi64 (__mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvttps2qq512_mask ((__v8sf) __A,
                 (__v8di) _mm512_setzero_si512(),
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvtt_roundps_epi64(A, R) __extension__ ({            \
  (__m512i)__builtin_ia32_cvttps2qq512_mask((__v8sf)(__m256)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvtt_roundps_epi64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvttps2qq512_mask((__v8sf)(__m256)(A), \
                                            (__v8di)(__m512i)(W), \
                                            (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvtt_roundps_epi64(U, A, R) __extension__ ({  \
  (__m512i)__builtin_ia32_cvttps2qq512_mask((__v8sf)(__m256)(A), \
                                            (__v8di)_mm512_setzero_si512(), \
                                            (__mmask8)(U), (int)(R)); })

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_cvttps_epu64 (__m256 __A) {
  return (__m512i) __builtin_ia32_cvttps2uqq512_mask ((__v8sf) __A,
                  (__v8di) _mm512_setzero_si512(),
                  (__mmask8) -1,
                  _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_cvttps_epu64 (__m512i __W, __mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvttps2uqq512_mask ((__v8sf) __A,
                  (__v8di) __W,
                  (__mmask8) __U,
                  _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_cvttps_epu64 (__mmask8 __U, __m256 __A) {
  return (__m512i) __builtin_ia32_cvttps2uqq512_mask ((__v8sf) __A,
                  (__v8di) _mm512_setzero_si512(),
                  (__mmask8) __U,
                  _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvtt_roundps_epu64(A, R) __extension__ ({            \
  (__m512i)__builtin_ia32_cvttps2uqq512_mask((__v8sf)(__m256)(A), \
                                             (__v8di)_mm512_setzero_si512(), \
                                             (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvtt_roundps_epu64(W, U, A, R) __extension__ ({ \
  (__m512i)__builtin_ia32_cvttps2uqq512_mask((__v8sf)(__m256)(A), \
                                             (__v8di)(__m512i)(W), \
                                             (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_cvtt_roundps_epu64(U, A, R) __extension__ ({  \
  (__m512i)__builtin_ia32_cvttps2uqq512_mask((__v8sf)(__m256)(A), \
                                             (__v8di)_mm512_setzero_si512(), \
                                             (__mmask8)(U), (int)(R)); })

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_cvtepu64_pd (__m512i __A) {
  return (__m512d) __builtin_ia32_cvtuqq2pd512_mask ((__v8di) __A,
                 (__v8df) _mm512_setzero_pd(),
                 (__mmask8) -1,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_cvtepu64_pd (__m512d __W, __mmask8 __U, __m512i __A) {
  return (__m512d) __builtin_ia32_cvtuqq2pd512_mask ((__v8di) __A,
                 (__v8df) __W,
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_cvtepu64_pd (__mmask8 __U, __m512i __A) {
  return (__m512d) __builtin_ia32_cvtuqq2pd512_mask ((__v8di) __A,
                 (__v8df) _mm512_setzero_pd(),
                 (__mmask8) __U,
                 _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundepu64_pd(A, R) __extension__ ({          \
  (__m512d)__builtin_ia32_cvtuqq2pd512_mask((__v8di)(__m512i)(A), \
                                            (__v8df)_mm512_setzero_pd(), \
                                            (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundepu64_pd(W, U, A, R) __extension__ ({ \
  (__m512d)__builtin_ia32_cvtuqq2pd512_mask((__v8di)(__m512i)(A), \
                                            (__v8df)(__m512d)(W), \
                                            (__mmask8)(U), (int)(R)); })


#define _mm512_maskz_cvt_roundepu64_pd(U, A, R) __extension__ ({ \
  (__m512d)__builtin_ia32_cvtuqq2pd512_mask((__v8di)(__m512i)(A), \
                                            (__v8df)_mm512_setzero_pd(), \
                                            (__mmask8)(U), (int)(R)); })


static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm512_cvtepu64_ps (__m512i __A) {
  return (__m256) __builtin_ia32_cvtuqq2ps512_mask ((__v8di) __A,
                (__v8sf) _mm256_setzero_ps(),
                (__mmask8) -1,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm512_mask_cvtepu64_ps (__m256 __W, __mmask8 __U, __m512i __A) {
  return (__m256) __builtin_ia32_cvtuqq2ps512_mask ((__v8di) __A,
                (__v8sf) __W,
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm512_maskz_cvtepu64_ps (__mmask8 __U, __m512i __A) {
  return (__m256) __builtin_ia32_cvtuqq2ps512_mask ((__v8di) __A,
                (__v8sf) _mm256_setzero_ps(),
                (__mmask8) __U,
                _MM_FROUND_CUR_DIRECTION);
}

#define _mm512_cvt_roundepu64_ps(A, R) __extension__ ({         \
  (__m256)__builtin_ia32_cvtuqq2ps512_mask((__v8di)(__m512i)(A), \
                                           (__v8sf)_mm256_setzero_ps(), \
                                           (__mmask8)-1, (int)(R)); })

#define _mm512_mask_cvt_roundepu64_ps(W, U, A, R) __extension__ ({ \
  (__m256)__builtin_ia32_cvtuqq2ps512_mask((__v8di)(__m512i)(A), \
                                           (__v8sf)(__m256)(W), (__mmask8)(U), \
                                           (int)(R)); })

#define _mm512_maskz_cvt_roundepu64_ps(U, A, R) __extension__ ({ \
  (__m256)__builtin_ia32_cvtuqq2ps512_mask((__v8di)(__m512i)(A), \
                                           (__v8sf)_mm256_setzero_ps(), \
                                           (__mmask8)(U), (int)(R)); })

#define _mm512_range_pd(A, B, C) __extension__ ({                     \
  (__m512d)__builtin_ia32_rangepd512_mask((__v8df)(__m512d)(A), \
                                          (__v8df)(__m512d)(B), (int)(C), \
                                          (__v8df)_mm512_setzero_pd(), \
                                          (__mmask8)-1, \
                                          _MM_FROUND_CUR_DIRECTION); })

#define _mm512_mask_range_pd(W, U, A, B, C) __extension__ ({      \
  (__m512d)__builtin_ia32_rangepd512_mask((__v8df)(__m512d)(A), \
                                          (__v8df)(__m512d)(B), (int)(C), \
                                          (__v8df)(__m512d)(W), (__mmask8)(U), \
                                          _MM_FROUND_CUR_DIRECTION); })

#define _mm512_maskz_range_pd(U, A, B, C) __extension__ ({           \
  (__m512d)__builtin_ia32_rangepd512_mask((__v8df)(__m512d)(A), \
                                          (__v8df)(__m512d)(B), (int)(C), \
                                          (__v8df)_mm512_setzero_pd(), \
                                          (__mmask8)(U), \
                                          _MM_FROUND_CUR_DIRECTION); })

#define _mm512_range_round_pd(A, B, C, R) __extension__ ({           \
  (__m512d)__builtin_ia32_rangepd512_mask((__v8df)(__m512d)(A), \
                                          (__v8df)(__m512d)(B), (int)(C), \
                                          (__v8df)_mm512_setzero_pd(), \
                                          (__mmask8)-1, (int)(R)); })

#define _mm512_mask_range_round_pd(W, U, A, B, C, R) __extension__ ({ \
  (__m512d)__builtin_ia32_rangepd512_mask((__v8df)(__m512d)(A), \
                                          (__v8df)(__m512d)(B), (int)(C), \
                                          (__v8df)(__m512d)(W), (__mmask8)(U), \
                                          (int)(R)); })

#define _mm512_maskz_range_round_pd(U, A, B, C, R) __extension__ ({ \
  (__m512d)__builtin_ia32_rangepd512_mask((__v8df)(__m512d)(A), \
                                          (__v8df)(__m512d)(B), (int)(C), \
                                          (__v8df)_mm512_setzero_pd(), \
                                          (__mmask8)(U), (int)(R)); })

#define _mm512_range_ps(A, B, C) __extension__ ({                       \
  (__m512)__builtin_ia32_rangeps512_mask((__v16sf)(__m512)(A), \
                                         (__v16sf)(__m512)(B), (int)(C), \
                                         (__v16sf)_mm512_setzero_ps(), \
                                         (__mmask16)-1, \
                                         _MM_FROUND_CUR_DIRECTION); })

#define _mm512_mask_range_ps(W, U, A, B, C) __extension__ ({         \
  (__m512)__builtin_ia32_rangeps512_mask((__v16sf)(__m512)(A), \
                                         (__v16sf)(__m512)(B), (int)(C), \
                                         (__v16sf)(__m512)(W), (__mmask16)(U), \
                                         _MM_FROUND_CUR_DIRECTION); })

#define _mm512_maskz_range_ps(U, A, B, C) __extension__ ({      \
  (__m512)__builtin_ia32_rangeps512_mask((__v16sf)(__m512)(A), \
                                         (__v16sf)(__m512)(B), (int)(C), \
                                         (__v16sf)_mm512_setzero_ps(), \
                                         (__mmask16)(U), \
                                         _MM_FROUND_CUR_DIRECTION); })

#define _mm512_range_round_ps(A, B, C, R) __extension__ ({         \
  (__m512)__builtin_ia32_rangeps512_mask((__v16sf)(__m512)(A), \
                                         (__v16sf)(__m512)(B), (int)(C), \
                                         (__v16sf)_mm512_setzero_ps(), \
                                         (__mmask16)-1, (int)(R)); })

#define _mm512_mask_range_round_ps(W, U, A, B, C, R) __extension__ ({ \
  (__m512)__builtin_ia32_rangeps512_mask((__v16sf)(__m512)(A), \
                                         (__v16sf)(__m512)(B), (int)(C), \
                                         (__v16sf)(__m512)(W), (__mmask16)(U), \
                                         (int)(R)); })

#define _mm512_maskz_range_round_ps(U, A, B, C, R) __extension__ ({ \
  (__m512)__builtin_ia32_rangeps512_mask((__v16sf)(__m512)(A), \
                                         (__v16sf)(__m512)(B), (int)(C), \
                                         (__v16sf)_mm512_setzero_ps(), \
                                         (__mmask16)(U), (int)(R)); })

#define _mm_range_round_ss(A, B, C, R) __extension__ ({           \
  (__m128)__builtin_ia32_rangess128_round_mask((__v4sf)(__m128)(A), \
                                               (__v4sf)(__m128)(B), \
                                               (__v4sf)_mm_setzero_ps(), \
                                               (__mmask8) -1, (int)(C),\
                                               (int)(R)); })

#define _mm_range_ss(A ,B , C) _mm_range_round_ss(A, B, C ,_MM_FROUND_CUR_DIRECTION)

#define _mm_mask_range_round_ss(W, U, A, B, C, R) __extension__ ({ \
  (__m128)__builtin_ia32_rangess128_round_mask((__v4sf)(__m128)(A), \
                                               (__v4sf)(__m128)(B), \
                                               (__v4sf)(__m128)(W),\
                                               (__mmask8)(U), (int)(C),\
                                               (int)(R)); })

#define _mm_mask_range_ss(W , U, A, B, C) _mm_mask_range_round_ss(W, U, A, B, C , _MM_FROUND_CUR_DIRECTION)

#define _mm_maskz_range_round_ss(U, A, B, C, R) __extension__ ({ \
  (__m128)__builtin_ia32_rangess128_round_mask((__v4sf)(__m128)(A), \
                                               (__v4sf)(__m128)(B), \
                                               (__v4sf)_mm_setzero_ps(), \
                                               (__mmask8)(U), (int)(C),\
                                               (int)(R)); })

#define _mm_maskz_range_ss(U, A ,B , C) _mm_maskz_range_round_ss(U, A, B, C ,_MM_FROUND_CUR_DIRECTION)

#define _mm_range_round_sd(A, B, C, R) __extension__ ({           \
  (__m128d)__builtin_ia32_rangesd128_round_mask((__v2df)(__m128d)(A), \
                                                (__v2df)(__m128d)(B), \
                                                (__v2df)_mm_setzero_pd(), \
                                                (__mmask8) -1, (int)(C),\
                                                (int)(R)); })

#define _mm_range_sd(A ,B , C) _mm_range_round_sd(A, B, C ,_MM_FROUND_CUR_DIRECTION)

#define _mm_mask_range_round_sd(W, U, A, B, C, R) __extension__ ({ \
  (__m128d)__builtin_ia32_rangesd128_round_mask((__v2df)(__m128d)(A), \
                                                (__v2df)(__m128d)(B), \
                                                (__v2df)(__m128d)(W),\
                                                (__mmask8)(U), (int)(C),\
                                                (int)(R)); })

#define _mm_mask_range_sd(W, U, A, B, C) _mm_mask_range_round_sd(W, U, A, B, C ,_MM_FROUND_CUR_DIRECTION)

#define _mm_maskz_range_round_sd(U, A, B, C, R) __extension__ ({ \
  (__m128d)__builtin_ia32_rangesd128_round_mask((__v2df)(__m128d)(A), \
                                                (__v2df)(__m128d)(B), \
                                                (__v2df)_mm_setzero_pd(), \
                                                (__mmask8)(U), (int)(C),\
                                                (int)(R)); })

#define _mm_maskz_range_sd(U, A, B, C) _mm_maskz_range_round_sd(U, A, B, C ,_MM_FROUND_CUR_DIRECTION)

#define _mm512_reduce_pd(A, B) __extension__ ({             \
  (__m512d)__builtin_ia32_reducepd512_mask((__v8df)(__m512d)(A), (int)(B), \
                                           (__v8df)_mm512_setzero_pd(), \
                                           (__mmask8)-1, \
                                           _MM_FROUND_CUR_DIRECTION); })

#define _mm512_mask_reduce_pd(W, U, A, B) __extension__ ({ \
  (__m512d)__builtin_ia32_reducepd512_mask((__v8df)(__m512d)(A), (int)(B), \
                                           (__v8df)(__m512d)(W), \
                                           (__mmask8)(U), \
                                           _MM_FROUND_CUR_DIRECTION); })

#define _mm512_maskz_reduce_pd(U, A, B) __extension__ ({  \
  (__m512d)__builtin_ia32_reducepd512_mask((__v8df)(__m512d)(A), (int)(B), \
                                           (__v8df)_mm512_setzero_pd(), \
                                           (__mmask8)(U), \
                                           _MM_FROUND_CUR_DIRECTION); })

#define _mm512_reduce_ps(A, B) __extension__ ({              \
  (__m512)__builtin_ia32_reduceps512_mask((__v16sf)(__m512)(A), (int)(B), \
                                          (__v16sf)_mm512_setzero_ps(), \
                                          (__mmask16)-1, \
                                          _MM_FROUND_CUR_DIRECTION); })

#define _mm512_mask_reduce_ps(W, U, A, B) __extension__ ({   \
  (__m512)__builtin_ia32_reduceps512_mask((__v16sf)(__m512)(A), (int)(B), \
                                          (__v16sf)(__m512)(W), \
                                          (__mmask16)(U), \
                                          _MM_FROUND_CUR_DIRECTION); })

#define _mm512_maskz_reduce_ps(U, A, B) __extension__ ({       \
  (__m512)__builtin_ia32_reduceps512_mask((__v16sf)(__m512)(A), (int)(B), \
                                          (__v16sf)_mm512_setzero_ps(), \
                                          (__mmask16)(U), \
                                          _MM_FROUND_CUR_DIRECTION); })

#define _mm512_reduce_round_pd(A, B, R) __extension__ ({\
  (__m512d)__builtin_ia32_reducepd512_mask((__v8df)(__m512d)(A), (int)(B), \
                                           (__v8df)_mm512_setzero_pd(), \
                                           (__mmask8)-1, (int)(R)); })

#define _mm512_mask_reduce_round_pd(W, U, A, B, R) __extension__ ({\
  (__m512d)__builtin_ia32_reducepd512_mask((__v8df)(__m512d)(A), (int)(B), \
                                           (__v8df)(__m512d)(W), \
                                           (__mmask8)(U), (int)(R)); })

#define _mm512_maskz_reduce_round_pd(U, A, B, R) __extension__ ({\
  (__m512d)__builtin_ia32_reducepd512_mask((__v8df)(__m512d)(A), (int)(B), \
                                           (__v8df)_mm512_setzero_pd(), \
                                           (__mmask8)(U), (int)(R)); })

#define _mm512_reduce_round_ps(A, B, R) __extension__ ({\
  (__m512)__builtin_ia32_reduceps512_mask((__v16sf)(__m512)(A), (int)(B), \
                                          (__v16sf)_mm512_setzero_ps(), \
                                          (__mmask16)-1, (int)(R)); })

#define _mm512_mask_reduce_round_ps(W, U, A, B, R) __extension__ ({\
  (__m512)__builtin_ia32_reduceps512_mask((__v16sf)(__m512)(A), (int)(B), \
                                          (__v16sf)(__m512)(W), \
                                          (__mmask16)(U), (int)(R)); })

#define _mm512_maskz_reduce_round_ps(U, A, B, R) __extension__ ({\
  (__m512)__builtin_ia32_reduceps512_mask((__v16sf)(__m512)(A), (int)(B), \
                                          (__v16sf)_mm512_setzero_ps(), \
                                          (__mmask16)(U), (int)(R)); })

#define _mm_reduce_ss(A, B, C) __extension__ ({              \
  (__m128)__builtin_ia32_reducess_mask((__v4sf)(__m128)(A), \
                                       (__v4sf)(__m128)(B), \
                                       (__v4sf)_mm_setzero_ps(), (__mmask8)-1, \
                                       (int)(C), _MM_FROUND_CUR_DIRECTION); })

#define _mm_mask_reduce_ss(W, U, A, B, C) __extension__ ({   \
  (__m128)__builtin_ia32_reducess_mask((__v4sf)(__m128)(A), \
                                       (__v4sf)(__m128)(B), \
                                       (__v4sf)(__m128)(W), (__mmask8)(U), \
                                       (int)(C), _MM_FROUND_CUR_DIRECTION); })

#define _mm_maskz_reduce_ss(U, A, B, C) __extension__ ({       \
  (__m128)__builtin_ia32_reducess_mask((__v4sf)(__m128)(A), \
                                       (__v4sf)(__m128)(B), \
                                       (__v4sf)_mm_setzero_ps(), \
                                       (__mmask8)(U), (int)(C), \
                                       _MM_FROUND_CUR_DIRECTION); })

#define _mm_reduce_round_ss(A, B, C, R) __extension__ ({              \
  (__m128)__builtin_ia32_reducess_mask((__v4sf)(__m128)(A), \
                                       (__v4sf)(__m128)(B), \
                                       (__v4sf)_mm_setzero_ps(), (__mmask8)-1, \
                                       (int)(C), (int)(R)); })

#define _mm_mask_reduce_round_ss(W, U, A, B, C, R) __extension__ ({   \
  (__m128)__builtin_ia32_reducess_mask((__v4sf)(__m128)(A), \
                                       (__v4sf)(__m128)(B), \
                                       (__v4sf)(__m128)(W), (__mmask8)(U), \
                                       (int)(C), (int)(R)); })

#define _mm_maskz_reduce_round_ss(U, A, B, C, R) __extension__ ({       \
  (__m128)__builtin_ia32_reducess_mask((__v4sf)(__m128)(A), \
                                       (__v4sf)(__m128)(B), \
                                       (__v4sf)_mm_setzero_ps(), \
                                       (__mmask8)(U), (int)(C), (int)(R)); })

#define _mm_reduce_sd(A, B, C) __extension__ ({              \
  (__m128d)__builtin_ia32_reducesd_mask((__v2df)(__m128d)(A), \
                                        (__v2df)(__m128d)(B), \
                                        (__v2df)_mm_setzero_pd(), \
                                        (__mmask8)-1, (int)(C), \
                                        _MM_FROUND_CUR_DIRECTION); })

#define _mm_mask_reduce_sd(W, U, A, B, C) __extension__ ({   \
  (__m128d)__builtin_ia32_reducesd_mask((__v2df)(__m128d)(A), \
                                        (__v2df)(__m128d)(B), \
                                        (__v2df)(__m128d)(W), (__mmask8)(U), \
                                        (int)(C), _MM_FROUND_CUR_DIRECTION); })

#define _mm_maskz_reduce_sd(U, A, B, C) __extension__ ({       \
  (__m128d)__builtin_ia32_reducesd_mask((__v2df)(__m128d)(A), \
                                        (__v2df)(__m128d)(B), \
                                        (__v2df)_mm_setzero_pd(), \
                                        (__mmask8)(U), (int)(C), \
                                        _MM_FROUND_CUR_DIRECTION); })

#define _mm_reduce_round_sd(A, B, C, R) __extension__ ({              \
  (__m128d)__builtin_ia32_reducesd_mask((__v2df)(__m128d)(A), \
                                        (__v2df)(__m128d)(B), \
                                        (__v2df)_mm_setzero_pd(), \
                                        (__mmask8)-1, (int)(C), (int)(R)); })

#define _mm_mask_reduce_round_sd(W, U, A, B, C, R) __extension__ ({   \
  (__m128d)__builtin_ia32_reducesd_mask((__v2df)(__m128d)(A), \
                                        (__v2df)(__m128d)(B), \
                                        (__v2df)(__m128d)(W), (__mmask8)(U), \
                                        (int)(C), (int)(R)); })

#define _mm_maskz_reduce_round_sd(U, A, B, C, R) __extension__ ({       \
  (__m128d)__builtin_ia32_reducesd_mask((__v2df)(__m128d)(A), \
                                        (__v2df)(__m128d)(B), \
                                        (__v2df)_mm_setzero_pd(), \
                                        (__mmask8)(U), (int)(C), (int)(R)); })
                     
static __inline__ __mmask16 __DEFAULT_FN_ATTRS
_mm512_movepi32_mask (__m512i __A)
{
  return (__mmask16) __builtin_ia32_cvtd2mask512 ((__v16si) __A);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_movm_epi32 (__mmask16 __A)
{
  return (__m512i) __builtin_ia32_cvtmask2d512 (__A);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_movm_epi64 (__mmask8 __A)
{
  return (__m512i) __builtin_ia32_cvtmask2q512 (__A);
}

static __inline__ __mmask8 __DEFAULT_FN_ATTRS
_mm512_movepi64_mask (__m512i __A)
{
  return (__mmask8) __builtin_ia32_cvtq2mask512 ((__v8di) __A);
}


static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_broadcast_f32x2 (__m128 __A)
{
  return (__m512) __builtin_ia32_broadcastf32x2_512_mask ((__v4sf) __A,
                (__v16sf)_mm512_undefined_ps(),
                (__mmask16) -1);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_broadcast_f32x2 (__m512 __O, __mmask16 __M, __m128 __A)
{
  return (__m512) __builtin_ia32_broadcastf32x2_512_mask ((__v4sf) __A,
                (__v16sf)
                __O, __M);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_broadcast_f32x2 (__mmask16 __M, __m128 __A)
{
  return (__m512) __builtin_ia32_broadcastf32x2_512_mask ((__v4sf) __A,
                (__v16sf)_mm512_setzero_ps (),
                __M);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_broadcast_f32x8(__m256 __A)
{
  return (__m512)__builtin_shufflevector((__v8sf)__A, (__v8sf)__A,
                                         0, 1, 2, 3, 4, 5, 6, 7,
                                         0, 1, 2, 3, 4, 5, 6, 7);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_mask_broadcast_f32x8(__m512 __O, __mmask16 __M, __m256 __A)
{
  return (__m512)__builtin_ia32_selectps_512((__mmask8)__M,
                                           (__v16sf)_mm512_broadcast_f32x8(__A),
                                           (__v16sf)__O);
}

static __inline__ __m512 __DEFAULT_FN_ATTRS
_mm512_maskz_broadcast_f32x8(__mmask16 __M, __m256 __A)
{
  return (__m512)__builtin_ia32_selectps_512((__mmask8)__M,
                                           (__v16sf)_mm512_broadcast_f32x8(__A),
                                           (__v16sf)_mm512_setzero_ps());
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_broadcast_f64x2(__m128d __A)
{
  return (__m512d)__builtin_shufflevector((__v2df)__A, (__v2df)__A,
                                          0, 1, 0, 1, 0, 1, 0, 1);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_mask_broadcast_f64x2(__m512d __O, __mmask8 __M, __m128d __A)
{
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__M,
                                            (__v8df)_mm512_broadcast_f64x2(__A),
                                            (__v8df)__O);
}

static __inline__ __m512d __DEFAULT_FN_ATTRS
_mm512_maskz_broadcast_f64x2(__mmask8 __M, __m128d __A)
{
  return (__m512d)__builtin_ia32_selectpd_512((__mmask8)__M,
                                            (__v8df)_mm512_broadcast_f64x2(__A),
                                            (__v8df)_mm512_setzero_pd());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_broadcast_i32x2 (__m128i __A)
{
  return (__m512i) __builtin_ia32_broadcasti32x2_512_mask ((__v4si) __A,
                 (__v16si)_mm512_setzero_si512(),
                 (__mmask16) -1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_broadcast_i32x2 (__m512i __O, __mmask16 __M, __m128i __A)
{
  return (__m512i) __builtin_ia32_broadcasti32x2_512_mask ((__v4si) __A,
                 (__v16si)
                 __O, __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_broadcast_i32x2 (__mmask16 __M, __m128i __A)
{
  return (__m512i) __builtin_ia32_broadcasti32x2_512_mask ((__v4si) __A,
                 (__v16si)_mm512_setzero_si512 (),
                 __M);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_broadcast_i32x8(__m256i __A)
{
  return (__m512i)__builtin_shufflevector((__v8si)__A, (__v8si)__A,
                                          0, 1, 2, 3, 4, 5, 6, 7,
                                          0, 1, 2, 3, 4, 5, 6, 7);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_broadcast_i32x8(__m512i __O, __mmask16 __M, __m256i __A)
{
  return (__m512i)__builtin_ia32_selectd_512((__mmask8)__M,
                                           (__v16si)_mm512_broadcast_i32x8(__A),
                                           (__v16si)__O);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_broadcast_i32x8(__mmask16 __M, __m256i __A)
{
  return (__m512i)__builtin_ia32_selectd_512((__mmask8)__M,
                                           (__v16si)_mm512_broadcast_i32x8(__A),
                                           (__v16si)_mm512_setzero_si512());
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_broadcast_i64x2(__m128i __A)
{
  return (__m512i)__builtin_shufflevector((__v2di)__A, (__v2di)__A,
                                          0, 1, 0, 1, 0, 1, 0, 1);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_mask_broadcast_i64x2(__m512i __O, __mmask8 __M, __m128i __A)
{
  return (__m512i)__builtin_ia32_selectq_512((__mmask8)__M,
                                            (__v8di)_mm512_broadcast_i64x2(__A),
                                            (__v8di)__O);
}

static __inline__ __m512i __DEFAULT_FN_ATTRS
_mm512_maskz_broadcast_i64x2(__mmask8 __M, __m128i __A)
{
  return (__m512i)__builtin_ia32_selectq_512((__mmask8)__M,
                                            (__v8di)_mm512_broadcast_i64x2(__A),
                                            (__v8di)_mm512_setzero_si512());
}

#define _mm512_extractf32x8_ps(A, imm) __extension__ ({ \
  (__m256)__builtin_shufflevector((__v16sf)(__m512)(A),           \
                                  (__v16sf)_mm512_undefined_ps(), \
                                  ((imm) & 1) ?  8 : 0,           \
                                  ((imm) & 1) ?  9 : 1,           \
                                  ((imm) & 1) ? 10 : 2,           \
                                  ((imm) & 1) ? 11 : 3,           \
                                  ((imm) & 1) ? 12 : 4,           \
                                  ((imm) & 1) ? 13 : 5,           \
                                  ((imm) & 1) ? 14 : 6,           \
                                  ((imm) & 1) ? 15 : 7); })

#define _mm512_mask_extractf32x8_ps(W, U, A, imm) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                   (__v8sf)_mm512_extractf32x8_ps((A), (imm)), \
                                   (__v8sf)(W)); })

#define _mm512_maskz_extractf32x8_ps(U, A, imm) __extension__ ({ \
  (__m256)__builtin_ia32_selectps_256((__mmask8)(U), \
                                   (__v8sf)_mm512_extractf32x8_ps((A), (imm)), \
                                   (__v8sf)_mm256_setzero_ps()); })

#define _mm512_extractf64x2_pd(A, imm) __extension__ ({ \
  (__m128d)__builtin_shufflevector((__v8df)(__m512d)(A),          \
                                   (__v8df)_mm512_undefined_pd(), \
                                   0 + ((imm) & 0x3) * 2,         \
                                   1 + ((imm) & 0x3) * 2); })

#define _mm512_mask_extractf64x2_pd(W, U, A, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_selectpd_128((__mmask8)(U), \
                                   (__v2df)_mm512_extractf64x2_pd((A), (imm)), \
                                   (__v2df)(W)); })

#define _mm512_maskz_extractf64x2_pd(U, A, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_selectpd_128((__mmask8)(U), \
                                   (__v2df)_mm512_extractf64x2_pd((A), (imm)), \
                                   (__v2df)_mm_setzero_pd()); })

#define _mm512_extracti32x8_epi32(A, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v16si)(__m512i)(A),             \
                                   (__v16si)_mm512_undefined_epi32(), \
                                   ((imm) & 1) ?  8 : 0,              \
                                   ((imm) & 1) ?  9 : 1,              \
                                   ((imm) & 1) ? 10 : 2,              \
                                   ((imm) & 1) ? 11 : 3,              \
                                   ((imm) & 1) ? 12 : 4,              \
                                   ((imm) & 1) ? 13 : 5,              \
                                   ((imm) & 1) ? 14 : 6,              \
                                   ((imm) & 1) ? 15 : 7); })

#define _mm512_mask_extracti32x8_epi32(W, U, A, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                (__v8si)_mm512_extracti32x8_epi32((A), (imm)), \
                                (__v8si)(W)); })

#define _mm512_maskz_extracti32x8_epi32(U, A, imm) __extension__ ({ \
  (__m256i)__builtin_ia32_selectd_256((__mmask8)(U), \
                                (__v8si)_mm512_extracti32x8_epi32((A), (imm)), \
                                (__v8si)_mm256_setzero_si256()); })

#define _mm512_extracti64x2_epi64(A, imm) __extension__ ({ \
  (__m128i)__builtin_shufflevector((__v8di)(__m512i)(A),          \
                                   (__v8di)_mm512_undefined_epi32(), \
                                   0 + ((imm) & 0x3) * 2,           \
                                   1 + ((imm) & 0x3) * 2); })

#define _mm512_mask_extracti64x2_epi64(W, U, A, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_selectq_128((__mmask8)(U), \
                                (__v2di)_mm512_extracti64x2_epi64((A), (imm)), \
                                (__v2di)(W)); })

#define _mm512_maskz_extracti64x2_epi64(U, A, imm) __extension__ ({ \
  (__m128d)__builtin_ia32_selectq_128((__mmask8)(U), \
                                (__v2di)_mm512_extracti64x2_epi64((A), (imm)), \
                                (__v2di)_mm_setzero_di()); })

#define _mm512_insertf32x8(A, B, imm) __extension__ ({ \
  (__m512)__builtin_shufflevector((__v16sf)(__m512)(A), \
                                  (__v16sf)_mm512_castps256_ps512((__m256)(B)),\
                                  ((imm) & 0x1) ?  0 : 16, \
                                  ((imm) & 0x1) ?  1 : 17, \
                                  ((imm) & 0x1) ?  2 : 18, \
                                  ((imm) & 0x1) ?  3 : 19, \
                                  ((imm) & 0x1) ?  4 : 20, \
                                  ((imm) & 0x1) ?  5 : 21, \
                                  ((imm) & 0x1) ?  6 : 22, \
                                  ((imm) & 0x1) ?  7 : 23, \
                                  ((imm) & 0x1) ? 16 :  8, \
                                  ((imm) & 0x1) ? 17 :  9, \
                                  ((imm) & 0x1) ? 18 : 10, \
                                  ((imm) & 0x1) ? 19 : 11, \
                                  ((imm) & 0x1) ? 20 : 12, \
                                  ((imm) & 0x1) ? 21 : 13, \
                                  ((imm) & 0x1) ? 22 : 14, \
                                  ((imm) & 0x1) ? 23 : 15); })

#define _mm512_mask_insertf32x8(W, U, A, B, imm) __extension__ ({ \
  (__m512)__builtin_ia32_selectps_512((__mmask16)(U), \
                                 (__v16sf)_mm512_insertf32x8((A), (B), (imm)), \
                                 (__v16sf)(W)); })

#define _mm512_maskz_insertf32x8(U, A, B, imm) __extension__ ({ \
  (__m512)__builtin_ia32_selectps_512((__mmask16)(U), \
                                 (__v16sf)_mm512_insertf32x8((A), (B), (imm)), \
                                 (__v16sf)_mm512_setzero_ps()); })

#define _mm512_insertf64x2(A, B, imm) __extension__ ({ \
  (__m512d)__builtin_shufflevector((__v8df)(__m512d)(A), \
                                  (__v8df)_mm512_castpd128_pd512((__m128d)(B)),\
                                  (((imm) & 0x3) == 0) ? 8 : 0, \
                                  (((imm) & 0x3) == 0) ? 9 : 1, \
                                  (((imm) & 0x3) == 1) ? 8 : 2, \
                                  (((imm) & 0x3) == 1) ? 9 : 3, \
                                  (((imm) & 0x3) == 2) ? 8 : 4, \
                                  (((imm) & 0x3) == 2) ? 9 : 5, \
                                  (((imm) & 0x3) == 3) ? 8 : 6, \
                                  (((imm) & 0x3) == 3) ? 9 : 7); })

#define _mm512_mask_insertf64x2(W, U, A, B, imm) __extension__ ({ \
  (__m512d)__builtin_ia32_selectpd_512((__mmask8)(U), \
                                  (__v8df)_mm512_insertf64x2((A), (B), (imm)), \
                                  (__v8df)(W)); })

#define _mm512_maskz_insertf64x2(U, A, B, imm) __extension__ ({ \
  (__m512d)__builtin_ia32_selectpd_512((__mmask8)(U), \
                                  (__v8df)_mm512_insertf64x2((A), (B), (imm)), \
                                  (__v8df)_mm512_setzero_pd()); })

#define _mm512_inserti32x8(A, B, imm) __extension__ ({ \
  (__m512i)__builtin_shufflevector((__v16si)(__m512i)(A), \
                                 (__v16si)_mm512_castsi256_si512((__m256i)(B)),\
                                 ((imm) & 0x1) ?  0 : 16, \
                                 ((imm) & 0x1) ?  1 : 17, \
                                 ((imm) & 0x1) ?  2 : 18, \
                                 ((imm) & 0x1) ?  3 : 19, \
                                 ((imm) & 0x1) ?  4 : 20, \
                                 ((imm) & 0x1) ?  5 : 21, \
                                 ((imm) & 0x1) ?  6 : 22, \
                                 ((imm) & 0x1) ?  7 : 23, \
                                 ((imm) & 0x1) ? 16 :  8, \
                                 ((imm) & 0x1) ? 17 :  9, \
                                 ((imm) & 0x1) ? 18 : 10, \
                                 ((imm) & 0x1) ? 19 : 11, \
                                 ((imm) & 0x1) ? 20 : 12, \
                                 ((imm) & 0x1) ? 21 : 13, \
                                 ((imm) & 0x1) ? 22 : 14, \
                                 ((imm) & 0x1) ? 23 : 15); })

#define _mm512_mask_inserti32x8(W, U, A, B, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectd_512((__mmask16)(U), \
                                 (__v16si)_mm512_inserti32x8((A), (B), (imm)), \
                                 (__v16si)(W)); })

#define _mm512_maskz_inserti32x8(U, A, B, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectd_512((__mmask16)(U), \
                                 (__v16si)_mm512_inserti32x8((A), (B), (imm)), \
                                 (__v16si)_mm512_setzero_si512()); })

#define _mm512_inserti64x2(A, B, imm) __extension__ ({ \
  (__m512i)__builtin_shufflevector((__v8di)(__m512i)(A), \
                                  (__v8di)_mm512_castsi128_si512((__m128i)(B)),\
                                  (((imm) & 0x3) == 0) ? 8 : 0, \
                                  (((imm) & 0x3) == 0) ? 9 : 1, \
                                  (((imm) & 0x3) == 1) ? 8 : 2, \
                                  (((imm) & 0x3) == 1) ? 9 : 3, \
                                  (((imm) & 0x3) == 2) ? 8 : 4, \
                                  (((imm) & 0x3) == 2) ? 9 : 5, \
                                  (((imm) & 0x3) == 3) ? 8 : 6, \
                                  (((imm) & 0x3) == 3) ? 9 : 7); })

#define _mm512_mask_inserti64x2(W, U, A, B, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectq_512((__mmask8)(U), \
                                  (__v8di)_mm512_inserti64x2((A), (B), (imm)), \
                                  (__v8di)(W)); })

#define _mm512_maskz_inserti64x2(U, A, B, imm) __extension__ ({ \
  (__m512i)__builtin_ia32_selectq_512((__mmask8)(U), \
                                  (__v8di)_mm512_inserti64x2((A), (B), (imm)), \
                                  (__v8di)_mm512_setzero_si512()); })

#define _mm512_mask_fpclass_ps_mask(U, A, imm) __extension__ ({ \
  (__mmask16)__builtin_ia32_fpclassps512_mask((__v16sf)(__m512)(A), \
                                              (int)(imm), (__mmask16)(U)); })

#define _mm512_fpclass_ps_mask(A, imm) __extension__ ({ \
  (__mmask16)__builtin_ia32_fpclassps512_mask((__v16sf)(__m512)(A), \
                                              (int)(imm), (__mmask16)-1); })

#define _mm512_mask_fpclass_pd_mask(U, A, imm) __extension__ ({ \
  (__mmask8)__builtin_ia32_fpclasspd512_mask((__v8df)(__m512d)(A), (int)(imm), \
                                             (__mmask8)(U)); })

#define _mm512_fpclass_pd_mask(A, imm) __extension__ ({ \
  (__mmask8)__builtin_ia32_fpclasspd512_mask((__v8df)(__m512d)(A), (int)(imm), \
                                             (__mmask8)-1); })

#define _mm_fpclass_sd_mask(A, imm) __extension__ ({ \
  (__mmask8)__builtin_ia32_fpclasssd_mask((__v2df)(__m128d)(A), (int)(imm), \
                                          (__mmask8)-1); })

#define _mm_mask_fpclass_sd_mask(U, A, imm) __extension__ ({ \
  (__mmask8)__builtin_ia32_fpclasssd_mask((__v2df)(__m128d)(A), (int)(imm), \
                                          (__mmask8)(U)); })

#define _mm_fpclass_ss_mask(A, imm) __extension__ ({ \
  (__mmask8)__builtin_ia32_fpclassss_mask((__v4sf)(__m128)(A), (int)(imm), \
                                          (__mmask8)-1); })

#define _mm_mask_fpclass_ss_mask(U, A, imm) __extension__ ({ \
  (__mmask8)__builtin_ia32_fpclassss_mask((__v4sf)(__m128)(A), (int)(imm), \
                                          (__mmask8)(U)); })

#undef __DEFAULT_FN_ATTRS

#endif
