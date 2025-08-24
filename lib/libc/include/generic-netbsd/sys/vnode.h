/*	$NetBSD: vnode.h,v 1.304 2022/10/26 23:40:30 riastradh Exp $	*/

/*-
 * Copyright (c) 2008, 2020 The NetBSD Foundation, Inc.
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

/*
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
 *	@(#)vnode.h	8.17 (Berkeley) 5/20/95
 */

#ifndef _SYS_VNODE_H_
#define	_SYS_VNODE_H_

#include <sys/event.h>
#include <sys/queue.h>
#include <sys/condvar.h>
#include <sys/rwlock.h>
#include <sys/mutex.h>
#include <sys/time.h>
#include <sys/acl.h>

/* XXX: clean up includes later */
#include <uvm/uvm_param.h>	/* XXX */
#if defined(_KERNEL) || defined(_KMEMUSER)
#include <uvm/uvm_pglist.h>	/* XXX */
#include <uvm/uvm_object.h>	/* XXX */
#include <uvm/uvm_extern.h>	/* XXX */

struct uvm_ractx;
#endif

/*
 * The vnode is the focus of all file activity in UNIX.  There is a
 * unique vnode allocated for each active file, each current directory,
 * each mounted-on file, text file, and the root.
 */

/*
 * Vnode types.  VNON means no type.
 */
enum vtype	{ VNON, VREG, VDIR, VBLK, VCHR, VLNK, VSOCK, VFIFO, VBAD };

#define	VNODE_TYPES \
    "VNON", "VREG", "VDIR", "VBLK", "VCHR", "VLNK", "VSOCK", "VFIFO", "VBAD"

/*
 * Vnode tag types.
 * These are for the benefit of external programs only (e.g., pstat)
 * and should NEVER be inspected by the kernel.
 */
enum vtagtype	{
	VT_NON, VT_UFS, VT_NFS, VT_MFS, VT_MSDOSFS, VT_LFS, VT_LOFS,
	VT_FDESC, VT_PORTAL, VT_NULL, VT_UMAP, VT_KERNFS, VT_PROCFS,
	VT_AFS, VT_ISOFS, VT_UNION, VT_ADOSFS, VT_EXT2FS, VT_CODA,
	VT_FILECORE, VT_NTFS, VT_VFS, VT_OVERLAY, VT_SMBFS, VT_PTYFS,
	VT_TMPFS, VT_UDF, VT_SYSVBFS, VT_PUFFS, VT_HFS, VT_EFS, VT_ZFS,
	VT_RUMP, VT_NILFS, VT_V7FS, VT_CHFS, VT_AUTOFS
};

#define	VNODE_TAGS \
    "VT_NON", "VT_UFS", "VT_NFS", "VT_MFS", "VT_MSDOSFS", "VT_LFS", "VT_LOFS", \
    "VT_FDESC", "VT_PORTAL", "VT_NULL", "VT_UMAP", "VT_KERNFS", "VT_PROCFS", \
    "VT_AFS", "VT_ISOFS", "VT_UNION", "VT_ADOSFS", "VT_EXT2FS", "VT_CODA", \
    "VT_FILECORE", "VT_NTFS", "VT_VFS", "VT_OVERLAY", "VT_SMBFS", "VT_PTYFS", \
    "VT_TMPFS", "VT_UDF", "VT_SYSVBFS", "VT_PUFFS", "VT_HFS", "VT_EFS", \
    "VT_ZFS", "VT_RUMP", "VT_NILFS", "VT_V7FS", "VT_CHFS", "VT_AUTOFS"

#if defined(_KERNEL) || defined(_KMEMUSER)
struct vnode;
struct buf;

LIST_HEAD(buflists, buf);

/*
 * Reading or writing any of these items requires holding the appropriate
 * lock.  Field markings and the corresponding locks:
 *
 *	-	stable, reference to the vnode is required
 *	b	bufcache_lock
 *	e	exec_lock
 *	f	vnode_free_list_lock, or vrele_lock for vrele_list
 *	i	v_interlock
 *	i+b	v_interlock + bufcache_lock to modify, either to inspect
 *	i+u	v_interlock + v_uobj.vmobjlock to modify, either to inspect
 *	k	locked by underlying filesystem (maybe kernel_lock)
 *	u	v_uobj.vmobjlock
 *	v	vnode lock
 *
 * Each underlying filesystem allocates its own private area and hangs
 * it from v_data.
 */
struct vnode {
	/*
	 * VM system related items.
	 */
	struct uvm_object v_uobj;		/* u   the VM object */
	voff_t		v_size;			/* i+u size of file */
	voff_t		v_writesize;		/* i+u new size after write */

	/*
	 * Unstable items get their own cache line.
	 * On _LP64 this fills the space nicely.
	 */
	kcondvar_t	v_cv			/* i   synchronization */
	    __aligned(COHERENCY_UNIT);
	int		v_iflag;		/* i+u VI_* flags */
	int		v_uflag;		/* k   VU_* flags */
	int		v_usecount;		/* i   reference count */
	int		v_numoutput;		/* i   # of pending writes */
	int		v_writecount;		/* i   ref count of writers */
	int		v_holdcnt;		/* i   page & buffer refs */
	struct buflists	v_cleanblkhd;		/* i+b clean blocklist head */
	struct buflists	v_dirtyblkhd;		/* i+b dirty blocklist head */

	/*
	 * The remaining items are largely stable.
	 */
	int		v_vflag			/* v   VV_* flags */
	    __aligned(COHERENCY_UNIT);
	kmutex_t	*v_interlock;		/* -   vnode interlock */
	struct mount	*v_mount;		/* v   ptr to vfs we are in */
	int		(**v_op)(void *);	/* :   vnode operations vector */
	union {
		struct mount	*vu_mountedhere;/* v   ptr to vfs (VDIR) */
		struct socket	*vu_socket;	/* v   unix ipc (VSOCK) */
		struct specnode	*vu_specnode;	/* v   device (VCHR, VBLK) */
		struct fifoinfo	*vu_fifoinfo;	/* v   fifo (VFIFO) */
		struct uvm_ractx *vu_ractx;	/* u   read-ahead ctx (VREG) */
	} v_un;
	enum vtype	v_type;			/* -   vnode type */
	enum vtagtype	v_tag;			/* -   type of underlying data */
	void 		*v_data;		/* -   private data for fs */
	struct vnode_klist *v_klist;		/* i   kevent / knote info */

	void		*v_segvguard;		/* e   for PAX_SEGVGUARD */
};
#define	v_mountedhere	v_un.vu_mountedhere
#define	v_socket	v_un.vu_socket
#define	v_specnode	v_un.vu_specnode
#define	v_fifoinfo	v_un.vu_fifoinfo
#define	v_ractx		v_un.vu_ractx

typedef struct vnode vnode_t;

/*
 * Structure that encompasses the kevent state for a vnode.  This is
 * carved out as a separate structure because some vnodes may share
 * this state with one another.
 *
 * N.B. if two vnodes share a vnode_klist, then they must also share
 * v_interlock.
 */
struct vnode_klist {
	struct klist	vk_klist;	/* i   notes attached to vnode */
	long		vk_interest;	/* i   what the notes are interested in */
};
#endif

/*
 * Vnode flags.  The first set are locked by vnode lock or are stable.
 * VSYSTEM is only used to skip vflush()ing quota files.  VISTTY is used
 * when reading dead vnodes.
 */
#define	VV_ROOT		0x00000001	/* root of its file system */
#define	VV_SYSTEM	0x00000002	/* vnode being used by kernel */
#define	VV_ISTTY	0x00000004	/* vnode represents a tty */
#define	VV_MAPPED	0x00000008	/* vnode might have user mappings */
#define	VV_MPSAFE	0x00000010	/* file system code is MP safe */

/*
 * The second set are locked by vp->v_interlock.  VI_TEXT and VI_EXECMAP are
 * typically updated with vp->v_uobj.vmobjlock also held as the VM system
 * uses them for accounting purposes.
 */
#define	VI_TEXT		0x00000100	/* vnode is a pure text prototype */
#define	VI_EXECMAP	0x00000200	/* might have PROT_EXEC mappings */
#define	VI_WRMAP	0x00000400	/* might have PROT_WRITE u. mappings */
#define	VI_PAGES	0x00000800	/* UVM object has >0 pages */
#define	VI_ONWORKLST	0x00004000	/* On syncer work-list */
#define	VI_DEADCHECK	0x00008000	/* UVM: need to call vdead_check() */

/*
 * The third set are locked by the underlying file system.
 */
#define	VU_DIROP	0x01000000	/* LFS: involved in a directory op */

#define	VNODE_FLAGBITS \
    "\20\1ROOT\2SYSTEM\3ISTTY\4MAPPED\5MPSAFE\11TEXT\12EXECMAP" \
    "\13WRMAP\14PAGES\17ONWORKLST\20DEADCHECK\31DIROP"

#define	VSIZENOTSET	((voff_t)-1)

/*
 * vnode lock flags
 */
#define	LK_NONE		0x00000000	/* no lock - for VOP_ISLOCKED() */
#define	LK_SHARED	0x00000001	/* shared lock */
#define	LK_EXCLUSIVE	0x00000002	/* exclusive lock */
#define	LK_UPGRADE	0x00000010	/* upgrade shared -> exclusive */
#define	LK_DOWNGRADE	0x00000020	/* downgrade exclusive -> shared */
#define	LK_NOWAIT	0x00000100	/* do not sleep to await lock */
#define	LK_RETRY	0x00000200	/* vn_lock: retry until locked */

/*
 * Vnode attributes.  A field value of VNOVAL represents a field whose value
 * is unavailable (getattr) or which is not to be changed (setattr).
 */
struct vattr {
	enum vtype	va_type;	/* vnode type (for create) */
	mode_t		va_mode;	/* files access mode and type */
	nlink_t		va_nlink;	/* number of references to file */
	uid_t		va_uid;		/* owner user id */
	gid_t		va_gid;		/* owner group id */
	dev_t		va_fsid;	/* file system id (dev for now) */
	ino_t		va_fileid;	/* file id */
	u_quad_t	va_size;	/* file size in bytes */
	long		va_blocksize;	/* blocksize preferred for i/o */
	struct timespec	va_atime;	/* time of last access */
	struct timespec	va_mtime;	/* time of last modification */
	struct timespec	va_ctime;	/* time file changed */
	struct timespec va_birthtime;	/* time file created */
	u_long		va_gen;		/* generation number of file */
	u_long		va_flags;	/* flags defined for file */
	dev_t		va_rdev;	/* device the special file represents */
	u_quad_t	va_bytes;	/* bytes of disk space held by file */
	u_quad_t	va_filerev;	/* file modification number */
	unsigned int	va_vaflags;	/* operations flags, see below */
	long		va_spare;	/* remain quad aligned */
};

/*
 * Flags for va_vaflags.
 */
#define	VA_UTIMES_NULL	0x01		/* utimes argument was NULL */
#define	VA_EXCLUSIVE	0x02		/* exclusive create request */

#ifdef _KERNEL

/*
 * Flags for ioflag.
 */
#define	IO_UNIT		0x00010		/* do I/O as atomic unit */
#define	IO_APPEND	0x00020		/* append write to end */
#define	IO_SYNC		(0x40|IO_DSYNC)	/* sync I/O file integrity completion */
#define	IO_NODELOCKED	0x00080		/* underlying node already locked */
#define	IO_NDELAY	0x00100		/* FNDELAY flag set in file table */
#define	IO_DSYNC	0x00200		/* sync I/O data integrity completion */
#define	IO_ALTSEMANTICS	0x00400		/* use alternate i/o semantics */
#define	IO_NORMAL	0x00800		/* operate on regular data */
#define	IO_EXT		0x01000		/* operate on extended attributes */
#define	IO_DIRECT	0x02000		/* direct I/O hint */
#define	IO_JOURNALLOCKED 0x04000	/* journal is already locked */
#define	IO_ADV_MASK	0x00003		/* access pattern hint */

#define	IO_ADV_SHIFT	0
#define	IO_ADV_ENCODE(adv)	(((adv) << IO_ADV_SHIFT) & IO_ADV_MASK)
#define	IO_ADV_DECODE(ioflag)	(((ioflag) & IO_ADV_MASK) >> IO_ADV_SHIFT)

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

#define __VNODE_PERM_BITS	\
	"\10"			\
	"\07VEXEC"		\
	"\10VWRITE"		\
	"\11VREAD"		\
	"\15VADMIN"		\
	"\17VAPPEND"		\
	"\20VEXPLICIT_DENY"	\
	"\21VREAD_NAMED_ATTRS"	\
	"\22VWRITE_NAMED_ATTRS"	\
	"\23VDELETE_CHILD"	\
	"\24VREAD_ATTRIBUTES"	\
	"\25VWRITE_ATTRIBUTES"	\
	"\26VDELETE"		\
	"\27VREAD_ACL"		\
	"\30VWRITE_ACL"		\
	"\31VWRITE_OWNER"	\
	"\32VSYNCHRONIZE"	\
	"\33VCREAT"		\
	"\34VVERIFY"

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
#define VNOVALSIZE ((u_quad_t)-1)
#define VNOVALFLAGS ((u_long)-1)

/*
 * Convert between vnode types and inode formats (since POSIX.1
 * defines mode word of stat structure in terms of inode formats).
 */
extern const enum vtype	iftovt_tab[];
extern const int	vttoif_tab[];
#define	IFTOVT(mode)	(iftovt_tab[((mode) & S_IFMT) >> 12])
#define	VTTOIF(indx)	(vttoif_tab[(int)(indx)])
#define	MAKEIMODE(indx, mode)	(int)(VTTOIF(indx) | (mode))

/*
 * Flags to various vnode functions.
 */
#define	SKIPSYSTEM	0x0001		/* vflush: skip vnodes marked VSYSTEM */
#define	FORCECLOSE	0x0002		/* vflush: force file closeure */
#define	WRITECLOSE	0x0004		/* vflush: only close writable files */
#define	V_SAVE		0x0001		/* vinvalbuf: sync file first */

/*
 * Flags to various vnode operations.
 */
#define	REVOKEALL	0x0001		/* revoke: revoke all aliases */

#define	FSYNC_WAIT	0x0001		/* fsync: wait for completion */
#define	FSYNC_DATAONLY	0x0002		/* fsync: hint: sync file data only */
#define	FSYNC_RECLAIM	0x0004		/* fsync: hint: vnode is being reclaimed */
#define	FSYNC_LAZY	0x0008		/* fsync: lazy sync (trickle) */
#define	FSYNC_NOLOG	0x0010		/* fsync: do not flush the log */
#define	FSYNC_CACHE	0x0100		/* fsync: flush disk caches too */

#define	UPDATE_WAIT	0x0001		/* update: wait for completion */
#define	UPDATE_DIROP	0x0002		/* update: hint to fs to wait or not */
#define	UPDATE_CLOSE	0x0004		/* update: clean up on close */

#define VDEAD_NOWAIT	0x0001		/* vdead_check: do not sleep */

void holdrelel(struct vnode *);
void holdrele(struct vnode *);
void vholdl(struct vnode *);
void vhold(struct vnode *);
void vref(struct vnode *);

#define	NULLVP	((struct vnode *)NULL)

/*
 * Macro to determine kevent interest on a vnode.
 */
#define	_VN_KEVENT_INTEREST(vp, n)					\
	(((vp)->v_klist->vk_interest & (n)) != 0)

static inline bool
VN_KEVENT_INTEREST(struct vnode *vp, long hint)
{
	mutex_enter(vp->v_interlock);
	bool rv = _VN_KEVENT_INTEREST(vp, hint);
	mutex_exit(vp->v_interlock);
	return rv;
}

static inline void
VN_KNOTE(struct vnode *vp, long hint)
{
	mutex_enter(vp->v_interlock);
	if (__predict_false(_VN_KEVENT_INTEREST(vp, hint))) {
		knote(&vp->v_klist->vk_klist, hint);
	}
	mutex_exit(vp->v_interlock);
}

void	vn_knote_attach(struct vnode *, struct knote *);
void	vn_knote_detach(struct vnode *, struct knote *);

/*
 * Global vnode data.
 */
extern struct vnode	*rootvnode;	/* root (i.e. "/") vnode */
extern int		desiredvnodes;	/* number of vnodes desired */
extern unsigned int	numvnodes;	/* current number of vnodes */

#endif /* _KERNEL */


/*
 * Mods for exensibility.
 */

/*
 * Flags for vdesc_flags:
 */
#define	VDESC_MAX_VPS		8
/* Low order 16 flag bits are reserved for willrele flags for vp arguments. */
#define	VDESC_VP0_WILLRELE	0x00000001
#define	VDESC_VP1_WILLRELE	0x00000002
#define	VDESC_VP2_WILLRELE	0x00000004
#define	VDESC_VP3_WILLRELE	0x00000008
#define	VDESC_VP0_WILLPUT	0x00000101
#define	VDESC_VP1_WILLPUT	0x00000202
#define	VDESC_VP2_WILLPUT	0x00000404
#define	VDESC_VP3_WILLPUT	0x00000808

/*
 * VDESC_NO_OFFSET is used to identify the end of the offset list
 * and in places where no such field exists.
 */
#define	VDESC_NO_OFFSET -1

/*
 * This structure describes the vnode operation taking place.
 */
struct vnodeop_desc {
	int		vdesc_offset;	/* offset in vector--first for speed */
	const char	*vdesc_name;	/* a readable name for debugging */
	int		vdesc_flags;	/* VDESC_* flags */

	/*
	 * These ops are used by bypass routines to map and locate arguments.
	 * Creds and procs are not needed in bypass routines, but sometimes
	 * they are useful to (for example) transport layers.
	 * Nameidata is useful because it has a cred in it.
	 */
	const int	*vdesc_vp_offsets;	/* list ended by VDESC_NO_OFFSET */
	int		vdesc_vpp_offset;	/* return vpp location */
	int		vdesc_cred_offset;	/* cred location, if any */
	int		vdesc_componentname_offset; /* if any */
};

#ifdef _KERNEL

extern const struct vnodeop_desc * const vfs_op_descs[];

/*
 * Union filesystem hook for vn_readdir().
 */
extern int (*vn_union_readdir_hook) (struct vnode **, struct file *, struct lwp *);

/*
 * Macros for offsets in the vdesc struct.
 */
#define	VOPARG_OFFSETOF(type, member)	offsetof(type, member)
#define	VOPARG_OFFSETTO(type,offset,sp)	((type)(((char *)(sp)) + (offset)))

/*
 * This structure is used to configure the new vnodeops vector.
 */
struct vnodeopv_entry_desc {
	const struct vnodeop_desc *opve_op;	/* which operation this is */
	int (*opve_impl)(void *);	/* code implementing this operation */
};

struct vnodeopv_desc {
			/* ptr to the ptr to the vector where op should go */
	int (***opv_desc_vector_p)(void *);
	const struct vnodeopv_entry_desc *opv_desc_ops; /* null terminated list */
};

/*
 * A default routine which just returns an error.
 */
int vn_default_error(void *);

/*
 * A generic structure.
 * This can be used by bypass routines to identify generic arguments.
 */
struct vop_generic_args {
	struct vnodeop_desc *a_desc;
	/* other random data follows, presumably */
};

/*
 * VOCALL calls an op given an ops vector.  We break it out because BSD's
 * vclean changes the ops vector and then wants to call ops with the old
 * vector.
 */
/*
 * actually, vclean doesn't use it anymore, but nfs does,
 * for device specials and fifos.
 */
#define	VOCALL(OPSV,OFF,AP) (( *((OPSV)[(OFF)])) (AP))

/*
 * This call works for vnodes in the kernel.
 */
#define	VCALL(VP,OFF,AP) VOCALL((VP)->v_op,(OFF),(AP))
#define	VDESC(OP) (& __CONCAT(OP,_desc))
#define	VOFFSET(OP) (VDESC(OP)->vdesc_offset)

/* XXX This include should go away */
#include <sys/mount.h>

/*
 * Finally, include the default set of vnode operations.
 */
#include <sys/vnode_if.h>

/*
 * Public vnode manipulation functions.
 */
struct file;
struct filedesc;
struct nameidata;
struct pathbuf;
struct proc;
struct stat;
struct uio;
struct vattr;
struct vnode;

/* see vnode(9) */
void	vfs_vnode_sysinit(void);
int 	bdevvp(dev_t, struct vnode **);
int 	cdevvp(dev_t, struct vnode **);
void 	vattr_null(struct vattr *);
void	vdevgone(int, int, int, enum vtype);
int	vfinddev(dev_t, enum vtype, struct vnode **);
int	vflush(struct mount *, struct vnode *, int);
int	vflushbuf(struct vnode *, int);
void 	vgone(struct vnode *);
int	vinvalbuf(struct vnode *, int, kauth_cred_t, struct lwp *, bool, int);
void	vprint(const char *, struct vnode *);
void 	vput(struct vnode *);
bool	vrecycle(struct vnode *);
void 	vrele(struct vnode *);
void 	vrele_async(struct vnode *);
void	vrele_flush(struct mount *);
int	vtruncbuf(struct vnode *, daddr_t, bool, int);
void	vwakeup(struct buf *);
int	vdead_check(struct vnode *, int);
void	vrevoke(struct vnode *);
void	vremfree(struct vnode *);
void	vshareilock(struct vnode *, struct vnode *);
void	vshareklist(struct vnode *, struct vnode *);
int	vrefcnt(struct vnode *);
int	vcache_get(struct mount *, const void *, size_t, struct vnode **);
int	vcache_new(struct mount *, struct vnode *,
	    struct vattr *, kauth_cred_t, void *, struct vnode **);
int	vcache_rekey_enter(struct mount *, struct vnode *,
	    const void *, size_t, const void *, size_t);
void	vcache_rekey_exit(struct mount *, struct vnode *,
	    const void *, size_t, const void *, size_t);

/* see vnsubr(9) */
int	vn_bwrite(void *);
int 	vn_close(struct vnode *, int, kauth_cred_t);
int	vn_isunder(struct vnode *, struct vnode *, struct lwp *);
int	vn_lock(struct vnode *, int);
void	vn_markexec(struct vnode *);
int	vn_marktext(struct vnode *);
int 	vn_open(struct vnode *, struct pathbuf *, int, int, int,
	    struct vnode **, bool *, int *);
int 	vn_rdwr(enum uio_rw, struct vnode *, void *, int, off_t, enum uio_seg,
    int, kauth_cred_t, size_t *, struct lwp *);
int	vn_readdir(struct file *, char *, int, unsigned int, int *,
    struct lwp *, off_t **, int *);
int	vn_stat(struct vnode *, struct stat *);
int	vn_kqfilter(struct file *, struct knote *);
int	vn_writechk(struct vnode *);
int	vn_openchk(struct vnode *, kauth_cred_t, int);
int	vn_extattr_get(struct vnode *, int, int, const char *, size_t *,
	    void *, struct lwp *);
int	vn_extattr_set(struct vnode *, int, int, const char *, size_t,
	    const void *, struct lwp *);
int	vn_extattr_rm(struct vnode *, int, int, const char *, struct lwp *);
int	vn_fifo_bypass(void *);
int	vn_bdev_open(dev_t, struct vnode **, struct lwp *);
int	vn_bdev_openpath(struct pathbuf *pb, struct vnode **, struct lwp *);


/* initialise global vnode management */
void	vntblinit(void);

/* misc stuff */
void	sched_sync(void *);
void	vn_syncer_add_to_worklist(struct vnode *, int);
void	vn_syncer_remove_from_worklist(struct vnode *);
int	dorevoke(struct vnode *, kauth_cred_t);
int	rawdev_mounted(struct vnode *, struct vnode **);
uint8_t	vtype2dt(enum vtype);

/* see vfssubr(9) */
int	vfs_unixify_accmode(accmode_t *);
void	vfs_getnewfsid(struct mount *);
void	vfs_timestamp(struct timespec *);
#if defined(DDB) || defined(DEBUGPRINT)
void	vfs_vnode_print(struct vnode *, int, void (*)(const char *, ...)
    __printflike(1, 2));
void	vfs_vnode_lock_print(void *, int, void (*)(const char *, ...)
    __printflike(1, 2));
void	vfs_mount_print(struct mount *, int, void (*)(const char *, ...)
    __printflike(1, 2));
void	vfs_mount_print_all(int, void (*)(const char *, ...)
    __printflike(1, 2));
#endif /* DDB */

#endif /* _KERNEL */

#endif /* !_SYS_VNODE_H_ */