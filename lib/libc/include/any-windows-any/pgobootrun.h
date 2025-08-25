/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw_unicode.h>

#ifdef _WCHAR_T_DEFINED
typedef void (__cdecl *POGOAUTOSWEEPPROCW)(const wchar_t *);
#else
typedef void (__cdecl *POGOAUTOSWEEPPROCW)(const unsigned short *);
#endif
typedef void (__cdecl *POGOAUTOSWEEPPROCA)(const char *);

#ifdef __cplusplus
extern "C"
#else
extern
#endif
POGOAUTOSWEEPPROCW PogoAutoSweepW;
#ifdef __cplusplus
extern "C"
#else
extern
#endif
POGOAUTOSWEEPPROCA PogoAutoSweepA;

#define PgoAutoSweep __MINGW_NAME_AW(PogoAutoSweep)
