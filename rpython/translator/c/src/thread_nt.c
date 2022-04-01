/* Copy-and-pasted from CPython */

/* This code implemented by Dag.Gruneau@elsa.preseco.comm.se */
/* Fast NonRecursiveMutex support by Yakov Markovitch, markovitch@iso.ru */
/* Eliminated some memory leaks, gsw@agere.com */

#include <windows.h>
#include <stdio.h>
#include <limits.h>
#include <process.h>


/*
 * Thread support.
 */
/* In rpython, this file is pulled in by thread.c */

typedef struct RPyOpaque_ThreadLock NRMUTEX, *PNRMUTEX;

typedef struct {
	void (*func)(void *);
	void *arg;
	Signed id;
	HANDLE done;
} callobj;

/* win64: _beginthread takes a UINT so we can store this in a long */
static long _pypythread_stacksize = 0;

static void gil_fatal(const char *msg, DWORD dw) {
    fprintf(stderr, "Fatal error in the GIL or with locks: %s [%x,%x]\n",
                    msg, (int)dw, (int)GetLastError());
    abort();
}

static void
bootstrap(void *call)
{
	callobj *obj = (callobj*)call;
	/* copy callobj since other thread might free it before we're done */
	void (*func)(void *) = obj->func;
	void *arg = obj->arg;

	obj->id = (Signed)GetCurrentThreadId();
	if (!ReleaseSemaphore(obj->done, 1, NULL))
        gil_fatal("bootstrap ReleaseSemaphore", 0);
	func(arg);
}

Signed RPyThreadStart(void (*func)(void))
{
    /* a kind-of-invalid cast, but the 'func' passed here doesn't expect
       any argument, so it's unlikely to cause problems */
    return RPyThreadStartEx((void(*)(void *))func, NULL);
}

Signed RPyThreadStartEx(void (*func)(void *), void *arg)
{
	Unsigned rv;
	callobj obj;

	obj.id = -1;	/* guilty until proved innocent */
	obj.func = func;
	obj.arg = arg;
	obj.done = CreateSemaphore(NULL, 0, 1, NULL);
	if (obj.done == NULL)
		return -1;

	rv = _beginthread(bootstrap, _pypythread_stacksize, &obj);
	if (rv == (Unsigned)-1) {
		/* I've seen errno == EAGAIN here, which means "there are
		 * too many threads".
		 */
		obj.id = -1;
	}
	else {
		/* wait for thread to initialize, so we can get its id */
        DWORD res = WaitForSingleObject(obj.done, INFINITE);
        if (res != WAIT_OBJECT_0)
            gil_fatal("WaitForSingleObject(obj.done) failed", res);
        if (obj.id == -1)
            gil_fatal("obj.id == -1", 0);
	}
	CloseHandle((HANDLE)obj.done);
	return obj.id;
}

/************************************************************/

/* minimum/maximum thread stack sizes supported */
/* win64: _beginthread takes a UINT, so max must be <4GB.
   It is also stored in a LONG (see above), it must be <2GB.
   The functions below take Signed to simplify Python code. */
#define THREAD_MIN_STACKSIZE    0x8000      /* 32kB */
#define THREAD_MAX_STACKSIZE    0x10000000  /* 256MB */

Signed RPyThreadGetStackSize(void)
{
	return _pypythread_stacksize;
}

Signed RPyThreadSetStackSize(Signed newsize)
{
	if (newsize == 0) {    /* set to default */
		_pypythread_stacksize = 0;
		return 0;
	}

	/* check the range */
	if (newsize >= THREAD_MIN_STACKSIZE && newsize < THREAD_MAX_STACKSIZE) {
	    /* win64: this cast is safe, see THREAD_MAX_STACKSIZE comment */
		_pypythread_stacksize = (long) newsize;
		return 0;
	}
	return -1;
}

/************************************************************/


static
BOOL InitializeNonRecursiveMutex(PNRMUTEX mutex)
{
    mutex->sem = CreateSemaphore(NULL, 1, 1, NULL);
    return !!mutex->sem;
}

static
VOID DeleteNonRecursiveMutex(PNRMUTEX mutex)
{
    /* No in-use check */
    CloseHandle(mutex->sem);
    mutex->sem = NULL ; /* Just in case */
}

static
DWORD EnterNonRecursiveMutex(PNRMUTEX mutex, RPY_TIMEOUT_T milliseconds)
{
    DWORD res;

    if (milliseconds < 0) {
        res = WaitForSingleObject(mutex->sem, INFINITE);
        if (res != WAIT_OBJECT_0)
            gil_fatal("EnterNonRecursiveMutex(INFINITE)", res);
        return res;
    }

    while (milliseconds >= (RPY_TIMEOUT_T)INFINITE) {
        res = WaitForSingleObject(mutex->sem, INFINITE - 1);
        if (res != WAIT_TIMEOUT) {
            if (res != WAIT_OBJECT_0)
                gil_fatal("EnterNonRecursiveMutex(INFINITE - 1)", res);
            return res;
        }
        milliseconds -= (RPY_TIMEOUT_T)(INFINITE - 1);
    }
    res = WaitForSingleObject(mutex->sem, (DWORD)milliseconds);
    if (res != WAIT_TIMEOUT && res != WAIT_OBJECT_0)
        gil_fatal("EnterNonRecursiveMutex(ms)", res);
    return res;
}

static
BOOL LeaveNonRecursiveMutex(PNRMUTEX mutex)
{
    return ReleaseSemaphore(mutex->sem, 1, NULL);
}

/************************************************************/

void RPyThreadAfterFork(void)
{
}

int RPyThreadLockInit(struct RPyOpaque_ThreadLock *lock)
{
  return InitializeNonRecursiveMutex(lock);
}

void RPyOpaqueDealloc_ThreadLock(struct RPyOpaque_ThreadLock *lock)
{
    if (lock->sem != NULL)
	DeleteNonRecursiveMutex(lock);
}

/*
 * Return 1 on success if the lock was acquired
 *
 * and 0 if the lock was not acquired. This means a 0 is returned
 * if the lock has already been acquired by this thread!
 */
RPyLockStatus
RPyThreadAcquireLockTimed(struct RPyOpaque_ThreadLock *lock,
			  RPY_TIMEOUT_T microseconds, int intr_flag)
{
    /* Fow now, intr_flag does nothing on Windows, and lock acquires are
     * uninterruptible.  */
    RPyLockStatus success;
    RPY_TIMEOUT_T milliseconds = -1;

    if (microseconds >= 0) {
        milliseconds = microseconds / 1000;
        if (microseconds % 1000 > 0)
            ++milliseconds;
    }

    if (lock && EnterNonRecursiveMutex(lock, milliseconds) == WAIT_OBJECT_0) {
        success = RPY_LOCK_ACQUIRED;
    }
    else {
        success = RPY_LOCK_FAILURE;
    }

    return success;
}

int RPyThreadAcquireLock(struct RPyOpaque_ThreadLock *lock, int waitflag)
{
    return RPyThreadAcquireLockTimed(lock, waitflag ? -1 : 0, /*intr_flag=*/0);
}

Signed RPyThreadReleaseLock(struct RPyOpaque_ThreadLock *lock)
{
    if (LeaveNonRecursiveMutex(lock))
        return 0;   /* success */
    else
        return -1;  /* failure: the lock was not previously acquired */
}

/************************************************************/
/* GIL code                                                 */
/************************************************************/

typedef HANDLE mutex2_t;   /* a semaphore, on Windows */

static INLINE void mutex2_init(mutex2_t *mutex) {
    *mutex = CreateSemaphore(NULL, 1, 1, NULL);
    if (*mutex == NULL)
        gil_fatal("CreateSemaphore failed", 0);
}

static INLINE void mutex2_lock(mutex2_t *mutex) {
    DWORD res = WaitForSingleObject(*mutex, INFINITE);
    if (res != WAIT_OBJECT_0)
        gil_fatal("mutex2_lock", res);
}

static INLINE void mutex2_unlock(mutex2_t *mutex) {
    if (!ReleaseSemaphore(*mutex, 1, NULL))
        gil_fatal("mutex2_unlock", 0);
}

static INLINE void mutex2_init_locked(mutex2_t *mutex) {
    mutex2_init(mutex);
    mutex2_lock(mutex);
}

static INLINE void mutex2_loop_start(mutex2_t *mutex) { }
static INLINE void mutex2_loop_stop(mutex2_t *mutex) { }

static INLINE int mutex2_lock_timeout(mutex2_t *mutex, double delay)
{
    DWORD result = WaitForSingleObject(*mutex, (DWORD)(delay * 1000.0 + 0.999));
    if (result != WAIT_TIMEOUT && result != WAIT_OBJECT_0)
        gil_fatal("mutex2_lock_timeout", result);
    return (result != WAIT_TIMEOUT);
}

typedef CRITICAL_SECTION mutex1_t;

static INLINE void mutex1_init(mutex1_t *mutex) {
    InitializeCriticalSection(mutex);
}

static INLINE void mutex1_lock(mutex1_t *mutex) {
    EnterCriticalSection(mutex);
}

static INLINE void mutex1_unlock(mutex1_t *mutex) {
    LeaveCriticalSection(mutex);
}

//#define pypy_lock_test_and_set(ptr, value)  see thread_nt.h
#ifdef _WIN64
#define atomic_increment(ptr)          InterlockedIncrement64(ptr)
#define atomic_decrement(ptr)          InterlockedDecrement64(ptr)
#else
#define atomic_increment(ptr)          InterlockedIncrement(ptr)
#define atomic_decrement(ptr)          InterlockedDecrement(ptr)
#endif
#ifdef YieldProcessor
#  define RPy_YieldProcessor()         YieldProcessor()
#else
#  define RPy_YieldProcessor()         __asm { rep nop }
#endif
#define RPy_CompilerMemoryBarrier()    _ReadWriteBarrier()

#include "src/thread_gil.c"
