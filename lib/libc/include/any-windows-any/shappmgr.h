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

#ifndef __shappmgr_h__
#define __shappmgr_h__

#ifndef __IShellApp_FWD_DEFINED__
#define __IShellApp_FWD_DEFINED__
typedef struct IShellApp IShellApp;
#endif

#ifndef __IPublishedApp_FWD_DEFINED__
#define __IPublishedApp_FWD_DEFINED__
typedef struct IPublishedApp IPublishedApp;
#endif

#ifndef __IEnumPublishedApps_FWD_DEFINED__
#define __IEnumPublishedApps_FWD_DEFINED__
typedef struct IEnumPublishedApps IEnumPublishedApps;
#endif

#ifndef __IAppPublisher_FWD_DEFINED__
#define __IAppPublisher_FWD_DEFINED__
typedef struct IAppPublisher IAppPublisher;
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "appmgmt.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _SHAPPMGR_H_
#define _SHAPPMGR_H_

  extern RPC_IF_HANDLE __MIDL_itf_shappmgr_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_shappmgr_0000_v0_0_s_ifspec;

#ifndef __IShellApp_INTERFACE_DEFINED__
#define __IShellApp_INTERFACE_DEFINED__
  typedef enum _tagAppInfoFlags {
    AIM_DISPLAYNAME = 0x1,AIM_VERSION = 0x2,AIM_PUBLISHER = 0x4,AIM_PRODUCTID = 0x8,AIM_REGISTEREDOWNER = 0x10,AIM_REGISTEREDCOMPANY = 0x20,
    AIM_LANGUAGE = 0x40,AIM_SUPPORTURL = 0x80,AIM_SUPPORTTELEPHONE = 0x100,AIM_HELPLINK = 0x200,AIM_INSTALLLOCATION = 0x400,AIM_INSTALLSOURCE = 0x800,
    AIM_INSTALLDATE = 0x1000,AIM_CONTACT = 0x4000,AIM_COMMENTS = 0x8000,AIM_IMAGE = 0x20000,AIM_READMEURL = 0x40000,AIM_UPDATEINFOURL = 0x80000
  } APPINFODATAFLAGS;

  typedef struct _AppInfoData {
    DWORD cbSize;
    DWORD dwMask;
    LPWSTR pszDisplayName;
    LPWSTR pszVersion;
    LPWSTR pszPublisher;
    LPWSTR pszProductID;
    LPWSTR pszRegisteredOwner;
    LPWSTR pszRegisteredCompany;
    LPWSTR pszLanguage;
    LPWSTR pszSupportUrl;
    LPWSTR pszSupportTelephone;
    LPWSTR pszHelpLink;
    LPWSTR pszInstallLocation;
    LPWSTR pszInstallSource;
    LPWSTR pszInstallDate;
    LPWSTR pszContact;
    LPWSTR pszComments;
    LPWSTR pszImage;
    LPWSTR pszReadmeUrl;
    LPWSTR pszUpdateInfoUrl;
  } APPINFODATA;

  typedef struct _AppInfoData *PAPPINFODATA;

  typedef enum _tagAppActionFlags {
    APPACTION_INSTALL = 0x1,APPACTION_UNINSTALL = 0x2,APPACTION_MODIFY = 0x4,APPACTION_REPAIR = 0x8,APPACTION_UPGRADE = 0x10,
    APPACTION_CANGETSIZE = 0x20,APPACTION_MODIFYREMOVE = 0x80,APPACTION_ADDLATER = 0x100,APPACTION_UNSCHEDULE = 0x200
  } APPACTIONFLAGS;

  typedef struct _tagSlowAppInfo {
    ULONGLONG ullSize;
    FILETIME ftLastUsed;
    int iTimesUsed;
    LPWSTR pszImage;
  } SLOWAPPINFO;

  typedef struct _tagSlowAppInfo *PSLOWAPPINFO;

  EXTERN_C const IID IID_IShellApp;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IShellApp : public IUnknown {
  public:
    virtual HRESULT WINAPI GetAppInfo(PAPPINFODATA pai) = 0;
    virtual HRESULT WINAPI GetPossibleActions(DWORD *pdwActions) = 0;
    virtual HRESULT WINAPI GetSlowAppInfo(PSLOWAPPINFO psaid) = 0;
    virtual HRESULT WINAPI GetCachedSlowAppInfo(PSLOWAPPINFO psaid) = 0;
    virtual HRESULT WINAPI IsInstalled(void) = 0;
  };
#else
  typedef struct IShellAppVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IShellApp *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IShellApp *This);
      ULONG (WINAPI *Release)(IShellApp *This);
      HRESULT (WINAPI *GetAppInfo)(IShellApp *This,PAPPINFODATA pai);
      HRESULT (WINAPI *GetPossibleActions)(IShellApp *This,DWORD *pdwActions);
      HRESULT (WINAPI *GetSlowAppInfo)(IShellApp *This,PSLOWAPPINFO psaid);
      HRESULT (WINAPI *GetCachedSlowAppInfo)(IShellApp *This,PSLOWAPPINFO psaid);
      HRESULT (WINAPI *IsInstalled)(IShellApp *This);
    END_INTERFACE
  } IShellAppVtbl;
  struct IShellApp {
    CONST_VTBL struct IShellAppVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IShellApp_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IShellApp_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IShellApp_Release(This) (This)->lpVtbl->Release(This)
#define IShellApp_GetAppInfo(This,pai) (This)->lpVtbl->GetAppInfo(This,pai)
#define IShellApp_GetPossibleActions(This,pdwActions) (This)->lpVtbl->GetPossibleActions(This,pdwActions)
#define IShellApp_GetSlowAppInfo(This,psaid) (This)->lpVtbl->GetSlowAppInfo(This,psaid)
#define IShellApp_GetCachedSlowAppInfo(This,psaid) (This)->lpVtbl->GetCachedSlowAppInfo(This,psaid)
#define IShellApp_IsInstalled(This) (This)->lpVtbl->IsInstalled(This)
#endif
#endif
  HRESULT WINAPI IShellApp_GetAppInfo_Proxy(IShellApp *This,PAPPINFODATA pai);
  void __RPC_STUB IShellApp_GetAppInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IShellApp_GetPossibleActions_Proxy(IShellApp *This,DWORD *pdwActions);
  void __RPC_STUB IShellApp_GetPossibleActions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IShellApp_GetSlowAppInfo_Proxy(IShellApp *This,PSLOWAPPINFO psaid);
  void __RPC_STUB IShellApp_GetSlowAppInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IShellApp_GetCachedSlowAppInfo_Proxy(IShellApp *This,PSLOWAPPINFO psaid);
  void __RPC_STUB IShellApp_GetCachedSlowAppInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IShellApp_IsInstalled_Proxy(IShellApp *This);
  void __RPC_STUB IShellApp_IsInstalled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPublishedApp_INTERFACE_DEFINED__
#define __IPublishedApp_INTERFACE_DEFINED__
  typedef enum _tagPublishedAppInfoFlags {
    PAI_SOURCE = 0x1,PAI_ASSIGNEDTIME = 0x2,PAI_PUBLISHEDTIME = 0x4,PAI_SCHEDULEDTIME = 0x8,PAI_EXPIRETIME = 0x10
  } PUBAPPINFOFLAGS;

  typedef struct _PubAppInfo {
    DWORD cbSize;
    DWORD dwMask;
    LPWSTR pszSource;
    SYSTEMTIME stAssigned;
    SYSTEMTIME stPublished;
    SYSTEMTIME stScheduled;
    SYSTEMTIME stExpire;
  } PUBAPPINFO;

  typedef struct _PubAppInfo *PPUBAPPINFO;

  EXTERN_C const IID IID_IPublishedApp;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPublishedApp : public IShellApp {
  public:
    virtual HRESULT WINAPI Install(LPSYSTEMTIME pstInstall) = 0;
    virtual HRESULT WINAPI GetPublishedAppInfo(PPUBAPPINFO ppai) = 0;
    virtual HRESULT WINAPI Unschedule(void) = 0;
  };
#else
  typedef struct IPublishedAppVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPublishedApp *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPublishedApp *This);
      ULONG (WINAPI *Release)(IPublishedApp *This);
      HRESULT (WINAPI *GetAppInfo)(IPublishedApp *This,PAPPINFODATA pai);
      HRESULT (WINAPI *GetPossibleActions)(IPublishedApp *This,DWORD *pdwActions);
      HRESULT (WINAPI *GetSlowAppInfo)(IPublishedApp *This,PSLOWAPPINFO psaid);
      HRESULT (WINAPI *GetCachedSlowAppInfo)(IPublishedApp *This,PSLOWAPPINFO psaid);
      HRESULT (WINAPI *IsInstalled)(IPublishedApp *This);
      HRESULT (WINAPI *Install)(IPublishedApp *This,LPSYSTEMTIME pstInstall);
      HRESULT (WINAPI *GetPublishedAppInfo)(IPublishedApp *This,PPUBAPPINFO ppai);
      HRESULT (WINAPI *Unschedule)(IPublishedApp *This);
    END_INTERFACE
  } IPublishedAppVtbl;
  struct IPublishedApp {
    CONST_VTBL struct IPublishedAppVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPublishedApp_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPublishedApp_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPublishedApp_Release(This) (This)->lpVtbl->Release(This)
#define IPublishedApp_GetAppInfo(This,pai) (This)->lpVtbl->GetAppInfo(This,pai)
#define IPublishedApp_GetPossibleActions(This,pdwActions) (This)->lpVtbl->GetPossibleActions(This,pdwActions)
#define IPublishedApp_GetSlowAppInfo(This,psaid) (This)->lpVtbl->GetSlowAppInfo(This,psaid)
#define IPublishedApp_GetCachedSlowAppInfo(This,psaid) (This)->lpVtbl->GetCachedSlowAppInfo(This,psaid)
#define IPublishedApp_IsInstalled(This) (This)->lpVtbl->IsInstalled(This)
#define IPublishedApp_Install(This,pstInstall) (This)->lpVtbl->Install(This,pstInstall)
#define IPublishedApp_GetPublishedAppInfo(This,ppai) (This)->lpVtbl->GetPublishedAppInfo(This,ppai)
#define IPublishedApp_Unschedule(This) (This)->lpVtbl->Unschedule(This)
#endif
#endif
  HRESULT WINAPI IPublishedApp_Install_Proxy(IPublishedApp *This,LPSYSTEMTIME pstInstall);
  void __RPC_STUB IPublishedApp_Install_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublishedApp_GetPublishedAppInfo_Proxy(IPublishedApp *This,PPUBAPPINFO ppai);
  void __RPC_STUB IPublishedApp_GetPublishedAppInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPublishedApp_Unschedule_Proxy(IPublishedApp *This);
  void __RPC_STUB IPublishedApp_Unschedule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumPublishedApps_INTERFACE_DEFINED__
#define __IEnumPublishedApps_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumPublishedApps;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumPublishedApps : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(IPublishedApp **pia) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
  };
#else
  typedef struct IEnumPublishedAppsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumPublishedApps *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumPublishedApps *This);
      ULONG (WINAPI *Release)(IEnumPublishedApps *This);
      HRESULT (WINAPI *Next)(IEnumPublishedApps *This,IPublishedApp **pia);
      HRESULT (WINAPI *Reset)(IEnumPublishedApps *This);
    END_INTERFACE
  } IEnumPublishedAppsVtbl;
  struct IEnumPublishedApps {
    CONST_VTBL struct IEnumPublishedAppsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumPublishedApps_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumPublishedApps_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumPublishedApps_Release(This) (This)->lpVtbl->Release(This)
#define IEnumPublishedApps_Next(This,pia) (This)->lpVtbl->Next(This,pia)
#define IEnumPublishedApps_Reset(This) (This)->lpVtbl->Reset(This)
#endif
#endif
  HRESULT WINAPI IEnumPublishedApps_Next_Proxy(IEnumPublishedApps *This,IPublishedApp **pia);
  void __RPC_STUB IEnumPublishedApps_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPublishedApps_Reset_Proxy(IEnumPublishedApps *This);
  void __RPC_STUB IEnumPublishedApps_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAppPublisher_INTERFACE_DEFINED__
#define __IAppPublisher_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAppPublisher;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAppPublisher : public IUnknown {
  public:
    virtual HRESULT WINAPI GetNumberOfCategories(DWORD *pdwCat) = 0;
    virtual HRESULT WINAPI GetCategories(APPCATEGORYINFOLIST *pAppCategoryList) = 0;
    virtual HRESULT WINAPI GetNumberOfApps(DWORD *pdwApps) = 0;
    virtual HRESULT WINAPI EnumApps(GUID *pAppCategoryId,IEnumPublishedApps **ppepa) = 0;
  };
#else
  typedef struct IAppPublisherVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAppPublisher *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAppPublisher *This);
      ULONG (WINAPI *Release)(IAppPublisher *This);
      HRESULT (WINAPI *GetNumberOfCategories)(IAppPublisher *This,DWORD *pdwCat);
      HRESULT (WINAPI *GetCategories)(IAppPublisher *This,APPCATEGORYINFOLIST *pAppCategoryList);
      HRESULT (WINAPI *GetNumberOfApps)(IAppPublisher *This,DWORD *pdwApps);
      HRESULT (WINAPI *EnumApps)(IAppPublisher *This,GUID *pAppCategoryId,IEnumPublishedApps **ppepa);
    END_INTERFACE
  } IAppPublisherVtbl;
  struct IAppPublisher {
    CONST_VTBL struct IAppPublisherVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAppPublisher_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAppPublisher_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAppPublisher_Release(This) (This)->lpVtbl->Release(This)
#define IAppPublisher_GetNumberOfCategories(This,pdwCat) (This)->lpVtbl->GetNumberOfCategories(This,pdwCat)
#define IAppPublisher_GetCategories(This,pAppCategoryList) (This)->lpVtbl->GetCategories(This,pAppCategoryList)
#define IAppPublisher_GetNumberOfApps(This,pdwApps) (This)->lpVtbl->GetNumberOfApps(This,pdwApps)
#define IAppPublisher_EnumApps(This,pAppCategoryId,ppepa) (This)->lpVtbl->EnumApps(This,pAppCategoryId,ppepa)
#endif
#endif
  HRESULT WINAPI IAppPublisher_GetNumberOfCategories_Proxy(IAppPublisher *This,DWORD *pdwCat);
  void __RPC_STUB IAppPublisher_GetNumberOfCategories_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppPublisher_GetCategories_Proxy(IAppPublisher *This,APPCATEGORYINFOLIST *pAppCategoryList);
  void __RPC_STUB IAppPublisher_GetCategories_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppPublisher_GetNumberOfApps_Proxy(IAppPublisher *This,DWORD *pdwApps);
  void __RPC_STUB IAppPublisher_GetNumberOfApps_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppPublisher_EnumApps_Proxy(IAppPublisher *This,GUID *pAppCategoryId,IEnumPublishedApps **ppepa);
  void __RPC_STUB IAppPublisher_EnumApps_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_shappmgr_0266_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_shappmgr_0266_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
