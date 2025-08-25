/*-
 * Copyright (c) 2013, 2014 Andrew Turner
 * Copyright (c) 2021 The FreeBSD Foundation
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

#ifndef _MACHINE_HYPERVISOR_H_
#define	_MACHINE_HYPERVISOR_H_

/*
 * These registers are only useful when in hypervisor context,
 * e.g. specific to EL2, or controlling the hypervisor.
 */

/* CNTHCTL_EL2 - Counter-timer Hypervisor Control register */
#define	CNTHCTL_EVNTI_MASK	(0xf << 4) /* Bit to trigger event stream */
/* Valid if HCR_EL2.E2H == 0 */
#define	CNTHCTL_EL1PCTEN	(1 << 0) /* Allow physical counter access */
#define	CNTHCTL_EL1PCEN		(1 << 1) /* Allow physical timer access */
/* Valid if HCR_EL2.E2H == 1 */
#define	CNTHCTL_E2H_EL1PCTEN	(1 << 10) /* Allow physical counter access */
#define	CNTHCTL_E2H_EL1PTEN	(1 << 11) /* Allow physical timer access */
/* Unconditionally valid */
#define	CNTHCTL_EVNTDIR		(1 << 3) /* Control transition trigger bit */
#define	CNTHCTL_EVNTEN		(1 << 2) /* Enable event stream */

/* CPTR_EL2 - Architecture feature trap register */
/* Valid if HCR_EL2.E2H == 0 */
#define	CPTR_RES0		0x7fefc800
#define	CPTR_RES1		0x000032ff
#define	CPTR_TFP		0x00000400
/* Valid if HCR_EL2.E2H == 1 */
#define	CPTR_FPEN		0x00300000
/* Unconditionally valid */
#define	CPTR_TTA		0x00100000
#define	CPTR_TCPAC		0x80000000

/* HCR_EL2 - Hypervisor Config Register */
#define	HCR_VM				(UL(0x1) << 0)
#define	HCR_SWIO			(UL(0x1) << 1)
#define	HCR_PTW				(UL(0x1) << 2)
#define	HCR_FMO				(UL(0x1) << 3)
#define	HCR_IMO				(UL(0x1) << 4)
#define	HCR_AMO				(UL(0x1) << 5)
#define	HCR_VF				(UL(0x1) << 6)
#define	HCR_VI				(UL(0x1) << 7)
#define	HCR_VSE				(UL(0x1) << 8)
#define	HCR_FB				(UL(0x1) << 9)
#define	HCR_BSU_MASK			(UL(0x3) << 10)
#define	 HCR_BSU_IS			(UL(0x1) << 10)
#define	 HCR_BSU_OS			(UL(0x2) << 10)
#define	 HCR_BSU_FS			(UL(0x3) << 10)
#define	HCR_DC				(UL(0x1) << 12)
#define	HCR_TWI				(UL(0x1) << 13)
#define	HCR_TWE				(UL(0x1) << 14)
#define	HCR_TID0			(UL(0x1) << 15)
#define	HCR_TID1			(UL(0x1) << 16)
#define	HCR_TID2			(UL(0x1) << 17)
#define	HCR_TID3			(UL(0x1) << 18)
#define	HCR_TSC				(UL(0x1) << 19)
#define	HCR_TIDCP			(UL(0x1) << 20)
#define	HCR_TACR			(UL(0x1) << 21)
#define	HCR_TSW				(UL(0x1) << 22)
#define	HCR_TPCP			(UL(0x1) << 23)
#define	HCR_TPU				(UL(0x1) << 24)
#define	HCR_TTLB			(UL(0x1) << 25)
#define	HCR_TVM				(UL(0x1) << 26)
#define	HCR_TGE				(UL(0x1) << 27)
#define	HCR_TDZ				(UL(0x1) << 28)
#define	HCR_HCD				(UL(0x1) << 29)
#define	HCR_TRVM			(UL(0x1) << 30)
#define	HCR_RW				(UL(0x1) << 31)
#define	HCR_CD				(UL(0x1) << 32)
#define	HCR_ID				(UL(0x1) << 33)
#define	HCR_E2H				(UL(0x1) << 34)
#define	HCR_TLOR			(UL(0x1) << 35)
#define	HCR_TERR			(UL(0x1) << 36)
#define	HCR_TEA				(UL(0x1) << 37)
#define	HCR_MIOCNCE			(UL(0x1) << 38)
/* Bit 39 is reserved */
#define	HCR_APK				(UL(0x1) << 40)
#define	HCR_API				(UL(0x1) << 41)
#define	HCR_NV				(UL(0x1) << 42)
#define	HCR_NV1				(UL(0x1) << 43)
#define	HCR_AT				(UL(0x1) << 44)
#define	HCR_NV2				(UL(0x1) << 45)
#define	HCR_FWB				(UL(0x1) << 46)
#define	HCR_FIEN			(UL(0x1) << 47)
/* Bit 48 is reserved */
#define	HCR_TID4			(UL(0x1) << 49)
#define	HCR_TICAB			(UL(0x1) << 50)
#define	HCR_AMVOFFEN			(UL(0x1) << 51)
#define	HCR_TOCU			(UL(0x1) << 52)
#define	HCR_EnSCXT			(UL(0x1) << 53)
#define	HCR_TTLBIS			(UL(0x1) << 54)
#define	HCR_TTLBOS			(UL(0x1) << 55)
#define	HCR_ATA				(UL(0x1) << 56)
#define	HCR_DCT				(UL(0x1) << 57)
#define	HCR_TID5			(UL(0x1) << 58)
#define	HCR_TWEDEn			(UL(0x1) << 59)
#define	HCR_TWEDEL_MASK			(UL(0xf) << 60)

/* HPFAR_EL2 - Hypervisor IPA Fault Address Register */
#define	HPFAR_EL2_FIPA_SHIFT	4
#define	HPFAR_EL2_FIPA_MASK	0xfffffffff0
#define	HPFAR_EL2_FIPA_GET(x)	\
    (((x) & HPFAR_EL2_FIPA_MASK) >> HPFAR_EL2_FIPA_SHIFT)
/* HPFAR_EL2_FIPA holds the 4k page address */
#define	HPFAR_EL2_FIPA_ADDR(x)	\
    (HPFAR_EL2_FIPA_GET(x) << 12)
/* The bits from FAR_EL2 we need to add to HPFAR_EL2_FIPA_ADDR */
#define	FAR_EL2_HPFAR_PAGE_MASK	(0xffful)

/* ICC_SRE_EL2 */
#define	ICC_SRE_EL2_SRE		(1UL << 0)
#define	ICC_SRE_EL2_EN		(1UL << 3)

/* SCTLR_EL2 - System Control Register */
#define	SCTLR_EL2_RES1		0x30c50830
#define	SCTLR_EL2_M_SHIFT	0
#define	SCTLR_EL2_M		(0x1UL << SCTLR_EL2_M_SHIFT)
#define	SCTLR_EL2_A_SHIFT	1
#define	SCTLR_EL2_A		(0x1UL << SCTLR_EL2_A_SHIFT)
#define	SCTLR_EL2_C_SHIFT	2
#define	SCTLR_EL2_C		(0x1UL << SCTLR_EL2_C_SHIFT)
#define	SCTLR_EL2_SA_SHIFT	3
#define	SCTLR_EL2_SA		(0x1UL << SCTLR_EL2_SA_SHIFT)
#define	SCTLR_EL2_EOS_SHIFT	11
#define	SCTLR_EL2_EOS		(0x1UL << SCTLR_EL2_EOS_SHIFT)
#define	SCTLR_EL2_I_SHIFT	12
#define	SCTLR_EL2_I		(0x1UL << SCTLR_EL2_I_SHIFT)
#define	SCTLR_EL2_WXN_SHIFT	19
#define	SCTLR_EL2_WXN		(0x1UL << SCTLR_EL2_WXN_SHIFT)
#define	SCTLR_EL2_EIS_SHIFT	22
#define	SCTLR_EL2_EIS		(0x1UL << SCTLR_EL2_EIS_SHIFT)
#define	SCTLR_EL2_EE_SHIFT	25
#define	SCTLR_EL2_EE		(0x1UL << SCTLR_EL2_EE_SHIFT)

/* TCR_EL2 - Translation Control Register */
#define	TCR_EL2_RES1		((0x1UL << 31) | (0x1UL << 23))
#define	TCR_EL2_T0SZ_SHIFT	0
#define	TCR_EL2_T0SZ_MASK	(0x3fUL << TCR_EL2_T0SZ_SHIFT)
#define	TCR_EL2_T0SZ(x)		((x) << TCR_EL2_T0SZ_SHIFT)
/* Bits 7:6 are reserved */
#define	TCR_EL2_IRGN0_SHIFT	8
#define	TCR_EL2_IRGN0_MASK	(0x3UL << TCR_EL2_IRGN0_SHIFT)
#define	TCR_EL2_IRGN0_WBWA	(1UL << TCR_EL2_IRGN0_SHIFT)
#define	TCR_EL2_ORGN0_SHIFT	10
#define	TCR_EL2_ORGN0_MASK	(0x3UL << TCR_EL2_ORGN0_SHIFT)
#define	TCR_EL2_ORGN0_WBWA	(1UL << TCR_EL2_ORGN0_SHIFT)
#define	TCR_EL2_SH0_SHIFT	12
#define	TCR_EL2_SH0_MASK	(0x3UL << TCR_EL2_SH0_SHIFT)
#define	TCR_EL2_SH0_IS		(3UL << TCR_EL2_SH0_SHIFT)
#define	TCR_EL2_TG0_SHIFT	14
#define	TCR_EL2_TG0_MASK	(0x3UL << TCR_EL2_TG0_SHIFT)
#define	TCR_EL2_TG0_4K		(0x0UL << TCR_EL2_TG0_SHIFT)
#define	TCR_EL2_TG0_64K		(0x1UL << TCR_EL2_TG0_SHIFT)
#define	TCR_EL2_TG0_16K		(0x2UL << TCR_EL2_TG0_SHIFT)
#define	TCR_EL2_PS_SHIFT	16
#define	TCR_EL2_PS_MASK		(0xfUL << TCR_EL2_PS_SHIFT)
#define	 TCR_EL2_PS_32BITS	(0UL << TCR_EL2_PS_SHIFT)
#define	 TCR_EL2_PS_36BITS	(1UL << TCR_EL2_PS_SHIFT)
#define	 TCR_EL2_PS_40BITS	(2UL << TCR_EL2_PS_SHIFT)
#define	 TCR_EL2_PS_42BITS	(3UL << TCR_EL2_PS_SHIFT)
#define	 TCR_EL2_PS_44BITS	(4UL << TCR_EL2_PS_SHIFT)
#define	 TCR_EL2_PS_48BITS	(5UL << TCR_EL2_PS_SHIFT)
#define	 TCR_EL2_PS_52BITS	(6UL << TCR_EL2_PS_SHIFT)
#define	TCR_EL2_HPD_SHIFT	24
#define	TCR_EL2_HPD		(1UL << TCR_EL2_HPD_SHIFT)
#define	TCR_EL2_HWU59_SHIFT	25
#define	TCR_EL2_HWU59		(1UL << TCR_EL2_HWU59_SHIFT)
#define	TCR_EL2_HWU60_SHIFT	26
#define	TCR_EL2_HWU60		(1UL << TCR_EL2_HWU60_SHIFT)
#define	TCR_EL2_HWU61_SHIFT	27
#define	TCR_EL2_HWU61		(1UL << TCR_EL2_HWU61_SHIFT)
#define	TCR_EL2_HWU62_SHIFT	28
#define	TCR_EL2_HWU62		(1UL << TCR_EL2_HWU62_SHIFT)
#define	TCR_EL2_HWU		\
    (TCR_EL2_HWU59 | TCR_EL2_HWU60 | TCR_EL2_HWU61 | TCR_EL2_HWU62)

/* VMPDIR_EL2 - Virtualization Multiprocessor ID Register */
#define	VMPIDR_EL2_U		0x0000000040000000
#define	VMPIDR_EL2_MT		0x0000000001000000
#define	VMPIDR_EL2_RES1		0x0000000080000000

/* VTCR_EL2 - Virtualization Translation Control Register */
#define	VTCR_EL2_RES1		(0x1UL << 31)
#define	VTCR_EL2_T0SZ_SHIFT	0
#define	VTCR_EL2_T0SZ_MASK	(0x3fUL << VTCR_EL2_T0SZ_SHIFT)
#define	VTCR_EL2_T0SZ(x)	((x) << VTCR_EL2_T0SZ_SHIFT)
#define	VTCR_EL2_SL0_SHIFT	6
#define	 VTCR_EL2_SL0_4K_LVL2	(0x0UL << VTCR_EL2_SL0_SHIFT)
#define	 VTCR_EL2_SL0_4K_LVL1	(0x1UL << VTCR_EL2_SL0_SHIFT)
#define	 VTCR_EL2_SL0_4K_LVL0	(0x2UL << VTCR_EL2_SL0_SHIFT)
#define	 VTCR_EL2_SL0_16K_LVL2	(0x1UL << VTCR_EL2_SL0_SHIFT)
#define	 VTCR_EL2_SL0_16K_LVL1	(0x2UL << VTCR_EL2_SL0_SHIFT)
#define	 VTCR_EL2_SL0_16K_LVL0	(0x3UL << VTCR_EL2_SL0_SHIFT)
#define	VTCR_EL2_IRGN0_SHIFT	8
#define	 VTCR_EL2_IRGN0_WBWA	(0x1UL << VTCR_EL2_IRGN0_SHIFT)
#define	VTCR_EL2_ORGN0_SHIFT	10
#define	 VTCR_EL2_ORGN0_WBWA	(0x1UL << VTCR_EL2_ORGN0_SHIFT)
#define	VTCR_EL2_SH0_SHIFT	12
#define	 VTCR_EL2_SH0_NS	(0x0UL << VTCR_EL2_SH0_SHIFT)
#define	 VTCR_EL2_SH0_OS	(0x2UL << VTCR_EL2_SH0_SHIFT)
#define	 VTCR_EL2_SH0_IS	(0x3UL << VTCR_EL2_SH0_SHIFT)
#define	VTCR_EL2_TG0_SHIFT	14
#define	 VTCR_EL2_TG0_4K	(0x0UL << VTCR_EL2_TG0_SHIFT)
#define	 VTCR_EL2_TG0_64K	(0x1UL << VTCR_EL2_TG0_SHIFT)
#define	 VTCR_EL2_TG0_16K	(0x2UL << VTCR_EL2_TG0_SHIFT)
#define	VTCR_EL2_PS_SHIFT	16
#define	 VTCR_EL2_PS_32BIT	(0x0UL << VTCR_EL2_PS_SHIFT)
#define	 VTCR_EL2_PS_36BIT	(0x1UL << VTCR_EL2_PS_SHIFT)
#define	 VTCR_EL2_PS_40BIT	(0x2UL << VTCR_EL2_PS_SHIFT)
#define	 VTCR_EL2_PS_42BIT	(0x3UL << VTCR_EL2_PS_SHIFT)
#define	 VTCR_EL2_PS_44BIT	(0x4UL << VTCR_EL2_PS_SHIFT)
#define	 VTCR_EL2_PS_48BIT	(0x5UL << VTCR_EL2_PS_SHIFT)

/* VTTBR_EL2 - Virtualization Translation Table Base Register */
#define	VTTBR_VMID_MASK		0xffff000000000000
#define	VTTBR_VMID_SHIFT	48
/* Assumed to be 0 by locore.S */
#define	VTTBR_HOST		0x0000000000000000

/* MDCR_EL2 - Hyp Debug Control Register */
#define	MDCR_EL2_HPMN_MASK	0x1f
#define	MDCR_EL2_HPMN_SHIFT	0
#define	MDCR_EL2_TPMCR_SHIFT	5
#define	MDCR_EL2_TPMCR		(0x1UL << MDCR_EL2_TPMCR_SHIFT)
#define	MDCR_EL2_TPM_SHIFT	6
#define	MDCR_EL2_TPM		(0x1UL << MDCR_EL2_TPM_SHIFT)
#define	MDCR_EL2_HPME_SHIFT	7
#define	MDCR_EL2_HPME		(0x1UL << MDCR_EL2_HPME_SHIFT)
#define	MDCR_EL2_TDE_SHIFT	8
#define	MDCR_EL2_TDE		(0x1UL << MDCR_EL2_TDE_SHIFT)
#define	MDCR_EL2_TDA_SHIFT	9
#define	MDCR_EL2_TDA		(0x1UL << MDCR_EL2_TDA_SHIFT)
#define	MDCR_EL2_TDOSA_SHIFT	10
#define	MDCR_EL2_TDOSA		(0x1UL << MDCR_EL2_TDOSA_SHIFT)
#define	MDCR_EL2_TDRA_SHIFT	11
#define	MDCR_EL2_TDRA		(0x1UL << MDCR_EL2_TDRA_SHIFT)
#define	MDCR_E2PB_SHIFT		12
#define	MDCR_E2PB_MASK		(0x3UL << MDCR_E2PB_SHIFT)
#define	MDCR_TPMS_SHIFT		14
#define	MDCR_TPMS		(0x1UL << MDCR_TPMS_SHIFT)
#define	MDCR_EnSPM_SHIFT	15
#define	MDCR_EnSPM		(0x1UL << MDCR_EnSPM_SHIFT)
#define	MDCR_HPMD_SHIFT		17
#define	MDCR_HPMD		(0x1UL << MDCR_HPMD_SHIFT)
#define	MDCR_TTRF_SHIFT		19
#define	MDCR_TTRF		(0x1UL << MDCR_TTRF_SHIFT)
#define	MDCR_HCCD_SHIFT		23
#define	MDCR_HCCD		(0x1UL << MDCR_HCCD_SHIFT)
#define	MDCR_E2TB_SHIFT		24
#define	MDCR_E2TB_MASK		(0x3UL << MDCR_E2TB_SHIFT)
#define	MDCR_HLP_SHIFT		26
#define	MDCR_HLP		(0x1UL << MDCR_HLP_SHIFT)
#define	MDCR_TDCC_SHIFT		27
#define	MDCR_TDCC		(0x1UL << MDCR_TDCC_SHIFT)
#define	MDCR_MTPME_SHIFT	28
#define	MDCR_MTPME		(0x1UL << MDCR_MTPME_SHIFT)
#define	MDCR_HPMFZO_SHIFT	29
#define	MDCR_HPMFZO		(0x1UL << MDCR_HPMFZO_SHIFT)
#define	MDCR_PMSSE_SHIFT	30
#define	MDCR_PMSSE_MASK		(0x3UL << MDCR_PMSSE_SHIFT)
#define	MDCR_HPMFZS_SHIFT	36
#define	MDCR_HPMFZS		(0x1UL << MDCR_HPMFZS_SHIFT)
#define	MDCR_PMEE_SHIFT		40
#define	MDCR_PMEE_MASK		(0x3UL << MDCR_PMEE_SHIFT)
#define	MDCR_EBWE_SHIFT		43
#define	MDCR_EBWE		(0x1UL << MDCR_EBWE_SHIFT)

#endif /* !_MACHINE_HYPERVISOR_H_ */