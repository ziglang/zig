/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 2006-2023 Free Software Foundation, Inc.
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
#include_next <kernel-features.h>

/* The ARM kernel before 3.14.3 may or may not support
   futex_atomic_cmpxchg_inatomic, depending on kernel
   configuration.  */
#if __LINUX_KERNEL_VERSION < 0x030E03
# undef __ASSUME_SET_ROBUST_LIST
#endif

/* ARM fadvise64_64 reorganize the syscall arguments.  */
#define __ASSUME_FADVISE64_64_6ARG	1

/* Define this if your 32-bit syscall API requires 64-bit register
   pairs to start with an even-number register.  */
#define __ASSUME_ALIGNED_REGISTER_PAIRS	1

/* ARM only has a syscall for fadvise64{_64} and it is defined with a
   non-standard name.  */
#define __NR_fadvise64_64 __NR_arm_fadvise64_64

#define __ASSUME_RECV_SYSCALL   1
#define __ASSUME_SEND_SYSCALL	1

/* Support for the mlock2 and copy_file_range syscalls was added to
   the compat syscall table for 64-bit kernels in 4.7, although
   present in 32-bit kernels from 4.4 and 4.5 respectively.  */
#if __LINUX_KERNEL_VERSION < 0x040700
# undef __ASSUME_MLOCK2
#endif

#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE_BACKWARDS	1

#if __BYTE_ORDER == __BIG_ENDIAN
# define __ASSUME_SYSVIPC_BROKEN_MODE_T
#endif

#undef __ASSUME_SYSVIPC_DEFAULT_IPC_64
