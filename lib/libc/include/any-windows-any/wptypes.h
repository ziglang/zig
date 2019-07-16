/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __WPTYPES_H__
#define __WPTYPES_H__

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef struct tagWPSITEINFOA {
    DWORD dwSize;
    DWORD dwFlags;
    LPSTR lpszSiteName;
    LPSTR lpszSiteURL;
  } WPSITEINFOA,*LPWPSITEINFOA;

  typedef struct tagWPSITEINFOW {
    DWORD dwSize;
    DWORD dwFlags;
    LPWSTR lpszSiteName;
    LPWSTR lpszSiteURL;
  } WPSITEINFOW,*LPWPSITEINFOW;

  typedef struct tagWPPROVINFOA {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwPriority;
    LPSTR lpszProviderName;
    LPSTR lpszProviderCLSID;
    LPSTR lpszDllPath;
  } WPPROVINFOA,*LPWPPROVINFOA;

  typedef struct tagWPPROVINFOW {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwPriority;
    LPWSTR lpszProviderName;
    LPWSTR lpszProviderCLSID;
    LPWSTR lpszDllPath;
  } WPPROVINFOW,*LPWPPROVINFOW;

#define WPSITEINFO __MINGW_NAME_AW(WPSITEINFO)
#define LPWPSITEINFO __MINGW_NAME_AW(LPWPSITEINFO)
#define WPPROVINFO __MINGW_NAME_AW(WPPROVINFO)
#define LPWPPROVINFO __MINGW_NAME_AW(LPWPPROVINFO)

#ifdef __cplusplus
}
#endif
#endif
