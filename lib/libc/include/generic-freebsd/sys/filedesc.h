/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1990, 1993
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
 *	@(#)filedesc.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_FILEDESC_H_
#define	_SYS_FILEDESC_H_

#include <sys/types.h>
#include <sys/caprights.h>
#include <sys/queue.h>
#include <sys/event.h>
#include <sys/lock.h>
#include <sys/mutex.h>
#include <sys/priority.h>
#include <sys/seqc.h>
#include <sys/sx.h>
#include <sys/_smr.h>
#include <sys/smr_types.h>

#include <machine/_limits.h>

struct filecaps {
	cap_rights_t	 fc_rights;	/* per-descriptor capability rights */
	u_long		*fc_ioctls;	/* per-descriptor allowed ioctls */
	int16_t		 fc_nioctls;	/* fc_ioctls array size */
	uint32_t	 fc_fcntls;	/* per-descriptor allowed fcntls */
};

struct filedescent {
	struct file	*fde_file;	/* file structure for open file */
	struct filecaps	 fde_caps;	/* per-descriptor rights */
	uint8_t		 fde_flags;	/* per-process open file flags */
	seqc_t		 fde_seqc;	/* keep file and caps in sync */
};
#define	fde_rights	fde_caps.fc_rights
#define	fde_fcntls	fde_caps.fc_fcntls
#define	fde_ioctls	fde_caps.fc_ioctls
#define	fde_nioctls	fde_caps.fc_nioctls

#ifdef _KERNEL
static inline void
fde_copy(struct filedescent *from, struct filedescent *to)
{

	to->fde_file = from->fde_file;
	to->fde_caps = from->fde_caps;
	to->fde_flags = from->fde_flags;
}
#endif

struct fdescenttbl {
	int	fdt_nfiles;		/* number of open files allocated */
	struct	filedescent fdt_ofiles[0];	/* open files */
};
#define	fd_seqc(fdt, fd)	(&(fdt)->fdt_ofiles[(fd)].fde_seqc)

#define NDSLOTTYPE	u_long

/*
 * This struct is copy-on-write and allocated from an SMR zone.
 * All fields are constant after initialization apart from the reference count.
 * The ABI root directory is initialized as the root directory and changed
 * during process transiting to or from non-native ABI.
 *
 * Check pwd_* routines for usage.
 */
struct pwd {
	u_int		pwd_refcount;
	struct	vnode	*pwd_cdir;	/* current directory */
	struct	vnode	*pwd_rdir;	/* root directory */
	struct	vnode	*pwd_jdir;	/* jail root directory */
	struct	vnode	*pwd_adir;	/* abi root directory */
};
typedef SMR_POINTER(struct pwd *) smrpwd_t;

struct pwddesc {
	struct mtx	pd_lock;	/* protects members of this struct */
	smrpwd_t	pd_pwd;		/* directories */
	u_int		pd_refcount;
	u_short		pd_cmask;	/* mask for file creation */
};

/*
 * This structure is used for the management of descriptors.  It may be
 * shared by multiple processes.
 */
struct filedesc {
	struct	fdescenttbl *fd_files;	/* open files table */
	NDSLOTTYPE *fd_map;		/* bitmap of free fds */
	int	fd_freefile;		/* approx. next free file */
	int	fd_refcnt;		/* thread reference count */
	int	fd_holdcnt;		/* hold count on structure + mutex */
	struct	sx fd_sx;		/* protects members of this struct */
	struct	kqlist fd_kqlist;	/* list of kqueues on this filedesc */
	int	fd_holdleaderscount;	/* block fdfree() for shared close() */
	int	fd_holdleaderswakeup;	/* fdfree() needs wakeup */
};

/*
 * Structure to keep track of (process leader, struct fildedesc) tuples.
 * Each process has a pointer to such a structure when detailed tracking
 * is needed, e.g., when rfork(RFPROC | RFMEM) causes a file descriptor
 * table to be shared by processes having different "p_leader" pointers
 * and thus distinct POSIX style locks.
 *
 * fdl_refcount and fdl_holdcount are protected by struct filedesc mtx.
 */
struct filedesc_to_leader {
	int		fdl_refcount;	/* references from struct proc */
	int		fdl_holdcount;	/* temporary hold during closef */
	int		fdl_wakeup;	/* fdfree() waits on closef() */
	struct proc	*fdl_leader;	/* owner of POSIX locks */
	/* Circular list: */
	struct filedesc_to_leader *fdl_prev;
	struct filedesc_to_leader *fdl_next;
};
#define	fd_nfiles	fd_files->fdt_nfiles
#define	fd_ofiles	fd_files->fdt_ofiles

/*
 * Per-process open flags.
 */
#define	UF_EXCLOSE	0x01		/* auto-close on exec */

#ifdef _KERNEL

/* Lock a paths descriptor table. */
#define	PWDDESC_LOCK(pdp)	(&(pdp)->pd_lock)
#define	PWDDESC_LOCK_INIT(pdp) \
    mtx_init(PWDDESC_LOCK(pdp), "pwddesc", NULL, MTX_DEF)
#define	PWDDESC_LOCK_DESTROY(pdp)	mtx_destroy(PWDDESC_LOCK(pdp))
#define	PWDDESC_XLOCK(pdp)	mtx_lock(PWDDESC_LOCK(pdp))
#define	PWDDESC_XUNLOCK(pdp)	mtx_unlock(PWDDESC_LOCK(pdp))
#define	PWDDESC_LOCK_ASSERT(pdp, what) \
    mtx_assert(PWDDESC_LOCK(pdp), (what))
#define	PWDDESC_ASSERT_XLOCKED(pdp) \
    PWDDESC_LOCK_ASSERT((pdp), MA_OWNED)
#define	PWDDESC_ASSERT_UNLOCKED(pdp) \
    PWDDESC_LOCK_ASSERT((pdp), MA_NOTOWNED)

#define	PWDDESC_XLOCKED_LOAD_PWD(pdp)	({					\
	struct pwddesc *_pdp = (pdp);						\
	struct pwd *_pwd;							\
	_pwd = smr_serialized_load(&(_pdp)->pd_pwd,				\
	    (PWDDESC_ASSERT_XLOCKED(_pdp), true));				\
	_pwd;									\
})

/* Lock a file descriptor table. */
#define	FILEDESC_LOCK_INIT(fdp)	sx_init(&(fdp)->fd_sx, "filedesc structure")
#define	FILEDESC_LOCK_DESTROY(fdp)	sx_destroy(&(fdp)->fd_sx)
#define	FILEDESC_LOCK(fdp)	(&(fdp)->fd_sx)
#define	FILEDESC_XLOCK(fdp)	sx_xlock(&(fdp)->fd_sx)
#define	FILEDESC_XUNLOCK(fdp)	sx_xunlock(&(fdp)->fd_sx)
#define	FILEDESC_SLOCK(fdp)	sx_slock(&(fdp)->fd_sx)
#define	FILEDESC_SUNLOCK(fdp)	sx_sunlock(&(fdp)->fd_sx)

#define	FILEDESC_LOCK_ASSERT(fdp)	sx_assert(&(fdp)->fd_sx, SX_LOCKED | \
					    SX_NOTRECURSED)
#define	FILEDESC_XLOCK_ASSERT(fdp)	sx_assert(&(fdp)->fd_sx, SX_XLOCKED | \
					    SX_NOTRECURSED)
#define	FILEDESC_UNLOCK_ASSERT(fdp)	sx_assert(&(fdp)->fd_sx, SX_UNLOCKED)

#define	FILEDESC_IS_ONLY_USER(fdp)	({					\
	struct filedesc *_fdp = (fdp);						\
	MPASS(curproc->p_fd == _fdp);						\
	(curproc->p_numthreads == 1 && refcount_load(&_fdp->fd_refcnt) == 1);	\
})

#else

/*
 * Accessor for libkvm et al.
 */
#define	PWDDESC_KVM_LOAD_PWD(pdp)	({					\
	struct pwddesc *_pdp = (pdp);						\
	struct pwd *_pwd;							\
	_pwd = smr_kvm_load(&(_pdp)->pd_pwd);					\
	_pwd;									\
})

#endif

#ifdef _KERNEL

/* Operation types for kern_dup(). */
enum {
	FDDUP_NORMAL,		/* dup() behavior. */
	FDDUP_FCNTL,		/* fcntl()-style errors. */
	FDDUP_FIXED,		/* Force fixed allocation. */
	FDDUP_LASTMODE,
};

/* Flags for kern_dup(). */
#define	FDDUP_FLAG_CLOEXEC	0x1	/* Atomically set UF_EXCLOSE. */

/* For backward compatibility. */
#define	falloc(td, resultfp, resultfd, flags) \
	falloc_caps(td, resultfp, resultfd, flags, NULL)

struct mount;
struct thread;

static __inline void
filecaps_init(struct filecaps *fcaps)
{

        bzero(fcaps, sizeof(*fcaps));
        fcaps->fc_nioctls = -1;
}
bool	filecaps_copy(const struct filecaps *src, struct filecaps *dst,
	    bool locked);
void	filecaps_move(struct filecaps *src, struct filecaps *dst);
void	filecaps_free(struct filecaps *fcaps);

int	closef(struct file *fp, struct thread *td);
void	closef_nothread(struct file *fp);
int	descrip_check_write_mp(struct filedesc *fdp, struct mount *mp);
int	dupfdopen(struct thread *td, struct filedesc *fdp, int dfd, int mode,
	    int openerror, int *indxp);
int	falloc_caps(struct thread *td, struct file **resultfp, int *resultfd,
	    int flags, struct filecaps *fcaps);
void	falloc_abort(struct thread *td, struct file *fp);
int	_falloc_noinstall(struct thread *td, struct file **resultfp, u_int n);
#define	falloc_noinstall(td, resultfp) _falloc_noinstall(td, resultfp, 1)
void	_finstall(struct filedesc *fdp, struct file *fp, int fd, int flags,
	    struct filecaps *fcaps);
int	finstall(struct thread *td, struct file *fp, int *resultfd, int flags,
	    struct filecaps *fcaps);
int	finstall_refed(struct thread *td, struct file *fp, int *resultfd, int flags,
	    struct filecaps *fcaps);
int	fdalloc(struct thread *td, int minfd, int *result);
int	fdallocn(struct thread *td, int minfd, int *fds, int n);
int	fdcheckstd(struct thread *td);
void	fdclose(struct thread *td, struct file *fp, int idx);
void	fdcloseexec(struct thread *td);
void	fdsetugidsafety(struct thread *td);
struct	filedesc *fdcopy(struct filedesc *fdp);
void	fdunshare(struct thread *td);
void	fdescfree(struct thread *td);
int	fdlastfile(struct filedesc *fdp);
int	fdlastfile_single(struct filedesc *fdp);
struct	filedesc *fdinit(void);
struct	filedesc *fdshare(struct filedesc *fdp);
struct filedesc_to_leader *
	filedesc_to_leader_alloc(struct filedesc_to_leader *old,
	    struct filedesc *fdp, struct proc *leader);
struct filedesc_to_leader *
	filedesc_to_leader_share(struct filedesc_to_leader *fdtol,
	    struct filedesc *fdp);
int	getvnode(struct thread *td, int fd, cap_rights_t *rightsp,
	    struct file **fpp);
int	getvnode_path(struct thread *td, int fd, cap_rights_t *rightsp,
	    struct file **fpp);
void	mountcheckdirs(struct vnode *olddp, struct vnode *newdp);

int	fget_cap_noref(struct filedesc *fdp, int fd, cap_rights_t *needrightsp,
	    struct file **fpp, struct filecaps *havecapsp);
int	fget_cap(struct thread *td, int fd, cap_rights_t *needrightsp,
	    struct file **fpp, struct filecaps *havecapsp);
/* Return a referenced file from an unlocked descriptor. */
int	fget_unlocked(struct thread *td, int fd, cap_rights_t *needrightsp,
	    struct file **fpp);
/* Return a file pointer without a ref. FILEDESC_IS_ONLY_USER must be true.  */
int	fget_only_user(struct filedesc *fdp, int fd, cap_rights_t *needrightsp,
	    struct file **fpp);
#define	fput_only_user(fdp, fp)	({					\
	MPASS(FILEDESC_IS_ONLY_USER(fdp));				\
	MPASS(refcount_load(&fp->f_count) > 0);				\
})

/* Requires a FILEDESC_{S,X}LOCK held and returns without a ref. */
static __inline struct file *
fget_noref(struct filedesc *fdp, int fd)
{

	FILEDESC_LOCK_ASSERT(fdp);

	if (__predict_false((u_int)fd >= (u_int)fdp->fd_nfiles))
		return (NULL);

	return (fdp->fd_ofiles[fd].fde_file);
}

static __inline struct filedescent *
fdeget_noref(struct filedesc *fdp, int fd)
{
	struct filedescent *fde;

	FILEDESC_LOCK_ASSERT(fdp);

	if (__predict_false((u_int)fd >= (u_int)fdp->fd_nfiles))
		return (NULL);

	fde = &fdp->fd_ofiles[fd];
	if (__predict_false(fde->fde_file == NULL))
		return (NULL);

	return (fde);
}

#ifdef CAPABILITIES
static __inline bool
fd_modified(struct filedesc *fdp, int fd, seqc_t seqc)
{

	return (!seqc_consistent(fd_seqc(fdp->fd_files, fd), seqc));
}
#endif

int	proc_nfiles(struct proc *p);

/* cdir/rdir/jdir manipulation functions. */
struct pwddesc *pdcopy(struct pwddesc *pdp);
void	pdescfree(struct thread *td);
struct pwddesc *pdinit(struct pwddesc *pdp, bool keeplock);
struct pwddesc *pdshare(struct pwddesc *pdp);
void	pdunshare(struct thread *td);

void	pwd_altroot(struct thread *td, struct vnode *altroot_vp);
void	pwd_chdir(struct thread *td, struct vnode *vp);
int	pwd_chroot(struct thread *td, struct vnode *vp);
int	pwd_chroot_chdir(struct thread *td, struct vnode *vp);
void	pwd_ensure_dirs(void);
void	pwd_set_rootvnode(void);

struct pwd *pwd_hold_pwddesc(struct pwddesc *pdp);
bool	pwd_hold_smr(struct pwd *pwd);
struct pwd *pwd_hold_proc(struct proc *p);
struct pwd *pwd_hold(struct thread *td);
void	pwd_drop(struct pwd *pwd);
static inline void
pwd_set(struct pwddesc *pdp, struct pwd *newpwd)
{
	smr_serialized_store(&pdp->pd_pwd, newpwd,
	    (PWDDESC_ASSERT_XLOCKED(pdp), true));
}
#define	pwd_get_smr()	vfs_smr_entered_load(&curproc->p_pd->pd_pwd)

#endif /* _KERNEL */

#endif /* !_SYS_FILEDESC_H_ */