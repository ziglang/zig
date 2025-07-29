/* Definitions for POSIX memory map interface.  Linux/x86_64 version.
   Copyright (C) 2001-2025 Free Software Foundation, Inc.
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

/* Other flags.  */
#define MAP_32BIT	0x40		/* Only give out 32-bit addresses.  */
#define MAP_ABOVE4G	0x80		/* Only map above 4GB.  */

#ifdef __USE_MISC
/* Set up a restore token in the newly allocated shadow stack */
# define SHADOW_STACK_SET_TOKEN 0x1
#endif

#include <bits/mman-map-flags-generic.h>

/* Include generic Linux declarations.  */
#include <bits/mman-linux.h>