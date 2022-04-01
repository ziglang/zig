#include "common_header.h"
#include "structdef.h"       /* for struct pypy_threadlocal_s */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "src/threadlocal.h"
#include "src/thread.h"


/* this is a spin-lock that must be acquired around each doubly-linked-list
   manipulation (because such manipulations can occur without the GIL) */
static Signed pypy_threadlocal_lock = 0;

static int check_valid(void);

int _RPython_ThreadLocals_AcquireTimeout(int max_wait_iterations) {
    while (1) {
        Signed old_value = pypy_lock_test_and_set(&pypy_threadlocal_lock, 1);
        if (old_value == 0)
            break;
        /* busy loop */
        if (max_wait_iterations == 0)
            return -1;
        if (max_wait_iterations > 0)
            --max_wait_iterations;
    }
    assert(check_valid());
    return 0;
}
void _RPython_ThreadLocals_Acquire(void) {
    _RPython_ThreadLocals_AcquireTimeout(-1);
}
void _RPython_ThreadLocals_Release(void) {
    assert(check_valid());
    pypy_lock_release(&pypy_threadlocal_lock);
}


pthread_key_t pypy_threadlocal_key
#ifdef _WIN32
= TLS_OUT_OF_INDEXES
#endif
;

static struct pypy_threadlocal_s linkedlist_head = {
    -1,                     /* ready     */
    NULL,                   /* stack_end */
    &linkedlist_head,       /* prev      */
    &linkedlist_head };     /* next      */

static int check_valid(void)
{
    struct pypy_threadlocal_s *prev, *cur;
    prev = &linkedlist_head;
    while (1) {
        cur = prev->next;
        assert(cur->prev == prev);
        if (cur == &linkedlist_head)
            break;
        assert(cur->ready == 42);
        assert(cur->next != cur);
        prev = cur;
    }
    assert(cur->ready == -1);
    return 1;
}

static void cleanup_after_fork(void)
{
    /* assume that at most one pypy_threadlocal_s survived, the current one */
    struct pypy_threadlocal_s *cur;
    cur = (struct pypy_threadlocal_s *)_RPy_ThreadLocals_Get();
    if (cur && cur->ready == 42) {
        cur->next = cur->prev = &linkedlist_head;
        linkedlist_head.next = linkedlist_head.prev = cur;
    }
    else {
        linkedlist_head.next = linkedlist_head.prev = &linkedlist_head;
    }
    _RPython_ThreadLocals_Release();
}


struct pypy_threadlocal_s *
_RPython_ThreadLocals_Enum(struct pypy_threadlocal_s *prev)
{
    if (prev == NULL)
        prev = &linkedlist_head;
    if (prev->next == &linkedlist_head)
        return NULL;
    return prev->next;
}

struct pypy_threadlocal_s *_RPython_ThreadLocals_Head(void)
{
    return &linkedlist_head;
}

static void _RPy_ThreadLocals_Init(void *p)
{
    struct pypy_threadlocal_s *tls = (struct pypy_threadlocal_s *)p;
    struct pypy_threadlocal_s *oldnext;
    memset(p, 0, sizeof(struct pypy_threadlocal_s));

#ifdef RPY_TLOFS_p_errno
    tls->p_errno = &errno;
#endif
#ifdef RPY_TLOFS_thread_ident
    tls->thread_ident =
#    ifdef _WIN32
        (Signed)GetCurrentThreadId();
#    else
        (Signed)pthread_self();    /* xxx This abuses pthread_self() by
                  assuming it just returns a integer.  According to
                  comments in CPython's source code, the platforms
                  where it is not the case are rather old nowadays. */
#    endif
#endif
    _RPython_ThreadLocals_Acquire();
    oldnext = linkedlist_head.next;
    tls->prev = &linkedlist_head;
    tls->next = oldnext;
    linkedlist_head.next = tls;
    oldnext->prev = tls;
    tls->ready = 42;
    _RPython_ThreadLocals_Release();
}

static void threadloc_unlink(void *p)
{
    /* warning: this can be called at completely random times without
       the GIL. */
    struct pypy_threadlocal_s *tls = (struct pypy_threadlocal_s *)p;
    _RPython_ThreadLocals_Acquire();
    if (tls->ready == 42) {
        tls->next->prev = tls->prev;
        tls->prev->next = tls->next;
        memset(tls, 0xDD, sizeof(struct pypy_threadlocal_s));  /* debug */
        tls->ready = 0;
    }
    _RPython_ThreadLocals_Release();
#ifndef USE___THREAD
    free(p);
#endif
}

#ifdef _WIN32
/* xxx Defines a DllMain() function.  It's horrible imho: it only
   works if we happen to compile a DLL (not a EXE); and of course you
   get link-time errors if two files in the same DLL do the same.
   There are some alternatives known, but they are horrible in other
   ways (e.g. using undocumented behavior).  This seems to be the
   simplest, but feel free to fix if you need that.

   For this reason we have the line 'not _win32 or config.translation.shared'
   in rpython.rlib.rthread.
*/
BOOL WINAPI DllMain(HINSTANCE hinstDLL,
                    DWORD     reason_for_call,
                    LPVOID    reserved)
{
    LPVOID p;
    switch (reason_for_call) {
    case DLL_THREAD_DETACH:
        if (pypy_threadlocal_key != TLS_OUT_OF_INDEXES) {
            p = TlsGetValue(pypy_threadlocal_key);
            if (p != NULL) {
                TlsSetValue(pypy_threadlocal_key, NULL);
                threadloc_unlink(p);
            }
        }
        break;
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
#ifdef RPY_WITH_GIL
	RPython_ThreadLocals_ProgramInit();
#endif
	break;
    default:
        break;
    }
    return TRUE;
}
#endif

void RPython_ThreadLocals_ProgramInit(void)
{
    /* Initialize the pypy_threadlocal_key, together with a destructor
       that will be called every time a thread shuts down (if there is
       a non-null thread-local value).  This is needed even in the
       case where we use '__thread' below, for the destructor.
    */
    static int threadlocals_initialized = 0;
    if (threadlocals_initialized)
        return;

    assert(pypy_threadlocal_lock == 0);
#ifdef _WIN32
    pypy_threadlocal_key = TlsAlloc();
    if (pypy_threadlocal_key == TLS_OUT_OF_INDEXES)
#else
    if (pthread_key_create(&pypy_threadlocal_key, threadloc_unlink) != 0)
#endif
    {
        fprintf(stderr, "Internal RPython error: "
                        "out of thread-local storage indexes");
        abort();
    }
    RPY_THREADLOCALREF_ENSURE();

#ifndef _WIN32
    pthread_atfork(_RPython_ThreadLocals_Acquire,
                   _RPython_ThreadLocals_Release,
                   cleanup_after_fork);
#endif
    threadlocals_initialized = 1;
}


/* ------------------------------------------------------------ */
#ifdef USE___THREAD
/* ------------------------------------------------------------ */


/* in this situation, we always have one full 'struct pypy_threadlocal_s'
   available, managed by gcc. */
__thread struct pypy_threadlocal_s pypy_threadlocal;

char *_RPython_ThreadLocals_Build(void)
{
    RPyAssert(pypy_threadlocal.ready == 0, "unclean thread-local");
    _RPy_ThreadLocals_Init(&pypy_threadlocal);

    /* we also set up &pypy_threadlocal as a POSIX thread-local variable,
       because we need the destructor behavior. */
    pthread_setspecific(pypy_threadlocal_key, (void *)&pypy_threadlocal);

    return (char *)&pypy_threadlocal;
}

void RPython_ThreadLocals_ThreadDie(void)
{
    pthread_setspecific(pypy_threadlocal_key, NULL);
    threadloc_unlink(&pypy_threadlocal);
}


/* ------------------------------------------------------------ */
#else
/* ------------------------------------------------------------ */


/* this is the case where the 'struct pypy_threadlocal_s' is allocated
   explicitly, with malloc()/free(), and attached to (a single) thread-
   local key using the API of Windows or pthread. */


char *_RPython_ThreadLocals_Build(void)
{
    void *p = malloc(sizeof(struct pypy_threadlocal_s));
    if (!p) {
        fprintf(stderr, "Internal RPython error: "
                        "out of memory for the thread-local storage");
        abort();
    }
    _RPy_ThreadLocals_Init(p);
    _RPy_ThreadLocals_Set(p);
    return (char *)p;
}

void RPython_ThreadLocals_ThreadDie(void)
{
    void *p = _RPy_ThreadLocals_Get();
    if (p != NULL) {
        _RPy_ThreadLocals_Set(NULL);
        threadloc_unlink(p);   /* includes free(p) */
    }
}


/* ------------------------------------------------------------ */
#endif
/* ------------------------------------------------------------ */
