/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _THREADPOOLAPISET_H_
#define _THREADPOOLAPISET_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  typedef VOID (WINAPI *PTP_WIN32_IO_CALLBACK) (PTP_CALLBACK_INSTANCE Instance, PVOID Context, PVOID Overlapped, ULONG IoResult, ULONG_PTR NumberOfBytesTransferred, PTP_IO Io);

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI PTP_POOL WINAPI CreateThreadpool (PVOID reserved);
  WINBASEAPI VOID WINAPI SetThreadpoolThreadMaximum (PTP_POOL ptpp, DWORD cthrdMost);
  WINBASEAPI WINBOOL WINAPI SetThreadpoolThreadMinimum (PTP_POOL ptpp, DWORD cthrdMic);
  WINBASEAPI WINBOOL WINAPI SetThreadpoolStackInformation (PTP_POOL ptpp, PTP_POOL_STACK_INFORMATION ptpsi);
  WINBASEAPI WINBOOL WINAPI QueryThreadpoolStackInformation (PTP_POOL ptpp, PTP_POOL_STACK_INFORMATION ptpsi);
  WINBASEAPI VOID WINAPI CloseThreadpool (PTP_POOL ptpp);
  WINBASEAPI PTP_CLEANUP_GROUP WINAPI CreateThreadpoolCleanupGroup (VOID);
  WINBASEAPI VOID WINAPI CloseThreadpoolCleanupGroupMembers (PTP_CLEANUP_GROUP ptpcg, WINBOOL fCancelPendingCallbacks, PVOID pvCleanupContext);
  WINBASEAPI VOID WINAPI CloseThreadpoolCleanupGroup (PTP_CLEANUP_GROUP ptpcg);
  WINBASEAPI VOID WINAPI SetEventWhenCallbackReturns (PTP_CALLBACK_INSTANCE pci, HANDLE evt);
  WINBASEAPI VOID WINAPI ReleaseSemaphoreWhenCallbackReturns (PTP_CALLBACK_INSTANCE pci, HANDLE sem, DWORD crel);
  WINBASEAPI VOID WINAPI ReleaseMutexWhenCallbackReturns (PTP_CALLBACK_INSTANCE pci, HANDLE mut);
  WINBASEAPI VOID WINAPI LeaveCriticalSectionWhenCallbackReturns (PTP_CALLBACK_INSTANCE pci, PCRITICAL_SECTION pcs);
  WINBASEAPI VOID WINAPI FreeLibraryWhenCallbackReturns (PTP_CALLBACK_INSTANCE pci, HMODULE mod);
  WINBASEAPI WINBOOL WINAPI CallbackMayRunLong (PTP_CALLBACK_INSTANCE pci);
  WINBASEAPI VOID WINAPI DisassociateCurrentThreadFromCallback (PTP_CALLBACK_INSTANCE pci);
  WINBASEAPI WINBOOL WINAPI TrySubmitThreadpoolCallback (PTP_SIMPLE_CALLBACK pfns, PVOID pv, PTP_CALLBACK_ENVIRON pcbe);
  WINBASEAPI PTP_WORK WINAPI CreateThreadpoolWork (PTP_WORK_CALLBACK pfnwk, PVOID pv, PTP_CALLBACK_ENVIRON pcbe);
  WINBASEAPI VOID WINAPI SubmitThreadpoolWork (PTP_WORK pwk);
  WINBASEAPI VOID WINAPI WaitForThreadpoolWorkCallbacks (PTP_WORK pwk, WINBOOL fCancelPendingCallbacks);
  WINBASEAPI VOID WINAPI CloseThreadpoolWork (PTP_WORK pwk);
  WINBASEAPI PTP_TIMER WINAPI CreateThreadpoolTimer (PTP_TIMER_CALLBACK pfnti, PVOID pv, PTP_CALLBACK_ENVIRON pcbe);
  WINBASEAPI VOID WINAPI SetThreadpoolTimer (PTP_TIMER pti, PFILETIME pftDueTime, DWORD msPeriod, DWORD msWindowLength);
  WINBASEAPI WINBOOL WINAPI IsThreadpoolTimerSet (PTP_TIMER pti);
  WINBASEAPI VOID WINAPI WaitForThreadpoolTimerCallbacks (PTP_TIMER pti, WINBOOL fCancelPendingCallbacks);
  WINBASEAPI VOID WINAPI CloseThreadpoolTimer (PTP_TIMER pti);
  WINBASEAPI PTP_WAIT WINAPI CreateThreadpoolWait (PTP_WAIT_CALLBACK pfnwa, PVOID pv, PTP_CALLBACK_ENVIRON pcbe);
  WINBASEAPI VOID WINAPI SetThreadpoolWait (PTP_WAIT pwa, HANDLE h, PFILETIME pftTimeout);
  WINBASEAPI VOID WINAPI WaitForThreadpoolWaitCallbacks (PTP_WAIT pwa, WINBOOL fCancelPendingCallbacks);
  WINBASEAPI VOID WINAPI CloseThreadpoolWait (PTP_WAIT pwa);
  WINBASEAPI PTP_IO WINAPI CreateThreadpoolIo (HANDLE fl, PTP_WIN32_IO_CALLBACK pfnio, PVOID pv, PTP_CALLBACK_ENVIRON pcbe);
  WINBASEAPI VOID WINAPI StartThreadpoolIo (PTP_IO pio);
  WINBASEAPI VOID WINAPI CancelThreadpoolIo (PTP_IO pio);
  WINBASEAPI VOID WINAPI WaitForThreadpoolIoCallbacks (PTP_IO pio, WINBOOL fCancelPendingCallbacks);
  WINBASEAPI VOID WINAPI CloseThreadpoolIo (PTP_IO pio);
  WINBASEAPI WINBOOL WINAPI SetThreadpoolTimerEx (PTP_TIMER pti, PFILETIME pftDueTime, DWORD msPeriod, DWORD msWindowLength);
  WINBASEAPI WINBOOL WINAPI SetThreadpoolWaitEx (PTP_WAIT pwa, HANDLE h, PFILETIME pftTimeout, PVOID Reserved);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
