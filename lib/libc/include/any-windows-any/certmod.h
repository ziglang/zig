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

#ifndef __certmod_h__
#define __certmod_h__

#ifndef __ICertManageModule_FWD_DEFINED__
#define __ICertManageModule_FWD_DEFINED__
typedef struct ICertManageModule ICertManageModule;
#endif

#include "wtypes.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define CMM_REFRESHONLY (0x1)
#define CMM_READONLY (0x2)

  const WCHAR wszCMM_PROP_NAME[] = L"Name";
  const WCHAR wszCMM_PROP_DESCRIPTION[] = L"Description";
  const WCHAR wszCMM_PROP_COPYRIGHT[] = L"Copyright";
  const WCHAR wszCMM_PROP_FILEVER[] = L"File Version";
  const WCHAR wszCMM_PROP_PRODUCTVER[] = L"Product Version";
  const WCHAR wszCMM_PROP_DISPLAY_HWND[] = L"HWND";
  const WCHAR wszCMM_PROP_ISMULTITHREADED[] = L"IsMultiThreaded";

  extern RPC_IF_HANDLE __MIDL_itf_certmod_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certmod_0000_v0_0_s_ifspec;

#ifndef __ICertManageModule_INTERFACE_DEFINED__
#define __ICertManageModule_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertManageModule;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertManageModule : public IDispatch {
  public:
    virtual HRESULT WINAPI GetProperty(const BSTR strConfig,BSTR strStorageLocation,BSTR strPropertyName,LONG Flags,VARIANT *pvarProperty) = 0;
    virtual HRESULT WINAPI SetProperty(const BSTR strConfig,BSTR strStorageLocation,BSTR strPropertyName,LONG Flags,const VARIANT *pvarProperty) = 0;
    virtual HRESULT WINAPI Configure(const BSTR strConfig,BSTR strStorageLocation,LONG Flags) = 0;
  };
#else
  typedef struct ICertManageModuleVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertManageModule *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertManageModule *This);
      ULONG (WINAPI *Release)(ICertManageModule *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertManageModule *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertManageModule *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertManageModule *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertManageModule *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetProperty)(ICertManageModule *This,const BSTR strConfig,BSTR strStorageLocation,BSTR strPropertyName,LONG Flags,VARIANT *pvarProperty);
      HRESULT (WINAPI *SetProperty)(ICertManageModule *This,const BSTR strConfig,BSTR strStorageLocation,BSTR strPropertyName,LONG Flags,const VARIANT *pvarProperty);
      HRESULT (WINAPI *Configure)(ICertManageModule *This,const BSTR strConfig,BSTR strStorageLocation,LONG Flags);
    END_INTERFACE
  } ICertManageModuleVtbl;
  struct ICertManageModule {
    CONST_VTBL struct ICertManageModuleVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertManageModule_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertManageModule_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertManageModule_Release(This) (This)->lpVtbl->Release(This)
#define ICertManageModule_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertManageModule_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertManageModule_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertManageModule_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertManageModule_GetProperty(This,strConfig,strStorageLocation,strPropertyName,Flags,pvarProperty) (This)->lpVtbl->GetProperty(This,strConfig,strStorageLocation,strPropertyName,Flags,pvarProperty)
#define ICertManageModule_SetProperty(This,strConfig,strStorageLocation,strPropertyName,Flags,pvarProperty) (This)->lpVtbl->SetProperty(This,strConfig,strStorageLocation,strPropertyName,Flags,pvarProperty)
#define ICertManageModule_Configure(This,strConfig,strStorageLocation,Flags) (This)->lpVtbl->Configure(This,strConfig,strStorageLocation,Flags)
#endif
#endif
  HRESULT WINAPI ICertManageModule_GetProperty_Proxy(ICertManageModule *This,const BSTR strConfig,BSTR strStorageLocation,BSTR strPropertyName,LONG Flags,VARIANT *pvarProperty);
  void __RPC_STUB ICertManageModule_GetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertManageModule_SetProperty_Proxy(ICertManageModule *This,const BSTR strConfig,BSTR strStorageLocation,BSTR strPropertyName,LONG Flags,const VARIANT *pvarProperty);
  void __RPC_STUB ICertManageModule_SetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertManageModule_Configure_Proxy(ICertManageModule *This,const BSTR strConfig,BSTR strStorageLocation,LONG Flags);
  void __RPC_STUB ICertManageModule_Configure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
