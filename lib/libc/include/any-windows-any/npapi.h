/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _NPAPI_INCLUDED
#define _NPAPI_INCLUDED

#include <_mingw_unicode.h>

typedef DWORD (WINAPI *PF_NPAddConnection)(LPNETRESOURCEW lpNetResource,LPWSTR lpPassword,LPWSTR lpUserName);
typedef DWORD (WINAPI *PF_NPAddConnection3)(HWND hwndOwner,LPNETRESOURCEW lpNetResource,LPWSTR lpPassword,LPWSTR lpUserName,DWORD dwFlags);
typedef DWORD (WINAPI *PF_NPCancelConnection)(LPWSTR lpName,WINBOOL fForce);
typedef DWORD (WINAPI *PF_NPGetConnection)(LPWSTR lpLocalName,LPWSTR lpRemoteName,LPDWORD lpnBufferLen);

#define WNGETCON_CONNECTED 0x00000000
#define WNGETCON_DISCONNECTED 0x00000001

typedef DWORD (WINAPI *PF_NPGetConnection3)(LPCWSTR lpLocalName,DWORD dwLevel,LPVOID lpBuffer,LPDWORD lpBufferSize);
typedef DWORD (WINAPI *PF_NPGetConnectionPerformance)(LPCWSTR lpRemoteName,LPNETCONNECTINFOSTRUCT lpNetConnectInfo);
typedef DWORD (WINAPI *PF_NPGetUniversalName)(LPWSTR lpLocalPath,DWORD dwInfoLevel,LPVOID lpBuffer,LPDWORD lpnBufferSize);
typedef DWORD (WINAPI *PF_NPOpenEnum)(DWORD dwScope,DWORD dwType,DWORD dwUsage,LPNETRESOURCEW lpNetResource,LPHANDLE lphEnum);
typedef DWORD (WINAPI *PF_NPEnumResource)(HANDLE hEnum,LPDWORD lpcCount,LPVOID lpBuffer,LPDWORD lpBufferSize);

DWORD WINAPI NPAddConnection(LPNETRESOURCEW lpNetResource,LPWSTR lpPassword,LPWSTR lpUserName);
DWORD WINAPI NPAddConnection3(HWND hwndOwner,LPNETRESOURCEW lpNetResource,LPTSTR lpPassword,LPTSTR lpUserName,DWORD dwFlags);
DWORD WINAPI NPCancelConnection(LPWSTR lpName,WINBOOL fForce);
DWORD WINAPI NPGetConnection(LPWSTR lpLocalName,LPWSTR lpRemoteName,LPDWORD lpnBufferLen);
DWORD WINAPI NPGetConnection3(LPCWSTR lpLocalName,DWORD dwLevel,LPVOID lpBuffer,LPDWORD lpBufferSize);
DWORD WINAPI NPGetConnectionPerformance(LPCWSTR lpRemoteName,LPNETCONNECTINFOSTRUCT lpNetConnectInfo);
DWORD WINAPI NPGetUniversalName(LPWSTR lpLocalPath,DWORD dwInfoLevel,LPVOID lpBuffer,LPDWORD lpBufferSize);
DWORD WINAPI NPOpenEnum(DWORD dwScope,DWORD dwType,DWORD dwUsage,LPNETRESOURCEW lpNetResource,LPHANDLE lphEnum);
DWORD WINAPI NPEnumResource(HANDLE hEnum,LPDWORD lpcCount,LPVOID lpBuffer,LPDWORD lpBufferSize);
DWORD WINAPI NPCloseEnum(HANDLE hEnum);

typedef DWORD (*PF_NPCloseEnum)(HANDLE hEnum);

#define WNNC_SPEC_VERSION 0x00000001
#define WNNC_SPEC_VERSION51 0x00050001
#define WNNC_NET_TYPE 0x00000002
#define WNNC_NET_NONE 0x00000000

#define WNNC_DRIVER_VERSION 0x00000003

#define WNNC_USER 0x00000004
#define WNNC_USR_GETUSER 0x00000001

#define WNNC_CONNECTION 0x00000006
#define WNNC_CON_ADDCONNECTION 0x00000001
#define WNNC_CON_CANCELCONNECTION 0x00000002
#define WNNC_CON_GETCONNECTIONS 0x00000004
#define WNNC_CON_ADDCONNECTION3 0x00000008
#define WNNC_CON_GETPERFORMANCE 0x00000040
#define WNNC_CON_DEFER 0x00000080

#define WNNC_DIALOG 0x00000008
#define WNNC_DLG_DEVICEMODE 0x00000001
#define WNNC_DLG_PROPERTYDIALOG 0x00000020
#define WNNC_DLG_SEARCHDIALOG 0x00000040
#define WNNC_DLG_FORMATNETWORKNAME 0x00000080
#define WNNC_DLG_PERMISSIONEDITOR 0x00000100
#define WNNC_DLG_GETRESOURCEPARENT 0x00000200
#define WNNC_DLG_GETRESOURCEINFORMATION 0x00000800

#define WNNC_ADMIN 0x00000009
#define WNNC_ADM_GETDIRECTORYTYPE 0x00000001
#define WNNC_ADM_DIRECTORYNOTIFY 0x00000002

#define WNNC_ENUMERATION 0x0000000B
#define WNNC_ENUM_GLOBAL 0x00000001
#define WNNC_ENUM_LOCAL 0x00000002
#define WNNC_ENUM_CONTEXT 0x00000004
#define WNNC_ENUM_SHAREABLE 0x00000008

#define WNNC_START 0x0000000C
#define WNNC_WAIT_FOR_START 0x00000001

typedef DWORD (WINAPI *PF_NPGetCaps)(DWORD ndex);
typedef DWORD (WINAPI *PF_NPGetUser)(LPWSTR lpName,LPWSTR lpUserName,LPDWORD lpnBufferLen);

DWORD WINAPI NPGetCaps (DWORD ndex);
DWORD WINAPI NPGetUser(LPWSTR lpName,LPWSTR lpUserName,LPDWORD lpnBufferLen);


#define WNTYPE_DRIVE 1
#define WNTYPE_FILE 2
#define WNTYPE_PRINTER 3
#define WNTYPE_COMM 4

#define WNPS_FILE 0
#define WNPS_DIR 1
#define WNPS_MULT 2

#define WNSRCH_REFRESH_FIRST_LEVEL 0x00000001

typedef DWORD (WINAPI *PF_NPDeviceMode)(HWND hParent);
typedef DWORD (WINAPI *PF_NPSearchDialog)(HWND hwndParent,LPNETRESOURCEW lpNetResource,LPVOID lpBuffer,DWORD cbBuffer,LPDWORD lpnFlags);
typedef DWORD (WINAPI *PF_NPGetResourceParent)(LPNETRESOURCEW lpNetResource,LPVOID lpBuffer,LPDWORD lpBufferSize);
typedef DWORD (WINAPI *PF_NPGetResourceInformation)(LPNETRESOURCEW lpNetResource,LPVOID lpBuffer,LPDWORD lpBufferSize,LPWSTR *lplpSystem);
typedef DWORD (WINAPI *PF_NPFormatNetworkName)(LPWSTR lpRemoteName,LPWSTR lpFormattedName,LPDWORD lpnLength,DWORD dwFlags,DWORD dwAveCharPerLine);
typedef DWORD (WINAPI *PF_NPGetPropertyText)(DWORD iButton,DWORD nPropSel,LPWSTR lpName,LPWSTR lpButtonName,DWORD nButtonNameLen,DWORD nType);
typedef DWORD (WINAPI *PF_NPPropertyDialog)(HWND hwndParent,DWORD iButtonDlg,DWORD nPropSel,LPWSTR lpFileName,DWORD nType);

DWORD WINAPI NPDeviceMode(HWND hParent);
DWORD WINAPI NPSearchDialog(HWND hwndParent,LPNETRESOURCEW lpNetResource,LPVOID lpBuffer,DWORD cbBuffer,LPDWORD lpnFlags);
DWORD WINAPI NPGetResourceParent(LPNETRESOURCEW lpNetResource,LPVOID lpBuffer,LPDWORD lpBufferSize);
DWORD WINAPI NPGetResourceInformation(LPNETRESOURCEW lpNetResource,LPVOID lpBuffer,LPDWORD lpBufferSize,LPWSTR *lplpSystem);
DWORD WINAPI NPFormatNetworkName(LPWSTR lpRemoteName,LPWSTR lpFormattedName,LPDWORD lpnLength,DWORD dwFlags,DWORD dwAveCharPerLine);
DWORD WINAPI NPGetPropertyText(DWORD iButton,DWORD nPropSel,LPWSTR lpName,LPWSTR lpButtonName,DWORD nButtonNameLen,DWORD nType);
DWORD WINAPI NPPropertyDialog(HWND hwndParent,DWORD iButtonDlg,DWORD nPropSel,LPWSTR lpFileName,DWORD nType);

#define WNDT_NORMAL 0
#define WNDT_NETWORK 1

#define WNDN_MKDIR 1
#define WNDN_RMDIR 2
#define WNDN_MVDIR 3

typedef DWORD (WINAPI *PF_NPGetDirectoryType)(LPWSTR lpName,LPINT lpType,WINBOOL bFlushCache);
typedef DWORD (WINAPI *PF_NPDirectoryNotify)(HWND hwnd,LPWSTR lpDir,DWORD dwOper);

DWORD WINAPI NPGetDirectoryType(LPWSTR lpName,LPINT lpType,WINBOOL bFlushCache);
DWORD WINAPI NPDirectoryNotify(HWND hwnd,LPWSTR lpDir,DWORD dwOper);
VOID WNetSetLastErrorA(DWORD err,LPSTR lpError,LPSTR lpProviders);
VOID WNetSetLastErrorW(DWORD err,LPWSTR lpError,LPWSTR lpProviders);

#define WNetSetLastError __MINGW_NAME_AW(WNetSetLastError)

#define WN_NETWORK_CLASS 0x00000001
#define WN_CREDENTIAL_CLASS 0x00000002
#define WN_PRIMARY_AUTHENT_CLASS 0x00000004
#define WN_SERVICE_CLASS 0x00000008

#define WN_VALID_LOGON_ACCOUNT 0x00000001
#define WN_NT_PASSWORD_CHANGED 0x00000002

typedef DWORD (WINAPI *PF_NPLogonNotify) (PLUID lpLogonId,LPCWSTR lpAuthentInfoType,LPVOID lpAuthentInfo,LPCWSTR lpPreviousAuthentInfoType,LPVOID lpPreviousAuthentInfo,LPWSTR lpStationName,LPVOID StationHandle,LPWSTR *lpLogonScript);
typedef DWORD (WINAPI *PF_NPPasswordChangeNotify) (LPCWSTR lpAuthentInfoType,LPVOID lpAuthentInfo,LPCWSTR lpPreviousAuthentInfoType,LPVOID lpPreviousAuthentInfo,LPWSTR lpStationName,LPVOID StationHandle,DWORD dwChangeInfo);

DWORD WINAPI NPLogonNotify (PLUID lpLogonId,LPCWSTR lpAuthentInfoType,LPVOID lpAuthentInfo,LPCWSTR lpPreviousAuthentInfoType,LPVOID lpPreviousAuthentInfo,LPWSTR lpStationName,LPVOID StationHandle,LPWSTR *lpLogonScript);
DWORD WINAPI NPPasswordChangeNotify (LPCWSTR lpAuthentInfoType,LPVOID lpAuthentInfo,LPCWSTR lpPreviousAuthentInfoType,LPVOID lpPreviousAuthentInfo,LPWSTR lpStationName,LPVOID StationHandle,DWORD dwChangeInfo);

#define NOTIFY_PRE 0x00000001
#define NOTIFY_POST 0x00000002

#define WNPERMC_PERM 0x00000001
#define WNPERMC_AUDIT 0x00000002
#define WNPERMC_OWNER 0x00000004

#define WNPERM_DLG_PERM 0
#define WNPERM_DLG_AUDIT 1
#define WNPERM_DLG_OWNER 2

typedef struct _NOTIFYINFO {
  DWORD dwNotifyStatus;
  DWORD dwOperationStatus;
  LPVOID lpContext;
} NOTIFYINFO,*LPNOTIFYINFO;

typedef struct _NOTIFYADD {
  HWND hwndOwner;
  NETRESOURCE NetResource;
  DWORD dwAddFlags;
} NOTIFYADD,*LPNOTIFYADD;

typedef struct _NOTIFYCANCEL {
  LPTSTR lpName;
  LPTSTR lpProvider;
  DWORD dwFlags;
  WINBOOL fForce;
} NOTIFYCANCEL,*LPNOTIFYCANCEL;

typedef DWORD (WINAPI *PF_AddConnectNotify) (LPNOTIFYINFO lpNotifyInfo,LPNOTIFYADD lpAddInfo);
typedef DWORD (WINAPI *PF_CancelConnectNotify) (LPNOTIFYINFO lpNotifyInfo,LPNOTIFYCANCEL lpCancelInfo);
typedef DWORD (WINAPI *PF_NPFMXGetPermCaps)(LPWSTR lpDriveName);
typedef DWORD (WINAPI *PF_NPFMXEditPerm)(LPWSTR lpDriveName,HWND hwndFMX,DWORD nDialogType);
typedef DWORD (WINAPI *PF_NPFMXGetPermHelp)(LPWSTR lpDriveName,DWORD nDialogType,WINBOOL fDirectory,LPVOID lpFileNameBuffer,LPDWORD lpBufferSize,LPDWORD lpnHelpContext);

DWORD WINAPI AddConnectNotify (LPNOTIFYINFO lpNotifyInfo,LPNOTIFYADD lpAddInfo);
DWORD WINAPI CancelConnectNotify (LPNOTIFYINFO lpNotifyInfo,LPNOTIFYCANCEL lpCancelInfo);
DWORD WINAPI NPFMXGetPermCaps(LPWSTR lpDriveName);
DWORD WINAPI NPFMXEditPerm(LPWSTR lpDriveName,HWND hwndFMX,DWORD nDialogType);
DWORD WINAPI NPFMXGetPermHelp(LPWSTR lpDriveName,DWORD nDialogType,WINBOOL fDirectory,LPVOID lpFileNameBuffer,LPDWORD lpBufferSize,LPDWORD lpnHelpContext);

#endif
