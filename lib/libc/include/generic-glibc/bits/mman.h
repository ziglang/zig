/* Definitions for POSIX memory map interface.  Linux/generic version.
   Copyright (C) 1997-2021 Free Software Foundation, Inc.
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

/* These definitions are appropriate for architectures that, in the
   Linux kernel, either have no uapi/asm/mman.h, or have one that
   includes asm-generic/mman.h without any changes or additions
   relevant to glibc.  If there are additions relevant to glibc, an
   architecture-specific bits/mman.h is needed.  */

#include <bits/mman-map-flags-generic.h>

/* Include generic Linux declarations.  */
#include <bits/mman-linux.h>