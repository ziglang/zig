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

#ifndef __objsafe_h__
#define __objsafe_h__

#ifndef __IObjectSafety_FWD_DEFINED__
#define __IObjectSafety_FWD_DEFINED__
typedef struct IObjectSafety IObjectSafety;
#endif

#include "unknwn.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _LPSAFEOBJECT_DEFINED
#define _LPSAFEOBJECT_DEFINED

#define INTERFACESAFE_FOR_UNTRUSTED_CALLER 0x00000001
#define INTERFACESAFE_FOR_UNTRUSTED_DATA 0x00000002
#define INTERFACE_USES_DISPEX 0x00000004
#define INTERFACE_USES_SECURITY_MANAGER 0x00000008

  DEFINE_GUID(IID_IObjectSafety,0xcb5bdc81,0x93c1,0x11cf,0x8f,0x20,0x0,0x80,0x5f,0x2c,0xd0,0x64);
  EXTERN_C GUID CATID_SafeForScripting;
  EXTERN_C GUID CATID_SafeForInitializing;

  extern RPC_IF_HANDLE __MIDL_itf_objsafe_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_objsafe_0000_v0_0_s_ifspec;

#ifndef __IObjectSafety_INTERFACE_DEFINED__
#define __IObjectSafety_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectSafety;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectSafety : public IUnknown {
  public:
    virtual HRESULT WINAPI GetInterfaceSafetyOptions(REFIID riid,DWORD *pdwSupportedOptions,DWORD *pdwEnabledOptions) = 0;
    virtual HRESULT WINAPI SetInterfaceSafetyOptions(REFIID riid,DWORD dwOptionSetMask,DWORD dwEnabledOptions) = 0;
  };
#else
  typedef struct IObjectSafetyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectSafety *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectSafety *This);
      ULONG (WINAPI *Release)(IObjectSafety *This);
      HRESULT (WINAPI *GetInterfaceSafetyOptions)(IObjectSafety *This,REFIID riid,DWORD *pdwSupportedOptions,DWORD *pdwEnabledOptions);
      HRESULT (WINAPI *SetInterfaceSafetyOptions)(IObjectSafety *This,REFIID riid,DWORD dwOptionSetMask,DWORD dwEnabledOptions);
    END_INTERFACE
  } IObjectSafetyVtbl;
  struct IObjectSafety {
    CONST_VTBL struct IObjectSafetyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectSafety_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectSafety_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectSafety_Release(This) (This)->lpVtbl->Release(This)
#define IObjectSafety_GetInterfaceSafetyOptions(This,riid,pdwSupportedOptions,pdwEnabledOptions) (This)->lpVtbl->GetInterfaceSafetyOptions(This,riid,pdwSupportedOptions,pdwEnabledOptions)
#define IObjectSafety_SetInterfaceSafetyOptions(This,riid,dwOptionSetMask,dwEnabledOptions) (This)->lpVtbl->SetInterfaceSafetyOptions(This,riid,dwOptionSetMask,dwEnabledOptions)
#endif
#endif
  HRESULT WINAPI IObjectSafety_GetInterfaceSafetyOptions_Proxy(IObjectSafety *This,REFIID riid,DWORD *pdwSupportedOptions,DWORD *pdwEnabledOptions);
  void __RPC_STUB IObjectSafety_GetInterfaceSafetyOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectSafety_SetInterfaceSafetyOptions_Proxy(IObjectSafety *This,REFIID riid,DWORD dwOptionSetMask,DWORD dwEnabledOptions);
  void __RPC_STUB IObjectSafety_SetInterfaceSafetyOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef IObjectSafety *LPOBJECTSAFETY;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_objsafe_0009_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_objsafe_0009_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
