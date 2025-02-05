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

#ifdef __cplusplus
extern "C" {
#endif

#if defined(IN_WINPTHREAD)
#  if defined(DLL_EXPORT) && !defined(WINPTHREAD_EXPORT_ALL_DEBUG)
#    define WINPTHREAD_SEMA_API  __declspec(dllexport)  /* building the DLL  */
#  else
#    define WINPTHREAD_SEMA_API  /* building the static library  */
#  endif
#else
#  if defined(WINPTHREADS_USE_DLLIMPORT)
#    define WINPTHREAD_SEMA_API  __declspec(dllimport)  /* user wants explicit `dllimport`  */
#  else
#    define WINPTHREAD_SEMA_API  /* the default; auto imported in case of DLL  */
#  endif
#endif

/* Set this to 0 to disable it */
#define USE_SEM_CriticalSection_SpinCount	100

#define SEM_VALUE_MAX   INT_MAX

#ifndef _MODE_T_
#define	_MODE_T_
typedef unsigned short mode_t;
#endif

typedef void		*sem_t;

#define SEM_FAILED 		NULL

WINPTHREAD_SEMA_API int sem_init(sem_t * sem, int pshared, unsigned int value);

WINPTHREAD_SEMA_API int sem_destroy(sem_t *sem);

WINPTHREAD_SEMA_API int sem_trywait(sem_t *sem);

WINPTHREAD_SEMA_API int sem_wait(sem_t *sem);

WINPTHREAD_SEMA_API int sem_timedwait(sem_t * sem, const struct timespec *t);

WINPTHREAD_SEMA_API int sem_post(sem_t *sem);

WINPTHREAD_SEMA_API int sem_post_multiple(sem_t *sem, int count);

/* yes, it returns a semaphore (or SEM_FAILED) */
WINPTHREAD_SEMA_API sem_t * sem_open(const char * name, int oflag, mode_t mode, unsigned int value);

WINPTHREAD_SEMA_API int sem_close(sem_t * sem);

WINPTHREAD_SEMA_API int sem_unlink(const char * name);

WINPTHREAD_SEMA_API int sem_getvalue(sem_t * sem, int * sval);

#ifdef __cplusplus
}
#endif

#endif /* WIN_PTHREADS_SEMAPHORE_H */
