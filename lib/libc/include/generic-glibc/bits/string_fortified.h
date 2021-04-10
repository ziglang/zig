/* Copyright (C) 2004-2021 Free Software Foundation, Inc.
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

#ifndef _BITS_STRING_FORTIFIED_H
#define _BITS_STRING_FORTIFIED_H 1

#ifndef _STRING_H
# error "Never use <bits/string_fortified.h> directly; include <string.h> instead."
#endif

__fortify_function void *
__NTH (memcpy (void *__restrict __dest, const void *__restrict __src,
	       size_t __len))
{
  return __builtin___memcpy_chk (__dest, __src, __len,
				 __glibc_objsize0 (__dest));
}

__fortify_function void *
__NTH (memmove (void *__dest, const void *__src, size_t __len))
{
  return __builtin___memmove_chk (__dest, __src, __len,
				  __glibc_objsize0 (__dest));
}

#ifdef __USE_GNU
__fortify_function void *
__NTH (mempcpy (void *__restrict __dest, const void *__restrict __src,
		size_t __len))
{
  return __builtin___mempcpy_chk (__dest, __src, __len,
				  __glibc_objsize0 (__dest));
}
#endif


/* The first two tests here help to catch a somewhat common problem
   where the second and third parameter are transposed.  This is
   especially problematic if the intended fill value is zero.  In this
   case no work is done at all.  We detect these problems by referring
   non-existing functions.  */
__fortify_function void *
__NTH (memset (void *__dest, int __ch, size_t __len))
{
  return __builtin___memset_chk (__dest, __ch, __len,
				 __glibc_objsize0 (__dest));
}

#ifdef __USE_MISC
# include <bits/strings_fortified.h>

void __explicit_bzero_chk (void *__dest, size_t __len, size_t __destlen)
  __THROW __nonnull ((1)) __attr_access ((__write_only__, 1, 2));

__fortify_function void
__NTH (explicit_bzero (void *__dest, size_t __len))
{
  __explicit_bzero_chk (__dest, __len, __glibc_objsize0 (__dest));
}
#endif

__fortify_function char *
__NTH (strcpy (char *__restrict __dest, const char *__restrict __src))
{
  return __builtin___strcpy_chk (__dest, __src, __glibc_objsize (__dest));
}

#ifdef __USE_GNU
__fortify_function char *
__NTH (stpcpy (char *__restrict __dest, const char *__restrict __src))
{
  return __builtin___stpcpy_chk (__dest, __src, __glibc_objsize (__dest));
}
#endif


__fortify_function char *
__NTH (strncpy (char *__restrict __dest, const char *__restrict __src,
		size_t __len))
{
  return __builtin___strncpy_chk (__dest, __src, __len,
				  __glibc_objsize (__dest));
}

#if __GNUC_PREREQ (4, 7) || __glibc_clang_prereq (2, 6)
__fortify_function char *
__NTH (stpncpy (char *__dest, const char *__src, size_t __n))
{
  return __builtin___stpncpy_chk (__dest, __src, __n,
				  __glibc_objsize (__dest));
}
#else
extern char *__stpncpy_chk (char *__dest, const char *__src, size_t __n,
			    size_t __destlen) __THROW
  __attr_access ((__write_only__, 1, 3)) __attr_access ((__read_only__, 2));
extern char *__REDIRECT_NTH (__stpncpy_alias, (char *__dest, const char *__src,
					       size_t __n), stpncpy);

__fortify_function char *
__NTH (stpncpy (char *__dest, const char *__src, size_t __n))
{
  if (__bos (__dest) != (size_t) -1
      && (!__builtin_constant_p (__n) || __n > __bos (__dest)))
    return __stpncpy_chk (__dest, __src, __n, __bos (__dest));
  return __stpncpy_alias (__dest, __src, __n);
}
#endif


__fortify_function char *
__NTH (strcat (char *__restrict __dest, const char *__restrict __src))
{
  return __builtin___strcat_chk (__dest, __src, __glibc_objsize (__dest));
}


__fortify_function char *
__NTH (strncat (char *__restrict __dest, const char *__restrict __src,
		size_t __len))
{
  return __builtin___strncat_chk (__dest, __src, __len,
				  __glibc_objsize (__dest));
}

#endif /* bits/string_fortified.h */