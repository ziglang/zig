/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1998 John Birrell <jb@cimlogic.com.au>.
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
 * 3. Neither the name of the author nor the names of any co-contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY JOHN BIRRELL AND CONTRIBUTORS ``AS IS'' AND
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
 * Private definitions for libc, libc_r and libpthread.
 *
 */

#ifndef _LIBC_PRIVATE_H_
#define _LIBC_PRIVATE_H_
#include <sys/_types.h>
#include <sys/_pthreadtypes.h>

#include <libsys.h>

extern char **environ;

/*
 * The kernel doesn't expose PID_MAX to the user space. Save it here
 * to allow to run a newer world on a pre-1400079 kernel.
 */
#define	_PID_MAX	99999

/*
 * This global flag is non-zero when a process has created one
 * or more threads. It is used to avoid calling locking functions
 * when they are not required.
 */
#ifndef __LIBC_ISTHREADED_DECLARED
#define __LIBC_ISTHREADED_DECLARED
extern int	__isthreaded;
#endif

/*
 * Elf_Auxinfo *__elf_aux_vector, the pointer to the ELF aux vector
 * provided by kernel. Either set for us by rtld, or found at runtime
 * on stack for static binaries.
 *
 * Type is void to avoid polluting whole libc with ELF types.
 */
extern void	*__elf_aux_vector;

/*
 * libc should use libc_dlopen internally, which respects a global
 * flag where loading of new shared objects can be restricted.
 */
void *libc_dlopen(const char *, int);

/*
 * For dynamic linker.
 */
void _rtld_error(const char *fmt, ...);

/*
 * File lock contention is difficult to diagnose without knowing
 * where locks were set. Allow a debug library to be built which
 * records the source file and line number of each lock call.
 */
#ifdef	_FLOCK_DEBUG
#define _FLOCKFILE(x)	_flockfile_debug(x, __FILE__, __LINE__)
#else
#define _FLOCKFILE(x)	_flockfile(x)
#endif

/*
 * Macros for locking and unlocking FILEs. These test if the
 * process is threaded to avoid locking when not required.
 */
#define	FLOCKFILE(fp)		if (__isthreaded) _FLOCKFILE(fp)
#define	FUNLOCKFILE(fp)		if (__isthreaded) _funlockfile(fp)

struct _spinlock;
extern struct _spinlock __stdio_thread_lock __hidden;
#define STDIO_THREAD_LOCK()				\
do {							\
	if (__isthreaded)				\
		_SPINLOCK(&__stdio_thread_lock);	\
} while (0)
#define STDIO_THREAD_UNLOCK()				\
do {							\
	if (__isthreaded)				\
		_SPINUNLOCK(&__stdio_thread_lock);	\
} while (0)

void		__libc_spinlock_stub(struct _spinlock *);
void		__libc_spinunlock_stub(struct _spinlock *);

/*
 * Indexes into the pthread jump table.
 *
 * Warning! If you change this type, you must also change the threads
 * libraries that reference it (libc_r, libpthread).
 */
typedef enum {
	PJT_ATFORK,
	PJT_ATTR_DESTROY,
	PJT_ATTR_GETDETACHSTATE,
	PJT_ATTR_GETGUARDSIZE,
	PJT_ATTR_GETINHERITSCHED,
	PJT_ATTR_GETSCHEDPARAM,
	PJT_ATTR_GETSCHEDPOLICY,
	PJT_ATTR_GETSCOPE,
	PJT_ATTR_GETSTACKADDR,
	PJT_ATTR_GETSTACKSIZE,
	PJT_ATTR_INIT,
	PJT_ATTR_SETDETACHSTATE,
	PJT_ATTR_SETGUARDSIZE,
	PJT_ATTR_SETINHERITSCHED,
	PJT_ATTR_SETSCHEDPARAM,
	PJT_ATTR_SETSCHEDPOLICY,
	PJT_ATTR_SETSCOPE,
	PJT_ATTR_SETSTACKADDR,
	PJT_ATTR_SETSTACKSIZE,
	PJT_CANCEL,
	PJT_CLEANUP_POP,
	PJT_CLEANUP_PUSH,
	PJT_COND_BROADCAST,
	PJT_COND_DESTROY,
	PJT_COND_INIT,
	PJT_COND_SIGNAL,
	PJT_COND_TIMEDWAIT,
	PJT_COND_WAIT,
	PJT_DETACH,
	PJT_EQUAL,
	PJT_EXIT,
	PJT_GETSPECIFIC,
	PJT_JOIN,
	PJT_KEY_CREATE,
	PJT_KEY_DELETE,
	PJT_KILL,
	PJT_MAIN_NP,
	PJT_MUTEXATTR_DESTROY,
	PJT_MUTEXATTR_INIT,
	PJT_MUTEXATTR_SETTYPE,
	PJT_MUTEX_DESTROY,
	PJT_MUTEX_INIT,
	PJT_MUTEX_LOCK,
	PJT_MUTEX_TRYLOCK,
	PJT_MUTEX_UNLOCK,
	PJT_ONCE,
	PJT_RWLOCK_DESTROY,
	PJT_RWLOCK_INIT,
	PJT_RWLOCK_RDLOCK,
	PJT_RWLOCK_TRYRDLOCK,
	PJT_RWLOCK_TRYWRLOCK,
	PJT_RWLOCK_UNLOCK,
	PJT_RWLOCK_WRLOCK,
	PJT_SELF,
	PJT_SETCANCELSTATE,
	PJT_SETCANCELTYPE,
	PJT_SETSPECIFIC,
	PJT_SIGMASK,
	PJT_TESTCANCEL,
	PJT_CLEANUP_POP_IMP,
	PJT_CLEANUP_PUSH_IMP,
	PJT_CANCEL_ENTER,
	PJT_CANCEL_LEAVE,
	PJT_MUTEX_CONSISTENT,
	PJT_MUTEXATTR_GETROBUST,
	PJT_MUTEXATTR_SETROBUST,
	PJT_GETTHREADID_NP,
	PJT_ATTR_GET_NP,
	PJT_GETNAME_NP,
	PJT_SUSPEND_ALL_NP,
	PJT_RESUME_ALL_NP,
	PJT_MAX
} pjt_index_t;

typedef void (*pthread_func_t)(void);
typedef pthread_func_t pthread_func_entry_t[2];

extern pthread_func_entry_t __thr_jtable[];

void	__set_error_selector(int *(*arg)(void));
int	_pthread_mutex_init_calloc_cb_stub(pthread_mutex_t *mutex,
	    void *(calloc_cb)(__size_t, __size_t));

typedef void (*interpos_func_t)(void);
interpos_func_t *__libc_interposing_slot(int interposno);
extern interpos_func_t __libc_interposing[] __hidden;
interpos_func_t *__libsys_interposing_slot(int interposno);

enum {
	INTERPOS_accept,
	INTERPOS_accept4,
	INTERPOS_aio_suspend,
	INTERPOS_close,
	INTERPOS_connect,
	INTERPOS_fcntl,
	INTERPOS_fsync,
	INTERPOS_fork,
	INTERPOS_msync,
	INTERPOS_nanosleep,
	INTERPOS_openat,
	INTERPOS_poll,
	INTERPOS_pselect,
	INTERPOS_recvfrom,
	INTERPOS_recvmsg,
	INTERPOS_select,
	INTERPOS_sendmsg,
	INTERPOS_sendto,
	INTERPOS_setcontext,
	INTERPOS_sigaction,
	INTERPOS_sigprocmask,
	INTERPOS_sigsuspend,
	INTERPOS_sigwait,
	INTERPOS_sigtimedwait,
	INTERPOS_sigwaitinfo,
	INTERPOS_swapcontext,
	INTERPOS_system,
	INTERPOS_tcdrain,
	INTERPOS_read,
	INTERPOS_readv,
	INTERPOS_wait4,
	INTERPOS_write,
	INTERPOS_writev,
	INTERPOS__pthread_mutex_init_calloc_cb,
	INTERPOS_spinlock,
	INTERPOS_spinunlock,
	INTERPOS_kevent,
	INTERPOS_wait6,
	INTERPOS_ppoll,
	INTERPOS_map_stacks_exec,
	INTERPOS_fdatasync,
	INTERPOS_clock_nanosleep,
	INTERPOS__reserved0, /* was distribute_static_tls */
	INTERPOS_pdfork,
	INTERPOS_uexterr_gettext,
	INTERPOS_MAX
};

#define	_INTERPOS_SYS(type, idx, ...)				\
    ((type *)*(__libc_interposing_slot(idx)))(__VA_ARGS__)
#define	INTERPOS_SYS(syscall, ...)				\
    _INTERPOS_SYS(__sys_## syscall ##_t, INTERPOS_## syscall	\
    __VA_OPT__(,) __VA_ARGS__)

/*
 * yplib internal interfaces
 */
#ifdef YP
int _yp_check(char **);
#endif

void __libc_start1(int, char *[], char *[],
    void (*)(void), int (*)(int, char *[], char *[])) __dead2;
void __libc_start1_gcrt(int, char *[], char *[],
    void (*)(void), int (*)(int, char *[], char *[]),
    int *, int *) __dead2;

/*
 * Initialise TLS for static programs
 */
void _init_tls(void);

/*
 * Provides pthread_once()-like functionality for both single-threaded
 * and multi-threaded applications.
 */
int _once(pthread_once_t *, void (*)(void));

/*
 * This is a pointer in the C run-time startup code. It is used
 * by getprogname() and setprogname().
 */
extern const char *__progname;

/*
 * This function is used by the threading libraries to notify malloc that a
 * thread is exiting.
 */
void _malloc_thread_cleanup(void);

/*
 * This function is used by the threading libraries to notify libc that a
 * thread is exiting, so its thread-local dtors should be called.
 */
void __cxa_thread_call_dtors(void);
int __cxa_thread_atexit_hidden(void (*dtor_func)(void *), void *obj,
    void *dso_symbol) __hidden;

/*
 * These functions are used by the threading libraries in order to protect
 * malloc across fork().
 */
void _malloc_prefork(void);
void _malloc_postfork(void);

void _malloc_first_thread(void);

/*
 * Function to clean up streams, called from abort() and exit().
 */
extern void (*__cleanup)(void) __hidden;

/*
 * Get kern.osreldate to detect ABI revisions.  Explicitly
 * ignores value of $OSVERSION and caches result.
 */
int __getosreldate(void);
#include <sys/_types.h>
#include <sys/_sigset.h>

struct aiocb;
struct fd_set;
struct iovec;
struct kevent;
struct msghdr;
struct pollfd;
struct rusage;
struct sigaction;
struct sockaddr;
struct stat;
struct statfs;
struct timespec;
struct timeval;
struct timezone;
struct __siginfo;
struct __ucontext;
struct __wrusage;
enum idtype;

int		__libc_execvpe(const char *, char * const *, char * const *);
int		__libc_sigaction(int, const struct sigaction *,
		    struct sigaction *) __hidden;
int		__libc_sigprocmask(int, const __sigset_t *, __sigset_t *)
		    __hidden;
int		__libc_sigsuspend(const __sigset_t *) __hidden;
int		__libsys_sigwait(const __sigset_t *, int *) __hidden;
int		__libc_system(const char *);
int		__libc_tcdrain(int);

int _elf_aux_info(int aux, void *buf, int buflen);
struct dl_phdr_info;
int __elf_phdr_match_addr(struct dl_phdr_info *, void *);
void __init_elf_aux_vector(void);
void __libc_map_stacks_exec(void);

void	_pthread_cancel_enter(int);
void	_pthread_cancel_leave(int);

struct _pthread_cleanup_info;
void	___pthread_cleanup_push_imp(void (*)(void *), void *,
	    struct _pthread_cleanup_info *);
void	___pthread_cleanup_pop_imp(int);

void __throw_constraint_handler_s(const char * restrict msg, int error);

struct __nl_cat_d;
struct _xlocale;
struct __nl_cat_d *__catopen_l(const char *name, int type,
	    struct _xlocale *locale);
int __strerror_rl(int errnum, char *strerrbuf, size_t buflen,
	    struct _xlocale *locale);

struct uexterror;
int __uexterr_format(const struct uexterror *ue, char *buf, size_t bufsz);
int __libc_uexterr_gettext(char *buf, size_t bufsz);

#endif /* _LIBC_PRIVATE_H_ */
