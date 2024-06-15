/* Copyright (C) 2011-2024 Free Software Foundation, Inc.
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

/*
 *      ISO C11 Standard: 7.28
 *	Unicode utilities	<uchar.h>
 */

#ifndef _UCHAR_H
#define _UCHAR_H	1

#include <features.h>

#define __need_size_t
#include <stddef.h>

#include <bits/types.h>
#include <bits/types/mbstate_t.h>

/* Declare the C2x char8_t typedef in C2x modes, but only if the C++
  __cpp_char8_t feature test macro is not defined.  */
#if __GLIBC_USE (ISOC2X) && !defined __cpp_char8_t
#if __GNUC_PREREQ (10, 0) && defined __cplusplus
/* Suppress the diagnostic regarding char8_t being a keyword in C++20.  */
# pragma GCC diagnostic push
# pragma GCC diagnostic ignored "-Wc++20-compat"
#endif
/* Define the 8-bit character type.  */
typedef unsigned char char8_t;
#if __GNUC_PREREQ (10, 0) && defined __cplusplus
# pragma GCC diagnostic pop
#endif
#endif

#ifndef __USE_ISOCXX11
/* Define the 16-bit and 32-bit character types.  */
typedef __uint_least16_t char16_t;
typedef __uint_least32_t char32_t;
#endif


__BEGIN_DECLS

/* Declare the C2x mbrtoc8() and c8rtomb() functions in C2x modes or if
   the C++ __cpp_char8_t feature test macro is defined.  */
#if __GLIBC_USE (ISOC2X) || defined __cpp_char8_t
/* Write char8_t representation of multibyte character pointed
   to by S to PC8.  */
extern size_t mbrtoc8  (char8_t *__restrict __pc8,
			const char *__restrict __s, size_t __n,
			mbstate_t *__restrict __p) __THROW;

/* Write multibyte representation of char8_t C8 to S.  */
extern size_t c8rtomb  (char *__restrict __s, char8_t __c8,
			mbstate_t *__restrict __ps) __THROW;
#endif

/* Write char16_t representation of multibyte character pointed
   to by S to PC16.  */
extern size_t mbrtoc16 (char16_t *__restrict __pc16,
			const char *__restrict __s, size_t __n,
			mbstate_t *__restrict __p) __THROW;

/* Write multibyte representation of char16_t C16 to S.  */
extern size_t c16rtomb (char *__restrict __s, char16_t __c16,
			mbstate_t *__restrict __ps) __THROW;



/* Write char32_t representation of multibyte character pointed
   to by S to PC32.  */
extern size_t mbrtoc32 (char32_t *__restrict __pc32,
			const char *__restrict __s, size_t __n,
			mbstate_t *__restrict __p) __THROW;

/* Write multibyte representation of char32_t C32 to S.  */
extern size_t c32rtomb (char *__restrict __s, char32_t __c32,
			mbstate_t *__restrict __ps) __THROW;

__END_DECLS

#endif	/* uchar.h */