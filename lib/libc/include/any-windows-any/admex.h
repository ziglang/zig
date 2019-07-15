/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __admex_h__
#define __admex_h__

#ifndef __IMSAdminReplication_FWD_DEFINED__
#define __IMSAdminReplication_FWD_DEFINED__
typedef struct IMSAdminReplication IMSAdminReplication;
#endif

#ifndef __IMSAdminCryptoCapabilities_FWD_DEFINED__
#define __IMSAdminCryptoCapabilities_FWD_DEFINED__
typedef struct IMSAdminCryptoCapabilities IMSAdminCryptoCapabilities;
#endif

#include "unknwn.h"
#include "objidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _ADMEX_IADM_
#define _ADMEX_IADM_
  DEFINE_GUID(IID_IMSAdminReplication,0xc804d980,0xebec,0x11d0,0xa6,0xa0,0x0,0xa0,0xc9,0x22,0xe7,0x52);
  DEFINE_GUID(IID_IMSAdminCryptoCapabilities,0x78b64540,0xf26d,0x11d0,0xa6,0xa3,0x0,0xa0,0xc9,0x22,0xe7,0x52);
  DEFINE_GUID(CLSID_MSCryptoAdmEx,0x9f0bd3a0,0xec01,0x11d0,0xa6,0xa0,0x0,0xa0,0xc9,0x22,0xe7,0x52);

  extern RPC_IF_HANDLE __MIDL_itf_admex_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_admex_0000_v0_0_s_ifspec;

#ifndef __IMSAdminReplication_INTERFACE_DEFINED__
#define __IMSAdminReplication_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSAdminReplication;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSAdminReplication : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSignature(DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
    virtual HRESULT WINAPI Propagate(DWORD dwBufferSize,unsigned char *pszBuffer) = 0;
    virtual HRESULT WINAPI Propagate2(DWORD dwBufferSize,unsigned char *pszBuffer,DWORD dwSignatureMismatch) = 0;
    virtual HRESULT WINAPI Serialize(DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
    virtual HRESULT WINAPI DeSerialize(DWORD dwBufferSize,unsigned char *pbBuffer) = 0;
  };
#else
  typedef struct IMSAdminReplicationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSAdminReplication *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSAdminReplication *This);
      ULONG (WINAPI *Release)(IMSAdminReplication *This);
      HRESULT (WINAPI *GetSignature)(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *Propagate)(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pszBuffer);
      HRESULT (WINAPI *Propagate2)(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pszBuffer,DWORD dwSignatureMismatch);
      HRESULT (WINAPI *Serialize)(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *DeSerialize)(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pbBuffer);
    END_INTERFACE
  } IMSAdminReplicationVtbl;
  struct IMSAdminReplication {
    CONST_VTBL struct IMSAdminReplicationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSAdminReplication_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSAdminReplication_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSAdminReplication_Release(This) (This)->lpVtbl->Release(This)
#define IMSAdminReplication_GetSignature(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetSignature(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize)
#define IMSAdminReplication_Propagate(This,dwBufferSize,pszBuffer) (This)->lpVtbl->Propagate(This,dwBufferSize,pszBuffer)
#define IMSAdminReplication_Propagate2(This,dwBufferSize,pszBuffer,dwSignatureMismatch) (This)->lpVtbl->Propagate2(This,dwBufferSize,pszBuffer,dwSignatureMismatch)
#define IMSAdminReplication_Serialize(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->Serialize(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize)
#define IMSAdminReplication_DeSerialize(This,dwBufferSize,pbBuffer) (This)->lpVtbl->DeSerialize(This,dwBufferSize,pbBuffer)
#endif
#endif

  HRESULT WINAPI IMSAdminReplication_GetSignature_Proxy(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
  void __RPC_STUB IMSAdminReplication_GetSignature_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminReplication_Propagate_Proxy(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pszBuffer);
  void __RPC_STUB IMSAdminReplication_Propagate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminReplication_Propagate2_Proxy(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pszBuffer,DWORD dwSignatureMismatch);
  void __RPC_STUB IMSAdminReplication_Propagate2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminReplication_Serialize_Proxy(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
  void __RPC_STUB IMSAdminReplication_Serialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminReplication_DeSerialize_Proxy(IMSAdminReplication *This,DWORD dwBufferSize,unsigned char *pbBuffer);
  void __RPC_STUB IMSAdminReplication_DeSerialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_admex_0255_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_admex_0255_v0_0_s_ifspec;

#ifndef __IMSAdminCryptoCapabilities_INTERFACE_DEFINED__
#define __IMSAdminCryptoCapabilities_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSAdminCryptoCapabilities;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSAdminCryptoCapabilities : public IUnknown {
  public:
    virtual HRESULT WINAPI GetProtocols(DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
    virtual HRESULT WINAPI GetMaximumCipherStrength(LPDWORD pdwMaximumCipherStrength) = 0;
    virtual HRESULT WINAPI GetRootCertificates(DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
    virtual HRESULT WINAPI GetSupportedAlgs(DWORD dwBufferSize,DWORD *pbBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
    virtual HRESULT WINAPI SetCAList(DWORD dwBufferSize,unsigned char *pbBuffer) = 0;
  };
#else
  typedef struct IMSAdminCryptoCapabilitiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSAdminCryptoCapabilities *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSAdminCryptoCapabilities *This);
      ULONG (WINAPI *Release)(IMSAdminCryptoCapabilities *This);
      HRESULT (WINAPI *GetProtocols)(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *GetMaximumCipherStrength)(IMSAdminCryptoCapabilities *This,LPDWORD pdwMaximumCipherStrength);
      HRESULT (WINAPI *GetRootCertificates)(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *GetSupportedAlgs)(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,DWORD *pbBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *SetCAList)(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,unsigned char *pbBuffer);
    END_INTERFACE
  } IMSAdminCryptoCapabilitiesVtbl;
  struct IMSAdminCryptoCapabilities {
    CONST_VTBL struct IMSAdminCryptoCapabilitiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSAdminCryptoCapabilities_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSAdminCryptoCapabilities_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSAdminCryptoCapabilities_Release(This) (This)->lpVtbl->Release(This)
#define IMSAdminCryptoCapabilities_GetProtocols(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetProtocols(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize)
#define IMSAdminCryptoCapabilities_GetMaximumCipherStrength(This,pdwMaximumCipherStrength) (This)->lpVtbl->GetMaximumCipherStrength(This,pdwMaximumCipherStrength)
#define IMSAdminCryptoCapabilities_GetRootCertificates(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetRootCertificates(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize)
#define IMSAdminCryptoCapabilities_GetSupportedAlgs(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetSupportedAlgs(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize)
#define IMSAdminCryptoCapabilities_SetCAList(This,dwBufferSize,pbBuffer) (This)->lpVtbl->SetCAList(This,dwBufferSize,pbBuffer)
#endif
#endif

  HRESULT WINAPI IMSAdminCryptoCapabilities_GetProtocols_Proxy(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
  void __RPC_STUB IMSAdminCryptoCapabilities_GetProtocols_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminCryptoCapabilities_GetMaximumCipherStrength_Proxy(IMSAdminCryptoCapabilities *This,LPDWORD pdwMaximumCipherStrength);
  void __RPC_STUB IMSAdminCryptoCapabilities_GetMaximumCipherStrength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminCryptoCapabilities_GetRootCertificates_Proxy(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize);
  void __RPC_STUB IMSAdminCryptoCapabilities_GetRootCertificates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminCryptoCapabilities_GetSupportedAlgs_Proxy(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,DWORD *pbBuffer,DWORD *pdwMDRequiredBufferSize);
  void __RPC_STUB IMSAdminCryptoCapabilities_GetSupportedAlgs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminCryptoCapabilities_SetCAList_Proxy(IMSAdminCryptoCapabilities *This,DWORD dwBufferSize,unsigned char *pbBuffer);
  void __RPC_STUB IMSAdminCryptoCapabilities_SetCAList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_admex_0256_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_admex_0256_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
