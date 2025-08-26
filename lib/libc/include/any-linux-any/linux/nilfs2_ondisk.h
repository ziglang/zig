/* SPDX-License-Identifier: LGPL-2.1+ WITH Linux-syscall-note */
/*
 * nilfs2_ondisk.h - NILFS2 on-disk structures
 *
 * Copyright (C) 2005-2008 Nippon Telegraph and Telephone Corporation.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 */
/*
 *  linux/include/linux/ext2_fs.h
 *
 * Copyright (C) 1992, 1993, 1994, 1995
 * Remy Card (card@masi.ibp.fr)
 * Laboratoire MASI - Institut Blaise Pascal
 * Universite Pierre et Marie Curie (Paris VI)
 *
 *  from
 *
 *  linux/include/linux/minix_fs.h
 *
 *  Copyright (C) 1991, 1992  Linus Torvalds
 */

#ifndef _LINUX_NILFS2_ONDISK_H
#define _LINUX_NILFS2_ONDISK_H

#include <linux/types.h>
#include <linux/magic.h>
#include <asm/byteorder.h>

#define NILFS_INODE_BMAP_SIZE	7

/**
 * struct nilfs_inode - structure of an inode on disk
 * @i_blocks: blocks count
 * @i_size: size in bytes
 * @i_ctime: creation time (seconds)
 * @i_mtime: modification time (seconds)
 * @i_ctime_nsec: creation time (nano seconds)
 * @i_mtime_nsec: modification time (nano seconds)
 * @i_uid: user id
 * @i_gid: group id
 * @i_mode: file mode
 * @i_links_count: links count
 * @i_flags: file flags
 * @i_bmap: block mapping
 * @i_xattr: extended attributes
 * @i_generation: file generation (for NFS)
 * @i_pad: padding
 */
struct nilfs_inode {
	__le64	i_blocks;
	__le64	i_size;
	__le64	i_ctime;
	__le64	i_mtime;
	__le32	i_ctime_nsec;
	__le32	i_mtime_nsec;
	__le32	i_uid;
	__le32	i_gid;
	__le16	i_mode;
	__le16	i_links_count;
	__le32	i_flags;
	__le64	i_bmap[NILFS_INODE_BMAP_SIZE];
#define i_device_code	i_bmap[0]
	__le64	i_xattr;
	__le32	i_generation;
	__le32	i_pad;
};

#define NILFS_MIN_INODE_SIZE		128

/**
 * struct nilfs_super_root - structure of super root
 * @sr_sum: check sum
 * @sr_bytes: byte count of the structure
 * @sr_flags: flags (reserved)
 * @sr_nongc_ctime: write time of the last segment not for cleaner operation
 * @sr_dat: DAT file inode
 * @sr_cpfile: checkpoint file inode
 * @sr_sufile: segment usage file inode
 */
struct nilfs_super_root {
	__le32 sr_sum;
	__le16 sr_bytes;
	__le16 sr_flags;
	__le64 sr_nongc_ctime;
	struct nilfs_inode sr_dat;
	struct nilfs_inode sr_cpfile;
	struct nilfs_inode sr_sufile;
};

#define NILFS_SR_MDT_OFFSET(inode_size, i)  \
	((unsigned long)&((struct nilfs_super_root *)0)->sr_dat + \
			(inode_size) * (i))
#define NILFS_SR_DAT_OFFSET(inode_size)     NILFS_SR_MDT_OFFSET(inode_size, 0)
#define NILFS_SR_CPFILE_OFFSET(inode_size)  NILFS_SR_MDT_OFFSET(inode_size, 1)
#define NILFS_SR_SUFILE_OFFSET(inode_size)  NILFS_SR_MDT_OFFSET(inode_size, 2)
#define NILFS_SR_BYTES(inode_size)	    NILFS_SR_MDT_OFFSET(inode_size, 3)

/*
 * Maximal mount counts
 */
#define NILFS_DFL_MAX_MNT_COUNT		50      /* 50 mounts */

/*
 * File system states (sbp->s_state, nilfs->ns_mount_state)
 */
#define NILFS_VALID_FS			0x0001  /* Unmounted cleanly */
#define NILFS_ERROR_FS			0x0002  /* Errors detected */
#define NILFS_RESIZE_FS			0x0004	/* Resize required */

/*
 * Mount flags (sbi->s_mount_opt)
 */
#define NILFS_MOUNT_ERROR_MODE		0x0070  /* Error mode mask */
#define NILFS_MOUNT_ERRORS_CONT		0x0010  /* Continue on errors */
#define NILFS_MOUNT_ERRORS_RO		0x0020  /* Remount fs ro on errors */
#define NILFS_MOUNT_ERRORS_PANIC	0x0040  /* Panic on errors */
#define NILFS_MOUNT_BARRIER		0x1000  /* Use block barriers */
#define NILFS_MOUNT_STRICT_ORDER	0x2000  /*
						 * Apply strict in-order
						 * semantics also for data
						 */
#define NILFS_MOUNT_NORECOVERY		0x4000  /*
						 * Disable write access during
						 * mount-time recovery
						 */
#define NILFS_MOUNT_DISCARD		0x8000  /* Issue DISCARD requests */


/**
 * struct nilfs_super_block - structure of super block on disk
 */
struct nilfs_super_block {
/*00*/	__le32	s_rev_level;		/* Revision level */
	__le16	s_minor_rev_level;	/* minor revision level */
	__le16	s_magic;		/* Magic signature */

	__le16  s_bytes;		/*
					 * Bytes count of CRC calculation
					 * for this structure. s_reserved
					 * is excluded.
					 */
	__le16  s_flags;		/* flags */
	__le32  s_crc_seed;		/* Seed value of CRC calculation */
/*10*/	__le32	s_sum;			/* Check sum of super block */

	__le32	s_log_block_size;	/*
					 * Block size represented as follows
					 * blocksize =
					 *     1 << (s_log_block_size + 10)
					 */
	__le64  s_nsegments;		/* Number of segments in filesystem */
/*20*/	__le64  s_dev_size;		/* block device size in bytes */
	__le64	s_first_data_block;	/* 1st seg disk block number */
/*30*/	__le32  s_blocks_per_segment;   /* number of blocks per full segment */
	__le32	s_r_segments_percentage; /* Reserved segments percentage */

	__le64  s_last_cno;		/* Last checkpoint number */
/*40*/	__le64  s_last_pseg;		/* disk block addr pseg written last */
	__le64  s_last_seq;             /* seq. number of seg written last */
/*50*/	__le64	s_free_blocks_count;	/* Free blocks count */

	__le64	s_ctime;		/*
					 * Creation time (execution time of
					 * newfs)
					 */
/*60*/	__le64	s_mtime;		/* Mount time */
	__le64	s_wtime;		/* Write time */
/*70*/	__le16	s_mnt_count;		/* Mount count */
	__le16	s_max_mnt_count;	/* Maximal mount count */
	__le16	s_state;		/* File system state */
	__le16	s_errors;		/* Behaviour when detecting errors */
	__le64	s_lastcheck;		/* time of last check */

/*80*/	__le32	s_checkinterval;	/* max. time between checks */
	__le32	s_creator_os;		/* OS */
	__le16	s_def_resuid;		/* Default uid for reserved blocks */
	__le16	s_def_resgid;		/* Default gid for reserved blocks */
	__le32	s_first_ino;		/* First non-reserved inode */

/*90*/	__le16  s_inode_size;		/* Size of an inode */
	__le16  s_dat_entry_size;       /* Size of a dat entry */
	__le16  s_checkpoint_size;      /* Size of a checkpoint */
	__le16	s_segment_usage_size;	/* Size of a segment usage */

/*98*/	__u8	s_uuid[16];		/* 128-bit uuid for volume */
/*A8*/	char	s_volume_name[80];	/* volume name */

/*F8*/	__le32  s_c_interval;           /* Commit interval of segment */
	__le32  s_c_block_max;          /*
					 * Threshold of data amount for
					 * the segment construction
					 */
/*100*/	__le64  s_feature_compat;	/* Compatible feature set */
	__le64  s_feature_compat_ro;	/* Read-only compatible feature set */
	__le64  s_feature_incompat;	/* Incompatible feature set */
	__u32	s_reserved[186];	/* padding to the end of the block */
};

/*
 * Codes for operating systems
 */
#define NILFS_OS_LINUX		0
/* Codes from 1 to 4 are reserved to keep compatibility with ext2 creator-OS */

/*
 * Revision levels
 */
#define NILFS_CURRENT_REV	2	/* current major revision */
#define NILFS_MINOR_REV		0	/* minor revision */
#define NILFS_MIN_SUPP_REV	2	/* minimum supported revision */

/*
 * Feature set definitions
 *
 * If there is a bit set in the incompatible feature set that the kernel
 * doesn't know about, it should refuse to mount the filesystem.
 */
#define NILFS_FEATURE_COMPAT_RO_BLOCK_COUNT	0x00000001ULL

#define NILFS_FEATURE_COMPAT_SUPP	0ULL
#define NILFS_FEATURE_COMPAT_RO_SUPP	NILFS_FEATURE_COMPAT_RO_BLOCK_COUNT
#define NILFS_FEATURE_INCOMPAT_SUPP	0ULL

/*
 * Bytes count of super_block for CRC-calculation
 */
#define NILFS_SB_BYTES  \
	((long)&((struct nilfs_super_block *)0)->s_reserved)

/*
 * Special inode number
 */
#define NILFS_ROOT_INO		2	/* Root file inode */
#define NILFS_DAT_INO		3	/* DAT file */
#define NILFS_CPFILE_INO	4	/* checkpoint file */
#define NILFS_SUFILE_INO	5	/* segment usage file */
#define NILFS_IFILE_INO		6	/* ifile */
#define NILFS_ATIME_INO		7	/* Atime file (reserved) */
#define NILFS_XATTR_INO		8	/* Xattribute file (reserved) */
#define NILFS_SKETCH_INO	10	/* Sketch file */
#define NILFS_USER_INO		11	/* Fisrt user's file inode number */

#define NILFS_SB_OFFSET_BYTES	1024	/* byte offset of nilfs superblock */

#define NILFS_SEG_MIN_BLOCKS	16	/*
					 * Minimum number of blocks in
					 * a full segment
					 */
#define NILFS_PSEG_MIN_BLOCKS	2	/*
					 * Minimum number of blocks in
					 * a partial segment
					 */
#define NILFS_MIN_NRSVSEGS	8	/*
					 * Minimum number of reserved
					 * segments
					 */

/*
 * We call DAT, cpfile, and sufile root metadata files.  Inodes of
 * these files are written in super root block instead of ifile, and
 * garbage collector doesn't keep any past versions of these files.
 */
#define NILFS_ROOT_METADATA_FILE(ino) \
	((ino) >= NILFS_DAT_INO && (ino) <= NILFS_SUFILE_INO)

/*
 * bytes offset of secondary super block
 */
#define NILFS_SB2_OFFSET_BYTES(devsize)	((((devsize) >> 12) - 1) << 12)

/*
 * Maximal count of links to a file
 */
#define NILFS_LINK_MAX		32000

/*
 * Structure of a directory entry
 *  (Same as ext2)
 */

#define NILFS_NAME_LEN 255

/*
 * Block size limitations
 */
#define NILFS_MIN_BLOCK_SIZE		1024
#define NILFS_MAX_BLOCK_SIZE		65536

/*
 * The new version of the directory entry.  Since V0 structures are
 * stored in intel byte order, and the name_len field could never be
 * bigger than 255 chars, it's safe to reclaim the extra byte for the
 * file_type field.
 */
struct nilfs_dir_entry {
	__le64	inode;			/* Inode number */
	__le16	rec_len;		/* Directory entry length */
	__u8	name_len;		/* Name length */
	__u8	file_type;		/* Dir entry type (file, dir, etc) */
	char	name[NILFS_NAME_LEN];	/* File name */
	char    pad;
};

/*
 * NILFS directory file types.  Only the low 3 bits are used.  The
 * other bits are reserved for now.
 */
enum {
	NILFS_FT_UNKNOWN,
	NILFS_FT_REG_FILE,
	NILFS_FT_DIR,
	NILFS_FT_CHRDEV,
	NILFS_FT_BLKDEV,
	NILFS_FT_FIFO,
	NILFS_FT_SOCK,
	NILFS_FT_SYMLINK,
	NILFS_FT_MAX
};

/*
 * NILFS_DIR_PAD defines the directory entries boundaries
 *
 * NOTE: It must be a multiple of 8
 */
#define NILFS_DIR_PAD			8
#define NILFS_DIR_ROUND			(NILFS_DIR_PAD - 1)
#define NILFS_DIR_REC_LEN(name_len)	(((name_len) + 12 + NILFS_DIR_ROUND) & \
					~NILFS_DIR_ROUND)
#define NILFS_MAX_REC_LEN		((1 << 16) - 1)

/**
 * struct nilfs_finfo - file information
 * @fi_ino: inode number
 * @fi_cno: checkpoint number
 * @fi_nblocks: number of blocks (including intermediate blocks)
 * @fi_ndatablk: number of file data blocks
 */
struct nilfs_finfo {
	__le64 fi_ino;
	__le64 fi_cno;
	__le32 fi_nblocks;
	__le32 fi_ndatablk;
};

/**
 * struct nilfs_binfo_v - information on a data block (except DAT)
 * @bi_vblocknr: virtual block number
 * @bi_blkoff: block offset
 */
struct nilfs_binfo_v {
	__le64 bi_vblocknr;
	__le64 bi_blkoff;
};

/**
 * struct nilfs_binfo_dat - information on a DAT node block
 * @bi_blkoff: block offset
 * @bi_level: level
 * @bi_pad: padding
 */
struct nilfs_binfo_dat {
	__le64 bi_blkoff;
	__u8 bi_level;
	__u8 bi_pad[7];
};

/**
 * union nilfs_binfo: block information
 * @bi_v: nilfs_binfo_v structure
 * @bi_dat: nilfs_binfo_dat structure
 */
union nilfs_binfo {
	struct nilfs_binfo_v bi_v;
	struct nilfs_binfo_dat bi_dat;
};

/**
 * struct nilfs_segment_summary - segment summary header
 * @ss_datasum: checksum of data
 * @ss_sumsum: checksum of segment summary
 * @ss_magic: magic number
 * @ss_bytes: size of this structure in bytes
 * @ss_flags: flags
 * @ss_seq: sequence number
 * @ss_create: creation timestamp
 * @ss_next: next segment
 * @ss_nblocks: number of blocks
 * @ss_nfinfo: number of finfo structures
 * @ss_sumbytes: total size of segment summary in bytes
 * @ss_pad: padding
 * @ss_cno: checkpoint number
 */
struct nilfs_segment_summary {
	__le32 ss_datasum;
	__le32 ss_sumsum;
	__le32 ss_magic;
	__le16 ss_bytes;
	__le16 ss_flags;
	__le64 ss_seq;
	__le64 ss_create;
	__le64 ss_next;
	__le32 ss_nblocks;
	__le32 ss_nfinfo;
	__le32 ss_sumbytes;
	__le32 ss_pad;
	__le64 ss_cno;
	/* array of finfo structures */
};

#define NILFS_SEGSUM_MAGIC	0x1eaffa11  /* segment summary magic number */

/*
 * Segment summary flags
 */
#define NILFS_SS_LOGBGN 0x0001  /* begins a logical segment */
#define NILFS_SS_LOGEND 0x0002  /* ends a logical segment */
#define NILFS_SS_SR     0x0004  /* has super root */
#define NILFS_SS_SYNDT  0x0008  /* includes data only updates */
#define NILFS_SS_GC     0x0010  /* segment written for cleaner operation */

/**
 * struct nilfs_btree_node - header of B-tree node block
 * @bn_flags: flags
 * @bn_level: level
 * @bn_nchildren: number of children
 * @bn_pad: padding
 */
struct nilfs_btree_node {
	__u8 bn_flags;
	__u8 bn_level;
	__le16 bn_nchildren;
	__le32 bn_pad;
};

/* flags */
#define NILFS_BTREE_NODE_ROOT   0x01

/* level */
#define NILFS_BTREE_LEVEL_DATA          0
#define NILFS_BTREE_LEVEL_NODE_MIN      (NILFS_BTREE_LEVEL_DATA + 1)
#define NILFS_BTREE_LEVEL_MAX           14	/* Max level (exclusive) */

/**
 * struct nilfs_direct_node - header of built-in bmap array
 * @dn_flags: flags
 * @dn_pad: padding
 */
struct nilfs_direct_node {
	__u8 dn_flags;
	__u8 pad[7];
};

/**
 * struct nilfs_palloc_group_desc - block group descriptor
 * @pg_nfrees: number of free entries in block group
 */
struct nilfs_palloc_group_desc {
	__le32 pg_nfrees;
};

/**
 * struct nilfs_dat_entry - disk address translation entry
 * @de_blocknr: block number
 * @de_start: start checkpoint number
 * @de_end: end checkpoint number
 * @de_rsv: reserved for future use
 */
struct nilfs_dat_entry {
	__le64 de_blocknr;
	__le64 de_start;
	__le64 de_end;
	__le64 de_rsv;
};

#define NILFS_MIN_DAT_ENTRY_SIZE	32

/**
 * struct nilfs_snapshot_list - snapshot list
 * @ssl_next: next checkpoint number on snapshot list
 * @ssl_prev: previous checkpoint number on snapshot list
 */
struct nilfs_snapshot_list {
	__le64 ssl_next;
	__le64 ssl_prev;
};

/**
 * struct nilfs_checkpoint - checkpoint structure
 * @cp_flags: flags
 * @cp_checkpoints_count: checkpoints count in a block
 * @cp_snapshot_list: snapshot list
 * @cp_cno: checkpoint number
 * @cp_create: creation timestamp
 * @cp_nblk_inc: number of blocks incremented by this checkpoint
 * @cp_inodes_count: inodes count
 * @cp_blocks_count: blocks count
 * @cp_ifile_inode: inode of ifile
 */
struct nilfs_checkpoint {
	__le32 cp_flags;
	__le32 cp_checkpoints_count;
	struct nilfs_snapshot_list cp_snapshot_list;
	__le64 cp_cno;
	__le64 cp_create;
	__le64 cp_nblk_inc;
	__le64 cp_inodes_count;
	__le64 cp_blocks_count;

	/*
	 * Do not change the byte offset of ifile inode.
	 * To keep the compatibility of the disk format,
	 * additional fields should be added behind cp_ifile_inode.
	 */
	struct nilfs_inode cp_ifile_inode;
};

#define NILFS_MIN_CHECKPOINT_SIZE	(64 + NILFS_MIN_INODE_SIZE)

/* checkpoint flags */
enum {
	NILFS_CHECKPOINT_SNAPSHOT,
	NILFS_CHECKPOINT_INVALID,
	NILFS_CHECKPOINT_SKETCH,
	NILFS_CHECKPOINT_MINOR,
};

#define NILFS_CHECKPOINT_FNS(flag, name)				\
static __inline__ void							\
nilfs_checkpoint_set_##name(struct nilfs_checkpoint *cp)		\
{									\
	cp->cp_flags = __cpu_to_le32(__le32_to_cpu(cp->cp_flags) |	\
				     (1UL << NILFS_CHECKPOINT_##flag));	\
}									\
static __inline__ void							\
nilfs_checkpoint_clear_##name(struct nilfs_checkpoint *cp)		\
{									\
	cp->cp_flags = __cpu_to_le32(__le32_to_cpu(cp->cp_flags) &	\
				   ~(1UL << NILFS_CHECKPOINT_##flag));	\
}									\
static __inline__ int							\
nilfs_checkpoint_##name(const struct nilfs_checkpoint *cp)		\
{									\
	return !!(__le32_to_cpu(cp->cp_flags) &				\
		  (1UL << NILFS_CHECKPOINT_##flag));			\
}

NILFS_CHECKPOINT_FNS(SNAPSHOT, snapshot)
NILFS_CHECKPOINT_FNS(INVALID, invalid)
NILFS_CHECKPOINT_FNS(MINOR, minor)

/**
 * struct nilfs_cpfile_header - checkpoint file header
 * @ch_ncheckpoints: number of checkpoints
 * @ch_nsnapshots: number of snapshots
 * @ch_snapshot_list: snapshot list
 */
struct nilfs_cpfile_header {
	__le64 ch_ncheckpoints;
	__le64 ch_nsnapshots;
	struct nilfs_snapshot_list ch_snapshot_list;
};

#define NILFS_CPFILE_FIRST_CHECKPOINT_OFFSET				\
	((sizeof(struct nilfs_cpfile_header) +				\
	  sizeof(struct nilfs_checkpoint) - 1) /			\
			sizeof(struct nilfs_checkpoint))

/**
 * struct nilfs_segment_usage - segment usage
 * @su_lastmod: last modified timestamp
 * @su_nblocks: number of blocks in segment
 * @su_flags: flags
 */
struct nilfs_segment_usage {
	__le64 su_lastmod;
	__le32 su_nblocks;
	__le32 su_flags;
};

#define NILFS_MIN_SEGMENT_USAGE_SIZE	16

/* segment usage flag */
enum {
	NILFS_SEGMENT_USAGE_ACTIVE,
	NILFS_SEGMENT_USAGE_DIRTY,
	NILFS_SEGMENT_USAGE_ERROR,
};

#define NILFS_SEGMENT_USAGE_FNS(flag, name)				\
static __inline__ void							\
nilfs_segment_usage_set_##name(struct nilfs_segment_usage *su)		\
{									\
	su->su_flags = __cpu_to_le32(__le32_to_cpu(su->su_flags) |	\
				   (1UL << NILFS_SEGMENT_USAGE_##flag));\
}									\
static __inline__ void							\
nilfs_segment_usage_clear_##name(struct nilfs_segment_usage *su)	\
{									\
	su->su_flags =							\
		__cpu_to_le32(__le32_to_cpu(su->su_flags) &		\
			    ~(1UL << NILFS_SEGMENT_USAGE_##flag));      \
}									\
static __inline__ int							\
nilfs_segment_usage_##name(const struct nilfs_segment_usage *su)	\
{									\
	return !!(__le32_to_cpu(su->su_flags) &				\
		  (1UL << NILFS_SEGMENT_USAGE_##flag));			\
}

NILFS_SEGMENT_USAGE_FNS(ACTIVE, active)
NILFS_SEGMENT_USAGE_FNS(DIRTY, dirty)
NILFS_SEGMENT_USAGE_FNS(ERROR, error)

static __inline__ void
nilfs_segment_usage_set_clean(struct nilfs_segment_usage *su)
{
	su->su_lastmod = __cpu_to_le64(0);
	su->su_nblocks = __cpu_to_le32(0);
	su->su_flags = __cpu_to_le32(0);
}

static __inline__ int
nilfs_segment_usage_clean(const struct nilfs_segment_usage *su)
{
	return !__le32_to_cpu(su->su_flags);
}

/**
 * struct nilfs_sufile_header - segment usage file header
 * @sh_ncleansegs: number of clean segments
 * @sh_ndirtysegs: number of dirty segments
 * @sh_last_alloc: last allocated segment number
 */
struct nilfs_sufile_header {
	__le64 sh_ncleansegs;
	__le64 sh_ndirtysegs;
	__le64 sh_last_alloc;
	/* ... */
};

#define NILFS_SUFILE_FIRST_SEGMENT_USAGE_OFFSET				\
	((sizeof(struct nilfs_sufile_header) +				\
	  sizeof(struct nilfs_segment_usage) - 1) /			\
			 sizeof(struct nilfs_segment_usage))

#endif	/* _LINUX_NILFS2_ONDISK_H */