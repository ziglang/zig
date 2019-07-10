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

#ifndef __h323priv_h__
#define __h323priv_h__

#ifndef __IH323LineEx_FWD_DEFINED__
#define __IH323LineEx_FWD_DEFINED__
typedef struct IH323LineEx IH323LineEx;
#endif

#ifndef __IKeyFrameControl_FWD_DEFINED__
#define __IKeyFrameControl_FWD_DEFINED__
typedef struct IKeyFrameControl IKeyFrameControl;
#endif

#include "ipmsp.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum H245_CAPABILITY {
    HC_G711 = 0,HC_G723,HC_H263QCIF,HC_H261QCIF
  } H245_CAPABILITY;

  extern RPC_IF_HANDLE __MIDL_itf_h323priv_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_h323priv_0000_v0_0_s_ifspec;

#ifndef __IH323LineEx_INTERFACE_DEFINED__
#define __IH323LineEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IH323LineEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IH323LineEx : public IUnknown {
  public:
    virtual HRESULT WINAPI SetExternalT120Address(WINBOOL fEnable,DWORD dwIP,WORD wPort) = 0;
    virtual HRESULT WINAPI SetDefaultCapabilityPreferrence(DWORD dwNumCaps,H245_CAPABILITY *pCapabilities,DWORD *pWeights) = 0;
    virtual HRESULT WINAPI SetAlias(WCHAR *strAlias,DWORD dwLength) = 0;
  };
#else
  typedef struct IH323LineExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IH323LineEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IH323LineEx *This);
      ULONG (WINAPI *Release)(IH323LineEx *This);
      HRESULT (WINAPI *SetExternalT120Address)(IH323LineEx *This,WINBOOL fEnable,DWORD dwIP,WORD wPort);
      HRESULT (WINAPI *SetDefaultCapabilityPreferrence)(IH323LineEx *This,DWORD dwNumCaps,H245_CAPABILITY *pCapabilities,DWORD *pWeights);
      HRESULT (WINAPI *SetAlias)(IH323LineEx *This,WCHAR *strAlias,DWORD dwLength);
    END_INTERFACE
  } IH323LineExVtbl;
  struct IH323LineEx {
    CONST_VTBL struct IH323LineExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IH323LineEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IH323LineEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IH323LineEx_Release(This) (This)->lpVtbl->Release(This)
#define IH323LineEx_SetExternalT120Address(This,fEnable,dwIP,wPort) (This)->lpVtbl->SetExternalT120Address(This,fEnable,dwIP,wPort)
#define IH323LineEx_SetDefaultCapabilityPreferrence(This,dwNumCaps,pCapabilities,pWeights) (This)->lpVtbl->SetDefaultCapabilityPreferrence(This,dwNumCaps,pCapabilities,pWeights)
#define IH323LineEx_SetAlias(This,strAlias,dwLength) (This)->lpVtbl->SetAlias(This,strAlias,dwLength)
#endif
#endif
  HRESULT WINAPI IH323LineEx_SetExternalT120Address_Proxy(IH323LineEx *This,WINBOOL fEnable,DWORD dwIP,WORD wPort);
  void __RPC_STUB IH323LineEx_SetExternalT120Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IH323LineEx_SetDefaultCapabilityPreferrence_Proxy(IH323LineEx *This,DWORD dwNumCaps,H245_CAPABILITY *pCapabilities,DWORD *pWeights);
  void __RPC_STUB IH323LineEx_SetDefaultCapabilityPreferrence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IH323LineEx_SetAlias_Proxy(IH323LineEx *This,WCHAR *strAlias,DWORD dwLength);
  void __RPC_STUB IH323LineEx_SetAlias_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IKeyFrameControl_INTERFACE_DEFINED__
#define __IKeyFrameControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IKeyFrameControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IKeyFrameControl : public IUnknown {
  public:
    virtual HRESULT WINAPI UpdatePicture(void) = 0;
    virtual HRESULT WINAPI PeriodicUpdatePicture(WINBOOL fEnable,DWORD dwInterval) = 0;
  };
#else
  typedef struct IKeyFrameControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IKeyFrameControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IKeyFrameControl *This);
      ULONG (WINAPI *Release)(IKeyFrameControl *This);
      HRESULT (WINAPI *UpdatePicture)(IKeyFrameControl *This);
      HRESULT (WINAPI *PeriodicUpdatePicture)(IKeyFrameControl *This,WINBOOL fEnable,DWORD dwInterval);
    END_INTERFACE
  } IKeyFrameControlVtbl;
  struct IKeyFrameControl {
    CONST_VTBL struct IKeyFrameControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IKeyFrameControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IKeyFrameControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IKeyFrameControl_Release(This) (This)->lpVtbl->Release(This)
#define IKeyFrameControl_UpdatePicture(This) (This)->lpVtbl->UpdatePicture(This)
#define IKeyFrameControl_PeriodicUpdatePicture(This,fEnable,dwInterval) (This)->lpVtbl->PeriodicUpdatePicture(This,fEnable,dwInterval)
#endif
#endif
  HRESULT WINAPI IKeyFrameControl_UpdatePicture_Proxy(IKeyFrameControl *This);
  void __RPC_STUB IKeyFrameControl_UpdatePicture_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IKeyFrameControl_PeriodicUpdatePicture_Proxy(IKeyFrameControl *This,WINBOOL fEnable,DWORD dwInterval);
  void __RPC_STUB IKeyFrameControl_PeriodicUpdatePicture_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif

#endif
