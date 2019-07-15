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

#ifndef __hlink_h__
#define __hlink_h__

#ifndef __IHlink_FWD_DEFINED__
#define __IHlink_FWD_DEFINED__
typedef struct IHlink IHlink;
#endif

#ifndef __IHlinkSite_FWD_DEFINED__
#define __IHlinkSite_FWD_DEFINED__
typedef struct IHlinkSite IHlinkSite;
#endif

#ifndef __IHlinkTarget_FWD_DEFINED__
#define __IHlinkTarget_FWD_DEFINED__
typedef struct IHlinkTarget IHlinkTarget;
#endif

#ifndef __IHlinkFrame_FWD_DEFINED__
#define __IHlinkFrame_FWD_DEFINED__
typedef struct IHlinkFrame IHlinkFrame;
#endif

#ifndef __IEnumHLITEM_FWD_DEFINED__
#define __IEnumHLITEM_FWD_DEFINED__
typedef struct IEnumHLITEM IEnumHLITEM;
#endif

#ifndef __IHlinkBrowseContext_FWD_DEFINED__
#define __IHlinkBrowseContext_FWD_DEFINED__
typedef struct IHlinkBrowseContext IHlinkBrowseContext;
#endif

#ifndef __IExtensionServices_FWD_DEFINED__
#define __IExtensionServices_FWD_DEFINED__
typedef struct IExtensionServices IExtensionServices;
#endif

#include "urlmon.h"
#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef HLINK_H
#define HLINK_H

#define SID_SHlinkFrame IID_IHlinkFrame
#define IID_IHlinkSource IID_IHlinkTarget
#define IHlinkSource IHlinkTarget
#define IHlinkSourceVtbl IHlinkTargetVtbl
#define LPHLINKSOURCE LPHLINKTARGET

#ifndef _HLINK_ERRORS_DEFINED
#define _HLINK_ERRORS_DEFINED
#define HLINK_E_FIRST (OLE_E_LAST+1)
#define HLINK_S_FIRST (OLE_S_LAST+1)
#define HLINK_S_DONTHIDE (HLINK_S_FIRST)
#endif

#define CFSTR_HYPERLINK (TEXT("Hyperlink"))

  STDAPI HlinkCreateFromMoniker(IMoniker *pimkTrgt,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,IHlinkSite *pihlsite,DWORD dwSiteData,IUnknown *piunkOuter,REFIID riid,void **ppvObj);
  STDAPI HlinkCreateFromString(LPCWSTR pwzTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,IHlinkSite *pihlsite,DWORD dwSiteData,IUnknown *piunkOuter,REFIID riid,void **ppvObj);
  STDAPI HlinkCreateFromData(IDataObject *piDataObj,IHlinkSite *pihlsite,DWORD dwSiteData,IUnknown *piunkOuter,REFIID riid,void **ppvObj);
  STDAPI HlinkQueryCreateFromData(IDataObject *piDataObj);
  STDAPI HlinkClone(IHlink *pihl,REFIID riid,IHlinkSite *pihlsiteForClone,DWORD dwSiteData,void **ppvObj);
  STDAPI HlinkCreateBrowseContext(IUnknown *piunkOuter,REFIID riid,void **ppvObj);
  STDAPI HlinkNavigateToStringReference(LPCWSTR pwzTarget,LPCWSTR pwzLocation,IHlinkSite *pihlsite,DWORD dwSiteData,IHlinkFrame *pihlframe,DWORD grfHLNF,LPBC pibc,IBindStatusCallback *pibsc,IHlinkBrowseContext *pihlbc);
  STDAPI HlinkNavigate(IHlink *pihl,IHlinkFrame *pihlframe,DWORD grfHLNF,LPBC pbc,IBindStatusCallback *pibsc,IHlinkBrowseContext *pihlbc);
  STDAPI HlinkOnNavigate(IHlinkFrame *pihlframe,IHlinkBrowseContext *pihlbc,DWORD grfHLNF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,ULONG *puHLID);
  STDAPI HlinkUpdateStackItem(IHlinkFrame *pihlframe,IHlinkBrowseContext *pihlbc,ULONG uHLID,IMoniker *pimkTrgt,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName);
  STDAPI HlinkOnRenameDocument(DWORD dwReserved,IHlinkBrowseContext *pihlbc,IMoniker *pimkOld,IMoniker *pimkNew);
  STDAPI HlinkResolveMonikerForData(LPMONIKER pimkReference,DWORD reserved,LPBC pibc,ULONG cFmtetc,FORMATETC *rgFmtetc,IBindStatusCallback *pibsc,LPMONIKER pimkBase);
  STDAPI HlinkResolveStringForData(LPCWSTR pwzReference,DWORD reserved,LPBC pibc,ULONG cFmtetc,FORMATETC *rgFmtetc,IBindStatusCallback *pibsc,LPMONIKER pimkBase);
  STDAPI HlinkParseDisplayName(LPBC pibc,LPCWSTR pwzDisplayName,WINBOOL fNoForceAbs,ULONG *pcchEaten,IMoniker **ppimk);
  STDAPI HlinkCreateExtensionServices(LPCWSTR pwzAdditionalHeaders,HWND phwnd,LPCWSTR pszUsername,LPCWSTR pszPassword,IUnknown *piunkOuter,REFIID riid,void **ppvObj);
  STDAPI HlinkPreprocessMoniker(LPBC pibc,IMoniker *pimkIn,IMoniker **ppimkOut);
  STDAPI OleSaveToStreamEx(IUnknown *piunk,IStream *pistm,WINBOOL fClearDirty);

  typedef enum _HLSR_NOREDEF10 {
    HLSR_HOME = 0,HLSR_SEARCHPAGE = 1,HLSR_HISTORYFOLDER = 2
  } HLSR;

  STDAPI HlinkSetSpecialReference(ULONG uReference,LPCWSTR pwzReference);
  STDAPI HlinkGetSpecialReference(ULONG uReference,LPWSTR *ppwzReference);

  typedef enum _HLSHORTCUTF__NOREDEF10 {
    HLSHORTCUTF_DEFAULT = 0,HLSHORTCUTF_DONTACTUALLYCREATE = 0x1,HLSHORTCUTF_USEFILENAMEFROMFRIENDLYNAME = 0x2,HLSHORTCUTF_USEUNIQUEFILENAME = 0x4,
    HLSHORTCUTF_MAYUSEEXISTINGSHORTCUT = 0x8
  } HLSHORTCUTF;

  STDAPI HlinkCreateShortcut(DWORD grfHLSHORTCUTF,IHlink *pihl,LPCWSTR pwzDir,LPCWSTR pwzFileName,LPWSTR *ppwzShortcutFile,DWORD dwReserved);
  STDAPI HlinkCreateShortcutFromMoniker(DWORD grfHLSHORTCUTF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzDir,LPCWSTR pwzFileName,LPWSTR *ppwzShortcutFile,DWORD dwReserved);
  STDAPI HlinkCreateShortcutFromString(DWORD grfHLSHORTCUTF,LPCWSTR pwzTarget,LPCWSTR pwzLocation,LPCWSTR pwzDir,LPCWSTR pwzFileName,LPWSTR *ppwzShortcutFile,DWORD dwReserved);
  STDAPI HlinkResolveShortcut(LPCWSTR pwzShortcutFileName,IHlinkSite *pihlsite,DWORD dwSiteData,IUnknown *piunkOuter,REFIID riid,void **ppvObj);
  STDAPI HlinkResolveShortcutToMoniker(LPCWSTR pwzShortcutFileName,IMoniker **ppimkTarget,LPWSTR *ppwzLocation);
  STDAPI HlinkResolveShortcutToString(LPCWSTR pwzShortcutFileName,LPWSTR *ppwzTarget,LPWSTR *ppwzLocation);
  STDAPI HlinkIsShortcut(LPCWSTR pwzFileName);
  STDAPI HlinkGetValueFromParams(LPCWSTR pwzParams,LPCWSTR pwzName,LPWSTR *ppwzValue);

  typedef enum _HLTRANSLATEF_NOREDEF10 {
    HLTRANSLATEF_DEFAULT = 0,HLTRANSLATEF_DONTAPPLYDEFAULTPREFIX = 0x1
  } HLTRANSLATEF;

  STDAPI HlinkTranslateURL(LPCWSTR pwzURL,DWORD grfFlags,LPWSTR *ppwzTranslatedURL);

#ifndef _LPHLINK_DEFINED
#define _LPHLINK_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0000_v0_0_s_ifspec;
#ifndef __IHlink_INTERFACE_DEFINED__
#define __IHlink_INTERFACE_DEFINED__
  typedef IHlink *LPHLINK;

  typedef enum __MIDL_IHlink_0001 {
    HLNF_INTERNALJUMP = 0x1,HLNF_OPENINNEWWINDOW = 0x2,HLNF_NAVIGATINGBACK = 0x4,HLNF_NAVIGATINGFORWARD = 0x8,HLNF_NAVIGATINGTOSTACKITEM = 0x10,
    HLNF_CREATENOHISTORY = 0x20
  } HLNF;

  typedef enum __MIDL_IHlink_0002 {
    HLINKGETREF_DEFAULT = 0,HLINKGETREF_ABSOLUTE = 1,HLINKGETREF_RELATIVE = 2
  } HLINKGETREF;

  typedef enum __MIDL_IHlink_0003 {
    HLFNAMEF_DEFAULT = 0,HLFNAMEF_TRYCACHE = 0x1,HLFNAMEF_TRYPRETTYTARGET = 0x2,HLFNAMEF_TRYFULLTARGET = 0x4,HLFNAMEF_TRYWIN95SHORTCUT = 0x8
  } HLFNAMEF;

  typedef enum __MIDL_IHlink_0004 {
    HLINKMISC_RELATIVE = 0x1
  } HLINKMISC;

  typedef enum __MIDL_IHlink_0005 {
    HLINKSETF_TARGET = 0x1,HLINKSETF_LOCATION = 0x2
  } HLINKSETF;

  EXTERN_C const IID IID_IHlink;

#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IHlink : public IUnknown {
  public:
    virtual HRESULT WINAPI SetHlinkSite(IHlinkSite *pihlSite,DWORD dwSiteData) = 0;
    virtual HRESULT WINAPI GetHlinkSite(IHlinkSite **ppihlSite,DWORD *pdwSiteData) = 0;
    virtual HRESULT WINAPI SetMonikerReference(DWORD grfHLSETF,IMoniker *pimkTarget,LPCWSTR pwzLocation) = 0;
    virtual HRESULT WINAPI GetMonikerReference(DWORD dwWhichRef,IMoniker **ppimkTarget,LPWSTR *ppwzLocation) = 0;
    virtual HRESULT WINAPI SetStringReference(DWORD grfHLSETF,LPCWSTR pwzTarget,LPCWSTR pwzLocation) = 0;
    virtual HRESULT WINAPI GetStringReference(DWORD dwWhichRef,LPWSTR *ppwzTarget,LPWSTR *ppwzLocation) = 0;
    virtual HRESULT WINAPI SetFriendlyName(LPCWSTR pwzFriendlyName) = 0;
    virtual HRESULT WINAPI GetFriendlyName(DWORD grfHLFNAMEF,LPWSTR *ppwzFriendlyName) = 0;
    virtual HRESULT WINAPI SetTargetFrameName(LPCWSTR pwzTargetFrameName) = 0;
    virtual HRESULT WINAPI GetTargetFrameName(LPWSTR *ppwzTargetFrameName) = 0;
    virtual HRESULT WINAPI GetMiscStatus(DWORD *pdwStatus) = 0;
    virtual HRESULT WINAPI Navigate(DWORD grfHLNF,LPBC pibc,IBindStatusCallback *pibsc,IHlinkBrowseContext *pihlbc) = 0;
    virtual HRESULT WINAPI SetAdditionalParams(LPCWSTR pwzAdditionalParams) = 0;
    virtual HRESULT WINAPI GetAdditionalParams(LPWSTR *ppwzAdditionalParams) = 0;
  };
#else
  typedef struct IHlinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IHlink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IHlink *This);
      ULONG (WINAPI *Release)(IHlink *This);
      HRESULT (WINAPI *SetHlinkSite)(IHlink *This,IHlinkSite *pihlSite,DWORD dwSiteData);
      HRESULT (WINAPI *GetHlinkSite)(IHlink *This,IHlinkSite **ppihlSite,DWORD *pdwSiteData);
      HRESULT (WINAPI *SetMonikerReference)(IHlink *This,DWORD grfHLSETF,IMoniker *pimkTarget,LPCWSTR pwzLocation);
      HRESULT (WINAPI *GetMonikerReference)(IHlink *This,DWORD dwWhichRef,IMoniker **ppimkTarget,LPWSTR *ppwzLocation);
      HRESULT (WINAPI *SetStringReference)(IHlink *This,DWORD grfHLSETF,LPCWSTR pwzTarget,LPCWSTR pwzLocation);
      HRESULT (WINAPI *GetStringReference)(IHlink *This,DWORD dwWhichRef,LPWSTR *ppwzTarget,LPWSTR *ppwzLocation);
      HRESULT (WINAPI *SetFriendlyName)(IHlink *This,LPCWSTR pwzFriendlyName);
      HRESULT (WINAPI *GetFriendlyName)(IHlink *This,DWORD grfHLFNAMEF,LPWSTR *ppwzFriendlyName);
      HRESULT (WINAPI *SetTargetFrameName)(IHlink *This,LPCWSTR pwzTargetFrameName);
      HRESULT (WINAPI *GetTargetFrameName)(IHlink *This,LPWSTR *ppwzTargetFrameName);
      HRESULT (WINAPI *GetMiscStatus)(IHlink *This,DWORD *pdwStatus);
      HRESULT (WINAPI *Navigate)(IHlink *This,DWORD grfHLNF,LPBC pibc,IBindStatusCallback *pibsc,IHlinkBrowseContext *pihlbc);
      HRESULT (WINAPI *SetAdditionalParams)(IHlink *This,LPCWSTR pwzAdditionalParams);
      HRESULT (WINAPI *GetAdditionalParams)(IHlink *This,LPWSTR *ppwzAdditionalParams);
    END_INTERFACE
  } IHlinkVtbl;
  struct IHlink {
    CONST_VTBL struct IHlinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IHlink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IHlink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IHlink_Release(This) (This)->lpVtbl->Release(This)
#define IHlink_SetHlinkSite(This,pihlSite,dwSiteData) (This)->lpVtbl->SetHlinkSite(This,pihlSite,dwSiteData)
#define IHlink_GetHlinkSite(This,ppihlSite,pdwSiteData) (This)->lpVtbl->GetHlinkSite(This,ppihlSite,pdwSiteData)
#define IHlink_SetMonikerReference(This,grfHLSETF,pimkTarget,pwzLocation) (This)->lpVtbl->SetMonikerReference(This,grfHLSETF,pimkTarget,pwzLocation)
#define IHlink_GetMonikerReference(This,dwWhichRef,ppimkTarget,ppwzLocation) (This)->lpVtbl->GetMonikerReference(This,dwWhichRef,ppimkTarget,ppwzLocation)
#define IHlink_SetStringReference(This,grfHLSETF,pwzTarget,pwzLocation) (This)->lpVtbl->SetStringReference(This,grfHLSETF,pwzTarget,pwzLocation)
#define IHlink_GetStringReference(This,dwWhichRef,ppwzTarget,ppwzLocation) (This)->lpVtbl->GetStringReference(This,dwWhichRef,ppwzTarget,ppwzLocation)
#define IHlink_SetFriendlyName(This,pwzFriendlyName) (This)->lpVtbl->SetFriendlyName(This,pwzFriendlyName)
#define IHlink_GetFriendlyName(This,grfHLFNAMEF,ppwzFriendlyName) (This)->lpVtbl->GetFriendlyName(This,grfHLFNAMEF,ppwzFriendlyName)
#define IHlink_SetTargetFrameName(This,pwzTargetFrameName) (This)->lpVtbl->SetTargetFrameName(This,pwzTargetFrameName)
#define IHlink_GetTargetFrameName(This,ppwzTargetFrameName) (This)->lpVtbl->GetTargetFrameName(This,ppwzTargetFrameName)
#define IHlink_GetMiscStatus(This,pdwStatus) (This)->lpVtbl->GetMiscStatus(This,pdwStatus)
#define IHlink_Navigate(This,grfHLNF,pibc,pibsc,pihlbc) (This)->lpVtbl->Navigate(This,grfHLNF,pibc,pibsc,pihlbc)
#define IHlink_SetAdditionalParams(This,pwzAdditionalParams) (This)->lpVtbl->SetAdditionalParams(This,pwzAdditionalParams)
#define IHlink_GetAdditionalParams(This,ppwzAdditionalParams) (This)->lpVtbl->GetAdditionalParams(This,ppwzAdditionalParams)
#endif
#endif
  HRESULT WINAPI IHlink_SetHlinkSite_Proxy(IHlink *This,IHlinkSite *pihlSite,DWORD dwSiteData);
  void __RPC_STUB IHlink_SetHlinkSite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_GetHlinkSite_Proxy(IHlink *This,IHlinkSite **ppihlSite,DWORD *pdwSiteData);
  void __RPC_STUB IHlink_GetHlinkSite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_SetMonikerReference_Proxy(IHlink *This,DWORD grfHLSETF,IMoniker *pimkTarget,LPCWSTR pwzLocation);
  void __RPC_STUB IHlink_SetMonikerReference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_GetMonikerReference_Proxy(IHlink *This,DWORD dwWhichRef,IMoniker **ppimkTarget,LPWSTR *ppwzLocation);
  void __RPC_STUB IHlink_GetMonikerReference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_SetStringReference_Proxy(IHlink *This,DWORD grfHLSETF,LPCWSTR pwzTarget,LPCWSTR pwzLocation);
  void __RPC_STUB IHlink_SetStringReference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_GetStringReference_Proxy(IHlink *This,DWORD dwWhichRef,LPWSTR *ppwzTarget,LPWSTR *ppwzLocation);
  void __RPC_STUB IHlink_GetStringReference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_SetFriendlyName_Proxy(IHlink *This,LPCWSTR pwzFriendlyName);
  void __RPC_STUB IHlink_SetFriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_GetFriendlyName_Proxy(IHlink *This,DWORD grfHLFNAMEF,LPWSTR *ppwzFriendlyName);
  void __RPC_STUB IHlink_GetFriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_SetTargetFrameName_Proxy(IHlink *This,LPCWSTR pwzTargetFrameName);
  void __RPC_STUB IHlink_SetTargetFrameName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_GetTargetFrameName_Proxy(IHlink *This,LPWSTR *ppwzTargetFrameName);
  void __RPC_STUB IHlink_GetTargetFrameName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_GetMiscStatus_Proxy(IHlink *This,DWORD *pdwStatus);
  void __RPC_STUB IHlink_GetMiscStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_Navigate_Proxy(IHlink *This,DWORD grfHLNF,LPBC pibc,IBindStatusCallback *pibsc,IHlinkBrowseContext *pihlbc);
  void __RPC_STUB IHlink_Navigate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_SetAdditionalParams_Proxy(IHlink *This,LPCWSTR pwzAdditionalParams);
  void __RPC_STUB IHlink_SetAdditionalParams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlink_GetAdditionalParams_Proxy(IHlink *This,LPWSTR *ppwzAdditionalParams);
  void __RPC_STUB IHlink_GetAdditionalParams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPHLINKSITE_DEFINED
#define _LPHLINKSITE_DEFINED
  EXTERN_C const GUID SID_SContainer;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0217_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0217_v0_0_s_ifspec;
#ifndef __IHlinkSite_INTERFACE_DEFINED__
#define __IHlinkSite_INTERFACE_DEFINED__
  typedef IHlinkSite *LPHLINKSITE;

  typedef enum __MIDL_IHlinkSite_0001 {
    HLINKWHICHMK_CONTAINER = 1,HLINKWHICHMK_BASE = 2
  } HLINKWHICHMK;

  EXTERN_C const IID IID_IHlinkSite;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IHlinkSite : public IUnknown {
  public:
    virtual HRESULT WINAPI QueryService(DWORD dwSiteData,REFGUID guidService,REFIID riid,IUnknown **ppiunk) = 0;
    virtual HRESULT WINAPI GetMoniker(DWORD dwSiteData,DWORD dwAssign,DWORD dwWhich,IMoniker **ppimk) = 0;
    virtual HRESULT WINAPI ReadyToNavigate(DWORD dwSiteData,DWORD dwReserved) = 0;
    virtual HRESULT WINAPI OnNavigationComplete(DWORD dwSiteData,DWORD dwreserved,HRESULT hrError,LPCWSTR pwzError) = 0;
  };
#else
  typedef struct IHlinkSiteVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IHlinkSite *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IHlinkSite *This);
      ULONG (WINAPI *Release)(IHlinkSite *This);
      HRESULT (WINAPI *QueryService)(IHlinkSite *This,DWORD dwSiteData,REFGUID guidService,REFIID riid,IUnknown **ppiunk);
      HRESULT (WINAPI *GetMoniker)(IHlinkSite *This,DWORD dwSiteData,DWORD dwAssign,DWORD dwWhich,IMoniker **ppimk);
      HRESULT (WINAPI *ReadyToNavigate)(IHlinkSite *This,DWORD dwSiteData,DWORD dwReserved);
      HRESULT (WINAPI *OnNavigationComplete)(IHlinkSite *This,DWORD dwSiteData,DWORD dwreserved,HRESULT hrError,LPCWSTR pwzError);
    END_INTERFACE
  } IHlinkSiteVtbl;
  struct IHlinkSite {
    CONST_VTBL struct IHlinkSiteVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IHlinkSite_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IHlinkSite_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IHlinkSite_Release(This) (This)->lpVtbl->Release(This)
#define IHlinkSite_QueryService(This,dwSiteData,guidService,riid,ppiunk) (This)->lpVtbl->QueryService(This,dwSiteData,guidService,riid,ppiunk)
#define IHlinkSite_GetMoniker(This,dwSiteData,dwAssign,dwWhich,ppimk) (This)->lpVtbl->GetMoniker(This,dwSiteData,dwAssign,dwWhich,ppimk)
#define IHlinkSite_ReadyToNavigate(This,dwSiteData,dwReserved) (This)->lpVtbl->ReadyToNavigate(This,dwSiteData,dwReserved)
#define IHlinkSite_OnNavigationComplete(This,dwSiteData,dwreserved,hrError,pwzError) (This)->lpVtbl->OnNavigationComplete(This,dwSiteData,dwreserved,hrError,pwzError)
#endif
#endif
  HRESULT WINAPI IHlinkSite_QueryService_Proxy(IHlinkSite *This,DWORD dwSiteData,REFGUID guidService,REFIID riid,IUnknown **ppiunk);
  void __RPC_STUB IHlinkSite_QueryService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkSite_GetMoniker_Proxy(IHlinkSite *This,DWORD dwSiteData,DWORD dwAssign,DWORD dwWhich,IMoniker **ppimk);
  void __RPC_STUB IHlinkSite_GetMoniker_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkSite_ReadyToNavigate_Proxy(IHlinkSite *This,DWORD dwSiteData,DWORD dwReserved);
  void __RPC_STUB IHlinkSite_ReadyToNavigate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkSite_OnNavigationComplete_Proxy(IHlinkSite *This,DWORD dwSiteData,DWORD dwreserved,HRESULT hrError,LPCWSTR pwzError);
  void __RPC_STUB IHlinkSite_OnNavigationComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPHLINKTARGET_DEFINED
#define _LPHLINKTARGET_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0218_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0218_v0_0_s_ifspec;
#ifndef __IHlinkTarget_INTERFACE_DEFINED__
#define __IHlinkTarget_INTERFACE_DEFINED__
  typedef IHlinkTarget *LPHLINKTARGET;
  EXTERN_C const IID IID_IHlinkTarget;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IHlinkTarget : public IUnknown {
  public:
    virtual HRESULT WINAPI SetBrowseContext(IHlinkBrowseContext *pihlbc) = 0;
    virtual HRESULT WINAPI GetBrowseContext(IHlinkBrowseContext **ppihlbc) = 0;
    virtual HRESULT WINAPI Navigate(DWORD grfHLNF,LPCWSTR pwzJumpLocation) = 0;
    virtual HRESULT WINAPI GetMoniker(LPCWSTR pwzLocation,DWORD dwAssign,IMoniker **ppimkLocation) = 0;
    virtual HRESULT WINAPI GetFriendlyName(LPCWSTR pwzLocation,LPWSTR *ppwzFriendlyName) = 0;
  };
#else
  typedef struct IHlinkTargetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IHlinkTarget *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IHlinkTarget *This);
      ULONG (WINAPI *Release)(IHlinkTarget *This);
      HRESULT (WINAPI *SetBrowseContext)(IHlinkTarget *This,IHlinkBrowseContext *pihlbc);
      HRESULT (WINAPI *GetBrowseContext)(IHlinkTarget *This,IHlinkBrowseContext **ppihlbc);
      HRESULT (WINAPI *Navigate)(IHlinkTarget *This,DWORD grfHLNF,LPCWSTR pwzJumpLocation);
      HRESULT (WINAPI *GetMoniker)(IHlinkTarget *This,LPCWSTR pwzLocation,DWORD dwAssign,IMoniker **ppimkLocation);
      HRESULT (WINAPI *GetFriendlyName)(IHlinkTarget *This,LPCWSTR pwzLocation,LPWSTR *ppwzFriendlyName);
    END_INTERFACE
  } IHlinkTargetVtbl;
  struct IHlinkTarget {
    CONST_VTBL struct IHlinkTargetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IHlinkTarget_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IHlinkTarget_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IHlinkTarget_Release(This) (This)->lpVtbl->Release(This)
#define IHlinkTarget_SetBrowseContext(This,pihlbc) (This)->lpVtbl->SetBrowseContext(This,pihlbc)
#define IHlinkTarget_GetBrowseContext(This,ppihlbc) (This)->lpVtbl->GetBrowseContext(This,ppihlbc)
#define IHlinkTarget_Navigate(This,grfHLNF,pwzJumpLocation) (This)->lpVtbl->Navigate(This,grfHLNF,pwzJumpLocation)
#define IHlinkTarget_GetMoniker(This,pwzLocation,dwAssign,ppimkLocation) (This)->lpVtbl->GetMoniker(This,pwzLocation,dwAssign,ppimkLocation)
#define IHlinkTarget_GetFriendlyName(This,pwzLocation,ppwzFriendlyName) (This)->lpVtbl->GetFriendlyName(This,pwzLocation,ppwzFriendlyName)
#endif
#endif
  HRESULT WINAPI IHlinkTarget_SetBrowseContext_Proxy(IHlinkTarget *This,IHlinkBrowseContext *pihlbc);
  void __RPC_STUB IHlinkTarget_SetBrowseContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkTarget_GetBrowseContext_Proxy(IHlinkTarget *This,IHlinkBrowseContext **ppihlbc);
  void __RPC_STUB IHlinkTarget_GetBrowseContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkTarget_Navigate_Proxy(IHlinkTarget *This,DWORD grfHLNF,LPCWSTR pwzJumpLocation);
  void __RPC_STUB IHlinkTarget_Navigate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkTarget_GetMoniker_Proxy(IHlinkTarget *This,LPCWSTR pwzLocation,DWORD dwAssign,IMoniker **ppimkLocation);
  void __RPC_STUB IHlinkTarget_GetMoniker_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkTarget_GetFriendlyName_Proxy(IHlinkTarget *This,LPCWSTR pwzLocation,LPWSTR *ppwzFriendlyName);
  void __RPC_STUB IHlinkTarget_GetFriendlyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPHLINKFRAME_DEFINED
#define _LPHLINKFRAME_DEFINED
  EXTERN_C const GUID SID_SHlinkFrame;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0219_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0219_v0_0_s_ifspec;
#ifndef __IHlinkFrame_INTERFACE_DEFINED__
#define __IHlinkFrame_INTERFACE_DEFINED__
  typedef IHlinkFrame *LPHLINKFRAME;

  EXTERN_C const IID IID_IHlinkFrame;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IHlinkFrame : public IUnknown {
  public:
    virtual HRESULT WINAPI SetBrowseContext(IHlinkBrowseContext *pihlbc) = 0;
    virtual HRESULT WINAPI GetBrowseContext(IHlinkBrowseContext **ppihlbc) = 0;
    virtual HRESULT WINAPI Navigate(DWORD grfHLNF,LPBC pbc,IBindStatusCallback *pibsc,IHlink *pihlNavigate) = 0;
    virtual HRESULT WINAPI OnNavigate(DWORD grfHLNF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,DWORD dwreserved) = 0;
    virtual HRESULT WINAPI UpdateHlink(ULONG uHLID,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName) = 0;
  };
#else
  typedef struct IHlinkFrameVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IHlinkFrame *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IHlinkFrame *This);
      ULONG (WINAPI *Release)(IHlinkFrame *This);
      HRESULT (WINAPI *SetBrowseContext)(IHlinkFrame *This,IHlinkBrowseContext *pihlbc);
      HRESULT (WINAPI *GetBrowseContext)(IHlinkFrame *This,IHlinkBrowseContext **ppihlbc);
      HRESULT (WINAPI *Navigate)(IHlinkFrame *This,DWORD grfHLNF,LPBC pbc,IBindStatusCallback *pibsc,IHlink *pihlNavigate);
      HRESULT (WINAPI *OnNavigate)(IHlinkFrame *This,DWORD grfHLNF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,DWORD dwreserved);
      HRESULT (WINAPI *UpdateHlink)(IHlinkFrame *This,ULONG uHLID,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName);
    END_INTERFACE
  } IHlinkFrameVtbl;
  struct IHlinkFrame {
    CONST_VTBL struct IHlinkFrameVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IHlinkFrame_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IHlinkFrame_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IHlinkFrame_Release(This) (This)->lpVtbl->Release(This)
#define IHlinkFrame_SetBrowseContext(This,pihlbc) (This)->lpVtbl->SetBrowseContext(This,pihlbc)
#define IHlinkFrame_GetBrowseContext(This,ppihlbc) (This)->lpVtbl->GetBrowseContext(This,ppihlbc)
#define IHlinkFrame_Navigate(This,grfHLNF,pbc,pibsc,pihlNavigate) (This)->lpVtbl->Navigate(This,grfHLNF,pbc,pibsc,pihlNavigate)
#define IHlinkFrame_OnNavigate(This,grfHLNF,pimkTarget,pwzLocation,pwzFriendlyName,dwreserved) (This)->lpVtbl->OnNavigate(This,grfHLNF,pimkTarget,pwzLocation,pwzFriendlyName,dwreserved)
#define IHlinkFrame_UpdateHlink(This,uHLID,pimkTarget,pwzLocation,pwzFriendlyName) (This)->lpVtbl->UpdateHlink(This,uHLID,pimkTarget,pwzLocation,pwzFriendlyName)
#endif
#endif
  HRESULT WINAPI IHlinkFrame_SetBrowseContext_Proxy(IHlinkFrame *This,IHlinkBrowseContext *pihlbc);
  void __RPC_STUB IHlinkFrame_SetBrowseContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkFrame_GetBrowseContext_Proxy(IHlinkFrame *This,IHlinkBrowseContext **ppihlbc);
  void __RPC_STUB IHlinkFrame_GetBrowseContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkFrame_Navigate_Proxy(IHlinkFrame *This,DWORD grfHLNF,LPBC pbc,IBindStatusCallback *pibsc,IHlink *pihlNavigate);
  void __RPC_STUB IHlinkFrame_Navigate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkFrame_OnNavigate_Proxy(IHlinkFrame *This,DWORD grfHLNF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,DWORD dwreserved);
  void __RPC_STUB IHlinkFrame_OnNavigate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkFrame_UpdateHlink_Proxy(IHlinkFrame *This,ULONG uHLID,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName);
  void __RPC_STUB IHlinkFrame_UpdateHlink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPENUMHLITEM_DEFINED
#define _LPENUMHLITEM_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0220_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0220_v0_0_s_ifspec;

#ifndef __IEnumHLITEM_INTERFACE_DEFINED__
#define __IEnumHLITEM_INTERFACE_DEFINED__
  typedef IEnumHLITEM *LPENUMHLITEM;
  typedef struct tagHLITEM {
    ULONG uHLID;
    LPWSTR pwzFriendlyName;
  } HLITEM;
  typedef HLITEM *LPHLITEM;

  EXTERN_C const IID IID_IEnumHLITEM;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumHLITEM : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,HLITEM *rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumHLITEM **ppienumhlitem) = 0;
  };
#else
  typedef struct IEnumHLITEMVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumHLITEM *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumHLITEM *This);
      ULONG (WINAPI *Release)(IEnumHLITEM *This);
      HRESULT (WINAPI *Next)(IEnumHLITEM *This,ULONG celt,HLITEM *rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumHLITEM *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumHLITEM *This);
      HRESULT (WINAPI *Clone)(IEnumHLITEM *This,IEnumHLITEM **ppienumhlitem);
    END_INTERFACE
  } IEnumHLITEMVtbl;
  struct IEnumHLITEM {
    CONST_VTBL struct IEnumHLITEMVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumHLITEM_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumHLITEM_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumHLITEM_Release(This) (This)->lpVtbl->Release(This)
#define IEnumHLITEM_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumHLITEM_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumHLITEM_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumHLITEM_Clone(This,ppienumhlitem) (This)->lpVtbl->Clone(This,ppienumhlitem)
#endif
#endif
  HRESULT WINAPI IEnumHLITEM_Next_Proxy(IEnumHLITEM *This,ULONG celt,HLITEM *rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumHLITEM_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumHLITEM_Skip_Proxy(IEnumHLITEM *This,ULONG celt);
  void __RPC_STUB IEnumHLITEM_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumHLITEM_Reset_Proxy(IEnumHLITEM *This);
  void __RPC_STUB IEnumHLITEM_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumHLITEM_Clone_Proxy(IEnumHLITEM *This,IEnumHLITEM **ppienumhlitem);
  void __RPC_STUB IEnumHLITEM_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPHLINKBROWSECONTEXT_DEFINED
#define _LPHLINKBROWSECONTEXT_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0221_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0221_v0_0_s_ifspec;

#ifndef __IHlinkBrowseContext_INTERFACE_DEFINED__
#define __IHlinkBrowseContext_INTERFACE_DEFINED__
  typedef IHlinkBrowseContext *LPHLINKBROWSECONTEXT;

  enum __MIDL_IHlinkBrowseContext_0001 {
    HLTB_DOCKEDLEFT = 0,HLTB_DOCKEDTOP = 1,HLTB_DOCKEDRIGHT = 2,HLTB_DOCKEDBOTTOM = 3,HLTB_FLOATING = 4
  };
  typedef struct _tagHLTBINFO {
    ULONG uDockType;
    RECT rcTbPos;
  } HLTBINFO;

  enum __MIDL_IHlinkBrowseContext_0002 {
    HLBWIF_HASFRAMEWNDINFO = 0x1,HLBWIF_HASDOCWNDINFO = 0x2,HLBWIF_FRAMEWNDMAXIMIZED = 0x4,HLBWIF_DOCWNDMAXIMIZED = 0x8,
    HLBWIF_HASWEBTOOLBARINFO = 0x10,HLBWIF_WEBTOOLBARHIDDEN = 0x20
  };
  typedef struct _tagHLBWINFO {
    ULONG cbSize;
    DWORD grfHLBWIF;
    RECT rcFramePos;
    RECT rcDocPos;
    HLTBINFO hltbinfo;
  } HLBWINFO;
  typedef HLBWINFO *LPHLBWINFO;

  enum __MIDL_IHlinkBrowseContext_0003 {
    HLID_INVALID = 0,HLID_PREVIOUS = 0xffffffff,HLID_NEXT = 0xfffffffe,HLID_CURRENT = 0xfffffffd,HLID_STACKBOTTOM = 0xfffffffc,
    HLID_STACKTOP = 0xfffffffb
  };

  enum __MIDL_IHlinkBrowseContext_0004 {
    HLQF_ISVALID = 0x1,HLQF_ISCURRENT = 0x2
  };

  EXTERN_C const IID IID_IHlinkBrowseContext;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IHlinkBrowseContext : public IUnknown {
  public:
    virtual HRESULT WINAPI Register(DWORD reserved,IUnknown *piunk,IMoniker *pimk,DWORD *pdwRegister) = 0;
    virtual HRESULT WINAPI GetObject(IMoniker *pimk,WINBOOL fBindIfRootRegistered,IUnknown **ppiunk) = 0;
    virtual HRESULT WINAPI Revoke(DWORD dwRegister) = 0;
    virtual HRESULT WINAPI SetBrowseWindowInfo(HLBWINFO *phlbwi) = 0;
    virtual HRESULT WINAPI GetBrowseWindowInfo(HLBWINFO *phlbwi) = 0;
    virtual HRESULT WINAPI SetInitialHlink(IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName) = 0;
    virtual HRESULT WINAPI OnNavigateHlink(DWORD grfHLNF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,ULONG *puHLID) = 0;
    virtual HRESULT WINAPI UpdateHlink(ULONG uHLID,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName) = 0;
    virtual HRESULT WINAPI EnumNavigationStack(DWORD dwReserved,DWORD grfHLFNAMEF,IEnumHLITEM **ppienumhlitem) = 0;
    virtual HRESULT WINAPI QueryHlink(DWORD grfHLQF,ULONG uHLID) = 0;
    virtual HRESULT WINAPI GetHlink(ULONG uHLID,IHlink **ppihl) = 0;
    virtual HRESULT WINAPI SetCurrentHlink(ULONG uHLID) = 0;
    virtual HRESULT WINAPI Clone(IUnknown *piunkOuter,REFIID riid,IUnknown **ppiunkObj) = 0;
    virtual HRESULT WINAPI Close(DWORD reserved) = 0;
  };
#else
  typedef struct IHlinkBrowseContextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IHlinkBrowseContext *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IHlinkBrowseContext *This);
      ULONG (WINAPI *Release)(IHlinkBrowseContext *This);
      HRESULT (WINAPI *Register)(IHlinkBrowseContext *This,DWORD reserved,IUnknown *piunk,IMoniker *pimk,DWORD *pdwRegister);
      HRESULT (WINAPI *GetObject)(IHlinkBrowseContext *This,IMoniker *pimk,WINBOOL fBindIfRootRegistered,IUnknown **ppiunk);
      HRESULT (WINAPI *Revoke)(IHlinkBrowseContext *This,DWORD dwRegister);
      HRESULT (WINAPI *SetBrowseWindowInfo)(IHlinkBrowseContext *This,HLBWINFO *phlbwi);
      HRESULT (WINAPI *GetBrowseWindowInfo)(IHlinkBrowseContext *This,HLBWINFO *phlbwi);
      HRESULT (WINAPI *SetInitialHlink)(IHlinkBrowseContext *This,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName);
      HRESULT (WINAPI *OnNavigateHlink)(IHlinkBrowseContext *This,DWORD grfHLNF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,ULONG *puHLID);
      HRESULT (WINAPI *UpdateHlink)(IHlinkBrowseContext *This,ULONG uHLID,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName);
      HRESULT (WINAPI *EnumNavigationStack)(IHlinkBrowseContext *This,DWORD dwReserved,DWORD grfHLFNAMEF,IEnumHLITEM **ppienumhlitem);
      HRESULT (WINAPI *QueryHlink)(IHlinkBrowseContext *This,DWORD grfHLQF,ULONG uHLID);
      HRESULT (WINAPI *GetHlink)(IHlinkBrowseContext *This,ULONG uHLID,IHlink **ppihl);
      HRESULT (WINAPI *SetCurrentHlink)(IHlinkBrowseContext *This,ULONG uHLID);
      HRESULT (WINAPI *Clone)(IHlinkBrowseContext *This,IUnknown *piunkOuter,REFIID riid,IUnknown **ppiunkObj);
      HRESULT (WINAPI *Close)(IHlinkBrowseContext *This,DWORD reserved);
    END_INTERFACE
  } IHlinkBrowseContextVtbl;
  struct IHlinkBrowseContext {
    CONST_VTBL struct IHlinkBrowseContextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IHlinkBrowseContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IHlinkBrowseContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IHlinkBrowseContext_Release(This) (This)->lpVtbl->Release(This)
#define IHlinkBrowseContext_Register(This,reserved,piunk,pimk,pdwRegister) (This)->lpVtbl->Register(This,reserved,piunk,pimk,pdwRegister)
#define IHlinkBrowseContext_GetObject(This,pimk,fBindIfRootRegistered,ppiunk) (This)->lpVtbl->GetObject(This,pimk,fBindIfRootRegistered,ppiunk)
#define IHlinkBrowseContext_Revoke(This,dwRegister) (This)->lpVtbl->Revoke(This,dwRegister)
#define IHlinkBrowseContext_SetBrowseWindowInfo(This,phlbwi) (This)->lpVtbl->SetBrowseWindowInfo(This,phlbwi)
#define IHlinkBrowseContext_GetBrowseWindowInfo(This,phlbwi) (This)->lpVtbl->GetBrowseWindowInfo(This,phlbwi)
#define IHlinkBrowseContext_SetInitialHlink(This,pimkTarget,pwzLocation,pwzFriendlyName) (This)->lpVtbl->SetInitialHlink(This,pimkTarget,pwzLocation,pwzFriendlyName)
#define IHlinkBrowseContext_OnNavigateHlink(This,grfHLNF,pimkTarget,pwzLocation,pwzFriendlyName,puHLID) (This)->lpVtbl->OnNavigateHlink(This,grfHLNF,pimkTarget,pwzLocation,pwzFriendlyName,puHLID)
#define IHlinkBrowseContext_UpdateHlink(This,uHLID,pimkTarget,pwzLocation,pwzFriendlyName) (This)->lpVtbl->UpdateHlink(This,uHLID,pimkTarget,pwzLocation,pwzFriendlyName)
#define IHlinkBrowseContext_EnumNavigationStack(This,dwReserved,grfHLFNAMEF,ppienumhlitem) (This)->lpVtbl->EnumNavigationStack(This,dwReserved,grfHLFNAMEF,ppienumhlitem)
#define IHlinkBrowseContext_QueryHlink(This,grfHLQF,uHLID) (This)->lpVtbl->QueryHlink(This,grfHLQF,uHLID)
#define IHlinkBrowseContext_GetHlink(This,uHLID,ppihl) (This)->lpVtbl->GetHlink(This,uHLID,ppihl)
#define IHlinkBrowseContext_SetCurrentHlink(This,uHLID) (This)->lpVtbl->SetCurrentHlink(This,uHLID)
#define IHlinkBrowseContext_Clone(This,piunkOuter,riid,ppiunkObj) (This)->lpVtbl->Clone(This,piunkOuter,riid,ppiunkObj)
#define IHlinkBrowseContext_Close(This,reserved) (This)->lpVtbl->Close(This,reserved)
#endif
#endif
  HRESULT WINAPI IHlinkBrowseContext_Register_Proxy(IHlinkBrowseContext *This,DWORD reserved,IUnknown *piunk,IMoniker *pimk,DWORD *pdwRegister);
  void __RPC_STUB IHlinkBrowseContext_Register_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_GetObject_Proxy(IHlinkBrowseContext *This,IMoniker *pimk,WINBOOL fBindIfRootRegistered,IUnknown **ppiunk);
  void __RPC_STUB IHlinkBrowseContext_GetObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_Revoke_Proxy(IHlinkBrowseContext *This,DWORD dwRegister);
  void __RPC_STUB IHlinkBrowseContext_Revoke_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_SetBrowseWindowInfo_Proxy(IHlinkBrowseContext *This,HLBWINFO *phlbwi);
  void __RPC_STUB IHlinkBrowseContext_SetBrowseWindowInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_GetBrowseWindowInfo_Proxy(IHlinkBrowseContext *This,HLBWINFO *phlbwi);
  void __RPC_STUB IHlinkBrowseContext_GetBrowseWindowInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_SetInitialHlink_Proxy(IHlinkBrowseContext *This,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName);
  void __RPC_STUB IHlinkBrowseContext_SetInitialHlink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_OnNavigateHlink_Proxy(IHlinkBrowseContext *This,DWORD grfHLNF,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName,ULONG *puHLID);
  void __RPC_STUB IHlinkBrowseContext_OnNavigateHlink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_UpdateHlink_Proxy(IHlinkBrowseContext *This,ULONG uHLID,IMoniker *pimkTarget,LPCWSTR pwzLocation,LPCWSTR pwzFriendlyName);
  void __RPC_STUB IHlinkBrowseContext_UpdateHlink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_EnumNavigationStack_Proxy(IHlinkBrowseContext *This,DWORD dwReserved,DWORD grfHLFNAMEF,IEnumHLITEM **ppienumhlitem);
  void __RPC_STUB IHlinkBrowseContext_EnumNavigationStack_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_QueryHlink_Proxy(IHlinkBrowseContext *This,DWORD grfHLQF,ULONG uHLID);
  void __RPC_STUB IHlinkBrowseContext_QueryHlink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_GetHlink_Proxy(IHlinkBrowseContext *This,ULONG uHLID,IHlink **ppihl);
  void __RPC_STUB IHlinkBrowseContext_GetHlink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_SetCurrentHlink_Proxy(IHlinkBrowseContext *This,ULONG uHLID);
  void __RPC_STUB IHlinkBrowseContext_SetCurrentHlink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_Clone_Proxy(IHlinkBrowseContext *This,IUnknown *piunkOuter,REFIID riid,IUnknown **ppiunkObj);
  void __RPC_STUB IHlinkBrowseContext_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHlinkBrowseContext_Close_Proxy(IHlinkBrowseContext *This,DWORD reserved);
  void __RPC_STUB IHlinkBrowseContext_Close_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPEXTENSIONSERVICES_DEFINED
#define _LPEXTENSIONSERVICES_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0222_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0222_v0_0_s_ifspec;

#ifndef __IExtensionServices_INTERFACE_DEFINED__
#define __IExtensionServices_INTERFACE_DEFINED__
  typedef IExtensionServices *LPEXTENSIONSERVICES;

  EXTERN_C const IID IID_IExtensionServices;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IExtensionServices : public IUnknown {
  public:
    virtual HRESULT WINAPI SetAdditionalHeaders(LPCWSTR pwzAdditionalHeaders) = 0;
    virtual HRESULT WINAPI SetAuthenticateData(HWND phwnd,LPCWSTR pwzUsername,LPCWSTR pwzPassword) = 0;
  };
#else
  typedef struct IExtensionServicesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IExtensionServices *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IExtensionServices *This);
      ULONG (WINAPI *Release)(IExtensionServices *This);
      HRESULT (WINAPI *SetAdditionalHeaders)(IExtensionServices *This,LPCWSTR pwzAdditionalHeaders);
      HRESULT (WINAPI *SetAuthenticateData)(IExtensionServices *This,HWND phwnd,LPCWSTR pwzUsername,LPCWSTR pwzPassword);
    END_INTERFACE
  } IExtensionServicesVtbl;
  struct IExtensionServices {
    CONST_VTBL struct IExtensionServicesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IExtensionServices_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IExtensionServices_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IExtensionServices_Release(This) (This)->lpVtbl->Release(This)
#define IExtensionServices_SetAdditionalHeaders(This,pwzAdditionalHeaders) (This)->lpVtbl->SetAdditionalHeaders(This,pwzAdditionalHeaders)
#define IExtensionServices_SetAuthenticateData(This,phwnd,pwzUsername,pwzPassword) (This)->lpVtbl->SetAuthenticateData(This,phwnd,pwzUsername,pwzPassword)
#endif
#endif
  HRESULT WINAPI IExtensionServices_SetAdditionalHeaders_Proxy(IExtensionServices *This,LPCWSTR pwzAdditionalHeaders);
  void __RPC_STUB IExtensionServices_SetAdditionalHeaders_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExtensionServices_SetAuthenticateData_Proxy(IExtensionServices *This,HWND phwnd,LPCWSTR pwzUsername,LPCWSTR pwzPassword);
  void __RPC_STUB IExtensionServices_SetAuthenticateData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_hlink_0223_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_hlink_0223_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
