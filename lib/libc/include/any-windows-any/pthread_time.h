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

#ifndef WIN_PTHREADS_TIME_H
#define WIN_PTHREADS_TIME_H

#include <sys/timeb.h>
#include "pthread_compat.h"

/* Posix timers are supported */
#ifndef _POSIX_TIMERS
#define _POSIX_TIMERS           200809L
#endif

/* Monotonic clocks are available.  */
#ifndef _POSIX_MONOTONIC_CLOCK
#define _POSIX_MONOTONIC_CLOCK  200809L
#endif

/* CPU-time clocks are available.  */
#ifndef _POSIX_CPUTIME
#define _POSIX_CPUTIME          200809L
#endif

/* Clock support in threads are available.  */
#ifndef _POSIX_THREAD_CPUTIME
#define _POSIX_THREAD_CPUTIME   200809L
#endif

#ifndef TIMER_ABSTIME
#define TIMER_ABSTIME   1
#endif

#ifndef CLOCK_REALTIME
#define CLOCK_REALTIME              0
#endif

#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC             1
#endif

#ifndef CLOCK_PROCESS_CPUTIME_ID
#define CLOCK_PROCESS_CPUTIME_ID    2
#endif

#ifndef CLOCK_THREAD_CPUTIME_ID
#define CLOCK_THREAD_CPUTIME_ID     3
#endif

#ifndef CLOCK_REALTIME_COARSE
#define CLOCK_REALTIME_COARSE       4
#endif

#ifdef __cplusplus
extern "C" {
#endif

WINPTHREAD_API int __cdecl nanosleep32(const struct _timespec32 *request, struct _timespec32 *remain);
WINPTHREAD_API int __cdecl nanosleep64(const struct _timespec64 *request, struct _timespec64 *remain);
WINPTHREAD_NANOSLEEP_DECL int __cdecl nanosleep(const struct timespec *request, struct timespec *remain)
{
#if WINPTHREADS_TIME_BITS == 32
  return nanosleep32 ((struct _timespec32 *)request, (struct _timespec32 *)remain);
#else
  return nanosleep64 ((struct _timespec64 *)request, (struct _timespec64 *)remain);
#endif
}

WINPTHREAD_API int __cdecl clock_nanosleep32(clockid_t clock_id, int flags, const struct _timespec32 *request, struct _timespec32 *remain);
WINPTHREAD_API int __cdecl clock_nanosleep64(clockid_t clock_id, int flags, const struct _timespec64 *request, struct _timespec64 *remain);
WINPTHREAD_CLOCK_DECL int __cdecl clock_nanosleep(clockid_t clock_id, int flags, const struct timespec *request, struct timespec *remain)
{
#if WINPTHREADS_TIME_BITS == 32
  return clock_nanosleep32 (clock_id, flags, (struct _timespec32 *)request, (struct _timespec32 *)remain);
#else
  return clock_nanosleep64 (clock_id, flags, (struct _timespec64 *)request, (struct _timespec64 *)remain);
#endif
}

WINPTHREAD_API int __cdecl clock_getres32(clockid_t clock_id, struct _timespec32 *res);
WINPTHREAD_API int __cdecl clock_getres64(clockid_t clock_id, struct _timespec64 *res);
WINPTHREAD_CLOCK_DECL int __cdecl clock_getres(clockid_t clock_id, struct timespec *res)
{
#if WINPTHREADS_TIME_BITS == 32
  return clock_getres32 (clock_id, (struct _timespec32 *)res);
#else
  return clock_getres64 (clock_id, (struct _timespec64 *)res);
#endif
}

WINPTHREAD_API int __cdecl clock_gettime32(clockid_t clock_id, struct _timespec32 *tp);
WINPTHREAD_API int __cdecl clock_gettime64(clockid_t clock_id, struct _timespec64 *tp);
WINPTHREAD_CLOCK_DECL int __cdecl clock_gettime(clockid_t clock_id, struct timespec *tp)
{
#if WINPTHREADS_TIME_BITS == 32
  return clock_gettime32 (clock_id, (struct _timespec32 *)tp);
#else
  return clock_gettime64 (clock_id, (struct _timespec64 *)tp);
#endif
}

WINPTHREAD_API int __cdecl clock_settime32(clockid_t clock_id, const struct _timespec32 *tp);
WINPTHREAD_API int __cdecl clock_settime64(clockid_t clock_id, const struct _timespec64 *tp);
WINPTHREAD_CLOCK_DECL int __cdecl clock_settime(clockid_t clock_id, const struct timespec *tp)
{
#if WINPTHREADS_TIME_BITS == 32
  return clock_settime32 (clock_id, (struct _timespec32 *)tp);
#else
  return clock_settime64 (clock_id, (struct _timespec64 *)tp);
#endif
}

#ifdef __cplusplus
}
#endif

#endif /* WIN_PTHREADS_TIME_H */
