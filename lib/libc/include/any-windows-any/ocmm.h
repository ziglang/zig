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

#ifndef __ocmm_h__
#define __ocmm_h__

#ifndef __ITimerService_FWD_DEFINED__
#define __ITimerService_FWD_DEFINED__
typedef struct ITimerService ITimerService;
#endif

#ifndef __ITimer_FWD_DEFINED__
#define __ITimer_FWD_DEFINED__
typedef struct ITimer ITimer;
#endif

#ifndef __ITimerSink_FWD_DEFINED__
#define __ITimerSink_FWD_DEFINED__
typedef struct ITimerSink ITimerSink;
#endif

#ifndef __IMapMIMEToCLSID_FWD_DEFINED__
#define __IMapMIMEToCLSID_FWD_DEFINED__
typedef struct IMapMIMEToCLSID IMapMIMEToCLSID;
#endif

#ifndef __IImageDecodeFilter_FWD_DEFINED__
#define __IImageDecodeFilter_FWD_DEFINED__
typedef struct IImageDecodeFilter IImageDecodeFilter;
#endif

#ifndef __IImageDecodeEventSink_FWD_DEFINED__
#define __IImageDecodeEventSink_FWD_DEFINED__
typedef struct IImageDecodeEventSink IImageDecodeEventSink;
#endif

#include "oaidl.h"
#include "oleidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define SURFACE_LOCK_EXCLUSIVE 0x01
#define SURFACE_LOCK_ALLOW_DISCARD 0x02
#define SURFACE_LOCK_WAIT 0x04

#define E_SURFACE_NOSURFACE __MSABI_LONG(0x8000C000)
#define E_SURFACE_UNKNOWN_FORMAT __MSABI_LONG(0x8000C001)
#define E_SURFACE_NOTMYPOINTER __MSABI_LONG(0x8000C002)
#define E_SURFACE_DISCARDED __MSABI_LONG(0x8000C003)
#define E_SURFACE_NODC __MSABI_LONG(0x8000C004)
#define E_SURFACE_NOTMYDC __MSABI_LONG(0x8000C005)
#define S_SURFACE_DISCARDED __MSABI_LONG(0x0000C003)

  typedef GUID BFID;

#ifndef RGBQUAD_DEFINED
#define RGBQUAD_DEFINED
  typedef struct tagRGBQUAD RGBQUAD;
#endif
  EXTERN_C const GUID BFID_MONOCHROME;
  EXTERN_C const GUID BFID_RGB_4;
  EXTERN_C const GUID BFID_RGB_8;
  EXTERN_C const GUID BFID_RGB_555;
  EXTERN_C const GUID BFID_RGB_565;
  EXTERN_C const GUID BFID_RGB_24;
  EXTERN_C const GUID BFID_RGB_32;
  EXTERN_C const GUID BFID_RGBA_32;
  EXTERN_C const GUID BFID_GRAY_8;
  EXTERN_C const GUID BFID_GRAY_16;

#define SID_SDirectDraw3 IID_IDirectDraw3

#define COLOR_NO_TRANSPARENT 0xFFFFFFFF

#define IMGDECODE_EVENT_PROGRESS 0x01
#define IMGDECODE_EVENT_PALETTE 0x02
#define IMGDECODE_EVENT_BEGINBITS 0x04
#define IMGDECODE_EVENT_BITSCOMPLETE 0x08
#define IMGDECODE_EVENT_USEDDRAW 0x10

#define IMGDECODE_HINT_TOPDOWN 0x01
#define IMGDECODE_HINT_BOTTOMUP 0x02
#define IMGDECODE_HINT_FULLWIDTH 0x04

#define MAPMIME_DEFAULT 0
#define MAPMIME_CLSID 1
#define MAPMIME_DISABLE 2
#define MAPMIME_DEFAULT_ALWAYS 3

#define BFID_INDEXED_RGB_8 BFID_RGB_8
#define BFID_INDEXED_RGB_4 BFID_RGB_4
#define BFID_INDEXED_RGB_1 BFID_MONOCHROME

  EXTERN_C const GUID CLSID_IImageDecodeFilter;
  EXTERN_C const GUID NAMEDTIMER_DRAW;

  extern RPC_IF_HANDLE __MIDL_itf_ocmm_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ocmm_0000_v0_0_s_ifspec;

#ifndef __ITimerService_INTERFACE_DEFINED__
#define __ITimerService_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITimerService;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITimerService : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateTimer(ITimer *pReferenceTimer,ITimer **ppNewTimer) = 0;
    virtual HRESULT WINAPI GetNamedTimer(REFGUID rguidName,ITimer **ppTimer) = 0;
    virtual HRESULT WINAPI SetNamedTimerReference(REFGUID rguidName,ITimer *pReferenceTimer) = 0;
  };
#else
  typedef struct ITimerServiceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITimerService *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITimerService *This);
      ULONG (WINAPI *Release)(ITimerService *This);
      HRESULT (WINAPI *CreateTimer)(ITimerService *This,ITimer *pReferenceTimer,ITimer **ppNewTimer);
      HRESULT (WINAPI *GetNamedTimer)(ITimerService *This,REFGUID rguidName,ITimer **ppTimer);
      HRESULT (WINAPI *SetNamedTimerReference)(ITimerService *This,REFGUID rguidName,ITimer *pReferenceTimer);
    END_INTERFACE
  } ITimerServiceVtbl;
  struct ITimerService {
    CONST_VTBL struct ITimerServiceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITimerService_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITimerService_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITimerService_Release(This) (This)->lpVtbl->Release(This)
#define ITimerService_CreateTimer(This,pReferenceTimer,ppNewTimer) (This)->lpVtbl->CreateTimer(This,pReferenceTimer,ppNewTimer)
#define ITimerService_GetNamedTimer(This,rguidName,ppTimer) (This)->lpVtbl->GetNamedTimer(This,rguidName,ppTimer)
#define ITimerService_SetNamedTimerReference(This,rguidName,pReferenceTimer) (This)->lpVtbl->SetNamedTimerReference(This,rguidName,pReferenceTimer)
#endif
#endif
  HRESULT WINAPI ITimerService_CreateTimer_Proxy(ITimerService *This,ITimer *pReferenceTimer,ITimer **ppNewTimer);
  void __RPC_STUB ITimerService_CreateTimer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITimerService_GetNamedTimer_Proxy(ITimerService *This,REFGUID rguidName,ITimer **ppTimer);
  void __RPC_STUB ITimerService_GetNamedTimer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITimerService_SetNamedTimerReference_Proxy(ITimerService *This,REFGUID rguidName,ITimer *pReferenceTimer);
  void __RPC_STUB ITimerService_SetNamedTimerReference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITimer_INTERFACE_DEFINED__
#define __ITimer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITimer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITimer : public IUnknown {
  public:
    virtual HRESULT WINAPI Advise(VARIANT vtimeMin,VARIANT vtimeMax,VARIANT vtimeInterval,DWORD dwFlags,ITimerSink *pTimerSink,DWORD *pdwCookie) = 0;
    virtual HRESULT WINAPI Unadvise(DWORD dwCookie) = 0;
    virtual HRESULT WINAPI Freeze(WINBOOL fFreeze) = 0;
    virtual HRESULT WINAPI GetTime(VARIANT *pvtime) = 0;
  };
#else
  typedef struct ITimerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITimer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITimer *This);
      ULONG (WINAPI *Release)(ITimer *This);
      HRESULT (WINAPI *Advise)(ITimer *This,VARIANT vtimeMin,VARIANT vtimeMax,VARIANT vtimeInterval,DWORD dwFlags,ITimerSink *pTimerSink,DWORD *pdwCookie);
      HRESULT (WINAPI *Unadvise)(ITimer *This,DWORD dwCookie);
      HRESULT (WINAPI *Freeze)(ITimer *This,WINBOOL fFreeze);
      HRESULT (WINAPI *GetTime)(ITimer *This,VARIANT *pvtime);
    END_INTERFACE
  } ITimerVtbl;
  struct ITimer {
    CONST_VTBL struct ITimerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITimer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITimer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITimer_Release(This) (This)->lpVtbl->Release(This)
#define ITimer_Advise(This,vtimeMin,vtimeMax,vtimeInterval,dwFlags,pTimerSink,pdwCookie) (This)->lpVtbl->Advise(This,vtimeMin,vtimeMax,vtimeInterval,dwFlags,pTimerSink,pdwCookie)
#define ITimer_Unadvise(This,dwCookie) (This)->lpVtbl->Unadvise(This,dwCookie)
#define ITimer_Freeze(This,fFreeze) (This)->lpVtbl->Freeze(This,fFreeze)
#define ITimer_GetTime(This,pvtime) (This)->lpVtbl->GetTime(This,pvtime)
#endif
#endif
  HRESULT WINAPI ITimer_Advise_Proxy(ITimer *This,VARIANT vtimeMin,VARIANT vtimeMax,VARIANT vtimeInterval,DWORD dwFlags,ITimerSink *pTimerSink,DWORD *pdwCookie);
  void __RPC_STUB ITimer_Advise_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITimer_Unadvise_Proxy(ITimer *This,DWORD dwCookie);
  void __RPC_STUB ITimer_Unadvise_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITimer_Freeze_Proxy(ITimer *This,WINBOOL fFreeze);
  void __RPC_STUB ITimer_Freeze_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITimer_GetTime_Proxy(ITimer *This,VARIANT *pvtime);
  void __RPC_STUB ITimer_GetTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITimerSink_INTERFACE_DEFINED__
#define __ITimerSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITimerSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITimerSink : public IUnknown {
  public:
    virtual HRESULT WINAPI OnTimer(VARIANT vtimeAdvise) = 0;
  };
#else
  typedef struct ITimerSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITimerSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITimerSink *This);
      ULONG (WINAPI *Release)(ITimerSink *This);
      HRESULT (WINAPI *OnTimer)(ITimerSink *This,VARIANT vtimeAdvise);
    END_INTERFACE
  } ITimerSinkVtbl;
  struct ITimerSink {
    CONST_VTBL struct ITimerSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITimerSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITimerSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITimerSink_Release(This) (This)->lpVtbl->Release(This)
#define ITimerSink_OnTimer(This,vtimeAdvise) (This)->lpVtbl->OnTimer(This,vtimeAdvise)
#endif
#endif
  HRESULT WINAPI ITimerSink_OnTimer_Proxy(ITimerSink *This,VARIANT vtimeAdvise);
  void __RPC_STUB ITimerSink_OnTimer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define SID_STimerService IID_ITimerService

  extern RPC_IF_HANDLE __MIDL_itf_ocmm_0142_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ocmm_0142_v0_0_s_ifspec;

#ifndef __IMapMIMEToCLSID_INTERFACE_DEFINED__
#define __IMapMIMEToCLSID_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMapMIMEToCLSID;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMapMIMEToCLSID : public IUnknown {
  public:
    virtual HRESULT WINAPI EnableDefaultMappings(WINBOOL bEnable) = 0;
    virtual HRESULT WINAPI MapMIMEToCLSID(LPCOLESTR pszMIMEType,CLSID *pCLSID) = 0;
    virtual HRESULT WINAPI SetMapping(LPCOLESTR pszMIMEType,DWORD dwMapMode,REFCLSID clsid) = 0;
  };
#else
  typedef struct IMapMIMEToCLSIDVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMapMIMEToCLSID *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMapMIMEToCLSID *This);
      ULONG (WINAPI *Release)(IMapMIMEToCLSID *This);
      HRESULT (WINAPI *EnableDefaultMappings)(IMapMIMEToCLSID *This,WINBOOL bEnable);
      HRESULT (WINAPI *MapMIMEToCLSID)(IMapMIMEToCLSID *This,LPCOLESTR pszMIMEType,CLSID *pCLSID);
      HRESULT (WINAPI *SetMapping)(IMapMIMEToCLSID *This,LPCOLESTR pszMIMEType,DWORD dwMapMode,REFCLSID clsid);
    END_INTERFACE
  } IMapMIMEToCLSIDVtbl;
  struct IMapMIMEToCLSID {
    CONST_VTBL struct IMapMIMEToCLSIDVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMapMIMEToCLSID_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMapMIMEToCLSID_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMapMIMEToCLSID_Release(This) (This)->lpVtbl->Release(This)
#define IMapMIMEToCLSID_EnableDefaultMappings(This,bEnable) (This)->lpVtbl->EnableDefaultMappings(This,bEnable)
#define IMapMIMEToCLSID_MapMIMEToCLSID(This,pszMIMEType,pCLSID) (This)->lpVtbl->MapMIMEToCLSID(This,pszMIMEType,pCLSID)
#define IMapMIMEToCLSID_SetMapping(This,pszMIMEType,dwMapMode,clsid) (This)->lpVtbl->SetMapping(This,pszMIMEType,dwMapMode,clsid)
#endif
#endif
  HRESULT WINAPI IMapMIMEToCLSID_EnableDefaultMappings_Proxy(IMapMIMEToCLSID *This,WINBOOL bEnable);
  void __RPC_STUB IMapMIMEToCLSID_EnableDefaultMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMapMIMEToCLSID_MapMIMEToCLSID_Proxy(IMapMIMEToCLSID *This,LPCOLESTR pszMIMEType,CLSID *pCLSID);
  void __RPC_STUB IMapMIMEToCLSID_MapMIMEToCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMapMIMEToCLSID_SetMapping_Proxy(IMapMIMEToCLSID *This,LPCOLESTR pszMIMEType,DWORD dwMapMode,REFCLSID clsid);
  void __RPC_STUB IMapMIMEToCLSID_SetMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IImageDecodeFilter_INTERFACE_DEFINED__
#define __IImageDecodeFilter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IImageDecodeFilter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IImageDecodeFilter : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(IImageDecodeEventSink *pEventSink) = 0;
    virtual HRESULT WINAPI Process(IStream *pStream) = 0;
    virtual HRESULT WINAPI Terminate(HRESULT hrStatus) = 0;
  };
#else
  typedef struct IImageDecodeFilterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IImageDecodeFilter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IImageDecodeFilter *This);
      ULONG (WINAPI *Release)(IImageDecodeFilter *This);
      HRESULT (WINAPI *Initialize)(IImageDecodeFilter *This,IImageDecodeEventSink *pEventSink);
      HRESULT (WINAPI *Process)(IImageDecodeFilter *This,IStream *pStream);
      HRESULT (WINAPI *Terminate)(IImageDecodeFilter *This,HRESULT hrStatus);
    END_INTERFACE
  } IImageDecodeFilterVtbl;
  struct IImageDecodeFilter {
    CONST_VTBL struct IImageDecodeFilterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IImageDecodeFilter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IImageDecodeFilter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IImageDecodeFilter_Release(This) (This)->lpVtbl->Release(This)
#define IImageDecodeFilter_Initialize(This,pEventSink) (This)->lpVtbl->Initialize(This,pEventSink)
#define IImageDecodeFilter_Process(This,pStream) (This)->lpVtbl->Process(This,pStream)
#define IImageDecodeFilter_Terminate(This,hrStatus) (This)->lpVtbl->Terminate(This,hrStatus)
#endif
#endif
  HRESULT WINAPI IImageDecodeFilter_Initialize_Proxy(IImageDecodeFilter *This,IImageDecodeEventSink *pEventSink);
  void __RPC_STUB IImageDecodeFilter_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IImageDecodeFilter_Process_Proxy(IImageDecodeFilter *This,IStream *pStream);
  void __RPC_STUB IImageDecodeFilter_Process_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IImageDecodeFilter_Terminate_Proxy(IImageDecodeFilter *This,HRESULT hrStatus);
  void __RPC_STUB IImageDecodeFilter_Terminate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IImageDecodeEventSink_INTERFACE_DEFINED__
#define __IImageDecodeEventSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IImageDecodeEventSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IImageDecodeEventSink : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSurface(LONG nWidth,LONG nHeight,REFGUID bfid,ULONG nPasses,DWORD dwHints,IUnknown **ppSurface) = 0;
    virtual HRESULT WINAPI OnBeginDecode(DWORD *pdwEvents,ULONG *pnFormats,BFID **ppFormats) = 0;
    virtual HRESULT WINAPI OnBitsComplete(void) = 0;
    virtual HRESULT WINAPI OnDecodeComplete(HRESULT hrStatus) = 0;
    virtual HRESULT WINAPI OnPalette(void) = 0;
    virtual HRESULT WINAPI OnProgress(RECT *pBounds,WINBOOL bComplete) = 0;
  };
#else
  typedef struct IImageDecodeEventSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IImageDecodeEventSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IImageDecodeEventSink *This);
      ULONG (WINAPI *Release)(IImageDecodeEventSink *This);
      HRESULT (WINAPI *GetSurface)(IImageDecodeEventSink *This,LONG nWidth,LONG nHeight,REFGUID bfid,ULONG nPasses,DWORD dwHints,IUnknown **ppSurface);
      HRESULT (WINAPI *OnBeginDecode)(IImageDecodeEventSink *This,DWORD *pdwEvents,ULONG *pnFormats,BFID **ppFormats);
      HRESULT (WINAPI *OnBitsComplete)(IImageDecodeEventSink *This);
      HRESULT (WINAPI *OnDecodeComplete)(IImageDecodeEventSink *This,HRESULT hrStatus);
      HRESULT (WINAPI *OnPalette)(IImageDecodeEventSink *This);
      HRESULT (WINAPI *OnProgress)(IImageDecodeEventSink *This,RECT *pBounds,WINBOOL bComplete);
    END_INTERFACE
  } IImageDecodeEventSinkVtbl;
  struct IImageDecodeEventSink {
    CONST_VTBL struct IImageDecodeEventSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IImageDecodeEventSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IImageDecodeEventSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IImageDecodeEventSink_Release(This) (This)->lpVtbl->Release(This)
#define IImageDecodeEventSink_GetSurface(This,nWidth,nHeight,bfid,nPasses,dwHints,ppSurface) (This)->lpVtbl->GetSurface(This,nWidth,nHeight,bfid,nPasses,dwHints,ppSurface)
#define IImageDecodeEventSink_OnBeginDecode(This,pdwEvents,pnFormats,ppFormats) (This)->lpVtbl->OnBeginDecode(This,pdwEvents,pnFormats,ppFormats)
#define IImageDecodeEventSink_OnBitsComplete(This) (This)->lpVtbl->OnBitsComplete(This)
#define IImageDecodeEventSink_OnDecodeComplete(This,hrStatus) (This)->lpVtbl->OnDecodeComplete(This,hrStatus)
#define IImageDecodeEventSink_OnPalette(This) (This)->lpVtbl->OnPalette(This)
#define IImageDecodeEventSink_OnProgress(This,pBounds,bComplete) (This)->lpVtbl->OnProgress(This,pBounds,bComplete)
#endif
#endif
  HRESULT WINAPI IImageDecodeEventSink_GetSurface_Proxy(IImageDecodeEventSink *This,LONG nWidth,LONG nHeight,REFGUID bfid,ULONG nPasses,DWORD dwHints,IUnknown **ppSurface);
  void __RPC_STUB IImageDecodeEventSink_GetSurface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IImageDecodeEventSink_OnBeginDecode_Proxy(IImageDecodeEventSink *This,DWORD *pdwEvents,ULONG *pnFormats,BFID **ppFormats);
  void __RPC_STUB IImageDecodeEventSink_OnBeginDecode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IImageDecodeEventSink_OnBitsComplete_Proxy(IImageDecodeEventSink *This);
  void __RPC_STUB IImageDecodeEventSink_OnBitsComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IImageDecodeEventSink_OnDecodeComplete_Proxy(IImageDecodeEventSink *This,HRESULT hrStatus);
  void __RPC_STUB IImageDecodeEventSink_OnDecodeComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IImageDecodeEventSink_OnPalette_Proxy(IImageDecodeEventSink *This);
  void __RPC_STUB IImageDecodeEventSink_OnPalette_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IImageDecodeEventSink_OnProgress_Proxy(IImageDecodeEventSink *This,RECT *pBounds,WINBOOL bComplete);
  void __RPC_STUB IImageDecodeEventSink_OnProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
