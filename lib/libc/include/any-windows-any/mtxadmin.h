/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "rpc.h"
#include "rpcndr.h"
#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __mtxadmin_h__
#define __mtxadmin_h__

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __ICatalog_FWD_DEFINED__
#define __ICatalog_FWD_DEFINED__
  typedef struct ICatalog ICatalog;
#endif

#ifndef __ICatalogObject_FWD_DEFINED__
#define __ICatalogObject_FWD_DEFINED__
  typedef struct ICatalogObject ICatalogObject;
#endif

#ifndef __ICatalogCollection_FWD_DEFINED__
#define __ICatalogCollection_FWD_DEFINED__
  typedef struct ICatalogCollection ICatalogCollection;
#endif

#ifndef __IComponentUtil_FWD_DEFINED__
#define __IComponentUtil_FWD_DEFINED__
  typedef struct IComponentUtil IComponentUtil;
#endif

#ifndef __IPackageUtil_FWD_DEFINED__
#define __IPackageUtil_FWD_DEFINED__
  typedef struct IPackageUtil IPackageUtil;
#endif

#ifndef __IRemoteComponentUtil_FWD_DEFINED__
#define __IRemoteComponentUtil_FWD_DEFINED__
  typedef struct IRemoteComponentUtil IRemoteComponentUtil;
#endif

#ifndef __IRoleAssociationUtil_FWD_DEFINED__
#define __IRoleAssociationUtil_FWD_DEFINED__
  typedef struct IRoleAssociationUtil IRoleAssociationUtil;
#endif

#ifndef __Catalog_FWD_DEFINED__
#define __Catalog_FWD_DEFINED__
#ifdef __cplusplus
  typedef class Catalog Catalog;
#else
  typedef struct Catalog Catalog;
#endif
#endif

#ifndef __CatalogObject_FWD_DEFINED__
#define __CatalogObject_FWD_DEFINED__
#ifdef __cplusplus
  typedef class CatalogObject CatalogObject;
#else
  typedef struct CatalogObject CatalogObject;
#endif
#endif

#ifndef __CatalogCollection_FWD_DEFINED__
#define __CatalogCollection_FWD_DEFINED__
#ifdef __cplusplus
  typedef class CatalogCollection CatalogCollection;
#else
  typedef struct CatalogCollection CatalogCollection;
#endif
#endif

#ifndef __ComponentUtil_FWD_DEFINED__
#define __ComponentUtil_FWD_DEFINED__
#ifdef __cplusplus
  typedef class ComponentUtil ComponentUtil;
#else
  typedef struct ComponentUtil ComponentUtil;
#endif
#endif

#ifndef __PackageUtil_FWD_DEFINED__
#define __PackageUtil_FWD_DEFINED__
#ifdef __cplusplus
  typedef class PackageUtil PackageUtil;
#else
  typedef struct PackageUtil PackageUtil;
#endif
#endif

#ifndef __RemoteComponentUtil_FWD_DEFINED__
#define __RemoteComponentUtil_FWD_DEFINED__
#ifdef __cplusplus
  typedef class RemoteComponentUtil RemoteComponentUtil;
#else
  typedef struct RemoteComponentUtil RemoteComponentUtil;
#endif
#endif

#ifndef __RoleAssociationUtil_FWD_DEFINED__
#define __RoleAssociationUtil_FWD_DEFINED__
#ifdef __cplusplus
  typedef class RoleAssociationUtil RoleAssociationUtil;
#else
  typedef struct RoleAssociationUtil RoleAssociationUtil;
#endif
#endif

#include "unknwn.h"
#include "oaidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include <objbase.h>

  extern RPC_IF_HANDLE __MIDL_itf_mtxadmin_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mtxadmin_0000_v0_0_s_ifspec;

#ifndef __ICatalog_INTERFACE_DEFINED__
#define __ICatalog_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICatalog;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICatalog : public IDispatch {
  public:
    virtual HRESULT WINAPI GetCollection(BSTR bstrCollName,IDispatch **ppCatalogCollection) = 0;
    virtual HRESULT WINAPI Connect(BSTR bstrConnectString,IDispatch **ppCatalogCollection) = 0;
    virtual HRESULT WINAPI get_MajorVersion(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI get_MinorVersion(__LONG32 *retval) = 0;
  };
#else
  typedef struct ICatalogVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICatalog *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICatalog *This);
      ULONG (WINAPI *Release)(ICatalog *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICatalog *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICatalog *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICatalog *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICatalog *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetCollection)(ICatalog *This,BSTR bstrCollName,IDispatch **ppCatalogCollection);
      HRESULT (WINAPI *Connect)(ICatalog *This,BSTR bstrConnectString,IDispatch **ppCatalogCollection);
      HRESULT (WINAPI *get_MajorVersion)(ICatalog *This,__LONG32 *retval);
      HRESULT (WINAPI *get_MinorVersion)(ICatalog *This,__LONG32 *retval);
    END_INTERFACE
  } ICatalogVtbl;
  struct ICatalog {
    CONST_VTBL struct ICatalogVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICatalog_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICatalog_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICatalog_Release(This) (This)->lpVtbl->Release(This)
#define ICatalog_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICatalog_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICatalog_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICatalog_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICatalog_GetCollection(This,bstrCollName,ppCatalogCollection) (This)->lpVtbl->GetCollection(This,bstrCollName,ppCatalogCollection)
#define ICatalog_Connect(This,bstrConnectString,ppCatalogCollection) (This)->lpVtbl->Connect(This,bstrConnectString,ppCatalogCollection)
#define ICatalog_get_MajorVersion(This,retval) (This)->lpVtbl->get_MajorVersion(This,retval)
#define ICatalog_get_MinorVersion(This,retval) (This)->lpVtbl->get_MinorVersion(This,retval)
#endif
#endif
  HRESULT WINAPI ICatalog_GetCollection_Proxy(ICatalog *This,BSTR bstrCollName,IDispatch **ppCatalogCollection);
  void __RPC_STUB ICatalog_GetCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalog_Connect_Proxy(ICatalog *This,BSTR bstrConnectString,IDispatch **ppCatalogCollection);
  void __RPC_STUB ICatalog_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalog_get_MajorVersion_Proxy(ICatalog *This,__LONG32 *retval);
  void __RPC_STUB ICatalog_get_MajorVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalog_get_MinorVersion_Proxy(ICatalog *This,__LONG32 *retval);
  void __RPC_STUB ICatalog_get_MinorVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICatalogObject_INTERFACE_DEFINED__
#define __ICatalogObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICatalogObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICatalogObject : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Value(BSTR bstrPropName,VARIANT *retval) = 0;
    virtual HRESULT WINAPI put_Value(BSTR bstrPropName,VARIANT val) = 0;
    virtual HRESULT WINAPI get_Key(VARIANT *retval) = 0;
    virtual HRESULT WINAPI get_Name(VARIANT *retval) = 0;
    virtual HRESULT WINAPI IsPropertyReadOnly(BSTR bstrPropName,VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI get_Valid(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI IsPropertyWriteOnly(BSTR bstrPropName,VARIANT_BOOL *retval) = 0;
  };
#else
  typedef struct ICatalogObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICatalogObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICatalogObject *This);
      ULONG (WINAPI *Release)(ICatalogObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICatalogObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICatalogObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICatalogObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICatalogObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Value)(ICatalogObject *This,BSTR bstrPropName,VARIANT *retval);
      HRESULT (WINAPI *put_Value)(ICatalogObject *This,BSTR bstrPropName,VARIANT val);
      HRESULT (WINAPI *get_Key)(ICatalogObject *This,VARIANT *retval);
      HRESULT (WINAPI *get_Name)(ICatalogObject *This,VARIANT *retval);
      HRESULT (WINAPI *IsPropertyReadOnly)(ICatalogObject *This,BSTR bstrPropName,VARIANT_BOOL *retval);
      HRESULT (WINAPI *get_Valid)(ICatalogObject *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *IsPropertyWriteOnly)(ICatalogObject *This,BSTR bstrPropName,VARIANT_BOOL *retval);
    END_INTERFACE
  } ICatalogObjectVtbl;
  struct ICatalogObject {
    CONST_VTBL struct ICatalogObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICatalogObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICatalogObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICatalogObject_Release(This) (This)->lpVtbl->Release(This)
#define ICatalogObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICatalogObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICatalogObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICatalogObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICatalogObject_get_Value(This,bstrPropName,retval) (This)->lpVtbl->get_Value(This,bstrPropName,retval)
#define ICatalogObject_put_Value(This,bstrPropName,val) (This)->lpVtbl->put_Value(This,bstrPropName,val)
#define ICatalogObject_get_Key(This,retval) (This)->lpVtbl->get_Key(This,retval)
#define ICatalogObject_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define ICatalogObject_IsPropertyReadOnly(This,bstrPropName,retval) (This)->lpVtbl->IsPropertyReadOnly(This,bstrPropName,retval)
#define ICatalogObject_get_Valid(This,retval) (This)->lpVtbl->get_Valid(This,retval)
#define ICatalogObject_IsPropertyWriteOnly(This,bstrPropName,retval) (This)->lpVtbl->IsPropertyWriteOnly(This,bstrPropName,retval)
#endif
#endif
  HRESULT WINAPI ICatalogObject_get_Value_Proxy(ICatalogObject *This,BSTR bstrPropName,VARIANT *retval);
  void __RPC_STUB ICatalogObject_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogObject_put_Value_Proxy(ICatalogObject *This,BSTR bstrPropName,VARIANT val);
  void __RPC_STUB ICatalogObject_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogObject_get_Key_Proxy(ICatalogObject *This,VARIANT *retval);
  void __RPC_STUB ICatalogObject_get_Key_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogObject_get_Name_Proxy(ICatalogObject *This,VARIANT *retval);
  void __RPC_STUB ICatalogObject_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogObject_IsPropertyReadOnly_Proxy(ICatalogObject *This,BSTR bstrPropName,VARIANT_BOOL *retval);
  void __RPC_STUB ICatalogObject_IsPropertyReadOnly_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogObject_get_Valid_Proxy(ICatalogObject *This,VARIANT_BOOL *retval);
  void __RPC_STUB ICatalogObject_get_Valid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogObject_IsPropertyWriteOnly_Proxy(ICatalogObject *This,BSTR bstrPropName,VARIANT_BOOL *retval);
  void __RPC_STUB ICatalogObject_IsPropertyWriteOnly_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICatalogCollection_INTERFACE_DEFINED__
#define __ICatalogCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICatalogCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICatalogCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumVariant) = 0;
    virtual HRESULT WINAPI get_Item(__LONG32 lIndex,IDispatch **ppCatalogObject) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI Remove(__LONG32 lIndex) = 0;
    virtual HRESULT WINAPI Add(IDispatch **ppCatalogObject) = 0;
    virtual HRESULT WINAPI Populate(void) = 0;
    virtual HRESULT WINAPI SaveChanges(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI GetCollection(BSTR bstrCollName,VARIANT varObjectKey,IDispatch **ppCatalogCollection) = 0;
    virtual HRESULT WINAPI get_Name(VARIANT *retval) = 0;
    virtual HRESULT WINAPI get_AddEnabled(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI get_RemoveEnabled(VARIANT_BOOL *retval) = 0;
    virtual HRESULT WINAPI GetUtilInterface(IDispatch **ppUtil) = 0;
    virtual HRESULT WINAPI get_DataStoreMajorVersion(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI get_DataStoreMinorVersion(__LONG32 *retval) = 0;
    virtual HRESULT WINAPI PopulateByKey(SAFEARRAY *aKeys) = 0;
    virtual HRESULT WINAPI PopulateByQuery(BSTR bstrQueryString,__LONG32 lQueryType) = 0;
  };
#else
  typedef struct ICatalogCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICatalogCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICatalogCollection *This);
      ULONG (WINAPI *Release)(ICatalogCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICatalogCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICatalogCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICatalogCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICatalogCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(ICatalogCollection *This,IUnknown **ppEnumVariant);
      HRESULT (WINAPI *get_Item)(ICatalogCollection *This,__LONG32 lIndex,IDispatch **ppCatalogObject);
      HRESULT (WINAPI *get_Count)(ICatalogCollection *This,__LONG32 *retval);
      HRESULT (WINAPI *Remove)(ICatalogCollection *This,__LONG32 lIndex);
      HRESULT (WINAPI *Add)(ICatalogCollection *This,IDispatch **ppCatalogObject);
      HRESULT (WINAPI *Populate)(ICatalogCollection *This);
      HRESULT (WINAPI *SaveChanges)(ICatalogCollection *This,__LONG32 *retval);
      HRESULT (WINAPI *GetCollection)(ICatalogCollection *This,BSTR bstrCollName,VARIANT varObjectKey,IDispatch **ppCatalogCollection);
      HRESULT (WINAPI *get_Name)(ICatalogCollection *This,VARIANT *retval);
      HRESULT (WINAPI *get_AddEnabled)(ICatalogCollection *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *get_RemoveEnabled)(ICatalogCollection *This,VARIANT_BOOL *retval);
      HRESULT (WINAPI *GetUtilInterface)(ICatalogCollection *This,IDispatch **ppUtil);
      HRESULT (WINAPI *get_DataStoreMajorVersion)(ICatalogCollection *This,__LONG32 *retval);
      HRESULT (WINAPI *get_DataStoreMinorVersion)(ICatalogCollection *This,__LONG32 *retval);
      HRESULT (WINAPI *PopulateByKey)(ICatalogCollection *This,SAFEARRAY *aKeys);
      HRESULT (WINAPI *PopulateByQuery)(ICatalogCollection *This,BSTR bstrQueryString,__LONG32 lQueryType);
    END_INTERFACE
  } ICatalogCollectionVtbl;
  struct ICatalogCollection {
    CONST_VTBL struct ICatalogCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICatalogCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICatalogCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICatalogCollection_Release(This) (This)->lpVtbl->Release(This)
#define ICatalogCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICatalogCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICatalogCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICatalogCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICatalogCollection_get__NewEnum(This,ppEnumVariant) (This)->lpVtbl->get__NewEnum(This,ppEnumVariant)
#define ICatalogCollection_get_Item(This,lIndex,ppCatalogObject) (This)->lpVtbl->get_Item(This,lIndex,ppCatalogObject)
#define ICatalogCollection_get_Count(This,retval) (This)->lpVtbl->get_Count(This,retval)
#define ICatalogCollection_Remove(This,lIndex) (This)->lpVtbl->Remove(This,lIndex)
#define ICatalogCollection_Add(This,ppCatalogObject) (This)->lpVtbl->Add(This,ppCatalogObject)
#define ICatalogCollection_Populate(This) (This)->lpVtbl->Populate(This)
#define ICatalogCollection_SaveChanges(This,retval) (This)->lpVtbl->SaveChanges(This,retval)
#define ICatalogCollection_GetCollection(This,bstrCollName,varObjectKey,ppCatalogCollection) (This)->lpVtbl->GetCollection(This,bstrCollName,varObjectKey,ppCatalogCollection)
#define ICatalogCollection_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define ICatalogCollection_get_AddEnabled(This,retval) (This)->lpVtbl->get_AddEnabled(This,retval)
#define ICatalogCollection_get_RemoveEnabled(This,retval) (This)->lpVtbl->get_RemoveEnabled(This,retval)
#define ICatalogCollection_GetUtilInterface(This,ppUtil) (This)->lpVtbl->GetUtilInterface(This,ppUtil)
#define ICatalogCollection_get_DataStoreMajorVersion(This,retval) (This)->lpVtbl->get_DataStoreMajorVersion(This,retval)
#define ICatalogCollection_get_DataStoreMinorVersion(This,retval) (This)->lpVtbl->get_DataStoreMinorVersion(This,retval)
#define ICatalogCollection_PopulateByKey(This,aKeys) (This)->lpVtbl->PopulateByKey(This,aKeys)
#define ICatalogCollection_PopulateByQuery(This,bstrQueryString,lQueryType) (This)->lpVtbl->PopulateByQuery(This,bstrQueryString,lQueryType)
#endif
#endif
  HRESULT WINAPI ICatalogCollection_get__NewEnum_Proxy(ICatalogCollection *This,IUnknown **ppEnumVariant);
  void __RPC_STUB ICatalogCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_get_Item_Proxy(ICatalogCollection *This,__LONG32 lIndex,IDispatch **ppCatalogObject);
  void __RPC_STUB ICatalogCollection_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_get_Count_Proxy(ICatalogCollection *This,__LONG32 *retval);
  void __RPC_STUB ICatalogCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_Remove_Proxy(ICatalogCollection *This,__LONG32 lIndex);
  void __RPC_STUB ICatalogCollection_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_Add_Proxy(ICatalogCollection *This,IDispatch **ppCatalogObject);
  void __RPC_STUB ICatalogCollection_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_Populate_Proxy(ICatalogCollection *This);
  void __RPC_STUB ICatalogCollection_Populate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_SaveChanges_Proxy(ICatalogCollection *This,__LONG32 *retval);
  void __RPC_STUB ICatalogCollection_SaveChanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_GetCollection_Proxy(ICatalogCollection *This,BSTR bstrCollName,VARIANT varObjectKey,IDispatch **ppCatalogCollection);
  void __RPC_STUB ICatalogCollection_GetCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_get_Name_Proxy(ICatalogCollection *This,VARIANT *retval);
  void __RPC_STUB ICatalogCollection_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_get_AddEnabled_Proxy(ICatalogCollection *This,VARIANT_BOOL *retval);
  void __RPC_STUB ICatalogCollection_get_AddEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_get_RemoveEnabled_Proxy(ICatalogCollection *This,VARIANT_BOOL *retval);
  void __RPC_STUB ICatalogCollection_get_RemoveEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_GetUtilInterface_Proxy(ICatalogCollection *This,IDispatch **ppUtil);
  void __RPC_STUB ICatalogCollection_GetUtilInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_get_DataStoreMajorVersion_Proxy(ICatalogCollection *This,__LONG32 *retval);
  void __RPC_STUB ICatalogCollection_get_DataStoreMajorVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_get_DataStoreMinorVersion_Proxy(ICatalogCollection *This,__LONG32 *retval);
  void __RPC_STUB ICatalogCollection_get_DataStoreMinorVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_PopulateByKey_Proxy(ICatalogCollection *This,SAFEARRAY *aKeys);
  void __RPC_STUB ICatalogCollection_PopulateByKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICatalogCollection_PopulateByQuery_Proxy(ICatalogCollection *This,BSTR bstrQueryString,__LONG32 lQueryType);
  void __RPC_STUB ICatalogCollection_PopulateByQuery_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComponentUtil_INTERFACE_DEFINED__
#define __IComponentUtil_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComponentUtil;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComponentUtil : public IDispatch {
  public:
    virtual HRESULT WINAPI InstallComponent(BSTR bstrDLLFile,BSTR bstrTypelibFile,BSTR bstrProxyStubDLLFile) = 0;
    virtual HRESULT WINAPI ImportComponent(BSTR bstrCLSID) = 0;
    virtual HRESULT WINAPI ImportComponentByName(BSTR bstrProgID) = 0;
    virtual HRESULT WINAPI GetCLSIDs(BSTR bstrDLLFile,BSTR bstrTypelibFile,SAFEARRAY **aCLSIDs) = 0;
  };
#else
  typedef struct IComponentUtilVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComponentUtil *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComponentUtil *This);
      ULONG (WINAPI *Release)(IComponentUtil *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IComponentUtil *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IComponentUtil *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IComponentUtil *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IComponentUtil *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *InstallComponent)(IComponentUtil *This,BSTR bstrDLLFile,BSTR bstrTypelibFile,BSTR bstrProxyStubDLLFile);
      HRESULT (WINAPI *ImportComponent)(IComponentUtil *This,BSTR bstrCLSID);
      HRESULT (WINAPI *ImportComponentByName)(IComponentUtil *This,BSTR bstrProgID);
      HRESULT (WINAPI *GetCLSIDs)(IComponentUtil *This,BSTR bstrDLLFile,BSTR bstrTypelibFile,SAFEARRAY **aCLSIDs);
    END_INTERFACE
  } IComponentUtilVtbl;
  struct IComponentUtil {
    CONST_VTBL struct IComponentUtilVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComponentUtil_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComponentUtil_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComponentUtil_Release(This) (This)->lpVtbl->Release(This)
#define IComponentUtil_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IComponentUtil_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IComponentUtil_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IComponentUtil_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IComponentUtil_InstallComponent(This,bstrDLLFile,bstrTypelibFile,bstrProxyStubDLLFile) (This)->lpVtbl->InstallComponent(This,bstrDLLFile,bstrTypelibFile,bstrProxyStubDLLFile)
#define IComponentUtil_ImportComponent(This,bstrCLSID) (This)->lpVtbl->ImportComponent(This,bstrCLSID)
#define IComponentUtil_ImportComponentByName(This,bstrProgID) (This)->lpVtbl->ImportComponentByName(This,bstrProgID)
#define IComponentUtil_GetCLSIDs(This,bstrDLLFile,bstrTypelibFile,aCLSIDs) (This)->lpVtbl->GetCLSIDs(This,bstrDLLFile,bstrTypelibFile,aCLSIDs)
#endif
#endif
  HRESULT WINAPI IComponentUtil_InstallComponent_Proxy(IComponentUtil *This,BSTR bstrDLLFile,BSTR bstrTypelibFile,BSTR bstrProxyStubDLLFile);
  void __RPC_STUB IComponentUtil_InstallComponent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComponentUtil_ImportComponent_Proxy(IComponentUtil *This,BSTR bstrCLSID);
  void __RPC_STUB IComponentUtil_ImportComponent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComponentUtil_ImportComponentByName_Proxy(IComponentUtil *This,BSTR bstrProgID);
  void __RPC_STUB IComponentUtil_ImportComponentByName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComponentUtil_GetCLSIDs_Proxy(IComponentUtil *This,BSTR bstrDLLFile,BSTR bstrTypelibFile,SAFEARRAY **aCLSIDs);
  void __RPC_STUB IComponentUtil_GetCLSIDs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPackageUtil_INTERFACE_DEFINED__
#define __IPackageUtil_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPackageUtil;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPackageUtil : public IDispatch {
  public:
    virtual HRESULT WINAPI InstallPackage(BSTR bstrPackageFile,BSTR bstrInstallPath,__LONG32 lOptions) = 0;
    virtual HRESULT WINAPI ExportPackage(BSTR bstrPackageID,BSTR bstrPackageFile,__LONG32 lOptions) = 0;
    virtual HRESULT WINAPI ShutdownPackage(BSTR bstrPackageID) = 0;
  };
#else
  typedef struct IPackageUtilVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPackageUtil *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPackageUtil *This);
      ULONG (WINAPI *Release)(IPackageUtil *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IPackageUtil *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IPackageUtil *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IPackageUtil *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IPackageUtil *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *InstallPackage)(IPackageUtil *This,BSTR bstrPackageFile,BSTR bstrInstallPath,__LONG32 lOptions);
      HRESULT (WINAPI *ExportPackage)(IPackageUtil *This,BSTR bstrPackageID,BSTR bstrPackageFile,__LONG32 lOptions);
      HRESULT (WINAPI *ShutdownPackage)(IPackageUtil *This,BSTR bstrPackageID);
    END_INTERFACE
  } IPackageUtilVtbl;
  struct IPackageUtil {
    CONST_VTBL struct IPackageUtilVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPackageUtil_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPackageUtil_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPackageUtil_Release(This) (This)->lpVtbl->Release(This)
#define IPackageUtil_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IPackageUtil_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IPackageUtil_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IPackageUtil_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IPackageUtil_InstallPackage(This,bstrPackageFile,bstrInstallPath,lOptions) (This)->lpVtbl->InstallPackage(This,bstrPackageFile,bstrInstallPath,lOptions)
#define IPackageUtil_ExportPackage(This,bstrPackageID,bstrPackageFile,lOptions) (This)->lpVtbl->ExportPackage(This,bstrPackageID,bstrPackageFile,lOptions)
#define IPackageUtil_ShutdownPackage(This,bstrPackageID) (This)->lpVtbl->ShutdownPackage(This,bstrPackageID)
#endif
#endif
  HRESULT WINAPI IPackageUtil_InstallPackage_Proxy(IPackageUtil *This,BSTR bstrPackageFile,BSTR bstrInstallPath,__LONG32 lOptions);
  void __RPC_STUB IPackageUtil_InstallPackage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPackageUtil_ExportPackage_Proxy(IPackageUtil *This,BSTR bstrPackageID,BSTR bstrPackageFile,__LONG32 lOptions);
  void __RPC_STUB IPackageUtil_ExportPackage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPackageUtil_ShutdownPackage_Proxy(IPackageUtil *This,BSTR bstrPackageID);
  void __RPC_STUB IPackageUtil_ShutdownPackage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRemoteComponentUtil_INTERFACE_DEFINED__
#define __IRemoteComponentUtil_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRemoteComponentUtil;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRemoteComponentUtil : public IDispatch {
  public:
    virtual HRESULT WINAPI InstallRemoteComponent(BSTR bstrServer,BSTR bstrPackageID,BSTR bstrCLSID) = 0;
    virtual HRESULT WINAPI InstallRemoteComponentByName(BSTR bstrServer,BSTR bstrPackageName,BSTR bstrProgID) = 0;
  };
#else
  typedef struct IRemoteComponentUtilVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRemoteComponentUtil *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRemoteComponentUtil *This);
      ULONG (WINAPI *Release)(IRemoteComponentUtil *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRemoteComponentUtil *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRemoteComponentUtil *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRemoteComponentUtil *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRemoteComponentUtil *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *InstallRemoteComponent)(IRemoteComponentUtil *This,BSTR bstrServer,BSTR bstrPackageID,BSTR bstrCLSID);
      HRESULT (WINAPI *InstallRemoteComponentByName)(IRemoteComponentUtil *This,BSTR bstrServer,BSTR bstrPackageName,BSTR bstrProgID);
    END_INTERFACE
  } IRemoteComponentUtilVtbl;
  struct IRemoteComponentUtil {
    CONST_VTBL struct IRemoteComponentUtilVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRemoteComponentUtil_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRemoteComponentUtil_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRemoteComponentUtil_Release(This) (This)->lpVtbl->Release(This)
#define IRemoteComponentUtil_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRemoteComponentUtil_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRemoteComponentUtil_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRemoteComponentUtil_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRemoteComponentUtil_InstallRemoteComponent(This,bstrServer,bstrPackageID,bstrCLSID) (This)->lpVtbl->InstallRemoteComponent(This,bstrServer,bstrPackageID,bstrCLSID)
#define IRemoteComponentUtil_InstallRemoteComponentByName(This,bstrServer,bstrPackageName,bstrProgID) (This)->lpVtbl->InstallRemoteComponentByName(This,bstrServer,bstrPackageName,bstrProgID)
#endif
#endif
  HRESULT WINAPI IRemoteComponentUtil_InstallRemoteComponent_Proxy(IRemoteComponentUtil *This,BSTR bstrServer,BSTR bstrPackageID,BSTR bstrCLSID);
  void __RPC_STUB IRemoteComponentUtil_InstallRemoteComponent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRemoteComponentUtil_InstallRemoteComponentByName_Proxy(IRemoteComponentUtil *This,BSTR bstrServer,BSTR bstrPackageName,BSTR bstrProgID);
  void __RPC_STUB IRemoteComponentUtil_InstallRemoteComponentByName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRoleAssociationUtil_INTERFACE_DEFINED__
#define __IRoleAssociationUtil_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRoleAssociationUtil;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRoleAssociationUtil : public IDispatch {
  public:
    virtual HRESULT WINAPI AssociateRole(BSTR bstrRoleID) = 0;
    virtual HRESULT WINAPI AssociateRoleByName(BSTR bstrRoleName) = 0;
  };
#else
  typedef struct IRoleAssociationUtilVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRoleAssociationUtil *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRoleAssociationUtil *This);
      ULONG (WINAPI *Release)(IRoleAssociationUtil *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRoleAssociationUtil *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRoleAssociationUtil *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRoleAssociationUtil *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRoleAssociationUtil *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *AssociateRole)(IRoleAssociationUtil *This,BSTR bstrRoleID);
      HRESULT (WINAPI *AssociateRoleByName)(IRoleAssociationUtil *This,BSTR bstrRoleName);
    END_INTERFACE
  } IRoleAssociationUtilVtbl;
  struct IRoleAssociationUtil {
    CONST_VTBL struct IRoleAssociationUtilVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRoleAssociationUtil_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRoleAssociationUtil_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRoleAssociationUtil_Release(This) (This)->lpVtbl->Release(This)
#define IRoleAssociationUtil_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRoleAssociationUtil_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRoleAssociationUtil_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRoleAssociationUtil_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRoleAssociationUtil_AssociateRole(This,bstrRoleID) (This)->lpVtbl->AssociateRole(This,bstrRoleID)
#define IRoleAssociationUtil_AssociateRoleByName(This,bstrRoleName) (This)->lpVtbl->AssociateRoleByName(This,bstrRoleName)
#endif
#endif
  HRESULT WINAPI IRoleAssociationUtil_AssociateRole_Proxy(IRoleAssociationUtil *This,BSTR bstrRoleID);
  void __RPC_STUB IRoleAssociationUtil_AssociateRole_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRoleAssociationUtil_AssociateRoleByName_Proxy(IRoleAssociationUtil *This,BSTR bstrRoleName);
  void __RPC_STUB IRoleAssociationUtil_AssociateRoleByName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __MTSAdmin_LIBRARY_DEFINED__
#define __MTSAdmin_LIBRARY_DEFINED__
  typedef enum __MIDL___MIDL_itf_mtxadmin_0107_0001 {
    mtsInstallUsers = 1
  } MTSPackageInstallOptions;

  typedef enum __MIDL___MIDL_itf_mtxadmin_0107_0002 {
    mtsExportUsers = 1
  } MTSPackageExportOptions;

  typedef enum __MIDL___MIDL_itf_mtxadmin_0107_0003 {
    mtsErrObjectErrors = 0x80110401,mtsErrObjectInvalid = 0x80110402,mtsErrKeyMissing = 0x80110403,mtsErrAlreadyInstalled = 0x80110404,
    mtsErrDownloadFailed = 0x80110405,mtsErrPDFWriteFail = 0x80110407,mtsErrPDFReadFail = 0x80110408,mtsErrPDFVersion = 0x80110409,
    mtsErrCoReqCompInstalled = 0x80110410,mtsErrBadPath = 0x8011040a,mtsErrPackageExists = 0x8011040b,mtsErrRoleExists = 0x8011040c,
    mtsErrCantCopyFile = 0x8011040d,mtsErrNoTypeLib = 0x8011040e,mtsErrNoUser = 0x8011040f,mtsErrInvalidUserids = 0x80110410,
    mtsErrNoRegistryCLSID = 0x80110411,mtsErrBadRegistryProgID = 0x80110412,mtsErrAuthenticationLevel = 0x80110413,
    mtsErrUserPasswdNotValid = 0x80110414,mtsErrNoRegistryRead = 0x80110415,mtsErrNoRegistryWrite = 0x80110416,mtsErrNoRegistryRepair = 0x80110417,
    mtsErrCLSIDOrIIDMismatch = 0x80110418,mtsErrRemoteInterface = 0x80110419,mtsErrDllRegisterServer = 0x8011041a,mtsErrNoServerShare = 0x8011041b,
    mtsErrNoAccessToUNC = 0x8011041c,mtsErrDllLoadFailed = 0x8011041d,mtsErrBadRegistryLibID = 0x8011041e,mtsErrPackDirNotFound = 0x8011041f,
    mtsErrTreatAs = 0x80110420,mtsErrBadForward = 0x80110421,mtsErrBadIID = 0x80110422,mtsErrRegistrarFailed = 0x80110423,
    mtsErrCompFileDoesNotExist = 0x80110424,mtsErrCompFileLoadDLLFail = 0x80110425,mtsErrCompFileGetClassObj = 0x80110426,
    mtsErrCompFileClassNotAvail = 0x80110427,mtsErrCompFileBadTLB = 0x80110428,mtsErrCompFileNotInstallable = 0x80110429,
    mtsErrNotChangeable = 0x8011042a,mtsErrNotDeletable = 0x8011042b,mtsErrSession = 0x8011042c,mtsErrCompFileNoRegistrar = 0x80110434
  } MTSAdminErrorCodes;

#define E_MTS_OBJECTERRORS mtsErrObjectErrors
#define E_MTS_OBJECTINVALID mtsErrObjectInvalid
#define E_MTS_KEYMISSING mtsErrKeyMissing
#define E_MTS_ALREADYINSTALLED mtsErrAlreadyInstalled
#define E_MTS_DOWNLOADFAILED mtsErrDownloadFailed
#define E_MTS_PDFWRITEFAIL mtsErrPDFWriteFail
#define E_MTS_PDFREADFAIL mtsErrPDFReadFail
#define E_MTS_PDFVERSION mtsErrPDFVersion
#define E_MTS_COREQCOMPINSTALLED mtsErrCoReqCompInstalled
#define E_MTS_BADPATH mtsErrBadPath
#define E_MTS_PACKAGEEXISTS mtsErrPackageExists
#define E_MTS_ROLEEXISTS mtsErrRoleExists
#define E_MTS_CANTCOPYFILE mtsErrCantCopyFile
#define E_MTS_NOTYPELIB mtsErrNoTypeLib
#define E_MTS_NOUSER mtsErrNoUser
#define E_MTS_INVALIDUSERIDS mtsErrInvalidUserids
#define E_MTS_NOREGISTRYCLSID mtsErrNoRegistryCLSID
#define E_MTS_BADREGISTRYPROGID mtsErrBadRegistryProgID
#define E_MTS_AUTHENTICATIONLEVEL mtsErrAuthenticationLevel
#define E_MTS_USERPASSWDNOTVALID mtsErrUserPasswdNotValid
#define E_MTS_NOREGISTRYREAD mtsErrNoRegistryRead
#define E_MTS_NOREGISTRYWRITE mtsErrNoRegistryWrite
#define E_MTS_NOREGISTRYREPAIR mtsErrNoRegistryRepair
#define E_MTS_CLSIDORIIDMISMATCH mtsErrCLSIDOrIIDMismatch
#define E_MTS_REMOTEINTERFACE mtsErrRemoteInterface
#define E_MTS_DLLREGISTERSERVER mtsErrDllRegisterServer
#define E_MTS_NOSERVERSHARE mtsErrNoServerShare
#define E_MTS_NOACCESSTOUNC mtsErrNoAccessToUNC
#define E_MTS_DLLLOADFAILED mtsErrDllLoadFailed
#define E_MTS_BADREGISTRYLIBID mtsErrBadRegistryLibID
#define E_MTS_PACKDIRNOTFOUND mtsErrPackDirNotFound
#define E_MTS_TREATAS mtsErrTreatAs
#define E_MTS_BADFORWARD mtsErrBadForward
#define E_MTS_BADIID mtsErrBadIID
#define E_MTS_REGISTRARFAILED mtsErrRegistrarFailed
#define E_MTS_COMPFILE_DOESNOTEXIST mtsErrCompFileDoesNotExist
#define E_MTS_COMPFILE_LOADDLLFAIL mtsErrCompFileLoadDLLFail
#define E_MTS_COMPFILE_GETCLASSOBJ mtsErrCompFileGetClassObj
#define E_MTS_COMPFILE_CLASSNOTAVAIL mtsErrCompFileClassNotAvail
#define E_MTS_COMPFILE_BADTLB mtsErrCompFileBadTLB
#define E_MTS_COMPFILE_NOTINSTALLABLE mtsErrCompFileNotInstallable
#define E_MTS_NOTCHANGEABLE mtsErrNotChangeable
#define E_MTS_NOTDELETEABLE mtsErrNotDeleteable
#define E_MTS_SESSION mtsErrSession
#define E_MTS_COMPFILE_NOREGISTRAR mtsErrCompFileNoRegistrar

  EXTERN_C const IID LIBID_MTSAdmin;

#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_Catalog;
  class Catalog;
#endif
#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_CatalogObject;
  class CatalogObject;
#endif

#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_CatalogCollection;
  class CatalogCollection;
#endif

#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_ComponentUtil;
  class ComponentUtil;
#endif

#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_PackageUtil;
  class PackageUtil;
#endif

#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_RemoteComponentUtil;
  class RemoteComponentUtil;
#endif

#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_RoleAssociationUtil;
  class RoleAssociationUtil;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API LPSAFEARRAY_UserSize(ULONG *,ULONG,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserMarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserUnmarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  void __RPC_API LPSAFEARRAY_UserFree(ULONG *,LPSAFEARRAY *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
