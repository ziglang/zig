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

#ifndef __msimcsdk_h__
#define __msimcsdk_h__

#ifndef __IMSIMHost_FWD_DEFINED__
#define __IMSIMHost_FWD_DEFINED__
typedef struct IMSIMHost IMSIMHost;
#endif

#ifndef __DMSIMHostEvents_FWD_DEFINED__
#define __DMSIMHostEvents_FWD_DEFINED__
typedef struct DMSIMHostEvents DMSIMHostEvents;
#endif

#ifndef __IMSIMWindow_FWD_DEFINED__
#define __IMSIMWindow_FWD_DEFINED__
typedef struct IMSIMWindow IMSIMWindow;
#endif

#ifndef __DMSIMWindowEvents_FWD_DEFINED__
#define __DMSIMWindowEvents_FWD_DEFINED__
typedef struct DMSIMWindowEvents DMSIMWindowEvents;
#endif

#ifndef __IIMService_FWD_DEFINED__
#define __IIMService_FWD_DEFINED__
typedef struct IIMService IIMService;
#endif

#ifndef __DIMServiceEvents_FWD_DEFINED__
#define __DIMServiceEvents_FWD_DEFINED__
typedef struct DIMServiceEvents DIMServiceEvents;
#endif

#ifndef __IIMContact_FWD_DEFINED__
#define __IIMContact_FWD_DEFINED__
typedef struct IIMContact IIMContact;
#endif

#ifndef __IIMContacts_FWD_DEFINED__
#define __IIMContacts_FWD_DEFINED__
typedef struct IIMContacts IIMContacts;
#endif

#ifndef __IIMSession_FWD_DEFINED__
#define __IIMSession_FWD_DEFINED__
typedef struct IIMSession IIMSession;
#endif

#ifndef __IIMSessions_FWD_DEFINED__
#define __IIMSessions_FWD_DEFINED__
typedef struct IIMSessions IIMSessions;
#endif

#ifndef __MSIMHost_FWD_DEFINED__
#define __MSIMHost_FWD_DEFINED__
#ifdef __cplusplus
typedef class MSIMHost MSIMHost;
#else
typedef struct MSIMHost MSIMHost;
#endif
#endif

#ifndef __MSIMService_FWD_DEFINED__
#define __MSIMService_FWD_DEFINED__
#ifdef __cplusplus
typedef class MSIMService MSIMService;
#else
typedef struct MSIMService MSIMService;
#endif
#endif

#ifndef __MSIMWindow_FWD_DEFINED__
#define __MSIMWindow_FWD_DEFINED__
#ifdef __cplusplus
typedef class MSIMWindow MSIMWindow;
#else
typedef struct MSIMWindow MSIMWindow;
#endif
#endif

#ifndef __MSIMHostOption_FWD_DEFINED__
#define __MSIMHostOption_FWD_DEFINED__
#ifdef __cplusplus
typedef class MSIMHostOption MSIMHostOption;
#else
typedef struct MSIMHostOption MSIMHostOption;
#endif
#endif

#ifndef __MSIMHostProfiles_FWD_DEFINED__
#define __MSIMHostProfiles_FWD_DEFINED__
#ifdef __cplusplus
typedef class MSIMHostProfiles MSIMHostProfiles;
#else
typedef struct MSIMHostProfiles MSIMHostProfiles;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define MSIM_DISPID_ONLOGONRESULT 0x0E00
#define MSIM_DISPID_ONLOGOFF 0x0E01
#define MSIM_DISPID_ONLISTADDRESULT 0x0E02
#define MSIM_DISPID_ONLISTREMOVERESULT 0x0E03
#define MSIM_DISPID_ONFRIENDLYNAMECHANGERESULT 0x0E04
#define MSIM_DISPID_ONCONTACTSTATECHANGED 0x0E05
#define MSIM_DISPID_ONTEXTRECEIVED 0x0E06
#define MSIM_DISPID_ONLOCALFRIENDLYNAMECHANGERESULT 0x0E07
#define MSIM_DISPID_ONLOCALSTATECHANGERESULT 0x0E08
#define MSIM_DISPID_ONSENDRESULT 0x0E09
#define MSIM_DISPID_ONFINDRESULT 0x0E0A
#define MSIM_DISPID_ONSESSIONSTATECHANGE 0x0E0B
#define MSIM_DISPID_ONNEWSESSIONMEMBER 0x0E0C
#define MSIM_DISPID_ONSESSIONMEMBERLEAVE 0x0E0D
#define MSIM_DISPID_ONNEWSESSIONREQUEST 0x0E0F
#define MSIM_DISPID_ONINVITECONTACT 0x0E10
#define MSIM_DISPID_ONAPPSHUTDOWN 0x0E12
#define MSIM_DISPID_ON_NM_INVITERECEIVED 0x0E13
#define MSIM_DISPID_ON_NM_ACCEPTED 0x0E14
#define MSIM_DISPID_ON_NM_CANCELLED 0x0E15
#define MSIMWND_DISPID_ONMOVE 0x00E0
#define MSIMWND_DISPID_ONCLOSE 0x00E1
#define MSIMWND_DISPID_ONRESIZE 0x00E2
#define MSIMWND_DISPID_ONSHOW 0x00E3
#define MSIMWND_DISPID_ONFOCUS 0x00E4
#define MSIMHOSTEVENTS_DISPID_ONDOUBLECLICK 0xD
#define MSIMHOSTEVENTS_DISPID_ONSHUTDOWN 0xE
#define MSIMHOSTEVENTS_DISPID_ONCLICKUSERNOTIFY 0xF

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0001 {
    IM_E_CONNECT = 0x81000300 + 0x1,IM_E_INVALID_SERVER_NAME = 0x81000300 + 0x2,IM_E_INVALID_PASSWORD = 0x81000300 + 0x3,
    IM_E_ALREADY_LOGGED_ON = 0x81000300 + 0x4,IM_E_SERVER_VERSION = 0x81000300 + 0x5,IM_E_LOGON_TIMEOUT = 0x81000300 + 0x6,
    IM_E_LIST_FULL = 0x81000300 + 0x7,IM_E_AI_REJECT = 0x81000300 + 0x8,IM_E_AI_REJECT_NOT_INST = 0x81000300 + 0x9,
    IM_E_USER_NOT_FOUND = 0x81000300 + 0xa,IM_E_ALREADY_IN_LIST = 0x81000300 + 0xb,IM_E_DISCONNECTED = 0x81000300 + 0xc,
    IM_E_UNEXPECTED = 0x81000300 + 0xd,IM_E_SERVER_TOO_BUSY = 0x81000300 + 0xe,IM_E_INVALID_AUTH_PACKAGES = 0x81000300 + 0xf,
    IM_E_NEWER_CLIENT_AVAILABLE = 0x81000300 + 0x10,IM_E_AI_TIMEOUT = 0x81000300 + 0x11,IM_E_CANCEL = 0x81000300 + 0x12,
    IM_E_TOO_MANY_MATCHES = 0x81000300 + 0x13,IM_E_SERVER_UNAVAILABLE = 0x81000300 + 0x14,IM_E_LOGON_UI_ACTIVE = 0x81000300 + 0x15,
    IM_E_OPTION_UI_ACTIVE = 0x81000300 + 0x16,IM_E_CONTACT_UI_ACTIVE = 0x81000300 + 0x17,IM_E_LOGGED_ON = 0x81000300 + 0x19,
    IM_E_CONNECT_PROXY = 0x81000300 + 0x1a,IM_E_PROXY_AUTH = 0x81000300 + 0x1b,IM_E_PROXY_AUTH_TYPE = 0x81000300 + 0x1c,
    IM_E_INVALID_PROXY_NAME = 0x81000300 + 0x1d,IM_E_NOT_PRIMARY_SERVICE = 0x81000300 + 0x20,IM_E_TOO_MANY_SESSIONS = 0x81000300 + 0x21,
    IM_E_TOO_MANY_MESSAGES = 0x81000300 + 0x22,IM_E_REMOTE_LOGIN = 0x81000300 + 0x23,IM_E_INVALID_FRIENDLY_NAME = 0x81000300 + 0x24,
    IM_E_SESSION_FULL = 0x81000300 + 0x25,IM_E_NOT_ALLOWING_NEW_USERS = 0x81000300 + 0x26,IM_E_INVALID_DOMAIN = 0x81000300 + 0x27,
    IM_E_TCP_ERROR = 0x81000300 + 0x28,IM_E_SESSION_TIMEOUT = 0x81000300 + 0x29,IM_E_MULTIPOINT_SESSION_BEGIN_TIMEOUT = 0x81000300 + 0x2a,
    IM_E_MULTIPOINT_SESSION_END_TIMEOUT = 0x81000300 + 0x2b,IM_E_REVERSE_LIST_FULL = 0x81000300 + 0x2c,IM_E_SERVER_ERROR = 0x81000300 + 0x2d,
    IM_E_SYSTEM_CONFIG = 0x81000300 + 0x2e,IM_E_NO_DIRECTORY = 0x81000300 + 0x2f,IM_E_USER_CANCELED_LOGON = 0x81000300 + 0x50,
    IM_E_ALREADY_EXISTS = 0x81000300 + 0x51,IM_E_DOES_NOT_EXIST = 0x81000300 + 0x52,IM_S_LOGGED_ON = 0x1000300 + 0x19,
    IM_S_ALREADY_IN_THE_MODE = 0x1000300 + 0x1
  } IM_RESULTS;

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0002 {
    IM_MSG_TYPE_NO_RESULT = 0,IM_MSG_TYPE_ERRORS_ONLY = 1,IM_MSG_TYPE_ALL_RESULTS = 2
  } IM_MSG_TYPE;

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0003 {
    IM_INVITE_TYPE_REQUEST_LAUNCH = 0x1,IM_INVITE_TYPE_REQUEST_IP = 0x4,IM_INVITE_TYPE_PROVIDE_IP = 0x8
  } IM_INVITE_FLAGS;

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0004 {
    IM_STATE_UNKNOWN = 0,IM_STATE_OFFLINE = 0x1,IM_STATE_ONLINE = 0x2,IM_STATE_INVISIBLE = 0x6,IM_STATE_BUSY = 0xa,IM_STATE_BE_RIGHT_BACK = 0xe,IM_STATE_IDLE = 0x12,IM_STATE_AWAY = 0x22,IM_STATE_ON_THE_PHONE = 0x32,IM_STATE_OUT_TO_LUNCH = 0x42,IM_STATE_LOCAL_FINDING_SERVER = 0x100,IM_STATE_LOCAL_CONNECTING_TO_SERVER = 0x200,IM_STATE_LOCAL_SYNCHRONIZING_WITH_SERVER = 0x300,IM_STATE_LOCAL_DISCONNECTING_FROM_SERVER = 0x400
  } IM_STATE;

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0005 {
    IM_SSTATE_DISCONNECTED = 0,IM_SSTATE_CONNECTING = 1,IM_SSTATE_CONNECTED = 2,IM_SSTATE_DISCONNECTING = 3,IM_SSTATE_ERROR = 4
  } IM_SSTATE;

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0006 {
    MSIM_LIST_CONTACT = 0x1,MSIM_LIST_ALLOW = 0x2,MSIM_LIST_BLOCK = 0x4,MSIM_LIST_REVERSE = 0x8,MSIM_LIST_NOREF = 0x10,
    MSIM_LIST_SAVE = 0x20,MSIM_LIST_SYSTEM = 0x80
  } MSIM_LIST_TYPE;

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0007 {
    MSIMWND_WS_OVERLAPPED = 0,MSIMWND_WS_TOOL = 1,MSIMWND_WS_POPUP = 2,MSIMWND_WS_DIALOG = 3,MSIMWND_WS_SIZEBOX = 4
  } MSIMWND_STYLES;

  typedef enum __MIDL___MIDL_itf_msimcsdk_0000_0008 {
    MSIMWND_SIZE_MAXHIDE = 1,MSIMWND_SIZE_MAXIMIZED = 2,MSIMWND_SIZE_MAXSHOW = 3,MSIMWND_SIZE_MINIMIZED = 4,MSIMWND_SIZE_RESTORED = 5
  } MSIMWND_SIZE_TYPE;

#define MSIM_LIST_CONTACT 0x00000001
#define MSIM_LIST_ALLOW 0x00000002
#define MSIM_LIST_BLOCK 0x00000004
#define MSIM_LIST_REVERSE 0x00000008
#define MSIM_LIST_NOREF 0x00000010
#define MSIM_LIST_SAVE 0x00000020
#define MSIM_LIST_SYSTEM 0x00000080
#define MSIM_LIST_CONTACT_STR L"$$Messenger\\Contact"
#define MSIM_LIST_ALLOW_STR L"$$Messenger\\Allow"
#define MSIM_LIST_BLOCK_STR L"$$Messenger\\Block"
#define MSIM_LIST_REVERSE_STR L"$$Messenger\\Reverse"

  extern RPC_IF_HANDLE __MIDL_itf_msimcsdk_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msimcsdk_0000_v0_0_s_ifspec;

#ifndef __MSIMCliSDKLib_LIBRARY_DEFINED__
#define __MSIMCliSDKLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_MSIMCliSDKLib;
#ifndef __IMSIMHost_INTERFACE_DEFINED__
#define __IMSIMHost_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSIMHost;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSIMHost : public IDispatch {
  public:
    virtual HRESULT WINAPI CreateContext(VARIANT Profile,VARIANT Flags,IDispatch **ppInterface) = 0;
    virtual HRESULT WINAPI ShowOptions(void) = 0;
    virtual HRESULT WINAPI get_Profiles(IDispatch **pProfile) = 0;
    virtual HRESULT WINAPI HostWindow(BSTR bstrControl,__LONG32 lStyle,VARIANT_BOOL fShowOnTaskbar,IDispatch **ppMSIMWnd) = 0;
    virtual HRESULT WINAPI CreateProfile(BSTR bstrProfile,IDispatch **ppProfile) = 0;
    virtual HRESULT WINAPI PopupMessage(BSTR bstrMessage,__LONG32 nTimeout,VARIANT_BOOL fClick,__LONG32 *plCookie) = 0;
    virtual HRESULT WINAPI HostWindowEx(BSTR bstrControl,__LONG32 lStyle,__LONG32 lExStyle,IStream *pStream,IMSIMWindow **ppMSIMWindow,IUnknown **ppUnk,REFIID iidAdvise,IUnknown *punkSink) = 0;
  };
#else
  typedef struct IMSIMHostVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSIMHost *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSIMHost *This);
      ULONG (WINAPI *Release)(IMSIMHost *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMSIMHost *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMSIMHost *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMSIMHost *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMSIMHost *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *CreateContext)(IMSIMHost *This,VARIANT Profile,VARIANT Flags,IDispatch **ppInterface);
      HRESULT (WINAPI *ShowOptions)(IMSIMHost *This);
      HRESULT (WINAPI *get_Profiles)(IMSIMHost *This,IDispatch **pProfile);
      HRESULT (WINAPI *HostWindow)(IMSIMHost *This,BSTR bstrControl,__LONG32 lStyle,VARIANT_BOOL fShowOnTaskbar,IDispatch **ppMSIMWnd);
      HRESULT (WINAPI *CreateProfile)(IMSIMHost *This,BSTR bstrProfile,IDispatch **ppProfile);
      HRESULT (WINAPI *PopupMessage)(IMSIMHost *This,BSTR bstrMessage,__LONG32 nTimeout,VARIANT_BOOL fClick,__LONG32 *plCookie);
      HRESULT (WINAPI *HostWindowEx)(IMSIMHost *This,BSTR bstrControl,__LONG32 lStyle,__LONG32 lExStyle,IStream *pStream,IMSIMWindow **ppMSIMWindow,IUnknown **ppUnk,REFIID iidAdvise,IUnknown *punkSink);
    END_INTERFACE
  } IMSIMHostVtbl;
  struct IMSIMHost {
    CONST_VTBL struct IMSIMHostVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSIMHost_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSIMHost_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSIMHost_Release(This) (This)->lpVtbl->Release(This)
#define IMSIMHost_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMSIMHost_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMSIMHost_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMSIMHost_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMSIMHost_CreateContext(This,Profile,Flags,ppInterface) (This)->lpVtbl->CreateContext(This,Profile,Flags,ppInterface)
#define IMSIMHost_ShowOptions(This) (This)->lpVtbl->ShowOptions(This)
#define IMSIMHost_get_Profiles(This,pProfile) (This)->lpVtbl->get_Profiles(This,pProfile)
#define IMSIMHost_HostWindow(This,bstrControl,lStyle,fShowOnTaskbar,ppMSIMWnd) (This)->lpVtbl->HostWindow(This,bstrControl,lStyle,fShowOnTaskbar,ppMSIMWnd)
#define IMSIMHost_CreateProfile(This,bstrProfile,ppProfile) (This)->lpVtbl->CreateProfile(This,bstrProfile,ppProfile)
#define IMSIMHost_PopupMessage(This,bstrMessage,nTimeout,fClick,plCookie) (This)->lpVtbl->PopupMessage(This,bstrMessage,nTimeout,fClick,plCookie)
#define IMSIMHost_HostWindowEx(This,bstrControl,lStyle,lExStyle,pStream,ppMSIMWindow,ppUnk,iidAdvise,punkSink) (This)->lpVtbl->HostWindowEx(This,bstrControl,lStyle,lExStyle,pStream,ppMSIMWindow,ppUnk,iidAdvise,punkSink)
#endif
#endif
  HRESULT WINAPI IMSIMHost_CreateContext_Proxy(IMSIMHost *This,VARIANT Profile,VARIANT Flags,IDispatch **ppInterface);
  void __RPC_STUB IMSIMHost_CreateContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMHost_ShowOptions_Proxy(IMSIMHost *This);
  void __RPC_STUB IMSIMHost_ShowOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMHost_get_Profiles_Proxy(IMSIMHost *This,IDispatch **pProfile);
  void __RPC_STUB IMSIMHost_get_Profiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMHost_HostWindow_Proxy(IMSIMHost *This,BSTR bstrControl,__LONG32 lStyle,VARIANT_BOOL fShowOnTaskbar,IDispatch **ppMSIMWnd);
  void __RPC_STUB IMSIMHost_HostWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMHost_CreateProfile_Proxy(IMSIMHost *This,BSTR bstrProfile,IDispatch **ppProfile);
  void __RPC_STUB IMSIMHost_CreateProfile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMHost_PopupMessage_Proxy(IMSIMHost *This,BSTR bstrMessage,__LONG32 nTimeout,VARIANT_BOOL fClick,__LONG32 *plCookie);
  void __RPC_STUB IMSIMHost_PopupMessage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMHost_HostWindowEx_Proxy(IMSIMHost *This,BSTR bstrControl,__LONG32 lStyle,__LONG32 lExStyle,IStream *pStream,IMSIMWindow **ppMSIMWindow,IUnknown **ppUnk,REFIID iidAdvise,IUnknown *punkSink);
  void __RPC_STUB IMSIMHost_HostWindowEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DMSIMHostEvents_DISPINTERFACE_DEFINED__
#define __DMSIMHostEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_DMSIMHostEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DMSIMHostEvents : public IDispatch {
  };
#else
  typedef struct DMSIMHostEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DMSIMHostEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DMSIMHostEvents *This);
      ULONG (WINAPI *Release)(DMSIMHostEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(DMSIMHostEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(DMSIMHostEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(DMSIMHostEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(DMSIMHostEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } DMSIMHostEventsVtbl;
  struct DMSIMHostEvents {
    CONST_VTBL struct DMSIMHostEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DMSIMHostEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DMSIMHostEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DMSIMHostEvents_Release(This) (This)->lpVtbl->Release(This)
#define DMSIMHostEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define DMSIMHostEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define DMSIMHostEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define DMSIMHostEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __IMSIMWindow_INTERFACE_DEFINED__
#define __IMSIMWindow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSIMWindow;
#if defined(__cplusplus) && !defined(CINTERFACE)

  struct IMSIMWindow : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Object(IDispatch **ppDisp) = 0;
    virtual HRESULT WINAPI Move(__LONG32 nX,__LONG32 nY,__LONG32 nWidth,__LONG32 nHeight) = 0;
    virtual HRESULT WINAPI Focus(void) = 0;
    virtual HRESULT WINAPI Show(void) = 0;
    virtual HRESULT WINAPI Hide(void) = 0;
    virtual HRESULT WINAPI get_Title(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_Title(BSTR newVal) = 0;
    virtual HRESULT WINAPI Close(void) = 0;
    virtual HRESULT WINAPI get_HasFocus(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI get_IsVisible(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI GetPosition(VARIANT *pvarX,VARIANT *pvarY,VARIANT *pvarWidth,VARIANT *pvarHeight) = 0;
    virtual HRESULT WINAPI get_TopMost(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_TopMost(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_Window(__LONG32 *pVal) = 0;
  };
#else
  typedef struct IMSIMWindowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSIMWindow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSIMWindow *This);
      ULONG (WINAPI *Release)(IMSIMWindow *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMSIMWindow *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMSIMWindow *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMSIMWindow *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMSIMWindow *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Object)(IMSIMWindow *This,IDispatch **ppDisp);
      HRESULT (WINAPI *Move)(IMSIMWindow *This,__LONG32 nX,__LONG32 nY,__LONG32 nWidth,__LONG32 nHeight);
      HRESULT (WINAPI *Focus)(IMSIMWindow *This);
      HRESULT (WINAPI *Show)(IMSIMWindow *This);
      HRESULT (WINAPI *Hide)(IMSIMWindow *This);
      HRESULT (WINAPI *get_Title)(IMSIMWindow *This,BSTR *pVal);
      HRESULT (WINAPI *put_Title)(IMSIMWindow *This,BSTR newVal);
      HRESULT (WINAPI *Close)(IMSIMWindow *This);
      HRESULT (WINAPI *get_HasFocus)(IMSIMWindow *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *get_IsVisible)(IMSIMWindow *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *GetPosition)(IMSIMWindow *This,VARIANT *pvarX,VARIANT *pvarY,VARIANT *pvarWidth,VARIANT *pvarHeight);
      HRESULT (WINAPI *get_TopMost)(IMSIMWindow *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_TopMost)(IMSIMWindow *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_Window)(IMSIMWindow *This,__LONG32 *pVal);
    END_INTERFACE
  } IMSIMWindowVtbl;
  struct IMSIMWindow {
    CONST_VTBL struct IMSIMWindowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSIMWindow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSIMWindow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSIMWindow_Release(This) (This)->lpVtbl->Release(This)
#define IMSIMWindow_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMSIMWindow_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMSIMWindow_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMSIMWindow_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMSIMWindow_get_Object(This,ppDisp) (This)->lpVtbl->get_Object(This,ppDisp)
#define IMSIMWindow_Move(This,nX,nY,nWidth,nHeight) (This)->lpVtbl->Move(This,nX,nY,nWidth,nHeight)
#define IMSIMWindow_Focus(This) (This)->lpVtbl->Focus(This)
#define IMSIMWindow_Show(This) (This)->lpVtbl->Show(This)
#define IMSIMWindow_Hide(This) (This)->lpVtbl->Hide(This)
#define IMSIMWindow_get_Title(This,pVal) (This)->lpVtbl->get_Title(This,pVal)
#define IMSIMWindow_put_Title(This,newVal) (This)->lpVtbl->put_Title(This,newVal)
#define IMSIMWindow_Close(This) (This)->lpVtbl->Close(This)
#define IMSIMWindow_get_HasFocus(This,pVal) (This)->lpVtbl->get_HasFocus(This,pVal)
#define IMSIMWindow_get_IsVisible(This,pVal) (This)->lpVtbl->get_IsVisible(This,pVal)
#define IMSIMWindow_GetPosition(This,pvarX,pvarY,pvarWidth,pvarHeight) (This)->lpVtbl->GetPosition(This,pvarX,pvarY,pvarWidth,pvarHeight)
#define IMSIMWindow_get_TopMost(This,pVal) (This)->lpVtbl->get_TopMost(This,pVal)
#define IMSIMWindow_put_TopMost(This,newVal) (This)->lpVtbl->put_TopMost(This,newVal)
#define IMSIMWindow_get_Window(This,pVal) (This)->lpVtbl->get_Window(This,pVal)
#endif
#endif
  HRESULT WINAPI IMSIMWindow_get_Object_Proxy(IMSIMWindow *This,IDispatch **ppDisp);
  void __RPC_STUB IMSIMWindow_get_Object_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_Move_Proxy(IMSIMWindow *This,__LONG32 nX,__LONG32 nY,__LONG32 nWidth,__LONG32 nHeight);
  void __RPC_STUB IMSIMWindow_Move_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_Focus_Proxy(IMSIMWindow *This);
  void __RPC_STUB IMSIMWindow_Focus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_Show_Proxy(IMSIMWindow *This);
  void __RPC_STUB IMSIMWindow_Show_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_Hide_Proxy(IMSIMWindow *This);
  void __RPC_STUB IMSIMWindow_Hide_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_get_Title_Proxy(IMSIMWindow *This,BSTR *pVal);
  void __RPC_STUB IMSIMWindow_get_Title_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_put_Title_Proxy(IMSIMWindow *This,BSTR newVal);
  void __RPC_STUB IMSIMWindow_put_Title_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_Close_Proxy(IMSIMWindow *This);
  void __RPC_STUB IMSIMWindow_Close_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_get_HasFocus_Proxy(IMSIMWindow *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMWindow_get_HasFocus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_get_IsVisible_Proxy(IMSIMWindow *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMWindow_get_IsVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_GetPosition_Proxy(IMSIMWindow *This,VARIANT *pvarX,VARIANT *pvarY,VARIANT *pvarWidth,VARIANT *pvarHeight);
  void __RPC_STUB IMSIMWindow_GetPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_get_TopMost_Proxy(IMSIMWindow *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMSIMWindow_get_TopMost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_put_TopMost_Proxy(IMSIMWindow *This,VARIANT_BOOL newVal);
  void __RPC_STUB IMSIMWindow_put_TopMost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSIMWindow_get_Window_Proxy(IMSIMWindow *This,__LONG32 *pVal);
  void __RPC_STUB IMSIMWindow_get_Window_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DMSIMWindowEvents_DISPINTERFACE_DEFINED__
#define __DMSIMWindowEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_DMSIMWindowEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DMSIMWindowEvents : public IDispatch {
  };
#else
  typedef struct DMSIMWindowEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DMSIMWindowEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DMSIMWindowEvents *This);
      ULONG (WINAPI *Release)(DMSIMWindowEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(DMSIMWindowEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(DMSIMWindowEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(DMSIMWindowEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(DMSIMWindowEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } DMSIMWindowEventsVtbl;
  struct DMSIMWindowEvents {
    CONST_VTBL struct DMSIMWindowEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DMSIMWindowEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DMSIMWindowEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DMSIMWindowEvents_Release(This) (This)->lpVtbl->Release(This)
#define DMSIMWindowEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define DMSIMWindowEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define DMSIMWindowEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define DMSIMWindowEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __IIMService_INTERFACE_DEFINED__
#define __IIMService_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIMService;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIMService : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Server(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_IMAddress(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_FriendlyName(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_FriendlyName(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI Logoff(void) = 0;
    virtual HRESULT WINAPI FindContact(BSTR bstrFirstName,BSTR bstrLastName,BSTR bstrAlias,BSTR bstrCity,BSTR bstrState,BSTR bstrCountry,LONG *plCookie) = 0;
    virtual HRESULT WINAPI Logon(VARIANT varParameter) = 0;
    virtual HRESULT WINAPI CreateContact(BSTR bstrAlias,IDispatch **ppContact) = 0;
    virtual HRESULT WINAPI SetLocalState(__LONG32 lState,BSTR bstrDescription,VARIANT varData) = 0;
    virtual HRESULT WINAPI GetLocalState(VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData) = 0;
    virtual HRESULT WINAPI CreateIMSession(VARIANT varIMContact,IDispatch **ppIMSession) = 0;
    virtual HRESULT WINAPI get_IMSessions(IDispatch **ppIMSessions) = 0;
    virtual HRESULT WINAPI NewList(BSTR bstrListName,__LONG32 bfProperties,IDispatch **ppList) = 0;
    virtual HRESULT WINAPI List(BSTR bstrListName,IDispatch **ppList) = 0;
    virtual HRESULT WINAPI RemoveList(BSTR bstrListName) = 0;
    virtual HRESULT WINAPI SendNetMeetingInvite(VARIANT varContact,__LONG32 lInviteCookie,__LONG32 *plSendCookie) = 0;
    virtual HRESULT WINAPI SendNetMeetingAccept(VARIANT varContact,__LONG32 lInviteCookie,__LONG32 lInviteType,__LONG32 *plSendCookie) = 0;
    virtual HRESULT WINAPI SendNetMeetingCancel(VARIANT varContact,__LONG32 lInviteCookie,__LONG32 hrReason,__LONG32 *plSendCookie) = 0;
    virtual HRESULT WINAPI get_BlockByDefault(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_BlockByDefault(VARIANT_BOOL newVal) = 0;
  };
#else
  typedef struct IIMServiceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIMService *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIMService *This);
      ULONG (WINAPI *Release)(IIMService *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIMService *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIMService *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIMService *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIMService *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Server)(IIMService *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_IMAddress)(IIMService *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_FriendlyName)(IIMService *This,BSTR bstrName);
      HRESULT (WINAPI *get_FriendlyName)(IIMService *This,BSTR *pbstrName);
      HRESULT (WINAPI *Logoff)(IIMService *This);
      HRESULT (WINAPI *FindContact)(IIMService *This,BSTR bstrFirstName,BSTR bstrLastName,BSTR bstrAlias,BSTR bstrCity,BSTR bstrState,BSTR bstrCountry,LONG *plCookie);
      HRESULT (WINAPI *Logon)(IIMService *This,VARIANT varParameter);
      HRESULT (WINAPI *CreateContact)(IIMService *This,BSTR bstrAlias,IDispatch **ppContact);
      HRESULT (WINAPI *SetLocalState)(IIMService *This,__LONG32 lState,BSTR bstrDescription,VARIANT varData);
      HRESULT (WINAPI *GetLocalState)(IIMService *This,VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData);
      HRESULT (WINAPI *CreateIMSession)(IIMService *This,VARIANT varIMContact,IDispatch **ppIMSession);
      HRESULT (WINAPI *get_IMSessions)(IIMService *This,IDispatch **ppIMSessions);
      HRESULT (WINAPI *NewList)(IIMService *This,BSTR bstrListName,__LONG32 bfProperties,IDispatch **ppList);
      HRESULT (WINAPI *List)(IIMService *This,BSTR bstrListName,IDispatch **ppList);
      HRESULT (WINAPI *RemoveList)(IIMService *This,BSTR bstrListName);
      HRESULT (WINAPI *SendNetMeetingInvite)(IIMService *This,VARIANT varContact,__LONG32 lInviteCookie,__LONG32 *plSendCookie);
      HRESULT (WINAPI *SendNetMeetingAccept)(IIMService *This,VARIANT varContact,__LONG32 lInviteCookie,__LONG32 lInviteType,__LONG32 *plSendCookie);
      HRESULT (WINAPI *SendNetMeetingCancel)(IIMService *This,VARIANT varContact,__LONG32 lInviteCookie,__LONG32 hrReason,__LONG32 *plSendCookie);
      HRESULT (WINAPI *get_BlockByDefault)(IIMService *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_BlockByDefault)(IIMService *This,VARIANT_BOOL newVal);
    END_INTERFACE
  } IIMServiceVtbl;
  struct IIMService {
    CONST_VTBL struct IIMServiceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIMService_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIMService_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIMService_Release(This) (This)->lpVtbl->Release(This)
#define IIMService_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIMService_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIMService_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIMService_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIMService_get_Server(This,pbstrName) (This)->lpVtbl->get_Server(This,pbstrName)
#define IIMService_get_IMAddress(This,pbstrName) (This)->lpVtbl->get_IMAddress(This,pbstrName)
#define IIMService_put_FriendlyName(This,bstrName) (This)->lpVtbl->put_FriendlyName(This,bstrName)
#define IIMService_get_FriendlyName(This,pbstrName) (This)->lpVtbl->get_FriendlyName(This,pbstrName)
#define IIMService_Logoff(This) (This)->lpVtbl->Logoff(This)
#define IIMService_FindContact(This,bstrFirstName,bstrLastName,bstrAlias,bstrCity,bstrState,bstrCountry,plCookie) (This)->lpVtbl->FindContact(This,bstrFirstName,bstrLastName,bstrAlias,bstrCity,bstrState,bstrCountry,plCookie)
#define IIMService_Logon(This,varParameter) (This)->lpVtbl->Logon(This,varParameter)
#define IIMService_CreateContact(This,bstrAlias,ppContact) (This)->lpVtbl->CreateContact(This,bstrAlias,ppContact)
#define IIMService_SetLocalState(This,lState,bstrDescription,varData) (This)->lpVtbl->SetLocalState(This,lState,bstrDescription,varData)
#define IIMService_GetLocalState(This,pvarState,pvarDescription,pvarData) (This)->lpVtbl->GetLocalState(This,pvarState,pvarDescription,pvarData)
#define IIMService_CreateIMSession(This,varIMContact,ppIMSession) (This)->lpVtbl->CreateIMSession(This,varIMContact,ppIMSession)
#define IIMService_get_IMSessions(This,ppIMSessions) (This)->lpVtbl->get_IMSessions(This,ppIMSessions)
#define IIMService_NewList(This,bstrListName,bfProperties,ppList) (This)->lpVtbl->NewList(This,bstrListName,bfProperties,ppList)
#define IIMService_List(This,bstrListName,ppList) (This)->lpVtbl->List(This,bstrListName,ppList)
#define IIMService_RemoveList(This,bstrListName) (This)->lpVtbl->RemoveList(This,bstrListName)
#define IIMService_SendNetMeetingInvite(This,varContact,lInviteCookie,plSendCookie) (This)->lpVtbl->SendNetMeetingInvite(This,varContact,lInviteCookie,plSendCookie)
#define IIMService_SendNetMeetingAccept(This,varContact,lInviteCookie,lInviteType,plSendCookie) (This)->lpVtbl->SendNetMeetingAccept(This,varContact,lInviteCookie,lInviteType,plSendCookie)
#define IIMService_SendNetMeetingCancel(This,varContact,lInviteCookie,hrReason,plSendCookie) (This)->lpVtbl->SendNetMeetingCancel(This,varContact,lInviteCookie,hrReason,plSendCookie)
#define IIMService_get_BlockByDefault(This,pVal) (This)->lpVtbl->get_BlockByDefault(This,pVal)
#define IIMService_put_BlockByDefault(This,newVal) (This)->lpVtbl->put_BlockByDefault(This,newVal)
#endif
#endif
  HRESULT WINAPI IIMService_get_Server_Proxy(IIMService *This,BSTR *pbstrName);
  void __RPC_STUB IIMService_get_Server_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_get_IMAddress_Proxy(IIMService *This,BSTR *pbstrName);
  void __RPC_STUB IIMService_get_IMAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_put_FriendlyName_Proxy(IIMService *This,BSTR bstrName);
  void __RPC_STUB IIMService_put_FriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_get_FriendlyName_Proxy(IIMService *This,BSTR *pbstrName);
  void __RPC_STUB IIMService_get_FriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_Logoff_Proxy(IIMService *This);
  void __RPC_STUB IIMService_Logoff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_FindContact_Proxy(IIMService *This,BSTR bstrFirstName,BSTR bstrLastName,BSTR bstrAlias,BSTR bstrCity,BSTR bstrState,BSTR bstrCountry,LONG *plCookie);
  void __RPC_STUB IIMService_FindContact_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_Logon_Proxy(IIMService *This,VARIANT varParameter);
  void __RPC_STUB IIMService_Logon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_CreateContact_Proxy(IIMService *This,BSTR bstrAlias,IDispatch **ppContact);
  void __RPC_STUB IIMService_CreateContact_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_SetLocalState_Proxy(IIMService *This,__LONG32 lState,BSTR bstrDescription,VARIANT varData);
  void __RPC_STUB IIMService_SetLocalState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_GetLocalState_Proxy(IIMService *This,VARIANT *pvarState,VARIANT *pvarDescription,VARIANT *pvarData);
  void __RPC_STUB IIMService_GetLocalState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_CreateIMSession_Proxy(IIMService *This,VARIANT varIMContact,IDispatch **ppIMSession);
  void __RPC_STUB IIMService_CreateIMSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_get_IMSessions_Proxy(IIMService *This,IDispatch **ppIMSessions);
  void __RPC_STUB IIMService_get_IMSessions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_NewList_Proxy(IIMService *This,BSTR bstrListName,__LONG32 bfProperties,IDispatch **ppList);
  void __RPC_STUB IIMService_NewList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_List_Proxy(IIMService *This,BSTR bstrListName,IDispatch **ppList);
  void __RPC_STUB IIMService_List_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_RemoveList_Proxy(IIMService *This,BSTR bstrListName);
  void __RPC_STUB IIMService_RemoveList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_SendNetMeetingInvite_Proxy(IIMService *This,VARIANT varContact,__LONG32 lInviteCookie,__LONG32 *plSendCookie);
  void __RPC_STUB IIMService_SendNetMeetingInvite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_SendNetMeetingAccept_Proxy(IIMService *This,VARIANT varContact,__LONG32 lInviteCookie,__LONG32 lInviteType,__LONG32 *plSendCookie);
  void __RPC_STUB IIMService_SendNetMeetingAccept_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_SendNetMeetingCancel_Proxy(IIMService *This,VARIANT varContact,__LONG32 lInviteCookie,__LONG32 hrReason,__LONG32 *plSendCookie);
  void __RPC_STUB IIMService_SendNetMeetingCancel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_get_BlockByDefault_Proxy(IIMService *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IIMService_get_BlockByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMService_put_BlockByDefault_Proxy(IIMService *This,VARIANT_BOOL newVal);
  void __RPC_STUB IIMService_put_BlockByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DIMServiceEvents_DISPINTERFACE_DEFINED__
#define __DIMServiceEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_DIMServiceEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DIMServiceEvents : public IDispatch {
  };
#else
  typedef struct DIMServiceEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DIMServiceEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DIMServiceEvents *This);
      ULONG (WINAPI *Release)(DIMServiceEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(DIMServiceEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(DIMServiceEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(DIMServiceEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(DIMServiceEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } DIMServiceEventsVtbl;
  struct DIMServiceEvents {
    CONST_VTBL struct DIMServiceEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DIMServiceEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DIMServiceEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DIMServiceEvents_Release(This) (This)->lpVtbl->Release(This)
#define DIMServiceEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define DIMServiceEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define DIMServiceEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define DIMServiceEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __IIMContact_INTERFACE_DEFINED__
#define __IIMContact_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIMContact;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIMContact : public IDispatch {
  public:
    virtual HRESULT WINAPI put_FriendlyName(BSTR bstrFriendlyName) = 0;
    virtual HRESULT WINAPI get_FriendlyName(BSTR *pbstrFriendlyName) = 0;
    virtual HRESULT WINAPI get_EmailAddress(BSTR *pbstrEmailAddress) = 0;
    virtual HRESULT WINAPI get_State(IM_STATE *pmState) = 0;
    virtual HRESULT WINAPI get_LogonName(BSTR *pbstrLogonName) = 0;
    virtual HRESULT WINAPI SendText(BSTR bstrMsgHeader,BSTR bstrMsgText,IM_MSG_TYPE MsgType,LONG *plCookie) = 0;
    virtual HRESULT WINAPI get_Service(IDispatch **ppService) = 0;
  };
#else
  typedef struct IIMContactVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIMContact *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIMContact *This);
      ULONG (WINAPI *Release)(IIMContact *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIMContact *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIMContact *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIMContact *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIMContact *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_FriendlyName)(IIMContact *This,BSTR bstrFriendlyName);
      HRESULT (WINAPI *get_FriendlyName)(IIMContact *This,BSTR *pbstrFriendlyName);
      HRESULT (WINAPI *get_EmailAddress)(IIMContact *This,BSTR *pbstrEmailAddress);
      HRESULT (WINAPI *get_State)(IIMContact *This,IM_STATE *pmState);
      HRESULT (WINAPI *get_LogonName)(IIMContact *This,BSTR *pbstrLogonName);
      HRESULT (WINAPI *SendText)(IIMContact *This,BSTR bstrMsgHeader,BSTR bstrMsgText,IM_MSG_TYPE MsgType,LONG *plCookie);
      HRESULT (WINAPI *get_Service)(IIMContact *This,IDispatch **ppService);
    END_INTERFACE
  } IIMContactVtbl;
  struct IIMContact {
    CONST_VTBL struct IIMContactVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIMContact_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIMContact_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIMContact_Release(This) (This)->lpVtbl->Release(This)
#define IIMContact_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIMContact_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIMContact_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIMContact_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIMContact_put_FriendlyName(This,bstrFriendlyName) (This)->lpVtbl->put_FriendlyName(This,bstrFriendlyName)
#define IIMContact_get_FriendlyName(This,pbstrFriendlyName) (This)->lpVtbl->get_FriendlyName(This,pbstrFriendlyName)
#define IIMContact_get_EmailAddress(This,pbstrEmailAddress) (This)->lpVtbl->get_EmailAddress(This,pbstrEmailAddress)
#define IIMContact_get_State(This,pmState) (This)->lpVtbl->get_State(This,pmState)
#define IIMContact_get_LogonName(This,pbstrLogonName) (This)->lpVtbl->get_LogonName(This,pbstrLogonName)
#define IIMContact_SendText(This,bstrMsgHeader,bstrMsgText,MsgType,plCookie) (This)->lpVtbl->SendText(This,bstrMsgHeader,bstrMsgText,MsgType,plCookie)
#define IIMContact_get_Service(This,ppService) (This)->lpVtbl->get_Service(This,ppService)
#endif
#endif
  HRESULT WINAPI IIMContact_put_FriendlyName_Proxy(IIMContact *This,BSTR bstrFriendlyName);
  void __RPC_STUB IIMContact_put_FriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContact_get_FriendlyName_Proxy(IIMContact *This,BSTR *pbstrFriendlyName);
  void __RPC_STUB IIMContact_get_FriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContact_get_EmailAddress_Proxy(IIMContact *This,BSTR *pbstrEmailAddress);
  void __RPC_STUB IIMContact_get_EmailAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContact_get_State_Proxy(IIMContact *This,IM_STATE *pmState);
  void __RPC_STUB IIMContact_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContact_get_LogonName_Proxy(IIMContact *This,BSTR *pbstrLogonName);
  void __RPC_STUB IIMContact_get_LogonName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContact_SendText_Proxy(IIMContact *This,BSTR bstrMsgHeader,BSTR bstrMsgText,IM_MSG_TYPE MsgType,LONG *plCookie);
  void __RPC_STUB IIMContact_SendText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContact_get_Service_Proxy(IIMContact *This,IDispatch **ppService);
  void __RPC_STUB IIMContact_get_Service_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IIMContacts_INTERFACE_DEFINED__
#define __IIMContacts_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIMContacts;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIMContacts : public IDispatch {
  public:
    virtual HRESULT WINAPI Item(VARIANT varItem,IDispatch **ppContact) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI Add(IDispatch *pContact) = 0;
    virtual HRESULT WINAPI Remove(IDispatch *pContact) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_Name(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_Properties(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI get_Cookie(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppVal) = 0;
  };
#else
  typedef struct IIMContactsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIMContacts *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIMContacts *This);
      ULONG (WINAPI *Release)(IIMContacts *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIMContacts *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIMContacts *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIMContacts *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIMContacts *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Item)(IIMContacts *This,VARIANT varItem,IDispatch **ppContact);
      HRESULT (WINAPI *get_Count)(IIMContacts *This,__LONG32 *pVal);
      HRESULT (WINAPI *Add)(IIMContacts *This,IDispatch *pContact);
      HRESULT (WINAPI *Remove)(IIMContacts *This,IDispatch *pContact);
      HRESULT (WINAPI *get_Name)(IIMContacts *This,BSTR *pVal);
      HRESULT (WINAPI *put_Name)(IIMContacts *This,BSTR newVal);
      HRESULT (WINAPI *get_Properties)(IIMContacts *This,__LONG32 *pVal);
      HRESULT (WINAPI *get_Cookie)(IIMContacts *This,__LONG32 *pVal);
      HRESULT (WINAPI *get__NewEnum)(IIMContacts *This,IUnknown **ppVal);
    END_INTERFACE
  } IIMContactsVtbl;
  struct IIMContacts {
    CONST_VTBL struct IIMContactsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIMContacts_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIMContacts_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIMContacts_Release(This) (This)->lpVtbl->Release(This)
#define IIMContacts_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIMContacts_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIMContacts_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIMContacts_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIMContacts_Item(This,varItem,ppContact) (This)->lpVtbl->Item(This,varItem,ppContact)
#define IIMContacts_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#define IIMContacts_Add(This,pContact) (This)->lpVtbl->Add(This,pContact)
#define IIMContacts_Remove(This,pContact) (This)->lpVtbl->Remove(This,pContact)
#define IIMContacts_get_Name(This,pVal) (This)->lpVtbl->get_Name(This,pVal)
#define IIMContacts_put_Name(This,newVal) (This)->lpVtbl->put_Name(This,newVal)
#define IIMContacts_get_Properties(This,pVal) (This)->lpVtbl->get_Properties(This,pVal)
#define IIMContacts_get_Cookie(This,pVal) (This)->lpVtbl->get_Cookie(This,pVal)
#define IIMContacts_get__NewEnum(This,ppVal) (This)->lpVtbl->get__NewEnum(This,ppVal)
#endif
#endif
  HRESULT WINAPI IIMContacts_Item_Proxy(IIMContacts *This,VARIANT varItem,IDispatch **ppContact);
  void __RPC_STUB IIMContacts_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_get_Count_Proxy(IIMContacts *This,__LONG32 *pVal);
  void __RPC_STUB IIMContacts_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_Add_Proxy(IIMContacts *This,IDispatch *pContact);
  void __RPC_STUB IIMContacts_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_Remove_Proxy(IIMContacts *This,IDispatch *pContact);
  void __RPC_STUB IIMContacts_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_get_Name_Proxy(IIMContacts *This,BSTR *pVal);
  void __RPC_STUB IIMContacts_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_put_Name_Proxy(IIMContacts *This,BSTR newVal);
  void __RPC_STUB IIMContacts_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_get_Properties_Proxy(IIMContacts *This,__LONG32 *pVal);
  void __RPC_STUB IIMContacts_get_Properties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_get_Cookie_Proxy(IIMContacts *This,__LONG32 *pVal);
  void __RPC_STUB IIMContacts_get_Cookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMContacts_get__NewEnum_Proxy(IIMContacts *This,IUnknown **ppVal);
  void __RPC_STUB IIMContacts_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IIMSession_INTERFACE_DEFINED__
#define __IIMSession_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIMSession;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIMSession : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Members(IDispatch **ppMembers) = 0;
    virtual HRESULT WINAPI get_State(IM_SSTATE *psState) = 0;
    virtual HRESULT WINAPI get_Service(IDispatch **ppService) = 0;
    virtual HRESULT WINAPI get_Invitees(IDispatch **ppInvitees) = 0;
    virtual HRESULT WINAPI LeaveSession(void) = 0;
    virtual HRESULT WINAPI InviteContact(VARIANT vContact) = 0;
    virtual HRESULT WINAPI SendText(BSTR bstrMsgHeader,BSTR bstrMsgText,IM_MSG_TYPE MsgType,LONG *plCookie) = 0;
  };
#else
  typedef struct IIMSessionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIMSession *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIMSession *This);
      ULONG (WINAPI *Release)(IIMSession *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIMSession *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIMSession *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIMSession *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIMSession *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Members)(IIMSession *This,IDispatch **ppMembers);
      HRESULT (WINAPI *get_State)(IIMSession *This,IM_SSTATE *psState);
      HRESULT (WINAPI *get_Service)(IIMSession *This,IDispatch **ppService);
      HRESULT (WINAPI *get_Invitees)(IIMSession *This,IDispatch **ppInvitees);
      HRESULT (WINAPI *LeaveSession)(IIMSession *This);
      HRESULT (WINAPI *InviteContact)(IIMSession *This,VARIANT vContact);
      HRESULT (WINAPI *SendText)(IIMSession *This,BSTR bstrMsgHeader,BSTR bstrMsgText,IM_MSG_TYPE MsgType,LONG *plCookie);
    END_INTERFACE
  } IIMSessionVtbl;
  struct IIMSession {
    CONST_VTBL struct IIMSessionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIMSession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIMSession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIMSession_Release(This) (This)->lpVtbl->Release(This)
#define IIMSession_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIMSession_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIMSession_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIMSession_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIMSession_get_Members(This,ppMembers) (This)->lpVtbl->get_Members(This,ppMembers)
#define IIMSession_get_State(This,psState) (This)->lpVtbl->get_State(This,psState)
#define IIMSession_get_Service(This,ppService) (This)->lpVtbl->get_Service(This,ppService)
#define IIMSession_get_Invitees(This,ppInvitees) (This)->lpVtbl->get_Invitees(This,ppInvitees)
#define IIMSession_LeaveSession(This) (This)->lpVtbl->LeaveSession(This)
#define IIMSession_InviteContact(This,vContact) (This)->lpVtbl->InviteContact(This,vContact)
#define IIMSession_SendText(This,bstrMsgHeader,bstrMsgText,MsgType,plCookie) (This)->lpVtbl->SendText(This,bstrMsgHeader,bstrMsgText,MsgType,plCookie)
#endif
#endif
  HRESULT WINAPI IIMSession_get_Members_Proxy(IIMSession *This,IDispatch **ppMembers);
  void __RPC_STUB IIMSession_get_Members_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSession_get_State_Proxy(IIMSession *This,IM_SSTATE *psState);
  void __RPC_STUB IIMSession_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSession_get_Service_Proxy(IIMSession *This,IDispatch **ppService);
  void __RPC_STUB IIMSession_get_Service_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSession_get_Invitees_Proxy(IIMSession *This,IDispatch **ppInvitees);
  void __RPC_STUB IIMSession_get_Invitees_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSession_LeaveSession_Proxy(IIMSession *This);
  void __RPC_STUB IIMSession_LeaveSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSession_InviteContact_Proxy(IIMSession *This,VARIANT vContact);
  void __RPC_STUB IIMSession_InviteContact_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSession_SendText_Proxy(IIMSession *This,BSTR bstrMsgHeader,BSTR bstrMsgText,IM_MSG_TYPE MsgType,LONG *plCookie);
  void __RPC_STUB IIMSession_SendText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IIMSessions_INTERFACE_DEFINED__
#define __IIMSessions_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIMSessions;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIMSessions : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *pcSessions) = 0;
    virtual HRESULT WINAPI Item(__LONG32 Index,IDispatch **ppIMSession) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppUnknown) = 0;
  };
#else
  typedef struct IIMSessionsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIMSessions *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIMSessions *This);
      ULONG (WINAPI *Release)(IIMSessions *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIMSessions *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIMSessions *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIMSessions *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIMSessions *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(IIMSessions *This,__LONG32 *pcSessions);
      HRESULT (WINAPI *Item)(IIMSessions *This,__LONG32 Index,IDispatch **ppIMSession);
      HRESULT (WINAPI *get__NewEnum)(IIMSessions *This,IUnknown **ppUnknown);
    END_INTERFACE
  } IIMSessionsVtbl;
  struct IIMSessions {
    CONST_VTBL struct IIMSessionsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIMSessions_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIMSessions_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIMSessions_Release(This) (This)->lpVtbl->Release(This)
#define IIMSessions_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIMSessions_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIMSessions_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIMSessions_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIMSessions_get_Count(This,pcSessions) (This)->lpVtbl->get_Count(This,pcSessions)
#define IIMSessions_Item(This,Index,ppIMSession) (This)->lpVtbl->Item(This,Index,ppIMSession)
#define IIMSessions_get__NewEnum(This,ppUnknown) (This)->lpVtbl->get__NewEnum(This,ppUnknown)
#endif
#endif
  HRESULT WINAPI IIMSessions_get_Count_Proxy(IIMSessions *This,__LONG32 *pcSessions);
  void __RPC_STUB IIMSessions_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSessions_Item_Proxy(IIMSessions *This,__LONG32 Index,IDispatch **ppIMSession);
  void __RPC_STUB IIMSessions_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIMSessions_get__NewEnum_Proxy(IIMSessions *This,IUnknown **ppUnknown);
  void __RPC_STUB IIMSessions_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_MSIMHost;
#ifdef __cplusplus
  class MSIMHost;
#endif
  EXTERN_C const CLSID CLSID_MSIMService;
#ifdef __cplusplus
  class MSIMService;
#endif
  EXTERN_C const CLSID CLSID_MSIMWindow;
#ifdef __cplusplus
  class MSIMWindow;
#endif
  EXTERN_C const CLSID CLSID_MSIMHostOption;
#ifdef __cplusplus
  class MSIMHostOption;
#endif
  EXTERN_C const CLSID CLSID_MSIMHostProfiles;
#ifdef __cplusplus
  class MSIMHostProfiles;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
