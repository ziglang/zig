/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPAUTHENTICATORACTIONDEFINE
#define _INC_EAPAUTHENTICATORACTIONDEFINE
#if (_WIN32_WINNT >= 0x0600)
#include <eaptypes.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef enum _EAP_METHOD_AUTHENTICATOR_RESPONSE_ACTION {
  EAP_METHOD_AUTHENTICATOR_RESPONSE_DISCARD           = 0,
  EAP_METHOD_AUTHENTICATOR_RESPONSE_SEND              = 1,
  EAP_METHOD_AUTHENTICATOR_RESPONSE_RESULT            = 2,
  EAP_METHOD_AUTHENTICATOR_RESPONSE_RESPOND           = 3,
  EAP_METHOD_AUTHENTICATOR_RESPONSE_AUTHENTICATE      = 4,
  EAP_METHOD_AUTHENTICATOR_RESPONSE_HANDLE_IDENTITY   = 5 
} EAP_METHOD_AUTHENTICATOR_RESPONSE_ACTION;

typedef enum _EapPeerMethodResponseAction {
  EapPeerMethodResponseActionDiscard    = 0,
  EapPeerMethodResponseActionSend       = 1,
  EapPeerMethodResponseActionResult     = 2,
  EapPeerMethodResponseActionInvokeUI   = 3,
  EapPeerMethodResponseActionRespond    = 4,
  EapPeerMethodResponseActionNone       = 5 
} EapPeerMethodResponseAction;

typedef enum  {
  EapPeerMethodResultUnknown   = 1,
  EapPeerMethodResultSuccess   = 2,
  EapPeerMethodResultFailure   = 3 
} EapPeerMethodResultReason;

typedef struct _EAP_METHOD_AUTHENTICATOR_RESULT {
  BOOL           fIsSuccess;
  DWORD          dwFailureReason;
  EAP_ATTRIBUTES *pAuthAttribs;
} EAP_METHOD_AUTHENTICATOR_RESULT;

typedef struct tagEapPeerMethodOutput {
  EapPeerMethodResponseAction action;
  WINBOOL                     fAllowNotifications;
} EapPeerMethodOutput;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EAPAUTHENTICATORACTIONDEFINE*/
