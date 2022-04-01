/* Thread-local storage */
#ifndef _SRC_THREADLOCAL_H
#define _SRC_THREADLOCAL_H

#include "src/precommondefs.h"
#include "src/support.h"


/* RPython_ThreadLocals_ProgramInit() is called once at program start-up. */
RPY_EXTERN void RPython_ThreadLocals_ProgramInit(void);

/* RPython_ThreadLocals_ThreadDie() is called in a thread that is about
   to die. */
RPY_EXTERN void RPython_ThreadLocals_ThreadDie(void);

/* 'threadlocalref_addr' returns the address of the thread-local
   structure (of the C type 'struct pypy_threadlocal_s').  It first
   checks if we have initialized this thread-local structure in the
   current thread, and if not, calls the following helper. */
RPY_EXTERN char *_RPython_ThreadLocals_Build(void);

RPY_EXTERN void _RPython_ThreadLocals_Acquire(void);
RPY_EXTERN void _RPython_ThreadLocals_Release(void);
RPY_EXTERN int _RPython_ThreadLocals_AcquireTimeout(int max_wait_iterations);

/* Must acquire/release the thread-local lock around a series of calls
   to the following function */
RPY_EXTERN struct pypy_threadlocal_s *
_RPython_ThreadLocals_Enum(struct pypy_threadlocal_s *prev);

/* will return the head of the list */
RPY_EXTERN struct pypy_threadlocal_s *_RPython_ThreadLocals_Head();

#define OP_THREADLOCALREF_ACQUIRE(r)   _RPython_ThreadLocals_Acquire()
#define OP_THREADLOCALREF_RELEASE(r)   _RPython_ThreadLocals_Release()
#define OP_THREADLOCALREF_ENUM(p, r)   r = _RPython_ThreadLocals_Enum(p)


/* ------------------------------------------------------------ */
#ifdef USE___THREAD
/* ------------------------------------------------------------ */


/* Use the '__thread' specifier, so far only on Linux */

#include <pthread.h>

RPY_EXTERN __thread struct pypy_threadlocal_s pypy_threadlocal;

#define OP_THREADLOCALREF_ADDR(r)               \
    do {                                        \
        r = (void *)&pypy_threadlocal;          \
        if (pypy_threadlocal.ready != 42)       \
            r = _RPython_ThreadLocals_Build();  \
    } while (0)

#define _OP_THREADLOCALREF_ADDR_SIGHANDLER(r)   \
    do {                                        \
        r = (void *)&pypy_threadlocal;          \
        if (pypy_threadlocal.ready != 42)       \
            r = NULL;                           \
    } while (0)

#define RPY_THREADLOCALREF_ENSURE()             \
    if (pypy_threadlocal.ready != 42)           \
        (void)_RPython_ThreadLocals_Build();

#define RPY_THREADLOCALREF_GET(FIELD)   pypy_threadlocal.FIELD

#define _RPy_ThreadLocals_Get()  (&pypy_threadlocal)


/* ------------------------------------------------------------ */
#else
/* ------------------------------------------------------------ */


/* Don't use '__thread'. */

#ifdef _WIN32
#  include <WinSock2.h>
#  include <windows.h>
#  define _RPy_ThreadLocals_Get()   TlsGetValue(pypy_threadlocal_key)
#  define _RPy_ThreadLocals_Set(x)  TlsSetValue(pypy_threadlocal_key, x)
typedef DWORD pthread_key_t;
#else
#  include <pthread.h>
#  define _RPy_ThreadLocals_Get()   pthread_getspecific(pypy_threadlocal_key)
#  define _RPy_ThreadLocals_Set(x)  pthread_setspecific(pypy_threadlocal_key, x)
#endif


#define OP_THREADLOCALREF_ADDR(r)               \
    do {                                        \
        r = (void *)_RPy_ThreadLocals_Get();    \
        if (!r)                                 \
            r = _RPython_ThreadLocals_Build();  \
    } while (0)

#define _OP_THREADLOCALREF_ADDR_SIGHANDLER(r)   \
    do {                                        \
        r = (void *)_RPy_ThreadLocals_Get();    \
    } while (0)

#define RPY_THREADLOCALREF_ENSURE()             \
    if (!_RPy_ThreadLocals_Get())               \
        (void)_RPython_ThreadLocals_Build();

#define RPY_THREADLOCALREF_GET(FIELD)           \
    ((struct pypy_threadlocal_s *)_RPy_ThreadLocals_Get())->FIELD


/* ------------------------------------------------------------ */
#endif
/* ------------------------------------------------------------ */


RPY_EXTERN pthread_key_t pypy_threadlocal_key;


#define OP_THREADLOCALREF_LOAD(RESTYPE, offset, r)              \
    do {                                                        \
        char *a;                                                \
        OP_THREADLOCALREF_ADDR(a);                              \
        r = *(RESTYPE *)(a + offset);                           \
    } while (0)

#define OP_THREADLOCALREF_STORE(VALTYPE, offset, value)         \
    do {                                                        \
        char *a;                                                \
        OP_THREADLOCALREF_ADDR(a);                              \
        *(VALTYPE *)(a + offset) = value;                       \
    } while (0)



// XXX hack: these functions are here instead of thread.h because
// we need pypy_threadlocal_s.
#include <src/thread.h>

static INLINE Signed _rpygil_get_my_ident(void)
{
#ifdef RPY_TLOFS_thread_ident
    struct pypy_threadlocal_s *p = (struct pypy_threadlocal_s *)_RPy_ThreadLocals_Get();
    assert(p->thread_ident != 0);
    return p->thread_ident;
#else
    // made-up thread identifier
    return 1234;
#endif
}

static INLINE Signed _rpygil_acquire_fast_path(void)
{
    return pypy_compare_and_swap(&rpy_fastgil, 0, _rpygil_get_my_ident());
}

static INLINE void _RPyGilAcquire(void) {
    /* see thread_gil.c point (5) */
    if (!_rpygil_acquire_fast_path())
        RPyGilAcquireSlowPath();
}
static INLINE void _RPyGilRelease(void) {
    assert(RPY_FASTGIL_LOCKED(rpy_fastgil));
    pypy_lock_release(&rpy_fastgil);
}
static INLINE Signed *_RPyFetchFastGil(void) {
    return &rpy_fastgil;
}
static INLINE Signed _RPyGilGetHolder(void) {
    return rpy_fastgil;
}



#endif /* _SRC_THREADLOCAL_H */
