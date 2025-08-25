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

#ifndef __confpriv_h__
#define __confpriv_h__

#ifndef __IDummy_FWD_DEFINED__
#define __IDummy_FWD_DEFINED__
typedef struct IDummy IDummy;
#endif

#ifndef __ITLocalParticipant_FWD_DEFINED__
#define __ITLocalParticipant_FWD_DEFINED__
typedef struct ITLocalParticipant ITLocalParticipant;
#endif

#ifndef __IEnumParticipant_FWD_DEFINED__
#define __IEnumParticipant_FWD_DEFINED__
typedef struct IEnumParticipant IEnumParticipant;
#endif

#ifndef __ITParticipantControl_FWD_DEFINED__
#define __ITParticipantControl_FWD_DEFINED__
typedef struct ITParticipantControl ITParticipantControl;
#endif

#ifndef __ITParticipantSubStreamControl_FWD_DEFINED__
#define __ITParticipantSubStreamControl_FWD_DEFINED__
typedef struct ITParticipantSubStreamControl ITParticipantSubStreamControl;
#endif

#ifndef __ITParticipantEvent_FWD_DEFINED__
#define __ITParticipantEvent_FWD_DEFINED__
typedef struct ITParticipantEvent ITParticipantEvent;
#endif

#ifndef __IMulticastControl_FWD_DEFINED__
#define __IMulticastControl_FWD_DEFINED__
typedef struct IMulticastControl IMulticastControl;
#endif

#include "ipmsp.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum MULTICAST_LOOPBACK_MODE {
    MM_NO_LOOPBACK = 0,MM_FULL_LOOPBACK,MM_SELECTIVE_LOOPBACK
  } MULTICAST_LOOPBACK_MODE;

  extern RPC_IF_HANDLE __MIDL_itf_confpriv_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_confpriv_0000_v0_0_s_ifspec;

#ifndef __IDummy_INTERFACE_DEFINED__
#define __IDummy_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDummy;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDummy : public IUnknown {
  public:
  };
#else
  typedef struct IDummyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDummy *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDummy *This);
      ULONG (WINAPI *Release)(IDummy *This);
    END_INTERFACE
  } IDummyVtbl;
  struct IDummy {
    CONST_VTBL struct IDummyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDummy_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDummy_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDummy_Release(This) (This)->lpVtbl->Release(This)
#endif
#endif
#endif

#ifndef __ITLocalParticipant_INTERFACE_DEFINED__
#define __ITLocalParticipant_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITLocalParticipant;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITLocalParticipant : public IDispatch {
  public:
    virtual HRESULT WINAPI get_LocalParticipantTypedInfo(PARTICIPANT_TYPED_INFO InfoType,BSTR *ppInfo) = 0;
    virtual HRESULT WINAPI put_LocalParticipantTypedInfo(PARTICIPANT_TYPED_INFO InfoType,BSTR pInfo) = 0;
  };
#else
  typedef struct ITLocalParticipantVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITLocalParticipant *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITLocalParticipant *This);
      ULONG (WINAPI *Release)(ITLocalParticipant *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITLocalParticipant *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITLocalParticipant *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITLocalParticipant *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITLocalParticipant *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_LocalParticipantTypedInfo)(ITLocalParticipant *This,PARTICIPANT_TYPED_INFO InfoType,BSTR *ppInfo);
      HRESULT (WINAPI *put_LocalParticipantTypedInfo)(ITLocalParticipant *This,PARTICIPANT_TYPED_INFO InfoType,BSTR pInfo);
    END_INTERFACE
  } ITLocalParticipantVtbl;
  struct ITLocalParticipant {
    CONST_VTBL struct ITLocalParticipantVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITLocalParticipant_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITLocalParticipant_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITLocalParticipant_Release(This) (This)->lpVtbl->Release(This)
#define ITLocalParticipant_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITLocalParticipant_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITLocalParticipant_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITLocalParticipant_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITLocalParticipant_get_LocalParticipantTypedInfo(This,InfoType,ppInfo) (This)->lpVtbl->get_LocalParticipantTypedInfo(This,InfoType,ppInfo)
#define ITLocalParticipant_put_LocalParticipantTypedInfo(This,InfoType,pInfo) (This)->lpVtbl->put_LocalParticipantTypedInfo(This,InfoType,pInfo)
#endif
#endif
  HRESULT WINAPI ITLocalParticipant_get_LocalParticipantTypedInfo_Proxy(ITLocalParticipant *This,PARTICIPANT_TYPED_INFO InfoType,BSTR *ppInfo);
  void __RPC_STUB ITLocalParticipant_get_LocalParticipantTypedInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocalParticipant_put_LocalParticipantTypedInfo_Proxy(ITLocalParticipant *This,PARTICIPANT_TYPED_INFO InfoType,BSTR pInfo);
  void __RPC_STUB ITLocalParticipant_put_LocalParticipantTypedInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumParticipant_INTERFACE_DEFINED__
#define __IEnumParticipant_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumParticipant;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumParticipant : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITParticipant **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumParticipant **ppEnum) = 0;
  };
#else
  typedef struct IEnumParticipantVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumParticipant *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumParticipant *This);
      ULONG (WINAPI *Release)(IEnumParticipant *This);
      HRESULT (WINAPI *Next)(IEnumParticipant *This,ULONG celt,ITParticipant **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumParticipant *This);
      HRESULT (WINAPI *Skip)(IEnumParticipant *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumParticipant *This,IEnumParticipant **ppEnum);
    END_INTERFACE
  } IEnumParticipantVtbl;
  struct IEnumParticipant {
    CONST_VTBL struct IEnumParticipantVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumParticipant_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumParticipant_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumParticipant_Release(This) (This)->lpVtbl->Release(This)
#define IEnumParticipant_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumParticipant_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumParticipant_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumParticipant_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumParticipant_Next_Proxy(IEnumParticipant *This,ULONG celt,ITParticipant **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumParticipant_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumParticipant_Reset_Proxy(IEnumParticipant *This);
  void __RPC_STUB IEnumParticipant_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumParticipant_Skip_Proxy(IEnumParticipant *This,ULONG celt);
  void __RPC_STUB IEnumParticipant_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumParticipant_Clone_Proxy(IEnumParticipant *This,IEnumParticipant **ppEnum);
  void __RPC_STUB IEnumParticipant_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITParticipantControl_INTERFACE_DEFINED__
#define __ITParticipantControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITParticipantControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITParticipantControl : public IDispatch {
  public:
    virtual HRESULT WINAPI EnumerateParticipants(IEnumParticipant **ppEnumParticipants) = 0;
    virtual HRESULT WINAPI get_Participants(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITParticipantControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITParticipantControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITParticipantControl *This);
      ULONG (WINAPI *Release)(ITParticipantControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITParticipantControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITParticipantControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITParticipantControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITParticipantControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *EnumerateParticipants)(ITParticipantControl *This,IEnumParticipant **ppEnumParticipants);
      HRESULT (WINAPI *get_Participants)(ITParticipantControl *This,VARIANT *pVariant);
    END_INTERFACE
  } ITParticipantControlVtbl;
  struct ITParticipantControl {
    CONST_VTBL struct ITParticipantControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITParticipantControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITParticipantControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITParticipantControl_Release(This) (This)->lpVtbl->Release(This)
#define ITParticipantControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITParticipantControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITParticipantControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITParticipantControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITParticipantControl_EnumerateParticipants(This,ppEnumParticipants) (This)->lpVtbl->EnumerateParticipants(This,ppEnumParticipants)
#define ITParticipantControl_get_Participants(This,pVariant) (This)->lpVtbl->get_Participants(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITParticipantControl_EnumerateParticipants_Proxy(ITParticipantControl *This,IEnumParticipant **ppEnumParticipants);
  void __RPC_STUB ITParticipantControl_EnumerateParticipants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipantControl_get_Participants_Proxy(ITParticipantControl *This,VARIANT *pVariant);
  void __RPC_STUB ITParticipantControl_get_Participants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITParticipantSubStreamControl_INTERFACE_DEFINED__
#define __ITParticipantSubStreamControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITParticipantSubStreamControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITParticipantSubStreamControl : public IDispatch {
  public:
    virtual HRESULT WINAPI get_SubStreamFromParticipant(ITParticipant *pParticipant,ITSubStream **ppITSubStream) = 0;
    virtual HRESULT WINAPI get_ParticipantFromSubStream(ITSubStream *pITSubStream,ITParticipant **ppParticipant) = 0;
    virtual HRESULT WINAPI SwitchTerminalToSubStream(ITTerminal *pITTerminal,ITSubStream *pITSubStream) = 0;
  };
#else
  typedef struct ITParticipantSubStreamControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITParticipantSubStreamControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITParticipantSubStreamControl *This);
      ULONG (WINAPI *Release)(ITParticipantSubStreamControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITParticipantSubStreamControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITParticipantSubStreamControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITParticipantSubStreamControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITParticipantSubStreamControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SubStreamFromParticipant)(ITParticipantSubStreamControl *This,ITParticipant *pParticipant,ITSubStream **ppITSubStream);
      HRESULT (WINAPI *get_ParticipantFromSubStream)(ITParticipantSubStreamControl *This,ITSubStream *pITSubStream,ITParticipant **ppParticipant);
      HRESULT (WINAPI *SwitchTerminalToSubStream)(ITParticipantSubStreamControl *This,ITTerminal *pITTerminal,ITSubStream *pITSubStream);
    END_INTERFACE
  } ITParticipantSubStreamControlVtbl;
  struct ITParticipantSubStreamControl {
    CONST_VTBL struct ITParticipantSubStreamControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITParticipantSubStreamControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITParticipantSubStreamControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITParticipantSubStreamControl_Release(This) (This)->lpVtbl->Release(This)
#define ITParticipantSubStreamControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITParticipantSubStreamControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITParticipantSubStreamControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITParticipantSubStreamControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITParticipantSubStreamControl_get_SubStreamFromParticipant(This,pParticipant,ppITSubStream) (This)->lpVtbl->get_SubStreamFromParticipant(This,pParticipant,ppITSubStream)
#define ITParticipantSubStreamControl_get_ParticipantFromSubStream(This,pITSubStream,ppParticipant) (This)->lpVtbl->get_ParticipantFromSubStream(This,pITSubStream,ppParticipant)
#define ITParticipantSubStreamControl_SwitchTerminalToSubStream(This,pITTerminal,pITSubStream) (This)->lpVtbl->SwitchTerminalToSubStream(This,pITTerminal,pITSubStream)
#endif
#endif
  HRESULT WINAPI ITParticipantSubStreamControl_get_SubStreamFromParticipant_Proxy(ITParticipantSubStreamControl *This,ITParticipant *pParticipant,ITSubStream **ppITSubStream);
  void __RPC_STUB ITParticipantSubStreamControl_get_SubStreamFromParticipant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipantSubStreamControl_get_ParticipantFromSubStream_Proxy(ITParticipantSubStreamControl *This,ITSubStream *pITSubStream,ITParticipant **ppParticipant);
  void __RPC_STUB ITParticipantSubStreamControl_get_ParticipantFromSubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipantSubStreamControl_SwitchTerminalToSubStream_Proxy(ITParticipantSubStreamControl *This,ITTerminal *pITTerminal,ITSubStream *pITSubStream);
  void __RPC_STUB ITParticipantSubStreamControl_SwitchTerminalToSubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITParticipantEvent_INTERFACE_DEFINED__
#define __ITParticipantEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITParticipantEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITParticipantEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Event(PARTICIPANT_EVENT *pParticipantEvent) = 0;
    virtual HRESULT WINAPI get_Participant(ITParticipant **ppParticipant) = 0;
    virtual HRESULT WINAPI get_SubStream(ITSubStream **ppSubStream) = 0;
  };
#else
  typedef struct ITParticipantEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITParticipantEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITParticipantEvent *This);
      ULONG (WINAPI *Release)(ITParticipantEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITParticipantEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITParticipantEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITParticipantEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITParticipantEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Event)(ITParticipantEvent *This,PARTICIPANT_EVENT *pParticipantEvent);
      HRESULT (WINAPI *get_Participant)(ITParticipantEvent *This,ITParticipant **ppParticipant);
      HRESULT (WINAPI *get_SubStream)(ITParticipantEvent *This,ITSubStream **ppSubStream);
    END_INTERFACE
  } ITParticipantEventVtbl;
  struct ITParticipantEvent {
    CONST_VTBL struct ITParticipantEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITParticipantEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITParticipantEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITParticipantEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITParticipantEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITParticipantEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITParticipantEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITParticipantEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITParticipantEvent_get_Event(This,pParticipantEvent) (This)->lpVtbl->get_Event(This,pParticipantEvent)
#define ITParticipantEvent_get_Participant(This,ppParticipant) (This)->lpVtbl->get_Participant(This,ppParticipant)
#define ITParticipantEvent_get_SubStream(This,ppSubStream) (This)->lpVtbl->get_SubStream(This,ppSubStream)
#endif
#endif
  HRESULT WINAPI ITParticipantEvent_get_Event_Proxy(ITParticipantEvent *This,PARTICIPANT_EVENT *pParticipantEvent);
  void __RPC_STUB ITParticipantEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipantEvent_get_Participant_Proxy(ITParticipantEvent *This,ITParticipant **ppParticipant);
  void __RPC_STUB ITParticipantEvent_get_Participant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipantEvent_get_SubStream_Proxy(ITParticipantEvent *This,ITSubStream **ppSubStream);
  void __RPC_STUB ITParticipantEvent_get_SubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMulticastControl_INTERFACE_DEFINED__
#define __IMulticastControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMulticastControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMulticastControl : public IDispatch {
  public:
    virtual HRESULT WINAPI get_LoopbackMode(MULTICAST_LOOPBACK_MODE *pMode) = 0;
    virtual HRESULT WINAPI put_LoopbackMode(MULTICAST_LOOPBACK_MODE mode) = 0;
  };
#else
  typedef struct IMulticastControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMulticastControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMulticastControl *This);
      ULONG (WINAPI *Release)(IMulticastControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMulticastControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMulticastControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMulticastControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMulticastControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_LoopbackMode)(IMulticastControl *This,MULTICAST_LOOPBACK_MODE *pMode);
      HRESULT (WINAPI *put_LoopbackMode)(IMulticastControl *This,MULTICAST_LOOPBACK_MODE mode);
    END_INTERFACE
  } IMulticastControlVtbl;
  struct IMulticastControl {
    CONST_VTBL struct IMulticastControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMulticastControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMulticastControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMulticastControl_Release(This) (This)->lpVtbl->Release(This)
#define IMulticastControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMulticastControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMulticastControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMulticastControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMulticastControl_get_LoopbackMode(This,pMode) (This)->lpVtbl->get_LoopbackMode(This,pMode)
#define IMulticastControl_put_LoopbackMode(This,mode) (This)->lpVtbl->put_LoopbackMode(This,mode)
#endif
#endif
  HRESULT WINAPI IMulticastControl_get_LoopbackMode_Proxy(IMulticastControl *This,MULTICAST_LOOPBACK_MODE *pMode);
  void __RPC_STUB IMulticastControl_get_LoopbackMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMulticastControl_put_LoopbackMode_Proxy(IMulticastControl *This,MULTICAST_LOOPBACK_MODE mode);
  void __RPC_STUB IMulticastControl_put_LoopbackMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
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
