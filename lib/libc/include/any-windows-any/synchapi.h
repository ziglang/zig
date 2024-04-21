/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _SYNCHAPI_H_
#define _SYNCHAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SRWLOCK_INIT RTL_SRWLOCK_INIT

#define INIT_ONCE_STATIC_INIT RTL_RUN_ONCE_INIT

#define INIT_ONCE_CHECK_ONLY RTL_RUN_ONCE_CHECK_ONLY
#define INIT_ONCE_ASYNC RTL_RUN_ONCE_ASYNC
#define INIT_ONCE_INIT_FAILED RTL_RUN_ONCE_INIT_FAILED

#define INIT_ONCE_CTX_RESERVED_BITS RTL_RUN_ONCE_CTX_RESERVED_BITS

#define CONDITION_VARIABLE_INIT RTL_CONDITION_VARIABLE_INIT

#define CONDITION_VARIABLE_LOCKMODE_SHARED RTL_CONDITION_VARIABLE_LOCKMODE_SHARED

#define MUTEX_MODIFY_STATE MUTANT_QUERY_STATE
#define MUTEX_ALL_ACCESS MUTANT_ALL_ACCESS

  typedef RTL_SRWLOCK SRWLOCK, *PSRWLOCK;

  typedef RTL_RUN_ONCE INIT_ONCE;
  typedef PRTL_RUN_ONCE PINIT_ONCE;
  typedef PRTL_RUN_ONCE LPINIT_ONCE;

  typedef WINBOOL (WINAPI *PINIT_ONCE_FN) (PINIT_ONCE InitOnce, PVOID Parameter, PVOID *Context);
  typedef RTL_CONDITION_VARIABLE CONDITION_VARIABLE, *PCONDITION_VARIABLE;

  WINBASEAPI VOID WINAPI EnterCriticalSection (LPCRITICAL_SECTION lpCriticalSection);
  WINBASEAPI VOID WINAPI LeaveCriticalSection (LPCRITICAL_SECTION lpCriticalSection);
  WINBASEAPI WINBOOL WINAPI TryEnterCriticalSection (LPCRITICAL_SECTION lpCriticalSection);
  WINBASEAPI VOID WINAPI DeleteCriticalSection (LPCRITICAL_SECTION lpCriticalSection);
  WINBASEAPI WINBOOL WINAPI SetEvent (HANDLE hEvent);
  WINBASEAPI WINBOOL WINAPI ResetEvent (HANDLE hEvent);
  WINBASEAPI WINBOOL WINAPI ReleaseSemaphore (HANDLE hSemaphore, LONG lReleaseCount, LPLONG lpPreviousCount);
  WINBASEAPI WINBOOL WINAPI ReleaseMutex (HANDLE hMutex);
  WINBASEAPI DWORD WINAPI WaitForSingleObjectEx (HANDLE hHandle, DWORD dwMilliseconds, WINBOOL bAlertable);
  WINBASEAPI DWORD WINAPI WaitForMultipleObjectsEx (DWORD nCount, CONST HANDLE *lpHandles, WINBOOL bWaitAll, DWORD dwMilliseconds, WINBOOL bAlertable);
  WINBASEAPI HANDLE WINAPI OpenMutexW (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCWSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenEventA (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenEventW (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCWSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenSemaphoreW (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCWSTR lpName);
  WINBOOL WINAPI WaitOnAddress (volatile VOID *Address, PVOID CompareAddress, SIZE_T AddressSize, DWORD dwMilliseconds);
  VOID WINAPI WakeByAddressSingle (PVOID Address);
  VOID WINAPI WakeByAddressAll (PVOID Address);
#if _WIN32_WINNT >= 0x0600
#define CREATE_MUTEX_INITIAL_OWNER 0x1

#define CREATE_EVENT_MANUAL_RESET 0x1
#define CREATE_EVENT_INITIAL_SET 0x2

  WINBASEAPI VOID WINAPI InitializeSRWLock (PSRWLOCK SRWLock);
  VOID WINAPI ReleaseSRWLockExclusive (PSRWLOCK SRWLock);
  VOID WINAPI ReleaseSRWLockShared (PSRWLOCK SRWLock);
  VOID WINAPI AcquireSRWLockExclusive (PSRWLOCK SRWLock);
  VOID WINAPI AcquireSRWLockShared (PSRWLOCK SRWLock);
  WINBASEAPI BOOLEAN WINAPI TryAcquireSRWLockExclusive (PSRWLOCK SRWLock);
  WINBASEAPI BOOLEAN WINAPI TryAcquireSRWLockShared (PSRWLOCK SRWLock);
  WINBASEAPI WINBOOL WINAPI InitializeCriticalSectionEx (LPCRITICAL_SECTION lpCriticalSection, DWORD dwSpinCount, DWORD Flags);
  WINBASEAPI VOID WINAPI InitOnceInitialize (PINIT_ONCE InitOnce);
  WINBASEAPI WINBOOL WINAPI InitOnceExecuteOnce (PINIT_ONCE InitOnce, PINIT_ONCE_FN InitFn, PVOID Parameter, LPVOID *Context);
  WINBASEAPI WINBOOL WINAPI InitOnceBeginInitialize (LPINIT_ONCE lpInitOnce, DWORD dwFlags, PBOOL fPending, LPVOID *lpContext);
  WINBASEAPI WINBOOL WINAPI InitOnceComplete (LPINIT_ONCE lpInitOnce, DWORD dwFlags, LPVOID lpContext);
  WINBASEAPI VOID WINAPI InitializeConditionVariable (PCONDITION_VARIABLE ConditionVariable);
  WINBASEAPI VOID WINAPI WakeConditionVariable (PCONDITION_VARIABLE ConditionVariable);
  WINBASEAPI VOID WINAPI WakeAllConditionVariable (PCONDITION_VARIABLE ConditionVariable);
  WINBASEAPI WINBOOL WINAPI SleepConditionVariableCS (PCONDITION_VARIABLE ConditionVariable, PCRITICAL_SECTION CriticalSection, DWORD dwMilliseconds);
  WINBASEAPI WINBOOL WINAPI SleepConditionVariableSRW (PCONDITION_VARIABLE ConditionVariable, PSRWLOCK SRWLock, DWORD dwMilliseconds, ULONG Flags);
  WINBASEAPI HANDLE WINAPI CreateMutexExA (LPSECURITY_ATTRIBUTES lpMutexAttributes, LPCSTR lpName, DWORD dwFlags, DWORD dwDesiredAccess);
  WINBASEAPI HANDLE WINAPI CreateMutexExW (LPSECURITY_ATTRIBUTES lpMutexAttributes, LPCWSTR lpName, DWORD dwFlags, DWORD dwDesiredAccess);
  WINBASEAPI HANDLE WINAPI CreateEventExA (LPSECURITY_ATTRIBUTES lpEventAttributes, LPCSTR lpName, DWORD dwFlags, DWORD dwDesiredAccess);
  WINBASEAPI HANDLE WINAPI CreateEventExW (LPSECURITY_ATTRIBUTES lpEventAttributes, LPCWSTR lpName, DWORD dwFlags, DWORD dwDesiredAccess);
  WINBASEAPI HANDLE WINAPI CreateSemaphoreExW (LPSECURITY_ATTRIBUTES lpSemaphoreAttributes, LONG lInitialCount, LONG lMaximumCount, LPCWSTR lpName, DWORD dwFlags, DWORD dwDesiredAccess);

#define CreateMutexEx __MINGW_NAME_AW(CreateMutexEx)
#define CreateEventEx __MINGW_NAME_AW(CreateEventEx)
#ifdef UNICODE
#define CreateSemaphoreEx CreateSemaphoreExW
#endif
#endif

#ifdef UNICODE
#define OpenMutex OpenMutexW
#define OpenSemaphore OpenSemaphoreW
#endif
#define OpenEvent __MINGW_NAME_AW(OpenEvent)

  typedef VOID (APIENTRY *PTIMERAPCROUTINE) (LPVOID lpArgToCompletionRoutine, DWORD dwTimerLowValue, DWORD dwTimerHighValue);

  typedef RTL_BARRIER SYNCHRONIZATION_BARRIER;
  typedef PRTL_BARRIER PSYNCHRONIZATION_BARRIER;
  typedef PRTL_BARRIER LPSYNCHRONIZATION_BARRIER;

#define SYNCHRONIZATION_BARRIER_FLAGS_SPIN_ONLY 0x01
#define SYNCHRONIZATION_BARRIER_FLAGS_BLOCK_ONLY 0x02
#define SYNCHRONIZATION_BARRIER_FLAGS_NO_DELETE 0x04

  WINBASEAPI VOID WINAPI InitializeCriticalSection (LPCRITICAL_SECTION lpCriticalSection);
  WINBASEAPI WINBOOL WINAPI InitializeCriticalSectionAndSpinCount (LPCRITICAL_SECTION lpCriticalSection, DWORD dwSpinCount);
  WINBASEAPI DWORD WINAPI SetCriticalSectionSpinCount (LPCRITICAL_SECTION lpCriticalSection, DWORD dwSpinCount);
  WINBASEAPI DWORD WINAPI WaitForSingleObject (HANDLE hHandle, DWORD dwMilliseconds);
  WINBASEAPI DWORD WINAPI SleepEx (DWORD dwMilliseconds, WINBOOL bAlertable);
  WINBASEAPI HANDLE WINAPI CreateMutexA (LPSECURITY_ATTRIBUTES lpMutexAttributes, WINBOOL bInitialOwner, LPCSTR lpName);
  WINBASEAPI HANDLE WINAPI CreateMutexW (LPSECURITY_ATTRIBUTES lpMutexAttributes, WINBOOL bInitialOwner, LPCWSTR lpName);
  WINBASEAPI HANDLE WINAPI CreateEventA (LPSECURITY_ATTRIBUTES lpEventAttributes, WINBOOL bManualReset, WINBOOL bInitialState, LPCSTR lpName);
  WINBASEAPI HANDLE WINAPI CreateEventW (LPSECURITY_ATTRIBUTES lpEventAttributes, WINBOOL bManualReset, WINBOOL bInitialState, LPCWSTR lpName);
  WINBASEAPI WINBOOL WINAPI SetWaitableTimer (HANDLE hTimer, const LARGE_INTEGER *lpDueTime, LONG lPeriod, PTIMERAPCROUTINE pfnCompletionRoutine, LPVOID lpArgToCompletionRoutine, WINBOOL fResume);
  WINBASEAPI WINBOOL WINAPI CancelWaitableTimer (HANDLE hTimer);
  WINBASEAPI HANDLE WINAPI OpenWaitableTimerW (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCWSTR lpTimerName);
  WINBOOL WINAPI EnterSynchronizationBarrier (LPSYNCHRONIZATION_BARRIER lpBarrier, DWORD dwFlags);
  WINBOOL WINAPI InitializeSynchronizationBarrier (LPSYNCHRONIZATION_BARRIER lpBarrier, LONG lTotalThreads, LONG lSpinCount);
  WINBOOL WINAPI DeleteSynchronizationBarrier (LPSYNCHRONIZATION_BARRIER lpBarrier);
  WINBASEAPI VOID WINAPI Sleep (DWORD dwMilliseconds);
  WINBASEAPI DWORD WINAPI SignalObjectAndWait (HANDLE hObjectToSignal, HANDLE hObjectToWaitOn, DWORD dwMilliseconds, WINBOOL bAlertable);
#if _WIN32_WINNT >= 0x0600
#define CREATE_WAITABLE_TIMER_MANUAL_RESET 0x1
#define CREATE_WAITABLE_TIMER_HIGH_RESOLUTION 0x2

  WINBASEAPI HANDLE WINAPI CreateWaitableTimerExW (LPSECURITY_ATTRIBUTES lpTimerAttributes, LPCWSTR lpTimerName, DWORD dwFlags, DWORD dwDesiredAccess);

#ifdef UNICODE
#define CreateWaitableTimerEx CreateWaitableTimerExW
#endif
#endif

#if _WIN32_WINNT >= 0x0601
  WINBOOL WINAPI SetWaitableTimerEx (HANDLE hTimer, const LARGE_INTEGER *lpDueTime, LONG lPeriod, PTIMERAPCROUTINE pfnCompletionRoutine, LPVOID lpArgToCompletionRoutine, PREASON_CONTEXT WakeContext, ULONG TolerableDelay);
#endif

#define CreateMutex __MINGW_NAME_AW(CreateMutex)
#define CreateEvent __MINGW_NAME_AW(CreateEvent)

#ifdef UNICODE
#define OpenWaitableTimer OpenWaitableTimerW
#endif

#ifdef __cplusplus
}
#endif
#endif
