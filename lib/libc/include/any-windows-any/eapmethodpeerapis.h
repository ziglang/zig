/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPMETHODPEERAPIS
#define _INC_EAPMETHODPEERAPIS
#if (_WIN32_WINNT >= 0x0600)
#include <eaptypes.h>
#include <eapmethodtypes.h>

#ifdef __cplusplus
extern "C" {
#endif

DWORD WINAPI EapPeerQueryCredentialInputFields(
  HANDLE hUserImpersonationToken,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwFlags,
  DWORD dwEapConnDataSize,
  BYTE *pbEapConnData,
  EAP_CONFIG_INPUT_FIELD_ARRAY *pEapConfigInputFieldsArray,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerBeginSession(
  DWORD dwFlags,
  const EapAttributes *pAttributeArray,
  HANDLE hTokenImpersonateUser,
  DWORD dwSizeofConnectionData,
  BYTE *pConnectionData,
  DWORD dwSizeofUserData,
  BYTE *pUserData,
  DWORD dwMaxSendPacketSize,
  EAP_SESSION_HANDLE *pSessionHandle,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerQueryUserBlobFromCredentialInputFields(
  HANDLE hUserImpersonationToken,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwFlags,
  DWORD dwEapConnDataSize,
  BYTE *pbEapConnData,
  const EAP_CONFIG_INPUT_FIELD_ARRAY *pEapConfigInputFieldArray,
  DWORD *pdwUsersBlobSize,
  BYTE **ppUserBlob,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerGetIdentity(
  DWORD dwflags,
  DWORD dwSizeofConnectionData,
  const BYTE *pConnectionData,
  DWORD dwSizeOfUserData,
  const BYTE *pUserData,
  HANDLE hTokenImpersonateUser,
  WINBOOL *pfInvokeUI,
  DWORD *pdwSizeOfUserDataOut,
  BYTE **ppUserDataOut,
  LPWSTR *ppwszIdentity,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerInitialize(
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerGetInfo(
  EAP_TYPE *pEapType,
  EAP_PEER_METHOD_ROUTINES *pEapInfo,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerSetCredentials(
  EAP_SESSION_HANDLE sessionHandle,
  LPWSTR pwszIdentity,
  LPWSTR pwszPassword,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerInvokeIdentityUI(
  EAP_METHOD_TYPE *pEapType,
  DWORD dwflags,
  HWND hwndParent,
  DWORD dwSizeOfConnectionData,
  const BYTE *pConnectionData,
  DWORD dwSizeOfUserData,
  const BYTE *pUserData,
  DWORD *pdwSizeOfUserDataOut,
  BYTE **ppUserDataOut,
  LPWSTR *ppwszIdentity,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerProcessRequestPacket(
  EAP_SESSION_HANDLE sessionHandle,
  DWORD cbReceivedPacket,
  EapPacket *pReceivedPacket,
  EapPeerMethodOutput *pEapOutput,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerGetResponsePacket(
  EAP_SESSION_HANDLE sessionHandle,
  DWORD *pcbSendPacket,
  EapPacket *pSendPacket,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerGetResult(
  EAP_SESSION_HANDLE sessionHandle,
  EapPeerMethodResultReason reason,
  EapPeerMethodResult *ppResult,
  EAP_ERROR **ppEapError
);

typedef struct tagEapPeerMethodResult {
  WINBOOL        fIsSuccess;
  DWORD          dwFailureReasonCode;
  WINBOOL        fSaveConnectionData;
  DWORD          dwSizeOfConnectionData;
  BYTE *         pConnectionData;
  WINBOOL        fSaveUserData;
  DWORD          dwSizeofUserData;
  BYTE *         pUserData;
  EAP_ATTRIBUTES *pAttribArray;
  EAP_ERROR *    pEapError;
} EapPeerMethodResult;

DWORD WINAPI EapPeerGetUIContext(
  EAP_SESSION_HANDLE sessionHandle,
  DWORD *pdwSizeOfUIContextData,
  BYTE **ppUIContextData,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerSetUIContext(
  EAP_SESSION_HANDLE sessionHandle,
  DWORD dwSizeOfUIContextData,
  const BYTE *pUIContextData,
  EapPeerMethodOutput *pEapOutput,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerGetResponseAttributes(
  EAP_SESSION_HANDLE sessionHandle,
  EapAttributes *pAttribs,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerSetResponseAttributes(
  EAP_SESSION_HANDLE sessionHandle,
  EapAttributes *pAttribs,
  EapPeerMethodOutput *pEapOutput,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerEndSession(
  EAP_SESSION_HANDLE sessionHandle,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerShutdown(
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerInvokeConfigUI(
  EAP_METHOD_TYPE *pEapType,
  HWND hwndParent,
  DWORD dwFlags,
  DWORD dwSizeOfConnectionDataIn,
  BYTE *pConnectionDataIn,
  DWORD *dwSizeOfConnectionDataOut,
  BYTE **ppConnectionDataOut,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerInvokeInteractiveUI(
  EAP_METHOD_TYPE *pEapType,
  HWND hwndParent,
  DWORD dwSizeofUIContextData,
  BYTE *pUIContextData,
  DWORD *pdwSizeOfDataFromInteractiveUI,
  BYTE **ppDataFromInteractiveUI,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerQueryInteractiveUIInputFields(
  DWORD dwVersion,
  DWORD dwFlags,
  DWORD dwSizeofUIContextData,
  const BYTE *pUIContextData,
  EAP_INTERACTIVE_UI_DATA *pEapInteractiveUIData,
  EAP_ERROR **ppEapError,
  LPVOID *pvReserved
);

DWORD WINAPI EapPeerQueryUIBlobFromInteractiveUIInputFields(
  DWORD dwVersion,
  DWORD dwFlags,
  DWORD dwSizeofUIContextData,
  const BYTE *pUIContextData,
  const EAP_INTERACTIVE_UI_DATA *pEapInteractiveUIData,
  DWORD *pdwSizeOfDataFromInteractiveUI,
  BYTE **ppDataFromInteractiveUI,
  EAP_ERROR **ppEapError,
  LPVOID *ppvReserved
);

DWORD WINAPI EapPeerConfigBlob2Xml(
  DWORD dwFlags,
  EAP_METHOD_TYPE eapMethodType,
  const BYTE *pConfigIn,
  DWORD dwSizeOfConfigIn,
  IXMLDOMDocument2 **ppConfigDoc,
  EAP_ERROR **pEapError
);

DWORD WINAPI EapPeerConfigXml2Blob(
  DWORD dwFlags,
  EAP_METHOD_TYPE eapMethodType,
  IXMLDOMDocument2 *pConfigDoc,
  BYTE **ppConfigOut,
  DWORD *pdwSizeOfConfigOut,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapPeerCredentialsXml2Blob(
  DWORD dwFlags,
  EAP_METHOD_TYPE eapMethodType,
  IXMLDOMDocument2 *pCredentialsDoc,
  const BYTE *pConfigIn,
  DWORD dwSizeOfConfigIn,
  BYTE **ppCredentialsOut,
  DWORD *pdwSizeofCredentialsOut,
  EAP_ERROR **ppEapError
);

VOID WINAPI EapPeerFreeMemory(
  void *pUIContextData
);

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EAPMETHODPEERAPIS*/
