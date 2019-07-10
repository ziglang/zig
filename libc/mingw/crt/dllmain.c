#include <oscalls.h>
#define _DECL_DLLMAIN
#include <process.h>

BOOL WINAPI DllMain (HANDLE __UNUSED_PARAM(hDllHandle),
		     DWORD  __UNUSED_PARAM(dwReason),
		     LPVOID __UNUSED_PARAM(lpreserved))
{
  return TRUE;
}
