/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef I_SIMPDC_H_
#define I_SIMPDC_H_

#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __ISimpleDataConverter_FWD_DEFINED__
#define __ISimpleDataConverter_FWD_DEFINED__
  typedef struct ISimpleDataConverter ISimpleDataConverter;
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __ISimpleDataConverter_INTERFACE_DEFINED__
#define __ISimpleDataConverter_INTERFACE_DEFINED__
  DEFINE_GUID(IID_ISimpleDataConverter,0x78667670,0x3C3D,0x11d2,0x91,0xF9,0x00,0x60,0x97,0xC9,0x7F,0x9B);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISimpleDataConverter : public IUnknown {
  public:
    virtual HRESULT WINAPI ConvertData(VARIANT varSrc,__LONG32 vtDest,IUnknown *pUnknownElement,VARIANT *pvarDest) = 0;
    virtual HRESULT WINAPI CanConvertData(__LONG32 vt1,__LONG32 vt2) = 0;
  };
#else
  typedef struct ISimpleDataConverterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISimpleDataConverter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISimpleDataConverter *This);
      ULONG (WINAPI *Release)(ISimpleDataConverter *This);
      HRESULT (WINAPI *ConvertData)(ISimpleDataConverter *This,VARIANT varSrc,__LONG32 vtDest,IUnknown *pUnknownElement,VARIANT *pvarDest);
      HRESULT (WINAPI *CanConvertData)(ISimpleDataConverter *This,__LONG32 vt1,__LONG32 vt2);
    END_INTERFACE
  } ISimpleDataConverterVtbl;
  struct ISimpleDataConverter {
    CONST_VTBL struct ISimpleDataConverterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISimpleDataConverter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISimpleDataConverter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISimpleDataConverter_Release(This) (This)->lpVtbl->Release(This)
#define ISimpleDataConverter_ConvertData(This,varSrc,vtDest,pUnknownElement,pvarDest) (This)->lpVtbl->ConvertData(This,varSrc,vtDest,pUnknownElement,pvarDest)
#define ISimpleDataConverter_CanConvertData(This,vt1,vt2) (This)->lpVtbl->CanConvertData(This,vt1,vt2)
#endif
#endif
  HRESULT WINAPI ISimpleDataConverter_ConvertData_Proxy(ISimpleDataConverter *This,VARIANT varSrc,__LONG32 vtDest,IUnknown *pUnknownElement,VARIANT *pvarDest);
  void __RPC_STUB ISimpleDataConverter_ConvertData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISimpleDataConverter_CanConvertData_Proxy(ISimpleDataConverter *This,__LONG32 vt1,__LONG32 vt2);
  void __RPC_STUB ISimpleDataConverter_CanConvertData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
