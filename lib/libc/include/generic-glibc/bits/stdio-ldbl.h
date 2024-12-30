/* -mlong-double-64 compatibility mode for stdio functions.
   Copyright (C) 2006-2024 Free Software Foundation, Inc.
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

#ifndef _STDIO_H
# error "Never include <bits/stdio-ldbl.h> directly; use <stdio.h> instead."
#endif

__LDBL_REDIR_DECL (fprintf)
__LDBL_REDIR_DECL (printf)
__LDBL_REDIR_DECL (sprintf)
__LDBL_REDIR_DECL (vfprintf)
__LDBL_REDIR_DECL (vprintf)
__LDBL_REDIR_DECL (vsprintf)
#if !__GLIBC_USE (DEPRECATED_SCANF)
# if defined __LDBL_COMPAT
#  if __GLIBC_USE (C23_STRTOL)
__LDBL_REDIR1_DECL (fscanf, __nldbl___isoc23_fscanf)
__LDBL_REDIR1_DECL (scanf, __nldbl___isoc23_scanf)
__LDBL_REDIR1_DECL (sscanf, __nldbl___isoc23_sscanf)
#  else
__LDBL_REDIR1_DECL (fscanf, __nldbl___isoc99_fscanf)
__LDBL_REDIR1_DECL (scanf, __nldbl___isoc99_scanf)
__LDBL_REDIR1_DECL (sscanf, __nldbl___isoc99_sscanf)
#  endif
# elif __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 1
#  if __GLIBC_USE (C23_STRTOL)
__LDBL_REDIR1_DECL (fscanf, __isoc23_fscanfieee128)
__LDBL_REDIR1_DECL (scanf, __isoc23_scanfieee128)
__LDBL_REDIR1_DECL (sscanf, __isoc23_sscanfieee128)
#  else
__LDBL_REDIR1_DECL (fscanf, __isoc99_fscanfieee128)
__LDBL_REDIR1_DECL (scanf, __isoc99_scanfieee128)
__LDBL_REDIR1_DECL (sscanf, __isoc99_sscanfieee128)
#  endif
# else
#  error bits/stdlib-ldbl.h included when no ldbl redirections are required.
# endif
#else
__LDBL_REDIR_DECL (fscanf)
__LDBL_REDIR_DECL (scanf)
__LDBL_REDIR_DECL (sscanf)
#endif

#if defined __USE_ISOC99 || defined __USE_UNIX98
__LDBL_REDIR_DECL (snprintf)
__LDBL_REDIR_DECL (vsnprintf)
#endif

#ifdef	__USE_ISOC99
# if !__GLIBC_USE (DEPRECATED_SCANF)
#  if defined __LDBL_COMPAT
#   if __GLIBC_USE (C23_STRTOL)
__LDBL_REDIR1_DECL (vfscanf, __nldbl___isoc23_vfscanf)
__LDBL_REDIR1_DECL (vscanf, __nldbl___isoc23_vscanf)
__LDBL_REDIR1_DECL (vsscanf, __nldbl___isoc23_vsscanf)
#   else
__LDBL_REDIR1_DECL (vfscanf, __nldbl___isoc99_vfscanf)
__LDBL_REDIR1_DECL (vscanf, __nldbl___isoc99_vscanf)
__LDBL_REDIR1_DECL (vsscanf, __nldbl___isoc99_vsscanf)
#   endif
#  elif __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 1
#   if __GLIBC_USE (C23_STRTOL)
__LDBL_REDIR1_DECL (vfscanf, __isoc23_vfscanfieee128)
__LDBL_REDIR1_DECL (vscanf, __isoc23_vscanfieee128)
__LDBL_REDIR1_DECL (vsscanf, __isoc23_vsscanfieee128)
#   else
__LDBL_REDIR1_DECL (vfscanf, __isoc99_vfscanfieee128)
__LDBL_REDIR1_DECL (vscanf, __isoc99_vscanfieee128)
__LDBL_REDIR1_DECL (vsscanf, __isoc99_vsscanfieee128)
#   endif
#  else
#   error bits/stdlib-ldbl.h included when no ldbl redirections are required.
#  endif
# else
__LDBL_REDIR_DECL (vfscanf)
__LDBL_REDIR_DECL (vsscanf)
__LDBL_REDIR_DECL (vscanf)
# endif
#endif

#ifdef __USE_XOPEN2K8
__LDBL_REDIR_DECL (vdprintf)
__LDBL_REDIR_DECL (dprintf)
#endif

#ifdef __USE_GNU
__LDBL_REDIR_DECL (vasprintf)
__LDBL_REDIR2_DECL (asprintf)
__LDBL_REDIR_DECL (asprintf)
__LDBL_REDIR_DECL (obstack_printf)
__LDBL_REDIR_DECL (obstack_vprintf)
#endif

#if __USE_FORTIFY_LEVEL > 0 && defined __fortify_function
__LDBL_REDIR2_DECL (sprintf_chk)
__LDBL_REDIR2_DECL (vsprintf_chk)
# if defined __USE_ISOC99 || defined __USE_UNIX98
__LDBL_REDIR2_DECL (snprintf_chk)
__LDBL_REDIR2_DECL (vsnprintf_chk)
# endif
# if __USE_FORTIFY_LEVEL > 1
__LDBL_REDIR2_DECL (fprintf_chk)
__LDBL_REDIR2_DECL (printf_chk)
__LDBL_REDIR2_DECL (vfprintf_chk)
__LDBL_REDIR2_DECL (vprintf_chk)
#  ifdef __USE_XOPEN2K8
__LDBL_REDIR2_DECL (dprintf_chk)
__LDBL_REDIR2_DECL (vdprintf_chk)
#  endif
#  ifdef __USE_GNU
__LDBL_REDIR2_DECL (asprintf_chk)
__LDBL_REDIR2_DECL (vasprintf_chk)
__LDBL_REDIR2_DECL (obstack_printf_chk)
__LDBL_REDIR2_DECL (obstack_vprintf_chk)
#  endif
# endif
#endif