/*
   Copyright (c) 2011, 2014 mingw-w64 project
   Copyright (c) 2015 Intel Corporation

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

#include <windows.h>
#include <stdio.h>
#include <malloc.h>
#include <stdbool.h>
#include "pthread.h"
#include "misc.h"

typedef enum {
  Unlocked,        /* Not locked. */
  Locked,          /* Locked but without waiters. */
  Waiting,         /* Locked, may have waiters. */
} mutex_state_t;

typedef enum {
  Normal,
  Errorcheck,
  Recursive,
} mutex_type_t;

/* The heap-allocated part of a mutex. */
typedef struct {
  mutex_state_t state;
  mutex_type_t type;
  HANDLE event;       /* Auto-reset event, or NULL if not yet allocated. */
  unsigned rec_lock;  /* For recursive mutexes, the number of times the
                         mutex has been locked in excess by the same thread. */
  volatile DWORD owner;  /* For recursive and error-checking mutexes, the
                            ID of the owning thread if the mutex is locked. */
} mutex_impl_t;

/* Whether a mutex is still a static initializer (not a pointer to
   a mutex_impl_t). */
static bool
is_static_initializer(pthread_mutex_t m)
{
  /* Treat 0 as a static initializer as well (for normal mutexes),
     to tolerate sloppy code in libgomp. (We should rather fix that code!) */
  intptr_t v = (intptr_t)m;
  return v >= -3 && v <= 0;
/* Should be simple:
  return (uintptr_t)m >= (uintptr_t)-3; */
}

/* Create and return the implementation part of a mutex from a static
   initialiser. Return NULL on out-of-memory error. */
static WINPTHREADS_ATTRIBUTE((noinline)) mutex_impl_t *
mutex_impl_init(pthread_mutex_t *m, mutex_impl_t *mi)
{
  mutex_impl_t *new_mi = malloc(sizeof(mutex_impl_t));
  if (new_mi == NULL)
    return NULL;
  new_mi->state = Unlocked;
  new_mi->type = (mi == (void *)PTHREAD_RECURSIVE_MUTEX_INITIALIZER ? Recursive
                  : mi == (void *)PTHREAD_ERRORCHECK_MUTEX_INITIALIZER ? Errorcheck
                  : Normal);
  new_mi->event = NULL;
  new_mi->rec_lock = 0;
  new_mi->owner = (DWORD)-1;
  if (InterlockedCompareExchangePointer((PVOID volatile *)m, new_mi, mi) == mi) {
    return new_mi;
  } else {
    /* Someone created the struct before us. */
    free(new_mi);
    return (mutex_impl_t *)*m;
  }
}

/* Return the implementation part of a mutex, creating it if necessary.
   Return NULL on out-of-memory error. */
static inline mutex_impl_t *
mutex_impl(pthread_mutex_t *m)
{
  mutex_impl_t *mi = (mutex_impl_t *)*m;
  if (is_static_initializer((pthread_mutex_t)mi)) {
    return mutex_impl_init(m, mi);
  } else {
    /* mi cannot be null here; avoid a test in the fast path. */
    if (mi == NULL)
      UNREACHABLE();
    return mi;
  }
}

/* Lock a mutex. Give up after 'timeout' ms (with ETIMEDOUT),
   or never if timeout=INFINITE. */
static inline int
pthread_mutex_lock_intern (pthread_mutex_t *m, DWORD timeout)
{
  mutex_impl_t *mi = mutex_impl(m);
  if (mi == NULL)
    return ENOMEM;
  mutex_state_t old_state = InterlockedExchange((long *)&mi->state, Locked);
  if (unlikely(old_state != Unlocked)) {
    /* The mutex is already locked. */

    if (mi->type != Normal) {
      /* Recursive or Errorcheck */
      if (mi->owner == GetCurrentThreadId()) {
        /* FIXME: A recursive mutex should not need two atomic ops when locking
           recursively.  We could rewrite by doing compare-and-swap instead of
           test-and-set the first time, but it would lead to more code
           duplication and add a conditional branch to the critical path. */
        InterlockedCompareExchange((long *)&mi->state, old_state, Locked);
        if (mi->type == Recursive) {
          mi->rec_lock++;
          return 0;
        } else {
          /* type == Errorcheck */
          return EDEADLK;
        }
      }
    }

    /* Make sure there is an event object on which to wait. */
    if (mi->event == NULL) {
      /* Make an auto-reset event object. */
      HANDLE ev = CreateEvent(NULL, false, false, NULL);
      if (ev == NULL) {
        switch (GetLastError()) {
        case ERROR_ACCESS_DENIED:
          return EPERM;
        default:
          return ENOMEM;    /* Probably accurate enough. */
        }
      }
      if (InterlockedCompareExchangePointer(&mi->event, ev, NULL) != NULL) {
        /* Someone created the event before us. */
        CloseHandle(ev);
      }
    }

    /* At this point, mi->event is non-NULL. */

    while (InterlockedExchange((long *)&mi->state, Waiting) != Unlocked) {
      /* For timed locking attempts, it is possible (although unlikely)
         that we are woken up but someone else grabs the lock before us,
         and we have to go back to sleep again. In that case, the total
         wait may be longer than expected. */

      unsigned r = _pthread_wait_for_single_object(mi->event, timeout);
      switch (r) {
      case WAIT_TIMEOUT:
        return ETIMEDOUT;
      case WAIT_OBJECT_0:
        break;
      default:
        return EINVAL;
      }
    }
  }

  if (mi->type != Normal)
    mi->owner = GetCurrentThreadId();

  return 0;
}

int
pthread_mutex_lock (pthread_mutex_t *m)
{
  return pthread_mutex_lock_intern (m, INFINITE);
}

int pthread_mutex_timedlock(pthread_mutex_t *m, const struct timespec *ts)
{
  unsigned long long patience;
  if (ts != NULL) {
    unsigned long long end = _pthread_time_in_ms_from_timespec(ts);
    unsigned long long now = _pthread_time_in_ms();
    patience = end > now ? end - now : 0;
    if (patience > 0xffffffff)
      patience = INFINITE;
  } else {
    patience = INFINITE;
  }
  return pthread_mutex_lock_intern(m, patience);
}

int pthread_mutex_unlock(pthread_mutex_t *m)
{    
  /* Here m might an initialiser of an error-checking or recursive mutex, in
     which case the behaviour is well-defined, so we can't skip this check. */
  mutex_impl_t *mi = mutex_impl(m);
  if (mi == NULL)
    return ENOMEM;

  if (unlikely(mi->type != Normal)) {
    if (mi->state == Unlocked)
      return EINVAL;
    if (mi->owner != GetCurrentThreadId())
      return EPERM;
    if (mi->rec_lock > 0) {
      mi->rec_lock--;
      return 0;
    }
    mi->owner = (DWORD)-1;
  }
  if (unlikely(InterlockedExchange((long *)&mi->state, Unlocked) == Waiting)) {
    if (!SetEvent(mi->event))
      return EPERM;
  }
  return 0;
}

int pthread_mutex_trylock(pthread_mutex_t *m)
{
  mutex_impl_t *mi = mutex_impl(m);
  if (mi == NULL)
    return ENOMEM;

  if (InterlockedCompareExchange((long *)&mi->state, Locked, Unlocked) == Unlocked) {
    if (mi->type != Normal)
      mi->owner = GetCurrentThreadId();
    return 0;
  } else {
    if (mi->type == Recursive && mi->owner == GetCurrentThreadId()) {
      mi->rec_lock++;
      return 0;
    }
    return EBUSY;
  }
}

int
pthread_mutex_init (pthread_mutex_t *m, const pthread_mutexattr_t *a)
{
  pthread_mutex_t init = PTHREAD_MUTEX_INITIALIZER;
  if (a != NULL) {
    int pshared;
    if (pthread_mutexattr_getpshared(a, &pshared) == 0
        && pshared == PTHREAD_PROCESS_SHARED)
      return ENOSYS;

    int type;
    if (pthread_mutexattr_gettype(a, &type) == 0) {
      switch (type) {
      case PTHREAD_MUTEX_ERRORCHECK:
        init = PTHREAD_ERRORCHECK_MUTEX_INITIALIZER;
        break;
      case PTHREAD_MUTEX_RECURSIVE:
        init = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
        break;
      default:
        init = PTHREAD_MUTEX_INITIALIZER;
        break;
      }
    }
  }
  *m = init;
  return 0;
}

int pthread_mutex_destroy (pthread_mutex_t *m)
{
  mutex_impl_t *mi = (mutex_impl_t *)*m;
  if (!is_static_initializer((pthread_mutex_t)mi)) {
    if (mi->event != NULL)
      CloseHandle(mi->event);
    free(mi);
    /* Sabotage attempts to re-use the mutex before initialising it again. */
    *m = (pthread_mutex_t)NULL;
  }

  return 0;
}

int pthread_mutexattr_init(pthread_mutexattr_t *a)
{
  *a = PTHREAD_MUTEX_NORMAL | (PTHREAD_PROCESS_PRIVATE << 3);
  return 0;
}

int pthread_mutexattr_destroy(pthread_mutexattr_t *a)
{
  if (!a)
    return EINVAL;

  return 0;
}

int pthread_mutexattr_gettype(const pthread_mutexattr_t *a, int *type)
{
  if (!a || !type)
    return EINVAL;
	
  *type = *a & 3;
  
  return 0;
}

int pthread_mutexattr_settype(pthread_mutexattr_t *a, int type)
{
    if (!a || (type != PTHREAD_MUTEX_NORMAL && type != PTHREAD_MUTEX_RECURSIVE && type != PTHREAD_MUTEX_ERRORCHECK))
      return EINVAL;
    *a &= ~3;
    *a |= type;

    return 0;
}

int pthread_mutexattr_getpshared(const pthread_mutexattr_t *a, int *type)
{
    if (!a || !type)
      return EINVAL;
    *type = (*a & 4 ? PTHREAD_PROCESS_SHARED : PTHREAD_PROCESS_PRIVATE);

    return 0;
}

int pthread_mutexattr_setpshared(pthread_mutexattr_t * a, int type)
{
    int r = 0;
    if (!a || (type != PTHREAD_PROCESS_SHARED
	&& type != PTHREAD_PROCESS_PRIVATE))
      return EINVAL;
    if (type == PTHREAD_PROCESS_SHARED)
    {
      type = PTHREAD_PROCESS_PRIVATE;
      r = ENOSYS;
    }
    type = (type == PTHREAD_PROCESS_SHARED ? 4 : 0);

    *a &= ~4;
    *a |= type;

    return r;
}

int pthread_mutexattr_getprotocol(const pthread_mutexattr_t *a, int *type)
{
    *type = *a & (8 + 16);

    return 0;
}

int pthread_mutexattr_setprotocol(pthread_mutexattr_t *a, int type)
{
    if ((type & (8 + 16)) != 8 + 16) return EINVAL;

    *a &= ~(8 + 16);
    *a |= type;

    return 0;
}

int pthread_mutexattr_getprioceiling(const pthread_mutexattr_t *a, int * prio)
{
    *prio = *a / PTHREAD_PRIO_MULT;
    return 0;
}

int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *a, int prio)
{
    *a &= (PTHREAD_PRIO_MULT - 1);
    *a += prio * PTHREAD_PRIO_MULT;

    return 0;
}
