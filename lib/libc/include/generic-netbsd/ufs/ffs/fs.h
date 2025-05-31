/*	$NetBSD: fs.h,v 1.70.2.1 2023/05/13 11:51:14 martin Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)fs.h	8.13 (Berkeley) 3/21/95
 */

/*
 * NOTE: COORDINATE ON-DISK FORMAT CHANGES WITH THE FREEBSD PROJECT.
 */

#ifndef	_UFS_FFS_FS_H_
#define	_UFS_FFS_FS_H_

/*
 * Each disk drive contains some number of file systems.
 * A file system consists of a number of cylinder groups.
 * Each cylinder group has inodes and data.
 *
 * A file system is described by its super-block, which in turn
 * describes the cylinder groups.  The super-block is critical
 * data and is replicated in each cylinder group to protect against
 * catastrophic loss.  This is done at `newfs' time and the critical
 * super-block data does not change, so the copies need not be
 * referenced further unless disaster strikes.
 *
 * For file system fs, the offsets of the various blocks of interest
 * are given in the super block as:
 *	[fs->fs_sblkno]		Super-block
 *	[fs->fs_cblkno]		Cylinder group block
 *	[fs->fs_iblkno]		Inode blocks
 *	[fs->fs_dblkno]		Data blocks
 * The beginning of cylinder group cg in fs, is given by
 * the ``cgbase(fs, cg)'' macro.
 *
 * Depending on the architecture and the media, the superblock may
 * reside in any one of four places. For tiny media where every block
 * counts, it is placed at the very front of the partition. Historically,
 * UFS1 placed it 8K from the front to leave room for the disk label and
 * a small bootstrap. For UFS2 it got moved to 64K from the front to leave
 * room for the disk label and a bigger bootstrap, and for really piggy
 * systems we check at 256K from the front if the first three fail. In
 * all cases the size of the superblock will be SBLOCKSIZE. All values are
 * given in byte-offset form, so they do not imply a sector size. The
 * SBLOCKSEARCH specifies the order in which the locations should be searched.
 *
 * Unfortunately the UFS2/FFSv2 change was done without adequate consideration
 * of backward compatibility.  In particular 'newfs' for a FFSv2 partition
 * must overwrite any old FFSv1 superblock at 8k, and preferably as many
 * of the alternates as it can find - otherwise attempting to mount on a
 * system that only supports FFSv1 is likely to succeed!.
 * For a small FFSv1 filesystem, an old FFSv2 superblock can be left on
 * the disk, and a system that tries to find an FFSv2 filesystem in preference
 * to and FFSv1 one (as NetBSD does) can mount the old FFSv2 filesystem.
 * As a added bonus, the 'first alternate' superblock of a FFSv1 filesystem
 * with 64k blocks is at 64k - just where the code looks first when playing
 * 'hunt the superblock'.
 *
 * The ffsv2 superblock layout (which might contain an ffsv1 filesystem)
 * can be detected by checking for sb->fs_old_flags & FS_FLAGS_UPDATED.
 * This is the default superblock type for NetBSD since ffsv2 support was added.
 */
#define	BBSIZE		8192
#define	BBOFF		((off_t)(0))
#define	BBLOCK		((daddr_t)(0))

#define	SBLOCK_FLOPPY      0
#define	SBLOCK_UFS1     8192
#define	SBLOCK_UFS2    65536
#define	SBLOCK_PIGGY  262144
#define	SBLOCKSIZE      8192
/*
 * NB: Do not, under any circumstances, look for an ffsv1 filesystem at
 * SBLOCK_UFS2.  Doing so will find the wrong superblock for filesystems
 * with a 64k block size.
 */
#define	SBLOCKSEARCH \
	{ SBLOCK_UFS2, SBLOCK_UFS1, SBLOCK_FLOPPY, SBLOCK_PIGGY, -1 }

/*
 * Max number of fragments per block. This value is NOT tweakable.
 */
#define	MAXFRAG		8



/*
 * Addresses stored in inodes are capable of addressing fragments
 * of `blocks'. File system blocks of at most size MAXBSIZE can
 * be optionally broken into 2, 4, or 8 pieces, each of which is
 * addressable; these pieces may be DEV_BSIZE, or some multiple of
 * a DEV_BSIZE unit.
 *
 * Large files consist of exclusively large data blocks.  To avoid
 * undue wasted disk space, the last data block of a small file may be
 * allocated as only as many fragments of a large block as are
 * necessary.  The file system format retains only a single pointer
 * to such a fragment, which is a piece of a single large block that
 * has been divided.  The size of such a fragment is determinable from
 * information in the inode, using the ``ffs_blksize(fs, ip, lbn)'' macro.
 *
 * The file system records space availability at the fragment level;
 * to determine block availability, aligned fragments are examined.
 */

/*
 * MINBSIZE is the smallest allowable block size.
 * In order to insure that it is possible to create files of size
 * 2^32 with only two levels of indirection, MINBSIZE is set to 4096.
 * MINBSIZE must be big enough to hold a cylinder group block,
 * thus changes to (struct cg) must keep its size within MINBSIZE.
 * Note that super blocks are always of size SBSIZE,
 * and that both SBSIZE and MAXBSIZE must be >= MINBSIZE.
 */
#define	MINBSIZE	4096

/*
 * The path name on which the file system is mounted is maintained
 * in fs_fsmnt. MAXMNTLEN defines the amount of space allocated in
 * the super block for this name.
 */
#define	MAXMNTLEN	468

/*
 * The volume name for this filesystem is maintained in fs_volname.
 * MAXVOLLEN defines the length of the buffer allocated.
 * This space used to be part of of fs_fsmnt.
 */
#define	MAXVOLLEN	32

/*
 * There is a 128-byte region in the superblock reserved for in-core
 * pointers to summary information. Originally this included an array
 * of pointers to blocks of struct csum; now there are just four
 * pointers and the remaining space is padded with fs_ocsp[].
 * NOCSPTRS determines the size of this padding. One pointer (fs_csp)
 * is taken away to point to a contiguous array of struct csum for
 * all cylinder groups; a second (fs_maxcluster) points to an array
 * of cluster sizes that is computed as cylinder groups are inspected;
 * the third (fs_contigdirs) points to an array that tracks the
 * creation of new directories; and the fourth (fs_active) is used
 * by snapshots.
 */
#define	NOCSPTRS	((128 / sizeof(void *)) - 4)

/*
 * A summary of contiguous blocks of various sizes is maintained
 * in each cylinder group. Normally this is set by the initial
 * value of fs_maxcontig. To conserve space, a maximum summary size
 * is set by FS_MAXCONTIG.
 */
#define	FS_MAXCONTIG	16

/*
 * The maximum number of snapshot nodes that can be associated
 * with each filesystem. This limit affects only the number of
 * snapshot files that can be recorded within the superblock so
 * that they can be found when the filesystem is mounted. However,
 * maintaining too many will slow the filesystem performance, so
 * having this limit is a good idea.
 */
#define	FSMAXSNAP 20

/*
 * Used to identify special blocks in snapshots:
 *
 * BLK_NOCOPY - A block that was unallocated at the time the snapshot
 *      was taken, hence does not need to be copied when written.
 * BLK_SNAP - A block held by another snapshot that is not needed by this
 *      snapshot. When the other snapshot is freed, the BLK_SNAP entries
 *      are converted to BLK_NOCOPY. These are needed to allow fsck to
 *      identify blocks that are in use by other snapshots (which are
 *      expunged from this snapshot).
 */
#define	BLK_NOCOPY	((daddr_t)(1))
#define	BLK_SNAP	((daddr_t)(2))

/*
 * MINFREE gives the minimum acceptable percentage of file system
 * blocks which may be free. If the freelist drops below this level
 * only the superuser may continue to allocate blocks. This may
 * be set to 0 if no reserve of free blocks is deemed necessary,
 * however throughput drops by fifty percent if the file system
 * is run at between 95% and 100% full; thus the minimum default
 * value of fs_minfree is 5%. However, to get good clustering
 * performance, 10% is a better choice. This value is used only
 * when creating a file system and can be overridden from the
 * command line. By default we choose to optimize for time.
 */
#define	MINFREE		5
#define	DEFAULTOPT	FS_OPTTIME

/*
 * Grigoriy Orlov <gluk@ptci.ru> has done some extensive work to fine
 * tune the layout preferences for directories within a filesystem.
 * His algorithm can be tuned by adjusting the following parameters
 * which tell the system the average file size and the average number
 * of files per directory. These defaults are well selected for typical
 * filesystems, but may need to be tuned for odd cases like filesystems
 * being used for squid caches or news spools.
 */
#define	AVFILESIZ	16384	/* expected average file size */
#define	AFPDIR		64	/* expected number of files per directory */

/*
 * Per cylinder group information; summarized in blocks allocated
 * from first cylinder group data blocks.  These blocks have to be
 * read in from fs_csaddr (size fs_cssize) in addition to the
 * super block.
 */
struct csum {
	int32_t	cs_ndir;		/* number of directories */
	int32_t	cs_nbfree;		/* number of free blocks */
	int32_t	cs_nifree;		/* number of free inodes */
	int32_t	cs_nffree;		/* number of free frags */
};

struct csum_total {
	int64_t cs_ndir;		/* number of directories */
	int64_t cs_nbfree;		/* number of free blocks */
	int64_t cs_nifree;		/* number of free inodes */
	int64_t cs_nffree;		/* number of free frags */
	int64_t cs_spare[4];		/* future expansion */
};


/*
 * Super block for an FFS file system in memory.
 */
struct fs {
	int32_t	 fs_firstfield;		/* historic file system linked list, */
	int32_t	 fs_unused_1;		/*     used for incore super blocks */
	int32_t  fs_sblkno;		/* addr of super-block in filesys */
	int32_t  fs_cblkno;		/* offset of cyl-block in filesys */
	int32_t  fs_iblkno;		/* offset of inode-blocks in filesys */
	int32_t  fs_dblkno;		/* offset of first data after cg */
	int32_t	 fs_old_cgoffset;	/* cylinder group offset in cylinder */
	int32_t	 fs_old_cgmask;		/* used to calc mod fs_ntrak */
	int32_t	 fs_old_time;		/* last time written */
	int32_t	 fs_old_size;		/* number of blocks in fs */
	int32_t	 fs_old_dsize;		/* number of data blocks in fs */
	u_int32_t fs_ncg;		/* number of cylinder groups */
	int32_t	 fs_bsize;		/* size of basic blocks in fs */
	int32_t	 fs_fsize;		/* size of frag blocks in fs */
	int32_t	 fs_frag;		/* number of frags in a block in fs */
/* these are configuration parameters */
	int32_t	 fs_minfree;		/* minimum percentage of free blocks */
	int32_t	 fs_old_rotdelay;	/* num of ms for optimal next block */
	int32_t	 fs_old_rps;		/* disk revolutions per second */
/* these fields can be computed from the others */
	int32_t	 fs_bmask;		/* ``blkoff'' calc of blk offsets */
	int32_t	 fs_fmask;		/* ``fragoff'' calc of frag offsets */
	int32_t	 fs_bshift;		/* ``lblkno'' calc of logical blkno */
	int32_t	 fs_fshift;		/* ``numfrags'' calc number of frags */
/* these are configuration parameters */
	int32_t	 fs_maxcontig;		/* max number of contiguous blks */
	int32_t	 fs_maxbpg;		/* max number of blks per cyl group */
/* these fields can be computed from the others */
	int32_t	 fs_fragshift;		/* block to frag shift */
	int32_t	 fs_fsbtodb;		/* fsbtodb and dbtofsb shift constant */
	int32_t	 fs_sbsize;		/* actual size of super block */
	int32_t	 fs_spare1[2];		/* old fs_csmask */
					/* old fs_csshift */
	int32_t	 fs_nindir;		/* value of FFS_NINDIR */
	u_int32_t fs_inopb;		/* value of FFS_INOPB */
	int32_t	 fs_old_nspf;		/* value of NSPF */
/* yet another configuration parameter */
	int32_t	 fs_optim;		/* optimization preference, see below */
/* these fields are derived from the hardware */
	int32_t	 fs_old_npsect;		/* # sectors/track including spares */
	int32_t	 fs_old_interleave;	/* hardware sector interleave */
	int32_t	 fs_old_trackskew;	/* sector 0 skew, per track */
/* fs_id takes the space of the unused fs_headswitch and fs_trkseek fields */
	int32_t	 fs_id[2];		/* unique file system id */
/* sizes determined by number of cylinder groups and their sizes */
	int32_t  fs_old_csaddr;		/* blk addr of cyl grp summary area */
	int32_t	 fs_cssize;		/* size of cyl grp summary area */
	int32_t	 fs_cgsize;		/* cylinder group size */
/* these fields are derived from the hardware */
	int32_t	 fs_spare2;		/* old fs_ntrak */
	int32_t	 fs_old_nsect;		/* sectors per track */
	int32_t	 fs_old_spc;		/* sectors per cylinder */
	int32_t	 fs_old_ncyl;		/* cylinders in file system */
	int32_t	 fs_old_cpg;		/* cylinders per group */
	u_int32_t fs_ipg;		/* inodes per group */
	int32_t	 fs_fpg;		/* blocks per group * fs_frag */
/* this data must be re-computed after crashes */
	struct	csum fs_old_cstotal;	/* cylinder summary information */
/* these fields are cleared at mount time */
	int8_t	 fs_fmod;		/* super block modified flag */
	uint8_t	 fs_clean;		/* file system is clean flag */
	int8_t	 fs_ronly;		/* mounted read-only flag */
	uint8_t	 fs_old_flags;		/* see FS_ flags below */
	u_char	 fs_fsmnt[MAXMNTLEN];	/* name mounted on */
	u_char   fs_volname[MAXVOLLEN];	/* volume name */
	uint64_t fs_swuid;		/* system-wide uid */
	int32_t	 fs_pad;
/* these fields retain the current block allocation info */
	int32_t	 fs_cgrotor;		/* last cg searched (UNUSED) */
	void 	*fs_ocsp[NOCSPTRS];	/* padding; was list of fs_cs buffers */
	u_int8_t *fs_contigdirs;	/* # of contiguously allocated dirs */
	struct csum *fs_csp;		/* cg summary info buffer for fs_cs */
	int32_t	*fs_maxcluster;		/* max cluster in each cyl group */
	u_char	*fs_active;		/* used by snapshots to track fs */
	int32_t	 fs_old_cpc;		/* cyl per cycle in postbl */
/* this area is otherwise allocated unless fs_old_flags & FS_FLAGS_UPDATED */
	int32_t	 fs_maxbsize;		/* maximum blocking factor permitted */
	uint8_t	 fs_journal_version;	/* journal format version */
	uint8_t	 fs_journal_location;	/* journal location type */
	uint8_t	 fs_journal_reserved[2];/* reserved for future use */
	uint32_t fs_journal_flags;	/* journal flags */
	uint64_t fs_journallocs[4];	/* location info for journal */
	uint32_t fs_quota_magic;	/* see quota2.h */
	uint8_t  fs_quota_flags;	/* see quota2.h */
	uint8_t  fs_quota_reserved[3];	
	uint64_t fs_quotafile[2];	/* pointer to quota inodes */
	int64_t	 fs_sparecon64[9];	/* reserved for future use */
	int64_t	 fs_sblockloc;		/* byte offset of standard superblock */
	struct	csum_total fs_cstotal;	/* cylinder summary information */
	int64_t  fs_time;		/* last time written */
	int64_t	 fs_size;		/* number of blocks in fs */
	int64_t	 fs_dsize;		/* number of data blocks in fs */
	int64_t  fs_csaddr;		/* blk addr of cyl grp summary area */
	int64_t	 fs_pendingblocks;	/* blocks in process of being freed */
	u_int32_t fs_pendinginodes;	/* inodes in process of being freed */
	uint32_t fs_snapinum[FSMAXSNAP];/* list of snapshot inode numbers */
/* back to stuff that has been around a while */
	u_int32_t fs_avgfilesize;	/* expected average file size */
	u_int32_t fs_avgfpdir;		/* expected # of files per directory */
	int32_t	 fs_save_cgsize;	/* save real cg size to use fs_bsize */
	int32_t	 fs_sparecon32[26];	/* reserved for future constants */
	uint32_t fs_flags;		/* see FS_ flags below */
/* back to stuff that has been around a while (again) */
	int32_t	 fs_contigsumsize;	/* size of cluster summary array */
	int32_t	 fs_maxsymlinklen;	/* max length of an internal symlink */
	int32_t	 fs_old_inodefmt;	/* format of on-disk inodes */
	u_int64_t fs_maxfilesize;	/* maximum representable file size */
	int64_t	 fs_qbmask;		/* ~fs_bmask for use with 64-bit size */
	int64_t	 fs_qfmask;		/* ~fs_fmask for use with 64-bit size */
	int32_t	 fs_state;		/* validate fs_clean field (UNUSED) */
	int32_t	 fs_old_postblformat;	/* format of positional layout tables */
	int32_t	 fs_old_nrpos;		/* number of rotational positions */
	int32_t  fs_spare5[2];		/* old fs_postbloff */
					/* old fs_rotbloff */
	int32_t	 fs_magic;		/* magic number */
};

#define	fs_old_postbloff	fs_spare5[0]
#define	fs_old_rotbloff		fs_spare5[1]
#define	fs_old_postbl_start	fs_maxbsize
#define	fs_old_headswitch	fs_id[0]
#define	fs_old_trkseek	fs_id[1]
#define	fs_old_csmask	fs_spare1[0]
#define	fs_old_csshift	fs_spare1[1]

#define	FS_42POSTBLFMT		-1	/* 4.2BSD rotational table format */
#define	FS_DYNAMICPOSTBLFMT	1	/* dynamic rotational table format */

#define	old_fs_postbl(fs_, cylno, opostblsave) \
    ((((fs_)->fs_old_postblformat == FS_42POSTBLFMT) || \
     ((fs_)->fs_old_postbloff == offsetof(struct fs, fs_old_postbl_start))) \
    ? ((int16_t *)(opostblsave) + (cylno) * (fs_)->fs_old_nrpos) \
    : ((int16_t *)((uint8_t *)(fs_) + \
	(fs_)->fs_old_postbloff) + (cylno) * (fs_)->fs_old_nrpos))
#define	old_fs_rotbl(fs) \
    (((fs)->fs_old_postblformat == FS_42POSTBLFMT) \
    ? ((uint8_t *)(&(fs)->fs_magic+1)) \
    : ((uint8_t *)((uint8_t *)(fs) + (fs)->fs_old_rotbloff)))

/*
 * File system identification
 */
#define	FS_UFS1_MAGIC	0x011954	/* UFS1 fast file system magic number */
#define	FS_UFS2_MAGIC	0x19540119	/* UFS2 fast file system magic number */
#define	FS_UFS2EA_MAGIC	0x19012038	/* UFS2 with extattrs */
#define	FS_UFS1_MAGIC_SWAPPED	0x54190100
#define	FS_UFS2_MAGIC_SWAPPED	0x19015419
#define	FS_UFS2EA_MAGIC_SWAPPED	0x38200119
#define	FS_OKAY		0x7c269d38	/* superblock checksum */
#define	FS_42INODEFMT	-1		/* 4.2BSD inode format */
#define	FS_44INODEFMT	2		/* 4.4BSD inode format */

/*
 * File system clean flags
 */
#define	FS_ISCLEAN	0x01
#define	FS_WASCLEAN	0x02

/*
 * Preference for optimization.
 */
#define	FS_OPTTIME	0	/* minimize allocation time */
#define	FS_OPTSPACE	1	/* minimize disk fragmentation */

/*
 * File system flags
 *
 * FS_POSIX1EACLS indicates that POSIX.1e ACLs are administratively enabled
 * for the file system, so they should be loaded from extended attributes,
 * observed for access control purposes, and be administered by object
 * owners.  FS_NFS4ACLS indicates that NFSv4 ACLs are administratively
 * enabled.  This flag is mutually exclusive with FS_POSIX1EACLS.
 */
#define	FS_UNCLEAN	0x001	/* file system not clean at mount (unused) */
#define	FS_DOSOFTDEP	0x002	/* file system using soft dependencies */
#define	FS_NEEDSFSCK	0x004	/* needs sync fsck (FreeBSD compat, unused) */
#define	FS_SUJ		0x008	/* file system using journaled softupdates */
#define	FS_POSIX1EACLS	0x010	/* file system has POSIX.1e ACLs enabled */
#define	FS_ACLS		FS_POSIX1EACLS	/* alias */
#define	FS_MULTILABEL	0x020	/* file system is MAC multi-label */
#define	FS_GJOURNAL	0x40	/* gjournaled file system */
#define	FS_FLAGS_UPDATED 0x80	/* flags have been moved to new location */
#define	FS_DOWAPBL	0x100	/* Write ahead physical block logging */
/*	FS_NFS4ACLS	0x100	   file system has NFSv4 ACLs enabled (FBSD) */
#define	FS_DOQUOTA2	0x200	/* in-filesystem quotas */
/*     	FS_INDEXDIRS	0x200	   kernel supports indexed directories (FBSD)*/
#define	FS_TRIM		0x400	/* discard deleted blocks in storage layer */
#define	FS_NFS4ACLS	0x800	/* file system has NFSv4 ACLs enabled */

/* File system flags that are ok for NetBSD if set in fs_flags */
#define	FS_KNOWN_FLAGS	(FS_DOSOFTDEP | FS_DOWAPBL | FS_DOQUOTA2 | \
	FS_POSIX1EACLS | FS_NFS4ACLS)

/*
 * File system internal flags, also in fs_flags.
 * (Pick highest number to avoid conflicts with others)
 */
#define	FS_SWAPPED	0x80000000	/* file system is endian swapped */
#define	FS_INTERNAL	0x80000000	/* mask for internal flags */

/*
 * Macros to access bits in the fs_active array.
 */
#define	ACTIVECG_SET(fs, cg)				\
	do {						\
		if ((fs)->fs_active != NULL)		\
			setbit((fs)->fs_active, (cg));	\
	} while (/*CONSTCOND*/ 0)
#define	ACTIVECG_CLR(fs, cg)				\
	do {						\
		if ((fs)->fs_active != NULL)		\
			clrbit((fs)->fs_active, (cg));	\
	} while (/*CONSTCOND*/ 0)
#define	ACTIVECG_ISSET(fs, cg)				\
	((fs)->fs_active != NULL && isset((fs)->fs_active, (cg)))

/*
 * The size of a cylinder group is calculated by CGSIZE. The maximum size
 * is limited by the fact that cylinder groups are at most one block.
 * Its size is derived from the size of the maps maintained in the
 * cylinder group and the (struct cg) size.
 */
#define	CGSIZE_IF(fs, ipg, fpg) \
    /* base cg */	(sizeof(struct cg) + sizeof(int32_t) + \
    /* old btotoff */	(fs)->fs_old_cpg * sizeof(int32_t) + \
    /* old boff */	(fs)->fs_old_cpg * sizeof(u_int16_t) + \
    /* inode map */	howmany((ipg), NBBY) + \
    /* block map */	howmany((fpg), NBBY) +\
    /* if present */	((fs)->fs_contigsumsize <= 0 ? 0 : \
    /* cluster sum */	(fs)->fs_contigsumsize * sizeof(int32_t) + \
    /* cluster map */	howmany(ffs_fragstoblks(fs, (fpg)), NBBY)))

#define	CGSIZE(fs) CGSIZE_IF((fs), (fs)->fs_ipg, (fs)->fs_fpg)

/*
 * The minimal number of cylinder groups that should be created.
 */
#define	MINCYLGRPS	4


/*
 * Convert cylinder group to base address of its global summary info.
 */
#define	fs_cs(fs, indx)	fs_csp[indx]

/*
 * Cylinder group block for a file system.
 */
#define	CG_MAGIC	0x090255
struct cg {
	int32_t	 cg_firstfield;		/* historic cyl groups linked list */
	int32_t	 cg_magic;		/* magic number */
	int32_t	 cg_old_time;		/* time last written */
	u_int32_t cg_cgx;		/* we are the cgx'th cylinder group */
	int16_t	 cg_old_ncyl;		/* number of cyl's this cg */
	int16_t	 cg_old_niblk;		/* number of inode blocks this cg */
	u_int32_t cg_ndblk;		/* number of data blocks this cg */
	struct	 csum cg_cs;		/* cylinder summary information */
	u_int32_t cg_rotor;		/* position of last used block */
	u_int32_t cg_frotor;		/* position of last used frag */
	u_int32_t cg_irotor;		/* position of last used inode */
	u_int32_t cg_frsum[MAXFRAG];	/* counts of available frags */
	int32_t	 cg_old_btotoff;	/* (int32) block totals per cylinder */
	int32_t	 cg_old_boff;		/* (u_int16) free block positions */
	u_int32_t cg_iusedoff;		/* (u_int8) used inode map */
	u_int32_t cg_freeoff;		/* (u_int8) free block map */
	u_int32_t cg_nextfreeoff;	/* (u_int8) next available space */
	u_int32_t cg_clustersumoff;	/* (u_int32) counts of avail clusters */
	u_int32_t cg_clusteroff;		/* (u_int8) free cluster map */
	u_int32_t cg_nclusterblks;	/* number of clusters this cg */
	u_int32_t cg_niblk;		/* number of inode blocks this cg */
	u_int32_t cg_initediblk;		/* last initialized inode */
	int32_t	 cg_sparecon32[3];	/* reserved for future use */
	int64_t  cg_time;		/* time last written */
	int64_t  cg_sparecon64[3];	/* reserved for future use */
	u_int8_t cg_space[1];		/* space for cylinder group maps */
/* actually longer */
};

/*
 * The following structure is defined
 * for compatibility with old file systems.
 */
struct ocg {
	int32_t  cg_firstfield;		/* historic linked list of cyl groups */
	int32_t  cg_unused_1;		/*     used for incore cyl groups */
	int32_t  cg_time;		/* time last written */
	int32_t  cg_cgx;		/* we are the cgx'th cylinder group */
	int16_t  cg_ncyl;		/* number of cyl's this cg */
	int16_t  cg_niblk;		/* number of inode blocks this cg */
	int32_t  cg_ndblk;		/* number of data blocks this cg */
	struct  csum cg_cs;		/* cylinder summary information */
	int32_t  cg_rotor;		/* position of last used block */
	int32_t  cg_frotor;		/* position of last used frag */
	int32_t  cg_irotor;		/* position of last used inode */
	int32_t  cg_frsum[8];		/* counts of available frags */
	int32_t  cg_btot[32];		/* block totals per cylinder */
	int16_t  cg_b[32][8];		/* positions of free blocks */
	u_int8_t cg_iused[256];		/* used inode map */
	int32_t  cg_magic;		/* magic number */
	u_int8_t cg_free[1];		/* free block map */
/* actually longer */
};


/*
 * Macros for access to cylinder group array structures.
 */
#define	old_cg_blktot_old(cgp, ns) \
    (((struct ocg *)(cgp))->cg_btot)
#define	old_cg_blks_old(fs, cgp, cylno, ns) \
    (((struct ocg *)(cgp))->cg_b[cylno])

#define	old_cg_blktot_new(cgp, ns) \
    ((int32_t *)((u_int8_t *)(cgp) + \
	ufs_rw32((cgp)->cg_old_btotoff, (ns))))
#define	old_cg_blks_new(fs, cgp, cylno, ns) \
    ((int16_t *)((u_int8_t *)(cgp) + \
	ufs_rw32((cgp)->cg_old_boff, (ns))) + (cylno) * (fs)->fs_old_nrpos)

#define	old_cg_blktot(cgp, ns) \
    ((ufs_rw32((cgp)->cg_magic, (ns)) != CG_MAGIC) ? \
      old_cg_blktot_old(cgp, ns) : old_cg_blktot_new(cgp, ns))
#define	old_cg_blks(fs, cgp, cylno, ns) \
    ((ufs_rw32((cgp)->cg_magic, (ns)) != CG_MAGIC) ? \
      old_cg_blks_old(fs, cgp, cylno, ns) : old_cg_blks_new(fs, cgp, cylno, ns))

#define	cg_inosused_new(cgp, ns) \
    ((u_int8_t *)((u_int8_t *)(cgp) + \
	ufs_rw32((cgp)->cg_iusedoff, (ns))))
#define	cg_blksfree_new(cgp, ns) \
    ((u_int8_t *)((u_int8_t *)(cgp) + \
	ufs_rw32((cgp)->cg_freeoff, (ns))))
#define	cg_chkmagic_new(cgp, ns) \
    (ufs_rw32((cgp)->cg_magic, (ns)) == CG_MAGIC)

#define	cg_inosused_old(cgp, ns) \
    (((struct ocg *)(cgp))->cg_iused)
#define	cg_blksfree_old(cgp, ns) \
    (((struct ocg *)(cgp))->cg_free)
#define	cg_chkmagic_old(cgp, ns) \
    (ufs_rw32(((struct ocg *)(cgp))->cg_magic, (ns)) == CG_MAGIC)

#define	cg_inosused(cgp, ns) \
    ((ufs_rw32((cgp)->cg_magic, (ns)) != CG_MAGIC) ? \
      cg_inosused_old(cgp, ns) : cg_inosused_new(cgp, ns))
#define	cg_blksfree(cgp, ns) \
    ((ufs_rw32((cgp)->cg_magic, (ns)) != CG_MAGIC) ? \
      cg_blksfree_old(cgp, ns) : cg_blksfree_new(cgp, ns))
#define	cg_chkmagic(cgp, ns) \
    (cg_chkmagic_new(cgp, ns) || cg_chkmagic_old(cgp, ns))

#define	cg_clustersfree(cgp, ns) \
    ((u_int8_t *)((u_int8_t *)(cgp) + \
	ufs_rw32((cgp)->cg_clusteroff, (ns))))
#define	cg_clustersum(cgp, ns) \
    ((int32_t *)((u_int8_t *)(cgp) + \
	ufs_rw32((cgp)->cg_clustersumoff, (ns))))


/*
 * Turn file system block numbers into disk block addresses.
 * This maps file system blocks to device size blocks.
 */
#if defined (_KERNEL)
#define	FFS_FSBTODB(fs, b)	((b) << ((fs)->fs_fshift - DEV_BSHIFT))
#define	FFS_DBTOFSB(fs, b)	((b) >> ((fs)->fs_fshift - DEV_BSHIFT))
#else
#define	FFS_FSBTODB(fs, b)	((b) << (fs)->fs_fsbtodb)
#define	FFS_DBTOFSB(fs, b)	((b) >> (fs)->fs_fsbtodb)
#endif

/*
 * Cylinder group macros to locate things in cylinder groups.
 * They calc file system addresses of cylinder group data structures.
 */
#define	cgbase(fs, c)	(((daddr_t)(fs)->fs_fpg) * (c))
#define	cgstart_ufs1(fs, c) \
    (cgbase(fs, c) + (fs)->fs_old_cgoffset * ((c) & ~((fs)->fs_old_cgmask)))
#define	cgstart_ufs2(fs, c) cgbase((fs), (c))
#define	cgstart(fs, c) ((fs)->fs_magic == FS_UFS2_MAGIC \
			    ? cgstart_ufs2((fs), (c)) : cgstart_ufs1((fs), (c)))
#define	cgdmin(fs, c)	(cgstart(fs, c) + (fs)->fs_dblkno)	/* 1st data */
#define	cgimin(fs, c)	(cgstart(fs, c) + (fs)->fs_iblkno)	/* inode blk */
#define	cgsblock(fs, c)	(cgstart(fs, c) + (fs)->fs_sblkno)	/* super blk */
#define	cgtod(fs, c)	(cgstart(fs, c) + (fs)->fs_cblkno)	/* cg block */

/*
 * Macros for handling inode numbers:
 *     inode number to file system block offset.
 *     inode number to cylinder group number.
 *     inode number to file system block address.
 */
#define	ino_to_cg(fs, x)	(((ino_t)(x)) / (fs)->fs_ipg)
#define	ino_to_fsba(fs, x)						\
	((daddr_t)(cgimin(fs, ino_to_cg(fs, (ino_t)(x))) +		\
	    (ffs_blkstofrags((fs), ((((ino_t)(x)) % (fs)->fs_ipg) / FFS_INOPB(fs))))))
#define	ino_to_fsbo(fs, x)	(((ino_t)(x)) % FFS_INOPB(fs))

/*
 * Give cylinder group number for a file system block.
 * Give cylinder group block number for a file system block.
 */
#define	dtog(fs, d)	((d) / (fs)->fs_fpg)
#define	dtogd(fs, d)	((d) % (fs)->fs_fpg)

/*
 * Extract the bits for a block from a map.
 * Compute the cylinder and rotational position of a cyl block addr.
 */
#define	blkmap(fs, map, loc) \
    (((map)[(loc) / NBBY] >> ((loc) % NBBY)) & (0xff >> (NBBY - (fs)->fs_frag)))
#define	old_cbtocylno(fs, bno) \
    (FFS_FSBTODB(fs, bno) / (fs)->fs_old_spc)
#define	old_cbtorpos(fs, bno) \
    ((fs)->fs_old_nrpos <= 1 ? 0 : \
     (FFS_FSBTODB(fs, bno) % (fs)->fs_old_spc / (fs)->fs_old_nsect * (fs)->fs_old_trackskew + \
      FFS_FSBTODB(fs, bno) % (fs)->fs_old_spc % (fs)->fs_old_nsect * (fs)->fs_old_interleave) % \
     (fs)->fs_old_nsect * (fs)->fs_old_nrpos / (fs)->fs_old_npsect)

/*
 * The following macros optimize certain frequently calculated
 * quantities by using shifts and masks in place of divisions
 * modulos and multiplications.
 */
#define	ffs_blkoff(fs, loc)	/* calculates (loc % fs->fs_bsize) */ \
	((loc) & (fs)->fs_qbmask)
#define	ffs_fragoff(fs, loc)	/* calculates (loc % fs->fs_fsize) */ \
	((loc) & (fs)->fs_qfmask)
#define	ffs_lfragtosize(fs, frag) /* calculates ((off_t)frag * fs->fs_fsize) */ \
	(((off_t)(frag)) << (fs)->fs_fshift)
#define	ffs_lblktosize(fs, blk)	/* calculates ((off_t)blk * fs->fs_bsize) */ \
	((uint64_t)(((off_t)(blk)) << (fs)->fs_bshift))
#define	ffs_lblkno(fs, loc)	/* calculates (loc / fs->fs_bsize) */ \
	((loc) >> (fs)->fs_bshift)
#define	ffs_numfrags(fs, loc)	/* calculates (loc / fs->fs_fsize) */ \
	((loc) >> (fs)->fs_fshift)
#define	ffs_blkroundup(fs, size) /* calculates roundup(size, fs->fs_bsize) */ \
	(((size) + (fs)->fs_qbmask) & (fs)->fs_bmask)
#define	ffs_fragroundup(fs, size) /* calculates roundup(size, fs->fs_fsize) */ \
	(((size) + (fs)->fs_qfmask) & (fs)->fs_fmask)
#define	ffs_fragstoblks(fs, frags) /* calculates (frags / fs->fs_frag) */ \
	((frags) >> (fs)->fs_fragshift)
#define	ffs_blkstofrags(fs, blks) /* calculates (blks * fs->fs_frag) */ \
	((blks) << (fs)->fs_fragshift)
#define	ffs_fragnum(fs, fsb)	/* calculates (fsb % fs->fs_frag) */ \
	((fsb) & ((fs)->fs_frag - 1))
#define	ffs_blknum(fs, fsb)	/* calculates rounddown(fsb, fs->fs_frag) */ \
	((fsb) &~ ((fs)->fs_frag - 1))
#define ffs_getdb(fs, ip, lb) \
    ((fs)->fs_magic == FS_UFS2_MAGIC ? \
	(daddr_t)ufs_rw64((ip)->i_ffs2_db[lb], UFS_FSNEEDSWAP(fs)) : \
	(daddr_t)ufs_rw32((ip)->i_ffs1_db[lb], UFS_FSNEEDSWAP(fs)))
#define ffs_getib(fs, ip, lb) \
    ((fs)->fs_magic == FS_UFS2_MAGIC ? \
	(daddr_t)ufs_rw64((ip)->i_ffs2_ib[lb], UFS_FSNEEDSWAP(fs)) : \
	(daddr_t)ufs_rw32((ip)->i_ffs1_ib[lb], UFS_FSNEEDSWAP(fs)))

/*
 * Determine the number of available frags given a
 * percentage to hold in reserve.
 */
#define	freespace(fs, percentreserved) \
	(ffs_blkstofrags((fs), (fs)->fs_cstotal.cs_nbfree) + \
	(fs)->fs_cstotal.cs_nffree - \
	(((off_t)((fs)->fs_dsize)) * (percentreserved) / 100))

/*
 * Determining the size of a file block in the file system.
 */
#define	ffs_blksize(fs, ip, lbn) \
	(((lbn) >= UFS_NDADDR || (ip)->i_size >= ffs_lblktosize(fs, (lbn) + 1)) \
	    ? (fs)->fs_bsize \
	    : ((int32_t)ffs_fragroundup(fs, ffs_blkoff(fs, (ip)->i_size))))

#define	ffs_sblksize(fs, size, lbn) \
	(((lbn) >= UFS_NDADDR || (size) >= ((lbn) + 1) << (fs)->fs_bshift) \
	  ? (fs)->fs_bsize \
	  : ((int32_t)ffs_fragroundup(fs, ffs_blkoff(fs, (uint64_t)(size)))))


/*
 * Number of inodes in a secondary storage block/fragment.
 */
#define	FFS_INOPB(fs)	((fs)->fs_inopb)
#define	FFS_INOPF(fs)	((fs)->fs_inopb >> (fs)->fs_fragshift)

/*
 * Number of indirects in a file system block.
 */
#define	FFS_NINDIR(fs)	((fs)->fs_nindir)

/*
 * Apple UFS Label:
 *  We check for this to decide to use APPLEUFS_DIRBLKSIZ
 */
#define	APPLEUFS_LABEL_MAGIC		0x4c41424c /* LABL */
#define	APPLEUFS_LABEL_SIZE		1024
#define	APPLEUFS_LABEL_OFFSET	(BBSIZE - APPLEUFS_LABEL_SIZE) /* located at 7k */
#define	APPLEUFS_LABEL_VERSION	1
#define	APPLEUFS_MAX_LABEL_NAME	512

struct appleufslabel {
	u_int32_t	ul_magic;
	u_int16_t	ul_checksum;
	u_int16_t	ul_unused0;
	u_int32_t	ul_version;
	u_int32_t	ul_time;
	u_int16_t	ul_namelen;
	u_char	ul_name[APPLEUFS_MAX_LABEL_NAME]; /* Warning: may not be null terminated */
	u_int16_t	ul_unused1;
	u_int64_t	ul_uuid;	/* Note this is only 4 byte aligned */
	u_char	ul_reserved[24];
	u_char	ul_unused[460];
} __packed;


#endif /* !_UFS_FFS_FS_H_ */