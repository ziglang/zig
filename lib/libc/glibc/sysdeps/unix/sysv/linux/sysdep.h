/* Copyright (C) 2015-2023 Free Software Foundation, Inc.
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

#ifndef _SYSDEP_LINUX_H
#define _SYSDEP_LINUX_H

#include <bits/wordsize.h>
#include <kernel-features.h>
#include <endian.h>
#include <errno.h>

#undef INTERNAL_SYSCALL_ERROR_P
#define INTERNAL_SYSCALL_ERROR_P(val) \
  ((unsigned long int) (val) > -4096UL)

#ifndef SYSCALL_ERROR_LABEL
# define SYSCALL_ERROR_LABEL(sc_err)					\
  ({									\
    __set_errno (sc_err);						\
    -1L;								\
  })
#endif

/* Define a macro which expands into the inline wrapper code for a system
   call.  It sets the errno and returns -1 on a failure, or the syscall
   return value otherwise.  */
#undef INLINE_SYSCALL
#define INLINE_SYSCALL(name, nr, args...)				\
  ({									\
    long int sc_ret = INTERNAL_SYSCALL (name, nr, args);		\
    __glibc_unlikely (INTERNAL_SYSCALL_ERROR_P (sc_ret))		\
    ? SYSCALL_ERROR_LABEL (INTERNAL_SYSCALL_ERRNO (sc_ret))		\
    : sc_ret;								\
  })

#undef INTERNAL_SYSCALL_ERRNO
#define INTERNAL_SYSCALL_ERRNO(val)     (-(val))

/* Set error number and return -1.  A target may choose to return the
   internal function, __syscall_error, which sets errno and returns -1.
   We use -1l, instead of -1, so that it can be casted to (void *).  */
#define INLINE_SYSCALL_ERROR_RETURN_VALUE(err)  \
  ({						\
    __set_errno (err);				\
    -1l;					\
  })

/* Provide a dummy argument that can be used to force register
   alignment for register pairs if required by the syscall ABI.  */
#ifdef __ASSUME_ALIGNED_REGISTER_PAIRS
#define __ALIGNMENT_ARG 0,
#define __ALIGNMENT_COUNT(a,b) b
#else
#define __ALIGNMENT_ARG
#define __ALIGNMENT_COUNT(a,b) a
#endif

/* Provide a common macro to pass 64-bit value on syscalls.  */
#if __WORDSIZE == 64 || defined __ASSUME_WORDSIZE64_ILP32
# define SYSCALL_LL(val)   (val)
# define SYSCALL_LL64(val) (val)
#else
#define SYSCALL_LL(val)   \
  __LONG_LONG_PAIR ((val) >> 31, (val))
#define SYSCALL_LL64(val) \
  __LONG_LONG_PAIR ((long) ((val) >> 32), (long) ((val) & 0xffffffff))
#endif

/* Provide a common macro to pass 64-bit value on pread and pwrite
   syscalls.  */
#ifdef __ASSUME_PRW_DUMMY_ARG
# define SYSCALL_LL_PRW(val)   0, SYSCALL_LL (val)
# define SYSCALL_LL64_PRW(val) 0, SYSCALL_LL64 (val)
#else
# define SYSCALL_LL_PRW(val)   __ALIGNMENT_ARG SYSCALL_LL (val)
# define SYSCALL_LL64_PRW(val) __ALIGNMENT_ARG SYSCALL_LL64 (val)
#endif

/* Provide a macro to pass the off{64}_t argument on p{readv,writev}{64}.  */
#define LO_HI_LONG(val) \
 (long) (val), \
 (long) (((uint64_t) (val)) >> 32)

/* Export the ___brk_addr symbol on brk.c implementation (some ABIs export
   it due and old crtstuff.c code).  */
#define HAVE_INTERNAL_BRK_ADDR_SYMBOL   0

#endif /* _SYSDEP_LINUX_H  */
