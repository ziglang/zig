/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT

#include <stdio.h>
#include <stdlib.h>
#include <internal.h>

void __cdecl __MINGW_ATTRIB_NORETURN _amsg_exit(int ret)
{
  fprintf(stderr, "runtime error %d\n", ret);
  _exit(255);
}
void __cdecl (*__MINGW_IMP_SYMBOL(_amsg_exit))(int) = _amsg_exit;
