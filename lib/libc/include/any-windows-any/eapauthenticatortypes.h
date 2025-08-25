/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPAUTHENTICATORTYPES
#define _INC_EAPAUTHENTICATORTYPES
#if (_WIN32_WINNT >= 0x0600)
#include <eaptypes.h>

typedef enum _EAP_AUTHENTICATOR_SEND_TIMEOUT {
  EAP_AUTHENTICATOR_SEND_TIMEOUT_NONE          = 0,
  EAP_AUTHENTICATOR_SEND_TIMEOUT_BASIC         = 1,
  EAP_AUTHENTICATOR_SEND_TIMEOUT_INTERACTIVE   = 2 
} EAP_AUTHENTICATOR_SEND_TIMEOUT;

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EAPAUTHENTICATORTYPES*/
