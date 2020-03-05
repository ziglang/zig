/* Set flags signalling availability of kernel features based on given
   kernel version number.
   Copyright (C) 2010-2020 Free Software Foundation, Inc.
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

#ifndef _KERNEL_FEATURES_H
#define _KERNEL_FEATURES_H 1

#include_next <kernel-features.h>

#define __ASSUME_RECV_SYSCALL   	1
#define __ASSUME_SEND_SYSCALL		1
#define __ASSUME_ACCEPT4_SYSCALL	1

/* Support for statx was added in 5.1.  */
#if __LINUX_KERNEL_VERSION < 0x050100
# undef __ASSUME_STATX
#endif

#undef __ASSUME_CLONE_DEFAULT
#define __ASSUME_CLONE2

#endif /* _KERNEL_FEATURES_H */
