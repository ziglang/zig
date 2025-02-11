/* Restartable Sequences Linux riscv architecture header.
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

#include <bits/endian.h>

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

   Select the instruction "csrw mhartid, x0" as the RSEQ_SIG. Unlike
   other architectures, the ebreak instruction has no immediate field for
   distinguishing purposes. Hence, ebreak is not suitable as RSEQ_SIG.
   "csrw mhartid, x0" can also satisfy the RSEQ requirement because it
   is an uncommon instruction and will raise an illegal instruction
   exception when executed in all modes.  */

#if __BYTE_ORDER == __LITTLE_ENDIAN
#define RSEQ_SIG	0xf1401073
#else
/* RSEQ is currently only supported on Little-Endian.  */
#endif