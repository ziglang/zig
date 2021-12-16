/* Machine-specific pthread type layouts.  Hurd i386 version.
   Copyright (C) 2002-2021 Free Software Foundation, Inc.
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

#ifndef _BITS_PTHREADTYPES_ARCH_H
#define _BITS_PTHREADTYPES_ARCH_H	1

#define __SIZEOF_PTHREAD_MUTEX_T 32
#define __SIZEOF_PTHREAD_ATTR_T 32
#define __SIZEOF_PTHREAD_RWLOCK_T 28
#define __SIZEOF_PTHREAD_BARRIER_T 24
#define __SIZEOF_PTHREAD_MUTEXATTR_T 16
#define __SIZEOF_PTHREAD_COND_T 20
#define __SIZEOF_PTHREAD_CONDATTR_T 8
#define __SIZEOF_PTHREAD_RWLOCKATTR_T 4
#define __SIZEOF_PTHREAD_BARRIERATTR_T 4
#define __SIZEOF_PTHREAD_ONCE_T 8

#define __LOCK_ALIGNMENT
#define __ONCE_ALIGNMENT

#endif /* bits/pthreadtypes.h */
