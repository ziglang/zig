/* Copyright (C) 1994-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_TIMEB_H
#define _SYS_TIMEB_H	1

#include <features.h>

__BEGIN_DECLS

# include <bits/types/struct_timeb.h>

/* Fill in TIMEBUF with information about the current time.  */

extern int ftime (struct timeb *__timebuf)
  __nonnull ((1))
  __attribute_deprecated_msg__ ("Use gettimeofday or clock_gettime instead");

__END_DECLS

#endif	/* sys/timeb.h */