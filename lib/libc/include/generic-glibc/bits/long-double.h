/* Properties of long double type.  MIPS version.
   Copyright (C) 2016-2023 Free Software Foundation, Inc.
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

#include <sgidefs.h>

#if !defined __NO_LONG_DOUBLE_MATH && _MIPS_SIM == _ABIO32
# define __NO_LONG_DOUBLE_MATH	1
#endif
#define __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI 0