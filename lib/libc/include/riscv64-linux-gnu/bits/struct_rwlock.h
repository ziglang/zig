/* RISC-V internal rwlock struct definitions.
   Copyright (C) 2019-2023 Free Software Foundation, Inc.

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

#ifndef _RWLOCK_INTERNAL_H
#define _RWLOCK_INTERNAL_H

/* There is a lot of padding in this structure.  While it's not strictly
   necessary on RISC-V, we're going to leave it in to be on the safe side in
   case it's needed in the future.  Most other architectures have the padding,
   so this gives us the same extensibility as everyone else has.  */
struct __pthread_rwlock_arch_t
{
  unsigned int __readers;
  unsigned int __writers;
  unsigned int __wrphase_futex;
  unsigned int __writers_futex;
  unsigned int __pad3;
  unsigned int __pad4;
#if __WORDSIZE == 64
  int __cur_writer;
  int __shared;
  unsigned long int __pad1;
  unsigned long int __pad2;
  unsigned int __flags;
#else
# if __BYTE_ORDER == __BIG_ENDIAN
  unsigned char __pad1;
  unsigned char __pad2;
  unsigned char __shared;
  unsigned char __flags;
# else
  unsigned char __flags;
  unsigned char __shared;
  unsigned char __pad1;
  unsigned char __pad2;
# endif
  int __cur_writer;
#endif
};

#if __WORDSIZE == 64
# define __PTHREAD_RWLOCK_INITIALIZER(__flags) \
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, __flags
#elif __BYTE_ORDER == __BIG_ENDIAN
# define __PTHREAD_RWLOCK_INITIALIZER(__flags) \
  0, 0, 0, 0, 0, 0, 0, 0, 0, __flags, 0
#else
# define __PTHREAD_RWLOCK_INITIALIZER(__flags) \
  0, 0, 0, 0, 0, 0, __flags, 0, 0, 0, 0
#endif

#endif