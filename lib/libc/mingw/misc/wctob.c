/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include "mb_wc_common.h"
#include <wchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <windows.h>

/* Return just the first byte after translating to multibyte.  */
int wctob (wint_t wc )
{
    wchar_t w = wc;
    char c;
    int invalid_char = 0;
    if (!WideCharToMultiByte (___lc_codepage_func(),
			      0 /* Is this correct flag? */,
			      &w, 1, &c, 1, NULL, &invalid_char)
	 || invalid_char)
      return EOF;

    return (int) c;
}
