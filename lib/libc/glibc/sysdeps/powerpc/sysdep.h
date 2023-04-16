/* Copyright (C) 1999-2023 Free Software Foundation, Inc.
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

/*
 * Powerpc Feature masks for the Aux Vector Hardware Capabilities (AT_HWCAP).
 * This entry is copied to _dl_hwcap or rtld_global._dl_hwcap during startup.
 */
#define _SYSDEPS_SYSDEP_H 1
#include <bits/hwcap.h>

#define PPC_FEATURE_970 (PPC_FEATURE_POWER4 + PPC_FEATURE_HAS_ALTIVEC)

#ifdef __ASSEMBLER__

/* Symbolic names for the registers.  The only portable way to write asm
   code is to use number but this produces really unreadable code.
   Therefore these symbolic names.  */

/* Integer registers.  */
#define r0	0
#define r1	1
#define r2	2
#define r3	3
#define r4	4
#define r5	5
#define r6	6
#define r7	7
#define r8	8
#define r9	9
#define r10	10
#define r11	11
#define r12	12
#define r13	13
#define r14	14
#define r15	15
#define r16	16
#define r17	17
#define r18	18
#define r19	19
#define r20	20
#define r21	21
#define r22	22
#define r23	23
#define r24	24
#define r25	25
#define r26	26
#define r27	27
#define r28	28
#define r29	29
#define r30	30
#define r31	31

/* Floating-point registers.  */
#define fp0	0
#define fp1	1
#define fp2	2
#define fp3	3
#define fp4	4
#define fp5	5
#define fp6	6
#define fp7	7
#define fp8	8
#define fp9	9
#define fp10	10
#define fp11	11
#define fp12	12
#define fp13	13
#define fp14	14
#define fp15	15
#define fp16	16
#define fp17	17
#define fp18	18
#define fp19	19
#define fp20	20
#define fp21	21
#define fp22	22
#define fp23	23
#define fp24	24
#define fp25	25
#define fp26	26
#define fp27	27
#define fp28	28
#define fp29	29
#define fp30	30
#define fp31	31

/* Condition code registers.  */
#define cr0	0
#define cr1	1
#define cr2	2
#define cr3	3
#define cr4	4
#define cr5	5
#define cr6	6
#define cr7	7

/* Vector registers. */
#define v0	0
#define v1	1
#define v2	2
#define v3	3
#define v4	4
#define v5	5
#define v6	6
#define v7	7
#define v8	8
#define v9	9
#define v10	10
#define v11	11
#define v12	12
#define v13	13
#define v14	14
#define v15	15
#define v16	16
#define v17	17
#define v18	18
#define v19	19
#define v20	20
#define v21	21
#define v22	22
#define v23	23
#define v24	24
#define v25	25
#define v26	26
#define v27	27
#define v28	28
#define v29	29
#define v30	30
#define v31	31

#define VRSAVE	256

/* The 32-bit words of a 64-bit dword are at these offsets in memory.  */
#if defined __LITTLE_ENDIAN__ || defined _LITTLE_ENDIAN
# define LOWORD 0
# define HIWORD 4
#else
# define LOWORD 4
# define HIWORD 0
#endif

/* The high 16-bit word of a 64-bit dword is at this offset in memory.  */
#if defined __LITTLE_ENDIAN__ || defined _LITTLE_ENDIAN
# define HISHORT 6
#else
# define HISHORT 0
#endif

/* This seems to always be the case on PPC.  */
#define ALIGNARG(log2) log2
#define ASM_SIZE_DIRECTIVE(name) .size name,.-name

#endif	/* __ASSEMBLER__ */
