/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifdef CRTDLL
#undef CRTDLL
#endif

#include <internal.h>

int __CRTDECL
#ifdef _UNICODE
_wsetargv (void)
#else
_setargv (void)
#endif
{
  return 0;
}
