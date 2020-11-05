/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw.h>
#include "../revstamp.h"

const char *__mingw_get_crt_info (void)
{
  return "MinGW-W64 Runtime " __MINGW64_VERSION_STR " ("
         __MINGW64_VERSION_STATE " - "
	 "rev. " __MINGW_W64_REV ") " __MINGW_W64_REV_STAMP;
}

