/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 2008-2025 Free Software Foundation, Inc.
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

#include_next <kernel-features.h>

#undef __ASSUME_ACCEPT_SYSCALL

/* Direct socketcalls available with kernel 4.3.  */
#if __LINUX_KERNEL_VERSION < 0x040300
# undef __ASSUME_ACCEPT4_SYSCALL
# undef __ASSUME_RECVMMSG_SYSCALL
# undef __ASSUME_SENDMMSG_SYSCALL
# undef __ASSUME_SENDMSG_SYSCALL
# undef __ASSUME_RECVMSG_SYSCALL
# undef __ASSUME_CONNECT_SYSCALL
# undef __ASSUME_RECVFROM_SYSCALL
# undef __ASSUME_SENDTO_SYSCALL
# undef __ASSUME_GETSOCKOPT_SYSCALL
# undef __ASSUME_SETSOCKOPT_SYSCALL
# undef __ASSUME_BIND_SYSCALL
# undef __ASSUME_SOCKET_SYSCALL
# undef __ASSUME_SOCKETPAIR_SYSCALL
# undef __ASSUME_LISTEN_SYSCALL
# undef __ASSUME_SHUTDOWN_SYSCALL
# undef __ASSUME_GETSOCKNAME_SYSCALL
# undef __ASSUME_GETPEERNAME_SYSCALL
#endif

/* No support for PI futexes or robust mutexes before 3.10 for m68k.  */
#if __LINUX_KERNEL_VERSION < 0x030a00
# undef __ASSUME_SET_ROBUST_LIST
#endif

/* m68k only supports ipc syscall before 5.1.  */
#if __LINUX_KERNEL_VERSION < 0x050100
# undef __ASSUME_DIRECT_SYSVIPC_SYSCALLS
# undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
#endif
#define __ASSUME_SYSVIPC_BROKEN_MODE_T
