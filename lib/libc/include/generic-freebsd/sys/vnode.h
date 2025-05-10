/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1989, 1993
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
 *	@(#)vnode.h	8.7 (Berkeley) 2/4/94
 */

#ifndef _SYS_VNODE_H_
#define	_SYS_VNODE_H_

#include <sys/bufobj.h>
#include <sys/queue.h>
#include <sys/lock.h>
#include <sys/lockmgr.h>
#include <sys/mutex.h>
#include <sys/rangelock.h>
#include <sys/selinfo.h>
#include <sys/uio.h>
#include <sys/acl.h>
#include <sys/ktr.h>
#include <sys/_seqc.h>

/*
 * The vnode is the focus of all file activity in UNIX.  There is a
 * unique vnode allocated for each active file, each current directory,
 * each mounted-on file, text file, and the root.
 */

/*
 * Vnode types.  VNON means no type.
 */
__enum_uint8_decl(vtype) {
	VNON,
	VREG,
	VDIR,
	VBLK,
	VCHR,
	VLNK,
	VSOCK,
	VFIFO,
	VBAD,
	VMARKER,
	VLASTTYPE = VMARKER,
};

__enum_uint8_decl(vstate) {
	VSTATE_UNINITIALIZED,
	VSTATE_CONSTRUCTED,
	VSTATE_DESTROYING,
	VSTATE_DEAD,
	VLASTSTATE = VSTATE_DEAD,
};

enum vgetstate {
	VGET_NONE,
	VGET_HOLDCNT,
	VGET_USECOUNT,
};

/*
 * Each underlying filesystem allocates its own private area and hangs
 * it from v_data.  If non-null, this area is freed in getnewvnode().
 */

struct namecache;
struct cache_fpl;

struct vpollinfo {
	struct	mtx vpi_lock;		/* lock to protect below */
	struct	selinfo vpi_selinfo;	/* identity of poller(s) */
	short	vpi_events;		/* what they are looking for */
	short	vpi_revents;		/* what has happened */
};

/*
 * Reading or writing any of these items requires holding the appropriate lock.
 *
 * Lock reference:
 *	c - namecache mutex
 *	i - interlock
 *	l - mp mnt_listmtx or freelist mutex
 *	I - updated with atomics, 0->1 and 1->0 transitions with interlock held
 *	m - mount point interlock
 *	p - pollinfo lock
 *	u - Only a reference to the vnode is needed to read.
 *	v - vnode lock
 *
 * Vnodes may be found on many lists.  The general way to deal with operating
 * on a vnode that is on a list is:
 *	1) Lock the list and find the vnode.
 *	2) Lock interlock so that the vnode does not go away.
 *	3) Unlock the list to avoid lock order reversals.
 *	4) vget with LK_INTERLOCK and check for ENOENT, or
 *	5) Check for DOOMED if the vnode lock is not required.
 *	6) Perform your operation, then vput().
 */

#if defined(_KERNEL) || defined(_KVM_VNODE)

struct vnode {
	/*
	 * Fields which define the identity of the vnode.  These fields are
	 * owned by the filesystem (XXX: and vgone() ?)
	 */
	__enum_uint8(vtype) v_type;		/* u vnode type */
	__enum_uint8(vstate) v_state;		/* u vnode state */
	short	v_irflag;			/* i frequently read flags */
	seqc_t	v_seqc;				/* i modification count */
	uint32_t v_nchash;			/* u namecache hash */
	u_int	v_hash;
	struct	vop_vector *v_op;		/* u vnode operations vector */
	void	*v_data;			/* u private data for fs */

	/*
	 * Filesystem instance stuff
	 */
	struct	mount *v_mount;			/* u ptr to vfs we are in */
	TAILQ_ENTRY(vnode) v_nmntvnodes;	/* m vnodes for mount point */

	/*
	 * Type specific fields, only one applies to any given vnode.
	 */
	union {
		struct mount	*v_mountedhere;	/* v ptr to mountpoint (VDIR) */
		struct unpcb	*v_unpcb;	/* v unix domain net (VSOCK) */
		struct cdev	*v_rdev; 	/* v device (VCHR, VBLK) */
		struct fifoinfo	*v_fifoinfo;	/* v fifo (VFIFO) */
	};

	/*
	 * vfs_hash: (mount + inode) -> vnode hash.  The hash value
	 * itself is grouped with other int fields, to avoid padding.
	 */
	LIST_ENTRY(vnode)	v_hashlist;

	/*
	 * VFS_namecache stuff
	 */
	LIST_HEAD(, namecache) v_cache_src;	/* c Cache entries from us */
	TAILQ_HEAD(, namecache) v_cache_dst;	/* c Cache entries to us */
	struct namecache *v_cache_dd;		/* c Cache entry for .. vnode */

	/*
	 * Locking
	 */
	struct	lock v_lock;			/* u (if fs don't have one) */
	struct	mtx v_interlock;		/* lock for "i" things */
	struct	lock *v_vnlock;			/* u pointer to vnode lock */

	/*
	 * The machinery of being a vnode
	 */
	TAILQ_ENTRY(vnode) v_vnodelist;		/* l vnode lists */
	TAILQ_ENTRY(vnode) v_lazylist;		/* l vnode lazy list */
	struct bufobj	v_bufobj;		/* * Buffer cache object */

	/*
	 * Hooks for various subsystems and features.
	 */
	struct vpollinfo *v_pollinfo;		/* i Poll events, p for *v_pi */
	struct label *v_label;			/* MAC label for vnode */
	struct lockf *v_lockf;		/* Byte-level advisory lock list */
	struct rangelock v_rl;			/* Byte-range lock */

	u_int	v_holdcnt;			/* I prevents recycling. */
	u_int	v_usecount;			/* I ref count of users */
	u_short	v_iflag;			/* i vnode flags (see below) */
	u_short	v_vflag;			/* v vnode flags */
	u_short	v_mflag;			/* l mnt-specific vnode flags */
	short	v_dbatchcpu;			/* i LRU requeue deferral batch */
	int	v_writecount;			/* I ref count of writers or
						   (negative) text users */
	int	v_seqc_users;			/* i modifications pending */
};

#ifndef DEBUG_LOCKS
#ifdef _LP64
/*
 * Not crossing 448 bytes fits 9 vnodes per page. If you have to add fields
 * to the structure and there is nothing which can be done to prevent growth
 * then so be it. But don't grow it without a good reason.
 */
_Static_assert(sizeof(struct vnode) <= 448, "vnode size crosses 448 bytes");
#endif
#endif

#endif /* defined(_KERNEL) || defined(_KVM_VNODE) */

#define	bo2vnode(bo)	__containerof((bo), struct vnode, v_bufobj)

/* XXX: These are temporary to avoid a source sweep at this time */
#define v_object	v_bufobj.bo_object

/* We don't need to lock the knlist */
#define	VN_KNLIST_EMPTY(vp) ((vp)->v_pollinfo == NULL ||	\
	    KNLIST_EMPTY(&(vp)->v_pollinfo->vpi_selinfo.si_note))

#define VN_KNOTE(vp, b, a)					\
	do {							\
		if (!VN_KNLIST_EMPTY(vp))			\
			KNOTE(&vp->v_pollinfo->vpi_selinfo.si_note, (b), \
			    (a) | KNF_NOKQLOCK);		\
	} while (0)
#define	VN_KNOTE_LOCKED(vp, b)		VN_KNOTE(vp, b, KNF_LISTLOCKED)
#define	VN_KNOTE_UNLOCKED(vp, b)	VN_KNOTE(vp, b, 0)

/*
 * Vnode flags.
 *	VI flags are protected by interlock and live in v_iflag
 *	VIRF flags are protected by interlock and live in v_irflag
 *	VV flags are protected by the vnode lock and live in v_vflag
 *
 *	VIRF_DOOMED is doubly protected by the interlock and vnode lock.  Both
 *	are required for writing but the status may be checked with either.
 */
#define	VHOLD_NO_SMR	(1<<29)	/* Disable vhold_smr */
#define VHOLD_ALL_FLAGS (VHOLD_NO_SMR)

#define	VIRF_DOOMED	0x0001	/* This vnode is being recycled */
#define	VIRF_PGREAD	0x0002	/* Direct reads from the page cache are permitted,
				   never cleared once set */
#define	VIRF_MOUNTPOINT	0x0004	/* This vnode is mounted on */
#define	VIRF_TEXT_REF	0x0008	/* Executable mappings ref the vnode */
#define	VIRF_CROSSMP	0x0010	/* Cross-mp vnode, no locking */

#define	VI_UNUSED0	0x0001	/* unused */
#define	VI_MOUNT	0x0002	/* Mount in progress */
#define	VI_DOINGINACT	0x0004	/* VOP_INACTIVE is in progress */
#define	VI_OWEINACT	0x0008	/* Need to call inactive */
#define	VI_DEFINACT	0x0010	/* deferred inactive */
#define	VI_FOPENING	0x0020	/* In open, with opening process having the
				   first right to advlock file */

#define	VV_ROOT		0x0001	/* root of its filesystem */
#define	VV_ISTTY	0x0002	/* vnode represents a tty */
#define	VV_NOSYNC	0x0004	/* unlinked, stop syncing */
#define	VV_ETERNALDEV	0x0008	/* device that is never destroyed */
#define	VV_CACHEDLABEL	0x0010	/* Vnode has valid cached MAC label */
#define	VV_VMSIZEVNLOCK	0x0020	/* object size check requires vnode lock */
#define	VV_COPYONWRITE	0x0040	/* vnode is doing copy-on-write */
#define	VV_SYSTEM	0x0080	/* vnode being used by kernel */
#define	VV_PROCDEP	0x0100	/* vnode is process dependent */
#define	VV_UNLINKED	0x0200	/* unlinked but stil open directory */
#define	VV_DELETED	0x0400	/* should be removed */
#define	VV_MD		0x0800	/* vnode backs the md device */
#define	VV_FORCEINSMQ	0x1000	/* force the insmntque to succeed */
#define	VV_READLINK	0x2000	/* fdescfs linux vnode */
#define	VV_UNREF	0x4000	/* vunref, do not drop lock in inactive() */
#define	VV_CROSSLOCK	0x8000	/* vnode lock is shared w/ root mounted here */

#define	VMP_LAZYLIST	0x0001	/* Vnode is on mnt's lazy list */

/*
 * Vnode attributes.  A field value of VNOVAL represents a field whose value
 * is unavailable (getattr) or which is not to be changed (setattr).
 */
struct vattr {
	__enum_uint8(vtype)	va_type;	/* vnode type (for create) */
	u_short		va_mode;	/* files access mode and type */
	u_short		va_padding0;
	uid_t		va_uid;		/* owner user id */
	gid_t		va_gid;		/* owner group id */
	nlink_t		va_nlink;	/* number of references to file */
	dev_t		va_fsid;	/* filesystem id */
	ino_t		va_fileid;	/* file id */
	u_quad_t	va_size;	/* file size in bytes */
	long		va_blocksize;	/* blocksize preferred for i/o */
	struct timespec	va_atime;	/* time of last access */
	struct timespec	va_mtime;	/* time of last modification */
	struct timespec	va_ctime;	/* time file changed */
	struct timespec	va_birthtime;	/* time file created */
	u_long		va_gen;		/* generation number of file */
	u_long		va_flags;	/* flags defined for file */
	dev_t		va_rdev;	/* device the special file represents */
	u_quad_t	va_bytes;	/* bytes of disk space held by file */
	u_quad_t	va_filerev;	/* file modification number */
	u_int		va_vaflags;	/* operations flags, see below */
	long		va_spare;	/* remain quad aligned */
};

/*
 * Flags for va_vaflags.
 */
#define	VA_UTIMES_NULL	0x01		/* utimes argument was NULL */
#define	VA_EXCLUSIVE	0x02		/* exclusive create request */
#define	VA_SYNC		0x04		/* O_SYNC truncation */

/*
 * Flags for ioflag. (high 16 bits used to ask for read-ahead and
 * help with write clustering)
 * NB: IO_NDELAY and IO_DIRECT are linked to fcntl.h
 */
#define	IO_UNIT		0x0001		/* do I/O as atomic unit */
#define	IO_APPEND	0x0002		/* append write to end */
#define	IO_NDELAY	0x0004		/* FNDELAY flag set in file table */
#define	IO_NODELOCKED	0x0008		/* underlying node already locked */
#define	IO_ASYNC	0x0010		/* bawrite rather then bdwrite */
#define	IO_VMIO		0x0020		/* data already in VMIO space */
#define	IO_INVAL	0x0040		/* invalidate after I/O */
#define	IO_SYNC		0x0080		/* do I/O synchronously */
#define	IO_DIRECT	0x0100		/* attempt to bypass buffer cache */
#define	IO_NOREUSE	0x0200		/* VMIO data won't be reused */
#define	IO_EXT		0x0400		/* operate on external attributes */
#define	IO_NORMAL	0x0800		/* operate on regular data */
#define	IO_NOMACCHECK	0x1000		/* MAC checks unnecessary */
#define	IO_BUFLOCKED	0x2000		/* ffs flag; indir buf is locked */
#define	IO_RANGELOCKED	0x4000		/* range locked */
#define	IO_DATASYNC	0x8000		/* do only data I/O synchronously */

#define IO_SEQMAX	0x7F		/* seq heuristic max value */
#define IO_SEQSHIFT	16		/* seq heuristic in upper 16 bits */

/*
 * Flags for accmode_t.
 */
#define	VEXEC			000000000100 /* execute/search permission */
#define	VWRITE			000000000200 /* write permission */
#define	VREAD			000000000400 /* read permission */
#define	VADMIN			000000010000 /* being the file owner */
#define	VAPPEND			000000040000 /* permission to write/append */
/*
 * VEXPLICIT_DENY makes VOP_ACCESSX(9) return EPERM or EACCES only
 * if permission was denied explicitly, by a "deny" rule in NFSv4 ACL,
 * and 0 otherwise.  This never happens with ordinary unix access rights
 * or POSIX.1e ACLs.  Obviously, VEXPLICIT_DENY must be OR-ed with
 * some other V* constant.
 */
#define	VEXPLICIT_DENY		000000100000
#define	VREAD_NAMED_ATTRS 	000000200000 /* not used */
#define	VWRITE_NAMED_ATTRS 	000000400000 /* not used */
#define	VDELETE_CHILD	 	000001000000
#define	VREAD_ATTRIBUTES 	000002000000 /* permission to stat(2) */
#define	VWRITE_ATTRIBUTES 	000004000000 /* change {m,c,a}time */
#define	VDELETE		 	000010000000
#define	VREAD_ACL	 	000020000000 /* read ACL and file mode */
#define	VWRITE_ACL	 	000040000000 /* change ACL and/or file mode */
#define	VWRITE_OWNER	 	000100000000 /* change file owner */
#define	VSYNCHRONIZE	 	000200000000 /* not used */
#define	VCREAT			000400000000 /* creating new file */
#define	VVERIFY			001000000000 /* verification required */

/*
 * Permissions that were traditionally granted only to the file owner.
 */
#define VADMIN_PERMS	(VADMIN | VWRITE_ATTRIBUTES | VWRITE_ACL | \
    VWRITE_OWNER)

/*
 * Permissions that were traditionally granted to everyone.
 */
#define VSTAT_PERMS	(VREAD_ATTRIBUTES | VREAD_ACL)

/*
 * Permissions that allow to change the state of the file in any way.
 */
#define VMODIFY_PERMS	(VWRITE | VAPPEND | VADMIN_PERMS | VDELETE_CHILD | \
    VDELETE)

/*
 * Token indicating no attribute value yet assigned.
 */
#define	VNOVAL	(-1)

/*
 * LK_TIMELOCK timeout for vnode locks (used mainly by the pageout daemon)
 */
#define VLKTIMEOUT	(hz / 20 + 1)

#ifdef _KERNEL

#ifdef MALLOC_DECLARE
MALLOC_DECLARE(M_VNODE);
#endif

extern u_int ncsizefactor;
extern const u_int io_hold_cnt;

/*
 * Convert between vnode types and inode formats (since POSIX.1
 * defines mode word of stat structure in terms of inode formats).
 */
extern __enum_uint8(vtype)	iftovt_tab[];
extern int		vttoif_tab[];
#define	IFTOVT(mode)	(iftovt_tab[((mode) & S_IFMT) >> 12])
#define	VTTOIF(indx)	(vttoif_tab[(int)(indx)])
#define	MAKEIMODE(indx, mode)	(int)(VTTOIF(indx) | (mode))

/*
 * Flags to various vnode functions.
 */
#define	SKIPSYSTEM	0x0001	/* vflush: skip vnodes marked VSYSTEM */
#define	FORCECLOSE	0x0002	/* vflush: force file closure */
#define	WRITECLOSE	0x0004	/* vflush: only close writable files */
#define	EARLYFLUSH	0x0008	/* vflush: early call for ffs_flushfiles */
#define	V_SAVE		0x0001	/* vinvalbuf: sync file first */
#define	V_ALT		0x0002	/* vinvalbuf: invalidate only alternate bufs */
#define	V_NORMAL	0x0004	/* vinvalbuf: invalidate only regular bufs */
#define	V_CLEANONLY	0x0008	/* vinvalbuf: invalidate only clean bufs */
#define	V_VMIO		0x0010	/* vinvalbuf: called during pageout */
#define	V_ALLOWCLEAN	0x0020	/* vinvalbuf: allow clean buffers after flush */
#define	REVOKEALL	0x0001	/* vop_revoke: revoke all aliases */
#define	V_WAIT		0x0001	/* vn_start_write: sleep for suspend */
#define	V_NOWAIT	0x0002	/* vn_start_write: don't sleep for suspend */
#define	V_XSLEEP	0x0004	/* vn_start_write: just return after sleep */
#define	V_PCATCH	0x0008	/* vn_start_write: make the sleep interruptible */
#define	V_VALID_FLAGS (V_WAIT | V_NOWAIT | V_XSLEEP | V_PCATCH)

#define	VR_START_WRITE	0x0001	/* vfs_write_resume: start write atomically */
#define	VR_NO_SUSPCLR	0x0002	/* vfs_write_resume: do not clear suspension */

#define	VS_SKIP_UNMOUNT	0x0001	/* vfs_write_suspend: fail if the
				   filesystem is being unmounted */

#define	VREF(vp)	vref(vp)

#ifdef DIAGNOSTIC
#define	VATTR_NULL(vap)	vattr_null(vap)
#else
#define	VATTR_NULL(vap)	(*(vap) = va_null)	/* initialize a vattr */
#endif /* DIAGNOSTIC */

#define	NULLVP	((struct vnode *)NULL)

/*
 * Global vnode data.
 */
extern	struct vnode *rootvnode;	/* root (i.e. "/") vnode */
extern	struct mount *rootdevmp;	/* "/dev" mount */
extern	u_long desiredvnodes;		/* number of vnodes desired */
extern	struct uma_zone *namei_zone;
extern	struct vattr va_null;		/* predefined null vattr structure */

extern	u_int vn_lock_pair_pause_max;

#define	VI_LOCK(vp)	mtx_lock(&(vp)->v_interlock)
#define	VI_LOCK_FLAGS(vp, flags) mtx_lock_flags(&(vp)->v_interlock, (flags))
#define	VI_TRYLOCK(vp)	mtx_trylock(&(vp)->v_interlock)
#define	VI_UNLOCK(vp)	mtx_unlock(&(vp)->v_interlock)
#define	VI_MTX(vp)	(&(vp)->v_interlock)

#define	VN_LOCK_AREC(vp)	lockallowrecurse((vp)->v_vnlock)
#define	VN_LOCK_ASHARE(vp)	lockallowshare((vp)->v_vnlock)
#define	VN_LOCK_DSHARE(vp)	lockdisableshare((vp)->v_vnlock)

#endif /* _KERNEL */

/*
 * Mods for extensibility.
 */

/*
 * Flags for vdesc_flags:
 */
#define	VDESC_MAX_VPS		16
/* Low order 16 flag bits are reserved for willrele flags for vp arguments. */
#define	VDESC_VP0_WILLRELE	0x0001
#define	VDESC_VP1_WILLRELE	0x0002
#define	VDESC_VP2_WILLRELE	0x0004
#define	VDESC_VP3_WILLRELE	0x0008

/*
 * A generic structure.
 * This can be used by bypass routines to identify generic arguments.
 */
struct vop_generic_args {
	struct vnodeop_desc *a_desc;
	/* other random data follows, presumably */
};

typedef int vop_bypass_t(struct vop_generic_args *);

/*
 * VDESC_NO_OFFSET is used to identify the end of the offset list
 * and in places where no such field exists.
 */
#define VDESC_NO_OFFSET -1

/*
 * This structure describes the vnode operation taking place.
 */
struct vnodeop_desc {
	char	*vdesc_name;		/* a readable name for debugging */
	int	 vdesc_flags;		/* VDESC_* flags */
	int	vdesc_vop_offset;
	vop_bypass_t	*vdesc_call;	/* Function to call */

	/*
	 * These ops are used by bypass routines to map and locate arguments.
	 * Creds and procs are not needed in bypass routines, but sometimes
	 * they are useful to (for example) transport layers.
	 * Nameidata is useful because it has a cred in it.
	 */
	int	*vdesc_vp_offsets;	/* list ended by VDESC_NO_OFFSET */
	int	vdesc_vpp_offset;	/* return vpp location */
	int	vdesc_cred_offset;	/* cred location, if any */
	int	vdesc_thread_offset;	/* thread location, if any */
	int	vdesc_componentname_offset; /* if any */
};

#ifdef _KERNEL
/*
 * A list of all the operation descs.
 */
extern struct vnodeop_desc *vnodeop_descs[];

#define	VOPARG_OFFSETOF(s_type, field)	__offsetof(s_type, field)
#define	VOPARG_OFFSETTO(s_type, s_offset, struct_p) \
    ((s_type)(((char*)(struct_p)) + (s_offset)))

#ifdef DEBUG_VFS_LOCKS
/*
 * Support code to aid in debugging VFS locking problems.  Not totally
 * reliable since if the thread sleeps between changing the lock
 * state and checking it with the assert, some other thread could
 * change the state.  They are good enough for debugging a single
 * filesystem using a single-threaded test.  Note that the unreliability is
 * limited to false negatives; efforts were made to ensure that false
 * positives cannot occur.
 */
void	assert_vi_locked(struct vnode *vp, const char *str);
void	assert_vi_unlocked(struct vnode *vp, const char *str);
void	assert_vop_elocked(struct vnode *vp, const char *str);
void	assert_vop_locked(struct vnode *vp, const char *str);
void	assert_vop_unlocked(struct vnode *vp, const char *str);

#define	ASSERT_VI_LOCKED(vp, str)	assert_vi_locked((vp), (str))
#define	ASSERT_VI_UNLOCKED(vp, str)	assert_vi_unlocked((vp), (str))
#define	ASSERT_VOP_ELOCKED(vp, str)	assert_vop_elocked((vp), (str))
#define	ASSERT_VOP_LOCKED(vp, str)	assert_vop_locked((vp), (str))
#define	ASSERT_VOP_UNLOCKED(vp, str)	assert_vop_unlocked((vp), (str))

#define ASSERT_VOP_IN_SEQC(vp)	do {				\
	struct vnode *_vp = (vp);				\
								\
	VNPASS(seqc_in_modify(_vp->v_seqc), _vp);		\
} while (0)

#define ASSERT_VOP_NOT_IN_SEQC(vp)	do {			\
	struct vnode *_vp = (vp);				\
								\
	VNPASS(!seqc_in_modify(_vp->v_seqc), _vp);		\
} while (0)

#else /* !DEBUG_VFS_LOCKS */

#define	ASSERT_VI_LOCKED(vp, str)	((void)0)
#define	ASSERT_VI_UNLOCKED(vp, str)	((void)0)
#define	ASSERT_VOP_ELOCKED(vp, str)	((void)0)
#define	ASSERT_VOP_LOCKED(vp, str)	((void)0)
#define	ASSERT_VOP_UNLOCKED(vp, str)	((void)0)

#define ASSERT_VOP_IN_SEQC(vp)		((void)0)
#define ASSERT_VOP_NOT_IN_SEQC(vp)	((void)0)

#endif /* DEBUG_VFS_LOCKS */

/*
 * This call works for vnodes in the kernel.
 */
#define VCALL(c) ((c)->a_desc->vdesc_call(c))

#define DOINGASYNC(vp)	   					\
	(((vp)->v_mount->mnt_kern_flag & MNTK_ASYNC) != 0 &&	\
	 ((curthread->td_pflags & TDP_SYNCIO) == 0))

/*
 * VMIO support inline
 */

extern int vmiodirenable;

static __inline int
vn_canvmio(struct vnode *vp)
{
      if (vp && (vp->v_type == VREG || (vmiodirenable && vp->v_type == VDIR)))
		return(TRUE);
	return(FALSE);
}

/*
 * Finally, include the default set of vnode operations.
 */
typedef void vop_getpages_iodone_t(void *, vm_page_t *, int, int);
#include "vnode_if.h"

/* vn_open_flags */
#define	VN_OPEN_NOAUDIT		0x00000001
#define	VN_OPEN_NOCAPCHECK	0x00000002
#define	VN_OPEN_NAMECACHE	0x00000004
#define	VN_OPEN_INVFS		0x00000008
#define	VN_OPEN_WANTIOCTLCAPS	0x00000010

/* copy_file_range kernel flags */
#define	COPY_FILE_RANGE_KFLAGS		0xff000000
#define	COPY_FILE_RANGE_TIMEO1SEC	0x01000000	/* Return after 1sec. */

/*
 * Public vnode manipulation functions.
 */
struct componentname;
struct file;
struct mount;
struct nameidata;
struct ostat;
struct freebsd11_stat;
struct thread;
struct proc;
struct stat;
struct nstat;
struct ucred;
struct uio;
struct vattr;
struct vfsops;
struct vnode;

typedef int (*vn_get_ino_t)(struct mount *, void *, int, struct vnode **);

int	bnoreuselist(struct bufv *bufv, struct bufobj *bo, daddr_t startn,
	    daddr_t endn);
/* cache_* may belong in namei.h. */
void	cache_changesize(u_long newhashsize);

#define	VFS_CACHE_DROPOLD	0x1

void	cache_enter_time_flags(struct vnode *dvp, struct vnode *vp,
	    struct componentname *cnp, struct timespec *tsp,
	    struct timespec *dtsp, int flags);
#define	cache_enter(dvp, vp, cnp)					\
	cache_enter_time(dvp, vp, cnp, NULL, NULL)
void	cache_enter_time(struct vnode *dvp, struct vnode *vp,
	    struct componentname *cnp, struct timespec *tsp,
	    struct timespec *dtsp);
int	cache_lookup(struct vnode *dvp, struct vnode **vpp,
	    struct componentname *cnp, struct timespec *tsp, int *ticksp);
void	cache_vnode_init(struct vnode *vp);
void	cache_purge(struct vnode *vp);
void	cache_purge_vgone(struct vnode *vp);
void	cache_purge_negative(struct vnode *vp);
void	cache_purgevfs(struct mount *mp);
char	*cache_symlink_alloc(size_t size, int flags);
void	cache_symlink_free(char *string, size_t size);
int	cache_symlink_resolve(struct cache_fpl *fpl, const char *string,
	    size_t len);
void	cache_vop_rename(struct vnode *fdvp, struct vnode *fvp, struct vnode *tdvp,
    struct vnode *tvp, struct componentname *fcnp, struct componentname *tcnp);
void	cache_vop_rmdir(struct vnode *dvp, struct vnode *vp);
void	cache_vop_vector_register(struct vop_vector *);
#ifdef INVARIANTS
void	cache_validate(struct vnode *dvp, struct vnode *vp,
	    struct componentname *cnp);
void	cache_validate_vop_vector(struct mount *mp, struct vop_vector *vops);
void	cache_assert_no_entries(struct vnode *vp);
#else
static inline void
cache_validate(struct vnode *dvp, struct vnode *vp, struct componentname *cnp)
{
}

static inline void
cache_validate_vop_vector(struct mount *mp, struct vop_vector *vops)
{
}

static inline void
cache_assert_no_entries(struct vnode *vp)
{
}
#endif
void	cache_fast_lookup_enabled_recalc(void);
int	change_dir(struct vnode *vp, struct thread *td);
void	cvtstat(struct stat *st, struct ostat *ost);
int	freebsd11_cvtnstat(struct stat *sb, struct nstat *nsb);
int	freebsd11_cvtstat(struct stat *st, struct freebsd11_stat *ost);
int	getnewvnode(const char *tag, struct mount *mp, struct vop_vector *vops,
	    struct vnode **vpp);
void	getnewvnode_reserve(void);
void	getnewvnode_drop_reserve(void);
int	insmntque(struct vnode *vp, struct mount *mp);
int	insmntque1(struct vnode *vp, struct mount *mp);
u_quad_t init_va_filerev(void);
int	speedup_syncer(void);
int	vn_vptocnp(struct vnode **vp, char *buf, size_t *buflen);
int	vn_getcwd(char *buf, char **retbuf, size_t *buflen);
int	vn_fullpath(struct vnode *vp, char **retbuf, char **freebuf);
int	vn_fullpath_global(struct vnode *vp, char **retbuf, char **freebuf);
int	vn_fullpath_hardlink(struct vnode *vp, struct vnode *dvp,
	    const char *hdrl_name, size_t hrdl_name_length, char **retbuf,
	    char **freebuf, size_t *buflen);
struct vnode *
	vn_dir_dd_ino(struct vnode *vp);
int	vn_commname(struct vnode *vn, char *buf, u_int buflen);
int	vn_path_to_global_path(struct thread *td, struct vnode *vp,
	    char *path, u_int pathlen);
int	vn_path_to_global_path_hardlink(struct thread *td, struct vnode *vp,
	    struct vnode *dvp, char *path, u_int pathlen, const char *leaf_name,
	    size_t leaf_length);
int	vaccess(__enum_uint8(vtype) type, mode_t file_mode, uid_t file_uid,
	    gid_t file_gid, accmode_t accmode, struct ucred *cred);
int	vaccess_vexec_smr(mode_t file_mode, uid_t file_uid, gid_t file_gid,
	    struct ucred *cred);
int	vaccess_acl_nfs4(__enum_uint8(vtype) type, uid_t file_uid, gid_t file_gid,
	    struct acl *aclp, accmode_t accmode, struct ucred *cred);
int	vaccess_acl_posix1e(__enum_uint8(vtype) type, uid_t file_uid,
	    gid_t file_gid, struct acl *acl, accmode_t accmode,
	    struct ucred *cred);
void	vattr_null(struct vattr *vap);
void	vlazy(struct vnode *);
void	vdrop(struct vnode *);
void	vdropl(struct vnode *);
int	vflush(struct mount *mp, int rootrefs, int flags, struct thread *td);
int	vget(struct vnode *vp, int flags);
enum vgetstate	vget_prep_smr(struct vnode *vp);
enum vgetstate	vget_prep(struct vnode *vp);
int	vget_finish(struct vnode *vp, int flags, enum vgetstate vs);
void	vget_finish_ref(struct vnode *vp, enum vgetstate vs);
void	vget_abort(struct vnode *vp, enum vgetstate vs);
void	vgone(struct vnode *vp);
void	vhold(struct vnode *);
void	vholdnz(struct vnode *);
bool	vhold_smr(struct vnode *);
int	vinactive(struct vnode *vp);
int	vinvalbuf(struct vnode *vp, int save, int slpflag, int slptimeo);
int	vtruncbuf(struct vnode *vp, off_t length, int blksize);
void	v_inval_buf_range(struct vnode *vp, daddr_t startlbn, daddr_t endlbn,
	    int blksize);
void	vunref(struct vnode *);
void	vn_printf(struct vnode *vp, const char *fmt, ...) __printflike(2,3);
int	vrecycle(struct vnode *vp);
int	vrecyclel(struct vnode *vp);
int	vn_bmap_seekhole_locked(struct vnode *vp, u_long cmd, off_t *off,
	    struct ucred *cred);
int	vn_bmap_seekhole(struct vnode *vp, u_long cmd, off_t *off,
	    struct ucred *cred);
int	vn_close(struct vnode *vp,
	    int flags, struct ucred *file_cred, struct thread *td);
int	vn_copy_file_range(struct vnode *invp, off_t *inoffp,
	    struct vnode *outvp, off_t *outoffp, size_t *lenp,
	    unsigned int flags, struct ucred *incred, struct ucred *outcred,
	    struct thread *fsize_td);
int	vn_deallocate(struct vnode *vp, off_t *offset, off_t *length, int flags,
	    int ioflg, struct ucred *active_cred, struct ucred *file_cred);
void	vn_finished_write(struct mount *mp);
void	vn_finished_secondary_write(struct mount *mp);
int	vn_fsync_buf(struct vnode *vp, int waitfor);
int	vn_generic_copy_file_range(struct vnode *invp, off_t *inoffp,
	    struct vnode *outvp, off_t *outoffp, size_t *lenp,
	    unsigned int flags, struct ucred *incred, struct ucred *outcred,
	    struct thread *fsize_td);
int	vn_need_pageq_flush(struct vnode *vp);
bool	vn_isdisk_error(struct vnode *vp, int *errp);
bool	vn_isdisk(struct vnode *vp);
int	_vn_lock(struct vnode *vp, int flags, const char *file, int line);
#define vn_lock(vp, flags) _vn_lock(vp, flags, __FILE__, __LINE__)
void	vn_lock_pair(struct vnode *vp1, bool vp1_locked, int lkflags1,
	    struct vnode *vp2, bool vp2_locked, int lkflags2);
int	vn_open(struct nameidata *ndp, int *flagp, int cmode, struct file *fp);
int	vn_open_cred(struct nameidata *ndp, int *flagp, int cmode,
	    u_int vn_open_flags, struct ucred *cred, struct file *fp);
int	vn_open_vnode(struct vnode *vp, int fmode, struct ucred *cred,
	    struct thread *td, struct file *fp);
void	vn_pages_remove(struct vnode *vp, vm_pindex_t start, vm_pindex_t end);
void	vn_pages_remove_valid(struct vnode *vp, vm_pindex_t start,
	    vm_pindex_t end);
int	vn_pollrecord(struct vnode *vp, struct thread *p, int events);
int	vn_rdwr(enum uio_rw rw, struct vnode *vp, void *base,
	    int len, off_t offset, enum uio_seg segflg, int ioflg,
	    struct ucred *active_cred, struct ucred *file_cred, ssize_t *aresid,
	    struct thread *td);
int	vn_rdwr_inchunks(enum uio_rw rw, struct vnode *vp, void *base,
	    size_t len, off_t offset, enum uio_seg segflg, int ioflg,
	    struct ucred *active_cred, struct ucred *file_cred, size_t *aresid,
	    struct thread *td);
int	vn_read_from_obj(struct vnode *vp, struct uio *uio);
int	vn_rlimit_fsize(const struct vnode *vp, const struct uio *uio,
	    struct thread *td);
int	vn_rlimit_fsizex(const struct vnode *vp, struct uio *uio,
	    off_t maxfsz, ssize_t *resid_adj, struct thread *td);
void	vn_rlimit_fsizex_res(struct uio *uio, ssize_t resid_adj);
int	vn_rlimit_trunc(u_quad_t size, struct thread *td);
int	vn_start_write(struct vnode *vp, struct mount **mpp, int flags);
int	vn_start_secondary_write(struct vnode *vp, struct mount **mpp,
	    int flags);
int	vn_truncate_locked(struct vnode *vp, off_t length, bool sync,
	    struct ucred *cred);
int	vn_writechk(struct vnode *vp);
int	vn_extattr_get(struct vnode *vp, int ioflg, int attrnamespace,
	    const char *attrname, int *buflen, char *buf, struct thread *td);
int	vn_extattr_set(struct vnode *vp, int ioflg, int attrnamespace,
	    const char *attrname, int buflen, char *buf, struct thread *td);
int	vn_extattr_rm(struct vnode *vp, int ioflg, int attrnamespace,
	    const char *attrname, struct thread *td);
int	vn_vget_ino(struct vnode *vp, ino_t ino, int lkflags,
	    struct vnode **rvp);
int	vn_vget_ino_gen(struct vnode *vp, vn_get_ino_t alloc,
	    void *alloc_arg, int lkflags, struct vnode **rvp);
int	vn_utimes_perm(struct vnode *vp, struct vattr *vap,
	    struct ucred *cred, struct thread *td);
int	vn_cmp(struct file *, struct file *, struct thread *td);

int	vn_io_fault_uiomove(char *data, int xfersize, struct uio *uio);
int	vn_io_fault_pgmove(vm_page_t ma[], vm_offset_t offset, int xfersize,
	    struct uio *uio);

void	vn_seqc_write_begin_locked(struct vnode *vp);
void	vn_seqc_write_begin(struct vnode *vp);
void	vn_seqc_write_end_locked(struct vnode *vp);
void	vn_seqc_write_end(struct vnode *vp);
#define	vn_seqc_read_any(vp)		seqc_read_any(&(vp)->v_seqc)
#define	vn_seqc_read_notmodify(vp)	seqc_read_notmodify(&(vp)->v_seqc)
#define	vn_seqc_consistent(vp, seq)	seqc_consistent(&(vp)->v_seqc, seq)

#define	vn_rangelock_unlock(vp, cookie)					\
	rangelock_unlock(&(vp)->v_rl, (cookie), VI_MTX(vp))
#define	vn_rangelock_unlock_range(vp, cookie, start, end)		\
	rangelock_unlock_range(&(vp)->v_rl, (cookie), (start), (end), 	\
	    VI_MTX(vp))
#define	vn_rangelock_rlock(vp, start, end)				\
	rangelock_rlock(&(vp)->v_rl, (start), (end), VI_MTX(vp))
#define	vn_rangelock_tryrlock(vp, start, end)				\
	rangelock_tryrlock(&(vp)->v_rl, (start), (end), VI_MTX(vp))
#define	vn_rangelock_wlock(vp, start, end)				\
	rangelock_wlock(&(vp)->v_rl, (start), (end), VI_MTX(vp))
#define	vn_rangelock_trywlock(vp, start, end)				\
	rangelock_trywlock(&(vp)->v_rl, (start), (end), VI_MTX(vp))

#define	vn_irflag_read(vp)	atomic_load_short(&(vp)->v_irflag)
void	vn_irflag_set_locked(struct vnode *vp, short toset);
void	vn_irflag_set(struct vnode *vp, short toset);
void	vn_irflag_set_cond_locked(struct vnode *vp, short toset);
void	vn_irflag_set_cond(struct vnode *vp, short toset);
void	vn_irflag_unset_locked(struct vnode *vp, short tounset);
void	vn_irflag_unset(struct vnode *vp, short tounset);

int	vfs_cache_lookup(struct vop_lookup_args *ap);
int	vfs_cache_root(struct mount *mp, int flags, struct vnode **vpp);
void	vfs_timestamp(struct timespec *);
void	vfs_write_resume(struct mount *mp, int flags);
int	vfs_write_suspend(struct mount *mp, int flags);
int	vfs_write_suspend_umnt(struct mount *mp);
struct vnode *vnlru_alloc_marker(void);
void	vnlru_free_marker(struct vnode *);
void	vnlru_free_vfsops(int, struct vfsops *, struct vnode *);
int	vop_stdbmap(struct vop_bmap_args *);
int	vop_stdfdatasync_buf(struct vop_fdatasync_args *);
int	vop_stdfsync(struct vop_fsync_args *);
int	vop_stdgetwritemount(struct vop_getwritemount_args *);
int	vop_stdgetpages(struct vop_getpages_args *);
int	vop_stdinactive(struct vop_inactive_args *);
int	vop_stdioctl(struct vop_ioctl_args *);
int	vop_stdneed_inactive(struct vop_need_inactive_args *);
int	vop_stdkqfilter(struct vop_kqfilter_args *);
int	vop_stdlock(struct vop_lock1_args *);
int	vop_stdunlock(struct vop_unlock_args *);
int	vop_stdislocked(struct vop_islocked_args *);
int	vop_lock(struct vop_lock1_args *);
int	vop_unlock(struct vop_unlock_args *);
int	vop_islocked(struct vop_islocked_args *);
int	vop_stdputpages(struct vop_putpages_args *);
int	vop_nopoll(struct vop_poll_args *);
int	vop_stdaccess(struct vop_access_args *ap);
int	vop_stdaccessx(struct vop_accessx_args *ap);
int	vop_stdadvise(struct vop_advise_args *ap);
int	vop_stdadvlock(struct vop_advlock_args *ap);
int	vop_stdadvlockasync(struct vop_advlockasync_args *ap);
int	vop_stdadvlockpurge(struct vop_advlockpurge_args *ap);
int	vop_stdallocate(struct vop_allocate_args *ap);
int	vop_stddeallocate(struct vop_deallocate_args *ap);
int	vop_stdset_text(struct vop_set_text_args *ap);
int	vop_stdpathconf(struct vop_pathconf_args *);
int	vop_stdpoll(struct vop_poll_args *);
int	vop_stdvptocnp(struct vop_vptocnp_args *ap);
int	vop_stdvptofh(struct vop_vptofh_args *ap);
int	vop_stdunp_bind(struct vop_unp_bind_args *ap);
int	vop_stdunp_connect(struct vop_unp_connect_args *ap);
int	vop_stdunp_detach(struct vop_unp_detach_args *ap);
int	vop_stdadd_writecount_nomsync(struct vop_add_writecount_args *ap);
int	vop_eopnotsupp(struct vop_generic_args *ap);
int	vop_ebadf(struct vop_generic_args *ap);
int	vop_einval(struct vop_generic_args *ap);
int	vop_enoent(struct vop_generic_args *ap);
int	vop_enotty(struct vop_generic_args *ap);
int	vop_eagain(struct vop_generic_args *ap);
int	vop_null(struct vop_generic_args *ap);
int	vop_panic(struct vop_generic_args *ap);
int	dead_poll(struct vop_poll_args *ap);
int	dead_read(struct vop_read_args *ap);
int	dead_write(struct vop_write_args *ap);

/* These are called from within the actual VOPS. */
void	vop_close_post(void *a, int rc);
void	vop_create_pre(void *a);
void	vop_create_post(void *a, int rc);
void	vop_whiteout_pre(void *a);
void	vop_whiteout_post(void *a, int rc);
void	vop_deleteextattr_pre(void *a);
void	vop_deleteextattr_post(void *a, int rc);
void	vop_link_pre(void *a);
void	vop_link_post(void *a, int rc);
void	vop_lookup_post(void *a, int rc);
void	vop_lookup_pre(void *a);
void	vop_mkdir_pre(void *a);
void	vop_mkdir_post(void *a, int rc);
void	vop_mknod_pre(void *a);
void	vop_mknod_post(void *a, int rc);
void	vop_open_post(void *a, int rc);
void	vop_read_post(void *a, int rc);
void	vop_read_pgcache_post(void *ap, int rc);
void	vop_readdir_post(void *a, int rc);
void	vop_reclaim_post(void *a, int rc);
void	vop_remove_pre(void *a);
void	vop_remove_post(void *a, int rc);
void	vop_rename_post(void *a, int rc);
void	vop_rename_pre(void *a);
void	vop_rmdir_pre(void *a);
void	vop_rmdir_post(void *a, int rc);
void	vop_setattr_pre(void *a);
void	vop_setattr_post(void *a, int rc);
void	vop_setacl_pre(void *a);
void	vop_setacl_post(void *a, int rc);
void	vop_setextattr_pre(void *a);
void	vop_setextattr_post(void *a, int rc);
void	vop_symlink_pre(void *a);
void	vop_symlink_post(void *a, int rc);
int	vop_sigdefer(struct vop_vector *vop, struct vop_generic_args *a);

#ifdef DEBUG_VFS_LOCKS
void	vop_fdatasync_debugpre(void *a);
void	vop_fdatasync_debugpost(void *a, int rc);
void	vop_fplookup_vexec_debugpre(void *a);
void	vop_fplookup_vexec_debugpost(void *a, int rc);
void	vop_fplookup_symlink_debugpre(void *a);
void	vop_fplookup_symlink_debugpost(void *a, int rc);
void	vop_fsync_debugpre(void *a);
void	vop_fsync_debugpost(void *a, int rc);
void	vop_strategy_debugpre(void *a);
void	vop_lock_debugpre(void *a);
void	vop_lock_debugpost(void *a, int rc);
void	vop_unlock_debugpre(void *a);
void	vop_need_inactive_debugpre(void *a);
void	vop_need_inactive_debugpost(void *a, int rc);
void	vop_mkdir_debugpost(void *a, int rc);
#else
#define	vop_fdatasync_debugpre(x)		do { } while (0)
#define	vop_fdatasync_debugpost(x, y)		do { } while (0)
#define	vop_fplookup_vexec_debugpre(x)		do { } while (0)
#define	vop_fplookup_vexec_debugpost(x, y)	do { } while (0)
#define	vop_fplookup_symlink_debugpre(x)	do { } while (0)
#define	vop_fplookup_symlink_debugpost(x, y)	do { } while (0)
#define	vop_fsync_debugpre(x)			do { } while (0)
#define	vop_fsync_debugpost(x, y)		do { } while (0)
#define	vop_strategy_debugpre(x)		do { } while (0)
#define	vop_lock_debugpre(x)			do { } while (0)
#define	vop_lock_debugpost(x, y)		do { } while (0)
#define	vop_unlock_debugpre(x)			do { } while (0)
#define	vop_need_inactive_debugpre(x)		do { } while (0)
#define	vop_need_inactive_debugpost(x, y)	do { } while (0)
#define	vop_mkdir_debugpost(x, y)		do { } while (0)
#endif

void	vop_rename_fail(struct vop_rename_args *ap);

#define	vop_stat_helper_pre(ap)	({						\
	struct vop_stat_args *_ap = (ap);					\
	int _error;								\
	AUDIT_ARG_VNODE1(ap->a_vp);						\
	_error = mac_vnode_check_stat(_ap->a_active_cred, _ap->a_file_cred, _ap->a_vp);\
	if (__predict_true(_error == 0)) {					\
		ap->a_sb->st_padding0 = 0;					\
		ap->a_sb->st_padding1 = 0;					\
		bzero(_ap->a_sb->st_spare, sizeof(_ap->a_sb->st_spare));	\
	}									\
	_error;									\
})

#define	vop_stat_helper_post(ap, error)	({					\
	struct vop_stat_args *_ap = (ap);					\
	int _error = (error);							\
	if (priv_check_cred_vfs_generation(_ap->a_active_cred))			\
		_ap->a_sb->st_gen = 0;						\
	_error;									\
})

#define	VOP_WRITE_PRE(ap)						\
	struct vattr va;						\
	int error;							\
	off_t osize, ooffset, noffset;					\
									\
	osize = ooffset = noffset = 0;					\
	if (!VN_KNLIST_EMPTY((ap)->a_vp)) {				\
		error = VOP_GETATTR((ap)->a_vp, &va, (ap)->a_cred);	\
		if (error)						\
			return (error);					\
		ooffset = (ap)->a_uio->uio_offset;			\
		osize = (off_t)va.va_size;				\
	}

#define VOP_WRITE_POST(ap, ret)						\
	noffset = (ap)->a_uio->uio_offset;				\
	if (noffset > ooffset && !VN_KNLIST_EMPTY((ap)->a_vp)) {	\
		VFS_KNOTE_LOCKED((ap)->a_vp, NOTE_WRITE			\
		    | (noffset > osize ? NOTE_EXTEND : 0));		\
	}

#define VOP_LOCK(vp, flags) VOP_LOCK1(vp, flags, __FILE__, __LINE__)

#ifdef INVARIANTS
#define	VOP_ADD_WRITECOUNT_CHECKED(vp, cnt)				\
do {									\
	int error_;							\
									\
	error_ = VOP_ADD_WRITECOUNT((vp), (cnt));			\
	VNASSERT(error_ == 0, (vp), ("VOP_ADD_WRITECOUNT returned %d",	\
	    error_));							\
} while (0)
#define	VOP_SET_TEXT_CHECKED(vp)					\
do {									\
	int error_;							\
									\
	error_ = VOP_SET_TEXT((vp));					\
	VNASSERT(error_ == 0, (vp), ("VOP_SET_TEXT returned %d",	\
	    error_));							\
} while (0)
#define	VOP_UNSET_TEXT_CHECKED(vp)					\
do {									\
	int error_;							\
									\
	error_ = VOP_UNSET_TEXT((vp));					\
	VNASSERT(error_ == 0, (vp), ("VOP_UNSET_TEXT returned %d",	\
	    error_));							\
} while (0)
#else
#define	VOP_ADD_WRITECOUNT_CHECKED(vp, cnt)	VOP_ADD_WRITECOUNT((vp), (cnt))
#define	VOP_SET_TEXT_CHECKED(vp)		VOP_SET_TEXT((vp))
#define	VOP_UNSET_TEXT_CHECKED(vp)		VOP_UNSET_TEXT((vp))
#endif

#define	VN_IS_DOOMED(vp)	__predict_false((vn_irflag_read(vp) & VIRF_DOOMED) != 0)

void	vput(struct vnode *vp);
void	vrele(struct vnode *vp);
void	vref(struct vnode *vp);
void	vrefact(struct vnode *vp);
void 	v_addpollinfo(struct vnode *vp);
static __inline int
vrefcnt(struct vnode *vp)
{

	return (vp->v_usecount);
}

#define	vholdl(vp)	do {						\
	ASSERT_VI_LOCKED(vp, __func__);					\
	vhold(vp);							\
} while (0)

#define	vrefl(vp)	do {						\
	ASSERT_VI_LOCKED(vp, __func__);					\
	vref(vp);							\
} while (0)

int vnode_create_vobject(struct vnode *vp, off_t size, struct thread *td);
void vnode_destroy_vobject(struct vnode *vp);

extern struct vop_vector fifo_specops;
extern struct vop_vector dead_vnodeops;
extern struct vop_vector default_vnodeops;

#define VOP_PANIC	((void*)(uintptr_t)vop_panic)
#define VOP_NULL	((void*)(uintptr_t)vop_null)
#define VOP_EBADF	((void*)(uintptr_t)vop_ebadf)
#define VOP_ENOTTY	((void*)(uintptr_t)vop_enotty)
#define VOP_EINVAL	((void*)(uintptr_t)vop_einval)
#define VOP_ENOENT	((void*)(uintptr_t)vop_enoent)
#define VOP_EOPNOTSUPP	((void*)(uintptr_t)vop_eopnotsupp)
#define VOP_EAGAIN	((void*)(uintptr_t)vop_eagain)

/* fifo_vnops.c */
int	fifo_printinfo(struct vnode *);

/* vfs_hash.c */
typedef int vfs_hash_cmp_t(struct vnode *vp, void *arg);

void vfs_hash_changesize(u_long newhashsize);
int vfs_hash_get(const struct mount *mp, u_int hash, int flags,
    struct thread *td, struct vnode **vpp, vfs_hash_cmp_t *fn, void *arg);
u_int vfs_hash_index(struct vnode *vp);
int vfs_hash_insert(struct vnode *vp, u_int hash, int flags, struct thread *td,
    struct vnode **vpp, vfs_hash_cmp_t *fn, void *arg);
void vfs_hash_ref(const struct mount *mp, u_int hash, struct thread *td,
    struct vnode **vpp, vfs_hash_cmp_t *fn, void *arg);
void vfs_hash_rehash(struct vnode *vp, u_int hash);
void vfs_hash_remove(struct vnode *vp);

int vfs_kqfilter(struct vop_kqfilter_args *);
struct dirent;
int vn_dir_next_dirent(struct vnode *vp, struct thread *td,
    char *dirbuf, size_t dirbuflen,
    struct dirent **dpp, size_t *len, off_t *off, int *eofflag);
int vn_dir_check_empty(struct vnode *vp);
int vfs_read_dirent(struct vop_readdir_args *ap, struct dirent *dp, off_t off);

int vfs_unixify_accmode(accmode_t *accmode);

void vfs_unp_reclaim(struct vnode *vp);

int setfmode(struct thread *td, struct ucred *cred, struct vnode *vp, int mode);
int setfown(struct thread *td, struct ucred *cred, struct vnode *vp, uid_t uid,
    gid_t gid);
int vn_chmod(struct file *fp, mode_t mode, struct ucred *active_cred,
    struct thread *td);
int vn_chown(struct file *fp, uid_t uid, gid_t gid, struct ucred *active_cred,
    struct thread *td);
int vn_getsize_locked(struct vnode *vp, off_t *size, struct ucred *active_cred);
int vn_getsize(struct vnode *vp, off_t *size, struct ucred *active_cred);

void vn_fsid(struct vnode *vp, struct vattr *va);

int vn_dir_check_exec(struct vnode *vp, struct componentname *cnp);
int vn_lktype_write(struct mount *mp, struct vnode *vp);

#ifdef INVARIANTS
void vn_set_state_validate(struct vnode *vp, __enum_uint8(vstate) state);
#endif

static inline void
vn_set_state(struct vnode *vp, __enum_uint8(vstate) state)
{
#ifdef INVARIANTS
	vn_set_state_validate(vp, state);
#endif
	vp->v_state = state;
}

static inline __enum_uint8(vstate)
vn_get_state(struct vnode *vp)
{
	return (vp->v_state);
}

#define VOP_UNLOCK_FLAGS(vp, flags)	({				\
	struct vnode *_vp = (vp);					\
	int _flags = (flags);						\
	int _error;							\
									\
        if ((_flags & ~(LK_INTERLOCK | LK_RELEASE)) != 0)		\
                panic("%s: unsupported flags %x\n", __func__, flags);	\
        _error = VOP_UNLOCK(_vp);					\
        if (_flags & LK_INTERLOCK)					\
                VI_UNLOCK(_vp);						\
        _error;								\
})

#include <sys/kernel.h>

#define VFS_VOP_VECTOR_REGISTER(vnodeops) \
	SYSINIT(vfs_vector_##vnodeops##_f, SI_SUB_VFS, SI_ORDER_ANY, \
	    vfs_vector_op_register, &vnodeops)

#define VFS_SMR_DECLARE				\
	extern smr_t vfs_smr

#define VFS_SMR()	vfs_smr
#define vfs_smr_enter()	smr_enter(VFS_SMR())
#define vfs_smr_exit()	smr_exit(VFS_SMR())
#define vfs_smr_synchronize()	smr_synchronize(VFS_SMR())
#define vfs_smr_entered_load(ptr)	smr_entered_load((ptr), VFS_SMR())
#define VFS_SMR_ASSERT_ENTERED()	SMR_ASSERT_ENTERED(VFS_SMR())
#define VFS_SMR_ASSERT_NOT_ENTERED()	SMR_ASSERT_NOT_ENTERED(VFS_SMR())
#define VFS_SMR_ZONE_SET(zone)	uma_zone_set_smr((zone), VFS_SMR())

#define vn_load_v_data_smr(vp)	({		\
	struct vnode *_vp = (vp);		\
						\
	VFS_SMR_ASSERT_ENTERED();		\
	atomic_load_consume_ptr(&(_vp)->v_data);\
})

#endif /* _KERNEL */

#endif /* !_SYS_VNODE_H_ */