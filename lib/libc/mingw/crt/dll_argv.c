/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifdef CRTDLL
#undef CRTDLL
#endif

#include <internal.h>

extern int _dowildcard;

#ifdef WPRFLAG
int __CRTDECL
__wsetargv (void)
#else
int __CRTDECL
__setargv (void)
#endif
{
  _dowildcard = 1;
  return 0;
}
