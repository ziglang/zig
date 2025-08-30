/* $NetBSD: armreg.h,v 1.63 2022/12/01 00:32:52 ryo Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _AARCH64_ARMREG_H_
#define _AARCH64_ARMREG_H_

#include <arm/cputypes.h>
#include <sys/types.h>

#ifdef __clang__
#define ATTR_ARCH(arch)			".arch " arch ";"
#define ATTR_TARGET_ARCH(x)
#define ASM_ARCH(x)			x
#else
#define ATTR_ARCH(arch)			__attribute__((target("arch=" arch)))
#define ATTR_TARGET_ARCH(x)		x
#define ASM_ARCH(x)
#endif

#define AARCH64REG_READ_INLINE3(regname, regdesc, arch)		\
static __inline uint64_t ATTR_TARGET_ARCH(arch)			\
reg_##regname##_read(void)					\
{								\
	uint64_t __rv;						\
	__asm __volatile(					\
	    ASM_ARCH(arch)					\
	    "mrs %0, " #regdesc : "=r"(__rv)			\
	);							\
	return __rv;						\
}

#define AARCH64REG_READ_INLINE2(regname, regdesc)		\
	AARCH64REG_READ_INLINE3(regname, regdesc, )

#define AARCH64REG_WRITE_INLINE3(regname, regdesc, arch)	\
static __inline void ATTR_TARGET_ARCH(arch)			\
reg_##regname##_write(uint64_t __val)				\
{								\
	__asm __volatile(					\
	    ASM_ARCH(arch)					\
	    "msr " #regdesc ", %0" :: "r"(__val) : "memory"	\
	);							\
}

#define AARCH64REG_WRITE_INLINE2(regname, regdesc)		\
	AARCH64REG_WRITE_INLINE3(regname, regdesc, )

#define AARCH64REG_WRITEIMM_INLINE2(regname, regdesc)		\
static __inline void __always_inline				\
reg_##regname##_write(const uint64_t __val)			\
{								\
	__asm __volatile(					\
	    "msr " #regdesc ", %0" :: "n"(__val) : "memory"	\
	);							\
}

#define AARCH64REG_READ_INLINE(regname)				\
	AARCH64REG_READ_INLINE2(regname, regname)

#define AARCH64REG_WRITE_INLINE(regname)			\
	AARCH64REG_WRITE_INLINE2(regname, regname)

#define AARCH64REG_WRITEIMM_INLINE(regname)			\
	AARCH64REG_WRITEIMM_INLINE2(regname, regname)

#define AARCH64REG_READWRITE_INLINE2(regname, regdesc)		\
	AARCH64REG_READ_INLINE2(regname, regdesc)		\
	AARCH64REG_WRITE_INLINE2(regname, regdesc)

#define AARCH64REG_ATWRITE_INLINE2(regname, regdesc)		\
static __inline void						\
reg_##regname##_write(uint64_t __val)				\
{								\
	__asm __volatile(					\
	    "at " #regdesc ", %0" :: "r"(__val) : "memory"	\
	);							\
}

#define AARCH64REG_ATWRITE_INLINE(regname)			\
	AARCH64REG_ATWRITE_INLINE2(regname, regname)

/*
 * System registers available at EL0 (user)
 */
AARCH64REG_READ_INLINE(ctr_el0)		// Cache Type Register

#define	CTR_EL0_TMIN_LINE	__BITS(37,32)	// Tag MIN LINE size
#define	CTR_EL0_DIC		__BIT(29)	// Instruction cache requirement
#define	CTR_EL0_IDC		__BIT(28)	// Data Cache clean requirement
#define	CTR_EL0_CWG_LINE	__BITS(27,24)	// Cacheback Writeback Granule
#define	CTR_EL0_ERG_LINE	__BITS(23,20)	// Exclusives Reservation Granule
#define	CTR_EL0_DMIN_LINE	__BITS(19,16)	// Dcache MIN LINE size (log2 - 2)
#define	CTR_EL0_L1IP_MASK	__BITS(15,14)
#define	 CTR_EL0_L1IP_VPIPT	0		//  VMID-aware Physical Index, Physical Tag
#define	 CTR_EL0_L1IP_AIVIVT	1		//  ASID-tagged Virtual Index, Virtual Tag
#define	 CTR_EL0_L1IP_VIPT	2		//  Virtual Index, Physical Tag
#define	 CTR_EL0_L1IP_PIPT	3		//  Physical Index, Physical Tag
#define	CTR_EL0_IMIN_LINE	__BITS(3,0)	// Icache MIN LINE size (log2 - 2)

AARCH64REG_READ_INLINE(dczid_el0)	// Data Cache Zero ID Register

#define	DCZID_DZP		__BIT(4)	// Data Zero Prohibited
#define	DCZID_BS		__BITS(3,0)	// Block Size (log2 - 2)

AARCH64REG_READ_INLINE(fpcr)		// Floating Point Control Register
AARCH64REG_WRITE_INLINE(fpcr)

#define	FPCR_AHP		__BIT(26)	// Alternative Half Precision
#define	FPCR_DN			__BIT(25)	// Default Nan Control
#define	FPCR_FZ			__BIT(24)	// Flush-To-Zero
#define	FPCR_RMODE		__BITS(23,22)	// Rounding Mode
#define	 FPCR_RN		0		//  Round Nearest
#define	 FPCR_RP		1		//  Round towards Plus infinity
#define	 FPCR_RM		2		//  Round towards Minus infinity
#define	 FPCR_RZ		3		//  Round towards Zero
#define	FPCR_STRIDE		__BITS(21,20)
#define	FPCR_FZ16		__BIT(19)	// Flush-To-Zero for FP16
#define	FPCR_LEN		__BITS(18,16)
#define	FPCR_IDE		__BIT(15)	// Input Denormal Exception enable
#define	FPCR_IXE		__BIT(12)	// IneXact Exception enable
#define	FPCR_UFE		__BIT(11)	// UnderFlow Exception enable
#define	FPCR_OFE		__BIT(10)	// OverFlow Exception enable
#define	FPCR_DZE		__BIT(9)	// Divide by Zero Exception enable
#define	FPCR_IOE		__BIT(8)	// Invalid Operation Exception enable
#define	FPCR_ESUM		0x1F00

AARCH64REG_READ_INLINE(fpsr)		// Floating Point Status Register
AARCH64REG_WRITE_INLINE(fpsr)

#define	FPSR_N32		__BIT(31)	// AARCH32 Negative
#define	FPSR_Z32		__BIT(30)	// AARCH32 Zero
#define	FPSR_C32		__BIT(29)	// AARCH32 Carry
#define	FPSR_V32		__BIT(28)	// AARCH32 Overflow
#define	FPSR_QC			__BIT(27)	// SIMD Saturation
#define	FPSR_IDC		__BIT(7)	// Input Denormal Cumulative status
#define	FPSR_IXC		__BIT(4)	// IneXact Cumulative status
#define	FPSR_UFC		__BIT(3)	// UnderFlow Cumulative status
#define	FPSR_OFC		__BIT(2)	// OverFlow Cumulative status
#define	FPSR_DZC		__BIT(1)	// Divide by Zero Cumulative status
#define	FPSR_IOC		__BIT(0)	// Invalid Operation Cumulative status
#define	FPSR_CSUM		0x1F

AARCH64REG_READ_INLINE(nzcv)		// condition codes
AARCH64REG_WRITE_INLINE(nzcv)

#define	NZCV_N			__BIT(31)	// Negative
#define	NZCV_Z			__BIT(30)	// Zero
#define	NZCV_C			__BIT(29)	// Carry
#define	NZCV_V			__BIT(28)	// Overflow

AARCH64REG_READ_INLINE(tpidr_el0)	// Thread Pointer ID Register (RW)
AARCH64REG_WRITE_INLINE(tpidr_el0)

AARCH64REG_READ_INLINE(tpidrro_el0)	// Thread Pointer ID Register (RO)

/*
 * From here on, these can only be accessed at EL1 (kernel)
 */

/*
 * These are readonly registers
 */
AARCH64REG_READ_INLINE(aidr_el1)

AARCH64REG_READ_INLINE2(cbar_el1, s3_1_c15_c3_0)	// Cortex-A57

#define	CBAR_PA			__BITS(47,18)

AARCH64REG_READ_INLINE(ccsidr_el1)

/* 32bit format CCSIDR_EL1 */
#define	CCSIDR_WT		__BIT(31)	// OBSOLETE: Write-through supported
#define	CCSIDR_WB		__BIT(30)	// OBSOLETE: Write-back supported
#define	CCSIDR_RA		__BIT(29)	// OBSOLETE: Read-allocation supported
#define	CCSIDR_WA		__BIT(28)	// OBSOLETE: Write-allocation supported
#define	CCSIDR_NUMSET		__BITS(27,13)	// (Number of sets in cache) - 1
#define	CCSIDR_ASSOC		__BITS(12,3)	// (Associativity of cache) - 1
#define	CCSIDR_LINESIZE 	__BITS(2,0)	// Number of bytes in cache line

/* 64bit format CCSIDR_EL1 (ARMv8.3-CCIDX is implemented) */
#define	CCSIDR64_NUMSET		__BITS(55,32)	// (Number of sets in cache) - 1
#define	CCSIDR64_ASSOC		__BITS(23,3)	// (Associativity of cache) - 1
#define	CCSIDR64_LINESIZE 	__BITS(2,0)	// Number of bytes in cache line

AARCH64REG_READ_INLINE(clidr_el1)

#define	CLIDR_ICB		__BITS(32,30)	// Inner cache boundary
#define	CLIDR_LOUU		__BITS(29,27)	// Level of Unification Uniprocessor
#define	CLIDR_LOC		__BITS(26,24)	// Level of Coherency
#define	CLIDR_LOUIS		__BITS(23,21)	// Level of Unification InnerShareable*/
#define	CLIDR_CTYPE7		__BITS(20,18)	// Cache Type field for level7
#define	CLIDR_CTYPE6		__BITS(17,15)	// Cache Type field for level6
#define	CLIDR_CTYPE5		__BITS(14,12)	// Cache Type field for level5
#define	CLIDR_CTYPE4		__BITS(11,9)	// Cache Type field for level4
#define	CLIDR_CTYPE3		__BITS(8,6)	// Cache Type field for level3
#define	CLIDR_CTYPE2		__BITS(5,3)	// Cache Type field for level2
#define	CLIDR_CTYPE1		__BITS(2,0)	// Cache Type field for level1
#define	 CLIDR_TYPE_NOCACHE	 0		//  No cache
#define	 CLIDR_TYPE_ICACHE	 1		//  Instruction cache only
#define	 CLIDR_TYPE_DCACHE	 2		//  Data cache only
#define	 CLIDR_TYPE_IDCACHE	 3		//  Separate inst and data caches
#define	 CLIDR_TYPE_UNIFIEDCACHE 4		//  Unified cache

AARCH64REG_READ_INLINE(currentel)
AARCH64REG_READ_INLINE(id_aa64afr0_el1)
AARCH64REG_READ_INLINE(id_aa64afr1_el1)
AARCH64REG_READ_INLINE(id_aa64dfr0_el1)

#define	ID_AA64DFR0_EL1_TRACEFILT	__BITS(43,40)
#define	 ID_AA64DFR0_EL1_TRACEFILT_NONE	 0
#define	 ID_AA64DFR0_EL1_TRACEFILT_IMPL	 1
#define	ID_AA64DFR0_EL1_DBLLOCK		__BITS(39,36)
#define	 ID_AA64DFR0_EL1_DBLLOCK_IMPL	 0
#define	 ID_AA64DFR0_EL1_DBLLOCK_NONE	 15
#define	ID_AA64DFR0_EL1_PMSVER		__BITS(35,32)
#define	ID_AA64DFR0_EL1_CTX_CMPS	__BITS(31,28)
#define	ID_AA64DFR0_EL1_WRPS		__BITS(20,23)
#define	ID_AA64DFR0_EL1_BRPS		__BITS(12,15)
#define	ID_AA64DFR0_EL1_PMUVER		__BITS(8,11)
#define	 ID_AA64DFR0_EL1_PMUVER_NONE	 0
#define	 ID_AA64DFR0_EL1_PMUVER_V3	 1
#define	 ID_AA64DFR0_EL1_PMUVER_NOV3	 2
#define	 ID_AA64DFR0_EL1_PMUVER_V3P1	 4
#define	 ID_AA64DFR0_EL1_PMUVER_V3P4	 5
#define	 ID_AA64DFR0_EL1_PMUVER_V3P5	 6
#define	 ID_AA64DFR0_EL1_PMUVER_V3P7	 7
#define	 ID_AA64DFR0_EL1_PMUVER_IMPL	 15
#define	ID_AA64DFR0_EL1_TRACEVER	__BITS(4,7)
#define	 ID_AA64DFR0_EL1_TRACEVER_NONE	 0
#define	 ID_AA64DFR0_EL1_TRACEVER_IMPL	 1
#define	ID_AA64DFR0_EL1_DEBUGVER	__BITS(0,3)
#define	 ID_AA64DFR0_EL1_DEBUGVER_V8A	 6

AARCH64REG_READ_INLINE(id_aa64dfr1_el1)

AARCH64REG_READ_INLINE(id_aa64isar0_el1)

#define	ID_AA64ISAR0_EL1_RNDR		__BITS(63,60)
#define	 ID_AA64ISAR0_EL1_RNDR_NONE	 0
#define	 ID_AA64ISAR0_EL1_RNDR_RNDRRS	 1
#define	ID_AA64ISAR0_EL1_TLB		__BITS(59,56)
#define	 ID_AA64ISAR0_EL1_TLB_NONE	 0
#define	 ID_AA64ISAR0_EL1_TLB_OS	 1
#define	 ID_AA64ISAR0_EL1_TLB_OS_TLB	 2
#define	ID_AA64ISAR0_EL1_TS		__BITS(55,52)
#define	 ID_AA64ISAR0_EL1_TS_NONE	 0
#define	 ID_AA64ISAR0_EL1_TS_CFINV	 1
#define	 ID_AA64ISAR0_EL1_TS_AXFLAG	 2
#define	ID_AA64ISAR0_EL1_FHM		__BITS(51,48)
#define	 ID_AA64ISAR0_EL1_FHM_NONE	 0
#define	 ID_AA64ISAR0_EL1_FHM_FMLAL	 1
#define	ID_AA64ISAR0_EL1_DP		__BITS(47,44)
#define	 ID_AA64ISAR0_EL1_DP_NONE	 0
#define	 ID_AA64ISAR0_EL1_DP_UDOT	 1
#define	ID_AA64ISAR0_EL1_SM4		__BITS(43,40)
#define	 ID_AA64ISAR0_EL1_SM4_NONE	 0
#define	 ID_AA64ISAR0_EL1_SM4_SM4	 1
#define	ID_AA64ISAR0_EL1_SM3		__BITS(39,36)
#define	 ID_AA64ISAR0_EL1_SM3_NONE	 0
#define	 ID_AA64ISAR0_EL1_SM3_SM3	 1
#define	ID_AA64ISAR0_EL1_SHA3		__BITS(35,32)
#define	 ID_AA64ISAR0_EL1_SHA3_NONE	 0
#define	 ID_AA64ISAR0_EL1_SHA3_EOR3	 1
#define	ID_AA64ISAR0_EL1_RDM		__BITS(31,28)
#define	 ID_AA64ISAR0_EL1_RDM_NONE	 0
#define	 ID_AA64ISAR0_EL1_RDM_SQRDML	 1
#define	ID_AA64ISAR0_EL1_ATOMIC		__BITS(23,20)
#define	 ID_AA64ISAR0_EL1_ATOMIC_NONE	 0
#define	 ID_AA64ISAR0_EL1_ATOMIC_SWP	 2
#define	ID_AA64ISAR0_EL1_CRC32		__BITS(19,16)
#define	 ID_AA64ISAR0_EL1_CRC32_NONE	 0
#define	 ID_AA64ISAR0_EL1_CRC32_CRC32X	 1
#define	ID_AA64ISAR0_EL1_SHA2		__BITS(15,12)
#define	 ID_AA64ISAR0_EL1_SHA2_NONE	 0
#define	 ID_AA64ISAR0_EL1_SHA2_SHA256HSU 1
#define	 ID_AA64ISAR0_EL1_SHA2_SHA512HSU 2
#define	ID_AA64ISAR0_EL1_SHA1		__BITS(11,8)
#define	 ID_AA64ISAR0_EL1_SHA1_NONE	 0
#define	 ID_AA64ISAR0_EL1_SHA1_SHA1CPMHSU 1
#define	ID_AA64ISAR0_EL1_AES		__BITS(7,4)
#define	 ID_AA64ISAR0_EL1_AES_NONE	 0
#define	 ID_AA64ISAR0_EL1_AES_AES	 1
#define	 ID_AA64ISAR0_EL1_AES_PMUL	 2

AARCH64REG_READ_INLINE(id_aa64isar1_el1)

#define	ID_AA64ISAR1_EL1_I8MM		__BITS(55,52)
#define	 ID_AA64ISAR1_EL1_I8MM_NONE	 0
#define	 ID_AA64ISAR1_EL1_I8MM_SUPPORTED 1
#define	ID_AA64ISAR1_EL1_DGH		__BITS(51,48)
#define	 ID_AA64ISAR1_EL1_DGH_NONE	 0
#define	 ID_AA64ISAR1_EL1_DGH_SUPPORTED	 1
#define	ID_AA64ISAR1_EL1_BF16		__BITS(47,44)
#define	 ID_AA64ISAR1_EL1_BF16_NONE	 0
#define	 ID_AA64ISAR1_EL1_BF16_BFDOT	 1
#define	ID_AA64ISAR1_EL1_SPECRES	__BITS(43,40)
#define	 ID_AA64ISAR1_EL1_SPECRES_NONE	 0
#define	 ID_AA64ISAR1_EL1_SPECRES_SUPPORTED 1
#define	ID_AA64ISAR1_EL1_SB		__BITS(39,36)
#define	 ID_AA64ISAR1_EL1_SB_NONE	 0
#define	 ID_AA64ISAR1_EL1_SB_SUPPORTED	 1
#define	ID_AA64ISAR1_EL1_FRINTTS	__BITS(35,32)
#define	 ID_AA64ISAR1_EL1_FRINTTS_NONE	 0
#define	 ID_AA64ISAR1_EL1_FRINTTS_SUPPORTED 1
#define	ID_AA64ISAR1_EL1_GPI		__BITS(31,28)
#define	 ID_AA64ISAR1_EL1_GPI_NONE	 0
#define	 ID_AA64ISAR1_EL1_GPI_SUPPORTED	 1
#define	ID_AA64ISAR1_EL1_GPA		__BITS(27,24)
#define	 ID_AA64ISAR1_EL1_GPA_NONE	 0
#define	 ID_AA64ISAR1_EL1_GPA_QARMA	 1
#define	ID_AA64ISAR1_EL1_LRCPC		__BITS(23,20)
#define	 ID_AA64ISAR1_EL1_LRCPC_NONE	 0
#define	 ID_AA64ISAR1_EL1_LRCPC_PR	 1
#define	 ID_AA64ISAR1_EL1_LRCPC_PR_UR	 2
#define	ID_AA64ISAR1_EL1_FCMA		__BITS(19,16)
#define	 ID_AA64ISAR1_EL1_FCMA_NONE	 0
#define	 ID_AA64ISAR1_EL1_FCMA_SUPPORTED 1
#define	ID_AA64ISAR1_EL1_JSCVT		__BITS(15,12)
#define	 ID_AA64ISAR1_EL1_JSCVT_NONE	 0
#define	 ID_AA64ISAR1_EL1_JSCVT_SUPPORTED 1
#define	ID_AA64ISAR1_EL1_API		__BITS(11,8)
#define	 ID_AA64ISAR1_EL1_API_NONE	 0
#define	 ID_AA64ISAR1_EL1_API_SUPPORTED	 1
#define	 ID_AA64ISAR1_EL1_API_ENHANCED	 2
#define	ID_AA64ISAR1_EL1_APA		__BITS(7,4)
#define	 ID_AA64ISAR1_EL1_APA_NONE	 0
#define	 ID_AA64ISAR1_EL1_APA_QARMA	 1
#define	 ID_AA64ISAR1_EL1_APA_QARMA_ENH	 2
#define	ID_AA64ISAR1_EL1_DPB		__BITS(3,0)
#define	 ID_AA64ISAR1_EL1_DPB_NONE	 0
#define	 ID_AA64ISAR1_EL1_DPB_CVAP	 1
#define	 ID_AA64ISAR1_EL1_DPB_CVAP_CVADP 2

AARCH64REG_READ_INLINE(id_aa64mmfr0_el1)

#define	ID_AA64MMFR0_EL1_EXS		__BITS(43,40)
#define	ID_AA64MMFR0_EL1_TGRAN4		__BITS(31,28)
#define	 ID_AA64MMFR0_EL1_TGRAN4_4KB	 0
#define	 ID_AA64MMFR0_EL1_TGRAN4_NONE	 15
#define	ID_AA64MMFR0_EL1_TGRAN64	__BITS(24,27)
#define	 ID_AA64MMFR0_EL1_TGRAN64_64KB	 0
#define	 ID_AA64MMFR0_EL1_TGRAN64_NONE	 15
#define	ID_AA64MMFR0_EL1_TGRAN16	__BITS(20,23)
#define	 ID_AA64MMFR0_EL1_TGRAN16_NONE	 0
#define	 ID_AA64MMFR0_EL1_TGRAN16_16KB	 1
#define	ID_AA64MMFR0_EL1_BIGENDEL0	__BITS(16,19)
#define	 ID_AA64MMFR0_EL1_BIGENDEL0_NONE 0
#define	 ID_AA64MMFR0_EL1_BIGENDEL0_MIX	 1
#define	ID_AA64MMFR0_EL1_SNSMEM		__BITS(12,15)
#define	 ID_AA64MMFR0_EL1_SNSMEM_NONE	 0
#define	 ID_AA64MMFR0_EL1_SNSMEM_SNSMEM	 1
#define	ID_AA64MMFR0_EL1_BIGEND		__BITS(8,11)
#define	 ID_AA64MMFR0_EL1_BIGEND_NONE	 0
#define	 ID_AA64MMFR0_EL1_BIGEND_MIX	 1
#define	ID_AA64MMFR0_EL1_ASIDBITS	__BITS(4,7)
#define	 ID_AA64MMFR0_EL1_ASIDBITS_8BIT	 0
#define	 ID_AA64MMFR0_EL1_ASIDBITS_16BIT 2
#define	ID_AA64MMFR0_EL1_PARANGE	__BITS(0,3)
#define	 ID_AA64MMFR0_EL1_PARANGE_4G	 0
#define	 ID_AA64MMFR0_EL1_PARANGE_64G	 1
#define	 ID_AA64MMFR0_EL1_PARANGE_1T	 2
#define	 ID_AA64MMFR0_EL1_PARANGE_4T	 3
#define	 ID_AA64MMFR0_EL1_PARANGE_16T	 4
#define	 ID_AA64MMFR0_EL1_PARANGE_256T	 5
#define	 ID_AA64MMFR0_EL1_PARANGE_4P	 6

AARCH64REG_READ_INLINE(id_aa64mmfr1_el1)

#define	ID_AA64MMFR1_EL1_XNX		__BITS(31,28)
#define	 ID_AA64MMFR1_EL1_XNX_NONE	 0
#define	 ID_AA64MMFR1_EL1_XNX_SUPPORTED	 1
#define	ID_AA64MMFR1_EL1_SPECSEI	__BITS(27,24)
#define	 ID_AA64MMFR1_EL1_SPECSEI_NONE	 0
#define	 ID_AA64MMFR1_EL1_SPECSEI_EXTINT 1
#define	ID_AA64MMFR1_EL1_PAN		__BITS(23,20)
#define	 ID_AA64MMFR1_EL1_PAN_NONE	 0
#define	 ID_AA64MMFR1_EL1_PAN_SUPPORTED	 1
#define	 ID_AA64MMFR1_EL1_PAN_S1E1	 2
#define	ID_AA64MMFR1_EL1_LO		__BITS(19,16)
#define	 ID_AA64MMFR1_EL1_LO_NONE	 0
#define	 ID_AA64MMFR1_EL1_LO_SUPPORTED	 1
#define	ID_AA64MMFR1_EL1_HPDS		__BITS(15,12)
#define	 ID_AA64MMFR1_EL1_HPDS_NONE	 0
#define	 ID_AA64MMFR1_EL1_HPDS_SUPPORTED 1
#define	 ID_AA64MMFR1_EL1_HPDS_EXTRA_PTD 2
#define	ID_AA64MMFR1_EL1_VH		__BITS(11,8)
#define	 ID_AA64MMFR1_EL1_VH_NONE	 0
#define	 ID_AA64MMFR1_EL1_VH_SUPPORTED	 1
#define	ID_AA64MMFR1_EL1_VMIDBITS	__BITS(7,4)
#define	 ID_AA64MMFR1_EL1_VMIDBITS_8BIT	 0
#define	 ID_AA64MMFR1_EL1_VMIDBITS_16BIT 2
#define	ID_AA64MMFR1_EL1_HAFDBS		__BITS(3,0)
#define	 ID_AA64MMFR1_EL1_HAFDBS_NONE	 0
#define	 ID_AA64MMFR1_EL1_HAFDBS_A	 1
#define	 ID_AA64MMFR1_EL1_HAFDBS_AD	 2

AARCH64REG_READ_INLINE3(id_aa64mmfr2_el1, id_aa64mmfr2_el1,
    ATTR_ARCH("armv8.2-a"))

#define	ID_AA64MMFR2_EL1_E0PD		__BITS(63,60)
#define	 ID_AA64MMFR2_EL1_E0PD_NONE	 0
#define	 ID_AA64MMFR2_EL1_E0PD_SUPPORTED 1
#define	ID_AA64MMFR2_EL1_EVT		__BITS(59,56)
#define	 ID_AA64MMFR2_EL1_EVT_NONE	 0
#define	 ID_AA64MMFR2_EL1_EVT_TO_TI	 1
#define	 ID_AA64MMFR2_EL1_EVT_TO_TI_TTL	 2
#define	ID_AA64MMFR2_EL1_BBM		__BITS(55,52)
#define	 ID_AA64MMFR2_EL1_BBM_L0	 0
#define	 ID_AA64MMFR2_EL1_BBM_L1	 1
#define	 ID_AA64MMFR2_EL1_BBM_L2	 2
#define	ID_AA64MMFR2_EL1_TTL		__BITS(51,48)
#define	 ID_AA64MMFR2_EL1_TTL_NONE	 0
#define	 ID_AA64MMFR2_EL1_TTL_SUPPORTED	 1
#define	ID_AA64MMFR2_EL1_FWB		__BITS(43,40)
#define	 ID_AA64MMFR2_EL1_FWB_NONE	 0
#define	 ID_AA64MMFR2_EL1_FWB_SUPPORTED	 1
#define	ID_AA64MMFR2_EL1_IDS		__BITS(39,36)
#define	 ID_AA64MMFR2_EL1_IDS_0X0	 0
#define	 ID_AA64MMFR2_EL1_IDS_0X18	 1
#define	ID_AA64MMFR2_EL1_AT		__BITS(35,32)
#define	 ID_AA64MMFR2_EL1_AT_NONE	 0
#define	 ID_AA64MMFR2_EL1_AT_16BIT	 1
#define	ID_AA64MMFR2_EL1_ST		__BITS(31,28)
#define	 ID_AA64MMFR2_EL1_ST_39		 0
#define	 ID_AA64MMFR2_EL1_ST_48		 1
#define	ID_AA64MMFR2_EL1_NV		__BITS(27,24)
#define	 ID_AA64MMFR2_EL1_NV_NONE	 0
#define	 ID_AA64MMFR2_EL1_NV_HCR	 1
#define	 ID_AA64MMFR2_EL1_NV_HCR_VNCR	 2
#define	ID_AA64MMFR2_EL1_CCIDX		__BITS(23,20)
#define	 ID_AA64MMFR2_EL1_CCIDX_32BIT	 0
#define	 ID_AA64MMFR2_EL1_CCIDX_64BIT	 1
#define	ID_AA64MMFR2_EL1_VARANGE	__BITS(19,16)
#define	 ID_AA64MMFR2_EL1_VARANGE_48BIT	 0
#define	 ID_AA64MMFR2_EL1_VARANGE_52BIT	 1
#define	ID_AA64MMFR2_EL1_IESB		__BITS(15,12)
#define	 ID_AA64MMFR2_EL1_IESB_NONE	 0
#define	 ID_AA64MMFR2_EL1_IESB_SUPPORTED 1
#define	ID_AA64MMFR2_EL1_LSM		__BITS(11,8)
#define	 ID_AA64MMFR2_EL1_LSM_NONE	 0
#define	 ID_AA64MMFR2_EL1_LSM_SUPPORTED	 1
#define	ID_AA64MMFR2_EL1_UAO		__BITS(7,4)
#define	 ID_AA64MMFR2_EL1_UAO_NONE	 0
#define	 ID_AA64MMFR2_EL1_UAO_SUPPORTED	 1
#define	ID_AA64MMFR2_EL1_CNP		__BITS(3,0)
#define	 ID_AA64MMFR2_EL1_CNP_NONE	 0
#define	 ID_AA64MMFR2_EL1_CNP_SUPPORTED	 1

AARCH64REG_READ_INLINE2(a72_cpuactlr_el1, s3_1_c15_c2_0)
AARCH64REG_READ_INLINE(id_aa64pfr0_el1)
AARCH64REG_READ_INLINE(id_aa64pfr1_el1)

#define	ID_AA64PFR1_EL1_RASFRAC		__BITS(15,12)
#define	 ID_AA64PFR1_EL1_RASFRAC_NORMAL	 0
#define	 ID_AA64PFR1_EL1_RASFRAC_EXTRA	 1
#define	ID_AA64PFR1_EL1_MTE		__BITS(11,8)
#define	 ID_AA64PFR1_EL1_MTE_NONE	 0
#define	 ID_AA64PFR1_EL1_MTE_PARTIAL	 1
#define	 ID_AA64PFR1_EL1_MTE_SUPPORTED	 2
#define	ID_AA64PFR1_EL1_SSBS		__BITS(7,4)
#define	 ID_AA64PFR1_EL1_SSBS_NONE	 0
#define	 ID_AA64PFR1_EL1_SSBS_SUPPORTED	 1
#define	 ID_AA64PFR1_EL1_SSBS_MSR_MRS	 2
#define	ID_AA64PFR1_EL1_BT		__BITS(3,0)
#define	 ID_AA64PFR1_EL1_BT_NONE	 0
#define	 ID_AA64PFR1_EL1_BT_SUPPORTED	 1

AARCH64REG_READ_INLINE(id_aa64zfr0_el1)
AARCH64REG_READ_INLINE(id_pfr1_el1)
AARCH64REG_READ_INLINE(isr_el1)
AARCH64REG_READ_INLINE(midr_el1)
AARCH64REG_READ_INLINE(mpidr_el1)

#define	MIDR_EL1_IMPL		__BITS(31,24)		// Implementor
#define	MIDR_EL1_VARIANT	__BITS(23,20)		// CPU Variant
#define	MIDR_EL1_ARCH		__BITS(19,16)		// Architecture
#define	MIDR_EL1_PARTNUM	__BITS(15,4)		// PartNum
#define	MIDR_EL1_REVISION	__BITS(3,0)		// Revision

#define	MPIDR_AFF3		__BITS(32,39)
#define	MPIDR_U	 		__BIT(30)		// 1 = Uni-Processor System
#define	MPIDR_MT		__BIT(24)		// 1 = SMT(AFF0 is logical)
#define	MPIDR_AFF2		__BITS(16,23)
#define	MPIDR_AFF1		__BITS(8,15)
#define	MPIDR_AFF0		__BITS(0,7)

AARCH64REG_READ_INLINE(mvfr0_el1)

#define	MVFR0_FPROUND		__BITS(31,28)
#define	 MVFR0_FPROUND_NEAREST	 0
#define	 MVFR0_FPROUND_ALL	 1
#define	MVFR0_FPSHVEC		__BITS(27,24)
#define	 MVFR0_FPSHVEC_NONE	 0
#define	 MVFR0_FPSHVEC_SHVEC	 1
#define	MVFR0_FPSQRT		__BITS(23,20)
#define	 MVFR0_FPSQRT_NONE	 0
#define	 MVFR0_FPSQRT_VSQRT	 1
#define	MVFR0_FPDIVIDE		__BITS(19,16)
#define	 MVFR0_FPDIVIDE_NONE	 0
#define	 MVFR0_FPDIVIDE_VDIV	 1
#define	MVFR0_FPTRAP		__BITS(15,12)
#define	 MVFR0_FPTRAP_NONE	 0
#define	 MVFR0_FPTRAP_TRAP	 1
#define	MVFR0_FPDP		__BITS(11,8)
#define	 MVFR0_FPDP_NONE	 0
#define	 MVFR0_FPDP_VFPV2	 1
#define	 MVFR0_FPDP_VFPV3	 2
#define	MVFR0_FPSP		__BITS(7,4)
#define	 MVFR0_FPSP_NONE	 0
#define	 MVFR0_FPSP_VFPV2	 1
#define	 MVFR0_FPSP_VFPV3	 2
#define	MVFR0_SIMDREG		__BITS(3,0)
#define	 MVFR0_SIMDREG_NONE	 0
#define	 MVFR0_SIMDREG_16x64	 1
#define	 MVFR0_SIMDREG_32x64	 2

AARCH64REG_READ_INLINE(mvfr1_el1)

#define	MVFR1_SIMDFMAC		__BITS(31,28)
#define	 MVFR1_SIMDFMAC_NONE	 0
#define	 MVFR1_SIMDFMAC_FMAC	 1
#define	MVFR1_FPHP		__BITS(27,24)
#define	 MVFR1_FPHP_NONE	 0
#define	 MVFR1_FPHP_HALF_SINGLE	 1
#define	 MVFR1_FPHP_HALF_DOUBLE	 2
#define	 MVFR1_FPHP_HALF_ARITH	 3
#define	MVFR1_SIMDHP		__BITS(23,20)
#define	 MVFR1_SIMDHP_NONE	 0
#define	 MVFR1_SIMDHP_HALF	 1
#define	 MVFR1_SIMDHP_HALF_ARITH 3
#define	MVFR1_SIMDSP		__BITS(19,16)
#define	 MVFR1_SIMDSP_NONE	 0
#define	 MVFR1_SIMDSP_SINGLE	 1
#define	MVFR1_SIMDINT		 __BITS(15,12)
#define	 MVFR1_SIMDINT_NONE	 0
#define	 MVFR1_SIMDINT_INTEGER	 1
#define	MVFR1_SIMDLS		__BITS(11,8)
#define	 MVFR1_SIMDLS_NONE	 0
#define	 MVFR1_SIMDLS_LOADSTORE	 1
#define	MVFR1_FPDNAN		__BITS(7,4)
#define	 MVFR1_FPDNAN_NONE	 0
#define	 MVFR1_FPDNAN_NAN	 1
#define	MVFR1_FPFTZ		__BITS(3,0)
#define	 MVFR1_FPFTZ_NONE	 0
#define	 MVFR1_FPFTZ_DENORMAL	 1

AARCH64REG_READ_INLINE(mvfr2_el1)

#define	MVFR2_FPMISC		__BITS(7,4)
#define	 MVFR2_FPMISC_NONE	 0
#define	 MVFR2_FPMISC_SEL	 1
#define	 MVFR2_FPMISC_DROUND	 2
#define	 MVFR2_FPMISC_ROUNDINT	 3
#define	 MVFR2_FPMISC_MAXMIN	 4
#define	MVFR2_SIMDMISC		__BITS(3,0)
#define	 MVFR2_SIMDMISC_NONE	 0
#define	 MVFR2_SIMDMISC_DROUND	 1
#define	 MVFR2_SIMDMISC_ROUNDINT 2
#define	 MVFR2_SIMDMISC_MAXMIN	 3

AARCH64REG_READ_INLINE(revidr_el1)

/*
 * These are read/write registers
 */
AARCH64REG_READ_INLINE3(APIAKeyLo_EL1, apiakeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APIAKeyLo_EL1, apiakeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_READ_INLINE3(APIAKeyHi_EL1, apiakeyhi_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APIAKeyHi_EL1, apiakeyhi_el1, ATTR_ARCH("armv8.3-a"))

AARCH64REG_READ_INLINE3(APIBKeyLo_EL1, apibkeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APIBKeyLo_EL1, apibkeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_READ_INLINE3(APIBKeyHi_EL1, apibkeyhi_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APIBKeyHi_EL1, apibkeyhi_el1, ATTR_ARCH("armv8.3-a"))

AARCH64REG_READ_INLINE3(APDAKeyLo_EL1, apdakeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APDAKeyLo_EL1, apdakeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_READ_INLINE3(APDAKeyHi_EL1, apdakeyhi_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APDAKeyHi_EL1, apdakeyhi_el1, ATTR_ARCH("armv8.3-a"))

AARCH64REG_READ_INLINE3(APDBKeyLo_EL1, apdbkeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APDBKeyLo_EL1, apdbkeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_READ_INLINE3(APDBKeyHi_EL1, apdbkeyhi_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APDBKeyHi_EL1, apdbkeyhi_el1, ATTR_ARCH("armv8.3-a"))

AARCH64REG_READ_INLINE3(APGAKeyLo_EL1, apgakeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APGAKeyLo_EL1, apgakeylo_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_READ_INLINE3(APGAKeyHi_EL1, apgakeyhi_el1, ATTR_ARCH("armv8.3-a"))
AARCH64REG_WRITE_INLINE3(APGAKeyHi_EL1, apgakeyhi_el1, ATTR_ARCH("armv8.3-a"))

AARCH64REG_READ_INLINE3(pan, pan, ATTR_ARCH("armv8.1-a"))
AARCH64REG_WRITE_INLINE3(pan, pan, ATTR_ARCH("armv8.1-a"))

AARCH64REG_READ_INLINE(cpacr_el1)	// Coprocessor Access Control Regiser
AARCH64REG_WRITE_INLINE(cpacr_el1)

#define	CPACR_TTA		__BIT(28)	 // System Register Access Traps
#define	CPACR_FPEN		__BITS(21,20)
#define  CPACR_FPEN_NONE	 __SHIFTIN(0, CPACR_FPEN)
#define	 CPACR_FPEN_EL1		 __SHIFTIN(1, CPACR_FPEN)
#define	 CPACR_FPEN_NONE_2	 __SHIFTIN(2, CPACR_FPEN)
#define	 CPACR_FPEN_ALL		 __SHIFTIN(3, CPACR_FPEN)

AARCH64REG_READ_INLINE(csselr_el1)	// Cache Size Selection Register
AARCH64REG_WRITE_INLINE(csselr_el1)

#define	CSSELR_LEVEL		__BITS(3,1)	// Cache level of required cache
#define	CSSELR_IND		__BIT(0)	// Instruction not Data bit

AARCH64REG_READ_INLINE(daif)		// Debug Async Irq Fiq mask register
AARCH64REG_WRITE_INLINE(daif)
AARCH64REG_WRITEIMM_INLINE(daifclr)
AARCH64REG_WRITEIMM_INLINE(daifset)

#define	DAIF_D			__BIT(9)	// Debug Exception Mask
#define	DAIF_A			__BIT(8)	// SError Abort Mask
#define	DAIF_I			__BIT(7)	// IRQ Mask
#define	DAIF_F			__BIT(6)	// FIQ Mask
#define	DAIF_SETCLR_SHIFT	6		// for daifset/daifclr #imm shift

AARCH64REG_READ_INLINE(elr_el1)		// Exception Link Register
AARCH64REG_WRITE_INLINE(elr_el1)

AARCH64REG_READ_INLINE(esr_el1)		// Exception Symdrone Register
AARCH64REG_WRITE_INLINE(esr_el1)

#define	ESR_EC			__BITS(31,26) // Exception Cause
#define	 ESR_EC_UNKNOWN		 0x00	// AXX: Unknown Reason
#define	 ESR_EC_WFX		 0x01	// AXX: WFI or WFE instruction execution
#define	 ESR_EC_CP15_RT		 0x03	// A32: MCR/MRC access to CP15 !EC=0
#define	 ESR_EC_CP15_RRT	 0x04	// A32: MCRR/MRRC access to CP15 !EC=0
#define	 ESR_EC_CP14_RT		 0x05	// A32: MCR/MRC access to CP14
#define	 ESR_EC_CP14_DT		 0x06	// A32: LDC/STC access to CP14
#define	 ESR_EC_FP_ACCESS	 0x07	// AXX: Access to SIMD/FP Registers
#define	 ESR_EC_FPID		 0x08	// A32: MCR/MRC access to CP10 !EC=7
#define	 ESR_EC_CP14_RRT	 0x0c	// A32: MRRC access to CP14
#define	 ESR_EC_BTE_A64		 0x0d	// A64: Branch Target Exception (V8.5)
#define	 ESR_EC_ILL_STATE	 0x0e	// AXX: Illegal Execution State
#define	 ESR_EC_SVC_A32		 0x11	// A32: SVC Instruction Execution
#define	 ESR_EC_HVC_A32		 0x12	// A32: HVC Instruction Execution
#define	 ESR_EC_SMC_A32		 0x13	// A32: SMC Instruction Execution
#define	 ESR_EC_SVC_A64		 0x15	// A64: SVC Instruction Execution
#define	 ESR_EC_HVC_A64		 0x16	// A64: HVC Instruction Execution
#define	 ESR_EC_SMC_A64		 0x17	// A64: SMC Instruction Execution
#define	 ESR_EC_SYS_REG		 0x18	// A64: MSR/MRS/SYS instruction (!EC0/1/7)
#define	 ESR_EC_INSN_ABT_EL0	 0x20	// AXX: Instruction Abort (EL0)
#define	 ESR_EC_INSN_ABT_EL1	 0x21	// AXX: Instruction Abort (EL1)
#define	 ESR_EC_PC_ALIGNMENT	 0x22	// AXX: Misaligned PC
#define	 ESR_EC_DATA_ABT_EL0	 0x24	// AXX: Data Abort (EL0)
#define	 ESR_EC_DATA_ABT_EL1	 0x25	// AXX: Data Abort (EL1)
#define	 ESR_EC_SP_ALIGNMENT 	 0x26	// AXX: Misaligned SP
#define	 ESR_EC_FP_TRAP_A32	 0x28	// A32: FP Exception
#define	 ESR_EC_FP_TRAP_A64	 0x2c	// A64: FP Exception
#define	 ESR_EC_SERROR	 	 0x2f	// AXX: SError Interrupt
#define	 ESR_EC_BRKPNT_EL0	 0x30	// AXX: Breakpoint Exception (EL0)
#define	 ESR_EC_BRKPNT_EL1	 0x31	// AXX: Breakpoint Exception (EL1)
#define	 ESR_EC_SW_STEP_EL0	 0x32	// AXX: Software Step (EL0)
#define	 ESR_EC_SW_STEP_EL1	 0x33	// AXX: Software Step (EL1)
#define	 ESR_EC_WTCHPNT_EL0	 0x34	// AXX: Watchpoint (EL0)
#define	 ESR_EC_WTCHPNT_EL1	 0x35	// AXX: Watchpoint (EL1)
#define	 ESR_EC_BKPT_INSN_A32	 0x38	// A32: BKPT Instruction Execution
#define	 ESR_EC_VECTOR_CATCH	 0x3a	// A32: Vector Catch Exception
#define	 ESR_EC_BKPT_INSN_A64	 0x3c	// A64: BKPT Instruction Execution
#define	ESR_IL			__BIT(25)	// Instruction Length (1=32-bit)
#define	ESR_ISS			__BITS(24,0)	// Instruction Specific Syndrome
#define	ESR_ISS_CV		__BIT(24)	// common
#define	ESR_ISS_COND		__BITS(23,20)	// common
#define	ESR_ISS_WFX_TRAP_INSN	__BIT(0)	// for ESR_EC_WFX
#define	ESR_ISS_MRC_OPC2	__BITS(19,17)	// for ESR_EC_CP15_RT
#define	ESR_ISS_MRC_OPC1	__BITS(16,14)	// for ESR_EC_CP15_RT
#define	ESR_ISS_MRC_CRN		__BITS(13,10)	// for ESR_EC_CP15_RT
#define	ESR_ISS_MRC_RT		__BITS(9,5)	// for ESR_EC_CP15_RT
#define	ESR_ISS_MRC_CRM		__BITS(4,1)	// for ESR_EC_CP15_RT
#define	ESR_ISS_MRC_DIRECTION	__BIT(0)	// for ESR_EC_CP15_RT
#define	ESR_ISS_MCRR_OPC1	__BITS(19,16)	// for ESR_EC_CP15_RRT
#define	ESR_ISS_MCRR_RT2	__BITS(14,10)	// for ESR_EC_CP15_RRT
#define	ESR_ISS_MCRR_RT		__BITS(9,5)	// for ESR_EC_CP15_RRT
#define	ESR_ISS_MCRR_CRM	__BITS(4,1)	// for ESR_EC_CP15_RRT
#define	ESR_ISS_MCRR_DIRECTION	__BIT(0)	// for ESR_EC_CP15_RRT
#define	ESR_ISS_HVC_IMM16	__BITS(15,0)	// for ESR_EC_{SVC,HVC}
// ...
#define	ESR_ISS_INSNABORT_EA	__BIT(9)	// for ESC_RC_INSN_ABT_EL[01]
#define	ESR_ISS_INSNABORT_S1PTW	__BIT(7)	// for ESC_RC_INSN_ABT_EL[01]
#define	ESR_ISS_INSNABORT_IFSC	__BITS(0,5)	// for ESC_RC_INSN_ABT_EL[01]
#define	ESR_ISS_DATAABORT_ISV	__BIT(24)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_SAS	__BITS(23,22)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_SSE	__BIT(21)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_SRT	__BITS(19,16)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_SF	__BIT(15)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_AR	__BIT(14)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_EA	__BIT(9)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_CM	__BIT(8)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_S1PTW	__BIT(7)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_WnR	__BIT(6)	// for ESC_RC_DATA_ABT_EL[01]
#define	ESR_ISS_DATAABORT_DFSC	__BITS(0,5)	// for ESC_RC_DATA_ABT_EL[01]

#define	ESR_ISS_FSC_ADDRESS_SIZE_FAULT_0		0x00
#define	ESR_ISS_FSC_ADDRESS_SIZE_FAULT_1		0x01
#define	ESR_ISS_FSC_ADDRESS_SIZE_FAULT_2		0x02
#define	ESR_ISS_FSC_ADDRESS_SIZE_FAULT_3		0x03
#define	ESR_ISS_FSC_TRANSLATION_FAULT_0			0x04
#define	ESR_ISS_FSC_TRANSLATION_FAULT_1			0x05
#define	ESR_ISS_FSC_TRANSLATION_FAULT_2			0x06
#define	ESR_ISS_FSC_TRANSLATION_FAULT_3			0x07
#define	ESR_ISS_FSC_ACCESS_FAULT_0			0x08
#define	ESR_ISS_FSC_ACCESS_FAULT_1			0x09
#define	ESR_ISS_FSC_ACCESS_FAULT_2			0x0a
#define	ESR_ISS_FSC_ACCESS_FAULT_3			0x0b
#define	ESR_ISS_FSC_PERM_FAULT_0			0x0c
#define	ESR_ISS_FSC_PERM_FAULT_1			0x0d
#define	ESR_ISS_FSC_PERM_FAULT_2			0x0e
#define	ESR_ISS_FSC_PERM_FAULT_3			0x0f
#define	ESR_ISS_FSC_SYNC_EXTERNAL_ABORT			0x10
#define	ESR_ISS_FSC_SYNC_EXTERNAL_ABORT_TTWALK_0	0x14
#define	ESR_ISS_FSC_SYNC_EXTERNAL_ABORT_TTWALK_1	0x15
#define	ESR_ISS_FSC_SYNC_EXTERNAL_ABORT_TTWALK_2	0x16
#define	ESR_ISS_FSC_SYNC_EXTERNAL_ABORT_TTWALK_3	0x17
#define	ESR_ISS_FSC_SYNC_PARITY_ERROR			0x18
#define	ESR_ISS_FSC_SYNC_PARITY_ERROR_ON_TTWALK_0	0x1c
#define	ESR_ISS_FSC_SYNC_PARITY_ERROR_ON_TTWALK_1	0x1d
#define	ESR_ISS_FSC_SYNC_PARITY_ERROR_ON_TTWALK_2	0x1e
#define	ESR_ISS_FSC_SYNC_PARITY_ERROR_ON_TTWALK_3	0x1f
#define	ESR_ISS_FSC_ALIGNMENT_FAULT			0x21
#define	ESR_ISS_FSC_TLB_CONFLICT_FAULT			0x30
#define	ESR_ISS_FSC_LOCKDOWN_ABORT			0x34
#define	ESR_ISS_FSC_UNSUPPORTED_EXCLUSIVE		0x35
#define	ESR_ISS_FSC_FIRST_LEVEL_DOMAIN_FAULT		0x3d
#define	ESR_ISS_FSC_SECOND_LEVEL_DOMAIN_FAULT		0x3e


AARCH64REG_READ_INLINE(far_el1)		// Fault Address Register
AARCH64REG_WRITE_INLINE(far_el1)

AARCH64REG_READ_INLINE2(l2ctlr_el1, s3_1_c11_c0_2)  // Cortex-A53,57,72,73
AARCH64REG_WRITE_INLINE2(l2ctlr_el1, s3_1_c11_c0_2) // Cortex-A53,57,72,73

#define	L2CTLR_NUMOFCORE	__BITS(25,24)	// Number of cores
#define	L2CTLR_CPUCACHEPROT	__BIT(22)	// CPU Cache Protection
#define	L2CTLR_SCUL2CACHEPROT	__BIT(21)	// SCU-L2 Cache Protection
#define	L2CTLR_L2_INPUT_LATENCY	__BIT(5)	// L2 Data RAM input latency
#define	L2CTLR_L2_OUTPUT_LATENCY __BIT(0)	// L2 Data RAM output latency

AARCH64REG_READ_INLINE(mair_el1) // Memory Attribute Indirection Register
AARCH64REG_WRITE_INLINE(mair_el1)

#define	MAIR_ATTR0		 __BITS(7,0)
#define	MAIR_ATTR1		 __BITS(15,8)
#define	MAIR_ATTR2		 __BITS(23,16)
#define	MAIR_ATTR3		 __BITS(31,24)
#define	MAIR_ATTR4		 __BITS(39,32)
#define	MAIR_ATTR5		 __BITS(47,40)
#define	MAIR_ATTR6		 __BITS(55,48)
#define	MAIR_ATTR7		 __BITS(63,56)
#define	MAIR_DEVICE_nGnRnE	 0x00	// NoGathering,NoReordering,NoEarlyWriteAck.
#define	MAIR_DEVICE_nGnRE	 0x04	// NoGathering,NoReordering,EarlyWriteAck.
#define	MAIR_NORMAL_NC		 0x44
#define	MAIR_NORMAL_WT		 0xbb
#define	MAIR_NORMAL_WB		 0xff

AARCH64REG_READ_INLINE(par_el1)		// Physical Address Register
AARCH64REG_WRITE_INLINE(par_el1)

#define	PAR_ATTR		__BITS(63,56)	// F=0 memory attributes
#define	PAR_PA			__BITS(51,12)	// F=0 physical address
#define	PAR_PA_SHIFT		12
#define	PAR_NS			__BIT(9)	// F=0 non-secure
#define	PAR_SH			__BITS(8,7)	// F=0 shareability attribute
#define	 PAR_SH_NONE		 0
#define	 PAR_SH_OUTER		 2
#define	 PAR_SH_INNER		 3

#define	PAR_S			__BIT(9)	// F=1 failure stage
#define	PAR_PTW			__BIT(8)	// F=1 partial table walk
#define	PAR_FST			__BITS(6,1)	// F=1 fault status code
#define	PAR_F			__BIT(0)	// translation failed

AARCH64REG_READ_INLINE(rmr_el1)		// Reset Management Register
AARCH64REG_WRITE_INLINE(rmr_el1)

AARCH64REG_READ_INLINE(rvbar_el1)	// Reset Vector Base Address Register
AARCH64REG_WRITE_INLINE(rvbar_el1)

AARCH64REG_ATWRITE_INLINE(s1e0r);	// Address Translate Stages 1
AARCH64REG_ATWRITE_INLINE(s1e0w);
AARCH64REG_ATWRITE_INLINE(s1e1r);
AARCH64REG_ATWRITE_INLINE(s1e1w);

AARCH64REG_READ_INLINE(sctlr_el1)	// System Control Register
AARCH64REG_WRITE_INLINE(sctlr_el1)

#define	SCTLR_RES0		0xc8222400	// Reserved ARMv8.0, write 0
#define	SCTLR_RES1		0x30d00800	// Reserved ARMv8.0, write 1
#define	SCTLR_M			__BIT(0)
#define	SCTLR_A			__BIT(1)
#define	SCTLR_C			__BIT(2)
#define	SCTLR_SA		__BIT(3)
#define	SCTLR_SA0		__BIT(4)
#define	SCTLR_CP15BEN		__BIT(5)
#define	SCTLR_nAA		__BIT(6)
#define	SCTLR_ITD		__BIT(7)
#define	SCTLR_SED		__BIT(8)
#define	SCTLR_UMA		__BIT(9)
#define	SCTLR_EnRCTX		__BIT(10)
#define	SCTLR_EOS		__BIT(11)
#define	SCTLR_I			__BIT(12)
#define	SCTLR_EnDB		__BIT(13)
#define	SCTLR_DZE		__BIT(14)
#define	SCTLR_UCT		__BIT(15)
#define	SCTLR_nTWI		__BIT(16)
#define	SCTLR_nTWE		__BIT(18)
#define	SCTLR_WXN		__BIT(19)
#define	SCTLR_TSCXT		__BIT(20)
#define	SCTLR_IESB		__BIT(21)
#define	SCTLR_EIS		__BIT(22)
#define	SCTLR_SPAN		__BIT(23)
#define	SCTLR_E0E		__BIT(24)
#define	SCTLR_EE		__BIT(25)
#define	SCTLR_UCI		__BIT(26)
#define	SCTLR_EnDA		__BIT(27)
#define	SCTLR_nTLSMD		__BIT(28)
#define	SCTLR_LSMAOE		__BIT(29)
#define	SCTLR_EnIB		__BIT(30)
#define	SCTLR_EnIA		__BIT(31)
#define	SCTLR_BT0		__BIT(35)
#define	SCTLR_BT1		__BIT(36)
#define	SCTLR_ITFSB		__BIT(37)
#define	SCTLR_TCF0		__BITS(39,38)
#define	SCTLR_TCF		__BITS(41,40)
#define	SCTLR_ATA0		__BIT(42)
#define	SCTLR_ATA		__BIT(43)
#define	SCTLR_DSSBS		__BIT(44)

// current EL stack pointer
static __inline uint64_t
reg_sp_read(void)
{
	uint64_t __rv;
	__asm __volatile ("mov %0, sp" : "=r"(__rv));
	return __rv;
}

AARCH64REG_READ_INLINE(sp_el0)		// EL0 Stack Pointer
AARCH64REG_WRITE_INLINE(sp_el0)

AARCH64REG_READ_INLINE(spsel)		// Stack Pointer Select
AARCH64REG_WRITE_INLINE(spsel)

#define	SPSEL_SP		__BIT(0);	// use SP_EL0 at all exception levels

AARCH64REG_READ_INLINE(spsr_el1)	// Saved Program Status Register
AARCH64REG_WRITE_INLINE(spsr_el1)

#define	SPSR_NZCV 		__BITS(31,28)	// mask of N Z C V
#define	 SPSR_N	 		__BIT(31)	// Negative
#define	 SPSR_Z	 		__BIT(30)	// Zero
#define	 SPSR_C	 		__BIT(29)	// Carry
#define	 SPSR_V	 		__BIT(28)	// oVerflow
#define	SPSR_A32_Q 		__BIT(27)	// A32: Overflow
#define	SPSR_A32_IT1 		__BIT(26)	// A32: IT[1]
#define	SPSR_A32_IT0 		__BIT(25)	// A32: IT[0]
#define	SPSR_PAN	 	__BIT(22)	// Privileged Access Never
#define	SPSR_SS	 		__BIT(21)	// Software Step
#define	SPSR_SS_SHIFT		21
#define	SPSR_IL	 		__BIT(20)	// Instruction Length
#define	SPSR_GE	 		__BITS(19,16)	// A32: SIMD GE
#define	SPSR_IT7 		__BIT(15)	// A32: IT[7]
#define	SPSR_IT6 		__BIT(14)	// A32: IT[6]
#define	SPSR_IT5 		__BIT(13)	// A32: IT[5]
#define	SPSR_IT4 		__BIT(12)	// A32: IT[4]
#define	SPSR_IT3 		__BIT(11)	// A32: IT[3]
#define	SPSR_IT2 		__BIT(10)	// A32: IT[2]
#define	SPSR_A64_BTYPE 		__BITS(11,10)	// A64: BTYPE
#define	SPSR_A64_D 		__BIT(9)	// A64: Debug Exception Mask
#define	SPSR_A32_E 		__BIT(9)	// A32: BE Endian Mode
#define	SPSR_A	 		__BIT(8)	// Async abort (SError) Mask
#define	SPSR_I	 		__BIT(7)	// IRQ Mask
#define	SPSR_F	 		__BIT(6)	// FIQ Mask
#define	SPSR_A32_T 		__BIT(5)	// A32 Thumb Mode
#define	SPSR_A32		__BIT(4)	// A32 Mode (a part of SPSR_M)
#define	SPSR_M	 		__BITS(4,0)	// Execution State
#define	 SPSR_M_EL3H 		 0x0d
#define	 SPSR_M_EL3T 		 0x0c
#define	 SPSR_M_EL2H 		 0x09
#define	 SPSR_M_EL2T 		 0x08
#define	 SPSR_M_EL1H 		 0x05
#define	 SPSR_M_EL1T 		 0x04
#define	 SPSR_M_EL0T 		 0x00
#define	 SPSR_M_SYS32		 0x1f
#define	 SPSR_M_UND32		 0x1b
#define	 SPSR_M_ABT32		 0x17
#define	 SPSR_M_SVC32		 0x13
#define	 SPSR_M_IRQ32		 0x12
#define	 SPSR_M_FIQ32		 0x11
#define	 SPSR_M_USR32		 0x10

AARCH64REG_READ_INLINE(tcr_el1)		// Translation Control Register
AARCH64REG_WRITE_INLINE(tcr_el1)


/* TCR_EL1 - Translation Control Register */
#define TCR_TCMA1		__BIT(58)		/* ARMv8.5-MemTag control when ADDR[59:55] = 0b11111 */
#define TCR_TCMA0		__BIT(57)		/* ARMv8.5-MemTag control when ADDR[59:55] = 0b00000 */
#define TCR_E0PD1		__BIT(56)		/* ARMv8.5-E0PD Faulting control for EL0 by TTBR1 */
#define TCR_E0PD0		__BIT(55)		/* ARMv8.5-E0PD Faulting control for EL0 by TTBR0 */
#define TCR_NFD1		__BIT(54)		/* SVE Non-fault translation table walk disable (TTBR1) */
#define TCR_NFD0		__BIT(53)		/* SVE Non-fault translation table walk disable (TTBR0) */
#define TCR_TBID1		__BIT(52)		/* ARMv8.3-PAuth TBI for instruction addr (TTBR1) */
#define TCR_TBID0		__BIT(51)		/* ARMv8.3-PAuth TBI for instruction addr (TTBR0) */
#define TCR_HWU162		__BIT(50)		/* ARMv8.1-TTPBHA bit[62] of PTE (TTBR1) */
#define TCR_HWU161		__BIT(49)		/* ARMv8.1-TTPBHA bit[61] of PTE (TTBR1) */
#define TCR_HWU160		__BIT(48)		/* ARMv8.1-TTPBHA bit[60] of PTE (TTBR1) */
#define TCR_HWU159		__BIT(47)		/* ARMv8.1-TTPBHA bit[59] of PTE (TTBR1) */
#define TCR_HWU062		__BIT(46)		/* ARMv8.1-TTPBHA bit[62] of PTE (TTBR0) */
#define TCR_HWU061		__BIT(45)		/* ARMv8.1-TTPBHA bit[61] of PTE (TTBR0) */
#define TCR_HWU060		__BIT(44)		/* ARMv8.1-TTPBHA bit[60] of PTE (TTBR0) */
#define TCR_HWU059		__BIT(43)		/* ARMv8.1-TTPBHA bit[59] of PTE (TTBR0) */
#define TCR_HPD1		__BIT(42)		/* ARMv8.1-HPD Hierarchical Permission (TTBR1) */
#define TCR_HPD0		__BIT(41)		/* ARMv8.1-HPD Hierarchical Permission (TTBR0) */
#define TCR_HD			__BIT(40)		/* ARMv8.1-TTHM Hardware Dirty flag */
#define TCR_HA			__BIT(39)		/* ARMv8.1-TTHM Hardware Access flag */
#define TCR_TBI1		__BIT(38)		/* ignore Top Byte TTBR1_EL1 */
#define TCR_TBI0		__BIT(37)		/* ignore Top Byte TTBR0_EL1 */
#define TCR_AS64K		__BIT(36)		/* Use 64K ASIDs */
#define TCR_IPS			__BITS(34,32)		/* Intermediate PhysAdr Size */
#define  TCR_IPS_4PB		__SHIFTIN(6,TCR_IPS)	/* 52 bits (  4 PB) */
#define  TCR_IPS_256TB		__SHIFTIN(5,TCR_IPS)	/* 48 bits (256 TB) */
#define  TCR_IPS_16TB		__SHIFTIN(4,TCR_IPS)	/* 44 bits  (16 TB) */
#define  TCR_IPS_4TB		__SHIFTIN(3,TCR_IPS)	/* 42 bits  ( 4 TB) */
#define  TCR_IPS_1TB		__SHIFTIN(2,TCR_IPS)	/* 40 bits  ( 1 TB) */
#define  TCR_IPS_64GB		__SHIFTIN(1,TCR_IPS)	/* 36 bits  (64 GB) */
#define  TCR_IPS_4GB		__SHIFTIN(0,TCR_IPS)	/* 32 bits   (4 GB) */
#define TCR_TG1			__BITS(31,30)		/* TTBR1 Page Granule Size */
#define  TCR_TG1_16KB		__SHIFTIN(1,TCR_TG1)	/* 16KB page size */
#define  TCR_TG1_4KB		__SHIFTIN(2,TCR_TG1)	/* 4KB page size */
#define  TCR_TG1_64KB		__SHIFTIN(3,TCR_TG1)	/* 64KB page size */
#define TCR_SH1			__BITS(29,28)
#define  TCR_SH1_NONE		__SHIFTIN(0,TCR_SH1)
#define  TCR_SH1_OUTER		__SHIFTIN(2,TCR_SH1)
#define  TCR_SH1_INNER		__SHIFTIN(3,TCR_SH1)
#define TCR_ORGN1		__BITS(27,26)		/* TTBR1 Outer cacheability */
#define  TCR_ORGN1_NC		__SHIFTIN(0,TCR_ORGN1)	/* Non Cacheable */
#define  TCR_ORGN1_WB_WA	__SHIFTIN(1,TCR_ORGN1)	/* WriteBack WriteAllocate */
#define  TCR_ORGN1_WT		__SHIFTIN(2,TCR_ORGN1)	/* WriteThrough */
#define  TCR_ORGN1_WB		__SHIFTIN(3,TCR_ORGN1)	/* WriteBack */
#define TCR_IRGN1		__BITS(25,24)		/* TTBR1 Inner cacheability */
#define  TCR_IRGN1_NC		__SHIFTIN(0,TCR_IRGN1)	/* Non Cacheable */
#define  TCR_IRGN1_WB_WA	__SHIFTIN(1,TCR_IRGN1)	/* WriteBack WriteAllocate */
#define  TCR_IRGN1_WT		__SHIFTIN(2,TCR_IRGN1)	/* WriteThrough */
#define  TCR_IRGN1_WB		__SHIFTIN(3,TCR_IRGN1)	/* WriteBack */
#define TCR_EPD1		__BIT(23)		/* Walk Disable for TTBR1_EL1 */
#define TCR_A1			__BIT(22)		/* ASID is in TTBR1_EL1 */
#define TCR_T1SZ		__BITS(21,16)		/* Size offset for TTBR1_EL1 */
#define TCR_TG0			__BITS(15,14)		/* TTBR0 Page Granule Size */
#define  TCR_TG0_4KB		__SHIFTIN(0,TCR_TG0)	/* 4KB page size */
#define  TCR_TG0_64KB		__SHIFTIN(1,TCR_TG0)	/* 64KB page size */
#define  TCR_TG0_16KB		__SHIFTIN(2,TCR_TG0)	/* 16KB page size */
#define TCR_SH0			__BITS(13,12)
#define  TCR_SH0_NONE		__SHIFTIN(0,TCR_SH0)
#define  TCR_SH0_OUTER		__SHIFTIN(2,TCR_SH0)
#define  TCR_SH0_INNER		__SHIFTIN(3,TCR_SH0)
#define TCR_ORGN0		__BITS(11,10)		/* TTBR0 Outer cacheability */
#define  TCR_ORGN0_NC		__SHIFTIN(0,TCR_ORGN0)	/* Non Cacheable */
#define  TCR_ORGN0_WB_WA	__SHIFTIN(1,TCR_ORGN0)	/* WriteBack WriteAllocate */
#define  TCR_ORGN0_WT		__SHIFTIN(2,TCR_ORGN0)	/* WriteThrough */
#define  TCR_ORGN0_WB		__SHIFTIN(3,TCR_ORGN0)	/* WriteBack */
#define TCR_IRGN0		__BITS(9,8)		/* TTBR0 Inner cacheability */
#define  TCR_IRGN0_NC		__SHIFTIN(0,TCR_IRGN0)	/* Non Cacheable */
#define  TCR_IRGN0_WB_WA	__SHIFTIN(1,TCR_IRGN0)	/* WriteBack WriteAllocate */
#define  TCR_IRGN0_WT		__SHIFTIN(2,TCR_IRGN0)	/* WriteThrough */
#define  TCR_IRGN0_WB		__SHIFTIN(3,TCR_IRGN0)	/* WriteBack */
#define TCR_EPD0		__BIT(7)		/* Walk Disable for TTBR0 */
#define TCR_T0SZ		__BITS(5,0)		/* Size offset for TTBR0_EL1 */

AARCH64REG_READ_INLINE(tpidr_el1)	// Thread ID Register (EL1)
AARCH64REG_WRITE_INLINE(tpidr_el1)

AARCH64REG_WRITE_INLINE(tpidrro_el0)	// Thread ID Register (RO for EL0)

AARCH64REG_READ_INLINE(ttbr0_el1) // Translation Table Base Register 0 EL1
AARCH64REG_WRITE_INLINE(ttbr0_el1)

AARCH64REG_READ_INLINE(ttbr1_el1) // Translation Table Base Register 1 EL1
AARCH64REG_WRITE_INLINE(ttbr1_el1)

#define TTBR_ASID		__BITS(63,48)
#define TTBR_BADDR		__BITS(47,0)

AARCH64REG_READ_INLINE(vbar_el1)	// Vector Base Address Register
AARCH64REG_WRITE_INLINE(vbar_el1)

/*
 * From here on, these are DEBUG registers
 */
AARCH64REG_READ_INLINE(dbgbcr0_el1) // Debug Breakpoint Control Register 0
AARCH64REG_WRITE_INLINE(dbgbcr0_el1)
AARCH64REG_READ_INLINE(dbgbcr1_el1) // Debug Breakpoint Control Register 1
AARCH64REG_WRITE_INLINE(dbgbcr1_el1)
AARCH64REG_READ_INLINE(dbgbcr2_el1) // Debug Breakpoint Control Register 2
AARCH64REG_WRITE_INLINE(dbgbcr2_el1)
AARCH64REG_READ_INLINE(dbgbcr3_el1) // Debug Breakpoint Control Register 3
AARCH64REG_WRITE_INLINE(dbgbcr3_el1)
AARCH64REG_READ_INLINE(dbgbcr4_el1) // Debug Breakpoint Control Register 4
AARCH64REG_WRITE_INLINE(dbgbcr4_el1)
AARCH64REG_READ_INLINE(dbgbcr5_el1) // Debug Breakpoint Control Register 5
AARCH64REG_WRITE_INLINE(dbgbcr5_el1)
AARCH64REG_READ_INLINE(dbgbcr6_el1) // Debug Breakpoint Control Register 6
AARCH64REG_WRITE_INLINE(dbgbcr6_el1)
AARCH64REG_READ_INLINE(dbgbcr7_el1) // Debug Breakpoint Control Register 7
AARCH64REG_WRITE_INLINE(dbgbcr7_el1)
AARCH64REG_READ_INLINE(dbgbcr8_el1) // Debug Breakpoint Control Register 8
AARCH64REG_WRITE_INLINE(dbgbcr8_el1)
AARCH64REG_READ_INLINE(dbgbcr9_el1) // Debug Breakpoint Control Register 9
AARCH64REG_WRITE_INLINE(dbgbcr9_el1)
AARCH64REG_READ_INLINE(dbgbcr10_el1) // Debug Breakpoint Control Register 10
AARCH64REG_WRITE_INLINE(dbgbcr10_el1)
AARCH64REG_READ_INLINE(dbgbcr11_el1) // Debug Breakpoint Control Register 11
AARCH64REG_WRITE_INLINE(dbgbcr11_el1)
AARCH64REG_READ_INLINE(dbgbcr12_el1) // Debug Breakpoint Control Register 12
AARCH64REG_WRITE_INLINE(dbgbcr12_el1)
AARCH64REG_READ_INLINE(dbgbcr13_el1) // Debug Breakpoint Control Register 13
AARCH64REG_WRITE_INLINE(dbgbcr13_el1)
AARCH64REG_READ_INLINE(dbgbcr14_el1) // Debug Breakpoint Control Register 14
AARCH64REG_WRITE_INLINE(dbgbcr14_el1)
AARCH64REG_READ_INLINE(dbgbcr15_el1) // Debug Breakpoint Control Register 15
AARCH64REG_WRITE_INLINE(dbgbcr15_el1)

#define	DBGBCR_BT		 __BITS(23,20)
#define	DBGBCR_LBN		 __BITS(19,16)
#define	DBGBCR_SSC		 __BITS(15,14)
#define	DBGBCR_HMC		 __BIT(13)
#define	DBGBCR_BAS		 __BITS(8,5)
#define	DBGBCR_PMC		 __BITS(2,1)
#define	DBGBCR_E		 __BIT(0)

AARCH64REG_READ_INLINE(dbgbvr0_el1) // Debug Breakpoint Value Register 0
AARCH64REG_WRITE_INLINE(dbgbvr0_el1)
AARCH64REG_READ_INLINE(dbgbvr1_el1) // Debug Breakpoint Value Register 1
AARCH64REG_WRITE_INLINE(dbgbvr1_el1)
AARCH64REG_READ_INLINE(dbgbvr2_el1) // Debug Breakpoint Value Register 2
AARCH64REG_WRITE_INLINE(dbgbvr2_el1)
AARCH64REG_READ_INLINE(dbgbvr3_el1) // Debug Breakpoint Value Register 3
AARCH64REG_WRITE_INLINE(dbgbvr3_el1)
AARCH64REG_READ_INLINE(dbgbvr4_el1) // Debug Breakpoint Value Register 4
AARCH64REG_WRITE_INLINE(dbgbvr4_el1)
AARCH64REG_READ_INLINE(dbgbvr5_el1) // Debug Breakpoint Value Register 5
AARCH64REG_WRITE_INLINE(dbgbvr5_el1)
AARCH64REG_READ_INLINE(dbgbvr6_el1) // Debug Breakpoint Value Register 6
AARCH64REG_WRITE_INLINE(dbgbvr6_el1)
AARCH64REG_READ_INLINE(dbgbvr7_el1) // Debug Breakpoint Value Register 7
AARCH64REG_WRITE_INLINE(dbgbvr7_el1)
AARCH64REG_READ_INLINE(dbgbvr8_el1) // Debug Breakpoint Value Register 8
AARCH64REG_WRITE_INLINE(dbgbvr8_el1)
AARCH64REG_READ_INLINE(dbgbvr9_el1) // Debug Breakpoint Value Register 9
AARCH64REG_WRITE_INLINE(dbgbvr9_el1)
AARCH64REG_READ_INLINE(dbgbvr10_el1) // Debug Breakpoint Value Register 10
AARCH64REG_WRITE_INLINE(dbgbvr10_el1)
AARCH64REG_READ_INLINE(dbgbvr11_el1) // Debug Breakpoint Value Register 11
AARCH64REG_WRITE_INLINE(dbgbvr11_el1)
AARCH64REG_READ_INLINE(dbgbvr12_el1) // Debug Breakpoint Value Register 12
AARCH64REG_WRITE_INLINE(dbgbvr12_el1)
AARCH64REG_READ_INLINE(dbgbvr13_el1) // Debug Breakpoint Value Register 13
AARCH64REG_WRITE_INLINE(dbgbvr13_el1)
AARCH64REG_READ_INLINE(dbgbvr14_el1) // Debug Breakpoint Value Register 14
AARCH64REG_WRITE_INLINE(dbgbvr14_el1)
AARCH64REG_READ_INLINE(dbgbvr15_el1) // Debug Breakpoint Value Register 15
AARCH64REG_WRITE_INLINE(dbgbvr15_el1)

#define	DBGBVR_MASK		 __BITS(63,2)

AARCH64REG_READ_INLINE(dbgwcr0_el1) // Debug Watchpoint Control Register 0
AARCH64REG_WRITE_INLINE(dbgwcr0_el1)
AARCH64REG_READ_INLINE(dbgwcr1_el1) // Debug Watchpoint Control Register 1
AARCH64REG_WRITE_INLINE(dbgwcr1_el1)
AARCH64REG_READ_INLINE(dbgwcr2_el1) // Debug Watchpoint Control Register 2
AARCH64REG_WRITE_INLINE(dbgwcr2_el1)
AARCH64REG_READ_INLINE(dbgwcr3_el1) // Debug Watchpoint Control Register 3
AARCH64REG_WRITE_INLINE(dbgwcr3_el1)
AARCH64REG_READ_INLINE(dbgwcr4_el1) // Debug Watchpoint Control Register 4
AARCH64REG_WRITE_INLINE(dbgwcr4_el1)
AARCH64REG_READ_INLINE(dbgwcr5_el1) // Debug Watchpoint Control Register 5
AARCH64REG_WRITE_INLINE(dbgwcr5_el1)
AARCH64REG_READ_INLINE(dbgwcr6_el1) // Debug Watchpoint Control Register 6
AARCH64REG_WRITE_INLINE(dbgwcr6_el1)
AARCH64REG_READ_INLINE(dbgwcr7_el1) // Debug Watchpoint Control Register 7
AARCH64REG_WRITE_INLINE(dbgwcr7_el1)
AARCH64REG_READ_INLINE(dbgwcr8_el1) // Debug Watchpoint Control Register 8
AARCH64REG_WRITE_INLINE(dbgwcr8_el1)
AARCH64REG_READ_INLINE(dbgwcr9_el1) // Debug Watchpoint Control Register 9
AARCH64REG_WRITE_INLINE(dbgwcr9_el1)
AARCH64REG_READ_INLINE(dbgwcr10_el1) // Debug Watchpoint Control Register 10
AARCH64REG_WRITE_INLINE(dbgwcr10_el1)
AARCH64REG_READ_INLINE(dbgwcr11_el1) // Debug Watchpoint Control Register 11
AARCH64REG_WRITE_INLINE(dbgwcr11_el1)
AARCH64REG_READ_INLINE(dbgwcr12_el1) // Debug Watchpoint Control Register 12
AARCH64REG_WRITE_INLINE(dbgwcr12_el1)
AARCH64REG_READ_INLINE(dbgwcr13_el1) // Debug Watchpoint Control Register 13
AARCH64REG_WRITE_INLINE(dbgwcr13_el1)
AARCH64REG_READ_INLINE(dbgwcr14_el1) // Debug Watchpoint Control Register 14
AARCH64REG_WRITE_INLINE(dbgwcr14_el1)
AARCH64REG_READ_INLINE(dbgwcr15_el1) // Debug Watchpoint Control Register 15
AARCH64REG_WRITE_INLINE(dbgwcr15_el1)

#define	DBGWCR_MASK		 __BITS(28,24)
#define	DBGWCR_WT		 __BIT(20)
#define	DBGWCR_LBN		 __BITS(19,16)
#define	DBGWCR_SSC		 __BITS(15,14)
#define	DBGWCR_HMC		 __BIT(13)
#define	DBGWCR_BAS		 __BITS(12,5)
#define	DBGWCR_LSC		 __BITS(4,3)
#define	DBGWCR_PAC		 __BITS(2,1)
#define	DBGWCR_E		 __BIT(0)

AARCH64REG_READ_INLINE(dbgwvr0_el1) // Debug Watchpoint Value Register 0
AARCH64REG_WRITE_INLINE(dbgwvr0_el1)
AARCH64REG_READ_INLINE(dbgwvr1_el1) // Debug Watchpoint Value Register 1
AARCH64REG_WRITE_INLINE(dbgwvr1_el1)
AARCH64REG_READ_INLINE(dbgwvr2_el1) // Debug Watchpoint Value Register 2
AARCH64REG_WRITE_INLINE(dbgwvr2_el1)
AARCH64REG_READ_INLINE(dbgwvr3_el1) // Debug Watchpoint Value Register 3
AARCH64REG_WRITE_INLINE(dbgwvr3_el1)
AARCH64REG_READ_INLINE(dbgwvr4_el1) // Debug Watchpoint Value Register 4
AARCH64REG_WRITE_INLINE(dbgwvr4_el1)
AARCH64REG_READ_INLINE(dbgwvr5_el1) // Debug Watchpoint Value Register 5
AARCH64REG_WRITE_INLINE(dbgwvr5_el1)
AARCH64REG_READ_INLINE(dbgwvr6_el1) // Debug Watchpoint Value Register 6
AARCH64REG_WRITE_INLINE(dbgwvr6_el1)
AARCH64REG_READ_INLINE(dbgwvr7_el1) // Debug Watchpoint Value Register 7
AARCH64REG_WRITE_INLINE(dbgwvr7_el1)
AARCH64REG_READ_INLINE(dbgwvr8_el1) // Debug Watchpoint Value Register 8
AARCH64REG_WRITE_INLINE(dbgwvr8_el1)
AARCH64REG_READ_INLINE(dbgwvr9_el1) // Debug Watchpoint Value Register 9
AARCH64REG_WRITE_INLINE(dbgwvr9_el1)
AARCH64REG_READ_INLINE(dbgwvr10_el1) // Debug Watchpoint Value Register 10
AARCH64REG_WRITE_INLINE(dbgwvr10_el1)
AARCH64REG_READ_INLINE(dbgwvr11_el1) // Debug Watchpoint Value Register 11
AARCH64REG_WRITE_INLINE(dbgwvr11_el1)
AARCH64REG_READ_INLINE(dbgwvr12_el1) // Debug Watchpoint Value Register 12
AARCH64REG_WRITE_INLINE(dbgwvr12_el1)
AARCH64REG_READ_INLINE(dbgwvr13_el1) // Debug Watchpoint Value Register 13
AARCH64REG_WRITE_INLINE(dbgwvr13_el1)
AARCH64REG_READ_INLINE(dbgwvr14_el1) // Debug Watchpoint Value Register 14
AARCH64REG_WRITE_INLINE(dbgwvr14_el1)
AARCH64REG_READ_INLINE(dbgwvr15_el1) // Debug Watchpoint Value Register 15
AARCH64REG_WRITE_INLINE(dbgwvr15_el1)

#define	DBGWVR_MASK		 __BITS(63,2)


AARCH64REG_READ_INLINE(mdscr_el1) // Monitor Debug System Control Register
AARCH64REG_WRITE_INLINE(mdscr_el1)

#define	MDSCR_RXFULL		__BIT(30)	// for EDSCR.RXfull
#define	MDSCR_TXFULL		__BIT(29)	// for EDSCR.TXfull
#define	MDSCR_RXO		__BIT(27)	// for EDSCR.RXO
#define	MDSCR_TXU		__BIT(26)	// for EDSCR.TXU
#define	MDSCR_INTDIS		__BITS(32,22)	// for EDSCR.INTdis
#define	MDSCR_TDA		__BIT(21)	// for EDSCR.TDA
#define	MDSCR_MDE		__BIT(15)	// Monitor debug events
#define	MDSCR_HDE		__BIT(14)	// for EDSCR.HDE
#define	MDSCR_KDE		__BIT(13)	// Local debug enable
#define	MDSCR_TDCC		__BIT(12)	// Trap Debug CommCh access
#define	MDSCR_ERR		__BIT(6)	// for EDSCR.ERR
#define	MDSCR_SS		__BIT(0)	// Software step

AARCH64REG_WRITE_INLINE(oslar_el1)	// OS Lock Access Register

AARCH64REG_READ_INLINE(oslsr_el1)	// OS Lock Status Register

/*
 * From here on, these are PMC registers
 */

AARCH64REG_READ_INLINE(pmccfiltr_el0)
AARCH64REG_WRITE_INLINE(pmccfiltr_el0)

#define	PMCCFILTR_P		__BIT(31)	// Don't count cycles in EL1
#define	PMCCFILTR_U		__BIT(30)	// Don't count cycles in EL0
#define	PMCCFILTR_NSK		__BIT(29)	// Don't count cycles in NS EL1
#define	PMCCFILTR_NSU 		__BIT(28)	// Don't count cycles in NS EL0
#define	PMCCFILTR_NSH 		__BIT(27)	// Don't count cycles in NS EL2
#define	PMCCFILTR_M		__BIT(26)	// Don't count cycles in EL3

AARCH64REG_READ_INLINE(pmccntr_el0)

AARCH64REG_READ_INLINE(pmceid0_el0)
AARCH64REG_READ_INLINE(pmceid1_el0)

AARCH64REG_WRITE_INLINE(pmcntenclr_el0)
AARCH64REG_WRITE_INLINE(pmcntenset_el0)

#define	PMCNTEN_C		__BIT(31)	// Enable the cycle counter
#define	PMCNTEN_P		__BITS(30,0)	// Enable event counter bits

AARCH64REG_READ_INLINE(pmcr_el0)
AARCH64REG_WRITE_INLINE(pmcr_el0)

#define	PMCR_IMP		__BITS(31,24)	// Implementor code
#define	PMCR_IDCODE		__BITS(23,16)	// Identification code
#define	PMCR_N			__BITS(15,11)	// Number of event counters
#define	PMCR_LP			__BIT(7)	// Long event counter enable
#define	PMCR_LC			__BIT(6)	// Long cycle counter enable
#define	PMCR_DP			__BIT(5)	// Disable cycle counter when event
						// counting is prohibited
#define	PMCR_X			__BIT(4)	// Enable export of events
#define	PMCR_D			__BIT(3)	// Clock divider
#define	PMCR_C			__BIT(2)	// Cycle counter reset
#define	PMCR_P			__BIT(1)	// Event counter reset
#define	PMCR_E			__BIT(0)	// Enable


AARCH64REG_READ_INLINE(pmevcntr1_el0)
AARCH64REG_WRITE_INLINE(pmevcntr1_el0)

AARCH64REG_READ_INLINE(pmevtyper1_el0)
AARCH64REG_WRITE_INLINE(pmevtyper1_el0)

#define	PMEVTYPER_P		__BIT(31)	// Don't count events in EL1
#define	PMEVTYPER_U		__BIT(30)	// Don't count events in EL0
#define	PMEVTYPER_NSK		__BIT(29)	// Don't count events in NS EL1
#define	PMEVTYPER_NSU		__BIT(28)	// Don't count events in NS EL0
#define	PMEVTYPER_NSH		__BIT(27)	// Count events in NS EL2
#define	PMEVTYPER_M		__BIT(26)	// Don't count events in EL3
#define	PMEVTYPER_MT		__BIT(25)	// Count events on all CPUs with same
						// aff1 level
#define	PMEVTYPER_EVTCOUNT	__BITS(15,0)	// Event to count

AARCH64REG_WRITE_INLINE(pmintenclr_el1)
AARCH64REG_WRITE_INLINE(pmintenset_el1)

#define PMINTEN_C		__BIT(31)	// for the cycle counter
#define PMINTEN_P		__BITS(30,0)	// for event counters (0-30)

AARCH64REG_WRITE_INLINE(pmovsclr_el0)
AARCH64REG_READ_INLINE(pmovsset_el0)
AARCH64REG_WRITE_INLINE(pmovsset_el0)

#define PMOVS_C			__BIT(31)	// for the cycle counter
#define PMOVS_P			__BITS(30,0)	// for event counters (0-30)

AARCH64REG_WRITE_INLINE(pmselr_el0)

AARCH64REG_WRITE_INLINE(pmswinc_el0)

AARCH64REG_READ_INLINE(pmuserenr_el0)
AARCH64REG_WRITE_INLINE(pmuserenr_el0)

AARCH64REG_READ_INLINE(pmxevcntr_el0)
AARCH64REG_WRITE_INLINE(pmxevcntr_el0)

AARCH64REG_READ_INLINE(pmxevtyper_el0)
AARCH64REG_WRITE_INLINE(pmxevtyper_el0)

/*
 * Generic timer registers
 */

AARCH64REG_READ_INLINE(cntfrq_el0)

AARCH64REG_READ_INLINE(cnthctl_el2)
AARCH64REG_WRITE_INLINE(cnthctl_el2)

#define	CNTHCTL_EVNTDIR		__BIT(3)
#define	CNTHCTL_EVNTEN		__BIT(2)
#define	CNTHCTL_EL1PCEN		__BIT(1)
#define	CNTHCTL_EL1PCTEN	__BIT(0)

AARCH64REG_READ_INLINE(cntkctl_el1)
AARCH64REG_WRITE_INLINE(cntkctl_el1)

#define	CNTKCTL_EL0PTEN		__BIT(9)	// EL0 access for CNTP CVAL/TVAL/CTL
#define	CNTKCTL_PL0PTEN		CNTKCTL_EL0PTEN
#define	CNTKCTL_EL0VTEN		__BIT(8)	// EL0 access for CNTV CVAL/TVAL/CTL
#define	CNTKCTL_PL0VTEN		CNTKCTL_EL0VTEN
#define	CNTKCTL_ELNTI		__BITS(7,4)
#define	CNTKCTL_EVNTDIR		__BIT(3)
#define	CNTKCTL_EVNTEN		__BIT(2)
#define	CNTKCTL_EL0VCTEN	__BIT(1)	// EL0 access for CNTVCT and CNTFRQ
#define	CNTKCTL_PL0VCTEN	CNTKCTL_EL0VCTEN
#define	CNTKCTL_EL0PCTEN	__BIT(0)	// EL0 access for CNTPCT and CNTFRQ
#define	CNTKCTL_PL0PCTEN	CNTKCTL_EL0PCTEN

AARCH64REG_READ_INLINE(cntp_ctl_el0)
AARCH64REG_WRITE_INLINE(cntp_ctl_el0)
AARCH64REG_READ_INLINE(cntp_cval_el0)
AARCH64REG_WRITE_INLINE(cntp_cval_el0)
AARCH64REG_READ_INLINE(cntp_tval_el0)
AARCH64REG_WRITE_INLINE(cntp_tval_el0)
AARCH64REG_READ_INLINE(cntpct_el0)
AARCH64REG_WRITE_INLINE(cntpct_el0)

AARCH64REG_READ_INLINE(cntps_ctl_el1)
AARCH64REG_WRITE_INLINE(cntps_ctl_el1)
AARCH64REG_READ_INLINE(cntps_cval_el1)
AARCH64REG_WRITE_INLINE(cntps_cval_el1)
AARCH64REG_READ_INLINE(cntps_tval_el1)
AARCH64REG_WRITE_INLINE(cntps_tval_el1)

AARCH64REG_READ_INLINE(cntv_ctl_el0)
AARCH64REG_WRITE_INLINE(cntv_ctl_el0)
AARCH64REG_READ_INLINE(cntv_cval_el0)
AARCH64REG_WRITE_INLINE(cntv_cval_el0)
AARCH64REG_READ_INLINE(cntv_tval_el0)
AARCH64REG_WRITE_INLINE(cntv_tval_el0)
AARCH64REG_READ_INLINE(cntvct_el0)
AARCH64REG_WRITE_INLINE(cntvct_el0)

#define	CNTCTL_ISTATUS		__BIT(2)	// Interrupt Asserted
#define	CNTCTL_IMASK		__BIT(1)	// Timer Interrupt is Masked
#define	CNTCTL_ENABLE		__BIT(0)	// Timer Enabled

// ID_AA64PFR0_EL1: AArch64 Processor Feature Register 0
#define	ID_AA64PFR0_EL1_CSV3		__BITS(63,60) // Speculative fault data
#define	 ID_AA64PFR0_EL1_CSV3_NONE	0
#define	 ID_AA64PFR0_EL1_CSV3_IMPL	1
#define	ID_AA64PFR0_EL1_CSV2		__BITS(59,56) // Speculative branches
#define	 ID_AA64PFR0_EL1_CSV2_NONE	0
#define	 ID_AA64PFR0_EL1_CSV2_IMPL	1
// reserved [55:52]
#define	ID_AA64PFR0_EL1_DIT		__BITS(51,48) // Data-indep. timing
#define	 ID_AA64PFR0_EL1_DIT_NONE	0
#define	 ID_AA64PFR0_EL1_DIT_IMPL	1
#define	ID_AA64PFR0_EL1_AMU		__BITS(47,44) // Activity monitors ext.
#define	 ID_AA64PFR0_EL1_AMU_NONE	0
#define	 ID_AA64PFR0_EL1_AMU_IMPLv8_4	1
#define	 ID_AA64PFR0_EL1_AMU_IMPLv8_6	2
#define	ID_AA64PFR0_EL1_MPAM		__BITS(43,40) // MPAM Extension
#define	 ID_AA64PFR0_EL1_MPAM_NONE	0
#define	 ID_AA64PFR0_EL1_MPAM_IMPL	1
#define	ID_AA64PFR0_EL1_SEL2		__BITS(43,40) // Secure EL2
#define	 ID_AA64PFR0_EL1_SEL2_NONE	0
#define	 ID_AA64PFR0_EL1_SEL2_IMPL	1
#define	ID_AA64PFR0_EL1_SVE		__BITS(35,32) // Scalable Vector
#define	 ID_AA64PFR0_EL1_SVE_NONE	 0
#define	 ID_AA64PFR0_EL1_SVE_IMPL	 1
#define	ID_AA64PFR0_EL1_RAS		__BITS(31,28) // RAS Extension
#define	 ID_AA64PFR0_EL1_RAS_NONE	 0
#define	 ID_AA64PFR0_EL1_RAS_IMPL	 1
#define	 ID_AA64PFR0_EL1_RAS_ERX	 2
#define	ID_AA64PFR0_EL1_GIC		__BITS(24,27) // GIC CPU IF
#define	ID_AA64PFR0_EL1_GIC_SHIFT	24
#define	 ID_AA64PFR0_EL1_GIC_CPUIF_EN	 1
#define	 ID_AA64PFR0_EL1_GIC_CPUIF_NONE	 0
#define	ID_AA64PFR0_EL1_ADVSIMD		__BITS(23,20) // SIMD
#define	 ID_AA64PFR0_EL1_ADV_SIMD_IMPL	 0x0
#define	 ID_AA64PFR0_EL1_ADV_SIMD_HP	 0x1
#define	 ID_AA64PFR0_EL1_ADV_SIMD_NONE	 0xf
#define	ID_AA64PFR0_EL1_FP		__BITS(19,16) // FP
#define	 ID_AA64PFR0_EL1_FP_IMPL	 0x0
#define	 ID_AA64PFR0_EL1_FP_HP		 0x1
#define	 ID_AA64PFR0_EL1_FP_NONE	 0xf
#define	ID_AA64PFR0_EL1_EL3		__BITS(15,12) // EL3 handling
#define	 ID_AA64PFR0_EL1_EL3_NONE	 0
#define	 ID_AA64PFR0_EL1_EL3_64		 1
#define	 ID_AA64PFR0_EL1_EL3_64_32	 2
#define	ID_AA64PFR0_EL1_EL2		__BITS(11,8) // EL2 handling
#define	 ID_AA64PFR0_EL1_EL2_NONE	 0
#define	 ID_AA64PFR0_EL1_EL2_64	 	 1
#define	 ID_AA64PFR0_EL1_EL2_64_32	 2
#define	ID_AA64PFR0_EL1_EL1		__BITS(7,4) // EL1 handling
#define	 ID_AA64PFR0_EL1_EL1_64	 	 1
#define	 ID_AA64PFR0_EL1_EL1_64_32	 2
#define	ID_AA64PFR0_EL1_EL0		__BITS(3,0) // EL0 handling
#define	 ID_AA64PFR0_EL1_EL0_64	 	 1
#define	 ID_AA64PFR0_EL1_EL0_64_32	 2

/*
 * GICv3 system registers
 */
AARCH64REG_READWRITE_INLINE2(icc_sre_el1, s3_0_c12_c12_5)
AARCH64REG_READWRITE_INLINE2(icc_ctlr_el1, s3_0_c12_c12_4)
AARCH64REG_READWRITE_INLINE2(icc_pmr_el1, s3_0_c4_c6_0)
AARCH64REG_READWRITE_INLINE2(icc_bpr0_el1, s3_0_c12_c8_3)
AARCH64REG_READWRITE_INLINE2(icc_bpr1_el1, s3_0_c12_c12_3)
AARCH64REG_READWRITE_INLINE2(icc_igrpen0_el1, s3_0_c12_c12_6)
AARCH64REG_READWRITE_INLINE2(icc_igrpen1_el1, s3_0_c12_c12_7)
AARCH64REG_READWRITE_INLINE2(icc_eoir0_el1, s3_0_c12_c8_1)
AARCH64REG_READWRITE_INLINE2(icc_eoir1_el1, s3_0_c12_c12_1)
AARCH64REG_READWRITE_INLINE2(icc_sgi1r_el1, s3_0_c12_c11_5)
AARCH64REG_READ_INLINE2(icc_iar1_el1, s3_0_c12_c12_0)

// ICC_SRE_EL1: Interrupt Controller System Register Enable register
#define	ICC_SRE_EL1_DIB		__BIT(2)
#define	ICC_SRE_EL1_DFB		__BIT(1)
#define	ICC_SRE_EL1_SRE		__BIT(0)

// ICC_SRE_EL2: Interrupt Controller System Register Enable register
#define	ICC_SRE_EL2_EN		__BIT(3)
#define	ICC_SRE_EL2_DIB		__BIT(2)
#define	ICC_SRE_EL2_DFB		__BIT(1)
#define	ICC_SRE_EL2_SRE		__BIT(0)

// ICC_BPR[01]_EL1: Interrupt Controller Binary Point Register 0/1
#define	ICC_BPR_EL1_BinaryPoint	__BITS(2,0)

// ICC_CTLR_EL1: Interrupt Controller Control Register
#define	ICC_CTLR_EL1_A3V	__BIT(15)
#define	ICC_CTLR_EL1_SEIS	__BIT(14)
#define	ICC_CTLR_EL1_IDbits	__BITS(13,11)
#define	ICC_CTLR_EL1_PRIbits	__BITS(10,8)
#define	ICC_CTLR_EL1_PMHE	__BIT(6)
#define	ICC_CTLR_EL1_EOImode	__BIT(1)
#define	ICC_CTLR_EL1_CBPR	__BIT(0)

// ICC_IGRPEN[01]_EL1: Interrupt Controller Interrupt Group 0/1 Enable register
#define	ICC_IGRPEN_EL1_Enable	__BIT(0)

// ICC_SGI[01]R_EL1: Interrupt Controller Software Generated Interrupt Group 0/1 Register
#define	ICC_SGIR_EL1_Aff3	__BITS(55,48)
#define	ICC_SGIR_EL1_IRM	__BIT(40)
#define	ICC_SGIR_EL1_Aff2	__BITS(39,32)
#define	ICC_SGIR_EL1_INTID	__BITS(27,24)
#define	ICC_SGIR_EL1_Aff1	__BITS(23,16)
#define	ICC_SGIR_EL1_TargetList	__BITS(15,0)
#define	ICC_SGIR_EL1_Aff	(ICC_SGIR_EL1_Aff3|ICC_SGIR_EL1_Aff2|ICC_SGIR_EL1_Aff1)

// ICC_IAR[01]_EL1: Interrupt Controller Interrupt Acknowledge Register 0/1
#define	ICC_IAR_INTID		__BITS(23,0)
#define	ICC_IAR_INTID_SPURIOUS	1023

/*
 * GICv3 REGISTER ACCESS
 */

#define	icc_sre_read		reg_icc_sre_el1_read
#define	icc_sre_write		reg_icc_sre_el1_write
#define	icc_pmr_read		reg_icc_pmr_el1_read
#define	icc_pmr_write		reg_icc_pmr_el1_write
#define	icc_bpr0_write		reg_icc_bpr0_el1_write
#define	icc_bpr1_write		reg_icc_bpr1_el1_write
#define	icc_ctlr_read		reg_icc_ctlr_el1_read
#define	icc_ctlr_write		reg_icc_ctlr_el1_write
#define	icc_igrpen1_write	reg_icc_igrpen1_el1_write
#define	icc_sgi1r_write		reg_icc_sgi1r_el1_write
#define	icc_iar1_read		reg_icc_iar1_el1_read
#define	icc_eoi1r_write		reg_icc_eoir1_el1_write

#if defined(_KERNEL)

/*
 * CPU REGISTER ACCESS
 */
static __inline register_t
cpu_mpidr_aff_read(void)
{

	return reg_mpidr_el1_read() &
	    (MPIDR_AFF3|MPIDR_AFF2|MPIDR_AFF1|MPIDR_AFF0);
}

/*
 * GENERIC TIMER REGISTER ACCESS
 */
static __inline uint32_t
gtmr_cntfrq_read(void)
{

	return reg_cntfrq_el0_read();
}

static __inline uint32_t
gtmr_cntk_ctl_read(void)
{

	return reg_cntkctl_el1_read();
}

static __inline void
gtmr_cntk_ctl_write(uint32_t val)
{

	reg_cntkctl_el1_write(val);
}

/*
 * Counter-timer Virtual Count timer
 */
static __inline uint64_t
gtmr_cntpct_read(void)
{

	return reg_cntpct_el0_read();
}

static __inline uint64_t
gtmr_cntvct_read(void)
{

	return reg_cntvct_el0_read();
}

/*
 * Counter-timer Virtual Timer Control register
 */
static __inline uint64_t
gtmr_cntv_ctl_read(void)
{

	return reg_cntv_ctl_el0_read();
}

static __inline void
gtmr_cntv_ctl_write(uint64_t val)
{

	reg_cntv_ctl_el0_write(val);
}

/*
 * Counter-timer Physical Timer Control register
 */
static __inline uint32_t
gtmr_cntp_ctl_read(void)
{

	return reg_cntp_ctl_el0_read();
}

static __inline void
gtmr_cntp_ctl_write(uint32_t val)
{

	reg_cntp_ctl_el0_write(val);
}

/*
 * Counter-timer Physical Timer TimerValue register
 */
static __inline uint32_t
gtmr_cntp_tval_read(void)
{

	return reg_cntp_tval_el0_read();
}

static __inline void
gtmr_cntp_tval_write(uint32_t val)
{

	reg_cntp_tval_el0_write(val);
}

/*
 * Counter-timer Virtual Timer TimerValue register
 */
static __inline uint32_t
gtmr_cntv_tval_read(void)
{

	return reg_cntv_tval_el0_read();
}

static __inline void
gtmr_cntv_tval_write(uint32_t val)
{

	reg_cntv_tval_el0_write(val);
}

/*
 * Counter-timer Physical Timer CompareValue register
 */
static __inline uint64_t
gtmr_cntp_cval_read(void)
{

	return reg_cntp_cval_el0_read();
}

static __inline void
gtmr_cntp_cval_write(uint64_t val)
{

	reg_cntp_cval_el0_write(val);
}

/*
 * Counter-timer Virtual Timer CompareValue register
 */
static __inline uint64_t
gtmr_cntv_cval_read(void)
{

	return reg_cntv_cval_el0_read();
}

static __inline void
gtmr_cntv_cval_write(uint64_t val)
{

	reg_cntv_cval_el0_write(val);
}
#endif /* _KERNEL */

/*
 * Structure attached to machdep.cpuN.cpu_id sysctl node.
 * Always add new members to the end, and avoid arrays.
 */
struct aarch64_sysctl_cpu_id {
	uint64_t ac_midr;	/* Main ID Register */
	uint64_t ac_revidr;	/* Revision ID Register */
	uint64_t ac_mpidr;	/* Multiprocessor Affinity Register */

	uint64_t ac_aa64dfr0;	/* A64 Debug Feature Register 0 */
	uint64_t ac_aa64dfr1;	/* A64 Debug Feature Register 1 */

	uint64_t ac_aa64isar0;	/* A64 Instruction Set Attribute Register 0 */
	uint64_t ac_aa64isar1;	/* A64 Instruction Set Attribute Register 1 */

	uint64_t ac_aa64mmfr0;	/* A64 Memory Model Feature Register 0 */
	uint64_t ac_aa64mmfr1;	/* A64 Memory Model Feature Register 1 */
	uint64_t ac_aa64mmfr2;	/* A64 Memory Model Feature Register 2 */

	uint64_t ac_aa64pfr0;	/* A64 Processor Feature Register 0 */
	uint64_t ac_aa64pfr1;	/* A64 Processor Feature Register 1 */

	uint64_t ac_aa64zfr0;	/* A64 SVE Feature ID Register 0 */

	uint32_t ac_mvfr0;	/* Media and VFP Feature Register 0 */
	uint32_t ac_mvfr1;	/* Media and VFP Feature Register 1 */
	uint32_t ac_mvfr2;	/* Media and VFP Feature Register 2 */
	uint32_t ac_pad;

	uint64_t ac_clidr;	/* Cache Level ID Register */
	uint64_t ac_ctr;	/* Cache Type Register */
};

#endif /* _AARCH64_ARMREG_H_ */