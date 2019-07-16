/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MAPINLS_H_
#define _MAPINLS_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#ifdef DOS
#include <string.h>
#endif

#ifndef FAR
#define FAR
#endif

  typedef unsigned char BYTE;
  typedef unsigned short WORD;
  typedef unsigned __LONG32 DWORD;
  typedef unsigned int UINT;
  typedef int WINBOOL;

#ifndef __CHAR_DEFINED__
  typedef char CHAR;
#endif

#if defined(UNICODE)
  typedef WCHAR TCHAR;
#else
  typedef char TCHAR;
#endif

#ifndef __WCHAR_DEFINED
#define __WCHAR_DEFINED
  typedef unsigned short WCHAR;
#endif
  typedef WCHAR *LPWSTR;
  typedef const WCHAR *LPCWSTR;
  typedef CHAR *LPSTR;
  typedef const CHAR *LPCSTR;
  typedef TCHAR *LPTSTR;
  typedef const TCHAR *LPCTSTR;
  typedef DWORD LCID;
#ifndef _LPCVOID_DEFINED
#define _LPCVOID_DEFINED
  typedef const void *LPCVOID;
#endif

#ifndef LPOLESTR
#define LPOLESTR LPWSTR
#define LPCOLESTR LPCWSTR
#define OLECHAR WCHAR
#define OLESTR(str) L##str
#endif

#define NORM_IGNORECASE 0x00000001
#define NORM_IGNORENONSPACE 0x00000002
#define NORM_IGNORESYMBOLS 0x00000004
#define NORM_IGNOREKANATYPE 0x00010000
#define NORM_IGNOREWIDTH 0x00020000

#define CP_ACP 0
#define CP_OEMCP 1

  LCID WINAPI MNLS_GetUserDefaultLCID(void);
  UINT WINAPI MNLS_GetACP(void);
  int WINAPI MNLS_CompareStringA(LCID Locale,DWORD dwCmpFlags,LPCSTR lpString1,int cchCount1,LPCSTR lpString2,int cchCount2);
  int WINAPI MNLS_CompareStringW(LCID Locale,DWORD dwCmpFlags,LPCWSTR lpString1,int cchCount1,LPCWSTR lpString2,int cchCount2);
  int WINAPI MNLS_MultiByteToWideChar(UINT uCodePage,DWORD dwFlags,LPCSTR lpMultiByteStr,int cchMultiByte,LPWSTR lpWideCharStr,int cchWideChar);
  int WINAPI MNLS_WideCharToMultiByte(UINT uCodePage,DWORD dwFlags,LPCWSTR lpWideCharStr,int cchWideChar,LPSTR lpMultiByteStr,int cchMultiByte,LPCSTR lpDefaultChar,WINBOOL *lpfUsedDefaultChar);
  int WINAPI MNLS_lstrlenW(LPCWSTR lpString);
  int WINAPI MNLS_lstrcmpW(LPCWSTR lpString1,LPCWSTR lpString2);
  LPWSTR WINAPI MNLS_lstrcpyW(LPWSTR lpString1,LPCWSTR lpString2);
  WINBOOL WINAPI MNLS_IsBadStringPtrW(LPCWSTR lpsz,UINT ucchMax);

#if !defined(_WINNT) && !defined(_WIN95)
#define _WINNT
#endif

#if !defined(_WINNT) && !defined(_WIN95)
#define GetUserDefaultLCID MNLS_GetUserDefaultLCID
#define GetACP MNLS_GetACP
#define MultiByteToWideChar MNLS_MultiByteToWideChar
#define WideCharToMultiByte MNLS_WideCharToMultiByte
#define CompareStringA MNLS_CompareStringA
#endif

#if !defined(MAPI_NOWIDECHAR)

#define lstrlenW MNLS_lstrlenW
#define lstrcmpW MNLS_lstrcmpW
#define lstrcpyW MNLS_lstrcpyW
#define CompareStringW MNLS_CompareStringW

#if defined(_WINNT) || defined(_WIN95)
#define IsBadStringPtrW MNLS_IsBadStringPtrW
#else
#define IsBadStringPtrW (FALSE)
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
