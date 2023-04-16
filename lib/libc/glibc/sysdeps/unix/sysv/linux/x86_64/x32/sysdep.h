/* Copyright (C) 2012-2023 Free Software Foundation, Inc.
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

#ifndef _LINUX_X32_SYSDEP_H
#define _LINUX_X32_SYSDEP_H 1

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/x86_64/sysdep.h>
#include <sysdeps/x86_64/x32/sysdep.h>

/* How to pass the off{64}_t argument on p{readv,writev}{64}.  */
#undef LO_HI_LONG
#define LO_HI_LONG(val) (val)

#ifdef __ASSEMBLER__
/* Zero-extend 32-bit unsigned long int arguments to 64 bits.  */
# undef ZERO_EXTEND_1
# define ZERO_EXTEND_1 movl %edi, %edi;
# undef ZERO_EXTEND_2
# define ZERO_EXTEND_2 movl %esi, %esi;
# undef ZERO_EXTEND_3
# define ZERO_EXTEND_3 movl %edx, %edx;
# if SYSCALL_ULONG_ARG_1 == 4 || SYSCALL_ULONG_ARG_2 == 4
#  undef DOARGS_4
#  define DOARGS_4 movl %ecx, %r10d;
# else
#  undef ZERO_EXTEND_4
#  define ZERO_EXTEND_4 movl %r10d, %r10d;
# endif
# undef ZERO_EXTEND_5
# define ZERO_EXTEND_5 movl %r8d, %r8d;
# undef ZERO_EXTEND_6
# define ZERO_EXTEND_6 movl %r9d, %r9d;
#else /* !__ASSEMBLER__ */
# undef ARGIFY
/* Enforce zero-extension for pointers and array system call arguments.
   For integer types, extend to int64_t (the full register) using a
   regular cast, resulting in zero or sign extension based on the
   signedness of the original type.  */
# define ARGIFY(X) \
 ({									\
    _Pragma ("GCC diagnostic push");					\
    _Pragma ("GCC diagnostic ignored \"-Wpointer-to-int-cast\"");	\
    (__builtin_classify_type (X) == 5					\
     ? (uintptr_t) (X) : (int64_t) (X));				\
    _Pragma ("GCC diagnostic pop");					\
  })
#endif	/* __ASSEMBLER__ */

#endif /* linux/x86_64/x32/sysdep.h */
