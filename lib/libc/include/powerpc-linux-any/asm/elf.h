/* SPDX-License-Identifier: GPL-2.0+ WITH Linux-syscall-note */
/*
 * ELF register definitions..
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 */
#ifndef _ASM_POWERPC_ELF_H
#define _ASM_POWERPC_ELF_H


#include <linux/types.h>

#include <asm/ptrace.h>
#include <asm/cputable.h>
#include <asm/auxvec.h>

/* PowerPC relocations defined by the ABIs */
#define R_PPC_NONE		0
#define R_PPC_ADDR32		1	/* 32bit absolute address */
#define R_PPC_ADDR24		2	/* 26bit address, 2 bits ignored.  */
#define R_PPC_ADDR16		3	/* 16bit absolute address */
#define R_PPC_ADDR16_LO		4	/* lower 16bit of absolute address */
#define R_PPC_ADDR16_HI		5	/* high 16bit of absolute address */
#define R_PPC_ADDR16_HA		6	/* adjusted high 16bit */
#define R_PPC_ADDR14		7	/* 16bit address, 2 bits ignored */
#define R_PPC_ADDR14_BRTAKEN	8
#define R_PPC_ADDR14_BRNTAKEN	9
#define R_PPC_REL24		10	/* PC relative 26 bit */
#define R_PPC_REL14		11	/* PC relative 16 bit */
#define R_PPC_REL14_BRTAKEN	12
#define R_PPC_REL14_BRNTAKEN	13
#define R_PPC_GOT16		14
#define R_PPC_GOT16_LO		15
#define R_PPC_GOT16_HI		16
#define R_PPC_GOT16_HA		17
#define R_PPC_PLTREL24		18
#define R_PPC_COPY		19
#define R_PPC_GLOB_DAT		20
#define R_PPC_JMP_SLOT		21
#define R_PPC_RELATIVE		22
#define R_PPC_LOCAL24PC		23
#define R_PPC_UADDR32		24
#define R_PPC_UADDR16		25
#define R_PPC_REL32		26
#define R_PPC_PLT32		27
#define R_PPC_PLTREL32		28
#define R_PPC_PLT16_LO		29
#define R_PPC_PLT16_HI		30
#define R_PPC_PLT16_HA		31
#define R_PPC_SDAREL16		32
#define R_PPC_SECTOFF		33
#define R_PPC_SECTOFF_LO	34
#define R_PPC_SECTOFF_HI	35
#define R_PPC_SECTOFF_HA	36

/* PowerPC relocations defined for the TLS access ABI.  */
#define R_PPC_TLS		67 /* none	(sym+add)@tls */
#define R_PPC_DTPMOD32		68 /* word32	(sym+add)@dtpmod */
#define R_PPC_TPREL16		69 /* half16*	(sym+add)@tprel */
#define R_PPC_TPREL16_LO	70 /* half16	(sym+add)@tprel@l */
#define R_PPC_TPREL16_HI	71 /* half16	(sym+add)@tprel@h */
#define R_PPC_TPREL16_HA	72 /* half16	(sym+add)@tprel@ha */
#define R_PPC_TPREL32		73 /* word32	(sym+add)@tprel */
#define R_PPC_DTPREL16		74 /* half16*	(sym+add)@dtprel */
#define R_PPC_DTPREL16_LO	75 /* half16	(sym+add)@dtprel@l */
#define R_PPC_DTPREL16_HI	76 /* half16	(sym+add)@dtprel@h */
#define R_PPC_DTPREL16_HA	77 /* half16	(sym+add)@dtprel@ha */
#define R_PPC_DTPREL32		78 /* word32	(sym+add)@dtprel */
#define R_PPC_GOT_TLSGD16	79 /* half16*	(sym+add)@got@tlsgd */
#define R_PPC_GOT_TLSGD16_LO	80 /* half16	(sym+add)@got@tlsgd@l */
#define R_PPC_GOT_TLSGD16_HI	81 /* half16	(sym+add)@got@tlsgd@h */
#define R_PPC_GOT_TLSGD16_HA	82 /* half16	(sym+add)@got@tlsgd@ha */
#define R_PPC_GOT_TLSLD16	83 /* half16*	(sym+add)@got@tlsld */
#define R_PPC_GOT_TLSLD16_LO	84 /* half16	(sym+add)@got@tlsld@l */
#define R_PPC_GOT_TLSLD16_HI	85 /* half16	(sym+add)@got@tlsld@h */
#define R_PPC_GOT_TLSLD16_HA	86 /* half16	(sym+add)@got@tlsld@ha */
#define R_PPC_GOT_TPREL16	87 /* half16*	(sym+add)@got@tprel */
#define R_PPC_GOT_TPREL16_LO	88 /* half16	(sym+add)@got@tprel@l */
#define R_PPC_GOT_TPREL16_HI	89 /* half16	(sym+add)@got@tprel@h */
#define R_PPC_GOT_TPREL16_HA	90 /* half16	(sym+add)@got@tprel@ha */
#define R_PPC_GOT_DTPREL16	91 /* half16*	(sym+add)@got@dtprel */
#define R_PPC_GOT_DTPREL16_LO	92 /* half16*	(sym+add)@got@dtprel@l */
#define R_PPC_GOT_DTPREL16_HI	93 /* half16*	(sym+add)@got@dtprel@h */
#define R_PPC_GOT_DTPREL16_HA	94 /* half16*	(sym+add)@got@dtprel@ha */

/* keep this the last entry. */
#define R_PPC_NUM		95


#define ELF_NGREG	48	/* includes nip, msr, lr, etc. */
#define ELF_NFPREG	33	/* includes fpscr */
#define ELF_NVMX	34	/* includes all vector registers */
#define ELF_NVSX	32	/* includes all VSX registers */
#define ELF_NTMSPRREG	3	/* include tfhar, tfiar, texasr */
#define ELF_NEBB	3	/* includes ebbrr, ebbhr, bescr */
#define ELF_NPMU	5	/* includes siar, sdar, sier, mmcr2, mmcr0 */
#define ELF_NPKEY	3	/* includes amr, iamr, uamor */

typedef unsigned long elf_greg_t64;
typedef elf_greg_t64 elf_gregset_t64[ELF_NGREG];

typedef unsigned int elf_greg_t32;
typedef elf_greg_t32 elf_gregset_t32[ELF_NGREG];
typedef elf_gregset_t32 compat_elf_gregset_t;

/*
 * ELF_ARCH, CLASS, and DATA are used to set parameters in the core dumps.
 */
#ifdef __powerpc64__
# define ELF_NVRREG32	33	/* includes vscr & vrsave stuffed together */
# define ELF_NVRREG	34	/* includes vscr & vrsave in split vectors */
# define ELF_NVSRHALFREG 32	/* Half the vsx registers */
# define ELF_GREG_TYPE	elf_greg_t64
# define ELF_ARCH	EM_PPC64
# define ELF_CLASS	ELFCLASS64
typedef elf_greg_t64 elf_greg_t;
typedef elf_gregset_t64 elf_gregset_t;
#else
# define ELF_NEVRREG	34	/* includes acc (as 2) */
# define ELF_NVRREG	33	/* includes vscr */
# define ELF_GREG_TYPE	elf_greg_t32
# define ELF_ARCH	EM_PPC
# define ELF_CLASS	ELFCLASS32
typedef elf_greg_t32 elf_greg_t;
typedef elf_gregset_t32 elf_gregset_t;
#endif /* __powerpc64__ */

#ifdef __BIG_ENDIAN__
#define ELF_DATA	ELFDATA2MSB
#else
#define ELF_DATA	ELFDATA2LSB
#endif

/* Floating point registers */
typedef double elf_fpreg_t;
typedef elf_fpreg_t elf_fpregset_t[ELF_NFPREG];

/* Altivec registers */
/*
 * The entries with indexes 0-31 contain the corresponding vector registers. 
 * The entry with index 32 contains the vscr as the last word (offset 12) 
 * within the quadword.  This allows the vscr to be stored as either a 
 * quadword (since it must be copied via a vector register to/from storage) 
 * or as a word.  
 *
 * 64-bit kernel notes: The entry at index 33 contains the vrsave as the first  
 * word (offset 0) within the quadword.
 *
 * This definition of the VMX state is compatible with the current PPC32 
 * ptrace interface.  This allows signal handling and ptrace to use the same 
 * structures.  This also simplifies the implementation of a bi-arch 
 * (combined (32- and 64-bit) gdb.
 *
 * Note that it's _not_ compatible with 32 bits ucontext which stuffs the
 * vrsave along with vscr and so only uses 33 vectors for the register set
 */
typedef __vector128 elf_vrreg_t;
typedef elf_vrreg_t elf_vrregset_t[ELF_NVRREG];
#ifdef __powerpc64__
typedef elf_vrreg_t elf_vrregset_t32[ELF_NVRREG32];
typedef elf_fpreg_t elf_vsrreghalf_t32[ELF_NVSRHALFREG];
#endif

/* PowerPC64 relocations defined by the ABIs */
#define R_PPC64_NONE    R_PPC_NONE
#define R_PPC64_ADDR32  R_PPC_ADDR32  /* 32bit absolute address.  */
#define R_PPC64_ADDR24  R_PPC_ADDR24  /* 26bit address, word aligned.  */
#define R_PPC64_ADDR16  R_PPC_ADDR16  /* 16bit absolute address. */
#define R_PPC64_ADDR16_LO R_PPC_ADDR16_LO /* lower 16bits of abs. address.  */
#define R_PPC64_ADDR16_HI R_PPC_ADDR16_HI /* high 16bits of abs. address. */
#define R_PPC64_ADDR16_HA R_PPC_ADDR16_HA /* adjusted high 16bits.  */
#define R_PPC64_ADDR14 R_PPC_ADDR14   /* 16bit address, word aligned.  */
#define R_PPC64_ADDR14_BRTAKEN  R_PPC_ADDR14_BRTAKEN
#define R_PPC64_ADDR14_BRNTAKEN R_PPC_ADDR14_BRNTAKEN
#define R_PPC64_REL24   R_PPC_REL24 /* PC relative 26 bit, word aligned.  */
#define R_PPC64_REL14   R_PPC_REL14 /* PC relative 16 bit. */
#define R_PPC64_REL14_BRTAKEN   R_PPC_REL14_BRTAKEN
#define R_PPC64_REL14_BRNTAKEN  R_PPC_REL14_BRNTAKEN
#define R_PPC64_GOT16     R_PPC_GOT16
#define R_PPC64_GOT16_LO  R_PPC_GOT16_LO
#define R_PPC64_GOT16_HI  R_PPC_GOT16_HI
#define R_PPC64_GOT16_HA  R_PPC_GOT16_HA

#define R_PPC64_COPY      R_PPC_COPY
#define R_PPC64_GLOB_DAT  R_PPC_GLOB_DAT
#define R_PPC64_JMP_SLOT  R_PPC_JMP_SLOT
#define R_PPC64_RELATIVE  R_PPC_RELATIVE

#define R_PPC64_UADDR32   R_PPC_UADDR32
#define R_PPC64_UADDR16   R_PPC_UADDR16
#define R_PPC64_REL32     R_PPC_REL32
#define R_PPC64_PLT32     R_PPC_PLT32
#define R_PPC64_PLTREL32  R_PPC_PLTREL32
#define R_PPC64_PLT16_LO  R_PPC_PLT16_LO
#define R_PPC64_PLT16_HI  R_PPC_PLT16_HI
#define R_PPC64_PLT16_HA  R_PPC_PLT16_HA

#define R_PPC64_SECTOFF     R_PPC_SECTOFF
#define R_PPC64_SECTOFF_LO  R_PPC_SECTOFF_LO
#define R_PPC64_SECTOFF_HI  R_PPC_SECTOFF_HI
#define R_PPC64_SECTOFF_HA  R_PPC_SECTOFF_HA
#define R_PPC64_ADDR30          37  /* word30 (S + A - P) >> 2.  */
#define R_PPC64_ADDR64          38  /* doubleword64 S + A.  */
#define R_PPC64_ADDR16_HIGHER   39  /* half16 #higher(S + A).  */
#define R_PPC64_ADDR16_HIGHERA  40  /* half16 #highera(S + A).  */
#define R_PPC64_ADDR16_HIGHEST  41  /* half16 #highest(S + A).  */
#define R_PPC64_ADDR16_HIGHESTA 42  /* half16 #highesta(S + A). */
#define R_PPC64_UADDR64     43  /* doubleword64 S + A.  */
#define R_PPC64_REL64       44  /* doubleword64 S + A - P.  */
#define R_PPC64_PLT64       45  /* doubleword64 L + A.  */
#define R_PPC64_PLTREL64    46  /* doubleword64 L + A - P.  */
#define R_PPC64_TOC16       47  /* half16* S + A - .TOC.  */
#define R_PPC64_TOC16_LO    48  /* half16 #lo(S + A - .TOC.).  */
#define R_PPC64_TOC16_HI    49  /* half16 #hi(S + A - .TOC.).  */
#define R_PPC64_TOC16_HA    50  /* half16 #ha(S + A - .TOC.).  */
#define R_PPC64_TOC         51  /* doubleword64 .TOC. */
#define R_PPC64_PLTGOT16    52  /* half16* M + A.  */
#define R_PPC64_PLTGOT16_LO 53  /* half16 #lo(M + A).  */
#define R_PPC64_PLTGOT16_HI 54  /* half16 #hi(M + A).  */
#define R_PPC64_PLTGOT16_HA 55  /* half16 #ha(M + A).  */

#define R_PPC64_ADDR16_DS      56 /* half16ds* (S + A) >> 2.  */
#define R_PPC64_ADDR16_LO_DS   57 /* half16ds  #lo(S + A) >> 2.  */
#define R_PPC64_GOT16_DS       58 /* half16ds* (G + A) >> 2.  */
#define R_PPC64_GOT16_LO_DS    59 /* half16ds  #lo(G + A) >> 2.  */
#define R_PPC64_PLT16_LO_DS    60 /* half16ds  #lo(L + A) >> 2.  */
#define R_PPC64_SECTOFF_DS     61 /* half16ds* (R + A) >> 2.  */
#define R_PPC64_SECTOFF_LO_DS  62 /* half16ds  #lo(R + A) >> 2.  */
#define R_PPC64_TOC16_DS       63 /* half16ds* (S + A - .TOC.) >> 2.  */
#define R_PPC64_TOC16_LO_DS    64 /* half16ds  #lo(S + A - .TOC.) >> 2.  */
#define R_PPC64_PLTGOT16_DS    65 /* half16ds* (M + A) >> 2.  */
#define R_PPC64_PLTGOT16_LO_DS 66 /* half16ds  #lo(M + A) >> 2.  */

/* PowerPC64 relocations defined for the TLS access ABI.  */
#define R_PPC64_TLS		67 /* none	(sym+add)@tls */
#define R_PPC64_DTPMOD64	68 /* doubleword64 (sym+add)@dtpmod */
#define R_PPC64_TPREL16		69 /* half16*	(sym+add)@tprel */
#define R_PPC64_TPREL16_LO	70 /* half16	(sym+add)@tprel@l */
#define R_PPC64_TPREL16_HI	71 /* half16	(sym+add)@tprel@h */
#define R_PPC64_TPREL16_HA	72 /* half16	(sym+add)@tprel@ha */
#define R_PPC64_TPREL64		73 /* doubleword64 (sym+add)@tprel */
#define R_PPC64_DTPREL16	74 /* half16*	(sym+add)@dtprel */
#define R_PPC64_DTPREL16_LO	75 /* half16	(sym+add)@dtprel@l */
#define R_PPC64_DTPREL16_HI	76 /* half16	(sym+add)@dtprel@h */
#define R_PPC64_DTPREL16_HA	77 /* half16	(sym+add)@dtprel@ha */
#define R_PPC64_DTPREL64	78 /* doubleword64 (sym+add)@dtprel */
#define R_PPC64_GOT_TLSGD16	79 /* half16*	(sym+add)@got@tlsgd */
#define R_PPC64_GOT_TLSGD16_LO	80 /* half16	(sym+add)@got@tlsgd@l */
#define R_PPC64_GOT_TLSGD16_HI	81 /* half16	(sym+add)@got@tlsgd@h */
#define R_PPC64_GOT_TLSGD16_HA	82 /* half16	(sym+add)@got@tlsgd@ha */
#define R_PPC64_GOT_TLSLD16	83 /* half16*	(sym+add)@got@tlsld */
#define R_PPC64_GOT_TLSLD16_LO	84 /* half16	(sym+add)@got@tlsld@l */
#define R_PPC64_GOT_TLSLD16_HI	85 /* half16	(sym+add)@got@tlsld@h */
#define R_PPC64_GOT_TLSLD16_HA	86 /* half16	(sym+add)@got@tlsld@ha */
#define R_PPC64_GOT_TPREL16_DS	87 /* half16ds*	(sym+add)@got@tprel */
#define R_PPC64_GOT_TPREL16_LO_DS 88 /* half16ds (sym+add)@got@tprel@l */
#define R_PPC64_GOT_TPREL16_HI	89 /* half16	(sym+add)@got@tprel@h */
#define R_PPC64_GOT_TPREL16_HA	90 /* half16	(sym+add)@got@tprel@ha */
#define R_PPC64_GOT_DTPREL16_DS	91 /* half16ds*	(sym+add)@got@dtprel */
#define R_PPC64_GOT_DTPREL16_LO_DS 92 /* half16ds (sym+add)@got@dtprel@l */
#define R_PPC64_GOT_DTPREL16_HI	93 /* half16	(sym+add)@got@dtprel@h */
#define R_PPC64_GOT_DTPREL16_HA	94 /* half16	(sym+add)@got@dtprel@ha */
#define R_PPC64_TPREL16_DS	95 /* half16ds*	(sym+add)@tprel */
#define R_PPC64_TPREL16_LO_DS	96 /* half16ds	(sym+add)@tprel@l */
#define R_PPC64_TPREL16_HIGHER	97 /* half16	(sym+add)@tprel@higher */
#define R_PPC64_TPREL16_HIGHERA	98 /* half16	(sym+add)@tprel@highera */
#define R_PPC64_TPREL16_HIGHEST	99 /* half16	(sym+add)@tprel@highest */
#define R_PPC64_TPREL16_HIGHESTA 100 /* half16	(sym+add)@tprel@highesta */
#define R_PPC64_DTPREL16_DS	101 /* half16ds* (sym+add)@dtprel */
#define R_PPC64_DTPREL16_LO_DS	102 /* half16ds	(sym+add)@dtprel@l */
#define R_PPC64_DTPREL16_HIGHER	103 /* half16	(sym+add)@dtprel@higher */
#define R_PPC64_DTPREL16_HIGHERA 104 /* half16	(sym+add)@dtprel@highera */
#define R_PPC64_DTPREL16_HIGHEST 105 /* half16	(sym+add)@dtprel@highest */
#define R_PPC64_DTPREL16_HIGHESTA 106 /* half16	(sym+add)@dtprel@highesta */
#define R_PPC64_TLSGD		107
#define R_PPC64_TLSLD		108
#define R_PPC64_TOCSAVE		109

#define R_PPC64_ENTRY		118

#define R_PPC64_REL16		249
#define R_PPC64_REL16_LO	250
#define R_PPC64_REL16_HI	251
#define R_PPC64_REL16_HA	252

/* Keep this the last entry.  */
#define R_PPC64_NUM		253

#endif /* _ASM_POWERPC_ELF_H */