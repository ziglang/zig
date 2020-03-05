/* Copyright (C) 2011-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Chris Metcalf <cmetcalf@tilera.com>, 2011.

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

#include <bits/wordsize.h>
#include <kernel-features.h>
#include <sysdeps/unix/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>

/* Provide the common name to allow more code reuse.  */
#ifdef __NR_llseek
# define __NR__llseek __NR_llseek
#endif

#if __WORDSIZE == 64
/* By defining the older names, glibc will build syscall wrappers for
   both pread and pread64; sysdeps/unix/sysv/linux/wordsize-64/pread64.c
   will suppress generating any separate code for pread64.c.  */
#define __NR_pread __NR_pread64
#define __NR_pwrite __NR_pwrite64
#endif
