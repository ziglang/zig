/* Copyright (C) 1992-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper, <drepper@gnu.ai.mit.edu>, August 1995.

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

#ifndef _LINUX_ALPHA_SYSDEP_H
#define _LINUX_ALPHA_SYSDEP_H 1

#ifdef __ASSEMBLER__
#include <asm/pal.h>
#include <alpha/regdef.h>
#endif

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/alpha/sysdep.h>

#include <tls.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#define SINGLE_THREAD_BY_GLOBAL 1

#endif /* _LINUX_ALPHA_SYSDEP_H */
