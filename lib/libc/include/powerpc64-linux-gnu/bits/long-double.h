/* Properties of long double type.  ldbl-opt version.
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

#ifndef __NO_LONG_DOUBLE_MATH
# define __LONG_DOUBLE_MATH_OPTIONAL	1
# ifndef __LONG_DOUBLE_128__
#  define __NO_LONG_DOUBLE_MATH		1
# endif
#endif
#define __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI 0