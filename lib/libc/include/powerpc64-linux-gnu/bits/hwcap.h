/* Defines for bits in AT_HWCAP and AT_HWCAP2.
   Copyright (C) 2012-2025 Free Software Foundation, Inc.
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

#if !defined(_SYS_AUXV_H) && !defined(_SYSDEPS_SYSDEP_H)
# error "Never include <bits/hwcap.h> directly; use <sys/auxv.h> instead."
#endif

/* The bit numbers must match those in the kernel's asm/cputable.h.  */

/* Feature definitions in AT_HWCAP.  */
#define PPC_FEATURE_32		    0x80000000 /* 32-bit mode. */
#define PPC_FEATURE_64		    0x40000000 /* 64-bit mode. */
#define PPC_FEATURE_601_INSTR	    0x20000000 /* 601 chip, Old POWER ISA.  */
#define PPC_FEATURE_HAS_ALTIVEC	    0x10000000 /* SIMD/Vector Unit.  */
#define PPC_FEATURE_HAS_FPU	    0x08000000 /* Floating Point Unit.  */
#define PPC_FEATURE_HAS_MMU	    0x04000000 /* Memory Management Unit.  */
#define PPC_FEATURE_HAS_4xxMAC	    0x02000000 /* 4xx Multiply Accumulator.  */
#define PPC_FEATURE_UNIFIED_CACHE   0x01000000 /* Unified I/D cache.  */
#define PPC_FEATURE_HAS_SPE	    0x00800000 /* Signal Processing ext.  */
#define PPC_FEATURE_HAS_EFP_SINGLE  0x00400000 /* SPE Float.  */
#define PPC_FEATURE_HAS_EFP_DOUBLE  0x00200000 /* SPE Double.  */
#define PPC_FEATURE_NO_TB	    0x00100000 /* 601/403gx have no timebase */
#define PPC_FEATURE_POWER4	    0x00080000 /* POWER4 ISA 2.00 */
#define PPC_FEATURE_POWER5	    0x00040000 /* POWER5 ISA 2.02 */
#define PPC_FEATURE_POWER5_PLUS	    0x00020000 /* POWER5+ ISA 2.03 */
#define PPC_FEATURE_CELL_BE	    0x00010000 /* CELL Broadband Engine */
#define PPC_FEATURE_BOOKE	    0x00008000 /* ISA Category Embedded */
#define PPC_FEATURE_SMT		    0x00004000 /* Simultaneous
						  Multi-Threading */
#define PPC_FEATURE_ICACHE_SNOOP    0x00002000
#define PPC_FEATURE_ARCH_2_05	    0x00001000 /* ISA 2.05 */
#define PPC_FEATURE_PA6T	    0x00000800 /* PA Semi 6T Core */
#define PPC_FEATURE_HAS_DFP	    0x00000400 /* Decimal FP Unit */
#define PPC_FEATURE_POWER6_EXT	    0x00000200 /* P6 + mffgpr/mftgpr */
#define PPC_FEATURE_ARCH_2_06	    0x00000100 /* ISA 2.06 */
#define PPC_FEATURE_HAS_VSX	    0x00000080 /* P7 Vector Extension.  */
#define PPC_FEATURE_PSERIES_PERFMON_COMPAT  0x00000040
/* Reserved by the kernel.	    0x00000004  Do not use.  */
#define PPC_FEATURE_TRUE_LE	    0x00000002
#define PPC_FEATURE_PPC_LE	    0x00000001

/* Feature definitions in AT_HWCAP2.  */
#define PPC_FEATURE2_ARCH_2_07     0x80000000 /* ISA 2.07 */
#define PPC_FEATURE2_HAS_HTM       0x40000000 /* Hardware Transactional
						 Memory */
#define PPC_FEATURE2_HAS_DSCR      0x20000000 /* Data Stream Control
						 Register */
#define PPC_FEATURE2_HAS_EBB       0x10000000 /* Event Base Branching */
#define PPC_FEATURE2_HAS_ISEL      0x08000000 /* Integer Select */
#define PPC_FEATURE2_HAS_TAR       0x04000000 /* Target Address Register */
#define PPC_FEATURE2_HAS_VEC_CRYPTO  0x02000000  /* Target supports vector
						    instruction.  */
#define PPC_FEATURE2_HTM_NOSC	   0x01000000 /* Kernel aborts transaction
						 when a syscall is made.  */
#define PPC_FEATURE2_ARCH_3_00	   0x00800000 /* ISA 3.0 */
#define PPC_FEATURE2_HAS_IEEE128   0x00400000 /* VSX IEEE Binary Float
						 128-bit */
#define PPC_FEATURE2_DARN	   0x00200000 /* darn instruction.  */
#define PPC_FEATURE2_SCV	   0x00100000 /* scv syscall.  */
#define PPC_FEATURE2_HTM_NO_SUSPEND  0x00080000 /* TM without suspended
						   state.  */
#define PPC_FEATURE2_ARCH_3_1	   0x00040000 /* ISA 3.1.  */
#define PPC_FEATURE2_MMA	   0x00020000 /* Matrix-Multiply Assist.  */