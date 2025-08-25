/* Definitions for POSIX memory map interface.  Linux/AArch64 version.
   Copyright (C) 2020-2025 Free Software Foundation, Inc.
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

/* AArch64 specific definitions, should be in sync with
   arch/arm64/include/uapi/asm/mman.h.  */

#define PROT_BTI	0x10
#define PROT_MTE	0x20

#ifdef __USE_GNU
# define PKEY_UNRESTRICTED 0x0
# define PKEY_DISABLE_ACCESS 0x1
# define PKEY_DISABLE_WRITE 0x2
# define PKEY_DISABLE_EXECUTE 0x4
# define PKEY_DISABLE_READ 0x8
#endif

#include <bits/mman-map-flags-generic.h>

/* Include generic Linux declarations.  */
#include <bits/mman-linux.h>