/* Checking macros for wchar functions.  Declarations only.
   Copyright (C) 2004-2023 Free Software Foundation, Inc.
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

#ifndef _BITS_WCHAR2_DECL_H
#define _BITS_WCHAR2_DECL_H 1

#ifndef _WCHAR_H
# error "Never include <bits/wchar2-decl.h> directly; use <wchar.h> instead."
#endif


extern wchar_t *__wmemcpy_chk (wchar_t *__restrict __s1,
			       const wchar_t *__restrict __s2, size_t __n,
			       size_t __ns1) __THROW;
extern wchar_t *__wmemmove_chk (wchar_t *__s1, const wchar_t *__s2,
				size_t __n, size_t __ns1) __THROW;


#ifdef __USE_GNU

extern wchar_t *__wmempcpy_chk (wchar_t *__restrict __s1,
				const wchar_t *__restrict __s2, size_t __n,
				size_t __ns1) __THROW;

#endif


extern wchar_t *__wmemset_chk (wchar_t *__s, wchar_t __c, size_t __n,
			       size_t __ns) __THROW;
extern wchar_t *__wcscpy_chk (wchar_t *__restrict __dest,
			      const wchar_t *__restrict __src,
			      size_t __n) __THROW;
extern wchar_t *__wcpcpy_chk (wchar_t *__restrict __dest,
			      const wchar_t *__restrict __src,
			      size_t __destlen) __THROW;
extern wchar_t *__wcsncpy_chk (wchar_t *__restrict __dest,
			       const wchar_t *__restrict __src, size_t __n,
			       size_t __destlen) __THROW;
extern wchar_t *__wcpncpy_chk (wchar_t *__restrict __dest,
			       const wchar_t *__restrict __src, size_t __n,
			       size_t __destlen) __THROW;
extern wchar_t *__wcscat_chk (wchar_t *__restrict __dest,
			      const wchar_t *__restrict __src,
			      size_t __destlen) __THROW;
extern wchar_t *__wcsncat_chk (wchar_t *__restrict __dest,
			       const wchar_t *__restrict __src,
			       size_t __n, size_t __destlen) __THROW;
extern int __swprintf_chk (wchar_t *__restrict __s, size_t __n,
			   int __flag, size_t __s_len,
			   const wchar_t *__restrict __format, ...)
     __THROW /* __attribute__ ((__format__ (__wprintf__, 5, 6))) */;
extern int __vswprintf_chk (wchar_t *__restrict __s, size_t __n,
			    int __flag, size_t __s_len,
			    const wchar_t *__restrict __format,
			    __gnuc_va_list __arg)
     __THROW /* __attribute__ ((__format__ (__wprintf__, 5, 0))) */;

#if __USE_FORTIFY_LEVEL > 1

extern int __fwprintf_chk (__FILE *__restrict __stream, int __flag,
			   const wchar_t *__restrict __format, ...);
extern int __wprintf_chk (int __flag, const wchar_t *__restrict __format,
			  ...);
extern int __vfwprintf_chk (__FILE *__restrict __stream, int __flag,
			    const wchar_t *__restrict __format,
			    __gnuc_va_list __ap);
extern int __vwprintf_chk (int __flag, const wchar_t *__restrict __format,
			   __gnuc_va_list __ap);

#endif

extern wchar_t *__fgetws_chk (wchar_t *__restrict __s, size_t __size, int __n,
			      __FILE *__restrict __stream) __wur;

#ifdef __USE_GNU

extern wchar_t *__fgetws_unlocked_chk (wchar_t *__restrict __s, size_t __size,
				       int __n, __FILE *__restrict __stream)
       __wur;

#endif

extern size_t __wcrtomb_chk (char *__restrict __s, wchar_t __wchar,
			     mbstate_t *__restrict __p,
			     size_t __buflen) __THROW __wur;
extern size_t __mbsrtowcs_chk (wchar_t *__restrict __dst,
			       const char **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps,
			       size_t __dstlen) __THROW;
extern size_t __wcsrtombs_chk (char *__restrict __dst,
			       const wchar_t **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps,
			       size_t __dstlen) __THROW;

#ifdef	__USE_XOPEN2K8

extern size_t __mbsnrtowcs_chk (wchar_t *__restrict __dst,
				const char **__restrict __src, size_t __nmc,
				size_t __len, mbstate_t *__restrict __ps,
				size_t __dstlen) __THROW;
extern size_t __wcsnrtombs_chk (char *__restrict __dst,
				const wchar_t **__restrict __src,
				size_t __nwc, size_t __len,
				mbstate_t *__restrict __ps, size_t __dstlen)
       __THROW;

#endif

#endif /* bits/wchar2-decl.h.  */