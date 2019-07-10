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

#ifndef __ctxtcall_h__
#define __ctxtcall_h__

#ifndef __IContextCallback_FWD_DEFINED__
#define __IContextCallback_FWD_DEFINED__
typedef struct IContextCallback IContextCallback;
#endif

#include "wtypes.h"
#include "objidl.h"
#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef struct tagComCallData {
    DWORD dwDispid;
    DWORD dwReserved;
    void *pUserDefined;
  } ComCallData;

  extern RPC_IF_HANDLE __MIDL_itf_ctxtcall_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ctxtcall_0000_v0_0_s_ifspec;

#ifndef __IContextCallback_INTERFACE_DEFINED__
#define __IContextCallback_INTERFACE_DEFINED__
  typedef HRESULT (WINAPI *PFNCONTEXTCALL)(ComCallData *pParam);
  EXTERN_C const IID IID_IContextCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IContextCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI ContextCallback(PFNCONTEXTCALL pfnCallback,ComCallData *pParam,REFIID riid,int iMethod,IUnknown *pUnk) = 0;
  };
#else
  typedef struct IContextCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IContextCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IContextCallback *This);
      ULONG (WINAPI *Release)(IContextCallback *This);
      HRESULT (WINAPI *ContextCallback)(IContextCallback *This,PFNCONTEXTCALL pfnCallback,ComCallData *pParam,REFIID riid,int iMethod,IUnknown *pUnk);
    END_INTERFACE
  } IContextCallbackVtbl;
  struct IContextCallback {
    CONST_VTBL struct IContextCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IContextCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IContextCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IContextCallback_Release(This) (This)->lpVtbl->Release(This)
#define IContextCallback_ContextCallback(This,pfnCallback,pParam,riid,iMethod,pUnk) (This)->lpVtbl->ContextCallback(This,pfnCallback,pParam,riid,iMethod,pUnk)
#endif
#endif
  HRESULT WINAPI IContextCallback_ContextCallback_Proxy(IContextCallback *This,PFNCONTEXTCALL pfnCallback,ComCallData *pParam,REFIID riid,int iMethod,IUnknown *pUnk);
  void __RPC_STUB IContextCallback_ContextCallback_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
