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
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __EMOSTORE_h__
#define __EMOSTORE_h__

#ifndef __IExchangeServer_FWD_DEFINED__
#define __IExchangeServer_FWD_DEFINED__
typedef struct IExchangeServer IExchangeServer;
#endif

#ifndef __IStorageGroup_FWD_DEFINED__
#define __IStorageGroup_FWD_DEFINED__
typedef struct IStorageGroup IStorageGroup;
#endif

#ifndef __IPublicStoreDB_FWD_DEFINED__
#define __IPublicStoreDB_FWD_DEFINED__
typedef struct IPublicStoreDB IPublicStoreDB;
#endif

#ifndef __IMailboxStoreDB_FWD_DEFINED__
#define __IMailboxStoreDB_FWD_DEFINED__
typedef struct IMailboxStoreDB IMailboxStoreDB;
#endif

#ifndef __IFolderTree_FWD_DEFINED__
#define __IFolderTree_FWD_DEFINED__
typedef struct IFolderTree IFolderTree;
#endif

#ifndef __IDataSource2_FWD_DEFINED__
#define __IDataSource2_FWD_DEFINED__
typedef struct IDataSource2 IDataSource2;
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "msado15.h"
#include "cdoex.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum CDOEXMStoreDBStatus {
    cdoexmOnline = 0,cdoexmOffline = 0x1,cdoexmMounting = 0x2,cdoexmDismounting = 0x3
  } CDOEXMStoreDBStatus;

  typedef enum CDOEXMFolderTreeType {
    cdoexmGeneralPurpose = 0,cdoexmMAPI = 0x1,cdoexmNNTPOnly = 0x2
  } CDOEXMFolderTreeType;

  typedef enum CDOEXMServerType {
    cdoexmBackEnd = 0,cdoexmFrontEnd = 0x1
  } CDOEXMServerType;

  extern RPC_IF_HANDLE __MIDL_itf_EMOSTORE_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_EMOSTORE_0000_v0_0_s_ifspec;

#ifndef __IExchangeServer_INTERFACE_DEFINED__
#define __IExchangeServer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IExchangeServer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IExchangeServer : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DataSource(IDataSource2 **varDataSource) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *varName) = 0;
    virtual HRESULT WINAPI get_ExchangeVersion(BSTR *varExchangeVersion) = 0;
    virtual HRESULT WINAPI get_StorageGroups(VARIANT *varStorageGroups) = 0;
    virtual HRESULT WINAPI get_SubjectLoggingEnabled(VARIANT_BOOL *pSubjectLoggingEnabled) = 0;
    virtual HRESULT WINAPI put_SubjectLoggingEnabled(VARIANT_BOOL varSubjectLoggingEnabled) = 0;
    virtual HRESULT WINAPI get_MessageTrackingEnabled(VARIANT_BOOL *pMessageTrackingEnabled) = 0;
    virtual HRESULT WINAPI put_MessageTrackingEnabled(VARIANT_BOOL varMessageTrackingEnabled) = 0;
    virtual HRESULT WINAPI get_DaysBeforeLogFileRemoval(__LONG32 *pDaysBeforeLogFileRemoval) = 0;
    virtual HRESULT WINAPI put_DaysBeforeLogFileRemoval(__LONG32 varDaysBeforeLogFileRemoval) = 0;
    virtual HRESULT WINAPI get_ServerType(CDOEXMServerType *pServerType) = 0;
    virtual HRESULT WINAPI put_ServerType(CDOEXMServerType varServerType) = 0;
    virtual HRESULT WINAPI get_DirectoryServer(BSTR *varDirectoryServer) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
  };
#else
  typedef struct IExchangeServerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IExchangeServer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IExchangeServer *This);
      ULONG (WINAPI *Release)(IExchangeServer *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IExchangeServer *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IExchangeServer *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IExchangeServer *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IExchangeServer *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DataSource)(IExchangeServer *This,IDataSource2 **varDataSource);
      HRESULT (WINAPI *get_Fields)(IExchangeServer *This,Fields **varFields);
      HRESULT (WINAPI *get_Name)(IExchangeServer *This,BSTR *varName);
      HRESULT (WINAPI *get_ExchangeVersion)(IExchangeServer *This,BSTR *varExchangeVersion);
      HRESULT (WINAPI *get_StorageGroups)(IExchangeServer *This,VARIANT *varStorageGroups);
      HRESULT (WINAPI *get_SubjectLoggingEnabled)(IExchangeServer *This,VARIANT_BOOL *pSubjectLoggingEnabled);
      HRESULT (WINAPI *put_SubjectLoggingEnabled)(IExchangeServer *This,VARIANT_BOOL varSubjectLoggingEnabled);
      HRESULT (WINAPI *get_MessageTrackingEnabled)(IExchangeServer *This,VARIANT_BOOL *pMessageTrackingEnabled);
      HRESULT (WINAPI *put_MessageTrackingEnabled)(IExchangeServer *This,VARIANT_BOOL varMessageTrackingEnabled);
      HRESULT (WINAPI *get_DaysBeforeLogFileRemoval)(IExchangeServer *This,__LONG32 *pDaysBeforeLogFileRemoval);
      HRESULT (WINAPI *put_DaysBeforeLogFileRemoval)(IExchangeServer *This,__LONG32 varDaysBeforeLogFileRemoval);
      HRESULT (WINAPI *get_ServerType)(IExchangeServer *This,CDOEXMServerType *pServerType);
      HRESULT (WINAPI *put_ServerType)(IExchangeServer *This,CDOEXMServerType varServerType);
      HRESULT (WINAPI *get_DirectoryServer)(IExchangeServer *This,BSTR *varDirectoryServer);
      HRESULT (WINAPI *GetInterface)(IExchangeServer *This,BSTR Interface,IDispatch **ppUnknown);
    END_INTERFACE
  } IExchangeServerVtbl;
  struct IExchangeServer {
    CONST_VTBL struct IExchangeServerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IExchangeServer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IExchangeServer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IExchangeServer_Release(This) (This)->lpVtbl->Release(This)
#define IExchangeServer_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IExchangeServer_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IExchangeServer_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IExchangeServer_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IExchangeServer_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IExchangeServer_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IExchangeServer_get_Name(This,varName) (This)->lpVtbl->get_Name(This,varName)
#define IExchangeServer_get_ExchangeVersion(This,varExchangeVersion) (This)->lpVtbl->get_ExchangeVersion(This,varExchangeVersion)
#define IExchangeServer_get_StorageGroups(This,varStorageGroups) (This)->lpVtbl->get_StorageGroups(This,varStorageGroups)
#define IExchangeServer_get_SubjectLoggingEnabled(This,pSubjectLoggingEnabled) (This)->lpVtbl->get_SubjectLoggingEnabled(This,pSubjectLoggingEnabled)
#define IExchangeServer_put_SubjectLoggingEnabled(This,varSubjectLoggingEnabled) (This)->lpVtbl->put_SubjectLoggingEnabled(This,varSubjectLoggingEnabled)
#define IExchangeServer_get_MessageTrackingEnabled(This,pMessageTrackingEnabled) (This)->lpVtbl->get_MessageTrackingEnabled(This,pMessageTrackingEnabled)
#define IExchangeServer_put_MessageTrackingEnabled(This,varMessageTrackingEnabled) (This)->lpVtbl->put_MessageTrackingEnabled(This,varMessageTrackingEnabled)
#define IExchangeServer_get_DaysBeforeLogFileRemoval(This,pDaysBeforeLogFileRemoval) (This)->lpVtbl->get_DaysBeforeLogFileRemoval(This,pDaysBeforeLogFileRemoval)
#define IExchangeServer_put_DaysBeforeLogFileRemoval(This,varDaysBeforeLogFileRemoval) (This)->lpVtbl->put_DaysBeforeLogFileRemoval(This,varDaysBeforeLogFileRemoval)
#define IExchangeServer_get_ServerType(This,pServerType) (This)->lpVtbl->get_ServerType(This,pServerType)
#define IExchangeServer_put_ServerType(This,varServerType) (This)->lpVtbl->put_ServerType(This,varServerType)
#define IExchangeServer_get_DirectoryServer(This,varDirectoryServer) (This)->lpVtbl->get_DirectoryServer(This,varDirectoryServer)
#define IExchangeServer_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#endif
#endif
  HRESULT WINAPI IExchangeServer_get_DataSource_Proxy(IExchangeServer *This,IDataSource2 **varDataSource);
  void __RPC_STUB IExchangeServer_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_Fields_Proxy(IExchangeServer *This,Fields **varFields);
  void __RPC_STUB IExchangeServer_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_Name_Proxy(IExchangeServer *This,BSTR *varName);
  void __RPC_STUB IExchangeServer_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_ExchangeVersion_Proxy(IExchangeServer *This,BSTR *varExchangeVersion);
  void __RPC_STUB IExchangeServer_get_ExchangeVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_StorageGroups_Proxy(IExchangeServer *This,VARIANT *varStorageGroups);
  void __RPC_STUB IExchangeServer_get_StorageGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_SubjectLoggingEnabled_Proxy(IExchangeServer *This,VARIANT_BOOL *pSubjectLoggingEnabled);
  void __RPC_STUB IExchangeServer_get_SubjectLoggingEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_put_SubjectLoggingEnabled_Proxy(IExchangeServer *This,VARIANT_BOOL varSubjectLoggingEnabled);
  void __RPC_STUB IExchangeServer_put_SubjectLoggingEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_MessageTrackingEnabled_Proxy(IExchangeServer *This,VARIANT_BOOL *pMessageTrackingEnabled);
  void __RPC_STUB IExchangeServer_get_MessageTrackingEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_put_MessageTrackingEnabled_Proxy(IExchangeServer *This,VARIANT_BOOL varMessageTrackingEnabled);
  void __RPC_STUB IExchangeServer_put_MessageTrackingEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_DaysBeforeLogFileRemoval_Proxy(IExchangeServer *This,__LONG32 *pDaysBeforeLogFileRemoval);
  void __RPC_STUB IExchangeServer_get_DaysBeforeLogFileRemoval_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_put_DaysBeforeLogFileRemoval_Proxy(IExchangeServer *This,__LONG32 varDaysBeforeLogFileRemoval);
  void __RPC_STUB IExchangeServer_put_DaysBeforeLogFileRemoval_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_ServerType_Proxy(IExchangeServer *This,CDOEXMServerType *pServerType);
  void __RPC_STUB IExchangeServer_get_ServerType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_put_ServerType_Proxy(IExchangeServer *This,CDOEXMServerType varServerType);
  void __RPC_STUB IExchangeServer_put_ServerType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_get_DirectoryServer_Proxy(IExchangeServer *This,BSTR *varDirectoryServer);
  void __RPC_STUB IExchangeServer_get_DirectoryServer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExchangeServer_GetInterface_Proxy(IExchangeServer *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IExchangeServer_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IStorageGroup_INTERFACE_DEFINED__
#define __IStorageGroup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IStorageGroup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IStorageGroup : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DataSource(IDataSource2 **varDataSource) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR varName) = 0;
    virtual HRESULT WINAPI get_PublicStoreDBs(VARIANT *varPublicStoreDBs) = 0;
    virtual HRESULT WINAPI get_MailboxStoreDBs(VARIANT *varMailboxStoreDBs) = 0;
    virtual HRESULT WINAPI get_LogFilePath(BSTR *varLogFilePath) = 0;
    virtual HRESULT WINAPI get_SystemFilePath(BSTR *varSystemFilePath) = 0;
    virtual HRESULT WINAPI get_CircularLogging(VARIANT_BOOL *pCircularLogging) = 0;
    virtual HRESULT WINAPI put_CircularLogging(VARIANT_BOOL varCircularLogging) = 0;
    virtual HRESULT WINAPI get_ZeroDatabase(VARIANT_BOOL *pZeroDatabase) = 0;
    virtual HRESULT WINAPI put_ZeroDatabase(VARIANT_BOOL varZeroDatabase) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI MoveLogFiles(BSTR LogFilePath,__LONG32 Flags) = 0;
    virtual HRESULT WINAPI MoveSystemFiles(BSTR SystemFilePath,__LONG32 Flags) = 0;
  };
#else
  typedef struct IStorageGroupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IStorageGroup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IStorageGroup *This);
      ULONG (WINAPI *Release)(IStorageGroup *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IStorageGroup *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IStorageGroup *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IStorageGroup *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IStorageGroup *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DataSource)(IStorageGroup *This,IDataSource2 **varDataSource);
      HRESULT (WINAPI *get_Fields)(IStorageGroup *This,Fields **varFields);
      HRESULT (WINAPI *get_Name)(IStorageGroup *This,BSTR *pName);
      HRESULT (WINAPI *put_Name)(IStorageGroup *This,BSTR varName);
      HRESULT (WINAPI *get_PublicStoreDBs)(IStorageGroup *This,VARIANT *varPublicStoreDBs);
      HRESULT (WINAPI *get_MailboxStoreDBs)(IStorageGroup *This,VARIANT *varMailboxStoreDBs);
      HRESULT (WINAPI *get_LogFilePath)(IStorageGroup *This,BSTR *varLogFilePath);
      HRESULT (WINAPI *get_SystemFilePath)(IStorageGroup *This,BSTR *varSystemFilePath);
      HRESULT (WINAPI *get_CircularLogging)(IStorageGroup *This,VARIANT_BOOL *pCircularLogging);
      HRESULT (WINAPI *put_CircularLogging)(IStorageGroup *This,VARIANT_BOOL varCircularLogging);
      HRESULT (WINAPI *get_ZeroDatabase)(IStorageGroup *This,VARIANT_BOOL *pZeroDatabase);
      HRESULT (WINAPI *put_ZeroDatabase)(IStorageGroup *This,VARIANT_BOOL varZeroDatabase);
      HRESULT (WINAPI *GetInterface)(IStorageGroup *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *MoveLogFiles)(IStorageGroup *This,BSTR LogFilePath,__LONG32 Flags);
      HRESULT (WINAPI *MoveSystemFiles)(IStorageGroup *This,BSTR SystemFilePath,__LONG32 Flags);
    END_INTERFACE
  } IStorageGroupVtbl;
  struct IStorageGroup {
    CONST_VTBL struct IStorageGroupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IStorageGroup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IStorageGroup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IStorageGroup_Release(This) (This)->lpVtbl->Release(This)
#define IStorageGroup_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IStorageGroup_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IStorageGroup_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IStorageGroup_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IStorageGroup_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IStorageGroup_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IStorageGroup_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define IStorageGroup_put_Name(This,varName) (This)->lpVtbl->put_Name(This,varName)
#define IStorageGroup_get_PublicStoreDBs(This,varPublicStoreDBs) (This)->lpVtbl->get_PublicStoreDBs(This,varPublicStoreDBs)
#define IStorageGroup_get_MailboxStoreDBs(This,varMailboxStoreDBs) (This)->lpVtbl->get_MailboxStoreDBs(This,varMailboxStoreDBs)
#define IStorageGroup_get_LogFilePath(This,varLogFilePath) (This)->lpVtbl->get_LogFilePath(This,varLogFilePath)
#define IStorageGroup_get_SystemFilePath(This,varSystemFilePath) (This)->lpVtbl->get_SystemFilePath(This,varSystemFilePath)
#define IStorageGroup_get_CircularLogging(This,pCircularLogging) (This)->lpVtbl->get_CircularLogging(This,pCircularLogging)
#define IStorageGroup_put_CircularLogging(This,varCircularLogging) (This)->lpVtbl->put_CircularLogging(This,varCircularLogging)
#define IStorageGroup_get_ZeroDatabase(This,pZeroDatabase) (This)->lpVtbl->get_ZeroDatabase(This,pZeroDatabase)
#define IStorageGroup_put_ZeroDatabase(This,varZeroDatabase) (This)->lpVtbl->put_ZeroDatabase(This,varZeroDatabase)
#define IStorageGroup_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IStorageGroup_MoveLogFiles(This,LogFilePath,Flags) (This)->lpVtbl->MoveLogFiles(This,LogFilePath,Flags)
#define IStorageGroup_MoveSystemFiles(This,SystemFilePath,Flags) (This)->lpVtbl->MoveSystemFiles(This,SystemFilePath,Flags)
#endif
#endif
  HRESULT WINAPI IStorageGroup_get_DataSource_Proxy(IStorageGroup *This,IDataSource2 **varDataSource);
  void __RPC_STUB IStorageGroup_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_Fields_Proxy(IStorageGroup *This,Fields **varFields);
  void __RPC_STUB IStorageGroup_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_Name_Proxy(IStorageGroup *This,BSTR *pName);
  void __RPC_STUB IStorageGroup_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_put_Name_Proxy(IStorageGroup *This,BSTR varName);
  void __RPC_STUB IStorageGroup_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_PublicStoreDBs_Proxy(IStorageGroup *This,VARIANT *varPublicStoreDBs);
  void __RPC_STUB IStorageGroup_get_PublicStoreDBs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_MailboxStoreDBs_Proxy(IStorageGroup *This,VARIANT *varMailboxStoreDBs);
  void __RPC_STUB IStorageGroup_get_MailboxStoreDBs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_LogFilePath_Proxy(IStorageGroup *This,BSTR *varLogFilePath);
  void __RPC_STUB IStorageGroup_get_LogFilePath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_SystemFilePath_Proxy(IStorageGroup *This,BSTR *varSystemFilePath);
  void __RPC_STUB IStorageGroup_get_SystemFilePath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_CircularLogging_Proxy(IStorageGroup *This,VARIANT_BOOL *pCircularLogging);
  void __RPC_STUB IStorageGroup_get_CircularLogging_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_put_CircularLogging_Proxy(IStorageGroup *This,VARIANT_BOOL varCircularLogging);
  void __RPC_STUB IStorageGroup_put_CircularLogging_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_get_ZeroDatabase_Proxy(IStorageGroup *This,VARIANT_BOOL *pZeroDatabase);
  void __RPC_STUB IStorageGroup_get_ZeroDatabase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_put_ZeroDatabase_Proxy(IStorageGroup *This,VARIANT_BOOL varZeroDatabase);
  void __RPC_STUB IStorageGroup_put_ZeroDatabase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_GetInterface_Proxy(IStorageGroup *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IStorageGroup_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_MoveLogFiles_Proxy(IStorageGroup *This,BSTR LogFilePath,__LONG32 Flags);
  void __RPC_STUB IStorageGroup_MoveLogFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStorageGroup_MoveSystemFiles_Proxy(IStorageGroup *This,BSTR SystemFilePath,__LONG32 Flags);
  void __RPC_STUB IStorageGroup_MoveSystemFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPublicStoreDB_INTERFACE_DEFINED__
#define __IPublicStoreDB_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPublicStoreDB;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPublicStoreDB : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DataSource(IDataSource2 **varDataSource) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR varName) = 0;
    virtual HRESULT WINAPI get_FolderTree(BSTR *pFolderTree) = 0;
    virtual HRESULT WINAPI put_FolderTree(BSTR varFolderTree) = 0;
    virtual HRESULT WINAPI get_DBPath(BSTR *varDBPath) = 0;
    virtual HRESULT WINAPI get_SLVPath(BSTR *varSLVPath) = 0;
    virtual HRESULT WINAPI get_Status(CDOEXMStoreDBStatus *varStatus) = 0;
    virtual HRESULT WINAPI get_Enabled(VARIANT_BOOL *pEnabled) = 0;
    virtual HRESULT WINAPI put_Enabled(VARIANT_BOOL varEnabled) = 0;
    virtual HRESULT WINAPI get_StoreQuota(__LONG32 *pStoreQuota) = 0;
    virtual HRESULT WINAPI put_StoreQuota(__LONG32 varStoreQuota) = 0;
    virtual HRESULT WINAPI get_HardLimit(__LONG32 *pHardLimit) = 0;
    virtual HRESULT WINAPI put_HardLimit(__LONG32 varHardLimit) = 0;
    virtual HRESULT WINAPI get_ItemSizeLimit(__LONG32 *pItemSizeLimit) = 0;
    virtual HRESULT WINAPI put_ItemSizeLimit(__LONG32 varItemSizeLimit) = 0;
    virtual HRESULT WINAPI get_DaysBeforeItemExpiration(__LONG32 *pDaysBeforeItemExpiration) = 0;
    virtual HRESULT WINAPI put_DaysBeforeItemExpiration(__LONG32 varDaysBeforeItemExpiration) = 0;
    virtual HRESULT WINAPI get_DaysBeforeGarbageCollection(__LONG32 *pDaysBeforeGarbageCollection) = 0;
    virtual HRESULT WINAPI put_DaysBeforeGarbageCollection(__LONG32 varDaysBeforeGarbageCollection) = 0;
    virtual HRESULT WINAPI get_GarbageCollectOnlyAfterBackup(VARIANT_BOOL *pGarbageCollectOnlyAfterBackup) = 0;
    virtual HRESULT WINAPI put_GarbageCollectOnlyAfterBackup(VARIANT_BOOL varGarbageCollectOnlyAfterBackup) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI MoveDataFiles(BSTR DBPath,BSTR SLVPath,__LONG32 Flags) = 0;
    virtual HRESULT WINAPI Mount(__LONG32 Timeout) = 0;
    virtual HRESULT WINAPI Dismount(__LONG32 Timeout) = 0;
  };
#else
  typedef struct IPublicStoreDBVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPublicStoreDB *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPublicStoreDB *This);
      ULONG (WINAPI *Release)(IPublicStoreDB *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IPublicStoreDB *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IPublicStoreDB *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IPublicStoreDB *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IPublicStoreDB *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DataSource)(IPublicStoreDB *This,IDataSource2 **varDataSource);
      HRESULT (WINAPI *get_Fields)(IPublicStoreDB *This,Fields **varFields);
      HRESULT (WINAPI *get_Name)(IPublicStoreDB *This,BSTR *pName);
      HRESULT (WINAPI *put_Name)(IPublicStoreDB *This,BSTR varName);
      HRESULT (WINAPI *get_FolderTree)(IPublicStoreDB *This,BSTR *pFolderTree);
      HRESULT (WINAPI *put_FolderTree)(IPublicStoreDB *This,BSTR varFolderTree);
      HRESULT (WINAPI *get_DBPath)(IPublicStoreDB *This,BSTR *varDBPath);
      HRESULT (WINAPI *get_SLVPath)(IPublicStoreDB *This,BSTR *varSLVPath);
      HRESULT (WINAPI *get_Status)(IPublicStoreDB *This,CDOEXMStoreDBStatus *varStatus);
      HRESULT (WINAPI *get_Enabled)(IPublicStoreDB *This,VARIANT_BOOL *pEnabled);
      HRESULT (WINAPI *put_Enabled)(IPublicStoreDB *This,VARIANT_BOOL varEnabled);
      HRESULT (WINAPI *get_StoreQuota)(IPublicStoreDB *This,__LONG32 *pStoreQuota);
      HRESULT (WINAPI *put_StoreQuota)(IPublicStoreDB *This,__LONG32 varStoreQuota);
      HRESULT (WINAPI *get_HardLimit)(IPublicStoreDB *This,__LONG32 *pHardLimit);
      HRESULT (WINAPI *put_HardLimit)(IPublicStoreDB *This,__LONG32 varHardLimit);
      HRESULT (WINAPI *get_ItemSizeLimit)(IPublicStoreDB *This,__LONG32 *pItemSizeLimit);
      HRESULT (WINAPI *put_ItemSizeLimit)(IPublicStoreDB *This,__LONG32 varItemSizeLimit);
      HRESULT (WINAPI *get_DaysBeforeItemExpiration)(IPublicStoreDB *This,__LONG32 *pDaysBeforeItemExpiration);
      HRESULT (WINAPI *put_DaysBeforeItemExpiration)(IPublicStoreDB *This,__LONG32 varDaysBeforeItemExpiration);
      HRESULT (WINAPI *get_DaysBeforeGarbageCollection)(IPublicStoreDB *This,__LONG32 *pDaysBeforeGarbageCollection);
      HRESULT (WINAPI *put_DaysBeforeGarbageCollection)(IPublicStoreDB *This,__LONG32 varDaysBeforeGarbageCollection);
      HRESULT (WINAPI *get_GarbageCollectOnlyAfterBackup)(IPublicStoreDB *This,VARIANT_BOOL *pGarbageCollectOnlyAfterBackup);
      HRESULT (WINAPI *put_GarbageCollectOnlyAfterBackup)(IPublicStoreDB *This,VARIANT_BOOL varGarbageCollectOnlyAfterBackup);
      HRESULT (WINAPI *GetInterface)(IPublicStoreDB *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *MoveDataFiles)(IPublicStoreDB *This,BSTR DBPath,BSTR SLVPath,__LONG32 Flags);
      HRESULT (WINAPI *Mount)(IPublicStoreDB *This,__LONG32 Timeout);
      HRESULT (WINAPI *Dismount)(IPublicStoreDB *This,__LONG32 Timeout);
    END_INTERFACE
  } IPublicStoreDBVtbl;
  struct IPublicStoreDB {
    CONST_VTBL struct IPublicStoreDBVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPublicStoreDB_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPublicStoreDB_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPublicStoreDB_Release(This) (This)->lpVtbl->Release(This)
#define IPublicStoreDB_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IPublicStoreDB_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IPublicStoreDB_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IPublicStoreDB_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IPublicStoreDB_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IPublicStoreDB_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IPublicStoreDB_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define IPublicStoreDB_put_Name(This,varName) (This)->lpVtbl->put_Name(This,varName)
#define IPublicStoreDB_get_FolderTree(This,pFolderTree) (This)->lpVtbl->get_FolderTree(This,pFolderTree)
#define IPublicStoreDB_put_FolderTree(This,varFolderTree) (This)->lpVtbl->put_FolderTree(This,varFolderTree)
#define IPublicStoreDB_get_DBPath(This,varDBPath) (This)->lpVtbl->get_DBPath(This,varDBPath)
#define IPublicStoreDB_get_SLVPath(This,varSLVPath) (This)->lpVtbl->get_SLVPath(This,varSLVPath)
#define IPublicStoreDB_get_Status(This,varStatus) (This)->lpVtbl->get_Status(This,varStatus)
#define IPublicStoreDB_get_Enabled(This,pEnabled) (This)->lpVtbl->get_Enabled(This,pEnabled)
#define IPublicStoreDB_put_Enabled(This,varEnabled) (This)->lpVtbl->put_Enabled(This,varEnabled)
#define IPublicStoreDB_get_StoreQuota(This,pStoreQuota) (This)->lpVtbl->get_StoreQuota(This,pStoreQuota)
#define IPublicStoreDB_put_StoreQuota(This,varStoreQuota) (This)->lpVtbl->put_StoreQuota(This,varStoreQuota)
#define IPublicStoreDB_get_HardLimit(This,pHardLimit) (This)->lpVtbl->get_HardLimit(This,pHardLimit)
#define IPublicStoreDB_put_HardLimit(This,varHardLimit) (This)->lpVtbl->put_HardLimit(This,varHardLimit)
#define IPublicStoreDB_get_ItemSizeLimit(This,pItemSizeLimit) (This)->lpVtbl->get_ItemSizeLimit(This,pItemSizeLimit)
#define IPublicStoreDB_put_ItemSizeLimit(This,varItemSizeLimit) (This)->lpVtbl->put_ItemSizeLimit(This,varItemSizeLimit)
#define IPublicStoreDB_get_DaysBeforeItemExpiration(This,pDaysBeforeItemExpiration) (This)->lpVtbl->get_DaysBeforeItemExpiration(This,pDaysBeforeItemExpiration)
#define IPublicStoreDB_put_DaysBeforeItemExpiration(This,varDaysBeforeItemExpiration) (This)->lpVtbl->put_DaysBeforeItemExpiration(This,varDaysBeforeItemExpiration)
#define IPublicStoreDB_get_DaysBeforeGarbageCollection(This,pDaysBeforeGarbageCollection) (This)->lpVtbl->get_DaysBeforeGarbageCollection(This,pDaysBeforeGarbageCollection)
#define IPublicStoreDB_put_DaysBeforeGarbageCollection(This,varDaysBeforeGarbageCollection) (This)->lpVtbl->put_DaysBeforeGarbageCollection(This,varDaysBeforeGarbageCollection)
#define IPublicStoreDB_get_GarbageCollectOnlyAfterBackup(This,pGarbageCollectOnlyAfterBackup) (This)->lpVtbl->get_GarbageCollectOnlyAfterBackup(This,pGarbageCollectOnlyAfterBackup)
#define IPublicStoreDB_put_GarbageCollectOnlyAfterBackup(This,varGarbageCollectOnlyAfterBackup) (This)->lpVtbl->put_GarbageCollectOnlyAfterBackup(This,varGarbageCollectOnlyAfterBackup)
#define IPublicStoreDB_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IPublicStoreDB_MoveDataFiles(This,DBPath,SLVPath,Flags) (This)->lpVtbl->MoveDataFiles(This,DBPath,SLVPath,Flags)
#define IPublicStoreDB_Mount(This,Timeout) (This)->lpVtbl->Mount(This,Timeout)
#define IPublicStoreDB_Dismount(This,Timeout) (This)->lpVtbl->Dismount(This,Timeout)
#endif
#endif
  HRESULT WINAPI IPublicStoreDB_get_DataSource_Proxy(IPublicStoreDB *This,IDataSource2 **varDataSource);
  void __RPC_STUB IPublicStoreDB_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_Fields_Proxy(IPublicStoreDB *This,Fields **varFields);
  void __RPC_STUB IPublicStoreDB_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_Name_Proxy(IPublicStoreDB *This,BSTR *pName);
  void __RPC_STUB IPublicStoreDB_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_Name_Proxy(IPublicStoreDB *This,BSTR varName);
  void __RPC_STUB IPublicStoreDB_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_FolderTree_Proxy(IPublicStoreDB *This,BSTR *pFolderTree);
  void __RPC_STUB IPublicStoreDB_get_FolderTree_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_FolderTree_Proxy(IPublicStoreDB *This,BSTR varFolderTree);
  void __RPC_STUB IPublicStoreDB_put_FolderTree_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_DBPath_Proxy(IPublicStoreDB *This,BSTR *varDBPath);
  void __RPC_STUB IPublicStoreDB_get_DBPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_SLVPath_Proxy(IPublicStoreDB *This,BSTR *varSLVPath);
  void __RPC_STUB IPublicStoreDB_get_SLVPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_Status_Proxy(IPublicStoreDB *This,CDOEXMStoreDBStatus *varStatus);
  void __RPC_STUB IPublicStoreDB_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_Enabled_Proxy(IPublicStoreDB *This,VARIANT_BOOL *pEnabled);
  void __RPC_STUB IPublicStoreDB_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_Enabled_Proxy(IPublicStoreDB *This,VARIANT_BOOL varEnabled);
  void __RPC_STUB IPublicStoreDB_put_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_StoreQuota_Proxy(IPublicStoreDB *This,__LONG32 *pStoreQuota);
  void __RPC_STUB IPublicStoreDB_get_StoreQuota_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_StoreQuota_Proxy(IPublicStoreDB *This,__LONG32 varStoreQuota);
  void __RPC_STUB IPublicStoreDB_put_StoreQuota_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_HardLimit_Proxy(IPublicStoreDB *This,__LONG32 *pHardLimit);
  void __RPC_STUB IPublicStoreDB_get_HardLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_HardLimit_Proxy(IPublicStoreDB *This,__LONG32 varHardLimit);
  void __RPC_STUB IPublicStoreDB_put_HardLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_ItemSizeLimit_Proxy(IPublicStoreDB *This,__LONG32 *pItemSizeLimit);
  void __RPC_STUB IPublicStoreDB_get_ItemSizeLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_ItemSizeLimit_Proxy(IPublicStoreDB *This,__LONG32 varItemSizeLimit);
  void __RPC_STUB IPublicStoreDB_put_ItemSizeLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_DaysBeforeItemExpiration_Proxy(IPublicStoreDB *This,__LONG32 *pDaysBeforeItemExpiration);
  void __RPC_STUB IPublicStoreDB_get_DaysBeforeItemExpiration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_DaysBeforeItemExpiration_Proxy(IPublicStoreDB *This,__LONG32 varDaysBeforeItemExpiration);
  void __RPC_STUB IPublicStoreDB_put_DaysBeforeItemExpiration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_DaysBeforeGarbageCollection_Proxy(IPublicStoreDB *This,__LONG32 *pDaysBeforeGarbageCollection);
  void __RPC_STUB IPublicStoreDB_get_DaysBeforeGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_DaysBeforeGarbageCollection_Proxy(IPublicStoreDB *This,__LONG32 varDaysBeforeGarbageCollection);
  void __RPC_STUB IPublicStoreDB_put_DaysBeforeGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_get_GarbageCollectOnlyAfterBackup_Proxy(IPublicStoreDB *This,VARIANT_BOOL *pGarbageCollectOnlyAfterBackup);
  void __RPC_STUB IPublicStoreDB_get_GarbageCollectOnlyAfterBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_put_GarbageCollectOnlyAfterBackup_Proxy(IPublicStoreDB *This,VARIANT_BOOL varGarbageCollectOnlyAfterBackup);
  void __RPC_STUB IPublicStoreDB_put_GarbageCollectOnlyAfterBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_GetInterface_Proxy(IPublicStoreDB *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IPublicStoreDB_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_MoveDataFiles_Proxy(IPublicStoreDB *This,BSTR DBPath,BSTR SLVPath,__LONG32 Flags);
  void __RPC_STUB IPublicStoreDB_MoveDataFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_Mount_Proxy(IPublicStoreDB *This,__LONG32 Timeout);
  void __RPC_STUB IPublicStoreDB_Mount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublicStoreDB_Dismount_Proxy(IPublicStoreDB *This,__LONG32 Timeout);
  void __RPC_STUB IPublicStoreDB_Dismount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMailboxStoreDB_INTERFACE_DEFINED__
#define __IMailboxStoreDB_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMailboxStoreDB;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMailboxStoreDB : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DataSource(IDataSource2 **varDataSource) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR varName) = 0;
    virtual HRESULT WINAPI get_PublicStoreDB(BSTR *pPublicStoreDB) = 0;
    virtual HRESULT WINAPI put_PublicStoreDB(BSTR varPublicStoreDB) = 0;
    virtual HRESULT WINAPI get_OfflineAddressList(BSTR *pOfflineAddressList) = 0;
    virtual HRESULT WINAPI put_OfflineAddressList(BSTR varOfflineAddressList) = 0;
    virtual HRESULT WINAPI get_DBPath(BSTR *varDBPath) = 0;
    virtual HRESULT WINAPI get_SLVPath(BSTR *varSLVPath) = 0;
    virtual HRESULT WINAPI get_Status(CDOEXMStoreDBStatus *varStatus) = 0;
    virtual HRESULT WINAPI get_Enabled(VARIANT_BOOL *pEnabled) = 0;
    virtual HRESULT WINAPI put_Enabled(VARIANT_BOOL varEnabled) = 0;
    virtual HRESULT WINAPI get_StoreQuota(__LONG32 *pStoreQuota) = 0;
    virtual HRESULT WINAPI put_StoreQuota(__LONG32 varStoreQuota) = 0;
    virtual HRESULT WINAPI get_OverQuotaLimit(__LONG32 *pOverQuotaLimit) = 0;
    virtual HRESULT WINAPI put_OverQuotaLimit(__LONG32 varOverQuotaLimit) = 0;
    virtual HRESULT WINAPI get_HardLimit(__LONG32 *pHardLimit) = 0;
    virtual HRESULT WINAPI put_HardLimit(__LONG32 varHardLimit) = 0;
    virtual HRESULT WINAPI get_DaysBeforeGarbageCollection(__LONG32 *pDaysBeforeGarbageCollection) = 0;
    virtual HRESULT WINAPI put_DaysBeforeGarbageCollection(__LONG32 varDaysBeforeGarbageCollection) = 0;
    virtual HRESULT WINAPI get_DaysBeforeDeletedMailboxCleanup(__LONG32 *pDaysBeforeDeletedMailboxCleanup) = 0;
    virtual HRESULT WINAPI put_DaysBeforeDeletedMailboxCleanup(__LONG32 varDaysBeforeDeletedMailboxCleanup) = 0;
    virtual HRESULT WINAPI get_GarbageCollectOnlyAfterBackup(VARIANT_BOOL *pGarbageCollectOnlyAfterBackup) = 0;
    virtual HRESULT WINAPI put_GarbageCollectOnlyAfterBackup(VARIANT_BOOL varGarbageCollectOnlyAfterBackup) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI MoveDataFiles(BSTR DBPath,BSTR SLVPath,__LONG32 Flags) = 0;
    virtual HRESULT WINAPI Mount(__LONG32 Timeout) = 0;
    virtual HRESULT WINAPI Dismount(__LONG32 Timeout) = 0;
  };
#else
  typedef struct IMailboxStoreDBVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMailboxStoreDB *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMailboxStoreDB *This);
      ULONG (WINAPI *Release)(IMailboxStoreDB *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMailboxStoreDB *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMailboxStoreDB *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMailboxStoreDB *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMailboxStoreDB *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DataSource)(IMailboxStoreDB *This,IDataSource2 **varDataSource);
      HRESULT (WINAPI *get_Fields)(IMailboxStoreDB *This,Fields **varFields);
      HRESULT (WINAPI *get_Name)(IMailboxStoreDB *This,BSTR *pName);
      HRESULT (WINAPI *put_Name)(IMailboxStoreDB *This,BSTR varName);
      HRESULT (WINAPI *get_PublicStoreDB)(IMailboxStoreDB *This,BSTR *pPublicStoreDB);
      HRESULT (WINAPI *put_PublicStoreDB)(IMailboxStoreDB *This,BSTR varPublicStoreDB);
      HRESULT (WINAPI *get_OfflineAddressList)(IMailboxStoreDB *This,BSTR *pOfflineAddressList);
      HRESULT (WINAPI *put_OfflineAddressList)(IMailboxStoreDB *This,BSTR varOfflineAddressList);
      HRESULT (WINAPI *get_DBPath)(IMailboxStoreDB *This,BSTR *varDBPath);
      HRESULT (WINAPI *get_SLVPath)(IMailboxStoreDB *This,BSTR *varSLVPath);
      HRESULT (WINAPI *get_Status)(IMailboxStoreDB *This,CDOEXMStoreDBStatus *varStatus);
      HRESULT (WINAPI *get_Enabled)(IMailboxStoreDB *This,VARIANT_BOOL *pEnabled);
      HRESULT (WINAPI *put_Enabled)(IMailboxStoreDB *This,VARIANT_BOOL varEnabled);
      HRESULT (WINAPI *get_StoreQuota)(IMailboxStoreDB *This,__LONG32 *pStoreQuota);
      HRESULT (WINAPI *put_StoreQuota)(IMailboxStoreDB *This,__LONG32 varStoreQuota);
      HRESULT (WINAPI *get_OverQuotaLimit)(IMailboxStoreDB *This,__LONG32 *pOverQuotaLimit);
      HRESULT (WINAPI *put_OverQuotaLimit)(IMailboxStoreDB *This,__LONG32 varOverQuotaLimit);
      HRESULT (WINAPI *get_HardLimit)(IMailboxStoreDB *This,__LONG32 *pHardLimit);
      HRESULT (WINAPI *put_HardLimit)(IMailboxStoreDB *This,__LONG32 varHardLimit);
      HRESULT (WINAPI *get_DaysBeforeGarbageCollection)(IMailboxStoreDB *This,__LONG32 *pDaysBeforeGarbageCollection);
      HRESULT (WINAPI *put_DaysBeforeGarbageCollection)(IMailboxStoreDB *This,__LONG32 varDaysBeforeGarbageCollection);
      HRESULT (WINAPI *get_DaysBeforeDeletedMailboxCleanup)(IMailboxStoreDB *This,__LONG32 *pDaysBeforeDeletedMailboxCleanup);
      HRESULT (WINAPI *put_DaysBeforeDeletedMailboxCleanup)(IMailboxStoreDB *This,__LONG32 varDaysBeforeDeletedMailboxCleanup);
      HRESULT (WINAPI *get_GarbageCollectOnlyAfterBackup)(IMailboxStoreDB *This,VARIANT_BOOL *pGarbageCollectOnlyAfterBackup);
      HRESULT (WINAPI *put_GarbageCollectOnlyAfterBackup)(IMailboxStoreDB *This,VARIANT_BOOL varGarbageCollectOnlyAfterBackup);
      HRESULT (WINAPI *GetInterface)(IMailboxStoreDB *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *MoveDataFiles)(IMailboxStoreDB *This,BSTR DBPath,BSTR SLVPath,__LONG32 Flags);
      HRESULT (WINAPI *Mount)(IMailboxStoreDB *This,__LONG32 Timeout);
      HRESULT (WINAPI *Dismount)(IMailboxStoreDB *This,__LONG32 Timeout);
    END_INTERFACE
  } IMailboxStoreDBVtbl;
  struct IMailboxStoreDB {
    CONST_VTBL struct IMailboxStoreDBVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMailboxStoreDB_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMailboxStoreDB_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMailboxStoreDB_Release(This) (This)->lpVtbl->Release(This)
#define IMailboxStoreDB_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMailboxStoreDB_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMailboxStoreDB_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMailboxStoreDB_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMailboxStoreDB_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IMailboxStoreDB_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IMailboxStoreDB_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define IMailboxStoreDB_put_Name(This,varName) (This)->lpVtbl->put_Name(This,varName)
#define IMailboxStoreDB_get_PublicStoreDB(This,pPublicStoreDB) (This)->lpVtbl->get_PublicStoreDB(This,pPublicStoreDB)
#define IMailboxStoreDB_put_PublicStoreDB(This,varPublicStoreDB) (This)->lpVtbl->put_PublicStoreDB(This,varPublicStoreDB)
#define IMailboxStoreDB_get_OfflineAddressList(This,pOfflineAddressList) (This)->lpVtbl->get_OfflineAddressList(This,pOfflineAddressList)
#define IMailboxStoreDB_put_OfflineAddressList(This,varOfflineAddressList) (This)->lpVtbl->put_OfflineAddressList(This,varOfflineAddressList)
#define IMailboxStoreDB_get_DBPath(This,varDBPath) (This)->lpVtbl->get_DBPath(This,varDBPath)
#define IMailboxStoreDB_get_SLVPath(This,varSLVPath) (This)->lpVtbl->get_SLVPath(This,varSLVPath)
#define IMailboxStoreDB_get_Status(This,varStatus) (This)->lpVtbl->get_Status(This,varStatus)
#define IMailboxStoreDB_get_Enabled(This,pEnabled) (This)->lpVtbl->get_Enabled(This,pEnabled)
#define IMailboxStoreDB_put_Enabled(This,varEnabled) (This)->lpVtbl->put_Enabled(This,varEnabled)
#define IMailboxStoreDB_get_StoreQuota(This,pStoreQuota) (This)->lpVtbl->get_StoreQuota(This,pStoreQuota)
#define IMailboxStoreDB_put_StoreQuota(This,varStoreQuota) (This)->lpVtbl->put_StoreQuota(This,varStoreQuota)
#define IMailboxStoreDB_get_OverQuotaLimit(This,pOverQuotaLimit) (This)->lpVtbl->get_OverQuotaLimit(This,pOverQuotaLimit)
#define IMailboxStoreDB_put_OverQuotaLimit(This,varOverQuotaLimit) (This)->lpVtbl->put_OverQuotaLimit(This,varOverQuotaLimit)
#define IMailboxStoreDB_get_HardLimit(This,pHardLimit) (This)->lpVtbl->get_HardLimit(This,pHardLimit)
#define IMailboxStoreDB_put_HardLimit(This,varHardLimit) (This)->lpVtbl->put_HardLimit(This,varHardLimit)
#define IMailboxStoreDB_get_DaysBeforeGarbageCollection(This,pDaysBeforeGarbageCollection) (This)->lpVtbl->get_DaysBeforeGarbageCollection(This,pDaysBeforeGarbageCollection)
#define IMailboxStoreDB_put_DaysBeforeGarbageCollection(This,varDaysBeforeGarbageCollection) (This)->lpVtbl->put_DaysBeforeGarbageCollection(This,varDaysBeforeGarbageCollection)
#define IMailboxStoreDB_get_DaysBeforeDeletedMailboxCleanup(This,pDaysBeforeDeletedMailboxCleanup) (This)->lpVtbl->get_DaysBeforeDeletedMailboxCleanup(This,pDaysBeforeDeletedMailboxCleanup)
#define IMailboxStoreDB_put_DaysBeforeDeletedMailboxCleanup(This,varDaysBeforeDeletedMailboxCleanup) (This)->lpVtbl->put_DaysBeforeDeletedMailboxCleanup(This,varDaysBeforeDeletedMailboxCleanup)
#define IMailboxStoreDB_get_GarbageCollectOnlyAfterBackup(This,pGarbageCollectOnlyAfterBackup) (This)->lpVtbl->get_GarbageCollectOnlyAfterBackup(This,pGarbageCollectOnlyAfterBackup)
#define IMailboxStoreDB_put_GarbageCollectOnlyAfterBackup(This,varGarbageCollectOnlyAfterBackup) (This)->lpVtbl->put_GarbageCollectOnlyAfterBackup(This,varGarbageCollectOnlyAfterBackup)
#define IMailboxStoreDB_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IMailboxStoreDB_MoveDataFiles(This,DBPath,SLVPath,Flags) (This)->lpVtbl->MoveDataFiles(This,DBPath,SLVPath,Flags)
#define IMailboxStoreDB_Mount(This,Timeout) (This)->lpVtbl->Mount(This,Timeout)
#define IMailboxStoreDB_Dismount(This,Timeout) (This)->lpVtbl->Dismount(This,Timeout)
#endif
#endif
  HRESULT WINAPI IMailboxStoreDB_get_DataSource_Proxy(IMailboxStoreDB *This,IDataSource2 **varDataSource);
  void __RPC_STUB IMailboxStoreDB_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_Fields_Proxy(IMailboxStoreDB *This,Fields **varFields);
  void __RPC_STUB IMailboxStoreDB_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_Name_Proxy(IMailboxStoreDB *This,BSTR *pName);
  void __RPC_STUB IMailboxStoreDB_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_Name_Proxy(IMailboxStoreDB *This,BSTR varName);
  void __RPC_STUB IMailboxStoreDB_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_PublicStoreDB_Proxy(IMailboxStoreDB *This,BSTR *pPublicStoreDB);
  void __RPC_STUB IMailboxStoreDB_get_PublicStoreDB_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_PublicStoreDB_Proxy(IMailboxStoreDB *This,BSTR varPublicStoreDB);
  void __RPC_STUB IMailboxStoreDB_put_PublicStoreDB_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_OfflineAddressList_Proxy(IMailboxStoreDB *This,BSTR *pOfflineAddressList);
  void __RPC_STUB IMailboxStoreDB_get_OfflineAddressList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_OfflineAddressList_Proxy(IMailboxStoreDB *This,BSTR varOfflineAddressList);
  void __RPC_STUB IMailboxStoreDB_put_OfflineAddressList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_DBPath_Proxy(IMailboxStoreDB *This,BSTR *varDBPath);
  void __RPC_STUB IMailboxStoreDB_get_DBPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_SLVPath_Proxy(IMailboxStoreDB *This,BSTR *varSLVPath);
  void __RPC_STUB IMailboxStoreDB_get_SLVPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_Status_Proxy(IMailboxStoreDB *This,CDOEXMStoreDBStatus *varStatus);
  void __RPC_STUB IMailboxStoreDB_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_Enabled_Proxy(IMailboxStoreDB *This,VARIANT_BOOL *pEnabled);
  void __RPC_STUB IMailboxStoreDB_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_Enabled_Proxy(IMailboxStoreDB *This,VARIANT_BOOL varEnabled);
  void __RPC_STUB IMailboxStoreDB_put_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_StoreQuota_Proxy(IMailboxStoreDB *This,__LONG32 *pStoreQuota);
  void __RPC_STUB IMailboxStoreDB_get_StoreQuota_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_StoreQuota_Proxy(IMailboxStoreDB *This,__LONG32 varStoreQuota);
  void __RPC_STUB IMailboxStoreDB_put_StoreQuota_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_OverQuotaLimit_Proxy(IMailboxStoreDB *This,__LONG32 *pOverQuotaLimit);
  void __RPC_STUB IMailboxStoreDB_get_OverQuotaLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_OverQuotaLimit_Proxy(IMailboxStoreDB *This,__LONG32 varOverQuotaLimit);
  void __RPC_STUB IMailboxStoreDB_put_OverQuotaLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_HardLimit_Proxy(IMailboxStoreDB *This,__LONG32 *pHardLimit);
  void __RPC_STUB IMailboxStoreDB_get_HardLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_HardLimit_Proxy(IMailboxStoreDB *This,__LONG32 varHardLimit);
  void __RPC_STUB IMailboxStoreDB_put_HardLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_DaysBeforeGarbageCollection_Proxy(IMailboxStoreDB *This,__LONG32 *pDaysBeforeGarbageCollection);
  void __RPC_STUB IMailboxStoreDB_get_DaysBeforeGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_DaysBeforeGarbageCollection_Proxy(IMailboxStoreDB *This,__LONG32 varDaysBeforeGarbageCollection);
  void __RPC_STUB IMailboxStoreDB_put_DaysBeforeGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_DaysBeforeDeletedMailboxCleanup_Proxy(IMailboxStoreDB *This,__LONG32 *pDaysBeforeDeletedMailboxCleanup);
  void __RPC_STUB IMailboxStoreDB_get_DaysBeforeDeletedMailboxCleanup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_DaysBeforeDeletedMailboxCleanup_Proxy(IMailboxStoreDB *This,__LONG32 varDaysBeforeDeletedMailboxCleanup);
  void __RPC_STUB IMailboxStoreDB_put_DaysBeforeDeletedMailboxCleanup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_get_GarbageCollectOnlyAfterBackup_Proxy(IMailboxStoreDB *This,VARIANT_BOOL *pGarbageCollectOnlyAfterBackup);
  void __RPC_STUB IMailboxStoreDB_get_GarbageCollectOnlyAfterBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_put_GarbageCollectOnlyAfterBackup_Proxy(IMailboxStoreDB *This,VARIANT_BOOL varGarbageCollectOnlyAfterBackup);
  void __RPC_STUB IMailboxStoreDB_put_GarbageCollectOnlyAfterBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_GetInterface_Proxy(IMailboxStoreDB *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IMailboxStoreDB_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_MoveDataFiles_Proxy(IMailboxStoreDB *This,BSTR DBPath,BSTR SLVPath,__LONG32 Flags);
  void __RPC_STUB IMailboxStoreDB_MoveDataFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_Mount_Proxy(IMailboxStoreDB *This,__LONG32 Timeout);
  void __RPC_STUB IMailboxStoreDB_Mount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStoreDB_Dismount_Proxy(IMailboxStoreDB *This,__LONG32 Timeout);
  void __RPC_STUB IMailboxStoreDB_Dismount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IFolderTree_INTERFACE_DEFINED__
#define __IFolderTree_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IFolderTree;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IFolderTree : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DataSource(IDataSource2 **varDataSource) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR varName) = 0;
    virtual HRESULT WINAPI get_StoreDBs(VARIANT *varStoreDBs) = 0;
    virtual HRESULT WINAPI get_TreeType(CDOEXMFolderTreeType *varTreeType) = 0;
    virtual HRESULT WINAPI get_RootFolderURL(BSTR *varRootFolderURL) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
  };
#else
  typedef struct IFolderTreeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IFolderTree *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IFolderTree *This);
      ULONG (WINAPI *Release)(IFolderTree *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IFolderTree *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IFolderTree *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IFolderTree *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IFolderTree *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DataSource)(IFolderTree *This,IDataSource2 **varDataSource);
      HRESULT (WINAPI *get_Fields)(IFolderTree *This,Fields **varFields);
      HRESULT (WINAPI *get_Name)(IFolderTree *This,BSTR *pName);
      HRESULT (WINAPI *put_Name)(IFolderTree *This,BSTR varName);
      HRESULT (WINAPI *get_StoreDBs)(IFolderTree *This,VARIANT *varStoreDBs);
      HRESULT (WINAPI *get_TreeType)(IFolderTree *This,CDOEXMFolderTreeType *varTreeType);
      HRESULT (WINAPI *get_RootFolderURL)(IFolderTree *This,BSTR *varRootFolderURL);
      HRESULT (WINAPI *GetInterface)(IFolderTree *This,BSTR Interface,IDispatch **ppUnknown);
    END_INTERFACE
  } IFolderTreeVtbl;
  struct IFolderTree {
    CONST_VTBL struct IFolderTreeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IFolderTree_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFolderTree_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFolderTree_Release(This) (This)->lpVtbl->Release(This)
#define IFolderTree_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IFolderTree_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IFolderTree_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IFolderTree_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IFolderTree_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IFolderTree_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IFolderTree_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define IFolderTree_put_Name(This,varName) (This)->lpVtbl->put_Name(This,varName)
#define IFolderTree_get_StoreDBs(This,varStoreDBs) (This)->lpVtbl->get_StoreDBs(This,varStoreDBs)
#define IFolderTree_get_TreeType(This,varTreeType) (This)->lpVtbl->get_TreeType(This,varTreeType)
#define IFolderTree_get_RootFolderURL(This,varRootFolderURL) (This)->lpVtbl->get_RootFolderURL(This,varRootFolderURL)
#define IFolderTree_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#endif
#endif
  HRESULT WINAPI IFolderTree_get_DataSource_Proxy(IFolderTree *This,IDataSource2 **varDataSource);
  void __RPC_STUB IFolderTree_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolderTree_get_Fields_Proxy(IFolderTree *This,Fields **varFields);
  void __RPC_STUB IFolderTree_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolderTree_get_Name_Proxy(IFolderTree *This,BSTR *pName);
  void __RPC_STUB IFolderTree_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolderTree_put_Name_Proxy(IFolderTree *This,BSTR varName);
  void __RPC_STUB IFolderTree_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolderTree_get_StoreDBs_Proxy(IFolderTree *This,VARIANT *varStoreDBs);
  void __RPC_STUB IFolderTree_get_StoreDBs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolderTree_get_TreeType_Proxy(IFolderTree *This,CDOEXMFolderTreeType *varTreeType);
  void __RPC_STUB IFolderTree_get_TreeType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolderTree_get_RootFolderURL_Proxy(IFolderTree *This,BSTR *varRootFolderURL);
  void __RPC_STUB IFolderTree_get_RootFolderURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolderTree_GetInterface_Proxy(IFolderTree *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IFolderTree_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDataSource2_INTERFACE_DEFINED__
#define __IDataSource2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDataSource2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDataSource2 : public IDataSource {
  public:
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI MoveToContainer(BSTR ContainerURL) = 0;
  };
#else
  typedef struct IDataSource2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDataSource2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDataSource2 *This);
      ULONG (WINAPI *Release)(IDataSource2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDataSource2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDataSource2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDataSource2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDataSource2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SourceClass)(IDataSource2 *This,BSTR *varSourceClass);
      HRESULT (WINAPI *get_Source)(IDataSource2 *This,IUnknown **varSource);
      HRESULT (WINAPI *get_IsDirty)(IDataSource2 *This,VARIANT_BOOL *pIsDirty);
      HRESULT (WINAPI *put_IsDirty)(IDataSource2 *This,VARIANT_BOOL varIsDirty);
      HRESULT (WINAPI *get_SourceURL)(IDataSource2 *This,BSTR *varSourceURL);
      HRESULT (WINAPI *get_ActiveConnection)(IDataSource2 *This,_Connection **varActiveConnection);
      HRESULT (WINAPI *SaveToObject)(IDataSource2 *This,IUnknown *Source,BSTR InterfaceName);
      HRESULT (WINAPI *OpenObject)(IDataSource2 *This,IUnknown *Source,BSTR InterfaceName);
      HRESULT (WINAPI *SaveTo)(IDataSource2 *This,BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
      HRESULT (WINAPI *Open)(IDataSource2 *This,BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
      HRESULT (WINAPI *Save)(IDataSource2 *This);
      HRESULT (WINAPI *SaveToContainer)(IDataSource2 *This,BSTR ContainerURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
      HRESULT (WINAPI *Delete)(IDataSource2 *This);
      HRESULT (WINAPI *MoveToContainer)(IDataSource2 *This,BSTR ContainerURL);
    END_INTERFACE
  } IDataSource2Vtbl;
  struct IDataSource2 {
    CONST_VTBL struct IDataSource2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDataSource2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDataSource2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDataSource2_Release(This) (This)->lpVtbl->Release(This)
#define IDataSource2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDataSource2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDataSource2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDataSource2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDataSource2_get_SourceClass(This,varSourceClass) (This)->lpVtbl->get_SourceClass(This,varSourceClass)
#define IDataSource2_get_Source(This,varSource) (This)->lpVtbl->get_Source(This,varSource)
#define IDataSource2_get_IsDirty(This,pIsDirty) (This)->lpVtbl->get_IsDirty(This,pIsDirty)
#define IDataSource2_put_IsDirty(This,varIsDirty) (This)->lpVtbl->put_IsDirty(This,varIsDirty)
#define IDataSource2_get_SourceURL(This,varSourceURL) (This)->lpVtbl->get_SourceURL(This,varSourceURL)
#define IDataSource2_get_ActiveConnection(This,varActiveConnection) (This)->lpVtbl->get_ActiveConnection(This,varActiveConnection)
#define IDataSource2_SaveToObject(This,Source,InterfaceName) (This)->lpVtbl->SaveToObject(This,Source,InterfaceName)
#define IDataSource2_OpenObject(This,Source,InterfaceName) (This)->lpVtbl->OpenObject(This,Source,InterfaceName)
#define IDataSource2_SaveTo(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password) (This)->lpVtbl->SaveTo(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password)
#define IDataSource2_Open(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password) (This)->lpVtbl->Open(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password)
#define IDataSource2_Save(This) (This)->lpVtbl->Save(This)
#define IDataSource2_SaveToContainer(This,ContainerURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password) (This)->lpVtbl->SaveToContainer(This,ContainerURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password)
#define IDataSource2_Delete(This) (This)->lpVtbl->Delete(This)
#define IDataSource2_MoveToContainer(This,ContainerURL) (This)->lpVtbl->MoveToContainer(This,ContainerURL)
#endif
#endif
  HRESULT WINAPI IDataSource2_Delete_Proxy(IDataSource2 *This);
  void __RPC_STUB IDataSource2_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource2_MoveToContainer_Proxy(IDataSource2 *This,BSTR ContainerURL);
  void __RPC_STUB IDataSource2_MoveToContainer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
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
