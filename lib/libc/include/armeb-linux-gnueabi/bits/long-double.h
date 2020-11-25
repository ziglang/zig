/* Properties of long double type.
   Copyright (C) 2016-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License  published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* This header is included by <sys/cdefs.h>.

   If long double is ABI-compatible with double, it should define
   __NO_LONG_DOUBLE_MATH to 1; otherwise, it should leave
   __NO_LONG_DOUBLE_MATH undefined.

   If this build of the GNU C Library supports both long double
   ABI-compatible with double and some other long double format not
   ABI-compatible with double, it should define
   __LONG_DOUBLE_MATH_OPTIONAL to 1; otherwise, it should leave
   __LONG_DOUBLE_MATH_OPTIONAL undefined.

   If __NO_LONG_DOUBLE_MATH is already defined, this header must not
   define anything; this is needed to work with the definition of
   __NO_LONG_DOUBLE_MATH in nldbl-compat.h.  */

/* In the default version of this header, long double is
   ABI-compatible with double.  */
#ifndef __NO_LONG_DOUBLE_MATH
# define __NO_LONG_DOUBLE_MATH	1
#endif

/* The macro __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI is used to determine the
   choice of the underlying ABI of long double.  It will always assume
   a constant value for each translation unit.

   If the value is non-zero, any API which is parameterized by the long
   double type (i.e the scanf/printf family of functions or the explicitly
   parameterized math.h functions) will be redirected to a compatible
   implementation using _Float128 ABI via symbols suffixed with ieee128.

   The mechanism this macro uses to acquire may be a function
   of architecture, or target specific options used to invoke the
   compiler.  */
#define __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI 0