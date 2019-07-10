/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 *
 * Written by Kai Tietz  <kai.tietz@onevision.com>
 *
 * This file is used by if gcc is built with --enable-threads=win32.
 *
 * Based on version created by Mumit Khan  <khan@nanotech.wisc.edu>
 *
 */

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <stdlib.h>

extern void __cdecl __MINGW_NOTHROW _fpreset (void);
WINBOOL __mingw_TLScallback (HANDLE hDllHandle, DWORD reason, LPVOID reserved);
int ___w64_mingwthr_remove_key_dtor (DWORD key);
int ___w64_mingwthr_add_key_dtor (DWORD key, void (*dtor)(void *));

/* To protect the thread/key association data structure modifications. */
static CRITICAL_SECTION __mingwthr_cs;
static volatile int __mingwthr_cs_init = 0;

typedef struct __mingwthr_key __mingwthr_key_t;

/* The list of threads active with key/dtor pairs. */
struct __mingwthr_key {
  DWORD key;
  void (*dtor)(void *);
  __mingwthr_key_t volatile *next;
};


static __mingwthr_key_t volatile *key_dtor_list;

int
___w64_mingwthr_add_key_dtor (DWORD key, void (*dtor)(void *))
{
  __mingwthr_key_t *new_key;

  if (__mingwthr_cs_init == 0)
    return 0;
  new_key = (__mingwthr_key_t *) calloc (1, sizeof (__mingwthr_key_t));
  if (new_key == NULL)
    return -1;

  new_key->key = key;
  new_key->dtor = dtor;

  EnterCriticalSection (&__mingwthr_cs);

  new_key->next = key_dtor_list;
  key_dtor_list = new_key;

  LeaveCriticalSection (&__mingwthr_cs);
  return 0;
}

int
___w64_mingwthr_remove_key_dtor (DWORD key)
{
  __mingwthr_key_t volatile *prev_key;
  __mingwthr_key_t volatile *cur_key;

  if (__mingwthr_cs_init == 0)
    return 0;

  EnterCriticalSection (&__mingwthr_cs);

  prev_key = NULL;
  cur_key = key_dtor_list;

  while (cur_key != NULL)
    {
      if ( cur_key->key == key)
        {
          if (prev_key == NULL)
            key_dtor_list = cur_key->next;
          else
            prev_key->next = cur_key->next;

          free ((void*)cur_key);
          break;
        }
      prev_key = cur_key;
      cur_key = cur_key->next;
    }

  LeaveCriticalSection (&__mingwthr_cs);
  return 0;
}

static void
__mingwthr_run_key_dtors (void)
{
  __mingwthr_key_t volatile *keyp;

  if (__mingwthr_cs_init == 0)
    return;
  EnterCriticalSection (&__mingwthr_cs);

  for (keyp = key_dtor_list; keyp; )
    {
      LPVOID value = TlsGetValue (keyp->key);
      if (GetLastError () == ERROR_SUCCESS)
        {
          if (value)
            (*keyp->dtor) (value);
        }
      keyp = keyp->next;
    }

  LeaveCriticalSection (&__mingwthr_cs);
}

WINBOOL
__mingw_TLScallback (HANDLE __UNUSED_PARAM(hDllHandle),
		     DWORD reason,
		     LPVOID __UNUSED_PARAM(reserved))
{
  switch (reason)
    {
    case DLL_PROCESS_ATTACH:
      if (__mingwthr_cs_init == 0)
        InitializeCriticalSection (&__mingwthr_cs);
      __mingwthr_cs_init = 1;
      break;
    case DLL_PROCESS_DETACH:
      __mingwthr_run_key_dtors();
      if (__mingwthr_cs_init == 1)
        {
          __mingwthr_key_t volatile *keyp, *t;
          for (keyp = key_dtor_list; keyp; )
          {
            t = keyp->next;
            free((void *)keyp);
            keyp = t;
          }
          key_dtor_list = NULL;
          __mingwthr_cs_init = 0;
          DeleteCriticalSection (&__mingwthr_cs);
        }
      break;
    case DLL_THREAD_ATTACH:
      _fpreset();
      break;
    case DLL_THREAD_DETACH:
      __mingwthr_run_key_dtors();
      break;
    }
  return TRUE;
}

