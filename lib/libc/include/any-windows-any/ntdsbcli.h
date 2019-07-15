/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _NTDSBCLI_H_
#define _NTDSBCLI_H_

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#define xRPC_STRING

#ifndef __WCHAR_DEFINED
#define __WCHAR_DEFINED
  typedef unsigned short WCHAR;
#endif

#ifndef _NTDSBCLI_DEFINED
#define NTDSBCLI_API __declspec(dllimport) _stdcall
#else
#define NTDSBCLI_API
#endif

#ifndef _HRESULT_DEFINED
#define _HRESULT_DEFINED
  typedef LONG HRESULT;
#endif

#define g_wszBackupAnnotation L"NTDS Backup Interface"
#define g_aszBackupAnnotation "NTDS Backup Interface"

#define g_wszRestoreAnnotation L"NTDS Restore Interface"
#define g_aszRestoreAnnotation "NTDS Restore Interface"

#if defined(UNICODE)
#define g_szBackupAnnotation g_wszBackupAnnotation
#define g_szRestoreAnnotation g_wszRestoreAnnotation
#else
#define g_szBackupAnnotation g_aszBackupAnnotation
#define g_szRestoreAnnotation g_aszRestoreAnnotation
#endif

#define BACKUP_TYPE_FULL 0x01
#define BACKUP_TYPE_LOGS_ONLY 0x02
#define BACKUP_TYPE_INCREMENTAL 0x04

#define RESTORE_TYPE_AUTHORATATIVE 0x01
#define RESTORE_TYPE_ONLINE 0x02
#define RESTORE_TYPE_CATCHUP 0x04

#define BACKUP_DISABLE_INCREMENTAL 0xffffffff

#if defined(UNICODE)
  typedef WCHAR BFT;
#else
  typedef CHAR BFT;
#endif

#define BFT_DIRECTORY 0x80
#define BFT_DATABASE_DIRECTORY 0x40
#define BFT_LOG_DIRECTORY 0x20

#define BFT_LOG (BFT)(TEXT('\x01') | BFT_LOG_DIRECTORY)
#define BFT_LOG_DIR (BFT)(TEXT('\x02') | BFT_DIRECTORY)
#define BFT_CHECKPOINT_DIR (BFT)(TEXT('\x03') | BFT_DIRECTORY)
#define BFT_NTDS_DATABASE (BFT)(TEXT('\x04') | BFT_DATABASE_DIRECTORY)
#define BFT_PATCH_FILE (BFT)(TEXT('\x05') | BFT_LOG_DIRECTORY)
#define BFT_UNKNOWN (BFT)(TEXT('\x0f'))

#include <ntdsbmsg.h>

  typedef void *HBC;

  typedef struct tagEDB_RSTMAPA {
    char *szDatabaseName;
    char *szNewDatabaseName;
  } EDB_RSTMAPA,*PEDB_RSTMAPA;

#define UNICODE_RSTMAP

  typedef struct tagEDB_RSTMAPW {
    WCHAR *wszDatabaseName;
    WCHAR *wszNewDatabaseName;
  } EDB_RSTMAPW,*PEDB_RSTMAPW;

#define EDB_RSTMAP __MINGW_NAME_AW(EDB_RSTMAP)
#define PEDB_RSTMAP __MINGW_NAME_AW(PEDB_RSTMAP)

#define DsIsNTDSOnline __MINGW_NAME_AW(DsIsNTDSOnline)
#define DsBackupPrepare __MINGW_NAME_AW(DsBackupPrepare)
#define DsBackupGetDatabaseNames __MINGW_NAME_AW(DsBackupGetDatabaseNames)
#define DsBackupOpenFile __MINGW_NAME_AW(DsBackupOpenFile)
#define DsBackupGetBackupLogs __MINGW_NAME_AW(DsBackupGetBackupLogs)
#define DsRestoreGetDatabaseLocations __MINGW_NAME_AW(DsRestoreGetDatabaseLocations)
#define DsRestorePrepare __MINGW_NAME_AW(DsRestorePrepare)
#define DsRestoreRegister __MINGW_NAME_AW(DsRestoreRegister)
#define DsSetCurrentBackupLog __MINGW_NAME_AW(DsSetCurrentBackupLog)
#define DsSetAuthIdentity __MINGW_NAME_AW(DsSetAuthIdentity)

  HRESULT NTDSBCLI_API DsIsNTDSOnlineA(LPCSTR szServerName,WINBOOL *pfNTDSOnline);
  HRESULT NTDSBCLI_API DsIsNTDSOnlineW(LPCWSTR szServerName,WINBOOL *pfNTDSOnline);
  HRESULT NTDSBCLI_API DsBackupPrepareA(LPCSTR szBackupServer,ULONG grbit,ULONG btFlag,PVOID *ppvExpiryToken,LPDWORD pcbExpiryTokenSize,HBC *phbc);
  HRESULT NTDSBCLI_API DsBackupPrepareW(LPCWSTR szBackupServer,ULONG grbit,ULONG btFlag,PVOID *ppvExpiryToken,LPDWORD pcbExpiryTokenSize,HBC *phbc);
  HRESULT NTDSBCLI_API DsBackupGetDatabaseNamesA(HBC hbc,LPSTR *pszAttachmentInfo,LPDWORD pcbSize);
  HRESULT NTDSBCLI_API DsBackupGetDatabaseNamesW(HBC hbc,LPWSTR *pszAttachmentInfo,LPDWORD pcbSize);
  HRESULT NTDSBCLI_API DsBackupOpenFileA(HBC hbc,LPCSTR szAttachmentName,DWORD cbReadHintSize,LARGE_INTEGER *pliFileSize);
  HRESULT NTDSBCLI_API DsBackupOpenFileW(HBC hbc,LPCWSTR szAttachmentName,DWORD cbReadHintSize,LARGE_INTEGER *pliFileSize);
  HRESULT NTDSBCLI_API DsBackupRead(HBC hbc,PVOID pvBuffer,DWORD cbBuffer,PDWORD pcbRead);
  HRESULT NTDSBCLI_API DsBackupClose(HBC hbc);
  HRESULT NTDSBCLI_API DsBackupGetBackupLogsA(HBC hbc,LPSTR *pszBackupLogFiles,LPDWORD pcbSize);
  HRESULT NTDSBCLI_API DsBackupGetBackupLogsW(HBC hbc,LPWSTR *pszBackupLogFiles,LPDWORD pcbSize);
  HRESULT NTDSBCLI_API DsBackupTruncateLogs(HBC hbc);
  HRESULT NTDSBCLI_API DsBackupEnd(HBC hbc);
  VOID NTDSBCLI_API DsBackupFree(PVOID pvBuffer);
  HRESULT NTDSBCLI_API DsRestoreGetDatabaseLocationsA(HBC hbc,LPSTR *pszDatabaseLocationList,LPDWORD pcbSize);
  HRESULT NTDSBCLI_API DsRestoreGetDatabaseLocationsW(HBC hbc,LPWSTR *pszDatabaseLocationList,LPDWORD pcbSize);
  HRESULT NTDSBCLI_API DsRestorePrepareA(LPCSTR szServerName,ULONG rtFlag,PVOID pvExpiryToken,DWORD cbExpiryTokenSize,HBC *phbc);
  HRESULT NTDSBCLI_API DsRestorePrepareW(LPCWSTR szServerName,ULONG rtFlag,PVOID pvExpiryToken,DWORD cbExpiryTokenSize,HBC *phbc);
  HRESULT NTDSBCLI_API DsRestoreRegisterA(HBC hbc,LPCSTR szCheckPointFilePath,LPCSTR szLogPath,EDB_RSTMAPA rgrstmap[],LONG crstmap,LPCSTR szBackupLogPath,ULONG genLow,ULONG genHigh);
  HRESULT NTDSBCLI_API DsRestoreRegisterW(HBC hbc,LPCWSTR szCheckPointFilePath,LPCWSTR szLogPath,EDB_RSTMAPW rgrstmap[],LONG crstmap,LPCWSTR szBackupLogPath,ULONG genLow,ULONG genHigh);
  HRESULT NTDSBCLI_API DsRestoreRegisterComplete(HBC hbc,HRESULT hrRestoreState);
  HRESULT NTDSBCLI_API DsRestoreEnd(HBC hbc);
  HRESULT NTDSBCLI_API DsSetCurrentBackupLogA(LPCSTR szServerName,DWORD dwCurrentLog);
  HRESULT NTDSBCLI_API DsSetCurrentBackupLogW(LPCWSTR szServerName,DWORD dwCurrentLog);
  HRESULT NTDSBCLI_API DsSetAuthIdentityA(LPCSTR szUserName,LPCSTR szDomainName,LPCSTR szPassword);
  HRESULT NTDSBCLI_API DsSetAuthIdentityW(LPCWSTR szUserName,LPCWSTR szDomainName,LPCWSTR szPassword);

#ifdef __cplusplus
}
#endif
#endif
