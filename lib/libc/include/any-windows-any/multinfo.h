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

#ifndef __multinfo_h__
#define __multinfo_h__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __IProvideClassInfo_FWD_DEFINED__
#define __IProvideClassInfo_FWD_DEFINED__
  typedef struct IProvideClassInfo IProvideClassInfo;
#endif

#ifndef __IProvideClassInfo2_FWD_DEFINED__
#define __IProvideClassInfo2_FWD_DEFINED__
  typedef struct IProvideClassInfo2 IProvideClassInfo2;
#endif

#ifndef __IProvideMultipleClassInfo_FWD_DEFINED__
#define __IProvideMultipleClassInfo_FWD_DEFINED__
  typedef struct IProvideMultipleClassInfo IProvideMultipleClassInfo;
#endif

#include "oaidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _OLECTL_H_
#include <olectl.h>
#endif

  DEFINE_GUID(IID_IProvideMultipleClassInfo,0xa7aba9c1,0x8983,0x11cf,0x8f,0x20,0x0,0x80,0x5f,0x2c,0xd0,0x64);

  extern RPC_IF_HANDLE __MIDL__intf_0053_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL__intf_0053_v0_0_s_ifspec;

#ifndef __IProvideMultipleClassInfo_INTERFACE_DEFINED__
#define __IProvideMultipleClassInfo_INTERFACE_DEFINED__

#define MULTICLASSINFO_GETTYPEINFO 0x00000001
#define MULTICLASSINFO_GETNUMRESERVEDDISPIDS 0x00000002
#define MULTICLASSINFO_GETIIDPRIMARY 0x00000004
#define MULTICLASSINFO_GETIIDSOURCE 0x00000008
#define TIFLAGS_EXTENDDISPATCHONLY 0x00000001

  EXTERN_C const IID IID_IProvideMultipleClassInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProvideMultipleClassInfo : public IProvideClassInfo2 {
public:
  virtual HRESULT WINAPI GetMultiTypeInfoCount(ULONG *pcti) = 0;
  virtual HRESULT WINAPI GetInfoOfIndex(ULONG iti,DWORD dwFlags,ITypeInfo **pptiCoClass,DWORD *pdwTIFlags,ULONG *pcdispidReserved,IID *piidPrimary,IID *piidSource) = 0;
  };
#else
  typedef struct IProvideMultipleClassInfoVtbl {
    HRESULT (WINAPI *QueryInterface)(IProvideMultipleClassInfo *This,REFIID riid,void **ppvObject);
    ULONG (WINAPI *AddRef)(IProvideMultipleClassInfo *This);
    ULONG (WINAPI *Release)(IProvideMultipleClassInfo *This);
    HRESULT (WINAPI *GetClassInfo)(IProvideMultipleClassInfo *This,LPTYPEINFO *ppTI);
    HRESULT (WINAPI *GetGUID)(IProvideMultipleClassInfo *This,DWORD dwGuidKind,GUID *pGUID);
    HRESULT (WINAPI *GetMultiTypeInfoCount)(IProvideMultipleClassInfo *This,ULONG *pcti);
    HRESULT (WINAPI *GetInfoOfIndex)(IProvideMultipleClassInfo *This,ULONG iti,DWORD dwFlags,ITypeInfo **pptiCoClass,DWORD *pdwTIFlags,ULONG *pcdispidReserved,IID *piidPrimary,IID *piidSource);
  } IProvideMultipleClassInfoVtbl;
  struct IProvideMultipleClassInfo {
    CONST_VTBL struct IProvideMultipleClassInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProvideMultipleClassInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProvideMultipleClassInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProvideMultipleClassInfo_Release(This) (This)->lpVtbl->Release(This)
#define IProvideMultipleClassInfo_GetClassInfo(This,ppTI) (This)->lpVtbl->GetClassInfo(This,ppTI)
#define IProvideMultipleClassInfo_GetGUID(This,dwGuidKind,pGUID) (This)->lpVtbl->GetGUID(This,dwGuidKind,pGUID)
#define IProvideMultipleClassInfo_GetMultiTypeInfoCount(This,pcti) (This)->lpVtbl->GetMultiTypeInfoCount(This,pcti)
#define IProvideMultipleClassInfo_GetInfoOfIndex(This,iti,dwFlags,pptiCoClass,pdwTIFlags,pcdispidReserved,piidPrimary,piidSource) (This)->lpVtbl->GetInfoOfIndex(This,iti,dwFlags,pptiCoClass,pdwTIFlags,pcdispidReserved,piidPrimary,piidSource)
#endif
#endif
  HRESULT WINAPI IProvideMultipleClassInfo_GetMultiTypeInfoCount_Proxy(IProvideMultipleClassInfo *This,ULONG *pcti);
  void __RPC_STUB IProvideMultipleClassInfo_GetMultiTypeInfoCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IProvideMultipleClassInfo_GetInfoOfIndex_Proxy(IProvideMultipleClassInfo *This,ULONG iti,DWORD dwFlags,ITypeInfo **pptiCoClass,DWORD *pdwTIFlags,ULONG *pcdispidReserved,IID *piidPrimary,IID *piidSource);
  void __RPC_STUB IProvideMultipleClassInfo_GetInfoOfIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
