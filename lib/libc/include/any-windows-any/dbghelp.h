/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _DBGHELP_
#define _DBGHELP_

#include <_mingw_unicode.h>

#ifdef _WIN64
#ifndef _IMAGEHLP64
#define _IMAGEHLP64
#endif
#endif

#include <psdk_inc/_dbg_LOAD_IMAGE.h>
#include <psdk_inc/_dbg_common.h>

#endif
