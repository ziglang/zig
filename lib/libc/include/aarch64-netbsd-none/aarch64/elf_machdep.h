/* $NetBSD: elf_machdep.h,v 1.5 2022/05/30 21:18:37 jkoshy Exp $ */

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

#ifndef _AARCH64_ELF_MACHDEP_H_
#define _AARCH64_ELF_MACHDEP_H_

#ifdef __aarch64__

#if defined(__AARCH64EB__)
#define ELF64_MACHDEP_ENDIANNESS	ELFDATA2MSB
#define ELF32_MACHDEP_ENDIANNESS	ELFDATA2MSB
#else
#define ELF64_MACHDEP_ENDIANNESS	ELFDATA2LSB
#define ELF32_MACHDEP_ENDIANNESS	ELFDATA2LSB
#endif

/* Processor specific flags for the ELF header e_flags field.  */
#define EF_ARM_RELEXEC		0x00000001
#define EF_ARM_HASENTRY		0x00000002
#define EF_ARM_INTERWORK	0x00000004 /* GNU binutils 000413 */
#define EF_ARM_SYMSARESORTED	0x00000004 /* ARM ELF A08 */
#define EF_ARM_APCS_26		0x00000008 /* GNU binutils 000413 */
#define EF_ARM_DYNSYMSUSESEGIDX	0x00000008 /* ARM ELF B01 */
#define EF_ARM_APCS_FLOAT	0x00000010 /* GNU binutils 000413 */
#define EF_ARM_MAPSYMSFIRST	0x00000010 /* ARM ELF B01 */
#define EF_ARM_PIC		0x00000020
#define EF_ARM_ALIGN8		0x00000040 /* 8-bit structure alignment.  */
#define EF_ARM_NEW_ABI		0x00000080
#define EF_ARM_OLD_ABI		0x00000100
#define EF_ARM_SOFT_FLOAT	0x00000200
#define EF_ARM_BE8		0x00800000
#define EF_ARM_EABIMASK		0xff000000
#define	EF_ARM_EABI_VER1	0x01000000
#define	EF_ARM_EABI_VER2	0x02000000
#define	EF_ARM_EABI_VER3	0x03000000
#define	EF_ARM_EABI_VER4	0x04000000
#define	EF_ARM_EABI_VER5	0x05000000

#define ELF32_MACHDEP_ID_CASES						\
		case EM_ARM:						\
			break;

#define	ELF64_MACHDEP_ID_CASES						\
		case EM_AARCH64:					\
			break;

#define	ELF64_MACHDEP_ID	EM_AARCH64
#define ELF32_MACHDEP_ID	EM_ARM

#define	KERN_ELFSIZE		64
#define ARCH_ELFSIZE		64	/* MD native binary size */

/* Processor specific relocation types */

#define R_AARCH64_NONE			0
#define R_AARCH64_NONE2			256

#define	R_AARCH64_ABS64			257	/* S + A */
#define	R_AARCH64_ABS32			258	/* S + A */
#define	R_AARCH64_ABS16			259	/* S + A */
#define	R_AARCH64_PREL64		260	/* S + A - P */
#define	R_AARCH64_PREL32		261	/* S + A - P */
#define	R_AARCH64_PREL16		262	/* S + A - P */
#define R_AARCH64_MOVW_UABS_G0		263	/* S + A [bits 0..15] */
#define R_AARCH64_MOVW_UABS_G0_NC	264	/* S + A [bits 0..15] */
#define R_AARCH64_MOVW_UABS_G1		265	/* S + A [bits 16..31] */
#define R_AARCH64_MOVW_UABS_G1_NC	266	/* S + A [bits 16..31] */
#define R_AARCH64_MOVW_UABS_G2		267	/* S + A [bits 32..47] */
#define R_AARCH64_MOVW_UABS_G2_NC	268	/* S + A [bits 32..47] */
#define R_AARCH64_MOVW_UABS_G3		269	/* S + A [bits 48..63] */
#define R_AARCH64_MOVW_SABS_G0		270	/* S + A [bits 0..15] */
#define R_AARCH64_MOVW_SABS_G1		271	/* S + A [bits 16..31] */
#define R_AARCH64_MOVW_SABS_G2		272	/* S + A [bits 32..47] */
#define	R_AARCH64_LD_PREL_LO19		273	/* S + A - P */
#define	R_AARCH64_ADR_PREL_LO21		274	/* S + A - P */
#define	R_AARCH64_ADR_PREL_PG_HI21	275	/* Page(S + A) - Page(P) */
#define	R_AARCH64_ADR_PREL_PG_HI21_NC	276	/* Page(S + A) - Page(P) */
#define R_AARCH64_ADD_ABS_LO12_NC	277	/* S + A */
#define	R_AARCH64_LDST8_ABS_LO12_NC	278	/* S + A */
#define R_AARCH_TSTBR14			279	/* S + A - P */
#define R_AARCH_CONDBR19		281	/* S + A - P */
#define R_AARCH_JUMP26			282	/* S + A - P */
#define R_AARCH_CALL26			283	/* S + A - P */
#define R_AARCH_LDST16_ABS_LO12_NC	284	/* S + A */
#define R_AARCH_LDST32_ABS_LO12_NC	285	/* S + A */
#define R_AARCH_LDST64_ABS_LO12_NC	286	/* S + A */
#define R_AARCH64_MOVW_PREL_G0		287	/* S + A - P */
#define R_AARCH64_MOVW_PREL_G0_NC	288	/* S + A - P */
#define R_AARCH64_MOVW_PREL_G1		289	/* S + A - P */
#define R_AARCH64_MOVW_PREL_G1_NC	290	/* S + A - P */
#define R_AARCH64_MOVW_PREL_G2		291	/* S + A - P */
#define R_AARCH64_MOVW_PREL_G2_NC	292	/* S + A - P */
#define R_AARCH64_MOVW_PREL_G3		293	/* S + A - P */

#define R_AARCH64_LDST128_ABS_LO12_NC	299	/* S + A */
#define R_AARCH64_MOVW_GOTOFF_G0	300	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_MOVW_GOTOFF_G0_NC	301	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_MOVW_GOTOFF_G1	302	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_MOVW_GOTOFF_G1_NC	303	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_MOVW_GOTOFF_G2	304	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_MOVW_GOTOFF_G2_NC	305	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_MOVW_GOTOFF_G3	306	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_GOTREL64		307	/* S + A - GOT */
#define R_AARCH64_GOTREL32		308	/* S + A - GOT */
#define R_AARCH64_GOT_LD_PREL19		309	/* G(GDAT(S + A)) - P */
#define R_AARCH64_LD64_GOTOFF_LO15	310	/* G(GDAT(S + A)) - GOT */
#define R_AARCH64_ADR_GOT_PAGE		311	/* Page(G(GDAT(S + A))) - Page(GOT) */
#define R_AARCH64_LD64_GOT_LO12_NC	312	/* G(GDAT(S + A)) */
#define R_AARCH64_LD64_GOTPAGE_LO15	313	/* G(GDAT(S + A)) - Page(GOT) */

#define R_AARCH64_TLSGD_ADR_PREL21		512	/* G(GTLSIDX(S,A)) - P */
#define R_AARCH64_TLSGD_ADR_PAGE21		513	/* Page(G(GTLSIDX(S,A))) - Page(P) */
#define R_AARCH64_TLSGD_ADD_LO12_NC		514	/* G(GTLSIDX(S,A)) */
#define R_AARCH64_TLSGD_MOVW_G1			515	/* G(GTLSIDX(S,A)) - GOT */
#define R_AARCH64_TLSGD_MOVW_G0_NV		516	/* G(GTLSIDX(S,A)) - GOT */
#define R_AARCH64_TLSLD_ADR_PREL21		517	/* G(GLDM(S,A)) - P */
#define R_AARCH64_TLSLD_ADR_PAGE21		518	/* Page(G(GLDM(S))) - Page(P) */
#define R_AARCH64_TLSLD_ADD_LO12_NC		519	/* G(GLDM(S)) */
#define R_AARCH64_TLSLD_MOVW_G1			520	/* G(GLDM(S)) - GOT */
#define R_AARCH64_TLSLD_MOVW_G0_NC		521	/* G(GLDM(S)) - GOT */
#define R_AARCH64_TLSLD_LD_PREL21		522	/* G(GLDM(S)) - P */
#define R_AARCH64_TLSLD_MOVW_DTPREL_G2		523	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_MOVW_DTPREL_G1		524	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_MOVW_DTPREL_G1_NC	525	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_MOVW_DTPREL_G0		526	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_MOVW_DTPREL_G0_NC	528	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_ADD_DTPREL_HI12		528	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_ADD_DTPREL_HI12		528	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_ADD_DTPREL_LO12		529	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_ADD_DTPREL_LO12_NC	530	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST8_DTPREL_LO12	531	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST8_DTPREL_LO12_NC	532	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST16_DTPREL_LO12	533	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST16_DTPREL_LO12_NC	534	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST32_DTPREL_LO12	535	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST32_DTPREL_LO12_NC	536	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST64_DTPREL_LO12	537	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST64_DTPREL_LO12_NC	538	/* DTPREL(S+A) */
#define R_AARCH64_TLSIE_MOVW_GOTTPREL_G1	539	/* G(GTPREL(S+A)) - GOT */
#define R_AARCH64_TLSIE_MOVW_GOTTPREL_G0_NC	540	/* G(GTPREL(S+A)) - GOT */
#define R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21	541	/* Page(G(GTPREL(S+A))) - Page(P) */
#define R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC	542	/* G(GTPREL(S+A)) */
#define R_AARCH64_TLSIE_LD_GOTTPREL_PREL19	543	/* G(GTPREL(S+A)) - P */
#define R_AARCH64_TLSLE_MOVW_TPREL_G2	544	/* TPREL(S+A) */
#define R_AARCH64_MOVW_TPREL_G1		545	/* TPREL(S+A) */
#define R_AARCH64_MOVW_TPREL_G1_NC	546	/* TPREL(S+A) */
#define R_AARCH64_MOVW_TPREL_G0		547	/* TPREL(S+A) */
#define R_AARCH64_MOVW_TPREL_G0_NC	548	/* TPREL(S+A) */
#define R_AARCH64_ADD_TPREL_HI12	549	/* TPREL(S+A) */
#define R_AARCH64_ADD_TPREL_LO12	550	/* TPREL(S+A) */
#define R_AARCH64_ADD_TPREL_LO12_NC	551	/* TPREL(S+A) */
#define R_AARCH64_LDST8_TPREL_LO12	552	/* TPREL(S+A) */
#define R_AARCH64_LDST8_TPREL_LO12_NC	553	/* TPREL(S+A) */
#define R_AARCH64_LDST16_TPREL_LO12	554	/* TPREL(S+A) */
#define R_AARCH64_LDST16_TPREL_LO12_NC	555	/* TPREL(S+A) */
#define R_AARCH64_LDST32_TPREL_LO12	556	/* TPREL(S+A) */
#define R_AARCH64_LDST32_TPREL_LO12_NC	557	/* TPREL(S+A) */
#define R_AARCH64_LDST64_TPREL_LO12	558	/* TPREL(S+A) */
#define R_AARCH64_LDST64_TPREL_LO12_NC	559	/* TPREL(S+A) */
#define R_AARCH64_TLSDESC_LD_PREL19	560	/* G(GTLSDESC(S+A)) - P */
#define R_AARCH64_TLSDESC_LD_PREL21	561	/* G(GTLSDESC(S+A)) - P */
#define R_AARCH64_TLSDESC_LD_PAGE21	562	/* Page(G(GTLSDESC(S+A))) - Page(P) */
#define R_AARCH64_TLSDESC_LD64_LO12	563	/* G(GTLSDESC(S+A)) */
#define R_AARCH64_TLSDESC_ADD_LO12	564	/* G(GTLSDESC(S+A)) */
#define R_AARCH64_TLSDESC_OFF_G1	565	/* G(GTLSDESC(S+A)) - GOT */
#define R_AARCH64_TLSDESC_OFF_G0_NC	566	/* G(GTLSDESC(S+A)) - GOT */
#define R_AARCH64_TLSDESC_LDR		567	/* */
#define R_AARCH64_TLSDESC_ADD		568	/* */
#define R_AARCH64_TLSDESC_CALL		569	/* */
#define R_AARCH64_TLSLE_LDST128_TPREL_LO12	570	/* TPREL(S+A) */
#define R_AARCH64_TLSLE_LDST128_TPREL_LO12_NC	571	/* TPREL(S+A) */
#define R_AARCH64_TLSLD_LDST128_DTPREL_LO12	572	/* DTPREL(S+A) */
#define R_AARCH64_TLSLD_LDST128_DTPREL_LO12_NC	573	/* DTPREL(S+A) */

/* Dynamic Relocations */
#define R_AARCH64_P32_COPY		180
#define R_AARCH64_P32_GLOB_DAT		181	/* S + A */
#define R_AARCH64_P32_JUMP_SLOT		182	/* S + A */
#define R_AARCH64_P32_RELATIVE		183	/* Delta(S) + A */
#define R_AARCH64_P32_TLS_DTPREL	184	/* DTPREL(S+A) */
#define R_AARCH64_P32_TLS_DTPMOD	185	/* LBM(S) */
#define R_AARCH64_P32_TLS_TPREL		186	/* TPREL(S+A) */
#define R_AARCH64_P32_TLSDESC		187	/* TLSDESC(S+A) */
#define R_AARCH64_P32_IRELATIVE		188	/* Indirect(Delta(S) + A) */

#define R_AARCH64_COPY			1024
#define R_AARCH64_GLOB_DAT		1025	/* S + A */
#define R_AARCH64_JUMP_SLOT		1026	/* S + A */
#define R_AARCH64_RELATIVE		1027	/* Delta(S) + A */
#define R_AARCH64_TLS_DTPREL64		1028	/* DTPREL(S+A) */
#define R_AARCH64_TLS_DTPMOD64		1029	/* LBM(S) */
#define R_AARCH64_TLS_TPREL64		1030	/* TPREL(S+A) */
#define R_AARCH64_TLSDESC		1031	/* TLSDESC(S+A) */
#define R_AARCH64_IRELATIVE		1032	/* Indirect(Delta(S) + A) */

#define R_TYPE(name)		R_AARCH64_ ## name
#define R_TLS_TYPE(name)	R_AARCH64_ ## name ## 64

/* Processor specific program header types */
#define PT_AARCH64_ARCHEXT	(PT_LOPROC + 0)
#define PT_AARCH64_UNWIND	(PT_LOPROC + 1)

/* Processor specific section header flags */
#define SHF_ENTRYSECT		0x10000000
#define SHF_COMDEF		0x80000000

#define SHT_AARCH64_ATTRIBUTES	(SHT_LOPROC + 3)

#ifdef _KERNEL
#ifdef ELFSIZE
#define	ELF_MD_PROBE_FUNC	ELFNAME2(aarch64_netbsd,probe)
#endif

struct exec_package;

int aarch64_netbsd_elf64_probe(struct lwp *, struct exec_package *, void *,
	char *, vaddr_t *);
int aarch64_netbsd_elf32_probe(struct lwp *, struct exec_package *, void *,
	char *, vaddr_t *);
#endif

#elif defined(__arm__)

#include <arm/elf_machdep.h>

#endif

#endif /* _AARCH64_ELF_MACHDEP_H_ */