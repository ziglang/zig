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

#ifndef __msimcntl_h__
#define __msimcntl_h__

#ifndef ___IUseIMBase_FWD_DEFINED__
#define ___IUseIMBase_FWD_DEFINED__
typedef struct _IUseIMBase _IUseIMBase;
#endif

#ifndef __IMSIMContactView_FWD_DEFINED__
#define __IMSIMContactView_FWD_DEFINED__
typedef struct IMSIMContactView IMSIMContactView;
#endif

#ifndef __DMSIMContactViewEvents_FWD_DEFINED__
#define __DMSIMContactViewEvents_FWD_DEFINED__
typedef struct DMSIMContactViewEvents DMSIMContactViewEvents;
#endif

#ifndef __IMSIMMessageView_FWD_DEFINED__
#define __IMSIMMessageView_FWD_DEFINED__
typedef struct IMSIMMessageView IMSIMMessageView;
#endif

#ifndef __DMSIMMessageViewEvents_FWD_DEFINED__
#define __DMSIMMessageViewEvents_FWD_DEFINED__
typedef struct DMSIMMessageViewEvents DMSIMMessageViewEvents;
#endif

#ifndef __MSIMContactView_FWD_DEFINED__
#define __MSIMContactView_FWD_DEFINED__

#ifdef __cplusplus
typedef class MSIMContactView MSIMContactView;
#else
typedef struct MSIMContactView MSIMContactView;
#endif
#endif

#ifndef __MSIMMessageView_FWD_DEFINED__
#define __MSIMMessageView_FWD_DEFINED__

#ifdef __cplusplus
typedef class MSIMMessageView MSIMMessageView;
#else
typedef struct MSIMMessageView MSIMMessageView;
#endif
#endif

#ifndef __IIMSafeContact_FWD_DEFINED__
#define __IIMSafeContact_FWD_DEFINED__
typedef struct IIMSafeContact IIMSafeContact;
#endif

#ifndef __IMSIMContactList_FWD_DEFINED__
#define __IMSIMContactList_FWD_DEFINED__
typedef struct IMSIMContactList IMSIMContactList;
#endif

#ifndef __DIMContactListEvents_FWD_DEFINED__
#define __DIMContactListEvents_FWD_DEFINED__
typedef struct DIMContactListEvents DIMContactListEvents;
#endif

#ifndef __MSIMContactList_FWD_DEFINED__
#define __MSIMContactList_FWD_DEFINED__
#ifdef __cplusplus
typedef class MSIMContactList MSIMContactList;
#else
typedef struct MSIMContactList MSIMContactList;
#endif
#endif

#ifndef __IMSafeContact_FWD_DEFINED__
#define __IMSafeContact_FWD_DEFINED__
#ifdef __cplusplus
typedef class IMSafeContact IMSafeContact;
#else
typedef struct IMSafeContact IMSafeContact;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "simpdata.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define DMSIMCONTACTVIEWEVENTS_OnReady 0xD0
#define DMSIMCONTACTVIEWEVENTS_OnLogon 0xD1
#define DMSIMCONTACTVIEWEVENTS_OnLogoff 0xD2
#define DMSIMCONTACTVIEWEVENTS_OnLaunchMessageUI 0xD3
#define DMSIMCONTACTVIEWEVENTS_OnMenuRequest 0xD6
#define DMSIMCONTACTVIEWEVENTS_OnMenuSelect 0xD7
#define DMSIMCONTACTVIEWEVENTS_OnAddResult 0xD8
#define DMSIMCONTACTVIEWEVENTS_OnRemoveResult 0xD9
#define DMSIMCONTACTVIEWEVENTS_OnSelect 0xDA
#define DMSIMCONTACTVIEWEVENTS_OnShutdown 0xDB
#define DMSIMCONTACTVIEWEVENTS_OnEMailContact 0xDC
#define DMSIMCONTACTVIEWEVENTS_OnAddContactUI 0xDD
#define DMSIMCONTACTVIEWEVENTS_OnLocalStateChange 0xDE
#define DMSIMCONTACTVIEWEVENTS_OnExtentsChange 0xDF
#define DMSIMMESSAGEVIEWEVENTS_OnReady 0xD0
#define DMSIMMESSAGEVIEWEVENTS_OnLogon 0xD1
#define DMSIMMESSAGEVIEWEVENTS_OnLogoff 0xD2
#define DMSIMMESSAGEVIEWEVENTS_OnLaunchMessageUI 0xD3
#define DMSIMMESSAGEVIEWEVENTS_OnNewMessage 0xD6
#define DMSIMMESSAGEVIEWEVENTS_OnAddResult 0xD7
#define DMSIMMESSAGEVIEWEVENTS_OnRemoveResult 0xD8
#define DMSIMMESSAGEVIEWEVENTS_OnNewSession 0xD9
#define DMSIMMESSAGEVIEWEVENTS_OnSessionEnd 0xDA
#define DMSIMMESSAGEVIEWEVENTS_OnShutdown 0xDB
#define DMSIMMESSAGEVIEWEVENTS_OnLocalStateChange 0xDC
#define DMSIMCONTACTLISTEVENTS_OnReady 0xD0
#define DMSIMCONTACTLISTEVENTS_OnLogon 0xD1
#define DMSIMCONTACTLISTEVENTS_OnLogoff 0xD2
#define DMSIMCONTACTLISTEVENTS_OnAddResult 0xD3
#define DMSIMCONTACTLISTEVENTS_OnRemoveResult 0xD4
#define DMSIMCONTACTLISTEVENTS_OnShutdown 0xD5
#define DMSIMCONTACTLISTEVENTS_OnChangeContact 0xD6
#define DMSIMCONTACTLISTEVENTS_OnLocalStateChange 0xD7

  extern RPC_IF_HANDLE __MIDL_itf_msimcntl_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msimcntl_0000_v0_0_s_ifspec;

#ifndef __MSIMCNTLLib_LIBRARY_DEFINED__
#define __MSIMCNTLLib_LIBRARY_DEFINED__

  typedef enum __MIDL___MIDL_itf_msimcntl_0000_0001 {
    MSIM_PROVIDER_FIRST = 0,MSIM_PROVIDER_ANY = 0,MSIM_PROVIDER_EXCHANGE_HOST = 1,MSIM_PROVIDER_LAST = 1,MSIM_PROVIDER_NONE = 0xffff
  } MSIM_PROVIDER;

  typedef enum __MIDL___MIDL_itf_msimcntl_0000_0002 {
    MSIM_MSG_UI_SESSION = 0,MSIM_MSG_UI_NETMEETING = 1
  } MSIM_MSG_UI;

  EXTERN_C const IID LIBID_MSIMCNTLLib;
#ifndef ___IUseIMBase_INTERFACE_DEFINED__
#define ___IUseIMBase_INTERFACE_DEFINED__
  EXTERN_C const IID IID__IUseIMBase;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct _IUseIMBase : public IDispatch {
  public:
    virtual HRESULT WINAPI SetService(IDispatch *pService,IDispatch *pApp = 0) = 0;
    virtual HRESULT WINAPI get_Service(short *pVal) = 0;
    virtual HRESULT WINAPI put_Service(short newVal) = 0;
    virtual HRESULT WINAPI get_HasService(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI get_AutoLogon(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_AutoLogon(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_LoggedOn(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI Logon(BSTR bstrAddress = L"",BSTR bstrName = L"",BSTR bstrPassword = L"",BSTR bstrDomain = L"") = 0;
    virtual HRESULT WINAPI Logoff(void) = 0;
    virtual HRESULT WINAPI GetLocalState(VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData) = 0;
    virtual HRESULT WINAPI SetLocalState(__LONG32 lState,VARIANT varDescription,VARIANT varData) = 0;
  };
#else
  typedef struct _IUseIMBaseVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(_IUseIMBase *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(_IUseIMBase *This);
      ULONG (WINAPI *Release)(_IUseIMBase *This);
      HRESULT (WINAPI *GetTypeInfoCount)(_IUseIMBase *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(_IUseIMBase *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(_IUseIMBase *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(_IUseIMBase *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetService)(_IUseIMBase *This,IDispatch *pService,IDispatch *pApp);
      HRESULT (WINAPI *get_Service)(_IUseIMBase *This,short *pVal);
      HRESULT (WINAPI *put_Service)(_IUseIMBase *This,short newVal);
      HRESULT (WINAPI *get_HasService)(_IUseIMBase *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *get_AutoLogon)(_IUseIMBase *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AutoLogon)(_IUseIMBase *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_LoggedOn)(_IUseIMBase *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *Logon)(_IUseIMBase *This,BSTR bstrAddress,BSTR bstrName,BSTR bstrPassword,BSTR bstrDomain);
      HRESULT (WINAPI *Logoff)(_IUseIMBase *This);
      HRESULT (WINAPI *GetLocalState)(_IUseIMBase *This,VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData);
      HRESULT (WINAPI *SetLocalState)(_IUseIMBase *This,__LONG32 lState,VARIANT varDescription,VARIANT varData);
    END_INTERFACE
  } _IUseIMBaseVtbl;
  struct _IUseIMBase {
    CONST_VTBL struct _IUseIMBaseVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _IUseIMBase_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define _IUseIMBase_AddRef(This) (This)->lpVtbl->AddRef(This)
#define _IUseIMBase_Release(This) (This)->lpVtbl->Release(This)
#define _IUseIMBase_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define _IUseIMBase_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define _IUseIMBase_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define _IUseIMBase_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define _IUseIMBase_SetService(This,pService,pApp) (This)->lpVtbl->SetService(This,pService,pApp)
#define _IUseIMBase_get_Service(This,pVal) (This)->lpVtbl->get_Service(This,pVal)
#define _IUseIMBase_put_Service(This,newVal) (This)->lpVtbl->put_Service(This,newVal)
#define _IUseIMBase_get_HasService(This,pVal) (This)->lpVtbl->get_HasService(This,pVal)
#define _IUseIMBase_get_AutoLogon(This,pVal) (This)->lpVtbl->get_AutoLogon(This,pVal)
#define _IUseIMBase_put_AutoLogon(This,newVal) (This)->lpVtbl->put_AutoLogon(This,newVal)
#define _IUseIMBase_get_LoggedOn(This,pVal) (This)->lpVtbl->get_LoggedOn(This,pVal)
#define _IUseIMBase_Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain) (This)->lpVtbl->Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain)
#define _IUseIMBase_Logoff(This) (This)->lpVtbl->Logoff(This)
#define _IUseIMBase_GetLocalState(This,pvarState,pvarDescription,pvarData) (This)->lpVtbl->GetLocalState(This,pvarState,pvarDescription,pvarData)
#define _IUseIMBase_SetLocalState(This,lState,varDescription,varData) (This)->lpVtbl->SetLocalState(This,lState,varDescription,varData)
#endif
#endif
  HRESULT WINAPI _IUseIMBase_SetService_Proxy(_IUseIMBase *This,IDispatch *pService,IDispatch *pApp);
  void __RPC_STUB _IUseIMBase_SetService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_get_Service_Proxy(_IUseIMBase *This,short *pVal);
  void __RPC_STUB _IUseIMBase_get_Service_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_put_Service_Proxy(_IUseIMBase *This,short newVal);
  void __RPC_STUB _IUseIMBase_put_Service_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_get_HasService_Proxy(_IUseIMBase *This,VARIANT_BOOL *pVal);
  void __RPC_STUB _IUseIMBase_get_HasService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_get_AutoLogon_Proxy(_IUseIMBase *This,VARIANT_BOOL *pVal);
  void __RPC_STUB _IUseIMBase_get_AutoLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_put_AutoLogon_Proxy(_IUseIMBase *This,VARIANT_BOOL newVal);
  void __RPC_STUB _IUseIMBase_put_AutoLogon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_get_LoggedOn_Proxy(_IUseIMBase *This,VARIANT_BOOL *pVal);
  void __RPC_STUB _IUseIMBase_get_LoggedOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_Logon_Proxy(_IUseIMBase *This,BSTR bstrAddress,BSTR bstrName,BSTR bstrPassword,BSTR bstrDomain);
  void __RPC_STUB _IUseIMBase_Logon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_Logoff_Proxy(_IUseIMBase *This);
  void __RPC_STUB _IUseIMBase_Logoff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_GetLocalState_Proxy(_IUseIMBase *This,VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData);
  void __RPC_STUB _IUseIMBase_GetLocalState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _IUseIMBase_SetLocalState_Proxy(_IUseIMBase *This,__LONG32 lState,VARIANT varDescription,VARIANT varData);
  void __RPC_STUB _IUseIMBase_SetLocalState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMSIMContactView_INTERFACE_DEFINED__
#define __IMSIMContactView_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSIMContactView;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSIMContactView : public _IUseIMBase {
  public:
    virtual HRESULT WINAPI Add(VARIANT vUser) = 0;
    virtual HRESULT WINAPI Remove(VARIANT vUser) = 0;
    virtual HRESULT WINAPI get_List(VARIANT *pvarList) = 0;
    virtual HRESULT WINAPI put_List(VARIANT varList) = 0;
    virtual HRESULT WINAPI AddMenuItem(BSTR bstrItem,__LONG32 lPosition,__LONG32 *plCommand) = 0;
    virtual HRESULT WINAPI get_SelectedMenuOptions(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI IMSelected(void) = 0;
    virtual HRESULT WINAPI EMailSelected(void) = 0;
    virtual HRESULT WINAPI InviteSelected(void) = 0;
    virtual HRESULT WINAPI BlockSelected(void) = 0;
    virtual HRESULT WINAPI UnblockSelected(void) = 0;
    virtual HRESULT WINAPI get_ExtentWidth(__LONG32 *pX) = 0;
    virtual HRESULT WINAPI get_ExtentHeight(__LONG32 *pY) = 0;
    virtual HRESULT WINAPI get_HotTracking(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_HotTracking(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_AllowCollapse(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_AllowCollapse(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ShowSelectAlways(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowSelectAlways(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_OnlineRootLabel(BSTR *pbstrLabel) = 0;
    virtual HRESULT WINAPI put_OnlineRootLabel(BSTR bstrLabel) = 0;
    virtual HRESULT WINAPI get_OfflineRootLabel(BSTR *pbstrLabel) = 0;
    virtual HRESULT WINAPI put_OfflineRootLabel(BSTR bstrLabel) = 0;
    virtual HRESULT WINAPI get_Window(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI get_ShowLogonButton(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowLogonButton(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_OnlineCollapsed(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_OnlineCollapsed(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_OfflineCollapsed(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_OfflineCollapsed(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_Group(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_Group(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_FilterOffline(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_FilterOffline(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ShowIcons(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowIcons(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_AcceptMessages(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_AcceptMessages(VARIANT_BOOL newVal) = 0;
  };
#else
  typedef struct IMSIMContactViewVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSIMContactView *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSIMContactView *This);
      ULONG (WINAPI *Release)(IMSIMContactView *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMSIMContactView *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMSIMContactView *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMSIMContactView *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMSIMContactView *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetService)(IMSIMContactView *This,IDispatch *pService,IDispatch *pApp);
      HRESULT (WINAPI *get_Service)(IMSIMContactView *This,short *pVal);
      HRESULT (WINAPI *put_Service)(IMSIMContactView *This,short newVal);
      HRESULT (WINAPI *get_HasService)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *get_AutoLogon)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AutoLogon)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_LoggedOn)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *Logon)(IMSIMContactView *This,BSTR bstrAddress,BSTR bstrName,BSTR bstrPassword,BSTR bstrDomain);
      HRESULT (WINAPI *Logoff)(IMSIMContactView *This);
      HRESULT (WINAPI *GetLocalState)(IMSIMContactView *This,VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData);
      HRESULT (WINAPI *SetLocalState)(IMSIMContactView *This,__LONG32 lState,VARIANT varDescription,VARIANT varData);
      HRESULT (WINAPI *Add)(IMSIMContactView *This,VARIANT vUser);
      HRESULT (WINAPI *Remove)(IMSIMContactView *This,VARIANT vUser);
      HRESULT (WINAPI *get_List)(IMSIMContactView *This,VARIANT *pvarList);
      HRESULT (WINAPI *put_List)(IMSIMContactView *This,VARIANT varList);
      HRESULT (WINAPI *AddMenuItem)(IMSIMContactView *This,BSTR bstrItem,__LONG32 lPosition,__LONG32 *plCommand);
      HRESULT (WINAPI *get_SelectedMenuOptions)(IMSIMContactView *This,__LONG32 *pVal);
      HRESULT (WINAPI *IMSelected)(IMSIMContactView *This);
      HRESULT (WINAPI *EMailSelected)(IMSIMContactView *This);
      HRESULT (WINAPI *InviteSelected)(IMSIMContactView *This);
      HRESULT (WINAPI *BlockSelected)(IMSIMContactView *This);
      HRESULT (WINAPI *UnblockSelected)(IMSIMContactView *This);
      HRESULT (WINAPI *get_ExtentWidth)(IMSIMContactView *This,__LONG32 *pX);
      HRESULT (WINAPI *get_ExtentHeight)(IMSIMContactView *This,__LONG32 *pY);
      HRESULT (WINAPI *get_HotTracking)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_HotTracking)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_AllowCollapse)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AllowCollapse)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowSelectAlways)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowSelectAlways)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_OnlineRootLabel)(IMSIMContactView *This,BSTR *pbstrLabel);
      HRESULT (WINAPI *put_OnlineRootLabel)(IMSIMContactView *This,BSTR bstrLabel);
      HRESULT (WINAPI *get_OfflineRootLabel)(IMSIMContactView *This,BSTR *pbstrLabel);
      HRESULT (WINAPI *put_OfflineRootLabel)(IMSIMContactView *This,BSTR bstrLabel);
      HRESULT (WINAPI *get_Window)(IMSIMContactView *This,__LONG32 *pVal);
      HRESULT (WINAPI *get_ShowLogonButton)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowLogonButton)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_OnlineCollapsed)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_OnlineCollapsed)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_OfflineCollapsed)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_OfflineCollapsed)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_Group)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_Group)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_FilterOffline)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_FilterOffline)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowIcons)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowIcons)(IMSIMContactView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_AcceptMessages)(IMSIMContactView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AcceptMessages)(IMSIMContactView *This,VARIANT_BOOL newVal);
    END_INTERFACE
  } IMSIMContactViewVtbl;
  struct IMSIMContactView {
    CONST_VTBL struct IMSIMContactViewVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSIMContactView_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSIMContactView_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSIMContactView_Release(This) (This)->lpVtbl->Release(This)
#define IMSIMContactView_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMSIMContactView_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMSIMContactView_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMSIMContactView_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMSIMContactView_SetService(This,pService,pApp) (This)->lpVtbl->SetService(This,pService,pApp)
#define IMSIMContactView_get_Service(This,pVal) (This)->lpVtbl->get_Service(This,pVal)
#define IMSIMContactView_put_Service(This,newVal) (This)->lpVtbl->put_Service(This,newVal)
#define IMSIMContactView_get_HasService(This,pVal) (This)->lpVtbl->get_HasService(This,pVal)
#define IMSIMContactView_get_AutoLogon(This,pVal) (This)->lpVtbl->get_AutoLogon(This,pVal)
#define IMSIMContactView_put_AutoLogon(This,newVal) (This)->lpVtbl->put_AutoLogon(This,newVal)
#define IMSIMContactView_get_LoggedOn(This,pVal) (This)->lpVtbl->get_LoggedOn(This,pVal)
#define IMSIMContactView_Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain) (This)->lpVtbl->Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain)
#define IMSIMContactView_Logoff(This) (This)->lpVtbl->Logoff(This)
#define IMSIMContactView_GetLocalState(This,pvarState,pvarDescription,pvarData) (This)->lpVtbl->GetLocalState(This,pvarState,pvarDescription,pvarData)
#define IMSIMContactView_SetLocalState(This,lState,varDescription,varData) (This)->lpVtbl->SetLocalState(This,lState,varDescription,varData)
#define IMSIMContactView_Add(This,vUser) (This)->lpVtbl->Add(This,vUser)
#define IMSIMContactView_Remove(This,vUser) (This)->lpVtbl->Remove(This,vUser)
#define IMSIMContactView_get_List(This,pvarList) (This)->lpVtbl->get_List(This,pvarList)
#define IMSIMContactView_put_List(This,varList) (This)->lpVtbl->put_List(This,varList)
#define IMSIMContactView_AddMenuItem(This,bstrItem,lPosition,plCommand) (This)->lpVtbl->AddMenuItem(This,bstrItem,lPosition,plCommand)
#define IMSIMContactView_get_SelectedMenuOptions(This,pVal) (This)->lpVtbl->get_SelectedMenuOptions(This,pVal)
#define IMSIMContactView_IMSelected(This) (This)->lpVtbl->IMSelected(This)
#define IMSIMContactView_EMailSelected(This) (This)->lpVtbl->EMailSelected(This)
#define IMSIMContactView_InviteSelected(This) (This)->lpVtbl->InviteSelected(This)
#define IMSIMContactView_BlockSelected(This) (This)->lpVtbl->BlockSelected(This)
#define IMSIMContactView_UnblockSelected(This) (This)->lpVtbl->UnblockSelected(This)
#define IMSIMContactView_get_ExtentWidth(This,pX) (This)->lpVtbl->get_ExtentWidth(This,pX)
#define IMSIMContactView_get_ExtentHeight(This,pY) (This)->lpVtbl->get_ExtentHeight(This,pY)
#define IMSIMContactView_get_HotTracking(This,pVal) (This)->lpVtbl->get_HotTracking(This,pVal)
#define IMSIMContactView_put_HotTracking(This,newVal) (This)->lpVtbl->put_HotTracking(This,newVal)
#define IMSIMContactView_get_AllowCollapse(This,pVal) (This)->lpVtbl->get_AllowCollapse(This,pVal)
#define IMSIMContactView_put_AllowCollapse(This,newVal) (This)->lpVtbl->put_AllowCollapse(This,newVal)
#define IMSIMContactView_get_ShowSelectAlways(This,pVal) (This)->lpVtbl->get_ShowSelectAlways(This,pVal)
#define IMSIMContactView_put_ShowSelectAlways(This,newVal) (This)->lpVtbl->put_ShowSelectAlways(This,newVal)
#define IMSIMContactView_get_OnlineRootLabel(This,pbstrLabel) (This)->lpVtbl->get_OnlineRootLabel(This,pbstrLabel)
#define IMSIMContactView_put_OnlineRootLabel(This,bstrLabel) (This)->lpVtbl->put_OnlineRootLabel(This,bstrLabel)
#define IMSIMContactView_get_OfflineRootLabel(This,pbstrLabel) (This)->lpVtbl->get_OfflineRootLabel(This,pbstrLabel)
#define IMSIMContactView_put_OfflineRootLabel(This,bstrLabel) (This)->lpVtbl->put_OfflineRootLabel(This,bstrLabel)
#define IMSIMContactView_get_Window(This,pVal) (This)->lpVtbl->get_Window(This,pVal)
#define IMSIMContactView_get_ShowLogonButton(This,pVal) (This)->lpVtbl->get_ShowLogonButton(This,pVal)
#define IMSIMContactView_put_ShowLogonButton(This,newVal) (This)->lpVtbl->put_ShowLogonButton(This,newVal)
#define IMSIMContactView_get_OnlineCollapsed(This,pVal) (This)->lpVtbl->get_OnlineCollapsed(This,pVal)
#define IMSIMContactView_put_OnlineCollapsed(This,newVal) (This)->lpVtbl->put_OnlineCollapsed(This,newVal)
#define IMSIMContactView_get_OfflineCollapsed(This,pVal) (This)->lpVtbl->get_OfflineCollapsed(This,pVal)
#define IMSIMContactView_put_OfflineCollapsed(This,newVal) (This)->lpVtbl->put_OfflineCollapsed(This,newVal)
#define IMSIMContactView_get_Group(This,pVal) (This)->lpVtbl->get_Group(This,pVal)
#define IMSIMContactView_put_Group(This,newVal) (This)->lpVtbl->put_Group(This,newVal)
#define IMSIMContactView_get_FilterOffline(This,pVal) (This)->lpVtbl->get_FilterOffline(This,pVal)
#define IMSIMContactView_put_FilterOffline(This,newVal) (This)->lpVtbl->put_FilterOffline(This,newVal)
#define IMSIMContactView_get_ShowIcons(This,pVal) (This)->lpVtbl->get_ShowIcons(This,pVal)
#define IMSIMContactView_put_ShowIcons(This,newVal) (This)->lpVtbl->put_ShowIcons(This,newVal)
#define IMSIMContactView_get_AcceptMessages(This,pVal) (This)->lpVtbl->get_AcceptMessages(This,pVal)
#define IMSIMContactView_put_AcceptMessages(This,newVal) (This)->lpVtbl->put_AcceptMessages(This,newVal)
#endif
#endif
  HRESULT WINAPI IMSIMContactView_Add_Proxy(IMSIMContactView *This,VARIANT vUser);
  void __RPC_STUB IMSIMContactView_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_Remove_Proxy(IMSIMContactView *This,VARIANT vUser);
  void __RPC_STUB IMSIMContactView_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_List_Proxy(IMSIMContactView *This,VARIANT *pvarList);
  void __RPC_STUB IMSIMContactView_get_List_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_List_Proxy(IMSIMContactView *This,VARIANT varList);
  void __RPC_STUB IMSIMContactView_put_List_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_AddMenuItem_Proxy(IMSIMContactView *This,BSTR bstrItem,__LONG32 lPosition,__LONG32 *plCommand);
  void __RPC_STUB IMSIMContactView_AddMenuItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_SelectedMenuOptions_Proxy(IMSIMContactView *This,__LONG32 *pVal);
  void __RPC_STUB IMSIMContactView_get_SelectedMenuOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_IMSelected_Proxy(IMSIMContactView *This);
  void __RPC_STUB IMSIMContactView_IMSelected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_EMailSelected_Proxy(IMSIMContactView *This);
  void __RPC_STUB IMSIMContactView_EMailSelected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_InviteSelected_Proxy(IMSIMContactView *This);
  void __RPC_STUB IMSIMContactView_InviteSelected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_BlockSelected_Proxy(IMSIMContactView *This);
  void __RPC_STUB IMSIMContactView_BlockSelected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_UnblockSelected_Proxy(IMSIMContactView *This);
  void __RPC_STUB IMSIMContactView_UnblockSelected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_ExtentWidth_Proxy(IMSIMContactView *This,__LONG32 *pX);
  void __RPC_STUB IMSIMContactView_get_ExtentWidth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_ExtentHeight_Proxy(IMSIMContactView *This,__LONG32 *pY);
  void __RPC_STUB IMSIMContactView_get_ExtentHeight_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_HotTracking_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_HotTracking_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_HotTracking_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_HotTracking_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_AllowCollapse_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_AllowCollapse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_AllowCollapse_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_AllowCollapse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_ShowSelectAlways_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_ShowSelectAlways_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_ShowSelectAlways_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_ShowSelectAlways_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_OnlineRootLabel_Proxy(IMSIMContactView *This,BSTR *pbstrLabel);
  void __RPC_STUB IMSIMContactView_get_OnlineRootLabel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_OnlineRootLabel_Proxy(IMSIMContactView *This,BSTR bstrLabel);
  void __RPC_STUB IMSIMContactView_put_OnlineRootLabel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_OfflineRootLabel_Proxy(IMSIMContactView *This,BSTR *pbstrLabel);
  void __RPC_STUB IMSIMContactView_get_OfflineRootLabel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_OfflineRootLabel_Proxy(IMSIMContactView *This,BSTR bstrLabel);
  void __RPC_STUB IMSIMContactView_put_OfflineRootLabel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_Window_Proxy(IMSIMContactView *This,__LONG32 *pVal);
  void __RPC_STUB IMSIMContactView_get_Window_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_ShowLogonButton_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_ShowLogonButton_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_ShowLogonButton_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_ShowLogonButton_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_OnlineCollapsed_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_OnlineCollapsed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_OnlineCollapsed_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_OnlineCollapsed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_OfflineCollapsed_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_OfflineCollapsed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_OfflineCollapsed_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_OfflineCollapsed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_Group_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_Group_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_Group_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_Group_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_FilterOffline_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_FilterOffline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_FilterOffline_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_FilterOffline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_ShowIcons_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_ShowIcons_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_ShowIcons_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_ShowIcons_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_get_AcceptMessages_Proxy(IMSIMContactView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMContactView_get_AcceptMessages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactView_put_AcceptMessages_Proxy(IMSIMContactView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMContactView_put_AcceptMessages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DMSIMContactViewEvents_DISPINTERFACE_DEFINED__
#define __DMSIMContactViewEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_DMSIMContactViewEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DMSIMContactViewEvents : public IDispatch {
  };
#else
  typedef struct DMSIMContactViewEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DMSIMContactViewEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DMSIMContactViewEvents *This);
      ULONG (WINAPI *Release)(DMSIMContactViewEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(DMSIMContactViewEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(DMSIMContactViewEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(DMSIMContactViewEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(DMSIMContactViewEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } DMSIMContactViewEventsVtbl;
  struct DMSIMContactViewEvents {
    CONST_VTBL struct DMSIMContactViewEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DMSIMContactViewEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DMSIMContactViewEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DMSIMContactViewEvents_Release(This) (This)->lpVtbl->Release(This)
#define DMSIMContactViewEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define DMSIMContactViewEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define DMSIMContactViewEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define DMSIMContactViewEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __IMSIMMessageView_INTERFACE_DEFINED__
#define __IMSIMMessageView_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSIMMessageView;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSIMMessageView : public _IUseIMBase {
  public:
    virtual HRESULT WINAPI get_Window(__LONG32 *phwnd) = 0;
    virtual HRESULT WINAPI put_Appearance(short appearance) = 0;
    virtual HRESULT WINAPI get_Appearance(short *pappearance) = 0;
    virtual HRESULT WINAPI get_ShowParticipants(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowParticipants(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ShowMembers(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowMembers(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ShowAvailable(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowAvailable(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_AvailableList(VARIANT *pVal) = 0;
    virtual HRESULT WINAPI put_AvailableList(VARIANT newVal) = 0;
    virtual HRESULT WINAPI get_ShowMessageHistory(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowMessageHistory(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ShowEdit(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowEdit(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_HideStatus(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_HideStatus(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_MessageHistory(BSTR *pVal) = 0;
    virtual HRESULT WINAPI get_StatusText(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_StatusText(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_MessageText(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_MessageText(BSTR newVal) = 0;
    virtual HRESULT WINAPI Invite(VARIANT varContact) = 0;
    virtual HRESULT WINAPI EndSession(void) = 0;
    virtual HRESULT WINAPI AddToAvailable(VARIANT varContact) = 0;
    virtual HRESULT WINAPI RemoveFromAvailable(VARIANT varContact) = 0;
    virtual HRESULT WINAPI InviteNetMeeting(void) = 0;
    virtual HRESULT WINAPI NetMeetingInvite(IDispatch *pIMSession,IDispatch *pContact,__LONG32 lInviteCookie) = 0;
    virtual HRESULT WINAPI get_SourceURL(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_SourceURL(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_InSession(VARIANT_BOOL *pVal) = 0;
  };
#else
  typedef struct IMSIMMessageViewVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSIMMessageView *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSIMMessageView *This);
      ULONG (WINAPI *Release)(IMSIMMessageView *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMSIMMessageView *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMSIMMessageView *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMSIMMessageView *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMSIMMessageView *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetService)(IMSIMMessageView *This,IDispatch *pService,IDispatch *pApp);
      HRESULT (WINAPI *get_Service)(IMSIMMessageView *This,short *pVal);
      HRESULT (WINAPI *put_Service)(IMSIMMessageView *This,short newVal);
      HRESULT (WINAPI *get_HasService)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *get_AutoLogon)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AutoLogon)(IMSIMMessageView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_LoggedOn)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *Logon)(IMSIMMessageView *This,BSTR bstrAddress,BSTR bstrName,BSTR bstrPassword,BSTR bstrDomain);
      HRESULT (WINAPI *Logoff)(IMSIMMessageView *This);
      HRESULT (WINAPI *GetLocalState)(IMSIMMessageView *This,VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData);
      HRESULT (WINAPI *SetLocalState)(IMSIMMessageView *This,__LONG32 lState,VARIANT varDescription,VARIANT varData);
      HRESULT (WINAPI *get_Window)(IMSIMMessageView *This,__LONG32 *phwnd);
      HRESULT (WINAPI *put_Appearance)(IMSIMMessageView *This,short appearance);
      HRESULT (WINAPI *get_Appearance)(IMSIMMessageView *This,short *pappearance);
      HRESULT (WINAPI *get_ShowParticipants)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowParticipants)(IMSIMMessageView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowMembers)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowMembers)(IMSIMMessageView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowAvailable)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowAvailable)(IMSIMMessageView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_AvailableList)(IMSIMMessageView *This,VARIANT *pVal);
      HRESULT (WINAPI *put_AvailableList)(IMSIMMessageView *This,VARIANT newVal);
      HRESULT (WINAPI *get_ShowMessageHistory)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowMessageHistory)(IMSIMMessageView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowEdit)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowEdit)(IMSIMMessageView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_HideStatus)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_HideStatus)(IMSIMMessageView *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_MessageHistory)(IMSIMMessageView *This,BSTR *pVal);
      HRESULT (WINAPI *get_StatusText)(IMSIMMessageView *This,BSTR *pVal);
      HRESULT (WINAPI *put_StatusText)(IMSIMMessageView *This,BSTR newVal);
      HRESULT (WINAPI *get_MessageText)(IMSIMMessageView *This,BSTR *pVal);
      HRESULT (WINAPI *put_MessageText)(IMSIMMessageView *This,BSTR newVal);
      HRESULT (WINAPI *Invite)(IMSIMMessageView *This,VARIANT varContact);
      HRESULT (WINAPI *EndSession)(IMSIMMessageView *This);
      HRESULT (WINAPI *AddToAvailable)(IMSIMMessageView *This,VARIANT varContact);
      HRESULT (WINAPI *RemoveFromAvailable)(IMSIMMessageView *This,VARIANT varContact);
      HRESULT (WINAPI *InviteNetMeeting)(IMSIMMessageView *This);
      HRESULT (WINAPI *NetMeetingInvite)(IMSIMMessageView *This,IDispatch *pIMSession,IDispatch *pContact,__LONG32 lInviteCookie);
      HRESULT (WINAPI *get_SourceURL)(IMSIMMessageView *This,BSTR *pVal);
      HRESULT (WINAPI *put_SourceURL)(IMSIMMessageView *This,BSTR newVal);
      HRESULT (WINAPI *get_InSession)(IMSIMMessageView *This,VARIANT_BOOL *pVal);
    END_INTERFACE
  } IMSIMMessageViewVtbl;
  struct IMSIMMessageView {
    CONST_VTBL struct IMSIMMessageViewVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSIMMessageView_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSIMMessageView_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSIMMessageView_Release(This) (This)->lpVtbl->Release(This)
#define IMSIMMessageView_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMSIMMessageView_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMSIMMessageView_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMSIMMessageView_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMSIMMessageView_SetService(This,pService,pApp) (This)->lpVtbl->SetService(This,pService,pApp)
#define IMSIMMessageView_get_Service(This,pVal) (This)->lpVtbl->get_Service(This,pVal)
#define IMSIMMessageView_put_Service(This,newVal) (This)->lpVtbl->put_Service(This,newVal)
#define IMSIMMessageView_get_HasService(This,pVal) (This)->lpVtbl->get_HasService(This,pVal)
#define IMSIMMessageView_get_AutoLogon(This,pVal) (This)->lpVtbl->get_AutoLogon(This,pVal)
#define IMSIMMessageView_put_AutoLogon(This,newVal) (This)->lpVtbl->put_AutoLogon(This,newVal)
#define IMSIMMessageView_get_LoggedOn(This,pVal) (This)->lpVtbl->get_LoggedOn(This,pVal)
#define IMSIMMessageView_Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain) (This)->lpVtbl->Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain)
#define IMSIMMessageView_Logoff(This) (This)->lpVtbl->Logoff(This)
#define IMSIMMessageView_GetLocalState(This,pvarState,pvarDescription,pvarData) (This)->lpVtbl->GetLocalState(This,pvarState,pvarDescription,pvarData)
#define IMSIMMessageView_SetLocalState(This,lState,varDescription,varData) (This)->lpVtbl->SetLocalState(This,lState,varDescription,varData)
#define IMSIMMessageView_get_Window(This,phwnd) (This)->lpVtbl->get_Window(This,phwnd)
#define IMSIMMessageView_put_Appearance(This,appearance) (This)->lpVtbl->put_Appearance(This,appearance)
#define IMSIMMessageView_get_Appearance(This,pappearance) (This)->lpVtbl->get_Appearance(This,pappearance)
#define IMSIMMessageView_get_ShowParticipants(This,pVal) (This)->lpVtbl->get_ShowParticipants(This,pVal)
#define IMSIMMessageView_put_ShowParticipants(This,newVal) (This)->lpVtbl->put_ShowParticipants(This,newVal)
#define IMSIMMessageView_get_ShowMembers(This,pVal) (This)->lpVtbl->get_ShowMembers(This,pVal)
#define IMSIMMessageView_put_ShowMembers(This,newVal) (This)->lpVtbl->put_ShowMembers(This,newVal)
#define IMSIMMessageView_get_ShowAvailable(This,pVal) (This)->lpVtbl->get_ShowAvailable(This,pVal)
#define IMSIMMessageView_put_ShowAvailable(This,newVal) (This)->lpVtbl->put_ShowAvailable(This,newVal)
#define IMSIMMessageView_get_AvailableList(This,pVal) (This)->lpVtbl->get_AvailableList(This,pVal)
#define IMSIMMessageView_put_AvailableList(This,newVal) (This)->lpVtbl->put_AvailableList(This,newVal)
#define IMSIMMessageView_get_ShowMessageHistory(This,pVal) (This)->lpVtbl->get_ShowMessageHistory(This,pVal)
#define IMSIMMessageView_put_ShowMessageHistory(This,newVal) (This)->lpVtbl->put_ShowMessageHistory(This,newVal)
#define IMSIMMessageView_get_ShowEdit(This,pVal) (This)->lpVtbl->get_ShowEdit(This,pVal)
#define IMSIMMessageView_put_ShowEdit(This,newVal) (This)->lpVtbl->put_ShowEdit(This,newVal)
#define IMSIMMessageView_get_HideStatus(This,pVal) (This)->lpVtbl->get_HideStatus(This,pVal)
#define IMSIMMessageView_put_HideStatus(This,newVal) (This)->lpVtbl->put_HideStatus(This,newVal)
#define IMSIMMessageView_get_MessageHistory(This,pVal) (This)->lpVtbl->get_MessageHistory(This,pVal)
#define IMSIMMessageView_get_StatusText(This,pVal) (This)->lpVtbl->get_StatusText(This,pVal)
#define IMSIMMessageView_put_StatusText(This,newVal) (This)->lpVtbl->put_StatusText(This,newVal)
#define IMSIMMessageView_get_MessageText(This,pVal) (This)->lpVtbl->get_MessageText(This,pVal)
#define IMSIMMessageView_put_MessageText(This,newVal) (This)->lpVtbl->put_MessageText(This,newVal)
#define IMSIMMessageView_Invite(This,varContact) (This)->lpVtbl->Invite(This,varContact)
#define IMSIMMessageView_EndSession(This) (This)->lpVtbl->EndSession(This)
#define IMSIMMessageView_AddToAvailable(This,varContact) (This)->lpVtbl->AddToAvailable(This,varContact)
#define IMSIMMessageView_RemoveFromAvailable(This,varContact) (This)->lpVtbl->RemoveFromAvailable(This,varContact)
#define IMSIMMessageView_InviteNetMeeting(This) (This)->lpVtbl->InviteNetMeeting(This)
#define IMSIMMessageView_NetMeetingInvite(This,pIMSession,pContact,lInviteCookie) (This)->lpVtbl->NetMeetingInvite(This,pIMSession,pContact,lInviteCookie)
#define IMSIMMessageView_get_SourceURL(This,pVal) (This)->lpVtbl->get_SourceURL(This,pVal)
#define IMSIMMessageView_put_SourceURL(This,newVal) (This)->lpVtbl->put_SourceURL(This,newVal)
#define IMSIMMessageView_get_InSession(This,pVal) (This)->lpVtbl->get_InSession(This,pVal)
#endif
#endif
  HRESULT WINAPI IMSIMMessageView_get_Window_Proxy(IMSIMMessageView *This,__LONG32 *phwnd);
  void __RPC_STUB IMSIMMessageView_get_Window_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_Appearance_Proxy(IMSIMMessageView *This,short appearance);
  void __RPC_STUB IMSIMMessageView_put_Appearance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_Appearance_Proxy(IMSIMMessageView *This,short *pappearance);
  void __RPC_STUB IMSIMMessageView_get_Appearance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_ShowParticipants_Proxy(IMSIMMessageView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMMessageView_get_ShowParticipants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_ShowParticipants_Proxy(IMSIMMessageView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMMessageView_put_ShowParticipants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_ShowMembers_Proxy(IMSIMMessageView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMMessageView_get_ShowMembers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_ShowMembers_Proxy(IMSIMMessageView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMMessageView_put_ShowMembers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_ShowAvailable_Proxy(IMSIMMessageView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMMessageView_get_ShowAvailable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_ShowAvailable_Proxy(IMSIMMessageView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMMessageView_put_ShowAvailable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_AvailableList_Proxy(IMSIMMessageView *This,VARIANT *pVal);
  void __RPC_STUB IMSIMMessageView_get_AvailableList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_AvailableList_Proxy(IMSIMMessageView *This,VARIANT newVal);
  void __RPC_STUB IMSIMMessageView_put_AvailableList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_ShowMessageHistory_Proxy(IMSIMMessageView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMMessageView_get_ShowMessageHistory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_ShowMessageHistory_Proxy(IMSIMMessageView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMMessageView_put_ShowMessageHistory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_ShowEdit_Proxy(IMSIMMessageView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMMessageView_get_ShowEdit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_ShowEdit_Proxy(IMSIMMessageView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMMessageView_put_ShowEdit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_HideStatus_Proxy(IMSIMMessageView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMMessageView_get_HideStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_HideStatus_Proxy(IMSIMMessageView *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMMessageView_put_HideStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_MessageHistory_Proxy(IMSIMMessageView *This,BSTR *pVal);
  void __RPC_STUB IMSIMMessageView_get_MessageHistory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_StatusText_Proxy(IMSIMMessageView *This,BSTR *pVal);
  void __RPC_STUB IMSIMMessageView_get_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_StatusText_Proxy(IMSIMMessageView *This,BSTR newVal);
  void __RPC_STUB IMSIMMessageView_put_StatusText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_MessageText_Proxy(IMSIMMessageView *This,BSTR *pVal);
  void __RPC_STUB IMSIMMessageView_get_MessageText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_MessageText_Proxy(IMSIMMessageView *This,BSTR newVal);
  void __RPC_STUB IMSIMMessageView_put_MessageText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_Invite_Proxy(IMSIMMessageView *This,VARIANT varContact);
  void __RPC_STUB IMSIMMessageView_Invite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_EndSession_Proxy(IMSIMMessageView *This);
  void __RPC_STUB IMSIMMessageView_EndSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_AddToAvailable_Proxy(IMSIMMessageView *This,VARIANT varContact);
  void __RPC_STUB IMSIMMessageView_AddToAvailable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_RemoveFromAvailable_Proxy(IMSIMMessageView *This,VARIANT varContact);
  void __RPC_STUB IMSIMMessageView_RemoveFromAvailable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_InviteNetMeeting_Proxy(IMSIMMessageView *This);
  void __RPC_STUB IMSIMMessageView_InviteNetMeeting_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_NetMeetingInvite_Proxy(IMSIMMessageView *This,IDispatch *pIMSession,IDispatch *pContact,__LONG32 lInviteCookie);
  void __RPC_STUB IMSIMMessageView_NetMeetingInvite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_SourceURL_Proxy(IMSIMMessageView *This,BSTR *pVal);
  void __RPC_STUB IMSIMMessageView_get_SourceURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_put_SourceURL_Proxy(IMSIMMessageView *This,BSTR newVal);
  void __RPC_STUB IMSIMMessageView_put_SourceURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMMessageView_get_InSession_Proxy(IMSIMMessageView *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMMessageView_get_InSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DMSIMMessageViewEvents_DISPINTERFACE_DEFINED__
#define __DMSIMMessageViewEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_DMSIMMessageViewEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DMSIMMessageViewEvents : public IDispatch {
  };
#else
  typedef struct DMSIMMessageViewEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DMSIMMessageViewEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DMSIMMessageViewEvents *This);
      ULONG (WINAPI *Release)(DMSIMMessageViewEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(DMSIMMessageViewEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(DMSIMMessageViewEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(DMSIMMessageViewEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(DMSIMMessageViewEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } DMSIMMessageViewEventsVtbl;
  struct DMSIMMessageViewEvents {
    CONST_VTBL struct DMSIMMessageViewEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DMSIMMessageViewEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DMSIMMessageViewEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DMSIMMessageViewEvents_Release(This) (This)->lpVtbl->Release(This)
#define DMSIMMessageViewEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define DMSIMMessageViewEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define DMSIMMessageViewEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define DMSIMMessageViewEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

  EXTERN_C const CLSID CLSID_MSIMContactView;
#ifdef __cplusplus
  class MSIMContactView;
#endif
  EXTERN_C const CLSID CLSID_MSIMMessageView;
#ifdef __cplusplus
  class MSIMMessageView;
#endif

#ifndef __IIMSafeContact_INTERFACE_DEFINED__
#define __IIMSafeContact_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIMSafeContact;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIMSafeContact : public IDispatch {
  public:
    virtual HRESULT WINAPI get_LogonName(BSTR *pbstrLogonName) = 0;
    virtual HRESULT WINAPI get_FriendlyName(BSTR *pbstrFriendlyName) = 0;
    virtual HRESULT WINAPI get_EmailAddress(BSTR *pbstrEmailAddress) = 0;
    virtual HRESULT WINAPI get_State(__LONG32 *plState) = 0;
    virtual HRESULT WINAPI _SetBaseContact(IDispatch *pUnk) = 0;
    virtual HRESULT WINAPI LaunchInstantMessage(void) = 0;
    virtual HRESULT WINAPI LaunchEmail(void) = 0;
    virtual HRESULT WINAPI LaunchNetMeeting(void) = 0;
  };
#else
  typedef struct IIMSafeContactVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIMSafeContact *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIMSafeContact *This);
      ULONG (WINAPI *Release)(IIMSafeContact *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIMSafeContact *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIMSafeContact *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIMSafeContact *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIMSafeContact *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_LogonName)(IIMSafeContact *This,BSTR *pbstrLogonName);
      HRESULT (WINAPI *get_FriendlyName)(IIMSafeContact *This,BSTR *pbstrFriendlyName);
      HRESULT (WINAPI *get_EmailAddress)(IIMSafeContact *This,BSTR *pbstrEmailAddress);
      HRESULT (WINAPI *get_State)(IIMSafeContact *This,__LONG32 *plState);
      HRESULT (WINAPI *_SetBaseContact)(IIMSafeContact *This,IDispatch *pUnk);
      HRESULT (WINAPI *LaunchInstantMessage)(IIMSafeContact *This);
      HRESULT (WINAPI *LaunchEmail)(IIMSafeContact *This);
      HRESULT (WINAPI *LaunchNetMeeting)(IIMSafeContact *This);
    END_INTERFACE
  } IIMSafeContactVtbl;
  struct IIMSafeContact {
    CONST_VTBL struct IIMSafeContactVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIMSafeContact_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIMSafeContact_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIMSafeContact_Release(This) (This)->lpVtbl->Release(This)
#define IIMSafeContact_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIMSafeContact_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIMSafeContact_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIMSafeContact_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIMSafeContact_get_LogonName(This,pbstrLogonName) (This)->lpVtbl->get_LogonName(This,pbstrLogonName)
#define IIMSafeContact_get_FriendlyName(This,pbstrFriendlyName) (This)->lpVtbl->get_FriendlyName(This,pbstrFriendlyName)
#define IIMSafeContact_get_EmailAddress(This,pbstrEmailAddress) (This)->lpVtbl->get_EmailAddress(This,pbstrEmailAddress)
#define IIMSafeContact_get_State(This,plState) (This)->lpVtbl->get_State(This,plState)
#define IIMSafeContact__SetBaseContact(This,pUnk) (This)->lpVtbl->_SetBaseContact(This,pUnk)
#define IIMSafeContact_LaunchInstantMessage(This) (This)->lpVtbl->LaunchInstantMessage(This)
#define IIMSafeContact_LaunchEmail(This) (This)->lpVtbl->LaunchEmail(This)
#define IIMSafeContact_LaunchNetMeeting(This) (This)->lpVtbl->LaunchNetMeeting(This)
#endif
#endif
  HRESULT WINAPI IIMSafeContact_get_LogonName_Proxy(IIMSafeContact *This,BSTR *pbstrLogonName);
  void __RPC_STUB IIMSafeContact_get_LogonName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSafeContact_get_FriendlyName_Proxy(IIMSafeContact *This,BSTR *pbstrFriendlyName);
  void __RPC_STUB IIMSafeContact_get_FriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSafeContact_get_EmailAddress_Proxy(IIMSafeContact *This,BSTR *pbstrEmailAddress);
  void __RPC_STUB IIMSafeContact_get_EmailAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSafeContact_get_State_Proxy(IIMSafeContact *This,__LONG32 *plState);
  void __RPC_STUB IIMSafeContact_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSafeContact__SetBaseContact_Proxy(IIMSafeContact *This,IDispatch *pUnk);
  void __RPC_STUB IIMSafeContact__SetBaseContact_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSafeContact_LaunchInstantMessage_Proxy(IIMSafeContact *This);
  void __RPC_STUB IIMSafeContact_LaunchInstantMessage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSafeContact_LaunchEmail_Proxy(IIMSafeContact *This);
  void __RPC_STUB IIMSafeContact_LaunchEmail_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSafeContact_LaunchNetMeeting_Proxy(IIMSafeContact *This);
  void __RPC_STUB IIMSafeContact_LaunchNetMeeting_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMSIMContactList_INTERFACE_DEFINED__
#define __IMSIMContactList_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSIMContactList;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSIMContactList : public _IUseIMBase {
  public:
    virtual HRESULT WINAPI get_List(VARIANT *pvarList) = 0;
    virtual HRESULT WINAPI put_List(VARIANT varList) = 0;
    virtual HRESULT WINAPI Add(VARIANT vUser) = 0;
    virtual HRESULT WINAPI Remove(VARIANT vUser) = 0;
    virtual HRESULT WINAPI get_SelectedMenuOptions(__LONG32 lRow,__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI InstantMessage(__LONG32 lRow) = 0;
    virtual HRESULT WINAPI EMail(__LONG32 lRow) = 0;
    virtual HRESULT WINAPI Invite(__LONG32 lRow) = 0;
    virtual HRESULT WINAPI Block(__LONG32 lRow) = 0;
    virtual HRESULT WINAPI Unblock(__LONG32 lRow) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pnCount) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT Var,VARIANT *pSafeContact) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppunkEnum) = 0;
    virtual HRESULT WINAPI get_LocalState(__LONG32 *pnState) = 0;
    virtual HRESULT WINAPI put_LocalState(__LONG32 nState) = 0;
    virtual HRESULT WINAPI get_LocalLogonName(BSTR *pval) = 0;
  };
#else
  typedef struct IMSIMContactListVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSIMContactList *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSIMContactList *This);
      ULONG (WINAPI *Release)(IMSIMContactList *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMSIMContactList *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMSIMContactList *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMSIMContactList *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMSIMContactList *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetService)(IMSIMContactList *This,IDispatch *pService,IDispatch *pApp);
      HRESULT (WINAPI *get_Service)(IMSIMContactList *This,short *pVal);
      HRESULT (WINAPI *put_Service)(IMSIMContactList *This,short newVal);
      HRESULT (WINAPI *get_HasService)(IMSIMContactList *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *get_AutoLogon)(IMSIMContactList *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AutoLogon)(IMSIMContactList *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_LoggedOn)(IMSIMContactList *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *Logon)(IMSIMContactList *This,BSTR bstrAddress,BSTR bstrName,BSTR bstrPassword,BSTR bstrDomain);
      HRESULT (WINAPI *Logoff)(IMSIMContactList *This);
      HRESULT (WINAPI *GetLocalState)(IMSIMContactList *This,VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData);
      HRESULT (WINAPI *SetLocalState)(IMSIMContactList *This,__LONG32 lState,VARIANT varDescription,VARIANT varData);
      HRESULT (WINAPI *get_List)(IMSIMContactList *This,VARIANT *pvarList);
      HRESULT (WINAPI *put_List)(IMSIMContactList *This,VARIANT varList);
      HRESULT (WINAPI *Add)(IMSIMContactList *This,VARIANT vUser);
      HRESULT (WINAPI *Remove)(IMSIMContactList *This,VARIANT vUser);
      HRESULT (WINAPI *get_SelectedMenuOptions)(IMSIMContactList *This,__LONG32 lRow,__LONG32 *pVal);
      HRESULT (WINAPI *InstantMessage)(IMSIMContactList *This,__LONG32 lRow);
      HRESULT (WINAPI *EMail)(IMSIMContactList *This,__LONG32 lRow);
      HRESULT (WINAPI *Invite)(IMSIMContactList *This,__LONG32 lRow);
      HRESULT (WINAPI *Block)(IMSIMContactList *This,__LONG32 lRow);
      HRESULT (WINAPI *Unblock)(IMSIMContactList *This,__LONG32 lRow);
      HRESULT (WINAPI *get_Count)(IMSIMContactList *This,__LONG32 *pnCount);
      HRESULT (WINAPI *get_Item)(IMSIMContactList *This,VARIANT Var,VARIANT *pSafeContact);
      HRESULT (WINAPI *get__NewEnum)(IMSIMContactList *This,IUnknown **ppunkEnum);
      HRESULT (WINAPI *get_LocalState)(IMSIMContactList *This,__LONG32 *pnState);
      HRESULT (WINAPI *put_LocalState)(IMSIMContactList *This,__LONG32 nState);
      HRESULT (WINAPI *get_LocalLogonName)(IMSIMContactList *This,BSTR *pval);
    END_INTERFACE
  } IMSIMContactListVtbl;
  struct IMSIMContactList {
    CONST_VTBL struct IMSIMContactListVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSIMContactList_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSIMContactList_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSIMContactList_Release(This) (This)->lpVtbl->Release(This)
#define IMSIMContactList_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMSIMContactList_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMSIMContactList_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMSIMContactList_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMSIMContactList_SetService(This,pService,pApp) (This)->lpVtbl->SetService(This,pService,pApp)
#define IMSIMContactList_get_Service(This,pVal) (This)->lpVtbl->get_Service(This,pVal)
#define IMSIMContactList_put_Service(This,newVal) (This)->lpVtbl->put_Service(This,newVal)
#define IMSIMContactList_get_HasService(This,pVal) (This)->lpVtbl->get_HasService(This,pVal)
#define IMSIMContactList_get_AutoLogon(This,pVal) (This)->lpVtbl->get_AutoLogon(This,pVal)
#define IMSIMContactList_put_AutoLogon(This,newVal) (This)->lpVtbl->put_AutoLogon(This,newVal)
#define IMSIMContactList_get_LoggedOn(This,pVal) (This)->lpVtbl->get_LoggedOn(This,pVal)
#define IMSIMContactList_Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain) (This)->lpVtbl->Logon(This,bstrAddress,bstrName,bstrPassword,bstrDomain)
#define IMSIMContactList_Logoff(This) (This)->lpVtbl->Logoff(This)
#define IMSIMContactList_GetLocalState(This,pvarState,pvarDescription,pvarData) (This)->lpVtbl->GetLocalState(This,pvarState,pvarDescription,pvarData)
#define IMSIMContactList_SetLocalState(This,lState,varDescription,varData) (This)->lpVtbl->SetLocalState(This,lState,varDescription,varData)
#define IMSIMContactList_get_List(This,pvarList) (This)->lpVtbl->get_List(This,pvarList)
#define IMSIMContactList_put_List(This,varList) (This)->lpVtbl->put_List(This,varList)
#define IMSIMContactList_Add(This,vUser) (This)->lpVtbl->Add(This,vUser)
#define IMSIMContactList_Remove(This,vUser) (This)->lpVtbl->Remove(This,vUser)
#define IMSIMContactList_get_SelectedMenuOptions(This,lRow,pVal) (This)->lpVtbl->get_SelectedMenuOptions(This,lRow,pVal)
#define IMSIMContactList_InstantMessage(This,lRow) (This)->lpVtbl->InstantMessage(This,lRow)
#define IMSIMContactList_EMail(This,lRow) (This)->lpVtbl->EMail(This,lRow)
#define IMSIMContactList_Invite(This,lRow) (This)->lpVtbl->Invite(This,lRow)
#define IMSIMContactList_Block(This,lRow) (This)->lpVtbl->Block(This,lRow)
#define IMSIMContactList_Unblock(This,lRow) (This)->lpVtbl->Unblock(This,lRow)
#define IMSIMContactList_get_Count(This,pnCount) (This)->lpVtbl->get_Count(This,pnCount)
#define IMSIMContactList_get_Item(This,Var,pSafeContact) (This)->lpVtbl->get_Item(This,Var,pSafeContact)
#define IMSIMContactList_get__NewEnum(This,ppunkEnum) (This)->lpVtbl->get__NewEnum(This,ppunkEnum)
#define IMSIMContactList_get_LocalState(This,pnState) (This)->lpVtbl->get_LocalState(This,pnState)
#define IMSIMContactList_put_LocalState(This,nState) (This)->lpVtbl->put_LocalState(This,nState)
#define IMSIMContactList_get_LocalLogonName(This,pval) (This)->lpVtbl->get_LocalLogonName(This,pval)
#endif
#endif
  HRESULT WINAPI IMSIMContactList_get_List_Proxy(IMSIMContactList *This,VARIANT *pvarList);
  void __RPC_STUB IMSIMContactList_get_List_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_put_List_Proxy(IMSIMContactList *This,VARIANT varList);
  void __RPC_STUB IMSIMContactList_put_List_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_Add_Proxy(IMSIMContactList *This,VARIANT vUser);
  void __RPC_STUB IMSIMContactList_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_Remove_Proxy(IMSIMContactList *This,VARIANT vUser);
  void __RPC_STUB IMSIMContactList_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_get_SelectedMenuOptions_Proxy(IMSIMContactList *This,__LONG32 lRow,__LONG32 *pVal);
  void __RPC_STUB IMSIMContactList_get_SelectedMenuOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_InstantMessage_Proxy(IMSIMContactList *This,__LONG32 lRow);
  void __RPC_STUB IMSIMContactList_InstantMessage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_EMail_Proxy(IMSIMContactList *This,__LONG32 lRow);
  void __RPC_STUB IMSIMContactList_EMail_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_Invite_Proxy(IMSIMContactList *This,__LONG32 lRow);
  void __RPC_STUB IMSIMContactList_Invite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_Block_Proxy(IMSIMContactList *This,__LONG32 lRow);
  void __RPC_STUB IMSIMContactList_Block_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_Unblock_Proxy(IMSIMContactList *This,__LONG32 lRow);
  void __RPC_STUB IMSIMContactList_Unblock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_get_Count_Proxy(IMSIMContactList *This,__LONG32 *pnCount);
  void __RPC_STUB IMSIMContactList_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_get_Item_Proxy(IMSIMContactList *This,VARIANT Var,VARIANT *pSafeContact);
  void __RPC_STUB IMSIMContactList_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_get__NewEnum_Proxy(IMSIMContactList *This,IUnknown **ppunkEnum);
  void __RPC_STUB IMSIMContactList_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_get_LocalState_Proxy(IMSIMContactList *This,__LONG32 *pnState);
  void __RPC_STUB IMSIMContactList_get_LocalState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_put_LocalState_Proxy(IMSIMContactList *This,__LONG32 nState);
  void __RPC_STUB IMSIMContactList_put_LocalState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMContactList_get_LocalLogonName_Proxy(IMSIMContactList *This,BSTR *pval);
  void __RPC_STUB IMSIMContactList_get_LocalLogonName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DIMContactListEvents_DISPINTERFACE_DEFINED__
#define __DIMContactListEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_DIMContactListEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DIMContactListEvents : public IDispatch {
  };
#else
  typedef struct DIMContactListEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DIMContactListEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DIMContactListEvents *This);
      ULONG (WINAPI *Release)(DIMContactListEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(DIMContactListEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(DIMContactListEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(DIMContactListEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(DIMContactListEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } DIMContactListEventsVtbl;
  struct DIMContactListEvents {
    CONST_VTBL struct DIMContactListEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DIMContactListEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DIMContactListEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DIMContactListEvents_Release(This) (This)->lpVtbl->Release(This)
#define DIMContactListEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define DIMContactListEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define DIMContactListEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define DIMContactListEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

  EXTERN_C const CLSID CLSID_MSIMContactList;
#ifdef __cplusplus
  class MSIMContactList;
#endif
  EXTERN_C const CLSID CLSID_IMSafeContact;
#ifdef __cplusplus
  class IMSafeContact;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
