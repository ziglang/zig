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

#ifndef __htiframe_h__
#define __htiframe_h__

#ifndef __ITargetNotify_FWD_DEFINED__
#define __ITargetNotify_FWD_DEFINED__
typedef struct ITargetNotify ITargetNotify;
#endif

#ifndef __ITargetNotify2_FWD_DEFINED__
#define __ITargetNotify2_FWD_DEFINED__
typedef struct ITargetNotify2 ITargetNotify2;
#endif

#ifndef __ITargetFrame2_FWD_DEFINED__
#define __ITargetFrame2_FWD_DEFINED__
typedef struct ITargetFrame2 ITargetFrame2;
#endif

#ifndef __ITargetContainer_FWD_DEFINED__
#define __ITargetContainer_FWD_DEFINED__
typedef struct ITargetContainer ITargetContainer;
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

  EXTERN_C const IID IID_ITargetFrame2;
  EXTERN_C const IID IID_ITargetContainer;
#ifndef _LPTARGETFRAME2_DEFINED
#define _LPTARGETFRAME2_DEFINED
#define TF_NAVIGATE 0x7FAEABAC
#define TARGET_NOTIFY_OBJECT_NAME L"863a99a0-21bc-11d0-82b4-00a0c90c29c5"

  extern RPC_IF_HANDLE __MIDL_itf_htiframe_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_htiframe_0000_v0_0_s_ifspec;

#ifndef __ITargetNotify_INTERFACE_DEFINED__
#define __ITargetNotify_INTERFACE_DEFINED__

  typedef ITargetNotify *LPTARGETNOTIFY;

  EXTERN_C const IID IID_ITargetNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITargetNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI OnCreate(IUnknown *pUnkDestination,ULONG cbCookie) = 0;
    virtual HRESULT WINAPI OnReuse(IUnknown *pUnkDestination) = 0;
  };
#else
  typedef struct ITargetNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITargetNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITargetNotify *This);
      ULONG (WINAPI *Release)(ITargetNotify *This);
      HRESULT (WINAPI *OnCreate)(ITargetNotify *This,IUnknown *pUnkDestination,ULONG cbCookie);
      HRESULT (WINAPI *OnReuse)(ITargetNotify *This,IUnknown *pUnkDestination);
    END_INTERFACE
  } ITargetNotifyVtbl;
  struct ITargetNotify {
    CONST_VTBL struct ITargetNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITargetNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITargetNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITargetNotify_Release(This) (This)->lpVtbl->Release(This)
#define ITargetNotify_OnCreate(This,pUnkDestination,cbCookie) (This)->lpVtbl->OnCreate(This,pUnkDestination,cbCookie)
#define ITargetNotify_OnReuse(This,pUnkDestination) (This)->lpVtbl->OnReuse(This,pUnkDestination)
#endif
#endif
  HRESULT WINAPI ITargetNotify_OnCreate_Proxy(ITargetNotify *This,IUnknown *pUnkDestination,ULONG cbCookie);
  void __RPC_STUB ITargetNotify_OnCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetNotify_OnReuse_Proxy(ITargetNotify *This,IUnknown *pUnkDestination);
  void __RPC_STUB ITargetNotify_OnReuse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITargetNotify2_INTERFACE_DEFINED__
#define __ITargetNotify2_INTERFACE_DEFINED__
  typedef ITargetNotify2 *LPTARGETNOTIFY2;

  EXTERN_C const IID IID_ITargetNotify2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITargetNotify2 : public ITargetNotify {
  public:
    virtual HRESULT WINAPI GetOptionString(BSTR *pbstrOptions) = 0;
  };
#else
  typedef struct ITargetNotify2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITargetNotify2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITargetNotify2 *This);
      ULONG (WINAPI *Release)(ITargetNotify2 *This);
      HRESULT (WINAPI *OnCreate)(ITargetNotify2 *This,IUnknown *pUnkDestination,ULONG cbCookie);
      HRESULT (WINAPI *OnReuse)(ITargetNotify2 *This,IUnknown *pUnkDestination);
      HRESULT (WINAPI *GetOptionString)(ITargetNotify2 *This,BSTR *pbstrOptions);
    END_INTERFACE
  } ITargetNotify2Vtbl;
  struct ITargetNotify2 {
    CONST_VTBL struct ITargetNotify2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITargetNotify2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITargetNotify2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITargetNotify2_Release(This) (This)->lpVtbl->Release(This)
#define ITargetNotify2_OnCreate(This,pUnkDestination,cbCookie) (This)->lpVtbl->OnCreate(This,pUnkDestination,cbCookie)
#define ITargetNotify2_OnReuse(This,pUnkDestination) (This)->lpVtbl->OnReuse(This,pUnkDestination)
#define ITargetNotify2_GetOptionString(This,pbstrOptions) (This)->lpVtbl->GetOptionString(This,pbstrOptions)
#endif
#endif
  HRESULT WINAPI ITargetNotify2_GetOptionString_Proxy(ITargetNotify2 *This,BSTR *pbstrOptions);
  void __RPC_STUB ITargetNotify2_GetOptionString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITargetFrame2_INTERFACE_DEFINED__
#define __ITargetFrame2_INTERFACE_DEFINED__
  typedef ITargetFrame2 *LPTARGETFRAME2;
  typedef
    enum __MIDL_ITargetFrame2_0001 {
      FINDFRAME_NONE = 0,FINDFRAME_JUSTTESTEXISTENCE = 1,FINDFRAME_INTERNAL = 0x80000000
  } FINDFRAME_FLAGS;

  typedef enum __MIDL_ITargetFrame2_0002 {
    FRAMEOPTIONS_SCROLL_YES = 0x1,FRAMEOPTIONS_SCROLL_NO = 0x2,FRAMEOPTIONS_SCROLL_AUTO = 0x4,FRAMEOPTIONS_NORESIZE = 0x8,FRAMEOPTIONS_NO3DBORDER = 0x10,
    FRAMEOPTIONS_DESKTOP = 0x20,FRAMEOPTIONS_BROWSERBAND = 0x40
  } FRAMEOPTIONS_FLAGS;

  EXTERN_C const IID IID_ITargetFrame2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITargetFrame2 : public IUnknown {
  public:
    virtual HRESULT WINAPI SetFrameName(LPCWSTR pszFrameName) = 0;
    virtual HRESULT WINAPI GetFrameName(LPWSTR *ppszFrameName) = 0;
    virtual HRESULT WINAPI GetParentFrame(IUnknown **ppunkParent) = 0;
    virtual HRESULT WINAPI SetFrameSrc(LPCWSTR pszFrameSrc) = 0;
    virtual HRESULT WINAPI GetFrameSrc(LPWSTR *ppszFrameSrc) = 0;
    virtual HRESULT WINAPI GetFramesContainer(IOleContainer **ppContainer) = 0;
    virtual HRESULT WINAPI SetFrameOptions(DWORD dwFlags) = 0;
    virtual HRESULT WINAPI GetFrameOptions(DWORD *pdwFlags) = 0;
    virtual HRESULT WINAPI SetFrameMargins(DWORD dwWidth,DWORD dwHeight) = 0;
    virtual HRESULT WINAPI GetFrameMargins(DWORD *pdwWidth,DWORD *pdwHeight) = 0;
    virtual HRESULT WINAPI FindFrame(LPCWSTR pszTargetName,DWORD dwFlags,IUnknown **ppunkTargetFrame) = 0;
    virtual HRESULT WINAPI GetTargetAlias(LPCWSTR pszTargetName,LPWSTR *ppszTargetAlias) = 0;
  };
#else
  typedef struct ITargetFrame2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITargetFrame2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITargetFrame2 *This);
      ULONG (WINAPI *Release)(ITargetFrame2 *This);
      HRESULT (WINAPI *SetFrameName)(ITargetFrame2 *This,LPCWSTR pszFrameName);
      HRESULT (WINAPI *GetFrameName)(ITargetFrame2 *This,LPWSTR *ppszFrameName);
      HRESULT (WINAPI *GetParentFrame)(ITargetFrame2 *This,IUnknown **ppunkParent);
      HRESULT (WINAPI *SetFrameSrc)(ITargetFrame2 *This,LPCWSTR pszFrameSrc);
      HRESULT (WINAPI *GetFrameSrc)(ITargetFrame2 *This,LPWSTR *ppszFrameSrc);
      HRESULT (WINAPI *GetFramesContainer)(ITargetFrame2 *This,IOleContainer **ppContainer);
      HRESULT (WINAPI *SetFrameOptions)(ITargetFrame2 *This,DWORD dwFlags);
      HRESULT (WINAPI *GetFrameOptions)(ITargetFrame2 *This,DWORD *pdwFlags);
      HRESULT (WINAPI *SetFrameMargins)(ITargetFrame2 *This,DWORD dwWidth,DWORD dwHeight);
      HRESULT (WINAPI *GetFrameMargins)(ITargetFrame2 *This,DWORD *pdwWidth,DWORD *pdwHeight);
      HRESULT (WINAPI *FindFrame)(ITargetFrame2 *This,LPCWSTR pszTargetName,DWORD dwFlags,IUnknown **ppunkTargetFrame);
      HRESULT (WINAPI *GetTargetAlias)(ITargetFrame2 *This,LPCWSTR pszTargetName,LPWSTR *ppszTargetAlias);
    END_INTERFACE
  } ITargetFrame2Vtbl;
  struct ITargetFrame2 {
    CONST_VTBL struct ITargetFrame2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITargetFrame2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITargetFrame2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITargetFrame2_Release(This) (This)->lpVtbl->Release(This)
#define ITargetFrame2_SetFrameName(This,pszFrameName) (This)->lpVtbl->SetFrameName(This,pszFrameName)
#define ITargetFrame2_GetFrameName(This,ppszFrameName) (This)->lpVtbl->GetFrameName(This,ppszFrameName)
#define ITargetFrame2_GetParentFrame(This,ppunkParent) (This)->lpVtbl->GetParentFrame(This,ppunkParent)
#define ITargetFrame2_SetFrameSrc(This,pszFrameSrc) (This)->lpVtbl->SetFrameSrc(This,pszFrameSrc)
#define ITargetFrame2_GetFrameSrc(This,ppszFrameSrc) (This)->lpVtbl->GetFrameSrc(This,ppszFrameSrc)
#define ITargetFrame2_GetFramesContainer(This,ppContainer) (This)->lpVtbl->GetFramesContainer(This,ppContainer)
#define ITargetFrame2_SetFrameOptions(This,dwFlags) (This)->lpVtbl->SetFrameOptions(This,dwFlags)
#define ITargetFrame2_GetFrameOptions(This,pdwFlags) (This)->lpVtbl->GetFrameOptions(This,pdwFlags)
#define ITargetFrame2_SetFrameMargins(This,dwWidth,dwHeight) (This)->lpVtbl->SetFrameMargins(This,dwWidth,dwHeight)
#define ITargetFrame2_GetFrameMargins(This,pdwWidth,pdwHeight) (This)->lpVtbl->GetFrameMargins(This,pdwWidth,pdwHeight)
#define ITargetFrame2_FindFrame(This,pszTargetName,dwFlags,ppunkTargetFrame) (This)->lpVtbl->FindFrame(This,pszTargetName,dwFlags,ppunkTargetFrame)
#define ITargetFrame2_GetTargetAlias(This,pszTargetName,ppszTargetAlias) (This)->lpVtbl->GetTargetAlias(This,pszTargetName,ppszTargetAlias)
#endif
#endif
  HRESULT WINAPI ITargetFrame2_SetFrameName_Proxy(ITargetFrame2 *This,LPCWSTR pszFrameName);
  void __RPC_STUB ITargetFrame2_SetFrameName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_GetFrameName_Proxy(ITargetFrame2 *This,LPWSTR *ppszFrameName);
  void __RPC_STUB ITargetFrame2_GetFrameName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_GetParentFrame_Proxy(ITargetFrame2 *This,IUnknown **ppunkParent);
  void __RPC_STUB ITargetFrame2_GetParentFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_SetFrameSrc_Proxy(ITargetFrame2 *This,LPCWSTR pszFrameSrc);
  void __RPC_STUB ITargetFrame2_SetFrameSrc_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_GetFrameSrc_Proxy(ITargetFrame2 *This,LPWSTR *ppszFrameSrc);
  void __RPC_STUB ITargetFrame2_GetFrameSrc_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_GetFramesContainer_Proxy(ITargetFrame2 *This,IOleContainer **ppContainer);
  void __RPC_STUB ITargetFrame2_GetFramesContainer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_SetFrameOptions_Proxy(ITargetFrame2 *This,DWORD dwFlags);
  void __RPC_STUB ITargetFrame2_SetFrameOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_GetFrameOptions_Proxy(ITargetFrame2 *This,DWORD *pdwFlags);
  void __RPC_STUB ITargetFrame2_GetFrameOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_SetFrameMargins_Proxy(ITargetFrame2 *This,DWORD dwWidth,DWORD dwHeight);
  void __RPC_STUB ITargetFrame2_SetFrameMargins_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_GetFrameMargins_Proxy(ITargetFrame2 *This,DWORD *pdwWidth,DWORD *pdwHeight);
  void __RPC_STUB ITargetFrame2_GetFrameMargins_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_FindFrame_Proxy(ITargetFrame2 *This,LPCWSTR pszTargetName,DWORD dwFlags,IUnknown **ppunkTargetFrame);
  void __RPC_STUB ITargetFrame2_FindFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetFrame2_GetTargetAlias_Proxy(ITargetFrame2 *This,LPCWSTR pszTargetName,LPWSTR *ppszTargetAlias);
  void __RPC_STUB ITargetFrame2_GetTargetAlias_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITargetContainer_INTERFACE_DEFINED__
#define __ITargetContainer_INTERFACE_DEFINED__
  typedef ITargetContainer *LPTARGETCONTAINER;

  EXTERN_C const IID IID_ITargetContainer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITargetContainer : public IUnknown {
  public:
    virtual HRESULT WINAPI GetFrameUrl(LPWSTR *ppszFrameSrc) = 0;
    virtual HRESULT WINAPI GetFramesContainer(IOleContainer **ppContainer) = 0;
  };
#else
  typedef struct ITargetContainerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITargetContainer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITargetContainer *This);
      ULONG (WINAPI *Release)(ITargetContainer *This);
      HRESULT (WINAPI *GetFrameUrl)(ITargetContainer *This,LPWSTR *ppszFrameSrc);
      HRESULT (WINAPI *GetFramesContainer)(ITargetContainer *This,IOleContainer **ppContainer);
    END_INTERFACE
  } ITargetContainerVtbl;
  struct ITargetContainer {
    CONST_VTBL struct ITargetContainerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITargetContainer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITargetContainer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITargetContainer_Release(This) (This)->lpVtbl->Release(This)
#define ITargetContainer_GetFrameUrl(This,ppszFrameSrc) (This)->lpVtbl->GetFrameUrl(This,ppszFrameSrc)
#define ITargetContainer_GetFramesContainer(This,ppContainer) (This)->lpVtbl->GetFramesContainer(This,ppContainer)
#endif
#endif
  HRESULT WINAPI ITargetContainer_GetFrameUrl_Proxy(ITargetContainer *This,LPWSTR *ppszFrameSrc);
  void __RPC_STUB ITargetContainer_GetFrameUrl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITargetContainer_GetFramesContainer_Proxy(ITargetContainer *This,IOleContainer **ppContainer);
  void __RPC_STUB ITargetContainer_GetFramesContainer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_htiframe_0121_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_htiframe_0121_v0_0_s_ifspec;

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
