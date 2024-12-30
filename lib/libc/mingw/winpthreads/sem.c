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
#include "misc.h"
#include "semaphore.h"
#include "sem.h"
#include "ref.h"

int do_sema_b_wait_intern (HANDLE sema, int nointerrupt, DWORD timeout);

static int
sem_result (int res)
{
  if (res != 0) {
    errno = res;
    return -1;
  }
  return 0;
}

int
sem_init (sem_t *sem, int pshared, unsigned int value)
{
  _sem_t *sv;

  if (!sem || value > (unsigned int)SEM_VALUE_MAX)
    return sem_result (EINVAL);
  if (pshared != PTHREAD_PROCESS_PRIVATE)
    return sem_result (EPERM);

  if ((sv = (sem_t) calloc (1,sizeof (*sv))) == NULL)
    return sem_result (ENOMEM);

  sv->value = value;
  if (pthread_mutex_init (&sv->vlock, NULL) != 0)
    {
      free (sv);
      return sem_result (ENOSPC);
    }
  if ((sv->s = CreateSemaphore (NULL, 0, SEM_VALUE_MAX, NULL)) == NULL)
    {
      pthread_mutex_destroy (&sv->vlock);
      free (sv);
      return sem_result (ENOSPC);
    }

  sv->valid = LIFE_SEM;
  *sem = sv;
  return 0;
}

int
sem_destroy (sem_t *sem)
{
  int r;
  _sem_t *sv = NULL;

  if (!sem || (sv = *sem) == NULL)
    return sem_result (EINVAL);
  if ((r = pthread_mutex_lock (&sv->vlock)) != 0)
    return sem_result (r);

#if 0
  /* We don't wait for destroying a semaphore ...
     or?  */
  if (sv->value < 0)
    {
      pthread_mutex_unlock (&sv->vlock);
      return sem_result (EBUSY);
    }
#endif

  if (!CloseHandle (sv->s))
    {
      pthread_mutex_unlock (&sv->vlock);
      return sem_result (EINVAL);
    }
  *sem = NULL;
  sv->value = SEM_VALUE_MAX;
  pthread_mutex_unlock(&sv->vlock);
  Sleep (0);
  while (pthread_mutex_destroy (&sv->vlock) == EBUSY)
    Sleep (0);
  sv->valid = DEAD_SEM;
  free (sv);
  return 0;
}

static int
sem_std_enter (sem_t *sem,_sem_t **svp, int do_test)
{
  int r;
  _sem_t *sv;

  if (do_test)
    pthread_testcancel ();
  if (!sem)
    return sem_result (EINVAL);
  sv = *sem;
  if (sv == NULL)
    return sem_result (EINVAL);

  if ((r = pthread_mutex_lock (&sv->vlock)) != 0)
    return sem_result (r);

  if (*sem == NULL)
    {
      pthread_mutex_unlock(&sv->vlock);
      return sem_result (EINVAL);
    }
  *svp = sv;
  return 0;
}

int
sem_trywait (sem_t *sem)
{
  _sem_t *sv;

  if (sem_std_enter (sem, &sv, 0) != 0)
    return -1;
  if (sv->value <= 0)
    {
      pthread_mutex_unlock (&sv->vlock);
      return sem_result (EAGAIN);
    }
  sv->value--;
  pthread_mutex_unlock (&sv->vlock);

  return 0;
}

struct sSemTimedWait
{
  sem_t *p;
  int *ret;
};

static void
clean_wait_sem (void *s)
{
  struct sSemTimedWait *p = (struct sSemTimedWait *) s;
  _sem_t *sv = NULL;

  if (sem_std_enter (p->p, &sv, 0) != 0)
    return;

  if (WaitForSingleObject (sv->s, 0) != WAIT_OBJECT_0)
    InterlockedIncrement (&sv->value);
  else if (p->ret)
    p->ret[0] = 0;
  pthread_mutex_unlock (&sv->vlock);
}

int
sem_wait (sem_t *sem)
{
  long cur_v;
  int ret = 0;
  _sem_t *sv;
  HANDLE semh;
  struct sSemTimedWait arg;

  if (sem_std_enter (sem, &sv, 1) != 0)
    return -1;

  arg.ret = &ret;
  arg.p = sem;
  InterlockedDecrement (&sv->value);
  cur_v = sv->value;
  semh = sv->s;
  pthread_mutex_unlock (&sv->vlock);

  if (cur_v >= 0)
    return 0;
  else
    {
      pthread_cleanup_push (clean_wait_sem, (void *) &arg);
      ret = do_sema_b_wait_intern (semh, 2, INFINITE);
      pthread_cleanup_pop (ret);
      if (ret == EINVAL)
        return 0;
    }

  if (!ret)
    return 0;

  return sem_result (ret);
}

int
sem_timedwait (sem_t *sem, const struct timespec *t)
{
  int cur_v, ret = 0;
  DWORD dwr;
  HANDLE semh;
  _sem_t *sv;
  struct sSemTimedWait arg;

  if (!t)
    return sem_wait (sem);
  dwr = dwMilliSecs(_pthread_rel_time_in_ms (t));

  if (sem_std_enter (sem, &sv, 1) != 0)
    return -1;

  arg.ret = &ret;
  arg.p = sem;
  InterlockedDecrement (&sv->value);
  cur_v = sv->value;
  semh = sv->s;
  pthread_mutex_unlock(&sv->vlock);

  if (cur_v >= 0)
    return 0;
  else
    {
      pthread_cleanup_push (clean_wait_sem, (void *) &arg);
      ret = do_sema_b_wait_intern (semh, 2, dwr);
      pthread_cleanup_pop (ret);
      if (ret == EINVAL)
        return 0;
    }

  if (!ret)
    return 0;
  return sem_result (ret);
}

int
sem_post (sem_t *sem)
{
  _sem_t *sv;

  if (sem_std_enter (sem, &sv, 0) != 0)
    return -1;

  if (sv->value >= SEM_VALUE_MAX)
    {
      pthread_mutex_unlock (&sv->vlock);
      return sem_result (ERANGE);
    }
  InterlockedIncrement (&sv->value);
  if (sv->value > 0 || ReleaseSemaphore (sv->s, 1, NULL))
    {
      pthread_mutex_unlock (&sv->vlock);
      return 0;
    }
  InterlockedDecrement (&sv->value);
  pthread_mutex_unlock (&sv->vlock);

  return sem_result (EINVAL);
}

int
sem_post_multiple (sem_t *sem, int count)
{
  int waiters_count;
  _sem_t *sv;

  if (count <= 0)
    return sem_result (EINVAL);
  if (sem_std_enter (sem, &sv, 0) != 0)
    return -1;

  if (sv->value > (SEM_VALUE_MAX - count))
  {
    pthread_mutex_unlock (&sv->vlock);
    return sem_result (ERANGE);
  }
  waiters_count = -sv->value;
  sv->value += count;
  /*InterlockedExchangeAdd((long*)&sv->value, (long) count);*/
  if (waiters_count <= 0
      || ReleaseSemaphore (sv->s,
			   (waiters_count < count ? waiters_count
			   			  : count), NULL))
  {
    pthread_mutex_unlock(&sv->vlock);
    return 0;
  }
  /*InterlockedExchangeAdd((long*)&sv->value, -((long) count));*/
  sv->value -= count;
  pthread_mutex_unlock(&sv->vlock);
  return sem_result (EINVAL);
}

sem_t *
sem_open (const char *name, int oflag, mode_t mode, unsigned int value)
{
  sem_result (ENOSYS);
  return NULL;
}

int
sem_close (sem_t *sem)
{
  return sem_result (ENOSYS);
}

int
sem_unlink (const char *name)
{
  return sem_result (ENOSYS);
}

int
sem_getvalue (sem_t *sem, int *sval)
{
  _sem_t *sv;
  int r;

  if (!sval)
    return sem_result (EINVAL);

  if (!sem || (sv = *sem) == NULL)
    return sem_result (EINVAL);

  if ((r = pthread_mutex_lock (&sv->vlock)) != 0)
    return sem_result (r);
  if (*sem == NULL)
    {
      pthread_mutex_unlock (&sv->vlock);
      return sem_result (EINVAL);
    }

  *sval = (int) sv->value;
  pthread_mutex_unlock (&sv->vlock);
  return 0;  
}
