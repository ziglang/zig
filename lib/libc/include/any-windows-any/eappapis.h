/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPPAPIS
#define _INC_EAPPAPIS
#if (_WIN32_WINNT >= 0x0600)
#include <eaptypes.h>
#include <eaphostpeertypes.h>
#ifdef __cplusplus
extern "C" {
#endif

DWORD APIENTRY EapHostPeerGetResult(
  EAP_SESSIONID sessionHandle,
  EapHostPeerMethodResultReason reason,
  EapHostPeerMethodResult *ppResult,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapHostPeerProcessReceivedPacket(
  EAP_SESSIONID sessionHandle,
  DWORD cbReceivePacket,
  const BYTE *pReceivePacket,
  EapHostPeerResponseAction *pEapOutput,
  EAP_ERROR **ppEapError
);

VOID APIENTRY EapHostPeerFreeEapError(
  EAP_ERROR *ppEapError
);

DWORD APIENTRY EapHostPeerClearConnection(
  GUID *pConnectionId,
  EAP_ERROR **ppEapError
);

DWORD APIENTRY EapHostPeerEndSession(
  EAP_SESSIONID sessionHandle,
  EAP_ERROR **ppEapError
);

DWORD APIENTRY EapHostPeerGetAuthStatus(
  EAP_SESSIONID sessionHandle,
  EapHostPeerAuthParams authParam,
  DWORD *pcbAuthData,
  BYTE **ppAuthData,
  EAP_ERROR **ppEapError
);

DWORD APIENTRY EapHostPeerGetResponseAttributes(
  EAP_SESSIONID sessionHandle,
  EapAttributes *pAttribs,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapHostPeerGetSendPacket(
  EAP_SESSIONID sessionHandle,
  DWORD *pcbSendPacket,
  BYTE **ppSendPacket,
  EAP_ERROR **ppEapError
);

DWORD APIENTRY EapHostPeerGetUIContext(
  EAP_SESSIONID sessionHandle,
  DWORD *pdwSizeOfUIContextData,
  BYTE **ppUIContextData,
  EAP_ERROR **ppEapError
);

DWORD APIENTRY EapHostPeerSetResponseAttributes(
  EAP_SESSIONID sessionHandle,
  const EapAttributes *pAttribs,
  EapHostPeerResponseAction *pEapOutput,
  EAP_ERROR **ppEapError
);

DWORD APIENTRY EapHostPeerSetUIContext(
  EAP_SESSIONID sessionHandle,
  DWORD dwSizeOfUIContextData,
  const BYTE *pUIContextData,
  EapHostPeerResponseAction *pEapOutput,
  EAP_ERROR **ppEapError
);

typedef VOID ( CALLBACK *NotificationHandler )(
  GUID connectionId,
  VOID *pContextData
);

DWORD APIENTRY EapHostPeerBeginSession(
  DWORD dwFlags,
  EAP_METHOD_TYPE eapType,
  const EapAttributes *pAttributeArray,
  HANDLE hTokenImpersonateUser,
  DWORD dwSizeOfConnectionData,
  const BYTE *pConnectionData,
  DWORD dwSizeOfUserData,
  const BYTE *pUserData,
  DWORD dwMaxSendPacketSize,
  const GUID *pConnectionId,
  NotificationHandler func,
  VOID *pContextData,
  EAP_SESSIONID *pSessionId,
  EAP_ERROR **ppEapError
);

VOID WINAPI  EapHostPeerFreeRuntimeMemory(
  BYTE *pData
);

DWORD WINAPI EapHostPeerGetIdentity(
  DWORD dwVersion,
  DWORD dwFlags,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwSizeofConnectionData,
  const BYTE *pConnectionData,
  DWORD dwSizeofUserData,
  const  BYTE *pUserData,
  HANDLE hTokenImpersonateUser,
  WINBOOL *pfInvokeUI,
  DWORD *pdwSizeofUserDataOut,
  BYTE **ppUserDataOut,
  LPWSTR *ppwszIdentity,
  EAP_ERROR **ppEapError,
  BYTE **ppvReserved
);

DWORD WINAPI EapHostPeerInitialize(void);
void WINAPI EapHostPeerUninitialize(void);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EAPPAPIS*/
