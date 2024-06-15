/* Checking macros for stdio functions.
   Copyright (C) 2004-2024 Free Software Foundation, Inc.
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

#ifndef _BITS_STDIO2_H
#define _BITS_STDIO2_H 1

#ifndef _STDIO_H
# error "Never include <bits/stdio2.h> directly; use <stdio.h> instead."
#endif

#ifdef __va_arg_pack
__fortify_function int
__NTH (sprintf (char *__restrict __s, const char *__restrict __fmt, ...))
{
  return __builtin___sprintf_chk (__s, __USE_FORTIFY_LEVEL - 1,
				  __glibc_objsize (__s), __fmt,
				  __va_arg_pack ());
}
#elif !defined __cplusplus
# define sprintf(str, ...) \
  __builtin___sprintf_chk (str, __USE_FORTIFY_LEVEL - 1,		      \
			   __glibc_objsize (str), __VA_ARGS__)
#endif

__fortify_function int
__NTH (vsprintf (char *__restrict __s, const char *__restrict __fmt,
		 __gnuc_va_list __ap))
{
  return __builtin___vsprintf_chk (__s, __USE_FORTIFY_LEVEL - 1,
				   __glibc_objsize (__s), __fmt, __ap);
}

#if defined __USE_ISOC99 || defined __USE_UNIX98
# ifdef __va_arg_pack
__fortify_function int
__NTH (snprintf (char *__restrict __s, size_t __n,
		 const char *__restrict __fmt, ...))
{
  return __builtin___snprintf_chk (__s, __n, __USE_FORTIFY_LEVEL - 1,
				   __glibc_objsize (__s), __fmt,
				   __va_arg_pack ());
}
# elif !defined __cplusplus
#  define snprintf(str, len, ...) \
  __builtin___snprintf_chk (str, len, __USE_FORTIFY_LEVEL - 1,		      \
			    __glibc_objsize (str), __VA_ARGS__)
# endif

__fortify_function int
__NTH (vsnprintf (char *__restrict __s, size_t __n,
		  const char *__restrict __fmt, __gnuc_va_list __ap))
{
  return __builtin___vsnprintf_chk (__s, __n, __USE_FORTIFY_LEVEL - 1,
				    __glibc_objsize (__s), __fmt, __ap);
}

#endif

#if __USE_FORTIFY_LEVEL > 1
# ifdef __va_arg_pack
__fortify_function __nonnull ((1)) int
fprintf (FILE *__restrict __stream, const char *__restrict __fmt, ...)
{
  return __fprintf_chk (__stream, __USE_FORTIFY_LEVEL - 1, __fmt,
			__va_arg_pack ());
}

__fortify_function int
printf (const char *__restrict __fmt, ...)
{
  return __printf_chk (__USE_FORTIFY_LEVEL - 1, __fmt, __va_arg_pack ());
}
# elif !defined __cplusplus
#  define printf(...) \
  __printf_chk (__USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
#  define fprintf(stream, ...) \
  __fprintf_chk (stream, __USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
# endif

__fortify_function int
vprintf (const char *__restrict __fmt, __gnuc_va_list __ap)
{
#ifdef __USE_EXTERN_INLINES
  return __vfprintf_chk (stdout, __USE_FORTIFY_LEVEL - 1, __fmt, __ap);
#else
  return __vprintf_chk (__USE_FORTIFY_LEVEL - 1, __fmt, __ap);
#endif
}

__fortify_function __nonnull ((1)) int
vfprintf (FILE *__restrict __stream,
	  const char *__restrict __fmt, __gnuc_va_list __ap)
{
  return __vfprintf_chk (__stream, __USE_FORTIFY_LEVEL - 1, __fmt, __ap);
}

# ifdef __USE_XOPEN2K8
#  ifdef __va_arg_pack
__fortify_function int
dprintf (int __fd, const char *__restrict __fmt, ...)
{
  return __dprintf_chk (__fd, __USE_FORTIFY_LEVEL - 1, __fmt,
			__va_arg_pack ());
}
#  elif !defined __cplusplus
#   define dprintf(fd, ...) \
  __dprintf_chk (fd, __USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
#  endif

__fortify_function int
vdprintf (int __fd, const char *__restrict __fmt, __gnuc_va_list __ap)
{
  return __vdprintf_chk (__fd, __USE_FORTIFY_LEVEL - 1, __fmt, __ap);
}
# endif

# ifdef __USE_GNU
#  ifdef __va_arg_pack
__fortify_function int
__NTH (asprintf (char **__restrict __ptr, const char *__restrict __fmt, ...))
{
  return __asprintf_chk (__ptr, __USE_FORTIFY_LEVEL - 1, __fmt,
			 __va_arg_pack ());
}

__fortify_function int
__NTH (__asprintf (char **__restrict __ptr, const char *__restrict __fmt,
		   ...))
{
  return __asprintf_chk (__ptr, __USE_FORTIFY_LEVEL - 1, __fmt,
			 __va_arg_pack ());
}

__fortify_function int
__NTH (obstack_printf (struct obstack *__restrict __obstack,
		       const char *__restrict __fmt, ...))
{
  return __obstack_printf_chk (__obstack, __USE_FORTIFY_LEVEL - 1, __fmt,
			       __va_arg_pack ());
}
#  elif !defined __cplusplus
#   define asprintf(ptr, ...) \
  __asprintf_chk (ptr, __USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
#   define __asprintf(ptr, ...) \
  __asprintf_chk (ptr, __USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
#   define obstack_printf(obstack, ...) \
  __obstack_printf_chk (obstack, __USE_FORTIFY_LEVEL - 1, __VA_ARGS__)
#  endif

__fortify_function int
__NTH (vasprintf (char **__restrict __ptr, const char *__restrict __fmt,
		  __gnuc_va_list __ap))
{
  return __vasprintf_chk (__ptr, __USE_FORTIFY_LEVEL - 1, __fmt, __ap);
}

__fortify_function int
__NTH (obstack_vprintf (struct obstack *__restrict __obstack,
			const char *__restrict __fmt, __gnuc_va_list __ap))
{
  return __obstack_vprintf_chk (__obstack, __USE_FORTIFY_LEVEL - 1, __fmt,
				__ap);
}

# endif

#endif

#if __GLIBC_USE (DEPRECATED_GETS)
__fortify_function __wur char *
gets (char *__str)
{
  if (__glibc_objsize (__str) != (size_t) -1)
    return __gets_chk (__str, __glibc_objsize (__str));
  return __gets_warn (__str);
}
#endif

__fortify_function __wur __fortified_attr_access (__write_only__, 1, 2)
__nonnull ((3)) char *
fgets (char *__restrict __s, int __n, FILE *__restrict __stream)
{
  size_t sz = __glibc_objsize (__s);
  if (__glibc_safe_or_unknown_len (__n, sizeof (char), sz))
    return __fgets_alias (__s, __n, __stream);
  if (__glibc_unsafe_len (__n, sizeof (char), sz))
    return __fgets_chk_warn (__s, sz, __n, __stream);
  return __fgets_chk (__s, sz, __n, __stream);
}

__fortify_function __wur __nonnull ((4)) size_t
fread (void *__restrict __ptr, size_t __size, size_t __n,
       FILE *__restrict __stream)
{
  size_t sz = __glibc_objsize0 (__ptr);
  if (__glibc_safe_or_unknown_len (__n, __size, sz))
    return __fread_alias (__ptr, __size, __n, __stream);
  if (__glibc_unsafe_len (__n, __size, sz))
    return __fread_chk_warn (__ptr, sz, __size, __n, __stream);
  return __fread_chk (__ptr, sz, __size, __n, __stream);
}

#ifdef __USE_GNU
__fortify_function __wur __fortified_attr_access (__write_only__, 1, 2)
__nonnull ((3)) char *
fgets_unlocked (char *__restrict __s, int __n, FILE *__restrict __stream)
{
  size_t sz = __glibc_objsize (__s);
  if (__glibc_safe_or_unknown_len (__n, sizeof (char), sz))
    return __fgets_unlocked_alias (__s, __n, __stream);
  if (__glibc_unsafe_len (__n, sizeof (char), sz))
    return __fgets_unlocked_chk_warn (__s, sz, __n, __stream);
  return __fgets_unlocked_chk (__s, sz, __n, __stream);
}
#endif

#ifdef __USE_MISC
# undef fread_unlocked
__fortify_function __wur __nonnull ((4)) size_t
fread_unlocked (void *__restrict __ptr, size_t __size, size_t __n,
		FILE *__restrict __stream)
{
  size_t sz = __glibc_objsize0 (__ptr);
  if (__glibc_safe_or_unknown_len (__n, __size, sz))
    {
# ifdef __USE_EXTERN_INLINES
      if (__builtin_constant_p (__size)
	  && __builtin_constant_p (__n)
	  && (__size | __n) < (((size_t) 1) << (8 * sizeof (size_t) / 2))
	  && __size * __n <= 8)
	{
	  size_t __cnt = __size * __n;
	  char *__cptr = (char *) __ptr;
	  if (__cnt == 0)
	    return 0;

	  for (; __cnt > 0; --__cnt)
	    {
	      int __c = getc_unlocked (__stream);
	      if (__c == EOF)
		break;
	      *__cptr++ = __c;
	    }
	  return (__cptr - (char *) __ptr) / __size;
	}
# endif
      return __fread_unlocked_alias (__ptr, __size, __n, __stream);
    }
  if (__glibc_unsafe_len (__n, __size, sz))
    return __fread_unlocked_chk_warn (__ptr, sz, __size, __n, __stream);
  return __fread_unlocked_chk (__ptr, sz, __size, __n, __stream);

}
#endif

#endif /* bits/stdio2.h.  */