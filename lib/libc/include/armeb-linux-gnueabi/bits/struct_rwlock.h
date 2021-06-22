/* Default read-write lock implementation struct definitions.
   Copyright (C) 2019-2021 Free Software Foundation, Inc.
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

#ifndef __RWLOCK_INTERNAL_H
#define __RWLOCK_INTERNAL_H

#include <bits/endian.h>

/* Generic struct for both POSIX read-write lock.  New ports are expected
   to use the default layout, however archictetures can redefine it to add
   arch-specific extensions (such as lock-elision).  The struct have a size
   of 32 bytes on both LP32 and LP64 architectures.  */

struct __pthread_rwlock_arch_t
{
  unsigned int __readers;
  unsigned int __writers;
  unsigned int __wrphase_futex;
  unsigned int __writers_futex;
  unsigned int __pad3;
  unsigned int __pad4;
  /* FLAGS must stay at its position in the structure to maintain
     binary compatibility.  */
#if __BYTE_ORDER == __BIG_ENDIAN
  unsigned char __pad1;
  unsigned char __pad2;
  unsigned char __shared;
  unsigned char __flags;
#else
  unsigned char __flags;
  unsigned char __shared;
  unsigned char __pad1;
  unsigned char __pad2;
#endif
  int __cur_writer;
};

#if __BYTE_ORDER == __BIG_ENDIAN
# define __PTHREAD_RWLOCK_INITIALIZER(__flags) \
  0, 0, 0, 0, 0, 0, 0, 0, 0, __flags, 0
#else
# define __PTHREAD_RWLOCK_INITIALIZER(__flags) \
  0, 0, 0, 0, 0, 0, __flags, 0, 0, 0, 0
#endif

#endif