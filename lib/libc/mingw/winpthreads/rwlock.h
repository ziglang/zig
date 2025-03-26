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

#ifndef WIN_PTHREADS_RWLOCK_H
#define WIN_PTHREADS_RWLOCK_H

#define LIFE_RWLOCK 0xBAB1F0ED
#define DEAD_RWLOCK 0xDEADB0EF

#define STATIC_RWL_INITIALIZER(x)		((pthread_rwlock_t)(x) == ((pthread_rwlock_t)PTHREAD_RWLOCK_INITIALIZER))

typedef struct rwlock_t rwlock_t;
struct rwlock_t {
    unsigned int valid;
    int busy;
    LONG nex_count; /* Exclusive access counter.  */
    LONG nsh_count; /* Shared access counter. */
    LONG ncomplete; /* Shared completed counter. */
    pthread_mutex_t mex; /* Exclusive access protection.  */
    pthread_mutex_t mcomplete; /* Shared completed protection. */
    pthread_cond_t ccomplete; /* Shared access completed queue.  */
};

#define RWL_SET	0x01
#define RWL_TRY	0x02

void rwl_print(volatile pthread_rwlock_t *rwl, char *txt);
void rwl_print_set(int state);

#endif
