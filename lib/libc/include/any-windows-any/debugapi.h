/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISETDEBUG_
#define _APISETDEBUG_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI IsDebuggerPresent (VOID);
  WINBASEAPI VOID WINAPI OutputDebugStringA (LPCSTR lpOutputString);
  WINBASEAPI VOID WINAPI OutputDebugStringW (LPCWSTR lpOutputString);

#define OutputDebugString __MINGW_NAME_AW(OutputDebugString)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI VOID WINAPI DebugBreak (VOID);
  WINBASEAPI WINBOOL APIENTRY ContinueDebugEvent (DWORD dwProcessId, DWORD dwThreadId, DWORD dwContinueStatus);
  WINBASEAPI WINBOOL APIENTRY WaitForDebugEvent (LPDEBUG_EVENT lpDebugEvent, DWORD dwMilliseconds);
  WINBASEAPI WINBOOL APIENTRY DebugActiveProcess (DWORD dwProcessId);
  WINBASEAPI WINBOOL APIENTRY DebugActiveProcessStop (DWORD dwProcessId);
  WINBASEAPI WINBOOL WINAPI CheckRemoteDebuggerPresent (HANDLE hProcess, PBOOL pbDebuggerPresent);
#endif

#ifdef __cplusplus
}
#endif
#endif
