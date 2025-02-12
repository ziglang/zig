/* Common threading primitives definitions for both POSIX and C11.
   Copyright (C) 2017-2025 Free Software Foundation, Inc.
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

#ifndef _THREAD_SHARED_TYPES_H
#define _THREAD_SHARED_TYPES_H 1

#include <bits/pthreadtypes-arch.h>
#include <bits/types/struct___pthread_once.h>
#include <bits/types/__thrd_t.h>

typedef int __tss_t;

typedef union
{
  struct __pthread_once __data;
  int __align __ONCE_ALIGNMENT;
  char __size[__SIZEOF_PTHREAD_ONCE_T];
} __once_flag;

#define __ONCE_FLAG_INIT { { __PTHREAD_ONCE_INIT } }

#endif /* _THREAD_SHARED_TYPES_H  */
