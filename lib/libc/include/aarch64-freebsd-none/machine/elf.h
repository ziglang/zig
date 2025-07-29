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

/* HWCAP */
#define	HWCAP_FP		0x00000001
#define	HWCAP_ASIMD		0x00000002
#define	HWCAP_EVTSTRM		0x00000004
#define	HWCAP_AES		0x00000008
#define	HWCAP_PMULL		0x00000010
#define	HWCAP_SHA1		0x00000020
#define	HWCAP_SHA2		0x00000040
#define	HWCAP_CRC32		0x00000080
#define	HWCAP_ATOMICS		0x00000100
#define	HWCAP_FPHP		0x00000200
#define	HWCAP_ASIMDHP		0x00000400
/*
 * XXX: The following bits (from CPUID to FLAGM) were originally incorrect,
 * but later changed to match the Linux definitions. No compatibility code is
 * provided, as the fix was expected to result in near-zero fallout.
 */
#define	HWCAP_CPUID		0x00000800
#define	HWCAP_ASIMDRDM		0x00001000
#define	HWCAP_JSCVT		0x00002000
#define	HWCAP_FCMA		0x00004000
#define	HWCAP_LRCPC		0x00008000
#define	HWCAP_DCPOP		0x00010000
#define	HWCAP_SHA3		0x00020000
#define	HWCAP_SM3		0x00040000
#define	HWCAP_SM4		0x00080000
#define	HWCAP_ASIMDDP		0x00100000
#define	HWCAP_SHA512		0x00200000
#define	HWCAP_SVE		0x00400000
#define	HWCAP_ASIMDFHM		0x00800000
#define	HWCAP_DIT		0x01000000
#define	HWCAP_USCAT		0x02000000
#define	HWCAP_ILRCPC		0x04000000
#define	HWCAP_FLAGM		0x08000000
#define	HWCAP_SSBS		0x10000000
#define	HWCAP_SB		0x20000000
#define	HWCAP_PACA		0x40000000
#define	HWCAP_PACG		0x80000000

/* HWCAP2 */
#define	HWCAP2_DCPODP		0x0000000000000001ul
#define	HWCAP2_SVE2		0x0000000000000002ul
#define	HWCAP2_SVEAES		0x0000000000000004ul
#define	HWCAP2_SVEPMULL		0x0000000000000008ul
#define	HWCAP2_SVEBITPERM	0x0000000000000010ul
#define	HWCAP2_SVESHA3		0x0000000000000020ul
#define	HWCAP2_SVESM4		0x0000000000000040ul
#define	HWCAP2_FLAGM2		0x0000000000000080ul
#define	HWCAP2_FRINT		0x0000000000000100ul
#define	HWCAP2_SVEI8MM		0x0000000000000200ul
#define	HWCAP2_SVEF32MM		0x0000000000000400ul
#define	HWCAP2_SVEF64MM		0x0000000000000800ul
#define	HWCAP2_SVEBF16		0x0000000000001000ul
#define	HWCAP2_I8MM		0x0000000000002000ul
#define	HWCAP2_BF16		0x0000000000004000ul
#define	HWCAP2_DGH		0x0000000000008000ul
#define	HWCAP2_RNG		0x0000000000010000ul
#define	HWCAP2_BTI		0x0000000000020000ul
#define	HWCAP2_MTE		0x0000000000040000ul
#define	HWCAP2_ECV		0x0000000000080000ul
#define	HWCAP2_AFP		0x0000000000100000ul
#define	HWCAP2_RPRES		0x0000000000200000ul
#define	HWCAP2_MTE3		0x0000000000400000ul
#define	HWCAP2_SME		0x0000000000800000ul
#define	HWCAP2_SME_I16I64	0x0000000001000000ul
#define	HWCAP2_SME_F64F64	0x0000000002000000ul
#define	HWCAP2_SME_I8I32	0x0000000004000000ul
#define	HWCAP2_SME_F16F32	0x0000000008000000ul
#define	HWCAP2_SME_B16F32	0x0000000010000000ul
#define	HWCAP2_SME_F32F32	0x0000000020000000ul
#define	HWCAP2_SME_FA64		0x0000000040000000ul
#define	HWCAP2_WFXT		0x0000000080000000ul
#define	HWCAP2_EBF16		0x0000000100000000ul
#define	HWCAP2_SVE_EBF16	0x0000000200000000ul
#define	HWCAP2_CSSC		0x0000000400000000ul
#define	HWCAP2_RPRFM		0x0000000800000000ul
#define	HWCAP2_SVE2P1		0x0000001000000000ul
#define	HWCAP2_SME2		0x0000002000000000ul
#define	HWCAP2_SME2P1		0x0000004000000000ul
#define	HWCAP2_SME_I16I32	0x0000008000000000ul
#define	HWCAP2_SME_BI32I32	0x0000010000000000ul
#define	HWCAP2_SME_B16B16	0x0000020000000000ul
#define	HWCAP2_SME_F16F16	0x0000040000000000ul
#define	HWCAP2_MOPS		0x0000080000000000ul
#define	HWCAP2_HBC		0x0000100000000000ul

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