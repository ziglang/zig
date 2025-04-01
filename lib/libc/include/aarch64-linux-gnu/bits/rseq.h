/* Restartable Sequences Linux aarch64 architecture header.
   Copyright (C) 2021-2025 Free Software Foundation, Inc.

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

#ifndef _SYS_RSEQ_H
# error "Never use <bits/rseq.h> directly; include <sys/rseq.h> instead."
#endif

/* RSEQ_SIG is a signature required before each abort handler code.

   It is a 32-bit value that maps to actual architecture code compiled
   into applications and libraries.  It needs to be defined for each
   architecture.  When choosing this value, it needs to be taken into
   account that generating invalid instructions may have ill effects on
   tools like objdump, and may also have impact on the CPU speculative
   execution efficiency in some cases.

   aarch64 -mbig-endian generates mixed endianness code vs data:
   little-endian code and big-endian data.  Ensure the RSEQ_SIG signature
   matches code endianness.  */

#define RSEQ_SIG_CODE  0xd428bc00  /* BRK #0x45E0.  */

#ifdef __AARCH64EB__
# define RSEQ_SIG_DATA 0x00bc28d4  /* BRK #0x45E0.  */
#else
# define RSEQ_SIG_DATA RSEQ_SIG_CODE
#endif

#define RSEQ_SIG       RSEQ_SIG_DATA