/* Copyright (C) 2005-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

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

/* The old 4-word 16-byte aligned lock. This is initalized
   to all ones by the Linuxthreads PTHREAD_MUTEX_INITIALIZER.
   Unused in NPTL.  */
#define __PTHREAD_COMPAT_PADDING_MID  int __compat_padding[4];
/* Two more words are left before the NPTL
   pthread_mutex_t is larger than Linuxthreads.  */
#define __PTHREAD_COMPAT_PADDING_END  int __reserved[2];
#define __PTHREAD_MUTEX_LOCK_ELISION    0
#define __PTHREAD_MUTEX_NUSERS_AFTER_KIND  1
#define __PTHREAD_MUTEX_USE_UNION          1

#define __LOCK_ALIGNMENT __attribute__ ((__aligned__(16)))
#define __ONCE_ALIGNMENT

struct __pthread_rwlock_arch_t
{
  /* In the old Linuxthreads pthread_rwlock_t, this is the
     start of the 4-word 16-byte aligned lock structure. The
     next four words are all set to 1 by the Linuxthreads
     PTHREAD_RWLOCK_INITIALIZER. We ignore them in NPTL.  */
  int __compat_padding[4] __attribute__ ((__aligned__(16)));
  unsigned int __readers;
  unsigned int __writers;
  unsigned int __wrphase_futex;
  unsigned int __writers_futex;
  unsigned int __pad3;
  unsigned int __pad4;
  int __cur_writer;
  /* An unused word, reserved for future use. It was added
     to maintain the location of the flags from the Linuxthreads
     layout of this structure.  */
  int __reserved1;
  /* FLAGS must stay at this position in the structure to maintain
     binary compatibility.  */
  unsigned char __pad2;
  unsigned char __pad1;
  unsigned char __shared;
  unsigned char __flags;
  /* The NPTL pthread_rwlock_t is 4 words smaller than the
     Linuxthreads version. One word is in the middle of the
     structure, the other three are at the end.  */
  int __reserved2;
  int __reserved3;
  int __reserved4;
};

#define __PTHREAD_RWLOCK_ELISION_EXTRA 0

#endif	/* bits/pthreadtypes.h */
