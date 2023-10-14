/* Macros to control TS 18661-3 glibc features.
   Copyright (C) 2017-2023 Free Software Foundation, Inc.
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

/* Defined to 1 if the current compiler invocation provides a
   floating-point type with the IEEE 754 binary128 format, and this glibc
   includes corresponding *f128 interfaces for it.  */
#define __HAVE_FLOAT128 0

/* Defined to 1 if __HAVE_FLOAT128 is 1 and the type is ABI-distinct
   from the default float, double and long double types in this glibc.  */
#define __HAVE_DISTINCT_FLOAT128 0

/* Defined to 1 if the current compiler invocation provides a
   floating-point type with the right format for _Float64x, and this
   glibc includes corresponding *f64x interfaces for it.  */
#define __HAVE_FLOAT64X 0

/* Defined to 1 if __HAVE_FLOAT64X is 1 and _Float64x has the format
   of long double.  Otherwise, if __HAVE_FLOAT64X is 1, _Float64x has
   the format of _Float128, which must be different from that of long
   double.  */
#define __HAVE_FLOAT64X_LONG_DOUBLE 0

#ifndef __ASSEMBLER__

/* Defined to concatenate the literal suffix to be used with _Float128
   types, if __HAVE_FLOAT128 is 1.
   E.g.: #define __f128(x) x##f128.  */
# undef __f128

/* Defined to a complex binary128 type if __HAVE_FLOAT128 is 1.
   E.g.: #define __CFLOAT128 _Complex _Float128.  */
# undef __CFLOAT128

#endif /* !__ASSEMBLER__.  */

#include <bits/floatn-common.h>