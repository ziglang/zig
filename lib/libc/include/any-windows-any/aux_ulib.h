/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _AUX_SHLD_LIB_H
#define _AUX_SHLD_LIB_H

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

  WINBOOL WINAPI AuxUlibInitialize (VOID);
  WINBOOL WINAPI AuxUlibSetSystemFileCacheSize (SIZE_T MinimumFileCacheSize, SIZE_T MaximumFileCacheSize, DWORD Flags);
  WINBOOL WINAPI AuxUlibIsDLLSynchronizationHeld (PBOOL SynchronizationHeld);

#ifdef __cplusplus
}
#endif

#endif

#endif
