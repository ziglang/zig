/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __RPCNSIP_H__
#define __RPCNSIP_H__

#ifdef __cplusplus
extern "C" {
#endif

  typedef struct {
    RPC_NS_HANDLE LookupContext;
    RPC_BINDING_HANDLE ProposedHandle;
    RPC_BINDING_VECTOR *Bindings;
  } RPC_IMPORT_CONTEXT_P,*PRPC_IMPORT_CONTEXT_P;

  RPCNSAPI RPC_STATUS RPC_ENTRY I_RpcNsGetBuffer(PRPC_MESSAGE Message);
  RPCNSAPI RPC_STATUS RPC_ENTRY I_RpcNsSendReceive(PRPC_MESSAGE Message,RPC_BINDING_HANDLE *Handle);
  RPCNSAPI void RPC_ENTRY I_RpcNsRaiseException(PRPC_MESSAGE Message,RPC_STATUS Status);
  RPCNSAPI RPC_STATUS RPC_ENTRY I_RpcReBindBuffer(PRPC_MESSAGE Message);
  RPCNSAPI RPC_STATUS RPC_ENTRY I_NsServerBindSearch(void);
  RPCNSAPI RPC_STATUS RPC_ENTRY I_NsClientBindSearch(void);
  RPCNSAPI void RPC_ENTRY I_NsClientBindDone(void);

#ifdef __cplusplus
}
#endif
#endif
