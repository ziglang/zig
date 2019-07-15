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

#ifndef __xmltrnsf_h__
#define __xmltrnsf_h__

#ifndef __IWmiXMLTransformer_FWD_DEFINED__
#define __IWmiXMLTransformer_FWD_DEFINED__
typedef struct IWmiXMLTransformer IWmiXMLTransformer;
#endif

#ifndef __WmiXMLTransformer_FWD_DEFINED__
#define __WmiXMLTransformer_FWD_DEFINED__
#ifdef __cplusplus
typedef class WmiXMLTransformer WmiXMLTransformer;
#else
typedef struct WmiXMLTransformer WmiXMLTransformer;
#endif
#endif

#ifndef __ISWbemXMLDocumentSet_FWD_DEFINED__
#define __ISWbemXMLDocumentSet_FWD_DEFINED__
typedef struct ISWbemXMLDocumentSet ISWbemXMLDocumentSet;
#endif

#ifndef __IWmiXMLTransformer_FWD_DEFINED__
#define __IWmiXMLTransformer_FWD_DEFINED__
typedef struct IWmiXMLTransformer IWmiXMLTransformer;
#endif

#include "msxml.h"
#include "wbemdisp.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define__MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __WmiXMLTransformer_LIBRARY_DEFINED__
#define __WmiXMLTransformer_LIBRARY_DEFINED__

  typedef enum WmiXMLEncoding {
    wmiXML_CIM_DTD_2_0 = 0,wmiXML_WMI_DTD_2_0 = 0x1,wmiXML_WMI_DTD_WHISTLER = 0x2
  } WmiXMLEncoding;

  typedef enum WmiXMLCompilationTypeEnum {
    WmiXMLCompilationWellFormCheck = 0,WmiXMLCompilationValidityCheck = 0x1,WmiXMLCompilationFullCompileAndLoad = 0x2
  } WmiXMLCompilationTypeEnum;

  EXTERN_C const IID LIBID_WmiXMLTransformer;
#ifndef __IWmiXMLTransformer_INTERFACE_DEFINED__
#define __IWmiXMLTransformer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWmiXMLTransformer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWmiXMLTransformer : public IDispatch {
  public:
    virtual HRESULT WINAPI get_XMLEncodingType(WmiXMLEncoding *piEncoding) = 0;
    virtual HRESULT WINAPI put_XMLEncodingType(WmiXMLEncoding iEncoding) = 0;
    virtual HRESULT WINAPI get_QualifierFilter(VARIANT_BOOL *bQualifierFilter) = 0;
    virtual HRESULT WINAPI put_QualifierFilter(VARIANT_BOOL bQualifierFilter) = 0;
    virtual HRESULT WINAPI get_ClassOriginFilter(VARIANT_BOOL *bClassOriginFilter) = 0;
    virtual HRESULT WINAPI put_ClassOriginFilter(VARIANT_BOOL bClassOriginFilter) = 0;
    virtual HRESULT WINAPI get_User(BSTR *strUser) = 0;
    virtual HRESULT WINAPI put_User(BSTR strUser) = 0;
    virtual HRESULT WINAPI get_Password(BSTR *strPassword) = 0;
    virtual HRESULT WINAPI put_Password(BSTR strPassword) = 0;
    virtual HRESULT WINAPI get_Authority(BSTR *strAuthority) = 0;
    virtual HRESULT WINAPI put_Authority(BSTR strAuthority) = 0;
    virtual HRESULT WINAPI get_ImpersonationLevel(DWORD *pdwImpersonationLevel) = 0;
    virtual HRESULT WINAPI put_ImpersonationLevel(DWORD dwImpersonationLevel) = 0;
    virtual HRESULT WINAPI get_AuthenticationLevel(DWORD *pdwAuthenticationLevel) = 0;
    virtual HRESULT WINAPI put_AuthenticationLevel(DWORD dwAuthenticationLevel) = 0;
    virtual HRESULT WINAPI get_Locale(BSTR *strLocale) = 0;
    virtual HRESULT WINAPI put_Locale(BSTR strLocale) = 0;
    virtual HRESULT WINAPI get_LocalOnly(VARIANT_BOOL *bLocalOnly) = 0;
    virtual HRESULT WINAPI put_LocalOnly(VARIANT_BOOL bLocalOnly) = 0;
    virtual HRESULT WINAPI GetObject(BSTR strObjectPath,IDispatch *pCtx,IXMLDOMDocument **ppXMLDocument) = 0;
    virtual HRESULT WINAPI ExecQuery(BSTR strNamespacePath,BSTR strQuery,BSTR strQueryLanguage,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet) = 0;
    virtual HRESULT WINAPI EnumClasses(BSTR strSuperClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet) = 0;
    virtual HRESULT WINAPI EnumInstances(BSTR strClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet) = 0;
    virtual HRESULT WINAPI EnumClassNames(BSTR strSuperClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet) = 0;
    virtual HRESULT WINAPI EnumInstanceNames(BSTR strClassPath,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet) = 0;
    virtual HRESULT WINAPI Compile(VARIANT *pvInputSource,BSTR strNamespacePath,LONG lClassFlags,LONG lInstanceFlags,WmiXMLCompilationTypeEnum iOperation,IDispatch *pCtx,VARIANT_BOOL *pStatus) = 0;
    virtual HRESULT WINAPI get_Privileges(ISWbemPrivilegeSet **objWbemPrivilegeSet) = 0;
    virtual HRESULT WINAPI get_CompilationErrors(BSTR *pstrErrors) = 0;
  };
#else
  typedef struct IWmiXMLTransformerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWmiXMLTransformer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWmiXMLTransformer *This);
      ULONG (WINAPI *Release)(IWmiXMLTransformer *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IWmiXMLTransformer *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IWmiXMLTransformer *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IWmiXMLTransformer *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IWmiXMLTransformer *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_XMLEncodingType)(IWmiXMLTransformer *This,WmiXMLEncoding *piEncoding);
      HRESULT (WINAPI *put_XMLEncodingType)(IWmiXMLTransformer *This,WmiXMLEncoding iEncoding);
      HRESULT (WINAPI *get_QualifierFilter)(IWmiXMLTransformer *This,VARIANT_BOOL *bQualifierFilter);
      HRESULT (WINAPI *put_QualifierFilter)(IWmiXMLTransformer *This,VARIANT_BOOL bQualifierFilter);
      HRESULT (WINAPI *get_ClassOriginFilter)(IWmiXMLTransformer *This,VARIANT_BOOL *bClassOriginFilter);
      HRESULT (WINAPI *put_ClassOriginFilter)(IWmiXMLTransformer *This,VARIANT_BOOL bClassOriginFilter);
      HRESULT (WINAPI *get_User)(IWmiXMLTransformer *This,BSTR *strUser);
      HRESULT (WINAPI *put_User)(IWmiXMLTransformer *This,BSTR strUser);
      HRESULT (WINAPI *get_Password)(IWmiXMLTransformer *This,BSTR *strPassword);
      HRESULT (WINAPI *put_Password)(IWmiXMLTransformer *This,BSTR strPassword);
      HRESULT (WINAPI *get_Authority)(IWmiXMLTransformer *This,BSTR *strAuthority);
      HRESULT (WINAPI *put_Authority)(IWmiXMLTransformer *This,BSTR strAuthority);
      HRESULT (WINAPI *get_ImpersonationLevel)(IWmiXMLTransformer *This,DWORD *pdwImpersonationLevel);
      HRESULT (WINAPI *put_ImpersonationLevel)(IWmiXMLTransformer *This,DWORD dwImpersonationLevel);
      HRESULT (WINAPI *get_AuthenticationLevel)(IWmiXMLTransformer *This,DWORD *pdwAuthenticationLevel);
      HRESULT (WINAPI *put_AuthenticationLevel)(IWmiXMLTransformer *This,DWORD dwAuthenticationLevel);
      HRESULT (WINAPI *get_Locale)(IWmiXMLTransformer *This,BSTR *strLocale);
      HRESULT (WINAPI *put_Locale)(IWmiXMLTransformer *This,BSTR strLocale);
      HRESULT (WINAPI *get_LocalOnly)(IWmiXMLTransformer *This,VARIANT_BOOL *bLocalOnly);
      HRESULT (WINAPI *put_LocalOnly)(IWmiXMLTransformer *This,VARIANT_BOOL bLocalOnly);
      HRESULT (WINAPI *GetObject)(IWmiXMLTransformer *This,BSTR strObjectPath,IDispatch *pCtx,IXMLDOMDocument **ppXMLDocument);
      HRESULT (WINAPI *ExecQuery)(IWmiXMLTransformer *This,BSTR strNamespacePath,BSTR strQuery,BSTR strQueryLanguage,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
      HRESULT (WINAPI *EnumClasses)(IWmiXMLTransformer *This,BSTR strSuperClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
      HRESULT (WINAPI *EnumInstances)(IWmiXMLTransformer *This,BSTR strClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
      HRESULT (WINAPI *EnumClassNames)(IWmiXMLTransformer *This,BSTR strSuperClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
      HRESULT (WINAPI *EnumInstanceNames)(IWmiXMLTransformer *This,BSTR strClassPath,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
      HRESULT (WINAPI *Compile)(IWmiXMLTransformer *This,VARIANT *pvInputSource,BSTR strNamespacePath,LONG lClassFlags,LONG lInstanceFlags,WmiXMLCompilationTypeEnum iOperation,IDispatch *pCtx,VARIANT_BOOL *pStatus);
      HRESULT (WINAPI *get_Privileges)(IWmiXMLTransformer *This,ISWbemPrivilegeSet **objWbemPrivilegeSet);
      HRESULT (WINAPI *get_CompilationErrors)(IWmiXMLTransformer *This,BSTR *pstrErrors);
    END_INTERFACE
  } IWmiXMLTransformerVtbl;
  struct IWmiXMLTransformer {
    CONST_VTBL struct IWmiXMLTransformerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWmiXMLTransformer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWmiXMLTransformer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWmiXMLTransformer_Release(This) (This)->lpVtbl->Release(This)
#define IWmiXMLTransformer_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IWmiXMLTransformer_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IWmiXMLTransformer_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IWmiXMLTransformer_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IWmiXMLTransformer_get_XMLEncodingType(This,piEncoding) (This)->lpVtbl->get_XMLEncodingType(This,piEncoding)
#define IWmiXMLTransformer_put_XMLEncodingType(This,iEncoding) (This)->lpVtbl->put_XMLEncodingType(This,iEncoding)
#define IWmiXMLTransformer_get_QualifierFilter(This,bQualifierFilter) (This)->lpVtbl->get_QualifierFilter(This,bQualifierFilter)
#define IWmiXMLTransformer_put_QualifierFilter(This,bQualifierFilter) (This)->lpVtbl->put_QualifierFilter(This,bQualifierFilter)
#define IWmiXMLTransformer_get_ClassOriginFilter(This,bClassOriginFilter) (This)->lpVtbl->get_ClassOriginFilter(This,bClassOriginFilter)
#define IWmiXMLTransformer_put_ClassOriginFilter(This,bClassOriginFilter) (This)->lpVtbl->put_ClassOriginFilter(This,bClassOriginFilter)
#define IWmiXMLTransformer_get_User(This,strUser) (This)->lpVtbl->get_User(This,strUser)
#define IWmiXMLTransformer_put_User(This,strUser) (This)->lpVtbl->put_User(This,strUser)
#define IWmiXMLTransformer_get_Password(This,strPassword) (This)->lpVtbl->get_Password(This,strPassword)
#define IWmiXMLTransformer_put_Password(This,strPassword) (This)->lpVtbl->put_Password(This,strPassword)
#define IWmiXMLTransformer_get_Authority(This,strAuthority) (This)->lpVtbl->get_Authority(This,strAuthority)
#define IWmiXMLTransformer_put_Authority(This,strAuthority) (This)->lpVtbl->put_Authority(This,strAuthority)
#define IWmiXMLTransformer_get_ImpersonationLevel(This,pdwImpersonationLevel) (This)->lpVtbl->get_ImpersonationLevel(This,pdwImpersonationLevel)
#define IWmiXMLTransformer_put_ImpersonationLevel(This,dwImpersonationLevel) (This)->lpVtbl->put_ImpersonationLevel(This,dwImpersonationLevel)
#define IWmiXMLTransformer_get_AuthenticationLevel(This,pdwAuthenticationLevel) (This)->lpVtbl->get_AuthenticationLevel(This,pdwAuthenticationLevel)
#define IWmiXMLTransformer_put_AuthenticationLevel(This,dwAuthenticationLevel) (This)->lpVtbl->put_AuthenticationLevel(This,dwAuthenticationLevel)
#define IWmiXMLTransformer_get_Locale(This,strLocale) (This)->lpVtbl->get_Locale(This,strLocale)
#define IWmiXMLTransformer_put_Locale(This,strLocale) (This)->lpVtbl->put_Locale(This,strLocale)
#define IWmiXMLTransformer_get_LocalOnly(This,bLocalOnly) (This)->lpVtbl->get_LocalOnly(This,bLocalOnly)
#define IWmiXMLTransformer_put_LocalOnly(This,bLocalOnly) (This)->lpVtbl->put_LocalOnly(This,bLocalOnly)
#define IWmiXMLTransformer_GetObject(This,strObjectPath,pCtx,ppXMLDocument) (This)->lpVtbl->GetObject(This,strObjectPath,pCtx,ppXMLDocument)
#define IWmiXMLTransformer_ExecQuery(This,strNamespacePath,strQuery,strQueryLanguage,pCtx,ppXMLDocumentSet) (This)->lpVtbl->ExecQuery(This,strNamespacePath,strQuery,strQueryLanguage,pCtx,ppXMLDocumentSet)
#define IWmiXMLTransformer_EnumClasses(This,strSuperClassPath,bDeep,pCtx,ppXMLDocumentSet) (This)->lpVtbl->EnumClasses(This,strSuperClassPath,bDeep,pCtx,ppXMLDocumentSet)
#define IWmiXMLTransformer_EnumInstances(This,strClassPath,bDeep,pCtx,ppXMLDocumentSet) (This)->lpVtbl->EnumInstances(This,strClassPath,bDeep,pCtx,ppXMLDocumentSet)
#define IWmiXMLTransformer_EnumClassNames(This,strSuperClassPath,bDeep,pCtx,ppXMLDocumentSet) (This)->lpVtbl->EnumClassNames(This,strSuperClassPath,bDeep,pCtx,ppXMLDocumentSet)
#define IWmiXMLTransformer_EnumInstanceNames(This,strClassPath,pCtx,ppXMLDocumentSet) (This)->lpVtbl->EnumInstanceNames(This,strClassPath,pCtx,ppXMLDocumentSet)
#define IWmiXMLTransformer_Compile(This,pvInputSource,strNamespacePath,lClassFlags,lInstanceFlags,iOperation,pCtx,pStatus) (This)->lpVtbl->Compile(This,pvInputSource,strNamespacePath,lClassFlags,lInstanceFlags,iOperation,pCtx,pStatus)
#define IWmiXMLTransformer_get_Privileges(This,objWbemPrivilegeSet) (This)->lpVtbl->get_Privileges(This,objWbemPrivilegeSet)
#define IWmiXMLTransformer_get_CompilationErrors(This,pstrErrors) (This)->lpVtbl->get_CompilationErrors(This,pstrErrors)
#endif
#endif
  HRESULT WINAPI IWmiXMLTransformer_get_XMLEncodingType_Proxy(IWmiXMLTransformer *This,WmiXMLEncoding *piEncoding);
  void __RPC_STUB IWmiXMLTransformer_get_XMLEncodingType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_XMLEncodingType_Proxy(IWmiXMLTransformer *This,WmiXMLEncoding iEncoding);
  void __RPC_STUB IWmiXMLTransformer_put_XMLEncodingType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_QualifierFilter_Proxy(IWmiXMLTransformer *This,VARIANT_BOOL *bQualifierFilter);
  void __RPC_STUB IWmiXMLTransformer_get_QualifierFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_QualifierFilter_Proxy(IWmiXMLTransformer *This,VARIANT_BOOL bQualifierFilter);
  void __RPC_STUB IWmiXMLTransformer_put_QualifierFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_ClassOriginFilter_Proxy(IWmiXMLTransformer *This,VARIANT_BOOL *bClassOriginFilter);
  void __RPC_STUB IWmiXMLTransformer_get_ClassOriginFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_ClassOriginFilter_Proxy(IWmiXMLTransformer *This,VARIANT_BOOL bClassOriginFilter);
  void __RPC_STUB IWmiXMLTransformer_put_ClassOriginFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_User_Proxy(IWmiXMLTransformer *This,BSTR *strUser);
  void __RPC_STUB IWmiXMLTransformer_get_User_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_User_Proxy(IWmiXMLTransformer *This,BSTR strUser);
  void __RPC_STUB IWmiXMLTransformer_put_User_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_Password_Proxy(IWmiXMLTransformer *This,BSTR *strPassword);
  void __RPC_STUB IWmiXMLTransformer_get_Password_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_Password_Proxy(IWmiXMLTransformer *This,BSTR strPassword);
  void __RPC_STUB IWmiXMLTransformer_put_Password_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_Authority_Proxy(IWmiXMLTransformer *This,BSTR *strAuthority);
  void __RPC_STUB IWmiXMLTransformer_get_Authority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_Authority_Proxy(IWmiXMLTransformer *This,BSTR strAuthority);
  void __RPC_STUB IWmiXMLTransformer_put_Authority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_ImpersonationLevel_Proxy(IWmiXMLTransformer *This,DWORD *pdwImpersonationLevel);
  void __RPC_STUB IWmiXMLTransformer_get_ImpersonationLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_ImpersonationLevel_Proxy(IWmiXMLTransformer *This,DWORD dwImpersonationLevel);
  void __RPC_STUB IWmiXMLTransformer_put_ImpersonationLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_AuthenticationLevel_Proxy(IWmiXMLTransformer *This,DWORD *pdwAuthenticationLevel);
  void __RPC_STUB IWmiXMLTransformer_get_AuthenticationLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_AuthenticationLevel_Proxy(IWmiXMLTransformer *This,DWORD dwAuthenticationLevel);
  void __RPC_STUB IWmiXMLTransformer_put_AuthenticationLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_Locale_Proxy(IWmiXMLTransformer *This,BSTR *strLocale);
  void __RPC_STUB IWmiXMLTransformer_get_Locale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_Locale_Proxy(IWmiXMLTransformer *This,BSTR strLocale);
  void __RPC_STUB IWmiXMLTransformer_put_Locale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_LocalOnly_Proxy(IWmiXMLTransformer *This,VARIANT_BOOL *bLocalOnly);
  void __RPC_STUB IWmiXMLTransformer_get_LocalOnly_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_put_LocalOnly_Proxy(IWmiXMLTransformer *This,VARIANT_BOOL bLocalOnly);
  void __RPC_STUB IWmiXMLTransformer_put_LocalOnly_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_GetObject_Proxy(IWmiXMLTransformer *This,BSTR strObjectPath,IDispatch *pCtx,IXMLDOMDocument **ppXMLDocument);
  void __RPC_STUB IWmiXMLTransformer_GetObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_ExecQuery_Proxy(IWmiXMLTransformer *This,BSTR strNamespacePath,BSTR strQuery,BSTR strQueryLanguage,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
  void __RPC_STUB IWmiXMLTransformer_ExecQuery_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_EnumClasses_Proxy(IWmiXMLTransformer *This,BSTR strSuperClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
  void __RPC_STUB IWmiXMLTransformer_EnumClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_EnumInstances_Proxy(IWmiXMLTransformer *This,BSTR strClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
  void __RPC_STUB IWmiXMLTransformer_EnumInstances_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_EnumClassNames_Proxy(IWmiXMLTransformer *This,BSTR strSuperClassPath,VARIANT_BOOL bDeep,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
  void __RPC_STUB IWmiXMLTransformer_EnumClassNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_EnumInstanceNames_Proxy(IWmiXMLTransformer *This,BSTR strClassPath,IDispatch *pCtx,ISWbemXMLDocumentSet **ppXMLDocumentSet);
  void __RPC_STUB IWmiXMLTransformer_EnumInstanceNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_Compile_Proxy(IWmiXMLTransformer *This,VARIANT *pvInputSource,BSTR strNamespacePath,LONG lClassFlags,LONG lInstanceFlags,WmiXMLCompilationTypeEnum iOperation,IDispatch *pCtx,VARIANT_BOOL *pStatus);
  void __RPC_STUB IWmiXMLTransformer_Compile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_Privileges_Proxy(IWmiXMLTransformer *This,ISWbemPrivilegeSet **objWbemPrivilegeSet);
  void __RPC_STUB IWmiXMLTransformer_get_Privileges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWmiXMLTransformer_get_CompilationErrors_Proxy(IWmiXMLTransformer *This,BSTR *pstrErrors);
  void __RPC_STUB IWmiXMLTransformer_get_CompilationErrors_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_WmiXMLTransformer;
#ifdef __cplusplus
  class WmiXMLTransformer;
#endif
#endif

#ifndef __ISWbemXMLDocumentSet_INTERFACE_DEFINED__
#define __ISWbemXMLDocumentSet_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISWbemXMLDocumentSet;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISWbemXMLDocumentSet : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **pUnk) = 0;
    virtual HRESULT WINAPI Item(BSTR strObjectPath,__LONG32 iFlags,IXMLDOMDocument **ppXMLDocument) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *iCount) = 0;
    virtual HRESULT WINAPI NextDocument(IXMLDOMDocument **ppDoc) = 0;
    virtual HRESULT WINAPI SkipNextDocument(void) = 0;
  };
#else
  typedef struct ISWbemXMLDocumentSetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISWbemXMLDocumentSet *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISWbemXMLDocumentSet *This);
      ULONG (WINAPI *Release)(ISWbemXMLDocumentSet *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISWbemXMLDocumentSet *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISWbemXMLDocumentSet *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISWbemXMLDocumentSet *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISWbemXMLDocumentSet *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(ISWbemXMLDocumentSet *This,IUnknown **pUnk);
      HRESULT (WINAPI *Item)(ISWbemXMLDocumentSet *This,BSTR strObjectPath,__LONG32 iFlags,IXMLDOMDocument **ppXMLDocument);
      HRESULT (WINAPI *get_Count)(ISWbemXMLDocumentSet *This,__LONG32 *iCount);
      HRESULT (WINAPI *NextDocument)(ISWbemXMLDocumentSet *This,IXMLDOMDocument **ppDoc);
      HRESULT (WINAPI *SkipNextDocument)(ISWbemXMLDocumentSet *This);
    END_INTERFACE
  } ISWbemXMLDocumentSetVtbl;
  struct ISWbemXMLDocumentSet {
    CONST_VTBL struct ISWbemXMLDocumentSetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISWbemXMLDocumentSet_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISWbemXMLDocumentSet_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISWbemXMLDocumentSet_Release(This) (This)->lpVtbl->Release(This)
#define ISWbemXMLDocumentSet_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISWbemXMLDocumentSet_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISWbemXMLDocumentSet_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISWbemXMLDocumentSet_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISWbemXMLDocumentSet_get__NewEnum(This,pUnk) (This)->lpVtbl->get__NewEnum(This,pUnk)
#define ISWbemXMLDocumentSet_Item(This,strObjectPath,iFlags,ppXMLDocument) (This)->lpVtbl->Item(This,strObjectPath,iFlags,ppXMLDocument)
#define ISWbemXMLDocumentSet_get_Count(This,iCount) (This)->lpVtbl->get_Count(This,iCount)
#define ISWbemXMLDocumentSet_NextDocument(This,ppDoc) (This)->lpVtbl->NextDocument(This,ppDoc)
#define ISWbemXMLDocumentSet_SkipNextDocument(This) (This)->lpVtbl->SkipNextDocument(This)
#endif
#endif
  HRESULT WINAPI ISWbemXMLDocumentSet_get__NewEnum_Proxy(ISWbemXMLDocumentSet *This,IUnknown **pUnk);
  void __RPC_STUB ISWbemXMLDocumentSet_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISWbemXMLDocumentSet_Item_Proxy(ISWbemXMLDocumentSet *This,BSTR strObjectPath,__LONG32 iFlags,IXMLDOMDocument **ppXMLDocument);
  void __RPC_STUB ISWbemXMLDocumentSet_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISWbemXMLDocumentSet_get_Count_Proxy(ISWbemXMLDocumentSet *This,__LONG32 *iCount);
  void __RPC_STUB ISWbemXMLDocumentSet_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISWbemXMLDocumentSet_NextDocument_Proxy(ISWbemXMLDocumentSet *This,IXMLDOMDocument **ppDoc);
  void __RPC_STUB ISWbemXMLDocumentSet_NextDocument_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISWbemXMLDocumentSet_SkipNextDocument_Proxy(ISWbemXMLDocumentSet *This);
  void __RPC_STUB ISWbemXMLDocumentSet_SkipNextDocument_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
