/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2001 David E. O'Brien
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

#ifndef _MACHINE_ELF_H_
#define	_MACHINE_ELF_H_ 1

/*
 * EABI ELF definitions for the PowerPC architecture.
 * See "PowerPC Embedded Application Binary Interface, 32-Bit Impliementation"
 * [ppc-eabi-1995-01.pdf] for details.
 */

#ifndef __ELF_WORD_SIZE
#ifdef __powerpc64__
#define	__ELF_WORD_SIZE	64	/* Used by <sys/elf_generic.h> */
#else
#define	__ELF_WORD_SIZE	32	/* Used by <sys/elf_generic.h> */
#endif
#endif

#include <sys/elf32.h>	/* Definitions common to all 32 bit architectures. */
#include <sys/elf64.h>	/* Definitions common to all 64 bit architectures. */
#include <sys/elf_generic.h>

#if __ELF_WORD_SIZE == 64
#define	ELF_ARCH	EM_PPC64
#define	ELF_MACHINE_OK(x) ((x) == EM_PPC64)
#else
#define	ELF_ARCH	EM_PPC
#define	ELF_ARCH32	EM_PPC
#define	ELF_MACHINE_OK(x) ((x) == EM_PPC)
#endif

/*
 * Auxiliary vector entries for passing information to the interpreter.
 *
 * The PowerPC supplement to the SVR4 ABI specification names this "auxv_t",
 * but POSIX lays claim to all symbols ending with "_t".
 */

typedef struct {	/* Auxiliary vector entry on initial stack */
	int	a_type;			/* Entry type. */
	union {
#ifdef __powerpc64__
		int	a_val;		/* Integer value */
#else
		long	a_val;		/* Integer value. */
		void	*a_ptr;		/* Address. */
		void	(*a_fcn)(void);	/* Function pointer (not used). */
#endif
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

/*
 * Relocation types.
 */

#define	R_PPC_COUNT		37	/* Count of defined relocation types. */

					/* Count of defined relocation types. */
#define	R_PPC_EMB_COUNT		(R_PPC_EMB_RELSDA - R_PPC_EMB_NADDR32 + 1)

/* Define "machine" characteristics */
#if BYTE_ORDER == LITTLE_ENDIAN
#define	ELF_TARG_DATA	ELFDATA2LSB
#else
#define	ELF_TARG_DATA	ELFDATA2MSB
#endif
#if __ELF_WORD_SIZE == 64
#define	ELF_TARG_CLASS	ELFCLASS64
#define	ELF_TARG_MACH	EM_PPC64
#define	ELF_TARG_VER	1
#else
#define	ELF_TARG_CLASS	ELFCLASS32
#define	ELF_TARG_MACH	EM_PPC
#define	ELF_TARG_VER	1
#endif

#define	ET_DYN_LOAD_ADDR 0x01010000

#define	AT_OLD_NULL		AT_NULL
#define	AT_OLD_IGNORE		AT_IGNORE
#define	AT_OLD_EXECFD		AT_EXECFD
#define	AT_OLD_PHDR		AT_PHDR
#define	AT_OLD_PHENT		AT_PHENT
#define	AT_OLD_PHNUM		AT_PHNUM
#define	AT_OLD_PAGESZ		AT_PAGESZ
#define	AT_OLD_BASE		AT_BASE
#define	AT_OLD_FLAGS		AT_FLAGS
#define	AT_OLD_ENTRY		AT_ENTRY
#define	AT_OLD_NOTELF		AT_NOTELF
#define	AT_OLD_UID		AT_UID
#define	AT_OLD_EUID		AT_EUID
#define	AT_OLD_EXECPATH		13
#define	AT_OLD_CANARY		14
#define	AT_OLD_CANARYLEN	15
#define	AT_OLD_OSRELDATE	16
#define	AT_OLD_NCPUS		17
#define	AT_OLD_PAGESIZES	18
#define	AT_OLD_PAGESIZESLEN	19
#define	AT_OLD_STACKPROT	21
#define	AT_OLD_TIMEKEEP		AT_TIMEKEEP
#define	AT_OLD_EHDRFLAGS	AT_EHDRFLAGS
#define	AT_OLD_HWCAP		AT_HWCAP
#define	AT_OLD_HWCAP2		AT_HWCAP2

#define	AT_OLD_COUNT	27	/* Count of defined aux entry types. */

#endif /* !_MACHINE_ELF_H_ */