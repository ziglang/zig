/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <crtdefs.h>
#include <sect_attribs.h>
#include <corecrt_startup.h>

__declspec(dllimport) int __lconv_init (void);

int __mingw_initcharmax = 0;

int _charmax = 255;

static int my_lconv_init(void)
{
  return __lconv_init();
}

_CRTALLOC(".CRT$XIC") _PIFV __mingw_pinit = my_lconv_init;
