/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define INITGUID
#include <guiddef.h>

#ifndef DECLSPEC_SELECTANY
#define DECLSPEC_SELECTANY __declspec(selectany)
#endif

#ifdef DEFINE_GUIDEX
#undef DEFINE_GUIDEX
#endif

#ifdef __cplusplus
#define DEFINE_GUIDEX(name) EXTERN_C const CDECL GUID DECLSPEC_SELECTANY name = { STATICGUIDOF(name) }
#else
#define DEFINE_GUIDEX(name) const CDECL GUID DECLSPEC_SELECTANY name = { STATICGUIDOF(name) }
#endif
#ifndef STATICGUIDOF
#define STATICGUIDOF(guid) STATIC_##guid
#endif

#ifndef DEFINE_WAVEFORMATEX_GUID
#define DEFINE_WAVEFORMATEX_GUID(x) (USHORT)(x),0x0000,0x0010,0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71
#endif
