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

#ifndef __tapi3ds_h__
#define __tapi3ds_h__

#ifndef __ITAMMediaFormat_FWD_DEFINED__
#define __ITAMMediaFormat_FWD_DEFINED__
typedef struct ITAMMediaFormat ITAMMediaFormat;
#endif

#ifndef __ITAllocatorProperties_FWD_DEFINED__
#define __ITAllocatorProperties_FWD_DEFINED__
typedef struct ITAllocatorProperties ITAllocatorProperties;
#endif

#include "oaidl.h"
#include "strmif.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_tapi3ds_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3ds_0000_v0_0_s_ifspec;
#ifndef __ITAMMediaFormat_INTERFACE_DEFINED__
#define __ITAMMediaFormat_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAMMediaFormat;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAMMediaFormat : public IUnknown {
  public:
    virtual HRESULT WINAPI get_MediaFormat(AM_MEDIA_TYPE **ppmt) = 0;
    virtual HRESULT WINAPI put_MediaFormat(const AM_MEDIA_TYPE *pmt) = 0;
  };
#else
  typedef struct ITAMMediaFormatVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAMMediaFormat *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAMMediaFormat *This);
      ULONG (WINAPI *Release)(ITAMMediaFormat *This);
      HRESULT (WINAPI *get_MediaFormat)(ITAMMediaFormat *This,AM_MEDIA_TYPE **ppmt);
      HRESULT (WINAPI *put_MediaFormat)(ITAMMediaFormat *This,const AM_MEDIA_TYPE *pmt);
    END_INTERFACE
  } ITAMMediaFormatVtbl;
  struct ITAMMediaFormat {
    CONST_VTBL struct ITAMMediaFormatVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAMMediaFormat_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAMMediaFormat_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAMMediaFormat_Release(This) (This)->lpVtbl->Release(This)
#define ITAMMediaFormat_get_MediaFormat(This,ppmt) (This)->lpVtbl->get_MediaFormat(This,ppmt)
#define ITAMMediaFormat_put_MediaFormat(This,pmt) (This)->lpVtbl->put_MediaFormat(This,pmt)
#endif
#endif
  HRESULT WINAPI ITAMMediaFormat_get_MediaFormat_Proxy(ITAMMediaFormat *This,AM_MEDIA_TYPE **ppmt);
  void __RPC_STUB ITAMMediaFormat_get_MediaFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAMMediaFormat_put_MediaFormat_Proxy(ITAMMediaFormat *This,const AM_MEDIA_TYPE *pmt);
  void __RPC_STUB ITAMMediaFormat_put_MediaFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAllocatorProperties_INTERFACE_DEFINED__
#define __ITAllocatorProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAllocatorProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAllocatorProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI SetAllocatorProperties(ALLOCATOR_PROPERTIES *pAllocProperties) = 0;
    virtual HRESULT WINAPI GetAllocatorProperties(ALLOCATOR_PROPERTIES *pAllocProperties) = 0;
    virtual HRESULT WINAPI SetAllocateBuffers(WINBOOL bAllocBuffers) = 0;
    virtual HRESULT WINAPI GetAllocateBuffers(WINBOOL *pbAllocBuffers) = 0;
    virtual HRESULT WINAPI SetBufferSize(DWORD BufferSize) = 0;
    virtual HRESULT WINAPI GetBufferSize(DWORD *pBufferSize) = 0;
  };
#else
  typedef struct ITAllocatorPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAllocatorProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAllocatorProperties *This);
      ULONG (WINAPI *Release)(ITAllocatorProperties *This);
      HRESULT (WINAPI *SetAllocatorProperties)(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
      HRESULT (WINAPI *GetAllocatorProperties)(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
      HRESULT (WINAPI *SetAllocateBuffers)(ITAllocatorProperties *This,WINBOOL bAllocBuffers);
      HRESULT (WINAPI *GetAllocateBuffers)(ITAllocatorProperties *This,WINBOOL *pbAllocBuffers);
      HRESULT (WINAPI *SetBufferSize)(ITAllocatorProperties *This,DWORD BufferSize);
      HRESULT (WINAPI *GetBufferSize)(ITAllocatorProperties *This,DWORD *pBufferSize);
    END_INTERFACE
  } ITAllocatorPropertiesVtbl;
  struct ITAllocatorProperties {
    CONST_VTBL struct ITAllocatorPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAllocatorProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAllocatorProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAllocatorProperties_Release(This) (This)->lpVtbl->Release(This)
#define ITAllocatorProperties_SetAllocatorProperties(This,pAllocProperties) (This)->lpVtbl->SetAllocatorProperties(This,pAllocProperties)
#define ITAllocatorProperties_GetAllocatorProperties(This,pAllocProperties) (This)->lpVtbl->GetAllocatorProperties(This,pAllocProperties)
#define ITAllocatorProperties_SetAllocateBuffers(This,bAllocBuffers) (This)->lpVtbl->SetAllocateBuffers(This,bAllocBuffers)
#define ITAllocatorProperties_GetAllocateBuffers(This,pbAllocBuffers) (This)->lpVtbl->GetAllocateBuffers(This,pbAllocBuffers)
#define ITAllocatorProperties_SetBufferSize(This,BufferSize) (This)->lpVtbl->SetBufferSize(This,BufferSize)
#define ITAllocatorProperties_GetBufferSize(This,pBufferSize) (This)->lpVtbl->GetBufferSize(This,pBufferSize)
#endif
#endif
  HRESULT WINAPI ITAllocatorProperties_SetAllocatorProperties_Proxy(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
  void __RPC_STUB ITAllocatorProperties_SetAllocatorProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_GetAllocatorProperties_Proxy(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
  void __RPC_STUB ITAllocatorProperties_GetAllocatorProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_SetAllocateBuffers_Proxy(ITAllocatorProperties *This,WINBOOL bAllocBuffers);
  void __RPC_STUB ITAllocatorProperties_SetAllocateBuffers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_GetAllocateBuffers_Proxy(ITAllocatorProperties *This,WINBOOL *pbAllocBuffers);
  void __RPC_STUB ITAllocatorProperties_GetAllocateBuffers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_SetBufferSize_Proxy(ITAllocatorProperties *This,DWORD BufferSize);
  void __RPC_STUB ITAllocatorProperties_SetBufferSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_GetBufferSize_Proxy(ITAllocatorProperties *This,DWORD *pBufferSize);
  void __RPC_STUB ITAllocatorProperties_GetBufferSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
