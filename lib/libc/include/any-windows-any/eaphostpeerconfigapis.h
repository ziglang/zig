/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPHOSTPEERCONFIGAPIS
#define _INC_EAPHOSTPEERCONFIGAPIS
#if (_WIN32_WINNT >= 0x0600)
#include <eaptypes.h>
#ifdef __cplusplus
extern "C" {
#endif

DWORD WINAPI EapHostPeerQueryUserBlobFromCredentialInputFields(
  HANDLE hUserImpersonationToken,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwFlags,
  DWORD dwEapConnDataSize,
  const BYTE *pbEapConnData,
  const EAP_CONFIG_INPUT_FIELD_ARRAY *pEapConfigInputFieldArray,
  DWORD *pdwUserBlobSize,
  BYTE **ppbUserBlob,
  EAP_ERROR **pEapError
);

VOID WINAPI EapHostPeerFreeErrorMemory(
    EAP_ERROR *pEapError
);

DWORD WINAPI EapHostPeerConfigBlob2Xml(
  DWORD dwFlags,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwSizeOfConfigIn,
  BYTE *pConfigIn,
  IXMLDOMDocument2 **ppConfigDoc,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapHostPeerInvokeInteractiveUI(
  HWND hwndParent,
  DWORD dwSizeofUIContextData,
  const BYTE *pUIContextData,
  DWORD *pdwSizeofDataFromInteractiveUI,
  BYTE **ppDataFromInteractiveUI,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapHostPeerQueryInteractiveUIInputFields(
  DWORD dwVersion,
  DWORD dwFlags,
  DWORD dwSizeofUIContextData,
  const BYTE *pUIContextData,
  EAP_INTERACTIVE_UI_DATA *pEapInteractiveUIData,
  EAP_ERROR **ppEapError,
  LPVOID *ppvReserved
);

DWORD WINAPI EapHostPeerQueryUIBlobFromInteractiveUIInputFields(
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

DWORD WINAPI EapHostPeerConfigXml2Blob(
  DWORD dwFlags,
  IXMLDOMNode *pConfigDoc,
  DWORD *pdwSizeOfConfigOut,
  BYTE **ppConfigOut,
  EAP_METHOD_TYPE *pEapMethodType,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapHostPeerCredentialsXml2Blob(
  DWORD dwFlags,
  IXMLDOMNode *pCredentialsDoc,
  DWORD dwSizeOfConfigIn,
  BYTE *pConfigIn,
  DWORD *pdwSizeofCredentialsOut,
  BYTE **ppCredentialsOut,
  EAP_METHOD_TYPE *pEapMethodType,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapHostPeerInvokeConfigUI(
  HWND hwndParent,
  DWORD dwFlags,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwSizeOfConfigIn,
  const BYTE *pConfigIn,
  DWORD *pdwSizeOfConfigOut,
  BYTE **ppConfigOut,
  EAP_ERROR **pEapError
);

VOID WINAPI EapHostPeerFreeMemory(
  BYTE *pData
);

DWORD WINAPI EapHostPeerQueryCredentialInputFields(
  HANDLE hUserImpersonationToken,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwFlags,
  DWORD dwEapConnDataSize,
  const BYTE *pbEapConnData,
  EAP_CONFIG_INPUT_FIELD_ARRAY *pEapConfigInputFieldArray,
  EAP_ERROR **pEapError
);

DWORD WINAPI EapHostPeerGetMethods(
  EAP_METHOD_INFO_ARRAY *pEapMethodInfoArray,
  EAP_ERROR **ppEapError
);

DWORD WINAPI EapHostPeerInvokeIdentityUI(
  DWORD dwVersion,
  EAP_METHOD_TYPE eapMethodType,
  DWORD dwFlags,
  HWND hwndParent,
  DWORD dwSizeofConnectionData,
  const  BYTE * pConnectionData,
  DWORD dwSizeofUserData,
  const  BYTE *pUserData,
  DWORD *pdwSizeofUserDataOut,
  BYTE **ppUserDataOut,
  LPWSTR *ppwszIdentity,
  EAP_ERROR **ppEapError,
  LPVOID *ppvReserved
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EAPHOSTPEERCONFIGAPIS*/
