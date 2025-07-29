/* Checking macros for stdio functions. Declarations only.
   Copyright (C) 2004-2025 Free Software Foundation, Inc.
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

#ifndef _BITS_STDIO2_DEC_H
#define _BITS_STDIO2_DEC_H 1

#ifndef _STDIO_H
# error "Never include <bits/stdio2-decl.h> directly; use <stdio.h> instead."
#endif

extern int __sprintf_chk (char *__restrict __s, int __flag, size_t __slen,
			  const char *__restrict __format, ...) __THROW
    __attr_access ((__write_only__, 1, 3));
extern int __vsprintf_chk (char *__restrict __s, int __flag, size_t __slen,
			   const char *__restrict __format,
			   __gnuc_va_list __ap) __THROW
    __attr_access ((__write_only__, 1, 3));

#if defined __USE_ISOC99 || defined __USE_UNIX98

extern int __snprintf_chk (char *__restrict __s, size_t __n, int __flag,
			   size_t __slen, const char *__restrict __format,
			   ...) __THROW
    __attr_access ((__write_only__, 1, 2));
extern int __vsnprintf_chk (char *__restrict __s, size_t __n, int __flag,
			    size_t __slen, const char *__restrict __format,
			    __gnuc_va_list __ap) __THROW
    __attr_access ((__write_only__, 1, 2));

#endif

#if __USE_FORTIFY_LEVEL > 1

extern int __fprintf_chk (FILE *__restrict __stream, int __flag,
			  const char *__restrict __format, ...)
    __nonnull ((1));
extern int __printf_chk (int __flag, const char *__restrict __format, ...);
extern int __vfprintf_chk (FILE *__restrict __stream, int __flag,
			   const char *__restrict __format,
			   __gnuc_va_list __ap) __nonnull ((1));
extern int __vprintf_chk (int __flag, const char *__restrict __format,
			  __gnuc_va_list __ap);

# ifdef __USE_XOPEN2K8
extern int __dprintf_chk (int __fd, int __flag, const char *__restrict __fmt,
			  ...) __attribute__ ((__format__ (__printf__, 3, 4)));
extern int __vdprintf_chk (int __fd, int __flag,
			   const char *__restrict __fmt, __gnuc_va_list __arg)
     __attribute__ ((__format__ (__printf__, 3, 0)));
# endif

# ifdef __USE_GNU

extern int __asprintf_chk (char **__restrict __ptr, int __flag,
			   const char *__restrict __fmt, ...)
     __THROW __attribute__ ((__format__ (__printf__, 3, 4))) __wur;
extern int __vasprintf_chk (char **__restrict __ptr, int __flag,
			    const char *__restrict __fmt, __gnuc_va_list __arg)
     __THROW __attribute__ ((__format__ (__printf__, 3, 0))) __wur;
extern int __obstack_printf_chk (struct obstack *__restrict __obstack,
				 int __flag, const char *__restrict __format,
				 ...)
     __THROW __attribute__ ((__format__ (__printf__, 3, 4)));
extern int __obstack_vprintf_chk (struct obstack *__restrict __obstack,
				  int __flag,
				  const char *__restrict __format,
				  __gnuc_va_list __args)
     __THROW __attribute__ ((__format__ (__printf__, 3, 0)));

# endif
#endif

#if __GLIBC_USE (DEPRECATED_GETS)
extern char *__REDIRECT (__gets_warn, (char *__str), gets)
     __wur __warnattr ("please use fgets or getline instead, gets can't "
		       "specify buffer size");

extern char *__gets_chk (char *__str, size_t) __wur;
#endif

extern char *__REDIRECT (__fgets_alias,
			 (char *__restrict __s, int __n,
			  FILE *__restrict __stream), fgets)
    __wur __attr_access ((__write_only__, 1, 2));
extern char *__REDIRECT (__fgets_chk_warn,
			 (char *__restrict __s, size_t __size, int __n,
			  FILE *__restrict __stream), __fgets_chk)
     __wur __warnattr ("fgets called with bigger size than length "
		       "of destination buffer");

extern char *__fgets_chk (char *__restrict __s, size_t __size, int __n,
			  FILE *__restrict __stream)
    __wur __attr_access ((__write_only__, 1, 3)) __nonnull ((4));

extern size_t __REDIRECT (__fread_alias,
			  (void *__restrict __ptr, size_t __size,
			   size_t __n, FILE *__restrict __stream),
			  fread) __wur;
extern size_t __REDIRECT (__fread_chk_warn,
			  (void *__restrict __ptr, size_t __ptrlen,
			   size_t __size, size_t __n,
			   FILE *__restrict __stream),
			  __fread_chk)
     __wur __warnattr ("fread called with bigger size * nmemb than length "
		       "of destination buffer");

extern size_t __fread_chk (void *__restrict __ptr, size_t __ptrlen,
			   size_t __size, size_t __n,
			   FILE *__restrict __stream) __wur __nonnull ((5));

#ifdef __USE_GNU
extern char *__REDIRECT_FORTIFY (__fgets_unlocked_alias,
			 (char *__restrict __s, int __n,
			  FILE *__restrict __stream), fgets_unlocked)
    __wur __attr_access ((__write_only__, 1, 2));
extern char *__REDIRECT (__fgets_unlocked_chk_warn,
			 (char *__restrict __s, size_t __size, int __n,
			  FILE *__restrict __stream), __fgets_unlocked_chk)
     __wur __warnattr ("fgets_unlocked called with bigger size than length "
		       "of destination buffer");


extern char *__fgets_unlocked_chk (char *__restrict __s, size_t __size,
				   int __n, FILE *__restrict __stream)
    __wur __attr_access ((__write_only__, 1, 3)) __nonnull ((4));
#endif

#ifdef __USE_MISC
# undef fread_unlocked
extern size_t __REDIRECT (__fread_unlocked_alias,
			  (void *__restrict __ptr, size_t __size,
			   size_t __n, FILE *__restrict __stream),
			  fread_unlocked) __wur;
extern size_t __REDIRECT (__fread_unlocked_chk_warn,
			  (void *__restrict __ptr, size_t __ptrlen,
			   size_t __size, size_t __n,
			   FILE *__restrict __stream),
			  __fread_unlocked_chk)
     __wur __warnattr ("fread_unlocked called with bigger size * nmemb than "
		       "length of destination buffer");

extern size_t __fread_unlocked_chk (void *__restrict __ptr, size_t __ptrlen,
				    size_t __size, size_t __n,
				    FILE *__restrict __stream)
    __wur __nonnull ((5));
#endif

#endif /* bits/stdio2-decl.h.  */