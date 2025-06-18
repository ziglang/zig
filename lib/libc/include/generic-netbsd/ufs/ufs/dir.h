/*	$NetBSD: dir.h,v 1.27 2019/05/05 15:07:12 christos Exp $	*/

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

#ifndef _UFS_UFS_DIR_H_
#define	_UFS_UFS_DIR_H_

/*
 * Theoretically, directories can be more than 2Gb in length; however, in
 * practice this seems unlikely. So, we define the type doff_t as a 32-bit
 * quantity to keep down the cost of doing lookup on a 32-bit machine.
 */
#define	doff_t		int32_t
#define	UFS_MAXDIRSIZE	(0x7fffffff)

/*
 * A directory consists of some number of blocks of UFS_DIRBLKSIZ
 * bytes, where UFS_DIRBLKSIZ is chosen such that it can be transferred
 * to disk in a single atomic operation (e.g. 512 bytes on most machines).
 *
 * Each UFS_DIRBLKSIZ byte block contains some number of directory entry
 * structures, which are of variable length.  Each directory entry has
 * a struct direct at the front of it, containing its inode number,
 * the length of the entry, and the length of the name contained in
 * the entry.  These are followed by the name padded to a 4 byte boundary.
 * All names are guaranteed null terminated.
 * The maximum length of a name in a directory is FFS_MAXNAMLEN.
 *
 * The macro UFS_DIRSIZ(fmt, dp) gives the amount of space required to represent
 * a directory entry.  Free space in a directory is represented by
 * entries which have dp->d_reclen > DIRSIZ(fmt, dp).  All UFS_DIRBLKSIZ bytes
 * in a directory block are claimed by the directory entries.  This
 * usually results in the last entry in a directory having a large
 * dp->d_reclen.  When entries are deleted from a directory, the
 * space is returned to the previous entry in the same directory
 * block by increasing its dp->d_reclen.  If the first entry of
 * a directory block is free, then its dp->d_ino is set to 0.
 * Entries other than the first in a directory do not normally have
 * dp->d_ino set to 0.
 */
#undef	UFS_DIRBLKSIZ
#define	UFS_DIRBLKSIZ	DEV_BSIZE
#define	FFS_MAXNAMLEN	255
#define APPLEUFS_DIRBLKSIZ 1024

#define d_ino d_fileno
struct	direct {
	u_int32_t d_fileno;		/* inode number of entry */
	u_int16_t d_reclen;		/* length of this record */
	u_int8_t  d_type; 		/* file type, see below */
	u_int8_t  d_namlen;		/* length of string in d_name */
	char	  d_name[FFS_MAXNAMLEN + 1];/* name with length <= FFS_MAXNAMLEN */
};

/*
 * File types
 */
#define	DT_UNKNOWN	 0
#define	DT_FIFO		 1
#define	DT_CHR		 2
#define	DT_DIR		 4
#define	DT_BLK		 6
#define	DT_REG		 8
#define	DT_LNK		10
#define	DT_SOCK		12
#define	DT_WHT		14

/*
 * Convert between stat structure types and directory types.
 */
#define	IFTODT(mode)	(((mode) & 0170000) >> 12)
#define	DTTOIF(dirtype)	((dirtype) << 12)

/*
 * The UFS_DIRSIZ macro gives the minimum record length which will hold
 * the directory entry.  This requires the amount of space in struct direct
 * without the d_name field, plus enough space for the name with a terminating
 * NUL byte (dp->d_namlen+1), rounded up to a 4 byte boundary.
 * The UFS_NAMEPAD macro gives the number bytes of padding needed including
 * the NUL terminating byte.
 */
#define DIR_ROUNDUP	4
#define UFS_NAMEROUNDUP(namlen)	(((namlen) + DIR_ROUNDUP) & ~(DIR_ROUNDUP - 1))
#define UFS_NAMEPAD(namlen)	(DIR_ROUNDUP - ((namlen) & (DIR_ROUNDUP - 1)))
#define	UFS_DIRECTSIZ(namlen) \
	((sizeof(struct direct) - (FFS_MAXNAMLEN+1)) + UFS_NAMEROUNDUP(namlen))

#if (BYTE_ORDER == LITTLE_ENDIAN)
#define UFS_DIRSIZ(oldfmt, dp, needswap)	\
    (((oldfmt) && !(needswap)) ?		\
    UFS_DIRECTSIZ((dp)->d_type) : UFS_DIRECTSIZ((dp)->d_namlen))
#else
#define UFS_DIRSIZ(oldfmt, dp, needswap)	\
    (((oldfmt) && (needswap)) ?			\
    UFS_DIRECTSIZ((dp)->d_type) : UFS_DIRECTSIZ((dp)->d_namlen))
#endif

/*
 * UFS_OLDDIRFMT and UFS_NEWDIRFMT are code numbers for a directory
 * format change that happened in ffs a long time ago. (Back in the
 * 80s, if I'm not mistaken.)
 *
 * These code numbers do not appear on disk. They're generated from
 * runtime logic that is cued by other things, which is why
 * UFS_OLDDIRFMT is confusingly 1 and UFS_NEWDIRFMT is confusingly 0.
 *
 * Relatedly, the FFS_EI byte swapping logic for directories is a
 * horrible mess. For example, to access the namlen field, one
 * currently does the following:
 *
 * #if (BYTE_ORDER == LITTLE_ENDIAN)
 *         swap = (UFS_IPNEEDSWAP(VTOI(vp)) == 0);
 * #else
 *         swap = (UFS_IPNEEDSWAP(VTOI(vp)) != 0);
 * #endif
 *         return ((FSFMT(vp) && swap) ? dp->d_type : dp->d_namlen);
 *
 * UFS_IPNEEDSWAP() returns true if the volume is opposite-endian. This
 * horrible "swap" logic is cutpasted all over everywhere but amounts
 * to the following:
 *
 *    running code      volume          lfs_dobyteswap  "swap"
 *    ----------------------------------------------------------
 *    LITTLE_ENDIAN     LITTLE_ENDIAN   false           true
 *    LITTLE_ENDIAN     BIG_ENDIAN      true            false
 *    BIG_ENDIAN        LITTLE_ENDIAN   true            true
 *    BIG_ENDIAN        BIG_ENDIAN      false           false
 *
 * which you'll note boils down to "volume is little-endian".
 *
 * Meanwhile, FSFMT(vp) yields UFS_OLDDIRFMT or UFS_NEWDIRFMT via
 * perverted logic of its own. Since UFS_OLDDIRFMT is 1 (contrary to
 * what one might expect approaching this cold) what this mess means
 * is: on OLDDIRFMT volumes that are little-endian, we read the
 * namlen value out of the type field. This is because on OLDDIRFMT
 * volumes there is no d_type field, just a 16-bit d_namlen; so if
 * the 16-bit d_namlen is little-endian, the useful part of it is
 * in the first byte, which in the NEWDIRFMT structure is the d_type
 * field.
 */

#define UFS_OLDDIRFMT	1
#define UFS_NEWDIRFMT	0

/*
 * Template for manipulating directories.  Should use struct direct's,
 * but the name field is FFS_MAXNAMLEN - 1, and this just won't do.
 */
struct dirtemplate {
	u_int32_t	dot_ino;
	int16_t		dot_reclen;
	u_int8_t	dot_type;
	u_int8_t	dot_namlen;
	char		dot_name[4];	/* must be multiple of 4 */
	u_int32_t	dotdot_ino;
	int16_t		dotdot_reclen;
	u_int8_t	dotdot_type;
	u_int8_t	dotdot_namlen;
	char		dotdot_name[4];	/* ditto */
};

/*
 * This is the old format of directories, sans type element.
 */
struct odirtemplate {
	u_int32_t	dot_ino;
	int16_t		dot_reclen;
	u_int16_t	dot_namlen;
	char		dot_name[4];	/* must be multiple of 4 */
	u_int32_t	dotdot_ino;
	int16_t		dotdot_reclen;
	u_int16_t	dotdot_namlen;
	char		dotdot_name[4];	/* ditto */
};
#endif /* !_UFS_UFS_DIR_H_ */