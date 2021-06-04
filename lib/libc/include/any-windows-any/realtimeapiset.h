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

#endif /* WINAPI_PARTITION_DESKTOP */

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)

  WINBASEAPI VOID WINAPI QueryInterruptTimePrecise (PULONGLONG lpInterruptTimePrecise);
  WINBASEAPI VOID WINAPI QueryUnbiasedInterruptTimePrecise (PULONGLONG lpUnbiasedInterruptTimePrecise);
  WINBASEAPI VOID WINAPI QueryInterruptTime (PULONGLONG lpInterruptTime);

#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI QueryUnbiasedInterruptTime (PULONGLONG UnbiasedTime);
#endif

  WINBASEAPI HRESULT WINAPI QueryAuxiliaryCounterFrequency (PULONGLONG lpAuxiliaryCounterFrequency);
  WINBASEAPI HRESULT WINAPI ConvertAuxiliaryCounterToPerformanceCounter (ULONGLONG ullAuxiliaryCounterValue, PULONGLONG lpPerformanceCounterValue, PULONGLONG lpConversionError);
  WINBASEAPI HRESULT WINAPI ConvertPerformanceCounterToAuxiliaryCounter (ULONGLONG ullPerformanceCounterValue, PULONGLONG lpAuxiliaryCounterValue, PULONGLONG lpConversionError);

#endif /* WINAPI_PARTITION_APP */

#ifdef __cplusplus
}
#endif

#endif /* _APISETREALTIME_ */
