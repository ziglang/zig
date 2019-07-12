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

#ifndef __iiisext_h__
#define __iiisext_h__

#ifndef __IISApplicationPool_FWD_DEFINED__
#define __IISApplicationPool_FWD_DEFINED__
typedef struct IISApplicationPool IISApplicationPool;
#endif

#ifndef __IISApplicationPools_FWD_DEFINED__
#define __IISApplicationPools_FWD_DEFINED__
typedef struct IISApplicationPools IISApplicationPools;
#endif

#ifndef __IISWebService_FWD_DEFINED__
#define __IISWebService_FWD_DEFINED__
typedef struct IISWebService IISWebService;
#endif

#ifndef __IISDsCrMap_FWD_DEFINED__
#define __IISDsCrMap_FWD_DEFINED__
typedef struct IISDsCrMap IISDsCrMap;
#endif

#ifndef __IISApp_FWD_DEFINED__
#define __IISApp_FWD_DEFINED__
typedef struct IISApp IISApp;
#endif

#ifndef __IISApp2_FWD_DEFINED__
#define __IISApp2_FWD_DEFINED__
typedef struct IISApp2 IISApp2;
#endif

#ifndef __IISApp3_FWD_DEFINED__
#define __IISApp3_FWD_DEFINED__
typedef struct IISApp3 IISApp3;
#endif

#ifndef __IISComputer_FWD_DEFINED__
#define __IISComputer_FWD_DEFINED__
typedef struct IISComputer IISComputer;
#endif

#ifndef __IISComputer2_FWD_DEFINED__
#define __IISComputer2_FWD_DEFINED__
typedef struct IISComputer2 IISComputer2;
#endif

#ifndef __IISExtComputer_FWD_DEFINED__
#define __IISExtComputer_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISExtComputer IISExtComputer;
#else
typedef struct IISExtComputer IISExtComputer;
#endif
#endif

#ifndef __IISExtApp_FWD_DEFINED__
#define __IISExtApp_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISExtApp IISExtApp;
#else
typedef struct IISExtApp IISExtApp;
#endif
#endif

#ifndef __IISExtServer_FWD_DEFINED__
#define __IISExtServer_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISExtServer IISExtServer;
#else
typedef struct IISExtServer IISExtServer;
#endif
#endif

#ifndef __IISExtDsCrMap_FWD_DEFINED__
#define __IISExtDsCrMap_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISExtDsCrMap IISExtDsCrMap;
#else
typedef struct IISExtDsCrMap IISExtDsCrMap;
#endif
#endif

#ifndef __IISExtApplicationPool_FWD_DEFINED__
#define __IISExtApplicationPool_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISExtApplicationPool IISExtApplicationPool;
#else
typedef struct IISExtApplicationPool IISExtApplicationPool;
#endif
#endif

#ifndef __IISExtApplicationPools_FWD_DEFINED__
#define __IISExtApplicationPools_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISExtApplicationPools IISExtApplicationPools;
#else
typedef struct IISExtApplicationPools IISExtApplicationPools;
#endif
#endif

#ifndef __IISExtWebService_FWD_DEFINED__
#define __IISExtWebService_FWD_DEFINED__
#ifdef __cplusplus
typedef class IISExtWebService IISExtWebService;
#else
typedef struct IISExtWebService IISExtWebService;
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

#ifndef __IISExt_LIBRARY_DEFINED__
#define __IISExt_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_IISExt;
#ifndef __IISApplicationPool_INTERFACE_DEFINED__
#define __IISApplicationPool_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISApplicationPool;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISApplicationPool : public IADs {
  public:
    virtual HRESULT WINAPI Recycle(void) = 0;
    virtual HRESULT WINAPI EnumAppsInPool(VARIANT *bstrBuffer) = 0;
    virtual HRESULT WINAPI Start(void) = 0;
    virtual HRESULT WINAPI Stop(void) = 0;
  };
#else
  typedef struct IISApplicationPoolVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISApplicationPool *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISApplicationPool *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISApplicationPool *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISApplicationPool *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISApplicationPool *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISApplicationPool *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISApplicationPool *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISApplicationPool *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISApplicationPool *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISApplicationPool *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISApplicationPool *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISApplicationPool *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISApplicationPool *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISApplicationPool *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISApplicationPool *This,void *retval);
      HRESULT (WINAPI *Get)(IISApplicationPool *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISApplicationPool *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISApplicationPool *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISApplicationPool *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISApplicationPool *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *Recycle)(IISApplicationPool *This);
      HRESULT (WINAPI *EnumAppsInPool)(IISApplicationPool *This,VARIANT *bstrBuffer);
      HRESULT (WINAPI *Start)(IISApplicationPool *This);
      HRESULT (WINAPI *Stop)(IISApplicationPool *This);
    END_INTERFACE
  } IISApplicationPoolVtbl;
  struct IISApplicationPool {
    CONST_VTBL struct IISApplicationPoolVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISApplicationPool_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISApplicationPool_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISApplicationPool_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISApplicationPool_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISApplicationPool_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISApplicationPool_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISApplicationPool_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISApplicationPool_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISApplicationPool_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISApplicationPool_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISApplicationPool_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISApplicationPool_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISApplicationPool_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISApplicationPool_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISApplicationPool_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISApplicationPool_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISApplicationPool_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISApplicationPool_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISApplicationPool_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISApplicationPool_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISApplicationPool_Recycle(This) (This)->lpVtbl->Recycle(This)
#define IISApplicationPool_EnumAppsInPool(This,bstrBuffer) (This)->lpVtbl->EnumAppsInPool(This,bstrBuffer)
#define IISApplicationPool_Start(This) (This)->lpVtbl->Start(This)
#define IISApplicationPool_Stop(This) (This)->lpVtbl->Stop(This)
#endif
#endif
  HRESULT WINAPI IISApplicationPool_Recycle_Proxy(IISApplicationPool *This);
  void __RPC_STUB IISApplicationPool_Recycle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApplicationPool_EnumAppsInPool_Proxy(IISApplicationPool *This,VARIANT *bstrBuffer);
  void __RPC_STUB IISApplicationPool_EnumAppsInPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApplicationPool_Start_Proxy(IISApplicationPool *This);
  void __RPC_STUB IISApplicationPool_Start_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApplicationPool_Stop_Proxy(IISApplicationPool *This);
  void __RPC_STUB IISApplicationPool_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISApplicationPools_INTERFACE_DEFINED__
#define __IISApplicationPools_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISApplicationPools;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISApplicationPools : public IADs {
  };
#else
  typedef struct IISApplicationPoolsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISApplicationPools *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISApplicationPools *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISApplicationPools *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISApplicationPools *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISApplicationPools *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISApplicationPools *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISApplicationPools *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISApplicationPools *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISApplicationPools *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISApplicationPools *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISApplicationPools *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISApplicationPools *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISApplicationPools *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISApplicationPools *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISApplicationPools *This,void *retval);
      HRESULT (WINAPI *Get)(IISApplicationPools *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISApplicationPools *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISApplicationPools *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISApplicationPools *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISApplicationPools *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
    END_INTERFACE
  } IISApplicationPoolsVtbl;
  struct IISApplicationPools {
    CONST_VTBL struct IISApplicationPoolsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISApplicationPools_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISApplicationPools_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISApplicationPools_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISApplicationPools_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISApplicationPools_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISApplicationPools_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISApplicationPools_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISApplicationPools_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISApplicationPools_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISApplicationPools_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISApplicationPools_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISApplicationPools_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISApplicationPools_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISApplicationPools_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISApplicationPools_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISApplicationPools_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISApplicationPools_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISApplicationPools_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISApplicationPools_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISApplicationPools_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#endif
#endif
#endif

#ifndef __IISWebService_INTERFACE_DEFINED__
#define __IISWebService_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISWebService;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISWebService : public IADs {
  public:
    virtual HRESULT WINAPI GetCurrentMode(VARIANT *pvServerMode) = 0;
    virtual HRESULT WINAPI CreateNewSite(BSTR bstrServerComment,VARIANT *pvServerBindings,BSTR bstrRootVDirPath,VARIANT vServerID,VARIANT *pvActualID) = 0;
    virtual HRESULT WINAPI EnableApplication(BSTR bstrAppName) = 0;
    virtual HRESULT WINAPI RemoveApplication(BSTR bstrAppName) = 0;
    virtual HRESULT WINAPI ListApplications(VARIANT *bstrBuffer) = 0;
    virtual HRESULT WINAPI AddDependency(BSTR bstrApplication,BSTR bstrGroupID) = 0;
    virtual HRESULT WINAPI RemoveDependency(BSTR bstrApplication,BSTR bstrGroupID) = 0;
    virtual HRESULT WINAPI EnableWebServiceExtension(BSTR bstrExtension) = 0;
    virtual HRESULT WINAPI DisableWebServiceExtension(BSTR bstrExtension) = 0;
    virtual HRESULT WINAPI ListWebServiceExtensions(VARIANT *bstrBuffer) = 0;
    virtual HRESULT WINAPI EnableExtensionFile(BSTR bstrExtensionFile) = 0;
    virtual HRESULT WINAPI DisableExtensionFile(BSTR bstrExtensionFile) = 0;
    virtual HRESULT WINAPI AddExtensionFile(BSTR bstrExtensionFile,VARIANT bAccess,BSTR bstrGroupID,VARIANT bCanDelete,BSTR bstrDescription) = 0;
    virtual HRESULT WINAPI DeleteExtensionFileRecord(BSTR bstrExtensionFile) = 0;
    virtual HRESULT WINAPI ListExtensionFiles(VARIANT *bstrBuffer) = 0;
    virtual HRESULT WINAPI QueryGroupIDStatus(BSTR bstrGroupID,VARIANT *bstrBuffer) = 0;
  };
#else
  typedef struct IISWebServiceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISWebService *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISWebService *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISWebService *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISWebService *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISWebService *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISWebService *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISWebService *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISWebService *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISWebService *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISWebService *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISWebService *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISWebService *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISWebService *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISWebService *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISWebService *This,void *retval);
      HRESULT (WINAPI *Get)(IISWebService *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISWebService *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISWebService *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISWebService *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISWebService *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *GetCurrentMode)(IISWebService *This,VARIANT *pvServerMode);
      HRESULT (WINAPI *CreateNewSite)(IISWebService *This,BSTR bstrServerComment,VARIANT *pvServerBindings,BSTR bstrRootVDirPath,VARIANT vServerID,VARIANT *pvActualID);
      HRESULT (WINAPI *EnableApplication)(IISWebService *This,BSTR bstrAppName);
      HRESULT (WINAPI *RemoveApplication)(IISWebService *This,BSTR bstrAppName);
      HRESULT (WINAPI *ListApplications)(IISWebService *This,VARIANT *bstrBuffer);
      HRESULT (WINAPI *AddDependency)(IISWebService *This,BSTR bstrApplication,BSTR bstrGroupID);
      HRESULT (WINAPI *RemoveDependency)(IISWebService *This,BSTR bstrApplication,BSTR bstrGroupID);
      HRESULT (WINAPI *EnableWebServiceExtension)(IISWebService *This,BSTR bstrExtension);
      HRESULT (WINAPI *DisableWebServiceExtension)(IISWebService *This,BSTR bstrExtension);
      HRESULT (WINAPI *ListWebServiceExtensions)(IISWebService *This,VARIANT *bstrBuffer);
      HRESULT (WINAPI *EnableExtensionFile)(IISWebService *This,BSTR bstrExtensionFile);
      HRESULT (WINAPI *DisableExtensionFile)(IISWebService *This,BSTR bstrExtensionFile);
      HRESULT (WINAPI *AddExtensionFile)(IISWebService *This,BSTR bstrExtensionFile,VARIANT bAccess,BSTR bstrGroupID,VARIANT bCanDelete,BSTR bstrDescription);
      HRESULT (WINAPI *DeleteExtensionFileRecord)(IISWebService *This,BSTR bstrExtensionFile);
      HRESULT (WINAPI *ListExtensionFiles)(IISWebService *This,VARIANT *bstrBuffer);
      HRESULT (WINAPI *QueryGroupIDStatus)(IISWebService *This,BSTR bstrGroupID,VARIANT *bstrBuffer);
    END_INTERFACE
  } IISWebServiceVtbl;
  struct IISWebService {
    CONST_VTBL struct IISWebServiceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISWebService_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISWebService_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISWebService_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISWebService_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISWebService_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISWebService_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISWebService_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISWebService_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISWebService_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISWebService_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISWebService_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISWebService_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISWebService_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISWebService_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISWebService_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISWebService_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISWebService_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISWebService_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISWebService_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISWebService_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISWebService_GetCurrentMode(This,pvServerMode) (This)->lpVtbl->GetCurrentMode(This,pvServerMode)
#define IISWebService_CreateNewSite(This,bstrServerComment,pvServerBindings,bstrRootVDirPath,vServerID,pvActualID) (This)->lpVtbl->CreateNewSite(This,bstrServerComment,pvServerBindings,bstrRootVDirPath,vServerID,pvActualID)
#define IISWebService_EnableApplication(This,bstrAppName) (This)->lpVtbl->EnableApplication(This,bstrAppName)
#define IISWebService_RemoveApplication(This,bstrAppName) (This)->lpVtbl->RemoveApplication(This,bstrAppName)
#define IISWebService_ListApplications(This,bstrBuffer) (This)->lpVtbl->ListApplications(This,bstrBuffer)
#define IISWebService_AddDependency(This,bstrApplication,bstrGroupID) (This)->lpVtbl->AddDependency(This,bstrApplication,bstrGroupID)
#define IISWebService_RemoveDependency(This,bstrApplication,bstrGroupID) (This)->lpVtbl->RemoveDependency(This,bstrApplication,bstrGroupID)
#define IISWebService_EnableWebServiceExtension(This,bstrExtension) (This)->lpVtbl->EnableWebServiceExtension(This,bstrExtension)
#define IISWebService_DisableWebServiceExtension(This,bstrExtension) (This)->lpVtbl->DisableWebServiceExtension(This,bstrExtension)
#define IISWebService_ListWebServiceExtensions(This,bstrBuffer) (This)->lpVtbl->ListWebServiceExtensions(This,bstrBuffer)
#define IISWebService_EnableExtensionFile(This,bstrExtensionFile) (This)->lpVtbl->EnableExtensionFile(This,bstrExtensionFile)
#define IISWebService_DisableExtensionFile(This,bstrExtensionFile) (This)->lpVtbl->DisableExtensionFile(This,bstrExtensionFile)
#define IISWebService_AddExtensionFile(This,bstrExtensionFile,bAccess,bstrGroupID,bCanDelete,bstrDescription) (This)->lpVtbl->AddExtensionFile(This,bstrExtensionFile,bAccess,bstrGroupID,bCanDelete,bstrDescription)
#define IISWebService_DeleteExtensionFileRecord(This,bstrExtensionFile) (This)->lpVtbl->DeleteExtensionFileRecord(This,bstrExtensionFile)
#define IISWebService_ListExtensionFiles(This,bstrBuffer) (This)->lpVtbl->ListExtensionFiles(This,bstrBuffer)
#define IISWebService_QueryGroupIDStatus(This,bstrGroupID,bstrBuffer) (This)->lpVtbl->QueryGroupIDStatus(This,bstrGroupID,bstrBuffer)
#endif
#endif
  HRESULT WINAPI IISWebService_GetCurrentMode_Proxy(IISWebService *This,VARIANT *pvServerMode);
  void __RPC_STUB IISWebService_GetCurrentMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_CreateNewSite_Proxy(IISWebService *This,BSTR bstrServerComment,VARIANT *pvServerBindings,BSTR bstrRootVDirPath,VARIANT vServerID,VARIANT *pvActualID);
  void __RPC_STUB IISWebService_CreateNewSite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_EnableApplication_Proxy(IISWebService *This,BSTR bstrAppName);
  void __RPC_STUB IISWebService_EnableApplication_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_RemoveApplication_Proxy(IISWebService *This,BSTR bstrAppName);
  void __RPC_STUB IISWebService_RemoveApplication_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_ListApplications_Proxy(IISWebService *This,VARIANT *bstrBuffer);
  void __RPC_STUB IISWebService_ListApplications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_AddDependency_Proxy(IISWebService *This,BSTR bstrApplication,BSTR bstrGroupID);
  void __RPC_STUB IISWebService_AddDependency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_RemoveDependency_Proxy(IISWebService *This,BSTR bstrApplication,BSTR bstrGroupID);
  void __RPC_STUB IISWebService_RemoveDependency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_EnableWebServiceExtension_Proxy(IISWebService *This,BSTR bstrExtension);
  void __RPC_STUB IISWebService_EnableWebServiceExtension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_DisableWebServiceExtension_Proxy(IISWebService *This,BSTR bstrExtension);
  void __RPC_STUB IISWebService_DisableWebServiceExtension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_ListWebServiceExtensions_Proxy(IISWebService *This,VARIANT *bstrBuffer);
  void __RPC_STUB IISWebService_ListWebServiceExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_EnableExtensionFile_Proxy(IISWebService *This,BSTR bstrExtensionFile);
  void __RPC_STUB IISWebService_EnableExtensionFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_DisableExtensionFile_Proxy(IISWebService *This,BSTR bstrExtensionFile);
  void __RPC_STUB IISWebService_DisableExtensionFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_AddExtensionFile_Proxy(IISWebService *This,BSTR bstrExtensionFile,VARIANT bAccess,BSTR bstrGroupID,VARIANT bCanDelete,BSTR bstrDescription);
  void __RPC_STUB IISWebService_AddExtensionFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_DeleteExtensionFileRecord_Proxy(IISWebService *This,BSTR bstrExtensionFile);
  void __RPC_STUB IISWebService_DeleteExtensionFileRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_ListExtensionFiles_Proxy(IISWebService *This,VARIANT *bstrBuffer);
  void __RPC_STUB IISWebService_ListExtensionFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISWebService_QueryGroupIDStatus_Proxy(IISWebService *This,BSTR bstrGroupID,VARIANT *bstrBuffer);
  void __RPC_STUB IISWebService_QueryGroupIDStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISDsCrMap_INTERFACE_DEFINED__
#define __IISDsCrMap_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISDsCrMap;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISDsCrMap : public IADs {
  public:
    virtual HRESULT WINAPI CreateMapping(VARIANT vCert,BSTR bstrNtAcct,BSTR bstrNtPwd,BSTR bstrName,LONG lEnabled) = 0;
    virtual HRESULT WINAPI GetMapping(LONG lMethod,VARIANT vKey,VARIANT *pvCert,VARIANT *pbstrNtAcct,VARIANT *pbstrNtPwd,VARIANT *pbstrName,VARIANT *plEnabled) = 0;
    virtual HRESULT WINAPI DeleteMapping(LONG lMethod,VARIANT vKey) = 0;
    virtual HRESULT WINAPI SetEnabled(LONG lMethod,VARIANT vKey,LONG lEnabled) = 0;
    virtual HRESULT WINAPI SetName(LONG lMethod,VARIANT vKey,BSTR bstrName) = 0;
    virtual HRESULT WINAPI SetPwd(LONG lMethod,VARIANT vKey,BSTR bstrPwd) = 0;
    virtual HRESULT WINAPI SetAcct(LONG lMethod,VARIANT vKey,BSTR bstrAcct) = 0;
  };
#else
  typedef struct IISDsCrMapVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISDsCrMap *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISDsCrMap *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISDsCrMap *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISDsCrMap *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISDsCrMap *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISDsCrMap *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISDsCrMap *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISDsCrMap *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISDsCrMap *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISDsCrMap *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISDsCrMap *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISDsCrMap *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISDsCrMap *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISDsCrMap *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISDsCrMap *This,void *retval);
      HRESULT (WINAPI *Get)(IISDsCrMap *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISDsCrMap *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISDsCrMap *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISDsCrMap *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISDsCrMap *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *CreateMapping)(IISDsCrMap *This,VARIANT vCert,BSTR bstrNtAcct,BSTR bstrNtPwd,BSTR bstrName,LONG lEnabled);
      HRESULT (WINAPI *GetMapping)(IISDsCrMap *This,LONG lMethod,VARIANT vKey,VARIANT *pvCert,VARIANT *pbstrNtAcct,VARIANT *pbstrNtPwd,VARIANT *pbstrName,VARIANT *plEnabled);
      HRESULT (WINAPI *DeleteMapping)(IISDsCrMap *This,LONG lMethod,VARIANT vKey);
      HRESULT (WINAPI *SetEnabled)(IISDsCrMap *This,LONG lMethod,VARIANT vKey,LONG lEnabled);
      HRESULT (WINAPI *SetName)(IISDsCrMap *This,LONG lMethod,VARIANT vKey,BSTR bstrName);
      HRESULT (WINAPI *SetPwd)(IISDsCrMap *This,LONG lMethod,VARIANT vKey,BSTR bstrPwd);
      HRESULT (WINAPI *SetAcct)(IISDsCrMap *This,LONG lMethod,VARIANT vKey,BSTR bstrAcct);
    END_INTERFACE
  } IISDsCrMapVtbl;
  struct IISDsCrMap {
    CONST_VTBL struct IISDsCrMapVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISDsCrMap_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISDsCrMap_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISDsCrMap_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISDsCrMap_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISDsCrMap_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISDsCrMap_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISDsCrMap_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISDsCrMap_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISDsCrMap_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISDsCrMap_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISDsCrMap_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISDsCrMap_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISDsCrMap_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISDsCrMap_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISDsCrMap_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISDsCrMap_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISDsCrMap_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISDsCrMap_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISDsCrMap_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISDsCrMap_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISDsCrMap_CreateMapping(This,vCert,bstrNtAcct,bstrNtPwd,bstrName,lEnabled) (This)->lpVtbl->CreateMapping(This,vCert,bstrNtAcct,bstrNtPwd,bstrName,lEnabled)
#define IISDsCrMap_GetMapping(This,lMethod,vKey,pvCert,pbstrNtAcct,pbstrNtPwd,pbstrName,plEnabled) (This)->lpVtbl->GetMapping(This,lMethod,vKey,pvCert,pbstrNtAcct,pbstrNtPwd,pbstrName,plEnabled)
#define IISDsCrMap_DeleteMapping(This,lMethod,vKey) (This)->lpVtbl->DeleteMapping(This,lMethod,vKey)
#define IISDsCrMap_SetEnabled(This,lMethod,vKey,lEnabled) (This)->lpVtbl->SetEnabled(This,lMethod,vKey,lEnabled)
#define IISDsCrMap_SetName(This,lMethod,vKey,bstrName) (This)->lpVtbl->SetName(This,lMethod,vKey,bstrName)
#define IISDsCrMap_SetPwd(This,lMethod,vKey,bstrPwd) (This)->lpVtbl->SetPwd(This,lMethod,vKey,bstrPwd)
#define IISDsCrMap_SetAcct(This,lMethod,vKey,bstrAcct) (This)->lpVtbl->SetAcct(This,lMethod,vKey,bstrAcct)
#endif
#endif
  HRESULT WINAPI IISDsCrMap_CreateMapping_Proxy(IISDsCrMap *This,VARIANT vCert,BSTR bstrNtAcct,BSTR bstrNtPwd,BSTR bstrName,LONG lEnabled);
  void __RPC_STUB IISDsCrMap_CreateMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISDsCrMap_GetMapping_Proxy(IISDsCrMap *This,LONG lMethod,VARIANT vKey,VARIANT *pvCert,VARIANT *pbstrNtAcct,VARIANT *pbstrNtPwd,VARIANT *pbstrName,VARIANT *plEnabled);
  void __RPC_STUB IISDsCrMap_GetMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISDsCrMap_DeleteMapping_Proxy(IISDsCrMap *This,LONG lMethod,VARIANT vKey);
  void __RPC_STUB IISDsCrMap_DeleteMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISDsCrMap_SetEnabled_Proxy(IISDsCrMap *This,LONG lMethod,VARIANT vKey,LONG lEnabled);
  void __RPC_STUB IISDsCrMap_SetEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISDsCrMap_SetName_Proxy(IISDsCrMap *This,LONG lMethod,VARIANT vKey,BSTR bstrName);
  void __RPC_STUB IISDsCrMap_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISDsCrMap_SetPwd_Proxy(IISDsCrMap *This,LONG lMethod,VARIANT vKey,BSTR bstrPwd);
  void __RPC_STUB IISDsCrMap_SetPwd_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISDsCrMap_SetAcct_Proxy(IISDsCrMap *This,LONG lMethod,VARIANT vKey,BSTR bstrAcct);
  void __RPC_STUB IISDsCrMap_SetAcct_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISApp_INTERFACE_DEFINED__
#define __IISApp_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISApp;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISApp : public IADs {
  public:
    virtual HRESULT WINAPI AppCreate(VARIANT_BOOL bSetInProcFlag) = 0;
    virtual HRESULT WINAPI AppDelete(void) = 0;
    virtual HRESULT WINAPI AppDeleteRecursive(void) = 0;
    virtual HRESULT WINAPI AppUnLoad(void) = 0;
    virtual HRESULT WINAPI AppUnLoadRecursive(void) = 0;
    virtual HRESULT WINAPI AppDisable(void) = 0;
    virtual HRESULT WINAPI AppDisableRecursive(void) = 0;
    virtual HRESULT WINAPI AppEnable(void) = 0;
    virtual HRESULT WINAPI AppEnableRecursive(void) = 0;
    virtual HRESULT WINAPI AppGetStatus(DWORD *pdwStatus) = 0;
    virtual HRESULT WINAPI AspAppRestart(void) = 0;
  };
#else
  typedef struct IISAppVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISApp *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISApp *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISApp *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISApp *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISApp *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISApp *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISApp *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISApp *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISApp *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISApp *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISApp *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISApp *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISApp *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISApp *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISApp *This,void *retval);
      HRESULT (WINAPI *Get)(IISApp *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISApp *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISApp *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISApp *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISApp *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *AppCreate)(IISApp *This,VARIANT_BOOL bSetInProcFlag);
      HRESULT (WINAPI *AppDelete)(IISApp *This);
      HRESULT (WINAPI *AppDeleteRecursive)(IISApp *This);
      HRESULT (WINAPI *AppUnLoad)(IISApp *This);
      HRESULT (WINAPI *AppUnLoadRecursive)(IISApp *This);
      HRESULT (WINAPI *AppDisable)(IISApp *This);
      HRESULT (WINAPI *AppDisableRecursive)(IISApp *This);
      HRESULT (WINAPI *AppEnable)(IISApp *This);
      HRESULT (WINAPI *AppEnableRecursive)(IISApp *This);
      HRESULT (WINAPI *AppGetStatus)(IISApp *This,DWORD *pdwStatus);
      HRESULT (WINAPI *AspAppRestart)(IISApp *This);
    END_INTERFACE
  } IISAppVtbl;
  struct IISApp {
    CONST_VTBL struct IISAppVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISApp_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISApp_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISApp_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISApp_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISApp_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISApp_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISApp_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISApp_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISApp_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISApp_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISApp_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISApp_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISApp_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISApp_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISApp_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISApp_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISApp_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISApp_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISApp_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISApp_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISApp_AppCreate(This,bSetInProcFlag) (This)->lpVtbl->AppCreate(This,bSetInProcFlag)
#define IISApp_AppDelete(This) (This)->lpVtbl->AppDelete(This)
#define IISApp_AppDeleteRecursive(This) (This)->lpVtbl->AppDeleteRecursive(This)
#define IISApp_AppUnLoad(This) (This)->lpVtbl->AppUnLoad(This)
#define IISApp_AppUnLoadRecursive(This) (This)->lpVtbl->AppUnLoadRecursive(This)
#define IISApp_AppDisable(This) (This)->lpVtbl->AppDisable(This)
#define IISApp_AppDisableRecursive(This) (This)->lpVtbl->AppDisableRecursive(This)
#define IISApp_AppEnable(This) (This)->lpVtbl->AppEnable(This)
#define IISApp_AppEnableRecursive(This) (This)->lpVtbl->AppEnableRecursive(This)
#define IISApp_AppGetStatus(This,pdwStatus) (This)->lpVtbl->AppGetStatus(This,pdwStatus)
#define IISApp_AspAppRestart(This) (This)->lpVtbl->AspAppRestart(This)
#endif
#endif
  HRESULT WINAPI IISApp_AppCreate_Proxy(IISApp *This,VARIANT_BOOL bSetInProcFlag);
  void __RPC_STUB IISApp_AppCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppDelete_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppDelete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppDeleteRecursive_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppDeleteRecursive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppUnLoad_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppUnLoad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppUnLoadRecursive_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppUnLoadRecursive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppDisable_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppDisable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppDisableRecursive_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppDisableRecursive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppEnable_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppEnable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppEnableRecursive_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AppEnableRecursive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AppGetStatus_Proxy(IISApp *This,DWORD *pdwStatus);
  void __RPC_STUB IISApp_AppGetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp_AspAppRestart_Proxy(IISApp *This);
  void __RPC_STUB IISApp_AspAppRestart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISApp2_INTERFACE_DEFINED__
#define __IISApp2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISApp2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISApp2 : public IISApp {
  public:
    virtual HRESULT WINAPI AppCreate2(LONG lAppMode) = 0;
    virtual HRESULT WINAPI AppGetStatus2(LONG *lpStatus) = 0;
  };
#else
  typedef struct IISApp2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISApp2 *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISApp2 *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISApp2 *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISApp2 *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISApp2 *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISApp2 *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISApp2 *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISApp2 *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISApp2 *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISApp2 *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISApp2 *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISApp2 *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISApp2 *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISApp2 *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISApp2 *This,void *retval);
      HRESULT (WINAPI *Get)(IISApp2 *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISApp2 *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISApp2 *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISApp2 *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISApp2 *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *AppCreate)(IISApp2 *This,VARIANT_BOOL bSetInProcFlag);
      HRESULT (WINAPI *AppDelete)(IISApp2 *This);
      HRESULT (WINAPI *AppDeleteRecursive)(IISApp2 *This);
      HRESULT (WINAPI *AppUnLoad)(IISApp2 *This);
      HRESULT (WINAPI *AppUnLoadRecursive)(IISApp2 *This);
      HRESULT (WINAPI *AppDisable)(IISApp2 *This);
      HRESULT (WINAPI *AppDisableRecursive)(IISApp2 *This);
      HRESULT (WINAPI *AppEnable)(IISApp2 *This);
      HRESULT (WINAPI *AppEnableRecursive)(IISApp2 *This);
      HRESULT (WINAPI *AppGetStatus)(IISApp2 *This,DWORD *pdwStatus);
      HRESULT (WINAPI *AspAppRestart)(IISApp2 *This);
      HRESULT (WINAPI *AppCreate2)(IISApp2 *This,LONG lAppMode);
      HRESULT (WINAPI *AppGetStatus2)(IISApp2 *This,LONG *lpStatus);
    END_INTERFACE
  } IISApp2Vtbl;
  struct IISApp2 {
    CONST_VTBL struct IISApp2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISApp2_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISApp2_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISApp2_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISApp2_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISApp2_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISApp2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISApp2_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISApp2_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISApp2_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISApp2_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISApp2_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISApp2_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISApp2_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISApp2_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISApp2_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISApp2_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISApp2_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISApp2_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISApp2_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISApp2_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISApp2_AppCreate(This,bSetInProcFlag) (This)->lpVtbl->AppCreate(This,bSetInProcFlag)
#define IISApp2_AppDelete(This) (This)->lpVtbl->AppDelete(This)
#define IISApp2_AppDeleteRecursive(This) (This)->lpVtbl->AppDeleteRecursive(This)
#define IISApp2_AppUnLoad(This) (This)->lpVtbl->AppUnLoad(This)
#define IISApp2_AppUnLoadRecursive(This) (This)->lpVtbl->AppUnLoadRecursive(This)
#define IISApp2_AppDisable(This) (This)->lpVtbl->AppDisable(This)
#define IISApp2_AppDisableRecursive(This) (This)->lpVtbl->AppDisableRecursive(This)
#define IISApp2_AppEnable(This) (This)->lpVtbl->AppEnable(This)
#define IISApp2_AppEnableRecursive(This) (This)->lpVtbl->AppEnableRecursive(This)
#define IISApp2_AppGetStatus(This,pdwStatus) (This)->lpVtbl->AppGetStatus(This,pdwStatus)
#define IISApp2_AspAppRestart(This) (This)->lpVtbl->AspAppRestart(This)
#define IISApp2_AppCreate2(This,lAppMode) (This)->lpVtbl->AppCreate2(This,lAppMode)
#define IISApp2_AppGetStatus2(This,lpStatus) (This)->lpVtbl->AppGetStatus2(This,lpStatus)
#endif
#endif
  HRESULT WINAPI IISApp2_AppCreate2_Proxy(IISApp2 *This,LONG lAppMode);
  void __RPC_STUB IISApp2_AppCreate2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISApp2_AppGetStatus2_Proxy(IISApp2 *This,LONG *lpStatus);
  void __RPC_STUB IISApp2_AppGetStatus2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISApp3_INTERFACE_DEFINED__
#define __IISApp3_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISApp3;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISApp3 : public IISApp2 {
  public:
    virtual HRESULT WINAPI AppCreate3(LONG lAppMode,VARIANT bstrAppPooI,VARIANT bCreatePool) = 0;
  };
#else
  typedef struct IISApp3Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISApp3 *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISApp3 *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISApp3 *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISApp3 *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISApp3 *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISApp3 *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISApp3 *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISApp3 *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISApp3 *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISApp3 *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISApp3 *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISApp3 *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISApp3 *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISApp3 *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISApp3 *This,void *retval);
      HRESULT (WINAPI *Get)(IISApp3 *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISApp3 *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISApp3 *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISApp3 *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISApp3 *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *AppCreate)(IISApp3 *This,VARIANT_BOOL bSetInProcFlag);
      HRESULT (WINAPI *AppDelete)(IISApp3 *This);
      HRESULT (WINAPI *AppDeleteRecursive)(IISApp3 *This);
      HRESULT (WINAPI *AppUnLoad)(IISApp3 *This);
      HRESULT (WINAPI *AppUnLoadRecursive)(IISApp3 *This);
      HRESULT (WINAPI *AppDisable)(IISApp3 *This);
      HRESULT (WINAPI *AppDisableRecursive)(IISApp3 *This);
      HRESULT (WINAPI *AppEnable)(IISApp3 *This);
      HRESULT (WINAPI *AppEnableRecursive)(IISApp3 *This);
      HRESULT (WINAPI *AppGetStatus)(IISApp3 *This,DWORD *pdwStatus);
      HRESULT (WINAPI *AspAppRestart)(IISApp3 *This);
      HRESULT (WINAPI *AppCreate2)(IISApp3 *This,LONG lAppMode);
      HRESULT (WINAPI *AppGetStatus2)(IISApp3 *This,LONG *lpStatus);
      HRESULT (WINAPI *AppCreate3)(IISApp3 *This,LONG lAppMode,VARIANT bstrAppPooI,VARIANT bCreatePool);
    END_INTERFACE
  } IISApp3Vtbl;
  struct IISApp3 {
    CONST_VTBL struct IISApp3Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISApp3_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISApp3_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISApp3_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISApp3_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISApp3_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISApp3_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISApp3_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISApp3_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISApp3_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISApp3_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISApp3_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISApp3_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISApp3_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISApp3_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISApp3_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISApp3_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISApp3_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISApp3_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISApp3_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISApp3_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISApp3_AppCreate(This,bSetInProcFlag) (This)->lpVtbl->AppCreate(This,bSetInProcFlag)
#define IISApp3_AppDelete(This) (This)->lpVtbl->AppDelete(This)
#define IISApp3_AppDeleteRecursive(This) (This)->lpVtbl->AppDeleteRecursive(This)
#define IISApp3_AppUnLoad(This) (This)->lpVtbl->AppUnLoad(This)
#define IISApp3_AppUnLoadRecursive(This) (This)->lpVtbl->AppUnLoadRecursive(This)
#define IISApp3_AppDisable(This) (This)->lpVtbl->AppDisable(This)
#define IISApp3_AppDisableRecursive(This) (This)->lpVtbl->AppDisableRecursive(This)
#define IISApp3_AppEnable(This) (This)->lpVtbl->AppEnable(This)
#define IISApp3_AppEnableRecursive(This) (This)->lpVtbl->AppEnableRecursive(This)
#define IISApp3_AppGetStatus(This,pdwStatus) (This)->lpVtbl->AppGetStatus(This,pdwStatus)
#define IISApp3_AspAppRestart(This) (This)->lpVtbl->AspAppRestart(This)
#define IISApp3_AppCreate2(This,lAppMode) (This)->lpVtbl->AppCreate2(This,lAppMode)
#define IISApp3_AppGetStatus2(This,lpStatus) (This)->lpVtbl->AppGetStatus2(This,lpStatus)
#define IISApp3_AppCreate3(This,lAppMode,bstrAppPooI,bCreatePool) (This)->lpVtbl->AppCreate3(This,lAppMode,bstrAppPooI,bCreatePool)
#endif
#endif
  HRESULT WINAPI IISApp3_AppCreate3_Proxy(IISApp3 *This,LONG lAppMode,VARIANT bstrAppPooI,VARIANT bCreatePool);
  void __RPC_STUB IISApp3_AppCreate3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISComputer_INTERFACE_DEFINED__
#define __IISComputer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISComputer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISComputer : public IADs {
  public:
    virtual HRESULT WINAPI Backup(BSTR bstrLocation,LONG lVersion,LONG lFlags) = 0;
    virtual HRESULT WINAPI Restore(BSTR bstrLocation,LONG lVersion,LONG lFlags) = 0;
    virtual HRESULT WINAPI EnumBackups(BSTR bstrLocation,LONG lIndex,VARIANT *pvVersion,VARIANT *pvLocations,VARIANT *pvDate) = 0;
    virtual HRESULT WINAPI DeleteBackup(BSTR bstrLocation,LONG lVersion) = 0;
  };
#else
  typedef struct IISComputerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISComputer *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISComputer *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISComputer *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISComputer *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISComputer *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISComputer *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISComputer *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISComputer *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISComputer *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISComputer *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISComputer *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISComputer *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISComputer *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISComputer *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISComputer *This,void *retval);
      HRESULT (WINAPI *Get)(IISComputer *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISComputer *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISComputer *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISComputer *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISComputer *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *Backup)(IISComputer *This,BSTR bstrLocation,LONG lVersion,LONG lFlags);
      HRESULT (WINAPI *Restore)(IISComputer *This,BSTR bstrLocation,LONG lVersion,LONG lFlags);
      HRESULT (WINAPI *EnumBackups)(IISComputer *This,BSTR bstrLocation,LONG lIndex,VARIANT *pvVersion,VARIANT *pvLocations,VARIANT *pvDate);
      HRESULT (WINAPI *DeleteBackup)(IISComputer *This,BSTR bstrLocation,LONG lVersion);
    END_INTERFACE
  } IISComputerVtbl;
  struct IISComputer {
    CONST_VTBL struct IISComputerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISComputer_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISComputer_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISComputer_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISComputer_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISComputer_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISComputer_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISComputer_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISComputer_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISComputer_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISComputer_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISComputer_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISComputer_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISComputer_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISComputer_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISComputer_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISComputer_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISComputer_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISComputer_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISComputer_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISComputer_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISComputer_Backup(This,bstrLocation,lVersion,lFlags) (This)->lpVtbl->Backup(This,bstrLocation,lVersion,lFlags)
#define IISComputer_Restore(This,bstrLocation,lVersion,lFlags) (This)->lpVtbl->Restore(This,bstrLocation,lVersion,lFlags)
#define IISComputer_EnumBackups(This,bstrLocation,lIndex,pvVersion,pvLocations,pvDate) (This)->lpVtbl->EnumBackups(This,bstrLocation,lIndex,pvVersion,pvLocations,pvDate)
#define IISComputer_DeleteBackup(This,bstrLocation,lVersion) (This)->lpVtbl->DeleteBackup(This,bstrLocation,lVersion)
#endif
#endif
  HRESULT WINAPI IISComputer_Backup_Proxy(IISComputer *This,BSTR bstrLocation,LONG lVersion,LONG lFlags);
  void __RPC_STUB IISComputer_Backup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISComputer_Restore_Proxy(IISComputer *This,BSTR bstrLocation,LONG lVersion,LONG lFlags);
  void __RPC_STUB IISComputer_Restore_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISComputer_EnumBackups_Proxy(IISComputer *This,BSTR bstrLocation,LONG lIndex,VARIANT *pvVersion,VARIANT *pvLocations,VARIANT *pvDate);
  void __RPC_STUB IISComputer_EnumBackups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISComputer_DeleteBackup_Proxy(IISComputer *This,BSTR bstrLocation,LONG lVersion);
  void __RPC_STUB IISComputer_DeleteBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IISComputer2_INTERFACE_DEFINED__
#define __IISComputer2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IISComputer2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IISComputer2 : public IISComputer {
  public:
    virtual HRESULT WINAPI BackupWithPassword(BSTR bstrLocation,LONG lVersion,LONG lFlags,BSTR bstrPassword) = 0;
    virtual HRESULT WINAPI RestoreWithPassword(BSTR bstrLocation,LONG lVersion,LONG lFlags,BSTR bstrPassword) = 0;
    virtual HRESULT WINAPI Export(BSTR bstrPassword,BSTR bstrFilename,BSTR bstrSourcePath,LONG lFlags) = 0;
    virtual HRESULT WINAPI Import(BSTR bstrPassword,BSTR bstrFilename,BSTR bstrSourcePath,BSTR bstrDestPath,LONG lFlags) = 0;
    virtual HRESULT WINAPI SaveData(void) = 0;
  };
#else
  typedef struct IISComputer2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IISComputer2 *This,struct GUID *riid,void **ppvObj,void *retval);
      HRESULT (WINAPI *AddRef)(IISComputer2 *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *Release)(IISComputer2 *This,unsigned __LONG32 *retval);
      HRESULT (WINAPI *GetTypeInfoCount)(IISComputer2 *This,unsigned UINT *pctinfo,void *retval);
      HRESULT (WINAPI *GetTypeInfo)(IISComputer2 *This,unsigned UINT itinfo,unsigned __LONG32 lcid,void **pptinfo,void *retval);
      HRESULT (WINAPI *GetIDsOfNames)(IISComputer2 *This,struct GUID *riid,signed char **rgszNames,unsigned UINT cNames,unsigned __LONG32 lcid,signed __LONG32 *rgdispid,void *retval);
      HRESULT (WINAPI *Invoke)(IISComputer2 *This,signed __LONG32 dispidMember,struct GUID *riid,unsigned __LONG32 lcid,unsigned short wFlags,struct DISPPARAMS *pdispparams,VARIANT *pvarResult,struct EXCEPINFO *pexcepinfo,unsigned UINT *puArgErr,void *retval);
      HRESULT (WINAPI *get_Name)(IISComputer2 *This,BSTR *retval);
      HRESULT (WINAPI *get_Class)(IISComputer2 *This,BSTR *retval);
      HRESULT (WINAPI *get_GUID)(IISComputer2 *This,BSTR *retval);
      HRESULT (WINAPI *get_ADsPath)(IISComputer2 *This,BSTR *retval);
      HRESULT (WINAPI *get_Parent)(IISComputer2 *This,BSTR *retval);
      HRESULT (WINAPI *get_Schema)(IISComputer2 *This,BSTR *retval);
      HRESULT (WINAPI *GetInfo)(IISComputer2 *This,void *retval);
      HRESULT (WINAPI *SetInfo)(IISComputer2 *This,void *retval);
      HRESULT (WINAPI *Get)(IISComputer2 *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *Put)(IISComputer2 *This,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetEx)(IISComputer2 *This,BSTR bstrName,VARIANT *retval);
      HRESULT (WINAPI *PutEx)(IISComputer2 *This,signed __LONG32 lnControlCode,BSTR bstrName,VARIANT vProp,void *retval);
      HRESULT (WINAPI *GetInfoEx)(IISComputer2 *This,VARIANT vProperties,signed __LONG32 lnReserved,void *retval);
      HRESULT (WINAPI *Backup)(IISComputer2 *This,BSTR bstrLocation,LONG lVersion,LONG lFlags);
      HRESULT (WINAPI *Restore)(IISComputer2 *This,BSTR bstrLocation,LONG lVersion,LONG lFlags);
      HRESULT (WINAPI *EnumBackups)(IISComputer2 *This,BSTR bstrLocation,LONG lIndex,VARIANT *pvVersion,VARIANT *pvLocations,VARIANT *pvDate);
      HRESULT (WINAPI *DeleteBackup)(IISComputer2 *This,BSTR bstrLocation,LONG lVersion);
      HRESULT (WINAPI *BackupWithPassword)(IISComputer2 *This,BSTR bstrLocation,LONG lVersion,LONG lFlags,BSTR bstrPassword);
      HRESULT (WINAPI *RestoreWithPassword)(IISComputer2 *This,BSTR bstrLocation,LONG lVersion,LONG lFlags,BSTR bstrPassword);
      HRESULT (WINAPI *Export)(IISComputer2 *This,BSTR bstrPassword,BSTR bstrFilename,BSTR bstrSourcePath,LONG lFlags);
      HRESULT (WINAPI *Import)(IISComputer2 *This,BSTR bstrPassword,BSTR bstrFilename,BSTR bstrSourcePath,BSTR bstrDestPath,LONG lFlags);
      HRESULT (WINAPI *SaveData)(IISComputer2 *This);
    END_INTERFACE
  } IISComputer2Vtbl;
  struct IISComputer2 {
    CONST_VTBL struct IISComputer2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IISComputer2_QueryInterface(This,riid,ppvObj,retval) (This)->lpVtbl->QueryInterface(This,riid,ppvObj,retval)
#define IISComputer2_AddRef(This,retval) (This)->lpVtbl->AddRef(This,retval)
#define IISComputer2_Release(This,retval) (This)->lpVtbl->Release(This,retval)
#define IISComputer2_GetTypeInfoCount(This,pctinfo,retval) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo,retval)
#define IISComputer2_GetTypeInfo(This,itinfo,lcid,pptinfo,retval) (This)->lpVtbl->GetTypeInfo(This,itinfo,lcid,pptinfo,retval)
#define IISComputer2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgdispid,retval)
#define IISComputer2_Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval) (This)->lpVtbl->Invoke(This,dispidMember,riid,lcid,wFlags,pdispparams,pvarResult,pexcepinfo,puArgErr,retval)
#define IISComputer2_get_Name(This,retval) (This)->lpVtbl->get_Name(This,retval)
#define IISComputer2_get_Class(This,retval) (This)->lpVtbl->get_Class(This,retval)
#define IISComputer2_get_GUID(This,retval) (This)->lpVtbl->get_GUID(This,retval)
#define IISComputer2_get_ADsPath(This,retval) (This)->lpVtbl->get_ADsPath(This,retval)
#define IISComputer2_get_Parent(This,retval) (This)->lpVtbl->get_Parent(This,retval)
#define IISComputer2_get_Schema(This,retval) (This)->lpVtbl->get_Schema(This,retval)
#define IISComputer2_GetInfo(This,retval) (This)->lpVtbl->GetInfo(This,retval)
#define IISComputer2_SetInfo(This,retval) (This)->lpVtbl->SetInfo(This,retval)
#define IISComputer2_Get(This,bstrName,retval) (This)->lpVtbl->Get(This,bstrName,retval)
#define IISComputer2_Put(This,bstrName,vProp,retval) (This)->lpVtbl->Put(This,bstrName,vProp,retval)
#define IISComputer2_GetEx(This,bstrName,retval) (This)->lpVtbl->GetEx(This,bstrName,retval)
#define IISComputer2_PutEx(This,lnControlCode,bstrName,vProp,retval) (This)->lpVtbl->PutEx(This,lnControlCode,bstrName,vProp,retval)
#define IISComputer2_GetInfoEx(This,vProperties,lnReserved,retval) (This)->lpVtbl->GetInfoEx(This,vProperties,lnReserved,retval)
#define IISComputer2_Backup(This,bstrLocation,lVersion,lFlags) (This)->lpVtbl->Backup(This,bstrLocation,lVersion,lFlags)
#define IISComputer2_Restore(This,bstrLocation,lVersion,lFlags) (This)->lpVtbl->Restore(This,bstrLocation,lVersion,lFlags)
#define IISComputer2_EnumBackups(This,bstrLocation,lIndex,pvVersion,pvLocations,pvDate) (This)->lpVtbl->EnumBackups(This,bstrLocation,lIndex,pvVersion,pvLocations,pvDate)
#define IISComputer2_DeleteBackup(This,bstrLocation,lVersion) (This)->lpVtbl->DeleteBackup(This,bstrLocation,lVersion)
#define IISComputer2_BackupWithPassword(This,bstrLocation,lVersion,lFlags,bstrPassword) (This)->lpVtbl->BackupWithPassword(This,bstrLocation,lVersion,lFlags,bstrPassword)
#define IISComputer2_RestoreWithPassword(This,bstrLocation,lVersion,lFlags,bstrPassword) (This)->lpVtbl->RestoreWithPassword(This,bstrLocation,lVersion,lFlags,bstrPassword)
#define IISComputer2_Export(This,bstrPassword,bstrFilename,bstrSourcePath,lFlags) (This)->lpVtbl->Export(This,bstrPassword,bstrFilename,bstrSourcePath,lFlags)
#define IISComputer2_Import(This,bstrPassword,bstrFilename,bstrSourcePath,bstrDestPath,lFlags) (This)->lpVtbl->Import(This,bstrPassword,bstrFilename,bstrSourcePath,bstrDestPath,lFlags)
#define IISComputer2_SaveData(This) (This)->lpVtbl->SaveData(This)
#endif
#endif
  HRESULT WINAPI IISComputer2_BackupWithPassword_Proxy(IISComputer2 *This,BSTR bstrLocation,LONG lVersion,LONG lFlags,BSTR bstrPassword);
  void __RPC_STUB IISComputer2_BackupWithPassword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISComputer2_RestoreWithPassword_Proxy(IISComputer2 *This,BSTR bstrLocation,LONG lVersion,LONG lFlags,BSTR bstrPassword);
  void __RPC_STUB IISComputer2_RestoreWithPassword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISComputer2_Export_Proxy(IISComputer2 *This,BSTR bstrPassword,BSTR bstrFilename,BSTR bstrSourcePath,LONG lFlags);
  void __RPC_STUB IISComputer2_Export_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISComputer2_Import_Proxy(IISComputer2 *This,BSTR bstrPassword,BSTR bstrFilename,BSTR bstrSourcePath,BSTR bstrDestPath,LONG lFlags);
  void __RPC_STUB IISComputer2_Import_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IISComputer2_SaveData_Proxy(IISComputer2 *This);
  void __RPC_STUB IISComputer2_SaveData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_IISExtComputer;
#ifdef __cplusplus
  class IISExtComputer;
#endif
  EXTERN_C const CLSID CLSID_IISExtApp;
#ifdef __cplusplus
  class IISExtApp;
#endif
  EXTERN_C const CLSID CLSID_IISExtServer;
#ifdef __cplusplus
  class IISExtServer;
#endif
  EXTERN_C const CLSID CLSID_IISExtDsCrMap;
#ifdef __cplusplus
  class IISExtDsCrMap;
#endif
  EXTERN_C const CLSID CLSID_IISExtApplicationPool;
#ifdef __cplusplus
  class IISExtApplicationPool;
#endif
  EXTERN_C const CLSID CLSID_IISExtApplicationPools;
#ifdef __cplusplus
  class IISExtApplicationPools;
#endif
  EXTERN_C const CLSID CLSID_IISExtWebService;
#ifdef __cplusplus
  class IISExtWebService;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
