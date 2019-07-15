/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 1999-2019 Free Software Foundation, Inc.
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

/* This file must not contain any C code.  At least it must be protected
   to allow using the file also in assembler files.  */

#ifndef __LINUX_KERNEL_VERSION
/* We assume the worst; all kernels should be supported.  */
# define __LINUX_KERNEL_VERSION	0
#endif

/* We assume for __LINUX_KERNEL_VERSION the same encoding used in
   linux/version.h.  I.e., the major, minor, and subminor all get a
   byte with the major number being in the highest byte.  This means
   we can do numeric comparisons.

   In the following we will define certain symbols depending on
   whether the describes kernel feature is available in the kernel
   version given by __LINUX_KERNEL_VERSION.  We are not always exactly
   recording the correct versions in which the features were
   introduced.  If somebody cares these values can afterwards be
   corrected.  */

/* The statfs64 syscalls are available in 2.5.74 (but not for alpha).  */
#define __ASSUME_STATFS64	1

/* pselect/ppoll were introduced just after 2.6.16-rc1.  On x86_64 and
   SH this appeared first in 2.6.19-rc1, on ia64 in 2.6.22-rc1.  */
#define __ASSUME_PSELECT	1

/* The *at syscalls were introduced just after 2.6.16-rc1.  On PPC
   they were introduced in 2.6.17-rc1, on SH in 2.6.19-rc1.  */
#define __ASSUME_ATFCTS	1

/* Support for inter-process robust mutexes was added in 2.6.17 (but
   some architectures lack futex_atomic_cmpxchg_inatomic in some
   configurations).  */
#define __ASSUME_SET_ROBUST_LIST	1

/* Support for various CLOEXEC and NONBLOCK flags was added in
   2.6.27.  */
#define __ASSUME_IN_NONBLOCK	1

/* Support for the FUTEX_CLOCK_REALTIME flag was added in 2.6.29.  */
#define __ASSUME_FUTEX_CLOCK_REALTIME	1

/* Support for preadv and pwritev was added in 2.6.30.  */
#define __ASSUME_PREADV	1
#define __ASSUME_PWRITEV	1

/* Support for sendmmsg functionality was added in 3.0.  */
#define __ASSUME_SENDMMSG	1

/* On most architectures, most socket syscalls are supported for all
   supported kernel versions, but on some socketcall architectures
   separate syscalls were only added later.  */
#define __ASSUME_SENDMSG_SYSCALL	1
#define __ASSUME_RECVMSG_SYSCALL	1
#define __ASSUME_ACCEPT_SYSCALL		1
#define __ASSUME_CONNECT_SYSCALL	1
#define __ASSUME_RECVFROM_SYSCALL	1
#define __ASSUME_SENDTO_SYSCALL		1
#define __ASSUME_ACCEPT4_SYSCALL	1
#define __ASSUME_RECVMMSG_SYSCALL	1
#define __ASSUME_SENDMMSG_SYSCALL	1

/* Support for SysV IPC through wired syscalls.  All supported architectures
   either support ipc syscall and/or all the ipc correspondent syscalls.  */
#define __ASSUME_DIRECT_SYSVIPC_SYSCALLS	1

/* Support for p{read,write}v2 was added in 4.6.  However Linux default
   implementation does not assume the __ASSUME_* and instead use a fallback
   implementation based on p{read,write}v and returning an error for
   non supported flags.  */

/* Support for the renameat2 system call was added in kernel 3.15.  */
#if __LINUX_KERNEL_VERSION >= 0x030F00
# define __ASSUME_RENAMEAT2
#endif

/* Support for the execveat syscall was added in 3.19.  */
#if __LINUX_KERNEL_VERSION >= 0x031300
# define __ASSUME_EXECVEAT	1
#endif

#if __LINUX_KERNEL_VERSION >= 0x040400
# define __ASSUME_MLOCK2 1
#endif

#if __LINUX_KERNEL_VERSION >= 0x040500
# define __ASSUME_COPY_FILE_RANGE 1
#endif

/* Support for statx was added in kernel 4.11.  */
#if __LINUX_KERNEL_VERSION >= 0x040B00
# define __ASSUME_STATX 1
#endif

/* Support for clone call used on fork.  The signature varies across the
   architectures with current 4 different variants:

   1. long int clone (unsigned long flags, unsigned long newsp,
		      int *parent_tidptr, unsigned long tls,
		      int *child_tidptr)

   2. long int clone (unsigned long newsp, unsigned long clone_flags,
		      int *parent_tidptr, int * child_tidptr,
		      unsigned long tls)

   3. long int clone (unsigned long flags, unsigned long newsp,
		      int stack_size, int *parent_tidptr,
		      int *child_tidptr, unsigned long tls)

   4. long int clone (unsigned long flags, unsigned long newsp,
		      int *parent_tidptr, int *child_tidptr,
		      unsigned long tls)

   The fourth variant is intended to be used as the default for newer ports,
   Also IA64 uses the third variant but with __NR_clone2 instead of
   __NR_clone.

   The macros names to define the variant used for the architecture is
   similar to kernel:

   - __ASSUME_CLONE_BACKWARDS: for variant 1.
   - __ASSUME_CLONE_BACKWARDS2: for variant 2 (s390).
   - __ASSUME_CLONE_BACKWARDS3: for variant 3 (microblaze).
   - __ASSUME_CLONE_DEFAULT: for variant 4.
   - __ASSUME_CLONE2: for clone2 with variant 3 (ia64).
   */

#define __ASSUME_CLONE_DEFAULT 1
