/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPMETHODAUTHENTICATORAPIS
#define _INC_EAPMETHODAUTHENTICATORAPIS
#if (_WIN32_WINNT >= 0x0600)
#include <eaptypes.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef struct _EAP_AUTHENTICATOR_METHOD_ROUTINES {
  DWORD           dwSizeInBytes;
  EAP_METHOD_TYPE *pEapType;
  DWORD (APIENTRY *EapMethodAuthenticatorInitialize)(
      EAP_METHOD_TYPE pEapType, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorBeginSession)(
      DWORD dwFlags, 
      LPCWSTR pwszIdentity, 
      EapAttributes pAttributeArray, 
      DWORD dwSizeOfConnectionData, 
      BYTE pConnectionData, 
      DWORD dwMaxSendPacketSize, 
      EAP_SESSION_HANDLE pSessionHandle, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorUpdateInnerMethodParams)(
      EAP_SESSION_HANDLE sessionHandle, 
      DWORD dwFlags, 
      WCHAR pwszIdentity, 
      EapAttributes pAttributeArray, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorReceivePacket)(
      EAP_SESSION_HANDLE sessionHandle, 
      DWORD cbReceivePacket, 
      EapPacket pReceivePacket, 
      EAP_METHOD_AUTHENTICATOR_RESPONSE_ACTION pEapOutput, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorSendPacket)(
      EAP_SESSION_HANDLE sessionHandle, 
      BYTE bPacketId, 
      DWORD pcbSendPacket, 
      EapPacket pSendPacket, 
      EAP_AUTHENTICATOR_SEND_TIMEOUT pTimeout, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorGetAttributes)(
      EAP_SESSION_HANDLE sessionHandle, 
      EapAttributes pAttribs, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorSetAttributes)(
      EAP_SESSION_HANDLE sessionHandle, 
      EapAttributes pAttribs, 
      EAP_METHOD_AUTHENTICATOR_RESPONSE_ACTION pEapOutput, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorGetResult)(
      EAP_SESSION_HANDLE sessionHandle, 
      EAP_METHOD_AUTHENTICATOR_RESULT pResult, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorEndSession)(
      EAP_SESSION_HANDLE sessionHandle, 
      EAP_ERROR ppEapError);
  DWORD (APIENTRY *EapMethodAuthenticatorShutdown)(
      EAP_METHOD_TYPE pEapType, 
      EAP_ERROR ppEapError);
} EAP_AUTHENTICATOR_METHOD_ROUTINES;

VOID WINAPI EapMethodAuthenticatorFreeMemory(
  void *pUIContextData
);

DWORD WINAPI EapMethodAuthenticatorInitialize(
  EAP_METHOD_TYPE *pEapType,
  EAP_ERROR **ppEapError
);

VOID WINAPI EapPeerFreeErrorMemory(
  EAP_ERROR *ppEapError
);

DWORD WINAPI EapMethodAuthenticatorGetResult(
  EAP_SESSION_HANDLE sessionHandle,
  EAP_METHOD_AUTHENTICATOR_RESULT *pResult,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapMethodAuthenticatorBeginSession(
  DWORD dwFlags,
  LPCWSTR pwszIdentity,
  const EapAttributes *pAttributeArray,
  DWORD dwSizeOfConnectionData,
  const BYTE *pConnectionData,
  DWORD dwMaxSendPacketSize,
  EAP_SESSION_HANDLE *pSessionHandle,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapMethodAuthenticatorFreeErrorMemory(
  EAP_ERROR *ppEapError
);

DWORD EapMethodAuthenticatorEndSession(
  EAP_SESSION_HANDLE sessionHandle,
  EAP_ERROR **ppEapError
);

DWORD EapMethodAuthenticatorGetAttributes(
  EAP_SESSION_HANDLE sessionHandle,
  EapAttributes *pAttribs,
  EAP_ERROR **ppEapError
);

DWORD EapMethodAuthenticatorGetInfo(
  EAP_METHOD_TYPE *pEapType,
  EAP_AUTHENTICATOR_METHOD_ROUTINES *pEapInfo,
  EAP_ERROR **ppEapError
);

DWORD EapMethodAuthenticatorGetResult(
  EAP_SESSION_HANDLE sessionHandle,
  EAP_METHOD_AUTHENTICATOR_RESULT *pResult,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapMethodAuthenticatorInvokeConfigUI(
  EAP_METHOD_TYPE *pEapMethodType,
  HWND hwndParent,
  DWORD dwFlags,
  LPCWSTR pwszMachineName,
  DWORD dwSizeOfConfigIn,
  BYTE *pConfigIn,
  DWORD *pdwSizeOfConfigOut,
  BYTE **ppConfigOut,
  EAP_ERROR **pEapError
);

DWORD WINAPI EapMethodAuthenticatorReceivePacket(
  EAP_SESSION_HANDLE sessionHandle,
  DWORD cbReceivePacket,
  const EapPacket *pReceivePacket,
  EAP_METHOD_AUTHENTICATOR_RESPONSE_ACTION *pEapOutput,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapMethodAuthenticatorSendPacket(
  EAP_SESSION_HANDLE sessionHandle,
  BYTE bPacketId,
  DWORD *pcbSendPacket,
  EapPacket *pSendPacket,
  EAP_AUTHENTICATOR_SEND_TIMEOUT *pTimeout,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapMethodAuthenticatorSetAttributes(
  EAP_SESSION_HANDLE sessionHandle,
  const EapAttributes *pAttribs,
  EAP_METHOD_AUTHENTICATOR_RESPONSE_ACTION *pEapOutput,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapMethodAuthenticatorShutdown(
  EAP_METHOD_TYPE *peapType,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapMethodAuthenticatorUpdateInnerMethodParams(
  EAP_SESSION_HANDLE sessionHandle,
  DWORD dwFlags,
  const WCHAR *pwszIdentity,
  const EapAttributes *pAttributeArray,
  EAP_ERROR **ppEapError
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EAPMETHODAUTHENTICATORAPIS*/
