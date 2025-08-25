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

#ifndef __netprov_h__
#define __netprov_h__

#ifndef __IProvisioningDomain_FWD_DEFINED__
#define __IProvisioningDomain_FWD_DEFINED__
typedef struct IProvisioningDomain IProvisioningDomain;
#endif

#ifndef __IProvisioningProfileWireless_FWD_DEFINED__
#define __IProvisioningProfileWireless_FWD_DEFINED__
typedef struct IProvisioningProfileWireless IProvisioningProfileWireless;
#endif

#ifndef __IFlashConfig_FWD_DEFINED__
#define __IFlashConfig_FWD_DEFINED__
typedef struct IFlashConfig IFlashConfig;
#endif

#ifndef __NetProvisioning_FWD_DEFINED__
#define __NetProvisioning_FWD_DEFINED__
#ifdef __cplusplus
typedef class NetProvisioning NetProvisioning;
#else
typedef struct NetProvisioning NetProvisioning;
#endif
#endif

#ifndef __FlashConfig_FWD_DEFINED__
#define __FlashConfig_FWD_DEFINED__
#ifdef __cplusplus
typedef class FlashConfig FlashConfig;
#else
typedef struct FlashConfig FlashConfig;
#endif
#endif

#include "oaidl.h"
#include "prsht.h"
#include "msxml.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_netprov_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netprov_0000_v0_0_s_ifspec;

#ifndef __IProvisioningDomain_INTERFACE_DEFINED__
#define __IProvisioningDomain_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IProvisioningDomain;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProvisioningDomain : public IUnknown {
  public:
    virtual HRESULT WINAPI Add(LPCWSTR pszwPathToFolder) = 0;
    virtual HRESULT WINAPI Query(LPCWSTR pszwDomain,LPCWSTR pszwLanguage,LPCWSTR pszwXPathQuery,IXMLDOMNodeList **Nodes) = 0;
  };
#else
  typedef struct IProvisioningDomainVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IProvisioningDomain *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IProvisioningDomain *This);
      ULONG (WINAPI *Release)(IProvisioningDomain *This);
      HRESULT (WINAPI *Add)(IProvisioningDomain *This,LPCWSTR pszwPathToFolder);
      HRESULT (WINAPI *Query)(IProvisioningDomain *This,LPCWSTR pszwDomain,LPCWSTR pszwLanguage,LPCWSTR pszwXPathQuery,IXMLDOMNodeList **Nodes);
    END_INTERFACE
  } IProvisioningDomainVtbl;
  struct IProvisioningDomain {
    CONST_VTBL struct IProvisioningDomainVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProvisioningDomain_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProvisioningDomain_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProvisioningDomain_Release(This) (This)->lpVtbl->Release(This)
#define IProvisioningDomain_Add(This,pszwPathToFolder) (This)->lpVtbl->Add(This,pszwPathToFolder)
#define IProvisioningDomain_Query(This,pszwDomain,pszwLanguage,pszwXPathQuery,Nodes) (This)->lpVtbl->Query(This,pszwDomain,pszwLanguage,pszwXPathQuery,Nodes)
#endif
#endif
  HRESULT WINAPI IProvisioningDomain_Add_Proxy(IProvisioningDomain *This,LPCWSTR pszwPathToFolder);
  void __RPC_STUB IProvisioningDomain_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IProvisioningDomain_Query_Proxy(IProvisioningDomain *This,LPCWSTR pszwDomain,LPCWSTR pszwLanguage,LPCWSTR pszwXPathQuery,IXMLDOMNodeList **Nodes);
  void __RPC_STUB IProvisioningDomain_Query_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define WZC_PROFILE_SUCCESS 0
#define WZC_PROFILE_XML_ERROR_NO_VERSION 1
#define WZC_PROFILE_XML_ERROR_BAD_VERSION 2
#define WZC_PROFILE_XML_ERROR_UNSUPPORTED_VERSION 3
#define WZC_PROFILE_XML_ERROR_SSID_NOT_FOUND 4
#define WZC_PROFILE_XML_ERROR_BAD_SSID 5
#define WZC_PROFILE_XML_ERROR_CONNECTION_TYPE 6
#define WZC_PROFILE_XML_ERROR_AUTHENTICATION 7
#define WZC_PROFILE_XML_ERROR_ENCRYPTION 8
#define WZC_PROFILE_XML_ERROR_KEY_PROVIDED_AUTOMATICALLY 9
#define WZC_PROFILE_XML_ERROR_1X_ENABLED 10
#define WZC_PROFILE_XML_ERROR_EAP_METHOD 11
#define WZC_PROFILE_XML_ERROR_BAD_KEY_INDEX 12
#define WZC_PROFILE_XML_ERROR_KEY_INDEX_RANGE 13
#define WZC_PROFILE_XML_ERROR_BAD_NETWORK_KEY 14
#define WZC_PROFILE_CONFIG_ERROR_INVALID_AUTH_FOR_CONNECTION_TYPE 15
#define WZC_PROFILE_CONFIG_ERROR_INVALID_ENCRYPTION_FOR_AUTHMODE 16
#define WZC_PROFILE_CONFIG_ERROR_KEY_REQUIRED 17
#define WZC_PROFILE_CONFIG_ERROR_KEY_INDEX_REQUIRED 18
#define WZC_PROFILE_CONFIG_ERROR_KEY_INDEX_NOT_APPLICABLE 19
#define WZC_PROFILE_CONFIG_ERROR_1X_NOT_ALLOWED 20
#define WZC_PROFILE_CONFIG_ERROR_1X_NOT_ALLOWED_KEY_REQUIRED 21
#define WZC_PROFILE_CONFIG_ERROR_1X_NOT_ENABLED_KEY_PROVIDED 22
#define WZC_PROFILE_CONFIG_ERROR_EAP_METHOD_REQUIRED 23
#define WZC_PROFILE_CONFIG_ERROR_EAP_METHOD_NOT_APPLICABLE 24
#define WZC_PROFILE_CONFIG_ERROR_WPA_NOT_SUPPORTED 25
#define WZC_PROFILE_CONFIG_ERROR_WPA_ENCRYPTION_NOT_SUPPORTED 26
#define WZC_PROFILE_SET_ERROR_DUPLICATE_NETWORK 27
#define WZC_PROFILE_SET_ERROR_MEMORY_ALLOCATION 28
#define WZC_PROFILE_SET_ERROR_READING_1X_CONFIG 29
#define WZC_PROFILE_SET_ERROR_WRITING_1X_CONFIG 30
#define WZC_PROFILE_SET_ERROR_WRITING_WZC_CFG 31
#define WZC_PROFILE_API_ERROR_NOT_SUPPORTED 32
#define WZC_PROFILE_API_ERROR_FAILED_TO_LOAD_XML 33
#define WZC_PROFILE_API_ERROR_FAILED_TO_LOAD_SCHEMA 34
#define WZC_PROFILE_API_ERROR_XML_VALIDATION_FAILED 35
#define WZC_PROFILE_API_ERROR_INTERNAL 36

  extern RPC_IF_HANDLE __MIDL_itf_netprov_0154_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netprov_0154_v0_0_s_ifspec;

#ifndef __IProvisioningProfileWireless_INTERFACE_DEFINED__
#define __IProvisioningProfileWireless_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IProvisioningProfileWireless;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProvisioningProfileWireless : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateProfile(BSTR bstrXMLWirelessConfigProfile,BSTR bstrXMLConnectionConfigProfile,GUID *pAdapterInstanceGuid,ULONG *pulStatus) = 0;
  };
#else
  typedef struct IProvisioningProfileWirelessVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IProvisioningProfileWireless *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IProvisioningProfileWireless *This);
      ULONG (WINAPI *Release)(IProvisioningProfileWireless *This);
      HRESULT (WINAPI *CreateProfile)(IProvisioningProfileWireless *This,BSTR bstrXMLWirelessConfigProfile,BSTR bstrXMLConnectionConfigProfile,GUID *pAdapterInstanceGuid,ULONG *pulStatus);
    END_INTERFACE
  } IProvisioningProfileWirelessVtbl;
  struct IProvisioningProfileWireless {
    CONST_VTBL struct IProvisioningProfileWirelessVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProvisioningProfileWireless_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProvisioningProfileWireless_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProvisioningProfileWireless_Release(This) (This)->lpVtbl->Release(This)
#define IProvisioningProfileWireless_CreateProfile(This,bstrXMLWirelessConfigProfile,bstrXMLConnectionConfigProfile,pAdapterInstanceGuid,pulStatus) (This)->lpVtbl->CreateProfile(This,bstrXMLWirelessConfigProfile,bstrXMLConnectionConfigProfile,pAdapterInstanceGuid,pulStatus)
#endif
#endif
  HRESULT WINAPI IProvisioningProfileWireless_CreateProfile_Proxy(IProvisioningProfileWireless *This,BSTR bstrXMLWirelessConfigProfile,BSTR bstrXMLConnectionConfigProfile,GUID *pAdapterInstanceGuid,ULONG *pulStatus);
  void __RPC_STUB IProvisioningProfileWireless_CreateProfile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IFlashConfig_INTERFACE_DEFINED__
#define __IFlashConfig_INTERFACE_DEFINED__
  typedef enum tagFLASHCONFIG_FLAGS {
    FCF_INFRASTRUCTURE = 0,FCF_ADHOC = 1
  } FLASHCONFIG_FLAGS;

  EXTERN_C const IID IID_IFlashConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IFlashConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI RunWizard(HWND hwndParent,FLASHCONFIG_FLAGS eFlags) = 0;
  };
#else
  typedef struct IFlashConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IFlashConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IFlashConfig *This);
      ULONG (WINAPI *Release)(IFlashConfig *This);
      HRESULT (WINAPI *RunWizard)(IFlashConfig *This,HWND hwndParent,FLASHCONFIG_FLAGS eFlags);
    END_INTERFACE
  } IFlashConfigVtbl;
  struct IFlashConfig {
    CONST_VTBL struct IFlashConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IFlashConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFlashConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFlashConfig_Release(This) (This)->lpVtbl->Release(This)
#define IFlashConfig_RunWizard(This,hwndParent,eFlags) (This)->lpVtbl->RunWizard(This,hwndParent,eFlags)
#endif
#endif
  HRESULT WINAPI IFlashConfig_RunWizard_Proxy(IFlashConfig *This,HWND hwndParent,FLASHCONFIG_FLAGS eFlags);
  void __RPC_STUB IFlashConfig_RunWizard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __NETPROVLib_LIBRARY_DEFINED__
#define __NETPROVLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_NETPROVLib;
  EXTERN_C const CLSID CLSID_NetProvisioning;
#ifdef __cplusplus
  class NetProvisioning;
#endif
  EXTERN_C const CLSID CLSID_FlashConfig;
#ifdef __cplusplus
  class FlashConfig;
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
