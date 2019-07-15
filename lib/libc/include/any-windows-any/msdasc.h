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

#ifndef __msdasc_h__
#define __msdasc_h__

#ifndef __IService_FWD_DEFINED__
#define __IService_FWD_DEFINED__
typedef struct IService IService;
#endif

#ifndef __IDBPromptInitialize_FWD_DEFINED__
#define __IDBPromptInitialize_FWD_DEFINED__
typedef struct IDBPromptInitialize IDBPromptInitialize;
#endif

#ifndef __IDataInitialize_FWD_DEFINED__
#define __IDataInitialize_FWD_DEFINED__
typedef struct IDataInitialize IDataInitialize;
#endif

#ifndef __IDataSourceLocator_FWD_DEFINED__
#define __IDataSourceLocator_FWD_DEFINED__
typedef struct IDataSourceLocator IDataSourceLocator;
#endif

#ifndef __DataLinks_FWD_DEFINED__
#define __DataLinks_FWD_DEFINED__
#ifdef __cplusplus
typedef class DataLinks DataLinks;
#else
typedef struct DataLinks DataLinks;
#endif
#endif

#ifndef __MSDAINITIALIZE_FWD_DEFINED__
#define __MSDAINITIALIZE_FWD_DEFINED__
#ifdef __cplusplus
typedef class MSDAINITIALIZE MSDAINITIALIZE;
#else
typedef struct MSDAINITIALIZE MSDAINITIALIZE;
#endif
#endif

#ifndef __PDPO_FWD_DEFINED__
#define __PDPO_FWD_DEFINED__
#ifdef __cplusplus
typedef class PDPO PDPO;
#else
typedef struct PDPO PDPO;
#endif
#endif

#ifndef __RootBinder_FWD_DEFINED__
#define __RootBinder_FWD_DEFINED__
#ifdef __cplusplus
typedef class RootBinder RootBinder;
#else
typedef struct RootBinder RootBinder;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "oledb.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifdef _WIN64
  typedef LONGLONG COMPATIBLE_LONG;
#else
  typedef LONG COMPATIBLE_LONG;
#endif
  typedef enum tagEBindInfoOptions {
    BIO_BINDER = 0x1
  } EBindInfoOptions;

#define STGM_COLLECTION __MSABI_LONG(0x00002000)
#define STGM_OUTPUT __MSABI_LONG(0x00008000)
#define STGM_OPEN __MSABI_LONG(0x80000000)
#define STGM_RECURSIVE __MSABI_LONG(0x01000000)
#define STGM_STRICTOPEN __MSABI_LONG(0x40000000)

  extern RPC_IF_HANDLE __MIDL_itf_msdasc_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msdasc_0000_v0_0_s_ifspec;

#ifndef __IService_INTERFACE_DEFINED__
#define __IService_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IService;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IService : public IUnknown {
  public:
    virtual HRESULT WINAPI InvokeService(IUnknown *pUnkInner) = 0;
  };
#else
  typedef struct IServiceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IService *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IService *This);
      ULONG (WINAPI *Release)(IService *This);
      HRESULT (WINAPI *InvokeService)(IService *This,IUnknown *pUnkInner);
    END_INTERFACE
  } IServiceVtbl;
  struct IService {
    CONST_VTBL struct IServiceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IService_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IService_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IService_Release(This) (This)->lpVtbl->Release(This)
#define IService_InvokeService(This,pUnkInner) (This)->lpVtbl->InvokeService(This,pUnkInner)
#endif
#endif
  HRESULT WINAPI IService_InvokeService_Proxy(IService *This,IUnknown *pUnkInner);
  void __RPC_STUB IService_InvokeService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef DWORD DBPROMPTOPTIONS;

  typedef enum tagDBPROMPTOPTIONSENUM {
    DBPROMPTOPTIONS_NONE = 0,DBPROMPTOPTIONS_WIZARDSHEET = 0x1,DBPROMPTOPTIONS_PROPERTYSHEET = 0x2,DBPROMPTOPTIONS_BROWSEONLY = 0x8,
    DBPROMPTOPTIONS_DISABLE_PROVIDER_SELECTION = 0x10,DBPROMPTOPTIONS_DISABLESAVEPASSWORD = 0x20
  } DBPROMPTOPTIONSENUM;

  extern RPC_IF_HANDLE __MIDL_itf_msdasc_0359_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msdasc_0359_v0_0_s_ifspec;

#ifndef __IDBPromptInitialize_INTERFACE_DEFINED__
#define __IDBPromptInitialize_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBPromptInitialize;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBPromptInitialize : public IUnknown {
  public:
    virtual HRESULT WINAPI PromptDataSource(IUnknown *pUnkOuter,HWND hWndParent,DBPROMPTOPTIONS dwPromptOptions,ULONG cSourceTypeFilter,DBSOURCETYPE *rgSourceTypeFilter,LPCOLESTR pwszszzProviderFilter,REFIID riid,IUnknown **ppDataSource) = 0;
    virtual HRESULT WINAPI PromptFileName(HWND hWndParent,DBPROMPTOPTIONS dwPromptOptions,LPCOLESTR pwszInitialDirectory,LPCOLESTR pwszInitialFile,LPOLESTR *ppwszSelectedFile) = 0;
  };
#else
  typedef struct IDBPromptInitializeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBPromptInitialize *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBPromptInitialize *This);
      ULONG (WINAPI *Release)(IDBPromptInitialize *This);
      HRESULT (WINAPI *PromptDataSource)(IDBPromptInitialize *This,IUnknown *pUnkOuter,HWND hWndParent,DBPROMPTOPTIONS dwPromptOptions,ULONG cSourceTypeFilter,DBSOURCETYPE *rgSourceTypeFilter,LPCOLESTR pwszszzProviderFilter,REFIID riid,IUnknown **ppDataSource);
      HRESULT (WINAPI *PromptFileName)(IDBPromptInitialize *This,HWND hWndParent,DBPROMPTOPTIONS dwPromptOptions,LPCOLESTR pwszInitialDirectory,LPCOLESTR pwszInitialFile,LPOLESTR *ppwszSelectedFile);
    END_INTERFACE
  } IDBPromptInitializeVtbl;
  struct IDBPromptInitialize {
    CONST_VTBL struct IDBPromptInitializeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBPromptInitialize_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBPromptInitialize_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBPromptInitialize_Release(This) (This)->lpVtbl->Release(This)
#define IDBPromptInitialize_PromptDataSource(This,pUnkOuter,hWndParent,dwPromptOptions,cSourceTypeFilter,rgSourceTypeFilter,pwszszzProviderFilter,riid,ppDataSource) (This)->lpVtbl->PromptDataSource(This,pUnkOuter,hWndParent,dwPromptOptions,cSourceTypeFilter,rgSourceTypeFilter,pwszszzProviderFilter,riid,ppDataSource)
#define IDBPromptInitialize_PromptFileName(This,hWndParent,dwPromptOptions,pwszInitialDirectory,pwszInitialFile,ppwszSelectedFile) (This)->lpVtbl->PromptFileName(This,hWndParent,dwPromptOptions,pwszInitialDirectory,pwszInitialFile,ppwszSelectedFile)
#endif
#endif
  HRESULT WINAPI IDBPromptInitialize_PromptDataSource_Proxy(IDBPromptInitialize *This,IUnknown *pUnkOuter,HWND hWndParent,DBPROMPTOPTIONS dwPromptOptions,ULONG cSourceTypeFilter,DBSOURCETYPE *rgSourceTypeFilter,LPCOLESTR pwszszzProviderFilter,REFIID riid,IUnknown **ppDataSource);
  void __RPC_STUB IDBPromptInitialize_PromptDataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBPromptInitialize_PromptFileName_Proxy(IDBPromptInitialize *This,HWND hWndParent,DBPROMPTOPTIONS dwPromptOptions,LPCOLESTR pwszInitialDirectory,LPCOLESTR pwszInitialFile,LPOLESTR *ppwszSelectedFile);
  void __RPC_STUB IDBPromptInitialize_PromptFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDataInitialize_INTERFACE_DEFINED__
#define __IDataInitialize_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDataInitialize;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDataInitialize : public IUnknown {
  public:
    virtual HRESULT WINAPI GetDataSource(IUnknown *pUnkOuter,DWORD dwClsCtx,LPCOLESTR pwszInitializationString,REFIID riid,IUnknown **ppDataSource) = 0;
    virtual HRESULT WINAPI GetInitializationString(IUnknown *pDataSource,boolean fIncludePassword,LPOLESTR *ppwszInitString) = 0;
    virtual HRESULT WINAPI CreateDBInstance(REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,REFIID riid,IUnknown **ppDataSource) = 0;
    virtual HRESULT WINAPI CreateDBInstanceEx(REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,COSERVERINFO *pServerInfo,ULONG cmq,MULTI_QI *rgmqResults) = 0;
    virtual HRESULT WINAPI LoadStringFromStorage(LPCOLESTR pwszFileName,LPOLESTR *ppwszInitializationString) = 0;
    virtual HRESULT WINAPI WriteStringToStorage(LPCOLESTR pwszFileName,LPCOLESTR pwszInitializationString,DWORD dwCreationDisposition) = 0;
  };
#else
  typedef struct IDataInitializeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDataInitialize *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDataInitialize *This);
      ULONG (WINAPI *Release)(IDataInitialize *This);
      HRESULT (WINAPI *GetDataSource)(IDataInitialize *This,IUnknown *pUnkOuter,DWORD dwClsCtx,LPCOLESTR pwszInitializationString,REFIID riid,IUnknown **ppDataSource);
      HRESULT (WINAPI *GetInitializationString)(IDataInitialize *This,IUnknown *pDataSource,boolean fIncludePassword,LPOLESTR *ppwszInitString);
      HRESULT (WINAPI *CreateDBInstance)(IDataInitialize *This,REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,REFIID riid,IUnknown **ppDataSource);
      HRESULT (WINAPI *CreateDBInstanceEx)(IDataInitialize *This,REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,COSERVERINFO *pServerInfo,ULONG cmq,MULTI_QI *rgmqResults);
      HRESULT (WINAPI *LoadStringFromStorage)(IDataInitialize *This,LPCOLESTR pwszFileName,LPOLESTR *ppwszInitializationString);
      HRESULT (WINAPI *WriteStringToStorage)(IDataInitialize *This,LPCOLESTR pwszFileName,LPCOLESTR pwszInitializationString,DWORD dwCreationDisposition);
    END_INTERFACE
  } IDataInitializeVtbl;
  struct IDataInitialize {
    CONST_VTBL struct IDataInitializeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDataInitialize_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDataInitialize_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDataInitialize_Release(This) (This)->lpVtbl->Release(This)
#define IDataInitialize_GetDataSource(This,pUnkOuter,dwClsCtx,pwszInitializationString,riid,ppDataSource) (This)->lpVtbl->GetDataSource(This,pUnkOuter,dwClsCtx,pwszInitializationString,riid,ppDataSource)
#define IDataInitialize_GetInitializationString(This,pDataSource,fIncludePassword,ppwszInitString) (This)->lpVtbl->GetInitializationString(This,pDataSource,fIncludePassword,ppwszInitString)
#define IDataInitialize_CreateDBInstance(This,clsidProvider,pUnkOuter,dwClsCtx,pwszReserved,riid,ppDataSource) (This)->lpVtbl->CreateDBInstance(This,clsidProvider,pUnkOuter,dwClsCtx,pwszReserved,riid,ppDataSource)
#define IDataInitialize_CreateDBInstanceEx(This,clsidProvider,pUnkOuter,dwClsCtx,pwszReserved,pServerInfo,cmq,rgmqResults) (This)->lpVtbl->CreateDBInstanceEx(This,clsidProvider,pUnkOuter,dwClsCtx,pwszReserved,pServerInfo,cmq,rgmqResults)
#define IDataInitialize_LoadStringFromStorage(This,pwszFileName,ppwszInitializationString) (This)->lpVtbl->LoadStringFromStorage(This,pwszFileName,ppwszInitializationString)
#define IDataInitialize_WriteStringToStorage(This,pwszFileName,pwszInitializationString,dwCreationDisposition) (This)->lpVtbl->WriteStringToStorage(This,pwszFileName,pwszInitializationString,dwCreationDisposition)
#endif
#endif
  HRESULT WINAPI IDataInitialize_GetDataSource_Proxy(IDataInitialize *This,IUnknown *pUnkOuter,DWORD dwClsCtx,LPCOLESTR pwszInitializationString,REFIID riid,IUnknown **ppDataSource);
  void __RPC_STUB IDataInitialize_GetDataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataInitialize_GetInitializationString_Proxy(IDataInitialize *This,IUnknown *pDataSource,boolean fIncludePassword,LPOLESTR *ppwszInitString);
  void __RPC_STUB IDataInitialize_GetInitializationString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataInitialize_CreateDBInstance_Proxy(IDataInitialize *This,REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,REFIID riid,IUnknown **ppDataSource);
  void __RPC_STUB IDataInitialize_CreateDBInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataInitialize_RemoteCreateDBInstanceEx_Proxy(IDataInitialize *This,REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,COSERVERINFO *pServerInfo,ULONG cmq,const IID **rgpIID,IUnknown **rgpItf,HRESULT *rghr);
  void __RPC_STUB IDataInitialize_RemoteCreateDBInstanceEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataInitialize_LoadStringFromStorage_Proxy(IDataInitialize *This,LPCOLESTR pwszFileName,LPOLESTR *ppwszInitializationString);
  void __RPC_STUB IDataInitialize_LoadStringFromStorage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataInitialize_WriteStringToStorage_Proxy(IDataInitialize *This,LPCOLESTR pwszFileName,LPCOLESTR pwszInitializationString,DWORD dwCreationDisposition);
  void __RPC_STUB IDataInitialize_WriteStringToStorage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __MSDASC_LIBRARY_DEFINED__
#define __MSDASC_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_MSDASC;
#ifndef __IDataSourceLocator_INTERFACE_DEFINED__
#define __IDataSourceLocator_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDataSourceLocator;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDataSourceLocator : public IDispatch {
  public:
    virtual HRESULT WINAPI get_hWnd(COMPATIBLE_LONG *phwndParent) = 0;
    virtual HRESULT WINAPI put_hWnd(COMPATIBLE_LONG hwndParent) = 0;
    virtual HRESULT WINAPI PromptNew(IDispatch **ppADOConnection) = 0;
    virtual HRESULT WINAPI PromptEdit(IDispatch **ppADOConnection,VARIANT_BOOL *pbSuccess) = 0;
  };
#else
  typedef struct IDataSourceLocatorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDataSourceLocator *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDataSourceLocator *This);
      ULONG (WINAPI *Release)(IDataSourceLocator *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDataSourceLocator *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDataSourceLocator *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDataSourceLocator *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDataSourceLocator *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_hWnd)(IDataSourceLocator *This,COMPATIBLE_LONG *phwndParent);
      HRESULT (WINAPI *put_hWnd)(IDataSourceLocator *This,COMPATIBLE_LONG hwndParent);
      HRESULT (WINAPI *PromptNew)(IDataSourceLocator *This,IDispatch **ppADOConnection);
      HRESULT (WINAPI *PromptEdit)(IDataSourceLocator *This,IDispatch **ppADOConnection,VARIANT_BOOL *pbSuccess);
    END_INTERFACE
  } IDataSourceLocatorVtbl;
  struct IDataSourceLocator {
    CONST_VTBL struct IDataSourceLocatorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDataSourceLocator_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDataSourceLocator_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDataSourceLocator_Release(This) (This)->lpVtbl->Release(This)
#define IDataSourceLocator_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDataSourceLocator_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDataSourceLocator_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDataSourceLocator_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDataSourceLocator_get_hWnd(This,phwndParent) (This)->lpVtbl->get_hWnd(This,phwndParent)
#define IDataSourceLocator_put_hWnd(This,hwndParent) (This)->lpVtbl->put_hWnd(This,hwndParent)
#define IDataSourceLocator_PromptNew(This,ppADOConnection) (This)->lpVtbl->PromptNew(This,ppADOConnection)
#define IDataSourceLocator_PromptEdit(This,ppADOConnection,pbSuccess) (This)->lpVtbl->PromptEdit(This,ppADOConnection,pbSuccess)
#endif
#endif
  HRESULT WINAPI IDataSourceLocator_get_hWnd_Proxy(IDataSourceLocator *This,COMPATIBLE_LONG *phwndParent);
  void __RPC_STUB IDataSourceLocator_get_hWnd_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSourceLocator_put_hWnd_Proxy(IDataSourceLocator *This,COMPATIBLE_LONG hwndParent);
  void __RPC_STUB IDataSourceLocator_put_hWnd_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSourceLocator_PromptNew_Proxy(IDataSourceLocator *This,IDispatch **ppADOConnection);
  void __RPC_STUB IDataSourceLocator_PromptNew_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSourceLocator_PromptEdit_Proxy(IDataSourceLocator *This,IDispatch **ppADOConnection,VARIANT_BOOL *pbSuccess);
  void __RPC_STUB IDataSourceLocator_PromptEdit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_DataLinks;
#ifdef __cplusplus
  class DataLinks;
#endif
  EXTERN_C const CLSID CLSID_MSDAINITIALIZE;
#ifdef __cplusplus
  class MSDAINITIALIZE;
#endif
  EXTERN_C const CLSID CLSID_PDPO;
#ifdef __cplusplus
  class PDPO;
#endif
  EXTERN_C const CLSID CLSID_RootBinder;
#ifdef __cplusplus
  class RootBinder;
#endif
#endif
  HRESULT WINAPI IDataInitialize_CreateDBInstanceEx_Proxy(IDataInitialize *This,REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,COSERVERINFO *pServerInfo,ULONG cmq,MULTI_QI *rgmqResults);
  HRESULT WINAPI IDataInitialize_CreateDBInstanceEx_Stub(IDataInitialize *This,REFCLSID clsidProvider,IUnknown *pUnkOuter,DWORD dwClsCtx,LPOLESTR pwszReserved,COSERVERINFO *pServerInfo,ULONG cmq,const IID **rgpIID,IUnknown **rgpItf,HRESULT *rghr);

#ifdef __cplusplus
}
#endif
#endif
