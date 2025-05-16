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

#ifndef WIN_PTHREADS_SEMAPHORE_H
#define WIN_PTHREADS_SEMAPHORE_H

#include <sys/timeb.h>
#include "pthread_compat.h"

#ifdef __cplusplus
extern "C" {
#endif

#define SEM_VALUE_MAX   INT_MAX

typedef void		*sem_t;

#define SEM_FAILED 		NULL

WINPTHREAD_API int sem_init(sem_t * sem, int pshared, unsigned int value);

WINPTHREAD_API int sem_destroy(sem_t *sem);

WINPTHREAD_API int sem_trywait(sem_t *sem);

WINPTHREAD_API int sem_wait(sem_t *sem);

WINPTHREAD_API int sem_timedwait32(sem_t * sem, const struct _timespec32 *t);
WINPTHREAD_API int sem_timedwait64(sem_t * sem, const struct _timespec64 *t);
WINPTHREAD_SEM_DECL int sem_timedwait(sem_t * sem, const struct timespec *t)
{
#if WINPTHREADS_TIME_BITS == 32
  return sem_timedwait32 (sem, (const struct _timespec32 *) t);
#else
  return sem_timedwait64 (sem, (const struct _timespec64 *) t);
#endif
}

WINPTHREAD_API int sem_post(sem_t *sem);

WINPTHREAD_API int sem_post_multiple(sem_t *sem, int count);

/* yes, it returns a semaphore (or SEM_FAILED) */
WINPTHREAD_API sem_t * sem_open(const char * name, int oflag, mode_t mode, unsigned int value);

WINPTHREAD_API int sem_close(sem_t * sem);

WINPTHREAD_API int sem_unlink(const char * name);

WINPTHREAD_API int sem_getvalue(sem_t * sem, int * sval);

#ifdef __cplusplus
}
#endif

#endif /* WIN_PTHREADS_SEMAPHORE_H */
