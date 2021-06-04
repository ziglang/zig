/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <sect_attribs.h>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <corecrt_startup.h>
#include <process.h>


typedef void (__thiscall * dtor_fn)(void*);
int __mingw_cxa_atexit(dtor_fn dtor, void *obj, void *dso);
int __mingw_cxa_thread_atexit(dtor_fn dtor, void *obj, void *dso);

typedef struct dtor_obj dtor_obj;
struct dtor_obj {
  dtor_fn dtor;
  void *obj;
  dtor_obj *next;
};

HANDLE __dso_handle;
extern char __mingw_module_is_dll;

static CRITICAL_SECTION lock;
static int inited = 0;
static dtor_obj *global_dtors = NULL;
static DWORD tls_dtors_slot = TLS_OUT_OF_INDEXES;

int __mingw_cxa_atexit(dtor_fn dtor, void *obj, void *dso) {
  if (!inited)
    return 1;
  assert(!dso || dso == &__dso_handle);
  dtor_obj *handler = (dtor_obj *) calloc(1, sizeof(*handler));
  if (!handler)
    return 1;
  handler->dtor = dtor;
  handler->obj = obj;
  EnterCriticalSection(&lock);
  handler->next = global_dtors;
  global_dtors = handler;
  LeaveCriticalSection(&lock);
  return 0;
}

static void run_dtor_list(dtor_obj **ptr) {
  dtor_obj *list = *ptr;
  while (list) {
    list->dtor(list->obj);
    dtor_obj *next = list->next;
    free(list);
    list = next;
  }
  *ptr = NULL;
}

int __mingw_cxa_thread_atexit(dtor_fn dtor, void *obj, void *dso) {
  if (!inited)
    return 1;
  assert(!dso || dso == &__dso_handle);
  dtor_obj *handler = (dtor_obj *) calloc(1, sizeof(*handler));
  if (!handler)
    return 1;
  handler->dtor = dtor;
  handler->obj = obj;
  handler->next = (dtor_obj *)TlsGetValue(tls_dtors_slot);
  TlsSetValue(tls_dtors_slot, handler);
  return 0;
}

static void WINAPI tls_atexit_callback(HANDLE __UNUSED_PARAM(hDllHandle), DWORD dwReason, LPVOID __UNUSED_PARAM(lpReserved)) {
  if (dwReason == DLL_PROCESS_DETACH) {
    dtor_obj * p = (dtor_obj *)TlsGetValue(tls_dtors_slot);
    run_dtor_list(&p);
    TlsSetValue(tls_dtors_slot, p);
    TlsFree(tls_dtors_slot);
    run_dtor_list(&global_dtors);
  }
}

static void WINAPI tls_callback(HANDLE hDllHandle, DWORD dwReason, LPVOID __UNUSED_PARAM(lpReserved)) {
  dtor_obj * p;
  switch (dwReason) {
  case DLL_PROCESS_ATTACH:
    if (inited == 0) {
      InitializeCriticalSection(&lock);
      __dso_handle = hDllHandle;
      tls_dtors_slot = TlsAlloc();
      /*
       * We can only call _register_thread_local_exe_atexit_callback once
       * in a process; if we call it a second time the process terminates.
       * When DLLs are unloaded, this callback is invoked before we run the
       * _onexit tables, but for exes, we need to ask this to be called before
       * all other registered atexit functions.
       * Since we are registered as a normal TLS callback, we will be called
       * another time later as well, but that doesn't matter, it's safe to
       * invoke this with DLL_PROCESS_DETACH twice.
       */
      if (!__mingw_module_is_dll)
        _register_thread_local_exe_atexit_callback(tls_atexit_callback);
    }
    inited = 1;
    break;
  case DLL_PROCESS_DETACH:
    /*
     * If there are other threads still running that haven't been detached,
     * we don't attempt to run their destructors (MSVC doesn't either), but
     * simply leak the destructor list and whatever resources the destructors
     * would have released.
     *
     * From Vista onwards, we could have used FlsAlloc to get a TLS key that
     * runs a destructor on each thread that has a value attached ot it, but
     * since MSVC doesn't run destructors on other threads in this case,
     * users shouldn't assume it and we don't attempt to do anything potentially
     * risky about it. TL;DR, threads with pending TLS destructors for a DLL
     * need to be joined before unloading the DLL.
     *
     * This gets called both when exiting cleanly (via exit or returning from
     * main, or when a DLL is unloaded), and when exiting bypassing some of
     * the cleanup, by calling _exit or ExitProcess. In the latter cases,
     * destructors (both TLS and global) in loaded DLLs still get called,
     * but none get called for the main executable. This matches what the
     * standard says, but differs from what MSVC does with a dynamically
     * linked CRT (which still runs TLS destructors for the main thread).
     */
    if (__mingw_module_is_dll) {
      p = (dtor_obj *)TlsGetValue(tls_dtors_slot);
      run_dtor_list(&p);
      TlsSetValue(tls_dtors_slot, p);
      /* For DLLs, run dtors when detached. For EXEs, run dtors via the
       * thread local atexit callback, to make sure they don't run when
       * exiting the process with _exit or ExitProcess. */
      run_dtor_list(&global_dtors);
      TlsFree(tls_dtors_slot);
    }
    if (inited == 1) {
      inited = 0;
      DeleteCriticalSection(&lock);
    }
    break;
  case DLL_THREAD_ATTACH:
    break;
  case DLL_THREAD_DETACH:
    p = (dtor_obj *)TlsGetValue(tls_dtors_slot);
    run_dtor_list(&p);
    TlsSetValue(tls_dtors_slot, p);
    break;
  }
}

_CRTALLOC(".CRT$XLB") PIMAGE_TLS_CALLBACK __xl_b = (PIMAGE_TLS_CALLBACK) tls_callback;
