/*	$NetBSD: kcore.h,v 1.5 2008/04/28 20:23:26 martin Exp $	*/

/*-
 * Copyright (c) 1996, 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Gordon W. Ross, Jason R. Thorpe, and Leo Weppelman.
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

#ifndef _M68K_KCORE_H_
#define	_M68K_KCORE_H_

/*
 * Unified m68k kcore header descriptions.
 *
 * NOTE: We must have all possible m68k kcore types defined in this
 * file.  Otherwise, we require kernel sources for all m68k platforms
 * to build userland.
 *
 * We must provide STE/PTE bits in the kcore header for a couple
 * of reasons:
 *
 *	- different platforms may have the MMUs configured for different
 *	  page sizes
 *	- we may not have a specific platform's pte.h available to us
 *
 * These are on-disk structures; use fixed-sized types!
 *
 * The total size of the cpu_kcore_hdr should be <= DEV_BSIZE!
 */

/*
 * kcore information for Utah-derived pmaps
 */
#define	M68K_NPHYS_RAM_SEGS	8	/* XXX */
struct m68k_kcore_hdr {
	int32_t		mmutype;	/* MMU type */
	u_int32_t	sg_v;		/* STE bits */
	u_int32_t	sg_frame;
	u_int32_t	sg_ishift;
	u_int32_t	sg_pmask;
	u_int32_t	sg40_shift1;
	u_int32_t	sg40_mask2;
	u_int32_t	sg40_shift2;
	u_int32_t	sg40_mask3;
	u_int32_t	sg40_shift3;
	u_int32_t	sg40_addr1;
	u_int32_t	sg40_addr2;
	u_int32_t	pg_v;		/* PTE bits */
	u_int32_t	pg_frame;
	u_int32_t	sysseg_pa;	/* PA of Sysseg[] */
	u_int32_t	reloc;		/* value added to relocate a symbol
					   before address translation is
					   enabled */
	u_int32_t	relocend;	/* if kernbase < va < relocend, we
					   can do simple relocation to get
					   the physical address */
	phys_ram_seg_t	ram_segs[M68K_NPHYS_RAM_SEGS];
};

/*
 * kcore information for the sun2
 */
struct sun2_kcore_hdr {
	u_int32_t	segshift;
	u_int32_t	pg_frame;	/* PTE bits */
	u_int32_t	pg_valid;
	u_int8_t	ksegmap[512];	/* kernel segment map */
};

/*
 * kcore information for the sun3
 */
struct sun3_kcore_hdr {
	u_int32_t	segshift;
	u_int32_t	pg_frame;	/* PTE bits */
	u_int32_t	pg_valid;
	u_int8_t	ksegmap[256];	/* kernel segment map */
};

/*
 * kcore information for the sun3x; Motorola MMU, but a very
 * different pmap.
 */
#define	SUN3X_NPHYS_RAM_SEGS	4
struct sun3x_kcore_hdr {
	u_int32_t	pg_frame;	/* PTE bits */
	u_int32_t	pg_valid;
	u_int32_t	contig_end;
	u_int32_t	kernCbase;	/* VA of kernel level C page table */
	phys_ram_seg_t	ram_segs[SUN3X_NPHYS_RAM_SEGS];
};

/*
 * Catch-all header.  "un" is interpreted based on the contents of "name".
 */
struct cpu_kcore_hdr {
	char		name[16];	/* machine name */
	u_int32_t	page_size;	/* hardware page size */
	u_int32_t	kernbase;	/* start of KVA space */
	union {
		struct m68k_kcore_hdr _m68k;
		struct sun2_kcore_hdr _sun2;
		struct sun3_kcore_hdr _sun3;
		struct sun3x_kcore_hdr _sun3x;
	} un;
};

typedef struct cpu_kcore_hdr cpu_kcore_hdr_t;

#endif /* _M68K_KCORE_H_ */