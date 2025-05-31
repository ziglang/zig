/*	$NetBSD: mount.h,v 1.240 2022/11/04 11:20:40 hannken Exp $	*/

/*
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

#ifndef _KERNEL
#include <sys/featuretest.h>
#if defined(_NETBSD_SOURCE)
#include <sys/stat.h>
#endif /* _NETBSD_SOURCE */
#endif

#ifndef _STANDALONE
#include <sys/param.h> /* precautionary upon removal from ucred.h */
#include <sys/time.h>
#include <sys/ucred.h>
#include <sys/fstypes.h>
#include <sys/statvfs.h>
#if defined(_KERNEL) || defined(__EXPOSE_MOUNT)
#include <sys/uio.h>
#include <sys/queue.h>
#include <sys/rwlock.h>
#include <sys/specificdata.h>
#include <sys/condvar.h>
#endif	/* defined(_KERNEL) || defined(__EXPOSE_MOUNT) */
#endif	/* !_STANDALONE */

/*
 * file system statistics
 */

#define	MNAMELEN	90	/* length of buffer for returned name */

/*
 * File system types.
 */
#define	MOUNT_FFS	"ffs"		/* UNIX "Fast" Filesystem */
#define	MOUNT_UFS	MOUNT_FFS	/* for compatibility */
#define	MOUNT_NFS	"nfs"		/* Network Filesystem */
#define	MOUNT_MFS	"mfs"		/* Memory Filesystem */
#define	MOUNT_MSDOS	"msdos"		/* MSDOS Filesystem */
#define	MOUNT_LFS	"lfs"		/* Log-based Filesystem */
#define	MOUNT_FDESC	"fdesc"		/* File Descriptor Filesystem */
#define	MOUNT_NULL	"null"		/* Minimal Filesystem Layer */
#define	MOUNT_OVERLAY	"overlay"	/* Minimal Overlay Filesystem Layer */
#define	MOUNT_UMAP	"umap"	/* User/Group Identifier Remapping Filesystem */
#define	MOUNT_KERNFS	"kernfs"	/* Kernel Information Filesystem */
#define	MOUNT_PROCFS	"procfs"	/* /proc Filesystem */
#define	MOUNT_AFS	"afs"		/* Andrew Filesystem */
#define	MOUNT_CD9660	"cd9660"	/* ISO9660 (aka CDROM) Filesystem */
#define	MOUNT_UNION	"union"		/* Union (translucent) Filesystem */
#define	MOUNT_ADOSFS	"adosfs"	/* AmigaDOS Filesystem */
#define	MOUNT_EXT2FS	"ext2fs"	/* Second Extended Filesystem */
#define	MOUNT_CFS	"coda"		/* Coda Filesystem */
#define	MOUNT_CODA	MOUNT_CFS	/* Coda Filesystem */
#define	MOUNT_FILECORE	"filecore"	/* Acorn Filecore Filesystem */
#define	MOUNT_NTFS	"ntfs"		/* Windows/NT Filesystem */
#define	MOUNT_SMBFS	"smbfs"		/* CIFS (SMB) */
#define	MOUNT_PTYFS	"ptyfs"		/* Pseudo tty filesystem */
#define	MOUNT_TMPFS	"tmpfs"		/* Efficient memory file-system */
#define MOUNT_UDF	"udf"		/* UDF CD/DVD filesystem */
#define	MOUNT_SYSVBFS	"sysvbfs"	/* System V Boot Filesystem */
#define MOUNT_PUFFS	"puffs"		/* Pass-to-Userspace filesystem */
#define MOUNT_HFS	"hfs"		/* Apple HFS+ Filesystem */
#define MOUNT_EFS	"efs"		/* SGI's Extent Filesystem */
#define MOUNT_ZFS	"zfs"		/* Sun ZFS */
#define MOUNT_NILFS	"nilfs"		/* NTT's NiLFS(2) logging file system */
#define MOUNT_RUMPFS	"rumpfs"	/* rump virtual file system */
#define MOUNT_V7FS	"v7fs"		/* 7th Edition of Unix Filesystem */
#define MOUNT_AUTOFS	"autofs"	/* Automounter Filesystem */

/*
 * Sysctl CTL_VFS definitions.
 *
 * Second level identifier specifies which filesystem. Second level
 * identifier VFS_GENERIC returns information about all filesystems.
 *
 * Note the slightly non-flat nature of these sysctl numbers.  Oh for
 * a better sysctl interface.
 */
#define VFS_GENERIC	0		/* generic filesystem information */
#define VFS_MAXTYPENUM	1		/* int: highest defined fs type */
#define VFS_CONF	2		/* struct: vfsconf for filesystem given
					   as next argument */
#define VFS_USERMOUNT	3		/* enable/disable fs mnt by non-root */
#define	VFS_MAGICLINKS  4		/* expand 'magic' symlinks */
#define	VFS_TIMESTAMP_PRECISION  5	/* file timestamp precision */

/* vfsquery flags for kqueue(2) */
#define VQ_MOUNT	0x0001	/* new filesystem arrived */
#define VQ_UNMOUNT	0x0002	/* filesystem has left */

#ifndef _STANDALONE

#if defined(_KERNEL) || defined(__EXPOSE_MOUNT)

struct vnode;
struct vnode_impl;
struct vattr;

/*
 * Structure per mounted file system.  Each mounted file system has an
 * array of operations and an instance record.
 */
struct mount {
	/*
	 * Mostly stable data.
	 */
	kmutex_t	*mnt_vnodelock;		/* lock on mnt_vnodelist */
	struct vfsops	*mnt_op;		/* operations on fs */
	struct vnode	*mnt_vnodecovered;	/* vnode we mounted on */
	struct mount	*mnt_lower;		/* fs mounted on */
	void		*mnt_transinfo;		/* for FS-internal use */
	void		*mnt_data;		/* private data */
	kmutex_t	*mnt_renamelock;	/* per-fs rename lock */
	int		mnt_flag;		/* flags */
	int		mnt_iflag;		/* internal flags */
	int		mnt_fs_bshift;		/* offset shift for lblkno */
	int		mnt_dev_bshift;		/* shift for device sectors */
	specificdata_reference
			mnt_specdataref;	/* subsystem specific data */
	kmutex_t	*mnt_updating;		/* to serialize updates */
	const struct wapbl_ops
			*mnt_wapbl_op;		/* logging ops */
	struct wapbl	*mnt_wapbl;		/* log info */
	struct wapbl_replay
			*mnt_wapbl_replay;	/* replay support XXX: what? */
	uint64_t	mnt_gen;

	/*
	 * Volatile data: pad to keep away from the stable items.
	 */
	int		mnt_refcnt		/* ref count on this structure */
	    __aligned(COHERENCY_UNIT);
	int		mnt_synclist_slot;	/* synclist slot index */
	TAILQ_HEAD(, vnode_impl) mnt_vnodelist;	/* list of vnodes this mount */
	struct statvfs	mnt_stat;		/* cache of filesystem stats */
};

#endif /* defined(_KERNEL) || defined(__EXPOSE_MOUNT) */

#ifdef _KERNEL

struct quotactl_args;		/* in sys/quotactl.h */
struct quotastat;		/* in sys/quotactl.h */
struct quotaidtypestat;		/* in sys/quotactl.h */
struct quotaobjtypestat;	/* in sys/quotactl.h */
struct quotakcursor;		/* in sys/quotactl.h */
struct quotakey;		/* in sys/quota.h */
struct quotaval;		/* in sys/quota.h */

/*
 * Operations supported on mounted file system.
 */

struct vfsops {
	const char *vfs_name;
	size_t	vfs_min_mount_data;
	int	(*vfs_mount)	(struct mount *, const char *, void *,
				    size_t *);
	int	(*vfs_start)	(struct mount *, int);
	int	(*vfs_unmount)	(struct mount *, int);
	int	(*vfs_root)	(struct mount *, int, struct vnode **);
	int	(*vfs_quotactl)	(struct mount *, struct quotactl_args *);
	int	(*vfs_statvfs)	(struct mount *, struct statvfs *);
	int	(*vfs_sync)	(struct mount *, int, struct kauth_cred *);
	int	(*vfs_vget)	(struct mount *, ino_t, int, struct vnode **);
	int	(*vfs_loadvnode) (struct mount *, struct vnode *,
				    const void *, size_t, const void **);
	int	(*vfs_newvnode) (struct mount *, struct vnode *, struct vnode *,
				    struct vattr *, kauth_cred_t, void *,
				    size_t *, const void **);
	int	(*vfs_fhtovp)	(struct mount *, struct fid *, int,
				    struct vnode **);
	int	(*vfs_vptofh)	(struct vnode *, struct fid *, size_t *);
	void	(*vfs_init)	(void);
	void	(*vfs_reinit)	(void);
	void	(*vfs_done)	(void);
	int	(*vfs_mountroot)(void);
	int	(*vfs_snapshot)	(struct mount *, struct vnode *,
				    struct timespec *);
	int	(*vfs_extattrctl) (struct mount *, int,
				    struct vnode *, int, const char *);
	int	(*vfs_suspendctl) (struct mount *, int);
	int	(*vfs_renamelock_enter)(struct mount *);
	void	(*vfs_renamelock_exit)(struct mount *);
	int	(*vfs_fsync)	(struct vnode *, int);
	const struct vnodeopv_desc * const *vfs_opv_descs;
	int	vfs_refcount;
	LIST_ENTRY(vfsops) vfs_list;
};

/* XXX vget is actually file system internal. */
#define VFS_VGET(MP, INO, LK, VPP) (*(MP)->mnt_op->vfs_vget)(MP, INO, LK, VPP)
#define VFS_LOADVNODE(MP, VP, KEY, KEY_LEN, NEW_KEY) \
	(*(MP)->mnt_op->vfs_loadvnode)(MP, VP, KEY, KEY_LEN, NEW_KEY)
#define VFS_NEWVNODE(MP, DVP, VP, VAP, CRED, EXTRA, NEW_LEN, NEW_KEY) \
	(*(MP)->mnt_op->vfs_newvnode)(MP, DVP, VP, VAP, CRED, EXTRA, \
	    NEW_LEN, NEW_KEY)

#define VFS_RENAMELOCK_ENTER(MP)  (*(MP)->mnt_op->vfs_renamelock_enter)(MP)
#define VFS_RENAMELOCK_EXIT(MP)   (*(MP)->mnt_op->vfs_renamelock_exit)(MP)
#define VFS_FSYNC(MP, VP, FLG)	  (*(MP)->mnt_op->vfs_fsync)(VP, FLG)

int	VFS_MOUNT(struct mount *, const char *, void *, size_t *);
int	VFS_START(struct mount *, int);
int	VFS_UNMOUNT(struct mount *, int);
int	VFS_ROOT(struct mount *, int, struct vnode **);
int	VFS_QUOTACTL(struct mount *, struct quotactl_args *);
int	VFS_STATVFS(struct mount *, struct statvfs *);
int	VFS_SYNC(struct mount *, int, struct kauth_cred *);
int	VFS_FHTOVP(struct mount *, struct fid *, int, struct vnode **);
int	VFS_VPTOFH(struct vnode *, struct fid *, size_t *);
int	VFS_SNAPSHOT(struct mount *, struct vnode *, struct timespec *);
int	VFS_EXTATTRCTL(struct mount *, int, struct vnode *, int, const char *);
int	VFS_SUSPENDCTL(struct mount *, int);

struct vnodeopv_desc;
struct kauth_cred;

#define	VFS_MAX_MOUNT_DATA	8192

#define VFS_PROTOS(fsname)						\
int	fsname##_mount(struct mount *, const char *, void *,		\
		size_t *);						\
int	fsname##_start(struct mount *, int);				\
int	fsname##_unmount(struct mount *, int);				\
int	fsname##_root(struct mount *, int, struct vnode **);		\
int	fsname##_quotactl(struct mount *, struct quotactl_args *);	\
int	fsname##_statvfs(struct mount *, struct statvfs *);		\
int	fsname##_sync(struct mount *, int, struct kauth_cred *);	\
int	fsname##_vget(struct mount *, ino_t, int, struct vnode **);	\
int	fsname##_loadvnode(struct mount *, struct vnode *,		\
		const void *, size_t, const void **);			\
int	fsname##_newvnode(struct mount *, struct vnode *,		\
		struct vnode *, struct vattr *, kauth_cred_t, void *,	\
		size_t *, const void **);				\
int	fsname##_fhtovp(struct mount *, struct fid *, int, struct vnode **);\
int	fsname##_vptofh(struct vnode *, struct fid *, size_t *);	\
void	fsname##_init(void);						\
void	fsname##_reinit(void);						\
void	fsname##_done(void);						\
int	fsname##_mountroot(void);					\
int	fsname##_snapshot(struct mount *, struct vnode *,		\
		struct timespec *);					\
int	fsname##_extattrctl(struct mount *, int, struct vnode *, int,	\
		const char *);						\
int	fsname##_suspendctl(struct mount *, int)

/*
 * This operations vector is so wapbl can be wrapped into a filesystem lkm.
 * XXX Eventually, we want to move this functionality
 * down into the filesystems themselves so that this isn't needed.
 */
struct wapbl_ops {
	void (*wo_wapbl_discard)(struct wapbl *);
	int (*wo_wapbl_replay_isopen)(struct wapbl_replay *);
	int (*wo_wapbl_replay_can_read)(struct wapbl_replay *, daddr_t, long);
	int (*wo_wapbl_replay_read)(struct wapbl_replay *, void *, daddr_t, long);
	void (*wo_wapbl_add_buf)(struct wapbl *, struct buf *);
	void (*wo_wapbl_remove_buf)(struct wapbl *, struct buf *);
	void (*wo_wapbl_resize_buf)(struct wapbl *, struct buf *, long, long);
	int (*wo_wapbl_begin)(struct wapbl *, const char *, int);
	void (*wo_wapbl_end)(struct wapbl *);
	void (*wo_wapbl_junlock_assert)(struct wapbl *);
	void (*wo_wapbl_jlock_assert)(struct wapbl *);
	void (*wo_wapbl_biodone)(struct buf *);
};
#define WAPBL_DISCARD(MP)						\
    (*(MP)->mnt_wapbl_op->wo_wapbl_discard)((MP)->mnt_wapbl)
#define WAPBL_REPLAY_ISOPEN(MP)						\
    (*(MP)->mnt_wapbl_op->wo_wapbl_replay_isopen)((MP)->mnt_wapbl_replay)
#define WAPBL_REPLAY_CAN_READ(MP, BLK, LEN)				\
    (*(MP)->mnt_wapbl_op->wo_wapbl_replay_can_read)((MP)->mnt_wapbl_replay, \
    (BLK), (LEN))
#define WAPBL_REPLAY_READ(MP, DATA, BLK, LEN)				\
    (*(MP)->mnt_wapbl_op->wo_wapbl_replay_read)((MP)->mnt_wapbl_replay,	\
    (DATA), (BLK), (LEN))
#define WAPBL_ADD_BUF(MP, BP)						\
    (*(MP)->mnt_wapbl_op->wo_wapbl_add_buf)((MP)->mnt_wapbl, (BP))
#define WAPBL_REMOVE_BUF(MP, BP)					\
    (*(MP)->mnt_wapbl_op->wo_wapbl_remove_buf)((MP)->mnt_wapbl, (BP))
#define WAPBL_RESIZE_BUF(MP, BP, OLDSZ, OLDCNT)				\
    (*(MP)->mnt_wapbl_op->wo_wapbl_resize_buf)((MP)->mnt_wapbl, (BP),	\
    (OLDSZ), (OLDCNT))
#define WAPBL_BEGIN(MP)							\
    (*(MP)->mnt_wapbl_op->wo_wapbl_begin)((MP)->mnt_wapbl,		\
    __FILE__, __LINE__)
#define WAPBL_END(MP)							\
    (*(MP)->mnt_wapbl_op->wo_wapbl_end)((MP)->mnt_wapbl)
#define WAPBL_JUNLOCK_ASSERT(MP)					\
    (*(MP)->mnt_wapbl_op->wo_wapbl_junlock_assert)((MP)->mnt_wapbl)
#define WAPBL_JLOCK_ASSERT(MP)						\
    (*(MP)->mnt_wapbl_op->wo_wapbl_jlock_assert)((MP)->mnt_wapbl)

struct vfs_hooks {
	LIST_ENTRY(vfs_hooks) vfs_hooks_list;
	void	(*vh_unmount)(struct mount *);
	int	(*vh_reexport)(struct mount *, const char *, void *);
	void	(*vh_future_expansion_1)(void);
	void	(*vh_future_expansion_2)(void);
	void	(*vh_future_expansion_3)(void);
	void	(*vh_future_expansion_4)(void);
	void	(*vh_future_expansion_5)(void);
};

void	vfs_hooks_init(void);
int	vfs_hooks_attach(struct vfs_hooks *);
int	vfs_hooks_detach(struct vfs_hooks *);
void	vfs_hooks_unmount(struct mount *);
int	vfs_hooks_reexport(struct mount *, const char *, void *);

#endif /* _KERNEL */

/*
 * Export arguments for local filesystem mount calls.
 *
 * This structure is deprecated and is only provided for compatibility
 * reasons with old binary utilities; several file systems expose an
 * instance of this structure in their mount arguments structure, thus
 * needing a padding in place of the old values.  This definition cannot
 * change in the future due to this reason.
 * XXX: This should be moved to the compat subtree but cannot be done
 * until we can move the mount args structures themselves.
 *
 * The current export_args structure can be found in nfs/nfs.h.
 */
struct export_args30 {
	int	ex_flags;		/* export related flags */
	uid_t	ex_root;		/* mapping for root uid */
	struct	uucred ex_anon;		/* mapping for anonymous user */
	struct	sockaddr *ex_addr;	/* net address to which exported */
	int	ex_addrlen;		/* and the net address length */
	struct	sockaddr *ex_mask;	/* mask of valid bits in saddr */
	int	ex_masklen;		/* and the smask length */
	char	*ex_indexfile;		/* index file for WebNFS URLs */
};

struct mnt_export_args30 {
	const char *fspec;		/* Always NULL */
	struct export_args30 eargs;
};

#ifdef _KERNEL

/*
 * exported VFS interface (see vfssubr(9))
 */
struct	mount *vfs_getvfs(fsid_t *);    /* return vfs given fsid */
int	vfs_composefh(struct vnode *, fhandle_t *, size_t *);
int	vfs_composefh_alloc(struct vnode *, fhandle_t **);
void	vfs_composefh_free(fhandle_t *);
int	vfs_fhtovp(fhandle_t *, struct vnode **);
int	vfs_mountedon(struct vnode *);/* is a vfs mounted on vp */
int	vfs_mountroot(void);
void	vfs_shutdown(void);	    /* unmount and sync file systems */
void	vfs_sync_all(struct lwp *);
bool	vfs_unmountall(struct lwp *);	    /* unmount file systems */
bool	vfs_unmountall1(struct lwp *, bool, bool);
bool	vfs_unmount_forceone(struct lwp *);
int 	vfs_busy(struct mount *);
int 	vfs_trybusy(struct mount *);
int	vfs_rootmountalloc(const char *, const char *, struct mount **);
void	vfs_unbusy(struct mount *);
int	vfs_set_lowermount(struct mount *, struct mount *);
int	vfs_attach(struct vfsops *);
int	vfs_detach(struct vfsops *);
void	vfs_reinit(void);
struct vfsops *vfs_getopsbyname(const char *);
void	vfs_delref(struct vfsops *);
void	vfs_ref(struct mount *);
void	vfs_rele(struct mount *);
struct mount *vfs_mountalloc(struct vfsops *, struct vnode *);
int	vfs_stdextattrctl(struct mount *, int, struct vnode *,
	    int, const char *);
void	vfs_insmntque(struct vnode *, struct mount *);
int	vfs_quotactl_stat(struct mount *, struct quotastat *);
int	vfs_quotactl_idtypestat(struct mount *, int, struct quotaidtypestat *);
int	vfs_quotactl_objtypestat(struct mount *,int,struct quotaobjtypestat *);
int	vfs_quotactl_get(struct mount *, const struct quotakey *,
	    struct quotaval *);
int	vfs_quotactl_put(struct mount *, const struct quotakey *,
	    const struct quotaval *);
int	vfs_quotactl_del(struct mount *, const struct quotakey *);
int	vfs_quotactl_cursoropen(struct mount *, struct quotakcursor *);
int	vfs_quotactl_cursorclose(struct mount *, struct quotakcursor *);
int	vfs_quotactl_cursorskipidtype(struct mount *, struct quotakcursor *,
            int);
int	vfs_quotactl_cursorget(struct mount *, struct quotakcursor *,
            struct quotakey *, struct quotaval *, unsigned, unsigned *);
int	vfs_quotactl_cursoratend(struct mount *, struct quotakcursor *, int *);
int	vfs_quotactl_cursorrewind(struct mount *, struct quotakcursor *);
int	vfs_quotactl_quotaon(struct mount *, int, const char *);
int	vfs_quotactl_quotaoff(struct mount *, int);

struct vnode_iterator; /* Opaque. */
void	vfs_vnode_iterator_init(struct mount *, struct vnode_iterator **);
void	vfs_vnode_iterator_destroy(struct vnode_iterator *);
struct vnode *vfs_vnode_iterator_next(struct vnode_iterator *,
    bool (*)(void *, struct vnode *), void *);

/* Syncer */
extern int	syncer_maxdelay;
extern time_t	syncdelay;
extern time_t	filedelay;
extern time_t	dirdelay;
extern time_t	metadelay;
void	vfs_syncer_add_to_worklist(struct mount *);
void	vfs_syncer_remove_from_worklist(struct mount *);

extern int vfs_magiclinks;
extern int vfs_timestamp_precision;

extern	struct vfsops *vfssw[];			/* filesystem type table */
extern	int nvfssw;
extern	kmutex_t vfs_list_lock;

void	vfs_mount_sysinit(void);
long	makefstype(const char *);
int	mount_domount(struct lwp *, struct vnode **, struct vfsops *,
	    const char *, int, void *, size_t *);
int	dounmount(struct mount *, int, struct lwp *);
int	do_sys_mount(struct lwp *, const char *, enum uio_seg, const char *,
	    int, void *, enum uio_seg, size_t, register_t *);
void	vfsinit(void);
void	vfs_evfilt_fs_init(void);
void	vfs_opv_init(const struct vnodeopv_desc * const *);
void	vfs_opv_free(const struct vnodeopv_desc * const *);
#ifdef DEBUG
void	vfs_bufstats(void);
#endif

int	mount_specific_key_create(specificdata_key_t *, specificdata_dtor_t);
void	mount_specific_key_delete(specificdata_key_t);
void 	mount_initspecific(struct mount *);
void 	mount_finispecific(struct mount *);
void *	mount_getspecific(struct mount *, specificdata_key_t);
void	mount_setspecific(struct mount *, specificdata_key_t, void *);

int	usermount_common_policy(struct mount *, u_long);

typedef struct mount_iterator mount_iterator_t; /* Opaque. */
void	mountlist_iterator_init(mount_iterator_t **);
void	mountlist_iterator_destroy(mount_iterator_t *);
struct mount *mountlist_iterator_next(mount_iterator_t *);
struct mount *mountlist_iterator_trynext(mount_iterator_t *);
struct mount *_mountlist_next(struct mount *);
void	mountlist_append(struct mount *);
void	mountlist_remove(struct mount *);

LIST_HEAD(vfs_list_head, vfsops);
extern struct vfs_list_head vfs_list;

#else /* _KERNEL */

#include <sys/cdefs.h>

__BEGIN_DECLS
#if !defined(__LIBC12_SOURCE__) && !defined(_STANDALONE)
int	getfh(const char *, void *, size_t *)
	__RENAME(__getfh30);
#endif

int	unmount(const char *, int);
#if defined(_NETBSD_SOURCE)
#ifndef __LIBC12_SOURCE__
int mount(const char *, const char *, int, void *, size_t) __RENAME(__mount50);
int	fhopen(const void *, size_t, int) __RENAME(__fhopen40);
int	fhstat(const void *, size_t, struct stat *) __RENAME(__fhstat50);
#endif
#endif /* _NETBSD_SOURCE */
__END_DECLS

#endif /* _KERNEL */
#endif /* !_STANDALONE */

#endif /* !_SYS_MOUNT_H_ */