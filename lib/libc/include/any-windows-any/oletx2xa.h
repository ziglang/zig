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

#ifndef __oletx2xa_h__
#define __oletx2xa_h__

#ifndef __IDtcToXaMapper_FWD_DEFINED__
#define __IDtcToXaMapper_FWD_DEFINED__
typedef struct IDtcToXaMapper IDtcToXaMapper;
#endif

#ifndef __IDtcToXaHelperFactory_FWD_DEFINED__
#define __IDtcToXaHelperFactory_FWD_DEFINED__
typedef struct IDtcToXaHelperFactory IDtcToXaHelperFactory;
#endif

#ifndef __IDtcToXaHelper_FWD_DEFINED__
#define __IDtcToXaHelper_FWD_DEFINED__
typedef struct IDtcToXaHelper IDtcToXaHelper;
#endif

#ifndef __IDtcToXaHelperSinglePipe_FWD_DEFINED__
#define __IDtcToXaHelperSinglePipe_FWD_DEFINED__
typedef struct IDtcToXaHelperSinglePipe IDtcToXaHelperSinglePipe;
#endif

#include "unknwn.h"
#include "transact.h"
#include "txcoord.h"
#include "xa.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oletx2xa_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oletx2xa_0000_v0_0_s_ifspec;

#ifndef __XaMapperTypes_INTERFACE_DEFINED__
#define __XaMapperTypes_INTERFACE_DEFINED__

  typedef DWORD XA_SWITCH_FLAGS;

#define XA_SWITCH_F_DTC 0x00000001
#define XA_FMTID_DTC 0x00445443
#define XA_FMTID_DTC_VER1 0x01445443

  const XID XID_NULL = {-1,0,0,'\0'};

  extern RPC_IF_HANDLE XaMapperTypes_v0_0_c_ifspec;
  extern RPC_IF_HANDLE XaMapperTypes_v0_0_s_ifspec;
#endif

#ifndef __XaMapperAPIs_INTERFACE_DEFINED__
#define __XaMapperAPIs_INTERFACE_DEFINED__
  HRESULT __cdecl GetXaSwitch(XA_SWITCH_FLAGS XaSwitchFlags,xa_switch_t **ppXaSwitch);

  extern RPC_IF_HANDLE XaMapperAPIs_v0_0_c_ifspec;
  extern RPC_IF_HANDLE XaMapperAPIs_v0_0_s_ifspec;
#endif

#ifndef __IDtcToXaMapper_INTERFACE_DEFINED__
#define __IDtcToXaMapper_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcToXaMapper;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcToXaMapper : public IUnknown {
  public:
    virtual HRESULT WINAPI RequestNewResourceManager(char *pszDSN,char *pszClientDllName,DWORD *pdwRMCookie) = 0;
    virtual HRESULT WINAPI TranslateTridToXid(DWORD *pdwITransaction,DWORD dwRMCookie,XID *pXid) = 0;
    virtual HRESULT WINAPI EnlistResourceManager(DWORD dwRMCookie,DWORD *pdwITransaction) = 0;
    virtual HRESULT WINAPI ReleaseResourceManager(DWORD dwRMCookie) = 0;
  };
#else
  typedef struct IDtcToXaMapperVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcToXaMapper *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcToXaMapper *This);
      ULONG (WINAPI *Release)(IDtcToXaMapper *This);
      HRESULT (WINAPI *RequestNewResourceManager)(IDtcToXaMapper *This,char *pszDSN,char *pszClientDllName,DWORD *pdwRMCookie);
      HRESULT (WINAPI *TranslateTridToXid)(IDtcToXaMapper *This,DWORD *pdwITransaction,DWORD dwRMCookie,XID *pXid);
      HRESULT (WINAPI *EnlistResourceManager)(IDtcToXaMapper *This,DWORD dwRMCookie,DWORD *pdwITransaction);
      HRESULT (WINAPI *ReleaseResourceManager)(IDtcToXaMapper *This,DWORD dwRMCookie);
    END_INTERFACE
  } IDtcToXaMapperVtbl;
  struct IDtcToXaMapper {
    CONST_VTBL struct IDtcToXaMapperVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcToXaMapper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcToXaMapper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcToXaMapper_Release(This) (This)->lpVtbl->Release(This)
#define IDtcToXaMapper_RequestNewResourceManager(This,pszDSN,pszClientDllName,pdwRMCookie) (This)->lpVtbl->RequestNewResourceManager(This,pszDSN,pszClientDllName,pdwRMCookie)
#define IDtcToXaMapper_TranslateTridToXid(This,pdwITransaction,dwRMCookie,pXid) (This)->lpVtbl->TranslateTridToXid(This,pdwITransaction,dwRMCookie,pXid)
#define IDtcToXaMapper_EnlistResourceManager(This,dwRMCookie,pdwITransaction) (This)->lpVtbl->EnlistResourceManager(This,dwRMCookie,pdwITransaction)
#define IDtcToXaMapper_ReleaseResourceManager(This,dwRMCookie) (This)->lpVtbl->ReleaseResourceManager(This,dwRMCookie)
#endif
#endif
  HRESULT WINAPI IDtcToXaMapper_RequestNewResourceManager_Proxy(IDtcToXaMapper *This,char *pszDSN,char *pszClientDllName,DWORD *pdwRMCookie);
  void __RPC_STUB IDtcToXaMapper_RequestNewResourceManager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcToXaMapper_TranslateTridToXid_Proxy(IDtcToXaMapper *This,DWORD *pdwITransaction,DWORD dwRMCookie,XID *pXid);
  void __RPC_STUB IDtcToXaMapper_TranslateTridToXid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcToXaMapper_EnlistResourceManager_Proxy(IDtcToXaMapper *This,DWORD dwRMCookie,DWORD *pdwITransaction);
  void __RPC_STUB IDtcToXaMapper_EnlistResourceManager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcToXaMapper_ReleaseResourceManager_Proxy(IDtcToXaMapper *This,DWORD dwRMCookie);
  void __RPC_STUB IDtcToXaMapper_ReleaseResourceManager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcToXaHelperFactory_INTERFACE_DEFINED__
#define __IDtcToXaHelperFactory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcToXaHelperFactory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcToXaHelperFactory : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(char *pszDSN,char *pszClientDllName,GUID *pguidRm,IDtcToXaHelper **ppXaHelper) = 0;
  };
#else
  typedef struct IDtcToXaHelperFactoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcToXaHelperFactory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcToXaHelperFactory *This);
      ULONG (WINAPI *Release)(IDtcToXaHelperFactory *This);
      HRESULT (WINAPI *Create)(IDtcToXaHelperFactory *This,char *pszDSN,char *pszClientDllName,GUID *pguidRm,IDtcToXaHelper **ppXaHelper);
    END_INTERFACE
  } IDtcToXaHelperFactoryVtbl;
  struct IDtcToXaHelperFactory {
    CONST_VTBL struct IDtcToXaHelperFactoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcToXaHelperFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcToXaHelperFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcToXaHelperFactory_Release(This) (This)->lpVtbl->Release(This)
#define IDtcToXaHelperFactory_Create(This,pszDSN,pszClientDllName,pguidRm,ppXaHelper) (This)->lpVtbl->Create(This,pszDSN,pszClientDllName,pguidRm,ppXaHelper)
#endif
#endif
  HRESULT WINAPI IDtcToXaHelperFactory_Create_Proxy(IDtcToXaHelperFactory *This,char *pszDSN,char *pszClientDllName,GUID *pguidRm,IDtcToXaHelper **ppXaHelper);
  void __RPC_STUB IDtcToXaHelperFactory_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcToXaHelper_INTERFACE_DEFINED__
#define __IDtcToXaHelper_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcToXaHelper;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcToXaHelper : public IUnknown {
  public:
    virtual HRESULT WINAPI Close(WINBOOL i_fDoRecovery) = 0;
    virtual HRESULT WINAPI TranslateTridToXid(ITransaction *pITransaction,GUID *pguidBqual,XID *pXid) = 0;
  };
#else
  typedef struct IDtcToXaHelperVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcToXaHelper *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcToXaHelper *This);
      ULONG (WINAPI *Release)(IDtcToXaHelper *This);
      HRESULT (WINAPI *Close)(IDtcToXaHelper *This,WINBOOL i_fDoRecovery);
      HRESULT (WINAPI *TranslateTridToXid)(IDtcToXaHelper *This,ITransaction *pITransaction,GUID *pguidBqual,XID *pXid);
    END_INTERFACE
  } IDtcToXaHelperVtbl;
  struct IDtcToXaHelper {
    CONST_VTBL struct IDtcToXaHelperVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcToXaHelper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcToXaHelper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcToXaHelper_Release(This) (This)->lpVtbl->Release(This)
#define IDtcToXaHelper_Close(This,i_fDoRecovery) (This)->lpVtbl->Close(This,i_fDoRecovery)
#define IDtcToXaHelper_TranslateTridToXid(This,pITransaction,pguidBqual,pXid) (This)->lpVtbl->TranslateTridToXid(This,pITransaction,pguidBqual,pXid)
#endif
#endif
  HRESULT WINAPI IDtcToXaHelper_Close_Proxy(IDtcToXaHelper *This,WINBOOL i_fDoRecovery);
  void __RPC_STUB IDtcToXaHelper_Close_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcToXaHelper_TranslateTridToXid_Proxy(IDtcToXaHelper *This,ITransaction *pITransaction,GUID *pguidBqual,XID *pXid);
  void __RPC_STUB IDtcToXaHelper_TranslateTridToXid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDtcToXaHelperSinglePipe_INTERFACE_DEFINED__
#define __IDtcToXaHelperSinglePipe_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDtcToXaHelperSinglePipe;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDtcToXaHelperSinglePipe : public IUnknown {
  public:
    virtual HRESULT WINAPI XARMCreate(char *pszDSN,char *pszClientDll,DWORD *pdwRMCookie) = 0;
    virtual HRESULT WINAPI ConvertTridToXID(DWORD *pdwITrans,DWORD dwRMCookie,XID *pxid) = 0;
    virtual HRESULT WINAPI EnlistWithRM(DWORD dwRMCookie,ITransaction *i_pITransaction,ITransactionResourceAsync *i_pITransRes,ITransactionEnlistmentAsync **o_ppITransEnslitment) = 0;
    virtual void WINAPI ReleaseRMCookie(DWORD i_dwRMCookie,WINBOOL i_fNormal) = 0;
  };
#else
  typedef struct IDtcToXaHelperSinglePipeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDtcToXaHelperSinglePipe *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDtcToXaHelperSinglePipe *This);
      ULONG (WINAPI *Release)(IDtcToXaHelperSinglePipe *This);
      HRESULT (WINAPI *XARMCreate)(IDtcToXaHelperSinglePipe *This,char *pszDSN,char *pszClientDll,DWORD *pdwRMCookie);
      HRESULT (WINAPI *ConvertTridToXID)(IDtcToXaHelperSinglePipe *This,DWORD *pdwITrans,DWORD dwRMCookie,XID *pxid);
      HRESULT (WINAPI *EnlistWithRM)(IDtcToXaHelperSinglePipe *This,DWORD dwRMCookie,ITransaction *i_pITransaction,ITransactionResourceAsync *i_pITransRes,ITransactionEnlistmentAsync **o_ppITransEnslitment);
      void (WINAPI *ReleaseRMCookie)(IDtcToXaHelperSinglePipe *This,DWORD i_dwRMCookie,WINBOOL i_fNormal);
    END_INTERFACE
  } IDtcToXaHelperSinglePipeVtbl;
  struct IDtcToXaHelperSinglePipe {
    CONST_VTBL struct IDtcToXaHelperSinglePipeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDtcToXaHelperSinglePipe_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDtcToXaHelperSinglePipe_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDtcToXaHelperSinglePipe_Release(This) (This)->lpVtbl->Release(This)
#define IDtcToXaHelperSinglePipe_XARMCreate(This,pszDSN,pszClientDll,pdwRMCookie) (This)->lpVtbl->XARMCreate(This,pszDSN,pszClientDll,pdwRMCookie)
#define IDtcToXaHelperSinglePipe_ConvertTridToXID(This,pdwITrans,dwRMCookie,pxid) (This)->lpVtbl->ConvertTridToXID(This,pdwITrans,dwRMCookie,pxid)
#define IDtcToXaHelperSinglePipe_EnlistWithRM(This,dwRMCookie,i_pITransaction,i_pITransRes,o_ppITransEnslitment) (This)->lpVtbl->EnlistWithRM(This,dwRMCookie,i_pITransaction,i_pITransRes,o_ppITransEnslitment)
#define IDtcToXaHelperSinglePipe_ReleaseRMCookie(This,i_dwRMCookie,i_fNormal) (This)->lpVtbl->ReleaseRMCookie(This,i_dwRMCookie,i_fNormal)
#endif
#endif
  HRESULT WINAPI IDtcToXaHelperSinglePipe_XARMCreate_Proxy(IDtcToXaHelperSinglePipe *This,char *pszDSN,char *pszClientDll,DWORD *pdwRMCookie);
  void __RPC_STUB IDtcToXaHelperSinglePipe_XARMCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcToXaHelperSinglePipe_ConvertTridToXID_Proxy(IDtcToXaHelperSinglePipe *This,DWORD *pdwITrans,DWORD dwRMCookie,XID *pxid);
  void __RPC_STUB IDtcToXaHelperSinglePipe_ConvertTridToXID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDtcToXaHelperSinglePipe_EnlistWithRM_Proxy(IDtcToXaHelperSinglePipe *This,DWORD dwRMCookie,ITransaction *i_pITransaction,ITransactionResourceAsync *i_pITransRes,ITransactionEnlistmentAsync **o_ppITransEnslitment);
  void __RPC_STUB IDtcToXaHelperSinglePipe_EnlistWithRM_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IDtcToXaHelperSinglePipe_ReleaseRMCookie_Proxy(IDtcToXaHelperSinglePipe *This,DWORD i_dwRMCookie,WINBOOL i_fNormal);
  void __RPC_STUB IDtcToXaHelperSinglePipe_ReleaseRMCookie_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(IID_IDtcToXaMapper,0x64FFABE0,0x7CE9,0x11d0,0x8C,0xE6,0x00,0xC0,0x4F,0xDC,0x87,0x7E);
  DEFINE_GUID(IID_IDtcToXaHelperFactory,0xadefc46a,0xcb1d,0x11d0,0xb1,0x35,0x00,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_IDtcToXaHelper,0xadefc46b,0xcb1d,0x11d0,0xb1,0x35,0x00,0xc0,0x4f,0xc2,0xf3,0xef);
  DEFINE_GUID(IID_IDtcToXaHelperSinglePipe,0x47ED4971,0x53B3,0x11d1,0xBB,0xB9,0x00,0xC0,0x4F,0xD6,0x58,0xF6);

  extern RPC_IF_HANDLE __MIDL_itf_oletx2xa_0126_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oletx2xa_0126_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
