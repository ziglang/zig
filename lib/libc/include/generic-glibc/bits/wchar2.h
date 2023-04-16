/* Checking macros for wchar functions.
   Copyright (C) 2005-2023 Free Software Foundation, Inc.
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

#ifndef _WCHAR_H
# error "Never include <bits/wchar2.h> directly; use <wchar.h> instead."
#endif


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

__fortify_function wchar_t *
__NTH (wmemcpy (wchar_t *__restrict __s1, const wchar_t *__restrict __s2,
		size_t __n))
{
  return __glibc_fortify_n (wmemcpy, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s1),
			    __s1, __s2, __n);
}


extern wchar_t *__REDIRECT_NTH (__wmemmove_alias, (wchar_t *__s1,
						   const wchar_t *__s2,
						   size_t __n), wmemmove);
extern wchar_t *__REDIRECT_NTH (__wmemmove_chk_warn,
				(wchar_t *__s1, const wchar_t *__s2,
				 size_t __n, size_t __ns1), __wmemmove_chk)
     __warnattr ("wmemmove called with length bigger than size of destination "
		 "buffer");

__fortify_function wchar_t *
__NTH (wmemmove (wchar_t *__s1, const wchar_t *__s2, size_t __n))
{
  return __glibc_fortify_n (wmemmove, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s1),
			    __s1, __s2, __n);
}


#ifdef __USE_GNU
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

__fortify_function wchar_t *
__NTH (wmempcpy (wchar_t *__restrict __s1, const wchar_t *__restrict __s2,
		 size_t __n))
{
  return __glibc_fortify_n (wmempcpy, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s1),
			    __s1, __s2, __n);
}
#endif


extern wchar_t *__REDIRECT_NTH (__wmemset_alias, (wchar_t *__s, wchar_t __c,
						  size_t __n), wmemset);
extern wchar_t *__REDIRECT_NTH (__wmemset_chk_warn,
				(wchar_t *__s, wchar_t __c, size_t __n,
				 size_t __ns), __wmemset_chk)
     __warnattr ("wmemset called with length bigger than size of destination "
		 "buffer");

__fortify_function wchar_t *
__NTH (wmemset (wchar_t *__s, wchar_t __c, size_t __n))
{
  return __glibc_fortify_n (wmemset, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s),
			    __s, __c, __n);
}


extern wchar_t *__REDIRECT_NTH (__wcscpy_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src), wcscpy);

__fortify_function wchar_t *
__NTH (wcscpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcscpy_chk (__dest, __src, sz / sizeof (wchar_t));
  return __wcscpy_alias (__dest, __src);
}


extern wchar_t *__REDIRECT_NTH (__wcpcpy_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src), wcpcpy);

__fortify_function wchar_t *
__NTH (wcpcpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcpcpy_chk (__dest, __src, sz / sizeof (wchar_t));
  return __wcpcpy_alias (__dest, __src);
}


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

__fortify_function wchar_t *
__NTH (wcsncpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  return __glibc_fortify_n (wcsncpy, __n, sizeof (wchar_t),
			    __glibc_objsize (__dest),
			    __dest, __src, __n);
}


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

__fortify_function wchar_t *
__NTH (wcpncpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  return __glibc_fortify_n (wcpncpy, __n, sizeof (wchar_t),
			    __glibc_objsize (__dest),
			    __dest, __src, __n);
}


extern wchar_t *__REDIRECT_NTH (__wcscat_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src), wcscat);

__fortify_function wchar_t *
__NTH (wcscat (wchar_t *__restrict __dest, const wchar_t *__restrict __src))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcscat_chk (__dest, __src, sz / sizeof (wchar_t));
  return __wcscat_alias (__dest, __src);
}


extern wchar_t *__REDIRECT_NTH (__wcsncat_alias,
				(wchar_t *__restrict __dest,
				 const wchar_t *__restrict __src,
				 size_t __n), wcsncat);

__fortify_function wchar_t *
__NTH (wcsncat (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcsncat_chk (__dest, __src, __n, sz / sizeof (wchar_t));
  return __wcsncat_alias (__dest, __src, __n);
}



extern int __REDIRECT_NTH_LDBL (__swprintf_alias,
				(wchar_t *__restrict __s, size_t __n,
				 const wchar_t *__restrict __fmt, ...),
				swprintf);

#ifdef __va_arg_pack
__fortify_function int
__NTH (swprintf (wchar_t *__restrict __s, size_t __n,
		 const wchar_t *__restrict __fmt, ...))
{
  size_t sz = __glibc_objsize (__s);
  if (sz != (size_t) -1 || __USE_FORTIFY_LEVEL > 1)
    return __swprintf_chk (__s, __n, __USE_FORTIFY_LEVEL - 1,
			   sz / sizeof (wchar_t), __fmt, __va_arg_pack ());
  return __swprintf_alias (__s, __n, __fmt, __va_arg_pack ());
}
#elif !defined __cplusplus
/* XXX We might want to have support in gcc for swprintf.  */
# define swprintf(s, n, ...) \
  (__glibc_objsize (s) != (size_t) -1 || __USE_FORTIFY_LEVEL > 1		      \
   ? __swprintf_chk (s, n, __USE_FORTIFY_LEVEL - 1,			      \
		     __glibc_objsize (s) / sizeof (wchar_t), __VA_ARGS__)	      \
   : swprintf (s, n, __VA_ARGS__))
#endif


extern int __REDIRECT_NTH_LDBL (__vswprintf_alias,
				(wchar_t *__restrict __s, size_t __n,
				 const wchar_t *__restrict __fmt,
				 __gnuc_va_list __ap), vswprintf);

__fortify_function int
__NTH (vswprintf (wchar_t *__restrict __s, size_t __n,
		  const wchar_t *__restrict __fmt, __gnuc_va_list __ap))
{
  size_t sz = __glibc_objsize (__s);
  if (sz != (size_t) -1 || __USE_FORTIFY_LEVEL > 1)
    return __vswprintf_chk (__s, __n,  __USE_FORTIFY_LEVEL - 1,
			    sz / sizeof (wchar_t), __fmt, __ap);
  return __vswprintf_alias (__s, __n, __fmt, __ap);
}


#if __USE_FORTIFY_LEVEL > 1

# ifdef __va_arg_pack
__fortify_function int
wprintf (const wchar_t *__restrict __fmt, ...)
{
  return __wprintf_chk (__USE_FORTIFY_LEVEL - 1, __fmt, __va_arg_pack ());
}

__fortify_function int
fwprintf (__FILE *__restrict __stream, const wchar_t *__restrict __fmt, ...)
{
  return __fwprintf_chk (__stream, __USE_FORTIFY_LEVEL - 1, __fmt,
			 __va_arg_pack ());
}
# elif !defined __cplusplus
#  define wprintf(...) \
  __wprintf_chk (__USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
#  define fwprintf(stream, ...) \
  __fwprintf_chk (stream, __USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
# endif

__fortify_function int
vwprintf (const wchar_t *__restrict __fmt, __gnuc_va_list __ap)
{
  return __vwprintf_chk (__USE_FORTIFY_LEVEL - 1, __fmt, __ap);
}

__fortify_function int
vfwprintf (__FILE *__restrict __stream,
	   const wchar_t *__restrict __fmt, __gnuc_va_list __ap)
{
  return __vfwprintf_chk (__stream, __USE_FORTIFY_LEVEL - 1, __fmt, __ap);
}

#endif

extern wchar_t *__REDIRECT (__fgetws_alias,
			    (wchar_t *__restrict __s, int __n,
			     __FILE *__restrict __stream), fgetws) __wur;
extern wchar_t *__REDIRECT (__fgetws_chk_warn,
			    (wchar_t *__restrict __s, size_t __size, int __n,
			     __FILE *__restrict __stream), __fgetws_chk)
     __wur __warnattr ("fgetws called with bigger size than length "
		       "of destination buffer");

__fortify_function __wur wchar_t *
fgetws (wchar_t *__restrict __s, int __n, __FILE *__restrict __stream)
{
  size_t sz = __glibc_objsize (__s);
  if (__glibc_safe_or_unknown_len (__n, sizeof (wchar_t), sz))
    return __fgetws_alias (__s, __n, __stream);
  if (__glibc_unsafe_len (__n, sizeof (wchar_t), sz))
    return __fgetws_chk_warn (__s, sz / sizeof (wchar_t), __n, __stream);
  return __fgetws_chk (__s, sz / sizeof (wchar_t), __n, __stream);
}

#ifdef __USE_GNU
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

__fortify_function __wur wchar_t *
fgetws_unlocked (wchar_t *__restrict __s, int __n, __FILE *__restrict __stream)
{
  size_t sz = __glibc_objsize (__s);
  if (__glibc_safe_or_unknown_len (__n, sizeof (wchar_t), sz))
    return __fgetws_unlocked_alias (__s, __n, __stream);
  if (__glibc_unsafe_len (__n, sizeof (wchar_t), sz))
    return __fgetws_unlocked_chk_warn (__s, sz / sizeof (wchar_t), __n,
				       __stream);
  return __fgetws_unlocked_chk (__s, sz / sizeof (wchar_t), __n, __stream);
}
#endif


extern size_t __REDIRECT_NTH (__wcrtomb_alias,
			      (char *__restrict __s, wchar_t __wchar,
			       mbstate_t *__restrict __ps), wcrtomb) __wur;

__fortify_function __wur size_t
__NTH (wcrtomb (char *__restrict __s, wchar_t __wchar,
		mbstate_t *__restrict __ps))
{
  /* We would have to include <limits.h> to get a definition of MB_LEN_MAX.
     But this would only disturb the namespace.  So we define our own
     version here.  */
#define __WCHAR_MB_LEN_MAX	16
#if defined MB_LEN_MAX && MB_LEN_MAX != __WCHAR_MB_LEN_MAX
# error "Assumed value of MB_LEN_MAX wrong"
#endif
  if (__glibc_objsize (__s) != (size_t) -1
      && __WCHAR_MB_LEN_MAX > __glibc_objsize (__s))
    return __wcrtomb_chk (__s, __wchar, __ps, __glibc_objsize (__s));
  return __wcrtomb_alias (__s, __wchar, __ps);
}


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

__fortify_function size_t
__NTH (mbsrtowcs (wchar_t *__restrict __dst, const char **__restrict __src,
		  size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify_n (mbsrtowcs, __len, sizeof (wchar_t),
			    __glibc_objsize (__dst),
			    __dst, __src, __len, __ps);
}


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

__fortify_function size_t
__NTH (wcsrtombs (char *__restrict __dst, const wchar_t **__restrict __src,
		  size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify (wcsrtombs, __len, sizeof (char),
			  __glibc_objsize (__dst),
			  __dst, __src, __len, __ps);
}


#ifdef	__USE_XOPEN2K8
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

__fortify_function size_t
__NTH (mbsnrtowcs (wchar_t *__restrict __dst, const char **__restrict __src,
		   size_t __nmc, size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify_n (mbsnrtowcs, __len, sizeof (wchar_t),
			    __glibc_objsize (__dst),
			    __dst, __src, __nmc, __len, __ps);
}


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

__fortify_function size_t
__NTH (wcsnrtombs (char *__restrict __dst, const wchar_t **__restrict __src,
		   size_t __nwc, size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify (wcsnrtombs, __len, sizeof (char),
			  __glibc_objsize (__dst),
			  __dst, __src, __nwc, __len, __ps);
}
#endif