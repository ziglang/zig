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
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __iisrsta_h__
#define __iisrsta_h__

#ifndef __IIisServiceControl_FWD_DEFINED__
#define __IIisServiceControl_FWD_DEFINED__
typedef struct IIisServiceControl IIisServiceControl;
#endif

#ifndef __IisServiceControl_FWD_DEFINED__
#define __IisServiceControl_FWD_DEFINED__
#ifdef __cplusplus
typedef class IisServiceControl IisServiceControl;
#else
typedef struct IisServiceControl IisServiceControl;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  DEFINE_GUID(IID_IIisServiceControl,0xE8FB8620,0x588F,0x11d2,0x9d,0x61,0x0,0xc0,0x4f,0x79,0xc5,0xfe);
  DEFINE_GUID(CLSID_IisServiceControl,0xE8FB8621,0x588F,0x11d2,0x9d,0x61,0x0,0xc0,0x4f,0x79,0xc5,0xfe);
  DEFINE_GUID(LIBID_IISRSTALib,0xE8FB8614,0x588F,0x11d2,0x9d,0x61,0x0,0xc0,0x4f,0x79,0xc5,0xfe);

  extern RPC_IF_HANDLE __MIDL_itf_iisrsta_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iisrsta_0000_v0_0_s_ifspec;

#ifndef __IIisServiceControl_INTERFACE_DEFINED__
#define __IIisServiceControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIisServiceControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIisServiceControl : public IDispatch {
  public:
    virtual HRESULT WINAPI Stop(DWORD dwTimeoutMsecs,DWORD dwForce) = 0;
    virtual HRESULT WINAPI Start(DWORD dwTimeoutMsecs) = 0;
    virtual HRESULT WINAPI Reboot(DWORD dwTimeouMsecs,DWORD dwForceAppsClosed) = 0;
    virtual HRESULT WINAPI Status(DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize,DWORD *pdwNumServices) = 0;
    virtual HRESULT WINAPI Kill(void) = 0;
  };
#else
  typedef struct IIisServiceControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIisServiceControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIisServiceControl *This);
      ULONG (WINAPI *Release)(IIisServiceControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIisServiceControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIisServiceControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIisServiceControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIisServiceControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Stop)(IIisServiceControl *This,DWORD dwTimeoutMsecs,DWORD dwForce);
      HRESULT (WINAPI *Start)(IIisServiceControl *This,DWORD dwTimeoutMsecs);
      HRESULT (WINAPI *Reboot)(IIisServiceControl *This,DWORD dwTimeouMsecs,DWORD dwForceAppsClosed);
      HRESULT (WINAPI *Status)(IIisServiceControl *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize,DWORD *pdwNumServices);
      HRESULT (WINAPI *Kill)(IIisServiceControl *This);
    END_INTERFACE
  } IIisServiceControlVtbl;
  struct IIisServiceControl {
    CONST_VTBL struct IIisServiceControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIisServiceControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIisServiceControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIisServiceControl_Release(This) (This)->lpVtbl->Release(This)
#define IIisServiceControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIisServiceControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIisServiceControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIisServiceControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIisServiceControl_Stop(This,dwTimeoutMsecs,dwForce) (This)->lpVtbl->Stop(This,dwTimeoutMsecs,dwForce)
#define IIisServiceControl_Start(This,dwTimeoutMsecs) (This)->lpVtbl->Start(This,dwTimeoutMsecs)
#define IIisServiceControl_Reboot(This,dwTimeouMsecs,dwForceAppsClosed) (This)->lpVtbl->Reboot(This,dwTimeouMsecs,dwForceAppsClosed)
#define IIisServiceControl_Status(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize,pdwNumServices) (This)->lpVtbl->Status(This,dwBufferSize,pbBuffer,pdwMDRequiredBufferSize,pdwNumServices)
#define IIisServiceControl_Kill(This) (This)->lpVtbl->Kill(This)
#endif
#endif
  HRESULT WINAPI IIisServiceControl_Stop_Proxy(IIisServiceControl *This,DWORD dwTimeoutMsecs,DWORD dwForce);
  void __RPC_STUB IIisServiceControl_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIisServiceControl_Start_Proxy(IIisServiceControl *This,DWORD dwTimeoutMsecs);
  void __RPC_STUB IIisServiceControl_Start_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIisServiceControl_Reboot_Proxy(IIisServiceControl *This,DWORD dwTimeouMsecs,DWORD dwForceAppsClosed);
  void __RPC_STUB IIisServiceControl_Reboot_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIisServiceControl_Status_Proxy(IIisServiceControl *This,DWORD dwBufferSize,unsigned char *pbBuffer,DWORD *pdwMDRequiredBufferSize,DWORD *pdwNumServices);
  void __RPC_STUB IIisServiceControl_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIisServiceControl_Kill_Proxy(IIisServiceControl *This);
  void __RPC_STUB IIisServiceControl_Kill_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISRSTALib_LIBRARY_DEFINED__
#define __IISRSTALib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_IISRSTALib;
  EXTERN_C const CLSID CLSID_IisServiceControl;
#ifdef __cplusplus
  class IisServiceControl;
#endif
#endif

  typedef struct {
    DWORD iServiceName;
    DWORD iDisplayName;
    SERVICE_STATUS ServiceStatus;
  } SERIALIZED_ENUM_SERVICE_STATUS;

  extern RPC_IF_HANDLE __MIDL_itf_iisrsta_0262_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iisrsta_0262_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
