/*	$NetBSD: ext2fs.h,v 1.48 2016/08/20 19:47:44 jdolecek Exp $	*/

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
 *	@(#)fs.h	8.10 (Berkeley) 10/27/94
 *  Modified for ext2fs by Manuel Bouyer.
 */

/*
 * Copyright (c) 1997 Manuel Bouyer.
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
 *
 *	@(#)fs.h	8.10 (Berkeley) 10/27/94
 *  Modified for ext2fs by Manuel Bouyer.
 */

#ifndef _UFS_EXT2FS_EXT2FS_H_
#define _UFS_EXT2FS_EXT2FS_H_

#include <sys/bswap.h>

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
 * The first boot and super blocks are given in absolute disk addresses.
 * The byte-offset forms are preferred, as they don't imply a sector size.
 */
#define BBSIZE		1024
#define SBSIZE		1024
#define	BBOFF		((off_t)(0))
#define	SBOFF		((off_t)(BBOFF + BBSIZE))
#define	BBLOCK		((daddr_t)(0))
#define	SBLOCK		((daddr_t)(BBLOCK + BBSIZE / DEV_BSIZE))

#define	fsbtodb(fs, b)  ((daddr_t)(b) << (fs)->e2fs_fsbtodb)
/* calculates (loc / fs->fs_bsize) */
#define	lblkno(fs, loc) ((loc) >> (fs->e2fs_bshift))
#define	blksize(fs, ip, lbn) ((fs)->e2fs_bsize)

/*
 * Addresses stored in inodes are capable of addressing blocks
 * XXX
 */

/*
 * MINBSIZE is the smallest allowable block size.
 * MINBSIZE must be big enough to hold a cylinder group block,
 * thus changes to (struct cg) must keep its size within MINBSIZE.
 * Note that super blocks are always of size SBSIZE,
 * and that both SBSIZE and MAXBSIZE must be >= MINBSIZE.
 */
#define LOG_MINBSIZE	10
#define MINBSIZE	(1 << LOG_MINBSIZE)

/*
 * The path name on which the file system is mounted is maintained
 * in fs_fsmnt. MAXMNTLEN defines the amount of space allocated in
 * the super block for this name.
 */
#define MAXMNTLEN	512

/*
 * MINFREE gives the minimum acceptable percentage of file system
 * blocks which may be free. If the freelist drops below this level
 * only the superuser may continue to allocate blocks. This may
 * be set to 0 if no reserve of free blocks is deemed necessary,
 * however throughput drops by fifty percent if the file system
 * is run at between 95% and 100% full; thus the minimum default
 * value of fs_minfree is 5%. However, to get good clustering
 * performance, 10% is a better choice. hence we use 10% as our
 * default value. With 10% free space, fragmentation is not a
 * problem, so we choose to optimize for time.
 */
#define MINFREE		5

/*
 * This is maximum amount of links allowed for files. For directories,
 * going over this means setting DIR_NLINK feature.
 */
#define EXT2FS_LINK_MAX		65000
#define EXT2FS_LINK_INF		1		/* link count unknown */

/*
 * Super block for an ext2fs file system.
 */
struct ext2fs {
	uint32_t  e2fs_icount;		/* Inode count */
	uint32_t  e2fs_bcount;		/* blocks count */
	uint32_t  e2fs_rbcount;		/* reserved blocks count */
	uint32_t  e2fs_fbcount;		/* free blocks count */
	uint32_t  e2fs_ficount;		/* free inodes count */
	uint32_t  e2fs_first_dblock;	/* first data block */
	uint32_t  e2fs_log_bsize;	/* bsize = 1024*(2^e2fs_log_bsize) */
	uint32_t  e2fs_fsize;		/* fragment size */
	uint32_t  e2fs_bpg;		/* blocks per group */
	uint32_t  e2fs_fpg;		/* frags per group */
	uint32_t  e2fs_ipg;		/* inodes per group */
	uint32_t  e2fs_mtime;		/* mount time */
	uint32_t  e2fs_wtime;		/* write time */
	uint16_t  e2fs_mnt_count;	/* mount count */
	uint16_t  e2fs_max_mnt_count;	/* max mount count */
	uint16_t  e2fs_magic;		/* magic number */
	uint16_t  e2fs_state;		/* file system state */
	uint16_t  e2fs_beh;		/* behavior on errors */
	uint16_t  e2fs_minrev;		/* minor revision level */
	uint32_t  e2fs_lastfsck;	/* time of last fsck */
	uint32_t  e2fs_fsckintv;	/* max time between fscks */
	uint32_t  e2fs_creator;		/* creator OS */
	uint32_t  e2fs_rev;		/* revision level */
	uint16_t  e2fs_ruid;		/* default uid for reserved blocks */
	uint16_t  e2fs_rgid;		/* default gid for reserved blocks */
	/* EXT2_DYNAMIC_REV superblocks */
	uint32_t  e2fs_first_ino;	/* first non-reserved inode */
	uint16_t  e2fs_inode_size;	/* size of inode structure */
	uint16_t  e2fs_block_group_nr;	/* block grp number of this sblk*/
	uint32_t  e2fs_features_compat;	/*  compatible feature set */
	uint32_t  e2fs_features_incompat; /* incompatible feature set */
	uint32_t  e2fs_features_rocompat; /* RO-compatible feature set */
	uint8_t   e2fs_uuid[16];	/* 128-bit uuid for volume */
	char      e2fs_vname[16];	/* volume name */
	char      e2fs_fsmnt[64];	/* name mounted on */
	uint32_t  e2fs_algo;		/* For compression */
	uint8_t   e2fs_prealloc;	/* # of blocks to preallocate */
	uint8_t   e2fs_dir_prealloc;	/* # of blocks to preallocate for dir */
	uint16_t  e2fs_reserved_ngdb;	/* # of reserved gd blocks for resize */
	
	/* Additional fields */
	char      e3fs_journal_uuid[16];/* uuid of journal superblock */
	uint32_t  e3fs_journal_inum;	/* inode number of journal file */
	uint32_t  e3fs_journal_dev;	/* device number of journal file */
	uint32_t  e3fs_last_orphan;	/* start of list of inodes to delete */
	uint32_t  e3fs_hash_seed[4];	/* HTREE hash seed */
	char      e3fs_def_hash_version;/* Default hash version to use */
	char      e3fs_jnl_backup_type;
	uint16_t  e3fs_desc_size;	/* size of group descriptor */
	uint32_t  e3fs_default_mount_opts;
	uint32_t  e3fs_first_meta_bg;	/* First metablock block group */
	uint32_t  e3fs_mkfs_time;	/* when the fs was created */
	uint32_t  e3fs_jnl_blks[17];	/* backup of the journal inode */
	uint32_t  e4fs_bcount_hi;	/* high bits of blocks count */
	uint32_t  e4fs_rbcount_hi;	/* high bits of reserved blocks count */
	uint32_t  e4fs_fbcount_hi;	/* high bits of free blocks count */
	uint16_t  e4fs_min_extra_isize; /* all inodes have some bytes */
	uint16_t  e4fs_want_extra_isize;/* inodes must reserve some bytes */
	uint32_t  e4fs_flags;		/* miscellaneous flags */
	uint16_t  e4fs_raid_stride;	/* RAID stride */
	uint16_t  e4fs_mmpintv;		/* seconds to wait in MMP checking */
	uint64_t  e4fs_mmpblk;		/* block for multi-mount protection */
	uint32_t  e4fs_raid_stripe_wid; /* blocks on data disks (N * stride) */
	uint8_t   e4fs_log_gpf;		/* FLEX_BG group size */
	uint8_t   e4fs_chksum_type;	/* metadata checksum algorithm used */
	uint8_t   e4fs_encrypt;		/* versioning level for encryption */
	uint8_t   e4fs_reserved_pad;
	uint64_t  e4fs_kbytes_written;	/* number of lifetime kilobytes */
	uint32_t  e4fs_snapinum;	/* inode number of active snapshot */
	uint32_t  e4fs_snapid;		/* sequential ID of active snapshot */
	uint64_t  e4fs_snaprbcount;	/* rsvd blocks for active snapshot */
	uint32_t  e4fs_snaplist;	/* inode number for on-disk snapshot */
	uint32_t  e4fs_errcount;	/* number of file system errors */
	uint32_t  e4fs_first_errtime;	/* first time an error happened */
	uint32_t  e4fs_first_errino;	/* inode involved in first error */
	uint64_t  e4fs_first_errblk;	/* block involved of first error */
	uint8_t   e4fs_first_errfunc[32];/* function where error happened */
	uint32_t  e4fs_first_errline;	/* line number where error happened */
	uint32_t  e4fs_last_errtime;	/* most recent time of an error */
	uint32_t  e4fs_last_errino;	/* inode involved in last error */
	uint32_t  e4fs_last_errline;	/* line number where error happened */
	uint64_t  e4fs_last_errblk;	/* block involved of last error */
	uint8_t   e4fs_last_errfunc[32];/* function where error happened */
	uint8_t   e4fs_mount_opts[64];
	uint32_t  e4fs_usrquota_inum;	/* inode for tracking user quota */
	uint32_t  e4fs_grpquota_inum;	/* inode for tracking group quota */
	uint32_t  e4fs_overhead_clusters;/* overhead blocks/clusters */
	uint32_t  e4fs_backup_bgs[2];	/* groups with sparse_super2 SBs */
	uint8_t   e4fs_encrypt_algos[4];/* encryption algorithms in use */
	uint8_t   e4fs_encrypt_pw_salt[16];/* salt used for string2key */
	uint32_t  e4fs_lpf_ino;		/* location of the lost+found inode */
	uint32_t  e4fs_proj_quota_inum;	/* inode for tracking project quota */
	uint32_t  e4fs_chksum_seed;	/* checksum seed */
	uint32_t  e4fs_reserved[98];	/* padding to the end of the block */
	uint32_t  e4fs_sbchksum;	/* superblock checksum */
};


/* in-memory data for ext2fs */
struct m_ext2fs {
	struct ext2fs e2fs;
	u_char	e2fs_fsmnt[MAXMNTLEN];	/* name mounted on */
	int8_t	e2fs_ronly;	/* mounted read-only flag */
	int8_t	e2fs_fmod;	/* super block modified flag */
	int8_t	e2fs_uhash;	/* 3 if hash should be signed, 0 if not */
	int32_t	e2fs_bsize;	/* block size */
	int32_t e2fs_bshift;	/* ``lblkno'' calc of logical blkno */
	int32_t e2fs_bmask;	/* ``blkoff'' calc of blk offsets */
	int64_t e2fs_qbmask;	/* ~fs_bmask - for use with quad size */
	int32_t	e2fs_fsbtodb;	/* fsbtodb and dbtofsb shift constant */
	int32_t	e2fs_ncg;	/* number of cylinder groups */
	int32_t	e2fs_ngdb;	/* number of group descriptor blocks */
	int32_t	e2fs_ipb;	/* number of inodes per block */
	int32_t	e2fs_itpg;	/* number of inode table blocks per group */
	struct	ext2_gd *e2fs_gd; /* group descriptors (data not byteswapped) */
};



/*
 * Filesystem identification
 */
#define	E2FS_MAGIC	0xef53	/* the ext2fs magic number */
#define E2FS_REV0	0	/* GOOD_OLD revision */
#define E2FS_REV1	1	/* Support compat/incompat features */

/* compatible/incompatible features */
#define EXT2F_COMPAT_PREALLOC		0x0001
#define EXT2F_COMPAT_AFS		0x0002
#define EXT2F_COMPAT_HASJOURNAL		0x0004
#define EXT2F_COMPAT_EXTATTR		0x0008
#define EXT2F_COMPAT_RESIZE		0x0010
#define EXT2F_COMPAT_DIRHASHINDEX	0x0020
#define EXT2F_COMPAT_SPARSESUPER2	0x0200
#define	EXT2F_COMPAT_BITS \
	"\20" \
	"\12COMPAT_SPARSESUPER2" \
	"\11" \
	"\10" \
	"\07" \
	"\06COMPAT_DIRHASHINDEX" \
	"\05COMPAT_RESIZE" \
	"\04COMPAT_EXTATTR" \
	"\03COMPAT_HASJOURNAL" \
	"\02COMPAT_AFS" \
	"\01COMPAT_PREALLOC"

#define EXT2F_ROCOMPAT_SPARSESUPER	0x0001
#define EXT2F_ROCOMPAT_LARGEFILE	0x0002
#define EXT2F_ROCOMPAT_BTREE_DIR	0x0004
#define EXT2F_ROCOMPAT_HUGE_FILE	0x0008
#define EXT2F_ROCOMPAT_GDT_CSUM		0x0010
#define EXT2F_ROCOMPAT_DIR_NLINK	0x0020
#define EXT2F_ROCOMPAT_EXTRA_ISIZE	0x0040
#define EXT2F_ROCOMPAT_QUOTA		0x0100
#define EXT2F_ROCOMPAT_BIGALLOC		0x0200
#define EXT2F_ROCOMPAT_METADATA_CKSUM	0x0400
#define EXT2F_ROCOMPAT_READONLY		0x1000
#define EXT2F_ROCOMPAT_PROJECT		0x2000
#define	EXT2F_ROCOMPAT_BITS \
	"\20" \
	"\16ROCOMPAT_PROJECT" \
	"\15ROCOMPAT_READONLY" \
	"\14" \
	"\13ROCOMPAT_METADATA_CKSUM" \
	"\12ROCOMPAT_BIGALLOC" \
	"\11ROCOMPAT_QUOTA" \
	"\10" \
	"\07ROCOMPAT_EXTRA_ISIZE" \
	"\06ROCOMPAT_DIR_NLINK" \
	"\05ROCOMPAT_GDT_CSUM" \
	"\04ROCOMPAT_HUGE_FILE" \
	"\03ROCOMPAT_BTREE_DIR" \
	"\02ROCOMPAT_LARGEFILE" \
	"\01ROCOMPAT_SPARSESUPER"

#define EXT2F_INCOMPAT_COMP		0x0001
#define EXT2F_INCOMPAT_FTYPE		0x0002
#define	EXT2F_INCOMPAT_REPLAY_JOURNAL	0x0004
#define	EXT2F_INCOMPAT_USES_JOURNAL	0x0008
#define EXT2F_INCOMPAT_META_BG		0x0010
#define EXT2F_INCOMPAT_EXTENTS		0x0040
#define EXT2F_INCOMPAT_64BIT		0x0080
#define EXT2F_INCOMPAT_MMP		0x0100
#define EXT2F_INCOMPAT_FLEX_BG		0x0200
#define EXT2F_INCOMPAT_EA_INODE		0x0400
#define EXT2F_INCOMPAT_DIRDATA		0x1000
#define EXT2F_INCOMPAT_CSUM_SEED	0x2000
#define EXT2F_INCOMPAT_LARGEDIR		0x4000
#define EXT2F_INCOMPAT_INLINE_DATA	0x8000
#define EXT2F_INCOMPAT_ENCRYPT		0x10000
#define	EXT2F_INCOMPAT_BITS \
	"\20" \
	"\021INCOMPAT_ENCRYPT" \
	"\020INCOMPAT_INLINE_DATA" \
	"\017INCOMPAT_LARGEDIR" \
	"\016INCOMPAT_CSUM_SEED" \
	"\015INCOMPAT_DIRDATA" \
	"\014" \
	"\013INCOMPAT_EA_INODE" \
	"\012INCOMPAT_FLEX_BG" \
	"\011INCOMPAT_MMP" \
	"\010INCOMPAT_64BIT" \
	"\07INCOMPAT_EXTENTS" \
	"\05INCOMPAT_META_BG" \
	"\04INCOMPAT_USES_JOURNAL" \
	"\03INCOMPAT_REPLAY_JOURNAL" \
	"\02INCOMPAT_FTYPE" \
	"\01INCOMPAT_COMP"

/*
 * Features supported in this implementation
 *
 * We support the following REV1 features:
 * - EXT2F_ROCOMPAT_SPARSESUPER
 *    superblock backups stored only in cg_has_sb(bno) groups
 * - EXT2F_ROCOMPAT_LARGEFILE
 *    use e2di_size_high in struct ext2fs_dinode to store 
 *    upper 32bit of size for >2GB files
 * - EXT2F_INCOMPAT_FTYPE
 *    store file type to e2d_type in struct ext2fs_direct
 *    (on REV0 e2d_namlen is uint16_t and no e2d_type, like ffs)
 */
#define EXT2F_COMPAT_SUPP		0x0000
#define EXT2F_ROCOMPAT_SUPP		(EXT2F_ROCOMPAT_SPARSESUPER \
					 | EXT2F_ROCOMPAT_LARGEFILE \
					 | EXT2F_ROCOMPAT_HUGE_FILE \
					 | EXT2F_ROCOMPAT_EXTRA_ISIZE \
					 | EXT2F_ROCOMPAT_DIR_NLINK \
					 | EXT2F_ROCOMPAT_GDT_CSUM)
#define EXT2F_INCOMPAT_SUPP		(EXT2F_INCOMPAT_FTYPE \
					 | EXT2F_INCOMPAT_EXTENTS \
					 | EXT2F_INCOMPAT_FLEX_BG)

/*
 * Feature set definitions
 */
#define EXT2F_HAS_COMPAT_FEATURE(fs, feature) \
	((fs)->e2fs.e2fs_rev >= E2FS_REV1 && \
	((fs)->e2fs.e2fs_features_compat & (feature)) != 0)

#define EXT2F_HAS_ROCOMPAT_FEATURE(fs, feature) \
	((fs)->e2fs.e2fs_rev >= E2FS_REV1 && \
	((fs)->e2fs.e2fs_features_rocompat & (feature)) != 0)

#define EXT2F_HAS_INCOMPAT_FEATURE(fs, feature) \
	((fs)->e2fs.e2fs_rev >= E2FS_REV1 && \
	((fs)->e2fs.e2fs_features_incompat & (feature)) != 0)


/*
 * Definitions of behavior on errors
 */
#define E2FS_BEH_CONTINUE	1	/* continue operation */
#define E2FS_BEH_READONLY	2	/* remount fs read only */
#define E2FS_BEH_PANIC		3	/* cause panic */
#define E2FS_BEH_DEFAULT	E2FS_BEH_CONTINUE

/*
 * OS identification
 */
#define E2FS_OS_LINUX	0
#define E2FS_OS_HURD	1
#define E2FS_OS_MASIX	2
#define E2FS_OS_FREEBSD	3
#define E2FS_OS_LITES	4

/*
 * Filesystem clean flags
 */
#define	E2FS_ISCLEAN	0x01
#define	E2FS_ERRORS	0x02

/* ext2 file system block group descriptor */

struct ext2_gd {
	uint32_t ext2bgd_b_bitmap;	/* blocks bitmap block */
	uint32_t ext2bgd_i_bitmap;	/* inodes bitmap block */
	uint32_t ext2bgd_i_tables;	/* first inodes table block */
	uint16_t ext2bgd_nbfree;	/* number of free blocks */
	uint16_t ext2bgd_nifree;	/* number of free inodes */
	uint16_t ext2bgd_ndirs;		/* number of directories */

	/*
	 * Following only valid when either GDT_CSUM (AKA uninit_bg) 
	 * or METADATA_CKSUM feature is on
	 */
	uint16_t ext2bgd_flags;		/* ext4 bg flags (INODE_UNINIT, ...)*/
	uint32_t ext2bgd_exclude_bitmap_lo;	/* snapshot exclude bitmap */
	uint16_t ext2bgd_block_bitmap_csum_lo;	/* Low block bitmap checksum */
	uint16_t ext2bgd_inode_bitmap_csum_lo;	/* Low inode bitmap checksum */
	uint16_t ext2bgd_itable_unused_lo;	/* Low unused inode offset */
	uint16_t ext2bgd_checksum;		/* Group desc checksum */

	/*
	 * XXX disk32 Further fields only exist if 64BIT feature is on
	 * and superblock desc_size > 32, not supported for now.
	 */
};

#define E2FS_BG_INODE_UNINIT	0x0001	/* Inode bitmap not used/initialized */
#define E2FS_BG_BLOCK_UNINIT	0x0002	/* Block bitmap not used/initialized */
#define E2FS_BG_INODE_ZEROED	0x0004	/* On-disk inode table initialized */

#define E2FS_HAS_GD_CSUM(fs) \
	EXT2F_HAS_ROCOMPAT_FEATURE(fs, EXT2F_ROCOMPAT_GDT_CSUM|EXT2F_ROCOMPAT_METADATA_CKSUM) != 0
	
/*
 * If the EXT2F_ROCOMPAT_SPARSESUPER flag is set, the cylinder group has a
 * copy of the super and cylinder group descriptors blocks only if it's
 * 1, a power of 3, 5 or 7
 */

static __inline int cg_has_sb(int) __unused;
static __inline int
cg_has_sb(int i)
{
	int a3, a5, a7;

	if (i == 0 || i == 1)
		return 1;
	for (a3 = 3, a5 = 5, a7 = 7;
	    a3 <= i || a5 <= i || a7 <= i;
	    a3 *= 3, a5 *= 5, a7 *= 7)
		if (i == a3 || i == a5 || i == a7)
			return 1;
	return 0;
}

/* EXT2FS metadatas are stored in little-endian byte order. These macros
 * helps reading theses metadatas
 */

#if BYTE_ORDER == LITTLE_ENDIAN
#	define h2fs16(x) (x)
#	define h2fs32(x) (x)
#	define h2fs64(x) (x)
#	define fs2h16(x) (x)
#	define fs2h32(x) (x)
#	define fs2h64(x) (x)
#	define e2fs_sbload(old, new) memcpy((new), (old), SBSIZE)
#	define e2fs_sbsave(old, new) memcpy((new), (old), SBSIZE)
#else
void e2fs_sb_bswap(struct ext2fs *, struct ext2fs *);
#	define h2fs16(x) bswap16(x)
#	define h2fs32(x) bswap32(x)
#	define h2fs64(x) bswap64(x)
#	define fs2h16(x) bswap16(x)
#	define fs2h32(x) bswap32(x)
#	define fs2h64(x) bswap64(x)
#	define e2fs_sbload(old, new) e2fs_sb_bswap((old), (new))
#	define e2fs_sbsave(old, new) e2fs_sb_bswap((old), (new))
#endif

/* Group descriptors are not byte swapped */
#define e2fs_cgload(old, new, size) memcpy((new), (old), (size))
#define e2fs_cgsave(old, new, size) memcpy((new), (old), (size))

/*
 * Turn file system block numbers into disk block addresses.
 * This maps file system blocks to device size blocks.
 */
#define EXT2_FSBTODB(fs, b)	((b) << (fs)->e2fs_fsbtodb)
#define EXT2_DBTOFSB(fs, b)	((b) >> (fs)->e2fs_fsbtodb)

/*
 * Macros for handling inode numbers:
 *	 inode number to file system block offset.
 *	 inode number to cylinder group number.
 *	 inode number to file system block address.
 */
#define	ino_to_cg(fs, x)	(((x) - 1) / (fs)->e2fs.e2fs_ipg)
#define	ino_to_fsba(fs, x)						\
	(fs2h32((fs)->e2fs_gd[ino_to_cg((fs), (x))].ext2bgd_i_tables) +	\
	(((x) - 1) % (fs)->e2fs.e2fs_ipg) / (fs)->e2fs_ipb)
#define	ino_to_fsbo(fs, x)	(((x) - 1) % (fs)->e2fs_ipb)

/*
 * Give cylinder group number for a file system block.
 * Give cylinder group block number for a file system block.
 */
#define	dtog(fs, d) (((d) - (fs)->e2fs.e2fs_first_dblock) / (fs)->e2fs.e2fs_fpg)
#define	dtogd(fs, d) \
	(((d) - (fs)->e2fs.e2fs_first_dblock) % (fs)->e2fs.e2fs_fpg)

/*
 * The following macros optimize certain frequently calculated
 * quantities by using shifts and masks in place of divisions
 * modulos and multiplications.
 */
#define ext2_blkoff(fs, loc)	/* calculates (loc % fs->e2fs_bsize) */ \
	((loc) & (fs)->e2fs_qbmask)
#define ext2_lblktosize(fs, blk) /* calculates (blk * fs->e2fs_bsize) */ \
	((blk) << (fs)->e2fs_bshift)
#define ext2_lblkno(fs, loc)	/* calculates (loc / fs->e2fs_bsize) */ \
	((loc) >> (fs)->e2fs_bshift)
#define ext2_blkroundup(fs, size) /* calculates roundup(size, fs->e2fs_bsize) */ \
	(((size) + (fs)->e2fs_qbmask) & (fs)->e2fs_bmask)
#define ext2_fragroundup(fs, size) /* calculates roundup(size, fs->e2fs_bsize) */ \
	(((size) + (fs)->e2fs_qbmask) & (fs)->e2fs_bmask)
/*
 * Determine the number of available frags given a
 * percentage to hold in reserve.
 */
#define freespace(fs) \
   ((fs)->e2fs.e2fs_fbcount - (fs)->e2fs.e2fs_rbcount)

/*
 * Number of indirects in a file system block.
 */
#define	EXT2_NINDIR(fs)	((fs)->e2fs_bsize / sizeof(uint32_t))

#endif /* !_UFS_EXT2FS_EXT2FS_H_ */