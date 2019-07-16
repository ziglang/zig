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

#ifndef __iedial_h__
#define __iedial_h__

#ifndef __IDialEventSink_FWD_DEFINED__
#define __IDialEventSink_FWD_DEFINED__
typedef struct IDialEventSink IDialEventSink;
#endif

#ifndef __IDialEngine_FWD_DEFINED__
#define __IDialEngine_FWD_DEFINED__
typedef struct IDialEngine IDialEngine;
#endif

#ifndef __IDialBranding_FWD_DEFINED__
#define __IDialBranding_FWD_DEFINED__
typedef struct IDialBranding IDialBranding;
#endif

#include "unknwn.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_iedial_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iedial_0000_v0_0_s_ifspec;

#ifndef __IDialEventSink_INTERFACE_DEFINED__
#define __IDialEventSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDialEventSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDialEventSink : public IUnknown {
  public:
    virtual HRESULT WINAPI OnEvent(DWORD dwEvent,DWORD dwStatus) = 0;
  };
#else
  typedef struct IDialEventSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDialEventSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDialEventSink *This);
      ULONG (WINAPI *Release)(IDialEventSink *This);
      HRESULT (WINAPI *OnEvent)(IDialEventSink *This,DWORD dwEvent,DWORD dwStatus);
    END_INTERFACE
  } IDialEventSinkVtbl;
  struct IDialEventSink {
    CONST_VTBL struct IDialEventSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDialEventSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDialEventSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDialEventSink_Release(This) (This)->lpVtbl->Release(This)
#define IDialEventSink_OnEvent(This,dwEvent,dwStatus) (This)->lpVtbl->OnEvent(This,dwEvent,dwStatus)
#endif
#endif
  HRESULT WINAPI IDialEventSink_OnEvent_Proxy(IDialEventSink *This,DWORD dwEvent,DWORD dwStatus);
  void __RPC_STUB IDialEventSink_OnEvent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDialEngine_INTERFACE_DEFINED__
#define __IDialEngine_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDialEngine;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDialEngine : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(LPCWSTR pwzConnectoid,IDialEventSink *pIDES) = 0;
    virtual HRESULT WINAPI GetProperty(LPCWSTR pwzProperty,LPWSTR pwzValue,DWORD dwBufSize) = 0;
    virtual HRESULT WINAPI SetProperty(LPCWSTR pwzProperty,LPCWSTR pwzValue) = 0;
    virtual HRESULT WINAPI Dial(void) = 0;
    virtual HRESULT WINAPI HangUp(void) = 0;
    virtual HRESULT WINAPI GetConnectedState(DWORD *pdwState) = 0;
    virtual HRESULT WINAPI GetConnectHandle(DWORD_PTR *pdwHandle) = 0;
  };
#else
  typedef struct IDialEngineVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDialEngine *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDialEngine *This);
      ULONG (WINAPI *Release)(IDialEngine *This);
      HRESULT (WINAPI *Initialize)(IDialEngine *This,LPCWSTR pwzConnectoid,IDialEventSink *pIDES);
      HRESULT (WINAPI *GetProperty)(IDialEngine *This,LPCWSTR pwzProperty,LPWSTR pwzValue,DWORD dwBufSize);
      HRESULT (WINAPI *SetProperty)(IDialEngine *This,LPCWSTR pwzProperty,LPCWSTR pwzValue);
      HRESULT (WINAPI *Dial)(IDialEngine *This);
      HRESULT (WINAPI *HangUp)(IDialEngine *This);
      HRESULT (WINAPI *GetConnectedState)(IDialEngine *This,DWORD *pdwState);
      HRESULT (WINAPI *GetConnectHandle)(IDialEngine *This,DWORD_PTR *pdwHandle);
    END_INTERFACE
  } IDialEngineVtbl;
  struct IDialEngine {
    CONST_VTBL struct IDialEngineVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDialEngine_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDialEngine_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDialEngine_Release(This) (This)->lpVtbl->Release(This)
#define IDialEngine_Initialize(This,pwzConnectoid,pIDES) (This)->lpVtbl->Initialize(This,pwzConnectoid,pIDES)
#define IDialEngine_GetProperty(This,pwzProperty,pwzValue,dwBufSize) (This)->lpVtbl->GetProperty(This,pwzProperty,pwzValue,dwBufSize)
#define IDialEngine_SetProperty(This,pwzProperty,pwzValue) (This)->lpVtbl->SetProperty(This,pwzProperty,pwzValue)
#define IDialEngine_Dial(This) (This)->lpVtbl->Dial(This)
#define IDialEngine_HangUp(This) (This)->lpVtbl->HangUp(This)
#define IDialEngine_GetConnectedState(This,pdwState) (This)->lpVtbl->GetConnectedState(This,pdwState)
#define IDialEngine_GetConnectHandle(This,pdwHandle) (This)->lpVtbl->GetConnectHandle(This,pdwHandle)
#endif
#endif
  HRESULT WINAPI IDialEngine_Initialize_Proxy(IDialEngine *This,LPCWSTR pwzConnectoid,IDialEventSink *pIDES);
  void __RPC_STUB IDialEngine_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDialEngine_GetProperty_Proxy(IDialEngine *This,LPCWSTR pwzProperty,LPWSTR pwzValue,DWORD dwBufSize);
  void __RPC_STUB IDialEngine_GetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDialEngine_SetProperty_Proxy(IDialEngine *This,LPCWSTR pwzProperty,LPCWSTR pwzValue);
  void __RPC_STUB IDialEngine_SetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDialEngine_Dial_Proxy(IDialEngine *This);
  void __RPC_STUB IDialEngine_Dial_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDialEngine_HangUp_Proxy(IDialEngine *This);
  void __RPC_STUB IDialEngine_HangUp_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDialEngine_GetConnectedState_Proxy(IDialEngine *This,DWORD *pdwState);
  void __RPC_STUB IDialEngine_GetConnectedState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDialEngine_GetConnectHandle_Proxy(IDialEngine *This,DWORD_PTR *pdwHandle);
  void __RPC_STUB IDialEngine_GetConnectHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDialBranding_INTERFACE_DEFINED__
#define __IDialBranding_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDialBranding;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDialBranding : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(LPCWSTR pwzConnectoid) = 0;
    virtual HRESULT WINAPI GetBitmap(DWORD dwIndex,HBITMAP *phBitmap) = 0;
  };
#else
  typedef struct IDialBrandingVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDialBranding *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDialBranding *This);
      ULONG (WINAPI *Release)(IDialBranding *This);
      HRESULT (WINAPI *Initialize)(IDialBranding *This,LPCWSTR pwzConnectoid);
      HRESULT (WINAPI *GetBitmap)(IDialBranding *This,DWORD dwIndex,HBITMAP *phBitmap);
    END_INTERFACE
  } IDialBrandingVtbl;
  struct IDialBranding {
    CONST_VTBL struct IDialBrandingVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDialBranding_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDialBranding_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDialBranding_Release(This) (This)->lpVtbl->Release(This)
#define IDialBranding_Initialize(This,pwzConnectoid) (This)->lpVtbl->Initialize(This,pwzConnectoid)
#define IDialBranding_GetBitmap(This,dwIndex,phBitmap) (This)->lpVtbl->GetBitmap(This,dwIndex,phBitmap)
#endif
#endif
  HRESULT WINAPI IDialBranding_Initialize_Proxy(IDialBranding *This,LPCWSTR pwzConnectoid);
  void __RPC_STUB IDialBranding_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDialBranding_GetBitmap_Proxy(IDialBranding *This,DWORD dwIndex,HBITMAP *phBitmap);
  void __RPC_STUB IDialBranding_GetBitmap_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define DIALPROP_USERNAME L"UserName"
#define DIALPROP_PASSWORD L"Password"
#define DIALPROP_DOMAIN L"Domain"
#define DIALPROP_SAVEPASSWORD L"SavePassword"
#define DIALPROP_REDIALCOUNT L"RedialCount"
#define DIALPROP_REDIALINTERVAL L"RedialInterval"
#define DIALPROP_PHONENUMBER L"PhoneNumber"
#define DIALPROP_LASTERROR L"LastError"
#define DIALPROP_RESOLVEDPHONE L"ResolvedPhone"

#define DIALENG_OperationComplete 0x10000
#define DIALENG_RedialAttempt 0x10001
#define DIALENG_RedialWait 0x10002

  extern RPC_IF_HANDLE __MIDL_itf_iedial_0266_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iedial_0266_v0_0_s_ifspec;

  ULONG __RPC_API HBITMAP_UserSize(ULONG *,ULONG,HBITMAP *);
  unsigned char *__RPC_API HBITMAP_UserMarshal(ULONG *,unsigned char *,HBITMAP *);
  unsigned char *__RPC_API HBITMAP_UserUnmarshal(ULONG *,unsigned char *,HBITMAP *);
  void __RPC_API HBITMAP_UserFree(ULONG *,HBITMAP *);

#ifdef __cplusplus
}
#endif
#endif
