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

#ifndef __tsuserex_h__
#define __tsuserex_h__

#ifndef __TSUserExInterfaces_FWD_DEFINED__
#define __TSUserExInterfaces_FWD_DEFINED__
#ifdef __cplusplus
typedef class TSUserExInterfaces TSUserExInterfaces;
#else
typedef struct TSUserExInterfaces TSUserExInterfaces;
#endif
#endif

#ifndef __IADsTSUserEx_FWD_DEFINED__
#define __IADsTSUserEx_FWD_DEFINED__
typedef struct IADsTSUserEx IADsTSUserEx;
#endif

#ifndef __ADsTSUserEx_FWD_DEFINED__
#define __ADsTSUserEx_FWD_DEFINED__

#ifdef __cplusplus
typedef class ADsTSUserEx ADsTSUserEx;
#else
typedef struct ADsTSUserEx ADsTSUserEx;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "mmc.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __TSUSEREXLib_LIBRARY_DEFINED__
#define __TSUSEREXLib_LIBRARY_DEFINED__

  EXTERN_C const IID LIBID_TSUSEREXLib;
  EXTERN_C const CLSID CLSID_TSUserExInterfaces;

#ifdef __cplusplus
  class TSUserExInterfaces;
#endif

#ifndef __IADsTSUserEx_INTERFACE_DEFINED__
#define __IADsTSUserEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IADsTSUserEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IADsTSUserEx : public IDispatch {
  public:
    virtual HRESULT WINAPI get_TerminalServicesProfilePath(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_TerminalServicesProfilePath(BSTR pNewVal) = 0;
    virtual HRESULT WINAPI get_TerminalServicesHomeDirectory(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_TerminalServicesHomeDirectory(BSTR pNewVal) = 0;
    virtual HRESULT WINAPI get_TerminalServicesHomeDrive(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_TerminalServicesHomeDrive(BSTR pNewVal) = 0;
    virtual HRESULT WINAPI get_AllowLogon(LONG *pVal) = 0;
    virtual HRESULT WINAPI put_AllowLogon(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_EnableRemoteControl(LONG *pVal) = 0;
    virtual HRESULT WINAPI put_EnableRemoteControl(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_MaxDisconnectionTime(LONG *pVal) = 0;
    virtual HRESULT WINAPI put_MaxDisconnectionTime(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_MaxConnectionTime(LONG *pVal) = 0;
    virtual HRESULT WINAPI put_MaxConnectionTime(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_MaxIdleTime(LONG *pVal) = 0;
    virtual HRESULT WINAPI put_MaxIdleTime(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_ReconnectionAction(LONG *pNewVal) = 0;
    virtual HRESULT WINAPI put_ReconnectionAction(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_BrokenConnectionAction(LONG *pNewVal) = 0;
    virtual HRESULT WINAPI put_BrokenConnectionAction(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_ConnectClientDrivesAtLogon(LONG *pNewVal) = 0;
    virtual HRESULT WINAPI put_ConnectClientDrivesAtLogon(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_ConnectClientPrintersAtLogon(LONG *pVal) = 0;
    virtual HRESULT WINAPI put_ConnectClientPrintersAtLogon(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_DefaultToMainPrinter(LONG *pVal) = 0;
    virtual HRESULT WINAPI put_DefaultToMainPrinter(LONG NewVal) = 0;
    virtual HRESULT WINAPI get_TerminalServicesWorkDirectory(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_TerminalServicesWorkDirectory(BSTR pNewVal) = 0;
    virtual HRESULT WINAPI get_TerminalServicesInitialProgram(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_TerminalServicesInitialProgram(BSTR pNewVal) = 0;
  };
#else
  typedef struct IADsTSUserExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IADsTSUserEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IADsTSUserEx *This);
      ULONG (WINAPI *Release)(IADsTSUserEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IADsTSUserEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IADsTSUserEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IADsTSUserEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IADsTSUserEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_TerminalServicesProfilePath)(IADsTSUserEx *This,BSTR *pVal);
      HRESULT (WINAPI *put_TerminalServicesProfilePath)(IADsTSUserEx *This,BSTR pNewVal);
      HRESULT (WINAPI *get_TerminalServicesHomeDirectory)(IADsTSUserEx *This,BSTR *pVal);
      HRESULT (WINAPI *put_TerminalServicesHomeDirectory)(IADsTSUserEx *This,BSTR pNewVal);
      HRESULT (WINAPI *get_TerminalServicesHomeDrive)(IADsTSUserEx *This,BSTR *pVal);
      HRESULT (WINAPI *put_TerminalServicesHomeDrive)(IADsTSUserEx *This,BSTR pNewVal);
      HRESULT (WINAPI *get_AllowLogon)(IADsTSUserEx *This,LONG *pVal);
      HRESULT (WINAPI *put_AllowLogon)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_EnableRemoteControl)(IADsTSUserEx *This,LONG *pVal);
      HRESULT (WINAPI *put_EnableRemoteControl)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_MaxDisconnectionTime)(IADsTSUserEx *This,LONG *pVal);
      HRESULT (WINAPI *put_MaxDisconnectionTime)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_MaxConnectionTime)(IADsTSUserEx *This,LONG *pVal);
      HRESULT (WINAPI *put_MaxConnectionTime)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_MaxIdleTime)(IADsTSUserEx *This,LONG *pVal);
      HRESULT (WINAPI *put_MaxIdleTime)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_ReconnectionAction)(IADsTSUserEx *This,LONG *pNewVal);
      HRESULT (WINAPI *put_ReconnectionAction)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_BrokenConnectionAction)(IADsTSUserEx *This,LONG *pNewVal);
      HRESULT (WINAPI *put_BrokenConnectionAction)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_ConnectClientDrivesAtLogon)(IADsTSUserEx *This,LONG *pNewVal);
      HRESULT (WINAPI *put_ConnectClientDrivesAtLogon)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_ConnectClientPrintersAtLogon)(IADsTSUserEx *This,LONG *pVal);
      HRESULT (WINAPI *put_ConnectClientPrintersAtLogon)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_DefaultToMainPrinter)(IADsTSUserEx *This,LONG *pVal);
      HRESULT (WINAPI *put_DefaultToMainPrinter)(IADsTSUserEx *This,LONG NewVal);
      HRESULT (WINAPI *get_TerminalServicesWorkDirectory)(IADsTSUserEx *This,BSTR *pVal);
      HRESULT (WINAPI *put_TerminalServicesWorkDirectory)(IADsTSUserEx *This,BSTR pNewVal);
      HRESULT (WINAPI *get_TerminalServicesInitialProgram)(IADsTSUserEx *This,BSTR *pVal);
      HRESULT (WINAPI *put_TerminalServicesInitialProgram)(IADsTSUserEx *This,BSTR pNewVal);
    END_INTERFACE
  } IADsTSUserExVtbl;
  struct IADsTSUserEx {
    CONST_VTBL struct IADsTSUserExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IADsTSUserEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IADsTSUserEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IADsTSUserEx_Release(This) (This)->lpVtbl->Release(This)
#define IADsTSUserEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IADsTSUserEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IADsTSUserEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IADsTSUserEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IADsTSUserEx_get_TerminalServicesProfilePath(This,pVal) (This)->lpVtbl->get_TerminalServicesProfilePath(This,pVal)
#define IADsTSUserEx_put_TerminalServicesProfilePath(This,pNewVal) (This)->lpVtbl->put_TerminalServicesProfilePath(This,pNewVal)
#define IADsTSUserEx_get_TerminalServicesHomeDirectory(This,pVal) (This)->lpVtbl->get_TerminalServicesHomeDirectory(This,pVal)
#define IADsTSUserEx_put_TerminalServicesHomeDirectory(This,pNewVal) (This)->lpVtbl->put_TerminalServicesHomeDirectory(This,pNewVal)
#define IADsTSUserEx_get_TerminalServicesHomeDrive(This,pVal) (This)->lpVtbl->get_TerminalServicesHomeDrive(This,pVal)
#define IADsTSUserEx_put_TerminalServicesHomeDrive(This,pNewVal) (This)->lpVtbl->put_TerminalServicesHomeDrive(This,pNewVal)
#define IADsTSUserEx_get_AllowLogon(This,pVal) (This)->lpVtbl->get_AllowLogon(This,pVal)
#define IADsTSUserEx_put_AllowLogon(This,NewVal) (This)->lpVtbl->put_AllowLogon(This,NewVal)
#define IADsTSUserEx_get_EnableRemoteControl(This,pVal) (This)->lpVtbl->get_EnableRemoteControl(This,pVal)
#define IADsTSUserEx_put_EnableRemoteControl(This,NewVal) (This)->lpVtbl->put_EnableRemoteControl(This,NewVal)
#define IADsTSUserEx_get_MaxDisconnectionTime(This,pVal) (This)->lpVtbl->get_MaxDisconnectionTime(This,pVal)
#define IADsTSUserEx_put_MaxDisconnectionTime(This,NewVal) (This)->lpVtbl->put_MaxDisconnectionTime(This,NewVal)
#define IADsTSUserEx_get_MaxConnectionTime(This,pVal) (This)->lpVtbl->get_MaxConnectionTime(This,pVal)
#define IADsTSUserEx_put_MaxConnectionTime(This,NewVal) (This)->lpVtbl->put_MaxConnectionTime(This,NewVal)
#define IADsTSUserEx_get_MaxIdleTime(This,pVal) (This)->lpVtbl->get_MaxIdleTime(This,pVal)
#define IADsTSUserEx_put_MaxIdleTime(This,NewVal) (This)->lpVtbl->put_MaxIdleTime(This,NewVal)
#define IADsTSUserEx_get_ReconnectionAction(This,pNewVal) (This)->lpVtbl->get_ReconnectionAction(This,pNewVal)
#define IADsTSUserEx_put_ReconnectionAction(This,NewVal) (This)->lpVtbl->put_ReconnectionAction(This,NewVal)
#define IADsTSUserEx_get_BrokenConnectionAction(This,pNewVal) (This)->lpVtbl->get_BrokenConnectionAction(This,pNewVal)
#define IADsTSUserEx_put_BrokenConnectionAction(This,NewVal) (This)->lpVtbl->put_BrokenConnectionAction(This,NewVal)
#define IADsTSUserEx_get_ConnectClientDrivesAtLogon(This,pNewVal) (This)->lpVtbl->get_ConnectClientDrivesAtLogon(This,pNewVal)
#define IADsTSUserEx_put_ConnectClientDrivesAtLogon(This,NewVal) (This)->lpVtbl->put_ConnectClientDrivesAtLogon(This,NewVal)
#define IADsTSUserEx_get_ConnectClientPrintersAtLogon(This,pVal) (This)->lpVtbl->get_ConnectClientPrintersAtLogon(This,pVal)
#define IADsTSUserEx_put_ConnectClientPrintersAtLogon(This,NewVal) (This)->lpVtbl->put_ConnectClientPrintersAtLogon(This,NewVal)
#define IADsTSUserEx_get_DefaultToMainPrinter(This,pVal) (This)->lpVtbl->get_DefaultToMainPrinter(This,pVal)
#define IADsTSUserEx_put_DefaultToMainPrinter(This,NewVal) (This)->lpVtbl->put_DefaultToMainPrinter(This,NewVal)
#define IADsTSUserEx_get_TerminalServicesWorkDirectory(This,pVal) (This)->lpVtbl->get_TerminalServicesWorkDirectory(This,pVal)
#define IADsTSUserEx_put_TerminalServicesWorkDirectory(This,pNewVal) (This)->lpVtbl->put_TerminalServicesWorkDirectory(This,pNewVal)
#define IADsTSUserEx_get_TerminalServicesInitialProgram(This,pVal) (This)->lpVtbl->get_TerminalServicesInitialProgram(This,pVal)
#define IADsTSUserEx_put_TerminalServicesInitialProgram(This,pNewVal) (This)->lpVtbl->put_TerminalServicesInitialProgram(This,pNewVal)
#endif
#endif
  HRESULT WINAPI IADsTSUserEx_get_TerminalServicesProfilePath_Proxy(IADsTSUserEx *This,BSTR *pVal);
  void __RPC_STUB IADsTSUserEx_get_TerminalServicesProfilePath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_TerminalServicesProfilePath_Proxy(IADsTSUserEx *This,BSTR pNewVal);
  void __RPC_STUB IADsTSUserEx_put_TerminalServicesProfilePath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_TerminalServicesHomeDirectory_Proxy(IADsTSUserEx *This,BSTR *pVal);
  void __RPC_STUB IADsTSUserEx_get_TerminalServicesHomeDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_TerminalServicesHomeDirectory_Proxy(IADsTSUserEx *This,BSTR pNewVal);
  void __RPC_STUB IADsTSUserEx_put_TerminalServicesHomeDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_TerminalServicesHomeDrive_Proxy(IADsTSUserEx *This,BSTR *pVal);
  void __RPC_STUB IADsTSUserEx_get_TerminalServicesHomeDrive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_TerminalServicesHomeDrive_Proxy(IADsTSUserEx *This,BSTR pNewVal);
  void __RPC_STUB IADsTSUserEx_put_TerminalServicesHomeDrive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_AllowLogon_Proxy(IADsTSUserEx *This,LONG *pVal);
  void __RPC_STUB IADsTSUserEx_get_AllowLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_AllowLogon_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_AllowLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_EnableRemoteControl_Proxy(IADsTSUserEx *This,LONG *pVal);
  void __RPC_STUB IADsTSUserEx_get_EnableRemoteControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_EnableRemoteControl_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_EnableRemoteControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_MaxDisconnectionTime_Proxy(IADsTSUserEx *This,LONG *pVal);
  void __RPC_STUB IADsTSUserEx_get_MaxDisconnectionTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_MaxDisconnectionTime_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_MaxDisconnectionTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_MaxConnectionTime_Proxy(IADsTSUserEx *This,LONG *pVal);
  void __RPC_STUB IADsTSUserEx_get_MaxConnectionTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_MaxConnectionTime_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_MaxConnectionTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_MaxIdleTime_Proxy(IADsTSUserEx *This,LONG *pVal);
  void __RPC_STUB IADsTSUserEx_get_MaxIdleTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_MaxIdleTime_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_MaxIdleTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_ReconnectionAction_Proxy(IADsTSUserEx *This,LONG *pNewVal);
  void __RPC_STUB IADsTSUserEx_get_ReconnectionAction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_ReconnectionAction_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_ReconnectionAction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_BrokenConnectionAction_Proxy(IADsTSUserEx *This,LONG *pNewVal);
  void __RPC_STUB IADsTSUserEx_get_BrokenConnectionAction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_BrokenConnectionAction_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_BrokenConnectionAction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_ConnectClientDrivesAtLogon_Proxy(IADsTSUserEx *This,LONG *pNewVal);
  void __RPC_STUB IADsTSUserEx_get_ConnectClientDrivesAtLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_ConnectClientDrivesAtLogon_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_ConnectClientDrivesAtLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_ConnectClientPrintersAtLogon_Proxy(IADsTSUserEx *This,LONG *pVal);
  void __RPC_STUB IADsTSUserEx_get_ConnectClientPrintersAtLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_ConnectClientPrintersAtLogon_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_ConnectClientPrintersAtLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_DefaultToMainPrinter_Proxy(IADsTSUserEx *This,LONG *pVal);
  void __RPC_STUB IADsTSUserEx_get_DefaultToMainPrinter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_DefaultToMainPrinter_Proxy(IADsTSUserEx *This,LONG NewVal);
  void __RPC_STUB IADsTSUserEx_put_DefaultToMainPrinter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_TerminalServicesWorkDirectory_Proxy(IADsTSUserEx *This,BSTR *pVal);
  void __RPC_STUB IADsTSUserEx_get_TerminalServicesWorkDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_TerminalServicesWorkDirectory_Proxy(IADsTSUserEx *This,BSTR pNewVal);
  void __RPC_STUB IADsTSUserEx_put_TerminalServicesWorkDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_get_TerminalServicesInitialProgram_Proxy(IADsTSUserEx *This,BSTR *pVal);
  void __RPC_STUB IADsTSUserEx_get_TerminalServicesInitialProgram_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IADsTSUserEx_put_TerminalServicesInitialProgram_Proxy(IADsTSUserEx *This,BSTR pNewVal);
  void __RPC_STUB IADsTSUserEx_put_TerminalServicesInitialProgram_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_ADsTSUserEx;
#ifdef __cplusplus
  class ADsTSUserEx;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
