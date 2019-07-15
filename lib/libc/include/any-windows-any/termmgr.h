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

#ifndef __termmgr_h__
#define __termmgr_h__

#ifndef __ITTerminalControl_FWD_DEFINED__
#define __ITTerminalControl_FWD_DEFINED__
typedef struct ITTerminalControl ITTerminalControl;
#endif

#ifndef __ITPluggableTerminalInitialization_FWD_DEFINED__
#define __ITPluggableTerminalInitialization_FWD_DEFINED__
typedef struct ITPluggableTerminalInitialization ITPluggableTerminalInitialization;
#endif

#ifndef __ITTerminalManager_FWD_DEFINED__
#define __ITTerminalManager_FWD_DEFINED__
typedef struct ITTerminalManager ITTerminalManager;
#endif

#ifndef __ITTerminalManager2_FWD_DEFINED__
#define __ITTerminalManager2_FWD_DEFINED__
typedef struct ITTerminalManager2 ITTerminalManager2;
#endif

#ifndef __ITPluggableTerminalClassRegistration_FWD_DEFINED__
#define __ITPluggableTerminalClassRegistration_FWD_DEFINED__
typedef struct ITPluggableTerminalClassRegistration ITPluggableTerminalClassRegistration;
#endif

#ifndef __ITPluggableTerminalSuperclassRegistration_FWD_DEFINED__
#define __ITPluggableTerminalSuperclassRegistration_FWD_DEFINED__
typedef struct ITPluggableTerminalSuperclassRegistration ITPluggableTerminalSuperclassRegistration;
#endif

#ifndef __TerminalManager_FWD_DEFINED__
#define __TerminalManager_FWD_DEFINED__
#ifdef __cplusplus
typedef class TerminalManager TerminalManager;
#else
typedef struct TerminalManager TerminalManager;
#endif
#endif

#ifndef __PluggableSuperclassRegistration_FWD_DEFINED__
#define __PluggableSuperclassRegistration_FWD_DEFINED__
#ifdef __cplusplus
typedef class PluggableSuperclassRegistration PluggableSuperclassRegistration;
#else
typedef struct PluggableSuperclassRegistration PluggableSuperclassRegistration;
#endif
#endif

#ifndef __PluggableTerminalRegistration_FWD_DEFINED__
#define __PluggableTerminalRegistration_FWD_DEFINED__
#ifdef __cplusplus
typedef class PluggableTerminalRegistration PluggableTerminalRegistration;
#else
typedef struct PluggableTerminalRegistration PluggableTerminalRegistration;
#endif
#endif

#include "Objsafe.h"
#include "tapi3if.h"
#include "tapi3ds.h"
#include "msp.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum __MIDL___MIDL_itf_termmgr_0000_0001 {
    TMGR_TD_CAPTURE = 1,TMGR_TD_RENDER = 2,TMGR_TD_BOTH = 3
  } TMGR_DIRECTION;

#define CLSID_String_VideoSuperclass (L"{714C6F8C-6244-4685-87B3-B91F3F9EADA7}")
#define CLSID_String_StreamingSuperclass (L"{214F4ACC-AE0B-4464-8405-07029003F8E2}")
#define CLSID_String_FileSuperclass (L"{B4790031-56DB-4d3e-88C8-6FFAAFA08A91}")

  extern RPC_IF_HANDLE __MIDL_itf_termmgr_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_termmgr_0000_v0_0_s_ifspec;

#ifndef __ITTerminalControl_INTERFACE_DEFINED__
#define __ITTerminalControl_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ITTerminalControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTerminalControl : public IUnknown {
  public:
    virtual HRESULT WINAPI get_AddressHandle(MSP_HANDLE *phtAddress) = 0;
    virtual HRESULT WINAPI ConnectTerminal(IGraphBuilder *pGraph,DWORD dwTerminalDirection,DWORD *pdwNumPins,IPin **ppPins) = 0;
    virtual HRESULT WINAPI CompleteConnectTerminal(void) = 0;
    virtual HRESULT WINAPI DisconnectTerminal(IGraphBuilder *pGraph,DWORD dwReserved) = 0;
    virtual HRESULT WINAPI RunRenderFilter(void) = 0;
    virtual HRESULT WINAPI StopRenderFilter(void) = 0;
  };
#else
  typedef struct ITTerminalControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTerminalControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTerminalControl *This);
      ULONG (WINAPI *Release)(ITTerminalControl *This);
      HRESULT (WINAPI *get_AddressHandle)(ITTerminalControl *This,MSP_HANDLE *phtAddress);
      HRESULT (WINAPI *ConnectTerminal)(ITTerminalControl *This,IGraphBuilder *pGraph,DWORD dwTerminalDirection,DWORD *pdwNumPins,IPin **ppPins);
      HRESULT (WINAPI *CompleteConnectTerminal)(ITTerminalControl *This);
      HRESULT (WINAPI *DisconnectTerminal)(ITTerminalControl *This,IGraphBuilder *pGraph,DWORD dwReserved);
      HRESULT (WINAPI *RunRenderFilter)(ITTerminalControl *This);
      HRESULT (WINAPI *StopRenderFilter)(ITTerminalControl *This);
    END_INTERFACE
  } ITTerminalControlVtbl;
  struct ITTerminalControl {
    CONST_VTBL struct ITTerminalControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTerminalControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTerminalControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTerminalControl_Release(This) (This)->lpVtbl->Release(This)
#define ITTerminalControl_get_AddressHandle(This,phtAddress) (This)->lpVtbl->get_AddressHandle(This,phtAddress)
#define ITTerminalControl_ConnectTerminal(This,pGraph,dwTerminalDirection,pdwNumPins,ppPins) (This)->lpVtbl->ConnectTerminal(This,pGraph,dwTerminalDirection,pdwNumPins,ppPins)
#define ITTerminalControl_CompleteConnectTerminal(This) (This)->lpVtbl->CompleteConnectTerminal(This)
#define ITTerminalControl_DisconnectTerminal(This,pGraph,dwReserved) (This)->lpVtbl->DisconnectTerminal(This,pGraph,dwReserved)
#define ITTerminalControl_RunRenderFilter(This) (This)->lpVtbl->RunRenderFilter(This)
#define ITTerminalControl_StopRenderFilter(This) (This)->lpVtbl->StopRenderFilter(This)
#endif
#endif
  HRESULT WINAPI ITTerminalControl_get_AddressHandle_Proxy(ITTerminalControl *This,MSP_HANDLE *phtAddress);
  void __RPC_STUB ITTerminalControl_get_AddressHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalControl_ConnectTerminal_Proxy(ITTerminalControl *This,IGraphBuilder *pGraph,DWORD dwTerminalDirection,DWORD *pdwNumPins,IPin **ppPins);
  void __RPC_STUB ITTerminalControl_ConnectTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalControl_CompleteConnectTerminal_Proxy(ITTerminalControl *This);
  void __RPC_STUB ITTerminalControl_CompleteConnectTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalControl_DisconnectTerminal_Proxy(ITTerminalControl *This,IGraphBuilder *pGraph,DWORD dwReserved);
  void __RPC_STUB ITTerminalControl_DisconnectTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalControl_RunRenderFilter_Proxy(ITTerminalControl *This);
  void __RPC_STUB ITTerminalControl_RunRenderFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalControl_StopRenderFilter_Proxy(ITTerminalControl *This);
  void __RPC_STUB ITTerminalControl_StopRenderFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPluggableTerminalInitialization_INTERFACE_DEFINED__
#define __ITPluggableTerminalInitialization_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPluggableTerminalInitialization;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPluggableTerminalInitialization : public IUnknown {
  public:
    virtual HRESULT WINAPI InitializeDynamic(IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress) = 0;
  };
#else
  typedef struct ITPluggableTerminalInitializationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPluggableTerminalInitialization *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPluggableTerminalInitialization *This);
      ULONG (WINAPI *Release)(ITPluggableTerminalInitialization *This);
      HRESULT (WINAPI *InitializeDynamic)(ITPluggableTerminalInitialization *This,IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress);
    END_INTERFACE
  } ITPluggableTerminalInitializationVtbl;
  struct ITPluggableTerminalInitialization {
    CONST_VTBL struct ITPluggableTerminalInitializationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPluggableTerminalInitialization_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPluggableTerminalInitialization_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPluggableTerminalInitialization_Release(This) (This)->lpVtbl->Release(This)
#define ITPluggableTerminalInitialization_InitializeDynamic(This,iidTerminalClass,dwMediaType,Direction,htAddress) (This)->lpVtbl->InitializeDynamic(This,iidTerminalClass,dwMediaType,Direction,htAddress)
#endif
#endif
  HRESULT WINAPI ITPluggableTerminalInitialization_InitializeDynamic_Proxy(ITPluggableTerminalInitialization *This,IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress);
  void __RPC_STUB ITPluggableTerminalInitialization_InitializeDynamic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTerminalManager_INTERFACE_DEFINED__
#define __ITTerminalManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTerminalManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTerminalManager : public IUnknown {
  public:
    virtual HRESULT WINAPI GetDynamicTerminalClasses(DWORD dwMediaTypes,DWORD *pdwNumClasses,IID *pTerminalClasses) = 0;
    virtual HRESULT WINAPI CreateDynamicTerminal(IUnknown *pOuterUnknown,IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress,ITTerminal **ppTerminal) = 0;
  };
#else
  typedef struct ITTerminalManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTerminalManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTerminalManager *This);
      ULONG (WINAPI *Release)(ITTerminalManager *This);
      HRESULT (WINAPI *GetDynamicTerminalClasses)(ITTerminalManager *This,DWORD dwMediaTypes,DWORD *pdwNumClasses,IID *pTerminalClasses);
      HRESULT (WINAPI *CreateDynamicTerminal)(ITTerminalManager *This,IUnknown *pOuterUnknown,IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress,ITTerminal **ppTerminal);
    END_INTERFACE
  } ITTerminalManagerVtbl;
  struct ITTerminalManager {
    CONST_VTBL struct ITTerminalManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTerminalManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTerminalManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTerminalManager_Release(This) (This)->lpVtbl->Release(This)
#define ITTerminalManager_GetDynamicTerminalClasses(This,dwMediaTypes,pdwNumClasses,pTerminalClasses) (This)->lpVtbl->GetDynamicTerminalClasses(This,dwMediaTypes,pdwNumClasses,pTerminalClasses)
#define ITTerminalManager_CreateDynamicTerminal(This,pOuterUnknown,iidTerminalClass,dwMediaType,Direction,htAddress,ppTerminal) (This)->lpVtbl->CreateDynamicTerminal(This,pOuterUnknown,iidTerminalClass,dwMediaType,Direction,htAddress,ppTerminal)
#endif
#endif
  HRESULT WINAPI ITTerminalManager_GetDynamicTerminalClasses_Proxy(ITTerminalManager *This,DWORD dwMediaTypes,DWORD *pdwNumClasses,IID *pTerminalClasses);
  void __RPC_STUB ITTerminalManager_GetDynamicTerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalManager_CreateDynamicTerminal_Proxy(ITTerminalManager *This,IUnknown *pOuterUnknown,IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress,ITTerminal **ppTerminal);
  void __RPC_STUB ITTerminalManager_CreateDynamicTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTerminalManager2_INTERFACE_DEFINED__
#define __ITTerminalManager2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTerminalManager2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTerminalManager2 : public ITTerminalManager {
  public:
    virtual HRESULT WINAPI GetPluggableSuperclasses(DWORD *pdwNumSuperclasses,IID *pSuperclasses) = 0;
    virtual HRESULT WINAPI GetPluggableTerminalClasses(IID iidSuperclass,DWORD dwMediaTypes,DWORD *pdwNumClasses,IID *pTerminalClasses) = 0;
  };
#else
  typedef struct ITTerminalManager2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTerminalManager2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTerminalManager2 *This);
      ULONG (WINAPI *Release)(ITTerminalManager2 *This);
      HRESULT (WINAPI *GetDynamicTerminalClasses)(ITTerminalManager2 *This,DWORD dwMediaTypes,DWORD *pdwNumClasses,IID *pTerminalClasses);
      HRESULT (WINAPI *CreateDynamicTerminal)(ITTerminalManager2 *This,IUnknown *pOuterUnknown,IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress,ITTerminal **ppTerminal);
      HRESULT (WINAPI *GetPluggableSuperclasses)(ITTerminalManager2 *This,DWORD *pdwNumSuperclasses,IID *pSuperclasses);
      HRESULT (WINAPI *GetPluggableTerminalClasses)(ITTerminalManager2 *This,IID iidSuperclass,DWORD dwMediaTypes,DWORD *pdwNumClasses,IID *pTerminalClasses);
    END_INTERFACE
  } ITTerminalManager2Vtbl;
  struct ITTerminalManager2 {
    CONST_VTBL struct ITTerminalManager2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTerminalManager2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTerminalManager2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTerminalManager2_Release(This) (This)->lpVtbl->Release(This)
#define ITTerminalManager2_GetDynamicTerminalClasses(This,dwMediaTypes,pdwNumClasses,pTerminalClasses) (This)->lpVtbl->GetDynamicTerminalClasses(This,dwMediaTypes,pdwNumClasses,pTerminalClasses)
#define ITTerminalManager2_CreateDynamicTerminal(This,pOuterUnknown,iidTerminalClass,dwMediaType,Direction,htAddress,ppTerminal) (This)->lpVtbl->CreateDynamicTerminal(This,pOuterUnknown,iidTerminalClass,dwMediaType,Direction,htAddress,ppTerminal)
#define ITTerminalManager2_GetPluggableSuperclasses(This,pdwNumSuperclasses,pSuperclasses) (This)->lpVtbl->GetPluggableSuperclasses(This,pdwNumSuperclasses,pSuperclasses)
#define ITTerminalManager2_GetPluggableTerminalClasses(This,iidSuperclass,dwMediaTypes,pdwNumClasses,pTerminalClasses) (This)->lpVtbl->GetPluggableTerminalClasses(This,iidSuperclass,dwMediaTypes,pdwNumClasses,pTerminalClasses)
#endif
#endif
  HRESULT WINAPI ITTerminalManager2_GetPluggableSuperclasses_Proxy(ITTerminalManager2 *This,DWORD *pdwNumSuperclasses,IID *pSuperclasses);
  void __RPC_STUB ITTerminalManager2_GetPluggableSuperclasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalManager2_GetPluggableTerminalClasses_Proxy(ITTerminalManager2 *This,IID iidSuperclass,DWORD dwMediaTypes,DWORD *pdwNumClasses,IID *pTerminalClasses);
  void __RPC_STUB ITTerminalManager2_GetPluggableTerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPluggableTerminalClassRegistration_INTERFACE_DEFINED__
#define __ITPluggableTerminalClassRegistration_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPluggableTerminalClassRegistration;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPluggableTerminalClassRegistration : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_Company(BSTR *pCompany) = 0;
    virtual HRESULT WINAPI put_Company(BSTR bstrCompany) = 0;
    virtual HRESULT WINAPI get_Version(BSTR *pVersion) = 0;
    virtual HRESULT WINAPI put_Version(BSTR bstrVersion) = 0;
    virtual HRESULT WINAPI get_TerminalClass(BSTR *pTerminalClass) = 0;
    virtual HRESULT WINAPI put_TerminalClass(BSTR bstrTerminalClass) = 0;
    virtual HRESULT WINAPI get_CLSID(BSTR *pCLSID) = 0;
    virtual HRESULT WINAPI put_CLSID(BSTR bstrCLSID) = 0;
    virtual HRESULT WINAPI get_Direction(TMGR_DIRECTION *pDirection) = 0;
    virtual HRESULT WINAPI put_Direction(TMGR_DIRECTION nDirection) = 0;
    virtual HRESULT WINAPI get_MediaTypes(__LONG32 *pMediaTypes) = 0;
    virtual HRESULT WINAPI put_MediaTypes(__LONG32 nMediaTypes) = 0;
    virtual HRESULT WINAPI Add(BSTR bstrSuperclass) = 0;
    virtual HRESULT WINAPI Delete(BSTR bstrSuperclass) = 0;
    virtual HRESULT WINAPI GetTerminalClassInfo(BSTR bstrSuperclass) = 0;
  };
#else
  typedef struct ITPluggableTerminalClassRegistrationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPluggableTerminalClassRegistration *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPluggableTerminalClassRegistration *This);
      ULONG (WINAPI *Release)(ITPluggableTerminalClassRegistration *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPluggableTerminalClassRegistration *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPluggableTerminalClassRegistration *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPluggableTerminalClassRegistration *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPluggableTerminalClassRegistration *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ITPluggableTerminalClassRegistration *This,BSTR *pName);
      HRESULT (WINAPI *put_Name)(ITPluggableTerminalClassRegistration *This,BSTR bstrName);
      HRESULT (WINAPI *get_Company)(ITPluggableTerminalClassRegistration *This,BSTR *pCompany);
      HRESULT (WINAPI *put_Company)(ITPluggableTerminalClassRegistration *This,BSTR bstrCompany);
      HRESULT (WINAPI *get_Version)(ITPluggableTerminalClassRegistration *This,BSTR *pVersion);
      HRESULT (WINAPI *put_Version)(ITPluggableTerminalClassRegistration *This,BSTR bstrVersion);
      HRESULT (WINAPI *get_TerminalClass)(ITPluggableTerminalClassRegistration *This,BSTR *pTerminalClass);
      HRESULT (WINAPI *put_TerminalClass)(ITPluggableTerminalClassRegistration *This,BSTR bstrTerminalClass);
      HRESULT (WINAPI *get_CLSID)(ITPluggableTerminalClassRegistration *This,BSTR *pCLSID);
      HRESULT (WINAPI *put_CLSID)(ITPluggableTerminalClassRegistration *This,BSTR bstrCLSID);
      HRESULT (WINAPI *get_Direction)(ITPluggableTerminalClassRegistration *This,TMGR_DIRECTION *pDirection);
      HRESULT (WINAPI *put_Direction)(ITPluggableTerminalClassRegistration *This,TMGR_DIRECTION nDirection);
      HRESULT (WINAPI *get_MediaTypes)(ITPluggableTerminalClassRegistration *This,__LONG32 *pMediaTypes);
      HRESULT (WINAPI *put_MediaTypes)(ITPluggableTerminalClassRegistration *This,__LONG32 nMediaTypes);
      HRESULT (WINAPI *Add)(ITPluggableTerminalClassRegistration *This,BSTR bstrSuperclass);
      HRESULT (WINAPI *Delete)(ITPluggableTerminalClassRegistration *This,BSTR bstrSuperclass);
      HRESULT (WINAPI *GetTerminalClassInfo)(ITPluggableTerminalClassRegistration *This,BSTR bstrSuperclass);
    END_INTERFACE
  } ITPluggableTerminalClassRegistrationVtbl;
  struct ITPluggableTerminalClassRegistration {
    CONST_VTBL struct ITPluggableTerminalClassRegistrationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPluggableTerminalClassRegistration_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPluggableTerminalClassRegistration_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPluggableTerminalClassRegistration_Release(This) (This)->lpVtbl->Release(This)
#define ITPluggableTerminalClassRegistration_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPluggableTerminalClassRegistration_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPluggableTerminalClassRegistration_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPluggableTerminalClassRegistration_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPluggableTerminalClassRegistration_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define ITPluggableTerminalClassRegistration_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define ITPluggableTerminalClassRegistration_get_Company(This,pCompany) (This)->lpVtbl->get_Company(This,pCompany)
#define ITPluggableTerminalClassRegistration_put_Company(This,bstrCompany) (This)->lpVtbl->put_Company(This,bstrCompany)
#define ITPluggableTerminalClassRegistration_get_Version(This,pVersion) (This)->lpVtbl->get_Version(This,pVersion)
#define ITPluggableTerminalClassRegistration_put_Version(This,bstrVersion) (This)->lpVtbl->put_Version(This,bstrVersion)
#define ITPluggableTerminalClassRegistration_get_TerminalClass(This,pTerminalClass) (This)->lpVtbl->get_TerminalClass(This,pTerminalClass)
#define ITPluggableTerminalClassRegistration_put_TerminalClass(This,bstrTerminalClass) (This)->lpVtbl->put_TerminalClass(This,bstrTerminalClass)
#define ITPluggableTerminalClassRegistration_get_CLSID(This,pCLSID) (This)->lpVtbl->get_CLSID(This,pCLSID)
#define ITPluggableTerminalClassRegistration_put_CLSID(This,bstrCLSID) (This)->lpVtbl->put_CLSID(This,bstrCLSID)
#define ITPluggableTerminalClassRegistration_get_Direction(This,pDirection) (This)->lpVtbl->get_Direction(This,pDirection)
#define ITPluggableTerminalClassRegistration_put_Direction(This,nDirection) (This)->lpVtbl->put_Direction(This,nDirection)
#define ITPluggableTerminalClassRegistration_get_MediaTypes(This,pMediaTypes) (This)->lpVtbl->get_MediaTypes(This,pMediaTypes)
#define ITPluggableTerminalClassRegistration_put_MediaTypes(This,nMediaTypes) (This)->lpVtbl->put_MediaTypes(This,nMediaTypes)
#define ITPluggableTerminalClassRegistration_Add(This,bstrSuperclass) (This)->lpVtbl->Add(This,bstrSuperclass)
#define ITPluggableTerminalClassRegistration_Delete(This,bstrSuperclass) (This)->lpVtbl->Delete(This,bstrSuperclass)
#define ITPluggableTerminalClassRegistration_GetTerminalClassInfo(This,bstrSuperclass) (This)->lpVtbl->GetTerminalClassInfo(This,bstrSuperclass)
#endif
#endif
  HRESULT WINAPI ITPluggableTerminalClassRegistration_get_Name_Proxy(ITPluggableTerminalClassRegistration *This,BSTR *pName);
  void __RPC_STUB ITPluggableTerminalClassRegistration_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_put_Name_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrName);
  void __RPC_STUB ITPluggableTerminalClassRegistration_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_get_Company_Proxy(ITPluggableTerminalClassRegistration *This,BSTR *pCompany);
  void __RPC_STUB ITPluggableTerminalClassRegistration_get_Company_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_put_Company_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrCompany);
  void __RPC_STUB ITPluggableTerminalClassRegistration_put_Company_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_get_Version_Proxy(ITPluggableTerminalClassRegistration *This,BSTR *pVersion);
  void __RPC_STUB ITPluggableTerminalClassRegistration_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_put_Version_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrVersion);
  void __RPC_STUB ITPluggableTerminalClassRegistration_put_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_get_TerminalClass_Proxy(ITPluggableTerminalClassRegistration *This,BSTR *pTerminalClass);
  void __RPC_STUB ITPluggableTerminalClassRegistration_get_TerminalClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_put_TerminalClass_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrTerminalClass);
  void __RPC_STUB ITPluggableTerminalClassRegistration_put_TerminalClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_get_CLSID_Proxy(ITPluggableTerminalClassRegistration *This,BSTR *pCLSID);
  void __RPC_STUB ITPluggableTerminalClassRegistration_get_CLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_put_CLSID_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrCLSID);
  void __RPC_STUB ITPluggableTerminalClassRegistration_put_CLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_get_Direction_Proxy(ITPluggableTerminalClassRegistration *This,TMGR_DIRECTION *pDirection);
  void __RPC_STUB ITPluggableTerminalClassRegistration_get_Direction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_put_Direction_Proxy(ITPluggableTerminalClassRegistration *This,TMGR_DIRECTION nDirection);
  void __RPC_STUB ITPluggableTerminalClassRegistration_put_Direction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_get_MediaTypes_Proxy(ITPluggableTerminalClassRegistration *This,__LONG32 *pMediaTypes);
  void __RPC_STUB ITPluggableTerminalClassRegistration_get_MediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_put_MediaTypes_Proxy(ITPluggableTerminalClassRegistration *This,__LONG32 nMediaTypes);
  void __RPC_STUB ITPluggableTerminalClassRegistration_put_MediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_Add_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrSuperclass);
  void __RPC_STUB ITPluggableTerminalClassRegistration_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_Delete_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrSuperclass);
  void __RPC_STUB ITPluggableTerminalClassRegistration_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassRegistration_GetTerminalClassInfo_Proxy(ITPluggableTerminalClassRegistration *This,BSTR bstrSuperclass);
  void __RPC_STUB ITPluggableTerminalClassRegistration_GetTerminalClassInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPluggableTerminalSuperclassRegistration_INTERFACE_DEFINED__
#define __ITPluggableTerminalSuperclassRegistration_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPluggableTerminalSuperclassRegistration;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPluggableTerminalSuperclassRegistration : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_CLSID(BSTR *pCLSID) = 0;
    virtual HRESULT WINAPI put_CLSID(BSTR bstrCLSID) = 0;
    virtual HRESULT WINAPI Add(void) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI GetTerminalSuperclassInfo(void) = 0;
    virtual HRESULT WINAPI get_TerminalClasses(VARIANT *pTerminals) = 0;
    virtual HRESULT WINAPI EnumerateTerminalClasses(IEnumTerminalClass **ppTerminals) = 0;
  };
#else
  typedef struct ITPluggableTerminalSuperclassRegistrationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPluggableTerminalSuperclassRegistration *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPluggableTerminalSuperclassRegistration *This);
      ULONG (WINAPI *Release)(ITPluggableTerminalSuperclassRegistration *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPluggableTerminalSuperclassRegistration *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPluggableTerminalSuperclassRegistration *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPluggableTerminalSuperclassRegistration *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPluggableTerminalSuperclassRegistration *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ITPluggableTerminalSuperclassRegistration *This,BSTR *pName);
      HRESULT (WINAPI *put_Name)(ITPluggableTerminalSuperclassRegistration *This,BSTR bstrName);
      HRESULT (WINAPI *get_CLSID)(ITPluggableTerminalSuperclassRegistration *This,BSTR *pCLSID);
      HRESULT (WINAPI *put_CLSID)(ITPluggableTerminalSuperclassRegistration *This,BSTR bstrCLSID);
      HRESULT (WINAPI *Add)(ITPluggableTerminalSuperclassRegistration *This);
      HRESULT (WINAPI *Delete)(ITPluggableTerminalSuperclassRegistration *This);
      HRESULT (WINAPI *GetTerminalSuperclassInfo)(ITPluggableTerminalSuperclassRegistration *This);
      HRESULT (WINAPI *get_TerminalClasses)(ITPluggableTerminalSuperclassRegistration *This,VARIANT *pTerminals);
      HRESULT (WINAPI *EnumerateTerminalClasses)(ITPluggableTerminalSuperclassRegistration *This,IEnumTerminalClass **ppTerminals);
    END_INTERFACE
  } ITPluggableTerminalSuperclassRegistrationVtbl;
  struct ITPluggableTerminalSuperclassRegistration {
    CONST_VTBL struct ITPluggableTerminalSuperclassRegistrationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPluggableTerminalSuperclassRegistration_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPluggableTerminalSuperclassRegistration_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPluggableTerminalSuperclassRegistration_Release(This) (This)->lpVtbl->Release(This)
#define ITPluggableTerminalSuperclassRegistration_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPluggableTerminalSuperclassRegistration_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPluggableTerminalSuperclassRegistration_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPluggableTerminalSuperclassRegistration_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPluggableTerminalSuperclassRegistration_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define ITPluggableTerminalSuperclassRegistration_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define ITPluggableTerminalSuperclassRegistration_get_CLSID(This,pCLSID) (This)->lpVtbl->get_CLSID(This,pCLSID)
#define ITPluggableTerminalSuperclassRegistration_put_CLSID(This,bstrCLSID) (This)->lpVtbl->put_CLSID(This,bstrCLSID)
#define ITPluggableTerminalSuperclassRegistration_Add(This) (This)->lpVtbl->Add(This)
#define ITPluggableTerminalSuperclassRegistration_Delete(This) (This)->lpVtbl->Delete(This)
#define ITPluggableTerminalSuperclassRegistration_GetTerminalSuperclassInfo(This) (This)->lpVtbl->GetTerminalSuperclassInfo(This)
#define ITPluggableTerminalSuperclassRegistration_get_TerminalClasses(This,pTerminals) (This)->lpVtbl->get_TerminalClasses(This,pTerminals)
#define ITPluggableTerminalSuperclassRegistration_EnumerateTerminalClasses(This,ppTerminals) (This)->lpVtbl->EnumerateTerminalClasses(This,ppTerminals)
#endif
#endif
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_get_Name_Proxy(ITPluggableTerminalSuperclassRegistration *This,BSTR *pName);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_put_Name_Proxy(ITPluggableTerminalSuperclassRegistration *This,BSTR bstrName);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_get_CLSID_Proxy(ITPluggableTerminalSuperclassRegistration *This,BSTR *pCLSID);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_get_CLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_put_CLSID_Proxy(ITPluggableTerminalSuperclassRegistration *This,BSTR bstrCLSID);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_put_CLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_Add_Proxy(ITPluggableTerminalSuperclassRegistration *This);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_Delete_Proxy(ITPluggableTerminalSuperclassRegistration *This);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_GetTerminalSuperclassInfo_Proxy(ITPluggableTerminalSuperclassRegistration *This);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_GetTerminalSuperclassInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_get_TerminalClasses_Proxy(ITPluggableTerminalSuperclassRegistration *This,VARIANT *pTerminals);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_get_TerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassRegistration_EnumerateTerminalClasses_Proxy(ITPluggableTerminalSuperclassRegistration *This,IEnumTerminalClass **ppTerminals);
  void __RPC_STUB ITPluggableTerminalSuperclassRegistration_EnumerateTerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __TERMMGRLib_LIBRARY_DEFINED__
#define __TERMMGRLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_TERMMGRLib;
  EXTERN_C const CLSID CLSID_TerminalManager;
#ifdef __cplusplus
  class TerminalManager;
#endif
  EXTERN_C const CLSID CLSID_PluggableSuperclassRegistration;
#ifdef __cplusplus
  class PluggableSuperclassRegistration;
#endif
  EXTERN_C const CLSID CLSID_PluggableTerminalRegistration;
#ifdef __cplusplus
  class PluggableTerminalRegistration;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
