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

#ifndef __iwamreg_h__
#define __iwamreg_h__

#ifndef __IWamAdmin_FWD_DEFINED__
#define __IWamAdmin_FWD_DEFINED__
typedef struct IWamAdmin IWamAdmin;
#endif

#ifndef __IWamAdmin2_FWD_DEFINED__
#define __IWamAdmin2_FWD_DEFINED__
typedef struct IWamAdmin2 IWamAdmin2;
#endif

#ifndef __IIISApplicationAdmin_FWD_DEFINED__
#define __IIISApplicationAdmin_FWD_DEFINED__
typedef struct IIISApplicationAdmin IIISApplicationAdmin;
#endif

#ifndef __WamAdmin_FWD_DEFINED__
#define __WamAdmin_FWD_DEFINED__
#ifdef __cplusplus
typedef class WamAdmin WamAdmin;
#else
typedef struct WamAdmin WamAdmin;
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

#ifndef __WAMREG_IADM__IID
#define __WAMREG_IADM__IID
  DEFINE_GUID(IID_IWamAdmin,0x29822AB7,0xF302,0x11D0,0x99,0x53,0x00,0xC0,0x4F,0xD9,0x19,0xC1);
  DEFINE_GUID(IID_IWamAdmin2,0x29822AB8,0xF302,0x11D0,0x99,0x53,0x00,0xC0,0x4F,0xD9,0x19,0xC1);
  DEFINE_GUID(IID_IIISApplicationAdmin,0x7C4E1804,0xE342,0x483D,0xA4,0x3E,0xA8,0x50,0xCF,0xCC,0x8D,0x18);
  DEFINE_GUID(LIBID_WAMREGLib,0x29822AA8,0xF302,0x11D0,0x99,0x53,0x00,0xC0,0x4F,0xD9,0x19,0xC1);
  DEFINE_GUID(CLSID_WamAdmin,0x61738644,0xF196,0x11D0,0x99,0x53,0x00,0xC0,0x4F,0xD9,0x19,0xC1);
#endif

#define APPSTATUS_STOPPED 0
#define APPSTATUS_RUNNING 1
#define APPSTATUS_NOTDEFINED 2

  typedef enum __MIDL___MIDL_itf_wamreg_0000_0001 {
    eAppRunInProc = 0,eAppRunOutProcIsolated,eAppRunOutProcInDefaultPool
  } EAppMode;

  extern RPC_IF_HANDLE __MIDL_itf_wamreg_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wamreg_0000_v0_0_s_ifspec;

#ifndef __IWamAdmin_INTERFACE_DEFINED__
#define __IWamAdmin_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWamAdmin;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWamAdmin : public IUnknown {
  public:
    virtual HRESULT WINAPI AppCreate(LPCWSTR szMDPath,WINBOOL fInProc) = 0;
    virtual HRESULT WINAPI AppDelete(LPCWSTR szMDPath,WINBOOL fRecursive) = 0;
    virtual HRESULT WINAPI AppUnLoad(LPCWSTR szMDPath,WINBOOL fRecursive) = 0;
    virtual HRESULT WINAPI AppGetStatus(LPCWSTR szMDPath,DWORD *pdwAppStatus) = 0;
    virtual HRESULT WINAPI AppDeleteRecoverable(LPCWSTR szMDPath,WINBOOL fRecursive) = 0;
    virtual HRESULT WINAPI AppRecover(LPCWSTR szMDPath,WINBOOL fRecursive) = 0;
  };
#else
  typedef struct IWamAdminVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWamAdmin *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWamAdmin *This);
      ULONG (WINAPI *Release)(IWamAdmin *This);
      HRESULT (WINAPI *AppCreate)(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fInProc);
      HRESULT (WINAPI *AppDelete)(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *AppUnLoad)(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *AppGetStatus)(IWamAdmin *This,LPCWSTR szMDPath,DWORD *pdwAppStatus);
      HRESULT (WINAPI *AppDeleteRecoverable)(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *AppRecover)(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
    END_INTERFACE
  } IWamAdminVtbl;
  struct IWamAdmin {
    CONST_VTBL struct IWamAdminVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWamAdmin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWamAdmin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWamAdmin_Release(This) (This)->lpVtbl->Release(This)
#define IWamAdmin_AppCreate(This,szMDPath,fInProc) (This)->lpVtbl->AppCreate(This,szMDPath,fInProc)
#define IWamAdmin_AppDelete(This,szMDPath,fRecursive) (This)->lpVtbl->AppDelete(This,szMDPath,fRecursive)
#define IWamAdmin_AppUnLoad(This,szMDPath,fRecursive) (This)->lpVtbl->AppUnLoad(This,szMDPath,fRecursive)
#define IWamAdmin_AppGetStatus(This,szMDPath,pdwAppStatus) (This)->lpVtbl->AppGetStatus(This,szMDPath,pdwAppStatus)
#define IWamAdmin_AppDeleteRecoverable(This,szMDPath,fRecursive) (This)->lpVtbl->AppDeleteRecoverable(This,szMDPath,fRecursive)
#define IWamAdmin_AppRecover(This,szMDPath,fRecursive) (This)->lpVtbl->AppRecover(This,szMDPath,fRecursive)
#endif
#endif
  HRESULT WINAPI IWamAdmin_AppCreate_Proxy(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fInProc);
  void __RPC_STUB IWamAdmin_AppCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWamAdmin_AppDelete_Proxy(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
  void __RPC_STUB IWamAdmin_AppDelete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWamAdmin_AppUnLoad_Proxy(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
  void __RPC_STUB IWamAdmin_AppUnLoad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWamAdmin_AppGetStatus_Proxy(IWamAdmin *This,LPCWSTR szMDPath,DWORD *pdwAppStatus);
  void __RPC_STUB IWamAdmin_AppGetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWamAdmin_AppDeleteRecoverable_Proxy(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
  void __RPC_STUB IWamAdmin_AppDeleteRecoverable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWamAdmin_AppRecover_Proxy(IWamAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
  void __RPC_STUB IWamAdmin_AppRecover_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWamAdmin2_INTERFACE_DEFINED__
#define __IWamAdmin2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWamAdmin2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWamAdmin2 : public IWamAdmin {
  public:
    virtual HRESULT WINAPI AppCreate2(LPCWSTR szMDPath,DWORD dwAppMode) = 0;
  };
#else
  typedef struct IWamAdmin2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWamAdmin2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWamAdmin2 *This);
      ULONG (WINAPI *Release)(IWamAdmin2 *This);
      HRESULT (WINAPI *AppCreate)(IWamAdmin2 *This,LPCWSTR szMDPath,WINBOOL fInProc);
      HRESULT (WINAPI *AppDelete)(IWamAdmin2 *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *AppUnLoad)(IWamAdmin2 *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *AppGetStatus)(IWamAdmin2 *This,LPCWSTR szMDPath,DWORD *pdwAppStatus);
      HRESULT (WINAPI *AppDeleteRecoverable)(IWamAdmin2 *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *AppRecover)(IWamAdmin2 *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *AppCreate2)(IWamAdmin2 *This,LPCWSTR szMDPath,DWORD dwAppMode);
    END_INTERFACE
  } IWamAdmin2Vtbl;
  struct IWamAdmin2 {
    CONST_VTBL struct IWamAdmin2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWamAdmin2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWamAdmin2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWamAdmin2_Release(This) (This)->lpVtbl->Release(This)
#define IWamAdmin2_AppCreate(This,szMDPath,fInProc) (This)->lpVtbl->AppCreate(This,szMDPath,fInProc)
#define IWamAdmin2_AppDelete(This,szMDPath,fRecursive) (This)->lpVtbl->AppDelete(This,szMDPath,fRecursive)
#define IWamAdmin2_AppUnLoad(This,szMDPath,fRecursive) (This)->lpVtbl->AppUnLoad(This,szMDPath,fRecursive)
#define IWamAdmin2_AppGetStatus(This,szMDPath,pdwAppStatus) (This)->lpVtbl->AppGetStatus(This,szMDPath,pdwAppStatus)
#define IWamAdmin2_AppDeleteRecoverable(This,szMDPath,fRecursive) (This)->lpVtbl->AppDeleteRecoverable(This,szMDPath,fRecursive)
#define IWamAdmin2_AppRecover(This,szMDPath,fRecursive) (This)->lpVtbl->AppRecover(This,szMDPath,fRecursive)
#define IWamAdmin2_AppCreate2(This,szMDPath,dwAppMode) (This)->lpVtbl->AppCreate2(This,szMDPath,dwAppMode)
#endif
#endif
  HRESULT WINAPI IWamAdmin2_AppCreate2_Proxy(IWamAdmin2 *This,LPCWSTR szMDPath,DWORD dwAppMode);
  void __RPC_STUB IWamAdmin2_AppCreate2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IIISApplicationAdmin_INTERFACE_DEFINED__
#define __IIISApplicationAdmin_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIISApplicationAdmin;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIISApplicationAdmin : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateApplication(LPCWSTR szMDPath,DWORD dwAppMode,LPCWSTR szAppPoolId,WINBOOL fCreatePool) = 0;
    virtual HRESULT WINAPI DeleteApplication(LPCWSTR szMDPath,WINBOOL fRecursive) = 0;
    virtual HRESULT WINAPI CreateApplicationPool(LPCWSTR szPool) = 0;
    virtual HRESULT WINAPI DeleteApplicationPool(LPCWSTR szPool) = 0;
    virtual HRESULT WINAPI EnumerateApplicationsInPool(LPCWSTR szPool,BSTR *bstrBuffer) = 0;
    virtual HRESULT WINAPI RecycleApplicationPool(LPCWSTR szPool) = 0;
    virtual HRESULT WINAPI GetProcessMode(DWORD *pdwMode) = 0;
  };
#else
  typedef struct IIISApplicationAdminVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIISApplicationAdmin *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIISApplicationAdmin *This);
      ULONG (WINAPI *Release)(IIISApplicationAdmin *This);
      HRESULT (WINAPI *CreateApplication)(IIISApplicationAdmin *This,LPCWSTR szMDPath,DWORD dwAppMode,LPCWSTR szAppPoolId,WINBOOL fCreatePool);
      HRESULT (WINAPI *DeleteApplication)(IIISApplicationAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
      HRESULT (WINAPI *CreateApplicationPool)(IIISApplicationAdmin *This,LPCWSTR szPool);
      HRESULT (WINAPI *DeleteApplicationPool)(IIISApplicationAdmin *This,LPCWSTR szPool);
      HRESULT (WINAPI *EnumerateApplicationsInPool)(IIISApplicationAdmin *This,LPCWSTR szPool,BSTR *bstrBuffer);
      HRESULT (WINAPI *RecycleApplicationPool)(IIISApplicationAdmin *This,LPCWSTR szPool);
      HRESULT (WINAPI *GetProcessMode)(IIISApplicationAdmin *This,DWORD *pdwMode);
    END_INTERFACE
  } IIISApplicationAdminVtbl;
  struct IIISApplicationAdmin {
    CONST_VTBL struct IIISApplicationAdminVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIISApplicationAdmin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIISApplicationAdmin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIISApplicationAdmin_Release(This) (This)->lpVtbl->Release(This)
#define IIISApplicationAdmin_CreateApplication(This,szMDPath,dwAppMode,szAppPoolId,fCreatePool) (This)->lpVtbl->CreateApplication(This,szMDPath,dwAppMode,szAppPoolId,fCreatePool)
#define IIISApplicationAdmin_DeleteApplication(This,szMDPath,fRecursive) (This)->lpVtbl->DeleteApplication(This,szMDPath,fRecursive)
#define IIISApplicationAdmin_CreateApplicationPool(This,szPool) (This)->lpVtbl->CreateApplicationPool(This,szPool)
#define IIISApplicationAdmin_DeleteApplicationPool(This,szPool) (This)->lpVtbl->DeleteApplicationPool(This,szPool)
#define IIISApplicationAdmin_EnumerateApplicationsInPool(This,szPool,bstrBuffer) (This)->lpVtbl->EnumerateApplicationsInPool(This,szPool,bstrBuffer)
#define IIISApplicationAdmin_RecycleApplicationPool(This,szPool) (This)->lpVtbl->RecycleApplicationPool(This,szPool)
#define IIISApplicationAdmin_GetProcessMode(This,pdwMode) (This)->lpVtbl->GetProcessMode(This,pdwMode)
#endif
#endif
  HRESULT WINAPI IIISApplicationAdmin_CreateApplication_Proxy(IIISApplicationAdmin *This,LPCWSTR szMDPath,DWORD dwAppMode,LPCWSTR szAppPoolId,WINBOOL fCreatePool);
  void __RPC_STUB IIISApplicationAdmin_CreateApplication_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIISApplicationAdmin_DeleteApplication_Proxy(IIISApplicationAdmin *This,LPCWSTR szMDPath,WINBOOL fRecursive);
  void __RPC_STUB IIISApplicationAdmin_DeleteApplication_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIISApplicationAdmin_CreateApplicationPool_Proxy(IIISApplicationAdmin *This,LPCWSTR szPool);
  void __RPC_STUB IIISApplicationAdmin_CreateApplicationPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIISApplicationAdmin_DeleteApplicationPool_Proxy(IIISApplicationAdmin *This,LPCWSTR szPool);
  void __RPC_STUB IIISApplicationAdmin_DeleteApplicationPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIISApplicationAdmin_EnumerateApplicationsInPool_Proxy(IIISApplicationAdmin *This,LPCWSTR szPool,BSTR *bstrBuffer);
  void __RPC_STUB IIISApplicationAdmin_EnumerateApplicationsInPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIISApplicationAdmin_RecycleApplicationPool_Proxy(IIISApplicationAdmin *This,LPCWSTR szPool);
  void __RPC_STUB IIISApplicationAdmin_RecycleApplicationPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIISApplicationAdmin_GetProcessMode_Proxy(IIISApplicationAdmin *This,DWORD *pdwMode);
  void __RPC_STUB IIISApplicationAdmin_GetProcessMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __WAMREGLib_LIBRARY_DEFINED__
#define __WAMREGLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_WAMREGLib;
  EXTERN_C const CLSID CLSID_WamAdmin;
#ifdef __cplusplus
  class WamAdmin;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
