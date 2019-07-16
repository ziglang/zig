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

#ifndef __rrascfg_h__
#define __rrascfg_h__

#ifndef __IRouterProtocolConfig_FWD_DEFINED__
#define __IRouterProtocolConfig_FWD_DEFINED__
typedef struct IRouterProtocolConfig IRouterProtocolConfig;
#endif

#ifndef __IAuthenticationProviderConfig_FWD_DEFINED__
#define __IAuthenticationProviderConfig_FWD_DEFINED__
typedef struct IAuthenticationProviderConfig IAuthenticationProviderConfig;
#endif

#ifndef __IAccountingProviderConfig_FWD_DEFINED__
#define __IAccountingProviderConfig_FWD_DEFINED__
typedef struct IAccountingProviderConfig IAccountingProviderConfig;
#endif

#ifndef __IEAPProviderConfig_FWD_DEFINED__
#define __IEAPProviderConfig_FWD_DEFINED__
typedef struct IEAPProviderConfig IEAPProviderConfig;
#endif

#include "basetsd.h"
#include "wtypes.h"
#include "unknwn.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef BYTE *PBYTE;

  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0000_v0_0_s_ifspec;

#ifndef __IRouterProtocolConfig_INTERFACE_DEFINED__
#define __IRouterProtocolConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRouterProtocolConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRouterProtocolConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI AddProtocol(LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved1) = 0;
    virtual HRESULT WINAPI RemoveProtocol(LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved1) = 0;
  };
#else
  typedef struct IRouterProtocolConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRouterProtocolConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRouterProtocolConfig *This);
      ULONG (WINAPI *Release)(IRouterProtocolConfig *This);
      HRESULT (WINAPI *AddProtocol)(IRouterProtocolConfig *This,LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved1);
      HRESULT (WINAPI *RemoveProtocol)(IRouterProtocolConfig *This,LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved1);
    END_INTERFACE
  } IRouterProtocolConfigVtbl;
  struct IRouterProtocolConfig {
    CONST_VTBL struct IRouterProtocolConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRouterProtocolConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRouterProtocolConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRouterProtocolConfig_Release(This) (This)->lpVtbl->Release(This)
#define IRouterProtocolConfig_AddProtocol(This,pszMachineName,dwTransportId,dwProtocolId,hWnd,dwFlags,pRouter,uReserved1) (This)->lpVtbl->AddProtocol(This,pszMachineName,dwTransportId,dwProtocolId,hWnd,dwFlags,pRouter,uReserved1)
#define IRouterProtocolConfig_RemoveProtocol(This,pszMachineName,dwTransportId,dwProtocolId,hWnd,dwFlags,pRouter,uReserved1) (This)->lpVtbl->RemoveProtocol(This,pszMachineName,dwTransportId,dwProtocolId,hWnd,dwFlags,pRouter,uReserved1)
#endif
#endif
  HRESULT WINAPI IRouterProtocolConfig_AddProtocol_Proxy(IRouterProtocolConfig *This,LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved1);
  void __RPC_STUB IRouterProtocolConfig_AddProtocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRouterProtocolConfig_RemoveProtocol_Proxy(IRouterProtocolConfig *This,LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved1);
  void __RPC_STUB IRouterProtocolConfig_RemoveProtocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define DeclareIRouterProtocolConfigMembers(IPURE) STDMETHOD(AddProtocol)(THIS_ LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved1) IPURE; STDMETHOD(RemoveProtocol)(THIS_ LPCOLESTR pszMachineName,DWORD dwTransportId,DWORD dwProtocolId,HWND hWnd,DWORD dwFlags,IUnknown *pRouter,ULONG_PTR uReserved2) IPURE;

  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0011_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0011_v0_0_s_ifspec;

#ifndef __IAuthenticationProviderConfig_INTERFACE_DEFINED__
#define __IAuthenticationProviderConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAuthenticationProviderConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAuthenticationProviderConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam) = 0;
    virtual HRESULT WINAPI Uninitialize(ULONG_PTR uConnectionParam) = 0;
    virtual HRESULT WINAPI Configure(ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2) = 0;
    virtual HRESULT WINAPI Activate(ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) = 0;
    virtual HRESULT WINAPI Deactivate(ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) = 0;
  };
#else
  typedef struct IAuthenticationProviderConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAuthenticationProviderConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAuthenticationProviderConfig *This);
      ULONG (WINAPI *Release)(IAuthenticationProviderConfig *This);
      HRESULT (WINAPI *Initialize)(IAuthenticationProviderConfig *This,LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam);
      HRESULT (WINAPI *Uninitialize)(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam);
      HRESULT (WINAPI *Configure)(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
      HRESULT (WINAPI *Activate)(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
      HRESULT (WINAPI *Deactivate)(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
    END_INTERFACE
  } IAuthenticationProviderConfigVtbl;
  struct IAuthenticationProviderConfig {
    CONST_VTBL struct IAuthenticationProviderConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAuthenticationProviderConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAuthenticationProviderConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAuthenticationProviderConfig_Release(This) (This)->lpVtbl->Release(This)
#define IAuthenticationProviderConfig_Initialize(This,pszMachineName,puConnectionParam) (This)->lpVtbl->Initialize(This,pszMachineName,puConnectionParam)
#define IAuthenticationProviderConfig_Uninitialize(This,uConnectionParam) (This)->lpVtbl->Uninitialize(This,uConnectionParam)
#define IAuthenticationProviderConfig_Configure(This,uConnectionParam,hWnd,dwFlags,uReserved1,uReserved2) (This)->lpVtbl->Configure(This,uConnectionParam,hWnd,dwFlags,uReserved1,uReserved2)
#define IAuthenticationProviderConfig_Activate(This,uConnectionParam,uReserved1,uReserved2) (This)->lpVtbl->Activate(This,uConnectionParam,uReserved1,uReserved2)
#define IAuthenticationProviderConfig_Deactivate(This,uConnectionParam,uReserved1,uReserved2) (This)->lpVtbl->Deactivate(This,uConnectionParam,uReserved1,uReserved2)
#endif
#endif
  HRESULT WINAPI IAuthenticationProviderConfig_Initialize_Proxy(IAuthenticationProviderConfig *This,LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam);
  void __RPC_STUB IAuthenticationProviderConfig_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuthenticationProviderConfig_Uninitialize_Proxy(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam);
  void __RPC_STUB IAuthenticationProviderConfig_Uninitialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuthenticationProviderConfig_Configure_Proxy(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
  void __RPC_STUB IAuthenticationProviderConfig_Configure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuthenticationProviderConfig_Activate_Proxy(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
  void __RPC_STUB IAuthenticationProviderConfig_Activate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuthenticationProviderConfig_Deactivate_Proxy(IAuthenticationProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
  void __RPC_STUB IAuthenticationProviderConfig_Deactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define DeclareIAuthenticationProviderConfigMembers(IPURE) STDMETHOD(Initialize)(THIS_ LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam) IPURE; STDMETHOD(Uninitialize)(THIS_ ULONG_PTR uConnectionParam) IPURE; STDMETHOD(Configure)(THIS_ ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2) IPURE; STDMETHOD(Activate)(THIS_ ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) IPURE; STDMETHOD(Deactivate)(THIS_ ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) IPURE;

  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0013_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0013_v0_0_s_ifspec;
#ifndef __IAccountingProviderConfig_INTERFACE_DEFINED__
#define __IAccountingProviderConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAccountingProviderConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAccountingProviderConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam) = 0;
    virtual HRESULT WINAPI Uninitialize(ULONG_PTR uConnectionParam) = 0;
    virtual HRESULT WINAPI Configure(ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2) = 0;
    virtual HRESULT WINAPI Activate(ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) = 0;
    virtual HRESULT WINAPI Deactivate(ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) = 0;
  };
#else
  typedef struct IAccountingProviderConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAccountingProviderConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAccountingProviderConfig *This);
      ULONG (WINAPI *Release)(IAccountingProviderConfig *This);
      HRESULT (WINAPI *Initialize)(IAccountingProviderConfig *This,LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam);
      HRESULT (WINAPI *Uninitialize)(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam);
      HRESULT (WINAPI *Configure)(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
      HRESULT (WINAPI *Activate)(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
      HRESULT (WINAPI *Deactivate)(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
    END_INTERFACE
  } IAccountingProviderConfigVtbl;
  struct IAccountingProviderConfig {
    CONST_VTBL struct IAccountingProviderConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAccountingProviderConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAccountingProviderConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAccountingProviderConfig_Release(This) (This)->lpVtbl->Release(This)
#define IAccountingProviderConfig_Initialize(This,pszMachineName,puConnectionParam) (This)->lpVtbl->Initialize(This,pszMachineName,puConnectionParam)
#define IAccountingProviderConfig_Uninitialize(This,uConnectionParam) (This)->lpVtbl->Uninitialize(This,uConnectionParam)
#define IAccountingProviderConfig_Configure(This,uConnectionParam,hWnd,dwFlags,uReserved1,uReserved2) (This)->lpVtbl->Configure(This,uConnectionParam,hWnd,dwFlags,uReserved1,uReserved2)
#define IAccountingProviderConfig_Activate(This,uConnectionParam,uReserved1,uReserved2) (This)->lpVtbl->Activate(This,uConnectionParam,uReserved1,uReserved2)
#define IAccountingProviderConfig_Deactivate(This,uConnectionParam,uReserved1,uReserved2) (This)->lpVtbl->Deactivate(This,uConnectionParam,uReserved1,uReserved2)
#endif
#endif
  HRESULT WINAPI IAccountingProviderConfig_Initialize_Proxy(IAccountingProviderConfig *This,LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam);
  void __RPC_STUB IAccountingProviderConfig_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccountingProviderConfig_Uninitialize_Proxy(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam);
  void __RPC_STUB IAccountingProviderConfig_Uninitialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccountingProviderConfig_Configure_Proxy(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
  void __RPC_STUB IAccountingProviderConfig_Configure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccountingProviderConfig_Activate_Proxy(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
  void __RPC_STUB IAccountingProviderConfig_Activate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccountingProviderConfig_Deactivate_Proxy(IAccountingProviderConfig *This,ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
  void __RPC_STUB IAccountingProviderConfig_Deactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define DeclareIAccountingProviderConfigMembers(IPURE) STDMETHOD(Initialize)(THIS_ LPCOLESTR pszMachineName,ULONG_PTR *puConnectionParam) IPURE; STDMETHOD(Uninitialize)(THIS_ ULONG_PTR uConnectionParam) IPURE; STDMETHOD(Configure)(THIS_ ULONG_PTR uConnectionParam,HWND hWnd,DWORD dwFlags,ULONG_PTR uReserved1,ULONG_PTR uReserved2) IPURE; STDMETHOD(Activate)(THIS_ ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) IPURE; STDMETHOD(Deactivate)(THIS_ ULONG_PTR uConnectionParam,ULONG_PTR uReserved1,ULONG_PTR uReserved2) IPURE;

  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0015_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0015_v0_0_s_ifspec;
#ifndef __IEAPProviderConfig_INTERFACE_DEFINED__
#define __IEAPProviderConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEAPProviderConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEAPProviderConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(LPCOLESTR pszMachineName,DWORD dwEapTypeId,ULONG_PTR *puConnectionParam) = 0;
    virtual HRESULT WINAPI Uninitialize(DWORD dwEapTypeId,ULONG_PTR uConnectionParam) = 0;
    virtual HRESULT WINAPI ServerInvokeConfigUI(DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hWnd,ULONG_PTR uReserved1,ULONG_PTR uReserved2) = 0;
    virtual HRESULT WINAPI RouterInvokeConfigUI(DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE **ppConnectionDataOut,DWORD *pdwSizeOfConnectionDataOut) = 0;
    virtual HRESULT WINAPI RouterInvokeCredentialsUI(DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE *pUserDataIn,DWORD dwSizeOfUserDataIn,BYTE **ppUserDataOut,DWORD *pdwSizeOfUserDataOut) = 0;
  };
#else
  typedef struct IEAPProviderConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEAPProviderConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEAPProviderConfig *This);
      ULONG (WINAPI *Release)(IEAPProviderConfig *This);
      HRESULT (WINAPI *Initialize)(IEAPProviderConfig *This,LPCOLESTR pszMachineName,DWORD dwEapTypeId,ULONG_PTR *puConnectionParam);
      HRESULT (WINAPI *Uninitialize)(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam);
      HRESULT (WINAPI *ServerInvokeConfigUI)(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hWnd,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
      HRESULT (WINAPI *RouterInvokeConfigUI)(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE **ppConnectionDataOut,DWORD *pdwSizeOfConnectionDataOut);
      HRESULT (WINAPI *RouterInvokeCredentialsUI)(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE *pUserDataIn,DWORD dwSizeOfUserDataIn,BYTE **ppUserDataOut,DWORD *pdwSizeOfUserDataOut);
    END_INTERFACE
  } IEAPProviderConfigVtbl;
  struct IEAPProviderConfig {
    CONST_VTBL struct IEAPProviderConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEAPProviderConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEAPProviderConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEAPProviderConfig_Release(This) (This)->lpVtbl->Release(This)
#define IEAPProviderConfig_Initialize(This,pszMachineName,dwEapTypeId,puConnectionParam) (This)->lpVtbl->Initialize(This,pszMachineName,dwEapTypeId,puConnectionParam)
#define IEAPProviderConfig_Uninitialize(This,dwEapTypeId,uConnectionParam) (This)->lpVtbl->Uninitialize(This,dwEapTypeId,uConnectionParam)
#define IEAPProviderConfig_ServerInvokeConfigUI(This,dwEapTypeId,uConnectionParam,hWnd,uReserved1,uReserved2) (This)->lpVtbl->ServerInvokeConfigUI(This,dwEapTypeId,uConnectionParam,hWnd,uReserved1,uReserved2)
#define IEAPProviderConfig_RouterInvokeConfigUI(This,dwEapTypeId,uConnectionParam,hwndParent,dwFlags,pConnectionDataIn,dwSizeOfConnectionDataIn,ppConnectionDataOut,pdwSizeOfConnectionDataOut) (This)->lpVtbl->RouterInvokeConfigUI(This,dwEapTypeId,uConnectionParam,hwndParent,dwFlags,pConnectionDataIn,dwSizeOfConnectionDataIn,ppConnectionDataOut,pdwSizeOfConnectionDataOut)
#define IEAPProviderConfig_RouterInvokeCredentialsUI(This,dwEapTypeId,uConnectionParam,hwndParent,dwFlags,pConnectionDataIn,dwSizeOfConnectionDataIn,pUserDataIn,dwSizeOfUserDataIn,ppUserDataOut,pdwSizeOfUserDataOut) (This)->lpVtbl->RouterInvokeCredentialsUI(This,dwEapTypeId,uConnectionParam,hwndParent,dwFlags,pConnectionDataIn,dwSizeOfConnectionDataIn,pUserDataIn,dwSizeOfUserDataIn,ppUserDataOut,pdwSizeOfUserDataOut)
#endif
#endif
  HRESULT WINAPI IEAPProviderConfig_Initialize_Proxy(IEAPProviderConfig *This,LPCOLESTR pszMachineName,DWORD dwEapTypeId,ULONG_PTR *puConnectionParam);
  void __RPC_STUB IEAPProviderConfig_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEAPProviderConfig_Uninitialize_Proxy(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam);
  void __RPC_STUB IEAPProviderConfig_Uninitialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEAPProviderConfig_ServerInvokeConfigUI_Proxy(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hWnd,ULONG_PTR uReserved1,ULONG_PTR uReserved2);
  void __RPC_STUB IEAPProviderConfig_ServerInvokeConfigUI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEAPProviderConfig_RouterInvokeConfigUI_Proxy(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE **ppConnectionDataOut,DWORD *pdwSizeOfConnectionDataOut);
  void __RPC_STUB IEAPProviderConfig_RouterInvokeConfigUI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEAPProviderConfig_RouterInvokeCredentialsUI_Proxy(IEAPProviderConfig *This,DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE *pUserDataIn,DWORD dwSizeOfUserDataIn,BYTE **ppUserDataOut,DWORD *pdwSizeOfUserDataOut);
  void __RPC_STUB IEAPProviderConfig_RouterInvokeCredentialsUI_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define DeclareIEAPProviderConfigMembers(IPURE) STDMETHOD(Initialize)(THIS_ LPCOLESTR pszMachineName,DWORD dwEapTypeId,ULONG_PTR *puConnectionParam) IPURE; STDMETHOD(Uninitialize)(THIS_ DWORD dwEapTypeId,ULONG_PTR uConnectionParam) IPURE; STDMETHOD(ServerInvokeConfigUI)(THIS_ DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hWnd,ULONG_PTR dwRes1,ULONG_PTR dwRes2) IPURE; STDMETHOD(RouterInvokeConfigUI)(THIS_ DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE **ppConnectionDataOut,DWORD *pdwSizeOfConnectionDataOut) IPURE; STDMETHOD(RouterInvokeCredentialsUI)(THIS_ DWORD dwEapTypeId,ULONG_PTR uConnectionParam,HWND hwndParent,DWORD dwFlags,BYTE *pConnectionDataIn,DWORD dwSizeOfConnectionDataIn,BYTE *pUserDataIn,DWORD dwSizeOfUserDataIn,BYTE **ppUserDataOut,DWORD *pdwSizeOfUserDataOut) IPURE;

  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0017_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_rrascfg_0017_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
