/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <oscalls.h>
#include <internal.h>
#include <process.h>
#include <math.h>
#include <stdlib.h>
#include <tchar.h>
#include <sect_attribs.h>
#include <locale.h>

extern const PIMAGE_TLS_CALLBACK __dyn_tls_init_callback;

void * __cdecl
_decode_pointer (void *codedptr)
{
  return (void *) codedptr;
}

void * __cdecl
_encode_pointer (void *ptr)
{
  return ptr;
}

/* 0:console, 1:windows.  */
int mingw_app_type = 0;
