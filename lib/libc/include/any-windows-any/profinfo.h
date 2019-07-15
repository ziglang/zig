/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_PROFINFO
#define _INC_PROFINFO

#include <_mingw_unicode.h>

typedef struct _PROFILEINFOA {
  DWORD dwSize;
  DWORD dwFlags;
  LPSTR lpUserName;
  LPSTR lpProfilePath;
  LPSTR lpDefaultPath;
  LPSTR lpServerName;
  LPSTR lpPolicyPath;
  HANDLE hProfile;
} PROFILEINFOA,*LPPROFILEINFOA;

typedef struct _PROFILEINFOW {
  DWORD dwSize;
  DWORD dwFlags;
  LPWSTR lpUserName;
  LPWSTR lpProfilePath;
  LPWSTR lpDefaultPath;
  LPWSTR lpServerName;
  LPWSTR lpPolicyPath;
  HANDLE hProfile;
} PROFILEINFOW,*LPPROFILEINFOW;

__MINGW_TYPEDEF_AW(PROFILEINFO)
__MINGW_TYPEDEF_AW(LPPROFILEINFO)

#define MIDL_STRING

#endif
