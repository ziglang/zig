/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "rpc.h"
#include "rpcndr.h"
#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __datapath_h__
#define __datapath_h__

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __IObjectWithSite_FWD_DEFINED__
#define __IObjectWithSite_FWD_DEFINED__
  typedef struct IObjectWithSite IObjectWithSite;
#endif

#ifndef __IDataPathBrowser_FWD_DEFINED__
#define __IDataPathBrowser_FWD_DEFINED__
  typedef struct IDataPathBrowser IDataPathBrowser;
#endif

#ifndef __IProvideClassInfo3_FWD_DEFINED__
#define __IProvideClassInfo3_FWD_DEFINED__
  typedef struct IProvideClassInfo3 IProvideClassInfo3;
#endif

#include "objidl.h"
#include "oleidl.h"
#include "oaidl.h"
#include "olectl.h"
#include "urlmon.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include "idispids.h"
  typedef BSTR OLE_DATAPATH;
#define SID_SDataPathBrowser IID_IDataPathBrowser

  EXTERN_C const GUID OLE_DATAPATH_BMP;
  EXTERN_C const GUID OLE_DATAPATH_DIB;
  EXTERN_C const GUID OLE_DATAPATH_WMF;
  EXTERN_C const GUID OLE_DATAPATH_ENHMF;
  EXTERN_C const GUID OLE_DATAPATH_GIF;
  EXTERN_C const GUID OLE_DATAPATH_JPEG;
  EXTERN_C const GUID OLE_DATAPATH_TIFF;
  EXTERN_C const GUID OLE_DATAPATH_XBM;
  EXTERN_C const GUID OLE_DATAPATH_PCX;
  EXTERN_C const GUID OLE_DATAPATH_PICT;
  EXTERN_C const GUID OLE_DATAPATH_CGM;
  EXTERN_C const GUID OLE_DATAPATH_EPS;
  EXTERN_C const GUID OLE_DATAPATH_COMMONIMAGE;
  EXTERN_C const GUID OLE_DATAPATH_ALLIMAGE;
  EXTERN_C const GUID OLE_DATAPATH_AVI;
  EXTERN_C const GUID OLE_DATAPATH_MPEG;
  EXTERN_C const GUID OLE_DATAPATH_QUICKTIME;
  EXTERN_C const GUID OLE_DATAPATH_BASICAUDIO;
  EXTERN_C const GUID OLE_DATAPATH_MIDI;
  EXTERN_C const GUID OLE_DATAPATH_WAV;
  EXTERN_C const GUID OLE_DATAPATH_RIFF;
  EXTERN_C const GUID OLE_DATAPATH_SOUND;
  EXTERN_C const GUID OLE_DATAPATH_VIDEO;
  EXTERN_C const GUID OLE_DATAPATH_ALLMM;
  EXTERN_C const GUID OLE_DATAPATH_ANSITEXT;
  EXTERN_C const GUID OLE_DATAPATH_UNICODE;
  EXTERN_C const GUID OLE_DATAPATH_RTF;
  EXTERN_C const GUID OLE_DATAPATH_HTML;
  EXTERN_C const GUID OLE_DATAPATH_POSTSCRIPT;
  EXTERN_C const GUID OLE_DATAPATH_ALLTEXT;
  EXTERN_C const GUID OLE_DATAPATH_DIF;
  EXTERN_C const GUID OLE_DATAPATH_SYLK;
  EXTERN_C const GUID OLE_DATAPATH_BIFF;
  EXTERN_C const GUID OLE_DATAPATH_PALETTE;
  EXTERN_C const GUID OLE_DATAPATH_PENDATA;
  EXTERN_C const GUID FLAGID_Internet;
  EXTERN_C const GUID GUID_PathProperty;
  EXTERN_C const GUID GUID_HasPathProperties;
  EXTERN_C const GUID ARRAYID_PathProperties;

#ifndef _LPOBJECTWITHSITE_DEFINED
#define _LPOBJECTWITHSITE_DEFINED
  extern RPC_IF_HANDLE __MIDL__intf_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL__intf_0000_v0_0_s_ifspec;
#ifndef __IObjectWithSite_INTERFACE_DEFINED__
#define __IObjectWithSite_INTERFACE_DEFINED__
  typedef IObjectWithSite *LPOBJECTWITHSITE;
  EXTERN_C const IID IID_IObjectWithSite;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectWithSite : public IUnknown {
public:
  virtual HRESULT WINAPI SetSite(IUnknown *pUnkSite) = 0;
  virtual HRESULT WINAPI GetSite(REFIID riid,void **ppvSite) = 0;
  };
#else
  typedef struct IObjectWithSiteVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectWithSite *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectWithSite *This);
      ULONG (WINAPI *Release)(IObjectWithSite *This);
      HRESULT (WINAPI *SetSite)(IObjectWithSite *This,IUnknown *pUnkSite);
      HRESULT (WINAPI *GetSite)(IObjectWithSite *This,REFIID riid,void **ppvSite);
    END_INTERFACE
  } IObjectWithSiteVtbl;
  struct IObjectWithSite {
    CONST_VTBL struct IObjectWithSiteVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectWithSite_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectWithSite_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectWithSite_Release(This) (This)->lpVtbl->Release(This)
#define IObjectWithSite_SetSite(This,pUnkSite) (This)->lpVtbl->SetSite(This,pUnkSite)
#define IObjectWithSite_GetSite(This,riid,ppvSite) (This)->lpVtbl->GetSite(This,riid,ppvSite)
#endif
#endif
  HRESULT WINAPI IObjectWithSite_SetSite_Proxy(IObjectWithSite *This,IUnknown *pUnkSite);
  void __RPC_STUB IObjectWithSite_SetSite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectWithSite_GetSite_Proxy(IObjectWithSite *This,REFIID riid,void **ppvSite);
  void __RPC_STUB IObjectWithSite_GetSite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPDATAPATHBROWSER_DEFINED
#define _LPDATAPATHBROWSER_DEFINED
  extern RPC_IF_HANDLE __MIDL__intf_0119_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL__intf_0119_v0_0_s_ifspec;
#ifndef __IDataPathBrowser_INTERFACE_DEFINED__
#define __IDataPathBrowser_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDataPathBrowser;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDataPathBrowser : public IUnknown {
  public:
    virtual HRESULT WINAPI BrowseType(REFGUID rguidPathType,LPOLESTR pszDefaultPath,ULONG cchPath,LPOLESTR pszPath,HWND hWnd) = 0;
  };
#else
  typedef struct IDataPathBrowserVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDataPathBrowser *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDataPathBrowser *This);
      ULONG (WINAPI *Release)(IDataPathBrowser *This);
      HRESULT (WINAPI *BrowseType)(IDataPathBrowser *This,REFGUID rguidPathType,LPOLESTR pszDefaultPath,ULONG cchPath,LPOLESTR pszPath,HWND hWnd);
    END_INTERFACE
  } IDataPathBrowserVtbl;
  struct IDataPathBrowser {
    CONST_VTBL struct IDataPathBrowserVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDataPathBrowser_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDataPathBrowser_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDataPathBrowser_Release(This) (This)->lpVtbl->Release(This)
#define IDataPathBrowser_BrowseType(This,rguidPathType,pszDefaultPath,cchPath,pszPath,hWnd) (This)->lpVtbl->BrowseType(This,rguidPathType,pszDefaultPath,cchPath,pszPath,hWnd)
#endif
#endif
  HRESULT WINAPI IDataPathBrowser_BrowseType_Proxy(IDataPathBrowser *This,REFGUID rguidPathType,LPOLESTR pszDefaultPath,ULONG cchPath,LPOLESTR pszPath,HWND hWnd);
  void __RPC_STUB IDataPathBrowser_BrowseType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPPROVIDECLASSINFO3_DEFINED
#define _LPPROVIDECLASSINFO3_DEFINED
  extern RPC_IF_HANDLE __MIDL__intf_0120_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL__intf_0120_v0_0_s_ifspec;
#ifndef __IProvideClassInfo3_INTERFACE_DEFINED__
#define __IProvideClassInfo3_INTERFACE_DEFINED__
  typedef IProvideClassInfo3 *LPPROVIDECLASSINFO3;
  enum __MIDL_IProvideClassInfo3_0001
  { INTERNETFLAG_USESDATAPATHS = 0x1
  };
  EXTERN_C const IID IID_IProvideClassInfo3;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProvideClassInfo3 : public IProvideClassInfo2 {
  public:
    virtual HRESULT WINAPI GetGUIDDwordArrays(REFGUID rguidArray,CAUUID *pcaUUID,CADWORD *pcadw) = 0;
    virtual HRESULT WINAPI GetClassInfoLocale(ITypeInfo **ppITypeInfo,LCID lcid) = 0;
    virtual HRESULT WINAPI GetFlags(REFGUID guidGroup,DWORD *pdwFlags) = 0;
  };
#else
  typedef struct IProvideClassInfo3Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IProvideClassInfo3 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IProvideClassInfo3 *This);
      ULONG (WINAPI *Release)(IProvideClassInfo3 *This);
      HRESULT (WINAPI *GetClassInfo)(IProvideClassInfo3 *This,ITypeInfo **ppTI);
      HRESULT (WINAPI *GetGUID)(IProvideClassInfo3 *This,DWORD dwGuidKind,GUID *pGUID);
      HRESULT (WINAPI *GetGUIDDwordArrays)(IProvideClassInfo3 *This,REFGUID rguidArray,CAUUID *pcaUUID,CADWORD *pcadw);
      HRESULT (WINAPI *GetClassInfoLocale)(IProvideClassInfo3 *This,ITypeInfo **ppITypeInfo,LCID lcid);
      HRESULT (WINAPI *GetFlags)(IProvideClassInfo3 *This,REFGUID guidGroup,DWORD *pdwFlags);
    END_INTERFACE
  } IProvideClassInfo3Vtbl;
  struct IProvideClassInfo3 {
    CONST_VTBL struct IProvideClassInfo3Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProvideClassInfo3_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProvideClassInfo3_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProvideClassInfo3_Release(This) (This)->lpVtbl->Release(This)
#define IProvideClassInfo3_GetClassInfo(This,ppTI) (This)->lpVtbl->GetClassInfo(This,ppTI)
#define IProvideClassInfo3_GetGUID(This,dwGuidKind,pGUID) (This)->lpVtbl->GetGUID(This,dwGuidKind,pGUID)
#define IProvideClassInfo3_GetGUIDDwordArrays(This,rguidArray,pcaUUID,pcadw) (This)->lpVtbl->GetGUIDDwordArrays(This,rguidArray,pcaUUID,pcadw)
#define IProvideClassInfo3_GetClassInfoLocale(This,ppITypeInfo,lcid) (This)->lpVtbl->GetClassInfoLocale(This,ppITypeInfo,lcid)
#define IProvideClassInfo3_GetFlags(This,guidGroup,pdwFlags) (This)->lpVtbl->GetFlags(This,guidGroup,pdwFlags)
#endif
#endif
  HRESULT WINAPI IProvideClassInfo3_GetGUIDDwordArrays_Proxy(IProvideClassInfo3 *This,REFGUID rguidArray,CAUUID *pcaUUID,CADWORD *pcadw);
  void __RPC_STUB IProvideClassInfo3_GetGUIDDwordArrays_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IProvideClassInfo3_GetClassInfoLocale_Proxy(IProvideClassInfo3 *This,ITypeInfo **ppITypeInfo,LCID lcid);
  void __RPC_STUB IProvideClassInfo3_GetClassInfoLocale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IProvideClassInfo3_GetFlags_Proxy(IProvideClassInfo3 *This,REFGUID guidGroup,DWORD *pdwFlags);
  void __RPC_STUB IProvideClassInfo3_GetFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL__intf_0121_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL__intf_0121_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
