/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CREDSSP
#define _INC_CREDSSP

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _CREDSSP_SUBMIT_TYPE {
  CredsspPasswordCreds         = 2,
  CredsspSchannelCreds         = 4,
  CredsspCertificateCreds      = 13,
  CredsspSubmitBufferBoth      = 50,
  CredsspSubmitBufferBothOld   = 51
} CREDSPP_SUBMIT_TYPE;

typedef struct _CREDSSP_CRED {
  CREDSPP_SUBMIT_TYPE Type;
  PVOID               pSchannelCred;
  PVOID               pSpnegoCred;
} CREDSSP_CRED, *PCREDSSP_CRED;

typedef struct _SecPkgContext_ClientCreds {
  ULONG  AuthBufferLen;
  PUCHAR AuthBuffer;
} SecPkgContext_ClientCreds, *PSecPkgContext_ClientCreds;

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /*_INC_CREDSSP*/
