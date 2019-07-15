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

#ifndef __cluadmex_h__
#define __cluadmex_h__

#ifndef __IGetClusterUIInfo_FWD_DEFINED__
#define __IGetClusterUIInfo_FWD_DEFINED__
typedef struct IGetClusterUIInfo IGetClusterUIInfo;
#endif

#ifndef __IGetClusterDataInfo_FWD_DEFINED__
#define __IGetClusterDataInfo_FWD_DEFINED__
typedef struct IGetClusterDataInfo IGetClusterDataInfo;
#endif

#ifndef __IGetClusterObjectInfo_FWD_DEFINED__
#define __IGetClusterObjectInfo_FWD_DEFINED__
typedef struct IGetClusterObjectInfo IGetClusterObjectInfo;
#endif

#ifndef __IGetClusterNodeInfo_FWD_DEFINED__
#define __IGetClusterNodeInfo_FWD_DEFINED__
typedef struct IGetClusterNodeInfo IGetClusterNodeInfo;
#endif

#ifndef __IGetClusterGroupInfo_FWD_DEFINED__
#define __IGetClusterGroupInfo_FWD_DEFINED__
typedef struct IGetClusterGroupInfo IGetClusterGroupInfo;
#endif

#ifndef __IGetClusterResourceInfo_FWD_DEFINED__
#define __IGetClusterResourceInfo_FWD_DEFINED__
typedef struct IGetClusterResourceInfo IGetClusterResourceInfo;
#endif

#ifndef __IGetClusterNetworkInfo_FWD_DEFINED__
#define __IGetClusterNetworkInfo_FWD_DEFINED__
typedef struct IGetClusterNetworkInfo IGetClusterNetworkInfo;
#endif

#ifndef __IGetClusterNetInterfaceInfo_FWD_DEFINED__
#define __IGetClusterNetInterfaceInfo_FWD_DEFINED__
typedef struct IGetClusterNetInterfaceInfo IGetClusterNetInterfaceInfo;
#endif

#ifndef __IWCPropertySheetCallback_FWD_DEFINED__
#define __IWCPropertySheetCallback_FWD_DEFINED__
typedef struct IWCPropertySheetCallback IWCPropertySheetCallback;
#endif

#ifndef __IWEExtendPropertySheet_FWD_DEFINED__
#define __IWEExtendPropertySheet_FWD_DEFINED__
typedef struct IWEExtendPropertySheet IWEExtendPropertySheet;
#endif

#ifndef __IWCWizardCallback_FWD_DEFINED__
#define __IWCWizardCallback_FWD_DEFINED__
typedef struct IWCWizardCallback IWCWizardCallback;
#endif

#ifndef __IWEExtendWizard_FWD_DEFINED__
#define __IWEExtendWizard_FWD_DEFINED__
typedef struct IWEExtendWizard IWEExtendWizard;
#endif

#ifndef __IWCContextMenuCallback_FWD_DEFINED__
#define __IWCContextMenuCallback_FWD_DEFINED__
typedef struct IWCContextMenuCallback IWCContextMenuCallback;
#endif

#ifndef __IWEExtendContextMenu_FWD_DEFINED__
#define __IWEExtendContextMenu_FWD_DEFINED__
typedef struct IWEExtendContextMenu IWEExtendContextMenu;
#endif

#ifndef __IWEInvokeCommand_FWD_DEFINED__
#define __IWEInvokeCommand_FWD_DEFINED__
typedef struct IWEInvokeCommand IWEInvokeCommand;
#endif

#ifndef __IWCWizard97Callback_FWD_DEFINED__
#define __IWCWizard97Callback_FWD_DEFINED__
typedef struct IWCWizard97Callback IWCWizard97Callback;
#endif

#ifndef __IWEExtendWizard97_FWD_DEFINED__
#define __IWEExtendWizard97_FWD_DEFINED__
typedef struct IWEExtendWizard97 IWEExtendWizard97;
#endif

#include "oaidl.h"
#include "clusapi.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum _CLUADMEX_OBJECT_TYPE {
    CLUADMEX_OT_NONE = 0,CLUADMEX_OT_CLUSTER,CLUADMEX_OT_NODE,CLUADMEX_OT_GROUP,
    CLUADMEX_OT_RESOURCE,CLUADMEX_OT_RESOURCETYPE,CLUADMEX_OT_NETWORK,
    CLUADMEX_OT_NETINTERFACE
  } CLUADMEX_OBJECT_TYPE;

  extern RPC_IF_HANDLE __MIDL_itf_cluadmex_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_cluadmex_0000_v0_0_s_ifspec;

#ifndef __IGetClusterUIInfo_INTERFACE_DEFINED__
#define __IGetClusterUIInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterUIInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterUIInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetClusterName(BSTR lpszName,LONG *pcchName) = 0;
    virtual LCID WINAPI GetLocale(void) = 0;
    virtual HFONT WINAPI GetFont(void) = 0;
    virtual HICON WINAPI GetIcon(void) = 0;
  };
#else
  typedef struct IGetClusterUIInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterUIInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterUIInfo *This);
      ULONG (WINAPI *Release)(IGetClusterUIInfo *This);
      HRESULT (WINAPI *GetClusterName)(IGetClusterUIInfo *This,BSTR lpszName,LONG *pcchName);
      LCID (WINAPI *GetLocale)(IGetClusterUIInfo *This);
      HFONT (WINAPI *GetFont)(IGetClusterUIInfo *This);
      HICON (WINAPI *GetIcon)(IGetClusterUIInfo *This);
    END_INTERFACE
  } IGetClusterUIInfoVtbl;
  struct IGetClusterUIInfo {
    CONST_VTBL struct IGetClusterUIInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterUIInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterUIInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterUIInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterUIInfo_GetClusterName(This,lpszName,pcchName) (This)->lpVtbl->GetClusterName(This,lpszName,pcchName)
#define IGetClusterUIInfo_GetLocale(This) (This)->lpVtbl->GetLocale(This)
#define IGetClusterUIInfo_GetFont(This) (This)->lpVtbl->GetFont(This)
#define IGetClusterUIInfo_GetIcon(This) (This)->lpVtbl->GetIcon(This)
#endif
#endif
  HRESULT WINAPI IGetClusterUIInfo_GetClusterName_Proxy(IGetClusterUIInfo *This,BSTR lpszName,LONG *pcchName);
  void __RPC_STUB IGetClusterUIInfo_GetClusterName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  LCID WINAPI IGetClusterUIInfo_GetLocale_Proxy(IGetClusterUIInfo *This);
  void __RPC_STUB IGetClusterUIInfo_GetLocale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HFONT WINAPI IGetClusterUIInfo_GetFont_Proxy(IGetClusterUIInfo *This);
  void __RPC_STUB IGetClusterUIInfo_GetFont_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HICON WINAPI IGetClusterUIInfo_GetIcon_Proxy(IGetClusterUIInfo *This);
  void __RPC_STUB IGetClusterUIInfo_GetIcon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetClusterDataInfo_INTERFACE_DEFINED__
#define __IGetClusterDataInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterDataInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterDataInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetClusterName(BSTR lpszName,LONG *pcchName) = 0;
    virtual HCLUSTER WINAPI GetClusterHandle(void) = 0;
    virtual LONG WINAPI GetObjectCount(void) = 0;
  };
#else
  typedef struct IGetClusterDataInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterDataInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterDataInfo *This);
      ULONG (WINAPI *Release)(IGetClusterDataInfo *This);
      HRESULT (WINAPI *GetClusterName)(IGetClusterDataInfo *This,BSTR lpszName,LONG *pcchName);
      HCLUSTER (WINAPI *GetClusterHandle)(IGetClusterDataInfo *This);
      LONG (WINAPI *GetObjectCount)(IGetClusterDataInfo *This);
    END_INTERFACE
  } IGetClusterDataInfoVtbl;
  struct IGetClusterDataInfo {
    CONST_VTBL struct IGetClusterDataInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterDataInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterDataInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterDataInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterDataInfo_GetClusterName(This,lpszName,pcchName) (This)->lpVtbl->GetClusterName(This,lpszName,pcchName)
#define IGetClusterDataInfo_GetClusterHandle(This) (This)->lpVtbl->GetClusterHandle(This)
#define IGetClusterDataInfo_GetObjectCount(This) (This)->lpVtbl->GetObjectCount(This)
#endif
#endif
  HRESULT WINAPI IGetClusterDataInfo_GetClusterName_Proxy(IGetClusterDataInfo *This,BSTR lpszName,LONG *pcchName);
  void __RPC_STUB IGetClusterDataInfo_GetClusterName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HCLUSTER WINAPI IGetClusterDataInfo_GetClusterHandle_Proxy(IGetClusterDataInfo *This);
  void __RPC_STUB IGetClusterDataInfo_GetClusterHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  LONG WINAPI IGetClusterDataInfo_GetObjectCount_Proxy(IGetClusterDataInfo *This);
  void __RPC_STUB IGetClusterDataInfo_GetObjectCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetClusterObjectInfo_INTERFACE_DEFINED__
#define __IGetClusterObjectInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterObjectInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterObjectInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetObjectName(LONG lObjIndex,BSTR lpszName,LONG *pcchName) = 0;
    virtual CLUADMEX_OBJECT_TYPE WINAPI GetObjectType(LONG lObjIndex) = 0;
  };
#else
  typedef struct IGetClusterObjectInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterObjectInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterObjectInfo *This);
      ULONG (WINAPI *Release)(IGetClusterObjectInfo *This);
      HRESULT (WINAPI *GetObjectName)(IGetClusterObjectInfo *This,LONG lObjIndex,BSTR lpszName,LONG *pcchName);
      CLUADMEX_OBJECT_TYPE (WINAPI *GetObjectType)(IGetClusterObjectInfo *This,LONG lObjIndex);
    END_INTERFACE
  } IGetClusterObjectInfoVtbl;
  struct IGetClusterObjectInfo {
    CONST_VTBL struct IGetClusterObjectInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterObjectInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterObjectInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterObjectInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterObjectInfo_GetObjectName(This,lObjIndex,lpszName,pcchName) (This)->lpVtbl->GetObjectName(This,lObjIndex,lpszName,pcchName)
#define IGetClusterObjectInfo_GetObjectType(This,lObjIndex) (This)->lpVtbl->GetObjectType(This,lObjIndex)
#endif
#endif
  HRESULT WINAPI IGetClusterObjectInfo_GetObjectName_Proxy(IGetClusterObjectInfo *This,LONG lObjIndex,BSTR lpszName,LONG *pcchName);
  void __RPC_STUB IGetClusterObjectInfo_GetObjectName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  CLUADMEX_OBJECT_TYPE WINAPI IGetClusterObjectInfo_GetObjectType_Proxy(IGetClusterObjectInfo *This,LONG lObjIndex);
  void __RPC_STUB IGetClusterObjectInfo_GetObjectType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetClusterNodeInfo_INTERFACE_DEFINED__
#define __IGetClusterNodeInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterNodeInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterNodeInfo : public IUnknown {
  public:
    virtual HNODE WINAPI GetNodeHandle(LONG lObjIndex) = 0;
  };
#else
  typedef struct IGetClusterNodeInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterNodeInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterNodeInfo *This);
      ULONG (WINAPI *Release)(IGetClusterNodeInfo *This);
      HNODE (WINAPI *GetNodeHandle)(IGetClusterNodeInfo *This,LONG lObjIndex);
    END_INTERFACE
  } IGetClusterNodeInfoVtbl;
  struct IGetClusterNodeInfo {
    CONST_VTBL struct IGetClusterNodeInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterNodeInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterNodeInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterNodeInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterNodeInfo_GetNodeHandle(This,lObjIndex) (This)->lpVtbl->GetNodeHandle(This,lObjIndex)
#endif
#endif
  HNODE WINAPI IGetClusterNodeInfo_GetNodeHandle_Proxy(IGetClusterNodeInfo *This,LONG lObjIndex);
  void __RPC_STUB IGetClusterNodeInfo_GetNodeHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetClusterGroupInfo_INTERFACE_DEFINED__
#define __IGetClusterGroupInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterGroupInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterGroupInfo : public IUnknown {
  public:
    virtual HGROUP WINAPI GetGroupHandle(LONG lObjIndex) = 0;
  };
#else
  typedef struct IGetClusterGroupInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterGroupInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterGroupInfo *This);
      ULONG (WINAPI *Release)(IGetClusterGroupInfo *This);
      HGROUP (WINAPI *GetGroupHandle)(IGetClusterGroupInfo *This,LONG lObjIndex);
    END_INTERFACE
  } IGetClusterGroupInfoVtbl;
  struct IGetClusterGroupInfo {
    CONST_VTBL struct IGetClusterGroupInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterGroupInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterGroupInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterGroupInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterGroupInfo_GetGroupHandle(This,lObjIndex) (This)->lpVtbl->GetGroupHandle(This,lObjIndex)
#endif
#endif
  HGROUP WINAPI IGetClusterGroupInfo_GetGroupHandle_Proxy(IGetClusterGroupInfo *This,LONG lObjIndex);
  void __RPC_STUB IGetClusterGroupInfo_GetGroupHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetClusterResourceInfo_INTERFACE_DEFINED__
#define __IGetClusterResourceInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterResourceInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterResourceInfo : public IUnknown {
  public:
    virtual HRESOURCE WINAPI GetResourceHandle(LONG lObjIndex) = 0;
    virtual HRESULT WINAPI GetResourceTypeName(LONG lObjIndex,BSTR lpszResTypeName,LONG *pcchResTypeName) = 0;
    virtual WINBOOL WINAPI GetResourceNetworkName(LONG lObjIndex,BSTR lpszNetName,ULONG *pcchNetName) = 0;
  };
#else
  typedef struct IGetClusterResourceInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterResourceInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterResourceInfo *This);
      ULONG (WINAPI *Release)(IGetClusterResourceInfo *This);
      HRESOURCE (WINAPI *GetResourceHandle)(IGetClusterResourceInfo *This,LONG lObjIndex);
      HRESULT (WINAPI *GetResourceTypeName)(IGetClusterResourceInfo *This,LONG lObjIndex,BSTR lpszResTypeName,LONG *pcchResTypeName);
      WINBOOL (WINAPI *GetResourceNetworkName)(IGetClusterResourceInfo *This,LONG lObjIndex,BSTR lpszNetName,ULONG *pcchNetName);
    END_INTERFACE
  } IGetClusterResourceInfoVtbl;
  struct IGetClusterResourceInfo {
    CONST_VTBL struct IGetClusterResourceInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterResourceInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterResourceInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterResourceInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterResourceInfo_GetResourceHandle(This,lObjIndex) (This)->lpVtbl->GetResourceHandle(This,lObjIndex)
#define IGetClusterResourceInfo_GetResourceTypeName(This,lObjIndex,lpszResTypeName,pcchResTypeName) (This)->lpVtbl->GetResourceTypeName(This,lObjIndex,lpszResTypeName,pcchResTypeName)
#define IGetClusterResourceInfo_GetResourceNetworkName(This,lObjIndex,lpszNetName,pcchNetName) (This)->lpVtbl->GetResourceNetworkName(This,lObjIndex,lpszNetName,pcchNetName)
#endif
#endif
  HRESOURCE WINAPI IGetClusterResourceInfo_GetResourceHandle_Proxy(IGetClusterResourceInfo *This,LONG lObjIndex);
  void __RPC_STUB IGetClusterResourceInfo_GetResourceHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IGetClusterResourceInfo_GetResourceTypeName_Proxy(IGetClusterResourceInfo *This,LONG lObjIndex,BSTR lpszResTypeName,LONG *pcchResTypeName);
  void __RPC_STUB IGetClusterResourceInfo_GetResourceTypeName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IGetClusterResourceInfo_GetResourceNetworkName_Proxy(IGetClusterResourceInfo *This,LONG lObjIndex,BSTR lpszNetName,ULONG *pcchNetName);
  void __RPC_STUB IGetClusterResourceInfo_GetResourceNetworkName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetClusterNetworkInfo_INTERFACE_DEFINED__
#define __IGetClusterNetworkInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterNetworkInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterNetworkInfo : public IUnknown {
  public:
    virtual HNETWORK WINAPI GetNetworkHandle(LONG lObjIndex) = 0;
  };
#else
  typedef struct IGetClusterNetworkInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterNetworkInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterNetworkInfo *This);
      ULONG (WINAPI *Release)(IGetClusterNetworkInfo *This);
      HNETWORK (WINAPI *GetNetworkHandle)(IGetClusterNetworkInfo *This,LONG lObjIndex);
    END_INTERFACE
  } IGetClusterNetworkInfoVtbl;
  struct IGetClusterNetworkInfo {
    CONST_VTBL struct IGetClusterNetworkInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterNetworkInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterNetworkInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterNetworkInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterNetworkInfo_GetNetworkHandle(This,lObjIndex) (This)->lpVtbl->GetNetworkHandle(This,lObjIndex)
#endif
#endif
  HNETWORK WINAPI IGetClusterNetworkInfo_GetNetworkHandle_Proxy(IGetClusterNetworkInfo *This,LONG lObjIndex);
  void __RPC_STUB IGetClusterNetworkInfo_GetNetworkHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetClusterNetInterfaceInfo_INTERFACE_DEFINED__
#define __IGetClusterNetInterfaceInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetClusterNetInterfaceInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetClusterNetInterfaceInfo : public IUnknown {
  public:
    virtual HNETINTERFACE WINAPI GetNetInterfaceHandle(LONG lObjIndex) = 0;
  };
#else
  typedef struct IGetClusterNetInterfaceInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetClusterNetInterfaceInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetClusterNetInterfaceInfo *This);
      ULONG (WINAPI *Release)(IGetClusterNetInterfaceInfo *This);
      HNETINTERFACE (WINAPI *GetNetInterfaceHandle)(IGetClusterNetInterfaceInfo *This,LONG lObjIndex);
    END_INTERFACE
  } IGetClusterNetInterfaceInfoVtbl;
  struct IGetClusterNetInterfaceInfo {
    CONST_VTBL struct IGetClusterNetInterfaceInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetClusterNetInterfaceInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetClusterNetInterfaceInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetClusterNetInterfaceInfo_Release(This) (This)->lpVtbl->Release(This)
#define IGetClusterNetInterfaceInfo_GetNetInterfaceHandle(This,lObjIndex) (This)->lpVtbl->GetNetInterfaceHandle(This,lObjIndex)
#endif
#endif
  HNETINTERFACE WINAPI IGetClusterNetInterfaceInfo_GetNetInterfaceHandle_Proxy(IGetClusterNetInterfaceInfo *This,LONG lObjIndex);
  void __RPC_STUB IGetClusterNetInterfaceInfo_GetNetInterfaceHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWCPropertySheetCallback_INTERFACE_DEFINED__
#define __IWCPropertySheetCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWCPropertySheetCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWCPropertySheetCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI AddPropertySheetPage(LONG *hpage) = 0;
  };
#else
  typedef struct IWCPropertySheetCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWCPropertySheetCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWCPropertySheetCallback *This);
      ULONG (WINAPI *Release)(IWCPropertySheetCallback *This);
      HRESULT (WINAPI *AddPropertySheetPage)(IWCPropertySheetCallback *This,LONG *hpage);
    END_INTERFACE
  } IWCPropertySheetCallbackVtbl;
  struct IWCPropertySheetCallback {
    CONST_VTBL struct IWCPropertySheetCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWCPropertySheetCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWCPropertySheetCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWCPropertySheetCallback_Release(This) (This)->lpVtbl->Release(This)
#define IWCPropertySheetCallback_AddPropertySheetPage(This,hpage) (This)->lpVtbl->AddPropertySheetPage(This,hpage)
#endif
#endif
  HRESULT WINAPI IWCPropertySheetCallback_AddPropertySheetPage_Proxy(IWCPropertySheetCallback *This,LONG *hpage);
  void __RPC_STUB IWCPropertySheetCallback_AddPropertySheetPage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWEExtendPropertySheet_INTERFACE_DEFINED__
#define __IWEExtendPropertySheet_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWEExtendPropertySheet;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWEExtendPropertySheet : public IUnknown {
  public:
    virtual HRESULT WINAPI CreatePropertySheetPages(IUnknown *piData,IWCPropertySheetCallback *piCallback) = 0;
  };
#else
  typedef struct IWEExtendPropertySheetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWEExtendPropertySheet *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWEExtendPropertySheet *This);
      ULONG (WINAPI *Release)(IWEExtendPropertySheet *This);
      HRESULT (WINAPI *CreatePropertySheetPages)(IWEExtendPropertySheet *This,IUnknown *piData,IWCPropertySheetCallback *piCallback);
    END_INTERFACE
  } IWEExtendPropertySheetVtbl;
  struct IWEExtendPropertySheet {
    CONST_VTBL struct IWEExtendPropertySheetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWEExtendPropertySheet_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWEExtendPropertySheet_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWEExtendPropertySheet_Release(This) (This)->lpVtbl->Release(This)
#define IWEExtendPropertySheet_CreatePropertySheetPages(This,piData,piCallback) (This)->lpVtbl->CreatePropertySheetPages(This,piData,piCallback)
#endif
#endif
  HRESULT WINAPI IWEExtendPropertySheet_CreatePropertySheetPages_Proxy(IWEExtendPropertySheet *This,IUnknown *piData,IWCPropertySheetCallback *piCallback);
  void __RPC_STUB IWEExtendPropertySheet_CreatePropertySheetPages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWCWizardCallback_INTERFACE_DEFINED__
#define __IWCWizardCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWCWizardCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWCWizardCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI AddWizardPage(LONG *hpage) = 0;
    virtual HRESULT WINAPI EnableNext(LONG *hpage,WINBOOL bEnable) = 0;
  };
#else
  typedef struct IWCWizardCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWCWizardCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWCWizardCallback *This);
      ULONG (WINAPI *Release)(IWCWizardCallback *This);
      HRESULT (WINAPI *AddWizardPage)(IWCWizardCallback *This,LONG *hpage);
      HRESULT (WINAPI *EnableNext)(IWCWizardCallback *This,LONG *hpage,WINBOOL bEnable);
    END_INTERFACE
  } IWCWizardCallbackVtbl;
  struct IWCWizardCallback {
    CONST_VTBL struct IWCWizardCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWCWizardCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWCWizardCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWCWizardCallback_Release(This) (This)->lpVtbl->Release(This)
#define IWCWizardCallback_AddWizardPage(This,hpage) (This)->lpVtbl->AddWizardPage(This,hpage)
#define IWCWizardCallback_EnableNext(This,hpage,bEnable) (This)->lpVtbl->EnableNext(This,hpage,bEnable)
#endif
#endif
  HRESULT WINAPI IWCWizardCallback_AddWizardPage_Proxy(IWCWizardCallback *This,LONG *hpage);
  void __RPC_STUB IWCWizardCallback_AddWizardPage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWCWizardCallback_EnableNext_Proxy(IWCWizardCallback *This,LONG *hpage,WINBOOL bEnable);
  void __RPC_STUB IWCWizardCallback_EnableNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWEExtendWizard_INTERFACE_DEFINED__
#define __IWEExtendWizard_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWEExtendWizard;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWEExtendWizard : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateWizardPages(IUnknown *piData,IWCWizardCallback *piCallback) = 0;
  };
#else
  typedef struct IWEExtendWizardVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWEExtendWizard *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWEExtendWizard *This);
      ULONG (WINAPI *Release)(IWEExtendWizard *This);
      HRESULT (WINAPI *CreateWizardPages)(IWEExtendWizard *This,IUnknown *piData,IWCWizardCallback *piCallback);
    END_INTERFACE
  } IWEExtendWizardVtbl;
  struct IWEExtendWizard {
    CONST_VTBL struct IWEExtendWizardVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWEExtendWizard_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWEExtendWizard_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWEExtendWizard_Release(This) (This)->lpVtbl->Release(This)
#define IWEExtendWizard_CreateWizardPages(This,piData,piCallback) (This)->lpVtbl->CreateWizardPages(This,piData,piCallback)
#endif
#endif
  HRESULT WINAPI IWEExtendWizard_CreateWizardPages_Proxy(IWEExtendWizard *This,IUnknown *piData,IWCWizardCallback *piCallback);
  void __RPC_STUB IWEExtendWizard_CreateWizardPages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWCContextMenuCallback_INTERFACE_DEFINED__
#define __IWCContextMenuCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWCContextMenuCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWCContextMenuCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI AddExtensionMenuItem(BSTR lpszName,BSTR lpszStatusBarText,ULONG nCommandID,ULONG nSubmenuCommandID,ULONG uFlags) = 0;
  };
#else
  typedef struct IWCContextMenuCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWCContextMenuCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWCContextMenuCallback *This);
      ULONG (WINAPI *Release)(IWCContextMenuCallback *This);
      HRESULT (WINAPI *AddExtensionMenuItem)(IWCContextMenuCallback *This,BSTR lpszName,BSTR lpszStatusBarText,ULONG nCommandID,ULONG nSubmenuCommandID,ULONG uFlags);
    END_INTERFACE
  } IWCContextMenuCallbackVtbl;
  struct IWCContextMenuCallback {
    CONST_VTBL struct IWCContextMenuCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWCContextMenuCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWCContextMenuCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWCContextMenuCallback_Release(This) (This)->lpVtbl->Release(This)
#define IWCContextMenuCallback_AddExtensionMenuItem(This,lpszName,lpszStatusBarText,nCommandID,nSubmenuCommandID,uFlags) (This)->lpVtbl->AddExtensionMenuItem(This,lpszName,lpszStatusBarText,nCommandID,nSubmenuCommandID,uFlags)
#endif
#endif
  HRESULT WINAPI IWCContextMenuCallback_AddExtensionMenuItem_Proxy(IWCContextMenuCallback *This,BSTR lpszName,BSTR lpszStatusBarText,ULONG nCommandID,ULONG nSubmenuCommandID,ULONG uFlags);
  void __RPC_STUB IWCContextMenuCallback_AddExtensionMenuItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWEExtendContextMenu_INTERFACE_DEFINED__
#define __IWEExtendContextMenu_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWEExtendContextMenu;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWEExtendContextMenu : public IUnknown {
  public:
    virtual HRESULT WINAPI AddContextMenuItems(IUnknown *piData,IWCContextMenuCallback *piCallback) = 0;
  };
#else
  typedef struct IWEExtendContextMenuVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWEExtendContextMenu *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWEExtendContextMenu *This);
      ULONG (WINAPI *Release)(IWEExtendContextMenu *This);
      HRESULT (WINAPI *AddContextMenuItems)(IWEExtendContextMenu *This,IUnknown *piData,IWCContextMenuCallback *piCallback);
    END_INTERFACE
  } IWEExtendContextMenuVtbl;
  struct IWEExtendContextMenu {
    CONST_VTBL struct IWEExtendContextMenuVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWEExtendContextMenu_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWEExtendContextMenu_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWEExtendContextMenu_Release(This) (This)->lpVtbl->Release(This)
#define IWEExtendContextMenu_AddContextMenuItems(This,piData,piCallback) (This)->lpVtbl->AddContextMenuItems(This,piData,piCallback)
#endif
#endif
  HRESULT WINAPI IWEExtendContextMenu_AddContextMenuItems_Proxy(IWEExtendContextMenu *This,IUnknown *piData,IWCContextMenuCallback *piCallback);
  void __RPC_STUB IWEExtendContextMenu_AddContextMenuItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWEInvokeCommand_INTERFACE_DEFINED__
#define __IWEInvokeCommand_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWEInvokeCommand;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWEInvokeCommand : public IUnknown {
  public:
    virtual HRESULT WINAPI InvokeCommand(ULONG nCommandID,IUnknown *piData) = 0;
  };
#else
  typedef struct IWEInvokeCommandVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWEInvokeCommand *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWEInvokeCommand *This);
      ULONG (WINAPI *Release)(IWEInvokeCommand *This);
      HRESULT (WINAPI *InvokeCommand)(IWEInvokeCommand *This,ULONG nCommandID,IUnknown *piData);
    END_INTERFACE
  } IWEInvokeCommandVtbl;
  struct IWEInvokeCommand {
    CONST_VTBL struct IWEInvokeCommandVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWEInvokeCommand_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWEInvokeCommand_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWEInvokeCommand_Release(This) (This)->lpVtbl->Release(This)
#define IWEInvokeCommand_InvokeCommand(This,nCommandID,piData) (This)->lpVtbl->InvokeCommand(This,nCommandID,piData)
#endif
#endif
  HRESULT WINAPI IWEInvokeCommand_InvokeCommand_Proxy(IWEInvokeCommand *This,ULONG nCommandID,IUnknown *piData);
  void __RPC_STUB IWEInvokeCommand_InvokeCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWCWizard97Callback_INTERFACE_DEFINED__
#define __IWCWizard97Callback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWCWizard97Callback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWCWizard97Callback : public IUnknown {
  public:
    virtual HRESULT WINAPI AddWizard97Page(LONG *hpage) = 0;
    virtual HRESULT WINAPI EnableNext(LONG *hpage,WINBOOL bEnable) = 0;
  };
#else
  typedef struct IWCWizard97CallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWCWizard97Callback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWCWizard97Callback *This);
      ULONG (WINAPI *Release)(IWCWizard97Callback *This);
      HRESULT (WINAPI *AddWizard97Page)(IWCWizard97Callback *This,LONG *hpage);
      HRESULT (WINAPI *EnableNext)(IWCWizard97Callback *This,LONG *hpage,WINBOOL bEnable);
    END_INTERFACE
  } IWCWizard97CallbackVtbl;
  struct IWCWizard97Callback {
    CONST_VTBL struct IWCWizard97CallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWCWizard97Callback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWCWizard97Callback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWCWizard97Callback_Release(This) (This)->lpVtbl->Release(This)
#define IWCWizard97Callback_AddWizard97Page(This,hpage) (This)->lpVtbl->AddWizard97Page(This,hpage)
#define IWCWizard97Callback_EnableNext(This,hpage,bEnable) (This)->lpVtbl->EnableNext(This,hpage,bEnable)
#endif
#endif
  HRESULT WINAPI IWCWizard97Callback_AddWizard97Page_Proxy(IWCWizard97Callback *This,LONG *hpage);
  void __RPC_STUB IWCWizard97Callback_AddWizard97Page_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWCWizard97Callback_EnableNext_Proxy(IWCWizard97Callback *This,LONG *hpage,WINBOOL bEnable);
  void __RPC_STUB IWCWizard97Callback_EnableNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWEExtendWizard97_INTERFACE_DEFINED__
#define __IWEExtendWizard97_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWEExtendWizard97;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWEExtendWizard97 : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateWizard97Pages(IUnknown *piData,IWCWizard97Callback *piCallback) = 0;
  };
#else
  typedef struct IWEExtendWizard97Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWEExtendWizard97 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWEExtendWizard97 *This);
      ULONG (WINAPI *Release)(IWEExtendWizard97 *This);
      HRESULT (WINAPI *CreateWizard97Pages)(IWEExtendWizard97 *This,IUnknown *piData,IWCWizard97Callback *piCallback);
    END_INTERFACE
  } IWEExtendWizard97Vtbl;
  struct IWEExtendWizard97 {
    CONST_VTBL struct IWEExtendWizard97Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWEExtendWizard97_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWEExtendWizard97_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWEExtendWizard97_Release(This) (This)->lpVtbl->Release(This)
#define IWEExtendWizard97_CreateWizard97Pages(This,piData,piCallback) (This)->lpVtbl->CreateWizard97Pages(This,piData,piCallback)
#endif
#endif
  HRESULT WINAPI IWEExtendWizard97_CreateWizard97Pages_Proxy(IWEExtendWizard97 *This,IUnknown *piData,IWCWizard97Callback *piCallback);
  void __RPC_STUB IWEExtendWizard97_CreateWizard97Pages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
