/* Posix threads.  Hurd version.
   Copyright (C) 2000-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library;  if not, see
   <https://www.gnu.org/licenses/>.  */

/*
 *	POSIX Threads Extension: ???			<pthread.h>
 */

#ifndef _PTHREAD_H
#define _PTHREAD_H	1

#include <features.h>

#include <sys/cdefs.h>
#ifndef __extern_inline
/* GCC 4.3 and above with -std=c99 or -std=gnu99 implements ISO C99
   inline semantics, unless -fgnu89-inline is used.  */
# if !defined __cplusplus || __GNUC_PREREQ (4,3)
#  if defined __GNUC_STDC_INLINE__ || defined __cplusplus
#   define __extern_inline extern __inline __attribute__ ((__gnu_inline__))
#   if __GNUC_PREREQ (4,3)
#    define __extern_always_inline \
   extern __always_inline __attribute__ ((__gnu_inline__, __artificial__))
#   else
#    define __extern_always_inline \
   extern __always_inline __attribute__ ((__gnu_inline__))
#   endif
#  else
#   define __extern_inline extern __inline
#   define __extern_always_inline extern __always_inline
#  endif
# endif
#endif

#include <sched.h>
#include <time.h>

__BEGIN_DECLS

#include <bits/pthreadtypes.h>

#include <bits/pthread.h>

/* Possible values for the process shared attribute.  */
#define PTHREAD_PROCESS_PRIVATE __PTHREAD_PROCESS_PRIVATE
#define PTHREAD_PROCESS_SHARED __PTHREAD_PROCESS_SHARED


/* Thread attributes.  */

/* Possible values for the inheritsched attribute.  */
#define PTHREAD_EXPLICIT_SCHED __PTHREAD_EXPLICIT_SCHED
#define PTHREAD_INHERIT_SCHED __PTHREAD_INHERIT_SCHED

/* Possible values for the `contentionscope' attribute.  */
#define PTHREAD_SCOPE_SYSTEM __PTHREAD_SCOPE_SYSTEM
#define PTHREAD_SCOPE_PROCESS __PTHREAD_SCOPE_PROCESS

/* Possible values for the `detachstate' attribute.  */
#define PTHREAD_CREATE_JOINABLE __PTHREAD_CREATE_JOINABLE
#define PTHREAD_CREATE_DETACHED __PTHREAD_CREATE_DETACHED

#include <bits/types/struct___pthread_attr.h>

/* Initialize the thread attribute object in *ATTR to the default
   values.  */
extern int pthread_attr_init (pthread_attr_t *__attr) __THROW __nonnull ((1));

/* Destroy the thread attribute object in *ATTR.  */
extern int pthread_attr_destroy (pthread_attr_t *__attr)
	__THROW __nonnull ((1));


/* Return the value of the inheritsched attribute in *ATTR in
   *INHERITSCHED.  */
extern int pthread_attr_getinheritsched (const pthread_attr_t *__restrict __attr,
					 int *__restrict __inheritsched)
	__THROW __nonnull ((1, 2));

/* Set the value of the inheritsched attribute in *ATTR to
   INHERITSCHED.  */
extern int pthread_attr_setinheritsched (pthread_attr_t *__attr,
					 int __inheritsched)
	__THROW __nonnull ((1));


/* Return the value of the schedparam attribute in *ATTR in *PARAM.  */
extern int pthread_attr_getschedparam (const pthread_attr_t *__restrict __attr,
				       struct sched_param *__restrict __param)
	__THROW __nonnull ((1, 2));

/* Set the value of the schedparam attribute in *ATTR to PARAM.  */
extern int pthread_attr_setschedparam (pthread_attr_t *__restrict __attr,
				       const struct sched_param *__restrict
				       __param) __THROW __nonnull ((1, 2));


/* Return the value of the schedpolicy attribute in *ATTR to *POLICY.  */
extern int pthread_attr_getschedpolicy (const pthread_attr_t *__restrict __attr,
					int *__restrict __policy)
	__THROW __nonnull ((1, 2));

/* Set the value of the schedpolicy attribute in *ATTR to POLICY.  */
extern int pthread_attr_setschedpolicy (pthread_attr_t *__attr,
					int __policy)
	__THROW __nonnull ((1));


/* Return the value of the contentionscope attribute in *ATTR in
   *CONTENTIONSCOPE.  */
extern int pthread_attr_getscope (const pthread_attr_t *__restrict __attr,
				  int *__restrict __contentionscope)
	__THROW __nonnull ((1, 2));

/* Set the value of the contentionscope attribute in *ATTR to
   CONTENTIONSCOPE.  */
extern int pthread_attr_setscope (pthread_attr_t *__attr,
				  int __contentionscope)
	__THROW __nonnull ((1));


/* Return the value of the stackaddr attribute in *ATTR in
   *STACKADDR.  */
extern int pthread_attr_getstackaddr (const pthread_attr_t *__restrict __attr,
				      void **__restrict __stackaddr)
	__THROW __nonnull ((1, 2));

/* Set the value of the stackaddr attribute in *ATTR to STACKADDR.  */
extern int pthread_attr_setstackaddr (pthread_attr_t *__attr,
				      void *__stackaddr)
	__THROW __nonnull ((1));


#ifdef __USE_XOPEN2K
/* Return the value of the stackaddr and stacksize attributes in *ATTR
   in *STACKADDR and *STACKSIZE respectively.  */
extern int pthread_attr_getstack (const pthread_attr_t *__restrict __attr,
				  void **__restrict __stackaddr,
				  size_t *__restrict __stacksize)
	__THROW __nonnull ((1, 2, 3));

/* Set the value of the stackaddr and stacksize attributes in *ATTR to
   STACKADDR and STACKSIZE respectively.  */
extern int pthread_attr_setstack (pthread_attr_t *__attr,
				  void *__stackaddr,
				  size_t __stacksize)
	__THROW __nonnull ((1));
#endif


/* Return the value of the detachstate attribute in *ATTR in
   *DETACHSTATE.  */
extern int pthread_attr_getdetachstate (const pthread_attr_t *__attr,
					int *__detachstate)
	__THROW __nonnull ((1, 2));

/* Set the value of the detachstate attribute in *ATTR to
   DETACHSTATE.  */
extern int pthread_attr_setdetachstate (pthread_attr_t *__attr,
					int __detachstate)
	__THROW __nonnull ((1));


/* Return the value of the guardsize attribute in *ATTR in
   *GUARDSIZE.  */
extern int pthread_attr_getguardsize (const pthread_attr_t *__restrict __attr,
				      size_t *__restrict __guardsize)
	__THROW __nonnull ((1, 2));

/* Set the value of the guardsize attribute in *ATTR to GUARDSIZE.  */
extern int pthread_attr_setguardsize (pthread_attr_t *__attr,
				      size_t __guardsize)
	__THROW __nonnull ((1));


/* Return the value of the stacksize attribute in *ATTR in
   *STACKSIZE.  */
extern int pthread_attr_getstacksize (const pthread_attr_t *__restrict __attr,
				      size_t *__restrict __stacksize)
	__THROW __nonnull ((1, 2));

/* Set the value of the stacksize attribute in *ATTR to STACKSIZE.  */
extern int pthread_attr_setstacksize (pthread_attr_t *__attr,
				      size_t __stacksize)
	__THROW __nonnull ((1));

#ifdef __USE_GNU
/* Initialize thread attribute *ATTR with attributes corresponding to the
   already running thread THREAD.  It shall be called on an uninitialized ATTR
   and destroyed with pthread_attr_destroy when no longer needed.  */
extern int pthread_getattr_np (pthread_t __thr, pthread_attr_t *__attr)
	__THROW __nonnull ((2));
#endif


/* Create a thread with attributes given by ATTR, executing
   START_ROUTINE with argument ARG.  */
extern int pthread_create (pthread_t *__restrict __threadp,
			   __const pthread_attr_t *__restrict __attr,
			   void *(*__start_routine)(void *),
			   void *__restrict __arg) __THROWNL __nonnull ((1, 3));

/* Terminate the current thread and make STATUS available to any
   thread that might join us.  */
extern void pthread_exit (void *__status) __attribute__ ((__noreturn__));

/* Make calling thread wait for termination of thread THREAD.  Return
   the exit status of the thread in *STATUS.  */
extern int pthread_join (pthread_t __threadp, void **__status);

/* Indicate that the storage for THREAD can be reclaimed when it
   terminates.  */
extern int pthread_detach (pthread_t __threadp);

/* Compare thread IDs T1 and T2.  Return nonzero if they are equal, 0
   if they are not.  */
extern int pthread_equal (pthread_t __t1, pthread_t __t2);

#ifdef __USE_EXTERN_INLINES

__extern_inline int
pthread_equal (pthread_t __t1, pthread_t __t2)
{
  return __pthread_equal (__t1, __t2);
}

#endif /* Use extern inlines.  */


/* Return the thread ID of the calling thread.  */
extern pthread_t pthread_self (void) __THROW;


/* Mutex attributes.  */

#define PTHREAD_PRIO_NONE_NP __PTHREAD_PRIO_NONE
#define PTHREAD_PRIO_INHERIT_NP __PTHREAD_PRIO_INHERIT
#define PTHREAD_PRIO_PROTECT_NP __PTHREAD_PRIO_PROTECT
#ifdef __USE_UNIX98
# define PTHREAD_PRIO_NONE PTHREAD_PRIO_NONE_NP
# define PTHREAD_PRIO_INHERIT PTHREAD_PRIO_INHERIT_NP
# define PTHREAD_PRIO_PROTECT PTHREAD_PRIO_PROTECT_NP
#endif

#define PTHREAD_MUTEX_TIMED_NP __PTHREAD_MUTEX_TIMED
#define PTHREAD_MUTEX_ERRORCHECK_NP __PTHREAD_MUTEX_ERRORCHECK
#define PTHREAD_MUTEX_RECURSIVE_NP __PTHREAD_MUTEX_RECURSIVE
#if defined __USE_UNIX98 || defined __USE_XOPEN2K8
# define PTHREAD_MUTEX_NORMAL PTHREAD_MUTEX_TIMED_NP
# define PTHREAD_MUTEX_ERRORCHECK PTHREAD_MUTEX_ERRORCHECK_NP
# define PTHREAD_MUTEX_RECURSIVE PTHREAD_MUTEX_RECURSIVE_NP
# define PTHREAD_MUTEX_DEFAULT PTHREAD_MUTEX_NORMAL
#endif
#ifdef __USE_GNU
/* For compatibility.  */
# define PTHREAD_MUTEX_FAST_NP PTHREAD_MUTEX_TIMED_NP
#endif

#ifdef __USE_XOPEN2K
# define PTHREAD_MUTEX_STALLED __PTHREAD_MUTEX_STALLED
# define PTHREAD_MUTEX_ROBUST __PTHREAD_MUTEX_ROBUST
#endif

#include <bits/types/struct___pthread_mutexattr.h>

/* Initialize the mutex attribute object in *ATTR to the default
   values.  */
extern int pthread_mutexattr_init(pthread_mutexattr_t *__attr)
	__THROW __nonnull ((1));

/* Destroy the mutex attribute structure in *ATTR.  */
extern int pthread_mutexattr_destroy(pthread_mutexattr_t *__attr)
	__THROW __nonnull ((1));


#ifdef __USE_UNIX98
/* Return the value of the prioceiling attribute in *ATTR in
   *PRIOCEILING.  */
extern int pthread_mutexattr_getprioceiling(const pthread_mutexattr_t *__restrict __attr,
					    int *__restrict __prioceiling)
	__THROW __nonnull ((1, 2));

/* Set the value of the prioceiling attribute in *ATTR to
   PRIOCEILING.  */
extern int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *__attr,
					    int __prioceiling)
	__THROW __nonnull ((1));


/* Return the value of the protocol attribute in *ATTR in
   *PROTOCOL.  */
extern int pthread_mutexattr_getprotocol(const pthread_mutexattr_t *__restrict __attr,
					 int *__restrict __protocol)
	__THROW __nonnull ((1, 2));

/* Set the value of the protocol attribute in *ATTR to PROTOCOL.  */
extern int pthread_mutexattr_setprotocol(pthread_mutexattr_t *__attr,
					 int __protocol)
	__THROW __nonnull ((1));
#endif

#ifdef __USE_XOPEN2K
/* Get the robustness flag of the mutex attribute ATTR.  */
extern int pthread_mutexattr_getrobust (const pthread_mutexattr_t *__attr,
					int *__robustness)
     __THROW __nonnull ((1, 2));
# ifdef __USE_GNU
extern int pthread_mutexattr_getrobust_np (const pthread_mutexattr_t *__attr,
					   int *__robustness)
     __THROW __nonnull ((1, 2));
# endif

/* Set the robustness flag of the mutex attribute ATTR.  */
extern int pthread_mutexattr_setrobust (pthread_mutexattr_t *__attr,
					int __robustness)
     __THROW __nonnull ((1));
# ifdef __USE_GNU
extern int pthread_mutexattr_setrobust_np (pthread_mutexattr_t *__attr,
					   int __robustness)
     __THROW __nonnull ((1));
# endif
#endif


/* Return the value of the process shared attribute in *ATTR in
   *PSHARED.  */
extern int pthread_mutexattr_getpshared(const pthread_mutexattr_t *__restrict __attr,
					int *__restrict __pshared)
	__THROW __nonnull ((1, 2));

/* Set the value of the process shared attribute in *ATTR to
   PSHARED.  */
extern int pthread_mutexattr_setpshared(pthread_mutexattr_t *__attr,
					int __pshared)
	__THROW __nonnull ((1));


#if defined __USE_UNIX98 || defined __USE_XOPEN2K8
/* Return the value of the type attribute in *ATTR in *TYPE.  */
extern int pthread_mutexattr_gettype(const pthread_mutexattr_t *__restrict __attr,
				     int *__restrict __type)
	__THROW __nonnull ((1, 2));

/* Set the value of the type attribute in *ATTR to TYPE.  */
extern int pthread_mutexattr_settype(pthread_mutexattr_t *__attr,
				     int __type)
	__THROW __nonnull ((1));
#endif


/* Mutexes.  */

#include <bits/types/struct___pthread_mutex.h>

#define PTHREAD_MUTEX_INITIALIZER __PTHREAD_MUTEX_INITIALIZER
/* Static initializer for recursive mutexes.  */

#ifdef __USE_GNU
# define PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP \
  __PTHREAD_ERRORCHECK_MUTEX_INITIALIZER
# define PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP \
  __PTHREAD_RECURSIVE_MUTEX_INITIALIZER
#endif

/* Create a mutex with attributes given by ATTR and store it in
   *__MUTEX.  */
extern int pthread_mutex_init (struct __pthread_mutex *__restrict __mutex,
			       const pthread_mutexattr_t *__restrict __attr)
	__THROW __nonnull ((1));

/* Destroy the mutex __MUTEX.  */
extern int pthread_mutex_destroy (struct __pthread_mutex *__mutex)
	__THROW __nonnull ((1));

/* Wait until lock for MUTEX becomes available and lock it.  */
extern int pthread_mutex_lock (pthread_mutex_t *__mutex);

/* Try to lock MUTEX.  */
extern int pthread_mutex_trylock (pthread_mutex_t *__mutex)
	__THROWNL __nonnull ((1));

#ifdef __USE_XOPEN2K
/* Try to lock MUTEX, block until *ABSTIME if it is already held.  */
extern int pthread_mutex_timedlock (struct __pthread_mutex *__restrict __mutex,
				    const struct timespec *__restrict __abstime)
	__THROWNL __nonnull ((1, 2));
#endif

/* Unlock MUTEX.  */
extern int pthread_mutex_unlock (pthread_mutex_t *__mutex)
	__THROWNL __nonnull ((1));

/* Transfer ownership of the mutex MUTEX to the thread TID.  The
   caller must own the lock.  */
extern int __pthread_mutex_transfer_np (struct __pthread_mutex *__mutex,
					pthread_t __tid)
	__THROWNL __nonnull ((1));


#ifdef __USE_UNIX98
/* Return the priority ceiling of mutex *MUTEX in *PRIOCEILING.  */
extern int pthread_mutex_getprioceiling (const pthread_mutex_t *__restrict __mutex,
					 int *__restrict __prioceiling)
	__THROW __nonnull ((1, 2));

/* After acquiring the mutex *MUTEX, set its priority ceiling to PRIO
   and return the old priority ceiling in *OLDPRIO.  Before returning,
   release the mutex.  */
extern int pthread_mutex_setprioceiling (pthread_mutex_t *__restrict __mutex,
					 int __prio, int *__restrict __oldprio)
	__THROW __nonnull ((1, 3));
#endif

#ifdef __USE_XOPEN2K8

/* Declare the state protected by robust mutex MTXP as consistent. */
extern int pthread_mutex_consistent (pthread_mutex_t *__mtxp)
  __THROW __nonnull ((1));

#  ifdef __USE_GNU
extern int pthread_mutex_consistent_np (pthread_mutex_t *__mtxp)
  __THROW __nonnull ((1));
#  endif
#endif



/* Condition attributes.  */

#include <bits/types/struct___pthread_condattr.h>

/* Initialize the condition attribute in *ATTR to the default
   values.  */
extern int pthread_condattr_init (pthread_condattr_t *__attr)
	__THROW __nonnull ((1));

/* Destroy the condition attribute structure in *ATTR.  */
extern int pthread_condattr_destroy (pthread_condattr_t *__attr)
	__THROW __nonnull ((1));


#ifdef __USE_XOPEN2K
/* Return the value of the clock attribute in *ATTR in *CLOCK_ID.  */
extern int pthread_condattr_getclock (const pthread_condattr_t *__restrict __attr,
				      __clockid_t *__restrict __clock_id)
	__THROW __nonnull ((1, 2));

/* Set the value of the clock attribute in *ATTR to CLOCK_ID.  */
extern int pthread_condattr_setclock (pthread_condattr_t *__attr,
				      __clockid_t __clock_id)
	__THROW __nonnull ((1));
#endif


/* Return the value of the process shared attribute in *ATTR in
   *PSHARED.  */
extern int pthread_condattr_getpshared (const pthread_condattr_t *__restrict __attr,
					int *__restrict __pshared)
	__THROW __nonnull ((1, 2));

/* Set the value of the process shared attribute in *ATTR to
   PSHARED.  */
extern int pthread_condattr_setpshared (pthread_condattr_t *__attr,
					int __pshared)
	__THROW __nonnull ((1));


/* Condition variables.  */

#include <bits/types/struct___pthread_cond.h>

#define PTHREAD_COND_INITIALIZER __PTHREAD_COND_INITIALIZER

extern int pthread_cond_init (pthread_cond_t *__restrict __cond,
			      const pthread_condattr_t *__restrict __attr)
	__THROW __nonnull ((1));

extern int pthread_cond_destroy (pthread_cond_t *__cond)
	__THROW __nonnull ((1));

/* Unblock at least one of the threads that are blocked on condition
   variable COND.  */
extern int pthread_cond_signal (pthread_cond_t *__cond)
	__THROWNL __nonnull ((1));

/* Unblock all threads that are blocked on condition variable COND.  */
extern int pthread_cond_broadcast (pthread_cond_t *__cond)
	__THROWNL __nonnull ((1));

/* Block on condition variable COND.  MUTEX should be held by the
   calling thread.  On success, MUTEX will be held by the calling
   thread.  */
extern int pthread_cond_wait (pthread_cond_t *__restrict __cond,
			      pthread_mutex_t *__restrict __mutex)
	 __nonnull ((1, 2));

/* Block on condition variable COND.  MUTEX should be held by the
   calling thread. On success, MUTEX will be held by the calling
   thread.  If the time specified by ABSTIME passes, ETIMEDOUT is
   returned, and MUTEX will nevertheless be held.  */
extern int pthread_cond_timedwait (pthread_cond_t *__restrict __cond,
				   pthread_mutex_t *__restrict __mutex,
				   __const struct timespec *__restrict __abstime)
	 __nonnull ((1, 2, 3));


/* Spin locks.  */

#ifdef __USE_XOPEN2K

# include <bits/types/__pthread_spinlock_t.h>

# define PTHREAD_SPINLOCK_INITIALIZER __PTHREAD_SPIN_LOCK_INITIALIZER

/* Destroy the spin lock object LOCK.  */
extern int pthread_spin_destroy (pthread_spinlock_t *__lock)
	__nonnull ((1));

/* Initialize the spin lock object LOCK.  PSHARED determines whether
   the spin lock can be operated upon by multiple processes.  */
extern int pthread_spin_init (pthread_spinlock_t *__lock, int __pshared)
	__nonnull ((1));

/* Lock the spin lock object LOCK.  If the lock is held by another
   thread spin until it becomes available.  */
extern int pthread_spin_lock (pthread_spinlock_t *__lock)
	__nonnull ((1));

/* Lock the spin lock object LOCK.  Fail if the lock is held by
   another thread.  */
extern int pthread_spin_trylock (pthread_spinlock_t *__lock)
	__nonnull ((1));

/* Unlock the spin lock object LOCK.  */
extern int pthread_spin_unlock (pthread_spinlock_t *__lock)
	__nonnull ((1));

# if defined __USE_EXTERN_INLINES && defined _LIBC

# include <bits/spin-lock-inline.h>

__extern_inline int
pthread_spin_destroy (pthread_spinlock_t *__lock)
{
  return __pthread_spin_destroy (__lock);
}

__extern_inline int
pthread_spin_init (pthread_spinlock_t *__lock, int __pshared)
{
  return __pthread_spin_init (__lock, __pshared);
}

__extern_inline int
pthread_spin_lock (pthread_spinlock_t *__lock)
{
  return __pthread_spin_lock (__lock);
}

__extern_inline int
pthread_spin_trylock (pthread_spinlock_t *__lock)
{
  return __pthread_spin_trylock (__lock);
}

__extern_inline int
pthread_spin_unlock (pthread_spinlock_t *__lock)
{
  return __pthread_spin_unlock (__lock);
}

# endif /* Use extern inlines.  */

#endif /* XPG6.  */


/* rwlock attributes.  */

#if defined __USE_UNIX98 || defined __USE_XOPEN2K

# include <bits/types/struct___pthread_rwlockattr.h>

/* Initialize rwlock attribute object in *ATTR to the default
   values.  */
extern int pthread_rwlockattr_init (pthread_rwlockattr_t *__attr)
	__THROW __nonnull ((1));

/* Destroy the rwlock attribute object in *ATTR.  */
extern int pthread_rwlockattr_destroy (pthread_rwlockattr_t *__attr)
	__THROW __nonnull ((1));


/* Return the value of the process shared attribute in *ATTR in
   *PSHARED.  */
extern int pthread_rwlockattr_getpshared (const pthread_rwlockattr_t *__restrict __attr,
					  int *__restrict __pshared)
	__THROW __nonnull ((1, 2));

/* Set the value of the process shared atrribute in *ATTR to
   PSHARED.  */
extern int pthread_rwlockattr_setpshared (pthread_rwlockattr_t *__attr,
					  int __pshared)
	__THROW __nonnull ((1));

/* Return current setting of reader/writer preference.  */
extern int pthread_rwlockattr_getkind_np (const pthread_rwlockattr_t *
					  __restrict __attr,
					  int *__restrict __pref)
     __THROW __nonnull ((1, 2));

/* Set reader/write preference.  */
extern int pthread_rwlockattr_setkind_np (pthread_rwlockattr_t *__attr,
					  int __pref) __THROW __nonnull ((1));


/* rwlocks.  */

# include <bits/types/struct___pthread_rwlock.h>

# define PTHREAD_RWLOCK_INITIALIZER __PTHREAD_RWLOCK_INITIALIZER
/* Create a rwlock object with attributes given by ATTR and strore the
   result in *RWLOCK.  */
extern int pthread_rwlock_init (pthread_rwlock_t *__restrict __rwlock,
				const pthread_rwlockattr_t *__restrict __attr)
	__THROW __nonnull ((1));

/* Destroy the rwlock *RWLOCK.  */
extern int pthread_rwlock_destroy (pthread_rwlock_t *__rwlock)
	__THROW __nonnull ((1));

/* Acquire the rwlock *RWLOCK for reading.  */
extern int pthread_rwlock_rdlock (pthread_rwlock_t *__rwlock)
	__THROWNL __nonnull ((1));

/* Acquire the rwlock *RWLOCK for reading.  */
extern int pthread_rwlock_tryrdlock (pthread_rwlock_t *__rwlock)
	__THROWNL __nonnull ((1));

# ifdef __USE_XOPEN2K
/* Acquire the rwlock *RWLOCK for reading blocking until *ABSTIME if
   it is already held.  */
extern int pthread_rwlock_timedrdlock (struct __pthread_rwlock *__restrict __rwlock,
				       const struct timespec *__restrict __abstime)
	__THROWNL __nonnull ((1, 2));
# endif

/* Acquire the rwlock *RWLOCK for writing.  */
extern int pthread_rwlock_wrlock (pthread_rwlock_t *__rwlock)
	__THROWNL __nonnull ((1));

/* Try to acquire the rwlock *RWLOCK for writing.  */
extern int pthread_rwlock_trywrlock (pthread_rwlock_t *__rwlock)
	__THROWNL __nonnull ((1));

# ifdef __USE_XOPEN2K
/* Acquire the rwlock *RWLOCK for writing blocking until *ABSTIME if
   it is already held.  */
extern int pthread_rwlock_timedwrlock (struct __pthread_rwlock *__restrict __rwlock,
				       const struct timespec *__restrict __abstime)
	__THROWNL __nonnull ((1, 2));
# endif

/* Release the lock held by the current thread on *RWLOCK.  */
extern int pthread_rwlock_unlock (pthread_rwlock_t *__rwlock)
	__THROWNL __nonnull ((1));

#endif /* __USE_UNIX98 || __USE_XOPEN2K */



/* Cancelation.  */

/* Register a cleanup handler.  */
extern void pthread_cleanup_push (void (*__routine) (void *), void *__arg);

/* Unregister a cleanup handler.  */
extern void pthread_cleanup_pop (int __execute);

#include <bits/cancelation.h>

#define pthread_cleanup_push(rt, rtarg) __pthread_cleanup_push(rt, rtarg)
#define pthread_cleanup_pop(execute) __pthread_cleanup_pop(execute)

#define PTHREAD_CANCEL_DISABLE 0
#define PTHREAD_CANCEL_ENABLE 1

/* Return the calling thread's cancelation state in *OLDSTATE and set
   its state to STATE.  */
extern int pthread_setcancelstate (int __state, int *__oldstate);

#define PTHREAD_CANCEL_DEFERRED 0
#define PTHREAD_CANCEL_ASYNCHRONOUS 1

/* Return the calling thread's cancelation type in *OLDTYPE and set
   its type to TYPE.  */
extern int pthread_setcanceltype (int __type, int *__oldtype);

/* Value returned by pthread_join if the target thread was
   canceled.  */
#define PTHREAD_CANCELED ((void *) -1)

/* Cancel THEAD.  */
extern int pthread_cancel (pthread_t __thr);

/* Add an explicit cancelation point.  */
extern void pthread_testcancel (void);


/* Barriers attributes.  */

#ifdef __USE_XOPEN2K

# include <bits/types/struct___pthread_barrierattr.h>

/* Initialize barrier attribute object in *ATTR to the default
   values.  */
extern int pthread_barrierattr_init (pthread_barrierattr_t *__attr)
	__THROW __nonnull ((1));

/* Destroy the barrier attribute object in *ATTR.  */
extern int pthread_barrierattr_destroy (pthread_barrierattr_t *__attr)
	__THROW __nonnull ((1));


/* Return the value of the process shared attribute in *ATTR in
   *PSHARED.  */
extern int pthread_barrierattr_getpshared (const pthread_barrierattr_t *__restrict __attr,
					   int *__restrict __pshared)
	__THROW __nonnull ((1, 2));

/* Set the value of the process shared atrribute in *ATTR to
   PSHARED.  */
extern int pthread_barrierattr_setpshared (pthread_barrierattr_t *__attr,
					   int __pshared)
	__THROW __nonnull ((1));


/* Barriers.  */

# include <bits/types/struct___pthread_barrier.h>

/* Returned by pthread_barrier_wait to exactly one thread each time a
   barrier is passed.  */
# define PTHREAD_BARRIER_SERIAL_THREAD -1

/* Initialize barrier BARRIER.  */
extern int pthread_barrier_init (pthread_barrier_t *__restrict __barrier,
				const pthread_barrierattr_t *__restrict __attr,
				unsigned __count)
	__THROW __nonnull ((1));

/* Destroy barrier BARRIER.  */
extern int pthread_barrier_destroy (pthread_barrier_t *__barrier)
	__THROW __nonnull ((1));

/* Wait on barrier BARRIER.  */
extern int pthread_barrier_wait (pthread_barrier_t *__barrier)
	__THROWNL __nonnull ((1));

#endif /* __USE_XOPEN2K */



/* Thread specific data.  */

#include <bits/types/__pthread_key.h>

/* Create a thread specific data key in KEY visible to all threads.
   On thread destruction, DESTRUCTOR shall be called with the thread
   specific data associate with KEY if it is not NULL.  */
extern int pthread_key_create (pthread_key_t *__key,
			       void (*__destructor) (void *))
	__THROW __nonnull ((1));

/* Delete the thread specific data key KEY.  The associated destructor
   function is not called.  */
extern int pthread_key_delete (pthread_key_t __key) __THROW;

/* Return the caller thread's thread specific value of KEY.  */
extern void *pthread_getspecific (pthread_key_t __key) __THROW;

/* Set the caller thread's thread specific value of KEY to VALUE.  */
extern int pthread_setspecific (pthread_key_t __key, const void *__value)
	__THROW;


/* Dynamic package initialization.  */

#include <bits/types/struct___pthread_once.h>

#define PTHREAD_ONCE_INIT __PTHREAD_ONCE_INIT

/* Call INIT_ROUTINE if this function has never been called with
   *ONCE_CONTROL, otherwise do nothing.  */
extern int pthread_once (pthread_once_t *__once_control,
			 void (*__init_routine) (void)) __nonnull ((1, 2));


/* Concurrency.  */

#ifdef __USE_UNIX98
/* Set the desired concurrency level to NEW_LEVEL.  */
extern int pthread_setconcurrency (int __new_level) __THROW;

/* Get the current concurrency level.  */
extern int pthread_getconcurrency (void) __THROW;
#endif


/* Forking.  */

/* Register the function PREPARE to be run before the process forks,
   the function PARENT to be run after a fork in the parent and the
   function CHILD to be run in the child after the fork.  If no
   handling is desired then any of PREPARE, PARENT and CHILD may be
   NULL.  The prepare handles will be called in the reverse order
   which they were registered and the parent and child handlers in the
   order in which they were registered.  */
extern int pthread_atfork (void (*__prepare) (void), void (*__parent) (void),
			   void (*__child) (void)) __THROW;


/* Signals (should be in <signal.h>).  */

/* Send signal SIGNO to thread THREAD.  */
extern int pthread_kill (pthread_t __thr, int __signo) __THROW;


/* Time.  */

#ifdef __USE_XOPEN2K
/* Return the thread cpu clock.  */
extern int pthread_getcpuclockid (pthread_t __thr, __clockid_t *__clock)
	__THROW __nonnull ((2));
#endif


/* Scheduling.  */

/* Return thread THREAD's scheduling paramters.  */
extern int pthread_getschedparam (pthread_t __thr, int *__restrict __policy,
				  struct sched_param *__restrict __param)
	__THROW __nonnull ((2, 3));

/* Set thread THREAD's scheduling paramters.  */
extern int pthread_setschedparam (pthread_t __thr, int __policy,
				  const struct sched_param *__param)
	__THROW __nonnull ((3));

/* Set thread THREAD's scheduling priority.  */
extern int pthread_setschedprio (pthread_t __thr, int __prio) __THROW;

#ifdef __USE_GNU
/* Yield the processor to another thread or process.
   This function is similar to the POSIX `sched_yield' function but
   might be differently implemented in the case of a m-on-n thread
   implementation.  */
extern int pthread_yield (void) __THROW;
#endif


/* Kernel-specific interfaces.  */

#include <bits/pthread-np.h>


__END_DECLS

#endif /* pthread.h */
