/* Private libc-internal interface for mutex locks.
   Copyright (C) 2015-2023 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License as
   published by the Free Software Foundation; either version 2.1 of the
   License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; see the file COPYING.LIB.  If
   not, see <https://www.gnu.org/licenses/>.  */

#ifndef _BITS_LIBC_LOCKP_H
#define _BITS_LIBC_LOCKP_H 1

#include <pthread.h>
#include <pthread-functions.h>

/* If we check for a weakly referenced symbol and then perform a
   normal jump to it te code generated for some platforms in case of
   PIC is unnecessarily slow.  What would happen is that the function
   is first referenced as data and then it is called indirectly
   through the PLT.  We can make this a direct jump.  */
#ifdef __PIC__
# define __libc_maybe_call(FUNC, ARGS, ELSE) \
  (__extension__ ({ __typeof (FUNC) *_fn = (FUNC); \
		    _fn != NULL ? (*_fn) ARGS : ELSE; }))
#else
# define __libc_maybe_call(FUNC, ARGS, ELSE) \
  (FUNC != NULL ? FUNC ARGS : ELSE)
#endif

/* Call thread functions through the function pointer table.  */
#if defined SHARED && IS_IN (libc)
# define PTFAVAIL(NAME) __libc_pthread_functions_init
# define __libc_ptf_call(FUNC, ARGS, ELSE) \
  (__libc_pthread_functions_init ? PTHFCT_CALL (ptr_##FUNC, ARGS) : ELSE)
# define __libc_ptf_call_always(FUNC, ARGS) \
  PTHFCT_CALL (ptr_##FUNC, ARGS)
#elif IS_IN (libpthread)
# define PTFAVAIL(NAME) 1
# define __libc_ptf_call(FUNC, ARGS, ELSE) \
  FUNC ARGS
# define __libc_ptf_call_always(FUNC, ARGS) \
  FUNC ARGS
#else
# define PTFAVAIL(NAME) (NAME != NULL)
# define __libc_ptf_call(FUNC, ARGS, ELSE) \
  __libc_maybe_call (FUNC, ARGS, ELSE)
# define __libc_ptf_call_always(FUNC, ARGS) \
  FUNC ARGS
#endif

/* Create thread-specific key.  */
#define __libc_key_create(KEY, DESTRUCTOR) \
  __libc_ptf_call (__pthread_key_create, (KEY, DESTRUCTOR), 1)

/* Get thread-specific data.  */
#define __libc_getspecific(KEY) \
  __libc_ptf_call (__pthread_getspecific, (KEY), NULL)

/* Set thread-specific data.  */
#define __libc_setspecific(KEY, VALUE) \
  __libc_ptf_call (__pthread_setspecific, (KEY, VALUE), 0)


/* Functions that are used by this file and are internal to the GNU C
   library.  */

extern int __pthread_mutex_init (pthread_mutex_t *__mutex,
				 const pthread_mutexattr_t *__mutex_attr);

extern int __pthread_mutex_destroy (pthread_mutex_t *__mutex);

extern int __pthread_mutex_trylock (pthread_mutex_t *__mutex);

extern int __pthread_mutex_lock (pthread_mutex_t *__mutex);

extern int __pthread_mutex_unlock (pthread_mutex_t *__mutex);

extern int __pthread_mutexattr_init (pthread_mutexattr_t *__attr);

extern int __pthread_mutexattr_destroy (pthread_mutexattr_t *__attr);

extern int __pthread_mutexattr_settype (pthread_mutexattr_t *__attr,
					int __kind);

extern int __pthread_rwlock_init (pthread_rwlock_t *__rwlock,
				  const pthread_rwlockattr_t *__attr);

extern int __pthread_rwlock_destroy (pthread_rwlock_t *__rwlock);

extern int __pthread_rwlock_rdlock (pthread_rwlock_t *__rwlock);

extern int __pthread_rwlock_tryrdlock (pthread_rwlock_t *__rwlock);

extern int __pthread_rwlock_wrlock (pthread_rwlock_t *__rwlock);

extern int __pthread_rwlock_trywrlock (pthread_rwlock_t *__rwlock);

extern int __pthread_rwlock_unlock (pthread_rwlock_t *__rwlock);

extern int __pthread_once (pthread_once_t *__once_control,
			   void (*__init_routine) (void));

extern int __pthread_atfork (void (*__prepare) (void),
			     void (*__parent) (void),
			     void (*__child) (void));



/* Make the pthread functions weak so that we can elide them from
   single-threaded processes.  */
#if !defined(__NO_WEAK_PTHREAD_ALIASES) && !IS_IN (libpthread)
# ifdef weak_extern
weak_extern (__pthread_mutex_init)
weak_extern (__pthread_mutex_destroy)
weak_extern (__pthread_mutex_lock)
weak_extern (__pthread_mutex_trylock)
weak_extern (__pthread_mutex_unlock)
weak_extern (__pthread_mutexattr_init)
weak_extern (__pthread_mutexattr_destroy)
weak_extern (__pthread_mutexattr_settype)
weak_extern (__pthread_rwlock_init)
weak_extern (__pthread_rwlock_destroy)
weak_extern (__pthread_rwlock_rdlock)
weak_extern (__pthread_rwlock_tryrdlock)
weak_extern (__pthread_rwlock_wrlock)
weak_extern (__pthread_rwlock_trywrlock)
weak_extern (__pthread_rwlock_unlock)
weak_extern (__pthread_key_create)
weak_extern (__pthread_setspecific)
weak_extern (__pthread_getspecific)
weak_extern (__pthread_once)
weak_extern (__pthread_initialize)
weak_extern (__pthread_atfork)
weak_extern (__pthread_setcancelstate)
# else
#  pragma weak __pthread_mutex_init
#  pragma weak __pthread_mutex_destroy
#  pragma weak __pthread_mutex_lock
#  pragma weak __pthread_mutex_trylock
#  pragma weak __pthread_mutex_unlock
#  pragma weak __pthread_mutexattr_init
#  pragma weak __pthread_mutexattr_destroy
#  pragma weak __pthread_mutexattr_settype
#  pragma weak __pthread_rwlock_destroy
#  pragma weak __pthread_rwlock_rdlock
#  pragma weak __pthread_rwlock_tryrdlock
#  pragma weak __pthread_rwlock_wrlock
#  pragma weak __pthread_rwlock_trywrlock
#  pragma weak __pthread_rwlock_unlock
#  pragma weak __pthread_key_create
#  pragma weak __pthread_setspecific
#  pragma weak __pthread_getspecific
#  pragma weak __pthread_once
#  pragma weak __pthread_initialize
#  pragma weak __pthread_atfork
#  pragma weak __pthread_setcancelstate
# endif
#endif

#endif	/* bits/libc-lockP.h */
