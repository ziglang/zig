/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _PROCESSENV_
#define _PROCESSENV_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI SetEnvironmentStringsW (LPWCH NewEnvironment);

#ifdef UNICODE
#define SetEnvironmentStrings SetEnvironmentStringsW
#endif

  WINBASEAPI LPSTR WINAPI GetCommandLineA (VOID);
  WINBASEAPI LPWSTR WINAPI GetCommandLineW (VOID);
  WINBASEAPI WINBOOL WINAPI SetCurrentDirectoryA (LPCSTR lpPathName);
  WINBASEAPI WINBOOL WINAPI SetCurrentDirectoryW (LPCWSTR lpPathName);
  WINBASEAPI DWORD WINAPI GetCurrentDirectoryA (DWORD nBufferLength, LPSTR lpBuffer);
  WINBASEAPI DWORD WINAPI GetCurrentDirectoryW (DWORD nBufferLength, LPWSTR lpBuffer);
  WINBASEAPI DWORD WINAPI SearchPathW (LPCWSTR lpPath, LPCWSTR lpFileName, LPCWSTR lpExtension, DWORD nBufferLength, LPWSTR lpBuffer, LPWSTR *lpFilePart);
  WINBASEAPI DWORD APIENTRY SearchPathA (LPCSTR lpPath, LPCSTR lpFileName, LPCSTR lpExtension, DWORD nBufferLength, LPSTR lpBuffer, LPSTR *lpFilePart);
  WINBASEAPI WINBOOL WINAPI NeedCurrentDirectoryForExePathA (LPCSTR ExeName);
  WINBASEAPI WINBOOL WINAPI NeedCurrentDirectoryForExePathW (LPCWSTR ExeName);

#define GetCommandLine __MINGW_NAME_AW(GetCommandLine)
#define GetCurrentDirectory __MINGW_NAME_AW(GetCurrentDirectory)
#define NeedCurrentDirectoryForExePath __MINGW_NAME_AW(NeedCurrentDirectoryForExePath)
#define SearchPath __MINGW_NAME_AW(SearchPath)
#define SetCurrentDirectory __MINGW_NAME_AW(SetCurrentDirectory)

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10

  WINBASEAPI LPCH WINAPI GetEnvironmentStrings (VOID);
  WINBASEAPI LPWCH WINAPI GetEnvironmentStringsW (VOID);

#ifdef UNICODE
#define GetEnvironmentStrings GetEnvironmentStringsW
#else
#define GetEnvironmentStringsA GetEnvironmentStrings
#endif

  WINBASEAPI HANDLE WINAPI GetStdHandle (DWORD nStdHandle);
  WINBASEAPI DWORD WINAPI ExpandEnvironmentStringsA (LPCSTR lpSrc, LPSTR lpDst, DWORD nSize);
  WINBASEAPI DWORD WINAPI ExpandEnvironmentStringsW (LPCWSTR lpSrc, LPWSTR lpDst, DWORD nSize);
  WINBASEAPI WINBOOL WINAPI FreeEnvironmentStringsA (LPCH penv);
  WINBASEAPI WINBOOL WINAPI FreeEnvironmentStringsW (LPWCH penv);
  WINBASEAPI DWORD WINAPI GetEnvironmentVariableA (LPCSTR lpName, LPSTR lpBuffer, DWORD nSize);
  WINBASEAPI DWORD WINAPI GetEnvironmentVariableW (LPCWSTR lpName, LPWSTR lpBuffer, DWORD nSize);
  WINBASEAPI WINBOOL WINAPI SetEnvironmentVariableA (LPCSTR lpName, LPCSTR lpValue);
  WINBASEAPI WINBOOL WINAPI SetEnvironmentVariableW (LPCWSTR lpName, LPCWSTR lpValue);
  WINBASEAPI WINBOOL WINAPI SetStdHandle (DWORD nStdHandle, HANDLE hHandle);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI SetStdHandleEx (DWORD nStdHandle, HANDLE hHandle, PHANDLE phPrevValue);
#endif

#define ExpandEnvironmentStrings __MINGW_NAME_AW(ExpandEnvironmentStrings)
#define FreeEnvironmentStrings __MINGW_NAME_AW(FreeEnvironmentStrings)
#define GetEnvironmentVariable __MINGW_NAME_AW(GetEnvironmentVariable)
#define SetEnvironmentVariable __MINGW_NAME_AW(SetEnvironmentVariable)

#endif

#ifdef __cplusplus
}
#endif
#endif
