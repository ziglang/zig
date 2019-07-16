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

#ifndef __txcoord_h__
#define __txcoord_h__

#ifndef __ITransactionResourceAsync_FWD_DEFINED__
#define __ITransactionResourceAsync_FWD_DEFINED__
typedef struct ITransactionResourceAsync ITransactionResourceAsync;
#endif

#ifndef __ITransactionLastResourceAsync_FWD_DEFINED__
#define __ITransactionLastResourceAsync_FWD_DEFINED__
typedef struct ITransactionLastResourceAsync ITransactionLastResourceAsync;
#endif

#ifndef __ITransactionResource_FWD_DEFINED__
#define __ITransactionResource_FWD_DEFINED__
typedef struct ITransactionResource ITransactionResource;
#endif

#ifndef __ITransactionEnlistmentAsync_FWD_DEFINED__
#define __ITransactionEnlistmentAsync_FWD_DEFINED__
typedef struct ITransactionEnlistmentAsync ITransactionEnlistmentAsync;
#endif

#ifndef __ITransactionLastEnlistmentAsync_FWD_DEFINED__
#define __ITransactionLastEnlistmentAsync_FWD_DEFINED__
typedef struct ITransactionLastEnlistmentAsync ITransactionLastEnlistmentAsync;
#endif

#ifndef __ITransactionExportFactory_FWD_DEFINED__
#define __ITransactionExportFactory_FWD_DEFINED__
typedef struct ITransactionExportFactory ITransactionExportFactory;
#endif

#ifndef __ITransactionImportWhereabouts_FWD_DEFINED__
#define __ITransactionImportWhereabouts_FWD_DEFINED__
typedef struct ITransactionImportWhereabouts ITransactionImportWhereabouts;
#endif

#ifndef __ITransactionExport_FWD_DEFINED__
#define __ITransactionExport_FWD_DEFINED__
typedef struct ITransactionExport ITransactionExport;
#endif

#ifndef __ITransactionImport_FWD_DEFINED__
#define __ITransactionImport_FWD_DEFINED__
typedef struct ITransactionImport ITransactionImport;
#endif

#ifndef __ITipTransaction_FWD_DEFINED__
#define __ITipTransaction_FWD_DEFINED__
typedef struct ITipTransaction ITipTransaction;
#endif

#ifndef __ITipHelper_FWD_DEFINED__
#define __ITipHelper_FWD_DEFINED__
typedef struct ITipHelper ITipHelper;
#endif

#ifndef __ITipPullSink_FWD_DEFINED__
#define __ITipPullSink_FWD_DEFINED__
typedef struct ITipPullSink ITipPullSink;
#endif

#ifndef __IDtcNetworkAccessConfig_FWD_DEFINED__
#define __IDtcNetworkAccessConfig_FWD_DEFINED__
typedef struct IDtcNetworkAccessConfig IDtcNetworkAccessConfig;
#endif

#ifndef __IDtcNetworkAccessConfig2_FWD_DEFINED__
#define __IDtcNetworkAccessConfig2_FWD_DEFINED__
typedef struct IDtcNetworkAccessConfig2 IDtcNetworkAccessConfig2;
#endif

#include "transact.h"
#include "objidl.h"
#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_txcoord_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_txcoord_0000_v0_0_s_ifspec;

#ifndef __ITransactionResourceAsync_INTERFACE_DEFINED__
#define __ITransactionResourceAsync_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ITransactionResourceAsync;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionResourceAsync : public IUnknown {
  public:
    virtual HRESULT WINAPI PrepareRequest(WINBOOL fRetaining,DWORD grfRM,WINBOOL fWantMoniker,WINBOOL fSinglePhase) = 0;
    virtual HRESULT WINAPI CommitRequest(DWORD grfRM,XACTUOW *pNewUOW) = 0;
    virtual HRESULT WINAPI AbortRequest(BOID *pboidReason,WINBOOL fRetaining,XACTUOW *pNewUOW) = 0;
    virtual HRESULT WINAPI TMDown(void) = 0;
  };
#else
  typedef struct ITransactionResourceAsyncVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionResourceAsync *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionResourceAsync *This);
      ULONG (WINAPI *Release)(ITransactionResourceAsync *This);
      HRESULT (WINAPI *PrepareRequest)(ITransactionResourceAsync *This,WINBOOL fRetaining,DWORD grfRM,WINBOOL fWantMoniker,WINBOOL fSinglePhase);
      HRESULT (WINAPI *CommitRequest)(ITransactionResourceAsync *This,DWORD grfRM,XACTUOW *pNewUOW);
      HRESULT (WINAPI *AbortRequest)(ITransactionResourceAsync *This,BOID *pboidReason,WINBOOL fRetaining,XACTUOW *pNewUOW);
      HRESULT (WINAPI *TMDown)(ITransactionResourceAsync *This);
    END_INTERFACE
  } ITransactionResourceAsyncVtbl;
  struct ITransactionResourceAsync {
    CONST_VTBL struct ITransactionResourceAsyncVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionResourceAsync_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionResourceAsync_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionResourceAsync_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionResourceAsync_PrepareRequest(This,fRetaining,grfRM,fWantMoniker,fSinglePhase) (This)->lpVtbl->PrepareRequest(This,fRetaining,grfRM,fWantMoniker,fSinglePhase)
#define ITransactionResourceAsync_CommitRequest(This,grfRM,pNewUOW) (This)->lpVtbl->CommitRequest(This,grfRM,pNewUOW)
#define ITransactionResourceAsync_AbortRequest(This,pboidReason,fRetaining,pNewUOW) (This)->lpVtbl->AbortRequest(This,pboidReason,fRetaining,pNewUOW)
#define ITransactionResourceAsync_TMDown(This) (This)->lpVtbl->TMDown(This)
#endif
#endif
  HRESULT WINAPI ITransactionResourceAsync_PrepareRequest_Proxy(ITransactionResourceAsync *This,WINBOOL fRetaining,DWORD grfRM,WINBOOL fWantMoniker,WINBOOL fSinglePhase);
  void __RPC_STUB ITransactionResourceAsync_PrepareRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionResourceAsync_CommitRequest_Proxy(ITransactionResourceAsync *This,DWORD grfRM,XACTUOW *pNewUOW);
  void __RPC_STUB ITransactionResourceAsync_CommitRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionResourceAsync_AbortRequest_Proxy(ITransactionResourceAsync *This,BOID *pboidReason,WINBOOL fRetaining,XACTUOW *pNewUOW);
  void __RPC_STUB ITransactionResourceAsync_AbortRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionResourceAsync_TMDown_Proxy(ITransactionResourceAsync *This);
  void __RPC_STUB ITransactionResourceAsync_TMDown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionLastResourceAsync_INTERFACE_DEFINED__
#define __ITransactionLastResourceAsync_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionLastResourceAsync;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionLastResourceAsync : public IUnknown {
  public:
    virtual HRESULT WINAPI DelegateCommit(DWORD grfRM) = 0;
    virtual HRESULT WINAPI ForgetRequest(XACTUOW *pNewUOW) = 0;
  };
#else
  typedef struct ITransactionLastResourceAsyncVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionLastResourceAsync *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionLastResourceAsync *This);
      ULONG (WINAPI *Release)(ITransactionLastResourceAsync *This);
      HRESULT (WINAPI *DelegateCommit)(ITransactionLastResourceAsync *This,DWORD grfRM);
      HRESULT (WINAPI *ForgetRequest)(ITransactionLastResourceAsync *This,XACTUOW *pNewUOW);
    END_INTERFACE
  } ITransactionLastResourceAsyncVtbl;
  struct ITransactionLastResourceAsync {
    CONST_VTBL struct ITransactionLastResourceAsyncVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionLastResourceAsync_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionLastResourceAsync_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionLastResourceAsync_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionLastResourceAsync_DelegateCommit(This,grfRM) (This)->lpVtbl->DelegateCommit(This,grfRM)
#define ITransactionLastResourceAsync_ForgetRequest(This,pNewUOW) (This)->lpVtbl->ForgetRequest(This,pNewUOW)
#endif
#endif
  HRESULT WINAPI ITransactionLastResourceAsync_DelegateCommit_Proxy(ITransactionLastResourceAsync *This,DWORD grfRM);
  void __RPC_STUB ITransactionLastResourceAsync_DelegateCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionLastResourceAsync_ForgetRequest_Proxy(ITransactionLastResourceAsync *This,XACTUOW *pNewUOW);
  void __RPC_STUB ITransactionLastResourceAsync_ForgetRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionResource_INTERFACE_DEFINED__
#define __ITransactionResource_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionResource;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionResource : public IUnknown {
  public:
    virtual HRESULT WINAPI PrepareRequest(WINBOOL fRetaining,DWORD grfRM,WINBOOL fWantMoniker,WINBOOL fSinglePhase) = 0;
    virtual HRESULT WINAPI CommitRequest(DWORD grfRM,XACTUOW *pNewUOW) = 0;
    virtual HRESULT WINAPI AbortRequest(BOID *pboidReason,WINBOOL fRetaining,XACTUOW *pNewUOW) = 0;
    virtual HRESULT WINAPI TMDown(void) = 0;
  };
#else
  typedef struct ITransactionResourceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionResource *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionResource *This);
      ULONG (WINAPI *Release)(ITransactionResource *This);
      HRESULT (WINAPI *PrepareRequest)(ITransactionResource *This,WINBOOL fRetaining,DWORD grfRM,WINBOOL fWantMoniker,WINBOOL fSinglePhase);
      HRESULT (WINAPI *CommitRequest)(ITransactionResource *This,DWORD grfRM,XACTUOW *pNewUOW);
      HRESULT (WINAPI *AbortRequest)(ITransactionResource *This,BOID *pboidReason,WINBOOL fRetaining,XACTUOW *pNewUOW);
      HRESULT (WINAPI *TMDown)(ITransactionResource *This);
    END_INTERFACE
  } ITransactionResourceVtbl;
  struct ITransactionResource {
    CONST_VTBL struct ITransactionResourceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionResource_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionResource_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionResource_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionResource_PrepareRequest(This,fRetaining,grfRM,fWantMoniker,fSinglePhase) (This)->lpVtbl->PrepareRequest(This,fRetaining,grfRM,fWantMoniker,fSinglePhase)
#define ITransactionResource_CommitRequest(This,grfRM,pNewUOW) (This)->lpVtbl->CommitRequest(This,grfRM,pNewUOW)
#define ITransactionResource_AbortRequest(This,pboidReason,fRetaining,pNewUOW) (This)->lpVtbl->AbortRequest(This,pboidReason,fRetaining,pNewUOW)
#define ITransactionResource_TMDown(This) (This)->lpVtbl->TMDown(This)
#endif
#endif
  HRESULT WINAPI ITransactionResource_PrepareRequest_Proxy(ITransactionResource *This,WINBOOL fRetaining,DWORD grfRM,WINBOOL fWantMoniker,WINBOOL fSinglePhase);
  void __RPC_STUB ITransactionResource_PrepareRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionResource_CommitRequest_Proxy(ITransactionResource *This,DWORD grfRM,XACTUOW *pNewUOW);
  void __RPC_STUB ITransactionResource_CommitRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionResource_AbortRequest_Proxy(ITransactionResource *This,BOID *pboidReason,WINBOOL fRetaining,XACTUOW *pNewUOW);
  void __RPC_STUB ITransactionResource_AbortRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionResource_TMDown_Proxy(ITransactionResource *This);
  void __RPC_STUB ITransactionResource_TMDown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionEnlistmentAsync_INTERFACE_DEFINED__
#define __ITransactionEnlistmentAsync_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionEnlistmentAsync;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionEnlistmentAsync : public IUnknown {
  public:
    virtual HRESULT WINAPI PrepareRequestDone(HRESULT hr,IMoniker *pmk,BOID *pboidReason) = 0;
    virtual HRESULT WINAPI CommitRequestDone(HRESULT hr) = 0;
    virtual HRESULT WINAPI AbortRequestDone(HRESULT hr) = 0;
  };
#else
  typedef struct ITransactionEnlistmentAsyncVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionEnlistmentAsync *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionEnlistmentAsync *This);
      ULONG (WINAPI *Release)(ITransactionEnlistmentAsync *This);
      HRESULT (WINAPI *PrepareRequestDone)(ITransactionEnlistmentAsync *This,HRESULT hr,IMoniker *pmk,BOID *pboidReason);
      HRESULT (WINAPI *CommitRequestDone)(ITransactionEnlistmentAsync *This,HRESULT hr);
      HRESULT (WINAPI *AbortRequestDone)(ITransactionEnlistmentAsync *This,HRESULT hr);
    END_INTERFACE
  } ITransactionEnlistmentAsyncVtbl;
  struct ITransactionEnlistmentAsync {
    CONST_VTBL struct ITransactionEnlistmentAsyncVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionEnlistmentAsync_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionEnlistmentAsync_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionEnlistmentAsync_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionEnlistmentAsync_PrepareRequestDone(This,hr,pmk,pboidReason) (This)->lpVtbl->PrepareRequestDone(This,hr,pmk,pboidReason)
#define ITransactionEnlistmentAsync_CommitRequestDone(This,hr) (This)->lpVtbl->CommitRequestDone(This,hr)
#define ITransactionEnlistmentAsync_AbortRequestDone(This,hr) (This)->lpVtbl->AbortRequestDone(This,hr)
#endif
#endif
  HRESULT WINAPI ITransactionEnlistmentAsync_PrepareRequestDone_Proxy(ITransactionEnlistmentAsync *This,HRESULT hr,IMoniker *pmk,BOID *pboidReason);
  void __RPC_STUB ITransactionEnlistmentAsync_PrepareRequestDone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionEnlistmentAsync_CommitRequestDone_Proxy(ITransactionEnlistmentAsync *This,HRESULT hr);
  void __RPC_STUB ITransactionEnlistmentAsync_CommitRequestDone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionEnlistmentAsync_AbortRequestDone_Proxy(ITransactionEnlistmentAsync *This,HRESULT hr);
  void __RPC_STUB ITransactionEnlistmentAsync_AbortRequestDone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionLastEnlistmentAsync_INTERFACE_DEFINED__
#define __ITransactionLastEnlistmentAsync_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionLastEnlistmentAsync;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionLastEnlistmentAsync : public IUnknown {
  public:
    virtual HRESULT WINAPI TransactionOutcome(XACTSTAT XactStat,BOID *pboidReason) = 0;
  };
#else
  typedef struct ITransactionLastEnlistmentAsyncVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionLastEnlistmentAsync *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionLastEnlistmentAsync *This);
      ULONG (WINAPI *Release)(ITransactionLastEnlistmentAsync *This);
      HRESULT (WINAPI *TransactionOutcome)(ITransactionLastEnlistmentAsync *This,XACTSTAT XactStat,BOID *pboidReason);
    END_INTERFACE
  } ITransactionLastEnlistmentAsyncVtbl;
  struct ITransactionLastEnlistmentAsync {
    CONST_VTBL struct ITransactionLastEnlistmentAsyncVtbl *lpVtbl;
  };
#ifdef COBJMACROS
  define ITransactionLastEnlistmentAsync_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionLastEnlistmentAsync_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionLastEnlistmentAsync_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionLastEnlistmentAsync_TransactionOutcome(This,XactStat,pboidReason) (This)->lpVtbl->TransactionOutcome(This,XactStat,pboidReason)
#endif
#endif
    HRESULT WINAPI ITransactionLastEnlistmentAsync_TransactionOutcome_Proxy(ITransactionLastEnlistmentAsync *This,XACTSTAT XactStat,BOID *pboidReason);
  void __RPC_STUB ITransactionLastEnlistmentAsync_TransactionOutcome_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionExportFactory_INTERFACE_DEFINED__
#define __ITransactionExportFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionExportFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionExportFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRemoteClassId(CLSID *pclsid) = 0;
    virtual HRESULT WINAPI Create(ULONG cbWhereabouts,byte *rgbWhereabouts,ITransactionExport **ppExport) = 0;
  };
#else
  typedef struct ITransactionExportFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionExportFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionExportFactory *This);
      ULONG (WINAPI *Release)(ITransactionExportFactory *This);
      HRESULT (WINAPI *GetRemoteClassId)(ITransactionExportFactory *This,CLSID *pclsid);
      HRESULT (WINAPI *Create)(ITransactionExportFactory *This,ULONG cbWhereabouts,byte *rgbWhereabouts,ITransactionExport **ppExport);
    END_INTERFACE
  } ITransactionExportFactoryVtbl;
  struct ITransactionExportFactory {
    CONST_VTBL struct ITransactionExportFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionExportFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionExportFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionExportFactory_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionExportFactory_GetRemoteClassId(This,pclsid) (This)->lpVtbl->GetRemoteClassId(This,pclsid)
#define ITransactionExportFactory_Create(This,cbWhereabouts,rgbWhereabouts,ppExport) (This)->lpVtbl->Create(This,cbWhereabouts,rgbWhereabouts,ppExport)
#endif
#endif
  HRESULT WINAPI ITransactionExportFactory_GetRemoteClassId_Proxy(ITransactionExportFactory *This,CLSID *pclsid);
  void __RPC_STUB ITransactionExportFactory_GetRemoteClassId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionExportFactory_Create_Proxy(ITransactionExportFactory *This,ULONG cbWhereabouts,byte *rgbWhereabouts,ITransactionExport **ppExport);
  void __RPC_STUB ITransactionExportFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionImportWhereabouts_INTERFACE_DEFINED__
#define __ITransactionImportWhereabouts_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionImportWhereabouts;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionImportWhereabouts : public IUnknown {
  public:
    virtual HRESULT WINAPI GetWhereaboutsSize(ULONG *pcbWhereabouts) = 0;
    virtual HRESULT WINAPI GetWhereabouts(ULONG cbWhereabouts,byte *rgbWhereabouts,ULONG *pcbUsed) = 0;
  };
#else
  typedef struct ITransactionImportWhereaboutsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionImportWhereabouts *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionImportWhereabouts *This);
      ULONG (WINAPI *Release)(ITransactionImportWhereabouts *This);
      HRESULT (WINAPI *GetWhereaboutsSize)(ITransactionImportWhereabouts *This,ULONG *pcbWhereabouts);
      HRESULT (WINAPI *GetWhereabouts)(ITransactionImportWhereabouts *This,ULONG cbWhereabouts,byte *rgbWhereabouts,ULONG *pcbUsed);
    END_INTERFACE
  } ITransactionImportWhereaboutsVtbl;
  struct ITransactionImportWhereabouts {
    CONST_VTBL struct ITransactionImportWhereaboutsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionImportWhereabouts_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionImportWhereabouts_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionImportWhereabouts_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionImportWhereabouts_GetWhereaboutsSize(This,pcbWhereabouts) (This)->lpVtbl->GetWhereaboutsSize(This,pcbWhereabouts)
#define ITransactionImportWhereabouts_GetWhereabouts(This,cbWhereabouts,rgbWhereabouts,pcbUsed) (This)->lpVtbl->GetWhereabouts(This,cbWhereabouts,rgbWhereabouts,pcbUsed)
#endif
#endif
  HRESULT WINAPI ITransactionImportWhereabouts_GetWhereaboutsSize_Proxy(ITransactionImportWhereabouts *This,ULONG *pcbWhereabouts);
  void __RPC_STUB ITransactionImportWhereabouts_GetWhereaboutsSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionImportWhereabouts_RemoteGetWhereabouts_Proxy(ITransactionImportWhereabouts *This,ULONG *pcbUsed,ULONG cbWhereabouts,byte *rgbWhereabouts);
  void __RPC_STUB ITransactionImportWhereabouts_RemoteGetWhereabouts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionExport_INTERFACE_DEFINED__
#define __ITransactionExport_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionExport;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionExport : public IUnknown {
  public:
    virtual HRESULT WINAPI Export(IUnknown *punkTransaction,ULONG *pcbTransactionCookie) = 0;
    virtual HRESULT WINAPI GetTransactionCookie(IUnknown *punkTransaction,ULONG cbTransactionCookie,byte *rgbTransactionCookie,ULONG *pcbUsed) = 0;
  };
#else
  typedef struct ITransactionExportVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionExport *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionExport *This);
      ULONG (WINAPI *Release)(ITransactionExport *This);
      HRESULT (WINAPI *Export)(ITransactionExport *This,IUnknown *punkTransaction,ULONG *pcbTransactionCookie);
      HRESULT (WINAPI *GetTransactionCookie)(ITransactionExport *This,IUnknown *punkTransaction,ULONG cbTransactionCookie,byte *rgbTransactionCookie,ULONG *pcbUsed);
    END_INTERFACE
  } ITransactionExportVtbl;
  struct ITransactionExport {
    CONST_VTBL struct ITransactionExportVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionExport_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionExport_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionExport_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionExport_Export(This,punkTransaction,pcbTransactionCookie) (This)->lpVtbl->Export(This,punkTransaction,pcbTransactionCookie)
#define ITransactionExport_GetTransactionCookie(This,punkTransaction,cbTransactionCookie,rgbTransactionCookie,pcbUsed) (This)->lpVtbl->GetTransactionCookie(This,punkTransaction,cbTransactionCookie,rgbTransactionCookie,pcbUsed)
#endif
#endif
  HRESULT WINAPI ITransactionExport_Export_Proxy(ITransactionExport *This,IUnknown *punkTransaction,ULONG *pcbTransactionCookie);
  void __RPC_STUB ITransactionExport_Export_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionExport_RemoteGetTransactionCookie_Proxy(ITransactionExport *This,IUnknown *punkTransaction,ULONG *pcbUsed,ULONG cbTransactionCookie,byte *rgbTransactionCookie);
  void __RPC_STUB ITransactionExport_RemoteGetTransactionCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionImport_INTERFACE_DEFINED__
#define __ITransactionImport_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionImport;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionImport : public IUnknown {
  public:
    virtual HRESULT WINAPI Import(ULONG cbTransactionCookie,byte *rgbTransactionCookie,IID *piid,void **ppvTransaction) = 0;
  };
#else
  typedef struct ITransactionImportVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionImport *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionImport *This);
      ULONG (WINAPI *Release)(ITransactionImport *This);
      HRESULT (WINAPI *Import)(ITransactionImport *This,ULONG cbTransactionCookie,byte *rgbTransactionCookie,IID *piid,void **ppvTransaction);
    END_INTERFACE
  } ITransactionImportVtbl;
  struct ITransactionImport {
    CONST_VTBL struct ITransactionImportVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionImport_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionImport_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionImport_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionImport_Import(This,cbTransactionCookie,rgbTransactionCookie,piid,ppvTransaction) (This)->lpVtbl->Import(This,cbTransactionCookie,rgbTransactionCookie,piid,ppvTransaction)
#endif
#endif
  HRESULT WINAPI ITransactionImport_Import_Proxy(ITransactionImport *This,ULONG cbTransactionCookie,byte *rgbTransactionCookie,IID *piid,void **ppvTransaction);
  void __RPC_STUB ITransactionImport_Import_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITipTransaction_INTERFACE_DEFINED__
#define __ITipTransaction_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITipTransaction;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITipTransaction : public IUnknown {
  public:
    virtual HRESULT WINAPI Push(char *i_pszRemoteTmUrl,char **o_ppszRemoteTxUrl) = 0;
    virtual HRESULT WINAPI GetTransactionUrl(char **o_ppszLocalTxUrl) = 0;
  };
#else
  typedef struct ITipTransactionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITipTransaction *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITipTransaction *This);
      ULONG (WINAPI *Release)(ITipTransaction *This);
      HRESULT (WINAPI *Push)(ITipTransaction *This,char *i_pszRemoteTmUrl,char **o_ppszRemoteTxUrl);
      HRESULT (WINAPI *GetTransactionUrl)(ITipTransaction *This,char **o_ppszLocalTxUrl);
    END_INTERFACE
  } ITipTransactionVtbl;
  struct ITipTransaction {
    CONST_VTBL struct ITipTransactionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITipTransaction_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITipTransaction_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITipTransaction_Release(This) (This)->lpVtbl->Release(This)
#define ITipTransaction_Push(This,i_pszRemoteTmUrl,o_ppszRemoteTxUrl) (This)->lpVtbl->Push(This,i_pszRemoteTmUrl,o_ppszRemoteTxUrl)
#define ITipTransaction_GetTransactionUrl(This,o_ppszLocalTxUrl) (This)->lpVtbl->GetTransactionUrl(This,o_ppszLocalTxUrl)
#endif
#endif
  HRESULT WINAPI ITipTransaction_Push_Proxy(ITipTransaction *This,char *i_pszRemoteTmUrl,char **o_ppszRemoteTxUrl);
  void __RPC_STUB ITipTransaction_Push_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITipTransaction_GetTransactionUrl_Proxy(ITipTransaction *This,char **o_ppszLocalTxUrl);
  void __RPC_STUB ITipTransaction_GetTransactionUrl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITipHelper_INTERFACE_DEFINED__
#define __ITipHelper_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITipHelper;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITipHelper : public IUnknown {
  public:
    virtual HRESULT WINAPI Pull(char *i_pszTxUrl,ITransaction **o_ppITransaction) = 0;
    virtual HRESULT WINAPI PullAsync(char *i_pszTxUrl,ITipPullSink *i_pTipPullSink,ITransaction **o_ppITransaction) = 0;
    virtual HRESULT WINAPI GetLocalTmUrl(char **o_ppszLocalTmUrl) = 0;
  };
#else
  typedef struct ITipHelperVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITipHelper *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITipHelper *This);
      ULONG (WINAPI *Release)(ITipHelper *This);
      HRESULT (WINAPI *Pull)(ITipHelper *This,char *i_pszTxUrl,ITransaction **o_ppITransaction);
      HRESULT (WINAPI *PullAsync)(ITipHelper *This,char *i_pszTxUrl,ITipPullSink *i_pTipPullSink,ITransaction **o_ppITransaction);
      HRESULT (WINAPI *GetLocalTmUrl)(ITipHelper *This,char **o_ppszLocalTmUrl);
    END_INTERFACE
  } ITipHelperVtbl;
  struct ITipHelper {
    CONST_VTBL struct ITipHelperVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITipHelper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITipHelper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITipHelper_Release(This) (This)->lpVtbl->Release(This)
#define ITipHelper_Pull(This,i_pszTxUrl,o_ppITransaction) (This)->lpVtbl->Pull(This,i_pszTxUrl,o_ppITransaction)
#define ITipHelper_PullAsync(This,i_pszTxUrl,i_pTipPullSink,o_ppITransaction) (This)->lpVtbl->PullAsync(This,i_pszTxUrl,i_pTipPullSink,o_ppITransaction)
#define ITipHelper_GetLocalTmUrl(This,o_ppszLocalTmUrl) (This)->lpVtbl->GetLocalTmUrl(This,o_ppszLocalTmUrl)
#endif
#endif
  HRESULT WINAPI ITipHelper_Pull_Proxy(ITipHelper *This,char *i_pszTxUrl,ITransaction **o_ppITransaction);
  void __RPC_STUB ITipHelper_Pull_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITipHelper_PullAsync_Proxy(ITipHelper *This,char *i_pszTxUrl,ITipPullSink *i_pTipPullSink,ITransaction **o_ppITransaction);
  void __RPC_STUB ITipHelper_PullAsync_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITipHelper_GetLocalTmUrl_Proxy(ITipHelper *This,char **o_ppszLocalTmUrl);
  void __RPC_STUB ITipHelper_GetLocalTmUrl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITipPullSink_INTERFACE_DEFINED__
#define __ITipPullSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITipPullSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITipPullSink : public IUnknown {
  public:
    virtual HRESULT WINAPI PullComplete(HRESULT i_hrPull) = 0;
  };
#else
  typedef struct ITipPullSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITipPullSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITipPullSink *This);
      ULONG (WINAPI *Release)(ITipPullSink *This);
      HRESULT (WINAPI *PullComplete)(ITipPullSink *This,HRESULT i_hrPull);
    END_INTERFACE
  } ITipPullSinkVtbl;
  struct ITipPullSink {
    CONST_VTBL struct ITipPullSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITipPullSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITipPullSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITipPullSink_Release(This) (This)->lpVtbl->Release(This)
#define ITipPullSink_PullComplete(This,i_hrPull) (This)->lpVtbl->PullComplete(This,i_hrPull)
#endif
#endif
  HRESULT WINAPI ITipPullSink_PullComplete_Proxy(ITipPullSink *This,HRESULT i_hrPull);
  void __RPC_STUB ITipPullSink_PullComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcNetworkAccessConfig_INTERFACE_DEFINED__
#define __IDtcNetworkAccessConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcNetworkAccessConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcNetworkAccessConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI GetAnyNetworkAccess(WINBOOL *pbAnyNetworkAccess) = 0;
    virtual HRESULT WINAPI SetAnyNetworkAccess(WINBOOL bAnyNetworkAccess) = 0;
    virtual HRESULT WINAPI GetNetworkAdministrationAccess(WINBOOL *pbNetworkAdministrationAccess) = 0;
    virtual HRESULT WINAPI SetNetworkAdministrationAccess(WINBOOL bNetworkAdministrationAccess) = 0;
    virtual HRESULT WINAPI GetNetworkTransactionAccess(WINBOOL *pbNetworkTransactionAccess) = 0;
    virtual HRESULT WINAPI SetNetworkTransactionAccess(WINBOOL bNetworkTransactionAccess) = 0;
    virtual HRESULT WINAPI GetNetworkClientAccess(WINBOOL *pbNetworkClientAccess) = 0;
    virtual HRESULT WINAPI SetNetworkClientAccess(WINBOOL bNetworkClientAccess) = 0;
    virtual HRESULT WINAPI GetNetworkTIPAccess(WINBOOL *pbNetworkTIPAccess) = 0;
    virtual HRESULT WINAPI SetNetworkTIPAccess(WINBOOL bNetworkTIPAccess) = 0;
    virtual HRESULT WINAPI GetXAAccess(WINBOOL *pbXAAccess) = 0;
    virtual HRESULT WINAPI SetXAAccess(WINBOOL bXAAccess) = 0;
    virtual HRESULT WINAPI RestartDtcService(void) = 0;
  };
#else
  typedef struct IDtcNetworkAccessConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcNetworkAccessConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcNetworkAccessConfig *This);
      ULONG (WINAPI *Release)(IDtcNetworkAccessConfig *This);
      HRESULT (WINAPI *GetAnyNetworkAccess)(IDtcNetworkAccessConfig *This,WINBOOL *pbAnyNetworkAccess);
      HRESULT (WINAPI *SetAnyNetworkAccess)(IDtcNetworkAccessConfig *This,WINBOOL bAnyNetworkAccess);
      HRESULT (WINAPI *GetNetworkAdministrationAccess)(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkAdministrationAccess);
      HRESULT (WINAPI *SetNetworkAdministrationAccess)(IDtcNetworkAccessConfig *This,WINBOOL bNetworkAdministrationAccess);
      HRESULT (WINAPI *GetNetworkTransactionAccess)(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkTransactionAccess);
      HRESULT (WINAPI *SetNetworkTransactionAccess)(IDtcNetworkAccessConfig *This,WINBOOL bNetworkTransactionAccess);
      HRESULT (WINAPI *GetNetworkClientAccess)(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkClientAccess);
      HRESULT (WINAPI *SetNetworkClientAccess)(IDtcNetworkAccessConfig *This,WINBOOL bNetworkClientAccess);
      HRESULT (WINAPI *GetNetworkTIPAccess)(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkTIPAccess);
      HRESULT (WINAPI *SetNetworkTIPAccess)(IDtcNetworkAccessConfig *This,WINBOOL bNetworkTIPAccess);
      HRESULT (WINAPI *GetXAAccess)(IDtcNetworkAccessConfig *This,WINBOOL *pbXAAccess);
      HRESULT (WINAPI *SetXAAccess)(IDtcNetworkAccessConfig *This,WINBOOL bXAAccess);
      HRESULT (WINAPI *RestartDtcService)(IDtcNetworkAccessConfig *This);
    END_INTERFACE
  } IDtcNetworkAccessConfigVtbl;
  struct IDtcNetworkAccessConfig {
    CONST_VTBL struct IDtcNetworkAccessConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcNetworkAccessConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcNetworkAccessConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcNetworkAccessConfig_Release(This) (This)->lpVtbl->Release(This)
#define IDtcNetworkAccessConfig_GetAnyNetworkAccess(This,pbAnyNetworkAccess) (This)->lpVtbl->GetAnyNetworkAccess(This,pbAnyNetworkAccess)
#define IDtcNetworkAccessConfig_SetAnyNetworkAccess(This,bAnyNetworkAccess) (This)->lpVtbl->SetAnyNetworkAccess(This,bAnyNetworkAccess)
#define IDtcNetworkAccessConfig_GetNetworkAdministrationAccess(This,pbNetworkAdministrationAccess) (This)->lpVtbl->GetNetworkAdministrationAccess(This,pbNetworkAdministrationAccess)
#define IDtcNetworkAccessConfig_SetNetworkAdministrationAccess(This,bNetworkAdministrationAccess) (This)->lpVtbl->SetNetworkAdministrationAccess(This,bNetworkAdministrationAccess)
#define IDtcNetworkAccessConfig_GetNetworkTransactionAccess(This,pbNetworkTransactionAccess) (This)->lpVtbl->GetNetworkTransactionAccess(This,pbNetworkTransactionAccess)
#define IDtcNetworkAccessConfig_SetNetworkTransactionAccess(This,bNetworkTransactionAccess) (This)->lpVtbl->SetNetworkTransactionAccess(This,bNetworkTransactionAccess)
#define IDtcNetworkAccessConfig_GetNetworkClientAccess(This,pbNetworkClientAccess) (This)->lpVtbl->GetNetworkClientAccess(This,pbNetworkClientAccess)
#define IDtcNetworkAccessConfig_SetNetworkClientAccess(This,bNetworkClientAccess) (This)->lpVtbl->SetNetworkClientAccess(This,bNetworkClientAccess)
#define IDtcNetworkAccessConfig_GetNetworkTIPAccess(This,pbNetworkTIPAccess) (This)->lpVtbl->GetNetworkTIPAccess(This,pbNetworkTIPAccess)
#define IDtcNetworkAccessConfig_SetNetworkTIPAccess(This,bNetworkTIPAccess) (This)->lpVtbl->SetNetworkTIPAccess(This,bNetworkTIPAccess)
#define IDtcNetworkAccessConfig_GetXAAccess(This,pbXAAccess) (This)->lpVtbl->GetXAAccess(This,pbXAAccess)
#define IDtcNetworkAccessConfig_SetXAAccess(This,bXAAccess) (This)->lpVtbl->SetXAAccess(This,bXAAccess)
#define IDtcNetworkAccessConfig_RestartDtcService(This) (This)->lpVtbl->RestartDtcService(This)
#endif
#endif
  HRESULT WINAPI IDtcNetworkAccessConfig_GetAnyNetworkAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL *pbAnyNetworkAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_GetAnyNetworkAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_SetAnyNetworkAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL bAnyNetworkAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_SetAnyNetworkAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_GetNetworkAdministrationAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkAdministrationAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_GetNetworkAdministrationAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_SetNetworkAdministrationAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL bNetworkAdministrationAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_SetNetworkAdministrationAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_GetNetworkTransactionAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkTransactionAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_GetNetworkTransactionAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_SetNetworkTransactionAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL bNetworkTransactionAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_SetNetworkTransactionAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_GetNetworkClientAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkClientAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_GetNetworkClientAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_SetNetworkClientAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL bNetworkClientAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_SetNetworkClientAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_GetNetworkTIPAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL *pbNetworkTIPAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_GetNetworkTIPAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_SetNetworkTIPAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL bNetworkTIPAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_SetNetworkTIPAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_GetXAAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL *pbXAAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_GetXAAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_SetXAAccess_Proxy(IDtcNetworkAccessConfig *This,WINBOOL bXAAccess);
  void __RPC_STUB IDtcNetworkAccessConfig_SetXAAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig_RestartDtcService_Proxy(IDtcNetworkAccessConfig *This);
  void __RPC_STUB IDtcNetworkAccessConfig_RestartDtcService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum AUTHENTICATION_LEVEL {
    NO_AUTHENTICATION_REQUIRED = 0,INCOMING_AUTHENTICATION_REQUIRED = 1,MUTUAL_AUTHENTICATION_REQUIRED = 2
  } AUTHENTICATION_LEVEL;

  extern RPC_IF_HANDLE __MIDL_itf_txcoord_0115_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_txcoord_0115_v0_0_s_ifspec;

#ifndef __IDtcNetworkAccessConfig2_INTERFACE_DEFINED__
#define __IDtcNetworkAccessConfig2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcNetworkAccessConfig2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcNetworkAccessConfig2 : public IDtcNetworkAccessConfig {
  public:
    virtual HRESULT WINAPI GetNetworkInboundAccess(WINBOOL *pbInbound) = 0;
    virtual HRESULT WINAPI GetNetworkOutboundAccess(WINBOOL *pbOutbound) = 0;
    virtual HRESULT WINAPI SetNetworkInboundAccess(WINBOOL bInbound) = 0;
    virtual HRESULT WINAPI SetNetworkOutboundAccess(WINBOOL bOutbound) = 0;
    virtual HRESULT WINAPI GetAuthenticationLevel(AUTHENTICATION_LEVEL *pAuthLevel) = 0;
    virtual HRESULT WINAPI SetAuthenticationLevel(AUTHENTICATION_LEVEL AuthLevel) = 0;
  };
#else
  typedef struct IDtcNetworkAccessConfig2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcNetworkAccessConfig2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcNetworkAccessConfig2 *This);
      ULONG (WINAPI *Release)(IDtcNetworkAccessConfig2 *This);
      HRESULT (WINAPI *GetAnyNetworkAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbAnyNetworkAccess);
      HRESULT (WINAPI *SetAnyNetworkAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bAnyNetworkAccess);
      HRESULT (WINAPI *GetNetworkAdministrationAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbNetworkAdministrationAccess);
      HRESULT (WINAPI *SetNetworkAdministrationAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bNetworkAdministrationAccess);
      HRESULT (WINAPI *GetNetworkTransactionAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbNetworkTransactionAccess);
      HRESULT (WINAPI *SetNetworkTransactionAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bNetworkTransactionAccess);
      HRESULT (WINAPI *GetNetworkClientAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbNetworkClientAccess);
      HRESULT (WINAPI *SetNetworkClientAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bNetworkClientAccess);
      HRESULT (WINAPI *GetNetworkTIPAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbNetworkTIPAccess);
      HRESULT (WINAPI *SetNetworkTIPAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bNetworkTIPAccess);
      HRESULT (WINAPI *GetXAAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbXAAccess);
      HRESULT (WINAPI *SetXAAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bXAAccess);
      HRESULT (WINAPI *RestartDtcService)(IDtcNetworkAccessConfig2 *This);
      HRESULT (WINAPI *GetNetworkInboundAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbInbound);
      HRESULT (WINAPI *GetNetworkOutboundAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL *pbOutbound);
      HRESULT (WINAPI *SetNetworkInboundAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bInbound);
      HRESULT (WINAPI *SetNetworkOutboundAccess)(IDtcNetworkAccessConfig2 *This,WINBOOL bOutbound);
      HRESULT (WINAPI *GetAuthenticationLevel)(IDtcNetworkAccessConfig2 *This,AUTHENTICATION_LEVEL *pAuthLevel);
      HRESULT (WINAPI *SetAuthenticationLevel)(IDtcNetworkAccessConfig2 *This,AUTHENTICATION_LEVEL AuthLevel);
    END_INTERFACE
  } IDtcNetworkAccessConfig2Vtbl;
  struct IDtcNetworkAccessConfig2 {
    CONST_VTBL struct IDtcNetworkAccessConfig2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcNetworkAccessConfig2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcNetworkAccessConfig2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcNetworkAccessConfig2_Release(This) (This)->lpVtbl->Release(This)
#define IDtcNetworkAccessConfig2_GetAnyNetworkAccess(This,pbAnyNetworkAccess) (This)->lpVtbl->GetAnyNetworkAccess(This,pbAnyNetworkAccess)
#define IDtcNetworkAccessConfig2_SetAnyNetworkAccess(This,bAnyNetworkAccess) (This)->lpVtbl->SetAnyNetworkAccess(This,bAnyNetworkAccess)
#define IDtcNetworkAccessConfig2_GetNetworkAdministrationAccess(This,pbNetworkAdministrationAccess) (This)->lpVtbl->GetNetworkAdministrationAccess(This,pbNetworkAdministrationAccess)
#define IDtcNetworkAccessConfig2_SetNetworkAdministrationAccess(This,bNetworkAdministrationAccess) (This)->lpVtbl->SetNetworkAdministrationAccess(This,bNetworkAdministrationAccess)
#define IDtcNetworkAccessConfig2_GetNetworkTransactionAccess(This,pbNetworkTransactionAccess) (This)->lpVtbl->GetNetworkTransactionAccess(This,pbNetworkTransactionAccess)
#define IDtcNetworkAccessConfig2_SetNetworkTransactionAccess(This,bNetworkTransactionAccess) (This)->lpVtbl->SetNetworkTransactionAccess(This,bNetworkTransactionAccess)
#define IDtcNetworkAccessConfig2_GetNetworkClientAccess(This,pbNetworkClientAccess) (This)->lpVtbl->GetNetworkClientAccess(This,pbNetworkClientAccess)
#define IDtcNetworkAccessConfig2_SetNetworkClientAccess(This,bNetworkClientAccess) (This)->lpVtbl->SetNetworkClientAccess(This,bNetworkClientAccess)
#define IDtcNetworkAccessConfig2_GetNetworkTIPAccess(This,pbNetworkTIPAccess) (This)->lpVtbl->GetNetworkTIPAccess(This,pbNetworkTIPAccess)
#define IDtcNetworkAccessConfig2_SetNetworkTIPAccess(This,bNetworkTIPAccess) (This)->lpVtbl->SetNetworkTIPAccess(This,bNetworkTIPAccess)
#define IDtcNetworkAccessConfig2_GetXAAccess(This,pbXAAccess) (This)->lpVtbl->GetXAAccess(This,pbXAAccess)
#define IDtcNetworkAccessConfig2_SetXAAccess(This,bXAAccess) (This)->lpVtbl->SetXAAccess(This,bXAAccess)
#define IDtcNetworkAccessConfig2_RestartDtcService(This) (This)->lpVtbl->RestartDtcService(This)
#define IDtcNetworkAccessConfig2_GetNetworkInboundAccess(This,pbInbound) (This)->lpVtbl->GetNetworkInboundAccess(This,pbInbound)
#define IDtcNetworkAccessConfig2_GetNetworkOutboundAccess(This,pbOutbound) (This)->lpVtbl->GetNetworkOutboundAccess(This,pbOutbound)
#define IDtcNetworkAccessConfig2_SetNetworkInboundAccess(This,bInbound) (This)->lpVtbl->SetNetworkInboundAccess(This,bInbound)
#define IDtcNetworkAccessConfig2_SetNetworkOutboundAccess(This,bOutbound) (This)->lpVtbl->SetNetworkOutboundAccess(This,bOutbound)
#define IDtcNetworkAccessConfig2_GetAuthenticationLevel(This,pAuthLevel) (This)->lpVtbl->GetAuthenticationLevel(This,pAuthLevel)
#define IDtcNetworkAccessConfig2_SetAuthenticationLevel(This,AuthLevel) (This)->lpVtbl->SetAuthenticationLevel(This,AuthLevel)
#endif
#endif
  HRESULT WINAPI IDtcNetworkAccessConfig2_GetNetworkInboundAccess_Proxy(IDtcNetworkAccessConfig2 *This,WINBOOL *pbInbound);
  void __RPC_STUB IDtcNetworkAccessConfig2_GetNetworkInboundAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig2_GetNetworkOutboundAccess_Proxy(IDtcNetworkAccessConfig2 *This,WINBOOL *pbOutbound);
  void __RPC_STUB IDtcNetworkAccessConfig2_GetNetworkOutboundAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig2_SetNetworkInboundAccess_Proxy(IDtcNetworkAccessConfig2 *This,WINBOOL bInbound);
  void __RPC_STUB IDtcNetworkAccessConfig2_SetNetworkInboundAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig2_SetNetworkOutboundAccess_Proxy(IDtcNetworkAccessConfig2 *This,WINBOOL bOutbound);
  void __RPC_STUB IDtcNetworkAccessConfig2_SetNetworkOutboundAccess_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig2_GetAuthenticationLevel_Proxy(IDtcNetworkAccessConfig2 *This,AUTHENTICATION_LEVEL *pAuthLevel);
  void __RPC_STUB IDtcNetworkAccessConfig2_GetAuthenticationLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcNetworkAccessConfig2_SetAuthenticationLevel_Proxy(IDtcNetworkAccessConfig2 *This,AUTHENTICATION_LEVEL AuthLevel);
  void __RPC_STUB IDtcNetworkAccessConfig2_SetAuthenticationLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(IID_ITransactionResourceAsync,0x69E971F0,0x23CE,0x11cf,0xAD,0x60,0x00,0xAA,0x00,0xA7,0x4C,0xCD);
  DEFINE_GUID(IID_ITransactionLastResourceAsync,0xC82BD532,0x5B30,0x11D3,0x8A,0x91,0x00,0xC0,0x4F,0x79,0xEB,0x6D);
  DEFINE_GUID(IID_ITransactionResource,0xEE5FF7B3,0x4572,0x11d0,0x94,0x52,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_ITransactionEnlistmentAsync,0x0fb15081,0xaf41,0x11ce,0xbd,0x2b,0x20,0x4c,0x4f,0x4f,0x50,0x20);
  DEFINE_GUID(IID_ITransactionLastEnlistmentAsync,0xC82BD533,0x5B30,0x11D3,0x8A,0x91,0x00,0xC0,0x4F,0x79,0xEB,0x6D);
  DEFINE_GUID(IID_ITransactionExportFactory,0xE1CF9B53,0x8745,0x11ce,0xA9,0xBA,0x00,0xAA,0x00,0x6C,0x37,0x06);
  DEFINE_GUID(IID_ITransactionImportWhereabouts,0x0141fda4,0x8fc0,0x11ce,0xbd,0x18,0x20,0x4c,0x4f,0x4f,0x50,0x20);
  DEFINE_GUID(IID_ITransactionExport,0x0141fda5,0x8fc0,0x11ce,0xbd,0x18,0x20,0x4c,0x4f,0x4f,0x50,0x20);
  DEFINE_GUID(IID_ITransactionImport,0xE1CF9B5A,0x8745,0x11ce,0xA9,0xBA,0x00,0xAA,0x00,0x6C,0x37,0x06);
  DEFINE_GUID(IID_ITipTransaction,0x17cf72d0,0xbac5,0x11d1,0xb1,0xbf,0x0,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_ITipHelper,0x17cf72d1,0xbac5,0x11d1,0xb1,0xbf,0x0,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_ITipPullSink,0x17cf72d2,0xbac5,0x11d1,0xb1,0xbf,0x0,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_IDtcNetworkAccessConfig,0x9797c15d,0xa428,0x4291,0x87,0xb6,0x9,0x95,0x3,0x1a,0x67,0x8d);
  DEFINE_GUID(IID_IDtcNetworkAccessConfig2,0xa7aa013b,0xeb7d,0x4f42,0xb4,0x1c,0xb2,0xde,0xc0,0x9a,0xe0,0x34);

  extern RPC_IF_HANDLE __MIDL_itf_txcoord_0116_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_txcoord_0116_v0_0_s_ifspec;

  HRESULT WINAPI ITransactionImportWhereabouts_GetWhereabouts_Proxy(ITransactionImportWhereabouts *This,ULONG cbWhereabouts,byte *rgbWhereabouts,ULONG *pcbUsed);
  HRESULT WINAPI ITransactionImportWhereabouts_GetWhereabouts_Stub(ITransactionImportWhereabouts *This,ULONG *pcbUsed,ULONG cbWhereabouts,byte *rgbWhereabouts);
  HRESULT WINAPI ITransactionExport_GetTransactionCookie_Proxy(ITransactionExport *This,IUnknown *punkTransaction,ULONG cbTransactionCookie,byte *rgbTransactionCookie,ULONG *pcbUsed);
  HRESULT WINAPI ITransactionExport_GetTransactionCookie_Stub(ITransactionExport *This,IUnknown *punkTransaction,ULONG *pcbUsed,ULONG cbTransactionCookie,byte *rgbTransactionCookie);

#ifdef __cplusplus
}
#endif
#endif
