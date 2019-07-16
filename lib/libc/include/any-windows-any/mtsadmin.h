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

#ifndef __mtsadmin_h__
#define __mtsadmin_h__

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __ICatalog_FWD_DEFINED__
#define __ICatalog_FWD_DEFINED__
  typedef struct ICatalog ICatalog;
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
#include "comadmin.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include <objbase.h>

  extern RPC_IF_HANDLE __MIDL_itf_mtsadmin_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mtsadmin_0000_v0_0_s_ifspec;

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

  typedef enum __MIDL___MIDL_itf_mtsadmin_0123_0001 {
    mtsInstallUsers = 1
  } MTSPackageInstallOptions;

  typedef enum __MIDL___MIDL_itf_mtsadmin_0123_0002 {
    mtsExportUsers = 1
  } MTSPackageExportOptions;

  typedef enum __MIDL___MIDL_itf_mtsadmin_0123_0003 {
    mtsErrObjectErrors = (HRESULT)0x80110401,mtsErrObjectInvalid = (HRESULT)0x80110402,mtsErrKeyMissing = (HRESULT)0x80110403,
    mtsErrAlreadyInstalled = (HRESULT)0x80110404,mtsErrDownloadFailed = 0x80110405,mtsErrPDFWriteFail = (HRESULT)0x80110407,
    mtsErrPDFReadFail = (HRESULT)0x80110408,mtsErrPDFVersion = (HRESULT)0x80110409,mtsErrBadPath = (HRESULT)0x8011040a,
    mtsErrPackageExists = (HRESULT)0x8011040b,mtsErrRoleExists = (HRESULT)0x8011040c,mtsErrCantCopyFile = (HRESULT)0x8011040d,
    mtsErrNoTypeLib = 0x8011040e,mtsErrNoUser = (HRESULT)0x8011040f,mtsErrInvalidUserids = (HRESULT)0x80110410,
    mtsErrNoRegistryCLSID = (HRESULT)0x80110411,mtsErrBadRegistryProgID = (HRESULT)0x80110412,mtsErrAuthenticationLevel = (HRESULT)0x80110413,
    mtsErrUserPasswdNotValid = (HRESULT)0x80110414,mtsErrNoRegistryRead = 0x80110415,mtsErrNoRegistryWrite = 0x80110416,
    mtsErrNoRegistryRepair = 0x80110417,mtsErrCLSIDOrIIDMismatch = (HRESULT)0x80110418,mtsErrRemoteInterface = (HRESULT)0x80110419,
    mtsErrDllRegisterServer = (HRESULT)0x8011041a,mtsErrNoServerShare = (HRESULT)0x8011041b,mtsErrNoAccessToUNC = 0x8011041c,
    mtsErrDllLoadFailed = (HRESULT)0x8011041d,mtsErrBadRegistryLibID = (HRESULT)0x8011041e,mtsErrPackDirNotFound = (HRESULT)0x8011041f,
    mtsErrTreatAs = 0x80110420,mtsErrBadForward = 0x80110421,mtsErrBadIID = 0x80110422,mtsErrRegistrarFailed = (HRESULT)0x80110423,
    mtsErrCompFileDoesNotExist = (HRESULT)0x80110424,mtsErrCompFileLoadDLLFail = (HRESULT)0x80110425,mtsErrCompFileGetClassObj = (HRESULT)0x80110426,
    mtsErrCompFileClassNotAvail = (HRESULT)0x80110427,mtsErrCompFileBadTLB = (HRESULT)0x80110428,mtsErrCompFileNotInstallable = (HRESULT)0x80110429,
    mtsErrNotChangeable = (HRESULT)0x8011042a,mtsErrNotDeletable = (HRESULT)0x8011042b,mtsErrSession = (HRESULT)0x8011042c,
    mtsErrCompMoveLocked = (HRESULT)0x8011042d,mtsErrCompMoveBadDest = (HRESULT)0x8011042e,mtsErrRegisterTLB = (HRESULT)0x80110430,
    mtsErrSystemPack = (HRESULT)0x80110433,mtsErrCompFileNoRegistrar = (HRESULT)0x80110434,mtsErrCoReqCompInstalled = (HRESULT)0x80110435,
    mtsErrPropSaveFailed = (HRESULT)0x80110437,mtsErrObjectExists = (HRESULT)0x80110438,mtsErrRegFileCorrupt = (HRESULT)0x8011043b,
    mtsErrPropertyOverflow = (HRESULT)0x8011043c,mtsErrNotInRegistry = (HRESULT)0x8011043e,mtsErrApplidMatchesClsid = (HRESULT)0x80110446,
    mtsErrRoleDoesNotExist = (HRESULT)0x80110447,mtsErrObjectParentMissing = (HRESULT)0x80110808,mtsErrObjectDoesNotExist = (HRESULT)0x80110809,
    mtsErrCanNotExportAppProxy = 0x8011044a,mtsErrCanNotExportSystemPack = 0x8011044c
  };

#define E_MTS_OBJECTERRORS mtsErrObjectErrors
#define E_MTS_OBJECTINVALID mtsErrObjectInvalid
#define E_MTS_KEYMISSING mtsErrKeyMissing
#define E_MTS_ALREADYINSTALLED mtsErrAlreadyInstalled
#define E_MTS_DOWNLOADFAILED mtsErrDownloadFailed
#define E_MTS_PDFWRITEFAIL mtsErrPDFWriteFail
#define E_MTS_PDFREADFAIL mtsErrPDFReadFail
#define E_MTS_PDFVERSION mtsErrPDFVersion
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
#define E_MTS_NOTDELETEABLE mtsErrNotDeletable
#define E_MTS_SESSION mtsErrSession
#define E_MTS_COMP_MOVE_LOCKED mtsErrCompMoveLocked
#define E_MTS_COMP_MOVE_BAD_DEST mtsErrCompMoveBadDest
#define E_MTS_REGISTERTLB mtsErrRegisterTLB
#define E_MTS_SYSTEMPACK mtsErrSystemPack
#define E_MTS_COMPFILE_NOREGISTRAR mtsErrCompFileNoRegistrar
#define E_MTS_COREQCOMPINSTALLED mtsErrCoReqCompInstalled
#define E_MTS_PROPERTYSAVEFAILED mtsErrPropSaveFailed
#define E_MTS_OBJECTEXISTS mtsErrObjectExists
#define E_MTS_REGFILE_CORRUPT mtsErrRegFileCorrupt
#define E_MTS_PROPERTY_OVERFLOW mtsErrPropertyOverflow
#define E_MTS_NOTINREGISTRY mtsErrNotInRegistry
#define E_MTS_APPLID_MATCHES_CLSID mtsErrApplidMatchesClsid
#define E_MTS_ROLE_DOES_NOT_EXIST mtsErrRoleDoesNotExist
#define E_MTS_OBJECT_PARENT_MISSING mtsErrObjectParentMissing
#define E_MTS_OBJECT_DOES_NOT_EXIST mtsErrObjectDoesNotExist
#define E_MTS_CAN_NOT_EXPORT_APP_PROXY mtsErrCanNotExportAppProxy
#define E_MTS_CAN_NOT_EXPORT_SYSTEM_PACK mtsErrCanNotExportSystemPack

  EXTERN_C const IID LIBID_MTSAdmin;
  EXTERN_C const CLSID CLSID_Catalog;
#ifdef __cplusplus
  class Catalog;
#endif
  EXTERN_C const CLSID CLSID_CatalogObject;
#ifdef __cplusplus
  class CatalogObject;
#endif
  EXTERN_C const CLSID CLSID_CatalogCollection;
#ifdef __cplusplus
  class CatalogCollection;
#endif
  EXTERN_C const CLSID CLSID_ComponentUtil;
#ifdef __cplusplus
  class ComponentUtil;
#endif
  EXTERN_C const CLSID CLSID_PackageUtil;
#ifdef __cplusplus
  class PackageUtil;
#endif
  EXTERN_C const CLSID CLSID_RemoteComponentUtil;
#ifdef __cplusplus
  class RemoteComponentUtil;
#endif
  EXTERN_C const CLSID CLSID_RoleAssociationUtil;
#ifdef __cplusplus
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

#ifdef __cplusplus
}
#endif
#endif
