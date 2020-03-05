/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISETLIBLOADER2_
#define _APISETLIBLOADER2_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#if (_WIN32_WINNT >= 0x0602)

  WINBASEAPI HMODULE WINAPI LoadPackagedLibrary(LPCWSTR lpwLibFileName, DWORD Reserved);
  WINBASEAPI WINBOOL WINAPI QueryOptionalDelayLoadedAPI(HMODULE hParentModule, LPCSTR lpDllName, LPCSTR lpProcName, DWORD Reserved);

#endif
#endif

#ifdef __cplusplus
}
#endif

#endif
