/* Set flags signalling availability of kernel features based on given
   kernel version number.  SPARC version.
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

#include_next <kernel-features.h>

/* 32-bit SPARC kernels do not support
   futex_atomic_cmpxchg_inatomic.  */
#if !defined __arch64__ && !defined __sparc_v9__
# undef __ASSUME_SET_ROBUST_LIST
#endif

/* These syscalls were added for 32-bit in 4.4 (but present for 64-bit
   in all supported kernel versions); the architecture-independent
   kernel-features.h assumes some of them to be present by default.
   getpeername and getsockname syscalls were also added for 32-bit in
   4.4, but only for 32-bit kernels, not in the compat syscall table
   for 64-bit kernels.  */
#if !defined __arch64__ && __LINUX_KERNEL_VERSION < 0x040400
# undef __ASSUME_SENDMSG_SYSCALL
# undef __ASSUME_RECVMSG_SYSCALL
# undef __ASSUME_ACCEPT_SYSCALL
# undef __ASSUME_CONNECT_SYSCALL
# undef __ASSUME_RECVFROM_SYSCALL
# undef __ASSUME_SENDTO_SYSCALL
# undef __ASSUME_GETSOCKOPT_SYSCALL
# undef __ASSUME_SETSOCKOPT_SYSCALL
#endif

/* There syscalls were added for 32-bit in compat syscall table only
   in 4.20 (but present for 64-bit in all supported kernel versions).  */
#if !defined __arch64__ && __LINUX_KERNEL_VERSION < 0x041400
# undef __ASSUME_GETSOCKNAME_SYSCALL
# undef __ASSUME_GETPEERNAME_SYSCALL
#endif

/* These syscalls were added for both 32-bit and 64-bit in 4.4.  */
#if __LINUX_KERNEL_VERSION < 0x040400
# undef __ASSUME_BIND_SYSCALL
# undef __ASSUME_LISTEN_SYSCALL
#endif

#ifdef __arch64__
/* sparc64 defines __NR_pause,  however it is not supported (ENOSYS).
   Undefine so pause.c can use a correct alternative.  */
# undef __NR_pause
#endif

/* sparc only supports ipc syscall before 5.1.  */
#if __LINUX_KERNEL_VERSION < 0x050100
# undef __ASSUME_DIRECT_SYSVIPC_SYSCALLS
# if !defined __arch64__
#  undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
# endif
#endif

/* Support for the renameat2 syscall was added in 3.16.  */
#if __LINUX_KERNEL_VERSION < 0x031000
# undef __ASSUME_RENAMEAT2
#endif

/* SPARC kernel Kconfig does not define CONFIG_CLONE_BACKWARDS, however it
   has the same ABI as if it did, implemented by sparc-specific code
   (sparc_do_fork).

   It also has a unique return value convention:

     Parent -->  %o0 == child's  pid, %o1 == 0
     Child  -->  %o0 == parent's pid, %o1 == 1

   Which required a special macro to correct issue the syscall
   (INLINE_CLONE_SYSCALL).  */
#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE_BACKWARDS	1
