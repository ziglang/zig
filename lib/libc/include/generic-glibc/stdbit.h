/* ISO C23 Standard: 7.18 - Bit and byte utilities <stdbit.h>.
   Copyright (C) 2024 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _STDBIT_H
#define _STDBIT_H	1

#include <features.h>
#include <bits/endian.h>
#include <bits/stdint-intn.h>
#include <bits/stdint-uintn.h>
#include <bits/stdint-least.h>
/* In C23, <stdbool.h> defines only an implementation-namespace macro,
   so is OK to include here.  Before C23, including <stdbool.h> allows
   the header to use bool rather than _Bool unconditionally, and so to
   compile as C++ (although the type-generic macros are not a good
   form of type-generic interface for C++).  */
#include <stdbool.h>
#define __need_size_t
#include <stddef.h>

#define __STDC_VERSION_STDBIT_H__	202311L

#define __STDC_ENDIAN_LITTLE__		__LITTLE_ENDIAN
#define __STDC_ENDIAN_BIG__		__BIG_ENDIAN
#define __STDC_ENDIAN_NATIVE__		__BYTE_ORDER

__BEGIN_DECLS

/* Use __pacify_uint16 (N) instead of (uint16_t) (N) when the cast is helpful
   only to pacify older GCC (e.g., GCC 10 -Wconversion) or non-GCC (e.g
   clang -Wimplicit-int-conversion).  */
#if __GNUC_PREREQ (11, 0)
# define __pacify_uint8(n)  (n)
# define __pacify_uint16(n) (n)
#else
# define __pacify_uint8(n)  ((uint8_t) (n))
# define __pacify_uint16(n) ((uint16_t) (n))
#endif

/* Count leading zeros.  */
extern unsigned int stdc_leading_zeros_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_leading_zeros_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_leading_zeros_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_leading_zeros_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_leading_zeros_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_leading_zeros)
# define stdc_leading_zeros(x) (__builtin_stdc_leading_zeros (x))
#else
# define stdc_leading_zeros(x)				\
  (stdc_leading_zeros_ull (x)				\
   - (unsigned int) (8 * (sizeof (0ULL) - sizeof (x))))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_clzll)
static __always_inline unsigned int
__clz64_inline (uint64_t __x)
{
  return __x == 0 ? 64U : (unsigned int) __builtin_clzll (__x);
}

static __always_inline unsigned int
__clz32_inline (uint32_t __x)
{
  return __x == 0 ? 32U : (unsigned int) __builtin_clz (__x);
}

static __always_inline unsigned int
__clz16_inline (uint16_t __x)
{
  return __clz32_inline (__x) - 16;
}

static __always_inline unsigned int
__clz8_inline (uint8_t __x)
{
  return __clz32_inline (__x) - 24;
}

# define stdc_leading_zeros_uc(x) (__clz8_inline (x))
# define stdc_leading_zeros_us(x) (__clz16_inline (x))
# define stdc_leading_zeros_ui(x) (__clz32_inline (x))
# if __WORDSIZE == 64
#  define stdc_leading_zeros_ul(x) (__clz64_inline (x))
# else
#  define stdc_leading_zeros_ul(x) (__clz32_inline (x))
# endif
# define stdc_leading_zeros_ull(x) (__clz64_inline (x))
#endif

/* Count leading ones.  */
extern unsigned int stdc_leading_ones_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_leading_ones_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_leading_ones_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_leading_ones_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_leading_ones_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_leading_ones)
# define stdc_leading_ones(x) (__builtin_stdc_leading_ones (x))
#else
# define stdc_leading_ones(x)					\
  (stdc_leading_ones_ull ((unsigned long long int) (x)		\
			  << 8 * (sizeof (0ULL) - sizeof (x))))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_clzll)
static __always_inline unsigned int
__clo64_inline (uint64_t __x)
{
  return __clz64_inline (~__x);
}

static __always_inline unsigned int
__clo32_inline (uint32_t __x)
{
  return __clz32_inline (~__x);
}

static __always_inline unsigned int
__clo16_inline (uint16_t __x)
{
  return __clz16_inline (__pacify_uint16 (~__x));
}

static __always_inline unsigned int
__clo8_inline (uint8_t __x)
{
  return __clz8_inline (__pacify_uint8 (~__x));
}

# define stdc_leading_ones_uc(x) (__clo8_inline (x))
# define stdc_leading_ones_us(x) (__clo16_inline (x))
# define stdc_leading_ones_ui(x) (__clo32_inline (x))
# if __WORDSIZE == 64
#  define stdc_leading_ones_ul(x) (__clo64_inline (x))
# else
#  define stdc_leading_ones_ul(x) (__clo32_inline (x))
# endif
# define stdc_leading_ones_ull(x) (__clo64_inline (x))
#endif

/* Count trailing zeros.  */
extern unsigned int stdc_trailing_zeros_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_trailing_zeros_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_trailing_zeros_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_trailing_zeros_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_trailing_zeros_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_trailing_zeros)
# define stdc_trailing_zeros(x) (__builtin_stdc_trailing_zeros (x))
#else
# define stdc_trailing_zeros(x)				\
  (sizeof (x) == 8 ? stdc_trailing_zeros_ull (x)	\
   : sizeof (x) == 4 ? stdc_trailing_zeros_ui (x)	\
   : sizeof (x) == 2 ? stdc_trailing_zeros_us (__pacify_uint16 (x))	\
   : stdc_trailing_zeros_uc (__pacify_uint8 (x)))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_ctzll)
static __always_inline unsigned int
__ctz64_inline (uint64_t __x)
{
  return __x == 0 ? 64U : (unsigned int) __builtin_ctzll (__x);
}

static __always_inline unsigned int
__ctz32_inline (uint32_t __x)
{
  return __x == 0 ? 32U : (unsigned int) __builtin_ctz (__x);
}

static __always_inline unsigned int
__ctz16_inline (uint16_t __x)
{
  return __x == 0 ? 16U : (unsigned int) __builtin_ctz (__x);
}

static __always_inline unsigned int
__ctz8_inline (uint8_t __x)
{
  return __x == 0 ? 8U : (unsigned int) __builtin_ctz (__x);
}

# define stdc_trailing_zeros_uc(x) (__ctz8_inline (x))
# define stdc_trailing_zeros_us(x) (__ctz16_inline (x))
# define stdc_trailing_zeros_ui(x) (__ctz32_inline (x))
# if __WORDSIZE == 64
#  define stdc_trailing_zeros_ul(x) (__ctz64_inline (x))
# else
#  define stdc_trailing_zeros_ul(x) (__ctz32_inline (x))
# endif
# define stdc_trailing_zeros_ull(x) (__ctz64_inline (x))
#endif

/* Count trailing ones.  */
extern unsigned int stdc_trailing_ones_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_trailing_ones_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_trailing_ones_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_trailing_ones_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_trailing_ones_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_trailing_ones)
# define stdc_trailing_ones(x) (__builtin_stdc_trailing_ones (x))
#else
# define stdc_trailing_ones(x) (stdc_trailing_ones_ull (x))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_ctzll)
static __always_inline unsigned int
__cto64_inline (uint64_t __x)
{
  return __ctz64_inline (~__x);
}

static __always_inline unsigned int
__cto32_inline (uint32_t __x)
{
  return __ctz32_inline (~__x);
}

static __always_inline unsigned int
__cto16_inline (uint16_t __x)
{
  return __ctz16_inline (__pacify_uint16 (~__x));
}

static __always_inline unsigned int
__cto8_inline (uint8_t __x)
{
  return __ctz8_inline (__pacify_uint8 (~__x));
}

# define stdc_trailing_ones_uc(x) (__cto8_inline (x))
# define stdc_trailing_ones_us(x) (__cto16_inline (x))
# define stdc_trailing_ones_ui(x) (__cto32_inline (x))
# if __WORDSIZE == 64
#  define stdc_trailing_ones_ul(x) (__cto64_inline (x))
# else
#  define stdc_trailing_ones_ul(x) (__cto32_inline (x))
# endif
# define stdc_trailing_ones_ull(x) (__cto64_inline (x))
#endif

/* First leading zero.  */
extern unsigned int stdc_first_leading_zero_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_leading_zero_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_leading_zero_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_leading_zero_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_first_leading_zero_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_first_leading_zero)
# define stdc_first_leading_zero(x) (__builtin_stdc_first_leading_zero (x))
#else
# define stdc_first_leading_zero(x)			\
  (sizeof (x) == 8 ? stdc_first_leading_zero_ull (x)	\
   : sizeof (x) == 4 ? stdc_first_leading_zero_ui (x)	\
   : sizeof (x) == 2 ? stdc_first_leading_zero_us (__pacify_uint16 (x))	\
   : stdc_first_leading_zero_uc (__pacify_uint8 (x)))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_clzll)
static __always_inline unsigned int
__flz64_inline (uint64_t __x)
{
  return __x == (uint64_t) -1 ? 0 : 1 + __clo64_inline (__x);
}

static __always_inline unsigned int
__flz32_inline (uint32_t __x)
{
  return __x == (uint32_t) -1 ? 0 : 1 + __clo32_inline (__x);
}

static __always_inline unsigned int
__flz16_inline (uint16_t __x)
{
  return __x == (uint16_t) -1 ? 0 : 1 + __clo16_inline (__x);
}

static __always_inline unsigned int
__flz8_inline (uint8_t __x)
{
  return __x == (uint8_t) -1 ? 0 : 1 + __clo8_inline (__x);
}

# define stdc_first_leading_zero_uc(x) (__flz8_inline (x))
# define stdc_first_leading_zero_us(x) (__flz16_inline (x))
# define stdc_first_leading_zero_ui(x) (__flz32_inline (x))
# if __WORDSIZE == 64
#  define stdc_first_leading_zero_ul(x) (__flz64_inline (x))
# else
#  define stdc_first_leading_zero_ul(x) (__flz32_inline (x))
# endif
# define stdc_first_leading_zero_ull(x) (__flz64_inline (x))
#endif

/* First leading one.  */
extern unsigned int stdc_first_leading_one_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_leading_one_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_leading_one_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_leading_one_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_first_leading_one_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_first_leading_one)
# define stdc_first_leading_one(x) (__builtin_stdc_first_leading_one (x))
#else
# define stdc_first_leading_one(x)			\
  (sizeof (x) == 8 ? stdc_first_leading_one_ull (x)	\
   : sizeof (x) == 4 ? stdc_first_leading_one_ui (x)	\
   : sizeof (x) == 2 ? stdc_first_leading_one_us (__pacify_uint16 (x))	\
   : stdc_first_leading_one_uc (__pacify_uint8 (x)))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_clzll)
static __always_inline unsigned int
__flo64_inline (uint64_t __x)
{
  return __x == 0 ? 0 : 1 + __clz64_inline (__x);
}

static __always_inline unsigned int
__flo32_inline (uint32_t __x)
{
  return __x == 0 ? 0 : 1 + __clz32_inline (__x);
}

static __always_inline unsigned int
__flo16_inline (uint16_t __x)
{
  return __x == 0 ? 0 : 1 + __clz16_inline (__x);
}

static __always_inline unsigned int
__flo8_inline (uint8_t __x)
{
  return __x == 0 ? 0 : 1 + __clz8_inline (__x);
}

# define stdc_first_leading_one_uc(x) (__flo8_inline (x))
# define stdc_first_leading_one_us(x) (__flo16_inline (x))
# define stdc_first_leading_one_ui(x) (__flo32_inline (x))
# if __WORDSIZE == 64
#  define stdc_first_leading_one_ul(x) (__flo64_inline (x))
# else
#  define stdc_first_leading_one_ul(x) (__flo32_inline (x))
# endif
# define stdc_first_leading_one_ull(x) (__flo64_inline (x))
#endif

/* First trailing zero.  */
extern unsigned int stdc_first_trailing_zero_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_trailing_zero_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_trailing_zero_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_trailing_zero_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_first_trailing_zero_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_first_trailing_zero)
# define stdc_first_trailing_zero(x) (__builtin_stdc_first_trailing_zero (x))
#else
# define stdc_first_trailing_zero(x)			\
  (sizeof (x) == 8 ? stdc_first_trailing_zero_ull (x)	\
   : sizeof (x) == 4 ? stdc_first_trailing_zero_ui (x)	\
   : sizeof (x) == 2 ? stdc_first_trailing_zero_us (__pacify_uint16 (x)) \
   : stdc_first_trailing_zero_uc (__pacify_uint8 (x)))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_ctzll)
static __always_inline unsigned int
__ftz64_inline (uint64_t __x)
{
  return __x == (uint64_t) -1 ? 0 : 1 + __cto64_inline (__x);
}

static __always_inline unsigned int
__ftz32_inline (uint32_t __x)
{
  return __x == (uint32_t) -1 ? 0 : 1 + __cto32_inline (__x);
}

static __always_inline unsigned int
__ftz16_inline (uint16_t __x)
{
  return __x == (uint16_t) -1 ? 0 : 1 + __cto16_inline (__x);
}

static __always_inline unsigned int
__ftz8_inline (uint8_t __x)
{
  return __x == (uint8_t) -1 ? 0 : 1 + __cto8_inline (__x);
}

# define stdc_first_trailing_zero_uc(x) (__ftz8_inline (x))
# define stdc_first_trailing_zero_us(x) (__ftz16_inline (x))
# define stdc_first_trailing_zero_ui(x) (__ftz32_inline (x))
# if __WORDSIZE == 64
#  define stdc_first_trailing_zero_ul(x) (__ftz64_inline (x))
# else
#  define stdc_first_trailing_zero_ul(x) (__ftz32_inline (x))
# endif
# define stdc_first_trailing_zero_ull(x) (__ftz64_inline (x))
#endif

/* First trailing one.  */
extern unsigned int stdc_first_trailing_one_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_trailing_one_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_trailing_one_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_first_trailing_one_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_first_trailing_one_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_first_trailing_one)
# define stdc_first_trailing_one(x) (__builtin_stdc_first_trailing_one (x))
#else
# define stdc_first_trailing_one(x)			\
  (sizeof (x) == 8 ? stdc_first_trailing_one_ull (x)	\
   : sizeof (x) == 4 ? stdc_first_trailing_one_ui (x)	\
   : sizeof (x) == 2 ? stdc_first_trailing_one_us (__pacify_uint16 (x))	\
   : stdc_first_trailing_one_uc (__pacify_uint8 (x)))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_ctzll)
static __always_inline unsigned int
__fto64_inline (uint64_t __x)
{
  return __x == 0 ? 0 : 1 + __ctz64_inline (__x);
}

static __always_inline unsigned int
__fto32_inline (uint32_t __x)
{
  return __x == 0 ? 0 : 1 + __ctz32_inline (__x);
}

static __always_inline unsigned int
__fto16_inline (uint16_t __x)
{
  return __x == 0 ? 0 : 1 + __ctz16_inline (__x);
}

static __always_inline unsigned int
__fto8_inline (uint8_t __x)
{
  return __x == 0 ? 0 : 1 + __ctz8_inline (__x);
}

# define stdc_first_trailing_one_uc(x) (__fto8_inline (x))
# define stdc_first_trailing_one_us(x) (__fto16_inline (x))
# define stdc_first_trailing_one_ui(x) (__fto32_inline (x))
# if __WORDSIZE == 64
#  define stdc_first_trailing_one_ul(x) (__fto64_inline (x))
# else
#  define stdc_first_trailing_one_ul(x) (__fto32_inline (x))
# endif
# define stdc_first_trailing_one_ull(x) (__fto64_inline (x))
#endif

/* Count zeros.  */
extern unsigned int stdc_count_zeros_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_count_zeros_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_count_zeros_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_count_zeros_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_count_zeros_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_count_zeros)
# define stdc_count_zeros(x) (__builtin_stdc_count_zeros (x))
#else
# define stdc_count_zeros(x)				\
  (stdc_count_zeros_ull (x)				\
   - (unsigned int) (8 * (sizeof (0ULL) - sizeof (x))))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_popcountll)
static __always_inline unsigned int
__cz64_inline (uint64_t __x)
{
  return 64U - (unsigned int) __builtin_popcountll (__x);
}

static __always_inline unsigned int
__cz32_inline (uint32_t __x)
{
  return 32U - (unsigned int) __builtin_popcount (__x);
}

static __always_inline unsigned int
__cz16_inline (uint16_t __x)
{
  return 16U - (unsigned int) __builtin_popcount (__x);
}

static __always_inline unsigned int
__cz8_inline (uint8_t __x)
{
  return 8U - (unsigned int) __builtin_popcount (__x);
}

# define stdc_count_zeros_uc(x) (__cz8_inline (x))
# define stdc_count_zeros_us(x) (__cz16_inline (x))
# define stdc_count_zeros_ui(x) (__cz32_inline (x))
# if __WORDSIZE == 64
#  define stdc_count_zeros_ul(x) (__cz64_inline (x))
# else
#  define stdc_count_zeros_ul(x) (__cz32_inline (x))
# endif
# define stdc_count_zeros_ull(x) (__cz64_inline (x))
#endif

/* Count ones.  */
extern unsigned int stdc_count_ones_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_count_ones_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_count_ones_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_count_ones_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_count_ones_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_count_ones)
# define stdc_count_ones(x) (__builtin_stdc_count_ones (x))
#else
# define stdc_count_ones(x) (stdc_count_ones_ull (x))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_popcountll)
static __always_inline unsigned int
__co64_inline (uint64_t __x)
{
  return (unsigned int) __builtin_popcountll (__x);
}

static __always_inline unsigned int
__co32_inline (uint32_t __x)
{
  return (unsigned int) __builtin_popcount (__x);
}

static __always_inline unsigned int
__co16_inline (uint16_t __x)
{
  return (unsigned int) __builtin_popcount (__x);
}

static __always_inline unsigned int
__co8_inline (uint8_t __x)
{
  return (unsigned int) __builtin_popcount (__x);
}

# define stdc_count_ones_uc(x) (__co8_inline (x))
# define stdc_count_ones_us(x) (__co16_inline (x))
# define stdc_count_ones_ui(x) (__co32_inline (x))
# if __WORDSIZE == 64
#  define stdc_count_ones_ul(x) (__co64_inline (x))
# else
#  define stdc_count_ones_ul(x) (__co32_inline (x))
# endif
# define stdc_count_ones_ull(x) (__co64_inline (x))
#endif

/* Single-bit check.  */
extern bool stdc_has_single_bit_uc (unsigned char __x)
     __THROW __attribute_const__;
extern bool stdc_has_single_bit_us (unsigned short __x)
     __THROW __attribute_const__;
extern bool stdc_has_single_bit_ui (unsigned int __x)
     __THROW __attribute_const__;
extern bool stdc_has_single_bit_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern bool stdc_has_single_bit_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_has_single_bit)
# define stdc_has_single_bit(x) (__builtin_stdc_has_single_bit (x))
#else
# define stdc_has_single_bit(x)				\
  ((bool) (sizeof (x) <= sizeof (unsigned int)		\
	   ? stdc_has_single_bit_ui (x)			\
	   : stdc_has_single_bit_ull (x)))
#endif

static __always_inline bool
__hsb64_inline (uint64_t __x)
{
  return (__x ^ (__x - 1)) > __x - 1;
}

static __always_inline bool
__hsb32_inline (uint32_t __x)
{
  return (__x ^ (__x - 1)) > __x - 1;
}

static __always_inline bool
__hsb16_inline (uint16_t __x)
{
  return (__x ^ (__x - 1)) > __x - 1;
}

static __always_inline bool
__hsb8_inline (uint8_t __x)
{
  return (__x ^ (__x - 1)) > __x - 1;
}

#define stdc_has_single_bit_uc(x) (__hsb8_inline (x))
#define stdc_has_single_bit_us(x) (__hsb16_inline (x))
#define stdc_has_single_bit_ui(x) (__hsb32_inline (x))
#if __WORDSIZE == 64
# define stdc_has_single_bit_ul(x) (__hsb64_inline (x))
#else
# define stdc_has_single_bit_ul(x) (__hsb32_inline (x))
#endif
#define stdc_has_single_bit_ull(x) (__hsb64_inline (x))

/* Bit width.  */
extern unsigned int stdc_bit_width_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned int stdc_bit_width_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_bit_width_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned int stdc_bit_width_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned int stdc_bit_width_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_bit_width)
# define stdc_bit_width(x) (__builtin_stdc_bit_width (x))
#else
# define stdc_bit_width(x) (stdc_bit_width_ull (x))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_clzll)
static __always_inline unsigned int
__bw64_inline (uint64_t __x)
{
  return 64 - __clz64_inline (__x);
}

static __always_inline unsigned int
__bw32_inline (uint32_t __x)
{
  return 32 - __clz32_inline (__x);
}

static __always_inline unsigned int
__bw16_inline (uint16_t __x)
{
  return 16 - __clz16_inline (__x);
}

static __always_inline unsigned int
__bw8_inline (uint8_t __x)
{
  return 8 - __clz8_inline (__x);
}

# define stdc_bit_width_uc(x) (__bw8_inline (x))
# define stdc_bit_width_us(x) (__bw16_inline (x))
# define stdc_bit_width_ui(x) (__bw32_inline (x))
# if __WORDSIZE == 64
#  define stdc_bit_width_ul(x) (__bw64_inline (x))
# else
#  define stdc_bit_width_ul(x) (__bw32_inline (x))
# endif
# define stdc_bit_width_ull(x) (__bw64_inline (x))
#endif

/* Bit floor.  */
extern unsigned char stdc_bit_floor_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned short stdc_bit_floor_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_bit_floor_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned long int stdc_bit_floor_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned long long int stdc_bit_floor_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_bit_floor)
# define stdc_bit_floor(x) (__builtin_stdc_bit_floor (x))
#else
# define stdc_bit_floor(x) ((__typeof (x)) stdc_bit_floor_ull (x))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_clzll)
static __always_inline uint64_t
__bf64_inline (uint64_t __x)
{
  return __x == 0 ? 0 : ((uint64_t) 1) << (__bw64_inline (__x) - 1);
}

static __always_inline uint32_t
__bf32_inline (uint32_t __x)
{
  return __x == 0 ? 0 : ((uint32_t) 1) << (__bw32_inline (__x) - 1);
}

static __always_inline uint16_t
__bf16_inline (uint16_t __x)
{
  return __pacify_uint16 (__x == 0
			  ? 0 : ((uint16_t) 1) << (__bw16_inline (__x) - 1));
}

static __always_inline uint8_t
__bf8_inline (uint8_t __x)
{
  return __pacify_uint8 (__x == 0
			 ? 0 : ((uint8_t) 1) << (__bw8_inline (__x) - 1));
}

# define stdc_bit_floor_uc(x) ((unsigned char) __bf8_inline (x))
# define stdc_bit_floor_us(x) ((unsigned short) __bf16_inline (x))
# define stdc_bit_floor_ui(x) ((unsigned int) __bf32_inline (x))
# if __WORDSIZE == 64
#  define stdc_bit_floor_ul(x) ((unsigned long int) __bf64_inline (x))
# else
#  define stdc_bit_floor_ul(x) ((unsigned long int) __bf32_inline (x))
# endif
# define stdc_bit_floor_ull(x) ((unsigned long long int) __bf64_inline (x))
#endif

/* Bit ceiling.  */
extern unsigned char stdc_bit_ceil_uc (unsigned char __x)
     __THROW __attribute_const__;
extern unsigned short stdc_bit_ceil_us (unsigned short __x)
     __THROW __attribute_const__;
extern unsigned int stdc_bit_ceil_ui (unsigned int __x)
     __THROW __attribute_const__;
extern unsigned long int stdc_bit_ceil_ul (unsigned long int __x)
     __THROW __attribute_const__;
__extension__
extern unsigned long long int stdc_bit_ceil_ull (unsigned long long int __x)
     __THROW __attribute_const__;
#if __glibc_has_builtin (__builtin_stdc_bit_ceil)
# define stdc_bit_ceil(x) (__builtin_stdc_bit_ceil (x))
#else
# define stdc_bit_ceil(x) ((__typeof (x)) stdc_bit_ceil_ull (x))
#endif

#if __GNUC_PREREQ (3, 4) || __glibc_has_builtin (__builtin_clzll)
static __always_inline uint64_t
__bc64_inline (uint64_t __x)
{
  return __x <= 1 ? 1 : ((uint64_t) 2) << (__bw64_inline (__x - 1) - 1);
}

static __always_inline uint32_t
__bc32_inline (uint32_t __x)
{
  return __x <= 1 ? 1 : ((uint32_t) 2) << (__bw32_inline (__x - 1) - 1);
}

static __always_inline uint16_t
__bc16_inline (uint16_t __x)
{
  return __pacify_uint16 (__x <= 1
			  ? 1
			  : ((uint16_t) 2)
			    << (__bw16_inline ((uint16_t) (__x - 1)) - 1));
}

static __always_inline uint8_t
__bc8_inline (uint8_t __x)
{
  return __pacify_uint8 (__x <= 1
			 ? 1
			 : ((uint8_t) 2)
			   << (__bw8_inline ((uint8_t) (__x - 1)) - 1));
}

# define stdc_bit_ceil_uc(x) ((unsigned char) __bc8_inline (x))
# define stdc_bit_ceil_us(x) ((unsigned short) __bc16_inline (x))
# define stdc_bit_ceil_ui(x) ((unsigned int) __bc32_inline (x))
# if __WORDSIZE == 64
#  define stdc_bit_ceil_ul(x) ((unsigned long int) __bc64_inline (x))
# else
#  define stdc_bit_ceil_ul(x) ((unsigned long int) __bc32_inline (x))
# endif
# define stdc_bit_ceil_ull(x) ((unsigned long long int) __bc64_inline (x))
#endif

__END_DECLS

#endif /* _STDBIT_H */