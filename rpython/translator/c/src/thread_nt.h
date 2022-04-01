#ifndef _THREAD_NT_H
#define _THREAD_NT_H
#include <WinSock2.h>
#include <windows.h>

/*
 * Thread support.
 */

typedef struct RPyOpaque_ThreadLock {
    HANDLE sem;
} NRMUTEX, *PNRMUTEX;

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
#endif


#ifdef _M_IA64
/* On Itanium, use 'acquire' memory ordering semantics */

#define pypy_lock_test_and_set(ptr, value) InterlockedExchangeAcquire64(ptr,value)
#define pypy_compare_and_swap(ptr, oldval, newval)  \
    (InterlockedCompareExchangeAcquire64(ptr, newval, oldval) == oldval)
#define pypy_lock_release(ptr)             (*((volatile __int64 *)ptr) = 0)

#else
#ifdef _WIN64
/* 64-bit, not Itanium */

#define pypy_lock_test_and_set(ptr, value) InterlockedExchange64(ptr, value)
#define pypy_compare_and_swap(ptr, oldval, newval)  \
    (InterlockedCompareExchange64(ptr, newval, oldval) == oldval)
#define pypy_lock_release(ptr)             (*((volatile __int64 *)ptr) = 0)

#else
/* 32-bit */

#define pypy_lock_test_and_set(ptr, value) InterlockedExchange(ptr, value)
#define pypy_compare_and_swap(ptr, oldval, newval)  \
    (InterlockedCompareExchange(ptr, newval, oldval) == oldval)
#define pypy_lock_release(ptr)             (*((volatile long *)ptr) = 0)

#endif
#endif
