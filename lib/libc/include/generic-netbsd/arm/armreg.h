/*	$NetBSD: armreg.h,v 1.136 2022/12/03 20:24:21 ryo Exp $	*/

/*
 * Copyright (c) 1998, 2001 Ben Harris
 * Copyright (c) 1994-1996 Mark Brinicombe.
 * Copyright (c) 1994 Brini.
 * All rights reserved.
 *
 * This code is derived from software written for Brini by Mark Brinicombe
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Brini.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRINI ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL BRINI OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ARM_ARMREG_H
#define _ARM_ARMREG_H

#include <arm/cputypes.h>

#ifdef __arm__

/*
 * ARM Process Status Register
 *
 * The picture in the ARM manuals looks like this:
 *       3 3 2 2 2 2
 *       1 0 9 8 7 6                                   8 7 6 5 4       0
 *      +-+-+-+-+-+-------------------------------------+-+-+-+---------+
 *      |N|Z|C|V|Q|                reserved             |I|F|T|M M M M M|
 *      | | | | | |                                     | | | |4 3 2 1 0|
 *      +-+-+-+-+-+-------------------------------------+-+-+-+---------+
 */

#define	PSR_FLAGS 0xf0000000	/* flags */
#define PSR_N_bit (1 << 31)	/* negative */
#define PSR_Z_bit (1 << 30)	/* zero */
#define PSR_C_bit (1 << 29)	/* carry */
#define PSR_V_bit (1 << 28)	/* overflow */

#define PSR_Q_bit (1 << 27)	/* saturation */
#define PSR_IT1_bit (1 << 26)
#define PSR_IT0_bit (1 << 25)
#define PSR_J_bit (1 << 24)	/* Jazelle mode */
#define PSR_GE_bits (15 << 16)	/* SIMD GE bits */
#define PSR_IT7_bit (1 << 15)
#define PSR_IT6_bit (1 << 14)
#define PSR_IT5_bit (1 << 13)
#define PSR_IT4_bit (1 << 12)
#define PSR_IT3_bit (1 << 11)
#define PSR_IT2_bit (1 << 10)
#define PSR_E_BIT (1 << 9)	/* Endian state */
#define PSR_A_BIT (1 << 8)	/* Async abort disable */

#define I32_bit (1 << 7)	/* IRQ disable */
#define F32_bit (1 << 6)	/* FIQ disable */
#define IF32_bits (3 << 6)	/* IRQ/FIQ disable */

#define PSR_T_bit (1 << 5)	/* Thumb state */

#define PSR_MODE	0x0000001f	/* mode mask */
#define PSR_USR32_MODE	0x00000010
#define PSR_FIQ32_MODE	0x00000011
#define PSR_IRQ32_MODE	0x00000012
#define PSR_SVC32_MODE	0x00000013
#define PSR_MON32_MODE	0x00000016
#define PSR_ABT32_MODE	0x00000017
#define PSR_HYP32_MODE	0x0000001a
#define PSR_UND32_MODE	0x0000001b
#define PSR_SYS32_MODE	0x0000001f
#define PSR_32_MODE	0x00000010

#define R15_FLAGS	0xf0000000
#define R15_FLAG_N	0x80000000
#define R15_FLAG_Z	0x40000000
#define R15_FLAG_C	0x20000000
#define R15_FLAG_V	0x10000000

/*
 * Co-processor 15:  The system control co-processor.
 */

#define ARM_CP15_CPU_ID		0

/* CPUID registers */
#define ARM_ISA3_SYNCHPRIM_MASK	0x0000f000
#define ARM_ISA4_SYNCHPRIM_MASK	0x00f00000
#define ARM_ISA3_SYNCHPRIM_LDREX	0x10	// LDREX
#define ARM_ISA3_SYNCHPRIM_LDREXPLUS	0x13	// +CLREX/LDREXB/LDREXH
#define ARM_ISA3_SYNCHPRIM_LDREXD	0x20	// +LDREXD
#define ARM_PFR0_THUMBEE_MASK	0x0000f000
#define ARM_PFR1_GTIMER_MASK	0x000f0000
#define ARM_PFR1_VIRT_MASK	0x0000f000
#define ARM_PFR1_SEC_MASK	0x000000f0

/* Media and VFP Feature registers */
#define ARM_MVFR0_ROUNDING_MASK		0xf0000000
#define ARM_MVFR0_SHORTVEC_MASK		0x0f000000
#define ARM_MVFR0_SQRT_MASK		0x00f00000
#define ARM_MVFR0_DIVIDE_MASK		0x000f0000
#define ARM_MVFR0_EXCEPT_MASK		0x0000f000
#define ARM_MVFR0_DFLOAT_MASK		0x00000f00
#define ARM_MVFR0_SFLOAT_MASK		0x000000f0
#define ARM_MVFR0_ASIMD_MASK		0x0000000f
#define ARM_MVFR1_ASIMD_FMACS_MASK	0xf0000000
#define ARM_MVFR1_VFP_HPFP_MASK		0x0f000000
#define ARM_MVFR1_ASIMD_HPFP_MASK	0x00f00000
#define ARM_MVFR1_ASIMD_SPFP_MASK	0x000f0000
#define ARM_MVFR1_ASIMD_INT_MASK	0x0000f000
#define ARM_MVFR1_ASIMD_LDST_MASK	0x00000f00
#define ARM_MVFR1_D_NAN_MASK		0x000000f0
#define ARM_MVFR1_FTZ_MASK		0x0000000f

/* ARM3-specific coprocessor 15 registers */
#define ARM3_CP15_FLUSH		1
#define ARM3_CP15_CONTROL	2
#define ARM3_CP15_CACHEABLE	3
#define ARM3_CP15_UPDATEABLE	4
#define ARM3_CP15_DISRUPTIVE	5

/* ARM3 Control register bits */
#define ARM3_CTL_CACHE_ON	0x00000001
#define ARM3_CTL_SHARED		0x00000002
#define ARM3_CTL_MONITOR	0x00000004

/*
 * Post-ARM3 CP15 registers:
 *
 *	1	Control register
 *
 *	2	Translation Table Base
 *
 *	3	Domain Access Control
 *
 *	4	Reserved
 *
 *	5	Fault Status
 *
 *	6	Fault Address
 *
 *	7	Cache/write-buffer Control
 *
 *	8	TLB Control
 *
 *	9	Cache Lockdown
 *
 *	10	TLB Lockdown
 *
 *	11	Reserved
 *
 *	12	Reserved
 *
 *	13	Process ID (for FCSE)
 *
 *	14	Reserved
 *
 *	15	Implementation Dependent
 */

/* Some of the definitions below need cleaning up for V3/V4 architectures */

/* CPU control register (CP15 register 1) */
#define CPU_CONTROL_MMU_ENABLE	0x00000001 /* M: MMU/Protection unit enable */
#define CPU_CONTROL_AFLT_ENABLE	0x00000002 /* A: Alignment fault enable */
#define CPU_CONTROL_DC_ENABLE	0x00000004 /* C: IDC/DC enable */
#define CPU_CONTROL_WBUF_ENABLE 0x00000008 /* W: Write buffer enable */
#define CPU_CONTROL_32BP_ENABLE 0x00000010 /* P: 32-bit exception handlers */
#define CPU_CONTROL_32BD_ENABLE 0x00000020 /* D: 32-bit addressing */
#define CPU_CONTROL_LABT_ENABLE 0x00000040 /* L: Late abort enable */
#define CPU_CONTROL_BEND_ENABLE 0x00000080 /* B: Big-endian mode */
#define CPU_CONTROL_SYST_ENABLE 0x00000100 /* S: System protection bit */
#define CPU_CONTROL_ROM_ENABLE	0x00000200 /* R: ROM protection bit */
#define CPU_CONTROL_CPCLK	0x00000400 /* F: Implementation defined */
#define CPU_CONTROL_SWP_ENABLE	0x00000400 /* SW: SWP{B} perform normally. */
#define CPU_CONTROL_BPRD_ENABLE 0x00000800 /* Z: Branch prediction enable */
#define CPU_CONTROL_IC_ENABLE   0x00001000 /* I: IC enable */
#define CPU_CONTROL_VECRELOC	0x00002000 /* V: Vector relocation */
#define CPU_CONTROL_ROUNDROBIN	0x00004000 /* RR: Predictable replacement */
#define CPU_CONTROL_V4COMPAT	0x00008000 /* L4: ARMv4 compat LDR R15 etc */
#define CPU_CONTROL_HA_ENABLE	0x00020000 /* HA: Hardware Access flag enable */
#define CPU_CONTROL_WXN_ENABLE	0x00080000 /* WXN: Write Execute Never */
#define CPU_CONTROL_UWXN_ENABLE	0x00100000 /* UWXN: User Write eXecute Never */
#define CPU_CONTROL_FI_ENABLE	0x00200000 /* FI: Low interrupt latency */
#define CPU_CONTROL_UNAL_ENABLE	0x00400000 /* U: unaligned data access */
#define CPU_CONTROL_XP_ENABLE	0x00800000 /* XP: extended page table */
#define	CPU_CONTROL_V_ENABLE	0x01000000 /* VE: Interrupt vectors enable */
#define	CPU_CONTROL_EX_BEND	0x02000000 /* EE: exception endianness */
#define	CPU_CONTROL_NMFI	0x08000000 /* NMFI: Non maskable FIQ */
#define	CPU_CONTROL_TR_ENABLE	0x10000000 /* TRE: */
#define	CPU_CONTROL_AF_ENABLE	0x20000000 /* AFE: Access flag enable */
#define	CPU_CONTROL_TE_ENABLE	0x40000000 /* TE: Thumb Exception enable */

#define CPU_CONTROL_IDC_ENABLE	CPU_CONTROL_DC_ENABLE

/* ARMv6/ARMv7 Co-Processor Access Control Register (CP15, 0, c1, c0, 2) */
#define	CPACR_V7_ASEDIS		0x80000000 /* Disable Advanced SIMD Ext. */
#define	CPACR_V7_D32DIS		0x40000000 /* Disable VFP regs 15-31 */
#define	CPACR_CPn(n)		(3 << (2*n))
#define	CPACR_NOACCESS		0 /* reset value */
#define	CPACR_PRIVED		1 /* Privileged mode access */
#define	CPACR_RESERVED		2
#define	CPACR_ALL		3 /* Privileged and User mode access */

/* ARMv6/ARMv7 Non-Secure Access Control Register (CP15, 0, c1, c1, 2) */
#define NSACR_SMP		0x00040000 /* ACTRL.SMP is writeable (!A8) */
#define NSACR_L2ERR		0x00020000 /* L2ECTRL is writeable (!A8) */
#define NSACR_ASEDIS		0x00008000 /* Deny Advanced SIMD Ext. */
#define NSACR_D32DIS		0x00004000 /* Deny VFP regs 15-31 */
#define NSACR_CPn(n)		(1 << (n)) /* NonSecure access allowed */

/* ARM11x6 Auxiliary Control Register (CP15 register 1, opcode2 1) */
#define	ARM11X6_AUXCTL_RS	0x00000001 /* return stack */
#define	ARM11X6_AUXCTL_DB	0x00000002 /* dynamic branch prediction */
#define	ARM11X6_AUXCTL_SB	0x00000004 /* static branch prediction */
#define	ARM11X6_AUXCTL_TR	0x00000008 /* MicroTLB replacement strat. */
#define	ARM11X6_AUXCTL_EX	0x00000010 /* exclusive L1/L2 cache */
#define	ARM11X6_AUXCTL_RA	0x00000020 /* clean entire cache disable */
#define	ARM11X6_AUXCTL_RV	0x00000040 /* block transfer cache disable */
#define	ARM11X6_AUXCTL_CZ	0x00000080 /* restrict cache size */

/* ARM1136 Auxiliary Control Register (CP15 register 1, opcode2 1) */
#define ARM1136_AUXCTL_PFI	0x80000000 /* PFI: partial FI mode. */
					   /* This is an undocumented flag
					    * used to work around a cache bug
					    * in r0 steppings. See errata
					    * 364296.
					    */
/* ARM1176 Auxiliary Control Register (CP15 register 1, opcode2 1) */
#define	ARM1176_AUXCTL_PHD	0x10000000 /* inst. prefetch halting disable */
#define	ARM1176_AUXCTL_BFD	0x20000000 /* branch folding disable */
#define	ARM1176_AUXCTL_FSD	0x40000000 /* force speculative ops disable */
#define	ARM1176_AUXCTL_FIO	0x80000000 /* low intr latency override */

/* XScale Auxiliary Control Register (CP15 register 1, opcode2 1) */
#define	XSCALE_AUXCTL_K		0x00000001 /* dis. write buffer coalescing */
#define	XSCALE_AUXCTL_P		0x00000002 /* ECC protect page table access */
#define	XSCALE_AUXCTL_MD_WB_RA	0x00000000 /* mini-D$ wb, read-allocate */
#define	XSCALE_AUXCTL_MD_WB_RWA	0x00000010 /* mini-D$ wb, read/write-allocate */
#define	XSCALE_AUXCTL_MD_WT	0x00000020 /* mini-D$ wt, read-allocate */
#define	XSCALE_AUXCTL_MD_MASK	0x00000030

/* ARM11 MPCore Auxiliary Control Register (CP15 register 1, opcode2 1) */
#define	MPCORE_AUXCTL_RS	0x00000001 /* return stack */
#define	MPCORE_AUXCTL_DB	0x00000002 /* dynamic branch prediction */
#define	MPCORE_AUXCTL_SB	0x00000004 /* static branch prediction */
#define	MPCORE_AUXCTL_F 	0x00000008 /* instruction folding enable */
#define	MPCORE_AUXCTL_EX	0x00000010 /* exclusive L1/L2 cache */
#define	MPCORE_AUXCTL_SA	0x00000020 /* SMP/AMP */

/* Marvell PJ4B Auxiliary Control Register (CP15.0.R1.c0.1) */
#define PJ4B_AUXCTL_FW		__BIT(0)   /* Cache and TLB updates broadcast */
#define PJ4B_AUXCTL_SMPNAMP	__BIT(6)   /* 0 = AMP, 1 = SMP */
#define PJ4B_AUXCTL_L1PARITY	__BIT(9)   /* L1 parity checking */

/* Marvell PJ4B Auxialiary Function Modes Control 0 (CP15.1.R15.c2.0) */
#define PJ4B_AUXFMC0_L2EN	__BIT(0)  /* Tightly-Coupled L2 cache enable */
#define PJ4B_AUXFMC0_SMPNAMP	__BIT(1)  /* 0 = AMP, 1 = SMP */
#define PJ4B_AUXFMC0_L1PARITY	__BIT(2)  /* alias of PJ4B_AUXCTL_L1PARITY */
#define PJ4B_AUXFMC0_DCSLFD	__BIT(2)  /* Disable DC Speculative linefill */
#define PJ4B_AUXFMC0_FW		__BIT(8)  /* alias of PJ4B_AUXCTL_FW*/

/* Cortex-A5 Auxiliary Control Register (CP15 register 1, opcode 1) */
#define	CORTEXA5_ACTLR_FW	__BIT(0)
#define	CORTEXA5_ACTLR_SMP	__BIT(6)  /* Inner Cache Shared is cacheable */
#define	CORTEXA5_ACTLR_EXCL	__BIT(7)  /* Exclusive L1/L2 cache control */

/* Cortex-A7 Auxiliary Control Register (CP15 register 1, opcode 1) */
#define	CORTEXA7_ACTLR_L1ALIAS	__BIT(0)  /* Enables L1 cache alias checks */
#define	CORTEXA7_ACTLR_L2EN	__BIT(1)  /* Enables L2 cache */
#define	CORTEXA7_ACTLR_SMP	__BIT(6)  /* SMP */

/* Cortex-A8 Auxiliary Control Register (CP15 register 1, opcode 1) */
#define	CORTEXA8_ACTLR_L1ALIAS	__BIT(0)  /* Enables L1 cache alias checks */
#define	CORTEXA8_ACTLR_L2EN	__BIT(1)  /* Enables L2 cache */

/* Cortex-A9 Auxiliary Control Register (CP15 register 1, opcode 1) */
#define	CORTEXA9_AUXCTL_FW	0x00000001 /* Cache and TLB updates broadcast */
#define	CORTEXA9_AUXCTL_L2PE	0x00000002 /* Prefetch hint enable */
#define	CORTEXA9_AUXCTL_L1PE	0x00000004 /* Data prefetch hint enable */
#define	CORTEXA9_AUXCTL_WR_ZERO	0x00000008 /* Ena. write full line of 0s mode */
#define	CORTEXA9_AUXCTL_SMP	0x00000040 /* Coherency is active */
#define	CORTEXA9_AUXCTL_EXCL	0x00000080 /* Exclusive cache bit */
#define	CORTEXA9_AUXCTL_ONEWAY	0x00000100 /* Allocate in on cache way only */
#define	CORTEXA9_AUXCTL_PARITY	0x00000200 /* Support parity checking */

/* Cortex-A15 Auxiliary Control Register (CP15 register 1, opcode 1) */
#define	CORTEXA15_ACTLR_BTB	__BIT(0)  /* Cache and TLB updates broadcast */
#define	CORTEXA15_ACTLR_SMP	__BIT(6)  /* SMP */
#define	CORTEXA15_ACTLR_IOBEU	__BIT(15) /* In order issue in Branch Exec Unit */
#define	CORTEXA15_ACTLR_SDEH	__BIT(31) /* snoop-delayed exclusive handling */

/* Cortex-A17 Auxiliary Control Register (CP15 register 1, opcode 1) */
#define	CORTEXA17_ACTLR_SMP	__BIT(6)  /* SMP */
#define	CORTEXA17_ACTLR_ASSE	__BIT(3)  /* ACE STREX Signaling Enable */
#define	CORTEXA17_ACTLR_L2PF	__BIT(2)  /* Enable L2 prefetch */
#define	CORTEXA17_ACTLR_L1PF	__BIT(1)  /* Enable L1 prefetch */

/* Marvell Feroceon Extra Features Register (CP15 register 1, opcode2 0) */
#define FC_DCACHE_REPL_LOCK	0x80000000 /* Replace DCache Lock */
#define FC_DCACHE_STREAM_EN	0x20000000 /* DCache Streaming Switch */
#define FC_WR_ALLOC_EN		0x10000000 /* Enable Write Allocate */
#define FC_L2_PREF_DIS		0x01000000 /* L2 Cache Prefetch Disable */
#define FC_L2_INV_EVICT_LINE	0x00800000 /* L2 Invalidates Uncorrectable Error Line Eviction */
#define FC_L2CACHE_EN		0x00400000 /* L2 enable */
#define FC_ICACHE_REPL_LOCK	0x00080000 /* Replace ICache Lock */
#define FC_GLOB_HIST_REG_EN	0x00040000 /* Branch Global History Register Enable */
#define FC_BRANCH_TARG_BUF_DIS	0x00020000 /* Branch Target Buffer Disable */
#define FC_L1_PAR_ERR_EN	0x00010000 /* L1 Parity Error Enable */

/* Cache type register definitions 0 */
#define	CPU_CT_FORMAT(x)	(((x) >> 29) & 0x7)	/* reg format */
#define	CPU_CT_ISIZE(x)		((x) & 0xfff)		/* I$ info */
#define	CPU_CT_DSIZE(x)		(((x) >> 12) & 0xfff)	/* D$ info */
#define	CPU_CT_S		(1U << 24)		/* split cache */
#define	CPU_CT_CTYPE(x)		(((x) >> 25) & 0xf)	/* cache type */

#define	CPU_CT_CTYPE_WT		0	/* write-through */
#define	CPU_CT_CTYPE_WB1	1	/* write-back, clean w/ read */
#define	CPU_CT_CTYPE_WB2	2	/* w/b, clean w/ cp15,7 */
#define	CPU_CT_CTYPE_WB6	6	/* w/b, cp15,7, lockdown fmt A */
#define	CPU_CT_CTYPE_WB7	7	/* w/b, cp15,7, lockdown fmt B */
#define	CPU_CT_CTYPE_WB14	14	/* w/b, cp15,7, lockdown fmt C */

#define	CPU_CT_xSIZE_LEN(x)	((x) & 0x3)		/* line size */
#define	CPU_CT_xSIZE_M		(1U << 2)		/* multiplier */
#define	CPU_CT_xSIZE_ASSOC(x)	(((x) >> 3) & 0x7)	/* associativity */
#define	CPU_CT_xSIZE_SIZE(x)	(((x) >> 6) & 0x7)	/* size */
#define	CPU_CT_xSIZE_P		(1U << 11)		/* need to page-color */

/* format 4 definitions */
#define	CPU_CT4_ILINE(x)	((x) & 0xf)		/* I$ line size */
#define	CPU_CT4_DLINE(x)	(((x) >> 16) & 0xf)	/* D$ line size */
#define	CPU_CT4_L1IPOLICY(x)	(((x) >> 14) & 0x3)	/* I$ policy */
#define	CPU_CT4_L1_AIVIVT	1			/* ASID tagged VIVT */
#define	CPU_CT4_L1_VIPT		2			/* VIPT */
#define	CPU_CT4_L1_PIPT		3			/* PIPT */
#define	CPU_CT4_ERG(x)		(((x) >> 20) & 0xf)	/* Cache WriteBack Granule */
#define	CPU_CT4_CWG(x)		(((x) >> 24) & 0xf)	/* Exclusive Resv. Granule */

/* Cache size identifaction register definitions 1, Rd, c0, c0, 0 */
#define	CPU_CSID_CTYPE_WT	0x80000000	/* write-through avail */
#define	CPU_CSID_CTYPE_WB	0x40000000	/* write-back avail */
#define	CPU_CSID_CTYPE_RA	0x20000000	/* read-allocation avail */
#define	CPU_CSID_CTYPE_WA	0x10000000	/* write-allocation avail */
#define	CPU_CSID_NUMSETS(x)	(((x) >> 13) & 0x7fff)
#define	CPU_CSID_ASSOC(x)	(((x) >> 3) & 0x1ff)
#define	CPU_CSID_LEN(x)		((x) & 0x07)

/* Cache size selection register definitions 2, Rd, c0, c0, 0 */
#define	CPU_CSSR_L2		0x00000002
#define	CPU_CSSR_L1		0x00000000
#define	CPU_CSSR_InD		0x00000001

/* Fault status register definitions */

#define FAULT_TYPE_MASK 0x0f
#define FAULT_USER      0x10

#define FAULT_WRTBUF_0  0x00 /* Vector Exception */
#define FAULT_WRTBUF_1  0x02 /* Terminal Exception */
#define FAULT_BUSERR_0  0x04 /* External Abort on Linefetch -- Section */
#define FAULT_BUSERR_1  0x06 /* External Abort on Linefetch -- Page */
#define FAULT_BUSERR_2  0x08 /* External Abort on Non-linefetch -- Section */
#define FAULT_BUSERR_3  0x0a /* External Abort on Non-linefetch -- Page */
#define FAULT_BUSTRNL1  0x0c /* External abort on Translation -- Level 1 */
#define FAULT_BUSTRNL2  0x0e /* External abort on Translation -- Level 2 */
#define FAULT_ALIGN_0   0x01 /* Alignment */
#define FAULT_ALIGN_1   0x03 /* Alignment */
#define FAULT_TRANS_S   0x05 /* Translation -- Section */
#define FAULT_TRANS_P   0x07 /* Translation -- Page */
#define FAULT_DOMAIN_S  0x09 /* Domain -- Section */
#define FAULT_DOMAIN_P  0x0b /* Domain -- Page */
#define FAULT_PERM_S    0x0d /* Permission -- Section */
#define FAULT_PERM_P    0x0f /* Permission -- Page */

#define FAULT_LPAE	0x0200	/* (SW) used long descriptors */
#define FAULT_IMPRECISE	0x0400	/* Imprecise exception (XSCALE) */
#define FAULT_WRITE	0x0800	/* fault was due to write (ARMv6+) */
#define FAULT_EXT	0x1000	/* fault was due to external abort (ARMv6+) */
#define FAULT_CM	0x2000	/* fault was due to cache maintenance (ARMv7+) */

/*
 * Address of the vector page, low and high versions.
 */
#define	ARM_VECTORS_LOW		0x00000000U
#define	ARM_VECTORS_HIGH	0xffff0000U

/*
 * ARM Instructions
 *
 *       3 3 2 2 2
 *       1 0 9 8 7                                                     0
 *      +-------+-------------------------------------------------------+
 *      | cond  |              instruction dependent                    |
 *      |c c c c|                                                       |
 *      +-------+-------------------------------------------------------+
 */

#define INSN_SIZE		4		/* Always 4 bytes */
#define INSN_COND_MASK		0xf0000000	/* Condition mask */
#define INSN_COND_EQ		0		/* Z == 1 */
#define INSN_COND_NE		1		/* Z == 0 */
#define INSN_COND_CS		2		/* C == 1 */
#define INSN_COND_CC		3		/* C == 0 */
#define INSN_COND_MI		4		/* N == 1 */
#define INSN_COND_PL		5		/* N == 0 */
#define INSN_COND_VS		6		/* V == 1 */
#define INSN_COND_VC		7		/* V == 0 */
#define INSN_COND_HI		8		/* C == 1 && Z == 0 */
#define INSN_COND_LS		9		/* C == 0 || Z == 1 */
#define INSN_COND_GE		10		/* N == V */
#define INSN_COND_LT		11		/* N != V */
#define INSN_COND_GT		12		/* Z == 0 && N == V */
#define INSN_COND_LE		13		/* Z == 1 || N != V */
#define INSN_COND_AL		14		/* Always condition */

#define THUMB_INSN_SIZE		2		/* Some are 4 bytes.  */

/*
 * Defines and such for arm11 Performance Monitor Counters (p15, c15, c12, 0)
 */
#define ARM11_PMCCTL_E		__BIT(0)	/* enable all three counters */
#define ARM11_PMCCTL_P		__BIT(1)	/* reset both Count Registers to zero */
#define ARM11_PMCCTL_C		__BIT(2)	/* reset the Cycle Counter Register to zero */
#define ARM11_PMCCTL_D		__BIT(3)	/* cycle count divide by 64 */
#define ARM11_PMCCTL_EC0	__BIT(4)	/* Enable Counter Register 0 interrupt */
#define ARM11_PMCCTL_EC1	__BIT(5)	/* Enable Counter Register 1 interrupt */
#define ARM11_PMCCTL_ECC	__BIT(6)	/* Enable Cycle Counter interrupt */
#define ARM11_PMCCTL_SBZa	__BIT(7)	/* UNP/SBZ */
#define ARM11_PMCCTL_CR0	__BIT(8)	/* Count Register 0 overflow flag */
#define ARM11_PMCCTL_CR1	__BIT(9)	/* Count Register 1 overflow flag */
#define ARM11_PMCCTL_CCR	__BIT(10)	/* Cycle Count Register overflow flag */
#define ARM11_PMCCTL_X		__BIT(11)	/* Enable Export of the events to the event bus */
#define ARM11_PMCCTL_EVT1	__BITS(19,12)	/* source of events for Count Register 1 */
#define ARM11_PMCCTL_EVT0	__BITS(27,20)	/* source of events for Count Register 0 */
#define ARM11_PMCCTL_SBZb	__BITS(31,28)	/* UNP/SBZ */
#define ARM11_PMCCTL_SBZ	\
		(ARM11_PMCCTL_SBZa | ARM11_PMCCTL_SBZb)

#define	ARM11_PMCEVT_ICACHE_MISS	0	/* Instruction Cache Miss */
#define	ARM11_PMCEVT_ISTREAM_STALL	1	/* Instruction Stream Stall */
#define	ARM11_PMCEVT_IUTLB_MISS		2	/* Instruction uTLB Miss */
#define	ARM11_PMCEVT_DUTLB_MISS		3	/* Data uTLB Miss */
#define	ARM11_PMCEVT_BRANCH		4	/* Branch Inst. Executed */
#define	ARM11_PMCEVT_BRANCH_MISS	6	/* Branch mispredicted */
#define	ARM11_PMCEVT_INST_EXEC		7	/* Instruction Executed */
#define	ARM11_PMCEVT_DCACHE_ACCESS0	9	/* Data Cache Access */
#define	ARM11_PMCEVT_DCACHE_ACCESS1	10	/* Data Cache Access */
#define	ARM11_PMCEVT_DCACHE_MISS	11	/* Data Cache Miss */
#define	ARM11_PMCEVT_DCACHE_WRITEBACK	12	/* Data Cache Writeback */
#define	ARM11_PMCEVT_PC_CHANGE		13	/* Software PC change */
#define	ARM11_PMCEVT_TLB_MISS		15	/* Main TLB Miss */
#define	ARM11_PMCEVT_DATA_ACCESS	16	/* non-cached data access */
#define	ARM11_PMCEVT_LSU_STALL		17	/* Load/Store Unit stall */
#define	ARM11_PMCEVT_WBUF_DRAIN		18	/* Write buffer drained */
#define	ARM11_PMCEVT_ETMEXTOUT0		32	/* ETMEXTOUT[0] asserted */
#define	ARM11_PMCEVT_ETMEXTOUT1		33	/* ETMEXTOUT[1] asserted */
#define	ARM11_PMCEVT_ETMEXTOUT		34	/* ETMEXTOUT[0 & 1] */
#define	ARM11_PMCEVT_CALL_EXEC		35	/* Procedure call executed */
#define	ARM11_PMCEVT_RETURN_EXEC	36	/* Return executed */
#define	ARM11_PMCEVT_RETURN_HIT		37	/* return address predicted */
#define	ARM11_PMCEVT_RETURN_MISS	38	/* return addr. mispredicted */
#define	ARM11_PMCEVT_CYCLE		255	/* Increment each cycle */

/* ARMv7 PMCR, Performance Monitor Control Register */
#define	PMCR_N			__BITS(15,11)
#define	PMCR_D			__BIT(3)
#define	PMCR_E			__BIT(0)

/* ARMv7 INTEN{SET,CLR}, Performance Monitors Interrupt Enable Set register */
#define	PMINTEN_C		__BIT(31)
#define	PMINTEN_P		__BITS(30,0)
#define	PMCNTEN_C		__BIT(31)
#define	PMCNTEN_P		__BITS(30,0)

/* ARMv7 PMOVSR, Performance Monitors Overflow Flag Status Register */
#define	PMOVS_C			__BIT(31)
#define	PMOVS_P			__BITS(30,0)

/* ARMv7 PMXEVTYPER, Performance Monitors Event Type Select Register */
#define	PMEVTYPER_P		__BIT(31)
#define	PMEVTYPER_U		__BIT(30)
#define	PMEVTYPER_EVTCOUNT	__BITS(7,0)

/* Defines for ARM CORTEX performance counters */
#define CORTEX_CNTENS_C __BIT(31)	/* Enables the cycle counter */
#define CORTEX_CNTENC_C __BIT(31)	/* Disables the cycle counter */
#define CORTEX_CNTOFL_C __BIT(31)	/* Cycle counter overflow flag */

/* Defines for ARM Cortex A7/A15 L2CTRL */
#define L2CTRL_NUMCPU	__BITS(25,24)	// numcpus - 1
#define L2CTRL_ICPRES	__BIT(23)	// Interrupt Controller is present

/* Translation Table Base Register */
#define	TTBR_C			__BIT(0)	/* without MPE */
#define	TTBR_S			__BIT(1)
#define	TTBR_IMP		__BIT(2)
#define	TTBR_RGN_MASK		__BITS(4,3)
#define	 TTBR_RGN_NC		__SHIFTIN(0, TTBR_RGN_MASK)
#define	 TTBR_RGN_WBWA		__SHIFTIN(1, TTBR_RGN_MASK)
#define	 TTBR_RGN_WT		__SHIFTIN(2, TTBR_RGN_MASK)
#define	 TTBR_RGN_WBNWA		__SHIFTIN(3, TTBR_RGN_MASK)
#define	TTBR_NOS		__BIT(5)
#define	TTBR_IRGN_MASK		(__BIT(6) | __BIT(0))
#define	 TTBR_IRGN_NC		0
#define	 TTBR_IRGN_WBWA		__BIT(6)
#define	 TTBR_IRGN_WT		__BIT(0)
#define	 TTBR_IRGN_WBNWA	(__BIT(0) | __BIT(6))

/* Translate Table Base Control Register */
#define TTBCR_S_EAE	__BIT(31)	// Extended Address Extension
#define TTBCR_S_PD1	__BIT(5)	// Don't use TTBR1
#define TTBCR_S_PD0	__BIT(4)	// Don't use TTBR0
#define TTBCR_S_N	__BITS(2,0)	// Width of base address in TTB0

#define TTBCR_L_EAE	__BIT(31)	// Extended Address Extension
#define TTBCR_L_SH1	__BITS(29,28)	// TTBR1 Shareability
#define TTBCR_L_ORGN1	__BITS(27,26)	// TTBR1 Outer cacheability
#define TTBCR_L_IRGN1	__BITS(25,24)	// TTBR1 inner cacheability
#define TTBCR_L_EPD1	__BIT(23)	// Don't use TTBR1
#define TTBCR_L_A1	__BIT(22)	// ASID is in TTBR1
#define TTBCR_L_T1SZ	__BITS(18,16)	// TTBR1 size offset
#define TTBCR_L_SH0	__BITS(13,12)	// TTBR0 Shareability
#define TTBCR_L_ORGN0	__BITS(11,10)	// TTBR0 Outer cacheability
#define TTBCR_L_IRGN0	__BITS(9,8)	// TTBR0 inner cacheability
#define TTBCR_L_EPD0	__BIT(7)	// Don't use TTBR0
#define TTBCR_L_T0SZ	__BITS(2,0)	// TTBR0 size offset

#define NMRR_ORn(n)	__BITS(17+2*(n),16+2*(n)) // Outer Cacheable mappings
#define NMRR_IRn(n)	__BITS(1+2*(n),0+2*(n)) // Inner Cacheable mappings
#define NMRR_NC		0		// non-cacheable
#define NMRR_WBWA	1		// write-back write-allocate
#define NMRR_WT		2		// write-through
#define NMRR_WB		3		// write-back
#define PRRR_NOSn(n)	__BITS(24+(n))	// Memory region is Inner Shareable only
#define PRRR_NS1	__BIT(19)	// Normal Shareable S=1 is Shareable
#define PRRR_NS0	__BIT(18)	// Normal Shareable S=0 is Shareable
#define PRRR_DS1	__BIT(17)	// Device Shareable S=1 is Shareable
#define PRRR_DS0	__BIT(16)	// Device Shareable S=0 is Shareable
#define PRRR_TRn(n)	__BITS(1+2*(n),0+2*(n))
#define PRRR_TR_STRONG	0		// Strongly Ordered
#define PRRR_TR_DEVICE	1		// Device
#define PRRR_TR_NORMAL	2		// Normal Memory
					// 3 is reserved

/* ARMv7 MPIDR, Multiprocessor Affinity Register generic format  */
#define MPIDR_MP		__BIT(31)	/* 1 = Have MP Extension */
#define MPIDR_U			__BIT(30)	/* 1 = Uni-Processor System */
#define MPIDR_MT		__BIT(24)	/* 1 = SMT(AFF0 is logical) */
#define MPIDR_AFF2		__BITS(23,16)	/* Affinity Level 2 */
#define MPIDR_AFF1		__BITS(15,8)	/* Affinity Level 1 */
#define MPIDR_AFF0		__BITS(7,0)	/* Affinity Level 0 */

/* MPIDR implementation of ARM Cortex A9: SMT and AFF2 is not used */
#define CORTEXA9_MPIDR_MP	MPIDR_MP
#define CORTEXA9_MPIDR_U	MPIDR_U
#define	CORTEXA9_MPIDR_CLID	__BITS(11,8)	/* AFF1 = cluster id */
#define CORTEXA9_MPIDR_CPUID	__BITS(0,1)	/* AFF0 = physical core id */

/* MPIDR implementation of Marvell PJ4B-MP: AFF2 is not used */
#define PJ4B_MPIDR_MP		MPIDR_MP
#define PJ4B_MPIDR_U		MPIDR_U
#define PJ4B_MPIDR_MT		MPIDR_MT	/* 1 = SMT(AFF0 is logical) */
#define PJ4B_MPIDR_CLID		__BITS(11,8)	/* AFF1 = cluster id */
#define PJ4B_MPIDR_CPUID	__BITS(0,3)	/* AFF0 = core id */

/* Defines for ARM Generic Timer */
#define CNTCTL_ISTATUS		__BIT(2)	// Interrupt is pending
#define CNTCTL_IMASK		__BIT(1)	// Mask Interrupt
#define CNTCTL_ENABLE		__BIT(0)	// Timer Enabled

#define CNTKCTL_PL0PTEN		__BIT(9)	/* PL0 Physical Timer Enable */
#define CNTKCTL_PL0VTEN		__BIT(8)	/* PL0 Virtual Timer Enable */
#define CNTKCTL_EVNTI		__BITS(7,4)	/* CNTVCT Event Bit Select */
#define CNTKCTL_EVNTDIR		__BIT(3)	/* CNTVCT Event Dir (1->0) */
#define CNTKCTL_EVNTEN		__BIT(2)	/* CNTVCT Event Enable */
#define CNTKCTL_PL0VCTEN	__BIT(1)	/* PL0 Virtual Counter Enable */
#define CNTKCTL_PL0PCTEN	__BIT(0)	/* PL0 Physical Counter Enable */

/* CNCHCTL, Timer PL2 Control register, Virtualization Extensions */
#define CNTHCTL_EVNTI		__BITS(7,4)
#define CNTHCTL_EVNTDIR		__BIT(3)
#define CNTHCTL_EVNTEN		__BIT(2)
#define CNTHCTL_PL1PCEN		__BIT(1)
#define CNTHCTL_PL1PCTEN	__BIT(0)

#define ARM_A5_TLBDATA_DOM		__BITS(62,59)
#define ARM_A5_TLBDATA_AP		__BITS(58,56)
#define ARM_A5_TLBDATA_NS_WALK		__BIT(55)
#define ARM_A5_TLBDATA_NS_PAGE		__BIT(54)
#define ARM_A5_TLBDATA_XN		__BIT(53)
#define ARM_A5_TLBDATA_TEX		__BITS(52,50)
#define ARM_A5_TLBDATA_B		__BIT(49)
#define ARM_A5_TLBDATA_C		__BIT(48)
#define ARM_A5_TLBDATA_S		__BIT(47)
#define ARM_A5_TLBDATA_ASID		__BITS(46,39)
#define ARM_A5_TLBDATA_SIZE		__BITS(38,37)
#define ARM_A5_TLBDATA_SIZE_4KB		0
#define ARM_A5_TLBDATA_SIZE_16KB	1
#define ARM_A5_TLBDATA_SIZE_1MB		2
#define ARM_A5_TLBDATA_SIZE_16MB	3
#define ARM_A5_TLBDATA_VA		__BITS(36,22)
#define ARM_A5_TLBDATA_PA		__BITS(21,2)
#define ARM_A5_TLBDATA_nG		__BIT(1)
#define ARM_A5_TLBDATA_VALID		__BIT(0)

#define ARM_A7_TLBDATA2_S2_LEVEL	__BITS(85-64,84-64)
#define ARM_A7_TLBDATA2_S1_SIZE		__BITS(83-64,82-64)
#define ARM_A7_TLBDATA2_S1_SIZE_4KB	0
#define ARM_A7_TLBDATA2_S1_SIZE_64KB	1
#define ARM_A7_TLBDATA2_S1_SIZE_1MB	2
#define ARM_A7_TLBDATA2_S1_SIZE_16MB	3
#define ARM_A7_TLBDATA2_DOM		__BITS(81-64,78-64)
#define ARM_A7_TLBDATA2_IS		__BITS(77-64,76-64)
#define ARM_A7_TLBDATA2_IS_NC		0
#define ARM_A7_TLBDATA2_IS_WB_WA	1
#define ARM_A7_TLBDATA2_IS_WT		2
#define ARM_A7_TLBDATA2_IS_DSO		3
#define ARM_A7_TLBDATA2_S2OVR		__BIT(75-64)
#define ARM_A7_TLBDATA2_SDO_MT		__BITS(74-64,72-64)
#define ARM_A7_TLBDATA2_SDO_MT_D	2
#define ARM_A7_TLBDATA2_SDO_MT_SO	6
#define ARM_A7_TLBDATA2_OS		__BITS(75-64,74-64)
#define ARM_A7_TLBDATA2_OS_NC		0
#define ARM_A7_TLBDATA2_OS_WB_WA	1
#define ARM_A7_TLBDATA2_OS_WT		2
#define ARM_A7_TLBDATA2_OS_WB		3
#define ARM_A7_TLBDATA2_SH		__BITS(73-64,72-64)
#define ARM_A7_TLBDATA2_SH_NONE		0
#define ARM_A7_TLBDATA2_SH_UNUSED	1
#define ARM_A7_TLBDATA2_SH_OS		2
#define ARM_A7_TLBDATA2_SH_IS		3
#define ARM_A7_TLBDATA2_XN2		__BIT(71-64)
#define ARM_A7_TLBDATA2_XN1		__BIT(70-64)
#define ARM_A7_TLBDATA2_PXN		__BIT(69-64)

#define ARM_A7_TLBDATA12_PA		__BITS(68-32,41-32)

#define ARM_A7_TLBDATA1_NS		__BIT(40-32)
#define ARM_A7_TLBDATA1_HAP		__BITS(39-32,38-32)
#define ARM_A7_TLBDATA1_AP		__BITS(37-32,35-32)
#define ARM_A7_TLBDATA1_nG		__BIT(34-32)

#define ARM_A7_TLBDATA01_ASID		__BITS(33,26)

#define ARM_A7_TLBDATA0_VMID		__BITS(25,18)
#define ARM_A7_TLBDATA0_VA		__BITS(17,5)
#define ARM_A7_TLBDATA0_NS_WALK		__BIT(4)
#define ARM_A7_TLBDATA0_SIZE		__BITS(3,1)
#define ARM_A7_TLBDATA0_SIZE_V7_4KB	0
#define ARM_A7_TLBDATA0_SIZE_LPAE_4KB	1
#define ARM_A7_TLBDATA0_SIZE_V7_64KB	2
#define ARM_A7_TLBDATA0_SIZE_LPAE_64KB	3
#define ARM_A7_TLBDATA0_SIZE_V7_1MB	4
#define ARM_A7_TLBDATA0_SIZE_LPAE_2MB	5
#define ARM_A7_TLBDATA0_SIZE_V7_16MB	6
#define ARM_A7_TLBDATA0_SIZE_LPAE_1GB	7

#define ARM_TLBDATA_VALID		__BIT(0)

#define ARM_TLBDATAOP_WAY		__BIT(31)
#define ARM_A5_TLBDATAOP_INDEX		__BITS(5,0)
#define ARM_A7_TLBDATAOP_INDEX		__BITS(6,0)

#if !defined(__ASSEMBLER__) && defined(_KERNEL)
static inline bool
arm_cond_ok_p(uint32_t insn, uint32_t psr)
{
	const uint32_t __cond = __SHIFTOUT(insn, INSN_COND_MASK);

	bool __ok;
	const bool __z = (psr & PSR_Z_bit);
	const bool __n = (psr & PSR_N_bit);
	const bool __c = (psr & PSR_C_bit);
	const bool __v = (psr & PSR_V_bit);
	switch (__cond & ~1) {
	case INSN_COND_EQ:	// Z == 1
		__ok = __z;
		break;
	case INSN_COND_CS:	// C == 1
		__ok = __c;
		break;
	case INSN_COND_MI:	// N == 1
		__ok = __n;
		break;
	case INSN_COND_VS:	// V == 1
		__ok = __v;
		break;
	case INSN_COND_HI:	// C == 1 && Z == 0
		__ok = __c && !__z;
		break;
	case INSN_COND_GE:	// N == V
		__ok = __n == __v;
		break;
	case INSN_COND_GT:	// N == V && Z == 0
		__ok = __n == __v && !__z;
		break;
	default: /* INSN_COND_AL or unconditional */
		return true;
	}

	return (__cond & 1) ? !__ok : __ok;
}
#endif /* !__ASSEMBLER && _KERNEL */

#if !defined(__ASSEMBLER__) && !defined(_RUMPKERNEL)
#define	ARMREG_READ_INLINE(name, __insnstring)			\
static inline uint32_t armreg_##name##_read(void)		\
{								\
	uint32_t __rv;						\
	__asm __volatile("mrc " __insnstring : "=r"(__rv));	\
	return __rv;						\
}

#define	ARMREG_WRITE_INLINE(name, __insnstring)			\
static inline void armreg_##name##_write(uint32_t __val)	\
{								\
	__asm __volatile("mcr " __insnstring :: "r"(__val));	\
}

#define	ARMREG_READ_INLINE2(name, __insnstring)			\
static inline uint32_t armreg_##name##_read(void)		\
{								\
	uint32_t __rv;						\
	__asm __volatile(".fpu vfp");				\
	__asm __volatile(__insnstring : "=r"(__rv));		\
	return __rv;						\
}

#define	ARMREG_WRITE_INLINE2(name, __insnstring)		\
static inline void armreg_##name##_write(uint32_t __val)	\
{								\
	__asm __volatile(".fpu vfp");				\
	__asm __volatile(__insnstring :: "r"(__val));		\
}

#define	ARMREG_READ64_INLINE(name, __insnstring)		\
static inline uint64_t armreg_##name##_read(void)		\
{								\
	uint64_t __rv;						\
	__asm __volatile("mrrc " __insnstring : "=r"(__rv));	\
	return __rv;						\
}

#define	ARMREG_WRITE64_INLINE(name, __insnstring)		\
static inline void armreg_##name##_write(uint64_t __val)	\
{								\
	__asm __volatile("mcrr " __insnstring :: "r"(__val));	\
}

/* cp10 registers */
ARMREG_READ_INLINE2(fpsid, ".fpu vfp\n vmrs\t%0, fpsid") /* VFP System ID */
ARMREG_READ_INLINE2(fpscr, ".fpu vfp\n vmrs\t%0, fpscr") /* VFP Status/Control Register */
ARMREG_WRITE_INLINE2(fpscr, ".fpu vfp\n vmsr\tfpscr, %0") /* VFP Status/Control Register */
ARMREG_READ_INLINE2(mvfr1, ".fpu vfp\n vmrs\t%0, mvfr1") /* Media and VFP Feature Register 1 */
ARMREG_READ_INLINE2(mvfr0, ".fpu vfp\n vmrs\t%0, mvfr0") /* Media and VFP Feature Register 0 */
ARMREG_READ_INLINE2(fpexc, ".fpu vfp\n vmrs\t%0, fpexc") /* VFP Exception Register */
ARMREG_WRITE_INLINE2(fpexc, ".fpu vfp\n vmsr\tfpexc, %0") /* VFP Exception Register */
ARMREG_READ_INLINE2(fpinst, ".fpu vfp\n fmrx\t%0, fpinst") /* VFP Exception Instruction */
ARMREG_WRITE_INLINE2(fpinst, ".fpu vfp\n vmsr\tfpinst, %0") /* VFP Exception Instruction */
ARMREG_READ_INLINE2(fpinst2, ".fpu vfp\n fmrx\t%0, fpinst2") /* VFP Exception Instruction 2 */
ARMREG_WRITE_INLINE2(fpinst2, ".fpu vfp\n fmxr\tfpinst2, %0") /* VFP Exception Instruction 2 */

/* cp15 c0 registers */
ARMREG_READ_INLINE(midr, "p15,0,%0,c0,c0,0") /* Main ID Register */
ARMREG_READ_INLINE(ctr, "p15,0,%0,c0,c0,1") /* Cache Type Register */
ARMREG_READ_INLINE(tlbtr, "p15,0,%0,c0,c0,3") /* TLB Type Register */
ARMREG_READ_INLINE(mpidr, "p15,0,%0,c0,c0,5") /* Multiprocess Affinity Register */
ARMREG_READ_INLINE(revidr, "p15,0,%0,c0,c0,6") /* Revision ID Register */
ARMREG_READ_INLINE(pfr0, "p15,0,%0,c0,c1,0") /* Processor Feature Register 0 */
ARMREG_READ_INLINE(pfr1, "p15,0,%0,c0,c1,1") /* Processor Feature Register 1 */
ARMREG_READ_INLINE(mmfr0, "p15,0,%0,c0,c1,4") /* Memory Model Feature Register 0 */
ARMREG_READ_INLINE(mmfr1, "p15,0,%0,c0,c1,5") /* Memory Model Feature Register 1 */
ARMREG_READ_INLINE(mmfr2, "p15,0,%0,c0,c1,6") /* Memory Model Feature Register 2 */
ARMREG_READ_INLINE(mmfr3, "p15,0,%0,c0,c1,7") /* Memory Model Feature Register 3 */
ARMREG_READ_INLINE(isar0, "p15,0,%0,c0,c2,0") /* Instruction Set Attribute Register 0 */
ARMREG_READ_INLINE(isar1, "p15,0,%0,c0,c2,1") /* Instruction Set Attribute Register 1 */
ARMREG_READ_INLINE(isar2, "p15,0,%0,c0,c2,2") /* Instruction Set Attribute Register 2 */
ARMREG_READ_INLINE(isar3, "p15,0,%0,c0,c2,3") /* Instruction Set Attribute Register 3 */
ARMREG_READ_INLINE(isar4, "p15,0,%0,c0,c2,4") /* Instruction Set Attribute Register 4 */
ARMREG_READ_INLINE(isar5, "p15,0,%0,c0,c2,5") /* Instruction Set Attribute Register 5 */
ARMREG_READ_INLINE(ccsidr, "p15,1,%0,c0,c0,0") /* Cache Size ID Register */
ARMREG_READ_INLINE(clidr, "p15,1,%0,c0,c0,1") /* Cache Level ID Register */
ARMREG_READ_INLINE(csselr, "p15,2,%0,c0,c0,0") /* Cache Size Selection Register */
ARMREG_WRITE_INLINE(csselr, "p15,2,%0,c0,c0,0") /* Cache Size Selection Register */
/* cp15 c1 registers */
ARMREG_READ_INLINE(sctlr, "p15,0,%0,c1,c0,0") /* System Control Register */
ARMREG_WRITE_INLINE(sctlr, "p15,0,%0,c1,c0,0") /* System Control Register */
ARMREG_READ_INLINE(auxctl, "p15,0,%0,c1,c0,1") /* Auxiliary Control Register */
ARMREG_WRITE_INLINE(auxctl, "p15,0,%0,c1,c0,1") /* Auxiliary Control Register */
ARMREG_READ_INLINE(cpacr, "p15,0,%0,c1,c0,2") /* Co-Processor Access Control Register */
ARMREG_WRITE_INLINE(cpacr, "p15,0,%0,c1,c0,2") /* Co-Processor Access Control Register */
ARMREG_READ_INLINE(scr, "p15,0,%0,c1,c1,0") /* Secure Configuration Register */
ARMREG_READ_INLINE(nsacr, "p15,0,%0,c1,c1,2") /* Non-Secure Access Control Register */
/* cp15 c2 registers */
ARMREG_READ_INLINE(ttbr, "p15,0,%0,c2,c0,0") /* Translation Table Base Register 0 */
ARMREG_WRITE_INLINE(ttbr, "p15,0,%0,c2,c0,0") /* Translation Table Base Register 0 */
ARMREG_READ_INLINE(ttbr1, "p15,0,%0,c2,c0,1") /* Translation Table Base Register 1 */
ARMREG_WRITE_INLINE(ttbr1, "p15,0,%0,c2,c0,1") /* Translation Table Base Register 1 */
ARMREG_READ_INLINE(ttbcr, "p15,0,%0,c2,c0,2") /* Translation Table Base Register */
ARMREG_WRITE_INLINE(ttbcr, "p15,0,%0,c2,c0,2") /* Translation Table Base Register */
/* cp15 c3 registers */
ARMREG_READ_INLINE(dacr, "p15,0,%0,c3,c0,0") /* Domain Access Control Register */
ARMREG_WRITE_INLINE(dacr, "p15,0,%0,c3,c0,0") /* Domain Access Control Register */
/* cp15 c5 registers */
ARMREG_READ_INLINE(dfsr, "p15,0,%0,c5,c0,0") /* Data Fault Status Register */
ARMREG_READ_INLINE(ifsr, "p15,0,%0,c5,c0,1") /* Instruction Fault Status Register */
/* cp15 c6 registers */
ARMREG_READ_INLINE(dfar, "p15,0,%0,c6,c0,0") /* Data Fault Address Register */
ARMREG_READ_INLINE(ifar, "p15,0,%0,c6,c0,2") /* Instruction Fault Address Register */
/* cp15 c7 registers */
ARMREG_WRITE_INLINE(icialluis, "p15,0,%0,c7,c1,0") /* Instruction Inv All (IS) */
ARMREG_WRITE_INLINE(bpiallis, "p15,0,%0,c7,c1,6") /* Branch Predictor Invalidate All (IS) */
ARMREG_READ_INLINE(par, "p15,0,%0,c7,c4,0") /* Physical Address Register */
ARMREG_WRITE_INLINE(iciallu, "p15,0,%0,c7,c5,0") /* Instruction Invalidate All */
ARMREG_WRITE_INLINE(icimvau, "p15,0,%0,c7,c5,1") /* Instruction Invalidate MVA */
ARMREG_WRITE_INLINE(isb, "p15,0,%0,c7,c5,4") /* Instruction Synchronization Barrier */
ARMREG_WRITE_INLINE(bpiall, "p15,0,%0,c7,c5,6") /* Branch Predictor Invalidate All */
ARMREG_WRITE_INLINE(bpimva, "p15,0,%0,c7,c5,7") /* Branch Predictor invalidate by MVA */
ARMREG_WRITE_INLINE(dcimvac, "p15,0,%0,c7,c6,1") /* Data Invalidate MVA to PoC */
ARMREG_WRITE_INLINE(dcisw, "p15,0,%0,c7,c6,2") /* Data Invalidate Set/Way */
ARMREG_WRITE_INLINE(ats1cpr, "p15,0,%0,c7,c8,0") /* AddrTrans CurState PL1 Read */
ARMREG_WRITE_INLINE(ats1cpw, "p15,0,%0,c7,c8,1") /* AddrTrans CurState PL1 Write */
ARMREG_WRITE_INLINE(ats1cur, "p15,0,%0,c7,c8,2") /* AddrTrans CurState PL0 Read */
ARMREG_WRITE_INLINE(ats1cuw, "p15,0,%0,c7,c8,3") /* AddrTrans CurState PL0 Write */
ARMREG_WRITE_INLINE(dccmvac, "p15,0,%0,c7,c10,1") /* Data Clean MVA to PoC */
ARMREG_WRITE_INLINE(dccsw, "p15,0,%0,c7,c10,2") /* Data Clean Set/Way */
ARMREG_WRITE_INLINE(dsb, "p15,0,%0,c7,c10,4") /* Data Synchronization Barrier */
ARMREG_WRITE_INLINE(dmb, "p15,0,%0,c7,c10,5") /* Data Memory Barrier */
ARMREG_WRITE_INLINE(dccmvau, "p15,0,%0,c7,c11,1") /* Data Clean MVA to PoU */
ARMREG_WRITE_INLINE(dccimvac, "p15,0,%0,c7,c14,1") /* Data Clean&Inv MVA to PoC */
ARMREG_WRITE_INLINE(dccisw, "p15,0,%0,c7,c14,2") /* Data Clean&Inv Set/Way */
/* cp15 c8 registers */
ARMREG_WRITE_INLINE(tlbiallis, "p15,0,%0,c8,c3,0") /* Invalidate entire unified TLB, inner shareable */
ARMREG_WRITE_INLINE(tlbimvais, "p15,0,%0,c8,c3,1") /* Invalidate unified TLB by MVA, inner shareable */
ARMREG_WRITE_INLINE(tlbiasidis, "p15,0,%0,c8,c3,2") /* Invalidate unified TLB by ASID, inner shareable */
ARMREG_WRITE_INLINE(tlbimvaais, "p15,0,%0,c8,c3,3") /* Invalidate unified TLB by MVA, all ASID, inner shareable */
ARMREG_WRITE_INLINE(itlbiall, "p15,0,%0,c8,c5,0") /* Invalidate entire instruction TLB */
ARMREG_WRITE_INLINE(itlbimva, "p15,0,%0,c8,c5,1") /* Invalidate instruction TLB by MVA */
ARMREG_WRITE_INLINE(itlbiasid, "p15,0,%0,c8,c5,2") /* Invalidate instruction TLB by ASID */
ARMREG_WRITE_INLINE(dtlbiall, "p15,0,%0,c8,c6,0") /* Invalidate entire data TLB */
ARMREG_WRITE_INLINE(dtlbimva, "p15,0,%0,c8,c6,1") /* Invalidate data TLB by MVA */
ARMREG_WRITE_INLINE(dtlbiasid, "p15,0,%0,c8,c6,2") /* Invalidate data TLB by ASID */
ARMREG_WRITE_INLINE(tlbiall, "p15,0,%0,c8,c7,0") /* Invalidate entire unified TLB */
ARMREG_WRITE_INLINE(tlbimva, "p15,0,%0,c8,c7,1") /* Invalidate unified TLB by MVA */
ARMREG_WRITE_INLINE(tlbiasid, "p15,0,%0,c8,c7,2") /* Invalidate unified TLB by ASID */
ARMREG_WRITE_INLINE(tlbimvaa, "p15,0,%0,c8,c7,3") /* Invalidate unified TLB by MVA, all ASID */
/* cp15 c9 registers */
ARMREG_READ_INLINE(pmcr, "p15,0,%0,c9,c12,0") /* PMC Control Register */
ARMREG_WRITE_INLINE(pmcr, "p15,0,%0,c9,c12,0") /* PMC Control Register */
ARMREG_READ_INLINE(pmcntenset, "p15,0,%0,c9,c12,1") /* PMC Count Enable Set */
ARMREG_WRITE_INLINE(pmcntenset, "p15,0,%0,c9,c12,1") /* PMC Count Enable Set */
ARMREG_READ_INLINE(pmcntenclr, "p15,0,%0,c9,c12,2") /* PMC Count Enable Clear */
ARMREG_WRITE_INLINE(pmcntenclr, "p15,0,%0,c9,c12,2") /* PMC Count Enable Clear */
ARMREG_READ_INLINE(pmovsr, "p15,0,%0,c9,c12,3") /* PMC Overflow Flag Status */
ARMREG_WRITE_INLINE(pmovsr, "p15,0,%0,c9,c12,3") /* PMC Overflow Flag Status */
ARMREG_READ_INLINE(pmselr, "p15,0,%0,c9,c12,5") /* PMC Event Counter Selection */
ARMREG_WRITE_INLINE(pmselr, "p15,0,%0,c9,c12,5") /* PMC Event Counter Selection */
ARMREG_READ_INLINE(pmceid0, "p15,0,%0,c9,c12,6") /* PMC Event ID 0 */
ARMREG_READ_INLINE(pmceid1, "p15,0,%0,c9,c12,7") /* PMC Event ID 1 */
ARMREG_READ_INLINE(pmccntr, "p15,0,%0,c9,c13,0") /* PMC Cycle Counter */
ARMREG_WRITE_INLINE(pmccntr, "p15,0,%0,c9,c13,0") /* PMC Cycle Counter */
ARMREG_READ_INLINE(pmxevtyper, "p15,0,%0,c9,c13,1") /* PMC Event Type Select */
ARMREG_WRITE_INLINE(pmxevtyper, "p15,0,%0,c9,c13,1") /* PMC Event Type Select */
ARMREG_READ_INLINE(pmxevcntr, "p15,0,%0,c9,c13,2") /* PMC Event Count */
ARMREG_WRITE_INLINE(pmxevcntr, "p15,0,%0,c9,c13,2") /* PMC Event Count */
ARMREG_READ_INLINE(pmuserenr, "p15,0,%0,c9,c14,0") /* PMC User Enable */
ARMREG_WRITE_INLINE(pmuserenr, "p15,0,%0,c9,c14,0") /* PMC User Enable */
ARMREG_READ_INLINE(pmintenset, "p15,0,%0,c9,c14,1") /* PMC Interrupt Enable Set */
ARMREG_WRITE_INLINE(pmintenset, "p15,0,%0,c9,c14,1") /* PMC Interrupt Enable Set */
ARMREG_READ_INLINE(pmintenclr, "p15,0,%0,c9,c14,2") /* PMC Interrupt Enable Clear */
ARMREG_WRITE_INLINE(pmintenclr, "p15,0,%0,c9,c14,2") /* PMC Interrupt Enable Clear */
ARMREG_READ_INLINE(l2ctrl, "p15,1,%0,c9,c0,2") /* A7/A15 L2 Control Register */
/* cp10 c10 registers */
ARMREG_READ_INLINE(prrr, "p15,0,%0,c10,c2,0") /* Primary Region Remap Register */
ARMREG_WRITE_INLINE(prrr, "p15,0,%0,c10,c2,0") /* Primary Region Remap Register */
ARMREG_READ_INLINE(nmrr, "p15,0,%0,c10,c2,1") /* Normal Memory Remap Register */
ARMREG_WRITE_INLINE(nmrr, "p15,0,%0,c10,c2,1") /* Normal Memory Remap Register */
/* cp15 c13 registers */
ARMREG_READ_INLINE(contextidr, "p15,0,%0,c13,c0,1") /* Context ID Register */
ARMREG_WRITE_INLINE(contextidr, "p15,0,%0,c13,c0,1") /* Context ID Register */
ARMREG_READ_INLINE(tpidrurw, "p15,0,%0,c13,c0,2") /* User read-write Thread ID Register */
ARMREG_WRITE_INLINE(tpidrurw, "p15,0,%0,c13,c0,2") /* User read-write Thread ID Register */
ARMREG_READ_INLINE(tpidruro, "p15,0,%0,c13,c0,3") /* User read-only Thread ID Register */
ARMREG_WRITE_INLINE(tpidruro, "p15,0,%0,c13,c0,3") /* User read-only Thread ID Register */
ARMREG_READ_INLINE(tpidrprw, "p15,0,%0,c13,c0,4") /* PL1 only Thread ID Register */
ARMREG_WRITE_INLINE(tpidrprw, "p15,0,%0,c13,c0,4") /* PL1 only Thread ID Register */
/* cp14 c12 registers */
ARMREG_READ_INLINE(vbar, "p15,0,%0,c12,c0,0")	/* Vector Base Address Register */
ARMREG_WRITE_INLINE(vbar, "p15,0,%0,c12,c0,0")	/* Vector Base Address Register */
/* cp15 c14 registers */
/* cp15 Global Timer Registers */
ARMREG_READ_INLINE(cnt_frq, "p15,0,%0,c14,c0,0") /* Counter Frequency Register */
ARMREG_WRITE_INLINE(cnt_frq, "p15,0,%0,c14,c0,0") /* Counter Frequency Register */
ARMREG_READ_INLINE(cntk_ctl, "p15,0,%0,c14,c1,0") /* Timer PL1 Control Register */
ARMREG_WRITE_INLINE(cntk_ctl, "p15,0,%0,c14,c1,0") /* Timer PL1 Control Register */
ARMREG_READ_INLINE(cntp_tval, "p15,0,%0,c14,c2,0") /* PL1 Physical TimerValue Register */
ARMREG_WRITE_INLINE(cntp_tval, "p15,0,%0,c14,c2,0") /* PL1 Physical TimerValue Register */
ARMREG_READ_INLINE(cntp_ctl, "p15,0,%0,c14,c2,1") /* PL1 Physical Timer Control Register */
ARMREG_WRITE_INLINE(cntp_ctl, "p15,0,%0,c14,c2,1") /* PL1 Physical Timer Control Register */
ARMREG_READ_INLINE(cntv_tval, "p15,0,%0,c14,c3,0") /* Virtual TimerValue Register */
ARMREG_WRITE_INLINE(cntv_tval, "p15,0,%0,c14,c3,0") /* Virtual TimerValue Register */
ARMREG_READ_INLINE(cntv_ctl, "p15,0,%0,c14,c3,1") /* Virtual Timer Control Register */
ARMREG_WRITE_INLINE(cntv_ctl, "p15,0,%0,c14,c3,1") /* Virtual Timer Control Register */
ARMREG_READ64_INLINE(cntp_ct, "p15,0,%Q0,%R0,c14") /* Physical Count Register */
ARMREG_WRITE64_INLINE(cntp_ct, "p15,0,%Q0,%R0,c14") /* Physical Count Register */
ARMREG_READ64_INLINE(cntv_ct, "p15,1,%Q0,%R0,c14") /* Virtual Count Register */
ARMREG_WRITE64_INLINE(cntv_ct, "p15,1,%Q0,%R0,c14") /* Virtual Count Register */
ARMREG_READ64_INLINE(cntp_cval, "p15,2,%Q0,%R0,c14") /* PL1 Physical Timer CompareValue Register */
ARMREG_WRITE64_INLINE(cntp_cval, "p15,2,%Q0,%R0,c14") /* PL1 Physical Timer CompareValue Register */
ARMREG_READ64_INLINE(cntv_cval, "p15,3,%Q0,%R0,c14") /* PL1 Virtual Timer CompareValue Register */
ARMREG_WRITE64_INLINE(cntv_cval, "p15,3,%Q0,%R0,c14") /* PL1 Virtual Timer CompareValue Register */
ARMREG_READ64_INLINE(cntvoff, "p15,4,%Q0,%R0,c14") /* Virtual Offset Register */
ARMREG_WRITE64_INLINE(cntvoff, "p15,4,%Q0,%R0,c14") /* Virtual Offset Register */
/* cp15 c15 registers */
/* Cortex A17 Diagnostic control registers */
ARMREG_READ_INLINE(dgnctlr0, "p15,0,%0,c15,c0,0")	/* DGNCTLR0 */
ARMREG_WRITE_INLINE(dgnctlr0, "p15,0,%0,c15,c0,0")	/* DGNCTLR0 */
ARMREG_READ_INLINE(dgnctlr1, "p15,0,%0,c15,c0,1")	/* DGNCTLR1 */
ARMREG_WRITE_INLINE(dgnctlr1, "p15,0,%0,c15,c0,1")	/* DGNCTLR1 */
ARMREG_READ_INLINE(dgnctlr2, "p15,0,%0,c15,c0,2")	/* DGNCTLR2 */
ARMREG_WRITE_INLINE(dgnctlr2, "p15,0,%0,c15,c0,2")	/* DGNCTLR2 */

ARMREG_READ_INLINE(cbar, "p15,4,%0,c15,c0,0")	/* Configuration Base Address Register */

ARMREG_READ_INLINE(pmcrv6, "p15,0,%0,c15,c12,0") /* PMC Control Register (armv6) */
ARMREG_WRITE_INLINE(pmcrv6, "p15,0,%0,c15,c12,0") /* PMC Control Register (armv6) */
ARMREG_READ_INLINE(pmccntrv6, "p15,0,%0,c15,c12,1") /* PMC Cycle Counter (armv6) */
ARMREG_WRITE_INLINE(pmccntrv6, "p15,0,%0,c15,c12,1") /* PMC Cycle Counter (armv6) */

ARMREG_READ_INLINE(tlbdata0, "p15,3,%0,c15,c0,0") /* TLB Data Register 0 (cortex) */
ARMREG_READ_INLINE(tlbdata1, "p15,3,%0,c15,c0,1") /* TLB Data Register 1 (cortex) */
ARMREG_READ_INLINE(tlbdata2, "p15,3,%0,c15,c0,2") /* TLB Data Register 2 (cortex) */
ARMREG_WRITE_INLINE(tlbdataop, "p15,3,%0,c15,c4,2") /* TLB Data Read Operation (cortex) */

ARMREG_READ_INLINE(sheeva_xctrl, "p15,1,%0,c15,c1,0") /* Sheeva eXtra Control register */
ARMREG_WRITE_INLINE(sheeva_xctrl, "p15,1,%0,c15,c1,0") /* Sheeva eXtra Control register */

#if defined(_KERNEL)

static inline uint64_t
cpu_mpidr_aff_read(void)
{

	return armreg_mpidr_read() & (MPIDR_AFF2|MPIDR_AFF1|MPIDR_AFF0);
}

/*
 * GENERIC TIMER register access
 */
static inline uint32_t
gtmr_cntfrq_read(void)
{

	return armreg_cnt_frq_read();
}

static inline uint32_t
gtmr_cntk_ctl_read(void)
{

	return armreg_cntk_ctl_read();
}

static inline void
gtmr_cntk_ctl_write(uint32_t val)
{

	armreg_cntk_ctl_write(val);
}

static inline uint64_t
gtmr_cntpct_read(void)
{

	return armreg_cntp_ct_read();
}

/*
 * Counter-timer Virtual Count timer
 */
static inline uint64_t
gtmr_cntvct_read(void)
{

	return armreg_cntv_ct_read();
}

/*
 * Counter-timer Virtual Timer Control register
 */
static inline uint32_t
gtmr_cntv_ctl_read(void)
{

	return armreg_cntv_ctl_read();
}

static inline void
gtmr_cntv_ctl_write(uint32_t val)
{

	armreg_cntv_ctl_write(val);
}


/*
 * Counter-timer Physical Timer Control register
 */

static inline uint32_t
gtmr_cntp_ctl_read(void)
{

	return armreg_cntp_ctl_read();
}

static inline void
gtmr_cntp_ctl_write(uint32_t val)
{

	armreg_cntp_ctl_write(val);
}


/*
 * Counter-timer Physical Timer TimerValue register
 */
static inline uint32_t
gtmr_cntp_tval_read(void)
{

	return armreg_cntp_tval_read();
}

static inline void
gtmr_cntp_tval_write(uint32_t val)
{

	armreg_cntp_tval_write(val);
}


/*
 * Counter-timer Virtual Timer TimerValue register
 */
static inline uint32_t
gtmr_cntv_tval_read(void)
{

	return armreg_cntv_tval_read();
}

static inline void
gtmr_cntv_tval_write(uint32_t val)
{

	armreg_cntv_tval_write(val);
}


/*
 * Counter-timer Physical Timer CompareValue register
 */
static inline uint64_t
gtmr_cntp_cval_read(void)
{

	return armreg_cntp_cval_read();
}

static inline void
gtmr_cntp_cval_write(uint64_t val)
{

	armreg_cntp_cval_write(val);
}


/*
 * Counter-timer Virtual Timer CompareValue register
 */
static inline uint64_t
gtmr_cntv_cval_read(void)
{

	return armreg_cntv_cval_read();
}

static inline void
gtmr_cntv_cval_write(uint64_t val)
{

	armreg_cntv_cval_write(val);
}

#endif /* _KERNEL */
#endif /* !__ASSEMBLER && !_RUMPKERNEL */

#elif defined(__aarch64__)

#include <aarch64/armreg.h>

#endif /* __arm__/__aarch64__ */

#endif	/* _ARM_ARMREG_H */