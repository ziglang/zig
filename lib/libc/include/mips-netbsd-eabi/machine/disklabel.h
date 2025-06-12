/*	$NetBSD: disklabel.h,v 1.6 2017/07/24 10:04:09 mrg Exp $	*/

/*
 * Copyright (c) 1994 Christopher G. Demetriou
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
 *      This product includes software developed by Christopher G. Demetriou.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright 2000, 2001
 * Broadcom Corporation. All rights reserved.
 *
 * This software is furnished under license and may be used and copied only
 * in accordance with the following terms and conditions.  Subject to these
 * conditions, you may download, copy, install, use, modify and distribute
 * modified or unmodified copies of this software in source and/or binary
 * form. No title or ownership is transferred hereby.
 *
 * 1) Any source code used, modified or distributed must reproduce and
 *    retain this copyright notice and list of conditions as they appear in
 *    the source file.
 *
 * 2) No right is granted to use any trade name, trademark, or logo of
 *    Broadcom Corporation.  The "Broadcom Corporation" name may not be
 *    used to endorse or promote products derived from this software
 *    without the prior written permission of Broadcom Corporation.
 *
 * 3) THIS SOFTWARE IS PROVIDED "AS-IS" AND ANY EXPRESS OR IMPLIED
 *    WARRANTIES, INCLUDING BUT NOT LIMITED TO, ANY IMPLIED WARRANTIES OF
 *    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
 *    NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL BROADCOM BE LIABLE
 *    FOR ANY DAMAGES WHATSOEVER, AND IN PARTICULAR, BROADCOM SHALL NOT BE
 *    LIABLE FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 *    BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *    WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 *    OR OTHERWISE), EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _EVBMIPS_DISKLABEL_H_
#define _EVBMIPS_DISKLABEL_H_

#ifdef _KERNEL_OPT
#include "opt_pmon.h"
#include "opt_cputype.h"
#endif

#ifdef MIPS64_SB1

#define LABELUSESMBR	0		/* no MBR partitionning */
#define	LABELSECTOR	1		/* sector containing label */
#define	LABELOFFSET	0		/* offset of label in sector */
#define	MAXPARTITIONS	16
#define	RAW_PART	3

#ifdef __NetBSD__
/* Pull in MBR partition definitions. */
#if HAVE_NBTOOL_CONFIG_H
#include <nbinclude/sys/bootblock.h>
#else
#include <sys/bootblock.h>
#endif /* HAVE_NBTOOL_CONFIG_H */

#ifndef __ASSEMBLER__
#if HAVE_NBTOOL_CONFIG_H
#include <nbinclude/sys/dkbad.h>
#else
#include <sys/dkbad.h>
#endif /* HAVE_NBTOOL_CONFIG_H */
struct cpu_disklabel {
	struct mbr_partition mbrparts[MBR_PART_COUNT];
#define __HAVE_DISKLABEL_DKBAD
	struct dkbad bad;
};
#endif
#endif

/*
 * CFE boot block, modeled loosely on Alpha.
 *
 * It consists of:
 *
 * 		BSD disk label
 *		<blank space>
 *		Boot block info (5 uint_64s)
 *
 * The boot block portion looks like:
 *
 *
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *	|                        BOOT_MAGIC_NUMBER                      |
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *	| Flags |   Reserved    | Vers  |      Header Checksum          |
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *	|             Secondary Loader Location (bytes)                 |
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *	|     Loader Checksum           |     Size of loader (bytes)    |
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *	|          Reserved             |    Architecture Information   |
 *	+-------+-------+-------+-------+-------+-------+-------+-------+
 *
 * Boot block fields should always be read as 64-bit numbers.
 *
 */


struct boot_block {
	uint64_t cfe_bb_data[64];	/* data (disklabel, also as below) */
};
#define	cfe_bb_magic	cfe_bb_data[59]	/* magic number */
#define	cfe_bb_hdrinfo	cfe_bb_data[60]	/* header checksum, ver, flags */
#define	cfe_bb_secstart	cfe_bb_data[61]	/* secondary start (bytes) */
#define	cfe_bb_secsize	cfe_bb_data[62]	/* secondary size (bytes) */
#define	cfe_bb_archinfo	cfe_bb_data[63]	/* architecture info */

#define	BOOT_BLOCK_OFFSET	0	/* offset of boot block. */
#define	BOOT_BLOCK_BLOCKSIZE	512	/* block size for sec. size/start,
					 * and for boot block itself
					 */
#define	BOOT_BLOCK_SIZE		40	/* 5 64-bit words */

#define	BOOT_MAGIC_NUMBER	0x43465631424f4f54
#define	BOOT_HDR_CHECKSUM_MASK	0x00000000FFFFFFFF
#define	BOOT_HDR_VER_MASK	0x000000FF00000000
#define	BOOT_HDR_VER_SHIFT	32
#define	BOOT_HDR_FLAGS_MASK	0xFF00000000000000
#define	BOOT_SECSIZE_MASK	0x00000000FFFFFFFF
#define	BOOT_DATA_CHECKSUM_MASK 0xFFFFFFFF00000000
#define	BOOT_DATA_CHECKSUM_SHIFT 32
#define	BOOT_ARCHINFO_MASK	0x00000000FFFFFFFF

#define	BOOT_HDR_VERSION	1

#define	CHECKSUM_BOOT_BLOCK(bb,cksum)					\
	do {								\
		uint32_t *_ptr = (uint32_t *) (bb);			\
		uint32_t _cksum;					\
		int _i;							\
									\
		_cksum = 0;						\
		for (_i = 0;						\
		    _i < (BOOT_BLOCK_SIZE / sizeof (uint32_t));		\
		    _i++)						\
			_cksum += _ptr[_i];				\
		*(cksum) = _cksum;					\
	} while (0)


#define	CHECKSUM_BOOT_DATA(data,len,cksum)				\
	do {								\
		uint32_t *_ptr = (uint32_t *) (data);			\
		uint32_t _cksum;					\
		int _i;							\
									\
		_cksum = 0;						\
		for (_i = 0;						\
		    _i < ((len) / sizeof (uint32_t));			\
		    _i++)						\
			_cksum += _ptr[_i];				\
		*(cksum) = _cksum;					\
	} while (0)

#else /* MIPS64_SB1 */

#ifdef PMON
#define LABELUSESMBR	1			/* use MBR partitionning */
#else
#define LABELUSESMBR	0			/* no MBR partitionning */
#endif
#define	LABELSECTOR	0			/* sector containing label */
#define	LABELOFFSET	64			/* offset of label in sector */
#define	MAXPARTITIONS	16			/* number of partitions */
#define	RAW_PART	2			/* raw partition: xx?c */

#if HAVE_NBTOOL_CONFIG_H
#include <nbinclude/sys/dkbad.h>
#else
#include <sys/dkbad.h>
#endif /* HAVE_NBTOOL_CONFIG_H */

/* Just a dummy */
struct cpu_disklabel {
#define __HAVE_DISKLABEL_DKBAD
	struct dkbad bad;			/* must have one element. */
};

#endif /* MIPS64_SB1 */

#endif	/* !_EVBMIPS_DISKLABEL_H_ */