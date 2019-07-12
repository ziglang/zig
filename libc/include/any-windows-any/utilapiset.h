/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISETUTIL_
#define _APISETUTIL_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI PVOID WINAPI EncodePointer (PVOID Ptr);
  WINBASEAPI PVOID WINAPI DecodePointer (PVOID Ptr);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI PVOID WINAPI EncodeSystemPointer (PVOID Ptr);
  WINBASEAPI PVOID WINAPI DecodeSystemPointer (PVOID Ptr);
  WINBASEAPI WINBOOL WINAPI Beep (DWORD dwFreq, DWORD dwDuration);
#endif

#ifdef __cplusplus
}
#endif
#endif
