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
#include "barrier.h"
#include "ref.h" 
#include "misc.h"

static pthread_spinlock_t barrier_global = PTHREAD_SPINLOCK_INITIALIZER;

static WINPTHREADS_ATTRIBUTE((noinline)) int
barrier_unref(volatile pthread_barrier_t *barrier, int res)
{
    pthread_spin_lock(&barrier_global);
#ifdef WINPTHREAD_DBG
    assert((((barrier_t *)*barrier)->valid == LIFE_BARRIER) && (((barrier_t *)*barrier)->busy > 0));
#endif
     ((barrier_t *)*barrier)->busy -= 1;
    pthread_spin_unlock(&barrier_global);
    return res;
}

static WINPTHREADS_ATTRIBUTE((noinline)) int barrier_ref(volatile pthread_barrier_t *barrier)
{
    int r = 0;
    pthread_spin_lock(&barrier_global);

    if (!barrier || !*barrier || ((barrier_t *)*barrier)->valid != LIFE_BARRIER) r = EINVAL;
    else {
        ((barrier_t *)*barrier)->busy += 1;
    }

    pthread_spin_unlock(&barrier_global);

    return r;
}

static WINPTHREADS_ATTRIBUTE((noinline))  int
barrier_ref_destroy(volatile pthread_barrier_t *barrier, pthread_barrier_t *bDestroy)
{
    int r = 0;

    *bDestroy = NULL;
    pthread_spin_lock(&barrier_global);
    
    if (!barrier || !*barrier || ((barrier_t *)*barrier)->valid != LIFE_BARRIER) r = EINVAL;
    else {
        barrier_t *b_ = (barrier_t *)*barrier;
        if (b_->busy) r = EBUSY;
        else {
            *bDestroy = *barrier;
            *barrier = NULL;
        }
    }

    pthread_spin_unlock(&barrier_global);
    return r;
}

static WINPTHREADS_ATTRIBUTE((noinline)) void
barrier_ref_set (volatile pthread_barrier_t *barrier, void *v)
{
  pthread_spin_lock(&barrier_global);
  *barrier = v;
  pthread_spin_unlock(&barrier_global);
}

int pthread_barrier_destroy(pthread_barrier_t *b_)
{
    pthread_barrier_t bDestroy;
    barrier_t *b;
    int r;
    
    while ((r = barrier_ref_destroy(b_,&bDestroy)) == EBUSY)
      Sleep(0);
    
    if (r)
      return r;

    b = (barrier_t *)bDestroy;
    
    pthread_mutex_lock(&b->m);

    if (sem_destroy(&b->sems[0]) != 0)
    {
        /* Could this happen? */
        *b_ = bDestroy;
        pthread_mutex_unlock (&b->m);
        return EBUSY;
    }
    if (sem_destroy(&b->sems[1]) != 0)
    {
      sem_init (&b->sems[0], b->share, 0);
      *b_ = bDestroy;
      pthread_mutex_unlock (&b->m);
      return -1;
    }
    pthread_mutex_unlock(&b->m);
    if(pthread_mutex_destroy(&b->m) != 0) {
     sem_init (&b->sems[0], b->share, 0);
     sem_init (&b->sems[1], b->share, 0);
     *b_ = bDestroy;
     return -1;
    }
    b->valid = DEAD_BARRIER;
    free(bDestroy);
    return 0;

}

int
pthread_barrier_init (pthread_barrier_t *b_, const void *attr,
		      unsigned int count)
{
    barrier_t *b;

    if (!count || !b_)
      return EINVAL;

    if ((b = (pthread_barrier_t)calloc(1,sizeof(*b))) == NULL)
       return ENOMEM;
    if (!attr || *((int **)attr) == NULL)
      b->share = PTHREAD_PROCESS_PRIVATE;
    else
      memcpy (&b->share, *((void **) attr), sizeof (int));
    b->total = count;
    b->count = count;
    b->valid = LIFE_BARRIER;
    b->sel = 0;

    if (pthread_mutex_init(&b->m, NULL) != 0)
    {
      free (b);
      return ENOMEM;
    }

    if (sem_init(&b->sems[0], b->share, 0) != 0)
    {
       pthread_mutex_destroy(&b->m);
       free (b);
       return ENOMEM;
    }
    if (sem_init(&b->sems[1], b->share, 0) != 0)
    {
       pthread_mutex_destroy(&b->m);
       sem_destroy(&b->sems[0]);
       free (b);
       return ENOMEM;
    }
    barrier_ref_set (b_,b);

    return 0;
}

int pthread_barrier_wait(pthread_barrier_t *b_)
{
  long sel;
  int r, e, rslt;
  barrier_t *b;

  r = barrier_ref(b_);
  if(r) return r;

  b = (barrier_t *)*b_;

  if ((r = pthread_mutex_lock(&b->m)) != 0) return  barrier_unref(b_,EINVAL);
  sel = b->sel;
  InterlockedDecrement((long*)&b->total);
  if (b->total == 0)
  {
    b->total = b->count;
    b->sel = (sel != 0 ? 0 : 1);
    e = 1;
    rslt = PTHREAD_BARRIER_SERIAL_THREAD;
    r = (b->count > 1 ? sem_post_multiple (&b->sems[sel], b->count - 1) : 0);
  }
  else { e = 0; rslt= 0; }
  pthread_mutex_unlock(&b->m);
  if (!e)
    r = sem_wait(&b->sems[sel]);

  if (!r) r = rslt;
  return barrier_unref(b_,r);
}

int pthread_barrierattr_init(void **attr)
{
  int *p;

  if ((p = (int *) calloc (1, sizeof (int))) == NULL)
    return ENOMEM;

  *p = PTHREAD_PROCESS_PRIVATE;
  *attr = p;

  return 0;
}

int pthread_barrierattr_destroy(void **attr)
{
  void *p;
  if (!attr || (p = *attr) == NULL)
    return EINVAL;
  *attr = NULL;
  free (p);
  return 0;
}

int pthread_barrierattr_setpshared(void **attr, int s)
{
  if (!attr || *attr == NULL
      || (s != PTHREAD_PROCESS_SHARED && s != PTHREAD_PROCESS_PRIVATE))
    return EINVAL;
  memcpy (*attr, &s, sizeof (int));
  return 0;
}

int pthread_barrierattr_getpshared(void **attr, int *s)
{
  if (!attr || !s || *attr == NULL)
    return EINVAL;
  memcpy (s, *attr, sizeof (int));
  return 0;
}
