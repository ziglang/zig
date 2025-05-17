/*	$NetBSD: spr.h,v 1.7 2020/07/06 10:31:23 rin Exp $	*/

#ifndef _POWERPC_OEA_SPR_H_
#define	_POWERPC_OEA_SPR_H_

#if !defined(_LOCORE) && defined(_KERNEL)

#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif

#if defined(PPC_OEA64_BRIDGE) || defined (_ARCH_PPC64)
#include <powerpc/psl.h>
#include <powerpc/spr.h>
#endif

#endif /* !_LOCORE && _KERNEL */

/*
 * Special Purpose Register declarations.
 *
 * The first column in the comments indicates which PowerPC architectures the
 * SPR is valid on - E for BookE series, 4 for 4xx series,
 * 6 for 6xx/7xx series and 8 for 8xx (but not most 8xxx) series.
 */

#define	SPR_MQ			0x000	/* ..6. 601 MQ register */
#define	SPR_RTCU_R		0x004	/* ..6. 601 RTC Upper - Read */
#define	SPR_RTCL_R		0x005	/* ..6. 601 RTC Lower - Read */
#define	SPR_DSISR		0x012	/* ..68 DSI exception source */
#define	  DSISR_DIRECT		  0x80000000 /* Direct-store error exception */
#define	  DSISR_NOTFOUND	  0x40000000 /* Translation not found */
#define	  DSISR_PROTECT		  0x08000000 /* Memory access not permitted */
#define	  DSISR_INVRX		  0x04000000 /* Reserve-indexed insn direct-store access */
#define	  DSISR_STORE		  0x02000000 /* Store operation */
#define	  DSISR_DABR		  0x00400000 /* DABR match */
#define	  DSISR_SEGMENT		  0x00200000 /* XXX; not in 6xx PEM */
#define	  DSISR_EAR		  0x00100000 /* eciwx/ecowx && EAR[E] == 0 */
#define	SPR_DAR			0x013	/* ..68 Data Address Register */
#define	SPR_RTCU_W		0x014	/* ..6. 601 RTC Upper - Write */
#define	SPR_RTCL_W		0x015	/* ..6. 601 RTC Lower - Write */
#define	SPR_SDR1		0x019	/* ..68 Page table base address register */
#define	SPR_VRSAVE		0x100	/* ..6. AltiVec VRSAVE */
#define SPR_SCOMC		0x114	/* .... SCOM Control Register (970) */
#define SPR_SCOMD		0x115	/* .... SCOM Data Register (970) */
#define  SCOM_PCR		  0x0aa00100	/* Power Control Register */
#define  SCOM_PCR_BIT		  0x80000000	/* Data bit */
#define  SCOM_PSR		  0x40800100	/* Power Status Register */
#define  PSR_RECEIVED		  (1ULL << 61)
#define  PSR_COMPLETED		  (1ULL << 60)
#define  SCOMC_READ		  0x00008000
#define  SCOMC_WRITE		  0x00000000
#define	SPR_ASR			0x118	/* ..6. Address Space Register (PPC64) */
#define	SPR_EAR			0x11a	/* ..68 External Access Register */
#define	  MPC601		  0x0001
#define	  MPC603		  0x0003
#define	  MPC604		  0x0004
#define	  MPC602		  0x0005
#define	  MPC603e		  0x0006
#define	  MPC603ev		  0x0007
#define	  MPC750		  0x0008
#define	  MPC604e		  0x0009
#define	  MPC604ev		  0x000a
#define	  MPC7400		  0x000c
#define	  MPC620		  0x0014
#define   IBMRS64II		  0x0033
#define   IBMRS64IIIp		  0x0034
#define   IBMPOWER4		  0x0035
#define   IBMRS64IIIi		  0x0036
#define   IBMRS64IV		  0x0037
#define   IBMPOWER4II		  0x0038
#define   IBM970		  0x0039
#define   IBMPOWER5GR		  0x003a
#define   IBMPOWER5GS		  0x003b
#define   IBM970FX		  0x003c
#define   IBMPOWER6		  0x003e
#define   IBMPOWER3		  0x0040
#define	  IBMPOWER3II		  0x0041
#define   IBM970MP		  0x0044
#define   IBM970GX		  0x0045
#define   IBMCELL		  0x0070
#define	  MPC8240		  0x0081
#define   PA6T			  0x0090
#define   IBMPOWER6P5		  0x0f00
#define   IBMSTB25		  0x5151
#define	  IBM750FX		  0x7000
#define   IBM750GX		  0x7002
#define	  MPC7450		  0x8000
#define	  MPC7455		  0x8001
#define   MPC7457		  0x8002
#define   MPC7447A		  0x8003
#define   MPC7448		  0x8004
#define MPC745X_P(v)		  ((v & 0xFFF8) == 0x8000)
#define	  MPC7410		  0x800c
#define	  MPC5200		  0x8011
#define   MPC8245		  0x8081
#define   MPCG2			  0x8082
#define   MPCe300c1		  0x8083
#define   MPCe300c2		  0x8084
#define   MPCe300c3		  0x8085
#define SPR_HIOR		0x137	/* .... HW Interrupt Offset (970) */

#define	SPR_IBAT0U		0x210	/* ..68 Instruction BAT Reg 0 Upper */
#define	SPR_IBAT0L		0x211	/* ..6. Instruction BAT Reg 0 Lower */
#define	SPR_IBAT1U		0x212	/* ..6. Instruction BAT Reg 1 Upper */
#define	SPR_IBAT1L		0x213	/* ..6. Instruction BAT Reg 1 Lower */
#define	SPR_IBAT2U		0x214	/* ..6. Instruction BAT Reg 2 Upper */
#define	SPR_IBAT2L		0x215	/* ..6. Instruction BAT Reg 2 Lower */
#define	SPR_IBAT3U		0x216	/* ..6. Instruction BAT Reg 3 Upper */
#define	SPR_IBAT3L		0x217	/* ..6. Instruction BAT Reg 3 Lower */
#define	SPR_DBAT0U		0x218	/* ..6. Data BAT Reg 0 Upper */
#define	SPR_DBAT0L		0x219	/* ..6. Data BAT Reg 0 Lower */
#define	SPR_DBAT1U		0x21a	/* ..6. Data BAT Reg 1 Upper */
#define	SPR_DBAT1L		0x21b	/* ..6. Data BAT Reg 1 Lower */
#define	SPR_DBAT2U		0x21c	/* ..6. Data BAT Reg 2 Upper */
#define	SPR_DBAT2L		0x21d	/* ..6. Data BAT Reg 2 Lower */
#define	SPR_DBAT3U		0x21e	/* ..6. Data BAT Reg 3 Upper */
#define	SPR_DBAT3L		0x21f	/* ..6. Data BAT Reg 3 Lower */
#define	SPR_IBAT4U		0x230	/* ..6. Instruction BAT Reg 4 Upper */
#define	SPR_IBAT4L		0x231	/* ..6. Instruction BAT Reg 4 Lower */
#define	SPR_IBAT5U		0x232	/* ..6. Instruction BAT Reg 5 Upper */
#define	SPR_IBAT5L		0x233	/* ..6. Instruction BAT Reg 5 Lower */
#define	SPR_IBAT6U		0x234	/* ..6. Instruction BAT Reg 6 Upper */
#define	SPR_IBAT6L		0x235	/* ..6. Instruction BAT Reg 6 Lower */
#define	SPR_IBAT7U		0x236	/* ..6. Instruction BAT Reg 7 Upper */
#define	SPR_IBAT7L		0x237	/* ..6. Instruction BAT Reg 7 Lower */
#define	SPR_DBAT4U		0x238	/* ..6. Data BAT Reg 4 Upper */
#define	SPR_DBAT4L		0x239	/* ..6. Data BAT Reg 4 Lower */
#define	SPR_DBAT5U		0x23a	/* ..6. Data BAT Reg 5 Upper */
#define	SPR_DBAT5L		0x23b	/* ..6. Data BAT Reg 5 Lower */
#define	SPR_DBAT6U		0x23c	/* ..6. Data BAT Reg 6 Upper */
#define	SPR_DBAT6L		0x23d	/* ..6. Data BAT Reg 6 Lower */
#define	SPR_DBAT7U		0x23e	/* ..6. Data BAT Reg 7 Upper */
#define	SPR_DBAT7L		0x23f	/* ..6. Data BAT Reg 7 Upper */
#define	SPR_UMMCR2		0x3a0	/* ..6. User Monitor Mode Control Register 2 */
#define	SPR_UMMCR0		0x3a8	/* ..6. User Monitor Mode Control Register 0 */
#define	SPR_USIA		0x3ab	/* ..6. User Sampled Instruction Address */
#define	SPR_UMMCR1		0x3ac	/* ..6. User Monitor Mode Control Register 1 */
#define	SPR_MMCR2		0x3b0	/* ..6. Monitor Mode Control Register 2 */
#define	 SPR_MMCR2_THRESHMULT_32  0x80000000 /* Multiply MMCR0 threshold by 32 */
#define	 SPR_MMCR2_THRESHMULT_2	  0x00000000 /* Multiply MMCR0 threshold by 2 */
#define	SPR_PMC5		0x3b1	/* ..6. Performance Counter Register 5 */
#define	SPR_PMC6		0x3b2	/* ..6. Performance Counter Register 6 */

#define	SPR_MMCR0		0x3b8	/* ..6. Monitor Mode Control Register 0 */
#define	  MMCR0_FC		  0x80000000 /* Freeze counters */
#define	  MMCR0_FCS		  0x40000000 /* Freeze counters in supervisor mode */
#define	  MMCR0_FCP		  0x20000000 /* Freeze counters in user mode */
#define	  MMCR0_FCM1		  0x10000000 /* Freeze counters when mark=1 */
#define	  MMCR0_FCM0		  0x08000000 /* Freeze counters when mark=0 */
#define	  MMCR0_PMXE		  0x04000000 /* Enable PM interrupt */
#define	  MMCR0_FCECE		  0x02000000 /* Freeze counters after event */
#define	  MMCR0_TBSEL_15	  0x01800000 /* Count bit 15 of TBL */
#define	  MMCR0_TBSEL_19	  0x01000000 /* Count bit 19 of TBL */
#define	  MMCR0_TBSEL_23	  0x00800000 /* Count bit 23 of TBL */
#define	  MMCR0_TBSEL_31	  0x00000000 /* Count bit 31 of TBL */
#define	  MMCR0_TBEE		  0x00400000 /* Time-base event enable */
#define	  MMCRO_THRESHOLD(x)	  ((x) << 16) /* Threshold value */
#define	  MMCR0_PMC1CE		  0x00008000 /* PMC1 condition enable */
#define	  MMCR0_PMCNCE		  0x00004000 /* PMCn condition enable */
#define	  MMCR0_TRIGGER		  0x00002000 /* Trigger */
#define	  MMCR0_PMC1SEL(x)	  ((x) << 6) /* PMC1 selector */
#define	  MMCR0_PMC2SEL(x)	  ((x) << 0) /* PMC2 selector */
#define	SPR_PMC1		0x3b9	/* ..6. Performance Counter Register 1 */
#define	SPR_PMC2		0x3ba	/* ..6. Performance Counter Register 2 */
#define	SPR_SIA			0x3bb	/* ..6. Sampled Instruction Address */
#define	SPR_MMCR1		0x3bc	/* ..6. Monitor Mode Control Register 2 */
#define	  MMCR1_PMC3SEL(x)	  ((x) << 27) /* PMC 3 selector */
#define	  MMCR1_PMC4SEL(x)	  ((x) << 22) /* PMC 4 selector */
#define	  MMCR1_PMC5SEL(x)	  ((x) << 17) /* PMC 5 selector */
#define	  MMCR1_PMC6SEL(x)	  ((x) << 11) /* PMC 6 selector */

#define	SPR_PMC3		0x3bd	/* ..6. Performance Counter Register 3 */
#define	SPR_PMC4		0x3be	/* ..6. Performance Counter Register 4 */
#define	SPR_DMISS		0x3d0	/* ..68 Data TLB Miss Address Register */
#define	SPR_DCMP		0x3d1	/* ..68 Data TLB Compare Register */
#define	SPR_HASH1		0x3d2	/* ..68 Primary Hash Address Register */
#define	SPR_HASH2		0x3d3	/* ..68 Secondary Hash Address Register */
#define	SPR_IMISS		0x3d4	/* ..68 Instruction TLB Miss Address Register */
#define	SPR_TLBMISS		0x3d4	/* ..6. TLB Miss Address Register */
#define	SPR_ICMP		0x3d5	/* ..68 Instruction TLB Compare Register */
#define	SPR_PTEHI		0x3d5	/* ..6. Instruction TLB Compare Register */
#define	SPR_RPA			0x3d6	/* ..68 Required Physical Address Register */
#define	SPR_PTELO		0x3d6	/* ..6. Required Physical Address Register */
#define SPR_HID0		0x3f0	/* E.68 Hardware Implementation Register
 0 */
#define SPR_HID1		0x3f1	/* E.68 Hardware Implementation Register
 1 */
#define SPR_HID4		0x3f4   /* ..6. 970 HID4 */
#define SPR_HID5		0x3f6   /* ..6. 970 HID5 */
#define	SPR_DABR		0x3f5	/* ..6. Data Address Breakpoint Register */
#define	SPR_MSSCR0		0x3f6	/* ..6. Memory SubSystem Control Register */
#define	  MSSCR0_SHDEN		  0x80000000 /* 0: Shared-state enable */
#define	  MSSCR0_SHDPEN3	  0x40000000 /* 1: ~SHD[01] signal enable in MEI mode */
#define	  MSSCR0_L1INTVEN	  0x38000000 /* 2-4: L1 data cache ~HIT intervention enable */
#define	  MSSCR0_L2INTVEN	  0x07000000 /* 5-7: L2 data cache ~HIT intervention enable */
#define	  MSSCR0_DL1HWF		  0x00800000 /* 8: L1 data cache hardware flush */
#define	  MSSCR0_MBO		  0x00400000 /* 9: must be one */
#define	  MSSCR0_EMODE		  0x00200000 /* 10: MPX bus mode (read-only) */
#define	  MSSCR0_ABD		  0x00100000 /* 11: address bus driven (read-only) */
#define	  MSSCR0_BMODE		  0x0000c000 /* 16-17: Bus Mode (read-only) (7450) */
#define	  MSSCR0_ID		  0x00000040 /* 26: Processor ID */
#define	  MSSCR0_L2PFE		  0x00000003 /* 30-31: L2 prefetching enabled (7450) */
#define	SPR_L2PM		0x3f8	/* ..6. L2 Private Memory Control Register */
#define	SPR_L2CR		0x3f9	/* ..6. L2 Control Register */
#define	  L2CR_L2E		  0x80000000 /* 0: L2 enable */
#define	  L2CR_L2PE		  0x40000000 /* 1: L2 data parity enable */
#define	  L2CR_L2SIZ		  0x30000000 /* 2-3: L2 size */
#define	   L2SIZ_2M		  0x00000000
#define	   L2SIZ_256K		  0x10000000
#define	   L2SIZ_512K		  0x20000000
#define	   L2SIZ_1M		  0x30000000
#define	  L2CR_L2CLK		  0x0e000000 /* 4-6: L2 clock ratio */
#define	   L2CLK_DIS		  0x00000000 /* disable L2 clock */
#define	   L2CLK_10		  0x02000000 /* core clock / 1   */
#define	   L2CLK_15		  0x04000000 /*            / 1.5 */
#define	   L2CLK_35		  0x06000000 /*            / 3.5 */
#define	   L2CLK_20		  0x08000000 /*            / 2   */
#define	   L2CLK_25		  0x0a000000 /*            / 2.5 */
#define	   L2CLK_30		  0x0c000000 /*            / 3   */
#define	   L2CLK_40		  0x0e000000 /*            / 4   */
#define	  L2CR_L2RAM		  0x01800000 /* 7-8: L2 RAM type */
#define	   L2RAM_FLOWTHRU_BURST	  0x00000000
#define	   L2RAM_PIPELINE_BURST	  0x01000000
#define	   L2RAM_PIPELINE_LATE	  0x01800000
#define	  L2CR_L2DO		  0x00400000 /* 9: L2 data-only.
				      Setting this bit disables instruction
				      caching. */
#define	  L2CR_L2I		  0x00200000 /* 10: L2 global invalidate. */
#define	  L2CR_L2CTL		  0x00100000 /* 11: L2 RAM control (ZZ enable).
				      Enables automatic operation of the
				      L2ZZ (low-power mode) signal. */
#define	  L2CR_L2WT		  0x00080000 /* 12: L2 write-through. */
#define	  L2CR_L2TS		  0x00040000 /* 13: L2 test support. */
#define	  L2CR_L2OH		  0x00030000 /* 14-15: L2 output hold. */
#define	  L2CR_L2SL		  0x00008000 /* 16: L2 DLL slow. */
#define	  L2CR_L2DF		  0x00004000 /* 17: L2 differential clock. */
#define	  L2CR_L2BYP		  0x00002000 /* 18: L2 DLL bypass. */
#define	  L2CR_L2FA		  0x00001000 /* 19: L2 flush assist (for software flush). */
#define	  L2CR_L2HWF		  0x00000800 /* 20: L2 hardware flush. */
#define	  L2CR_L2IO		  0x00000400 /* 21: L2 instruction-only. */
#define	  L2CR_L2CLKSTP		  0x00000200 /* 22: L2 clock stop. */
#define	  L2CR_L2DRO		  0x00000100 /* 23: L2DLL rollover checkstop enable. */
#define	  L2CR_L2IP		  0x00000001 /* 31: L2 global invalidate in */
					     /*     progress (read only). */
#define	SPR_L3CR		0x3fa	/* ..6. L3 Control Register */
#define	  L3CR_RESERVED		  0x0438003a /* Reserved bits in L3CR */
#define	  L3CR_L3E		  0x80000000 /* 0: L3 enable */
#define	  L3CR_L3PE		  0x40000000 /* 1: L3 data parity checking enable */
#define	  L3CR_L3APE		  0x20000000 /* 2: L3 address parity checking enable */
#define	  L3CR_L3SIZ		  0x10000000 /* 3: L3 size (0=1MB, 1=2MB) */
#define	   L3SIZ_1M		  0x00000000
#define	   L3SIZ_2M		  0x10000000
#define	  L3CR_L3CLKEN		  0x08000000 /* 4: Enables the L3_CLK[0:1] signals */
#define	  L3CR_L3CLK		  0x03800000 /* 6-8: L3 clock ratio */
#define	   L3CLK_60		  0x00000000 /* core clock / 6   */
#define	   L3CLK_20		  0x01000000 /*            / 2   */
#define	   L3CLK_25		  0x01800000 /*            / 2.5 */
#define	   L3CLK_30		  0x02000000 /*            / 3   */
#define	   L3CLK_35		  0x02800000 /*            / 3.5 */
#define	   L3CLK_40		  0x03000000 /*            / 4   */
#define	   L3CLK_50		  0x03800000 /*            / 5   */
#define	  L3CR_L3IO		  0x00400000 /* 9: L3 instruction-only mode */
#define	  L3CR_L3SPO		  0x00040000 /* 13: L3 sample point override */
#define	  L3CR_L3CKSP		  0x00030000 /* 14-15: L3 clock sample point */
#define	   L3CKSP_2		  0x00000000 /* 2 clocks */
#define	   L3CKSP_3		  0x00010000 /* 3 clocks */
#define	   L3CKSP_4		  0x00020000 /* 4 clocks */
#define	   L3CKSP_5		  0x00030000 /* 5 clocks */
#define	  L3CR_L3PSP		  0x0000e000 /* 16-18: L3 P-clock sample point */
#define	   L3PSP_0		  0x00000000 /* 0 clocks */
#define	   L3PSP_1		  0x00002000 /* 1 clocks */
#define	   L3PSP_2		  0x00004000 /* 2 clocks */
#define	   L3PSP_3		  0x00006000 /* 3 clocks */
#define	   L3PSP_4		  0x00008000 /* 4 clocks */
#define	   L3PSP_5		  0x0000a000 /* 5 clocks */
#define	  L3CR_L3REP		  0x00001000 /* 19: L3 replacement algorithm (0=default, 1=alternate) */
#define	  L3CR_L3HWF		  0x00000800 /* 20: L3 hardware flush */
#define	  L3CR_L3I		  0x00000400 /* 21: L3 global invalidate */
#define	  L3CR_L3RT		  0x00000300 /* 22-23: L3 SRAM type */
#define	   L3RT_MSUG2_DDR	  0x00000000 /* MSUG2 DDR SRAM */
#define	   L3RT_PIPELINE_LATE	  0x00000100 /* Pipelined (register-register) synchronous late-write SRAM */
#define	   L3RT_PB2_SRAM	  0x00000300 /* PB2 SRAM */
#define	  L3CR_L3NIRCA		  0x00000080 /* 24: L3 non-integer ratios clock adjustment for the SRAM */
#define	  L3CR_L3DO		  0x00000040 /* 25: L3 data-only mode */
#define	  L3CR_PMEN		  0x00000004 /* 29: Private memory enable */
#define	  L3CR_PMSIZ		  0x00000004 /* 31: Private memory size (0=1MB, 1=2MB) */
#define SPR_ICTC		0x3fb	/* ..6. instruction cache throttling */
#define  ICTC_ENABLE		  0x00000001 /* enable throttling */
#define  ICTC_COUNT_M		  0x000001fe /* number of waits to insert */
#define	SPR_THRM1		0x3fc	/* ..6. Thermal Management Register */
#define	SPR_THRM2		0x3fd	/* ..6. Thermal Management Register */
#define	 SPR_THRM_TIN		  0x80000000 /* Thermal interrupt bit (RO) */
#define	 SPR_THRM_TIV		  0x40000000 /* Thermal interrupt valid (RO) */
#define	 SPR_THRM_THRESHOLD(x)	  ((x) << 23) /* Thermal sensor threshold */
#define	 SPR_THRM_TID		  0x00000004 /* Thermal interrupt direction */
#define	 SPR_THRM_TIE		  0x00000002 /* Thermal interrupt enable */
#define	 SPR_THRM_VALID		  0x00000001 /* Valid bit */
#define	SPR_THRM3		0x3fe	/* ..6. Thermal Management Register */
#define	 SPR_THRM_TIMER(x)	  ((x) << 1) /* Sampling interval timer */
#define	 SPR_THRM_ENABLE       	  0x00000001 /* TAU Enable */
#define	SPR_FPECR		0x3fe	/* ..6. Floating-Point Exception Cause Register */
#define	SPR_PIR			0x3ff	/* ..6. Processor Identification Register */

/* Performance counter declarations */
#define	PMC_OVERFLOW	  	0x80000000 /* Counter has overflowed */

/* The first five countable [non-]events are common to all the PMC's */
#define	PMCN_NONE		 0 /* Count nothing */
#define	PMCN_CYCLES		 1 /* Processor cycles */
#define	PMCN_ICOMP		 2 /* Instructions completed */
#define	PMCN_TBLTRANS		 3 /* TBL bit transitions */
#define	PCMN_IDISPATCH		 4 /* Instructions dispatched */

#if !defined(_LOCORE) && defined(_KERNEL)

#if defined(PPC_OEA64_BRIDGE) || defined (_ARCH_PPC64)

static inline uint64_t
scom_read(register_t address)
{
	register_t msr;
	uint64_t ret;

	msr = mfmsr();
	mtmsr(msr & ~PSL_EE);
	__asm volatile("isync;");

	mtspr(SPR_SCOMC, address | SCOMC_READ);
	__asm volatile("isync;");

	ret = mfspr(SPR_SCOMD);
	mtmsr(msr);
	__asm volatile("isync;");

	return ret;
}

static inline void
scom_write(register_t address, uint64_t data)
{
	register_t msr;

	msr = mfmsr();
	mtmsr(msr & ~PSL_EE);
	__asm volatile("isync;");

	mtspr(SPR_SCOMD, data);
	__asm volatile("isync;");
	mtspr(SPR_SCOMC, address | SCOMC_WRITE);
	__asm volatile("isync;");
	
	mtmsr(msr);
	__asm volatile("isync;");
}

#endif /* defined(PPC_OEA64_BRIDGE) || defined (_ARCH_PPC64) */

#endif /* !defined(_LOCORE) && defined(_KERNEL) */

#endif /* !_POWERPC_SPR_H_ */