/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _PROFILEAPI_H_
#define _PROFILEAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

  WINBASEAPI WINBOOL WINAPI QueryPerformanceCounter (LARGE_INTEGER *lpPerformanceCount);
  WINBASEAPI WINBOOL WINAPI QueryPerformanceFrequency (LARGE_INTEGER *lpFrequency);

#ifdef __cplusplus
}
#endif

#endif
