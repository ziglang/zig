/*
   Copyright (c) 2011-2016 mingw-w64 project

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.
*/

/*
 * Parts of this library are derived by:
 *
 * Posix Threads library for Microsoft Windows
 *
 * Use at own risk, there is no implied warranty to this code.
 * It uses undocumented features of Microsoft Windows that can change
 * at any time in the future.
 *
 * (C) 2010 Lockless Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 *
 *  * Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *  * Neither the name of Lockless Inc. nor the names of its contributors may be
 *    used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AN
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef WIN_PTHREADS_H
#define WIN_PTHREADS_H

#include <stddef.h>
#include <errno.h>
#include <sys/types.h>

#include <process.h>
#include <limits.h>
#include <signal.h>
#include <time.h>

#include <sys/timeb.h>

#include "pthread_compat.h"

#ifdef __cplusplus
extern "C" {
#endif

#define __WINPTHREADS_VERSION_MAJOR 0
#define __WINPTHREADS_VERSION_MINOR 5
#define __WINPTHREADS_VERSION_PATCHLEVEL 0

/* MSB 8-bit major version, 8-bit minor version, 16-bit patch level.  */
#define __WINPTHREADS_VERSION 0x00050000

#if defined(IN_WINPTHREAD)
#  if defined(DLL_EXPORT)
#    define WINPTHREAD_API  __declspec(dllexport)  /* building the DLL  */
#  else
#    define WINPTHREAD_API  /* building the static library  */
#  endif
#else
#  if defined(WINPTHREADS_USE_DLLIMPORT)
#    define WINPTHREAD_API  __declspec(dllimport)  /* user wants explicit `dllimport`  */
#  else
#    define WINPTHREAD_API  /* the default; auto imported in case of DLL  */
#  endif
#endif

/* #define WINPTHREAD_DBG 1 */

/* Compatibility stuff: */
#define RWLS_PER_THREAD						8

/* Error-codes.  */
#ifndef ETIMEDOUT
#define ETIMEDOUT	138
#endif
#ifndef ENOTSUP
#define ENOTSUP		129
#endif
#ifndef EWOULDBLOCK
#define EWOULDBLOCK	140
#endif

/* pthread specific defines.  */

#define PTHREAD_CANCEL_DISABLE 0
#define PTHREAD_CANCEL_ENABLE 0x01

#define PTHREAD_CANCEL_DEFERRED 0
#define PTHREAD_CANCEL_ASYNCHRONOUS 0x02

#define PTHREAD_CREATE_JOINABLE 0
#define PTHREAD_CREATE_DETACHED 0x04

#define PTHREAD_EXPLICIT_SCHED 0
#define PTHREAD_INHERIT_SCHED 0x08

#define PTHREAD_SCOPE_PROCESS 0
#define PTHREAD_SCOPE_SYSTEM 0x10

#define PTHREAD_DEFAULT_ATTR (PTHREAD_CANCEL_ENABLE)

#define PTHREAD_CANCELED ((void *) (intptr_t) 0xDEADBEEF)

#define _PTHREAD_NULL_THREAD ((pthread_t) 0)

#define PTHREAD_ONCE_INIT 0

#define PTHREAD_DESTRUCTOR_ITERATIONS 256
#define PTHREAD_KEYS_MAX (1<<20)

#define PTHREAD_MUTEX_NORMAL 0
#define PTHREAD_MUTEX_ERRORCHECK 1
#define PTHREAD_MUTEX_RECURSIVE 2
#define PTHREAD_MUTEX_DEFAULT PTHREAD_MUTEX_NORMAL

#define PTHREAD_MUTEX_SHARED 1
#define PTHREAD_MUTEX_PRIVATE 0

#define PTHREAD_PRIO_NONE 0
#define PTHREAD_PRIO_INHERIT 8
#define PTHREAD_PRIO_PROTECT 16
#define PTHREAD_PRIO_MULT 32
#define PTHREAD_PROCESS_SHARED 1
#define PTHREAD_PROCESS_PRIVATE 0

#define PTHREAD_MUTEX_FAST_NP		PTHREAD_MUTEX_NORMAL
#define PTHREAD_MUTEX_TIMED_NP		PTHREAD_MUTEX_FAST_NP
#define PTHREAD_MUTEX_ADAPTIVE_NP	PTHREAD_MUTEX_FAST_NP
#define PTHREAD_MUTEX_ERRORCHECK_NP	PTHREAD_MUTEX_ERRORCHECK
#define PTHREAD_MUTEX_RECURSIVE_NP	PTHREAD_MUTEX_RECURSIVE

WINPTHREAD_API void * pthread_timechange_handler_np(void * dummy);
WINPTHREAD_API int    pthread_delay_np (const struct timespec *interval);
WINPTHREAD_API int    pthread_num_processors_np(void);
WINPTHREAD_API int    pthread_set_num_processors_np(int n);

#define PTHREAD_BARRIER_SERIAL_THREAD 1

/* maximum number of times a read lock may be obtained */
#define	MAX_READ_LOCKS		(INT_MAX - 1)

/* No fork() in windows - so ignore this */
#define pthread_atfork(F1,F2,F3) 0

/* unsupported stuff: */
#define pthread_mutex_getprioceiling(M, P) ENOTSUP
#define pthread_mutex_setprioceiling(M, P) ENOTSUP
#define pthread_getcpuclockid(T, C) ENOTSUP
#define pthread_attr_getguardsize(A, S) ENOTSUP
#define pthread_attr_setgaurdsize(A, S) ENOTSUP

typedef long pthread_once_t;
typedef unsigned pthread_mutexattr_t;
typedef unsigned pthread_key_t;
typedef void *pthread_barrierattr_t;
typedef int pthread_condattr_t;
typedef int pthread_rwlockattr_t;

/*
struct _pthread_v;

typedef struct pthread_t {
  struct _pthread_v *p;
  int x;
} pthread_t;
*/

typedef uintptr_t pthread_t;

typedef struct _pthread_cleanup _pthread_cleanup;
struct _pthread_cleanup
{
    void (*func)(void *);
    void *arg;
    _pthread_cleanup *next;
};

/* Using MemoryBarrier() requires including Windows headers. User code
 * may want to use pthread_cleanup_push without including Windows headers
 * first, thus prefer GCC specific intrinsics where possible. */
#ifdef __GNUC__
#define __pthread_MemoryBarrier() __sync_synchronize()
#else
#define __pthread_MemoryBarrier() MemoryBarrier()
#endif

#define pthread_cleanup_push(F, A)                                      \
    do {                                                                \
        const _pthread_cleanup _pthread_cup =                           \
            { (F), (A), *pthread_getclean() };                          \
        __pthread_MemoryBarrier();                                      \
        *pthread_getclean() = (_pthread_cleanup *) &_pthread_cup;       \
        __pthread_MemoryBarrier();                                      \
        do {                                                            \
            do {} while (0)

/* Note that if async cancelling is used, then there is a race here */
#define pthread_cleanup_pop(E)                                          \
        } while (0);                                                    \
        *pthread_getclean() = _pthread_cup.next;                        \
        if ((E)) _pthread_cup.func((pthread_once_t *)_pthread_cup.arg); \
    } while (0)

#ifndef SCHED_OTHER
/* Some POSIX realtime extensions, mostly stubbed */
#define SCHED_OTHER     0
#define SCHED_FIFO      1
#define SCHED_RR        2
#define SCHED_MIN       SCHED_OTHER
#define SCHED_MAX       SCHED_RR

struct sched_param {
  int sched_priority;
};

WINPTHREAD_API int sched_yield(void);
WINPTHREAD_API int sched_get_priority_min(int pol);
WINPTHREAD_API int sched_get_priority_max(int pol);
WINPTHREAD_API int sched_getscheduler(pid_t pid);
WINPTHREAD_API int sched_setscheduler(pid_t pid, int pol, const struct sched_param *param);

#endif

typedef struct pthread_attr_t pthread_attr_t;
struct pthread_attr_t
{
    unsigned p_state;
    void *stack;
    size_t s_size;
    struct sched_param param;
};

WINPTHREAD_API int pthread_attr_setschedparam(pthread_attr_t *attr, const struct sched_param *param);
WINPTHREAD_API int pthread_attr_getschedparam(const pthread_attr_t *attr, struct sched_param *param);
WINPTHREAD_API int pthread_getschedparam(pthread_t thread, int *pol, struct sched_param *param);
WINPTHREAD_API int pthread_setschedparam(pthread_t thread, int pol, const struct sched_param *param);
WINPTHREAD_API int pthread_attr_setschedpolicy (pthread_attr_t *attr, int pol);
WINPTHREAD_API int pthread_attr_getschedpolicy (const pthread_attr_t *attr, int *pol);

/* synchronization objects */
typedef intptr_t pthread_spinlock_t;
typedef intptr_t pthread_mutex_t;
typedef intptr_t pthread_cond_t;
typedef intptr_t pthread_rwlock_t;
typedef void	*pthread_barrier_t;

#define PTHREAD_MUTEX_NORMAL 0
#define PTHREAD_MUTEX_ERRORCHECK 1
#define PTHREAD_MUTEX_RECURSIVE 2

#define GENERIC_INITIALIZER				-1
#define GENERIC_ERRORCHECK_INITIALIZER			-2
#define GENERIC_RECURSIVE_INITIALIZER			-3
#define GENERIC_NORMAL_INITIALIZER			-1
#define PTHREAD_MUTEX_INITIALIZER			(pthread_mutex_t)GENERIC_INITIALIZER
#define PTHREAD_RECURSIVE_MUTEX_INITIALIZER		(pthread_mutex_t)GENERIC_RECURSIVE_INITIALIZER
#define PTHREAD_ERRORCHECK_MUTEX_INITIALIZER		(pthread_mutex_t)GENERIC_ERRORCHECK_INITIALIZER
#define PTHREAD_NORMAL_MUTEX_INITIALIZER		(pthread_mutex_t)GENERIC_NORMAL_INITIALIZER
#define PTHREAD_DEFAULT_MUTEX_INITIALIZER		PTHREAD_NORMAL_MUTEX_INITIALIZER
#define PTHREAD_COND_INITIALIZER			(pthread_cond_t)GENERIC_INITIALIZER
#define PTHREAD_RWLOCK_INITIALIZER			(pthread_rwlock_t)GENERIC_INITIALIZER
#define PTHREAD_SPINLOCK_INITIALIZER			(pthread_spinlock_t)GENERIC_INITIALIZER

WINPTHREAD_API extern void (**_pthread_key_dest)(void *);
WINPTHREAD_API int         pthread_key_create(pthread_key_t *key, void (* dest)(void *));
WINPTHREAD_API int         pthread_key_delete(pthread_key_t key);
WINPTHREAD_API void *      pthread_getspecific(pthread_key_t key);
WINPTHREAD_API int         pthread_setspecific(pthread_key_t key, const void *value);

WINPTHREAD_API pthread_t pthread_self(void);
WINPTHREAD_API int       pthread_once(pthread_once_t *o, void (*func)(void));
WINPTHREAD_API void      pthread_testcancel(void);
WINPTHREAD_API int       pthread_equal(pthread_t t1, pthread_t t2);
WINPTHREAD_API void      pthread_tls_init(void);
WINPTHREAD_API void      _pthread_cleanup_dest(pthread_t t);
WINPTHREAD_API int       pthread_get_concurrency(int *val);
WINPTHREAD_API int       pthread_set_concurrency(int val);
WINPTHREAD_API void      pthread_exit(void *res);
WINPTHREAD_API void      _pthread_invoke_cancel(void);
WINPTHREAD_API int       pthread_cancel(pthread_t t);
WINPTHREAD_API int       pthread_kill(pthread_t t, int sig);
WINPTHREAD_API unsigned  _pthread_get_state(const pthread_attr_t *attr, unsigned flag);
WINPTHREAD_API int       _pthread_set_state(pthread_attr_t *attr, unsigned flag, unsigned val);
WINPTHREAD_API int       pthread_setcancelstate(int state, int *oldstate);
WINPTHREAD_API int       pthread_setcanceltype(int type, int *oldtype);
WINPTHREAD_API unsigned  __stdcall pthread_create_wrapper(void *args);
WINPTHREAD_API int       pthread_create(pthread_t *th, const pthread_attr_t *attr, void *(* func)(void *), void *arg);
WINPTHREAD_API int       pthread_join(pthread_t t, void **res);
WINPTHREAD_API int       pthread_detach(pthread_t t);
WINPTHREAD_API int       pthread_setname_np(pthread_t thread, const char *name);
WINPTHREAD_API int       pthread_getname_np(pthread_t thread, char *name, size_t len);


WINPTHREAD_API int pthread_rwlock_init(pthread_rwlock_t *rwlock_, const pthread_rwlockattr_t *attr);
WINPTHREAD_API int pthread_rwlock_wrlock(pthread_rwlock_t *l);
WINPTHREAD_API int pthread_rwlock_timedwrlock(pthread_rwlock_t *rwlock, const struct timespec *ts);
WINPTHREAD_API int pthread_rwlock_rdlock(pthread_rwlock_t *l);
WINPTHREAD_API int pthread_rwlock_timedrdlock(pthread_rwlock_t *l, const struct timespec *ts);
WINPTHREAD_API int pthread_rwlock_unlock(pthread_rwlock_t *l);
WINPTHREAD_API int pthread_rwlock_tryrdlock(pthread_rwlock_t *l);
WINPTHREAD_API int pthread_rwlock_trywrlock(pthread_rwlock_t *l);
WINPTHREAD_API int pthread_rwlock_destroy (pthread_rwlock_t *l);

WINPTHREAD_API int pthread_cond_init(pthread_cond_t *cv, const pthread_condattr_t *a);
WINPTHREAD_API int pthread_cond_destroy(pthread_cond_t *cv);
WINPTHREAD_API int pthread_cond_signal (pthread_cond_t *cv);
WINPTHREAD_API int pthread_cond_broadcast (pthread_cond_t *cv);
WINPTHREAD_API int pthread_cond_wait (pthread_cond_t *cv, pthread_mutex_t *external_mutex);
WINPTHREAD_API int pthread_cond_timedwait(pthread_cond_t *cv, pthread_mutex_t *external_mutex, const struct timespec *t);
WINPTHREAD_API int pthread_cond_timedwait_relative_np(pthread_cond_t *cv, pthread_mutex_t *external_mutex, const struct timespec *t);

WINPTHREAD_API int pthread_mutex_lock(pthread_mutex_t *m);
WINPTHREAD_API int pthread_mutex_timedlock(pthread_mutex_t *m, const struct timespec *ts);
WINPTHREAD_API int pthread_mutex_unlock(pthread_mutex_t *m);
WINPTHREAD_API int pthread_mutex_trylock(pthread_mutex_t *m);
WINPTHREAD_API int pthread_mutex_init(pthread_mutex_t *m, const pthread_mutexattr_t *a);
WINPTHREAD_API int pthread_mutex_destroy(pthread_mutex_t *m);

WINPTHREAD_API int pthread_barrier_destroy(pthread_barrier_t *b);
WINPTHREAD_API int pthread_barrier_init(pthread_barrier_t *b, const void *attr, unsigned int count);
WINPTHREAD_API int pthread_barrier_wait(pthread_barrier_t *b);

WINPTHREAD_API int pthread_spin_init(pthread_spinlock_t *l, int pshared);
WINPTHREAD_API int pthread_spin_destroy(pthread_spinlock_t *l);
/* No-fair spinlock due to lack of knowledge of thread number.  */
WINPTHREAD_API int pthread_spin_lock(pthread_spinlock_t *l);
WINPTHREAD_API int pthread_spin_trylock(pthread_spinlock_t *l);
WINPTHREAD_API int pthread_spin_unlock(pthread_spinlock_t *l);

WINPTHREAD_API int pthread_attr_init(pthread_attr_t *attr);
WINPTHREAD_API int pthread_attr_destroy(pthread_attr_t *attr);
WINPTHREAD_API int pthread_attr_setdetachstate(pthread_attr_t *a, int flag);
WINPTHREAD_API int pthread_attr_getdetachstate(const pthread_attr_t *a, int *flag);
WINPTHREAD_API int pthread_attr_setinheritsched(pthread_attr_t *a, int flag);
WINPTHREAD_API int pthread_attr_getinheritsched(const pthread_attr_t *a, int *flag);
WINPTHREAD_API int pthread_attr_setscope(pthread_attr_t *a, int flag);
WINPTHREAD_API int pthread_attr_getscope(const pthread_attr_t *a, int *flag);
WINPTHREAD_API int pthread_attr_getstack(const pthread_attr_t *attr, void **stack, size_t *size);
WINPTHREAD_API int pthread_attr_setstack(pthread_attr_t *attr, void *stack, size_t size);
WINPTHREAD_API int pthread_attr_getstackaddr(const pthread_attr_t *attr, void **stack);
WINPTHREAD_API int pthread_attr_setstackaddr(pthread_attr_t *attr, void *stack);
WINPTHREAD_API int pthread_attr_getstacksize(const pthread_attr_t *attr, size_t *size);
WINPTHREAD_API int pthread_attr_setstacksize(pthread_attr_t *attr, size_t size);

WINPTHREAD_API int pthread_mutexattr_init(pthread_mutexattr_t *a);
WINPTHREAD_API int pthread_mutexattr_destroy(pthread_mutexattr_t *a);
WINPTHREAD_API int pthread_mutexattr_gettype(const pthread_mutexattr_t *a, int *type);
WINPTHREAD_API int pthread_mutexattr_settype(pthread_mutexattr_t *a, int type);
WINPTHREAD_API int pthread_mutexattr_getpshared(const pthread_mutexattr_t *a, int *type);
WINPTHREAD_API int pthread_mutexattr_setpshared(pthread_mutexattr_t * a, int type);
WINPTHREAD_API int pthread_mutexattr_getprotocol(const pthread_mutexattr_t *a, int *type);
WINPTHREAD_API int pthread_mutexattr_setprotocol(pthread_mutexattr_t *a, int type);
WINPTHREAD_API int pthread_mutexattr_getprioceiling(const pthread_mutexattr_t *a, int * prio);
WINPTHREAD_API int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *a, int prio);
WINPTHREAD_API int pthread_getconcurrency(void);
WINPTHREAD_API int pthread_setconcurrency(int new_level);

WINPTHREAD_API int pthread_condattr_destroy(pthread_condattr_t *a);
WINPTHREAD_API int pthread_condattr_init(pthread_condattr_t *a);
WINPTHREAD_API int pthread_condattr_getpshared(const pthread_condattr_t *a, int *s);
WINPTHREAD_API int pthread_condattr_setpshared(pthread_condattr_t *a, int s);

#ifndef __clockid_t_defined
typedef int clockid_t;
#define __clockid_t_defined 1
#endif  /* __clockid_t_defined */

WINPTHREAD_API int pthread_condattr_getclock (const pthread_condattr_t *attr,
       clockid_t *clock_id);
WINPTHREAD_API int pthread_condattr_setclock(pthread_condattr_t *attr,
       clockid_t clock_id);
WINPTHREAD_API int __pthread_clock_nanosleep(clockid_t clock_id, int flags, const struct timespec *rqtp, struct timespec *rmtp);

WINPTHREAD_API int pthread_barrierattr_init(void **attr);
WINPTHREAD_API int pthread_barrierattr_destroy(void **attr);
WINPTHREAD_API int pthread_barrierattr_setpshared(void **attr, int s);
WINPTHREAD_API int pthread_barrierattr_getpshared(void **attr, int *s);

/* Private extensions for analysis and internal use.  */
WINPTHREAD_API struct _pthread_cleanup ** pthread_getclean (void);
WINPTHREAD_API void * pthread_gethandle (pthread_t t);
WINPTHREAD_API void * pthread_getevent (void);

WINPTHREAD_API unsigned long long _pthread_rel_time_in_ms(const struct timespec *ts);
WINPTHREAD_API unsigned long long _pthread_time_in_ms(void);
WINPTHREAD_API unsigned long long _pthread_time_in_ms_from_timespec(const struct timespec *ts);
WINPTHREAD_API int _pthread_tryjoin (pthread_t t, void **res);
WINPTHREAD_API int pthread_rwlockattr_destroy(pthread_rwlockattr_t *a);
WINPTHREAD_API int pthread_rwlockattr_getpshared(pthread_rwlockattr_t *a, int *s);
WINPTHREAD_API int pthread_rwlockattr_init(pthread_rwlockattr_t *a);
WINPTHREAD_API int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *a, int s);

#ifndef SIG_BLOCK
#define SIG_BLOCK 0
#endif
#ifndef SIG_UNBLOCK
#define SIG_UNBLOCK 1
#endif
#ifndef SIG_SETMASK
#define SIG_SETMASK 2
#endif

#include <pthread_unistd.h>

#undef _POSIX_THREAD_DESTRUCTOR_ITERATIONS
#define _POSIX_THREAD_DESTRUCTOR_ITERATIONS     PTHREAD_DESTRUCTOR_ITERATIONS

#undef _POSIX_THREAD_KEYS_MAX
#define _POSIX_THREAD_KEYS_MAX                  PTHREAD_KEYS_MAX

#undef PTHREAD_THREADS_MAX
#define PTHREAD_THREADS_MAX                     2019

#undef _POSIX_SEM_NSEMS_MAX
#define _POSIX_SEM_NSEMS_MAX                    256

#undef SEM_NSEMS_MAX
#define SEM_NSEMS_MAX                           1024

/* Wrap cancellation points.  */
#if defined(__WINPTHREAD_ENABLE_WRAP_API) \
    || defined(__WINPTRHEAD_ENABLE_WRAP_API) /* historical typo */
#define accept(...) (pthread_testcancel(), accept(__VA_ARGS__))
#define aio_suspend(...) (pthread_testcancel(), aio_suspend(__VA_ARGS__))
#define clock_nanosleep(...) (pthread_testcancel(), clock_nanosleep(__VA_ARGS__))
#define close(...) (pthread_testcancel(), close(__VA_ARGS__))
#define connect(...) (pthread_testcancel(), connect(__VA_ARGS__))
#define creat(...) (pthread_testcancel(), creat(__VA_ARGS__))
#define fcntl(...) (pthread_testcancel(), fcntl(__VA_ARGS__))
#define fdatasync(...) (pthread_testcancel(), fdatasync(__VA_ARGS__))
#define fsync(...) (pthread_testcancel(), fsync(__VA_ARGS__))
#define getmsg(...) (pthread_testcancel(), getmsg(__VA_ARGS__))
#define getpmsg(...) (pthread_testcancel(), getpmsg(__VA_ARGS__))
#define lockf(...) (pthread_testcancel(), lockf(__VA_ARGS__))
#define mg_receive(...) (pthread_testcancel(), mg_receive(__VA_ARGS__))
#define mg_send(...) (pthread_testcancel(), mg_send(__VA_ARGS__))
#define mg_timedreceive(...) (pthread_testcancel(), mg_timedreceive(__VA_ARGS__))
#define mg_timessend(...) (pthread_testcancel(), mg_timedsend(__VA_ARGS__))
#define msgrcv(...) (pthread_testcancel(), msgrecv(__VA_ARGS__))
#define msgsnd(...) (pthread_testcancel(), msgsnd(__VA_ARGS__))
#define msync(...) (pthread_testcancel(), msync(__VA_ARGS__))
#define nanosleep(...) (pthread_testcancel(), nanosleep(__VA_ARGS__))
#define open(...) (pthread_testcancel(), open(__VA_ARGS__))
#define pause(...) (pthread_testcancel(), pause(__VA_ARGS__))
#define poll(...) (pthread_testcancel(), poll(__VA_ARGS__))
#define pread(...) (pthread_testcancel(), pread(__VA_ARGS__))
#define pselect(...) (pthread_testcancel(), pselect(__VA_ARGS__))
#define putmsg(...) (pthread_testcancel(), putmsg(__VA_ARGS__))
#define putpmsg(...) (pthread_testcancel(), putpmsg(__VA_ARGS__))
#define pwrite(...) (pthread_testcancel(), pwrite(__VA_ARGS__))
#define read(...) (pthread_testcancel(), read(__VA_ARGS__))
#define readv(...) (pthread_testcancel(), readv(__VA_ARGS__))
#define recv(...) (pthread_testcancel(), recv(__VA_ARGS__))
#define recvfrom(...) (pthread_testcancel(), recvfrom(__VA_ARGS__))
#define recvmsg(...) (pthread_testcancel(), recvmsg(__VA_ARGS__))
#define select(...) (pthread_testcancel(), select(__VA_ARGS__))
#define sem_timedwait(...) (pthread_testcancel(), sem_timedwait(__VA_ARGS__))
#define sem_wait(...) (pthread_testcancel(), sem_wait(__VA_ARGS__))
#define send(...) (pthread_testcancel(), send(__VA_ARGS__))
#define sendmsg(...) (pthread_testcancel(), sendmsg(__VA_ARGS__))
#define sendto(...) (pthread_testcancel(), sendto(__VA_ARGS__))
#define sigpause(...) (pthread_testcancel(), sigpause(__VA_ARGS__))
#define sigsuspend(...) (pthread_testcancel(), sigsuspend(__VA_ARGS__))
#define sigwait(...) (pthread_testcancel(), sigwait(__VA_ARGS__))
#define sigwaitinfo(...) (pthread_testcancel(), sigwaitinfo(__VA_ARGS__))
#define sleep(...) (pthread_testcancel(), sleep(__VA_ARGS__))
//#define Sleep(...) (pthread_testcancel(), Sleep(__VA_ARGS__))
#define system(...) (pthread_testcancel(), system(__VA_ARGS__))
#define access(...) (pthread_testcancel(), access(__VA_ARGS__))
#define asctime(...) (pthread_testcancel(), asctime(__VA_ARGS__))
#define catclose(...) (pthread_testcancel(), catclose(__VA_ARGS__))
#define catgets(...) (pthread_testcancel(), catgets(__VA_ARGS__))
#define catopen(...) (pthread_testcancel(), catopen(__VA_ARGS__))
#define closedir(...) (pthread_testcancel(), closedir(__VA_ARGS__))
#define closelog(...) (pthread_testcancel(), closelog(__VA_ARGS__))
#define ctermid(...) (pthread_testcancel(), ctermid(__VA_ARGS__))
#define ctime(...) (pthread_testcancel(), ctime(__VA_ARGS__))
#define dbm_close(...) (pthread_testcancel(), dbm_close(__VA_ARGS__))
#define dbm_delete(...) (pthread_testcancel(), dbm_delete(__VA_ARGS__))
#define dbm_fetch(...) (pthread_testcancel(), dbm_fetch(__VA_ARGS__))
#define dbm_nextkey(...) (pthread_testcancel(), dbm_nextkey(__VA_ARGS__))
#define dbm_open(...) (pthread_testcancel(), dbm_open(__VA_ARGS__))
#define dbm_store(...) (pthread_testcancel(), dbm_store(__VA_ARGS__))
#define dlclose(...) (pthread_testcancel(), dlclose(__VA_ARGS__))
#define dlopen(...) (pthread_testcancel(), dlopen(__VA_ARGS__))
#define endgrent(...) (pthread_testcancel(), endgrent(__VA_ARGS__))
#define endhostent(...) (pthread_testcancel(), endhostent(__VA_ARGS__))
#define endnetent(...) (pthread_testcancel(), endnetent(__VA_ARGS__))
#define endprotoent(...) (pthread_testcancel(), endprotoend(__VA_ARGS__))
#define endpwent(...) (pthread_testcancel(), endpwent(__VA_ARGS__))
#define endservent(...) (pthread_testcancel(), endservent(__VA_ARGS__))
#define endutxent(...) (pthread_testcancel(), endutxent(__VA_ARGS__))
#define fclose(...) (pthread_testcancel(), fclose(__VA_ARGS__))
#define fflush(...) (pthread_testcancel(), fflush(__VA_ARGS__))
#define fgetc(...) (pthread_testcancel(), fgetc(__VA_ARGS__))
#define fgetpos(...) (pthread_testcancel(), fgetpos(__VA_ARGS__))
#define fgets(...) (pthread_testcancel(), fgets(__VA_ARGS__))
#define fgetwc(...) (pthread_testcancel(), fgetwc(__VA_ARGS__))
#define fgetws(...) (pthread_testcancel(), fgetws(__VA_ARGS__))
#define fmtmsg(...) (pthread_testcancel(), fmtmsg(__VA_ARGS__))
#define fopen(...) (pthread_testcancel(), fopen(__VA_ARGS__))
#define fpathconf(...) (pthread_testcancel(), fpathconf(__VA_ARGS__))
#define fprintf(...) (pthread_testcancel(), fprintf(__VA_ARGS__))
#define fputc(...) (pthread_testcancel(), fputc(__VA_ARGS__))
#define fputs(...) (pthread_testcancel(), fputs(__VA_ARGS__))
#define fputwc(...) (pthread_testcancel(), fputwc(__VA_ARGS__))
#define fputws(...) (pthread_testcancel(), fputws(__VA_ARGS__))
#define fread(...) (pthread_testcancel(), fread(__VA_ARGS__))
#define freopen(...) (pthread_testcancel(), freopen(__VA_ARGS__))
#define fscanf(...) (pthread_testcancel(), fscanf(__VA_ARGS__))
#define fseek(...) (pthread_testcancel(), fseek(__VA_ARGS__))
#define fseeko(...) (pthread_testcancel(), fseeko(__VA_ARGS__))
#define fsetpos(...) (pthread_testcancel(), fsetpos(__VA_ARGS__))
#define fstat(...) (pthread_testcancel(), fstat(__VA_ARGS__))
#define ftell(...) (pthread_testcancel(), ftell(__VA_ARGS__))
#define ftello(...) (pthread_testcancel(), ftello(__VA_ARGS__))
#define ftw(...) (pthread_testcancel(), ftw(__VA_ARGS__))
#define fwprintf(...) (pthread_testcancel(), fwprintf(__VA_ARGS__))
#define fwrite(...) (pthread_testcancel(), fwrite(__VA_ARGS__))
#define fwscanf(...) (pthread_testcancel(), fwscanf(__VA_ARGS__))
#define getaddrinfo(...) (pthread_testcancel(), getaddrinfo(__VA_ARGS__))
#define getc(...) (pthread_testcancel(), getc(__VA_ARGS__))
#define getc_unlocked(...) (pthread_testcancel(), getc_unlocked(__VA_ARGS__))
#define getchar(...) (pthread_testcancel(), getchar(__VA_ARGS__))
#define getchar_unlocked(...) (pthread_testcancel(), getchar_unlocked(__VA_ARGS__))
#define getcwd(...) (pthread_testcancel(), getcwd(__VA_ARGS__))
#define getdate(...) (pthread_testcancel(), getdate(__VA_ARGS__))
#define getgrent(...) (pthread_testcancel(), getgrent(__VA_ARGS__))
#define getgrgid(...) (pthread_testcancel(), getgrgid(__VA_ARGS__))
#define getgrgid_r(...) (pthread_testcancel(), getgrgid_r(__VA_ARGS__))
#define gergrnam(...) (pthread_testcancel(), getgrnam(__VA_ARGS__))
#define getgrnam_r(...) (pthread_testcancel(), getgrnam_r(__VA_ARGS__))
#define gethostbyaddr(...) (pthread_testcancel(), gethostbyaddr(__VA_ARGS__))
#define gethostbyname(...) (pthread_testcancel(), gethostbyname(__VA_ARGS__))
#define gethostent(...) (pthread_testcancel(), gethostent(__VA_ARGS__))
#define gethostid(...) (pthread_testcancel(), gethostid(__VA_ARGS__))
#define gethostname(...) (pthread_testcancel(), gethostname(__VA_ARGS__))
#define getlogin(...) (pthread_testcancel(), getlogin(__VA_ARGS__))
#define getlogin_r(...) (pthread_testcancel(), getlogin_r(__VA_ARGS__))
#define getnameinfo(...) (pthread_testcancel(), getnameinfo(__VA_ARGS__))
#define getnetbyaddr(...) (pthread_testcancel(), getnetbyaddr(__VA_ARGS__))
#define getnetbyname(...) (pthread_testcancel(), getnetbyname(__VA_ARGS__))
#define getnetent(...) (pthread_testcancel(), getnetent(__VA_ARGS__))
#define getopt(...) (pthread_testcancel(), getopt(__VA_ARGS__))
#define getprotobyname(...) (pthread_testcancel(), getprotobyname(__VA_ARGS__))
#define getprotobynumber(...) (pthread_testcancel(), getprotobynumber(__VA_ARGS__))
#define getprotoent(...) (pthread_testcancel(), getprotoent(__VA_ARGS__))
#define getpwent(...) (pthread_testcancel(), getpwent(__VA_ARGS__))
#define getpwnam(...) (pthread_testcancel(), getpwnam(__VA_ARGS__))
#define getpwnam_r(...) (pthread_testcancel(), getpwnam_r(__VA_ARGS__))
#define getpwuid(...) (pthread_testcancel(), getpwuid(__VA_ARGS__))
#define getpwuid_r(...) (pthread_testcancel(), getpwuid_r(__VA_ARGS__))
#define gets(...) (pthread_testcancel(), gets(__VA_ARGS__))
#define getservbyname(...) (pthread_testcancel(), getservbyname(__VA_ARGS__))
#define getservbyport(...) (pthread_testcancel(), getservbyport(__VA_ARGS__))
#define getservent(...) (pthread_testcancel(), getservent(__VA_ARGS__))
#define getutxent(...) (pthread_testcancel(), getutxent(__VA_ARGS__))
#define getutxid(...) (pthread_testcancel(), getutxid(__VA_ARGS__))
#define getutxline(...) (pthread_testcancel(), getutxline(__VA_ARGS__))
#undef getwc
#define getwc(...) (pthread_testcancel(), getwc(__VA_ARGS__))
#undef getwchar
#define getwchar(...) (pthread_testcancel(), getwchar(__VA_ARGS__))
#define getwd(...) (pthread_testcancel(), getwd(__VA_ARGS__))
#define glob(...) (pthread_testcancel(), glob(__VA_ARGS__))
#define iconv_close(...) (pthread_testcancel(), iconv_close(__VA_ARGS__))
#define iconv_open(...) (pthread_testcancel(), iconv_open(__VA_ARGS__))
#define ioctl(...) (pthread_testcancel(), ioctl(__VA_ARGS__))
#define link(...) (pthread_testcancel(), link(__VA_ARGS__))
#define localtime(...) (pthread_testcancel(), localtime(__VA_ARGS__))
#define lseek(...) (pthread_testcancel(), lseek(__VA_ARGS__))
#define lstat(...) (pthread_testcancel(), lstat(__VA_ARGS__))
#define mkstemp(...) (pthread_testcancel(), mkstemp(__VA_ARGS__))
#define nftw(...) (pthread_testcancel(), nftw(__VA_ARGS__))
#define opendir(...) (pthread_testcancel(), opendir(__VA_ARGS__))
#define openlog(...) (pthread_testcancel(), openlog(__VA_ARGS__))
#define pathconf(...) (pthread_testcancel(), pathconf(__VA_ARGS__))
#define pclose(...) (pthread_testcancel(), pclose(__VA_ARGS__))
#define perror(...) (pthread_testcancel(), perror(__VA_ARGS__))
#define popen(...) (pthread_testcancel(), popen(__VA_ARGS__))
#define posix_fadvise(...) (pthread_testcancel(), posix_fadvise(__VA_ARGS__))
#define posix_fallocate(...) (pthread_testcancel(), posix_fallocate(__VA_ARGS__))
#define posix_madvise(...) (pthread_testcancel(), posix_madvise(__VA_ARGS__))
#define posix_openpt(...) (pthread_testcancel(), posix_openpt(__VA_ARGS__))
#define posix_spawn(...) (pthread_testcancel(), posix_spawn(__VA_ARGS__))
#define posix_spawnp(...) (pthread_testcancel(), posix_spawnp(__VA_ARGS__))
#define posix_trace_clear(...) (pthread_testcancel(), posix_trace_clear(__VA_ARGS__))
#define posix_trace_close(...) (pthread_testcancel(), posix_trace_close(__VA_ARGS__))
#define posix_trace_create(...) (pthread_testcancel(), posix_trace_create(__VA_ARGS__))
#define posix_trace_create_withlog(...) (pthread_testcancel(), posix_trace_create_withlog(__VA_ARGS__))
#define posix_trace_eventtypelist_getne(...) (pthread_testcancel(), posix_trace_eventtypelist_getne(__VA_ARGS__))
#define posix_trace_eventtypelist_rewin(...) (pthread_testcancel(), posix_trace_eventtypelist_rewin(__VA_ARGS__))
#define posix_trace_flush(...) (pthread_testcancel(), posix_trace_flush(__VA_ARGS__))
#define posix_trace_get_attr(...) (pthread_testcancel(), posix_trace_get_attr(__VA_ARGS__))
#define posix_trace_get_filter(...) (pthread_testcancel(), posix_trace_get_filter(__VA_ARGS__))
#define posix_trace_get_status(...) (pthread_testcancel(), posix_trace_get_status(__VA_ARGS__))
#define posix_trace_getnext_event(...) (pthread_testcancel(), posix_trace_getnext_event(__VA_ARGS__))
#define posix_trace_open(...) (pthread_testcancel(), posix_trace_open(__VA_ARGS__))
#define posix_trace_rewind(...) (pthread_testcancel(), posix_trace_rewind(__VA_ARGS__))
#define posix_trace_setfilter(...) (pthread_testcancel(), posix_trace_setfilter(__VA_ARGS__))
#define posix_trace_shutdown(...) (pthread_testcancel(), posix_trace_shutdown(__VA_ARGS__))
#define posix_trace_timedgetnext_event(...) (pthread_testcancel(), posix_trace_timedgetnext_event(__VA_ARGS__))
#define posix_typed_mem_open(...) (pthread_testcancel(), posix_typed_mem_open(__VA_ARGS__))
#define printf(...) (pthread_testcancel(), printf(__VA_ARGS__))
#define putc(...) (pthread_testcancel(), putc(__VA_ARGS__))
#define putc_unlocked(...) (pthread_testcancel(), putc_unlocked(__VA_ARGS__))
#define putchar(...) (pthread_testcancel(), putchar(__VA_ARGS__))
#define putchar_unlocked(...) (pthread_testcancel(), putchar_unlocked(__VA_ARGS__))
#define puts(...) (pthread_testcancel(), puts(__VA_ARGS__))
#define pututxline(...) (pthread_testcancel(), pututxline(__VA_ARGS__))
#undef putwc
#define putwc(...) (pthread_testcancel(), putwc(__VA_ARGS__))
#undef putwchar
#define putwchar(...) (pthread_testcancel(), putwchar(__VA_ARGS__))
#define readdir(...) (pthread_testcancel(), readdir(__VA_ARSG__))
#define readdir_r(...) (pthread_testcancel(), readdir_r(__VA_ARGS__))
#define remove(...) (pthread_testcancel(), remove(__VA_ARGS__))
#define rename(...) (pthread_testcancel(), rename(__VA_ARGS__))
#define rewind(...) (pthread_testcancel(), rewind(__VA_ARGS__))
#define rewinddir(...) (pthread_testcancel(), rewinddir(__VA_ARGS__))
#define scanf(...) (pthread_testcancel(), scanf(__VA_ARGS__))
#define seekdir(...) (pthread_testcancel(), seekdir(__VA_ARGS__))
#define semop(...) (pthread_testcancel(), semop(__VA_ARGS__))
#define setgrent(...) (pthread_testcancel(), setgrent(__VA_ARGS__))
#define sethostent(...) (pthread_testcancel(), sethostemt(__VA_ARGS__))
#define setnetent(...) (pthread_testcancel(), setnetent(__VA_ARGS__))
#define setprotoent(...) (pthread_testcancel(), setprotoent(__VA_ARGS__))
#define setpwent(...) (pthread_testcancel(), setpwent(__VA_ARGS__))
#define setservent(...) (pthread_testcancel(), setservent(__VA_ARGS__))
#define setutxent(...) (pthread_testcancel(), setutxent(__VA_ARGS__))
#define stat(...) (pthread_testcancel(), stat(__VA_ARGS__))
#define strerror(...) (pthread_testcancel(), strerror(__VA_ARGS__))
#define strerror_r(...) (pthread_testcancel(), strerror_r(__VA_ARGS__))
#define strftime(...) (pthread_testcancel(), strftime(__VA_ARGS__))
#define symlink(...) (pthread_testcancel(), symlink(__VA_ARGS__))
#define sync(...) (pthread_testcancel(), sync(__VA_ARGS__))
#define syslog(...) (pthread_testcancel(), syslog(__VA_ARGS__))
#define tmpfile(...) (pthread_testcancel(), tmpfile(__VA_ARGS__))
#define tmpnam(...) (pthread_testcancel(), tmpnam(__VA_ARGS__))
#define ttyname(...) (pthread_testcancel(), ttyname(__VA_ARGS__))
#define ttyname_r(...) (pthread_testcancel(), ttyname_r(__VA_ARGS__))
#define tzset(...) (pthread_testcancel(), tzset(__VA_ARGS__))
#define ungetc(...) (pthread_testcancel(), ungetc(__VA_ARGS__))
#define ungetwc(...) (pthread_testcancel(), ungetwc(__VA_ARGS__))
#define unlink(...) (pthread_testcancel(), unlink(__VA_ARGS__))
#define vfprintf(...) (pthread_testcancel(), vfprintf(__VA_ARGS__))
#define vfwprintf(...) (pthread_testcancel(), vfwprintf(__VA_ARGS__))
#define vprintf(...) (pthread_testcancel(), vprintf(__VA_ARGS__))
#define vwprintf(...) (pthread_testcancel(), vwprintf(__VA_ARGS__))
#define wcsftime(...) (pthread_testcancel(), wcsftime(__VA_ARGS__))
#define wordexp(...) (pthread_testcancel(), wordexp(__VA_ARGS__))
#define wprintf(...) (pthread_testcancel(), wprintf(__VA_ARGS__))
#define wscanf(...) (pthread_testcancel(), wscanf(__VA_ARGS__))
#endif

/* We deal here with a gcc issue for posix threading on Windows.
   We would need to change here gcc's gthr-posix.h header, but this
   got rejected.  So we deal it within this header.  */
#ifdef _GTHREAD_USE_MUTEX_INIT_FUNC
#undef _GTHREAD_USE_MUTEX_INIT_FUNC
#endif
#define _GTHREAD_USE_MUTEX_INIT_FUNC 1

#ifdef __cplusplus
}
#endif

#endif /* WIN_PTHREADS_H */
