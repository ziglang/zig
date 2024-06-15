/* Checking macros for wchar functions.
   Copyright (C) 2005-2024 Free Software Foundation, Inc.
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

__fortify_function wchar_t *
__NTH (wmemcpy (wchar_t *__restrict __s1, const wchar_t *__restrict __s2,
		size_t __n))
{
  return __glibc_fortify_n (wmemcpy, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s1),
			    __s1, __s2, __n);
}

__fortify_function wchar_t *
__NTH (wmemmove (wchar_t *__s1, const wchar_t *__s2, size_t __n))
{
  return __glibc_fortify_n (wmemmove, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s1),
			    __s1, __s2, __n);
}

#ifdef __USE_GNU
__fortify_function wchar_t *
__NTH (wmempcpy (wchar_t *__restrict __s1, const wchar_t *__restrict __s2,
		 size_t __n))
{
  return __glibc_fortify_n (wmempcpy, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s1),
			    __s1, __s2, __n);
}
#endif

__fortify_function wchar_t *
__NTH (wmemset (wchar_t *__s, wchar_t __c, size_t __n))
{
  return __glibc_fortify_n (wmemset, __n, sizeof (wchar_t),
			    __glibc_objsize0 (__s),
			    __s, __c, __n);
}

__fortify_function wchar_t *
__NTH (wcscpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcscpy_chk (__dest, __src, sz / sizeof (wchar_t));
  return __wcscpy_alias (__dest, __src);
}

__fortify_function wchar_t *
__NTH (wcpcpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcpcpy_chk (__dest, __src, sz / sizeof (wchar_t));
  return __wcpcpy_alias (__dest, __src);
}

__fortify_function wchar_t *
__NTH (wcsncpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  return __glibc_fortify_n (wcsncpy, __n, sizeof (wchar_t),
			    __glibc_objsize (__dest),
			    __dest, __src, __n);
}

__fortify_function wchar_t *
__NTH (wcpncpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  return __glibc_fortify_n (wcpncpy, __n, sizeof (wchar_t),
			    __glibc_objsize (__dest),
			    __dest, __src, __n);
}

__fortify_function wchar_t *
__NTH (wcscat (wchar_t *__restrict __dest, const wchar_t *__restrict __src))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcscat_chk (__dest, __src, sz / sizeof (wchar_t));
  return __wcscat_alias (__dest, __src);
}

__fortify_function wchar_t *
__NTH (wcsncat (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  size_t sz = __glibc_objsize (__dest);
  if (sz != (size_t) -1)
    return __wcsncat_chk (__dest, __src, __n, sz / sizeof (wchar_t));
  return __wcsncat_alias (__dest, __src, __n);
}

#ifdef __USE_MISC
__fortify_function size_t
__NTH (wcslcpy (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  if (__glibc_objsize (__dest) != (size_t) -1
      && (!__builtin_constant_p (__n
				 > __glibc_objsize (__dest) / sizeof (wchar_t))
	  || __n > __glibc_objsize (__dest) / sizeof (wchar_t)))
    return __wcslcpy_chk (__dest, __src, __n,
			  __glibc_objsize (__dest) / sizeof (wchar_t));
  return __wcslcpy_alias (__dest, __src, __n);
}

__fortify_function size_t
__NTH (wcslcat (wchar_t *__restrict __dest, const wchar_t *__restrict __src,
		size_t __n))
{
  if (__glibc_objsize (__dest) != (size_t) -1
      && (!__builtin_constant_p (__n > __glibc_objsize (__dest)
				 / sizeof (wchar_t))
	  || __n > __glibc_objsize (__dest) / sizeof (wchar_t)))
    return __wcslcat_chk (__dest, __src, __n,
			  __glibc_objsize (__dest) / sizeof (wchar_t));
  return __wcslcat_alias (__dest, __src, __n);
}
#endif /* __USE_MISC */

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

__fortify_function size_t
__NTH (mbsrtowcs (wchar_t *__restrict __dst, const char **__restrict __src,
		  size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify_n (mbsrtowcs, __len, sizeof (wchar_t),
			    __glibc_objsize (__dst),
			    __dst, __src, __len, __ps);
}

__fortify_function size_t
__NTH (wcsrtombs (char *__restrict __dst, const wchar_t **__restrict __src,
		  size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify (wcsrtombs, __len, sizeof (char),
			  __glibc_objsize (__dst),
			  __dst, __src, __len, __ps);
}


#ifdef	__USE_XOPEN2K8
__fortify_function size_t
__NTH (mbsnrtowcs (wchar_t *__restrict __dst, const char **__restrict __src,
		   size_t __nmc, size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify_n (mbsnrtowcs, __len, sizeof (wchar_t),
			    __glibc_objsize (__dst),
			    __dst, __src, __nmc, __len, __ps);
}

__fortify_function size_t
__NTH (wcsnrtombs (char *__restrict __dst, const wchar_t **__restrict __src,
		   size_t __nwc, size_t __len, mbstate_t *__restrict __ps))
{
  return __glibc_fortify (wcsnrtombs, __len, sizeof (char),
			  __glibc_objsize (__dst),
			  __dst, __src, __nwc, __len, __ps);
}
#endif