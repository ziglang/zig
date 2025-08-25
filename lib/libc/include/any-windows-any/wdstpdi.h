/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_WDSTPDI
#define _INC_WDSTPDI
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

/* 	Wdsmc.dll is missing an implib because Vista clients don't have the dll to generate it from */

#ifndef WDSMCSAPI
#define WDSMCSAPI WINAPI
#endif

typedef enum _TRANSPORTPROVIDER_CALLBACK_ID {
  WDS_TRANSPORTPROVIDER_CREATE_INSTANCE         = 0,
  WDS_TRANSPORTPROVIDER_COMPARE_CONTENT         = 1,
  WDS_TRANSPORTPROVIDER_OPEN_CONTENT            = 2,
  WDS_TRANSPORTPROVIDER_USER_ACCESS_CHECK       = 3,
  WDS_TRANSPORTPROVIDER_GET_CONTENT_SIZE        = 4,
  WDS_TRANSPORTPROVIDER_READ_CONTENT            = 5,
  WDS_TRANSPORTPROVIDER_CLOSE_CONTENT           = 6,
  WDS_TRANSPORTPROVIDER_CLOSE_INSTANCE          = 7,
  WDS_TRANSPORTPROVIDER_SHUTDOWN                = 8,
  WDS_TRANSPORTPROVIDER_DUMP_STATE              = 9,
  WDS_TRANSPORTPROVIDER_REFRESH_SETTINGS        = 10,
  WDS_TRANSPORTPROVIDER_GET_CONTENT_METADATA    = 11,
  WDS_TRANSPORTPROVIDER_MAX_CALLBACKS           = 12 
} TRANSPORTPROVIDER_CALLBACK_ID, *PTRANSPORTPROVIDER_CALLBACK_ID;

typedef enum _WDS_MC_SEVERITY {
  WDS_MC_TRACE_VERBOSE = 0x00010000,
  WDS_MC_TRACE_INFO = 0x00020000,
  WDS_MC_TRACE_WARNING = 0x00040000,
  WDS_MC_TRACE_ERROR = 0x00080000,
  WDS_MC_TRACE_FATAL = 0x00010000
} WDS_MC_SEVERITY;

typedef struct _WDS_TRANSPORTPROVIDER_INIT_PARAMS {
  ULONG  ulLength;
  ULONG  ulMcServerVersion;
  HKEY   hRegistryKey;
  HANDLE hProvider;
} WDS_TRANSPORTPROVIDER_INIT_PARAMS, *PWDS_TRANSPORTPROVIDER_INIT_PARAMS;

typedef struct _WDS_TRANSPORTPROVIDER_SETTINGS {
  ULONG ulLength;
  ULONG ulLength;
} WDS_TRANSPORTPROVIDER_SETTINGS, *PWDS_TRANSPORTPROVIDER_SETTINGS;

PVOID WDSMCSAPI WdsTransportServerAllocateBuffer(
  HANDLE hProvider,
  ULONG ulBufferSize
);

HRESULT WDSMCSAPI WdsTransportServerCompleteRead(
  HANDLE hProvider,
  ULONG ulBytesRead,
  PVOID pvUserData,
  HRESULT hReadResult
);

HRESULT WDSMCSAPI WdsTransportServerFreeBuffer(
  HANDLE hProvider,
  PVOID pvBuffer
);

HRESULT WDSMCSAPI WdsTransportServerRegisterCallback(
  HANDLE hProvider,
  TRANSPORTPROVIDER_CALLBACK_ID CallbackId,
  PVOID pfnCallback
);

HRESULT WDSMCSAPI WdsTransportServerTraceV(
  HANDLE hProvider,
  WDS_MC_SEVERITY Severity,
  LPCWSTR pwszFormat,
  va_list Params
);

HRESULT WDSMCSAPI WdsTransportServerTrace(
  HANDLE hProvider,
  WDS_MC_SEVERITY Severity,
  LPCWSTR pwszFormat
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WDSTPDI*/
