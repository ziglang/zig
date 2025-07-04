/*	$NetBSD: disklabel.h,v 1.8 2019/04/03 22:10:49 christos Exp $	*/

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
/*-
 * Copyright (C) 1993	Allen K. Briggs, Chris P. Caputo,
 *			Michael L. Finch, Bradley A. Grantham, and
 *			Lawrence A. Kesteloot
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
 *	This product includes software developed by the Alice Group.
 * 4. The names of the Alice Group or any of its members may not be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE ALICE GROUP ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE ALICE GROUP BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef _MACHINE_DISKLABEL_H_
#define _MACHINE_DISKLABEL_H_

#define LABELUSESMBR	0			/* no MBR partitionning */
#define	LABELSECTOR	0			/* sector containing label */
#define	LABELOFFSET	64			/* offset of label in sector */
#define	MAXPARTITIONS	8			/* number of partitions */
#define	RAW_PART	2			/* raw partition: xx?c */

/* Just a dummy */
struct cpu_disklabel {
	int	cd_dummy;			/* must have one element. */
};

/*
 * Driver Descriptor Map, from Inside Macintosh: Devices, SCSI Manager
 * pp 12-13.  The driver descriptor map always resides on physical block 0.
 */
struct drvr_descriptor {
	u_int32_t	descBlock;	/* first block of driver */
	u_int16_t	descSize;	/* driver size in blocks */
	u_int16_t	descType;	/* system type */
};

/* system types; Apple reserves 0-15 */
#define	DRVR_TYPE_MACINTOSH	1

struct drvr_map {
#define DRIVER_MAP_MAGIC	0x4552
	u_int16_t	sbSig;		/* map signature */
	u_int16_t	sbBlockSize;	/* block size of device */
	u_int32_t	sbBlkCount;	/* number of blocks on device */
	u_int16_t	sbDevType;	/* (used internally by ROM) */
	u_int16_t	sbDevID;	/* (used internally by ROM) */
	u_int32_t	sbData;		/* (used internally by ROM) */
	u_int16_t	sbDrvrCount;	/* number of driver descriptors */
#define	DRVR_MAX_DESCRIPTORS	61
	struct drvr_descriptor sb_dd[DRVR_MAX_DESCRIPTORS];
	u_int16_t	pad[3];
} __attribute__ ((packed));

#define	ddBlock(N)	sb_dd[(N)].descBlock
#define	ddSize(N)	sb_dd[(N)].descSize
#define	ddType(N)	sb_dd[(N)].descType

/*
 * Partition map structure from Inside Macintosh: Devices, SCSI Manager
 * pp. 13-14.  The partition map always begins on physical block 1.
 *
 * With the exception of block 0, all blocks on the disk must belong to
 * exactly one partition.  The partition map itself belongs to a partition
 * of type `APPLE_PARTITION_MAP', and is not limited in size by anything
 * other than available disk space.  The partition map is not necessarily
 * the first partition listed.
 */
struct part_map_entry {
#define PART_ENTRY_MAGIC	0x504d
	u_int16_t	pmSig;		/* partition signature */
	u_int16_t	pmSigPad;	/* (reserved) */
	u_int32_t	pmMapBlkCnt;	/* number of blocks in partition map */
	u_int32_t	pmPyPartStart;	/* first physical block of partition */
	u_int32_t	pmPartBlkCnt;	/* number of blocks in partition */
	char		pmPartName[32];	/* partition name */
	char		pmPartType[32];	/* partition type */
	u_int32_t	pmLgDataStart;	/* first logical block of data area */
	u_int32_t	pmDataCnt;	/* number of blocks in data area */
	u_int32_t	pmPartStatus;	/* partition status information */
	u_int32_t	pmLgBootStart;	/* first logical block of boot code */
	u_int32_t	pmBootSize;	/* size of boot code, in bytes */
	u_int32_t	pmBootLoad;	/* boot code load address */
	u_int32_t	pmBootLoad2;	/* (reserved) */
	u_int32_t	pmBootEntry;	/* boot code entry point */
	u_int32_t	pmBootEntry2;	/* (reserved) */
	u_int32_t	pmBootCksum;	/* boot code checksum */
	char		pmProcessor[16]; /* processor type (e.g. "68020") */
	u_int8_t	pmBootArgs[128]; /* A/UX boot arguments */
	u_int8_t	pad[248];	/* pad to end of block */
};

#define PART_TYPE_DRIVER	"APPLE_DRIVER"
#define PART_TYPE_DRIVER43	"APPLE_DRIVER43"
#define PART_TYPE_DRIVERATA	"APPLE_DRIVER_ATA"
#define PART_TYPE_FWB_COMPONENT	"FWB DRIVER COMPONENTS"
#define PART_TYPE_MAC		"APPLE_HFS"
#define PART_TYPE_NETBSD	"NETBSD"
#define PART_TYPE_PARTMAP	"APPLE_PARTITION_MAP"
#define PART_TYPE_SCRATCH	"APPLE_SCRATCH"
#define PART_TYPE_UNIX		"APPLE_UNIX_SVR2"

/*
 * "pmBootArgs" for APPLE_UNIX_SVR2 partition.
 * NetBSD/mac68k only uses Magic, Cluster, Type, and Flags.
 */
struct blockzeroblock {
	u_int32_t       bzbMagic;
	u_int8_t        bzbCluster;
	u_int8_t        bzbType;
	u_int16_t       bzbBadBlockInode;
	u_int16_t       bzbFlags;
	u_int16_t       bzbReserved;
	u_int32_t       bzbCreationTime;
	u_int32_t       bzbMountTime;
	u_int32_t       bzbUMountTime;
};

#define BZB_MAGIC	0xABADBABE
#define BZB_TYPEFS	1
#define BZB_TYPESWAP	3
#define BZB_ROOTFS	0x8000
#define BZB_USRFS	0x4000

#define __HAVE_SETDISKLABEL

#endif /* _MACHINE_DISKLABEL_H_ */