/*-
 * Copyright (c) 1996-1997 John D. Polstra.
 * All rights reserved.
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
#include <arm/elf.h>
#else /* !__arm__ */

#ifndef	_MACHINE_ELF_H_
#define	_MACHINE_ELF_H_

/*
 * ELF definitions for the AArch64 architecture.
 */

#include <sys/elf32.h>	/* Definitions common to all 32 bit architectures. */
#include <sys/elf64.h>	/* Definitions common to all 64 bit architectures. */

#ifndef __ELF_WORD_SIZE
#define	__ELF_WORD_SIZE	64	/* Used by <sys/elf_generic.h> */
#endif

#include <sys/elf_generic.h>

/*
 * Auxiliary vector entries for passing information to the interpreter.
 */

typedef struct {	/* Auxiliary vector entry on initial stack */
	int	a_type;			/* Entry type. */
	union {
		int	a_val;		/* Integer value. */
	} a_un;
} Elf32_Auxinfo;

typedef struct {	/* Auxiliary vector entry on initial stack */
	long	a_type;			/* Entry type. */
	union {
		long	a_val;		/* Integer value. */
		void	*a_ptr;		/* Address. */
		void	(*a_fcn)(void);	/* Function pointer (not used). */
	} a_un;
} Elf64_Auxinfo;

__ElfType(Auxinfo);

#ifdef _MACHINE_ELF_WANT_32BIT
#define	ELF_ARCH	EM_ARM
#else
#define	ELF_ARCH	EM_AARCH64
#endif

#define	ELF_MACHINE_OK(x) ((x) == (ELF_ARCH))

/* Define "machine" characteristics */
#if __ELF_WORD_SIZE == 64
#define	ELF_TARG_CLASS	ELFCLASS64
#define	ELF_TARG_DATA	ELFDATA2LSB
#define	ELF_TARG_MACH	EM_AARCH64
#define	ELF_TARG_VER	1
#else
#define	ELF_TARG_CLASS	ELFCLASS32
#define	ELF_TARG_DATA	ELFDATA2LSB
#define	ELF_TARG_MACH	EM_ARM
#define	ELF_TARG_VER	1
#endif

#if __ELF_WORD_SIZE == 32
#define	ET_DYN_LOAD_ADDR 0x01001000
#else
#define	ET_DYN_LOAD_ADDR 0x100000
#endif

/* First __FreeBSD_version that supports Top Byte Ignore (TBI) */
#define	TBI_VERSION	1500058

/* HWCAP */
#define	HWCAP_FP		(1 << 0)
#define	HWCAP_ASIMD		(1 << 1)
#define	HWCAP_EVTSTRM		(1 << 2)
#define	HWCAP_AES		(1 << 3)
#define	HWCAP_PMULL		(1 << 4)
#define	HWCAP_SHA1		(1 << 5)
#define	HWCAP_SHA2		(1 << 6)
#define	HWCAP_CRC32		(1 << 7)
#define	HWCAP_ATOMICS		(1 << 8)
#define	HWCAP_FPHP		(1 << 9)
#define	HWCAP_ASIMDHP		(1 << 10)
/*
 * XXX: The following bits (from CPUID to FLAGM) were originally incorrect,
 * but later changed to match the Linux definitions. No compatibility code is
 * provided, as the fix was expected to result in near-zero fallout.
 */
#define	HWCAP_CPUID		(1 << 11)
#define	HWCAP_ASIMDRDM		(1 << 12)
#define	HWCAP_JSCVT		(1 << 13)
#define	HWCAP_FCMA		(1 << 14)
#define	HWCAP_LRCPC		(1 << 15)
#define	HWCAP_DCPOP		(1 << 16)
#define	HWCAP_SHA3		(1 << 17)
#define	HWCAP_SM3		(1 << 18)
#define	HWCAP_SM4		(1 << 19)
#define	HWCAP_ASIMDDP		(1 << 20)
#define	HWCAP_SHA512		(1 << 21)
#define	HWCAP_SVE		(1 << 22)
#define	HWCAP_ASIMDFHM		(1 << 23)
#define	HWCAP_DIT		(1 << 24)
#define	HWCAP_USCAT		(1 << 25)
#define	HWCAP_ILRCPC		(1 << 26)
#define	HWCAP_FLAGM		(1 << 27)
#define	HWCAP_SSBS		(1 << 28)
#define	HWCAP_SB		(1 << 29)
#define	HWCAP_PACA		(1 << 30)
#define	HWCAP_PACG		(1UL << 31)
#define	HWCAP_GCS		(1UL << 32)

/* HWCAP2 */
#define	HWCAP2_DCPODP		(1 << 0)
#define	HWCAP2_SVE2		(1 << 1)
#define	HWCAP2_SVEAES		(1 << 2)
#define	HWCAP2_SVEPMULL		(1 << 3)
#define	HWCAP2_SVEBITPERM	(1 << 4)
#define	HWCAP2_SVESHA3		(1 << 5)
#define	HWCAP2_SVESM4		(1 << 6)
#define	HWCAP2_FLAGM2		(1 << 7)
#define	HWCAP2_FRINT		(1 << 8)
#define	HWCAP2_SVEI8MM		(1 << 9)
#define	HWCAP2_SVEF32MM		(1 << 10)
#define	HWCAP2_SVEF64MM		(1 << 11)
#define	HWCAP2_SVEBF16		(1 << 12)
#define	HWCAP2_I8MM		(1 << 13)
#define	HWCAP2_BF16		(1 << 14)
#define	HWCAP2_DGH		(1 << 15)
#define	HWCAP2_RNG		(1 << 16)
#define	HWCAP2_BTI		(1 << 17)
#define	HWCAP2_MTE		(1 << 18)
#define	HWCAP2_ECV		(1 << 19)
#define	HWCAP2_AFP		(1 << 20)
#define	HWCAP2_RPRES		(1 << 21)
#define	HWCAP2_MTE3		(1 << 22)
#define	HWCAP2_SME		(1 << 23)
#define	HWCAP2_SME_I16I64	(1 << 24)
#define	HWCAP2_SME_F64F64	(1 << 25)
#define	HWCAP2_SME_I8I32	(1 << 26)
#define	HWCAP2_SME_F16F32	(1 << 27)
#define	HWCAP2_SME_B16F32	(1 << 28)
#define	HWCAP2_SME_F32F32	(1 << 29)
#define	HWCAP2_SME_FA64		(1 << 30)
#define	HWCAP2_WFXT		(1UL << 31)
#define	HWCAP2_EBF16		(1UL << 32)
#define	HWCAP2_SVE_EBF16	(1UL << 33)
#define	HWCAP2_CSSC		(1UL << 34)
#define	HWCAP2_RPRFM		(1UL << 35)
#define	HWCAP2_SVE2P1		(1UL << 36)
#define	HWCAP2_SME2		(1UL << 37)
#define	HWCAP2_SME2P1		(1UL << 38)
#define	HWCAP2_SME_I16I32	(1UL << 39)
#define	HWCAP2_SME_BI32I32	(1UL << 40)
#define	HWCAP2_SME_B16B16	(1UL << 41)
#define	HWCAP2_SME_F16F16	(1UL << 42)
#define	HWCAP2_MOPS		(1UL << 43)
#define	HWCAP2_HBC		(1UL << 44)
#define	HWCAP2_SVE_B16B16	(1UL << 45)
#define	HWCAP2_LRCPC3		(1UL << 46)
#define	HWCAP2_LSE128		(1UL << 47)
#define	HWCAP2_FPMR		(1UL << 48)
#define	HWCAP2_LUT		(1UL << 49)
#define	HWCAP2_FAMINMAX		(1UL << 50)
#define	HWCAP2_F8CVT		(1UL << 51)
#define	HWCAP2_F8FMA		(1UL << 52)
#define	HWCAP2_F8DP4		(1UL << 53)
#define	HWCAP2_F8DP2		(1UL << 54)
#define	HWCAP2_F8E4M3		(1UL << 55)
#define	HWCAP2_F8E5M2		(1UL << 56)
#define	HWCAP2_SME_LUTV2	(1UL << 57)
#define	HWCAP2_SME_F8F16	(1UL << 58)
#define	HWCAP2_SME_F8F32	(1UL << 59)
#define	HWCAP2_SME_SF8FMA	(1UL << 60)
#define	HWCAP2_SME_SF8DP4	(1UL << 61)
#define	HWCAP2_SME_SF8DP2	(1UL << 62)
#define	HWCAP2_POE		(1UL << 63)

#ifdef COMPAT_FREEBSD32
/* ARM HWCAP */
#define	HWCAP32_HALF		0x00000002	/* Always set.               */
#define	HWCAP32_THUMB		0x00000004	/* Always set.               */
#define	HWCAP32_FAST_MULT	0x00000010	/* Always set.               */
#define	HWCAP32_VFP		0x00000040
#define	HWCAP32_EDSP		0x00000080	/* Always set.               */
#define	HWCAP32_NEON		0x00001000
#define	HWCAP32_VFPv3		0x00002000
#define	HWCAP32_TLS		0x00008000	/* Always set.               */
#define	HWCAP32_VFPv4		0x00010000
#define	HWCAP32_IDIVA		0x00020000	/* Always set.               */
#define	HWCAP32_IDIVT		0x00040000	/* Always set.               */
#define	HWCAP32_VFPD32		0x00080000	/* Always set.               */
#define	HWCAP32_LPAE		0x00100000	/* Always set.               */

#define HWCAP32_DEFAULT \
   (HWCAP32_HALF | HWCAP32_THUMB | HWCAP32_FAST_MULT | HWCAP32_EDSP |\
    HWCAP32_TLS | HWCAP32_IDIVA | HWCAP32_IDIVT | HWCAP32_VFPD32 |   \
    HWCAP32_LPAE)

/* ARM HWCAP2 */
#define	HWCAP32_2_AES		0x00000001
#define	HWCAP32_2_PMULL		0x00000002
#define	HWCAP32_2_SHA1		0x00000004
#define	HWCAP32_2_SHA2		0x00000008
#define	HWCAP32_2_CRC32		0x00000010
#endif

#endif /* !_MACHINE_ELF_H_ */

#endif /* !__arm__ */