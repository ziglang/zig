/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_CRTDBG_S
#define _INC_CRTDBG_S

#include <crtdbg.h>

#if defined(MINGW_HAS_SECURE_API)

#define _dupenv_s_dbg(ps1,size,s2,t,f,l) _dupenv_s(ps1,size,s2)
#define _wdupenv_s_dbg(ps1,size,s2,t,f,l) _wdupenv_s(ps1,size,s2)

#endif

#endif
