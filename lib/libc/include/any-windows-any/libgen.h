/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _LIBGEN_H_
#define _LIBGEN_H_

#include <crtdefs.h>

#ifdef __cplusplus
extern "C" {
#endif

 char * __cdecl __MINGW_NOTHROW basename (char *);
 char * __cdecl __MINGW_NOTHROW dirname (char *);

#ifdef __cplusplus
}
#endif

#endif

