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

#ifndef __bidispl_h__
#define __bidispl_h__

#ifndef __IBidiRequest_FWD_DEFINED__
#define __IBidiRequest_FWD_DEFINED__
typedef struct IBidiRequest IBidiRequest;
#endif

#ifndef __IBidiRequestContainer_FWD_DEFINED__
#define __IBidiRequestContainer_FWD_DEFINED__
typedef struct IBidiRequestContainer IBidiRequestContainer;
#endif

#ifndef __IBidiSpl_FWD_DEFINED__
#define __IBidiSpl_FWD_DEFINED__
typedef struct IBidiSpl IBidiSpl;
#endif

#ifndef __BidiRequest_FWD_DEFINED__
#define __BidiRequest_FWD_DEFINED__
#ifdef __cplusplus
typedef class BidiRequest BidiRequest;
#else
typedef struct BidiRequest BidiRequest;
#endif
#endif

#ifndef __BidiRequestContainer_FWD_DEFINED__
#define __BidiRequestContainer_FWD_DEFINED__
#ifdef __cplusplus
typedef class BidiRequestContainer BidiRequestContainer;
#else
typedef struct BidiRequestContainer BidiRequestContainer;
#endif
#endif

#ifndef __BidiSpl_FWD_DEFINED__
#define __BidiSpl_FWD_DEFINED__
#ifdef __cplusplus
typedef class BidiSpl BidiSpl;
#else
typedef struct BidiSpl BidiSpl;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __IBidiRequest_INTERFACE_DEFINED__
#define __IBidiRequest_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBidiRequest;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBidiRequest : public IUnknown {
  public:
    virtual HRESULT WINAPI SetSchema(const LPCWSTR pszSchema) = 0;
    virtual HRESULT WINAPI SetInputData(const DWORD dwType,const BYTE *pData,const UINT uSize) = 0;
    virtual HRESULT WINAPI GetResult(HRESULT *phr) = 0;
    virtual HRESULT WINAPI GetOutputData(const DWORD dwIndex,LPWSTR *ppszSchema,DWORD *pdwType,BYTE **ppData,ULONG *uSize) = 0;
    virtual HRESULT WINAPI GetEnumCount(DWORD *pdwTotal) = 0;
  };
#else
  typedef struct IBidiRequestVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBidiRequest *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBidiRequest *This);
      ULONG (WINAPI *Release)(IBidiRequest *This);
      HRESULT (WINAPI *SetSchema)(IBidiRequest *This,const LPCWSTR pszSchema);
      HRESULT (WINAPI *SetInputData)(IBidiRequest *This,const DWORD dwType,const BYTE *pData,const UINT uSize);
      HRESULT (WINAPI *GetResult)(IBidiRequest *This,HRESULT *phr);
      HRESULT (WINAPI *GetOutputData)(IBidiRequest *This,const DWORD dwIndex,LPWSTR *ppszSchema,DWORD *pdwType,BYTE **ppData,ULONG *uSize);
      HRESULT (WINAPI *GetEnumCount)(IBidiRequest *This,DWORD *pdwTotal);
    END_INTERFACE
  } IBidiRequestVtbl;
  struct IBidiRequest {
    CONST_VTBL struct IBidiRequestVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBidiRequest_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBidiRequest_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBidiRequest_Release(This) (This)->lpVtbl->Release(This)
#define IBidiRequest_SetSchema(This,pszSchema) (This)->lpVtbl->SetSchema(This,pszSchema)
#define IBidiRequest_SetInputData(This,dwType,pData,uSize) (This)->lpVtbl->SetInputData(This,dwType,pData,uSize)
#define IBidiRequest_GetResult(This,phr) (This)->lpVtbl->GetResult(This,phr)
#define IBidiRequest_GetOutputData(This,dwIndex,ppszSchema,pdwType,ppData,uSize) (This)->lpVtbl->GetOutputData(This,dwIndex,ppszSchema,pdwType,ppData,uSize)
#define IBidiRequest_GetEnumCount(This,pdwTotal) (This)->lpVtbl->GetEnumCount(This,pdwTotal)
#endif
#endif
  HRESULT WINAPI IBidiRequest_SetSchema_Proxy(IBidiRequest *This,const LPCWSTR pszSchema);
  void __RPC_STUB IBidiRequest_SetSchema_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiRequest_SetInputData_Proxy(IBidiRequest *This,const DWORD dwType,const BYTE *pData,const UINT uSize);
  void __RPC_STUB IBidiRequest_SetInputData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiRequest_GetResult_Proxy(IBidiRequest *This,HRESULT *phr);
  void __RPC_STUB IBidiRequest_GetResult_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiRequest_GetOutputData_Proxy(IBidiRequest *This,const DWORD dwIndex,LPWSTR *ppszSchema,DWORD *pdwType,BYTE **ppData,ULONG *uSize);
  void __RPC_STUB IBidiRequest_GetOutputData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiRequest_GetEnumCount_Proxy(IBidiRequest *This,DWORD *pdwTotal);
  void __RPC_STUB IBidiRequest_GetEnumCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBidiRequestContainer_INTERFACE_DEFINED__
#define __IBidiRequestContainer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBidiRequestContainer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBidiRequestContainer : public IUnknown {
  public:
    virtual HRESULT WINAPI AddRequest(IBidiRequest *pRequest) = 0;
    virtual HRESULT WINAPI GetEnumObject(IEnumUnknown **ppenum) = 0;
    virtual HRESULT WINAPI GetRequestCount(ULONG *puCount) = 0;
  };
#else
  typedef struct IBidiRequestContainerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBidiRequestContainer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBidiRequestContainer *This);
      ULONG (WINAPI *Release)(IBidiRequestContainer *This);
      HRESULT (WINAPI *AddRequest)(IBidiRequestContainer *This,IBidiRequest *pRequest);
      HRESULT (WINAPI *GetEnumObject)(IBidiRequestContainer *This,IEnumUnknown **ppenum);
      HRESULT (WINAPI *GetRequestCount)(IBidiRequestContainer *This,ULONG *puCount);
    END_INTERFACE
  } IBidiRequestContainerVtbl;
  struct IBidiRequestContainer {
    CONST_VTBL struct IBidiRequestContainerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBidiRequestContainer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBidiRequestContainer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBidiRequestContainer_Release(This) (This)->lpVtbl->Release(This)
#define IBidiRequestContainer_AddRequest(This,pRequest) (This)->lpVtbl->AddRequest(This,pRequest)
#define IBidiRequestContainer_GetEnumObject(This,ppenum) (This)->lpVtbl->GetEnumObject(This,ppenum)
#define IBidiRequestContainer_GetRequestCount(This,puCount) (This)->lpVtbl->GetRequestCount(This,puCount)
#endif
#endif
  HRESULT WINAPI IBidiRequestContainer_AddRequest_Proxy(IBidiRequestContainer *This,IBidiRequest *pRequest);
  void __RPC_STUB IBidiRequestContainer_AddRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiRequestContainer_GetEnumObject_Proxy(IBidiRequestContainer *This,IEnumUnknown **ppenum);
  void __RPC_STUB IBidiRequestContainer_GetEnumObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiRequestContainer_GetRequestCount_Proxy(IBidiRequestContainer *This,ULONG *puCount);
  void __RPC_STUB IBidiRequestContainer_GetRequestCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBidiSpl_INTERFACE_DEFINED__
#define __IBidiSpl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBidiSpl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBidiSpl : public IUnknown {
  public:
    virtual HRESULT WINAPI BindDevice(const LPCWSTR pszDeviceName,const DWORD dwAccess) = 0;
    virtual HRESULT WINAPI UnbindDevice(void) = 0;
    virtual HRESULT WINAPI SendRecv(const LPCWSTR pszAction,IBidiRequest *pRequest) = 0;
    virtual HRESULT WINAPI MultiSendRecv(const LPCWSTR pszAction,IBidiRequestContainer *pRequestContainer) = 0;
  };
#else
  typedef struct IBidiSplVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBidiSpl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBidiSpl *This);
      ULONG (WINAPI *Release)(IBidiSpl *This);
      HRESULT (WINAPI *BindDevice)(IBidiSpl *This,const LPCWSTR pszDeviceName,const DWORD dwAccess);
      HRESULT (WINAPI *UnbindDevice)(IBidiSpl *This);
      HRESULT (WINAPI *SendRecv)(IBidiSpl *This,const LPCWSTR pszAction,IBidiRequest *pRequest);
      HRESULT (WINAPI *MultiSendRecv)(IBidiSpl *This,const LPCWSTR pszAction,IBidiRequestContainer *pRequestContainer);
    END_INTERFACE
  } IBidiSplVtbl;
  struct IBidiSpl {
    CONST_VTBL struct IBidiSplVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBidiSpl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBidiSpl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBidiSpl_Release(This) (This)->lpVtbl->Release(This)
#define IBidiSpl_BindDevice(This,pszDeviceName,dwAccess) (This)->lpVtbl->BindDevice(This,pszDeviceName,dwAccess)
#define IBidiSpl_UnbindDevice(This) (This)->lpVtbl->UnbindDevice(This)
#define IBidiSpl_SendRecv(This,pszAction,pRequest) (This)->lpVtbl->SendRecv(This,pszAction,pRequest)
#define IBidiSpl_MultiSendRecv(This,pszAction,pRequestContainer) (This)->lpVtbl->MultiSendRecv(This,pszAction,pRequestContainer)
#endif
#endif
  HRESULT WINAPI IBidiSpl_BindDevice_Proxy(IBidiSpl *This,const LPCWSTR pszDeviceName,const DWORD dwAccess);
  void __RPC_STUB IBidiSpl_BindDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiSpl_UnbindDevice_Proxy(IBidiSpl *This);
  void __RPC_STUB IBidiSpl_UnbindDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiSpl_SendRecv_Proxy(IBidiSpl *This,const LPCWSTR pszAction,IBidiRequest *pRequest);
  void __RPC_STUB IBidiSpl_SendRecv_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBidiSpl_MultiSendRecv_Proxy(IBidiSpl *This,const LPCWSTR pszAction,IBidiRequestContainer *pRequestContainer);
  void __RPC_STUB IBidiSpl_MultiSendRecv_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBidiSplLib_LIBRARY_DEFINED__
#define __IBidiSplLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_IBidiSplLib;
  EXTERN_C const CLSID CLSID_BidiRequest;
#ifdef __cplusplus
  class BidiRequest;
#endif
  EXTERN_C const CLSID CLSID_BidiRequestContainer;
#ifdef __cplusplus
  class BidiRequestContainer;
#endif
  EXTERN_C const CLSID CLSID_BidiSpl;
#ifdef __cplusplus
  class BidiSpl;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
