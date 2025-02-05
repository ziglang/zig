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

#include <windows.h>
#include <stdio.h>
#include <malloc.h>
#include "pthread.h"
#include "thread.h"
#include "ref.h"
#include "rwlock.h"
#include "misc.h"

static pthread_spinlock_t rwl_global = PTHREAD_SPINLOCK_INITIALIZER;

static WINPTHREADS_ATTRIBUTE((noinline)) int rwlock_static_init(pthread_rwlock_t *rw);

static WINPTHREADS_ATTRIBUTE((noinline)) int rwl_unref(volatile pthread_rwlock_t *rwl, int res)
{
    pthread_spin_lock(&rwl_global);
#ifdef WINPTHREAD_DBG
    assert((((rwlock_t *)*rwl)->valid == LIFE_RWLOCK) && (((rwlock_t *)*rwl)->busy > 0));
#endif
     ((rwlock_t *)*rwl)->busy--;
    pthread_spin_unlock(&rwl_global);
    return res;
}

static WINPTHREADS_ATTRIBUTE((noinline)) int rwl_ref(pthread_rwlock_t *rwl, int f )
{
    int r = 0;
    if (STATIC_RWL_INITIALIZER(*rwl)) {
        r = rwlock_static_init(rwl);
        if (r != 0 && r != EBUSY)
            return r;
    }
    pthread_spin_lock(&rwl_global);

    if (!rwl || !*rwl || ((rwlock_t *)*rwl)->valid != LIFE_RWLOCK) r = EINVAL;
    else {
        ((rwlock_t *)*rwl)->busy ++;
    }

    pthread_spin_unlock(&rwl_global);

    return r;
}

static WINPTHREADS_ATTRIBUTE((noinline)) int rwl_ref_unlock(pthread_rwlock_t *rwl )
{
    int r = 0;

    pthread_spin_lock(&rwl_global);

    if (!rwl || !*rwl || ((rwlock_t *)*rwl)->valid != LIFE_RWLOCK) r = EINVAL;
    else if (STATIC_RWL_INITIALIZER(*rwl)) r= EPERM;
    else {
        ((rwlock_t *)*rwl)->busy ++;
    }

    pthread_spin_unlock(&rwl_global);

    return r;
}

static WINPTHREADS_ATTRIBUTE((noinline)) int rwl_ref_destroy(pthread_rwlock_t *rwl, pthread_rwlock_t *rDestroy )
{
    int r = 0;

    *rDestroy = (pthread_rwlock_t)NULL;
    pthread_spin_lock(&rwl_global);
    
    if (!rwl || !*rwl) r = EINVAL;
    else {
        rwlock_t *r_ = (rwlock_t *)*rwl;
        if (STATIC_RWL_INITIALIZER(*rwl)) *rwl = (pthread_rwlock_t)NULL;
        else if (r_->valid != LIFE_RWLOCK) r = EINVAL;
        else if (r_->busy) r = EBUSY;
        else {
            *rDestroy = *rwl;
            *rwl = (pthread_rwlock_t)NULL;
        }
    }

    pthread_spin_unlock(&rwl_global);
    return r;
}

static int rwlock_gain_both_locks(rwlock_t *rwlock)
{
  int ret;
  ret = pthread_mutex_lock(&rwlock->mex);
  if (ret != 0)
    return ret;
  ret = pthread_mutex_lock(&rwlock->mcomplete);
  if (ret != 0)
    pthread_mutex_unlock(&rwlock->mex);
  return ret;
}

static int rwlock_free_both_locks(rwlock_t *rwlock, int last_fail)
{
  int ret, ret2;
  ret = pthread_mutex_unlock(&rwlock->mcomplete);
  ret2 = pthread_mutex_unlock(&rwlock->mex);
  if (last_fail && ret2 != 0)
    ret = ret2;
  else if (!last_fail && !ret)
    ret = ret2;
  return ret;
}

#ifdef WINPTHREAD_DBG
static int print_state = 0;
void rwl_print_set(int state)
{
    print_state = state;
}

void rwl_print(volatile pthread_rwlock_t *rwl, char *txt)
{
    if (!print_state) return;
    rwlock_t *r = (rwlock_t *)*rwl;
    if (r == NULL) {
        printf("RWL%p %lu %s\n",(void *)*rwl,GetCurrentThreadId(),txt);
    } else {
        printf("RWL%p %lu V=%0X B=%d r=%ld w=%ld L=%p %s\n",
            (void *)*rwl,
            GetCurrentThreadId(),
            (int)r->valid, 
            (int)r->busy,
            0L,0L,NULL,txt);
    }
}
#endif

static pthread_spinlock_t cond_locked = PTHREAD_SPINLOCK_INITIALIZER;

static WINPTHREADS_ATTRIBUTE((noinline)) int rwlock_static_init(pthread_rwlock_t *rw)
{
  int r;
  pthread_spin_lock(&cond_locked);
  if (*rw != PTHREAD_RWLOCK_INITIALIZER)
  {
    pthread_spin_unlock(&cond_locked);
    return EINVAL;
  }
  r = pthread_rwlock_init (rw, NULL);
  pthread_spin_unlock(&cond_locked);
  
  return r;
}

int pthread_rwlock_init (pthread_rwlock_t *rwlock_, const pthread_rwlockattr_t *attr)
{
    rwlock_t *rwlock;
    int r;

    if(!rwlock_)
      return EINVAL;
    *rwlock_ = (pthread_rwlock_t)NULL;
    if ((rwlock = calloc(1, sizeof(*rwlock))) == NULL)
      return ENOMEM; 
    rwlock->valid = DEAD_RWLOCK;

    rwlock->nex_count = rwlock->nsh_count = rwlock->ncomplete = 0;
    if ((r = pthread_mutex_init (&rwlock->mex, NULL)) != 0)
    {
        free(rwlock);
        return r;
    }
    if ((r = pthread_mutex_init (&rwlock->mcomplete, NULL)) != 0)
    {
      pthread_mutex_destroy(&rwlock->mex);
      free(rwlock);
      return r;
    }
    if ((r = pthread_cond_init (&rwlock->ccomplete, NULL)) != 0)
    {
      pthread_mutex_destroy(&rwlock->mex);
      pthread_mutex_destroy (&rwlock->mcomplete);
      free(rwlock);
      return r;
    }
    rwlock->valid = LIFE_RWLOCK;
    *rwlock_ = (pthread_rwlock_t)rwlock;
    return r;
} 

int pthread_rwlock_destroy (pthread_rwlock_t *rwlock_)
{
    rwlock_t *rwlock;
    pthread_rwlock_t rDestroy;
    int r, r2;
    
    pthread_spin_lock(&cond_locked);
    r = rwl_ref_destroy(rwlock_,&rDestroy);
    pthread_spin_unlock(&cond_locked);
    
    if(r) return r;
    if(!rDestroy) return 0; /* destroyed a (still) static initialized rwl */

    rwlock = (rwlock_t *)rDestroy;
    r = rwlock_gain_both_locks (rwlock);
    if (r != 0)
    {
      *rwlock_ = rDestroy;
      return r;
    }
    if (rwlock->nsh_count > rwlock->ncomplete || rwlock->nex_count > 0)
    {
      *rwlock_ = rDestroy;
      r = rwlock_free_both_locks(rwlock, 1);
      if (!r)
        r = EBUSY;
      return r;
    }
    rwlock->valid  = DEAD_RWLOCK;
    r = rwlock_free_both_locks(rwlock, 0);
    if (r != 0) { *rwlock_ = rDestroy; return r; }

    r = pthread_cond_destroy(&rwlock->ccomplete);
    r2 = pthread_mutex_destroy(&rwlock->mex);
    if (!r) r = r2;
    r2 = pthread_mutex_destroy(&rwlock->mcomplete);
    if (!r) r = r2;
    rwlock->valid  = DEAD_RWLOCK;
    free((void *)rDestroy);
    return 0;
} 

int pthread_rwlock_rdlock (pthread_rwlock_t *rwlock_)
{
  rwlock_t *rwlock;
  int ret;

  /* pthread_testcancel(); */

  ret = rwl_ref(rwlock_,0);
  if(ret != 0) return ret;

  rwlock = (rwlock_t *)*rwlock_;

  ret = pthread_mutex_lock(&rwlock->mex);
  if (ret != 0) return rwl_unref(rwlock_, ret);
  InterlockedIncrement((long*)&rwlock->nsh_count);
  if (rwlock->nsh_count == INT_MAX)
  {
    ret = pthread_mutex_lock(&rwlock->mcomplete);
    if (ret != 0)
    {
      pthread_mutex_unlock(&rwlock->mex);
      return rwl_unref(rwlock_,ret);
    }
    rwlock->nsh_count -= rwlock->ncomplete;
    rwlock->ncomplete = 0;
    ret = rwlock_free_both_locks(rwlock, 0);
    return rwl_unref(rwlock_, ret);
  }
  ret = pthread_mutex_unlock(&rwlock->mex);
  return rwl_unref(rwlock_, ret);
}

int pthread_rwlock_timedrdlock (pthread_rwlock_t *rwlock_, const struct timespec *ts)
{
  rwlock_t *rwlock;
  int ret;

  /* pthread_testcancel(); */

  ret = rwl_ref(rwlock_,0);
  if(ret != 0) return ret;

  rwlock = (rwlock_t *)*rwlock_;
  if ((ret = pthread_mutex_timedlock (&rwlock->mex, ts)) != 0)
      return rwl_unref(rwlock_, ret);
  InterlockedIncrement(&rwlock->nsh_count);
  if (rwlock->nsh_count == INT_MAX)
  {
    ret = pthread_mutex_timedlock(&rwlock->mcomplete, ts);
    if (ret != 0)
    {
      if (ret == ETIMEDOUT)
	InterlockedIncrement(&rwlock->ncomplete);
      pthread_mutex_unlock(&rwlock->mex);
      return rwl_unref(rwlock_, ret);
    }
    rwlock->nsh_count -= rwlock->ncomplete;
    rwlock->ncomplete = 0;
    ret = rwlock_free_both_locks(rwlock, 0);
    return rwl_unref(rwlock_, ret);
  }
  ret = pthread_mutex_unlock(&rwlock->mex);
  return rwl_unref(rwlock_, ret);
}

int pthread_rwlock_tryrdlock (pthread_rwlock_t *rwlock_)
{
  rwlock_t *rwlock;
  int ret;

  ret = rwl_ref(rwlock_,RWL_TRY);
  if(ret != 0) return ret;

  rwlock = (rwlock_t *)*rwlock_;
  ret = pthread_mutex_trylock(&rwlock->mex);
  if (ret != 0)
      return rwl_unref(rwlock_, ret);
  InterlockedIncrement(&rwlock->nsh_count);
  if (rwlock->nsh_count == INT_MAX)
  {
    ret = pthread_mutex_lock(&rwlock->mcomplete);
    if (ret != 0)
    {
      pthread_mutex_unlock(&rwlock->mex);
      return rwl_unref(rwlock_, ret);
    }
    rwlock->nsh_count -= rwlock->ncomplete;
    rwlock->ncomplete = 0;
    ret = rwlock_free_both_locks(rwlock, 0);
    return rwl_unref(rwlock_, ret);
  }
  ret = pthread_mutex_unlock(&rwlock->mex);
  return rwl_unref(rwlock_,ret);
} 

int pthread_rwlock_trywrlock (pthread_rwlock_t *rwlock_)
{
  rwlock_t *rwlock;
  int ret;

  ret = rwl_ref(rwlock_,RWL_TRY);
  if(ret != 0) return ret;

  rwlock = (rwlock_t *)*rwlock_;
  ret = pthread_mutex_trylock (&rwlock->mex);
  if (ret != 0)
    return rwl_unref(rwlock_, ret);
  ret = pthread_mutex_trylock(&rwlock->mcomplete);
  if (ret != 0)
  {
    int r1 = pthread_mutex_unlock(&rwlock->mex);
    if (r1 != 0)
      ret = r1;
    return rwl_unref(rwlock_, ret);
  }
  if (rwlock->nex_count != 0)
    return rwl_unref(rwlock_, EBUSY);
  if (rwlock->ncomplete > 0)
  {
    rwlock->nsh_count -= rwlock->ncomplete;
    rwlock->ncomplete = 0;
  }
  if (rwlock->nsh_count > 0)
  {
    ret = rwlock_free_both_locks(rwlock, 0);
    if (!ret)
      ret = EBUSY;
    return rwl_unref(rwlock_, ret);
  }
  rwlock->nex_count = 1;
  return rwl_unref(rwlock_, 0);
} 

int pthread_rwlock_unlock (pthread_rwlock_t *rwlock_)
{
  rwlock_t *rwlock;
  int ret;

  ret = rwl_ref_unlock(rwlock_);
  if(ret != 0) return ret;

  rwlock = (rwlock_t *)*rwlock_;
  if (rwlock->nex_count == 0)
  {
    ret = pthread_mutex_lock(&rwlock->mcomplete);
    if (!ret)
    {
      int r1;
      InterlockedIncrement(&rwlock->ncomplete);
      if (rwlock->ncomplete == 0)
	ret = pthread_cond_signal(&rwlock->ccomplete);
      r1 = pthread_mutex_unlock(&rwlock->mcomplete);
      if (!ret)
	ret = r1;
    }
  }
  else
  {
    InterlockedDecrement(&rwlock->nex_count);
    ret = rwlock_free_both_locks(rwlock, 0);
  }
  return rwl_unref(rwlock_, ret);
} 

static void st_cancelwrite (void *arg)
{
    rwlock_t *rwlock = (rwlock_t *)arg;

    rwlock->nsh_count = - rwlock->ncomplete;
    rwlock->ncomplete = 0;
    rwlock_free_both_locks(rwlock, 0);
}

int pthread_rwlock_wrlock (pthread_rwlock_t *rwlock_)
{
  rwlock_t *rwlock;
  int ret;

  /* pthread_testcancel(); */
  ret = rwl_ref(rwlock_,0);
  if(ret != 0) return ret;

  rwlock = (rwlock_t *)*rwlock_;
  ret = rwlock_gain_both_locks(rwlock);
  if (ret != 0)
    return rwl_unref(rwlock_,ret);

  if (rwlock->nex_count == 0)
  {
    if (rwlock->ncomplete > 0)
    {
      rwlock->nsh_count -= rwlock->ncomplete;
      rwlock->ncomplete = 0;
    }
    if (rwlock->nsh_count > 0)
    {
      rwlock->ncomplete = -rwlock->nsh_count;
      pthread_cleanup_push(st_cancelwrite, (void *) rwlock);
      do {
	ret = pthread_cond_wait(&rwlock->ccomplete, &rwlock->mcomplete);
      } while (!ret && rwlock->ncomplete < 0);

      pthread_cleanup_pop(!ret ? 0 : 1);
      if (!ret)
	rwlock->nsh_count = 0;
    }
  }
  if(!ret)
    InterlockedIncrement((long*)&rwlock->nex_count);
  return rwl_unref(rwlock_,ret);
}

int pthread_rwlock_timedwrlock (pthread_rwlock_t *rwlock_, const struct timespec *ts)
{
  int ret;
  rwlock_t *rwlock;

  /* pthread_testcancel(); */
  if (!rwlock_ || !ts)
    return EINVAL;
  if ((ret = rwl_ref(rwlock_,0)) != 0)
    return ret;
  rwlock = (rwlock_t *)*rwlock_;

  ret = pthread_mutex_timedlock(&rwlock->mex, ts);
  if (ret != 0)
    return rwl_unref(rwlock_,ret);
  ret = pthread_mutex_timedlock (&rwlock->mcomplete, ts);
  if (ret != 0)
  {
    pthread_mutex_unlock(&rwlock->mex);
    return rwl_unref(rwlock_,ret);
  }
  if (rwlock->nex_count == 0)
  {
    if (rwlock->ncomplete > 0)
    {
      rwlock->nsh_count -= rwlock->ncomplete;
      rwlock->ncomplete = 0;
    }
    if (rwlock->nsh_count > 0)
    {
      rwlock->ncomplete = -rwlock->nsh_count;
      pthread_cleanup_push(st_cancelwrite, (void *) rwlock);
      do {
	ret = pthread_cond_timedwait(&rwlock->ccomplete, &rwlock->mcomplete, ts);
      } while (rwlock->ncomplete < 0 && !ret);
      pthread_cleanup_pop(!ret ? 0 : 1);

      if (!ret)
	rwlock->nsh_count = 0;
    }
  }
  if(!ret)
    InterlockedIncrement((long*)&rwlock->nex_count);
  return rwl_unref(rwlock_,ret);
}

int pthread_rwlockattr_destroy(pthread_rwlockattr_t *a)
{
  if (!a)
    return EINVAL;
  return 0;
}

int pthread_rwlockattr_init(pthread_rwlockattr_t *a)
{
  if (!a)
    return EINVAL;
  *a = PTHREAD_PROCESS_PRIVATE;
  return 0;
}

int pthread_rwlockattr_getpshared(pthread_rwlockattr_t *a, int *s)
{
  if (!a || !s)
    return EINVAL;
  *s = *a;
  return 0;
}

int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *a, int s)
{
  if (!a || (s != PTHREAD_PROCESS_SHARED && s != PTHREAD_PROCESS_PRIVATE))
    return EINVAL;
  *a = s;
  return 0;
}
