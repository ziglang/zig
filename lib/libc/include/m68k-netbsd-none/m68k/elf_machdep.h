/*	$NetBSD: elf_machdep.h,v 1.9 2017/11/06 03:47:47 christos Exp $	*/

#define	ELF32_MACHDEP_ENDIANNESS	ELFDATA2MSB
#define	ELF32_MACHDEP_ID_CASES						\
		case EM_68K:						\
			break;

#define	ELF64_MACHDEP_ENDIANNESS	XXX	/* break compilation */
#define	ELF64_MACHDEP_ID_CASES						\
		/* no 64-bit ELF machine types supported */

#define	ELF32_MACHDEP_ID	EM_68K

/*
 * Machine-dependent ELF flags.  These are defined by the GNU tools.
 */
#define	EF_CPU32	0x00810000
#define	EF_M68000	0x01000000

#define	KERN_ELFSIZE		32
#define ARCH_ELFSIZE		32	/* MD native binary size */

/* m68k relocation types */
#define	R_68K_NONE	0
#define	R_68K_32	1
#define	R_68K_16	2
#define	R_68K_8		3
#define	R_68K_PC32	4
#define	R_68K_PC16	5
#define	R_68K_PC8	6
#define	R_68K_GOT32	7
#define	R_68K_GOT16	8
#define	R_68K_GOT8	9
#define	R_68K_GOT32O	10
#define	R_68K_GOT16O	11
#define	R_68K_GOT8O	12
#define	R_68K_PLT32	13
#define	R_68K_PLT16	14
#define	R_68K_PLT8	15
#define	R_68K_PLT32O	16
#define	R_68K_PLT16O	17
#define	R_68K_PLT8O	18
#define	R_68K_COPY	19
#define	R_68K_GLOB_DAT	20
#define	R_68K_JMP_SLOT	21
#define	R_68K_RELATIVE	22

/* TLS relocations */
#define R_68K_TLS_GD32		25
#define R_68K_TLS_GD16		26
#define R_68K_TLS_GD8		27
#define R_68K_TLS_LDM32		28
#define R_68K_TLS_LDM16		29
#define R_68K_TLS_LDM8		30
#define R_68K_TLS_LDO32		31
#define R_68K_TLS_LDO16		32
#define R_68K_TLS_LDO8		33
#define R_68K_TLS_IE32		34
#define R_68K_TLS_IE16		35
#define R_68K_TLS_IE8		36
#define R_68K_TLS_LE32		37
#define R_68K_TLS_LE16		38
#define R_68K_TLS_LE8		39
#define R_68K_TLS_DTPMOD32	40
#define R_68K_TLS_DTPREL32	41
#define R_68K_TLS_TPREL32	42

#define	R_TYPE(name)	__CONCAT(R_68K_,name)