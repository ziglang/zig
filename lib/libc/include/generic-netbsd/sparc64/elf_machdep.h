/*	$NetBSD: elf_machdep.h,v 1.14 2017/11/06 03:47:48 christos Exp $	*/

#define ELF32_MACHDEP_ENDIANNESS	ELFDATA2MSB
#define	ELF32_MACHDEP_ID_CASES						\
		case EM_SPARC:						\
		case EM_SPARC32PLUS:					\
			break;

#define	ELF64_MACHDEP_ENDIANNESS	ELFDATA2MSB
#define	ELF64_MACHDEP_ID_CASES						\
		case EM_SPARCV9:					\
			break;

#define	ELF32_MACHDEP_ID	EM_SPARC
#define	ELF64_MACHDEP_ID	EM_SPARCV9

#ifdef __arch64__
#define	KERN_ELFSIZE		64
#define ARCH_ELFSIZE		64	/* MD native binary size */
#else
#define	KERN_ELFSIZE		32
#define ARCH_ELFSIZE		32	/* MD native binary size */
#endif

#ifdef __arch64__
/*
 * we need to check .note.netbsd.mcmodel in native binaries before enabling
 * top-down VM.
 */
struct exec_package;
void sparc64_elf_mcmodel_check(struct exec_package*, const char *, size_t);
#define	ELF_MD_MCMODEL_CHECK(ep, str, len)	\
	sparc64_elf_mcmodel_check(ep,str,len)
#endif

/* The following are what is used for AT_SUN_HWCAP: */
#define AV_SPARC_HWMUL_32x32	1	/* 32x32-bit smul/umul is efficient */
#define	AV_SPARC_HWDIV_32x32	2	/* 32x32-bit sdiv/udiv is efficient */
#define	AV_SPARC_HWFSMULD	4	/* fsmuld is efficient */

/*
 * Here are some SPARC specific flags I can't 
 * find a better home for.  They are used for AT_FLAGS
 * and in the exec header.
 */
#define	EF_SPARCV9_MM		0x3
#define	EF_SPARCV9_TSO		0x0
#define	EF_SPARCV9_PSO		0x1
#define	EF_SPARCV9_RMO		0x2

#define EF_SPARC_32PLUS_MASK    0xffff00        /* bits indicating V8+ type */
#define EF_SPARC_32PLUS         0x000100        /* generic V8+ features */
#define EF_SPARC_EXT_MASK       0xffff00        /* bits for vendor extensions */
#define	EF_SPARC_SUN_US1	0x000200	/* UltraSPARC 1 extensions */	
#define	EF_SPARC_HAL_R1		0x000400	/* HAL R1 extensions */
#define	EF_SPARC_SUN_US3	0x000800	/* UltraSPARC 3 extensions */

/* Relocation types */
#define R_SPARC_NONE		0
#define R_SPARC_8		1
#define R_SPARC_16		2
#define R_SPARC_32		3
#define R_SPARC_DISP8		4
#define R_SPARC_DISP16		5
#define R_SPARC_DISP32		6
#define R_SPARC_WDISP30		7
#define R_SPARC_WDISP22		8
#define R_SPARC_HI22		9
#define R_SPARC_22		10
#define R_SPARC_13		11
#define R_SPARC_LO10		12
#define R_SPARC_GOT10		13
#define R_SPARC_GOT13		14
#define R_SPARC_GOT22		15
#define R_SPARC_PC10		16
#define R_SPARC_PC22		17
#define R_SPARC_WPLT30		18
#define R_SPARC_COPY		19
#define R_SPARC_GLOB_DAT	20
#define R_SPARC_JMP_SLOT	21
#define R_SPARC_RELATIVE	22
#define R_SPARC_UA32		23
#define R_SPARC_PLT32		24
#define R_SPARC_HIPLT22		25
#define R_SPARC_LOPLT10		26
#define R_SPARC_PCPLT32		27
#define R_SPARC_PCPLT22		28
#define R_SPARC_PCPLT10		29
#define R_SPARC_10		30
#define R_SPARC_11		31
#define R_SPARC_64		32
#define R_SPARC_OLO10		33
#define R_SPARC_HH22		34
#define R_SPARC_HM10		35
#define R_SPARC_LM22		36
#define R_SPARC_PC_HH22		37
#define R_SPARC_PC_HM10		38
#define R_SPARC_PC_LM22		39
#define R_SPARC_WDISP16		40
#define R_SPARC_WDISP19		41
#define R_SPARC_GLOB_JMP	42
#define R_SPARC_7		43
#define R_SPARC_5		44
#define R_SPARC_6		45
#define	R_SPARC_DISP64		46
#define	R_SPARC_PLT64		47
#define	R_SPARC_HIX22		48
#define	R_SPARC_LOX10		49
#define	R_SPARC_H44		50
#define	R_SPARC_M44		51
#define	R_SPARC_L44		52
#define	R_SPARC_REGISTER	53
#define	R_SPARC_UA64		54
#define	R_SPARC_UA16		55

/* TLS relocations */
#define R_SPARC_TLS_GD_HI22	56
#define R_SPARC_TLS_GD_LO10	57
#define R_SPARC_TLS_GD_ADD	58
#define R_SPARC_TLS_GD_CALL	59
#define R_SPARC_TLS_LDM_HI22	60
#define R_SPARC_TLS_LDM_LO10	61
#define R_SPARC_TLS_LDM_ADD	62
#define R_SPARC_TLS_LDM_CALL	63
#define R_SPARC_TLS_LDO_HIX22	64
#define R_SPARC_TLS_LDO_LOX10	65
#define R_SPARC_TLS_LDO_ADD	66
#define R_SPARC_TLS_IE_HI22	67
#define R_SPARC_TLS_IE_LO10	68
#define R_SPARC_TLS_IE_LD	69
#define R_SPARC_TLS_IE_LDX	70
#define R_SPARC_TLS_IE_ADD	71
#define R_SPARC_TLS_LE_HIX22	72
#define R_SPARC_TLS_LE_LOX10	73
#define R_SPARC_TLS_DTPMOD32	74
#define R_SPARC_TLS_DTPMOD64	75
#define R_SPARC_TLS_DTPOFF32	76
#define R_SPARC_TLS_DTPOFF64	77
#define R_SPARC_TLS_TPOFF32	78
#define R_SPARC_TLS_TPOFF64	79

#define R_SPARC_JMP_IREL	248
#define R_SPARC_IRELATIVE	249

#define R_TYPE(name)		__CONCAT(R_SPARC_,name)