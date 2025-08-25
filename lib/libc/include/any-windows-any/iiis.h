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

#ifndef __iiis_h__
#define __iiis_h__

#ifndef __IISMimeType_FWD_DEFINED__
#define __IISMimeType_FWD_DEFINED__
typedef struct IISMimeType IISMimeType;
#endif

#ifndef __MimeMap_FWD_DEFINED__
#define __MimeMap_FWD_DEFINED__
#ifdef __cplusplus
typedef class MimeMap MimeMap;
#else
typedef struct MimeMap MimeMap;
#endif
#endif

#ifndef __IISIPSecurity_FWD_DEFINED__
#define __IISIPSecurity_FWD_DEFINED__
typedef struct IISIPSecurity IISIPSecurity;
#endif

#ifndef __IPSecurity_FWD_DEFINED__
#define __IPSecurity_FWD_DEFINED__
#ifdef __cplusplus
typedef class IPSecurity IPSecurity;
#else
typedef struct IPSecurity IPSecurity;
#endif
#endif

#ifndef __IISNamespace_FWD_DEFINED__
#define __IISNamespace_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISNamespace IISNamespace;
#else
typedef struct IISNamespace IISNamespace;
#endif
#endif

#ifndef __IISProvider_FWD_DEFINED__
#define __IISProvider_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISProvider IISProvider;
#else
typedef struct IISProvider IISProvider;
#endif
#endif

#ifndef __IISBaseObject_FWD_DEFINED__
#define __IISBaseObject_FWD_DEFINED__
typedef struct IISBaseObject IISBaseObject;
#endif

#ifndef __IISSchemaObject_FWD_DEFINED__
#define __IISSchemaObject_FWD_DEFINED__
typedef struct IISSchemaObject IISSchemaObject;
#endif

#ifndef __IISPropertyAttribute_FWD_DEFINED__
#define __IISPropertyAttribute_FWD_DEFINED__
typedef struct IISPropertyAttribute IISPropertyAttribute;
#endif

#ifndef __PropertyAttribute_FWD_DEFINED__
#define __PropertyAttribute_FWD_DEFINED__
#ifdef __cplusplus
typedef class PropertyAttribute PropertyAttribute;
#else
typedef struct PropertyAttribute PropertyAttribute;
#endif
#endif

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  DEFINE_GUID(LIBID_IISOle,0x49D704A0,0x89F7,0x11D0,0x85,0x27,0x00,0xC0,0x4F,0xD8,0xD5,0x03);
  DEFINE_GUID(IID_IISBaseObject,0x4b42e390,0xe96,0x11d1,0x9c,0x3f,0x0,0xa0,0xc9,0x22,0xe7,0x3);

  extern RPC_IF_HANDLE __MIDL_itf_iis_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iis_0000_v0_0_s_ifspec;

#ifndef __IISOle_LIBRARY_DEFINED__
#define __IISOle_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_IISOle;
#ifndef __IISMimeType_INTERFACE_DEFINED__
#define __IISMimeType_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISMimeType;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISMimeType : public IDispatch {
  public:
    virtual HRESULT WINAPI get_MimeType(BSTR *retval) = 0;
    virtual HRESULT WINAPI put_MimeType(BSTR bstrMimeType) = 0;
    virtual HRESULT WINAPI get_Extension(BSTR *retval) = 0;
    virtual HRESULT WINAPI put_Extension(BSTR bstrExtension) = 0;
  };
#else
  typedef struct IISMimeTypeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISMimeType *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IISMimeType *This);
      ULONG (WINAPI *Release)(IISMimeType *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IISMimeType *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IISMimeType *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IISMimeType *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IISMimeType *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_MimeType)(IISMimeType *This,BSTR *retval);
      HRESULT (WINAPI *put_MimeType)(IISMimeType *This,BSTR bstrMimeType);
      HRESULT (WINAPI *get_Extension)(IISMimeType *This,BSTR *retval);
      HRESULT (WINAPI *put_Extension)(IISMimeType *This,BSTR bstrExtension);
    END_INTERFACE
  } IISMimeTypeVtbl;
  struct IISMimeType {
    CONST_VTBL struct IISMimeTypeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISMimeType_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IISMimeType_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IISMimeType_Release(This) (This)->lpVtbl->Release(This)
#define IISMimeType_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IISMimeType_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IISMimeType_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IISMimeType_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IISMimeType_get_MimeType(This,retval) (This)->lpVtbl->get_MimeType(This,retval)
#define IISMimeType_put_MimeType(This,bstrMimeType) (This)->lpVtbl->put_MimeType(This,bstrMimeType)
#define IISMimeType_get_Extension(This,retval) (This)->lpVtbl->get_Extension(This,retval)
#define IISMimeType_put_Extension(This,bstrExtension) (This)->lpVtbl->put_Extension(This,bstrExtension)
#endif
#endif
  HRESULT WINAPI IISMimeType_get_MimeType_Proxy(IISMimeType *This,BSTR *retval);
  void __RPC_STUB IISMimeType_get_MimeType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISMimeType_put_MimeType_Proxy(IISMimeType *This,BSTR bstrMimeType);
  void __RPC_STUB IISMimeType_put_MimeType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISMimeType_get_Extension_Proxy(IISMimeType *This,BSTR *retval);
  void __RPC_STUB IISMimeType_get_Extension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISMimeType_put_Extension_Proxy(IISMimeType *This,BSTR bstrExtension);
  void __RPC_STUB IISMimeType_put_Extension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_MimeMap;
#ifdef __cplusplus
  class MimeMap;
#endif

#ifndef __IISIPSecurity_INTERFACE_DEFINED__
#define __IISIPSecurity_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISIPSecurity;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISIPSecurity : public IDispatch {
  public:
    virtual HRESULT WINAPI get_IPDeny(VARIANT *retval) = 0;
    virtual HRESULT WINAPI put_IPDeny(VARIANT vIPDeny) = 0;
    virtual HRESULT WINAPI get_IPGrant(VARIANT *retval) = 0;
    virtual HRESULT WINAPI put_IPGrant(VARIANT vIPGrant) = 0;
    virtual HRESULT WINAPI get_DomainDeny(VARIANT *retval) = 0;
    virtual HRESULT WINAPI put_DomainDeny(VARIANT vDomainDeny) = 0;
    virtual HRESULT WINAPI get_DomainGrant(VARIANT *retval) = 0;
    virtual HRESULT WINAPI put_DomainGrant(VARIANT vDomainGrant) = 0;
    virtual HRESULT WINAPI get_GrantByDefault(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI put_GrantByDefault(VARIANT_BOOL fGrantByDefault) = 0;
  };
#else
  typedef struct IISIPSecurityVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISIPSecurity *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IISIPSecurity *This);
      ULONG (WINAPI *Release)(IISIPSecurity *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IISIPSecurity *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IISIPSecurity *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IISIPSecurity *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IISIPSecurity *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_IPDeny)(IISIPSecurity *This,VARIANT *retval);
      HRESULT (WINAPI *put_IPDeny)(IISIPSecurity *This,VARIANT vIPDeny);
      HRESULT (WINAPI *get_IPGrant)(IISIPSecurity *This,VARIANT *retval);
      HRESULT (WINAPI *put_IPGrant)(IISIPSecurity *This,VARIANT vIPGrant);
      HRESULT (WINAPI *get_DomainDeny)(IISIPSecurity *This,VARIANT *retval);
      HRESULT (WINAPI *put_DomainDeny)(IISIPSecurity *This,VARIANT vDomainDeny);
      HRESULT (WINAPI *get_DomainGrant)(IISIPSecurity *This,VARIANT *retval);
      HRESULT (WINAPI *put_DomainGrant)(IISIPSecurity *This,VARIANT vDomainGrant);
      HRESULT (WINAPI *get_GrantByDefault)(IISIPSecurity *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *put_GrantByDefault)(IISIPSecurity *This,VARIANT_BOOL fGrantByDefault);
    END_INTERFACE
  } IISIPSecurityVtbl;
  struct IISIPSecurity {
    CONST_VTBL struct IISIPSecurityVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISIPSecurity_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IISIPSecurity_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IISIPSecurity_Release(This) (This)->lpVtbl->Release(This)
#define IISIPSecurity_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IISIPSecurity_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IISIPSecurity_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IISIPSecurity_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IISIPSecurity_get_IPDeny(This,retval) (This)->lpVtbl->get_IPDeny(This,retval)
#define IISIPSecurity_put_IPDeny(This,vIPDeny) (This)->lpVtbl->put_IPDeny(This,vIPDeny)
#define IISIPSecurity_get_IPGrant(This,retval) (This)->lpVtbl->get_IPGrant(This,retval)
#define IISIPSecurity_put_IPGrant(This,vIPGrant) (This)->lpVtbl->put_IPGrant(This,vIPGrant)
#define IISIPSecurity_get_DomainDeny(This,retval) (This)->lpVtbl->get_DomainDeny(This,retval)
#define IISIPSecurity_put_DomainDeny(This,vDomainDeny) (This)->lpVtbl->put_DomainDeny(This,vDomainDeny)
#define IISIPSecurity_get_DomainGrant(This,retval) (This)->lpVtbl->get_DomainGrant(This,retval)
#define IISIPSecurity_put_DomainGrant(This,vDomainGrant) (This)->lpVtbl->put_DomainGrant(This,vDomainGrant)
#define IISIPSecurity_get_GrantByDefault(This,retval) (This)->lpVtbl->get_GrantByDefault(This,retval)
#define IISIPSecurity_put_GrantByDefault(This,fGrantByDefault) (This)->lpVtbl->put_GrantByDefault(This,fGrantByDefault)
#endif
#endif
  HRESULT WINAPI IISIPSecurity_get_IPDeny_Proxy(IISIPSecurity *This,VARIANT *retval);
  void __RPC_STUB IISIPSecurity_get_IPDeny_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_put_IPDeny_Proxy(IISIPSecurity *This,VARIANT vIPDeny);
  void __RPC_STUB IISIPSecurity_put_IPDeny_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_get_IPGrant_Proxy(IISIPSecurity *This,VARIANT *retval);
  void __RPC_STUB IISIPSecurity_get_IPGrant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_put_IPGrant_Proxy(IISIPSecurity *This,VARIANT vIPGrant);
  void __RPC_STUB IISIPSecurity_put_IPGrant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_get_DomainDeny_Proxy(IISIPSecurity *This,VARIANT *retval);
  void __RPC_STUB IISIPSecurity_get_DomainDeny_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_put_DomainDeny_Proxy(IISIPSecurity *This,VARIANT vDomainDeny);
  void __RPC_STUB IISIPSecurity_put_DomainDeny_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_get_DomainGrant_Proxy(IISIPSecurity *This,VARIANT *retval);
  void __RPC_STUB IISIPSecurity_get_DomainGrant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_put_DomainGrant_Proxy(IISIPSecurity *This,VARIANT vDomainGrant);
  void __RPC_STUB IISIPSecurity_put_DomainGrant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_get_GrantByDefault_Proxy(IISIPSecurity *This,VARIANT_BOOL *retval);
  void __RPC_STUB IISIPSecurity_get_GrantByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISIPSecurity_put_GrantByDefault_Proxy(IISIPSecurity *This,VARIANT_BOOL fGrantByDefault);
  void __RPC_STUB IISIPSecurity_put_GrantByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_IPSecurity;
#ifdef __cplusplus
  class IPSecurity;
#endif
  EXTERN_C const CLSID CLSID_IISNamespace;
#ifdef __cplusplus
  class IISNamespace;
#endif
  EXTERN_C const CLSID CLSID_IISProvider;
#ifdef __cplusplus
  class IISProvider;
#endif

#ifndef __IISBaseObject_INTERFACE_DEFINED__
#define __IISBaseObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISBaseObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISBaseObject : public IDispatch {
  public:
    virtual HRESULT WINAPI GetDataPaths(BSTR bstrName,LONG lnAttribute,VARIANT *pvPaths) = 0;
    virtual HRESULT WINAPI GetPropertyAttribObj(BSTR bstrName,IDispatch **ppObject) = 0;

  };
#else
  typedef struct IISBaseObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISBaseObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IISBaseObject *This);
      ULONG (WINAPI *Release)(IISBaseObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IISBaseObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IISBaseObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IISBaseObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IISBaseObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetDataPaths)(IISBaseObject *This,BSTR bstrName,LONG lnAttribute,VARIANT *pvPaths);
      HRESULT (WINAPI *GetPropertyAttribObj)(IISBaseObject *This,BSTR bstrName,IDispatch **ppObject);
    END_INTERFACE
  } IISBaseObjectVtbl;
  struct IISBaseObject {
    CONST_VTBL struct IISBaseObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISBaseObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IISBaseObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IISBaseObject_Release(This) (This)->lpVtbl->Release(This)
#define IISBaseObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IISBaseObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IISBaseObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IISBaseObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IISBaseObject_GetDataPaths(This,bstrName,lnAttribute,pvPaths) (This)->lpVtbl->GetDataPaths(This,bstrName,lnAttribute,pvPaths)
#define IISBaseObject_GetPropertyAttribObj(This,bstrName,ppObject) (This)->lpVtbl->GetPropertyAttribObj(This,bstrName,ppObject)
#endif
#endif
  HRESULT WINAPI IISBaseObject_GetDataPaths_Proxy(IISBaseObject *This,BSTR bstrName,LONG lnAttribute,VARIANT *pvPaths);
  void __RPC_STUB IISBaseObject_GetDataPaths_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISBaseObject_GetPropertyAttribObj_Proxy(IISBaseObject *This,BSTR bstrName,IDispatch **ppObject);
  void __RPC_STUB IISBaseObject_GetPropertyAttribObj_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISSchemaObject_INTERFACE_DEFINED__
#define __IISSchemaObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISSchemaObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISSchemaObject : public IDispatch {
  public:
    virtual HRESULT WINAPI GetSchemaPropertyAttributes(BSTR bstrName,IDispatch **ppObject) = 0;
    virtual HRESULT WINAPI PutSchemaPropertyAttributes(IDispatch *pObject) = 0;
  };
#else
  typedef struct IISSchemaObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISSchemaObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IISSchemaObject *This);
      ULONG (WINAPI *Release)(IISSchemaObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IISSchemaObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IISSchemaObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IISSchemaObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IISSchemaObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetSchemaPropertyAttributes)(IISSchemaObject *This,BSTR bstrName,IDispatch **ppObject);
      HRESULT (WINAPI *PutSchemaPropertyAttributes)(IISSchemaObject *This,IDispatch *pObject);
    END_INTERFACE
  } IISSchemaObjectVtbl;
  struct IISSchemaObject {
    CONST_VTBL struct IISSchemaObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISSchemaObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IISSchemaObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IISSchemaObject_Release(This) (This)->lpVtbl->Release(This)
#define IISSchemaObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IISSchemaObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IISSchemaObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IISSchemaObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IISSchemaObject_GetSchemaPropertyAttributes(This,bstrName,ppObject) (This)->lpVtbl->GetSchemaPropertyAttributes(This,bstrName,ppObject)
#define IISSchemaObject_PutSchemaPropertyAttributes(This,pObject) (This)->lpVtbl->PutSchemaPropertyAttributes(This,pObject)
#endif
#endif
  HRESULT WINAPI IISSchemaObject_GetSchemaPropertyAttributes_Proxy(IISSchemaObject *This,BSTR bstrName,IDispatch **ppObject);
  void __RPC_STUB IISSchemaObject_GetSchemaPropertyAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISSchemaObject_PutSchemaPropertyAttributes_Proxy(IISSchemaObject *This,IDispatch *pObject);
  void __RPC_STUB IISSchemaObject_PutSchemaPropertyAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISPropertyAttribute_INTERFACE_DEFINED__
#define __IISPropertyAttribute_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISPropertyAttribute;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISPropertyAttribute : public IDispatch {
  public:
    virtual HRESULT WINAPI get_PropName(BSTR *retval) = 0;
    virtual HRESULT WINAPI get_MetaId(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI put_MetaId(__LONG32 lnMetaId) = 0;
    virtual HRESULT WINAPI get_UserType(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI put_UserType(__LONG32 lnUserType) = 0;
    virtual HRESULT WINAPI get_AllAttributes(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI get_Inherit(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI put_Inherit(VARIANT_BOOL fInherit) = 0;
    virtual HRESULT WINAPI get_Secure(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI put_Secure(VARIANT_BOOL fSecure) = 0;
    virtual HRESULT WINAPI get_Reference(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI put_Reference(VARIANT_BOOL fReference) = 0;
    virtual HRESULT WINAPI get_Volatile(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI put_Volatile(VARIANT_BOOL fVolatile) = 0;
    virtual HRESULT WINAPI get_Isinherit(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI get_Default(VARIANT *retval) = 0;
    virtual HRESULT WINAPI put_Default(VARIANT vDefault) = 0;
  };
#else
  typedef struct IISPropertyAttributeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISPropertyAttribute *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IISPropertyAttribute *This);
      ULONG (WINAPI *Release)(IISPropertyAttribute *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IISPropertyAttribute *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IISPropertyAttribute *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IISPropertyAttribute *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IISPropertyAttribute *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_PropName)(IISPropertyAttribute *This,BSTR *retval);
      HRESULT (WINAPI *get_MetaId)(IISPropertyAttribute *This,__LONG32 *retval);
      HRESULT (WINAPI *put_MetaId)(IISPropertyAttribute *This,__LONG32 lnMetaId);
      HRESULT (WINAPI *get_UserType)(IISPropertyAttribute *This,__LONG32 *retval);
      HRESULT (WINAPI *put_UserType)(IISPropertyAttribute *This,__LONG32 lnUserType);
      HRESULT (WINAPI *get_AllAttributes)(IISPropertyAttribute *This,__LONG32 *retval);
      HRESULT (WINAPI *get_Inherit)(IISPropertyAttribute *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *put_Inherit)(IISPropertyAttribute *This,VARIANT_BOOL fInherit);
      HRESULT (WINAPI *get_Secure)(IISPropertyAttribute *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *put_Secure)(IISPropertyAttribute *This,VARIANT_BOOL fSecure);
      HRESULT (WINAPI *get_Reference)(IISPropertyAttribute *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *put_Reference)(IISPropertyAttribute *This,VARIANT_BOOL fReference);
      HRESULT (WINAPI *get_Volatile)(IISPropertyAttribute *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *put_Volatile)(IISPropertyAttribute *This,VARIANT_BOOL fVolatile);
      HRESULT (WINAPI *get_Isinherit)(IISPropertyAttribute *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *get_Default)(IISPropertyAttribute *This,VARIANT *retval);
      HRESULT (WINAPI *put_Default)(IISPropertyAttribute *This,VARIANT vDefault);
    END_INTERFACE
  } IISPropertyAttributeVtbl;
  struct IISPropertyAttribute {
    CONST_VTBL struct IISPropertyAttributeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISPropertyAttribute_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IISPropertyAttribute_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IISPropertyAttribute_Release(This) (This)->lpVtbl->Release(This)
#define IISPropertyAttribute_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IISPropertyAttribute_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IISPropertyAttribute_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IISPropertyAttribute_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IISPropertyAttribute_get_PropName(This,retval) (This)->lpVtbl->get_PropName(This,retval)
#define IISPropertyAttribute_get_MetaId(This,retval) (This)->lpVtbl->get_MetaId(This,retval)
#define IISPropertyAttribute_put_MetaId(This,lnMetaId) (This)->lpVtbl->put_MetaId(This,lnMetaId)
#define IISPropertyAttribute_get_UserType(This,retval) (This)->lpVtbl->get_UserType(This,retval)
#define IISPropertyAttribute_put_UserType(This,lnUserType) (This)->lpVtbl->put_UserType(This,lnUserType)
#define IISPropertyAttribute_get_AllAttributes(This,retval) (This)->lpVtbl->get_AllAttributes(This,retval)
#define IISPropertyAttribute_get_Inherit(This,retval) (This)->lpVtbl->get_Inherit(This,retval)
#define IISPropertyAttribute_put_Inherit(This,fInherit) (This)->lpVtbl->put_Inherit(This,fInherit)
#define IISPropertyAttribute_get_Secure(This,retval) (This)->lpVtbl->get_Secure(This,retval)
#define IISPropertyAttribute_put_Secure(This,fSecure) (This)->lpVtbl->put_Secure(This,fSecure)
#define IISPropertyAttribute_get_Reference(This,retval) (This)->lpVtbl->get_Reference(This,retval)
#define IISPropertyAttribute_put_Reference(This,fReference) (This)->lpVtbl->put_Reference(This,fReference)
#define IISPropertyAttribute_get_Volatile(This,retval) (This)->lpVtbl->get_Volatile(This,retval)
#define IISPropertyAttribute_put_Volatile(This,fVolatile) (This)->lpVtbl->put_Volatile(This,fVolatile)
#define IISPropertyAttribute_get_Isinherit(This,retval) (This)->lpVtbl->get_Isinherit(This,retval)
#define IISPropertyAttribute_get_Default(This,retval) (This)->lpVtbl->get_Default(This,retval)
#define IISPropertyAttribute_put_Default(This,vDefault) (This)->lpVtbl->put_Default(This,vDefault)
#endif
#endif
  HRESULT WINAPI IISPropertyAttribute_get_PropName_Proxy(IISPropertyAttribute *This,BSTR *retval);
  void __RPC_STUB IISPropertyAttribute_get_PropName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_MetaId_Proxy(IISPropertyAttribute *This,__LONG32 *retval);
  void __RPC_STUB IISPropertyAttribute_get_MetaId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_put_MetaId_Proxy(IISPropertyAttribute *This,__LONG32 lnMetaId);
  void __RPC_STUB IISPropertyAttribute_put_MetaId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_UserType_Proxy(IISPropertyAttribute *This,__LONG32 *retval);
  void __RPC_STUB IISPropertyAttribute_get_UserType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_put_UserType_Proxy(IISPropertyAttribute *This,__LONG32 lnUserType);
  void __RPC_STUB IISPropertyAttribute_put_UserType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_AllAttributes_Proxy(IISPropertyAttribute *This,__LONG32 *retval);
  void __RPC_STUB IISPropertyAttribute_get_AllAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_Inherit_Proxy(IISPropertyAttribute *This,VARIANT_BOOL *retval);
  void __RPC_STUB IISPropertyAttribute_get_Inherit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_put_Inherit_Proxy(IISPropertyAttribute *This,VARIANT_BOOL fInherit);
  void __RPC_STUB IISPropertyAttribute_put_Inherit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_Secure_Proxy(IISPropertyAttribute *This,VARIANT_BOOL *retval);
  void __RPC_STUB IISPropertyAttribute_get_Secure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_put_Secure_Proxy(IISPropertyAttribute *This,VARIANT_BOOL fSecure);
  void __RPC_STUB IISPropertyAttribute_put_Secure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_Reference_Proxy(IISPropertyAttribute *This,VARIANT_BOOL *retval);
  void __RPC_STUB IISPropertyAttribute_get_Reference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_put_Reference_Proxy(IISPropertyAttribute *This,VARIANT_BOOL fReference);
  void __RPC_STUB IISPropertyAttribute_put_Reference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_Volatile_Proxy(IISPropertyAttribute *This,VARIANT_BOOL *retval);
  void __RPC_STUB IISPropertyAttribute_get_Volatile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_put_Volatile_Proxy(IISPropertyAttribute *This,VARIANT_BOOL fVolatile);
  void __RPC_STUB IISPropertyAttribute_put_Volatile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_Isinherit_Proxy(IISPropertyAttribute *This,VARIANT_BOOL *retval);
  void __RPC_STUB IISPropertyAttribute_get_Isinherit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_get_Default_Proxy(IISPropertyAttribute *This,VARIANT *retval);
  void __RPC_STUB IISPropertyAttribute_get_Default_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISPropertyAttribute_put_Default_Proxy(IISPropertyAttribute *This,VARIANT vDefault);
  void __RPC_STUB IISPropertyAttribute_put_Default_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_PropertyAttribute;
#ifdef __cplusplus
  class PropertyAttribute;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
