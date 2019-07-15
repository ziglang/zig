/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __ODBCINST_H
#define __ODBCINST_H

#include <sql.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef ODBCVER
#define ODBCVER 0x0351
#endif

#define ODBC_ADD_DSN 1
#define ODBC_CONFIG_DSN 2
#define ODBC_REMOVE_DSN 3

#if (ODBCVER >= 0x0250)
#define ODBC_ADD_SYS_DSN 4
#define ODBC_CONFIG_SYS_DSN 5
#define ODBC_REMOVE_SYS_DSN 6
#if (ODBCVER >= 0x0300)
#define ODBC_REMOVE_DEFAULT_DSN 7
#endif

#define ODBC_INSTALL_INQUIRY 1
#define ODBC_INSTALL_COMPLETE 2

#define ODBC_INSTALL_DRIVER 1
#define ODBC_REMOVE_DRIVER 2
#define ODBC_CONFIG_DRIVER 3
#define ODBC_CONFIG_DRIVER_MAX 100
#endif

#if (ODBCVER >= 0x0300)
#define ODBC_BOTH_DSN 0
#define ODBC_USER_DSN 1
#define ODBC_SYSTEM_DSN 2
#endif

#if (ODBCVER >= 0x0300)
#define ODBC_ERROR_GENERAL_ERR 1
#define ODBC_ERROR_INVALID_BUFF_LEN 2
#define ODBC_ERROR_INVALID_HWND 3
#define ODBC_ERROR_INVALID_STR 4
#define ODBC_ERROR_INVALID_REQUEST_TYPE 5
#define ODBC_ERROR_COMPONENT_NOT_FOUND 6
#define ODBC_ERROR_INVALID_NAME 7
#define ODBC_ERROR_INVALID_KEYWORD_VALUE 8
#define ODBC_ERROR_INVALID_DSN 9
#define ODBC_ERROR_INVALID_INF 10
#define ODBC_ERROR_REQUEST_FAILED 11
#define ODBC_ERROR_INVALID_PATH 12
#define ODBC_ERROR_LOAD_LIB_FAILED 13
#define ODBC_ERROR_INVALID_PARAM_SEQUENCE 14
#define ODBC_ERROR_INVALID_LOG_FILE 15
#define ODBC_ERROR_USER_CANCELED 16
#define ODBC_ERROR_USAGE_UPDATE_FAILED 17
#define ODBC_ERROR_CREATE_DSN_FAILED 18
#define ODBC_ERROR_WRITING_SYSINFO_FAILED 19
#define ODBC_ERROR_REMOVE_DSN_FAILED 20
#define ODBC_ERROR_OUT_OF_MEM 21
#define ODBC_ERROR_OUTPUT_STRING_TRUNCATED 22
#endif

#ifndef EXPORT
#define EXPORT
#endif

#ifndef RC_INVOKED

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#define INSTAPI WINAPI

  WINBOOL WINAPI SQLInstallODBC(HWND hwndParent,LPCSTR lpszInfFile,LPCSTR lpszSrcPath,LPCSTR lpszDrivers);
  WINBOOL WINAPI SQLManageDataSources(HWND hwndParent);
  WINBOOL WINAPI SQLCreateDataSource(HWND hwndParent,LPCSTR lpszDSN);
  WINBOOL WINAPI SQLGetTranslator(HWND hwnd,LPSTR lpszName,WORD cbNameMax,WORD *pcbNameOut,LPSTR lpszPath,WORD cbPathMax,WORD *pcbPathOut,DWORD *pvOption);
  WINBOOL WINAPI SQLInstallDriver(LPCSTR lpszInfFile,LPCSTR lpszDriver,LPSTR lpszPath,WORD cbPathMax,WORD *pcbPathOut);
  WINBOOL WINAPI SQLInstallDriverManager (LPSTR lpszPath,WORD cbPathMax,WORD *pcbPathOut);
  WINBOOL WINAPI SQLGetInstalledDrivers (LPSTR lpszBuf,WORD cbBufMax,WORD *pcbBufOut);
  WINBOOL WINAPI SQLGetAvailableDrivers(LPCSTR lpszInfFile,LPSTR lpszBuf,WORD cbBufMax,WORD *pcbBufOut);
  WINBOOL WINAPI SQLConfigDataSource(HWND hwndParent,WORD fRequest,LPCSTR lpszDriver,LPCSTR lpszAttributes);
  WINBOOL WINAPI SQLRemoveDefaultDataSource(void);
  WINBOOL WINAPI SQLWriteDSNToIni(LPCSTR lpszDSN,LPCSTR lpszDriver);
  WINBOOL WINAPI SQLRemoveDSNFromIni(LPCSTR lpszDSN);
  WINBOOL WINAPI SQLValidDSN(LPCSTR lpszDSN);
  WINBOOL WINAPI SQLWritePrivateProfileString(LPCSTR lpszSection,LPCSTR lpszEntry,LPCSTR lpszString,LPCSTR lpszFilename);
  int WINAPI SQLGetPrivateProfileString(LPCSTR lpszSection,LPCSTR lpszEntry,LPCSTR lpszDefault,LPSTR lpszRetBuffer,int cbRetBuffer,LPCSTR lpszFilename);
#if (ODBCVER >= 0x0250)
  WINBOOL WINAPI SQLRemoveDriverManager(LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLInstallTranslator(LPCSTR lpszInfFile,LPCSTR lpszTranslator,LPCSTR lpszPathIn,LPSTR lpszPathOut,WORD cbPathOutMax,WORD *pcbPathOut,WORD fRequest,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLRemoveTranslator(LPCSTR lpszTranslator,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLRemoveDriver(LPCSTR lpszDriver,WINBOOL fRemoveDSN,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLConfigDriver(HWND hwndParent,WORD fRequest,LPCSTR lpszDriver,LPCSTR lpszArgs,LPSTR lpszMsg,WORD cbMsgMax,WORD *pcbMsgOut);
#endif

#if (ODBCVER >= 0x0300)
  SQLRETURN WINAPI SQLInstallerError(WORD iError,DWORD *pfErrorCode,LPSTR lpszErrorMsg,WORD cbErrorMsgMax,WORD *pcbErrorMsg);
  SQLRETURN WINAPI SQLPostInstallerError(DWORD dwErrorCode,LPCSTR lpszErrMsg);
  WINBOOL WINAPI SQLWriteFileDSN(LPCSTR lpszFileName,LPCSTR lpszAppName,LPCSTR lpszKeyName,LPCSTR lpszString);
  WINBOOL WINAPI SQLReadFileDSN(LPCSTR lpszFileName,LPCSTR lpszAppName,LPCSTR lpszKeyName,LPSTR lpszString,WORD cbString,WORD *pcbString);
  WINBOOL WINAPI SQLInstallDriverEx(LPCSTR lpszDriver,LPCSTR lpszPathIn,LPSTR lpszPathOut,WORD cbPathOutMax,WORD *pcbPathOut,WORD fRequest,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLInstallTranslatorEx(LPCSTR lpszTranslator,LPCSTR lpszPathIn,LPSTR lpszPathOut,WORD cbPathOutMax,WORD *pcbPathOut,WORD fRequest,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLGetConfigMode(UWORD *pwConfigMode);
  WINBOOL WINAPI SQLSetConfigMode(UWORD wConfigMode);
#endif

  WINBOOL WINAPI ConfigDSN(HWND hwndParent,WORD fRequest,LPCSTR lpszDriver,LPCSTR lpszAttributes);
  WINBOOL WINAPI ConfigTranslator(HWND hwndParent,DWORD *pvOption);
#if (ODBCVER >= 0x0250)
  WINBOOL WINAPI ConfigDriver(HWND hwndParent,WORD fRequest,LPCSTR lpszDriver,LPCSTR lpszArgs,LPSTR lpszMsg,WORD cbMsgMax,WORD *pcbMsgOut);
#endif
  WINBOOL WINAPI SQLInstallODBCW(HWND hwndParent,LPCWSTR lpszInfFile,LPCWSTR lpszSrcPath,LPCWSTR lpszDrivers);
  WINBOOL WINAPI SQLCreateDataSourceW(HWND hwndParent,LPCWSTR lpszDSN);
  WINBOOL WINAPI SQLGetTranslatorW(HWND hwnd,LPWSTR lpszName,WORD cbNameMax,WORD *pcbNameOut,LPWSTR lpszPath,WORD cbPathMax,WORD *pcbPathOut,DWORD *pvOption);
  WINBOOL WINAPI SQLInstallDriverW (LPCWSTR lpszInfFile,LPCWSTR lpszDriver,LPWSTR lpszPath,WORD cbPathMax,WORD *pcbPathOut);
  WINBOOL WINAPI SQLInstallDriverManagerW (LPWSTR lpszPath,WORD cbPathMax,WORD *pcbPathOut);
  WINBOOL WINAPI SQLGetInstalledDriversW (LPWSTR lpszBuf,WORD cbBufMax,WORD *pcbBufOut);
  WINBOOL WINAPI SQLGetAvailableDriversW (LPCWSTR lpszInfFile,LPWSTR lpszBuf,WORD cbBufMax,WORD *pcbBufOut);
  WINBOOL WINAPI SQLConfigDataSourceW(HWND hwndParent,WORD fRequest,LPCWSTR lpszDriver,LPCWSTR lpszAttributes);
  WINBOOL WINAPI SQLWriteDSNToIniW (LPCWSTR lpszDSN,LPCWSTR lpszDriver);
  WINBOOL WINAPI SQLRemoveDSNFromIniW (LPCWSTR lpszDSN);
  WINBOOL WINAPI SQLValidDSNW (LPCWSTR lpszDSN);
  WINBOOL WINAPI SQLWritePrivateProfileStringW(LPCWSTR lpszSection,LPCWSTR lpszEntry,LPCWSTR lpszString,LPCWSTR lpszFilename);
  int WINAPI SQLGetPrivateProfileStringW(LPCWSTR lpszSection,LPCWSTR lpszEntry,LPCWSTR lpszDefault,LPWSTR lpszRetBuffer,int cbRetBuffer,LPCWSTR lpszFilename);
#if (ODBCVER >= 0x0250)
  WINBOOL WINAPI SQLInstallTranslatorW(LPCWSTR lpszInfFile,LPCWSTR lpszTranslator,LPCWSTR lpszPathIn,LPWSTR lpszPathOut,WORD cbPathOutMax,WORD *pcbPathOut,WORD fRequest,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLRemoveTranslatorW(LPCWSTR lpszTranslator,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLRemoveDriverW(LPCWSTR lpszDriver,WINBOOL fRemoveDSN,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLConfigDriverW(HWND hwndParent,WORD fRequest,LPCWSTR lpszDriver,LPCWSTR lpszArgs,LPWSTR lpszMsg,WORD cbMsgMax,WORD *pcbMsgOut);
#endif
#if (ODBCVER >= 0x0300)
  SQLRETURN WINAPI SQLInstallerErrorW(WORD iError,DWORD *pfErrorCode,LPWSTR lpszErrorMsg,WORD cbErrorMsgMax,WORD *pcbErrorMsg);
  SQLRETURN WINAPI SQLPostInstallerErrorW(DWORD dwErrorCode,LPCWSTR lpszErrorMsg);
  WINBOOL WINAPI SQLWriteFileDSNW(LPCWSTR lpszFileName,LPCWSTR lpszAppName,LPCWSTR lpszKeyName,LPCWSTR lpszString);
  WINBOOL WINAPI SQLReadFileDSNW(LPCWSTR lpszFileName,LPCWSTR lpszAppName,LPCWSTR lpszKeyName,LPWSTR lpszString,WORD cbString,WORD *pcbString);
  WINBOOL WINAPI SQLInstallDriverExW(LPCWSTR lpszDriver,LPCWSTR lpszPathIn,LPWSTR lpszPathOut,WORD cbPathOutMax,WORD *pcbPathOut,WORD fRequest,LPDWORD lpdwUsageCount);
  WINBOOL WINAPI SQLInstallTranslatorExW(LPCWSTR lpszTranslator,LPCWSTR lpszPathIn,LPWSTR lpszPathOut,WORD cbPathOutMax,WORD *pcbPathOut,WORD fRequest,LPDWORD lpdwUsageCount);
#endif

  WINBOOL WINAPI ConfigDSNW(HWND hwndParent,WORD fRequest,LPCWSTR lpszDriver,LPCWSTR lpszAttributes);

#if (ODBCVER >= 0x0250)
  WINBOOL WINAPI ConfigDriverW(HWND hwndParent,WORD fRequest,LPCWSTR lpszDriver,LPCWSTR lpszArgs,LPWSTR lpszMsg,WORD cbMsgMax,WORD *pcbMsgOut);
#endif

#ifndef SQL_NOUNICODEMAP

#if defined(UNICODE)
#define SQLInstallODBC SQLInstallODBCW
#define SQLCreateDataSource SQLCreateDataSourceW
#define SQLGetTranslator SQLGetTranslatorW
#define SQLInstallDriver SQLInstallDriverW
#define SQLInstallDriverManager SQLInstallDriverManagerW
#define SQLGetInstalledDrivers SQLGetInstalledDriversW
#define SQLGetAvailableDrivers SQLGetAvailableDriversW
#define SQLConfigDataSource SQLConfigDataSourceW
#define SQLWriteDSNToIni SQLWriteDSNToIniW
#define SQLRemoveDSNFromIni SQLRemoveDSNFromIniW
#define SQLValidDSN SQLValidDSNW
#define SQLWritePrivateProfileString SQLWritePrivateProfileStringW
#define SQLGetPrivateProfileString SQLGetPrivateProfileStringW
#define SQLInstallTranslator SQLInstallTranslatorW
#define SQLRemoveTranslator SQLRemoveTranslatorW
#define SQLRemoveDriver SQLRemoveDriverW
#define SQLConfigDriver SQLConfigDriverW
#define SQLInstallerError SQLInstallerErrorW
#define SQLPostInstallerError SQLPostInstallerErrorW
#define SQLReadFileDSN SQLReadFileDSNW
#define SQLWriteFileDSN SQLWriteFileDSNW
#define SQLInstallDriverEx SQLInstallDriverExW
#define SQLInstallTranslatorEx SQLInstallTranslatorExW
#endif

#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
