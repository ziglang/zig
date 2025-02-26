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
#ifndef WIN_PTHREADS_SCHED_H
#define WIN_PTHREADS_SCHED_H

#include <stddef.h>
#include <errno.h>
#include <sys/types.h>

#include <process.h>
#include <limits.h>
#include <signal.h>

#include "pthread_compat.h"

/* Some POSIX realtime extensions, mostly stubbed */
#define SCHED_OTHER     0
#define SCHED_FIFO      1
#define SCHED_RR        2
#define SCHED_MIN       SCHED_OTHER
#define SCHED_MAX       SCHED_RR

struct sched_param {
  int sched_priority;
};

#ifdef __cplusplus
extern "C" {
#endif

WINPTHREAD_API int sched_yield(void);
WINPTHREAD_API int sched_get_priority_min(int pol);
WINPTHREAD_API int sched_get_priority_max(int pol);
WINPTHREAD_API int sched_getscheduler(pid_t pid);
WINPTHREAD_API int sched_setscheduler(pid_t pid, int pol, const struct sched_param *param);

#ifdef __cplusplus
}
#endif

#ifndef sched_rr_get_interval
#define sched_rr_get_interval(_p, _i) \
  ( errno = ENOTSUP, (int) -1 )
#endif

#endif /* WIN_PTHREADS_SCHED_H */
