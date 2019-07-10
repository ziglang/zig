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

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __subsmgr_h__
#define __subsmgr_h__

#ifndef __IEnumItemProperties_FWD_DEFINED__
#define __IEnumItemProperties_FWD_DEFINED__
typedef struct IEnumItemProperties IEnumItemProperties;
#endif

#ifndef __ISubscriptionItem_FWD_DEFINED__
#define __ISubscriptionItem_FWD_DEFINED__
typedef struct ISubscriptionItem ISubscriptionItem;
#endif

#ifndef __IEnumSubscription_FWD_DEFINED__
#define __IEnumSubscription_FWD_DEFINED__
typedef struct IEnumSubscription IEnumSubscription;
#endif

#ifndef __ISubscriptionMgr_FWD_DEFINED__
#define __ISubscriptionMgr_FWD_DEFINED__
typedef struct ISubscriptionMgr ISubscriptionMgr;
#endif

#ifndef __ISubscriptionMgr2_FWD_DEFINED__
#define __ISubscriptionMgr2_FWD_DEFINED__
typedef struct ISubscriptionMgr2 ISubscriptionMgr2;
#endif

#ifndef __SubscriptionMgr_FWD_DEFINED__
#define __SubscriptionMgr_FWD_DEFINED__
#ifdef __cplusplus
typedef class SubscriptionMgr SubscriptionMgr;
#else
typedef struct SubscriptionMgr SubscriptionMgr;
#endif
#endif

#include "unknwn.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef GUID SUBSCRIPTIONCOOKIE;

  extern RPC_IF_HANDLE __MIDL_itf_subsmgr_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_subsmgr_0000_v0_0_s_ifspec;

#ifndef __IEnumItemProperties_INTERFACE_DEFINED__
#define __IEnumItemProperties_INTERFACE_DEFINED__
  typedef IEnumItemProperties *LPENUMITEMPROPERTIES;

  typedef struct _tagITEMPROP {
    VARIANT variantValue;
    LPWSTR pwszName;
  } ITEMPROP;

  typedef struct _tagITEMPROP *LPITEMPROP;

  EXTERN_C const IID IID_IEnumItemProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumItemProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITEMPROP *rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumItemProperties **ppenum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *pnCount) = 0;
  };
#else
  typedef struct IEnumItemPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumItemProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumItemProperties *This);
      ULONG (WINAPI *Release)(IEnumItemProperties *This);
      HRESULT (WINAPI *Next)(IEnumItemProperties *This,ULONG celt,ITEMPROP *rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumItemProperties *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumItemProperties *This);
      HRESULT (WINAPI *Clone)(IEnumItemProperties *This,IEnumItemProperties **ppenum);
      HRESULT (WINAPI *GetCount)(IEnumItemProperties *This,ULONG *pnCount);
    END_INTERFACE
  } IEnumItemPropertiesVtbl;
  struct IEnumItemProperties {
    CONST_VTBL struct IEnumItemPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumItemProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumItemProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumItemProperties_Release(This) (This)->lpVtbl->Release(This)
#define IEnumItemProperties_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumItemProperties_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumItemProperties_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumItemProperties_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#define IEnumItemProperties_GetCount(This,pnCount) (This)->lpVtbl->GetCount(This,pnCount)
#endif
#endif
  HRESULT WINAPI IEnumItemProperties_Next_Proxy(IEnumItemProperties *This,ULONG celt,ITEMPROP *rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumItemProperties_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumItemProperties_Skip_Proxy(IEnumItemProperties *This,ULONG celt);
  void __RPC_STUB IEnumItemProperties_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumItemProperties_Reset_Proxy(IEnumItemProperties *This);
  void __RPC_STUB IEnumItemProperties_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumItemProperties_Clone_Proxy(IEnumItemProperties *This,IEnumItemProperties **ppenum);
  void __RPC_STUB IEnumItemProperties_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumItemProperties_GetCount_Proxy(IEnumItemProperties *This,ULONG *pnCount);
  void __RPC_STUB IEnumItemProperties_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define SI_TEMPORARY 0x80000000

  extern RPC_IF_HANDLE __MIDL_itf_subsmgr_0264_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_subsmgr_0264_v0_0_s_ifspec;

#ifndef __ISubscriptionItem_INTERFACE_DEFINED__
#define __ISubscriptionItem_INTERFACE_DEFINED__
  typedef ISubscriptionItem *LPSUBSCRIPTIONITEM;

  typedef struct tagSUBSCRIPTIONITEMINFO {
    ULONG cbSize;
    DWORD dwFlags;
    DWORD dwPriority;
    SUBSCRIPTIONCOOKIE ScheduleGroup;
    CLSID clsidAgent;
  } SUBSCRIPTIONITEMINFO;

  EXTERN_C const IID IID_ISubscriptionItem;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISubscriptionItem : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCookie(SUBSCRIPTIONCOOKIE *pCookie) = 0;
    virtual HRESULT WINAPI GetSubscriptionItemInfo(SUBSCRIPTIONITEMINFO *pSubscriptionItemInfo) = 0;
    virtual HRESULT WINAPI SetSubscriptionItemInfo(const SUBSCRIPTIONITEMINFO *pSubscriptionItemInfo) = 0;
    virtual HRESULT WINAPI ReadProperties(ULONG nCount,const LPCWSTR rgwszName[],VARIANT rgValue[]) = 0;
    virtual HRESULT WINAPI WriteProperties(ULONG nCount,const LPCWSTR rgwszName[],const VARIANT rgValue[]) = 0;
    virtual HRESULT WINAPI EnumProperties(IEnumItemProperties **ppEnumItemProperties) = 0;
    virtual HRESULT WINAPI NotifyChanged(void) = 0;
  };
#else
  typedef struct ISubscriptionItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISubscriptionItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISubscriptionItem *This);
      ULONG (WINAPI *Release)(ISubscriptionItem *This);
      HRESULT (WINAPI *GetCookie)(ISubscriptionItem *This,SUBSCRIPTIONCOOKIE *pCookie);
      HRESULT (WINAPI *GetSubscriptionItemInfo)(ISubscriptionItem *This,SUBSCRIPTIONITEMINFO *pSubscriptionItemInfo);
      HRESULT (WINAPI *SetSubscriptionItemInfo)(ISubscriptionItem *This,const SUBSCRIPTIONITEMINFO *pSubscriptionItemInfo);
      HRESULT (WINAPI *ReadProperties)(ISubscriptionItem *This,ULONG nCount,const LPCWSTR rgwszName[],VARIANT rgValue[]);
      HRESULT (WINAPI *WriteProperties)(ISubscriptionItem *This,ULONG nCount,const LPCWSTR rgwszName[],const VARIANT rgValue[]);
      HRESULT (WINAPI *EnumProperties)(ISubscriptionItem *This,IEnumItemProperties **ppEnumItemProperties);
      HRESULT (WINAPI *NotifyChanged)(ISubscriptionItem *This);
    END_INTERFACE
  } ISubscriptionItemVtbl;
  struct ISubscriptionItem {
    CONST_VTBL struct ISubscriptionItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISubscriptionItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISubscriptionItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISubscriptionItem_Release(This) (This)->lpVtbl->Release(This)
#define ISubscriptionItem_GetCookie(This,pCookie) (This)->lpVtbl->GetCookie(This,pCookie)
#define ISubscriptionItem_GetSubscriptionItemInfo(This,pSubscriptionItemInfo) (This)->lpVtbl->GetSubscriptionItemInfo(This,pSubscriptionItemInfo)
#define ISubscriptionItem_SetSubscriptionItemInfo(This,pSubscriptionItemInfo) (This)->lpVtbl->SetSubscriptionItemInfo(This,pSubscriptionItemInfo)
#define ISubscriptionItem_ReadProperties(This,nCount,rgwszName,rgValue) (This)->lpVtbl->ReadProperties(This,nCount,rgwszName,rgValue)
#define ISubscriptionItem_WriteProperties(This,nCount,rgwszName,rgValue) (This)->lpVtbl->WriteProperties(This,nCount,rgwszName,rgValue)
#define ISubscriptionItem_EnumProperties(This,ppEnumItemProperties) (This)->lpVtbl->EnumProperties(This,ppEnumItemProperties)
#define ISubscriptionItem_NotifyChanged(This) (This)->lpVtbl->NotifyChanged(This)
#endif
#endif
  HRESULT WINAPI ISubscriptionItem_GetCookie_Proxy(ISubscriptionItem *This,SUBSCRIPTIONCOOKIE *pCookie);
  void __RPC_STUB ISubscriptionItem_GetCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionItem_GetSubscriptionItemInfo_Proxy(ISubscriptionItem *This,SUBSCRIPTIONITEMINFO *pSubscriptionItemInfo);
  void __RPC_STUB ISubscriptionItem_GetSubscriptionItemInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionItem_SetSubscriptionItemInfo_Proxy(ISubscriptionItem *This,const SUBSCRIPTIONITEMINFO *pSubscriptionItemInfo);
  void __RPC_STUB ISubscriptionItem_SetSubscriptionItemInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionItem_ReadProperties_Proxy(ISubscriptionItem *This,ULONG nCount,const LPCWSTR rgwszName[],VARIANT rgValue[]);
  void __RPC_STUB ISubscriptionItem_ReadProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionItem_WriteProperties_Proxy(ISubscriptionItem *This,ULONG nCount,const LPCWSTR rgwszName[],const VARIANT rgValue[]);
  void __RPC_STUB ISubscriptionItem_WriteProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionItem_EnumProperties_Proxy(ISubscriptionItem *This,IEnumItemProperties **ppEnumItemProperties);
  void __RPC_STUB ISubscriptionItem_EnumProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionItem_NotifyChanged_Proxy(ISubscriptionItem *This);
  void __RPC_STUB ISubscriptionItem_NotifyChanged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumSubscription_INTERFACE_DEFINED__
#define __IEnumSubscription_INTERFACE_DEFINED__
  typedef IEnumSubscription *LPENUMSUBSCRIPTION;

  EXTERN_C const IID IID_IEnumSubscription;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumSubscription : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,SUBSCRIPTIONCOOKIE *rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumSubscription **ppenum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *pnCount) = 0;
  };
#else
  typedef struct IEnumSubscriptionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumSubscription *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumSubscription *This);
      ULONG (WINAPI *Release)(IEnumSubscription *This);
      HRESULT (WINAPI *Next)(IEnumSubscription *This,ULONG celt,SUBSCRIPTIONCOOKIE *rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumSubscription *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumSubscription *This);
      HRESULT (WINAPI *Clone)(IEnumSubscription *This,IEnumSubscription **ppenum);
      HRESULT (WINAPI *GetCount)(IEnumSubscription *This,ULONG *pnCount);
    END_INTERFACE
  } IEnumSubscriptionVtbl;
  struct IEnumSubscription {
    CONST_VTBL struct IEnumSubscriptionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumSubscription_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumSubscription_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumSubscription_Release(This) (This)->lpVtbl->Release(This)
#define IEnumSubscription_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumSubscription_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumSubscription_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumSubscription_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#define IEnumSubscription_GetCount(This,pnCount) (This)->lpVtbl->GetCount(This,pnCount)
#endif
#endif
  HRESULT WINAPI IEnumSubscription_Next_Proxy(IEnumSubscription *This,ULONG celt,SUBSCRIPTIONCOOKIE *rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumSubscription_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumSubscription_Skip_Proxy(IEnumSubscription *This,ULONG celt);
  void __RPC_STUB IEnumSubscription_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumSubscription_Reset_Proxy(IEnumSubscription *This);
  void __RPC_STUB IEnumSubscription_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumSubscription_Clone_Proxy(IEnumSubscription *This,IEnumSubscription **ppenum);
  void __RPC_STUB IEnumSubscription_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumSubscription_GetCount_Proxy(IEnumSubscription *This,ULONG *pnCount);
  void __RPC_STUB IEnumSubscription_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __SubscriptionMgr_LIBRARY_DEFINED__
#define __SubscriptionMgr_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_SubscriptionMgr;
#ifndef __ISubscriptionMgr_INTERFACE_DEFINED__
#define __ISubscriptionMgr_INTERFACE_DEFINED__
  typedef enum SUBSCRIPTIONTYPE {
    SUBSTYPE_URL = 0,SUBSTYPE_CHANNEL = 1,SUBSTYPE_DESKTOPURL = 2,SUBSTYPE_EXTERNAL = 3,SUBSTYPE_DESKTOPCHANNEL = 4
  } SUBSCRIPTIONTYPE;

  typedef enum SUBSCRIPTIONINFOFLAGS {
    SUBSINFO_SCHEDULE = 0x1,SUBSINFO_RECURSE = 0x2,SUBSINFO_WEBCRAWL = 0x4,SUBSINFO_MAILNOT = 0x8,
    SUBSINFO_MAXSIZEKB = 0x10,SUBSINFO_USER = 0x20,SUBSINFO_PASSWORD = 0x40,SUBSINFO_TASKFLAGS = 0x100,
    SUBSINFO_GLEAM = 0x200,SUBSINFO_CHANGESONLY = 0x400,SUBSINFO_CHANNELFLAGS = 0x800,SUBSINFO_FRIENDLYNAME = 0x2000,
    SUBSINFO_NEEDPASSWORD = 0x4000,SUBSINFO_TYPE = 0x8000
  } SUBSCRIPTIONINFOFLAGS;

#define SUBSINFO_ALLFLAGS 0x0000EF7F

  typedef enum CREATESUBSCRIPTIONFLAGS {
    CREATESUBS_ADDTOFAVORITES = 0x1,CREATESUBS_FROMFAVORITES = 0x2,CREATESUBS_NOUI = 0x4,CREATESUBS_NOSAVE = 0x8,
    CREATESUBS_SOFTWAREUPDATE = 0x10
  } CREATESUBSCRIPTIONFLAGS;

  typedef enum SUBSCRIPTIONSCHEDULE {
    SUBSSCHED_AUTO = 0,SUBSSCHED_DAILY = 1,SUBSSCHED_WEEKLY = 2,SUBSSCHED_CUSTOM = 3,SUBSSCHED_MANUAL = 4
  } SUBSCRIPTIONSCHEDULE;

  typedef struct _tagSubscriptionInfo {
    DWORD cbSize;
    DWORD fUpdateFlags;
    SUBSCRIPTIONSCHEDULE schedule;
    CLSID customGroupCookie;
    LPVOID pTrigger;
    DWORD dwRecurseLevels;
    DWORD fWebcrawlerFlags;
    WINBOOL bMailNotification;
    WINBOOL bGleam;
    WINBOOL bChangesOnly;
    WINBOOL bNeedPassword;
    DWORD fChannelFlags;
    BSTR bstrUserName;
    BSTR bstrPassword;
    BSTR bstrFriendlyName;
    DWORD dwMaxSizeKB;
    SUBSCRIPTIONTYPE subType;
    DWORD fTaskFlags;
    DWORD dwReserved;
  } SUBSCRIPTIONINFO;

  typedef struct _tagSubscriptionInfo *LPSUBSCRIPTIONINFO;
  typedef struct _tagSubscriptionInfo *PSUBSCRIPTIONINFO;

  EXTERN_C const IID IID_ISubscriptionMgr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISubscriptionMgr : public IUnknown {
  public:
    virtual HRESULT WINAPI DeleteSubscription(LPCWSTR pwszURL,HWND hwnd) = 0;
    virtual HRESULT WINAPI UpdateSubscription(LPCWSTR pwszURL) = 0;
    virtual HRESULT WINAPI UpdateAll(void) = 0;
    virtual HRESULT WINAPI IsSubscribed(LPCWSTR pwszURL,WINBOOL *pfSubscribed) = 0;
    virtual HRESULT WINAPI GetSubscriptionInfo(LPCWSTR pwszURL,SUBSCRIPTIONINFO *pInfo) = 0;
    virtual HRESULT WINAPI GetDefaultInfo(SUBSCRIPTIONTYPE subType,SUBSCRIPTIONINFO *pInfo) = 0;
    virtual HRESULT WINAPI ShowSubscriptionProperties(LPCWSTR pwszURL,HWND hwnd) = 0;
    virtual HRESULT WINAPI CreateSubscription(HWND hwnd,LPCWSTR pwszURL,LPCWSTR pwszFriendlyName,DWORD dwFlags,SUBSCRIPTIONTYPE subsType,SUBSCRIPTIONINFO *pInfo) = 0;
  };
#else
  typedef struct ISubscriptionMgrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISubscriptionMgr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISubscriptionMgr *This);
      ULONG (WINAPI *Release)(ISubscriptionMgr *This);
      HRESULT (WINAPI *DeleteSubscription)(ISubscriptionMgr *This,LPCWSTR pwszURL,HWND hwnd);
      HRESULT (WINAPI *UpdateSubscription)(ISubscriptionMgr *This,LPCWSTR pwszURL);
      HRESULT (WINAPI *UpdateAll)(ISubscriptionMgr *This);
      HRESULT (WINAPI *IsSubscribed)(ISubscriptionMgr *This,LPCWSTR pwszURL,WINBOOL *pfSubscribed);
      HRESULT (WINAPI *GetSubscriptionInfo)(ISubscriptionMgr *This,LPCWSTR pwszURL,SUBSCRIPTIONINFO *pInfo);
      HRESULT (WINAPI *GetDefaultInfo)(ISubscriptionMgr *This,SUBSCRIPTIONTYPE subType,SUBSCRIPTIONINFO *pInfo);
      HRESULT (WINAPI *ShowSubscriptionProperties)(ISubscriptionMgr *This,LPCWSTR pwszURL,HWND hwnd);
      HRESULT (WINAPI *CreateSubscription)(ISubscriptionMgr *This,HWND hwnd,LPCWSTR pwszURL,LPCWSTR pwszFriendlyName,DWORD dwFlags,SUBSCRIPTIONTYPE subsType,SUBSCRIPTIONINFO *pInfo);
    END_INTERFACE
  } ISubscriptionMgrVtbl;
  struct ISubscriptionMgr {
    CONST_VTBL struct ISubscriptionMgrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISubscriptionMgr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISubscriptionMgr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISubscriptionMgr_Release(This) (This)->lpVtbl->Release(This)
#define ISubscriptionMgr_DeleteSubscription(This,pwszURL,hwnd) (This)->lpVtbl->DeleteSubscription(This,pwszURL,hwnd)
#define ISubscriptionMgr_UpdateSubscription(This,pwszURL) (This)->lpVtbl->UpdateSubscription(This,pwszURL)
#define ISubscriptionMgr_UpdateAll(This) (This)->lpVtbl->UpdateAll(This)
#define ISubscriptionMgr_IsSubscribed(This,pwszURL,pfSubscribed) (This)->lpVtbl->IsSubscribed(This,pwszURL,pfSubscribed)
#define ISubscriptionMgr_GetSubscriptionInfo(This,pwszURL,pInfo) (This)->lpVtbl->GetSubscriptionInfo(This,pwszURL,pInfo)
#define ISubscriptionMgr_GetDefaultInfo(This,subType,pInfo) (This)->lpVtbl->GetDefaultInfo(This,subType,pInfo)
#define ISubscriptionMgr_ShowSubscriptionProperties(This,pwszURL,hwnd) (This)->lpVtbl->ShowSubscriptionProperties(This,pwszURL,hwnd)
#define ISubscriptionMgr_CreateSubscription(This,hwnd,pwszURL,pwszFriendlyName,dwFlags,subsType,pInfo) (This)->lpVtbl->CreateSubscription(This,hwnd,pwszURL,pwszFriendlyName,dwFlags,subsType,pInfo)
#endif
#endif
  HRESULT WINAPI ISubscriptionMgr_DeleteSubscription_Proxy(ISubscriptionMgr *This,LPCWSTR pwszURL,HWND hwnd);
  void __RPC_STUB ISubscriptionMgr_DeleteSubscription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr_UpdateSubscription_Proxy(ISubscriptionMgr *This,LPCWSTR pwszURL);
  void __RPC_STUB ISubscriptionMgr_UpdateSubscription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr_UpdateAll_Proxy(ISubscriptionMgr *This);
  void __RPC_STUB ISubscriptionMgr_UpdateAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr_IsSubscribed_Proxy(ISubscriptionMgr *This,LPCWSTR pwszURL,WINBOOL *pfSubscribed);
  void __RPC_STUB ISubscriptionMgr_IsSubscribed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr_GetSubscriptionInfo_Proxy(ISubscriptionMgr *This,LPCWSTR pwszURL,SUBSCRIPTIONINFO *pInfo);
  void __RPC_STUB ISubscriptionMgr_GetSubscriptionInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr_GetDefaultInfo_Proxy(ISubscriptionMgr *This,SUBSCRIPTIONTYPE subType,SUBSCRIPTIONINFO *pInfo);
  void __RPC_STUB ISubscriptionMgr_GetDefaultInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr_ShowSubscriptionProperties_Proxy(ISubscriptionMgr *This,LPCWSTR pwszURL,HWND hwnd);
  void __RPC_STUB ISubscriptionMgr_ShowSubscriptionProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr_CreateSubscription_Proxy(ISubscriptionMgr *This,HWND hwnd,LPCWSTR pwszURL,LPCWSTR pwszFriendlyName,DWORD dwFlags,SUBSCRIPTIONTYPE subsType,SUBSCRIPTIONINFO *pInfo);
  void __RPC_STUB ISubscriptionMgr_CreateSubscription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISubscriptionMgr2_INTERFACE_DEFINED__
#define __ISubscriptionMgr2_INTERFACE_DEFINED__

#define RS_READY 0x00000001
#define RS_SUSPENDED 0x00000002
#define RS_UPDATING 0x00000004
#define RS_SUSPENDONIDLE 0x00010000
#define RS_MAYBOTHERUSER 0x00020000
#define RS_COMPLETED 0x80000000

#define SUBSMGRUPDATE_MINIMIZE 0x00000001
#define SUBSMGRUPDATE_MASK 0x00000001
#define SUBSMGRENUM_TEMP 0x00000001
#define SUBSMGRENUM_MASK 0x00000001

  EXTERN_C const IID IID_ISubscriptionMgr2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISubscriptionMgr2 : public ISubscriptionMgr {
  public:
    virtual HRESULT WINAPI GetItemFromURL(LPCWSTR pwszURL,ISubscriptionItem **ppSubscriptionItem) = 0;
    virtual HRESULT WINAPI GetItemFromCookie(const SUBSCRIPTIONCOOKIE *pSubscriptionCookie,ISubscriptionItem **ppSubscriptionItem) = 0;
    virtual HRESULT WINAPI GetSubscriptionRunState(DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies,DWORD *pdwRunState) = 0;
    virtual HRESULT WINAPI EnumSubscriptions(DWORD dwFlags,IEnumSubscription **ppEnumSubscriptions) = 0;
    virtual HRESULT WINAPI UpdateItems(DWORD dwFlags,DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies) = 0;
    virtual HRESULT WINAPI AbortItems(DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies) = 0;
    virtual HRESULT WINAPI AbortAll(void) = 0;
  };
#else
  typedef struct ISubscriptionMgr2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISubscriptionMgr2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISubscriptionMgr2 *This);
      ULONG (WINAPI *Release)(ISubscriptionMgr2 *This);
      HRESULT (WINAPI *DeleteSubscription)(ISubscriptionMgr2 *This,LPCWSTR pwszURL,HWND hwnd);
      HRESULT (WINAPI *UpdateSubscription)(ISubscriptionMgr2 *This,LPCWSTR pwszURL);
      HRESULT (WINAPI *UpdateAll)(ISubscriptionMgr2 *This);
      HRESULT (WINAPI *IsSubscribed)(ISubscriptionMgr2 *This,LPCWSTR pwszURL,WINBOOL *pfSubscribed);
      HRESULT (WINAPI *GetSubscriptionInfo)(ISubscriptionMgr2 *This,LPCWSTR pwszURL,SUBSCRIPTIONINFO *pInfo);
      HRESULT (WINAPI *GetDefaultInfo)(ISubscriptionMgr2 *This,SUBSCRIPTIONTYPE subType,SUBSCRIPTIONINFO *pInfo);
      HRESULT (WINAPI *ShowSubscriptionProperties)(ISubscriptionMgr2 *This,LPCWSTR pwszURL,HWND hwnd);
      HRESULT (WINAPI *CreateSubscription)(ISubscriptionMgr2 *This,HWND hwnd,LPCWSTR pwszURL,LPCWSTR pwszFriendlyName,DWORD dwFlags,SUBSCRIPTIONTYPE subsType,SUBSCRIPTIONINFO *pInfo);
      HRESULT (WINAPI *GetItemFromURL)(ISubscriptionMgr2 *This,LPCWSTR pwszURL,ISubscriptionItem **ppSubscriptionItem);
      HRESULT (WINAPI *GetItemFromCookie)(ISubscriptionMgr2 *This,const SUBSCRIPTIONCOOKIE *pSubscriptionCookie,ISubscriptionItem **ppSubscriptionItem);
      HRESULT (WINAPI *GetSubscriptionRunState)(ISubscriptionMgr2 *This,DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies,DWORD *pdwRunState);
      HRESULT (WINAPI *EnumSubscriptions)(ISubscriptionMgr2 *This,DWORD dwFlags,IEnumSubscription **ppEnumSubscriptions);
      HRESULT (WINAPI *UpdateItems)(ISubscriptionMgr2 *This,DWORD dwFlags,DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies);
      HRESULT (WINAPI *AbortItems)(ISubscriptionMgr2 *This,DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies);
      HRESULT (WINAPI *AbortAll)(ISubscriptionMgr2 *This);
    END_INTERFACE
  } ISubscriptionMgr2Vtbl;
  struct ISubscriptionMgr2 {
    CONST_VTBL struct ISubscriptionMgr2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISubscriptionMgr2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISubscriptionMgr2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISubscriptionMgr2_Release(This) (This)->lpVtbl->Release(This)
#define ISubscriptionMgr2_DeleteSubscription(This,pwszURL,hwnd) (This)->lpVtbl->DeleteSubscription(This,pwszURL,hwnd)
#define ISubscriptionMgr2_UpdateSubscription(This,pwszURL) (This)->lpVtbl->UpdateSubscription(This,pwszURL)
#define ISubscriptionMgr2_UpdateAll(This) (This)->lpVtbl->UpdateAll(This)
#define ISubscriptionMgr2_IsSubscribed(This,pwszURL,pfSubscribed) (This)->lpVtbl->IsSubscribed(This,pwszURL,pfSubscribed)
#define ISubscriptionMgr2_GetSubscriptionInfo(This,pwszURL,pInfo) (This)->lpVtbl->GetSubscriptionInfo(This,pwszURL,pInfo)
#define ISubscriptionMgr2_GetDefaultInfo(This,subType,pInfo) (This)->lpVtbl->GetDefaultInfo(This,subType,pInfo)
#define ISubscriptionMgr2_ShowSubscriptionProperties(This,pwszURL,hwnd) (This)->lpVtbl->ShowSubscriptionProperties(This,pwszURL,hwnd)
#define ISubscriptionMgr2_CreateSubscription(This,hwnd,pwszURL,pwszFriendlyName,dwFlags,subsType,pInfo) (This)->lpVtbl->CreateSubscription(This,hwnd,pwszURL,pwszFriendlyName,dwFlags,subsType,pInfo)
#define ISubscriptionMgr2_GetItemFromURL(This,pwszURL,ppSubscriptionItem) (This)->lpVtbl->GetItemFromURL(This,pwszURL,ppSubscriptionItem)
#define ISubscriptionMgr2_GetItemFromCookie(This,pSubscriptionCookie,ppSubscriptionItem) (This)->lpVtbl->GetItemFromCookie(This,pSubscriptionCookie,ppSubscriptionItem)
#define ISubscriptionMgr2_GetSubscriptionRunState(This,dwNumCookies,pCookies,pdwRunState) (This)->lpVtbl->GetSubscriptionRunState(This,dwNumCookies,pCookies,pdwRunState)
#define ISubscriptionMgr2_EnumSubscriptions(This,dwFlags,ppEnumSubscriptions) (This)->lpVtbl->EnumSubscriptions(This,dwFlags,ppEnumSubscriptions)
#define ISubscriptionMgr2_UpdateItems(This,dwFlags,dwNumCookies,pCookies) (This)->lpVtbl->UpdateItems(This,dwFlags,dwNumCookies,pCookies)
#define ISubscriptionMgr2_AbortItems(This,dwNumCookies,pCookies) (This)->lpVtbl->AbortItems(This,dwNumCookies,pCookies)
#define ISubscriptionMgr2_AbortAll(This) (This)->lpVtbl->AbortAll(This)
#endif
#endif
  HRESULT WINAPI ISubscriptionMgr2_GetItemFromURL_Proxy(ISubscriptionMgr2 *This,LPCWSTR pwszURL,ISubscriptionItem **ppSubscriptionItem);
  void __RPC_STUB ISubscriptionMgr2_GetItemFromURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr2_GetItemFromCookie_Proxy(ISubscriptionMgr2 *This,const SUBSCRIPTIONCOOKIE *pSubscriptionCookie,ISubscriptionItem **ppSubscriptionItem);
  void __RPC_STUB ISubscriptionMgr2_GetItemFromCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr2_GetSubscriptionRunState_Proxy(ISubscriptionMgr2 *This,DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies,DWORD *pdwRunState);
  void __RPC_STUB ISubscriptionMgr2_GetSubscriptionRunState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr2_EnumSubscriptions_Proxy(ISubscriptionMgr2 *This,DWORD dwFlags,IEnumSubscription **ppEnumSubscriptions);
  void __RPC_STUB ISubscriptionMgr2_EnumSubscriptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr2_UpdateItems_Proxy(ISubscriptionMgr2 *This,DWORD dwFlags,DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies);
  void __RPC_STUB ISubscriptionMgr2_UpdateItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr2_AbortItems_Proxy(ISubscriptionMgr2 *This,DWORD dwNumCookies,const SUBSCRIPTIONCOOKIE *pCookies);
  void __RPC_STUB ISubscriptionMgr2_AbortItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISubscriptionMgr2_AbortAll_Proxy(ISubscriptionMgr2 *This);
  void __RPC_STUB ISubscriptionMgr2_AbortAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_SubscriptionMgr;
#ifdef __cplusplus
  class SubscriptionMgr;
#endif
#endif

  EXTERN_C const CLSID CLSID_WebCrawlerAgent;
  EXTERN_C const CLSID CLSID_ChannelAgent;
  EXTERN_C const CLSID CLSID_DialAgent;
  EXTERN_C const CLSID CLSID_CDLAgent;
  typedef enum DELIVERY_AGENT_FLAGS {
    DELIVERY_AGENT_FLAG_NO_BROADCAST = 0x4,DELIVERY_AGENT_FLAG_NO_RESTRICTIONS = 0x8,DELIVERY_AGENT_FLAG_SILENT_DIAL = 0x10
  } DELIVERY_AGENT_FLAGS;

  typedef enum WEBCRAWL_RECURSEFLAGS {
    WEBCRAWL_DONT_MAKE_STICKY = 0x1,WEBCRAWL_GET_IMAGES = 0x2,WEBCRAWL_GET_VIDEOS = 0x4,WEBCRAWL_GET_BGSOUNDS = 0x8,WEBCRAWL_GET_CONTROLS = 0x10,
    WEBCRAWL_LINKS_ELSEWHERE = 0x20,WEBCRAWL_IGNORE_ROBOTSTXT = 0x80,WEBCRAWL_ONLY_LINKS_TO_HTML = 0x100
  } WEBCRAWL_RECURSEFLAGS;

  typedef enum CHANNEL_AGENT_FLAGS {
    CHANNEL_AGENT_DYNAMIC_SCHEDULE = 0x1,CHANNEL_AGENT_PRECACHE_SOME = 0x2,CHANNEL_AGENT_PRECACHE_ALL = 0x4,CHANNEL_AGENT_PRECACHE_SCRNSAVER = 0x8
  } CHANNEL_AGENT_FLAGS;

#define INET_E_AGENT_MAX_SIZE_EXCEEDED _HRESULT_TYPEDEF_(0x800C0F80)
#define INET_S_AGENT_PART_FAIL _HRESULT_TYPEDEF_(0x000C0F81)
#define INET_E_AGENT_CACHE_SIZE_EXCEEDED _HRESULT_TYPEDEF_(0x800C0F82)
#define INET_E_AGENT_CONNECTION_FAILED _HRESULT_TYPEDEF_(0x800C0F83)
#define INET_E_SCHEDULED_UPDATES_DISABLED _HRESULT_TYPEDEF_(0x800C0F84)
#define INET_E_SCHEDULED_UPDATES_RESTRICTED _HRESULT_TYPEDEF_(0x800C0F85)
#define INET_E_SCHEDULED_UPDATE_INTERVAL _HRESULT_TYPEDEF_(0x800C0F86)
#define INET_E_SCHEDULED_EXCLUDE_RANGE _HRESULT_TYPEDEF_(0x800C0F87)
#define INET_E_AGENT_EXCEEDING_CACHE_SIZE _HRESULT_TYPEDEF_(0x800C0F90)
#define INET_S_AGENT_INCREASED_CACHE_SIZE _HRESULT_TYPEDEF_(0x000C0F90)

  extern RPC_IF_HANDLE __MIDL_itf_subsmgr_0268_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_subsmgr_0268_v0_0_s_ifspec;

  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
