/* Set flags signalling availability of kernel features based on given
   kernel version number.  i386 version.
   Copyright (C) 1999-2020 Free Software Foundation, Inc.
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

/* Direct socketcalls available with kernel 4.3.  */
#if __LINUX_KERNEL_VERSION >= 0x040300
# define __ASSUME_SOCKET_SYSCALL             1
# define __ASSUME_SOCKETPAIR_SYSCALL         1
# define __ASSUME_BIND_SYSCALL               1
# define __ASSUME_LISTEN_SYSCALL             1
# define __ASSUME_GETSOCKOPT_SYSCALL         1
# define __ASSUME_SETSOCKOPT_SYSCALL         1
# define __ASSUME_GETSOCKNAME_SYSCALL        1
# define __ASSUME_GETPEERNAME_SYSCALL        1
# define __ASSUME_SHUTDOWN_SYSCALL           1
#endif

#include_next <kernel-features.h>

#undef __ASSUME_ACCEPT_SYSCALL

#if __LINUX_KERNEL_VERSION < 0x040300
# undef __ASSUME_ACCEPT4_SYSCALL
# undef __ASSUME_SENDMSG_SYSCALL
# undef __ASSUME_RECVMSG_SYSCALL
# undef __ASSUME_CONNECT_SYSCALL
# undef __ASSUME_RECVFROM_SYSCALL
# undef __ASSUME_SENDTO_SYSCALL
#endif

/* i686 only supports ipc syscall before 5.1.  */
#if __LINUX_KERNEL_VERSION < 0x050100
# undef __ASSUME_DIRECT_SYSVIPC_SYSCALLS
# undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
#endif

#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE_BACKWARDS	1
