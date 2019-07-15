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

#ifndef __mimeinfo_h__
#define __mimeinfo_h__

#ifndef __IMimeInfo_FWD_DEFINED__
#define __IMimeInfo_FWD_DEFINED__
typedef struct IMimeInfo IMimeInfo;
#endif

#include "objidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_mimeinfo_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mimeinfo_0000_v0_0_s_ifspec;

#ifndef __IMimeInfo_INTERFACE_DEFINED__
#define __IMimeInfo_INTERFACE_DEFINED__

  typedef IMimeInfo *LPMIMEINFO;

  EXTERN_C const IID IID_IMimeInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMimeInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetMimeCLSIDMapping(UINT *pcTypes,LPCSTR **ppszTypes,CLSID **ppclsID) = 0;
  };
#else
  typedef struct IMimeInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMimeInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMimeInfo *This);
      ULONG (WINAPI *Release)(IMimeInfo *This);
      HRESULT (WINAPI *GetMimeCLSIDMapping)(IMimeInfo *This,UINT *pcTypes,LPCSTR **ppszTypes,CLSID **ppclsID);
    END_INTERFACE
  } IMimeInfoVtbl;
  struct IMimeInfo {
    CONST_VTBL struct IMimeInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMimeInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMimeInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMimeInfo_Release(This) (This)->lpVtbl->Release(This)
#define IMimeInfo_GetMimeCLSIDMapping(This,pcTypes,ppszTypes,ppclsID) (This)->lpVtbl->GetMimeCLSIDMapping(This,pcTypes,ppszTypes,ppclsID)
#endif
#endif
  HRESULT WINAPI IMimeInfo_GetMimeCLSIDMapping_Proxy(IMimeInfo *This,UINT *pcTypes,LPCSTR **ppszTypes,CLSID **ppclsID);
  void __RPC_STUB IMimeInfo_GetMimeCLSIDMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define SID_IMimeInfo IID_IMimeInfo

  extern RPC_IF_HANDLE __MIDL_itf_mimeinfo_0093_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mimeinfo_0093_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
