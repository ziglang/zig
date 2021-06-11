/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISETHANDLE_
#define _APISETHANDLE_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define INVALID_HANDLE_VALUE ((HANDLE) (LONG_PTR)-1)

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI CloseHandle (HANDLE hObject);
  WINBASEAPI WINBOOL WINAPI DuplicateHandle (HANDLE hSourceProcessHandle, HANDLE hSourceHandle, HANDLE hTargetProcessHandle, LPHANDLE lpTargetHandle, DWORD dwDesiredAccess, WINBOOL bInheritHandle, DWORD dwOptions);
#if _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI WINBOOL WINAPI CompareObjectHandles (HANDLE hFirstObjectHandle, HANDLE hSecondObjectHandle);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI GetHandleInformation (HANDLE hObject, LPDWORD lpdwFlags);
  WINBASEAPI WINBOOL WINAPI SetHandleInformation (HANDLE hObject, DWORD dwMask, DWORD dwFlags);
#endif

#ifdef __cplusplus
}
#endif
#endif
