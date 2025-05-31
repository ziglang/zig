/*	$NetBSD: bat.h,v 1.20 2020/07/06 10:31:23 rin Exp $	*/

/*-
 * Copyright (c) 1999 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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

/*
 * Copyright (C) 1995, 1996 Wolfgang Solfrank.
 * Copyright (C) 1995, 1996 TooLs GmbH.
 * All rights reserved.
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
 *	This product includes software developed by TooLs GmbH.
 * 4. The name of TooLs GmbH may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY TOOLS GMBH ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL TOOLS GMBH BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_POWERPC_OEA_BAT_H_
#define	_POWERPC_OEA_BAT_H_

#if defined(_KERNEL) && !defined(_LOCORE)

#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif

#include <powerpc/psl.h>

struct bat {
	register_t batu;
	register_t batl;
} __aligned(8);
#endif

/* Lower BAT bits (all but PowerPC 601): */
#define	BAT_RPN		(~0x1ffff)	/* physical block start */
#define	BAT_XPN		0x00000e00	/* eXtended physical page number (0-2) */
#define	BAT_W		0x00000040	/* 1 = write-through, 0 = write-back */
#define	BAT_I		0x00000020	/* cache inhibit */
#define	BAT_M		0x00000010	/* memory coherency enable */
#define	BAT_G		0x00000008	/* guarded region (not on 601) */
#define	BAT_X		0x00000004	/* eXtended physical page number (3) */
#define	BAT_WIMG	0x00000078	/* WIMG mask */

/*
 * BAT_XPN and BAT_X are only used when HID0[XAEN] == 1 and are used
 * to generate the 4 MSB of physical address
 */

#define	BAT_PP		0x00000003	/* PP mask */
#define	BAT_PP_NONE	0x00000000	/* no access permission */
#define	BAT_PP_RO_S	0x00000001	/* read-only (soft) */
#define	BAT_PP_RW	0x00000002	/* read/write */
#define	BAT_PP_RO	0x00000003	/* read-only */

/* Upper BAT bits (all but PowerPC 601): */
#define	BAT_EPI		(~0x1ffffL)	/* effective block start */
#define	BAT_BL		0x00001ffc	/* block length */
#define	BAT_Vs		0x00000002	/* valid in supervisor mode */
#define	BAT_Vu		0x00000001	/* valid in user mode */

#define	BAT_XBL		0x0001e000	/* eXtended Block Length (*) */
#define	BAT_XBL_512M	0x00002000	/* XBL for 512MB */
#define	BAT_XBL_1G	0x00006000	/* XBL for 1GB */
#define	BAT_XBL_2G	0x0000e000	/* XBL for 2GB */
#define	BAT_XBL_4G	0x0001e000	/* XBL for 4GB */

#define	BAT_V		(BAT_Vs|BAT_Vu)

/* Block Length encoding (all but PowerPC 601): */
#define	BAT_BL_128K	0x00000000
#define	BAT_BL_256K	0x00000004
#define	BAT_BL_512K	0x0000000c
#define	BAT_BL_1M	0x0000001c
#define	BAT_BL_2M	0x0000003c
#define	BAT_BL_4M	0x0000007c
#define	BAT_BL_8M	0x000000fc
#define	BAT_BL_16M	0x000001fc
#define	BAT_BL_32M	0x000003fc
#define	BAT_BL_64M	0x000007fc
#define	BAT_BL_128M	0x00000ffc
#define	BAT_BL_256M	0x00001ffc
/* Extended Block Lengths (7455+) */
#define	BAT_BL_512M	0x00003ffc
#define	BAT_BL_1G	0x00007ffc
#define	BAT_BL_2G	0x0000fffc
#define	BAT_BL_4G	0x0001fffc

#define	BAT_BL_TO_SIZE(bl)	(((bl)+4) << 15)

#define	BATU(va, len, v)						\
	(((va) & BAT_EPI) | ((len) & (BAT_BL|BAT_XBL)) | ((v) & BAT_V))

#define	BATL(pa, wimg, pp)						\
	(((pa) & BAT_RPN) | (wimg) | (pp))

#define BAT_VA_MATCH_P(batu,va) \
  (((~(((batu)&(BAT_BL|BAT_XBL))<<15))&(va)&BAT_EPI)==((batu)&BAT_EPI))

#define BAT_PA_MATCH_P(batu,batl,pa) \
  (((~(((batu)&(BAT_BL|BAT_XBL))<<15))&(pa)&BAT_RPN)==((batl)&BAT_RPN))

#define BAT_VALID_P(batu, msr) \
  (((msr)&PSL_PR)?(((batu)&BAT_Vu)==BAT_Vu):(((batu)&BAT_Vs)==BAT_Vs))

/* Lower BAT bits (PowerPC 601): */
#define	BAT601_PBN	0xfffe0000	/* physical block number */
#define	BAT601_V	0x00000040	/* valid */
#define	BAT601_BSM	0x0000003f	/* block size mask */

/* Upper BAT bits (PowerPC 601): */
#define	BAT601_BLPI	0xfffe0000	/* block logical page index */
#define	BAT601_W	0x00000040	/* 1 = write-through, 0 = write-back */
#define	BAT601_I	0x00000020	/* cache inhibit */
#define	BAT601_M	0x00000010	/* memory coherency enable */
#define	BAT601_Ks	0x00000008	/* key-supervisor */
#define	BAT601_Ku	0x00000004	/* key-user */

/*
 * Permission bits on the PowerPC 601 are modified by the appropriate
 * Key bit:
 *
 *	Key	PP	Access
 *	0	NONE	read/write
 *	0	RO_S	read/write
 *	0	RW	read/write
 *	0	RO	read-only
 *
 *	1	NONE	none
 *	1	RO_S	read-only
 *	1	RW	read/write
 *	1	RO	read-only
 */
#define	BAT601_PP	0x00000003
#define	BAT601_PP_NONE	0x00000000	/* no access permission */
#define	BAT601_PP_RO_S	0x00000001	/* read-only (soft) */
#define	BAT601_PP_RW	0x00000002	/* read/write */
#define	BAT601_PP_RO	0x00000003	/* read-only */

/* Block Size Mask encoding (PowerPC 601): */
#define	BAT601_BSM_128K	0x00000000
#define	BAT601_BSM_256K	0x00000001
#define	BAT601_BSM_512K	0x00000003
#define	BAT601_BSM_1M	0x00000007
#define	BAT601_BSM_2M	0x0000000f
#define	BAT601_BSM_4M	0x0000001f
#define	BAT601_BSM_8M	0x0000003f

#define	BATU601(va, wim, key, pp)					\
	(((va) & BAT601_BLPI) | (wim) | (key) | (pp))

#define	BATL601(pa, size, v)						\
	(((pa) & BAT601_PBN) | (v) | (size))

#define	BAT601_VA_MATCH_P(batu, batl, va)				\
	(((~(((batl)&BAT601_BSM)<<17))&(va)&BAT601_BLPI)==((batu)&BAT601_BLPI))

#define	BAT601_VALID_P(batl) \
	((batl) & BAT601_V)

#define	BAT_VA2IDX(va)	((va) / (8*1024*1024))
#define	BAT_IDX2VA(i)	((i) * (8*1024*1024))

#if defined(_KERNEL) && !defined(_LOCORE)
void oea_batinit(paddr_t, ...);
void oea_iobat_add(paddr_t, register_t);
void oea_iobat_remove(paddr_t);

#if !defined (PPC_OEA64)
extern struct bat battable[];
#endif /* PPC_OEA */
#endif

#endif	/* _POWERPC_OEA_BAT_H_ */