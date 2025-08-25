/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <io.h>

int __cdecl __mingw_access(const char *fname, int mode);

int __cdecl access(const char *fname, int mode)
{
  /* On UCRT, unconditionally forward access to __mingw_access. UCRT's
   * access() function return an error if passed the X_OK constant,
   * while msvcrt.dll's access() doesn't. (It's reported that msvcrt.dll's
   * access() also returned errors on X_OK in the version shipped in Vista,
   * but in recent tests it's no longer the case.) */
  return __mingw_access(fname, mode);
}
