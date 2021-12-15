/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 1999-2021 Free Software Foundation, Inc.
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

/* This file must not contain any C code.  At least it must be protected
   to allow using the file also in assembler files.  */

#ifndef _LINUX_KERNEL_FEATURES_H
#define _LINUX_KERNEL_FEATURES_H 1

#include <bits/wordsize.h>

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

/* Support for inter-process robust mutexes was added in 2.6.17 (but
   some architectures lack futex_atomic_cmpxchg_inatomic in some
   configurations).  */
#define __ASSUME_SET_ROBUST_LIST	1

/* Support for various CLOEXEC and NONBLOCK flags was added in
   2.6.27.  */
#define __ASSUME_IN_NONBLOCK	1

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
#define __ASSUME_GETSOCKOPT_SYSCALL	1
#define __ASSUME_SETSOCKOPT_SYSCALL	1

/* Support for SysV IPC through wired syscalls.  All supported architectures
   either support ipc syscall and/or all the ipc correspondent syscalls.  */
#define __ASSUME_DIRECT_SYSVIPC_SYSCALLS	1
/* The generic default __IPC_64 value is 0x0, however some architectures
   require a different value of 0x100.  */
#define __ASSUME_SYSVIPC_DEFAULT_IPC_64		1

/* All supported architectures reserve a 32-bit for MODE field in sysvipc
   ipc_perm.  However, some kernel ABI interfaces still expect a 16-bit
   field.  This is only an issue if arch-defined IPC_PERM padding is on a
   wrong position regarding endianness.  In this case, the IPC control
   routines (msgctl, semctl, and semtctl) requires to shift the value to
   correct place.
   The ABIs that requires it define __ASSUME_SYSVIPC_BROKEN_MODE_T.  */

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

/* Support for 64-bit time_t in the system call interface.  When this
   flag is set, the kernel provides a version of each of these system
   calls that accepts 64-bit time_t:

     clock_adjtime(64)
     clock_gettime(64)
     clock_settime(64)
     clock_getres(_time64)
     clock_nanosleep(_time64)
     futex(_time64)
     mq_timedreceive(_time64)
     mq_timedsend(_time64)
     ppoll(_time64)
     pselect6(_time64)
     rt_sigtimedwait(_time64)
     sched_rr_get_interval(_time64)
     timer_gettime(64)
     timer_settime(64)
     timerfd_gettime(64)
     timerfd_settime(64)
     utimensat(_time64)

   On architectures where time_t has historically been 64 bits,
   only the 64-bit version of each system call exists, and there
   are no suffixes on the __NR_ constants.

   On architectures where time_t has historically been 32 bits,
   both 32-bit and 64-bit versions of each system call may exist,
   depending on the kernel version.  When the 64-bit version exists,
   there is a '64' or '_time64' suffix on the name of its __NR_
   constant, as shown above.

   This flag is always set for Linux 5.1 and later.  Prior to that
   version, it is set only for some CPU architectures and ABIs:

   - __WORDSIZE == 64 - all supported architectures where pointers
     are 64 bits also have always had 64-bit time_t.

   - __WORDSIZE == 32 && __SYSCALL_WORDSIZE == 64 - this describes
     only one supported configuration, x86's 'x32' subarchitecture,
     where pointers are 32 bits but time_t has always been 64 bits.

   __ASSUME_TIME64_SYSCALLS being set does not mean __TIMESIZE is 64,
   and __TIMESIZE equal to 64 does not mean __ASSUME_TIME64_SYSCALLS
   is set.  All four cases are possible.  */

#if __LINUX_KERNEL_VERSION >= 0x050100                          \
  || __WORDSIZE == 64                                           \
  || (defined __SYSCALL_WORDSIZE && __SYSCALL_WORDSIZE == 64)
# define __ASSUME_TIME64_SYSCALLS 1
#endif

/* Linux waitid prior kernel 5.4 does not support waiting for the current
   process group.  */
#if __LINUX_KERNEL_VERSION >= 0x050400
# define __ASSUME_WAITID_PID0_P_PGID
#endif

/* The faccessat2 system call was introduced across all architectures
   in Linux 5.8.  */
#if __LINUX_KERNEL_VERSION >= 0x050800
# define __ASSUME_FACCESSAT2 1
#else
# define __ASSUME_FACCESSAT2 0
#endif

#endif /* kernel-features.h */
