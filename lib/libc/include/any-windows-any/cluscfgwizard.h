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

#ifndef __cluscfgwizard_h__
#define __cluscfgwizard_h__

#ifndef __IClusCfgCreateClusterWizard_FWD_DEFINED__
#define __IClusCfgCreateClusterWizard_FWD_DEFINED__
typedef struct IClusCfgCreateClusterWizard IClusCfgCreateClusterWizard;
#endif

#ifndef __IClusCfgAddNodesWizard_FWD_DEFINED__
#define __IClusCfgAddNodesWizard_FWD_DEFINED__
typedef struct IClusCfgAddNodesWizard IClusCfgAddNodesWizard;
#endif

#ifndef __ClusCfgCreateClusterWizard_FWD_DEFINED__
#define __ClusCfgCreateClusterWizard_FWD_DEFINED__

#ifdef __cplusplus
typedef class ClusCfgCreateClusterWizard ClusCfgCreateClusterWizard;
#else
typedef struct ClusCfgCreateClusterWizard ClusCfgCreateClusterWizard;
#endif
#endif

#ifndef __ClusCfgAddNodesWizard_FWD_DEFINED__
#define __ClusCfgAddNodesWizard_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusCfgAddNodesWizard ClusCfgAddNodesWizard;
#else
typedef struct ClusCfgAddNodesWizard ClusCfgAddNodesWizard;
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

#ifndef __ClusCfgWizard_LIBRARY_DEFINED__
#define __ClusCfgWizard_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_ClusCfgWizard;
#ifndef __IClusCfgCreateClusterWizard_INTERFACE_DEFINED__
#define __IClusCfgCreateClusterWizard_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgCreateClusterWizard;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgCreateClusterWizard : public IDispatch {
  public:
    virtual HRESULT WINAPI put_ClusterName(BSTR bstrClusterNameIn) = 0;
    virtual HRESULT WINAPI get_ClusterName(BSTR *pbstrClusterNameOut) = 0;
    virtual HRESULT WINAPI put_ServiceAccountName(BSTR bstrServiceAccountNameIn) = 0;
    virtual HRESULT WINAPI get_ServiceAccountName(BSTR *pbstrServiceAccountNameOut) = 0;
    virtual HRESULT WINAPI put_ServiceAccountDomain(BSTR bstrServiceAccountDomainIn) = 0;
    virtual HRESULT WINAPI get_ServiceAccountDomain(BSTR *pbstrServiceAccountDomainOut) = 0;
    virtual HRESULT WINAPI put_ServiceAccountPassword(BSTR bstrPasswordIn) = 0;
    virtual HRESULT WINAPI put_ClusterIPAddress(BSTR bstrClusterIPAddressIn) = 0;
    virtual HRESULT WINAPI get_ClusterIPAddress(BSTR *pbstrClusterIPAddressOut) = 0;
    virtual HRESULT WINAPI get_ClusterIPSubnet(BSTR *pbstrClusterIPSubnetOut) = 0;
    virtual HRESULT WINAPI get_ClusterIPAddressNetwork(BSTR *pbstrClusterNetworkNameOut) = 0;
    virtual HRESULT WINAPI put_FirstNodeInCluster(BSTR bstrFirstNodeInClusterIn) = 0;
    virtual HRESULT WINAPI get_FirstNodeInCluster(BSTR *pbstrFirstNodeInClusterOut) = 0;
    virtual HRESULT WINAPI put_MinimumConfiguration(VARIANT_BOOL fMinConfigIn) = 0;
    virtual HRESULT WINAPI get_MinimumConfiguration(VARIANT_BOOL *pfMinConfigOut) = 0;
    virtual HRESULT WINAPI ShowWizard(__LONG32 lParentWindowHandleIn,VARIANT_BOOL *pfCompletedOut) = 0;
  };
#else
  typedef struct IClusCfgCreateClusterWizardVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgCreateClusterWizard *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgCreateClusterWizard *This);
      ULONG (WINAPI *Release)(IClusCfgCreateClusterWizard *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IClusCfgCreateClusterWizard *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IClusCfgCreateClusterWizard *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IClusCfgCreateClusterWizard *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IClusCfgCreateClusterWizard *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_ClusterName)(IClusCfgCreateClusterWizard *This,BSTR bstrClusterNameIn);
      HRESULT (WINAPI *get_ClusterName)(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterNameOut);
      HRESULT (WINAPI *put_ServiceAccountName)(IClusCfgCreateClusterWizard *This,BSTR bstrServiceAccountNameIn);
      HRESULT (WINAPI *get_ServiceAccountName)(IClusCfgCreateClusterWizard *This,BSTR *pbstrServiceAccountNameOut);
      HRESULT (WINAPI *put_ServiceAccountDomain)(IClusCfgCreateClusterWizard *This,BSTR bstrServiceAccountDomainIn);
      HRESULT (WINAPI *get_ServiceAccountDomain)(IClusCfgCreateClusterWizard *This,BSTR *pbstrServiceAccountDomainOut);
      HRESULT (WINAPI *put_ServiceAccountPassword)(IClusCfgCreateClusterWizard *This,BSTR bstrPasswordIn);
      HRESULT (WINAPI *put_ClusterIPAddress)(IClusCfgCreateClusterWizard *This,BSTR bstrClusterIPAddressIn);
      HRESULT (WINAPI *get_ClusterIPAddress)(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterIPAddressOut);
      HRESULT (WINAPI *get_ClusterIPSubnet)(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterIPSubnetOut);
      HRESULT (WINAPI *get_ClusterIPAddressNetwork)(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterNetworkNameOut);
      HRESULT (WINAPI *put_FirstNodeInCluster)(IClusCfgCreateClusterWizard *This,BSTR bstrFirstNodeInClusterIn);
      HRESULT (WINAPI *get_FirstNodeInCluster)(IClusCfgCreateClusterWizard *This,BSTR *pbstrFirstNodeInClusterOut);
      HRESULT (WINAPI *put_MinimumConfiguration)(IClusCfgCreateClusterWizard *This,VARIANT_BOOL fMinConfigIn);
      HRESULT (WINAPI *get_MinimumConfiguration)(IClusCfgCreateClusterWizard *This,VARIANT_BOOL *pfMinConfigOut);
      HRESULT (WINAPI *ShowWizard)(IClusCfgCreateClusterWizard *This,__LONG32 lParentWindowHandleIn,VARIANT_BOOL *pfCompletedOut);
    END_INTERFACE
  } IClusCfgCreateClusterWizardVtbl;
  struct IClusCfgCreateClusterWizard {
    CONST_VTBL struct IClusCfgCreateClusterWizardVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgCreateClusterWizard_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgCreateClusterWizard_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgCreateClusterWizard_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgCreateClusterWizard_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IClusCfgCreateClusterWizard_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IClusCfgCreateClusterWizard_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IClusCfgCreateClusterWizard_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IClusCfgCreateClusterWizard_put_ClusterName(This,bstrClusterNameIn) (This)->lpVtbl->put_ClusterName(This,bstrClusterNameIn)
#define IClusCfgCreateClusterWizard_get_ClusterName(This,pbstrClusterNameOut) (This)->lpVtbl->get_ClusterName(This,pbstrClusterNameOut)
#define IClusCfgCreateClusterWizard_put_ServiceAccountName(This,bstrServiceAccountNameIn) (This)->lpVtbl->put_ServiceAccountName(This,bstrServiceAccountNameIn)
#define IClusCfgCreateClusterWizard_get_ServiceAccountName(This,pbstrServiceAccountNameOut) (This)->lpVtbl->get_ServiceAccountName(This,pbstrServiceAccountNameOut)
#define IClusCfgCreateClusterWizard_put_ServiceAccountDomain(This,bstrServiceAccountDomainIn) (This)->lpVtbl->put_ServiceAccountDomain(This,bstrServiceAccountDomainIn)
#define IClusCfgCreateClusterWizard_get_ServiceAccountDomain(This,pbstrServiceAccountDomainOut) (This)->lpVtbl->get_ServiceAccountDomain(This,pbstrServiceAccountDomainOut)
#define IClusCfgCreateClusterWizard_put_ServiceAccountPassword(This,bstrPasswordIn) (This)->lpVtbl->put_ServiceAccountPassword(This,bstrPasswordIn)
#define IClusCfgCreateClusterWizard_put_ClusterIPAddress(This,bstrClusterIPAddressIn) (This)->lpVtbl->put_ClusterIPAddress(This,bstrClusterIPAddressIn)
#define IClusCfgCreateClusterWizard_get_ClusterIPAddress(This,pbstrClusterIPAddressOut) (This)->lpVtbl->get_ClusterIPAddress(This,pbstrClusterIPAddressOut)
#define IClusCfgCreateClusterWizard_get_ClusterIPSubnet(This,pbstrClusterIPSubnetOut) (This)->lpVtbl->get_ClusterIPSubnet(This,pbstrClusterIPSubnetOut)
#define IClusCfgCreateClusterWizard_get_ClusterIPAddressNetwork(This,pbstrClusterNetworkNameOut) (This)->lpVtbl->get_ClusterIPAddressNetwork(This,pbstrClusterNetworkNameOut)
#define IClusCfgCreateClusterWizard_put_FirstNodeInCluster(This,bstrFirstNodeInClusterIn) (This)->lpVtbl->put_FirstNodeInCluster(This,bstrFirstNodeInClusterIn)
#define IClusCfgCreateClusterWizard_get_FirstNodeInCluster(This,pbstrFirstNodeInClusterOut) (This)->lpVtbl->get_FirstNodeInCluster(This,pbstrFirstNodeInClusterOut)
#define IClusCfgCreateClusterWizard_put_MinimumConfiguration(This,fMinConfigIn) (This)->lpVtbl->put_MinimumConfiguration(This,fMinConfigIn)
#define IClusCfgCreateClusterWizard_get_MinimumConfiguration(This,pfMinConfigOut) (This)->lpVtbl->get_MinimumConfiguration(This,pfMinConfigOut)
#define IClusCfgCreateClusterWizard_ShowWizard(This,lParentWindowHandleIn,pfCompletedOut) (This)->lpVtbl->ShowWizard(This,lParentWindowHandleIn,pfCompletedOut)
#endif
#endif
  HRESULT WINAPI IClusCfgCreateClusterWizard_put_ClusterName_Proxy(IClusCfgCreateClusterWizard *This,BSTR bstrClusterNameIn);
  void __RPC_STUB IClusCfgCreateClusterWizard_put_ClusterName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_ClusterName_Proxy(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterNameOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_ClusterName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_put_ServiceAccountName_Proxy(IClusCfgCreateClusterWizard *This,BSTR bstrServiceAccountNameIn);
  void __RPC_STUB IClusCfgCreateClusterWizard_put_ServiceAccountName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_ServiceAccountName_Proxy(IClusCfgCreateClusterWizard *This,BSTR *pbstrServiceAccountNameOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_ServiceAccountName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_put_ServiceAccountDomain_Proxy(IClusCfgCreateClusterWizard *This,BSTR bstrServiceAccountDomainIn);
  void __RPC_STUB IClusCfgCreateClusterWizard_put_ServiceAccountDomain_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_ServiceAccountDomain_Proxy(IClusCfgCreateClusterWizard *This,BSTR *pbstrServiceAccountDomainOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_ServiceAccountDomain_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_put_ServiceAccountPassword_Proxy(IClusCfgCreateClusterWizard *This,BSTR bstrPasswordIn);
  void __RPC_STUB IClusCfgCreateClusterWizard_put_ServiceAccountPassword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_put_ClusterIPAddress_Proxy(IClusCfgCreateClusterWizard *This,BSTR bstrClusterIPAddressIn);
  void __RPC_STUB IClusCfgCreateClusterWizard_put_ClusterIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_ClusterIPAddress_Proxy(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterIPAddressOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_ClusterIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_ClusterIPSubnet_Proxy(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterIPSubnetOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_ClusterIPSubnet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_ClusterIPAddressNetwork_Proxy(IClusCfgCreateClusterWizard *This,BSTR *pbstrClusterNetworkNameOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_ClusterIPAddressNetwork_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_put_FirstNodeInCluster_Proxy(IClusCfgCreateClusterWizard *This,BSTR bstrFirstNodeInClusterIn);
  void __RPC_STUB IClusCfgCreateClusterWizard_put_FirstNodeInCluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_FirstNodeInCluster_Proxy(IClusCfgCreateClusterWizard *This,BSTR *pbstrFirstNodeInClusterOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_FirstNodeInCluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_put_MinimumConfiguration_Proxy(IClusCfgCreateClusterWizard *This,VARIANT_BOOL fMinConfigIn);
  void __RPC_STUB IClusCfgCreateClusterWizard_put_MinimumConfiguration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_get_MinimumConfiguration_Proxy(IClusCfgCreateClusterWizard *This,VARIANT_BOOL *pfMinConfigOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_get_MinimumConfiguration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCreateClusterWizard_ShowWizard_Proxy(IClusCfgCreateClusterWizard *This,__LONG32 lParentWindowHandleIn,VARIANT_BOOL *pfCompletedOut);
  void __RPC_STUB IClusCfgCreateClusterWizard_ShowWizard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgAddNodesWizard_INTERFACE_DEFINED__
#define __IClusCfgAddNodesWizard_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgAddNodesWizard;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgAddNodesWizard : public IDispatch {
  public:
    virtual HRESULT WINAPI put_ClusterName(BSTR bstrClusterNameIn) = 0;
    virtual HRESULT WINAPI get_ClusterName(BSTR *pbstrClusterNameOut) = 0;
    virtual HRESULT WINAPI put_ServiceAccountPassword(BSTR bstrPasswordIn) = 0;
    virtual HRESULT WINAPI put_MinimumConfiguration(VARIANT_BOOL fMinConfigIn) = 0;
    virtual HRESULT WINAPI get_MinimumConfiguration(VARIANT_BOOL *pfMinConfigOut) = 0;
    virtual HRESULT WINAPI AddNodeToList(BSTR bstrNodeNameIn) = 0;
    virtual HRESULT WINAPI RemoveNodeFromList(BSTR bstrNodeNameIn) = 0;
    virtual HRESULT WINAPI ClearNodeList(void) = 0;
    virtual HRESULT WINAPI ShowWizard(__LONG32 lParentWindowHandleIn,VARIANT_BOOL *pfCompletedOut) = 0;
  };
#else
  typedef struct IClusCfgAddNodesWizardVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgAddNodesWizard *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgAddNodesWizard *This);
      ULONG (WINAPI *Release)(IClusCfgAddNodesWizard *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IClusCfgAddNodesWizard *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IClusCfgAddNodesWizard *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IClusCfgAddNodesWizard *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IClusCfgAddNodesWizard *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_ClusterName)(IClusCfgAddNodesWizard *This,BSTR bstrClusterNameIn);
      HRESULT (WINAPI *get_ClusterName)(IClusCfgAddNodesWizard *This,BSTR *pbstrClusterNameOut);
      HRESULT (WINAPI *put_ServiceAccountPassword)(IClusCfgAddNodesWizard *This,BSTR bstrPasswordIn);
      HRESULT (WINAPI *put_MinimumConfiguration)(IClusCfgAddNodesWizard *This,VARIANT_BOOL fMinConfigIn);
      HRESULT (WINAPI *get_MinimumConfiguration)(IClusCfgAddNodesWizard *This,VARIANT_BOOL *pfMinConfigOut);
      HRESULT (WINAPI *AddNodeToList)(IClusCfgAddNodesWizard *This,BSTR bstrNodeNameIn);
      HRESULT (WINAPI *RemoveNodeFromList)(IClusCfgAddNodesWizard *This,BSTR bstrNodeNameIn);
      HRESULT (WINAPI *ClearNodeList)(IClusCfgAddNodesWizard *This);
      HRESULT (WINAPI *ShowWizard)(IClusCfgAddNodesWizard *This,__LONG32 lParentWindowHandleIn,VARIANT_BOOL *pfCompletedOut);
    END_INTERFACE
  } IClusCfgAddNodesWizardVtbl;
  struct IClusCfgAddNodesWizard {
    CONST_VTBL struct IClusCfgAddNodesWizardVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgAddNodesWizard_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgAddNodesWizard_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgAddNodesWizard_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgAddNodesWizard_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IClusCfgAddNodesWizard_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IClusCfgAddNodesWizard_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IClusCfgAddNodesWizard_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IClusCfgAddNodesWizard_put_ClusterName(This,bstrClusterNameIn) (This)->lpVtbl->put_ClusterName(This,bstrClusterNameIn)
#define IClusCfgAddNodesWizard_get_ClusterName(This,pbstrClusterNameOut) (This)->lpVtbl->get_ClusterName(This,pbstrClusterNameOut)
#define IClusCfgAddNodesWizard_put_ServiceAccountPassword(This,bstrPasswordIn) (This)->lpVtbl->put_ServiceAccountPassword(This,bstrPasswordIn)
#define IClusCfgAddNodesWizard_put_MinimumConfiguration(This,fMinConfigIn) (This)->lpVtbl->put_MinimumConfiguration(This,fMinConfigIn)
#define IClusCfgAddNodesWizard_get_MinimumConfiguration(This,pfMinConfigOut) (This)->lpVtbl->get_MinimumConfiguration(This,pfMinConfigOut)
#define IClusCfgAddNodesWizard_AddNodeToList(This,bstrNodeNameIn) (This)->lpVtbl->AddNodeToList(This,bstrNodeNameIn)
#define IClusCfgAddNodesWizard_RemoveNodeFromList(This,bstrNodeNameIn) (This)->lpVtbl->RemoveNodeFromList(This,bstrNodeNameIn)
#define IClusCfgAddNodesWizard_ClearNodeList(This) (This)->lpVtbl->ClearNodeList(This)
#define IClusCfgAddNodesWizard_ShowWizard(This,lParentWindowHandleIn,pfCompletedOut) (This)->lpVtbl->ShowWizard(This,lParentWindowHandleIn,pfCompletedOut)
#endif
#endif
  HRESULT WINAPI IClusCfgAddNodesWizard_put_ClusterName_Proxy(IClusCfgAddNodesWizard *This,BSTR bstrClusterNameIn);
  void __RPC_STUB IClusCfgAddNodesWizard_put_ClusterName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_get_ClusterName_Proxy(IClusCfgAddNodesWizard *This,BSTR *pbstrClusterNameOut);
  void __RPC_STUB IClusCfgAddNodesWizard_get_ClusterName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_put_ServiceAccountPassword_Proxy(IClusCfgAddNodesWizard *This,BSTR bstrPasswordIn);
  void __RPC_STUB IClusCfgAddNodesWizard_put_ServiceAccountPassword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_put_MinimumConfiguration_Proxy(IClusCfgAddNodesWizard *This,VARIANT_BOOL fMinConfigIn);
  void __RPC_STUB IClusCfgAddNodesWizard_put_MinimumConfiguration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_get_MinimumConfiguration_Proxy(IClusCfgAddNodesWizard *This,VARIANT_BOOL *pfMinConfigOut);
  void __RPC_STUB IClusCfgAddNodesWizard_get_MinimumConfiguration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_AddNodeToList_Proxy(IClusCfgAddNodesWizard *This,BSTR bstrNodeNameIn);
  void __RPC_STUB IClusCfgAddNodesWizard_AddNodeToList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_RemoveNodeFromList_Proxy(IClusCfgAddNodesWizard *This,BSTR bstrNodeNameIn);
  void __RPC_STUB IClusCfgAddNodesWizard_RemoveNodeFromList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_ClearNodeList_Proxy(IClusCfgAddNodesWizard *This);
  void __RPC_STUB IClusCfgAddNodesWizard_ClearNodeList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgAddNodesWizard_ShowWizard_Proxy(IClusCfgAddNodesWizard *This,__LONG32 lParentWindowHandleIn,VARIANT_BOOL *pfCompletedOut);
  void __RPC_STUB IClusCfgAddNodesWizard_ShowWizard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_ClusCfgCreateClusterWizard;
#ifdef __cplusplus
  class ClusCfgCreateClusterWizard;
#endif
  EXTERN_C const CLSID CLSID_ClusCfgAddNodesWizard;
#ifdef __cplusplus
  class ClusCfgAddNodesWizard;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
