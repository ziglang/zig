/* Posix threads interface (from CPython) */

/* XXX needs to detect HAVE_BROKEN_POSIX_SEMAPHORES properly; currently
   it is set only if _POSIX_SEMAPHORES == -1.  Seems to be only for
   SunOS/5.8 and AIX/5.
*/

#include <unistd.h>   /* for the _POSIX_xxx and _POSIX_THREAD_xxx defines */
#include <pthread.h>

/* The POSIX spec says that implementations supporting the sem_*
   family of functions must indicate this by defining
   _POSIX_SEMAPHORES. */   
#ifdef _POSIX_SEMAPHORES
/* On FreeBSD 4.x, _POSIX_SEMAPHORES is defined empty, so 
   we need to add 0 to make it work there as well. */
#if (_POSIX_SEMAPHORES+0) == -1
#define HAVE_BROKEN_POSIX_SEMAPHORES
#else
#include <semaphore.h>
#endif
#endif

/* Whether or not to use semaphores directly rather than emulating them with
 * mutexes and condition variables:
 */
#if defined(_POSIX_SEMAPHORES) && !defined(HAVE_BROKEN_POSIX_SEMAPHORES)
#  define USE_SEMAPHORES
#else
#  undef USE_SEMAPHORES
#endif


/********************* structs ***********/

#ifdef USE_SEMAPHORES

#include <semaphore.h>

struct RPyOpaque_ThreadLock {
	sem_t sem;
	int initialized;
};

#else /* !USE_SEMAPHORE */

/* A pthread mutex isn't sufficient to model the Python lock type
   (see explanations in CPython's Python/thread_pthread.h */
struct RPyOpaque_ThreadLock {
	char             locked; /* 0=unlocked, 1=locked */
	char             initialized;
	/* a <cond, mutex> pair to handle an acquire of a locked lock */
	pthread_cond_t   lock_released;
	pthread_mutex_t  mut;
	struct RPyOpaque_ThreadLock *prev, *next;
};

#endif /* USE_SEMAPHORE */

/* prototypes */

RPY_EXTERN
Signed RPyThreadStart(void (*func)(void));
RPY_EXTERN
Signed RPyThreadStartEx(void (*func)(void *), void *arg);
RPY_EXTERN
int RPyThreadLockInit(struct RPyOpaque_ThreadLock *lock);
RPY_EXTERN
void RPyOpaqueDealloc_ThreadLock(struct RPyOpaque_ThreadLock *lock);
RPY_EXTERN
int RPyThreadAcquireLock(struct RPyOpaque_ThreadLock *lock, int waitflag);
RPY_EXTERN
RPyLockStatus RPyThreadAcquireLockTimed(struct RPyOpaque_ThreadLock *lock,
					RPY_TIMEOUT_T timeout, int intr_flag);
RPY_EXTERN
Signed RPyThreadReleaseLock(struct RPyOpaque_ThreadLock *lock);
RPY_EXTERN
Signed RPyThreadGetStackSize(void);
RPY_EXTERN
Signed RPyThreadSetStackSize(Signed);
RPY_EXTERN
void RPyThreadAfterFork(void);


#define pypy_compare_and_swap(ptr, oldval, newval)  \
                            __sync_bool_compare_and_swap(ptr, oldval, newval)
#define pypy_lock_test_and_set(ptr, value)  __sync_lock_test_and_set(ptr, value)
#define pypy_lock_release(ptr)              __sync_lock_release(ptr)
