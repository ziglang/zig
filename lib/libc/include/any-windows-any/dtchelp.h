/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __DTCHELP_H__
#define __DTCHELP_H__

#include <_mingw_unicode.h>
#include <windows.h>

#ifndef DEFINED_DTC_STATUS
#define DEFINED_DTC_STATUS

typedef enum DTC_STATUS_ {
  DTC_STATUS_UNKNOWN = 0,DTC_STATUS_STARTING = 1,DTC_STATUS_STARTED = 2,DTC_STATUS_PAUSING = 3,DTC_STATUS_PAUSED = 4,DTC_STATUS_CONTINUING = 5,
  DTC_STATUS_STOPPING = 6,DTC_STATUS_STOPPED = 7,DTC_STATUS_E_CANTCONTROL = 8,DTC_STATUS_FAILED = 9
} DTC_STATUS;
#endif

typedef HRESULT (__cdecl *DTC_GET_TRANSACTION_MANAGER)(char *pszHost,char *pszTmName,REFIID rid,DWORD dwReserved1,WORD wcbReserved2,void *pvReserved2,void **ppvObject);
typedef HRESULT (__cdecl *DTC_GET_TRANSACTION_MANAGER_EX_A)(char *i_pszHost,char *i_pszTmName,REFIID i_riid,DWORD i_grfOptions,void *i_pvConfigParams,void **o_ppvObject);
typedef HRESULT (__cdecl *DTC_GET_TRANSACTION_MANAGER_EX_W)(WCHAR *i_pwszHost,WCHAR *i_pwszTmName,REFIID i_riid,DWORD i_grfOptions,void *i_pvConfigParams,void **o_ppvObject);
typedef HRESULT (*DTC_INSTALL_CLIENT)(LPTSTR i_pszRemoteTmHostName,DWORD i_dwProtocol,DWORD i_dwOverwrite);

#define DTC_GET_TRANSACTION_MANAGER_EX __MINGW_NAME_UAW(DTC_GET_TRANSACTION_MANAGER_EX)
#define LoadDtcHelperEx __MINGW_NAME_AW(LoadDtcHelperEx)
#define GetDTCStatus __MINGW_NAME_AW(GetDTCStatus)
#define StartDTC __MINGW_NAME_AW(StartDTC)
#define StopDTC __MINGW_NAME_AW(StopDTC)

#define DTCINSTALL_E_CLIENT_ALREADY_INSTALLED __MSABI_LONG(0x0000180)
#define DTCINSTALL_E_SERVER_ALREADY_INSTALLED __MSABI_LONG(0x0000181)

const DWORD DTC_INSTALL_OVERWRITE_CLIENT = 0x00000001;
const DWORD DTC_INSTALL_OVERWRITE_SERVER = 0x00000002;

#ifdef __cplusplus
extern "C" {
#endif
  DTC_GET_TRANSACTION_MANAGER __cdecl LoadDtcHelper(void);
  DTC_GET_TRANSACTION_MANAGER_EX_A __cdecl LoadDtcHelperExA(void);
  DTC_GET_TRANSACTION_MANAGER_EX_W __cdecl LoadDtcHelperExW(void);
  void __cdecl FreeDtcHelper(void);
  HMODULE __cdecl GetDtcLocaleResourceHandle(void);
  HRESULT __cdecl Initialize(void);
  HRESULT __cdecl Uninitialize(void);
  DTC_STATUS __cdecl GetDTCStatusW(WCHAR *wszHostName);
  DTC_STATUS __cdecl GetDTCStatusA(LPSTR szHostName);
  HRESULT __cdecl StartDTCW(WCHAR *wszHostName);
  HRESULT __cdecl StartDTCA(LPSTR szHostName);
  HRESULT __cdecl StopDTCW(WCHAR *wszHostName);
  HRESULT __cdecl StopDTCA(LPSTR szHostName);
  HRESULT __cdecl DtcInstallClient(LPTSTR i_pszRemoteTmHostName,DWORD i_dwProtocol,DWORD i_dwOverwrite);
#ifdef __cplusplus
}
#endif

#endif
