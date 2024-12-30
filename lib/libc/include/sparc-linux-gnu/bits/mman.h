/* Definitions for POSIX memory map interface.  Linux/SPARC version.
   Copyright (C) 1997-2024 Free Software Foundation, Inc.
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

#ifndef _SYS_MMAN_H
# error "Never use <bits/mman.h> directly; include <sys/mman.h> instead."
#endif

/* The following definitions basically come from the kernel headers.
   But the kernel header is not namespace clean.  */


/* These are Linux-specific.  */
#define MAP_GROWSDOWN	0x0200		/* Stack-like segment.  */
#define MAP_DENYWRITE	0x0800		/* ETXTBSY */
#define MAP_EXECUTABLE	0x1000		/* Mark it as an executable.  */
#define MAP_LOCKED	0x0100		/* Lock the mapping.  */
#define MAP_NORESERVE	0x0040		/* Don't check for reservations.  */
#define _MAP_NEW	0x80000000	/* Binary compatibility with SunOS.  */
#define MAP_POPULATE	0x8000		/* Populate (prefault) pagetables.  */
#define MAP_NONBLOCK	0x10000		/* Do not block on IO.  */
#define MAP_STACK	0x20000		/* Allocation is for a stack.  */
#define MAP_HUGETLB	0x40000		/* Create huge page mapping.  */
#define MAP_SYNC	0x80000		/* Perform synchronous page
					   faults for the mapping.  */
#define MAP_FIXED_NOREPLACE 0x100000	/* MAP_FIXED but do not unmap
					   underlying mapping.  */

/* Flags for `mlockall'.  */
#define MCL_CURRENT	0x2000		/* Lock all currently mapped pages.  */
#define MCL_FUTURE	0x4000		/* Lock all additions to address
					   space.  */
#define MCL_ONFAULT	0x8000		/* Lock all pages that are
					   faulted in.  */
/* Include generic Linux declarations.  */
#include <bits/mman-linux.h>

/* Other flags.  */
#define MAP_RENAME	MAP_ANONYMOUS