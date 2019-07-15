/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __CDOEXM_h__
#define __CDOEXM_h__

#ifndef __IDistributionList_FWD_DEFINED__
#define __IDistributionList_FWD_DEFINED__
typedef struct IDistributionList IDistributionList;
#endif

#ifndef __IMailRecipient_FWD_DEFINED__
#define __IMailRecipient_FWD_DEFINED__
typedef struct IMailRecipient IMailRecipient;
#endif

#ifndef __IMailboxStore_FWD_DEFINED__
#define __IMailboxStore_FWD_DEFINED__
typedef struct IMailboxStore IMailboxStore;
#endif

#ifndef __MailGroup_FWD_DEFINED__
#define __MailGroup_FWD_DEFINED__
#ifdef __cplusplus
typedef class MailGroup MailGroup;
#else
typedef struct MailGroup MailGroup;
#endif
#endif

#ifndef __MailRecipient_FWD_DEFINED__
#define __MailRecipient_FWD_DEFINED__
#ifdef __cplusplus
typedef class MailRecipient MailRecipient;
#else
typedef struct MailRecipient MailRecipient;
#endif
#endif

#ifndef __Mailbox_FWD_DEFINED__
#define __Mailbox_FWD_DEFINED__
#ifdef __cplusplus
typedef class Mailbox Mailbox;
#else
typedef struct Mailbox Mailbox;
#endif
#endif

#ifndef __FolderAdmin_FWD_DEFINED__
#define __FolderAdmin_FWD_DEFINED__
#ifdef __cplusplus
typedef class FolderAdmin FolderAdmin;
#else
typedef struct FolderAdmin FolderAdmin;
#endif
#endif

#ifndef __ExchangeServer_FWD_DEFINED__
#define __ExchangeServer_FWD_DEFINED__
#ifdef __cplusplus
typedef class ExchangeServer ExchangeServer;
#else
typedef struct ExchangeServer ExchangeServer;
#endif
#endif

#ifndef __FolderTree_FWD_DEFINED__
#define __FolderTree_FWD_DEFINED__

#ifdef __cplusplus
typedef class FolderTree FolderTree;
#else
typedef struct FolderTree FolderTree;
#endif
#endif

#ifndef __PublicStoreDB_FWD_DEFINED__
#define __PublicStoreDB_FWD_DEFINED__
#ifdef __cplusplus
typedef class PublicStoreDB PublicStoreDB;
#else
typedef struct PublicStoreDB PublicStoreDB;
#endif
#endif

#ifndef __MailboxStoreDB_FWD_DEFINED__
#define __MailboxStoreDB_FWD_DEFINED__
#ifdef __cplusplus
typedef class MailboxStoreDB MailboxStoreDB;
#else
typedef struct MailboxStoreDB MailboxStoreDB;
#endif
#endif

#ifndef __StorageGroup_FWD_DEFINED__
#define __StorageGroup_FWD_DEFINED__
#ifdef __cplusplus
typedef class StorageGroup StorageGroup;
#else
typedef struct StorageGroup StorageGroup;
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

#ifndef NO_CDOEX_H
#define CDO_NO_NAMESPACE
#include "cdoex.h"
#endif
#include "emostore.h"

  typedef enum CDOEXMRestrictedAddressType {
    cdoexmAccept = 0,cdoexmReject = 0x1
  } CDOEXMRestrictedAddressType;

  typedef enum CDOEXMDeliverAndRedirect {
    cdoexmRecipientOrForward = 0,cdoexmDeliverToBoth = 0x1
  } CDOEXMDeliverAndRedirect;

  extern RPC_IF_HANDLE __MIDL_itf_CDOEXM_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_CDOEXM_0000_v0_0_s_ifspec;

#ifndef __CDOEXM_LIBRARY_DEFINED__
#define __CDOEXM_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_CDOEXM;
#ifndef __IDistributionList_INTERFACE_DEFINED__
#define __IDistributionList_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDistributionList;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDistributionList : public IDispatch {
  public:
    virtual HRESULT WINAPI get_HideDLMembership(VARIANT_BOOL *pHideDLMembership) = 0;
    virtual HRESULT WINAPI put_HideDLMembership(VARIANT_BOOL varHideDLMembership) = 0;
  };
#else
  typedef struct IDistributionListVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDistributionList *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDistributionList *This);
      ULONG (WINAPI *Release)(IDistributionList *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDistributionList *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDistributionList *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDistributionList *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDistributionList *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_HideDLMembership)(IDistributionList *This,VARIANT_BOOL *pHideDLMembership);
      HRESULT (WINAPI *put_HideDLMembership)(IDistributionList *This,VARIANT_BOOL varHideDLMembership);
    END_INTERFACE
  } IDistributionListVtbl;
  struct IDistributionList {
    CONST_VTBL struct IDistributionListVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDistributionList_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDistributionList_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDistributionList_Release(This) (This)->lpVtbl->Release(This)
#define IDistributionList_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDistributionList_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDistributionList_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDistributionList_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDistributionList_get_HideDLMembership(This,pHideDLMembership) (This)->lpVtbl->get_HideDLMembership(This,pHideDLMembership)
#define IDistributionList_put_HideDLMembership(This,varHideDLMembership) (This)->lpVtbl->put_HideDLMembership(This,varHideDLMembership)
#endif
#endif
  HRESULT WINAPI IDistributionList_get_HideDLMembership_Proxy(IDistributionList *This,VARIANT_BOOL *pHideDLMembership);
  void __RPC_STUB IDistributionList_get_HideDLMembership_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDistributionList_put_HideDLMembership_Proxy(IDistributionList *This,VARIANT_BOOL varHideDLMembership);
  void __RPC_STUB IDistributionList_put_HideDLMembership_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMailRecipient_INTERFACE_DEFINED__
#define __IMailRecipient_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMailRecipient;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMailRecipient : public IDispatch {
  public:
    virtual HRESULT WINAPI get_IncomingLimit(__LONG32 *pIncomingLimit) = 0;
    virtual HRESULT WINAPI put_IncomingLimit(__LONG32 varIncomingLimit) = 0;
    virtual HRESULT WINAPI get_OutgoingLimit(__LONG32 *pOutgoingLimit) = 0;
    virtual HRESULT WINAPI put_OutgoingLimit(__LONG32 varOutgoingLimit) = 0;
    virtual HRESULT WINAPI get_RestrictedAddressList(VARIANT *pRestrictedAddressList) = 0;
    virtual HRESULT WINAPI put_RestrictedAddressList(VARIANT varRestrictedAddressList) = 0;
    virtual HRESULT WINAPI get_RestrictedAddresses(CDOEXMRestrictedAddressType *pRestrictedAddresses) = 0;
    virtual HRESULT WINAPI put_RestrictedAddresses(CDOEXMRestrictedAddressType varRestrictedAddresses) = 0;
    virtual HRESULT WINAPI get_ForwardTo(BSTR *pForwardTo) = 0;
    virtual HRESULT WINAPI put_ForwardTo(BSTR varForwardTo) = 0;
    virtual HRESULT WINAPI get_ForwardingStyle(CDOEXMDeliverAndRedirect *pForwardingStyle) = 0;
    virtual HRESULT WINAPI put_ForwardingStyle(CDOEXMDeliverAndRedirect varForwardingStyle) = 0;
    virtual HRESULT WINAPI get_HideFromAddressBook(VARIANT_BOOL *pHideFromAddressBook) = 0;
    virtual HRESULT WINAPI put_HideFromAddressBook(VARIANT_BOOL varHideFromAddressBook) = 0;
    virtual HRESULT WINAPI get_X400Email(BSTR *pX400Email) = 0;
    virtual HRESULT WINAPI put_X400Email(BSTR varX400Email) = 0;
    virtual HRESULT WINAPI get_SMTPEmail(BSTR *pSMTPEmail) = 0;
    virtual HRESULT WINAPI put_SMTPEmail(BSTR varSMTPEmail) = 0;
    virtual HRESULT WINAPI get_ProxyAddresses(VARIANT *pProxyAddresses) = 0;
    virtual HRESULT WINAPI put_ProxyAddresses(VARIANT varProxyAddresses) = 0;
    virtual HRESULT WINAPI get_AutoGenerateEmailAddresses(VARIANT_BOOL *pAutoGenerateEmailAddresses) = 0;
    virtual HRESULT WINAPI put_AutoGenerateEmailAddresses(VARIANT_BOOL varAutoGenerateEmailAddresses) = 0;
    virtual HRESULT WINAPI get_Alias(BSTR *pAlias) = 0;
    virtual HRESULT WINAPI put_Alias(BSTR varAlias) = 0;
    virtual HRESULT WINAPI get_TargetAddress(BSTR *varTargetAddress) = 0;
    virtual HRESULT WINAPI MailEnable(BSTR TargetMailAddress) = 0;
    virtual HRESULT WINAPI MailDisable(void) = 0;
  };
#else
  typedef struct IMailRecipientVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMailRecipient *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMailRecipient *This);
      ULONG (WINAPI *Release)(IMailRecipient *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMailRecipient *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMailRecipient *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMailRecipient *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMailRecipient *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_IncomingLimit)(IMailRecipient *This,__LONG32 *pIncomingLimit);
      HRESULT (WINAPI *put_IncomingLimit)(IMailRecipient *This,__LONG32 varIncomingLimit);
      HRESULT (WINAPI *get_OutgoingLimit)(IMailRecipient *This,__LONG32 *pOutgoingLimit);
      HRESULT (WINAPI *put_OutgoingLimit)(IMailRecipient *This,__LONG32 varOutgoingLimit);
      HRESULT (WINAPI *get_RestrictedAddressList)(IMailRecipient *This,VARIANT *pRestrictedAddressList);
      HRESULT (WINAPI *put_RestrictedAddressList)(IMailRecipient *This,VARIANT varRestrictedAddressList);
      HRESULT (WINAPI *get_RestrictedAddresses)(IMailRecipient *This,CDOEXMRestrictedAddressType *pRestrictedAddresses);
      HRESULT (WINAPI *put_RestrictedAddresses)(IMailRecipient *This,CDOEXMRestrictedAddressType varRestrictedAddresses);
      HRESULT (WINAPI *get_ForwardTo)(IMailRecipient *This,BSTR *pForwardTo);
      HRESULT (WINAPI *put_ForwardTo)(IMailRecipient *This,BSTR varForwardTo);
      HRESULT (WINAPI *get_ForwardingStyle)(IMailRecipient *This,CDOEXMDeliverAndRedirect *pForwardingStyle);
      HRESULT (WINAPI *put_ForwardingStyle)(IMailRecipient *This,CDOEXMDeliverAndRedirect varForwardingStyle);
      HRESULT (WINAPI *get_HideFromAddressBook)(IMailRecipient *This,VARIANT_BOOL *pHideFromAddressBook);
      HRESULT (WINAPI *put_HideFromAddressBook)(IMailRecipient *This,VARIANT_BOOL varHideFromAddressBook);
      HRESULT (WINAPI *get_X400Email)(IMailRecipient *This,BSTR *pX400Email);
      HRESULT (WINAPI *put_X400Email)(IMailRecipient *This,BSTR varX400Email);
      HRESULT (WINAPI *get_SMTPEmail)(IMailRecipient *This,BSTR *pSMTPEmail);
      HRESULT (WINAPI *put_SMTPEmail)(IMailRecipient *This,BSTR varSMTPEmail);
      HRESULT (WINAPI *get_ProxyAddresses)(IMailRecipient *This,VARIANT *pProxyAddresses);
      HRESULT (WINAPI *put_ProxyAddresses)(IMailRecipient *This,VARIANT varProxyAddresses);
      HRESULT (WINAPI *get_AutoGenerateEmailAddresses)(IMailRecipient *This,VARIANT_BOOL *pAutoGenerateEmailAddresses);
      HRESULT (WINAPI *put_AutoGenerateEmailAddresses)(IMailRecipient *This,VARIANT_BOOL varAutoGenerateEmailAddresses);
      HRESULT (WINAPI *get_Alias)(IMailRecipient *This,BSTR *pAlias);
      HRESULT (WINAPI *put_Alias)(IMailRecipient *This,BSTR varAlias);
      HRESULT (WINAPI *get_TargetAddress)(IMailRecipient *This,BSTR *varTargetAddress);
      HRESULT (WINAPI *MailEnable)(IMailRecipient *This,BSTR TargetMailAddress);
      HRESULT (WINAPI *MailDisable)(IMailRecipient *This);
    END_INTERFACE
  } IMailRecipientVtbl;
  struct IMailRecipient {
    CONST_VTBL struct IMailRecipientVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMailRecipient_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMailRecipient_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMailRecipient_Release(This) (This)->lpVtbl->Release(This)
#define IMailRecipient_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMailRecipient_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMailRecipient_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMailRecipient_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMailRecipient_get_IncomingLimit(This,pIncomingLimit) (This)->lpVtbl->get_IncomingLimit(This,pIncomingLimit)
#define IMailRecipient_put_IncomingLimit(This,varIncomingLimit) (This)->lpVtbl->put_IncomingLimit(This,varIncomingLimit)
#define IMailRecipient_get_OutgoingLimit(This,pOutgoingLimit) (This)->lpVtbl->get_OutgoingLimit(This,pOutgoingLimit)
#define IMailRecipient_put_OutgoingLimit(This,varOutgoingLimit) (This)->lpVtbl->put_OutgoingLimit(This,varOutgoingLimit)
#define IMailRecipient_get_RestrictedAddressList(This,pRestrictedAddressList) (This)->lpVtbl->get_RestrictedAddressList(This,pRestrictedAddressList)
#define IMailRecipient_put_RestrictedAddressList(This,varRestrictedAddressList) (This)->lpVtbl->put_RestrictedAddressList(This,varRestrictedAddressList)
#define IMailRecipient_get_RestrictedAddresses(This,pRestrictedAddresses) (This)->lpVtbl->get_RestrictedAddresses(This,pRestrictedAddresses)
#define IMailRecipient_put_RestrictedAddresses(This,varRestrictedAddresses) (This)->lpVtbl->put_RestrictedAddresses(This,varRestrictedAddresses)
#define IMailRecipient_get_ForwardTo(This,pForwardTo) (This)->lpVtbl->get_ForwardTo(This,pForwardTo)
#define IMailRecipient_put_ForwardTo(This,varForwardTo) (This)->lpVtbl->put_ForwardTo(This,varForwardTo)
#define IMailRecipient_get_ForwardingStyle(This,pForwardingStyle) (This)->lpVtbl->get_ForwardingStyle(This,pForwardingStyle)
#define IMailRecipient_put_ForwardingStyle(This,varForwardingStyle) (This)->lpVtbl->put_ForwardingStyle(This,varForwardingStyle)
#define IMailRecipient_get_HideFromAddressBook(This,pHideFromAddressBook) (This)->lpVtbl->get_HideFromAddressBook(This,pHideFromAddressBook)
#define IMailRecipient_put_HideFromAddressBook(This,varHideFromAddressBook) (This)->lpVtbl->put_HideFromAddressBook(This,varHideFromAddressBook)
#define IMailRecipient_get_X400Email(This,pX400Email) (This)->lpVtbl->get_X400Email(This,pX400Email)
#define IMailRecipient_put_X400Email(This,varX400Email) (This)->lpVtbl->put_X400Email(This,varX400Email)
#define IMailRecipient_get_SMTPEmail(This,pSMTPEmail) (This)->lpVtbl->get_SMTPEmail(This,pSMTPEmail)
#define IMailRecipient_put_SMTPEmail(This,varSMTPEmail) (This)->lpVtbl->put_SMTPEmail(This,varSMTPEmail)
#define IMailRecipient_get_ProxyAddresses(This,pProxyAddresses) (This)->lpVtbl->get_ProxyAddresses(This,pProxyAddresses)
#define IMailRecipient_put_ProxyAddresses(This,varProxyAddresses) (This)->lpVtbl->put_ProxyAddresses(This,varProxyAddresses)
#define IMailRecipient_get_AutoGenerateEmailAddresses(This,pAutoGenerateEmailAddresses) (This)->lpVtbl->get_AutoGenerateEmailAddresses(This,pAutoGenerateEmailAddresses)
#define IMailRecipient_put_AutoGenerateEmailAddresses(This,varAutoGenerateEmailAddresses) (This)->lpVtbl->put_AutoGenerateEmailAddresses(This,varAutoGenerateEmailAddresses)
#define IMailRecipient_get_Alias(This,pAlias) (This)->lpVtbl->get_Alias(This,pAlias)
#define IMailRecipient_put_Alias(This,varAlias) (This)->lpVtbl->put_Alias(This,varAlias)
#define IMailRecipient_get_TargetAddress(This,varTargetAddress) (This)->lpVtbl->get_TargetAddress(This,varTargetAddress)
#define IMailRecipient_MailEnable(This,TargetMailAddress) (This)->lpVtbl->MailEnable(This,TargetMailAddress)
#define IMailRecipient_MailDisable(This) (This)->lpVtbl->MailDisable(This)
#endif
#endif
  HRESULT WINAPI IMailRecipient_get_IncomingLimit_Proxy(IMailRecipient *This,__LONG32 *pIncomingLimit);
  void __RPC_STUB IMailRecipient_get_IncomingLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_IncomingLimit_Proxy(IMailRecipient *This,__LONG32 varIncomingLimit);
  void __RPC_STUB IMailRecipient_put_IncomingLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_OutgoingLimit_Proxy(IMailRecipient *This,__LONG32 *pOutgoingLimit);
  void __RPC_STUB IMailRecipient_get_OutgoingLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_OutgoingLimit_Proxy(IMailRecipient *This,__LONG32 varOutgoingLimit);
  void __RPC_STUB IMailRecipient_put_OutgoingLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_RestrictedAddressList_Proxy(IMailRecipient *This,VARIANT *pRestrictedAddressList);
  void __RPC_STUB IMailRecipient_get_RestrictedAddressList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_RestrictedAddressList_Proxy(IMailRecipient *This,VARIANT varRestrictedAddressList);
  void __RPC_STUB IMailRecipient_put_RestrictedAddressList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_RestrictedAddresses_Proxy(IMailRecipient *This,CDOEXMRestrictedAddressType *pRestrictedAddresses);
  void __RPC_STUB IMailRecipient_get_RestrictedAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_RestrictedAddresses_Proxy(IMailRecipient *This,CDOEXMRestrictedAddressType varRestrictedAddresses);
  void __RPC_STUB IMailRecipient_put_RestrictedAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_ForwardTo_Proxy(IMailRecipient *This,BSTR *pForwardTo);
  void __RPC_STUB IMailRecipient_get_ForwardTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_ForwardTo_Proxy(IMailRecipient *This,BSTR varForwardTo);
  void __RPC_STUB IMailRecipient_put_ForwardTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_ForwardingStyle_Proxy(IMailRecipient *This,CDOEXMDeliverAndRedirect *pForwardingStyle);
  void __RPC_STUB IMailRecipient_get_ForwardingStyle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_ForwardingStyle_Proxy(IMailRecipient *This,CDOEXMDeliverAndRedirect varForwardingStyle);
  void __RPC_STUB IMailRecipient_put_ForwardingStyle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_HideFromAddressBook_Proxy(IMailRecipient *This,VARIANT_BOOL *pHideFromAddressBook);
  void __RPC_STUB IMailRecipient_get_HideFromAddressBook_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_HideFromAddressBook_Proxy(IMailRecipient *This,VARIANT_BOOL varHideFromAddressBook);
  void __RPC_STUB IMailRecipient_put_HideFromAddressBook_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_X400Email_Proxy(IMailRecipient *This,BSTR *pX400Email);
  void __RPC_STUB IMailRecipient_get_X400Email_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_X400Email_Proxy(IMailRecipient *This,BSTR varX400Email);
  void __RPC_STUB IMailRecipient_put_X400Email_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_SMTPEmail_Proxy(IMailRecipient *This,BSTR *pSMTPEmail);
  void __RPC_STUB IMailRecipient_get_SMTPEmail_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_SMTPEmail_Proxy(IMailRecipient *This,BSTR varSMTPEmail);
  void __RPC_STUB IMailRecipient_put_SMTPEmail_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_ProxyAddresses_Proxy(IMailRecipient *This,VARIANT *pProxyAddresses);
  void __RPC_STUB IMailRecipient_get_ProxyAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_ProxyAddresses_Proxy(IMailRecipient *This,VARIANT varProxyAddresses);
  void __RPC_STUB IMailRecipient_put_ProxyAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_AutoGenerateEmailAddresses_Proxy(IMailRecipient *This,VARIANT_BOOL *pAutoGenerateEmailAddresses);
  void __RPC_STUB IMailRecipient_get_AutoGenerateEmailAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_AutoGenerateEmailAddresses_Proxy(IMailRecipient *This,VARIANT_BOOL varAutoGenerateEmailAddresses);
  void __RPC_STUB IMailRecipient_put_AutoGenerateEmailAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_Alias_Proxy(IMailRecipient *This,BSTR *pAlias);
  void __RPC_STUB IMailRecipient_get_Alias_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_put_Alias_Proxy(IMailRecipient *This,BSTR varAlias);
  void __RPC_STUB IMailRecipient_put_Alias_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_get_TargetAddress_Proxy(IMailRecipient *This,BSTR *varTargetAddress);
  void __RPC_STUB IMailRecipient_get_TargetAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_MailEnable_Proxy(IMailRecipient *This,BSTR TargetMailAddress);
  void __RPC_STUB IMailRecipient_MailEnable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailRecipient_MailDisable_Proxy(IMailRecipient *This);
  void __RPC_STUB IMailRecipient_MailDisable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMailboxStore_INTERFACE_DEFINED__
#define __IMailboxStore_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMailboxStore;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMailboxStore : public IDispatch {
  public:
    virtual HRESULT WINAPI get_EnableStoreDefaults(VARIANT *pEnableStoreDefaults) = 0;
    virtual HRESULT WINAPI put_EnableStoreDefaults(VARIANT varEnableStoreDefaults) = 0;
    virtual HRESULT WINAPI get_StoreQuota(__LONG32 *pStoreQuota) = 0;
    virtual HRESULT WINAPI put_StoreQuota(__LONG32 varStoreQuota) = 0;
    virtual HRESULT WINAPI get_OverQuotaLimit(__LONG32 *pOverQuotaLimit) = 0;
    virtual HRESULT WINAPI put_OverQuotaLimit(__LONG32 varOverQuotaLimit) = 0;
    virtual HRESULT WINAPI get_HardLimit(__LONG32 *pHardLimit) = 0;
    virtual HRESULT WINAPI put_HardLimit(__LONG32 varHardLimit) = 0;
    virtual HRESULT WINAPI get_OverrideStoreGarbageCollection(VARIANT_BOOL *pOverrideStoreGarbageCollection) = 0;
    virtual HRESULT WINAPI put_OverrideStoreGarbageCollection(VARIANT_BOOL varOverrideStoreGarbageCollection) = 0;
    virtual HRESULT WINAPI get_DaysBeforeGarbageCollection(__LONG32 *pDaysBeforeGarbageCollection) = 0;
    virtual HRESULT WINAPI put_DaysBeforeGarbageCollection(__LONG32 varDaysBeforeGarbageCollection) = 0;
    virtual HRESULT WINAPI get_GarbageCollectOnlyAfterBackup(VARIANT_BOOL *pGarbageCollectOnlyAfterBackup) = 0;
    virtual HRESULT WINAPI put_GarbageCollectOnlyAfterBackup(VARIANT_BOOL varGarbageCollectOnlyAfterBackup) = 0;
    virtual HRESULT WINAPI get_Delegates(VARIANT *pDelegates) = 0;
    virtual HRESULT WINAPI put_Delegates(VARIANT varDelegates) = 0;
    virtual HRESULT WINAPI get_HomeMDB(BSTR *varHomeMDB) = 0;
    virtual HRESULT WINAPI get_RecipientLimit(__LONG32 *pRecipientLimit) = 0;
    virtual HRESULT WINAPI put_RecipientLimit(__LONG32 varRecipientLimit) = 0;
    virtual HRESULT WINAPI CreateMailbox(BSTR HomeMDBURL) = 0;
    virtual HRESULT WINAPI DeleteMailbox(void) = 0;
    virtual HRESULT WINAPI MoveMailbox(BSTR HomeMDBURL) = 0;
  };
#else
  typedef struct IMailboxStoreVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMailboxStore *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMailboxStore *This);
      ULONG (WINAPI *Release)(IMailboxStore *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMailboxStore *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMailboxStore *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMailboxStore *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMailboxStore *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_EnableStoreDefaults)(IMailboxStore *This,VARIANT *pEnableStoreDefaults);
      HRESULT (WINAPI *put_EnableStoreDefaults)(IMailboxStore *This,VARIANT varEnableStoreDefaults);
      HRESULT (WINAPI *get_StoreQuota)(IMailboxStore *This,__LONG32 *pStoreQuota);
      HRESULT (WINAPI *put_StoreQuota)(IMailboxStore *This,__LONG32 varStoreQuota);
      HRESULT (WINAPI *get_OverQuotaLimit)(IMailboxStore *This,__LONG32 *pOverQuotaLimit);
      HRESULT (WINAPI *put_OverQuotaLimit)(IMailboxStore *This,__LONG32 varOverQuotaLimit);
      HRESULT (WINAPI *get_HardLimit)(IMailboxStore *This,__LONG32 *pHardLimit);
      HRESULT (WINAPI *put_HardLimit)(IMailboxStore *This,__LONG32 varHardLimit);
      HRESULT (WINAPI *get_OverrideStoreGarbageCollection)(IMailboxStore *This,VARIANT_BOOL *pOverrideStoreGarbageCollection);
      HRESULT (WINAPI *put_OverrideStoreGarbageCollection)(IMailboxStore *This,VARIANT_BOOL varOverrideStoreGarbageCollection);
      HRESULT (WINAPI *get_DaysBeforeGarbageCollection)(IMailboxStore *This,__LONG32 *pDaysBeforeGarbageCollection);
      HRESULT (WINAPI *put_DaysBeforeGarbageCollection)(IMailboxStore *This,__LONG32 varDaysBeforeGarbageCollection);
      HRESULT (WINAPI *get_GarbageCollectOnlyAfterBackup)(IMailboxStore *This,VARIANT_BOOL *pGarbageCollectOnlyAfterBackup);
      HRESULT (WINAPI *put_GarbageCollectOnlyAfterBackup)(IMailboxStore *This,VARIANT_BOOL varGarbageCollectOnlyAfterBackup);
      HRESULT (WINAPI *get_Delegates)(IMailboxStore *This,VARIANT *pDelegates);
      HRESULT (WINAPI *put_Delegates)(IMailboxStore *This,VARIANT varDelegates);
      HRESULT (WINAPI *get_HomeMDB)(IMailboxStore *This,BSTR *varHomeMDB);
      HRESULT (WINAPI *get_RecipientLimit)(IMailboxStore *This,__LONG32 *pRecipientLimit);
      HRESULT (WINAPI *put_RecipientLimit)(IMailboxStore *This,__LONG32 varRecipientLimit);
      HRESULT (WINAPI *CreateMailbox)(IMailboxStore *This,BSTR HomeMDBURL);
      HRESULT (WINAPI *DeleteMailbox)(IMailboxStore *This);
      HRESULT (WINAPI *MoveMailbox)(IMailboxStore *This,BSTR HomeMDBURL);
    END_INTERFACE
  } IMailboxStoreVtbl;
  struct IMailboxStore {
    CONST_VTBL struct IMailboxStoreVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMailboxStore_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMailboxStore_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMailboxStore_Release(This) (This)->lpVtbl->Release(This)
#define IMailboxStore_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMailboxStore_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMailboxStore_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMailboxStore_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMailboxStore_get_EnableStoreDefaults(This,pEnableStoreDefaults) (This)->lpVtbl->get_EnableStoreDefaults(This,pEnableStoreDefaults)
#define IMailboxStore_put_EnableStoreDefaults(This,varEnableStoreDefaults) (This)->lpVtbl->put_EnableStoreDefaults(This,varEnableStoreDefaults)
#define IMailboxStore_get_StoreQuota(This,pStoreQuota) (This)->lpVtbl->get_StoreQuota(This,pStoreQuota)
#define IMailboxStore_put_StoreQuota(This,varStoreQuota) (This)->lpVtbl->put_StoreQuota(This,varStoreQuota)
#define IMailboxStore_get_OverQuotaLimit(This,pOverQuotaLimit) (This)->lpVtbl->get_OverQuotaLimit(This,pOverQuotaLimit)
#define IMailboxStore_put_OverQuotaLimit(This,varOverQuotaLimit) (This)->lpVtbl->put_OverQuotaLimit(This,varOverQuotaLimit)
#define IMailboxStore_get_HardLimit(This,pHardLimit) (This)->lpVtbl->get_HardLimit(This,pHardLimit)
#define IMailboxStore_put_HardLimit(This,varHardLimit) (This)->lpVtbl->put_HardLimit(This,varHardLimit)
#define IMailboxStore_get_OverrideStoreGarbageCollection(This,pOverrideStoreGarbageCollection) (This)->lpVtbl->get_OverrideStoreGarbageCollection(This,pOverrideStoreGarbageCollection)
#define IMailboxStore_put_OverrideStoreGarbageCollection(This,varOverrideStoreGarbageCollection) (This)->lpVtbl->put_OverrideStoreGarbageCollection(This,varOverrideStoreGarbageCollection)
#define IMailboxStore_get_DaysBeforeGarbageCollection(This,pDaysBeforeGarbageCollection) (This)->lpVtbl->get_DaysBeforeGarbageCollection(This,pDaysBeforeGarbageCollection)
#define IMailboxStore_put_DaysBeforeGarbageCollection(This,varDaysBeforeGarbageCollection) (This)->lpVtbl->put_DaysBeforeGarbageCollection(This,varDaysBeforeGarbageCollection)
#define IMailboxStore_get_GarbageCollectOnlyAfterBackup(This,pGarbageCollectOnlyAfterBackup) (This)->lpVtbl->get_GarbageCollectOnlyAfterBackup(This,pGarbageCollectOnlyAfterBackup)
#define IMailboxStore_put_GarbageCollectOnlyAfterBackup(This,varGarbageCollectOnlyAfterBackup) (This)->lpVtbl->put_GarbageCollectOnlyAfterBackup(This,varGarbageCollectOnlyAfterBackup)
#define IMailboxStore_get_Delegates(This,pDelegates) (This)->lpVtbl->get_Delegates(This,pDelegates)
#define IMailboxStore_put_Delegates(This,varDelegates) (This)->lpVtbl->put_Delegates(This,varDelegates)
#define IMailboxStore_get_HomeMDB(This,varHomeMDB) (This)->lpVtbl->get_HomeMDB(This,varHomeMDB)
#define IMailboxStore_get_RecipientLimit(This,pRecipientLimit) (This)->lpVtbl->get_RecipientLimit(This,pRecipientLimit)
#define IMailboxStore_put_RecipientLimit(This,varRecipientLimit) (This)->lpVtbl->put_RecipientLimit(This,varRecipientLimit)
#define IMailboxStore_CreateMailbox(This,HomeMDBURL) (This)->lpVtbl->CreateMailbox(This,HomeMDBURL)
#define IMailboxStore_DeleteMailbox(This) (This)->lpVtbl->DeleteMailbox(This)
#define IMailboxStore_MoveMailbox(This,HomeMDBURL) (This)->lpVtbl->MoveMailbox(This,HomeMDBURL)
#endif
#endif
  HRESULT WINAPI IMailboxStore_get_EnableStoreDefaults_Proxy(IMailboxStore *This,VARIANT *pEnableStoreDefaults);
  void __RPC_STUB IMailboxStore_get_EnableStoreDefaults_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_EnableStoreDefaults_Proxy(IMailboxStore *This,VARIANT varEnableStoreDefaults);
  void __RPC_STUB IMailboxStore_put_EnableStoreDefaults_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_StoreQuota_Proxy(IMailboxStore *This,__LONG32 *pStoreQuota);
  void __RPC_STUB IMailboxStore_get_StoreQuota_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_StoreQuota_Proxy(IMailboxStore *This,__LONG32 varStoreQuota);
  void __RPC_STUB IMailboxStore_put_StoreQuota_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_OverQuotaLimit_Proxy(IMailboxStore *This,__LONG32 *pOverQuotaLimit);
  void __RPC_STUB IMailboxStore_get_OverQuotaLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_OverQuotaLimit_Proxy(IMailboxStore *This,__LONG32 varOverQuotaLimit);
  void __RPC_STUB IMailboxStore_put_OverQuotaLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_HardLimit_Proxy(IMailboxStore *This,__LONG32 *pHardLimit);
  void __RPC_STUB IMailboxStore_get_HardLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_HardLimit_Proxy(IMailboxStore *This,__LONG32 varHardLimit);
  void __RPC_STUB IMailboxStore_put_HardLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_OverrideStoreGarbageCollection_Proxy(IMailboxStore *This,VARIANT_BOOL *pOverrideStoreGarbageCollection);
  void __RPC_STUB IMailboxStore_get_OverrideStoreGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_OverrideStoreGarbageCollection_Proxy(IMailboxStore *This,VARIANT_BOOL varOverrideStoreGarbageCollection);
  void __RPC_STUB IMailboxStore_put_OverrideStoreGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_DaysBeforeGarbageCollection_Proxy(IMailboxStore *This,__LONG32 *pDaysBeforeGarbageCollection);
  void __RPC_STUB IMailboxStore_get_DaysBeforeGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_DaysBeforeGarbageCollection_Proxy(IMailboxStore *This,__LONG32 varDaysBeforeGarbageCollection);
  void __RPC_STUB IMailboxStore_put_DaysBeforeGarbageCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_GarbageCollectOnlyAfterBackup_Proxy(IMailboxStore *This,VARIANT_BOOL *pGarbageCollectOnlyAfterBackup);
  void __RPC_STUB IMailboxStore_get_GarbageCollectOnlyAfterBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_GarbageCollectOnlyAfterBackup_Proxy(IMailboxStore *This,VARIANT_BOOL varGarbageCollectOnlyAfterBackup);
  void __RPC_STUB IMailboxStore_put_GarbageCollectOnlyAfterBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_Delegates_Proxy(IMailboxStore *This,VARIANT *pDelegates);
  void __RPC_STUB IMailboxStore_get_Delegates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_Delegates_Proxy(IMailboxStore *This,VARIANT varDelegates);
  void __RPC_STUB IMailboxStore_put_Delegates_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_HomeMDB_Proxy(IMailboxStore *This,BSTR *varHomeMDB);
  void __RPC_STUB IMailboxStore_get_HomeMDB_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_get_RecipientLimit_Proxy(IMailboxStore *This,__LONG32 *pRecipientLimit);
  void __RPC_STUB IMailboxStore_get_RecipientLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_put_RecipientLimit_Proxy(IMailboxStore *This,__LONG32 varRecipientLimit);
  void __RPC_STUB IMailboxStore_put_RecipientLimit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_CreateMailbox_Proxy(IMailboxStore *This,BSTR HomeMDBURL);
  void __RPC_STUB IMailboxStore_CreateMailbox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_DeleteMailbox_Proxy(IMailboxStore *This);
  void __RPC_STUB IMailboxStore_DeleteMailbox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailboxStore_MoveMailbox_Proxy(IMailboxStore *This,BSTR HomeMDBURL);
  void __RPC_STUB IMailboxStore_MoveMailbox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_MailGroup;
#ifdef __cplusplus
  class MailGroup;
#endif
  EXTERN_C const CLSID CLSID_MailRecipient;
#ifdef __cplusplus
  class MailRecipient;
#endif
  EXTERN_C const CLSID CLSID_Mailbox;
#ifdef __cplusplus
  class Mailbox;
#endif
  EXTERN_C const CLSID CLSID_FolderAdmin;
#ifdef __cplusplus
  class FolderAdmin;
#endif
  EXTERN_C const CLSID CLSID_ExchangeServer;
#ifdef __cplusplus
  class ExchangeServer;
#endif
  EXTERN_C const CLSID CLSID_FolderTree;
#ifdef __cplusplus
  class FolderTree;
#endif
  EXTERN_C const CLSID CLSID_PublicStoreDB;
#ifdef __cplusplus
  class PublicStoreDB;
#endif
  EXTERN_C const CLSID CLSID_MailboxStoreDB;
#ifdef __cplusplus
  class MailboxStoreDB;
#endif
  EXTERN_C const CLSID CLSID_StorageGroup;
#ifdef __cplusplus
  class StorageGroup;
#endif

#ifndef __CDOEXMInterfaces_MODULE_DEFINED__
#define __CDOEXMInterfaces_MODULE_DEFINED__
  const BSTR cdoexmIMailRecipient = L"IMailRecipient";
  const BSTR cdoexmIMailboxStore = L"IMailboxStore";
  const BSTR cdoexmIDistributionList = L"IDistributionList";
  const BSTR cdoexmIExchangeServer = L"IExchangeServer";
  const BSTR cdoexmIFolderTree = L"IFolderTree";
  const BSTR cdoexmIPublicStoreDB = L"IPublicStoreDB";
  const BSTR cdoexmIMailboxStoreDB = L"IMailboxStoreDB";
  const BSTR cdoexmIStorageGroup = L"IStorageGroup";
  const BSTR cdoexmIFolderAdmin = L"IFolderAdmin";
  const BSTR cdoexmIADs = L"IADs";
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
