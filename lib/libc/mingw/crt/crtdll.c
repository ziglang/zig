/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifdef CRTDLL
#undef CRTDLL
#ifndef _DLL
#define _DLL
#endif

#include <oscalls.h>
#include <internal.h>
#include <stdlib.h>
#include <windows.h>
#define _DECL_DLLMAIN
#include <process.h>
#include <crtdbg.h>

#ifndef _CRTIMP
#ifdef CRTDLL
#define _CRTIMP __declspec(dllexport)
#else
#ifdef _DLL
#define _CRTIMP __declspec(dllimport)
#else
#define _CRTIMP
#endif
#endif
#endif
#include <sect_attribs.h>
#include <locale.h>

extern void __cdecl _initterm(_PVFV *,_PVFV *);
extern void __main ();
extern void _pei386_runtime_relocator (void);
extern _CRTALLOC(".CRT$XIA") _PIFV __xi_a[];
extern _CRTALLOC(".CRT$XIZ") _PIFV __xi_z[];
extern _CRTALLOC(".CRT$XCA") _PVFV __xc_a[];
extern _CRTALLOC(".CRT$XCZ") _PVFV __xc_z[];


/* TLS initialization hook.  */
extern const PIMAGE_TLS_CALLBACK __dyn_tls_init_callback;

static int __proc_attached = 0;

static _onexit_table_t atexit_table;

extern int mingw_app_type;

extern WINBOOL WINAPI DllMain (HANDLE hDllHandle, DWORD dwReason, LPVOID lpreserved);

extern WINBOOL WINAPI DllEntryPoint (HANDLE, DWORD, LPVOID);

static int pre_c_init (void);

_CRTALLOC(".CRT$XIAA") _PIFV pcinit = pre_c_init;

static int
pre_c_init (void)
{
  return _initialize_onexit_table(&atexit_table);
}

WINBOOL WINAPI _CRT_INIT (HANDLE hDllHandle, DWORD dwReason, LPVOID lpreserved)
{
  if (dwReason == DLL_PROCESS_DETACH)
    {
      if (__proc_attached > 0)
	__proc_attached--;
      else
	return FALSE;
    }
  if (dwReason == DLL_PROCESS_ATTACH)
    {
      void *lock_free = NULL;
      void *fiberid = ((PNT_TIB)NtCurrentTeb ())->StackBase;
      int nested = FALSE;
      
      while ((lock_free = InterlockedCompareExchangePointer ((volatile PVOID *) &__native_startup_lock,
							     fiberid, 0)) != 0)
	{
	  if (lock_free == fiberid)
	    {
	      nested = TRUE;
	      break;
	    }
	  Sleep(1000);
	}
      if (__native_startup_state == __initializing)
	{
	  _amsg_exit (31);
	}
      else if (__native_startup_state == __uninitialized)
	{
	  __native_startup_state = __initializing;
	  
	  _initterm ((_PVFV *) (void *) __xi_a, (_PVFV *) (void *) __xi_z);
	}
      if (__native_startup_state == __initializing)
	{
	  _initterm (__xc_a, __xc_z);
	  __native_startup_state = __initialized;
	}
      if (! nested)
	{
	  (void) InterlockedExchangePointer ((volatile PVOID *) &__native_startup_lock, 0);
	}
      if (__dyn_tls_init_callback != NULL)
	{
	  __dyn_tls_init_callback (hDllHandle, DLL_THREAD_ATTACH, lpreserved);
	}
      __proc_attached++;
    }
  else if (dwReason == DLL_PROCESS_DETACH)
    {
      void *lock_free = NULL;
      while ((lock_free = InterlockedCompareExchangePointer ((volatile PVOID *) &__native_startup_lock,(PVOID) 1, 0)) != 0)
	{
	  Sleep(1000);
	}
      if (__native_startup_state != __initialized)
	{
	  _amsg_exit (31);
	}
      else
	{
          _execute_onexit_table(&atexit_table);
	  __native_startup_state = __uninitialized;
	  (void) InterlockedExchangePointer ((volatile PVOID *) &__native_startup_lock, 0);
	}
    }
  return TRUE;
}

static WINBOOL __DllMainCRTStartup (HANDLE, DWORD, LPVOID);

WINBOOL WINAPI DllMainCRTStartup (HANDLE, DWORD, LPVOID);
#if defined(__x86_64__) && !defined(__SEH__)
int __mingw_init_ehandler (void);
#endif

WINBOOL WINAPI
DllMainCRTStartup (HANDLE hDllHandle, DWORD dwReason, LPVOID lpreserved)
{
  mingw_app_type = 0;
  if (dwReason == DLL_PROCESS_ATTACH)
    {
#if defined(__x86_64__) && !defined(__SEH__)
      __mingw_init_ehandler ();
#endif
    }
  return __DllMainCRTStartup (hDllHandle, dwReason, lpreserved);
}

__declspec(noinline) WINBOOL
__DllMainCRTStartup (HANDLE hDllHandle, DWORD dwReason, LPVOID lpreserved)
{
  WINBOOL retcode = TRUE;

  __native_dllmain_reason = dwReason;
  if (dwReason == DLL_PROCESS_DETACH && __proc_attached == 0)
    {
	retcode = FALSE;
	goto i__leave;
    }
  _pei386_runtime_relocator ();
  if (dwReason == DLL_PROCESS_ATTACH || dwReason == DLL_THREAD_ATTACH)
    {
        retcode = _CRT_INIT (hDllHandle, dwReason, lpreserved);
        if (!retcode)
          goto i__leave;
        retcode = DllEntryPoint (hDllHandle, dwReason, lpreserved);
	if (! retcode)
	  {
	    if (dwReason == DLL_PROCESS_ATTACH)
	      _CRT_INIT (hDllHandle, DLL_PROCESS_DETACH, lpreserved);
	    goto i__leave;
	  }
    }
  if (dwReason == DLL_PROCESS_ATTACH)
    __main ();
  retcode = DllMain(hDllHandle,dwReason,lpreserved);
  if (dwReason == DLL_PROCESS_ATTACH && ! retcode)
    {
	DllMain (hDllHandle, DLL_PROCESS_DETACH, lpreserved);
	DllEntryPoint (hDllHandle, DLL_PROCESS_DETACH, lpreserved);
	_CRT_INIT (hDllHandle, DLL_PROCESS_DETACH, lpreserved);
    }
  if (dwReason == DLL_PROCESS_DETACH || dwReason == DLL_THREAD_DETACH)
    {
        retcode = DllEntryPoint (hDllHandle, dwReason, lpreserved);
	if (_CRT_INIT (hDllHandle, dwReason, lpreserved) == FALSE)
	  retcode = FALSE;
    }
i__leave:
  __native_dllmain_reason = UINT_MAX;
  return retcode ;
}
#endif

int __cdecl atexit (_PVFV func)
{
    return _register_onexit_function(&atexit_table, (_onexit_t)func);
}

char __mingw_module_is_dll = 1;
