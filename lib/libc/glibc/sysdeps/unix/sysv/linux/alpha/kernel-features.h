/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 2010-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

#ifndef _KERNEL_FEATURES_H
#define _KERNEL_FEATURES_H 1

#include_next <kernel-features.h>

/* There never has been support for fstat64.  */
#undef __ASSUME_STATFS64
#define __ASSUME_STATFS64 0

/* Alpha defines SysV ipc shmat syscall with a different name.  */
#define __NR_shmat __NR_osf_shmat

#define __ASSUME_RECV_SYSCALL	1
#define __ASSUME_SEND_SYSCALL	1

/* Support for the renameat2 syscall was added in 3.17.  */
#if __LINUX_KERNEL_VERSION < 0x031100
# undef __ASSUME_RENAMEAT2
#endif

/* Support for the execveat syscall was added in 4.2.  */
#if __LINUX_KERNEL_VERSION < 0x040200
# undef __ASSUME_EXECVEAT
#endif

/* Support for copy_file_range, statx was added in kernel 4.13.  */
#if __LINUX_KERNEL_VERSION < 0x040D00
# undef __ASSUME_MLOCK2
# undef __ASSUME_COPY_FILE_RANGE
# undef __ASSUME_STATX
#endif

#endif /* _KERNEL_FEATURES_H */
