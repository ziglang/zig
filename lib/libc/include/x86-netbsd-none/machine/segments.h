/*	$NetBSD: segments.h,v 1.70 2022/05/18 13:56:32 andvar Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)segments.h	7.1 (Berkeley) 5/9/91
 */

/*-
 * Copyright (c) 1995, 1997
 *	Charles M. Hannum.  All rights reserved.
 * Copyright (c) 1989, 1990 William F. Jolitz
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)segments.h	7.1 (Berkeley) 5/9/91
 */

/*
 * 386 Segmentation Data Structures and definitions
 *	William F. Jolitz (william@ernie.berkeley.edu) 6/20/1989
 */

#ifndef _I386_SEGMENTS_H_
#define _I386_SEGMENTS_H_
#ifdef _KERNEL_OPT
#include "opt_xen.h"
#endif

/*
 * Selectors
 */

#define ISPL(s)		((s) & SEL_RPL)	/* what is the priority level of a selector */
#ifndef XENPV
#define SEL_KPL		0		/* kernel privilege level */
#else
#define SEL_XEN		0		/* Xen privilege level */
#define SEL_KPL		1		/* kernel privilege level */
#endif /* XENPV */
#define SEL_UPL		3		/* user privilege level */
#define SEL_RPL		3		/* requester's privilege level mask */
#ifdef XENPV
#define CHK_UPL		2		/* user privilege level mask */
#else
#define CHK_UPL		SEL_RPL
#endif /* XENPV */
#define ISLDT(s)	((s) & SEL_LDT)	/* is it local or global */
#define SEL_LDT		4		/* local descriptor table */

#define IOPL_KPL	SEL_KPL

/* Dynamically allocated TSSs and LDTs start (byte offset) */
#define DYNSEL_START	(NGDT << 3)

#define IDXSEL(s)	(((s) >> 3) & 0x1fff)		/* index of selector */
#define IDXSELN(s)	(((s) >> 3))			/* index of selector */
#define IDXDYNSEL(s)	((((s) & ~SEL_RPL) - DYNSEL_START) >> 3)

#define GSEL(s,r)	(((s) << 3) | r)		/* a global selector */
#define GSYSSEL(s,r)	GSEL(s,r)			/* compat with amd64 */
#define GDYNSEL(s,r)	((((s) << 3) + DYNSEL_START) | r | SEL_KPL)

#define LSEL(s,r)	(((s) << 3) | r | SEL_LDT)	/* a local selector */

#define USERMODE(c)		(ISPL(c) == SEL_UPL)
#define KERNELMODE(c)		(ISPL(c) == SEL_KPL)

#ifndef _LOCORE

#if __GNUC__ == 2 && __GNUC_MINOR__ < 7
#pragma pack(1)
#endif

/*
 * Memory and System segment descriptors (both 8 bytes).
 */
struct segment_descriptor {
	unsigned sd_lolimit:16;		/* segment extent (lsb) */
	unsigned sd_lobase:24;		/* segment base address (lsb) */
	unsigned sd_type:5;		/* segment type */
	unsigned sd_dpl:2;		/* segment descriptor priority level */
	unsigned sd_p:1;		/* segment descriptor present */
	unsigned sd_hilimit:4;		/* segment extent (msb) */
	unsigned sd_xx:2;		/* unused */
	unsigned sd_def32:1;		/* default 32 vs 16 bit size */
	unsigned sd_gran:1;		/* limit granularity (byte/page) */
	unsigned sd_hibase:8;		/* segment base address (msb) */
} __packed;

/*
 * Gate descriptors (8 bytes).
 */
struct gate_descriptor {
	unsigned gd_looffset:16;	/* gate offset (lsb) */
	unsigned gd_selector:16;	/* gate segment selector */
	unsigned gd_stkcpy:5;		/* number of stack wds to cpy */
	unsigned gd_xx:3;		/* unused */
	unsigned gd_type:5;		/* segment type */
	unsigned gd_dpl:2;		/* segment descriptor priority level */
	unsigned gd_p:1;		/* segment descriptor present */
	unsigned gd_hioffset:16;	/* gate offset (msb) */
} __packed;

/*
 * Xen-specific?
 */
struct ldt_descriptor {
	__vaddr_t ld_base;
	uint32_t ld_entries;
} __packed;

/*
 * Generic descriptor (8 bytes).
 */
union descriptor {
	struct segment_descriptor sd;
	struct gate_descriptor gd;
	struct ldt_descriptor ld;
	uint32_t raw[2];
	uint64_t raw64;
} __packed;

/*
 * Region descriptors, used to load gdt/idt tables before segments yet exist.
 */
struct region_descriptor {
	unsigned rd_limit:16;		/* segment extent */
	unsigned rd_base:32;		/* base address  */
} __packed;

#if __GNUC__ == 2 && __GNUC_MINOR__ < 7
#pragma pack(4)
#endif

#ifdef _KERNEL
#ifdef XENPV
typedef struct trap_info idt_descriptor_t;
#else
typedef struct gate_descriptor idt_descriptor_t; 
#endif /* XENPV */
extern union descriptor *gdtstore, *ldtstore;

void setgate(struct gate_descriptor *, void *, int, int, int, int);
void set_idtgate(idt_descriptor_t *, void *, int, int, int, int);
void unset_idtgate(idt_descriptor_t *);
void setregion(struct region_descriptor *, void *, size_t);
void setsegment(struct segment_descriptor *, const void *, size_t, int, int,
    int, int);
void unsetgate(struct gate_descriptor *);
void update_descriptor(union descriptor *, union descriptor *);

struct idt_vec;
void idt_vec_reserve(struct idt_vec *, int);
int idt_vec_alloc(struct idt_vec *, int, int);
void idt_vec_set(struct idt_vec *, int, void (*)(void));
void idt_vec_free(struct idt_vec *, int);
void idt_vec_init_cpu_md(struct idt_vec *, cpuid_t);
bool idt_vec_is_pcpu(void);
struct idt_vec* idt_vec_ref(struct idt_vec *);


#endif /* _KERNEL */

#endif /* !_LOCORE */

/* system segments and gate types */
#define SDT_SYSNULL	 0	/* system null */
#define SDT_SYS286TSS	 1	/* system 286 TSS available */
#define SDT_SYSLDT	 2	/* system local descriptor table */
#define SDT_SYS286BSY	 3	/* system 286 TSS busy */
#define SDT_SYS286CGT	 4	/* system 286 call gate */
#define SDT_SYSTASKGT	 5	/* system task gate */
#define SDT_SYS286IGT	 6	/* system 286 interrupt gate */
#define SDT_SYS286TGT	 7	/* system 286 trap gate */
#define SDT_SYSNULL2	 8	/* system null again */
#define SDT_SYS386TSS	 9	/* system 386 TSS available */
#define SDT_SYSNULL3	10	/* system null again */
#define SDT_SYS386BSY	11	/* system 386 TSS busy */
#define SDT_SYS386CGT	12	/* system 386 call gate */
#define SDT_SYSNULL4	13	/* system null again */
#define SDT_SYS386IGT	14	/* system 386 interrupt gate */
#define SDT_SYS386TGT	15	/* system 386 trap gate */

/* memory segment types */
#define SDT_MEMRO	16	/* memory read only */
#define SDT_MEMROA	17	/* memory read only accessed */
#define SDT_MEMRW	18	/* memory read write */
#define SDT_MEMRWA	19	/* memory read write accessed */
#define SDT_MEMROD	20	/* memory read only expand dwn limit */
#define SDT_MEMRODA	21	/* memory read only expand dwn limit accessed */
#define SDT_MEMRWD	22	/* memory read write expand dwn limit */
#define SDT_MEMRWDA	23	/* memory read write expand dwn limit accessed */
#define SDT_MEME	24	/* memory execute only */
#define SDT_MEMEA	25	/* memory execute only accessed */
#define SDT_MEMER	26	/* memory execute read */
#define SDT_MEMERA	27	/* memory execute read accessed */
#define SDT_MEMEC	28	/* memory execute only conforming */
#define SDT_MEMEAC	29	/* memory execute only accessed conforming */
#define SDT_MEMERC	30	/* memory execute read conforming */
#define SDT_MEMERAC	31	/* memory execute read accessed conforming */

#define SDTYPE(p)	(((const struct segment_descriptor *)(p))->sd_type)
/* is memory segment descriptor pointer ? */
#define ISMEMSDP(s)	(SDTYPE(s) >= SDT_MEMRO && \
			 SDTYPE(s) <= SDT_MEMERAC)

/* is 286 gate descriptor pointer ? */
#define IS286GDP(s)	(SDTYPE(s) >= SDT_SYS286CGT && \
			 SDTYPE(s) < SDT_SYS286TGT)

/* is 386 gate descriptor pointer ? */
#define IS386GDP(s)	(SDTYPE(s) >= SDT_SYS386CGT && \
			 SDTYPE(s) < SDT_SYS386TGT)

/* is gate descriptor pointer ? */
#define ISGDP(s)	(IS286GDP(s) || IS386GDP(s))

/* is segment descriptor pointer ? */
#define ISSDP(s)	(ISMEMSDP(s) || !ISGDP(s))

/* is system segment descriptor pointer ? */
#define ISSYSSDP(s)	(!ISMEMSDP(s) && !ISGDP(s))

/*
 * Segment Protection Exception code bits
 */
#define SEGEX_EXT	0x01	/* recursive or externally induced */
#define SEGEX_IDT	0x02	/* interrupt descriptor table */
#define SEGEX_TI	0x04	/* local descriptor table */

/*
 * Entries in the Interrupt Descriptor Table (IDT)
 */
#define NIDT	256
#define NRSVIDT	32		/* reserved entries for CPU exceptions */

/*
 * Entries in the Global Descriptor Table (GDT).
 *
 * NB: If you change GBIOSCODE/GBIOSDATA, you *must* rebuild arch/i386/
 * bioscall/biostramp.inc, as that relies on GBIOSCODE/GBIOSDATA and a
 * normal kernel build does not rebuild it (it's merely included whole-
 * sale from i386/bioscall.s)
 *
 * Also, note that the GEXTBIOSDATA_SEL selector is special, as it maps
 * to the value 0x0040 (when created as a KPL global selector).  Some
 * BIOSes reference the extended BIOS data area at segment 0040 in a non
 * relocatable fashion (even when in protected mode); mapping the zero page
 * via the GEXTBIOSDATA_SEL allows these buggy BIOSes to continue to work
 * under NetBSD.
 *
 * The order if the first 5 descriptors is special; the sysenter/sysexit
 * instructions depend on them.
 */
#define GNULL_SEL	0	/* Null descriptor */
#define GCODE_SEL	1	/* Kernel code descriptor */
#define GDATA_SEL	2	/* Kernel data descriptor */
#define GUCODE_SEL	3	/* User code descriptor */
#define GUDATA_SEL	4	/* User data descriptor */
#define GLDT_SEL	5	/* Default LDT descriptor */
#define GCPU_SEL	6	/* per-CPU segment */
#define GEXTBIOSDATA_SEL 8	/* magic to catch BIOS refs to EBDA */
#define GAPM32CODE_SEL	9	/* 3 APM segments must be consecutive */
#define GAPM16CODE_SEL	10	/* and in the specified order: code32 */
#define GAPMDATA_SEL	11	/* code16 and then data per APM spec */
#define GBIOSCODE_SEL	12
#define GBIOSDATA_SEL	13
#define GPNPBIOSCODE_SEL 14
#define GPNPBIOSDATA_SEL 15
#define GPNPBIOSSCRATCH_SEL 16
#define GPNPBIOSTRAMP_SEL 17
#define GTRAPTSS_SEL	18
#define GIPITSS_SEL	19
#define GUCODEBIG_SEL	20	/* User code with executable stack */
#define GUFS_SEL	21	/* Per-thread %fs */
#define GUGS_SEL	22	/* Per-thread %gs */
#define NGDT		23

/*
 * Entries in the Local Descriptor Table (LDT).
 * DO NOT ADD KERNEL DATA/CODE SEGMENTS TO THIS TABLE.
 */
#define LSYS5CALLS_SEL	0	/* iBCS system call gate */
#define LSYS5SIGR_SEL	1	/* iBCS sigreturn gate */
#define LUCODE_SEL	2	/* User code descriptor */
#define LUDATA_SEL	3	/* User data descriptor */
#define LSOL26CALLS_SEL	4	/* Solaris 2.6 system call gate */
#define LUCODEBIG_SEL	5	/* User code with executable stack */
#define LBSDICALLS_SEL	16	/* BSDI system call gate */
#define NLDT		17

#endif /* _I386_SEGMENTS_H_ */