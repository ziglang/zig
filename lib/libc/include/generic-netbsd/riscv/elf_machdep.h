/* $NetBSD: elf_machdep.h,v 1.9 2022/12/03 08:54:38 skrll Exp $ */

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

#ifndef _RISCV_ELF_MACHDEP_H_
#define _RISCV_ELF_MACHDEP_H_

#define	ELF32_MACHDEP_ID		EM_RISCV
#define	ELF64_MACHDEP_ID		EM_RISCV

#define ELF32_MACHDEP_ENDIANNESS	ELFDATA2LSB
#define ELF64_MACHDEP_ENDIANNESS	ELFDATA2LSB

#define ELF32_MACHDEP_ID_CASES		\
		case EM_RISCV:		\
			break;

#define	ELF64_MACHDEP_ID_CASES		\
		case EM_RISCV:		\
			break;

#ifdef _LP64
#define	KERN_ELFSIZE		64
#define ARCH_ELFSIZE		64	/* MD native binary size */
#else
#define	KERN_ELFSIZE		32
#define ARCH_ELFSIZE		32	/* MD native binary size */
#endif

/* Processor specific flags for the ELF header e_flags field.  */

/* Processor specific relocation types */

#define R_RISCV_NONE		0
#define R_RISCV_32		1	// A
#define R_RISCV_64		2
#define R_RISCV_RELATIVE	3
#define R_RISCV_COPY		4
#define R_RISCV_JMP_SLOT	5
#define R_RISCV_TLS_DTPMOD32	6
#define R_RISCV_TLS_DTPMOD64	7
#define R_RISCV_TLS_DTPREL32	8
#define R_RISCV_TLS_DTPREL64	9
#define R_RISCV_TLS_TPREL32	10
#define R_RISCV_TLS_TPREL64	11

/* The rest are not used by the dynamic linker */
#define R_RISCV_BRANCH		16	// (A - P) & 0xffff
#define R_RISCV_JAL		17	// A & 0xff
#define R_RISCV_CALL		18	// (A - P) & 0xff
#define R_RISCV_CALL_PLT	19
#define R_RISCV_GOT_HI20	20
#define R_RISCV_TLS_GOT_HI20	21
#define R_RISCV_TLS_GD_HI20	22
#define R_RISCV_PCREL_HI20	23
#define R_RISCV_PCREL_LO12_I	24
#define R_RISCV_PCREL_LO12_S	25
#define R_RISCV_HI20		26	// A & 0xffff
#define R_RISCV_LO12_I		27	// (A >> 16) & 0xffff
#define R_RISCV_LO12_S		28	// (S + A - P) >> 2
#define R_RISCV_TPREL_HI20	29
#define R_RISCV_TPREL_LO12_I	30
#define R_RISCV_TPREL_LO12_S	31
#define R_RISCV_TPREL_ADD	32
#define R_RISCV_ADD8		33
#define R_RISCV_ADD16		34
#define R_RISCV_ADD32		35
#define R_RISCV_ADD64		36
#define R_RISCV_SUB8		37
#define R_RISCV_SUB16		38
#define R_RISCV_SUB32		39
#define R_RISCV_SUB64		40
#define R_RISCV_GNU_VTINHERIT	41	// A & 0xffff
#define R_RISCV_GNU_VTENTRY	42
#define R_RISCV_ALIGN		43
#define R_RISCV_RVC_BRANCH	44
#define R_RISCV_RVC_JUMP	45
#define R_RISCV_RVC_LUI		46
#define R_RISCV_GPREL_I		47
#define R_RISCV_GPREL_S		48
#define R_RISCV_TPREL_I		49
#define R_RISCV_TPREL_S		50
#define R_RISCV_RELAX		51
#define R_RISCV_SUB6		52
#define R_RISCV_SET6		53
#define R_RISCV_SET8		54
#define R_RISCV_SET16		55
#define R_RISCV_SET32		56
#define R_RISCV_32_PCREL	57

/* These are aliases we can use R_TYPESZ */
#define R_RISCV_ADDR32		R_RISCV_32
#define R_RISCV_ADDR64		R_RISCV_64

#define R_TYPE(name)		R_RISCV_ ## name
#if ELFSIZE == 32
#define R_TYPESZ(name)		R_RISCV_ ## name ## 32
#else
#define R_TYPESZ(name)		R_RISCV_ ## name ## 64
#endif

#ifdef _KERNEL
#ifdef ELFSIZE
#define ELF_MD_PROBE_FUNC       ELFNAME2(cpu_netbsd,probe)
#endif

struct exec_package;

int cpu_netbsd_elf32_probe(struct lwp *, struct exec_package *, void *, char *,
        vaddr_t *);

int cpu_netbsd_elf64_probe(struct lwp *, struct exec_package *, void *, char *,
        vaddr_t *);

#endif /* _KERNEL */

#endif /* _RISCV_ELF_MACHDEP_H_ */