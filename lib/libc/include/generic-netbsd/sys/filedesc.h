/*	$NetBSD: filedesc.h,v 1.70.2.1 2024/11/17 16:16:10 martin Exp $	*/

/*-
 * Copyright (c) 2008 The NetBSD Foundation, Inc.
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

#include <sys/param.h>
#include <sys/queue.h>
#include <sys/mutex.h>
#include <sys/rwlock.h>
#include <sys/condvar.h>

/*
 * This structure is used for the management of descriptors.  It may be
 * shared by multiple processes.
 *
 * A process is initially started out with NDFILE descriptors stored within
 * this structure, selected to be enough for typical applications based on
 * the historical limit of 20 open files (and the usage of descriptors by
 * shells).  If these descriptors are exhausted, a larger descriptor table
 * may be allocated, up to a process' resource limit; the internal arrays
 * are then unused.  The initial expansion is set to NDEXTENT; each time
 * it runs out, it is doubled until the resource limit is reached. NDEXTENT
 * should be selected to be the biggest multiple of OFILESIZE (see below)
 * that will fit in a power-of-two sized piece of memory.
 */
#define	NDFILE		20
#define	NDEXTENT	50		/* 250 bytes in 256-byte alloc */
#define	NDENTRIES	32		/* 32 fds per entry */
#define	NDENTRYMASK	(NDENTRIES - 1)
#define	NDENTRYSHIFT	5		/* bits per entry */
#define	NDLOSLOTS(x)	(((x) + NDENTRIES - 1) >> NDENTRYSHIFT)
#define	NDHISLOTS(x)	((NDLOSLOTS(x) + NDENTRIES - 1) >> NDENTRYSHIFT)
#define	NDFDFILE	6		/* first 6 descriptors are free */

/*
 * Process-private descriptor reference, one for each descriptor slot
 * in use.  Locks:
 *
 * :	unlocked
 * a	atomic operations + filedesc_t::fd_lock in some cases
 * d	filedesc_t::fd_lock
 *
 * Note that ff_exclose and ff_allocated are likely to be byte sized
 * (bool).  In general adjacent sub-word sized fields must be locked
 * the same way, but in this case it's ok: ff_exclose can only be
 * modified while the descriptor slot is live, and ff_allocated when
 * it's invalid.
 *
 * NOTE: ff_exclose should generally be set with fd_set_exclose(), not
 * written to directly, when implementing flags like O_CLOEXEC or
 * SOCK_CLOEXEC, so that struct filedesc::fd_exclose is updated as
 * needed.  See PR kern/58855: close-on-exec is broken for dup3 and
 * opening cloning devices.
 */
typedef struct fdfile {
	bool		ff_exclose;	/* :: close on exec (fd_set_exclose) */
	bool		ff_allocated;	/* d: descriptor slot is allocated */
	u_int		ff_refcnt;	/* a: reference count on structure */
	struct file	*ff_file;	/* d: pointer to file if open */
	SLIST_HEAD(,knote) ff_knlist;	/* d: knotes attached to this fd */
	kcondvar_t	ff_closing;	/* d: notifier for close */
} fdfile_t;

#define FDFILE_SIZE ((sizeof(fdfile_t)+CACHE_LINE_SIZE-1)/CACHE_LINE_SIZE*CACHE_LINE_SIZE)

/* Reference count */
#define	FR_CLOSING	(0x80000000)	/* closing: must interlock */
#define	FR_MASK		(~FR_CLOSING)	/* reference count */

/*
 * Open file table, potentially many 'active' tables per filedesc_t
 * in a multi-threaded process, or with a shared filedesc_t (clone()).
 * nfiles is first to avoid pointer arithmetic.
 */
typedef struct fdtab {
	u_int		dt_nfiles;	/* number of open files allocated */
	struct fdtab	*dt_link;	/* for lists of dtab */
	fdfile_t	*dt_ff[NDFILE];	/* file structures for open fds */
} fdtab_t;

typedef struct filedesc {
	/*
	 * Built-in fdfile_t records first, since they have strict
	 * alignment requirements.
	 */
	uint8_t		fd_dfdfile[NDFDFILE][FDFILE_SIZE];
	/*
	 * All of the remaining fields are locked by fd_lock.
	 */
	kmutex_t	fd_lock;	/* lock on structure */
	fdtab_t * volatile fd_dt;	/* active descriptor table */
	uint32_t	*fd_himap;	/* each bit points to 32 fds */
	uint32_t	*fd_lomap;	/* bitmap of free fds */
	struct klist	*fd_knhash;	/* hash of attached non-fd knotes */
	int		fd_lastkqfile;	/* max descriptor for kqueue */
	int		fd_lastfile;	/* high-water mark of fd_ofiles */
	int		fd_refcnt;	/* reference count */
	u_long		fd_knhashmask;	/* size of fd_knhash */
	int		fd_freefile;	/* approx. next free file */
	int		fd_unused;	/* unused */
	bool		fd_exclose;	/* non-zero if >0 fd with EXCLOSE */
	/*
	 * This structure is used when the number of open files is
	 * <= NDFILE, and are then pointed to by the pointers above.
	 */
	fdtab_t		fd_dtbuiltin;
	/*
	 * These arrays are used when the number of open files is
	 * <= 1024, and are then pointed to by the pointers above.
	 */
#define fd_startzero	fd_dhimap	/* area to zero on return to cache */
	uint32_t	fd_dhimap[NDENTRIES >> NDENTRYSHIFT];
	uint32_t	fd_dlomap[NDENTRIES];
} filedesc_t;

/*
 * Working directory, root and umask information.  Serialization:
 *
 * a	atomic operations
 * l	cwdi_lock
 */
typedef struct cwdinfo {
	struct vnode	*cwdi_cdir;	/* l: current directory */
	struct vnode	*cwdi_rdir;	/* l: root directory */
	struct vnode	*cwdi_edir;	/* l: emulation root (if known) */
	u_int		cwdi_cmask;	/* a: mask for file creation */
	u_int		cwdi_refcnt;	/* a: reference count */

	krwlock_t	cwdi_lock	/* :: lock on struct */
	    __aligned(COHERENCY_UNIT);	/* -> gets own cache line */
} cwdinfo_t;

#ifdef _KERNEL

struct fileops;
struct socket;
struct proc;

extern struct cwdinfo cwdi0;

/*
 * Kernel global variables and routines.
 */
void	fd_sys_init(void);
int	fd_open(const char*, int, int, int*);
int	fd_dupopen(int, bool, int, int *);
int	fd_alloc(struct proc *, int, int *);
void	fd_tryexpand(struct proc *);
int	fd_allocfile(file_t **, int *);
void	fd_affix(struct proc *, file_t *, unsigned);
void	fd_abort(struct proc *, file_t *, unsigned);
filedesc_t *fd_copy(void);
filedesc_t *fd_init(filedesc_t *);
void	fd_share(proc_t *);
void	fd_hold(lwp_t *);
void	fd_free(void);
void	fd_closeexec(void);
void	fd_ktrexecfd(void);
int	fd_checkstd(void);
file_t	*fd_getfile(unsigned);
file_t	*fd_getfile2(proc_t *, unsigned);
void	fd_putfile(unsigned);
int	fd_getvnode(unsigned, file_t **);
int	fd_getsock(unsigned, struct socket **);
int	fd_getsock1(unsigned, struct socket **, file_t **);
void	fd_putvnode(unsigned);
void	fd_putsock(unsigned);
int	fd_close(unsigned);
int	fd_dup(file_t *, int, int *, bool);
int	fd_dup2(file_t *, unsigned, int);
int	fd_clone(file_t *, unsigned, int, const struct fileops *, void *);
void	fd_set_exclose(struct lwp *, int, bool);
int	pipe1(struct lwp *, int *, int);
int	dodup(struct lwp *, int, int, int, register_t *);

void	cwd_sys_init(void);
struct cwdinfo *cwdinit(void);
void	cwdshare(proc_t *);
void	cwdunshare(proc_t *);
void	cwdfree(struct cwdinfo *);
void	cwdexec(struct proc *);

#define GETCWD_CHECK_ACCESS 0x0001
int	getcwd_common(struct vnode *, struct vnode *, char **, char *, int,
    int, struct lwp *);
int	vnode_to_path(char *, size_t, struct vnode *, struct lwp *,
    struct proc *);

int	closef(file_t *);
file_t *fgetdummy(void);
void	fputdummy(file_t *);

struct stat;
int	do_sys_fstat(int, struct stat *);
struct flock;
int	do_fcntl_lock(int, int, struct flock *);
int	do_posix_fadvise(int, off_t, off_t, int);

extern kmutex_t filelist_lock;
extern filedesc_t filedesc0;

#endif /* _KERNEL */

#endif /* !_SYS_FILEDESC_H_ */