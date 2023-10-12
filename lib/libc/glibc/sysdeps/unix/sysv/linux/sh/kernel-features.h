/* Set flags signalling availability of kernel features based on given
   kernel version number.  SH version.
   Copyright (C) 1999-2023 Free Software Foundation, Inc.
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

#ifndef __KERNEL_FEATURES_SH__
# define __KERNEL_FEATURES_SH__

#include <endian.h>

/* These syscalls were added for SH in 2.6.37.  */
#define __ASSUME_CONNECT_SYSCALL	1
#define __ASSUME_SEND_SYSCALL		1
#define __ASSUME_RECV_SYSCALL		1

#include_next <kernel-features.h>

/* SH4 ABI does not really require argument alignment for 64-bits, but
   the kernel interface for p{read,write}64 adds a dummy long argument
   before the offset.  */
#define __ASSUME_PRW_DUMMY_ARG	1

/* sh only supports ipc syscall before 5.1.  */
#if __LINUX_KERNEL_VERSION < 0x050100
# undef __ASSUME_DIRECT_SYSVIPC_SYSCALLS
# undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
#endif
#if __BYTE_ORDER == __BIG_ENDIAN
# define __ASSUME_SYSVIPC_BROKEN_MODE_T
#endif

/* Support for several syscalls was added in 4.8.  */
#if __LINUX_KERNEL_VERSION < 0x040800
# undef __ASSUME_RENAMEAT2
# undef __ASSUME_EXECVEAT
# undef __ASSUME_MLOCK2
#endif

/* sh does not support the statx system call before 5.1.  */
#if __LINUX_KERNEL_VERSION < 0x050100
# undef __ASSUME_STATX
#endif

#endif
