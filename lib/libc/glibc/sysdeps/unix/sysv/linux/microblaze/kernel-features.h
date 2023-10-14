/* Copyright (C) 2011-2023 Free Software Foundation, Inc.
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

#include <endian.h>

/* All supported kernel versions for MicroBlaze have these syscalls.  */
#define __ASSUME_CONNECT_SYSCALL	1
#define __ASSUME_SEND_SYSCALL		1
#define __ASSUME_RECV_SYSCALL		1

#include_next <kernel-features.h>

/* Support for the pselect6, preadv and pwritev syscalls was added in
   3.15.  */
#if __LINUX_KERNEL_VERSION < 0x030f00
# undef __ASSUME_PSELECT
# undef __ASSUME_PREADV
# undef __ASSUME_PWRITEV
#endif

/* Support for the sendmmsg syscall was added in 3.3.  */
#if __LINUX_KERNEL_VERSION < 0x030300
# undef __ASSUME_SENDMMSG_SYSCALL
#endif

/* Support for the renameat2 syscall was added in 3.17.  */
#if __LINUX_KERNEL_VERSION < 0x031100
# undef __ASSUME_RENAMEAT2
#endif

/* Support for the execveat syscall was added in 4.0.  */
#if __LINUX_KERNEL_VERSION < 0x040000
# undef __ASSUME_EXECVEAT
#endif

/* Support for the mlock2 syscall was added in 4.7.  */
#if __LINUX_KERNEL_VERSION < 0x040700
# undef __ASSUME_MLOCK2
#endif

/* Support for statx was added in kernel 4.12.  */
#if __LINUX_KERNEL_VERSION < 0X040C00
# undef __ASSUME_STATX
#endif

#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE_BACKWARDS3

#if __BYTE_ORDER == __BIG_ENDIAN
# define __ASSUME_SYSVIPC_BROKEN_MODE_T
#endif
#undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
