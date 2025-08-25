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

#ifndef WIN_PTHREADS_UNISTD_H
#define WIN_PTHREADS_UNISTD_H

/* Set defines described by the POSIX Threads Extension (1003.1c-1995) */
/* _SC_THREADS
  Basic support for POSIX threads is available. The functions

  pthread_atfork(),
  pthread_attr_destroy(),
  pthread_attr_getdetachstate(),
  pthread_attr_getschedparam(),
  pthread_attr_init(),
  pthread_attr_setdetachstate(),
  pthread_attr_setschedparam(),
  pthread_cancel(),
  pthread_cleanup_push(),
  pthread_cleanup_pop(),
  pthread_cond_broadcast(),
  pthread_cond_destroy(),
  pthread_cond_init(),
  pthread_cond_signal(),
  pthread_cond_timedwait(),
  pthread_cond_wait(),
  pthread_condattr_destroy(),
  pthread_condattr_init(),
  pthread_create(),
  pthread_detach(),
  pthread_equal(),
  pthread_exit(),
  pthread_getspecific(),
  pthread_join(,
  pthread_key_create(),
  pthread_key_delete(),
  pthread_mutex_destroy(),
  pthread_mutex_init(),
  pthread_mutex_lock(),
  pthread_mutex_trylock(),
  pthread_mutex_unlock(),
  pthread_mutexattr_destroy(),
  pthread_mutexattr_init(),
  pthread_once(),
  pthread_rwlock_destroy(),
  pthread_rwlock_init(),
  pthread_rwlock_rdlock(),
  pthread_rwlock_tryrdlock(),
  pthread_rwlock_trywrlock(),
  pthread_rwlock_unlock(),
  pthread_rwlock_wrlock(),
  pthread_rwlockattr_destroy(),
  pthread_rwlockattr_init(),
  pthread_self(),
  pthread_setcancelstate(),
  pthread_setcanceltype(),
  pthread_setspecific(),
  pthread_testcancel()

  are present. */
#undef _POSIX_THREADS
#define _POSIX_THREADS 200112L

/* _SC_READER_WRITER_LOCKS
  This option implies the _POSIX_THREADS option. Conversely, under
  POSIX 1003.1-2001 the _POSIX_THREADS option implies this option.

  The functions
  pthread_rwlock_destroy(),
  pthread_rwlock_init(),
  pthread_rwlock_rdlock(),
  pthread_rwlock_tryrdlock(),
  pthread_rwlock_trywrlock(),
  pthread_rwlock_unlock(),
  pthread_rwlock_wrlock(),
  pthread_rwlockattr_destroy(),
  pthread_rwlockattr_init()

  are present.
*/
#undef _POSIX_READER_WRITER_LOCKS
#define _POSIX_READER_WRITER_LOCKS 200112L

/* _SC_SPIN_LOCKS
  This option implies the _POSIX_THREADS and _POSIX_THREAD_SAFE_FUNCTIONS
  options. The functions

  pthread_spin_destroy(),
  pthread_spin_init(),
  pthread_spin_lock(),
  pthread_spin_trylock(),
  pthread_spin_unlock()

  are present. */
#undef _POSIX_SPIN_LOCKS
#define _POSIX_SPIN_LOCKS 200112L

/* _SC_BARRIERS
  This option implies the _POSIX_THREADS and _POSIX_THREAD_SAFE_FUNCTIONS
  options. The functions

  pthread_barrier_destroy(),
  pthread_barrier_init(),
  pthread_barrier_wait(),
  pthread_barrierattr_destroy(),
  pthread_barrierattr_init()

  are present.
*/
#undef _POSIX_BARRIERS
#define _POSIX_BARRIERS 200112L

/* _SC_TIMEOUTS
  The functions

  mq_timedreceive(), - not supported
  mq_timedsend(), - not supported
  posix_trace_timedgetnext_event(), - not supported
  pthread_mutex_timedlock(),
  pthread_rwlock_timedrdlock(),
  pthread_rwlock_timedwrlock(),
  sem_timedwait(),

  are present. */
#undef _POSIX_TIMEOUTS
#define _POSIX_TIMEOUTS 200112L

/* _SC_TIMERS - not supported
  The functions

  clock_getres(),
  clock_gettime(),
  clock_settime(),
  nanosleep(),
  timer_create(),
  timer_delete(),
  timer_gettime(),
  timer_getoverrun(),
  timer_settime()

  are present.  */
/* #undef _POSIX_TIMERS */

/* _SC_CLOCK_SELECTION
   This option implies the _POSIX_TIMERS option. The functions

   pthread_condattr_getclock(),
   pthread_condattr_setclock(),
   clock_nanosleep()

   are present.
*/
#undef _POSIX_CLOCK_SELECTION
#define _POSIX_CLOCK_SELECTION 200112

/* _SC_SEMAPHORES
  The include file <semaphore.h> is present. The functions

  sem_close(),
  sem_destroy(),
  sem_getvalue(),
  sem_init(),
  sem_open(),
  sem_post(),
  sem_trywait(),
  sem_unlink(),
  sem_wait()

  are present. */
#undef _POSIX_SEMAPHORES
#define _POSIX_SEMAPHORES 200112

#endif /* WIN_PTHREADS_UNISTD_H */
