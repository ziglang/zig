/* Checking macros for stdlib functions.
   Copyright (C) 2005-2025 Free Software Foundation, Inc.
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

#ifndef _STDLIB_H
# error "Never include <bits/stdlib.h> directly; use <stdlib.h> instead."
#endif

extern char *__realpath_chk (const char *__restrict __name,
			     char *__restrict __resolved,
			     size_t __resolvedlen) __THROW __wur;
extern char *__REDIRECT_NTH (__realpath_alias,
			     (const char *__restrict __name,
			      char *__restrict __resolved), realpath) __wur;
extern char *__REDIRECT_NTH (__realpath_chk_warn,
			     (const char *__restrict __name,
			      char *__restrict __resolved,
			      size_t __resolvedlen), __realpath_chk) __wur
     __warnattr ("second argument of realpath must be either NULL or at "
		 "least PATH_MAX bytes long buffer");

__fortify_function __attribute_overloadable__ __wur char *
__NTH (realpath (const char *__restrict __name,
		 __fortify_clang_overload_arg (char *, __restrict, __resolved)))
#if defined _LIBC_LIMITS_H_ && defined PATH_MAX
     __fortify_clang_warning_only_if_bos_lt (PATH_MAX, __resolved,
					     "second argument of realpath must be "
					     "either NULL or at least PATH_MAX "
					     "bytes long buffer")
#endif
{
  size_t __sz = __glibc_objsize (__resolved);

  if (__sz == (size_t) -1)
    return __realpath_alias (__name, __resolved);

#if !__fortify_use_clang && defined _LIBC_LIMITS_H_ && defined PATH_MAX
  if (__glibc_unsafe_len (PATH_MAX, sizeof (char), __sz))
    return __realpath_chk_warn (__name, __resolved, __sz);
#endif
  return __realpath_chk (__name, __resolved, __sz);
}


extern int __ptsname_r_chk (int __fd, char *__buf, size_t __buflen,
			    size_t __nreal) __THROW __nonnull ((2))
    __attr_access ((__write_only__, 2, 3));
extern int __REDIRECT_NTH (__ptsname_r_alias, (int __fd, char *__buf,
					       size_t __buflen), ptsname_r)
     __nonnull ((2)) __attr_access ((__write_only__, 2, 3));
extern int __REDIRECT_NTH (__ptsname_r_chk_warn,
			   (int __fd, char *__buf, size_t __buflen,
			    size_t __nreal), __ptsname_r_chk)
     __nonnull ((2)) __warnattr ("ptsname_r called with buflen bigger than "
				 "size of buf");

__fortify_function __attribute_overloadable__ int
__NTH (ptsname_r (int __fd,
		 __fortify_clang_overload_arg (char *, ,__buf),
		 size_t __buflen))
     __fortify_clang_warning_only_if_bos_lt (__buflen, __buf,
					     "ptsname_r called with buflen "
					     "bigger than size of buf")
{
  return __glibc_fortify (ptsname_r, __buflen, sizeof (char),
			  __glibc_objsize (__buf),
			  __fd, __buf, __buflen);
}


extern int __wctomb_chk (char *__s, wchar_t __wchar, size_t __buflen)
  __THROW __wur;
extern int __REDIRECT_NTH (__wctomb_alias, (char *__s, wchar_t __wchar),
			   wctomb) __wur;

__fortify_function __attribute_overloadable__ __wur int
__NTH (wctomb (__fortify_clang_overload_arg (char *, ,__s), wchar_t __wchar))
{
  /* We would have to include <limits.h> to get a definition of MB_LEN_MAX.
     But this would only disturb the namespace.  So we define our own
     version here.  */
#define __STDLIB_MB_LEN_MAX	16
#if defined MB_LEN_MAX && MB_LEN_MAX != __STDLIB_MB_LEN_MAX
# error "Assumed value of MB_LEN_MAX wrong"
#endif
  if (__glibc_objsize (__s) != (size_t) -1
      && __STDLIB_MB_LEN_MAX > __glibc_objsize (__s))
    return __wctomb_chk (__s, __wchar, __glibc_objsize (__s));
  return __wctomb_alias (__s, __wchar);
}


extern size_t __mbstowcs_chk (wchar_t *__restrict __dst,
			      const char *__restrict __src,
			      size_t __len, size_t __dstlen) __THROW
    __attr_access ((__write_only__, 1, 3)) __attr_access ((__read_only__, 2));
extern size_t __REDIRECT_NTH (__mbstowcs_nulldst,
			      (wchar_t *__restrict __dst,
			       const char *__restrict __src,
			       size_t __len), mbstowcs)
    __attr_access ((__read_only__, 2));
extern size_t __REDIRECT_NTH (__mbstowcs_alias,
			      (wchar_t *__restrict __dst,
			       const char *__restrict __src,
			       size_t __len), mbstowcs)
    __attr_access ((__write_only__, 1, 3)) __attr_access ((__read_only__, 2));
extern size_t __REDIRECT_NTH (__mbstowcs_chk_warn,
			      (wchar_t *__restrict __dst,
			       const char *__restrict __src,
			       size_t __len, size_t __dstlen), __mbstowcs_chk)
     __warnattr ("mbstowcs called with dst buffer smaller than len "
		 "* sizeof (wchar_t)");

__fortify_function __attribute_overloadable__ size_t
__NTH (mbstowcs (__fortify_clang_overload_arg (wchar_t *, __restrict, __dst),
		 const char *__restrict __src,
		 size_t __len))
     __fortify_clang_warning_only_if_bos0_lt2 (__len, __dst, sizeof (wchar_t),
					       "mbstowcs called with dst buffer "
					       "smaller than len * sizeof (wchar_t)")
{
  if (__builtin_constant_p (__dst == NULL) && __dst == NULL)
    return __mbstowcs_nulldst (__dst, __src, __len);
  else
    return __glibc_fortify_n (mbstowcs, __len, sizeof (wchar_t),
			      __glibc_objsize (__dst), __dst, __src, __len);
}

extern size_t __wcstombs_chk (char *__restrict __dst,
			      const wchar_t *__restrict __src,
			      size_t __len, size_t __dstlen) __THROW
  __attr_access ((__write_only__, 1, 3)) __attr_access ((__read_only__, 2));
extern size_t __REDIRECT_NTH (__wcstombs_alias,
			      (char *__restrict __dst,
			       const wchar_t *__restrict __src,
			       size_t __len), wcstombs)
  __attr_access ((__write_only__, 1, 3)) __attr_access ((__read_only__, 2));
extern size_t __REDIRECT_NTH (__wcstombs_chk_warn,
			      (char *__restrict __dst,
			       const wchar_t *__restrict __src,
			       size_t __len, size_t __dstlen), __wcstombs_chk)
     __warnattr ("wcstombs called with dst buffer smaller than len");

__fortify_function __attribute_overloadable__ size_t
__NTH (wcstombs (__fortify_clang_overload_arg (char *, __restrict, __dst),
		 const wchar_t *__restrict __src,
		 size_t __len))
{
  return __glibc_fortify (wcstombs, __len, sizeof (char),
			  __glibc_objsize (__dst),
			  __dst, __src, __len);
}