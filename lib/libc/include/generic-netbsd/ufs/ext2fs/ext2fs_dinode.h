/*	$NetBSD: ext2fs_dinode.h,v 1.37 2017/01/13 18:04:36 christos Exp $	*/

/*
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
 *	@(#)dinode.h	8.6 (Berkeley) 9/13/94
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
 *	@(#)dinode.h	8.6 (Berkeley) 9/13/94
 *  Modified for ext2fs by Manuel Bouyer.
 */

#ifndef _UFS_EXT2FS_EXT2FS_DINODE_H_
#define _UFS_EXT2FS_EXT2FS_DINODE_H_

#if !defined(_KERNEL) && !defined(_STANDALONE)
#include <stddef.h> /* for offsetof */
#endif

#include <sys/stat.h>

/*
 * The root inode is the root of the file system.  Inode 0 can't be used for
 * normal purposes and bad blocks are normally linked to inode 1, thus
 * the root inode is 2.
 * Inode 3 to 10 are reserved in ext2fs.
 */
#define	EXT2_BADBLKINO		((ino_t)1)
#define	EXT2_ROOTINO		((ino_t)2)
#define	EXT2_ACLIDXINO		((ino_t)3)
#define	EXT2_ACLDATAINO		((ino_t)4)
#define	EXT2_BOOTLOADERINO	((ino_t)5)
#define	EXT2_UNDELDIRINO	((ino_t)6)
#define	EXT2_RESIZEINO		((ino_t)7)
#define	EXT2_JOURNALINO		((ino_t)8)
#define	EXT2_FIRSTINO		((ino_t)11)

/*
 * A dinode contains all the meta-data associated with a UFS file.
 * This structure defines the on-disk format of a dinode. Since
 * this structure describes an on-disk structure, all its fields
 * are defined by types with precise widths.
 */

/*
 * XXX these are the same values as UFS_NDADDR/UFS_NIADDR and it is
 * far from clear that there isn't code that relies on them being the
 * same.
 */
#define	EXT2FS_NDADDR	12		/* Direct addresses in inode. */
#define	EXT2FS_NIADDR	3		/* Indirect addresses in inode. */

#define EXT2_MAXSYMLINKLEN ((EXT2FS_NDADDR+EXT2FS_NIADDR) * sizeof (uint32_t))
#define E2MAXSYMLINKLEN	EXT2_MAXSYMLINKLEN

struct ext2fs_dinode {
	uint16_t	e2di_mode;	/*   0: IFMT, permissions; see below. */
	uint16_t	e2di_uid;	/*   2: Owner UID */
	uint32_t	e2di_size;	/*   4: Size (in bytes) */
	uint32_t	e2di_atime;	/*   8: Access time */
	uint32_t	e2di_ctime;	/*  12: Create time */
	uint32_t	e2di_mtime;	/*  16: Modification time */
	uint32_t	e2di_dtime;	/*  20: Deletion time */
	uint16_t	e2di_gid;	/*  24: Owner GID */
	uint16_t	e2di_nlink;	/*  26: File link count */
	uint32_t	e2di_nblock;	/*  28: Blocks count */
	uint32_t	e2di_flags;	/*  32: Status flags (chflags) */
	uint32_t	e2di_version;	/*  36: was reserved1 */
	uint32_t	e2di_blocks[EXT2FS_NDADDR+EXT2FS_NIADDR];
					/* 40: disk blocks */
	uint32_t	e2di_gen;	/* 100: generation number */
	uint32_t	e2di_facl;	/* 104: file ACL (ext3) */
	uint32_t	e2di_size_high;	/* 108: Size (in bytes) high */
	uint32_t	e2di_obso_faddr;/* 112: obsolete fragment address (ext2) */
	uint16_t	e2di_nblock_high; /* 116: Blocks count bits 47:32 (ext4) */
	uint16_t	e2di_facl_high; /* 118: file ACL bits 47:32 (ext4/64bit) */
	uint16_t	e2di_uid_high;	/* 120: Owner UID top 16 bits (ext4) */
	uint16_t	e2di_gid_high;	/* 122: Owner GID top 16 bits (ext4) */
	uint16_t 	e2di_checksum_low;  /* 124: crc LE (not implemented) (ext4) */
	uint16_t 	e2di_reserved;      /* 126: reserved */
	uint16_t	e2di_extra_isize;   /* 128: inode extra size (over 128) actually used (ext4) */
	uint16_t	e2di_checksum_high; /* 130: crc BE (not implemented) (ext4) */
	uint32_t	e2di_ctime_extra;   /* 132: ctime (nsec << 2 | high epoch) (ext4) */
	uint32_t	e2di_mtime_extra;   /* 136: mtime (nsec << 2 | high epoch) (ext4) */
	uint32_t	e2di_atime_extra;   /* 140: atime (nsec << 2 | high epoch) (ext4) */
	uint32_t	e2di_crtime;        /* 144: creation time (epoch) (ext4) */
	uint32_t	e2di_crtime_extra;  /* 148: creation time (nsec << 2 | high epoch) (ext4) */
	uint32_t	e2di_version_high;  /* 152: version high (ext4) */
	uint32_t	e2di_projid;        /* 156: project id (not implemented) (ext4) */
};

#define	i_e2fs_mode		i_din.e2fs_din->e2di_mode
#define	i_e2fs_uid		i_din.e2fs_din->e2di_uid
#define	i_e2fs_size		i_din.e2fs_din->e2di_size
#define	i_e2fs_atime		i_din.e2fs_din->e2di_atime
#define	i_e2fs_ctime		i_din.e2fs_din->e2di_ctime
#define	i_e2fs_mtime		i_din.e2fs_din->e2di_mtime
#define	i_e2fs_dtime		i_din.e2fs_din->e2di_dtime
#define	i_e2fs_gid		i_din.e2fs_din->e2di_gid
#define	i_e2fs_nlink		i_din.e2fs_din->e2di_nlink
#define	i_e2fs_nblock		i_din.e2fs_din->e2di_nblock
#define	i_e2fs_flags		i_din.e2fs_din->e2di_flags
#define	i_e2fs_version		i_din.e2fs_din->e2di_version
#define	i_e2fs_blocks		i_din.e2fs_din->e2di_blocks
#define	i_e2fs_rdev		i_din.e2fs_din->e2di_rdev
#define	i_e2fs_gen		i_din.e2fs_din->e2di_gen
#define	i_e2fs_facl		i_din.e2fs_din->e2di_facl
#define	i_e2fs_nblock_high	i_din.e2fs_din->e2di_nblock_high
#define	i_e2fs_facl_high	i_din.e2fs_din->e2di_facl_high
#define	i_e2fs_uid_high		i_din.e2fs_din->e2di_uid_high
#define	i_e2fs_gid_high		i_din.e2fs_din->e2di_gid_high

/* File permissions. */
#define	EXT2_IEXEC		0000100		/* Executable. */
#define	EXT2_IWRITE		0000200		/* Writable. */
#define	EXT2_IREAD		0000400		/* Readable. */
#define	EXT2_ISVTX		0001000		/* Sticky bit. */
#define	EXT2_ISGID		0002000		/* Set-gid. */
#define	EXT2_ISUID		0004000		/* Set-uid. */

/* File types. */
#define	EXT2_IFMT		0170000		/* Mask of file type. */
#define	EXT2_IFIFO		0010000		/* Named pipe (fifo). */
#define	EXT2_IFCHR		0020000		/* Character device. */
#define	EXT2_IFDIR		0040000		/* Directory file. */
#define	EXT2_IFBLK		0060000		/* Block device. */
#define	EXT2_IFREG		0100000		/* Regular file. */
#define	EXT2_IFLNK		0120000		/* Symbolic link. */
#define	EXT2_IFSOCK		0140000		/* UNIX domain socket. */

/* file flags */
#define EXT2_SECRM		0x00000001 /* Secure deletion */
#define EXT2_UNRM		0x00000002 /* Undelete */
#define EXT2_COMPR		0x00000004 /* Compress file */
#define EXT2_SYNC		0x00000008 /* Synchronous updates */
#define EXT2_IMMUTABLE		0x00000010 /* Immutable file */
#define EXT2_APPEND		0x00000020 /* writes to file may only append */
#define EXT2_NODUMP		0x00000040 /* do not dump file */
#define EXT2_NOATIME		0x00000080 /* do not update atime */
#define EXT2_INDEX		0x00001000 /* hash-indexed directory */
#define EXT2_IMAGIC		0x00002000 /* AFS directory */
#define EXT2_JOURNAL_DATA	0x00004000 /* file data should be journaled */
#define EXT2_NOTAIL		0x00008000 /* file tail should not be merged */
#define EXT2_DIRSYNC		0x00010000 /* dirsync behaviour */
#define EXT2_TOPDIR		0x00020000 /* Top of directory hierarchies*/
#define EXT2_HUGE_FILE		0x00040000 /* Set to each huge file */
#define EXT2_EXTENTS		0x00080000 /* Inode uses extents */
#define EXT2_EA_INODE		0x00200000 /* Inode used for large EA */
#define EXT2_EOFBLOCKS		0x00400000 /* Blocks allocated beyond EOF */
#define EXT2_INLINE_DATA	0x10000000 /* Inode has inline data */
#define EXT2_PROJINHERIT	0x20000000 /* Children inherit project ID */

/* Size of on-disk inode. */
#define EXT2_REV0_DINODE_SIZE	128U
#define EXT2_DINODE_SIZE(fs)	((fs)->e2fs.e2fs_rev > E2FS_REV0 ?	\
				    (fs)->e2fs.e2fs_inode_size :	\
				    EXT2_REV0_DINODE_SIZE)
#define EXT2_DINODE_FITS(dinode, field, isize) (\
	(isize > EXT2_REV0_DINODE_SIZE) \
	&& ((EXT2_REV0_DINODE_SIZE + (dinode)->e2di_extra_isize)  >= offsetof(struct ext2fs_dinode, field) + sizeof((dinode)->field)) \
	)

/*
 * Time encoding
 * Lower two bits of extra field are extra high bits for epoch; unfortunately still, Linux kernels treat 11 there as 00 for compatibility
 * Rest of extra fields are nanoseconds
 */
static __inline void
ext2fs_dinode_time_get(struct timespec *ts, uint32_t epoch, uint32_t extra)
{
	ts->tv_sec = (signed) epoch;

	if (extra) {
		uint64_t epoch_bits = extra & 0x3;
		/* XXX compatibility with linux kernel < 4.20 */
		if (epoch_bits == 3 && ts->tv_sec < 0)
			epoch_bits = 0;

		ts->tv_sec |= epoch_bits << 32;

		ts->tv_nsec = extra >> 2;
	} else {
		ts->tv_nsec = 0;
	}
}
#define EXT2_DINODE_TIME_GET(ts, dinode, field, isize) \
	ext2fs_dinode_time_get(ts, (dinode)->field, \
		EXT2_DINODE_FITS(dinode, field ## _extra, isize) \
			? (dinode)->field ## _extra : 0 \
	)

static __inline void
ext2fs_dinode_time_set(const struct timespec *ts, uint32_t *epoch, uint32_t *extra)
{
	*epoch = (int32_t) ts->tv_sec;

	if (extra) {
		uint32_t epoch_bits = (ts->tv_sec >> 32) & 0x3;

		*extra = (ts->tv_nsec << 2) | epoch_bits;
	}
}
#define EXT2_DINODE_TIME_SET(ts, dinode, field, isize) \
	ext2fs_dinode_time_set(ts, &(dinode)->field, \
		EXT2_DINODE_FITS(dinode, field ## _extra, isize) \
			? &(dinode)->field ## _extra : NULL \
	)

/*
 * The e2di_blocks fields may be overlaid with other information for
 * file types that do not have associated disk storage. Block
 * and character devices overlay the first data block with their
 * dev_t value. Short symbolic links place their path in the
 * di_db area.
 */

#define e2di_rdev		e2di_blocks[0]
#define e2di_shortlink		e2di_blocks

/* e2fs needs byte swapping on big-endian systems */
#if BYTE_ORDER == LITTLE_ENDIAN
#	define e2fs_iload(old, new, isize)	\
		memcpy((new),(old),(isize))
#	define e2fs_isave(old, new, isize)	\
		memcpy((new),(old),(isize))
#else
void e2fs_i_bswap(struct ext2fs_dinode *, struct ext2fs_dinode *, size_t);
#	define e2fs_iload(old, new, isize) e2fs_i_bswap((old), (new), (isize))
#	define e2fs_isave(old, new, isize) e2fs_i_bswap((old), (new), (isize))
#endif

#endif /* !_UFS_EXT2FS_EXT2FS_DINODE_H_ */