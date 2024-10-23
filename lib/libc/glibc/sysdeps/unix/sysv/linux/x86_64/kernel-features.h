/* Set flags signalling availability of kernel features based on given
   kernel version number.  x86-64 version.
   Copyright (C) 1999-2024 Free Software Foundation, Inc.
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

/* Define that x32 is a ILP32 ABI to set the correct interface to pass
   64-bits values through syscalls.  */
#ifdef __ILP32__
# define __ASSUME_WORDSIZE64_ILP32	1
#endif

#include_next <kernel-features.h>
