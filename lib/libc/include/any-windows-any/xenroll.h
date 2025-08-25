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

#ifndef __xenroll_h__
#define __xenroll_h__

#ifndef __ICEnroll_FWD_DEFINED__
#define __ICEnroll_FWD_DEFINED__
typedef struct ICEnroll ICEnroll;
#endif

#ifndef __ICEnroll2_FWD_DEFINED__
#define __ICEnroll2_FWD_DEFINED__
typedef struct ICEnroll2 ICEnroll2;
#endif

#ifndef __ICEnroll3_FWD_DEFINED__
#define __ICEnroll3_FWD_DEFINED__
typedef struct ICEnroll3 ICEnroll3;
#endif

#ifndef __ICEnroll4_FWD_DEFINED__
#define __ICEnroll4_FWD_DEFINED__
typedef struct ICEnroll4 ICEnroll4;
#endif

#ifndef __IEnroll_FWD_DEFINED__
#define __IEnroll_FWD_DEFINED__
typedef struct IEnroll IEnroll;
#endif

#ifndef __IEnroll2_FWD_DEFINED__
#define __IEnroll2_FWD_DEFINED__
typedef struct IEnroll2 IEnroll2;
#endif

#ifndef __IEnroll4_FWD_DEFINED__
#define __IEnroll4_FWD_DEFINED__
typedef struct IEnroll4 IEnroll4;
#endif

#ifndef __CEnroll2_FWD_DEFINED__
#define __CEnroll2_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEnroll2 CEnroll2;
#else
typedef struct CEnroll2 CEnroll2;
#endif
#endif

#ifndef __CEnroll_FWD_DEFINED__
#define __CEnroll_FWD_DEFINED__
#ifdef __cplusplus
typedef class CEnroll CEnroll;
#else
typedef struct CEnroll CEnroll;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "wincrypt.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __ICEnroll_INTERFACE_DEFINED__
#define __ICEnroll_INTERFACE_DEFINED__

  extern const IID IID_ICEnroll;

#if defined(__cplusplus) && !defined(CINTERFACE)
#ifdef __cplusplus
}
#endif
  struct ICEnroll : public IDispatch {
  public:
    virtual HRESULT WINAPI createFilePKCS10(BSTR DNName,BSTR Usage,BSTR wszPKCS10FileName) = 0;
    virtual HRESULT WINAPI acceptFilePKCS7(BSTR wszPKCS7FileName) = 0;
    virtual HRESULT WINAPI createPKCS10(BSTR DNName,BSTR Usage,BSTR *pPKCS10) = 0;
    virtual HRESULT WINAPI acceptPKCS7(BSTR PKCS7) = 0;
    virtual HRESULT WINAPI getCertFromPKCS7(BSTR wszPKCS7,BSTR *pbstrCert) = 0;
    virtual HRESULT WINAPI enumProviders(LONG dwIndex,LONG dwFlags,BSTR *pbstrProvName) = 0;
    virtual HRESULT WINAPI enumContainers(LONG dwIndex,BSTR *pbstr) = 0;
    virtual HRESULT WINAPI freeRequestInfo(BSTR PKCS7OrPKCS10) = 0;
    virtual HRESULT WINAPI get_MyStoreName(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_MyStoreName(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_MyStoreType(BSTR *pbstrType) = 0;
    virtual HRESULT WINAPI put_MyStoreType(BSTR bstrType) = 0;
    virtual HRESULT WINAPI get_MyStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_MyStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_CAStoreName(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_CAStoreName(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_CAStoreType(BSTR *pbstrType) = 0;
    virtual HRESULT WINAPI put_CAStoreType(BSTR bstrType) = 0;
    virtual HRESULT WINAPI get_CAStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_CAStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_RootStoreName(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_RootStoreName(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_RootStoreType(BSTR *pbstrType) = 0;
    virtual HRESULT WINAPI put_RootStoreType(BSTR bstrType) = 0;
    virtual HRESULT WINAPI get_RootStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_RootStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_RequestStoreName(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_RequestStoreName(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_RequestStoreType(BSTR *pbstrType) = 0;
    virtual HRESULT WINAPI put_RequestStoreType(BSTR bstrType) = 0;
    virtual HRESULT WINAPI get_RequestStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_RequestStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_ContainerName(BSTR *pbstrContainer) = 0;
    virtual HRESULT WINAPI put_ContainerName(BSTR bstrContainer) = 0;
    virtual HRESULT WINAPI get_ProviderName(BSTR *pbstrProvider) = 0;
    virtual HRESULT WINAPI put_ProviderName(BSTR bstrProvider) = 0;
    virtual HRESULT WINAPI get_ProviderType(LONG *pdwType) = 0;
    virtual HRESULT WINAPI put_ProviderType(LONG dwType) = 0;
    virtual HRESULT WINAPI get_KeySpec(LONG *pdw) = 0;
    virtual HRESULT WINAPI put_KeySpec(LONG dw) = 0;
    virtual HRESULT WINAPI get_ProviderFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_ProviderFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_UseExistingKeySet(WINBOOL *fUseExistingKeys) = 0;
    virtual HRESULT WINAPI put_UseExistingKeySet(WINBOOL fUseExistingKeys) = 0;
    virtual HRESULT WINAPI get_GenKeyFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_GenKeyFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_DeleteRequestCert(WINBOOL *fDelete) = 0;
    virtual HRESULT WINAPI put_DeleteRequestCert(WINBOOL fDelete) = 0;
    virtual HRESULT WINAPI get_WriteCertToCSP(WINBOOL *fBool) = 0;
    virtual HRESULT WINAPI put_WriteCertToCSP(WINBOOL fBool) = 0;
    virtual HRESULT WINAPI get_SPCFileName(BSTR *pbstr) = 0;
    virtual HRESULT WINAPI put_SPCFileName(BSTR bstr) = 0;
    virtual HRESULT WINAPI get_PVKFileName(BSTR *pbstr) = 0;
    virtual HRESULT WINAPI put_PVKFileName(BSTR bstr) = 0;
    virtual HRESULT WINAPI get_HashAlgorithm(BSTR *pbstr) = 0;
    virtual HRESULT WINAPI put_HashAlgorithm(BSTR bstr) = 0;
  };
#ifdef __cplusplus
  extern "C" {
#endif
#else
  typedef struct ICEnrollVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICEnroll *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICEnroll *This);
      ULONG (WINAPI *Release)(ICEnroll *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICEnroll *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICEnroll *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICEnroll *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICEnroll *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *createFilePKCS10)(ICEnroll *This,BSTR DNName,BSTR Usage,BSTR wszPKCS10FileName);
      HRESULT (WINAPI *acceptFilePKCS7)(ICEnroll *This,BSTR wszPKCS7FileName);
      HRESULT (WINAPI *createPKCS10)(ICEnroll *This,BSTR DNName,BSTR Usage,BSTR *pPKCS10);
      HRESULT (WINAPI *acceptPKCS7)(ICEnroll *This,BSTR PKCS7);
      HRESULT (WINAPI *getCertFromPKCS7)(ICEnroll *This,BSTR wszPKCS7,BSTR *pbstrCert);
      HRESULT (WINAPI *enumProviders)(ICEnroll *This,LONG dwIndex,LONG dwFlags,BSTR *pbstrProvName);
      HRESULT (WINAPI *enumContainers)(ICEnroll *This,LONG dwIndex,BSTR *pbstr);
      HRESULT (WINAPI *freeRequestInfo)(ICEnroll *This,BSTR PKCS7OrPKCS10);
      HRESULT (WINAPI *get_MyStoreName)(ICEnroll *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_MyStoreName)(ICEnroll *This,BSTR bstrName);
      HRESULT (WINAPI *get_MyStoreType)(ICEnroll *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_MyStoreType)(ICEnroll *This,BSTR bstrType);
      HRESULT (WINAPI *get_MyStoreFlags)(ICEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_MyStoreFlags)(ICEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_CAStoreName)(ICEnroll *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_CAStoreName)(ICEnroll *This,BSTR bstrName);
      HRESULT (WINAPI *get_CAStoreType)(ICEnroll *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_CAStoreType)(ICEnroll *This,BSTR bstrType);
      HRESULT (WINAPI *get_CAStoreFlags)(ICEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_CAStoreFlags)(ICEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_RootStoreName)(ICEnroll *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RootStoreName)(ICEnroll *This,BSTR bstrName);
      HRESULT (WINAPI *get_RootStoreType)(ICEnroll *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RootStoreType)(ICEnroll *This,BSTR bstrType);
      HRESULT (WINAPI *get_RootStoreFlags)(ICEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RootStoreFlags)(ICEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_RequestStoreName)(ICEnroll *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RequestStoreName)(ICEnroll *This,BSTR bstrName);
      HRESULT (WINAPI *get_RequestStoreType)(ICEnroll *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RequestStoreType)(ICEnroll *This,BSTR bstrType);
      HRESULT (WINAPI *get_RequestStoreFlags)(ICEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RequestStoreFlags)(ICEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_ContainerName)(ICEnroll *This,BSTR *pbstrContainer);
      HRESULT (WINAPI *put_ContainerName)(ICEnroll *This,BSTR bstrContainer);
      HRESULT (WINAPI *get_ProviderName)(ICEnroll *This,BSTR *pbstrProvider);
      HRESULT (WINAPI *put_ProviderName)(ICEnroll *This,BSTR bstrProvider);
      HRESULT (WINAPI *get_ProviderType)(ICEnroll *This,LONG *pdwType);
      HRESULT (WINAPI *put_ProviderType)(ICEnroll *This,LONG dwType);
      HRESULT (WINAPI *get_KeySpec)(ICEnroll *This,LONG *pdw);
      HRESULT (WINAPI *put_KeySpec)(ICEnroll *This,LONG dw);
      HRESULT (WINAPI *get_ProviderFlags)(ICEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_ProviderFlags)(ICEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_UseExistingKeySet)(ICEnroll *This,WINBOOL *fUseExistingKeys);
      HRESULT (WINAPI *put_UseExistingKeySet)(ICEnroll *This,WINBOOL fUseExistingKeys);
      HRESULT (WINAPI *get_GenKeyFlags)(ICEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_GenKeyFlags)(ICEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_DeleteRequestCert)(ICEnroll *This,WINBOOL *fDelete);
      HRESULT (WINAPI *put_DeleteRequestCert)(ICEnroll *This,WINBOOL fDelete);
      HRESULT (WINAPI *get_WriteCertToCSP)(ICEnroll *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToCSP)(ICEnroll *This,WINBOOL fBool);
      HRESULT (WINAPI *get_SPCFileName)(ICEnroll *This,BSTR *pbstr);
      HRESULT (WINAPI *put_SPCFileName)(ICEnroll *This,BSTR bstr);
      HRESULT (WINAPI *get_PVKFileName)(ICEnroll *This,BSTR *pbstr);
      HRESULT (WINAPI *put_PVKFileName)(ICEnroll *This,BSTR bstr);
      HRESULT (WINAPI *get_HashAlgorithm)(ICEnroll *This,BSTR *pbstr);
      HRESULT (WINAPI *put_HashAlgorithm)(ICEnroll *This,BSTR bstr);
    END_INTERFACE
  } ICEnrollVtbl;
  struct ICEnroll {
    CONST_VTBL struct ICEnrollVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICEnroll_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICEnroll_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICEnroll_Release(This) (This)->lpVtbl->Release(This)
#define ICEnroll_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICEnroll_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICEnroll_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICEnroll_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICEnroll_createFilePKCS10(This,DNName,Usage,wszPKCS10FileName) (This)->lpVtbl->createFilePKCS10(This,DNName,Usage,wszPKCS10FileName)
#define ICEnroll_acceptFilePKCS7(This,wszPKCS7FileName) (This)->lpVtbl->acceptFilePKCS7(This,wszPKCS7FileName)
#define ICEnroll_createPKCS10(This,DNName,Usage,pPKCS10) (This)->lpVtbl->createPKCS10(This,DNName,Usage,pPKCS10)
#define ICEnroll_acceptPKCS7(This,PKCS7) (This)->lpVtbl->acceptPKCS7(This,PKCS7)
#define ICEnroll_getCertFromPKCS7(This,wszPKCS7,pbstrCert) (This)->lpVtbl->getCertFromPKCS7(This,wszPKCS7,pbstrCert)
#define ICEnroll_enumProviders(This,dwIndex,dwFlags,pbstrProvName) (This)->lpVtbl->enumProviders(This,dwIndex,dwFlags,pbstrProvName)
#define ICEnroll_enumContainers(This,dwIndex,pbstr) (This)->lpVtbl->enumContainers(This,dwIndex,pbstr)
#define ICEnroll_freeRequestInfo(This,PKCS7OrPKCS10) (This)->lpVtbl->freeRequestInfo(This,PKCS7OrPKCS10)
#define ICEnroll_get_MyStoreName(This,pbstrName) (This)->lpVtbl->get_MyStoreName(This,pbstrName)
#define ICEnroll_put_MyStoreName(This,bstrName) (This)->lpVtbl->put_MyStoreName(This,bstrName)
#define ICEnroll_get_MyStoreType(This,pbstrType) (This)->lpVtbl->get_MyStoreType(This,pbstrType)
#define ICEnroll_put_MyStoreType(This,bstrType) (This)->lpVtbl->put_MyStoreType(This,bstrType)
#define ICEnroll_get_MyStoreFlags(This,pdwFlags) (This)->lpVtbl->get_MyStoreFlags(This,pdwFlags)
#define ICEnroll_put_MyStoreFlags(This,dwFlags) (This)->lpVtbl->put_MyStoreFlags(This,dwFlags)
#define ICEnroll_get_CAStoreName(This,pbstrName) (This)->lpVtbl->get_CAStoreName(This,pbstrName)
#define ICEnroll_put_CAStoreName(This,bstrName) (This)->lpVtbl->put_CAStoreName(This,bstrName)
#define ICEnroll_get_CAStoreType(This,pbstrType) (This)->lpVtbl->get_CAStoreType(This,pbstrType)
#define ICEnroll_put_CAStoreType(This,bstrType) (This)->lpVtbl->put_CAStoreType(This,bstrType)
#define ICEnroll_get_CAStoreFlags(This,pdwFlags) (This)->lpVtbl->get_CAStoreFlags(This,pdwFlags)
#define ICEnroll_put_CAStoreFlags(This,dwFlags) (This)->lpVtbl->put_CAStoreFlags(This,dwFlags)
#define ICEnroll_get_RootStoreName(This,pbstrName) (This)->lpVtbl->get_RootStoreName(This,pbstrName)
#define ICEnroll_put_RootStoreName(This,bstrName) (This)->lpVtbl->put_RootStoreName(This,bstrName)
#define ICEnroll_get_RootStoreType(This,pbstrType) (This)->lpVtbl->get_RootStoreType(This,pbstrType)
#define ICEnroll_put_RootStoreType(This,bstrType) (This)->lpVtbl->put_RootStoreType(This,bstrType)
#define ICEnroll_get_RootStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RootStoreFlags(This,pdwFlags)
#define ICEnroll_put_RootStoreFlags(This,dwFlags) (This)->lpVtbl->put_RootStoreFlags(This,dwFlags)
#define ICEnroll_get_RequestStoreName(This,pbstrName) (This)->lpVtbl->get_RequestStoreName(This,pbstrName)
#define ICEnroll_put_RequestStoreName(This,bstrName) (This)->lpVtbl->put_RequestStoreName(This,bstrName)
#define ICEnroll_get_RequestStoreType(This,pbstrType) (This)->lpVtbl->get_RequestStoreType(This,pbstrType)
#define ICEnroll_put_RequestStoreType(This,bstrType) (This)->lpVtbl->put_RequestStoreType(This,bstrType)
#define ICEnroll_get_RequestStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RequestStoreFlags(This,pdwFlags)
#define ICEnroll_put_RequestStoreFlags(This,dwFlags) (This)->lpVtbl->put_RequestStoreFlags(This,dwFlags)
#define ICEnroll_get_ContainerName(This,pbstrContainer) (This)->lpVtbl->get_ContainerName(This,pbstrContainer)
#define ICEnroll_put_ContainerName(This,bstrContainer) (This)->lpVtbl->put_ContainerName(This,bstrContainer)
#define ICEnroll_get_ProviderName(This,pbstrProvider) (This)->lpVtbl->get_ProviderName(This,pbstrProvider)
#define ICEnroll_put_ProviderName(This,bstrProvider) (This)->lpVtbl->put_ProviderName(This,bstrProvider)
#define ICEnroll_get_ProviderType(This,pdwType) (This)->lpVtbl->get_ProviderType(This,pdwType)
#define ICEnroll_put_ProviderType(This,dwType) (This)->lpVtbl->put_ProviderType(This,dwType)
#define ICEnroll_get_KeySpec(This,pdw) (This)->lpVtbl->get_KeySpec(This,pdw)
#define ICEnroll_put_KeySpec(This,dw) (This)->lpVtbl->put_KeySpec(This,dw)
#define ICEnroll_get_ProviderFlags(This,pdwFlags) (This)->lpVtbl->get_ProviderFlags(This,pdwFlags)
#define ICEnroll_put_ProviderFlags(This,dwFlags) (This)->lpVtbl->put_ProviderFlags(This,dwFlags)
#define ICEnroll_get_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->get_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll_put_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->put_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll_get_GenKeyFlags(This,pdwFlags) (This)->lpVtbl->get_GenKeyFlags(This,pdwFlags)
#define ICEnroll_put_GenKeyFlags(This,dwFlags) (This)->lpVtbl->put_GenKeyFlags(This,dwFlags)
#define ICEnroll_get_DeleteRequestCert(This,fDelete) (This)->lpVtbl->get_DeleteRequestCert(This,fDelete)
#define ICEnroll_put_DeleteRequestCert(This,fDelete) (This)->lpVtbl->put_DeleteRequestCert(This,fDelete)
#define ICEnroll_get_WriteCertToCSP(This,fBool) (This)->lpVtbl->get_WriteCertToCSP(This,fBool)
#define ICEnroll_put_WriteCertToCSP(This,fBool) (This)->lpVtbl->put_WriteCertToCSP(This,fBool)
#define ICEnroll_get_SPCFileName(This,pbstr) (This)->lpVtbl->get_SPCFileName(This,pbstr)
#define ICEnroll_put_SPCFileName(This,bstr) (This)->lpVtbl->put_SPCFileName(This,bstr)
#define ICEnroll_get_PVKFileName(This,pbstr) (This)->lpVtbl->get_PVKFileName(This,pbstr)
#define ICEnroll_put_PVKFileName(This,bstr) (This)->lpVtbl->put_PVKFileName(This,bstr)
#define ICEnroll_get_HashAlgorithm(This,pbstr) (This)->lpVtbl->get_HashAlgorithm(This,pbstr)
#define ICEnroll_put_HashAlgorithm(This,bstr) (This)->lpVtbl->put_HashAlgorithm(This,bstr)
#endif
#endif
  HRESULT WINAPI ICEnroll_createFilePKCS10_Proxy(ICEnroll *This,BSTR DNName,BSTR Usage,BSTR wszPKCS10FileName);
  void __RPC_STUB ICEnroll_createFilePKCS10_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_acceptFilePKCS7_Proxy(ICEnroll *This,BSTR wszPKCS7FileName);
  void __RPC_STUB ICEnroll_acceptFilePKCS7_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_createPKCS10_Proxy(ICEnroll *This,BSTR DNName,BSTR Usage,BSTR *pPKCS10);
  void __RPC_STUB ICEnroll_createPKCS10_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_acceptPKCS7_Proxy(ICEnroll *This,BSTR PKCS7);
  void __RPC_STUB ICEnroll_acceptPKCS7_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_getCertFromPKCS7_Proxy(ICEnroll *This,BSTR wszPKCS7,BSTR *pbstrCert);
  void __RPC_STUB ICEnroll_getCertFromPKCS7_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_enumProviders_Proxy(ICEnroll *This,LONG dwIndex,LONG dwFlags,BSTR *pbstrProvName);
  void __RPC_STUB ICEnroll_enumProviders_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_enumContainers_Proxy(ICEnroll *This,LONG dwIndex,BSTR *pbstr);
  void __RPC_STUB ICEnroll_enumContainers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_freeRequestInfo_Proxy(ICEnroll *This,BSTR PKCS7OrPKCS10);
  void __RPC_STUB ICEnroll_freeRequestInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_MyStoreName_Proxy(ICEnroll *This,BSTR *pbstrName);
  void __RPC_STUB ICEnroll_get_MyStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_MyStoreName_Proxy(ICEnroll *This,BSTR bstrName);
  void __RPC_STUB ICEnroll_put_MyStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_MyStoreType_Proxy(ICEnroll *This,BSTR *pbstrType);
  void __RPC_STUB ICEnroll_get_MyStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_MyStoreType_Proxy(ICEnroll *This,BSTR bstrType);
  void __RPC_STUB ICEnroll_put_MyStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_MyStoreFlags_Proxy(ICEnroll *This,LONG *pdwFlags);
  void __RPC_STUB ICEnroll_get_MyStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_MyStoreFlags_Proxy(ICEnroll *This,LONG dwFlags);
  void __RPC_STUB ICEnroll_put_MyStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_CAStoreName_Proxy(ICEnroll *This,BSTR *pbstrName);
  void __RPC_STUB ICEnroll_get_CAStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_CAStoreName_Proxy(ICEnroll *This,BSTR bstrName);
  void __RPC_STUB ICEnroll_put_CAStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_CAStoreType_Proxy(ICEnroll *This,BSTR *pbstrType);
  void __RPC_STUB ICEnroll_get_CAStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_CAStoreType_Proxy(ICEnroll *This,BSTR bstrType);
  void __RPC_STUB ICEnroll_put_CAStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_CAStoreFlags_Proxy(ICEnroll *This,LONG *pdwFlags);
  void __RPC_STUB ICEnroll_get_CAStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_CAStoreFlags_Proxy(ICEnroll *This,LONG dwFlags);
  void __RPC_STUB ICEnroll_put_CAStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_RootStoreName_Proxy(ICEnroll *This,BSTR *pbstrName);
  void __RPC_STUB ICEnroll_get_RootStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_RootStoreName_Proxy(ICEnroll *This,BSTR bstrName);
  void __RPC_STUB ICEnroll_put_RootStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_RootStoreType_Proxy(ICEnroll *This,BSTR *pbstrType);
  void __RPC_STUB ICEnroll_get_RootStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_RootStoreType_Proxy(ICEnroll *This,BSTR bstrType);
  void __RPC_STUB ICEnroll_put_RootStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_RootStoreFlags_Proxy(ICEnroll *This,LONG *pdwFlags);
  void __RPC_STUB ICEnroll_get_RootStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_RootStoreFlags_Proxy(ICEnroll *This,LONG dwFlags);
  void __RPC_STUB ICEnroll_put_RootStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_RequestStoreName_Proxy(ICEnroll *This,BSTR *pbstrName);
  void __RPC_STUB ICEnroll_get_RequestStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_RequestStoreName_Proxy(ICEnroll *This,BSTR bstrName);
  void __RPC_STUB ICEnroll_put_RequestStoreName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_RequestStoreType_Proxy(ICEnroll *This,BSTR *pbstrType);
  void __RPC_STUB ICEnroll_get_RequestStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_RequestStoreType_Proxy(ICEnroll *This,BSTR bstrType);
  void __RPC_STUB ICEnroll_put_RequestStoreType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_RequestStoreFlags_Proxy(ICEnroll *This,LONG *pdwFlags);
  void __RPC_STUB ICEnroll_get_RequestStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_RequestStoreFlags_Proxy(ICEnroll *This,LONG dwFlags);
  void __RPC_STUB ICEnroll_put_RequestStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_ContainerName_Proxy(ICEnroll *This,BSTR *pbstrContainer);
  void __RPC_STUB ICEnroll_get_ContainerName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_ContainerName_Proxy(ICEnroll *This,BSTR bstrContainer);
  void __RPC_STUB ICEnroll_put_ContainerName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_ProviderName_Proxy(ICEnroll *This,BSTR *pbstrProvider);
  void __RPC_STUB ICEnroll_get_ProviderName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_ProviderName_Proxy(ICEnroll *This,BSTR bstrProvider);
  void __RPC_STUB ICEnroll_put_ProviderName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_ProviderType_Proxy(ICEnroll *This,LONG *pdwType);
  void __RPC_STUB ICEnroll_get_ProviderType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_ProviderType_Proxy(ICEnroll *This,LONG dwType);
  void __RPC_STUB ICEnroll_put_ProviderType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_KeySpec_Proxy(ICEnroll *This,LONG *pdw);
  void __RPC_STUB ICEnroll_get_KeySpec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_KeySpec_Proxy(ICEnroll *This,LONG dw);
  void __RPC_STUB ICEnroll_put_KeySpec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_ProviderFlags_Proxy(ICEnroll *This,LONG *pdwFlags);
  void __RPC_STUB ICEnroll_get_ProviderFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_ProviderFlags_Proxy(ICEnroll *This,LONG dwFlags);
  void __RPC_STUB ICEnroll_put_ProviderFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_UseExistingKeySet_Proxy(ICEnroll *This,WINBOOL *fUseExistingKeys);
  void __RPC_STUB ICEnroll_get_UseExistingKeySet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_UseExistingKeySet_Proxy(ICEnroll *This,WINBOOL fUseExistingKeys);
  void __RPC_STUB ICEnroll_put_UseExistingKeySet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_GenKeyFlags_Proxy(ICEnroll *This,LONG *pdwFlags);
  void __RPC_STUB ICEnroll_get_GenKeyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_GenKeyFlags_Proxy(ICEnroll *This,LONG dwFlags);
  void __RPC_STUB ICEnroll_put_GenKeyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_DeleteRequestCert_Proxy(ICEnroll *This,WINBOOL *fDelete);
  void __RPC_STUB ICEnroll_get_DeleteRequestCert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_DeleteRequestCert_Proxy(ICEnroll *This,WINBOOL fDelete);
  void __RPC_STUB ICEnroll_put_DeleteRequestCert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_WriteCertToCSP_Proxy(ICEnroll *This,WINBOOL *fBool);
  void __RPC_STUB ICEnroll_get_WriteCertToCSP_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_WriteCertToCSP_Proxy(ICEnroll *This,WINBOOL fBool);
  void __RPC_STUB ICEnroll_put_WriteCertToCSP_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_SPCFileName_Proxy(ICEnroll *This,BSTR *pbstr);
  void __RPC_STUB ICEnroll_get_SPCFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_SPCFileName_Proxy(ICEnroll *This,BSTR bstr);
  void __RPC_STUB ICEnroll_put_SPCFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_PVKFileName_Proxy(ICEnroll *This,BSTR *pbstr);
  void __RPC_STUB ICEnroll_get_PVKFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_PVKFileName_Proxy(ICEnroll *This,BSTR bstr);
  void __RPC_STUB ICEnroll_put_PVKFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_get_HashAlgorithm_Proxy(ICEnroll *This,BSTR *pbstr);
  void __RPC_STUB ICEnroll_get_HashAlgorithm_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll_put_HashAlgorithm_Proxy(ICEnroll *This,BSTR bstr);
  void __RPC_STUB ICEnroll_put_HashAlgorithm_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICEnroll2_INTERFACE_DEFINED__
#define __ICEnroll2_INTERFACE_DEFINED__
  extern const IID IID_ICEnroll2;
#if defined(__cplusplus) && !defined(CINTERFACE)
#ifdef __cplusplus
}
#endif
  struct ICEnroll2 : public ICEnroll {
  public:
    virtual HRESULT WINAPI addCertTypeToRequest(BSTR CertType) = 0;
    virtual HRESULT WINAPI addNameValuePairToSignature(BSTR Name,BSTR Value) = 0;
    virtual HRESULT WINAPI get_WriteCertToUserDS(WINBOOL *fBool) = 0;
    virtual HRESULT WINAPI put_WriteCertToUserDS(WINBOOL fBool) = 0;
    virtual HRESULT WINAPI get_EnableT61DNEncoding(WINBOOL *fBool) = 0;
    virtual HRESULT WINAPI put_EnableT61DNEncoding(WINBOOL fBool) = 0;
  };
#ifdef __cplusplus
  extern "C" {
#endif
#else
  typedef struct ICEnroll2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICEnroll2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICEnroll2 *This);
      ULONG (WINAPI *Release)(ICEnroll2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICEnroll2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICEnroll2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICEnroll2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICEnroll2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *createFilePKCS10)(ICEnroll2 *This,BSTR DNName,BSTR Usage,BSTR wszPKCS10FileName);
      HRESULT (WINAPI *acceptFilePKCS7)(ICEnroll2 *This,BSTR wszPKCS7FileName);
      HRESULT (WINAPI *createPKCS10)(ICEnroll2 *This,BSTR DNName,BSTR Usage,BSTR *pPKCS10);
      HRESULT (WINAPI *acceptPKCS7)(ICEnroll2 *This,BSTR PKCS7);
      HRESULT (WINAPI *getCertFromPKCS7)(ICEnroll2 *This,BSTR wszPKCS7,BSTR *pbstrCert);
      HRESULT (WINAPI *enumProviders)(ICEnroll2 *This,LONG dwIndex,LONG dwFlags,BSTR *pbstrProvName);
      HRESULT (WINAPI *enumContainers)(ICEnroll2 *This,LONG dwIndex,BSTR *pbstr);
      HRESULT (WINAPI *freeRequestInfo)(ICEnroll2 *This,BSTR PKCS7OrPKCS10);
      HRESULT (WINAPI *get_MyStoreName)(ICEnroll2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_MyStoreName)(ICEnroll2 *This,BSTR bstrName);
      HRESULT (WINAPI *get_MyStoreType)(ICEnroll2 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_MyStoreType)(ICEnroll2 *This,BSTR bstrType);
      HRESULT (WINAPI *get_MyStoreFlags)(ICEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_MyStoreFlags)(ICEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_CAStoreName)(ICEnroll2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_CAStoreName)(ICEnroll2 *This,BSTR bstrName);
      HRESULT (WINAPI *get_CAStoreType)(ICEnroll2 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_CAStoreType)(ICEnroll2 *This,BSTR bstrType);
      HRESULT (WINAPI *get_CAStoreFlags)(ICEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_CAStoreFlags)(ICEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RootStoreName)(ICEnroll2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RootStoreName)(ICEnroll2 *This,BSTR bstrName);
      HRESULT (WINAPI *get_RootStoreType)(ICEnroll2 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RootStoreType)(ICEnroll2 *This,BSTR bstrType);
      HRESULT (WINAPI *get_RootStoreFlags)(ICEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RootStoreFlags)(ICEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RequestStoreName)(ICEnroll2 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RequestStoreName)(ICEnroll2 *This,BSTR bstrName);
      HRESULT (WINAPI *get_RequestStoreType)(ICEnroll2 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RequestStoreType)(ICEnroll2 *This,BSTR bstrType);
      HRESULT (WINAPI *get_RequestStoreFlags)(ICEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RequestStoreFlags)(ICEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_ContainerName)(ICEnroll2 *This,BSTR *pbstrContainer);
      HRESULT (WINAPI *put_ContainerName)(ICEnroll2 *This,BSTR bstrContainer);
      HRESULT (WINAPI *get_ProviderName)(ICEnroll2 *This,BSTR *pbstrProvider);
      HRESULT (WINAPI *put_ProviderName)(ICEnroll2 *This,BSTR bstrProvider);
      HRESULT (WINAPI *get_ProviderType)(ICEnroll2 *This,LONG *pdwType);
      HRESULT (WINAPI *put_ProviderType)(ICEnroll2 *This,LONG dwType);
      HRESULT (WINAPI *get_KeySpec)(ICEnroll2 *This,LONG *pdw);
      HRESULT (WINAPI *put_KeySpec)(ICEnroll2 *This,LONG dw);
      HRESULT (WINAPI *get_ProviderFlags)(ICEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_ProviderFlags)(ICEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_UseExistingKeySet)(ICEnroll2 *This,WINBOOL *fUseExistingKeys);
      HRESULT (WINAPI *put_UseExistingKeySet)(ICEnroll2 *This,WINBOOL fUseExistingKeys);
      HRESULT (WINAPI *get_GenKeyFlags)(ICEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_GenKeyFlags)(ICEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_DeleteRequestCert)(ICEnroll2 *This,WINBOOL *fDelete);
      HRESULT (WINAPI *put_DeleteRequestCert)(ICEnroll2 *This,WINBOOL fDelete);
      HRESULT (WINAPI *get_WriteCertToCSP)(ICEnroll2 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToCSP)(ICEnroll2 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_SPCFileName)(ICEnroll2 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_SPCFileName)(ICEnroll2 *This,BSTR bstr);
      HRESULT (WINAPI *get_PVKFileName)(ICEnroll2 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_PVKFileName)(ICEnroll2 *This,BSTR bstr);
      HRESULT (WINAPI *get_HashAlgorithm)(ICEnroll2 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_HashAlgorithm)(ICEnroll2 *This,BSTR bstr);
      HRESULT (WINAPI *addCertTypeToRequest)(ICEnroll2 *This,BSTR CertType);
      HRESULT (WINAPI *addNameValuePairToSignature)(ICEnroll2 *This,BSTR Name,BSTR Value);
      HRESULT (WINAPI *get_WriteCertToUserDS)(ICEnroll2 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToUserDS)(ICEnroll2 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_EnableT61DNEncoding)(ICEnroll2 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_EnableT61DNEncoding)(ICEnroll2 *This,WINBOOL fBool);
    END_INTERFACE
  } ICEnroll2Vtbl;
  struct ICEnroll2 {
    CONST_VTBL struct ICEnroll2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICEnroll2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICEnroll2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICEnroll2_Release(This) (This)->lpVtbl->Release(This)
#define ICEnroll2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICEnroll2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICEnroll2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICEnroll2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICEnroll2_createFilePKCS10(This,DNName,Usage,wszPKCS10FileName) (This)->lpVtbl->createFilePKCS10(This,DNName,Usage,wszPKCS10FileName)
#define ICEnroll2_acceptFilePKCS7(This,wszPKCS7FileName) (This)->lpVtbl->acceptFilePKCS7(This,wszPKCS7FileName)
#define ICEnroll2_createPKCS10(This,DNName,Usage,pPKCS10) (This)->lpVtbl->createPKCS10(This,DNName,Usage,pPKCS10)
#define ICEnroll2_acceptPKCS7(This,PKCS7) (This)->lpVtbl->acceptPKCS7(This,PKCS7)
#define ICEnroll2_getCertFromPKCS7(This,wszPKCS7,pbstrCert) (This)->lpVtbl->getCertFromPKCS7(This,wszPKCS7,pbstrCert)
#define ICEnroll2_enumProviders(This,dwIndex,dwFlags,pbstrProvName) (This)->lpVtbl->enumProviders(This,dwIndex,dwFlags,pbstrProvName)
#define ICEnroll2_enumContainers(This,dwIndex,pbstr) (This)->lpVtbl->enumContainers(This,dwIndex,pbstr)
#define ICEnroll2_freeRequestInfo(This,PKCS7OrPKCS10) (This)->lpVtbl->freeRequestInfo(This,PKCS7OrPKCS10)
#define ICEnroll2_get_MyStoreName(This,pbstrName) (This)->lpVtbl->get_MyStoreName(This,pbstrName)
#define ICEnroll2_put_MyStoreName(This,bstrName) (This)->lpVtbl->put_MyStoreName(This,bstrName)
#define ICEnroll2_get_MyStoreType(This,pbstrType) (This)->lpVtbl->get_MyStoreType(This,pbstrType)
#define ICEnroll2_put_MyStoreType(This,bstrType) (This)->lpVtbl->put_MyStoreType(This,bstrType)
#define ICEnroll2_get_MyStoreFlags(This,pdwFlags) (This)->lpVtbl->get_MyStoreFlags(This,pdwFlags)
#define ICEnroll2_put_MyStoreFlags(This,dwFlags) (This)->lpVtbl->put_MyStoreFlags(This,dwFlags)
#define ICEnroll2_get_CAStoreName(This,pbstrName) (This)->lpVtbl->get_CAStoreName(This,pbstrName)
#define ICEnroll2_put_CAStoreName(This,bstrName) (This)->lpVtbl->put_CAStoreName(This,bstrName)
#define ICEnroll2_get_CAStoreType(This,pbstrType) (This)->lpVtbl->get_CAStoreType(This,pbstrType)
#define ICEnroll2_put_CAStoreType(This,bstrType) (This)->lpVtbl->put_CAStoreType(This,bstrType)
#define ICEnroll2_get_CAStoreFlags(This,pdwFlags) (This)->lpVtbl->get_CAStoreFlags(This,pdwFlags)
#define ICEnroll2_put_CAStoreFlags(This,dwFlags) (This)->lpVtbl->put_CAStoreFlags(This,dwFlags)
#define ICEnroll2_get_RootStoreName(This,pbstrName) (This)->lpVtbl->get_RootStoreName(This,pbstrName)
#define ICEnroll2_put_RootStoreName(This,bstrName) (This)->lpVtbl->put_RootStoreName(This,bstrName)
#define ICEnroll2_get_RootStoreType(This,pbstrType) (This)->lpVtbl->get_RootStoreType(This,pbstrType)
#define ICEnroll2_put_RootStoreType(This,bstrType) (This)->lpVtbl->put_RootStoreType(This,bstrType)
#define ICEnroll2_get_RootStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RootStoreFlags(This,pdwFlags)
#define ICEnroll2_put_RootStoreFlags(This,dwFlags) (This)->lpVtbl->put_RootStoreFlags(This,dwFlags)
#define ICEnroll2_get_RequestStoreName(This,pbstrName) (This)->lpVtbl->get_RequestStoreName(This,pbstrName)
#define ICEnroll2_put_RequestStoreName(This,bstrName) (This)->lpVtbl->put_RequestStoreName(This,bstrName)
#define ICEnroll2_get_RequestStoreType(This,pbstrType) (This)->lpVtbl->get_RequestStoreType(This,pbstrType)
#define ICEnroll2_put_RequestStoreType(This,bstrType) (This)->lpVtbl->put_RequestStoreType(This,bstrType)
#define ICEnroll2_get_RequestStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RequestStoreFlags(This,pdwFlags)
#define ICEnroll2_put_RequestStoreFlags(This,dwFlags) (This)->lpVtbl->put_RequestStoreFlags(This,dwFlags)
#define ICEnroll2_get_ContainerName(This,pbstrContainer) (This)->lpVtbl->get_ContainerName(This,pbstrContainer)
#define ICEnroll2_put_ContainerName(This,bstrContainer) (This)->lpVtbl->put_ContainerName(This,bstrContainer)
#define ICEnroll2_get_ProviderName(This,pbstrProvider) (This)->lpVtbl->get_ProviderName(This,pbstrProvider)
#define ICEnroll2_put_ProviderName(This,bstrProvider) (This)->lpVtbl->put_ProviderName(This,bstrProvider)
#define ICEnroll2_get_ProviderType(This,pdwType) (This)->lpVtbl->get_ProviderType(This,pdwType)
#define ICEnroll2_put_ProviderType(This,dwType) (This)->lpVtbl->put_ProviderType(This,dwType)
#define ICEnroll2_get_KeySpec(This,pdw) (This)->lpVtbl->get_KeySpec(This,pdw)
#define ICEnroll2_put_KeySpec(This,dw) (This)->lpVtbl->put_KeySpec(This,dw)
#define ICEnroll2_get_ProviderFlags(This,pdwFlags) (This)->lpVtbl->get_ProviderFlags(This,pdwFlags)
#define ICEnroll2_put_ProviderFlags(This,dwFlags) (This)->lpVtbl->put_ProviderFlags(This,dwFlags)
#define ICEnroll2_get_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->get_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll2_put_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->put_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll2_get_GenKeyFlags(This,pdwFlags) (This)->lpVtbl->get_GenKeyFlags(This,pdwFlags)
#define ICEnroll2_put_GenKeyFlags(This,dwFlags) (This)->lpVtbl->put_GenKeyFlags(This,dwFlags)
#define ICEnroll2_get_DeleteRequestCert(This,fDelete) (This)->lpVtbl->get_DeleteRequestCert(This,fDelete)
#define ICEnroll2_put_DeleteRequestCert(This,fDelete) (This)->lpVtbl->put_DeleteRequestCert(This,fDelete)
#define ICEnroll2_get_WriteCertToCSP(This,fBool) (This)->lpVtbl->get_WriteCertToCSP(This,fBool)
#define ICEnroll2_put_WriteCertToCSP(This,fBool) (This)->lpVtbl->put_WriteCertToCSP(This,fBool)
#define ICEnroll2_get_SPCFileName(This,pbstr) (This)->lpVtbl->get_SPCFileName(This,pbstr)
#define ICEnroll2_put_SPCFileName(This,bstr) (This)->lpVtbl->put_SPCFileName(This,bstr)
#define ICEnroll2_get_PVKFileName(This,pbstr) (This)->lpVtbl->get_PVKFileName(This,pbstr)
#define ICEnroll2_put_PVKFileName(This,bstr) (This)->lpVtbl->put_PVKFileName(This,bstr)
#define ICEnroll2_get_HashAlgorithm(This,pbstr) (This)->lpVtbl->get_HashAlgorithm(This,pbstr)
#define ICEnroll2_put_HashAlgorithm(This,bstr) (This)->lpVtbl->put_HashAlgorithm(This,bstr)
#define ICEnroll2_addCertTypeToRequest(This,CertType) (This)->lpVtbl->addCertTypeToRequest(This,CertType)
#define ICEnroll2_addNameValuePairToSignature(This,Name,Value) (This)->lpVtbl->addNameValuePairToSignature(This,Name,Value)
#define ICEnroll2_get_WriteCertToUserDS(This,fBool) (This)->lpVtbl->get_WriteCertToUserDS(This,fBool)
#define ICEnroll2_put_WriteCertToUserDS(This,fBool) (This)->lpVtbl->put_WriteCertToUserDS(This,fBool)
#define ICEnroll2_get_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->get_EnableT61DNEncoding(This,fBool)
#define ICEnroll2_put_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->put_EnableT61DNEncoding(This,fBool)
#endif
#endif
  HRESULT WINAPI ICEnroll2_addCertTypeToRequest_Proxy(ICEnroll2 *This,BSTR CertType);
  void __RPC_STUB ICEnroll2_addCertTypeToRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll2_addNameValuePairToSignature_Proxy(ICEnroll2 *This,BSTR Name,BSTR Value);
  void __RPC_STUB ICEnroll2_addNameValuePairToSignature_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll2_get_WriteCertToUserDS_Proxy(ICEnroll2 *This,WINBOOL *fBool);
  void __RPC_STUB ICEnroll2_get_WriteCertToUserDS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll2_put_WriteCertToUserDS_Proxy(ICEnroll2 *This,WINBOOL fBool);
  void __RPC_STUB ICEnroll2_put_WriteCertToUserDS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll2_get_EnableT61DNEncoding_Proxy(ICEnroll2 *This,WINBOOL *fBool);
  void __RPC_STUB ICEnroll2_get_EnableT61DNEncoding_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll2_put_EnableT61DNEncoding_Proxy(ICEnroll2 *This,WINBOOL fBool);
  void __RPC_STUB ICEnroll2_put_EnableT61DNEncoding_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICEnroll3_INTERFACE_DEFINED__
#define __ICEnroll3_INTERFACE_DEFINED__
  extern const IID IID_ICEnroll3;
#if defined(__cplusplus) && !defined(CINTERFACE)
#ifdef __cplusplus
}
#endif
  struct ICEnroll3 : public ICEnroll2 {
  public:
    virtual HRESULT WINAPI InstallPKCS7(BSTR PKCS7) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI GetSupportedKeySpec(LONG *pdwKeySpec) = 0;
    virtual HRESULT WINAPI GetKeyLen(WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize) = 0;
    virtual HRESULT WINAPI EnumAlgs(LONG dwIndex,LONG algClass,LONG *pdwAlgID) = 0;
    virtual HRESULT WINAPI GetAlgName(LONG algID,BSTR *pbstr) = 0;
    virtual HRESULT WINAPI put_ReuseHardwareKeyIfUnableToGenNew(WINBOOL fReuseHardwareKeyIfUnableToGenNew) = 0;
    virtual HRESULT WINAPI get_ReuseHardwareKeyIfUnableToGenNew(WINBOOL *fReuseHardwareKeyIfUnableToGenNew) = 0;
    virtual HRESULT WINAPI put_HashAlgID(LONG hashAlgID) = 0;
    virtual HRESULT WINAPI get_HashAlgID(LONG *hashAlgID) = 0;
    virtual HRESULT WINAPI put_LimitExchangeKeyToEncipherment(WINBOOL fLimitExchangeKeyToEncipherment) = 0;
    virtual HRESULT WINAPI get_LimitExchangeKeyToEncipherment(WINBOOL *fLimitExchangeKeyToEncipherment) = 0;
    virtual HRESULT WINAPI put_EnableSMIMECapabilities(WINBOOL fEnableSMIMECapabilities) = 0;
    virtual HRESULT WINAPI get_EnableSMIMECapabilities(WINBOOL *fEnableSMIMECapabilities) = 0;
  };
#ifdef __cplusplus
  extern "C" {
#endif
#else
  typedef struct ICEnroll3Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICEnroll3 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICEnroll3 *This);
      ULONG (WINAPI *Release)(ICEnroll3 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICEnroll3 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICEnroll3 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICEnroll3 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICEnroll3 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *createFilePKCS10)(ICEnroll3 *This,BSTR DNName,BSTR Usage,BSTR wszPKCS10FileName);
      HRESULT (WINAPI *acceptFilePKCS7)(ICEnroll3 *This,BSTR wszPKCS7FileName);
      HRESULT (WINAPI *createPKCS10)(ICEnroll3 *This,BSTR DNName,BSTR Usage,BSTR *pPKCS10);
      HRESULT (WINAPI *acceptPKCS7)(ICEnroll3 *This,BSTR PKCS7);
      HRESULT (WINAPI *getCertFromPKCS7)(ICEnroll3 *This,BSTR wszPKCS7,BSTR *pbstrCert);
      HRESULT (WINAPI *enumProviders)(ICEnroll3 *This,LONG dwIndex,LONG dwFlags,BSTR *pbstrProvName);
      HRESULT (WINAPI *enumContainers)(ICEnroll3 *This,LONG dwIndex,BSTR *pbstr);
      HRESULT (WINAPI *freeRequestInfo)(ICEnroll3 *This,BSTR PKCS7OrPKCS10);
      HRESULT (WINAPI *get_MyStoreName)(ICEnroll3 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_MyStoreName)(ICEnroll3 *This,BSTR bstrName);
      HRESULT (WINAPI *get_MyStoreType)(ICEnroll3 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_MyStoreType)(ICEnroll3 *This,BSTR bstrType);
      HRESULT (WINAPI *get_MyStoreFlags)(ICEnroll3 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_MyStoreFlags)(ICEnroll3 *This,LONG dwFlags);
      HRESULT (WINAPI *get_CAStoreName)(ICEnroll3 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_CAStoreName)(ICEnroll3 *This,BSTR bstrName);
      HRESULT (WINAPI *get_CAStoreType)(ICEnroll3 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_CAStoreType)(ICEnroll3 *This,BSTR bstrType);
      HRESULT (WINAPI *get_CAStoreFlags)(ICEnroll3 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_CAStoreFlags)(ICEnroll3 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RootStoreName)(ICEnroll3 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RootStoreName)(ICEnroll3 *This,BSTR bstrName);
      HRESULT (WINAPI *get_RootStoreType)(ICEnroll3 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RootStoreType)(ICEnroll3 *This,BSTR bstrType);
      HRESULT (WINAPI *get_RootStoreFlags)(ICEnroll3 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RootStoreFlags)(ICEnroll3 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RequestStoreName)(ICEnroll3 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RequestStoreName)(ICEnroll3 *This,BSTR bstrName);
      HRESULT (WINAPI *get_RequestStoreType)(ICEnroll3 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RequestStoreType)(ICEnroll3 *This,BSTR bstrType);
      HRESULT (WINAPI *get_RequestStoreFlags)(ICEnroll3 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RequestStoreFlags)(ICEnroll3 *This,LONG dwFlags);
      HRESULT (WINAPI *get_ContainerName)(ICEnroll3 *This,BSTR *pbstrContainer);
      HRESULT (WINAPI *put_ContainerName)(ICEnroll3 *This,BSTR bstrContainer);
      HRESULT (WINAPI *get_ProviderName)(ICEnroll3 *This,BSTR *pbstrProvider);
      HRESULT (WINAPI *put_ProviderName)(ICEnroll3 *This,BSTR bstrProvider);
      HRESULT (WINAPI *get_ProviderType)(ICEnroll3 *This,LONG *pdwType);
      HRESULT (WINAPI *put_ProviderType)(ICEnroll3 *This,LONG dwType);
      HRESULT (WINAPI *get_KeySpec)(ICEnroll3 *This,LONG *pdw);
      HRESULT (WINAPI *put_KeySpec)(ICEnroll3 *This,LONG dw);
      HRESULT (WINAPI *get_ProviderFlags)(ICEnroll3 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_ProviderFlags)(ICEnroll3 *This,LONG dwFlags);
      HRESULT (WINAPI *get_UseExistingKeySet)(ICEnroll3 *This,WINBOOL *fUseExistingKeys);
      HRESULT (WINAPI *put_UseExistingKeySet)(ICEnroll3 *This,WINBOOL fUseExistingKeys);
      HRESULT (WINAPI *get_GenKeyFlags)(ICEnroll3 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_GenKeyFlags)(ICEnroll3 *This,LONG dwFlags);
      HRESULT (WINAPI *get_DeleteRequestCert)(ICEnroll3 *This,WINBOOL *fDelete);
      HRESULT (WINAPI *put_DeleteRequestCert)(ICEnroll3 *This,WINBOOL fDelete);
      HRESULT (WINAPI *get_WriteCertToCSP)(ICEnroll3 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToCSP)(ICEnroll3 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_SPCFileName)(ICEnroll3 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_SPCFileName)(ICEnroll3 *This,BSTR bstr);
      HRESULT (WINAPI *get_PVKFileName)(ICEnroll3 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_PVKFileName)(ICEnroll3 *This,BSTR bstr);
      HRESULT (WINAPI *get_HashAlgorithm)(ICEnroll3 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_HashAlgorithm)(ICEnroll3 *This,BSTR bstr);
      HRESULT (WINAPI *addCertTypeToRequest)(ICEnroll3 *This,BSTR CertType);
      HRESULT (WINAPI *addNameValuePairToSignature)(ICEnroll3 *This,BSTR Name,BSTR Value);
      HRESULT (WINAPI *get_WriteCertToUserDS)(ICEnroll3 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToUserDS)(ICEnroll3 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_EnableT61DNEncoding)(ICEnroll3 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_EnableT61DNEncoding)(ICEnroll3 *This,WINBOOL fBool);
      HRESULT (WINAPI *InstallPKCS7)(ICEnroll3 *This,BSTR PKCS7);
      HRESULT (WINAPI *Reset)(ICEnroll3 *This);
      HRESULT (WINAPI *GetSupportedKeySpec)(ICEnroll3 *This,LONG *pdwKeySpec);
      HRESULT (WINAPI *GetKeyLen)(ICEnroll3 *This,WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize);
      HRESULT (WINAPI *EnumAlgs)(ICEnroll3 *This,LONG dwIndex,LONG algClass,LONG *pdwAlgID);
      HRESULT (WINAPI *GetAlgName)(ICEnroll3 *This,LONG algID,BSTR *pbstr);
      HRESULT (WINAPI *put_ReuseHardwareKeyIfUnableToGenNew)(ICEnroll3 *This,WINBOOL fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *get_ReuseHardwareKeyIfUnableToGenNew)(ICEnroll3 *This,WINBOOL *fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *put_HashAlgID)(ICEnroll3 *This,LONG hashAlgID);
      HRESULT (WINAPI *get_HashAlgID)(ICEnroll3 *This,LONG *hashAlgID);
      HRESULT (WINAPI *put_LimitExchangeKeyToEncipherment)(ICEnroll3 *This,WINBOOL fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *get_LimitExchangeKeyToEncipherment)(ICEnroll3 *This,WINBOOL *fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *put_EnableSMIMECapabilities)(ICEnroll3 *This,WINBOOL fEnableSMIMECapabilities);
      HRESULT (WINAPI *get_EnableSMIMECapabilities)(ICEnroll3 *This,WINBOOL *fEnableSMIMECapabilities);
    END_INTERFACE
  } ICEnroll3Vtbl;
  struct ICEnroll3 {
    CONST_VTBL struct ICEnroll3Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICEnroll3_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICEnroll3_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICEnroll3_Release(This) (This)->lpVtbl->Release(This)
#define ICEnroll3_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICEnroll3_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICEnroll3_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICEnroll3_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICEnroll3_createFilePKCS10(This,DNName,Usage,wszPKCS10FileName) (This)->lpVtbl->createFilePKCS10(This,DNName,Usage,wszPKCS10FileName)
#define ICEnroll3_acceptFilePKCS7(This,wszPKCS7FileName) (This)->lpVtbl->acceptFilePKCS7(This,wszPKCS7FileName)
#define ICEnroll3_createPKCS10(This,DNName,Usage,pPKCS10) (This)->lpVtbl->createPKCS10(This,DNName,Usage,pPKCS10)
#define ICEnroll3_acceptPKCS7(This,PKCS7) (This)->lpVtbl->acceptPKCS7(This,PKCS7)
#define ICEnroll3_getCertFromPKCS7(This,wszPKCS7,pbstrCert) (This)->lpVtbl->getCertFromPKCS7(This,wszPKCS7,pbstrCert)
#define ICEnroll3_enumProviders(This,dwIndex,dwFlags,pbstrProvName) (This)->lpVtbl->enumProviders(This,dwIndex,dwFlags,pbstrProvName)
#define ICEnroll3_enumContainers(This,dwIndex,pbstr) (This)->lpVtbl->enumContainers(This,dwIndex,pbstr)
#define ICEnroll3_freeRequestInfo(This,PKCS7OrPKCS10) (This)->lpVtbl->freeRequestInfo(This,PKCS7OrPKCS10)
#define ICEnroll3_get_MyStoreName(This,pbstrName) (This)->lpVtbl->get_MyStoreName(This,pbstrName)
#define ICEnroll3_put_MyStoreName(This,bstrName) (This)->lpVtbl->put_MyStoreName(This,bstrName)
#define ICEnroll3_get_MyStoreType(This,pbstrType) (This)->lpVtbl->get_MyStoreType(This,pbstrType)
#define ICEnroll3_put_MyStoreType(This,bstrType) (This)->lpVtbl->put_MyStoreType(This,bstrType)
#define ICEnroll3_get_MyStoreFlags(This,pdwFlags) (This)->lpVtbl->get_MyStoreFlags(This,pdwFlags)
#define ICEnroll3_put_MyStoreFlags(This,dwFlags) (This)->lpVtbl->put_MyStoreFlags(This,dwFlags)
#define ICEnroll3_get_CAStoreName(This,pbstrName) (This)->lpVtbl->get_CAStoreName(This,pbstrName)
#define ICEnroll3_put_CAStoreName(This,bstrName) (This)->lpVtbl->put_CAStoreName(This,bstrName)
#define ICEnroll3_get_CAStoreType(This,pbstrType) (This)->lpVtbl->get_CAStoreType(This,pbstrType)
#define ICEnroll3_put_CAStoreType(This,bstrType) (This)->lpVtbl->put_CAStoreType(This,bstrType)
#define ICEnroll3_get_CAStoreFlags(This,pdwFlags) (This)->lpVtbl->get_CAStoreFlags(This,pdwFlags)
#define ICEnroll3_put_CAStoreFlags(This,dwFlags) (This)->lpVtbl->put_CAStoreFlags(This,dwFlags)
#define ICEnroll3_get_RootStoreName(This,pbstrName) (This)->lpVtbl->get_RootStoreName(This,pbstrName)
#define ICEnroll3_put_RootStoreName(This,bstrName) (This)->lpVtbl->put_RootStoreName(This,bstrName)
#define ICEnroll3_get_RootStoreType(This,pbstrType) (This)->lpVtbl->get_RootStoreType(This,pbstrType)
#define ICEnroll3_put_RootStoreType(This,bstrType) (This)->lpVtbl->put_RootStoreType(This,bstrType)
#define ICEnroll3_get_RootStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RootStoreFlags(This,pdwFlags)
#define ICEnroll3_put_RootStoreFlags(This,dwFlags) (This)->lpVtbl->put_RootStoreFlags(This,dwFlags)
#define ICEnroll3_get_RequestStoreName(This,pbstrName) (This)->lpVtbl->get_RequestStoreName(This,pbstrName)
#define ICEnroll3_put_RequestStoreName(This,bstrName) (This)->lpVtbl->put_RequestStoreName(This,bstrName)
#define ICEnroll3_get_RequestStoreType(This,pbstrType) (This)->lpVtbl->get_RequestStoreType(This,pbstrType)
#define ICEnroll3_put_RequestStoreType(This,bstrType) (This)->lpVtbl->put_RequestStoreType(This,bstrType)
#define ICEnroll3_get_RequestStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RequestStoreFlags(This,pdwFlags)
#define ICEnroll3_put_RequestStoreFlags(This,dwFlags) (This)->lpVtbl->put_RequestStoreFlags(This,dwFlags)
#define ICEnroll3_get_ContainerName(This,pbstrContainer) (This)->lpVtbl->get_ContainerName(This,pbstrContainer)
#define ICEnroll3_put_ContainerName(This,bstrContainer) (This)->lpVtbl->put_ContainerName(This,bstrContainer)
#define ICEnroll3_get_ProviderName(This,pbstrProvider) (This)->lpVtbl->get_ProviderName(This,pbstrProvider)
#define ICEnroll3_put_ProviderName(This,bstrProvider) (This)->lpVtbl->put_ProviderName(This,bstrProvider)
#define ICEnroll3_get_ProviderType(This,pdwType) (This)->lpVtbl->get_ProviderType(This,pdwType)
#define ICEnroll3_put_ProviderType(This,dwType) (This)->lpVtbl->put_ProviderType(This,dwType)
#define ICEnroll3_get_KeySpec(This,pdw) (This)->lpVtbl->get_KeySpec(This,pdw)
#define ICEnroll3_put_KeySpec(This,dw) (This)->lpVtbl->put_KeySpec(This,dw)
#define ICEnroll3_get_ProviderFlags(This,pdwFlags) (This)->lpVtbl->get_ProviderFlags(This,pdwFlags)
#define ICEnroll3_put_ProviderFlags(This,dwFlags) (This)->lpVtbl->put_ProviderFlags(This,dwFlags)
#define ICEnroll3_get_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->get_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll3_put_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->put_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll3_get_GenKeyFlags(This,pdwFlags) (This)->lpVtbl->get_GenKeyFlags(This,pdwFlags)
#define ICEnroll3_put_GenKeyFlags(This,dwFlags) (This)->lpVtbl->put_GenKeyFlags(This,dwFlags)
#define ICEnroll3_get_DeleteRequestCert(This,fDelete) (This)->lpVtbl->get_DeleteRequestCert(This,fDelete)
#define ICEnroll3_put_DeleteRequestCert(This,fDelete) (This)->lpVtbl->put_DeleteRequestCert(This,fDelete)
#define ICEnroll3_get_WriteCertToCSP(This,fBool) (This)->lpVtbl->get_WriteCertToCSP(This,fBool)
#define ICEnroll3_put_WriteCertToCSP(This,fBool) (This)->lpVtbl->put_WriteCertToCSP(This,fBool)
#define ICEnroll3_get_SPCFileName(This,pbstr) (This)->lpVtbl->get_SPCFileName(This,pbstr)
#define ICEnroll3_put_SPCFileName(This,bstr) (This)->lpVtbl->put_SPCFileName(This,bstr)
#define ICEnroll3_get_PVKFileName(This,pbstr) (This)->lpVtbl->get_PVKFileName(This,pbstr)
#define ICEnroll3_put_PVKFileName(This,bstr) (This)->lpVtbl->put_PVKFileName(This,bstr)
#define ICEnroll3_get_HashAlgorithm(This,pbstr) (This)->lpVtbl->get_HashAlgorithm(This,pbstr)
#define ICEnroll3_put_HashAlgorithm(This,bstr) (This)->lpVtbl->put_HashAlgorithm(This,bstr)
#define ICEnroll3_addCertTypeToRequest(This,CertType) (This)->lpVtbl->addCertTypeToRequest(This,CertType)
#define ICEnroll3_addNameValuePairToSignature(This,Name,Value) (This)->lpVtbl->addNameValuePairToSignature(This,Name,Value)
#define ICEnroll3_get_WriteCertToUserDS(This,fBool) (This)->lpVtbl->get_WriteCertToUserDS(This,fBool)
#define ICEnroll3_put_WriteCertToUserDS(This,fBool) (This)->lpVtbl->put_WriteCertToUserDS(This,fBool)
#define ICEnroll3_get_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->get_EnableT61DNEncoding(This,fBool)
#define ICEnroll3_put_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->put_EnableT61DNEncoding(This,fBool)
#define ICEnroll3_InstallPKCS7(This,PKCS7) (This)->lpVtbl->InstallPKCS7(This,PKCS7)
#define ICEnroll3_Reset(This) (This)->lpVtbl->Reset(This)
#define ICEnroll3_GetSupportedKeySpec(This,pdwKeySpec) (This)->lpVtbl->GetSupportedKeySpec(This,pdwKeySpec)
#define ICEnroll3_GetKeyLen(This,fMin,fExchange,pdwKeySize) (This)->lpVtbl->GetKeyLen(This,fMin,fExchange,pdwKeySize)
#define ICEnroll3_EnumAlgs(This,dwIndex,algClass,pdwAlgID) (This)->lpVtbl->EnumAlgs(This,dwIndex,algClass,pdwAlgID)
#define ICEnroll3_GetAlgName(This,algID,pbstr) (This)->lpVtbl->GetAlgName(This,algID,pbstr)
#define ICEnroll3_put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define ICEnroll3_get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define ICEnroll3_put_HashAlgID(This,hashAlgID) (This)->lpVtbl->put_HashAlgID(This,hashAlgID)
#define ICEnroll3_get_HashAlgID(This,hashAlgID) (This)->lpVtbl->get_HashAlgID(This,hashAlgID)
#define ICEnroll3_put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define ICEnroll3_get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define ICEnroll3_put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#define ICEnroll3_get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#endif
#endif
  HRESULT WINAPI ICEnroll3_InstallPKCS7_Proxy(ICEnroll3 *This,BSTR PKCS7);
  void __RPC_STUB ICEnroll3_InstallPKCS7_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_Reset_Proxy(ICEnroll3 *This);
  void __RPC_STUB ICEnroll3_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_GetSupportedKeySpec_Proxy(ICEnroll3 *This,LONG *pdwKeySpec);
  void __RPC_STUB ICEnroll3_GetSupportedKeySpec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_GetKeyLen_Proxy(ICEnroll3 *This,WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize);
  void __RPC_STUB ICEnroll3_GetKeyLen_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_EnumAlgs_Proxy(ICEnroll3 *This,LONG dwIndex,LONG algClass,LONG *pdwAlgID);
  void __RPC_STUB ICEnroll3_EnumAlgs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_GetAlgName_Proxy(ICEnroll3 *This,LONG algID,BSTR *pbstr);
  void __RPC_STUB ICEnroll3_GetAlgName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_put_ReuseHardwareKeyIfUnableToGenNew_Proxy(ICEnroll3 *This,WINBOOL fReuseHardwareKeyIfUnableToGenNew);
  void __RPC_STUB ICEnroll3_put_ReuseHardwareKeyIfUnableToGenNew_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_get_ReuseHardwareKeyIfUnableToGenNew_Proxy(ICEnroll3 *This,WINBOOL *fReuseHardwareKeyIfUnableToGenNew);
  void __RPC_STUB ICEnroll3_get_ReuseHardwareKeyIfUnableToGenNew_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_put_HashAlgID_Proxy(ICEnroll3 *This,LONG hashAlgID);
  void __RPC_STUB ICEnroll3_put_HashAlgID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_get_HashAlgID_Proxy(ICEnroll3 *This,LONG *hashAlgID);
  void __RPC_STUB ICEnroll3_get_HashAlgID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_put_LimitExchangeKeyToEncipherment_Proxy(ICEnroll3 *This,WINBOOL fLimitExchangeKeyToEncipherment);
  void __RPC_STUB ICEnroll3_put_LimitExchangeKeyToEncipherment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_get_LimitExchangeKeyToEncipherment_Proxy(ICEnroll3 *This,WINBOOL *fLimitExchangeKeyToEncipherment);
  void __RPC_STUB ICEnroll3_get_LimitExchangeKeyToEncipherment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_put_EnableSMIMECapabilities_Proxy(ICEnroll3 *This,WINBOOL fEnableSMIMECapabilities);
  void __RPC_STUB ICEnroll3_put_EnableSMIMECapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll3_get_EnableSMIMECapabilities_Proxy(ICEnroll3 *This,WINBOOL *fEnableSMIMECapabilities);
  void __RPC_STUB ICEnroll3_get_EnableSMIMECapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICEnroll4_INTERFACE_DEFINED__
#define __ICEnroll4_INTERFACE_DEFINED__
  extern const IID IID_ICEnroll4;
#if defined(__cplusplus) && !defined(CINTERFACE)
#ifdef __cplusplus
}
#endif
  struct ICEnroll4 : public ICEnroll3 {
  public:
    virtual HRESULT WINAPI put_PrivateKeyArchiveCertificate(BSTR bstrCert) = 0;
    virtual HRESULT WINAPI get_PrivateKeyArchiveCertificate(BSTR *pbstrCert) = 0;
    virtual HRESULT WINAPI put_ThumbPrint(BSTR bstrThumbPrint) = 0;
    virtual HRESULT WINAPI get_ThumbPrint(BSTR *pbstrThumbPrint) = 0;
    virtual HRESULT WINAPI binaryToString(LONG Flags,BSTR strBinary,BSTR *pstrEncoded) = 0;
    virtual HRESULT WINAPI stringToBinary(LONG Flags,BSTR strEncoded,BSTR *pstrBinary) = 0;
    virtual HRESULT WINAPI addExtensionToRequest(LONG Flags,BSTR strName,BSTR strValue) = 0;
    virtual HRESULT WINAPI addAttributeToRequest(LONG Flags,BSTR strName,BSTR strValue) = 0;
    virtual HRESULT WINAPI addNameValuePairToRequest(LONG Flags,BSTR strName,BSTR strValue) = 0;
    virtual HRESULT WINAPI resetExtensions(void) = 0;
    virtual HRESULT WINAPI resetAttributes(void) = 0;
    virtual HRESULT WINAPI createRequest(LONG Flags,BSTR strDNName,BSTR Usage,BSTR *pstrRequest) = 0;
    virtual HRESULT WINAPI createFileRequest(LONG Flags,BSTR strDNName,BSTR strUsage,BSTR strRequestFileName) = 0;
    virtual HRESULT WINAPI acceptResponse(BSTR strResponse) = 0;
    virtual HRESULT WINAPI acceptFileResponse(BSTR strResponseFileName) = 0;
    virtual HRESULT WINAPI getCertFromResponse(BSTR strResponse,BSTR *pstrCert) = 0;
    virtual HRESULT WINAPI getCertFromFileResponse(BSTR strResponseFileName,BSTR *pstrCert) = 0;
    virtual HRESULT WINAPI createPFX(BSTR strPassword,BSTR *pstrPFX) = 0;
    virtual HRESULT WINAPI createFilePFX(BSTR strPassword,BSTR strPFXFileName) = 0;
    virtual HRESULT WINAPI setPendingRequestInfo(LONG lRequestID,BSTR strCADNS,BSTR strCAName,BSTR strFriendlyName) = 0;
    virtual HRESULT WINAPI enumPendingRequest(LONG lIndex,LONG lDesiredProperty,VARIANT *pvarProperty) = 0;
    virtual HRESULT WINAPI removePendingRequest(BSTR strThumbprint) = 0;
    virtual HRESULT WINAPI GetKeyLenEx(LONG lSizeSpec,LONG lKeySpec,LONG *pdwKeySize) = 0;
    virtual HRESULT WINAPI InstallPKCS7Ex(BSTR PKCS7,LONG *plCertInstalled) = 0;
    virtual HRESULT WINAPI addCertTypeToRequestEx(LONG lType,BSTR bstrOIDOrName,LONG lMajorVersion,WINBOOL fMinorVersion,LONG lMinorVersion) = 0;
    virtual HRESULT WINAPI getProviderType(BSTR strProvName,LONG *plProvType) = 0;
    virtual HRESULT WINAPI put_SignerCertificate(BSTR bstrCert) = 0;
    virtual HRESULT WINAPI put_ClientId(LONG lClientId) = 0;
    virtual HRESULT WINAPI get_ClientId(LONG *plClientId) = 0;
    virtual HRESULT WINAPI addBlobPropertyToCertificate(LONG lPropertyId,LONG lReserved,BSTR bstrProperty) = 0;
    virtual HRESULT WINAPI resetBlobProperties(void) = 0;
    virtual HRESULT WINAPI put_IncludeSubjectKeyID(WINBOOL fInclude) = 0;
    virtual HRESULT WINAPI get_IncludeSubjectKeyID(WINBOOL *pfInclude) = 0;
  };
#ifdef __cplusplus
  extern "C" {
#endif
#else
  typedef struct ICEnroll4Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICEnroll4 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICEnroll4 *This);
      ULONG (WINAPI *Release)(ICEnroll4 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICEnroll4 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICEnroll4 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICEnroll4 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICEnroll4 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *createFilePKCS10)(ICEnroll4 *This,BSTR DNName,BSTR Usage,BSTR wszPKCS10FileName);
      HRESULT (WINAPI *acceptFilePKCS7)(ICEnroll4 *This,BSTR wszPKCS7FileName);
      HRESULT (WINAPI *createPKCS10)(ICEnroll4 *This,BSTR DNName,BSTR Usage,BSTR *pPKCS10);
      HRESULT (WINAPI *acceptPKCS7)(ICEnroll4 *This,BSTR PKCS7);
      HRESULT (WINAPI *getCertFromPKCS7)(ICEnroll4 *This,BSTR wszPKCS7,BSTR *pbstrCert);
      HRESULT (WINAPI *enumProviders)(ICEnroll4 *This,LONG dwIndex,LONG dwFlags,BSTR *pbstrProvName);
      HRESULT (WINAPI *enumContainers)(ICEnroll4 *This,LONG dwIndex,BSTR *pbstr);
      HRESULT (WINAPI *freeRequestInfo)(ICEnroll4 *This,BSTR PKCS7OrPKCS10);
      HRESULT (WINAPI *get_MyStoreName)(ICEnroll4 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_MyStoreName)(ICEnroll4 *This,BSTR bstrName);
      HRESULT (WINAPI *get_MyStoreType)(ICEnroll4 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_MyStoreType)(ICEnroll4 *This,BSTR bstrType);
      HRESULT (WINAPI *get_MyStoreFlags)(ICEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_MyStoreFlags)(ICEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_CAStoreName)(ICEnroll4 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_CAStoreName)(ICEnroll4 *This,BSTR bstrName);
      HRESULT (WINAPI *get_CAStoreType)(ICEnroll4 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_CAStoreType)(ICEnroll4 *This,BSTR bstrType);
      HRESULT (WINAPI *get_CAStoreFlags)(ICEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_CAStoreFlags)(ICEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RootStoreName)(ICEnroll4 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RootStoreName)(ICEnroll4 *This,BSTR bstrName);
      HRESULT (WINAPI *get_RootStoreType)(ICEnroll4 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RootStoreType)(ICEnroll4 *This,BSTR bstrType);
      HRESULT (WINAPI *get_RootStoreFlags)(ICEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RootStoreFlags)(ICEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RequestStoreName)(ICEnroll4 *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_RequestStoreName)(ICEnroll4 *This,BSTR bstrName);
      HRESULT (WINAPI *get_RequestStoreType)(ICEnroll4 *This,BSTR *pbstrType);
      HRESULT (WINAPI *put_RequestStoreType)(ICEnroll4 *This,BSTR bstrType);
      HRESULT (WINAPI *get_RequestStoreFlags)(ICEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RequestStoreFlags)(ICEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_ContainerName)(ICEnroll4 *This,BSTR *pbstrContainer);
      HRESULT (WINAPI *put_ContainerName)(ICEnroll4 *This,BSTR bstrContainer);
      HRESULT (WINAPI *get_ProviderName)(ICEnroll4 *This,BSTR *pbstrProvider);
      HRESULT (WINAPI *put_ProviderName)(ICEnroll4 *This,BSTR bstrProvider);
      HRESULT (WINAPI *get_ProviderType)(ICEnroll4 *This,LONG *pdwType);
      HRESULT (WINAPI *put_ProviderType)(ICEnroll4 *This,LONG dwType);
      HRESULT (WINAPI *get_KeySpec)(ICEnroll4 *This,LONG *pdw);
      HRESULT (WINAPI *put_KeySpec)(ICEnroll4 *This,LONG dw);
      HRESULT (WINAPI *get_ProviderFlags)(ICEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_ProviderFlags)(ICEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_UseExistingKeySet)(ICEnroll4 *This,WINBOOL *fUseExistingKeys);
      HRESULT (WINAPI *put_UseExistingKeySet)(ICEnroll4 *This,WINBOOL fUseExistingKeys);
      HRESULT (WINAPI *get_GenKeyFlags)(ICEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_GenKeyFlags)(ICEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_DeleteRequestCert)(ICEnroll4 *This,WINBOOL *fDelete);
      HRESULT (WINAPI *put_DeleteRequestCert)(ICEnroll4 *This,WINBOOL fDelete);
      HRESULT (WINAPI *get_WriteCertToCSP)(ICEnroll4 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToCSP)(ICEnroll4 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_SPCFileName)(ICEnroll4 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_SPCFileName)(ICEnroll4 *This,BSTR bstr);
      HRESULT (WINAPI *get_PVKFileName)(ICEnroll4 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_PVKFileName)(ICEnroll4 *This,BSTR bstr);
      HRESULT (WINAPI *get_HashAlgorithm)(ICEnroll4 *This,BSTR *pbstr);
      HRESULT (WINAPI *put_HashAlgorithm)(ICEnroll4 *This,BSTR bstr);
      HRESULT (WINAPI *addCertTypeToRequest)(ICEnroll4 *This,BSTR CertType);
      HRESULT (WINAPI *addNameValuePairToSignature)(ICEnroll4 *This,BSTR Name,BSTR Value);
      HRESULT (WINAPI *get_WriteCertToUserDS)(ICEnroll4 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToUserDS)(ICEnroll4 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_EnableT61DNEncoding)(ICEnroll4 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_EnableT61DNEncoding)(ICEnroll4 *This,WINBOOL fBool);
      HRESULT (WINAPI *InstallPKCS7)(ICEnroll4 *This,BSTR PKCS7);
      HRESULT (WINAPI *Reset)(ICEnroll4 *This);
      HRESULT (WINAPI *GetSupportedKeySpec)(ICEnroll4 *This,LONG *pdwKeySpec);
      HRESULT (WINAPI *GetKeyLen)(ICEnroll4 *This,WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize);
      HRESULT (WINAPI *EnumAlgs)(ICEnroll4 *This,LONG dwIndex,LONG algClass,LONG *pdwAlgID);
      HRESULT (WINAPI *GetAlgName)(ICEnroll4 *This,LONG algID,BSTR *pbstr);
      HRESULT (WINAPI *put_ReuseHardwareKeyIfUnableToGenNew)(ICEnroll4 *This,WINBOOL fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *get_ReuseHardwareKeyIfUnableToGenNew)(ICEnroll4 *This,WINBOOL *fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *put_HashAlgID)(ICEnroll4 *This,LONG hashAlgID);
      HRESULT (WINAPI *get_HashAlgID)(ICEnroll4 *This,LONG *hashAlgID);
      HRESULT (WINAPI *put_LimitExchangeKeyToEncipherment)(ICEnroll4 *This,WINBOOL fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *get_LimitExchangeKeyToEncipherment)(ICEnroll4 *This,WINBOOL *fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *put_EnableSMIMECapabilities)(ICEnroll4 *This,WINBOOL fEnableSMIMECapabilities);
      HRESULT (WINAPI *get_EnableSMIMECapabilities)(ICEnroll4 *This,WINBOOL *fEnableSMIMECapabilities);
      HRESULT (WINAPI *put_PrivateKeyArchiveCertificate)(ICEnroll4 *This,BSTR bstrCert);
      HRESULT (WINAPI *get_PrivateKeyArchiveCertificate)(ICEnroll4 *This,BSTR *pbstrCert);
      HRESULT (WINAPI *put_ThumbPrint)(ICEnroll4 *This,BSTR bstrThumbPrint);
      HRESULT (WINAPI *get_ThumbPrint)(ICEnroll4 *This,BSTR *pbstrThumbPrint);
      HRESULT (WINAPI *binaryToString)(ICEnroll4 *This,LONG Flags,BSTR strBinary,BSTR *pstrEncoded);
      HRESULT (WINAPI *stringToBinary)(ICEnroll4 *This,LONG Flags,BSTR strEncoded,BSTR *pstrBinary);
      HRESULT (WINAPI *addExtensionToRequest)(ICEnroll4 *This,LONG Flags,BSTR strName,BSTR strValue);
      HRESULT (WINAPI *addAttributeToRequest)(ICEnroll4 *This,LONG Flags,BSTR strName,BSTR strValue);
      HRESULT (WINAPI *addNameValuePairToRequest)(ICEnroll4 *This,LONG Flags,BSTR strName,BSTR strValue);
      HRESULT (WINAPI *resetExtensions)(ICEnroll4 *This);
      HRESULT (WINAPI *resetAttributes)(ICEnroll4 *This);
      HRESULT (WINAPI *createRequest)(ICEnroll4 *This,LONG Flags,BSTR strDNName,BSTR Usage,BSTR *pstrRequest);
      HRESULT (WINAPI *createFileRequest)(ICEnroll4 *This,LONG Flags,BSTR strDNName,BSTR strUsage,BSTR strRequestFileName);
      HRESULT (WINAPI *acceptResponse)(ICEnroll4 *This,BSTR strResponse);
      HRESULT (WINAPI *acceptFileResponse)(ICEnroll4 *This,BSTR strResponseFileName);
      HRESULT (WINAPI *getCertFromResponse)(ICEnroll4 *This,BSTR strResponse,BSTR *pstrCert);
      HRESULT (WINAPI *getCertFromFileResponse)(ICEnroll4 *This,BSTR strResponseFileName,BSTR *pstrCert);
      HRESULT (WINAPI *createPFX)(ICEnroll4 *This,BSTR strPassword,BSTR *pstrPFX);
      HRESULT (WINAPI *createFilePFX)(ICEnroll4 *This,BSTR strPassword,BSTR strPFXFileName);
      HRESULT (WINAPI *setPendingRequestInfo)(ICEnroll4 *This,LONG lRequestID,BSTR strCADNS,BSTR strCAName,BSTR strFriendlyName);
      HRESULT (WINAPI *enumPendingRequest)(ICEnroll4 *This,LONG lIndex,LONG lDesiredProperty,VARIANT *pvarProperty);
      HRESULT (WINAPI *removePendingRequest)(ICEnroll4 *This,BSTR strThumbprint);
      HRESULT (WINAPI *GetKeyLenEx)(ICEnroll4 *This,LONG lSizeSpec,LONG lKeySpec,LONG *pdwKeySize);
      HRESULT (WINAPI *InstallPKCS7Ex)(ICEnroll4 *This,BSTR PKCS7,LONG *plCertInstalled);
      HRESULT (WINAPI *addCertTypeToRequestEx)(ICEnroll4 *This,LONG lType,BSTR bstrOIDOrName,LONG lMajorVersion,WINBOOL fMinorVersion,LONG lMinorVersion);
      HRESULT (WINAPI *getProviderType)(ICEnroll4 *This,BSTR strProvName,LONG *plProvType);
      HRESULT (WINAPI *put_SignerCertificate)(ICEnroll4 *This,BSTR bstrCert);
      HRESULT (WINAPI *put_ClientId)(ICEnroll4 *This,LONG lClientId);
      HRESULT (WINAPI *get_ClientId)(ICEnroll4 *This,LONG *plClientId);
      HRESULT (WINAPI *addBlobPropertyToCertificate)(ICEnroll4 *This,LONG lPropertyId,LONG lReserved,BSTR bstrProperty);
      HRESULT (WINAPI *resetBlobProperties)(ICEnroll4 *This);
      HRESULT (WINAPI *put_IncludeSubjectKeyID)(ICEnroll4 *This,WINBOOL fInclude);
      HRESULT (WINAPI *get_IncludeSubjectKeyID)(ICEnroll4 *This,WINBOOL *pfInclude);
    END_INTERFACE
  } ICEnroll4Vtbl;
  struct ICEnroll4 {
    CONST_VTBL struct ICEnroll4Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICEnroll4_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICEnroll4_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICEnroll4_Release(This) (This)->lpVtbl->Release(This)
#define ICEnroll4_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICEnroll4_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICEnroll4_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICEnroll4_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICEnroll4_createFilePKCS10(This,DNName,Usage,wszPKCS10FileName) (This)->lpVtbl->createFilePKCS10(This,DNName,Usage,wszPKCS10FileName)
#define ICEnroll4_acceptFilePKCS7(This,wszPKCS7FileName) (This)->lpVtbl->acceptFilePKCS7(This,wszPKCS7FileName)
#define ICEnroll4_createPKCS10(This,DNName,Usage,pPKCS10) (This)->lpVtbl->createPKCS10(This,DNName,Usage,pPKCS10)
#define ICEnroll4_acceptPKCS7(This,PKCS7) (This)->lpVtbl->acceptPKCS7(This,PKCS7)
#define ICEnroll4_getCertFromPKCS7(This,wszPKCS7,pbstrCert) (This)->lpVtbl->getCertFromPKCS7(This,wszPKCS7,pbstrCert)
#define ICEnroll4_enumProviders(This,dwIndex,dwFlags,pbstrProvName) (This)->lpVtbl->enumProviders(This,dwIndex,dwFlags,pbstrProvName)
#define ICEnroll4_enumContainers(This,dwIndex,pbstr) (This)->lpVtbl->enumContainers(This,dwIndex,pbstr)
#define ICEnroll4_freeRequestInfo(This,PKCS7OrPKCS10) (This)->lpVtbl->freeRequestInfo(This,PKCS7OrPKCS10)
#define ICEnroll4_get_MyStoreName(This,pbstrName) (This)->lpVtbl->get_MyStoreName(This,pbstrName)
#define ICEnroll4_put_MyStoreName(This,bstrName) (This)->lpVtbl->put_MyStoreName(This,bstrName)
#define ICEnroll4_get_MyStoreType(This,pbstrType) (This)->lpVtbl->get_MyStoreType(This,pbstrType)
#define ICEnroll4_put_MyStoreType(This,bstrType) (This)->lpVtbl->put_MyStoreType(This,bstrType)
#define ICEnroll4_get_MyStoreFlags(This,pdwFlags) (This)->lpVtbl->get_MyStoreFlags(This,pdwFlags)
#define ICEnroll4_put_MyStoreFlags(This,dwFlags) (This)->lpVtbl->put_MyStoreFlags(This,dwFlags)
#define ICEnroll4_get_CAStoreName(This,pbstrName) (This)->lpVtbl->get_CAStoreName(This,pbstrName)
#define ICEnroll4_put_CAStoreName(This,bstrName) (This)->lpVtbl->put_CAStoreName(This,bstrName)
#define ICEnroll4_get_CAStoreType(This,pbstrType) (This)->lpVtbl->get_CAStoreType(This,pbstrType)
#define ICEnroll4_put_CAStoreType(This,bstrType) (This)->lpVtbl->put_CAStoreType(This,bstrType)
#define ICEnroll4_get_CAStoreFlags(This,pdwFlags) (This)->lpVtbl->get_CAStoreFlags(This,pdwFlags)
#define ICEnroll4_put_CAStoreFlags(This,dwFlags) (This)->lpVtbl->put_CAStoreFlags(This,dwFlags)
#define ICEnroll4_get_RootStoreName(This,pbstrName) (This)->lpVtbl->get_RootStoreName(This,pbstrName)
#define ICEnroll4_put_RootStoreName(This,bstrName) (This)->lpVtbl->put_RootStoreName(This,bstrName)
#define ICEnroll4_get_RootStoreType(This,pbstrType) (This)->lpVtbl->get_RootStoreType(This,pbstrType)
#define ICEnroll4_put_RootStoreType(This,bstrType) (This)->lpVtbl->put_RootStoreType(This,bstrType)
#define ICEnroll4_get_RootStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RootStoreFlags(This,pdwFlags)
#define ICEnroll4_put_RootStoreFlags(This,dwFlags) (This)->lpVtbl->put_RootStoreFlags(This,dwFlags)
#define ICEnroll4_get_RequestStoreName(This,pbstrName) (This)->lpVtbl->get_RequestStoreName(This,pbstrName)
#define ICEnroll4_put_RequestStoreName(This,bstrName) (This)->lpVtbl->put_RequestStoreName(This,bstrName)
#define ICEnroll4_get_RequestStoreType(This,pbstrType) (This)->lpVtbl->get_RequestStoreType(This,pbstrType)
#define ICEnroll4_put_RequestStoreType(This,bstrType) (This)->lpVtbl->put_RequestStoreType(This,bstrType)
#define ICEnroll4_get_RequestStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RequestStoreFlags(This,pdwFlags)
#define ICEnroll4_put_RequestStoreFlags(This,dwFlags) (This)->lpVtbl->put_RequestStoreFlags(This,dwFlags)
#define ICEnroll4_get_ContainerName(This,pbstrContainer) (This)->lpVtbl->get_ContainerName(This,pbstrContainer)
#define ICEnroll4_put_ContainerName(This,bstrContainer) (This)->lpVtbl->put_ContainerName(This,bstrContainer)
#define ICEnroll4_get_ProviderName(This,pbstrProvider) (This)->lpVtbl->get_ProviderName(This,pbstrProvider)
#define ICEnroll4_put_ProviderName(This,bstrProvider) (This)->lpVtbl->put_ProviderName(This,bstrProvider)
#define ICEnroll4_get_ProviderType(This,pdwType) (This)->lpVtbl->get_ProviderType(This,pdwType)
#define ICEnroll4_put_ProviderType(This,dwType) (This)->lpVtbl->put_ProviderType(This,dwType)
#define ICEnroll4_get_KeySpec(This,pdw) (This)->lpVtbl->get_KeySpec(This,pdw)
#define ICEnroll4_put_KeySpec(This,dw) (This)->lpVtbl->put_KeySpec(This,dw)
#define ICEnroll4_get_ProviderFlags(This,pdwFlags) (This)->lpVtbl->get_ProviderFlags(This,pdwFlags)
#define ICEnroll4_put_ProviderFlags(This,dwFlags) (This)->lpVtbl->put_ProviderFlags(This,dwFlags)
#define ICEnroll4_get_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->get_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll4_put_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->put_UseExistingKeySet(This,fUseExistingKeys)
#define ICEnroll4_get_GenKeyFlags(This,pdwFlags) (This)->lpVtbl->get_GenKeyFlags(This,pdwFlags)
#define ICEnroll4_put_GenKeyFlags(This,dwFlags) (This)->lpVtbl->put_GenKeyFlags(This,dwFlags)
#define ICEnroll4_get_DeleteRequestCert(This,fDelete) (This)->lpVtbl->get_DeleteRequestCert(This,fDelete)
#define ICEnroll4_put_DeleteRequestCert(This,fDelete) (This)->lpVtbl->put_DeleteRequestCert(This,fDelete)
#define ICEnroll4_get_WriteCertToCSP(This,fBool) (This)->lpVtbl->get_WriteCertToCSP(This,fBool)
#define ICEnroll4_put_WriteCertToCSP(This,fBool) (This)->lpVtbl->put_WriteCertToCSP(This,fBool)
#define ICEnroll4_get_SPCFileName(This,pbstr) (This)->lpVtbl->get_SPCFileName(This,pbstr)
#define ICEnroll4_put_SPCFileName(This,bstr) (This)->lpVtbl->put_SPCFileName(This,bstr)
#define ICEnroll4_get_PVKFileName(This,pbstr) (This)->lpVtbl->get_PVKFileName(This,pbstr)
#define ICEnroll4_put_PVKFileName(This,bstr) (This)->lpVtbl->put_PVKFileName(This,bstr)
#define ICEnroll4_get_HashAlgorithm(This,pbstr) (This)->lpVtbl->get_HashAlgorithm(This,pbstr)
#define ICEnroll4_put_HashAlgorithm(This,bstr) (This)->lpVtbl->put_HashAlgorithm(This,bstr)
#define ICEnroll4_addCertTypeToRequest(This,CertType) (This)->lpVtbl->addCertTypeToRequest(This,CertType)
#define ICEnroll4_addNameValuePairToSignature(This,Name,Value) (This)->lpVtbl->addNameValuePairToSignature(This,Name,Value)
#define ICEnroll4_get_WriteCertToUserDS(This,fBool) (This)->lpVtbl->get_WriteCertToUserDS(This,fBool)
#define ICEnroll4_put_WriteCertToUserDS(This,fBool) (This)->lpVtbl->put_WriteCertToUserDS(This,fBool)
#define ICEnroll4_get_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->get_EnableT61DNEncoding(This,fBool)
#define ICEnroll4_put_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->put_EnableT61DNEncoding(This,fBool)
#define ICEnroll4_InstallPKCS7(This,PKCS7) (This)->lpVtbl->InstallPKCS7(This,PKCS7)
#define ICEnroll4_Reset(This) (This)->lpVtbl->Reset(This)
#define ICEnroll4_GetSupportedKeySpec(This,pdwKeySpec) (This)->lpVtbl->GetSupportedKeySpec(This,pdwKeySpec)
#define ICEnroll4_GetKeyLen(This,fMin,fExchange,pdwKeySize) (This)->lpVtbl->GetKeyLen(This,fMin,fExchange,pdwKeySize)
#define ICEnroll4_EnumAlgs(This,dwIndex,algClass,pdwAlgID) (This)->lpVtbl->EnumAlgs(This,dwIndex,algClass,pdwAlgID)
#define ICEnroll4_GetAlgName(This,algID,pbstr) (This)->lpVtbl->GetAlgName(This,algID,pbstr)
#define ICEnroll4_put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define ICEnroll4_get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define ICEnroll4_put_HashAlgID(This,hashAlgID) (This)->lpVtbl->put_HashAlgID(This,hashAlgID)
#define ICEnroll4_get_HashAlgID(This,hashAlgID) (This)->lpVtbl->get_HashAlgID(This,hashAlgID)
#define ICEnroll4_put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define ICEnroll4_get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define ICEnroll4_put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#define ICEnroll4_get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#define ICEnroll4_put_PrivateKeyArchiveCertificate(This,bstrCert) (This)->lpVtbl->put_PrivateKeyArchiveCertificate(This,bstrCert)
#define ICEnroll4_get_PrivateKeyArchiveCertificate(This,pbstrCert) (This)->lpVtbl->get_PrivateKeyArchiveCertificate(This,pbstrCert)
#define ICEnroll4_put_ThumbPrint(This,bstrThumbPrint) (This)->lpVtbl->put_ThumbPrint(This,bstrThumbPrint)
#define ICEnroll4_get_ThumbPrint(This,pbstrThumbPrint) (This)->lpVtbl->get_ThumbPrint(This,pbstrThumbPrint)
#define ICEnroll4_binaryToString(This,Flags,strBinary,pstrEncoded) (This)->lpVtbl->binaryToString(This,Flags,strBinary,pstrEncoded)
#define ICEnroll4_stringToBinary(This,Flags,strEncoded,pstrBinary) (This)->lpVtbl->stringToBinary(This,Flags,strEncoded,pstrBinary)
#define ICEnroll4_addExtensionToRequest(This,Flags,strName,strValue) (This)->lpVtbl->addExtensionToRequest(This,Flags,strName,strValue)
#define ICEnroll4_addAttributeToRequest(This,Flags,strName,strValue) (This)->lpVtbl->addAttributeToRequest(This,Flags,strName,strValue)
#define ICEnroll4_addNameValuePairToRequest(This,Flags,strName,strValue) (This)->lpVtbl->addNameValuePairToRequest(This,Flags,strName,strValue)
#define ICEnroll4_resetExtensions(This) (This)->lpVtbl->resetExtensions(This)
#define ICEnroll4_resetAttributes(This) (This)->lpVtbl->resetAttributes(This)
#define ICEnroll4_createRequest(This,Flags,strDNName,Usage,pstrRequest) (This)->lpVtbl->createRequest(This,Flags,strDNName,Usage,pstrRequest)
#define ICEnroll4_createFileRequest(This,Flags,strDNName,strUsage,strRequestFileName) (This)->lpVtbl->createFileRequest(This,Flags,strDNName,strUsage,strRequestFileName)
#define ICEnroll4_acceptResponse(This,strResponse) (This)->lpVtbl->acceptResponse(This,strResponse)
#define ICEnroll4_acceptFileResponse(This,strResponseFileName) (This)->lpVtbl->acceptFileResponse(This,strResponseFileName)
#define ICEnroll4_getCertFromResponse(This,strResponse,pstrCert) (This)->lpVtbl->getCertFromResponse(This,strResponse,pstrCert)
#define ICEnroll4_getCertFromFileResponse(This,strResponseFileName,pstrCert) (This)->lpVtbl->getCertFromFileResponse(This,strResponseFileName,pstrCert)
#define ICEnroll4_createPFX(This,strPassword,pstrPFX) (This)->lpVtbl->createPFX(This,strPassword,pstrPFX)
#define ICEnroll4_createFilePFX(This,strPassword,strPFXFileName) (This)->lpVtbl->createFilePFX(This,strPassword,strPFXFileName)
#define ICEnroll4_setPendingRequestInfo(This,lRequestID,strCADNS,strCAName,strFriendlyName) (This)->lpVtbl->setPendingRequestInfo(This,lRequestID,strCADNS,strCAName,strFriendlyName)
#define ICEnroll4_enumPendingRequest(This,lIndex,lDesiredProperty,pvarProperty) (This)->lpVtbl->enumPendingRequest(This,lIndex,lDesiredProperty,pvarProperty)
#define ICEnroll4_removePendingRequest(This,strThumbprint) (This)->lpVtbl->removePendingRequest(This,strThumbprint)
#define ICEnroll4_GetKeyLenEx(This,lSizeSpec,lKeySpec,pdwKeySize) (This)->lpVtbl->GetKeyLenEx(This,lSizeSpec,lKeySpec,pdwKeySize)
#define ICEnroll4_InstallPKCS7Ex(This,PKCS7,plCertInstalled) (This)->lpVtbl->InstallPKCS7Ex(This,PKCS7,plCertInstalled)
#define ICEnroll4_addCertTypeToRequestEx(This,lType,bstrOIDOrName,lMajorVersion,fMinorVersion,lMinorVersion) (This)->lpVtbl->addCertTypeToRequestEx(This,lType,bstrOIDOrName,lMajorVersion,fMinorVersion,lMinorVersion)
#define ICEnroll4_getProviderType(This,strProvName,plProvType) (This)->lpVtbl->getProviderType(This,strProvName,plProvType)
#define ICEnroll4_put_SignerCertificate(This,bstrCert) (This)->lpVtbl->put_SignerCertificate(This,bstrCert)
#define ICEnroll4_put_ClientId(This,lClientId) (This)->lpVtbl->put_ClientId(This,lClientId)
#define ICEnroll4_get_ClientId(This,plClientId) (This)->lpVtbl->get_ClientId(This,plClientId)
#define ICEnroll4_addBlobPropertyToCertificate(This,lPropertyId,lReserved,bstrProperty) (This)->lpVtbl->addBlobPropertyToCertificate(This,lPropertyId,lReserved,bstrProperty)
#define ICEnroll4_resetBlobProperties(This) (This)->lpVtbl->resetBlobProperties(This)
#define ICEnroll4_put_IncludeSubjectKeyID(This,fInclude) (This)->lpVtbl->put_IncludeSubjectKeyID(This,fInclude)
#define ICEnroll4_get_IncludeSubjectKeyID(This,pfInclude) (This)->lpVtbl->get_IncludeSubjectKeyID(This,pfInclude)
#endif
#endif
  HRESULT WINAPI ICEnroll4_put_PrivateKeyArchiveCertificate_Proxy(ICEnroll4 *This,BSTR bstrCert);
  void __RPC_STUB ICEnroll4_put_PrivateKeyArchiveCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_get_PrivateKeyArchiveCertificate_Proxy(ICEnroll4 *This,BSTR *pbstrCert);
  void __RPC_STUB ICEnroll4_get_PrivateKeyArchiveCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_put_ThumbPrint_Proxy(ICEnroll4 *This,BSTR bstrThumbPrint);
  void __RPC_STUB ICEnroll4_put_ThumbPrint_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_get_ThumbPrint_Proxy(ICEnroll4 *This,BSTR *pbstrThumbPrint);
  void __RPC_STUB ICEnroll4_get_ThumbPrint_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_binaryToString_Proxy(ICEnroll4 *This,LONG Flags,BSTR strBinary,BSTR *pstrEncoded);
  void __RPC_STUB ICEnroll4_binaryToString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_stringToBinary_Proxy(ICEnroll4 *This,LONG Flags,BSTR strEncoded,BSTR *pstrBinary);
  void __RPC_STUB ICEnroll4_stringToBinary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_addExtensionToRequest_Proxy(ICEnroll4 *This,LONG Flags,BSTR strName,BSTR strValue);
  void __RPC_STUB ICEnroll4_addExtensionToRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_addAttributeToRequest_Proxy(ICEnroll4 *This,LONG Flags,BSTR strName,BSTR strValue);
  void __RPC_STUB ICEnroll4_addAttributeToRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_addNameValuePairToRequest_Proxy(ICEnroll4 *This,LONG Flags,BSTR strName,BSTR strValue);
  void __RPC_STUB ICEnroll4_addNameValuePairToRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_resetExtensions_Proxy(ICEnroll4 *This);
  void __RPC_STUB ICEnroll4_resetExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_resetAttributes_Proxy(ICEnroll4 *This);
  void __RPC_STUB ICEnroll4_resetAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_createRequest_Proxy(ICEnroll4 *This,LONG Flags,BSTR strDNName,BSTR Usage,BSTR *pstrRequest);
  void __RPC_STUB ICEnroll4_createRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_createFileRequest_Proxy(ICEnroll4 *This,LONG Flags,BSTR strDNName,BSTR strUsage,BSTR strRequestFileName);
  void __RPC_STUB ICEnroll4_createFileRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_acceptResponse_Proxy(ICEnroll4 *This,BSTR strResponse);
  void __RPC_STUB ICEnroll4_acceptResponse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_acceptFileResponse_Proxy(ICEnroll4 *This,BSTR strResponseFileName);
  void __RPC_STUB ICEnroll4_acceptFileResponse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_getCertFromResponse_Proxy(ICEnroll4 *This,BSTR strResponse,BSTR *pstrCert);
  void __RPC_STUB ICEnroll4_getCertFromResponse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_getCertFromFileResponse_Proxy(ICEnroll4 *This,BSTR strResponseFileName,BSTR *pstrCert);
  void __RPC_STUB ICEnroll4_getCertFromFileResponse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_createPFX_Proxy(ICEnroll4 *This,BSTR strPassword,BSTR *pstrPFX);
  void __RPC_STUB ICEnroll4_createPFX_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_createFilePFX_Proxy(ICEnroll4 *This,BSTR strPassword,BSTR strPFXFileName);
  void __RPC_STUB ICEnroll4_createFilePFX_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_setPendingRequestInfo_Proxy(ICEnroll4 *This,LONG lRequestID,BSTR strCADNS,BSTR strCAName,BSTR strFriendlyName);
  void __RPC_STUB ICEnroll4_setPendingRequestInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_enumPendingRequest_Proxy(ICEnroll4 *This,LONG lIndex,LONG lDesiredProperty,VARIANT *pvarProperty);
  void __RPC_STUB ICEnroll4_enumPendingRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_removePendingRequest_Proxy(ICEnroll4 *This,BSTR strThumbprint);
  void __RPC_STUB ICEnroll4_removePendingRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_GetKeyLenEx_Proxy(ICEnroll4 *This,LONG lSizeSpec,LONG lKeySpec,LONG *pdwKeySize);
  void __RPC_STUB ICEnroll4_GetKeyLenEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_InstallPKCS7Ex_Proxy(ICEnroll4 *This,BSTR PKCS7,LONG *plCertInstalled);
  void __RPC_STUB ICEnroll4_InstallPKCS7Ex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_addCertTypeToRequestEx_Proxy(ICEnroll4 *This,LONG lType,BSTR bstrOIDOrName,LONG lMajorVersion,WINBOOL fMinorVersion,LONG lMinorVersion);
  void __RPC_STUB ICEnroll4_addCertTypeToRequestEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_getProviderType_Proxy(ICEnroll4 *This,BSTR strProvName,LONG *plProvType);
  void __RPC_STUB ICEnroll4_getProviderType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_put_SignerCertificate_Proxy(ICEnroll4 *This,BSTR bstrCert);
  void __RPC_STUB ICEnroll4_put_SignerCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_put_ClientId_Proxy(ICEnroll4 *This,LONG lClientId);
  void __RPC_STUB ICEnroll4_put_ClientId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_get_ClientId_Proxy(ICEnroll4 *This,LONG *plClientId);
  void __RPC_STUB ICEnroll4_get_ClientId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_addBlobPropertyToCertificate_Proxy(ICEnroll4 *This,LONG lPropertyId,LONG lReserved,BSTR bstrProperty);
  void __RPC_STUB ICEnroll4_addBlobPropertyToCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_resetBlobProperties_Proxy(ICEnroll4 *This);
  void __RPC_STUB ICEnroll4_resetBlobProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_put_IncludeSubjectKeyID_Proxy(ICEnroll4 *This,WINBOOL fInclude);
  void __RPC_STUB ICEnroll4_put_IncludeSubjectKeyID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICEnroll4_get_IncludeSubjectKeyID_Proxy(ICEnroll4 *This,WINBOOL *pfInclude);
  void __RPC_STUB ICEnroll4_get_IncludeSubjectKeyID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnroll_INTERFACE_DEFINED__
#define __IEnroll_INTERFACE_DEFINED__
  extern const IID IID_IEnroll;
#if defined(__cplusplus) && !defined(CINTERFACE)
#ifdef __cplusplus
}
#endif
  struct IEnroll : public IUnknown {
  public:
    virtual HRESULT WINAPI createFilePKCS10WStr(LPCWSTR DNName,LPCWSTR Usage,LPCWSTR wszPKCS10FileName) = 0;
    virtual HRESULT WINAPI acceptFilePKCS7WStr(LPCWSTR wszPKCS7FileName) = 0;
    virtual HRESULT WINAPI createPKCS10WStr(LPCWSTR DNName,LPCWSTR Usage,PCRYPT_DATA_BLOB pPkcs10Blob) = 0;
    virtual HRESULT WINAPI acceptPKCS7Blob(PCRYPT_DATA_BLOB pBlobPKCS7) = 0;
    virtual PCCERT_CONTEXT WINAPI getCertContextFromPKCS7(PCRYPT_DATA_BLOB pBlobPKCS7) = 0;
    virtual HCERTSTORE WINAPI getMyStore(void) = 0;
    virtual HCERTSTORE WINAPI getCAStore(void) = 0;
    virtual HCERTSTORE WINAPI getROOTHStore(void) = 0;
    virtual HRESULT WINAPI enumProvidersWStr(LONG dwIndex,LONG dwFlags,LPWSTR *pbstrProvName) = 0;
    virtual HRESULT WINAPI enumContainersWStr(LONG dwIndex,LPWSTR *pbstr) = 0;
    virtual HRESULT WINAPI freeRequestInfoBlob(CRYPT_DATA_BLOB pkcs7OrPkcs10) = 0;
    virtual HRESULT WINAPI get_MyStoreNameWStr(LPWSTR *szwName) = 0;
    virtual HRESULT WINAPI put_MyStoreNameWStr(LPWSTR szwName) = 0;
    virtual HRESULT WINAPI get_MyStoreTypeWStr(LPWSTR *szwType) = 0;
    virtual HRESULT WINAPI put_MyStoreTypeWStr(LPWSTR szwType) = 0;
    virtual HRESULT WINAPI get_MyStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_MyStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_CAStoreNameWStr(LPWSTR *szwName) = 0;
    virtual HRESULT WINAPI put_CAStoreNameWStr(LPWSTR szwName) = 0;
    virtual HRESULT WINAPI get_CAStoreTypeWStr(LPWSTR *szwType) = 0;
    virtual HRESULT WINAPI put_CAStoreTypeWStr(LPWSTR szwType) = 0;
    virtual HRESULT WINAPI get_CAStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_CAStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_RootStoreNameWStr(LPWSTR *szwName) = 0;
    virtual HRESULT WINAPI put_RootStoreNameWStr(LPWSTR szwName) = 0;
    virtual HRESULT WINAPI get_RootStoreTypeWStr(LPWSTR *szwType) = 0;
    virtual HRESULT WINAPI put_RootStoreTypeWStr(LPWSTR szwType) = 0;
    virtual HRESULT WINAPI get_RootStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_RootStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_RequestStoreNameWStr(LPWSTR *szwName) = 0;
    virtual HRESULT WINAPI put_RequestStoreNameWStr(LPWSTR szwName) = 0;
    virtual HRESULT WINAPI get_RequestStoreTypeWStr(LPWSTR *szwType) = 0;
    virtual HRESULT WINAPI put_RequestStoreTypeWStr(LPWSTR szwType) = 0;
    virtual HRESULT WINAPI get_RequestStoreFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_RequestStoreFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_ContainerNameWStr(LPWSTR *szwContainer) = 0;
    virtual HRESULT WINAPI put_ContainerNameWStr(LPWSTR szwContainer) = 0;
    virtual HRESULT WINAPI get_ProviderNameWStr(LPWSTR *szwProvider) = 0;
    virtual HRESULT WINAPI put_ProviderNameWStr(LPWSTR szwProvider) = 0;
    virtual HRESULT WINAPI get_ProviderType(LONG *pdwType) = 0;
    virtual HRESULT WINAPI put_ProviderType(LONG dwType) = 0;
    virtual HRESULT WINAPI get_KeySpec(LONG *pdw) = 0;
    virtual HRESULT WINAPI put_KeySpec(LONG dw) = 0;
    virtual HRESULT WINAPI get_ProviderFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_ProviderFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_UseExistingKeySet(WINBOOL *fUseExistingKeys) = 0;
    virtual HRESULT WINAPI put_UseExistingKeySet(WINBOOL fUseExistingKeys) = 0;
    virtual HRESULT WINAPI get_GenKeyFlags(LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI put_GenKeyFlags(LONG dwFlags) = 0;
    virtual HRESULT WINAPI get_DeleteRequestCert(WINBOOL *fDelete) = 0;
    virtual HRESULT WINAPI put_DeleteRequestCert(WINBOOL fDelete) = 0;
    virtual HRESULT WINAPI get_WriteCertToUserDS(WINBOOL *fBool) = 0;
    virtual HRESULT WINAPI put_WriteCertToUserDS(WINBOOL fBool) = 0;
    virtual HRESULT WINAPI get_EnableT61DNEncoding(WINBOOL *fBool) = 0;
    virtual HRESULT WINAPI put_EnableT61DNEncoding(WINBOOL fBool) = 0;
    virtual HRESULT WINAPI get_WriteCertToCSP(WINBOOL *fBool) = 0;
    virtual HRESULT WINAPI put_WriteCertToCSP(WINBOOL fBool) = 0;
    virtual HRESULT WINAPI get_SPCFileNameWStr(LPWSTR *szw) = 0;
    virtual HRESULT WINAPI put_SPCFileNameWStr(LPWSTR szw) = 0;
    virtual HRESULT WINAPI get_PVKFileNameWStr(LPWSTR *szw) = 0;
    virtual HRESULT WINAPI put_PVKFileNameWStr(LPWSTR szw) = 0;
    virtual HRESULT WINAPI get_HashAlgorithmWStr(LPWSTR *szw) = 0;
    virtual HRESULT WINAPI put_HashAlgorithmWStr(LPWSTR szw) = 0;
    virtual HRESULT WINAPI get_RenewalCertificate(PCCERT_CONTEXT *ppCertContext) = 0;
    virtual HRESULT WINAPI put_RenewalCertificate(PCCERT_CONTEXT pCertContext) = 0;
    virtual HRESULT WINAPI AddCertTypeToRequestWStr(LPWSTR szw) = 0;
    virtual HRESULT WINAPI AddNameValuePairToSignatureWStr(LPWSTR Name,LPWSTR Value) = 0;
    virtual HRESULT WINAPI AddExtensionsToRequest(PCERT_EXTENSIONS pCertExtensions) = 0;
    virtual HRESULT WINAPI AddAuthenticatedAttributesToPKCS7Request(PCRYPT_ATTRIBUTES pAttributes) = 0;
    virtual HRESULT WINAPI CreatePKCS7RequestFromRequest(PCRYPT_DATA_BLOB pRequest,PCCERT_CONTEXT pSigningCertContext,PCRYPT_DATA_BLOB pPkcs7Blob) = 0;
  };
#ifdef __cplusplus
  extern "C" {
#endif
#else
  typedef struct IEnrollVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnroll *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnroll *This);
      ULONG (WINAPI *Release)(IEnroll *This);
      HRESULT (WINAPI *createFilePKCS10WStr)(IEnroll *This,LPCWSTR DNName,LPCWSTR Usage,LPCWSTR wszPKCS10FileName);
      HRESULT (WINAPI *acceptFilePKCS7WStr)(IEnroll *This,LPCWSTR wszPKCS7FileName);
      HRESULT (WINAPI *createPKCS10WStr)(IEnroll *This,LPCWSTR DNName,LPCWSTR Usage,PCRYPT_DATA_BLOB pPkcs10Blob);
      HRESULT (WINAPI *acceptPKCS7Blob)(IEnroll *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      PCCERT_CONTEXT (WINAPI *getCertContextFromPKCS7)(IEnroll *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      HCERTSTORE (WINAPI *getMyStore)(IEnroll *This);
      HCERTSTORE (WINAPI *getCAStore)(IEnroll *This);
      HCERTSTORE (WINAPI *getROOTHStore)(IEnroll *This);
      HRESULT (WINAPI *enumProvidersWStr)(IEnroll *This,LONG dwIndex,LONG dwFlags,LPWSTR *pbstrProvName);
      HRESULT (WINAPI *enumContainersWStr)(IEnroll *This,LONG dwIndex,LPWSTR *pbstr);
      HRESULT (WINAPI *freeRequestInfoBlob)(IEnroll *This,CRYPT_DATA_BLOB pkcs7OrPkcs10);
      HRESULT (WINAPI *get_MyStoreNameWStr)(IEnroll *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_MyStoreNameWStr)(IEnroll *This,LPWSTR szwName);
      HRESULT (WINAPI *get_MyStoreTypeWStr)(IEnroll *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_MyStoreTypeWStr)(IEnroll *This,LPWSTR szwType);
      HRESULT (WINAPI *get_MyStoreFlags)(IEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_MyStoreFlags)(IEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_CAStoreNameWStr)(IEnroll *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_CAStoreNameWStr)(IEnroll *This,LPWSTR szwName);
      HRESULT (WINAPI *get_CAStoreTypeWStr)(IEnroll *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_CAStoreTypeWStr)(IEnroll *This,LPWSTR szwType);
      HRESULT (WINAPI *get_CAStoreFlags)(IEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_CAStoreFlags)(IEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_RootStoreNameWStr)(IEnroll *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_RootStoreNameWStr)(IEnroll *This,LPWSTR szwName);
      HRESULT (WINAPI *get_RootStoreTypeWStr)(IEnroll *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_RootStoreTypeWStr)(IEnroll *This,LPWSTR szwType);
      HRESULT (WINAPI *get_RootStoreFlags)(IEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RootStoreFlags)(IEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_RequestStoreNameWStr)(IEnroll *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_RequestStoreNameWStr)(IEnroll *This,LPWSTR szwName);
      HRESULT (WINAPI *get_RequestStoreTypeWStr)(IEnroll *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_RequestStoreTypeWStr)(IEnroll *This,LPWSTR szwType);
      HRESULT (WINAPI *get_RequestStoreFlags)(IEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RequestStoreFlags)(IEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_ContainerNameWStr)(IEnroll *This,LPWSTR *szwContainer);
      HRESULT (WINAPI *put_ContainerNameWStr)(IEnroll *This,LPWSTR szwContainer);
      HRESULT (WINAPI *get_ProviderNameWStr)(IEnroll *This,LPWSTR *szwProvider);
      HRESULT (WINAPI *put_ProviderNameWStr)(IEnroll *This,LPWSTR szwProvider);
      HRESULT (WINAPI *get_ProviderType)(IEnroll *This,LONG *pdwType);
      HRESULT (WINAPI *put_ProviderType)(IEnroll *This,LONG dwType);
      HRESULT (WINAPI *get_KeySpec)(IEnroll *This,LONG *pdw);
      HRESULT (WINAPI *put_KeySpec)(IEnroll *This,LONG dw);
      HRESULT (WINAPI *get_ProviderFlags)(IEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_ProviderFlags)(IEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_UseExistingKeySet)(IEnroll *This,WINBOOL *fUseExistingKeys);
      HRESULT (WINAPI *put_UseExistingKeySet)(IEnroll *This,WINBOOL fUseExistingKeys);
      HRESULT (WINAPI *get_GenKeyFlags)(IEnroll *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_GenKeyFlags)(IEnroll *This,LONG dwFlags);
      HRESULT (WINAPI *get_DeleteRequestCert)(IEnroll *This,WINBOOL *fDelete);
      HRESULT (WINAPI *put_DeleteRequestCert)(IEnroll *This,WINBOOL fDelete);
      HRESULT (WINAPI *get_WriteCertToUserDS)(IEnroll *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToUserDS)(IEnroll *This,WINBOOL fBool);
      HRESULT (WINAPI *get_EnableT61DNEncoding)(IEnroll *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_EnableT61DNEncoding)(IEnroll *This,WINBOOL fBool);
      HRESULT (WINAPI *get_WriteCertToCSP)(IEnroll *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToCSP)(IEnroll *This,WINBOOL fBool);
      HRESULT (WINAPI *get_SPCFileNameWStr)(IEnroll *This,LPWSTR *szw);
      HRESULT (WINAPI *put_SPCFileNameWStr)(IEnroll *This,LPWSTR szw);
      HRESULT (WINAPI *get_PVKFileNameWStr)(IEnroll *This,LPWSTR *szw);
      HRESULT (WINAPI *put_PVKFileNameWStr)(IEnroll *This,LPWSTR szw);
      HRESULT (WINAPI *get_HashAlgorithmWStr)(IEnroll *This,LPWSTR *szw);
      HRESULT (WINAPI *put_HashAlgorithmWStr)(IEnroll *This,LPWSTR szw);
      HRESULT (WINAPI *get_RenewalCertificate)(IEnroll *This,PCCERT_CONTEXT *ppCertContext);
      HRESULT (WINAPI *put_RenewalCertificate)(IEnroll *This,PCCERT_CONTEXT pCertContext);
      HRESULT (WINAPI *AddCertTypeToRequestWStr)(IEnroll *This,LPWSTR szw);
      HRESULT (WINAPI *AddNameValuePairToSignatureWStr)(IEnroll *This,LPWSTR Name,LPWSTR Value);
      HRESULT (WINAPI *AddExtensionsToRequest)(IEnroll *This,PCERT_EXTENSIONS pCertExtensions);
      HRESULT (WINAPI *AddAuthenticatedAttributesToPKCS7Request)(IEnroll *This,PCRYPT_ATTRIBUTES pAttributes);
      HRESULT (WINAPI *CreatePKCS7RequestFromRequest)(IEnroll *This,PCRYPT_DATA_BLOB pRequest,PCCERT_CONTEXT pSigningCertContext,PCRYPT_DATA_BLOB pPkcs7Blob);
    END_INTERFACE
  } IEnrollVtbl;
  struct IEnroll {
    CONST_VTBL struct IEnrollVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnroll_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnroll_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnroll_Release(This) (This)->lpVtbl->Release(This)
#define IEnroll_createFilePKCS10WStr(This,DNName,Usage,wszPKCS10FileName) (This)->lpVtbl->createFilePKCS10WStr(This,DNName,Usage,wszPKCS10FileName)
#define IEnroll_acceptFilePKCS7WStr(This,wszPKCS7FileName) (This)->lpVtbl->acceptFilePKCS7WStr(This,wszPKCS7FileName)
#define IEnroll_createPKCS10WStr(This,DNName,Usage,pPkcs10Blob) (This)->lpVtbl->createPKCS10WStr(This,DNName,Usage,pPkcs10Blob)
#define IEnroll_acceptPKCS7Blob(This,pBlobPKCS7) (This)->lpVtbl->acceptPKCS7Blob(This,pBlobPKCS7)
#define IEnroll_getCertContextFromPKCS7(This,pBlobPKCS7) (This)->lpVtbl->getCertContextFromPKCS7(This,pBlobPKCS7)
#define IEnroll_getMyStore(This) (This)->lpVtbl->getMyStore(This)
#define IEnroll_getCAStore(This) (This)->lpVtbl->getCAStore(This)
#define IEnroll_getROOTHStore(This) (This)->lpVtbl->getROOTHStore(This)
#define IEnroll_enumProvidersWStr(This,dwIndex,dwFlags,pbstrProvName) (This)->lpVtbl->enumProvidersWStr(This,dwIndex,dwFlags,pbstrProvName)
#define IEnroll_enumContainersWStr(This,dwIndex,pbstr) (This)->lpVtbl->enumContainersWStr(This,dwIndex,pbstr)
#define IEnroll_freeRequestInfoBlob(This,pkcs7OrPkcs10) (This)->lpVtbl->freeRequestInfoBlob(This,pkcs7OrPkcs10)
#define IEnroll_get_MyStoreNameWStr(This,szwName) (This)->lpVtbl->get_MyStoreNameWStr(This,szwName)
#define IEnroll_put_MyStoreNameWStr(This,szwName) (This)->lpVtbl->put_MyStoreNameWStr(This,szwName)
#define IEnroll_get_MyStoreTypeWStr(This,szwType) (This)->lpVtbl->get_MyStoreTypeWStr(This,szwType)
#define IEnroll_put_MyStoreTypeWStr(This,szwType) (This)->lpVtbl->put_MyStoreTypeWStr(This,szwType)
#define IEnroll_get_MyStoreFlags(This,pdwFlags) (This)->lpVtbl->get_MyStoreFlags(This,pdwFlags)
#define IEnroll_put_MyStoreFlags(This,dwFlags) (This)->lpVtbl->put_MyStoreFlags(This,dwFlags)
#define IEnroll_get_CAStoreNameWStr(This,szwName) (This)->lpVtbl->get_CAStoreNameWStr(This,szwName)
#define IEnroll_put_CAStoreNameWStr(This,szwName) (This)->lpVtbl->put_CAStoreNameWStr(This,szwName)
#define IEnroll_get_CAStoreTypeWStr(This,szwType) (This)->lpVtbl->get_CAStoreTypeWStr(This,szwType)
#define IEnroll_put_CAStoreTypeWStr(This,szwType) (This)->lpVtbl->put_CAStoreTypeWStr(This,szwType)
#define IEnroll_get_CAStoreFlags(This,pdwFlags) (This)->lpVtbl->get_CAStoreFlags(This,pdwFlags)
#define IEnroll_put_CAStoreFlags(This,dwFlags) (This)->lpVtbl->put_CAStoreFlags(This,dwFlags)
#define IEnroll_get_RootStoreNameWStr(This,szwName) (This)->lpVtbl->get_RootStoreNameWStr(This,szwName)
#define IEnroll_put_RootStoreNameWStr(This,szwName) (This)->lpVtbl->put_RootStoreNameWStr(This,szwName)
#define IEnroll_get_RootStoreTypeWStr(This,szwType) (This)->lpVtbl->get_RootStoreTypeWStr(This,szwType)
#define IEnroll_put_RootStoreTypeWStr(This,szwType) (This)->lpVtbl->put_RootStoreTypeWStr(This,szwType)
#define IEnroll_get_RootStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RootStoreFlags(This,pdwFlags)
#define IEnroll_put_RootStoreFlags(This,dwFlags) (This)->lpVtbl->put_RootStoreFlags(This,dwFlags)
#define IEnroll_get_RequestStoreNameWStr(This,szwName) (This)->lpVtbl->get_RequestStoreNameWStr(This,szwName)
#define IEnroll_put_RequestStoreNameWStr(This,szwName) (This)->lpVtbl->put_RequestStoreNameWStr(This,szwName)
#define IEnroll_get_RequestStoreTypeWStr(This,szwType) (This)->lpVtbl->get_RequestStoreTypeWStr(This,szwType)
#define IEnroll_put_RequestStoreTypeWStr(This,szwType) (This)->lpVtbl->put_RequestStoreTypeWStr(This,szwType)
#define IEnroll_get_RequestStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RequestStoreFlags(This,pdwFlags)
#define IEnroll_put_RequestStoreFlags(This,dwFlags) (This)->lpVtbl->put_RequestStoreFlags(This,dwFlags)
#define IEnroll_get_ContainerNameWStr(This,szwContainer) (This)->lpVtbl->get_ContainerNameWStr(This,szwContainer)
#define IEnroll_put_ContainerNameWStr(This,szwContainer) (This)->lpVtbl->put_ContainerNameWStr(This,szwContainer)
#define IEnroll_get_ProviderNameWStr(This,szwProvider) (This)->lpVtbl->get_ProviderNameWStr(This,szwProvider)
#define IEnroll_put_ProviderNameWStr(This,szwProvider) (This)->lpVtbl->put_ProviderNameWStr(This,szwProvider)
#define IEnroll_get_ProviderType(This,pdwType) (This)->lpVtbl->get_ProviderType(This,pdwType)
#define IEnroll_put_ProviderType(This,dwType) (This)->lpVtbl->put_ProviderType(This,dwType)
#define IEnroll_get_KeySpec(This,pdw) (This)->lpVtbl->get_KeySpec(This,pdw)
#define IEnroll_put_KeySpec(This,dw) (This)->lpVtbl->put_KeySpec(This,dw)
#define IEnroll_get_ProviderFlags(This,pdwFlags) (This)->lpVtbl->get_ProviderFlags(This,pdwFlags)
#define IEnroll_put_ProviderFlags(This,dwFlags) (This)->lpVtbl->put_ProviderFlags(This,dwFlags)
#define IEnroll_get_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->get_UseExistingKeySet(This,fUseExistingKeys)
#define IEnroll_put_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->put_UseExistingKeySet(This,fUseExistingKeys)
#define IEnroll_get_GenKeyFlags(This,pdwFlags) (This)->lpVtbl->get_GenKeyFlags(This,pdwFlags)
#define IEnroll_put_GenKeyFlags(This,dwFlags) (This)->lpVtbl->put_GenKeyFlags(This,dwFlags)
#define IEnroll_get_DeleteRequestCert(This,fDelete) (This)->lpVtbl->get_DeleteRequestCert(This,fDelete)
#define IEnroll_put_DeleteRequestCert(This,fDelete) (This)->lpVtbl->put_DeleteRequestCert(This,fDelete)
#define IEnroll_get_WriteCertToUserDS(This,fBool) (This)->lpVtbl->get_WriteCertToUserDS(This,fBool)
#define IEnroll_put_WriteCertToUserDS(This,fBool) (This)->lpVtbl->put_WriteCertToUserDS(This,fBool)
#define IEnroll_get_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->get_EnableT61DNEncoding(This,fBool)
#define IEnroll_put_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->put_EnableT61DNEncoding(This,fBool)
#define IEnroll_get_WriteCertToCSP(This,fBool) (This)->lpVtbl->get_WriteCertToCSP(This,fBool)
#define IEnroll_put_WriteCertToCSP(This,fBool) (This)->lpVtbl->put_WriteCertToCSP(This,fBool)
#define IEnroll_get_SPCFileNameWStr(This,szw) (This)->lpVtbl->get_SPCFileNameWStr(This,szw)
#define IEnroll_put_SPCFileNameWStr(This,szw) (This)->lpVtbl->put_SPCFileNameWStr(This,szw)
#define IEnroll_get_PVKFileNameWStr(This,szw) (This)->lpVtbl->get_PVKFileNameWStr(This,szw)
#define IEnroll_put_PVKFileNameWStr(This,szw) (This)->lpVtbl->put_PVKFileNameWStr(This,szw)
#define IEnroll_get_HashAlgorithmWStr(This,szw) (This)->lpVtbl->get_HashAlgorithmWStr(This,szw)
#define IEnroll_put_HashAlgorithmWStr(This,szw) (This)->lpVtbl->put_HashAlgorithmWStr(This,szw)
#define IEnroll_get_RenewalCertificate(This,ppCertContext) (This)->lpVtbl->get_RenewalCertificate(This,ppCertContext)
#define IEnroll_put_RenewalCertificate(This,pCertContext) (This)->lpVtbl->put_RenewalCertificate(This,pCertContext)
#define IEnroll_AddCertTypeToRequestWStr(This,szw) (This)->lpVtbl->AddCertTypeToRequestWStr(This,szw)
#define IEnroll_AddNameValuePairToSignatureWStr(This,Name,Value) (This)->lpVtbl->AddNameValuePairToSignatureWStr(This,Name,Value)
#define IEnroll_AddExtensionsToRequest(This,pCertExtensions) (This)->lpVtbl->AddExtensionsToRequest(This,pCertExtensions)
#define IEnroll_AddAuthenticatedAttributesToPKCS7Request(This,pAttributes) (This)->lpVtbl->AddAuthenticatedAttributesToPKCS7Request(This,pAttributes)
#define IEnroll_CreatePKCS7RequestFromRequest(This,pRequest,pSigningCertContext,pPkcs7Blob) (This)->lpVtbl->CreatePKCS7RequestFromRequest(This,pRequest,pSigningCertContext,pPkcs7Blob)
#endif
#endif
  HRESULT WINAPI IEnroll_createFilePKCS10WStr_Proxy(IEnroll *This,LPCWSTR DNName,LPCWSTR Usage,LPCWSTR wszPKCS10FileName);
  void __RPC_STUB IEnroll_createFilePKCS10WStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_acceptFilePKCS7WStr_Proxy(IEnroll *This,LPCWSTR wszPKCS7FileName);
  void __RPC_STUB IEnroll_acceptFilePKCS7WStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_createPKCS10WStr_Proxy(IEnroll *This,LPCWSTR DNName,LPCWSTR Usage,PCRYPT_DATA_BLOB pPkcs10Blob);
  void __RPC_STUB IEnroll_createPKCS10WStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_acceptPKCS7Blob_Proxy(IEnroll *This,PCRYPT_DATA_BLOB pBlobPKCS7);
  void __RPC_STUB IEnroll_acceptPKCS7Blob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  PCCERT_CONTEXT WINAPI IEnroll_getCertContextFromPKCS7_Proxy(IEnroll *This,PCRYPT_DATA_BLOB pBlobPKCS7);
  void __RPC_STUB IEnroll_getCertContextFromPKCS7_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HCERTSTORE WINAPI IEnroll_getMyStore_Proxy(IEnroll *This);
  void __RPC_STUB IEnroll_getMyStore_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HCERTSTORE WINAPI IEnroll_getCAStore_Proxy(IEnroll *This);
  void __RPC_STUB IEnroll_getCAStore_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HCERTSTORE WINAPI IEnroll_getROOTHStore_Proxy(IEnroll *This);
  void __RPC_STUB IEnroll_getROOTHStore_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_enumProvidersWStr_Proxy(IEnroll *This,LONG dwIndex,LONG dwFlags,LPWSTR *pbstrProvName);
  void __RPC_STUB IEnroll_enumProvidersWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_enumContainersWStr_Proxy(IEnroll *This,LONG dwIndex,LPWSTR *pbstr);
  void __RPC_STUB IEnroll_enumContainersWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_freeRequestInfoBlob_Proxy(IEnroll *This,CRYPT_DATA_BLOB pkcs7OrPkcs10);
  void __RPC_STUB IEnroll_freeRequestInfoBlob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_MyStoreNameWStr_Proxy(IEnroll *This,LPWSTR *szwName);
  void __RPC_STUB IEnroll_get_MyStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_MyStoreNameWStr_Proxy(IEnroll *This,LPWSTR szwName);
  void __RPC_STUB IEnroll_put_MyStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_MyStoreTypeWStr_Proxy(IEnroll *This,LPWSTR *szwType);
  void __RPC_STUB IEnroll_get_MyStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_MyStoreTypeWStr_Proxy(IEnroll *This,LPWSTR szwType);
  void __RPC_STUB IEnroll_put_MyStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_MyStoreFlags_Proxy(IEnroll *This,LONG *pdwFlags);
  void __RPC_STUB IEnroll_get_MyStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_MyStoreFlags_Proxy(IEnroll *This,LONG dwFlags);
  void __RPC_STUB IEnroll_put_MyStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_CAStoreNameWStr_Proxy(IEnroll *This,LPWSTR *szwName);
  void __RPC_STUB IEnroll_get_CAStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_CAStoreNameWStr_Proxy(IEnroll *This,LPWSTR szwName);
  void __RPC_STUB IEnroll_put_CAStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_CAStoreTypeWStr_Proxy(IEnroll *This,LPWSTR *szwType);
  void __RPC_STUB IEnroll_get_CAStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_CAStoreTypeWStr_Proxy(IEnroll *This,LPWSTR szwType);
  void __RPC_STUB IEnroll_put_CAStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_CAStoreFlags_Proxy(IEnroll *This,LONG *pdwFlags);
  void __RPC_STUB IEnroll_get_CAStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_CAStoreFlags_Proxy(IEnroll *This,LONG dwFlags);
  void __RPC_STUB IEnroll_put_CAStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_RootStoreNameWStr_Proxy(IEnroll *This,LPWSTR *szwName);
  void __RPC_STUB IEnroll_get_RootStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_RootStoreNameWStr_Proxy(IEnroll *This,LPWSTR szwName);
  void __RPC_STUB IEnroll_put_RootStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_RootStoreTypeWStr_Proxy(IEnroll *This,LPWSTR *szwType);
  void __RPC_STUB IEnroll_get_RootStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_RootStoreTypeWStr_Proxy(IEnroll *This,LPWSTR szwType);
  void __RPC_STUB IEnroll_put_RootStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_RootStoreFlags_Proxy(IEnroll *This,LONG *pdwFlags);
  void __RPC_STUB IEnroll_get_RootStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_RootStoreFlags_Proxy(IEnroll *This,LONG dwFlags);
  void __RPC_STUB IEnroll_put_RootStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_RequestStoreNameWStr_Proxy(IEnroll *This,LPWSTR *szwName);
  void __RPC_STUB IEnroll_get_RequestStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_RequestStoreNameWStr_Proxy(IEnroll *This,LPWSTR szwName);
  void __RPC_STUB IEnroll_put_RequestStoreNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_RequestStoreTypeWStr_Proxy(IEnroll *This,LPWSTR *szwType);
  void __RPC_STUB IEnroll_get_RequestStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_RequestStoreTypeWStr_Proxy(IEnroll *This,LPWSTR szwType);
  void __RPC_STUB IEnroll_put_RequestStoreTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_RequestStoreFlags_Proxy(IEnroll *This,LONG *pdwFlags);
  void __RPC_STUB IEnroll_get_RequestStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_RequestStoreFlags_Proxy(IEnroll *This,LONG dwFlags);
  void __RPC_STUB IEnroll_put_RequestStoreFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_ContainerNameWStr_Proxy(IEnroll *This,LPWSTR *szwContainer);
  void __RPC_STUB IEnroll_get_ContainerNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_ContainerNameWStr_Proxy(IEnroll *This,LPWSTR szwContainer);
  void __RPC_STUB IEnroll_put_ContainerNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_ProviderNameWStr_Proxy(IEnroll *This,LPWSTR *szwProvider);
  void __RPC_STUB IEnroll_get_ProviderNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_ProviderNameWStr_Proxy(IEnroll *This,LPWSTR szwProvider);
  void __RPC_STUB IEnroll_put_ProviderNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_ProviderType_Proxy(IEnroll *This,LONG *pdwType);
  void __RPC_STUB IEnroll_get_ProviderType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_ProviderType_Proxy(IEnroll *This,LONG dwType);
  void __RPC_STUB IEnroll_put_ProviderType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_KeySpec_Proxy(IEnroll *This,LONG *pdw);
  void __RPC_STUB IEnroll_get_KeySpec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_KeySpec_Proxy(IEnroll *This,LONG dw);
  void __RPC_STUB IEnroll_put_KeySpec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_ProviderFlags_Proxy(IEnroll *This,LONG *pdwFlags);
  void __RPC_STUB IEnroll_get_ProviderFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_ProviderFlags_Proxy(IEnroll *This,LONG dwFlags);
  void __RPC_STUB IEnroll_put_ProviderFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_UseExistingKeySet_Proxy(IEnroll *This,WINBOOL *fUseExistingKeys);
  void __RPC_STUB IEnroll_get_UseExistingKeySet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_UseExistingKeySet_Proxy(IEnroll *This,WINBOOL fUseExistingKeys);
  void __RPC_STUB IEnroll_put_UseExistingKeySet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_GenKeyFlags_Proxy(IEnroll *This,LONG *pdwFlags);
  void __RPC_STUB IEnroll_get_GenKeyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_GenKeyFlags_Proxy(IEnroll *This,LONG dwFlags);
  void __RPC_STUB IEnroll_put_GenKeyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_DeleteRequestCert_Proxy(IEnroll *This,WINBOOL *fDelete);
  void __RPC_STUB IEnroll_get_DeleteRequestCert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_DeleteRequestCert_Proxy(IEnroll *This,WINBOOL fDelete);
  void __RPC_STUB IEnroll_put_DeleteRequestCert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_WriteCertToUserDS_Proxy(IEnroll *This,WINBOOL *fBool);
  void __RPC_STUB IEnroll_get_WriteCertToUserDS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_WriteCertToUserDS_Proxy(IEnroll *This,WINBOOL fBool);
  void __RPC_STUB IEnroll_put_WriteCertToUserDS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_EnableT61DNEncoding_Proxy(IEnroll *This,WINBOOL *fBool);
  void __RPC_STUB IEnroll_get_EnableT61DNEncoding_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_EnableT61DNEncoding_Proxy(IEnroll *This,WINBOOL fBool);
  void __RPC_STUB IEnroll_put_EnableT61DNEncoding_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_WriteCertToCSP_Proxy(IEnroll *This,WINBOOL *fBool);
  void __RPC_STUB IEnroll_get_WriteCertToCSP_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_WriteCertToCSP_Proxy(IEnroll *This,WINBOOL fBool);
  void __RPC_STUB IEnroll_put_WriteCertToCSP_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_SPCFileNameWStr_Proxy(IEnroll *This,LPWSTR *szw);
  void __RPC_STUB IEnroll_get_SPCFileNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_SPCFileNameWStr_Proxy(IEnroll *This,LPWSTR szw);
  void __RPC_STUB IEnroll_put_SPCFileNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_PVKFileNameWStr_Proxy(IEnroll *This,LPWSTR *szw);
  void __RPC_STUB IEnroll_get_PVKFileNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_PVKFileNameWStr_Proxy(IEnroll *This,LPWSTR szw);
  void __RPC_STUB IEnroll_put_PVKFileNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_HashAlgorithmWStr_Proxy(IEnroll *This,LPWSTR *szw);
  void __RPC_STUB IEnroll_get_HashAlgorithmWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_HashAlgorithmWStr_Proxy(IEnroll *This,LPWSTR szw);
  void __RPC_STUB IEnroll_put_HashAlgorithmWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_get_RenewalCertificate_Proxy(IEnroll *This,PCCERT_CONTEXT *ppCertContext);
  void __RPC_STUB IEnroll_get_RenewalCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_put_RenewalCertificate_Proxy(IEnroll *This,PCCERT_CONTEXT pCertContext);
  void __RPC_STUB IEnroll_put_RenewalCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_AddCertTypeToRequestWStr_Proxy(IEnroll *This,LPWSTR szw);
  void __RPC_STUB IEnroll_AddCertTypeToRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_AddNameValuePairToSignatureWStr_Proxy(IEnroll *This,LPWSTR Name,LPWSTR Value);
  void __RPC_STUB IEnroll_AddNameValuePairToSignatureWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_AddExtensionsToRequest_Proxy(IEnroll *This,PCERT_EXTENSIONS pCertExtensions);
  void __RPC_STUB IEnroll_AddExtensionsToRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_AddAuthenticatedAttributesToPKCS7Request_Proxy(IEnroll *This,PCRYPT_ATTRIBUTES pAttributes);
  void __RPC_STUB IEnroll_AddAuthenticatedAttributesToPKCS7Request_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll_CreatePKCS7RequestFromRequest_Proxy(IEnroll *This,PCRYPT_DATA_BLOB pRequest,PCCERT_CONTEXT pSigningCertContext,PCRYPT_DATA_BLOB pPkcs7Blob);
  void __RPC_STUB IEnroll_CreatePKCS7RequestFromRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnroll2_INTERFACE_DEFINED__
#define __IEnroll2_INTERFACE_DEFINED__
  extern const IID IID_IEnroll2;
#if defined(__cplusplus) && !defined(CINTERFACE)
#ifdef __cplusplus
}
#endif
  struct IEnroll2 : public IEnroll {
  public:
    virtual HRESULT WINAPI InstallPKCS7Blob(PCRYPT_DATA_BLOB pBlobPKCS7) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI GetSupportedKeySpec(LONG *pdwKeySpec) = 0;
    virtual HRESULT WINAPI GetKeyLen(WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize) = 0;
    virtual HRESULT WINAPI EnumAlgs(LONG dwIndex,LONG algClass,LONG *pdwAlgID) = 0;
    virtual HRESULT WINAPI GetAlgNameWStr(LONG algID,LPWSTR *ppwsz) = 0;
    virtual HRESULT WINAPI put_ReuseHardwareKeyIfUnableToGenNew(WINBOOL fReuseHardwareKeyIfUnableToGenNew) = 0;
    virtual HRESULT WINAPI get_ReuseHardwareKeyIfUnableToGenNew(WINBOOL *fReuseHardwareKeyIfUnableToGenNew) = 0;
    virtual HRESULT WINAPI put_HashAlgID(LONG hashAlgID) = 0;
    virtual HRESULT WINAPI get_HashAlgID(LONG *hashAlgID) = 0;
    virtual HRESULT WINAPI SetHStoreMy(HCERTSTORE hStore) = 0;
    virtual HRESULT WINAPI SetHStoreCA(HCERTSTORE hStore) = 0;
    virtual HRESULT WINAPI SetHStoreROOT(HCERTSTORE hStore) = 0;
    virtual HRESULT WINAPI SetHStoreRequest(HCERTSTORE hStore) = 0;
    virtual HRESULT WINAPI put_LimitExchangeKeyToEncipherment(WINBOOL fLimitExchangeKeyToEncipherment) = 0;
    virtual HRESULT WINAPI get_LimitExchangeKeyToEncipherment(WINBOOL *fLimitExchangeKeyToEncipherment) = 0;
    virtual HRESULT WINAPI put_EnableSMIMECapabilities(WINBOOL fEnableSMIMECapabilities) = 0;
    virtual HRESULT WINAPI get_EnableSMIMECapabilities(WINBOOL *fEnableSMIMECapabilities) = 0;
  };
#ifdef __cplusplus
  extern "C" {
#endif
#else
  typedef struct IEnroll2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnroll2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnroll2 *This);
      ULONG (WINAPI *Release)(IEnroll2 *This);
      HRESULT (WINAPI *createFilePKCS10WStr)(IEnroll2 *This,LPCWSTR DNName,LPCWSTR Usage,LPCWSTR wszPKCS10FileName);
      HRESULT (WINAPI *acceptFilePKCS7WStr)(IEnroll2 *This,LPCWSTR wszPKCS7FileName);
      HRESULT (WINAPI *createPKCS10WStr)(IEnroll2 *This,LPCWSTR DNName,LPCWSTR Usage,PCRYPT_DATA_BLOB pPkcs10Blob);
      HRESULT (WINAPI *acceptPKCS7Blob)(IEnroll2 *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      PCCERT_CONTEXT (WINAPI *getCertContextFromPKCS7)(IEnroll2 *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      HCERTSTORE (WINAPI *getMyStore)(IEnroll2 *This);
      HCERTSTORE (WINAPI *getCAStore)(IEnroll2 *This);
      HCERTSTORE (WINAPI *getROOTHStore)(IEnroll2 *This);
      HRESULT (WINAPI *enumProvidersWStr)(IEnroll2 *This,LONG dwIndex,LONG dwFlags,LPWSTR *pbstrProvName);
      HRESULT (WINAPI *enumContainersWStr)(IEnroll2 *This,LONG dwIndex,LPWSTR *pbstr);
      HRESULT (WINAPI *freeRequestInfoBlob)(IEnroll2 *This,CRYPT_DATA_BLOB pkcs7OrPkcs10);
      HRESULT (WINAPI *get_MyStoreNameWStr)(IEnroll2 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_MyStoreNameWStr)(IEnroll2 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_MyStoreTypeWStr)(IEnroll2 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_MyStoreTypeWStr)(IEnroll2 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_MyStoreFlags)(IEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_MyStoreFlags)(IEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_CAStoreNameWStr)(IEnroll2 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_CAStoreNameWStr)(IEnroll2 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_CAStoreTypeWStr)(IEnroll2 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_CAStoreTypeWStr)(IEnroll2 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_CAStoreFlags)(IEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_CAStoreFlags)(IEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RootStoreNameWStr)(IEnroll2 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_RootStoreNameWStr)(IEnroll2 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_RootStoreTypeWStr)(IEnroll2 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_RootStoreTypeWStr)(IEnroll2 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_RootStoreFlags)(IEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RootStoreFlags)(IEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RequestStoreNameWStr)(IEnroll2 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_RequestStoreNameWStr)(IEnroll2 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_RequestStoreTypeWStr)(IEnroll2 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_RequestStoreTypeWStr)(IEnroll2 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_RequestStoreFlags)(IEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RequestStoreFlags)(IEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_ContainerNameWStr)(IEnroll2 *This,LPWSTR *szwContainer);
      HRESULT (WINAPI *put_ContainerNameWStr)(IEnroll2 *This,LPWSTR szwContainer);
      HRESULT (WINAPI *get_ProviderNameWStr)(IEnroll2 *This,LPWSTR *szwProvider);
      HRESULT (WINAPI *put_ProviderNameWStr)(IEnroll2 *This,LPWSTR szwProvider);
      HRESULT (WINAPI *get_ProviderType)(IEnroll2 *This,LONG *pdwType);
      HRESULT (WINAPI *put_ProviderType)(IEnroll2 *This,LONG dwType);
      HRESULT (WINAPI *get_KeySpec)(IEnroll2 *This,LONG *pdw);
      HRESULT (WINAPI *put_KeySpec)(IEnroll2 *This,LONG dw);
      HRESULT (WINAPI *get_ProviderFlags)(IEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_ProviderFlags)(IEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_UseExistingKeySet)(IEnroll2 *This,WINBOOL *fUseExistingKeys);
      HRESULT (WINAPI *put_UseExistingKeySet)(IEnroll2 *This,WINBOOL fUseExistingKeys);
      HRESULT (WINAPI *get_GenKeyFlags)(IEnroll2 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_GenKeyFlags)(IEnroll2 *This,LONG dwFlags);
      HRESULT (WINAPI *get_DeleteRequestCert)(IEnroll2 *This,WINBOOL *fDelete);
      HRESULT (WINAPI *put_DeleteRequestCert)(IEnroll2 *This,WINBOOL fDelete);
      HRESULT (WINAPI *get_WriteCertToUserDS)(IEnroll2 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToUserDS)(IEnroll2 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_EnableT61DNEncoding)(IEnroll2 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_EnableT61DNEncoding)(IEnroll2 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_WriteCertToCSP)(IEnroll2 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToCSP)(IEnroll2 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_SPCFileNameWStr)(IEnroll2 *This,LPWSTR *szw);
      HRESULT (WINAPI *put_SPCFileNameWStr)(IEnroll2 *This,LPWSTR szw);
      HRESULT (WINAPI *get_PVKFileNameWStr)(IEnroll2 *This,LPWSTR *szw);
      HRESULT (WINAPI *put_PVKFileNameWStr)(IEnroll2 *This,LPWSTR szw);
      HRESULT (WINAPI *get_HashAlgorithmWStr)(IEnroll2 *This,LPWSTR *szw);
      HRESULT (WINAPI *put_HashAlgorithmWStr)(IEnroll2 *This,LPWSTR szw);
      HRESULT (WINAPI *get_RenewalCertificate)(IEnroll2 *This,PCCERT_CONTEXT *ppCertContext);
      HRESULT (WINAPI *put_RenewalCertificate)(IEnroll2 *This,PCCERT_CONTEXT pCertContext);
      HRESULT (WINAPI *AddCertTypeToRequestWStr)(IEnroll2 *This,LPWSTR szw);
      HRESULT (WINAPI *AddNameValuePairToSignatureWStr)(IEnroll2 *This,LPWSTR Name,LPWSTR Value);
      HRESULT (WINAPI *AddExtensionsToRequest)(IEnroll2 *This,PCERT_EXTENSIONS pCertExtensions);
      HRESULT (WINAPI *AddAuthenticatedAttributesToPKCS7Request)(IEnroll2 *This,PCRYPT_ATTRIBUTES pAttributes);
      HRESULT (WINAPI *CreatePKCS7RequestFromRequest)(IEnroll2 *This,PCRYPT_DATA_BLOB pRequest,PCCERT_CONTEXT pSigningCertContext,PCRYPT_DATA_BLOB pPkcs7Blob);
      HRESULT (WINAPI *InstallPKCS7Blob)(IEnroll2 *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      HRESULT (WINAPI *Reset)(IEnroll2 *This);
      HRESULT (WINAPI *GetSupportedKeySpec)(IEnroll2 *This,LONG *pdwKeySpec);
      HRESULT (WINAPI *GetKeyLen)(IEnroll2 *This,WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize);
      HRESULT (WINAPI *EnumAlgs)(IEnroll2 *This,LONG dwIndex,LONG algClass,LONG *pdwAlgID);
      HRESULT (WINAPI *GetAlgNameWStr)(IEnroll2 *This,LONG algID,LPWSTR *ppwsz);
      HRESULT (WINAPI *put_ReuseHardwareKeyIfUnableToGenNew)(IEnroll2 *This,WINBOOL fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *get_ReuseHardwareKeyIfUnableToGenNew)(IEnroll2 *This,WINBOOL *fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *put_HashAlgID)(IEnroll2 *This,LONG hashAlgID);
      HRESULT (WINAPI *get_HashAlgID)(IEnroll2 *This,LONG *hashAlgID);
      HRESULT (WINAPI *SetHStoreMy)(IEnroll2 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *SetHStoreCA)(IEnroll2 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *SetHStoreROOT)(IEnroll2 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *SetHStoreRequest)(IEnroll2 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *put_LimitExchangeKeyToEncipherment)(IEnroll2 *This,WINBOOL fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *get_LimitExchangeKeyToEncipherment)(IEnroll2 *This,WINBOOL *fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *put_EnableSMIMECapabilities)(IEnroll2 *This,WINBOOL fEnableSMIMECapabilities);
      HRESULT (WINAPI *get_EnableSMIMECapabilities)(IEnroll2 *This,WINBOOL *fEnableSMIMECapabilities);
    END_INTERFACE
  } IEnroll2Vtbl;
  struct IEnroll2 {
    CONST_VTBL struct IEnroll2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnroll2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnroll2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnroll2_Release(This) (This)->lpVtbl->Release(This)
#define IEnroll2_createFilePKCS10WStr(This,DNName,Usage,wszPKCS10FileName) (This)->lpVtbl->createFilePKCS10WStr(This,DNName,Usage,wszPKCS10FileName)
#define IEnroll2_acceptFilePKCS7WStr(This,wszPKCS7FileName) (This)->lpVtbl->acceptFilePKCS7WStr(This,wszPKCS7FileName)
#define IEnroll2_createPKCS10WStr(This,DNName,Usage,pPkcs10Blob) (This)->lpVtbl->createPKCS10WStr(This,DNName,Usage,pPkcs10Blob)
#define IEnroll2_acceptPKCS7Blob(This,pBlobPKCS7) (This)->lpVtbl->acceptPKCS7Blob(This,pBlobPKCS7)
#define IEnroll2_getCertContextFromPKCS7(This,pBlobPKCS7) (This)->lpVtbl->getCertContextFromPKCS7(This,pBlobPKCS7)
#define IEnroll2_getMyStore(This) (This)->lpVtbl->getMyStore(This)
#define IEnroll2_getCAStore(This) (This)->lpVtbl->getCAStore(This)
#define IEnroll2_getROOTHStore(This) (This)->lpVtbl->getROOTHStore(This)
#define IEnroll2_enumProvidersWStr(This,dwIndex,dwFlags,pbstrProvName) (This)->lpVtbl->enumProvidersWStr(This,dwIndex,dwFlags,pbstrProvName)
#define IEnroll2_enumContainersWStr(This,dwIndex,pbstr) (This)->lpVtbl->enumContainersWStr(This,dwIndex,pbstr)
#define IEnroll2_freeRequestInfoBlob(This,pkcs7OrPkcs10) (This)->lpVtbl->freeRequestInfoBlob(This,pkcs7OrPkcs10)
#define IEnroll2_get_MyStoreNameWStr(This,szwName) (This)->lpVtbl->get_MyStoreNameWStr(This,szwName)
#define IEnroll2_put_MyStoreNameWStr(This,szwName) (This)->lpVtbl->put_MyStoreNameWStr(This,szwName)
#define IEnroll2_get_MyStoreTypeWStr(This,szwType) (This)->lpVtbl->get_MyStoreTypeWStr(This,szwType)
#define IEnroll2_put_MyStoreTypeWStr(This,szwType) (This)->lpVtbl->put_MyStoreTypeWStr(This,szwType)
#define IEnroll2_get_MyStoreFlags(This,pdwFlags) (This)->lpVtbl->get_MyStoreFlags(This,pdwFlags)
#define IEnroll2_put_MyStoreFlags(This,dwFlags) (This)->lpVtbl->put_MyStoreFlags(This,dwFlags)
#define IEnroll2_get_CAStoreNameWStr(This,szwName) (This)->lpVtbl->get_CAStoreNameWStr(This,szwName)
#define IEnroll2_put_CAStoreNameWStr(This,szwName) (This)->lpVtbl->put_CAStoreNameWStr(This,szwName)
#define IEnroll2_get_CAStoreTypeWStr(This,szwType) (This)->lpVtbl->get_CAStoreTypeWStr(This,szwType)
#define IEnroll2_put_CAStoreTypeWStr(This,szwType) (This)->lpVtbl->put_CAStoreTypeWStr(This,szwType)
#define IEnroll2_get_CAStoreFlags(This,pdwFlags) (This)->lpVtbl->get_CAStoreFlags(This,pdwFlags)
#define IEnroll2_put_CAStoreFlags(This,dwFlags) (This)->lpVtbl->put_CAStoreFlags(This,dwFlags)
#define IEnroll2_get_RootStoreNameWStr(This,szwName) (This)->lpVtbl->get_RootStoreNameWStr(This,szwName)
#define IEnroll2_put_RootStoreNameWStr(This,szwName) (This)->lpVtbl->put_RootStoreNameWStr(This,szwName)
#define IEnroll2_get_RootStoreTypeWStr(This,szwType) (This)->lpVtbl->get_RootStoreTypeWStr(This,szwType)
#define IEnroll2_put_RootStoreTypeWStr(This,szwType) (This)->lpVtbl->put_RootStoreTypeWStr(This,szwType)
#define IEnroll2_get_RootStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RootStoreFlags(This,pdwFlags)
#define IEnroll2_put_RootStoreFlags(This,dwFlags) (This)->lpVtbl->put_RootStoreFlags(This,dwFlags)
#define IEnroll2_get_RequestStoreNameWStr(This,szwName) (This)->lpVtbl->get_RequestStoreNameWStr(This,szwName)
#define IEnroll2_put_RequestStoreNameWStr(This,szwName) (This)->lpVtbl->put_RequestStoreNameWStr(This,szwName)
#define IEnroll2_get_RequestStoreTypeWStr(This,szwType) (This)->lpVtbl->get_RequestStoreTypeWStr(This,szwType)
#define IEnroll2_put_RequestStoreTypeWStr(This,szwType) (This)->lpVtbl->put_RequestStoreTypeWStr(This,szwType)
#define IEnroll2_get_RequestStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RequestStoreFlags(This,pdwFlags)
#define IEnroll2_put_RequestStoreFlags(This,dwFlags) (This)->lpVtbl->put_RequestStoreFlags(This,dwFlags)
#define IEnroll2_get_ContainerNameWStr(This,szwContainer) (This)->lpVtbl->get_ContainerNameWStr(This,szwContainer)
#define IEnroll2_put_ContainerNameWStr(This,szwContainer) (This)->lpVtbl->put_ContainerNameWStr(This,szwContainer)
#define IEnroll2_get_ProviderNameWStr(This,szwProvider) (This)->lpVtbl->get_ProviderNameWStr(This,szwProvider)
#define IEnroll2_put_ProviderNameWStr(This,szwProvider) (This)->lpVtbl->put_ProviderNameWStr(This,szwProvider)
#define IEnroll2_get_ProviderType(This,pdwType) (This)->lpVtbl->get_ProviderType(This,pdwType)
#define IEnroll2_put_ProviderType(This,dwType) (This)->lpVtbl->put_ProviderType(This,dwType)
#define IEnroll2_get_KeySpec(This,pdw) (This)->lpVtbl->get_KeySpec(This,pdw)
#define IEnroll2_put_KeySpec(This,dw) (This)->lpVtbl->put_KeySpec(This,dw)
#define IEnroll2_get_ProviderFlags(This,pdwFlags) (This)->lpVtbl->get_ProviderFlags(This,pdwFlags)
#define IEnroll2_put_ProviderFlags(This,dwFlags) (This)->lpVtbl->put_ProviderFlags(This,dwFlags)
#define IEnroll2_get_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->get_UseExistingKeySet(This,fUseExistingKeys)
#define IEnroll2_put_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->put_UseExistingKeySet(This,fUseExistingKeys)
#define IEnroll2_get_GenKeyFlags(This,pdwFlags) (This)->lpVtbl->get_GenKeyFlags(This,pdwFlags)
#define IEnroll2_put_GenKeyFlags(This,dwFlags) (This)->lpVtbl->put_GenKeyFlags(This,dwFlags)
#define IEnroll2_get_DeleteRequestCert(This,fDelete) (This)->lpVtbl->get_DeleteRequestCert(This,fDelete)
#define IEnroll2_put_DeleteRequestCert(This,fDelete) (This)->lpVtbl->put_DeleteRequestCert(This,fDelete)
#define IEnroll2_get_WriteCertToUserDS(This,fBool) (This)->lpVtbl->get_WriteCertToUserDS(This,fBool)
#define IEnroll2_put_WriteCertToUserDS(This,fBool) (This)->lpVtbl->put_WriteCertToUserDS(This,fBool)
#define IEnroll2_get_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->get_EnableT61DNEncoding(This,fBool)
#define IEnroll2_put_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->put_EnableT61DNEncoding(This,fBool)
#define IEnroll2_get_WriteCertToCSP(This,fBool) (This)->lpVtbl->get_WriteCertToCSP(This,fBool)
#define IEnroll2_put_WriteCertToCSP(This,fBool) (This)->lpVtbl->put_WriteCertToCSP(This,fBool)
#define IEnroll2_get_SPCFileNameWStr(This,szw) (This)->lpVtbl->get_SPCFileNameWStr(This,szw)
#define IEnroll2_put_SPCFileNameWStr(This,szw) (This)->lpVtbl->put_SPCFileNameWStr(This,szw)
#define IEnroll2_get_PVKFileNameWStr(This,szw) (This)->lpVtbl->get_PVKFileNameWStr(This,szw)
#define IEnroll2_put_PVKFileNameWStr(This,szw) (This)->lpVtbl->put_PVKFileNameWStr(This,szw)
#define IEnroll2_get_HashAlgorithmWStr(This,szw) (This)->lpVtbl->get_HashAlgorithmWStr(This,szw)
#define IEnroll2_put_HashAlgorithmWStr(This,szw) (This)->lpVtbl->put_HashAlgorithmWStr(This,szw)
#define IEnroll2_get_RenewalCertificate(This,ppCertContext) (This)->lpVtbl->get_RenewalCertificate(This,ppCertContext)
#define IEnroll2_put_RenewalCertificate(This,pCertContext) (This)->lpVtbl->put_RenewalCertificate(This,pCertContext)
#define IEnroll2_AddCertTypeToRequestWStr(This,szw) (This)->lpVtbl->AddCertTypeToRequestWStr(This,szw)
#define IEnroll2_AddNameValuePairToSignatureWStr(This,Name,Value) (This)->lpVtbl->AddNameValuePairToSignatureWStr(This,Name,Value)
#define IEnroll2_AddExtensionsToRequest(This,pCertExtensions) (This)->lpVtbl->AddExtensionsToRequest(This,pCertExtensions)
#define IEnroll2_AddAuthenticatedAttributesToPKCS7Request(This,pAttributes) (This)->lpVtbl->AddAuthenticatedAttributesToPKCS7Request(This,pAttributes)
#define IEnroll2_CreatePKCS7RequestFromRequest(This,pRequest,pSigningCertContext,pPkcs7Blob) (This)->lpVtbl->CreatePKCS7RequestFromRequest(This,pRequest,pSigningCertContext,pPkcs7Blob)
#define IEnroll2_InstallPKCS7Blob(This,pBlobPKCS7) (This)->lpVtbl->InstallPKCS7Blob(This,pBlobPKCS7)
#define IEnroll2_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnroll2_GetSupportedKeySpec(This,pdwKeySpec) (This)->lpVtbl->GetSupportedKeySpec(This,pdwKeySpec)
#define IEnroll2_GetKeyLen(This,fMin,fExchange,pdwKeySize) (This)->lpVtbl->GetKeyLen(This,fMin,fExchange,pdwKeySize)
#define IEnroll2_EnumAlgs(This,dwIndex,algClass,pdwAlgID) (This)->lpVtbl->EnumAlgs(This,dwIndex,algClass,pdwAlgID)
#define IEnroll2_GetAlgNameWStr(This,algID,ppwsz) (This)->lpVtbl->GetAlgNameWStr(This,algID,ppwsz)
#define IEnroll2_put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define IEnroll2_get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define IEnroll2_put_HashAlgID(This,hashAlgID) (This)->lpVtbl->put_HashAlgID(This,hashAlgID)
#define IEnroll2_get_HashAlgID(This,hashAlgID) (This)->lpVtbl->get_HashAlgID(This,hashAlgID)
#define IEnroll2_SetHStoreMy(This,hStore) (This)->lpVtbl->SetHStoreMy(This,hStore)
#define IEnroll2_SetHStoreCA(This,hStore) (This)->lpVtbl->SetHStoreCA(This,hStore)
#define IEnroll2_SetHStoreROOT(This,hStore) (This)->lpVtbl->SetHStoreROOT(This,hStore)
#define IEnroll2_SetHStoreRequest(This,hStore) (This)->lpVtbl->SetHStoreRequest(This,hStore)
#define IEnroll2_put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define IEnroll2_get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define IEnroll2_put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#define IEnroll2_get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#endif
#endif
  HRESULT WINAPI IEnroll2_InstallPKCS7Blob_Proxy(IEnroll2 *This,PCRYPT_DATA_BLOB pBlobPKCS7);
  void __RPC_STUB IEnroll2_InstallPKCS7Blob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_Reset_Proxy(IEnroll2 *This);
  void __RPC_STUB IEnroll2_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_GetSupportedKeySpec_Proxy(IEnroll2 *This,LONG *pdwKeySpec);
  void __RPC_STUB IEnroll2_GetSupportedKeySpec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_GetKeyLen_Proxy(IEnroll2 *This,WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize);
  void __RPC_STUB IEnroll2_GetKeyLen_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_EnumAlgs_Proxy(IEnroll2 *This,LONG dwIndex,LONG algClass,LONG *pdwAlgID);
  void __RPC_STUB IEnroll2_EnumAlgs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_GetAlgNameWStr_Proxy(IEnroll2 *This,LONG algID,LPWSTR *ppwsz);
  void __RPC_STUB IEnroll2_GetAlgNameWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_put_ReuseHardwareKeyIfUnableToGenNew_Proxy(IEnroll2 *This,WINBOOL fReuseHardwareKeyIfUnableToGenNew);
  void __RPC_STUB IEnroll2_put_ReuseHardwareKeyIfUnableToGenNew_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_get_ReuseHardwareKeyIfUnableToGenNew_Proxy(IEnroll2 *This,WINBOOL *fReuseHardwareKeyIfUnableToGenNew);
  void __RPC_STUB IEnroll2_get_ReuseHardwareKeyIfUnableToGenNew_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_put_HashAlgID_Proxy(IEnroll2 *This,LONG hashAlgID);
  void __RPC_STUB IEnroll2_put_HashAlgID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_get_HashAlgID_Proxy(IEnroll2 *This,LONG *hashAlgID);
  void __RPC_STUB IEnroll2_get_HashAlgID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_SetHStoreMy_Proxy(IEnroll2 *This,HCERTSTORE hStore);
  void __RPC_STUB IEnroll2_SetHStoreMy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_SetHStoreCA_Proxy(IEnroll2 *This,HCERTSTORE hStore);
  void __RPC_STUB IEnroll2_SetHStoreCA_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_SetHStoreROOT_Proxy(IEnroll2 *This,HCERTSTORE hStore);
  void __RPC_STUB IEnroll2_SetHStoreROOT_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_SetHStoreRequest_Proxy(IEnroll2 *This,HCERTSTORE hStore);
  void __RPC_STUB IEnroll2_SetHStoreRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_put_LimitExchangeKeyToEncipherment_Proxy(IEnroll2 *This,WINBOOL fLimitExchangeKeyToEncipherment);
  void __RPC_STUB IEnroll2_put_LimitExchangeKeyToEncipherment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_get_LimitExchangeKeyToEncipherment_Proxy(IEnroll2 *This,WINBOOL *fLimitExchangeKeyToEncipherment);
  void __RPC_STUB IEnroll2_get_LimitExchangeKeyToEncipherment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_put_EnableSMIMECapabilities_Proxy(IEnroll2 *This,WINBOOL fEnableSMIMECapabilities);
  void __RPC_STUB IEnroll2_put_EnableSMIMECapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll2_get_EnableSMIMECapabilities_Proxy(IEnroll2 *This,WINBOOL *fEnableSMIMECapabilities);
  void __RPC_STUB IEnroll2_get_EnableSMIMECapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnroll4_INTERFACE_DEFINED__
#define __IEnroll4_INTERFACE_DEFINED__
  extern const IID IID_IEnroll4;
#if defined(__cplusplus) && !defined(CINTERFACE)
#ifdef __cplusplus
}
#endif
  struct IEnroll4 : public IEnroll2 {
  public:
    virtual HRESULT WINAPI put_ThumbPrintWStr(CRYPT_DATA_BLOB thumbPrintBlob) = 0;
    virtual HRESULT WINAPI get_ThumbPrintWStr(PCRYPT_DATA_BLOB thumbPrintBlob) = 0;
    virtual HRESULT WINAPI SetPrivateKeyArchiveCertificate(PCCERT_CONTEXT pPrivateKeyArchiveCert) = 0;
    virtual PCCERT_CONTEXT WINAPI GetPrivateKeyArchiveCertificate(void) = 0;
    virtual HRESULT WINAPI binaryBlobToString(LONG Flags,PCRYPT_DATA_BLOB pblobBinary,LPWSTR *ppwszString) = 0;
    virtual HRESULT WINAPI stringToBinaryBlob(LONG Flags,LPCWSTR pwszString,PCRYPT_DATA_BLOB pblobBinary,LONG *pdwSkip,LONG *pdwFlags) = 0;
    virtual HRESULT WINAPI addExtensionToRequestWStr(LONG Flags,LPCWSTR pwszName,PCRYPT_DATA_BLOB pblobValue) = 0;
    virtual HRESULT WINAPI addAttributeToRequestWStr(LONG Flags,LPCWSTR pwszName,PCRYPT_DATA_BLOB pblobValue) = 0;
    virtual HRESULT WINAPI addNameValuePairToRequestWStr(LONG Flags,LPCWSTR pwszName,LPCWSTR pwszValue) = 0;
    virtual HRESULT WINAPI resetExtensions(void) = 0;
    virtual HRESULT WINAPI resetAttributes(void) = 0;
    virtual HRESULT WINAPI createRequestWStr(LONG Flags,LPCWSTR pwszDNName,LPCWSTR pwszUsage,PCRYPT_DATA_BLOB pblobRequest) = 0;
    virtual HRESULT WINAPI createFileRequestWStr(LONG Flags,LPCWSTR pwszDNName,LPCWSTR pwszUsage,LPCWSTR pwszRequestFileName) = 0;
    virtual HRESULT WINAPI acceptResponseBlob(PCRYPT_DATA_BLOB pblobResponse) = 0;
    virtual HRESULT WINAPI acceptFileResponseWStr(LPCWSTR pwszResponseFileName) = 0;
    virtual HRESULT WINAPI getCertContextFromResponseBlob(PCRYPT_DATA_BLOB pblobResponse,PCCERT_CONTEXT *ppCertContext) = 0;
    virtual HRESULT WINAPI getCertContextFromFileResponseWStr(LPCWSTR pwszResponseFileName,PCCERT_CONTEXT *ppCertContext) = 0;
    virtual HRESULT WINAPI createPFXWStr(LPCWSTR pwszPassword,PCRYPT_DATA_BLOB pblobPFX) = 0;
    virtual HRESULT WINAPI createFilePFXWStr(LPCWSTR pwszPassword,LPCWSTR pwszPFXFileName) = 0;
    virtual HRESULT WINAPI setPendingRequestInfoWStr(LONG lRequestID,LPCWSTR pwszCADNS,LPCWSTR pwszCAName,LPCWSTR pwszFriendlyName) = 0;
    virtual HRESULT WINAPI enumPendingRequestWStr(LONG lIndex,LONG lDesiredProperty,LPVOID ppProperty) = 0;
    virtual HRESULT WINAPI removePendingRequestWStr(CRYPT_DATA_BLOB thumbPrintBlob) = 0;
    virtual HRESULT WINAPI GetKeyLenEx(LONG lSizeSpec,LONG lKeySpec,LONG *pdwKeySize) = 0;
    virtual HRESULT WINAPI InstallPKCS7BlobEx(PCRYPT_DATA_BLOB pBlobPKCS7,LONG *plCertInstalled) = 0;
    virtual HRESULT WINAPI AddCertTypeToRequestWStrEx(LONG lType,LPCWSTR pwszOIDOrName,LONG lMajorVersion,WINBOOL fMinorVersion,LONG lMinorVersion) = 0;
    virtual HRESULT WINAPI getProviderTypeWStr(LPCWSTR pwszProvName,LONG *plProvType) = 0;
    virtual HRESULT WINAPI addBlobPropertyToCertificateWStr(LONG lPropertyId,LONG lReserved,PCRYPT_DATA_BLOB pBlobProperty) = 0;
    virtual HRESULT WINAPI SetSignerCertificate(PCCERT_CONTEXT pSignerCert) = 0;
    virtual HRESULT WINAPI put_ClientId(LONG lClientId) = 0;
    virtual HRESULT WINAPI get_ClientId(LONG *plClientId) = 0;
    virtual HRESULT WINAPI put_IncludeSubjectKeyID(WINBOOL fInclude) = 0;
    virtual HRESULT WINAPI get_IncludeSubjectKeyID(WINBOOL *pfInclude) = 0;
  };
#ifdef __cplusplus
  extern "C" {
#endif
#else
  typedef struct IEnroll4Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnroll4 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnroll4 *This);
      ULONG (WINAPI *Release)(IEnroll4 *This);
      HRESULT (WINAPI *createFilePKCS10WStr)(IEnroll4 *This,LPCWSTR DNName,LPCWSTR Usage,LPCWSTR wszPKCS10FileName);
      HRESULT (WINAPI *acceptFilePKCS7WStr)(IEnroll4 *This,LPCWSTR wszPKCS7FileName);
      HRESULT (WINAPI *createPKCS10WStr)(IEnroll4 *This,LPCWSTR DNName,LPCWSTR Usage,PCRYPT_DATA_BLOB pPkcs10Blob);
      HRESULT (WINAPI *acceptPKCS7Blob)(IEnroll4 *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      PCCERT_CONTEXT (WINAPI *getCertContextFromPKCS7)(IEnroll4 *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      HCERTSTORE (WINAPI *getMyStore)(IEnroll4 *This);
      HCERTSTORE (WINAPI *getCAStore)(IEnroll4 *This);
      HCERTSTORE (WINAPI *getROOTHStore)(IEnroll4 *This);
      HRESULT (WINAPI *enumProvidersWStr)(IEnroll4 *This,LONG dwIndex,LONG dwFlags,LPWSTR *pbstrProvName);
      HRESULT (WINAPI *enumContainersWStr)(IEnroll4 *This,LONG dwIndex,LPWSTR *pbstr);
      HRESULT (WINAPI *freeRequestInfoBlob)(IEnroll4 *This,CRYPT_DATA_BLOB pkcs7OrPkcs10);
      HRESULT (WINAPI *get_MyStoreNameWStr)(IEnroll4 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_MyStoreNameWStr)(IEnroll4 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_MyStoreTypeWStr)(IEnroll4 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_MyStoreTypeWStr)(IEnroll4 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_MyStoreFlags)(IEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_MyStoreFlags)(IEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_CAStoreNameWStr)(IEnroll4 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_CAStoreNameWStr)(IEnroll4 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_CAStoreTypeWStr)(IEnroll4 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_CAStoreTypeWStr)(IEnroll4 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_CAStoreFlags)(IEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_CAStoreFlags)(IEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RootStoreNameWStr)(IEnroll4 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_RootStoreNameWStr)(IEnroll4 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_RootStoreTypeWStr)(IEnroll4 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_RootStoreTypeWStr)(IEnroll4 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_RootStoreFlags)(IEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RootStoreFlags)(IEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_RequestStoreNameWStr)(IEnroll4 *This,LPWSTR *szwName);
      HRESULT (WINAPI *put_RequestStoreNameWStr)(IEnroll4 *This,LPWSTR szwName);
      HRESULT (WINAPI *get_RequestStoreTypeWStr)(IEnroll4 *This,LPWSTR *szwType);
      HRESULT (WINAPI *put_RequestStoreTypeWStr)(IEnroll4 *This,LPWSTR szwType);
      HRESULT (WINAPI *get_RequestStoreFlags)(IEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_RequestStoreFlags)(IEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_ContainerNameWStr)(IEnroll4 *This,LPWSTR *szwContainer);
      HRESULT (WINAPI *put_ContainerNameWStr)(IEnroll4 *This,LPWSTR szwContainer);
      HRESULT (WINAPI *get_ProviderNameWStr)(IEnroll4 *This,LPWSTR *szwProvider);
      HRESULT (WINAPI *put_ProviderNameWStr)(IEnroll4 *This,LPWSTR szwProvider);
      HRESULT (WINAPI *get_ProviderType)(IEnroll4 *This,LONG *pdwType);
      HRESULT (WINAPI *put_ProviderType)(IEnroll4 *This,LONG dwType);
      HRESULT (WINAPI *get_KeySpec)(IEnroll4 *This,LONG *pdw);
      HRESULT (WINAPI *put_KeySpec)(IEnroll4 *This,LONG dw);
      HRESULT (WINAPI *get_ProviderFlags)(IEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_ProviderFlags)(IEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_UseExistingKeySet)(IEnroll4 *This,WINBOOL *fUseExistingKeys);
      HRESULT (WINAPI *put_UseExistingKeySet)(IEnroll4 *This,WINBOOL fUseExistingKeys);
      HRESULT (WINAPI *get_GenKeyFlags)(IEnroll4 *This,LONG *pdwFlags);
      HRESULT (WINAPI *put_GenKeyFlags)(IEnroll4 *This,LONG dwFlags);
      HRESULT (WINAPI *get_DeleteRequestCert)(IEnroll4 *This,WINBOOL *fDelete);
      HRESULT (WINAPI *put_DeleteRequestCert)(IEnroll4 *This,WINBOOL fDelete);
      HRESULT (WINAPI *get_WriteCertToUserDS)(IEnroll4 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToUserDS)(IEnroll4 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_EnableT61DNEncoding)(IEnroll4 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_EnableT61DNEncoding)(IEnroll4 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_WriteCertToCSP)(IEnroll4 *This,WINBOOL *fBool);
      HRESULT (WINAPI *put_WriteCertToCSP)(IEnroll4 *This,WINBOOL fBool);
      HRESULT (WINAPI *get_SPCFileNameWStr)(IEnroll4 *This,LPWSTR *szw);
      HRESULT (WINAPI *put_SPCFileNameWStr)(IEnroll4 *This,LPWSTR szw);
      HRESULT (WINAPI *get_PVKFileNameWStr)(IEnroll4 *This,LPWSTR *szw);
      HRESULT (WINAPI *put_PVKFileNameWStr)(IEnroll4 *This,LPWSTR szw);
      HRESULT (WINAPI *get_HashAlgorithmWStr)(IEnroll4 *This,LPWSTR *szw);
      HRESULT (WINAPI *put_HashAlgorithmWStr)(IEnroll4 *This,LPWSTR szw);
      HRESULT (WINAPI *get_RenewalCertificate)(IEnroll4 *This,PCCERT_CONTEXT *ppCertContext);
      HRESULT (WINAPI *put_RenewalCertificate)(IEnroll4 *This,PCCERT_CONTEXT pCertContext);
      HRESULT (WINAPI *AddCertTypeToRequestWStr)(IEnroll4 *This,LPWSTR szw);
      HRESULT (WINAPI *AddNameValuePairToSignatureWStr)(IEnroll4 *This,LPWSTR Name,LPWSTR Value);
      HRESULT (WINAPI *AddExtensionsToRequest)(IEnroll4 *This,PCERT_EXTENSIONS pCertExtensions);
      HRESULT (WINAPI *AddAuthenticatedAttributesToPKCS7Request)(IEnroll4 *This,PCRYPT_ATTRIBUTES pAttributes);
      HRESULT (WINAPI *CreatePKCS7RequestFromRequest)(IEnroll4 *This,PCRYPT_DATA_BLOB pRequest,PCCERT_CONTEXT pSigningCertContext,PCRYPT_DATA_BLOB pPkcs7Blob);
      HRESULT (WINAPI *InstallPKCS7Blob)(IEnroll4 *This,PCRYPT_DATA_BLOB pBlobPKCS7);
      HRESULT (WINAPI *Reset)(IEnroll4 *This);
      HRESULT (WINAPI *GetSupportedKeySpec)(IEnroll4 *This,LONG *pdwKeySpec);
      HRESULT (WINAPI *GetKeyLen)(IEnroll4 *This,WINBOOL fMin,WINBOOL fExchange,LONG *pdwKeySize);
      HRESULT (WINAPI *EnumAlgs)(IEnroll4 *This,LONG dwIndex,LONG algClass,LONG *pdwAlgID);
      HRESULT (WINAPI *GetAlgNameWStr)(IEnroll4 *This,LONG algID,LPWSTR *ppwsz);
      HRESULT (WINAPI *put_ReuseHardwareKeyIfUnableToGenNew)(IEnroll4 *This,WINBOOL fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *get_ReuseHardwareKeyIfUnableToGenNew)(IEnroll4 *This,WINBOOL *fReuseHardwareKeyIfUnableToGenNew);
      HRESULT (WINAPI *put_HashAlgID)(IEnroll4 *This,LONG hashAlgID);
      HRESULT (WINAPI *get_HashAlgID)(IEnroll4 *This,LONG *hashAlgID);
      HRESULT (WINAPI *SetHStoreMy)(IEnroll4 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *SetHStoreCA)(IEnroll4 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *SetHStoreROOT)(IEnroll4 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *SetHStoreRequest)(IEnroll4 *This,HCERTSTORE hStore);
      HRESULT (WINAPI *put_LimitExchangeKeyToEncipherment)(IEnroll4 *This,WINBOOL fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *get_LimitExchangeKeyToEncipherment)(IEnroll4 *This,WINBOOL *fLimitExchangeKeyToEncipherment);
      HRESULT (WINAPI *put_EnableSMIMECapabilities)(IEnroll4 *This,WINBOOL fEnableSMIMECapabilities);
      HRESULT (WINAPI *get_EnableSMIMECapabilities)(IEnroll4 *This,WINBOOL *fEnableSMIMECapabilities);
      HRESULT (WINAPI *put_ThumbPrintWStr)(IEnroll4 *This,CRYPT_DATA_BLOB thumbPrintBlob);
      HRESULT (WINAPI *get_ThumbPrintWStr)(IEnroll4 *This,PCRYPT_DATA_BLOB thumbPrintBlob);
      HRESULT (WINAPI *SetPrivateKeyArchiveCertificate)(IEnroll4 *This,PCCERT_CONTEXT pPrivateKeyArchiveCert);
      PCCERT_CONTEXT (WINAPI *GetPrivateKeyArchiveCertificate)(IEnroll4 *This);
      HRESULT (WINAPI *binaryBlobToString)(IEnroll4 *This,LONG Flags,PCRYPT_DATA_BLOB pblobBinary,LPWSTR *ppwszString);
      HRESULT (WINAPI *stringToBinaryBlob)(IEnroll4 *This,LONG Flags,LPCWSTR pwszString,PCRYPT_DATA_BLOB pblobBinary,LONG *pdwSkip,LONG *pdwFlags);
      HRESULT (WINAPI *addExtensionToRequestWStr)(IEnroll4 *This,LONG Flags,LPCWSTR pwszName,PCRYPT_DATA_BLOB pblobValue);
      HRESULT (WINAPI *addAttributeToRequestWStr)(IEnroll4 *This,LONG Flags,LPCWSTR pwszName,PCRYPT_DATA_BLOB pblobValue);
      HRESULT (WINAPI *addNameValuePairToRequestWStr)(IEnroll4 *This,LONG Flags,LPCWSTR pwszName,LPCWSTR pwszValue);
      HRESULT (WINAPI *resetExtensions)(IEnroll4 *This);
      HRESULT (WINAPI *resetAttributes)(IEnroll4 *This);
      HRESULT (WINAPI *createRequestWStr)(IEnroll4 *This,LONG Flags,LPCWSTR pwszDNName,LPCWSTR pwszUsage,PCRYPT_DATA_BLOB pblobRequest);
      HRESULT (WINAPI *createFileRequestWStr)(IEnroll4 *This,LONG Flags,LPCWSTR pwszDNName,LPCWSTR pwszUsage,LPCWSTR pwszRequestFileName);
      HRESULT (WINAPI *acceptResponseBlob)(IEnroll4 *This,PCRYPT_DATA_BLOB pblobResponse);
      HRESULT (WINAPI *acceptFileResponseWStr)(IEnroll4 *This,LPCWSTR pwszResponseFileName);
      HRESULT (WINAPI *getCertContextFromResponseBlob)(IEnroll4 *This,PCRYPT_DATA_BLOB pblobResponse,PCCERT_CONTEXT *ppCertContext);
      HRESULT (WINAPI *getCertContextFromFileResponseWStr)(IEnroll4 *This,LPCWSTR pwszResponseFileName,PCCERT_CONTEXT *ppCertContext);
      HRESULT (WINAPI *createPFXWStr)(IEnroll4 *This,LPCWSTR pwszPassword,PCRYPT_DATA_BLOB pblobPFX);
      HRESULT (WINAPI *createFilePFXWStr)(IEnroll4 *This,LPCWSTR pwszPassword,LPCWSTR pwszPFXFileName);
      HRESULT (WINAPI *setPendingRequestInfoWStr)(IEnroll4 *This,LONG lRequestID,LPCWSTR pwszCADNS,LPCWSTR pwszCAName,LPCWSTR pwszFriendlyName);
      HRESULT (WINAPI *enumPendingRequestWStr)(IEnroll4 *This,LONG lIndex,LONG lDesiredProperty,LPVOID ppProperty);
      HRESULT (WINAPI *removePendingRequestWStr)(IEnroll4 *This,CRYPT_DATA_BLOB thumbPrintBlob);
      HRESULT (WINAPI *GetKeyLenEx)(IEnroll4 *This,LONG lSizeSpec,LONG lKeySpec,LONG *pdwKeySize);
      HRESULT (WINAPI *InstallPKCS7BlobEx)(IEnroll4 *This,PCRYPT_DATA_BLOB pBlobPKCS7,LONG *plCertInstalled);
      HRESULT (WINAPI *AddCertTypeToRequestWStrEx)(IEnroll4 *This,LONG lType,LPCWSTR pwszOIDOrName,LONG lMajorVersion,WINBOOL fMinorVersion,LONG lMinorVersion);
      HRESULT (WINAPI *getProviderTypeWStr)(IEnroll4 *This,LPCWSTR pwszProvName,LONG *plProvType);
      HRESULT (WINAPI *addBlobPropertyToCertificateWStr)(IEnroll4 *This,LONG lPropertyId,LONG lReserved,PCRYPT_DATA_BLOB pBlobProperty);
      HRESULT (WINAPI *SetSignerCertificate)(IEnroll4 *This,PCCERT_CONTEXT pSignerCert);
      HRESULT (WINAPI *put_ClientId)(IEnroll4 *This,LONG lClientId);
      HRESULT (WINAPI *get_ClientId)(IEnroll4 *This,LONG *plClientId);
      HRESULT (WINAPI *put_IncludeSubjectKeyID)(IEnroll4 *This,WINBOOL fInclude);
      HRESULT (WINAPI *get_IncludeSubjectKeyID)(IEnroll4 *This,WINBOOL *pfInclude);
    END_INTERFACE
  } IEnroll4Vtbl;
  struct IEnroll4 {
    CONST_VTBL struct IEnroll4Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnroll4_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnroll4_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnroll4_Release(This) (This)->lpVtbl->Release(This)
#define IEnroll4_createFilePKCS10WStr(This,DNName,Usage,wszPKCS10FileName) (This)->lpVtbl->createFilePKCS10WStr(This,DNName,Usage,wszPKCS10FileName)
#define IEnroll4_acceptFilePKCS7WStr(This,wszPKCS7FileName) (This)->lpVtbl->acceptFilePKCS7WStr(This,wszPKCS7FileName)
#define IEnroll4_createPKCS10WStr(This,DNName,Usage,pPkcs10Blob) (This)->lpVtbl->createPKCS10WStr(This,DNName,Usage,pPkcs10Blob)
#define IEnroll4_acceptPKCS7Blob(This,pBlobPKCS7) (This)->lpVtbl->acceptPKCS7Blob(This,pBlobPKCS7)
#define IEnroll4_getCertContextFromPKCS7(This,pBlobPKCS7) (This)->lpVtbl->getCertContextFromPKCS7(This,pBlobPKCS7)
#define IEnroll4_getMyStore(This) (This)->lpVtbl->getMyStore(This)
#define IEnroll4_getCAStore(This) (This)->lpVtbl->getCAStore(This)
#define IEnroll4_getROOTHStore(This) (This)->lpVtbl->getROOTHStore(This)
#define IEnroll4_enumProvidersWStr(This,dwIndex,dwFlags,pbstrProvName) (This)->lpVtbl->enumProvidersWStr(This,dwIndex,dwFlags,pbstrProvName)
#define IEnroll4_enumContainersWStr(This,dwIndex,pbstr) (This)->lpVtbl->enumContainersWStr(This,dwIndex,pbstr)
#define IEnroll4_freeRequestInfoBlob(This,pkcs7OrPkcs10) (This)->lpVtbl->freeRequestInfoBlob(This,pkcs7OrPkcs10)
#define IEnroll4_get_MyStoreNameWStr(This,szwName) (This)->lpVtbl->get_MyStoreNameWStr(This,szwName)
#define IEnroll4_put_MyStoreNameWStr(This,szwName) (This)->lpVtbl->put_MyStoreNameWStr(This,szwName)
#define IEnroll4_get_MyStoreTypeWStr(This,szwType) (This)->lpVtbl->get_MyStoreTypeWStr(This,szwType)
#define IEnroll4_put_MyStoreTypeWStr(This,szwType) (This)->lpVtbl->put_MyStoreTypeWStr(This,szwType)
#define IEnroll4_get_MyStoreFlags(This,pdwFlags) (This)->lpVtbl->get_MyStoreFlags(This,pdwFlags)
#define IEnroll4_put_MyStoreFlags(This,dwFlags) (This)->lpVtbl->put_MyStoreFlags(This,dwFlags)
#define IEnroll4_get_CAStoreNameWStr(This,szwName) (This)->lpVtbl->get_CAStoreNameWStr(This,szwName)
#define IEnroll4_put_CAStoreNameWStr(This,szwName) (This)->lpVtbl->put_CAStoreNameWStr(This,szwName)
#define IEnroll4_get_CAStoreTypeWStr(This,szwType) (This)->lpVtbl->get_CAStoreTypeWStr(This,szwType)
#define IEnroll4_put_CAStoreTypeWStr(This,szwType) (This)->lpVtbl->put_CAStoreTypeWStr(This,szwType)
#define IEnroll4_get_CAStoreFlags(This,pdwFlags) (This)->lpVtbl->get_CAStoreFlags(This,pdwFlags)
#define IEnroll4_put_CAStoreFlags(This,dwFlags) (This)->lpVtbl->put_CAStoreFlags(This,dwFlags)
#define IEnroll4_get_RootStoreNameWStr(This,szwName) (This)->lpVtbl->get_RootStoreNameWStr(This,szwName)
#define IEnroll4_put_RootStoreNameWStr(This,szwName) (This)->lpVtbl->put_RootStoreNameWStr(This,szwName)
#define IEnroll4_get_RootStoreTypeWStr(This,szwType) (This)->lpVtbl->get_RootStoreTypeWStr(This,szwType)
#define IEnroll4_put_RootStoreTypeWStr(This,szwType) (This)->lpVtbl->put_RootStoreTypeWStr(This,szwType)
#define IEnroll4_get_RootStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RootStoreFlags(This,pdwFlags)
#define IEnroll4_put_RootStoreFlags(This,dwFlags) (This)->lpVtbl->put_RootStoreFlags(This,dwFlags)
#define IEnroll4_get_RequestStoreNameWStr(This,szwName) (This)->lpVtbl->get_RequestStoreNameWStr(This,szwName)
#define IEnroll4_put_RequestStoreNameWStr(This,szwName) (This)->lpVtbl->put_RequestStoreNameWStr(This,szwName)
#define IEnroll4_get_RequestStoreTypeWStr(This,szwType) (This)->lpVtbl->get_RequestStoreTypeWStr(This,szwType)
#define IEnroll4_put_RequestStoreTypeWStr(This,szwType) (This)->lpVtbl->put_RequestStoreTypeWStr(This,szwType)
#define IEnroll4_get_RequestStoreFlags(This,pdwFlags) (This)->lpVtbl->get_RequestStoreFlags(This,pdwFlags)
#define IEnroll4_put_RequestStoreFlags(This,dwFlags) (This)->lpVtbl->put_RequestStoreFlags(This,dwFlags)
#define IEnroll4_get_ContainerNameWStr(This,szwContainer) (This)->lpVtbl->get_ContainerNameWStr(This,szwContainer)
#define IEnroll4_put_ContainerNameWStr(This,szwContainer) (This)->lpVtbl->put_ContainerNameWStr(This,szwContainer)
#define IEnroll4_get_ProviderNameWStr(This,szwProvider) (This)->lpVtbl->get_ProviderNameWStr(This,szwProvider)
#define IEnroll4_put_ProviderNameWStr(This,szwProvider) (This)->lpVtbl->put_ProviderNameWStr(This,szwProvider)
#define IEnroll4_get_ProviderType(This,pdwType) (This)->lpVtbl->get_ProviderType(This,pdwType)
#define IEnroll4_put_ProviderType(This,dwType) (This)->lpVtbl->put_ProviderType(This,dwType)
#define IEnroll4_get_KeySpec(This,pdw) (This)->lpVtbl->get_KeySpec(This,pdw)
#define IEnroll4_put_KeySpec(This,dw) (This)->lpVtbl->put_KeySpec(This,dw)
#define IEnroll4_get_ProviderFlags(This,pdwFlags) (This)->lpVtbl->get_ProviderFlags(This,pdwFlags)
#define IEnroll4_put_ProviderFlags(This,dwFlags) (This)->lpVtbl->put_ProviderFlags(This,dwFlags)
#define IEnroll4_get_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->get_UseExistingKeySet(This,fUseExistingKeys)
#define IEnroll4_put_UseExistingKeySet(This,fUseExistingKeys) (This)->lpVtbl->put_UseExistingKeySet(This,fUseExistingKeys)
#define IEnroll4_get_GenKeyFlags(This,pdwFlags) (This)->lpVtbl->get_GenKeyFlags(This,pdwFlags)
#define IEnroll4_put_GenKeyFlags(This,dwFlags) (This)->lpVtbl->put_GenKeyFlags(This,dwFlags)
#define IEnroll4_get_DeleteRequestCert(This,fDelete) (This)->lpVtbl->get_DeleteRequestCert(This,fDelete)
#define IEnroll4_put_DeleteRequestCert(This,fDelete) (This)->lpVtbl->put_DeleteRequestCert(This,fDelete)
#define IEnroll4_get_WriteCertToUserDS(This,fBool) (This)->lpVtbl->get_WriteCertToUserDS(This,fBool)
#define IEnroll4_put_WriteCertToUserDS(This,fBool) (This)->lpVtbl->put_WriteCertToUserDS(This,fBool)
#define IEnroll4_get_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->get_EnableT61DNEncoding(This,fBool)
#define IEnroll4_put_EnableT61DNEncoding(This,fBool) (This)->lpVtbl->put_EnableT61DNEncoding(This,fBool)
#define IEnroll4_get_WriteCertToCSP(This,fBool) (This)->lpVtbl->get_WriteCertToCSP(This,fBool)
#define IEnroll4_put_WriteCertToCSP(This,fBool) (This)->lpVtbl->put_WriteCertToCSP(This,fBool)
#define IEnroll4_get_SPCFileNameWStr(This,szw) (This)->lpVtbl->get_SPCFileNameWStr(This,szw)
#define IEnroll4_put_SPCFileNameWStr(This,szw) (This)->lpVtbl->put_SPCFileNameWStr(This,szw)
#define IEnroll4_get_PVKFileNameWStr(This,szw) (This)->lpVtbl->get_PVKFileNameWStr(This,szw)
#define IEnroll4_put_PVKFileNameWStr(This,szw) (This)->lpVtbl->put_PVKFileNameWStr(This,szw)
#define IEnroll4_get_HashAlgorithmWStr(This,szw) (This)->lpVtbl->get_HashAlgorithmWStr(This,szw)
#define IEnroll4_put_HashAlgorithmWStr(This,szw) (This)->lpVtbl->put_HashAlgorithmWStr(This,szw)
#define IEnroll4_get_RenewalCertificate(This,ppCertContext) (This)->lpVtbl->get_RenewalCertificate(This,ppCertContext)
#define IEnroll4_put_RenewalCertificate(This,pCertContext) (This)->lpVtbl->put_RenewalCertificate(This,pCertContext)
#define IEnroll4_AddCertTypeToRequestWStr(This,szw) (This)->lpVtbl->AddCertTypeToRequestWStr(This,szw)
#define IEnroll4_AddNameValuePairToSignatureWStr(This,Name,Value) (This)->lpVtbl->AddNameValuePairToSignatureWStr(This,Name,Value)
#define IEnroll4_AddExtensionsToRequest(This,pCertExtensions) (This)->lpVtbl->AddExtensionsToRequest(This,pCertExtensions)
#define IEnroll4_AddAuthenticatedAttributesToPKCS7Request(This,pAttributes) (This)->lpVtbl->AddAuthenticatedAttributesToPKCS7Request(This,pAttributes)
#define IEnroll4_CreatePKCS7RequestFromRequest(This,pRequest,pSigningCertContext,pPkcs7Blob) (This)->lpVtbl->CreatePKCS7RequestFromRequest(This,pRequest,pSigningCertContext,pPkcs7Blob)
#define IEnroll4_InstallPKCS7Blob(This,pBlobPKCS7) (This)->lpVtbl->InstallPKCS7Blob(This,pBlobPKCS7)
#define IEnroll4_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnroll4_GetSupportedKeySpec(This,pdwKeySpec) (This)->lpVtbl->GetSupportedKeySpec(This,pdwKeySpec)
#define IEnroll4_GetKeyLen(This,fMin,fExchange,pdwKeySize) (This)->lpVtbl->GetKeyLen(This,fMin,fExchange,pdwKeySize)
#define IEnroll4_EnumAlgs(This,dwIndex,algClass,pdwAlgID) (This)->lpVtbl->EnumAlgs(This,dwIndex,algClass,pdwAlgID)
#define IEnroll4_GetAlgNameWStr(This,algID,ppwsz) (This)->lpVtbl->GetAlgNameWStr(This,algID,ppwsz)
#define IEnroll4_put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->put_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define IEnroll4_get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew) (This)->lpVtbl->get_ReuseHardwareKeyIfUnableToGenNew(This,fReuseHardwareKeyIfUnableToGenNew)
#define IEnroll4_put_HashAlgID(This,hashAlgID) (This)->lpVtbl->put_HashAlgID(This,hashAlgID)
#define IEnroll4_get_HashAlgID(This,hashAlgID) (This)->lpVtbl->get_HashAlgID(This,hashAlgID)
#define IEnroll4_SetHStoreMy(This,hStore) (This)->lpVtbl->SetHStoreMy(This,hStore)
#define IEnroll4_SetHStoreCA(This,hStore) (This)->lpVtbl->SetHStoreCA(This,hStore)
#define IEnroll4_SetHStoreROOT(This,hStore) (This)->lpVtbl->SetHStoreROOT(This,hStore)
#define IEnroll4_SetHStoreRequest(This,hStore) (This)->lpVtbl->SetHStoreRequest(This,hStore)
#define IEnroll4_put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->put_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define IEnroll4_get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment) (This)->lpVtbl->get_LimitExchangeKeyToEncipherment(This,fLimitExchangeKeyToEncipherment)
#define IEnroll4_put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->put_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#define IEnroll4_get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities) (This)->lpVtbl->get_EnableSMIMECapabilities(This,fEnableSMIMECapabilities)
#define IEnroll4_put_ThumbPrintWStr(This,thumbPrintBlob) (This)->lpVtbl->put_ThumbPrintWStr(This,thumbPrintBlob)
#define IEnroll4_get_ThumbPrintWStr(This,thumbPrintBlob) (This)->lpVtbl->get_ThumbPrintWStr(This,thumbPrintBlob)
#define IEnroll4_SetPrivateKeyArchiveCertificate(This,pPrivateKeyArchiveCert) (This)->lpVtbl->SetPrivateKeyArchiveCertificate(This,pPrivateKeyArchiveCert)
#define IEnroll4_GetPrivateKeyArchiveCertificate(This) (This)->lpVtbl->GetPrivateKeyArchiveCertificate(This)
#define IEnroll4_binaryBlobToString(This,Flags,pblobBinary,ppwszString) (This)->lpVtbl->binaryBlobToString(This,Flags,pblobBinary,ppwszString)
#define IEnroll4_stringToBinaryBlob(This,Flags,pwszString,pblobBinary,pdwSkip,pdwFlags) (This)->lpVtbl->stringToBinaryBlob(This,Flags,pwszString,pblobBinary,pdwSkip,pdwFlags)
#define IEnroll4_addExtensionToRequestWStr(This,Flags,pwszName,pblobValue) (This)->lpVtbl->addExtensionToRequestWStr(This,Flags,pwszName,pblobValue)
#define IEnroll4_addAttributeToRequestWStr(This,Flags,pwszName,pblobValue) (This)->lpVtbl->addAttributeToRequestWStr(This,Flags,pwszName,pblobValue)
#define IEnroll4_addNameValuePairToRequestWStr(This,Flags,pwszName,pwszValue) (This)->lpVtbl->addNameValuePairToRequestWStr(This,Flags,pwszName,pwszValue)
#define IEnroll4_resetExtensions(This) (This)->lpVtbl->resetExtensions(This)
#define IEnroll4_resetAttributes(This) (This)->lpVtbl->resetAttributes(This)
#define IEnroll4_createRequestWStr(This,Flags,pwszDNName,pwszUsage,pblobRequest) (This)->lpVtbl->createRequestWStr(This,Flags,pwszDNName,pwszUsage,pblobRequest)
#define IEnroll4_createFileRequestWStr(This,Flags,pwszDNName,pwszUsage,pwszRequestFileName) (This)->lpVtbl->createFileRequestWStr(This,Flags,pwszDNName,pwszUsage,pwszRequestFileName)
#define IEnroll4_acceptResponseBlob(This,pblobResponse) (This)->lpVtbl->acceptResponseBlob(This,pblobResponse)
#define IEnroll4_acceptFileResponseWStr(This,pwszResponseFileName) (This)->lpVtbl->acceptFileResponseWStr(This,pwszResponseFileName)
#define IEnroll4_getCertContextFromResponseBlob(This,pblobResponse,ppCertContext) (This)->lpVtbl->getCertContextFromResponseBlob(This,pblobResponse,ppCertContext)
#define IEnroll4_getCertContextFromFileResponseWStr(This,pwszResponseFileName,ppCertContext) (This)->lpVtbl->getCertContextFromFileResponseWStr(This,pwszResponseFileName,ppCertContext)
#define IEnroll4_createPFXWStr(This,pwszPassword,pblobPFX) (This)->lpVtbl->createPFXWStr(This,pwszPassword,pblobPFX)
#define IEnroll4_createFilePFXWStr(This,pwszPassword,pwszPFXFileName) (This)->lpVtbl->createFilePFXWStr(This,pwszPassword,pwszPFXFileName)
#define IEnroll4_setPendingRequestInfoWStr(This,lRequestID,pwszCADNS,pwszCAName,pwszFriendlyName) (This)->lpVtbl->setPendingRequestInfoWStr(This,lRequestID,pwszCADNS,pwszCAName,pwszFriendlyName)
#define IEnroll4_enumPendingRequestWStr(This,lIndex,lDesiredProperty,ppProperty) (This)->lpVtbl->enumPendingRequestWStr(This,lIndex,lDesiredProperty,ppProperty)
#define IEnroll4_removePendingRequestWStr(This,thumbPrintBlob) (This)->lpVtbl->removePendingRequestWStr(This,thumbPrintBlob)
#define IEnroll4_GetKeyLenEx(This,lSizeSpec,lKeySpec,pdwKeySize) (This)->lpVtbl->GetKeyLenEx(This,lSizeSpec,lKeySpec,pdwKeySize)
#define IEnroll4_InstallPKCS7BlobEx(This,pBlobPKCS7,plCertInstalled) (This)->lpVtbl->InstallPKCS7BlobEx(This,pBlobPKCS7,plCertInstalled)
#define IEnroll4_AddCertTypeToRequestWStrEx(This,lType,pwszOIDOrName,lMajorVersion,fMinorVersion,lMinorVersion) (This)->lpVtbl->AddCertTypeToRequestWStrEx(This,lType,pwszOIDOrName,lMajorVersion,fMinorVersion,lMinorVersion)
#define IEnroll4_getProviderTypeWStr(This,pwszProvName,plProvType) (This)->lpVtbl->getProviderTypeWStr(This,pwszProvName,plProvType)
#define IEnroll4_addBlobPropertyToCertificateWStr(This,lPropertyId,lReserved,pBlobProperty) (This)->lpVtbl->addBlobPropertyToCertificateWStr(This,lPropertyId,lReserved,pBlobProperty)
#define IEnroll4_SetSignerCertificate(This,pSignerCert) (This)->lpVtbl->SetSignerCertificate(This,pSignerCert)
#define IEnroll4_put_ClientId(This,lClientId) (This)->lpVtbl->put_ClientId(This,lClientId)
#define IEnroll4_get_ClientId(This,plClientId) (This)->lpVtbl->get_ClientId(This,plClientId)
#define IEnroll4_put_IncludeSubjectKeyID(This,fInclude) (This)->lpVtbl->put_IncludeSubjectKeyID(This,fInclude)
#define IEnroll4_get_IncludeSubjectKeyID(This,pfInclude) (This)->lpVtbl->get_IncludeSubjectKeyID(This,pfInclude)
#endif
#endif
  HRESULT WINAPI IEnroll4_put_ThumbPrintWStr_Proxy(IEnroll4 *This,CRYPT_DATA_BLOB thumbPrintBlob);
  void __RPC_STUB IEnroll4_put_ThumbPrintWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_get_ThumbPrintWStr_Proxy(IEnroll4 *This,PCRYPT_DATA_BLOB thumbPrintBlob);
  void __RPC_STUB IEnroll4_get_ThumbPrintWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_SetPrivateKeyArchiveCertificate_Proxy(IEnroll4 *This,PCCERT_CONTEXT pPrivateKeyArchiveCert);
  void __RPC_STUB IEnroll4_SetPrivateKeyArchiveCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  PCCERT_CONTEXT WINAPI IEnroll4_GetPrivateKeyArchiveCertificate_Proxy(IEnroll4 *This);
  void __RPC_STUB IEnroll4_GetPrivateKeyArchiveCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_binaryBlobToString_Proxy(IEnroll4 *This,LONG Flags,PCRYPT_DATA_BLOB pblobBinary,LPWSTR *ppwszString);
  void __RPC_STUB IEnroll4_binaryBlobToString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_stringToBinaryBlob_Proxy(IEnroll4 *This,LONG Flags,LPCWSTR pwszString,PCRYPT_DATA_BLOB pblobBinary,LONG *pdwSkip,LONG *pdwFlags);
  void __RPC_STUB IEnroll4_stringToBinaryBlob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_addExtensionToRequestWStr_Proxy(IEnroll4 *This,LONG Flags,LPCWSTR pwszName,PCRYPT_DATA_BLOB pblobValue);
  void __RPC_STUB IEnroll4_addExtensionToRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_addAttributeToRequestWStr_Proxy(IEnroll4 *This,LONG Flags,LPCWSTR pwszName,PCRYPT_DATA_BLOB pblobValue);
  void __RPC_STUB IEnroll4_addAttributeToRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_addNameValuePairToRequestWStr_Proxy(IEnroll4 *This,LONG Flags,LPCWSTR pwszName,LPCWSTR pwszValue);
  void __RPC_STUB IEnroll4_addNameValuePairToRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_resetExtensions_Proxy(IEnroll4 *This);
  void __RPC_STUB IEnroll4_resetExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_resetAttributes_Proxy(IEnroll4 *This);
  void __RPC_STUB IEnroll4_resetAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_createRequestWStr_Proxy(IEnroll4 *This,LONG Flags,LPCWSTR pwszDNName,LPCWSTR pwszUsage,PCRYPT_DATA_BLOB pblobRequest);
  void __RPC_STUB IEnroll4_createRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_createFileRequestWStr_Proxy(IEnroll4 *This,LONG Flags,LPCWSTR pwszDNName,LPCWSTR pwszUsage,LPCWSTR pwszRequestFileName);
  void __RPC_STUB IEnroll4_createFileRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_acceptResponseBlob_Proxy(IEnroll4 *This,PCRYPT_DATA_BLOB pblobResponse);
  void __RPC_STUB IEnroll4_acceptResponseBlob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_acceptFileResponseWStr_Proxy(IEnroll4 *This,LPCWSTR pwszResponseFileName);
  void __RPC_STUB IEnroll4_acceptFileResponseWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_getCertContextFromResponseBlob_Proxy(IEnroll4 *This,PCRYPT_DATA_BLOB pblobResponse,PCCERT_CONTEXT *ppCertContext);
  void __RPC_STUB IEnroll4_getCertContextFromResponseBlob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_getCertContextFromFileResponseWStr_Proxy(IEnroll4 *This,LPCWSTR pwszResponseFileName,PCCERT_CONTEXT *ppCertContext);
  void __RPC_STUB IEnroll4_getCertContextFromFileResponseWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_createPFXWStr_Proxy(IEnroll4 *This,LPCWSTR pwszPassword,PCRYPT_DATA_BLOB pblobPFX);
  void __RPC_STUB IEnroll4_createPFXWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_createFilePFXWStr_Proxy(IEnroll4 *This,LPCWSTR pwszPassword,LPCWSTR pwszPFXFileName);
  void __RPC_STUB IEnroll4_createFilePFXWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_setPendingRequestInfoWStr_Proxy(IEnroll4 *This,LONG lRequestID,LPCWSTR pwszCADNS,LPCWSTR pwszCAName,LPCWSTR pwszFriendlyName);
  void __RPC_STUB IEnroll4_setPendingRequestInfoWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_enumPendingRequestWStr_Proxy(IEnroll4 *This,LONG lIndex,LONG lDesiredProperty,LPVOID ppProperty);
  void __RPC_STUB IEnroll4_enumPendingRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_removePendingRequestWStr_Proxy(IEnroll4 *This,CRYPT_DATA_BLOB thumbPrintBlob);
  void __RPC_STUB IEnroll4_removePendingRequestWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_GetKeyLenEx_Proxy(IEnroll4 *This,LONG lSizeSpec,LONG lKeySpec,LONG *pdwKeySize);
  void __RPC_STUB IEnroll4_GetKeyLenEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_InstallPKCS7BlobEx_Proxy(IEnroll4 *This,PCRYPT_DATA_BLOB pBlobPKCS7,LONG *plCertInstalled);
  void __RPC_STUB IEnroll4_InstallPKCS7BlobEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_AddCertTypeToRequestWStrEx_Proxy(IEnroll4 *This,LONG lType,LPCWSTR pwszOIDOrName,LONG lMajorVersion,WINBOOL fMinorVersion,LONG lMinorVersion);
  void __RPC_STUB IEnroll4_AddCertTypeToRequestWStrEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_getProviderTypeWStr_Proxy(IEnroll4 *This,LPCWSTR pwszProvName,LONG *plProvType);
  void __RPC_STUB IEnroll4_getProviderTypeWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_addBlobPropertyToCertificateWStr_Proxy(IEnroll4 *This,LONG lPropertyId,LONG lReserved,PCRYPT_DATA_BLOB pBlobProperty);
  void __RPC_STUB IEnroll4_addBlobPropertyToCertificateWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_SetSignerCertificate_Proxy(IEnroll4 *This,PCCERT_CONTEXT pSignerCert);
  void __RPC_STUB IEnroll4_SetSignerCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_put_ClientId_Proxy(IEnroll4 *This,LONG lClientId);
  void __RPC_STUB IEnroll4_put_ClientId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_get_ClientId_Proxy(IEnroll4 *This,LONG *plClientId);
  void __RPC_STUB IEnroll4_get_ClientId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_put_IncludeSubjectKeyID_Proxy(IEnroll4 *This,WINBOOL fInclude);
  void __RPC_STUB IEnroll4_put_IncludeSubjectKeyID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnroll4_get_IncludeSubjectKeyID_Proxy(IEnroll4 *This,WINBOOL *pfInclude);
  void __RPC_STUB IEnroll4_get_IncludeSubjectKeyID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __XENROLLLib_LIBRARY_DEFINED__
#define __XENROLLLib_LIBRARY_DEFINED__
  extern const IID LIBID_XENROLLLib;
  extern const CLSID CLSID_CEnroll2;
  extern const CLSID CLSID_CEnroll;
#ifdef __cplusplus
}
  class CEnroll2;
  class CEnroll;
  extern "C" {
#endif
#endif

  IEnroll *WINAPI PIEnrollGetNoCOM(void);
  IEnroll2 *WINAPI PIEnroll2GetNoCOM(void);
  IEnroll4 *WINAPI PIEnroll4GetNoCOM(void);

#define CRYPT_ENUM_ALL_PROVIDERS 0x1
#define XEPR_ENUM_FIRST -1
#define XEPR_CADNS 0x01
#define XEPR_CANAME 0x02
#define XEPR_CAFRIENDLYNAME 0x03
#define XEPR_REQUESTID 0x04
#define XEPR_DATE 0x05
#define XEPR_TEMPLATENAME 0x06
#define XEPR_VERSION 0x07
#define XEPR_HASH 0x08
#define XEPR_V1TEMPLATENAME 0x09
#define XEPR_V2TEMPLATEOID 0x10
#define XECR_PKCS10_V2_0 0x1
#define XECR_PKCS7 0x2
#define XECR_CMC 0x3
#define XECR_PKCS10_V1_5 0x4
#define XEKL_KEYSIZE_MIN 0x1
#define XEKL_KEYSIZE_MAX 0x2
#define XEKL_KEYSIZE_INC 0x3
#define XEKL_KEYSIZE_DEFAULT 0x4
#define XEKL_KEYSPEC_KEYX 0x1
#define XEKL_KEYSPEC_SIG 0x2
#define XECT_EXTENSION_V1 0x1
#define XECT_EXTENSION_V2 0x2
#define XECP_STRING_PROPERTY 0x1
#define XECI_DISABLE 0x0
#define XECI_XENROLL 0x1
#define XECI_AUTOENROLL 0x2
#define XECI_REQWIZARD 0x3
#define XECI_CERTREQ 0x4

  extern RPC_IF_HANDLE __MIDL_itf_xenroll_0269_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_xenroll_0269_v0_0_s_ifspec;

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
