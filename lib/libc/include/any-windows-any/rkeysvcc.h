/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __rkeysvcc_h__
#define __rkeysvcc_h__

#ifdef __cplusplus
extern "C" {
#endif

  typedef void *KEYSVCC_HANDLE;

  typedef enum _KEYSVC_TYPE {
    KeySvcMachine,KeySvcService
  } KEYSVC_TYPE;

  typedef struct _KEYSVC_UNICODE_STRING {
    USHORT Length;
    USHORT MaximumLength;
    USHORT *Buffer;
  } KEYSVC_UNICODE_STRING,*PKEYSVC_UNICODE_STRING;

  typedef struct _KEYSVC_BLOB {
    ULONG cb;
    BYTE *pb;
  } KEYSVC_BLOB,*PKEYSVC_BLOB;

#define RKEYSVC_CONNECT_SECURE_ONLY 0x00000001

  ULONG RKeyOpenKeyService(LPSTR pszMachineName,KEYSVC_TYPE OwnerType,LPWSTR pwszOwnerName,void *pAuthentication,void *pReserved,KEYSVCC_HANDLE *phKeySvcCli);
  ULONG RKeyCloseKeyService(KEYSVCC_HANDLE hKeySvcCli,void *pReserved);
  ULONG RKeyPFXInstall(KEYSVCC_HANDLE hKeySvcCli,PKEYSVC_BLOB pPFX,PKEYSVC_UNICODE_STRING pPassword,ULONG ulFlags);

#ifdef __cplusplus
}
#endif
#endif
