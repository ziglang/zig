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

#ifndef __htiface_h__
#define __htiface_h__

#ifndef __ITargetFrame_FWD_DEFINED__
#define __ITargetFrame_FWD_DEFINED__
typedef struct ITargetFrame ITargetFrame;
#endif

#ifndef __ITargetEmbedding_FWD_DEFINED__
#define __ITargetEmbedding_FWD_DEFINED__
typedef struct ITargetEmbedding ITargetEmbedding;
#endif

#ifndef __ITargetFramePriv_FWD_DEFINED__
#define __ITargetFramePriv_FWD_DEFINED__
typedef struct ITargetFramePriv ITargetFramePriv;
#endif

#include "objidl.h"
#include "oleidl.h"
#include "urlmon.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _LPTARGETFRAME2_DEFINED
#include "htiframe.h"
#endif

  EXTERN_C const IID IID_ITargetFrame;
  EXTERN_C const IID IID_ITargetEmbedding;
  EXTERN_C const IID IID_ITargetFramePriv;
#ifndef _LPTARGETFRAME_DEFINED
#define _LPTARGETFRAME_DEFINED

  extern RPC_IF_HANDLE __MIDL_itf_htiface_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_htiface_0000_v0_0_s_ifspec;

#ifndef __ITargetFrame_INTERFACE_DEFINED__
#define __ITargetFrame_INTERFACE_DEFINED__
  typedef ITargetFrame *LPTARGETFRAME;

  typedef enum __MIDL_ITargetFrame_0001 {
    NAVIGATEFRAME_FL_RECORD = 0x1,NAVIGATEFRAME_FL_POST = 0x2,NAVIGATEFRAME_FL_NO_DOC_CACHE = 0x4,NAVIGATEFRAME_FL_NO_IMAGE_CACHE = 0x8,
    NAVIGATEFRAME_FL_AUTH_FAIL_CACHE_OK = 0x10,NAVIGATEFRAME_FL_SENDING_FROM_FORM = 0x20,NAVIGATEFRAME_FL_REALLY_SENDING_FROM_FORM = 0x40
  } NAVIGATEFRAME_FLAGS;

  typedef struct tagNavigateData {
    ULONG ulTarget;
    ULONG ulURL;
    ULONG ulRefURL;
    ULONG ulPostData;
    DWORD dwFlags;
  } NAVIGATEDATA;

  EXTERN_C const IID IID_ITargetFrame;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITargetFrame : public IUnknown {
  public:
    virtual HRESULT WINAPI SetFrameName(LPCWSTR pszFrameName) = 0;
    virtual HRESULT WINAPI GetFrameName(LPWSTR *ppszFrameName) = 0;
    virtual HRESULT WINAPI GetParentFrame(IUnknown **ppunkParent) = 0;
    virtual HRESULT WINAPI FindFrame(LPCWSTR pszTargetName,IUnknown *ppunkContextFrame,DWORD dwFlags,IUnknown **ppunkTargetFrame) = 0;
    virtual HRESULT WINAPI SetFrameSrc(LPCWSTR pszFrameSrc) = 0;
    virtual HRESULT WINAPI GetFrameSrc(LPWSTR *ppszFrameSrc) = 0;
    virtual HRESULT WINAPI GetFramesContainer(IOleContainer **ppContainer) = 0;
    virtual HRESULT WINAPI SetFrameOptions(DWORD dwFlags) = 0;
    virtual HRESULT WINAPI GetFrameOptions(DWORD *pdwFlags) = 0;
    virtual HRESULT WINAPI SetFrameMargins(DWORD dwWidth,DWORD dwHeight) = 0;
    virtual HRESULT WINAPI GetFrameMargins(DWORD *pdwWidth,DWORD *pdwHeight) = 0;
    virtual HRESULT WINAPI RemoteNavigate(ULONG cLength,ULONG *pulData) = 0;
    virtual HRESULT WINAPI OnChildFrameActivate(IUnknown *pUnkChildFrame) = 0;
    virtual HRESULT WINAPI OnChildFrameDeactivate(IUnknown *pUnkChildFrame) = 0;
  };
#else
  typedef struct ITargetFrameVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITargetFrame *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITargetFrame *This);
      ULONG (WINAPI *Release)(ITargetFrame *This);
      HRESULT (WINAPI *SetFrameName)(ITargetFrame *This,LPCWSTR pszFrameName);
      HRESULT (WINAPI *GetFrameName)(ITargetFrame *This,LPWSTR *ppszFrameName);
      HRESULT (WINAPI *GetParentFrame)(ITargetFrame *This,IUnknown **ppunkParent);
      HRESULT (WINAPI *FindFrame)(ITargetFrame *This,LPCWSTR pszTargetName,IUnknown *ppunkContextFrame,DWORD dwFlags,IUnknown **ppunkTargetFrame);
      HRESULT (WINAPI *SetFrameSrc)(ITargetFrame *This,LPCWSTR pszFrameSrc);
      HRESULT (WINAPI *GetFrameSrc)(ITargetFrame *This,LPWSTR *ppszFrameSrc);
      HRESULT (WINAPI *GetFramesContainer)(ITargetFrame *This,IOleContainer **ppContainer);
      HRESULT (WINAPI *SetFrameOptions)(ITargetFrame *This,DWORD dwFlags);
      HRESULT (WINAPI *GetFrameOptions)(ITargetFrame *This,DWORD *pdwFlags);
      HRESULT (WINAPI *SetFrameMargins)(ITargetFrame *This,DWORD dwWidth,DWORD dwHeight);
      HRESULT (WINAPI *GetFrameMargins)(ITargetFrame *This,DWORD *pdwWidth,DWORD *pdwHeight);
      HRESULT (WINAPI *RemoteNavigate)(ITargetFrame *This,ULONG cLength,ULONG *pulData);
      HRESULT (WINAPI *OnChildFrameActivate)(ITargetFrame *This,IUnknown *pUnkChildFrame);
      HRESULT (WINAPI *OnChildFrameDeactivate)(ITargetFrame *This,IUnknown *pUnkChildFrame);
    END_INTERFACE
  } ITargetFrameVtbl;
  struct ITargetFrame {
    CONST_VTBL struct ITargetFrameVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITargetFrame_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITargetFrame_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITargetFrame_Release(This) (This)->lpVtbl->Release(This)
#define ITargetFrame_SetFrameName(This,pszFrameName) (This)->lpVtbl->SetFrameName(This,pszFrameName)
#define ITargetFrame_GetFrameName(This,ppszFrameName) (This)->lpVtbl->GetFrameName(This,ppszFrameName)
#define ITargetFrame_GetParentFrame(This,ppunkParent) (This)->lpVtbl->GetParentFrame(This,ppunkParent)
#define ITargetFrame_FindFrame(This,pszTargetName,ppunkContextFrame,dwFlags,ppunkTargetFrame) (This)->lpVtbl->FindFrame(This,pszTargetName,ppunkContextFrame,dwFlags,ppunkTargetFrame)
#define ITargetFrame_SetFrameSrc(This,pszFrameSrc) (This)->lpVtbl->SetFrameSrc(This,pszFrameSrc)
#define ITargetFrame_GetFrameSrc(This,ppszFrameSrc) (This)->lpVtbl->GetFrameSrc(This,ppszFrameSrc)
#define ITargetFrame_GetFramesContainer(This,ppContainer) (This)->lpVtbl->GetFramesContainer(This,ppContainer)
#define ITargetFrame_SetFrameOptions(This,dwFlags) (This)->lpVtbl->SetFrameOptions(This,dwFlags)
#define ITargetFrame_GetFrameOptions(This,pdwFlags) (This)->lpVtbl->GetFrameOptions(This,pdwFlags)
#define ITargetFrame_SetFrameMargins(This,dwWidth,dwHeight) (This)->lpVtbl->SetFrameMargins(This,dwWidth,dwHeight)
#define ITargetFrame_GetFrameMargins(This,pdwWidth,pdwHeight) (This)->lpVtbl->GetFrameMargins(This,pdwWidth,pdwHeight)
#define ITargetFrame_RemoteNavigate(This,cLength,pulData) (This)->lpVtbl->RemoteNavigate(This,cLength,pulData)
#define ITargetFrame_OnChildFrameActivate(This,pUnkChildFrame) (This)->lpVtbl->OnChildFrameActivate(This,pUnkChildFrame)
#define ITargetFrame_OnChildFrameDeactivate(This,pUnkChildFrame) (This)->lpVtbl->OnChildFrameDeactivate(This,pUnkChildFrame)
#endif
#endif
  HRESULT WINAPI ITargetFrame_SetFrameName_Proxy(ITargetFrame *This,LPCWSTR pszFrameName);
  void __RPC_STUB ITargetFrame_SetFrameName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_GetFrameName_Proxy(ITargetFrame *This,LPWSTR *ppszFrameName);
  void __RPC_STUB ITargetFrame_GetFrameName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_GetParentFrame_Proxy(ITargetFrame *This,IUnknown **ppunkParent);
  void __RPC_STUB ITargetFrame_GetParentFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_FindFrame_Proxy(ITargetFrame *This,LPCWSTR pszTargetName,IUnknown *ppunkContextFrame,DWORD dwFlags,IUnknown **ppunkTargetFrame);
  void __RPC_STUB ITargetFrame_FindFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_SetFrameSrc_Proxy(ITargetFrame *This,LPCWSTR pszFrameSrc);
  void __RPC_STUB ITargetFrame_SetFrameSrc_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_GetFrameSrc_Proxy(ITargetFrame *This,LPWSTR *ppszFrameSrc);
  void __RPC_STUB ITargetFrame_GetFrameSrc_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_GetFramesContainer_Proxy(ITargetFrame *This,IOleContainer **ppContainer);
  void __RPC_STUB ITargetFrame_GetFramesContainer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_SetFrameOptions_Proxy(ITargetFrame *This,DWORD dwFlags);
  void __RPC_STUB ITargetFrame_SetFrameOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_GetFrameOptions_Proxy(ITargetFrame *This,DWORD *pdwFlags);
  void __RPC_STUB ITargetFrame_GetFrameOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_SetFrameMargins_Proxy(ITargetFrame *This,DWORD dwWidth,DWORD dwHeight);
  void __RPC_STUB ITargetFrame_SetFrameMargins_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_GetFrameMargins_Proxy(ITargetFrame *This,DWORD *pdwWidth,DWORD *pdwHeight);
  void __RPC_STUB ITargetFrame_GetFrameMargins_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_RemoteNavigate_Proxy(ITargetFrame *This,ULONG cLength,ULONG *pulData);
  void __RPC_STUB ITargetFrame_RemoteNavigate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_OnChildFrameActivate_Proxy(ITargetFrame *This,IUnknown *pUnkChildFrame);
  void __RPC_STUB ITargetFrame_OnChildFrameActivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame_OnChildFrameDeactivate_Proxy(ITargetFrame *This,IUnknown *pUnkChildFrame);
  void __RPC_STUB ITargetFrame_OnChildFrameDeactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITargetEmbedding_INTERFACE_DEFINED__
#define __ITargetEmbedding_INTERFACE_DEFINED__
  typedef ITargetEmbedding *LPTARGETEMBEDDING;

  EXTERN_C const IID IID_ITargetEmbedding;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITargetEmbedding : public IUnknown {
  public:
    virtual HRESULT WINAPI GetTargetFrame(ITargetFrame **ppTargetFrame) = 0;
  };
#else
  typedef struct ITargetEmbeddingVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITargetEmbedding *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITargetEmbedding *This);
      ULONG (WINAPI *Release)(ITargetEmbedding *This);
      HRESULT (WINAPI *GetTargetFrame)(ITargetEmbedding *This,ITargetFrame **ppTargetFrame);
    END_INTERFACE
  } ITargetEmbeddingVtbl;
  struct ITargetEmbedding {
    CONST_VTBL struct ITargetEmbeddingVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITargetEmbedding_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITargetEmbedding_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITargetEmbedding_Release(This) (This)->lpVtbl->Release(This)
#define ITargetEmbedding_GetTargetFrame(This,ppTargetFrame) (This)->lpVtbl->GetTargetFrame(This,ppTargetFrame)
#endif
#endif
  HRESULT WINAPI ITargetEmbedding_GetTargetFrame_Proxy(ITargetEmbedding *This,ITargetFrame **ppTargetFrame);
  void __RPC_STUB ITargetEmbedding_GetTargetFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITargetFramePriv_INTERFACE_DEFINED__
#define __ITargetFramePriv_INTERFACE_DEFINED__
  typedef ITargetFramePriv *LPTARGETFRAMEPRIV;

  EXTERN_C const IID IID_ITargetFramePriv;
#if defined(__cplusplus) && !defined(CINTERFACE)

  struct ITargetFramePriv : public IUnknown {
  public:
    virtual HRESULT WINAPI FindFrameDownwards(LPCWSTR pszTargetName,DWORD dwFlags,IUnknown **ppunkTargetFrame) = 0;
    virtual HRESULT WINAPI FindFrameInContext(LPCWSTR pszTargetName,IUnknown *punkContextFrame,DWORD dwFlags,IUnknown **ppunkTargetFrame) = 0;
    virtual HRESULT WINAPI OnChildFrameActivate(IUnknown *pUnkChildFrame) = 0;
    virtual HRESULT WINAPI OnChildFrameDeactivate(IUnknown *pUnkChildFrame) = 0;
    virtual HRESULT WINAPI NavigateHack(DWORD grfHLNF,LPBC pbc,IBindStatusCallback *pibsc,LPCWSTR pszTargetName,LPCWSTR pszUrl,LPCWSTR pszLocation) = 0;
    virtual HRESULT WINAPI FindBrowserByIndex(DWORD dwID,IUnknown **ppunkBrowser) = 0;
  };
#else
  typedef struct ITargetFramePrivVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITargetFramePriv *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITargetFramePriv *This);
      ULONG (WINAPI *Release)(ITargetFramePriv *This);
      HRESULT (WINAPI *FindFrameDownwards)(ITargetFramePriv *This,LPCWSTR pszTargetName,DWORD dwFlags,IUnknown **ppunkTargetFrame);
      HRESULT (WINAPI *FindFrameInContext)(ITargetFramePriv *This,LPCWSTR pszTargetName,IUnknown *punkContextFrame,DWORD dwFlags,IUnknown **ppunkTargetFrame);
      HRESULT (WINAPI *OnChildFrameActivate)(ITargetFramePriv *This,IUnknown *pUnkChildFrame);
      HRESULT (WINAPI *OnChildFrameDeactivate)(ITargetFramePriv *This,IUnknown *pUnkChildFrame);
      HRESULT (WINAPI *NavigateHack)(ITargetFramePriv *This,DWORD grfHLNF,LPBC pbc,IBindStatusCallback *pibsc,LPCWSTR pszTargetName,LPCWSTR pszUrl,LPCWSTR pszLocation);
      HRESULT (WINAPI *FindBrowserByIndex)(ITargetFramePriv *This,DWORD dwID,IUnknown **ppunkBrowser);
    END_INTERFACE
  } ITargetFramePrivVtbl;
  struct ITargetFramePriv {
    CONST_VTBL struct ITargetFramePrivVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITargetFramePriv_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITargetFramePriv_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITargetFramePriv_Release(This) (This)->lpVtbl->Release(This)
#define ITargetFramePriv_FindFrameDownwards(This,pszTargetName,dwFlags,ppunkTargetFrame) (This)->lpVtbl->FindFrameDownwards(This,pszTargetName,dwFlags,ppunkTargetFrame)
#define ITargetFramePriv_FindFrameInContext(This,pszTargetName,punkContextFrame,dwFlags,ppunkTargetFrame) (This)->lpVtbl->FindFrameInContext(This,pszTargetName,punkContextFrame,dwFlags,ppunkTargetFrame)
#define ITargetFramePriv_OnChildFrameActivate(This,pUnkChildFrame) (This)->lpVtbl->OnChildFrameActivate(This,pUnkChildFrame)
#define ITargetFramePriv_OnChildFrameDeactivate(This,pUnkChildFrame) (This)->lpVtbl->OnChildFrameDeactivate(This,pUnkChildFrame)
#define ITargetFramePriv_NavigateHack(This,grfHLNF,pbc,pibsc,pszTargetName,pszUrl,pszLocation) (This)->lpVtbl->NavigateHack(This,grfHLNF,pbc,pibsc,pszTargetName,pszUrl,pszLocation)
#define ITargetFramePriv_FindBrowserByIndex(This,dwID,ppunkBrowser) (This)->lpVtbl->FindBrowserByIndex(This,dwID,ppunkBrowser)
#endif
#endif
  HRESULT WINAPI ITargetFramePriv_FindFrameDownwards_Proxy(ITargetFramePriv *This,LPCWSTR pszTargetName,DWORD dwFlags,IUnknown **ppunkTargetFrame);
  void __RPC_STUB ITargetFramePriv_FindFrameDownwards_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFramePriv_FindFrameInContext_Proxy(ITargetFramePriv *This,LPCWSTR pszTargetName,IUnknown *punkContextFrame,DWORD dwFlags,IUnknown **ppunkTargetFrame);
  void __RPC_STUB ITargetFramePriv_FindFrameInContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFramePriv_OnChildFrameActivate_Proxy(ITargetFramePriv *This,IUnknown *pUnkChildFrame);
  void __RPC_STUB ITargetFramePriv_OnChildFrameActivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFramePriv_OnChildFrameDeactivate_Proxy(ITargetFramePriv *This,IUnknown *pUnkChildFrame);
  void __RPC_STUB ITargetFramePriv_OnChildFrameDeactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFramePriv_NavigateHack_Proxy(ITargetFramePriv *This,DWORD grfHLNF,LPBC pbc,IBindStatusCallback *pibsc,LPCWSTR pszTargetName,LPCWSTR pszUrl,LPCWSTR pszLocation);
  void __RPC_STUB ITargetFramePriv_NavigateHack_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFramePriv_FindBrowserByIndex_Proxy(ITargetFramePriv *This,DWORD dwID,IUnknown **ppunkBrowser);
  void __RPC_STUB ITargetFramePriv_FindBrowserByIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_htiface_0221_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_htiface_0221_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
