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

#ifndef __certpol_h__
#define __certpol_h__

#ifndef __ICertPolicy_FWD_DEFINED__
#define __ICertPolicy_FWD_DEFINED__
typedef struct ICertPolicy ICertPolicy;
#endif

#ifndef __ICertPolicy2_FWD_DEFINED__
#define __ICertPolicy2_FWD_DEFINED__
typedef struct ICertPolicy2 ICertPolicy2;
#endif

#include "wtypes.h"
#include "certmod.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __ICertPolicy_INTERFACE_DEFINED__
#define __ICertPolicy_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertPolicy;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertPolicy : public IDispatch {
  public:
    virtual HRESULT WINAPI Initialize(const BSTR strConfig) = 0;
    virtual HRESULT WINAPI VerifyRequest(const BSTR strConfig,LONG Context,LONG bNewRequest,LONG Flags,LONG *pDisposition) = 0;
    virtual HRESULT WINAPI GetDescription(BSTR *pstrDescription) = 0;
    virtual HRESULT WINAPI ShutDown(void) = 0;
  };
#else
  typedef struct ICertPolicyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertPolicy *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertPolicy *This);
      ULONG (WINAPI *Release)(ICertPolicy *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertPolicy *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertPolicy *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertPolicy *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertPolicy *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Initialize)(ICertPolicy *This,const BSTR strConfig);
      HRESULT (WINAPI *VerifyRequest)(ICertPolicy *This,const BSTR strConfig,LONG Context,LONG bNewRequest,LONG Flags,LONG *pDisposition);
      HRESULT (WINAPI *GetDescription)(ICertPolicy *This,BSTR *pstrDescription);
      HRESULT (WINAPI *ShutDown)(ICertPolicy *This);
    END_INTERFACE
  } ICertPolicyVtbl;
  struct ICertPolicy {
    CONST_VTBL struct ICertPolicyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertPolicy_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertPolicy_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertPolicy_Release(This) (This)->lpVtbl->Release(This)
#define ICertPolicy_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertPolicy_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertPolicy_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertPolicy_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertPolicy_Initialize(This,strConfig) (This)->lpVtbl->Initialize(This,strConfig)
#define ICertPolicy_VerifyRequest(This,strConfig,Context,bNewRequest,Flags,pDisposition) (This)->lpVtbl->VerifyRequest(This,strConfig,Context,bNewRequest,Flags,pDisposition)
#define ICertPolicy_GetDescription(This,pstrDescription) (This)->lpVtbl->GetDescription(This,pstrDescription)
#define ICertPolicy_ShutDown(This) (This)->lpVtbl->ShutDown(This)
#endif
#endif
  HRESULT WINAPI ICertPolicy_Initialize_Proxy(ICertPolicy *This,const BSTR strConfig);
  void __RPC_STUB ICertPolicy_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertPolicy_VerifyRequest_Proxy(ICertPolicy *This,const BSTR strConfig,LONG Context,LONG bNewRequest,LONG Flags,LONG *pDisposition);
  void __RPC_STUB ICertPolicy_VerifyRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertPolicy_GetDescription_Proxy(ICertPolicy *This,BSTR *pstrDescription);
  void __RPC_STUB ICertPolicy_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertPolicy_ShutDown_Proxy(ICertPolicy *This);
  void __RPC_STUB ICertPolicy_ShutDown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertPolicy2_INTERFACE_DEFINED__
#define __ICertPolicy2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertPolicy2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertPolicy2 : public ICertPolicy {
  public:
    virtual HRESULT WINAPI GetManageModule(ICertManageModule **ppManageModule) = 0;
  };
#else
  typedef struct ICertPolicy2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertPolicy2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertPolicy2 *This);
      ULONG (WINAPI *Release)(ICertPolicy2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertPolicy2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertPolicy2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertPolicy2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertPolicy2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Initialize)(ICertPolicy2 *This,const BSTR strConfig);
      HRESULT (WINAPI *VerifyRequest)(ICertPolicy2 *This,const BSTR strConfig,LONG Context,LONG bNewRequest,LONG Flags,LONG *pDisposition);
      HRESULT (WINAPI *GetDescription)(ICertPolicy2 *This,BSTR *pstrDescription);
      HRESULT (WINAPI *ShutDown)(ICertPolicy2 *This);
      HRESULT (WINAPI *GetManageModule)(ICertPolicy2 *This,ICertManageModule **ppManageModule);
    END_INTERFACE
  } ICertPolicy2Vtbl;
  struct ICertPolicy2 {
    CONST_VTBL struct ICertPolicy2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertPolicy2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertPolicy2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertPolicy2_Release(This) (This)->lpVtbl->Release(This)
#define ICertPolicy2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertPolicy2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertPolicy2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertPolicy2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertPolicy2_Initialize(This,strConfig) (This)->lpVtbl->Initialize(This,strConfig)
#define ICertPolicy2_VerifyRequest(This,strConfig,Context,bNewRequest,Flags,pDisposition) (This)->lpVtbl->VerifyRequest(This,strConfig,Context,bNewRequest,Flags,pDisposition)
#define ICertPolicy2_GetDescription(This,pstrDescription) (This)->lpVtbl->GetDescription(This,pstrDescription)
#define ICertPolicy2_ShutDown(This) (This)->lpVtbl->ShutDown(This)
#define ICertPolicy2_GetManageModule(This,ppManageModule) (This)->lpVtbl->GetManageModule(This,ppManageModule)
#endif
#endif
  HRESULT WINAPI ICertPolicy2_GetManageModule_Proxy(ICertPolicy2 *This,ICertManageModule **ppManageModule);
  void __RPC_STUB ICertPolicy2_GetManageModule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
