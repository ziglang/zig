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
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __bitscfg_h__
#define __bitscfg_h__

#ifndef __IBITSExtensionSetup_FWD_DEFINED__
#define __IBITSExtensionSetup_FWD_DEFINED__
typedef struct IBITSExtensionSetup IBITSExtensionSetup;
#endif

#ifndef __IBITSExtensionSetupFactory_FWD_DEFINED__
#define __IBITSExtensionSetupFactory_FWD_DEFINED__
typedef struct IBITSExtensionSetupFactory IBITSExtensionSetupFactory;
#endif

#ifndef __BITSExtensionSetupFactory_FWD_DEFINED__
#define __BITSExtensionSetupFactory_FWD_DEFINED__
#ifdef __cplusplus
typedef class BITSExtensionSetupFactory BITSExtensionSetupFactory;
#else
typedef struct BITSExtensionSetupFactory BITSExtensionSetupFactory;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "mstask.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __IBITSExtensionSetup_INTERFACE_DEFINED__
#define __IBITSExtensionSetup_INTERFACE_DEFINED__

  EXTERN_C const IID IID_IBITSExtensionSetup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBITSExtensionSetup : public IDispatch {
  public:
    virtual HRESULT WINAPI EnableBITSUploads(void) = 0;
    virtual HRESULT WINAPI DisableBITSUploads(void) = 0;
    virtual HRESULT WINAPI GetCleanupTaskName(BSTR *pTaskName) = 0;
    virtual HRESULT WINAPI GetCleanupTask(REFIID riid,IUnknown **ppUnk) = 0;
  };
#else
  typedef struct IBITSExtensionSetupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBITSExtensionSetup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBITSExtensionSetup *This);
      ULONG (WINAPI *Release)(IBITSExtensionSetup *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IBITSExtensionSetup *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IBITSExtensionSetup *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IBITSExtensionSetup *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IBITSExtensionSetup *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *EnableBITSUploads)(IBITSExtensionSetup *This);
      HRESULT (WINAPI *DisableBITSUploads)(IBITSExtensionSetup *This);
      HRESULT (WINAPI *GetCleanupTaskName)(IBITSExtensionSetup *This,BSTR *pTaskName);
      HRESULT (WINAPI *GetCleanupTask)(IBITSExtensionSetup *This,REFIID riid,IUnknown **ppUnk);
    END_INTERFACE
  } IBITSExtensionSetupVtbl;
  struct IBITSExtensionSetup {
    CONST_VTBL struct IBITSExtensionSetupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBITSExtensionSetup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBITSExtensionSetup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBITSExtensionSetup_Release(This) (This)->lpVtbl->Release(This)
#define IBITSExtensionSetup_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IBITSExtensionSetup_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IBITSExtensionSetup_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IBITSExtensionSetup_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IBITSExtensionSetup_EnableBITSUploads(This) (This)->lpVtbl->EnableBITSUploads(This)
#define IBITSExtensionSetup_DisableBITSUploads(This) (This)->lpVtbl->DisableBITSUploads(This)
#define IBITSExtensionSetup_GetCleanupTaskName(This,pTaskName) (This)->lpVtbl->GetCleanupTaskName(This,pTaskName)
#define IBITSExtensionSetup_GetCleanupTask(This,riid,ppUnk) (This)->lpVtbl->GetCleanupTask(This,riid,ppUnk)
#endif
#endif
  HRESULT WINAPI IBITSExtensionSetup_EnableBITSUploads_Proxy(IBITSExtensionSetup *This);
  void __RPC_STUB IBITSExtensionSetup_EnableBITSUploads_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBITSExtensionSetup_DisableBITSUploads_Proxy(IBITSExtensionSetup *This);
  void __RPC_STUB IBITSExtensionSetup_DisableBITSUploads_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBITSExtensionSetup_GetCleanupTaskName_Proxy(IBITSExtensionSetup *This,BSTR *pTaskName);
  void __RPC_STUB IBITSExtensionSetup_GetCleanupTaskName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBITSExtensionSetup_GetCleanupTask_Proxy(IBITSExtensionSetup *This,REFIID riid,IUnknown **ppUnk);
  void __RPC_STUB IBITSExtensionSetup_GetCleanupTask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBITSExtensionSetupFactory_INTERFACE_DEFINED__
#define __IBITSExtensionSetupFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBITSExtensionSetupFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBITSExtensionSetupFactory : public IDispatch {
  public:
    virtual HRESULT WINAPI GetObject(BSTR Path,IBITSExtensionSetup **ppExtensionSetup) = 0;
  };
#else
  typedef struct IBITSExtensionSetupFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBITSExtensionSetupFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBITSExtensionSetupFactory *This);
      ULONG (WINAPI *Release)(IBITSExtensionSetupFactory *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IBITSExtensionSetupFactory *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IBITSExtensionSetupFactory *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IBITSExtensionSetupFactory *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IBITSExtensionSetupFactory *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetObject)(IBITSExtensionSetupFactory *This,BSTR Path,IBITSExtensionSetup **ppExtensionSetup);
    END_INTERFACE
  } IBITSExtensionSetupFactoryVtbl;
  struct IBITSExtensionSetupFactory {
    CONST_VTBL struct IBITSExtensionSetupFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBITSExtensionSetupFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBITSExtensionSetupFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBITSExtensionSetupFactory_Release(This) (This)->lpVtbl->Release(This)
#define IBITSExtensionSetupFactory_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IBITSExtensionSetupFactory_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IBITSExtensionSetupFactory_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IBITSExtensionSetupFactory_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IBITSExtensionSetupFactory_GetObject(This,Path,ppExtensionSetup) (This)->lpVtbl->GetObject(This,Path,ppExtensionSetup)
#endif
#endif
  HRESULT WINAPI IBITSExtensionSetupFactory_GetObject_Proxy(IBITSExtensionSetupFactory *This,BSTR Path,IBITSExtensionSetup **ppExtensionSetup);
  void __RPC_STUB IBITSExtensionSetupFactory_GetObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __BITSExtensionSetup_LIBRARY_DEFINED__
#define __BITSExtensionSetup_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_BITSExtensionSetup;
  EXTERN_C const CLSID CLSID_BITSExtensionSetupFactory;
#ifdef __cplusplus
  class BITSExtensionSetupFactory;
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
