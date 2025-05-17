/*	$NetBSD: ufsmount.h,v 1.44 2022/11/17 06:40:40 chs Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1989, 1993
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
 *	@(#)ufsmount.h	8.6 (Berkeley) 3/30/95
 */

#ifndef _UFS_UFS_UFSMOUNT_H_
#define _UFS_UFS_UFSMOUNT_H_

#include <sys/mount.h> /* struct export_args30 */

/*
 * Arguments to mount UFS-based filesystems
 */
struct ufs_args {
	char	*fspec;			/* block special device to mount */
};

/*
 * Arguments to mount MFS
 */
struct mfs_args {
	char	*fspec;			/* name to export for statfs */
	struct	export_args30 _pad1; /* compat with old userland tools */
	void *	base;			/* base of file system in memory */
	u_long	size;			/* size of file system */
};

#ifdef _KERNEL

#if defined(_KERNEL_OPT)
#include "opt_ffs.h"
#endif

#include <sys/mutex.h>

#include <ufs/ufs/extattr.h>
#include <ufs/ufs/quota.h>

struct buf;
struct inode;
struct nameidata;
struct timeval;
struct uio;
struct vnode;

/* This structure describes the UFS specific mount structure data. */
struct ufsmount {
	struct	mount *um_mountp;		/* filesystem vfs structure */
	dev_t	um_dev;				/* device mounted */
	struct	vnode *um_devvp;		/* block device mounted vnode */
	u_long	um_fstype;
	u_int32_t um_flags;			/* UFS-specific flags - see below */
	union {					/* pointer to superblock */
		struct	fs *fs;			/* FFS */
		struct	lfs *lfs;		/* LFS */
		struct  m_ext2fs *e2fs;		/* EXT2FS */
		struct  chfs_mount *chfs;	/* CHFS */
	} ufsmount_u;
#define	um_fs	ufsmount_u.fs
#define	um_lfs	ufsmount_u.lfs
#define um_e2fs	ufsmount_u.e2fs
#define um_e2fsb ufsmount_u.e2fs->s_es
#define um_chfs	ufsmount_u.chfs

	/* Extended attribute information. */
	struct ufs_extattr_per_mount um_extattr;

	struct	vnode *um_quotas[MAXQUOTAS];	/* pointer to quota files */
	kauth_cred_t   um_cred[MAXQUOTAS];	/* quota file access cred */
	u_long	um_nindir;			/* indirect ptrs per block */
	u_long	um_lognindir;			/* log2 of um_nindir */
	u_long	um_bptrtodb;			/* indir ptr to disk block */
	u_long	um_seqinc;			/* inc between seq blocks */
	kmutex_t um_lock;			/* lock on global data */
	union {
	    struct um_q1 {
		time_t	q1_btime[MAXQUOTAS];	/* block quota time limit */
		time_t	q1_itime[MAXQUOTAS];	/* inode quota time limit */
		char	q1_qflags[MAXQUOTAS];	/* quota specific flags */
	    } um_q1;
	    struct um_q2 {
		uint64_t q2_bsize;		/* block size of quota file */
		uint64_t q2_bmask;		/* mask for above */
	    } um_q2;
	} um_q;
#define umq1_btime  um_q.um_q1.q1_btime
#define umq1_itime  um_q.um_q1.q1_itime
#define umq1_qflags um_q.um_q1.q1_qflags
#define umq2_bsize  um_q.um_q2.q2_bsize
#define umq2_bmask  um_q.um_q2.q2_bmask

	void	*um_oldfscompat;		/* save 4.2 rotbl */
	int	um_maxsymlinklen;
	int	um_dirblksiz;
	u_int64_t um_maxfilesize;
	void	*um_snapinfo;			/* snapshot private data */

	const struct ufs_ops *um_ops;

	void *um_discarddata;
};

struct ufs_ops {
	void (*uo_itimes)(struct inode *ip, const struct timespec *,
	    const struct timespec *, const struct timespec *);
	int (*uo_update)(struct vnode *, const struct timespec *,
	    const struct timespec *, int);
	int (*uo_truncate)(struct vnode *, off_t, int, kauth_cred_t);
	int (*uo_balloc)(struct vnode *, off_t, int, kauth_cred_t, int,
	    struct buf **);
        void (*uo_snapgone)(struct vnode *);
	int (*uo_bufrd)(struct vnode *, struct uio *, int, kauth_cred_t);
	int (*uo_bufwr)(struct vnode *, struct uio *, int, kauth_cred_t);
};

#define	UFS_OPS(vp)	(VFSTOUFS((vp)->v_mount)->um_ops)

#define	UFS_ITIMES(vp, acc, mod, cre) \
	(*UFS_OPS(vp)->uo_itimes)(VTOI(vp), (acc), (mod), (cre))
#define	UFS_UPDATE(vp, acc, mod, flags) \
	(*UFS_OPS(vp)->uo_update)((vp), (acc), (mod), (flags))
#define	UFS_TRUNCATE(vp, off, flags, cr) \
	(*UFS_OPS(vp)->uo_truncate)((vp), (off), (flags), (cr))
#define	UFS_BALLOC(vp, off, size, cr, flags, bpp) \
	(*UFS_OPS(vp)->uo_balloc)((vp), (off), (size), (cr), (flags), (bpp))
#define	UFS_SNAPGONE(vp) \
	(*UFS_OPS(vp)->uo_snapgone)((vp))
#define	UFS_BUFRD(vp, uio, ioflag, cred) \
	(*UFS_OPS(vp)->uo_bufrd)((vp), (uio), (ioflag), (cred))
#define	UFS_BUFWR(vp, uio, ioflag, cred) \
	(*UFS_OPS(vp)->uo_bufwr)((vp), (uio), (ioflag), (cred))

/* UFS-specific flags */
#define UFS_NEEDSWAP	0x01	/* filesystem metadata need byte-swapping */
#define UFS_ISAPPLEUFS	0x02	/* filesystem is Apple UFS */
#define UFS_QUOTA	0x04	/* filesystem has QUOTA (v1) */
#define UFS_QUOTA2	0x08	/* filesystem has QUOTA2 */
#define UFS_EA		0x10	/* UFS2 with extattrs */

/*
 * Filesystem types
 */
#define UFS1  1
#define UFS2  2


/*
 * Flags describing the state of quotas.
 */
#define	QTF_OPENING	0x01			/* Q_QUOTAON in progress */
#define	QTF_CLOSING	0x02			/* Q_QUOTAOFF in progress */

/* Convert mount ptr to ufsmount ptr. */
#define VFSTOUFS(mp)	((struct ufsmount *)((mp)->mnt_data))

#ifdef APPLE_UFS
#define UFS_MPISAPPLEUFS(ump)	((ump)->um_flags & UFS_ISAPPLEUFS)
#else
#define UFS_MPISAPPLEUFS(ump)	(0)
#endif

/*
 * Macros to access file system parameters in the ufsmount structure.
 * Used by ufs_bmap.
 */
#define MNINDIR(ump)			((ump)->um_nindir)
#define	blkptrtodb(ump, b)		((b) << (ump)->um_bptrtodb)

/*
 * Predicate for byte-swapping support.
 */
#define	FSFMT(vp)	(((vp)->v_mount->mnt_iflag & IMNT_DTYPE) == 0)

#endif /* _KERNEL */

#endif /* !_UFS_UFS_UFSMOUNT_H_ */