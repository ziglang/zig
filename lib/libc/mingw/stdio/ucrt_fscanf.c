/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl fscanf(FILE * __restrict__ _File,const char * __restrict__ _Format,...) {
  __builtin_va_list __ap;
  int __ret;
  __builtin_va_start(__ap, _Format);
  __ret = __stdio_common_vfscanf(0, _File, _Format, NULL, __ap);
  __builtin_va_end(__ap);
  return __ret;
}
int __cdecl (*__MINGW_IMP_SYMBOL(fscanf))(FILE *__restrict__, const char *__restrict__, ...) = fscanf;
