/* Restartable Sequences Linux arm architecture header.
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

/*
   RSEQ_SIG is a signature required before each abort handler code.

   It is a 32-bit value that maps to actual architecture code compiled
   into applications and libraries.  It needs to be defined for each
   architecture.  When choosing this value, it needs to be taken into
   account that generating invalid instructions may have ill effects on
   tools like objdump, and may also have impact on the CPU speculative
   execution efficiency in some cases.

   - ARM little endian

   RSEQ_SIG uses the udf A32 instruction with an uncommon immediate operand
   value 0x5de3.  This traps if user-space reaches this instruction by mistake,
   and the uncommon operand ensures the kernel does not move the instruction
   pointer to attacker-controlled code on rseq abort.

   The instruction pattern in the A32 instruction set is:

   e7f5def3    udf    #24035    ; 0x5de3

   This translates to the following instruction pattern in the T16 instruction
   set:

   little endian:
   def3        udf    #243      ; 0xf3
   e7f5        b.n    <7f5>

   - ARMv6+ big endian (BE8):

   ARMv6+ -mbig-endian generates mixed endianness code vs data: little-endian
   code and big-endian data.  The data value of the signature needs to have its
   byte order reversed to generate the trap instruction:

   Data: 0xf3def5e7

   Translates to this A32 instruction pattern:

   e7f5def3    udf    #24035    ; 0x5de3

   Translates to this T16 instruction pattern:

   def3        udf    #243      ; 0xf3
   e7f5        b.n    <7f5>

   - Prior to ARMv6 big endian (BE32):

   Prior to ARMv6, -mbig-endian generates big-endian code and data
   (which match), so the endianness of the data representation of the
   signature should not be reversed.  However, the choice between BE32
   and BE8 is done by the linker, so we cannot know whether code and
   data endianness will be mixed before the linker is invoked.  So rather
   than try to play tricks with the linker, the rseq signature is simply
   data (not a trap instruction) prior to ARMv6 on big endian.  This is
   why the signature is expressed as data (.word) rather than as
   instruction (.inst) in assembler.  */

#ifdef __ARMEB__
# define RSEQ_SIG    0xf3def5e7      /* udf    #24035    ; 0x5de3 (ARMv6+) */
#else
# define RSEQ_SIG    0xe7f5def3      /* udf    #24035    ; 0x5de3 */
#endif