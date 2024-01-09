/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define __CRT__NO_INLINE
#include <stdlib.h>

long long __cdecl atoll(const char * nptr) { return strtoll(nptr, NULL, 10); }
long long (__cdecl *__MINGW_IMP_SYMBOL(atoll))(const char *) = atoll;

__int64 __attribute__((alias("atoll"))) __cdecl _atoi64(const char * nptr);
__int64 (__cdecl *__MINGW_IMP_SYMBOL(_atoi64))(const char *) = _atoi64;
