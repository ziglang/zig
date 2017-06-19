/*===---- smmintrin.h - SSE4 intrinsics ------------------------------------===
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

#ifndef _SMMINTRIN_H
#define _SMMINTRIN_H

#include <tmmintrin.h>

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("sse4.1")))

/* SSE4 Rounding macros. */
#define _MM_FROUND_TO_NEAREST_INT    0x00
#define _MM_FROUND_TO_NEG_INF        0x01
#define _MM_FROUND_TO_POS_INF        0x02
#define _MM_FROUND_TO_ZERO           0x03
#define _MM_FROUND_CUR_DIRECTION     0x04

#define _MM_FROUND_RAISE_EXC         0x00
#define _MM_FROUND_NO_EXC            0x08

#define _MM_FROUND_NINT      (_MM_FROUND_RAISE_EXC | _MM_FROUND_TO_NEAREST_INT)
#define _MM_FROUND_FLOOR     (_MM_FROUND_RAISE_EXC | _MM_FROUND_TO_NEG_INF)
#define _MM_FROUND_CEIL      (_MM_FROUND_RAISE_EXC | _MM_FROUND_TO_POS_INF)
#define _MM_FROUND_TRUNC     (_MM_FROUND_RAISE_EXC | _MM_FROUND_TO_ZERO)
#define _MM_FROUND_RINT      (_MM_FROUND_RAISE_EXC | _MM_FROUND_CUR_DIRECTION)
#define _MM_FROUND_NEARBYINT (_MM_FROUND_NO_EXC | _MM_FROUND_CUR_DIRECTION)

#define _mm_ceil_ps(X)       _mm_round_ps((X), _MM_FROUND_CEIL)
#define _mm_ceil_pd(X)       _mm_round_pd((X), _MM_FROUND_CEIL)
#define _mm_ceil_ss(X, Y)    _mm_round_ss((X), (Y), _MM_FROUND_CEIL)
#define _mm_ceil_sd(X, Y)    _mm_round_sd((X), (Y), _MM_FROUND_CEIL)

#define _mm_floor_ps(X)      _mm_round_ps((X), _MM_FROUND_FLOOR)
#define _mm_floor_pd(X)      _mm_round_pd((X), _MM_FROUND_FLOOR)
#define _mm_floor_ss(X, Y)   _mm_round_ss((X), (Y), _MM_FROUND_FLOOR)
#define _mm_floor_sd(X, Y)   _mm_round_sd((X), (Y), _MM_FROUND_FLOOR)

#define _mm_round_ps(X, M) __extension__ ({ \
  (__m128)__builtin_ia32_roundps((__v4sf)(__m128)(X), (M)); })

#define _mm_round_ss(X, Y, M) __extension__ ({ \
  (__m128)__builtin_ia32_roundss((__v4sf)(__m128)(X), \
                                 (__v4sf)(__m128)(Y), (M)); })

#define _mm_round_pd(X, M) __extension__ ({ \
  (__m128d)__builtin_ia32_roundpd((__v2df)(__m128d)(X), (M)); })

#define _mm_round_sd(X, Y, M) __extension__ ({ \
  (__m128d)__builtin_ia32_roundsd((__v2df)(__m128d)(X), \
                                  (__v2df)(__m128d)(Y), (M)); })

/* SSE4 Packed Blending Intrinsics.  */
#define _mm_blend_pd(V1, V2, M) __extension__ ({ \
  (__m128d)__builtin_shufflevector((__v2df)(__m128d)(V1), \
                                   (__v2df)(__m128d)(V2), \
                                   (((M) & 0x01) ? 2 : 0), \
                                   (((M) & 0x02) ? 3 : 1)); })

#define _mm_blend_ps(V1, V2, M) __extension__ ({ \
  (__m128)__builtin_shufflevector((__v4sf)(__m128)(V1), (__v4sf)(__m128)(V2), \
                                  (((M) & 0x01) ? 4 : 0), \
                                  (((M) & 0x02) ? 5 : 1), \
                                  (((M) & 0x04) ? 6 : 2), \
                                  (((M) & 0x08) ? 7 : 3)); })

static __inline__ __m128d __DEFAULT_FN_ATTRS
_mm_blendv_pd (__m128d __V1, __m128d __V2, __m128d __M)
{
  return (__m128d) __builtin_ia32_blendvpd ((__v2df)__V1, (__v2df)__V2,
                                            (__v2df)__M);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS
_mm_blendv_ps (__m128 __V1, __m128 __V2, __m128 __M)
{
  return (__m128) __builtin_ia32_blendvps ((__v4sf)__V1, (__v4sf)__V2,
                                           (__v4sf)__M);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_blendv_epi8 (__m128i __V1, __m128i __V2, __m128i __M)
{
  return (__m128i) __builtin_ia32_pblendvb128 ((__v16qi)__V1, (__v16qi)__V2,
                                               (__v16qi)__M);
}

#define _mm_blend_epi16(V1, V2, M) __extension__ ({ \
  (__m128i)__builtin_shufflevector((__v8hi)(__m128i)(V1), \
                                   (__v8hi)(__m128i)(V2), \
                                   (((M) & 0x01) ?  8 : 0), \
                                   (((M) & 0x02) ?  9 : 1), \
                                   (((M) & 0x04) ? 10 : 2), \
                                   (((M) & 0x08) ? 11 : 3), \
                                   (((M) & 0x10) ? 12 : 4), \
                                   (((M) & 0x20) ? 13 : 5), \
                                   (((M) & 0x40) ? 14 : 6), \
                                   (((M) & 0x80) ? 15 : 7)); })

/* SSE4 Dword Multiply Instructions.  */
static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_mullo_epi32 (__m128i __V1, __m128i __V2)
{
  return (__m128i) ((__v4su)__V1 * (__v4su)__V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_mul_epi32 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pmuldq128 ((__v4si)__V1, (__v4si)__V2);
}

/* SSE4 Floating Point Dot Product Instructions.  */
#define _mm_dp_ps(X, Y, M) __extension__ ({ \
  (__m128) __builtin_ia32_dpps((__v4sf)(__m128)(X), \
                               (__v4sf)(__m128)(Y), (M)); })

#define _mm_dp_pd(X, Y, M) __extension__ ({\
  (__m128d) __builtin_ia32_dppd((__v2df)(__m128d)(X), \
                                (__v2df)(__m128d)(Y), (M)); })

/* SSE4 Streaming Load Hint Instruction.  */
static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_stream_load_si128 (__m128i const *__V)
{
  return (__m128i) __builtin_ia32_movntdqa ((const __v2di *) __V);
}

/* SSE4 Packed Integer Min/Max Instructions.  */
static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_min_epi8 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pminsb128 ((__v16qi) __V1, (__v16qi) __V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_max_epi8 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pmaxsb128 ((__v16qi) __V1, (__v16qi) __V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_min_epu16 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pminuw128 ((__v8hi) __V1, (__v8hi) __V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_max_epu16 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pmaxuw128 ((__v8hi) __V1, (__v8hi) __V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_min_epi32 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pminsd128 ((__v4si) __V1, (__v4si) __V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_max_epi32 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pmaxsd128 ((__v4si) __V1, (__v4si) __V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_min_epu32 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pminud128((__v4si) __V1, (__v4si) __V2);
}

static __inline__  __m128i __DEFAULT_FN_ATTRS
_mm_max_epu32 (__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_pmaxud128((__v4si) __V1, (__v4si) __V2);
}

/* SSE4 Insertion and Extraction from XMM Register Instructions.  */
#define _mm_insert_ps(X, Y, N) __builtin_ia32_insertps128((X), (Y), (N))
#define _mm_extract_ps(X, N) (__extension__                      \
                              ({ union { int __i; float __f; } __t;  \
                                 __v4sf __a = (__v4sf)(__m128)(X);       \
                                 __t.__f = __a[(N) & 3];                 \
                                 __t.__i;}))

/* Miscellaneous insert and extract macros.  */
/* Extract a single-precision float from X at index N into D.  */
#define _MM_EXTRACT_FLOAT(D, X, N) (__extension__ ({ __v4sf __a = (__v4sf)(X); \
                                                    (D) = __a[N]; }))

/* Or together 2 sets of indexes (X and Y) with the zeroing bits (Z) to create
   an index suitable for _mm_insert_ps.  */
#define _MM_MK_INSERTPS_NDX(X, Y, Z) (((X) << 6) | ((Y) << 4) | (Z))

/* Extract a float from X at index N into the first index of the return.  */
#define _MM_PICK_OUT_PS(X, N) _mm_insert_ps (_mm_setzero_ps(), (X),   \
                                             _MM_MK_INSERTPS_NDX((N), 0, 0x0e))

/* Insert int into packed integer array at index.  */
#define _mm_insert_epi8(X, I, N) (__extension__                           \
                                  ({ __v16qi __a = (__v16qi)(__m128i)(X); \
                                     __a[(N) & 15] = (I);                 \
                                     (__m128i)__a;}))
#define _mm_insert_epi32(X, I, N) (__extension__                         \
                                   ({ __v4si __a = (__v4si)(__m128i)(X); \
                                      __a[(N) & 3] = (I);                \
                                      (__m128i)__a;}))
#ifdef __x86_64__
#define _mm_insert_epi64(X, I, N) (__extension__                         \
                                   ({ __v2di __a = (__v2di)(__m128i)(X); \
                                      __a[(N) & 1] = (I);                \
                                      (__m128i)__a;}))
#endif /* __x86_64__ */

/* Extract int from packed integer array at index.  This returns the element
 * as a zero extended value, so it is unsigned.
 */
#define _mm_extract_epi8(X, N) (__extension__                           \
                                ({ __v16qi __a = (__v16qi)(__m128i)(X); \
                                   (int)(unsigned char) __a[(N) & 15];}))
#define _mm_extract_epi32(X, N) (__extension__                         \
                                 ({ __v4si __a = (__v4si)(__m128i)(X); \
                                    (int)__a[(N) & 3];}))
#ifdef __x86_64__
#define _mm_extract_epi64(X, N) (__extension__                         \
                                 ({ __v2di __a = (__v2di)(__m128i)(X); \
                                    (long long)__a[(N) & 1];}))
#endif /* __x86_64 */

/* SSE4 128-bit Packed Integer Comparisons.  */
static __inline__ int __DEFAULT_FN_ATTRS
_mm_testz_si128(__m128i __M, __m128i __V)
{
  return __builtin_ia32_ptestz128((__v2di)__M, (__v2di)__V);
}

static __inline__ int __DEFAULT_FN_ATTRS
_mm_testc_si128(__m128i __M, __m128i __V)
{
  return __builtin_ia32_ptestc128((__v2di)__M, (__v2di)__V);
}

static __inline__ int __DEFAULT_FN_ATTRS
_mm_testnzc_si128(__m128i __M, __m128i __V)
{
  return __builtin_ia32_ptestnzc128((__v2di)__M, (__v2di)__V);
}

#define _mm_test_all_ones(V) _mm_testc_si128((V), _mm_cmpeq_epi32((V), (V)))
#define _mm_test_mix_ones_zeros(M, V) _mm_testnzc_si128((M), (V))
#define _mm_test_all_zeros(M, V) _mm_testz_si128 ((M), (V))

/* SSE4 64-bit Packed Integer Comparisons.  */
static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cmpeq_epi64(__m128i __V1, __m128i __V2)
{
  return (__m128i)((__v2di)__V1 == (__v2di)__V2);
}

/* SSE4 Packed Integer Sign-Extension.  */
static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi8_epi16(__m128i __V)
{
  /* This function always performs a signed extension, but __v16qi is a char
     which may be signed or unsigned, so use __v16qs. */
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v16qs)__V, (__v16qs)__V, 0, 1, 2, 3, 4, 5, 6, 7), __v8hi);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi8_epi32(__m128i __V)
{
  /* This function always performs a signed extension, but __v16qi is a char
     which may be signed or unsigned, so use __v16qs. */
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v16qs)__V, (__v16qs)__V, 0, 1, 2, 3), __v4si);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi8_epi64(__m128i __V)
{
  /* This function always performs a signed extension, but __v16qi is a char
     which may be signed or unsigned, so use __v16qs. */
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v16qs)__V, (__v16qs)__V, 0, 1), __v2di);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi16_epi32(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v8hi)__V, (__v8hi)__V, 0, 1, 2, 3), __v4si);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi16_epi64(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v8hi)__V, (__v8hi)__V, 0, 1), __v2di);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepi32_epi64(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v4si)__V, (__v4si)__V, 0, 1), __v2di);
}

/* SSE4 Packed Integer Zero-Extension.  */
static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepu8_epi16(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v16qu)__V, (__v16qu)__V, 0, 1, 2, 3, 4, 5, 6, 7), __v8hi);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepu8_epi32(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v16qu)__V, (__v16qu)__V, 0, 1, 2, 3), __v4si);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepu8_epi64(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v16qu)__V, (__v16qu)__V, 0, 1), __v2di);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepu16_epi32(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v8hu)__V, (__v8hu)__V, 0, 1, 2, 3), __v4si);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepu16_epi64(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v8hu)__V, (__v8hu)__V, 0, 1), __v2di);
}

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cvtepu32_epi64(__m128i __V)
{
  return (__m128i)__builtin_convertvector(__builtin_shufflevector((__v4su)__V, (__v4su)__V, 0, 1), __v2di);
}

/* SSE4 Pack with Unsigned Saturation.  */
static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_packus_epi32(__m128i __V1, __m128i __V2)
{
  return (__m128i) __builtin_ia32_packusdw128((__v4si)__V1, (__v4si)__V2);
}

/* SSE4 Multiple Packed Sums of Absolute Difference.  */
#define _mm_mpsadbw_epu8(X, Y, M) __extension__ ({ \
  (__m128i) __builtin_ia32_mpsadbw128((__v16qi)(__m128i)(X), \
                                      (__v16qi)(__m128i)(Y), (M)); })

static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_minpos_epu16(__m128i __V)
{
  return (__m128i) __builtin_ia32_phminposuw128((__v8hi)__V);
}

/* Handle the sse4.2 definitions here. */

/* These definitions are normally in nmmintrin.h, but gcc puts them in here
   so we'll do the same.  */

#undef __DEFAULT_FN_ATTRS
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__, __target__("sse4.2")))

/* These specify the type of data that we're comparing.  */
#define _SIDD_UBYTE_OPS                 0x00
#define _SIDD_UWORD_OPS                 0x01
#define _SIDD_SBYTE_OPS                 0x02
#define _SIDD_SWORD_OPS                 0x03

/* These specify the type of comparison operation.  */
#define _SIDD_CMP_EQUAL_ANY             0x00
#define _SIDD_CMP_RANGES                0x04
#define _SIDD_CMP_EQUAL_EACH            0x08
#define _SIDD_CMP_EQUAL_ORDERED         0x0c

/* These macros specify the polarity of the operation.  */
#define _SIDD_POSITIVE_POLARITY         0x00
#define _SIDD_NEGATIVE_POLARITY         0x10
#define _SIDD_MASKED_POSITIVE_POLARITY  0x20
#define _SIDD_MASKED_NEGATIVE_POLARITY  0x30

/* These macros are used in _mm_cmpXstri() to specify the return.  */
#define _SIDD_LEAST_SIGNIFICANT         0x00
#define _SIDD_MOST_SIGNIFICANT          0x40

/* These macros are used in _mm_cmpXstri() to specify the return.  */
#define _SIDD_BIT_MASK                  0x00
#define _SIDD_UNIT_MASK                 0x40

/* SSE4.2 Packed Comparison Intrinsics.  */
#define _mm_cmpistrm(A, B, M) \
  (__m128i)__builtin_ia32_pcmpistrm128((__v16qi)(__m128i)(A), \
                                       (__v16qi)(__m128i)(B), (int)(M))
#define _mm_cmpistri(A, B, M) \
  (int)__builtin_ia32_pcmpistri128((__v16qi)(__m128i)(A), \
                                   (__v16qi)(__m128i)(B), (int)(M))

#define _mm_cmpestrm(A, LA, B, LB, M) \
  (__m128i)__builtin_ia32_pcmpestrm128((__v16qi)(__m128i)(A), (int)(LA), \
                                       (__v16qi)(__m128i)(B), (int)(LB), \
                                       (int)(M))
#define _mm_cmpestri(A, LA, B, LB, M) \
  (int)__builtin_ia32_pcmpestri128((__v16qi)(__m128i)(A), (int)(LA), \
                                   (__v16qi)(__m128i)(B), (int)(LB), \
                                   (int)(M))

/* SSE4.2 Packed Comparison Intrinsics and EFlag Reading.  */
#define _mm_cmpistra(A, B, M) \
  (int)__builtin_ia32_pcmpistria128((__v16qi)(__m128i)(A), \
                                    (__v16qi)(__m128i)(B), (int)(M))
#define _mm_cmpistrc(A, B, M) \
  (int)__builtin_ia32_pcmpistric128((__v16qi)(__m128i)(A), \
                                    (__v16qi)(__m128i)(B), (int)(M))
#define _mm_cmpistro(A, B, M) \
  (int)__builtin_ia32_pcmpistrio128((__v16qi)(__m128i)(A), \
                                    (__v16qi)(__m128i)(B), (int)(M))
#define _mm_cmpistrs(A, B, M) \
  (int)__builtin_ia32_pcmpistris128((__v16qi)(__m128i)(A), \
                                    (__v16qi)(__m128i)(B), (int)(M))
#define _mm_cmpistrz(A, B, M) \
  (int)__builtin_ia32_pcmpistriz128((__v16qi)(__m128i)(A), \
                                    (__v16qi)(__m128i)(B), (int)(M))

#define _mm_cmpestra(A, LA, B, LB, M) \
  (int)__builtin_ia32_pcmpestria128((__v16qi)(__m128i)(A), (int)(LA), \
                                    (__v16qi)(__m128i)(B), (int)(LB), \
                                    (int)(M))
#define _mm_cmpestrc(A, LA, B, LB, M) \
  (int)__builtin_ia32_pcmpestric128((__v16qi)(__m128i)(A), (int)(LA), \
                                    (__v16qi)(__m128i)(B), (int)(LB), \
                                    (int)(M))
#define _mm_cmpestro(A, LA, B, LB, M) \
  (int)__builtin_ia32_pcmpestrio128((__v16qi)(__m128i)(A), (int)(LA), \
                                    (__v16qi)(__m128i)(B), (int)(LB), \
                                    (int)(M))
#define _mm_cmpestrs(A, LA, B, LB, M) \
  (int)__builtin_ia32_pcmpestris128((__v16qi)(__m128i)(A), (int)(LA), \
                                    (__v16qi)(__m128i)(B), (int)(LB), \
                                    (int)(M))
#define _mm_cmpestrz(A, LA, B, LB, M) \
  (int)__builtin_ia32_pcmpestriz128((__v16qi)(__m128i)(A), (int)(LA), \
                                    (__v16qi)(__m128i)(B), (int)(LB), \
                                    (int)(M))

/* SSE4.2 Compare Packed Data -- Greater Than.  */
static __inline__ __m128i __DEFAULT_FN_ATTRS
_mm_cmpgt_epi64(__m128i __V1, __m128i __V2)
{
  return (__m128i)((__v2di)__V1 > (__v2di)__V2);
}

/* SSE4.2 Accumulate CRC32.  */
static __inline__ unsigned int __DEFAULT_FN_ATTRS
_mm_crc32_u8(unsigned int __C, unsigned char __D)
{
  return __builtin_ia32_crc32qi(__C, __D);
}

static __inline__ unsigned int __DEFAULT_FN_ATTRS
_mm_crc32_u16(unsigned int __C, unsigned short __D)
{
  return __builtin_ia32_crc32hi(__C, __D);
}

static __inline__ unsigned int __DEFAULT_FN_ATTRS
_mm_crc32_u32(unsigned int __C, unsigned int __D)
{
  return __builtin_ia32_crc32si(__C, __D);
}

#ifdef __x86_64__
static __inline__ unsigned long long __DEFAULT_FN_ATTRS
_mm_crc32_u64(unsigned long long __C, unsigned long long __D)
{
  return __builtin_ia32_crc32di(__C, __D);
}
#endif /* __x86_64__ */

#undef __DEFAULT_FN_ATTRS

#ifdef __POPCNT__
#include <popcntintrin.h>
#endif

#endif /* _SMMINTRIN_H */
