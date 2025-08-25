/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
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

#ifndef __perhist_h__
#define __perhist_h__

#ifndef __IPersistHistory_FWD_DEFINED__
#define __IPersistHistory_FWD_DEFINED__
typedef struct IPersistHistory IPersistHistory;
#endif

#include "objidl.h"
#include "oleidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _LPPERSISTHISTORY_DEFINED
#define _LPPERSISTHISTORY_DEFINED

  extern RPC_IF_HANDLE __MIDL_itf_perhist_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_perhist_0000_v0_0_s_ifspec;

#ifndef __IPersistHistory_INTERFACE_DEFINED__
#define __IPersistHistory_INTERFACE_DEFINED__
  typedef IPersistHistory *LPPERSISTHISTORY;

  EXTERN_C const IID IID_IPersistHistory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPersistHistory : public IPersist {
  public:
    virtual HRESULT WINAPI LoadHistory(IStream *pStream,IBindCtx *pbc) = 0;
    virtual HRESULT WINAPI SaveHistory(IStream *pStream) = 0;
    virtual HRESULT WINAPI SetPositionCookie(DWORD dwPositioncookie) = 0;
    virtual HRESULT WINAPI GetPositionCookie(DWORD *pdwPositioncookie) = 0;
  };
#else
  typedef struct IPersistHistoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPersistHistory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPersistHistory *This);
      ULONG (WINAPI *Release)(IPersistHistory *This);
      HRESULT (WINAPI *GetClassID)(IPersistHistory *This,CLSID *pClassID);
      HRESULT (WINAPI *LoadHistory)(IPersistHistory *This,IStream *pStream,IBindCtx *pbc);
      HRESULT (WINAPI *SaveHistory)(IPersistHistory *This,IStream *pStream);
      HRESULT (WINAPI *SetPositionCookie)(IPersistHistory *This,DWORD dwPositioncookie);
      HRESULT (WINAPI *GetPositionCookie)(IPersistHistory *This,DWORD *pdwPositioncookie);
    END_INTERFACE
  } IPersistHistoryVtbl;
  struct IPersistHistory {
    CONST_VTBL struct IPersistHistoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPersistHistory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPersistHistory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPersistHistory_Release(This) (This)->lpVtbl->Release(This)
#define IPersistHistory_GetClassID(This,pClassID) (This)->lpVtbl->GetClassID(This,pClassID)
#define IPersistHistory_LoadHistory(This,pStream,pbc) (This)->lpVtbl->LoadHistory(This,pStream,pbc)
#define IPersistHistory_SaveHistory(This,pStream) (This)->lpVtbl->SaveHistory(This,pStream)
#define IPersistHistory_SetPositionCookie(This,dwPositioncookie) (This)->lpVtbl->SetPositionCookie(This,dwPositioncookie)
#define IPersistHistory_GetPositionCookie(This,pdwPositioncookie) (This)->lpVtbl->GetPositionCookie(This,pdwPositioncookie)
#endif
#endif
  HRESULT WINAPI IPersistHistory_LoadHistory_Proxy(IPersistHistory *This,IStream *pStream,IBindCtx *pbc);
  void __RPC_STUB IPersistHistory_LoadHistory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPersistHistory_SaveHistory_Proxy(IPersistHistory *This,IStream *pStream);
  void __RPC_STUB IPersistHistory_SaveHistory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPersistHistory_SetPositionCookie_Proxy(IPersistHistory *This,DWORD dwPositioncookie);
  void __RPC_STUB IPersistHistory_SetPositionCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPersistHistory_GetPositionCookie_Proxy(IPersistHistory *This,DWORD *pdwPositioncookie);
  void __RPC_STUB IPersistHistory_GetPositionCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_perhist_0118_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_perhist_0118_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
