/* $NetBSD: nilfs_fs.h,v 1.4 2022/02/16 22:00:56 andvar Exp $ */

/*
 * Copyright (c) 2008, 2009 Reinoud Zandijk
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
 * NilFS on disc structures
 *
 * Original definitions written by Koji Sato <koji@osrg.net>
 *                    and Ryusuke Konishi <ryusuke@osrg.net>
 */

#ifndef _NILFS_FS_H
#define _NILFS_FS_H

/*
 * NiLFS stores ext2fs compatible flags in its Inode. NetBSD uses a comparable
 * mechanism with file flags to be mutated with chflags(2).
 *
 * For completion, i mention all ext2-fs flags currently stored in NiLFS
 * inodes.
 */
#define NILFS_SECRM_FL           0x00000001 /* no mapping;    delete securely */
#define NILFS_UNRM_FL            0x00000002 /* no mapping;    allow undelete  */
#define NILFS_SYNC_FL            0x00000008 /* no mapping;    sychrone update */
#define NILFS_IMMUTABLE_FL       0x00000010 /* SF_IMMUTABLE | UF_IMMUTABLE    */
#define NILFS_APPEND_FL          0x00000020 /* SF_APPEND    | UF_APPEND       */
#define NILFS_NODUMP_FL          0x00000040 /* UF_NODUMP                      */
#define NILFS_NOATIME_FL         0x00000080 /* no mapping;    no atime update */
/* intermediate bits are reserved for compression settings */
#define NILFS_NOTAIL_FL          0x00008000 /* no mapping;    dont merge tail */
#define NILFS_DIRSYNC_FL         0x00010000 /* no mapping;    dirsync         */

#define NILFS_FL_USER_VISIBLE    0x0003DFFF /* flags visible to user          */
#define NILFS_FL_USER_MODIFIABLE 0x000380FF /* flags modifiable by user       */



/*
 * NiLFS stores files in hierarchical B-trees in tupels of (dkey, dptr).
 * Entries in a level N btree point to a btree of level N-1. As dkey value the
 * first block number to be found in the level N-1 btree is taken.
 *
 * To conserve disk space and to reduce an extra lookup, small B-tree's of
 * level 0 consisting of only the first [0..NILFS_DIRECT_KEY_MAX> entries are
 * stored directly into the inode without dkey. Otherwise the entries point to
 * the B-tree's of level N-1.
 *
 * In all B-trees, but of the system DAT-file, the dptr values are virtual
 * block numbers. The dptr values in the B-tree of the system DAT-file are
 * physical block numbers since the DAT performs virtual to physical block
 * mapping.
 */

#define NILFS_INODE_BMAP_SIZE    7

#define NILFS_BMAP_SIZE		(NILFS_INODE_BMAP_SIZE * sizeof(uint64_t))
#define NILFS_BMAP_INVALID_PTR	0

#define NILFS_DIRECT_NBLOCKS	(NILFS_BMAP_SIZE / sizeof(uint64_t) - 1)
#define NILFS_DIRECT_KEY_MIN	0
#define NILFS_DIRECT_KEY_MAX	(NILFS_DIRECT_NBLOCKS - 1)

#define NILFS_BMAP_SMALL_LOW	NILFS_DIRECT_KEY_MIN
#define NILFS_BMAP_SMALL_HIGH	NILFS_DIRECT_KEY_MAX
#define NILFS_BMAP_LARGE_LOW	NILFS_BTREE_ROOT_NCHILDREN_MAX
#define NILFS_BMAP_LARGE_HIGH	NILFS_BTREE_KEY_MAX


/*
 * B-tree header found on all btree blocks and in the direct-entry. Its size
 * should be 64 bits. In a direct entry, it is followed by 64 bits block
 * numbers for the translation of block [0..NILFS_DIRECT_KEY_MAX>. In large
 * bmaps its followed by pairs of 64 bit dkey and 64 bit dptr.
 */

struct nilfs_btree_node {
	uint8_t  bn_flags;		/* btree flags                       */
	uint8_t  bn_level;		/* level of btree                    */
	uint16_t bn_nchildren;		/* number of children in this record */
	uint32_t bn_pad;		/* pad to 64 bits                    */
};


/* btree flags stored in nilfs_btree_node->bn_flags */
#define NILFS_BTREE_NODE_ROOT	0x01
#define NILFS_BMAP_LARGE	0x01	/* equivalent to BTREE_NODE_ROOT */

/* btree levels stored in nilfs_btree_node->bn_level */
#define NILFS_BTREE_LEVEL_DATA		0
#define NILFS_BTREE_LEVEL_NODE_MIN	(NILFS_BTREE_LEVEL_DATA + 1)
#define NILFS_BTREE_LEVEL_MAX		14

/*
 * Calculate number of entries that fit into the `direct' space
 */
#define NILFS_BTREE_ROOT_SIZE		NILFS_BMAP_SIZE
#define NILFS_BTREE_ROOT_NCHILDREN_MAX					\
	((NILFS_BTREE_ROOT_SIZE - sizeof(struct nilfs_btree_node)) /	\
	 (sizeof(uint64_t /* dkey */) + sizeof(uint64_t /* dptr */)))
#define NILFS_BTREE_ROOT_NCHILDREN_MIN	0

/*
 * Calculate number of entries that fit into a non LEVEL_DATA nodes. Each of
 * those nodes are padded with one extra 64 bit (extension?)
 */
#define NILFS_BTREE_NODE_EXTRA_PAD_SIZE	(sizeof(uint64_t))
#define NILFS_BTREE_NODE_NCHILDREN_MAX(nodesize)			\
	(((nodesize) - sizeof(struct nilfs_btree_node) -		\
		NILFS_BTREE_NODE_EXTRA_PAD_SIZE) /			\
	 (sizeof(uint64_t /* dkey */) + sizeof(uint64_t /* dptr */)))
#define NILFS_BTREE_NODE_NCHILDREN_MIN(nodesize)			\
	((NILFS_BTREE_NODE_NCHILDREN_MAX(nodesize) - 1) / 2 + 1)
#define NILFS_BTREE_KEY_MIN	( (uint64_t) 0)
#define NILFS_BTREE_KEY_MAX	(~(uint64_t) 0)


/* 
 * NiLFS inode structure. There are a few dedicated inode numbers that are
 * defined here first.
 */

#define NILFS_ROOT_INO           2         /* Root file inode                */
#define NILFS_DAT_INO            3         /* DAT file                       */
#define NILFS_CPFILE_INO         4         /* checkpoint file                */
#define NILFS_SUFILE_INO         5         /* segment usage file             */
#define NILFS_IFILE_INO          6         /* ifile                          */
#define NILFS_ATIME_INO          7         /* Atime file (reserved)          */
#define NILFS_XATTR_INO          8         /* Xattribute file (reserved)     */
#define NILFS_SKETCH_INO         10        /* Sketch file (obsolete)         */
#define NILFS_USER_INO           11        /* First user's file inode number */

struct nilfs_inode {
         uint64_t i_blocks;		/* size in device blocks             */
         uint64_t i_size;		/* size in bytes                     */
         uint64_t i_ctime;		/* creation time in seconds part     */
         uint64_t i_mtime;		/* modification time in seconds part */
         uint32_t i_ctime_nsec;		/* creation time nanoseconds part    */
	 uint32_t i_mtime_nsec;		/* modification time in nanoseconds  */
         uint32_t i_uid;		/* user id                           */
         uint32_t i_gid;		/* group id                          */
         uint16_t i_mode;		/* file mode                         */
         uint16_t i_links_count;	/* number of references to the inode */
         uint32_t i_flags;		/* NILFS_*_FL flags                  */
         uint64_t i_bmap[NILFS_INODE_BMAP_SIZE]; /* btree direct/large       */
#define i_device_code     i_bmap[0]	/* 64 bits composed of major+minor   */
         uint64_t i_xattr;		/* reserved for extended attributes  */
         uint32_t i_generation;		/* file generation for NFS           */
         uint32_t i_pad;		/* make it 64 bits aligned           */
};


/*
 * In NiLFS each checkpoint/snapshot has a super root.
 *
 * The super root holds the inodes of the three system files: `dat', `cp' and
 * 'su' files. All other FS state is defined by those.
 *
 * It is crc checksum'ed and time stamped.
 */

struct nilfs_super_root {
         uint32_t sr_sum;		/* check-sum                         */
         uint16_t sr_bytes;		/* byte count of this structure      */
         uint16_t sr_flags;		/* reserved for flags                */
         uint64_t sr_nongc_ctime;	/* timestamp, not for cleaner(?)     */
         struct nilfs_inode sr_dat;	/* DAT, virt->phys translation inode */
         struct nilfs_inode sr_cpfile;	/* CP, checkpoints inode             */
         struct nilfs_inode sr_sufile;  /* SU, segment usage inode           */
};

#define NILFS_SR_MDT_OFFSET(inode_size, i)  \
         ((uint32_t)&((struct nilfs_super_root *)0)->sr_dat + \
                           (inode_size) * (i))
#define NILFS_SR_DAT_OFFSET(inode_size)     NILFS_SR_MDT_OFFSET(inode_size, 0)
#define NILFS_SR_CPFILE_OFFSET(inode_size)  NILFS_SR_MDT_OFFSET(inode_size, 1)
#define NILFS_SR_SUFILE_OFFSET(inode_size)  NILFS_SR_MDT_OFFSET(inode_size, 2)
#define NILFS_SR_BYTES                  (sizeof(struct nilfs_super_root))



/*
 * NiLFS has a superblock that describes the basic structure and mount
 * history. It also records some sizes of structures found on the disc for
 * sanity checks.
 *
 * The superblock is stored at two places: NILFS_SB_OFFSET_BYTES and
 * NILFS_SB2_OFFSET_BYTES.
 */

#define NILFS_DFL_MAX_MNT_COUNT  50      /* default 50 mounts before fsck */
#define NILFS_EIO_RETRY_COUNT    4	/* then give up, not used yet     */

/* File system states stored on disc in superblock's sbp->s_state */
#define NILFS_VALID_FS           0x0001  /* cleanly unmounted and all is ok  */
#define NILFS_ERROR_FS           0x0002  /* there were errors detected, fsck */
#define NILFS_RESIZE_FS          0x0004  /* resize required, XXX unknown flag*/
#define NILFS_MOUNT_STATE_BITS	"\20\1VALID_FS\2ERROR_FS\3RESIZE_FS"

/* Mount option flags passed in Linux; Not used but here for reference */
#define NILFS_MOUNT_ERROR_MODE   0x0070  /* error mode mask */
#define NILFS_MOUNT_ERRORS_CONT  0x0010  /* continue on errors */
#define NILFS_MOUNT_ERRORS_RO    0x0020  /* remount fs ro on errors */
#define NILFS_MOUNT_ERRORS_PANIC 0x0040  /* panic on errors */
#define NILFS_MOUNT_SNAPSHOT     0x0080  /* snapshot flag */
#define NILFS_MOUNT_BARRIER      0x1000  /* use block barriers XXX what is this? */
#define NILFS_MOUNT_STRICT_ORDER 0x2000  /* apply strict in-order; */
                                         /* semantics also for data */

struct nilfs_super_block {
         uint32_t s_rev_level;             /* major disk format revision     */
         uint16_t s_minor_rev_level;       /* minor disc format revision     */
         uint16_t s_magic;                 /* magic value for identification */

         uint16_t s_bytes;                 /* byte count of CRC calculation
                                              for this structure. s_reserved
                                              is excluded! */
         uint16_t s_flags;                 /* linux mount flags, XXX can they
					      be ignored? */
         uint32_t s_crc_seed;              /* seed value of CRC calculation  */
         uint32_t s_sum;                   /* check sum of super block       */

	 /* Block size represented as follows
                        blocksize = 1 << (s_log_block_size + 10) */
         uint32_t s_log_block_size;
         uint64_t s_nsegments;             /* number of segm. in filesystem  */
         uint64_t s_dev_size;              /* block device size in bytes     */
         uint64_t s_first_data_block;      /* 1st seg disk block number      */
         uint32_t s_blocks_per_segment;    /* number of blocks per segment   */
         uint32_t s_r_segments_percentage; /* reserved segments percentage   */

         uint64_t s_last_cno;              /* last checkpoint number         */
         uint64_t s_last_pseg;             /* addr part. segm. written last  */
         uint64_t s_last_seq;              /* seq.number of seg written last */
         uint64_t s_free_blocks_count;     /* free blocks count              */

         uint64_t s_ctime;                 /* creation time (execution time
					      of newfs) */
         uint64_t s_mtime;                 /* mount time                     */
         uint64_t s_wtime;                 /* write time                     */
         uint16_t s_mnt_count;             /* mount count                    */
         uint16_t s_max_mnt_count;         /* maximal mount count            */
         uint16_t s_state;                 /* file system state              */
         uint16_t s_errors;                /* behaviour on detecting errors  */
         uint64_t s_lastcheck;             /* time of last checked           */

         uint32_t s_checkinterval;         /* max. time between checks       */
         uint32_t s_creator_os;            /* OS that created it             */
         uint16_t s_def_resuid;            /* default uid for reserv. blocks */
         uint16_t s_def_resgid;            /* default gid for reserv. blocks */
         uint32_t s_first_ino;             /* first non-reserved inode       */

         uint16_t s_inode_size;            /* size of an inode               */
         uint16_t s_dat_entry_size;        /* size of a dat entry            */
         uint16_t s_checkpoint_size;       /* size of a checkpoint           */
         uint16_t s_segment_usage_size;    /* size of a segment usage        */

         uint8_t  s_uuid[16];              /* 128-bit uuid for volume        */
         char     s_volume_name[80];       /* volume name                    */

         uint32_t s_c_interval;            /* commit interval of segment     */
         uint32_t s_c_block_max;           /* threshold of data amount for
                                              the segment construction */
         uint32_t s_reserved[192];         /* padding to end of the block    */
};

#define NILFS_SUPER_MAGIC        0x3434    /* NILFS filesystem  magic number */
#define NILFS_SB_OFFSET_BYTES    1024      /* byte offset of nilfs superblock */
#define NILFS_SB2_OFFSET_BYTES(devsize)	((((devsize) >> 12) - 1) << 12)


/* codes for operating systems in superblock */
#define NILFS_OS_LINUX           0
#define NILFS_OS_UNK1		 1	/* ext2 */
#define NILFS_OS_UNK2		 2	/* ext2 */
#define NILFS_OS_UNK3		 3	/* ext2 */
#define NILFS_OS_NETBSD		10	/* temp */

/* NiLFS revision levels */
#define NILFS_CURRENT_REV        2         /* current major revision */
#define NILFS_MINOR_REV          0         /* minor revision */

/* Bytes count of super_block for CRC-calculation */
#define NILFS_SB_BYTES  \
         ((uint32_t)&((struct nilfs_super_block *)0)->s_reserved)

/* Maximal count of links to a file */
#define NILFS_LINK_MAX           32000


/*
 * Structure of a directory entry, same as ext2.
 *
 * The `file_type' is chosen there since filenames are limited to 256 bytes
 * and the name_len in ext2 is a two byter.
 *
 * Note that they can't span blocks; the rec_len fills out.
 */

#define NILFS_NAME_LEN 255
struct nilfs_dir_entry {
         uint64_t inode;                    /* inode number */
         uint16_t rec_len;                  /* directory entry length */
         uint8_t  name_len;                 /* name length */
         uint8_t  file_type;
         char     name[NILFS_NAME_LEN];     /* file name */
         char     pad;
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
#define NILFS_DIR_PAD               8
#define NILFS_DIR_ROUND             (NILFS_DIR_PAD - 1)
#define NILFS_DIR_REC_LEN(name_len) (((name_len) + 12 + NILFS_DIR_ROUND) & \
                                        ~NILFS_DIR_ROUND)

/*
 * NiLFS devides the disc into fixed length segments. Each segment is filled
 * with one or more partial segments of variable lengths.
 *
 * Each partial segment has a segment summary header followed by updates of
 * files and optionally a super root.
 */

struct nilfs_finfo {
         uint64_t fi_ino;		/* inode number                     */
         uint64_t fi_cno;		/* checkpoint associated with this  */
         uint32_t fi_nblocks;		/* size in blocks of this finfo     */
         uint32_t fi_ndatablk;		/* number of data blocks            */
	 /* For the DAT file */
	 /* 	fi_ndatablk               * nilfs_binfo.bi_dat.bi_blkoff */
	 /*	fi_nblocks - fi_ndatablks * nilfs_binfo.bi_dat           */
	 /* Other files */
	 /*     fi_ndatablk               * nilfs_binfo.bi_v             */
	 /*     fi_nblocks - fi_ndatablks * nilfs_binfo.bi_v.bi_vblocknr */
};


/*
 * Virtual to physical block translation information. For data blocks it maps
 * logical block number bi_blkoff to virtual block nr bi_vblocknr. For non
 * datablocks it is the virtual block number assigned to an inserted btree
 * level and thus has no bi_blkoff. The physical block number is the next
 * available data block in the partial segment after all the finfo's.
 */
struct nilfs_binfo_v {
         uint64_t bi_vblocknr;		/* assigned virtual block number     */
         uint64_t bi_blkoff;		/* for file's logical block number   */
};


/*
 * DAT allocation. For data blocks just the logical block number that maps on
 * the next available data block in the partial segment after the finfo's.
 * Intermediate btree blocks are looked up by their blkoffset dkey and their
 * level and given the next available data block.
 */
struct nilfs_binfo_dat {
         uint64_t bi_blkoff;		/* DAT file's logical block number */
         uint8_t bi_level;		/* btree level */
         uint8_t bi_pad[7];
};


/* Convenience union for both types of binfo's */
union nilfs_binfo {
         struct nilfs_binfo_v bi_v;
         struct nilfs_binfo_dat bi_dat;
};


/* The (partial) segment summary itself */
struct nilfs_segment_summary {
         uint32_t ss_datasum;		/* CRC of complete data block        */
         uint32_t ss_sumsum;		/* CRC of segment summary only       */
         uint32_t ss_magic;		/* magic to identify segment summary */
         uint16_t ss_bytes;		/* size of segment summary structure */
         uint16_t ss_flags;		/* NILFS_SS_* flags                  */
         uint64_t ss_seq;		/* sequence number of this segm. sum */
         uint64_t ss_create;		/* creation timestamp in seconds     */
         uint64_t ss_next;		/* blocknumber of next segment       */
         uint32_t ss_nblocks;		/* number of blocks follow           */
         uint32_t ss_nfinfo;		/* number of finfo structures follow */
         uint32_t ss_sumbytes;		/* total size of segment summary     */
         uint32_t ss_pad;
	 uint64_t ss_cno;		/* latest checkpoint number known    */
         /* stream of finfo structures */
};

#define NILFS_SEGSUM_MAGIC       0x1eaffa11  /* segment summary magic number */

/* Segment summary flags */
#define NILFS_SS_LOGBGN 0x0001  /* begins a logical segment */
#define NILFS_SS_LOGEND 0x0002  /* ends a logical segment */
#define NILFS_SS_SR     0x0004  /* has super root */
#define NILFS_SS_SYNDT  0x0008  /* includes data only updates */
#define NILFS_SS_GC     0x0010  /* segment written for cleaner operation */
#define NILFS_SS_FLAG_BITS "\20\1LOGBGN\2LOGEND\3SR\4SYNDT\5GC"

/* Segment summary constrains */
#define NILFS_SEG_MIN_BLOCKS     16        /* minimum number of blocks in a
					      full segment */
#define NILFS_PSEG_MIN_BLOCKS    2         /* minimum number of blocks in a
					      partial segment */
#define NILFS_MIN_NRSVSEGS       8         /* minimum number of reserved
					      segments */

/*
 * Structure of DAT/inode file.
 *
 * A DAT file is divided into groups. The maximum number of groups is the
 * number of block group descriptors that fit into one block; this descriptor
 * only gives the number of free entries in the associated group.
 *
 * Each group has a block sized bitmap indicating if an entry is taken or
 * empty. Each bit stands for a DAT entry.
 *
 * The inode file has exactly the same format only the entries are inode
 * entries.
 */

struct nilfs_block_group_desc {
         uint32_t bg_nfrees;		/* num. free entries in block group  */
};


/* DAT entry in a super root's DAT file */
struct nilfs_dat_entry {
         uint64_t de_blocknr;		/* block number                      */
         uint64_t de_start;		/* valid from checkpoint             */
         uint64_t de_end;		/* valid till checkpoint             */
         uint64_t de_rsv;		/* reserved for future use           */
};


/*
 * Structure of CP file.
 *
 * A snapshot is just a checkpoint only its protected against removal by the
 * cleaner. The snapshots are kept on a double linked list of checkpoints.
 */

struct nilfs_snapshot_list {
         uint64_t ssl_next;		/* checkpoint nr. forward */
         uint64_t ssl_prev;		/* checkpoint nr. back    */
};


/* checkpoint entry structure */
struct nilfs_checkpoint {
         uint32_t cp_flags;		/* NILFS_CHECKPOINT_* flags          */
         uint32_t cp_checkpoints_count;	/* ZERO, not used anymore?           */
         struct nilfs_snapshot_list cp_snapshot_list; /* list of snapshots   */
         uint64_t cp_cno;		/* checkpoint number                 */
         uint64_t cp_create;		/* creation timestamp                */
         uint64_t cp_nblk_inc;		/* number of blocks incremented      */
         uint64_t cp_inodes_count;	/* number of inodes in this cp.      */
         uint64_t cp_blocks_count;      /* reserved (might be deleted)       */
         struct nilfs_inode cp_ifile_inode;	/* inode file inode          */
};

/* checkpoint flags */
#define NILFS_CHECKPOINT_SNAPSHOT 1
#define NILFS_CHECKPOINT_INVALID  2
#define NILFS_CHECKPOINT_SKETCH   4
#define NILFS_CHECKPOINT_MINOR	  8
#define NILFS_CHECKPOINT_BITS "\20\1SNAPSHOT\2INVALID\3SKETCH\4MINOR"


/* header of the checkpoint file */
struct nilfs_cpfile_header {
         uint64_t ch_ncheckpoints;	/* number of checkpoints             */
         uint64_t ch_nsnapshots;	/* number of snapshots               */
         struct nilfs_snapshot_list ch_snapshot_list;	/* snapshot list     */
};

/* to accommodate with the header */
#define NILFS_CPFILE_FIRST_CHECKPOINT_OFFSET    \
        ((sizeof(struct nilfs_cpfile_header) +                          \
          sizeof(struct nilfs_checkpoint) - 1) /                        \
                        sizeof(struct nilfs_checkpoint))


/*
 * Structure of SU file.
 *
 * The segment usage file sums up how each of the segments are used. They are
 * indexed by their segment number.
 */

/* segment usage entry */
struct nilfs_segment_usage {
         uint64_t su_lastmod;		/* last modified timestamp           */
         uint32_t su_nblocks;		/* number of blocks in segment       */
         uint32_t su_flags;		/* NILFS_SEGMENT_USAGE_* flags       */
};

/* segment usage flag */
#define NILFS_SEGMENT_USAGE_ACTIVE	    1
#define NILFS_SEGMENT_USAGE_DIRTY	    2
#define NILFS_SEGMENT_USAGE_ERROR	    4
#define NILFS_SEGMENT_USAGE_BITS "\20\1ACTIVE\2DIRTY\3ERROR"


/* header of the segment usage file */
struct nilfs_sufile_header {
         uint64_t sh_ncleansegs;	/* number of segments marked clean   */
         uint64_t sh_ndirtysegs;	/* number of segments marked dirty   */
         uint64_t sh_last_alloc;	/* last allocated segment number     */
         /* ... */
};

/* to accommodate with the header */
#define NILFS_SUFILE_FIRST_SEGMENT_USAGE_OFFSET \
         ((sizeof(struct nilfs_sufile_header) + \
           sizeof(struct nilfs_segment_usage) - 1) / \
                            sizeof(struct nilfs_segment_usage))


#endif