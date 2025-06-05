/*	$NetBSD: dinode.h,v 1.25 2016/01/22 23:06:10 dholland Exp $	*/

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
 * NOTE: COORDINATE ON-DISK FORMAT CHANGES WITH THE FREEBSD PROJECT.
 */

#ifndef	_UFS_UFS_DINODE_H_
#define	_UFS_UFS_DINODE_H_

/*
 * The root inode is the root of the file system.  Inode 0 can't be used for
 * normal purposes and historically bad blocks were linked to inode 1, thus
 * the root inode is 2.  (Inode 1 is no longer used for this purpose, however
 * numerous dump tapes make this assumption, so we are stuck with it).
 */
#define	UFS_ROOTINO	((ino_t)2)

/*
 * The Whiteout inode# is a dummy non-zero inode number which will
 * never be allocated to a real file.  It is used as a place holder
 * in the directory entry which has been tagged as a DT_W entry.
 * See the comments about UFS_ROOTINO above.
 */
#define	UFS_WINO	((ino_t)1)

/*
 * A dinode contains all the meta-data associated with a UFS file.
 * This structure defines the on-disk format of a dinode. Since
 * this structure describes an on-disk structure, all its fields
 * are defined by types with precise widths.
 */

#define UFS_NXADDR	2
#define	UFS_NDADDR	12		/* Direct addresses in inode. */
#define	UFS_NIADDR	3		/* Indirect addresses in inode. */

struct ufs1_dinode {
	uint16_t	di_mode;	/*   0: IFMT, permissions; see below. */
	int16_t		di_nlink;	/*   2: File link count. */
	uint16_t	di_oldids[2];	/*   4: Ffs: old user and group ids. */
	uint64_t	di_size;	/*   8: File byte count. */
	int32_t		di_atime;	/*  16: Last access time. */
	int32_t		di_atimensec;	/*  20: Last access time. */
	int32_t		di_mtime;	/*  24: Last modified time. */
	int32_t		di_mtimensec;	/*  28: Last modified time. */
	int32_t		di_ctime;	/*  32: Last inode change time. */
	int32_t		di_ctimensec;	/*  36: Last inode change time. */
	int32_t		di_db[UFS_NDADDR]; /*  40: Direct disk blocks. */
	int32_t		di_ib[UFS_NIADDR]; /*  88: Indirect disk blocks. */
	uint32_t	di_flags;	/* 100: Status flags (chflags). */
	uint32_t	di_blocks;	/* 104: Blocks actually held. */
	int32_t		di_gen;		/* 108: Generation number. */
	uint32_t	di_uid;		/* 112: File owner. */
	uint32_t	di_gid;		/* 116: File group. */
	uint64_t	di_modrev;	/* 120: i_modrev for NFSv4 */
};

struct ufs2_dinode {
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
	int64_t		di_extb[UFS_NXADDR];/* 96: External attributes block. */
	int64_t		di_db[UFS_NDADDR]; /* 112: Direct disk blocks. */
	int64_t		di_ib[UFS_NIADDR]; /* 208: Indirect disk blocks. */
	uint64_t	di_modrev;	/* 232: i_modrev for NFSv4 */
	int64_t		di_spare[2];	/* 240: Reserved; currently unused */
};

/*
 * The di_db fields may be overlaid with other information for
 * file types that do not have associated disk storage. Block
 * and character devices overlay the first data block with their
 * dev_t value. Short symbolic links place their path in the
 * di_db area.
 */
#define	di_ogid		di_oldids[1]
#define	di_ouid		di_oldids[0]
#define	di_rdev		di_db[0]
#define UFS1_MAXSYMLINKLEN	((UFS_NDADDR + UFS_NIADDR) * sizeof(int32_t))
#define UFS2_MAXSYMLINKLEN	((UFS_NDADDR + UFS_NIADDR) * sizeof(int64_t))

#define UFS_MAXSYMLINKLEN(ip) \
	((ip)->i_ump->um_fstype == UFS1) ? \
	UFS1_MAXSYMLINKLEN : UFS2_MAXSYMLINKLEN

/* NeXT used to keep short symlinks in the inode even when using
 * FS_42INODEFMT.  In that case fs->fs_maxsymlinklen is probably -1,
 * but short symlinks were stored in inodes shorter than this:
 */
#define	APPLEUFS_MAXSYMLINKLEN 60

/* File permissions. */
#define	IEXEC		0000100		/* Executable. */
#define	IWRITE		0000200		/* Writable. */
#define	IREAD		0000400		/* Readable. */
#define	ISVTX		0001000		/* Sticky bit. */
#define	ISGID		0002000		/* Set-gid. */
#define	ISUID		0004000		/* Set-uid. */

/* File types. */
#define	IFMT		0170000		/* Mask of file type. */
#define	IFIFO		0010000		/* Named pipe (fifo). */
#define	IFCHR		0020000		/* Character device. */
#define	IFDIR		0040000		/* Directory file. */
#define	IFBLK		0060000		/* Block device. */
#define	IFREG		0100000		/* Regular file. */
#define	IFLNK		0120000		/* Symbolic link. */
#define	IFSOCK		0140000		/* UNIX domain socket. */
#define	IFWHT		0160000		/* Whiteout. */

/* Size of the on-disk inode. */
#define	DINODE1_SIZE	(sizeof(struct ufs1_dinode))		/* 128 */
#define	DINODE2_SIZE	(sizeof(struct ufs2_dinode))

#endif /* !_UFS_UFS_DINODE_H_ */