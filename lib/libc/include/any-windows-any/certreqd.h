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

#ifndef __certreqd_h__
#define __certreqd_h__

#ifndef __ICertRequestD_FWD_DEFINED__
#define __ICertRequestD_FWD_DEFINED__
typedef struct ICertRequestD ICertRequestD;
#endif

#ifndef __ICertRequestD2_FWD_DEFINED__
#define __ICertRequestD2_FWD_DEFINED__
typedef struct ICertRequestD2 ICertRequestD2;
#endif

#include "certbase.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __ICertRequestD_INTERFACE_DEFINED__
#define __ICertRequestD_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertRequestD;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertRequestD : public IUnknown {
  public:
    virtual HRESULT WINAPI Request(DWORD dwFlags,const wchar_t *pwszAuthority,DWORD *pdwRequestId,DWORD *pdwDisposition,const wchar_t *pwszAttributes,const CERTTRANSBLOB *pctbRequest,CERTTRANSBLOB *pctbCertChain,CERTTRANSBLOB *pctbEncodedCert,CERTTRANSBLOB *pctbDispositionMessage) = 0;
    virtual HRESULT WINAPI GetCACert(DWORD fchain,const wchar_t *pwszAuthority,CERTTRANSBLOB *pctbOut) = 0;
    virtual HRESULT WINAPI Ping(const wchar_t *pwszAuthority) = 0;
  };
#else
  typedef struct ICertRequestDVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertRequestD *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertRequestD *This);
      ULONG (WINAPI *Release)(ICertRequestD *This);
      HRESULT (WINAPI *Request)(ICertRequestD *This,DWORD dwFlags,const wchar_t *pwszAuthority,DWORD *pdwRequestId,DWORD *pdwDisposition,const wchar_t *pwszAttributes,const CERTTRANSBLOB *pctbRequest,CERTTRANSBLOB *pctbCertChain,CERTTRANSBLOB *pctbEncodedCert,CERTTRANSBLOB *pctbDispositionMessage);
      HRESULT (WINAPI *GetCACert)(ICertRequestD *This,DWORD fchain,const wchar_t *pwszAuthority,CERTTRANSBLOB *pctbOut);
      HRESULT (WINAPI *Ping)(ICertRequestD *This,const wchar_t *pwszAuthority);
    END_INTERFACE
  } ICertRequestDVtbl;
  struct ICertRequestD {
    CONST_VTBL struct ICertRequestDVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertRequestD_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertRequestD_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertRequestD_Release(This) (This)->lpVtbl->Release(This)
#define ICertRequestD_Request(This,dwFlags,pwszAuthority,pdwRequestId,pdwDisposition,pwszAttributes,pctbRequest,pctbCertChain,pctbEncodedCert,pctbDispositionMessage) (This)->lpVtbl->Request(This,dwFlags,pwszAuthority,pdwRequestId,pdwDisposition,pwszAttributes,pctbRequest,pctbCertChain,pctbEncodedCert,pctbDispositionMessage)
#define ICertRequestD_GetCACert(This,fchain,pwszAuthority,pctbOut) (This)->lpVtbl->GetCACert(This,fchain,pwszAuthority,pctbOut)
#define ICertRequestD_Ping(This,pwszAuthority) (This)->lpVtbl->Ping(This,pwszAuthority)
#endif
#endif
  HRESULT WINAPI ICertRequestD_Request_Proxy(ICertRequestD *This,DWORD dwFlags,const wchar_t *pwszAuthority,DWORD *pdwRequestId,DWORD *pdwDisposition,const wchar_t *pwszAttributes,const CERTTRANSBLOB *pctbRequest,CERTTRANSBLOB *pctbCertChain,CERTTRANSBLOB *pctbEncodedCert,CERTTRANSBLOB *pctbDispositionMessage);
  void __RPC_STUB ICertRequestD_Request_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequestD_GetCACert_Proxy(ICertRequestD *This,DWORD fchain,const wchar_t *pwszAuthority,CERTTRANSBLOB *pctbOut);
  void __RPC_STUB ICertRequestD_GetCACert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequestD_Ping_Proxy(ICertRequestD *This,const wchar_t *pwszAuthority);
  void __RPC_STUB ICertRequestD_Ping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertRequestD2_INTERFACE_DEFINED__
#define __ICertRequestD2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertRequestD2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertRequestD2 : public ICertRequestD {
  public:
    virtual HRESULT WINAPI Request2(const wchar_t *pwszAuthority,DWORD dwFlags,const wchar_t *pwszSerialNumber,DWORD *pdwRequestId,DWORD *pdwDisposition,const wchar_t *pwszAttributes,const CERTTRANSBLOB *pctbRequest,CERTTRANSBLOB *pctbFullResponse,CERTTRANSBLOB *pctbEncodedCert,CERTTRANSBLOB *pctbDispositionMessage) = 0;
    virtual HRESULT WINAPI GetCAProperty(const wchar_t *pwszAuthority,LONG PropId,LONG PropIndex,LONG PropType,CERTTRANSBLOB *pctbPropertyValue) = 0;
    virtual HRESULT WINAPI GetCAPropertyInfo(const wchar_t *pwszAuthority,LONG *pcProperty,CERTTRANSBLOB *pctbPropInfo) = 0;
    virtual HRESULT WINAPI Ping2(const wchar_t *pwszAuthority) = 0;
  };
#else
  typedef struct ICertRequestD2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertRequestD2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertRequestD2 *This);
      ULONG (WINAPI *Release)(ICertRequestD2 *This);
      HRESULT (WINAPI *Request)(ICertRequestD2 *This,DWORD dwFlags,const wchar_t *pwszAuthority,DWORD *pdwRequestId,DWORD *pdwDisposition,const wchar_t *pwszAttributes,const CERTTRANSBLOB *pctbRequest,CERTTRANSBLOB *pctbCertChain,CERTTRANSBLOB *pctbEncodedCert,CERTTRANSBLOB *pctbDispositionMessage);
      HRESULT (WINAPI *GetCACert)(ICertRequestD2 *This,DWORD fchain,const wchar_t *pwszAuthority,CERTTRANSBLOB *pctbOut);
      HRESULT (WINAPI *Ping)(ICertRequestD2 *This,const wchar_t *pwszAuthority);
      HRESULT (WINAPI *Request2)(ICertRequestD2 *This,const wchar_t *pwszAuthority,DWORD dwFlags,const wchar_t *pwszSerialNumber,DWORD *pdwRequestId,DWORD *pdwDisposition,const wchar_t *pwszAttributes,const CERTTRANSBLOB *pctbRequest,CERTTRANSBLOB *pctbFullResponse,CERTTRANSBLOB *pctbEncodedCert,CERTTRANSBLOB *pctbDispositionMessage);
      HRESULT (WINAPI *GetCAProperty)(ICertRequestD2 *This,const wchar_t *pwszAuthority,LONG PropId,LONG PropIndex,LONG PropType,CERTTRANSBLOB *pctbPropertyValue);
      HRESULT (WINAPI *GetCAPropertyInfo)(ICertRequestD2 *This,const wchar_t *pwszAuthority,LONG *pcProperty,CERTTRANSBLOB *pctbPropInfo);
      HRESULT (WINAPI *Ping2)(ICertRequestD2 *This,const wchar_t *pwszAuthority);
    END_INTERFACE
  } ICertRequestD2Vtbl;
  struct ICertRequestD2 {
    CONST_VTBL struct ICertRequestD2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertRequestD2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertRequestD2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertRequestD2_Release(This) (This)->lpVtbl->Release(This)
#define ICertRequestD2_Request(This,dwFlags,pwszAuthority,pdwRequestId,pdwDisposition,pwszAttributes,pctbRequest,pctbCertChain,pctbEncodedCert,pctbDispositionMessage) (This)->lpVtbl->Request(This,dwFlags,pwszAuthority,pdwRequestId,pdwDisposition,pwszAttributes,pctbRequest,pctbCertChain,pctbEncodedCert,pctbDispositionMessage)
#define ICertRequestD2_GetCACert(This,fchain,pwszAuthority,pctbOut) (This)->lpVtbl->GetCACert(This,fchain,pwszAuthority,pctbOut)
#define ICertRequestD2_Ping(This,pwszAuthority) (This)->lpVtbl->Ping(This,pwszAuthority)
#define ICertRequestD2_Request2(This,pwszAuthority,dwFlags,pwszSerialNumber,pdwRequestId,pdwDisposition,pwszAttributes,pctbRequest,pctbFullResponse,pctbEncodedCert,pctbDispositionMessage) (This)->lpVtbl->Request2(This,pwszAuthority,dwFlags,pwszSerialNumber,pdwRequestId,pdwDisposition,pwszAttributes,pctbRequest,pctbFullResponse,pctbEncodedCert,pctbDispositionMessage)
#define ICertRequestD2_GetCAProperty(This,pwszAuthority,PropId,PropIndex,PropType,pctbPropertyValue) (This)->lpVtbl->GetCAProperty(This,pwszAuthority,PropId,PropIndex,PropType,pctbPropertyValue)
#define ICertRequestD2_GetCAPropertyInfo(This,pwszAuthority,pcProperty,pctbPropInfo) (This)->lpVtbl->GetCAPropertyInfo(This,pwszAuthority,pcProperty,pctbPropInfo)
#define ICertRequestD2_Ping2(This,pwszAuthority) (This)->lpVtbl->Ping2(This,pwszAuthority)
#endif
#endif
  HRESULT WINAPI ICertRequestD2_Request2_Proxy(ICertRequestD2 *This,const wchar_t *pwszAuthority,DWORD dwFlags,const wchar_t *pwszSerialNumber,DWORD *pdwRequestId,DWORD *pdwDisposition,const wchar_t *pwszAttributes,const CERTTRANSBLOB *pctbRequest,CERTTRANSBLOB *pctbFullResponse,CERTTRANSBLOB *pctbEncodedCert,CERTTRANSBLOB *pctbDispositionMessage);
  void __RPC_STUB ICertRequestD2_Request2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequestD2_GetCAProperty_Proxy(ICertRequestD2 *This,const wchar_t *pwszAuthority,LONG PropId,LONG PropIndex,LONG PropType,CERTTRANSBLOB *pctbPropertyValue);
  void __RPC_STUB ICertRequestD2_GetCAProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequestD2_GetCAPropertyInfo_Proxy(ICertRequestD2 *This,const wchar_t *pwszAuthority,LONG *pcProperty,CERTTRANSBLOB *pctbPropInfo);
  void __RPC_STUB ICertRequestD2_GetCAPropertyInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequestD2_Ping2_Proxy(ICertRequestD2 *This,const wchar_t *pwszAuthority);
  void __RPC_STUB ICertRequestD2_Ping2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
