/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _WOW64APISET_H_
#define _WOW64APISET_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI Wow64DisableWow64FsRedirection (PVOID *OldValue);
  WINBASEAPI WINBOOL WINAPI Wow64RevertWow64FsRedirection (PVOID OlValue);

  WINBASEAPI UINT WINAPI GetSystemWow64DirectoryA (LPSTR lpBuffer, UINT uSize);
  WINBASEAPI UINT WINAPI GetSystemWow64DirectoryW (LPWSTR lpBuffer, UINT uSize);
  #define GetSystemWow64Directory __MINGW_NAME_AW(GetSystemWow64Directory)

  #if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI Wow64GetThreadContext (HANDLE hThread, PWOW64_CONTEXT lpContext);
  WINBASEAPI WINBOOL WINAPI Wow64SetThreadContext (HANDLE hThread, CONST WOW64_CONTEXT *lpContext);
  WINBASEAPI DWORD WINAPI Wow64SuspendThread (HANDLE hThread);
  #endif

  #if _WIN32_WINNT >= 0x0A00
  WINBASEAPI USHORT WINAPI Wow64SetThreadDefaultGuestMachine (USHORT Machine);

  WINBASEAPI UINT WINAPI GetSystemWow64Directory2A (LPSTR lpBuffer, UINT uSize, WORD ImageFileMachineType);
  WINBASEAPI UINT WINAPI GetSystemWow64Directory2W (LPWSTR lpBuffer, UINT uSize, WORD ImageFileMachineType);
  #define GetSystemWow64Directory2 __MINGW_NAME_AW(GetSystemWow64Directory2)

  WINBASEAPI HRESULT WINAPI IsWow64GuestMachineSupported (USHORT WowGuestMachine, WINBOOL *MachineIsSupported);
  #endif

#endif /* WINAPI_PARTITION_DESKTOP */

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI IsWow64Process (HANDLE hProcess, PBOOL Wow64Process);

  #if _WIN32_WINNT >= 0x0A00
  WINBASEAPI WINBOOL WINAPI IsWow64Process2 (HANDLE hProcess, USHORT *pProcessMachine, USHORT *pNativeMachine);
  #endif

#endif /* WINAPI_PARTITION_APP */

#ifdef __cplusplus
}
#endif
#endif
