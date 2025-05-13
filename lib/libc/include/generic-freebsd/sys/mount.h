/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1989, 1991, 1993
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
 *	@(#)mount.h	8.21 (Berkeley) 5/20/95
 */

#ifndef _SYS_MOUNT_H_
#define _SYS_MOUNT_H_

#include <sys/ucred.h>
#include <sys/queue.h>
#ifdef _KERNEL
#include <sys/types.h>
#include <sys/lock.h>
#include <sys/lockmgr.h>
#include <sys/tslog.h>
#include <sys/_mutex.h>
#include <sys/_sx.h>
#endif

/*
 * NOTE: When changing statfs structure, mount structure, MNT_* flags or
 * MNTK_* flags also update DDB show mount command in vfs_subr.c.
 */

typedef struct fsid { int32_t val[2]; } fsid_t;	/* filesystem id type */

/* Returns non-zero if fsids are different. */
static __inline int
fsidcmp(const fsid_t *a, const fsid_t *b)
{
	return (a->val[0] != b->val[0] || a->val[1] != b->val[1]);
}

/*
 * File identifier.
 * These are unique per filesystem on a single machine.
 *
 * Note that the offset of fid_data is 4 bytes, so care must be taken to avoid
 * undefined behavior accessing unaligned fields within an embedded struct.
 */
#define	MAXFIDSZ	16

struct fid {
	u_short		fid_len;		/* length of data in bytes */
	u_short		fid_data0;		/* force longword alignment */
	char		fid_data[MAXFIDSZ];	/* data (variable length) */
};

/*
 * filesystem statistics
 */
#define	MFSNAMELEN	16		/* length of type name including null */
#define	MNAMELEN	1024		/* size of on/from name bufs */
#define	STATFS_VERSION	0x20140518	/* current version number */
struct statfs {
	uint32_t f_version;		/* structure version number */
	uint32_t f_type;		/* type of filesystem */
	uint64_t f_flags;		/* copy of mount exported flags */
	uint64_t f_bsize;		/* filesystem fragment size */
	uint64_t f_iosize;		/* optimal transfer block size */
	uint64_t f_blocks;		/* total data blocks in filesystem */
	uint64_t f_bfree;		/* free blocks in filesystem */
	int64_t	 f_bavail;		/* free blocks avail to non-superuser */
	uint64_t f_files;		/* total file nodes in filesystem */
	int64_t	 f_ffree;		/* free nodes avail to non-superuser */
	uint64_t f_syncwrites;		/* count of sync writes since mount */
	uint64_t f_asyncwrites;		/* count of async writes since mount */
	uint64_t f_syncreads;		/* count of sync reads since mount */
	uint64_t f_asyncreads;		/* count of async reads since mount */
	uint32_t f_nvnodelistsize;	/* # of vnodes */
	uint32_t f_spare0;		/* unused spare */
	uint64_t f_spare[9];		/* unused spare */
	uint32_t f_namemax;		/* maximum filename length */
	uid_t	  f_owner;		/* user that mounted the filesystem */
	fsid_t	  f_fsid;		/* filesystem id */
	char	  f_charspare[80];	    /* spare string space */
	char	  f_fstypename[MFSNAMELEN]; /* filesystem type name */
	char	  f_mntfromname[MNAMELEN];  /* mounted filesystem */
	char	  f_mntonname[MNAMELEN];    /* directory on which mounted */
};

#if defined(_WANT_FREEBSD11_STATFS) || defined(_KERNEL)
#define	FREEBSD11_STATFS_VERSION	0x20030518 /* current version number */
struct freebsd11_statfs {
	uint32_t f_version;		/* structure version number */
	uint32_t f_type;		/* type of filesystem */
	uint64_t f_flags;		/* copy of mount exported flags */
	uint64_t f_bsize;		/* filesystem fragment size */
	uint64_t f_iosize;		/* optimal transfer block size */
	uint64_t f_blocks;		/* total data blocks in filesystem */
	uint64_t f_bfree;		/* free blocks in filesystem */
	int64_t	 f_bavail;		/* free blocks avail to non-superuser */
	uint64_t f_files;		/* total file nodes in filesystem */
	int64_t	 f_ffree;		/* free nodes avail to non-superuser */
	uint64_t f_syncwrites;		/* count of sync writes since mount */
	uint64_t f_asyncwrites;		/* count of async writes since mount */
	uint64_t f_syncreads;		/* count of sync reads since mount */
	uint64_t f_asyncreads;		/* count of async reads since mount */
	uint64_t f_spare[10];		/* unused spare */
	uint32_t f_namemax;		/* maximum filename length */
	uid_t	  f_owner;		/* user that mounted the filesystem */
	fsid_t	  f_fsid;		/* filesystem id */
	char	  f_charspare[80];	/* spare string space */
	char	  f_fstypename[16];	/* filesystem type name */
	char	  f_mntfromname[88];	/* mounted filesystem */
	char	  f_mntonname[88];	/* directory on which mounted */
};
#endif /* _WANT_FREEBSD11_STATFS || _KERNEL */

#ifdef _KERNEL
#define	OMFSNAMELEN	16	/* length of fs type name, including null */
#define	OMNAMELEN	(88 - 2 * sizeof(long))	/* size of on/from name bufs */

/* XXX getfsstat.2 is out of date with write and read counter changes here. */
/* XXX statfs.2 is out of date with read counter changes here. */
struct ostatfs {
	long	f_spare2;		/* placeholder */
	long	f_bsize;		/* fundamental filesystem block size */
	long	f_iosize;		/* optimal transfer block size */
	long	f_blocks;		/* total data blocks in filesystem */
	long	f_bfree;		/* free blocks in fs */
	long	f_bavail;		/* free blocks avail to non-superuser */
	long	f_files;		/* total file nodes in filesystem */
	long	f_ffree;		/* free file nodes in fs */
	fsid_t	f_fsid;			/* filesystem id */
	uid_t	f_owner;		/* user that mounted the filesystem */
	int	f_type;			/* type of filesystem */
	int	f_flags;		/* copy of mount exported flags */
	long	f_syncwrites;		/* count of sync writes since mount */
	long	f_asyncwrites;		/* count of async writes since mount */
	char	f_fstypename[OMFSNAMELEN]; /* fs type name */
	char	f_mntonname[OMNAMELEN];	/* directory on which mounted */
	long	f_syncreads;		/* count of sync reads since mount */
	long	f_asyncreads;		/* count of async reads since mount */
	short	f_spares1;		/* unused spare */
	char	f_mntfromname[OMNAMELEN];/* mounted filesystem */
	short	f_spares2;		/* unused spare */
	/*
	 * XXX on machines where longs are aligned to 8-byte boundaries, there
	 * is an unnamed int32_t here.  This spare was after the apparent end
	 * of the struct until we bit off the read counters from f_mntonname.
	 */
	long	f_spare[2];		/* unused spare */
};
#endif	/* _KERNEL */

#if defined(_WANT_MOUNT) || defined(_KERNEL)
TAILQ_HEAD(vnodelst, vnode);

/* Mount options list */
TAILQ_HEAD(vfsoptlist, vfsopt);
struct vfsopt {
	TAILQ_ENTRY(vfsopt) link;
	char	*name;
	void	*value;
	int	len;
	int	pos;
	int	seen;
};

struct mount_pcpu {
	int		mntp_thread_in_ops;
	int		mntp_ref;
	int		mntp_lockref;
	int		mntp_writeopcount;
};

_Static_assert(sizeof(struct mount_pcpu) == 16,
    "the struct is allocated from pcpu 16 zone");

/*
 * Structure for tracking a stacked filesystem mounted above another
 * filesystem.  This is expected to be stored in the upper FS' per-mount data.
 *
 * Lock reference:
 *	i - lower mount interlock
 *	c - constant from node initialization
 */
struct mount_upper_node {
	struct mount 	*mp;	/* (c) mount object for upper FS */
	TAILQ_ENTRY(mount_upper_node) mnt_upper_link;	/* (i) position in uppers list */
};

/*
 * Structure per mounted filesystem.  Each mounted filesystem has an
 * array of operations and an instance record.  The filesystems are
 * put on a doubly linked list.
 *
 * Lock reference:
 * 	l - mnt_listmtx
 *	m - mountlist_mtx
 *	i - interlock
 *	v - vnode freelist mutex
 *	d - deferred unmount list mutex
 *	e - mnt_explock
 *
 * Unmarked fields are considered stable as long as a ref is held.
 *
 */
struct mount {
	int 		mnt_vfs_ops;		/* (i) pending vfs ops */
	int		mnt_kern_flag;		/* (i) kernel only flags */
	uint64_t	mnt_flag;		/* (i) flags shared with user */
	struct mount_pcpu *mnt_pcpu;		/* per-CPU data */
	struct vnode	*mnt_rootvnode;
	struct vnode	*mnt_vnodecovered;	/* vnode we mounted on */
	struct vfsops	*mnt_op;		/* operations on fs */
	struct vfsconf	*mnt_vfc;		/* configuration info */
	struct mtx __aligned(CACHE_LINE_SIZE)	mnt_mtx; /* mount structure interlock */
	int		mnt_gen;		/* struct mount generation */
#define	mnt_startzero	mnt_list
	TAILQ_ENTRY(mount) mnt_list;		/* (m) mount list */
	struct vnode	*mnt_syncer;		/* syncer vnode */
	int		mnt_ref;		/* (i) Reference count */
	struct vnodelst	mnt_nvnodelist;		/* (i) list of vnodes */
	int		mnt_nvnodelistsize;	/* (i) # of vnodes */
	int		mnt_writeopcount;	/* (i) write syscalls pending */
	struct vfsoptlist *mnt_opt;		/* current mount options */
	struct vfsoptlist *mnt_optnew;		/* new options passed to fs */
	struct statfs	mnt_stat;		/* cache of filesystem stats */
	struct ucred	*mnt_cred;		/* credentials of mounter */
	void *		mnt_data;		/* private data */
	time_t		mnt_time;		/* last time written*/
	int		mnt_iosize_max;		/* max size for clusters, etc */
	struct netexport *mnt_export;		/* (e) export list */
	struct label	*mnt_label;		/* MAC label for the fs */
	u_int		mnt_hashseed;		/* Random seed for vfs_hash */
	int		mnt_lockref;		/* (i) Lock reference count */
	int		mnt_secondary_writes;   /* (i) # of secondary writes */
	int		mnt_secondary_accwrites;/* (i) secondary wr. starts */
	struct thread	*mnt_susp_owner;	/* (i) thread owning suspension */
	struct ucred	*mnt_exjail;		/* (i) jail which did exports */
#define	mnt_endzero	mnt_gjprovider
	char		*mnt_gjprovider;	/* gjournal provider name */
	struct mtx	mnt_listmtx;
	struct vnodelst	mnt_lazyvnodelist;	/* (l) list of lazy vnodes */
	int		mnt_lazyvnodelistsize;	/* (l) # of lazy vnodes */
	int		mnt_upper_pending;	/* (i) # of pending ops on mnt_uppers */
	struct lock	mnt_explock;		/* vfs_export walkers lock */
	TAILQ_HEAD(, mount_upper_node) mnt_uppers; /* (i) upper mounts over us */
	TAILQ_HEAD(, mount_upper_node) mnt_notify; /* (i) upper mounts for notification */
	STAILQ_ENTRY(mount) mnt_taskqueue_link;	/* (d) our place in deferred unmount list */
	uint64_t	mnt_taskqueue_flags;	/* (d) unmount flags passed from taskqueue */
	unsigned int	mnt_unmount_retries;	/* (d) # of failed deferred unmount attempts */
};
#endif	/* _WANT_MOUNT || _KERNEL */

#ifdef _KERNEL
/*
 * Definitions for MNT_VNODE_FOREACH_ALL.
 */
struct vnode *__mnt_vnode_next_all(struct vnode **mvp, struct mount *mp);
struct vnode *__mnt_vnode_first_all(struct vnode **mvp, struct mount *mp);
void          __mnt_vnode_markerfree_all(struct vnode **mvp, struct mount *mp);

#define MNT_VNODE_FOREACH_ALL(vp, mp, mvp)				\
	for (vp = __mnt_vnode_first_all(&(mvp), (mp));			\
		(vp) != NULL; vp = __mnt_vnode_next_all(&(mvp), (mp)))

#define MNT_VNODE_FOREACH_ALL_ABORT(mp, mvp)				\
	do {								\
		MNT_ILOCK(mp);						\
		__mnt_vnode_markerfree_all(&(mvp), (mp));		\
		/* MNT_IUNLOCK(mp); -- done in above function */	\
		mtx_assert(MNT_MTX(mp), MA_NOTOWNED);			\
	} while (0)

/*
 * Definitions for MNT_VNODE_FOREACH_LAZY.
 */
typedef int mnt_lazy_cb_t(struct vnode *, void *);
struct vnode *__mnt_vnode_next_lazy(struct vnode **mvp, struct mount *mp,
    mnt_lazy_cb_t *cb, void *cbarg);
struct vnode *__mnt_vnode_first_lazy(struct vnode **mvp, struct mount *mp,
    mnt_lazy_cb_t *cb, void *cbarg);
void          __mnt_vnode_markerfree_lazy(struct vnode **mvp, struct mount *mp);

#define MNT_VNODE_FOREACH_LAZY(vp, mp, mvp, cb, cbarg)			\
	for (vp = __mnt_vnode_first_lazy(&(mvp), (mp), (cb), (cbarg));	\
		(vp) != NULL; 						\
		vp = __mnt_vnode_next_lazy(&(mvp), (mp), (cb), (cbarg)))

#define MNT_VNODE_FOREACH_LAZY_ABORT(mp, mvp)				\
	__mnt_vnode_markerfree_lazy(&(mvp), (mp))

#define	MNT_ILOCK(mp)	mtx_lock(&(mp)->mnt_mtx)
#define	MNT_ITRYLOCK(mp) mtx_trylock(&(mp)->mnt_mtx)
#define	MNT_IUNLOCK(mp)	mtx_unlock(&(mp)->mnt_mtx)
#define	MNT_MTX(mp)	(&(mp)->mnt_mtx)

#define	MNT_REF(mp)	do {						\
	mtx_assert(MNT_MTX(mp), MA_OWNED);				\
	mp->mnt_ref++;							\
} while (0)
#define	MNT_REL(mp)	do {						\
	mtx_assert(MNT_MTX(mp), MA_OWNED);				\
	(mp)->mnt_ref--;						\
	if ((mp)->mnt_vfs_ops && (mp)->mnt_ref < 0)		\
		vfs_dump_mount_counters(mp);				\
	if ((mp)->mnt_ref == 0 && (mp)->mnt_vfs_ops)		\
		wakeup((mp));						\
} while (0)

#endif /* _KERNEL */

#if defined(_WANT_MNTOPTNAMES) || defined(_KERNEL)
struct mntoptnames {
	uint64_t o_opt;
	const char *o_name;
};
#define MNTOPT_NAMES							\
	{ MNT_ASYNC,		"asynchronous" },			\
	{ MNT_EXPORTED,		"NFS exported" },			\
	{ MNT_LOCAL,		"local" },				\
	{ MNT_NOATIME,		"noatime" },				\
	{ MNT_NOEXEC,		"noexec" },				\
	{ MNT_NOSUID,		"nosuid" },				\
	{ MNT_NOSYMFOLLOW,	"nosymfollow" },			\
	{ MNT_QUOTA,		"with quotas" },			\
	{ MNT_RDONLY,		"read-only" },				\
	{ MNT_SYNCHRONOUS,	"synchronous" },			\
	{ MNT_UNION,		"union" },				\
	{ MNT_NOCLUSTERR,	"noclusterr" },				\
	{ MNT_NOCLUSTERW,	"noclusterw" },				\
	{ MNT_SUIDDIR,		"suiddir" },				\
	{ MNT_SOFTDEP,		"soft-updates" },			\
	{ MNT_SUJ,		"journaled soft-updates" },		\
	{ MNT_MULTILABEL,	"multilabel" },				\
	{ MNT_ACLS,		"acls" },				\
	{ MNT_NFS4ACLS,		"nfsv4acls" },				\
	{ MNT_GJOURNAL,		"gjournal" },				\
	{ MNT_AUTOMOUNTED,	"automounted" },			\
	{ MNT_VERIFIED,		"verified" },				\
	{ MNT_UNTRUSTED,	"untrusted" },				\
	{ MNT_NOCOVER,		"nocover" },				\
	{ MNT_EMPTYDIR,		"emptydir" },				\
	{ MNT_UPDATE,		"update" },				\
	{ MNT_DELEXPORT,	"delexport" },				\
	{ MNT_RELOAD,		"reload" },				\
	{ MNT_FORCE,		"force" },				\
	{ MNT_SNAPSHOT,		"snapshot" },				\
	{ 0, NULL }
#endif

/*
 * User specifiable flags, stored in mnt_flag.
 */
#define	MNT_RDONLY	0x0000000000000001ULL /* read only filesystem */
#define	MNT_SYNCHRONOUS	0x0000000000000002ULL /* fs written synchronously */
#define	MNT_NOEXEC	0x0000000000000004ULL /* can't exec from filesystem */
#define	MNT_NOSUID	0x0000000000000008ULL /* don't honor setuid fs bits */
#define	MNT_NFS4ACLS	0x0000000000000010ULL /* enable NFS version 4 ACLs */
#define	MNT_UNION	0x0000000000000020ULL /* union with underlying fs */
#define	MNT_ASYNC	0x0000000000000040ULL /* fs written asynchronously */
#define	MNT_SUIDDIR	0x0000000000100000ULL /* special SUID dir handling */
#define	MNT_SOFTDEP	0x0000000000200000ULL /* using soft updates */
#define	MNT_NOSYMFOLLOW	0x0000000000400000ULL /* do not follow symlinks */
#define	MNT_GJOURNAL	0x0000000002000000ULL /* GEOM journal support enabled */
#define	MNT_MULTILABEL	0x0000000004000000ULL /* MAC support for objects */
#define	MNT_ACLS	0x0000000008000000ULL /* ACL support enabled */
#define	MNT_NOATIME	0x0000000010000000ULL /* dont update file access time */
#define	MNT_NOCLUSTERR	0x0000000040000000ULL /* disable cluster read */
#define	MNT_NOCLUSTERW	0x0000000080000000ULL /* disable cluster write */
#define	MNT_SUJ		0x0000000100000000ULL /* using journaled soft updates */
#define	MNT_AUTOMOUNTED	0x0000000200000000ULL /* mounted by automountd(8) */
#define	MNT_UNTRUSTED	0x0000000800000000ULL /* filesys metadata untrusted */

/*
 * NFS export related mount flags.
 */
#define	MNT_EXRDONLY	0x0000000000000080ULL	/* exported read only */
#define	MNT_EXPORTED	0x0000000000000100ULL	/* filesystem is exported */
#define	MNT_DEFEXPORTED	0x0000000000000200ULL	/* exported to the world */
#define	MNT_EXPORTANON	0x0000000000000400ULL	/* anon uid mapping for all */
#define	MNT_EXKERB	0x0000000000000800ULL	/* exported with Kerberos */
#define	MNT_EXPUBLIC	0x0000000020000000ULL	/* public export (WebNFS) */
#define	MNT_EXTLS	0x0000004000000000ULL /* require TLS */
#define	MNT_EXTLSCERT	0x0000008000000000ULL /* require TLS with client cert */
#define	MNT_EXTLSCERTUSER 0x0000010000000000ULL /* require TLS with user cert */

/*
 * Flags set by internal operations, but visible to the user.
 */
#define	MNT_LOCAL	0x0000000000001000ULL /* filesystem is stored locally */
#define	MNT_QUOTA	0x0000000000002000ULL /* quotas are enabled on fs */
#define	MNT_ROOTFS	0x0000000000004000ULL /* identifies the root fs */
#define	MNT_USER	0x0000000000008000ULL /* mounted by a user */
#define	MNT_IGNORE	0x0000000000800000ULL /* do not show entry in df */
#define	MNT_VERIFIED	0x0000000400000000ULL /* filesystem is verified */

/*
 * Mask of flags that are visible to statfs().
 * XXX I think that this could now become (~(MNT_CMDFLAGS))
 * but the 'mount' program may need changing to handle this.
 */
#define	MNT_VISFLAGMASK	(MNT_RDONLY	| MNT_SYNCHRONOUS | MNT_NOEXEC	| \
			MNT_NOSUID	| MNT_UNION	| MNT_SUJ	| \
			MNT_ASYNC	| MNT_EXRDONLY	| MNT_EXPORTED	| \
			MNT_DEFEXPORTED	| MNT_EXPORTANON| MNT_EXKERB	| \
			MNT_LOCAL	| MNT_USER	| MNT_QUOTA	| \
			MNT_ROOTFS	| MNT_NOATIME	| MNT_NOCLUSTERR| \
			MNT_NOCLUSTERW	| MNT_SUIDDIR	| MNT_SOFTDEP	| \
			MNT_IGNORE	| MNT_EXPUBLIC	| MNT_NOSYMFOLLOW | \
			MNT_GJOURNAL	| MNT_MULTILABEL | MNT_ACLS	| \
			MNT_NFS4ACLS	| MNT_AUTOMOUNTED | MNT_VERIFIED | \
			MNT_UNTRUSTED)

/* Mask of flags that can be updated. */
#define	MNT_UPDATEMASK (MNT_NOSUID	| MNT_NOEXEC	| \
			MNT_SYNCHRONOUS	| MNT_UNION	| MNT_ASYNC	| \
			MNT_NOATIME | \
			MNT_NOSYMFOLLOW	| MNT_IGNORE	| \
			MNT_NOCLUSTERR	| MNT_NOCLUSTERW | MNT_SUIDDIR	| \
			MNT_ACLS	| MNT_USER	| MNT_NFS4ACLS	| \
			MNT_AUTOMOUNTED | MNT_UNTRUSTED)

/*
 * External filesystem command modifier flags.
 * Unmount can use the MNT_FORCE flag.
 * XXX: These are not STATES and really should be somewhere else.
 * XXX: MNT_BYFSID and MNT_NONBUSY collide with MNT_ACLS and MNT_MULTILABEL,
 *      but because MNT_ACLS and MNT_MULTILABEL are only used for mount(2),
 *      and MNT_BYFSID and MNT_NONBUSY are only used for unmount(2),
 *      it's harmless.
 */
#define	MNT_UPDATE	0x0000000000010000ULL /* not real mount, just update */
#define	MNT_DELEXPORT	0x0000000000020000ULL /* delete export host lists */
#define	MNT_RELOAD	0x0000000000040000ULL /* reload filesystem data */
#define	MNT_FORCE	0x0000000000080000ULL /* force unmount or readonly */
#define	MNT_SNAPSHOT	0x0000000001000000ULL /* snapshot the filesystem */
#define	MNT_NONBUSY	0x0000000004000000ULL /* check vnode use counts. */
#define	MNT_BYFSID	0x0000000008000000ULL /* specify filesystem by ID. */
#define	MNT_NOCOVER	0x0000001000000000ULL /* Do not cover a mount point */
#define	MNT_EMPTYDIR	0x0000002000000000ULL /* Only mount on empty dir */
#define	MNT_RECURSE	0x0000100000000000ULL /* recursively unmount uppers */
#define	MNT_DEFERRED    0x0000200000000000ULL /* unmount in async context */
#define	MNT_CMDFLAGS   (MNT_UPDATE	| MNT_DELEXPORT	| MNT_RELOAD	| \
			MNT_FORCE	| MNT_SNAPSHOT	| MNT_NONBUSY	| \
			MNT_BYFSID	| MNT_NOCOVER	| MNT_EMPTYDIR	| \
			MNT_RECURSE	| MNT_DEFERRED)

/*
 * Internal filesystem control flags stored in mnt_kern_flag.
 *
 * MNTK_UNMOUNT locks the mount entry so that name lookup cannot
 * proceed past the mount point.  This keeps the subtree stable during
 * mounts and unmounts.  When non-forced unmount flushes all vnodes
 * from the mp queue, the MNTK_UNMOUNT flag prevents insmntque() from
 * queueing new vnodes.
 *
 * MNTK_UNMOUNTF permits filesystems to detect a forced unmount while
 * dounmount() is still waiting to lock the mountpoint. This allows
 * the filesystem to cancel operations that might otherwise deadlock
 * with the unmount attempt (used by NFS).
 */
#define MNTK_UNMOUNTF		0x00000001 /* forced unmount in progress */
#define MNTK_ASYNC		0x00000002 /* filtered async flag */
#define MNTK_SOFTDEP		0x00000004 /* async disabled by softdep */
#define MNTK_NOMSYNC		0x00000008 /* don't do msync */
#define	MNTK_DRAINING		0x00000010 /* lock draining is happening */
#define	MNTK_REFEXPIRE		0x00000020 /* refcount expiring is happening */
#define MNTK_EXTENDED_SHARED	0x00000040 /* Allow shared locking for more ops */
#define	MNTK_SHARED_WRITES	0x00000080 /* Allow shared locking for writes */
#define	MNTK_NO_IOPF		0x00000100 /* Disallow page faults during reads
					      and writes. Filesystem shall
					      properly handle i/o state on
					      EFAULT. */
#define	MNTK_RECURSE		0x00000200 /* pending recursive unmount */
#define	MNTK_UPPER_WAITER	0x00000400 /* waiting to drain MNTK_UPPER_PENDING */
/* UNUSED 			0x00000800 */
#define	MNTK_UNLOCKED_INSMNTQUE	0x00001000 /* fs does not lock the vnode for
					      insmntque */
#define	MNTK_UNMAPPED_BUFS	0x00002000
#define	MNTK_USES_BCACHE	0x00004000 /* FS uses the buffer cache. */
/* UNUSED			0x00008000 */
#define	MNTK_VMSETSIZE_BUG	0x00010000
#define	MNTK_UNIONFS		0x00020000 /* A hack for F_ISUNIONSTACK */
#define	MNTK_FPLOOKUP		0x00040000 /* fast path lookup is supported */
#define	MNTK_SUSPEND_ALL	0x00080000 /* Suspended by all-fs suspension */
#define	MNTK_TASKQUEUE_WAITER	0x00100000 /* Waiting on unmount taskqueue */
/* UNUSED			0x00200000 */
/* UNUSED			0x00400000 */
#define	MNTK_NOASYNC		0x00800000 /* disable async */
#define	MNTK_UNMOUNT		0x01000000 /* unmount in progress */
#define	MNTK_MWAIT		0x02000000 /* waiting for unmount to finish */
#define	MNTK_SUSPEND		0x08000000 /* request write suspension */
#define	MNTK_SUSPEND2		0x04000000 /* block secondary writes */
#define	MNTK_SUSPENDED		0x10000000 /* write operations are suspended */
#define	MNTK_NULL_NOCACHE	0x20000000 /* auto disable cache for nullfs
					      mounts over this fs */
#define MNTK_LOOKUP_SHARED	0x40000000 /* FS supports shared lock lookups */
/* UNUSED			0x80000000 */

#ifdef _KERNEL
static inline int
MNT_SHARED_WRITES(struct mount *mp)
{

	return (mp != NULL && (mp->mnt_kern_flag & MNTK_SHARED_WRITES) != 0);
}

static inline int
MNT_EXTENDED_SHARED(struct mount *mp)
{

	return (mp != NULL && (mp->mnt_kern_flag & MNTK_EXTENDED_SHARED) != 0);
}
#endif

/*
 * Sysctl CTL_VFS definitions.
 *
 * Second level identifier specifies which filesystem. Second level
 * identifier VFS_VFSCONF returns information about all filesystems.
 * Second level identifier VFS_GENERIC is non-terminal.
 */
#define	VFS_VFSCONF		0	/* get configured filesystems */
#define	VFS_GENERIC		0	/* generic filesystem information */
/*
 * Third level identifiers for VFS_GENERIC are given below; third
 * level identifiers for specific filesystems are given in their
 * mount specific header files.
 */
#define VFS_MAXTYPENUM	1	/* int: highest defined filesystem type */
#define VFS_CONF	2	/* struct: vfsconf for filesystem given
				   as next argument */

/*
 * Flags for various system call interfaces.
 *
 * waitfor flags to vfs_sync() and getfsstat()
 */
#define MNT_WAIT	1	/* synchronously wait for I/O to complete */
#define MNT_NOWAIT	2	/* start all I/O, but do not wait for it */
#define MNT_LAZY	3	/* push data not written by filesystem syncer */
#define MNT_SUSPEND	4	/* Suspend file system after sync */

/*
 * Generic file handle
 */
struct fhandle {
	fsid_t	fh_fsid;	/* Filesystem id of mount point */
	struct	fid fh_fid;	/* Filesys specific id */
};
typedef struct fhandle	fhandle_t;

/*
 * Old export arguments without security flavor list
 */
struct oexport_args {
	int	ex_flags;		/* export related flags */
	uid_t	ex_root;		/* mapping for root uid */
	struct	xucred ex_anon;		/* mapping for anonymous user */
	struct	sockaddr *ex_addr;	/* net address to which exported */
	u_char	ex_addrlen;		/* and the net address length */
	struct	sockaddr *ex_mask;	/* mask of valid bits in saddr */
	u_char	ex_masklen;		/* and the smask length */
	char	*ex_indexfile;		/* index file for WebNFS URLs */
};

/*
 * Not quite so old export arguments with 32bit ex_flags and xucred ex_anon.
 */
#define	MAXSECFLAVORS	5
struct o2export_args {
	int	ex_flags;		/* export related flags */
	uid_t	ex_root;		/* mapping for root uid */
	struct	xucred ex_anon;		/* mapping for anonymous user */
	struct	sockaddr *ex_addr;	/* net address to which exported */
	u_char	ex_addrlen;		/* and the net address length */
	struct	sockaddr *ex_mask;	/* mask of valid bits in saddr */
	u_char	ex_masklen;		/* and the smask length */
	char	*ex_indexfile;		/* index file for WebNFS URLs */
	int	ex_numsecflavors;	/* security flavor count */
	int	ex_secflavors[MAXSECFLAVORS]; /* list of security flavors */
};

/*
 * Export arguments for local filesystem mount calls.
 */
struct export_args {
	uint64_t ex_flags;		/* export related flags */
	uid_t	ex_root;		/* mapping for root uid */
	uid_t	ex_uid;			/* mapping for anonymous user */
	int	ex_ngroups;
	gid_t	*ex_groups;
	struct	sockaddr *ex_addr;	/* net address to which exported */
	u_char	ex_addrlen;		/* and the net address length */
	struct	sockaddr *ex_mask;	/* mask of valid bits in saddr */
	u_char	ex_masklen;		/* and the smask length */
	char	*ex_indexfile;		/* index file for WebNFS URLs */
	int	ex_numsecflavors;	/* security flavor count */
	int	ex_secflavors[MAXSECFLAVORS]; /* list of security flavors */
};

/*
 * Structure holding information for a publicly exported filesystem
 * (WebNFS). Currently the specs allow just for one such filesystem.
 */
struct nfs_public {
	int		np_valid;	/* Do we hold valid information */
	fhandle_t	np_handle;	/* Filehandle for pub fs (internal) */
	struct mount	*np_mount;	/* Mountpoint of exported fs */
	char		*np_index;	/* Index file */
};

/*
 * Filesystem configuration information. One of these exists for each
 * type of filesystem supported by the kernel. These are searched at
 * mount time to identify the requested filesystem.
 *
 * XXX: Never change the first two arguments!
 */
struct vfsconf {
	u_int	vfc_version;		/* ABI version number */
	char	vfc_name[MFSNAMELEN];	/* filesystem type name */
	struct	vfsops *vfc_vfsops;	/* filesystem operations vector */
	struct	vfsops *vfc_vfsops_sd;	/* ... signal-deferred */
	int	vfc_typenum;		/* historic filesystem type number */
	int	vfc_refcount;		/* number mounted of this type */
	int	vfc_flags;		/* permanent flags */
	int	vfc_prison_flag;	/* prison allow.mount.* flag */
	struct	vfsoptdecl *vfc_opts;	/* mount options */
	TAILQ_ENTRY(vfsconf) vfc_list;	/* list of vfscons */
};

/* Userland version of the struct vfsconf. */
struct xvfsconf {
	struct	vfsops *vfc_vfsops;	/* filesystem operations vector */
	char	vfc_name[MFSNAMELEN];	/* filesystem type name */
	int	vfc_typenum;		/* historic filesystem type number */
	int	vfc_refcount;		/* number mounted of this type */
	int	vfc_flags;		/* permanent flags */
	struct	vfsconf *vfc_next;	/* next in list */
};

#ifndef BURN_BRIDGES
struct ovfsconf {
	void	*vfc_vfsops;
	char	vfc_name[32];
	int	vfc_index;
	int	vfc_refcount;
	int	vfc_flags;
};
#endif

/*
 * NB: these flags refer to IMPLEMENTATION properties, not properties of
 * any actual mounts; i.e., it does not make sense to change the flags.
 */
#define	VFCF_STATIC	0x00010000	/* statically compiled into kernel */
#define	VFCF_NETWORK	0x00020000	/* may get data over the network */
#define	VFCF_READONLY	0x00040000	/* writes are not implemented */
#define	VFCF_SYNTHETIC	0x00080000	/* data does not represent real files */
#define	VFCF_LOOPBACK	0x00100000	/* aliases some other mounted FS */
#define	VFCF_UNICODE	0x00200000	/* stores file names as Unicode */
#define	VFCF_JAIL	0x00400000	/* can be mounted from within a jail */
#define	VFCF_DELEGADMIN	0x00800000	/* supports delegated administration */
#define	VFCF_SBDRY	0x01000000	/* Stop at Boundary: defer stop requests
					   to kernel->user (AST) transition */
#define	VFCF_FILEMOUNT	0x02000000	/* allow mounting files */

typedef uint32_t fsctlop_t;

struct vfsidctl {
	int		vc_vers;	/* should be VFSIDCTL_VERS1 (below) */
	fsid_t		vc_fsid;	/* fsid to operate on */
	char		vc_fstypename[MFSNAMELEN];
					/* type of fs 'nfs' or '*' */
	fsctlop_t	vc_op;		/* operation VFS_CTL_* (below) */
	void		*vc_ptr;	/* pointer to data structure */
	size_t		vc_len;		/* sizeof said structure */
	u_int32_t	vc_spare[12];	/* spare (must be zero) */
};

/* vfsidctl API version. */
#define VFS_CTL_VERS1	0x01

/*
 * New style VFS sysctls, do not reuse/conflict with the namespace for
 * private sysctls.
 * All "global" sysctl ops have the 33rd bit set:
 * 0x...1....
 * Private sysctl ops should have the 33rd bit unset.
 */
#define VFS_CTL_QUERY	0x00010001	/* anything wrong? (vfsquery) */
#define VFS_CTL_TIMEO	0x00010002	/* set timeout for vfs notification */
#define VFS_CTL_NOLOCKS	0x00010003	/* disable file locking */

struct vfsquery {
	u_int32_t	vq_flags;
	u_int32_t	vq_spare[31];
};

/* vfsquery flags */
#define VQ_NOTRESP	0x0001	/* server down */
#define VQ_NEEDAUTH	0x0002	/* server bad auth */
#define VQ_LOWDISK	0x0004	/* we're low on space */
#define VQ_MOUNT	0x0008	/* new filesystem arrived */
#define VQ_UNMOUNT	0x0010	/* filesystem has left */
#define VQ_DEAD		0x0020	/* filesystem is dead, needs force unmount */
#define VQ_ASSIST	0x0040	/* filesystem needs assistance from external
				   program */
#define VQ_NOTRESPLOCK	0x0080	/* server lockd down */
#define VQ_FLAG0100	0x0100	/* placeholder */
#define VQ_FLAG0200	0x0200	/* placeholder */
#define VQ_FLAG0400	0x0400	/* placeholder */
#define VQ_FLAG0800	0x0800	/* placeholder */
#define VQ_FLAG1000	0x1000	/* placeholder */
#define VQ_FLAG2000	0x2000	/* placeholder */
#define VQ_FLAG4000	0x4000	/* placeholder */
#define VQ_FLAG8000	0x8000	/* placeholder */

#ifdef _KERNEL
/* Point a sysctl request at a vfsidctl's data. */
#define VCTLTOREQ(vc, req)						\
	do {								\
		(req)->newptr = (vc)->vc_ptr;				\
		(req)->newlen = (vc)->vc_len;				\
		(req)->newidx = 0;					\
	} while (0)
#endif

struct iovec;
struct uio;

#ifdef _KERNEL

/*
 * vfs_busy specific flags and mask.
 */
#define	MBF_NOWAIT	0x01
#define	MBF_MNTLSTLOCK	0x02
#define	MBF_MASK	(MBF_NOWAIT | MBF_MNTLSTLOCK)

#ifdef MALLOC_DECLARE
MALLOC_DECLARE(M_MOUNT);
MALLOC_DECLARE(M_STATFS);
#endif
extern int maxvfsconf;		/* highest defined filesystem type */

TAILQ_HEAD(vfsconfhead, vfsconf);
extern struct vfsconfhead vfsconf;

/*
 * Operations supported on mounted filesystem.
 */
struct mount_args;
struct nameidata;
struct sysctl_req;
struct mntarg;

/*
 * N.B., vfs_cmount is the ancient vfsop invoked by the old mount(2) syscall.
 * The new way is vfs_mount.
 *
 * vfs_cmount implementations typically translate arguments from their
 * respective old per-FS structures into the key-value list supported by
 * nmount(2), then use kernel_mount(9) to mimic nmount(2) from kernelspace.
 *
 * Filesystems with mounters that use nmount(2) do not need to and should not
 * implement vfs_cmount.  Hopefully a future cleanup can remove vfs_cmount and
 * mount(2) entirely.
 */
typedef int vfs_cmount_t(struct mntarg *ma, void *data, uint64_t flags);
typedef int vfs_unmount_t(struct mount *mp, int mntflags);
typedef int vfs_root_t(struct mount *mp, int flags, struct vnode **vpp);
typedef	int vfs_quotactl_t(struct mount *mp, int cmds, uid_t uid, void *arg,
		    bool *mp_busy);
typedef	int vfs_statfs_t(struct mount *mp, struct statfs *sbp);
typedef	int vfs_sync_t(struct mount *mp, int waitfor);
typedef	int vfs_vget_t(struct mount *mp, ino_t ino, int flags,
		    struct vnode **vpp);
typedef	int vfs_fhtovp_t(struct mount *mp, struct fid *fhp,
		    int flags, struct vnode **vpp);
typedef	int vfs_checkexp_t(struct mount *mp, struct sockaddr *nam,
		    uint64_t *extflagsp, struct ucred **credanonp,
		    int *numsecflavors, int *secflavors);
typedef	int vfs_init_t(struct vfsconf *);
typedef	int vfs_uninit_t(struct vfsconf *);
typedef	int vfs_extattrctl_t(struct mount *mp, int cmd,
		    struct vnode *filename_vp, int attrnamespace,
		    const char *attrname);
typedef	int vfs_mount_t(struct mount *mp);
typedef int vfs_sysctl_t(struct mount *mp, fsctlop_t op,
		    struct sysctl_req *req);
typedef void vfs_susp_clean_t(struct mount *mp);
typedef void vfs_notify_lowervp_t(struct mount *mp, struct vnode *lowervp);
typedef void vfs_purge_t(struct mount *mp);
struct sbuf;
typedef int vfs_report_lockf_t(struct mount *mp, struct sbuf *sb);

struct vfsops {
	vfs_mount_t		*vfs_mount;
	vfs_cmount_t		*vfs_cmount;
	vfs_unmount_t		*vfs_unmount;
	vfs_root_t		*vfs_root;
	vfs_root_t		*vfs_cachedroot;
	vfs_quotactl_t		*vfs_quotactl;
	vfs_statfs_t		*vfs_statfs;
	vfs_sync_t		*vfs_sync;
	vfs_vget_t		*vfs_vget;
	vfs_fhtovp_t		*vfs_fhtovp;
	vfs_checkexp_t		*vfs_checkexp;
	vfs_init_t		*vfs_init;
	vfs_uninit_t		*vfs_uninit;
	vfs_extattrctl_t	*vfs_extattrctl;
	vfs_sysctl_t		*vfs_sysctl;
	vfs_susp_clean_t	*vfs_susp_clean;
	vfs_notify_lowervp_t	*vfs_reclaim_lowervp;
	vfs_notify_lowervp_t	*vfs_unlink_lowervp;
	vfs_purge_t		*vfs_purge;
	vfs_report_lockf_t	*vfs_report_lockf;
	vfs_mount_t		*vfs_spare[6];	/* spares for ABI compat */
};

vfs_statfs_t	__vfs_statfs;

#define	VFS_MOUNT(MP) ({						\
	int _rc;							\
									\
	TSRAW(curthread, TS_ENTER, "VFS_MOUNT", (MP)->mnt_vfc->vfc_name);\
	_rc = (*(MP)->mnt_op->vfs_mount)(MP);				\
	TSRAW(curthread, TS_EXIT, "VFS_MOUNT", (MP)->mnt_vfc->vfc_name);\
	_rc; })

#define	VFS_UNMOUNT(MP, FORCE) ({					\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_unmount)(MP, FORCE);			\
	_rc; })

#define	VFS_ROOT(MP, FLAGS, VPP) ({					\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_root)(MP, FLAGS, VPP);		\
	_rc; })

#define	VFS_CACHEDROOT(MP, FLAGS, VPP) ({				\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_cachedroot)(MP, FLAGS, VPP);		\
	_rc; })

#define	VFS_QUOTACTL(MP, C, U, A, MP_BUSY) ({				\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_quotactl)(MP, C, U, A, MP_BUSY);	\
	_rc; })

#define	VFS_STATFS(MP, SBP) ({						\
	int _rc;							\
									\
	_rc = __vfs_statfs((MP), (SBP));				\
	_rc; })

#define	VFS_SYNC(MP, WAIT) ({						\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_sync)(MP, WAIT);			\
	_rc; })

#define	VFS_VGET(MP, INO, FLAGS, VPP) ({				\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_vget)(MP, INO, FLAGS, VPP);		\
	_rc; })

#define	VFS_FHTOVP(MP, FIDP, FLAGS, VPP) ({				\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_fhtovp)(MP, FIDP, FLAGS, VPP);	\
	_rc; })

#define	VFS_CHECKEXP(MP, NAM, EXFLG, CRED, NUMSEC, SEC) ({		\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_checkexp)(MP, NAM, EXFLG, CRED, NUMSEC,\
	    SEC);							\
	_rc; })

#define	VFS_EXTATTRCTL(MP, C, FN, NS, N) ({				\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_extattrctl)(MP, C, FN, NS, N);	\
	_rc; })

#define	VFS_SYSCTL(MP, OP, REQ) ({					\
	int _rc;							\
									\
	_rc = (*(MP)->mnt_op->vfs_sysctl)(MP, OP, REQ);			\
	_rc; })

#define	VFS_SUSP_CLEAN(MP) do {						\
	if (*(MP)->mnt_op->vfs_susp_clean != NULL) {			\
		(*(MP)->mnt_op->vfs_susp_clean)(MP);			\
	}								\
} while (0)

#define	VFS_RECLAIM_LOWERVP(MP, VP) do {				\
	if (*(MP)->mnt_op->vfs_reclaim_lowervp != NULL) {		\
		(*(MP)->mnt_op->vfs_reclaim_lowervp)((MP), (VP));	\
	}								\
} while (0)

#define	VFS_UNLINK_LOWERVP(MP, VP) do {					\
	if (*(MP)->mnt_op->vfs_unlink_lowervp != NULL) {		\
		(*(MP)->mnt_op->vfs_unlink_lowervp)((MP), (VP));	\
	}								\
} while (0)

#define	VFS_PURGE(MP) do {						\
	if (*(MP)->mnt_op->vfs_purge != NULL) {				\
		(*(MP)->mnt_op->vfs_purge)(MP);				\
	}								\
} while (0)

#define VFS_KNOTE_LOCKED(vp, hint) do					\
{									\
	VN_KNOTE((vp), (hint), KNF_LISTLOCKED);				\
} while (0)

#define VFS_KNOTE_UNLOCKED(vp, hint) do					\
{									\
	VN_KNOTE((vp), (hint), 0);					\
} while (0)

#include <sys/module.h>

/*
 * Version numbers.
 */
#define VFS_VERSION_00	0x19660120
#define VFS_VERSION_01	0x20121030
#define VFS_VERSION_02	0x20180504
#define VFS_VERSION	VFS_VERSION_02

#define VFS_SET(vfsops, fsname, flags) \
	static struct vfsconf fsname ## _vfsconf = {		\
		.vfc_version = VFS_VERSION,			\
		.vfc_name = #fsname,				\
		.vfc_vfsops = &vfsops,				\
		.vfc_typenum = -1,				\
		.vfc_flags = flags,				\
	};							\
	static moduledata_t fsname ## _mod = {			\
		#fsname,					\
		vfs_modevent,					\
		& fsname ## _vfsconf				\
	};							\
	DECLARE_MODULE(fsname, fsname ## _mod, SI_SUB_VFS, SI_ORDER_MIDDLE)

enum vfs_notify_upper_type {
	VFS_NOTIFY_UPPER_RECLAIM,
	VFS_NOTIFY_UPPER_UNLINK,
};

/*
 * exported vnode operations
 */

/* Define this to indicate that vfs_exjail_clone() exists for ZFS to use. */
#define	VFS_SUPPORTS_EXJAIL_CLONE	1

int	dounmount(struct mount *, uint64_t, struct thread *);

int	kernel_mount(struct mntarg *ma, uint64_t flags);
struct mntarg *mount_arg(struct mntarg *ma, const char *name, const void *val, int len);
struct mntarg *mount_argb(struct mntarg *ma, int flag, const char *name);
struct mntarg *mount_argf(struct mntarg *ma, const char *name, const char *fmt, ...);
struct mntarg *mount_argsu(struct mntarg *ma, const char *name, const void *val, int len);
void	statfs_scale_blocks(struct statfs *sf, long max_size);
struct vfsconf *vfs_byname(const char *);
struct vfsconf *vfs_byname_kld(const char *, struct thread *td, int *);
void	vfs_mount_destroy(struct mount *);
void	vfs_event_signal(fsid_t *, u_int32_t, intptr_t);
void	vfs_freeopts(struct vfsoptlist *opts);
void	vfs_deleteopt(struct vfsoptlist *opts, const char *name);
int	vfs_buildopts(struct uio *auio, struct vfsoptlist **options);
int	vfs_flagopt(struct vfsoptlist *opts, const char *name, uint64_t *w,
	    uint64_t val);
int	vfs_getopt(struct vfsoptlist *, const char *, void **, int *);
int	vfs_getopt_pos(struct vfsoptlist *opts, const char *name);
int	vfs_getopt_size(struct vfsoptlist *opts, const char *name,
	    off_t *value);
char	*vfs_getopts(struct vfsoptlist *, const char *, int *error);
int	vfs_copyopt(struct vfsoptlist *, const char *, void *, int);
int	vfs_filteropt(struct vfsoptlist *, const char **legal);
void	vfs_opterror(struct vfsoptlist *opts, const char *fmt, ...);
int	vfs_scanopt(struct vfsoptlist *opts, const char *name, const char *fmt, ...);
int	vfs_setopt(struct vfsoptlist *opts, const char *name, void *value,
	    int len);
int	vfs_setopt_part(struct vfsoptlist *opts, const char *name, void *value,
	    int len);
int	vfs_setopts(struct vfsoptlist *opts, const char *name,
	    const char *value);
int	vfs_setpublicfs			    /* set publicly exported fs */
	    (struct mount *, struct netexport *, struct export_args *);
void	vfs_periodic(struct mount *, int);
int	vfs_busy(struct mount *, int);
void	vfs_exjail_clone(struct mount *, struct mount *);
void	vfs_exjail_delete(struct prison *);
int	vfs_export			 /* process mount export info */
	    (struct mount *, struct export_args *, bool);
void	vfs_free_addrlist(struct netexport *);
void	vfs_allocate_syncvnode(struct mount *);
void	vfs_deallocate_syncvnode(struct mount *);
int	vfs_donmount(struct thread *td, uint64_t fsflags,
	    struct uio *fsoptions);
void	vfs_getnewfsid(struct mount *);
struct	mount *vfs_getvfs(fsid_t *);      /* return vfs given fsid */
struct	mount *vfs_busyfs(fsid_t *);
int	vfs_modevent(module_t, int, void *);
void	vfs_mount_error(struct mount *, const char *, ...);
void	vfs_mountroot(void);			/* mount our root filesystem */
void	vfs_mountedfrom(struct mount *, const char *from);
void	vfs_notify_upper(struct vnode *, enum vfs_notify_upper_type);
struct mount *vfs_ref_from_vp(struct vnode *);
void	vfs_ref(struct mount *);
void	vfs_rel(struct mount *);
struct mount *vfs_mount_alloc(struct vnode *, struct vfsconf *, const char *,
	    struct ucred *);
int	vfs_suser(struct mount *, struct thread *);
void	vfs_unbusy(struct mount *);
void	vfs_unmountall(void);
struct mount *vfs_register_upper_from_vp(struct vnode *,
	    struct mount *ump, struct mount_upper_node *);
void	vfs_register_for_notification(struct mount *, struct mount *,
	    struct mount_upper_node *);
void	vfs_unregister_for_notification(struct mount *,
	    struct mount_upper_node *);
void	vfs_unregister_upper(struct mount *, struct mount_upper_node *);
int	vfs_remount_ro(struct mount *mp);
int	vfs_report_lockf(struct mount *mp, struct sbuf *sb);

extern	TAILQ_HEAD(mntlist, mount) mountlist;	/* mounted filesystem list */
extern	struct mtx_padalign mountlist_mtx;
extern	struct nfs_public nfs_pub;
extern	struct sx vfsconf_sx;
#define	vfsconf_lock()		sx_xlock(&vfsconf_sx)
#define	vfsconf_unlock()	sx_xunlock(&vfsconf_sx)
#define	vfsconf_slock()		sx_slock(&vfsconf_sx)
#define	vfsconf_sunlock()	sx_sunlock(&vfsconf_sx)
struct vnode *mntfs_allocvp(struct mount *, struct vnode *);
void   mntfs_freevp(struct vnode *);

/*
 * Declarations for these vfs default operations are located in
 * kern/vfs_default.c.  They will be automatically used to replace
 * null entries in VFS ops tables when registering a new filesystem
 * type in the global table.
 */
vfs_root_t		vfs_stdroot;
vfs_quotactl_t		vfs_stdquotactl;
vfs_statfs_t		vfs_stdstatfs;
vfs_sync_t		vfs_stdsync;
vfs_sync_t		vfs_stdnosync;
vfs_vget_t		vfs_stdvget;
vfs_fhtovp_t		vfs_stdfhtovp;
vfs_checkexp_t		vfs_stdcheckexp;
vfs_init_t		vfs_stdinit;
vfs_uninit_t		vfs_stduninit;
vfs_extattrctl_t	vfs_stdextattrctl;
vfs_sysctl_t		vfs_stdsysctl;

void	syncer_suspend(void);
void	syncer_resume(void);

struct vnode *vfs_cache_root_clear(struct mount *);
void	vfs_cache_root_set(struct mount *, struct vnode *);

void	vfs_op_barrier_wait(struct mount *);
void	vfs_op_enter(struct mount *);
void	vfs_op_exit_locked(struct mount *);
void	vfs_op_exit(struct mount *);

#ifdef DIAGNOSTIC
void	vfs_assert_mount_counters(struct mount *);
void	vfs_dump_mount_counters(struct mount *);
#else
#define vfs_assert_mount_counters(mp) do { } while (0)
#define vfs_dump_mount_counters(mp) do { } while (0)
#endif

enum mount_counter { MNT_COUNT_REF, MNT_COUNT_LOCKREF, MNT_COUNT_WRITEOPCOUNT };
int	vfs_mount_fetch_counter(struct mount *, enum mount_counter);

void suspend_all_fs(void);
void resume_all_fs(void);

/*
 * Code transitioning mnt_vfs_ops to > 0 issues IPIs until it observes
 * all CPUs not executing code enclosed by thread_in_ops_pcpu variable.
 *
 * This provides an invariant that by the time the last CPU is observed not
 * executing, everyone else entering will see the counter > 0 and exit.
 *
 * Note there is no barrier between vfs_ops and the rest of the code in the
 * section. It is not necessary as the writer has to wait for everyone to drain
 * before making any changes or only make changes safe while the section is
 * executed.
 */
#define	vfs_mount_pcpu(mp)		zpcpu_get(mp->mnt_pcpu)
#define	vfs_mount_pcpu_remote(mp, cpu)	zpcpu_get_cpu(mp->mnt_pcpu, cpu)

#define vfs_op_thread_entered(mp) ({				\
	MPASS(curthread->td_critnest > 0);			\
	struct mount_pcpu *_mpcpu = vfs_mount_pcpu(mp);		\
	_mpcpu->mntp_thread_in_ops == 1;			\
})

#define vfs_op_thread_enter_crit(mp, _mpcpu) ({			\
	bool _retval_crit = true;				\
	MPASS(curthread->td_critnest > 0);			\
	_mpcpu = vfs_mount_pcpu(mp);				\
	MPASS(mpcpu->mntp_thread_in_ops == 0);			\
	_mpcpu->mntp_thread_in_ops = 1;				\
	atomic_interrupt_fence();					\
	if (__predict_false(mp->mnt_vfs_ops > 0)) {		\
		vfs_op_thread_exit_crit(mp, _mpcpu);		\
		_retval_crit = false;				\
	}							\
	_retval_crit;						\
})

#define vfs_op_thread_enter(mp, _mpcpu) ({			\
	bool _retval;						\
	critical_enter();					\
	_retval = vfs_op_thread_enter_crit(mp, _mpcpu);		\
	if (__predict_false(!_retval))				\
		critical_exit();				\
	_retval;						\
})

#define vfs_op_thread_exit_crit(mp, _mpcpu) do {		\
	MPASS(_mpcpu == vfs_mount_pcpu(mp));			\
	MPASS(_mpcpu->mntp_thread_in_ops == 1);			\
	atomic_interrupt_fence();					\
	_mpcpu->mntp_thread_in_ops = 0;				\
} while (0)

#define vfs_op_thread_exit(mp, _mpcpu) do {			\
	vfs_op_thread_exit_crit(mp, _mpcpu);			\
	critical_exit();					\
} while (0)

#define vfs_mp_count_add_pcpu(_mpcpu, count, val) do {		\
	MPASS(_mpcpu->mntp_thread_in_ops == 1);			\
	_mpcpu->mntp_##count += val;				\
} while (0)

#define vfs_mp_count_sub_pcpu(_mpcpu, count, val) do {		\
	MPASS(_mpcpu->mntp_thread_in_ops == 1);			\
	_mpcpu->mntp_##count -= val;				\
} while (0)

#else /* !_KERNEL */

#include <sys/cdefs.h>

struct stat;

__BEGIN_DECLS
int	fhlink(struct fhandle *, const char *);
int	fhlinkat(struct fhandle *, int, const char *);
int	fhopen(const struct fhandle *, int);
int	fhreadlink(struct fhandle *, char *, size_t);
int	fhstat(const struct fhandle *, struct stat *);
int	fhstatfs(const struct fhandle *, struct statfs *);
int	fstatfs(int, struct statfs *);
int	getfh(const char *, fhandle_t *);
int	getfhat(int, char *, struct fhandle *, int);
int	getfsstat(struct statfs *, long, int);
int	getmntinfo(struct statfs **, int);
int	lgetfh(const char *, fhandle_t *);
int	mount(const char *, const char *, int, void *);
int	nmount(struct iovec *, unsigned int, int);
int	statfs(const char *, struct statfs *);
int	unmount(const char *, int);

/* C library stuff */
int	getvfsbyname(const char *, struct xvfsconf *);
__END_DECLS

#endif /* _KERNEL */

#endif /* !_SYS_MOUNT_H_ */