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

#ifndef __netcon_h__
#define __netcon_h__

#ifndef __IEnumNetConnection_FWD_DEFINED__
#define __IEnumNetConnection_FWD_DEFINED__
typedef struct IEnumNetConnection IEnumNetConnection;
#endif

#ifndef __INetConnection_FWD_DEFINED__
#define __INetConnection_FWD_DEFINED__
typedef struct INetConnection INetConnection;
#endif

#ifndef __INetConnectionManager_FWD_DEFINED__
#define __INetConnectionManager_FWD_DEFINED__
typedef struct INetConnectionManager INetConnectionManager;
#endif

#ifndef __INetConnectionManagerEvents_FWD_DEFINED__
#define __INetConnectionManagerEvents_FWD_DEFINED__
typedef struct INetConnectionManagerEvents INetConnectionManagerEvents;
#endif

#ifndef __INetConnectionConnectUi_FWD_DEFINED__
#define __INetConnectionConnectUi_FWD_DEFINED__
typedef struct INetConnectionConnectUi INetConnectionConnectUi;
#endif

#ifndef __INetConnectionPropertyUi_FWD_DEFINED__
#define __INetConnectionPropertyUi_FWD_DEFINED__
typedef struct INetConnectionPropertyUi INetConnectionPropertyUi;
#endif

#ifndef __INetConnectionPropertyUi2_FWD_DEFINED__
#define __INetConnectionPropertyUi2_FWD_DEFINED__
typedef struct INetConnectionPropertyUi2 INetConnectionPropertyUi2;
#endif

#ifndef __INetConnectionCommonUi_FWD_DEFINED__
#define __INetConnectionCommonUi_FWD_DEFINED__
typedef struct INetConnectionCommonUi INetConnectionCommonUi;
#endif

#ifndef __IEnumNetSharingPortMapping_FWD_DEFINED__
#define __IEnumNetSharingPortMapping_FWD_DEFINED__
typedef struct IEnumNetSharingPortMapping IEnumNetSharingPortMapping;
#endif

#ifndef __INetSharingPortMappingProps_FWD_DEFINED__
#define __INetSharingPortMappingProps_FWD_DEFINED__
typedef struct INetSharingPortMappingProps INetSharingPortMappingProps;
#endif

#ifndef __INetSharingPortMapping_FWD_DEFINED__
#define __INetSharingPortMapping_FWD_DEFINED__
typedef struct INetSharingPortMapping INetSharingPortMapping;
#endif

#ifndef __IEnumNetSharingEveryConnection_FWD_DEFINED__
#define __IEnumNetSharingEveryConnection_FWD_DEFINED__
typedef struct IEnumNetSharingEveryConnection IEnumNetSharingEveryConnection;
#endif

#ifndef __IEnumNetSharingPublicConnection_FWD_DEFINED__
#define __IEnumNetSharingPublicConnection_FWD_DEFINED__
typedef struct IEnumNetSharingPublicConnection IEnumNetSharingPublicConnection;
#endif

#ifndef __IEnumNetSharingPrivateConnection_FWD_DEFINED__
#define __IEnumNetSharingPrivateConnection_FWD_DEFINED__
typedef struct IEnumNetSharingPrivateConnection IEnumNetSharingPrivateConnection;
#endif

#ifndef __INetSharingPortMappingCollection_FWD_DEFINED__
#define __INetSharingPortMappingCollection_FWD_DEFINED__
typedef struct INetSharingPortMappingCollection INetSharingPortMappingCollection;
#endif

#ifndef __INetConnectionProps_FWD_DEFINED__
#define __INetConnectionProps_FWD_DEFINED__
typedef struct INetConnectionProps INetConnectionProps;
#endif

#ifndef __INetSharingConfiguration_FWD_DEFINED__
#define __INetSharingConfiguration_FWD_DEFINED__
typedef struct INetSharingConfiguration INetSharingConfiguration;
#endif

#ifndef __INetSharingEveryConnectionCollection_FWD_DEFINED__
#define __INetSharingEveryConnectionCollection_FWD_DEFINED__
typedef struct INetSharingEveryConnectionCollection INetSharingEveryConnectionCollection;
#endif

#ifndef __INetSharingPublicConnectionCollection_FWD_DEFINED__
#define __INetSharingPublicConnectionCollection_FWD_DEFINED__
typedef struct INetSharingPublicConnectionCollection INetSharingPublicConnectionCollection;
#endif

#ifndef __INetSharingPrivateConnectionCollection_FWD_DEFINED__
#define __INetSharingPrivateConnectionCollection_FWD_DEFINED__
typedef struct INetSharingPrivateConnectionCollection INetSharingPrivateConnectionCollection;
#endif

#ifndef __INetSharingManager_FWD_DEFINED__
#define __INetSharingManager_FWD_DEFINED__
typedef struct INetSharingManager INetSharingManager;
#endif

#ifndef __NetSharingManager_FWD_DEFINED__
#define __NetSharingManager_FWD_DEFINED__
#ifdef __cplusplus
typedef class NetSharingManager NetSharingManager;
#else
typedef struct NetSharingManager NetSharingManager;
#endif
#endif

#include "oaidl.h"
#include "prsht.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  EXTERN_C const CLSID CLSID_ConnectionManager;
  EXTERN_C const CLSID CLSID_ConnectionCommonUi;
  EXTERN_C const CLSID CLSID_NetSharingManager;

#define NETCON_HKEYCURRENTUSERPATH TEXT("Software\\Microsoft\\Windows NT\\CurrentVersion\\Network\\Network Connections")
#define NETCON_DESKTOPSHORTCUT TEXT("DesktopShortcut")
#define NETCON_MAX_NAME_LEN 256

  extern RPC_IF_HANDLE __MIDL_itf_netcon_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netcon_0000_v0_0_s_ifspec;

#ifndef __IEnumNetConnection_INTERFACE_DEFINED__
#define __IEnumNetConnection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumNetConnection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumNetConnection : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,INetConnection **rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumNetConnection **ppenum) = 0;
  };
#else
  typedef struct IEnumNetConnectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumNetConnection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumNetConnection *This);
      ULONG (WINAPI *Release)(IEnumNetConnection *This);
      HRESULT (WINAPI *Next)(IEnumNetConnection *This,ULONG celt,INetConnection **rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumNetConnection *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumNetConnection *This);
      HRESULT (WINAPI *Clone)(IEnumNetConnection *This,IEnumNetConnection **ppenum);
    END_INTERFACE
  } IEnumNetConnectionVtbl;
  struct IEnumNetConnection {
    CONST_VTBL struct IEnumNetConnectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumNetConnection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumNetConnection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumNetConnection_Release(This) (This)->lpVtbl->Release(This)
#define IEnumNetConnection_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumNetConnection_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumNetConnection_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumNetConnection_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumNetConnection_Next_Proxy(IEnumNetConnection *This,ULONG celt,INetConnection **rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumNetConnection_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetConnection_Skip_Proxy(IEnumNetConnection *This,ULONG celt);
  void __RPC_STUB IEnumNetConnection_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetConnection_Reset_Proxy(IEnumNetConnection *This);
  void __RPC_STUB IEnumNetConnection_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetConnection_Clone_Proxy(IEnumNetConnection *This,IEnumNetConnection **ppenum);
  void __RPC_STUB IEnumNetConnection_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetConnection_INTERFACE_DEFINED__
#define __INetConnection_INTERFACE_DEFINED__
  typedef enum tagNETCON_CHARACTERISTIC_FLAGS {
    NCCF_NONE = 0,NCCF_ALL_USERS = 0x1,NCCF_ALLOW_DUPLICATION = 0x2,NCCF_ALLOW_REMOVAL = 0x4,NCCF_ALLOW_RENAME = 0x8,NCCF_SHOW_ICON = 0x10,
    NCCF_INCOMING_ONLY = 0x20,NCCF_OUTGOING_ONLY = 0x40,NCCF_BRANDED = 0x80,NCCF_SHARED = 0x100,NCCF_BRIDGED = 0x200,NCCF_FIREWALLED = 0x400,
    NCCF_DEFAULT = 0x800,NCCF_HOMENET_CAPABLE = 0x1000,NCCF_SHARED_PRIVATE = 0x2000,NCCF_QUARANTINED = 0x4000,NCCF_RESERVED = 0x8000,
    NCCF_BLUETOOTH_MASK = 0xf0000,NCCF_LAN_MASK = 0xf00000
  } NETCON_CHARACTERISTIC_FLAGS;

  typedef enum tagNETCON_STATUS {
    NCS_DISCONNECTED = 0,NCS_CONNECTING,NCS_CONNECTED,NCS_DISCONNECTING,
    NCS_HARDWARE_NOT_PRESENT,NCS_HARDWARE_DISABLED,NCS_HARDWARE_MALFUNCTION,
    NCS_MEDIA_DISCONNECTED,NCS_AUTHENTICATING,NCS_AUTHENTICATION_SUCCEEDED,
    NCS_AUTHENTICATION_FAILED,NCS_INVALID_ADDRESS,NCS_CREDENTIALS_REQUIRED
  } NETCON_STATUS;

  typedef enum tagNETCON_TYPE {
    NCT_DIRECT_CONNECT = 0,NCT_INBOUND,NCT_INTERNET,NCT_LAN,NCT_PHONE,NCT_TUNNEL,NCT_BRIDGE
  } NETCON_TYPE;

  typedef enum tagNETCON_MEDIATYPE {
    NCM_NONE = 0,NCM_DIRECT,NCM_ISDN,NCM_LAN,NCM_PHONE,NCM_TUNNEL,
    NCM_PPPOE,NCM_BRIDGE,NCM_SHAREDACCESSHOST_LAN,NCM_SHAREDACCESSHOST_RAS
  } NETCON_MEDIATYPE;

  typedef struct tagNETCON_PROPERTIES {
    GUID guidId;
    LPWSTR pszwName;
    LPWSTR pszwDeviceName;
    NETCON_STATUS Status;
    NETCON_MEDIATYPE MediaType;
    DWORD dwCharacter;
    CLSID clsidThisObject;
    CLSID clsidUiObject;
  } NETCON_PROPERTIES;

#define S_OBJECT_NO_LONGER_VALID ((HRESULT)0x00000002)

  EXTERN_C const IID IID_INetConnection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnection : public IUnknown {
  public:
    virtual HRESULT WINAPI Connect(void) = 0;
    virtual HRESULT WINAPI Disconnect(void) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI Duplicate(LPCWSTR pszwDuplicateName,INetConnection **ppCon) = 0;
    virtual HRESULT WINAPI GetProperties(NETCON_PROPERTIES **ppProps) = 0;
    virtual HRESULT WINAPI GetUiObjectClassId(CLSID *pclsid) = 0;
    virtual HRESULT WINAPI Rename(LPCWSTR pszwNewName) = 0;
  };
#else
  typedef struct INetConnectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnection *This);
      ULONG (WINAPI *Release)(INetConnection *This);
      HRESULT (WINAPI *Connect)(INetConnection *This);
      HRESULT (WINAPI *Disconnect)(INetConnection *This);
      HRESULT (WINAPI *Delete)(INetConnection *This);
      HRESULT (WINAPI *Duplicate)(INetConnection *This,LPCWSTR pszwDuplicateName,INetConnection **ppCon);
      HRESULT (WINAPI *GetProperties)(INetConnection *This,NETCON_PROPERTIES **ppProps);
      HRESULT (WINAPI *GetUiObjectClassId)(INetConnection *This,CLSID *pclsid);
      HRESULT (WINAPI *Rename)(INetConnection *This,LPCWSTR pszwNewName);
    END_INTERFACE
  } INetConnectionVtbl;
  struct INetConnection {
    CONST_VTBL struct INetConnectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnection_Release(This) (This)->lpVtbl->Release(This)
#define INetConnection_Connect(This) (This)->lpVtbl->Connect(This)
#define INetConnection_Disconnect(This) (This)->lpVtbl->Disconnect(This)
#define INetConnection_Delete(This) (This)->lpVtbl->Delete(This)
#define INetConnection_Duplicate(This,pszwDuplicateName,ppCon) (This)->lpVtbl->Duplicate(This,pszwDuplicateName,ppCon)
#define INetConnection_GetProperties(This,ppProps) (This)->lpVtbl->GetProperties(This,ppProps)
#define INetConnection_GetUiObjectClassId(This,pclsid) (This)->lpVtbl->GetUiObjectClassId(This,pclsid)
#define INetConnection_Rename(This,pszwNewName) (This)->lpVtbl->Rename(This,pszwNewName)
#endif
#endif
  HRESULT WINAPI INetConnection_Connect_Proxy(INetConnection *This);
  void __RPC_STUB INetConnection_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnection_Disconnect_Proxy(INetConnection *This);
  void __RPC_STUB INetConnection_Disconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnection_Delete_Proxy(INetConnection *This);
  void __RPC_STUB INetConnection_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnection_Duplicate_Proxy(INetConnection *This,LPCWSTR pszwDuplicateName,INetConnection **ppCon);
  void __RPC_STUB INetConnection_Duplicate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnection_GetProperties_Proxy(INetConnection *This,NETCON_PROPERTIES **ppProps);
  void __RPC_STUB INetConnection_GetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnection_GetUiObjectClassId_Proxy(INetConnection *This,CLSID *pclsid);
  void __RPC_STUB INetConnection_GetUiObjectClassId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnection_Rename_Proxy(INetConnection *This,LPCWSTR pszwNewName);
  void __RPC_STUB INetConnection_Rename_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  STDAPI_(VOID) NcFreeNetconProperties(NETCON_PROPERTIES *pProps);
  STDAPI_(WINBOOL) NcIsValidConnectionName(PCWSTR pszwName);

  extern RPC_IF_HANDLE __MIDL_itf_netcon_0120_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netcon_0120_v0_0_s_ifspec;

#ifndef __INetConnectionManager_INTERFACE_DEFINED__
#define __INetConnectionManager_INTERFACE_DEFINED__
  typedef enum tagNETCONMGR_ENUM_FLAGS {
    NCME_DEFAULT = 0
  } NETCONMGR_ENUM_FLAGS;

  EXTERN_C const IID IID_INetConnectionManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnectionManager : public IUnknown {
  public:
    virtual HRESULT WINAPI EnumConnections(NETCONMGR_ENUM_FLAGS Flags,IEnumNetConnection **ppEnum) = 0;
  };
#else
  typedef struct INetConnectionManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnectionManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnectionManager *This);
      ULONG (WINAPI *Release)(INetConnectionManager *This);
      HRESULT (WINAPI *EnumConnections)(INetConnectionManager *This,NETCONMGR_ENUM_FLAGS Flags,IEnumNetConnection **ppEnum);
    END_INTERFACE
  } INetConnectionManagerVtbl;
  struct INetConnectionManager {
    CONST_VTBL struct INetConnectionManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnectionManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnectionManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnectionManager_Release(This) (This)->lpVtbl->Release(This)
#define INetConnectionManager_EnumConnections(This,Flags,ppEnum) (This)->lpVtbl->EnumConnections(This,Flags,ppEnum)
#endif
#endif
  HRESULT WINAPI INetConnectionManager_EnumConnections_Proxy(INetConnectionManager *This,NETCONMGR_ENUM_FLAGS Flags,IEnumNetConnection **ppEnum);
  void __RPC_STUB INetConnectionManager_EnumConnections_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetConnectionManagerEvents_INTERFACE_DEFINED__
#define __INetConnectionManagerEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetConnectionManagerEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnectionManagerEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI RefreshConnections(void) = 0;
    virtual HRESULT WINAPI Enable(void) = 0;
    virtual HRESULT WINAPI Disable(ULONG ulDisableTimeout) = 0;
  };
#else
  typedef struct INetConnectionManagerEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnectionManagerEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnectionManagerEvents *This);
      ULONG (WINAPI *Release)(INetConnectionManagerEvents *This);
      HRESULT (WINAPI *RefreshConnections)(INetConnectionManagerEvents *This);
      HRESULT (WINAPI *Enable)(INetConnectionManagerEvents *This);
      HRESULT (WINAPI *Disable)(INetConnectionManagerEvents *This,ULONG ulDisableTimeout);
    END_INTERFACE
  } INetConnectionManagerEventsVtbl;
  struct INetConnectionManagerEvents {
    CONST_VTBL struct INetConnectionManagerEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnectionManagerEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnectionManagerEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnectionManagerEvents_Release(This) (This)->lpVtbl->Release(This)
#define INetConnectionManagerEvents_RefreshConnections(This) (This)->lpVtbl->RefreshConnections(This)
#define INetConnectionManagerEvents_Enable(This) (This)->lpVtbl->Enable(This)
#define INetConnectionManagerEvents_Disable(This,ulDisableTimeout) (This)->lpVtbl->Disable(This,ulDisableTimeout)
#endif
#endif
  HRESULT WINAPI INetConnectionManagerEvents_RefreshConnections_Proxy(INetConnectionManagerEvents *This);
  void __RPC_STUB INetConnectionManagerEvents_RefreshConnections_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionManagerEvents_Enable_Proxy(INetConnectionManagerEvents *This);
  void __RPC_STUB INetConnectionManagerEvents_Enable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionManagerEvents_Disable_Proxy(INetConnectionManagerEvents *This,ULONG ulDisableTimeout);
  void __RPC_STUB INetConnectionManagerEvents_Disable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetConnectionConnectUi_INTERFACE_DEFINED__
#define __INetConnectionConnectUi_INTERFACE_DEFINED__
  typedef enum tagNETCONUI_CONNECT_FLAGS {
    NCUC_DEFAULT = 0,NCUC_NO_UI = 0x1,NCUC_ENABLE_DISABLE = 0x2
  } NETCONUI_CONNECT_FLAGS;

  EXTERN_C const IID IID_INetConnectionConnectUi;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnectionConnectUi : public IUnknown {
  public:
    virtual HRESULT WINAPI SetConnection(INetConnection *pCon) = 0;
    virtual HRESULT WINAPI Connect(HWND hwndParent,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI Disconnect(HWND hwndParent,DWORD dwFlags) = 0;
  };
#else
  typedef struct INetConnectionConnectUiVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnectionConnectUi *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnectionConnectUi *This);
      ULONG (WINAPI *Release)(INetConnectionConnectUi *This);
      HRESULT (WINAPI *SetConnection)(INetConnectionConnectUi *This,INetConnection *pCon);
      HRESULT (WINAPI *Connect)(INetConnectionConnectUi *This,HWND hwndParent,DWORD dwFlags);
      HRESULT (WINAPI *Disconnect)(INetConnectionConnectUi *This,HWND hwndParent,DWORD dwFlags);
    END_INTERFACE
  } INetConnectionConnectUiVtbl;
  struct INetConnectionConnectUi {
    CONST_VTBL struct INetConnectionConnectUiVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnectionConnectUi_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnectionConnectUi_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnectionConnectUi_Release(This) (This)->lpVtbl->Release(This)
#define INetConnectionConnectUi_SetConnection(This,pCon) (This)->lpVtbl->SetConnection(This,pCon)
#define INetConnectionConnectUi_Connect(This,hwndParent,dwFlags) (This)->lpVtbl->Connect(This,hwndParent,dwFlags)
#define INetConnectionConnectUi_Disconnect(This,hwndParent,dwFlags) (This)->lpVtbl->Disconnect(This,hwndParent,dwFlags)
#endif
#endif
  HRESULT WINAPI INetConnectionConnectUi_SetConnection_Proxy(INetConnectionConnectUi *This,INetConnection *pCon);
  void __RPC_STUB INetConnectionConnectUi_SetConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionConnectUi_Connect_Proxy(INetConnectionConnectUi *This,HWND hwndParent,DWORD dwFlags);
  void __RPC_STUB INetConnectionConnectUi_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionConnectUi_Disconnect_Proxy(INetConnectionConnectUi *This,HWND hwndParent,DWORD dwFlags);
  void __RPC_STUB INetConnectionConnectUi_Disconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetConnectionPropertyUi_INTERFACE_DEFINED__
#define __INetConnectionPropertyUi_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetConnectionPropertyUi;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnectionPropertyUi : public IUnknown {
  public:
    virtual HRESULT WINAPI SetConnection(INetConnection *pCon) = 0;
    virtual HRESULT WINAPI AddPages(HWND hwndParent,LPFNADDPROPSHEETPAGE pfnAddPage,LPARAM lParam) = 0;
  };
#else
  typedef struct INetConnectionPropertyUiVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnectionPropertyUi *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnectionPropertyUi *This);
      ULONG (WINAPI *Release)(INetConnectionPropertyUi *This);
      HRESULT (WINAPI *SetConnection)(INetConnectionPropertyUi *This,INetConnection *pCon);
      HRESULT (WINAPI *AddPages)(INetConnectionPropertyUi *This,HWND hwndParent,LPFNADDPROPSHEETPAGE pfnAddPage,LPARAM lParam);
    END_INTERFACE
  } INetConnectionPropertyUiVtbl;
  struct INetConnectionPropertyUi {
    CONST_VTBL struct INetConnectionPropertyUiVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnectionPropertyUi_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnectionPropertyUi_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnectionPropertyUi_Release(This) (This)->lpVtbl->Release(This)
#define INetConnectionPropertyUi_SetConnection(This,pCon) (This)->lpVtbl->SetConnection(This,pCon)
#define INetConnectionPropertyUi_AddPages(This,hwndParent,pfnAddPage,lParam) (This)->lpVtbl->AddPages(This,hwndParent,pfnAddPage,lParam)
#endif
#endif
  HRESULT WINAPI INetConnectionPropertyUi_SetConnection_Proxy(INetConnectionPropertyUi *This,INetConnection *pCon);
  void __RPC_STUB INetConnectionPropertyUi_SetConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionPropertyUi_AddPages_Proxy(INetConnectionPropertyUi *This,HWND hwndParent,LPFNADDPROPSHEETPAGE pfnAddPage,LPARAM lParam);
  void __RPC_STUB INetConnectionPropertyUi_AddPages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetConnectionPropertyUi2_INTERFACE_DEFINED__
#define __INetConnectionPropertyUi2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetConnectionPropertyUi2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnectionPropertyUi2 : public INetConnectionPropertyUi {
  public:
    virtual HRESULT WINAPI GetIcon(DWORD dwSize,HICON *phIcon) = 0;
  };
#else
  typedef struct INetConnectionPropertyUi2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnectionPropertyUi2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnectionPropertyUi2 *This);
      ULONG (WINAPI *Release)(INetConnectionPropertyUi2 *This);
      HRESULT (WINAPI *SetConnection)(INetConnectionPropertyUi2 *This,INetConnection *pCon);
      HRESULT (WINAPI *AddPages)(INetConnectionPropertyUi2 *This,HWND hwndParent,LPFNADDPROPSHEETPAGE pfnAddPage,LPARAM lParam);
      HRESULT (WINAPI *GetIcon)(INetConnectionPropertyUi2 *This,DWORD dwSize,HICON *phIcon);
    END_INTERFACE
  } INetConnectionPropertyUi2Vtbl;
  struct INetConnectionPropertyUi2 {
    CONST_VTBL struct INetConnectionPropertyUi2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnectionPropertyUi2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnectionPropertyUi2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnectionPropertyUi2_Release(This) (This)->lpVtbl->Release(This)
#define INetConnectionPropertyUi2_SetConnection(This,pCon) (This)->lpVtbl->SetConnection(This,pCon)
#define INetConnectionPropertyUi2_AddPages(This,hwndParent,pfnAddPage,lParam) (This)->lpVtbl->AddPages(This,hwndParent,pfnAddPage,lParam)
#define INetConnectionPropertyUi2_GetIcon(This,dwSize,phIcon) (This)->lpVtbl->GetIcon(This,dwSize,phIcon)
#endif
#endif
  HRESULT WINAPI INetConnectionPropertyUi2_GetIcon_Proxy(INetConnectionPropertyUi2 *This,DWORD dwSize,HICON *phIcon);
  void __RPC_STUB INetConnectionPropertyUi2_GetIcon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetConnectionCommonUi_INTERFACE_DEFINED__
#define __INetConnectionCommonUi_INTERFACE_DEFINED__
  typedef enum tagNETCON_CHOOSEFLAGS {
    NCCHF_CONNECT = 0x1,NCCHF_CAPTION = 0x2,NCCHF_OKBTTNTEXT = 0x4,NCCHF_DISABLENEW = 0x8,NCCHF_AUTOSELECT = 0x10
  } NETCON_CHOOSEFLAGS;

  typedef enum tagNETCON_CHOOSETYPE {
    NCCHT_DIRECT_CONNECT = 0x1,NCCHT_LAN = 0x2,NCCHT_PHONE = 0x4,NCCHT_TUNNEL = 0x8,NCCHT_ISDN = 0x10,NCCHT_ALL = 0x1f
  } NETCON_CHOOSETYPE;

  typedef struct tagNETCON_CHOOSECONN {
    DWORD lStructSize;
    HWND hwndParent;
    DWORD dwFlags;
    DWORD dwTypeMask;
    LPCWSTR lpstrCaption;
    LPCWSTR lpstrOkBttnText;
  } NETCON_CHOOSECONN;

  EXTERN_C const IID IID_INetConnectionCommonUi;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnectionCommonUi : public IUnknown {
  public:
    virtual HRESULT WINAPI ChooseConnection(NETCON_CHOOSECONN *pChooseConn,INetConnection **ppCon) = 0;
    virtual HRESULT WINAPI ShowConnectionProperties(HWND hwndParent,INetConnection *pCon) = 0;
    virtual HRESULT WINAPI StartNewConnectionWizard(HWND hwndParent,INetConnection **ppCon) = 0;
  };
#else
  typedef struct INetConnectionCommonUiVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnectionCommonUi *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnectionCommonUi *This);
      ULONG (WINAPI *Release)(INetConnectionCommonUi *This);
      HRESULT (WINAPI *ChooseConnection)(INetConnectionCommonUi *This,NETCON_CHOOSECONN *pChooseConn,INetConnection **ppCon);
      HRESULT (WINAPI *ShowConnectionProperties)(INetConnectionCommonUi *This,HWND hwndParent,INetConnection *pCon);
      HRESULT (WINAPI *StartNewConnectionWizard)(INetConnectionCommonUi *This,HWND hwndParent,INetConnection **ppCon);
    END_INTERFACE
  } INetConnectionCommonUiVtbl;
  struct INetConnectionCommonUi {
    CONST_VTBL struct INetConnectionCommonUiVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnectionCommonUi_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnectionCommonUi_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnectionCommonUi_Release(This) (This)->lpVtbl->Release(This)
#define INetConnectionCommonUi_ChooseConnection(This,pChooseConn,ppCon) (This)->lpVtbl->ChooseConnection(This,pChooseConn,ppCon)
#define INetConnectionCommonUi_ShowConnectionProperties(This,hwndParent,pCon) (This)->lpVtbl->ShowConnectionProperties(This,hwndParent,pCon)
#define INetConnectionCommonUi_StartNewConnectionWizard(This,hwndParent,ppCon) (This)->lpVtbl->StartNewConnectionWizard(This,hwndParent,ppCon)
#endif
#endif
  HRESULT WINAPI INetConnectionCommonUi_ChooseConnection_Proxy(INetConnectionCommonUi *This,NETCON_CHOOSECONN *pChooseConn,INetConnection **ppCon);
  void __RPC_STUB INetConnectionCommonUi_ChooseConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionCommonUi_ShowConnectionProperties_Proxy(INetConnectionCommonUi *This,HWND hwndParent,INetConnection *pCon);
  void __RPC_STUB INetConnectionCommonUi_ShowConnectionProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionCommonUi_StartNewConnectionWizard_Proxy(INetConnectionCommonUi *This,HWND hwndParent,INetConnection **ppCon);
  void __RPC_STUB INetConnectionCommonUi_StartNewConnectionWizard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumNetSharingPortMapping_INTERFACE_DEFINED__
#define __IEnumNetSharingPortMapping_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumNetSharingPortMapping;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumNetSharingPortMapping : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,VARIANT *rgVar,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumNetSharingPortMapping **ppenum) = 0;
  };
#else
  typedef struct IEnumNetSharingPortMappingVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumNetSharingPortMapping *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumNetSharingPortMapping *This);
      ULONG (WINAPI *Release)(IEnumNetSharingPortMapping *This);
      HRESULT (WINAPI *Next)(IEnumNetSharingPortMapping *This,ULONG celt,VARIANT *rgVar,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumNetSharingPortMapping *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumNetSharingPortMapping *This);
      HRESULT (WINAPI *Clone)(IEnumNetSharingPortMapping *This,IEnumNetSharingPortMapping **ppenum);
    END_INTERFACE
  } IEnumNetSharingPortMappingVtbl;
  struct IEnumNetSharingPortMapping {
    CONST_VTBL struct IEnumNetSharingPortMappingVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumNetSharingPortMapping_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumNetSharingPortMapping_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumNetSharingPortMapping_Release(This) (This)->lpVtbl->Release(This)
#define IEnumNetSharingPortMapping_Next(This,celt,rgVar,pceltFetched) (This)->lpVtbl->Next(This,celt,rgVar,pceltFetched)
#define IEnumNetSharingPortMapping_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumNetSharingPortMapping_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumNetSharingPortMapping_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumNetSharingPortMapping_Next_Proxy(IEnumNetSharingPortMapping *This,ULONG celt,VARIANT *rgVar,ULONG *pceltFetched);
  void __RPC_STUB IEnumNetSharingPortMapping_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPortMapping_Skip_Proxy(IEnumNetSharingPortMapping *This,ULONG celt);
  void __RPC_STUB IEnumNetSharingPortMapping_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPortMapping_Reset_Proxy(IEnumNetSharingPortMapping *This);
  void __RPC_STUB IEnumNetSharingPortMapping_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPortMapping_Clone_Proxy(IEnumNetSharingPortMapping *This,IEnumNetSharingPortMapping **ppenum);
  void __RPC_STUB IEnumNetSharingPortMapping_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingPortMappingProps_INTERFACE_DEFINED__
#define __INetSharingPortMappingProps_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetSharingPortMappingProps;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingPortMappingProps : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_IPProtocol(UCHAR *pucIPProt) = 0;
    virtual HRESULT WINAPI get_ExternalPort(__LONG32 *pusPort) = 0;
    virtual HRESULT WINAPI get_InternalPort(__LONG32 *pusPort) = 0;
    virtual HRESULT WINAPI get_Options(__LONG32 *pdwOptions) = 0;
    virtual HRESULT WINAPI get_TargetName(BSTR *pbstrTargetName) = 0;
    virtual HRESULT WINAPI get_TargetIPAddress(BSTR *pbstrTargetIPAddress) = 0;
    virtual HRESULT WINAPI get_Enabled(VARIANT_BOOL *pbool) = 0;
  };
#else
  typedef struct INetSharingPortMappingPropsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingPortMappingProps *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingPortMappingProps *This);
      ULONG (WINAPI *Release)(INetSharingPortMappingProps *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingPortMappingProps *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingPortMappingProps *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingPortMappingProps *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingPortMappingProps *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(INetSharingPortMappingProps *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_IPProtocol)(INetSharingPortMappingProps *This,UCHAR *pucIPProt);
      HRESULT (WINAPI *get_ExternalPort)(INetSharingPortMappingProps *This,__LONG32 *pusPort);
      HRESULT (WINAPI *get_InternalPort)(INetSharingPortMappingProps *This,__LONG32 *pusPort);
      HRESULT (WINAPI *get_Options)(INetSharingPortMappingProps *This,__LONG32 *pdwOptions);
      HRESULT (WINAPI *get_TargetName)(INetSharingPortMappingProps *This,BSTR *pbstrTargetName);
      HRESULT (WINAPI *get_TargetIPAddress)(INetSharingPortMappingProps *This,BSTR *pbstrTargetIPAddress);
      HRESULT (WINAPI *get_Enabled)(INetSharingPortMappingProps *This,VARIANT_BOOL *pbool);
    END_INTERFACE
  } INetSharingPortMappingPropsVtbl;
  struct INetSharingPortMappingProps {
    CONST_VTBL struct INetSharingPortMappingPropsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingPortMappingProps_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingPortMappingProps_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingPortMappingProps_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingPortMappingProps_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingPortMappingProps_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingPortMappingProps_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingPortMappingProps_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingPortMappingProps_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define INetSharingPortMappingProps_get_IPProtocol(This,pucIPProt) (This)->lpVtbl->get_IPProtocol(This,pucIPProt)
#define INetSharingPortMappingProps_get_ExternalPort(This,pusPort) (This)->lpVtbl->get_ExternalPort(This,pusPort)
#define INetSharingPortMappingProps_get_InternalPort(This,pusPort) (This)->lpVtbl->get_InternalPort(This,pusPort)
#define INetSharingPortMappingProps_get_Options(This,pdwOptions) (This)->lpVtbl->get_Options(This,pdwOptions)
#define INetSharingPortMappingProps_get_TargetName(This,pbstrTargetName) (This)->lpVtbl->get_TargetName(This,pbstrTargetName)
#define INetSharingPortMappingProps_get_TargetIPAddress(This,pbstrTargetIPAddress) (This)->lpVtbl->get_TargetIPAddress(This,pbstrTargetIPAddress)
#define INetSharingPortMappingProps_get_Enabled(This,pbool) (This)->lpVtbl->get_Enabled(This,pbool)
#endif
#endif
  HRESULT WINAPI INetSharingPortMappingProps_get_Name_Proxy(INetSharingPortMappingProps *This,BSTR *pbstrName);
  void __RPC_STUB INetSharingPortMappingProps_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingProps_get_IPProtocol_Proxy(INetSharingPortMappingProps *This,UCHAR *pucIPProt);
  void __RPC_STUB INetSharingPortMappingProps_get_IPProtocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingProps_get_ExternalPort_Proxy(INetSharingPortMappingProps *This,__LONG32 *pusPort);
  void __RPC_STUB INetSharingPortMappingProps_get_ExternalPort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingProps_get_InternalPort_Proxy(INetSharingPortMappingProps *This,__LONG32 *pusPort);
  void __RPC_STUB INetSharingPortMappingProps_get_InternalPort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingProps_get_Options_Proxy(INetSharingPortMappingProps *This,__LONG32 *pdwOptions);
  void __RPC_STUB INetSharingPortMappingProps_get_Options_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingProps_get_TargetName_Proxy(INetSharingPortMappingProps *This,BSTR *pbstrTargetName);
  void __RPC_STUB INetSharingPortMappingProps_get_TargetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingProps_get_TargetIPAddress_Proxy(INetSharingPortMappingProps *This,BSTR *pbstrTargetIPAddress);
  void __RPC_STUB INetSharingPortMappingProps_get_TargetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingProps_get_Enabled_Proxy(INetSharingPortMappingProps *This,VARIANT_BOOL *pbool);
  void __RPC_STUB INetSharingPortMappingProps_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingPortMapping_INTERFACE_DEFINED__
#define __INetSharingPortMapping_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetSharingPortMapping;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingPortMapping : public IDispatch {
  public:
    virtual HRESULT WINAPI Disable(void) = 0;
    virtual HRESULT WINAPI Enable(void) = 0;
    virtual HRESULT WINAPI get_Properties(INetSharingPortMappingProps **ppNSPMP) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
  };
#else
  typedef struct INetSharingPortMappingVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingPortMapping *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingPortMapping *This);
      ULONG (WINAPI *Release)(INetSharingPortMapping *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingPortMapping *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingPortMapping *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingPortMapping *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingPortMapping *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Disable)(INetSharingPortMapping *This);
      HRESULT (WINAPI *Enable)(INetSharingPortMapping *This);
      HRESULT (WINAPI *get_Properties)(INetSharingPortMapping *This,INetSharingPortMappingProps **ppNSPMP);
      HRESULT (WINAPI *Delete)(INetSharingPortMapping *This);
    END_INTERFACE
  } INetSharingPortMappingVtbl;
  struct INetSharingPortMapping {
    CONST_VTBL struct INetSharingPortMappingVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingPortMapping_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingPortMapping_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingPortMapping_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingPortMapping_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingPortMapping_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingPortMapping_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingPortMapping_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingPortMapping_Disable(This) (This)->lpVtbl->Disable(This)
#define INetSharingPortMapping_Enable(This) (This)->lpVtbl->Enable(This)
#define INetSharingPortMapping_get_Properties(This,ppNSPMP) (This)->lpVtbl->get_Properties(This,ppNSPMP)
#define INetSharingPortMapping_Delete(This) (This)->lpVtbl->Delete(This)
#endif
#endif
  HRESULT WINAPI INetSharingPortMapping_Disable_Proxy(INetSharingPortMapping *This);
  void __RPC_STUB INetSharingPortMapping_Disable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMapping_Enable_Proxy(INetSharingPortMapping *This);
  void __RPC_STUB INetSharingPortMapping_Enable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMapping_get_Properties_Proxy(INetSharingPortMapping *This,INetSharingPortMappingProps **ppNSPMP);
  void __RPC_STUB INetSharingPortMapping_get_Properties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMapping_Delete_Proxy(INetSharingPortMapping *This);
  void __RPC_STUB INetSharingPortMapping_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumNetSharingEveryConnection_INTERFACE_DEFINED__
#define __IEnumNetSharingEveryConnection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumNetSharingEveryConnection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumNetSharingEveryConnection : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,VARIANT *rgVar,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumNetSharingEveryConnection **ppenum) = 0;
  };
#else
  typedef struct IEnumNetSharingEveryConnectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumNetSharingEveryConnection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumNetSharingEveryConnection *This);
      ULONG (WINAPI *Release)(IEnumNetSharingEveryConnection *This);
      HRESULT (WINAPI *Next)(IEnumNetSharingEveryConnection *This,ULONG celt,VARIANT *rgVar,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumNetSharingEveryConnection *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumNetSharingEveryConnection *This);
      HRESULT (WINAPI *Clone)(IEnumNetSharingEveryConnection *This,IEnumNetSharingEveryConnection **ppenum);
    END_INTERFACE
  } IEnumNetSharingEveryConnectionVtbl;
  struct IEnumNetSharingEveryConnection {
    CONST_VTBL struct IEnumNetSharingEveryConnectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumNetSharingEveryConnection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumNetSharingEveryConnection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumNetSharingEveryConnection_Release(This) (This)->lpVtbl->Release(This)
#define IEnumNetSharingEveryConnection_Next(This,celt,rgVar,pceltFetched) (This)->lpVtbl->Next(This,celt,rgVar,pceltFetched)
#define IEnumNetSharingEveryConnection_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumNetSharingEveryConnection_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumNetSharingEveryConnection_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumNetSharingEveryConnection_Next_Proxy(IEnumNetSharingEveryConnection *This,ULONG celt,VARIANT *rgVar,ULONG *pceltFetched);
  void __RPC_STUB IEnumNetSharingEveryConnection_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingEveryConnection_Skip_Proxy(IEnumNetSharingEveryConnection *This,ULONG celt);
  void __RPC_STUB IEnumNetSharingEveryConnection_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingEveryConnection_Reset_Proxy(IEnumNetSharingEveryConnection *This);
  void __RPC_STUB IEnumNetSharingEveryConnection_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingEveryConnection_Clone_Proxy(IEnumNetSharingEveryConnection *This,IEnumNetSharingEveryConnection **ppenum);
  void __RPC_STUB IEnumNetSharingEveryConnection_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumNetSharingPublicConnection_INTERFACE_DEFINED__
#define __IEnumNetSharingPublicConnection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumNetSharingPublicConnection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumNetSharingPublicConnection : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,VARIANT *rgVar,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumNetSharingPublicConnection **ppenum) = 0;
  };
#else
  typedef struct IEnumNetSharingPublicConnectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumNetSharingPublicConnection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumNetSharingPublicConnection *This);
      ULONG (WINAPI *Release)(IEnumNetSharingPublicConnection *This);
      HRESULT (WINAPI *Next)(IEnumNetSharingPublicConnection *This,ULONG celt,VARIANT *rgVar,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumNetSharingPublicConnection *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumNetSharingPublicConnection *This);
      HRESULT (WINAPI *Clone)(IEnumNetSharingPublicConnection *This,IEnumNetSharingPublicConnection **ppenum);
    END_INTERFACE
  } IEnumNetSharingPublicConnectionVtbl;
  struct IEnumNetSharingPublicConnection {
    CONST_VTBL struct IEnumNetSharingPublicConnectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumNetSharingPublicConnection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumNetSharingPublicConnection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumNetSharingPublicConnection_Release(This) (This)->lpVtbl->Release(This)
#define IEnumNetSharingPublicConnection_Next(This,celt,rgVar,pceltFetched) (This)->lpVtbl->Next(This,celt,rgVar,pceltFetched)
#define IEnumNetSharingPublicConnection_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumNetSharingPublicConnection_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumNetSharingPublicConnection_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumNetSharingPublicConnection_Next_Proxy(IEnumNetSharingPublicConnection *This,ULONG celt,VARIANT *rgVar,ULONG *pceltFetched);
  void __RPC_STUB IEnumNetSharingPublicConnection_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPublicConnection_Skip_Proxy(IEnumNetSharingPublicConnection *This,ULONG celt);
  void __RPC_STUB IEnumNetSharingPublicConnection_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPublicConnection_Reset_Proxy(IEnumNetSharingPublicConnection *This);
  void __RPC_STUB IEnumNetSharingPublicConnection_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPublicConnection_Clone_Proxy(IEnumNetSharingPublicConnection *This,IEnumNetSharingPublicConnection **ppenum);
  void __RPC_STUB IEnumNetSharingPublicConnection_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumNetSharingPrivateConnection_INTERFACE_DEFINED__
#define __IEnumNetSharingPrivateConnection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumNetSharingPrivateConnection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumNetSharingPrivateConnection : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,VARIANT *rgVar,ULONG *pCeltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumNetSharingPrivateConnection **ppenum) = 0;
  };
#else
  typedef struct IEnumNetSharingPrivateConnectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumNetSharingPrivateConnection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumNetSharingPrivateConnection *This);
      ULONG (WINAPI *Release)(IEnumNetSharingPrivateConnection *This);
      HRESULT (WINAPI *Next)(IEnumNetSharingPrivateConnection *This,ULONG celt,VARIANT *rgVar,ULONG *pCeltFetched);
      HRESULT (WINAPI *Skip)(IEnumNetSharingPrivateConnection *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumNetSharingPrivateConnection *This);
      HRESULT (WINAPI *Clone)(IEnumNetSharingPrivateConnection *This,IEnumNetSharingPrivateConnection **ppenum);
    END_INTERFACE
  } IEnumNetSharingPrivateConnectionVtbl;
  struct IEnumNetSharingPrivateConnection {
    CONST_VTBL struct IEnumNetSharingPrivateConnectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumNetSharingPrivateConnection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumNetSharingPrivateConnection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumNetSharingPrivateConnection_Release(This) (This)->lpVtbl->Release(This)
#define IEnumNetSharingPrivateConnection_Next(This,celt,rgVar,pCeltFetched) (This)->lpVtbl->Next(This,celt,rgVar,pCeltFetched)
#define IEnumNetSharingPrivateConnection_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumNetSharingPrivateConnection_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumNetSharingPrivateConnection_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumNetSharingPrivateConnection_Next_Proxy(IEnumNetSharingPrivateConnection *This,ULONG celt,VARIANT *rgVar,ULONG *pCeltFetched);
  void __RPC_STUB IEnumNetSharingPrivateConnection_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPrivateConnection_Skip_Proxy(IEnumNetSharingPrivateConnection *This,ULONG celt);
  void __RPC_STUB IEnumNetSharingPrivateConnection_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPrivateConnection_Reset_Proxy(IEnumNetSharingPrivateConnection *This);
  void __RPC_STUB IEnumNetSharingPrivateConnection_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNetSharingPrivateConnection_Clone_Proxy(IEnumNetSharingPrivateConnection *This,IEnumNetSharingPrivateConnection **ppenum);
  void __RPC_STUB IEnumNetSharingPrivateConnection_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingPortMappingCollection_INTERFACE_DEFINED__
#define __INetSharingPortMappingCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetSharingPortMappingCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingPortMappingCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **pVal) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
  };
#else
  typedef struct INetSharingPortMappingCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingPortMappingCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingPortMappingCollection *This);
      ULONG (WINAPI *Release)(INetSharingPortMappingCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingPortMappingCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingPortMappingCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingPortMappingCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingPortMappingCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(INetSharingPortMappingCollection *This,IUnknown **pVal);
      HRESULT (WINAPI *get_Count)(INetSharingPortMappingCollection *This,__LONG32 *pVal);
    END_INTERFACE
  } INetSharingPortMappingCollectionVtbl;
  struct INetSharingPortMappingCollection {
    CONST_VTBL struct INetSharingPortMappingCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingPortMappingCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingPortMappingCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingPortMappingCollection_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingPortMappingCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingPortMappingCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingPortMappingCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingPortMappingCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingPortMappingCollection_get__NewEnum(This,pVal) (This)->lpVtbl->get__NewEnum(This,pVal)
#define INetSharingPortMappingCollection_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#endif
#endif
  HRESULT WINAPI INetSharingPortMappingCollection_get__NewEnum_Proxy(INetSharingPortMappingCollection *This,IUnknown **pVal);
  void __RPC_STUB INetSharingPortMappingCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPortMappingCollection_get_Count_Proxy(INetSharingPortMappingCollection *This,__LONG32 *pVal);
  void __RPC_STUB INetSharingPortMappingCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_netcon_0133_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netcon_0133_v0_0_s_ifspec;

#ifndef __INetConnectionProps_INTERFACE_DEFINED__
#define __INetConnectionProps_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetConnectionProps;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetConnectionProps : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Guid(BSTR *pbstrGuid) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_DeviceName(BSTR *pbstrDeviceName) = 0;
    virtual HRESULT WINAPI get_Status(NETCON_STATUS *pStatus) = 0;
    virtual HRESULT WINAPI get_MediaType(NETCON_MEDIATYPE *pMediaType) = 0;
    virtual HRESULT WINAPI get_Characteristics(DWORD *pdwFlags) = 0;
  };
#else
  typedef struct INetConnectionPropsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetConnectionProps *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetConnectionProps *This);
      ULONG (WINAPI *Release)(INetConnectionProps *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetConnectionProps *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetConnectionProps *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetConnectionProps *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetConnectionProps *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Guid)(INetConnectionProps *This,BSTR *pbstrGuid);
      HRESULT (WINAPI *get_Name)(INetConnectionProps *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_DeviceName)(INetConnectionProps *This,BSTR *pbstrDeviceName);
      HRESULT (WINAPI *get_Status)(INetConnectionProps *This,NETCON_STATUS *pStatus);
      HRESULT (WINAPI *get_MediaType)(INetConnectionProps *This,NETCON_MEDIATYPE *pMediaType);
      HRESULT (WINAPI *get_Characteristics)(INetConnectionProps *This,DWORD *pdwFlags);
    END_INTERFACE
  } INetConnectionPropsVtbl;
  struct INetConnectionProps {
    CONST_VTBL struct INetConnectionPropsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetConnectionProps_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetConnectionProps_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetConnectionProps_Release(This) (This)->lpVtbl->Release(This)
#define INetConnectionProps_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetConnectionProps_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetConnectionProps_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetConnectionProps_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetConnectionProps_get_Guid(This,pbstrGuid) (This)->lpVtbl->get_Guid(This,pbstrGuid)
#define INetConnectionProps_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define INetConnectionProps_get_DeviceName(This,pbstrDeviceName) (This)->lpVtbl->get_DeviceName(This,pbstrDeviceName)
#define INetConnectionProps_get_Status(This,pStatus) (This)->lpVtbl->get_Status(This,pStatus)
#define INetConnectionProps_get_MediaType(This,pMediaType) (This)->lpVtbl->get_MediaType(This,pMediaType)
#define INetConnectionProps_get_Characteristics(This,pdwFlags) (This)->lpVtbl->get_Characteristics(This,pdwFlags)
#endif
#endif
  HRESULT WINAPI INetConnectionProps_get_Guid_Proxy(INetConnectionProps *This,BSTR *pbstrGuid);
  void __RPC_STUB INetConnectionProps_get_Guid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionProps_get_Name_Proxy(INetConnectionProps *This,BSTR *pbstrName);
  void __RPC_STUB INetConnectionProps_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionProps_get_DeviceName_Proxy(INetConnectionProps *This,BSTR *pbstrDeviceName);
  void __RPC_STUB INetConnectionProps_get_DeviceName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionProps_get_Status_Proxy(INetConnectionProps *This,NETCON_STATUS *pStatus);
  void __RPC_STUB INetConnectionProps_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionProps_get_MediaType_Proxy(INetConnectionProps *This,NETCON_MEDIATYPE *pMediaType);
  void __RPC_STUB INetConnectionProps_get_MediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetConnectionProps_get_Characteristics_Proxy(INetConnectionProps *This,DWORD *pdwFlags);
  void __RPC_STUB INetConnectionProps_get_Characteristics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingConfiguration_INTERFACE_DEFINED__
#define __INetSharingConfiguration_INTERFACE_DEFINED__
  typedef enum tagSHARINGCONNECTIONTYPE {
    ICSSHARINGTYPE_PUBLIC = 0,ICSSHARINGTYPE_PRIVATE = ICSSHARINGTYPE_PUBLIC + 1
  } SHARINGCONNECTIONTYPE;
  typedef enum tagSHARINGCONNECTIONTYPE *LPSHARINGCONNECTIONTYPE;

  typedef enum tagSHARINGCONNECTION_ENUM_FLAGS {
    ICSSC_DEFAULT = 0,ICSSC_ENABLED = ICSSC_DEFAULT + 1
  } SHARINGCONNECTION_ENUM_FLAGS;

  typedef enum tagICS_TARGETTYPE {
    ICSTT_NAME = 0,ICSTT_IPADDRESS = ICSTT_NAME + 1
  } ICS_TARGETTYPE;

  EXTERN_C const IID IID_INetSharingConfiguration;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingConfiguration : public IDispatch {
  public:
    virtual HRESULT WINAPI get_SharingEnabled(VARIANT_BOOL *pbEnabled) = 0;
    virtual HRESULT WINAPI get_SharingConnectionType(SHARINGCONNECTIONTYPE *pType) = 0;
    virtual HRESULT WINAPI DisableSharing(void) = 0;
    virtual HRESULT WINAPI EnableSharing(SHARINGCONNECTIONTYPE Type) = 0;
    virtual HRESULT WINAPI get_InternetFirewallEnabled(VARIANT_BOOL *pbEnabled) = 0;
    virtual HRESULT WINAPI DisableInternetFirewall(void) = 0;
    virtual HRESULT WINAPI EnableInternetFirewall(void) = 0;
    virtual HRESULT WINAPI get_EnumPortMappings(SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPortMappingCollection **ppColl) = 0;
    virtual HRESULT WINAPI AddPortMapping(BSTR bstrName,UCHAR ucIPProtocol,USHORT usExternalPort,USHORT usInternalPort,DWORD dwOptions,BSTR bstrTargetNameOrIPAddress,ICS_TARGETTYPE eTargetType,INetSharingPortMapping **ppMapping) = 0;
    virtual HRESULT WINAPI RemovePortMapping(INetSharingPortMapping *pMapping) = 0;
  };
#else
  typedef struct INetSharingConfigurationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingConfiguration *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingConfiguration *This);
      ULONG (WINAPI *Release)(INetSharingConfiguration *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingConfiguration *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingConfiguration *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingConfiguration *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingConfiguration *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SharingEnabled)(INetSharingConfiguration *This,VARIANT_BOOL *pbEnabled);
      HRESULT (WINAPI *get_SharingConnectionType)(INetSharingConfiguration *This,SHARINGCONNECTIONTYPE *pType);
      HRESULT (WINAPI *DisableSharing)(INetSharingConfiguration *This);
      HRESULT (WINAPI *EnableSharing)(INetSharingConfiguration *This,SHARINGCONNECTIONTYPE Type);
      HRESULT (WINAPI *get_InternetFirewallEnabled)(INetSharingConfiguration *This,VARIANT_BOOL *pbEnabled);
      HRESULT (WINAPI *DisableInternetFirewall)(INetSharingConfiguration *This);
      HRESULT (WINAPI *EnableInternetFirewall)(INetSharingConfiguration *This);
      HRESULT (WINAPI *get_EnumPortMappings)(INetSharingConfiguration *This,SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPortMappingCollection **ppColl);
      HRESULT (WINAPI *AddPortMapping)(INetSharingConfiguration *This,BSTR bstrName,UCHAR ucIPProtocol,USHORT usExternalPort,USHORT usInternalPort,DWORD dwOptions,BSTR bstrTargetNameOrIPAddress,ICS_TARGETTYPE eTargetType,INetSharingPortMapping **ppMapping);
      HRESULT (WINAPI *RemovePortMapping)(INetSharingConfiguration *This,INetSharingPortMapping *pMapping);
    END_INTERFACE
  } INetSharingConfigurationVtbl;
  struct INetSharingConfiguration {
    CONST_VTBL struct INetSharingConfigurationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingConfiguration_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingConfiguration_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingConfiguration_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingConfiguration_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingConfiguration_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingConfiguration_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingConfiguration_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingConfiguration_get_SharingEnabled(This,pbEnabled) (This)->lpVtbl->get_SharingEnabled(This,pbEnabled)
#define INetSharingConfiguration_get_SharingConnectionType(This,pType) (This)->lpVtbl->get_SharingConnectionType(This,pType)
#define INetSharingConfiguration_DisableSharing(This) (This)->lpVtbl->DisableSharing(This)
#define INetSharingConfiguration_EnableSharing(This,Type) (This)->lpVtbl->EnableSharing(This,Type)
#define INetSharingConfiguration_get_InternetFirewallEnabled(This,pbEnabled) (This)->lpVtbl->get_InternetFirewallEnabled(This,pbEnabled)
#define INetSharingConfiguration_DisableInternetFirewall(This) (This)->lpVtbl->DisableInternetFirewall(This)
#define INetSharingConfiguration_EnableInternetFirewall(This) (This)->lpVtbl->EnableInternetFirewall(This)
#define INetSharingConfiguration_get_EnumPortMappings(This,Flags,ppColl) (This)->lpVtbl->get_EnumPortMappings(This,Flags,ppColl)
#define INetSharingConfiguration_AddPortMapping(This,bstrName,ucIPProtocol,usExternalPort,usInternalPort,dwOptions,bstrTargetNameOrIPAddress,eTargetType,ppMapping) (This)->lpVtbl->AddPortMapping(This,bstrName,ucIPProtocol,usExternalPort,usInternalPort,dwOptions,bstrTargetNameOrIPAddress,eTargetType,ppMapping)
#define INetSharingConfiguration_RemovePortMapping(This,pMapping) (This)->lpVtbl->RemovePortMapping(This,pMapping)
#endif
#endif
  HRESULT WINAPI INetSharingConfiguration_get_SharingEnabled_Proxy(INetSharingConfiguration *This,VARIANT_BOOL *pbEnabled);
  void __RPC_STUB INetSharingConfiguration_get_SharingEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_get_SharingConnectionType_Proxy(INetSharingConfiguration *This,SHARINGCONNECTIONTYPE *pType);
  void __RPC_STUB INetSharingConfiguration_get_SharingConnectionType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_DisableSharing_Proxy(INetSharingConfiguration *This);
  void __RPC_STUB INetSharingConfiguration_DisableSharing_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_EnableSharing_Proxy(INetSharingConfiguration *This,SHARINGCONNECTIONTYPE Type);
  void __RPC_STUB INetSharingConfiguration_EnableSharing_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_get_InternetFirewallEnabled_Proxy(INetSharingConfiguration *This,VARIANT_BOOL *pbEnabled);
  void __RPC_STUB INetSharingConfiguration_get_InternetFirewallEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_DisableInternetFirewall_Proxy(INetSharingConfiguration *This);
  void __RPC_STUB INetSharingConfiguration_DisableInternetFirewall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_EnableInternetFirewall_Proxy(INetSharingConfiguration *This);
  void __RPC_STUB INetSharingConfiguration_EnableInternetFirewall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_get_EnumPortMappings_Proxy(INetSharingConfiguration *This,SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPortMappingCollection **ppColl);
  void __RPC_STUB INetSharingConfiguration_get_EnumPortMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_AddPortMapping_Proxy(INetSharingConfiguration *This,BSTR bstrName,UCHAR ucIPProtocol,USHORT usExternalPort,USHORT usInternalPort,DWORD dwOptions,BSTR bstrTargetNameOrIPAddress,ICS_TARGETTYPE eTargetType,INetSharingPortMapping **ppMapping);
  void __RPC_STUB INetSharingConfiguration_AddPortMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingConfiguration_RemovePortMapping_Proxy(INetSharingConfiguration *This,INetSharingPortMapping *pMapping);
  void __RPC_STUB INetSharingConfiguration_RemovePortMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingEveryConnectionCollection_INTERFACE_DEFINED__
#define __INetSharingEveryConnectionCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetSharingEveryConnectionCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingEveryConnectionCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **pVal) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
  };
#else
  typedef struct INetSharingEveryConnectionCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingEveryConnectionCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingEveryConnectionCollection *This);
      ULONG (WINAPI *Release)(INetSharingEveryConnectionCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingEveryConnectionCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingEveryConnectionCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingEveryConnectionCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingEveryConnectionCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(INetSharingEveryConnectionCollection *This,IUnknown **pVal);
      HRESULT (WINAPI *get_Count)(INetSharingEveryConnectionCollection *This,__LONG32 *pVal);
    END_INTERFACE
  } INetSharingEveryConnectionCollectionVtbl;
  struct INetSharingEveryConnectionCollection {
    CONST_VTBL struct INetSharingEveryConnectionCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingEveryConnectionCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingEveryConnectionCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingEveryConnectionCollection_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingEveryConnectionCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingEveryConnectionCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingEveryConnectionCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingEveryConnectionCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingEveryConnectionCollection_get__NewEnum(This,pVal) (This)->lpVtbl->get__NewEnum(This,pVal)
#define INetSharingEveryConnectionCollection_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#endif
#endif
  HRESULT WINAPI INetSharingEveryConnectionCollection_get__NewEnum_Proxy(INetSharingEveryConnectionCollection *This,IUnknown **pVal);
  void __RPC_STUB INetSharingEveryConnectionCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingEveryConnectionCollection_get_Count_Proxy(INetSharingEveryConnectionCollection *This,__LONG32 *pVal);
  void __RPC_STUB INetSharingEveryConnectionCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingPublicConnectionCollection_INTERFACE_DEFINED__
#define __INetSharingPublicConnectionCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetSharingPublicConnectionCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingPublicConnectionCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **pVal) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
  };
#else
  typedef struct INetSharingPublicConnectionCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingPublicConnectionCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingPublicConnectionCollection *This);
      ULONG (WINAPI *Release)(INetSharingPublicConnectionCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingPublicConnectionCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingPublicConnectionCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingPublicConnectionCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingPublicConnectionCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(INetSharingPublicConnectionCollection *This,IUnknown **pVal);
      HRESULT (WINAPI *get_Count)(INetSharingPublicConnectionCollection *This,__LONG32 *pVal);
    END_INTERFACE
  } INetSharingPublicConnectionCollectionVtbl;
  struct INetSharingPublicConnectionCollection {
    CONST_VTBL struct INetSharingPublicConnectionCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingPublicConnectionCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingPublicConnectionCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingPublicConnectionCollection_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingPublicConnectionCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingPublicConnectionCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingPublicConnectionCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingPublicConnectionCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingPublicConnectionCollection_get__NewEnum(This,pVal) (This)->lpVtbl->get__NewEnum(This,pVal)
#define INetSharingPublicConnectionCollection_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#endif
#endif
  HRESULT WINAPI INetSharingPublicConnectionCollection_get__NewEnum_Proxy(INetSharingPublicConnectionCollection *This,IUnknown **pVal);
  void __RPC_STUB INetSharingPublicConnectionCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPublicConnectionCollection_get_Count_Proxy(INetSharingPublicConnectionCollection *This,__LONG32 *pVal);
  void __RPC_STUB INetSharingPublicConnectionCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingPrivateConnectionCollection_INTERFACE_DEFINED__
#define __INetSharingPrivateConnectionCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetSharingPrivateConnectionCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingPrivateConnectionCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **pVal) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
  };
#else
  typedef struct INetSharingPrivateConnectionCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingPrivateConnectionCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingPrivateConnectionCollection *This);
      ULONG (WINAPI *Release)(INetSharingPrivateConnectionCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingPrivateConnectionCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingPrivateConnectionCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingPrivateConnectionCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingPrivateConnectionCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(INetSharingPrivateConnectionCollection *This,IUnknown **pVal);
      HRESULT (WINAPI *get_Count)(INetSharingPrivateConnectionCollection *This,__LONG32 *pVal);
    END_INTERFACE
  } INetSharingPrivateConnectionCollectionVtbl;
  struct INetSharingPrivateConnectionCollection {
    CONST_VTBL struct INetSharingPrivateConnectionCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingPrivateConnectionCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingPrivateConnectionCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingPrivateConnectionCollection_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingPrivateConnectionCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingPrivateConnectionCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingPrivateConnectionCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingPrivateConnectionCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingPrivateConnectionCollection_get__NewEnum(This,pVal) (This)->lpVtbl->get__NewEnum(This,pVal)
#define INetSharingPrivateConnectionCollection_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#endif
#endif
  HRESULT WINAPI INetSharingPrivateConnectionCollection_get__NewEnum_Proxy(INetSharingPrivateConnectionCollection *This,IUnknown **pVal);
  void __RPC_STUB INetSharingPrivateConnectionCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingPrivateConnectionCollection_get_Count_Proxy(INetSharingPrivateConnectionCollection *This,__LONG32 *pVal);
  void __RPC_STUB INetSharingPrivateConnectionCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INetSharingManager_INTERFACE_DEFINED__
#define __INetSharingManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INetSharingManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INetSharingManager : public IDispatch {
  public:
    virtual HRESULT WINAPI get_SharingInstalled(VARIANT_BOOL *pbInstalled) = 0;
    virtual HRESULT WINAPI get_EnumPublicConnections(SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPublicConnectionCollection **ppColl) = 0;
    virtual HRESULT WINAPI get_EnumPrivateConnections(SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPrivateConnectionCollection **ppColl) = 0;
    virtual HRESULT WINAPI get_INetSharingConfigurationForINetConnection(INetConnection *pNetConnection,INetSharingConfiguration **ppNetSharingConfiguration) = 0;
    virtual HRESULT WINAPI get_EnumEveryConnection(INetSharingEveryConnectionCollection **ppColl) = 0;
    virtual HRESULT WINAPI get_NetConnectionProps(INetConnection *pNetConnection,INetConnectionProps **ppProps) = 0;
  };
#else
  typedef struct INetSharingManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INetSharingManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INetSharingManager *This);
      ULONG (WINAPI *Release)(INetSharingManager *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INetSharingManager *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INetSharingManager *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INetSharingManager *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INetSharingManager *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SharingInstalled)(INetSharingManager *This,VARIANT_BOOL *pbInstalled);
      HRESULT (WINAPI *get_EnumPublicConnections)(INetSharingManager *This,SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPublicConnectionCollection **ppColl);
      HRESULT (WINAPI *get_EnumPrivateConnections)(INetSharingManager *This,SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPrivateConnectionCollection **ppColl);
      HRESULT (WINAPI *get_INetSharingConfigurationForINetConnection)(INetSharingManager *This,INetConnection *pNetConnection,INetSharingConfiguration **ppNetSharingConfiguration);
      HRESULT (WINAPI *get_EnumEveryConnection)(INetSharingManager *This,INetSharingEveryConnectionCollection **ppColl);
      HRESULT (WINAPI *get_NetConnectionProps)(INetSharingManager *This,INetConnection *pNetConnection,INetConnectionProps **ppProps);
    END_INTERFACE
  } INetSharingManagerVtbl;
  struct INetSharingManager {
    CONST_VTBL struct INetSharingManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INetSharingManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetSharingManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetSharingManager_Release(This) (This)->lpVtbl->Release(This)
#define INetSharingManager_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INetSharingManager_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INetSharingManager_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INetSharingManager_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INetSharingManager_get_SharingInstalled(This,pbInstalled) (This)->lpVtbl->get_SharingInstalled(This,pbInstalled)
#define INetSharingManager_get_EnumPublicConnections(This,Flags,ppColl) (This)->lpVtbl->get_EnumPublicConnections(This,Flags,ppColl)
#define INetSharingManager_get_EnumPrivateConnections(This,Flags,ppColl) (This)->lpVtbl->get_EnumPrivateConnections(This,Flags,ppColl)
#define INetSharingManager_get_INetSharingConfigurationForINetConnection(This,pNetConnection,ppNetSharingConfiguration) (This)->lpVtbl->get_INetSharingConfigurationForINetConnection(This,pNetConnection,ppNetSharingConfiguration)
#define INetSharingManager_get_EnumEveryConnection(This,ppColl) (This)->lpVtbl->get_EnumEveryConnection(This,ppColl)
#define INetSharingManager_get_NetConnectionProps(This,pNetConnection,ppProps) (This)->lpVtbl->get_NetConnectionProps(This,pNetConnection,ppProps)
#endif
#endif
  HRESULT WINAPI INetSharingManager_get_SharingInstalled_Proxy(INetSharingManager *This,VARIANT_BOOL *pbInstalled);
  void __RPC_STUB INetSharingManager_get_SharingInstalled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingManager_get_EnumPublicConnections_Proxy(INetSharingManager *This,SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPublicConnectionCollection **ppColl);
  void __RPC_STUB INetSharingManager_get_EnumPublicConnections_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingManager_get_EnumPrivateConnections_Proxy(INetSharingManager *This,SHARINGCONNECTION_ENUM_FLAGS Flags,INetSharingPrivateConnectionCollection **ppColl);
  void __RPC_STUB INetSharingManager_get_EnumPrivateConnections_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingManager_get_INetSharingConfigurationForINetConnection_Proxy(INetSharingManager *This,INetConnection *pNetConnection,INetSharingConfiguration **ppNetSharingConfiguration);
  void __RPC_STUB INetSharingManager_get_INetSharingConfigurationForINetConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingManager_get_EnumEveryConnection_Proxy(INetSharingManager *This,INetSharingEveryConnectionCollection **ppColl);
  void __RPC_STUB INetSharingManager_get_EnumEveryConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INetSharingManager_get_NetConnectionProps_Proxy(INetSharingManager *This,INetConnection *pNetConnection,INetConnectionProps **ppProps);
  void __RPC_STUB INetSharingManager_get_NetConnectionProps_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __NETCONLib_LIBRARY_DEFINED__
#define __NETCONLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_NETCONLib;
  EXTERN_C const CLSID CLSID_NetSharingManager;
#ifdef __cplusplus
  class NetSharingManager;
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
