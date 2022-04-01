#ifndef __PYPY_THREAD_H
#define __PYPY_THREAD_H
#include "precommondefs.h"
#include <assert.h>

#define RPY_TIMEOUT_T long long

typedef enum RPyLockStatus {
    RPY_LOCK_FAILURE = 0,
    RPY_LOCK_ACQUIRED = 1,
    RPY_LOCK_INTR = 2
} RPyLockStatus;

#ifdef _WIN32
#define RPYTHREAD_NAME "nt"
#include "thread_nt.h"
#else

/* We should check if unistd.h defines _POSIX_THREADS, but sometimes
   it is not defined even though the system implements them as an
   external library (e.g. gnu pth in pthread emulation).  So we just
   always go ahead and use them, assuming they are supported on all
   platforms for which we care.  If not, do some detecting again.
*/
#define RPYTHREAD_NAME "pthread"
#include "thread_pthread.h"

#endif /* !_WIN32 */

RPY_EXTERN void RPyGilAllocate(void);
RPY_EXTERN Signed RPyGilYieldThread(void);
RPY_EXTERN void RPyGilAcquireSlowPath(void);
#define RPyGilAcquire _RPyGilAcquire
#define RPyGilRelease _RPyGilRelease
#define RPyFetchFastGil _RPyFetchFastGil
#define RPyGilGetHolder _RPyGilGetHolder
#define RPY_FASTGIL_LOCKED(x)   (x != 0)

RPY_EXTERN Signed rpy_fastgil;

#endif
