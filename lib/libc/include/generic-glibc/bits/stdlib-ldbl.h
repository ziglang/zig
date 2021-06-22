/* -mlong-double-64 compatibility mode for <stdlib.h> functions.
   Copyright (C) 2006-2021 Free Software Foundation, Inc.
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
# error "Never include <bits/stdlib-ldbl.h> directly; use <stdlib.h> instead."
#endif

#ifdef	__USE_ISOC99
# ifdef __LDBL_COMPAT
__LDBL_REDIR1_DECL (strtold, strtod)
# else
__LDBL_REDIR1_DECL (strtold, __strtoieee128)
# endif
#endif

#ifdef __USE_GNU
# ifdef __LDBL_COMPAT
__LDBL_REDIR1_DECL (strtold_l, strtod_l)
# else
__LDBL_REDIR1_DECL (strtold_l, __strtoieee128_l)
# endif
#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
# ifdef __LDBL_COMPAT
__LDBL_REDIR1_DECL (strfroml, strfromd)
# else
__LDBL_REDIR1_DECL (strfroml, __strfromieee128)
# endif
#endif

#ifdef __USE_MISC
# if defined __LDBL_COMPAT
__LDBL_REDIR1_DECL (qecvt, ecvt)
__LDBL_REDIR1_DECL (qfcvt, fcvt)
__LDBL_REDIR1_DECL (qgcvt, gcvt)
__LDBL_REDIR1_DECL (qecvt_r, ecvt_r)
__LDBL_REDIR1_DECL (qfcvt_r, fcvt_r)
# elif __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 1
__LDBL_REDIR1_DECL (qecvt, __qecvtieee128)
__LDBL_REDIR1_DECL (qfcvt, __qfcvtieee128)
__LDBL_REDIR1_DECL (qgcvt, __qgcvtieee128)
__LDBL_REDIR1_DECL (qecvt_r, __qecvtieee128_r)
__LDBL_REDIR1_DECL (qfcvt_r, __qfcvtieee128_r)
# else
#  error bits/stdlib-ldbl.h included when no ldbl redirections are required.
# endif
#endif