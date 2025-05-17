/*	$NetBSD: exec_elf.h,v 1.170 2022/06/08 10:12:42 rin Exp $	*/

/*-
 * Copyright (c) 1994 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas.
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

#ifndef _SYS_EXEC_ELF_H_
#define _SYS_EXEC_ELF_H_

/*
 * The current ELF ABI specification is available at:
 *	http://www.sco.com/developers/gabi/
 *
 * Current header definitions are in:
 *	http://www.sco.com/developers/gabi/latest/ch4.eheader.html
 */

#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/types.h>
#else
#include <inttypes.h>
#include <stddef.h>
#endif /* _KERNEL || _STANDALONE */

#if HAVE_NBTOOL_CONFIG_H
#include <nbinclude/machine/elf_machdep.h>
#else
#include <machine/elf_machdep.h>
#endif

typedef uint8_t		Elf_Byte;

typedef uint32_t	Elf32_Addr;
#define ELF32_FSZ_ADDR	4
typedef uint32_t	Elf32_Off;
typedef int32_t		Elf32_SOff;
#define ELF32_FSZ_OFF	4
typedef int32_t		Elf32_Sword;
#define ELF32_FSZ_SWORD 4
typedef uint32_t	Elf32_Word;
#define ELF32_FSZ_WORD	4
typedef uint16_t	Elf32_Half;
#define ELF32_FSZ_HALF	2
typedef uint64_t	Elf32_Lword;
#define ELF32_FSZ_LWORD 8

typedef uint64_t	Elf64_Addr;
#define ELF64_FSZ_ADDR	8
typedef uint64_t	Elf64_Off;
typedef int64_t		Elf64_SOff;
#define ELF64_FSZ_OFF	8

typedef int32_t		Elf64_Sword;
#define ELF64_FSZ_SWORD 4
typedef uint32_t	Elf64_Word;
#define ELF64_FSZ_WORD	4

typedef int64_t		Elf64_Sxword;
#define ELF64_FSZ_SXWORD 8
typedef uint64_t	Elf64_Xword;
#define ELF64_FSZ_XWORD 8
typedef uint64_t	Elf64_Lword;
#define ELF64_FSZ_LWORD 8
typedef uint16_t	Elf64_Half;
#define ELF64_FSZ_HALF 2

/*
 * ELF Header
 */
#define ELF_NIDENT	16

typedef struct {
	unsigned char	e_ident[ELF_NIDENT];	/* Id bytes */
	Elf32_Half	e_type;			/* file type */
	Elf32_Half	e_machine;		/* machine type */
	Elf32_Word	e_version;		/* version number */
	Elf32_Addr	e_entry;		/* entry point */
	Elf32_Off	e_phoff;		/* Program hdr offset */
	Elf32_Off	e_shoff;		/* Section hdr offset */
	Elf32_Word	e_flags;		/* Processor flags */
	Elf32_Half	e_ehsize;		/* sizeof ehdr */
	Elf32_Half	e_phentsize;		/* Program header entry size */
	Elf32_Half	e_phnum;		/* Number of program headers */
	Elf32_Half	e_shentsize;		/* Section header entry size */
	Elf32_Half	e_shnum;		/* Number of section headers */
	Elf32_Half	e_shstrndx;		/* String table index */
} Elf32_Ehdr;

typedef struct {
	unsigned char	e_ident[ELF_NIDENT];	/* Id bytes */
	Elf64_Half	e_type;			/* file type */
	Elf64_Half	e_machine;		/* machine type */
	Elf64_Word	e_version;		/* version number */
	Elf64_Addr	e_entry;		/* entry point */
	Elf64_Off	e_phoff;		/* Program hdr offset */
	Elf64_Off	e_shoff;		/* Section hdr offset */
	Elf64_Word	e_flags;		/* Processor flags */
	Elf64_Half	e_ehsize;		/* sizeof ehdr */
	Elf64_Half	e_phentsize;		/* Program header entry size */
	Elf64_Half	e_phnum;		/* Number of program headers */
	Elf64_Half	e_shentsize;		/* Section header entry size */
	Elf64_Half	e_shnum;		/* Number of section headers */
	Elf64_Half	e_shstrndx;		/* String table index */
} Elf64_Ehdr;

/* e_ident offsets */
#define EI_MAG0		0	/* '\177' */
#define EI_MAG1		1	/* 'E'	  */
#define EI_MAG2		2	/* 'L'	  */
#define EI_MAG3		3	/* 'F'	  */
#define EI_CLASS	4	/* File class */
#define EI_DATA		5	/* Data encoding */
#define EI_VERSION	6	/* File version */
#define EI_OSABI	7	/* Operating system/ABI identification */
#define EI_ABIVERSION	8	/* ABI version */
#define EI_PAD		9	/* Start of padding bytes up to EI_NIDENT*/
#define EI_NIDENT	16	/* First non-ident header byte */

/* e_ident[EI_MAG0,EI_MAG3] */
#define ELFMAG0		0x7f
#define ELFMAG1		'E'
#define ELFMAG2		'L'
#define ELFMAG3		'F'
#define ELFMAG		"\177ELF"
#define SELFMAG		4

/* e_ident[EI_CLASS] */
#define ELFCLASSNONE	0	/* Invalid class */
#define ELFCLASS32	1	/* 32-bit objects */
#define ELFCLASS64	2	/* 64-bit objects */
#define ELFCLASSNUM	3

/* e_ident[EI_DATA] */
#define ELFDATANONE	0	/* Invalid data encoding */
#define ELFDATA2LSB	1	/* 2's complement values, LSB first */
#define ELFDATA2MSB	2	/* 2's complement values, MSB first */

/* e_ident[EI_VERSION] */
#define EV_NONE		0	/* Invalid version */
#define EV_CURRENT	1	/* Current version */
#define EV_NUM		2

/* e_ident[EI_OSABI] */
#define ELFOSABI_SYSV		0	/* UNIX System V ABI */
#define ELFOSABI_HPUX		1	/* HP-UX operating system */
#define ELFOSABI_NETBSD		2	/* NetBSD */
#define ELFOSABI_GNU		3	/* GNU/Linux */
#define ELFOSABI_HURD		4	/* GNU/Hurd - historical */
#define ELFOSABI_86OPEN		5	/* 86Open - historical */
#define ELFOSABI_SOLARIS	6	/* Solaris */
#define ELFOSABI_AIX		7	/* AIX */
#define ELFOSABI_IRIX		8	/* IRIX */
#define ELFOSABI_FREEBSD	9	/* FreeBSD */
#define ELFOSABI_TRU64		10	/* TRU64 UNIX */
#define ELFOSABI_MODESTO	11	/* Novell Modesto */
#define ELFOSABI_OPENBSD	12	/* OpenBSD */
#define ELFOSABI_OPENVMS	13	/* OpenVMS */
#define ELFOSABI_NSK		14	/* HP Non-Stop Kernel */
#define ELFOSABI_AROS		15	/* Amiga Research OS */
#define ELFOSABI_FENIXOS	16	/* The FenixOS highly scalable multi-core OS */
#define ELFOSABI_CLOUDABI	17	/* Nuxi CloudABI */
#define ELFOSABI_OPENVOS	18	/* Stratus Technologies OpenVOS */
/* Unofficial OSABIs follow */
#define ELFOSABI_ARM		97	/* ARM */
#define ELFOSABI_STANDALONE	255	/* Standalone (embedded) application */

#define ELFOSABI_NONE		ELFOSABI_SYSV

/* Historical aliases. */
#define ELFOSABI_LINUX		ELFOSABI_GNU
#define ELFOSABI_MONTEREY	ELFOSABI_AIX

/* e_type */
#define ET_NONE		0	/* No file type */
#define ET_REL		1	/* Relocatable file */
#define ET_EXEC		2	/* Executable file */
#define ET_DYN		3	/* Shared object file */
#define ET_CORE		4	/* Core file */
#define ET_NUM		5

#define ET_LOOS		0xfe00	/* Operating system specific range */
#define ET_HIOS		0xfeff
#define ET_LOPROC	0xff00	/* Processor-specific range */
#define ET_HIPROC	0xffff

/* e_machine */
#define EM_NONE		0	/* No machine */
#define EM_M32		1	/* AT&T WE 32100 */
#define EM_SPARC	2	/* SPARC */
#define EM_386		3	/* Intel 80386 */
#define EM_68K		4	/* Motorola 68000 */
#define EM_88K		5	/* Motorola 88000 */
#define EM_486		6	/* Intel 80486 [old] */
#define EM_IAMCU	6	/* Intel MCU. */
#define EM_860		7	/* Intel 80860 */
#define EM_MIPS		8	/* MIPS I Architecture */
#define EM_S370		9	/* Amdahl UTS on System/370 */
#define EM_MIPS_RS3_LE	10	/* MIPS RS3000 Little-endian */
			/* 11-14 - Reserved */
#define EM_RS6000	11	/* IBM RS/6000 XXX reserved */
#define EM_PARISC	15	/* Hewlett-Packard PA-RISC */
#define EM_NCUBE	16	/* NCube XXX reserved */
#define EM_VPP500	17	/* Fujitsu VPP500 */
#define EM_SPARC32PLUS	18	/* Enhanced instruction set SPARC */
#define EM_960		19	/* Intel 80960 */
#define EM_PPC		20	/* PowerPC */
#define EM_PPC64	21	/* 64-bit PowerPC */
#define EM_S390		22	/* IBM System/390 Processor */
#define EM_SPU		23	/* IBM SPU/SPC */
			/* 24-35 - Reserved */
#define EM_V800		36	/* NEC V800 */
#define EM_FR20		37	/* Fujitsu FR20 */
#define EM_RH32		38	/* TRW RH-32 */
#define EM_RCE		39	/* Motorola RCE */
#define EM_ARM		40	/* Advanced RISC Machines ARM */
#define EM_OLD_ALPHA	41	/* DIGITAL Alpha (obsolete) */
#define EM_SH		42	/* Hitachi Super-H */
#define EM_SPARCV9	43	/* SPARC Version 9 */
#define EM_TRICORE	44	/* Siemens Tricore */
#define EM_ARC		45	/* Argonaut RISC Core */
#define EM_H8_300	46	/* Hitachi H8/300 */
#define EM_H8_300H	47	/* Hitachi H8/300H */
#define EM_H8S		48	/* Hitachi H8S */
#define EM_H8_500	49	/* Hitachi H8/500 */
#define EM_IA_64	50	/* Intel Merced Processor */
#define EM_MIPS_X	51	/* Stanford MIPS-X */
#define EM_COLDFIRE	52	/* Motorola Coldfire */
#define EM_68HC12	53	/* Motorola MC68HC12 */
#define EM_MMA		54	/* Fujitsu MMA Multimedia Accelerator */
#define EM_PCP		55	/* Siemens PCP */
#define EM_NCPU		56	/* Sony nCPU embedded RISC processor */
#define EM_NDR1		57	/* Denso NDR1 microprocessor */
#define EM_STARCORE	58	/* Motorola Star*Core processor */
#define EM_ME16		59	/* Toyota ME16 processor */
#define EM_ST100	60	/* STMicroelectronics ST100 processor */
#define EM_TINYJ	61	/* Advanced Logic Corp. TinyJ embedded family processor */
#define EM_X86_64	62	/* AMD x86-64 architecture */
#define EM_PDSP		63	/* Sony DSP Processor */
#define EM_PDP10	64	/* Digital Equipment Corp. PDP-10 */
#define EM_PDP11	65	/* Digital Equipment Corp. PDP-11 */
#define EM_FX66		66	/* Siemens FX66 microcontroller */
#define EM_ST9PLUS	67	/* STMicroelectronics ST9+ 8/16 bit microcontroller */
#define EM_ST7		68	/* STMicroelectronics ST7 8-bit microcontroller */
#define EM_68HC16	69	/* Motorola MC68HC16 Microcontroller */
#define EM_68HC11	70	/* Motorola MC68HC11 Microcontroller */
#define EM_68HC08	71	/* Motorola MC68HC08 Microcontroller */
#define EM_68HC05	72	/* Motorola MC68HC05 Microcontroller */
#define EM_SVX		73	/* Silicon Graphics SVx */
#define EM_ST19		74	/* STMicroelectronics ST19 8-bit CPU */
#define EM_VAX		75	/* Digital VAX */
#define EM_CRIS		76	/* Axis Communications 32-bit embedded processor */
#define EM_JAVELIN	77	/* Infineon Technologies 32-bit embedded CPU */
#define EM_FIREPATH	78	/* Element 14 64-bit DSP processor */
#define EM_ZSP		79	/* LSI Logic's 16-bit DSP processor */
#define EM_MMIX		80	/* Donald Knuth's educational 64-bit processor */
#define EM_HUANY	81	/* Harvard's machine-independent format */
#define EM_PRISM	82	/* SiTera Prism */
#define EM_AVR		83	/* Atmel AVR 8-bit microcontroller */
#define EM_FR30		84	/* Fujitsu FR30 */
#define EM_D10V		85	/* Mitsubishi D10V */
#define EM_D30V		86	/* Mitsubishi D30V */
#define EM_V850		87	/* NEC v850 */
#define EM_M32R		88	/* Mitsubishi M32R */
#define EM_MN10300	89	/* Matsushita MN10300 */
#define EM_MN10200	90	/* Matsushita MN10200 */
#define EM_PJ		91	/* picoJava */
#define EM_OR1K		92	/* OpenRISC 32-bit embedded processor */
#define EM_OPENRISC	EM_OR1K
#define EM_ARC_A5	93	/* ARC Cores Tangent-A5 */
#define EM_XTENSA	94	/* Tensilica Xtensa Architecture */
#define EM_VIDEOCORE	95	/* Alphamosaic VideoCore processor */
#define EM_TMM_GPP	96	/* Thompson Multimedia General Purpose Processor */
#define EM_NS32K	97	/* National Semiconductor 32000 series */
#define EM_TPC		98	/* Tenor Network TPC processor */
#define EM_SNP1K	99	/* Trebia SNP 1000 processor */
#define EM_ST200	100	/* STMicroelectronics ST200 microcontroller */
#define EM_IP2K		101	/* Ubicom IP2xxx microcontroller family */
#define EM_MAX		102	/* MAX processor */
#define EM_CR		103	/* National Semiconductor CompactRISC micorprocessor */
#define EM_F2MC16	104	/* Fujitsu F2MC16 */
#define EM_MSP430	105	/* Texas Instruments MSP430 */
#define EM_BLACKFIN	106	/* Analog Devices Blackfin DSP */
#define EM_SE_C33	107	/* Seiko Epson S1C33 family */
#define EM_SEP		108	/* Sharp embedded microprocessor */
#define EM_ARCA		109	/* Arca RISC microprocessor */
#define EM_UNICORE	110	/* UNICORE from PKU-Unity Ltd. and MPRC Peking University */
#define EM_EXCESS	111	/* eXcess: 16/32/64-bit configurable embedded CPU */
#define EM_DXP		112	/* Icera Semiconductor Inc. Deep Execution Processor */
#define EM_ALTERA_NIOS2	113	/* Altera Nios II soft-core processor */
#define EM_CRX		114	/* National Semiconductor CompactRISC CRX microprocessor */
#define EM_XGATE	115	/* Motorola XGATE embedded processor */
#define EM_C166		116	/* Infineon C16x/XC16x processor */
#define EM_M16C		117	/* Renesas M16C series microprocessors */
#define EM_DSPIC30F	118	/* Microchip Technology dsPIC30F Digital Signal Controller */
#define EM_CE		119	/* Freescale Communication Engine RISC core */
#define EM_M32C		120	/* Renesas M32C series microprocessors */
			/* 121-130 - Reserved */
#define EM_TSK3000	131	/* Altium TSK3000 core */
#define EM_RS08		132	/* Freescale RS08 embedded processor */
#define EM_SHARC	133	/* Analog Devices SHARC family of 32-bit DSP processors */
#define EM_ECOG2	134	/* Cyan Technology eCOG2 microprocessor */
#define EM_SCORE7	135	/* Sunplus S+core7 RISC processor */
#define EM_DSP24	136	/* New Japan Radio (NJR) 24-bit DSP Processor */
#define EM_VIDEOCORE3	137	/* Broadcom VideoCore III processor */
#define EM_LATTICEMICO32	138	/* RISC processor for Lattice FPGA architecture */
#define EM_SE_C17	139	/* Seiko Epson C17 family */
#define EM_TI_C6000	140	/* The Texas Instruments TMS320C6000 DSP family */
#define EM_TI_C2000	141	/* The Texas Instruments TMS320C2000 DSP family */
#define EM_TI_C5500	142	/* The Texas Instruments TMS320C55x DSP family */
#define EM_TI_ARP32	143	/* Texas Instruments Application Specific RISC Processor, 32bit fetch */
#define EM_TI_PRU	144	/* Texas Instruments Programmable Realtime Unit */
			/* 145-159 - Reserved */
#define EM_MMDSP_PLUS	160	/* STMicroelectronics 64bit VLIW Data Signal Processor */
#define EM_CYPRESS_M8C	161	/* Cypress M8C microprocessor */
#define EM_R32C		162	/* Renesas R32C series microprocessors */
#define EM_TRIMEDIA	163	/* NXP Semiconductors TriMedia architecture family */
#define EM_QDSP6	164	/* QUALCOMM DSP6 Processor */
#define EM_8051		165	/* Intel 8051 and variants */
#define EM_STXP7X	166	/* STMicroelectronics STxP7x family of configurable and extensible RISC processors */
#define EM_NDS32	167	/* Andes Technology compact code size embedded RISC processor family */
#define EM_ECOG1	168	/* Cyan Technology eCOG1X family */
#define EM_ECOG1X	168	/* Cyan Technology eCOG1X family */
#define EM_MAXQ30	169	/* Dallas Semiconductor MAXQ30 Core Micro-controllers */
#define EM_XIMO16	170	/* New Japan Radio (NJR) 16-bit DSP Processor */
#define EM_MANIK	171	/* M2000 Reconfigurable RISC Microprocessor */
#define EM_CRAYNV2	172	/* Cray Inc. NV2 vector architecture */
#define EM_RX		173	/* Renesas RX family */
#define EM_METAG	174	/* Imagination Technologies META processor architecture */
#define EM_MCST_ELBRUS	175	/* MCST Elbrus general purpose hardware architecture */
#define EM_ECOG16	176	/* Cyan Technology eCOG16 family */
#define EM_CR16		177	/* National Semiconductor CompactRISC CR16 16-bit microprocessor */
#define EM_ETPU		178	/* Freescale Extended Time Processing Unit */
#define EM_SLE9X	179	/* Infineon Technologies SLE9X core */
#define EM_L10M		180	/* Intel L10M */
#define EM_K10M		181	/* Intel K10M */
			/* 182 - Reserved */
#define EM_AARCH64	183	/* AArch64 64-bit ARM microprocessor */
			/* 184 - Reserved */
#define EM_AVR32	185	/* Atmel Corporation 32-bit microprocessor family*/
#define EM_TILE64	187	/* Tilera TILE64 multicore architecture family */
#define EM_TILEPRO	188	/* Tilera TILEPro multicore architecture family */
#define EM_MICROBLAZE	189	/* Xilinx MicroBlaze 32-bit RISC soft processor core */
#define EM_CUDA		190	/* NVIDIA CUDA architecture */
#define EM_TILEGX	191	/* Tilera TILE-GX multicore architecture family */
#define EM_CLOUDSHIELD	192	/* CloudShield architecture family */
#define EM_COREA_1ST	193	/* KIPO-KAIST Core-A 1st generation processor family */
#define EM_COREA_2ND	194	/* KIPO-KAIST Core-A 2nd generation processor family */
#define EM_ARC_COMPACT2	195	/* Synopsys ARCompact V2 */
#define EM_OPEN8	196	/* Open8 8-bit RISC soft processor core */
#define EM_RL78		197	/* Renesas RL78 family */
#define EM_VIDEOCORE5	198	/* Broadcom VideoCore V processor */
#define EM_78KOR	199	/* Renesas 78KOR family */
#define EM_56800EX	200	/* Freescale 56800EX Digital Signal Controller (DSC) */
#define EM_BA1		201	/* Beyond BA1 CPU architecture */
#define EM_BA2		202	/* Beyond BA2 CPU architecture */
#define EM_XCORE	203	/* XMOS xCORE processor family */
#define EM_MCHP_PIC	204	/* Microchip 8-bit PIC(r) family */
#define EM_INTEL205	205	/* Reserved by Intel */
#define EM_INTEL206	206	/* Reserved by Intel */
#define EM_INTEL207	207	/* Reserved by Intel */
#define EM_INTEL208	208	/* Reserved by Intel */
#define EM_INTEL209	209	/* Reserved by Intel */
#define EM_KM32		210	/* KM211 KM32 32-bit processor */
#define EM_KMX32	211	/* KM211 KMX32 32-bit processor */
#define EM_KMX16	212	/* KM211 KMX16 16-bit processor */
#define EM_KMX8		213	/* KM211 KMX8 8-bit processor */
#define EM_KVARC	214	/* KM211 KVARC processor */
#define EM_CDP		215	/* Paneve CDP architecture family */
#define EM_COGE		216	/* Cognitive Smart Memory Processor */
#define EM_COOL		217	/* Bluechip Systems CoolEngine */
#define EM_NORC		218	/* Nanoradio Optimized RISC */
#define EM_CSR_KALIMBA 	219	/* CSR Kalimba architecture family */
#define EM_Z80		220	/* Zilog Z80 */
#define EM_VISIUM 	221	/* Controls and Data Services VISIUMcore processor */
#define EM_FT32 	222	/* FTDI Chip FT32 high performance 32-bit RISC architecture */
#define EM_MOXIE	223	/* Moxie processor family */
#define EM_AMDGPU	224	/* AMD GPU architecture */
			/* 225-242 - Reserved */
#define EM_RISCV	243	/* RISC-V */

/* Unofficial machine types follow */
#define EM_ALPHA	36902	/* DIGITAL Alpha */
#define EM_NUM		36903

/*
 * Program Header
 */
typedef struct {
	Elf32_Word	p_type;		/* entry type */
	Elf32_Off	p_offset;	/* offset */
	Elf32_Addr	p_vaddr;	/* virtual address */
	Elf32_Addr	p_paddr;	/* physical address */
	Elf32_Word	p_filesz;	/* file size */
	Elf32_Word	p_memsz;	/* memory size */
	Elf32_Word	p_flags;	/* flags */
	Elf32_Word	p_align;	/* memory & file alignment */
} Elf32_Phdr;

typedef struct {
	Elf64_Word	p_type;		/* entry type */
	Elf64_Word	p_flags;	/* flags */
	Elf64_Off	p_offset;	/* offset */
	Elf64_Addr	p_vaddr;	/* virtual address */
	Elf64_Addr	p_paddr;	/* physical address */
	Elf64_Xword	p_filesz;	/* file size */
	Elf64_Xword	p_memsz;	/* memory size */
	Elf64_Xword	p_align;	/* memory & file alignment */
} Elf64_Phdr;

/* p_type */
#define PT_NULL		0		/* Program header table entry unused */
#define PT_LOAD		1		/* Loadable program segment */
#define PT_DYNAMIC	2		/* Dynamic linking information */
#define PT_INTERP	3		/* Program interpreter */
#define PT_NOTE		4		/* Auxiliary information */
#define PT_SHLIB	5		/* Reserved, unspecified semantics */
#define PT_PHDR		6		/* Entry for header table itself */
#define PT_TLS		7		/* TLS initialisation image */
#define PT_NUM		8

#define PT_LOOS		0x60000000	/* OS-specific range */

/* GNU-specific */
#define PT_GNU_EH_FRAME 0x6474e550	/* EH frame segment */
#define PT_GNU_STACK	0x6474e551	/* Indicate executable stack */
#define PT_GNU_RELRO	0x6474e552	/* Make read-only after relocation */

#define PT_HIOS		0x6fffffff
#define PT_LOPROC	0x70000000	/* Processor-specific range */
#define PT_HIPROC	0x7fffffff

#define PT_MIPS_REGINFO 0x70000000
#define PT_MIPS_ABIFLAGS 0x70000003

/* p_flags */
#define PF_R		0x4		/* Segment is readable */
#define PF_W		0x2		/* Segment is writable */
#define PF_X		0x1		/* Segment is executable */

#define PF_MASKOS	0x0ff00000	/* Operating system specific values */
#define PF_MASKPROC	0xf0000000	/* Processor-specific values */

/* Extended program header index. */
#define PN_XNUM		0xffff

/*
 * Section Headers
 */
typedef struct {
	Elf32_Word	sh_name;	/* section name (.shstrtab index) */
	Elf32_Word	sh_type;	/* section type */
	Elf32_Word	sh_flags;	/* section flags */
	Elf32_Addr	sh_addr;	/* virtual address */
	Elf32_Off	sh_offset;	/* file offset */
	Elf32_Word	sh_size;	/* section size */
	Elf32_Word	sh_link;	/* link to another */
	Elf32_Word	sh_info;	/* misc info */
	Elf32_Word	sh_addralign;	/* memory alignment */
	Elf32_Word	sh_entsize;	/* table entry size */
} Elf32_Shdr;

typedef struct {
	Elf64_Word	sh_name;	/* section name (.shstrtab index) */
	Elf64_Word	sh_type;	/* section type */
	Elf64_Xword	sh_flags;	/* section flags */
	Elf64_Addr	sh_addr;	/* virtual address */
	Elf64_Off	sh_offset;	/* file offset */
	Elf64_Xword	sh_size;	/* section size */
	Elf64_Word	sh_link;	/* link to another */
	Elf64_Word	sh_info;	/* misc info */
	Elf64_Xword	sh_addralign;	/* memory alignment */
	Elf64_Xword	sh_entsize;	/* table entry size */
} Elf64_Shdr;

/* sh_type */
#define SHT_NULL	      0		/* Section header table entry unused */
#define SHT_PROGBITS	      1		/* Program information */
#define SHT_SYMTAB	      2		/* Symbol table */
#define SHT_STRTAB	      3		/* String table */
#define SHT_RELA	      4		/* Relocation information w/ addend */
#define SHT_HASH	      5		/* Symbol hash table */
#define SHT_DYNAMIC	      6		/* Dynamic linking information */
#define SHT_NOTE	      7		/* Auxiliary information */
#define SHT_NOBITS	      8		/* No space allocated in file image */
#define SHT_REL		      9		/* Relocation information w/o addend */
#define SHT_SHLIB	     10		/* Reserved, unspecified semantics */
#define SHT_DYNSYM	     11		/* Symbol table for dynamic linker */
#define SHT_INIT_ARRAY	     14		/* Initialization function pointers */
#define SHT_FINI_ARRAY	     15		/* Termination function pointers */
#define SHT_PREINIT_ARRAY    16		/* Pre-initialization function ptrs */
#define SHT_GROUP	     17		/* Section group */
#define SHT_SYMTAB_SHNDX     18		/* Section indexes (see SHN_XINDEX) */
#define SHT_NUM		     19

#define SHT_LOOS	     0x60000000 /* Operating system specific range */
#define SHT_GNU_INCREMENTAL_INPUTS 0x6fff4700   /* GNU incremental build data */
#define	SHT_LOSUNW	     0x6ffffff4
#define	SHT_SUNW_dof	     0x6ffffff4
#define	SHT_GNU_ATTRIBUTES   0x6ffffff5	/* GNU object attributes */
#define	SHT_SUNW_cap	     0x6ffffff5
#define	SHT_SUNW_SIGNATURE   0x6ffffff6
#define SHT_GNU_HASH	     0x6ffffff6 /* GNU style symbol hash table */
#define SHT_GNU_LIBLIST	     0x6ffffff7 /* GNU list of prelink dependencies */
#define SHT_SUNW_move	     0x6ffffffa
#define	SHT_SUNW_COMDAT	     0x6ffffffb
#define SHT_SUNW_syminfo     0x6ffffffc
#define SHT_SUNW_verdef	     0x6ffffffd /* Versions defined by file */
#define SHT_GNU_verdef	     SHT_SUNW_verdef
#define SHT_SUNW_verneed     0x6ffffffe /* Versions needed by file */
#define SHT_GNU_verneed	     SHT_SUNW_verneed
#define SHT_SUNW_versym	     0x6fffffff /* Symbol versions */
#define SHT_GNU_versym	     SHT_SUNW_versym
#define	SHT_HISUNW	     0x6fffffff
#define SHT_HIOS	     0x6fffffff
#define SHT_LOPROC	     0x70000000 /* Processor-specific range */
#define SHT_AMD64_UNWIND     0x70000001 /* unwind information */
#define SHT_ARM_EXIDX	     0x70000001	/* exception index table */
#define SHT_ARM_PREEMPTMAP   0x70000002 /* BPABI DLL dynamic linking 
					 * pre-emption map */
#define SHT_ARM_ATTRIBUTES   0x70000003 /* Object file compatibility 
					 * attributes */
#define SHT_ARM_DEBUGOVERLAY 0x70000004 /* See DBGOVL for details */
#define SHT_ARM_OVERLAYSECTION 0x70000005
#define	SHT_MIPS_REGINFO     0x70000006
#define	SHT_MIPS_OPTIONS     0x7000000d
#define	SHT_MIPS_DWARF	     0x7000001e	/* MIPS gcc uses MIPS_DWARF */
#define	SHT_MIPS_XHASH	     0x7000002b	/* MIPS version of GNU_HASH */
#define SHT_HIPROC	     0x7fffffff
#define SHT_LOUSER	     0x80000000 /* Application-specific range */
#define SHT_HIUSER	     0xffffffff

/* sh_flags */
#define SHF_WRITE	     0x00000001 /* Contains writable data */
#define SHF_ALLOC	     0x00000002 /* Occupies memory */
#define SHF_EXECINSTR	     0x00000004 /* Contains executable insns */
#define SHF_MERGE	     0x00000010 /* Might be merged */
#define SHF_STRINGS	     0x00000020 /* Contains nul terminated strings */
#define SHF_INFO_LINK	     0x00000040 /* "sh_info" contains SHT index */
#define SHF_LINK_ORDER	     0x00000080 /* Preserve order after combining */
#define SHF_OS_NONCONFORMING 0x00000100 /* OS specific handling required */
#define SHF_GROUP	     0x00000200 /* Is member of a group */
#define SHF_TLS		     0x00000400 /* Holds thread-local data */
#define SHF_MASKOS	     0x0ff00000 /* Operating system specific values */
#define SHF_MASKPROC	     0xf0000000 /* Processor-specific values */
#define SHF_ORDERED	     0x40000000 /* Ordering requirement (Solaris) */
#define SHF_EXCLUDE	     0x80000000 /* Excluded unless unles ref/alloc
					   (Solaris).*/
/*
 * Symbol Table
 */
typedef struct {
	Elf32_Word	st_name;	/* Symbol name (.strtab index) */
	Elf32_Word	st_value;	/* value of symbol */
	Elf32_Word	st_size;	/* size of symbol */
	Elf_Byte	st_info;	/* type / binding attrs */
	Elf_Byte	st_other;	/* unused */
	Elf32_Half	st_shndx;	/* section index of symbol */
} Elf32_Sym;

typedef struct {
	Elf64_Word	st_name;	/* Symbol name (.strtab index) */
	Elf_Byte	st_info;	/* type / binding attrs */
	Elf_Byte	st_other;	/* unused */
	Elf64_Half	st_shndx;	/* section index of symbol */
	Elf64_Addr	st_value;	/* value of symbol */
	Elf64_Xword	st_size;	/* size of symbol */
} Elf64_Sym;

/* Symbol Table index of the undefined symbol */
#define ELF_SYM_UNDEFINED	0

#define STN_UNDEF		0	/* undefined index */

/* st_info: Symbol Bindings */
#define STB_LOCAL		0	/* local symbol */
#define STB_GLOBAL		1	/* global symbol */
#define STB_WEAK		2	/* weakly defined global symbol */
#define STB_NUM			3

#define STB_LOOS		10	/* Operating system specific range */
#define STB_HIOS		12
#define STB_LOPROC		13	/* Processor-specific range */
#define STB_HIPROC		15

/* st_info: Symbol Types */
#define STT_NOTYPE		0	/* Type not specified */
#define STT_OBJECT		1	/* Associated with a data object */
#define STT_FUNC		2	/* Associated with a function */
#define STT_SECTION		3	/* Associated with a section */
#define STT_FILE		4	/* Associated with a file name */
#define STT_COMMON		5	/* Uninitialised common block */
#define STT_TLS			6	/* Thread local data object */
#define STT_NUM			7

#define STT_LOOS		10	/* Operating system specific range */
#define STT_GNU_IFUNC		10	/* GNU extension: indirect function */
#define STT_HIOS		12
#define STT_LOPROC		13	/* Processor-specific range */
#define STT_HIPROC		15

/* st_other: Visibility Types */
#define STV_DEFAULT		0	/* use binding type */
#define STV_INTERNAL		1	/* not referenced from outside */
#define STV_HIDDEN		2	/* not visible, may be used via ptr */
#define STV_PROTECTED		3	/* visible, not preemptible */
#define STV_EXPORTED		4
#define STV_SINGLETON		5
#define STV_ELIMINATE		6

/* st_info/st_other utility macros */
#define ELF_ST_BIND(info)		((uint32_t)(info) >> 4)
#define ELF_ST_TYPE(info)		((uint32_t)(info) & 0xf)
#define ELF_ST_INFO(bind,type)		((Elf_Byte)(((bind) << 4) | \
					 ((type) & 0xf)))
#define ELF_ST_VISIBILITY(other)	((uint32_t)(other) & 3)

/*
 * Special section indexes
 */
#define SHN_UNDEF	0		/* Undefined section */

#define SHN_LORESERVE	0xff00		/* Reserved range */
#define SHN_ABS		0xfff1		/*  Absolute symbols */
#define SHN_COMMON	0xfff2		/*  Common symbols */
#define SHN_XINDEX	0xffff		/* Escape -- index stored elsewhere */
#define SHN_HIRESERVE	0xffff

#define SHN_LOPROC	0xff00		/* Processor-specific range */
#define SHN_HIPROC	0xff1f
#define SHN_LOOS	0xff20		/* Operating system specific range */
#define SHN_HIOS	0xff3f

#define SHN_MIPS_ACOMMON 0xff00
#define SHN_MIPS_TEXT	0xff01
#define SHN_MIPS_DATA	0xff02
#define SHN_MIPS_SCOMMON 0xff03

/*
 * Relocation Entries
 */
typedef struct {
	Elf32_Word	r_offset;	/* where to do it */
	Elf32_Word	r_info;		/* index & type of relocation */
} Elf32_Rel;

typedef struct {
	Elf32_Word	r_offset;	/* where to do it */
	Elf32_Word	r_info;		/* index & type of relocation */
	Elf32_Sword	r_addend;	/* adjustment value */
} Elf32_Rela;

/* r_info utility macros */
#define ELF32_R_SYM(info)	((info) >> 8)
#define ELF32_R_TYPE(info)	((info) & 0xff)
#define ELF32_R_INFO(sym, type) (((sym) << 8) + (unsigned char)(type))

typedef struct {
	Elf64_Addr	r_offset;	/* where to do it */
	Elf64_Xword	r_info;		/* index & type of relocation */
} Elf64_Rel;

typedef struct {
	Elf64_Addr	r_offset;	/* where to do it */
	Elf64_Xword	r_info;		/* index & type of relocation */
	Elf64_Sxword	r_addend;	/* adjustment value */
} Elf64_Rela;

/* r_info utility macros */
#define ELF64_R_SYM(info)	((info) >> 32)
#define ELF64_R_TYPE(info)	((info) & 0xffffffff)
#define ELF64_R_INFO(sym,type)	(((sym) << 32) + (type))

/*
 * Move entries
 */
typedef struct {
	Elf32_Lword	m_value;	/* symbol value */
	Elf32_Word	m_info;		/* size + index */
	Elf32_Word	m_poffset;	/* symbol offset */
	Elf32_Half	m_repeat;	/* repeat count */
	Elf32_Half	m_stride;	/* stride info */
} Elf32_Move;

#define ELF32_M_SYM(info)	((info) >> 8)
#define ELF32_M_SIZE(info)	((info) & 0xff)
#define ELF32_M_INFO(sym, size) (((sym) << 8) + (unsigned char)(size))

typedef struct {
	Elf64_Lword	m_value;	/* symbol value */
	Elf64_Xword	m_info;		/* size + index */
	Elf64_Xword	m_poffset;	/* symbol offset */
	Elf64_Word	m_repeat;	/* repeat count */
	Elf64_Word	m_stride;	/* stride info */
} Elf64_Move;

#define ELF64_M_SYM(info)	((info) >> 8)
#define ELF64_M_SIZE(info)	((info) & 0xff)
#define ELF64_M_INFO(sym, size) (((sym) << 8) + (unsigned char)(size))

/*
 * Hardware/software capabilities entry
 */
typedef struct {
	Elf32_Word		c_tag;	/* entry tag value */
	union {
		Elf32_Addr	c_ptr;
		Elf32_Word	c_val;
	} c_un;
} Elf32_Cap;

typedef struct {
	Elf64_Xword		c_tag;	/* entry tag value */
	union {
		Elf64_Addr	c_ptr;
		Elf64_Xword	c_val;
	} c_un;
} Elf64_Cap;

/*
 * Dynamic Section structure array
 */
typedef struct {
	Elf32_Word		d_tag;	/* entry tag value */
	union {
		Elf32_Addr	d_ptr;
		Elf32_Word	d_val;
	} d_un;
} Elf32_Dyn;

typedef struct {
	Elf64_Xword		d_tag;	/* entry tag value */
	union {
		Elf64_Addr	d_ptr;
		Elf64_Xword	d_val;
	} d_un;
} Elf64_Dyn;

/* d_tag */
#define DT_NULL		0	/* Marks end of dynamic array */
#define DT_NEEDED	1	/* Name of needed library (DT_STRTAB offset) */
#define DT_PLTRELSZ	2	/* Size, in bytes, of relocations in PLT */
#define DT_PLTGOT	3	/* Address of PLT and/or GOT */
#define DT_HASH		4	/* Address of symbol hash table */
#define DT_STRTAB	5	/* Address of string table */
#define DT_SYMTAB	6	/* Address of symbol table */
#define DT_RELA		7	/* Address of Rela relocation table */
#define DT_RELASZ	8	/* Size, in bytes, of DT_RELA table */
#define DT_RELAENT	9	/* Size, in bytes, of one DT_RELA entry */
#define DT_STRSZ	10	/* Size, in bytes, of DT_STRTAB table */
#define DT_SYMENT	11	/* Size, in bytes, of one DT_SYMTAB entry */
#define DT_INIT		12	/* Address of initialization function */
#define DT_FINI		13	/* Address of termination function */
#define DT_SONAME	14	/* Shared object name (DT_STRTAB offset) */
#define DT_RPATH	15	/* Library search path (DT_STRTAB offset) */
#define DT_SYMBOLIC	16	/* Start symbol search within local object */
#define DT_REL		17	/* Address of Rel relocation table */
#define DT_RELSZ	18	/* Size, in bytes, of DT_REL table */
#define DT_RELENT	19	/* Size, in bytes, of one DT_REL entry */
#define DT_PLTREL	20	/* Type of PLT relocation entries */
#define DT_DEBUG	21	/* Used for debugging; unspecified */
#define DT_TEXTREL	22	/* Relocations might modify non-writable seg */
#define DT_JMPREL	23	/* Address of relocations associated with PLT */
#define DT_BIND_NOW	24	/* Process all relocations at load-time */
#define DT_INIT_ARRAY	25	/* Address of initialization function array */
#define DT_FINI_ARRAY	26	/* Size, in bytes, of DT_INIT_ARRAY array */
#define DT_INIT_ARRAYSZ 27	/* Address of termination function array */
#define DT_FINI_ARRAYSZ 28	/* Size, in bytes, of DT_FINI_ARRAY array*/
#define DT_RUNPATH	29	/* overrides DT_RPATH */
#define DT_FLAGS	30	/* Encodes ORIGIN, SYMBOLIC, TEXTREL, BIND_NOW, STATIC_TLS */
#define DT_ENCODING	31	/* ??? */
#define DT_PREINIT_ARRAY 32	/* Address of pre-init function array */
#define DT_PREINIT_ARRAYSZ 33	/* Size, in bytes, of DT_PREINIT_ARRAY array */
#define DT_NUM		34

#define DT_LOOS		0x60000000	/* Operating system specific range */
#define DT_GNU_HASH	0x6ffffef5	/* GNU-style hash table */
#define DT_VERSYM	0x6ffffff0	/* Symbol versions */
#define DT_FLAGS_1	0x6ffffffb	/* ELF dynamic flags */
#define DT_VERDEF	0x6ffffffc	/* Versions defined by file */
#define DT_VERDEFNUM	0x6ffffffd	/* Number of versions defined by file */
#define DT_VERNEED	0x6ffffffe	/* Versions needed by file */
#define DT_VERNEEDNUM	0x6fffffff	/* Number of versions needed by file */
#define DT_HIOS		0x6fffffff
#define DT_LOPROC	0x70000000	/* Processor-specific range */
#define DT_MIPS_XHASH	0x70000036	/* MIPS version of GNU_HASH */
#define DT_HIPROC	0x7fffffff

/* Flag values for DT_FLAGS */
#define DF_ORIGIN	0x00000001	/* uses $ORIGIN */
#define DF_SYMBOLIC	0x00000002	/* */
#define DF_TEXTREL	0x00000004	/* */
#define DF_BIND_NOW	0x00000008	/* */
#define DF_STATIC_TLS	0x00000010	/* */

/* Flag values for DT_FLAGS_1 */
#define	DF_1_NOW	0x00000001	/* Same as DF_BIND_NOW */
#define	DF_1_GLOBAL	0x00000002	/* Unused */
#define	DF_1_GROUP	0x00000004	/* Is member of group */
#define	DF_1_NODELETE	0x00000008	/* Cannot be deleted from process */
#define	DF_1_LOADFLTR	0x00000010	/* Immediate loading of filters */
#define	DF_1_INITFIRST	0x00000020	/* init/fini takes priority */
#define	DF_1_NOOPEN	0x00000040	/* Do not allow loading on dlopen() */
#define	DF_1_ORIGIN	0x00000080 	/* Require $ORIGIN processing */
#define	DF_1_DIRECT	0x00000100	/* Enable direct bindings */
#define	DF_1_INTERPOSE 	0x00000400	/* Is an interposer */
#define	DF_1_NODEFLIB	0x00000800 	/* Ignore default library search path */
#define	DF_1_NODUMP	0x00001000 	/* Cannot be dumped with dldump(3C) */
#define	DF_1_CONFALT	0x00002000 	/* Configuration alternative */
#define	DF_1_ENDFILTEE	0x00004000	/* Filtee ends filter's search */
#define	DF_1_DISPRELDNE	0x00008000	/* Did displacement relocation */
#define	DF_1_DISPRELPND 0x00010000	/* Pending displacement relocation */
#define	DF_1_NODIRECT	0x00020000 	/* Has non-direct bindings */
#define	DF_1_IGNMULDEF	0x00040000	/* Used internally */
#define	DF_1_NOKSYMS	0x00080000	/* Used internally */
#define	DF_1_NOHDR	0x00100000	/* Used internally */
#define	DF_1_EDITED	0x00200000	/* Has been modified since build */
#define	DF_1_NORELOC	0x00400000 	/* Used internally */
#define	DF_1_SYMINTPOSE 0x00800000 	/* Has individual symbol interposers */
#define	DF_1_GLOBAUDIT	0x01000000	/* Require global auditing */
#define	DF_1_SINGLETON	0x02000000	/* Has singleton symbols */
#define	DF_1_STUB	0x04000000	/* Stub */
#define	DF_1_PIE	0x08000000	/* Position Independent Executable */

/*
 * Auxiliary Vectors
 */
typedef struct {
	Elf32_Word	a_type;				/* 32-bit id */
	Elf32_Word	a_v;				/* 32-bit id */
} Aux32Info;

typedef struct {
	Elf64_Word	a_type;		/* 32-bit id */
	Elf64_Xword	a_v;		/* 64-bit id */
} Aux64Info;

/* a_type */
#define AT_NULL		0	/* Marks end of array */
#define AT_IGNORE	1	/* No meaning, a_un is undefined */
#define AT_EXECFD	2	/* Open file descriptor of object file */
#define AT_PHDR		3	/* &phdr[0] */
#define AT_PHENT	4	/* sizeof(phdr[0]) */
#define AT_PHNUM	5	/* # phdr entries */
#define AT_PAGESZ	6	/* PAGESIZE */
#define AT_BASE		7	/* Interpreter base addr */
#define AT_FLAGS	8	/* Processor flags */
#define AT_ENTRY	9	/* Entry address of executable */
#define AT_DCACHEBSIZE	10	/* Data cache block size */
#define AT_ICACHEBSIZE	11	/* Instruction cache block size */
#define AT_UCACHEBSIZE	12	/* Unified cache block size */
#define AT_STACKBASE	13	/* Base address of the main thread */

	/* Vendor specific */
#define AT_MIPS_NOTELF	10	/* XXX a_val != 0 -> MIPS XCOFF executable */

#define AT_EUID		2000	/* euid (solaris compatible numbers) */
#define AT_RUID		2001	/* ruid (solaris compatible numbers) */
#define AT_EGID		2002	/* egid (solaris compatible numbers) */
#define AT_RGID		2003	/* rgid (solaris compatible numbers) */

	/* Solaris kernel specific */
#define AT_SUN_LDELF	2004	/* dynamic linker's ELF header */
#define AT_SUN_LDSHDR	2005	/* dynamic linker's section header */
#define AT_SUN_LDNAME	2006	/* dynamic linker's name */
#define AT_SUN_LPGSIZE	2007	/* large pagesize */

	/* Other information */
#define AT_SUN_PLATFORM 2008	/* sysinfo(SI_PLATFORM) */
#define AT_SUN_HWCAP	2009	/* process hardware capabilities */
#define AT_SUN_IFLUSH	2010	/* do we need to flush the instruction cache? */
#define AT_SUN_CPU	2011	/* CPU name */
	/* ibcs2 emulation band aid */
#define AT_SUN_EMUL_ENTRY 2012	/* coff entry point */
#define AT_SUN_EMUL_EXECFD 2013 /* coff file descriptor */
	/* Executable's fully resolved name */
#define AT_SUN_EXECNAME 2014

/*
 * The header for GNU-style hash sections.
 */
typedef struct {
	uint32_t	gh_nbuckets;	/* Number of hash buckets. */
	uint32_t	gh_symndx;	/* First visible symbol in .dynsym. */
	uint32_t	gh_maskwords;	/* #maskwords used in bloom filter. */
	uint32_t	gh_shift2;	/* Bloom filter shift count. */
} Elf_GNU_Hash_Header;

/*
 * Note Headers
 */
typedef struct {
	Elf32_Word n_namesz;
	Elf32_Word n_descsz;
	Elf32_Word n_type;
} Elf32_Nhdr;

typedef struct {
	Elf64_Word n_namesz;
	Elf64_Word n_descsz;
	Elf64_Word n_type;
} Elf64_Nhdr;

#define ELF_NOTE_GNU_NAMESZ		4
#define ELF_NOTE_GNU_NAME		"GNU\0"

/*
 * GNU-specific note type: ABI tag
 * name: GNU\0
 * namesz: 4
 * desc:
 *	word[0]: OS tag
 *	word[1]: major version
 *	word[2]: minor version
 *	word[3]: teeny version
 * descsz: 16
 */
/* GNU-specific note name and description sizes */
#define ELF_NOTE_TYPE_ABI_TAG		1
#define ELF_NOTE_ABI_NAME		ELF_NOTE_GNU_NAME
#define ELF_NOTE_ABI_NAMESZ		ELF_NOTE_GNU_NAMESZ
#define ELF_NOTE_ABI_DESCSZ		16
/* GNU-specific OS/version value stuff */
#define ELF_NOTE_ABI_OS_LINUX		0
#define ELF_NOTE_ABI_OS_HURD		1
#define ELF_NOTE_ABI_OS_SOLARIS		2
#define ELF_NOTE_ABI_OS_KFREEBSD	3
#define ELF_NOTE_ABI_OS_KNETBSD		4

/* Old gcc style, under the ABI tag */
#define ELF_NOTE_OGCC_NAMESZ		8
#define ELF_NOTE_OGCC_NAME		"01.01\0\0\0\0"
#define ELF_NOTE_OGCC_DESCSZ		0

/*
 * GNU-specific note type: Hardware capabilities
 * name: GNU\0
 * namesz: 4
 * desc:
 *	word[0]: Number of entries
 *	word[1]: Bitmask of enabled entries
 *	Followed by a byte id, and a NUL terminated string per entry
 * descsz: variable
 */
#define ELF_NOTE_TYPE_GNU_HWCAP		2

/*
 * GNU-specific note type: Build ID generated by ld
 * name: GNU\0
 * desc:
 *	word[0..4] SHA1 [default] 
 * or
 *	word[0..3] md5 or uuid
 * descsz: 16 or 20
 */
#define ELF_NOTE_TYPE_GNU_BUILD_ID	3

/* SuSE-specific note type: ABI
 * name: SuSE\0
 * namesz: 5
 * desc:
 *	half[0] = MMmm
 *
 *	M = product major version
 *	m = product minor version
 * descsz: 2
 */
#define ELF_NOTE_TYPE_SUSE_TAG	1
/* SuSE-specific note name and description sizes */
#define ELF_NOTE_SUSE_NAMESZ	5
#define ELF_NOTE_SUSE_DESCSZ	2
/* SuSE-specific note name */
#define ELF_NOTE_SUSE_NAME		"SuSE\0"

/* SuSE-specific note type: version
 * name: SuSE\0\0\0\0
 * namesz: 8
 * desc: 
 *	word[0] = VVTTMMmm
 *
 *	V = version of following data
 *	T = product type: [box, sles, nld, whatever]
 *	M = product major version
 *	m = product minor version
 * descsz: 8
 */
#define ELF_NOTE_TYPE_SUSE_VERSION_TAG	0x45537553	/* SuSE in LE */
/* SuSE-specific note name and description sizes */
#define ELF_NOTE_SUSE_VERSION_NAMESZ	8
#define ELF_NOTE_SUSE_VERSION_DESCSZ	8
/* SuSE-specific note name */
#define ELF_NOTE_SUSE_VERSION_NAME		"SuSE\0\0\0\0"

/* Go-specific note type: buildid
 * name: Go\0\0
 * namesz: 4
 * desc: 
 *	words[10]
 * descsz: 40
 */
#define ELF_NOTE_TYPE_GO_BUILDID_TAG	4
#define ELF_NOTE_GO_BUILDID_NAMESZ	4
#define ELF_NOTE_GO_BUILDID_DESCSZ	40
#define ELF_NOTE_GO_BUILDID_NAME	"Go\0\0"

/*
 * FDO-specific note type: packaging metadata
 * name: FDO\0
 * namesz: 4
 * desc:
 *	a single JSON object encoded as a zero-terminated UTF-8 string
 *	(see https://systemd.io/COREDUMP_PACKAGE_METADATA/)
 * descsz: variable
 */
#define	ELF_NOTE_TYPE_FDO_PACKAGING_METADATA	0xcafe1a7e
#define	ELF_NOTE_FDO_PACKAGING_METADATA_NAMESZ	4
#define	ELF_NOTE_FDO_PACKAGING_METADATA_NAME	"FDO\0"

/* NetBSD-specific note type: NetBSD ABI version.
 * name: NetBSD\0\0
 * namesz: 8
 * desc: 
 *	word[0]: MMmmrrpp00
 *
 *	M = major version
 *	m = minor version
 *	r = release ["",A-Z,Z[A-Z] but numeric]
 *	p = patchlevel
 * descsz: 4
 */
#define ELF_NOTE_TYPE_NETBSD_TAG	1
/* NetBSD-specific note name and description sizes */
#define ELF_NOTE_NETBSD_NAMESZ		7
#define ELF_NOTE_NETBSD_DESCSZ		4
/* NetBSD-specific note name */
#define ELF_NOTE_NETBSD_NAME		"NetBSD\0\0"

/* NetBSD-specific note type: Emulation (obsolete; last used early 2000)
 * name: NetBSD\0\0
 * namesz: 8
 * desc:
 *	"netbsd\0"
 *	
 * descsz: 8
 */
#define ELF_NOTE_TYPE_NETBSD_EMUL_TAG	2
#define ELF_NOTE_NETBSD_EMUL_NAMESZ	7
#define ELF_NOTE_NETBSD_EMUL_DESCSZ	7
/* NetBSD-specific note name */
#define ELF_NOTE_NETBSD_EMUL_NAME	"NetBSD\0\0"

/*
 * NetBSD-specific note type: PaX.
 * There should be 1 NOTE per executable.
 * name: PaX\0
 * namesz: 4
 * desc:
 *	word[0]: capability bitmask
 * descsz: 4
 */
#define ELF_NOTE_TYPE_PAX_TAG		3
#define ELF_NOTE_PAX_MPROTECT		0x01	/* Force enable Mprotect */
#define ELF_NOTE_PAX_NOMPROTECT		0x02	/* Force disable Mprotect */
#define ELF_NOTE_PAX_GUARD		0x04	/* Force enable Segvguard */
#define ELF_NOTE_PAX_NOGUARD		0x08	/* Force disable Segvguard */
#define ELF_NOTE_PAX_ASLR		0x10	/* Force enable ASLR */
#define ELF_NOTE_PAX_NOASLR		0x20	/* Force disable ASLR */
#define ELF_NOTE_PAX_NAMESZ		4
#define ELF_NOTE_PAX_NAME		"PaX\0"
#define ELF_NOTE_PAX_DESCSZ		4

/*
 * NetBSD-specific core file information.
 *
 * NetBSD ELF core files use notes to provide information about
 * the process's state.	 The note name is "NetBSD-CORE" for
 * information that is global to the process, and "NetBSD-CORE@nn",
 * where "nn" is the lwpid of the LWP that the information belongs
 * to (such as register state).
 *
 * We use the following note identifiers:
 *
 *	ELF_NOTE_NETBSD_CORE_PROCINFO
 *		Note is a "netbsd_elfcore_procinfo" structure.
 *	ELF_NOTE_NETBSD_CORE_AUXV
 *		Note is an array of AuxInfo structures.
 *
 * We also use ptrace(2) request numbers (the ones that exist in
 * machine-dependent space) to identify register info notes.  The
 * info in such notes is in the same format that ptrace(2) would
 * export that information.
 *
 * Please try to keep the members of this structure nicely aligned,
 * and if you add elements, add them to the end and bump the version.
 */

#define ELF_NOTE_NETBSD_CORE_NAME	"NetBSD-CORE"

#define ELF_NOTE_NETBSD_CORE_PROCINFO	1
#define ELF_NOTE_NETBSD_CORE_AUXV	2

#define NETBSD_ELFCORE_PROCINFO_VERSION 1

struct netbsd_elfcore_procinfo {
	/* Version 1 fields start here. */
	uint32_t	cpi_version;		/* our version */
	uint32_t	cpi_cpisize;		/* sizeof(this struct) */
	uint32_t	cpi_signo;		/* killing signal */
	uint32_t	cpi_sigcode;		/* signal code */
	uint32_t	cpi_sigpend[4];		/* pending signals */
	uint32_t	cpi_sigmask[4];		/* blocked signals */
	uint32_t	cpi_sigignore[4];	/* ignored signals */
	uint32_t	cpi_sigcatch[4];	/* caught signals */
	int32_t		cpi_pid;		/* process ID */
	int32_t		cpi_ppid;		/* parent process ID */
	int32_t		cpi_pgrp;		/* process group ID */
	int32_t		cpi_sid;		/* session ID */
	uint32_t	cpi_ruid;		/* real user ID */
	uint32_t	cpi_euid;		/* effective user ID */
	uint32_t	cpi_svuid;		/* saved user ID */
	uint32_t	cpi_rgid;		/* real group ID */
	uint32_t	cpi_egid;		/* effective group ID */
	uint32_t	cpi_svgid;		/* saved group ID */
	uint32_t	cpi_nlwps;		/* number of LWPs */
	int8_t		cpi_name[32];		/* copy of p->p_comm */
	/* Add version 2 fields below here. */
	int32_t		cpi_siglwp;	/* LWP target of killing signal */
};

/*
 * NetBSD-specific note type: MACHINE_ARCH.
 * There should be 1 NOTE per executable.
 * name:	NetBSD\0
 * namesz:	7
 * desc:	string
 * descsz:	variable
 */
#define ELF_NOTE_TYPE_MARCH_TAG		5
/* NetBSD-specific note name and description sizes */
#define ELF_NOTE_MARCH_NAMESZ		ELF_NOTE_NETBSD_NAMESZ
/* NetBSD-specific note name */
#define ELF_NOTE_MARCH_NAME		ELF_NOTE_NETBSD_NAME

/*
 * NetBSD-specific note type: MCMODEL
 * There should be 1 NOTE per executable.
 * name:	NetBSD\0
 * namesz:	7
 * code model:	string
 */

#define ELF_NOTE_TYPE_MCMODEL_TAG	6
/* NetBSD-specific note name and description sizes */
#define ELF_NOTE_MCMODEL_NAMESZ		ELF_NOTE_NETBSD_NAMESZ
/* NetBSD-specific note name */
#define ELF_NOTE_MCMODEL_NAME		ELF_NOTE_NETBSD_NAME


#if !defined(ELFSIZE)
# if defined(_RUMPKERNEL) || !defined(_KERNEL)
#  define ELFSIZE ARCH_ELFSIZE
# else
#  define ELFSIZE KERN_ELFSIZE
# endif
#endif

#if defined(ELFSIZE)
#define CONCAT(x,y)	__CONCAT(x,y)
#define ELFNAME(x)	CONCAT(elf,CONCAT(ELFSIZE,CONCAT(_,x)))
#define ELFNAME2(x,y)	CONCAT(x,CONCAT(_elf,CONCAT(ELFSIZE,CONCAT(_,y))))
#define ELFNAMEEND(x)	CONCAT(x,CONCAT(_elf,ELFSIZE))
#define ELFDEFNNAME(x)	CONCAT(ELF,CONCAT(ELFSIZE,CONCAT(_,x)))
#define	ElfW(x)		CONCAT(Elf,CONCAT(ELFSIZE,CONCAT(_,x)))
#endif

#if defined(ELFSIZE) && (ELFSIZE == 32)
#define Elf_Ehdr	Elf32_Ehdr
#define Elf_Phdr	Elf32_Phdr
#define Elf_Shdr	Elf32_Shdr
#define Elf_Sym		Elf32_Sym
#define Elf_Rel		Elf32_Rel
#define Elf_Rela	Elf32_Rela
#define Elf_Dyn		Elf32_Dyn
#define Elf_Word	Elf32_Word
#define Elf_Sword	Elf32_Sword
#define Elf_Half	Elf32_Half
#define Elf_Addr	Elf32_Addr
#define Elf_Off		Elf32_Off
#define Elf_SOff	Elf32_SOff
#define Elf_Nhdr	Elf32_Nhdr
#define Elf_Verdef	Elf32_Verdef
#define Elf_Verdaux	Elf32_Verdaux
#define Elf_Verneed	Elf32_Verneed
#define Elf_Vernaux	Elf32_Vernaux
#define Elf_Versym	Elf32_Versym

#define ELF_R_SYM	ELF32_R_SYM
#define ELF_R_TYPE	ELF32_R_TYPE
#define ELFCLASS	ELFCLASS32

#define AuxInfo		Aux32Info
#elif defined(ELFSIZE) && (ELFSIZE == 64)
#define Elf_Ehdr	Elf64_Ehdr
#define Elf_Phdr	Elf64_Phdr
#define Elf_Shdr	Elf64_Shdr
#define Elf_Sym		Elf64_Sym
#define Elf_Rel		Elf64_Rel
#define Elf_Rela	Elf64_Rela
#define Elf_Dyn		Elf64_Dyn
#define Elf_Word	Elf64_Word
#define Elf_Sword	Elf64_Sword
#define Elf_Half	Elf64_Half
#define Elf_Addr	Elf64_Addr
#define Elf_Off		Elf64_Off
#define Elf_SOff	Elf64_SOff
#define Elf_Nhdr	Elf64_Nhdr
#define Elf_Verdef	Elf64_Verdef
#define Elf_Verdaux	Elf64_Verdaux
#define Elf_Verneed	Elf64_Verneed
#define Elf_Vernaux	Elf64_Vernaux
#define Elf_Versym	Elf64_Versym

#define ELF_R_SYM	ELF64_R_SYM
#define ELF_R_TYPE	ELF64_R_TYPE
#define ELFCLASS	ELFCLASS64

#define AuxInfo		Aux64Info
#endif

#ifndef Elf_Symindx
#define Elf_Symindx	uint32_t
#endif

#define ELF32_ST_BIND(info)		ELF_ST_BIND(info)
#define ELF32_ST_TYPE(info)		ELF_ST_TYPE(info)
#define ELF32_ST_INFO(bind,type)	ELF_ST_INFO(bind,type)
#define ELF32_ST_VISIBILITY(other)	ELF_ST_VISIBILITY(other)

#define ELF64_ST_BIND(info)		ELF_ST_BIND(info)
#define ELF64_ST_TYPE(info)		ELF_ST_TYPE(info)
#define ELF64_ST_INFO(bind,type)	ELF_ST_INFO(bind,type)
#define ELF64_ST_VISIBILITY(other)	ELF_ST_VISIBILITY(other)

typedef struct {
	Elf32_Half	si_boundto;	/* direct bindings - symbol bound to */
	Elf32_Half	si_flags;	/* per symbol flags */
} Elf32_Syminfo;

typedef struct {
	Elf64_Word	si_boundto;	/* direct bindings - symbol bound to */
	Elf64_Word	si_flags;	/* per symbol flags */
} Elf64_Syminfo;

#define SYMINFO_FLG_DIRECT	0x0001	/* symbol ref has direct association
					   to object containing definition */
#define SYMINFO_FLG_PASSTHRU	0x0002	/* ignored - see SYMINFO_FLG_FILTER */
#define SYMINFO_FLG_COPY	0x0004	/* symbol is a copy-reloc */
#define SYMINFO_FLG_LAZYLOAD	0x0008	/* object containing defn should be
					   lazily-loaded */
#define SYMINFO_FLG_DIRECTBIND	0x0010	/* ref should be bound directly to
					   object containing definition */
#define SYMINFO_FLG_NOEXTDIRECT 0x0020	/* don't let an external reference
					   directly bind to this symbol */
#define SYMINFO_FLG_FILTER	0x0002	/* symbol ref is associated to a */
#define SYMINFO_FLG_AUXILIARY	0x0040	/*	standard or auxiliary filter */

#define SYMINFO_BT_SELF		0xffff	/* symbol bound to self */
#define SYMINFO_BT_PARENT	0xfffe	/* symbol bound to parent */
#define SYMINFO_BT_NONE		0xfffd	/* no special symbol binding */
#define SYMINFO_BT_EXTERN	0xfffc	/* symbol defined as external */
#define SYMINFO_BT_LOWRESERVE	0xff00	/* beginning of reserved entries */

#define SYMINFO_NONE		0	/* Syminfo version */
#define SYMINFO_CURRENT		1
#define SYMINFO_NUM		2

/*
 * These constants are used for Elf32_Verdef struct's version number.  
 */
#define VER_DEF_NONE		0
#define VER_DEF_CURRENT		1

/*
 * These constants are used for Elf32_Verdef struct's vd_ndx.
 */
#define VER_DEF_IDX(x)		VER_NDX(x)

/*
 * These constants are used for Elf32_Verdef struct's vd_flags.	 
 */
#define VER_FLG_BASE		0x1
#define VER_FLG_WEAK		0x2

/*
 * These are used in an Elf32_Versym field.
 */
#define VER_NDX_LOCAL		0
#define VER_NDX_GLOBAL		1
#define VER_NDX_GIVEN		2

/*
 * These constants are used for Elf32_Verneed struct's version number.	
 */
#define VER_NEED_NONE		0
#define VER_NEED_CURRENT	1

/*
 * These constants are used for Elf32_Vernaux struct's vna_other.
 */
#define VER_NEED_HIDDEN		VER_NDX_HIDDEN
#define VER_NEED_IDX(x)		VER_NDX(x)

/* index */
#define VER_NDX_HIDDEN		0x8000
#define VER_NDX(x)		((x) & ~VER_NDX_HIDDEN)

/*
 * GNU Extension hiding symbol
 */
#define VERSYM_HIDDEN		0x8000
#define VERSYM_VERSION		0x7fff

#define ELF_VER_CHR		'@'

/*
 * These are current size independent.
 */

typedef struct {
	Elf32_Half	vd_version;	/* version number of structure */
	Elf32_Half	vd_flags;	/* flags (VER_FLG_*) */
	Elf32_Half	vd_ndx;		/* version index */
	Elf32_Half	vd_cnt;		/* number of verdaux entries */
	Elf32_Word	vd_hash;	/* hash of name */
	Elf32_Word	vd_aux;		/* offset to verdaux entries */
	Elf32_Word	vd_next;	/* offset to next verdef */
} Elf32_Verdef;
typedef Elf32_Verdef	Elf64_Verdef;

typedef struct {
	Elf32_Word	vda_name;	/* string table offset of name */
	Elf32_Word	vda_next;	/* offset to verdaux */
} Elf32_Verdaux;
typedef Elf32_Verdaux	Elf64_Verdaux;

typedef struct {
	Elf32_Half	vn_version;	/* version number of structure */
	Elf32_Half	vn_cnt;		/* number of vernaux entries */
	Elf32_Word	vn_file;	/* string table offset of library name*/
	Elf32_Word	vn_aux;		/* offset to vernaux entries */
	Elf32_Word	vn_next;	/* offset to next verneed */
} Elf32_Verneed;
typedef Elf32_Verneed	Elf64_Verneed;

typedef struct {
	Elf32_Word	vna_hash;	/* Hash of dependency name */
	Elf32_Half	vna_flags;	/* flags (VER_FLG_*) */
	Elf32_Half	vna_other;	/* unused */
	Elf32_Word	vna_name;	/* string table offset to version name*/
	Elf32_Word	vna_next;	/* offset to next vernaux */
} Elf32_Vernaux;
typedef Elf32_Vernaux	Elf64_Vernaux;

typedef struct {
	Elf32_Half	vs_vers;
} Elf32_Versym;
typedef Elf32_Versym	Elf64_Versym;

#ifdef _KERNEL

/*
 * Arbitrary limits to avoid DoS for excessive memory allocation.
 */
#define ELF_MAXPHNUM	128
#define ELF_MAXSHNUM	32768
#define ELF_MAXNOTESIZE	1024

#define ELF_AUX_ENTRIES 15	/* Max size of aux array passed to loader */
#define ELF32_NO_ADDR	(~(Elf32_Addr)0) /* Indicates addr. not yet filled in */
#define ELF32_LINK_ADDR ((Elf32_Addr)-2) /* advises to use link address */
#define ELF64_NO_ADDR	(~(Elf64_Addr)0) /* Indicates addr. not yet filled in */
#define ELF64_LINK_ADDR ((Elf64_Addr)-2) /* advises to use link address */

#if defined(ELFSIZE) && (ELFSIZE == 64)
#define ELF_NO_ADDR	ELF64_NO_ADDR
#define ELF_LINK_ADDR	ELF64_LINK_ADDR
#elif defined(ELFSIZE) && (ELFSIZE == 32)
#define ELF_NO_ADDR	ELF32_NO_ADDR
#define ELF_LINK_ADDR	ELF32_LINK_ADDR
#endif

#ifndef ELF32_EHDR_FLAGS_OK
#define ELF32_EHDR_FLAGS_OK(eh) 1
#endif

#ifndef ELF64_EHDR_FLAGS_OK
#define ELF64_EHDR_FLAGS_OK(eh) 1
#endif

#if defined(ELFSIZE) && (ELFSIZE == 64)
#define ELF_EHDR_FLAGS_OK(eh)	ELF64_EHDR_FLAGS_OK(eh)
#else
#define ELF_EHDR_FLAGS_OK(eh)	ELF32_EHDR_FLAGS_OK(eh)
#endif

#if defined(ELFSIZE)
struct elf_args {
	Elf_Addr	arg_entry;	/* program entry point */
	Elf_Addr	arg_interp;	/* Interpreter load address */
	Elf_Addr	arg_phaddr;	/* program header address */
	Elf_Addr	arg_phentsize;	/* Size of program header */
	Elf_Addr	arg_phnum;	/* Number of program headers */
};
#endif

#ifdef _KERNEL_OPT
#include "opt_execfmt.h"
#endif

struct ps_strings;
struct coredump_iostate;
struct note_state;
struct exec_package;

#ifdef EXEC_ELF32
int	exec_elf32_makecmds(struct lwp *, struct exec_package *);
int	elf32_populate_auxv(struct lwp *, struct exec_package *, char **);
int	elf32_copyargs(struct lwp *, struct exec_package *,
    struct ps_strings *, char **, void *);

int	elf32_check_header(Elf32_Ehdr *);
#endif

int	real_coredump_elf32(struct lwp *, struct coredump_iostate *);
int	coredump_elf32(struct lwp *, struct coredump_iostate *);
void	coredump_savenote_elf32(struct note_state *, unsigned int,
	    const char *, void *, size_t);


#ifdef EXEC_ELF64
int	exec_elf64_makecmds(struct lwp *, struct exec_package *);
int	elf64_populate_auxv(struct lwp *, struct exec_package *, char **);
int	elf64_copyargs(struct lwp *, struct exec_package *,
    struct ps_strings *, char **, void *);

int	elf64_check_header(Elf64_Ehdr *);
#endif

int	real_coredump_elf64(struct lwp *, struct coredump_iostate *);
int	coredump_elf64(struct lwp *, struct coredump_iostate *);
void	coredump_savenote_elf64(struct note_state *, unsigned int,
	    const char *, void *, size_t);


#endif /* _KERNEL */

#endif /* !_SYS_EXEC_ELF_H_ */