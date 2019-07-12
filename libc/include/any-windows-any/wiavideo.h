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

#ifndef __wiavideo_h__
#define __wiavideo_h__

#ifndef __IWiaVideo_FWD_DEFINED__
#define __IWiaVideo_FWD_DEFINED__
typedef struct IWiaVideo IWiaVideo;
#endif

#ifndef __WiaVideo_FWD_DEFINED__
#define __WiaVideo_FWD_DEFINED__
#ifdef __cplusplus
typedef class WiaVideo WiaVideo;
#else
typedef struct WiaVideo WiaVideo;
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

  typedef enum __MIDL___MIDL_itf_wiavideo_0000_0001 {
    WIAVIDEO_NO_VIDEO = 1,WIAVIDEO_CREATING_VIDEO = 2,WIAVIDEO_VIDEO_CREATED = 3,WIAVIDEO_VIDEO_PLAYING = 4,WIAVIDEO_VIDEO_PAUSED = 5,
    WIAVIDEO_DESTROYING_VIDEO = 6
  } WIAVIDEO_STATE;

  extern RPC_IF_HANDLE __MIDL_itf_wiavideo_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wiavideo_0000_v0_0_s_ifspec;
#ifndef __IWiaVideo_INTERFACE_DEFINED__
#define __IWiaVideo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWiaVideo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWiaVideo : public IUnknown {
  public:
    virtual HRESULT WINAPI get_PreviewVisible(WINBOOL *pbPreviewVisible) = 0;
    virtual HRESULT WINAPI put_PreviewVisible(WINBOOL bPreviewVisible) = 0;
    virtual HRESULT WINAPI get_ImagesDirectory(BSTR *pbstrImageDirectory) = 0;
    virtual HRESULT WINAPI put_ImagesDirectory(BSTR bstrImageDirectory) = 0;
    virtual HRESULT WINAPI CreateVideoByWiaDevID(BSTR bstrWiaDeviceID,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback) = 0;
    virtual HRESULT WINAPI CreateVideoByDevNum(UINT uiDeviceNumber,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback) = 0;
    virtual HRESULT WINAPI CreateVideoByName(BSTR bstrFriendlyName,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback) = 0;
    virtual HRESULT WINAPI DestroyVideo(void) = 0;
    virtual HRESULT WINAPI Play(void) = 0;
    virtual HRESULT WINAPI Pause(void) = 0;
    virtual HRESULT WINAPI TakePicture(BSTR *pbstrNewImageFilename) = 0;
    virtual HRESULT WINAPI ResizeVideo(WINBOOL bStretchToFitParent) = 0;
    virtual HRESULT WINAPI GetCurrentState(WIAVIDEO_STATE *pState) = 0;
  };
#else
  typedef struct IWiaVideoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWiaVideo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWiaVideo *This);
      ULONG (WINAPI *Release)(IWiaVideo *This);
      HRESULT (WINAPI *get_PreviewVisible)(IWiaVideo *This,WINBOOL *pbPreviewVisible);
      HRESULT (WINAPI *put_PreviewVisible)(IWiaVideo *This,WINBOOL bPreviewVisible);
      HRESULT (WINAPI *get_ImagesDirectory)(IWiaVideo *This,BSTR *pbstrImageDirectory);
      HRESULT (WINAPI *put_ImagesDirectory)(IWiaVideo *This,BSTR bstrImageDirectory);
      HRESULT (WINAPI *CreateVideoByWiaDevID)(IWiaVideo *This,BSTR bstrWiaDeviceID,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback);
      HRESULT (WINAPI *CreateVideoByDevNum)(IWiaVideo *This,UINT uiDeviceNumber,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback);
      HRESULT (WINAPI *CreateVideoByName)(IWiaVideo *This,BSTR bstrFriendlyName,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback);
      HRESULT (WINAPI *DestroyVideo)(IWiaVideo *This);
      HRESULT (WINAPI *Play)(IWiaVideo *This);
      HRESULT (WINAPI *Pause)(IWiaVideo *This);
      HRESULT (WINAPI *TakePicture)(IWiaVideo *This,BSTR *pbstrNewImageFilename);
      HRESULT (WINAPI *ResizeVideo)(IWiaVideo *This,WINBOOL bStretchToFitParent);
      HRESULT (WINAPI *GetCurrentState)(IWiaVideo *This,WIAVIDEO_STATE *pState);
    END_INTERFACE
  } IWiaVideoVtbl;
  struct IWiaVideo {
    CONST_VTBL struct IWiaVideoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWiaVideo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWiaVideo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWiaVideo_Release(This) (This)->lpVtbl->Release(This)
#define IWiaVideo_get_PreviewVisible(This,pbPreviewVisible) (This)->lpVtbl->get_PreviewVisible(This,pbPreviewVisible)
#define IWiaVideo_put_PreviewVisible(This,bPreviewVisible) (This)->lpVtbl->put_PreviewVisible(This,bPreviewVisible)
#define IWiaVideo_get_ImagesDirectory(This,pbstrImageDirectory) (This)->lpVtbl->get_ImagesDirectory(This,pbstrImageDirectory)
#define IWiaVideo_put_ImagesDirectory(This,bstrImageDirectory) (This)->lpVtbl->put_ImagesDirectory(This,bstrImageDirectory)
#define IWiaVideo_CreateVideoByWiaDevID(This,bstrWiaDeviceID,hwndParent,bStretchToFitParent,bAutoBeginPlayback) (This)->lpVtbl->CreateVideoByWiaDevID(This,bstrWiaDeviceID,hwndParent,bStretchToFitParent,bAutoBeginPlayback)
#define IWiaVideo_CreateVideoByDevNum(This,uiDeviceNumber,hwndParent,bStretchToFitParent,bAutoBeginPlayback) (This)->lpVtbl->CreateVideoByDevNum(This,uiDeviceNumber,hwndParent,bStretchToFitParent,bAutoBeginPlayback)
#define IWiaVideo_CreateVideoByName(This,bstrFriendlyName,hwndParent,bStretchToFitParent,bAutoBeginPlayback) (This)->lpVtbl->CreateVideoByName(This,bstrFriendlyName,hwndParent,bStretchToFitParent,bAutoBeginPlayback)
#define IWiaVideo_DestroyVideo(This) (This)->lpVtbl->DestroyVideo(This)
#define IWiaVideo_Play(This) (This)->lpVtbl->Play(This)
#define IWiaVideo_Pause(This) (This)->lpVtbl->Pause(This)
#define IWiaVideo_TakePicture(This,pbstrNewImageFilename) (This)->lpVtbl->TakePicture(This,pbstrNewImageFilename)
#define IWiaVideo_ResizeVideo(This,bStretchToFitParent) (This)->lpVtbl->ResizeVideo(This,bStretchToFitParent)
#define IWiaVideo_GetCurrentState(This,pState) (This)->lpVtbl->GetCurrentState(This,pState)
#endif
#endif
  HRESULT WINAPI IWiaVideo_get_PreviewVisible_Proxy(IWiaVideo *This,WINBOOL *pbPreviewVisible);
  void __RPC_STUB IWiaVideo_get_PreviewVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_put_PreviewVisible_Proxy(IWiaVideo *This,WINBOOL bPreviewVisible);
  void __RPC_STUB IWiaVideo_put_PreviewVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_get_ImagesDirectory_Proxy(IWiaVideo *This,BSTR *pbstrImageDirectory);
  void __RPC_STUB IWiaVideo_get_ImagesDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_put_ImagesDirectory_Proxy(IWiaVideo *This,BSTR bstrImageDirectory);
  void __RPC_STUB IWiaVideo_put_ImagesDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_CreateVideoByWiaDevID_Proxy(IWiaVideo *This,BSTR bstrWiaDeviceID,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback);
  void __RPC_STUB IWiaVideo_CreateVideoByWiaDevID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_CreateVideoByDevNum_Proxy(IWiaVideo *This,UINT uiDeviceNumber,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback);
  void __RPC_STUB IWiaVideo_CreateVideoByDevNum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_CreateVideoByName_Proxy(IWiaVideo *This,BSTR bstrFriendlyName,HWND hwndParent,WINBOOL bStretchToFitParent,WINBOOL bAutoBeginPlayback);
  void __RPC_STUB IWiaVideo_CreateVideoByName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_DestroyVideo_Proxy(IWiaVideo *This);
  void __RPC_STUB IWiaVideo_DestroyVideo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_Play_Proxy(IWiaVideo *This);
  void __RPC_STUB IWiaVideo_Play_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_Pause_Proxy(IWiaVideo *This);
  void __RPC_STUB IWiaVideo_Pause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_TakePicture_Proxy(IWiaVideo *This,BSTR *pbstrNewImageFilename);
  void __RPC_STUB IWiaVideo_TakePicture_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_ResizeVideo_Proxy(IWiaVideo *This,WINBOOL bStretchToFitParent);
  void __RPC_STUB IWiaVideo_ResizeVideo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWiaVideo_GetCurrentState_Proxy(IWiaVideo *This,WIAVIDEO_STATE *pState);
  void __RPC_STUB IWiaVideo_GetCurrentState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __WIAVIDEOLib_LIBRARY_DEFINED__
#define __WIAVIDEOLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_WIAVIDEOLib;
  EXTERN_C const CLSID CLSID_WiaVideo;
#ifdef __cplusplus
  class WiaVideo;
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

#ifdef __cplusplus
}
#endif
#endif
