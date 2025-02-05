/* Pthread data structures.  Generic version.
   Copyright (C) 2002-2024 Free Software Foundation, Inc.
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
   License along with the GNU C Library;  if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _BITS_PTHREAD_H
#define _BITS_PTHREAD_H	1

#include <bits/types/__pthread_t.h>

/* Return true if __T1 and __T2 both name the same thread.  Otherwise,
   false.  */
extern int __pthread_equal (__pthread_t __t1, __pthread_t __t2);

#ifdef __USE_EXTERN_INLINES
__extern_inline int
__pthread_equal (__pthread_t __t1, __pthread_t __t2)
{
  return __t1 == __t2;
}
#endif

#endif /* bits/pthread.h */
