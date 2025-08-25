/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WDSCLIENTAPI
#define _INC_WDSCLIENTAPI
#include <wdstpdi.h>
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WDSTCIAPI
#define WDSTCIAPI WINAPI
#endif

/* Wdstptc.dll is missing an implib because Vista clients don't have the dll to generate it from */

typedef VOID (CALLBACK *PFN_WdsTransportClientReceiveContents)(
  HANDLE hSessionKey,
  PVOID pCallerData,
  PVOID pMetadata,
  ULONG ulSize,
  PULARGE_INTEGER pContentOffset
);

typedef VOID (CALLBACK *PFN_WdsTransportClientReceiveMetadata)(
  HANDLE hSessionKey,
  PVOID pCallerData,
  PVOID pMetadata,
  ULONG ulSize
);

typedef VOID (CALLBACK *PFN_WdsTransportClientSessionComplete)(
  HANDLE hSessionKey,
  PVOID pCallerData,
  DWORD dwError
);

typedef VOID (CALLBACK *PFN_WdsTransportClientSessionStart)(
  HANDLE hSessionKey,
  PVOID pCallerData,
  PULARGE_INTEGER FileSize
);

typedef VOID (CALLBACK *PFN_WdsTransportClientSessionStartEx)(
  HANDLE hSessionKey,
  PVOID pCallerData,
  PTRANSPORTCLIENT_SESSION_INFO Info
);

typedef enum _TRANSPORTCLIENT_CALLBACK_ID {
  WDS_TRANSPORTCLIENT_SESSION_START      = 0,
  WDS_TRANSPORTCLIENT_RECEIVE_CONTENTS   = 1,
  WDS_TRANSPORTCLIENT_SESSION_COMPLETE   = 2,
  WDS_TRANSPORTCLIENT_RECEIVE_METADATA   = 3,
  WDS_TRANSPORTCLIENT_SESSION_STARTEX    = 4,
  WDS_TRANSPORTCLIENT_MAX_CALLBACKS      = 5 
} TRANSPORTCLIENT_CALLBACK_ID,*PTRANSPORTCLIENT_CALLBACK_ID;

typedef struct _TRANSPORTCLIENT_SESSION_INFO {
  ULONG          ulStructureLength;
  ULARGE_INTEGER ullFileSize;
  ULONG          ulBlockSize;
} TRANSPORTCLIENT_SESSION_INFO, *PTRANSPORTCLIENT_SESSION_INFO;

#define WDS_TRANSPORT_CLIENT_CURRENT_API_VERSION 1

#define WDS_TRANSPORTCLIENT_AUTH 1
#define WDS_TRANSPORTCLIENT_NO_AUTH 2

#define WDS_TRANSPORTCLIENT_PROTOCOL_MULTICAST 1

typedef struct _WDS_TRANSPORTCLIENT_REQUEST {
   ULONG  ulLength;
   ULONG  ulApiVersion;
   ULONG  ulAuthLevel;
  LPCWSTR pwszServer;
  LPCWSTR pwszNamespace;
  LPCWSTR pwszObjectName;
  ULONG   ulCacheSize;
  ULONG   ulProtocol;
  PVOID   pvProtocolData;
  ULONG   ulProtocolDataLength;
} WDS_TRANSPORTCLIENT_REQUEST, *PWDS_TRANSPORTCLIENT_REQUEST;

DWORD WDSTCIAPI WdsTransportClientStartSession(
  HANDLE hSessionKey
);

DWORD WDSTCIAPI WdsTransportClientAddRefBuffer(
  PVOID pvBuffer
);

DWORD WDSTCIAPI WdsTransportClientCancelSession(
  HANDLE hSessionKey
);

DWORD WDSTCIAPI WdsTransportClientCloseSession(
  HANDLE hSessionKey
);

DWORD WDSTCIAPI WdsTransportClientCompleteReceive(
  HANDLE hSessionKey,
  HANDLE ulSize,
  PULARGE_INTEGER pullOffset
);

DWORD WDSTCIAPI WdsTransportClientInitialize(void);

DWORD WDSTCIAPI WdsTransportClientInitializeSession(
  PWDS_TRANSPORTCLIENT_REQUEST pSessionRequest,
  PVOID pCallerData,
  PHANDLE hSessionKey
);

DWORD WDSTCIAPI WdsTransportClientQueryStatus(
  HANDLE hSessionKey,
  PULONG puStatus,
  PULONG puErrorCode
);

DWORD WDSTCIAPI WdsTransportClientRegisterCallback(
  HANDLE hSessionKey,
  TRANSPORTCLIENT_CALLBACK_ID CallbackId,
  PVOID pfnCallback
);

DWORD WDSTCIAPI WdsTransportClientReleaseBuffer(
  PVOID pvBuffer
);

DWORD WDSTCIAPI WdsTransportClientShutdown(void);

DWORD WDSTCIAPI WdsTransportClientWaitForCompletion(
  HANDLE hSessionKey,
  ULONG uTimeout
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WDSCLIENTAPI*/
