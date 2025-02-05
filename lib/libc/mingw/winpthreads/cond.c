/*
   Copyright (c) 2011-2016  mingw-w64 project

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
 * Posix Condition Variables for Microsoft Windows.
 * 22-9-2010 Partly based on the ACE framework implementation.
 */
#include <windows.h>
#include <stdio.h>
#include <malloc.h>
#include <time.h>
#include "pthread.h"
#include "pthread_time.h"
#include "ref.h"
#include "cond.h"
#include "thread.h"
#include "misc.h"
#include "winpthread_internal.h"

#include "pthread_compat.h"

int __pthread_shallcancel (void);

static int do_sema_b_wait (HANDLE sema, int nointerrupt, DWORD timeout,CRITICAL_SECTION *cs, LONG *val);
static int do_sema_b_release(HANDLE sema, LONG count,CRITICAL_SECTION *cs, LONG *val);
static void cleanup_wait(void *arg);

typedef struct sCondWaitHelper {
    cond_t *c;
    pthread_mutex_t *external_mutex;
    int *r;
} sCondWaitHelper;

int do_sema_b_wait_intern (HANDLE sema, int nointerrupt, DWORD timeout);

#ifdef WINPTHREAD_DBG
static int print_state = 0;
static FILE *fo;
void cond_print_set(int state, FILE *f)
{
    if (f) fo = f;
    if (!fo) fo = stdout;
    print_state = state;
}

void cond_print(volatile pthread_cond_t *c, char *txt)
{
    if (!print_state) return;
    cond_t *c_ = (cond_t *)*c;
    if (c_ == NULL) {
        fprintf(fo,"C%p %lu %s\n",(void *)*c,GetCurrentThreadId(),txt);
    } else {
        fprintf(fo,"C%p %lu V=%0X w=%ld %s\n",
            (void *)*c,
            GetCurrentThreadId(),
            (int)c_->valid, 
            c_->waiters_count_,
            txt
            );
    }
}
#endif

static pthread_spinlock_t cond_locked = PTHREAD_SPINLOCK_INITIALIZER;

static int
cond_static_init (pthread_cond_t *c)
{
  int r = 0;
  
  pthread_spin_lock (&cond_locked);
  if (c == NULL)
    r = EINVAL;
  else if (*c == PTHREAD_COND_INITIALIZER)
    r = pthread_cond_init (c, NULL);
  else
    /* We assume someone was faster ... */
    r = 0;
  pthread_spin_unlock (&cond_locked);
  return r;
}

int
pthread_condattr_destroy (pthread_condattr_t *a)
{
  if (!a)
    return EINVAL;
   *a = 0;
   return 0;
}

int
pthread_condattr_init (pthread_condattr_t *a)
{
  if (!a)
    return EINVAL;
  *a = 0;
  return 0;
}

int
pthread_condattr_getpshared (const pthread_condattr_t *a, int *s)
{
  if (!a || !s)
    return EINVAL;
  *s = *a;
  return 0;
}

int
pthread_condattr_getclock (const pthread_condattr_t *a, clockid_t *clock_id)
{
  if (!a || !clock_id)
    return EINVAL;
  *clock_id = 0;
  return 0;
}

int
pthread_condattr_setclock(pthread_condattr_t *a, clockid_t clock_id)
{
  if (!a || clock_id != 0)
    return EINVAL;
  return 0;
}

int
__pthread_clock_nanosleep (clockid_t clock_id, int flags, const struct timespec *rqtp,
			   struct timespec *rmtp)
{
  unsigned long long tick, tick2;
  unsigned long long delay;
  DWORD dw;

  if (clock_id != CLOCK_REALTIME
      && clock_id != CLOCK_MONOTONIC
      && clock_id != CLOCK_PROCESS_CPUTIME_ID)
   return EINVAL;
  if ((flags & TIMER_ABSTIME) != 0)
    delay = _pthread_rel_time_in_ms (rqtp);
  else
    delay = _pthread_time_in_ms_from_timespec (rqtp);
  do
    {
      dw = (DWORD) (delay >= 99999ULL ? 99999ULL : delay);
      tick = _pthread_time_in_ms ();
      pthread_delay_np_ms (dw);
      tick2 = _pthread_time_in_ms ();
      tick2 -= tick;
      if (tick2 >= delay)
        delay = 0;
      else
        delay -= tick2;
    }
  while (delay != 0ULL);
  if (rmtp)
    memset (rmtp, 0, sizeof (*rmtp));
  return 0;
}

int
pthread_condattr_setpshared (pthread_condattr_t *a, int s)
{
  if (!a || (s != PTHREAD_PROCESS_SHARED && s != PTHREAD_PROCESS_PRIVATE))
    return EINVAL;
  if (s == PTHREAD_PROCESS_SHARED)
    {
       *a = PTHREAD_PROCESS_PRIVATE;
       return ENOSYS;
    }
  *a = s;
  return 0;
}

int
pthread_cond_init (pthread_cond_t *c, const pthread_condattr_t *a)
{
  cond_t *_c;
  int r = 0;

  if (!c)
    return EINVAL;
  if (a && *a == PTHREAD_PROCESS_SHARED)
    return ENOSYS;

  if ((_c = calloc(1, sizeof(*_c))) == NULL)
    return ENOMEM;

  _c->valid  = DEAD_COND;
  _c->busy = 0;
  _c->waiters_count_ = 0;
  _c->waiters_count_gone_ = 0;
  _c->waiters_count_unblock_ = 0;

  _c->sema_q = CreateSemaphore (NULL,       /* no security */
      0,          /* initially 0 */
      0x7fffffff, /* max count */
      NULL);      /* unnamed  */
  _c->sema_b =  CreateSemaphore (NULL,       /* no security */
      0,          /* initially 0 */
      0x7fffffff, /* max count */
      NULL);  
  if (_c->sema_q == NULL || _c->sema_b == NULL) {
      if (_c->sema_q != NULL)
	CloseHandle (_c->sema_q);
      if (_c->sema_b != NULL)
	CloseHandle (_c->sema_b);
      free (_c);
      r = EAGAIN;
  } else {
      InitializeCriticalSection(&_c->waiters_count_lock_);
      InitializeCriticalSection(&_c->waiters_b_lock_);
      InitializeCriticalSection(&_c->waiters_q_lock_);
      _c->value_q = 0;
      _c->value_b = 1;
  }
  if (!r)
    {
      _c->valid = LIFE_COND;
      *c = (pthread_cond_t)_c;
    }
  else
    *c = (pthread_cond_t)NULL;
  return r;
}

int
pthread_cond_destroy (pthread_cond_t *c)
{
  cond_t *_c;
  int r;
  if (!c || !*c)
    return EINVAL;
  if (*c == PTHREAD_COND_INITIALIZER)
    {
      pthread_spin_lock (&cond_locked);
      if (*c == PTHREAD_COND_INITIALIZER)
      {
	*c = (pthread_cond_t)NULL;
	r = 0;
      }
      else
	r = EBUSY;
      pthread_spin_unlock (&cond_locked);
      return r;
    }
  _c = (cond_t *) *c;
  r = do_sema_b_wait(_c->sema_b, 0, INFINITE,&_c->waiters_b_lock_,&_c->value_b);
  if (r != 0)
    return r;
  if (!TryEnterCriticalSection (&_c->waiters_count_lock_))
    {
       do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
       return EBUSY;
    }
  if (_c->waiters_count_ > _c->waiters_count_gone_)
    {
      r = do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
      if (!r) r = EBUSY;
      LeaveCriticalSection(&_c->waiters_count_lock_);
      return r;
    }
  *c = (pthread_cond_t)NULL;
  do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);

  if (!CloseHandle (_c->sema_q) && !r)
    r = EINVAL;
  if (!CloseHandle (_c->sema_b) && !r)
    r = EINVAL;
  LeaveCriticalSection (&_c->waiters_count_lock_);
  DeleteCriticalSection(&_c->waiters_count_lock_);
  DeleteCriticalSection(&_c->waiters_b_lock_);
  DeleteCriticalSection(&_c->waiters_q_lock_);
  _c->valid  = DEAD_COND;
  free(_c);
  return 0;
}

int
pthread_cond_signal (pthread_cond_t *c)
{
  cond_t *_c;
  int r;

  if (!c || !*c)
    return EINVAL;
  _c = (cond_t *)*c;
  if (_c == (cond_t *)PTHREAD_COND_INITIALIZER)
    return 0;
  else if (_c->valid != (unsigned int)LIFE_COND)
    return EINVAL;

  EnterCriticalSection (&_c->waiters_count_lock_);
  /* If there aren't any waiters, then this is a no-op.   */
  if (_c->waiters_count_unblock_ != 0)
    {
      if (_c->waiters_count_ == 0)
      {
	LeaveCriticalSection (&_c->waiters_count_lock_);
	/* pthread_testcancel(); */
	return 0;
      }
      _c->waiters_count_ -= 1;
      _c->waiters_count_unblock_ += 1;
    }
  else if (_c->waiters_count_ > _c->waiters_count_gone_)
    {
      r = do_sema_b_wait (_c->sema_b, 1, INFINITE,&_c->waiters_b_lock_,&_c->value_b);
      if (r != 0)
      {
	LeaveCriticalSection (&_c->waiters_count_lock_);
	/* pthread_testcancel(); */
	return r;
      }
      if (_c->waiters_count_gone_ != 0)
      {
	_c->waiters_count_ -= _c->waiters_count_gone_;
	_c->waiters_count_gone_ = 0;
      }
      _c->waiters_count_ -= 1;
      _c->waiters_count_unblock_ = 1;
    }
  else
    {
      LeaveCriticalSection (&_c->waiters_count_lock_);
      /* pthread_testcancel(); */
      return 0;
    }
  LeaveCriticalSection (&_c->waiters_count_lock_);
  r = do_sema_b_release(_c->sema_q, 1,&_c->waiters_q_lock_,&_c->value_q);
  /* pthread_testcancel(); */
  return r;
}

int
pthread_cond_broadcast (pthread_cond_t *c)
{
  cond_t *_c;
  int r;
  int relCnt = 0;    

  if (!c || !*c)
    return EINVAL;
  _c = (cond_t *)*c;
  if (_c == (cond_t*)PTHREAD_COND_INITIALIZER)
    return 0;
  else if (_c->valid != (unsigned int)LIFE_COND)
    return EINVAL;

  EnterCriticalSection (&_c->waiters_count_lock_);
  /* If there aren't any waiters, then this is a no-op.   */
  if (_c->waiters_count_unblock_ != 0)
    {
      if (_c->waiters_count_ == 0)
      {
	LeaveCriticalSection (&_c->waiters_count_lock_);
	/* pthread_testcancel(); */
	return 0;
      }
      relCnt = _c->waiters_count_;
      _c->waiters_count_ = 0;
      _c->waiters_count_unblock_ += relCnt;
    }
  else if (_c->waiters_count_ > _c->waiters_count_gone_)
    {
      r = do_sema_b_wait (_c->sema_b, 1, INFINITE,&_c->waiters_b_lock_,&_c->value_b);
      if (r != 0)
      {
	LeaveCriticalSection (&_c->waiters_count_lock_);
	/* pthread_testcancel(); */
	return r;
      }
      if (_c->waiters_count_gone_ != 0)
      {
	_c->waiters_count_ -= _c->waiters_count_gone_;
	_c->waiters_count_gone_ = 0;
      }
      relCnt = _c->waiters_count_;
      _c->waiters_count_ = 0;
      _c->waiters_count_unblock_ = relCnt;
    }
  else
    {
      LeaveCriticalSection (&_c->waiters_count_lock_);
      /* pthread_testcancel(); */
      return 0;
    }
  LeaveCriticalSection (&_c->waiters_count_lock_);
  r = do_sema_b_release(_c->sema_q, relCnt,&_c->waiters_q_lock_,&_c->value_q);
  /* pthread_testcancel(); */
  return r;
}

int
pthread_cond_wait (pthread_cond_t *c, pthread_mutex_t *external_mutex)
{
  sCondWaitHelper ch;
  cond_t *_c;
  int r;

  /* pthread_testcancel(); */

  if (!c || *c == (pthread_cond_t)NULL)
    return EINVAL;
  _c = (cond_t *)*c;
  if (*c == PTHREAD_COND_INITIALIZER)
  {
    r = cond_static_init(c);
    if (r != 0 && r != EBUSY)
      return r;
    _c = (cond_t *) *c;
  } else if (_c->valid != (unsigned int)LIFE_COND)
    return EINVAL;

tryagain:
  r = do_sema_b_wait (_c->sema_b, 0, INFINITE,&_c->waiters_b_lock_,&_c->value_b);
  if (r != 0)
    return r;

  if (!TryEnterCriticalSection (&_c->waiters_count_lock_))
  {
    r = do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
    if (r != 0)
      return r;
    sched_yield();
    goto tryagain;
  }

  _c->waiters_count_++;
  LeaveCriticalSection(&_c->waiters_count_lock_);
  r = do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
  if (r != 0)
    return r;

  ch.c = _c;
  ch.r = &r;
  ch.external_mutex = external_mutex;

  pthread_cleanup_push(cleanup_wait, (void *) &ch);
  r = pthread_mutex_unlock(external_mutex);
  if (!r)
    r = do_sema_b_wait (_c->sema_q, 0, INFINITE,&_c->waiters_q_lock_,&_c->value_q);

  pthread_cleanup_pop(1);
  return r;
}

static int
pthread_cond_timedwait_impl (pthread_cond_t *c, pthread_mutex_t *external_mutex, const struct timespec *t, int rel)
{
  sCondWaitHelper ch;
  DWORD dwr;
  int r;
  cond_t *_c;

  /* pthread_testcancel(); */

  if (!c || !*c)
    return EINVAL;
  _c = (cond_t *)*c;
  if (_c == (cond_t *)PTHREAD_COND_INITIALIZER)
  {
    r = cond_static_init(c);
    if (r && r != EBUSY)
      return r;
    _c = (cond_t *) *c;
  } else if ((_c)->valid != (unsigned int)LIFE_COND)
    return EINVAL;

  if (rel == 0)
  {
    dwr = dwMilliSecs(_pthread_rel_time_in_ms(t));
  }
  else
  {
    dwr = dwMilliSecs(_pthread_time_in_ms_from_timespec(t));
  }

tryagain:
  r = do_sema_b_wait (_c->sema_b, 0, INFINITE,&_c->waiters_b_lock_,&_c->value_b);
  if (r != 0)
    return r;

  if (!TryEnterCriticalSection (&_c->waiters_count_lock_))
  {
    r = do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
    if (r != 0)
      return r;
    sched_yield();
    goto tryagain;
  }

  _c->waiters_count_++;
  LeaveCriticalSection(&_c->waiters_count_lock_);
  r = do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
  if (r != 0)
    return r;

  ch.c = _c;
  ch.r = &r;
  ch.external_mutex = external_mutex;
  {
    pthread_cleanup_push(cleanup_wait, (void *) &ch);

    r = pthread_mutex_unlock(external_mutex);
    if (!r)
      r = do_sema_b_wait (_c->sema_q, 0, dwr,&_c->waiters_q_lock_,&_c->value_q);

    pthread_cleanup_pop(1);
  }
  return r;
}

int
pthread_cond_timedwait(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *t)
{
  return pthread_cond_timedwait_impl(c, m, t, 0);
}

int
pthread_cond_timedwait_relative_np(pthread_cond_t *c, pthread_mutex_t *m, const struct timespec *t)
{
  return pthread_cond_timedwait_impl(c, m, t, 1);
}

static void
cleanup_wait (void *arg)
{
  int n, r;
  sCondWaitHelper *ch = (sCondWaitHelper *) arg;
  cond_t *_c;

  _c = ch->c;
  EnterCriticalSection (&_c->waiters_count_lock_);
  n = _c->waiters_count_unblock_;
  if (n != 0)
    _c->waiters_count_unblock_ -= 1;
  else if ((INT_MAX/2) - 1 == _c->waiters_count_gone_)
  {
    _c->waiters_count_gone_ += 1;
    r = do_sema_b_wait (_c->sema_b, 1, INFINITE,&_c->waiters_b_lock_,&_c->value_b);
    if (r != 0)
    {
      LeaveCriticalSection(&_c->waiters_count_lock_);
      ch->r[0] = r;
      return;
    }
    _c->waiters_count_ -= _c->waiters_count_gone_;
    r = do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
    if (r != 0)
    {
      LeaveCriticalSection(&_c->waiters_count_lock_);
      ch->r[0] = r;
      return;
    }
    _c->waiters_count_gone_ = 0;
  }
  else
    _c->waiters_count_gone_ += 1;
  LeaveCriticalSection (&_c->waiters_count_lock_);

  if (n == 1)
  {
    r = do_sema_b_release (_c->sema_b, 1,&_c->waiters_b_lock_,&_c->value_b);
    if (r != 0)
    {
      ch->r[0] = r;
      return;
    }
  }
  r = pthread_mutex_lock(ch->external_mutex);
  if (r != 0)
    ch->r[0] = r;
}

static int
do_sema_b_wait (HANDLE sema, int nointerrupt, DWORD timeout,CRITICAL_SECTION *cs, LONG *val)
{
  int r;
  LONG v;
  EnterCriticalSection(cs);
  InterlockedDecrement(val);
  v = val[0];
  LeaveCriticalSection(cs);
  if (v >= 0)
    return 0;
  r = do_sema_b_wait_intern (sema, nointerrupt, timeout);
  EnterCriticalSection(cs);
  if (r != 0)
    InterlockedIncrement(val);
  LeaveCriticalSection(cs);
  return r;
}

int
do_sema_b_wait_intern (HANDLE sema, int nointerrupt, DWORD timeout)
{
  HANDLE arr[2];
  DWORD maxH = 1;
  int r = 0;
  DWORD res, dt;
  if (nointerrupt == 1)
  {
    res = _pthread_wait_for_single_object(sema, timeout);
    switch (res) {
    case WAIT_TIMEOUT:
	r = ETIMEDOUT;
	break;
    case WAIT_ABANDONED:
	r = EPERM;
	break;
    case WAIT_OBJECT_0:
	break;
    default:
	/*We can only return EINVAL though it might not be posix compliant  */
	r = EINVAL;
    }
    if (r != 0 && r != EINVAL && WaitForSingleObject(sema, 0) == WAIT_OBJECT_0)
      r = 0;
    return r;
  }
  arr[0] = sema;
  arr[1] = (HANDLE) pthread_getevent ();
  if (arr[1] != NULL) maxH += 1;
  if (maxH == 2)
  {
redo:
      res = _pthread_wait_for_multiple_objects(maxH, arr, 0, timeout);
      switch (res) {
      case WAIT_TIMEOUT:
	  r = ETIMEDOUT;
	  break;
      case (WAIT_OBJECT_0 + 1):
          ResetEvent(arr[1]);
          if (nointerrupt != 2)
	    {
            pthread_testcancel();
            return EINVAL;
	    }
	  pthread_testcancel ();
	  goto redo;
      case WAIT_ABANDONED:
	  r = EPERM;
	  break;
      case WAIT_OBJECT_0:
          r = 0;
	  break;
      default:
	  /*We can only return EINVAL though it might not be posix compliant  */
	  r = EINVAL;
      }
      if (r != 0 && r != EINVAL && WaitForSingleObject(arr[0], 0) == WAIT_OBJECT_0)
	r = 0;
      if (r != 0 && nointerrupt != 2 && __pthread_shallcancel ())
	return EINVAL;
      return r;
  }
  if (timeout == INFINITE)
  {
    do {
      res = _pthread_wait_for_single_object(sema, 40);
      switch (res) {
      case WAIT_TIMEOUT:
	  r = ETIMEDOUT;
	  break;
      case WAIT_ABANDONED:
	  r = EPERM;
	  break;
      case WAIT_OBJECT_0:
          r = 0;
	  break;
      default:
	  /*We can only return EINVAL though it might not be posix compliant  */
	  r = EINVAL;
      }
      if (r != 0 && __pthread_shallcancel ())
      {
	if (nointerrupt != 2)
	  pthread_testcancel();
	return EINVAL;
      }
    } while (r == ETIMEDOUT);
    if (r != 0 && r != EINVAL && WaitForSingleObject(sema, 0) == WAIT_OBJECT_0)
      r = 0;
    return r;
  }
  dt = 20;
  do {
    if (dt > timeout) dt = timeout;
    res = _pthread_wait_for_single_object(sema, dt);
    switch (res) {
    case WAIT_TIMEOUT:
	r = ETIMEDOUT;
	break;
    case WAIT_ABANDONED:
	r = EPERM;
	break;
    case WAIT_OBJECT_0:
	r = 0;
	break;
    default:
	/*We can only return EINVAL though it might not be posix compliant  */
	r = EINVAL;
    }
    timeout -= dt;
    if (timeout != 0 && r != 0 && __pthread_shallcancel ())
      return EINVAL;
  } while (r == ETIMEDOUT && timeout != 0);
  if (r != 0 && r == ETIMEDOUT && WaitForSingleObject(sema, 0) == WAIT_OBJECT_0)
    r = 0;
  if (r != 0 && nointerrupt != 2)
    pthread_testcancel();
  return r;
}

static int
do_sema_b_release(HANDLE sema, LONG count,CRITICAL_SECTION *cs, LONG *val)
{
  int wc;
  EnterCriticalSection(cs);
  if (((long long) val[0] + (long long) count) > (long long) 0x7fffffffLL)
  {
    LeaveCriticalSection(cs);
    return ERANGE;
  }
  wc = -val[0];
  InterlockedExchangeAdd(val, count);
  if (wc <= 0 || ReleaseSemaphore(sema, (wc < count ? wc : count), NULL))
  {
    LeaveCriticalSection(cs);
    return 0;
  }
  InterlockedExchangeAdd(val, -count);
  LeaveCriticalSection(cs);
  return EINVAL;  
}
