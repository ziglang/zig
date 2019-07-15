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

#ifndef __sensevts_h__
#define __sensevts_h__

#ifndef __ISensNetwork_FWD_DEFINED__
#define __ISensNetwork_FWD_DEFINED__
typedef struct ISensNetwork ISensNetwork;
#endif

#ifndef __ISensOnNow_FWD_DEFINED__
#define __ISensOnNow_FWD_DEFINED__
typedef struct ISensOnNow ISensOnNow;
#endif

#ifndef __ISensLogon_FWD_DEFINED__
#define __ISensLogon_FWD_DEFINED__
typedef struct ISensLogon ISensLogon;
#endif

#ifndef __ISensLogon2_FWD_DEFINED__
#define __ISensLogon2_FWD_DEFINED__
typedef struct ISensLogon2 ISensLogon2;
#endif

#ifndef __SENS_FWD_DEFINED__
#define __SENS_FWD_DEFINED__
#ifdef __cplusplus
typedef class SENS SENS;
#else
typedef struct SENS SENS;
#endif
#endif

#include "wtypes.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __SensEvents_LIBRARY_DEFINED__
#define __SensEvents_LIBRARY_DEFINED__
  typedef struct SENS_QOCINFO {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwOutSpeed;
    DWORD dwInSpeed;
  } SENS_QOCINFO;

  typedef SENS_QOCINFO *LPSENS_QOCINFO;

  EXTERN_C const IID LIBID_SensEvents;
#ifndef __ISensNetwork_INTERFACE_DEFINED__
#define __ISensNetwork_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISensNetwork;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISensNetwork : public IDispatch {
  public:
    virtual HRESULT WINAPI ConnectionMade(BSTR bstrConnection,ULONG ulType,LPSENS_QOCINFO lpQOCInfo) = 0;
    virtual HRESULT WINAPI ConnectionMadeNoQOCInfo(BSTR bstrConnection,ULONG ulType) = 0;
    virtual HRESULT WINAPI ConnectionLost(BSTR bstrConnection,ULONG ulType) = 0;
    virtual HRESULT WINAPI DestinationReachable(BSTR bstrDestination,BSTR bstrConnection,ULONG ulType,LPSENS_QOCINFO lpQOCInfo) = 0;
    virtual HRESULT WINAPI DestinationReachableNoQOCInfo(BSTR bstrDestination,BSTR bstrConnection,ULONG ulType) = 0;
  };
#else
  typedef struct ISensNetworkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISensNetwork *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISensNetwork *This);
      ULONG (WINAPI *Release)(ISensNetwork *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISensNetwork *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISensNetwork *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISensNetwork *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISensNetwork *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ConnectionMade)(ISensNetwork *This,BSTR bstrConnection,ULONG ulType,LPSENS_QOCINFO lpQOCInfo);
      HRESULT (WINAPI *ConnectionMadeNoQOCInfo)(ISensNetwork *This,BSTR bstrConnection,ULONG ulType);
      HRESULT (WINAPI *ConnectionLost)(ISensNetwork *This,BSTR bstrConnection,ULONG ulType);
      HRESULT (WINAPI *DestinationReachable)(ISensNetwork *This,BSTR bstrDestination,BSTR bstrConnection,ULONG ulType,LPSENS_QOCINFO lpQOCInfo);
      HRESULT (WINAPI *DestinationReachableNoQOCInfo)(ISensNetwork *This,BSTR bstrDestination,BSTR bstrConnection,ULONG ulType);
    END_INTERFACE
  } ISensNetworkVtbl;
  struct ISensNetwork {
    CONST_VTBL struct ISensNetworkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISensNetwork_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISensNetwork_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISensNetwork_Release(This) (This)->lpVtbl->Release(This)
#define ISensNetwork_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISensNetwork_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISensNetwork_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISensNetwork_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISensNetwork_ConnectionMade(This,bstrConnection,ulType,lpQOCInfo) (This)->lpVtbl->ConnectionMade(This,bstrConnection,ulType,lpQOCInfo)
#define ISensNetwork_ConnectionMadeNoQOCInfo(This,bstrConnection,ulType) (This)->lpVtbl->ConnectionMadeNoQOCInfo(This,bstrConnection,ulType)
#define ISensNetwork_ConnectionLost(This,bstrConnection,ulType) (This)->lpVtbl->ConnectionLost(This,bstrConnection,ulType)
#define ISensNetwork_DestinationReachable(This,bstrDestination,bstrConnection,ulType,lpQOCInfo) (This)->lpVtbl->DestinationReachable(This,bstrDestination,bstrConnection,ulType,lpQOCInfo)
#define ISensNetwork_DestinationReachableNoQOCInfo(This,bstrDestination,bstrConnection,ulType) (This)->lpVtbl->DestinationReachableNoQOCInfo(This,bstrDestination,bstrConnection,ulType)
#endif
#endif
  HRESULT WINAPI ISensNetwork_ConnectionMade_Proxy(ISensNetwork *This,BSTR bstrConnection,ULONG ulType,LPSENS_QOCINFO lpQOCInfo);
  void __RPC_STUB ISensNetwork_ConnectionMade_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensNetwork_ConnectionMadeNoQOCInfo_Proxy(ISensNetwork *This,BSTR bstrConnection,ULONG ulType);
  void __RPC_STUB ISensNetwork_ConnectionMadeNoQOCInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensNetwork_ConnectionLost_Proxy(ISensNetwork *This,BSTR bstrConnection,ULONG ulType);
  void __RPC_STUB ISensNetwork_ConnectionLost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensNetwork_DestinationReachable_Proxy(ISensNetwork *This,BSTR bstrDestination,BSTR bstrConnection,ULONG ulType,LPSENS_QOCINFO lpQOCInfo);
  void __RPC_STUB ISensNetwork_DestinationReachable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensNetwork_DestinationReachableNoQOCInfo_Proxy(ISensNetwork *This,BSTR bstrDestination,BSTR bstrConnection,ULONG ulType);
  void __RPC_STUB ISensNetwork_DestinationReachableNoQOCInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISensOnNow_INTERFACE_DEFINED__
#define __ISensOnNow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISensOnNow;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISensOnNow : public IDispatch {
  public:
    virtual HRESULT WINAPI OnACPower(void) = 0;
    virtual HRESULT WINAPI OnBatteryPower(DWORD dwBatteryLifePercent) = 0;
    virtual HRESULT WINAPI BatteryLow(DWORD dwBatteryLifePercent) = 0;
  };
#else
  typedef struct ISensOnNowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISensOnNow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISensOnNow *This);
      ULONG (WINAPI *Release)(ISensOnNow *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISensOnNow *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISensOnNow *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISensOnNow *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISensOnNow *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OnACPower)(ISensOnNow *This);
      HRESULT (WINAPI *OnBatteryPower)(ISensOnNow *This,DWORD dwBatteryLifePercent);
      HRESULT (WINAPI *BatteryLow)(ISensOnNow *This,DWORD dwBatteryLifePercent);
    END_INTERFACE
  } ISensOnNowVtbl;
  struct ISensOnNow {
    CONST_VTBL struct ISensOnNowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISensOnNow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISensOnNow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISensOnNow_Release(This) (This)->lpVtbl->Release(This)
#define ISensOnNow_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISensOnNow_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISensOnNow_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISensOnNow_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISensOnNow_OnACPower(This) (This)->lpVtbl->OnACPower(This)
#define ISensOnNow_OnBatteryPower(This,dwBatteryLifePercent) (This)->lpVtbl->OnBatteryPower(This,dwBatteryLifePercent)
#define ISensOnNow_BatteryLow(This,dwBatteryLifePercent) (This)->lpVtbl->BatteryLow(This,dwBatteryLifePercent)
#endif
#endif
  HRESULT WINAPI ISensOnNow_OnACPower_Proxy(ISensOnNow *This);
  void __RPC_STUB ISensOnNow_OnACPower_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensOnNow_OnBatteryPower_Proxy(ISensOnNow *This,DWORD dwBatteryLifePercent);
  void __RPC_STUB ISensOnNow_OnBatteryPower_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensOnNow_BatteryLow_Proxy(ISensOnNow *This,DWORD dwBatteryLifePercent);
  void __RPC_STUB ISensOnNow_BatteryLow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISensLogon_INTERFACE_DEFINED__
#define __ISensLogon_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISensLogon;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISensLogon : public IDispatch {
  public:
    virtual HRESULT WINAPI Logon(BSTR bstrUserName) = 0;
    virtual HRESULT WINAPI Logoff(BSTR bstrUserName) = 0;
    virtual HRESULT WINAPI StartShell(BSTR bstrUserName) = 0;
    virtual HRESULT WINAPI DisplayLock(BSTR bstrUserName) = 0;
    virtual HRESULT WINAPI DisplayUnlock(BSTR bstrUserName) = 0;
    virtual HRESULT WINAPI StartScreenSaver(BSTR bstrUserName) = 0;
    virtual HRESULT WINAPI StopScreenSaver(BSTR bstrUserName) = 0;
  };
#else
  typedef struct ISensLogonVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISensLogon *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISensLogon *This);
      ULONG (WINAPI *Release)(ISensLogon *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISensLogon *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISensLogon *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISensLogon *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISensLogon *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Logon)(ISensLogon *This,BSTR bstrUserName);
      HRESULT (WINAPI *Logoff)(ISensLogon *This,BSTR bstrUserName);
      HRESULT (WINAPI *StartShell)(ISensLogon *This,BSTR bstrUserName);
      HRESULT (WINAPI *DisplayLock)(ISensLogon *This,BSTR bstrUserName);
      HRESULT (WINAPI *DisplayUnlock)(ISensLogon *This,BSTR bstrUserName);
      HRESULT (WINAPI *StartScreenSaver)(ISensLogon *This,BSTR bstrUserName);
      HRESULT (WINAPI *StopScreenSaver)(ISensLogon *This,BSTR bstrUserName);
    END_INTERFACE
  } ISensLogonVtbl;
  struct ISensLogon {
    CONST_VTBL struct ISensLogonVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISensLogon_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISensLogon_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISensLogon_Release(This) (This)->lpVtbl->Release(This)
#define ISensLogon_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISensLogon_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISensLogon_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISensLogon_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISensLogon_Logon(This,bstrUserName) (This)->lpVtbl->Logon(This,bstrUserName)
#define ISensLogon_Logoff(This,bstrUserName) (This)->lpVtbl->Logoff(This,bstrUserName)
#define ISensLogon_StartShell(This,bstrUserName) (This)->lpVtbl->StartShell(This,bstrUserName)
#define ISensLogon_DisplayLock(This,bstrUserName) (This)->lpVtbl->DisplayLock(This,bstrUserName)
#define ISensLogon_DisplayUnlock(This,bstrUserName) (This)->lpVtbl->DisplayUnlock(This,bstrUserName)
#define ISensLogon_StartScreenSaver(This,bstrUserName) (This)->lpVtbl->StartScreenSaver(This,bstrUserName)
#define ISensLogon_StopScreenSaver(This,bstrUserName) (This)->lpVtbl->StopScreenSaver(This,bstrUserName)
#endif
#endif
  HRESULT WINAPI ISensLogon_Logon_Proxy(ISensLogon *This,BSTR bstrUserName);
  void __RPC_STUB ISensLogon_Logon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon_Logoff_Proxy(ISensLogon *This,BSTR bstrUserName);
  void __RPC_STUB ISensLogon_Logoff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon_StartShell_Proxy(ISensLogon *This,BSTR bstrUserName);
  void __RPC_STUB ISensLogon_StartShell_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon_DisplayLock_Proxy(ISensLogon *This,BSTR bstrUserName);
  void __RPC_STUB ISensLogon_DisplayLock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon_DisplayUnlock_Proxy(ISensLogon *This,BSTR bstrUserName);
  void __RPC_STUB ISensLogon_DisplayUnlock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon_StartScreenSaver_Proxy(ISensLogon *This,BSTR bstrUserName);
  void __RPC_STUB ISensLogon_StartScreenSaver_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon_StopScreenSaver_Proxy(ISensLogon *This,BSTR bstrUserName);
  void __RPC_STUB ISensLogon_StopScreenSaver_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISensLogon2_INTERFACE_DEFINED__
#define __ISensLogon2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISensLogon2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISensLogon2 : public IDispatch {
  public:
    virtual HRESULT WINAPI Logon(BSTR bstrUserName,DWORD dwSessionId) = 0;
    virtual HRESULT WINAPI Logoff(BSTR bstrUserName,DWORD dwSessionId) = 0;
    virtual HRESULT WINAPI SessionDisconnect(BSTR bstrUserName,DWORD dwSessionId) = 0;
    virtual HRESULT WINAPI SessionReconnect(BSTR bstrUserName,DWORD dwSessionId) = 0;
    virtual HRESULT WINAPI PostShell(BSTR bstrUserName,DWORD dwSessionId) = 0;
  };
#else
  typedef struct ISensLogon2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISensLogon2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISensLogon2 *This);
      ULONG (WINAPI *Release)(ISensLogon2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISensLogon2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISensLogon2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISensLogon2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISensLogon2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Logon)(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
      HRESULT (WINAPI *Logoff)(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
      HRESULT (WINAPI *SessionDisconnect)(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
      HRESULT (WINAPI *SessionReconnect)(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
      HRESULT (WINAPI *PostShell)(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
    END_INTERFACE
  } ISensLogon2Vtbl;
  struct ISensLogon2 {
    CONST_VTBL struct ISensLogon2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISensLogon2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISensLogon2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISensLogon2_Release(This) (This)->lpVtbl->Release(This)
#define ISensLogon2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISensLogon2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISensLogon2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISensLogon2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISensLogon2_Logon(This,bstrUserName,dwSessionId) (This)->lpVtbl->Logon(This,bstrUserName,dwSessionId)
#define ISensLogon2_Logoff(This,bstrUserName,dwSessionId) (This)->lpVtbl->Logoff(This,bstrUserName,dwSessionId)
#define ISensLogon2_SessionDisconnect(This,bstrUserName,dwSessionId) (This)->lpVtbl->SessionDisconnect(This,bstrUserName,dwSessionId)
#define ISensLogon2_SessionReconnect(This,bstrUserName,dwSessionId) (This)->lpVtbl->SessionReconnect(This,bstrUserName,dwSessionId)
#define ISensLogon2_PostShell(This,bstrUserName,dwSessionId) (This)->lpVtbl->PostShell(This,bstrUserName,dwSessionId)
#endif
#endif
  HRESULT WINAPI ISensLogon2_Logon_Proxy(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
  void __RPC_STUB ISensLogon2_Logon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon2_Logoff_Proxy(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
  void __RPC_STUB ISensLogon2_Logoff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon2_SessionDisconnect_Proxy(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
  void __RPC_STUB ISensLogon2_SessionDisconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon2_SessionReconnect_Proxy(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
  void __RPC_STUB ISensLogon2_SessionReconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISensLogon2_PostShell_Proxy(ISensLogon2 *This,BSTR bstrUserName,DWORD dwSessionId);
  void __RPC_STUB ISensLogon2_PostShell_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_SENS;
#ifdef __cplusplus
  class SENS;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
