/*	$NetBSD: rumpuser.h,v 1.116 2020/03/22 13:30:10 pgoyette Exp $	*/

/*
 * Copyright (c) 2007-2013 Antti Kantee.  All Rights Reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _RUMP_RUMPUSER_H_
#define _RUMP_RUMPUSER_H_

/*
 * Do not include any headers here!  Implementation must take care of
 * having stdint or equivalent included before including this header.
 */

#if !defined(_KERNEL) && !defined(LIBRUMPUSER)
#error The rump/rumpuser.h interface is not for non-kernel consumers
#endif
struct lwp;

/*
 * init
 */

/*
 * Bumping this causes all kinds of havoc for implementations
 * outside of the NetBSD tree, so try to avoid it.
 */
#define RUMPUSER_VERSION 17

/* hypervisor upcall routines */
struct rumpuser_hyperup {
	void (*hyp_schedule)(void);
	void (*hyp_unschedule)(void);
	void (*hyp_backend_unschedule)(int, int *, void *);
	void (*hyp_backend_schedule)(int, void *);
	void (*hyp_lwproc_switch)(struct lwp *);
	void (*hyp_lwproc_release)(void);
	int (*hyp_lwproc_rfork)(void *, int, const char *);
	int (*hyp_lwproc_newlwp)(pid_t);
	struct lwp * (*hyp_lwproc_curlwp)(void);
	int (*hyp_syscall)(int, void *, long *);
	void (*hyp_lwpexit)(void);
	void (*hyp_execnotify)(const char *);
	pid_t (*hyp_getpid)(void);
	void *hyp__extra[8];
};
int rumpuser_init(int, const struct rumpuser_hyperup *);

/*
 * memory allocation
 */

int rumpuser_malloc(size_t, int, void **);
void rumpuser_free(void *, size_t);
int rumpuser_anonmmap(void *, size_t, int, int, void **);
void  rumpuser_unmap(void *, size_t);

/*
 * files and I/O
 */

#define RUMPUSER_OPEN_RDONLY	0x0000
#define RUMPUSER_OPEN_WRONLY	0x0001
#define RUMPUSER_OPEN_RDWR	0x0002
#define RUMPUSER_OPEN_ACCMODE	0x0003 /* "yay" */
#define RUMPUSER_OPEN_CREATE	0x0004 /* create file if it doesn't exist */
#define RUMPUSER_OPEN_EXCL	0x0008 /* exclusive open */
#define RUMPUSER_OPEN_BIO	0x0010 /* open device for block i/o */
int rumpuser_open(const char *, int, int *);
int rumpuser_close(int);

#define RUMPUSER_FT_OTHER 0
#define RUMPUSER_FT_DIR 1
#define RUMPUSER_FT_REG 2
#define RUMPUSER_FT_BLK 3
#define RUMPUSER_FT_CHR 4
int rumpuser_getfileinfo(const char *, uint64_t *, int *);

#define RUMPUSER_BIO_READ	0x01
#define RUMPUSER_BIO_WRITE	0x02
#define RUMPUSER_BIO_SYNC	0x04
typedef void (*rump_biodone_fn)(void *, size_t, int);
void rumpuser_bio(int, int, void *, size_t, int64_t, rump_biodone_fn, void *);

/* this one "accidentally" matches the NetBSD kernel ... */
struct rumpuser_iovec {
	void *iov_base;
	size_t iov_len;
};
#define RUMPUSER_IOV_NOSEEK -1
int rumpuser_iovread(int, struct rumpuser_iovec *, size_t, int64_t, size_t *);
int rumpuser_iovwrite(int, const struct rumpuser_iovec *, size_t,
		      int64_t, size_t *);

#define RUMPUSER_SYNCFD_READ	0x01
#define RUMPUSER_SYNCFD_WRITE	0x02
#define RUMPUSER_SYNCFD_BOTH	(RUMPUSER_SYNCFD_READ | RUMPUSER_SYNCFD_WRITE)
#define RUMPUSER_SYNCFD_BARRIER	0x04
#define RUMPUSER_SYNCFD_SYNC	0x08
int rumpuser_syncfd(int, int, uint64_t, uint64_t);

/*
 * clock and zzz
 */

enum rumpclock { RUMPUSER_CLOCK_RELWALL, RUMPUSER_CLOCK_ABSMONO };
int rumpuser_clock_gettime(int, int64_t *, long *);
int rumpuser_clock_sleep(int, int64_t, long);

/*
 * host information retrieval
 */

#define RUMPUSER_PARAM_NCPU "_RUMPUSER_NCPU"
#define RUMPUSER_PARAM_HOSTNAME "_RUMPUSER_HOSTNAME"
int rumpuser_getparam(const char *, void *, size_t);

/*
 * system call emulation, set errno is TLS
 */

void rumpuser_seterrno(int);

/*
 * termination
 */

#define RUMPUSER_PID_SELF ((int64_t)-1)
int rumpuser_kill(int64_t, int);
#define RUMPUSER_PANIC (-1)
void rumpuser_exit(int) __dead;

/*
 * console output
 */

void rumpuser_putchar(int);
void rumpuser_dprintf(const char *, ...) __printflike(1, 2);

/*
 * access to host random pool
 */

/* always succeeds unless NOWAIT is given */
#define RUMPUSER_RANDOM_HARD	0x01
#define RUMPUSER_RANDOM_NOWAIT	0x02
int rumpuser_getrandom(void *, size_t, int, size_t *);

/*
 * threads, scheduling (host) and synchronization
 */
int  rumpuser_thread_create(void *(*f)(void *), void *, const char *, int,
			    int, int, void **);
void rumpuser_thread_exit(void) __dead;
int  rumpuser_thread_join(void *);

#if defined(LIBRUMPUSER) || defined(RUMP__CURLWP_PRIVATE)
enum rumplwpop {
	RUMPUSER_LWP_CREATE, RUMPUSER_LWP_DESTROY,
	RUMPUSER_LWP_SET, RUMPUSER_LWP_CLEAR
};
void rumpuser_curlwpop(int, struct lwp *);
struct lwp *rumpuser_curlwp(void);
#endif /* LIBRUMPUSER || RUMP__CURLWP_PRIVATE */

struct rumpuser_mtx;
#define RUMPUSER_MTX_SPIN	0x01
#define RUMPUSER_MTX_KMUTEX 	0x02
void rumpuser_mutex_init(struct rumpuser_mtx **, int);
void rumpuser_mutex_enter(struct rumpuser_mtx *);
void rumpuser_mutex_enter_nowrap(struct rumpuser_mtx *);
int  rumpuser_mutex_tryenter(struct rumpuser_mtx *);
void rumpuser_mutex_exit(struct rumpuser_mtx *);
void rumpuser_mutex_destroy(struct rumpuser_mtx *);
void rumpuser_mutex_owner(struct rumpuser_mtx *, struct lwp **);
int  rumpuser_mutex_spin_p(struct rumpuser_mtx *);

struct rumpuser_rw;
enum rumprwlock { RUMPUSER_RW_READER, RUMPUSER_RW_WRITER };
void rumpuser_rw_init(struct rumpuser_rw **);
void rumpuser_rw_enter(int, struct rumpuser_rw *);
int  rumpuser_rw_tryenter(int, struct rumpuser_rw *);
int  rumpuser_rw_tryupgrade(struct rumpuser_rw *);
void rumpuser_rw_downgrade(struct rumpuser_rw *);
void rumpuser_rw_exit(struct rumpuser_rw *);
void rumpuser_rw_destroy(struct rumpuser_rw *);
void rumpuser_rw_held(int, struct rumpuser_rw *, int *);

struct rumpuser_cv;
void rumpuser_cv_init(struct rumpuser_cv **);
void rumpuser_cv_destroy(struct rumpuser_cv *);
void rumpuser_cv_wait(struct rumpuser_cv *, struct rumpuser_mtx *);
void rumpuser_cv_wait_nowrap(struct rumpuser_cv *, struct rumpuser_mtx *);
int  rumpuser_cv_timedwait(struct rumpuser_cv *, struct rumpuser_mtx *,
			   int64_t, int64_t);
void rumpuser_cv_signal(struct rumpuser_cv *);
void rumpuser_cv_broadcast(struct rumpuser_cv *);
void rumpuser_cv_has_waiters(struct rumpuser_cv *, int *);

/*
 * dynloader
 */

struct modinfo;
struct rump_component;
struct evcnt;
typedef void (*rump_modinit_fn)(const struct modinfo *const *, size_t);
typedef int (*rump_symload_fn)(void *, uint64_t, char *, uint64_t);
typedef void (*rump_compload_fn)(const struct rump_component *);
typedef void (*rump_evcntattach_fn)(struct evcnt *);
void rumpuser_dl_bootstrap(rump_modinit_fn, rump_symload_fn, rump_compload_fn,
    rump_evcntattach_fn);

/*
 * misc management
 */

int rumpuser_daemonize_begin(void);
int rumpuser_daemonize_done(int);

#if defined(_RUMP_SYSPROXY) || defined(LIBRUMPUSER)
/*
 * syscall proxy
 */

int	rumpuser_sp_init(const char *,
			 const char *, const char *, const char *);
int	rumpuser_sp_copyin(void *, const void *, void *, size_t);
int	rumpuser_sp_copyinstr(void *, const void *, void *, size_t *);
int	rumpuser_sp_copyout(void *, const void *, void *, size_t);
int	rumpuser_sp_copyoutstr(void *, const void *, void *, size_t *);
int	rumpuser_sp_anonmmap(void *, size_t, void **);
int	rumpuser_sp_raise(void *, int);
void	rumpuser_sp_fini(void *);
#endif /* _RUMP_SYSPROXY || LIBRUMPUSER */

#endif /* _RUMP_RUMPUSER_H_ */