/* Definitions for POSIX memory map interface.  Linux/MIPS version.
   Copyright (C) 1997-2025 Free Software Foundation, Inc.
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

#ifndef _SYS_MMAN_H
# error "Never use <bits/mman.h> directly; include <sys/mman.h> instead."
#endif

/* The following definitions basically come from the kernel headers.
   But the kernel header is not namespace clean.  */

/* These are Linux-specific.  */
#define MAP_NORESERVE	0x0400		/* don't check for reservations */
#define MAP_GROWSDOWN	0x1000		/* stack-like segment */
#define MAP_DENYWRITE	0x2000		/* ETXTBSY */
#define MAP_EXECUTABLE	0x4000		/* mark it as an executable */
#define MAP_LOCKED	0x8000		/* pages are locked */
#define MAP_POPULATE   0x10000         /* populate (prefault) pagetables */
#define MAP_NONBLOCK   0x20000         /* do not block on IO */
#define MAP_STACK	0x40000		/* Allocation is for a stack.  */
#define MAP_HUGETLB	0x80000		/* Create huge page mapping.  */
#define MAP_FIXED_NOREPLACE 0x100000	/* MAP_FIXED but do not unmap
					   underlying mapping.  */

#define __MAP_ANONYMOUS 0x0800

/* Include generic Linux declarations.  */
#include <bits/mman-linux.h>

#define MAP_RENAME	MAP_ANONYMOUS