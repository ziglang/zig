/*-
 * Copyright (c) 2013, 2014 Andrew Turner
 * Copyright (c) 2015,2021 The FreeBSD Foundation
 *
 * Portions of this software were developed by Andrew Turner
 * under sponsorship from the FreeBSD Foundation.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifdef __arm__
#include <arm/armreg.h>
#else /* !__arm__ */

#ifndef _MACHINE_ARMREG_H_
#define	_MACHINE_ARMREG_H_

#define	INSN_SIZE		4

#define	MRS_MASK			0xfff00000
#define	MRS_VALUE			0xd5300000
#define	MRS_SPECIAL(insn)		((insn) & 0x000fffe0)
#define	MRS_REGISTER(insn)		((insn) & 0x0000001f)
#define	 MRS_Op0_SHIFT			19
#define	 MRS_Op0_MASK			0x00080000
#define	 MRS_Op1_SHIFT			16
#define	 MRS_Op1_MASK			0x00070000
#define	 MRS_CRn_SHIFT			12
#define	 MRS_CRn_MASK			0x0000f000
#define	 MRS_CRm_SHIFT			8
#define	 MRS_CRm_MASK			0x00000f00
#define	 MRS_Op2_SHIFT			5
#define	 MRS_Op2_MASK			0x000000e0
#define	 MRS_Rt_SHIFT			0
#define	 MRS_Rt_MASK			0x0000001f
#define	__MRS_REG(op0, op1, crn, crm, op2)				\
    (((op0) << MRS_Op0_SHIFT) | ((op1) << MRS_Op1_SHIFT) |		\
     ((crn) << MRS_CRn_SHIFT) | ((crm) << MRS_CRm_SHIFT) |		\
     ((op2) << MRS_Op2_SHIFT))
#define	MRS_REG(reg)							\
    __MRS_REG(reg##_op0, reg##_op1, reg##_CRn, reg##_CRm, reg##_op2)

#define	__MRS_REG_ALT_NAME(op0, op1, crn, crm, op2)			\
    S##op0##_##op1##_C##crn##_C##crm##_##op2
#define	_MRS_REG_ALT_NAME(op0, op1, crn, crm, op2)			\
    __MRS_REG_ALT_NAME(op0, op1, crn, crm, op2)
#define	MRS_REG_ALT_NAME(reg)						\
    _MRS_REG_ALT_NAME(reg##_op0, reg##_op1, reg##_CRn, reg##_CRm, reg##_op2)


#define	READ_SPECIALREG(reg)						\
({	uint64_t _val;							\
	__asm __volatile("mrs	%0, " __STRING(reg) : "=&r" (_val));	\
	_val;								\
})
#define	WRITE_SPECIALREG(reg, _val)					\
	__asm __volatile("msr	" __STRING(reg) ", %0" : : "r"((uint64_t)_val))

#define	UL(x)	UINT64_C(x)

/* AFSR0_EL1 - Auxiliary Fault Status Register 0 */
#define	AFSR0_EL1_REG			MRS_REG_ALT_NAME(AFSR0_EL1)
#define	AFSR0_EL1_op0			3
#define	AFSR0_EL1_op1			0
#define	AFSR0_EL1_CRn			5
#define	AFSR0_EL1_CRm			1
#define	AFSR0_EL1_op2			0

/* AFSR0_EL12 */
#define	AFSR0_EL12_REG			MRS_REG_ALT_NAME(AFSR0_EL12)
#define	AFSR0_EL12_op0			3
#define	AFSR0_EL12_op1			5
#define	AFSR0_EL12_CRn			5
#define	AFSR0_EL12_CRm			1
#define	AFSR0_EL12_op2			0

/* AFSR1_EL1 - Auxiliary Fault Status Register 1 */
#define	AFSR1_EL1_REG			MRS_REG_ALT_NAME(AFSR1_EL1)
#define	AFSR1_EL1_op0			3
#define	AFSR1_EL1_op1			0
#define	AFSR1_EL1_CRn			5
#define	AFSR1_EL1_CRm			1
#define	AFSR1_EL1_op2			1

/* AFSR1_EL12 */
#define	AFSR1_EL12_REG			MRS_REG_ALT_NAME(AFSR1_EL12)
#define	AFSR1_EL12_op0			3
#define	AFSR1_EL12_op1			5
#define	AFSR1_EL12_CRn			5
#define	AFSR1_EL12_CRm			1
#define	AFSR1_EL12_op2			1

/* AMAIR_EL1 - Auxiliary Memory Attribute Indirection Register */
#define	AMAIR_EL1_REG			MRS_REG_ALT_NAME(AMAIR_EL1)
#define	AMAIR_EL1_op0			3
#define	AMAIR_EL1_op1			0
#define	AMAIR_EL1_CRn			10
#define	AMAIR_EL1_CRm			3
#define	AMAIR_EL1_op2			0

/* AMAIR_EL12 */
#define	AMAIR_EL12_REG			MRS_REG_ALT_NAME(AMAIR_EL12)
#define	AMAIR_EL12_op0			3
#define	AMAIR_EL12_op1			5
#define	AMAIR_EL12_CRn			10
#define	AMAIR_EL12_CRm			3
#define	AMAIR_EL12_op2			0

/* APDAKeyHi_EL1 */
#define	APDAKeyHi_EL1_REG	MRS_REG_ALT_NAME(APDAKeyHi_EL1)
#define	APDAKeyHi_EL1_op0	3
#define	APDAKeyHi_EL1_op1	0
#define	APDAKeyHi_EL1_CRn	2
#define	APDAKeyHi_EL1_CRm	2
#define	APDAKeyHi_EL1_op2	1

/* APDAKeyLo_EL1 */
#define	APDAKeyLo_EL1_REG	MRS_REG_ALT_NAME(APDAKeyLo_EL1)
#define	APDAKeyLo_EL1_op0	3
#define	APDAKeyLo_EL1_op1	0
#define	APDAKeyLo_EL1_CRn	2
#define	APDAKeyLo_EL1_CRm	2
#define	APDAKeyLo_EL1_op2	0

/* APDBKeyHi_EL1 */
#define	APDBKeyHi_EL1_REG	MRS_REG_ALT_NAME(APDBKeyHi_EL1)
#define	APDBKeyHi_EL1_op0	3
#define	APDBKeyHi_EL1_op1	0
#define	APDBKeyHi_EL1_CRn	2
#define	APDBKeyHi_EL1_CRm	2
#define	APDBKeyHi_EL1_op2	3

/* APDBKeyLo_EL1 */
#define	APDBKeyLo_EL1_REG	MRS_REG_ALT_NAME(APDBKeyLo_EL1)
#define	APDBKeyLo_EL1_op0	3
#define	APDBKeyLo_EL1_op1	0
#define	APDBKeyLo_EL1_CRn	2
#define	APDBKeyLo_EL1_CRm	2
#define	APDBKeyLo_EL1_op2	2

/* APGAKeyHi_EL1 */
#define	APGAKeyHi_EL1_REG	MRS_REG_ALT_NAME(APGAKeyHi_EL1)
#define	APGAKeyHi_EL1_op0	3
#define	APGAKeyHi_EL1_op1	0
#define	APGAKeyHi_EL1_CRn	2
#define	APGAKeyHi_EL1_CRm	3
#define	APGAKeyHi_EL1_op2	1

/* APGAKeyLo_EL1 */
#define	APGAKeyLo_EL1_REG	MRS_REG_ALT_NAME(APGAKeyLo_EL1)
#define	APGAKeyLo_EL1_op0	3
#define	APGAKeyLo_EL1_op1	0
#define	APGAKeyLo_EL1_CRn	2
#define	APGAKeyLo_EL1_CRm	3
#define	APGAKeyLo_EL1_op2	0

/* APIAKeyHi_EL1 */
#define	APIAKeyHi_EL1_REG	MRS_REG_ALT_NAME(APIAKeyHi_EL1)
#define	APIAKeyHi_EL1_op0	3
#define	APIAKeyHi_EL1_op1	0
#define	APIAKeyHi_EL1_CRn	2
#define	APIAKeyHi_EL1_CRm	1
#define	APIAKeyHi_EL1_op2	1

/* APIAKeyLo_EL1 */
#define	APIAKeyLo_EL1_REG	MRS_REG_ALT_NAME(APIAKeyLo_EL1)
#define	APIAKeyLo_EL1_op0	3
#define	APIAKeyLo_EL1_op1	0
#define	APIAKeyLo_EL1_CRn	2
#define	APIAKeyLo_EL1_CRm	1
#define	APIAKeyLo_EL1_op2	0

/* APIBKeyHi_EL1 */
#define	APIBKeyHi_EL1_REG	MRS_REG_ALT_NAME(APIBKeyHi_EL1)
#define	APIBKeyHi_EL1_op0	3
#define	APIBKeyHi_EL1_op1	0
#define	APIBKeyHi_EL1_CRn	2
#define	APIBKeyHi_EL1_CRm	1
#define	APIBKeyHi_EL1_op2	3

/* APIBKeyLo_EL1 */
#define	APIBKeyLo_EL1_REG	MRS_REG_ALT_NAME(APIBKeyLo_EL1)
#define	APIBKeyLo_EL1_op0	3
#define	APIBKeyLo_EL1_op1	0
#define	APIBKeyLo_EL1_CRn	2
#define	APIBKeyLo_EL1_CRm	1
#define	APIBKeyLo_EL1_op2	2

/* CCSIDR_EL1 - Cache Size ID Register */
#define	CCSIDR_NumSets_MASK	0x0FFFE000
#define	CCSIDR_NumSets64_MASK	0x00FFFFFF00000000
#define	CCSIDR_NumSets_SHIFT	13
#define	CCSIDR_NumSets64_SHIFT	32
#define	CCSIDR_Assoc_MASK	0x00001FF8
#define	CCSIDR_Assoc64_MASK	0x0000000000FFFFF8
#define	CCSIDR_Assoc_SHIFT	3
#define	CCSIDR_Assoc64_SHIFT	3
#define	CCSIDR_LineSize_MASK	0x7
#define	CCSIDR_NSETS(idr)						\
	(((idr) & CCSIDR_NumSets_MASK) >> CCSIDR_NumSets_SHIFT)
#define	CCSIDR_ASSOC(idr)						\
	(((idr) & CCSIDR_Assoc_MASK) >> CCSIDR_Assoc_SHIFT)
#define	CCSIDR_NSETS_64(idr)						\
	(((idr) & CCSIDR_NumSets64_MASK) >> CCSIDR_NumSets64_SHIFT)
#define	CCSIDR_ASSOC_64(idr)						\
	(((idr) & CCSIDR_Assoc64_MASK) >> CCSIDR_Assoc64_SHIFT)

/* CLIDR_EL1 - Cache level ID register */
#define	CLIDR_CTYPE_MASK	0x7	/* Cache type mask bits */
#define	CLIDR_CTYPE_IO		0x1	/* Instruction only */
#define	CLIDR_CTYPE_DO		0x2	/* Data only */
#define	CLIDR_CTYPE_ID		0x3	/* Split instruction and data */
#define	CLIDR_CTYPE_UNIFIED	0x4	/* Unified */

/* CNTP_CTL_EL0 - Counter-timer Physical Timer Control register */
#define	CNTP_CTL_EL0		MRS_REG(CNTP_CTL_EL0)
#define	CNTP_CTL_EL0_op0	3
#define	CNTP_CTL_EL0_op1	3
#define	CNTP_CTL_EL0_CRn	14
#define	CNTP_CTL_EL0_CRm	2
#define	CNTP_CTL_EL0_op2	1
#define	CNTP_CTL_ENABLE		(1 << 0)
#define	CNTP_CTL_IMASK		(1 << 1)
#define	CNTP_CTL_ISTATUS	(1 << 2)

/* CNTP_CVAL_EL0 - Counter-timer Physical Timer CompareValue register */
#define	CNTP_CVAL_EL0		MRS_REG(CNTP_CVAL_EL0)
#define	CNTP_CVAL_EL0_op0	3
#define	CNTP_CVAL_EL0_op1	3
#define	CNTP_CVAL_EL0_CRn	14
#define	CNTP_CVAL_EL0_CRm	2
#define	CNTP_CVAL_EL0_op2	2

/* CNTP_TVAL_EL0 - Counter-timer Physical Timer TimerValue register */
#define	CNTP_TVAL_EL0		MRS_REG(CNTP_TVAL_EL0)
#define	CNTP_TVAL_EL0_op0	3
#define	CNTP_TVAL_EL0_op1	3
#define	CNTP_TVAL_EL0_CRn	14
#define	CNTP_TVAL_EL0_CRm	2
#define	CNTP_TVAL_EL0_op2	0

/* CNTPCT_EL0 - Counter-timer Physical Count register */
#define	CNTPCT_EL0		MRS_REG(CNTPCT_EL0)
#define	CNTPCT_EL0_op0		3
#define	CNTPCT_EL0_op1		3
#define	CNTPCT_EL0_CRn		14
#define	CNTPCT_EL0_CRm		0
#define	CNTPCT_EL0_op2		1

/* CONTEXTIDR_EL1 - Context ID register */
#define	CONTEXTIDR_EL1		MRS_REG(CONTEXTIDR_EL1)
#define	CONTEXTIDR_EL1_REG	MRS_REG_ALT_NAME(CONTEXTIDR_EL1)
#define	CONTEXTIDR_EL1_op0	3
#define	CONTEXTIDR_EL1_op1	0
#define	CONTEXTIDR_EL1_CRn	13
#define	CONTEXTIDR_EL1_CRm	0
#define	CONTEXTIDR_EL1_op2	1

/* CONTEXTIDR_EL12 */
#define	CONTEXTIDR_EL12_REG	MRS_REG_ALT_NAME(CONTEXTIDR_EL12)
#define	CONTEXTIDR_EL12_op0	3
#define	CONTEXTIDR_EL12_op1	5
#define	CONTEXTIDR_EL12_CRn	13
#define	CONTEXTIDR_EL12_CRm	0
#define	CONTEXTIDR_EL12_op2	1

/* CPACR_EL1 */
#define	CPACR_EL1_REG		MRS_REG_ALT_NAME(CPACR_EL1)
#define	CPACR_EL1_op0		3
#define	CPACR_EL1_op1		0
#define	CPACR_EL1_CRn		1
#define	CPACR_EL1_CRm		0
#define	CPACR_EL1_op2		2
#define	CPACR_ZEN_MASK		(0x3 << 16)
#define	 CPACR_ZEN_TRAP_ALL1	(0x0 << 16) /* Traps from EL0 and EL1 */
#define	 CPACR_ZEN_TRAP_EL0	(0x1 << 16) /* Traps from EL0 */
#define	 CPACR_ZEN_TRAP_ALL2	(0x2 << 16) /* Traps from EL0 and EL1 */
#define	 CPACR_ZEN_TRAP_NONE	(0x3 << 16) /* No traps */
#define	CPACR_FPEN_MASK		(0x3 << 20)
#define	 CPACR_FPEN_TRAP_ALL1	(0x0 << 20) /* Traps from EL0 and EL1 */
#define	 CPACR_FPEN_TRAP_EL0	(0x1 << 20) /* Traps from EL0 */
#define	 CPACR_FPEN_TRAP_ALL2	(0x2 << 20) /* Traps from EL0 and EL1 */
#define	 CPACR_FPEN_TRAP_NONE	(0x3 << 20) /* No traps */
#define	CPACR_TTA		(0x1 << 28)

/* CPACR_EL12 */
#define	CPACR_EL12_REG		MRS_REG_ALT_NAME(CPACR_EL12)
#define	CPACR_EL12_op0		3
#define	CPACR_EL12_op1		5
#define	CPACR_EL12_CRn		1
#define	CPACR_EL12_CRm		0
#define	CPACR_EL12_op2		2

/* CSSELR_EL1 - Cache size selection register */
#define	CSSELR_Level(i)		(i << 1)
#define	CSSELR_InD		0x00000001

/* CTR_EL0 - Cache Type Register */
#define	CTR_RES1		(1 << 31)
#define	CTR_TminLine_SHIFT	32
#define	CTR_TminLine_MASK	(UL(0x3f) << CTR_TminLine_SHIFT)
#define	CTR_TminLine_VAL(reg)	((reg) & CTR_TminLine_MASK)
#define	CTR_DIC_SHIFT		29
#define	CTR_DIC_MASK		(0x1 << CTR_DIC_SHIFT)
#define	CTR_DIC_VAL(reg)	((reg) & CTR_DIC_MASK)
#define	CTR_IDC_SHIFT		28
#define	CTR_IDC_MASK		(0x1 << CTR_IDC_SHIFT)
#define	CTR_IDC_VAL(reg)	((reg) & CTR_IDC_MASK)
#define	CTR_CWG_SHIFT		24
#define	CTR_CWG_MASK		(0xf << CTR_CWG_SHIFT)
#define	CTR_CWG_VAL(reg)	((reg) & CTR_CWG_MASK)
#define	CTR_CWG_SIZE(reg)	(4 << (CTR_CWG_VAL(reg) >> CTR_CWG_SHIFT))
#define	CTR_ERG_SHIFT		20
#define	CTR_ERG_MASK		(0xf << CTR_ERG_SHIFT)
#define	CTR_ERG_VAL(reg)	((reg) & CTR_ERG_MASK)
#define	CTR_ERG_SIZE(reg)	(4 << (CTR_ERG_VAL(reg) >> CTR_ERG_SHIFT))
#define	CTR_DLINE_SHIFT		16
#define	CTR_DLINE_MASK		(0xf << CTR_DLINE_SHIFT)
#define	CTR_DLINE_VAL(reg)	((reg) & CTR_DLINE_MASK)
#define	CTR_DLINE_SIZE(reg)	(4 << (CTR_DLINE_VAL(reg) >> CTR_DLINE_SHIFT))
#define	CTR_L1IP_SHIFT		14
#define	CTR_L1IP_MASK		(0x3 << CTR_L1IP_SHIFT)
#define	CTR_L1IP_VAL(reg)	((reg) & CTR_L1IP_MASK)
#define	 CTR_L1IP_VPIPT		(0 << CTR_L1IP_SHIFT)
#define	 CTR_L1IP_AIVIVT	(1 << CTR_L1IP_SHIFT)
#define	 CTR_L1IP_VIPT		(2 << CTR_L1IP_SHIFT)
#define	 CTR_L1IP_PIPT		(3 << CTR_L1IP_SHIFT)
#define	CTR_ILINE_SHIFT		0
#define	CTR_ILINE_MASK		(0xf << CTR_ILINE_SHIFT)
#define	CTR_ILINE_VAL(reg)	((reg) & CTR_ILINE_MASK)
#define	CTR_ILINE_SIZE(reg)	(4 << (CTR_ILINE_VAL(reg) >> CTR_ILINE_SHIFT))

/* CurrentEL - Current Exception Level */
#define	CURRENTEL_EL_SHIFT	2
#define	CURRENTEL_EL_MASK	(0x3 << CURRENTEL_EL_SHIFT)
#define	 CURRENTEL_EL_EL0	(0x0 << CURRENTEL_EL_SHIFT)
#define	 CURRENTEL_EL_EL1	(0x1 << CURRENTEL_EL_SHIFT)
#define	 CURRENTEL_EL_EL2	(0x2 << CURRENTEL_EL_SHIFT)
#define	 CURRENTEL_EL_EL3	(0x3 << CURRENTEL_EL_SHIFT)

/* DAIFSet/DAIFClear */
#define	DAIF_D			(1 << 3)
#define	DAIF_A			(1 << 2)
#define	DAIF_I			(1 << 1)
#define	DAIF_F			(1 << 0)
#define	DAIF_ALL		(DAIF_D | DAIF_A | DAIF_I | DAIF_F)
#define	DAIF_INTR		(DAIF_I)	/* All exceptions that pass */
						/* through the intr framework */

/* DBGBCR<n>_EL1 - Debug Breakpoint Control Registers */
#define	DBGBCR_EL1_op0		2
#define	DBGBCR_EL1_op1		0
#define	DBGBCR_EL1_CRn		0
/* DBGBCR_EL1_CRm indicates which watchpoint this register is for */
#define	DBGBCR_EL1_op2		5
#define	DBGBCR_EN		0x1
#define	DBGBCR_PMC_SHIFT	1
#define	DBGBCR_PMC		(0x3 << DBGBCR_PMC_SHIFT)
#define	 DBGBCR_PMC_EL1		(0x1 << DBGBCR_PMC_SHIFT)
#define	 DBGBCR_PMC_EL0		(0x2 << DBGBCR_PMC_SHIFT)
#define	DBGBCR_BAS_SHIFT	5
#define	DBGBCR_BAS		(0xf << DBGBCR_BAS_SHIFT)
#define	DBGBCR_HMC_SHIFT	13
#define	DBGBCR_HMC		(0x1 << DBGBCR_HMC_SHIFT)
#define	DBGBCR_SSC_SHIFT	14
#define	DBGBCR_SSC		(0x3 << DBGBCR_SSC_SHIFT)
#define	DBGBCR_LBN_SHIFT	16
#define	DBGBCR_LBN		(0xf << DBGBCR_LBN_SHIFT)
#define	DBGBCR_BT_SHIFT		20
#define	DBGBCR_BT		(0xf << DBGBCR_BT_SHIFT)

/* DBGBVR<n>_EL1 - Debug Breakpoint Value Registers */
#define	DBGBVR_EL1_op0		2
#define	DBGBVR_EL1_op1		0
#define	DBGBVR_EL1_CRn		0
/* DBGBVR_EL1_CRm indicates which watchpoint this register is for */
#define	DBGBVR_EL1_op2		4

/* DBGWCR<n>_EL1 - Debug Watchpoint Control Registers */
#define	DBGWCR_EL1_op0		2
#define	DBGWCR_EL1_op1		0
#define	DBGWCR_EL1_CRn		0
/* DBGWCR_EL1_CRm indicates which watchpoint this register is for */
#define	DBGWCR_EL1_op2		7
#define	DBGWCR_EN		0x1
#define	DBGWCR_PAC_SHIFT	1
#define	DBGWCR_PAC		(0x3 << DBGWCR_PAC_SHIFT)
#define	 DBGWCR_PAC_EL1		(0x1 << DBGWCR_PAC_SHIFT)
#define	 DBGWCR_PAC_EL0		(0x2 << DBGWCR_PAC_SHIFT)
#define	DBGWCR_LSC_SHIFT	3
#define	DBGWCR_LSC		(0x3 << DBGWCR_LSC_SHIFT)
#define	DBGWCR_BAS_SHIFT	5
#define	DBGWCR_BAS		(0xff << DBGWCR_BAS_SHIFT)
#define	DBGWCR_HMC_SHIFT	13
#define	DBGWCR_HMC		(0x1 << DBGWCR_HMC_SHIFT)
#define	DBGWCR_SSC_SHIFT	14
#define	DBGWCR_SSC		(0x3 << DBGWCR_SSC_SHIFT)
#define	DBGWCR_LBN_SHIFT	16
#define	DBGWCR_LBN		(0xf << DBGWCR_LBN_SHIFT)
#define	DBGWCR_WT_SHIFT		20
#define	DBGWCR_WT		(0x1 << DBGWCR_WT_SHIFT)
#define	DBGWCR_MASK_SHIFT	24
#define	DBGWCR_MASK		(0x1f << DBGWCR_MASK_SHIFT)

/* DBGWVR<n>_EL1 - Debug Watchpoint Value Registers */
#define	DBGWVR_EL1_op0		2
#define	DBGWVR_EL1_op1		0
#define	DBGWVR_EL1_CRn		0
/* DBGWVR_EL1_CRm indicates which watchpoint this register is for */
#define	DBGWVR_EL1_op2		6

/* DCZID_EL0 - Data Cache Zero ID register */
#define DCZID_DZP		(1 << 4) /* DC ZVA prohibited if non-0 */
#define DCZID_BS_SHIFT		0
#define DCZID_BS_MASK		(0xf << DCZID_BS_SHIFT)
#define	DCZID_BS_SIZE(reg)	(((reg) & DCZID_BS_MASK) >> DCZID_BS_SHIFT)

/* DBGAUTHSTATUS_EL1 */
#define	DBGAUTHSTATUS_EL1		MRS_REG(DBGAUTHSTATUS_EL1)
#define	DBGAUTHSTATUS_EL1_op0		2
#define	DBGAUTHSTATUS_EL1_op1		0
#define	DBGAUTHSTATUS_EL1_CRn		7
#define	DBGAUTHSTATUS_EL1_CRm		14
#define	DBGAUTHSTATUS_EL1_op2		6

/* DBGCLAIMCLR_EL1 */
#define	DBGCLAIMCLR_EL1			MRS_REG(DBGCLAIMCLR_EL1)
#define	DBGCLAIMCLR_EL1_op0		2
#define	DBGCLAIMCLR_EL1_op1		0
#define	DBGCLAIMCLR_EL1_CRn		7
#define	DBGCLAIMCLR_EL1_CRm		9
#define	DBGCLAIMCLR_EL1_op2		6

/* DBGCLAIMSET_EL1 */
#define	DBGCLAIMSET_EL1			MRS_REG(DBGCLAIMSET_EL1)
#define	DBGCLAIMSET_EL1_op0		2
#define	DBGCLAIMSET_EL1_op1		0
#define	DBGCLAIMSET_EL1_CRn		7
#define	DBGCLAIMSET_EL1_CRm		8
#define	DBGCLAIMSET_EL1_op2		6

/* DBGPRCR_EL1 */
#define	DBGPRCR_EL1			MRS_REG(DBGPRCR_EL1)
#define	DBGPRCR_EL1_op0			2
#define	DBGPRCR_EL1_op1			0
#define	DBGPRCR_EL1_CRn			1
#define	DBGPRCR_EL1_CRm			4
#define	DBGPRCR_EL1_op2			4

/* ELR_EL1 */
#define	ELR_EL1_REG			MRS_REG_ALT_NAME(ELR_EL1)
#define	ELR_EL1_op0			3
#define	ELR_EL1_op1			0
#define	ELR_EL1_CRn			4
#define	ELR_EL1_CRm			0
#define	ELR_EL1_op2			1

/* ELR_EL12 */
#define	ELR_EL12_REG			MRS_REG_ALT_NAME(ELR_EL12)
#define	ELR_EL12_op0			3
#define	ELR_EL12_op1			5
#define	ELR_EL12_CRn			4
#define	ELR_EL12_CRm			0
#define	ELR_EL12_op2			1

/* ESR_ELx */
#define	ESR_ELx_ISS_MASK	0x01ffffff
#define	 ISS_FP_TFV_SHIFT	23
#define	 ISS_FP_TFV		(0x01 << ISS_FP_TFV_SHIFT)
#define	 ISS_FP_IOF		0x01
#define	 ISS_FP_DZF		0x02
#define	 ISS_FP_OFF		0x04
#define	 ISS_FP_UFF		0x08
#define	 ISS_FP_IXF		0x10
#define	 ISS_FP_IDF		0x80
#define	 ISS_INSN_FnV		(0x01 << 10)
#define	 ISS_INSN_EA		(0x01 << 9)
#define	 ISS_INSN_S1PTW		(0x01 << 7)
#define	 ISS_INSN_IFSC_MASK	(0x1f << 0)

#define	 ISS_WFx_TI_SHIFT	0
#define	 ISS_WFx_TI_MASK	(0x03 << ISS_WFx_TI_SHIFT)
#define	 ISS_WFx_TI_WFI		(0x00 << ISS_WFx_TI_SHIFT)
#define	 ISS_WFx_TI_WFE		(0x01 << ISS_WFx_TI_SHIFT)
#define	 ISS_WFx_TI_WFIT	(0x02 << ISS_WFx_TI_SHIFT)
#define	 ISS_WFx_TI_WFET	(0x03 << ISS_WFx_TI_SHIFT)
#define	 ISS_WFx_RV_SHIFT	2
#define	 ISS_WFx_RV_MASK	(0x01 << ISS_WFx_RV_SHIFT)
#define	 ISS_WFx_RV_INVALID	(0x00 << ISS_WFx_RV_SHIFT)
#define	 ISS_WFx_RV_VALID	(0x01 << ISS_WFx_RV_SHIFT)
#define	 ISS_WFx_RN_SHIFT	5
#define	 ISS_WFx_RN_MASK	(0x1f << ISS_WFx_RN_SHIFT)
#define	 ISS_WFx_RN(x)		(((x) & ISS_WFx_RN_MASK) >> ISS_WFx_RN_SHIFT)
#define	 ISS_WFx_COND_SHIFT	20
#define	 ISS_WFx_COND_MASK	(0x0f << ISS_WFx_COND_SHIFT)
#define	 ISS_WFx_CV_SHIFT	24
#define	 ISS_WFx_CV_MASK	(0x01 << ISS_WFx_CV_SHIFT)
#define	 ISS_WFx_CV_INVALID	(0x00 << ISS_WFx_CV_SHIFT)
#define	 ISS_WFx_CV_VALID	(0x01 << ISS_WFx_CV_SHIFT)

#define	 ISS_MSR_DIR_SHIFT	0
#define	 ISS_MSR_DIR		(0x01 << ISS_MSR_DIR_SHIFT)
#define	 ISS_MSR_Rt_SHIFT	5
#define	 ISS_MSR_Rt_MASK	(0x1f << ISS_MSR_Rt_SHIFT)
#define	 ISS_MSR_Rt(x)		(((x) & ISS_MSR_Rt_MASK) >> ISS_MSR_Rt_SHIFT)
#define	 ISS_MSR_CRm_SHIFT	1
#define	 ISS_MSR_CRm_MASK	(0xf << ISS_MSR_CRm_SHIFT)
#define	 ISS_MSR_CRm(x)		(((x) & ISS_MSR_CRm_MASK) >> ISS_MSR_CRm_SHIFT)
#define	 ISS_MSR_CRn_SHIFT	10
#define	 ISS_MSR_CRn_MASK	(0xf << ISS_MSR_CRn_SHIFT)
#define	 ISS_MSR_CRn(x)		(((x) & ISS_MSR_CRn_MASK) >> ISS_MSR_CRn_SHIFT)
#define	 ISS_MSR_OP1_SHIFT	14
#define	 ISS_MSR_OP1_MASK	(0x7 << ISS_MSR_OP1_SHIFT)
#define	 ISS_MSR_OP1(x)		(((x) & ISS_MSR_OP1_MASK) >> ISS_MSR_OP1_SHIFT)
#define	 ISS_MSR_OP2_SHIFT	17
#define	 ISS_MSR_OP2_MASK	(0x7 << ISS_MSR_OP2_SHIFT)
#define	 ISS_MSR_OP2(x)		(((x) & ISS_MSR_OP2_MASK) >> ISS_MSR_OP2_SHIFT)
#define	 ISS_MSR_OP0_SHIFT	20
#define	 ISS_MSR_OP0_MASK	(0x3 << ISS_MSR_OP0_SHIFT)
#define	 ISS_MSR_OP0(x)		(((x) & ISS_MSR_OP0_MASK) >> ISS_MSR_OP0_SHIFT)
#define	 ISS_MSR_REG_MASK	\
    (ISS_MSR_OP0_MASK | ISS_MSR_OP2_MASK | ISS_MSR_OP1_MASK | 	\
     ISS_MSR_CRn_MASK | ISS_MSR_CRm_MASK)
#define	 ISS_MSR_REG(reg)				\
    (((reg ## _op0) << ISS_MSR_OP0_SHIFT) |		\
     ((reg ## _op1) << ISS_MSR_OP1_SHIFT) |		\
     ((reg ## _CRn) << ISS_MSR_CRn_SHIFT) |		\
     ((reg ## _CRm) << ISS_MSR_CRm_SHIFT) |		\
     ((reg ## _op2) << ISS_MSR_OP2_SHIFT))

#define	 ISS_DATA_ISV_SHIFT	24
#define	 ISS_DATA_ISV		(0x01 << ISS_DATA_ISV_SHIFT)
#define	 ISS_DATA_SAS_SHIFT	22
#define	 ISS_DATA_SAS_MASK	(0x03 << ISS_DATA_SAS_SHIFT)
#define	 ISS_DATA_SSE_SHIFT	21
#define	 ISS_DATA_SSE		(0x01 << ISS_DATA_SSE_SHIFT)
#define	 ISS_DATA_SRT_SHIFT	16
#define	 ISS_DATA_SRT_MASK	(0x1f << ISS_DATA_SRT_SHIFT)
#define	 ISS_DATA_SF		(0x01 << 15)
#define	 ISS_DATA_AR		(0x01 << 14)
#define	 ISS_DATA_FnV		(0x01 << 10)
#define	 ISS_DATA_EA		(0x01 << 9)
#define	 ISS_DATA_CM		(0x01 << 8)
#define	 ISS_DATA_S1PTW		(0x01 << 7)
#define	 ISS_DATA_WnR_SHIFT	6
#define	 ISS_DATA_WnR		(0x01 << ISS_DATA_WnR_SHIFT)
#define	 ISS_DATA_DFSC_MASK	(0x3f << 0)
#define	 ISS_DATA_DFSC_ASF_L0	(0x00 << 0)
#define	 ISS_DATA_DFSC_ASF_L1	(0x01 << 0)
#define	 ISS_DATA_DFSC_ASF_L2	(0x02 << 0)
#define	 ISS_DATA_DFSC_ASF_L3	(0x03 << 0)
#define	 ISS_DATA_DFSC_TF_L0	(0x04 << 0)
#define	 ISS_DATA_DFSC_TF_L1	(0x05 << 0)
#define	 ISS_DATA_DFSC_TF_L2	(0x06 << 0)
#define	 ISS_DATA_DFSC_TF_L3	(0x07 << 0)
#define	 ISS_DATA_DFSC_AFF_L1	(0x09 << 0)
#define	 ISS_DATA_DFSC_AFF_L2	(0x0a << 0)
#define	 ISS_DATA_DFSC_AFF_L3	(0x0b << 0)
#define	 ISS_DATA_DFSC_PF_L1	(0x0d << 0)
#define	 ISS_DATA_DFSC_PF_L2	(0x0e << 0)
#define	 ISS_DATA_DFSC_PF_L3	(0x0f << 0)
#define	 ISS_DATA_DFSC_EXT	(0x10 << 0)
#define	 ISS_DATA_DFSC_EXT_L0	(0x14 << 0)
#define	 ISS_DATA_DFSC_EXT_L1	(0x15 << 0)
#define	 ISS_DATA_DFSC_EXT_L2	(0x16 << 0)
#define	 ISS_DATA_DFSC_EXT_L3	(0x17 << 0)
#define	 ISS_DATA_DFSC_ECC	(0x18 << 0)
#define	 ISS_DATA_DFSC_ECC_L0	(0x1c << 0)
#define	 ISS_DATA_DFSC_ECC_L1	(0x1d << 0)
#define	 ISS_DATA_DFSC_ECC_L2	(0x1e << 0)
#define	 ISS_DATA_DFSC_ECC_L3	(0x1f << 0)
#define	 ISS_DATA_DFSC_ALIGN	(0x21 << 0)
#define	 ISS_DATA_DFSC_TLB_CONFLICT (0x30 << 0)
#define	ESR_ELx_IL		(0x01 << 25)
#define	ESR_ELx_EC_SHIFT	26
#define	ESR_ELx_EC_MASK		(0x3f << 26)
#define	ESR_ELx_EXCEPTION(esr)	(((esr) & ESR_ELx_EC_MASK) >> ESR_ELx_EC_SHIFT)
#define	 EXCP_UNKNOWN		0x00	/* Unkwn exception */
#define	 EXCP_TRAP_WFI_WFE	0x01	/* Trapped WFI or WFE */
#define	 EXCP_FP_SIMD		0x07	/* VFP/SIMD trap */
#define	 EXCP_BTI		0x0d	/* Branch Target Exception */
#define	 EXCP_ILL_STATE		0x0e	/* Illegal execution state */
#define	 EXCP_SVC32		0x11	/* SVC trap for AArch32 */
#define	 EXCP_SVC64		0x15	/* SVC trap for AArch64 */
#define	 EXCP_HVC		0x16	/* HVC trap */
#define	 EXCP_MSR		0x18	/* MSR/MRS trap */
#define	 EXCP_SVE		0x19	/* SVE trap */
#define	 EXCP_FPAC		0x1c	/* Faulting PAC trap */
#define	 EXCP_INSN_ABORT_L	0x20	/* Instruction abort, from lower EL */
#define	 EXCP_INSN_ABORT	0x21	/* Instruction abort, from same EL */ 
#define	 EXCP_PC_ALIGN		0x22	/* PC alignment fault */
#define	 EXCP_DATA_ABORT_L	0x24	/* Data abort, from lower EL */
#define	 EXCP_DATA_ABORT	0x25	/* Data abort, from same EL */ 
#define	 EXCP_SP_ALIGN		0x26	/* SP slignment fault */
#define	 EXCP_TRAP_FP		0x2c	/* Trapped FP exception */
#define	 EXCP_SERROR		0x2f	/* SError interrupt */
#define	 EXCP_BRKPT_EL0		0x30	/* Hardware breakpoint, from same EL */
#define	 EXCP_BRKPT_EL1		0x31	/* Hardware breakpoint, from same EL */
#define	 EXCP_SOFTSTP_EL0	0x32	/* Software Step, from lower EL */
#define	 EXCP_SOFTSTP_EL1	0x33	/* Software Step, from same EL */
#define	 EXCP_WATCHPT_EL0	0x34	/* Watchpoint, from lower EL */
#define	 EXCP_WATCHPT_EL1	0x35	/* Watchpoint, from same EL */
#define	 EXCP_BRKPT_32		0x38    /* 32bits breakpoint */
#define	 EXCP_BRK		0x3c	/* Breakpoint */

/* ESR_EL1 */
#define	ESR_EL1_REG			MRS_REG_ALT_NAME(ESR_EL1)
#define	ESR_EL1_op0			3
#define	ESR_EL1_op1			0
#define	ESR_EL1_CRn			5
#define	ESR_EL1_CRm			2
#define	ESR_EL1_op2			0

/* ESR_EL12 */
#define	ESR_EL12_REG			MRS_REG_ALT_NAME(ESR_EL12)
#define	ESR_EL12_op0			3
#define	ESR_EL12_op1			5
#define	ESR_EL12_CRn			5
#define	ESR_EL12_CRm			2
#define	ESR_EL12_op2			0

/* FAR_EL1 */
#define	FAR_EL1_REG			MRS_REG_ALT_NAME(FAR_EL1)
#define	FAR_EL1_op0			3
#define	FAR_EL1_op1			0
#define	FAR_EL1_CRn			6
#define	FAR_EL1_CRm			0
#define	FAR_EL1_op2			0

/* FAR_EL12 */
#define	FAR_EL12_REG			MRS_REG_ALT_NAME(FAR_EL12)
#define	FAR_EL12_op0			3
#define	FAR_EL12_op1			5
#define	FAR_EL12_CRn			6
#define	FAR_EL12_CRm			0
#define	FAR_EL12_op2			0

/* ICC_CTLR_EL1 */
#define	ICC_CTLR_EL1_EOIMODE	(1U << 1)

/* ICC_IAR1_EL1 */
#define	ICC_IAR1_EL1_SPUR	(0x03ff)

/* ICC_IGRPEN0_EL1 */
#define	ICC_IGRPEN0_EL1_EN	(1U << 0)

/* ICC_PMR_EL1 */
#define	ICC_PMR_EL1_PRIO_MASK	(0xFFUL)

/* ICC_SGI1R_EL1 */
#define	ICC_SGI1R_EL1			MRS_REG(ICC_SGI1R_EL1)
#define	ICC_SGI1R_EL1_op0		3
#define	ICC_SGI1R_EL1_op1		0
#define	ICC_SGI1R_EL1_CRn		12
#define	ICC_SGI1R_EL1_CRm		11
#define	ICC_SGI1R_EL1_op2		5
#define	ICC_SGI1R_EL1_TL_SHIFT		0
#define	ICC_SGI1R_EL1_TL_MASK		(0xffffUL << ICC_SGI1R_EL1_TL_SHIFT)
#define	ICC_SGI1R_EL1_TL_VAL(x)		((x) & ICC_SGI1R_EL1_TL_MASK)
#define	ICC_SGI1R_EL1_AFF1_SHIFT	16
#define	ICC_SGI1R_EL1_AFF1_MASK		(0xfful << ICC_SGI1R_EL1_AFF1_SHIFT)
#define	ICC_SGI1R_EL1_AFF1_VAL(x)	((x) & ICC_SGI1R_EL1_AFF1_MASK)
#define	ICC_SGI1R_EL1_SGIID_SHIFT	24
#define	ICC_SGI1R_EL1_SGIID_MASK	(0xfUL << ICC_SGI1R_EL1_SGIID_SHIFT)
#define	ICC_SGI1R_EL1_SGIID_VAL(x)	((x) & ICC_SGI1R_EL1_SGIID_MASK)
#define	ICC_SGI1R_EL1_AFF2_SHIFT	32
#define	ICC_SGI1R_EL1_AFF2_MASK		(0xfful << ICC_SGI1R_EL1_AFF2_SHIFT)
#define	ICC_SGI1R_EL1_AFF2_VAL(x)	((x) & ICC_SGI1R_EL1_AFF2_MASK)
#define	ICC_SGI1R_EL1_RS_SHIFT		44
#define	ICC_SGI1R_EL1_RS_MASK		(0xful << ICC_SGI1R_EL1_RS_SHIFT)
#define	ICC_SGI1R_EL1_RS_VAL(x)		((x) & ICC_SGI1R_EL1_RS_MASK)
#define	ICC_SGI1R_EL1_AFF3_SHIFT	48
#define	ICC_SGI1R_EL1_AFF3_MASK		(0xfful << ICC_SGI1R_EL1_AFF3_SHIFT)
#define	ICC_SGI1R_EL1_AFF3_VAL(x)	((x) & ICC_SGI1R_EL1_AFF3_MASK)
#define	ICC_SGI1R_EL1_IRM		(0x1UL << 40)

/* ICC_SRE_EL1 */
#define	ICC_SRE_EL1_SRE		(1U << 0)

/* ID_AA64AFR0_EL1 */
#define	ID_AA64AFR0_EL1			MRS_REG(ID_AA64AFR0_EL1)
#define	ID_AA64AFR0_EL1_REG		MRS_REG_ALT_NAME(ID_AA64AFR0_EL1)
#define	ID_AA64AFR0_EL1_op0		3
#define	ID_AA64AFR0_EL1_op1		0
#define	ID_AA64AFR0_EL1_CRn		0
#define	ID_AA64AFR0_EL1_CRm		5
#define	ID_AA64AFR0_EL1_op2		4

/* ID_AA64AFR1_EL1 */
#define	ID_AA64AFR1_EL1			MRS_REG(ID_AA64AFR1_EL1)
#define	ID_AA64AFR1_EL1_REG		MRS_REG_ALT_NAME(ID_AA64AFR1_EL1)
#define	ID_AA64AFR1_EL1_op0		3
#define	ID_AA64AFR1_EL1_op1		0
#define	ID_AA64AFR1_EL1_CRn		0
#define	ID_AA64AFR1_EL1_CRm		5
#define	ID_AA64AFR1_EL1_op2		5

/* ID_AA64DFR0_EL1 */
#define	ID_AA64DFR0_EL1			MRS_REG(ID_AA64DFR0_EL1)
#define	ID_AA64DFR0_EL1_REG		MRS_REG_ALT_NAME(ID_AA64DFR0_EL1)
#define	ID_AA64DFR0_EL1_op0		3
#define	ID_AA64DFR0_EL1_op1		0
#define	ID_AA64DFR0_EL1_CRn		0
#define	ID_AA64DFR0_EL1_CRm		5
#define	ID_AA64DFR0_EL1_op2		0
#define	ID_AA64DFR0_DebugVer_SHIFT	0
#define	ID_AA64DFR0_DebugVer_MASK	(UL(0xf) << ID_AA64DFR0_DebugVer_SHIFT)
#define	ID_AA64DFR0_DebugVer_VAL(x)	((x) & ID_AA64DFR0_DebugVer_MASK)
#define	 ID_AA64DFR0_DebugVer_8		(UL(0x6) << ID_AA64DFR0_DebugVer_SHIFT)
#define	 ID_AA64DFR0_DebugVer_8_VHE	(UL(0x7) << ID_AA64DFR0_DebugVer_SHIFT)
#define	 ID_AA64DFR0_DebugVer_8_2	(UL(0x8) << ID_AA64DFR0_DebugVer_SHIFT)
#define	 ID_AA64DFR0_DebugVer_8_4	(UL(0x9) << ID_AA64DFR0_DebugVer_SHIFT)
#define	 ID_AA64DFR0_DebugVer_8_8	(UL(0xa) << ID_AA64DFR0_DebugVer_SHIFT)
#define	ID_AA64DFR0_TraceVer_SHIFT	4
#define	ID_AA64DFR0_TraceVer_MASK	(UL(0xf) << ID_AA64DFR0_TraceVer_SHIFT)
#define	ID_AA64DFR0_TraceVer_VAL(x)	((x) & ID_AA64DFR0_TraceVer_MASK)
#define	 ID_AA64DFR0_TraceVer_NONE	(UL(0x0) << ID_AA64DFR0_TraceVer_SHIFT)
#define	 ID_AA64DFR0_TraceVer_IMPL	(UL(0x1) << ID_AA64DFR0_TraceVer_SHIFT)
#define	ID_AA64DFR0_PMUVer_SHIFT	8
#define	ID_AA64DFR0_PMUVer_MASK		(UL(0xf) << ID_AA64DFR0_PMUVer_SHIFT)
#define	ID_AA64DFR0_PMUVer_VAL(x)	((x) & ID_AA64DFR0_PMUVer_MASK)
#define	 ID_AA64DFR0_PMUVer_NONE	(UL(0x0) << ID_AA64DFR0_PMUVer_SHIFT)
#define	 ID_AA64DFR0_PMUVer_3		(UL(0x1) << ID_AA64DFR0_PMUVer_SHIFT)
#define	 ID_AA64DFR0_PMUVer_3_1		(UL(0x4) << ID_AA64DFR0_PMUVer_SHIFT)
#define	 ID_AA64DFR0_PMUVer_3_4		(UL(0x5) << ID_AA64DFR0_PMUVer_SHIFT)
#define	 ID_AA64DFR0_PMUVer_3_5		(UL(0x6) << ID_AA64DFR0_PMUVer_SHIFT)
#define	 ID_AA64DFR0_PMUVer_3_7		(UL(0x7) << ID_AA64DFR0_PMUVer_SHIFT)
#define	 ID_AA64DFR0_PMUVer_3_8		(UL(0x8) << ID_AA64DFR0_PMUVer_SHIFT)
#define	 ID_AA64DFR0_PMUVer_IMPL	(UL(0xf) << ID_AA64DFR0_PMUVer_SHIFT)
#define	ID_AA64DFR0_BRPs_SHIFT		12
#define	ID_AA64DFR0_BRPs_MASK		(UL(0xf) << ID_AA64DFR0_BRPs_SHIFT)
#define	ID_AA64DFR0_BRPs_VAL(x)	\
    ((((x) >> ID_AA64DFR0_BRPs_SHIFT) & 0xf) + 1)
#define	ID_AA64DFR0_PMSS_SHIFT		16
#define	ID_AA64DFR0_PMSS_MASK		(UL(0xf) << ID_AA64DFR0_PMSS_SHIFT)
#define	ID_AA64DFR0_PMSS_VAL(x)		((x) & ID_AA64DFR0_PMSS_MASK)
#define	 ID_AA64DFR0_PMSS_NONE		(UL(0x0) << ID_AA64DFR0_PMSS_SHIFT)
#define	 ID_AA64DFR0_PMSS_IMPL		(UL(0x1) << ID_AA64DFR0_PMSS_SHIFT)
#define	ID_AA64DFR0_WRPs_SHIFT		20
#define	ID_AA64DFR0_WRPs_MASK		(UL(0xf) << ID_AA64DFR0_WRPs_SHIFT)
#define	ID_AA64DFR0_WRPs_VAL(x)	\
    ((((x) >> ID_AA64DFR0_WRPs_SHIFT) & 0xf) + 1)
#define	ID_AA64DFR0_CTX_CMPs_SHIFT	28
#define	ID_AA64DFR0_CTX_CMPs_MASK	(UL(0xf) << ID_AA64DFR0_CTX_CMPs_SHIFT)
#define	ID_AA64DFR0_CTX_CMPs_VAL(x)	\
    ((((x) >> ID_AA64DFR0_CTX_CMPs_SHIFT) & 0xf) + 1)
#define	ID_AA64DFR0_PMSVer_SHIFT	32
#define	ID_AA64DFR0_PMSVer_MASK		(UL(0xf) << ID_AA64DFR0_PMSVer_SHIFT)
#define	ID_AA64DFR0_PMSVer_VAL(x)	((x) & ID_AA64DFR0_PMSVer_MASK)
#define	 ID_AA64DFR0_PMSVer_NONE	(UL(0x0) << ID_AA64DFR0_PMSVer_SHIFT)
#define	 ID_AA64DFR0_PMSVer_SPE		(UL(0x1) << ID_AA64DFR0_PMSVer_SHIFT)
#define	 ID_AA64DFR0_PMSVer_SPE_1_1	(UL(0x2) << ID_AA64DFR0_PMSVer_SHIFT)
#define	 ID_AA64DFR0_PMSVer_SPE_1_2	(UL(0x3) << ID_AA64DFR0_PMSVer_SHIFT)
#define	 ID_AA64DFR0_PMSVer_SPE_1_3	(UL(0x4) << ID_AA64DFR0_PMSVer_SHIFT)
#define	ID_AA64DFR0_DoubleLock_SHIFT	36
#define	ID_AA64DFR0_DoubleLock_MASK	(UL(0xf) << ID_AA64DFR0_DoubleLock_SHIFT)
#define	ID_AA64DFR0_DoubleLock_VAL(x)	((x) & ID_AA64DFR0_DoubleLock_MASK)
#define	 ID_AA64DFR0_DoubleLock_IMPL	(UL(0x0) << ID_AA64DFR0_DoubleLock_SHIFT)
#define	 ID_AA64DFR0_DoubleLock_NONE	(UL(0xf) << ID_AA64DFR0_DoubleLock_SHIFT)
#define	ID_AA64DFR0_TraceFilt_SHIFT	40
#define	ID_AA64DFR0_TraceFilt_MASK	(UL(0xf) << ID_AA64DFR0_TraceFilt_SHIFT)
#define	ID_AA64DFR0_TraceFilt_VAL(x)	((x) & ID_AA64DFR0_TraceFilt_MASK)
#define	 ID_AA64DFR0_TraceFilt_NONE	(UL(0x0) << ID_AA64DFR0_TraceFilt_SHIFT)
#define	 ID_AA64DFR0_TraceFilt_8_4	(UL(0x1) << ID_AA64DFR0_TraceFilt_SHIFT)
#define	ID_AA64DFR0_TraceBuffer_SHIFT	44
#define	ID_AA64DFR0_TraceBuffer_MASK	(UL(0xf) << ID_AA64DFR0_TraceBuffer_SHIFT)
#define	ID_AA64DFR0_TraceBuffer_VAL(x)	((x) & ID_AA64DFR0_TraceBuffer_MASK)
#define	 ID_AA64DFR0_TraceBuffer_NONE	(UL(0x0) << ID_AA64DFR0_TraceBuffer_SHIFT)
#define	 ID_AA64DFR0_TraceBuffer_IMPL	(UL(0x1) << ID_AA64DFR0_TraceBuffer_SHIFT)
#define	ID_AA64DFR0_MTPMU_SHIFT		48
#define	ID_AA64DFR0_MTPMU_MASK		(UL(0xf) << ID_AA64DFR0_MTPMU_SHIFT)
#define	ID_AA64DFR0_MTPMU_VAL(x)	((x) & ID_AA64DFR0_MTPMU_MASK)
#define	 ID_AA64DFR0_MTPMU_NONE		(UL(0x0) << ID_AA64DFR0_MTPMU_SHIFT)
#define	 ID_AA64DFR0_MTPMU_IMPL		(UL(0x1) << ID_AA64DFR0_MTPMU_SHIFT)
#define	 ID_AA64DFR0_MTPMU_NONE_MT_RES0	(UL(0xf) << ID_AA64DFR0_MTPMU_SHIFT)
#define	ID_AA64DFR0_BRBE_SHIFT		52
#define	ID_AA64DFR0_BRBE_MASK		(UL(0xf) << ID_AA64DFR0_BRBE_SHIFT)
#define	ID_AA64DFR0_BRBE_VAL(x)		((x) & ID_AA64DFR0_BRBE_MASK)
#define	 ID_AA64DFR0_BRBE_NONE		(UL(0x0) << ID_AA64DFR0_BRBE_SHIFT)
#define	 ID_AA64DFR0_BRBE_IMPL		(UL(0x1) << ID_AA64DFR0_BRBE_SHIFT)
#define	 ID_AA64DFR0_BRBE_EL3		(UL(0x2) << ID_AA64DFR0_BRBE_SHIFT)
#define	ID_AA64DFR0_HPMN0_SHIFT		60
#define	ID_AA64DFR0_HPMN0_MASK		(UL(0xf) << ID_AA64DFR0_HPMN0_SHIFT)
#define	ID_AA64DFR0_HPMN0_VAL(x)	((x) & ID_AA64DFR0_HPMN0_MASK)
#define	 ID_AA64DFR0_HPMN0_CONSTR	(UL(0x0) << ID_AA64DFR0_HPMN0_SHIFT)
#define	 ID_AA64DFR0_HPMN0_DEFINED	(UL(0x1) << ID_AA64DFR0_HPMN0_SHIFT)

/* ID_AA64DFR1_EL1 */
#define	ID_AA64DFR1_EL1			MRS_REG(ID_AA64DFR1_EL1)
#define	ID_AA64DFR1_EL1_REG		MRS_REG_ALT_NAME(ID_AA64DFR1_EL1)
#define	ID_AA64DFR1_EL1_op0		3
#define	ID_AA64DFR1_EL1_op1		0
#define	ID_AA64DFR1_EL1_CRn		0
#define	ID_AA64DFR1_EL1_CRm		5
#define	ID_AA64DFR1_EL1_op2		1

/* ID_AA64ISAR0_EL1 */
#define	ID_AA64ISAR0_EL1		MRS_REG(ID_AA64ISAR0_EL1)
#define	ID_AA64ISAR0_EL1_REG		MRS_REG_ALT_NAME(ID_AA64ISAR0_EL1)
#define	ID_AA64ISAR0_EL1_op0		3
#define	ID_AA64ISAR0_EL1_op1		0
#define	ID_AA64ISAR0_EL1_CRn		0
#define	ID_AA64ISAR0_EL1_CRm		6
#define	ID_AA64ISAR0_EL1_op2		0
#define	ID_AA64ISAR0_AES_SHIFT		4
#define	ID_AA64ISAR0_AES_MASK		(UL(0xf) << ID_AA64ISAR0_AES_SHIFT)
#define	ID_AA64ISAR0_AES_VAL(x)		((x) & ID_AA64ISAR0_AES_MASK)
#define	 ID_AA64ISAR0_AES_NONE		(UL(0x0) << ID_AA64ISAR0_AES_SHIFT)
#define	 ID_AA64ISAR0_AES_BASE		(UL(0x1) << ID_AA64ISAR0_AES_SHIFT)
#define	 ID_AA64ISAR0_AES_PMULL		(UL(0x2) << ID_AA64ISAR0_AES_SHIFT)
#define	ID_AA64ISAR0_SHA1_SHIFT		8
#define	ID_AA64ISAR0_SHA1_MASK		(UL(0xf) << ID_AA64ISAR0_SHA1_SHIFT)
#define	ID_AA64ISAR0_SHA1_VAL(x)	((x) & ID_AA64ISAR0_SHA1_MASK)
#define	 ID_AA64ISAR0_SHA1_NONE		(UL(0x0) << ID_AA64ISAR0_SHA1_SHIFT)
#define	 ID_AA64ISAR0_SHA1_BASE		(UL(0x1) << ID_AA64ISAR0_SHA1_SHIFT)
#define	ID_AA64ISAR0_SHA2_SHIFT		12
#define	ID_AA64ISAR0_SHA2_MASK		(UL(0xf) << ID_AA64ISAR0_SHA2_SHIFT)
#define	ID_AA64ISAR0_SHA2_VAL(x)	((x) & ID_AA64ISAR0_SHA2_MASK)
#define	 ID_AA64ISAR0_SHA2_NONE		(UL(0x0) << ID_AA64ISAR0_SHA2_SHIFT)
#define	 ID_AA64ISAR0_SHA2_BASE		(UL(0x1) << ID_AA64ISAR0_SHA2_SHIFT)
#define	 ID_AA64ISAR0_SHA2_512		(UL(0x2) << ID_AA64ISAR0_SHA2_SHIFT)
#define	ID_AA64ISAR0_CRC32_SHIFT	16
#define	ID_AA64ISAR0_CRC32_MASK		(UL(0xf) << ID_AA64ISAR0_CRC32_SHIFT)
#define	ID_AA64ISAR0_CRC32_VAL(x)	((x) & ID_AA64ISAR0_CRC32_MASK)
#define	 ID_AA64ISAR0_CRC32_NONE	(UL(0x0) << ID_AA64ISAR0_CRC32_SHIFT)
#define	 ID_AA64ISAR0_CRC32_BASE	(UL(0x1) << ID_AA64ISAR0_CRC32_SHIFT)
#define	ID_AA64ISAR0_Atomic_SHIFT	20
#define	ID_AA64ISAR0_Atomic_MASK	(UL(0xf) << ID_AA64ISAR0_Atomic_SHIFT)
#define	ID_AA64ISAR0_Atomic_VAL(x)	((x) & ID_AA64ISAR0_Atomic_MASK)
#define	 ID_AA64ISAR0_Atomic_NONE	(UL(0x0) << ID_AA64ISAR0_Atomic_SHIFT)
#define	 ID_AA64ISAR0_Atomic_IMPL	(UL(0x2) << ID_AA64ISAR0_Atomic_SHIFT)
#define	ID_AA64ISAR0_TME_SHIFT		24
#define	ID_AA64ISAR0_TME_MASK		(UL(0xf) << ID_AA64ISAR0_TME_SHIFT)
#define	 ID_AA64ISAR0_TME_NONE		(UL(0x0) << ID_AA64ISAR0_TME_SHIFT)
#define	 ID_AA64ISAR0_TME_IMPL		(UL(0x1) << ID_AA64ISAR0_TME_SHIFT)
#define	ID_AA64ISAR0_RDM_SHIFT		28
#define	ID_AA64ISAR0_RDM_MASK		(UL(0xf) << ID_AA64ISAR0_RDM_SHIFT)
#define	ID_AA64ISAR0_RDM_VAL(x)		((x) & ID_AA64ISAR0_RDM_MASK)
#define	 ID_AA64ISAR0_RDM_NONE		(UL(0x0) << ID_AA64ISAR0_RDM_SHIFT)
#define	 ID_AA64ISAR0_RDM_IMPL		(UL(0x1) << ID_AA64ISAR0_RDM_SHIFT)
#define	ID_AA64ISAR0_SHA3_SHIFT		32
#define	ID_AA64ISAR0_SHA3_MASK		(UL(0xf) << ID_AA64ISAR0_SHA3_SHIFT)
#define	ID_AA64ISAR0_SHA3_VAL(x)	((x) & ID_AA64ISAR0_SHA3_MASK)
#define	 ID_AA64ISAR0_SHA3_NONE		(UL(0x0) << ID_AA64ISAR0_SHA3_SHIFT)
#define	 ID_AA64ISAR0_SHA3_IMPL		(UL(0x1) << ID_AA64ISAR0_SHA3_SHIFT)
#define	ID_AA64ISAR0_SM3_SHIFT		36
#define	ID_AA64ISAR0_SM3_MASK		(UL(0xf) << ID_AA64ISAR0_SM3_SHIFT)
#define	ID_AA64ISAR0_SM3_VAL(x)		((x) & ID_AA64ISAR0_SM3_MASK)
#define	 ID_AA64ISAR0_SM3_NONE		(UL(0x0) << ID_AA64ISAR0_SM3_SHIFT)
#define	 ID_AA64ISAR0_SM3_IMPL		(UL(0x1) << ID_AA64ISAR0_SM3_SHIFT)
#define	ID_AA64ISAR0_SM4_SHIFT		40
#define	ID_AA64ISAR0_SM4_MASK		(UL(0xf) << ID_AA64ISAR0_SM4_SHIFT)
#define	ID_AA64ISAR0_SM4_VAL(x)		((x) & ID_AA64ISAR0_SM4_MASK)
#define	 ID_AA64ISAR0_SM4_NONE		(UL(0x0) << ID_AA64ISAR0_SM4_SHIFT)
#define	 ID_AA64ISAR0_SM4_IMPL		(UL(0x1) << ID_AA64ISAR0_SM4_SHIFT)
#define	ID_AA64ISAR0_DP_SHIFT		44
#define	ID_AA64ISAR0_DP_MASK		(UL(0xf) << ID_AA64ISAR0_DP_SHIFT)
#define	ID_AA64ISAR0_DP_VAL(x)		((x) & ID_AA64ISAR0_DP_MASK)
#define	 ID_AA64ISAR0_DP_NONE		(UL(0x0) << ID_AA64ISAR0_DP_SHIFT)
#define	 ID_AA64ISAR0_DP_IMPL		(UL(0x1) << ID_AA64ISAR0_DP_SHIFT)
#define	ID_AA64ISAR0_FHM_SHIFT		48
#define	ID_AA64ISAR0_FHM_MASK		(UL(0xf) << ID_AA64ISAR0_FHM_SHIFT)
#define	ID_AA64ISAR0_FHM_VAL(x)		((x) & ID_AA64ISAR0_FHM_MASK)
#define	 ID_AA64ISAR0_FHM_NONE		(UL(0x0) << ID_AA64ISAR0_FHM_SHIFT)
#define	 ID_AA64ISAR0_FHM_IMPL		(UL(0x1) << ID_AA64ISAR0_FHM_SHIFT)
#define	ID_AA64ISAR0_TS_SHIFT		52
#define	ID_AA64ISAR0_TS_MASK		(UL(0xf) << ID_AA64ISAR0_TS_SHIFT)
#define	ID_AA64ISAR0_TS_VAL(x)		((x) & ID_AA64ISAR0_TS_MASK)
#define	 ID_AA64ISAR0_TS_NONE		(UL(0x0) << ID_AA64ISAR0_TS_SHIFT)
#define	 ID_AA64ISAR0_TS_CondM_8_4	(UL(0x1) << ID_AA64ISAR0_TS_SHIFT)
#define	 ID_AA64ISAR0_TS_CondM_8_5	(UL(0x2) << ID_AA64ISAR0_TS_SHIFT)
#define	ID_AA64ISAR0_TLB_SHIFT		56
#define	ID_AA64ISAR0_TLB_MASK		(UL(0xf) << ID_AA64ISAR0_TLB_SHIFT)
#define	ID_AA64ISAR0_TLB_VAL(x)		((x) & ID_AA64ISAR0_TLB_MASK)
#define	 ID_AA64ISAR0_TLB_NONE		(UL(0x0) << ID_AA64ISAR0_TLB_SHIFT)
#define	 ID_AA64ISAR0_TLB_TLBIOS	(UL(0x1) << ID_AA64ISAR0_TLB_SHIFT)
#define	 ID_AA64ISAR0_TLB_TLBIOSR	(UL(0x2) << ID_AA64ISAR0_TLB_SHIFT)
#define	ID_AA64ISAR0_RNDR_SHIFT		60
#define	ID_AA64ISAR0_RNDR_MASK		(UL(0xf) << ID_AA64ISAR0_RNDR_SHIFT)
#define	ID_AA64ISAR0_RNDR_VAL(x)	((x) & ID_AA64ISAR0_RNDR_MASK)
#define	 ID_AA64ISAR0_RNDR_NONE		(UL(0x0) << ID_AA64ISAR0_RNDR_SHIFT)
#define	 ID_AA64ISAR0_RNDR_IMPL		(UL(0x1) << ID_AA64ISAR0_RNDR_SHIFT)

/* ID_AA64ISAR1_EL1 */
#define	ID_AA64ISAR1_EL1		MRS_REG(ID_AA64ISAR1_EL1)
#define	ID_AA64ISAR1_EL1_REG		MRS_REG_ALT_NAME(ID_AA64ISAR1_EL1)
#define	ID_AA64ISAR1_EL1_op0		3
#define	ID_AA64ISAR1_EL1_op1		0
#define	ID_AA64ISAR1_EL1_CRn		0
#define	ID_AA64ISAR1_EL1_CRm		6
#define	ID_AA64ISAR1_EL1_op2		1
#define	ID_AA64ISAR1_DPB_SHIFT		0
#define	ID_AA64ISAR1_DPB_MASK		(UL(0xf) << ID_AA64ISAR1_DPB_SHIFT)
#define	ID_AA64ISAR1_DPB_VAL(x)		((x) & ID_AA64ISAR1_DPB_MASK)
#define	 ID_AA64ISAR1_DPB_NONE		(UL(0x0) << ID_AA64ISAR1_DPB_SHIFT)
#define	 ID_AA64ISAR1_DPB_DCCVAP	(UL(0x1) << ID_AA64ISAR1_DPB_SHIFT)
#define	 ID_AA64ISAR1_DPB_DCCVADP	(UL(0x2) << ID_AA64ISAR1_DPB_SHIFT)
#define	ID_AA64ISAR1_APA_SHIFT		4
#define	ID_AA64ISAR1_APA_MASK		(UL(0xf) << ID_AA64ISAR1_APA_SHIFT)
#define	ID_AA64ISAR1_APA_VAL(x)		((x) & ID_AA64ISAR1_APA_MASK)
#define	 ID_AA64ISAR1_APA_NONE		(UL(0x0) << ID_AA64ISAR1_APA_SHIFT)
#define	 ID_AA64ISAR1_APA_PAC		(UL(0x1) << ID_AA64ISAR1_APA_SHIFT)
#define	 ID_AA64ISAR1_APA_EPAC		(UL(0x2) << ID_AA64ISAR1_APA_SHIFT)
#define	 ID_AA64ISAR1_APA_EPAC2		(UL(0x3) << ID_AA64ISAR1_APA_SHIFT)
#define	 ID_AA64ISAR1_APA_FPAC		(UL(0x4) << ID_AA64ISAR1_APA_SHIFT)
#define	 ID_AA64ISAR1_APA_FPAC_COMBINED	(UL(0x5) << ID_AA64ISAR1_APA_SHIFT)
#define	ID_AA64ISAR1_API_SHIFT		8
#define	ID_AA64ISAR1_API_MASK		(UL(0xf) << ID_AA64ISAR1_API_SHIFT)
#define	ID_AA64ISAR1_API_VAL(x)		((x) & ID_AA64ISAR1_API_MASK)
#define	 ID_AA64ISAR1_API_NONE		(UL(0x0) << ID_AA64ISAR1_API_SHIFT)
#define	 ID_AA64ISAR1_API_PAC		(UL(0x1) << ID_AA64ISAR1_API_SHIFT)
#define	 ID_AA64ISAR1_API_EPAC		(UL(0x2) << ID_AA64ISAR1_API_SHIFT)
#define	 ID_AA64ISAR1_API_EPAC2		(UL(0x3) << ID_AA64ISAR1_API_SHIFT)
#define	 ID_AA64ISAR1_API_FPAC		(UL(0x4) << ID_AA64ISAR1_API_SHIFT)
#define	 ID_AA64ISAR1_API_FPAC_COMBINED	(UL(0x5) << ID_AA64ISAR1_API_SHIFT)
#define	ID_AA64ISAR1_JSCVT_SHIFT	12
#define	ID_AA64ISAR1_JSCVT_MASK		(UL(0xf) << ID_AA64ISAR1_JSCVT_SHIFT)
#define	ID_AA64ISAR1_JSCVT_VAL(x)	((x) & ID_AA64ISAR1_JSCVT_MASK)
#define	 ID_AA64ISAR1_JSCVT_NONE	(UL(0x0) << ID_AA64ISAR1_JSCVT_SHIFT)
#define	 ID_AA64ISAR1_JSCVT_IMPL	(UL(0x1) << ID_AA64ISAR1_JSCVT_SHIFT)
#define	ID_AA64ISAR1_FCMA_SHIFT		16
#define	ID_AA64ISAR1_FCMA_MASK		(UL(0xf) << ID_AA64ISAR1_FCMA_SHIFT)
#define	ID_AA64ISAR1_FCMA_VAL(x)	((x) & ID_AA64ISAR1_FCMA_MASK)
#define	 ID_AA64ISAR1_FCMA_NONE		(UL(0x0) << ID_AA64ISAR1_FCMA_SHIFT)
#define	 ID_AA64ISAR1_FCMA_IMPL		(UL(0x1) << ID_AA64ISAR1_FCMA_SHIFT)
#define	ID_AA64ISAR1_LRCPC_SHIFT	20
#define	ID_AA64ISAR1_LRCPC_MASK		(UL(0xf) << ID_AA64ISAR1_LRCPC_SHIFT)
#define	ID_AA64ISAR1_LRCPC_VAL(x)	((x) & ID_AA64ISAR1_LRCPC_MASK)
#define	 ID_AA64ISAR1_LRCPC_NONE	(UL(0x0) << ID_AA64ISAR1_LRCPC_SHIFT)
#define	 ID_AA64ISAR1_LRCPC_RCPC_8_3	(UL(0x1) << ID_AA64ISAR1_LRCPC_SHIFT)
#define	 ID_AA64ISAR1_LRCPC_RCPC_8_4	(UL(0x2) << ID_AA64ISAR1_LRCPC_SHIFT)
#define	ID_AA64ISAR1_GPA_SHIFT		24
#define	ID_AA64ISAR1_GPA_MASK		(UL(0xf) << ID_AA64ISAR1_GPA_SHIFT)
#define	ID_AA64ISAR1_GPA_VAL(x)		((x) & ID_AA64ISAR1_GPA_MASK)
#define	 ID_AA64ISAR1_GPA_NONE		(UL(0x0) << ID_AA64ISAR1_GPA_SHIFT)
#define	 ID_AA64ISAR1_GPA_IMPL		(UL(0x1) << ID_AA64ISAR1_GPA_SHIFT)
#define	ID_AA64ISAR1_GPI_SHIFT		28
#define	ID_AA64ISAR1_GPI_MASK		(UL(0xf) << ID_AA64ISAR1_GPI_SHIFT)
#define	ID_AA64ISAR1_GPI_VAL(x)		((x) & ID_AA64ISAR1_GPI_MASK)
#define	 ID_AA64ISAR1_GPI_NONE		(UL(0x0) << ID_AA64ISAR1_GPI_SHIFT)
#define	 ID_AA64ISAR1_GPI_IMPL		(UL(0x1) << ID_AA64ISAR1_GPI_SHIFT)
#define	ID_AA64ISAR1_FRINTTS_SHIFT	32
#define	ID_AA64ISAR1_FRINTTS_MASK	(UL(0xf) << ID_AA64ISAR1_FRINTTS_SHIFT)
#define	ID_AA64ISAR1_FRINTTS_VAL(x)	((x) & ID_AA64ISAR1_FRINTTS_MASK)
#define	 ID_AA64ISAR1_FRINTTS_NONE	(UL(0x0) << ID_AA64ISAR1_FRINTTS_SHIFT)
#define	 ID_AA64ISAR1_FRINTTS_IMPL	(UL(0x1) << ID_AA64ISAR1_FRINTTS_SHIFT)
#define	ID_AA64ISAR1_SB_SHIFT		36
#define	ID_AA64ISAR1_SB_MASK		(UL(0xf) << ID_AA64ISAR1_SB_SHIFT)
#define	ID_AA64ISAR1_SB_VAL(x)		((x) & ID_AA64ISAR1_SB_MASK)
#define	 ID_AA64ISAR1_SB_NONE		(UL(0x0) << ID_AA64ISAR1_SB_SHIFT)
#define	 ID_AA64ISAR1_SB_IMPL		(UL(0x1) << ID_AA64ISAR1_SB_SHIFT)
#define	ID_AA64ISAR1_SPECRES_SHIFT	40
#define	ID_AA64ISAR1_SPECRES_MASK	(UL(0xf) << ID_AA64ISAR1_SPECRES_SHIFT)
#define	ID_AA64ISAR1_SPECRES_VAL(x)	((x) & ID_AA64ISAR1_SPECRES_MASK)
#define	 ID_AA64ISAR1_SPECRES_NONE	(UL(0x0) << ID_AA64ISAR1_SPECRES_SHIFT)
#define	 ID_AA64ISAR1_SPECRES_IMPL	(UL(0x1) << ID_AA64ISAR1_SPECRES_SHIFT)
#define	ID_AA64ISAR1_BF16_SHIFT		44
#define	ID_AA64ISAR1_BF16_MASK		(UL(0xf) << ID_AA64ISAR1_BF16_SHIFT)
#define	ID_AA64ISAR1_BF16_VAL(x)	((x) & ID_AA64ISAR1_BF16_MASK)
#define	 ID_AA64ISAR1_BF16_NONE		(UL(0x0) << ID_AA64ISAR1_BF16_SHIFT)
#define	 ID_AA64ISAR1_BF16_IMPL		(UL(0x1) << ID_AA64ISAR1_BF16_SHIFT)
#define	 ID_AA64ISAR1_BF16_EBF		(UL(0x2) << ID_AA64ISAR1_BF16_SHIFT)
#define	ID_AA64ISAR1_DGH_SHIFT		48
#define	ID_AA64ISAR1_DGH_MASK		(UL(0xf) << ID_AA64ISAR1_DGH_SHIFT)
#define	ID_AA64ISAR1_DGH_VAL(x)		((x) & ID_AA64ISAR1_DGH_MASK)
#define	 ID_AA64ISAR1_DGH_NONE		(UL(0x0) << ID_AA64ISAR1_DGH_SHIFT)
#define	 ID_AA64ISAR1_DGH_IMPL		(UL(0x1) << ID_AA64ISAR1_DGH_SHIFT)
#define	ID_AA64ISAR1_I8MM_SHIFT		52
#define	ID_AA64ISAR1_I8MM_MASK		(UL(0xf) << ID_AA64ISAR1_I8MM_SHIFT)
#define	ID_AA64ISAR1_I8MM_VAL(x)	((x) & ID_AA64ISAR1_I8MM_MASK)
#define	 ID_AA64ISAR1_I8MM_NONE		(UL(0x0) << ID_AA64ISAR1_I8MM_SHIFT)
#define	 ID_AA64ISAR1_I8MM_IMPL		(UL(0x1) << ID_AA64ISAR1_I8MM_SHIFT)
#define	ID_AA64ISAR1_XS_SHIFT		56
#define	ID_AA64ISAR1_XS_MASK		(UL(0xf) << ID_AA64ISAR1_XS_SHIFT)
#define	ID_AA64ISAR1_XS_VAL(x)		((x) & ID_AA64ISAR1_XS_MASK)
#define	 ID_AA64ISAR1_XS_NONE		(UL(0x0) << ID_AA64ISAR1_XS_SHIFT)
#define	 ID_AA64ISAR1_XS_IMPL		(UL(0x1) << ID_AA64ISAR1_XS_SHIFT)
#define	ID_AA64ISAR1_LS64_SHIFT		60
#define	ID_AA64ISAR1_LS64_MASK		(UL(0xf) << ID_AA64ISAR1_LS64_SHIFT)
#define	ID_AA64ISAR1_LS64_VAL(x)	((x) & ID_AA64ISAR1_LS64_MASK)
#define	 ID_AA64ISAR1_LS64_NONE		(UL(0x0) << ID_AA64ISAR1_LS64_SHIFT)
#define	 ID_AA64ISAR1_LS64_IMPL		(UL(0x1) << ID_AA64ISAR1_LS64_SHIFT)
#define	 ID_AA64ISAR1_LS64_V		(UL(0x2) << ID_AA64ISAR1_LS64_SHIFT)
#define	 ID_AA64ISAR1_LS64_ACCDATA	(UL(0x3) << ID_AA64ISAR1_LS64_SHIFT)

/* ID_AA64ISAR2_EL1 */
#define	ID_AA64ISAR2_EL1		MRS_REG(ID_AA64ISAR2_EL1)
#define	ID_AA64ISAR2_EL1_REG		MRS_REG_ALT_NAME(ID_AA64ISAR2_EL1)
#define	ID_AA64ISAR2_EL1_op0		3
#define	ID_AA64ISAR2_EL1_op1		0
#define	ID_AA64ISAR2_EL1_CRn		0
#define	ID_AA64ISAR2_EL1_CRm		6
#define	ID_AA64ISAR2_EL1_op2		2
#define	ID_AA64ISAR2_WFxT_SHIFT		0
#define	ID_AA64ISAR2_WFxT_MASK		(UL(0xf) << ID_AA64ISAR2_WFxT_SHIFT)
#define	ID_AA64ISAR2_WFxT_VAL(x)	((x) & ID_AA64ISAR2_WFxT_MASK)
#define	 ID_AA64ISAR2_WFxT_NONE		(UL(0x0) << ID_AA64ISAR2_WFxT_SHIFT)
#define	 ID_AA64ISAR2_WFxT_IMPL		(UL(0x1) << ID_AA64ISAR2_WFxT_SHIFT)
#define	ID_AA64ISAR2_RPRES_SHIFT	4
#define	ID_AA64ISAR2_RPRES_MASK		(UL(0xf) << ID_AA64ISAR2_RPRES_SHIFT)
#define	ID_AA64ISAR2_RPRES_VAL(x)	((x) & ID_AA64ISAR2_RPRES_MASK)
#define	 ID_AA64ISAR2_RPRES_NONE	(UL(0x0) << ID_AA64ISAR2_RPRES_SHIFT)
#define	 ID_AA64ISAR2_RPRES_IMPL	(UL(0x1) << ID_AA64ISAR2_RPRES_SHIFT)
#define	ID_AA64ISAR2_GPA3_SHIFT		8
#define	ID_AA64ISAR2_GPA3_MASK		(UL(0xf) << ID_AA64ISAR2_GPA3_SHIFT)
#define	ID_AA64ISAR2_GPA3_VAL(x)	((x) & ID_AA64ISAR2_GPA3_MASK)
#define	 ID_AA64ISAR2_GPA3_NONE		(UL(0x0) << ID_AA64ISAR2_GPA3_SHIFT)
#define	 ID_AA64ISAR2_GPA3_IMPL		(UL(0x1) << ID_AA64ISAR2_GPA3_SHIFT)
#define	ID_AA64ISAR2_APA3_SHIFT		12
#define	ID_AA64ISAR2_APA3_MASK		(UL(0xf) << ID_AA64ISAR2_APA3_SHIFT)
#define	ID_AA64ISAR2_APA3_VAL(x)	((x) & ID_AA64ISAR2_APA3_MASK)
#define	 ID_AA64ISAR2_APA3_NONE		(UL(0x0) << ID_AA64ISAR2_APA3_SHIFT)
#define	 ID_AA64ISAR2_APA3_PAC		(UL(0x1) << ID_AA64ISAR2_APA3_SHIFT)
#define	 ID_AA64ISAR2_APA3_EPAC		(UL(0x2) << ID_AA64ISAR2_APA3_SHIFT)
#define	 ID_AA64ISAR2_APA3_EPAC2	(UL(0x3) << ID_AA64ISAR2_APA3_SHIFT)
#define	 ID_AA64ISAR2_APA3_FPAC		(UL(0x4) << ID_AA64ISAR2_APA3_SHIFT)
#define	 ID_AA64ISAR2_APA3_FPAC_COMBINED (UL(0x5) << ID_AA64ISAR2_APA3_SHIFT)
#define	ID_AA64ISAR2_MOPS_SHIFT		16
#define	ID_AA64ISAR2_MOPS_MASK		(UL(0xf) << ID_AA64ISAR2_MOPS_SHIFT)
#define	ID_AA64ISAR2_MOPS_VAL(x)	((x) & ID_AA64ISAR2_MOPS_MASK)
#define	 ID_AA64ISAR2_MOPS_NONE		(UL(0x0) << ID_AA64ISAR2_MOPS_SHIFT)
#define	 ID_AA64ISAR2_MOPS_IMPL		(UL(0x1) << ID_AA64ISAR2_MOPS_SHIFT)
#define	ID_AA64ISAR2_BC_SHIFT		20
#define	ID_AA64ISAR2_BC_MASK		(UL(0xf) << ID_AA64ISAR2_BC_SHIFT)
#define	ID_AA64ISAR2_BC_VAL(x)		((x) & ID_AA64ISAR2_BC_MASK)
#define	 ID_AA64ISAR2_BC_NONE		(UL(0x0) << ID_AA64ISAR2_BC_SHIFT)
#define	 ID_AA64ISAR2_BC_IMPL		(UL(0x1) << ID_AA64ISAR2_BC_SHIFT)
#define	ID_AA64ISAR2_PAC_frac_SHIFT	28
#define	ID_AA64ISAR2_PAC_frac_MASK	(UL(0xf) << ID_AA64ISAR2_PAC_frac_SHIFT)
#define	ID_AA64ISAR2_PAC_frac_VAL(x)	((x) & ID_AA64ISAR2_PAC_frac_MASK)
#define	 ID_AA64ISAR2_PAC_frac_NONE	(UL(0x0) << ID_AA64ISAR2_PAC_frac_SHIFT)
#define	 ID_AA64ISAR2_PAC_frac_IMPL	(UL(0x1) << ID_AA64ISAR2_PAC_frac_SHIFT)

/* ID_AA64MMFR0_EL1 */
#define	ID_AA64MMFR0_EL1		MRS_REG(ID_AA64MMFR0_EL1)
#define	ID_AA64MMFR0_EL1_REG		MRS_REG_ALT_NAME(ID_AA64MMFR0_EL1)
#define	ID_AA64MMFR0_EL1_op0		3
#define	ID_AA64MMFR0_EL1_op1		0
#define	ID_AA64MMFR0_EL1_CRn		0
#define	ID_AA64MMFR0_EL1_CRm		7
#define	ID_AA64MMFR0_EL1_op2		0
#define	ID_AA64MMFR0_PARange_SHIFT	0
#define	ID_AA64MMFR0_PARange_MASK	(UL(0xf) << ID_AA64MMFR0_PARange_SHIFT)
#define	ID_AA64MMFR0_PARange_VAL(x)	((x) & ID_AA64MMFR0_PARange_MASK)
#define	 ID_AA64MMFR0_PARange_4G	(UL(0x0) << ID_AA64MMFR0_PARange_SHIFT)
#define	 ID_AA64MMFR0_PARange_64G	(UL(0x1) << ID_AA64MMFR0_PARange_SHIFT)
#define	 ID_AA64MMFR0_PARange_1T	(UL(0x2) << ID_AA64MMFR0_PARange_SHIFT)
#define	 ID_AA64MMFR0_PARange_4T	(UL(0x3) << ID_AA64MMFR0_PARange_SHIFT)
#define	 ID_AA64MMFR0_PARange_16T	(UL(0x4) << ID_AA64MMFR0_PARange_SHIFT)
#define	 ID_AA64MMFR0_PARange_256T	(UL(0x5) << ID_AA64MMFR0_PARange_SHIFT)
#define	 ID_AA64MMFR0_PARange_4P	(UL(0x6) << ID_AA64MMFR0_PARange_SHIFT)
#define	ID_AA64MMFR0_ASIDBits_SHIFT	4
#define	ID_AA64MMFR0_ASIDBits_MASK	(UL(0xf) << ID_AA64MMFR0_ASIDBits_SHIFT)
#define	ID_AA64MMFR0_ASIDBits_VAL(x)	((x) & ID_AA64MMFR0_ASIDBits_MASK)
#define	 ID_AA64MMFR0_ASIDBits_8	(UL(0x0) << ID_AA64MMFR0_ASIDBits_SHIFT)
#define	 ID_AA64MMFR0_ASIDBits_16	(UL(0x2) << ID_AA64MMFR0_ASIDBits_SHIFT)
#define	ID_AA64MMFR0_BigEnd_SHIFT	8
#define	ID_AA64MMFR0_BigEnd_MASK	(UL(0xf) << ID_AA64MMFR0_BigEnd_SHIFT)
#define	ID_AA64MMFR0_BigEnd_VAL(x)	((x) & ID_AA64MMFR0_BigEnd_MASK)
#define	 ID_AA64MMFR0_BigEnd_FIXED	(UL(0x0) << ID_AA64MMFR0_BigEnd_SHIFT)
#define	 ID_AA64MMFR0_BigEnd_MIXED	(UL(0x1) << ID_AA64MMFR0_BigEnd_SHIFT)
#define	ID_AA64MMFR0_SNSMem_SHIFT	12
#define	ID_AA64MMFR0_SNSMem_MASK	(UL(0xf) << ID_AA64MMFR0_SNSMem_SHIFT)
#define	ID_AA64MMFR0_SNSMem_VAL(x)	((x) & ID_AA64MMFR0_SNSMem_MASK)
#define	 ID_AA64MMFR0_SNSMem_NONE	(UL(0x0) << ID_AA64MMFR0_SNSMem_SHIFT)
#define	 ID_AA64MMFR0_SNSMem_DISTINCT	(UL(0x1) << ID_AA64MMFR0_SNSMem_SHIFT)
#define	ID_AA64MMFR0_BigEndEL0_SHIFT	16
#define	ID_AA64MMFR0_BigEndEL0_MASK	(UL(0xf) << ID_AA64MMFR0_BigEndEL0_SHIFT)
#define	ID_AA64MMFR0_BigEndEL0_VAL(x)	((x) & ID_AA64MMFR0_BigEndEL0_MASK)
#define	 ID_AA64MMFR0_BigEndEL0_FIXED	(UL(0x0) << ID_AA64MMFR0_BigEndEL0_SHIFT)
#define	 ID_AA64MMFR0_BigEndEL0_MIXED	(UL(0x1) << ID_AA64MMFR0_BigEndEL0_SHIFT)
#define	ID_AA64MMFR0_TGran16_SHIFT	20
#define	ID_AA64MMFR0_TGran16_MASK	(UL(0xf) << ID_AA64MMFR0_TGran16_SHIFT)
#define	ID_AA64MMFR0_TGran16_VAL(x)	((x) & ID_AA64MMFR0_TGran16_MASK)
#define	 ID_AA64MMFR0_TGran16_NONE	(UL(0x0) << ID_AA64MMFR0_TGran16_SHIFT)
#define	 ID_AA64MMFR0_TGran16_IMPL	(UL(0x1) << ID_AA64MMFR0_TGran16_SHIFT)
#define	 ID_AA64MMFR0_TGran16_LPA2	(UL(0x2) << ID_AA64MMFR0_TGran16_SHIFT)
#define	ID_AA64MMFR0_TGran64_SHIFT	24
#define	ID_AA64MMFR0_TGran64_MASK	(UL(0xf) << ID_AA64MMFR0_TGran64_SHIFT)
#define	ID_AA64MMFR0_TGran64_VAL(x)	((x) & ID_AA64MMFR0_TGran64_MASK)
#define	 ID_AA64MMFR0_TGran64_IMPL	(UL(0x0) << ID_AA64MMFR0_TGran64_SHIFT)
#define	 ID_AA64MMFR0_TGran64_NONE	(UL(0xf) << ID_AA64MMFR0_TGran64_SHIFT)
#define	ID_AA64MMFR0_TGran4_SHIFT	28
#define	ID_AA64MMFR0_TGran4_MASK	(UL(0xf) << ID_AA64MMFR0_TGran4_SHIFT)
#define	ID_AA64MMFR0_TGran4_VAL(x)	((x) & ID_AA64MMFR0_TGran4_MASK)
#define	 ID_AA64MMFR0_TGran4_IMPL	(UL(0x0) << ID_AA64MMFR0_TGran4_SHIFT)
#define	 ID_AA64MMFR0_TGran4_LPA2	(UL(0x1) << ID_AA64MMFR0_TGran4_SHIFT)
#define	 ID_AA64MMFR0_TGran4_NONE	(UL(0xf) << ID_AA64MMFR0_TGran4_SHIFT)
#define	ID_AA64MMFR0_TGran16_2_SHIFT	32
#define	ID_AA64MMFR0_TGran16_2_MASK	(UL(0xf) << ID_AA64MMFR0_TGran16_2_SHIFT)
#define	ID_AA64MMFR0_TGran16_2_VAL(x)	((x) & ID_AA64MMFR0_TGran16_2_MASK)
#define	 ID_AA64MMFR0_TGran16_2_TGran16	(UL(0x0) << ID_AA64MMFR0_TGran16_2_SHIFT)
#define	 ID_AA64MMFR0_TGran16_2_NONE	(UL(0x1) << ID_AA64MMFR0_TGran16_2_SHIFT)
#define	 ID_AA64MMFR0_TGran16_2_IMPL	(UL(0x2) << ID_AA64MMFR0_TGran16_2_SHIFT)
#define	 ID_AA64MMFR0_TGran16_2_LPA2	(UL(0x3) << ID_AA64MMFR0_TGran16_2_SHIFT)
#define	ID_AA64MMFR0_TGran64_2_SHIFT	36
#define	ID_AA64MMFR0_TGran64_2_MASK	(UL(0xf) << ID_AA64MMFR0_TGran64_2_SHIFT)
#define	ID_AA64MMFR0_TGran64_2_VAL(x)	((x) & ID_AA64MMFR0_TGran64_2_MASK)
#define	 ID_AA64MMFR0_TGran64_2_TGran64	(UL(0x0) << ID_AA64MMFR0_TGran64_2_SHIFT)
#define	 ID_AA64MMFR0_TGran64_2_NONE	(UL(0x1) << ID_AA64MMFR0_TGran64_2_SHIFT)
#define	 ID_AA64MMFR0_TGran64_2_IMPL	(UL(0x2) << ID_AA64MMFR0_TGran64_2_SHIFT)
#define	ID_AA64MMFR0_TGran4_2_SHIFT	40
#define	ID_AA64MMFR0_TGran4_2_MASK	(UL(0xf) << ID_AA64MMFR0_TGran4_2_SHIFT)
#define	ID_AA64MMFR0_TGran4_2_VAL(x)	((x) & ID_AA64MMFR0_TGran4_2_MASK)
#define	 ID_AA64MMFR0_TGran4_2_TGran4	(UL(0x0) << ID_AA64MMFR0_TGran4_2_SHIFT)
#define	 ID_AA64MMFR0_TGran4_2_NONE	(UL(0x1) << ID_AA64MMFR0_TGran4_2_SHIFT)
#define	 ID_AA64MMFR0_TGran4_2_IMPL	(UL(0x2) << ID_AA64MMFR0_TGran4_2_SHIFT)
#define	 ID_AA64MMFR0_TGran4_2_LPA2	(UL(0x3) << ID_AA64MMFR0_TGran4_2_SHIFT)
#define	ID_AA64MMFR0_ExS_SHIFT		44
#define	ID_AA64MMFR0_ExS_MASK		(UL(0xf) << ID_AA64MMFR0_ExS_SHIFT)
#define	ID_AA64MMFR0_ExS_VAL(x)		((x) & ID_AA64MMFR0_ExS_MASK)
#define	 ID_AA64MMFR0_ExS_ALL		(UL(0x0) << ID_AA64MMFR0_ExS_SHIFT)
#define	 ID_AA64MMFR0_ExS_IMPL		(UL(0x1) << ID_AA64MMFR0_ExS_SHIFT)
#define	ID_AA64MMFR0_FGT_SHIFT		56
#define	ID_AA64MMFR0_FGT_MASK		(UL(0xf) << ID_AA64MMFR0_FGT_SHIFT)
#define	ID_AA64MMFR0_FGT_VAL(x)		((x) & ID_AA64MMFR0_FGT_MASK)
#define	 ID_AA64MMFR0_FGT_NONE		(UL(0x0) << ID_AA64MMFR0_FGT_SHIFT)
#define	 ID_AA64MMFR0_FGT_IMPL		(UL(0x1) << ID_AA64MMFR0_FGT_SHIFT)
#define	ID_AA64MMFR0_ECV_SHIFT		60
#define	ID_AA64MMFR0_ECV_MASK		(UL(0xf) << ID_AA64MMFR0_ECV_SHIFT)
#define	ID_AA64MMFR0_ECV_VAL(x)		((x) & ID_AA64MMFR0_ECV_MASK)
#define	 ID_AA64MMFR0_ECV_NONE		(UL(0x0) << ID_AA64MMFR0_ECV_SHIFT)
#define	 ID_AA64MMFR0_ECV_IMPL		(UL(0x1) << ID_AA64MMFR0_ECV_SHIFT)
#define	 ID_AA64MMFR0_ECV_CNTHCTL	(UL(0x2) << ID_AA64MMFR0_ECV_SHIFT)

/* ID_AA64MMFR1_EL1 */
#define	ID_AA64MMFR1_EL1		MRS_REG(ID_AA64MMFR1_EL1)
#define	ID_AA64MMFR1_EL1_REG		MRS_REG_ALT_NAME(ID_AA64MMFR1_EL1)
#define	ID_AA64MMFR1_EL1_op0		3
#define	ID_AA64MMFR1_EL1_op1		0
#define	ID_AA64MMFR1_EL1_CRn		0
#define	ID_AA64MMFR1_EL1_CRm		7
#define	ID_AA64MMFR1_EL1_op2		1
#define	ID_AA64MMFR1_HAFDBS_SHIFT	0
#define	ID_AA64MMFR1_HAFDBS_MASK	(UL(0xf) << ID_AA64MMFR1_HAFDBS_SHIFT)
#define	ID_AA64MMFR1_HAFDBS_VAL(x)	((x) & ID_AA64MMFR1_HAFDBS_MASK)
#define	 ID_AA64MMFR1_HAFDBS_NONE	(UL(0x0) << ID_AA64MMFR1_HAFDBS_SHIFT)
#define	 ID_AA64MMFR1_HAFDBS_AF		(UL(0x1) << ID_AA64MMFR1_HAFDBS_SHIFT)
#define	 ID_AA64MMFR1_HAFDBS_AF_DBS	(UL(0x2) << ID_AA64MMFR1_HAFDBS_SHIFT)
#define	ID_AA64MMFR1_VMIDBits_SHIFT	4
#define	ID_AA64MMFR1_VMIDBits_MASK	(UL(0xf) << ID_AA64MMFR1_VMIDBits_SHIFT)
#define	ID_AA64MMFR1_VMIDBits_VAL(x)	((x) & ID_AA64MMFR1_VMIDBits_MASK)
#define	 ID_AA64MMFR1_VMIDBits_8	(UL(0x0) << ID_AA64MMFR1_VMIDBits_SHIFT)
#define	 ID_AA64MMFR1_VMIDBits_16	(UL(0x2) << ID_AA64MMFR1_VMIDBits_SHIFT)
#define	ID_AA64MMFR1_VH_SHIFT		8
#define	ID_AA64MMFR1_VH_MASK		(UL(0xf) << ID_AA64MMFR1_VH_SHIFT)
#define	ID_AA64MMFR1_VH_VAL(x)		((x) & ID_AA64MMFR1_VH_MASK)
#define	 ID_AA64MMFR1_VH_NONE		(UL(0x0) << ID_AA64MMFR1_VH_SHIFT)
#define	 ID_AA64MMFR1_VH_IMPL		(UL(0x1) << ID_AA64MMFR1_VH_SHIFT)
#define	ID_AA64MMFR1_HPDS_SHIFT		12
#define	ID_AA64MMFR1_HPDS_MASK		(UL(0xf) << ID_AA64MMFR1_HPDS_SHIFT)
#define	ID_AA64MMFR1_HPDS_VAL(x)	((x) & ID_AA64MMFR1_HPDS_MASK)
#define	 ID_AA64MMFR1_HPDS_NONE		(UL(0x0) << ID_AA64MMFR1_HPDS_SHIFT)
#define	 ID_AA64MMFR1_HPDS_HPD		(UL(0x1) << ID_AA64MMFR1_HPDS_SHIFT)
#define	 ID_AA64MMFR1_HPDS_TTPBHA	(UL(0x2) << ID_AA64MMFR1_HPDS_SHIFT)
#define	ID_AA64MMFR1_LO_SHIFT		16
#define	ID_AA64MMFR1_LO_MASK		(UL(0xf) << ID_AA64MMFR1_LO_SHIFT)
#define	ID_AA64MMFR1_LO_VAL(x)		((x) & ID_AA64MMFR1_LO_MASK)
#define	 ID_AA64MMFR1_LO_NONE		(UL(0x0) << ID_AA64MMFR1_LO_SHIFT)
#define	 ID_AA64MMFR1_LO_IMPL		(UL(0x1) << ID_AA64MMFR1_LO_SHIFT)
#define	ID_AA64MMFR1_PAN_SHIFT		20
#define	ID_AA64MMFR1_PAN_MASK		(UL(0xf) << ID_AA64MMFR1_PAN_SHIFT)
#define	ID_AA64MMFR1_PAN_VAL(x)		((x) & ID_AA64MMFR1_PAN_MASK)
#define	 ID_AA64MMFR1_PAN_NONE		(UL(0x0) << ID_AA64MMFR1_PAN_SHIFT)
#define	 ID_AA64MMFR1_PAN_IMPL		(UL(0x1) << ID_AA64MMFR1_PAN_SHIFT)
#define	 ID_AA64MMFR1_PAN_ATS1E1	(UL(0x2) << ID_AA64MMFR1_PAN_SHIFT)
#define	 ID_AA64MMFR1_PAN_EPAN		(UL(0x2) << ID_AA64MMFR1_PAN_SHIFT)
#define	ID_AA64MMFR1_SpecSEI_SHIFT	24
#define	ID_AA64MMFR1_SpecSEI_MASK	(UL(0xf) << ID_AA64MMFR1_SpecSEI_SHIFT)
#define	ID_AA64MMFR1_SpecSEI_VAL(x)	((x) & ID_AA64MMFR1_SpecSEI_MASK)
#define	 ID_AA64MMFR1_SpecSEI_NONE	(UL(0x0) << ID_AA64MMFR1_SpecSEI_SHIFT)
#define	 ID_AA64MMFR1_SpecSEI_IMPL	(UL(0x1) << ID_AA64MMFR1_SpecSEI_SHIFT)
#define	ID_AA64MMFR1_XNX_SHIFT		28
#define	ID_AA64MMFR1_XNX_MASK		(UL(0xf) << ID_AA64MMFR1_XNX_SHIFT)
#define	ID_AA64MMFR1_XNX_VAL(x)		((x) & ID_AA64MMFR1_XNX_MASK)
#define	 ID_AA64MMFR1_XNX_NONE		(UL(0x0) << ID_AA64MMFR1_XNX_SHIFT)
#define	 ID_AA64MMFR1_XNX_IMPL		(UL(0x1) << ID_AA64MMFR1_XNX_SHIFT)
#define	ID_AA64MMFR1_TWED_SHIFT		32
#define	ID_AA64MMFR1_TWED_MASK		(UL(0xf) << ID_AA64MMFR1_TWED_SHIFT)
#define	ID_AA64MMFR1_TWED_VAL(x)	((x) & ID_AA64MMFR1_TWED_MASK)
#define	 ID_AA64MMFR1_TWED_NONE		(UL(0x0) << ID_AA64MMFR1_TWED_SHIFT)
#define	 ID_AA64MMFR1_TWED_IMPL		(UL(0x1) << ID_AA64MMFR1_TWED_SHIFT)
#define	ID_AA64MMFR1_ETS_SHIFT		36
#define	ID_AA64MMFR1_ETS_MASK		(UL(0xf) << ID_AA64MMFR1_ETS_SHIFT)
#define	ID_AA64MMFR1_ETS_VAL(x)		((x) & ID_AA64MMFR1_ETS_MASK)
#define	 ID_AA64MMFR1_ETS_NONE		(UL(0x0) << ID_AA64MMFR1_ETS_SHIFT)
#define	 ID_AA64MMFR1_ETS_IMPL		(UL(0x1) << ID_AA64MMFR1_ETS_SHIFT)
#define	ID_AA64MMFR1_HCX_SHIFT		40
#define	ID_AA64MMFR1_HCX_MASK		(UL(0xf) << ID_AA64MMFR1_HCX_SHIFT)
#define	ID_AA64MMFR1_HCX_VAL(x)		((x) & ID_AA64MMFR1_HCX_MASK)
#define	 ID_AA64MMFR1_HCX_NONE		(UL(0x0) << ID_AA64MMFR1_HCX_SHIFT)
#define	 ID_AA64MMFR1_HCX_IMPL		(UL(0x1) << ID_AA64MMFR1_HCX_SHIFT)
#define	ID_AA64MMFR1_AFP_SHIFT		44
#define	ID_AA64MMFR1_AFP_MASK		(UL(0xf) << ID_AA64MMFR1_AFP_SHIFT)
#define	ID_AA64MMFR1_AFP_VAL(x)		((x) & ID_AA64MMFR1_AFP_MASK)
#define	 ID_AA64MMFR1_AFP_NONE		(UL(0x0) << ID_AA64MMFR1_AFP_SHIFT)
#define	 ID_AA64MMFR1_AFP_IMPL		(UL(0x1) << ID_AA64MMFR1_AFP_SHIFT)
#define	ID_AA64MMFR1_nTLBPA_SHIFT	48
#define	ID_AA64MMFR1_nTLBPA_MASK	(UL(0xf) << ID_AA64MMFR1_nTLBPA_SHIFT)
#define	ID_AA64MMFR1_nTLBPA_VAL(x)	((x) & ID_AA64MMFR1_nTLBPA_MASK)
#define	 ID_AA64MMFR1_nTLBPA_NONE	(UL(0x0) << ID_AA64MMFR1_nTLBPA_SHIFT)
#define	 ID_AA64MMFR1_nTLBPA_IMPL	(UL(0x1) << ID_AA64MMFR1_nTLBPA_SHIFT)
#define	ID_AA64MMFR1_TIDCP1_SHIFT	52
#define	ID_AA64MMFR1_TIDCP1_MASK	(UL(0xf) << ID_AA64MMFR1_TIDCP1_SHIFT)
#define	ID_AA64MMFR1_TIDCP1_VAL(x)	((x) & ID_AA64MMFR1_TIDCP1_MASK)
#define	 ID_AA64MMFR1_TIDCP1_NONE	(UL(0x0) << ID_AA64MMFR1_TIDCP1_SHIFT)
#define	 ID_AA64MMFR1_TIDCP1_IMPL	(UL(0x1) << ID_AA64MMFR1_TIDCP1_SHIFT)
#define	ID_AA64MMFR1_CMOVW_SHIFT	56
#define	ID_AA64MMFR1_CMOVW_MASK		(UL(0xf) << ID_AA64MMFR1_CMOVW_SHIFT)
#define	ID_AA64MMFR1_CMOVW_VAL(x)	((x) & ID_AA64MMFR1_CMOVW_MASK)
#define	 ID_AA64MMFR1_CMOVW_NONE	(UL(0x0) << ID_AA64MMFR1_CMOVW_SHIFT)
#define	 ID_AA64MMFR1_CMOVW_IMPL	(UL(0x1) << ID_AA64MMFR1_CMOVW_SHIFT)

/* ID_AA64MMFR2_EL1 */
#define	ID_AA64MMFR2_EL1		MRS_REG(ID_AA64MMFR2_EL1)
#define	ID_AA64MMFR2_EL1_REG		MRS_REG_ALT_NAME(ID_AA64MMFR2_EL1)
#define	ID_AA64MMFR2_EL1_op0		3
#define	ID_AA64MMFR2_EL1_op1		0
#define	ID_AA64MMFR2_EL1_CRn		0
#define	ID_AA64MMFR2_EL1_CRm		7
#define	ID_AA64MMFR2_EL1_op2		2
#define	ID_AA64MMFR2_CnP_SHIFT		0
#define	ID_AA64MMFR2_CnP_MASK		(UL(0xf) << ID_AA64MMFR2_CnP_SHIFT)
#define	ID_AA64MMFR2_CnP_VAL(x)		((x) & ID_AA64MMFR2_CnP_MASK)
#define	 ID_AA64MMFR2_CnP_NONE		(UL(0x0) << ID_AA64MMFR2_CnP_SHIFT)
#define	 ID_AA64MMFR2_CnP_IMPL		(UL(0x1) << ID_AA64MMFR2_CnP_SHIFT)
#define	ID_AA64MMFR2_UAO_SHIFT		4
#define	ID_AA64MMFR2_UAO_MASK		(UL(0xf) << ID_AA64MMFR2_UAO_SHIFT)
#define	ID_AA64MMFR2_UAO_VAL(x)		((x) & ID_AA64MMFR2_UAO_MASK)
#define	 ID_AA64MMFR2_UAO_NONE		(UL(0x0) << ID_AA64MMFR2_UAO_SHIFT)
#define	 ID_AA64MMFR2_UAO_IMPL		(UL(0x1) << ID_AA64MMFR2_UAO_SHIFT)
#define	ID_AA64MMFR2_LSM_SHIFT		8
#define	ID_AA64MMFR2_LSM_MASK		(UL(0xf) << ID_AA64MMFR2_LSM_SHIFT)
#define	ID_AA64MMFR2_LSM_VAL(x)		((x) & ID_AA64MMFR2_LSM_MASK)
#define	 ID_AA64MMFR2_LSM_NONE		(UL(0x0) << ID_AA64MMFR2_LSM_SHIFT)
#define	 ID_AA64MMFR2_LSM_IMPL		(UL(0x1) << ID_AA64MMFR2_LSM_SHIFT)
#define	ID_AA64MMFR2_IESB_SHIFT		12
#define	ID_AA64MMFR2_IESB_MASK		(UL(0xf) << ID_AA64MMFR2_IESB_SHIFT)
#define	ID_AA64MMFR2_IESB_VAL(x)	((x) & ID_AA64MMFR2_IESB_MASK)
#define	 ID_AA64MMFR2_IESB_NONE		(UL(0x0) << ID_AA64MMFR2_IESB_SHIFT)
#define	 ID_AA64MMFR2_IESB_IMPL		(UL(0x1) << ID_AA64MMFR2_IESB_SHIFT)
#define	ID_AA64MMFR2_VARange_SHIFT	16
#define	ID_AA64MMFR2_VARange_MASK	(UL(0xf) << ID_AA64MMFR2_VARange_SHIFT)
#define	ID_AA64MMFR2_VARange_VAL(x)	((x) & ID_AA64MMFR2_VARange_MASK)
#define	 ID_AA64MMFR2_VARange_48	(UL(0x0) << ID_AA64MMFR2_VARange_SHIFT)
#define	 ID_AA64MMFR2_VARange_52	(UL(0x1) << ID_AA64MMFR2_VARange_SHIFT)
#define	ID_AA64MMFR2_CCIDX_SHIFT	20
#define	ID_AA64MMFR2_CCIDX_MASK		(UL(0xf) << ID_AA64MMFR2_CCIDX_SHIFT)
#define	ID_AA64MMFR2_CCIDX_VAL(x)	((x) & ID_AA64MMFR2_CCIDX_MASK)
#define	 ID_AA64MMFR2_CCIDX_32		(UL(0x0) << ID_AA64MMFR2_CCIDX_SHIFT)
#define	 ID_AA64MMFR2_CCIDX_64		(UL(0x1) << ID_AA64MMFR2_CCIDX_SHIFT)
#define	ID_AA64MMFR2_NV_SHIFT		24
#define	ID_AA64MMFR2_NV_MASK		(UL(0xf) << ID_AA64MMFR2_NV_SHIFT)
#define	ID_AA64MMFR2_NV_VAL(x)		((x) & ID_AA64MMFR2_NV_MASK)
#define	 ID_AA64MMFR2_NV_NONE		(UL(0x0) << ID_AA64MMFR2_NV_SHIFT)
#define	 ID_AA64MMFR2_NV_8_3		(UL(0x1) << ID_AA64MMFR2_NV_SHIFT)
#define	 ID_AA64MMFR2_NV_8_4		(UL(0x2) << ID_AA64MMFR2_NV_SHIFT)
#define	ID_AA64MMFR2_ST_SHIFT		28
#define	ID_AA64MMFR2_ST_MASK		(UL(0xf) << ID_AA64MMFR2_ST_SHIFT)
#define	ID_AA64MMFR2_ST_VAL(x)		((x) & ID_AA64MMFR2_ST_MASK)
#define	 ID_AA64MMFR2_ST_NONE		(UL(0x0) << ID_AA64MMFR2_ST_SHIFT)
#define	 ID_AA64MMFR2_ST_IMPL		(UL(0x1) << ID_AA64MMFR2_ST_SHIFT)
#define	ID_AA64MMFR2_AT_SHIFT		32
#define	ID_AA64MMFR2_AT_MASK		(UL(0xf) << ID_AA64MMFR2_AT_SHIFT)
#define	ID_AA64MMFR2_AT_VAL(x)		((x) & ID_AA64MMFR2_AT_MASK)
#define	 ID_AA64MMFR2_AT_NONE		(UL(0x0) << ID_AA64MMFR2_AT_SHIFT)
#define	 ID_AA64MMFR2_AT_IMPL		(UL(0x1) << ID_AA64MMFR2_AT_SHIFT)
#define	ID_AA64MMFR2_IDS_SHIFT		36
#define	ID_AA64MMFR2_IDS_MASK		(UL(0xf) << ID_AA64MMFR2_IDS_SHIFT)
#define	ID_AA64MMFR2_IDS_VAL(x)		((x) & ID_AA64MMFR2_IDS_MASK)
#define	 ID_AA64MMFR2_IDS_NONE		(UL(0x0) << ID_AA64MMFR2_IDS_SHIFT)
#define	 ID_AA64MMFR2_IDS_IMPL		(UL(0x1) << ID_AA64MMFR2_IDS_SHIFT)
#define	ID_AA64MMFR2_FWB_SHIFT		40
#define	ID_AA64MMFR2_FWB_MASK		(UL(0xf) << ID_AA64MMFR2_FWB_SHIFT)
#define	ID_AA64MMFR2_FWB_VAL(x)		((x) & ID_AA64MMFR2_FWB_MASK)
#define	 ID_AA64MMFR2_FWB_NONE		(UL(0x0) << ID_AA64MMFR2_FWB_SHIFT)
#define	 ID_AA64MMFR2_FWB_IMPL		(UL(0x1) << ID_AA64MMFR2_FWB_SHIFT)
#define	ID_AA64MMFR2_TTL_SHIFT		48
#define	ID_AA64MMFR2_TTL_MASK		(UL(0xf) << ID_AA64MMFR2_TTL_SHIFT)
#define	ID_AA64MMFR2_TTL_VAL(x)		((x) & ID_AA64MMFR2_TTL_MASK)
#define	 ID_AA64MMFR2_TTL_NONE		(UL(0x0) << ID_AA64MMFR2_TTL_SHIFT)
#define	 ID_AA64MMFR2_TTL_IMPL		(UL(0x1) << ID_AA64MMFR2_TTL_SHIFT)
#define	ID_AA64MMFR2_BBM_SHIFT		52
#define	ID_AA64MMFR2_BBM_MASK		(UL(0xf) << ID_AA64MMFR2_BBM_SHIFT)
#define	ID_AA64MMFR2_BBM_VAL(x)		((x) & ID_AA64MMFR2_BBM_MASK)
#define	 ID_AA64MMFR2_BBM_LEVEL0	(UL(0x0) << ID_AA64MMFR2_BBM_SHIFT)
#define	 ID_AA64MMFR2_BBM_LEVEL1	(UL(0x1) << ID_AA64MMFR2_BBM_SHIFT)
#define	 ID_AA64MMFR2_BBM_LEVEL2	(UL(0x2) << ID_AA64MMFR2_BBM_SHIFT)
#define	ID_AA64MMFR2_EVT_SHIFT		56
#define	ID_AA64MMFR2_EVT_MASK		(UL(0xf) << ID_AA64MMFR2_EVT_SHIFT)
#define	ID_AA64MMFR2_EVT_VAL(x)		((x) & ID_AA64MMFR2_EVT_MASK)
#define	 ID_AA64MMFR2_EVT_NONE		(UL(0x0) << ID_AA64MMFR2_EVT_SHIFT)
#define	 ID_AA64MMFR2_EVT_8_2		(UL(0x1) << ID_AA64MMFR2_EVT_SHIFT)
#define	 ID_AA64MMFR2_EVT_8_5		(UL(0x2) << ID_AA64MMFR2_EVT_SHIFT)
#define	ID_AA64MMFR2_E0PD_SHIFT		60
#define	ID_AA64MMFR2_E0PD_MASK		(UL(0xf) << ID_AA64MMFR2_E0PD_SHIFT)
#define	ID_AA64MMFR2_E0PD_VAL(x)	((x) & ID_AA64MMFR2_E0PD_MASK)
#define	 ID_AA64MMFR2_E0PD_NONE		(UL(0x0) << ID_AA64MMFR2_E0PD_SHIFT)
#define	 ID_AA64MMFR2_E0PD_IMPL		(UL(0x1) << ID_AA64MMFR2_E0PD_SHIFT)

/* ID_AA64MMFR3_EL1 */
#define	ID_AA64MMFR3_EL1		MRS_REG(ID_AA64MMFR3_EL1)
#define	ID_AA64MMFR3_EL1_REG		MRS_REG_ALT_NAME(ID_AA64MMFR3_EL1)
#define	ID_AA64MMFR3_EL1_op0		3
#define	ID_AA64MMFR3_EL1_op1		0
#define	ID_AA64MMFR3_EL1_CRn		0
#define	ID_AA64MMFR3_EL1_CRm		7
#define	ID_AA64MMFR3_EL1_op2		3
#define	ID_AA64MMFR3_TCRX_SHIFT		0
#define	ID_AA64MMFR3_TCRX_MASK		(UL(0xf) << ID_AA64MMFR3_TCRX_SHIFT)
#define	ID_AA64MMFR3_TCRX_VAL(x)	((x) & ID_AA64MMFR3_TCRX_MASK)
#define	 ID_AA64MMFR3_TCRX_NONE		(UL(0x0) << ID_AA64MMFR3_TCRX_SHIFT)
#define	 ID_AA64MMFR3_TCRX_IMPL		(UL(0x1) << ID_AA64MMFR3_TCRX_SHIFT)
#define	ID_AA64MMFR3_SCTLRX_SHIFT	4
#define	ID_AA64MMFR3_SCTLRX_MASK	(UL(0xf) << ID_AA64MMFR3_SCTLRX_SHIFT)
#define	ID_AA64MMFR3_SCTLRX_VAL(x)	((x) & ID_AA64MMFR3_SCTLRX_MASK)
#define	 ID_AA64MMFR3_SCTLRX_NONE	(UL(0x0) << ID_AA64MMFR3_SCTLRX_SHIFT)
#define	 ID_AA64MMFR3_SCTLRX_IMPL	(UL(0x1) << ID_AA64MMFR3_SCTLRX_SHIFT)
#define	ID_AA64MMFR3_MEC_SHIFT		28
#define	ID_AA64MMFR3_MEC_MASK		(UL(0xf) << ID_AA64MMFR3_MEC_SHIFT)
#define	ID_AA64MMFR3_MEC_VAL(x)	((x) & ID_AA64MMFR3_MEC_MASK)
#define	 ID_AA64MMFR3_MEC_NONE		(UL(0x0) << ID_AA64MMFR3_MEC_SHIFT)
#define	 ID_AA64MMFR3_MEC_IMPL		(UL(0x1) << ID_AA64MMFR3_MEC_SHIFT)
#define	ID_AA64MMFR3_Spec_FPACC_SHIFT	60
#define	ID_AA64MMFR3_Spec_FPACC_MASK	(UL(0xf) << ID_AA64MMFR3_Spec_FPACC_SHIFT)
#define	ID_AA64MMFR3_Spec_FPACC_VAL(x)	((x) & ID_AA64MMFR3_Spec_FPACC_MASK)
#define	 ID_AA64MMFR3_Spec_FPACC_NONE	(UL(0x0) << ID_AA64MMFR3_Spec_FPACC_SHIFT)
#define	 ID_AA64MMFR3_Spec_FPACC_IMPL	(UL(0x1) << ID_AA64MMFR3_Spec_FPACC_SHIFT)

/* ID_AA64MMFR4_EL1 */
#define	ID_AA64MMFR4_EL1		MRS_REG(ID_AA64MMFR4_EL1)
#define	ID_AA64MMFR4_EL1_REG		MRS_REG_ALT_NAME(ID_AA64MMFR4_EL1)
#define	ID_AA64MMFR4_EL1_op0		3
#define	ID_AA64MMFR4_EL1_op1		0
#define	ID_AA64MMFR4_EL1_CRn		0
#define	ID_AA64MMFR4_EL1_CRm		7
#define	ID_AA64MMFR4_EL1_op2		4

/* ID_AA64PFR0_EL1 */
#define	ID_AA64PFR0_EL1			MRS_REG(ID_AA64PFR0_EL1)
#define	ID_AA64PFR0_EL1_REG		MRS_REG_ALT_NAME(ID_AA64PFR0_EL1)
#define	ID_AA64PFR0_EL1_op0		3
#define	ID_AA64PFR0_EL1_op1		0
#define	ID_AA64PFR0_EL1_CRn		0
#define	ID_AA64PFR0_EL1_CRm		4
#define	ID_AA64PFR0_EL1_op2		0
#define	ID_AA64PFR0_EL0_SHIFT		0
#define	ID_AA64PFR0_EL0_MASK		(UL(0xf) << ID_AA64PFR0_EL0_SHIFT)
#define	ID_AA64PFR0_EL0_VAL(x)		((x) & ID_AA64PFR0_EL0_MASK)
#define	 ID_AA64PFR0_EL0_64		(UL(0x1) << ID_AA64PFR0_EL0_SHIFT)
#define	 ID_AA64PFR0_EL0_64_32		(UL(0x2) << ID_AA64PFR0_EL0_SHIFT)
#define	ID_AA64PFR0_EL1_SHIFT		4
#define	ID_AA64PFR0_EL1_MASK		(UL(0xf) << ID_AA64PFR0_EL1_SHIFT)
#define	ID_AA64PFR0_EL1_VAL(x)		((x) & ID_AA64PFR0_EL1_MASK)
#define	 ID_AA64PFR0_EL1_64		(UL(0x1) << ID_AA64PFR0_EL1_SHIFT)
#define	 ID_AA64PFR0_EL1_64_32		(UL(0x2) << ID_AA64PFR0_EL1_SHIFT)
#define	ID_AA64PFR0_EL2_SHIFT		8
#define	ID_AA64PFR0_EL2_MASK		(UL(0xf) << ID_AA64PFR0_EL2_SHIFT)
#define	ID_AA64PFR0_EL2_VAL(x)		((x) & ID_AA64PFR0_EL2_MASK)
#define	 ID_AA64PFR0_EL2_NONE		(UL(0x0) << ID_AA64PFR0_EL2_SHIFT)
#define	 ID_AA64PFR0_EL2_64		(UL(0x1) << ID_AA64PFR0_EL2_SHIFT)
#define	 ID_AA64PFR0_EL2_64_32		(UL(0x2) << ID_AA64PFR0_EL2_SHIFT)
#define	ID_AA64PFR0_EL3_SHIFT		12
#define	ID_AA64PFR0_EL3_MASK		(UL(0xf) << ID_AA64PFR0_EL3_SHIFT)
#define	ID_AA64PFR0_EL3_VAL(x)		((x) & ID_AA64PFR0_EL3_MASK)
#define	 ID_AA64PFR0_EL3_NONE		(UL(0x0) << ID_AA64PFR0_EL3_SHIFT)
#define	 ID_AA64PFR0_EL3_64		(UL(0x1) << ID_AA64PFR0_EL3_SHIFT)
#define	 ID_AA64PFR0_EL3_64_32		(UL(0x2) << ID_AA64PFR0_EL3_SHIFT)
#define	ID_AA64PFR0_FP_SHIFT		16
#define	ID_AA64PFR0_FP_MASK		(UL(0xf) << ID_AA64PFR0_FP_SHIFT)
#define	ID_AA64PFR0_FP_VAL(x)		((x) & ID_AA64PFR0_FP_MASK)
#define	 ID_AA64PFR0_FP_IMPL		(UL(0x0) << ID_AA64PFR0_FP_SHIFT)
#define	 ID_AA64PFR0_FP_HP		(UL(0x1) << ID_AA64PFR0_FP_SHIFT)
#define	 ID_AA64PFR0_FP_NONE		(UL(0xf) << ID_AA64PFR0_FP_SHIFT)
#define	ID_AA64PFR0_AdvSIMD_SHIFT	20
#define	ID_AA64PFR0_AdvSIMD_MASK	(UL(0xf) << ID_AA64PFR0_AdvSIMD_SHIFT)
#define	ID_AA64PFR0_AdvSIMD_VAL(x)	((x) & ID_AA64PFR0_AdvSIMD_MASK)
#define	 ID_AA64PFR0_AdvSIMD_IMPL	(UL(0x0) << ID_AA64PFR0_AdvSIMD_SHIFT)
#define	 ID_AA64PFR0_AdvSIMD_HP		(UL(0x1) << ID_AA64PFR0_AdvSIMD_SHIFT)
#define	 ID_AA64PFR0_AdvSIMD_NONE	(UL(0xf) << ID_AA64PFR0_AdvSIMD_SHIFT)
#define	ID_AA64PFR0_GIC_BITS		0x4 /* Number of bits in GIC field */
#define	ID_AA64PFR0_GIC_SHIFT		24
#define	ID_AA64PFR0_GIC_MASK		(UL(0xf) << ID_AA64PFR0_GIC_SHIFT)
#define	ID_AA64PFR0_GIC_VAL(x)		((x) & ID_AA64PFR0_GIC_MASK)
#define	 ID_AA64PFR0_GIC_CPUIF_NONE	(UL(0x0) << ID_AA64PFR0_GIC_SHIFT)
#define	 ID_AA64PFR0_GIC_CPUIF_EN	(UL(0x1) << ID_AA64PFR0_GIC_SHIFT)
#define	 ID_AA64PFR0_GIC_CPUIF_4_1	(UL(0x3) << ID_AA64PFR0_GIC_SHIFT)
#define	ID_AA64PFR0_RAS_SHIFT		28
#define	ID_AA64PFR0_RAS_MASK		(UL(0xf) << ID_AA64PFR0_RAS_SHIFT)
#define	ID_AA64PFR0_RAS_VAL(x)		((x) & ID_AA64PFR0_RAS_MASK)
#define	 ID_AA64PFR0_RAS_NONE		(UL(0x0) << ID_AA64PFR0_RAS_SHIFT)
#define	 ID_AA64PFR0_RAS_IMPL		(UL(0x1) << ID_AA64PFR0_RAS_SHIFT)
#define	 ID_AA64PFR0_RAS_8_4		(UL(0x2) << ID_AA64PFR0_RAS_SHIFT)
#define	ID_AA64PFR0_SVE_SHIFT		32
#define	ID_AA64PFR0_SVE_MASK		(UL(0xf) << ID_AA64PFR0_SVE_SHIFT)
#define	ID_AA64PFR0_SVE_VAL(x)		((x) & ID_AA64PFR0_SVE_MASK)
#define	 ID_AA64PFR0_SVE_NONE		(UL(0x0) << ID_AA64PFR0_SVE_SHIFT)
#define	 ID_AA64PFR0_SVE_IMPL		(UL(0x1) << ID_AA64PFR0_SVE_SHIFT)
#define	ID_AA64PFR0_SEL2_SHIFT		36
#define	ID_AA64PFR0_SEL2_MASK		(UL(0xf) << ID_AA64PFR0_SEL2_SHIFT)
#define	ID_AA64PFR0_SEL2_VAL(x)		((x) & ID_AA64PFR0_SEL2_MASK)
#define	 ID_AA64PFR0_SEL2_NONE		(UL(0x0) << ID_AA64PFR0_SEL2_SHIFT)
#define	 ID_AA64PFR0_SEL2_IMPL		(UL(0x1) << ID_AA64PFR0_SEL2_SHIFT)
#define	ID_AA64PFR0_MPAM_SHIFT		40
#define	ID_AA64PFR0_MPAM_MASK		(UL(0xf) << ID_AA64PFR0_MPAM_SHIFT)
#define	ID_AA64PFR0_MPAM_VAL(x)		((x) & ID_AA64PFR0_MPAM_MASK)
#define	 ID_AA64PFR0_MPAM_NONE		(UL(0x0) << ID_AA64PFR0_MPAM_SHIFT)
#define	 ID_AA64PFR0_MPAM_IMPL		(UL(0x1) << ID_AA64PFR0_MPAM_SHIFT)
#define	ID_AA64PFR0_AMU_SHIFT		44
#define	ID_AA64PFR0_AMU_MASK		(UL(0xf) << ID_AA64PFR0_AMU_SHIFT)
#define	ID_AA64PFR0_AMU_VAL(x)		((x) & ID_AA64PFR0_AMU_MASK)
#define	 ID_AA64PFR0_AMU_NONE		(UL(0x0) << ID_AA64PFR0_AMU_SHIFT)
#define	 ID_AA64PFR0_AMU_V1		(UL(0x1) << ID_AA64PFR0_AMU_SHIFT)
#define	 ID_AA64PFR0_AMU_V1_1		(UL(0x2) << ID_AA64PFR0_AMU_SHIFT)
#define	ID_AA64PFR0_DIT_SHIFT		48
#define	ID_AA64PFR0_DIT_MASK		(UL(0xf) << ID_AA64PFR0_DIT_SHIFT)
#define	ID_AA64PFR0_DIT_VAL(x)		((x) & ID_AA64PFR0_DIT_MASK)
#define	 ID_AA64PFR0_DIT_NONE		(UL(0x0) << ID_AA64PFR0_DIT_SHIFT)
#define	 ID_AA64PFR0_DIT_PSTATE		(UL(0x1) << ID_AA64PFR0_DIT_SHIFT)
#define	ID_AA64PFR0_RME_SHIFT		52
#define	ID_AA64PFR0_RME_MASK		(UL(0xf) << ID_AA64PFR0_RME_SHIFT)
#define	ID_AA64PFR0_RME_VAL(x)		((x) & ID_AA64PFR0_RME_MASK)
#define	 ID_AA64PFR0_RME_NONE		(UL(0x0) << ID_AA64PFR0_RME_SHIFT)
#define	 ID_AA64PFR0_RME_IMPL		(UL(0x1) << ID_AA64PFR0_RME_SHIFT)
#define	ID_AA64PFR0_CSV2_SHIFT		56
#define	ID_AA64PFR0_CSV2_MASK		(UL(0xf) << ID_AA64PFR0_CSV2_SHIFT)
#define	ID_AA64PFR0_CSV2_VAL(x)		((x) & ID_AA64PFR0_CSV2_MASK)
#define	 ID_AA64PFR0_CSV2_NONE		(UL(0x0) << ID_AA64PFR0_CSV2_SHIFT)
#define	 ID_AA64PFR0_CSV2_ISOLATED	(UL(0x1) << ID_AA64PFR0_CSV2_SHIFT)
#define	 ID_AA64PFR0_CSV2_SCXTNUM	(UL(0x2) << ID_AA64PFR0_CSV2_SHIFT)
#define	 ID_AA64PFR0_CSV2_3		(UL(0x3) << ID_AA64PFR0_CSV2_SHIFT)
#define	ID_AA64PFR0_CSV3_SHIFT		60
#define	ID_AA64PFR0_CSV3_MASK		(UL(0xf) << ID_AA64PFR0_CSV3_SHIFT)
#define	ID_AA64PFR0_CSV3_VAL(x)		((x) & ID_AA64PFR0_CSV3_MASK)
#define	 ID_AA64PFR0_CSV3_NONE		(UL(0x0) << ID_AA64PFR0_CSV3_SHIFT)
#define	 ID_AA64PFR0_CSV3_ISOLATED	(UL(0x1) << ID_AA64PFR0_CSV3_SHIFT)

/* ID_AA64PFR1_EL1 */
#define	ID_AA64PFR1_EL1			MRS_REG(ID_AA64PFR1_EL1)
#define	ID_AA64PFR1_EL1_REG		MRS_REG_ALT_NAME(ID_AA64PFR1_EL1)
#define	ID_AA64PFR1_EL1_op0		3
#define	ID_AA64PFR1_EL1_op1		0
#define	ID_AA64PFR1_EL1_CRn		0
#define	ID_AA64PFR1_EL1_CRm		4
#define	ID_AA64PFR1_EL1_op2		1
#define	ID_AA64PFR1_BT_SHIFT		0
#define	ID_AA64PFR1_BT_MASK		(UL(0xf) << ID_AA64PFR1_BT_SHIFT)
#define	ID_AA64PFR1_BT_VAL(x)		((x) & ID_AA64PFR1_BT_MASK)
#define	 ID_AA64PFR1_BT_NONE		(UL(0x0) << ID_AA64PFR1_BT_SHIFT)
#define	 ID_AA64PFR1_BT_IMPL		(UL(0x1) << ID_AA64PFR1_BT_SHIFT)
#define	ID_AA64PFR1_SSBS_SHIFT		4
#define	ID_AA64PFR1_SSBS_MASK		(UL(0xf) << ID_AA64PFR1_SSBS_SHIFT)
#define	ID_AA64PFR1_SSBS_VAL(x)		((x) & ID_AA64PFR1_SSBS_MASK)
#define	 ID_AA64PFR1_SSBS_NONE		(UL(0x0) << ID_AA64PFR1_SSBS_SHIFT)
#define	 ID_AA64PFR1_SSBS_PSTATE	(UL(0x1) << ID_AA64PFR1_SSBS_SHIFT)
#define	 ID_AA64PFR1_SSBS_PSTATE_MSR	(UL(0x2) << ID_AA64PFR1_SSBS_SHIFT)
#define	ID_AA64PFR1_MTE_SHIFT		8
#define	ID_AA64PFR1_MTE_MASK		(UL(0xf) << ID_AA64PFR1_MTE_SHIFT)
#define	ID_AA64PFR1_MTE_VAL(x)		((x) & ID_AA64PFR1_MTE_MASK)
#define	 ID_AA64PFR1_MTE_NONE		(UL(0x0) << ID_AA64PFR1_MTE_SHIFT)
#define	 ID_AA64PFR1_MTE_MTE		(UL(0x1) << ID_AA64PFR1_MTE_SHIFT)
#define	 ID_AA64PFR1_MTE_MTE2		(UL(0x2) << ID_AA64PFR1_MTE_SHIFT)
#define	 ID_AA64PFR1_MTE_MTE3		(UL(0x3) << ID_AA64PFR1_MTE_SHIFT)
#define	ID_AA64PFR1_RAS_frac_SHIFT	12
#define	ID_AA64PFR1_RAS_frac_MASK	(UL(0xf) << ID_AA64PFR1_RAS_frac_SHIFT)
#define	ID_AA64PFR1_RAS_frac_VAL(x)	((x) & ID_AA64PFR1_RAS_frac_MASK)
#define	 ID_AA64PFR1_RAS_frac_p0	(UL(0x0) << ID_AA64PFR1_RAS_frac_SHIFT)
#define	 ID_AA64PFR1_RAS_frac_p1	(UL(0x1) << ID_AA64PFR1_RAS_frac_SHIFT)
#define	ID_AA64PFR1_MPAM_frac_SHIFT	16
#define	ID_AA64PFR1_MPAM_frac_MASK	(UL(0xf) << ID_AA64PFR1_MPAM_frac_SHIFT)
#define	ID_AA64PFR1_MPAM_frac_VAL(x)	((x) & ID_AA64PFR1_MPAM_frac_MASK)
#define	 ID_AA64PFR1_MPAM_frac_p0	(UL(0x0) << ID_AA64PFR1_MPAM_frac_SHIFT)
#define	 ID_AA64PFR1_MPAM_frac_p1	(UL(0x1) << ID_AA64PFR1_MPAM_frac_SHIFT)
#define	ID_AA64PFR1_SME_SHIFT		24
#define	ID_AA64PFR1_SME_MASK		(UL(0xf) << ID_AA64PFR1_SME_SHIFT)
#define	ID_AA64PFR1_SME_VAL(x)		((x) & ID_AA64PFR1_SME_MASK)
#define	 ID_AA64PFR1_SME_NONE		(UL(0x0) << ID_AA64PFR1_SME_SHIFT)
#define	 ID_AA64PFR1_SME_SME		(UL(0x1) << ID_AA64PFR1_SME_SHIFT)
#define	 ID_AA64PFR1_SME_SME2		(UL(0x2) << ID_AA64PFR1_SME_SHIFT)
#define	ID_AA64PFR1_RNDR_trap_SHIFT	28
#define	ID_AA64PFR1_RNDR_trap_MASK	(UL(0xf) << ID_AA64PFR1_RNDR_trap_SHIFT)
#define	ID_AA64PFR1_RNDR_trap_VAL(x)	((x) & ID_AA64PFR1_RNDR_trap_MASK)
#define	 ID_AA64PFR1_RNDR_trap_NONE	(UL(0x0) << ID_AA64PFR1_RNDR_trap_SHIFT)
#define	 ID_AA64PFR1_RNDR_trap_IMPL	(UL(0x1) << ID_AA64PFR1_RNDR_trap_SHIFT)
#define	ID_AA64PFR1_CSV2_frac_SHIFT	32
#define	ID_AA64PFR1_CSV2_frac_MASK	(UL(0xf) << ID_AA64PFR1_CSV2_frac_SHIFT)
#define	ID_AA64PFR1_CSV2_frac_VAL(x)	((x) & ID_AA64PFR1_CSV2_frac_MASK)
#define	 ID_AA64PFR1_CSV2_frac_p0	(UL(0x0) << ID_AA64PFR1_CSV2_frac_SHIFT)
#define	 ID_AA64PFR1_CSV2_frac_p1	(UL(0x1) << ID_AA64PFR1_CSV2_frac_SHIFT)
#define	 ID_AA64PFR1_CSV2_frac_p2	(UL(0x2) << ID_AA64PFR1_CSV2_frac_SHIFT)
#define	ID_AA64PFR1_NMI_SHIFT		36
#define	ID_AA64PFR1_NMI_MASK		(UL(0xf) << ID_AA64PFR1_NMI_SHIFT)
#define	ID_AA64PFR1_NMI_VAL(x)		((x) & ID_AA64PFR1_NMI_MASK)
#define	 ID_AA64PFR1_NMI_NONE		(UL(0x0) << ID_AA64PFR1_NMI_SHIFT)
#define	 ID_AA64PFR1_NMI_IMPL		(UL(0x1) << ID_AA64PFR1_NMI_SHIFT)

/* ID_AA64PFR2_EL1 */
#define	ID_AA64PFR2_EL1			MRS_REG(ID_AA64PFR2_EL1)
#define	ID_AA64PFR2_EL1_REG		MRS_REG_ALT_NAME(ID_AA64PFR2_EL1)
#define	ID_AA64PFR2_EL1_op0		3
#define	ID_AA64PFR2_EL1_op1		0
#define	ID_AA64PFR2_EL1_CRn		0
#define	ID_AA64PFR2_EL1_CRm		4
#define	ID_AA64PFR2_EL1_op2		2

/* ID_AA64ZFR0_EL1 */
#define	ID_AA64ZFR0_EL1			MRS_REG(ID_AA64ZFR0_EL1)
#define	ID_AA64ZFR0_EL1_REG		MRS_REG_ALT_NAME(ID_AA64ZFR0_EL1)
#define	ID_AA64ZFR0_EL1_op0		3
#define	ID_AA64ZFR0_EL1_op1		0
#define	ID_AA64ZFR0_EL1_CRn		0
#define	ID_AA64ZFR0_EL1_CRm		4
#define	ID_AA64ZFR0_EL1_op2		4
#define	ID_AA64ZFR0_SVEver_SHIFT	0
#define	ID_AA64ZFR0_SVEver_MASK		(UL(0xf) << ID_AA64ZFR0_SVEver_SHIFT)
#define	ID_AA64ZFR0_SVEver_VAL(x)	((x) & ID_AA64ZFR0_SVEver_MASK
#define	ID_AA64ZFR0_SVEver_SVE1		(UL(0x0) << ID_AA64ZFR0_SVEver_SHIFT)
#define	ID_AA64ZFR0_SVEver_SVE2		(UL(0x1) << ID_AA64ZFR0_SVEver_SHIFT)
#define	ID_AA64ZFR0_SVEver_SVE2P1	(UL(0x2) << ID_AA64ZFR0_SVEver_SHIFT)
#define	ID_AA64ZFR0_AES_SHIFT		4
#define	ID_AA64ZFR0_AES_MASK		(UL(0xf) << ID_AA64ZFR0_AES_SHIFT)
#define	ID_AA64ZFR0_AES_VAL(x)		((x) & ID_AA64ZFR0_AES_MASK
#define	ID_AA64ZFR0_AES_NONE		(UL(0x0) << ID_AA64ZFR0_AES_SHIFT)
#define	ID_AA64ZFR0_AES_BASE		(UL(0x1) << ID_AA64ZFR0_AES_SHIFT)
#define	ID_AA64ZFR0_AES_PMULL		(UL(0x2) << ID_AA64ZFR0_AES_SHIFT)
#define	ID_AA64ZFR0_BitPerm_SHIFT	16
#define	ID_AA64ZFR0_BitPerm_MASK	(UL(0xf) << ID_AA64ZFR0_BitPerm_SHIFT)
#define	ID_AA64ZFR0_BitPerm_VAL(x)	((x) & ID_AA64ZFR0_BitPerm_MASK
#define	ID_AA64ZFR0_BitPerm_NONE	(UL(0x0) << ID_AA64ZFR0_BitPerm_SHIFT)
#define	ID_AA64ZFR0_BitPerm_IMPL	(UL(0x1) << ID_AA64ZFR0_BitPerm_SHIFT)
#define	ID_AA64ZFR0_BF16_SHIFT		20
#define	ID_AA64ZFR0_BF16_MASK		(UL(0xf) << ID_AA64ZFR0_BF16_SHIFT)
#define	ID_AA64ZFR0_BF16_VAL(x)		((x) & ID_AA64ZFR0_BF16_MASK
#define	ID_AA64ZFR0_BF16_NONE		(UL(0x0) << ID_AA64ZFR0_BF16_SHIFT)
#define	ID_AA64ZFR0_BF16_BASE		(UL(0x1) << ID_AA64ZFR0_BF16_SHIFT)
#define	ID_AA64ZFR0_BF16_EBF		(UL(0x1) << ID_AA64ZFR0_BF16_SHIFT)
#define	ID_AA64ZFR0_SHA3_SHIFT		32
#define	ID_AA64ZFR0_SHA3_MASK		(UL(0xf) << ID_AA64ZFR0_SHA3_SHIFT)
#define	ID_AA64ZFR0_SHA3_VAL(x)		((x) & ID_AA64ZFR0_SHA3_MASK
#define	ID_AA64ZFR0_SHA3_NONE		(UL(0x0) << ID_AA64ZFR0_SHA3_SHIFT)
#define	ID_AA64ZFR0_SHA3_IMPL		(UL(0x1) << ID_AA64ZFR0_SHA3_SHIFT)
#define	ID_AA64ZFR0_SM4_SHIFT		40
#define	ID_AA64ZFR0_SM4_MASK		(UL(0xf) << ID_AA64ZFR0_SM4_SHIFT)
#define	ID_AA64ZFR0_SM4_VAL(x)		((x) & ID_AA64ZFR0_SM4_MASK
#define	ID_AA64ZFR0_SM4_NONE		(UL(0x0) << ID_AA64ZFR0_SM4_SHIFT)
#define	ID_AA64ZFR0_SM4_IMPL		(UL(0x1) << ID_AA64ZFR0_SM4_SHIFT)
#define	ID_AA64ZFR0_I8MM_SHIFT		44
#define	ID_AA64ZFR0_I8MM_MASK		(UL(0xf) << ID_AA64ZFR0_I8MM_SHIFT)
#define	ID_AA64ZFR0_I8MM_VAL(x)		((x) & ID_AA64ZFR0_I8MM_MASK
#define	ID_AA64ZFR0_I8MM_NONE		(UL(0x0) << ID_AA64ZFR0_I8MM_SHIFT)
#define	ID_AA64ZFR0_I8MM_IMPL		(UL(0x1) << ID_AA64ZFR0_I8MM_SHIFT)
#define	ID_AA64ZFR0_F32MM_SHIFT		52
#define	ID_AA64ZFR0_F32MM_MASK		(UL(0xf) << ID_AA64ZFR0_F32MM_SHIFT)
#define	ID_AA64ZFR0_F32MM_VAL(x)	((x) & ID_AA64ZFR0_F32MM_MASK
#define	ID_AA64ZFR0_F32MM_NONE		(UL(0x0) << ID_AA64ZFR0_F32MM_SHIFT)
#define	ID_AA64ZFR0_F32MM_IMPL		(UL(0x1) << ID_AA64ZFR0_F32MM_SHIFT)
#define	ID_AA64ZFR0_F64MM_SHIFT		56
#define	ID_AA64ZFR0_F64MM_MASK		(UL(0xf) << ID_AA64ZFR0_F64MM_SHIFT)
#define	ID_AA64ZFR0_F64MM_VAL(x)	((x) & ID_AA64ZFR0_F64MM_MASK
#define	ID_AA64ZFR0_F64MM_NONE		(UL(0x0) << ID_AA64ZFR0_F64MM_SHIFT)
#define	ID_AA64ZFR0_F64MM_IMPL		(UL(0x1) << ID_AA64ZFR0_F64MM_SHIFT)

/* ID_ISAR5_EL1 */
#define	ID_ISAR5_EL1			MRS_REG(ID_ISAR5_EL1)
#define	ID_ISAR5_EL1_op0		0x3
#define	ID_ISAR5_EL1_op1		0x0
#define	ID_ISAR5_EL1_CRn		0x0
#define	ID_ISAR5_EL1_CRm		0x2
#define	ID_ISAR5_EL1_op2		0x5
#define	ID_ISAR5_SEVL_SHIFT		0
#define	ID_ISAR5_SEVL_MASK		(UL(0xf) << ID_ISAR5_SEVL_SHIFT)
#define	ID_ISAR5_SEVL_VAL(x)		((x) & ID_ISAR5_SEVL_MASK)
#define	 ID_ISAR5_SEVL_NOP		(UL(0x0) << ID_ISAR5_SEVL_SHIFT)
#define	 ID_ISAR5_SEVL_IMPL		(UL(0x1) << ID_ISAR5_SEVL_SHIFT)
#define	ID_ISAR5_AES_SHIFT		4
#define	ID_ISAR5_AES_MASK		(UL(0xf) << ID_ISAR5_AES_SHIFT)
#define	ID_ISAR5_AES_VAL(x)		((x) & ID_ISAR5_AES_MASK)
#define	 ID_ISAR5_AES_NONE		(UL(0x0) << ID_ISAR5_AES_SHIFT)
#define	 ID_ISAR5_AES_BASE		(UL(0x1) << ID_ISAR5_AES_SHIFT)
#define	 ID_ISAR5_AES_VMULL		(UL(0x2) << ID_ISAR5_AES_SHIFT)
#define	ID_ISAR5_SHA1_SHIFT		8
#define	ID_ISAR5_SHA1_MASK		(UL(0xf) << ID_ISAR5_SHA1_SHIFT)
#define	ID_ISAR5_SHA1_VAL(x)		((x) & ID_ISAR5_SHA1_MASK)
#define	 ID_ISAR5_SHA1_NONE		(UL(0x0) << ID_ISAR5_SHA1_SHIFT)
#define	 ID_ISAR5_SHA1_IMPL		(UL(0x1) << ID_ISAR5_SHA1_SHIFT)
#define	ID_ISAR5_SHA2_SHIFT		12
#define	ID_ISAR5_SHA2_MASK		(UL(0xf) << ID_ISAR5_SHA2_SHIFT)
#define	ID_ISAR5_SHA2_VAL(x)		((x) & ID_ISAR5_SHA2_MASK)
#define	 ID_ISAR5_SHA2_NONE		(UL(0x0) << ID_ISAR5_SHA2_SHIFT)
#define	 ID_ISAR5_SHA2_IMPL		(UL(0x1) << ID_ISAR5_SHA2_SHIFT)
#define	ID_ISAR5_CRC32_SHIFT		16
#define	ID_ISAR5_CRC32_MASK		(UL(0xf) << ID_ISAR5_CRC32_SHIFT)
#define	ID_ISAR5_CRC32_VAL(x)		((x) & ID_ISAR5_CRC32_MASK)
#define	 ID_ISAR5_CRC32_NONE		(UL(0x0) << ID_ISAR5_CRC32_SHIFT)
#define	 ID_ISAR5_CRC32_IMPL		(UL(0x1) << ID_ISAR5_CRC32_SHIFT)
#define	ID_ISAR5_RDM_SHIFT		24
#define	ID_ISAR5_RDM_MASK		(UL(0xf) << ID_ISAR5_RDM_SHIFT)
#define	ID_ISAR5_RDM_VAL(x)		((x) & ID_ISAR5_RDM_MASK)
#define	 ID_ISAR5_RDM_NONE		(UL(0x0) << ID_ISAR5_RDM_SHIFT)
#define	 ID_ISAR5_RDM_IMPL		(UL(0x1) << ID_ISAR5_RDM_SHIFT)
#define	ID_ISAR5_VCMA_SHIFT		28
#define	ID_ISAR5_VCMA_MASK		(UL(0xf) << ID_ISAR5_VCMA_SHIFT)
#define	ID_ISAR5_VCMA_VAL(x)		((x) & ID_ISAR5_VCMA_MASK)
#define	 ID_ISAR5_VCMA_NONE		(UL(0x0) << ID_ISAR5_VCMA_SHIFT)
#define	 ID_ISAR5_VCMA_IMPL		(UL(0x1) << ID_ISAR5_VCMA_SHIFT)

/* MAIR_EL1 - Memory Attribute Indirection Register */
#define	MAIR_EL1_REG			MRS_REG_ALT_NAME(MAIR_EL1)
#define	MAIR_EL1_op0			3
#define	MAIR_EL1_op1			0
#define	MAIR_EL1_CRn			10
#define	MAIR_EL1_CRm			2
#define	MAIR_EL1_op2			0
#define	MAIR_ATTR_MASK(idx)		(UL(0xff) << ((n)* 8))
#define	MAIR_ATTR(attr, idx)		((attr) << ((idx) * 8))
#define	 MAIR_DEVICE_nGnRnE		UL(0x00)
#define	 MAIR_DEVICE_nGnRE		UL(0x04)
#define	 MAIR_NORMAL_NC			UL(0x44)
#define	 MAIR_NORMAL_WT			UL(0xbb)
#define	 MAIR_NORMAL_WB			UL(0xff)

/* MAIR_EL12 */
#define	MAIR_EL12_REG			MRS_REG_ALT_NAME(MAIR_EL12)
#define	MAIR_EL12_op0			3
#define	MAIR_EL12_op1			5
#define	MAIR_EL12_CRn			10
#define	MAIR_EL12_CRm			2
#define	MAIR_EL12_op2			0

/* MDCCINT_EL1 */
#define	MDCCINT_EL1			MRS_REG(MDCCINT_EL1)
#define	MDCCINT_EL1_op0			2
#define	MDCCINT_EL1_op1			0
#define	MDCCINT_EL1_CRn			0
#define	MDCCINT_EL1_CRm			2
#define	MDCCINT_EL1_op2			0

/* MDCCSR_EL0 */
#define	MDCCSR_EL0			MRS_REG(MDCCSR_EL0)
#define	MDCCSR_EL0_op0			2
#define	MDCCSR_EL0_op1			3
#define	MDCCSR_EL0_CRn			0
#define	MDCCSR_EL0_CRm			1
#define	MDCCSR_EL0_op2			0

/* MDSCR_EL1 - Monitor Debug System Control Register */
#define	MDSCR_EL1			MRS_REG(MDSCR_EL1)
#define	MDSCR_EL1_op0			2
#define	MDSCR_EL1_op1			0
#define	MDSCR_EL1_CRn			0
#define	MDSCR_EL1_CRm			2
#define	MDSCR_EL1_op2			2
#define	MDSCR_SS_SHIFT			0
#define	MDSCR_SS			(UL(0x1) << MDSCR_SS_SHIFT)
#define	MDSCR_KDE_SHIFT			13
#define	MDSCR_KDE			(UL(0x1) << MDSCR_KDE_SHIFT)
#define	MDSCR_MDE_SHIFT			15
#define	MDSCR_MDE			(UL(0x1) << MDSCR_MDE_SHIFT)

/* MIDR_EL1 - Main ID Register */
#define	MIDR_EL1			MRS_REG(MIDR_EL1)
#define	MIDR_EL1_op0			3
#define	MIDR_EL1_op1			0
#define	MIDR_EL1_CRn			0
#define	MIDR_EL1_CRm			0
#define	MIDR_EL1_op2			0

/* MPIDR_EL1 - Multiprocessor Affinity Register */
#define	MPIDR_EL1			MRS_REG(MPIDR_EL1)
#define	MPIDR_EL1_op0			3
#define	MPIDR_EL1_op1			0
#define	MPIDR_EL1_CRn			0
#define	MPIDR_EL1_CRm			0
#define	MPIDR_EL1_op2			5
#define	MPIDR_AFF0_SHIFT		0
#define	MPIDR_AFF0_MASK			(UL(0xff) << MPIDR_AFF0_SHIFT)
#define	MPIDR_AFF0_VAL(x)		((x) & MPIDR_AFF0_MASK)
#define	MPIDR_AFF1_SHIFT		8
#define	MPIDR_AFF1_MASK			(UL(0xff) << MPIDR_AFF1_SHIFT)
#define	MPIDR_AFF1_VAL(x)		((x) & MPIDR_AFF1_MASK)
#define	MPIDR_AFF2_SHIFT		16
#define	MPIDR_AFF2_MASK			(UL(0xff) << MPIDR_AFF2_SHIFT)
#define	MPIDR_AFF2_VAL(x)		((x) & MPIDR_AFF2_MASK)
#define	MPIDR_MT_SHIFT			24
#define	MPIDR_MT_MASK			(UL(0x1) << MPIDR_MT_SHIFT)
#define	MPIDR_U_SHIFT			30
#define	MPIDR_U_MASK			(UL(0x1) << MPIDR_U_SHIFT)
#define	MPIDR_AFF3_SHIFT		32
#define	MPIDR_AFF3_MASK			(UL(0xff) << MPIDR_AFF3_SHIFT)
#define	MPIDR_AFF3_VAL(x)		((x) & MPIDR_AFF3_MASK)

/* MVFR0_EL1 */
#define	MVFR0_EL1			MRS_REG(MVFR0_EL1)
#define	MVFR0_EL1_op0			0x3
#define	MVFR0_EL1_op1			0x0
#define	MVFR0_EL1_CRn			0x0
#define	MVFR0_EL1_CRm			0x3
#define	MVFR0_EL1_op2			0x0
#define	MVFR0_SIMDReg_SHIFT		0
#define	MVFR0_SIMDReg_MASK		(UL(0xf) << MVFR0_SIMDReg_SHIFT)
#define	MVFR0_SIMDReg_VAL(x)		((x) & MVFR0_SIMDReg_MASK)
#define	 MVFR0_SIMDReg_NONE		(UL(0x0) << MVFR0_SIMDReg_SHIFT)
#define	 MVFR0_SIMDReg_FP		(UL(0x1) << MVFR0_SIMDReg_SHIFT)
#define	 MVFR0_SIMDReg_AdvSIMD		(UL(0x2) << MVFR0_SIMDReg_SHIFT)
#define	MVFR0_FPSP_SHIFT		4
#define	MVFR0_FPSP_MASK			(UL(0xf) << MVFR0_FPSP_SHIFT)
#define	MVFR0_FPSP_VAL(x)		((x) & MVFR0_FPSP_MASK)
#define	 MVFR0_FPSP_NONE		(UL(0x0) << MVFR0_FPSP_SHIFT)
#define	 MVFR0_FPSP_VFP_v2		(UL(0x1) << MVFR0_FPSP_SHIFT)
#define	 MVFR0_FPSP_VFP_v3_v4		(UL(0x2) << MVFR0_FPSP_SHIFT)
#define	MVFR0_FPDP_SHIFT		8
#define	MVFR0_FPDP_MASK			(UL(0xf) << MVFR0_FPDP_SHIFT)
#define	MVFR0_FPDP_VAL(x)		((x) & MVFR0_FPDP_MASK)
#define	 MVFR0_FPDP_NONE		(UL(0x0) << MVFR0_FPDP_SHIFT)
#define	 MVFR0_FPDP_VFP_v2		(UL(0x1) << MVFR0_FPDP_SHIFT)
#define	 MVFR0_FPDP_VFP_v3_v4		(UL(0x2) << MVFR0_FPDP_SHIFT)
#define	MVFR0_FPTrap_SHIFT		12
#define	MVFR0_FPTrap_MASK		(UL(0xf) << MVFR0_FPTrap_SHIFT)
#define	MVFR0_FPTrap_VAL(x)		((x) & MVFR0_FPTrap_MASK)
#define	 MVFR0_FPTrap_NONE		(UL(0x0) << MVFR0_FPTrap_SHIFT)
#define	 MVFR0_FPTrap_IMPL		(UL(0x1) << MVFR0_FPTrap_SHIFT)
#define	MVFR0_FPDivide_SHIFT		16
#define	MVFR0_FPDivide_MASK		(UL(0xf) << MVFR0_FPDivide_SHIFT)
#define	MVFR0_FPDivide_VAL(x)		((x) & MVFR0_FPDivide_MASK)
#define	 MVFR0_FPDivide_NONE		(UL(0x0) << MVFR0_FPDivide_SHIFT)
#define	 MVFR0_FPDivide_IMPL		(UL(0x1) << MVFR0_FPDivide_SHIFT)
#define	MVFR0_FPSqrt_SHIFT		20
#define	MVFR0_FPSqrt_MASK		(UL(0xf) << MVFR0_FPSqrt_SHIFT)
#define	MVFR0_FPSqrt_VAL(x)		((x) & MVFR0_FPSqrt_MASK)
#define	 MVFR0_FPSqrt_NONE		(UL(0x0) << MVFR0_FPSqrt_SHIFT)
#define	 MVFR0_FPSqrt_IMPL		(UL(0x1) << MVFR0_FPSqrt_SHIFT)
#define	MVFR0_FPShVec_SHIFT		24
#define	MVFR0_FPShVec_MASK		(UL(0xf) << MVFR0_FPShVec_SHIFT)
#define	MVFR0_FPShVec_VAL(x)		((x) & MVFR0_FPShVec_MASK)
#define	 MVFR0_FPShVec_NONE		(UL(0x0) << MVFR0_FPShVec_SHIFT)
#define	 MVFR0_FPShVec_IMPL		(UL(0x1) << MVFR0_FPShVec_SHIFT)
#define	MVFR0_FPRound_SHIFT		28
#define	MVFR0_FPRound_MASK		(UL(0xf) << MVFR0_FPRound_SHIFT)
#define	MVFR0_FPRound_VAL(x)		((x) & MVFR0_FPRound_MASK)
#define	 MVFR0_FPRound_NONE		(UL(0x0) << MVFR0_FPRound_SHIFT)
#define	 MVFR0_FPRound_IMPL		(UL(0x1) << MVFR0_FPRound_SHIFT)

/* MVFR1_EL1 */
#define	MVFR1_EL1			MRS_REG(MVFR1_EL1)
#define	MVFR1_EL1_op0			0x3
#define	MVFR1_EL1_op1			0x0
#define	MVFR1_EL1_CRn			0x0
#define	MVFR1_EL1_CRm			0x3
#define	MVFR1_EL1_op2			0x1
#define	MVFR1_FPFtZ_SHIFT		0
#define	MVFR1_FPFtZ_MASK		(UL(0xf) << MVFR1_FPFtZ_SHIFT)
#define	MVFR1_FPFtZ_VAL(x)		((x) & MVFR1_FPFtZ_MASK)
#define	 MVFR1_FPFtZ_NONE		(UL(0x0) << MVFR1_FPFtZ_SHIFT)
#define	 MVFR1_FPFtZ_IMPL		(UL(0x1) << MVFR1_FPFtZ_SHIFT)
#define	MVFR1_FPDNaN_SHIFT		4
#define	MVFR1_FPDNaN_MASK		(UL(0xf) << MVFR1_FPDNaN_SHIFT)
#define	MVFR1_FPDNaN_VAL(x)		((x) & MVFR1_FPDNaN_MASK)
#define	 MVFR1_FPDNaN_NONE		(UL(0x0) << MVFR1_FPDNaN_SHIFT)
#define	 MVFR1_FPDNaN_IMPL		(UL(0x1) << MVFR1_FPDNaN_SHIFT)
#define	MVFR1_SIMDLS_SHIFT		8
#define	MVFR1_SIMDLS_MASK		(UL(0xf) << MVFR1_SIMDLS_SHIFT)
#define	MVFR1_SIMDLS_VAL(x)		((x) & MVFR1_SIMDLS_MASK)
#define	 MVFR1_SIMDLS_NONE		(UL(0x0) << MVFR1_SIMDLS_SHIFT)
#define	 MVFR1_SIMDLS_IMPL		(UL(0x1) << MVFR1_SIMDLS_SHIFT)
#define	MVFR1_SIMDInt_SHIFT		12
#define	MVFR1_SIMDInt_MASK		(UL(0xf) << MVFR1_SIMDInt_SHIFT)
#define	MVFR1_SIMDInt_VAL(x)		((x) & MVFR1_SIMDInt_MASK)
#define	 MVFR1_SIMDInt_NONE		(UL(0x0) << MVFR1_SIMDInt_SHIFT)
#define	 MVFR1_SIMDInt_IMPL		(UL(0x1) << MVFR1_SIMDInt_SHIFT)
#define	MVFR1_SIMDSP_SHIFT		16
#define	MVFR1_SIMDSP_MASK		(UL(0xf) << MVFR1_SIMDSP_SHIFT)
#define	MVFR1_SIMDSP_VAL(x)		((x) & MVFR1_SIMDSP_MASK)
#define	 MVFR1_SIMDSP_NONE		(UL(0x0) << MVFR1_SIMDSP_SHIFT)
#define	 MVFR1_SIMDSP_IMPL		(UL(0x1) << MVFR1_SIMDSP_SHIFT)
#define	MVFR1_SIMDHP_SHIFT		20
#define	MVFR1_SIMDHP_MASK		(UL(0xf) << MVFR1_SIMDHP_SHIFT)
#define	MVFR1_SIMDHP_VAL(x)		((x) & MVFR1_SIMDHP_MASK)
#define	 MVFR1_SIMDHP_NONE		(UL(0x0) << MVFR1_SIMDHP_SHIFT)
#define	 MVFR1_SIMDHP_CONV_SP		(UL(0x1) << MVFR1_SIMDHP_SHIFT)
#define	 MVFR1_SIMDHP_ARITH		(UL(0x2) << MVFR1_SIMDHP_SHIFT)
#define	MVFR1_FPHP_SHIFT		24
#define	MVFR1_FPHP_MASK			(UL(0xf) << MVFR1_FPHP_SHIFT)
#define	MVFR1_FPHP_VAL(x)		((x) & MVFR1_FPHP_MASK)
#define	 MVFR1_FPHP_NONE		(UL(0x0) << MVFR1_FPHP_SHIFT)
#define	 MVFR1_FPHP_CONV_SP		(UL(0x1) << MVFR1_FPHP_SHIFT)
#define	 MVFR1_FPHP_CONV_DP		(UL(0x2) << MVFR1_FPHP_SHIFT)
#define	 MVFR1_FPHP_ARITH		(UL(0x3) << MVFR1_FPHP_SHIFT)
#define	MVFR1_SIMDFMAC_SHIFT		28
#define	MVFR1_SIMDFMAC_MASK		(UL(0xf) << MVFR1_SIMDFMAC_SHIFT)
#define	MVFR1_SIMDFMAC_VAL(x)		((x) & MVFR1_SIMDFMAC_MASK)
#define	 MVFR1_SIMDFMAC_NONE		(UL(0x0) << MVFR1_SIMDFMAC_SHIFT)
#define	 MVFR1_SIMDFMAC_IMPL		(UL(0x1) << MVFR1_SIMDFMAC_SHIFT)

/* OSDLR_EL1 */
#define	OSDLR_EL1			MRS_REG(OSDLR_EL1)
#define	OSDLR_EL1_op0			2
#define	OSDLR_EL1_op1			0
#define	OSDLR_EL1_CRn			1
#define	OSDLR_EL1_CRm			3
#define	OSDLR_EL1_op2			4

/* OSLAR_EL1 */
#define	OSLAR_EL1			MRS_REG(OSLAR_EL1)
#define	OSLAR_EL1_op0			2
#define	OSLAR_EL1_op1			0
#define	OSLAR_EL1_CRn			1
#define	OSLAR_EL1_CRm			0
#define	OSLAR_EL1_op2			4

/* OSLSR_EL1 */
#define	OSLSR_EL1			MRS_REG(OSLSR_EL1)
#define	OSLSR_EL1_op0			2
#define	OSLSR_EL1_op1			0
#define	OSLSR_EL1_CRn			1
#define	OSLSR_EL1_CRm			1
#define	OSLSR_EL1_op2			4

/* PAR_EL1 - Physical Address Register */
#define	PAR_F_SHIFT		0
#define	PAR_F			(0x1 << PAR_F_SHIFT)
#define	PAR_SUCCESS(x)		(((x) & PAR_F) == 0)
/* When PAR_F == 0 (success) */
#define	PAR_LOW_MASK		0xfff
#define	PAR_SH_SHIFT		7
#define	PAR_SH_MASK		(0x3 << PAR_SH_SHIFT)
#define	PAR_NS_SHIFT		9
#define	PAR_NS_MASK		(0x3 << PAR_NS_SHIFT)
#define	PAR_PA_SHIFT		12
#define	PAR_PA_MASK		0x0000fffffffff000
#define	PAR_ATTR_SHIFT		56
#define	PAR_ATTR_MASK		(0xff << PAR_ATTR_SHIFT)
/* When PAR_F == 1 (aborted) */
#define	PAR_FST_SHIFT		1
#define	PAR_FST_MASK		(0x3f << PAR_FST_SHIFT)
#define	PAR_PTW_SHIFT		8
#define	PAR_PTW_MASK		(0x1 << PAR_PTW_SHIFT)
#define	PAR_S_SHIFT		9
#define	PAR_S_MASK		(0x1 << PAR_S_SHIFT)

/* PMBIDR_EL1 */
#define	PMBIDR_EL1			MRS_REG(PMBIDR_EL1)
#define	PMBIDR_EL1_REG			MRS_REG_ALT_NAME(PMBIDR_EL1)
#define	PMBIDR_EL1_op0			3
#define	PMBIDR_EL1_op1			0
#define	PMBIDR_EL1_CRn			9
#define	PMBIDR_EL1_CRm			10
#define	PMBIDR_EL1_op2			7
#define	PMBIDR_Align_SHIFT		0
#define	PMBIDR_Align_MASK		(UL(0xf) << PMBIDR_Align_SHIFT)
#define	PMBIDR_P_SHIFT			4
#define	PMBIDR_P			(UL(0x1) << PMBIDR_P_SHIFT)
#define	PMBIDR_F_SHIFT			5
#define	PMBIDR_F			(UL(0x1) << PMBIDR_F_SHIFT)

/* PMBLIMITR_EL1 */
#define	PMBLIMITR_EL1			MRS_REG(PMBLIMITR_EL1)
#define	PMBLIMITR_EL1_REG		MRS_REG_ALT_NAME(PMBLIMITR_EL1)
#define	PMBLIMITR_EL1_op0		3
#define	PMBLIMITR_EL1_op1		0
#define	PMBLIMITR_EL1_CRn		9
#define	PMBLIMITR_EL1_CRm		10
#define	PMBLIMITR_EL1_op2		0
#define	PMBLIMITR_E_SHIFT		0
#define	PMBLIMITR_E			(UL(0x1) << PMBLIMITR_E_SHIFT)
#define	PMBLIMITR_FM_SHIFT		1
#define	PMBLIMITR_FM_MASK		(UL(0x3) << PMBLIMITR_FM_SHIFT)
#define	PMBLIMITR_PMFZ_SHIFT		5
#define	PMBLIMITR_PMFZ			(UL(0x1) << PMBLIMITR_PMFZ_SHIFT)
#define	PMBLIMITR_LIMIT_SHIFT		12
#define	PMBLIMITR_LIMIT_MASK		\
    (UL(0xfffffffffffff) << PMBLIMITR_LIMIT_SHIFT)

/* PMBPTR_EL1 */
#define	PMBPTR_EL1			MRS_REG(PMBPTR_EL1)
#define	PMBPTR_EL1_REG			MRS_REG_ALT_NAME(PMBPTR_EL1)
#define	PMBPTR_EL1_op0			3
#define	PMBPTR_EL1_op1			0
#define	PMBPTR_EL1_CRn			9
#define	PMBPTR_EL1_CRm			10
#define	PMBPTR_EL1_op2			1
#define	PMBPTR_PTR_SHIFT		0
#define	PMBPTR_PTR_MASK			\
    (UL(0xffffffffffffffff) << PMBPTR_PTR_SHIFT)

/* PMBSR_EL1 */
#define	PMBSR_EL1			MRS_REG(PMBSR_EL1)
#define	PMBSR_EL1_REG			MRS_REG_ALT_NAME(PMBSR_EL1)
#define	PMBSR_EL1_op0			3
#define	PMBSR_EL1_op1			0
#define	PMBSR_EL1_CRn			9
#define	PMBSR_EL1_CRm			10
#define	PMBSR_EL1_op2			3
#define	PMBSR_MSS_SHIFT			0
#define	PMBSR_MSS_MASK			(UL(0xffff) << PMBSR_MSS_SHIFT)
#define	PMBSR_MSS_BSC_MASK		(UL(0x3f) << PMBSR_MSS_SHIFT)
#define	PMBSR_MSS_FSC_MASK		(UL(0x3f) << PMBSR_MSS_SHIFT)
#define	PMBSR_COLL_SHIFT		16
#define	PMBSR_COLL			(UL(0x1) << PMBSR_COLL_SHIFT)
#define	PMBSR_S_SHIFT			17
#define	PMBSR_S				(UL(0x1) << PMBSR_S_SHIFT)
#define	PMBSR_EA_SHIFT			18
#define	PMBSR_EA			(UL(0x1) << PMBSR_EA_SHIFT)
#define	PMBSR_DL_SHIFT			19
#define	PMBSR_DL			(UL(0x1) << PMBSR_DL_SHIFT)
#define	PMBSR_EC_SHIFT			26
#define	PMBSR_EC_MASK			(UL(0x3f) << PMBSR_EC_SHIFT)

/* PMCCFILTR_EL0 */
#define	PMCCFILTR_EL0			MRS_REG(PMCCFILTR_EL0)
#define	PMCCFILTR_EL0_op0		3
#define	PMCCFILTR_EL0_op1		3
#define	PMCCFILTR_EL0_CRn		14
#define	PMCCFILTR_EL0_CRm		15
#define	PMCCFILTR_EL0_op2		7

/* PMCCNTR_EL0 */
#define	PMCCNTR_EL0			MRS_REG(PMCCNTR_EL0)
#define	PMCCNTR_EL0_op0			3
#define	PMCCNTR_EL0_op1			3
#define	PMCCNTR_EL0_CRn			9
#define	PMCCNTR_EL0_CRm			13
#define	PMCCNTR_EL0_op2			0

/* PMCEID0_EL0 */
#define	PMCEID0_EL0			MRS_REG(PMCEID0_EL0)
#define	PMCEID0_EL0_op0			3
#define	PMCEID0_EL0_op1			3
#define	PMCEID0_EL0_CRn			9
#define	PMCEID0_EL0_CRm			12
#define	PMCEID0_EL0_op2			6

/* PMCEID1_EL0 */
#define	PMCEID1_EL0			MRS_REG(PMCEID1_EL0)
#define	PMCEID1_EL0_op0			3
#define	PMCEID1_EL0_op1			3
#define	PMCEID1_EL0_CRn			9
#define	PMCEID1_EL0_CRm			12
#define	PMCEID1_EL0_op2			7

/* PMCNTENCLR_EL0 */
#define	PMCNTENCLR_EL0			MRS_REG(PMCNTENCLR_EL0)
#define	PMCNTENCLR_EL0_op0		3
#define	PMCNTENCLR_EL0_op1		3
#define	PMCNTENCLR_EL0_CRn		9
#define	PMCNTENCLR_EL0_CRm		12
#define	PMCNTENCLR_EL0_op2		2

/* PMCNTENSET_EL0 */
#define	PMCNTENSET_EL0			MRS_REG(PMCNTENSET_EL0)
#define	PMCNTENSET_EL0_op0		3
#define	PMCNTENSET_EL0_op1		3
#define	PMCNTENSET_EL0_CRn		9
#define	PMCNTENSET_EL0_CRm		12
#define	PMCNTENSET_EL0_op2		1

/* PMCR_EL0 - Perfomance Monitoring Counters */
#define	PMCR_EL0			MRS_REG(PMCR_EL0)
#define	PMCR_EL0_op0			3
#define	PMCR_EL0_op1			3
#define	PMCR_EL0_CRn			9
#define	PMCR_EL0_CRm			12
#define	PMCR_EL0_op2			0
#define	PMCR_E				(1 << 0) /* Enable all counters */
#define	PMCR_P				(1 << 1) /* Reset all counters */
#define	PMCR_C				(1 << 2) /* Clock counter reset */
#define	PMCR_D				(1 << 3) /* CNTR counts every 64 clk cycles */
#define	PMCR_X				(1 << 4) /* Export to ext. monitoring (ETM) */
#define	PMCR_DP				(1 << 5) /* Disable CCNT if non-invasive debug*/
#define	PMCR_LC				(1 << 6) /* Long cycle count enable */
#define	PMCR_IMP_SHIFT			24	/* Implementer code */
#define	PMCR_IMP_MASK			(0xff << PMCR_IMP_SHIFT)
#define	 PMCR_IMP_ARM			0x41
#define	PMCR_IDCODE_SHIFT		16	/* Identification code */
#define	PMCR_IDCODE_MASK		(0xff << PMCR_IDCODE_SHIFT)
#define	 PMCR_IDCODE_CORTEX_A57		0x01
#define	 PMCR_IDCODE_CORTEX_A72		0x02
#define	 PMCR_IDCODE_CORTEX_A53		0x03
#define	 PMCR_IDCODE_CORTEX_A73		0x04
#define	 PMCR_IDCODE_CORTEX_A35		0x0a
#define	 PMCR_IDCODE_CORTEX_A76		0x0b
#define	 PMCR_IDCODE_NEOVERSE_N1	0x0c
#define	 PMCR_IDCODE_CORTEX_A77		0x10
#define	 PMCR_IDCODE_CORTEX_A55		0x45
#define	 PMCR_IDCODE_NEOVERSE_E1	0x46
#define	 PMCR_IDCODE_CORTEX_A75		0x4a
#define	PMCR_N_SHIFT			11  /* Number of counters implemented */
#define	PMCR_N_MASK			(0x1f << PMCR_N_SHIFT)

/* PMEVCNTR<n>_EL0 */
#define	PMEVCNTR_EL0_op0		3
#define	PMEVCNTR_EL0_op1		3
#define	PMEVCNTR_EL0_CRn		14
#define	PMEVCNTR_EL0_CRm		8
/*
 * PMEVCNTRn_EL0_CRm[1:0] holds the upper 2 bits of 'n'
 * PMEVCNTRn_EL0_op2 holds the lower 3 bits of 'n'
 */

/* PMEVTYPER<n>_EL0 - Performance Monitoring Event Type */
#define	PMEVTYPER_EL0_op0		3
#define	PMEVTYPER_EL0_op1		3
#define	PMEVTYPER_EL0_CRn		14
#define	PMEVTYPER_EL0_CRm		12
/*
 * PMEVTYPERn_EL0_CRm[1:0] holds the upper 2 bits of 'n'
 * PMEVTYPERn_EL0_op2 holds the lower 3 bits of 'n'
 */
#define	PMEVTYPER_EVTCOUNT_MASK		0x000003ff /* ARMv8.0 */
#define	PMEVTYPER_EVTCOUNT_8_1_MASK	0x0000ffff /* ARMv8.1+ */
#define	PMEVTYPER_MT			(1 << 25) /* Multithreading */
#define	PMEVTYPER_M			(1 << 26) /* Secure EL3 filtering */
#define	PMEVTYPER_NSH			(1 << 27) /* Non-secure hypervisor filtering */
#define	PMEVTYPER_NSU			(1 << 28) /* Non-secure user filtering */
#define	PMEVTYPER_NSK			(1 << 29) /* Non-secure kernel filtering */
#define	PMEVTYPER_U			(1 << 30) /* User filtering */
#define	PMEVTYPER_P			(1 << 31) /* Privileged filtering */

/* PMINTENCLR_EL1 */
#define	PMINTENCLR_EL1			MRS_REG(PMINTENCLR_EL1)
#define	PMINTENCLR_EL1_op0		3
#define	PMINTENCLR_EL1_op1		0
#define	PMINTENCLR_EL1_CRn		9
#define	PMINTENCLR_EL1_CRm		14
#define	PMINTENCLR_EL1_op2		2

/* PMINTENSET_EL1 */
#define	PMINTENSET_EL1			MRS_REG(PMINTENSET_EL1)
#define	PMINTENSET_EL1_op0		3
#define	PMINTENSET_EL1_op1		0
#define	PMINTENSET_EL1_CRn		9
#define	PMINTENSET_EL1_CRm		14
#define	PMINTENSET_EL1_op2		1

/* PMMIR_EL1 */
#define	PMMIR_EL1			MRS_REG(PMMIR_EL1)
#define	PMMIR_EL1_op0			3
#define	PMMIR_EL1_op1			0
#define	PMMIR_EL1_CRn			9
#define	PMMIR_EL1_CRm			14
#define	PMMIR_EL1_op2			6

/* PMOVSCLR_EL0 */
#define	PMOVSCLR_EL0			MRS_REG(PMOVSCLR_EL0)
#define	PMOVSCLR_EL0_op0		3
#define	PMOVSCLR_EL0_op1		3
#define	PMOVSCLR_EL0_CRn		9
#define	PMOVSCLR_EL0_CRm		12
#define	PMOVSCLR_EL0_op2		3

/* PMOVSSET_EL0 */
#define	PMOVSSET_EL0			MRS_REG(PMOVSSET_EL0)
#define	PMOVSSET_EL0_op0		3
#define	PMOVSSET_EL0_op1		3
#define	PMOVSSET_EL0_CRn		9
#define	PMOVSSET_EL0_CRm		14
#define	PMOVSSET_EL0_op2		3

/* PMSCR_EL1 */
#define	PMSCR_EL1			MRS_REG(PMSCR_EL1)
#define	PMSCR_EL1_REG			MRS_REG_ALT_NAME(PMSCR_EL1)
#define	PMSCR_EL1_op0			3
#define	PMSCR_EL1_op1			0
#define	PMSCR_EL1_CRn			9
#define	PMSCR_EL1_CRm			9
#define	PMSCR_EL1_op2			0
#define	PMSCR_E0SPE_SHIFT		0
#define	PMSCR_E0SPE			(UL(0x1) << PMSCR_E0SPE_SHIFT)
#define	PMSCR_E1SPE_SHIFT		1
#define	PMSCR_E1SPE			(UL(0x1) << PMSCR_E1SPE_SHIFT)
#define	PMSCR_CX_SHIFT			3
#define	PMSCR_CX			(UL(0x1) << PMSCR_CX_SHIFT)
#define	PMSCR_PA_SHIFT			4
#define	PMSCR_PA			(UL(0x1) << PMSCR_PA_SHIFT)
#define	PMSCR_TS_SHIFT			5
#define	PMSCR_TS			(UL(0x1) << PMSCR_TS_SHIFT)
#define	PMSCR_PCT_SHIFT			6
#define	PMSCR_PCT_MASK			(UL(0x3) << PMSCR_PCT_SHIFT)

/* PMSELR_EL0 */
#define	PMSELR_EL0			MRS_REG(PMSELR_EL0)
#define	PMSELR_EL0_op0			3
#define	PMSELR_EL0_op1			3
#define	PMSELR_EL0_CRn			9
#define	PMSELR_EL0_CRm			12
#define	PMSELR_EL0_op2			5
#define	PMSELR_SEL_MASK			0x1f

/* PMSEVFR_EL1 */
#define	PMSEVFR_EL1			MRS_REG(PMSEVFR_EL1)
#define	PMSEVFR_EL1_REG			MRS_REG_ALT_NAME(PMSEVFR_EL1)
#define	PMSEVFR_EL1_op0			3
#define	PMSEVFR_EL1_op1			0
#define	PMSEVFR_EL1_CRn			9
#define	PMSEVFR_EL1_CRm			9
#define	PMSEVFR_EL1_op2			5

/* PMSFCR_EL1 */
#define	PMSFCR_EL1			MRS_REG(PMSFCR_EL1)
#define	PMSFCR_EL1_REG			MRS_REG_ALT_NAME(PMSFCR_EL1)
#define	PMSFCR_EL1_op0			3
#define	PMSFCR_EL1_op1			0
#define	PMSFCR_EL1_CRn			9
#define	PMSFCR_EL1_CRm			9
#define	PMSFCR_EL1_op2			4
#define	PMSFCR_FE_SHIFT			0
#define	PMSFCR_FE			(UL(0x1) << PMSFCR_FE_SHIFT)
#define	PMSFCR_FT_SHIFT			1
#define	PMSFCR_FT			(UL(0x1) << PMSFCR_FT_SHIFT)
#define	PMSFCR_FL_SHIFT			2
#define	PMSFCR_FL			(UL(0x1) << PMSFCR_FL_SHIFT)
#define	PMSFCR_FnE_SHIFT		3
#define	PMSFCR_FnE			(UL(0x1) << PMSFCR_FnE_SHIFT)
#define	PMSFCR_B_SHIFT			16
#define	PMSFCR_B			(UL(0x1) << PMSFCR_B_SHIFT)
#define	PMSFCR_LD_SHIFT			17
#define	PMSFCR_LD			(UL(0x1) << PMSFCR_LD_SHIFT)
#define	PMSFCR_ST_SHIFT			18
#define	PMSFCR_ST			(UL(0x1) << PMSFCR_ST_SHIFT)

/* PMSICR_EL1 */
#define	PMSICR_EL1			MRS_REG(PMSICR_EL1)
#define	PMSICR_EL1_REG			MRS_REG_ALT_NAME(PMSICR_EL1)
#define	PMSICR_EL1_op0			3
#define	PMSICR_EL1_op1			0
#define	PMSICR_EL1_CRn			9
#define	PMSICR_EL1_CRm			9
#define	PMSICR_EL1_op2			2
#define	PMSICR_COUNT_SHIFT		0
#define	PMSICR_COUNT_MASK		(UL(0xffffffff) << PMSICR_COUNT_SHIFT)
#define	PMSICR_ECOUNT_SHIFT		56
#define	PMSICR_ECOUNT_MASK		(UL(0xff) << PMSICR_ECOUNT_SHIFT)

/* PMSIDR_EL1 */
#define	PMSIDR_EL1			MRS_REG(PMSIDR_EL1)
#define	PMSIDR_EL1_REG			MRS_REG_ALT_NAME(PMSIDR_EL1)
#define	PMSIDR_EL1_op0			3
#define	PMSIDR_EL1_op1			0
#define	PMSIDR_EL1_CRn			9
#define	PMSIDR_EL1_CRm			9
#define	PMSIDR_EL1_op2			7
#define	PMSIDR_FE_SHIFT			0
#define	PMSIDR_FE			(UL(0x1) << PMSIDR_FE_SHIFT)
#define	PMSIDR_FT_SHIFT			1
#define	PMSIDR_FT			(UL(0x1) << PMSIDR_FT_SHIFT)
#define	PMSIDR_FL_SHIFT			2
#define	PMSIDR_FL			(UL(0x1) << PMSIDR_FL_SHIFT)
#define	PMSIDR_ArchInst_SHIFT		3
#define	PMSIDR_ArchInst			(UL(0x1) << PMSIDR_ArchInst_SHIFT)
#define	PMSIDR_LDS_SHIFT		4
#define	PMSIDR_LDS			(UL(0x1) << PMSIDR_LDS_SHIFT)
#define	PMSIDR_ERnd_SHIFT		5
#define	PMSIDR_ERnd			(UL(0x1) << PMSIDR_ERnd_SHIFT)
#define	PMSIDR_FnE_SHIFT		6
#define	PMSIDR_FnE			(UL(0x1) << PMSIDR_FnE_SHIFT)
#define	PMSIDR_Interval_SHIFT		8
#define	PMSIDR_Interval_MASK		(UL(0xf) << PMSIDR_Interval_SHIFT)
#define	PMSIDR_MaxSize_SHIFT		12
#define	PMSIDR_MaxSize_MASK		(UL(0xf) << PMSIDR_MaxSize_SHIFT)
#define	PMSIDR_CountSize_SHIFT		16
#define	PMSIDR_CountSize_MASK		(UL(0xf) << PMSIDR_CountSize_SHIFT)
#define	PMSIDR_Format_SHIFT		20
#define	PMSIDR_Format_MASK		(UL(0xf) << PMSIDR_Format_SHIFT)
#define	PMSIDR_PBT_SHIFT		24
#define	PMSIDR_PBT			(UL(0x1) << PMSIDR_PBT_SHIFT)

/* PMSIRR_EL1 */
#define	PMSIRR_EL1			MRS_REG(PMSIRR_EL1)
#define	PMSIRR_EL1_REG			MRS_REG_ALT_NAME(PMSIRR_EL1)
#define	PMSIRR_EL1_op0			3
#define	PMSIRR_EL1_op1			0
#define	PMSIRR_EL1_CRn			9
#define	PMSIRR_EL1_CRm			9
#define	PMSIRR_EL1_op2			3
#define	PMSIRR_RND_SHIFT		0
#define	PMSIRR_RND			(UL(0x1) << PMSIRR_RND_SHIFT)
#define	PMSIRR_INTERVAL_SHIFT		8
#define	PMSIRR_INTERVAL_MASK		(UL(0xffffff) << PMSIRR_INTERVAL_SHIFT)

/* PMSLATFR_EL1 */
#define	PMSLATFR_EL1			MRS_REG(PMSLATFR_EL1)
#define	PMSLATFR_EL1_REG		MRS_REG_ALT_NAME(PMSLATFR_EL1)
#define	PMSLATFR_EL1_op0		3
#define	PMSLATFR_EL1_op1		0
#define	PMSLATFR_EL1_CRn		9
#define	PMSLATFR_EL1_CRm		9
#define	PMSLATFR_EL1_op2		6
#define	PMSLATFR_MINLAT_SHIFT		0
#define	PMSLATFR_MINLAT_MASK		(UL(0xfff) << PMSLATFR_MINLAT_SHIFT)

/* PMSNEVFR_EL1 */
#define	PMSNEVFR_EL1			MRS_REG(PMSNEVFR_EL1)
#define	PMSNEVFR_EL1_REG		MRS_REG_ALT_NAME(PMSNEVFR_EL1)
#define	PMSNEVFR_EL1_op0		3
#define	PMSNEVFR_EL1_op1		0
#define	PMSNEVFR_EL1_CRn		9
#define	PMSNEVFR_EL1_CRm		9
#define	PMSNEVFR_EL1_op2		1

/* PMSWINC_EL0 */
#define	PMSWINC_EL0			MRS_REG(PMSWINC_EL0)
#define	PMSWINC_EL0_op0			3
#define	PMSWINC_EL0_op1			3
#define	PMSWINC_EL0_CRn			9
#define	PMSWINC_EL0_CRm			12
#define	PMSWINC_EL0_op2			4

/* PMUSERENR_EL0 */
#define	PMUSERENR_EL0			MRS_REG(PMUSERENR_EL0)
#define	PMUSERENR_EL0_op0		3
#define	PMUSERENR_EL0_op1		3
#define	PMUSERENR_EL0_CRn		9
#define	PMUSERENR_EL0_CRm		14
#define	PMUSERENR_EL0_op2		0

/* PMXEVCNTR_EL0 */
#define	PMXEVCNTR_EL0			MRS_REG(PMXEVCNTR_EL0)
#define	PMXEVCNTR_EL0_op0		3
#define	PMXEVCNTR_EL0_op1		3
#define	PMXEVCNTR_EL0_CRn		9
#define	PMXEVCNTR_EL0_CRm		13
#define	PMXEVCNTR_EL0_op2		2

/* PMXEVTYPER_EL0 */
#define	PMXEVTYPER_EL0			MRS_REG(PMXEVTYPER_EL0)
#define	PMXEVTYPER_EL0_op0		3
#define	PMXEVTYPER_EL0_op1		3
#define	PMXEVTYPER_EL0_CRn		9
#define	PMXEVTYPER_EL0_CRm		13
#define	PMXEVTYPER_EL0_op2		1

/* RNDRRS */
#define	RNDRRS				MRS_REG(RNDRRS)
#define	RNDRRS_REG			MRS_REG_ALT_NAME(RNDRRS)
#define	RNDRRS_op0			3
#define	RNDRRS_op1			3
#define	RNDRRS_CRn			2
#define	RNDRRS_CRm			4
#define	RNDRRS_op2			1

/* SCTLR_EL1 - System Control Register */
#define	SCTLR_EL1_REG			MRS_REG_ALT_NAME(SCTLR_EL1)
#define	SCTLR_EL1_op0			3
#define	SCTLR_EL1_op1			0
#define	SCTLR_EL1_CRn			1
#define	SCTLR_EL1_CRm			0
#define	SCTLR_EL1_op2			0
#define	SCTLR_RES1	0x30d00800	/* Reserved ARMv8.0, write 1 */
#define	SCTLR_M				(UL(0x1) << 0)
#define	SCTLR_A				(UL(0x1) << 1)
#define	SCTLR_C				(UL(0x1) << 2)
#define	SCTLR_SA			(UL(0x1) << 3)
#define	SCTLR_SA0			(UL(0x1) << 4)
#define	SCTLR_CP15BEN			(UL(0x1) << 5)
#define	SCTLR_nAA			(UL(0x1) << 6)
#define	SCTLR_ITD			(UL(0x1) << 7)
#define	SCTLR_SED			(UL(0x1) << 8)
#define	SCTLR_UMA			(UL(0x1) << 9)
#define	SCTLR_EnRCTX			(UL(0x1) << 10)
#define	SCTLR_EOS			(UL(0x1) << 11)
#define	SCTLR_I				(UL(0x1) << 12)
#define	SCTLR_EnDB			(UL(0x1) << 13)
#define	SCTLR_DZE			(UL(0x1) << 14)
#define	SCTLR_UCT			(UL(0x1) << 15)
#define	SCTLR_nTWI			(UL(0x1) << 16)
/* Bit 17 is reserved */
#define	SCTLR_nTWE			(UL(0x1) << 18)
#define	SCTLR_WXN			(UL(0x1) << 19)
#define	SCTLR_TSCXT			(UL(0x1) << 20)
#define	SCTLR_IESB			(UL(0x1) << 21)
#define	SCTLR_EIS			(UL(0x1) << 22)
#define	SCTLR_SPAN			(UL(0x1) << 23)
#define	SCTLR_E0E			(UL(0x1) << 24)
#define	SCTLR_EE			(UL(0x1) << 25)
#define	SCTLR_UCI			(UL(0x1) << 26)
#define	SCTLR_EnDA			(UL(0x1) << 27)
#define	SCTLR_nTLSMD			(UL(0x1) << 28)
#define	SCTLR_LSMAOE			(UL(0x1) << 29)
#define	SCTLR_EnIB			(UL(0x1) << 30)
#define	SCTLR_EnIA			(UL(0x1) << 31)
/* Bits 34:32 are reserved */
#define	SCTLR_BT0			(UL(0x1) << 35)
#define	SCTLR_BT1			(UL(0x1) << 36)
#define	SCTLR_ITFSB			(UL(0x1) << 37)
#define	SCTLR_TCF0_MASK			(UL(0x3) << 38)
#define	SCTLR_TCF_MASK			(UL(0x3) << 40)
#define	SCTLR_ATA0			(UL(0x1) << 42)
#define	SCTLR_ATA			(UL(0x1) << 43)
#define	SCTLR_DSSBS			(UL(0x1) << 44)
#define	SCTLR_TWEDEn			(UL(0x1) << 45)
#define	SCTLR_TWEDEL_MASK		(UL(0xf) << 46)
/* Bits 53:50 are reserved */
#define	SCTLR_EnASR			(UL(0x1) << 54)
#define	SCTLR_EnAS0			(UL(0x1) << 55)
#define	SCTLR_EnALS			(UL(0x1) << 56)
#define	SCTLR_EPAN			(UL(0x1) << 57)

/* SCTLR_EL12 */
#define	SCTLR_EL12_REG			MRS_REG_ALT_NAME(SCTLR_EL12)
#define	SCTLR_EL12_op0			3
#define	SCTLR_EL12_op1			5
#define	SCTLR_EL12_CRn			1
#define	SCTLR_EL12_CRm			0
#define	SCTLR_EL12_op2			0

/* SPSR_EL1 */
#define	SPSR_EL1_REG			MRS_REG_ALT_NAME(SPSR_EL1)
#define	SPSR_EL1_op0			3
#define	SPSR_EL1_op1			0
#define	SPSR_EL1_CRn			4
#define	SPSR_EL1_CRm			0
#define	SPSR_EL1_op2			0
/*
 * When the exception is taken in AArch64:
 * M[3:2] is the exception level
 * M[1]   is unused
 * M[0]   is the SP select:
 *         0: always SP0
 *         1: current ELs SP
 */
#define	PSR_M_EL0t	0x00000000UL
#define	PSR_M_EL1t	0x00000004UL
#define	PSR_M_EL1h	0x00000005UL
#define	PSR_M_EL2t	0x00000008UL
#define	PSR_M_EL2h	0x00000009UL
#define	PSR_M_64	0x00000000UL
#define	PSR_M_32	0x00000010UL
#define	PSR_M_MASK	0x0000000fUL

#define	PSR_T		0x00000020UL

#define	PSR_AARCH32	0x00000010UL
#define	PSR_F		0x00000040UL
#define	PSR_I		0x00000080UL
#define	PSR_A		0x00000100UL
#define	PSR_D		0x00000200UL
#define	PSR_DAIF	(PSR_D | PSR_A | PSR_I | PSR_F)
/* The default DAIF mask. These bits are valid in spsr_el1 and daif */
#define	PSR_DAIF_DEFAULT (PSR_F)
#define	PSR_BTYPE	0x00000c00UL
#define	PSR_SSBS	0x00001000UL
#define	PSR_ALLINT	0x00002000UL
#define	PSR_IL		0x00100000UL
#define	PSR_SS		0x00200000UL
#define	PSR_PAN		0x00400000UL
#define	PSR_UAO		0x00800000UL
#define	PSR_DIT		0x01000000UL
#define	PSR_TCO		0x02000000UL
#define	PSR_V		0x10000000UL
#define	PSR_C		0x20000000UL
#define	PSR_Z		0x40000000UL
#define	PSR_N		0x80000000UL
#define	PSR_FLAGS	0xf0000000UL
/* PSR fields that can be set from 32-bit and 64-bit processes */
#define	PSR_SETTABLE_32	PSR_FLAGS
#define	PSR_SETTABLE_64	(PSR_FLAGS | PSR_SS)

/* SPSR_EL12 */
#define	SPSR_EL12_REG			MRS_REG_ALT_NAME(SPSR_EL12)
#define	SPSR_EL12_op0			3
#define	SPSR_EL12_op1			5
#define	SPSR_EL12_CRn			4
#define	SPSR_EL12_CRm			0
#define	SPSR_EL12_op2			0

/* REVIDR_EL1 - Revision ID Register */
#define	REVIDR_EL1			MRS_REG(REVIDR_EL1)
#define	REVIDR_EL1_op0			3
#define	REVIDR_EL1_op1			0
#define	REVIDR_EL1_CRn			0
#define	REVIDR_EL1_CRm			0
#define	REVIDR_EL1_op2			6

/* TCR_EL1 - Translation Control Register */
#define	TCR_EL1_REG			MRS_REG_ALT_NAME(TCR_EL1)
#define	TCR_EL1_op0			3
#define	TCR_EL1_op1			0
#define	TCR_EL1_CRn			2
#define	TCR_EL1_CRm			0
#define	TCR_EL1_op2			2
/* Bits 63:59 are reserved */
#define	TCR_DS_SHIFT		59
#define	TCR_DS			(UL(1) << TCR_DS_SHIFT)
#define	TCR_TCMA1_SHIFT		58
#define	TCR_TCMA1		(UL(1) << TCR_TCMA1_SHIFT)
#define	TCR_TCMA0_SHIFT		57
#define	TCR_TCMA0		(UL(1) << TCR_TCMA0_SHIFT)
#define	TCR_E0PD1_SHIFT		56
#define	TCR_E0PD1		(UL(1) << TCR_E0PD1_SHIFT)
#define	TCR_E0PD0_SHIFT		55
#define	TCR_E0PD0		(UL(1) << TCR_E0PD0_SHIFT)
#define	TCR_NFD1_SHIFT		54
#define	TCR_NFD1		(UL(1) << TCR_NFD1_SHIFT)
#define	TCR_NFD0_SHIFT		53
#define	TCR_NFD0		(UL(1) << TCR_NFD0_SHIFT)
#define	TCR_TBID1_SHIFT		52
#define	TCR_TBID1		(UL(1) << TCR_TBID1_SHIFT)
#define	TCR_TBID0_SHIFT		51
#define	TCR_TBID0		(UL(1) << TCR_TBID0_SHIFT)
#define	TCR_HWU162_SHIFT	50
#define	TCR_HWU162		(UL(1) << TCR_HWU162_SHIFT)
#define	TCR_HWU161_SHIFT	49
#define	TCR_HWU161		(UL(1) << TCR_HWU161_SHIFT)
#define	TCR_HWU160_SHIFT	48
#define	TCR_HWU160		(UL(1) << TCR_HWU160_SHIFT)
#define	TCR_HWU159_SHIFT	47
#define	TCR_HWU159		(UL(1) << TCR_HWU159_SHIFT)
#define	TCR_HWU1		\
    (TCR_HWU159 | TCR_HWU160 | TCR_HWU161 | TCR_HWU162)
#define	TCR_HWU062_SHIFT	46
#define	TCR_HWU062		(UL(1) << TCR_HWU062_SHIFT)
#define	TCR_HWU061_SHIFT	45
#define	TCR_HWU061		(UL(1) << TCR_HWU061_SHIFT)
#define	TCR_HWU060_SHIFT	44
#define	TCR_HWU060		(UL(1) << TCR_HWU060_SHIFT)
#define	TCR_HWU059_SHIFT	43
#define	TCR_HWU059		(UL(1) << TCR_HWU059_SHIFT)
#define	TCR_HWU0		\
    (TCR_HWU059 | TCR_HWU060 | TCR_HWU061 | TCR_HWU062)
#define	TCR_HPD1_SHIFT		42
#define	TCR_HPD1		(UL(1) << TCR_HPD1_SHIFT)
#define	TCR_HPD0_SHIFT		41
#define	TCR_HPD0		(UL(1) << TCR_HPD0_SHIFT)
#define	TCR_HD_SHIFT		40
#define	TCR_HD			(UL(1) << TCR_HD_SHIFT)
#define	TCR_HA_SHIFT		39
#define	TCR_HA			(UL(1) << TCR_HA_SHIFT)
#define	TCR_TBI1_SHIFT		38
#define	TCR_TBI1		(UL(1) << TCR_TBI1_SHIFT)
#define	TCR_TBI0_SHIFT		37
#define	TCR_TBI0		(UL(1) << TCR_TBI0_SHIFT)
#define	TCR_ASID_SHIFT		36
#define	TCR_ASID_WIDTH		1
#define	TCR_ASID_16		(UL(1) << TCR_ASID_SHIFT)
/* Bit 35 is reserved */
#define	TCR_IPS_SHIFT		32
#define	TCR_IPS_WIDTH		3
#define	TCR_IPS_32BIT		(UL(0) << TCR_IPS_SHIFT)
#define	TCR_IPS_36BIT		(UL(1) << TCR_IPS_SHIFT)
#define	TCR_IPS_40BIT		(UL(2) << TCR_IPS_SHIFT)
#define	TCR_IPS_42BIT		(UL(3) << TCR_IPS_SHIFT)
#define	TCR_IPS_44BIT		(UL(4) << TCR_IPS_SHIFT)
#define	TCR_IPS_48BIT		(UL(5) << TCR_IPS_SHIFT)
#define	TCR_TG1_SHIFT		30
#define	TCR_TG1_MASK		(UL(3) << TCR_TG1_SHIFT)
#define	TCR_TG1_16K		(UL(1) << TCR_TG1_SHIFT)
#define	TCR_TG1_4K		(UL(2) << TCR_TG1_SHIFT)
#define	TCR_TG1_64K		(UL(3) << TCR_TG1_SHIFT)
#define	TCR_SH1_SHIFT		28
#define	TCR_SH1_IS		(UL(3) << TCR_SH1_SHIFT)
#define	TCR_ORGN1_SHIFT		26
#define	TCR_ORGN1_WBWA		(UL(1) << TCR_ORGN1_SHIFT)
#define	TCR_IRGN1_SHIFT		24
#define	TCR_IRGN1_WBWA		(UL(1) << TCR_IRGN1_SHIFT)
#define	TCR_EPD1_SHIFT		23
#define	TCR_EPD1		(UL(1) << TCR_EPD1_SHIFT)
#define	TCR_A1_SHIFT		22
#define	TCR_A1			(UL(1) << TCR_A1_SHIFT)
#define	TCR_T1SZ_SHIFT		16
#define	TCR_T1SZ_MASK		(UL(0x3f) << TCR_T1SZ_SHIFT)
#define	TCR_T1SZ(x)		((x) << TCR_T1SZ_SHIFT)
#define	TCR_TG0_SHIFT		14
#define	TCR_TG0_MASK		(UL(3) << TCR_TG0_SHIFT)
#define	TCR_TG0_4K		(UL(0) << TCR_TG0_SHIFT)
#define	TCR_TG0_64K		(UL(1) << TCR_TG0_SHIFT)
#define	TCR_TG0_16K		(UL(2) << TCR_TG0_SHIFT)
#define	TCR_SH0_SHIFT		12
#define	TCR_SH0_IS		(UL(3) << TCR_SH0_SHIFT)
#define	TCR_ORGN0_SHIFT		10
#define	TCR_ORGN0_WBWA		(UL(1) << TCR_ORGN0_SHIFT)
#define	TCR_IRGN0_SHIFT		8
#define	TCR_IRGN0_WBWA		(UL(1) << TCR_IRGN0_SHIFT)
#define	TCR_EPD0_SHIFT		7
#define	TCR_EPD0		(UL(1) << TCR_EPD0_SHIFT)
/* Bit 6 is reserved */
#define	TCR_T0SZ_SHIFT		0
#define	TCR_T0SZ_MASK		(UL(0x3f) << TCR_T0SZ_SHIFT)
#define	TCR_T0SZ(x)		((x) << TCR_T0SZ_SHIFT)
#define	TCR_TxSZ(x)		(TCR_T1SZ(x) | TCR_T0SZ(x))

#define	TCR_CACHE_ATTRS	((TCR_IRGN0_WBWA | TCR_IRGN1_WBWA) |\
				(TCR_ORGN0_WBWA | TCR_ORGN1_WBWA))
#ifdef SMP
#define	TCR_SMP_ATTRS	(TCR_SH0_IS | TCR_SH1_IS)
#else
#define	TCR_SMP_ATTRS	0
#endif

/* TCR_EL12 */
#define	TCR_EL12_REG			MRS_REG_ALT_NAME(TCR_EL12)
#define	TCR_EL12_op0			3
#define	TCR_EL12_op1			5
#define	TCR_EL12_CRn			2
#define	TCR_EL12_CRm			0
#define	TCR_EL12_op2			2

/* TTBR0_EL1 & TTBR1_EL1 - Translation Table Base Register 0 & 1 */
#define	TTBR_ASID_SHIFT		48
#define	TTBR_ASID_MASK		(0xfffful << TTBR_ASID_SHIFT)
#define	TTBR_BADDR		0x0000fffffffffffeul
#define	TTBR_CnP_SHIFT		0
#define	TTBR_CnP		(1ul << TTBR_CnP_SHIFT)

/* TTBR0_EL1 */
#define	TTBR0_EL1_REG			MRS_REG_ALT_NAME(TTBR0_EL1)
#define	TTBR0_EL1_op0			3
#define	TTBR0_EL1_op1			0
#define	TTBR0_EL1_CRn			2
#define	TTBR0_EL1_CRm			0
#define	TTBR0_EL1_op2			0

/* TTBR0_EL12 */
#define	TTBR0_EL12_REG			MRS_REG_ALT_NAME(TTBR0_EL12)
#define	TTBR0_EL12_op0			3
#define	TTBR0_EL12_op1			5
#define	TTBR0_EL12_CRn			2
#define	TTBR0_EL12_CRm			0
#define	TTBR0_EL12_op2			0

/* TTBR1_EL1 */
#define	TTBR1_EL1_REG			MRS_REG_ALT_NAME(TTBR1_EL1)
#define	TTBR1_EL1_op0			3
#define	TTBR1_EL1_op1			0
#define	TTBR1_EL1_CRn			2
#define	TTBR1_EL1_CRm			0
#define	TTBR1_EL1_op2			1

/* TTBR1_EL12 */
#define	TTBR1_EL12_REG			MRS_REG_ALT_NAME(TTBR1_EL12)
#define	TTBR1_EL12_op0			3
#define	TTBR1_EL12_op1			5
#define	TTBR1_EL12_CRn			2
#define	TTBR1_EL12_CRm			0
#define	TTBR1_EL12_op2			1

/* VBAR_EL1 */
#define	VBAR_EL1_REG			MRS_REG_ALT_NAME(VBAR_EL1)
#define	VBAR_EL1_op0			3
#define	VBAR_EL1_op1			0
#define	VBAR_EL1_CRn			12
#define	VBAR_EL1_CRm			0
#define	VBAR_EL1_op2			0

/* VBAR_EL12 */
#define	VBAR_EL12_REG			MRS_REG_ALT_NAME(VBAR_EL12)
#define	VBAR_EL12_op0			3
#define	VBAR_EL12_op1			5
#define	VBAR_EL12_CRn			12
#define	VBAR_EL12_CRm			0
#define	VBAR_EL12_op2			0

/* ZCR_EL1 - SVE Control Register */
#define	ZCR_EL1			MRS_REG(ZCR_EL1)
#define	ZCR_EL1_REG		MRS_REG_ALT_NAME(ZCR_EL1_REG)
#define	ZCR_EL1_REG_op0		3
#define	ZCR_EL1_REG_op1		0
#define	ZCR_EL1_REG_CRn		1
#define	ZCR_EL1_REG_CRm		2
#define	ZCR_EL1_REG_op2		0
#define	ZCR_LEN_SHIFT		0
#define	ZCR_LEN_MASK		(0xf << ZCR_LEN_SHIFT)
#define	ZCR_LEN_BYTES(x)	((((x) & ZCR_LEN_MASK) + 1) * 16)

#endif /* !_MACHINE_ARMREG_H_ */

#endif /* !__arm__ */