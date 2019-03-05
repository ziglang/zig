/* Definitions of constants and data structure for POSIX 1003.1b-1993
   scheduling interface.
   Copyright (C) 1996-2019 Free Software Foundation, Inc.
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

#ifndef _BITS_SCHED_H
#define _BITS_SCHED_H 1

#ifndef _SCHED_H
# error "Never include <bits/sched.h> directly; use <sched.h> instead."
#endif

/* Scheduling algorithms.  */
#define SCHED_OTHER	0
#define SCHED_FIFO	1
#define SCHED_RR	2

#include <bits/types/struct_sched_param.h>

#endif /* bits/sched.h */
