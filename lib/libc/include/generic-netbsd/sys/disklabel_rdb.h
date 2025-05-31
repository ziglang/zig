/*	$NetBSD: disklabel_rdb.h,v 1.5 2021/02/20 09:51:20 rin Exp $	*/

/*
 * Copyright (c) 1994 Christian E. Hopps
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
 *      This product includes software developed by Christian E. Hopps.
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

#ifndef _SYS_DISKLABEL_RDB_H_
#define _SYS_DISKLABEL_RDB_H_

#include <sys/types.h>

/*
 * describes ados Rigid Disk Blocks
 * which are used to partition a drive
 */
#define RDBNULL ((uint32_t)0xffffffff)

/*
 * you will find rdblock somewhere in [0, RDBMAXBLOCKS)
 */
#define RDB_MAXBLOCKS	16

struct rdblock {
	uint32_t id;		/* 'RDSK' */
	uint32_t nsumlong;	/* number of long words in check sum */
	uint32_t chksum;	/* simple additive with wrap checksum */
	uint32_t hostid;	/* scsi target of host */
	uint32_t nbytes;	/* size of disk blocks */
	uint32_t flags;
	uint32_t badbhead;	/* linked list of badblocks */
	uint32_t partbhead;	/* linked list of partblocks */
	uint32_t fsbhead;	/*   "     "   of fsblocks */
	uint32_t driveinit;
	uint32_t resv1[6];	/* RDBNULL */
	uint32_t ncylinders;	/* number of cylinders on drive */
	uint32_t nsectors;	/* number of sectors per track */
	uint32_t nheads;	/* number of tracks per cylinder */
	uint32_t interleave;
	uint32_t park;		/* only used with st506 i.e. not */
	uint32_t resv2[3];
	uint32_t wprecomp;	/* start cyl for write precomp */
	uint32_t reducedwrite;	/* start cyl for reduced write current */
	uint32_t steprate;	/* driver step rate in ?s */
	uint32_t resv3[5];
	uint32_t rdblowb;	/* lowblock of range for rdb's */
	uint32_t rdbhighb;	/* high block of range for rdb's */
	uint32_t lowcyl;	/* low cylinder of partition area */
	uint32_t highcyl;	/* upper cylinder of partition area */
	uint32_t secpercyl;	/* number of sectors per cylinder */
	uint32_t parkseconds;	/* zero if no park needed */
	uint32_t resv4[2];
	char   diskvendor[8];	/* inquiry stuff */
	char   diskproduct[16];	/* inquiry stuff */
	char   diskrevision[4];	/* inquiry stuff */
	char   contvendor[8];	/* inquiry stuff */
	char   contproduct[16];	/* inquiry stuff */
	char   contrevision[4];	/* inquiry stuff */
#if never_use_secsize
	uint32_t resv5[0];
#endif
};


#define RDBF_LAST	0x1	/* last drive available */
#define RDBF_LASTLUN	0x2	/* last LUN available */
#define RDBF_LASTUNIT	0x4	/* last target available */
#define RDBF_NORESELECT	0x8	/* do not use reselect */
#define RDBF_DISKID	0x10	/* disk id is valid ?? */
#define RDBF_CTRLID	0x20	/* ctrl id is valid ?? */
#define RDBF_SYNC	0x40	/* drive supports SCSI synchronous mode */
	
struct ados_environ {
	uint32_t tabsize;	/* 0: environ table size */
	uint32_t sizeblock;	/* 1: n long words in a block */
	uint32_t secorg;	/* 2: not used must be zero */
	uint32_t numheads;	/* 3: number of surfaces */
	uint32_t secperblk;	/* 4: must be 1 */
	uint32_t secpertrk;	/* 5: blocks per track */
	uint32_t resvblocks;	/* 6: reserved blocks at start */
	uint32_t prefac;	/* 7: must be 0 */
	uint32_t interleave;	/* 8: normally 1 */
	uint32_t lowcyl;	/* 9: low cylinder of partition */
	uint32_t highcyl;	/* 10: upper cylinder of partition */
	uint32_t numbufs;	/* 11: ados: number of buffers */
	uint32_t membuftype;	/* 12: ados: type of bufmem */
	uint32_t maxtrans;	/* 13: maxtrans the ctrlr supports */
	uint32_t mask;		/* 14: mask for valid address */
	uint32_t bootpri;	/* 15: boot priority for autoboot */
	uint32_t dostype;	/* 16: filesystem type */
	uint32_t baud;		/* 17: serial handler baud rate */
	uint32_t control;	/* 18: control word for fs */
	uint32_t bootblocks;	/* 19: blocks containing boot code */
	uint32_t fsize;		/* 20: file system block size */
	uint32_t frag;		/* 21: allowable frags per block */
	uint32_t cpg;		/* 22: cylinders per group */
};

struct partblock {
	uint32_t id;		/* 'PART' */
	uint32_t nsumlong;	/* number of long words in check sum */
	uint32_t chksum;	/* simple additive with wrap checksum */
	uint32_t hostid;	/* scsi target of host */
	uint32_t next;		/* next in chain */
	uint32_t flags;		/* see below */
	uint32_t resv1[3];
	unsigned char partname[32]; /* (BCPL) part name (may not be unique) */
	uint32_t resv2[15];
	struct ados_environ e;
#if never_use_secsize
	uint32_t extra[9];	/* 8 for extra added to environ */
#endif
};

#define PBF_BOOTABLE	0x1	/* partition is bootable */
#define PBF_NOMOUNT	0x2	/* partition should be mounted */

struct badblock {
	uint32_t id;		/* 'BADB' */
	uint32_t nsumlong;	/* number of long words in check sum */
	uint32_t chksum;	/* simple additive with wrap checksum */
	uint32_t hostid;	/* scsi target of host */
	uint32_t next;		/* next in chain */
	uint32_t resv;
	struct badblockent {
		uint32_t badblock;
		uint32_t goodblock;
	} badtab[0];		/* 61 for secsize == 512 */
};

struct fsblock {
	uint32_t id;		/* 'FSHD' */
	uint32_t nsumlong;	/* number of long words in check sum */
	uint32_t chksum;	/* simple additive with wrap checksum */
	uint32_t hostid;	/* scsi target of host */
	uint32_t next;		/* next in chain */
	uint32_t flags;
	uint32_t resv1[2];
	uint32_t dostype;	/* this is a file system for this type */
	uint32_t version;	/* version of this fs */
	uint32_t patchflags;	/* describes which functions to replace */
	uint32_t type;		/* zero */
	uint32_t task;		/* zero */
	uint32_t lock;		/* zero */
	uint32_t handler;	/* zero */
	uint32_t stacksize;	/* to use when loading handler */
	uint32_t priority;	/* to run the fs at. */
	uint32_t startup;	/* zero */
	uint32_t lsegblocks;	/* linked list of lsegblocks of fs code */
	uint32_t globalvec;	/* bcpl vector not used mostly */
#if never_use_secsize
	uint32_t resv2[44];
#endif
};

struct lsegblock {
	uint32_t id;		/* 'LSEG' */
	uint32_t nsumlong;	/* number of long words in check sum */
	uint32_t chksum;	/* simple additive with wrap checksum */
	uint32_t hostid;	/* scsi target of host */
	uint32_t next;		/* next in chain */
	uint32_t loaddata[0];	/* load segment data, 123 for secsize == 512 */
};

#define RDBLOCK_ID	0x5244534b	/* 'RDSK' */
#define PARTBLOCK_ID	0x50415254	/* 'PART' */
#define BADBLOCK_ID	0x42414442	/* 'BADB' */
#define FSBLOCK_ID	0x46534844	/* 'FSHD' */
#define LSEGBLOCK_ID	0x4c534547	/* 'LSEG' */

/*
 * Dos types for identifying file systems
 * bsd file systems will be 'N','B',x,y where y is the fstype found in
 * disklabel.h (for DOST_DOS it will be the version number)
 */
#define DOST_XXXBSD	0x42534400	/* Old type back compat*/
#define DOST_NBR	0x4e425200	/* 'NBRx' NetBSD root partition */
#define DOST_NBS	0x4e425300	/* 'NBS0' NetBSD swap partition */
#define DOST_NBU	0x4e425500	/* 'NBUx' NetBSD user partition */
#define DOST_DOS	0x444f5300	/* 'DOSx' AmigaDos partition */
#define DOST_AMIX	0x554e4900	/* 'UNIx' AmigaDos partition */
#define DOST_MUFS	0x6d754600	/* 'muFx' AmigaDos partition (muFS) */
#define DOST_EXT2	0x4c4e5800	/* 'LNX0' Linux fs partition (ext2fs) */
#define DOST_LNXSWP	0x53575000	/* 'SWP0' Linux swap partition */
#define DOST_RAID	0x52414900	/* 'RAID' Raidframe partition */
#define DOST_MSD	0x4d534400	/* 'MSDx' MSDOS partition */
#define DOST_SFS	0x53465300	/* 'SFSx' Smart fs partition */

struct adostype {
	uint8_t archtype;	/* see ADT_xxx below */
	uint8_t fstype;		/* byte 3 from amiga dostype */
};

/* archtypes */
#define ADT_UNKNOWN	0
#define ADT_AMIGADOS	1
#define ADT_NETBSDROOT	2
#define ADT_NETBSDSWAP	3
#define ADT_NETBSDUSER	4
#define ADT_AMIX	5
#define ADT_EXT2	6
#define ADT_RAID	7
#define ADT_MSD		8
#define ADT_SFS		9

#define ISFSARCH_NETBSD(adt) \
	((adt).archtype >= ADT_NETBSDROOT && (adt).archtype <= ADT_NETBSDUSER)

#endif /* _SYS_DISKLABEL_RDB_H_ */