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

#ifndef __mdhcp_h__
#define __mdhcp_h__

#ifndef __IMcastScope_FWD_DEFINED__
#define __IMcastScope_FWD_DEFINED__
typedef struct IMcastScope IMcastScope;
#endif

#ifndef __IMcastLeaseInfo_FWD_DEFINED__
#define __IMcastLeaseInfo_FWD_DEFINED__
typedef struct IMcastLeaseInfo IMcastLeaseInfo;
#endif

#ifndef __IEnumMcastScope_FWD_DEFINED__
#define __IEnumMcastScope_FWD_DEFINED__
typedef struct IEnumMcastScope IEnumMcastScope;
#endif

#ifndef __IMcastAddressAllocation_FWD_DEFINED__
#define __IMcastAddressAllocation_FWD_DEFINED__
typedef struct IMcastAddressAllocation IMcastAddressAllocation;
#endif

#ifndef __IMcastScope_FWD_DEFINED__
#define __IMcastScope_FWD_DEFINED__
typedef struct IMcastScope IMcastScope;
#endif

#ifndef __IMcastLeaseInfo_FWD_DEFINED__
#define __IMcastLeaseInfo_FWD_DEFINED__
typedef struct IMcastLeaseInfo IMcastLeaseInfo;
#endif

#ifndef __IEnumMcastScope_FWD_DEFINED__
#define __IEnumMcastScope_FWD_DEFINED__
typedef struct IEnumMcastScope IEnumMcastScope;
#endif

#ifndef __IMcastAddressAllocation_FWD_DEFINED__
#define __IMcastAddressAllocation_FWD_DEFINED__
typedef struct IMcastAddressAllocation IMcastAddressAllocation;
#endif

#ifndef __McastAddressAllocation_FWD_DEFINED__
#define __McastAddressAllocation_FWD_DEFINED__
#ifdef __cplusplus
typedef class McastAddressAllocation McastAddressAllocation;
#else
typedef struct McastAddressAllocation McastAddressAllocation;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "tapi3if.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_mdhcp_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mdhcp_0000_v0_0_s_ifspec;

#ifndef __IMcastScope_INTERFACE_DEFINED__
#define __IMcastScope_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMcastScope;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMcastScope : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ScopeID(__LONG32 *pID) = 0;
    virtual HRESULT WINAPI get_ServerID(__LONG32 *pID) = 0;
    virtual HRESULT WINAPI get_InterfaceID(__LONG32 *pID) = 0;
    virtual HRESULT WINAPI get_ScopeDescription(BSTR *ppDescription) = 0;
    virtual HRESULT WINAPI get_TTL(__LONG32 *pTTL) = 0;
  };
#else
  typedef struct IMcastScopeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMcastScope *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMcastScope *This);
      ULONG (WINAPI *Release)(IMcastScope *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMcastScope *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMcastScope *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMcastScope *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMcastScope *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ScopeID)(IMcastScope *This,__LONG32 *pID);
      HRESULT (WINAPI *get_ServerID)(IMcastScope *This,__LONG32 *pID);
      HRESULT (WINAPI *get_InterfaceID)(IMcastScope *This,__LONG32 *pID);
      HRESULT (WINAPI *get_ScopeDescription)(IMcastScope *This,BSTR *ppDescription);
      HRESULT (WINAPI *get_TTL)(IMcastScope *This,__LONG32 *pTTL);
    END_INTERFACE
  } IMcastScopeVtbl;
  struct IMcastScope {
    CONST_VTBL struct IMcastScopeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMcastScope_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMcastScope_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMcastScope_Release(This) (This)->lpVtbl->Release(This)
#define IMcastScope_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMcastScope_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMcastScope_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMcastScope_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMcastScope_get_ScopeID(This,pID) (This)->lpVtbl->get_ScopeID(This,pID)
#define IMcastScope_get_ServerID(This,pID) (This)->lpVtbl->get_ServerID(This,pID)
#define IMcastScope_get_InterfaceID(This,pID) (This)->lpVtbl->get_InterfaceID(This,pID)
#define IMcastScope_get_ScopeDescription(This,ppDescription) (This)->lpVtbl->get_ScopeDescription(This,ppDescription)
#define IMcastScope_get_TTL(This,pTTL) (This)->lpVtbl->get_TTL(This,pTTL)
#endif
#endif
  HRESULT WINAPI IMcastScope_get_ScopeID_Proxy(IMcastScope *This,__LONG32 *pID);
  void __RPC_STUB IMcastScope_get_ScopeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastScope_get_ServerID_Proxy(IMcastScope *This,__LONG32 *pID);
  void __RPC_STUB IMcastScope_get_ServerID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastScope_get_InterfaceID_Proxy(IMcastScope *This,__LONG32 *pID);
  void __RPC_STUB IMcastScope_get_InterfaceID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastScope_get_ScopeDescription_Proxy(IMcastScope *This,BSTR *ppDescription);
  void __RPC_STUB IMcastScope_get_ScopeDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastScope_get_TTL_Proxy(IMcastScope *This,__LONG32 *pTTL);
  void __RPC_STUB IMcastScope_get_TTL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMcastLeaseInfo_INTERFACE_DEFINED__
#define __IMcastLeaseInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMcastLeaseInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMcastLeaseInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI get_RequestID(BSTR *ppRequestID) = 0;
    virtual HRESULT WINAPI get_LeaseStartTime(DATE *pTime) = 0;
    virtual HRESULT WINAPI put_LeaseStartTime(DATE time) = 0;
    virtual HRESULT WINAPI get_LeaseStopTime(DATE *pTime) = 0;
    virtual HRESULT WINAPI put_LeaseStopTime(DATE time) = 0;
    virtual HRESULT WINAPI get_AddressCount(__LONG32 *pCount) = 0;
    virtual HRESULT WINAPI get_ServerAddress(BSTR *ppAddress) = 0;
    virtual HRESULT WINAPI get_TTL(__LONG32 *pTTL) = 0;
    virtual HRESULT WINAPI get_Addresses(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateAddresses(IEnumBstr **ppEnumAddresses) = 0;
  };
#else
  typedef struct IMcastLeaseInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMcastLeaseInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMcastLeaseInfo *This);
      ULONG (WINAPI *Release)(IMcastLeaseInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMcastLeaseInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMcastLeaseInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMcastLeaseInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMcastLeaseInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_RequestID)(IMcastLeaseInfo *This,BSTR *ppRequestID);
      HRESULT (WINAPI *get_LeaseStartTime)(IMcastLeaseInfo *This,DATE *pTime);
      HRESULT (WINAPI *put_LeaseStartTime)(IMcastLeaseInfo *This,DATE time);
      HRESULT (WINAPI *get_LeaseStopTime)(IMcastLeaseInfo *This,DATE *pTime);
      HRESULT (WINAPI *put_LeaseStopTime)(IMcastLeaseInfo *This,DATE time);
      HRESULT (WINAPI *get_AddressCount)(IMcastLeaseInfo *This,__LONG32 *pCount);
      HRESULT (WINAPI *get_ServerAddress)(IMcastLeaseInfo *This,BSTR *ppAddress);
      HRESULT (WINAPI *get_TTL)(IMcastLeaseInfo *This,__LONG32 *pTTL);
      HRESULT (WINAPI *get_Addresses)(IMcastLeaseInfo *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateAddresses)(IMcastLeaseInfo *This,IEnumBstr **ppEnumAddresses);
    END_INTERFACE
  } IMcastLeaseInfoVtbl;
  struct IMcastLeaseInfo {
    CONST_VTBL struct IMcastLeaseInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMcastLeaseInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMcastLeaseInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMcastLeaseInfo_Release(This) (This)->lpVtbl->Release(This)
#define IMcastLeaseInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMcastLeaseInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMcastLeaseInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMcastLeaseInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMcastLeaseInfo_get_RequestID(This,ppRequestID) (This)->lpVtbl->get_RequestID(This,ppRequestID)
#define IMcastLeaseInfo_get_LeaseStartTime(This,pTime) (This)->lpVtbl->get_LeaseStartTime(This,pTime)
#define IMcastLeaseInfo_put_LeaseStartTime(This,time) (This)->lpVtbl->put_LeaseStartTime(This,time)
#define IMcastLeaseInfo_get_LeaseStopTime(This,pTime) (This)->lpVtbl->get_LeaseStopTime(This,pTime)
#define IMcastLeaseInfo_put_LeaseStopTime(This,time) (This)->lpVtbl->put_LeaseStopTime(This,time)
#define IMcastLeaseInfo_get_AddressCount(This,pCount) (This)->lpVtbl->get_AddressCount(This,pCount)
#define IMcastLeaseInfo_get_ServerAddress(This,ppAddress) (This)->lpVtbl->get_ServerAddress(This,ppAddress)
#define IMcastLeaseInfo_get_TTL(This,pTTL) (This)->lpVtbl->get_TTL(This,pTTL)
#define IMcastLeaseInfo_get_Addresses(This,pVariant) (This)->lpVtbl->get_Addresses(This,pVariant)
#define IMcastLeaseInfo_EnumerateAddresses(This,ppEnumAddresses) (This)->lpVtbl->EnumerateAddresses(This,ppEnumAddresses)
#endif
#endif
  HRESULT WINAPI IMcastLeaseInfo_get_RequestID_Proxy(IMcastLeaseInfo *This,BSTR *ppRequestID);
  void __RPC_STUB IMcastLeaseInfo_get_RequestID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_get_LeaseStartTime_Proxy(IMcastLeaseInfo *This,DATE *pTime);
  void __RPC_STUB IMcastLeaseInfo_get_LeaseStartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_put_LeaseStartTime_Proxy(IMcastLeaseInfo *This,DATE time);
  void __RPC_STUB IMcastLeaseInfo_put_LeaseStartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_get_LeaseStopTime_Proxy(IMcastLeaseInfo *This,DATE *pTime);
  void __RPC_STUB IMcastLeaseInfo_get_LeaseStopTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_put_LeaseStopTime_Proxy(IMcastLeaseInfo *This,DATE time);
  void __RPC_STUB IMcastLeaseInfo_put_LeaseStopTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_get_AddressCount_Proxy(IMcastLeaseInfo *This,__LONG32 *pCount);
  void __RPC_STUB IMcastLeaseInfo_get_AddressCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_get_ServerAddress_Proxy(IMcastLeaseInfo *This,BSTR *ppAddress);
  void __RPC_STUB IMcastLeaseInfo_get_ServerAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_get_TTL_Proxy(IMcastLeaseInfo *This,__LONG32 *pTTL);
  void __RPC_STUB IMcastLeaseInfo_get_TTL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_get_Addresses_Proxy(IMcastLeaseInfo *This,VARIANT *pVariant);
  void __RPC_STUB IMcastLeaseInfo_get_Addresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastLeaseInfo_EnumerateAddresses_Proxy(IMcastLeaseInfo *This,IEnumBstr **ppEnumAddresses);
  void __RPC_STUB IMcastLeaseInfo_EnumerateAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumMcastScope_INTERFACE_DEFINED__
#define __IEnumMcastScope_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumMcastScope;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumMcastScope : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IMcastScope **ppScopes,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumMcastScope **ppEnum) = 0;
  };
#else
  typedef struct IEnumMcastScopeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumMcastScope *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumMcastScope *This);
      ULONG (WINAPI *Release)(IEnumMcastScope *This);
      HRESULT (WINAPI *Next)(IEnumMcastScope *This,ULONG celt,IMcastScope **ppScopes,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumMcastScope *This);
      HRESULT (WINAPI *Skip)(IEnumMcastScope *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumMcastScope *This,IEnumMcastScope **ppEnum);
    END_INTERFACE
  } IEnumMcastScopeVtbl;
  struct IEnumMcastScope {
    CONST_VTBL struct IEnumMcastScopeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumMcastScope_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumMcastScope_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumMcastScope_Release(This) (This)->lpVtbl->Release(This)
#define IEnumMcastScope_Next(This,celt,ppScopes,pceltFetched) (This)->lpVtbl->Next(This,celt,ppScopes,pceltFetched)
#define IEnumMcastScope_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumMcastScope_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumMcastScope_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumMcastScope_Next_Proxy(IEnumMcastScope *This,ULONG celt,IMcastScope **ppScopes,ULONG *pceltFetched);
  void __RPC_STUB IEnumMcastScope_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMcastScope_Reset_Proxy(IEnumMcastScope *This);
  void __RPC_STUB IEnumMcastScope_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMcastScope_Skip_Proxy(IEnumMcastScope *This,ULONG celt);
  void __RPC_STUB IEnumMcastScope_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMcastScope_Clone_Proxy(IEnumMcastScope *This,IEnumMcastScope **ppEnum);
  void __RPC_STUB IEnumMcastScope_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMcastAddressAllocation_INTERFACE_DEFINED__
#define __IMcastAddressAllocation_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMcastAddressAllocation;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMcastAddressAllocation : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Scopes(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateScopes(IEnumMcastScope **ppEnumMcastScope) = 0;
    virtual HRESULT WINAPI RequestAddress(IMcastScope *pScope,DATE LeaseStartTime,DATE LeaseStopTime,__LONG32 NumAddresses,IMcastLeaseInfo **ppLeaseResponse) = 0;
    virtual HRESULT WINAPI RenewAddress(__LONG32 lReserved,IMcastLeaseInfo *pRenewRequest,IMcastLeaseInfo **ppRenewResponse) = 0;
    virtual HRESULT WINAPI ReleaseAddress(IMcastLeaseInfo *pReleaseRequest) = 0;
    virtual HRESULT WINAPI CreateLeaseInfo(DATE LeaseStartTime,DATE LeaseStopTime,DWORD dwNumAddresses,LPWSTR *ppAddresses,LPWSTR pRequestID,LPWSTR pServerAddress,IMcastLeaseInfo **ppReleaseRequest) = 0;
    virtual HRESULT WINAPI CreateLeaseInfoFromVariant(DATE LeaseStartTime,DATE LeaseStopTime,VARIANT vAddresses,BSTR pRequestID,BSTR pServerAddress,IMcastLeaseInfo **ppReleaseRequest) = 0;
  };
#else
  typedef struct IMcastAddressAllocationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMcastAddressAllocation *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMcastAddressAllocation *This);
      ULONG (WINAPI *Release)(IMcastAddressAllocation *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMcastAddressAllocation *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMcastAddressAllocation *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMcastAddressAllocation *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMcastAddressAllocation *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Scopes)(IMcastAddressAllocation *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateScopes)(IMcastAddressAllocation *This,IEnumMcastScope **ppEnumMcastScope);
      HRESULT (WINAPI *RequestAddress)(IMcastAddressAllocation *This,IMcastScope *pScope,DATE LeaseStartTime,DATE LeaseStopTime,__LONG32 NumAddresses,IMcastLeaseInfo **ppLeaseResponse);
      HRESULT (WINAPI *RenewAddress)(IMcastAddressAllocation *This,__LONG32 lReserved,IMcastLeaseInfo *pRenewRequest,IMcastLeaseInfo **ppRenewResponse);
      HRESULT (WINAPI *ReleaseAddress)(IMcastAddressAllocation *This,IMcastLeaseInfo *pReleaseRequest);
      HRESULT (WINAPI *CreateLeaseInfo)(IMcastAddressAllocation *This,DATE LeaseStartTime,DATE LeaseStopTime,DWORD dwNumAddresses,LPWSTR *ppAddresses,LPWSTR pRequestID,LPWSTR pServerAddress,IMcastLeaseInfo **ppReleaseRequest);
      HRESULT (WINAPI *CreateLeaseInfoFromVariant)(IMcastAddressAllocation *This,DATE LeaseStartTime,DATE LeaseStopTime,VARIANT vAddresses,BSTR pRequestID,BSTR pServerAddress,IMcastLeaseInfo **ppReleaseRequest);
    END_INTERFACE
  } IMcastAddressAllocationVtbl;
  struct IMcastAddressAllocation {
    CONST_VTBL struct IMcastAddressAllocationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMcastAddressAllocation_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMcastAddressAllocation_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMcastAddressAllocation_Release(This) (This)->lpVtbl->Release(This)
#define IMcastAddressAllocation_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMcastAddressAllocation_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMcastAddressAllocation_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMcastAddressAllocation_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMcastAddressAllocation_get_Scopes(This,pVariant) (This)->lpVtbl->get_Scopes(This,pVariant)
#define IMcastAddressAllocation_EnumerateScopes(This,ppEnumMcastScope) (This)->lpVtbl->EnumerateScopes(This,ppEnumMcastScope)
#define IMcastAddressAllocation_RequestAddress(This,pScope,LeaseStartTime,LeaseStopTime,NumAddresses,ppLeaseResponse) (This)->lpVtbl->RequestAddress(This,pScope,LeaseStartTime,LeaseStopTime,NumAddresses,ppLeaseResponse)
#define IMcastAddressAllocation_RenewAddress(This,lReserved,pRenewRequest,ppRenewResponse) (This)->lpVtbl->RenewAddress(This,lReserved,pRenewRequest,ppRenewResponse)
#define IMcastAddressAllocation_ReleaseAddress(This,pReleaseRequest) (This)->lpVtbl->ReleaseAddress(This,pReleaseRequest)
#define IMcastAddressAllocation_CreateLeaseInfo(This,LeaseStartTime,LeaseStopTime,dwNumAddresses,ppAddresses,pRequestID,pServerAddress,ppReleaseRequest) (This)->lpVtbl->CreateLeaseInfo(This,LeaseStartTime,LeaseStopTime,dwNumAddresses,ppAddresses,pRequestID,pServerAddress,ppReleaseRequest)
#define IMcastAddressAllocation_CreateLeaseInfoFromVariant(This,LeaseStartTime,LeaseStopTime,vAddresses,pRequestID,pServerAddress,ppReleaseRequest) (This)->lpVtbl->CreateLeaseInfoFromVariant(This,LeaseStartTime,LeaseStopTime,vAddresses,pRequestID,pServerAddress,ppReleaseRequest)
#endif
#endif
  HRESULT WINAPI IMcastAddressAllocation_get_Scopes_Proxy(IMcastAddressAllocation *This,VARIANT *pVariant);
  void __RPC_STUB IMcastAddressAllocation_get_Scopes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastAddressAllocation_EnumerateScopes_Proxy(IMcastAddressAllocation *This,IEnumMcastScope **ppEnumMcastScope);
  void __RPC_STUB IMcastAddressAllocation_EnumerateScopes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastAddressAllocation_RequestAddress_Proxy(IMcastAddressAllocation *This,IMcastScope *pScope,DATE LeaseStartTime,DATE LeaseStopTime,__LONG32 NumAddresses,IMcastLeaseInfo **ppLeaseResponse);
  void __RPC_STUB IMcastAddressAllocation_RequestAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastAddressAllocation_RenewAddress_Proxy(IMcastAddressAllocation *This,__LONG32 lReserved,IMcastLeaseInfo *pRenewRequest,IMcastLeaseInfo **ppRenewResponse);
  void __RPC_STUB IMcastAddressAllocation_RenewAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastAddressAllocation_ReleaseAddress_Proxy(IMcastAddressAllocation *This,IMcastLeaseInfo *pReleaseRequest);
  void __RPC_STUB IMcastAddressAllocation_ReleaseAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastAddressAllocation_CreateLeaseInfo_Proxy(IMcastAddressAllocation *This,DATE LeaseStartTime,DATE LeaseStopTime,DWORD dwNumAddresses,LPWSTR *ppAddresses,LPWSTR pRequestID,LPWSTR pServerAddress,IMcastLeaseInfo **ppReleaseRequest);
  void __RPC_STUB IMcastAddressAllocation_CreateLeaseInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMcastAddressAllocation_CreateLeaseInfoFromVariant_Proxy(IMcastAddressAllocation *This,DATE LeaseStartTime,DATE LeaseStopTime,VARIANT vAddresses,BSTR pRequestID,BSTR pServerAddress,IMcastLeaseInfo **ppReleaseRequest);
  void __RPC_STUB IMcastAddressAllocation_CreateLeaseInfoFromVariant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __McastLib_LIBRARY_DEFINED__
#define __McastLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_McastLib;
  EXTERN_C const CLSID CLSID_McastAddressAllocation;
#ifdef __cplusplus
  class McastAddressAllocation;
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
