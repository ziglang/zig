/**
* This file is part of the mingw-w64 runtime package.
* No warranty is given; refer to the file DISCLAIMER within this package.
*/

#include <winapifamily.h>

#ifndef _AVRT_
#define _AVRT_

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  typedef enum _AVRT_PRIORITY {
    AVRT_PRIORITY_VERYLOW = -2,
    AVRT_PRIORITY_LOW,
    AVRT_PRIORITY_NORMAL,
    AVRT_PRIORITY_HIGH,
    AVRT_PRIORITY_CRITICAL
  } AVRT_PRIORITY,*PAVRT_PRIORITY;

#define THREAD_ORDER_GROUP_INFINITE_TIMEOUT (-1LL)

#define AVRTAPI

  WINBOOL WINAPI AvQuerySystemResponsiveness (HANDLE AvrtHandle, PULONG SystemResponsivenessValue);
  WINBOOL WINAPI AvRevertMmThreadCharacteristics (HANDLE AvrtHandle);
  WINBOOL WINAPI AvRtCreateThreadOrderingGroup (PHANDLE Context, PLARGE_INTEGER Period, GUID *ThreadOrderingGuid, PLARGE_INTEGER Timeout);
  WINBOOL WINAPI AvRtCreateThreadOrderingGroupExA (PHANDLE Context, PLARGE_INTEGER Period, GUID *ThreadOrderingGuid, PLARGE_INTEGER Timeout, LPCSTR TaskName);
  WINBOOL WINAPI AvRtCreateThreadOrderingGroupExW (PHANDLE Context, PLARGE_INTEGER Period, GUID *ThreadOrderingGuid, PLARGE_INTEGER Timeout, LPCWSTR TaskName);
  WINBOOL WINAPI AvRtDeleteThreadOrderingGroup (HANDLE Context);
  WINBOOL WINAPI AvRtJoinThreadOrderingGroup (PHANDLE Context, GUID *ThreadOrderingGuid, WINBOOL Before);
  WINBOOL WINAPI AvRtLeaveThreadOrderingGroup (HANDLE Context);
  WINBOOL WINAPI AvRtWaitOnThreadOrderingGroup (HANDLE Context);
  HANDLE WINAPI AvSetMmMaxThreadCharacteristicsA (LPCSTR FirstTask, LPCSTR SecondTask, LPDWORD TaskIndex);
  HANDLE WINAPI AvSetMmMaxThreadCharacteristicsW (LPCWSTR FirstTask, LPCWSTR SecondTask, LPDWORD TaskIndex);
  HANDLE WINAPI AvSetMmThreadCharacteristicsA (LPCSTR TaskName, LPDWORD TaskIndex);
  HANDLE WINAPI AvSetMmThreadCharacteristicsW (LPCWSTR TaskName, LPDWORD TaskIndex);
  WINBOOL WINAPI AvSetMmThreadPriority (HANDLE AvrtHandle, AVRT_PRIORITY Priority);

#define AvSetMmThreadCharacteristics __MINGW_NAME_AW(AvSetMmThreadCharacteristics)
#define AvSetMmMaxThreadCharacteristics __MINGW_NAME_AW(AvSetMmMaxThreadCharacteristics)
#define AvRtCreateThreadOrderingGroupEx __MINGW_NAME_AW(AvRtCreateThreadOrderingGroupEx)

#endif

#ifdef __cplusplus
}
#endif

#endif
