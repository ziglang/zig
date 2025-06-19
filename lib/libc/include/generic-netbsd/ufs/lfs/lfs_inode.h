/*	$NetBSD: lfs_inode.h,v 1.26 2022/03/23 13:06:06 andvar Exp $	*/
/*  from NetBSD: ulfs_inode.h,v 1.5 2013/06/06 00:51:50 dholland Exp  */
/*  from NetBSD: inode.h,v 1.72 2016/06/03 15:36:03 christos Exp  */

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
 *	@(#)inode.h	8.9 (Berkeley) 5/14/95
 */

#ifndef _UFS_LFS_LFS_INODE_H_
#define	_UFS_LFS_LFS_INODE_H_

/*
 * Some of the userlevel code (fsck, newfs, lfs_cleanerd) wants to use
 * the in-memory inode structure in a faked-up kernel environment.
 * This header file provides a reasonably sanitized version of the
 * structures and definitions needed for that purpose.
 */

#include <miscfs/genfs/genfs_node.h>
#include <ufs/lfs/lfs.h>

/*
 * Adjustable filesystem parameters
 */
#define MIN_FREE_SEGS	20
#define MIN_RESV_SEGS	15

/*
 * The following constants define the usage of the quota file array in the
 * ulfsmount structure and dquot array in the inode structure.  The semantics
 * of the elements of these arrays are defined in the routine lfs_getinoquota;
 * the remainder of the quota code treats them generically and need not be
 * inspected when changing the size of the array.
 */
#define	ULFS_MAXQUOTAS	2
#define	ULFS_USRQUOTA	0	/* element used for user quotas */
#define	ULFS_GRPQUOTA	1	/* element used for group quotas */

/*
 * Lookup result state (other than the result inode). This is
 * currently stashed in the vnode between VOP_LOOKUP and directory
 * operation VOPs, which is gross.
 *
 * XXX ulr_diroff is a lookup hint from the previous call of VOP_LOOKUP.
 * probably it should not be here.
 */
struct ulfs_lookup_results {
	int32_t	  ulr_count;	/* Size of free slot in directory. */
	doff_t	  ulr_endoff;	/* End of useful stuff in directory. */
	doff_t	  ulr_diroff;	/* Offset in dir, where we found last entry. */
	doff_t	  ulr_offset;	/* Offset of free space in directory. */
	uint32_t ulr_reclen;	/* Size of found directory entry. */
};

/* notyet XXX */
#define ULFS_CHECK_CRAPCOUNTER(dp) ((void)(dp)->i_crapcounter)

/*
 * Per-filesystem inode extensions.
 */
struct lfs_inode_ext;

/*
 * The inode is used to describe each active (or recently active) file in the
 * ULFS filesystem. It is composed of two types of information. The first part
 * is the information that is needed only while the file is active (such as
 * the identity of the file and linkage to speed its lookup). The second part
 * is the permanent meta-data associated with the file which is read in
 * from the permanent dinode from long term storage when the file becomes
 * active, and is put back when the file is no longer being used.
 */
struct inode {
	struct genfs_node i_gnode;
	TAILQ_ENTRY(inode) i_nextsnap; /* snapshot file list. */
	struct	vnode *i_vnode;	/* Vnode associated with this inode. */
	struct  ulfsmount *i_ump; /* Mount point associated with this inode. */
	struct	vnode *i_devvp;	/* Vnode for block I/O. */

	uint32_t i_state;	/* state */
#define	IN_ACCESS	0x0001		/* Access time update request. */
#define	IN_CHANGE	0x0002		/* Inode change time update request. */
#define	IN_UPDATE	0x0004		/* Inode was written to; update mtime. */
#define	IN_MODIFY	0x2000		/* Modification time update request. */
#define	IN_MODIFIED	0x0008		/* Inode has been modified. */
#define	IN_ACCESSED	0x0010		/* Inode has been accessed. */
/* 	   unused	0x0020 */	/* was IN_RENAME */
#define	IN_SHLOCK	0x0040		/* File has shared lock. */
#define	IN_EXLOCK	0x0080		/* File has exclusive lock. */
#define	IN_CLEANING	0x0100		/* LFS: file is being cleaned */
#define	IN_ADIROP	0x0200		/* LFS: dirop in progress */
/* 	   unused	0x0400 */	/* was FFS-only IN_SPACECOUNTED */
#define	IN_PAGING       0x1000		/* LFS: file is on paging queue */
#define IN_CDIROP       0x4000          /* LFS: dirop completed pending i/o */
#define	IN_MARKER	0x00010000	/* LFS: marker inode for iteration */

/* XXX this is missing some of the flags */
#define IN_ALLMOD (IN_MODIFIED|IN_ACCESS|IN_CHANGE|IN_UPDATE|IN_MODIFY|IN_ACCESSED|IN_CLEANING)

	dev_t	  i_dev;	/* Device associated with the inode. */
	ino_t	  i_number;	/* The identity of the inode. */

	struct lfs *i_lfs;	/* The LFS volume we belong to. */

	void	*i_unused1;	/* Unused. */
	struct	 dquot *i_dquot[ULFS_MAXQUOTAS]; /* Dquot structures. */
	u_quad_t i_modrev;	/* Revision level for NFS lease. */
	struct	 lockf *i_lockf;/* Head of byte-level lock list. */

	/*
	 * Side effects; used during (and after) directory lookup.
	 * XXX should not be here.
	 */
	struct ulfs_lookup_results i_crap;
	unsigned i_crapcounter;	/* serial number for i_crap */

	/*
	 * Inode extensions
	 */
	union {
		/* Other extensions could go here... */
		struct  lfs_inode_ext *lfs;
	} inode_ext;
	/*
	 * Copies from the on-disk dinode itself.
	 *
	 * These fields are currently only used by LFS.
	 */
	uint16_t i_mode;	/* IFMT, permissions; see below. */
	int16_t   i_nlink;	/* File link count. */
	uint64_t i_size;	/* File byte count. */
	uint32_t i_flags;	/* Status flags (chflags). */
	int32_t   i_gen;	/* Generation number. */
	uint32_t i_uid;		/* File owner. */
	uint32_t i_gid;		/* File group. */
	uint16_t i_omode;	/* Old mode, for ulfs_reclaim. */

	struct dirhash *i_dirhash;	/* Hashing for large directories */

	/*
	 * The on-disk dinode itself.
	 */
	union lfs_dinode *i_din;
};

/*
 * LFS inode extensions.
 */
struct lfs_inode_ext {
	off_t	  lfs_osize;		/* size of file on disk */
	uint64_t  lfs_effnblocks;  /* number of blocks when i/o completes */
	size_t	  lfs_fragsize[ULFS_NDADDR]; /* size of on-disk direct blocks */
	TAILQ_ENTRY(inode) lfs_dchain;  /* Dirop chain. */
	TAILQ_ENTRY(inode) lfs_pchain;  /* Paging chain. */
#define LFSI_NO_GOP_WRITE 0x01
#define LFSI_DELETED      0x02
#define LFSI_WRAPBLOCK    0x04
#define LFSI_WRAPWAIT     0x08
#define LFSI_BMAP         0x10
	uint32_t lfs_iflags;		/* Inode flags */
	daddr_t   lfs_hiblk;		/* Highest lbn held by inode */
#ifdef _KERNEL
	SPLAY_HEAD(lfs_splay, lbnentry) lfs_lbtree; /* Tree of balloc'd lbns */
	int	  lfs_nbtree;		/* Size of tree */
	LIST_HEAD(, segdelta) lfs_segdhd;
#endif
	int16_t	  lfs_odnlink;		/* on-disk nlink count for cleaner */
};
#define i_lfs_osize		inode_ext.lfs->lfs_osize
#define i_lfs_effnblks		inode_ext.lfs->lfs_effnblocks
#define i_lfs_fragsize		inode_ext.lfs->lfs_fragsize
#define i_lfs_dchain		inode_ext.lfs->lfs_dchain
#define i_lfs_pchain		inode_ext.lfs->lfs_pchain
#define i_lfs_iflags		inode_ext.lfs->lfs_iflags
#define i_lfs_hiblk		inode_ext.lfs->lfs_hiblk
#define i_lfs_lbtree		inode_ext.lfs->lfs_lbtree
#define i_lfs_nbtree		inode_ext.lfs->lfs_nbtree
#define i_lfs_segdhd		inode_ext.lfs->lfs_segdhd
#define i_lfs_odnlink		inode_ext.lfs->lfs_odnlink

/*
 * "struct buf" associated definitions
 */

#ifdef _KERNEL

# define LFS_IS_MALLOC_BUF(bp) ((bp)->b_iodone == lfs_free_aiodone)

/* log for debugging writes to the Ifile */
# ifdef DEBUG
struct lfs_log_entry {
	const char *op;
	const char *file;
	int pid;
	int line;
	daddr_t block;
	unsigned long flags;
};
extern int lfs_lognum;
extern struct lfs_log_entry lfs_log[LFS_LOGLENGTH];
#  define LFS_BWRITE_LOG(bp) lfs_bwrite_log((bp), __FILE__, __LINE__)
#  define LFS_ENTER_LOG(theop, thefile, theline, lbn, theflags, thepid) do {\
									\
	mutex_enter(&lfs_lock);						\
	lfs_log[lfs_lognum].op = theop;					\
	lfs_log[lfs_lognum].file = thefile;				\
	lfs_log[lfs_lognum].line = (theline);				\
	lfs_log[lfs_lognum].pid = (thepid);				\
	lfs_log[lfs_lognum].block = (lbn);				\
	lfs_log[lfs_lognum].flags = (theflags);				\
	lfs_lognum = (lfs_lognum + 1) % LFS_LOGLENGTH;			\
	mutex_exit(&lfs_lock);						\
} while (0)

/* Must match list in lfs_vfsops.c ! */
#  define DLOG_RF     0  /* roll forward */
#  define DLOG_ALLOC  1  /* inode alloc */
#  define DLOG_AVAIL  2  /* lfs_{,r,f}avail */
#  define DLOG_FLUSH  3  /* flush */
#  define DLOG_LLIST  4  /* locked list accounting */
#  define DLOG_WVNODE 5  /* vflush/writevnodes verbose */
#  define DLOG_VNODE  6  /* vflush/writevnodes */
#  define DLOG_SEG    7  /* segwrite */
#  define DLOG_SU     8  /* seguse accounting */
#  define DLOG_CLEAN  9  /* cleaner routines */
#  define DLOG_MOUNT  10 /* mount/unmount */
#  define DLOG_PAGE   11 /* putpages/gop_write */
#  define DLOG_DIROP  12 /* dirop accounting */
#  define DLOG_MALLOC 13 /* lfs_malloc accounting */
#  define DLOG_MAX    14 /* The terminator */
#  define DLOG(a) lfs_debug_log a
# else /* ! DEBUG */
#  define LFS_BCLEAN_LOG(fs, bp)
#  define LFS_BWRITE_LOG(bp)		VOP_BWRITE((bp)->b_vp, (bp))
#  define LFS_ENTER_LOG(theop, thefile, theline, lbn, theflags, thepid) __nothing
#  define DLOG(a)
# endif /* ! DEBUG */
#else /* ! _KERNEL */
# define LFS_BWRITE_LOG(bp)		VOP_BWRITE((bp))
#endif /* _KERNEL */


#endif /* _UFS_LFS_LFS_INODE_H_ */