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

#ifndef __eventsys_h__
#define __eventsys_h__

#ifndef __IEventSystem_FWD_DEFINED__
#define __IEventSystem_FWD_DEFINED__
typedef struct IEventSystem IEventSystem;
#endif

#ifndef __IEventPublisher_FWD_DEFINED__
#define __IEventPublisher_FWD_DEFINED__
typedef struct IEventPublisher IEventPublisher;
#endif

#ifndef __IEventClass_FWD_DEFINED__
#define __IEventClass_FWD_DEFINED__
typedef struct IEventClass IEventClass;
#endif

#ifndef __IEventClass2_FWD_DEFINED__
#define __IEventClass2_FWD_DEFINED__
typedef struct IEventClass2 IEventClass2;
#endif

#ifndef __IEventSubscription_FWD_DEFINED__
#define __IEventSubscription_FWD_DEFINED__
typedef struct IEventSubscription IEventSubscription;
#endif

#ifndef __IFiringControl_FWD_DEFINED__
#define __IFiringControl_FWD_DEFINED__
typedef struct IFiringControl IFiringControl;
#endif

#ifndef __IPublisherFilter_FWD_DEFINED__
#define __IPublisherFilter_FWD_DEFINED__
typedef struct IPublisherFilter IPublisherFilter;
#endif

#ifndef __IMultiInterfacePublisherFilter_FWD_DEFINED__
#define __IMultiInterfacePublisherFilter_FWD_DEFINED__
typedef struct IMultiInterfacePublisherFilter IMultiInterfacePublisherFilter;
#endif

#ifndef __IEventObjectChange_FWD_DEFINED__
#define __IEventObjectChange_FWD_DEFINED__
typedef struct IEventObjectChange IEventObjectChange;
#endif

#ifndef __IEventObjectChange2_FWD_DEFINED__
#define __IEventObjectChange2_FWD_DEFINED__
typedef struct IEventObjectChange2 IEventObjectChange2;
#endif

#ifndef __IEnumEventObject_FWD_DEFINED__
#define __IEnumEventObject_FWD_DEFINED__
typedef struct IEnumEventObject IEnumEventObject;
#endif

#ifndef __IEventObjectCollection_FWD_DEFINED__
#define __IEventObjectCollection_FWD_DEFINED__
typedef struct IEventObjectCollection IEventObjectCollection;
#endif

#ifndef __IEventProperty_FWD_DEFINED__
#define __IEventProperty_FWD_DEFINED__
typedef struct IEventProperty IEventProperty;
#endif

#ifndef __IEventControl_FWD_DEFINED__
#define __IEventControl_FWD_DEFINED__
typedef struct IEventControl IEventControl;
#endif

#ifndef __IMultiInterfaceEventControl_FWD_DEFINED__
#define __IMultiInterfaceEventControl_FWD_DEFINED__
typedef struct IMultiInterfaceEventControl IMultiInterfaceEventControl;
#endif

#ifndef __CEventSystem_FWD_DEFINED__
#define __CEventSystem_FWD_DEFINED__
#ifdef __cplusplus
typedef class CEventSystem CEventSystem;
#else
typedef struct CEventSystem CEventSystem;
#endif
#endif

#ifndef __CEventPublisher_FWD_DEFINED__
#define __CEventPublisher_FWD_DEFINED__
#ifdef __cplusplus
typedef class CEventPublisher CEventPublisher;
#else
typedef struct CEventPublisher CEventPublisher;
#endif
#endif

#ifndef __CEventClass_FWD_DEFINED__
#define __CEventClass_FWD_DEFINED__
#ifdef __cplusplus
typedef class CEventClass CEventClass;
#else
typedef struct CEventClass CEventClass;
#endif
#endif

#ifndef __CEventSubscription_FWD_DEFINED__
#define __CEventSubscription_FWD_DEFINED__
#ifdef __cplusplus
typedef class CEventSubscription CEventSubscription;
#else
typedef struct CEventSubscription CEventSubscription;
#endif
#endif

#ifndef __EventObjectChange_FWD_DEFINED__
#define __EventObjectChange_FWD_DEFINED__
#ifdef __cplusplus
typedef class EventObjectChange EventObjectChange;
#else
typedef struct EventObjectChange EventObjectChange;
#endif
#endif

#ifndef __EventObjectChange2_FWD_DEFINED__
#define __EventObjectChange2_FWD_DEFINED__
#ifdef __cplusplus
typedef class EventObjectChange2 EventObjectChange2;
#else
typedef struct EventObjectChange2 EventObjectChange2;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define PROGID_EventSystem OLESTR("EventSystem.EventSystem")
#define PROGID_EventPublisher OLESTR("EventSystem.EventPublisher")
#define PROGID_EventClass OLESTR("EventSystem.EventClass")
#define PROGID_EventSubscription OLESTR("EventSystem.EventSubscription")
#define PROGID_EventPublisherCollection OLESTR("EventSystem.EventPublisherCollection")
#define PROGID_EventClassCollection OLESTR("EventSystem.EventClassCollection")
#define PROGID_EventSubscriptionCollection OLESTR("EventSystem.EventSubscriptionCollection")
#define PROGID_EventSubsystem OLESTR("EventSystem.EventSubsystem")
#define EVENTSYSTEM_PUBLISHER_ID OLESTR("{d0564c30-9df4-11d1-a281-00c04fca0aa7}")
#define EVENTSYSTEM_SUBSYSTEM_CLSID OLESTR("{503c1fd8-b605-11d2-a92d-006008c60e24}")

  extern RPC_IF_HANDLE __MIDL_itf_eventsys_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_eventsys_0000_v0_0_s_ifspec;

#ifndef __IEventSystem_INTERFACE_DEFINED__
#define __IEventSystem_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventSystem;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventSystem : public IDispatch {
  public:
    virtual HRESULT WINAPI Query(BSTR progID,BSTR queryCriteria,int *errorIndex,IUnknown **ppInterface) = 0;
    virtual HRESULT WINAPI Store(BSTR ProgID,IUnknown *pInterface) = 0;
    virtual HRESULT WINAPI Remove(BSTR progID,BSTR queryCriteria,int *errorIndex) = 0;
    virtual HRESULT WINAPI get_EventObjectChangeEventClassID(BSTR *pbstrEventClassID) = 0;
    virtual HRESULT WINAPI QueryS(BSTR progID,BSTR queryCriteria,IUnknown **ppInterface) = 0;
    virtual HRESULT WINAPI RemoveS(BSTR progID,BSTR queryCriteria) = 0;
  };
#else
  typedef struct IEventSystemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventSystem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventSystem *This);
      ULONG (WINAPI *Release)(IEventSystem *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventSystem *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventSystem *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventSystem *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventSystem *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Query)(IEventSystem *This,BSTR progID,BSTR queryCriteria,int *errorIndex,IUnknown **ppInterface);
      HRESULT (WINAPI *Store)(IEventSystem *This,BSTR ProgID,IUnknown *pInterface);
      HRESULT (WINAPI *Remove)(IEventSystem *This,BSTR progID,BSTR queryCriteria,int *errorIndex);
      HRESULT (WINAPI *get_EventObjectChangeEventClassID)(IEventSystem *This,BSTR *pbstrEventClassID);
      HRESULT (WINAPI *QueryS)(IEventSystem *This,BSTR progID,BSTR queryCriteria,IUnknown **ppInterface);
      HRESULT (WINAPI *RemoveS)(IEventSystem *This,BSTR progID,BSTR queryCriteria);
    END_INTERFACE
  } IEventSystemVtbl;
  struct IEventSystem {
    CONST_VTBL struct IEventSystemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventSystem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventSystem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventSystem_Release(This) (This)->lpVtbl->Release(This)
#define IEventSystem_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventSystem_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventSystem_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventSystem_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventSystem_Query(This,progID,queryCriteria,errorIndex,ppInterface) (This)->lpVtbl->Query(This,progID,queryCriteria,errorIndex,ppInterface)
#define IEventSystem_Store(This,ProgID,pInterface) (This)->lpVtbl->Store(This,ProgID,pInterface)
#define IEventSystem_Remove(This,progID,queryCriteria,errorIndex) (This)->lpVtbl->Remove(This,progID,queryCriteria,errorIndex)
#define IEventSystem_get_EventObjectChangeEventClassID(This,pbstrEventClassID) (This)->lpVtbl->get_EventObjectChangeEventClassID(This,pbstrEventClassID)
#define IEventSystem_QueryS(This,progID,queryCriteria,ppInterface) (This)->lpVtbl->QueryS(This,progID,queryCriteria,ppInterface)
#define IEventSystem_RemoveS(This,progID,queryCriteria) (This)->lpVtbl->RemoveS(This,progID,queryCriteria)
#endif
#endif
  HRESULT WINAPI IEventSystem_Query_Proxy(IEventSystem *This,BSTR progID,BSTR queryCriteria,int *errorIndex,IUnknown **ppInterface);
  void __RPC_STUB IEventSystem_Query_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSystem_Store_Proxy(IEventSystem *This,BSTR ProgID,IUnknown *pInterface);
  void __RPC_STUB IEventSystem_Store_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSystem_Remove_Proxy(IEventSystem *This,BSTR progID,BSTR queryCriteria,int *errorIndex);
  void __RPC_STUB IEventSystem_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSystem_get_EventObjectChangeEventClassID_Proxy(IEventSystem *This,BSTR *pbstrEventClassID);
  void __RPC_STUB IEventSystem_get_EventObjectChangeEventClassID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSystem_QueryS_Proxy(IEventSystem *This,BSTR progID,BSTR queryCriteria,IUnknown **ppInterface);
  void __RPC_STUB IEventSystem_QueryS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSystem_RemoveS_Proxy(IEventSystem *This,BSTR progID,BSTR queryCriteria);
  void __RPC_STUB IEventSystem_RemoveS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventPublisher_INTERFACE_DEFINED__
#define __IEventPublisher_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventPublisher;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventPublisher : public IDispatch {
  public:
    virtual HRESULT WINAPI get_PublisherID(BSTR *pbstrPublisherID) = 0;
    virtual HRESULT WINAPI put_PublisherID(BSTR bstrPublisherID) = 0;
    virtual HRESULT WINAPI get_PublisherName(BSTR *pbstrPublisherName) = 0;
    virtual HRESULT WINAPI put_PublisherName(BSTR bstrPublisherName) = 0;
    virtual HRESULT WINAPI get_PublisherType(BSTR *pbstrPublisherType) = 0;
    virtual HRESULT WINAPI put_PublisherType(BSTR bstrPublisherType) = 0;
    virtual HRESULT WINAPI get_OwnerSID(BSTR *pbstrOwnerSID) = 0;
    virtual HRESULT WINAPI put_OwnerSID(BSTR bstrOwnerSID) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *pbstrDescription) = 0;
    virtual HRESULT WINAPI put_Description(BSTR bstrDescription) = 0;
    virtual HRESULT WINAPI GetDefaultProperty(BSTR bstrPropertyName,VARIANT *propertyValue) = 0;
    virtual HRESULT WINAPI PutDefaultProperty(BSTR bstrPropertyName,VARIANT *propertyValue) = 0;
    virtual HRESULT WINAPI RemoveDefaultProperty(BSTR bstrPropertyName) = 0;
    virtual HRESULT WINAPI GetDefaultPropertyCollection(IEventObjectCollection **collection) = 0;
  };
#else
  typedef struct IEventPublisherVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventPublisher *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventPublisher *This);
      ULONG (WINAPI *Release)(IEventPublisher *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventPublisher *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventPublisher *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventPublisher *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventPublisher *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_PublisherID)(IEventPublisher *This,BSTR *pbstrPublisherID);
      HRESULT (WINAPI *put_PublisherID)(IEventPublisher *This,BSTR bstrPublisherID);
      HRESULT (WINAPI *get_PublisherName)(IEventPublisher *This,BSTR *pbstrPublisherName);
      HRESULT (WINAPI *put_PublisherName)(IEventPublisher *This,BSTR bstrPublisherName);
      HRESULT (WINAPI *get_PublisherType)(IEventPublisher *This,BSTR *pbstrPublisherType);
      HRESULT (WINAPI *put_PublisherType)(IEventPublisher *This,BSTR bstrPublisherType);
      HRESULT (WINAPI *get_OwnerSID)(IEventPublisher *This,BSTR *pbstrOwnerSID);
      HRESULT (WINAPI *put_OwnerSID)(IEventPublisher *This,BSTR bstrOwnerSID);
      HRESULT (WINAPI *get_Description)(IEventPublisher *This,BSTR *pbstrDescription);
      HRESULT (WINAPI *put_Description)(IEventPublisher *This,BSTR bstrDescription);
      HRESULT (WINAPI *GetDefaultProperty)(IEventPublisher *This,BSTR bstrPropertyName,VARIANT *propertyValue);
      HRESULT (WINAPI *PutDefaultProperty)(IEventPublisher *This,BSTR bstrPropertyName,VARIANT *propertyValue);
      HRESULT (WINAPI *RemoveDefaultProperty)(IEventPublisher *This,BSTR bstrPropertyName);
      HRESULT (WINAPI *GetDefaultPropertyCollection)(IEventPublisher *This,IEventObjectCollection **collection);
    END_INTERFACE
  } IEventPublisherVtbl;
  struct IEventPublisher {
    CONST_VTBL struct IEventPublisherVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventPublisher_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventPublisher_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventPublisher_Release(This) (This)->lpVtbl->Release(This)
#define IEventPublisher_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventPublisher_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventPublisher_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventPublisher_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventPublisher_get_PublisherID(This,pbstrPublisherID) (This)->lpVtbl->get_PublisherID(This,pbstrPublisherID)
#define IEventPublisher_put_PublisherID(This,bstrPublisherID) (This)->lpVtbl->put_PublisherID(This,bstrPublisherID)
#define IEventPublisher_get_PublisherName(This,pbstrPublisherName) (This)->lpVtbl->get_PublisherName(This,pbstrPublisherName)
#define IEventPublisher_put_PublisherName(This,bstrPublisherName) (This)->lpVtbl->put_PublisherName(This,bstrPublisherName)
#define IEventPublisher_get_PublisherType(This,pbstrPublisherType) (This)->lpVtbl->get_PublisherType(This,pbstrPublisherType)
#define IEventPublisher_put_PublisherType(This,bstrPublisherType) (This)->lpVtbl->put_PublisherType(This,bstrPublisherType)
#define IEventPublisher_get_OwnerSID(This,pbstrOwnerSID) (This)->lpVtbl->get_OwnerSID(This,pbstrOwnerSID)
#define IEventPublisher_put_OwnerSID(This,bstrOwnerSID) (This)->lpVtbl->put_OwnerSID(This,bstrOwnerSID)
#define IEventPublisher_get_Description(This,pbstrDescription) (This)->lpVtbl->get_Description(This,pbstrDescription)
#define IEventPublisher_put_Description(This,bstrDescription) (This)->lpVtbl->put_Description(This,bstrDescription)
#define IEventPublisher_GetDefaultProperty(This,bstrPropertyName,propertyValue) (This)->lpVtbl->GetDefaultProperty(This,bstrPropertyName,propertyValue)
#define IEventPublisher_PutDefaultProperty(This,bstrPropertyName,propertyValue) (This)->lpVtbl->PutDefaultProperty(This,bstrPropertyName,propertyValue)
#define IEventPublisher_RemoveDefaultProperty(This,bstrPropertyName) (This)->lpVtbl->RemoveDefaultProperty(This,bstrPropertyName)
#define IEventPublisher_GetDefaultPropertyCollection(This,collection) (This)->lpVtbl->GetDefaultPropertyCollection(This,collection)
#endif
#endif
  HRESULT WINAPI IEventPublisher_get_PublisherID_Proxy(IEventPublisher *This,BSTR *pbstrPublisherID);
  void __RPC_STUB IEventPublisher_get_PublisherID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_put_PublisherID_Proxy(IEventPublisher *This,BSTR bstrPublisherID);
  void __RPC_STUB IEventPublisher_put_PublisherID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_get_PublisherName_Proxy(IEventPublisher *This,BSTR *pbstrPublisherName);
  void __RPC_STUB IEventPublisher_get_PublisherName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_put_PublisherName_Proxy(IEventPublisher *This,BSTR bstrPublisherName);
  void __RPC_STUB IEventPublisher_put_PublisherName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_get_PublisherType_Proxy(IEventPublisher *This,BSTR *pbstrPublisherType);
  void __RPC_STUB IEventPublisher_get_PublisherType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_put_PublisherType_Proxy(IEventPublisher *This,BSTR bstrPublisherType);
  void __RPC_STUB IEventPublisher_put_PublisherType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_get_OwnerSID_Proxy(IEventPublisher *This,BSTR *pbstrOwnerSID);
  void __RPC_STUB IEventPublisher_get_OwnerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_put_OwnerSID_Proxy(IEventPublisher *This,BSTR bstrOwnerSID);
  void __RPC_STUB IEventPublisher_put_OwnerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_get_Description_Proxy(IEventPublisher *This,BSTR *pbstrDescription);
  void __RPC_STUB IEventPublisher_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_put_Description_Proxy(IEventPublisher *This,BSTR bstrDescription);
  void __RPC_STUB IEventPublisher_put_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_GetDefaultProperty_Proxy(IEventPublisher *This,BSTR bstrPropertyName,VARIANT *propertyValue);
  void __RPC_STUB IEventPublisher_GetDefaultProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_PutDefaultProperty_Proxy(IEventPublisher *This,BSTR bstrPropertyName,VARIANT *propertyValue);
  void __RPC_STUB IEventPublisher_PutDefaultProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_RemoveDefaultProperty_Proxy(IEventPublisher *This,BSTR bstrPropertyName);
  void __RPC_STUB IEventPublisher_RemoveDefaultProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventPublisher_GetDefaultPropertyCollection_Proxy(IEventPublisher *This,IEventObjectCollection **collection);
  void __RPC_STUB IEventPublisher_GetDefaultPropertyCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventClass_INTERFACE_DEFINED__
#define __IEventClass_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventClass;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventClass : public IDispatch {
  public:
    virtual HRESULT WINAPI get_EventClassID(BSTR *pbstrEventClassID) = 0;
    virtual HRESULT WINAPI put_EventClassID(BSTR bstrEventClassID) = 0;
    virtual HRESULT WINAPI get_EventClassName(BSTR *pbstrEventClassName) = 0;
    virtual HRESULT WINAPI put_EventClassName(BSTR bstrEventClassName) = 0;
    virtual HRESULT WINAPI get_OwnerSID(BSTR *pbstrOwnerSID) = 0;
    virtual HRESULT WINAPI put_OwnerSID(BSTR bstrOwnerSID) = 0;
    virtual HRESULT WINAPI get_FiringInterfaceID(BSTR *pbstrFiringInterfaceID) = 0;
    virtual HRESULT WINAPI put_FiringInterfaceID(BSTR bstrFiringInterfaceID) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *pbstrDescription) = 0;
    virtual HRESULT WINAPI put_Description(BSTR bstrDescription) = 0;
    virtual HRESULT WINAPI get_CustomConfigCLSID(BSTR *pbstrCustomConfigCLSID) = 0;
    virtual HRESULT WINAPI put_CustomConfigCLSID(BSTR bstrCustomConfigCLSID) = 0;
    virtual HRESULT WINAPI get_TypeLib(BSTR *pbstrTypeLib) = 0;
    virtual HRESULT WINAPI put_TypeLib(BSTR bstrTypeLib) = 0;
  };
#else
  typedef struct IEventClassVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventClass *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventClass *This);
      ULONG (WINAPI *Release)(IEventClass *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventClass *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventClass *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventClass *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventClass *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_EventClassID)(IEventClass *This,BSTR *pbstrEventClassID);
      HRESULT (WINAPI *put_EventClassID)(IEventClass *This,BSTR bstrEventClassID);
      HRESULT (WINAPI *get_EventClassName)(IEventClass *This,BSTR *pbstrEventClassName);
      HRESULT (WINAPI *put_EventClassName)(IEventClass *This,BSTR bstrEventClassName);
      HRESULT (WINAPI *get_OwnerSID)(IEventClass *This,BSTR *pbstrOwnerSID);
      HRESULT (WINAPI *put_OwnerSID)(IEventClass *This,BSTR bstrOwnerSID);
      HRESULT (WINAPI *get_FiringInterfaceID)(IEventClass *This,BSTR *pbstrFiringInterfaceID);
      HRESULT (WINAPI *put_FiringInterfaceID)(IEventClass *This,BSTR bstrFiringInterfaceID);
      HRESULT (WINAPI *get_Description)(IEventClass *This,BSTR *pbstrDescription);
      HRESULT (WINAPI *put_Description)(IEventClass *This,BSTR bstrDescription);
      HRESULT (WINAPI *get_CustomConfigCLSID)(IEventClass *This,BSTR *pbstrCustomConfigCLSID);
      HRESULT (WINAPI *put_CustomConfigCLSID)(IEventClass *This,BSTR bstrCustomConfigCLSID);
      HRESULT (WINAPI *get_TypeLib)(IEventClass *This,BSTR *pbstrTypeLib);
      HRESULT (WINAPI *put_TypeLib)(IEventClass *This,BSTR bstrTypeLib);
    END_INTERFACE
  } IEventClassVtbl;
  struct IEventClass {
    CONST_VTBL struct IEventClassVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventClass_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventClass_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventClass_Release(This) (This)->lpVtbl->Release(This)
#define IEventClass_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventClass_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventClass_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventClass_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventClass_get_EventClassID(This,pbstrEventClassID) (This)->lpVtbl->get_EventClassID(This,pbstrEventClassID)
#define IEventClass_put_EventClassID(This,bstrEventClassID) (This)->lpVtbl->put_EventClassID(This,bstrEventClassID)
#define IEventClass_get_EventClassName(This,pbstrEventClassName) (This)->lpVtbl->get_EventClassName(This,pbstrEventClassName)
#define IEventClass_put_EventClassName(This,bstrEventClassName) (This)->lpVtbl->put_EventClassName(This,bstrEventClassName)
#define IEventClass_get_OwnerSID(This,pbstrOwnerSID) (This)->lpVtbl->get_OwnerSID(This,pbstrOwnerSID)
#define IEventClass_put_OwnerSID(This,bstrOwnerSID) (This)->lpVtbl->put_OwnerSID(This,bstrOwnerSID)
#define IEventClass_get_FiringInterfaceID(This,pbstrFiringInterfaceID) (This)->lpVtbl->get_FiringInterfaceID(This,pbstrFiringInterfaceID)
#define IEventClass_put_FiringInterfaceID(This,bstrFiringInterfaceID) (This)->lpVtbl->put_FiringInterfaceID(This,bstrFiringInterfaceID)
#define IEventClass_get_Description(This,pbstrDescription) (This)->lpVtbl->get_Description(This,pbstrDescription)
#define IEventClass_put_Description(This,bstrDescription) (This)->lpVtbl->put_Description(This,bstrDescription)
#define IEventClass_get_CustomConfigCLSID(This,pbstrCustomConfigCLSID) (This)->lpVtbl->get_CustomConfigCLSID(This,pbstrCustomConfigCLSID)
#define IEventClass_put_CustomConfigCLSID(This,bstrCustomConfigCLSID) (This)->lpVtbl->put_CustomConfigCLSID(This,bstrCustomConfigCLSID)
#define IEventClass_get_TypeLib(This,pbstrTypeLib) (This)->lpVtbl->get_TypeLib(This,pbstrTypeLib)
#define IEventClass_put_TypeLib(This,bstrTypeLib) (This)->lpVtbl->put_TypeLib(This,bstrTypeLib)
#endif
#endif
  HRESULT WINAPI IEventClass_get_EventClassID_Proxy(IEventClass *This,BSTR *pbstrEventClassID);
  void __RPC_STUB IEventClass_get_EventClassID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_put_EventClassID_Proxy(IEventClass *This,BSTR bstrEventClassID);
  void __RPC_STUB IEventClass_put_EventClassID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_get_EventClassName_Proxy(IEventClass *This,BSTR *pbstrEventClassName);
  void __RPC_STUB IEventClass_get_EventClassName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_put_EventClassName_Proxy(IEventClass *This,BSTR bstrEventClassName);
  void __RPC_STUB IEventClass_put_EventClassName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_get_OwnerSID_Proxy(IEventClass *This,BSTR *pbstrOwnerSID);
  void __RPC_STUB IEventClass_get_OwnerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_put_OwnerSID_Proxy(IEventClass *This,BSTR bstrOwnerSID);
  void __RPC_STUB IEventClass_put_OwnerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_get_FiringInterfaceID_Proxy(IEventClass *This,BSTR *pbstrFiringInterfaceID);
  void __RPC_STUB IEventClass_get_FiringInterfaceID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_put_FiringInterfaceID_Proxy(IEventClass *This,BSTR bstrFiringInterfaceID);
  void __RPC_STUB IEventClass_put_FiringInterfaceID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_get_Description_Proxy(IEventClass *This,BSTR *pbstrDescription);
  void __RPC_STUB IEventClass_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_put_Description_Proxy(IEventClass *This,BSTR bstrDescription);
  void __RPC_STUB IEventClass_put_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_get_CustomConfigCLSID_Proxy(IEventClass *This,BSTR *pbstrCustomConfigCLSID);
  void __RPC_STUB IEventClass_get_CustomConfigCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_put_CustomConfigCLSID_Proxy(IEventClass *This,BSTR bstrCustomConfigCLSID);
  void __RPC_STUB IEventClass_put_CustomConfigCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_get_TypeLib_Proxy(IEventClass *This,BSTR *pbstrTypeLib);
  void __RPC_STUB IEventClass_get_TypeLib_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass_put_TypeLib_Proxy(IEventClass *This,BSTR bstrTypeLib);
  void __RPC_STUB IEventClass_put_TypeLib_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventClass2_INTERFACE_DEFINED__
#define __IEventClass2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventClass2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventClass2 : public IEventClass {
  public:
    virtual HRESULT WINAPI get_PublisherID(BSTR *pbstrPublisherID) = 0;
    virtual HRESULT WINAPI put_PublisherID(BSTR bstrPublisherID) = 0;
    virtual HRESULT WINAPI get_MultiInterfacePublisherFilterCLSID(BSTR *pbstrPubFilCLSID) = 0;
    virtual HRESULT WINAPI put_MultiInterfacePublisherFilterCLSID(BSTR bstrPubFilCLSID) = 0;
    virtual HRESULT WINAPI get_AllowInprocActivation(WINBOOL *pfAllowInprocActivation) = 0;
    virtual HRESULT WINAPI put_AllowInprocActivation(WINBOOL fAllowInprocActivation) = 0;
    virtual HRESULT WINAPI get_FireInParallel(WINBOOL *pfFireInParallel) = 0;
    virtual HRESULT WINAPI put_FireInParallel(WINBOOL fFireInParallel) = 0;
  };
#else
  typedef struct IEventClass2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventClass2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventClass2 *This);
      ULONG (WINAPI *Release)(IEventClass2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventClass2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventClass2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventClass2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventClass2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_EventClassID)(IEventClass2 *This,BSTR *pbstrEventClassID);
      HRESULT (WINAPI *put_EventClassID)(IEventClass2 *This,BSTR bstrEventClassID);
      HRESULT (WINAPI *get_EventClassName)(IEventClass2 *This,BSTR *pbstrEventClassName);
      HRESULT (WINAPI *put_EventClassName)(IEventClass2 *This,BSTR bstrEventClassName);
      HRESULT (WINAPI *get_OwnerSID)(IEventClass2 *This,BSTR *pbstrOwnerSID);
      HRESULT (WINAPI *put_OwnerSID)(IEventClass2 *This,BSTR bstrOwnerSID);
      HRESULT (WINAPI *get_FiringInterfaceID)(IEventClass2 *This,BSTR *pbstrFiringInterfaceID);
      HRESULT (WINAPI *put_FiringInterfaceID)(IEventClass2 *This,BSTR bstrFiringInterfaceID);
      HRESULT (WINAPI *get_Description)(IEventClass2 *This,BSTR *pbstrDescription);
      HRESULT (WINAPI *put_Description)(IEventClass2 *This,BSTR bstrDescription);
      HRESULT (WINAPI *get_CustomConfigCLSID)(IEventClass2 *This,BSTR *pbstrCustomConfigCLSID);
      HRESULT (WINAPI *put_CustomConfigCLSID)(IEventClass2 *This,BSTR bstrCustomConfigCLSID);
      HRESULT (WINAPI *get_TypeLib)(IEventClass2 *This,BSTR *pbstrTypeLib);
      HRESULT (WINAPI *put_TypeLib)(IEventClass2 *This,BSTR bstrTypeLib);
      HRESULT (WINAPI *get_PublisherID)(IEventClass2 *This,BSTR *pbstrPublisherID);
      HRESULT (WINAPI *put_PublisherID)(IEventClass2 *This,BSTR bstrPublisherID);
      HRESULT (WINAPI *get_MultiInterfacePublisherFilterCLSID)(IEventClass2 *This,BSTR *pbstrPubFilCLSID);
      HRESULT (WINAPI *put_MultiInterfacePublisherFilterCLSID)(IEventClass2 *This,BSTR bstrPubFilCLSID);
      HRESULT (WINAPI *get_AllowInprocActivation)(IEventClass2 *This,WINBOOL *pfAllowInprocActivation);
      HRESULT (WINAPI *put_AllowInprocActivation)(IEventClass2 *This,WINBOOL fAllowInprocActivation);
      HRESULT (WINAPI *get_FireInParallel)(IEventClass2 *This,WINBOOL *pfFireInParallel);
      HRESULT (WINAPI *put_FireInParallel)(IEventClass2 *This,WINBOOL fFireInParallel);
    END_INTERFACE
  } IEventClass2Vtbl;
  struct IEventClass2 {
    CONST_VTBL struct IEventClass2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventClass2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventClass2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventClass2_Release(This) (This)->lpVtbl->Release(This)
#define IEventClass2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventClass2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventClass2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventClass2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventClass2_get_EventClassID(This,pbstrEventClassID) (This)->lpVtbl->get_EventClassID(This,pbstrEventClassID)
#define IEventClass2_put_EventClassID(This,bstrEventClassID) (This)->lpVtbl->put_EventClassID(This,bstrEventClassID)
#define IEventClass2_get_EventClassName(This,pbstrEventClassName) (This)->lpVtbl->get_EventClassName(This,pbstrEventClassName)
#define IEventClass2_put_EventClassName(This,bstrEventClassName) (This)->lpVtbl->put_EventClassName(This,bstrEventClassName)
#define IEventClass2_get_OwnerSID(This,pbstrOwnerSID) (This)->lpVtbl->get_OwnerSID(This,pbstrOwnerSID)
#define IEventClass2_put_OwnerSID(This,bstrOwnerSID) (This)->lpVtbl->put_OwnerSID(This,bstrOwnerSID)
#define IEventClass2_get_FiringInterfaceID(This,pbstrFiringInterfaceID) (This)->lpVtbl->get_FiringInterfaceID(This,pbstrFiringInterfaceID)
#define IEventClass2_put_FiringInterfaceID(This,bstrFiringInterfaceID) (This)->lpVtbl->put_FiringInterfaceID(This,bstrFiringInterfaceID)
#define IEventClass2_get_Description(This,pbstrDescription) (This)->lpVtbl->get_Description(This,pbstrDescription)
#define IEventClass2_put_Description(This,bstrDescription) (This)->lpVtbl->put_Description(This,bstrDescription)
#define IEventClass2_get_CustomConfigCLSID(This,pbstrCustomConfigCLSID) (This)->lpVtbl->get_CustomConfigCLSID(This,pbstrCustomConfigCLSID)
#define IEventClass2_put_CustomConfigCLSID(This,bstrCustomConfigCLSID) (This)->lpVtbl->put_CustomConfigCLSID(This,bstrCustomConfigCLSID)
#define IEventClass2_get_TypeLib(This,pbstrTypeLib) (This)->lpVtbl->get_TypeLib(This,pbstrTypeLib)
#define IEventClass2_put_TypeLib(This,bstrTypeLib) (This)->lpVtbl->put_TypeLib(This,bstrTypeLib)
#define IEventClass2_get_PublisherID(This,pbstrPublisherID) (This)->lpVtbl->get_PublisherID(This,pbstrPublisherID)
#define IEventClass2_put_PublisherID(This,bstrPublisherID) (This)->lpVtbl->put_PublisherID(This,bstrPublisherID)
#define IEventClass2_get_MultiInterfacePublisherFilterCLSID(This,pbstrPubFilCLSID) (This)->lpVtbl->get_MultiInterfacePublisherFilterCLSID(This,pbstrPubFilCLSID)
#define IEventClass2_put_MultiInterfacePublisherFilterCLSID(This,bstrPubFilCLSID) (This)->lpVtbl->put_MultiInterfacePublisherFilterCLSID(This,bstrPubFilCLSID)
#define IEventClass2_get_AllowInprocActivation(This,pfAllowInprocActivation) (This)->lpVtbl->get_AllowInprocActivation(This,pfAllowInprocActivation)
#define IEventClass2_put_AllowInprocActivation(This,fAllowInprocActivation) (This)->lpVtbl->put_AllowInprocActivation(This,fAllowInprocActivation)
#define IEventClass2_get_FireInParallel(This,pfFireInParallel) (This)->lpVtbl->get_FireInParallel(This,pfFireInParallel)
#define IEventClass2_put_FireInParallel(This,fFireInParallel) (This)->lpVtbl->put_FireInParallel(This,fFireInParallel)
#endif
#endif
  HRESULT WINAPI IEventClass2_get_PublisherID_Proxy(IEventClass2 *This,BSTR *pbstrPublisherID);
  void __RPC_STUB IEventClass2_get_PublisherID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass2_put_PublisherID_Proxy(IEventClass2 *This,BSTR bstrPublisherID);
  void __RPC_STUB IEventClass2_put_PublisherID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass2_get_MultiInterfacePublisherFilterCLSID_Proxy(IEventClass2 *This,BSTR *pbstrPubFilCLSID);
  void __RPC_STUB IEventClass2_get_MultiInterfacePublisherFilterCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass2_put_MultiInterfacePublisherFilterCLSID_Proxy(IEventClass2 *This,BSTR bstrPubFilCLSID);
  void __RPC_STUB IEventClass2_put_MultiInterfacePublisherFilterCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass2_get_AllowInprocActivation_Proxy(IEventClass2 *This,WINBOOL *pfAllowInprocActivation);
  void __RPC_STUB IEventClass2_get_AllowInprocActivation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass2_put_AllowInprocActivation_Proxy(IEventClass2 *This,WINBOOL fAllowInprocActivation);
  void __RPC_STUB IEventClass2_put_AllowInprocActivation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass2_get_FireInParallel_Proxy(IEventClass2 *This,WINBOOL *pfFireInParallel);
  void __RPC_STUB IEventClass2_get_FireInParallel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventClass2_put_FireInParallel_Proxy(IEventClass2 *This,WINBOOL fFireInParallel);
  void __RPC_STUB IEventClass2_put_FireInParallel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventSubscription_INTERFACE_DEFINED__
#define __IEventSubscription_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventSubscription;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventSubscription : public IDispatch {
  public:
    virtual HRESULT WINAPI get_SubscriptionID(BSTR *pbstrSubscriptionID) = 0;
    virtual HRESULT WINAPI put_SubscriptionID(BSTR bstrSubscriptionID) = 0;
    virtual HRESULT WINAPI get_SubscriptionName(BSTR *pbstrSubscriptionName) = 0;
    virtual HRESULT WINAPI put_SubscriptionName(BSTR bstrSubscriptionName) = 0;
    virtual HRESULT WINAPI get_PublisherID(BSTR *pbstrPublisherID) = 0;
    virtual HRESULT WINAPI put_PublisherID(BSTR bstrPublisherID) = 0;
    virtual HRESULT WINAPI get_EventClassID(BSTR *pbstrEventClassID) = 0;
    virtual HRESULT WINAPI put_EventClassID(BSTR bstrEventClassID) = 0;
    virtual HRESULT WINAPI get_MethodName(BSTR *pbstrMethodName) = 0;
    virtual HRESULT WINAPI put_MethodName(BSTR bstrMethodName) = 0;
    virtual HRESULT WINAPI get_SubscriberCLSID(BSTR *pbstrSubscriberCLSID) = 0;
    virtual HRESULT WINAPI put_SubscriberCLSID(BSTR bstrSubscriberCLSID) = 0;
    virtual HRESULT WINAPI get_SubscriberInterface(IUnknown **ppSubscriberInterface) = 0;
    virtual HRESULT WINAPI put_SubscriberInterface(IUnknown *pSubscriberInterface) = 0;
    virtual HRESULT WINAPI get_PerUser(WINBOOL *pfPerUser) = 0;
    virtual HRESULT WINAPI put_PerUser(WINBOOL fPerUser) = 0;
    virtual HRESULT WINAPI get_OwnerSID(BSTR *pbstrOwnerSID) = 0;
    virtual HRESULT WINAPI put_OwnerSID(BSTR bstrOwnerSID) = 0;
    virtual HRESULT WINAPI get_Enabled(WINBOOL *pfEnabled) = 0;
    virtual HRESULT WINAPI put_Enabled(WINBOOL fEnabled) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *pbstrDescription) = 0;
    virtual HRESULT WINAPI put_Description(BSTR bstrDescription) = 0;
    virtual HRESULT WINAPI get_MachineName(BSTR *pbstrMachineName) = 0;
    virtual HRESULT WINAPI put_MachineName(BSTR bstrMachineName) = 0;
    virtual HRESULT WINAPI GetPublisherProperty(BSTR bstrPropertyName,VARIANT *propertyValue) = 0;
    virtual HRESULT WINAPI PutPublisherProperty(BSTR bstrPropertyName,VARIANT *propertyValue) = 0;
    virtual HRESULT WINAPI RemovePublisherProperty(BSTR bstrPropertyName) = 0;
    virtual HRESULT WINAPI GetPublisherPropertyCollection(IEventObjectCollection **collection) = 0;
    virtual HRESULT WINAPI GetSubscriberProperty(BSTR bstrPropertyName,VARIANT *propertyValue) = 0;
    virtual HRESULT WINAPI PutSubscriberProperty(BSTR bstrPropertyName,VARIANT *propertyValue) = 0;
    virtual HRESULT WINAPI RemoveSubscriberProperty(BSTR bstrPropertyName) = 0;
    virtual HRESULT WINAPI GetSubscriberPropertyCollection(IEventObjectCollection **collection) = 0;
    virtual HRESULT WINAPI get_InterfaceID(BSTR *pbstrInterfaceID) = 0;
    virtual HRESULT WINAPI put_InterfaceID(BSTR bstrInterfaceID) = 0;
  };
#else
  typedef struct IEventSubscriptionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventSubscription *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventSubscription *This);
      ULONG (WINAPI *Release)(IEventSubscription *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventSubscription *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventSubscription *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventSubscription *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventSubscription *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SubscriptionID)(IEventSubscription *This,BSTR *pbstrSubscriptionID);
      HRESULT (WINAPI *put_SubscriptionID)(IEventSubscription *This,BSTR bstrSubscriptionID);
      HRESULT (WINAPI *get_SubscriptionName)(IEventSubscription *This,BSTR *pbstrSubscriptionName);
      HRESULT (WINAPI *put_SubscriptionName)(IEventSubscription *This,BSTR bstrSubscriptionName);
      HRESULT (WINAPI *get_PublisherID)(IEventSubscription *This,BSTR *pbstrPublisherID);
      HRESULT (WINAPI *put_PublisherID)(IEventSubscription *This,BSTR bstrPublisherID);
      HRESULT (WINAPI *get_EventClassID)(IEventSubscription *This,BSTR *pbstrEventClassID);
      HRESULT (WINAPI *put_EventClassID)(IEventSubscription *This,BSTR bstrEventClassID);
      HRESULT (WINAPI *get_MethodName)(IEventSubscription *This,BSTR *pbstrMethodName);
      HRESULT (WINAPI *put_MethodName)(IEventSubscription *This,BSTR bstrMethodName);
      HRESULT (WINAPI *get_SubscriberCLSID)(IEventSubscription *This,BSTR *pbstrSubscriberCLSID);
      HRESULT (WINAPI *put_SubscriberCLSID)(IEventSubscription *This,BSTR bstrSubscriberCLSID);
      HRESULT (WINAPI *get_SubscriberInterface)(IEventSubscription *This,IUnknown **ppSubscriberInterface);
      HRESULT (WINAPI *put_SubscriberInterface)(IEventSubscription *This,IUnknown *pSubscriberInterface);
      HRESULT (WINAPI *get_PerUser)(IEventSubscription *This,WINBOOL *pfPerUser);
      HRESULT (WINAPI *put_PerUser)(IEventSubscription *This,WINBOOL fPerUser);
      HRESULT (WINAPI *get_OwnerSID)(IEventSubscription *This,BSTR *pbstrOwnerSID);
      HRESULT (WINAPI *put_OwnerSID)(IEventSubscription *This,BSTR bstrOwnerSID);
      HRESULT (WINAPI *get_Enabled)(IEventSubscription *This,WINBOOL *pfEnabled);
      HRESULT (WINAPI *put_Enabled)(IEventSubscription *This,WINBOOL fEnabled);
      HRESULT (WINAPI *get_Description)(IEventSubscription *This,BSTR *pbstrDescription);
      HRESULT (WINAPI *put_Description)(IEventSubscription *This,BSTR bstrDescription);
      HRESULT (WINAPI *get_MachineName)(IEventSubscription *This,BSTR *pbstrMachineName);
      HRESULT (WINAPI *put_MachineName)(IEventSubscription *This,BSTR bstrMachineName);
      HRESULT (WINAPI *GetPublisherProperty)(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
      HRESULT (WINAPI *PutPublisherProperty)(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
      HRESULT (WINAPI *RemovePublisherProperty)(IEventSubscription *This,BSTR bstrPropertyName);
      HRESULT (WINAPI *GetPublisherPropertyCollection)(IEventSubscription *This,IEventObjectCollection **collection);
      HRESULT (WINAPI *GetSubscriberProperty)(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
      HRESULT (WINAPI *PutSubscriberProperty)(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
      HRESULT (WINAPI *RemoveSubscriberProperty)(IEventSubscription *This,BSTR bstrPropertyName);
      HRESULT (WINAPI *GetSubscriberPropertyCollection)(IEventSubscription *This,IEventObjectCollection **collection);
      HRESULT (WINAPI *get_InterfaceID)(IEventSubscription *This,BSTR *pbstrInterfaceID);
      HRESULT (WINAPI *put_InterfaceID)(IEventSubscription *This,BSTR bstrInterfaceID);
    END_INTERFACE
  } IEventSubscriptionVtbl;
  struct IEventSubscription {
    CONST_VTBL struct IEventSubscriptionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventSubscription_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventSubscription_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventSubscription_Release(This) (This)->lpVtbl->Release(This)
#define IEventSubscription_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventSubscription_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventSubscription_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventSubscription_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventSubscription_get_SubscriptionID(This,pbstrSubscriptionID) (This)->lpVtbl->get_SubscriptionID(This,pbstrSubscriptionID)
#define IEventSubscription_put_SubscriptionID(This,bstrSubscriptionID) (This)->lpVtbl->put_SubscriptionID(This,bstrSubscriptionID)
#define IEventSubscription_get_SubscriptionName(This,pbstrSubscriptionName) (This)->lpVtbl->get_SubscriptionName(This,pbstrSubscriptionName)
#define IEventSubscription_put_SubscriptionName(This,bstrSubscriptionName) (This)->lpVtbl->put_SubscriptionName(This,bstrSubscriptionName)
#define IEventSubscription_get_PublisherID(This,pbstrPublisherID) (This)->lpVtbl->get_PublisherID(This,pbstrPublisherID)
#define IEventSubscription_put_PublisherID(This,bstrPublisherID) (This)->lpVtbl->put_PublisherID(This,bstrPublisherID)
#define IEventSubscription_get_EventClassID(This,pbstrEventClassID) (This)->lpVtbl->get_EventClassID(This,pbstrEventClassID)
#define IEventSubscription_put_EventClassID(This,bstrEventClassID) (This)->lpVtbl->put_EventClassID(This,bstrEventClassID)
#define IEventSubscription_get_MethodName(This,pbstrMethodName) (This)->lpVtbl->get_MethodName(This,pbstrMethodName)
#define IEventSubscription_put_MethodName(This,bstrMethodName) (This)->lpVtbl->put_MethodName(This,bstrMethodName)
#define IEventSubscription_get_SubscriberCLSID(This,pbstrSubscriberCLSID) (This)->lpVtbl->get_SubscriberCLSID(This,pbstrSubscriberCLSID)
#define IEventSubscription_put_SubscriberCLSID(This,bstrSubscriberCLSID) (This)->lpVtbl->put_SubscriberCLSID(This,bstrSubscriberCLSID)
#define IEventSubscription_get_SubscriberInterface(This,ppSubscriberInterface) (This)->lpVtbl->get_SubscriberInterface(This,ppSubscriberInterface)
#define IEventSubscription_put_SubscriberInterface(This,pSubscriberInterface) (This)->lpVtbl->put_SubscriberInterface(This,pSubscriberInterface)
#define IEventSubscription_get_PerUser(This,pfPerUser) (This)->lpVtbl->get_PerUser(This,pfPerUser)
#define IEventSubscription_put_PerUser(This,fPerUser) (This)->lpVtbl->put_PerUser(This,fPerUser)
#define IEventSubscription_get_OwnerSID(This,pbstrOwnerSID) (This)->lpVtbl->get_OwnerSID(This,pbstrOwnerSID)
#define IEventSubscription_put_OwnerSID(This,bstrOwnerSID) (This)->lpVtbl->put_OwnerSID(This,bstrOwnerSID)
#define IEventSubscription_get_Enabled(This,pfEnabled) (This)->lpVtbl->get_Enabled(This,pfEnabled)
#define IEventSubscription_put_Enabled(This,fEnabled) (This)->lpVtbl->put_Enabled(This,fEnabled)
#define IEventSubscription_get_Description(This,pbstrDescription) (This)->lpVtbl->get_Description(This,pbstrDescription)
#define IEventSubscription_put_Description(This,bstrDescription) (This)->lpVtbl->put_Description(This,bstrDescription)
#define IEventSubscription_get_MachineName(This,pbstrMachineName) (This)->lpVtbl->get_MachineName(This,pbstrMachineName)
#define IEventSubscription_put_MachineName(This,bstrMachineName) (This)->lpVtbl->put_MachineName(This,bstrMachineName)
#define IEventSubscription_GetPublisherProperty(This,bstrPropertyName,propertyValue) (This)->lpVtbl->GetPublisherProperty(This,bstrPropertyName,propertyValue)
#define IEventSubscription_PutPublisherProperty(This,bstrPropertyName,propertyValue) (This)->lpVtbl->PutPublisherProperty(This,bstrPropertyName,propertyValue)
#define IEventSubscription_RemovePublisherProperty(This,bstrPropertyName) (This)->lpVtbl->RemovePublisherProperty(This,bstrPropertyName)
#define IEventSubscription_GetPublisherPropertyCollection(This,collection) (This)->lpVtbl->GetPublisherPropertyCollection(This,collection)
#define IEventSubscription_GetSubscriberProperty(This,bstrPropertyName,propertyValue) (This)->lpVtbl->GetSubscriberProperty(This,bstrPropertyName,propertyValue)
#define IEventSubscription_PutSubscriberProperty(This,bstrPropertyName,propertyValue) (This)->lpVtbl->PutSubscriberProperty(This,bstrPropertyName,propertyValue)
#define IEventSubscription_RemoveSubscriberProperty(This,bstrPropertyName) (This)->lpVtbl->RemoveSubscriberProperty(This,bstrPropertyName)
#define IEventSubscription_GetSubscriberPropertyCollection(This,collection) (This)->lpVtbl->GetSubscriberPropertyCollection(This,collection)
#define IEventSubscription_get_InterfaceID(This,pbstrInterfaceID) (This)->lpVtbl->get_InterfaceID(This,pbstrInterfaceID)
#define IEventSubscription_put_InterfaceID(This,bstrInterfaceID) (This)->lpVtbl->put_InterfaceID(This,bstrInterfaceID)
#endif
#endif
  HRESULT WINAPI IEventSubscription_get_SubscriptionID_Proxy(IEventSubscription *This,BSTR *pbstrSubscriptionID);
  void __RPC_STUB IEventSubscription_get_SubscriptionID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_SubscriptionID_Proxy(IEventSubscription *This,BSTR bstrSubscriptionID);
  void __RPC_STUB IEventSubscription_put_SubscriptionID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_SubscriptionName_Proxy(IEventSubscription *This,BSTR *pbstrSubscriptionName);
  void __RPC_STUB IEventSubscription_get_SubscriptionName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_SubscriptionName_Proxy(IEventSubscription *This,BSTR bstrSubscriptionName);
  void __RPC_STUB IEventSubscription_put_SubscriptionName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_PublisherID_Proxy(IEventSubscription *This,BSTR *pbstrPublisherID);
  void __RPC_STUB IEventSubscription_get_PublisherID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_PublisherID_Proxy(IEventSubscription *This,BSTR bstrPublisherID);
  void __RPC_STUB IEventSubscription_put_PublisherID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_EventClassID_Proxy(IEventSubscription *This,BSTR *pbstrEventClassID);
  void __RPC_STUB IEventSubscription_get_EventClassID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_EventClassID_Proxy(IEventSubscription *This,BSTR bstrEventClassID);
  void __RPC_STUB IEventSubscription_put_EventClassID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_MethodName_Proxy(IEventSubscription *This,BSTR *pbstrMethodName);
  void __RPC_STUB IEventSubscription_get_MethodName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_MethodName_Proxy(IEventSubscription *This,BSTR bstrMethodName);
  void __RPC_STUB IEventSubscription_put_MethodName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_SubscriberCLSID_Proxy(IEventSubscription *This,BSTR *pbstrSubscriberCLSID);
  void __RPC_STUB IEventSubscription_get_SubscriberCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_SubscriberCLSID_Proxy(IEventSubscription *This,BSTR bstrSubscriberCLSID);
  void __RPC_STUB IEventSubscription_put_SubscriberCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_SubscriberInterface_Proxy(IEventSubscription *This,IUnknown **ppSubscriberInterface);
  void __RPC_STUB IEventSubscription_get_SubscriberInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_SubscriberInterface_Proxy(IEventSubscription *This,IUnknown *pSubscriberInterface);
  void __RPC_STUB IEventSubscription_put_SubscriberInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_PerUser_Proxy(IEventSubscription *This,WINBOOL *pfPerUser);
  void __RPC_STUB IEventSubscription_get_PerUser_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_PerUser_Proxy(IEventSubscription *This,WINBOOL fPerUser);
  void __RPC_STUB IEventSubscription_put_PerUser_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_OwnerSID_Proxy(IEventSubscription *This,BSTR *pbstrOwnerSID);
  void __RPC_STUB IEventSubscription_get_OwnerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_OwnerSID_Proxy(IEventSubscription *This,BSTR bstrOwnerSID);
  void __RPC_STUB IEventSubscription_put_OwnerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_Enabled_Proxy(IEventSubscription *This,WINBOOL *pfEnabled);
  void __RPC_STUB IEventSubscription_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_Enabled_Proxy(IEventSubscription *This,WINBOOL fEnabled);
  void __RPC_STUB IEventSubscription_put_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_Description_Proxy(IEventSubscription *This,BSTR *pbstrDescription);
  void __RPC_STUB IEventSubscription_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_Description_Proxy(IEventSubscription *This,BSTR bstrDescription);
  void __RPC_STUB IEventSubscription_put_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_MachineName_Proxy(IEventSubscription *This,BSTR *pbstrMachineName);
  void __RPC_STUB IEventSubscription_get_MachineName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_MachineName_Proxy(IEventSubscription *This,BSTR bstrMachineName);
  void __RPC_STUB IEventSubscription_put_MachineName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_GetPublisherProperty_Proxy(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
  void __RPC_STUB IEventSubscription_GetPublisherProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_PutPublisherProperty_Proxy(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
  void __RPC_STUB IEventSubscription_PutPublisherProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_RemovePublisherProperty_Proxy(IEventSubscription *This,BSTR bstrPropertyName);
  void __RPC_STUB IEventSubscription_RemovePublisherProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_GetPublisherPropertyCollection_Proxy(IEventSubscription *This,IEventObjectCollection **collection);
  void __RPC_STUB IEventSubscription_GetPublisherPropertyCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_GetSubscriberProperty_Proxy(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
  void __RPC_STUB IEventSubscription_GetSubscriberProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_PutSubscriberProperty_Proxy(IEventSubscription *This,BSTR bstrPropertyName,VARIANT *propertyValue);
  void __RPC_STUB IEventSubscription_PutSubscriberProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_RemoveSubscriberProperty_Proxy(IEventSubscription *This,BSTR bstrPropertyName);
  void __RPC_STUB IEventSubscription_RemoveSubscriberProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_GetSubscriberPropertyCollection_Proxy(IEventSubscription *This,IEventObjectCollection **collection);
  void __RPC_STUB IEventSubscription_GetSubscriberPropertyCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_get_InterfaceID_Proxy(IEventSubscription *This,BSTR *pbstrInterfaceID);
  void __RPC_STUB IEventSubscription_get_InterfaceID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventSubscription_put_InterfaceID_Proxy(IEventSubscription *This,BSTR bstrInterfaceID);
  void __RPC_STUB IEventSubscription_put_InterfaceID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IFiringControl_INTERFACE_DEFINED__
#define __IFiringControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IFiringControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IFiringControl : public IDispatch {
  public:
    virtual HRESULT WINAPI FireSubscription(IEventSubscription *subscription) = 0;
  };
#else
  typedef struct IFiringControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IFiringControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IFiringControl *This);
      ULONG (WINAPI *Release)(IFiringControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IFiringControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IFiringControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IFiringControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IFiringControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *FireSubscription)(IFiringControl *This,IEventSubscription *subscription);
    END_INTERFACE
  } IFiringControlVtbl;
  struct IFiringControl {
    CONST_VTBL struct IFiringControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IFiringControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFiringControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFiringControl_Release(This) (This)->lpVtbl->Release(This)
#define IFiringControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IFiringControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IFiringControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IFiringControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IFiringControl_FireSubscription(This,subscription) (This)->lpVtbl->FireSubscription(This,subscription)
#endif
#endif
  HRESULT WINAPI IFiringControl_FireSubscription_Proxy(IFiringControl *This,IEventSubscription *subscription);
  void __RPC_STUB IFiringControl_FireSubscription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPublisherFilter_INTERFACE_DEFINED__
#define __IPublisherFilter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPublisherFilter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPublisherFilter : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(BSTR methodName,IDispatch *dispUserDefined) = 0;
    virtual HRESULT WINAPI PrepareToFire(BSTR methodName,IFiringControl *firingControl) = 0;
  };
#else
  typedef struct IPublisherFilterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPublisherFilter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPublisherFilter *This);
      ULONG (WINAPI *Release)(IPublisherFilter *This);
      HRESULT (WINAPI *Initialize)(IPublisherFilter *This,BSTR methodName,IDispatch *dispUserDefined);
      HRESULT (WINAPI *PrepareToFire)(IPublisherFilter *This,BSTR methodName,IFiringControl *firingControl);
    END_INTERFACE
  } IPublisherFilterVtbl;
  struct IPublisherFilter {
    CONST_VTBL struct IPublisherFilterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPublisherFilter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPublisherFilter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPublisherFilter_Release(This) (This)->lpVtbl->Release(This)
#define IPublisherFilter_Initialize(This,methodName,dispUserDefined) (This)->lpVtbl->Initialize(This,methodName,dispUserDefined)
#define IPublisherFilter_PrepareToFire(This,methodName,firingControl) (This)->lpVtbl->PrepareToFire(This,methodName,firingControl)
#endif
#endif
  HRESULT WINAPI IPublisherFilter_Initialize_Proxy(IPublisherFilter *This,BSTR methodName,IDispatch *dispUserDefined);
  void __RPC_STUB IPublisherFilter_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublisherFilter_PrepareToFire_Proxy(IPublisherFilter *This,BSTR methodName,IFiringControl *firingControl);
  void __RPC_STUB IPublisherFilter_PrepareToFire_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMultiInterfacePublisherFilter_INTERFACE_DEFINED__
#define __IMultiInterfacePublisherFilter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMultiInterfacePublisherFilter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMultiInterfacePublisherFilter : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(IMultiInterfaceEventControl *pEIC) = 0;
    virtual HRESULT WINAPI PrepareToFire(REFIID iid,BSTR methodName,IFiringControl *firingControl) = 0;
  };
#else
  typedef struct IMultiInterfacePublisherFilterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMultiInterfacePublisherFilter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMultiInterfacePublisherFilter *This);
      ULONG (WINAPI *Release)(IMultiInterfacePublisherFilter *This);
      HRESULT (WINAPI *Initialize)(IMultiInterfacePublisherFilter *This,IMultiInterfaceEventControl *pEIC);
      HRESULT (WINAPI *PrepareToFire)(IMultiInterfacePublisherFilter *This,REFIID iid,BSTR methodName,IFiringControl *firingControl);
    END_INTERFACE
  } IMultiInterfacePublisherFilterVtbl;
  struct IMultiInterfacePublisherFilter {
    CONST_VTBL struct IMultiInterfacePublisherFilterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMultiInterfacePublisherFilter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMultiInterfacePublisherFilter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMultiInterfacePublisherFilter_Release(This) (This)->lpVtbl->Release(This)
#define IMultiInterfacePublisherFilter_Initialize(This,pEIC) (This)->lpVtbl->Initialize(This,pEIC)
#define IMultiInterfacePublisherFilter_PrepareToFire(This,iid,methodName,firingControl) (This)->lpVtbl->PrepareToFire(This,iid,methodName,firingControl)
#endif
#endif
    HRESULT WINAPI IMultiInterfacePublisherFilter_Initialize_Proxy(IMultiInterfacePublisherFilter *This,IMultiInterfaceEventControl *pEIC);
  void __RPC_STUB IMultiInterfacePublisherFilter_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiInterfacePublisherFilter_PrepareToFire_Proxy(IMultiInterfacePublisherFilter *This,REFIID iid,BSTR methodName,IFiringControl *firingControl);
  void __RPC_STUB IMultiInterfacePublisherFilter_PrepareToFire_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventObjectChange_INTERFACE_DEFINED__
#define __IEventObjectChange_INTERFACE_DEFINED__
  typedef enum __MIDL_IEventObjectChange_0001 {
    EOC_NewObject = 0,EOC_ModifiedObject,EOC_DeletedObject
  } EOC_ChangeType;
  EXTERN_C const IID IID_IEventObjectChange;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventObjectChange : public IUnknown {
  public:
    virtual HRESULT WINAPI ChangedSubscription(EOC_ChangeType changeType,BSTR bstrSubscriptionID) = 0;
    virtual HRESULT WINAPI ChangedEventClass(EOC_ChangeType changeType,BSTR bstrEventClassID) = 0;
    virtual HRESULT WINAPI ChangedPublisher(EOC_ChangeType changeType,BSTR bstrPublisherID) = 0;
  };
#else
  typedef struct IEventObjectChangeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventObjectChange *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventObjectChange *This);
      ULONG (WINAPI *Release)(IEventObjectChange *This);
      HRESULT (WINAPI *ChangedSubscription)(IEventObjectChange *This,EOC_ChangeType changeType,BSTR bstrSubscriptionID);
      HRESULT (WINAPI *ChangedEventClass)(IEventObjectChange *This,EOC_ChangeType changeType,BSTR bstrEventClassID);
      HRESULT (WINAPI *ChangedPublisher)(IEventObjectChange *This,EOC_ChangeType changeType,BSTR bstrPublisherID);
    END_INTERFACE
  } IEventObjectChangeVtbl;
  struct IEventObjectChange {
    CONST_VTBL struct IEventObjectChangeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventObjectChange_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventObjectChange_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventObjectChange_Release(This) (This)->lpVtbl->Release(This)
#define IEventObjectChange_ChangedSubscription(This,changeType,bstrSubscriptionID) (This)->lpVtbl->ChangedSubscription(This,changeType,bstrSubscriptionID)
#define IEventObjectChange_ChangedEventClass(This,changeType,bstrEventClassID) (This)->lpVtbl->ChangedEventClass(This,changeType,bstrEventClassID)
#define IEventObjectChange_ChangedPublisher(This,changeType,bstrPublisherID) (This)->lpVtbl->ChangedPublisher(This,changeType,bstrPublisherID)
#endif
#endif
  HRESULT WINAPI IEventObjectChange_ChangedSubscription_Proxy(IEventObjectChange *This,EOC_ChangeType changeType,BSTR bstrSubscriptionID);
  void __RPC_STUB IEventObjectChange_ChangedSubscription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectChange_ChangedEventClass_Proxy(IEventObjectChange *This,EOC_ChangeType changeType,BSTR bstrEventClassID);
  void __RPC_STUB IEventObjectChange_ChangedEventClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectChange_ChangedPublisher_Proxy(IEventObjectChange *This,EOC_ChangeType changeType,BSTR bstrPublisherID);
  void __RPC_STUB IEventObjectChange_ChangedPublisher_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef _COMEVENTSYSCHANGEINFO_
#define _COMEVENTSYSCHANGEINFO_
  typedef struct __MIDL___MIDL_itf_eventsys_0270_0001 {
    DWORD cbSize;
    EOC_ChangeType changeType;
    BSTR objectId;
    BSTR partitionId;
    BSTR applicationId;
    GUID reserved[10 ];
  } COMEVENTSYSCHANGEINFO;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_eventsys_0270_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_eventsys_0270_v0_0_s_ifspec;
#ifndef __IEventObjectChange2_INTERFACE_DEFINED__
#define __IEventObjectChange2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventObjectChange2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventObjectChange2 : public IUnknown {
  public:
    virtual HRESULT WINAPI ChangedSubscription(COMEVENTSYSCHANGEINFO *pInfo) = 0;
    virtual HRESULT WINAPI ChangedEventClass(COMEVENTSYSCHANGEINFO *pInfo) = 0;
  };
#else
  typedef struct IEventObjectChange2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventObjectChange2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventObjectChange2 *This);
      ULONG (WINAPI *Release)(IEventObjectChange2 *This);
      HRESULT (WINAPI *ChangedSubscription)(IEventObjectChange2 *This,COMEVENTSYSCHANGEINFO *pInfo);
      HRESULT (WINAPI *ChangedEventClass)(IEventObjectChange2 *This,COMEVENTSYSCHANGEINFO *pInfo);
    END_INTERFACE
  } IEventObjectChange2Vtbl;
  struct IEventObjectChange2 {
    CONST_VTBL struct IEventObjectChange2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventObjectChange2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventObjectChange2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventObjectChange2_Release(This) (This)->lpVtbl->Release(This)
#define IEventObjectChange2_ChangedSubscription(This,pInfo) (This)->lpVtbl->ChangedSubscription(This,pInfo)
#define IEventObjectChange2_ChangedEventClass(This,pInfo) (This)->lpVtbl->ChangedEventClass(This,pInfo)
#endif
#endif
  HRESULT WINAPI IEventObjectChange2_ChangedSubscription_Proxy(IEventObjectChange2 *This,COMEVENTSYSCHANGEINFO *pInfo);
  void __RPC_STUB IEventObjectChange2_ChangedSubscription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectChange2_ChangedEventClass_Proxy(IEventObjectChange2 *This,COMEVENTSYSCHANGEINFO *pInfo);
  void __RPC_STUB IEventObjectChange2_ChangedEventClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumEventObject_INTERFACE_DEFINED__
#define __IEnumEventObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumEventObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumEventObject : public IUnknown {
  public:
    virtual HRESULT WINAPI Clone(IEnumEventObject **ppInterface) = 0;
    virtual HRESULT WINAPI Next(ULONG cReqElem,IUnknown **ppInterface,ULONG *cRetElem) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG cSkipElem) = 0;
  };
#else
  typedef struct IEnumEventObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumEventObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumEventObject *This);
      ULONG (WINAPI *Release)(IEnumEventObject *This);
      HRESULT (WINAPI *Clone)(IEnumEventObject *This,IEnumEventObject **ppInterface);
      HRESULT (WINAPI *Next)(IEnumEventObject *This,ULONG cReqElem,IUnknown **ppInterface,ULONG *cRetElem);
      HRESULT (WINAPI *Reset)(IEnumEventObject *This);
      HRESULT (WINAPI *Skip)(IEnumEventObject *This,ULONG cSkipElem);
    END_INTERFACE
  } IEnumEventObjectVtbl;
  struct IEnumEventObject {
    CONST_VTBL struct IEnumEventObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumEventObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumEventObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumEventObject_Release(This) (This)->lpVtbl->Release(This)
#define IEnumEventObject_Clone(This,ppInterface) (This)->lpVtbl->Clone(This,ppInterface)
#define IEnumEventObject_Next(This,cReqElem,ppInterface,cRetElem) (This)->lpVtbl->Next(This,cReqElem,ppInterface,cRetElem)
#define IEnumEventObject_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumEventObject_Skip(This,cSkipElem) (This)->lpVtbl->Skip(This,cSkipElem)
#endif
#endif
  HRESULT WINAPI IEnumEventObject_Clone_Proxy(IEnumEventObject *This,IEnumEventObject **ppInterface);
  void __RPC_STUB IEnumEventObject_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumEventObject_Next_Proxy(IEnumEventObject *This,ULONG cReqElem,IUnknown **ppInterface,ULONG *cRetElem);
  void __RPC_STUB IEnumEventObject_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumEventObject_Reset_Proxy(IEnumEventObject *This);
  void __RPC_STUB IEnumEventObject_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumEventObject_Skip_Proxy(IEnumEventObject *This,ULONG cSkipElem);
  void __RPC_STUB IEnumEventObject_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventObjectCollection_INTERFACE_DEFINED__
#define __IEventObjectCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventObjectCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventObjectCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppUnkEnum) = 0;
    virtual HRESULT WINAPI get_Item(BSTR objectID,VARIANT *pItem) = 0;
    virtual HRESULT WINAPI get_NewEnum(IEnumEventObject **ppEnum) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pCount) = 0;
    virtual HRESULT WINAPI Add(VARIANT *item,BSTR objectID) = 0;
    virtual HRESULT WINAPI Remove(BSTR objectID) = 0;
  };
#else
  typedef struct IEventObjectCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventObjectCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventObjectCollection *This);
      ULONG (WINAPI *Release)(IEventObjectCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventObjectCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventObjectCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventObjectCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventObjectCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(IEventObjectCollection *This,IUnknown **ppUnkEnum);
      HRESULT (WINAPI *get_Item)(IEventObjectCollection *This,BSTR objectID,VARIANT *pItem);
      HRESULT (WINAPI *get_NewEnum)(IEventObjectCollection *This,IEnumEventObject **ppEnum);
      HRESULT (WINAPI *get_Count)(IEventObjectCollection *This,__LONG32 *pCount);
      HRESULT (WINAPI *Add)(IEventObjectCollection *This,VARIANT *item,BSTR objectID);
      HRESULT (WINAPI *Remove)(IEventObjectCollection *This,BSTR objectID);
    END_INTERFACE
  } IEventObjectCollectionVtbl;
  struct IEventObjectCollection {
    CONST_VTBL struct IEventObjectCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventObjectCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventObjectCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventObjectCollection_Release(This) (This)->lpVtbl->Release(This)
#define IEventObjectCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventObjectCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventObjectCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventObjectCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventObjectCollection_get__NewEnum(This,ppUnkEnum) (This)->lpVtbl->get__NewEnum(This,ppUnkEnum)
#define IEventObjectCollection_get_Item(This,objectID,pItem) (This)->lpVtbl->get_Item(This,objectID,pItem)
#define IEventObjectCollection_get_NewEnum(This,ppEnum) (This)->lpVtbl->get_NewEnum(This,ppEnum)
#define IEventObjectCollection_get_Count(This,pCount) (This)->lpVtbl->get_Count(This,pCount)
#define IEventObjectCollection_Add(This,item,objectID) (This)->lpVtbl->Add(This,item,objectID)
#define IEventObjectCollection_Remove(This,objectID) (This)->lpVtbl->Remove(This,objectID)
#endif
#endif
  HRESULT WINAPI IEventObjectCollection_get__NewEnum_Proxy(IEventObjectCollection *This,IUnknown **ppUnkEnum);
  void __RPC_STUB IEventObjectCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectCollection_get_Item_Proxy(IEventObjectCollection *This,BSTR objectID,VARIANT *pItem);
  void __RPC_STUB IEventObjectCollection_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectCollection_get_NewEnum_Proxy(IEventObjectCollection *This,IEnumEventObject **ppEnum);
  void __RPC_STUB IEventObjectCollection_get_NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectCollection_get_Count_Proxy(IEventObjectCollection *This,__LONG32 *pCount);
  void __RPC_STUB IEventObjectCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectCollection_Add_Proxy(IEventObjectCollection *This,VARIANT *item,BSTR objectID);
  void __RPC_STUB IEventObjectCollection_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventObjectCollection_Remove_Proxy(IEventObjectCollection *This,BSTR objectID);
  void __RPC_STUB IEventObjectCollection_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventProperty_INTERFACE_DEFINED__
#define __IEventProperty_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventProperty;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventProperty : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *propertyName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR propertyName) = 0;
    virtual HRESULT WINAPI get_Value(VARIANT *propertyValue) = 0;
    virtual HRESULT WINAPI put_Value(VARIANT *propertyValue) = 0;
  };
#else
  typedef struct IEventPropertyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventProperty *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventProperty *This);
      ULONG (WINAPI *Release)(IEventProperty *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventProperty *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventProperty *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventProperty *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventProperty *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(IEventProperty *This,BSTR *propertyName);
      HRESULT (WINAPI *put_Name)(IEventProperty *This,BSTR propertyName);
      HRESULT (WINAPI *get_Value)(IEventProperty *This,VARIANT *propertyValue);
      HRESULT (WINAPI *put_Value)(IEventProperty *This,VARIANT *propertyValue);
    END_INTERFACE
  } IEventPropertyVtbl;
  struct IEventProperty {
    CONST_VTBL struct IEventPropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventProperty_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventProperty_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventProperty_Release(This) (This)->lpVtbl->Release(This)
#define IEventProperty_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventProperty_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventProperty_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventProperty_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventProperty_get_Name(This,propertyName) (This)->lpVtbl->get_Name(This,propertyName)
#define IEventProperty_put_Name(This,propertyName) (This)->lpVtbl->put_Name(This,propertyName)
#define IEventProperty_get_Value(This,propertyValue) (This)->lpVtbl->get_Value(This,propertyValue)
#define IEventProperty_put_Value(This,propertyValue) (This)->lpVtbl->put_Value(This,propertyValue)
#endif
#endif
  HRESULT WINAPI IEventProperty_get_Name_Proxy(IEventProperty *This,BSTR *propertyName);
  void __RPC_STUB IEventProperty_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventProperty_put_Name_Proxy(IEventProperty *This,BSTR propertyName);
  void __RPC_STUB IEventProperty_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventProperty_get_Value_Proxy(IEventProperty *This,VARIANT *propertyValue);
  void __RPC_STUB IEventProperty_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventProperty_put_Value_Proxy(IEventProperty *This,VARIANT *propertyValue);
  void __RPC_STUB IEventProperty_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventControl_INTERFACE_DEFINED__
#define __IEventControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventControl : public IDispatch {
  public:
    virtual HRESULT WINAPI SetPublisherFilter(BSTR methodName,IPublisherFilter *pPublisherFilter) = 0;
    virtual HRESULT WINAPI get_AllowInprocActivation(WINBOOL *pfAllowInprocActivation) = 0;
    virtual HRESULT WINAPI put_AllowInprocActivation(WINBOOL fAllowInprocActivation) = 0;
    virtual HRESULT WINAPI GetSubscriptions(BSTR methodName,BSTR optionalCriteria,int *optionalErrorIndex,IEventObjectCollection **ppCollection) = 0;
    virtual HRESULT WINAPI SetDefaultQuery(BSTR methodName,BSTR criteria,int *errorIndex) = 0;
  };
#else
  typedef struct IEventControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventControl *This);
      ULONG (WINAPI *Release)(IEventControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetPublisherFilter)(IEventControl *This,BSTR methodName,IPublisherFilter *pPublisherFilter);
      HRESULT (WINAPI *get_AllowInprocActivation)(IEventControl *This,WINBOOL *pfAllowInprocActivation);
      HRESULT (WINAPI *put_AllowInprocActivation)(IEventControl *This,WINBOOL fAllowInprocActivation);
      HRESULT (WINAPI *GetSubscriptions)(IEventControl *This,BSTR methodName,BSTR optionalCriteria,int *optionalErrorIndex,IEventObjectCollection **ppCollection);
      HRESULT (WINAPI *SetDefaultQuery)(IEventControl *This,BSTR methodName,BSTR criteria,int *errorIndex);
    END_INTERFACE
  } IEventControlVtbl;
  struct IEventControl {
    CONST_VTBL struct IEventControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventControl_Release(This) (This)->lpVtbl->Release(This)
#define IEventControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventControl_SetPublisherFilter(This,methodName,pPublisherFilter) (This)->lpVtbl->SetPublisherFilter(This,methodName,pPublisherFilter)
#define IEventControl_get_AllowInprocActivation(This,pfAllowInprocActivation) (This)->lpVtbl->get_AllowInprocActivation(This,pfAllowInprocActivation)
#define IEventControl_put_AllowInprocActivation(This,fAllowInprocActivation) (This)->lpVtbl->put_AllowInprocActivation(This,fAllowInprocActivation)
#define IEventControl_GetSubscriptions(This,methodName,optionalCriteria,optionalErrorIndex,ppCollection) (This)->lpVtbl->GetSubscriptions(This,methodName,optionalCriteria,optionalErrorIndex,ppCollection)
#define IEventControl_SetDefaultQuery(This,methodName,criteria,errorIndex) (This)->lpVtbl->SetDefaultQuery(This,methodName,criteria,errorIndex)
#endif
#endif
  HRESULT WINAPI IEventControl_SetPublisherFilter_Proxy(IEventControl *This,BSTR methodName,IPublisherFilter *pPublisherFilter);
  void __RPC_STUB IEventControl_SetPublisherFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventControl_get_AllowInprocActivation_Proxy(IEventControl *This,WINBOOL *pfAllowInprocActivation);
  void __RPC_STUB IEventControl_get_AllowInprocActivation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventControl_put_AllowInprocActivation_Proxy(IEventControl *This,WINBOOL fAllowInprocActivation);
  void __RPC_STUB IEventControl_put_AllowInprocActivation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventControl_GetSubscriptions_Proxy(IEventControl *This,BSTR methodName,BSTR optionalCriteria,int *optionalErrorIndex,IEventObjectCollection **ppCollection);
  void __RPC_STUB IEventControl_GetSubscriptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventControl_SetDefaultQuery_Proxy(IEventControl *This,BSTR methodName,BSTR criteria,int *errorIndex);
  void __RPC_STUB IEventControl_SetDefaultQuery_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMultiInterfaceEventControl_INTERFACE_DEFINED__
#define __IMultiInterfaceEventControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMultiInterfaceEventControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMultiInterfaceEventControl : public IUnknown {
  public:
    virtual HRESULT WINAPI SetMultiInterfacePublisherFilter(IMultiInterfacePublisherFilter *classFilter) = 0;
    virtual HRESULT WINAPI GetSubscriptions(REFIID eventIID,BSTR bstrMethodName,BSTR optionalCriteria,int *optionalErrorIndex,IEventObjectCollection **ppCollection) = 0;
    virtual HRESULT WINAPI SetDefaultQuery(REFIID eventIID,BSTR bstrMethodName,BSTR bstrCriteria,int *errorIndex) = 0;
    virtual HRESULT WINAPI get_AllowInprocActivation(WINBOOL *pfAllowInprocActivation) = 0;
    virtual HRESULT WINAPI put_AllowInprocActivation(WINBOOL fAllowInprocActivation) = 0;
    virtual HRESULT WINAPI get_FireInParallel(WINBOOL *pfFireInParallel) = 0;
    virtual HRESULT WINAPI put_FireInParallel(WINBOOL fFireInParallel) = 0;
  };
#else
  typedef struct IMultiInterfaceEventControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMultiInterfaceEventControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMultiInterfaceEventControl *This);
      ULONG (WINAPI *Release)(IMultiInterfaceEventControl *This);
      HRESULT (WINAPI *SetMultiInterfacePublisherFilter)(IMultiInterfaceEventControl *This,IMultiInterfacePublisherFilter *classFilter);
      HRESULT (WINAPI *GetSubscriptions)(IMultiInterfaceEventControl *This,REFIID eventIID,BSTR bstrMethodName,BSTR optionalCriteria,int *optionalErrorIndex,IEventObjectCollection **ppCollection);
      HRESULT (WINAPI *SetDefaultQuery)(IMultiInterfaceEventControl *This,REFIID eventIID,BSTR bstrMethodName,BSTR bstrCriteria,int *errorIndex);
      HRESULT (WINAPI *get_AllowInprocActivation)(IMultiInterfaceEventControl *This,WINBOOL *pfAllowInprocActivation);
      HRESULT (WINAPI *put_AllowInprocActivation)(IMultiInterfaceEventControl *This,WINBOOL fAllowInprocActivation);
      HRESULT (WINAPI *get_FireInParallel)(IMultiInterfaceEventControl *This,WINBOOL *pfFireInParallel);
      HRESULT (WINAPI *put_FireInParallel)(IMultiInterfaceEventControl *This,WINBOOL fFireInParallel);
    END_INTERFACE
  } IMultiInterfaceEventControlVtbl;
  struct IMultiInterfaceEventControl {
    CONST_VTBL struct IMultiInterfaceEventControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMultiInterfaceEventControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMultiInterfaceEventControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMultiInterfaceEventControl_Release(This) (This)->lpVtbl->Release(This)
#define IMultiInterfaceEventControl_SetMultiInterfacePublisherFilter(This,classFilter) (This)->lpVtbl->SetMultiInterfacePublisherFilter(This,classFilter)
#define IMultiInterfaceEventControl_GetSubscriptions(This,eventIID,bstrMethodName,optionalCriteria,optionalErrorIndex,ppCollection) (This)->lpVtbl->GetSubscriptions(This,eventIID,bstrMethodName,optionalCriteria,optionalErrorIndex,ppCollection)
#define IMultiInterfaceEventControl_SetDefaultQuery(This,eventIID,bstrMethodName,bstrCriteria,errorIndex) (This)->lpVtbl->SetDefaultQuery(This,eventIID,bstrMethodName,bstrCriteria,errorIndex)
#define IMultiInterfaceEventControl_get_AllowInprocActivation(This,pfAllowInprocActivation) (This)->lpVtbl->get_AllowInprocActivation(This,pfAllowInprocActivation)
#define IMultiInterfaceEventControl_put_AllowInprocActivation(This,fAllowInprocActivation) (This)->lpVtbl->put_AllowInprocActivation(This,fAllowInprocActivation)
#define IMultiInterfaceEventControl_get_FireInParallel(This,pfFireInParallel) (This)->lpVtbl->get_FireInParallel(This,pfFireInParallel)
#define IMultiInterfaceEventControl_put_FireInParallel(This,fFireInParallel) (This)->lpVtbl->put_FireInParallel(This,fFireInParallel)
#endif
#endif
  HRESULT WINAPI IMultiInterfaceEventControl_SetMultiInterfacePublisherFilter_Proxy(IMultiInterfaceEventControl *This,IMultiInterfacePublisherFilter *classFilter);
  void __RPC_STUB IMultiInterfaceEventControl_SetMultiInterfacePublisherFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiInterfaceEventControl_GetSubscriptions_Proxy(IMultiInterfaceEventControl *This,REFIID eventIID,BSTR bstrMethodName,BSTR optionalCriteria,int *optionalErrorIndex,IEventObjectCollection **ppCollection);
  void __RPC_STUB IMultiInterfaceEventControl_GetSubscriptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiInterfaceEventControl_SetDefaultQuery_Proxy(IMultiInterfaceEventControl *This,REFIID eventIID,BSTR bstrMethodName,BSTR bstrCriteria,int *errorIndex);
  void __RPC_STUB IMultiInterfaceEventControl_SetDefaultQuery_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiInterfaceEventControl_get_AllowInprocActivation_Proxy(IMultiInterfaceEventControl *This,WINBOOL *pfAllowInprocActivation);
  void __RPC_STUB IMultiInterfaceEventControl_get_AllowInprocActivation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiInterfaceEventControl_put_AllowInprocActivation_Proxy(IMultiInterfaceEventControl *This,WINBOOL fAllowInprocActivation);
  void __RPC_STUB IMultiInterfaceEventControl_put_AllowInprocActivation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiInterfaceEventControl_get_FireInParallel_Proxy(IMultiInterfaceEventControl *This,WINBOOL *pfFireInParallel);
  void __RPC_STUB IMultiInterfaceEventControl_get_FireInParallel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiInterfaceEventControl_put_FireInParallel_Proxy(IMultiInterfaceEventControl *This,WINBOOL fFireInParallel);
  void __RPC_STUB IMultiInterfaceEventControl_put_FireInParallel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DummyEventSystemLib_LIBRARY_DEFINED__
#define __DummyEventSystemLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_DummyEventSystemLib;
  EXTERN_C const CLSID CLSID_CEventSystem;
#ifdef __cplusplus
  class CEventSystem;
#endif
  EXTERN_C const CLSID CLSID_CEventPublisher;
#ifdef __cplusplus
  class CEventPublisher;
#endif
  EXTERN_C const CLSID CLSID_CEventClass;
#ifdef __cplusplus
  class CEventClass;
#endif
  EXTERN_C const CLSID CLSID_CEventSubscription;
#ifdef __cplusplus
  class CEventSubscription;
#endif
  EXTERN_C const CLSID CLSID_EventObjectChange;
#ifdef __cplusplus
  class EventObjectChange;
#endif
  EXTERN_C const CLSID CLSID_EventObjectChange2;
#ifdef __cplusplus
  class EventObjectChange2;
#endif
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
