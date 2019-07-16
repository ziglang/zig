/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISETREALTIME_
#define _APISETREALTIME_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI QueryThreadCycleTime (HANDLE ThreadHandle, PULONG64 CycleTime);
  WINBASEAPI WINBOOL WINAPI QueryProcessCycleTime (HANDLE ProcessHandle, PULONG64 CycleTime);
  WINBASEAPI WINBOOL WINAPI QueryIdleProcessorCycleTime (PULONG BufferLength, PULONG64 ProcessorIdleCycleTime);
#endif

#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI QueryIdleProcessorCycleTimeEx (USHORT Group, PULONG BufferLength, PULONG64 ProcessorIdleCycleTime);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI QueryUnbiasedInterruptTime (PULONGLONG UnbiasedTime);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
