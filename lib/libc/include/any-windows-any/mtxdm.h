/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MTXDM_H__
#define __MTXDM_H__

#include "comsvcs.h"

#ifdef __cplusplus
extern "C" {
#endif

  __declspec(dllimport) HRESULT __cdecl GetDispenserManager(IDispenserManager **);

#ifdef __cplusplus
}
#endif
#endif
