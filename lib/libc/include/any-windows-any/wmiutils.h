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

#ifndef __wmiutils_h__
#define __wmiutils_h__

#ifndef __IWbemPathKeyList_FWD_DEFINED__
#define __IWbemPathKeyList_FWD_DEFINED__
typedef struct IWbemPathKeyList IWbemPathKeyList;
#endif

#ifndef __IWbemPath_FWD_DEFINED__
#define __IWbemPath_FWD_DEFINED__
typedef struct IWbemPath IWbemPath;
#endif

#ifndef __WbemDefPath_FWD_DEFINED__
#define __WbemDefPath_FWD_DEFINED__

#ifdef __cplusplus
typedef class WbemDefPath WbemDefPath;
#else
typedef struct WbemDefPath WbemDefPath;
#endif
#endif

#ifndef __IWbemQuery_FWD_DEFINED__
#define __IWbemQuery_FWD_DEFINED__
typedef struct IWbemQuery IWbemQuery;
#endif

#ifndef __WbemQuery_FWD_DEFINED__
#define __WbemQuery_FWD_DEFINED__
#ifdef __cplusplus
typedef class WbemQuery WbemQuery;
#else
typedef struct WbemQuery WbemQuery;
#endif
#endif

#ifndef __IWbemQuery_FWD_DEFINED__
#define __IWbemQuery_FWD_DEFINED__
typedef struct IWbemQuery IWbemQuery;
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_wmiutils_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wmiutils_0000_v0_0_s_ifspec;

#ifndef __WbemUtilities_v1_LIBRARY_DEFINED__
#define __WbemUtilities_v1_LIBRARY_DEFINED__

  typedef enum tag_WBEM_PATH_STATUS_FLAG {
    WBEMPATH_INFO_ANON_LOCAL_MACHINE = 0x1,WBEMPATH_INFO_HAS_MACHINE_NAME = 0x2,WBEMPATH_INFO_IS_CLASS_REF = 0x4,WBEMPATH_INFO_IS_INST_REF = 0x8,
    WBEMPATH_INFO_HAS_SUBSCOPES = 0x10,WBEMPATH_INFO_IS_COMPOUND = 0x20,WBEMPATH_INFO_HAS_V2_REF_PATHS = 0x40,WBEMPATH_INFO_HAS_IMPLIED_KEY = 0x80,
    WBEMPATH_INFO_CONTAINS_SINGLETON = 0x100,WBEMPATH_INFO_V1_COMPLIANT = 0x200,WBEMPATH_INFO_V2_COMPLIANT = 0x400,WBEMPATH_INFO_CIM_COMPLIANT = 0x800,
    WBEMPATH_INFO_IS_SINGLETON = 0x1000,WBEMPATH_INFO_IS_PARENT = 0x2000,WBEMPATH_INFO_SERVER_NAMESPACE_ONLY = 0x4000,WBEMPATH_INFO_NATIVE_PATH = 0x8000,
    WBEMPATH_INFO_WMI_PATH = 0x10000,WBEMPATH_INFO_PATH_HAD_SERVER = 0x20000
  } tag_WBEM_PATH_STATUS_FLAG;

  typedef enum tag_WBEM_PATH_CREATE_FLAG {
    WBEMPATH_CREATE_ACCEPT_RELATIVE = 0x1,WBEMPATH_CREATE_ACCEPT_ABSOLUTE = 0x2,WBEMPATH_CREATE_ACCEPT_ALL = 0x4,WBEMPATH_TREAT_SINGLE_IDENT_AS_NS = 0x8
  } tag_WBEM_PATH_CREATE_FLAG;

  typedef enum tag_WBEM_GET_TEXT_FLAGS {
    WBEMPATH_COMPRESSED = 0x1,WBEMPATH_GET_RELATIVE_ONLY = 0x2,WBEMPATH_GET_SERVER_TOO = 0x4,WBEMPATH_GET_SERVER_AND_NAMESPACE_ONLY = 0x8,
    WBEMPATH_GET_NAMESPACE_ONLY = 0x10,WBEMPATH_GET_ORIGINAL = 0x20
  } tag_WBEM_GET_TEXT_FLAGS;

  typedef enum tag_WBEM_GET_KEY_FLAGS {
    WBEMPATH_TEXT = 0x1,WBEMPATH_QUOTEDTEXT = 0x2
  } tag_WBEM_GET_KEY_FLAGS;

  EXTERN_C const IID LIBID_WbemUtilities_v1;
#ifndef __IWbemPathKeyList_INTERFACE_DEFINED__
#define __IWbemPathKeyList_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWbemPathKeyList;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWbemPathKeyList : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCount(ULONG *puKeyCount) = 0;
    virtual HRESULT WINAPI SetKey(LPCWSTR wszName,ULONG uFlags,ULONG uCimType,LPVOID pKeyVal) = 0;
    virtual HRESULT WINAPI SetKey2(LPCWSTR wszName,ULONG uFlags,ULONG uCimType,VARIANT *pKeyVal) = 0;
    virtual HRESULT WINAPI GetKey(ULONG uKeyIx,ULONG uFlags,ULONG *puNameBufSize,LPWSTR pszKeyName,ULONG *puKeyValBufSize,LPVOID pKeyVal,ULONG *puApparentCimType) = 0;
    virtual HRESULT WINAPI GetKey2(ULONG uKeyIx,ULONG uFlags,ULONG *puNameBufSize,LPWSTR pszKeyName,VARIANT *pKeyValue,ULONG *puApparentCimType) = 0;
    virtual HRESULT WINAPI RemoveKey(LPCWSTR wszName,ULONG uFlags) = 0;
    virtual HRESULT WINAPI RemoveAllKeys(ULONG uFlags) = 0;
    virtual HRESULT WINAPI MakeSingleton(boolean bSet) = 0;
    virtual HRESULT WINAPI GetInfo(ULONG uRequestedInfo,ULONGLONG *puResponse) = 0;
    virtual HRESULT WINAPI GetText(__LONG32 lFlags,ULONG *puBuffLength,LPWSTR pszText) = 0;
  };
#else
  typedef struct IWbemPathKeyListVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWbemPathKeyList *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWbemPathKeyList *This);
      ULONG (WINAPI *Release)(IWbemPathKeyList *This);
      HRESULT (WINAPI *GetCount)(IWbemPathKeyList *This,ULONG *puKeyCount);
      HRESULT (WINAPI *SetKey)(IWbemPathKeyList *This,LPCWSTR wszName,ULONG uFlags,ULONG uCimType,LPVOID pKeyVal);
      HRESULT (WINAPI *SetKey2)(IWbemPathKeyList *This,LPCWSTR wszName,ULONG uFlags,ULONG uCimType,VARIANT *pKeyVal);
      HRESULT (WINAPI *GetKey)(IWbemPathKeyList *This,ULONG uKeyIx,ULONG uFlags,ULONG *puNameBufSize,LPWSTR pszKeyName,ULONG *puKeyValBufSize,LPVOID pKeyVal,ULONG *puApparentCimType);
      HRESULT (WINAPI *GetKey2)(IWbemPathKeyList *This,ULONG uKeyIx,ULONG uFlags,ULONG *puNameBufSize,LPWSTR pszKeyName,VARIANT *pKeyValue,ULONG *puApparentCimType);
      HRESULT (WINAPI *RemoveKey)(IWbemPathKeyList *This,LPCWSTR wszName,ULONG uFlags);
      HRESULT (WINAPI *RemoveAllKeys)(IWbemPathKeyList *This,ULONG uFlags);
      HRESULT (WINAPI *MakeSingleton)(IWbemPathKeyList *This,boolean bSet);
      HRESULT (WINAPI *GetInfo)(IWbemPathKeyList *This,ULONG uRequestedInfo,ULONGLONG *puResponse);
      HRESULT (WINAPI *GetText)(IWbemPathKeyList *This,__LONG32 lFlags,ULONG *puBuffLength,LPWSTR pszText);
    END_INTERFACE
  } IWbemPathKeyListVtbl;
  struct IWbemPathKeyList {
    CONST_VTBL struct IWbemPathKeyListVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWbemPathKeyList_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWbemPathKeyList_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWbemPathKeyList_Release(This) (This)->lpVtbl->Release(This)
#define IWbemPathKeyList_GetCount(This,puKeyCount) (This)->lpVtbl->GetCount(This,puKeyCount)
#define IWbemPathKeyList_SetKey(This,wszName,uFlags,uCimType,pKeyVal) (This)->lpVtbl->SetKey(This,wszName,uFlags,uCimType,pKeyVal)
#define IWbemPathKeyList_SetKey2(This,wszName,uFlags,uCimType,pKeyVal) (This)->lpVtbl->SetKey2(This,wszName,uFlags,uCimType,pKeyVal)
#define IWbemPathKeyList_GetKey(This,uKeyIx,uFlags,puNameBufSize,pszKeyName,puKeyValBufSize,pKeyVal,puApparentCimType) (This)->lpVtbl->GetKey(This,uKeyIx,uFlags,puNameBufSize,pszKeyName,puKeyValBufSize,pKeyVal,puApparentCimType)
#define IWbemPathKeyList_GetKey2(This,uKeyIx,uFlags,puNameBufSize,pszKeyName,pKeyValue,puApparentCimType) (This)->lpVtbl->GetKey2(This,uKeyIx,uFlags,puNameBufSize,pszKeyName,pKeyValue,puApparentCimType)
#define IWbemPathKeyList_RemoveKey(This,wszName,uFlags) (This)->lpVtbl->RemoveKey(This,wszName,uFlags)
#define IWbemPathKeyList_RemoveAllKeys(This,uFlags) (This)->lpVtbl->RemoveAllKeys(This,uFlags)
#define IWbemPathKeyList_MakeSingleton(This,bSet) (This)->lpVtbl->MakeSingleton(This,bSet)
#define IWbemPathKeyList_GetInfo(This,uRequestedInfo,puResponse) (This)->lpVtbl->GetInfo(This,uRequestedInfo,puResponse)
#define IWbemPathKeyList_GetText(This,lFlags,puBuffLength,pszText) (This)->lpVtbl->GetText(This,lFlags,puBuffLength,pszText)
#endif
#endif
  HRESULT WINAPI IWbemPathKeyList_GetCount_Proxy(IWbemPathKeyList *This,ULONG *puKeyCount);
  void __RPC_STUB IWbemPathKeyList_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_SetKey_Proxy(IWbemPathKeyList *This,LPCWSTR wszName,ULONG uFlags,ULONG uCimType,LPVOID pKeyVal);
  void __RPC_STUB IWbemPathKeyList_SetKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_SetKey2_Proxy(IWbemPathKeyList *This,LPCWSTR wszName,ULONG uFlags,ULONG uCimType,VARIANT *pKeyVal);
  void __RPC_STUB IWbemPathKeyList_SetKey2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_GetKey_Proxy(IWbemPathKeyList *This,ULONG uKeyIx,ULONG uFlags,ULONG *puNameBufSize,LPWSTR pszKeyName,ULONG *puKeyValBufSize,LPVOID pKeyVal,ULONG *puApparentCimType);
  void __RPC_STUB IWbemPathKeyList_GetKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_GetKey2_Proxy(IWbemPathKeyList *This,ULONG uKeyIx,ULONG uFlags,ULONG *puNameBufSize,LPWSTR pszKeyName,VARIANT *pKeyValue,ULONG *puApparentCimType);
  void __RPC_STUB IWbemPathKeyList_GetKey2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_RemoveKey_Proxy(IWbemPathKeyList *This,LPCWSTR wszName,ULONG uFlags);
  void __RPC_STUB IWbemPathKeyList_RemoveKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_RemoveAllKeys_Proxy(IWbemPathKeyList *This,ULONG uFlags);
  void __RPC_STUB IWbemPathKeyList_RemoveAllKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_MakeSingleton_Proxy(IWbemPathKeyList *This,boolean bSet);
  void __RPC_STUB IWbemPathKeyList_MakeSingleton_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_GetInfo_Proxy(IWbemPathKeyList *This,ULONG uRequestedInfo,ULONGLONG *puResponse);
  void __RPC_STUB IWbemPathKeyList_GetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPathKeyList_GetText_Proxy(IWbemPathKeyList *This,__LONG32 lFlags,ULONG *puBuffLength,LPWSTR pszText);
  void __RPC_STUB IWbemPathKeyList_GetText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWbemPath_INTERFACE_DEFINED__
#define __IWbemPath_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWbemPath;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWbemPath : public IUnknown {
  public:
    virtual HRESULT WINAPI SetText(ULONG uMode,LPCWSTR pszPath) = 0;
    virtual HRESULT WINAPI GetText(__LONG32 lFlags,ULONG *puBuffLength,LPWSTR pszText) = 0;
    virtual HRESULT WINAPI GetInfo(ULONG uRequestedInfo,ULONGLONG *puResponse) = 0;
    virtual HRESULT WINAPI SetServer(LPCWSTR Name) = 0;
    virtual HRESULT WINAPI GetServer(ULONG *puNameBufLength,LPWSTR pName) = 0;
    virtual HRESULT WINAPI GetNamespaceCount(ULONG *puCount) = 0;
    virtual HRESULT WINAPI SetNamespaceAt(ULONG uIndex,LPCWSTR pszName) = 0;
    virtual HRESULT WINAPI GetNamespaceAt(ULONG uIndex,ULONG *puNameBufLength,LPWSTR pName) = 0;
    virtual HRESULT WINAPI RemoveNamespaceAt(ULONG uIndex) = 0;
    virtual HRESULT WINAPI RemoveAllNamespaces(void) = 0;
    virtual HRESULT WINAPI GetScopeCount(ULONG *puCount) = 0;
    virtual HRESULT WINAPI SetScope(ULONG uIndex,LPWSTR pszClass) = 0;
    virtual HRESULT WINAPI SetScopeFromText(ULONG uIndex,LPWSTR pszText) = 0;
    virtual HRESULT WINAPI GetScope(ULONG uIndex,ULONG *puClassNameBufSize,LPWSTR pszClass,IWbemPathKeyList **pKeyList) = 0;
    virtual HRESULT WINAPI GetScopeAsText(ULONG uIndex,ULONG *puTextBufSize,LPWSTR pszText) = 0;
    virtual HRESULT WINAPI RemoveScope(ULONG uIndex) = 0;
    virtual HRESULT WINAPI RemoveAllScopes(void) = 0;
    virtual HRESULT WINAPI SetClassName(LPCWSTR Name) = 0;
    virtual HRESULT WINAPI GetClassName(ULONG *puBuffLength,LPWSTR pszName) = 0;
    virtual HRESULT WINAPI GetKeyList(IWbemPathKeyList **pOut) = 0;
    virtual HRESULT WINAPI CreateClassPart(__LONG32 lFlags,LPCWSTR Name) = 0;
    virtual HRESULT WINAPI DeleteClassPart(__LONG32 lFlags) = 0;
    virtual WINBOOL WINAPI IsRelative(LPWSTR wszMachine,LPWSTR wszNamespace) = 0;
    virtual WINBOOL WINAPI IsRelativeOrChild(LPWSTR wszMachine,LPWSTR wszNamespace,__LONG32 lFlags) = 0;
    virtual WINBOOL WINAPI IsLocal(LPCWSTR wszMachine) = 0;
    virtual WINBOOL WINAPI IsSameClassName(LPCWSTR wszClass) = 0;
  };
#else
  typedef struct IWbemPathVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWbemPath *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWbemPath *This);
      ULONG (WINAPI *Release)(IWbemPath *This);
      HRESULT (WINAPI *SetText)(IWbemPath *This,ULONG uMode,LPCWSTR pszPath);
      HRESULT (WINAPI *GetText)(IWbemPath *This,__LONG32 lFlags,ULONG *puBuffLength,LPWSTR pszText);
      HRESULT (WINAPI *GetInfo)(IWbemPath *This,ULONG uRequestedInfo,ULONGLONG *puResponse);
      HRESULT (WINAPI *SetServer)(IWbemPath *This,LPCWSTR Name);
      HRESULT (WINAPI *GetServer)(IWbemPath *This,ULONG *puNameBufLength,LPWSTR pName);
      HRESULT (WINAPI *GetNamespaceCount)(IWbemPath *This,ULONG *puCount);
      HRESULT (WINAPI *SetNamespaceAt)(IWbemPath *This,ULONG uIndex,LPCWSTR pszName);
      HRESULT (WINAPI *GetNamespaceAt)(IWbemPath *This,ULONG uIndex,ULONG *puNameBufLength,LPWSTR pName);
      HRESULT (WINAPI *RemoveNamespaceAt)(IWbemPath *This,ULONG uIndex);
      HRESULT (WINAPI *RemoveAllNamespaces)(IWbemPath *This);
      HRESULT (WINAPI *GetScopeCount)(IWbemPath *This,ULONG *puCount);
      HRESULT (WINAPI *SetScope)(IWbemPath *This,ULONG uIndex,LPWSTR pszClass);
      HRESULT (WINAPI *SetScopeFromText)(IWbemPath *This,ULONG uIndex,LPWSTR pszText);
      HRESULT (WINAPI *GetScope)(IWbemPath *This,ULONG uIndex,ULONG *puClassNameBufSize,LPWSTR pszClass,IWbemPathKeyList **pKeyList);
      HRESULT (WINAPI *GetScopeAsText)(IWbemPath *This,ULONG uIndex,ULONG *puTextBufSize,LPWSTR pszText);
      HRESULT (WINAPI *RemoveScope)(IWbemPath *This,ULONG uIndex);
      HRESULT (WINAPI *RemoveAllScopes)(IWbemPath *This);
      HRESULT (WINAPI *SetClassName)(IWbemPath *This,LPCWSTR Name);
      HRESULT (WINAPI *GetClassName)(IWbemPath *This,ULONG *puBuffLength,LPWSTR pszName);
      HRESULT (WINAPI *GetKeyList)(IWbemPath *This,IWbemPathKeyList **pOut);
      HRESULT (WINAPI *CreateClassPart)(IWbemPath *This,__LONG32 lFlags,LPCWSTR Name);
      HRESULT (WINAPI *DeleteClassPart)(IWbemPath *This,__LONG32 lFlags);
      WINBOOL (WINAPI *IsRelative)(IWbemPath *This,LPWSTR wszMachine,LPWSTR wszNamespace);
      WINBOOL (WINAPI *IsRelativeOrChild)(IWbemPath *This,LPWSTR wszMachine,LPWSTR wszNamespace,__LONG32 lFlags);
      WINBOOL (WINAPI *IsLocal)(IWbemPath *This,LPCWSTR wszMachine);
      WINBOOL (WINAPI *IsSameClassName)(IWbemPath *This,LPCWSTR wszClass);
    END_INTERFACE
  } IWbemPathVtbl;
  struct IWbemPath {
    CONST_VTBL struct IWbemPathVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWbemPath_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWbemPath_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWbemPath_Release(This) (This)->lpVtbl->Release(This)
#define IWbemPath_SetText(This,uMode,pszPath) (This)->lpVtbl->SetText(This,uMode,pszPath)
#define IWbemPath_GetText(This,lFlags,puBuffLength,pszText) (This)->lpVtbl->GetText(This,lFlags,puBuffLength,pszText)
#define IWbemPath_GetInfo(This,uRequestedInfo,puResponse) (This)->lpVtbl->GetInfo(This,uRequestedInfo,puResponse)
#define IWbemPath_SetServer(This,Name) (This)->lpVtbl->SetServer(This,Name)
#define IWbemPath_GetServer(This,puNameBufLength,pName) (This)->lpVtbl->GetServer(This,puNameBufLength,pName)
#define IWbemPath_GetNamespaceCount(This,puCount) (This)->lpVtbl->GetNamespaceCount(This,puCount)
#define IWbemPath_SetNamespaceAt(This,uIndex,pszName) (This)->lpVtbl->SetNamespaceAt(This,uIndex,pszName)
#define IWbemPath_GetNamespaceAt(This,uIndex,puNameBufLength,pName) (This)->lpVtbl->GetNamespaceAt(This,uIndex,puNameBufLength,pName)
#define IWbemPath_RemoveNamespaceAt(This,uIndex) (This)->lpVtbl->RemoveNamespaceAt(This,uIndex)
#define IWbemPath_RemoveAllNamespaces(This) (This)->lpVtbl->RemoveAllNamespaces(This)
#define IWbemPath_GetScopeCount(This,puCount) (This)->lpVtbl->GetScopeCount(This,puCount)
#define IWbemPath_SetScope(This,uIndex,pszClass) (This)->lpVtbl->SetScope(This,uIndex,pszClass)
#define IWbemPath_SetScopeFromText(This,uIndex,pszText) (This)->lpVtbl->SetScopeFromText(This,uIndex,pszText)
#define IWbemPath_GetScope(This,uIndex,puClassNameBufSize,pszClass,pKeyList) (This)->lpVtbl->GetScope(This,uIndex,puClassNameBufSize,pszClass,pKeyList)
#define IWbemPath_GetScopeAsText(This,uIndex,puTextBufSize,pszText) (This)->lpVtbl->GetScopeAsText(This,uIndex,puTextBufSize,pszText)
#define IWbemPath_RemoveScope(This,uIndex) (This)->lpVtbl->RemoveScope(This,uIndex)
#define IWbemPath_RemoveAllScopes(This) (This)->lpVtbl->RemoveAllScopes(This)
#define IWbemPath_SetClassName(This,Name) (This)->lpVtbl->SetClassName(This,Name)
#define IWbemPath_GetClassName(This,puBuffLength,pszName) (This)->lpVtbl->GetClassName(This,puBuffLength,pszName)
#define IWbemPath_GetKeyList(This,pOut) (This)->lpVtbl->GetKeyList(This,pOut)
#define IWbemPath_CreateClassPart(This,lFlags,Name) (This)->lpVtbl->CreateClassPart(This,lFlags,Name)
#define IWbemPath_DeleteClassPart(This,lFlags) (This)->lpVtbl->DeleteClassPart(This,lFlags)
#define IWbemPath_IsRelative(This,wszMachine,wszNamespace) (This)->lpVtbl->IsRelative(This,wszMachine,wszNamespace)
#define IWbemPath_IsRelativeOrChild(This,wszMachine,wszNamespace,lFlags) (This)->lpVtbl->IsRelativeOrChild(This,wszMachine,wszNamespace,lFlags)
#define IWbemPath_IsLocal(This,wszMachine) (This)->lpVtbl->IsLocal(This,wszMachine)
#define IWbemPath_IsSameClassName(This,wszClass) (This)->lpVtbl->IsSameClassName(This,wszClass)
#endif
#endif
  HRESULT WINAPI IWbemPath_SetText_Proxy(IWbemPath *This,ULONG uMode,LPCWSTR pszPath);
  void __RPC_STUB IWbemPath_SetText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetText_Proxy(IWbemPath *This,__LONG32 lFlags,ULONG *puBuffLength,LPWSTR pszText);
  void __RPC_STUB IWbemPath_GetText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetInfo_Proxy(IWbemPath *This,ULONG uRequestedInfo,ULONGLONG *puResponse);
  void __RPC_STUB IWbemPath_GetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_SetServer_Proxy(IWbemPath *This,LPCWSTR Name);
  void __RPC_STUB IWbemPath_SetServer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetServer_Proxy(IWbemPath *This,ULONG *puNameBufLength,LPWSTR pName);
  void __RPC_STUB IWbemPath_GetServer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetNamespaceCount_Proxy(IWbemPath *This,ULONG *puCount);
  void __RPC_STUB IWbemPath_GetNamespaceCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_SetNamespaceAt_Proxy(IWbemPath *This,ULONG uIndex,LPCWSTR pszName);
  void __RPC_STUB IWbemPath_SetNamespaceAt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetNamespaceAt_Proxy(IWbemPath *This,ULONG uIndex,ULONG *puNameBufLength,LPWSTR pName);
  void __RPC_STUB IWbemPath_GetNamespaceAt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_RemoveNamespaceAt_Proxy(IWbemPath *This,ULONG uIndex);
  void __RPC_STUB IWbemPath_RemoveNamespaceAt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_RemoveAllNamespaces_Proxy(IWbemPath *This);
  void __RPC_STUB IWbemPath_RemoveAllNamespaces_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetScopeCount_Proxy(IWbemPath *This,ULONG *puCount);
  void __RPC_STUB IWbemPath_GetScopeCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_SetScope_Proxy(IWbemPath *This,ULONG uIndex,LPWSTR pszClass);
  void __RPC_STUB IWbemPath_SetScope_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_SetScopeFromText_Proxy(IWbemPath *This,ULONG uIndex,LPWSTR pszText);
  void __RPC_STUB IWbemPath_SetScopeFromText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetScope_Proxy(IWbemPath *This,ULONG uIndex,ULONG *puClassNameBufSize,LPWSTR pszClass,IWbemPathKeyList **pKeyList);
  void __RPC_STUB IWbemPath_GetScope_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetScopeAsText_Proxy(IWbemPath *This,ULONG uIndex,ULONG *puTextBufSize,LPWSTR pszText);
  void __RPC_STUB IWbemPath_GetScopeAsText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_RemoveScope_Proxy(IWbemPath *This,ULONG uIndex);
  void __RPC_STUB IWbemPath_RemoveScope_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_RemoveAllScopes_Proxy(IWbemPath *This);
  void __RPC_STUB IWbemPath_RemoveAllScopes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_SetClassName_Proxy(IWbemPath *This,LPCWSTR Name);
  void __RPC_STUB IWbemPath_SetClassName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetClassName_Proxy(IWbemPath *This,ULONG *puBuffLength,LPWSTR pszName);
  void __RPC_STUB IWbemPath_GetClassName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_GetKeyList_Proxy(IWbemPath *This,IWbemPathKeyList **pOut);
  void __RPC_STUB IWbemPath_GetKeyList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_CreateClassPart_Proxy(IWbemPath *This,__LONG32 lFlags,LPCWSTR Name);
  void __RPC_STUB IWbemPath_CreateClassPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemPath_DeleteClassPart_Proxy(IWbemPath *This,__LONG32 lFlags);
  void __RPC_STUB IWbemPath_DeleteClassPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IWbemPath_IsRelative_Proxy(IWbemPath *This,LPWSTR wszMachine,LPWSTR wszNamespace);
  void __RPC_STUB IWbemPath_IsRelative_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IWbemPath_IsRelativeOrChild_Proxy(IWbemPath *This,LPWSTR wszMachine,LPWSTR wszNamespace,__LONG32 lFlags);
  void __RPC_STUB IWbemPath_IsRelativeOrChild_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IWbemPath_IsLocal_Proxy(IWbemPath *This,LPCWSTR wszMachine);
  void __RPC_STUB IWbemPath_IsLocal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IWbemPath_IsSameClassName_Proxy(IWbemPath *This,LPCWSTR wszClass);
  void __RPC_STUB IWbemPath_IsSameClassName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_WbemDefPath;
#ifdef __cplusplus
  class WbemDefPath;
#endif

#ifndef __IWbemQuery_INTERFACE_DEFINED__
#define __IWbemQuery_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWbemQuery;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWbemQuery : public IUnknown {
  public:
    virtual HRESULT WINAPI Empty(void) = 0;
    virtual HRESULT WINAPI SetLanguageFeatures(ULONG uFlags,ULONG uArraySize,ULONG *puFeatures) = 0;
    virtual HRESULT WINAPI TestLanguageFeatures(ULONG uFlags,ULONG *uArraySize,ULONG *puFeatures) = 0;
    virtual HRESULT WINAPI Parse(LPCWSTR pszLang,LPCWSTR pszQuery,ULONG uFlags) = 0;
    virtual HRESULT WINAPI GetAnalysis(ULONG uAnalysisType,ULONG uFlags,LPVOID *pAnalysis) = 0;
    virtual HRESULT WINAPI FreeMemory(LPVOID pMem) = 0;
    virtual HRESULT WINAPI GetQueryInfo(ULONG uAnalysisType,ULONG uInfoId,ULONG uBufSize,LPVOID pDestBuf) = 0;
  };
#else
  typedef struct IWbemQueryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWbemQuery *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWbemQuery *This);
      ULONG (WINAPI *Release)(IWbemQuery *This);
      HRESULT (WINAPI *Empty)(IWbemQuery *This);
      HRESULT (WINAPI *SetLanguageFeatures)(IWbemQuery *This,ULONG uFlags,ULONG uArraySize,ULONG *puFeatures);
      HRESULT (WINAPI *TestLanguageFeatures)(IWbemQuery *This,ULONG uFlags,ULONG *uArraySize,ULONG *puFeatures);
      HRESULT (WINAPI *Parse)(IWbemQuery *This,LPCWSTR pszLang,LPCWSTR pszQuery,ULONG uFlags);
      HRESULT (WINAPI *GetAnalysis)(IWbemQuery *This,ULONG uAnalysisType,ULONG uFlags,LPVOID *pAnalysis);
      HRESULT (WINAPI *FreeMemory)(IWbemQuery *This,LPVOID pMem);
      HRESULT (WINAPI *GetQueryInfo)(IWbemQuery *This,ULONG uAnalysisType,ULONG uInfoId,ULONG uBufSize,LPVOID pDestBuf);
    END_INTERFACE
  } IWbemQueryVtbl;
  struct IWbemQuery {
    CONST_VTBL struct IWbemQueryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWbemQuery_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWbemQuery_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWbemQuery_Release(This) (This)->lpVtbl->Release(This)
#define IWbemQuery_Empty(This) (This)->lpVtbl->Empty(This)
#define IWbemQuery_SetLanguageFeatures(This,uFlags,uArraySize,puFeatures) (This)->lpVtbl->SetLanguageFeatures(This,uFlags,uArraySize,puFeatures)
#define IWbemQuery_TestLanguageFeatures(This,uFlags,uArraySize,puFeatures) (This)->lpVtbl->TestLanguageFeatures(This,uFlags,uArraySize,puFeatures)
#define IWbemQuery_Parse(This,pszLang,pszQuery,uFlags) (This)->lpVtbl->Parse(This,pszLang,pszQuery,uFlags)
#define IWbemQuery_GetAnalysis(This,uAnalysisType,uFlags,pAnalysis) (This)->lpVtbl->GetAnalysis(This,uAnalysisType,uFlags,pAnalysis)
#define IWbemQuery_FreeMemory(This,pMem) (This)->lpVtbl->FreeMemory(This,pMem)
#define IWbemQuery_GetQueryInfo(This,uAnalysisType,uInfoId,uBufSize,pDestBuf) (This)->lpVtbl->GetQueryInfo(This,uAnalysisType,uInfoId,uBufSize,pDestBuf)
#endif
#endif
  HRESULT WINAPI IWbemQuery_Empty_Proxy(IWbemQuery *This);
  void __RPC_STUB IWbemQuery_Empty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemQuery_SetLanguageFeatures_Proxy(IWbemQuery *This,ULONG uFlags,ULONG uArraySize,ULONG *puFeatures);
  void __RPC_STUB IWbemQuery_SetLanguageFeatures_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemQuery_TestLanguageFeatures_Proxy(IWbemQuery *This,ULONG uFlags,ULONG *uArraySize,ULONG *puFeatures);
  void __RPC_STUB IWbemQuery_TestLanguageFeatures_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemQuery_Parse_Proxy(IWbemQuery *This,LPCWSTR pszLang,LPCWSTR pszQuery,ULONG uFlags);
  void __RPC_STUB IWbemQuery_Parse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemQuery_GetAnalysis_Proxy(IWbemQuery *This,ULONG uAnalysisType,ULONG uFlags,LPVOID *pAnalysis);
  void __RPC_STUB IWbemQuery_GetAnalysis_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemQuery_FreeMemory_Proxy(IWbemQuery *This,LPVOID pMem);
  void __RPC_STUB IWbemQuery_FreeMemory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWbemQuery_GetQueryInfo_Proxy(IWbemQuery *This,ULONG uAnalysisType,ULONG uInfoId,ULONG uBufSize,LPVOID pDestBuf);
  void __RPC_STUB IWbemQuery_GetQueryInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_WbemQuery;
#ifdef __cplusplus
  class WbemQuery;
#endif
#endif

  typedef enum __MIDL___MIDL_itf_wmiutils_0116_0001 {
    WMIQ_ANALYSIS_RPN_SEQUENCE = 0x1,WMIQ_ANALYSIS_ASSOC_QUERY = 0x2,WMIQ_ANALYSIS_PROP_ANALYSIS_MATRIX = 0x3,WMIQ_ANALYSIS_QUERY_TEXT = 0x4,
    WMIQ_ANALYSIS_RESERVED = 0x8000000
  } WMIQ_ANALYSIS_TYPE;

  typedef enum __MIDL___MIDL_itf_wmiutils_0116_0002 {
    WMIQ_RPN_TOKEN_EXPRESSION = 1,WMIQ_RPN_TOKEN_AND = 2,WMIQ_RPN_TOKEN_OR = 3,WMIQ_RPN_TOKEN_NOT = 4,WMIQ_RPN_OP_UNDEFINED = 0,WMIQ_RPN_OP_EQ = 1,
    WMIQ_RPN_OP_NE = 2,WMIQ_RPN_OP_GE = 3,WMIQ_RPN_OP_LE = 4,WMIQ_RPN_OP_LT = 5,WMIQ_RPN_OP_GT = 6,WMIQ_RPN_OP_LIKE = 7,WMIQ_RPN_OP_ISA = 8,
    WMIQ_RPN_OP_ISNOTA = 9,WMIQ_RPN_OP_ISNULL = 10,WMIQ_RPN_OP_ISNOTNULL = 11,WMIQ_RPN_LEFT_PROPERTY_NAME = 0x1,WMIQ_RPN_RIGHT_PROPERTY_NAME = 0x2,
    WMIQ_RPN_CONST2 = 0x4,WMIQ_RPN_CONST = 0x8,WMIQ_RPN_RELOP = 0x10,WMIQ_RPN_LEFT_FUNCTION = 0x20,WMIQ_RPN_RIGHT_FUNCTION = 0x40,
    WMIQ_RPN_GET_TOKEN_TYPE = 1,WMIQ_RPN_GET_EXPR_SHAPE = 2,WMIQ_RPN_GET_LEFT_FUNCTION = 3,WMIQ_RPN_GET_RIGHT_FUNCTION = 4,WMIQ_RPN_GET_RELOP = 5,
    WMIQ_RPN_NEXT_TOKEN = 1,WMIQ_RPN_FROM_UNARY = 0x1,WMIQ_RPN_FROM_PATH = 0x2,WMIQ_RPN_FROM_CLASS_LIST = 0x4,WMIQ_RPN_FROM_MULTIPLE = 0x8
  } WMIQ_RPN_TOKEN_FLAGS;

  typedef enum __MIDL___MIDL_itf_wmiutils_0116_0003 {
    WMIQ_ASSOCQ_ASSOCIATORS = 0x1,WMIQ_ASSOCQ_REFERENCES = 0x2,WMIQ_ASSOCQ_RESULTCLASS = 0x4,WMIQ_ASSOCQ_ASSOCCLASS = 0x8,WMIQ_ASSOCQ_ROLE = 0x10,
    WMIQ_ASSOCQ_RESULTROLE = 0x20,WMIQ_ASSOCQ_REQUIREDQUALIFIER = 0x40,WMIQ_ASSOCQ_REQUIREDASSOCQUALIFIER = 0x80,WMIQ_ASSOCQ_CLASSDEFSONLY = 0x100,
    WMIQ_ASSOCQ_KEYSONLY = 0x200,WMIQ_ASSOCQ_SCHEMAONLY = 0x400,WMIQ_ASSOCQ_CLASSREFSONLY = 0x800
  } WMIQ_ASSOCQ_FLAGS;

  typedef struct tag_SWbemQueryQualifiedName {
    ULONG m_uVersion;
    ULONG m_uTokenType;
    ULONG m_uNameListSize;
    LPCWSTR *m_ppszNameList;
    WINBOOL m_bArraysUsed;
    WINBOOL *m_pbArrayElUsed;
    ULONG *m_puArrayIndex;
  } SWbemQueryQualifiedName;

  typedef union tag_SWbemRpnConst {
    LPCWSTR m_pszStrVal;
    WINBOOL m_bBoolVal;
    LONG m_lLongVal;
    ULONG m_uLongVal;
    double m_dblVal;
    __MINGW_EXTENSION __int64 m_lVal64;
    __MINGW_EXTENSION __int64 m_uVal64;
  } SWbemRpnConst;

  typedef struct tag_SWbemRpnQueryToken {
    ULONG m_uVersion;
    ULONG m_uTokenType;
    ULONG m_uSubexpressionShape;
    ULONG m_uOperator;
    SWbemQueryQualifiedName *m_pRightIdent;
    SWbemQueryQualifiedName *m_pLeftIdent;
    ULONG m_uConstApparentType;
    SWbemRpnConst m_Const;
    ULONG m_uConst2ApparentType;
    SWbemRpnConst m_Const2;
    LPCWSTR m_pszRightFunc;
    LPCWSTR m_pszLeftFunc;
  } SWbemRpnQueryToken;

  typedef struct tag_SWbemRpnTokenList {
    ULONG m_uVersion;
    ULONG m_uTokenType;
    ULONG m_uNumTokens;
  } SWbemRpnTokenList;

  typedef enum tag_WMIQ_LANGUAGE_FEATURES {
    WMIQ_LF1_BASIC_SELECT = 1,WMIQ_LF2_CLASS_NAME_IN_QUERY = 2,WMIQ_LF3_STRING_CASE_FUNCTIONS = 3,WMIQ_LF4_PROP_TO_PROP_TESTS = 4,
    WMIQ_LF5_COUNT_STAR = 5,WMIQ_LF6_ORDER_BY = 6,WMIQ_LF7_DISTINCT = 7,WMIQ_LF8_ISA = 8,WMIQ_LF9_THIS = 9,WMIQ_LF10_COMPEX_SUBEXPRESSIONS = 10,
    WMIQ_LF11_ALIASING = 11,WMIQ_LF12_GROUP_BY_HAVING = 12,WMIQ_LF13_WMI_WITHIN = 13,WMIQ_LF14_SQL_WRITE_OPERATIONS = 14,WMIQ_LF15_GO = 15,
    WMIQ_LF16_SINGLE_LEVEL_TRANSACTIONS = 16,WMIQ_LF17_QUALIFIED_NAMES = 17,WMIQ_LF18_ASSOCIATONS = 18,WMIQ_LF19_SYSTEM_PROPERTIES = 19,
    WMIQ_LF20_EXTENDED_SYSTEM_PROPERTIES = 20,WMIQ_LF21_SQL89_JOINS = 21,WMIQ_LF22_SQL92_JOINS = 22,WMIQ_LF23_SUBSELECTS = 23,
    WMIQ_LF24_UMI_EXTENSIONS = 24,WMIQ_LF25_DATEPART = 25,WMIQ_LF26_LIKE = 26,WMIQ_LF27_CIM_TEMPORAL_CONSTRUCTS = 27,
    WMIQ_LF28_STANDARD_AGGREGATES = 28,WMIQ_LF29_MULTI_LEVEL_ORDER_BY = 29,WMIQ_LF30_WMI_PRAGMAS = 30,WMIQ_LF31_QUALIFIER_TESTS = 31,
    WMIQ_LF32_SP_EXECUTE = 32,WMIQ_LF33_ARRAY_ACCESS = 33,WMIQ_LF34_UNION = 34,WMIQ_LF35_COMPLEX_SELECT_TARGET = 35,WMIQ_LF36_REFERENCE_TESTS = 36,
    WMIQ_LF37_SELECT_INTO = 37,WMIQ_LF38_BASIC_DATETIME_TESTS = 38,WMIQ_LF39_COUNT_COLUMN = 39,WMIQ_LF40_BETWEEN = 40,WMIQ_LF_LAST = 40
  } WMIQ_LANGUAGE_FEATURES;

  typedef enum tag_WMIQ_RPNQ_FEATURE {
    WMIQ_RPNF_WHERE_CLAUSE_PRESENT = 0x1,WMIQ_RPNF_QUERY_IS_CONJUNCTIVE = 0x2,WMIQ_RPNF_QUERY_IS_DISJUNCTIVE = 0x4,WMIQ_RPNF_PROJECTION = 0x8,
    WMIQ_RPNF_FEATURE_SELECT_STAR = 0x10,WMIQ_RPNF_EQUALITY_TESTS_ONLY = 0x20,WMIQ_RPNF_COUNT_STAR = 0x40,WMIQ_RPNF_QUALIFIED_NAMES_USED = 0x80,
    WMIQ_RPNF_SYSPROP_CLASS_USED = 0x100,WMIQ_RPNF_PROP_TO_PROP_TESTS = 0x200,WMIQ_RPNF_ORDER_BY = 0x400,WMIQ_RPNF_ISA_USED = 0x800,
    WMIQ_RPNF_GROUP_BY_HAVING = 0x1000,WMIQ_RPNF_ARRAY_ACCESS_USED = 0x2000
  } WMIQ_RPNF_FEATURE;

  typedef struct tag_SWbemRpnEncodedQuery {
    ULONG m_uVersion;
    ULONG m_uTokenType;
    __MINGW_EXTENSION unsigned __int64 m_uParsedFeatureMask;
    ULONG m_uDetectedArraySize;
    ULONG *m_puDetectedFeatures;
    ULONG m_uSelectListSize;
    SWbemQueryQualifiedName **m_ppSelectList;
    ULONG m_uFromTargetType;
    LPCWSTR m_pszOptionalFromPath;
    ULONG m_uFromListSize;
    LPCWSTR *m_ppszFromList;
    ULONG m_uWhereClauseSize;
    SWbemRpnQueryToken **m_ppRpnWhereClause;
    double m_dblWithinPolling;
    double m_dblWithinWindow;
    ULONG m_uOrderByListSize;
    LPCWSTR *m_ppszOrderByList;
    ULONG *m_uOrderDirectionEl;
  } SWbemRpnEncodedQuery;

  typedef struct tag_SWbemAnalysisMatrix {
    ULONG m_uVersion;
    ULONG m_uMatrixType;
    LPCWSTR m_pszProperty;
    ULONG m_uPropertyType;
    ULONG m_uEntries;
    LPVOID *m_pValues;
    WINBOOL *m_pbTruthTable;
  } SWbemAnalysisMatrix;

  typedef struct tag_SWbemAnalysisMatrixList {
    ULONG m_uVersion;
    ULONG m_uMatrixType;
    ULONG m_uNumMatrices;
    SWbemAnalysisMatrix *m_pMatrices;
  } SWbemAnalysisMatrixList;

  typedef struct tag_SWbemAssocQueryInf {
    ULONG m_uVersion;
    ULONG m_uAnalysisType;
    ULONG m_uFeatureMask;
    IWbemPath *m_pPath;
    LPWSTR m_pszPath;
    LPWSTR m_pszQueryText;
    LPWSTR m_pszResultClass;
    LPWSTR m_pszAssocClass;
    LPWSTR m_pszRole;
    LPWSTR m_pszResultRole;
    LPWSTR m_pszRequiredQualifier;
    LPWSTR m_pszRequiredAssocQualifier;
  } SWbemAssocQueryInf;

  extern RPC_IF_HANDLE __MIDL_itf_wmiutils_0116_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_wmiutils_0116_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
