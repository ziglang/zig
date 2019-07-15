/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _SFC_
#define _SFC_

#ifdef __cplusplus
extern "C" {
#endif

#define SFC_DISABLE_NORMAL 0
#define SFC_DISABLE_ASK 1
#define SFC_DISABLE_ONCE 2
#define SFC_DISABLE_SETUP 3
#define SFC_DISABLE_NOPOPUPS 4

#define SFC_SCAN_NORMAL 0
#define SFC_SCAN_ALWAYS 1
#define SFC_SCAN_ONCE 2
#define SFC_SCAN_IMMEDIATE 3

#define SFC_QUOTA_DEFAULT 50
#define SFC_QUOTA_ALL_FILES ((ULONG)-1)

#define SFC_IDLE_TRIGGER L"WFP_IDLE_TRIGGER"

  typedef struct _PROTECTED_FILE_DATA {
    WCHAR FileName[MAX_PATH];
    DWORD FileNumber;
  } PROTECTED_FILE_DATA,*PPROTECTED_FILE_DATA;

  WINBOOL WINAPI SfcGetNextProtectedFile(HANDLE RpcHandle,PPROTECTED_FILE_DATA ProtFileData);
  WINBOOL WINAPI SfcIsFileProtected(HANDLE RpcHandle,LPCWSTR ProtFileName);
  WINBOOL WINAPI SfpVerifyFile(LPCSTR pszFileName,LPSTR pszError,DWORD dwErrSize);

#if (_WIN32_WINNT >= 0x0600)
WINBOOL WINAPI SfcIsKeyProtected(
  HKEY hKey,
  LPCWSTR lpSubKey,
  REGSAM samDesired
);
#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif
#endif
