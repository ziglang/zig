/* Private libc-internal interface for mutex locks.  NPTL version.
   Copyright (C) 1996-2021 Free Software Foundation, Inc.
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

#ifndef _LIBC_LOCKP_H
#define _LIBC_LOCKP_H 1

#include <pthread.h>
#define __need_NULL
#include <stddef.h>


/* Fortunately Linux now has a mean to do locking which is realtime
   safe without the aid of the thread library.  We also need no fancy
   options like error checking mutexes etc.  We only need simple
   locks, maybe recursive.  This can be easily and cheaply implemented
   using futexes.  We will use them everywhere except in ld.so since
   ld.so might be used on old kernels with a different libc.so.  */
#include <lowlevellock.h>
#include <tls.h>

/* Mutex type.  */
typedef int __libc_lock_t;
typedef struct { pthread_mutex_t mutex; } __rtld_lock_recursive_t;
typedef pthread_rwlock_t __libc_rwlock_t;

/* Define a lock variable NAME with storage class CLASS.  The lock must be
   initialized with __libc_lock_init before it can be used (or define it
   with __libc_lock_define_initialized, below).  Use `extern' for CLASS to
   declare a lock defined in another module.  In public structure
   definitions you must use a pointer to the lock structure (i.e., NAME
   begins with a `*'), because its storage size will not be known outside
   of libc.  */
#define __libc_lock_define(CLASS,NAME) \
  CLASS __libc_lock_t NAME;
#define __libc_rwlock_define(CLASS,NAME) \
  CLASS __libc_rwlock_t NAME;
#define __rtld_lock_define_recursive(CLASS,NAME) \
  CLASS __rtld_lock_recursive_t NAME;

/* Define an initialized lock variable NAME with storage class CLASS.

   For the C library we take a deeper look at the initializer.  For
   this implementation all fields are initialized to zero.  Therefore
   we don't initialize the variable which allows putting it into the
   BSS section.  */

_Static_assert (LLL_LOCK_INITIALIZER == 0, "LLL_LOCK_INITIALIZER != 0");
#define _LIBC_LOCK_INITIALIZER LLL_LOCK_INITIALIZER
#define __libc_lock_define_initialized(CLASS,NAME) \
  CLASS __libc_lock_t NAME;

#define __libc_rwlock_define_initialized(CLASS,NAME) \
  CLASS __libc_rwlock_t NAME = PTHREAD_RWLOCK_INITIALIZER;

#define __rtld_lock_define_initialized_recursive(CLASS,NAME) \
  CLASS __rtld_lock_recursive_t NAME = _RTLD_LOCK_RECURSIVE_INITIALIZER;
#define _RTLD_LOCK_RECURSIVE_INITIALIZER \
  {PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP}

#define __rtld_lock_initialize(NAME) \
  (void) ((NAME) = (__rtld_lock_recursive_t) _RTLD_LOCK_RECURSIVE_INITIALIZER)

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

/* All previously forwarded functions are now called directly (either
   via local call in libc, or through a __export), but __libc_ptf_call
   is still used in generic code shared with Hurd.  */
#define PTFAVAIL(NAME) 1
#define __libc_ptf_call(FUNC, ARGS, ELSE) FUNC ARGS
#define __libc_ptf_call_always(FUNC, ARGS) FUNC ARGS

/* Initialize the named lock variable, leaving it in a consistent, unlocked
   state.  */
#define __libc_lock_init(NAME) ((void) ((NAME) = LLL_LOCK_INITIALIZER))
#define __libc_rwlock_init(NAME) __pthread_rwlock_init (&(NAME), NULL)

/* Finalize the named lock variable, which must be locked.  It cannot be
   used again until __libc_lock_init is called again on it.  This must be
   called on a lock variable before the containing storage is reused.  */
#define __libc_lock_fini(NAME) ((void) 0)
#define __libc_rwlock_fini(NAME) ((void) 0)

/* Lock the named lock variable.  */
#define __libc_lock_lock(NAME) ({ lll_lock (NAME, LLL_PRIVATE); 0; })
#define __libc_rwlock_rdlock(NAME) __pthread_rwlock_rdlock (&(NAME))
#define __libc_rwlock_wrlock(NAME) __pthread_rwlock_wrlock (&(NAME))

/* Try to lock the named lock variable.  */
#define __libc_lock_trylock(NAME) lll_trylock (NAME)

/* Unlock the named lock variable.  */
#define __libc_lock_unlock(NAME) lll_unlock (NAME, LLL_PRIVATE)
#define __libc_rwlock_unlock(NAME) __pthread_rwlock_unlock (&(NAME))

#if IS_IN (rtld)
# define __rtld_lock_lock_recursive(NAME) \
  ___rtld_mutex_lock (&(NAME).mutex)

# define __rtld_lock_unlock_recursive(NAME) \
  ___rtld_mutex_unlock (&(NAME).mutex)
#else /* Not in the dynamic loader.  */
# define __rtld_lock_lock_recursive(NAME) \
  __pthread_mutex_lock (&(NAME).mutex)

# define __rtld_lock_unlock_recursive(NAME) \
  __pthread_mutex_unlock (&(NAME).mutex)
#endif

/* Define once control variable.  */
#if PTHREAD_ONCE_INIT == 0
/* Special case for static variables where we can avoid the initialization
   if it is zero.  */
# define __libc_once_define(CLASS, NAME) \
  CLASS pthread_once_t NAME
#else
# define __libc_once_define(CLASS, NAME) \
  CLASS pthread_once_t NAME = PTHREAD_ONCE_INIT
#endif

/* Call handler iff the first call.  Use a local call in libc, but the
   global pthread_once symbol elsewhere.  */
#if IS_IN (libc)
# define __libc_once(ONCE_CONTROL, INIT_FUNCTION) \
  __pthread_once (&(ONCE_CONTROL), INIT_FUNCTION)
#else
# define __libc_once(ONCE_CONTROL, INIT_FUNCTION) \
  pthread_once (&(ONCE_CONTROL), INIT_FUNCTION)
#endif

/* Get once control variable.  */
#define __libc_once_get(ONCE_CONTROL)	((ONCE_CONTROL) != PTHREAD_ONCE_INIT)

/* __libc_cleanup_push and __libc_cleanup_pop depend on exception
   handling and stack unwinding.  */
#ifdef __EXCEPTIONS

/* Normal cleanup handling, based on C cleanup attribute.  */
static __always_inline void
__libc_cleanup_routine (struct __pthread_cleanup_frame *f)
{
  if (f->__do_it)
    f->__cancel_routine (f->__cancel_arg);
}

# define __libc_cleanup_push(fct, arg) \
  do {									      \
    struct __pthread_cleanup_frame __clframe				      \
      __attribute__ ((__cleanup__ (__libc_cleanup_routine)))		      \
      = { .__cancel_routine = (fct), .__cancel_arg = (arg),		      \
	  .__do_it = 1 };

# define __libc_cleanup_pop(execute) \
    __clframe.__do_it = (execute);					      \
  } while (0)
#endif /* __EXCEPTIONS */

/* Register handlers to execute before and after `fork'.  Note that the
   last parameter is NULL.  The handlers registered by the libc are
   never removed so this is OK.  */
extern int __register_atfork (void (*__prepare) (void),
			      void (*__parent) (void),
			      void (*__child) (void),
			      void *__dso_handle);

/* Functions that are used by this file and are internal to the GNU C
   library.  */

extern int __pthread_mutex_init (pthread_mutex_t *__mutex,
				 const pthread_mutexattr_t *__mutex_attr);
libc_hidden_proto (__pthread_mutex_init)
extern int __pthread_mutex_destroy (pthread_mutex_t *__mutex);
libc_hidden_proto (__pthread_mutex_destroy)
extern int __pthread_mutex_trylock (pthread_mutex_t *__mutex);

extern int __pthread_mutex_lock (pthread_mutex_t *__mutex);
libc_hidden_proto (__pthread_mutex_lock)
extern int __pthread_mutex_unlock (pthread_mutex_t *__mutex);
libc_hidden_proto (__pthread_mutex_unlock)

extern int __pthread_mutexattr_destroy (pthread_mutexattr_t *__attr);

extern int __pthread_rwlock_init (pthread_rwlock_t *__rwlock,
				  const pthread_rwlockattr_t *__attr);
libc_hidden_proto (__pthread_rwlock_init)

extern int __pthread_rwlock_destroy (pthread_rwlock_t *__rwlock);

extern int __pthread_rwlock_rdlock (pthread_rwlock_t *__rwlock);
libc_hidden_proto (__pthread_rwlock_rdlock)

extern int __pthread_rwlock_wrlock (pthread_rwlock_t *__rwlock);
libc_hidden_proto (__pthread_rwlock_wrlock)

extern int __pthread_rwlock_unlock (pthread_rwlock_t *__rwlock);
libc_hidden_proto (__pthread_rwlock_unlock)
extern int __pthread_once (pthread_once_t *__once_control,
			   void (*__init_routine) (void));
libc_hidden_proto (__pthread_once)

extern int __pthread_atfork (void (*__prepare) (void),
			     void (*__parent) (void),
			     void (*__child) (void));

extern int __pthread_setcancelstate (int state, int *oldstate);
libc_hidden_proto (__pthread_setcancelstate)

/* Make the pthread functions weak so that we can elide them from
   single-threaded processes.  */
#ifndef __NO_WEAK_PTHREAD_ALIASES
# ifdef weak_extern
weak_extern (__pthread_mutex_trylock)
weak_extern (__pthread_mutexattr_destroy)
weak_extern (__pthread_initialize)
weak_extern (__pthread_atfork)
# else
#  pragma weak __pthread_mutex_trylock
#  pragma weak __pthread_mutexattr_destroy
#  pragma weak __pthread_initialize
#  pragma weak __pthread_atfork
# endif
#endif

#endif	/* libc-lockP.h */
