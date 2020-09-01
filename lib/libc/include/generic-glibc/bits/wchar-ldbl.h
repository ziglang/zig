/* -mlong-double-64 compatibility mode for <wchar.h> functions.
   Copyright (C) 2006-2020 Free Software Foundation, Inc.
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
# error "Never include <bits/wchar-ldbl.h> directly; use <wchar.h> instead."
#endif

#if defined __USE_ISOC95 || defined __USE_UNIX98
__LDBL_REDIR_DECL (fwprintf);
__LDBL_REDIR_DECL (wprintf);
__LDBL_REDIR_DECL (swprintf);
__LDBL_REDIR_DECL (vfwprintf);
__LDBL_REDIR_DECL (vwprintf);
__LDBL_REDIR_DECL (vswprintf);
# if !__GLIBC_USE (DEPRECATED_SCANF)
#  if defined __LDBL_COMPAT
__LDBL_REDIR1_DECL (fwscanf, __nldbl___isoc99_fwscanf)
__LDBL_REDIR1_DECL (wscanf, __nldbl___isoc99_wscanf)
__LDBL_REDIR1_DECL (swscanf, __nldbl___isoc99_swscanf)
#  elif __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 1
__LDBL_REDIR1_DECL (fwscanf, __isoc99_fwscanfieee128)
__LDBL_REDIR1_DECL (wscanf, __isoc99_wscanfieee128)
__LDBL_REDIR1_DECL (swscanf, __isoc99_swscanfieee128)
#  else
#   error bits/stdlib-ldbl.h included when no ldbl redirections are required.
#  endif
# else
__LDBL_REDIR_DECL (fwscanf);
__LDBL_REDIR_DECL (wscanf);
__LDBL_REDIR_DECL (swscanf);
# endif
#endif

#ifdef __USE_ISOC99
# ifdef __LDBL_COMPAT
__LDBL_REDIR1_DECL (wcstold, wcstod);
# else
__LDBL_REDIR1_DECL (wcstold, __wcstoieee128)
# endif
# if !__GLIBC_USE (DEPRECATED_SCANF)
#  if defined __LDBL_COMPAT
__LDBL_REDIR1_DECL (vfwscanf, __nldbl___isoc99_vfwscanf)
__LDBL_REDIR1_DECL (vwscanf, __nldbl___isoc99_vwscanf)
__LDBL_REDIR1_DECL (vswscanf, __nldbl___isoc99_vswscanf)
#  elif __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 1
__LDBL_REDIR1_DECL (vfwscanf, __isoc99_vfwscanfieee128)
__LDBL_REDIR1_DECL (vwscanf, __isoc99_vwscanfieee128)
__LDBL_REDIR1_DECL (vswscanf, __isoc99_vswscanfieee128)
#  else
#   error bits/stdlib-ldbl.h included when no ldbl redirections are required.
#  endif
# else
__LDBL_REDIR_DECL (vfwscanf);
__LDBL_REDIR_DECL (vwscanf);
__LDBL_REDIR_DECL (vswscanf);
# endif
#endif

#ifdef __USE_GNU
# ifdef __LDBL_COMPAT
__LDBL_REDIR1_DECL (wcstold_l, wcstod_l);
# else
__LDBL_REDIR1_DECL (wcstold_l, __wcstoieee128_l)
# endif
#endif

#if __USE_FORTIFY_LEVEL > 0 && defined __fortify_function
__LDBL_REDIR2_DECL (swprintf_chk)
__LDBL_REDIR2_DECL (vswprintf_chk)
# if __USE_FORTIFY_LEVEL > 1
__LDBL_REDIR2_DECL (fwprintf_chk)
__LDBL_REDIR2_DECL (wprintf_chk)
__LDBL_REDIR2_DECL (vfwprintf_chk)
__LDBL_REDIR2_DECL (vwprintf_chk)
# endif
#endif