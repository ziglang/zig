/*	$NetBSD: lfs.h,v 1.208 2020/03/28 01:08:42 christos Exp $	*/

/*  from NetBSD: dinode.h,v 1.25 2016/01/22 23:06:10 dholland Exp  */
/*  from NetBSD: dir.h,v 1.25 2015/09/01 06:16:03 dholland Exp  */

/*-
 * Copyright (c) 1999, 2000, 2001, 2002, 2003 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Konrad E. Schroder <perseant@hhhh.org>.
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
/*-
 * Copyright (c) 1991, 1993
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
 *	@(#)lfs.h	8.9 (Berkeley) 5/8/95
 */
/*
 * Copyright (c) 2002 Networks Associates Technology, Inc.
 * All rights reserved.
 *
 * This software was developed for the FreeBSD Project by Marshall
 * Kirk McKusick and Network Associates Laboratories, the Security
 * Research Division of Network Associates, Inc. under DARPA/SPAWAR
 * contract N66001-01-C-8035 ("CBOSS"), as part of the DARPA CHATS
 * research program
 *
 * Copyright (c) 1982, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)dinode.h	8.9 (Berkeley) 3/29/95
 */
/*
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)dir.h	8.5 (Berkeley) 4/27/95
 */

/*
 * NOTE: COORDINATE ON-DISK FORMAT CHANGES WITH THE FREEBSD PROJECT.
 */

#ifndef _UFS_LFS_LFS_H_
#define _UFS_LFS_LFS_H_

#if !defined(_KERNEL) && !defined(_STANDALONE)
#include <stddef.h> /* for offsetof */
#endif

#include <sys/rwlock.h>
#include <sys/mutex.h>
#include <sys/queue.h>
#include <sys/condvar.h>
#include <sys/mount.h>
#include <sys/pool.h>

/*
 * Compile-time options for LFS.
 */
#define LFS_IFIND_RETRIES  16
#define LFS_LOGLENGTH      1024 /* size of debugging log */
#define LFS_MAX_ACTIVE	   10	/* Dirty segments before ckp forced */

/*
 * Fixed filesystem layout parameters
 */
#define	LFS_LABELPAD	8192		/* LFS label size */
#define	LFS_SBPAD	8192		/* LFS superblock size */

#define	LFS_UNUSED_INUM	0		/* 0: out of band inode number */
#define	LFS_IFILE_INUM	1		/* 1: IFILE inode number */
					/* 2: Root inode number */
#define	LFS_LOSTFOUNDINO 3		/* 3: lost+found inode number */
#define	LFS_FIRST_INUM	4		/* 4: first free inode number */

/*
 * The root inode is the root of the file system.  Inode 0 can't be used for
 * normal purposes and historically bad blocks were linked to inode 1, thus
 * the root inode is 2.  (Inode 1 is no longer used for this purpose, however
 * numerous dump tapes make this assumption, so we are stuck with it).
 */
#define	ULFS_ROOTINO	((ino_t)2)

/*
 * The Whiteout inode# is a dummy non-zero inode number which will
 * never be allocated to a real file.  It is used as a place holder
 * in the directory entry which has been tagged as a LFS_DT_WHT entry.
 * See the comments about ULFS_ROOTINO above.
 */
#define	ULFS_WINO	((ino_t)1)


#define	LFS_V1_SUMMARY_SIZE	512     /* V1 fixed summary size */
#define	LFS_DFL_SUMMARY_SIZE	512	/* Default summary size */

#define LFS_MAXNAMLEN	255		/* maximum name length in a dir */

#define ULFS_NXADDR	2
#define	ULFS_NDADDR	12		/* Direct addresses in inode. */
#define	ULFS_NIADDR	3		/* Indirect addresses in inode. */

/*
 * Adjustable filesystem parameters
 */
#ifndef LFS_ATIME_IFILE
# define LFS_ATIME_IFILE 0 /* Store atime info in ifile (optional in LFSv1) */
#endif
#define LFS_MARKV_MAXBLKCNT	65536	/* Max block count for lfs_markv() */

/*
 * Directories
 */

/*
 * Directories in LFS are files; they use the same inode and block
 * mapping structures that regular files do. The directory per se is
 * manifested in the file contents: an unordered, unstructured
 * sequence of variable-size directory entries.
 *
 * This format and structure is taken (via what was originally shared
 * ufs-level code) from FFS. Each directory entry is a fixed header
 * followed by a string, the total length padded to a 4-byte boundary.
 * All strings include a null terminator; the maximum string length
 * is LFS_MAXNAMLEN, which is 255.
 *
 * The directory entry header structure (struct lfs_dirheader) is just
 * the header information. A complete entry is this plus a null-
 * terminated name following it, plus some amount of padding. The
 * length of the name (not including the null terminator) is given by
 * the namlen field of the header; the complete record length,
 * including the null terminator and padding, is given by the reclen
 * field of the header. The record length is always 4-byte aligned.
 * (Even on 64-bit volumes, the record length is only 4-byte aligned,
 * not 8-byte.)
 *
 * Historically, FFS directories were/are organized into blocks of
 * size DIRBLKSIZE that can be written atomically to disk at the
 * hardware level. Directory entries are not allowed to cross the
 * boundaries of these blocks. The resulting atomicity is important
 * for the integrity of FFS volumes; however, for LFS it's irrelevant.
 * All we have to care about is not writing out directories that
 * confuse earlier ufs-based versions of the LFS code.
 *
 * This means [to be determined]. (XXX)
 *
 * As DIRBLKSIZE in its FFS sense is hardware-dependent, and file
 * system images do from time to time move to different hardware, code
 * that reads directories should be prepared to handle directories
 * written in a context where DIRBLKSIZE was different (smaller or
 * larger) than its current value. Note however that it is not
 * sensible for DIRBLKSIZE to be larger than the volume fragment size,
 * and not practically possible for it to be larger than the volume
 * block size.
 *
 * Some further notes:
 *    - the LFS_DIRSIZ macro provides the minimum space needed to hold
 *      a directory entry.
 *    - any particular entry may be arbitrarily larger (which is why the
 *      header stores both the entry size and the name size) to pad out
 *      unused space.
 *    - historically the padding in an entry is not necessarily zeroed
 *      but may contain trash.
 *    - dp->d_reclen is the size of the entry. This is always 4-byte
 *      aligned.
 *    - dp->d_namlen is the length of the string, and should always be
 *      the same as strlen(dp->d_name).
 *    - in particular, space available in an entry is given by
 *      dp->d_reclen - LFS_DIRSIZ(dp), and all space available within a
 *      directory block is tucked away within an existing entry.
 *    - all space within a directory block is part of some entry.
 *    - therefore, inserting a new entry requires finding and
 *      splitting a suitable existing entry, and when entries are
 *      removed their space is merged into the entry ahead of them.
 *    - an empty/unused entry has d_ino set to 0. This normally only
 *      appears in the first entry in a block, as elsewhere the unused
 *      entry should have been merged into the one before it. However,
 *      fsck leaves such entries behind so they must be tolerated
 *      elsewhere.
 *    - a completely empty directory block has one entry whose
 *      d_reclen is DIRBLKSIZ and whose d_ino is 0.
 *
 * The "old directory format" referenced by the fs->lfs_isolddirfmt
 * flag (and some other things) refers to when the type field was
 * added to directory entries. This change was made to FFS in the 80s,
 * well before LFS was first written; there should be no LFS volumes
 * (and certainly no LFS v2-format volumes or LFS64 volumes) where the
 * old format pertains. All of the related logic should probably be
 * removed; however, it hasn't been yet, and we get to carry it around
 * until we can be conclusively sure it isn't needed.
 *
 * In the "old directory format" there is no type field and the namlen
 * field is correspondingly 16 bits wide. On big-endian volumes this
 * has no effect: namlen cannot exceed 255, so the upper byte is
 * always 0 and this reads back from the type field as LFS_DT_UNKNOWN.
 * On little-endian volumes, the namlen field will always be 0 and
 * the namlen value needs to be read out of the type field. (The type
 * is always LFS_DT_UNKNOWN.) The directory accessor functions take
 * care of this so nothing else needs to be aware of it.
 *
 * LFS_OLDDIRFMT and LFS_NEWDIRFMT are code numbers for the old and
 * new directory format respectively. These codes do not appear on
 * disk; they're generated from a runtime macro called FSFMT() that's
 * cued by other things. This is why (confusingly) LFS_OLDDIRFMT is 1
 * and LFS_NEWDIRFMT is 0.
 *
 * FSFMT(), LFS_OLDDIRFMT, and LFS_NEWDIRFMT should be removed. (XXX)
 */

/*
 * Directory block size.
 */
#undef	LFS_DIRBLKSIZ
#define	LFS_DIRBLKSIZ	DEV_BSIZE

/*
 * Convert between stat structure type codes and directory entry type codes.
 */
#define	LFS_IFTODT(mode)	(((mode) & 0170000) >> 12)
#define	LFS_DTTOIF(dirtype)	((dirtype) << 12)

/*
 * Theoretically, directories can be more than 2Gb in length; however, in
 * practice this seems unlikely. So, we define the type doff_t as a 32-bit
 * quantity to keep down the cost of doing lookup on a 32-bit machine.
 */
#define	doff_t		int32_t
#define	lfs_doff_t	int32_t
#define	LFS_MAXDIRSIZE	(0x7fffffff)

/*
 * File types for d_type
 */
#define	LFS_DT_UNKNOWN	 0
#define	LFS_DT_FIFO	 1
#define	LFS_DT_CHR	 2
#define	LFS_DT_DIR	 4
#define	LFS_DT_BLK	 6
#define	LFS_DT_REG	 8
#define	LFS_DT_LNK	10
#define	LFS_DT_SOCK	12
#define	LFS_DT_WHT	14

/*
 * (See notes above)
 */

struct lfs_dirheader32 {
	uint32_t dh_ino;		/* inode number of entry */
	uint16_t dh_reclen;		/* length of this record */
	uint8_t  dh_type; 		/* file type, see below */
	uint8_t  dh_namlen;		/* length of string in d_name */
};
__CTASSERT(sizeof(struct lfs_dirheader32) == 8);

struct lfs_dirheader64 {
	uint64_t dh_ino;		/* inode number of entry */
	uint16_t dh_reclen;		/* length of this record */
	uint8_t  dh_type; 		/* file type, see below */
	uint8_t  dh_namlen;		/* length of string in d_name */
} __aligned(4) __packed;
__CTASSERT(sizeof(struct lfs_dirheader64) == 12);

union lfs_dirheader {
	struct lfs_dirheader64 u_64;
	struct lfs_dirheader32 u_32;
};
__CTASSERT(__alignof(union lfs_dirheader) == __alignof(struct lfs_dirheader64));
#ifndef __lint__
__CTASSERT(__alignof(union lfs_dirheader) == __alignof(struct lfs_dirheader32));
#endif

typedef union lfs_dirheader LFS_DIRHEADER;

/*
 * Template for manipulating directories.
 */

struct lfs_dirtemplate32 {
	struct lfs_dirheader32	dot_header;
	char			dot_name[4];	/* must be multiple of 4 */
	struct lfs_dirheader32	dotdot_header;
	char			dotdot_name[4];	/* ditto */
};
__CTASSERT(sizeof(struct lfs_dirtemplate32) == 2*(8 + 4));

struct lfs_dirtemplate64 {
	struct lfs_dirheader64	dot_header;
	char			dot_name[4];	/* must be multiple of 4 */
	struct lfs_dirheader64	dotdot_header;
	char			dotdot_name[4];	/* ditto */
};
__CTASSERT(sizeof(struct lfs_dirtemplate64) == 2*(12 + 4));

union lfs_dirtemplate {
	struct lfs_dirtemplate64 u_64;
	struct lfs_dirtemplate32 u_32;
};

#if 0
/*
 * This is the old format of directories, sans type element.
 */
struct lfs_odirtemplate {
	uint32_t	dot_ino;
	int16_t		dot_reclen;
	uint16_t	dot_namlen;
	char		dot_name[4];	/* must be multiple of 4 */
	uint32_t	dotdot_ino;
	int16_t		dotdot_reclen;
	uint16_t	dotdot_namlen;
	char		dotdot_name[4];	/* ditto */
};
__CTASSERT(sizeof(struct lfs_odirtemplate) == 2*(8 + 4));
#endif

/*
 * Inodes
 */

/*
 * A dinode contains all the meta-data associated with a LFS file.
 * This structure defines the on-disk format of a dinode. Since
 * this structure describes an on-disk structure, all its fields
 * are defined by types with precise widths.
 */

struct lfs32_dinode {
	uint16_t	di_mode;	/*   0: IFMT, permissions; see below. */
	int16_t		di_nlink;	/*   2: File link count. */
	uint32_t	di_inumber;	/*   4: Inode number. */
	uint64_t	di_size;	/*   8: File byte count. */
	int32_t		di_atime;	/*  16: Last access time. */
	int32_t		di_atimensec;	/*  20: Last access time. */
	int32_t		di_mtime;	/*  24: Last modified time. */
	int32_t		di_mtimensec;	/*  28: Last modified time. */
	int32_t		di_ctime;	/*  32: Last inode change time. */
	int32_t		di_ctimensec;	/*  36: Last inode change time. */
	int32_t		di_db[ULFS_NDADDR]; /*  40: Direct disk blocks. */
	int32_t		di_ib[ULFS_NIADDR]; /*  88: Indirect disk blocks. */
	uint32_t	di_flags;	/* 100: Status flags (chflags). */
	uint32_t	di_blocks;	/* 104: Blocks actually held. */
	int32_t		di_gen;		/* 108: Generation number. */
	uint32_t	di_uid;		/* 112: File owner. */
	uint32_t	di_gid;		/* 116: File group. */
	uint64_t	di_modrev;	/* 120: i_modrev for NFSv4 */
};
__CTASSERT(sizeof(struct lfs32_dinode) == 128);

struct lfs64_dinode {
	uint16_t	di_mode;	/*   0: IFMT, permissions; see below. */
	int16_t		di_nlink;	/*   2: File link count. */
	uint32_t	di_uid;		/*   4: File owner. */
	uint32_t	di_gid;		/*   8: File group. */
	uint32_t	di_blksize;	/*  12: Inode blocksize. */
	uint64_t	di_size;	/*  16: File byte count. */
	uint64_t	di_blocks;	/*  24: Bytes actually held. */
	int64_t		di_atime;	/*  32: Last access time. */
	int64_t		di_mtime;	/*  40: Last modified time. */
	int64_t		di_ctime;	/*  48: Last inode change time. */
	int64_t		di_birthtime;	/*  56: Inode creation time. */
	int32_t		di_mtimensec;	/*  64: Last modified time. */
	int32_t		di_atimensec;	/*  68: Last access time. */
	int32_t		di_ctimensec;	/*  72: Last inode change time. */
	int32_t		di_birthnsec;	/*  76: Inode creation time. */
	int32_t		di_gen;		/*  80: Generation number. */
	uint32_t	di_kernflags;	/*  84: Kernel flags. */
	uint32_t	di_flags;	/*  88: Status flags (chflags). */
	int32_t		di_extsize;	/*  92: External attributes block. */
	int64_t		di_extb[ULFS_NXADDR];/* 96: External attributes block. */
	int64_t		di_db[ULFS_NDADDR]; /* 112: Direct disk blocks. */
	int64_t		di_ib[ULFS_NIADDR]; /* 208: Indirect disk blocks. */
	uint64_t	di_modrev;	/* 232: i_modrev for NFSv4 */
	uint64_t	di_inumber;	/* 240: Inode number */
	uint64_t	di_spare[1];	/* 248: Reserved; currently unused */
};
__CTASSERT(sizeof(struct lfs64_dinode) == 256);

union lfs_dinode {
	struct lfs64_dinode u_64;
	struct lfs32_dinode u_32;
};
__CTASSERT(__alignof(union lfs_dinode) == __alignof(struct lfs64_dinode));
__CTASSERT(__alignof(union lfs_dinode) == __alignof(struct lfs32_dinode));

/*
 * The di_db fields may be overlaid with other information for
 * file types that do not have associated disk storage. Block
 * and character devices overlay the first data block with their
 * dev_t value. Short symbolic links place their path in the
 * di_db area.
 */
#define	di_rdev		di_db[0]

/* Size of the on-disk inode. */
//#define	LFS_DINODE1_SIZE	(sizeof(struct ulfs1_dinode))	/* 128 */
//#define	LFS_DINODE2_SIZE	(sizeof(struct ulfs2_dinode))

/* File types, found in the upper bits of di_mode. */
#define	LFS_IFMT	0170000		/* Mask of file type. */
#define	LFS_IFIFO	0010000		/* Named pipe (fifo). */
#define	LFS_IFCHR	0020000		/* Character device. */
#define	LFS_IFDIR	0040000		/* Directory file. */
#define	LFS_IFBLK	0060000		/* Block device. */
#define	LFS_IFREG	0100000		/* Regular file. */
#define	LFS_IFLNK	0120000		/* Symbolic link. */
#define	LFS_IFSOCK	0140000		/* UNIX domain socket. */
#define	LFS_IFWHT	0160000		/* Whiteout. */

/*
 * "struct buf" associated definitions
 */

/* Unassigned disk addresses. */
#define	UNASSIGNED	-1
#define UNWRITTEN	-2

/* Unused logical block number */
#define LFS_UNUSED_LBN	-1

/*
 * On-disk and in-memory checkpoint segment usage structure.
 */
typedef struct segusage SEGUSE;
struct segusage {
	uint32_t su_nbytes;		/* 0: number of live bytes */
	uint32_t su_olastmod;		/* 4: SEGUSE last modified timestamp */
	uint16_t su_nsums;		/* 8: number of summaries in segment */
	uint16_t su_ninos;		/* 10: number of inode blocks in seg */

#define	SEGUSE_ACTIVE		0x01	/*  segment currently being written */
#define	SEGUSE_DIRTY		0x02	/*  segment has data in it */
#define	SEGUSE_SUPERBLOCK	0x04	/*  segment contains a superblock */
#define SEGUSE_ERROR		0x08	/*  cleaner: do not clean segment */
#define SEGUSE_EMPTY		0x10	/*  segment is empty */
#define SEGUSE_INVAL		0x20	/*  segment is invalid */
	uint32_t su_flags;		/* 12: segment flags */
	uint64_t su_lastmod;		/* 16: last modified timestamp */
};
__CTASSERT(sizeof(struct segusage) == 24);

typedef struct segusage_v1 SEGUSE_V1;
struct segusage_v1 {
	uint32_t su_nbytes;		/* 0: number of live bytes */
	uint32_t su_lastmod;		/* 4: SEGUSE last modified timestamp */
	uint16_t su_nsums;		/* 8: number of summaries in segment */
	uint16_t su_ninos;		/* 10: number of inode blocks in seg */
	uint32_t su_flags;		/* 12: segment flags  */
};
__CTASSERT(sizeof(struct segusage_v1) == 16);

/*
 * On-disk file information.  One per file with data blocks in the segment.
 *
 * The FINFO structure is a header; it is followed by fi_nblocks block
 * pointers, which are logical block numbers of the file. (These are the
 * blocks of the file present in this segment.)
 */

typedef struct finfo64 FINFO64;
struct finfo64 {
	uint32_t fi_nblocks;		/* number of blocks */
	uint32_t fi_version;		/* version number */
	uint64_t fi_ino;		/* inode number */
	uint32_t fi_lastlength;		/* length of last block in array */
	uint32_t fi_pad;		/* unused */
} __aligned(4) __packed;
__CTASSERT(sizeof(struct finfo64) == 24);

typedef struct finfo32 FINFO32;
struct finfo32 {
	uint32_t fi_nblocks;		/* number of blocks */
	uint32_t fi_version;		/* version number */
	uint32_t fi_ino;		/* inode number */
	uint32_t fi_lastlength;		/* length of last block in array */
};
__CTASSERT(sizeof(struct finfo32) == 16);

typedef union finfo {
	struct finfo64 u_64;
	struct finfo32 u_32;
} FINFO;
__CTASSERT(__alignof(union finfo) == __alignof(struct finfo64));
#ifndef __lint__
__CTASSERT(__alignof(union finfo) == __alignof(struct finfo32));
#endif

/*
 * inode info (part of the segment summary)
 *
 * Each one of these is just a block number; wrapping the structure
 * around it gives more contextual information in the code about
 * what's going on.
 */

typedef struct iinfo64 {
	uint64_t ii_block;		/* block number */
} __aligned(4) __packed IINFO64;
__CTASSERT(sizeof(struct iinfo64) == 8);

typedef struct iinfo32 {
	uint32_t ii_block;		/* block number */
} IINFO32;
__CTASSERT(sizeof(struct iinfo32) == 4);

typedef union iinfo {
	struct iinfo64 u_64;
	struct iinfo32 u_32;
} IINFO;
__CTASSERT(__alignof(union iinfo) == __alignof(struct iinfo64));
#ifndef __lint__
__CTASSERT(__alignof(union iinfo) == __alignof(struct iinfo32));
#endif

/*
 * Index file inode entries.
 */

/* magic value for daddrs */
#define	LFS_UNUSED_DADDR	0	/* out-of-band daddr */
/* magic value for if_nextfree -- indicate orphaned file */
#define LFS_ORPHAN_NEXTFREE(fs) \
	((fs)->lfs_is64 ? ~(uint64_t)0 : ~(uint32_t)0)

typedef struct ifile64 IFILE64;
struct ifile64 {
	uint32_t if_version;		/* inode version number */
	uint32_t if_atime_nsec;		/* and nanoseconds */
	uint64_t if_atime_sec;		/* Last access time, seconds */
	int64_t	  if_daddr;		/* inode disk address */
	uint64_t if_nextfree;		/* next-unallocated inode */
} __aligned(4) __packed;
__CTASSERT(sizeof(struct ifile64) == 32);

typedef struct ifile32 IFILE32;
struct ifile32 {
	uint32_t if_version;		/* inode version number */
	int32_t	  if_daddr;		/* inode disk address */
	uint32_t if_nextfree;		/* next-unallocated inode */
	uint32_t if_atime_sec;		/* Last access time, seconds */
	uint32_t if_atime_nsec;		/* and nanoseconds */
};
__CTASSERT(sizeof(struct ifile32) == 20);

typedef struct ifile_v1 IFILE_V1;
struct ifile_v1 {
	uint32_t if_version;		/* inode version number */
	int32_t	  if_daddr;		/* inode disk address */
	uint32_t if_nextfree;		/* next-unallocated inode */
#if LFS_ATIME_IFILE
#error "this cannot work"
	struct timespec if_atime;	/* Last access time */
#endif
};
__CTASSERT(sizeof(struct ifile_v1) == 12);

/*
 * Note: struct ifile_v1 is often handled by accessing the first three
 * fields of struct ifile32. (XXX: Blah.  This should be cleaned up as
 * it may in some cases violate the strict-aliasing rules.)
 */
typedef union ifile {
	struct ifile64 u_64;
	struct ifile32 u_32;
	struct ifile_v1 u_v1;
} IFILE;
__CTASSERT(__alignof(union ifile) == __alignof(struct ifile64));
#ifndef __lint__
__CTASSERT(__alignof(union ifile) == __alignof(struct ifile32));
__CTASSERT(__alignof(union ifile) == __alignof(struct ifile_v1));
#endif

/*
 * Cleaner information structure.  This resides in the ifile and is used
 * to pass information from the kernel to the cleaner.
 */

/* flags for ->flags */
#define LFS_CLEANER_MUST_CLEAN	0x01

typedef struct _cleanerinfo32 {
	uint32_t clean;			/* 0: number of clean segments */
	uint32_t dirty;			/* 4: number of dirty segments */
	int32_t   bfree;		/* 8: disk blocks free */
	int32_t	  avail;		/* 12: disk blocks available */
	uint32_t free_head;		/* 16: head of the inode free list */
	uint32_t free_tail;		/* 20: tail of the inode free list */
	uint32_t flags;			/* 24: status word from the kernel */
} CLEANERINFO32;
__CTASSERT(sizeof(struct _cleanerinfo32) == 28);

typedef struct _cleanerinfo64 {
	uint32_t clean;			/* 0: number of clean segments */
	uint32_t dirty;			/* 4: number of dirty segments */
	int64_t   bfree;		/* 8: disk blocks free */
	int64_t	  avail;		/* 16: disk blocks available */
	uint64_t free_head;		/* 24: head of the inode free list */
	uint64_t free_tail;		/* 32: tail of the inode free list */
	uint32_t flags;			/* 40: status word from the kernel */
	uint32_t pad;			/* 44: must be 64-bit aligned */
} __aligned(4) __packed CLEANERINFO64;
__CTASSERT(sizeof(struct _cleanerinfo64) == 48);

/* this must not go to disk directly of course */
typedef union _cleanerinfo {
	CLEANERINFO32 u_32;
	CLEANERINFO64 u_64;
} CLEANERINFO;
#ifndef __lint__
__CTASSERT(__alignof(union _cleanerinfo) == __alignof(struct _cleanerinfo32));
__CTASSERT(__alignof(union _cleanerinfo) == __alignof(struct _cleanerinfo64));
#endif

/*
 * On-disk segment summary information
 */

/* magic value for ss_magic */
#define SS_MAGIC	0x061561

/* flags for ss_flags */
#define	SS_DIROP	0x01		/* segment begins a dirop */
#define	SS_CONT		0x02		/* more partials to finish this write*/
#define	SS_CLEAN	0x04		/* written by the cleaner */
#define	SS_RFW		0x08		/* written by the roll-forward agent */
#define	SS_RECLAIM	0x10		/* written by the roll-forward agent */

/* type used for reading checksum signatures from metadata structures */
typedef uint32_t lfs_checkword;

typedef struct segsum_v1 SEGSUM_V1;
struct segsum_v1 {
	uint32_t ss_sumsum;		/* 0: check sum of summary block */
	uint32_t ss_datasum;		/* 4: check sum of data */
	uint32_t ss_magic;		/* 8: segment summary magic number */
	int32_t	  ss_next;		/* 12: next segment */
	uint32_t ss_create;		/* 16: creation time stamp */
	uint16_t ss_nfinfo;		/* 20: number of file info structures */
	uint16_t ss_ninos;		/* 22: number of inodes in summary */
	uint16_t ss_flags;		/* 24: used for directory operations */
	uint16_t ss_pad;		/* 26: extra space */
	/* FINFO's and inode daddr's... */
};
__CTASSERT(sizeof(struct segsum_v1) == 28);

typedef struct segsum32 SEGSUM32;
struct segsum32 {
	uint32_t ss_sumsum;		/* 0: check sum of summary block */
	uint32_t ss_datasum;		/* 4: check sum of data */
	uint32_t ss_magic;		/* 8: segment summary magic number */
	int32_t	  ss_next;		/* 12: next segment (disk address) */
	uint32_t ss_ident;		/* 16: roll-forward fsid */
	uint16_t ss_nfinfo;		/* 20: number of file info structures */
	uint16_t ss_ninos;		/* 22: number of inodes in summary */
	uint16_t ss_flags;		/* 24: used for directory operations */
	uint8_t  ss_pad[2];		/* 26: extra space */
	uint32_t ss_reclino;		/* 28: inode being reclaimed */
	uint64_t ss_serial;		/* 32: serial number */
	uint64_t ss_create;		/* 40: time stamp */
	/* FINFO's and inode daddr's... */
} __aligned(4) __packed;
__CTASSERT(sizeof(struct segsum32) == 48);

typedef struct segsum64 SEGSUM64;
struct segsum64 {
	uint32_t ss_sumsum;		/* 0: check sum of summary block */
	uint32_t ss_datasum;		/* 4: check sum of data */
	uint32_t ss_magic;		/* 8: segment summary magic number */
	uint32_t ss_ident;		/* 12: roll-forward fsid */
	int64_t	  ss_next;		/* 16: next segment (disk address) */
	uint16_t ss_nfinfo;		/* 24: number of file info structures */
	uint16_t ss_ninos;		/* 26: number of inodes in summary */
	uint16_t ss_flags;		/* 28: used for directory operations */
	uint8_t  ss_pad[2];		/* 30: extra space */
	uint64_t ss_reclino;		/* 32: inode being reclaimed */
	uint64_t ss_serial;		/* 40: serial number */
	uint64_t ss_create;		/* 48: time stamp */
	/* FINFO's and inode daddr's... */
} __aligned(4) __packed;
__CTASSERT(sizeof(struct segsum64) == 56);

typedef union segsum SEGSUM;
union segsum {
	struct segsum64 u_64;
	struct segsum32 u_32;
	struct segsum_v1 u_v1;
};
__CTASSERT(__alignof(union segsum) == __alignof(struct segsum64));
__CTASSERT(__alignof(union segsum) == __alignof(struct segsum32));
#ifndef __lint__
__CTASSERT(__alignof(union segsum) == __alignof(struct segsum_v1));
#endif

/*
 * On-disk super block.
 *
 * We have separate superblock structures for the 32-bit and 64-bit
 * LFS, and accessor functions to hide the differences.
 *
 * For lfs64, the format version is always 2; version 1 lfs is old.
 * For both, the inode format version is 0; for lfs32 this selects the
 * same 32-bit inode as always, and for lfs64 this selects the larger
 * 64-bit inode structure we got from ffsv2.
 *
 * In lfs64:
 *   - inode numbers are 64 bit now
 *   - segments may not be larger than 4G (counted in bytes)
 *   - there may not be more than 2^32 (or perhaps 2^31) segments
 *   - the total volume size is limited to 2^63 frags and/or 2^63
 *     disk blocks, and probably in practice 2^63 bytes.
 */

#define	       LFS_MAGIC       		0x070162
#define        LFS_MAGIC_SWAPPED	0x62010700

#define        LFS64_MAGIC     		(0x19620701 ^ 0xffffffff)
#define        LFS64_MAGIC_SWAPPED      (0x01076219 ^ 0xffffffff)

#define	       LFS_VERSION     		2

#define LFS_MIN_SBINTERVAL     5	/* min superblock segment spacing */
#define LFS_MAXNUMSB	       10	/* max number of superblocks */

/* flags for dlfs_pflags */
#define LFS_PF_CLEAN 0x1

/* Inode format versions */
#define LFS_44INODEFMT 0
#define LFS_MAXINODEFMT 0

struct dlfs {
	uint32_t dlfs_magic;	  /* 0: magic number */
	uint32_t dlfs_version;	  /* 4: version number */

	uint32_t dlfs_size;	  /* 8: number of blocks in fs (v1) */
				  /*	number of frags in fs (v2) */
	uint32_t dlfs_ssize;	  /* 12: number of blocks per segment (v1) */
				  /*	 number of bytes per segment (v2) */
	uint32_t dlfs_dsize;	  /* 16: number of disk blocks in fs */
	uint32_t dlfs_bsize;	  /* 20: file system block size */
	uint32_t dlfs_fsize;	  /* 24: size of frag blocks in fs */
	uint32_t dlfs_frag;	  /* 28: number of frags in a block in fs */

/* Checkpoint region. */
	uint32_t dlfs_freehd;	  /* 32: start of the free inode list */
	int32_t   dlfs_bfree;	  /* 36: number of free frags */
	uint32_t dlfs_nfiles;	  /* 40: number of allocated inodes */
	int32_t	  dlfs_avail;	  /* 44: blocks available for writing */
	int32_t	  dlfs_uinodes;	  /* 48: inodes in cache not yet on disk */
	int32_t	  dlfs_idaddr;	  /* 52: inode file disk address */
	uint32_t dlfs_ifile;	  /* 56: inode file inode number */
	int32_t	  dlfs_lastseg;	  /* 60: address of last segment written */
	int32_t	  dlfs_nextseg;	  /* 64: address of next segment to write */
	int32_t	  dlfs_curseg;	  /* 68: current segment being written */
	int32_t	  dlfs_offset;	  /* 72: offset in curseg for next partial */
	int32_t	  dlfs_lastpseg;  /* 76: address of last partial written */
	uint32_t dlfs_inopf;	  /* 80: v1: time stamp; v2: inodes per frag */

/* These are configuration parameters. */
	uint32_t dlfs_minfree;	  /* 84: minimum percentage of free blocks */

/* These fields can be computed from the others. */
	uint64_t dlfs_maxfilesize; /* 88: maximum representable file size */
	uint32_t dlfs_fsbpseg;	  /* 96: frags (fsb) per segment */
	uint32_t dlfs_inopb;	  /* 100: inodes per block */
	uint32_t dlfs_ifpb;	  /* 104: IFILE entries per block */
	uint32_t dlfs_sepb;	  /* 108: SEGUSE entries per block */
	uint32_t dlfs_nindir;	  /* 112: indirect pointers per block */
	uint32_t dlfs_nseg;	  /* 116: number of segments */
	uint32_t dlfs_nspf;	  /* 120: number of sectors per fragment */
	uint32_t dlfs_cleansz;	  /* 124: cleaner info size in blocks */
	uint32_t dlfs_segtabsz;	  /* 128: segment table size in blocks */
	uint32_t dlfs_segmask;	  /* 132: calculate offset within a segment */
	uint32_t dlfs_segshift;	  /* 136: fast mult/div for segments */
	uint32_t dlfs_bshift;	  /* 140: calc block number from file offset */
	uint32_t dlfs_ffshift;	  /* 144: fast mult/div for frag from file */
	uint32_t dlfs_fbshift;	  /* 148: fast mult/div for frag from block */
	uint64_t dlfs_bmask;	  /* 152: calc block offset from file offset */
	uint64_t dlfs_ffmask;	  /* 160: calc frag offset from file offset */
	uint64_t dlfs_fbmask;	  /* 168: calc frag offset from block offset */
	uint32_t dlfs_blktodb;	  /* 176: blktodb and dbtoblk shift constant */
	uint32_t dlfs_sushift;	  /* 180: fast mult/div for segusage table */

	int32_t	  dlfs_maxsymlinklen; /* 184: max length of an internal symlink */
				  /* 188: superblock disk offsets */
	int32_t	  dlfs_sboffs[LFS_MAXNUMSB];

	uint32_t dlfs_nclean;	  /* 228: Number of clean segments */
	u_char	  dlfs_fsmnt[MNAMELEN];	 /* 232: name mounted on */
	uint16_t dlfs_pflags;	  /* 322: file system persistent flags */
	int32_t	  dlfs_dmeta;	  /* 324: total number of dirty summaries */
	uint32_t dlfs_minfreeseg; /* 328: segments not counted in bfree */
	uint32_t dlfs_sumsize;	  /* 332: size of summary blocks */
	uint64_t dlfs_serial;	  /* 336: serial number */
	uint32_t dlfs_ibsize;	  /* 344: size of inode blocks */
	int32_t	  dlfs_s0addr;	  /* 348: start of segment 0 */
	uint64_t dlfs_tstamp;	  /* 352: time stamp */
	uint32_t dlfs_inodefmt;	  /* 360: inode format version */
	uint32_t dlfs_interleave; /* 364: segment interleave */
	uint32_t dlfs_ident;	  /* 368: per-fs identifier */
	uint32_t dlfs_fsbtodb;	  /* 372: fsbtodb and dbtodsb shift constant */
	uint32_t dlfs_resvseg;	  /* 376: segments reserved for the cleaner */
	int8_t	  dlfs_pad[128];  /* 380: round to 512 bytes */
/* Checksum -- last valid disk field. */
	uint32_t dlfs_cksum;	  /* 508: checksum for superblock checking */
};

struct dlfs64 {
	uint32_t dlfs_magic;	  /* 0: magic number */
	uint32_t dlfs_version;	  /* 4: version number (2) */

	uint64_t dlfs_size;	  /* 8: number of frags in fs (v2) */
	uint64_t dlfs_dsize;	  /* 16: number of disk blocks in fs */
	uint32_t dlfs_ssize;	  /* 24: number of bytes per segment (v2) */
	uint32_t dlfs_bsize;	  /* 28: file system block size */
	uint32_t dlfs_fsize;	  /* 32: size of frag blocks in fs */
	uint32_t dlfs_frag;	  /* 36: number of frags in a block in fs */

/* Checkpoint region. */
	uint64_t dlfs_freehd;	  /* 40: start of the free inode list */
	uint64_t dlfs_nfiles;	  /* 48: number of allocated inodes */
	int64_t   dlfs_bfree;	  /* 56: number of free frags */
	int64_t	  dlfs_avail;	  /* 64: blocks available for writing */
	int64_t	  dlfs_idaddr;	  /* 72: inode file disk address */
	int32_t	  dlfs_uinodes;	  /* 80: inodes in cache not yet on disk */
	uint32_t dlfs_unused_0;	  /* 84: not used */
	int64_t	  dlfs_lastseg;	  /* 88: address of last segment written */
	int64_t	  dlfs_nextseg;	  /* 96: address of next segment to write */
	int64_t	  dlfs_curseg;	  /* 104: current segment being written */
	int64_t	  dlfs_offset;	  /* 112: offset in curseg for next partial */
	int64_t	  dlfs_lastpseg;  /* 120: address of last partial written */
	uint32_t dlfs_inopf;	  /* 128: inodes per frag */

/* These are configuration parameters. */
	uint32_t dlfs_minfree;	  /* 132: minimum percentage of free blocks */

/* These fields can be computed from the others. */
	uint64_t dlfs_maxfilesize; /* 136: maximum representable file size */
	uint32_t dlfs_fsbpseg;	  /* 144: frags (fsb) per segment */
	uint32_t dlfs_inopb;	  /* 148: inodes per block */
	uint32_t dlfs_ifpb;	  /* 152: IFILE entries per block */
	uint32_t dlfs_sepb;	  /* 156: SEGUSE entries per block */
	uint32_t dlfs_nindir;	  /* 160: indirect pointers per block */
	uint32_t dlfs_nseg;	  /* 164: number of segments */
	uint32_t dlfs_nspf;	  /* 168: number of sectors per fragment */
	uint32_t dlfs_cleansz;	  /* 172: cleaner info size in blocks */
	uint32_t dlfs_segtabsz;	  /* 176: segment table size in blocks */
	uint32_t dlfs_bshift;	  /* 180: calc block number from file offset */
	uint32_t dlfs_ffshift;	  /* 184: fast mult/div for frag from file */
	uint32_t dlfs_fbshift;	  /* 188: fast mult/div for frag from block */
	uint64_t dlfs_bmask;	  /* 192: calc block offset from file offset */
	uint64_t dlfs_ffmask;	  /* 200: calc frag offset from file offset */
	uint64_t dlfs_fbmask;	  /* 208: calc frag offset from block offset */
	uint32_t dlfs_blktodb;	  /* 216: blktodb and dbtoblk shift constant */
	uint32_t dlfs_sushift;	  /* 220: fast mult/div for segusage table */

				  /* 224: superblock disk offsets */
	int64_t	   dlfs_sboffs[LFS_MAXNUMSB];

	int32_t	  dlfs_maxsymlinklen; /* 304: max len of an internal symlink */
	uint32_t dlfs_nclean;	  /* 308: Number of clean segments */
	u_char	  dlfs_fsmnt[MNAMELEN];	 /* 312: name mounted on */
	uint16_t dlfs_pflags;	  /* 402: file system persistent flags */
	int32_t	  dlfs_dmeta;	  /* 404: total number of dirty summaries */
	uint32_t dlfs_minfreeseg; /* 408: segments not counted in bfree */
	uint32_t dlfs_sumsize;	  /* 412: size of summary blocks */
	uint32_t dlfs_ibsize;	  /* 416: size of inode blocks */
	uint32_t dlfs_inodefmt;	  /* 420: inode format version */
	uint64_t dlfs_serial;	  /* 424: serial number */
	int64_t	  dlfs_s0addr;	  /* 432: start of segment 0 */
	uint64_t dlfs_tstamp;	  /* 440: time stamp */
	uint32_t dlfs_interleave; /* 448: segment interleave */
	uint32_t dlfs_ident;	  /* 452: per-fs identifier */
	uint32_t dlfs_fsbtodb;	  /* 456: fsbtodb and dbtodsb shift constant */
	uint32_t dlfs_resvseg;	  /* 460: segments reserved for the cleaner */
	int8_t	  dlfs_pad[44];   /* 464: round to 512 bytes */
/* Checksum -- last valid disk field. */
	uint32_t dlfs_cksum;	  /* 508: checksum for superblock checking */
};

__CTASSERT(__alignof(struct dlfs) == __alignof(struct dlfs64));

/* Type used for the inode bitmap */
typedef uint32_t lfs_bm_t;

/*
 * Linked list of segments whose byte count needs updating following a
 * file truncation.
 */
struct segdelta {
	long segnum;
	size_t num;
	LIST_ENTRY(segdelta) list;
};

/*
 * In-memory super block.
 */
struct lfs {
	union {				/* on-disk parameters */
		struct dlfs u_32;
		struct dlfs64 u_64;
	} lfs_dlfs_u;

/* These fields are set at mount time and are meaningless on disk. */
	unsigned lfs_is64 : 1,		/* are we lfs64 or lfs32? */
		lfs_dobyteswap : 1,	/* are we opposite-endian? */
		lfs_hasolddirfmt : 1;	/* dir entries have no d_type */

	struct segment *lfs_sp;		/* current segment being written */
	struct vnode *lfs_ivnode;	/* vnode for the ifile */
	uint32_t  lfs_seglock;		/* single-thread the segment writer */
	pid_t	  lfs_lockpid;		/* pid of lock holder */
	lwpid_t	  lfs_locklwp;		/* lwp of lock holder */
	uint32_t lfs_iocount;		/* number of ios pending */
	uint32_t lfs_writer;		/* don't allow any dirops to start */
	uint32_t lfs_dirops;		/* count of active directory ops */
	kcondvar_t lfs_diropscv;	/* condvar of active directory ops */
	uint32_t lfs_dirvcount;		/* count of VDIROP nodes in this fs */
	uint32_t lfs_doifile;		/* Write ifile blocks on next write */
	uint32_t lfs_nactive;		/* Number of segments since last ckp */
	int8_t	  lfs_fmod;		/* super block modified flag */
	int8_t	  lfs_ronly;		/* mounted read-only flag */
#define LFS_NOTYET  0x01
#define LFS_IFDIRTY 0x02
#define LFS_WARNED  0x04
#define LFS_UNDIROP 0x08
	int8_t	  lfs_flags;		/* currently unused flag */
	uint16_t lfs_activesb;		/* toggle between superblocks */
	daddr_t	  lfs_sbactive;		/* disk address of current sb write */
	struct vnode *lfs_flushvp;	/* vnode being flushed */
	int lfs_flushvp_fakevref;	/* fake vref count for flushvp */
	struct vnode *lfs_unlockvp;	/* being inactivated in lfs_segunlock */
	uint32_t lfs_diropwait;		/* # procs waiting on dirop flush */
	size_t lfs_devbsize;		/* Device block size */
	size_t lfs_devbshift;		/* Device block shift */
	krwlock_t lfs_fraglock;
	krwlock_t lfs_iflock;		/* Ifile lock */
	kcondvar_t lfs_stopcv;		/* Wrap lock */
	struct lwp *lfs_stoplwp;
	pid_t lfs_rfpid;		/* Process ID of roll-forward agent */
	int	  lfs_nadirop;		/* number of active dirop nodes */
	long	  lfs_ravail;		/* blocks pre-reserved for writing */
	long	  lfs_favail;		/* blocks pre-reserved for writing */
	struct lfs_res_blk *lfs_resblk;	/* Reserved memory for pageout */
	TAILQ_HEAD(, inode) lfs_dchainhd; /* dirop vnodes */
	TAILQ_HEAD(, inode) lfs_pchainhd; /* paging vnodes */
#define LFS_RESHASH_WIDTH 17
	LIST_HEAD(, lfs_res_blk) lfs_reshash[LFS_RESHASH_WIDTH];
	int	  lfs_pdflush;		/* pagedaemon wants us to flush */
	uint32_t **lfs_suflags;		/* Segment use flags */
#ifdef _KERNEL
	struct pool lfs_clpool;		/* Pool for struct lfs_cluster */
	struct pool lfs_bpppool;	/* Pool for bpp */
	struct pool lfs_segpool;	/* Pool for struct segment */
#endif /* _KERNEL */
#define LFS_MAX_CLEANIND 64
	daddr_t  lfs_cleanint[LFS_MAX_CLEANIND]; /* Active cleaning intervals */
	int 	 lfs_cleanind;		/* Index into intervals */
	int lfs_sleepers;		/* # procs sleeping this fs */
	kcondvar_t lfs_sleeperscv;	
	int lfs_pages;			/* dirty pages blaming this fs */
	lfs_bm_t *lfs_ino_bitmap;	/* Inuse inodes bitmap */
	int lfs_nowrap;			/* Suspend log wrap */
	int lfs_wrappass;		/* Allow first log wrap requester to pass */
	int lfs_wrapstatus;		/* Wrap status */
	int lfs_reclino;		/* Inode being reclaimed */
	daddr_t lfs_startseg;           /* Segment we started writing at */
	LIST_HEAD(, segdelta) lfs_segdhd;	/* List of pending trunc accounting events */

#ifdef _KERNEL
	/* The block device we're mounted on. */
	dev_t lfs_dev;
	struct vnode *lfs_devvp;

	/* ULFS-level information */
	uint32_t um_flags;			/* ULFS flags (below) */
	u_long	um_nindir;			/* indirect ptrs per block */
	u_long	um_lognindir;			/* log2 of um_nindir */
	u_long	um_bptrtodb;			/* indir ptr to disk block */
	u_long	um_seqinc;			/* inc between seq blocks */
	int um_maxsymlinklen;
	int um_dirblksiz;
	uint64_t um_maxfilesize;

	/* Stuff used by quota2 code, not currently operable */
	unsigned lfs_use_quota2 : 1;
	uint32_t lfs_quota_magic;
	uint8_t lfs_quota_flags;
	uint64_t lfs_quotaino[2];

	/* Sleep address replacing &lfs_avail inside the on-disk superblock */
	/* XXX: should be replaced with a condvar */
	int lfs_availsleep;
	/* This one replaces &lfs_nextseg... all ditto */
	kcondvar_t lfs_nextsegsleep;

	/* Cleaner lwp, set on first bmapv syscall. */
	struct lwp *lfs_cleaner_thread;

	/* Hint from cleaner, only valid if curlwp == um_cleaner_thread. */
	/* XXX change this to BLOCK_INFO after resorting this file */
	struct block_info *lfs_cleaner_hint;
#endif
};

/*
 * Structures used by lfs_bmapv and lfs_markv to communicate information
 * about inodes and data blocks.
 */
typedef struct block_info {
	uint64_t bi_inode;		/* inode # */
	int64_t	bi_lbn;			/* logical block w/in file */
	int64_t	bi_daddr;		/* disk address of block */
	uint64_t bi_segcreate;		/* origin segment create time */
	int	bi_version;		/* file version number */
	int	bi_size;		/* size of the block (if fragment) */
	void	*bi_bp;			/* data buffer */
} BLOCK_INFO;

/* Compatibility for 7.0 binaries */
typedef struct block_info_70 {
	uint32_t bi_inode;		/* inode # */
	int32_t	bi_lbn;			/* logical block w/in file */
	int32_t	bi_daddr;		/* disk address of block */
	uint64_t bi_segcreate;		/* origin segment create time */
	int	bi_version;		/* file version number */
	void	*bi_bp;			/* data buffer */
	int	bi_size;		/* size of the block (if fragment) */
} BLOCK_INFO_70;

/* Compatibility for 1.5 binaries */
typedef struct block_info_15 {
	uint32_t bi_inode;		/* inode # */
	int32_t	bi_lbn;			/* logical block w/in file */
	int32_t	bi_daddr;		/* disk address of block */
	uint32_t bi_segcreate;		/* origin segment create time */
	int	bi_version;		/* file version number */
	void	*bi_bp;			/* data buffer */
	int	bi_size;		/* size of the block (if fragment) */
} BLOCK_INFO_15;

/*
 * 32/64-bit-clean pointer to block pointers. This points into
 * already-existing storage; it is mostly used to access the block
 * pointers following a FINFO.
 */
union lfs_blocks {
	int64_t *b64;
	int32_t *b32;
};

/* In-memory description of a segment about to be written. */
struct segment {
	struct lfs	 *fs;		/* file system pointer */
	struct buf	**bpp;		/* pointer to buffer array */
	struct buf	**cbpp;		/* pointer to next available bp */
	struct buf	**start_bpp;	/* pointer to first bp in this set */
	struct buf	 *ibp;		/* buffer pointer to inode page */
	union lfs_dinode *idp;          /* pointer to ifile dinode */
	FINFO *fip;			/* current fileinfo pointer */
	struct vnode	 *vp;		/* vnode being gathered */
	void	 *segsum;		/* segment summary info */
	uint32_t ninodes;		/* number of inodes in this segment */
	int32_t seg_bytes_left;		/* bytes left in segment */
	int32_t sum_bytes_left;		/* bytes left in summary block */
	uint32_t seg_number;		/* number of this segment */
	union lfs_blocks start_lbp;	/* beginning lbn for this set */

#define SEGM_CKP	0x0001		/* doing a checkpoint */
#define SEGM_CLEAN	0x0002		/* cleaner call; don't sort */
#define SEGM_SYNC	0x0004		/* wait for segment */
#define SEGM_PROT	0x0008		/* don't inactivate at segunlock */
#define SEGM_PAGEDAEMON	0x0010		/* pagedaemon called us */
#define SEGM_WRITERD	0x0020		/* LFS writed called us */
#define SEGM_FORCE_CKP	0x0040		/* Force checkpoint right away */
#define SEGM_RECLAIM	0x0080		/* Writing to reclaim vnode */
#define SEGM_SINGLE	0x0100		/* Opportunistic writevnodes */
	uint16_t seg_flags;		/* run-time flags for this segment */
	uint32_t seg_iocount;		/* number of ios pending */
	int	  ndupino;		/* number of duplicate inodes */
};

/* Statistics Counters */
struct lfs_stats {	/* Must match sysctl list in lfs_vfsops.h ! */
	u_int	segsused;
	u_int	psegwrites;
	u_int	psyncwrites;
	u_int	pcleanwrites;
	u_int	blocktot;
	u_int	cleanblocks;
	u_int	ncheckpoints;
	u_int	nwrites;
	u_int	nsync_writes;
	u_int	wait_exceeded;
	u_int	write_exceeded;
	u_int	flush_invoked;
	u_int	vflush_invoked;
	u_int	clean_inlocked;
	u_int	clean_vnlocked;
	u_int   segs_reclaimed;
};

/* Fcntls to take the place of the lfs syscalls */
struct lfs_fcntl_markv {
	BLOCK_INFO *blkiov;	/* blocks to relocate */
	int blkcnt;		/* number of blocks (limited to 65536) */
};

#define LFCNSEGWAITALL	_FCNR_FSPRIV('L', 14, struct timeval)
#define LFCNSEGWAIT	_FCNR_FSPRIV('L', 15, struct timeval)
#define LFCNBMAPV	_FCNRW_FSPRIV('L', 16, struct lfs_fcntl_markv)
#define LFCNMARKV	_FCNRW_FSPRIV('L', 17, struct lfs_fcntl_markv)
#define LFCNRECLAIM	 _FCNO_FSPRIV('L', 4)

struct lfs_fhandle {
	char space[28];	/* FHANDLE_SIZE_COMPAT (but used from userland too) */
};
#define LFCNREWIND       _FCNR_FSPRIV('L', 6, int)
#define LFCNINVAL        _FCNR_FSPRIV('L', 7, int)
#define LFCNRESIZE       _FCNR_FSPRIV('L', 8, int)
#define LFCNWRAPSTOP	 _FCNR_FSPRIV('L', 9, int)
#define LFCNWRAPGO	 _FCNR_FSPRIV('L', 10, int)
#define LFCNIFILEFH	 _FCNW_FSPRIV('L', 11, struct lfs_fhandle)
#define LFCNWRAPPASS	 _FCNR_FSPRIV('L', 12, int)
# define LFS_WRAP_GOING   0x0
# define LFS_WRAP_WAITING 0x1
#define LFCNWRAPSTATUS	 _FCNW_FSPRIV('L', 13, int)

/* Debug segment lock */
#ifdef notyet
# define ASSERT_SEGLOCK(fs) KASSERT(LFS_SEGLOCK_HELD(fs))
# define ASSERT_NO_SEGLOCK(fs) KASSERT(!LFS_SEGLOCK_HELD(fs))
# define ASSERT_DUNNO_SEGLOCK(fs)
# define ASSERT_MAYBE_SEGLOCK(fs)
#else /* !notyet */
# define ASSERT_DUNNO_SEGLOCK(fs) \
	DLOG((DLOG_SEG, "lfs func %s seglock wrong (%d)\n", __func__, \
		LFS_SEGLOCK_HELD(fs)))
# define ASSERT_SEGLOCK(fs) do {					\
	if (!LFS_SEGLOCK_HELD(fs)) {					\
		DLOG((DLOG_SEG, "lfs func %s seglock wrong (0)\n", __func__)); \
	}								\
} while(0)
# define ASSERT_NO_SEGLOCK(fs) do {					\
	if (LFS_SEGLOCK_HELD(fs)) {					\
		DLOG((DLOG_SEG, "lfs func %s seglock wrong (1)\n", __func__)); \
	}								\
} while(0)
# define ASSERT_MAYBE_SEGLOCK(x)
#endif /* !notyet */

/*
 * Arguments to mount LFS filesystems
 */
struct ulfs_args {
	char	*fspec;			/* block special device to mount */
};

__BEGIN_DECLS
void lfs_itimes(struct inode *, const struct timespec *,
    const struct timespec *, const struct timespec *);
__END_DECLS

#endif /* !_UFS_LFS_LFS_H_ */