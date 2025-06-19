/*	$NetBSD: segments.h,v 1.38 2021/04/17 20:12:55 rillig Exp $	*/

/*
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

/*
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
 * Adapted for NetBSD/amd64 by fvdl@wasabisystems.com.
 */

/*
 * 386 Segmentation Data Structures and definitions
 *	William F. Jolitz (william@ernie.berkeley.edu) 6/20/1989
 */

#ifndef _AMD64_SEGMENTS_H_
#define _AMD64_SEGMENTS_H_

#ifdef __x86_64__

#ifdef _KERNEL_OPT
#include "opt_xen.h"
#endif

/*
 * Selectors
 */

#define ISPL(s)		((s) & SEL_RPL)	/* what is the priority level of a selector */
#ifdef XENPV
#define SEL_KPL		3		/* kernel privilege level */
#define SEL_XPL		0		/* Xen Hypervisor privilege level */
#else
#define SEL_KPL		0		/* kernel privilege level */
#endif
#define SEL_UPL		3		/* user privilege level */
#define SEL_RPL		3		/* requester's privilege level mask */
#define ISLDT(s)	((s) & SEL_LDT)	/* is it local or global */
#define SEL_LDT		4		/* local descriptor table */

#ifdef XENPV
#define IOPL_KPL	1
#else
#define IOPL_KPL	SEL_KPL
#endif

/* Dynamically allocated TSSs and LDTs start (byte offset) */
#define SYSSEL_START	(NGDT_MEM << 3)
#define DYNSEL_START	(SYSSEL_START + (NGDT_SYS << 4))

/*
 * These define the index not from the start of the GDT, but from
 * the part of the GDT that they're allocated from.
 * First NGDT_MEM entries are 8-byte descriptors for CS and DS.
 * Next NGDT_SYS entries are 16-byte descriptors defining LDTs.
 *
 * The rest is 16-byte descriptors for TSS and LDT.
 */

#define IDXSEL(s)	(((s) >> 3) & 0x1fff)
#define IDXDYNSEL(s)	((((s) & ~SEL_RPL) - DYNSEL_START) >> 4)

#define GSEL(s,r)	(((s) << 3) | r)
#define GSYSSEL(s,r)	((((s) << 4) + SYSSEL_START) | r)
#define GDYNSEL(s,r)	((((s) << 4) + DYNSEL_START) | r | SEL_KPL)

#define LSEL(s,r)	((s) | r | SEL_LDT)

#define USERMODE(c)		(ISPL(c) == SEL_UPL)
#ifdef XENPV
/*
 * As KPL == UPL, Xen emulate interrupt in kernel context by pushing
 * a fake CS with XPL privilege
 */
#define KERNELMODE(c)		(ISPL(c) == SEL_XPL)
#else
#define KERNELMODE(c)		(ISPL(c) == SEL_KPL)
#endif

#ifndef _LOCORE

/*
 * Memory and System segment descriptors
 */

/*
 * System segment descriptor (16 bytes): used for TSS and LDT.
 */
struct sys_segment_descriptor {
	uint64_t sd_lolimit:16;	/* segment extent (lsb) */
	uint64_t sd_lobase:24;	/* segment base address (lsb) */
	uint64_t sd_type:5;	/* segment type */
	uint64_t sd_dpl:2;	/* segment descriptor priority level */
	uint64_t sd_p:1;	/* segment descriptor present */
	uint64_t sd_hilimit:4;	/* segment extent (msb) */
	uint64_t sd_xx1:3;	/* avl, long and def32 (not used) */
	uint64_t sd_gran:1;	/* limit granularity (byte/page) */
	uint64_t sd_hibase:40;	/* segment base address (msb) */
	uint64_t sd_xx2:8;	/* reserved */
	uint64_t sd_zero:5;	/* must be zero */
	uint64_t sd_xx3:19;	/* reserved */
} __packed;

/*
 * Memory segment descriptor (8 bytes): used for cs, ds, etc.
 */
struct mem_segment_descriptor {
	unsigned sd_lolimit:16;	/* segment extent (lsb) */
	unsigned sd_lobase:24;	/* segment base address (lsb) */
	unsigned sd_type:5;	/* segment type */
	unsigned sd_dpl:2;	/* segment descriptor priority level */
	unsigned sd_p:1;	/* segment descriptor present */
	unsigned sd_hilimit:4;	/* segment extent (msb) */
	unsigned sd_avl:1;	/* available */
	unsigned sd_long:1;	/* long mode */
	unsigned sd_def32:1;	/* default 32 vs 16 bit size */
	unsigned sd_gran:1;	/* limit granularity (byte/page) */
	unsigned sd_hibase:8;	/* segment base address (msb) */
} __packed;

/*
 * Common part of the above structures. Used to walk descriptor tables.
 */
struct common_segment_descriptor {
	unsigned sdc_lolimit:16;
	unsigned sdc_lobase:24;
	unsigned sdc_type:5;
	unsigned sdc_other:19;
} __packed;

/*
 * Gate descriptors (16 bytes).
 */
struct gate_descriptor {
	uint64_t gd_looffset:16;/* gate offset (lsb) */
	uint64_t gd_selector:16;/* gate segment selector */
	uint64_t gd_ist:3;	/* IST select */
	uint64_t gd_xx1:5;	/* reserved */
	uint64_t gd_type:5;	/* segment type */
	uint64_t gd_dpl:2;	/* segment descriptor priority level */
	uint64_t gd_p:1;	/* segment descriptor present */
	uint64_t gd_hioffset:48;/* gate offset (msb) */
	uint64_t gd_xx2:8;	/* reserved */
	uint64_t gd_zero:5;	/* must be zero */
	uint64_t gd_xx3:19;	/* reserved */
} __packed;

/*
 * Generic descriptor (8 bytes). Note: it does not include system segment
 * descriptors and gate descriptors, since these are 16-byte-long.
 */
union descriptor {
	struct mem_segment_descriptor sd;
	uint32_t raw[2];
	uint64_t raw64;
} __packed;

/*
 * Region descriptors, used to load gdt/idt tables before segments yet exist.
 */
struct region_descriptor {
	uint16_t rd_limit;	/* segment extent */
	uint64_t rd_base;	/* base address  */
} __packed;

#ifdef _KERNEL
#ifdef XENPV
typedef struct trap_info idt_descriptor_t;
#else
typedef struct gate_descriptor idt_descriptor_t;
#endif /* XENPV */
extern char *gdtstore;
extern char *ldtstore;

void setgate(struct gate_descriptor *, void *, int, int, int, int);
void unsetgate(struct gate_descriptor *);
void set_idtgate(idt_descriptor_t *, void *, int, int, int, int);
void unset_idtgate(idt_descriptor_t *);
void setregion(struct region_descriptor *, void *, uint16_t);
void set_sys_segment(struct sys_segment_descriptor *, void *, size_t,
    int, int, int);
void set_mem_segment(struct mem_segment_descriptor *, void *, size_t,
    int, int, int, int, int);
void update_descriptor(void *, void *);

struct idt_vec;
void idt_vec_reserve(struct idt_vec *, int);
int idt_vec_alloc(struct idt_vec *, int, int);
void idt_vec_set(struct idt_vec *, int, void (*)(void));
void idt_vec_free(struct idt_vec *, int);
void idt_vec_init_cpu_md(struct idt_vec *, cpuid_t);
bool idt_vec_is_pcpu(void);
struct idt_vec * idt_vec_ref(struct idt_vec *);


struct lwp;
void cpu_segregs64_zero(struct lwp *);
void cpu_segregs32_zero(struct lwp *);
void cpu_fsgs_reload(struct lwp *, int, int);

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
#define NCPUIDT	32		/* reserved entries for CPU exceptions */

/*
 * Entries in the Global Descriptor Table (GDT)
 * The code and data descriptors must come first. There
 * are NGDT_MEM of them.
 *
 * Then come the predefined LDT (and possibly TSS) descriptors.
 * There are NGDT_SYS of them.
 */
#define GNULL_SEL	0	/* Null descriptor */
#define GCODE_SEL	1	/* Kernel code descriptor */
#define GDATA_SEL	2	/* Kernel data descriptor */
#define GUCODE_SEL	3	/* User code descriptor */
#define GUDATA_SEL	4	/* User data descriptor */
#define GAPM32CODE_SEL	5
#define GAPM16CODE_SEL	6
#define GAPMDATA_SEL	7
#define GBIOSCODE_SEL	8
#define GBIOSDATA_SEL	9
#define GPNPBIOSCODE_SEL 10
#define GPNPBIOSDATA_SEL 11
#define GPNPBIOSSCRATCH_SEL 12
#define GPNPBIOSTRAMP_SEL 13
#define GUCODE32_SEL	14
#define GUDATA32_SEL	15
#define GUFS_SEL	16	/* 32-bit Per-thread %fs */
#define GUGS_SEL	17	/* 32-bit Per-thread %gs */
#define NGDT_MEM	18

#define GLDT_SEL	0	/* Default LDT descriptor */
#define NGDT_SYS	1

#define GDT_ADDR_MEM(s,i)	\
    ((struct mem_segment_descriptor *)((s) + ((i) << 3)))
#define GDT_ADDR_SYS(s,i)	\
    ((struct sys_segment_descriptor *)((s) + (((i) << 4) + SYSSEL_START)))

/*
 * Byte offsets in the Local Descriptor Table (LDT)
 * Strange order because of syscall/sysret insns
 */
#define LUCODE32_SEL	48	/* 32 bit user code descriptor */
#define LUDATA_SEL	56	/* User data descriptor */
#define LUCODE_SEL	64	/* User code descriptor */
#define LUDATA32_SEL	72	/* 32 bit user data descriptor (needed?)*/

#define LDT_SIZE	80

#define LSYSRETBASE_SEL	LUCODE32_SEL

/*
 * Checks for valid user selectors.
 */
#define VALID_USER_DSEL32(s) \
    (((s) & 0xffff) == GSEL(GUDATA32_SEL, SEL_UPL) || \
     ((s) & 0xffff) == LSEL(LUDATA32_SEL, SEL_UPL))
#define VALID_USER_CSEL32(s) \
    ((s) == GSEL(GUCODE32_SEL, SEL_UPL) || (s) == LSEL(LUCODE32_SEL, SEL_UPL))
#define VALID_USER_FSEL32(s) \
    (((s) & 0xffff) == GSEL(GUFS_SEL, SEL_UPL))
#define VALID_USER_GSEL32(s) \
    (((s) & 0xffff) == GSEL(GUGS_SEL, SEL_UPL))

#define VALID_USER_CSEL(s) \
    ((s) == GSEL(GUCODE_SEL, SEL_UPL) || (s) == LSEL(LUCODE_SEL, SEL_UPL))
#define VALID_USER_DSEL(s) \
    ((s) == GSEL(GUDATA_SEL, SEL_UPL) || (s) == LSEL(LUDATA_SEL, SEL_UPL))

#else	/*	__x86_64__	*/

#include <i386/segments.h>

#endif	/*	__x86_64__	*/

#endif /* _AMD64_SEGMENTS_H_ */