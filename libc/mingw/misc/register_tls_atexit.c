/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <process.h>
#include <windows.h>
#include <winnt.h>
#include <stdlib.h>

static _tls_callback_type callback;

static void run_callback(void)
{
  if (callback)
    callback(NULL, DLL_PROCESS_DETACH, 0);
  callback = NULL;
}

void __cdecl _register_thread_local_exe_atexit_callback(_tls_callback_type cb)
{
  callback = cb;
  /* This should guarantee that the callback is called. It won't be run in the
   * exact right spot as intended to, but it will be run. */
  atexit(run_callback);
}

typeof(_register_thread_local_exe_atexit_callback) *__MINGW_IMP_SYMBOL(_register_thread_local_exe_atexit_callback) = _register_thread_local_exe_atexit_callback;
