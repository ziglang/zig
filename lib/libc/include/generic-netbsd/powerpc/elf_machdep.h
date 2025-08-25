/*	$NetBSD: elf_machdep.h,v 1.16 2019/12/08 21:46:03 uwe Exp $	*/

#ifndef _POWERPC_ELF_MACHDEP_H_
#define _POWERPC_ELF_MACHDEP_H_

#define	ELF32_MACHDEP_ENDIANNESS	ELFDATA2MSB
#define	ELF32_MACHDEP_ID_CASES						\
		case EM_PPC:						\
			break;

#define	ELF64_MACHDEP_ENDIANNESS	ELFDATA2MSB
#define	ELF64_MACHDEP_ID_CASES						\
		case EM_PPC64:						\
			break;

#define	ELF32_MACHDEP_ID	EM_PPC
#define	ELF64_MACHDEP_ID	EM_PPC64


#ifdef _LP64
#define KERN_ELFSIZE		64
#define ARCH_ELFSIZE		64	/* MD native binary size */
#else
#define KERN_ELFSIZE		32
#define ARCH_ELFSIZE		32	/* MD native binary size */
#endif

/* Specify the value of _GLOBAL_OFFSET_TABLE_ */
#define	DT_PPC_GOT		DT_LOPROC
#define	DT_PPC64_GLINK		(DT_LOPROC + 0)
#define	DT_PPC64_OPD		(DT_LOPROC + 1)
#define	DT_PPC64_OPDSZ		(DT_LOPROC + 2)
#define	DT_PPC64_TLSOPT		(DT_LOPROC + 3)

// A = the addend used to compute the value of relocatable field
// B = the base address of the shared object
// G = offset into the global offset table
// L = section offset or address of the procedure link table entry for the
//     symbol + addend
// M = similar to G except the address which is stored may be the address of
//     the procedure linkage table entry for the symbol
// P = the place (section offset or address) of the storage unit being
//     relocated (computed using r_offset)
// R = the offset of the symbol with the section in which the symbol is defined
// S = the value of the symbol whose index resides in the relocation entry
//
// @dtpmod
//   Computes the load module index of the load module that contains the
//   definition of sym.  The addend, if present, is ignored.
// @dtprel
//   Computes a dtv-relative displacement, the difference between the value of
//   S + A and the base address of the thread-local storage block that contains
//   the definition of the symbol, minus 0x8000.
// @tprel
//   Computes a tp-relative displacement, the difference between the value of
//   S + A and the value of the thread pointer (r13).
// @got@tlsgd
//   Allocates two contiguous entries in the GOT to hold a tls_index structure,
//   with values @dtpmod and @dtprel, and computes the offset to the first
//   entry relative to the TOC base (r2).
// @got@tlsld
//   Allocates two contiguous entries in the GOT to hold a tls_index structure,
//   with values @dtpmod and zero, and computes the offset to the first entry
//   relative to the TOC base (r2).
// @got@dtprel
//   Allocates an entry in the GOT with value @dtprel, and computes the offset
//   to the entry relative to the TOC base (r2).
// @got@tprel
//   Allocates an entry in the GOT with value @tprel, and computes the offset
//   to the entry relative to the TOC base (r2).
// 
// #lo(x) = (x & 0xffff)
// #hi(x) = ((x >> 16) & 0xffff)
// #ha(x) = (((x >> 16) + ((x & 0x8000) == 0x8000)) & 0xffff)
// #higher(x) = ((x >> 32) & 0xffff)
// #highera(x) =
//    (((x >> 32) + ((x & 0xffff8000) == 0xffff8000)) & 0xffff)
// #highest(x) = ((x >> 48) & 0xffff)
// #highesta(x) =
//    (((x >> 48) + ((x & 0xffffffff8000) == 0xffffffff8000)) & 0xffff)
// .TOC. = base TOC base of TOC section for object being relocated

#define	R_PPC_NONE 		0
#define	R_PPC_ADDR32 		1	// S + A
#define	R_PPC_ADDR24 		2	// (S + A) >> 2
#define	R_PPC_ADDR16 		3	// S + A
#define	R_PPC_ADDR16_LO 	4	// #lo(S + A)
#define	R_PPC_ADDR16_HI 	5	// #hi(S + A)
#define	R_PPC_ADDR16_HA 	6	// #ha(S + A)
#define	R_PPC_ADDR14 		7	// (S + A) >> 2
#define	R_PPC_ADDR14_TAKEN 	8	// (S + A) >> 2
#define	R_PPC_ADDR14_NTAKEN 	9	// (S + A) >> 2
#define	R_PPC_REL24 		10 	// (S + A - P) >> 2
#define	R_PPC_REL14 		11	// (S + A - P) >> 2
#define	R_PPC_REL14_TAKEN 	12	// (S + A - P) >> 2
#define	R_PPC_REL14_NTAKEN 	13	// (S + A - P) >> 2
#define	R_PPC_GOT16 		14	// G + A
#define	R_PPC_GOT16_LO 		15	// #lo(G + A)
#define	R_PPC_GOT16_HI 		16	// #hi(G + A)
#define	R_PPC_GOT16_HA 		17	// #ha(G + A)
#define	R_PPC_PLTREL24 		18	// (L + A - P) >> 2
#define	R_PPC_COPY 		19	// none
#define	R_PPC_GLOB_DAT 		20	// S + A
#define	R_PPC_JMP_SLOT 		21
#define	R_PPC_RELATIVE 		22	// B + A
#define	R_PPC_LOCAL24PC 	23	// (see R_PPC_REL24)
#define	R_PPC_UADDR32 		24	// S + A
#define	R_PPC_UADDR16 		25	// S + A
#define	R_PPC_REL32 		26	// S + A - P
#define	R_PPC_PLT32 		27	// L
#define	R_PPC_PLTREL 		28	// L - P
#define	R_PPC_PLT16_LO 		29	// #lo(L)
#define	R_PPC_PLT16_HI 		30	// #hi(L)
#define	R_PPC_PLT16_HA 		31	// #ha(L)
#define	R_PPC_SDAREL16 		32	// S + A - _SDA_BASE_
#define	R_PPC_SECTOFF 		33	// R + A
#define	R_PPC_SECTOFF_LO 	34	// #lo(R + A)
#define	R_PPC_SECTOFF_HI	35	// #lo(R + A)
#define	R_PPC_SECTOFF_HA	36	// #ha(R + A)
#define	R_PPC_ADDR30 		37	// (S + A - P) >> 2
/* PPC64 relocations */
#define R_PPC_ADDR64		38	// S + A
#define R_PPC_ADDR16_HIGHER	39	// #higher(S + A)
#define R_PPC_ADDR16_HIGHERA	40	// #highera(S + A)
#define R_PPC_ADDR16_HIGHEST	41	// #highest(S + A)
#define R_PPC_ADDR16_HIGHESTA	42	// #highesta(S + A)
#define R_PPC_UADDR64		43	// S + A
#define R_PPC_REL64		44	// S + A - P
#define R_PPC_PLT64		45	// L
#define R_PPC_PLTREL4		46	// L - P
#define	R_PPC_TOC16 		47	// S + A - .TOC.
#define	R_PPC_TOC16_LO 		48	// #lo(S + A - .TOC.)
#define	R_PPC_TOC16_HI		49	// #lo(S + A - .TOC.)
#define	R_PPC_TOC16_HA		50	// #ha(S + A - .TOC.)
#define R_PPC_TOC		51	// .TOC.
#define	R_PPC_PLTGOT16 		52	// M
#define	R_PPC_PLTGOT16_LO 	53	// #lo(M)
#define	R_PPC_PLTGOT16_HI	54	// #lo(M)
#define	R_PPC_PLTGOT16_HA	55	// #ha(M)
#define	R_PPC_ADDR16_DS		56	// (S + A) >> 2
#define	R_PPC_ADDR16_LO_DS 	57	// #lo(S + A) >> 2
#define	R_PPC_GOT16_DS 		58	// G >> 2
#define	R_PPC_GOT16_LO_DS 	59	// #lo(G) >> 2
#define	R_PPC_PLT16_LO_DS 	60	// #lo(L) >> 2
#define	R_PPC_SECTOFF16_DS	61	// (R + A) >> 2
#define	R_PPC_SECTOFF16_LO_DS 	62	// #lo(R + A) >> 2
#define	R_PPC_TOC16_DS		63	// (S + A - .TOC.) >> 2
#define	R_PPC_TOC16_LO_DS 	64	// #lo(S + A - .TOC.) >> 2
#define	R_PPC_PLTGOT16_DS	65	// M >> 2
#define	R_PPC_PLTGOT16_LO_DS 	66	// #lo(M) >> 2

/* TLS relocations */
#define	R_PPC_TLS		67	// none

#define	R_PPC_DTPMOD		68
#define	R_PPC_TPREL16		69	// @tprel
#define	R_PPC_TPREL16_LO	70	// #lo(@tprel)
#define	R_PPC_TPREL16_HI	71	// #hi(@tprel)
#define	R_PPC_TPREL16_HA	72	// #ha(@tprel)
#define	R_PPC_TPREL		73	// @tprel
#define	R_PPC_DTPREL16		74	// @got@dtprel
#define	R_PPC_DTPREL16_LO	75	// #lo(@dtprel)
#define	R_PPC_DTPREL16_HI	76	// #hi(@dtprel)
#define	R_PPC_DTPREL16_HA	77	// #ha(@dtprel)
#define	R_PPC_DTPREL		78	// @dtprel

#define	R_PPC_GOT_TLSGD16	79	// @got@tlsgd
#define	R_PPC_GOT_TLSGD16_LO	80	// #lo(@got@tlsgd)
#define	R_PPC_GOT_TLSGD16_HI	81	// #hi(@got@tlsgd)
#define	R_PPC_GOT_TLSGD16_HA	82	// #ha(@got@tlsgd)
#define	R_PPC_GOT_TLSLD16	83	// @got@tlsld
#define	R_PPC_GOT_TLSLD16_LO	84	// #lo(@got@tlsld)
#define	R_PPC_GOT_TLSLD16_HI	85	// #hi(@got@tlsld)
#define	R_PPC_GOT_TLSLD16_HA	86	// #ha(@got@tlsld)

#define	R_PPC_GOT_TPREL16	87	// @got@tprel
#define	R_PPC_GOT_TPREL16_LO	88	// #lo(@got@tprel)
#define	R_PPC_GOT_TPREL16_HI	89	// #hi(@got@tprel)
#define	R_PPC_GOT_TPREL16_HA	90	// #ha(@got@tprel)
#define	R_PPC_GOT_DTPREL16	91	// @got@dtprel
#define	R_PPC_GOT_DTPREL16_LO	92	// #lo(@got@dtprel)
#define	R_PPC_GOT_DTPREL16_HI	93	// #hi(@got@dtprel)
#define	R_PPC_GOT_DTPREL16_HA	94	// #ha(@got@dtprel)
#define	R_PPC_TLSGD		95
#define	R_PPC_TLSLD		96

/* PPC64 relocations */
#define	R_PPC_TPREL16_DS	95	// @tprel
#define	R_PPC_TPREL16_LO_DS	96	// #lo(@tprel)
#define	R_PPC_TPREL16_HIGHER	97	// #higher(@tprel)
#define	R_PPC_TPREL16_HIGHERA	98	// #highera(@tprel)
#define	R_PPC_TPREL16_HIGHEST	99	// #highest(@tprel)
#define	R_PPC_TPREL16_HIGHESTA	100	// #highesta(@tprel)

#define	R_PPC_DTPREL16_DS	101	// @dtprel
#define	R_PPC_DTPREL16_LO_DS	102	// #lo(@dtprel)
#define	R_PPC_DTPREL16_HIGHER	103	// #higher(@dtprel)
#define	R_PPC_DTPREL16_HIGHERA	104	// #highera(@dtprel)
#define	R_PPC_DTPREL16_HIGHEST	105	// #highest(@dtprel)
#define	R_PPC_DTPREL16_HIGHESTA	106	// #highesta(@dtprel)

/* Indirect-function support */
#define	R_PPC_IRELATIVE		248

/* Used for the secure-plt PIC code sequences */
#define	R_PPC_REL16		249	// S + A - P
#define	R_PPC_REL16_LO		250	// #lo(S + A - P)
#define	R_PPC_REL16_HI		251	// #hi(S + A - P)
#define	R_PPC_REL16_HA		252	// #ha(S + A - P)

#define R_TYPE(name) 		__CONCAT(R_PPC_,name)

#endif /* _POWERPC_ELF_MACHDEP_H_ */