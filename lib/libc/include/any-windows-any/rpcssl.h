/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RpcCertGeneratePrincipalName __MINGW_NAME_AW(RpcCertGeneratePrincipalName)

  RPCRTAPI RPC_STATUS RPC_ENTRY RpcCertGeneratePrincipalNameW(PCCERT_CONTEXT Context,DWORD Flags,RPC_WSTR *pBuffer);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcCertGeneratePrincipalNameA(PCCERT_CONTEXT Context,DWORD Flags,RPC_CSTR *pBuffer);

#ifdef __cplusplus
}
#endif
