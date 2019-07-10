/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifdef _CERTBCLI_TYPECHECK
#undef __CERTBCLI_H__
#endif

#ifndef __CERTBCLI_H__
#define __CERTBCLI_H__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _NO_W32_PSEUDO_MODIFIERS
#ifndef IN
#define IN
#endif
#ifndef OUT
#define OUT
#endif
#ifndef OPTIONAL
#define OPTIONAL
#endif
#endif

#ifndef RPC_STRING
#define RPC_STRING
#endif
#ifndef VOID
#define VOID void
#endif

#define CERTBCLI_CALL WINAPI
#define CERTBCLI_API __declspec(dllimport) WINAPI

#define szBACKUPANNOTATION "Cert Server Backup Interface"
#define wszBACKUPANNOTATION TEXT(szBACKUPANNOTATION)

#define szRESTOREANNOTATION "Cert Server Restore Interface"
#define wszRESTOREANNOTATION TEXT(szRESTOREANNOTATION)

#define CSBACKUP_TYPE_FULL 0x00000001
#define CSBACKUP_TYPE_LOGS_ONLY 0x00000002

#define CSBACKUP_TYPE_MASK 0x00000003

#define CSRESTORE_TYPE_FULL 0x00000001
#define CSRESTORE_TYPE_ONLINE 0x00000002
#define CSRESTORE_TYPE_CATCHUP 0x00000004
#define CSRESTORE_TYPE_MASK 0x00000005

#define CSBACKUP_DISABLE_INCREMENTAL 0xffffffff

  typedef WCHAR CSBFT;

#define CSBFT_DIRECTORY 0x80
#define CSBFT_DATABASE_DIRECTORY 0x40
#define CSBFT_LOG_DIRECTORY 0x20

#define CSBFT_LOG ((CSBFT) (TEXT('\x01') | CSBFT_LOG_DIRECTORY))
#define CSBFT_LOG_DIR ((CSBFT) (TEXT('\x02') | CSBFT_DIRECTORY))
#define CSBFT_CHECKPOINT_DIR ((CSBFT) (TEXT('\x03') | CSBFT_DIRECTORY))
#define CSBFT_CERTSERVER_DATABASE ((CSBFT) (TEXT('\x04') | CSBFT_DATABASE_DIRECTORY))
#define CSBFT_PATCH_FILE ((CSBFT) (TEXT('\x05') | CSBFT_LOG_DIRECTORY))
#define CSBFT_UNKNOWN ((CSBFT) (TEXT('\x0f')))

  typedef void *HCSBC;

#ifndef CSEDB_RSTMAP
  typedef struct tagCSEDB_RSTMAPW {
    WCHAR *pwszDatabaseName;
    WCHAR *pwszNewDatabaseName;
  } CSEDB_RSTMAPW;

#define CSEDB_RSTMAP CSEDB_RSTMAPW
#endif

#define CertSrvIsServerOnline CertSrvIsServerOnlineW
#define CertSrvBackupGetDynamicFileList CertSrvBackupGetDynamicFileListW
#define CertSrvBackupPrepare CertSrvBackupPrepareW
#define CertSrvBackupGetDatabaseNames CertSrvBackupGetDatabaseNamesW
#define CertSrvBackupOpenFile CertSrvBackupOpenFileW
#define CertSrvBackupGetBackupLogs CertSrvBackupGetBackupLogsW

#define CertSrvRestoreGetDatabaseLocations CertSrvRestoreGetDatabaseLocationsW
#define CertSrvRestorePrepare CertSrvRestorePrepareW
#define CertSrvRestoreRegister CertSrvRestoreRegisterW

#define CertSrvServerControl CertSrvServerControlW

  typedef HRESULT (WINAPI FNCERTSRVISSERVERONLINEW)(WCHAR const *pwszServerName,WINBOOL *pfServerOnline);

  HRESULT CERTBCLI_API CertSrvIsServerOnlineW(WCHAR const *pwszServerName,WINBOOL *pfServerOnline);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVISSERVERONLINEW *pfnCertSrvIsServerOnline = CertSrvIsServerOnline;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPGETDYNAMICFILELISTW)(HCSBC hbc,WCHAR **ppwszzFileList,DWORD *pcbSize);

  HRESULT CERTBCLI_API CertSrvBackupGetDynamicFileListW(HCSBC hbc,WCHAR **ppwszzFileList,DWORD *pcbSize);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPGETDYNAMICFILELISTW *pfnCertSrvBackupGetDynamicFileList = CertSrvBackupGetDynamicFileList;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPPREPAREW)(WCHAR const *pwszServerName,ULONG grbitJet,ULONG dwBackupFlags,HCSBC *phbc);

  HRESULT CERTBCLI_API CertSrvBackupPrepareW(WCHAR const *pwszServerName,ULONG grbitJet,ULONG dwBackupFlags,HCSBC *phbc);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPPREPAREW *pfnCertSrvBackupPrepare = CertSrvBackupPrepare;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPGETDATABASENAMESW)(HCSBC hbc,WCHAR **ppwszzAttachmentInformation,DWORD *pcbSize);

  HRESULT CERTBCLI_API CertSrvBackupGetDatabaseNamesW(HCSBC hbc,WCHAR **ppwszzAttachmentInformation,DWORD *pcbSize);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPGETDATABASENAMESW *pfnCertSrvBackupGetDatabaseNames = CertSrvBackupGetDatabaseNames;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPOPENFILEW)(HCSBC hbc,WCHAR const *pwszAttachmentName,DWORD cbReadHintSize,LARGE_INTEGER *pliFileSize);

  HRESULT CERTBCLI_API CertSrvBackupOpenFileW(HCSBC hbc,WCHAR const *pwszAttachmentName,DWORD cbReadHintSize,LARGE_INTEGER *pliFileSize);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPOPENFILEW *pfnCertSrvBackupOpenFile = CertSrvBackupOpenFile;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPREAD)(HCSBC hbc,VOID *pvBuffer,DWORD cbBuffer,DWORD *pcbRead);

  HRESULT CERTBCLI_API CertSrvBackupRead(HCSBC hbc,VOID *pvBuffer,DWORD cbBuffer,DWORD *pcbRead);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPREAD *pfnCertSrvBackupRead = CertSrvBackupRead;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPCLOSE)(HCSBC hbc);

  HRESULT CERTBCLI_API CertSrvBackupClose(HCSBC hbc);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPCLOSE *pfnCertSrvBackupClose = CertSrvBackupClose;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPGETBACKUPLOGSW)(HCSBC hbc,WCHAR **ppwszzBackupLogFiles,DWORD *pcbSize);

  HRESULT CERTBCLI_API CertSrvBackupGetBackupLogsW(HCSBC hbc,WCHAR **ppwszzBackupLogFiles,DWORD *pcbSize);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPGETBACKUPLOGSW *pfnCertSrvBackupGetBackupLogs = CertSrvBackupGetBackupLogs;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPTRUNCATELOGS)(HCSBC hbc);

  HRESULT CERTBCLI_API CertSrvBackupTruncateLogs(HCSBC hbc);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPTRUNCATELOGS *pfnCertSrvBackupTruncateLogs = CertSrvBackupTruncateLogs;
#endif

  typedef HRESULT (WINAPI FNCERTSRVBACKUPEND)(HCSBC hbc);

  HRESULT CERTBCLI_API CertSrvBackupEnd(HCSBC hbc);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPEND *pfnCertSrvBackupEnd = CertSrvBackupEnd;
#endif

  typedef VOID (WINAPI FNCERTSRVBACKUPFREE)(VOID *pv);

  VOID CERTBCLI_API CertSrvBackupFree(VOID *pv);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVBACKUPFREE *pfnCertSrvBackupFree = CertSrvBackupFree;
#endif

  typedef HRESULT (WINAPI FNCERTSRVRESTOREGETDATABASELOCATIONSW)(HCSBC hbc,WCHAR **ppwszzDatabaseLocationList,DWORD *pcbSize);

  HRESULT CERTBCLI_API CertSrvRestoreGetDatabaseLocationsW(HCSBC hbc,WCHAR **ppwszzDatabaseLocationList,DWORD *pcbSize);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVRESTOREGETDATABASELOCATIONSW *pfnCertSrvRestoreGetDatabaseLocations = CertSrvRestoreGetDatabaseLocations;
#endif

  typedef HRESULT (WINAPI FNCERTSRVRESTOREPREPAREW)(WCHAR const *pwszServerName,ULONG dwRestoreFlags,HCSBC *phbc);

  HRESULT CERTBCLI_API CertSrvRestorePrepareW(WCHAR const *pwszServerName,ULONG dwRestoreFlags,HCSBC *phbc);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVRESTOREPREPAREW *pfnCertSrvRestorePrepare = CertSrvRestorePrepare;
#endif

  typedef HRESULT (WINAPI FNCERTSRVRESTOREREGISTERW)(HCSBC hbc,WCHAR const *pwszCheckPointFilePath,WCHAR const *pwszLogPath,CSEDB_RSTMAPW rgrstmap[],LONG crstmap,WCHAR const *pwszBackupLogPath,ULONG genLow,ULONG genHigh);

  HRESULT CERTBCLI_API CertSrvRestoreRegisterW(HCSBC hbc,WCHAR const *pwszCheckPointFilePath,WCHAR const *pwszLogPath,CSEDB_RSTMAPW rgrstmap[],LONG crstmap,WCHAR const *pwszBackupLogPath,ULONG genLow,ULONG genHigh);
  HRESULT CERTBCLI_API CertSrvRestoreRegisterThroughFile(HCSBC hbc,WCHAR const *pwszCheckPointFilePath,WCHAR const *pwszLogPath,CSEDB_RSTMAPW rgrstmap[],LONG crstmap,WCHAR const *pwszBackupLogPath,ULONG genLow,ULONG genHigh);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVRESTOREREGISTERW *pfnCertSrvRestoreRegister = CertSrvRestoreRegister;
#endif

  typedef HRESULT (WINAPI FNCERTSRVRESTOREREGISTERCOMPLETE)(HCSBC hbc,HRESULT hrRestoreState);

  HRESULT CERTBCLI_API CertSrvRestoreRegisterComplete(HCSBC hbc,HRESULT hrRestoreState);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVRESTOREREGISTERCOMPLETE *pfnCertSrvRestoreRegisterComplete = CertSrvRestoreRegisterComplete;
#endif

  typedef HRESULT (WINAPI FNCERTSRVRESTOREEND)(HCSBC hbc);

  HRESULT CERTBCLI_API CertSrvRestoreEnd(HCSBC hbc);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVRESTOREEND *pfnCertSrvRestoreEnd = CertSrvRestoreEnd;
#endif

#define CSCONTROL_SHUTDOWN 0x000000001
#define CSCONTROL_SUSPEND 0x000000002
#define CSCONTROL_RESTART 0x000000003

  typedef HRESULT (WINAPI FNCERTSRVSERVERCONTROLW)(WCHAR const *pwszServerName,DWORD dwControlFlags,DWORD *pcbOut,BYTE **ppbOut);

  HRESULT CERTBCLI_API CertSrvServerControlW(WCHAR const *pwszServerName,DWORD dwControlFlags,DWORD *pcbOut,BYTE **ppbOut);

#ifdef _CERTBCLI_TYPECHECK
  FNCERTSRVSERVERCONTROLW *pfnCertSrvServerControl = CertSrvServerControl;
#endif

#ifdef __cplusplus
}
#endif
#endif
