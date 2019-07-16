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

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __emptyvc_h__
#define __emptyvc_h__

#ifndef __IEmptyVolumeCacheCallBack_FWD_DEFINED__
#define __IEmptyVolumeCacheCallBack_FWD_DEFINED__
typedef struct IEmptyVolumeCacheCallBack IEmptyVolumeCacheCallBack;
#endif

#ifndef __IEmptyVolumeCache_FWD_DEFINED__
#define __IEmptyVolumeCache_FWD_DEFINED__
typedef struct IEmptyVolumeCache IEmptyVolumeCache;
#endif

#ifndef __IEmptyVolumeCache2_FWD_DEFINED__
#define __IEmptyVolumeCache2_FWD_DEFINED__
typedef struct IEmptyVolumeCache2 IEmptyVolumeCache2;
#endif

#include "objidl.h"
#include "oleidl.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define EVCF_HASSETTINGS 0x0001
#define EVCF_ENABLEBYDEFAULT 0x0002
#define EVCF_REMOVEFROMLIST 0x0004
#define EVCF_ENABLEBYDEFAULT_AUTO 0x0008
#define EVCF_DONTSHOWIFZERO 0x0010
#define EVCF_SETTINGSMODE 0x0020
#define EVCF_OUTOFDISKSPACE 0x0040

#define EVCCBF_LASTNOTIFICATION 0x0001

#ifndef _LPEMPTYVOLUMECACHECALLBACK_DEFINED
#define _LPEMPTYVOLUMECACHECALLBACK_DEFINED

  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0000_v0_0_s_ifspec;

#ifndef __IEmptyVolumeCacheCallBack_INTERFACE_DEFINED__
#define __IEmptyVolumeCacheCallBack_INTERFACE_DEFINED__
  typedef IEmptyVolumeCacheCallBack *LPEMPTYVOLUMECACHECALLBACK;
  EXTERN_C const IID IID_IEmptyVolumeCacheCallBack;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEmptyVolumeCacheCallBack : public IUnknown {
  public:
    virtual HRESULT WINAPI ScanProgress(DWORDLONG dwlSpaceUsed,DWORD dwFlags,LPCWSTR pcwszStatus) = 0;
    virtual HRESULT WINAPI PurgeProgress(DWORDLONG dwlSpaceFreed,DWORDLONG dwlSpaceToFree,DWORD dwFlags,LPCWSTR pcwszStatus) = 0;
  };
#else
  typedef struct IEmptyVolumeCacheCallBackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEmptyVolumeCacheCallBack *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEmptyVolumeCacheCallBack *This);
      ULONG (WINAPI *Release)(IEmptyVolumeCacheCallBack *This);
      HRESULT (WINAPI *ScanProgress)(IEmptyVolumeCacheCallBack *This,DWORDLONG dwlSpaceUsed,DWORD dwFlags,LPCWSTR pcwszStatus);
      HRESULT (WINAPI *PurgeProgress)(IEmptyVolumeCacheCallBack *This,DWORDLONG dwlSpaceFreed,DWORDLONG dwlSpaceToFree,DWORD dwFlags,LPCWSTR pcwszStatus);
    END_INTERFACE
  } IEmptyVolumeCacheCallBackVtbl;
  struct IEmptyVolumeCacheCallBack {
    CONST_VTBL struct IEmptyVolumeCacheCallBackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEmptyVolumeCacheCallBack_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEmptyVolumeCacheCallBack_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEmptyVolumeCacheCallBack_Release(This) (This)->lpVtbl->Release(This)
#define IEmptyVolumeCacheCallBack_ScanProgress(This,dwlSpaceUsed,dwFlags,pcwszStatus) (This)->lpVtbl->ScanProgress(This,dwlSpaceUsed,dwFlags,pcwszStatus)
#define IEmptyVolumeCacheCallBack_PurgeProgress(This,dwlSpaceFreed,dwlSpaceToFree,dwFlags,pcwszStatus) (This)->lpVtbl->PurgeProgress(This,dwlSpaceFreed,dwlSpaceToFree,dwFlags,pcwszStatus)
#endif
#endif
  HRESULT WINAPI IEmptyVolumeCacheCallBack_ScanProgress_Proxy(IEmptyVolumeCacheCallBack *This,DWORDLONG dwlSpaceUsed,DWORD dwFlags,LPCWSTR pcwszStatus);
  void __RPC_STUB IEmptyVolumeCacheCallBack_ScanProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEmptyVolumeCacheCallBack_PurgeProgress_Proxy(IEmptyVolumeCacheCallBack *This,DWORDLONG dwlSpaceFreed,DWORDLONG dwlSpaceToFree,DWORD dwFlags,LPCWSTR pcwszStatus);
  void __RPC_STUB IEmptyVolumeCacheCallBack_PurgeProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPEMPTYVOLUMECACHE_DEFINED
#define _LPEMPTYVOLUMECACHE_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0141_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0141_v0_0_s_ifspec;
#ifndef __IEmptyVolumeCache_INTERFACE_DEFINED__
#define __IEmptyVolumeCache_INTERFACE_DEFINED__
  typedef IEmptyVolumeCache *LPEMPTYVOLUMECACHE;
  EXTERN_C const IID IID_IEmptyVolumeCache;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEmptyVolumeCache : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(HKEY hkRegKey,LPCWSTR pcwszVolume,LPWSTR *ppwszDisplayName,LPWSTR *ppwszDescription,DWORD *pdwFlags) = 0;
    virtual HRESULT WINAPI GetSpaceUsed(DWORDLONG *pdwlSpaceUsed,IEmptyVolumeCacheCallBack *picb) = 0;
    virtual HRESULT WINAPI Purge(DWORDLONG dwlSpaceToFree,IEmptyVolumeCacheCallBack *picb) = 0;
    virtual HRESULT WINAPI ShowProperties(HWND hwnd) = 0;
    virtual HRESULT WINAPI Deactivate(DWORD *pdwFlags) = 0;
  };
#else
  typedef struct IEmptyVolumeCacheVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEmptyVolumeCache *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEmptyVolumeCache *This);
      ULONG (WINAPI *Release)(IEmptyVolumeCache *This);
      HRESULT (WINAPI *Initialize)(IEmptyVolumeCache *This,HKEY hkRegKey,LPCWSTR pcwszVolume,LPWSTR *ppwszDisplayName,LPWSTR *ppwszDescription,DWORD *pdwFlags);
      HRESULT (WINAPI *GetSpaceUsed)(IEmptyVolumeCache *This,DWORDLONG *pdwlSpaceUsed,IEmptyVolumeCacheCallBack *picb);
      HRESULT (WINAPI *Purge)(IEmptyVolumeCache *This,DWORDLONG dwlSpaceToFree,IEmptyVolumeCacheCallBack *picb);
      HRESULT (WINAPI *ShowProperties)(IEmptyVolumeCache *This,HWND hwnd);
      HRESULT (WINAPI *Deactivate)(IEmptyVolumeCache *This,DWORD *pdwFlags);
    END_INTERFACE
  } IEmptyVolumeCacheVtbl;
  struct IEmptyVolumeCache {
    CONST_VTBL struct IEmptyVolumeCacheVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEmptyVolumeCache_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEmptyVolumeCache_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEmptyVolumeCache_Release(This) (This)->lpVtbl->Release(This)
#define IEmptyVolumeCache_Initialize(This,hkRegKey,pcwszVolume,ppwszDisplayName,ppwszDescription,pdwFlags) (This)->lpVtbl->Initialize(This,hkRegKey,pcwszVolume,ppwszDisplayName,ppwszDescription,pdwFlags)
#define IEmptyVolumeCache_GetSpaceUsed(This,pdwlSpaceUsed,picb) (This)->lpVtbl->GetSpaceUsed(This,pdwlSpaceUsed,picb)
#define IEmptyVolumeCache_Purge(This,dwlSpaceToFree,picb) (This)->lpVtbl->Purge(This,dwlSpaceToFree,picb)
#define IEmptyVolumeCache_ShowProperties(This,hwnd) (This)->lpVtbl->ShowProperties(This,hwnd)
#define IEmptyVolumeCache_Deactivate(This,pdwFlags) (This)->lpVtbl->Deactivate(This,pdwFlags)
#endif
#endif
  HRESULT WINAPI IEmptyVolumeCache_Initialize_Proxy(IEmptyVolumeCache *This,HKEY hkRegKey,LPCWSTR pcwszVolume,LPWSTR *ppwszDisplayName,LPWSTR *ppwszDescription,DWORD *pdwFlags);
  void __RPC_STUB IEmptyVolumeCache_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEmptyVolumeCache_GetSpaceUsed_Proxy(IEmptyVolumeCache *This,DWORDLONG *pdwlSpaceUsed,IEmptyVolumeCacheCallBack *picb);
  void __RPC_STUB IEmptyVolumeCache_GetSpaceUsed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEmptyVolumeCache_Purge_Proxy(IEmptyVolumeCache *This,DWORDLONG dwlSpaceToFree,IEmptyVolumeCacheCallBack *picb);
  void __RPC_STUB IEmptyVolumeCache_Purge_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEmptyVolumeCache_ShowProperties_Proxy(IEmptyVolumeCache *This,HWND hwnd);
  void __RPC_STUB IEmptyVolumeCache_ShowProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEmptyVolumeCache_Deactivate_Proxy(IEmptyVolumeCache *This,DWORD *pdwFlags);
  void __RPC_STUB IEmptyVolumeCache_Deactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPEMPTYVOLUMECACHE2_DEFINED
#define _LPEMPTYVOLUMECACHE2_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0142_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0142_v0_0_s_ifspec;
#ifndef __IEmptyVolumeCache2_INTERFACE_DEFINED__
#define __IEmptyVolumeCache2_INTERFACE_DEFINED__
  typedef IEmptyVolumeCache2 *LPEMPTYVOLUMECACHE2;
  EXTERN_C const IID IID_IEmptyVolumeCache2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEmptyVolumeCache2 : public IEmptyVolumeCache {
  public:
    virtual HRESULT WINAPI InitializeEx(HKEY hkRegKey,LPCWSTR pcwszVolume,LPCWSTR pcwszKeyName,LPWSTR *ppwszDisplayName,LPWSTR *ppwszDescription,LPWSTR *ppwszBtnText,DWORD *pdwFlags) = 0;
  };
#else
  typedef struct IEmptyVolumeCache2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEmptyVolumeCache2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEmptyVolumeCache2 *This);
      ULONG (WINAPI *Release)(IEmptyVolumeCache2 *This);
      HRESULT (WINAPI *Initialize)(IEmptyVolumeCache2 *This,HKEY hkRegKey,LPCWSTR pcwszVolume,LPWSTR *ppwszDisplayName,LPWSTR *ppwszDescription,DWORD *pdwFlags);
      HRESULT (WINAPI *GetSpaceUsed)(IEmptyVolumeCache2 *This,DWORDLONG *pdwlSpaceUsed,IEmptyVolumeCacheCallBack *picb);
      HRESULT (WINAPI *Purge)(IEmptyVolumeCache2 *This,DWORDLONG dwlSpaceToFree,IEmptyVolumeCacheCallBack *picb);
      HRESULT (WINAPI *ShowProperties)(IEmptyVolumeCache2 *This,HWND hwnd);
      HRESULT (WINAPI *Deactivate)(IEmptyVolumeCache2 *This,DWORD *pdwFlags);
      HRESULT (WINAPI *InitializeEx)(IEmptyVolumeCache2 *This,HKEY hkRegKey,LPCWSTR pcwszVolume,LPCWSTR pcwszKeyName,LPWSTR *ppwszDisplayName,LPWSTR *ppwszDescription,LPWSTR *ppwszBtnText,DWORD *pdwFlags);
    END_INTERFACE
  } IEmptyVolumeCache2Vtbl;
  struct IEmptyVolumeCache2 {
    CONST_VTBL struct IEmptyVolumeCache2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEmptyVolumeCache2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEmptyVolumeCache2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEmptyVolumeCache2_Release(This) (This)->lpVtbl->Release(This)
#define IEmptyVolumeCache2_Initialize(This,hkRegKey,pcwszVolume,ppwszDisplayName,ppwszDescription,pdwFlags) (This)->lpVtbl->Initialize(This,hkRegKey,pcwszVolume,ppwszDisplayName,ppwszDescription,pdwFlags)
#define IEmptyVolumeCache2_GetSpaceUsed(This,pdwlSpaceUsed,picb) (This)->lpVtbl->GetSpaceUsed(This,pdwlSpaceUsed,picb)
#define IEmptyVolumeCache2_Purge(This,dwlSpaceToFree,picb) (This)->lpVtbl->Purge(This,dwlSpaceToFree,picb)
#define IEmptyVolumeCache2_ShowProperties(This,hwnd) (This)->lpVtbl->ShowProperties(This,hwnd)
#define IEmptyVolumeCache2_Deactivate(This,pdwFlags) (This)->lpVtbl->Deactivate(This,pdwFlags)
#define IEmptyVolumeCache2_InitializeEx(This,hkRegKey,pcwszVolume,pcwszKeyName,ppwszDisplayName,ppwszDescription,ppwszBtnText,pdwFlags) (This)->lpVtbl->InitializeEx(This,hkRegKey,pcwszVolume,pcwszKeyName,ppwszDisplayName,ppwszDescription,ppwszBtnText,pdwFlags)
#endif
#endif
  HRESULT WINAPI IEmptyVolumeCache2_InitializeEx_Proxy(IEmptyVolumeCache2 *This,HKEY hkRegKey,LPCWSTR pcwszVolume,LPCWSTR pcwszKeyName,LPWSTR *ppwszDisplayName,LPWSTR *ppwszDescription,LPWSTR *ppwszBtnText,DWORD *pdwFlags);
  void __RPC_STUB IEmptyVolumeCache2_InitializeEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0143_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_emptyvc_0143_v0_0_s_ifspec;

  ULONG __RPC_API HWND_UserSize(ULONG *,ULONG,HWND *);
  unsigned char *__RPC_API HWND_UserMarshal(ULONG *,unsigned char *,HWND *);
  unsigned char *__RPC_API HWND_UserUnmarshal(ULONG *,unsigned char *,HWND *);
  void __RPC_API HWND_UserFree(ULONG *,HWND *);

#ifdef __cplusplus
}
#endif
#endif
