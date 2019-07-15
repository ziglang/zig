/* Copyright (C) 1997-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

/* PowerPC can be little or big endian.  Hopefully gcc will know...  */

#ifndef _ENDIAN_H
# error "Never use <bits/endian.h> directly; include <endian.h> instead."
#endif

#if defined __BIG_ENDIAN__ || defined _BIG_ENDIAN
# if defined __LITTLE_ENDIAN__ || defined _LITTLE_ENDIAN
#  error Both BIG_ENDIAN and LITTLE_ENDIAN defined!
# endif
# define __BYTE_ORDER __BIG_ENDIAN
#else
# if defined __LITTLE_ENDIAN__ || defined _LITTLE_ENDIAN
#  define __BYTE_ORDER __LITTLE_ENDIAN
# else
#  warning Cannot determine current byte order, assuming big-endian.
#  define __BYTE_ORDER __BIG_ENDIAN
# endif
#endif
