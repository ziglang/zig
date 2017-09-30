/*===---- avx2intrin.h - AVX2 intrinsics -----------------------------------===
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
#error "Never use <avx2intrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX2INTRIN_H
#define __AVX2INTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("avx2")))

/* SSE4 Multiple Packed Sums of Absolute Difference.  */
#define _mm256_mpsadbw_epu8(X, Y, M) \
  (__m256i)__builtin_ia32_mpsadbw256((__v32qi)(__m256i)(X), \
                                     (__v32qi)(__m256i)(Y), (int)(M))

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_abs_epi8(__m256i __a)
{
    return (__m256i)__builtin_ia32_pabsb256((__v32qi)__a);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_abs_epi16(__m256i __a)
{
    return (__m256i)__builtin_ia32_pabsw256((__v16hi)__a);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_abs_epi32(__m256i __a)
{
    return (__m256i)__builtin_ia32_pabsd256((__v8si)__a);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_packs_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_packsswb256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_packs_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_packssdw256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_packus_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_packuswb256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_packus_epi32(__m256i __V1, __m256i __V2)
{
  return (__m256i) __builtin_ia32_packusdw256((__v8si)__V1, (__v8si)__V2);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_add_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)((__v32qu)__a + (__v32qu)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_add_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)((__v16hu)__a + (__v16hu)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_add_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)((__v8su)__a + (__v8su)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_add_epi64(__m256i __a, __m256i __b)
{
  return (__m256i)((__v4du)__a + (__v4du)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_adds_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_paddsb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_adds_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_paddsw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_adds_epu8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_paddusb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_adds_epu16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_paddusw256((__v16hi)__a, (__v16hi)__b);
}

#define _mm256_alignr_epi8(a, b, n) __extension__ ({        \
  (__m256i)__builtin_ia32_palignr256((__v32qi)(__m256i)(a), \
                                     (__v32qi)(__m256i)(b), (n)); })

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_and_si256(__m256i __a, __m256i __b)
{
  return (__m256i)((__v4du)__a & (__v4du)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_andnot_si256(__m256i __a, __m256i __b)
{
  return (__m256i)(~(__v4du)__a & (__v4du)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_avg_epu8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pavgb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_avg_epu16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pavgw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_blendv_epi8(__m256i __V1, __m256i __V2, __m256i __M)
{
  return (__m256i)__builtin_ia32_pblendvb256((__v32qi)__V1, (__v32qi)__V2,
                                              (__v32qi)__M);
}

#define _mm256_blend_epi16(V1, V2, M) __extension__ ({       \
  (__m256i)__builtin_shufflevector((__v16hi)(__m256i)(V1),   \
                                   (__v16hi)(__m256i)(V2),   \
                                   (((M) & 0x01) ? 16 : 0),  \
                                   (((M) & 0x02) ? 17 : 1),  \
                                   (((M) & 0x04) ? 18 : 2),  \
                                   (((M) & 0x08) ? 19 : 3),  \
                                   (((M) & 0x10) ? 20 : 4),  \
                                   (((M) & 0x20) ? 21 : 5),  \
                                   (((M) & 0x40) ? 22 : 6),  \
                                   (((M) & 0x80) ? 23 : 7),  \
                                   (((M) & 0x01) ? 24 : 8),  \
                                   (((M) & 0x02) ? 25 : 9),  \
                                   (((M) & 0x04) ? 26 : 10), \
                                   (((M) & 0x08) ? 27 : 11), \
                                   (((M) & 0x10) ? 28 : 12), \
                                   (((M) & 0x20) ? 29 : 13), \
                                   (((M) & 0x40) ? 30 : 14), \
                                   (((M) & 0x80) ? 31 : 15)); })

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpeq_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)((__v32qi)__a == (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpeq_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)((__v16hi)__a == (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpeq_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)((__v8si)__a == (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpeq_epi64(__m256i __a, __m256i __b)
{
  return (__m256i)((__v4di)__a == (__v4di)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpgt_epi8(__m256i __a, __m256i __b)
{
  /* This function always performs a signed comparison, but __v32qi is a char
     which may be signed or unsigned, so use __v32qs. */
  return (__m256i)((__v32qs)__a > (__v32qs)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpgt_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)((__v16hi)__a > (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpgt_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)((__v8si)__a > (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cmpgt_epi64(__m256i __a, __m256i __b)
{
  return (__m256i)((__v4di)__a > (__v4di)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_hadd_epi16(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_phaddw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_hadd_epi32(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_phaddd256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_hadds_epi16(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_phaddsw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_hsub_epi16(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_phsubw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_hsub_epi32(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_phsubd256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_hsubs_epi16(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_phsubsw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maddubs_epi16(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_pmaddubsw256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_madd_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmaddwd256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmaxsb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmaxsw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmaxsd256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epu8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmaxub256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epu16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmaxuw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_max_epu32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmaxud256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pminsb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pminsw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pminsd256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epu8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pminub256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epu16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pminuw256 ((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_min_epu32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pminud256((__v8si)__a, (__v8si)__b);
}

static __inline__ int __DEFAULT_FN_ATTRS
_mm256_movemask_epi8(__m256i __a)
{
  return __builtin_ia32_pmovmskb256((__v32qi)__a);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepi8_epi16(__m128i __V)
{
  /* This function always performs a signed extension, but __v16qi is a char
     which may be signed or unsigned, so use __v16qs. */
  return (__m256i)__builtin_convertvector((__v16qs)__V, __v16hi);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepi8_epi32(__m128i __V)
{
  /* This function always performs a signed extension, but __v16qi is a char
     which may be signed or unsigned, so use __v16qs. */
  return (__m256i)__builtin_convertvector(__builtin_shufflevector((__v16qs)__V, (__v16qs)__V, 0, 1, 2, 3, 4, 5, 6, 7), __v8si);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepi8_epi64(__m128i __V)
{
  /* This function always performs a signed extension, but __v16qi is a char
     which may be signed or unsigned, so use __v16qs. */
  return (__m256i)__builtin_convertvector(__builtin_shufflevector((__v16qs)__V, (__v16qs)__V, 0, 1, 2, 3), __v4di);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepi16_epi32(__m128i __V)
{
  return (__m256i)__builtin_convertvector((__v8hi)__V, __v8si);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepi16_epi64(__m128i __V)
{
  return (__m256i)__builtin_convertvector(__builtin_shufflevector((__v8hi)__V, (__v8hi)__V, 0, 1, 2, 3), __v4di);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepi32_epi64(__m128i __V)
{
  return (__m256i)__builtin_convertvector((__v4si)__V, __v4di);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepu8_epi16(__m128i __V)
{
  return (__m256i)__builtin_convertvector((__v16qu)__V, __v16hi);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepu8_epi32(__m128i __V)
{
  return (__m256i)__builtin_convertvector(__builtin_shufflevector((__v16qu)__V, (__v16qu)__V, 0, 1, 2, 3, 4, 5, 6, 7), __v8si);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepu8_epi64(__m128i __V)
{
  return (__m256i)__builtin_convertvector(__builtin_shufflevector((__v16qu)__V, (__v16qu)__V, 0, 1, 2, 3), __v4di);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepu16_epi32(__m128i __V)
{
  return (__m256i)__builtin_convertvector((__v8hu)__V, __v8si);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepu16_epi64(__m128i __V)
{
  return (__m256i)__builtin_convertvector(__builtin_shufflevector((__v8hu)__V, (__v8hu)__V, 0, 1, 2, 3), __v4di);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_cvtepu32_epi64(__m128i __V)
{
  return (__m256i)__builtin_convertvector((__v4su)__V, __v4di);
}

static __inline__  __m256i __DEFAULT_FN_ATTRS
_mm256_mul_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmuldq256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mulhrs_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmulhrsw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mulhi_epu16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmulhuw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mulhi_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pmulhw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mullo_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)((__v16hu)__a * (__v16hu)__b);
}

static __inline__  __m256i __DEFAULT_FN_ATTRS
_mm256_mullo_epi32 (__m256i __a, __m256i __b)
{
  return (__m256i)((__v8su)__a * (__v8su)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_mul_epu32(__m256i __a, __m256i __b)
{
  return __builtin_ia32_pmuludq256((__v8si)__a, (__v8si)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_or_si256(__m256i __a, __m256i __b)
{
  return (__m256i)((__v4du)__a | (__v4du)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sad_epu8(__m256i __a, __m256i __b)
{
  return __builtin_ia32_psadbw256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_shuffle_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_pshufb256((__v32qi)__a, (__v32qi)__b);
}

#define _mm256_shuffle_epi32(a, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v8si)(__m256i)(a), \
                                   (__v8si)_mm256_undefined_si256(), \
                                   0 + (((imm) >> 0) & 0x3), \
                                   0 + (((imm) >> 2) & 0x3), \
                                   0 + (((imm) >> 4) & 0x3), \
                                   0 + (((imm) >> 6) & 0x3), \
                                   4 + (((imm) >> 0) & 0x3), \
                                   4 + (((imm) >> 2) & 0x3), \
                                   4 + (((imm) >> 4) & 0x3), \
                                   4 + (((imm) >> 6) & 0x3)); })

#define _mm256_shufflehi_epi16(a, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v16hi)(__m256i)(a), \
                                   (__v16hi)_mm256_undefined_si256(), \
                                   0, 1, 2, 3, \
                                   4  + (((imm) >> 0) & 0x3), \
                                   4  + (((imm) >> 2) & 0x3), \
                                   4  + (((imm) >> 4) & 0x3), \
                                   4  + (((imm) >> 6) & 0x3), \
                                   8, 9, 10, 11, \
                                   12 + (((imm) >> 0) & 0x3), \
                                   12 + (((imm) >> 2) & 0x3), \
                                   12 + (((imm) >> 4) & 0x3), \
                                   12 + (((imm) >> 6) & 0x3)); })

#define _mm256_shufflelo_epi16(a, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v16hi)(__m256i)(a), \
                                   (__v16hi)_mm256_undefined_si256(), \
                                   0 + (((imm) >> 0) & 0x3), \
                                   0 + (((imm) >> 2) & 0x3), \
                                   0 + (((imm) >> 4) & 0x3), \
                                   0 + (((imm) >> 6) & 0x3), \
                                   4, 5, 6, 7, \
                                   8 + (((imm) >> 0) & 0x3), \
                                   8 + (((imm) >> 2) & 0x3), \
                                   8 + (((imm) >> 4) & 0x3), \
                                   8 + (((imm) >> 6) & 0x3), \
                                   12, 13, 14, 15); })

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sign_epi8(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_psignb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sign_epi16(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_psignw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sign_epi32(__m256i __a, __m256i __b)
{
    return (__m256i)__builtin_ia32_psignd256((__v8si)__a, (__v8si)__b);
}

#define _mm256_slli_si256(a, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector(                                          \
        (__v32qi)_mm256_setzero_si256(),                                     \
        (__v32qi)(__m256i)(a),                                               \
        ((char)(imm)&0xF0) ?  0 : ((char)(imm)>0x0 ? 16 : 32) - (char)(imm), \
        ((char)(imm)&0xF0) ?  1 : ((char)(imm)>0x1 ? 17 : 33) - (char)(imm), \
        ((char)(imm)&0xF0) ?  2 : ((char)(imm)>0x2 ? 18 : 34) - (char)(imm), \
        ((char)(imm)&0xF0) ?  3 : ((char)(imm)>0x3 ? 19 : 35) - (char)(imm), \
        ((char)(imm)&0xF0) ?  4 : ((char)(imm)>0x4 ? 20 : 36) - (char)(imm), \
        ((char)(imm)&0xF0) ?  5 : ((char)(imm)>0x5 ? 21 : 37) - (char)(imm), \
        ((char)(imm)&0xF0) ?  6 : ((char)(imm)>0x6 ? 22 : 38) - (char)(imm), \
        ((char)(imm)&0xF0) ?  7 : ((char)(imm)>0x7 ? 23 : 39) - (char)(imm), \
        ((char)(imm)&0xF0) ?  8 : ((char)(imm)>0x8 ? 24 : 40) - (char)(imm), \
        ((char)(imm)&0xF0) ?  9 : ((char)(imm)>0x9 ? 25 : 41) - (char)(imm), \
        ((char)(imm)&0xF0) ? 10 : ((char)(imm)>0xA ? 26 : 42) - (char)(imm), \
        ((char)(imm)&0xF0) ? 11 : ((char)(imm)>0xB ? 27 : 43) - (char)(imm), \
        ((char)(imm)&0xF0) ? 12 : ((char)(imm)>0xC ? 28 : 44) - (char)(imm), \
        ((char)(imm)&0xF0) ? 13 : ((char)(imm)>0xD ? 29 : 45) - (char)(imm), \
        ((char)(imm)&0xF0) ? 14 : ((char)(imm)>0xE ? 30 : 46) - (char)(imm), \
        ((char)(imm)&0xF0) ? 15 : ((char)(imm)>0xF ? 31 : 47) - (char)(imm), \
        ((char)(imm)&0xF0) ? 16 : ((char)(imm)>0x0 ? 32 : 48) - (char)(imm), \
        ((char)(imm)&0xF0) ? 17 : ((char)(imm)>0x1 ? 33 : 49) - (char)(imm), \
        ((char)(imm)&0xF0) ? 18 : ((char)(imm)>0x2 ? 34 : 50) - (char)(imm), \
        ((char)(imm)&0xF0) ? 19 : ((char)(imm)>0x3 ? 35 : 51) - (char)(imm), \
        ((char)(imm)&0xF0) ? 20 : ((char)(imm)>0x4 ? 36 : 52) - (char)(imm), \
        ((char)(imm)&0xF0) ? 21 : ((char)(imm)>0x5 ? 37 : 53) - (char)(imm), \
        ((char)(imm)&0xF0) ? 22 : ((char)(imm)>0x6 ? 38 : 54) - (char)(imm), \
        ((char)(imm)&0xF0) ? 23 : ((char)(imm)>0x7 ? 39 : 55) - (char)(imm), \
        ((char)(imm)&0xF0) ? 24 : ((char)(imm)>0x8 ? 40 : 56) - (char)(imm), \
        ((char)(imm)&0xF0) ? 25 : ((char)(imm)>0x9 ? 41 : 57) - (char)(imm), \
        ((char)(imm)&0xF0) ? 26 : ((char)(imm)>0xA ? 42 : 58) - (char)(imm), \
        ((char)(imm)&0xF0) ? 27 : ((char)(imm)>0xB ? 43 : 59) - (char)(imm), \
        ((char)(imm)&0xF0) ? 28 : ((char)(imm)>0xC ? 44 : 60) - (char)(imm), \
        ((char)(imm)&0xF0) ? 29 : ((char)(imm)>0xD ? 45 : 61) - (char)(imm), \
        ((char)(imm)&0xF0) ? 30 : ((char)(imm)>0xE ? 46 : 62) - (char)(imm), \
        ((char)(imm)&0xF0) ? 31 : ((char)(imm)>0xF ? 47 : 63) - (char)(imm)); })

#define _mm256_bslli_epi128(a, count) _mm256_slli_si256((a), (count))

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_slli_epi16(__m256i __a, int __count)
{
  return (__m256i)__builtin_ia32_psllwi256((__v16hi)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sll_epi16(__m256i __a, __m128i __count)
{
  return (__m256i)__builtin_ia32_psllw256((__v16hi)__a, (__v8hi)__count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_slli_epi32(__m256i __a, int __count)
{
  return (__m256i)__builtin_ia32_pslldi256((__v8si)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sll_epi32(__m256i __a, __m128i __count)
{
  return (__m256i)__builtin_ia32_pslld256((__v8si)__a, (__v4si)__count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_slli_epi64(__m256i __a, int __count)
{
  return __builtin_ia32_psllqi256((__v4di)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sll_epi64(__m256i __a, __m128i __count)
{
  return __builtin_ia32_psllq256((__v4di)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srai_epi16(__m256i __a, int __count)
{
  return (__m256i)__builtin_ia32_psrawi256((__v16hi)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sra_epi16(__m256i __a, __m128i __count)
{
  return (__m256i)__builtin_ia32_psraw256((__v16hi)__a, (__v8hi)__count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srai_epi32(__m256i __a, int __count)
{
  return (__m256i)__builtin_ia32_psradi256((__v8si)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sra_epi32(__m256i __a, __m128i __count)
{
  return (__m256i)__builtin_ia32_psrad256((__v8si)__a, (__v4si)__count);
}

#define _mm256_srli_si256(a, imm) __extension__ ({ \
  (__m256i)__builtin_shufflevector(                                           \
        (__v32qi)(__m256i)(a),                                               \
        (__v32qi)_mm256_setzero_si256(),                                     \
        ((char)(imm)&0xF0) ? 32 : (char)(imm) + ((char)(imm)>0xF ? 16 : 0),  \
        ((char)(imm)&0xF0) ? 33 : (char)(imm) + ((char)(imm)>0xE ? 17 : 1),  \
        ((char)(imm)&0xF0) ? 34 : (char)(imm) + ((char)(imm)>0xD ? 18 : 2),  \
        ((char)(imm)&0xF0) ? 35 : (char)(imm) + ((char)(imm)>0xC ? 19 : 3),  \
        ((char)(imm)&0xF0) ? 36 : (char)(imm) + ((char)(imm)>0xB ? 20 : 4),  \
        ((char)(imm)&0xF0) ? 37 : (char)(imm) + ((char)(imm)>0xA ? 21 : 5),  \
        ((char)(imm)&0xF0) ? 38 : (char)(imm) + ((char)(imm)>0x9 ? 22 : 6),  \
        ((char)(imm)&0xF0) ? 39 : (char)(imm) + ((char)(imm)>0x8 ? 23 : 7),  \
        ((char)(imm)&0xF0) ? 40 : (char)(imm) + ((char)(imm)>0x7 ? 24 : 8),  \
        ((char)(imm)&0xF0) ? 41 : (char)(imm) + ((char)(imm)>0x6 ? 25 : 9),  \
        ((char)(imm)&0xF0) ? 42 : (char)(imm) + ((char)(imm)>0x5 ? 26 : 10), \
        ((char)(imm)&0xF0) ? 43 : (char)(imm) + ((char)(imm)>0x4 ? 27 : 11), \
        ((char)(imm)&0xF0) ? 44 : (char)(imm) + ((char)(imm)>0x3 ? 28 : 12), \
        ((char)(imm)&0xF0) ? 45 : (char)(imm) + ((char)(imm)>0x2 ? 29 : 13), \
        ((char)(imm)&0xF0) ? 46 : (char)(imm) + ((char)(imm)>0x1 ? 30 : 14), \
        ((char)(imm)&0xF0) ? 47 : (char)(imm) + ((char)(imm)>0x0 ? 31 : 15), \
        ((char)(imm)&0xF0) ? 48 : (char)(imm) + ((char)(imm)>0xF ? 32 : 16), \
        ((char)(imm)&0xF0) ? 49 : (char)(imm) + ((char)(imm)>0xE ? 33 : 17), \
        ((char)(imm)&0xF0) ? 50 : (char)(imm) + ((char)(imm)>0xD ? 34 : 18), \
        ((char)(imm)&0xF0) ? 51 : (char)(imm) + ((char)(imm)>0xC ? 35 : 19), \
        ((char)(imm)&0xF0) ? 52 : (char)(imm) + ((char)(imm)>0xB ? 36 : 20), \
        ((char)(imm)&0xF0) ? 53 : (char)(imm) + ((char)(imm)>0xA ? 37 : 21), \
        ((char)(imm)&0xF0) ? 54 : (char)(imm) + ((char)(imm)>0x9 ? 38 : 22), \
        ((char)(imm)&0xF0) ? 55 : (char)(imm) + ((char)(imm)>0x8 ? 39 : 23), \
        ((char)(imm)&0xF0) ? 56 : (char)(imm) + ((char)(imm)>0x7 ? 40 : 24), \
        ((char)(imm)&0xF0) ? 57 : (char)(imm) + ((char)(imm)>0x6 ? 41 : 25), \
        ((char)(imm)&0xF0) ? 58 : (char)(imm) + ((char)(imm)>0x5 ? 42 : 26), \
        ((char)(imm)&0xF0) ? 59 : (char)(imm) + ((char)(imm)>0x4 ? 43 : 27), \
        ((char)(imm)&0xF0) ? 60 : (char)(imm) + ((char)(imm)>0x3 ? 44 : 28), \
        ((char)(imm)&0xF0) ? 61 : (char)(imm) + ((char)(imm)>0x2 ? 45 : 29), \
        ((char)(imm)&0xF0) ? 62 : (char)(imm) + ((char)(imm)>0x1 ? 46 : 30), \
        ((char)(imm)&0xF0) ? 63 : (char)(imm) + ((char)(imm)>0x0 ? 47 : 31)); })

#define _mm256_bsrli_epi128(a, count) _mm256_srli_si256((a), (count))

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srli_epi16(__m256i __a, int __count)
{
  return (__m256i)__builtin_ia32_psrlwi256((__v16hi)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srl_epi16(__m256i __a, __m128i __count)
{
  return (__m256i)__builtin_ia32_psrlw256((__v16hi)__a, (__v8hi)__count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srli_epi32(__m256i __a, int __count)
{
  return (__m256i)__builtin_ia32_psrldi256((__v8si)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srl_epi32(__m256i __a, __m128i __count)
{
  return (__m256i)__builtin_ia32_psrld256((__v8si)__a, (__v4si)__count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srli_epi64(__m256i __a, int __count)
{
  return __builtin_ia32_psrlqi256((__v4di)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srl_epi64(__m256i __a, __m128i __count)
{
  return __builtin_ia32_psrlq256((__v4di)__a, __count);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sub_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)((__v32qu)__a - (__v32qu)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sub_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)((__v16hu)__a - (__v16hu)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sub_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)((__v8su)__a - (__v8su)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sub_epi64(__m256i __a, __m256i __b)
{
  return (__m256i)((__v4du)__a - (__v4du)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_subs_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_psubsb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_subs_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_psubsw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_subs_epu8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_psubusb256((__v32qi)__a, (__v32qi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_subs_epu16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_psubusw256((__v16hi)__a, (__v16hi)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpackhi_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v32qi)__a, (__v32qi)__b, 8, 32+8, 9, 32+9, 10, 32+10, 11, 32+11, 12, 32+12, 13, 32+13, 14, 32+14, 15, 32+15, 24, 32+24, 25, 32+25, 26, 32+26, 27, 32+27, 28, 32+28, 29, 32+29, 30, 32+30, 31, 32+31);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpackhi_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v16hi)__a, (__v16hi)__b, 4, 16+4, 5, 16+5, 6, 16+6, 7, 16+7, 12, 16+12, 13, 16+13, 14, 16+14, 15, 16+15);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpackhi_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v8si)__a, (__v8si)__b, 2, 8+2, 3, 8+3, 6, 8+6, 7, 8+7);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpackhi_epi64(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v4di)__a, (__v4di)__b, 1, 4+1, 3, 4+3);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpacklo_epi8(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v32qi)__a, (__v32qi)__b, 0, 32+0, 1, 32+1, 2, 32+2, 3, 32+3, 4, 32+4, 5, 32+5, 6, 32+6, 7, 32+7, 16, 32+16, 17, 32+17, 18, 32+18, 19, 32+19, 20, 32+20, 21, 32+21, 22, 32+22, 23, 32+23);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpacklo_epi16(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v16hi)__a, (__v16hi)__b, 0, 16+0, 1, 16+1, 2, 16+2, 3, 16+3, 8, 16+8, 9, 16+9, 10, 16+10, 11, 16+11);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpacklo_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v8si)__a, (__v8si)__b, 0, 8+0, 1, 8+1, 4, 8+4, 5, 8+5);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_unpacklo_epi64(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_shufflevector((__v4di)__a, (__v4di)__b, 0, 4+0, 2, 4+2);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_xor_si256(__m256i __a, __m256i __b)
{
  return (__m256i)((__v4du)__a ^ (__v4du)__b);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_stream_load_si256(__m256i const *__V)
{
  typedef __v4di __v4di_aligned __attribute__((aligned(32)));
  return (__m256i)__builtin_nontemporal_load((const __v4di_aligned *)__V);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_broadcastss_ps(__m128 __X)
{
  return (__m128)__builtin_shufflevector((__v4sf)__X, (__v4sf)__X, 0, 0, 0, 0);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_broadcastsd_pd(__m128d __a)
{
  return __builtin_shufflevector((__v2df)__a, (__v2df)__a, 0, 0);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_broadcastss_ps(__m128 __X)
{
  return (__m256)__builtin_shufflevector((__v4sf)__X, (__v4sf)__X, 0, 0, 0, 0, 0, 0, 0, 0);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS
_mm256_broadcastsd_pd(__m128d __X)
{
  return (__m256d)__builtin_shufflevector((__v2df)__X, (__v2df)__X, 0, 0, 0, 0);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcastsi128_si256(__m128i __X)
{
  return (__m256i)__builtin_shufflevector((__v2di)__X, (__v2di)__X, 0, 1, 0, 1);
}

#define _mm_blend_epi32(V1, V2, M) __extension__ ({ \
  (__m128i)__builtin_shufflevector((__v4si)(__m128i)(V1),  \
                                   (__v4si)(__m128i)(V2),  \
                                   (((M) & 0x01) ? 4 : 0), \
                                   (((M) & 0x02) ? 5 : 1), \
                                   (((M) & 0x04) ? 6 : 2), \
                                   (((M) & 0x08) ? 7 : 3)); })

#define _mm256_blend_epi32(V1, V2, M) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v8si)(__m256i)(V1),   \
                                   (__v8si)(__m256i)(V2),   \
                                   (((M) & 0x01) ?  8 : 0), \
                                   (((M) & 0x02) ?  9 : 1), \
                                   (((M) & 0x04) ? 10 : 2), \
                                   (((M) & 0x08) ? 11 : 3), \
                                   (((M) & 0x10) ? 12 : 4), \
                                   (((M) & 0x20) ? 13 : 5), \
                                   (((M) & 0x40) ? 14 : 6), \
                                   (((M) & 0x80) ? 15 : 7)); })

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcastb_epi8(__m128i __X)
{
  return (__m256i)__builtin_shufflevector((__v16qi)__X, (__v16qi)__X, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcastw_epi16(__m128i __X)
{
  return (__m256i)__builtin_shufflevector((__v8hi)__X, (__v8hi)__X, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcastd_epi32(__m128i __X)
{
  return (__m256i)__builtin_shufflevector((__v4si)__X, (__v4si)__X, 0, 0, 0, 0, 0, 0, 0, 0);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_broadcastq_epi64(__m128i __X)
{
  return (__m256i)__builtin_shufflevector((__v2di)__X, (__v2di)__X, 0, 0, 0, 0);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_broadcastb_epi8(__m128i __X)
{
  return (__m128i)__builtin_shufflevector((__v16qi)__X, (__v16qi)__X, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_broadcastw_epi16(__m128i __X)
{
  return (__m128i)__builtin_shufflevector((__v8hi)__X, (__v8hi)__X, 0, 0, 0, 0, 0, 0, 0, 0);
}


static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_broadcastd_epi32(__m128i __X)
{
  return (__m128i)__builtin_shufflevector((__v4si)__X, (__v4si)__X, 0, 0, 0, 0);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_broadcastq_epi64(__m128i __X)
{
  return (__m128i)__builtin_shufflevector((__v2di)__X, (__v2di)__X, 0, 0);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_permutevar8x32_epi32(__m256i __a, __m256i __b)
{
  return (__m256i)__builtin_ia32_permvarsi256((__v8si)__a, (__v8si)__b);
}

#define _mm256_permute4x64_pd(V, M) __extension__ ({ \
  (__m256d)__builtin_shufflevector((__v4df)(__m256d)(V), \
                                   (__v4df)_mm256_undefined_pd(), \
                                   ((M) >> 0) & 0x3, \
                                   ((M) >> 2) & 0x3, \
                                   ((M) >> 4) & 0x3, \
                                   ((M) >> 6) & 0x3); })

static __inline__ __m256 __DEFAULT_FN_ATTRS
_mm256_permutevar8x32_ps(__m256 __a, __m256i __b)
{
  return (__m256)__builtin_ia32_permvarsf256((__v8sf)__a, (__v8si)__b);
}

#define _mm256_permute4x64_epi64(V, M) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v4di)(__m256i)(V), \
                                   (__v4di)_mm256_undefined_si256(), \
                                   ((M) >> 0) & 0x3, \
                                   ((M) >> 2) & 0x3, \
                                   ((M) >> 4) & 0x3, \
                                   ((M) >> 6) & 0x3); })

#define _mm256_permute2x128_si256(V1, V2, M) __extension__ ({ \
  (__m256i)__builtin_ia32_permti256((__m256i)(V1), (__m256i)(V2), (M)); })

#define _mm256_extracti128_si256(V, M) __extension__ ({ \
  (__m128i)__builtin_shufflevector((__v4di)(__m256i)(V), \
                                   (__v4di)_mm256_undefined_si256(), \
                                   (((M) & 1) ? 2 : 0), \
                                   (((M) & 1) ? 3 : 1) ); })

#define _mm256_inserti128_si256(V1, V2, M) __extension__ ({ \
  (__m256i)__builtin_shufflevector((__v4di)(__m256i)(V1), \
                                   (__v4di)_mm256_castsi128_si256((__m128i)(V2)), \
                                   (((M) & 1) ? 0 : 4), \
                                   (((M) & 1) ? 1 : 5), \
                                   (((M) & 1) ? 4 : 2), \
                                   (((M) & 1) ? 5 : 3) ); })

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskload_epi32(int const *__X, __m256i __M)
{
  return (__m256i)__builtin_ia32_maskloadd256((const __v8si *)__X, (__v8si)__M);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_maskload_epi64(long long const *__X, __m256i __M)
{
  return (__m256i)__builtin_ia32_maskloadq256((const __v4di *)__X, (__v4di)__M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskload_epi32(int const *__X, __m128i __M)
{
  return (__m128i)__builtin_ia32_maskloadd((const __v4si *)__X, (__v4si)__M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_maskload_epi64(long long const *__X, __m128i __M)
{
  return (__m128i)__builtin_ia32_maskloadq((const __v2di *)__X, (__v2di)__M);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_maskstore_epi32(int *__X, __m256i __M, __m256i __Y)
{
  __builtin_ia32_maskstored256((__v8si *)__X, (__v8si)__M, (__v8si)__Y);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm256_maskstore_epi64(long long *__X, __m256i __M, __m256i __Y)
{
  __builtin_ia32_maskstoreq256((__v4di *)__X, (__v4di)__M, (__v4di)__Y);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_maskstore_epi32(int *__X, __m128i __M, __m128i __Y)
{
  __builtin_ia32_maskstored((__v4si *)__X, (__v4si)__M, (__v4si)__Y);
}

static __inline__ void __DEFAULT_FN_ATTRS
_mm_maskstore_epi64(long long *__X, __m128i __M, __m128i __Y)
{
  __builtin_ia32_maskstoreq(( __v2di *)__X, (__v2di)__M, (__v2di)__Y);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sllv_epi32(__m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_psllv8si((__v8si)__X, (__v8si)__Y);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_sllv_epi32(__m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_psllv4si((__v4si)__X, (__v4si)__Y);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_sllv_epi64(__m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_psllv4di((__v4di)__X, (__v4di)__Y);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_sllv_epi64(__m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_psllv2di((__v2di)__X, (__v2di)__Y);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srav_epi32(__m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_psrav8si((__v8si)__X, (__v8si)__Y);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_srav_epi32(__m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_psrav4si((__v4si)__X, (__v4si)__Y);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srlv_epi32(__m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_psrlv8si((__v8si)__X, (__v8si)__Y);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_srlv_epi32(__m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_psrlv4si((__v4si)__X, (__v4si)__Y);
}

static __inline__ __m256i __DEFAULT_FN_ATTRS
_mm256_srlv_epi64(__m256i __X, __m256i __Y)
{
  return (__m256i)__builtin_ia32_psrlv4di((__v4di)__X, (__v4di)__Y);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_srlv_epi64(__m128i __X, __m128i __Y)
{
  return (__m128i)__builtin_ia32_psrlv2di((__v2di)__X, (__v2di)__Y);
}

#define _mm_mask_i32gather_pd(a, m, i, mask, s) __extension__ ({ \
  (__m128d)__builtin_ia32_gatherd_pd((__v2df)(__m128i)(a), \
                                     (double const *)(m), \
                                     (__v4si)(__m128i)(i), \
                                     (__v2df)(__m128d)(mask), (s)); })

#define _mm256_mask_i32gather_pd(a, m, i, mask, s) __extension__ ({ \
  (__m256d)__builtin_ia32_gatherd_pd256((__v4df)(__m256d)(a), \
                                        (double const *)(m), \
                                        (__v4si)(__m128i)(i), \
                                        (__v4df)(__m256d)(mask), (s)); })

#define _mm_mask_i64gather_pd(a, m, i, mask, s) __extension__ ({ \
  (__m128d)__builtin_ia32_gatherq_pd((__v2df)(__m128d)(a), \
                                     (double const *)(m), \
                                     (__v2di)(__m128i)(i), \
                                     (__v2df)(__m128d)(mask), (s)); })

#define _mm256_mask_i64gather_pd(a, m, i, mask, s) __extension__ ({ \
  (__m256d)__builtin_ia32_gatherq_pd256((__v4df)(__m256d)(a), \
                                        (double const *)(m), \
                                        (__v4di)(__m256i)(i), \
                                        (__v4df)(__m256d)(mask), (s)); })

#define _mm_mask_i32gather_ps(a, m, i, mask, s) __extension__ ({ \
  (__m128)__builtin_ia32_gatherd_ps((__v4sf)(__m128)(a), \
                                    (float const *)(m), \
                                    (__v4si)(__m128i)(i), \
                                    (__v4sf)(__m128)(mask), (s)); })

#define _mm256_mask_i32gather_ps(a, m, i, mask, s) __extension__ ({ \
  (__m256)__builtin_ia32_gatherd_ps256((__v8sf)(__m256)(a), \
                                       (float const *)(m), \
                                       (__v8si)(__m256i)(i), \
                                       (__v8sf)(__m256)(mask), (s)); })

#define _mm_mask_i64gather_ps(a, m, i, mask, s) __extension__ ({ \
  (__m128)__builtin_ia32_gatherq_ps((__v4sf)(__m128)(a), \
                                    (float const *)(m), \
                                    (__v2di)(__m128i)(i), \
                                    (__v4sf)(__m128)(mask), (s)); })

#define _mm256_mask_i64gather_ps(a, m, i, mask, s) __extension__ ({ \
  (__m128)__builtin_ia32_gatherq_ps256((__v4sf)(__m128)(a), \
                                       (float const *)(m), \
                                       (__v4di)(__m256i)(i), \
                                       (__v4sf)(__m128)(mask), (s)); })

#define _mm_mask_i32gather_epi32(a, m, i, mask, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherd_d((__v4si)(__m128i)(a), \
                                    (int const *)(m), \
                                    (__v4si)(__m128i)(i), \
                                    (__v4si)(__m128i)(mask), (s)); })

#define _mm256_mask_i32gather_epi32(a, m, i, mask, s) __extension__ ({ \
  (__m256i)__builtin_ia32_gatherd_d256((__v8si)(__m256i)(a), \
                                       (int const *)(m), \
                                       (__v8si)(__m256i)(i), \
                                       (__v8si)(__m256i)(mask), (s)); })

#define _mm_mask_i64gather_epi32(a, m, i, mask, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherq_d((__v4si)(__m128i)(a), \
                                    (int const *)(m), \
                                    (__v2di)(__m128i)(i), \
                                    (__v4si)(__m128i)(mask), (s)); })

#define _mm256_mask_i64gather_epi32(a, m, i, mask, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherq_d256((__v4si)(__m128i)(a), \
                                       (int const *)(m), \
                                       (__v4di)(__m256i)(i), \
                                       (__v4si)(__m128i)(mask), (s)); })

#define _mm_mask_i32gather_epi64(a, m, i, mask, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherd_q((__v2di)(__m128i)(a), \
                                    (long long const *)(m), \
                                    (__v4si)(__m128i)(i), \
                                    (__v2di)(__m128i)(mask), (s)); })

#define _mm256_mask_i32gather_epi64(a, m, i, mask, s) __extension__ ({ \
  (__m256i)__builtin_ia32_gatherd_q256((__v4di)(__m256i)(a), \
                                       (long long const *)(m), \
                                       (__v4si)(__m128i)(i), \
                                       (__v4di)(__m256i)(mask), (s)); })

#define _mm_mask_i64gather_epi64(a, m, i, mask, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherq_q((__v2di)(__m128i)(a), \
                                    (long long const *)(m), \
                                    (__v2di)(__m128i)(i), \
                                    (__v2di)(__m128i)(mask), (s)); })

#define _mm256_mask_i64gather_epi64(a, m, i, mask, s) __extension__ ({ \
  (__m256i)__builtin_ia32_gatherq_q256((__v4di)(__m256i)(a), \
                                       (long long const *)(m), \
                                       (__v4di)(__m256i)(i), \
                                       (__v4di)(__m256i)(mask), (s)); })

#define _mm_i32gather_pd(m, i, s) __extension__ ({ \
  (__m128d)__builtin_ia32_gatherd_pd((__v2df)_mm_undefined_pd(), \
                                     (double const *)(m), \
                                     (__v4si)(__m128i)(i), \
                                     (__v2df)_mm_cmpeq_pd(_mm_setzero_pd(), \
                                                          _mm_setzero_pd()), \
                                     (s)); })

#define _mm256_i32gather_pd(m, i, s) __extension__ ({ \
  (__m256d)__builtin_ia32_gatherd_pd256((__v4df)_mm256_undefined_pd(), \
                                        (double const *)(m), \
                                        (__v4si)(__m128i)(i), \
                                        (__v4df)_mm256_cmp_pd(_mm256_setzero_pd(), \
                                                              _mm256_setzero_pd(), \
                                                              _CMP_EQ_OQ), \
                                        (s)); })

#define _mm_i64gather_pd(m, i, s) __extension__ ({ \
  (__m128d)__builtin_ia32_gatherq_pd((__v2df)_mm_undefined_pd(), \
                                     (double const *)(m), \
                                     (__v2di)(__m128i)(i), \
                                     (__v2df)_mm_cmpeq_pd(_mm_setzero_pd(), \
                                                          _mm_setzero_pd()), \
                                     (s)); })

#define _mm256_i64gather_pd(m, i, s) __extension__ ({ \
  (__m256d)__builtin_ia32_gatherq_pd256((__v4df)_mm256_undefined_pd(), \
                                        (double const *)(m), \
                                        (__v4di)(__m256i)(i), \
                                        (__v4df)_mm256_cmp_pd(_mm256_setzero_pd(), \
                                                              _mm256_setzero_pd(), \
                                                              _CMP_EQ_OQ), \
                                        (s)); })

#define _mm_i32gather_ps(m, i, s) __extension__ ({ \
  (__m128)__builtin_ia32_gatherd_ps((__v4sf)_mm_undefined_ps(), \
                                    (float const *)(m), \
                                    (__v4si)(__m128i)(i), \
                                    (__v4sf)_mm_cmpeq_ps(_mm_setzero_ps(), \
                                                         _mm_setzero_ps()), \
                                    (s)); })

#define _mm256_i32gather_ps(m, i, s) __extension__ ({ \
  (__m256)__builtin_ia32_gatherd_ps256((__v8sf)_mm256_undefined_ps(), \
                                       (float const *)(m), \
                                       (__v8si)(__m256i)(i), \
                                       (__v8sf)_mm256_cmp_ps(_mm256_setzero_ps(), \
                                                             _mm256_setzero_ps(), \
                                                             _CMP_EQ_OQ), \
                                       (s)); })

#define _mm_i64gather_ps(m, i, s) __extension__ ({ \
  (__m128)__builtin_ia32_gatherq_ps((__v4sf)_mm_undefined_ps(), \
                                    (float const *)(m), \
                                    (__v2di)(__m128i)(i), \
                                    (__v4sf)_mm_cmpeq_ps(_mm_setzero_ps(), \
                                                         _mm_setzero_ps()), \
                                    (s)); })

#define _mm256_i64gather_ps(m, i, s) __extension__ ({ \
  (__m128)__builtin_ia32_gatherq_ps256((__v4sf)_mm_undefined_ps(), \
                                       (float const *)(m), \
                                       (__v4di)(__m256i)(i), \
                                       (__v4sf)_mm_cmpeq_ps(_mm_setzero_ps(), \
                                                            _mm_setzero_ps()), \
                                       (s)); })

#define _mm_i32gather_epi32(m, i, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherd_d((__v4si)_mm_undefined_si128(), \
                                    (int const *)(m), (__v4si)(__m128i)(i), \
                                    (__v4si)_mm_set1_epi32(-1), (s)); })

#define _mm256_i32gather_epi32(m, i, s) __extension__ ({ \
  (__m256i)__builtin_ia32_gatherd_d256((__v8si)_mm256_undefined_si256(), \
                                       (int const *)(m), (__v8si)(__m256i)(i), \
                                       (__v8si)_mm256_set1_epi32(-1), (s)); })

#define _mm_i64gather_epi32(m, i, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherq_d((__v4si)_mm_undefined_si128(), \
                                    (int const *)(m), (__v2di)(__m128i)(i), \
                                    (__v4si)_mm_set1_epi32(-1), (s)); })

#define _mm256_i64gather_epi32(m, i, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherq_d256((__v4si)_mm_undefined_si128(), \
                                       (int const *)(m), (__v4di)(__m256i)(i), \
                                       (__v4si)_mm_set1_epi32(-1), (s)); })

#define _mm_i32gather_epi64(m, i, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherd_q((__v2di)_mm_undefined_si128(), \
                                    (long long const *)(m), \
                                    (__v4si)(__m128i)(i), \
                                    (__v2di)_mm_set1_epi64x(-1), (s)); })

#define _mm256_i32gather_epi64(m, i, s) __extension__ ({ \
  (__m256i)__builtin_ia32_gatherd_q256((__v4di)_mm256_undefined_si256(), \
                                       (long long const *)(m), \
                                       (__v4si)(__m128i)(i), \
                                       (__v4di)_mm256_set1_epi64x(-1), (s)); })

#define _mm_i64gather_epi64(m, i, s) __extension__ ({ \
  (__m128i)__builtin_ia32_gatherq_q((__v2di)_mm_undefined_si128(), \
                                    (long long const *)(m), \
                                    (__v2di)(__m128i)(i), \
                                    (__v2di)_mm_set1_epi64x(-1), (s)); })

#define _mm256_i64gather_epi64(m, i, s) __extension__ ({ \
  (__m256i)__builtin_ia32_gatherq_q256((__v4di)_mm256_undefined_si256(), \
                                       (long long const *)(m), \
                                       (__v4di)(__m256i)(i), \
                                       (__v4di)_mm256_set1_epi64x(-1), (s)); })

#undef __DEFAULT_FN_ATTRS

#endif /* __AVX2INTRIN_H */
