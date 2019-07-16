/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _THREADPOOLLEGACYAPISET_H_
#define _THREADPOOLLEGACYAPISET_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || defined(WINSTORECOMPAT)
  WINBASEAPI WINBOOL WINAPI CreateTimerQueueTimer (PHANDLE phNewTimer, HANDLE TimerQueue, WAITORTIMERCALLBACK Callback, PVOID Parameter, DWORD DueTime, DWORD Period, ULONG Flags);
  WINBASEAPI WINBOOL WINAPI DeleteTimerQueueTimer (HANDLE TimerQueue, HANDLE Timer, HANDLE CompletionEvent);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI QueueUserWorkItem (LPTHREAD_START_ROUTINE Function, PVOID Context, ULONG Flags);
  WINBASEAPI WINBOOL WINAPI UnregisterWaitEx (HANDLE WaitHandle, HANDLE CompletionEvent);
  WINBASEAPI HANDLE WINAPI CreateTimerQueue (VOID);
  WINBASEAPI WINBOOL WINAPI ChangeTimerQueueTimer (HANDLE TimerQueue, HANDLE Timer, ULONG DueTime, ULONG Period);
  WINBASEAPI WINBOOL WINAPI DeleteTimerQueueEx (HANDLE TimerQueue, HANDLE CompletionEvent);
#endif

#ifdef __cplusplus
}
#endif
#endif
