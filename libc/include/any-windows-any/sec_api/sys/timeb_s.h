/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _TIMEB_H_S
#define _TIMEB_H_S

#include <sys/timeb.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(MINGW_HAS_SECURE_API)

  _CRTIMP errno_t __cdecl _ftime_s(struct __timeb32 *_Time);
  _CRTIMP errno_t __cdecl _ftime64_s(struct __timeb64 *_Time);

#ifndef _USE_32BIT_TIME_T
#define _ftime_s _ftime64_s
#endif
#endif

#ifdef __cplusplus
}
#endif

#endif
