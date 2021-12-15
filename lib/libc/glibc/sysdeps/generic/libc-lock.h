/* libc-internal interface for mutex locks.  Stub version.
   Copyright (C) 1996-2021 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _LIBC_LOCK_H
#define _LIBC_LOCK_H 1


/* Define a lock variable NAME with storage class CLASS.  The lock must be
   initialized with __libc_lock_init before it can be used (or define it
   with __libc_lock_define_initialized, below).  Use `extern' for CLASS to
   declare a lock defined in another module.  In public structure
   definitions you must use a pointer to the lock structure (i.e., NAME
   begins with a `*'), because its storage size will not be known outside
   of libc.  */
#define __libc_lock_define(CLASS,NAME)
#define __libc_lock_define_recursive(CLASS,NAME)
#define __rtld_lock_define_recursive(CLASS,NAME)
#define __libc_rwlock_define(CLASS,NAME)

/* Define an initialized lock variable NAME with storage class CLASS.  */
#define __libc_lock_define_initialized(CLASS,NAME)
#define __libc_rwlock_define_initialized(CLASS,NAME)

/* Define an initialized recursive lock variable NAME with storage
   class CLASS.  */
#define __libc_lock_define_initialized_recursive(CLASS,NAME)
#define __rtld_lock_define_initialized_recursive(CLASS,NAME)

/* Initialize the named lock variable, leaving it in a consistent, unlocked
   state.  */
#define __libc_lock_init(NAME)
#define __rtld_lock_initialize(NAME)
#define __libc_rwlock_init(NAME)

/* Same as last but this time we initialize a recursive mutex.  */
#define __libc_lock_init_recursive(NAME)

/* Finalize the named lock variable, which must be locked.  It cannot be
   used again until __libc_lock_init is called again on it.  This must be
   called on a lock variable before the containing storage is reused.  */
#define __libc_lock_fini(NAME)
#define __libc_rwlock_fini(NAME)

/* Finalize recursive named lock.  */
#define __libc_lock_fini_recursive(NAME)

/* Lock the named lock variable.  */
#define __libc_lock_lock(NAME)
#define __libc_rwlock_rdlock(NAME)
#define __libc_rwlock_wrlock(NAME)

/* Lock the recursive named lock variable.  */
#define __libc_lock_lock_recursive(NAME)
#define __rtld_lock_lock_recursive(NAME)

/* Try to lock the named lock variable.  */
#define __libc_lock_trylock(NAME) 0
#define __libc_rwlock_tryrdlock(NAME) 0
#define __libc_rwlock_trywrlock(NAME) 0

/* Try to lock the recursive named lock variable.  */
#define __libc_lock_trylock_recursive(NAME) 0

/* Unlock the named lock variable.  */
#define __libc_lock_unlock(NAME)
#define __libc_rwlock_unlock(NAME)

/* Unlock the recursive named lock variable.  */
#define __libc_lock_unlock_recursive(NAME)
#define __rtld_lock_unlock_recursive(NAME)


/* Define once control variable.  */
#define __libc_once_define(CLASS, NAME) CLASS int NAME = 0

/* Call handler iff the first call.  */
#define __libc_once(ONCE_CONTROL, INIT_FUNCTION) \
  do {									      \
    if ((ONCE_CONTROL) == 0) {						      \
      INIT_FUNCTION ();							      \
      (ONCE_CONTROL) = 1;						      \
    }									      \
  } while (0)

/* Get once control variable.  */
#define __libc_once_get(ONCE_CONTROL) \
  ((ONCE_CONTROL) == 1)

/* Start a critical region with a cleanup function */
#define __libc_cleanup_region_start(DOIT, FCT, ARG)			    \
{									    \
  typeof (***(FCT)) *__save_FCT = (DOIT) ? (FCT) : 0;			    \
  typeof (ARG) __save_ARG = ARG;					    \
  /* close brace is in __libc_cleanup_region_end below. */

/* End a critical region started with __libc_cleanup_region_start. */
#define __libc_cleanup_region_end(DOIT)					    \
  if ((DOIT) && __save_FCT != 0)					    \
    (*__save_FCT)(__save_ARG);						    \
}

/* Sometimes we have to exit the block in the middle.  */
#define __libc_cleanup_end(DOIT)					    \
  if ((DOIT) && __save_FCT != 0)					    \
    (*__save_FCT)(__save_ARG);						    \

#define __libc_cleanup_push(fct, arg) __libc_cleanup_region_start (1, fct, arg)
#define __libc_cleanup_pop(execute) __libc_cleanup_region_end (execute)

/* We need portable names for some of the functions.  */
#define __libc_mutex_unlock

#endif	/* libc-lock.h */
