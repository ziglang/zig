/*	$NetBSD: ffs_extern.h,v 1.87.2.1 2023/05/13 11:51:14 martin Exp $	*/

/*-
 * Copyright (c) 1991, 1993, 1994
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
 *	@(#)ffs_extern.h	8.6 (Berkeley) 3/30/95
 */

#ifndef _UFS_FFS_FFS_EXTERN_H_
#define _UFS_FFS_FFS_EXTERN_H_

/*
 * Sysctl values for the fast filesystem.
 */
#define FFS_CLUSTERREAD		1	/* cluster reading enabled */
#define FFS_CLUSTERWRITE	2	/* cluster writing enabled */
#define FFS_REALLOCBLKS		3	/* block reallocation enabled */
#define FFS_ASYNCFREE		4	/* asynchronous block freeing enabled */
#define FFS_LOG_CHANGEOPT	5	/* log optimalization strategy change */
#define FFS_EXTATTR_AUTOCREATE	6	/* size for backing file autocreation */

struct buf;
struct fid;
struct fs;
struct inode;
struct ufs1_dinode;
struct ufs2_dinode;
struct mount;
struct nameidata;
struct lwp;
struct statvfs;
struct timeval;
struct timespec;
struct ufsmount;
struct uio;
struct vnode;
struct mbuf;
struct cg;

#if defined(_KERNEL)

#include <sys/pool.h>

#define FFS_NOBLK		((daddr_t)-1)

#define	FFS_ITIMES(ip, acc, mod, cre) \
	while ((ip)->i_flag & (IN_ACCESS | IN_CHANGE | IN_UPDATE | IN_MODIFY)) \
		ffs_itimes(ip, acc, mod, cre)

extern pool_cache_t ffs_inode_cache;	/* memory pool for inodes */
extern pool_cache_t ffs_dinode1_cache;	/* memory pool for UFS1 dinodes */
extern pool_cache_t ffs_dinode2_cache;	/* memory pool for UFS2 dinodes */

#endif /* defined(_KERNEL) */

__BEGIN_DECLS

#if defined(_KERNEL)

#include <sys/param.h>
#include <sys/mount.h>
#include <sys/wapbl.h>

/* ffs_alloc.c */
int	ffs_alloc(struct inode *, daddr_t, daddr_t , int, int, kauth_cred_t,
		  daddr_t *);
int	ffs_realloccg(struct inode *, daddr_t, daddr_t, daddr_t, int, int,
		      int, kauth_cred_t, struct buf **, daddr_t *);
int	ffs_valloc(struct vnode *, int, kauth_cred_t, ino_t *);
daddr_t	ffs_blkpref_ufs1(struct inode *, daddr_t, int, int, int32_t *);
daddr_t	ffs_blkpref_ufs2(struct inode *, daddr_t, int, int, int64_t *);
int	ffs_blkalloc(struct inode *, daddr_t, long);
int	ffs_blkalloc_ump(struct ufsmount *, daddr_t, long);
void	ffs_blkfree(struct fs *, struct vnode *, daddr_t, long, ino_t);
void	*ffs_discard_init(struct vnode *, struct fs *);
void	ffs_discard_finish(void *, int);
void	ffs_blkfree_snap(struct fs *, struct vnode *, daddr_t, long, ino_t);
int	ffs_vfree(struct vnode *, ino_t, int);
int	ffs_checkfreefile(struct fs *, struct vnode *, ino_t);
int	ffs_freefile(struct mount *, ino_t, int);
int	ffs_freefile_snap(struct fs *, struct vnode *, ino_t, int);

/* ffs_balloc.c */
int	ffs_balloc(struct vnode *, off_t, int, kauth_cred_t, int,
    struct buf **);

/* ffs_inode.c */
int	ffs_update(struct vnode *, const struct timespec *,
    const struct timespec *, int);
int	ffs_truncate(struct vnode *, off_t, int, kauth_cred_t);

/* ffs_vfsops.c */
VFS_PROTOS(ffs);

int     ffs_reload(struct mount *, kauth_cred_t, struct lwp *);
int     ffs_mountfs(struct vnode *, struct mount *, struct lwp *);
int	ffs_flushfiles(struct mount *, int, struct lwp *);
int	ffs_sbupdate(struct ufsmount *, int);
int	ffs_cgupdate(struct ufsmount *, int);

/* ffs_vnops.c */
int	ffs_read(void *);
int	ffs_write(void *);
int	ffs_bufio(enum uio_rw, struct vnode *, void *, size_t, off_t, int,
	    kauth_cred_t, size_t *, struct lwp *);
int	ffs_bufrd(struct vnode *, struct uio *, int, kauth_cred_t);
int	ffs_bufwr(struct vnode *, struct uio *, int, kauth_cred_t);
int	ffs_fsync(void *);
int	ffs_spec_fsync(void *);
int	ffs_reclaim(void *);
int	ffs_getpages(void *);
void	ffs_gop_size(struct vnode *, off_t, off_t *, int);
int	ffs_lock(void *);
int	ffs_unlock(void *);
int	ffs_islocked(void *);
int	ffs_full_fsync(struct vnode *, int);

/* ffs_extattr.c */
int	ffs_openextattr(void *);
int	ffs_closeextattr(void *);
int	ffs_getextattr(void *);
int	ffs_setextattr(void *);
int	ffs_listextattr(void *);
int	ffs_deleteextattr(void *);
int	ffsext_strategy(void *);

/*
 * Snapshot function prototypes.
 */
int	ffs_snapshot_init(struct ufsmount *);
void	ffs_snapshot_fini(struct ufsmount *);
int	ffs_snapblkfree(struct fs *, struct vnode *, daddr_t, long, ino_t);
void	ffs_snapremove(struct vnode *);
int	ffs_snapshot(struct mount *, struct vnode *, struct timespec *);
void	ffs_snapshot_mount(struct mount *);
void	ffs_snapshot_unmount(struct mount *);
void	ffs_snapgone(struct vnode *);
int	ffs_snapshot_read(struct vnode *, struct uio *, int);

/* Write Ahead Physical Block Logging */
void	ffs_wapbl_verify_inodes(struct mount *, const char *);
void	ffs_wapbl_replay_finish(struct mount *);
int	ffs_wapbl_start(struct mount *);
int	ffs_wapbl_stop(struct mount *, int);
int	ffs_wapbl_replay_start(struct mount *, struct fs *, struct vnode *);
void	ffs_wapbl_blkalloc(struct fs *, struct vnode *, daddr_t, int);

void	ffs_wapbl_sync_metadata(struct mount *, struct wapbl_dealloc *);
void	ffs_wapbl_abort_sync_metadata(struct mount *, struct wapbl_dealloc *);

extern int (**ffs_vnodeop_p)(void *);
extern int (**ffs_specop_p)(void *);
extern int (**ffs_fifoop_p)(void *);

#endif /* defined(_KERNEL) */

/* ffs_appleufs.c */
struct appleufslabel;
u_int16_t ffs_appleufs_cksum(const struct appleufslabel *);
int	ffs_appleufs_validate(const char*, const struct appleufslabel *,
			      struct appleufslabel *);
void	ffs_appleufs_set(struct appleufslabel *, const char *, time_t,
			 uint64_t);

/* ffs_bswap.c */
void	ffs_sb_swap(const struct fs *, struct fs *);
void	ffs_dinode1_swap(struct ufs1_dinode *, struct ufs1_dinode *);
void	ffs_dinode2_swap(struct ufs2_dinode *, struct ufs2_dinode *);
struct csum;
void	ffs_csum_swap(struct csum *, struct csum *, int);
struct csum_total;
void	ffs_csumtotal_swap(const struct csum_total *, struct csum_total *);
void	ffs_cg_swap(struct cg *, struct cg *, struct fs *);

/* ffs_subr.c */
#if defined(_KERNEL)
void	ffs_load_inode(struct buf *, struct inode *, struct fs *, ino_t);
int	ffs_getblk(struct vnode *, daddr_t, daddr_t, int, bool, buf_t **);
#endif /* defined(_KERNEL) */
void	ffs_fragacct(struct fs *, int, uint32_t[], int, int);
int	ffs_isblock(struct fs *, u_char *, int32_t);
int	ffs_isfreeblock(struct fs *, u_char *, int32_t);
void	ffs_clrblock(struct fs *, u_char *, int32_t);
void	ffs_setblock(struct fs *, u_char *, int32_t);
void	ffs_itimes(struct inode *, const struct timespec *,
    const struct timespec *, const struct timespec *);
void	ffs_clusteracct(struct fs *, struct cg *, int32_t, int);

/* ffs_quota2.c */
int	ffs_quota2_mount(struct mount *);

__END_DECLS

#endif /* !_UFS_FFS_FFS_EXTERN_H_ */