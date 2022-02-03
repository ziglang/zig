/*===---- mmintrin.h - Implementation of MMX intrinsics on PowerPC ---------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

/* Implemented from the specification included in the Intel C++ Compiler
   User Guide and Reference, version 9.0.  */

#ifndef NO_WARN_X86_INTRINSICS
/* This header file is to help porting code using Intel intrinsics
   explicitly from x86_64 to powerpc64/powerpc64le.

   Since PowerPC target doesn't support native 64-bit vector type, we
   typedef __m64 to 64-bit unsigned long long in MMX intrinsics, which
   works well for _si64 and some _pi32 operations.

   For _pi16 and _pi8 operations, it's better to transfer __m64 into
   128-bit PowerPC vector first. Power8 introduced direct register
   move instructions which helps for more efficient implementation.

   It's user's responsibility to determine if the results of such port
   are acceptable or further changes are needed. Please note that much
   code using Intel intrinsics CAN BE REWRITTEN in more portable and
   efficient standard C or GNU C extensions with 64-bit scalar
   operations, or 128-bit SSE/Altivec operations, which are more
   recommended. */
#error                                                                         \
    "Please read comment above.  Use -DNO_WARN_X86_INTRINSICS to disable this error."
#endif

#ifndef _MMINTRIN_H_INCLUDED
#define _MMINTRIN_H_INCLUDED

#if defined(__ppc64__) && (defined(__linux__) || defined(__FreeBSD__))

#include <altivec.h>
/* The Intel API is flexible enough that we must allow aliasing with other
   vector types, and their scalar components.  */
typedef __attribute__((__aligned__(8))) unsigned long long __m64;

typedef __attribute__((__aligned__(8))) union {
  __m64 as_m64;
  char as_char[8];
  signed char as_signed_char[8];
  short as_short[4];
  int as_int[2];
  long long as_long_long;
  float as_float[2];
  double as_double;
} __m64_union;

/* Empty the multimedia state.  */
extern __inline void
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_empty(void) {
  /* nothing to do on PowerPC.  */
}

extern __inline void
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_empty(void) {
  /* nothing to do on PowerPC.  */
}

/* Convert I to a __m64 object.  The integer is zero-extended to 64-bits.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cvtsi32_si64(int __i) {
  return (__m64)(unsigned int)__i;
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_from_int(int __i) {
  return _mm_cvtsi32_si64(__i);
}

/* Convert the lower 32 bits of the __m64 object into an integer.  */
extern __inline int
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cvtsi64_si32(__m64 __i) {
  return ((int)__i);
}

extern __inline int
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_to_int(__m64 __i) {
  return _mm_cvtsi64_si32(__i);
}

/* Convert I to a __m64 object.  */

/* Intel intrinsic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_from_int64(long long __i) {
  return (__m64)__i;
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cvtsi64_m64(long long __i) {
  return (__m64)__i;
}

/* Microsoft intrinsic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cvtsi64x_si64(long long __i) {
  return (__m64)__i;
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_set_pi64x(long long __i) {
  return (__m64)__i;
}

/* Convert the __m64 object to a 64bit integer.  */

/* Intel intrinsic.  */
extern __inline long long
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_to_int64(__m64 __i) {
  return (long long)__i;
}

extern __inline long long
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cvtm64_si64(__m64 __i) {
  return (long long)__i;
}

/* Microsoft intrinsic.  */
extern __inline long long
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cvtsi64_si64x(__m64 __i) {
  return (long long)__i;
}

#ifdef _ARCH_PWR8
/* Pack the four 16-bit values from M1 into the lower four 8-bit values of
   the result, and the four 16-bit values from M2 into the upper four 8-bit
   values of the result, all with signed saturation.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_packs_pi16(__m64 __m1, __m64 __m2) {
  __vector signed short vm1;
  __vector signed char vresult;

  vm1 = (__vector signed short)(__vector unsigned long long)
#ifdef __LITTLE_ENDIAN__
      {__m1, __m2};
#else
      {__m2, __m1};
#endif
  vresult = vec_packs(vm1, vm1);
  return (__m64)((__vector long long)vresult)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_packsswb(__m64 __m1, __m64 __m2) {
  return _mm_packs_pi16(__m1, __m2);
}

/* Pack the two 32-bit values from M1 in to the lower two 16-bit values of
   the result, and the two 32-bit values from M2 into the upper two 16-bit
   values of the result, all with signed saturation.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_packs_pi32(__m64 __m1, __m64 __m2) {
  __vector signed int vm1;
  __vector signed short vresult;

  vm1 = (__vector signed int)(__vector unsigned long long)
#ifdef __LITTLE_ENDIAN__
      {__m1, __m2};
#else
      {__m2, __m1};
#endif
  vresult = vec_packs(vm1, vm1);
  return (__m64)((__vector long long)vresult)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_packssdw(__m64 __m1, __m64 __m2) {
  return _mm_packs_pi32(__m1, __m2);
}

/* Pack the four 16-bit values from M1 into the lower four 8-bit values of
   the result, and the four 16-bit values from M2 into the upper four 8-bit
   values of the result, all with unsigned saturation.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_packs_pu16(__m64 __m1, __m64 __m2) {
  __vector unsigned char r;
  __vector signed short vm1 = (__vector signed short)(__vector long long)
#ifdef __LITTLE_ENDIAN__
      {__m1, __m2};
#else
      {__m2, __m1};
#endif
  const __vector signed short __zero = {0};
  __vector __bool short __select = vec_cmplt(vm1, __zero);
  r = vec_packs((__vector unsigned short)vm1, (__vector unsigned short)vm1);
  __vector __bool char packsel = vec_pack(__select, __select);
  r = vec_sel(r, (const __vector unsigned char)__zero, packsel);
  return (__m64)((__vector long long)r)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_packuswb(__m64 __m1, __m64 __m2) {
  return _mm_packs_pu16(__m1, __m2);
}
#endif /* end ARCH_PWR8 */

/* Interleave the four 8-bit values from the high half of M1 with the four
   8-bit values from the high half of M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_unpackhi_pi8(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector unsigned char a, b, c;

  a = (__vector unsigned char)vec_splats(__m1);
  b = (__vector unsigned char)vec_splats(__m2);
  c = vec_mergel(a, b);
  return (__m64)((__vector long long)c)[1];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_char[0] = m1.as_char[4];
  res.as_char[1] = m2.as_char[4];
  res.as_char[2] = m1.as_char[5];
  res.as_char[3] = m2.as_char[5];
  res.as_char[4] = m1.as_char[6];
  res.as_char[5] = m2.as_char[6];
  res.as_char[6] = m1.as_char[7];
  res.as_char[7] = m2.as_char[7];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_punpckhbw(__m64 __m1, __m64 __m2) {
  return _mm_unpackhi_pi8(__m1, __m2);
}

/* Interleave the two 16-bit values from the high half of M1 with the two
   16-bit values from the high half of M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_unpackhi_pi16(__m64 __m1, __m64 __m2) {
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_short[0] = m1.as_short[2];
  res.as_short[1] = m2.as_short[2];
  res.as_short[2] = m1.as_short[3];
  res.as_short[3] = m2.as_short[3];

  return (__m64)res.as_m64;
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_punpckhwd(__m64 __m1, __m64 __m2) {
  return _mm_unpackhi_pi16(__m1, __m2);
}
/* Interleave the 32-bit value from the high half of M1 with the 32-bit
   value from the high half of M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_unpackhi_pi32(__m64 __m1, __m64 __m2) {
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_int[0] = m1.as_int[1];
  res.as_int[1] = m2.as_int[1];

  return (__m64)res.as_m64;
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_punpckhdq(__m64 __m1, __m64 __m2) {
  return _mm_unpackhi_pi32(__m1, __m2);
}
/* Interleave the four 8-bit values from the low half of M1 with the four
   8-bit values from the low half of M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_unpacklo_pi8(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector unsigned char a, b, c;

  a = (__vector unsigned char)vec_splats(__m1);
  b = (__vector unsigned char)vec_splats(__m2);
  c = vec_mergel(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_char[0] = m1.as_char[0];
  res.as_char[1] = m2.as_char[0];
  res.as_char[2] = m1.as_char[1];
  res.as_char[3] = m2.as_char[1];
  res.as_char[4] = m1.as_char[2];
  res.as_char[5] = m2.as_char[2];
  res.as_char[6] = m1.as_char[3];
  res.as_char[7] = m2.as_char[3];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_punpcklbw(__m64 __m1, __m64 __m2) {
  return _mm_unpacklo_pi8(__m1, __m2);
}
/* Interleave the two 16-bit values from the low half of M1 with the two
   16-bit values from the low half of M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_unpacklo_pi16(__m64 __m1, __m64 __m2) {
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_short[0] = m1.as_short[0];
  res.as_short[1] = m2.as_short[0];
  res.as_short[2] = m1.as_short[1];
  res.as_short[3] = m2.as_short[1];

  return (__m64)res.as_m64;
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_punpcklwd(__m64 __m1, __m64 __m2) {
  return _mm_unpacklo_pi16(__m1, __m2);
}

/* Interleave the 32-bit value from the low half of M1 with the 32-bit
   value from the low half of M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_unpacklo_pi32(__m64 __m1, __m64 __m2) {
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_int[0] = m1.as_int[0];
  res.as_int[1] = m2.as_int[0];

  return (__m64)res.as_m64;
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_punpckldq(__m64 __m1, __m64 __m2) {
  return _mm_unpacklo_pi32(__m1, __m2);
}

/* Add the 8-bit values in M1 to the 8-bit values in M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_add_pi8(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector signed char a, b, c;

  a = (__vector signed char)vec_splats(__m1);
  b = (__vector signed char)vec_splats(__m2);
  c = vec_add(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_char[0] = m1.as_char[0] + m2.as_char[0];
  res.as_char[1] = m1.as_char[1] + m2.as_char[1];
  res.as_char[2] = m1.as_char[2] + m2.as_char[2];
  res.as_char[3] = m1.as_char[3] + m2.as_char[3];
  res.as_char[4] = m1.as_char[4] + m2.as_char[4];
  res.as_char[5] = m1.as_char[5] + m2.as_char[5];
  res.as_char[6] = m1.as_char[6] + m2.as_char[6];
  res.as_char[7] = m1.as_char[7] + m2.as_char[7];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_paddb(__m64 __m1, __m64 __m2) {
  return _mm_add_pi8(__m1, __m2);
}

/* Add the 16-bit values in M1 to the 16-bit values in M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_add_pi16(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector signed short a, b, c;

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = vec_add(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_short[0] = m1.as_short[0] + m2.as_short[0];
  res.as_short[1] = m1.as_short[1] + m2.as_short[1];
  res.as_short[2] = m1.as_short[2] + m2.as_short[2];
  res.as_short[3] = m1.as_short[3] + m2.as_short[3];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_paddw(__m64 __m1, __m64 __m2) {
  return _mm_add_pi16(__m1, __m2);
}

/* Add the 32-bit values in M1 to the 32-bit values in M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_add_pi32(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR9
  __vector signed int a, b, c;

  a = (__vector signed int)vec_splats(__m1);
  b = (__vector signed int)vec_splats(__m2);
  c = vec_add(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_int[0] = m1.as_int[0] + m2.as_int[0];
  res.as_int[1] = m1.as_int[1] + m2.as_int[1];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_paddd(__m64 __m1, __m64 __m2) {
  return _mm_add_pi32(__m1, __m2);
}

/* Subtract the 8-bit values in M2 from the 8-bit values in M1.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sub_pi8(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector signed char a, b, c;

  a = (__vector signed char)vec_splats(__m1);
  b = (__vector signed char)vec_splats(__m2);
  c = vec_sub(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_char[0] = m1.as_char[0] - m2.as_char[0];
  res.as_char[1] = m1.as_char[1] - m2.as_char[1];
  res.as_char[2] = m1.as_char[2] - m2.as_char[2];
  res.as_char[3] = m1.as_char[3] - m2.as_char[3];
  res.as_char[4] = m1.as_char[4] - m2.as_char[4];
  res.as_char[5] = m1.as_char[5] - m2.as_char[5];
  res.as_char[6] = m1.as_char[6] - m2.as_char[6];
  res.as_char[7] = m1.as_char[7] - m2.as_char[7];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psubb(__m64 __m1, __m64 __m2) {
  return _mm_sub_pi8(__m1, __m2);
}

/* Subtract the 16-bit values in M2 from the 16-bit values in M1.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sub_pi16(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector signed short a, b, c;

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = vec_sub(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_short[0] = m1.as_short[0] - m2.as_short[0];
  res.as_short[1] = m1.as_short[1] - m2.as_short[1];
  res.as_short[2] = m1.as_short[2] - m2.as_short[2];
  res.as_short[3] = m1.as_short[3] - m2.as_short[3];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psubw(__m64 __m1, __m64 __m2) {
  return _mm_sub_pi16(__m1, __m2);
}

/* Subtract the 32-bit values in M2 from the 32-bit values in M1.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sub_pi32(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR9
  __vector signed int a, b, c;

  a = (__vector signed int)vec_splats(__m1);
  b = (__vector signed int)vec_splats(__m2);
  c = vec_sub(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_int[0] = m1.as_int[0] - m2.as_int[0];
  res.as_int[1] = m1.as_int[1] - m2.as_int[1];

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psubd(__m64 __m1, __m64 __m2) {
  return _mm_sub_pi32(__m1, __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_add_si64(__m64 __m1, __m64 __m2) {
  return (__m1 + __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sub_si64(__m64 __m1, __m64 __m2) {
  return (__m1 - __m2);
}

/* Shift the 64-bit value in M left by COUNT.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sll_si64(__m64 __m, __m64 __count) {
  return (__m << __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psllq(__m64 __m, __m64 __count) {
  return _mm_sll_si64(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_slli_si64(__m64 __m, const int __count) {
  return (__m << __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psllqi(__m64 __m, const int __count) {
  return _mm_slli_si64(__m, __count);
}

/* Shift the 64-bit value in M left by COUNT; shift in zeros.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srl_si64(__m64 __m, __m64 __count) {
  return (__m >> __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrlq(__m64 __m, __m64 __count) {
  return _mm_srl_si64(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srli_si64(__m64 __m, const int __count) {
  return (__m >> __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrlqi(__m64 __m, const int __count) {
  return _mm_srli_si64(__m, __count);
}

/* Bit-wise AND the 64-bit values in M1 and M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_and_si64(__m64 __m1, __m64 __m2) {
  return (__m1 & __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pand(__m64 __m1, __m64 __m2) {
  return _mm_and_si64(__m1, __m2);
}

/* Bit-wise complement the 64-bit value in M1 and bit-wise AND it with the
   64-bit value in M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_andnot_si64(__m64 __m1, __m64 __m2) {
  return (~__m1 & __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pandn(__m64 __m1, __m64 __m2) {
  return _mm_andnot_si64(__m1, __m2);
}

/* Bit-wise inclusive OR the 64-bit values in M1 and M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_or_si64(__m64 __m1, __m64 __m2) {
  return (__m1 | __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_por(__m64 __m1, __m64 __m2) {
  return _mm_or_si64(__m1, __m2);
}

/* Bit-wise exclusive OR the 64-bit values in M1 and M2.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_xor_si64(__m64 __m1, __m64 __m2) {
  return (__m1 ^ __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pxor(__m64 __m1, __m64 __m2) {
  return _mm_xor_si64(__m1, __m2);
}

/* Creates a 64-bit zero.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_setzero_si64(void) {
  return (__m64)0;
}

/* Compare eight 8-bit values.  The result of the comparison is 0xFF if the
   test is true and zero if false.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cmpeq_pi8(__m64 __m1, __m64 __m2) {
#if defined(_ARCH_PWR6) && defined(__powerpc64__)
  __m64 res;
  __asm__("cmpb %0,%1,%2;\n" : "=r"(res) : "r"(__m1), "r"(__m2) :);
  return (res);
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_char[0] = (m1.as_char[0] == m2.as_char[0]) ? -1 : 0;
  res.as_char[1] = (m1.as_char[1] == m2.as_char[1]) ? -1 : 0;
  res.as_char[2] = (m1.as_char[2] == m2.as_char[2]) ? -1 : 0;
  res.as_char[3] = (m1.as_char[3] == m2.as_char[3]) ? -1 : 0;
  res.as_char[4] = (m1.as_char[4] == m2.as_char[4]) ? -1 : 0;
  res.as_char[5] = (m1.as_char[5] == m2.as_char[5]) ? -1 : 0;
  res.as_char[6] = (m1.as_char[6] == m2.as_char[6]) ? -1 : 0;
  res.as_char[7] = (m1.as_char[7] == m2.as_char[7]) ? -1 : 0;

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pcmpeqb(__m64 __m1, __m64 __m2) {
  return _mm_cmpeq_pi8(__m1, __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cmpgt_pi8(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector signed char a, b, c;

  a = (__vector signed char)vec_splats(__m1);
  b = (__vector signed char)vec_splats(__m2);
  c = (__vector signed char)vec_cmpgt(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_char[0] = (m1.as_char[0] > m2.as_char[0]) ? -1 : 0;
  res.as_char[1] = (m1.as_char[1] > m2.as_char[1]) ? -1 : 0;
  res.as_char[2] = (m1.as_char[2] > m2.as_char[2]) ? -1 : 0;
  res.as_char[3] = (m1.as_char[3] > m2.as_char[3]) ? -1 : 0;
  res.as_char[4] = (m1.as_char[4] > m2.as_char[4]) ? -1 : 0;
  res.as_char[5] = (m1.as_char[5] > m2.as_char[5]) ? -1 : 0;
  res.as_char[6] = (m1.as_char[6] > m2.as_char[6]) ? -1 : 0;
  res.as_char[7] = (m1.as_char[7] > m2.as_char[7]) ? -1 : 0;

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pcmpgtb(__m64 __m1, __m64 __m2) {
  return _mm_cmpgt_pi8(__m1, __m2);
}

/* Compare four 16-bit values.  The result of the comparison is 0xFFFF if
   the test is true and zero if false.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cmpeq_pi16(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector signed short a, b, c;

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = (__vector signed short)vec_cmpeq(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_short[0] = (m1.as_short[0] == m2.as_short[0]) ? -1 : 0;
  res.as_short[1] = (m1.as_short[1] == m2.as_short[1]) ? -1 : 0;
  res.as_short[2] = (m1.as_short[2] == m2.as_short[2]) ? -1 : 0;
  res.as_short[3] = (m1.as_short[3] == m2.as_short[3]) ? -1 : 0;

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pcmpeqw(__m64 __m1, __m64 __m2) {
  return _mm_cmpeq_pi16(__m1, __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cmpgt_pi16(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR8
  __vector signed short a, b, c;

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = (__vector signed short)vec_cmpgt(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_short[0] = (m1.as_short[0] > m2.as_short[0]) ? -1 : 0;
  res.as_short[1] = (m1.as_short[1] > m2.as_short[1]) ? -1 : 0;
  res.as_short[2] = (m1.as_short[2] > m2.as_short[2]) ? -1 : 0;
  res.as_short[3] = (m1.as_short[3] > m2.as_short[3]) ? -1 : 0;

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pcmpgtw(__m64 __m1, __m64 __m2) {
  return _mm_cmpgt_pi16(__m1, __m2);
}

/* Compare two 32-bit values.  The result of the comparison is 0xFFFFFFFF if
   the test is true and zero if false.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cmpeq_pi32(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR9
  __vector signed int a, b, c;

  a = (__vector signed int)vec_splats(__m1);
  b = (__vector signed int)vec_splats(__m2);
  c = (__vector signed int)vec_cmpeq(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_int[0] = (m1.as_int[0] == m2.as_int[0]) ? -1 : 0;
  res.as_int[1] = (m1.as_int[1] == m2.as_int[1]) ? -1 : 0;

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pcmpeqd(__m64 __m1, __m64 __m2) {
  return _mm_cmpeq_pi32(__m1, __m2);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_cmpgt_pi32(__m64 __m1, __m64 __m2) {
#if _ARCH_PWR9
  __vector signed int a, b, c;

  a = (__vector signed int)vec_splats(__m1);
  b = (__vector signed int)vec_splats(__m2);
  c = (__vector signed int)vec_cmpgt(a, b);
  return (__m64)((__vector long long)c)[0];
#else
  __m64_union m1, m2, res;

  m1.as_m64 = __m1;
  m2.as_m64 = __m2;

  res.as_int[0] = (m1.as_int[0] > m2.as_int[0]) ? -1 : 0;
  res.as_int[1] = (m1.as_int[1] > m2.as_int[1]) ? -1 : 0;

  return (__m64)res.as_m64;
#endif
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pcmpgtd(__m64 __m1, __m64 __m2) {
  return _mm_cmpgt_pi32(__m1, __m2);
}

#if _ARCH_PWR8
/* Add the 8-bit values in M1 to the 8-bit values in M2 using signed
   saturated arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_adds_pi8(__m64 __m1, __m64 __m2) {
  __vector signed char a, b, c;

  a = (__vector signed char)vec_splats(__m1);
  b = (__vector signed char)vec_splats(__m2);
  c = vec_adds(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_paddsb(__m64 __m1, __m64 __m2) {
  return _mm_adds_pi8(__m1, __m2);
}
/* Add the 16-bit values in M1 to the 16-bit values in M2 using signed
   saturated arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_adds_pi16(__m64 __m1, __m64 __m2) {
  __vector signed short a, b, c;

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = vec_adds(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_paddsw(__m64 __m1, __m64 __m2) {
  return _mm_adds_pi16(__m1, __m2);
}
/* Add the 8-bit values in M1 to the 8-bit values in M2 using unsigned
   saturated arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_adds_pu8(__m64 __m1, __m64 __m2) {
  __vector unsigned char a, b, c;

  a = (__vector unsigned char)vec_splats(__m1);
  b = (__vector unsigned char)vec_splats(__m2);
  c = vec_adds(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_paddusb(__m64 __m1, __m64 __m2) {
  return _mm_adds_pu8(__m1, __m2);
}

/* Add the 16-bit values in M1 to the 16-bit values in M2 using unsigned
   saturated arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_adds_pu16(__m64 __m1, __m64 __m2) {
  __vector unsigned short a, b, c;

  a = (__vector unsigned short)vec_splats(__m1);
  b = (__vector unsigned short)vec_splats(__m2);
  c = vec_adds(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_paddusw(__m64 __m1, __m64 __m2) {
  return _mm_adds_pu16(__m1, __m2);
}

/* Subtract the 8-bit values in M2 from the 8-bit values in M1 using signed
   saturating arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_subs_pi8(__m64 __m1, __m64 __m2) {
  __vector signed char a, b, c;

  a = (__vector signed char)vec_splats(__m1);
  b = (__vector signed char)vec_splats(__m2);
  c = vec_subs(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psubsb(__m64 __m1, __m64 __m2) {
  return _mm_subs_pi8(__m1, __m2);
}

/* Subtract the 16-bit values in M2 from the 16-bit values in M1 using
   signed saturating arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_subs_pi16(__m64 __m1, __m64 __m2) {
  __vector signed short a, b, c;

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = vec_subs(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psubsw(__m64 __m1, __m64 __m2) {
  return _mm_subs_pi16(__m1, __m2);
}

/* Subtract the 8-bit values in M2 from the 8-bit values in M1 using
   unsigned saturating arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_subs_pu8(__m64 __m1, __m64 __m2) {
  __vector unsigned char a, b, c;

  a = (__vector unsigned char)vec_splats(__m1);
  b = (__vector unsigned char)vec_splats(__m2);
  c = vec_subs(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psubusb(__m64 __m1, __m64 __m2) {
  return _mm_subs_pu8(__m1, __m2);
}

/* Subtract the 16-bit values in M2 from the 16-bit values in M1 using
   unsigned saturating arithmetic.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_subs_pu16(__m64 __m1, __m64 __m2) {
  __vector unsigned short a, b, c;

  a = (__vector unsigned short)vec_splats(__m1);
  b = (__vector unsigned short)vec_splats(__m2);
  c = vec_subs(a, b);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psubusw(__m64 __m1, __m64 __m2) {
  return _mm_subs_pu16(__m1, __m2);
}

/* Multiply four 16-bit values in M1 by four 16-bit values in M2 producing
   four 32-bit intermediate results, which are then summed by pairs to
   produce two 32-bit results.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_madd_pi16(__m64 __m1, __m64 __m2) {
  __vector signed short a, b;
  __vector signed int c;
  __vector signed int zero = {0, 0, 0, 0};

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = vec_vmsumshm(a, b, zero);
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pmaddwd(__m64 __m1, __m64 __m2) {
  return _mm_madd_pi16(__m1, __m2);
}
/* Multiply four signed 16-bit values in M1 by four signed 16-bit values in
   M2 and produce the high 16 bits of the 32-bit results.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_mulhi_pi16(__m64 __m1, __m64 __m2) {
  __vector signed short a, b;
  __vector signed short c;
  __vector signed int w0, w1;
  __vector unsigned char xform1 = {
#ifdef __LITTLE_ENDIAN__
      0x02, 0x03, 0x12, 0x13, 0x06, 0x07, 0x16, 0x17, 0x0A,
      0x0B, 0x1A, 0x1B, 0x0E, 0x0F, 0x1E, 0x1F
#else
      0x00, 0x01, 0x10, 0x11, 0x04, 0x05, 0x14, 0x15, 0x00,
      0x01, 0x10, 0x11, 0x04, 0x05, 0x14, 0x15
#endif
  };

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);

  w0 = vec_vmulesh(a, b);
  w1 = vec_vmulosh(a, b);
  c = (__vector signed short)vec_perm(w0, w1, xform1);

  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pmulhw(__m64 __m1, __m64 __m2) {
  return _mm_mulhi_pi16(__m1, __m2);
}

/* Multiply four 16-bit values in M1 by four 16-bit values in M2 and produce
   the low 16 bits of the results.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_mullo_pi16(__m64 __m1, __m64 __m2) {
  __vector signed short a, b, c;

  a = (__vector signed short)vec_splats(__m1);
  b = (__vector signed short)vec_splats(__m2);
  c = a * b;
  return (__m64)((__vector long long)c)[0];
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pmullw(__m64 __m1, __m64 __m2) {
  return _mm_mullo_pi16(__m1, __m2);
}

/* Shift four 16-bit values in M left by COUNT.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sll_pi16(__m64 __m, __m64 __count) {
  __vector signed short m, r;
  __vector unsigned short c;

  if (__count <= 15) {
    m = (__vector signed short)vec_splats(__m);
    c = (__vector unsigned short)vec_splats((unsigned short)__count);
    r = vec_sl(m, (__vector unsigned short)c);
    return (__m64)((__vector long long)r)[0];
  } else
    return (0);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psllw(__m64 __m, __m64 __count) {
  return _mm_sll_pi16(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_slli_pi16(__m64 __m, int __count) {
  /* Promote int to long then invoke mm_sll_pi16.  */
  return _mm_sll_pi16(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psllwi(__m64 __m, int __count) {
  return _mm_slli_pi16(__m, __count);
}

/* Shift two 32-bit values in M left by COUNT.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sll_pi32(__m64 __m, __m64 __count) {
  __m64_union m, res;

  m.as_m64 = __m;

  res.as_int[0] = m.as_int[0] << __count;
  res.as_int[1] = m.as_int[1] << __count;
  return (res.as_m64);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pslld(__m64 __m, __m64 __count) {
  return _mm_sll_pi32(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_slli_pi32(__m64 __m, int __count) {
  /* Promote int to long then invoke mm_sll_pi32.  */
  return _mm_sll_pi32(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_pslldi(__m64 __m, int __count) {
  return _mm_slli_pi32(__m, __count);
}

/* Shift four 16-bit values in M right by COUNT; shift in the sign bit.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sra_pi16(__m64 __m, __m64 __count) {
  __vector signed short m, r;
  __vector unsigned short c;

  if (__count <= 15) {
    m = (__vector signed short)vec_splats(__m);
    c = (__vector unsigned short)vec_splats((unsigned short)__count);
    r = vec_sra(m, (__vector unsigned short)c);
    return (__m64)((__vector long long)r)[0];
  } else
    return (0);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psraw(__m64 __m, __m64 __count) {
  return _mm_sra_pi16(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srai_pi16(__m64 __m, int __count) {
  /* Promote int to long then invoke mm_sra_pi32.  */
  return _mm_sra_pi16(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrawi(__m64 __m, int __count) {
  return _mm_srai_pi16(__m, __count);
}

/* Shift two 32-bit values in M right by COUNT; shift in the sign bit.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_sra_pi32(__m64 __m, __m64 __count) {
  __m64_union m, res;

  m.as_m64 = __m;

  res.as_int[0] = m.as_int[0] >> __count;
  res.as_int[1] = m.as_int[1] >> __count;
  return (res.as_m64);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrad(__m64 __m, __m64 __count) {
  return _mm_sra_pi32(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srai_pi32(__m64 __m, int __count) {
  /* Promote int to long then invoke mm_sra_pi32.  */
  return _mm_sra_pi32(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psradi(__m64 __m, int __count) {
  return _mm_srai_pi32(__m, __count);
}

/* Shift four 16-bit values in M right by COUNT; shift in zeros.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srl_pi16(__m64 __m, __m64 __count) {
  __vector unsigned short m, r;
  __vector unsigned short c;

  if (__count <= 15) {
    m = (__vector unsigned short)vec_splats(__m);
    c = (__vector unsigned short)vec_splats((unsigned short)__count);
    r = vec_sr(m, (__vector unsigned short)c);
    return (__m64)((__vector long long)r)[0];
  } else
    return (0);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrlw(__m64 __m, __m64 __count) {
  return _mm_srl_pi16(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srli_pi16(__m64 __m, int __count) {
  /* Promote int to long then invoke mm_sra_pi32.  */
  return _mm_srl_pi16(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrlwi(__m64 __m, int __count) {
  return _mm_srli_pi16(__m, __count);
}

/* Shift two 32-bit values in M right by COUNT; shift in zeros.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srl_pi32(__m64 __m, __m64 __count) {
  __m64_union m, res;

  m.as_m64 = __m;

  res.as_int[0] = (unsigned int)m.as_int[0] >> __count;
  res.as_int[1] = (unsigned int)m.as_int[1] >> __count;
  return (res.as_m64);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrld(__m64 __m, __m64 __count) {
  return _mm_srl_pi32(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_srli_pi32(__m64 __m, int __count) {
  /* Promote int to long then invoke mm_srl_pi32.  */
  return _mm_srl_pi32(__m, __count);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _m_psrldi(__m64 __m, int __count) {
  return _mm_srli_pi32(__m, __count);
}
#endif /* _ARCH_PWR8 */

/* Creates a vector of two 32-bit values; I0 is least significant.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_set_pi32(int __i1, int __i0) {
  __m64_union res;

  res.as_int[0] = __i0;
  res.as_int[1] = __i1;
  return (res.as_m64);
}

/* Creates a vector of four 16-bit values; W0 is least significant.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_set_pi16(short __w3, short __w2, short __w1, short __w0) {
  __m64_union res;

  res.as_short[0] = __w0;
  res.as_short[1] = __w1;
  res.as_short[2] = __w2;
  res.as_short[3] = __w3;
  return (res.as_m64);
}

/* Creates a vector of eight 8-bit values; B0 is least significant.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_set_pi8(char __b7, char __b6, char __b5, char __b4, char __b3,
                char __b2, char __b1, char __b0) {
  __m64_union res;

  res.as_char[0] = __b0;
  res.as_char[1] = __b1;
  res.as_char[2] = __b2;
  res.as_char[3] = __b3;
  res.as_char[4] = __b4;
  res.as_char[5] = __b5;
  res.as_char[6] = __b6;
  res.as_char[7] = __b7;
  return (res.as_m64);
}

/* Similar, but with the arguments in reverse order.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_setr_pi32(int __i0, int __i1) {
  __m64_union res;

  res.as_int[0] = __i0;
  res.as_int[1] = __i1;
  return (res.as_m64);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_setr_pi16(short __w0, short __w1, short __w2, short __w3) {
  return _mm_set_pi16(__w3, __w2, __w1, __w0);
}

extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_setr_pi8(char __b0, char __b1, char __b2, char __b3, char __b4,
                 char __b5, char __b6, char __b7) {
  return _mm_set_pi8(__b7, __b6, __b5, __b4, __b3, __b2, __b1, __b0);
}

/* Creates a vector of two 32-bit values, both elements containing I.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_set1_pi32(int __i) {
  __m64_union res;

  res.as_int[0] = __i;
  res.as_int[1] = __i;
  return (res.as_m64);
}

/* Creates a vector of four 16-bit values, all elements containing W.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_set1_pi16(short __w) {
#if _ARCH_PWR9
  __vector signed short w;

  w = (__vector signed short)vec_splats(__w);
  return (__m64)((__vector long long)w)[0];
#else
  __m64_union res;

  res.as_short[0] = __w;
  res.as_short[1] = __w;
  res.as_short[2] = __w;
  res.as_short[3] = __w;
  return (res.as_m64);
#endif
}

/* Creates a vector of eight 8-bit values, all elements containing B.  */
extern __inline __m64
    __attribute__((__gnu_inline__, __always_inline__, __artificial__))
    _mm_set1_pi8(signed char __b) {
#if _ARCH_PWR8
  __vector signed char b;

  b = (__vector signed char)vec_splats(__b);
  return (__m64)((__vector long long)b)[0];
#else
  __m64_union res;

  res.as_char[0] = __b;
  res.as_char[1] = __b;
  res.as_char[2] = __b;
  res.as_char[3] = __b;
  res.as_char[4] = __b;
  res.as_char[5] = __b;
  res.as_char[6] = __b;
  res.as_char[7] = __b;
  return (res.as_m64);
#endif
}

#else
#include_next <mmintrin.h>
#endif /* defined(__ppc64__) && (defined(__linux__) || defined(__FreeBSD__))   \
        */

#endif /* _MMINTRIN_H_INCLUDED */
