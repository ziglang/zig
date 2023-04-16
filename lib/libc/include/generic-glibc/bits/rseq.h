/* Restartable Sequences Linux mips architecture header.
   Copyright (C) 2021-2023 Free Software Foundation, Inc.

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

   RSEQ_SIG uses the break instruction.  The instruction pattern is:

   On MIPS:
        0350000d        break     0x350

   On nanoMIPS:
        00100350        break     0x350

   On microMIPS:
        0000d407        break     0x350

   For nanoMIPS32 and microMIPS, the instruction stream is encoded as
   16-bit halfwords, so the signature halfwords need to be swapped
   accordingly for little-endian.  */

#if defined (__nanomips__)
# ifdef __MIPSEL__
#  define RSEQ_SIG      0x03500010
# else
#  define RSEQ_SIG      0x00100350
# endif
#elif defined (__mips_micromips)
# ifdef __MIPSEL__
#  define RSEQ_SIG      0xd4070000
# else
#  define RSEQ_SIG      0x0000d407
# endif
#elif defined (__mips__)
# define RSEQ_SIG       0x0350000d
#else
/* Unknown MIPS architecture.  */
#endif