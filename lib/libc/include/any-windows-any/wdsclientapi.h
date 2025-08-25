/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WDSCLIENTAPI
#define _INC_WDSCLIENTAPI
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

#define WDS_CLI_MSG_START 0
#define WDS_CLI_MSG_COMPLETE 1
#define WDS_CLI_MSG_PROGRESS 2
#define WDS_CLI_MSG_TEXT 3

#ifndef WDSCLIAPI
#define WDSCLIAPI WINAPI
#endif

/* WdsClientAPI.dll is missing an implib because Vista clients don't have the dll to generate it from */

typedef VOID (CALLBACK *PFN_WdsCliCallback)(
  DWORD dwMessageId,
  WPARAM wParam,
  LPARAM lParam,
  PVOID pvUserData
);

typedef VOID (WDSCLIAPI *PFN_WdsCliTraceFunction)(
  LPCWSTR pwszFormat,
  va_list Params
);


typedef enum _WDS_LOG_LEVEL {
  WDS_LOG_LEVEL_DISABLED   = 0,
  WDS_LOG_LEVEL_ERROR      = 1,
  WDS_LOG_LEVEL_WARNING    = 2,
  WDS_LOG_LEVEL_INFO       = 3 
} WDS_LOG_LEVEL;

typedef enum _WDS_LOG_TYPE_CLIENT {
  WDS_LOG_TYPE_CLIENT_ERROR             = 1,
  WDS_LOG_TYPE_CLIENT_STARTED,
  WDS_LOG_TYPE_CLIENT_FINISHED,
  WDS_LOG_TYPE_CLIENT_IMAGE_SELECTED,
  WDS_LOG_TYPE_CLIENT_APPLY_STARTED,
  WDS_LOG_TYPE_CLIENT_APPLY_FINISHED,
  WDS_LOG_TYPE_CLIENT_GENERIC_MESSAGE,
  WDS_LOG_TYPE_CLIENT_MAX_CODE 
} WDS_LOG_TYPE_CLIENT;

typedef struct tagWDS_CLI_CRED {
  PCWSTR  pwszUserName;
  PCWSTR pwszDomain;
  PCWSTR pwszPassword;
} WDS_CLI_CRED, *PWDS_CLI_CRED, *LPWDS_CLI_CRED;

HRESULT WDSCLIAPI WdsCliAuthorizeSession(
  HANDLE hSession,
  PWDS_CLI_CRED pCred
);

HRESULT WDSCLIAPI WdsCliCancelTransfer(
  HANDLE hTransfer
);

HRESULT WDSCLIAPI WdsCliClose(
  HANDLE Handle
);

HRESULT WDSCLIAPI WdsCliCreateSession(
  PWSTR pwszServer,
  PWDS_CLI_CRED pCred,
  PHANDLE phSession
);

HRESULT WDSCLIAPI WdsCliFindFirstImage(
  HANDLE hSession,
  PHANDLE phFindHandle
);

HRESULT WDSCLIAPI WdsCliFindNextImage(
  HANDLE Handle
);

#define WdsCliFlagEnumFilterVersion 1

HRESULT WDSCLIAPI WdsCliGetEnumerationFlags(
  HANDLE Handle,
  PDWORD pdwFlags
);

#define PROCESSOR_ARCHITECTURE_AMD64 9
#define PROCESSOR_ARCHITECTURE_IA64 6
#define PROCESSOR_ARCHITECTURE_INTEL 0

HRESULT WDSCLIAPI WdsCliGetImageArchitecture(
  HANDLE hIfh,
  PDWORD pdwValue
);

HRESULT WDSCLIAPI WdsCliGetImageDescription(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetImageGroup(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetImageHalName(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetImageHandleFromFindHandle(
  HANDLE FindHandle,
  PHANDLE phImageHandle
);

HRESULT WDSCLIAPI WdsCliGetImageHandleFromTransferHandle(
  HANDLE hTransfer,
  PHANDLE phImageHandle
);

HRESULT WDSCLIAPI WdsCliGetImageIndex(
  HANDLE hIfh,
  PDWORD pdwValue
);

HRESULT WDSCLIAPI WdsCliGetImageLanguage(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetImageLanguages(
  HANDLE hIfh,
  PTSTR **pppszValues,
  PDWORD pdwNumValues
);

HRESULT WDSCLIAPI WdsCliGetImageLastModifiedTime(
  HANDLE hIfh,
  PSYSTEMTIME *ppSysTimeValue
);

HRESULT WINAPI WdsCliGetImageName(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetImageNamespace(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetImagePath(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetImageSize(
  HANDLE hIfh,
  PULONGLONG pullValue
);

HRESULT WDSCLIAPI WdsCliGetImageVersion(
  HANDLE hIfh,
  PWSTR *ppwszValue
);

HRESULT WDSCLIAPI WdsCliGetTransferSize(
  HANDLE hIfh,
  PULONGLONG pullValue
);

HRESULT WDSCLIAPI WdsCliInitializeLog(
  HANDLE hSession,
  ULONG ulClientArchitecture,
  PWSTR pwszClientId,
  PWSTR pwszClientAddress
);

#define WDS_LOG_LEVEL_DISABLED 0
#define WDS_LOG_LEVEL_ERROR 1
#define WDS_LOG_LEVEL_WARNING 2
#define WDS_LOG_LEVEL_INFO 3

#define WDS_LOG_TYPE_CLIENT_ERROR 1
#define WDS_LOG_TYPE_CLIENT_STARTED 2
#define WDS_LOG_TYPE_CLIENT_FINISHED 3
#define WDS_LOG_TYPE_CLIENT_IMAGE_SELECTED 4
#define WDS_LOG_TYPE_CLIENT_APPLY_STARTED 5
#define WDS_LOG_TYPE_CLIENT_APPLY_FINISHED 6
#define WDS_LOG_TYPE_CLIENT_GENERIC_MESSAGE 7
#define WDS_LOG_TYPE_CLIENT_MAX_CODE 8

HRESULT __cdecl WdsCliLog(
  HANDLE hSession,
  ULONG ulLogLevel,
  ULONG ulMessageCode,
  ...
);

HRESULT WDSCLIAPI WdsCliRegisterTrace(
  PFN_WdsCliTraceFunction pfn
);

HRESULT WDSCLIAPI WdsCliTransferFile(
  PCWSTR pwszServer,
  PCWSTR pwszNamespace,
  PCWSTR pwszRemoteFilePath,
  PCWSTR pwszLocalFilePath,
  DWORD dwFlags,
  DWORD dwReserved,
  PFN_WdsCliCallback pfnWdsCliCallback,
  PVOID pvUserData,
  PHANDLE phTransfer
);

HRESULT WDSCLIAPI WdsCliTransferImage(
  HANDLE hImage,
  PWSTR pwszLocalPath,
  DWORD dwFlags,
  DWORD dwReserved,
  PFN_WdsCliCallback pfnWdsCliCallback,
  PVOID pvUserData,
  PHANDLE phTransfer
);

HRESULT WDSCLIAPI WdsCliWaitForTransfer(
  HANDLE hTransfer
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WDSCLIENTAPI*/
