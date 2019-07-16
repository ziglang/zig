/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _UASTRFNC_H_
#define _UASTRFNC_H_

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _X86_
#define ALIGNMENT_MACHINE
#endif

#ifdef ALIGNMENT_MACHINE
#define IS_ALIGNED(p) (((ULONG_PTR)(p) & (sizeof(*(p))-1))==0)

  UNALIGNED WCHAR *ualstrcpynW(UNALIGNED WCHAR *lpString1,UNALIGNED const WCHAR *lpString2,int iMaxLength);
  int ualstrcmpiW(UNALIGNED const WCHAR *dst,UNALIGNED const WCHAR *src);
  int ualstrcmpW(UNALIGNED const WCHAR *src,UNALIGNED const WCHAR *dst);
  size_t ualstrlenW(UNALIGNED const WCHAR *wcs);
  UNALIGNED WCHAR *ualstrcpyW(UNALIGNED WCHAR *dst,UNALIGNED const WCHAR *src);
#else
#define ualstrcpynW StrCpyNW
#define ualstrcmpiW StrCmpIW
#define ualstrcmpW StrCmpW
#define ualstrlenW lstrlenW
#define ualstrcpyW StrCpyW
#endif

#define ualstrcpynA lstrcpynA
#define ualstrcmpiA lstrcmpiA
#define ualstrcmpA lstrcmpA
#define ualstrlenA lstrlenA
#define ualstrcpyA lstrcpyA

#define ualstrcpyn __MINGW_NAME_AW(ualstrcpyn)
#define ualstrcmpi __MINGW_NAME_AW(ualstrcmpi)
#define ualstrcmp __MINGW_NAME_AW(ualstrcmp)
#define ualstrlen __MINGW_NAME_AW(ualstrlen)
#define ualstrcpy __MINGW_NAME_AW(ualstrcpy)

#ifdef __cplusplus
}
#endif
#endif
