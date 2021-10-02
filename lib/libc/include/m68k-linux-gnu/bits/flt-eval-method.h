/* Define __GLIBC_FLT_EVAL_METHOD.  M68K version.
   Copyright (C) 2016-2021 Free Software Foundation, Inc.
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

#ifndef _MATH_H
# error "Never use <bits/flt-eval-method.h> directly; include <math.h> instead."
#endif

/* The m68k FPUs evaluate all values in the 96-bit floating-point
   format which is also available for the user as 'long double'.  */
#define __GLIBC_FLT_EVAL_METHOD	2