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
extern wchar_t *__REDIRECT_NTH (__wmemcpy_alias,
				(wchar_t *__restrict __s1,
				 const wchar_t *__restrict __s2, size_t __n),
				wmemcpy);
extern wchar_t *__REDIRECT_NTH (__wmemcpy_chk_warn,
				(wchar_t *__restrict __s1,
				 const wchar_t *__restrict __s2, size_t __n,
				 size_t __ns1), __wmemcpy_chk)
     __warnattr ("wmemcpy called with length bigger than size of destination "
		 "buffer");

extern wchar_t *__wmemmove_chk (wchar_t *__s1, const wchar_t *__s2,
				size_t __n, size_t __ns1) __THROW;
extern wchar_t *__REDIRECT_NTH (__wmemmove_alias, (wchar_t *__s1,
						   const wchar_t *__s2,
						   size_t __n), wmemmove);
extern wchar_t *__REDIRECT_NTH (__wmemmove_chk_warn,
				(wchar_t *__s1, const wchar_t *__s2,
				 size_t __n, size_t __ns1), __wmemmove_chk)
     __warnattr ("wmemmove called with length bigger than size of destination "
		 "buffer");


#ifdef __USE_GNU

extern wchar_t *__wmempcpy_chk (wchar_t *__restrict __s1,
				const wchar_t *__restrict __s2, size_t __n,
				size_t __ns1) __THROW;
extern wchar_t *__REDIRECT_NTH (__wmempcpy_alias,
				(wchar_t *__restrict __s1,
				 const wchar_t *__restrict __s2,
				 size_t __n), wmempcpy);
extern wchar_t *__REDIRECT_NTH (__wmempcpy_chk_warn,
				(wchar_t *__restrict __s1,
				 const wchar_t *__restrict __s2, size_t __n,
				 size_t __ns1), __wmempcpy_chk)
     __warnattr ("wmempcpy called with length bigger than size of destination "
		 "buffer");

#endif


extern wchar_t *__wmemset_chk (wchar_t *__s, wchar_t __c, size_t __n,
			       size_t __ns) __THROW;
extern wchar_t *__REDIRECT_FORTIFY_NTH (__wmemset_alias, (wchar_t *__s, wchar_t __c,
							  size_t __n), wmemset);
extern wchar_t *__REDIRECT_NTH (__wmemset_chk_warn,
				(wchar_t *__s, wchar_t __c, size_t __n,
				 size_t __ns), __wmemset_chk)
     __warnattr ("wmemset called with length bigger than size of destination "
		 "buffer");

extern wchar_t *__wcscpy_chk (wchar_t *__restrict __dest,
			      const wchar_t *__restrict __src,
			      size_t __n) __THROW;
extern wchar_t *__REDIRECT_NTH (__wcscpy_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src), wcscpy);

extern wchar_t *__wcpcpy_chk (wchar_t *__restrict __dest,
			      const wchar_t *__restrict __src,
			      size_t __destlen) __THROW;
extern wchar_t *__REDIRECT_NTH (__wcpcpy_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src), wcpcpy);

extern wchar_t *__wcsncpy_chk (wchar_t *__restrict __dest,
			       const wchar_t *__restrict __src, size_t __n,
			       size_t __destlen) __THROW;
extern wchar_t *__REDIRECT_NTH (__wcsncpy_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src,
				 size_t __n), wcsncpy);
extern wchar_t *__REDIRECT_NTH (__wcsncpy_chk_warn,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src,
				 size_t __n, size_t __destlen), __wcsncpy_chk)
     __warnattr ("wcsncpy called with length bigger than size of destination "
		 "buffer");

extern wchar_t *__wcpncpy_chk (wchar_t *__restrict __dest,
			       const wchar_t *__restrict __src, size_t __n,
			       size_t __destlen) __THROW;

extern wchar_t *__REDIRECT_NTH (__wcpncpy_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src,
				 size_t __n), wcpncpy);
extern wchar_t *__REDIRECT_NTH (__wcpncpy_chk_warn,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src,
				 size_t __n, size_t __destlen), __wcpncpy_chk)
     __warnattr ("wcpncpy called with length bigger than size of destination "
		 "buffer");

extern wchar_t *__wcscat_chk (wchar_t *__restrict __dest,
			      const wchar_t *__restrict __src,
			      size_t __destlen) __THROW;
extern wchar_t *__REDIRECT_NTH (__wcscat_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src), wcscat);

extern wchar_t *__wcsncat_chk (wchar_t *__restrict __dest,
			       const wchar_t *__restrict __src,
			       size_t __n, size_t __destlen) __THROW;
extern wchar_t *__REDIRECT_NTH (__wcsncat_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src,
				 size_t __n), wcsncat);

extern int __swprintf_chk (wchar_t *__restrict __s, size_t __n,
			   int __flag, size_t __s_len,
			   const wchar_t *__restrict __format, ...)
     __THROW /* __attribute__ ((__format__ (__wprintf__, 5, 6))) */;
extern int __REDIRECT_NTH_LDBL (__swprintf_alias,
				(wchar_t *__restrict __s, size_t __n,
				 const wchar_t *__restrict __fmt, ...),
				swprintf);

extern int __vswprintf_chk (wchar_t *__restrict __s, size_t __n,
			    int __flag, size_t __s_len,
			    const wchar_t *__restrict __format,
			    __gnuc_va_list __arg)
     __THROW /* __attribute__ ((__format__ (__wprintf__, 5, 0))) */;
extern int __REDIRECT_NTH_LDBL (__vswprintf_alias,
				(wchar_t *__restrict __s, size_t __n,
				 const wchar_t *__restrict __fmt,
				 __gnuc_va_list __ap), vswprintf);


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
extern wchar_t *__REDIRECT (__fgetws_alias,
			    (wchar_t *__restrict __s, int __n,
			     __FILE *__restrict __stream), fgetws) __wur;
extern wchar_t *__REDIRECT (__fgetws_chk_warn,
			    (wchar_t *__restrict __s, size_t __size, int __n,
			     __FILE *__restrict __stream), __fgetws_chk)
     __wur __warnattr ("fgetws called with bigger size than length "
		       "of destination buffer");

#ifdef __USE_GNU

extern wchar_t *__fgetws_unlocked_chk (wchar_t *__restrict __s, size_t __size,
				       int __n, __FILE *__restrict __stream)
       __wur;
extern wchar_t *__REDIRECT (__fgetws_unlocked_alias,
			    (wchar_t *__restrict __s, int __n,
			     __FILE *__restrict __stream), fgetws_unlocked)
  __wur;
extern wchar_t *__REDIRECT (__fgetws_unlocked_chk_warn,
			    (wchar_t *__restrict __s, size_t __size, int __n,
			     __FILE *__restrict __stream),
			    __fgetws_unlocked_chk)
     __wur __warnattr ("fgetws_unlocked called with bigger size than length "
		       "of destination buffer");

#endif

extern size_t __wcrtomb_chk (char *__restrict __s, wchar_t __wchar,
			     mbstate_t *__restrict __p,
			     size_t __buflen) __THROW __wur;
extern size_t __REDIRECT_FORTIFY_NTH (__wcrtomb_alias,
				      (char *__restrict __s, wchar_t __wchar,
				      mbstate_t *__restrict __ps), wcrtomb) __wur;

extern size_t __mbsrtowcs_chk (wchar_t *__restrict __dst,
			       const char **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps,
			       size_t __dstlen) __THROW;
extern size_t __REDIRECT_NTH (__mbsrtowcs_alias,
			      (wchar_t *__restrict __dst,
			       const char **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps),
			      mbsrtowcs);
extern size_t __REDIRECT_NTH (__mbsrtowcs_chk_warn,
			      (wchar_t *__restrict __dst,
			       const char **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps,
			       size_t __dstlen), __mbsrtowcs_chk)
     __warnattr ("mbsrtowcs called with dst buffer smaller than len "
		 "* sizeof (wchar_t)");

extern size_t __wcsrtombs_chk (char *__restrict __dst,
			       const wchar_t **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps,
			       size_t __dstlen) __THROW;
extern size_t __REDIRECT_NTH (__wcsrtombs_alias,
			      (char *__restrict __dst,
			       const wchar_t **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps),
			      wcsrtombs);
extern size_t __REDIRECT_NTH (__wcsrtombs_chk_warn,
			      (char *__restrict __dst,
			       const wchar_t **__restrict __src,
			       size_t __len, mbstate_t *__restrict __ps,
			       size_t __dstlen), __wcsrtombs_chk)
    __warnattr ("wcsrtombs called with dst buffer smaller than len");

#ifdef	__USE_XOPEN2K8

extern size_t __mbsnrtowcs_chk (wchar_t *__restrict __dst,
				const char **__restrict __src, size_t __nmc,
				size_t __len, mbstate_t *__restrict __ps,
				size_t __dstlen) __THROW;
extern size_t __REDIRECT_NTH (__mbsnrtowcs_alias,
			      (wchar_t *__restrict __dst,
			       const char **__restrict __src, size_t __nmc,
			       size_t __len, mbstate_t *__restrict __ps),
			      mbsnrtowcs);
extern size_t __REDIRECT_NTH (__mbsnrtowcs_chk_warn,
			      (wchar_t *__restrict __dst,
			       const char **__restrict __src, size_t __nmc,
			       size_t __len, mbstate_t *__restrict __ps,
			       size_t __dstlen), __mbsnrtowcs_chk)
     __warnattr ("mbsnrtowcs called with dst buffer smaller than len "
		 "* sizeof (wchar_t)");

extern size_t __wcsnrtombs_chk (char *__restrict __dst,
				const wchar_t **__restrict __src,
				size_t __nwc, size_t __len,
				mbstate_t *__restrict __ps, size_t __dstlen)
       __THROW;
extern size_t __REDIRECT_NTH (__wcsnrtombs_alias,
			      (char *__restrict __dst,
			       const wchar_t **__restrict __src,
			       size_t __nwc, size_t __len,
			       mbstate_t *__restrict __ps), wcsnrtombs);
extern size_t __REDIRECT_NTH (__wcsnrtombs_chk_warn,
			      (char *__restrict __dst,
			       const wchar_t **__restrict __src,
			       size_t __nwc, size_t __len,
			       mbstate_t *__restrict __ps,
			       size_t __dstlen), __wcsnrtombs_chk)
     __warnattr ("wcsnrtombs called with dst buffer smaller than len");

#endif

#ifdef __USE_MISC
extern size_t __wcslcpy_chk (wchar_t *__dest, const wchar_t *__src, size_t __n,
			     size_t __destlen) __THROW;
extern size_t __REDIRECT_NTH (__wcslcpy_alias,
			      (wchar_t *__dest, const wchar_t *__src,
			       size_t __n), wcslcpy);

extern size_t __wcslcat_chk (wchar_t *__dest, const wchar_t *__src, size_t __n,
			     size_t __destlen) __THROW;
extern size_t __REDIRECT_NTH (__wcslcat_alias,
			      (wchar_t *__dest, const wchar_t *__src,
			       size_t __n), wcslcat);
#endif /* __USE_MISC */

#endif /* bits/wchar2-decl.h.  */