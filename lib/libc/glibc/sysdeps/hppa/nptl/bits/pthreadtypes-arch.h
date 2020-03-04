/* Copyright (C) 2005-2020 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _BITS_PTHREADTYPES_ARCH_H
#define _BITS_PTHREADTYPES_ARCH_H	1

/* Linuxthread type sizes (bytes):
   sizeof(pthread_attr_t) = 0x24 (36)
   sizeof(pthread_barrier_t) = 0x30 (48)
   sizeof(pthread_barrierattr_t) = 0x4 (4)
   sizeof(pthread_cond_t) = 0x30 (48)
   sizeof(pthread_condattr_t) = 0x4 (4)
   sizeof(pthread_mutex_t) = 0x30 (48)
   sizeof(pthread_mutexattr_t) = 0x4 (4)
   sizeof(pthread_rwlock_t) = 0x40 (64)
   sizeof(pthread_rwlockattr_t) = 0x8 (8)
   sizeof(pthread_spinlock_t) = 0x10 (16) */

#define __SIZEOF_PTHREAD_ATTR_T 36
#define __SIZEOF_PTHREAD_MUTEX_T 48
#define __SIZEOF_PTHREAD_BARRIER_T 48
#define __SIZEOF_PTHREAD_BARRIERATTR_T 4
#define __SIZEOF_PTHREAD_COND_T 48
#define __SIZEOF_PTHREAD_CONDATTR_T 4
#define __SIZEOF_PTHREAD_MUTEXATTR_T 4
#define __SIZEOF_PTHREAD_RWLOCK_T 64
#define __SIZEOF_PTHREAD_RWLOCKATTR_T 8

#define __LOCK_ALIGNMENT __attribute__ ((__aligned__(16)))
#define __ONCE_ALIGNMENT

#endif	/* bits/pthreadtypes.h */
