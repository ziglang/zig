/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _SSPGUID_H_
#define _SSPGUID_H_

#define IID_DEFINED

#include "scardssp_i.c"

#ifndef CLSCTX_LOCAL
#define CLSCTX_LOCAL (CLSCTX_INPROC_SERVER| CLSCTX_INPROC_HANDLER| CLSCTX_LOCAL_SERVER)
#endif

#endif
