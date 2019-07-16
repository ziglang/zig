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

#ifndef __rend_h__
#define __rend_h__

#ifndef __ITDirectoryObjectConference_FWD_DEFINED__
#define __ITDirectoryObjectConference_FWD_DEFINED__
typedef struct ITDirectoryObjectConference ITDirectoryObjectConference;
#endif

#ifndef __ITDirectoryObjectUser_FWD_DEFINED__
#define __ITDirectoryObjectUser_FWD_DEFINED__
typedef struct ITDirectoryObjectUser ITDirectoryObjectUser;
#endif

#ifndef __IEnumDialableAddrs_FWD_DEFINED__
#define __IEnumDialableAddrs_FWD_DEFINED__
typedef struct IEnumDialableAddrs IEnumDialableAddrs;
#endif

#ifndef __ITDirectoryObject_FWD_DEFINED__
#define __ITDirectoryObject_FWD_DEFINED__
typedef struct ITDirectoryObject ITDirectoryObject;
#endif

#ifndef __IEnumDirectoryObject_FWD_DEFINED__
#define __IEnumDirectoryObject_FWD_DEFINED__
typedef struct IEnumDirectoryObject IEnumDirectoryObject;
#endif

#ifndef __ITILSConfig_FWD_DEFINED__
#define __ITILSConfig_FWD_DEFINED__
typedef struct ITILSConfig ITILSConfig;
#endif

#ifndef __ITDirectory_FWD_DEFINED__
#define __ITDirectory_FWD_DEFINED__
typedef struct ITDirectory ITDirectory;
#endif

#ifndef __IEnumDirectory_FWD_DEFINED__
#define __IEnumDirectory_FWD_DEFINED__
typedef struct IEnumDirectory IEnumDirectory;
#endif

#ifndef __ITRendezvous_FWD_DEFINED__
#define __ITRendezvous_FWD_DEFINED__
typedef struct ITRendezvous ITRendezvous;
#endif

#ifndef __ITRendezvous_FWD_DEFINED__
#define __ITRendezvous_FWD_DEFINED__
typedef struct ITRendezvous ITRendezvous;
#endif

#ifndef __ITDirectoryObjectConference_FWD_DEFINED__
#define __ITDirectoryObjectConference_FWD_DEFINED__
typedef struct ITDirectoryObjectConference ITDirectoryObjectConference;
#endif

#ifndef __ITDirectoryObjectUser_FWD_DEFINED__
#define __ITDirectoryObjectUser_FWD_DEFINED__
typedef struct ITDirectoryObjectUser ITDirectoryObjectUser;
#endif

#ifndef __ITDirectoryObject_FWD_DEFINED__
#define __ITDirectoryObject_FWD_DEFINED__
typedef struct ITDirectoryObject ITDirectoryObject;
#endif

#ifndef __ITILSConfig_FWD_DEFINED__
#define __ITILSConfig_FWD_DEFINED__
typedef struct ITILSConfig ITILSConfig;
#endif

#ifndef __ITDirectory_FWD_DEFINED__
#define __ITDirectory_FWD_DEFINED__
typedef struct ITDirectory ITDirectory;
#endif

#ifndef __Rendezvous_FWD_DEFINED__
#define __Rendezvous_FWD_DEFINED__
#ifdef __cplusplus
typedef class Rendezvous Rendezvous;
#else
typedef struct Rendezvous Rendezvous;
#endif
#endif

#include "oaidl.h"
#include "tapi3if.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define IDISPDIROBJECT (0x10000)
#define IDISPDIROBJCONFERENCE (0x20000)
#define IDISPDIROBJUSER (0x30000)
#define IDISPDIRECTORY (0x10000)
#define IDISPILSCONFIG (0x20000)

  typedef enum DIRECTORY_TYPE {
    DT_NTDS = 1,DT_ILS = 2
  } DIRECTORY_TYPE;

  typedef enum DIRECTORY_OBJECT_TYPE {
    OT_CONFERENCE = 1,OT_USER = 2
  } DIRECTORY_OBJECT_TYPE;

  typedef enum RND_ADVERTISING_SCOPE {
    RAS_LOCAL = 1,RAS_SITE = 2,RAS_REGION = 3,RAS_WORLD = 4
  } RND_ADVERTISING_SCOPE;

  extern RPC_IF_HANDLE __MIDL_itf_rend_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rend_0000_v0_0_s_ifspec;

#ifndef __ITDirectoryObjectConference_INTERFACE_DEFINED__
#define __ITDirectoryObjectConference_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDirectoryObjectConference;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDirectoryObjectConference : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Protocol(BSTR *ppProtocol) = 0;
    virtual HRESULT WINAPI get_Originator(BSTR *ppOriginator) = 0;
    virtual HRESULT WINAPI put_Originator(BSTR pOriginator) = 0;
    virtual HRESULT WINAPI get_AdvertisingScope(RND_ADVERTISING_SCOPE *pAdvertisingScope) = 0;
    virtual HRESULT WINAPI put_AdvertisingScope(RND_ADVERTISING_SCOPE AdvertisingScope) = 0;
    virtual HRESULT WINAPI get_Url(BSTR *ppUrl) = 0;
    virtual HRESULT WINAPI put_Url(BSTR pUrl) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *ppDescription) = 0;
    virtual HRESULT WINAPI put_Description(BSTR pDescription) = 0;
    virtual HRESULT WINAPI get_IsEncrypted(VARIANT_BOOL *pfEncrypted) = 0;
    virtual HRESULT WINAPI put_IsEncrypted(VARIANT_BOOL fEncrypted) = 0;
    virtual HRESULT WINAPI get_StartTime(DATE *pDate) = 0;
    virtual HRESULT WINAPI put_StartTime(DATE Date) = 0;
    virtual HRESULT WINAPI get_StopTime(DATE *pDate) = 0;
    virtual HRESULT WINAPI put_StopTime(DATE Date) = 0;
  };
#else
  typedef struct ITDirectoryObjectConferenceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDirectoryObjectConference *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDirectoryObjectConference *This);
      ULONG (WINAPI *Release)(ITDirectoryObjectConference *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDirectoryObjectConference *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDirectoryObjectConference *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDirectoryObjectConference *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDirectoryObjectConference *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Protocol)(ITDirectoryObjectConference *This,BSTR *ppProtocol);
      HRESULT (WINAPI *get_Originator)(ITDirectoryObjectConference *This,BSTR *ppOriginator);
      HRESULT (WINAPI *put_Originator)(ITDirectoryObjectConference *This,BSTR pOriginator);
      HRESULT (WINAPI *get_AdvertisingScope)(ITDirectoryObjectConference *This,RND_ADVERTISING_SCOPE *pAdvertisingScope);
      HRESULT (WINAPI *put_AdvertisingScope)(ITDirectoryObjectConference *This,RND_ADVERTISING_SCOPE AdvertisingScope);
      HRESULT (WINAPI *get_Url)(ITDirectoryObjectConference *This,BSTR *ppUrl);
      HRESULT (WINAPI *put_Url)(ITDirectoryObjectConference *This,BSTR pUrl);
      HRESULT (WINAPI *get_Description)(ITDirectoryObjectConference *This,BSTR *ppDescription);
      HRESULT (WINAPI *put_Description)(ITDirectoryObjectConference *This,BSTR pDescription);
      HRESULT (WINAPI *get_IsEncrypted)(ITDirectoryObjectConference *This,VARIANT_BOOL *pfEncrypted);
      HRESULT (WINAPI *put_IsEncrypted)(ITDirectoryObjectConference *This,VARIANT_BOOL fEncrypted);
      HRESULT (WINAPI *get_StartTime)(ITDirectoryObjectConference *This,DATE *pDate);
      HRESULT (WINAPI *put_StartTime)(ITDirectoryObjectConference *This,DATE Date);
      HRESULT (WINAPI *get_StopTime)(ITDirectoryObjectConference *This,DATE *pDate);
      HRESULT (WINAPI *put_StopTime)(ITDirectoryObjectConference *This,DATE Date);
    END_INTERFACE
  } ITDirectoryObjectConferenceVtbl;
  struct ITDirectoryObjectConference {
    CONST_VTBL struct ITDirectoryObjectConferenceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDirectoryObjectConference_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDirectoryObjectConference_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDirectoryObjectConference_Release(This) (This)->lpVtbl->Release(This)
#define ITDirectoryObjectConference_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDirectoryObjectConference_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDirectoryObjectConference_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDirectoryObjectConference_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDirectoryObjectConference_get_Protocol(This,ppProtocol) (This)->lpVtbl->get_Protocol(This,ppProtocol)
#define ITDirectoryObjectConference_get_Originator(This,ppOriginator) (This)->lpVtbl->get_Originator(This,ppOriginator)
#define ITDirectoryObjectConference_put_Originator(This,pOriginator) (This)->lpVtbl->put_Originator(This,pOriginator)
#define ITDirectoryObjectConference_get_AdvertisingScope(This,pAdvertisingScope) (This)->lpVtbl->get_AdvertisingScope(This,pAdvertisingScope)
#define ITDirectoryObjectConference_put_AdvertisingScope(This,AdvertisingScope) (This)->lpVtbl->put_AdvertisingScope(This,AdvertisingScope)
#define ITDirectoryObjectConference_get_Url(This,ppUrl) (This)->lpVtbl->get_Url(This,ppUrl)
#define ITDirectoryObjectConference_put_Url(This,pUrl) (This)->lpVtbl->put_Url(This,pUrl)
#define ITDirectoryObjectConference_get_Description(This,ppDescription) (This)->lpVtbl->get_Description(This,ppDescription)
#define ITDirectoryObjectConference_put_Description(This,pDescription) (This)->lpVtbl->put_Description(This,pDescription)
#define ITDirectoryObjectConference_get_IsEncrypted(This,pfEncrypted) (This)->lpVtbl->get_IsEncrypted(This,pfEncrypted)
#define ITDirectoryObjectConference_put_IsEncrypted(This,fEncrypted) (This)->lpVtbl->put_IsEncrypted(This,fEncrypted)
#define ITDirectoryObjectConference_get_StartTime(This,pDate) (This)->lpVtbl->get_StartTime(This,pDate)
#define ITDirectoryObjectConference_put_StartTime(This,Date) (This)->lpVtbl->put_StartTime(This,Date)
#define ITDirectoryObjectConference_get_StopTime(This,pDate) (This)->lpVtbl->get_StopTime(This,pDate)
#define ITDirectoryObjectConference_put_StopTime(This,Date) (This)->lpVtbl->put_StopTime(This,Date)
#endif
#endif
  HRESULT WINAPI ITDirectoryObjectConference_get_Protocol_Proxy(ITDirectoryObjectConference *This,BSTR *ppProtocol);
  void __RPC_STUB ITDirectoryObjectConference_get_Protocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_get_Originator_Proxy(ITDirectoryObjectConference *This,BSTR *ppOriginator);
  void __RPC_STUB ITDirectoryObjectConference_get_Originator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_put_Originator_Proxy(ITDirectoryObjectConference *This,BSTR pOriginator);
  void __RPC_STUB ITDirectoryObjectConference_put_Originator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_get_AdvertisingScope_Proxy(ITDirectoryObjectConference *This,RND_ADVERTISING_SCOPE *pAdvertisingScope);
  void __RPC_STUB ITDirectoryObjectConference_get_AdvertisingScope_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_put_AdvertisingScope_Proxy(ITDirectoryObjectConference *This,RND_ADVERTISING_SCOPE AdvertisingScope);
  void __RPC_STUB ITDirectoryObjectConference_put_AdvertisingScope_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_get_Url_Proxy(ITDirectoryObjectConference *This,BSTR *ppUrl);
  void __RPC_STUB ITDirectoryObjectConference_get_Url_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_put_Url_Proxy(ITDirectoryObjectConference *This,BSTR pUrl);
  void __RPC_STUB ITDirectoryObjectConference_put_Url_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_get_Description_Proxy(ITDirectoryObjectConference *This,BSTR *ppDescription);
  void __RPC_STUB ITDirectoryObjectConference_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_put_Description_Proxy(ITDirectoryObjectConference *This,BSTR pDescription);
  void __RPC_STUB ITDirectoryObjectConference_put_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_get_IsEncrypted_Proxy(ITDirectoryObjectConference *This,VARIANT_BOOL *pfEncrypted);
  void __RPC_STUB ITDirectoryObjectConference_get_IsEncrypted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_put_IsEncrypted_Proxy(ITDirectoryObjectConference *This,VARIANT_BOOL fEncrypted);
  void __RPC_STUB ITDirectoryObjectConference_put_IsEncrypted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_get_StartTime_Proxy(ITDirectoryObjectConference *This,DATE *pDate);
  void __RPC_STUB ITDirectoryObjectConference_get_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_put_StartTime_Proxy(ITDirectoryObjectConference *This,DATE Date);
  void __RPC_STUB ITDirectoryObjectConference_put_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_get_StopTime_Proxy(ITDirectoryObjectConference *This,DATE *pDate);
  void __RPC_STUB ITDirectoryObjectConference_get_StopTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectConference_put_StopTime_Proxy(ITDirectoryObjectConference *This,DATE Date);
  void __RPC_STUB ITDirectoryObjectConference_put_StopTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDirectoryObjectUser_INTERFACE_DEFINED__
#define __ITDirectoryObjectUser_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDirectoryObjectUser;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDirectoryObjectUser : public IDispatch {
  public:
    virtual HRESULT WINAPI get_IPPhonePrimary(BSTR *ppName) = 0;
    virtual HRESULT WINAPI put_IPPhonePrimary(BSTR pName) = 0;
  };
#else
  typedef struct ITDirectoryObjectUserVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDirectoryObjectUser *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDirectoryObjectUser *This);
      ULONG (WINAPI *Release)(ITDirectoryObjectUser *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDirectoryObjectUser *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDirectoryObjectUser *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDirectoryObjectUser *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDirectoryObjectUser *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_IPPhonePrimary)(ITDirectoryObjectUser *This,BSTR *ppName);
      HRESULT (WINAPI *put_IPPhonePrimary)(ITDirectoryObjectUser *This,BSTR pName);
    END_INTERFACE
  } ITDirectoryObjectUserVtbl;
  struct ITDirectoryObjectUser {
    CONST_VTBL struct ITDirectoryObjectUserVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDirectoryObjectUser_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDirectoryObjectUser_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDirectoryObjectUser_Release(This) (This)->lpVtbl->Release(This)
#define ITDirectoryObjectUser_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDirectoryObjectUser_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDirectoryObjectUser_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDirectoryObjectUser_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDirectoryObjectUser_get_IPPhonePrimary(This,ppName) (This)->lpVtbl->get_IPPhonePrimary(This,ppName)
#define ITDirectoryObjectUser_put_IPPhonePrimary(This,pName) (This)->lpVtbl->put_IPPhonePrimary(This,pName)
#endif
#endif
  HRESULT WINAPI ITDirectoryObjectUser_get_IPPhonePrimary_Proxy(ITDirectoryObjectUser *This,BSTR *ppName);
  void __RPC_STUB ITDirectoryObjectUser_get_IPPhonePrimary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObjectUser_put_IPPhonePrimary_Proxy(ITDirectoryObjectUser *This,BSTR pName);
  void __RPC_STUB ITDirectoryObjectUser_put_IPPhonePrimary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumDialableAddrs_INTERFACE_DEFINED__
#define __IEnumDialableAddrs_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumDialableAddrs;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumDialableAddrs : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,BSTR *ppElements,ULONG *pcFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumDialableAddrs **ppEnum) = 0;
  };
#else
  typedef struct IEnumDialableAddrsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumDialableAddrs *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumDialableAddrs *This);
      ULONG (WINAPI *Release)(IEnumDialableAddrs *This);
      HRESULT (WINAPI *Next)(IEnumDialableAddrs *This,ULONG celt,BSTR *ppElements,ULONG *pcFetched);
      HRESULT (WINAPI *Reset)(IEnumDialableAddrs *This);
      HRESULT (WINAPI *Skip)(IEnumDialableAddrs *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumDialableAddrs *This,IEnumDialableAddrs **ppEnum);
    END_INTERFACE
  } IEnumDialableAddrsVtbl;
  struct IEnumDialableAddrs {
    CONST_VTBL struct IEnumDialableAddrsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumDialableAddrs_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumDialableAddrs_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumDialableAddrs_Release(This) (This)->lpVtbl->Release(This)
#define IEnumDialableAddrs_Next(This,celt,ppElements,pcFetched) (This)->lpVtbl->Next(This,celt,ppElements,pcFetched)
#define IEnumDialableAddrs_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumDialableAddrs_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumDialableAddrs_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumDialableAddrs_Next_Proxy(IEnumDialableAddrs *This,ULONG celt,BSTR *ppElements,ULONG *pcFetched);
  void __RPC_STUB IEnumDialableAddrs_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDialableAddrs_Reset_Proxy(IEnumDialableAddrs *This);
  void __RPC_STUB IEnumDialableAddrs_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDialableAddrs_Skip_Proxy(IEnumDialableAddrs *This,ULONG celt);
  void __RPC_STUB IEnumDialableAddrs_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDialableAddrs_Clone_Proxy(IEnumDialableAddrs *This,IEnumDialableAddrs **ppEnum);
  void __RPC_STUB IEnumDialableAddrs_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDirectoryObject_INTERFACE_DEFINED__
#define __ITDirectoryObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDirectoryObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDirectoryObject : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ObjectType(DIRECTORY_OBJECT_TYPE *pObjectType) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *ppName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR pName) = 0;
    virtual HRESULT WINAPI get_DialableAddrs(__LONG32 dwAddressType,VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateDialableAddrs(DWORD dwAddressType,IEnumDialableAddrs **ppEnumDialableAddrs) = 0;
    virtual HRESULT WINAPI get_SecurityDescriptor(IDispatch **ppSecDes) = 0;
    virtual HRESULT WINAPI put_SecurityDescriptor(IDispatch *pSecDes) = 0;
  };
#else
  typedef struct ITDirectoryObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDirectoryObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDirectoryObject *This);
      ULONG (WINAPI *Release)(ITDirectoryObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDirectoryObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDirectoryObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDirectoryObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDirectoryObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ObjectType)(ITDirectoryObject *This,DIRECTORY_OBJECT_TYPE *pObjectType);
      HRESULT (WINAPI *get_Name)(ITDirectoryObject *This,BSTR *ppName);
      HRESULT (WINAPI *put_Name)(ITDirectoryObject *This,BSTR pName);
      HRESULT (WINAPI *get_DialableAddrs)(ITDirectoryObject *This,__LONG32 dwAddressType,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateDialableAddrs)(ITDirectoryObject *This,DWORD dwAddressType,IEnumDialableAddrs **ppEnumDialableAddrs);
      HRESULT (WINAPI *get_SecurityDescriptor)(ITDirectoryObject *This,IDispatch **ppSecDes);
      HRESULT (WINAPI *put_SecurityDescriptor)(ITDirectoryObject *This,IDispatch *pSecDes);
    END_INTERFACE
  } ITDirectoryObjectVtbl;
  struct ITDirectoryObject {
    CONST_VTBL struct ITDirectoryObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDirectoryObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDirectoryObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDirectoryObject_Release(This) (This)->lpVtbl->Release(This)
#define ITDirectoryObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDirectoryObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDirectoryObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDirectoryObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDirectoryObject_get_ObjectType(This,pObjectType) (This)->lpVtbl->get_ObjectType(This,pObjectType)
#define ITDirectoryObject_get_Name(This,ppName) (This)->lpVtbl->get_Name(This,ppName)
#define ITDirectoryObject_put_Name(This,pName) (This)->lpVtbl->put_Name(This,pName)
#define ITDirectoryObject_get_DialableAddrs(This,dwAddressType,pVariant) (This)->lpVtbl->get_DialableAddrs(This,dwAddressType,pVariant)
#define ITDirectoryObject_EnumerateDialableAddrs(This,dwAddressType,ppEnumDialableAddrs) (This)->lpVtbl->EnumerateDialableAddrs(This,dwAddressType,ppEnumDialableAddrs)
#define ITDirectoryObject_get_SecurityDescriptor(This,ppSecDes) (This)->lpVtbl->get_SecurityDescriptor(This,ppSecDes)
#define ITDirectoryObject_put_SecurityDescriptor(This,pSecDes) (This)->lpVtbl->put_SecurityDescriptor(This,pSecDes)
#endif
#endif
  HRESULT WINAPI ITDirectoryObject_get_ObjectType_Proxy(ITDirectoryObject *This,DIRECTORY_OBJECT_TYPE *pObjectType);
  void __RPC_STUB ITDirectoryObject_get_ObjectType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObject_get_Name_Proxy(ITDirectoryObject *This,BSTR *ppName);
  void __RPC_STUB ITDirectoryObject_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObject_put_Name_Proxy(ITDirectoryObject *This,BSTR pName);
  void __RPC_STUB ITDirectoryObject_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObject_get_DialableAddrs_Proxy(ITDirectoryObject *This,__LONG32 dwAddressType,VARIANT *pVariant);
  void __RPC_STUB ITDirectoryObject_get_DialableAddrs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObject_EnumerateDialableAddrs_Proxy(ITDirectoryObject *This,DWORD dwAddressType,IEnumDialableAddrs **ppEnumDialableAddrs);
  void __RPC_STUB ITDirectoryObject_EnumerateDialableAddrs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObject_get_SecurityDescriptor_Proxy(ITDirectoryObject *This,IDispatch **ppSecDes);
  void __RPC_STUB ITDirectoryObject_get_SecurityDescriptor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectoryObject_put_SecurityDescriptor_Proxy(ITDirectoryObject *This,IDispatch *pSecDes);
  void __RPC_STUB ITDirectoryObject_put_SecurityDescriptor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumDirectoryObject_INTERFACE_DEFINED__
#define __IEnumDirectoryObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumDirectoryObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumDirectoryObject : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITDirectoryObject **pVal,ULONG *pcFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumDirectoryObject **ppEnum) = 0;
  };
#else
  typedef struct IEnumDirectoryObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumDirectoryObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumDirectoryObject *This);
      ULONG (WINAPI *Release)(IEnumDirectoryObject *This);
      HRESULT (WINAPI *Next)(IEnumDirectoryObject *This,ULONG celt,ITDirectoryObject **pVal,ULONG *pcFetched);
      HRESULT (WINAPI *Reset)(IEnumDirectoryObject *This);
      HRESULT (WINAPI *Skip)(IEnumDirectoryObject *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumDirectoryObject *This,IEnumDirectoryObject **ppEnum);
    END_INTERFACE
  } IEnumDirectoryObjectVtbl;
  struct IEnumDirectoryObject {
    CONST_VTBL struct IEnumDirectoryObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumDirectoryObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumDirectoryObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumDirectoryObject_Release(This) (This)->lpVtbl->Release(This)
#define IEnumDirectoryObject_Next(This,celt,pVal,pcFetched) (This)->lpVtbl->Next(This,celt,pVal,pcFetched)
#define IEnumDirectoryObject_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumDirectoryObject_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumDirectoryObject_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumDirectoryObject_Next_Proxy(IEnumDirectoryObject *This,ULONG celt,ITDirectoryObject **pVal,ULONG *pcFetched);
  void __RPC_STUB IEnumDirectoryObject_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDirectoryObject_Reset_Proxy(IEnumDirectoryObject *This);
  void __RPC_STUB IEnumDirectoryObject_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDirectoryObject_Skip_Proxy(IEnumDirectoryObject *This,ULONG celt);
  void __RPC_STUB IEnumDirectoryObject_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDirectoryObject_Clone_Proxy(IEnumDirectoryObject *This,IEnumDirectoryObject **ppEnum);
  void __RPC_STUB IEnumDirectoryObject_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITILSConfig_INTERFACE_DEFINED__
#define __ITILSConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITILSConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITILSConfig : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Port(__LONG32 *pPort) = 0;
    virtual HRESULT WINAPI put_Port(__LONG32 Port) = 0;
  };
#else
  typedef struct ITILSConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITILSConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITILSConfig *This);
      ULONG (WINAPI *Release)(ITILSConfig *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITILSConfig *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITILSConfig *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITILSConfig *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITILSConfig *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Port)(ITILSConfig *This,__LONG32 *pPort);
      HRESULT (WINAPI *put_Port)(ITILSConfig *This,__LONG32 Port);
    END_INTERFACE
  } ITILSConfigVtbl;
  struct ITILSConfig {
    CONST_VTBL struct ITILSConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITILSConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITILSConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITILSConfig_Release(This) (This)->lpVtbl->Release(This)
#define ITILSConfig_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITILSConfig_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITILSConfig_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITILSConfig_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITILSConfig_get_Port(This,pPort) (This)->lpVtbl->get_Port(This,pPort)
#define ITILSConfig_put_Port(This,Port) (This)->lpVtbl->put_Port(This,Port)
#endif
#endif
  HRESULT WINAPI ITILSConfig_get_Port_Proxy(ITILSConfig *This,__LONG32 *pPort);
  void __RPC_STUB ITILSConfig_get_Port_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITILSConfig_put_Port_Proxy(ITILSConfig *This,__LONG32 Port);
  void __RPC_STUB ITILSConfig_put_Port_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDirectory_INTERFACE_DEFINED__
#define __ITDirectory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDirectory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDirectory : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DirectoryType(DIRECTORY_TYPE *pDirectoryType) = 0;
    virtual HRESULT WINAPI get_DisplayName(BSTR *pName) = 0;
    virtual HRESULT WINAPI get_IsDynamic(VARIANT_BOOL *pfDynamic) = 0;
    virtual HRESULT WINAPI get_DefaultObjectTTL(__LONG32 *pTTL) = 0;
    virtual HRESULT WINAPI put_DefaultObjectTTL(__LONG32 TTL) = 0;
    virtual HRESULT WINAPI EnableAutoRefresh(VARIANT_BOOL fEnable) = 0;
    virtual HRESULT WINAPI Connect(VARIANT_BOOL fSecure) = 0;
    virtual HRESULT WINAPI Bind(BSTR pDomainName,BSTR pUserName,BSTR pPassword,__LONG32 lFlags) = 0;
    virtual HRESULT WINAPI AddDirectoryObject(ITDirectoryObject *pDirectoryObject) = 0;
    virtual HRESULT WINAPI ModifyDirectoryObject(ITDirectoryObject *pDirectoryObject) = 0;
    virtual HRESULT WINAPI RefreshDirectoryObject(ITDirectoryObject *pDirectoryObject) = 0;
    virtual HRESULT WINAPI DeleteDirectoryObject(ITDirectoryObject *pDirectoryObject) = 0;
    virtual HRESULT WINAPI get_DirectoryObjects(DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateDirectoryObjects(DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,IEnumDirectoryObject **ppEnumObject) = 0;
  };
#else
  typedef struct ITDirectoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDirectory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDirectory *This);
      ULONG (WINAPI *Release)(ITDirectory *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDirectory *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDirectory *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDirectory *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDirectory *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DirectoryType)(ITDirectory *This,DIRECTORY_TYPE *pDirectoryType);
      HRESULT (WINAPI *get_DisplayName)(ITDirectory *This,BSTR *pName);
      HRESULT (WINAPI *get_IsDynamic)(ITDirectory *This,VARIANT_BOOL *pfDynamic);
      HRESULT (WINAPI *get_DefaultObjectTTL)(ITDirectory *This,__LONG32 *pTTL);
      HRESULT (WINAPI *put_DefaultObjectTTL)(ITDirectory *This,__LONG32 TTL);
      HRESULT (WINAPI *EnableAutoRefresh)(ITDirectory *This,VARIANT_BOOL fEnable);
      HRESULT (WINAPI *Connect)(ITDirectory *This,VARIANT_BOOL fSecure);
      HRESULT (WINAPI *Bind)(ITDirectory *This,BSTR pDomainName,BSTR pUserName,BSTR pPassword,__LONG32 lFlags);
      HRESULT (WINAPI *AddDirectoryObject)(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
      HRESULT (WINAPI *ModifyDirectoryObject)(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
      HRESULT (WINAPI *RefreshDirectoryObject)(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
      HRESULT (WINAPI *DeleteDirectoryObject)(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
      HRESULT (WINAPI *get_DirectoryObjects)(ITDirectory *This,DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateDirectoryObjects)(ITDirectory *This,DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,IEnumDirectoryObject **ppEnumObject);
    END_INTERFACE
  } ITDirectoryVtbl;
  struct ITDirectory {
    CONST_VTBL struct ITDirectoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDirectory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDirectory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDirectory_Release(This) (This)->lpVtbl->Release(This)
#define ITDirectory_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDirectory_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDirectory_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDirectory_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDirectory_get_DirectoryType(This,pDirectoryType) (This)->lpVtbl->get_DirectoryType(This,pDirectoryType)
#define ITDirectory_get_DisplayName(This,pName) (This)->lpVtbl->get_DisplayName(This,pName)
#define ITDirectory_get_IsDynamic(This,pfDynamic) (This)->lpVtbl->get_IsDynamic(This,pfDynamic)
#define ITDirectory_get_DefaultObjectTTL(This,pTTL) (This)->lpVtbl->get_DefaultObjectTTL(This,pTTL)
#define ITDirectory_put_DefaultObjectTTL(This,TTL) (This)->lpVtbl->put_DefaultObjectTTL(This,TTL)
#define ITDirectory_EnableAutoRefresh(This,fEnable) (This)->lpVtbl->EnableAutoRefresh(This,fEnable)
#define ITDirectory_Connect(This,fSecure) (This)->lpVtbl->Connect(This,fSecure)
#define ITDirectory_Bind(This,pDomainName,pUserName,pPassword,lFlags) (This)->lpVtbl->Bind(This,pDomainName,pUserName,pPassword,lFlags)
#define ITDirectory_AddDirectoryObject(This,pDirectoryObject) (This)->lpVtbl->AddDirectoryObject(This,pDirectoryObject)
#define ITDirectory_ModifyDirectoryObject(This,pDirectoryObject) (This)->lpVtbl->ModifyDirectoryObject(This,pDirectoryObject)
#define ITDirectory_RefreshDirectoryObject(This,pDirectoryObject) (This)->lpVtbl->RefreshDirectoryObject(This,pDirectoryObject)
#define ITDirectory_DeleteDirectoryObject(This,pDirectoryObject) (This)->lpVtbl->DeleteDirectoryObject(This,pDirectoryObject)
#define ITDirectory_get_DirectoryObjects(This,DirectoryObjectType,pName,pVariant) (This)->lpVtbl->get_DirectoryObjects(This,DirectoryObjectType,pName,pVariant)
#define ITDirectory_EnumerateDirectoryObjects(This,DirectoryObjectType,pName,ppEnumObject) (This)->lpVtbl->EnumerateDirectoryObjects(This,DirectoryObjectType,pName,ppEnumObject)
#endif
#endif
  HRESULT WINAPI ITDirectory_get_DirectoryType_Proxy(ITDirectory *This,DIRECTORY_TYPE *pDirectoryType);
  void __RPC_STUB ITDirectory_get_DirectoryType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_get_DisplayName_Proxy(ITDirectory *This,BSTR *pName);
  void __RPC_STUB ITDirectory_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_get_IsDynamic_Proxy(ITDirectory *This,VARIANT_BOOL *pfDynamic);
  void __RPC_STUB ITDirectory_get_IsDynamic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_get_DefaultObjectTTL_Proxy(ITDirectory *This,__LONG32 *pTTL);
  void __RPC_STUB ITDirectory_get_DefaultObjectTTL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_put_DefaultObjectTTL_Proxy(ITDirectory *This,__LONG32 TTL);
  void __RPC_STUB ITDirectory_put_DefaultObjectTTL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_EnableAutoRefresh_Proxy(ITDirectory *This,VARIANT_BOOL fEnable);
  void __RPC_STUB ITDirectory_EnableAutoRefresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_Connect_Proxy(ITDirectory *This,VARIANT_BOOL fSecure);
  void __RPC_STUB ITDirectory_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_Bind_Proxy(ITDirectory *This,BSTR pDomainName,BSTR pUserName,BSTR pPassword,__LONG32 lFlags);
  void __RPC_STUB ITDirectory_Bind_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_AddDirectoryObject_Proxy(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
  void __RPC_STUB ITDirectory_AddDirectoryObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_ModifyDirectoryObject_Proxy(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
  void __RPC_STUB ITDirectory_ModifyDirectoryObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_RefreshDirectoryObject_Proxy(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
  void __RPC_STUB ITDirectory_RefreshDirectoryObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_DeleteDirectoryObject_Proxy(ITDirectory *This,ITDirectoryObject *pDirectoryObject);
  void __RPC_STUB ITDirectory_DeleteDirectoryObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_get_DirectoryObjects_Proxy(ITDirectory *This,DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,VARIANT *pVariant);
  void __RPC_STUB ITDirectory_get_DirectoryObjects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDirectory_EnumerateDirectoryObjects_Proxy(ITDirectory *This,DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,IEnumDirectoryObject **ppEnumObject);
  void __RPC_STUB ITDirectory_EnumerateDirectoryObjects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumDirectory_INTERFACE_DEFINED__
#define __IEnumDirectory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumDirectory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumDirectory : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITDirectory **ppElements,ULONG *pcFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumDirectory **ppEnum) = 0;
  };
#else
  typedef struct IEnumDirectoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumDirectory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumDirectory *This);
      ULONG (WINAPI *Release)(IEnumDirectory *This);
      HRESULT (WINAPI *Next)(IEnumDirectory *This,ULONG celt,ITDirectory **ppElements,ULONG *pcFetched);
      HRESULT (WINAPI *Reset)(IEnumDirectory *This);
      HRESULT (WINAPI *Skip)(IEnumDirectory *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumDirectory *This,IEnumDirectory **ppEnum);
    END_INTERFACE
  } IEnumDirectoryVtbl;
  struct IEnumDirectory {
    CONST_VTBL struct IEnumDirectoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumDirectory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumDirectory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumDirectory_Release(This) (This)->lpVtbl->Release(This)
#define IEnumDirectory_Next(This,celt,ppElements,pcFetched) (This)->lpVtbl->Next(This,celt,ppElements,pcFetched)
#define IEnumDirectory_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumDirectory_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumDirectory_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumDirectory_Next_Proxy(IEnumDirectory *This,ULONG celt,ITDirectory **ppElements,ULONG *pcFetched);
  void __RPC_STUB IEnumDirectory_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDirectory_Reset_Proxy(IEnumDirectory *This);
  void __RPC_STUB IEnumDirectory_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDirectory_Skip_Proxy(IEnumDirectory *This,ULONG celt);
  void __RPC_STUB IEnumDirectory_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumDirectory_Clone_Proxy(IEnumDirectory *This,IEnumDirectory **ppEnum);
  void __RPC_STUB IEnumDirectory_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITRendezvous_INTERFACE_DEFINED__
#define __ITRendezvous_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITRendezvous;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITRendezvous : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DefaultDirectories(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateDefaultDirectories(IEnumDirectory **ppEnumDirectory) = 0;
    virtual HRESULT WINAPI CreateDirectory(DIRECTORY_TYPE DirectoryType,BSTR pName,ITDirectory **ppDir) = 0;
    virtual HRESULT WINAPI CreateDirectoryObject(DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,ITDirectoryObject **ppDirectoryObject) = 0;
  };
#else
  typedef struct ITRendezvousVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITRendezvous *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITRendezvous *This);
      ULONG (WINAPI *Release)(ITRendezvous *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITRendezvous *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITRendezvous *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITRendezvous *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITRendezvous *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DefaultDirectories)(ITRendezvous *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateDefaultDirectories)(ITRendezvous *This,IEnumDirectory **ppEnumDirectory);
      HRESULT (WINAPI *CreateDirectory)(ITRendezvous *This,DIRECTORY_TYPE DirectoryType,BSTR pName,ITDirectory **ppDir);
      HRESULT (WINAPI *CreateDirectoryObject)(ITRendezvous *This,DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,ITDirectoryObject **ppDirectoryObject);
    END_INTERFACE
  } ITRendezvousVtbl;
  struct ITRendezvous {
    CONST_VTBL struct ITRendezvousVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITRendezvous_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITRendezvous_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITRendezvous_Release(This) (This)->lpVtbl->Release(This)
#define ITRendezvous_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITRendezvous_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITRendezvous_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITRendezvous_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITRendezvous_get_DefaultDirectories(This,pVariant) (This)->lpVtbl->get_DefaultDirectories(This,pVariant)
#define ITRendezvous_EnumerateDefaultDirectories(This,ppEnumDirectory) (This)->lpVtbl->EnumerateDefaultDirectories(This,ppEnumDirectory)
#define ITRendezvous_CreateDirectory(This,DirectoryType,pName,ppDir) (This)->lpVtbl->CreateDirectory(This,DirectoryType,pName,ppDir)
#define ITRendezvous_CreateDirectoryObject(This,DirectoryObjectType,pName,ppDirectoryObject) (This)->lpVtbl->CreateDirectoryObject(This,DirectoryObjectType,pName,ppDirectoryObject)
#endif
#endif
  HRESULT WINAPI ITRendezvous_get_DefaultDirectories_Proxy(ITRendezvous *This,VARIANT *pVariant);
  void __RPC_STUB ITRendezvous_get_DefaultDirectories_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRendezvous_EnumerateDefaultDirectories_Proxy(ITRendezvous *This,IEnumDirectory **ppEnumDirectory);
  void __RPC_STUB ITRendezvous_EnumerateDefaultDirectories_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRendezvous_CreateDirectory_Proxy(ITRendezvous *This,DIRECTORY_TYPE DirectoryType,BSTR pName,ITDirectory **ppDir);
  void __RPC_STUB ITRendezvous_CreateDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRendezvous_CreateDirectoryObject_Proxy(ITRendezvous *This,DIRECTORY_OBJECT_TYPE DirectoryObjectType,BSTR pName,ITDirectoryObject **ppDirectoryObject);
  void __RPC_STUB ITRendezvous_CreateDirectoryObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define RENDBIND_AUTHENTICATE 0x00000001
#define RENDBIND_DEFAULTDOMAINNAME 0x00000002
#define RENDBIND_DEFAULTUSERNAME 0x00000004
#define RENDBIND_DEFAULTPASSWORD 0x00000008
#define RENDBIND_DEFAULTCREDENTIALS 0x0000000e
#define __RendConstants_MODULE_DEFINED__

  extern RPC_IF_HANDLE __MIDL_itf_rend_0510_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rend_0510_v0_0_s_ifspec;

#ifndef __RENDLib_LIBRARY_DEFINED__
#define __RENDLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_RENDLib;
  EXTERN_C const CLSID CLSID_Rendezvous;
#ifdef __cplusplus
  class Rendezvous;
#endif

#ifndef __RendConstants_MODULE_DEFINED__
#define __RendConstants_MODULE_DEFINED__
  const __LONG32 RENDBIND_AUTHENTICATE = 0x1;
  const __LONG32 RENDBIND_DEFAULTDOMAINNAME = 0x2;
  const __LONG32 RENDBIND_DEFAULTUSERNAME = 0x4;
  const __LONG32 RENDBIND_DEFAULTPASSWORD = 0x8;
  const __LONG32 RENDBIND_DEFAULTCREDENTIALS = 0xe;
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
