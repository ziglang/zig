/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _APISETSTRING_
#define _APISETSTRING_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <winnls.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI int WINAPI CompareStringW (LCID Locale, DWORD dwCmpFlags, PCNZWCH lpString1, int cchCount1, PCNZWCH lpString2, int cchCount2);
  WINBASEAPI int WINAPI FoldStringW (DWORD dwMapFlags, LPCWCH lpSrcStr, int cchSrc, LPWSTR lpDestStr, int cchDest);

#ifdef UNICODE
#define CompareString CompareStringW
#define FoldString FoldStringW
#endif

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI GetStringTypeExW (LCID Locale, DWORD dwInfoType, LPCWCH lpSrcStr, int cchSrc, LPWORD lpCharType);
#if WINVER >= 0x0600
  WINBASEAPI int WINAPI CompareStringEx (LPCWSTR lpLocaleName, DWORD dwCmpFlags, LPCWCH lpString1, int cchCount1, LPCWCH lpString2, int cchCount2, LPNLSVERSIONINFO lpVersionInformation, LPVOID lpReserved, LPARAM lParam);
  WINBASEAPI int WINAPI CompareStringOrdinal (LPCWCH lpString1, int cchCount1, LPCWCH lpString2, int cchCount2, WINBOOL bIgnoreCase);
#endif

#ifdef UNICODE
#define GetStringTypeEx GetStringTypeExW
#endif

  WINBASEAPI WINBOOL WINAPI GetStringTypeW (DWORD dwInfoType, LPCWCH lpSrcStr, int cchSrc, LPWORD lpCharType);
  WINBASEAPI int WINAPI MultiByteToWideChar (UINT CodePage, DWORD dwFlags, LPCCH lpMultiByteStr, int cbMultiByte, LPWSTR lpWideCharStr, int cchWideChar);
  WINBASEAPI int WINAPI WideCharToMultiByte (UINT CodePage, DWORD dwFlags, LPCWCH lpWideCharStr, int cchWideChar, LPSTR lpMultiByteStr, int cbMultiByte, LPCCH lpDefaultChar, LPBOOL lpUsedDefaultChar);
#endif

#ifdef __cplusplus
}
#endif

#endif
