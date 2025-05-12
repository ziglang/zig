/*	$NetBSD: elf_machdep.h,v 1.20 2017/11/06 19:17:43 christos Exp $	*/

/*-
 * Copyright (c) 2013 The NetBSD Foundation, Inc.
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
#ifndef _MIPS_ELF_MACHDEP_H_
#define	_MIPS_ELF_MACHDEP_H_

#ifdef _LP64
#define	KERN_ELFSIZE		64
#define	ARCH_ELFSIZE		64	/* MD native binary size */
#else
#define	KERN_ELFSIZE		32
#define	ARCH_ELFSIZE		32	/* MD native binary size */
#endif

#if ELFSIZE == 32
#define	ELF32_MACHDEP_ID_CASES						\
		case EM_MIPS:						\
			break;

#define	ELF32_MACHDEP_ID	EM_MIPS
#elif ELFSIZE == 64
#define	ELF64_MACHDEP_ID_CASES						\
		case EM_MIPS:						\
			break;

#define	ELF64_MACHDEP_ID	EM_MIPS
#endif

/* mips relocs. */

#define	R_MIPS_NONE		0
#define	R_MIPS_16		1
#define	R_MIPS_32		2
#define	R_MIPS_REL32		3
#define	R_MIPS_REL		R_MIPS_REL32
#define	R_MIPS_26		4
#define	R_MIPS_HI16		5	/* high 16 bits of symbol value */
#define	R_MIPS_LO16		6	/* low 16 bits of symbol value */
#define	R_MIPS_GPREL16		7	/* GP-relative reference  */
#define	R_MIPS_LITERAL		8	/* Reference to literal section  */
#define	R_MIPS_GOT16		9	/* Reference to global offset table */
#define	R_MIPS_GOT		R_MIPS_GOT16
#define	R_MIPS_PC16		10	/* 16 bit PC relative reference */
#define	R_MIPS_CALL16 		11	/* 16 bit call thru glbl offset tbl */
#define	R_MIPS_CALL		R_MIPS_CALL16
#define	R_MIPS_GPREL32		12

/* 13, 14, 15 are not defined at this point. */
#define	R_MIPS_UNUSED1		13
#define	R_MIPS_UNUSED2		14
#define	R_MIPS_UNUSED3		15

/*
 * The remaining relocs are apparently part of the 64-bit Irix ELF ABI.
 */
#define	R_MIPS_SHIFT5		16
#define	R_MIPS_SHIFT6		17

#define	R_MIPS_64		18
#define	R_MIPS_GOT_DISP		19
#define	R_MIPS_GOT_PAGE		20
#define	R_MIPS_GOT_OFST		21
#define	R_MIPS_GOT_HI16		22
#define	R_MIPS_GOT_LO16		23
#define	R_MIPS_SUB		24
#define	R_MIPS_INSERT_A		25
#define	R_MIPS_INSERT_B		26
#define	R_MIPS_DELETE		27
#define	R_MIPS_HIGHER		28
#define	R_MIPS_HIGHEST		29
#define	R_MIPS_CALL_HI16	30
#define	R_MIPS_CALL_LO16	31
#define	R_MIPS_SCN_DISP		32
#define	R_MIPS_REL16		33
#define	R_MIPS_ADD_IMMEDIATE	34
#define	R_MIPS_PJUMP		35
#define	R_MIPS_RELGOT		36
#define	R_MIPS_JALR		37
/* TLS relocations */

#define	R_MIPS_TLS_DTPMOD32	38	/* Module number 32 bit */
#define	R_MIPS_TLS_DTPREL32	39	/* Module-relative offset 32 bit */
#define	R_MIPS_TLS_DTPMOD64	40	/* Module number 64 bit */
#define	R_MIPS_TLS_DTPREL64	41	/* Module-relative offset 64 bit */
#define	R_MIPS_TLS_GD		42	/* 16 bit GOT offset for GD */
#define	R_MIPS_TLS_LDM		43	/* 16 bit GOT offset for LDM */
#define	R_MIPS_TLS_DTPREL_HI16	44	/* Module-relative offset, high 16 bits */
#define	R_MIPS_TLS_DTPREL_LO16	45	/* Module-relative offset, low 16 bits */
#define	R_MIPS_TLS_GOTTPREL	46	/* 16 bit GOT offset for IE */
#define	R_MIPS_TLS_TPREL32	47	/* TP-relative offset, 32 bit */
#define	R_MIPS_TLS_TPREL64	48	/* TP-relative offset, 64 bit */
#define	R_MIPS_TLS_TPREL_HI16	49	/* TP-relative offset, high 16 bits */
#define	R_MIPS_TLS_TPREL_LO16	50	/* TP-relative offset, low 16 bits */

#define	R_MIPS_max		51

#define	R_TYPE(name)		__CONCAT(R_MIPS_,name)

#define	R_MIPS16_min		100
#define	R_MIPS16_26		100
#define	R_MIPS16_GPREL		101
#define	R_MIPS16_GOT16		102
#define	R_MIPS16_CALL16		103
#define	R_MIPS16_HI16		104
#define	R_MIPS16_LO16		105
#define	R_MIPS16_max		106

#define	R_MIPS_COPY		126
#define	R_MIPS_JUMP_SLOT	127

/* mips dynamic tags */

#define	DT_MIPS_RLD_VERSION	0x70000001
#define	DT_MIPS_TIME_STAMP	0x70000002
#define	DT_MIPS_ICHECKSUM	0x70000003
#define	DT_MIPS_IVERSION	0x70000004
#define	DT_MIPS_FLAGS		0x70000005
#define	DT_MIPS_BASE_ADDRESS	0x70000006
#define	DT_MIPS_CONFLICT	0x70000008
#define	DT_MIPS_LIBLIST		0x70000009
#define	DT_MIPS_CONFLICTNO	0x7000000b
#define	DT_MIPS_LOCAL_GOTNO	0x7000000a	/* number of local got ents */
#define	DT_MIPS_LIBLISTNO	0x70000010
#define	DT_MIPS_SYMTABNO	0x70000011	/* number of .dynsym entries */
#define	DT_MIPS_UNREFEXTNO	0x70000012
#define	DT_MIPS_GOTSYM		0x70000013	/* first dynamic sym in got */
#define	DT_MIPS_HIPAGENO	0x70000014
#define	DT_MIPS_RLD_MAP		0x70000016	/* address of loader map */
#define	DT_MIPS_PLTGOT		0x70000032
#define	DT_MIPS_RWPLT		0x70000034

/*
 * ELF Flags
 */
#define	EF_MIPS_PIC		0x00000002	/* Contains PIC code */
#define	EF_MIPS_CPIC		0x00000004	/* STD PIC calling sequence */
#define	EF_MIPS_ABI2		0x00000020	/* N32 */

#define	EF_MIPS_ARCH_ASE	0x0f000000	/* Architectural extensions */
#define	EF_MIPS_ARCH_MDMX	0x08000000	/* MDMX multimedia extension */
#define	EF_MIPS_ARCH_M16	0x04000000	/* MIPS-16 ISA extensions */

#define	EF_MIPS_ARCH		0xf0000000	/* Architecture field */
#define	EF_MIPS_ARCH_1		0x00000000	/* -mips1 code */
#define	EF_MIPS_ARCH_2		0x10000000	/* -mips2 code */
#define	EF_MIPS_ARCH_3		0x20000000	/* -mips3 code */
#define	EF_MIPS_ARCH_4		0x30000000	/* -mips4 code */
#define	EF_MIPS_ARCH_5		0x40000000	/* -mips5 code */
#define	EF_MIPS_ARCH_32		0x50000000	/* -mips32 code */
#define	EF_MIPS_ARCH_64		0x60000000	/* -mips64 code */
#define	EF_MIPS_ARCH_32R2	0x70000000	/* -mips32r2 code */
#define	EF_MIPS_ARCH_64R2	0x80000000	/* -mips64r2 code */

#define	EF_MIPS_ABI		0x0000f000
#define	EF_MIPS_ABI_O32		0x00001000
#define	EF_MIPS_ABI_O64		0x00002000
#define	EF_MIPS_ABI_EABI32	0x00003000
#define	EF_MIPS_ABI_EABI64	0x00004000

#if defined(__MIPSEB__)
#define	ELF32_MACHDEP_ENDIANNESS	ELFDATA2MSB
#define	ELF64_MACHDEP_ENDIANNESS	ELFDATA2MSB
#elif defined(__MIPSEL__)
#define	ELF32_MACHDEP_ENDIANNESS	ELFDATA2LSB
#define	ELF64_MACHDEP_ENDIANNESS	ELFDATA2LSB
#elif !defined(HAVE_NBTOOL_CONFIG_H)
#error neither __MIPSEL__ nor __MIPSEB__ are defined.
#endif

#ifdef _KERNEL
#ifdef _KERNEL_OPT
#include "opt_compat_netbsd.h"
#endif
#ifdef COMPAT_16
/*
 * Up to 1.6, the ELF dynamic loader (ld.elf_so) was not relocatable.
 * Tell the kernel ELF exec code not to try relocating the interpreter
 * for dynamically-linked ELF binaries.
 */
#define	ELF_INTERP_NON_RELOCATABLE
#endif /* COMPAT_16 */

/*
 * We need to be able to include the ELF header so we can pick out the
 * ABI being used.
 */
#ifdef ELFSIZE
#define	ELF_MD_PROBE_FUNC	ELFNAME2(mips_netbsd,probe)
#define	ELF_MD_COREDUMP_SETUP	ELFNAME2(coredump,setup)
#endif

struct exec_package;

int mips_netbsd_elf32_probe(struct lwp *, struct exec_package *, void *, char *,
	vaddr_t *);
void coredump_elf32_setup(struct lwp *, void *);

int mips_netbsd_elf64_probe(struct lwp *, struct exec_package *, void *, char *,
	vaddr_t *);
void coredump_elf64_setup(struct lwp *, void *);
#endif /* _KERNEL */

#endif /* _MIPS_ELF_MACHDEP_H_ */