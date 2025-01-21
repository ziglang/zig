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

#ifndef WIN_PTHREAD_H
#define WIN_PTHREAD_H

#include <windows.h>
#include <setjmp.h>
#include "rwlock.h"

#define LIFE_THREAD 0xBAB1F00D
#define DEAD_THREAD 0xDEADBEEF
#define EXCEPTION_SET_THREAD_NAME ((DWORD) 0x406D1388)

typedef struct _pthread_v _pthread_v;
struct _pthread_v
{
    unsigned int valid;
    void *ret_arg;
    void *(* func)(void *);
    _pthread_cleanup *clean;
    int nobreak;
    HANDLE h;
    HANDLE evStart;
    pthread_mutex_t p_clock;
    int cancelled : 2;
    int in_cancel : 2;
    int thread_noposix : 2;
    unsigned int p_state;
    unsigned int keymax;
    void **keyval;
    unsigned char *keyval_set;
    char *thread_name;
    pthread_spinlock_t spin_keys;
    DWORD tid;
    int rwlc;
    pthread_rwlock_t rwlq[RWLS_PER_THREAD];
    int sched_pol;
    int ended;
    struct sched_param sched;
    jmp_buf jb;
    struct _pthread_v *next;
    pthread_t x; /* Internal posix handle.  */
};

typedef struct __pthread_idlist {
  struct _pthread_v *ptr;
  pthread_t id;
} __pthread_idlist;

int _pthread_tryjoin(pthread_t t, void **res);
void _pthread_setnobreak(int);
#ifdef WINPTHREAD_DBG
void thread_print_set(int state);
void thread_print(volatile pthread_t t, char *txt);
#endif
int  __pthread_shallcancel(void);
struct _pthread_v *WINPTHREAD_API __pth_gpointer_locked (pthread_t id);

#endif
