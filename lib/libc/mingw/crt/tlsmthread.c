/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 *
 * Written by Kai Tietz  <kai.tietz@onevision.com>
 */
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <stdlib.h>

int __mingwthr_key_dtor (DWORD key, void (*dtor)(void *));
int __mingwthr_remove_key_dtor (DWORD key);

extern int ___w64_mingwthr_remove_key_dtor (DWORD key);
extern int ___w64_mingwthr_add_key_dtor (DWORD key, void (*dtor)(void *));

int
__mingwthr_remove_key_dtor (DWORD key)
{
   return ___w64_mingwthr_remove_key_dtor (key);
}

int
__mingwthr_key_dtor (DWORD key, void (*dtor)(void *))
{
  if (dtor)
    return ___w64_mingwthr_add_key_dtor (key, dtor);

  return 0;
}
