/*
 * Copyright (c) 2000-2012 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * Copyright 1996 1995 by Open Software Foundation, Inc. 1997 1996 1995 1994 1993 1992 1991
 *              All Rights Reserved
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appears in all copies and
 * that both the copyright notice and this permission notice appear in
 * supporting documentation.
 *
 * OSF DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE.
 *
 * IN NO EVENT SHALL OSF BE LIABLE FOR ANY SPECIAL, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
 * LOSS OF USE, DATA OR PROFITS, WHETHER IN ACTION OF CONTRACT,
 * NEGLIGENCE, OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
 * WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
/*
 * MkLinux
 */

/*
 * POSIX Threads - IEEE 1003.1c
 */

#ifndef _PTHREAD_H
#define _PTHREAD_H

#include <_types.h>
#include <pthread/sched.h>
#include <time.h>
#include <sys/_pthread/_pthread_types.h>
#include <sys/_pthread/_pthread_attr_t.h>
#include <sys/_pthread/_pthread_cond_t.h>
#include <sys/_pthread/_pthread_condattr_t.h>
#include <sys/_pthread/_pthread_key_t.h>
#include <sys/_pthread/_pthread_mutex_t.h>
#include <sys/_pthread/_pthread_mutexattr_t.h>
#include <sys/_pthread/_pthread_once_t.h>
#include <sys/_pthread/_pthread_rwlock_t.h>
#include <sys/_pthread/_pthread_rwlockattr_t.h>
#include <sys/_pthread/_pthread_t.h>

#include <pthread/qos.h>

#if (!defined(_POSIX_C_SOURCE) && !defined(_XOPEN_SOURCE)) || defined(_DARWIN_C_SOURCE) || defined(__cplusplus)

#include <sys/_types/_mach_port_t.h>
#include <sys/_types/_sigset_t.h>

#endif /* (!_POSIX_C_SOURCE && !_XOPEN_SOURCE) || _DARWIN_C_SOURCE || __cplusplus */

/*
 * These symbols indicate which [optional] features are available
 * They can be tested at compile time via '#ifdef XXX'
 * The way to check for pthreads is like so:

 * #include <unistd.h>
 * #ifdef _POSIX_THREADS
 * #include <pthread.h>
 * #endif

 */

/* These will be moved to unistd.h */

/*
 * Note: These data structures are meant to be opaque.  Only enough
 * structure is exposed to support initializers.
 * All of the typedefs will be moved to <sys/types.h>
 */

#include <sys/cdefs.h>
#include <Availability.h>

#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull begin")
#endif
__BEGIN_DECLS
/*
 * Threads
 */


/*
 * Cancel cleanup handler management.  Note, since these are implemented as macros,
 * they *MUST* occur in matched pairs!
 */

#define pthread_cleanup_push(func, val) \
   { \
	     struct __darwin_pthread_handler_rec __handler; \
	     pthread_t __self = pthread_self(); \
	     __handler.__routine = func; \
	     __handler.__arg = val; \
	     __handler.__next = __self->__cleanup_stack; \
	     __self->__cleanup_stack = &__handler;

#define pthread_cleanup_pop(execute) \
	     /* Note: 'handler' must be in this same lexical context! */ \
	     __self->__cleanup_stack = __handler.__next; \
	     if (execute) (__handler.__routine)(__handler.__arg); \
   }

/*
 * Thread attributes
 */

#define PTHREAD_CREATE_JOINABLE      1
#define PTHREAD_CREATE_DETACHED      2

#define PTHREAD_INHERIT_SCHED        1
#define PTHREAD_EXPLICIT_SCHED       2

#define PTHREAD_CANCEL_ENABLE        0x01  /* Cancel takes place at next cancellation point */
#define PTHREAD_CANCEL_DISABLE       0x00  /* Cancel postponed */
#define PTHREAD_CANCEL_DEFERRED      0x02  /* Cancel waits until cancellation point */
#define PTHREAD_CANCEL_ASYNCHRONOUS  0x00  /* Cancel occurs immediately */

/* Value returned from pthread_join() when a thread is canceled */
#define PTHREAD_CANCELED	     ((void *) 1)

/* We only support PTHREAD_SCOPE_SYSTEM */
#define PTHREAD_SCOPE_SYSTEM         1
#define PTHREAD_SCOPE_PROCESS        2

#define PTHREAD_PROCESS_SHARED         1
#define PTHREAD_PROCESS_PRIVATE        2

/*
 * Mutex protocol attributes
 */
#define PTHREAD_PRIO_NONE            0
#define PTHREAD_PRIO_INHERIT         1
#define PTHREAD_PRIO_PROTECT         2

/*
 * Mutex type attributes
 */
#define PTHREAD_MUTEX_NORMAL		0
#define PTHREAD_MUTEX_ERRORCHECK	1
#define PTHREAD_MUTEX_RECURSIVE		2
#define PTHREAD_MUTEX_DEFAULT		PTHREAD_MUTEX_NORMAL

/*
 * Mutex policy attributes
 */
#define PTHREAD_MUTEX_POLICY_FAIRSHARE_NP   1
#define PTHREAD_MUTEX_POLICY_FIRSTFIT_NP    3

/*
 * RWLock variables
 */
#define PTHREAD_RWLOCK_INITIALIZER {_PTHREAD_RWLOCK_SIG_init, {0}}

/*
 * Mutex variables
 */
#define PTHREAD_MUTEX_INITIALIZER {_PTHREAD_MUTEX_SIG_init, {0}}

/* <rdar://problem/10854763> */
#if ((__MAC_OS_X_VERSION_MIN_REQUIRED && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070) || (__IPHONE_OS_VERSION_MIN_REQUIRED && __IPHONE_OS_VERSION_MIN_REQUIRED >= 50000)) || defined(__DRIVERKIT_VERSION_MIN_REQUIRED)
#	if (!defined(_POSIX_C_SOURCE) && !defined(_XOPEN_SOURCE)) || defined(_DARWIN_C_SOURCE)
#		define PTHREAD_ERRORCHECK_MUTEX_INITIALIZER {_PTHREAD_ERRORCHECK_MUTEX_SIG_init, {0}}
#		define PTHREAD_RECURSIVE_MUTEX_INITIALIZER {_PTHREAD_RECURSIVE_MUTEX_SIG_init, {0}}
#	endif /* (!_POSIX_C_SOURCE && !_XOPEN_SOURCE) || _DARWIN_C_SOURCE */
#endif

/* <rdar://problem/25944576> */
#define _PTHREAD_SWIFT_IMPORTER_NULLABILITY_COMPAT \
	defined(SWIFT_CLASS_EXTRA) && (!defined(SWIFT_SDK_OVERLAY_PTHREAD_EPOCH) || (SWIFT_SDK_OVERLAY_PTHREAD_EPOCH < 1))

/*
 * Condition variable attributes
 */

/*
 * Condition variables
 */

#define PTHREAD_COND_INITIALIZER {_PTHREAD_COND_SIG_init, {0}}

/*
 * Initialization control (once) variables
 */

#define PTHREAD_ONCE_INIT {_PTHREAD_ONCE_SIG_init, {0}}

/*
 * Prototypes for all PTHREAD interfaces
 */
__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_atfork(void (* _Nullable)(void), void (* _Nullable)(void),
		void (* _Nullable)(void));

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_destroy(pthread_attr_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getdetachstate(const pthread_attr_t *, int *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getguardsize(const pthread_attr_t * __restrict, size_t * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getinheritsched(const pthread_attr_t * __restrict, int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getschedparam(const pthread_attr_t * __restrict,
		struct sched_param * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getschedpolicy(const pthread_attr_t * __restrict, int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getscope(const pthread_attr_t * __restrict, int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getstack(const pthread_attr_t * __restrict,
		void * _Nullable * _Nonnull __restrict, size_t * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getstackaddr(const pthread_attr_t * __restrict,
		void * _Nullable * _Nonnull __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_getstacksize(const pthread_attr_t * __restrict, size_t * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_init(pthread_attr_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setdetachstate(pthread_attr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setguardsize(pthread_attr_t *, size_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setinheritsched(pthread_attr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setschedparam(pthread_attr_t * __restrict,
		const struct sched_param * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setschedpolicy(pthread_attr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setscope(pthread_attr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setstack(pthread_attr_t *, void *, size_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setstackaddr(pthread_attr_t *, void *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_attr_setstacksize(pthread_attr_t *, size_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cancel(pthread_t) __DARWIN_ALIAS(pthread_cancel);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_broadcast(pthread_cond_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_destroy(pthread_cond_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_init(
		pthread_cond_t * __restrict,
		const pthread_condattr_t * _Nullable __restrict)
		__DARWIN_ALIAS(pthread_cond_init);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_signal(pthread_cond_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_timedwait(
		pthread_cond_t * __restrict, pthread_mutex_t * __restrict,
		const struct timespec * _Nullable __restrict)
		__DARWIN_ALIAS_C(pthread_cond_timedwait);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_wait(pthread_cond_t * __restrict,
		pthread_mutex_t * __restrict) __DARWIN_ALIAS_C(pthread_cond_wait);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_condattr_destroy(pthread_condattr_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_condattr_init(pthread_condattr_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_condattr_getpshared(const pthread_condattr_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_condattr_setpshared(pthread_condattr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
#if !_PTHREAD_SWIFT_IMPORTER_NULLABILITY_COMPAT
int pthread_create(pthread_t _Nullable * _Nonnull __restrict,
		const pthread_attr_t * _Nullable __restrict,
		void * _Nullable (* _Nonnull)(void * _Nullable),
		void * _Nullable __restrict);
#else
int pthread_create(pthread_t * __restrict,
		const pthread_attr_t * _Nullable __restrict,
		void *(* _Nonnull)(void *), void * _Nullable __restrict);
#endif // _PTHREAD_SWIFT_IMPORTER_NULLABILITY_COMPAT

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_detach(pthread_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_equal(pthread_t _Nullable, pthread_t _Nullable);

__API_AVAILABLE(macos(10.4), ios(2.0))
void pthread_exit(void * _Nullable) __dead2;

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_getconcurrency(void);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_getschedparam(pthread_t , int * _Nullable __restrict,
		struct sched_param * _Nullable __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
void* _Nullable pthread_getspecific(pthread_key_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_join(pthread_t , void * _Nullable * _Nullable)
		__DARWIN_ALIAS_C(pthread_join);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_key_create(pthread_key_t *, void (* _Nullable)(void *));

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_key_delete(pthread_key_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutex_destroy(pthread_mutex_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutex_getprioceiling(const pthread_mutex_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutex_init(pthread_mutex_t * __restrict,
		const pthread_mutexattr_t * _Nullable __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutex_lock(pthread_mutex_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutex_setprioceiling(pthread_mutex_t * __restrict, int,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutex_trylock(pthread_mutex_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutex_unlock(pthread_mutex_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_destroy(pthread_mutexattr_t *) __DARWIN_ALIAS(pthread_mutexattr_destroy);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_getprioceiling(const pthread_mutexattr_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_getprotocol(const pthread_mutexattr_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_getpshared(const pthread_mutexattr_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_gettype(const pthread_mutexattr_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.13.4), ios(11.3), watchos(4.3), tvos(11.3))
int pthread_mutexattr_getpolicy_np(const pthread_mutexattr_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_init(pthread_mutexattr_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_setprotocol(pthread_mutexattr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_setpshared(pthread_mutexattr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_mutexattr_settype(pthread_mutexattr_t *, int);

__API_AVAILABLE(macos(10.7), ios(5.0))
int pthread_mutexattr_setpolicy_np(pthread_mutexattr_t *, int);

__SWIFT_UNAVAILABLE_MSG("Use lazily initialized globals instead")
__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_once(pthread_once_t *, void (* _Nonnull)(void));

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlock_destroy(pthread_rwlock_t * ) __DARWIN_ALIAS(pthread_rwlock_destroy);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlock_init(pthread_rwlock_t * __restrict,
		const pthread_rwlockattr_t * _Nullable __restrict)
		__DARWIN_ALIAS(pthread_rwlock_init);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlock_rdlock(pthread_rwlock_t *) __DARWIN_ALIAS(pthread_rwlock_rdlock);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlock_tryrdlock(pthread_rwlock_t *) __DARWIN_ALIAS(pthread_rwlock_tryrdlock);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlock_trywrlock(pthread_rwlock_t *) __DARWIN_ALIAS(pthread_rwlock_trywrlock);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlock_wrlock(pthread_rwlock_t *) __DARWIN_ALIAS(pthread_rwlock_wrlock);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlock_unlock(pthread_rwlock_t *) __DARWIN_ALIAS(pthread_rwlock_unlock);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlockattr_destroy(pthread_rwlockattr_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlockattr_getpshared(const pthread_rwlockattr_t * __restrict,
		int * __restrict);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlockattr_init(pthread_rwlockattr_t *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *, int);

__API_AVAILABLE(macos(10.4), ios(2.0))
pthread_t pthread_self(void);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_setcancelstate(int , int * _Nullable)
		__DARWIN_ALIAS(pthread_setcancelstate);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_setcanceltype(int , int * _Nullable)
		__DARWIN_ALIAS(pthread_setcanceltype);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_setconcurrency(int);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_setschedparam(pthread_t, int, const struct sched_param *);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_setspecific(pthread_key_t , const void * _Nullable);

__API_AVAILABLE(macos(10.4), ios(2.0))
void pthread_testcancel(void) __DARWIN_ALIAS(pthread_testcancel);

#if (!defined(_POSIX_C_SOURCE) && !defined(_XOPEN_SOURCE)) || defined(_DARWIN_C_SOURCE) || defined(__cplusplus)

/* returns non-zero if pthread_create or cthread_fork have been called */
__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_is_threaded_np(void);

__API_AVAILABLE(macos(10.6), ios(3.2))
int pthread_threadid_np(pthread_t _Nullable,__uint64_t* _Nullable);

/*SPI to set and get pthread name*/
__API_AVAILABLE(macos(10.6), ios(3.2))
int	pthread_getname_np(pthread_t,char*,size_t);

__API_AVAILABLE(macos(10.6), ios(3.2))
int	pthread_setname_np(const char*);

/* returns non-zero if the current thread is the main thread */
__API_AVAILABLE(macos(10.4), ios(2.0))
int	pthread_main_np(void);

/* return the mach thread bound to the pthread */
__API_AVAILABLE(macos(10.4), ios(2.0))
mach_port_t pthread_mach_thread_np(pthread_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
size_t pthread_get_stacksize_np(pthread_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
void* pthread_get_stackaddr_np(pthread_t);

/* Like pthread_cond_signal(), but only wake up the specified pthread */
__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_signal_thread_np(pthread_cond_t *, pthread_t _Nullable);

/* Like pthread_cond_timedwait, but use a relative timeout */
__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_cond_timedwait_relative_np(pthread_cond_t *, pthread_mutex_t *,
		const struct timespec * _Nullable);

/* Like pthread_create(), but leaves the thread suspended */
__API_AVAILABLE(macos(10.4), ios(2.0))
#if !_PTHREAD_SWIFT_IMPORTER_NULLABILITY_COMPAT
int pthread_create_suspended_np(
		pthread_t _Nullable * _Nonnull, const pthread_attr_t * _Nullable,
		void * _Nullable (* _Nonnull)(void * _Nullable), void * _Nullable);
#else
int pthread_create_suspended_np(pthread_t *, const pthread_attr_t * _Nullable,
		void *(* _Nonnull)(void *), void * _Nullable);
#endif

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_kill(pthread_t, int);

__API_AVAILABLE(macos(10.5), ios(2.0))
_Nullable pthread_t pthread_from_mach_thread_np(mach_port_t);

__API_AVAILABLE(macos(10.4), ios(2.0))
int pthread_sigmask(int, const sigset_t * _Nullable, sigset_t * _Nullable)
		__DARWIN_ALIAS(pthread_sigmask);

__API_AVAILABLE(macos(10.4), ios(2.0))
void pthread_yield_np(void);

__API_AVAILABLE(macos(11.0))
__API_UNAVAILABLE(ios, tvos, watchos, driverkit)
void pthread_jit_write_protect_np(int enabled);

__API_AVAILABLE(macos(11.0))
__API_UNAVAILABLE(ios, tvos, watchos, driverkit)
int pthread_jit_write_protect_supported_np(void);

/*!
 * @function pthread_cpu_number_np
 *
 * @param cpu_number_out
 * The CPU number that the thread was running on at the time of query.
 * This cpu number is in the interval [0, ncpus) (from sysctlbyname("hw.ncpu"))
 *
 * @result
 * This function returns 0 or the value of errno if an error occurred.
 *
 * @note
 * Optimizations of per-CPU datastructures based on the result of this function
 * still require synchronization since it is not guaranteed that the thread will
 * still be on the same CPU by the time the function returns.
 */
__API_AVAILABLE(macos(11.0), ios(14.2), tvos(14.2), watchos(7.1))
int
pthread_cpu_number_np(size_t *cpu_number_out);

#endif /* (!_POSIX_C_SOURCE && !_XOPEN_SOURCE) || _DARWIN_C_SOURCE || __cplusplus */
__END_DECLS
#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull end")
#endif

#endif /* _PTHREAD_H */