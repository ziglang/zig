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

#ifndef WIN_PTHREADS_BARRIER_H
#define WIN_PTHREADS_BARRIER_H

#define LIFE_BARRIER 0xBAB1FEED
#define DEAD_BARRIER 0xDEADB00F

#define _PTHREAD_BARRIER_FLAG (1<<30)

#define CHECK_BARRIER(b)                                                \
    do {                                                                \
        if (!(b) || ( ((barrier_t *)(*b))->valid != (unsigned int)LIFE_BARRIER ) ) \
            return EINVAL;                                              \
    } while (0)

#include "semaphore.h"

typedef struct barrier_t barrier_t;
struct barrier_t
{
    int valid;
    int busy;
    int count;
    int total;
    int share;
    long sel;
    pthread_mutex_t m;
    sem_t sems[2];
};

#endif
