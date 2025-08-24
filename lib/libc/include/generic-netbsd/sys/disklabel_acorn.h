/*	$NetBSD: disklabel_acorn.h,v 1.7 2022/05/24 19:37:39 andvar Exp $	*/

/*
 * Copyright (c) 1994 Mark Brinicombe.
 * Copyright (c) 1994 Brini.
 * All rights reserved.
 *
 * This code is derived from software written for Brini by Mark Brinicombe
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
 *	This product includes software developed by Brini.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRINI ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL BRINI OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS_DISKLABEL_ACORN_H_
#define _SYS_DISKLABEL_ACORN_H_

#define PARTITION_TYPE_UNUSED  0
#define PARTITION_TYPE_ADFS    1
#define PARTITION_TYPE_RISCIX  2

#define PARTITION_FORMAT_RISCIX  2
#define PARTITION_FORMAT_RISCBSD 0x42

#define FILECORE_BOOT_SECTOR 6

/* Stuff to deal with RISCiX partitions */

#define NRISCIX_PARTITIONS 8
#define RISCIX_PARTITION_OFFSET 8

struct riscix_partition {
	uint32_t	rp_start;
	uint32_t	rp_length;
	uint32_t	rp_type;
	int8_t		rp_name[16];
};

struct riscix_partition_table {
	uint32_t	pad0;
	uint32_t	pad1;
	struct riscix_partition partitions[NRISCIX_PARTITIONS];
};

struct filecore_bootblock {
	uint8_t		padding0[0x1c0];
	uint8_t		log2secsize;
	uint8_t		secspertrack;
	uint8_t		heads;
	uint8_t		density;
	uint8_t		idlen;
	uint8_t		log2bpmb;
	uint8_t		skew;
	uint8_t		bootoption;
	uint8_t		lowsector;
	uint8_t		nzones;
	uint16_t	zone_spare;
	uint32_t	root;
	uint32_t	disc_size;
	uint16_t	disc_id;
	uint8_t		disc_name[10];
	uint32_t	disc_type;

	uint8_t		padding1[24];

	uint8_t		partition_type;
	uint8_t		partition_cyl_low;
	uint8_t		partition_cyl_high;
	uint8_t		checksum;
};

#if defined(_KERNEL) && !defined(__ASSEMBLER__)
struct buf;
struct cpu_disklabel;
struct disklabel;

/* for readdisklabel.  rv != 0 -> matches, msg == NULL -> success */
int filecore_label_read(dev_t, void (*)(struct buf *),
	struct disklabel *, struct cpu_disklabel *, const char **, int *,
	int *);

/* for writedisklabel.  rv == 0 -> doesn't match, rv > 0 -> success */
int filecore_label_locate(dev_t, void (*)(struct buf *),
	struct disklabel *, struct cpu_disklabel *, int *, int *);
#endif
#endif /* _SYS_DISKLABEL_ACORN_H_ */