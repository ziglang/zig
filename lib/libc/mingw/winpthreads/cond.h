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

#ifndef WIN_PTHREADS_COND_H
#define WIN_PTHREADS_COND_H

#include <windows.h>

#define CHECK_COND(c)                                                   \
    do {                                                                \
        if (!(c) || !*c || (*c == PTHREAD_COND_INITIALIZER)             \
            || ( ((cond_t *)(*c))->valid != (unsigned int)LIFE_COND ) ) \
            return EINVAL;                                              \
    } while (0)

#define LIFE_COND 0xC0BAB1FD
#define DEAD_COND 0xC0DEADBF

#define STATIC_COND_INITIALIZER(x)		((pthread_cond_t)(x) == ((pthread_cond_t)PTHREAD_COND_INITIALIZER))

typedef struct cond_t cond_t;
struct cond_t
{
    unsigned int valid;   
    int busy;
    LONG waiters_count_; /* Number of waiting threads.  */
    LONG waiters_count_unblock_; /* Number of waiting threads whitch can be unblocked.  */
    LONG waiters_count_gone_; /* Number of waiters which are gone.  */
    CRITICAL_SECTION waiters_count_lock_; /* Serialize access to <waiters_count_>.  */
    CRITICAL_SECTION waiters_q_lock_; /* Serialize access to sema_q.  */
    LONG value_q;
    CRITICAL_SECTION waiters_b_lock_; /* Serialize access to sema_b.  */
    LONG value_b;
    HANDLE sema_q; /* Semaphore used to queue up threads waiting for the condition to
                 become signaled.  */
    HANDLE sema_b; /* Semaphore used to queue up threads waiting for the condition which
                 became signaled.  */
};

void cond_print_set(int state, FILE *f);

void cond_print(volatile pthread_cond_t *c, char *txt);

#endif
