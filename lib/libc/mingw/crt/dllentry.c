/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <oscalls.h>
#define _DECL_DLLMAIN
#include <process.h>

BOOL WINAPI DllEntryPoint (HANDLE, DWORD, LPVOID);

BOOL WINAPI DllEntryPoint (HANDLE __UNUSED_PARAM(hDllHandle),
			   DWORD  __UNUSED_PARAM(dwReason),
			   LPVOID __UNUSED_PARAM(lpreserved))
{
  return TRUE;
}
