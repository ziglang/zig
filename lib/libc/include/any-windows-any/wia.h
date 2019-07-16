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

#ifndef __wia_h__
#define __wia_h__

#ifndef __IWiaDevMgr_FWD_DEFINED__
#define __IWiaDevMgr_FWD_DEFINED__
typedef struct IWiaDevMgr IWiaDevMgr;
#endif

#ifndef __IEnumWIA_DEV_INFO_FWD_DEFINED__
#define __IEnumWIA_DEV_INFO_FWD_DEFINED__
typedef struct IEnumWIA_DEV_INFO IEnumWIA_DEV_INFO;
#endif

#ifndef __IWiaEventCallback_FWD_DEFINED__
#define __IWiaEventCallback_FWD_DEFINED__
typedef struct IWiaEventCallback IWiaEventCallback;
#endif

#ifndef __IWiaDataCallback_FWD_DEFINED__
#define __IWiaDataCallback_FWD_DEFINED__
typedef struct IWiaDataCallback IWiaDataCallback;
#endif

#ifndef __IWiaDataTransfer_FWD_DEFINED__
#define __IWiaDataTransfer_FWD_DEFINED__
typedef struct IWiaDataTransfer IWiaDataTransfer;
#endif

#ifndef __IWiaItem_FWD_DEFINED__
#define __IWiaItem_FWD_DEFINED__
typedef struct IWiaItem IWiaItem;
#endif

#ifndef __IWiaPropertyStorage_FWD_DEFINED__
#define __IWiaPropertyStorage_FWD_DEFINED__
typedef struct IWiaPropertyStorage IWiaPropertyStorage;
#endif

#ifndef __IEnumWiaItem_FWD_DEFINED__
#define __IEnumWiaItem_FWD_DEFINED__
typedef struct IEnumWiaItem IEnumWiaItem;
#endif

#ifndef __IEnumWIA_DEV_CAPS_FWD_DEFINED__
#define __IEnumWIA_DEV_CAPS_FWD_DEFINED__
typedef struct IEnumWIA_DEV_CAPS IEnumWIA_DEV_CAPS;
#endif

#ifndef __IEnumWIA_FORMAT_INFO_FWD_DEFINED__
#define __IEnumWIA_FORMAT_INFO_FWD_DEFINED__
typedef struct IEnumWIA_FORMAT_INFO IEnumWIA_FORMAT_INFO;
#endif

#ifndef __IWiaLog_FWD_DEFINED__
#define __IWiaLog_FWD_DEFINED__
typedef struct IWiaLog IWiaLog;
#endif

#ifndef __IWiaLogEx_FWD_DEFINED__
#define __IWiaLogEx_FWD_DEFINED__
typedef struct IWiaLogEx IWiaLogEx;
#endif

#ifndef __IWiaNotifyDevMgr_FWD_DEFINED__
#define __IWiaNotifyDevMgr_FWD_DEFINED__
typedef struct IWiaNotifyDevMgr IWiaNotifyDevMgr;
#endif

#ifndef __IWiaItemExtras_FWD_DEFINED__
#define __IWiaItemExtras_FWD_DEFINED__
typedef struct IWiaItemExtras IWiaItemExtras;
#endif

#ifndef __WiaDevMgr_FWD_DEFINED__
#define __WiaDevMgr_FWD_DEFINED__

#ifdef __cplusplus
typedef class WiaDevMgr WiaDevMgr;
#else
typedef struct WiaDevMgr WiaDevMgr;
#endif
#endif

#ifndef __WiaLog_FWD_DEFINED__
#define __WiaLog_FWD_DEFINED__

#ifdef __cplusplus
typedef class WiaLog WiaLog;
#else
typedef struct WiaLog WiaLog;
#endif
#endif

#include "unknwn.h"
#include "oaidl.h"
#include "propidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef struct _WIA_DITHER_PATTERN_DATA {
    LONG lSize;
    BSTR bstrPatternName;
    LONG lPatternWidth;
    LONG lPatternLength;
    LONG cbPattern;
    BYTE *pbPattern;
  } WIA_DITHER_PATTERN_DATA;

  typedef struct _WIA_DITHER_PATTERN_DATA *PWIA_DITHER_PATTERN_DATA;

  typedef struct _WIA_PROPID_TO_NAME {
    PROPID propid;
    LPOLESTR pszName;
  } WIA_PROPID_TO_NAME;

  typedef struct _WIA_PROPID_TO_NAME *PWIA_PROPID_TO_NAME;

  typedef struct _WIA_FORMAT_INFO {
    GUID guidFormatID;
    LONG lTymed;
  } WIA_FORMAT_INFO;

  typedef struct _WIA_FORMAT_INFO *PWIA_FORMAT_INFO;

#include "wiadef.h"

  extern RPC_IF_HANDLE __MIDL_itf_wia_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wia_0000_v0_0_s_ifspec;
#ifndef __IWiaDevMgr_INTERFACE_DEFINED__
#define __IWiaDevMgr_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaDevMgr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaDevMgr : public IUnknown {
  public:
    virtual HRESULT WINAPI EnumDeviceInfo(LONG lFlag,IEnumWIA_DEV_INFO **ppIEnum) = 0;
    virtual HRESULT WINAPI CreateDevice(BSTR bstrDeviceID,IWiaItem **ppWiaItemRoot) = 0;
    virtual HRESULT WINAPI SelectDeviceDlg(HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID,IWiaItem **ppItemRoot) = 0;
    virtual HRESULT WINAPI SelectDeviceDlgID(HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID) = 0;
    virtual HRESULT WINAPI GetImageDlg(HWND hwndParent,LONG lDeviceType,LONG lFlags,LONG lIntent,IWiaItem *pItemRoot,BSTR bstrFilename,GUID *pguidFormat) = 0;
    virtual HRESULT WINAPI RegisterEventCallbackProgram(LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,BSTR bstrCommandline,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon) = 0;
    virtual HRESULT WINAPI RegisterEventCallbackInterface(LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,IWiaEventCallback *pIWiaEventCallback,IUnknown **pEventObject) = 0;
    virtual HRESULT WINAPI RegisterEventCallbackCLSID(LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,const GUID *pClsID,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon) = 0;
    virtual HRESULT WINAPI AddDeviceDlg(HWND hwndParent,LONG lFlags) = 0;
  };
#else
  typedef struct IWiaDevMgrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaDevMgr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaDevMgr *This);
      ULONG (WINAPI *Release)(IWiaDevMgr *This);
      HRESULT (WINAPI *EnumDeviceInfo)(IWiaDevMgr *This,LONG lFlag,IEnumWIA_DEV_INFO **ppIEnum);
      HRESULT (WINAPI *CreateDevice)(IWiaDevMgr *This,BSTR bstrDeviceID,IWiaItem **ppWiaItemRoot);
      HRESULT (WINAPI *SelectDeviceDlg)(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID,IWiaItem **ppItemRoot);
      HRESULT (WINAPI *SelectDeviceDlgID)(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID);
      HRESULT (WINAPI *GetImageDlg)(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,LONG lIntent,IWiaItem *pItemRoot,BSTR bstrFilename,GUID *pguidFormat);
      HRESULT (WINAPI *RegisterEventCallbackProgram)(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,BSTR bstrCommandline,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
      HRESULT (WINAPI *RegisterEventCallbackInterface)(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,IWiaEventCallback *pIWiaEventCallback,IUnknown **pEventObject);
      HRESULT (WINAPI *RegisterEventCallbackCLSID)(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,const GUID *pClsID,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
      HRESULT (WINAPI *AddDeviceDlg)(IWiaDevMgr *This,HWND hwndParent,LONG lFlags);
    END_INTERFACE
  } IWiaDevMgrVtbl;
  struct IWiaDevMgr {
    CONST_VTBL struct IWiaDevMgrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaDevMgr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaDevMgr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaDevMgr_Release(This) (This)->lpVtbl->Release(This)
#define IWiaDevMgr_EnumDeviceInfo(This,lFlag,ppIEnum) (This)->lpVtbl->EnumDeviceInfo(This,lFlag,ppIEnum)
#define IWiaDevMgr_CreateDevice(This,bstrDeviceID,ppWiaItemRoot) (This)->lpVtbl->CreateDevice(This,bstrDeviceID,ppWiaItemRoot)
#define IWiaDevMgr_SelectDeviceDlg(This,hwndParent,lDeviceType,lFlags,pbstrDeviceID,ppItemRoot) (This)->lpVtbl->SelectDeviceDlg(This,hwndParent,lDeviceType,lFlags,pbstrDeviceID,ppItemRoot)
#define IWiaDevMgr_SelectDeviceDlgID(This,hwndParent,lDeviceType,lFlags,pbstrDeviceID) (This)->lpVtbl->SelectDeviceDlgID(This,hwndParent,lDeviceType,lFlags,pbstrDeviceID)
#define IWiaDevMgr_GetImageDlg(This,hwndParent,lDeviceType,lFlags,lIntent,pItemRoot,bstrFilename,pguidFormat) (This)->lpVtbl->GetImageDlg(This,hwndParent,lDeviceType,lFlags,lIntent,pItemRoot,bstrFilename,pguidFormat)
#define IWiaDevMgr_RegisterEventCallbackProgram(This,lFlags,bstrDeviceID,pEventGUID,bstrCommandline,bstrName,bstrDescription,bstrIcon) (This)->lpVtbl->RegisterEventCallbackProgram(This,lFlags,bstrDeviceID,pEventGUID,bstrCommandline,bstrName,bstrDescription,bstrIcon)
#define IWiaDevMgr_RegisterEventCallbackInterface(This,lFlags,bstrDeviceID,pEventGUID,pIWiaEventCallback,pEventObject) (This)->lpVtbl->RegisterEventCallbackInterface(This,lFlags,bstrDeviceID,pEventGUID,pIWiaEventCallback,pEventObject)
#define IWiaDevMgr_RegisterEventCallbackCLSID(This,lFlags,bstrDeviceID,pEventGUID,pClsID,bstrName,bstrDescription,bstrIcon) (This)->lpVtbl->RegisterEventCallbackCLSID(This,lFlags,bstrDeviceID,pEventGUID,pClsID,bstrName,bstrDescription,bstrIcon)
#define IWiaDevMgr_AddDeviceDlg(This,hwndParent,lFlags) (This)->lpVtbl->AddDeviceDlg(This,hwndParent,lFlags)
#endif
#endif
  HRESULT WINAPI IWiaDevMgr_EnumDeviceInfo_Proxy(IWiaDevMgr *This,LONG lFlag,IEnumWIA_DEV_INFO **ppIEnum);
  void __RPC_STUB IWiaDevMgr_EnumDeviceInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_LocalCreateDevice_Proxy(IWiaDevMgr *This,BSTR bstrDeviceID,IWiaItem **ppWiaItemRoot);
  void __RPC_STUB IWiaDevMgr_LocalCreateDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_LocalSelectDeviceDlg_Proxy(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID,IWiaItem **ppItemRoot);
  void __RPC_STUB IWiaDevMgr_LocalSelectDeviceDlg_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_LocalSelectDeviceDlgID_Proxy(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID);
  void __RPC_STUB IWiaDevMgr_LocalSelectDeviceDlgID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_LocalGetImageDlg_Proxy(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,LONG lIntent,IWiaItem *pItemRoot,BSTR bstrFilename,GUID *pguidFormat);
  void __RPC_STUB IWiaDevMgr_LocalGetImageDlg_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_LocalRegisterEventCallbackProgram_Proxy(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,BSTR bstrCommandline,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
  void __RPC_STUB IWiaDevMgr_LocalRegisterEventCallbackProgram_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_LocalRegisterEventCallbackInterface_Proxy(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,IWiaEventCallback *pIWiaEventCallback,IUnknown **pEventObject);
  void __RPC_STUB IWiaDevMgr_LocalRegisterEventCallbackInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_LocalRegisterEventCallbackCLSID_Proxy(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,const GUID *pClsID,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
  void __RPC_STUB IWiaDevMgr_LocalRegisterEventCallbackCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDevMgr_AddDeviceDlg_Proxy(IWiaDevMgr *This,HWND hwndParent,LONG lFlags);
  void __RPC_STUB IWiaDevMgr_AddDeviceDlg_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumWIA_DEV_INFO_INTERFACE_DEFINED__
#define __IEnumWIA_DEV_INFO_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumWIA_DEV_INFO;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumWIA_DEV_INFO : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IWiaPropertyStorage **rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumWIA_DEV_INFO **ppIEnum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *celt) = 0;
  };
#else
  typedef struct IEnumWIA_DEV_INFOVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumWIA_DEV_INFO *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumWIA_DEV_INFO *This);
      ULONG (WINAPI *Release)(IEnumWIA_DEV_INFO *This);
      HRESULT (WINAPI *Next)(IEnumWIA_DEV_INFO *This,ULONG celt,IWiaPropertyStorage **rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumWIA_DEV_INFO *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumWIA_DEV_INFO *This);
      HRESULT (WINAPI *Clone)(IEnumWIA_DEV_INFO *This,IEnumWIA_DEV_INFO **ppIEnum);
      HRESULT (WINAPI *GetCount)(IEnumWIA_DEV_INFO *This,ULONG *celt);
    END_INTERFACE
  } IEnumWIA_DEV_INFOVtbl;
  struct IEnumWIA_DEV_INFO {
    CONST_VTBL struct IEnumWIA_DEV_INFOVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumWIA_DEV_INFO_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumWIA_DEV_INFO_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumWIA_DEV_INFO_Release(This) (This)->lpVtbl->Release(This)
#define IEnumWIA_DEV_INFO_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumWIA_DEV_INFO_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumWIA_DEV_INFO_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumWIA_DEV_INFO_Clone(This,ppIEnum) (This)->lpVtbl->Clone(This,ppIEnum)
#define IEnumWIA_DEV_INFO_GetCount(This,celt) (This)->lpVtbl->GetCount(This,celt)
#endif
#endif
  HRESULT WINAPI IEnumWIA_DEV_INFO_RemoteNext_Proxy(IEnumWIA_DEV_INFO *This,ULONG celt,IWiaPropertyStorage **rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumWIA_DEV_INFO_RemoteNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_INFO_Skip_Proxy(IEnumWIA_DEV_INFO *This,ULONG celt);
  void __RPC_STUB IEnumWIA_DEV_INFO_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_INFO_Reset_Proxy(IEnumWIA_DEV_INFO *This);
  void __RPC_STUB IEnumWIA_DEV_INFO_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_INFO_Clone_Proxy(IEnumWIA_DEV_INFO *This,IEnumWIA_DEV_INFO **ppIEnum);
  void __RPC_STUB IEnumWIA_DEV_INFO_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_INFO_GetCount_Proxy(IEnumWIA_DEV_INFO *This,ULONG *celt);
  void __RPC_STUB IEnumWIA_DEV_INFO_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWiaEventCallback_INTERFACE_DEFINED__
#define __IWiaEventCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaEventCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaEventCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI ImageEventCallback(const GUID *pEventGUID,BSTR bstrEventDescription,BSTR bstrDeviceID,BSTR bstrDeviceDescription,DWORD dwDeviceType,BSTR bstrFullItemName,ULONG *pulEventType,ULONG ulReserved) = 0;
  };
#else
  typedef struct IWiaEventCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaEventCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaEventCallback *This);
      ULONG (WINAPI *Release)(IWiaEventCallback *This);
      HRESULT (WINAPI *ImageEventCallback)(IWiaEventCallback *This,const GUID *pEventGUID,BSTR bstrEventDescription,BSTR bstrDeviceID,BSTR bstrDeviceDescription,DWORD dwDeviceType,BSTR bstrFullItemName,ULONG *pulEventType,ULONG ulReserved);
    END_INTERFACE
  } IWiaEventCallbackVtbl;
  struct IWiaEventCallback {
    CONST_VTBL struct IWiaEventCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaEventCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaEventCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaEventCallback_Release(This) (This)->lpVtbl->Release(This)
#define IWiaEventCallback_ImageEventCallback(This,pEventGUID,bstrEventDescription,bstrDeviceID,bstrDeviceDescription,dwDeviceType,bstrFullItemName,pulEventType,ulReserved) (This)->lpVtbl->ImageEventCallback(This,pEventGUID,bstrEventDescription,bstrDeviceID,bstrDeviceDescription,dwDeviceType,bstrFullItemName,pulEventType,ulReserved)
#endif
#endif
  HRESULT WINAPI IWiaEventCallback_ImageEventCallback_Proxy(IWiaEventCallback *This,const GUID *pEventGUID,BSTR bstrEventDescription,BSTR bstrDeviceID,BSTR bstrDeviceDescription,DWORD dwDeviceType,BSTR bstrFullItemName,ULONG *pulEventType,ULONG ulReserved);
  void __RPC_STUB IWiaEventCallback_ImageEventCallback_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef struct _WIA_DATA_CALLBACK_HEADER {
    LONG lSize;
    GUID guidFormatID;
    LONG lBufferSize;
    LONG lPageCount;
  } WIA_DATA_CALLBACK_HEADER;

  typedef struct _WIA_DATA_CALLBACK_HEADER *PWIA_DATA_CALLBACK_HEADER;

  extern RPC_IF_HANDLE __MIDL_itf_wia_0125_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wia_0125_v0_0_s_ifspec;
#ifndef __IWiaDataCallback_INTERFACE_DEFINED__
#define __IWiaDataCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaDataCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaDataCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI BandedDataCallback(LONG lMessage,LONG lStatus,LONG lPercentComplete,LONG lOffset,LONG lLength,LONG lReserved,LONG lResLength,BYTE *pbBuffer) = 0;
  };
#else
  typedef struct IWiaDataCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaDataCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaDataCallback *This);
      ULONG (WINAPI *Release)(IWiaDataCallback *This);
      HRESULT (WINAPI *BandedDataCallback)(IWiaDataCallback *This,LONG lMessage,LONG lStatus,LONG lPercentComplete,LONG lOffset,LONG lLength,LONG lReserved,LONG lResLength,BYTE *pbBuffer);
    END_INTERFACE
  } IWiaDataCallbackVtbl;
  struct IWiaDataCallback {
    CONST_VTBL struct IWiaDataCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaDataCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaDataCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaDataCallback_Release(This) (This)->lpVtbl->Release(This)
#define IWiaDataCallback_BandedDataCallback(This,lMessage,lStatus,lPercentComplete,lOffset,lLength,lReserved,lResLength,pbBuffer) (This)->lpVtbl->BandedDataCallback(This,lMessage,lStatus,lPercentComplete,lOffset,lLength,lReserved,lResLength,pbBuffer)
#endif
#endif
  HRESULT WINAPI IWiaDataCallback_RemoteBandedDataCallback_Proxy(IWiaDataCallback *This,LONG lMessage,LONG lStatus,LONG lPercentComplete,LONG lOffset,LONG lLength,LONG lReserved,LONG lResLength,BYTE *pbBuffer);
  void __RPC_STUB IWiaDataCallback_RemoteBandedDataCallback_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef struct _WIA_DATA_TRANSFER_INFO {
    ULONG ulSize;
    ULONG ulSection;
    ULONG ulBufferSize;
    WINBOOL bDoubleBuffer;
    ULONG ulReserved1;
    ULONG ulReserved2;
    ULONG ulReserved3;
  } WIA_DATA_TRANSFER_INFO;

  typedef struct _WIA_DATA_TRANSFER_INFO *PWIA_DATA_TRANSFER_INFO;

  typedef struct _WIA_EXTENDED_TRANSFER_INFO {
    ULONG ulSize;
    ULONG ulMinBufferSize;
    ULONG ulOptimalBufferSize;
    ULONG ulMaxBufferSize;
    ULONG ulNumBuffers;
  } WIA_EXTENDED_TRANSFER_INFO;

  typedef struct _WIA_EXTENDED_TRANSFER_INFO *PWIA_EXTENDED_TRANSFER_INFO;

  extern RPC_IF_HANDLE __MIDL_itf_wia_0126_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wia_0126_v0_0_s_ifspec;
#ifndef __IWiaDataTransfer_INTERFACE_DEFINED__
#define __IWiaDataTransfer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaDataTransfer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaDataTransfer : public IUnknown {
  public:
    virtual HRESULT WINAPI idtGetData(LPSTGMEDIUM pMedium,IWiaDataCallback *pIWiaDataCallback) = 0;
    virtual HRESULT WINAPI idtGetBandedData(PWIA_DATA_TRANSFER_INFO pWiaDataTransInfo,IWiaDataCallback *pIWiaDataCallback) = 0;
    virtual HRESULT WINAPI idtQueryGetData(WIA_FORMAT_INFO *pfe) = 0;
    virtual HRESULT WINAPI idtEnumWIA_FORMAT_INFO(IEnumWIA_FORMAT_INFO **ppEnum) = 0;
    virtual HRESULT WINAPI idtGetExtendedTransferInfo(PWIA_EXTENDED_TRANSFER_INFO pExtendedTransferInfo) = 0;
  };
#else
  typedef struct IWiaDataTransferVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaDataTransfer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaDataTransfer *This);
      ULONG (WINAPI *Release)(IWiaDataTransfer *This);
      HRESULT (WINAPI *idtGetData)(IWiaDataTransfer *This,LPSTGMEDIUM pMedium,IWiaDataCallback *pIWiaDataCallback);
      HRESULT (WINAPI *idtGetBandedData)(IWiaDataTransfer *This,PWIA_DATA_TRANSFER_INFO pWiaDataTransInfo,IWiaDataCallback *pIWiaDataCallback);
      HRESULT (WINAPI *idtQueryGetData)(IWiaDataTransfer *This,WIA_FORMAT_INFO *pfe);
      HRESULT (WINAPI *idtEnumWIA_FORMAT_INFO)(IWiaDataTransfer *This,IEnumWIA_FORMAT_INFO **ppEnum);
      HRESULT (WINAPI *idtGetExtendedTransferInfo)(IWiaDataTransfer *This,PWIA_EXTENDED_TRANSFER_INFO pExtendedTransferInfo);
    END_INTERFACE
  } IWiaDataTransferVtbl;
  struct IWiaDataTransfer {
    CONST_VTBL struct IWiaDataTransferVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaDataTransfer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaDataTransfer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaDataTransfer_Release(This) (This)->lpVtbl->Release(This)
#define IWiaDataTransfer_idtGetData(This,pMedium,pIWiaDataCallback) (This)->lpVtbl->idtGetData(This,pMedium,pIWiaDataCallback)
#define IWiaDataTransfer_idtGetBandedData(This,pWiaDataTransInfo,pIWiaDataCallback) (This)->lpVtbl->idtGetBandedData(This,pWiaDataTransInfo,pIWiaDataCallback)
#define IWiaDataTransfer_idtQueryGetData(This,pfe) (This)->lpVtbl->idtQueryGetData(This,pfe)
#define IWiaDataTransfer_idtEnumWIA_FORMAT_INFO(This,ppEnum) (This)->lpVtbl->idtEnumWIA_FORMAT_INFO(This,ppEnum)
#define IWiaDataTransfer_idtGetExtendedTransferInfo(This,pExtendedTransferInfo) (This)->lpVtbl->idtGetExtendedTransferInfo(This,pExtendedTransferInfo)
#endif
#endif
  HRESULT WINAPI IWiaDataTransfer_idtGetDataEx_Proxy(IWiaDataTransfer *This,LPSTGMEDIUM pMedium,IWiaDataCallback *pIWiaDataCallback);
  void __RPC_STUB IWiaDataTransfer_idtGetDataEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDataTransfer_idtGetBandedDataEx_Proxy(IWiaDataTransfer *This,PWIA_DATA_TRANSFER_INFO pWiaDataTransInfo,IWiaDataCallback *pIWiaDataCallback);
  void __RPC_STUB IWiaDataTransfer_idtGetBandedDataEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDataTransfer_idtQueryGetData_Proxy(IWiaDataTransfer *This,WIA_FORMAT_INFO *pfe);
  void __RPC_STUB IWiaDataTransfer_idtQueryGetData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDataTransfer_idtEnumWIA_FORMAT_INFO_Proxy(IWiaDataTransfer *This,IEnumWIA_FORMAT_INFO **ppEnum);
  void __RPC_STUB IWiaDataTransfer_idtEnumWIA_FORMAT_INFO_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaDataTransfer_idtGetExtendedTransferInfo_Proxy(IWiaDataTransfer *This,PWIA_EXTENDED_TRANSFER_INFO pExtendedTransferInfo);
  void __RPC_STUB IWiaDataTransfer_idtGetExtendedTransferInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWiaItem_INTERFACE_DEFINED__
#define __IWiaItem_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaItem;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaItem : public IUnknown {
  public:
    virtual HRESULT WINAPI GetItemType(LONG *pItemType) = 0;
    virtual HRESULT WINAPI AnalyzeItem(LONG lFlags) = 0;
    virtual HRESULT WINAPI EnumChildItems(IEnumWiaItem **ppIEnumWiaItem) = 0;
    virtual HRESULT WINAPI DeleteItem(LONG lFlags) = 0;
    virtual HRESULT WINAPI CreateChildItem(LONG lFlags,BSTR bstrItemName,BSTR bstrFullItemName,IWiaItem **ppIWiaItem) = 0;
    virtual HRESULT WINAPI EnumRegisterEventInfo(LONG lFlags,const GUID *pEventGUID,IEnumWIA_DEV_CAPS **ppIEnum) = 0;
    virtual HRESULT WINAPI FindItemByName(LONG lFlags,BSTR bstrFullItemName,IWiaItem **ppIWiaItem) = 0;
    virtual HRESULT WINAPI DeviceDlg(HWND hwndParent,LONG lFlags,LONG lIntent,LONG *plItemCount,IWiaItem ***ppIWiaItem) = 0;
    virtual HRESULT WINAPI DeviceCommand(LONG lFlags,const GUID *pCmdGUID,IWiaItem **pIWiaItem) = 0;
    virtual HRESULT WINAPI GetRootItem(IWiaItem **ppIWiaItem) = 0;
    virtual HRESULT WINAPI EnumDeviceCapabilities(LONG lFlags,IEnumWIA_DEV_CAPS **ppIEnumWIA_DEV_CAPS) = 0;
    virtual HRESULT WINAPI DumpItemData(BSTR *bstrData) = 0;
    virtual HRESULT WINAPI DumpDrvItemData(BSTR *bstrData) = 0;
    virtual HRESULT WINAPI DumpTreeItemData(BSTR *bstrData) = 0;
    virtual HRESULT WINAPI Diagnostic(ULONG ulSize,BYTE *pBuffer) = 0;
  };
#else
  typedef struct IWiaItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaItem *This);
      ULONG (WINAPI *Release)(IWiaItem *This);
      HRESULT (WINAPI *GetItemType)(IWiaItem *This,LONG *pItemType);
      HRESULT (WINAPI *AnalyzeItem)(IWiaItem *This,LONG lFlags);
      HRESULT (WINAPI *EnumChildItems)(IWiaItem *This,IEnumWiaItem **ppIEnumWiaItem);
      HRESULT (WINAPI *DeleteItem)(IWiaItem *This,LONG lFlags);
      HRESULT (WINAPI *CreateChildItem)(IWiaItem *This,LONG lFlags,BSTR bstrItemName,BSTR bstrFullItemName,IWiaItem **ppIWiaItem);
      HRESULT (WINAPI *EnumRegisterEventInfo)(IWiaItem *This,LONG lFlags,const GUID *pEventGUID,IEnumWIA_DEV_CAPS **ppIEnum);
      HRESULT (WINAPI *FindItemByName)(IWiaItem *This,LONG lFlags,BSTR bstrFullItemName,IWiaItem **ppIWiaItem);
      HRESULT (WINAPI *DeviceDlg)(IWiaItem *This,HWND hwndParent,LONG lFlags,LONG lIntent,LONG *plItemCount,IWiaItem ***ppIWiaItem);
      HRESULT (WINAPI *DeviceCommand)(IWiaItem *This,LONG lFlags,const GUID *pCmdGUID,IWiaItem **pIWiaItem);
      HRESULT (WINAPI *GetRootItem)(IWiaItem *This,IWiaItem **ppIWiaItem);
      HRESULT (WINAPI *EnumDeviceCapabilities)(IWiaItem *This,LONG lFlags,IEnumWIA_DEV_CAPS **ppIEnumWIA_DEV_CAPS);
      HRESULT (WINAPI *DumpItemData)(IWiaItem *This,BSTR *bstrData);
      HRESULT (WINAPI *DumpDrvItemData)(IWiaItem *This,BSTR *bstrData);
      HRESULT (WINAPI *DumpTreeItemData)(IWiaItem *This,BSTR *bstrData);
      HRESULT (WINAPI *Diagnostic)(IWiaItem *This,ULONG ulSize,BYTE *pBuffer);
    END_INTERFACE
  } IWiaItemVtbl;
  struct IWiaItem {
    CONST_VTBL struct IWiaItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaItem_Release(This) (This)->lpVtbl->Release(This)
#define IWiaItem_GetItemType(This,pItemType) (This)->lpVtbl->GetItemType(This,pItemType)
#define IWiaItem_AnalyzeItem(This,lFlags) (This)->lpVtbl->AnalyzeItem(This,lFlags)
#define IWiaItem_EnumChildItems(This,ppIEnumWiaItem) (This)->lpVtbl->EnumChildItems(This,ppIEnumWiaItem)
#define IWiaItem_DeleteItem(This,lFlags) (This)->lpVtbl->DeleteItem(This,lFlags)
#define IWiaItem_CreateChildItem(This,lFlags,bstrItemName,bstrFullItemName,ppIWiaItem) (This)->lpVtbl->CreateChildItem(This,lFlags,bstrItemName,bstrFullItemName,ppIWiaItem)
#define IWiaItem_EnumRegisterEventInfo(This,lFlags,pEventGUID,ppIEnum) (This)->lpVtbl->EnumRegisterEventInfo(This,lFlags,pEventGUID,ppIEnum)
#define IWiaItem_FindItemByName(This,lFlags,bstrFullItemName,ppIWiaItem) (This)->lpVtbl->FindItemByName(This,lFlags,bstrFullItemName,ppIWiaItem)
#define IWiaItem_DeviceDlg(This,hwndParent,lFlags,lIntent,plItemCount,ppIWiaItem) (This)->lpVtbl->DeviceDlg(This,hwndParent,lFlags,lIntent,plItemCount,ppIWiaItem)
#define IWiaItem_DeviceCommand(This,lFlags,pCmdGUID,pIWiaItem) (This)->lpVtbl->DeviceCommand(This,lFlags,pCmdGUID,pIWiaItem)
#define IWiaItem_GetRootItem(This,ppIWiaItem) (This)->lpVtbl->GetRootItem(This,ppIWiaItem)
#define IWiaItem_EnumDeviceCapabilities(This,lFlags,ppIEnumWIA_DEV_CAPS) (This)->lpVtbl->EnumDeviceCapabilities(This,lFlags,ppIEnumWIA_DEV_CAPS)
#define IWiaItem_DumpItemData(This,bstrData) (This)->lpVtbl->DumpItemData(This,bstrData)
#define IWiaItem_DumpDrvItemData(This,bstrData) (This)->lpVtbl->DumpDrvItemData(This,bstrData)
#define IWiaItem_DumpTreeItemData(This,bstrData) (This)->lpVtbl->DumpTreeItemData(This,bstrData)
#define IWiaItem_Diagnostic(This,ulSize,pBuffer) (This)->lpVtbl->Diagnostic(This,ulSize,pBuffer)
#endif
#endif
  HRESULT WINAPI IWiaItem_GetItemType_Proxy(IWiaItem *This,LONG *pItemType);
  void __RPC_STUB IWiaItem_GetItemType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_AnalyzeItem_Proxy(IWiaItem *This,LONG lFlags);
  void __RPC_STUB IWiaItem_AnalyzeItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_EnumChildItems_Proxy(IWiaItem *This,IEnumWiaItem **ppIEnumWiaItem);
  void __RPC_STUB IWiaItem_EnumChildItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_DeleteItem_Proxy(IWiaItem *This,LONG lFlags);
  void __RPC_STUB IWiaItem_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_CreateChildItem_Proxy(IWiaItem *This,LONG lFlags,BSTR bstrItemName,BSTR bstrFullItemName,IWiaItem **ppIWiaItem);
  void __RPC_STUB IWiaItem_CreateChildItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_EnumRegisterEventInfo_Proxy(IWiaItem *This,LONG lFlags,const GUID *pEventGUID,IEnumWIA_DEV_CAPS **ppIEnum);
  void __RPC_STUB IWiaItem_EnumRegisterEventInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_FindItemByName_Proxy(IWiaItem *This,LONG lFlags,BSTR bstrFullItemName,IWiaItem **ppIWiaItem);
  void __RPC_STUB IWiaItem_FindItemByName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_LocalDeviceDlg_Proxy(IWiaItem *This,HWND hwndParent,LONG lFlags,LONG lIntent,LONG *plItemCount,IWiaItem ***pIWiaItem);
  void __RPC_STUB IWiaItem_LocalDeviceDlg_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_DeviceCommand_Proxy(IWiaItem *This,LONG lFlags,const GUID *pCmdGUID,IWiaItem **pIWiaItem);
  void __RPC_STUB IWiaItem_DeviceCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_GetRootItem_Proxy(IWiaItem *This,IWiaItem **ppIWiaItem);
  void __RPC_STUB IWiaItem_GetRootItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_EnumDeviceCapabilities_Proxy(IWiaItem *This,LONG lFlags,IEnumWIA_DEV_CAPS **ppIEnumWIA_DEV_CAPS);
  void __RPC_STUB IWiaItem_EnumDeviceCapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_DumpItemData_Proxy(IWiaItem *This,BSTR *bstrData);
  void __RPC_STUB IWiaItem_DumpItemData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_DumpDrvItemData_Proxy(IWiaItem *This,BSTR *bstrData);
  void __RPC_STUB IWiaItem_DumpDrvItemData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_DumpTreeItemData_Proxy(IWiaItem *This,BSTR *bstrData);
  void __RPC_STUB IWiaItem_DumpTreeItemData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItem_Diagnostic_Proxy(IWiaItem *This,ULONG ulSize,BYTE *pBuffer);
  void __RPC_STUB IWiaItem_Diagnostic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWiaPropertyStorage_INTERFACE_DEFINED__
#define __IWiaPropertyStorage_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaPropertyStorage;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaPropertyStorage : public IUnknown {
  public:
    virtual HRESULT WINAPI ReadMultiple(ULONG cpspec,const PROPSPEC rgpspec[],PROPVARIANT rgpropvar[]) = 0;
    virtual HRESULT WINAPI WriteMultiple(ULONG cpspec,const PROPSPEC rgpspec[],const PROPVARIANT rgpropvar[],PROPID propidNameFirst) = 0;
    virtual HRESULT WINAPI DeleteMultiple(ULONG cpspec,const PROPSPEC rgpspec[]) = 0;
    virtual HRESULT WINAPI ReadPropertyNames(ULONG cpropid,const PROPID rgpropid[],LPOLESTR rglpwstrName[]) = 0;
    virtual HRESULT WINAPI WritePropertyNames(ULONG cpropid,const PROPID rgpropid[],const LPOLESTR rglpwstrName[]) = 0;
    virtual HRESULT WINAPI DeletePropertyNames(ULONG cpropid,const PROPID rgpropid[]) = 0;
    virtual HRESULT WINAPI Commit(DWORD grfCommitFlags) = 0;
    virtual HRESULT WINAPI Revert(void) = 0;
    virtual HRESULT WINAPI Enum(IEnumSTATPROPSTG **ppenum) = 0;
    virtual HRESULT WINAPI SetTimes(const FILETIME *pctime,const FILETIME *patime,const FILETIME *pmtime) = 0;
    virtual HRESULT WINAPI SetClass(REFCLSID clsid) = 0;
    virtual HRESULT WINAPI Stat(STATPROPSETSTG *pstatpsstg) = 0;
    virtual HRESULT WINAPI GetPropertyAttributes(ULONG cpspec,PROPSPEC rgpspec[],ULONG rgflags[],PROPVARIANT rgpropvar[]) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *pulNumProps) = 0;
    virtual HRESULT WINAPI GetPropertyStream(GUID *pCompatibilityId,IStream **ppIStream) = 0;
    virtual HRESULT WINAPI SetPropertyStream(GUID *pCompatibilityId,IStream *pIStream) = 0;
  };
#else
  typedef struct IWiaPropertyStorageVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaPropertyStorage *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaPropertyStorage *This);
      ULONG (WINAPI *Release)(IWiaPropertyStorage *This);
      HRESULT (WINAPI *ReadMultiple)(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC rgpspec[],PROPVARIANT rgpropvar[]);
      HRESULT (WINAPI *WriteMultiple)(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC rgpspec[],const PROPVARIANT rgpropvar[],PROPID propidNameFirst);
      HRESULT (WINAPI *DeleteMultiple)(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC rgpspec[]);
      HRESULT (WINAPI *ReadPropertyNames)(IWiaPropertyStorage *This,ULONG cpropid,const PROPID rgpropid[],LPOLESTR rglpwstrName[]);
      HRESULT (WINAPI *WritePropertyNames)(IWiaPropertyStorage *This,ULONG cpropid,const PROPID rgpropid[],const LPOLESTR rglpwstrName[]);
      HRESULT (WINAPI *DeletePropertyNames)(IWiaPropertyStorage *This,ULONG cpropid,const PROPID rgpropid[]);
      HRESULT (WINAPI *Commit)(IWiaPropertyStorage *This,DWORD grfCommitFlags);
      HRESULT (WINAPI *Revert)(IWiaPropertyStorage *This);
      HRESULT (WINAPI *Enum)(IWiaPropertyStorage *This,IEnumSTATPROPSTG **ppenum);
      HRESULT (WINAPI *SetTimes)(IWiaPropertyStorage *This,const FILETIME *pctime,const FILETIME *patime,const FILETIME *pmtime);
      HRESULT (WINAPI *SetClass)(IWiaPropertyStorage *This,REFCLSID clsid);
      HRESULT (WINAPI *Stat)(IWiaPropertyStorage *This,STATPROPSETSTG *pstatpsstg);
      HRESULT (WINAPI *GetPropertyAttributes)(IWiaPropertyStorage *This,ULONG cpspec,PROPSPEC rgpspec[],ULONG rgflags[],PROPVARIANT rgpropvar[]);
      HRESULT (WINAPI *GetCount)(IWiaPropertyStorage *This,ULONG *pulNumProps);
      HRESULT (WINAPI *GetPropertyStream)(IWiaPropertyStorage *This,GUID *pCompatibilityId,IStream **ppIStream);
      HRESULT (WINAPI *SetPropertyStream)(IWiaPropertyStorage *This,GUID *pCompatibilityId,IStream *pIStream);
    END_INTERFACE
  } IWiaPropertyStorageVtbl;
  struct IWiaPropertyStorage {
    CONST_VTBL struct IWiaPropertyStorageVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaPropertyStorage_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaPropertyStorage_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaPropertyStorage_Release(This) (This)->lpVtbl->Release(This)
#define IWiaPropertyStorage_ReadMultiple(This,cpspec,rgpspec,rgpropvar) (This)->lpVtbl->ReadMultiple(This,cpspec,rgpspec,rgpropvar)
#define IWiaPropertyStorage_WriteMultiple(This,cpspec,rgpspec,rgpropvar,propidNameFirst) (This)->lpVtbl->WriteMultiple(This,cpspec,rgpspec,rgpropvar,propidNameFirst)
#define IWiaPropertyStorage_DeleteMultiple(This,cpspec,rgpspec) (This)->lpVtbl->DeleteMultiple(This,cpspec,rgpspec)
#define IWiaPropertyStorage_ReadPropertyNames(This,cpropid,rgpropid,rglpwstrName) (This)->lpVtbl->ReadPropertyNames(This,cpropid,rgpropid,rglpwstrName)
#define IWiaPropertyStorage_WritePropertyNames(This,cpropid,rgpropid,rglpwstrName) (This)->lpVtbl->WritePropertyNames(This,cpropid,rgpropid,rglpwstrName)
#define IWiaPropertyStorage_DeletePropertyNames(This,cpropid,rgpropid) (This)->lpVtbl->DeletePropertyNames(This,cpropid,rgpropid)
#define IWiaPropertyStorage_Commit(This,grfCommitFlags) (This)->lpVtbl->Commit(This,grfCommitFlags)
#define IWiaPropertyStorage_Revert(This) (This)->lpVtbl->Revert(This)
#define IWiaPropertyStorage_Enum(This,ppenum) (This)->lpVtbl->Enum(This,ppenum)
#define IWiaPropertyStorage_SetTimes(This,pctime,patime,pmtime) (This)->lpVtbl->SetTimes(This,pctime,patime,pmtime)
#define IWiaPropertyStorage_SetClass(This,clsid) (This)->lpVtbl->SetClass(This,clsid)
#define IWiaPropertyStorage_Stat(This,pstatpsstg) (This)->lpVtbl->Stat(This,pstatpsstg)
#define IWiaPropertyStorage_GetPropertyAttributes(This,cpspec,rgpspec,rgflags,rgpropvar) (This)->lpVtbl->GetPropertyAttributes(This,cpspec,rgpspec,rgflags,rgpropvar)
#define IWiaPropertyStorage_GetCount(This,pulNumProps) (This)->lpVtbl->GetCount(This,pulNumProps)
#define IWiaPropertyStorage_GetPropertyStream(This,pCompatibilityId,ppIStream) (This)->lpVtbl->GetPropertyStream(This,pCompatibilityId,ppIStream)
#define IWiaPropertyStorage_SetPropertyStream(This,pCompatibilityId,pIStream) (This)->lpVtbl->SetPropertyStream(This,pCompatibilityId,pIStream)
#endif
#endif
  HRESULT WINAPI IWiaPropertyStorage_ReadMultiple_Proxy(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC rgpspec[],PROPVARIANT rgpropvar[]);
  void __RPC_STUB IWiaPropertyStorage_ReadMultiple_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_RemoteWriteMultiple_Proxy(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC *rgpspec,const PROPVARIANT *rgpropvar,PROPID propidNameFirst);
  void __RPC_STUB IWiaPropertyStorage_RemoteWriteMultiple_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_DeleteMultiple_Proxy(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC rgpspec[]);
  void __RPC_STUB IWiaPropertyStorage_DeleteMultiple_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_ReadPropertyNames_Proxy(IWiaPropertyStorage *This,ULONG cpropid,const PROPID rgpropid[],LPOLESTR rglpwstrName[]);
  void __RPC_STUB IWiaPropertyStorage_ReadPropertyNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_WritePropertyNames_Proxy(IWiaPropertyStorage *This,ULONG cpropid,const PROPID rgpropid[],const LPOLESTR rglpwstrName[]);
  void __RPC_STUB IWiaPropertyStorage_WritePropertyNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_DeletePropertyNames_Proxy(IWiaPropertyStorage *This,ULONG cpropid,const PROPID rgpropid[]);
  void __RPC_STUB IWiaPropertyStorage_DeletePropertyNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_Commit_Proxy(IWiaPropertyStorage *This,DWORD grfCommitFlags);
  void __RPC_STUB IWiaPropertyStorage_Commit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_Revert_Proxy(IWiaPropertyStorage *This);
  void __RPC_STUB IWiaPropertyStorage_Revert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_Enum_Proxy(IWiaPropertyStorage *This,IEnumSTATPROPSTG **ppenum);
  void __RPC_STUB IWiaPropertyStorage_Enum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_SetTimes_Proxy(IWiaPropertyStorage *This,const FILETIME *pctime,const FILETIME *patime,const FILETIME *pmtime);
  void __RPC_STUB IWiaPropertyStorage_SetTimes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_SetClass_Proxy(IWiaPropertyStorage *This,REFCLSID clsid);
  void __RPC_STUB IWiaPropertyStorage_SetClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_Stat_Proxy(IWiaPropertyStorage *This,STATPROPSETSTG *pstatpsstg);
  void __RPC_STUB IWiaPropertyStorage_Stat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_GetPropertyAttributes_Proxy(IWiaPropertyStorage *This,ULONG cpspec,PROPSPEC rgpspec[],ULONG rgflags[],PROPVARIANT rgpropvar[]);
  void __RPC_STUB IWiaPropertyStorage_GetPropertyAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_GetCount_Proxy(IWiaPropertyStorage *This,ULONG *pulNumProps);
  void __RPC_STUB IWiaPropertyStorage_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_GetPropertyStream_Proxy(IWiaPropertyStorage *This,GUID *pCompatibilityId,IStream **ppIStream);
  void __RPC_STUB IWiaPropertyStorage_GetPropertyStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaPropertyStorage_RemoteSetPropertyStream_Proxy(IWiaPropertyStorage *This,GUID *pCompatibilityId,IStream *pIStream);
  void __RPC_STUB IWiaPropertyStorage_RemoteSetPropertyStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumWiaItem_INTERFACE_DEFINED__
#define __IEnumWiaItem_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumWiaItem;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumWiaItem : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IWiaItem **ppIWiaItem,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumWiaItem **ppIEnum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *celt) = 0;
  };
#else
  typedef struct IEnumWiaItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumWiaItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumWiaItem *This);
      ULONG (WINAPI *Release)(IEnumWiaItem *This);
      HRESULT (WINAPI *Next)(IEnumWiaItem *This,ULONG celt,IWiaItem **ppIWiaItem,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumWiaItem *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumWiaItem *This);
      HRESULT (WINAPI *Clone)(IEnumWiaItem *This,IEnumWiaItem **ppIEnum);
      HRESULT (WINAPI *GetCount)(IEnumWiaItem *This,ULONG *celt);
    END_INTERFACE
  } IEnumWiaItemVtbl;
  struct IEnumWiaItem {
    CONST_VTBL struct IEnumWiaItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumWiaItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumWiaItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumWiaItem_Release(This) (This)->lpVtbl->Release(This)
#define IEnumWiaItem_Next(This,celt,ppIWiaItem,pceltFetched) (This)->lpVtbl->Next(This,celt,ppIWiaItem,pceltFetched)
#define IEnumWiaItem_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumWiaItem_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumWiaItem_Clone(This,ppIEnum) (This)->lpVtbl->Clone(This,ppIEnum)
#define IEnumWiaItem_GetCount(This,celt) (This)->lpVtbl->GetCount(This,celt)
#endif
#endif
  HRESULT WINAPI IEnumWiaItem_RemoteNext_Proxy(IEnumWiaItem *This,ULONG celt,IWiaItem **ppIWiaItem,ULONG *pceltFetched);
  void __RPC_STUB IEnumWiaItem_RemoteNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWiaItem_Skip_Proxy(IEnumWiaItem *This,ULONG celt);
  void __RPC_STUB IEnumWiaItem_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWiaItem_Reset_Proxy(IEnumWiaItem *This);
  void __RPC_STUB IEnumWiaItem_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWiaItem_Clone_Proxy(IEnumWiaItem *This,IEnumWiaItem **ppIEnum);
  void __RPC_STUB IEnumWiaItem_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWiaItem_GetCount_Proxy(IEnumWiaItem *This,ULONG *celt);
  void __RPC_STUB IEnumWiaItem_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef struct _WIA_DEV_CAP {
    GUID guid;
    ULONG ulFlags;
    BSTR bstrName;
    BSTR bstrDescription;
    BSTR bstrIcon;
    BSTR bstrCommandline;
  } WIA_DEV_CAP;

  typedef struct _WIA_DEV_CAP *PWIA_DEV_CAP;
  typedef struct _WIA_DEV_CAP WIA_EVENT_HANDLER;
  typedef struct _WIA_DEV_CAP *PWIA_EVENT_HANDLER;

  extern RPC_IF_HANDLE __MIDL_itf_wia_0130_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wia_0130_v0_0_s_ifspec;
#ifndef __IEnumWIA_DEV_CAPS_INTERFACE_DEFINED__
#define __IEnumWIA_DEV_CAPS_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumWIA_DEV_CAPS;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumWIA_DEV_CAPS : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,WIA_DEV_CAP *rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumWIA_DEV_CAPS **ppIEnum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *pcelt) = 0;
  };
#else
  typedef struct IEnumWIA_DEV_CAPSVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumWIA_DEV_CAPS *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumWIA_DEV_CAPS *This);
      ULONG (WINAPI *Release)(IEnumWIA_DEV_CAPS *This);
      HRESULT (WINAPI *Next)(IEnumWIA_DEV_CAPS *This,ULONG celt,WIA_DEV_CAP *rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumWIA_DEV_CAPS *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumWIA_DEV_CAPS *This);
      HRESULT (WINAPI *Clone)(IEnumWIA_DEV_CAPS *This,IEnumWIA_DEV_CAPS **ppIEnum);
      HRESULT (WINAPI *GetCount)(IEnumWIA_DEV_CAPS *This,ULONG *pcelt);
    END_INTERFACE
  } IEnumWIA_DEV_CAPSVtbl;
  struct IEnumWIA_DEV_CAPS {
    CONST_VTBL struct IEnumWIA_DEV_CAPSVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumWIA_DEV_CAPS_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumWIA_DEV_CAPS_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumWIA_DEV_CAPS_Release(This) (This)->lpVtbl->Release(This)
#define IEnumWIA_DEV_CAPS_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumWIA_DEV_CAPS_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumWIA_DEV_CAPS_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumWIA_DEV_CAPS_Clone(This,ppIEnum) (This)->lpVtbl->Clone(This,ppIEnum)
#define IEnumWIA_DEV_CAPS_GetCount(This,pcelt) (This)->lpVtbl->GetCount(This,pcelt)
#endif
#endif
  HRESULT WINAPI IEnumWIA_DEV_CAPS_RemoteNext_Proxy(IEnumWIA_DEV_CAPS *This,ULONG celt,WIA_DEV_CAP *rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumWIA_DEV_CAPS_RemoteNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_CAPS_Skip_Proxy(IEnumWIA_DEV_CAPS *This,ULONG celt);
  void __RPC_STUB IEnumWIA_DEV_CAPS_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_CAPS_Reset_Proxy(IEnumWIA_DEV_CAPS *This);
  void __RPC_STUB IEnumWIA_DEV_CAPS_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_CAPS_Clone_Proxy(IEnumWIA_DEV_CAPS *This,IEnumWIA_DEV_CAPS **ppIEnum);
  void __RPC_STUB IEnumWIA_DEV_CAPS_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_DEV_CAPS_GetCount_Proxy(IEnumWIA_DEV_CAPS *This,ULONG *pcelt);
  void __RPC_STUB IEnumWIA_DEV_CAPS_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumWIA_FORMAT_INFO_INTERFACE_DEFINED__
#define __IEnumWIA_FORMAT_INFO_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumWIA_FORMAT_INFO;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumWIA_FORMAT_INFO : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,WIA_FORMAT_INFO *rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumWIA_FORMAT_INFO **ppIEnum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *pcelt) = 0;
  };
#else
  typedef struct IEnumWIA_FORMAT_INFOVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumWIA_FORMAT_INFO *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumWIA_FORMAT_INFO *This);
      ULONG (WINAPI *Release)(IEnumWIA_FORMAT_INFO *This);
      HRESULT (WINAPI *Next)(IEnumWIA_FORMAT_INFO *This,ULONG celt,WIA_FORMAT_INFO *rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumWIA_FORMAT_INFO *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumWIA_FORMAT_INFO *This);
      HRESULT (WINAPI *Clone)(IEnumWIA_FORMAT_INFO *This,IEnumWIA_FORMAT_INFO **ppIEnum);
      HRESULT (WINAPI *GetCount)(IEnumWIA_FORMAT_INFO *This,ULONG *pcelt);
    END_INTERFACE
  } IEnumWIA_FORMAT_INFOVtbl;
  struct IEnumWIA_FORMAT_INFO {
    CONST_VTBL struct IEnumWIA_FORMAT_INFOVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumWIA_FORMAT_INFO_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumWIA_FORMAT_INFO_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumWIA_FORMAT_INFO_Release(This) (This)->lpVtbl->Release(This)
#define IEnumWIA_FORMAT_INFO_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumWIA_FORMAT_INFO_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumWIA_FORMAT_INFO_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumWIA_FORMAT_INFO_Clone(This,ppIEnum) (This)->lpVtbl->Clone(This,ppIEnum)
#define IEnumWIA_FORMAT_INFO_GetCount(This,pcelt) (This)->lpVtbl->GetCount(This,pcelt)
#endif
#endif
  HRESULT WINAPI IEnumWIA_FORMAT_INFO_RemoteNext_Proxy(IEnumWIA_FORMAT_INFO *This,ULONG celt,WIA_FORMAT_INFO *rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumWIA_FORMAT_INFO_RemoteNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_FORMAT_INFO_Skip_Proxy(IEnumWIA_FORMAT_INFO *This,ULONG celt);
  void __RPC_STUB IEnumWIA_FORMAT_INFO_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_FORMAT_INFO_Reset_Proxy(IEnumWIA_FORMAT_INFO *This);
  void __RPC_STUB IEnumWIA_FORMAT_INFO_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_FORMAT_INFO_Clone_Proxy(IEnumWIA_FORMAT_INFO *This,IEnumWIA_FORMAT_INFO **ppIEnum);
  void __RPC_STUB IEnumWIA_FORMAT_INFO_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWIA_FORMAT_INFO_GetCount_Proxy(IEnumWIA_FORMAT_INFO *This,ULONG *pcelt);
  void __RPC_STUB IEnumWIA_FORMAT_INFO_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWiaLog_INTERFACE_DEFINED__
#define __IWiaLog_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaLog;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaLog : public IUnknown {
  public:
    virtual HRESULT WINAPI InitializeLog(LONG hInstance) = 0;
    virtual HRESULT WINAPI hResult(HRESULT hResult) = 0;
    virtual HRESULT WINAPI Log(LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText) = 0;
  };
#else
  typedef struct IWiaLogVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaLog *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaLog *This);
      ULONG (WINAPI *Release)(IWiaLog *This);
      HRESULT (WINAPI *InitializeLog)(IWiaLog *This,LONG hInstance);
      HRESULT (WINAPI *hResult)(IWiaLog *This,HRESULT hResult);
      HRESULT (WINAPI *Log)(IWiaLog *This,LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText);
    END_INTERFACE
  } IWiaLogVtbl;
  struct IWiaLog {
    CONST_VTBL struct IWiaLogVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaLog_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaLog_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaLog_Release(This) (This)->lpVtbl->Release(This)
#define IWiaLog_InitializeLog(This,hInstance) (This)->lpVtbl->InitializeLog(This,hInstance)
#define IWiaLog_hResult(This,hResult) (This)->lpVtbl->hResult(This,hResult)
#define IWiaLog_Log(This,lFlags,lResID,lDetail,bstrText) (This)->lpVtbl->Log(This,lFlags,lResID,lDetail,bstrText)
#endif
#endif
  HRESULT WINAPI IWiaLog_InitializeLog_Proxy(IWiaLog *This,LONG hInstance);
  void __RPC_STUB IWiaLog_InitializeLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaLog_hResult_Proxy(IWiaLog *This,HRESULT hResult);
  void __RPC_STUB IWiaLog_hResult_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaLog_Log_Proxy(IWiaLog *This,LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText);
  void __RPC_STUB IWiaLog_Log_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWiaLogEx_INTERFACE_DEFINED__
#define __IWiaLogEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaLogEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaLogEx : public IUnknown {
  public:
    virtual HRESULT WINAPI InitializeLogEx(BYTE *hInstance) = 0;
    virtual HRESULT WINAPI hResult(HRESULT hResult) = 0;
    virtual HRESULT WINAPI Log(LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText) = 0;
    virtual HRESULT WINAPI hResultEx(LONG lMethodId,HRESULT hResult) = 0;
    virtual HRESULT WINAPI LogEx(LONG lMethodId,LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText) = 0;
  };
#else
  typedef struct IWiaLogExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaLogEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaLogEx *This);
      ULONG (WINAPI *Release)(IWiaLogEx *This);
      HRESULT (WINAPI *InitializeLogEx)(IWiaLogEx *This,BYTE *hInstance);
      HRESULT (WINAPI *hResult)(IWiaLogEx *This,HRESULT hResult);
      HRESULT (WINAPI *Log)(IWiaLogEx *This,LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText);
      HRESULT (WINAPI *hResultEx)(IWiaLogEx *This,LONG lMethodId,HRESULT hResult);
      HRESULT (WINAPI *LogEx)(IWiaLogEx *This,LONG lMethodId,LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText);
    END_INTERFACE
  } IWiaLogExVtbl;
  struct IWiaLogEx {
    CONST_VTBL struct IWiaLogExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaLogEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaLogEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaLogEx_Release(This) (This)->lpVtbl->Release(This)
#define IWiaLogEx_InitializeLogEx(This,hInstance) (This)->lpVtbl->InitializeLogEx(This,hInstance)
#define IWiaLogEx_hResult(This,hResult) (This)->lpVtbl->hResult(This,hResult)
#define IWiaLogEx_Log(This,lFlags,lResID,lDetail,bstrText) (This)->lpVtbl->Log(This,lFlags,lResID,lDetail,bstrText)
#define IWiaLogEx_hResultEx(This,lMethodId,hResult) (This)->lpVtbl->hResultEx(This,lMethodId,hResult)
#define IWiaLogEx_LogEx(This,lMethodId,lFlags,lResID,lDetail,bstrText) (This)->lpVtbl->LogEx(This,lMethodId,lFlags,lResID,lDetail,bstrText)
#endif
#endif
  HRESULT WINAPI IWiaLogEx_InitializeLogEx_Proxy(IWiaLogEx *This,BYTE *hInstance);
  void __RPC_STUB IWiaLogEx_InitializeLogEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaLogEx_hResult_Proxy(IWiaLogEx *This,HRESULT hResult);
  void __RPC_STUB IWiaLogEx_hResult_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaLogEx_Log_Proxy(IWiaLogEx *This,LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText);
  void __RPC_STUB IWiaLogEx_Log_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaLogEx_hResultEx_Proxy(IWiaLogEx *This,LONG lMethodId,HRESULT hResult);
  void __RPC_STUB IWiaLogEx_hResultEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaLogEx_LogEx_Proxy(IWiaLogEx *This,LONG lMethodId,LONG lFlags,LONG lResID,LONG lDetail,BSTR bstrText);
  void __RPC_STUB IWiaLogEx_LogEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWiaNotifyDevMgr_INTERFACE_DEFINED__
#define __IWiaNotifyDevMgr_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaNotifyDevMgr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaNotifyDevMgr : public IUnknown {
  public:
    virtual HRESULT WINAPI NewDeviceArrival(void) = 0;
  };
#else
  typedef struct IWiaNotifyDevMgrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaNotifyDevMgr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaNotifyDevMgr *This);
      ULONG (WINAPI *Release)(IWiaNotifyDevMgr *This);
      HRESULT (WINAPI *NewDeviceArrival)(IWiaNotifyDevMgr *This);
    END_INTERFACE
  } IWiaNotifyDevMgrVtbl;
  struct IWiaNotifyDevMgr {
    CONST_VTBL struct IWiaNotifyDevMgrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaNotifyDevMgr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaNotifyDevMgr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaNotifyDevMgr_Release(This) (This)->lpVtbl->Release(This)
#define IWiaNotifyDevMgr_NewDeviceArrival(This) (This)->lpVtbl->NewDeviceArrival(This)
#endif
#endif
  HRESULT WINAPI IWiaNotifyDevMgr_NewDeviceArrival_Proxy(IWiaNotifyDevMgr *This);
  void __RPC_STUB IWiaNotifyDevMgr_NewDeviceArrival_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWiaItemExtras_INTERFACE_DEFINED__
#define __IWiaItemExtras_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaItemExtras;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaItemExtras : public IUnknown {
  public:
    virtual HRESULT WINAPI GetExtendedErrorInfo(BSTR *bstrErrorText) = 0;
    virtual HRESULT WINAPI Escape(DWORD dwEscapeCode,BYTE *lpInData,DWORD cbInDataSize,BYTE *pOutData,DWORD dwOutDataSize,DWORD *pdwActualDataSize) = 0;
    virtual HRESULT WINAPI CancelPendingIO(void) = 0;
  };
#else
  typedef struct IWiaItemExtrasVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaItemExtras *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaItemExtras *This);
      ULONG (WINAPI *Release)(IWiaItemExtras *This);
      HRESULT (WINAPI *GetExtendedErrorInfo)(IWiaItemExtras *This,BSTR *bstrErrorText);
      HRESULT (WINAPI *Escape)(IWiaItemExtras *This,DWORD dwEscapeCode,BYTE *lpInData,DWORD cbInDataSize,BYTE *pOutData,DWORD dwOutDataSize,DWORD *pdwActualDataSize);
      HRESULT (WINAPI *CancelPendingIO)(IWiaItemExtras *This);
    END_INTERFACE
  } IWiaItemExtrasVtbl;
  struct IWiaItemExtras {
    CONST_VTBL struct IWiaItemExtrasVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaItemExtras_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaItemExtras_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaItemExtras_Release(This) (This)->lpVtbl->Release(This)
#define IWiaItemExtras_GetExtendedErrorInfo(This,bstrErrorText) (This)->lpVtbl->GetExtendedErrorInfo(This,bstrErrorText)
#define IWiaItemExtras_Escape(This,dwEscapeCode,lpInData,cbInDataSize,pOutData,dwOutDataSize,pdwActualDataSize) (This)->lpVtbl->Escape(This,dwEscapeCode,lpInData,cbInDataSize,pOutData,dwOutDataSize,pdwActualDataSize)
#define IWiaItemExtras_CancelPendingIO(This) (This)->lpVtbl->CancelPendingIO(This)
#endif
#endif
  HRESULT WINAPI IWiaItemExtras_GetExtendedErrorInfo_Proxy(IWiaItemExtras *This,BSTR *bstrErrorText);
  void __RPC_STUB IWiaItemExtras_GetExtendedErrorInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItemExtras_Escape_Proxy(IWiaItemExtras *This,DWORD dwEscapeCode,BYTE *lpInData,DWORD cbInDataSize,BYTE *pOutData,DWORD dwOutDataSize,DWORD *pdwActualDataSize);
  void __RPC_STUB IWiaItemExtras_Escape_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaItemExtras_CancelPendingIO_Proxy(IWiaItemExtras *This);
  void __RPC_STUB IWiaItemExtras_CancelPendingIO_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __WiaDevMgr_LIBRARY_DEFINED__
#define __WiaDevMgr_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_WiaDevMgr;
  EXTERN_C const CLSID CLSID_WiaDevMgr;
#ifdef __cplusplus
  class WiaDevMgr;
#endif
  EXTERN_C const CLSID CLSID_WiaLog;
#ifdef __cplusplus
  class WiaLog;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API HWND_UserSize(ULONG *,ULONG,HWND *);
  unsigned char *__RPC_API HWND_UserMarshal(ULONG *,unsigned char *,HWND *);
  unsigned char *__RPC_API HWND_UserUnmarshal(ULONG *,unsigned char *,HWND *);
  void __RPC_API HWND_UserFree(ULONG *,HWND *);
  ULONG __RPC_API LPSAFEARRAY_UserSize(ULONG *,ULONG,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserMarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserUnmarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  void __RPC_API LPSAFEARRAY_UserFree(ULONG *,LPSAFEARRAY *);
  ULONG __RPC_API STGMEDIUM_UserSize(ULONG *,ULONG,STGMEDIUM *);
  unsigned char *__RPC_API STGMEDIUM_UserMarshal(ULONG *,unsigned char *,STGMEDIUM *);
  unsigned char *__RPC_API STGMEDIUM_UserUnmarshal(ULONG *,unsigned char *,STGMEDIUM *);
  void __RPC_API STGMEDIUM_UserFree(ULONG *,STGMEDIUM *);

  HRESULT WINAPI IWiaDevMgr_CreateDevice_Proxy(IWiaDevMgr *This,BSTR bstrDeviceID,IWiaItem **ppWiaItemRoot);
  HRESULT WINAPI IWiaDevMgr_CreateDevice_Stub(IWiaDevMgr *This,BSTR bstrDeviceID,IWiaItem **ppWiaItemRoot);
  HRESULT WINAPI IWiaDevMgr_SelectDeviceDlg_Proxy(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID,IWiaItem **ppItemRoot);
  HRESULT WINAPI IWiaDevMgr_SelectDeviceDlg_Stub(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID,IWiaItem **ppItemRoot);
  HRESULT WINAPI IWiaDevMgr_SelectDeviceDlgID_Proxy(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID);
  HRESULT WINAPI IWiaDevMgr_SelectDeviceDlgID_Stub(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,BSTR *pbstrDeviceID);
  HRESULT WINAPI IWiaDevMgr_GetImageDlg_Proxy(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,LONG lIntent,IWiaItem *pItemRoot,BSTR bstrFilename,GUID *pguidFormat);
  HRESULT WINAPI IWiaDevMgr_GetImageDlg_Stub(IWiaDevMgr *This,HWND hwndParent,LONG lDeviceType,LONG lFlags,LONG lIntent,IWiaItem *pItemRoot,BSTR bstrFilename,GUID *pguidFormat);
  HRESULT WINAPI IWiaDevMgr_RegisterEventCallbackProgram_Proxy(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,BSTR bstrCommandline,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
  HRESULT WINAPI IWiaDevMgr_RegisterEventCallbackProgram_Stub(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,BSTR bstrCommandline,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
  HRESULT WINAPI IWiaDevMgr_RegisterEventCallbackInterface_Proxy(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,IWiaEventCallback *pIWiaEventCallback,IUnknown **pEventObject);
  HRESULT WINAPI IWiaDevMgr_RegisterEventCallbackInterface_Stub(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,IWiaEventCallback *pIWiaEventCallback,IUnknown **pEventObject);
  HRESULT WINAPI IWiaDevMgr_RegisterEventCallbackCLSID_Proxy(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,const GUID *pClsID,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
  HRESULT WINAPI IWiaDevMgr_RegisterEventCallbackCLSID_Stub(IWiaDevMgr *This,LONG lFlags,BSTR bstrDeviceID,const GUID *pEventGUID,const GUID *pClsID,BSTR bstrName,BSTR bstrDescription,BSTR bstrIcon);
  HRESULT WINAPI IEnumWIA_DEV_INFO_Next_Proxy(IEnumWIA_DEV_INFO *This,ULONG celt,IWiaPropertyStorage **rgelt,ULONG *pceltFetched);
  HRESULT WINAPI IEnumWIA_DEV_INFO_Next_Stub(IEnumWIA_DEV_INFO *This,ULONG celt,IWiaPropertyStorage **rgelt,ULONG *pceltFetched);
  HRESULT WINAPI IWiaDataCallback_BandedDataCallback_Proxy(IWiaDataCallback *This,LONG lMessage,LONG lStatus,LONG lPercentComplete,LONG lOffset,LONG lLength,LONG lReserved,LONG lResLength,BYTE *pbBuffer);
  HRESULT WINAPI IWiaDataCallback_BandedDataCallback_Stub(IWiaDataCallback *This,LONG lMessage,LONG lStatus,LONG lPercentComplete,LONG lOffset,LONG lLength,LONG lReserved,LONG lResLength,BYTE *pbBuffer);
  HRESULT WINAPI IWiaDataTransfer_idtGetData_Proxy(IWiaDataTransfer *This,LPSTGMEDIUM pMedium,IWiaDataCallback *pIWiaDataCallback);
  HRESULT WINAPI IWiaDataTransfer_idtGetData_Stub(IWiaDataTransfer *This,LPSTGMEDIUM pMedium,IWiaDataCallback *pIWiaDataCallback);
  HRESULT WINAPI IWiaDataTransfer_idtGetBandedData_Proxy(IWiaDataTransfer *This,PWIA_DATA_TRANSFER_INFO pWiaDataTransInfo,IWiaDataCallback *pIWiaDataCallback);
  HRESULT WINAPI IWiaDataTransfer_idtGetBandedData_Stub(IWiaDataTransfer *This,PWIA_DATA_TRANSFER_INFO pWiaDataTransInfo,IWiaDataCallback *pIWiaDataCallback);
  HRESULT WINAPI IWiaItem_DeviceDlg_Proxy(IWiaItem *This,HWND hwndParent,LONG lFlags,LONG lIntent,LONG *plItemCount,IWiaItem ***ppIWiaItem);
  HRESULT WINAPI IWiaItem_DeviceDlg_Stub(IWiaItem *This,HWND hwndParent,LONG lFlags,LONG lIntent,LONG *plItemCount,IWiaItem ***pIWiaItem);
  HRESULT WINAPI IWiaPropertyStorage_WriteMultiple_Proxy(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC rgpspec[],const PROPVARIANT rgpropvar[],PROPID propidNameFirst);
  HRESULT WINAPI IWiaPropertyStorage_WriteMultiple_Stub(IWiaPropertyStorage *This,ULONG cpspec,const PROPSPEC *rgpspec,const PROPVARIANT *rgpropvar,PROPID propidNameFirst);
  HRESULT WINAPI IWiaPropertyStorage_SetPropertyStream_Proxy(IWiaPropertyStorage *This,GUID *pCompatibilityId,IStream *pIStream);
  HRESULT WINAPI IWiaPropertyStorage_SetPropertyStream_Stub(IWiaPropertyStorage *This,GUID *pCompatibilityId,IStream *pIStream);
  HRESULT WINAPI IEnumWiaItem_Next_Proxy(IEnumWiaItem *This,ULONG celt,IWiaItem **ppIWiaItem,ULONG *pceltFetched);
  HRESULT WINAPI IEnumWiaItem_Next_Stub(IEnumWiaItem *This,ULONG celt,IWiaItem **ppIWiaItem,ULONG *pceltFetched);
  HRESULT WINAPI IEnumWIA_DEV_CAPS_Next_Proxy(IEnumWIA_DEV_CAPS *This,ULONG celt,WIA_DEV_CAP *rgelt,ULONG *pceltFetched);
  HRESULT WINAPI IEnumWIA_DEV_CAPS_Next_Stub(IEnumWIA_DEV_CAPS *This,ULONG celt,WIA_DEV_CAP *rgelt,ULONG *pceltFetched);
  HRESULT WINAPI IEnumWIA_FORMAT_INFO_Next_Proxy(IEnumWIA_FORMAT_INFO *This,ULONG celt,WIA_FORMAT_INFO *rgelt,ULONG *pceltFetched);
  HRESULT WINAPI IEnumWIA_FORMAT_INFO_Next_Stub(IEnumWIA_FORMAT_INFO *This,ULONG celt,WIA_FORMAT_INFO *rgelt,ULONG *pceltFetched);

#ifdef __cplusplus
}
#endif
#endif
