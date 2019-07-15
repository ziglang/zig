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
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __certexit_h__
#define __certexit_h__

#ifndef __ICertExit_FWD_DEFINED__
#define __ICertExit_FWD_DEFINED__
typedef struct ICertExit ICertExit;
#endif

#ifndef __ICertExit2_FWD_DEFINED__
#define __ICertExit2_FWD_DEFINED__
typedef struct ICertExit2 ICertExit2;
#endif

#include "wtypes.h"
#include "certmod.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define EXITEVENT_INVALID (0x0)
#define EXITEVENT_CERTISSUED (0x1)
#define EXITEVENT_CERTPENDING (0x2)
#define EXITEVENT_CERTDENIED (0x4)
#define EXITEVENT_CERTREVOKED (0x8)
#define EXITEVENT_CERTRETRIEVEPENDING (0x10)
#define EXITEVENT_CRLISSUED (0x20)
#define EXITEVENT_SHUTDOWN (0x40)
#define EXITEVENT_STARTUP (0x80)

  extern RPC_IF_HANDLE __MIDL_itf_certexit_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certexit_0000_v0_0_s_ifspec;

#ifndef __ICertExit_INTERFACE_DEFINED__
#define __ICertExit_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertExit;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertExit : public IDispatch {
  public:
    virtual HRESULT WINAPI Initialize(const BSTR strConfig,LONG *pEventMask) = 0;
    virtual HRESULT WINAPI Notify(LONG ExitEvent,LONG Context) = 0;
    virtual HRESULT WINAPI GetDescription(BSTR *pstrDescription) = 0;
  };
#else
  typedef struct ICertExitVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertExit *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertExit *This);
      ULONG (WINAPI *Release)(ICertExit *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertExit *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertExit *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertExit *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertExit *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Initialize)(ICertExit *This,const BSTR strConfig,LONG *pEventMask);
      HRESULT (WINAPI *Notify)(ICertExit *This,LONG ExitEvent,LONG Context);
      HRESULT (WINAPI *GetDescription)(ICertExit *This,BSTR *pstrDescription);
    END_INTERFACE
  } ICertExitVtbl;
  struct ICertExit {
    CONST_VTBL struct ICertExitVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertExit_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertExit_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertExit_Release(This) (This)->lpVtbl->Release(This)
#define ICertExit_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertExit_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertExit_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertExit_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertExit_Initialize(This,strConfig,pEventMask) (This)->lpVtbl->Initialize(This,strConfig,pEventMask)
#define ICertExit_Notify(This,ExitEvent,Context) (This)->lpVtbl->Notify(This,ExitEvent,Context)
#define ICertExit_GetDescription(This,pstrDescription) (This)->lpVtbl->GetDescription(This,pstrDescription)
#endif
#endif
  HRESULT WINAPI ICertExit_Initialize_Proxy(ICertExit *This,const BSTR strConfig,LONG *pEventMask);
  void __RPC_STUB ICertExit_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertExit_Notify_Proxy(ICertExit *This,LONG ExitEvent,LONG Context);
  void __RPC_STUB ICertExit_Notify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertExit_GetDescription_Proxy(ICertExit *This,BSTR *pstrDescription);
  void __RPC_STUB ICertExit_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertExit2_INTERFACE_DEFINED__
#define __ICertExit2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertExit2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertExit2 : public ICertExit {
  public:
    virtual HRESULT WINAPI GetManageModule(ICertManageModule **ppManageModule) = 0;
  };
#else
  typedef struct ICertExit2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertExit2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertExit2 *This);
      ULONG (WINAPI *Release)(ICertExit2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertExit2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertExit2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertExit2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertExit2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Initialize)(ICertExit2 *This,const BSTR strConfig,LONG *pEventMask);
      HRESULT (WINAPI *Notify)(ICertExit2 *This,LONG ExitEvent,LONG Context);
      HRESULT (WINAPI *GetDescription)(ICertExit2 *This,BSTR *pstrDescription);
      HRESULT (WINAPI *GetManageModule)(ICertExit2 *This,ICertManageModule **ppManageModule);
    END_INTERFACE
  } ICertExit2Vtbl;
  struct ICertExit2 {
    CONST_VTBL struct ICertExit2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertExit2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertExit2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertExit2_Release(This) (This)->lpVtbl->Release(This)
#define ICertExit2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertExit2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertExit2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertExit2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertExit2_Initialize(This,strConfig,pEventMask) (This)->lpVtbl->Initialize(This,strConfig,pEventMask)
#define ICertExit2_Notify(This,ExitEvent,Context) (This)->lpVtbl->Notify(This,ExitEvent,Context)
#define ICertExit2_GetDescription(This,pstrDescription) (This)->lpVtbl->GetDescription(This,pstrDescription)
#define ICertExit2_GetManageModule(This,ppManageModule) (This)->lpVtbl->GetManageModule(This,ppManageModule)
#endif
#endif
  HRESULT WINAPI ICertExit2_GetManageModule_Proxy(ICertExit2 *This,ICertManageModule **ppManageModule);
  void __RPC_STUB ICertExit2_GetManageModule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
