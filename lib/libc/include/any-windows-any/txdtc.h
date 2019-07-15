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

#ifndef __txdtc_h__
#define __txdtc_h__

#ifndef __IXATransLookup_FWD_DEFINED__
#define __IXATransLookup_FWD_DEFINED__
typedef struct IXATransLookup IXATransLookup;
#endif

#ifndef __IXATransLookup2_FWD_DEFINED__
#define __IXATransLookup2_FWD_DEFINED__
typedef struct IXATransLookup2 IXATransLookup2;
#endif

#ifndef __IResourceManagerSink_FWD_DEFINED__
#define __IResourceManagerSink_FWD_DEFINED__
typedef struct IResourceManagerSink IResourceManagerSink;
#endif

#ifndef __IResourceManager_FWD_DEFINED__
#define __IResourceManager_FWD_DEFINED__
typedef struct IResourceManager IResourceManager;
#endif

#ifndef __ILastResourceManager_FWD_DEFINED__
#define __ILastResourceManager_FWD_DEFINED__
typedef struct ILastResourceManager ILastResourceManager;
#endif

#ifndef __IResourceManager2_FWD_DEFINED__
#define __IResourceManager2_FWD_DEFINED__
typedef struct IResourceManager2 IResourceManager2;
#endif

#ifndef __IXAConfig_FWD_DEFINED__
#define __IXAConfig_FWD_DEFINED__
typedef struct IXAConfig IXAConfig;
#endif

#ifndef __IRMHelper_FWD_DEFINED__
#define __IRMHelper_FWD_DEFINED__
typedef struct IRMHelper IRMHelper;
#endif

#ifndef __IXAObtainRMInfo_FWD_DEFINED__
#define __IXAObtainRMInfo_FWD_DEFINED__
typedef struct IXAObtainRMInfo IXAObtainRMInfo;
#endif

#ifndef __IResourceManagerFactory_FWD_DEFINED__
#define __IResourceManagerFactory_FWD_DEFINED__
typedef struct IResourceManagerFactory IResourceManagerFactory;
#endif

#ifndef __IResourceManagerFactory2_FWD_DEFINED__
#define __IResourceManagerFactory2_FWD_DEFINED__
typedef struct IResourceManagerFactory2 IResourceManagerFactory2;
#endif

#ifndef __IPrepareInfo_FWD_DEFINED__
#define __IPrepareInfo_FWD_DEFINED__
typedef struct IPrepareInfo IPrepareInfo;
#endif

#ifndef __IPrepareInfo2_FWD_DEFINED__
#define __IPrepareInfo2_FWD_DEFINED__
typedef struct IPrepareInfo2 IPrepareInfo2;
#endif

#ifndef __IGetDispenser_FWD_DEFINED__
#define __IGetDispenser_FWD_DEFINED__
typedef struct IGetDispenser IGetDispenser;
#endif

#ifndef __ITransactionVoterBallotAsync2_FWD_DEFINED__
#define __ITransactionVoterBallotAsync2_FWD_DEFINED__
typedef struct ITransactionVoterBallotAsync2 ITransactionVoterBallotAsync2;
#endif

#ifndef __ITransactionVoterNotifyAsync2_FWD_DEFINED__
#define __ITransactionVoterNotifyAsync2_FWD_DEFINED__
typedef struct ITransactionVoterNotifyAsync2 ITransactionVoterNotifyAsync2;
#endif

#ifndef __ITransactionVoterFactory2_FWD_DEFINED__
#define __ITransactionVoterFactory2_FWD_DEFINED__
typedef struct ITransactionVoterFactory2 ITransactionVoterFactory2;
#endif

#ifndef __ITransactionPhase0EnlistmentAsync_FWD_DEFINED__
#define __ITransactionPhase0EnlistmentAsync_FWD_DEFINED__
typedef struct ITransactionPhase0EnlistmentAsync ITransactionPhase0EnlistmentAsync;
#endif

#ifndef __ITransactionPhase0NotifyAsync_FWD_DEFINED__
#define __ITransactionPhase0NotifyAsync_FWD_DEFINED__
typedef struct ITransactionPhase0NotifyAsync ITransactionPhase0NotifyAsync;
#endif

#ifndef __ITransactionPhase0Factory_FWD_DEFINED__
#define __ITransactionPhase0Factory_FWD_DEFINED__
typedef struct ITransactionPhase0Factory ITransactionPhase0Factory;
#endif

#ifndef __ITransactionTransmitter_FWD_DEFINED__
#define __ITransactionTransmitter_FWD_DEFINED__
typedef struct ITransactionTransmitter ITransactionTransmitter;
#endif

#ifndef __ITransactionTransmitterFactory_FWD_DEFINED__
#define __ITransactionTransmitterFactory_FWD_DEFINED__
typedef struct ITransactionTransmitterFactory ITransactionTransmitterFactory;
#endif

#ifndef __ITransactionReceiver_FWD_DEFINED__
#define __ITransactionReceiver_FWD_DEFINED__
typedef struct ITransactionReceiver ITransactionReceiver;
#endif

#ifndef __ITransactionReceiverFactory_FWD_DEFINED__
#define __ITransactionReceiverFactory_FWD_DEFINED__
typedef struct ITransactionReceiverFactory ITransactionReceiverFactory;
#endif

#ifndef __IDtcLuConfigure_FWD_DEFINED__
#define __IDtcLuConfigure_FWD_DEFINED__
typedef struct IDtcLuConfigure IDtcLuConfigure;
#endif

#ifndef __IDtcLuRecovery_FWD_DEFINED__
#define __IDtcLuRecovery_FWD_DEFINED__
typedef struct IDtcLuRecovery IDtcLuRecovery;
#endif

#ifndef __IDtcLuRecoveryFactory_FWD_DEFINED__
#define __IDtcLuRecoveryFactory_FWD_DEFINED__
typedef struct IDtcLuRecoveryFactory IDtcLuRecoveryFactory;
#endif

#ifndef __IDtcLuRecoveryInitiatedByDtcTransWork_FWD_DEFINED__
#define __IDtcLuRecoveryInitiatedByDtcTransWork_FWD_DEFINED__
typedef struct IDtcLuRecoveryInitiatedByDtcTransWork IDtcLuRecoveryInitiatedByDtcTransWork;
#endif

#ifndef __IDtcLuRecoveryInitiatedByDtcStatusWork_FWD_DEFINED__
#define __IDtcLuRecoveryInitiatedByDtcStatusWork_FWD_DEFINED__
typedef struct IDtcLuRecoveryInitiatedByDtcStatusWork IDtcLuRecoveryInitiatedByDtcStatusWork;
#endif

#ifndef __IDtcLuRecoveryInitiatedByDtc_FWD_DEFINED__
#define __IDtcLuRecoveryInitiatedByDtc_FWD_DEFINED__
typedef struct IDtcLuRecoveryInitiatedByDtc IDtcLuRecoveryInitiatedByDtc;
#endif

#ifndef __IDtcLuRecoveryInitiatedByLuWork_FWD_DEFINED__
#define __IDtcLuRecoveryInitiatedByLuWork_FWD_DEFINED__
typedef struct IDtcLuRecoveryInitiatedByLuWork IDtcLuRecoveryInitiatedByLuWork;
#endif

#ifndef __IDtcLuRecoveryInitiatedByLu_FWD_DEFINED__
#define __IDtcLuRecoveryInitiatedByLu_FWD_DEFINED__
typedef struct IDtcLuRecoveryInitiatedByLu IDtcLuRecoveryInitiatedByLu;
#endif

#ifndef __IDtcLuRmEnlistment_FWD_DEFINED__
#define __IDtcLuRmEnlistment_FWD_DEFINED__
typedef struct IDtcLuRmEnlistment IDtcLuRmEnlistment;
#endif

#ifndef __IDtcLuRmEnlistmentSink_FWD_DEFINED__
#define __IDtcLuRmEnlistmentSink_FWD_DEFINED__
typedef struct IDtcLuRmEnlistmentSink IDtcLuRmEnlistmentSink;
#endif

#ifndef __IDtcLuRmEnlistmentFactory_FWD_DEFINED__
#define __IDtcLuRmEnlistmentFactory_FWD_DEFINED__
typedef struct IDtcLuRmEnlistmentFactory IDtcLuRmEnlistmentFactory;
#endif

#ifndef __IDtcLuSubordinateDtc_FWD_DEFINED__
#define __IDtcLuSubordinateDtc_FWD_DEFINED__
typedef struct IDtcLuSubordinateDtc IDtcLuSubordinateDtc;
#endif

#ifndef __IDtcLuSubordinateDtcSink_FWD_DEFINED__
#define __IDtcLuSubordinateDtcSink_FWD_DEFINED__
typedef struct IDtcLuSubordinateDtcSink IDtcLuSubordinateDtcSink;
#endif

#ifndef __IDtcLuSubordinateDtcFactory_FWD_DEFINED__
#define __IDtcLuSubordinateDtcFactory_FWD_DEFINED__
typedef struct IDtcLuSubordinateDtcFactory IDtcLuSubordinateDtcFactory;
#endif

#include "txcoord.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define XACTTOMSG(dwXact) (dwXact-0x00040000+0x40000000)
  typedef enum XACT_DTC_CONSTANTS {
    XACT_E_CONNECTION_REQUEST_DENIED = 0x8004d100,XACT_E_TOOMANY_ENLISTMENTS = 0x8004d101,XACT_E_DUPLICATE_GUID = 0x8004d102,
    XACT_E_NOTSINGLEPHASE = 0x8004d103,XACT_E_RECOVERYALREADYDONE = 0x8004d104,XACT_E_PROTOCOL = 0x8004d105,XACT_E_RM_FAILURE = 0x8004d106,
    XACT_E_RECOVERY_FAILED = 0x8004d107,XACT_E_LU_NOT_FOUND = 0x8004d108,XACT_E_DUPLICATE_LU = 0x8004d109,XACT_E_LU_NOT_CONNECTED = 0x8004d10a,
    XACT_E_DUPLICATE_TRANSID = 0x8004d10b,XACT_E_LU_BUSY = 0x8004d10c,XACT_E_LU_NO_RECOVERY_PROCESS = 0x8004d10d,XACT_E_LU_DOWN = 0x8004d10e,
    XACT_E_LU_RECOVERING = 0x8004d10f,XACT_E_LU_RECOVERY_MISMATCH = 0x8004d110,XACT_E_RM_UNAVAILABLE = 0x8004d111,
    XACT_E_LRMRECOVERYALREADYDONE = 0x8004d112,XACT_E_NOLASTRESOURCEINTERFACE = 0x8004d113,XACT_S_NONOTIFY = 0x4d100,XACT_OK_NONOTIFY = 0x4d101,
    dwUSER_MS_SQLSERVER = 0xffff
  } XACT_DTC_CONSTANTS;

#ifndef _XID_T_DEFINED
#define _XID_T_DEFINED
  typedef struct xid_t {
    __LONG32 formatID;
    __LONG32 gtrid_length;
    __LONG32 bqual_length;
    char data[128 ];
  } XID;
#endif
#ifndef _XA_SWITCH_T_DEFINED
#define _XA_SWITCH_T_DEFINED
  typedef struct xa_switch_t {
    char name[32 ];
    __LONG32 flags;
    __LONG32 version;
    int (__cdecl *xa_open_entry)(char *__MIDL_0004,int __MIDL_0005,__LONG32 __MIDL_0006);
    int (__cdecl *xa_close_entry)(char *__MIDL_0008,int __MIDL_0009,__LONG32 __MIDL_0010);
    int (__cdecl *xa_start_entry)(XID *__MIDL_0012,int __MIDL_0013,__LONG32 __MIDL_0014);
    int (__cdecl *xa_end_entry)(XID *__MIDL_0016,int __MIDL_0017,__LONG32 __MIDL_0018);
    int (__cdecl *xa_rollback_entry)(XID *__MIDL_0020,int __MIDL_0021,__LONG32 __MIDL_0022);
    int (__cdecl *xa_prepare_entry)(XID *__MIDL_0024,int __MIDL_0025,__LONG32 __MIDL_0026);
    int (__cdecl *xa_commit_entry)(XID *__MIDL_0028,int __MIDL_0029,__LONG32 __MIDL_0030);
    int (__cdecl *xa_recover_entry)(XID *__MIDL_0032,__LONG32 __MIDL_0033,int __MIDL_0034,__LONG32 __MIDL_0035);
    int (__cdecl *xa_forget_entry)(XID *__MIDL_0037,int __MIDL_0038,__LONG32 __MIDL_0039);
    int (__cdecl *xa_complete_entry)(int *__MIDL_0041,int *__MIDL_0042,int __MIDL_0043,__LONG32 __MIDL_0044);
  } xa_switch_t;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0000_v0_0_s_ifspec;
#ifndef __IXATransLookup_INTERFACE_DEFINED__
#define __IXATransLookup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IXATransLookup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IXATransLookup : public IUnknown {
  public:
    virtual HRESULT WINAPI Lookup(ITransaction **ppTransaction) = 0;
  };
#else
  typedef struct IXATransLookupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IXATransLookup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IXATransLookup *This);
      ULONG (WINAPI *Release)(IXATransLookup *This);
      HRESULT (WINAPI *Lookup)(IXATransLookup *This,ITransaction **ppTransaction);
    END_INTERFACE
  } IXATransLookupVtbl;
  struct IXATransLookup {
    CONST_VTBL struct IXATransLookupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IXATransLookup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IXATransLookup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IXATransLookup_Release(This) (This)->lpVtbl->Release(This)
#define IXATransLookup_Lookup(This,ppTransaction) (This)->lpVtbl->Lookup(This,ppTransaction)
#endif
#endif
  HRESULT WINAPI IXATransLookup_Lookup_Proxy(IXATransLookup *This,ITransaction **ppTransaction);
  void __RPC_STUB IXATransLookup_Lookup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IXATransLookup2_INTERFACE_DEFINED__
#define __IXATransLookup2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IXATransLookup2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IXATransLookup2 : public IUnknown {
  public:
    virtual HRESULT WINAPI Lookup(XID *pXID,ITransaction **ppTransaction) = 0;
  };
#else
  typedef struct IXATransLookup2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IXATransLookup2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IXATransLookup2 *This);
      ULONG (WINAPI *Release)(IXATransLookup2 *This);
      HRESULT (WINAPI *Lookup)(IXATransLookup2 *This,XID *pXID,ITransaction **ppTransaction);
    END_INTERFACE
  } IXATransLookup2Vtbl;
  struct IXATransLookup2 {
    CONST_VTBL struct IXATransLookup2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IXATransLookup2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IXATransLookup2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IXATransLookup2_Release(This) (This)->lpVtbl->Release(This)
#define IXATransLookup2_Lookup(This,pXID,ppTransaction) (This)->lpVtbl->Lookup(This,pXID,ppTransaction)
#endif
#endif
  HRESULT WINAPI IXATransLookup2_Lookup_Proxy(IXATransLookup2 *This,XID *pXID,ITransaction **ppTransaction);
  void __RPC_STUB IXATransLookup2_Lookup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IResourceManagerSink_INTERFACE_DEFINED__
#define __IResourceManagerSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IResourceManagerSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IResourceManagerSink : public IUnknown {
  public:
    virtual HRESULT WINAPI TMDown(void) = 0;
  };
#else
  typedef struct IResourceManagerSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IResourceManagerSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IResourceManagerSink *This);
      ULONG (WINAPI *Release)(IResourceManagerSink *This);
      HRESULT (WINAPI *TMDown)(IResourceManagerSink *This);
    END_INTERFACE
  } IResourceManagerSinkVtbl;
  struct IResourceManagerSink {
    CONST_VTBL struct IResourceManagerSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IResourceManagerSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IResourceManagerSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IResourceManagerSink_Release(This) (This)->lpVtbl->Release(This)
#define IResourceManagerSink_TMDown(This) (This)->lpVtbl->TMDown(This)
#endif
#endif
  HRESULT WINAPI IResourceManagerSink_TMDown_Proxy(IResourceManagerSink *This);
  void __RPC_STUB IResourceManagerSink_TMDown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#ifndef __IResourceManager_INTERFACE_DEFINED__
#define __IResourceManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IResourceManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IResourceManager : public IUnknown {
  public:
    virtual HRESULT WINAPI Enlist(ITransaction *pTransaction,ITransactionResourceAsync *pRes,XACTUOW *pUOW,LONG *pisoLevel,ITransactionEnlistmentAsync **ppEnlist) = 0;
    virtual HRESULT WINAPI Reenlist(byte *pPrepInfo,ULONG cbPrepInfo,DWORD lTimeout,XACTSTAT *pXactStat) = 0;
    virtual HRESULT WINAPI ReenlistmentComplete(void) = 0;
    virtual HRESULT WINAPI GetDistributedTransactionManager(REFIID iid,void **ppvObject) = 0;
  };
#else
  typedef struct IResourceManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IResourceManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IResourceManager *This);
      ULONG (WINAPI *Release)(IResourceManager *This);
      HRESULT (WINAPI *Enlist)(IResourceManager *This,ITransaction *pTransaction,ITransactionResourceAsync *pRes,XACTUOW *pUOW,LONG *pisoLevel,ITransactionEnlistmentAsync **ppEnlist);
      HRESULT (WINAPI *Reenlist)(IResourceManager *This,byte *pPrepInfo,ULONG cbPrepInfo,DWORD lTimeout,XACTSTAT *pXactStat);
      HRESULT (WINAPI *ReenlistmentComplete)(IResourceManager *This);
      HRESULT (WINAPI *GetDistributedTransactionManager)(IResourceManager *This,REFIID iid,void **ppvObject);
    END_INTERFACE
  } IResourceManagerVtbl;
  struct IResourceManager {
    CONST_VTBL struct IResourceManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IResourceManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IResourceManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IResourceManager_Release(This) (This)->lpVtbl->Release(This)
#define IResourceManager_Enlist(This,pTransaction,pRes,pUOW,pisoLevel,ppEnlist) (This)->lpVtbl->Enlist(This,pTransaction,pRes,pUOW,pisoLevel,ppEnlist)
#define IResourceManager_Reenlist(This,pPrepInfo,cbPrepInfo,lTimeout,pXactStat) (This)->lpVtbl->Reenlist(This,pPrepInfo,cbPrepInfo,lTimeout,pXactStat)
#define IResourceManager_ReenlistmentComplete(This) (This)->lpVtbl->ReenlistmentComplete(This)
#define IResourceManager_GetDistributedTransactionManager(This,iid,ppvObject) (This)->lpVtbl->GetDistributedTransactionManager(This,iid,ppvObject)
#endif
#endif
  HRESULT WINAPI IResourceManager_Enlist_Proxy(IResourceManager *This,ITransaction *pTransaction,ITransactionResourceAsync *pRes,XACTUOW *pUOW,LONG *pisoLevel,ITransactionEnlistmentAsync **ppEnlist);
  void __RPC_STUB IResourceManager_Enlist_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResourceManager_Reenlist_Proxy(IResourceManager *This,byte *pPrepInfo,ULONG cbPrepInfo,DWORD lTimeout,XACTSTAT *pXactStat);
  void __RPC_STUB IResourceManager_Reenlist_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResourceManager_ReenlistmentComplete_Proxy(IResourceManager *This);
  void __RPC_STUB IResourceManager_ReenlistmentComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResourceManager_GetDistributedTransactionManager_Proxy(IResourceManager *This,REFIID iid,void **ppvObject);
  void __RPC_STUB IResourceManager_GetDistributedTransactionManager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ILastResourceManager_INTERFACE_DEFINED__
#define __ILastResourceManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ILastResourceManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ILastResourceManager : public IUnknown {
  public:
    virtual HRESULT WINAPI TransactionCommitted(byte *pPrepInfo,ULONG cbPrepInfo) = 0;
    virtual HRESULT WINAPI RecoveryDone(void) = 0;
  };
#else
  typedef struct ILastResourceManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ILastResourceManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ILastResourceManager *This);
      ULONG (WINAPI *Release)(ILastResourceManager *This);
      HRESULT (WINAPI *TransactionCommitted)(ILastResourceManager *This,byte *pPrepInfo,ULONG cbPrepInfo);
      HRESULT (WINAPI *RecoveryDone)(ILastResourceManager *This);
    END_INTERFACE
  } ILastResourceManagerVtbl;
  struct ILastResourceManager {
    CONST_VTBL struct ILastResourceManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ILastResourceManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ILastResourceManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ILastResourceManager_Release(This) (This)->lpVtbl->Release(This)
#define ILastResourceManager_TransactionCommitted(This,pPrepInfo,cbPrepInfo) (This)->lpVtbl->TransactionCommitted(This,pPrepInfo,cbPrepInfo)
#define ILastResourceManager_RecoveryDone(This) (This)->lpVtbl->RecoveryDone(This)
#endif
#endif
  HRESULT WINAPI ILastResourceManager_TransactionCommitted_Proxy(ILastResourceManager *This,byte *pPrepInfo,ULONG cbPrepInfo);
  void __RPC_STUB ILastResourceManager_TransactionCommitted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ILastResourceManager_RecoveryDone_Proxy(ILastResourceManager *This);
  void __RPC_STUB ILastResourceManager_RecoveryDone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IResourceManager2_INTERFACE_DEFINED__
#define __IResourceManager2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IResourceManager2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IResourceManager2 : public IResourceManager {
  public:
    virtual HRESULT WINAPI Enlist2(ITransaction *pTransaction,ITransactionResourceAsync *pResAsync,XACTUOW *pUOW,LONG *pisoLevel,XID *pXid,ITransactionEnlistmentAsync **ppEnlist) = 0;
    virtual HRESULT WINAPI Reenlist2(XID *pXid,DWORD dwTimeout,XACTSTAT *pXactStat) = 0;
  };
#else
  typedef struct IResourceManager2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IResourceManager2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IResourceManager2 *This);
      ULONG (WINAPI *Release)(IResourceManager2 *This);
      HRESULT (WINAPI *Enlist)(IResourceManager2 *This,ITransaction *pTransaction,ITransactionResourceAsync *pRes,XACTUOW *pUOW,LONG *pisoLevel,ITransactionEnlistmentAsync **ppEnlist);
      HRESULT (WINAPI *Reenlist)(IResourceManager2 *This,byte *pPrepInfo,ULONG cbPrepInfo,DWORD lTimeout,XACTSTAT *pXactStat);
      HRESULT (WINAPI *ReenlistmentComplete)(IResourceManager2 *This);
      HRESULT (WINAPI *GetDistributedTransactionManager)(IResourceManager2 *This,REFIID iid,void **ppvObject);
      HRESULT (WINAPI *Enlist2)(IResourceManager2 *This,ITransaction *pTransaction,ITransactionResourceAsync *pResAsync,XACTUOW *pUOW,LONG *pisoLevel,XID *pXid,ITransactionEnlistmentAsync **ppEnlist);
      HRESULT (WINAPI *Reenlist2)(IResourceManager2 *This,XID *pXid,DWORD dwTimeout,XACTSTAT *pXactStat);
    END_INTERFACE
  } IResourceManager2Vtbl;
  struct IResourceManager2 {
    CONST_VTBL struct IResourceManager2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IResourceManager2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IResourceManager2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IResourceManager2_Release(This) (This)->lpVtbl->Release(This)
#define IResourceManager2_Enlist(This,pTransaction,pRes,pUOW,pisoLevel,ppEnlist) (This)->lpVtbl->Enlist(This,pTransaction,pRes,pUOW,pisoLevel,ppEnlist)
#define IResourceManager2_Reenlist(This,pPrepInfo,cbPrepInfo,lTimeout,pXactStat) (This)->lpVtbl->Reenlist(This,pPrepInfo,cbPrepInfo,lTimeout,pXactStat)
#define IResourceManager2_ReenlistmentComplete(This) (This)->lpVtbl->ReenlistmentComplete(This)
#define IResourceManager2_GetDistributedTransactionManager(This,iid,ppvObject) (This)->lpVtbl->GetDistributedTransactionManager(This,iid,ppvObject)
#define IResourceManager2_Enlist2(This,pTransaction,pResAsync,pUOW,pisoLevel,pXid,ppEnlist) (This)->lpVtbl->Enlist2(This,pTransaction,pResAsync,pUOW,pisoLevel,pXid,ppEnlist)
#define IResourceManager2_Reenlist2(This,pXid,dwTimeout,pXactStat) (This)->lpVtbl->Reenlist2(This,pXid,dwTimeout,pXactStat)
#endif
#endif
  HRESULT WINAPI IResourceManager2_Enlist2_Proxy(IResourceManager2 *This,ITransaction *pTransaction,ITransactionResourceAsync *pResAsync,XACTUOW *pUOW,LONG *pisoLevel,XID *pXid,ITransactionEnlistmentAsync **ppEnlist);
  void __RPC_STUB IResourceManager2_Enlist2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResourceManager2_Reenlist2_Proxy(IResourceManager2 *This,XID *pXid,DWORD dwTimeout,XACTSTAT *pXactStat);
  void __RPC_STUB IResourceManager2_Reenlist2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IXAConfig_INTERFACE_DEFINED__
#define __IXAConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IXAConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IXAConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(GUID clsidHelperDll) = 0;
    virtual HRESULT WINAPI Terminate(void) = 0;
  };
#else
  typedef struct IXAConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IXAConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IXAConfig *This);
      ULONG (WINAPI *Release)(IXAConfig *This);
      HRESULT (WINAPI *Initialize)(IXAConfig *This,GUID clsidHelperDll);
      HRESULT (WINAPI *Terminate)(IXAConfig *This);
    END_INTERFACE
  } IXAConfigVtbl;
  struct IXAConfig {
    CONST_VTBL struct IXAConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IXAConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IXAConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IXAConfig_Release(This) (This)->lpVtbl->Release(This)
#define IXAConfig_Initialize(This,clsidHelperDll) (This)->lpVtbl->Initialize(This,clsidHelperDll)
#define IXAConfig_Terminate(This) (This)->lpVtbl->Terminate(This)
#endif
#endif
  HRESULT WINAPI IXAConfig_Initialize_Proxy(IXAConfig *This,GUID clsidHelperDll);
  void __RPC_STUB IXAConfig_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IXAConfig_Terminate_Proxy(IXAConfig *This);
  void __RPC_STUB IXAConfig_Terminate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRMHelper_INTERFACE_DEFINED__
#define __IRMHelper_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRMHelper;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRMHelper : public IUnknown {
  public:
    virtual HRESULT WINAPI RMCount(DWORD dwcTotalNumberOfRMs) = 0;
    virtual HRESULT WINAPI RMInfo(xa_switch_t *pXa_Switch,WINBOOL fCDeclCallingConv,char *pszOpenString,char *pszCloseString,GUID guidRMRecovery) = 0;
  };
#else
  typedef struct IRMHelperVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRMHelper *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRMHelper *This);
      ULONG (WINAPI *Release)(IRMHelper *This);
      HRESULT (WINAPI *RMCount)(IRMHelper *This,DWORD dwcTotalNumberOfRMs);
      HRESULT (WINAPI *RMInfo)(IRMHelper *This,xa_switch_t *pXa_Switch,WINBOOL fCDeclCallingConv,char *pszOpenString,char *pszCloseString,GUID guidRMRecovery);
    END_INTERFACE
  } IRMHelperVtbl;
  struct IRMHelper {
    CONST_VTBL struct IRMHelperVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRMHelper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRMHelper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRMHelper_Release(This) (This)->lpVtbl->Release(This)
#define IRMHelper_RMCount(This,dwcTotalNumberOfRMs) (This)->lpVtbl->RMCount(This,dwcTotalNumberOfRMs)
#define IRMHelper_RMInfo(This,pXa_Switch,fCDeclCallingConv,pszOpenString,pszCloseString,guidRMRecovery) (This)->lpVtbl->RMInfo(This,pXa_Switch,fCDeclCallingConv,pszOpenString,pszCloseString,guidRMRecovery)
#endif
#endif
  HRESULT WINAPI IRMHelper_RMCount_Proxy(IRMHelper *This,DWORD dwcTotalNumberOfRMs);
  void __RPC_STUB IRMHelper_RMCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRMHelper_RMInfo_Proxy(IRMHelper *This,xa_switch_t *pXa_Switch,WINBOOL fCDeclCallingConv,char *pszOpenString,char *pszCloseString,GUID guidRMRecovery);
  void __RPC_STUB IRMHelper_RMInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IXAObtainRMInfo_INTERFACE_DEFINED__
#define __IXAObtainRMInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IXAObtainRMInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IXAObtainRMInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI ObtainRMInfo(IRMHelper *pIRMHelper) = 0;
  };
#else
  typedef struct IXAObtainRMInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IXAObtainRMInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IXAObtainRMInfo *This);
      ULONG (WINAPI *Release)(IXAObtainRMInfo *This);
      HRESULT (WINAPI *ObtainRMInfo)(IXAObtainRMInfo *This,IRMHelper *pIRMHelper);
    END_INTERFACE
  } IXAObtainRMInfoVtbl;
  struct IXAObtainRMInfo {
    CONST_VTBL struct IXAObtainRMInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IXAObtainRMInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IXAObtainRMInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IXAObtainRMInfo_Release(This) (This)->lpVtbl->Release(This)
#define IXAObtainRMInfo_ObtainRMInfo(This,pIRMHelper) (This)->lpVtbl->ObtainRMInfo(This,pIRMHelper)
#endif
#endif
  HRESULT WINAPI IXAObtainRMInfo_ObtainRMInfo_Proxy(IXAObtainRMInfo *This,IRMHelper *pIRMHelper);
  void __RPC_STUB IXAObtainRMInfo_ObtainRMInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IResourceManagerFactory_INTERFACE_DEFINED__
#define __IResourceManagerFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IResourceManagerFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IResourceManagerFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(GUID *pguidRM,CHAR *pszRMName,IResourceManagerSink *pIResMgrSink,IResourceManager **ppResMgr) = 0;
  };
#else
  typedef struct IResourceManagerFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IResourceManagerFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IResourceManagerFactory *This);
      ULONG (WINAPI *Release)(IResourceManagerFactory *This);
      HRESULT (WINAPI *Create)(IResourceManagerFactory *This,GUID *pguidRM,CHAR *pszRMName,IResourceManagerSink *pIResMgrSink,IResourceManager **ppResMgr);
    END_INTERFACE
  } IResourceManagerFactoryVtbl;
  struct IResourceManagerFactory {
    CONST_VTBL struct IResourceManagerFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IResourceManagerFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IResourceManagerFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IResourceManagerFactory_Release(This) (This)->lpVtbl->Release(This)
#define IResourceManagerFactory_Create(This,pguidRM,pszRMName,pIResMgrSink,ppResMgr) (This)->lpVtbl->Create(This,pguidRM,pszRMName,pIResMgrSink,ppResMgr)
#endif
#endif
  HRESULT WINAPI IResourceManagerFactory_Create_Proxy(IResourceManagerFactory *This,GUID *pguidRM,CHAR *pszRMName,IResourceManagerSink *pIResMgrSink,IResourceManager **ppResMgr);
  void __RPC_STUB IResourceManagerFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IResourceManagerFactory2_INTERFACE_DEFINED__
#define __IResourceManagerFactory2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IResourceManagerFactory2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IResourceManagerFactory2 : public IResourceManagerFactory {
  public:
    virtual HRESULT WINAPI CreateEx(GUID *pguidRM,CHAR *pszRMName,IResourceManagerSink *pIResMgrSink,REFIID riidRequested,void **ppvResMgr) = 0;
  };
#else
  typedef struct IResourceManagerFactory2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IResourceManagerFactory2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IResourceManagerFactory2 *This);
      ULONG (WINAPI *Release)(IResourceManagerFactory2 *This);
      HRESULT (WINAPI *Create)(IResourceManagerFactory2 *This,GUID *pguidRM,CHAR *pszRMName,IResourceManagerSink *pIResMgrSink,IResourceManager **ppResMgr);
      HRESULT (WINAPI *CreateEx)(IResourceManagerFactory2 *This,GUID *pguidRM,CHAR *pszRMName,IResourceManagerSink *pIResMgrSink,REFIID riidRequested,void **ppvResMgr);
    END_INTERFACE
  } IResourceManagerFactory2Vtbl;
  struct IResourceManagerFactory2 {
    CONST_VTBL struct IResourceManagerFactory2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IResourceManagerFactory2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IResourceManagerFactory2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IResourceManagerFactory2_Release(This) (This)->lpVtbl->Release(This)
#define IResourceManagerFactory2_Create(This,pguidRM,pszRMName,pIResMgrSink,ppResMgr) (This)->lpVtbl->Create(This,pguidRM,pszRMName,pIResMgrSink,ppResMgr)
#define IResourceManagerFactory2_CreateEx(This,pguidRM,pszRMName,pIResMgrSink,riidRequested,ppvResMgr) (This)->lpVtbl->CreateEx(This,pguidRM,pszRMName,pIResMgrSink,riidRequested,ppvResMgr)
#endif
#endif
  HRESULT WINAPI IResourceManagerFactory2_CreateEx_Proxy(IResourceManagerFactory2 *This,GUID *pguidRM,CHAR *pszRMName,IResourceManagerSink *pIResMgrSink,REFIID riidRequested,void **ppvResMgr);
  void __RPC_STUB IResourceManagerFactory2_CreateEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPrepareInfo_INTERFACE_DEFINED__
#define __IPrepareInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPrepareInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPrepareInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetPrepareInfoSize(ULONG *pcbPrepInfo) = 0;
    virtual HRESULT WINAPI GetPrepareInfo(byte *pPrepInfo) = 0;
  };
#else
  typedef struct IPrepareInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPrepareInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPrepareInfo *This);
      ULONG (WINAPI *Release)(IPrepareInfo *This);
      HRESULT (WINAPI *GetPrepareInfoSize)(IPrepareInfo *This,ULONG *pcbPrepInfo);
      HRESULT (WINAPI *GetPrepareInfo)(IPrepareInfo *This,byte *pPrepInfo);
    END_INTERFACE
  } IPrepareInfoVtbl;
  struct IPrepareInfo {
    CONST_VTBL struct IPrepareInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPrepareInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPrepareInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPrepareInfo_Release(This) (This)->lpVtbl->Release(This)
#define IPrepareInfo_GetPrepareInfoSize(This,pcbPrepInfo) (This)->lpVtbl->GetPrepareInfoSize(This,pcbPrepInfo)
#define IPrepareInfo_GetPrepareInfo(This,pPrepInfo) (This)->lpVtbl->GetPrepareInfo(This,pPrepInfo)
#endif
#endif
  HRESULT WINAPI IPrepareInfo_GetPrepareInfoSize_Proxy(IPrepareInfo *This,ULONG *pcbPrepInfo);
  void __RPC_STUB IPrepareInfo_GetPrepareInfoSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPrepareInfo_GetPrepareInfo_Proxy(IPrepareInfo *This,byte *pPrepInfo);
  void __RPC_STUB IPrepareInfo_GetPrepareInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPrepareInfo2_INTERFACE_DEFINED__
#define __IPrepareInfo2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPrepareInfo2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPrepareInfo2 : public IUnknown {
  public:
    virtual HRESULT WINAPI GetPrepareInfoSize(ULONG *pcbPrepInfo) = 0;
    virtual HRESULT WINAPI GetPrepareInfo(ULONG cbPrepareInfo,byte *pPrepInfo) = 0;
  };
#else
  typedef struct IPrepareInfo2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPrepareInfo2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPrepareInfo2 *This);
      ULONG (WINAPI *Release)(IPrepareInfo2 *This);
      HRESULT (WINAPI *GetPrepareInfoSize)(IPrepareInfo2 *This,ULONG *pcbPrepInfo);
      HRESULT (WINAPI *GetPrepareInfo)(IPrepareInfo2 *This,ULONG cbPrepareInfo,byte *pPrepInfo);
    END_INTERFACE
  } IPrepareInfo2Vtbl;
  struct IPrepareInfo2 {
    CONST_VTBL struct IPrepareInfo2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPrepareInfo2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPrepareInfo2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPrepareInfo2_Release(This) (This)->lpVtbl->Release(This)
#define IPrepareInfo2_GetPrepareInfoSize(This,pcbPrepInfo) (This)->lpVtbl->GetPrepareInfoSize(This,pcbPrepInfo)
#define IPrepareInfo2_GetPrepareInfo(This,cbPrepareInfo,pPrepInfo) (This)->lpVtbl->GetPrepareInfo(This,cbPrepareInfo,pPrepInfo)
#endif
#endif
  HRESULT WINAPI IPrepareInfo2_GetPrepareInfoSize_Proxy(IPrepareInfo2 *This,ULONG *pcbPrepInfo);
  void __RPC_STUB IPrepareInfo2_GetPrepareInfoSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPrepareInfo2_GetPrepareInfo_Proxy(IPrepareInfo2 *This,ULONG cbPrepareInfo,byte *pPrepInfo);
  void __RPC_STUB IPrepareInfo2_GetPrepareInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetDispenser_INTERFACE_DEFINED__
#define __IGetDispenser_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetDispenser;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetDispenser : public IUnknown {
  public:
    virtual HRESULT WINAPI GetDispenser(REFIID iid,void **ppvObject) = 0;
  };
#else
  typedef struct IGetDispenserVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetDispenser *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetDispenser *This);
      ULONG (WINAPI *Release)(IGetDispenser *This);
      HRESULT (WINAPI *GetDispenser)(IGetDispenser *This,REFIID iid,void **ppvObject);
    END_INTERFACE
  } IGetDispenserVtbl;
  struct IGetDispenser {
    CONST_VTBL struct IGetDispenserVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetDispenser_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetDispenser_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetDispenser_Release(This) (This)->lpVtbl->Release(This)
#define IGetDispenser_GetDispenser(This,iid,ppvObject) (This)->lpVtbl->GetDispenser(This,iid,ppvObject)
#endif
#endif
  HRESULT WINAPI IGetDispenser_GetDispenser_Proxy(IGetDispenser *This,REFIID iid,void **ppvObject);
  void __RPC_STUB IGetDispenser_GetDispenser_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionVoterBallotAsync2_INTERFACE_DEFINED__
#define __ITransactionVoterBallotAsync2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionVoterBallotAsync2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionVoterBallotAsync2 : public IUnknown {
  public:
    virtual HRESULT WINAPI VoteRequestDone(HRESULT hr,BOID *pboidReason) = 0;
  };
#else
  typedef struct ITransactionVoterBallotAsync2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionVoterBallotAsync2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionVoterBallotAsync2 *This);
      ULONG (WINAPI *Release)(ITransactionVoterBallotAsync2 *This);
      HRESULT (WINAPI *VoteRequestDone)(ITransactionVoterBallotAsync2 *This,HRESULT hr,BOID *pboidReason);
    END_INTERFACE
  } ITransactionVoterBallotAsync2Vtbl;
  struct ITransactionVoterBallotAsync2 {
    CONST_VTBL struct ITransactionVoterBallotAsync2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionVoterBallotAsync2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionVoterBallotAsync2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionVoterBallotAsync2_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionVoterBallotAsync2_VoteRequestDone(This,hr,pboidReason) (This)->lpVtbl->VoteRequestDone(This,hr,pboidReason)
#endif
#endif
  HRESULT WINAPI ITransactionVoterBallotAsync2_VoteRequestDone_Proxy(ITransactionVoterBallotAsync2 *This,HRESULT hr,BOID *pboidReason);
  void __RPC_STUB ITransactionVoterBallotAsync2_VoteRequestDone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionVoterNotifyAsync2_INTERFACE_DEFINED__
#define __ITransactionVoterNotifyAsync2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionVoterNotifyAsync2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionVoterNotifyAsync2 : public ITransactionOutcomeEvents {
  public:
    virtual HRESULT WINAPI VoteRequest(void) = 0;
  };
#else
  typedef struct ITransactionVoterNotifyAsync2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionVoterNotifyAsync2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionVoterNotifyAsync2 *This);
      ULONG (WINAPI *Release)(ITransactionVoterNotifyAsync2 *This);
      HRESULT (WINAPI *Committed)(ITransactionVoterNotifyAsync2 *This,WINBOOL fRetaining,XACTUOW *pNewUOW,HRESULT hr);
      HRESULT (WINAPI *Aborted)(ITransactionVoterNotifyAsync2 *This,BOID *pboidReason,WINBOOL fRetaining,XACTUOW *pNewUOW,HRESULT hr);
      HRESULT (WINAPI *HeuristicDecision)(ITransactionVoterNotifyAsync2 *This,DWORD dwDecision,BOID *pboidReason,HRESULT hr);
      HRESULT (WINAPI *Indoubt)(ITransactionVoterNotifyAsync2 *This);
      HRESULT (WINAPI *VoteRequest)(ITransactionVoterNotifyAsync2 *This);
    END_INTERFACE
  } ITransactionVoterNotifyAsync2Vtbl;
  struct ITransactionVoterNotifyAsync2 {
    CONST_VTBL struct ITransactionVoterNotifyAsync2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionVoterNotifyAsync2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionVoterNotifyAsync2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionVoterNotifyAsync2_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionVoterNotifyAsync2_Committed(This,fRetaining,pNewUOW,hr) (This)->lpVtbl->Committed(This,fRetaining,pNewUOW,hr)
#define ITransactionVoterNotifyAsync2_Aborted(This,pboidReason,fRetaining,pNewUOW,hr) (This)->lpVtbl->Aborted(This,pboidReason,fRetaining,pNewUOW,hr)
#define ITransactionVoterNotifyAsync2_HeuristicDecision(This,dwDecision,pboidReason,hr) (This)->lpVtbl->HeuristicDecision(This,dwDecision,pboidReason,hr)
#define ITransactionVoterNotifyAsync2_Indoubt(This) (This)->lpVtbl->Indoubt(This)
#define ITransactionVoterNotifyAsync2_VoteRequest(This) (This)->lpVtbl->VoteRequest(This)
#endif
#endif
  HRESULT WINAPI ITransactionVoterNotifyAsync2_VoteRequest_Proxy(ITransactionVoterNotifyAsync2 *This);
  void __RPC_STUB ITransactionVoterNotifyAsync2_VoteRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionVoterFactory2_INTERFACE_DEFINED__
#define __ITransactionVoterFactory2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionVoterFactory2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionVoterFactory2 : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(ITransaction *pTransaction,ITransactionVoterNotifyAsync2 *pVoterNotify,ITransactionVoterBallotAsync2 **ppVoterBallot) = 0;
  };
#else
  typedef struct ITransactionVoterFactory2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionVoterFactory2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionVoterFactory2 *This);
      ULONG (WINAPI *Release)(ITransactionVoterFactory2 *This);
      HRESULT (WINAPI *Create)(ITransactionVoterFactory2 *This,ITransaction *pTransaction,ITransactionVoterNotifyAsync2 *pVoterNotify,ITransactionVoterBallotAsync2 **ppVoterBallot);
    END_INTERFACE
  } ITransactionVoterFactory2Vtbl;
  struct ITransactionVoterFactory2 {
    CONST_VTBL struct ITransactionVoterFactory2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionVoterFactory2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionVoterFactory2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionVoterFactory2_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionVoterFactory2_Create(This,pTransaction,pVoterNotify,ppVoterBallot) (This)->lpVtbl->Create(This,pTransaction,pVoterNotify,ppVoterBallot)
#endif
#endif
  HRESULT WINAPI ITransactionVoterFactory2_Create_Proxy(ITransactionVoterFactory2 *This,ITransaction *pTransaction,ITransactionVoterNotifyAsync2 *pVoterNotify,ITransactionVoterBallotAsync2 **ppVoterBallot);
  void __RPC_STUB ITransactionVoterFactory2_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionPhase0EnlistmentAsync_INTERFACE_DEFINED__
#define __ITransactionPhase0EnlistmentAsync_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionPhase0EnlistmentAsync;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionPhase0EnlistmentAsync : public IUnknown {
  public:
    virtual HRESULT WINAPI Enable(void) = 0;
    virtual HRESULT WINAPI WaitForEnlistment(void) = 0;
    virtual HRESULT WINAPI Phase0Done(void) = 0;
    virtual HRESULT WINAPI Unenlist(void) = 0;
    virtual HRESULT WINAPI GetTransaction(ITransaction **ppITransaction) = 0;
  };
#else
  typedef struct ITransactionPhase0EnlistmentAsyncVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionPhase0EnlistmentAsync *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionPhase0EnlistmentAsync *This);
      ULONG (WINAPI *Release)(ITransactionPhase0EnlistmentAsync *This);
      HRESULT (WINAPI *Enable)(ITransactionPhase0EnlistmentAsync *This);
      HRESULT (WINAPI *WaitForEnlistment)(ITransactionPhase0EnlistmentAsync *This);
      HRESULT (WINAPI *Phase0Done)(ITransactionPhase0EnlistmentAsync *This);
      HRESULT (WINAPI *Unenlist)(ITransactionPhase0EnlistmentAsync *This);
      HRESULT (WINAPI *GetTransaction)(ITransactionPhase0EnlistmentAsync *This,ITransaction **ppITransaction);
    END_INTERFACE
  } ITransactionPhase0EnlistmentAsyncVtbl;
  struct ITransactionPhase0EnlistmentAsync {
    CONST_VTBL struct ITransactionPhase0EnlistmentAsyncVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionPhase0EnlistmentAsync_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionPhase0EnlistmentAsync_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionPhase0EnlistmentAsync_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionPhase0EnlistmentAsync_Enable(This) (This)->lpVtbl->Enable(This)
#define ITransactionPhase0EnlistmentAsync_WaitForEnlistment(This) (This)->lpVtbl->WaitForEnlistment(This)
#define ITransactionPhase0EnlistmentAsync_Phase0Done(This) (This)->lpVtbl->Phase0Done(This)
#define ITransactionPhase0EnlistmentAsync_Unenlist(This) (This)->lpVtbl->Unenlist(This)
#define ITransactionPhase0EnlistmentAsync_GetTransaction(This,ppITransaction) (This)->lpVtbl->GetTransaction(This,ppITransaction)
#endif
#endif
  HRESULT WINAPI ITransactionPhase0EnlistmentAsync_Enable_Proxy(ITransactionPhase0EnlistmentAsync *This);
  void __RPC_STUB ITransactionPhase0EnlistmentAsync_Enable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionPhase0EnlistmentAsync_WaitForEnlistment_Proxy(ITransactionPhase0EnlistmentAsync *This);
  void __RPC_STUB ITransactionPhase0EnlistmentAsync_WaitForEnlistment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionPhase0EnlistmentAsync_Phase0Done_Proxy(ITransactionPhase0EnlistmentAsync *This);
  void __RPC_STUB ITransactionPhase0EnlistmentAsync_Phase0Done_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionPhase0EnlistmentAsync_Unenlist_Proxy(ITransactionPhase0EnlistmentAsync *This);
  void __RPC_STUB ITransactionPhase0EnlistmentAsync_Unenlist_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionPhase0EnlistmentAsync_GetTransaction_Proxy(ITransactionPhase0EnlistmentAsync *This,ITransaction **ppITransaction);
  void __RPC_STUB ITransactionPhase0EnlistmentAsync_GetTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionPhase0NotifyAsync_INTERFACE_DEFINED__
#define __ITransactionPhase0NotifyAsync_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionPhase0NotifyAsync;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionPhase0NotifyAsync : public IUnknown {
  public:
    virtual HRESULT WINAPI Phase0Request(WINBOOL fAbortingHint) = 0;
    virtual HRESULT WINAPI EnlistCompleted(HRESULT status) = 0;
  };
#else
  typedef struct ITransactionPhase0NotifyAsyncVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionPhase0NotifyAsync *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionPhase0NotifyAsync *This);
      ULONG (WINAPI *Release)(ITransactionPhase0NotifyAsync *This);
      HRESULT (WINAPI *Phase0Request)(ITransactionPhase0NotifyAsync *This,WINBOOL fAbortingHint);
      HRESULT (WINAPI *EnlistCompleted)(ITransactionPhase0NotifyAsync *This,HRESULT status);
    END_INTERFACE
  } ITransactionPhase0NotifyAsyncVtbl;
  struct ITransactionPhase0NotifyAsync {
    CONST_VTBL struct ITransactionPhase0NotifyAsyncVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionPhase0NotifyAsync_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionPhase0NotifyAsync_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionPhase0NotifyAsync_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionPhase0NotifyAsync_Phase0Request(This,fAbortingHint) (This)->lpVtbl->Phase0Request(This,fAbortingHint)
#define ITransactionPhase0NotifyAsync_EnlistCompleted(This,status) (This)->lpVtbl->EnlistCompleted(This,status)
#endif
#endif
  HRESULT WINAPI ITransactionPhase0NotifyAsync_Phase0Request_Proxy(ITransactionPhase0NotifyAsync *This,WINBOOL fAbortingHint);
  void __RPC_STUB ITransactionPhase0NotifyAsync_Phase0Request_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionPhase0NotifyAsync_EnlistCompleted_Proxy(ITransactionPhase0NotifyAsync *This,HRESULT status);
  void __RPC_STUB ITransactionPhase0NotifyAsync_EnlistCompleted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionPhase0Factory_INTERFACE_DEFINED__
#define __ITransactionPhase0Factory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionPhase0Factory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionPhase0Factory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(ITransactionPhase0NotifyAsync *pPhase0Notify,ITransactionPhase0EnlistmentAsync **ppPhase0Enlistment) = 0;
  };
#else
  typedef struct ITransactionPhase0FactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionPhase0Factory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionPhase0Factory *This);
      ULONG (WINAPI *Release)(ITransactionPhase0Factory *This);
      HRESULT (WINAPI *Create)(ITransactionPhase0Factory *This,ITransactionPhase0NotifyAsync *pPhase0Notify,ITransactionPhase0EnlistmentAsync **ppPhase0Enlistment);
    END_INTERFACE
  } ITransactionPhase0FactoryVtbl;
  struct ITransactionPhase0Factory {
    CONST_VTBL struct ITransactionPhase0FactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionPhase0Factory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionPhase0Factory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionPhase0Factory_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionPhase0Factory_Create(This,pPhase0Notify,ppPhase0Enlistment) (This)->lpVtbl->Create(This,pPhase0Notify,ppPhase0Enlistment)
#endif
#endif
  HRESULT WINAPI ITransactionPhase0Factory_Create_Proxy(ITransactionPhase0Factory *This,ITransactionPhase0NotifyAsync *pPhase0Notify,ITransactionPhase0EnlistmentAsync **ppPhase0Enlistment);
  void __RPC_STUB ITransactionPhase0Factory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionTransmitter_INTERFACE_DEFINED__
#define __ITransactionTransmitter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionTransmitter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionTransmitter : public IUnknown {
  public:
    virtual HRESULT WINAPI Set(ITransaction *pTransaction) = 0;
    virtual HRESULT WINAPI GetPropagationTokenSize(ULONG *pcbToken) = 0;
    virtual HRESULT WINAPI MarshalPropagationToken(ULONG cbToken,byte *rgbToken,ULONG *pcbUsed) = 0;
    virtual HRESULT WINAPI UnmarshalReturnToken(ULONG cbReturnToken,byte *rgbReturnToken) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
  };
#else
  typedef struct ITransactionTransmitterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionTransmitter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionTransmitter *This);
      ULONG (WINAPI *Release)(ITransactionTransmitter *This);
      HRESULT (WINAPI *Set)(ITransactionTransmitter *This,ITransaction *pTransaction);
      HRESULT (WINAPI *GetPropagationTokenSize)(ITransactionTransmitter *This,ULONG *pcbToken);
      HRESULT (WINAPI *MarshalPropagationToken)(ITransactionTransmitter *This,ULONG cbToken,byte *rgbToken,ULONG *pcbUsed);
      HRESULT (WINAPI *UnmarshalReturnToken)(ITransactionTransmitter *This,ULONG cbReturnToken,byte *rgbReturnToken);
      HRESULT (WINAPI *Reset)(ITransactionTransmitter *This);
    END_INTERFACE
  } ITransactionTransmitterVtbl;
  struct ITransactionTransmitter {
    CONST_VTBL struct ITransactionTransmitterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionTransmitter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionTransmitter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionTransmitter_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionTransmitter_Set(This,pTransaction) (This)->lpVtbl->Set(This,pTransaction)
#define ITransactionTransmitter_GetPropagationTokenSize(This,pcbToken) (This)->lpVtbl->GetPropagationTokenSize(This,pcbToken)
#define ITransactionTransmitter_MarshalPropagationToken(This,cbToken,rgbToken,pcbUsed) (This)->lpVtbl->MarshalPropagationToken(This,cbToken,rgbToken,pcbUsed)
#define ITransactionTransmitter_UnmarshalReturnToken(This,cbReturnToken,rgbReturnToken) (This)->lpVtbl->UnmarshalReturnToken(This,cbReturnToken,rgbReturnToken)
#define ITransactionTransmitter_Reset(This) (This)->lpVtbl->Reset(This)
#endif
#endif
  HRESULT WINAPI ITransactionTransmitter_Set_Proxy(ITransactionTransmitter *This,ITransaction *pTransaction);
  void __RPC_STUB ITransactionTransmitter_Set_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionTransmitter_GetPropagationTokenSize_Proxy(ITransactionTransmitter *This,ULONG *pcbToken);
  void __RPC_STUB ITransactionTransmitter_GetPropagationTokenSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionTransmitter_MarshalPropagationToken_Proxy(ITransactionTransmitter *This,ULONG cbToken,byte *rgbToken,ULONG *pcbUsed);
  void __RPC_STUB ITransactionTransmitter_MarshalPropagationToken_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionTransmitter_UnmarshalReturnToken_Proxy(ITransactionTransmitter *This,ULONG cbReturnToken,byte *rgbReturnToken);
  void __RPC_STUB ITransactionTransmitter_UnmarshalReturnToken_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionTransmitter_Reset_Proxy(ITransactionTransmitter *This);
  void __RPC_STUB ITransactionTransmitter_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionTransmitterFactory_INTERFACE_DEFINED__
#define __ITransactionTransmitterFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionTransmitterFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionTransmitterFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(ITransactionTransmitter **ppTransmitter) = 0;
  };
#else
  typedef struct ITransactionTransmitterFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionTransmitterFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionTransmitterFactory *This);
      ULONG (WINAPI *Release)(ITransactionTransmitterFactory *This);
      HRESULT (WINAPI *Create)(ITransactionTransmitterFactory *This,ITransactionTransmitter **ppTransmitter);
    END_INTERFACE
  } ITransactionTransmitterFactoryVtbl;
  struct ITransactionTransmitterFactory {
    CONST_VTBL struct ITransactionTransmitterFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionTransmitterFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionTransmitterFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionTransmitterFactory_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionTransmitterFactory_Create(This,ppTransmitter) (This)->lpVtbl->Create(This,ppTransmitter)
#endif
#endif
  HRESULT WINAPI ITransactionTransmitterFactory_Create_Proxy(ITransactionTransmitterFactory *This,ITransactionTransmitter **ppTransmitter);
  void __RPC_STUB ITransactionTransmitterFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionReceiver_INTERFACE_DEFINED__
#define __ITransactionReceiver_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionReceiver;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionReceiver : public IUnknown {
  public:
    virtual HRESULT WINAPI UnmarshalPropagationToken(ULONG cbToken,byte *rgbToken,ITransaction **ppTransaction) = 0;
    virtual HRESULT WINAPI GetReturnTokenSize(ULONG *pcbReturnToken) = 0;
    virtual HRESULT WINAPI MarshalReturnToken(ULONG cbReturnToken,byte *rgbReturnToken,ULONG *pcbUsed) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
  };
#else
  typedef struct ITransactionReceiverVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionReceiver *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionReceiver *This);
      ULONG (WINAPI *Release)(ITransactionReceiver *This);
      HRESULT (WINAPI *UnmarshalPropagationToken)(ITransactionReceiver *This,ULONG cbToken,byte *rgbToken,ITransaction **ppTransaction);
      HRESULT (WINAPI *GetReturnTokenSize)(ITransactionReceiver *This,ULONG *pcbReturnToken);
      HRESULT (WINAPI *MarshalReturnToken)(ITransactionReceiver *This,ULONG cbReturnToken,byte *rgbReturnToken,ULONG *pcbUsed);
      HRESULT (WINAPI *Reset)(ITransactionReceiver *This);
    END_INTERFACE
  } ITransactionReceiverVtbl;
  struct ITransactionReceiver {
    CONST_VTBL struct ITransactionReceiverVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionReceiver_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionReceiver_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionReceiver_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionReceiver_UnmarshalPropagationToken(This,cbToken,rgbToken,ppTransaction) (This)->lpVtbl->UnmarshalPropagationToken(This,cbToken,rgbToken,ppTransaction)
#define ITransactionReceiver_GetReturnTokenSize(This,pcbReturnToken) (This)->lpVtbl->GetReturnTokenSize(This,pcbReturnToken)
#define ITransactionReceiver_MarshalReturnToken(This,cbReturnToken,rgbReturnToken,pcbUsed) (This)->lpVtbl->MarshalReturnToken(This,cbReturnToken,rgbReturnToken,pcbUsed)
#define ITransactionReceiver_Reset(This) (This)->lpVtbl->Reset(This)
#endif
#endif
  HRESULT WINAPI ITransactionReceiver_UnmarshalPropagationToken_Proxy(ITransactionReceiver *This,ULONG cbToken,byte *rgbToken,ITransaction **ppTransaction);
  void __RPC_STUB ITransactionReceiver_UnmarshalPropagationToken_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionReceiver_GetReturnTokenSize_Proxy(ITransactionReceiver *This,ULONG *pcbReturnToken);
  void __RPC_STUB ITransactionReceiver_GetReturnTokenSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionReceiver_MarshalReturnToken_Proxy(ITransactionReceiver *This,ULONG cbReturnToken,byte *rgbReturnToken,ULONG *pcbUsed);
  void __RPC_STUB ITransactionReceiver_MarshalReturnToken_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionReceiver_Reset_Proxy(ITransactionReceiver *This);
  void __RPC_STUB ITransactionReceiver_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionReceiverFactory_INTERFACE_DEFINED__
#define __ITransactionReceiverFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionReceiverFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionReceiverFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(ITransactionReceiver **ppReceiver) = 0;
  };
#else
  typedef struct ITransactionReceiverFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionReceiverFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionReceiverFactory *This);
      ULONG (WINAPI *Release)(ITransactionReceiverFactory *This);
      HRESULT (WINAPI *Create)(ITransactionReceiverFactory *This,ITransactionReceiver **ppReceiver);
    END_INTERFACE
  } ITransactionReceiverFactoryVtbl;
  struct ITransactionReceiverFactory {
    CONST_VTBL struct ITransactionReceiverFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionReceiverFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionReceiverFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionReceiverFactory_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionReceiverFactory_Create(This,ppReceiver) (This)->lpVtbl->Create(This,ppReceiver)
#endif
#endif
  HRESULT WINAPI ITransactionReceiverFactory_Create_Proxy(ITransactionReceiverFactory *This,ITransactionReceiver **ppReceiver);
  void __RPC_STUB ITransactionReceiverFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef struct _ProxyConfigParams {
    WORD wcThreadsMax;
  } PROXY_CONFIG_PARAMS;

  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0141_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0141_v0_0_s_ifspec;
#ifndef __IDtcLuConfigure_INTERFACE_DEFINED__
#define __IDtcLuConfigure_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuConfigure;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuConfigure : public IUnknown {
  public:
    virtual HRESULT WINAPI Add(byte *pucLuPair,DWORD cbLuPair) = 0;
    virtual HRESULT WINAPI Delete(byte *pucLuPair,DWORD cbLuPair) = 0;
  };
#else
  typedef struct IDtcLuConfigureVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuConfigure *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuConfigure *This);
      ULONG (WINAPI *Release)(IDtcLuConfigure *This);
      HRESULT (WINAPI *Add)(IDtcLuConfigure *This,byte *pucLuPair,DWORD cbLuPair);
      HRESULT (WINAPI *Delete)(IDtcLuConfigure *This,byte *pucLuPair,DWORD cbLuPair);
    END_INTERFACE
  } IDtcLuConfigureVtbl;
  struct IDtcLuConfigure {
    CONST_VTBL struct IDtcLuConfigureVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuConfigure_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuConfigure_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuConfigure_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuConfigure_Add(This,pucLuPair,cbLuPair) (This)->lpVtbl->Add(This,pucLuPair,cbLuPair)
#define IDtcLuConfigure_Delete(This,pucLuPair,cbLuPair) (This)->lpVtbl->Delete(This,pucLuPair,cbLuPair)
#endif
#endif
  HRESULT WINAPI IDtcLuConfigure_Add_Proxy(IDtcLuConfigure *This,byte *pucLuPair,DWORD cbLuPair);
  void __RPC_STUB IDtcLuConfigure_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuConfigure_Delete_Proxy(IDtcLuConfigure *This,byte *pucLuPair,DWORD cbLuPair);
  void __RPC_STUB IDtcLuConfigure_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRecovery_INTERFACE_DEFINED__
#define __IDtcLuRecovery_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRecovery;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRecovery : public IUnknown {
  };
#else
  typedef struct IDtcLuRecoveryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRecovery *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRecovery *This);
      ULONG (WINAPI *Release)(IDtcLuRecovery *This);
    END_INTERFACE
  } IDtcLuRecoveryVtbl;
  struct IDtcLuRecovery {
    CONST_VTBL struct IDtcLuRecoveryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRecovery_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRecovery_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRecovery_Release(This) (This)->lpVtbl->Release(This)
#endif
#endif
#endif

#ifndef __IDtcLuRecoveryFactory_INTERFACE_DEFINED__
#define __IDtcLuRecoveryFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRecoveryFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRecoveryFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(byte *pucLuPair,DWORD cbLuPair,IDtcLuRecovery **ppRecovery) = 0;
  };
#else
  typedef struct IDtcLuRecoveryFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRecoveryFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRecoveryFactory *This);
      ULONG (WINAPI *Release)(IDtcLuRecoveryFactory *This);
      HRESULT (WINAPI *Create)(IDtcLuRecoveryFactory *This,byte *pucLuPair,DWORD cbLuPair,IDtcLuRecovery **ppRecovery);
    END_INTERFACE
  } IDtcLuRecoveryFactoryVtbl;
  struct IDtcLuRecoveryFactory {
    CONST_VTBL struct IDtcLuRecoveryFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRecoveryFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRecoveryFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRecoveryFactory_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRecoveryFactory_Create(This,pucLuPair,cbLuPair,ppRecovery) (This)->lpVtbl->Create(This,pucLuPair,cbLuPair,ppRecovery)
#endif
#endif
  HRESULT WINAPI IDtcLuRecoveryFactory_Create_Proxy(IDtcLuRecoveryFactory *This,byte *pucLuPair,DWORD cbLuPair,IDtcLuRecovery **ppRecovery);
  void __RPC_STUB IDtcLuRecoveryFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum _DtcLu_LocalRecovery_Work {
    DTCINITIATEDRECOVERYWORK_CHECKLUSTATUS = 1,
    DTCINITIATEDRECOVERYWORK_TRANS,DTCINITIATEDRECOVERYWORK_TMDOWN
  } DTCINITIATEDRECOVERYWORK;

  typedef enum _DtcLu_Xln {
    DTCLUXLN_COLD = 1,DTCLUXLN_WARM
  } DTCLUXLN;

  typedef enum _DtcLu_Xln_Confirmation {
    DTCLUXLNCONFIRMATION_CONFIRM = 1,
    DTCLUXLNCONFIRMATION_LOGNAMEMISMATCH,DTCLUXLNCONFIRMATION_COLDWARMMISMATCH,
    DTCLUXLNCONFIRMATION_OBSOLETE
  } DTCLUXLNCONFIRMATION;

  typedef enum _DtcLu_Xln_Response {
    DTCLUXLNRESPONSE_OK_SENDOURXLNBACK = 1,
    DTCLUXLNRESPONSE_OK_SENDCONFIRMATION,DTCLUXLNRESPONSE_LOGNAMEMISMATCH,
    DTCLUXLNRESPONSE_COLDWARMMISMATCH
  } DTCLUXLNRESPONSE;

  typedef enum _DtcLu_Xln_Error {
    DTCLUXLNERROR_PROTOCOL = 1,
    DTCLUXLNERROR_LOGNAMEMISMATCH,DTCLUXLNERROR_COLDWARMMISMATCH
  } DTCLUXLNERROR;

  typedef enum _DtcLu_CompareState {
    DTCLUCOMPARESTATE_COMMITTED = 1,
    DTCLUCOMPARESTATE_HEURISTICCOMMITTED,DTCLUCOMPARESTATE_HEURISTICMIXED,
    DTCLUCOMPARESTATE_HEURISTICRESET,DTCLUCOMPARESTATE_INDOUBT,DTCLUCOMPARESTATE_RESET
  } DTCLUCOMPARESTATE;

  typedef enum _DtcLu_CompareStates_Confirmation {
    DTCLUCOMPARESTATESCONFIRMATION_CONFIRM = 1,
    DTCLUCOMPARESTATESCONFIRMATION_PROTOCOL
  } DTCLUCOMPARESTATESCONFIRMATION;

  typedef enum _DtcLu_CompareStates_Error {
    DTCLUCOMPARESTATESERROR_PROTOCOL = 1
  } DTCLUCOMPARESTATESERROR;

  typedef enum _DtcLu_CompareStates_Response {
    DTCLUCOMPARESTATESRESPONSE_OK = 1,
    DTCLUCOMPARESTATESRESPONSE_PROTOCOL
  } DTCLUCOMPARESTATESRESPONSE;

  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0144_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0144_v0_0_s_ifspec;
#ifndef __IDtcLuRecoveryInitiatedByDtcTransWork_INTERFACE_DEFINED__
#define __IDtcLuRecoveryInitiatedByDtcTransWork_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRecoveryInitiatedByDtcTransWork;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRecoveryInitiatedByDtcTransWork : public IUnknown {
  public:
    virtual HRESULT WINAPI GetLogNameSizes(DWORD *pcbOurLogName,DWORD *pcbRemoteLogName) = 0;
    virtual HRESULT WINAPI GetOurXln(DTCLUXLN *pXln,unsigned char *pOurLogName,unsigned char *pRemoteLogName,DWORD *pdwProtocol) = 0;
    virtual HRESULT WINAPI HandleConfirmationFromOurXln(DTCLUXLNCONFIRMATION Confirmation) = 0;
    virtual HRESULT WINAPI HandleTheirXlnResponse(DTCLUXLN Xln,unsigned char *pRemoteLogName,DWORD cbRemoteLogName,DWORD dwProtocol,DTCLUXLNCONFIRMATION *pConfirmation) = 0;
    virtual HRESULT WINAPI HandleErrorFromOurXln(DTCLUXLNERROR Error) = 0;
    virtual HRESULT WINAPI CheckForCompareStates(WINBOOL *fCompareStates) = 0;
    virtual HRESULT WINAPI GetOurTransIdSize(DWORD *pcbOurTransId) = 0;
    virtual HRESULT WINAPI GetOurCompareStates(unsigned char *pOurTransId,DTCLUCOMPARESTATE *pCompareState) = 0;
    virtual HRESULT WINAPI HandleTheirCompareStatesResponse(DTCLUCOMPARESTATE CompareState,DTCLUCOMPARESTATESCONFIRMATION *pConfirmation) = 0;
    virtual HRESULT WINAPI HandleErrorFromOurCompareStates(DTCLUCOMPARESTATESERROR Error) = 0;
    virtual HRESULT WINAPI ConversationLost(void) = 0;
    virtual HRESULT WINAPI GetRecoverySeqNum(LONG *plRecoverySeqNum) = 0;
    virtual HRESULT WINAPI ObsoleteRecoverySeqNum(LONG lNewRecoverySeqNum) = 0;
  };
#else
  typedef struct IDtcLuRecoveryInitiatedByDtcTransWorkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRecoveryInitiatedByDtcTransWork *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRecoveryInitiatedByDtcTransWork *This);
      ULONG (WINAPI *Release)(IDtcLuRecoveryInitiatedByDtcTransWork *This);
      HRESULT (WINAPI *GetLogNameSizes)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DWORD *pcbOurLogName,DWORD *pcbRemoteLogName);
      HRESULT (WINAPI *GetOurXln)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLN *pXln,unsigned char *pOurLogName,unsigned char *pRemoteLogName,DWORD *pdwProtocol);
      HRESULT (WINAPI *HandleConfirmationFromOurXln)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLNCONFIRMATION Confirmation);
      HRESULT (WINAPI *HandleTheirXlnResponse)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLN Xln,unsigned char *pRemoteLogName,DWORD cbRemoteLogName,DWORD dwProtocol,DTCLUXLNCONFIRMATION *pConfirmation);
      HRESULT (WINAPI *HandleErrorFromOurXln)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLNERROR Error);
      HRESULT (WINAPI *CheckForCompareStates)(IDtcLuRecoveryInitiatedByDtcTransWork *This,WINBOOL *fCompareStates);
      HRESULT (WINAPI *GetOurTransIdSize)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DWORD *pcbOurTransId);
      HRESULT (WINAPI *GetOurCompareStates)(IDtcLuRecoveryInitiatedByDtcTransWork *This,unsigned char *pOurTransId,DTCLUCOMPARESTATE *pCompareState);
      HRESULT (WINAPI *HandleTheirCompareStatesResponse)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUCOMPARESTATE CompareState,DTCLUCOMPARESTATESCONFIRMATION *pConfirmation);
      HRESULT (WINAPI *HandleErrorFromOurCompareStates)(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUCOMPARESTATESERROR Error);
      HRESULT (WINAPI *ConversationLost)(IDtcLuRecoveryInitiatedByDtcTransWork *This);
      HRESULT (WINAPI *GetRecoverySeqNum)(IDtcLuRecoveryInitiatedByDtcTransWork *This,LONG *plRecoverySeqNum);
      HRESULT (WINAPI *ObsoleteRecoverySeqNum)(IDtcLuRecoveryInitiatedByDtcTransWork *This,LONG lNewRecoverySeqNum);
    END_INTERFACE
  } IDtcLuRecoveryInitiatedByDtcTransWorkVtbl;
  struct IDtcLuRecoveryInitiatedByDtcTransWork {
    CONST_VTBL struct IDtcLuRecoveryInitiatedByDtcTransWorkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRecoveryInitiatedByDtcTransWork_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRecoveryInitiatedByDtcTransWork_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRecoveryInitiatedByDtcTransWork_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRecoveryInitiatedByDtcTransWork_GetLogNameSizes(This,pcbOurLogName,pcbRemoteLogName) (This)->lpVtbl->GetLogNameSizes(This,pcbOurLogName,pcbRemoteLogName)
#define IDtcLuRecoveryInitiatedByDtcTransWork_GetOurXln(This,pXln,pOurLogName,pRemoteLogName,pdwProtocol) (This)->lpVtbl->GetOurXln(This,pXln,pOurLogName,pRemoteLogName,pdwProtocol)
#define IDtcLuRecoveryInitiatedByDtcTransWork_HandleConfirmationFromOurXln(This,Confirmation) (This)->lpVtbl->HandleConfirmationFromOurXln(This,Confirmation)
#define IDtcLuRecoveryInitiatedByDtcTransWork_HandleTheirXlnResponse(This,Xln,pRemoteLogName,cbRemoteLogName,dwProtocol,pConfirmation) (This)->lpVtbl->HandleTheirXlnResponse(This,Xln,pRemoteLogName,cbRemoteLogName,dwProtocol,pConfirmation)
#define IDtcLuRecoveryInitiatedByDtcTransWork_HandleErrorFromOurXln(This,Error) (This)->lpVtbl->HandleErrorFromOurXln(This,Error)
#define IDtcLuRecoveryInitiatedByDtcTransWork_CheckForCompareStates(This,fCompareStates) (This)->lpVtbl->CheckForCompareStates(This,fCompareStates)
#define IDtcLuRecoveryInitiatedByDtcTransWork_GetOurTransIdSize(This,pcbOurTransId) (This)->lpVtbl->GetOurTransIdSize(This,pcbOurTransId)
#define IDtcLuRecoveryInitiatedByDtcTransWork_GetOurCompareStates(This,pOurTransId,pCompareState) (This)->lpVtbl->GetOurCompareStates(This,pOurTransId,pCompareState)
#define IDtcLuRecoveryInitiatedByDtcTransWork_HandleTheirCompareStatesResponse(This,CompareState,pConfirmation) (This)->lpVtbl->HandleTheirCompareStatesResponse(This,CompareState,pConfirmation)
#define IDtcLuRecoveryInitiatedByDtcTransWork_HandleErrorFromOurCompareStates(This,Error) (This)->lpVtbl->HandleErrorFromOurCompareStates(This,Error)
#define IDtcLuRecoveryInitiatedByDtcTransWork_ConversationLost(This) (This)->lpVtbl->ConversationLost(This)
#define IDtcLuRecoveryInitiatedByDtcTransWork_GetRecoverySeqNum(This,plRecoverySeqNum) (This)->lpVtbl->GetRecoverySeqNum(This,plRecoverySeqNum)
#define IDtcLuRecoveryInitiatedByDtcTransWork_ObsoleteRecoverySeqNum(This,lNewRecoverySeqNum) (This)->lpVtbl->ObsoleteRecoverySeqNum(This,lNewRecoverySeqNum)
#endif
#endif
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_GetLogNameSizes_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DWORD *pcbOurLogName,DWORD *pcbRemoteLogName);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_GetLogNameSizes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_GetOurXln_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLN *pXln,unsigned char *pOurLogName,unsigned char *pRemoteLogName,DWORD *pdwProtocol);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_GetOurXln_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_HandleConfirmationFromOurXln_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLNCONFIRMATION Confirmation);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_HandleConfirmationFromOurXln_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_HandleTheirXlnResponse_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLN Xln,unsigned char *pRemoteLogName,DWORD cbRemoteLogName,DWORD dwProtocol,DTCLUXLNCONFIRMATION *pConfirmation);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_HandleTheirXlnResponse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_HandleErrorFromOurXln_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUXLNERROR Error);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_HandleErrorFromOurXln_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_CheckForCompareStates_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,WINBOOL *fCompareStates);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_CheckForCompareStates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_GetOurTransIdSize_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DWORD *pcbOurTransId);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_GetOurTransIdSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_GetOurCompareStates_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,unsigned char *pOurTransId,DTCLUCOMPARESTATE *pCompareState);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_GetOurCompareStates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_HandleTheirCompareStatesResponse_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUCOMPARESTATE CompareState,DTCLUCOMPARESTATESCONFIRMATION *pConfirmation);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_HandleTheirCompareStatesResponse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_HandleErrorFromOurCompareStates_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,DTCLUCOMPARESTATESERROR Error);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_HandleErrorFromOurCompareStates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_ConversationLost_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_ConversationLost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_GetRecoverySeqNum_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,LONG *plRecoverySeqNum);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_GetRecoverySeqNum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcTransWork_ObsoleteRecoverySeqNum_Proxy(IDtcLuRecoveryInitiatedByDtcTransWork *This,LONG lNewRecoverySeqNum);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcTransWork_ObsoleteRecoverySeqNum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRecoveryInitiatedByDtcStatusWork_INTERFACE_DEFINED__
#define __IDtcLuRecoveryInitiatedByDtcStatusWork_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRecoveryInitiatedByDtcStatusWork;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRecoveryInitiatedByDtcStatusWork : public IUnknown {
  public:
    virtual HRESULT WINAPI HandleCheckLuStatus(LONG lRecoverySeqNum) = 0;
  };
#else
  typedef struct IDtcLuRecoveryInitiatedByDtcStatusWorkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRecoveryInitiatedByDtcStatusWork *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRecoveryInitiatedByDtcStatusWork *This);
      ULONG (WINAPI *Release)(IDtcLuRecoveryInitiatedByDtcStatusWork *This);
      HRESULT (WINAPI *HandleCheckLuStatus)(IDtcLuRecoveryInitiatedByDtcStatusWork *This,LONG lRecoverySeqNum);
    END_INTERFACE
  } IDtcLuRecoveryInitiatedByDtcStatusWorkVtbl;
  struct IDtcLuRecoveryInitiatedByDtcStatusWork {
    CONST_VTBL struct IDtcLuRecoveryInitiatedByDtcStatusWorkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRecoveryInitiatedByDtcStatusWork_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRecoveryInitiatedByDtcStatusWork_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRecoveryInitiatedByDtcStatusWork_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRecoveryInitiatedByDtcStatusWork_HandleCheckLuStatus(This,lRecoverySeqNum) (This)->lpVtbl->HandleCheckLuStatus(This,lRecoverySeqNum)
#endif
#endif
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtcStatusWork_HandleCheckLuStatus_Proxy(IDtcLuRecoveryInitiatedByDtcStatusWork *This,LONG lRecoverySeqNum);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtcStatusWork_HandleCheckLuStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRecoveryInitiatedByDtc_INTERFACE_DEFINED__
#define __IDtcLuRecoveryInitiatedByDtc_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRecoveryInitiatedByDtc;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRecoveryInitiatedByDtc : public IUnknown {
  public:
    virtual HRESULT WINAPI GetWork(DTCINITIATEDRECOVERYWORK *pWork,void **ppv) = 0;
  };
#else
  typedef struct IDtcLuRecoveryInitiatedByDtcVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRecoveryInitiatedByDtc *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRecoveryInitiatedByDtc *This);
      ULONG (WINAPI *Release)(IDtcLuRecoveryInitiatedByDtc *This);
      HRESULT (WINAPI *GetWork)(IDtcLuRecoveryInitiatedByDtc *This,DTCINITIATEDRECOVERYWORK *pWork,void **ppv);
    END_INTERFACE
  } IDtcLuRecoveryInitiatedByDtcVtbl;
  struct IDtcLuRecoveryInitiatedByDtc {
    CONST_VTBL struct IDtcLuRecoveryInitiatedByDtcVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRecoveryInitiatedByDtc_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRecoveryInitiatedByDtc_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRecoveryInitiatedByDtc_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRecoveryInitiatedByDtc_GetWork(This,pWork,ppv) (This)->lpVtbl->GetWork(This,pWork,ppv)
#endif
#endif
  HRESULT WINAPI IDtcLuRecoveryInitiatedByDtc_GetWork_Proxy(IDtcLuRecoveryInitiatedByDtc *This,DTCINITIATEDRECOVERYWORK *pWork,void **ppv);
  void __RPC_STUB IDtcLuRecoveryInitiatedByDtc_GetWork_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRecoveryInitiatedByLuWork_INTERFACE_DEFINED__
#define __IDtcLuRecoveryInitiatedByLuWork_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRecoveryInitiatedByLuWork;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRecoveryInitiatedByLuWork : public IUnknown {
  public:
    virtual HRESULT WINAPI HandleTheirXln(LONG lRecoverySeqNum,DTCLUXLN Xln,unsigned char *pRemoteLogName,DWORD cbRemoteLogName,unsigned char *pOurLogName,DWORD cbOurLogName,DWORD dwProtocol,DTCLUXLNRESPONSE *pResponse) = 0;
    virtual HRESULT WINAPI GetOurLogNameSize(DWORD *pcbOurLogName) = 0;
    virtual HRESULT WINAPI GetOurXln(DTCLUXLN *pXln,unsigned char *pOurLogName,DWORD *pdwProtocol) = 0;
    virtual HRESULT WINAPI HandleConfirmationOfOurXln(DTCLUXLNCONFIRMATION Confirmation) = 0;
    virtual HRESULT WINAPI HandleTheirCompareStates(unsigned char *pRemoteTransId,DWORD cbRemoteTransId,DTCLUCOMPARESTATE CompareState,DTCLUCOMPARESTATESRESPONSE *pResponse,DTCLUCOMPARESTATE *pCompareState) = 0;
    virtual HRESULT WINAPI HandleConfirmationOfOurCompareStates(DTCLUCOMPARESTATESCONFIRMATION Confirmation) = 0;
    virtual HRESULT WINAPI HandleErrorFromOurCompareStates(DTCLUCOMPARESTATESERROR Error) = 0;
    virtual HRESULT WINAPI ConversationLost(void) = 0;
  };
#else
  typedef struct IDtcLuRecoveryInitiatedByLuWorkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRecoveryInitiatedByLuWork *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRecoveryInitiatedByLuWork *This);
      ULONG (WINAPI *Release)(IDtcLuRecoveryInitiatedByLuWork *This);
      HRESULT (WINAPI *HandleTheirXln)(IDtcLuRecoveryInitiatedByLuWork *This,LONG lRecoverySeqNum,DTCLUXLN Xln,unsigned char *pRemoteLogName,DWORD cbRemoteLogName,unsigned char *pOurLogName,DWORD cbOurLogName,DWORD dwProtocol,DTCLUXLNRESPONSE *pResponse);
      HRESULT (WINAPI *GetOurLogNameSize)(IDtcLuRecoveryInitiatedByLuWork *This,DWORD *pcbOurLogName);
      HRESULT (WINAPI *GetOurXln)(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUXLN *pXln,unsigned char *pOurLogName,DWORD *pdwProtocol);
      HRESULT (WINAPI *HandleConfirmationOfOurXln)(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUXLNCONFIRMATION Confirmation);
      HRESULT (WINAPI *HandleTheirCompareStates)(IDtcLuRecoveryInitiatedByLuWork *This,unsigned char *pRemoteTransId,DWORD cbRemoteTransId,DTCLUCOMPARESTATE CompareState,DTCLUCOMPARESTATESRESPONSE *pResponse,DTCLUCOMPARESTATE *pCompareState);
      HRESULT (WINAPI *HandleConfirmationOfOurCompareStates)(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUCOMPARESTATESCONFIRMATION Confirmation);
      HRESULT (WINAPI *HandleErrorFromOurCompareStates)(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUCOMPARESTATESERROR Error);
      HRESULT (WINAPI *ConversationLost)(IDtcLuRecoveryInitiatedByLuWork *This);
    END_INTERFACE
  } IDtcLuRecoveryInitiatedByLuWorkVtbl;
  struct IDtcLuRecoveryInitiatedByLuWork {
    CONST_VTBL struct IDtcLuRecoveryInitiatedByLuWorkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRecoveryInitiatedByLuWork_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRecoveryInitiatedByLuWork_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRecoveryInitiatedByLuWork_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRecoveryInitiatedByLuWork_HandleTheirXln(This,lRecoverySeqNum,Xln,pRemoteLogName,cbRemoteLogName,pOurLogName,cbOurLogName,dwProtocol,pResponse) (This)->lpVtbl->HandleTheirXln(This,lRecoverySeqNum,Xln,pRemoteLogName,cbRemoteLogName,pOurLogName,cbOurLogName,dwProtocol,pResponse)
#define IDtcLuRecoveryInitiatedByLuWork_GetOurLogNameSize(This,pcbOurLogName) (This)->lpVtbl->GetOurLogNameSize(This,pcbOurLogName)
#define IDtcLuRecoveryInitiatedByLuWork_GetOurXln(This,pXln,pOurLogName,pdwProtocol) (This)->lpVtbl->GetOurXln(This,pXln,pOurLogName,pdwProtocol)
#define IDtcLuRecoveryInitiatedByLuWork_HandleConfirmationOfOurXln(This,Confirmation) (This)->lpVtbl->HandleConfirmationOfOurXln(This,Confirmation)
#define IDtcLuRecoveryInitiatedByLuWork_HandleTheirCompareStates(This,pRemoteTransId,cbRemoteTransId,CompareState,pResponse,pCompareState) (This)->lpVtbl->HandleTheirCompareStates(This,pRemoteTransId,cbRemoteTransId,CompareState,pResponse,pCompareState)
#define IDtcLuRecoveryInitiatedByLuWork_HandleConfirmationOfOurCompareStates(This,Confirmation) (This)->lpVtbl->HandleConfirmationOfOurCompareStates(This,Confirmation)
#define IDtcLuRecoveryInitiatedByLuWork_HandleErrorFromOurCompareStates(This,Error) (This)->lpVtbl->HandleErrorFromOurCompareStates(This,Error)
#define IDtcLuRecoveryInitiatedByLuWork_ConversationLost(This) (This)->lpVtbl->ConversationLost(This)
#endif
#endif
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_HandleTheirXln_Proxy(IDtcLuRecoveryInitiatedByLuWork *This,LONG lRecoverySeqNum,DTCLUXLN Xln,unsigned char *pRemoteLogName,DWORD cbRemoteLogName,unsigned char *pOurLogName,DWORD cbOurLogName,DWORD dwProtocol,DTCLUXLNRESPONSE *pResponse);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_HandleTheirXln_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_GetOurLogNameSize_Proxy(IDtcLuRecoveryInitiatedByLuWork *This,DWORD *pcbOurLogName);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_GetOurLogNameSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_GetOurXln_Proxy(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUXLN *pXln,unsigned char *pOurLogName,DWORD *pdwProtocol);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_GetOurXln_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_HandleConfirmationOfOurXln_Proxy(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUXLNCONFIRMATION Confirmation);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_HandleConfirmationOfOurXln_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_HandleTheirCompareStates_Proxy(IDtcLuRecoveryInitiatedByLuWork *This,unsigned char *pRemoteTransId,DWORD cbRemoteTransId,DTCLUCOMPARESTATE CompareState,DTCLUCOMPARESTATESRESPONSE *pResponse,DTCLUCOMPARESTATE *pCompareState);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_HandleTheirCompareStates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_HandleConfirmationOfOurCompareStates_Proxy(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUCOMPARESTATESCONFIRMATION Confirmation);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_HandleConfirmationOfOurCompareStates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_HandleErrorFromOurCompareStates_Proxy(IDtcLuRecoveryInitiatedByLuWork *This,DTCLUCOMPARESTATESERROR Error);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_HandleErrorFromOurCompareStates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLuWork_ConversationLost_Proxy(IDtcLuRecoveryInitiatedByLuWork *This);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLuWork_ConversationLost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRecoveryInitiatedByLu_INTERFACE_DEFINED__
#define __IDtcLuRecoveryInitiatedByLu_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRecoveryInitiatedByLu;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRecoveryInitiatedByLu : public IUnknown {
  public:
    virtual HRESULT WINAPI GetObjectToHandleWorkFromLu(IDtcLuRecoveryInitiatedByLuWork **ppWork) = 0;
  };
#else
  typedef struct IDtcLuRecoveryInitiatedByLuVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRecoveryInitiatedByLu *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRecoveryInitiatedByLu *This);
      ULONG (WINAPI *Release)(IDtcLuRecoveryInitiatedByLu *This);
      HRESULT (WINAPI *GetObjectToHandleWorkFromLu)(IDtcLuRecoveryInitiatedByLu *This,IDtcLuRecoveryInitiatedByLuWork **ppWork);
    END_INTERFACE
  } IDtcLuRecoveryInitiatedByLuVtbl;
  struct IDtcLuRecoveryInitiatedByLu {
    CONST_VTBL struct IDtcLuRecoveryInitiatedByLuVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRecoveryInitiatedByLu_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRecoveryInitiatedByLu_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRecoveryInitiatedByLu_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRecoveryInitiatedByLu_GetObjectToHandleWorkFromLu(This,ppWork) (This)->lpVtbl->GetObjectToHandleWorkFromLu(This,ppWork)
#endif
#endif
  HRESULT WINAPI IDtcLuRecoveryInitiatedByLu_GetObjectToHandleWorkFromLu_Proxy(IDtcLuRecoveryInitiatedByLu *This,IDtcLuRecoveryInitiatedByLuWork **ppWork);
  void __RPC_STUB IDtcLuRecoveryInitiatedByLu_GetObjectToHandleWorkFromLu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRmEnlistment_INTERFACE_DEFINED__
#define __IDtcLuRmEnlistment_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRmEnlistment;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRmEnlistment : public IUnknown {
  public:
    virtual HRESULT WINAPI Unplug(WINBOOL fConversationLost) = 0;
    virtual HRESULT WINAPI BackedOut(void) = 0;
    virtual HRESULT WINAPI BackOut(void) = 0;
    virtual HRESULT WINAPI Committed(void) = 0;
    virtual HRESULT WINAPI Forget(void) = 0;
    virtual HRESULT WINAPI RequestCommit(void) = 0;
  };
#else
  typedef struct IDtcLuRmEnlistmentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRmEnlistment *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRmEnlistment *This);
      ULONG (WINAPI *Release)(IDtcLuRmEnlistment *This);
      HRESULT (WINAPI *Unplug)(IDtcLuRmEnlistment *This,WINBOOL fConversationLost);
      HRESULT (WINAPI *BackedOut)(IDtcLuRmEnlistment *This);
      HRESULT (WINAPI *BackOut)(IDtcLuRmEnlistment *This);
      HRESULT (WINAPI *Committed)(IDtcLuRmEnlistment *This);
      HRESULT (WINAPI *Forget)(IDtcLuRmEnlistment *This);
      HRESULT (WINAPI *RequestCommit)(IDtcLuRmEnlistment *This);
    END_INTERFACE
  } IDtcLuRmEnlistmentVtbl;
  struct IDtcLuRmEnlistment {
    CONST_VTBL struct IDtcLuRmEnlistmentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRmEnlistment_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRmEnlistment_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRmEnlistment_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRmEnlistment_Unplug(This,fConversationLost) (This)->lpVtbl->Unplug(This,fConversationLost)
#define IDtcLuRmEnlistment_BackedOut(This) (This)->lpVtbl->BackedOut(This)
#define IDtcLuRmEnlistment_BackOut(This) (This)->lpVtbl->BackOut(This)
#define IDtcLuRmEnlistment_Committed(This) (This)->lpVtbl->Committed(This)
#define IDtcLuRmEnlistment_Forget(This) (This)->lpVtbl->Forget(This)
#define IDtcLuRmEnlistment_RequestCommit(This) (This)->lpVtbl->RequestCommit(This)
#endif
#endif
  HRESULT WINAPI IDtcLuRmEnlistment_Unplug_Proxy(IDtcLuRmEnlistment *This,WINBOOL fConversationLost);
  void __RPC_STUB IDtcLuRmEnlistment_Unplug_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistment_BackedOut_Proxy(IDtcLuRmEnlistment *This);
  void __RPC_STUB IDtcLuRmEnlistment_BackedOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistment_BackOut_Proxy(IDtcLuRmEnlistment *This);
  void __RPC_STUB IDtcLuRmEnlistment_BackOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistment_Committed_Proxy(IDtcLuRmEnlistment *This);
  void __RPC_STUB IDtcLuRmEnlistment_Committed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistment_Forget_Proxy(IDtcLuRmEnlistment *This);
  void __RPC_STUB IDtcLuRmEnlistment_Forget_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistment_RequestCommit_Proxy(IDtcLuRmEnlistment *This);
  void __RPC_STUB IDtcLuRmEnlistment_RequestCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRmEnlistmentSink_INTERFACE_DEFINED__
#define __IDtcLuRmEnlistmentSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRmEnlistmentSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRmEnlistmentSink : public IUnknown {
  public:
    virtual HRESULT WINAPI AckUnplug(void) = 0;
    virtual HRESULT WINAPI TmDown(void) = 0;
    virtual HRESULT WINAPI SessionLost(void) = 0;
    virtual HRESULT WINAPI BackedOut(void) = 0;
    virtual HRESULT WINAPI BackOut(void) = 0;
    virtual HRESULT WINAPI Committed(void) = 0;
    virtual HRESULT WINAPI Forget(void) = 0;
    virtual HRESULT WINAPI Prepare(void) = 0;
    virtual HRESULT WINAPI RequestCommit(void) = 0;
  };
#else
  typedef struct IDtcLuRmEnlistmentSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRmEnlistmentSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRmEnlistmentSink *This);
      ULONG (WINAPI *Release)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *AckUnplug)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *TmDown)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *SessionLost)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *BackedOut)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *BackOut)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *Committed)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *Forget)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *Prepare)(IDtcLuRmEnlistmentSink *This);
      HRESULT (WINAPI *RequestCommit)(IDtcLuRmEnlistmentSink *This);
    END_INTERFACE
  } IDtcLuRmEnlistmentSinkVtbl;
  struct IDtcLuRmEnlistmentSink {
    CONST_VTBL struct IDtcLuRmEnlistmentSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRmEnlistmentSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRmEnlistmentSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRmEnlistmentSink_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRmEnlistmentSink_AckUnplug(This) (This)->lpVtbl->AckUnplug(This)
#define IDtcLuRmEnlistmentSink_TmDown(This) (This)->lpVtbl->TmDown(This)
#define IDtcLuRmEnlistmentSink_SessionLost(This) (This)->lpVtbl->SessionLost(This)
#define IDtcLuRmEnlistmentSink_BackedOut(This) (This)->lpVtbl->BackedOut(This)
#define IDtcLuRmEnlistmentSink_BackOut(This) (This)->lpVtbl->BackOut(This)
#define IDtcLuRmEnlistmentSink_Committed(This) (This)->lpVtbl->Committed(This)
#define IDtcLuRmEnlistmentSink_Forget(This) (This)->lpVtbl->Forget(This)
#define IDtcLuRmEnlistmentSink_Prepare(This) (This)->lpVtbl->Prepare(This)
#define IDtcLuRmEnlistmentSink_RequestCommit(This) (This)->lpVtbl->RequestCommit(This)
#endif
#endif
  HRESULT WINAPI IDtcLuRmEnlistmentSink_AckUnplug_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_AckUnplug_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_TmDown_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_TmDown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_SessionLost_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_SessionLost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_BackedOut_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_BackedOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_BackOut_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_BackOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_Committed_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_Committed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_Forget_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_Forget_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_Prepare_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_Prepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuRmEnlistmentSink_RequestCommit_Proxy(IDtcLuRmEnlistmentSink *This);
  void __RPC_STUB IDtcLuRmEnlistmentSink_RequestCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuRmEnlistmentFactory_INTERFACE_DEFINED__
#define __IDtcLuRmEnlistmentFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuRmEnlistmentFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuRmEnlistmentFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(unsigned char *pucLuPair,DWORD cbLuPair,ITransaction *pITransaction,unsigned char *pTransId,DWORD cbTransId,IDtcLuRmEnlistmentSink *pRmEnlistmentSink,IDtcLuRmEnlistment **ppRmEnlistment) = 0;
  };
#else
  typedef struct IDtcLuRmEnlistmentFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuRmEnlistmentFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuRmEnlistmentFactory *This);
      ULONG (WINAPI *Release)(IDtcLuRmEnlistmentFactory *This);
      HRESULT (WINAPI *Create)(IDtcLuRmEnlistmentFactory *This,unsigned char *pucLuPair,DWORD cbLuPair,ITransaction *pITransaction,unsigned char *pTransId,DWORD cbTransId,IDtcLuRmEnlistmentSink *pRmEnlistmentSink,IDtcLuRmEnlistment **ppRmEnlistment);
    END_INTERFACE
  } IDtcLuRmEnlistmentFactoryVtbl;
  struct IDtcLuRmEnlistmentFactory {
    CONST_VTBL struct IDtcLuRmEnlistmentFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuRmEnlistmentFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuRmEnlistmentFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuRmEnlistmentFactory_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuRmEnlistmentFactory_Create(This,pucLuPair,cbLuPair,pITransaction,pTransId,cbTransId,pRmEnlistmentSink,ppRmEnlistment) (This)->lpVtbl->Create(This,pucLuPair,cbLuPair,pITransaction,pTransId,cbTransId,pRmEnlistmentSink,ppRmEnlistment)
#endif
#endif
  HRESULT WINAPI IDtcLuRmEnlistmentFactory_Create_Proxy(IDtcLuRmEnlistmentFactory *This,unsigned char *pucLuPair,DWORD cbLuPair,ITransaction *pITransaction,unsigned char *pTransId,DWORD cbTransId,IDtcLuRmEnlistmentSink *pRmEnlistmentSink,IDtcLuRmEnlistment **ppRmEnlistment);
  void __RPC_STUB IDtcLuRmEnlistmentFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuSubordinateDtc_INTERFACE_DEFINED__
#define __IDtcLuSubordinateDtc_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuSubordinateDtc;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuSubordinateDtc : public IUnknown {
  public:
    virtual HRESULT WINAPI Unplug(WINBOOL fConversationLost) = 0;
    virtual HRESULT WINAPI BackedOut(void) = 0;
    virtual HRESULT WINAPI BackOut(void) = 0;
    virtual HRESULT WINAPI Committed(void) = 0;
    virtual HRESULT WINAPI Forget(void) = 0;
    virtual HRESULT WINAPI Prepare(void) = 0;
    virtual HRESULT WINAPI RequestCommit(void) = 0;
  };
#else
  typedef struct IDtcLuSubordinateDtcVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuSubordinateDtc *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuSubordinateDtc *This);
      ULONG (WINAPI *Release)(IDtcLuSubordinateDtc *This);
      HRESULT (WINAPI *Unplug)(IDtcLuSubordinateDtc *This,WINBOOL fConversationLost);
      HRESULT (WINAPI *BackedOut)(IDtcLuSubordinateDtc *This);
      HRESULT (WINAPI *BackOut)(IDtcLuSubordinateDtc *This);
      HRESULT (WINAPI *Committed)(IDtcLuSubordinateDtc *This);
      HRESULT (WINAPI *Forget)(IDtcLuSubordinateDtc *This);
      HRESULT (WINAPI *Prepare)(IDtcLuSubordinateDtc *This);
      HRESULT (WINAPI *RequestCommit)(IDtcLuSubordinateDtc *This);
    END_INTERFACE
  } IDtcLuSubordinateDtcVtbl;
  struct IDtcLuSubordinateDtc {
    CONST_VTBL struct IDtcLuSubordinateDtcVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuSubordinateDtc_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuSubordinateDtc_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuSubordinateDtc_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuSubordinateDtc_Unplug(This,fConversationLost) (This)->lpVtbl->Unplug(This,fConversationLost)
#define IDtcLuSubordinateDtc_BackedOut(This) (This)->lpVtbl->BackedOut(This)
#define IDtcLuSubordinateDtc_BackOut(This) (This)->lpVtbl->BackOut(This)
#define IDtcLuSubordinateDtc_Committed(This) (This)->lpVtbl->Committed(This)
#define IDtcLuSubordinateDtc_Forget(This) (This)->lpVtbl->Forget(This)
#define IDtcLuSubordinateDtc_Prepare(This) (This)->lpVtbl->Prepare(This)
#define IDtcLuSubordinateDtc_RequestCommit(This) (This)->lpVtbl->RequestCommit(This)
#endif
#endif
  HRESULT WINAPI IDtcLuSubordinateDtc_Unplug_Proxy(IDtcLuSubordinateDtc *This,WINBOOL fConversationLost);
  void __RPC_STUB IDtcLuSubordinateDtc_Unplug_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtc_BackedOut_Proxy(IDtcLuSubordinateDtc *This);
  void __RPC_STUB IDtcLuSubordinateDtc_BackedOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtc_BackOut_Proxy(IDtcLuSubordinateDtc *This);
  void __RPC_STUB IDtcLuSubordinateDtc_BackOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtc_Committed_Proxy(IDtcLuSubordinateDtc *This);
  void __RPC_STUB IDtcLuSubordinateDtc_Committed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtc_Forget_Proxy(IDtcLuSubordinateDtc *This);
  void __RPC_STUB IDtcLuSubordinateDtc_Forget_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtc_Prepare_Proxy(IDtcLuSubordinateDtc *This);
  void __RPC_STUB IDtcLuSubordinateDtc_Prepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtc_RequestCommit_Proxy(IDtcLuSubordinateDtc *This);
  void __RPC_STUB IDtcLuSubordinateDtc_RequestCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuSubordinateDtcSink_INTERFACE_DEFINED__
#define __IDtcLuSubordinateDtcSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuSubordinateDtcSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuSubordinateDtcSink : public IUnknown {
  public:
    virtual HRESULT WINAPI AckUnplug(void) = 0;
    virtual HRESULT WINAPI TmDown(void) = 0;
    virtual HRESULT WINAPI SessionLost(void) = 0;
    virtual HRESULT WINAPI BackedOut(void) = 0;
    virtual HRESULT WINAPI BackOut(void) = 0;
    virtual HRESULT WINAPI Committed(void) = 0;
    virtual HRESULT WINAPI Forget(void) = 0;
    virtual HRESULT WINAPI RequestCommit(void) = 0;
  };
#else
  typedef struct IDtcLuSubordinateDtcSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuSubordinateDtcSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuSubordinateDtcSink *This);
      ULONG (WINAPI *Release)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *AckUnplug)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *TmDown)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *SessionLost)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *BackedOut)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *BackOut)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *Committed)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *Forget)(IDtcLuSubordinateDtcSink *This);
      HRESULT (WINAPI *RequestCommit)(IDtcLuSubordinateDtcSink *This);
    END_INTERFACE
  } IDtcLuSubordinateDtcSinkVtbl;
  struct IDtcLuSubordinateDtcSink {
    CONST_VTBL struct IDtcLuSubordinateDtcSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuSubordinateDtcSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuSubordinateDtcSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuSubordinateDtcSink_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuSubordinateDtcSink_AckUnplug(This) (This)->lpVtbl->AckUnplug(This)
#define IDtcLuSubordinateDtcSink_TmDown(This) (This)->lpVtbl->TmDown(This)
#define IDtcLuSubordinateDtcSink_SessionLost(This) (This)->lpVtbl->SessionLost(This)
#define IDtcLuSubordinateDtcSink_BackedOut(This) (This)->lpVtbl->BackedOut(This)
#define IDtcLuSubordinateDtcSink_BackOut(This) (This)->lpVtbl->BackOut(This)
#define IDtcLuSubordinateDtcSink_Committed(This) (This)->lpVtbl->Committed(This)
#define IDtcLuSubordinateDtcSink_Forget(This) (This)->lpVtbl->Forget(This)
#define IDtcLuSubordinateDtcSink_RequestCommit(This) (This)->lpVtbl->RequestCommit(This)
#endif
#endif
  HRESULT WINAPI IDtcLuSubordinateDtcSink_AckUnplug_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_AckUnplug_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtcSink_TmDown_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_TmDown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtcSink_SessionLost_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_SessionLost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtcSink_BackedOut_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_BackedOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtcSink_BackOut_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_BackOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtcSink_Committed_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_Committed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtcSink_Forget_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_Forget_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcLuSubordinateDtcSink_RequestCommit_Proxy(IDtcLuSubordinateDtcSink *This);
  void __RPC_STUB IDtcLuSubordinateDtcSink_RequestCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcLuSubordinateDtcFactory_INTERFACE_DEFINED__
#define __IDtcLuSubordinateDtcFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcLuSubordinateDtcFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcLuSubordinateDtcFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(unsigned char *pucLuPair,DWORD cbLuPair,IUnknown *punkTransactionOuter,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOptions,ITransaction **ppTransaction,unsigned char *pTransId,DWORD cbTransId,IDtcLuSubordinateDtcSink *pSubordinateDtcSink,IDtcLuSubordinateDtc **ppSubordinateDtc) = 0;
  };
#else
  typedef struct IDtcLuSubordinateDtcFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcLuSubordinateDtcFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcLuSubordinateDtcFactory *This);
      ULONG (WINAPI *Release)(IDtcLuSubordinateDtcFactory *This);
      HRESULT (WINAPI *Create)(IDtcLuSubordinateDtcFactory *This,unsigned char *pucLuPair,DWORD cbLuPair,IUnknown *punkTransactionOuter,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOptions,ITransaction **ppTransaction,unsigned char *pTransId,DWORD cbTransId,IDtcLuSubordinateDtcSink *pSubordinateDtcSink,IDtcLuSubordinateDtc **ppSubordinateDtc);
    END_INTERFACE
  } IDtcLuSubordinateDtcFactoryVtbl;
  struct IDtcLuSubordinateDtcFactory {
    CONST_VTBL struct IDtcLuSubordinateDtcFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcLuSubordinateDtcFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcLuSubordinateDtcFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcLuSubordinateDtcFactory_Release(This) (This)->lpVtbl->Release(This)
#define IDtcLuSubordinateDtcFactory_Create(This,pucLuPair,cbLuPair,punkTransactionOuter,isoLevel,isoFlags,pOptions,ppTransaction,pTransId,cbTransId,pSubordinateDtcSink,ppSubordinateDtc) (This)->lpVtbl->Create(This,pucLuPair,cbLuPair,punkTransactionOuter,isoLevel,isoFlags,pOptions,ppTransaction,pTransId,cbTransId,pSubordinateDtcSink,ppSubordinateDtc)
#endif
#endif
  HRESULT WINAPI IDtcLuSubordinateDtcFactory_Create_Proxy(IDtcLuSubordinateDtcFactory *This,unsigned char *pucLuPair,DWORD cbLuPair,IUnknown *punkTransactionOuter,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOptions,ITransaction **ppTransaction,unsigned char *pTransId,DWORD cbTransId,IDtcLuSubordinateDtcSink *pSubordinateDtcSink,IDtcLuSubordinateDtc **ppSubordinateDtc);
  void __RPC_STUB IDtcLuSubordinateDtcFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(IID_IXATransLookup,0xF3B1F131,0xEEDA,0x11ce,0xAE,0xD4,0x00,0xAA,0x00,0x51,0xE2,0xC4);
  DEFINE_GUID(IID_IXATransLookup2,0xbf193c85,0xd1a,0x4290,0xb8,0x8f,0xd2,0xcb,0x88,0x73,0xd1,0xe7);
  DEFINE_GUID(IID_IResourceManagerSink,0x0D563181,0xDEFB,0x11ce,0xAE,0xD1,0x00,0xAA,0x00,0x51,0xE2,0xC4);
  DEFINE_GUID(IID_IResourceManager,0x3741d21,0x87eb,0x11ce,0x80,0x81,0x00,0x80,0xc7,0x58,0x52,0x7e);
  DEFINE_GUID(IID_IResourceManager2,0xd136c69a,0xf749,0x11d1,0x8f,0x47,0x0,0xc0,0x4f,0x8e,0xe5,0x7d);
  DEFINE_GUID(IID_ILastResourceManager,0x4d964ad4,0x5b33,0x11d3,0x8a,0x91,0x00,0xc0,0x4f,0x79,0xeb,0x6d);
  DEFINE_GUID(IID_IXAConfig,0xC8A6E3A1,0x9A8C,0x11cf,0xA3,0x08,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IRMHelper,0xE793F6D1,0xF53D,0x11cf,0xA6,0x0D,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IXAObtainRMInfo,0xE793F6D2,0xF53D,0x11cf,0xA6,0x0D,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IXAResourceManager,0x4131E751,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IXAResourceManagerFactory,0x4131E750,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IXATransaction,0x4131E752,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IResourceManagerFactory,0x13741d20,0x87eb,0x11ce,0x80,0x81,0x00,0x80,0xc7,0x58,0x52,0x7e);
  DEFINE_GUID(IID_IResourceManagerFactory2,0x6b369c21,0xfbd2,0x11d1,0x8f,0x47,0x0,0xc0,0x4f,0x8e,0xe5,0x7d);
  DEFINE_GUID(IID_IPrepareInfo,0x80c7bfd0,0x87ee,0x11ce,0x80,0x81,0x00,0x80,0xc7,0x58,0x52,0x7e);
  DEFINE_GUID(IID_IPrepareInfo2,0x5FAB2547,0x9779,0x11d1,0xB8,0x86,0x00,0xC0,0x4F,0xB9,0x61,0x8A);
  DEFINE_GUID(IID_IGetDispenser,0xc23cc370,0x87ef,0x11ce,0x80,0x81,0x00,0x80,0xc7,0x58,0x52,0x7e);
  DEFINE_GUID(IID_ITransactionVoterNotifyAsync2,0x5433376b,0x414d,0x11d3,0xb2,0x6,0x0,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_ITransactionVoterBallotAsync2,0x5433376c,0x414d,0x11d3,0xb2,0x6,0x0,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_ITransactionVoterFactory2,0x5433376a,0x414d,0x11d3,0xb2,0x6,0x0,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_ITransactionPhase0EnlistmentAsync,0x82DC88E1,0xA954,0x11d1,0x8F,0x88,0x00,0x60,0x08,0x95,0xE7,0xD5);
  DEFINE_GUID(IID_ITransactionPhase0NotifyAsync,0xEF081809,0x0C76,0x11d2,0x87,0xA6,0x00,0xC0,0x4F,0x99,0x0F,0x34);
  DEFINE_GUID(IID_ITransactionPhase0Factory,0x82DC88E0,0xA954,0x11d1,0x8F,0x88,0x00,0x60,0x08,0x95,0xE7,0xD5);
  DEFINE_GUID(IID_ITransactionTransmitter,0x59313E01,0xB36C,0x11cf,0xA5,0x39,0x00,0xAA,0x00,0x68,0x87,0xC3);
  DEFINE_GUID(IID_ITransactionTransmitterFactory,0x59313E00,0xB36C,0x11cf,0xA5,0x39,0x00,0xAA,0x00,0x68,0x87,0xC3);
  DEFINE_GUID(IID_ITransactionReceiver,0x59313E03,0xB36C,0x11cf,0xA5,0x39,0x00,0xAA,0x00,0x68,0x87,0xC3);
  DEFINE_GUID(IID_ITransactionReceiverFactory,0x59313E02,0xB36C,0x11cf,0xA5,0x39,0x00,0xAA,0x00,0x68,0x87,0xC3);
  DEFINE_GUID(IID_IDtcLuConfigure,0x4131E760,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRecovery,0xac2b8ad2,0xd6f0,0x11d0,0xb3,0x86,0x0,0xa0,0xc9,0x8,0x33,0x65);
  DEFINE_GUID(IID_IDtcLuRecoveryFactory,0x4131E762,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRecoveryInitiatedByDtcTransWork,0x4131E765,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRecoveryInitiatedByDtcStatusWork,0x4131E766,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRecoveryInitiatedByDtc,0x4131E764,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRecoveryInitiatedByLuWork,0xac2b8ad1,0xd6f0,0x11d0,0xb3,0x86,0x0,0xa0,0xc9,0x8,0x33,0x65);
  DEFINE_GUID(IID_IDtcLuRecoveryInitiatedByLu,0x4131E768,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRmEnlistment,0x4131E769,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRmEnlistmentSink,0x4131E770,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuRmEnlistmentFactory,0x4131E771,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuSubordinateDtc,0x4131E773,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuSubordinateDtcSink,0x4131E774,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);
  DEFINE_GUID(IID_IDtcLuSubordinateDtcFactory,0x4131E775,0x1AEA,0x11d0,0x94,0x4B,0x00,0xA0,0xC9,0x05,0x41,0x6E);

  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0155_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_txdtc_0155_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
