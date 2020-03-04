/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 2006-2020 Free Software Foundation, Inc.
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


/* Support for the utimes syscall was added in 3.14.  */
#if __LINUX_KERNEL_VERSION >= 0x030e00
# define __ASSUME_UTIMES		1
#endif

#include_next <kernel-features.h>

#define __ASSUME_RECV_SYSCALL   1
#define __ASSUME_SEND_SYSCALL	1

/* Support for the execveat syscall was added in 4.0.  */
#if __LINUX_KERNEL_VERSION < 0x040000
# undef __ASSUME_EXECVEAT
#endif

#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE_BACKWARDS 1
