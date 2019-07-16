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

#ifndef __chanmgr_h__
#define __chanmgr_h__

#ifndef __IChannelMgr_FWD_DEFINED__
#define __IChannelMgr_FWD_DEFINED__
typedef struct IChannelMgr IChannelMgr;
#endif

#ifndef __IEnumChannels_FWD_DEFINED__
#define __IEnumChannels_FWD_DEFINED__
typedef struct IEnumChannels IEnumChannels;
#endif

#ifndef __ChannelMgr_FWD_DEFINED__
#define __ChannelMgr_FWD_DEFINED__
#ifdef __cplusplus
typedef class ChannelMgr ChannelMgr;
#else
typedef struct ChannelMgr ChannelMgr;
#endif
#endif

#include "unknwn.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_chanmgr_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_chanmgr_0000_v0_0_s_ifspec;

#ifndef __CHANNELMGR_LIBRARY_DEFINED__
#define __CHANNELMGR_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_CHANNELMGR;
#ifndef __IChannelMgr_INTERFACE_DEFINED__
#define __IChannelMgr_INTERFACE_DEFINED__

  typedef struct _tagChannelShortcutInfo {
    DWORD cbSize;
    LPWSTR pszTitle;
    LPWSTR pszURL;
    LPWSTR pszLogo;
    LPWSTR pszIcon;
    LPWSTR pszWideLogo;
    WINBOOL bIsSoftware;
  } CHANNELSHORTCUTINFO;

  typedef struct _tagChannelCategoryInfo {
    DWORD cbSize;
    LPWSTR pszTitle;
    LPWSTR pszURL;
    LPWSTR pszLogo;
    LPWSTR pszIcon;
    LPWSTR pszWideLogo;
  } CHANNELCATEGORYINFO;

  typedef enum _tagChannelEnumFlags {
    CHANENUM_CHANNELFOLDER = 0x1,CHANENUM_SOFTUPDATEFOLDER = 0x2,CHANENUM_DESKTOPFOLDER = 0x4,CHANENUM_TITLE = 0x10000,CHANENUM_PATH = 0x20000,
    CHANENUM_URL = 0x40000,CHANENUM_SUBSCRIBESTATE = 0x80000
  } CHANNELENUMFLAGS;

#define CHANENUM_ALLFOLDERS (CHANENUM_CHANNELFOLDER | CHANENUM_SOFTUPDATEFOLDER | CHANENUM_DESKTOPFOLDER)
#define CHANENUM_ALLDATA (CHANENUM_TITLE | CHANENUM_PATH | CHANENUM_URL | CHANENUM_SUBSCRIBESTATE)
#define CHANENUM_ALL (CHANENUM_CHANNELFOLDER | CHANENUM_SOFTUPDATEFOLDER | CHANENUM_DESKTOPFOLDER | CHANENUM_TITLE | CHANENUM_PATH | CHANENUM_URL | CHANENUM_SUBSCRIBESTATE)

  EXTERN_C const IID IID_IChannelMgr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IChannelMgr : public IUnknown {
  public:
    virtual HRESULT WINAPI AddChannelShortcut(CHANNELSHORTCUTINFO *pChannelInfo) = 0;
    virtual HRESULT WINAPI DeleteChannelShortcut(LPWSTR pszTitle) = 0;
    virtual HRESULT WINAPI AddCategory(CHANNELCATEGORYINFO *pCategoryInfo) = 0;
    virtual HRESULT WINAPI DeleteCategory(LPWSTR pszTitle) = 0;
    virtual HRESULT WINAPI EnumChannels(DWORD dwEnumFlags,LPCWSTR pszURL,IEnumChannels **pIEnumChannels) = 0;
  };
#else
  typedef struct IChannelMgrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IChannelMgr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IChannelMgr *This);
      ULONG (WINAPI *Release)(IChannelMgr *This);
      HRESULT (WINAPI *AddChannelShortcut)(IChannelMgr *This,CHANNELSHORTCUTINFO *pChannelInfo);
      HRESULT (WINAPI *DeleteChannelShortcut)(IChannelMgr *This,LPWSTR pszTitle);
      HRESULT (WINAPI *AddCategory)(IChannelMgr *This,CHANNELCATEGORYINFO *pCategoryInfo);
      HRESULT (WINAPI *DeleteCategory)(IChannelMgr *This,LPWSTR pszTitle);
      HRESULT (WINAPI *EnumChannels)(IChannelMgr *This,DWORD dwEnumFlags,LPCWSTR pszURL,IEnumChannels **pIEnumChannels);
    END_INTERFACE
  } IChannelMgrVtbl;
  struct IChannelMgr {
    CONST_VTBL struct IChannelMgrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IChannelMgr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IChannelMgr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IChannelMgr_Release(This) (This)->lpVtbl->Release(This)
#define IChannelMgr_AddChannelShortcut(This,pChannelInfo) (This)->lpVtbl->AddChannelShortcut(This,pChannelInfo)
#define IChannelMgr_DeleteChannelShortcut(This,pszTitle) (This)->lpVtbl->DeleteChannelShortcut(This,pszTitle)
#define IChannelMgr_AddCategory(This,pCategoryInfo) (This)->lpVtbl->AddCategory(This,pCategoryInfo)
#define IChannelMgr_DeleteCategory(This,pszTitle) (This)->lpVtbl->DeleteCategory(This,pszTitle)
#define IChannelMgr_EnumChannels(This,dwEnumFlags,pszURL,pIEnumChannels) (This)->lpVtbl->EnumChannels(This,dwEnumFlags,pszURL,pIEnumChannels)
#endif
#endif
  HRESULT WINAPI IChannelMgr_AddChannelShortcut_Proxy(IChannelMgr *This,CHANNELSHORTCUTINFO *pChannelInfo);
  void __RPC_STUB IChannelMgr_AddChannelShortcut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IChannelMgr_DeleteChannelShortcut_Proxy(IChannelMgr *This,LPWSTR pszTitle);
  void __RPC_STUB IChannelMgr_DeleteChannelShortcut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IChannelMgr_AddCategory_Proxy(IChannelMgr *This,CHANNELCATEGORYINFO *pCategoryInfo);
  void __RPC_STUB IChannelMgr_AddCategory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IChannelMgr_DeleteCategory_Proxy(IChannelMgr *This,LPWSTR pszTitle);
  void __RPC_STUB IChannelMgr_DeleteCategory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IChannelMgr_EnumChannels_Proxy(IChannelMgr *This,DWORD dwEnumFlags,LPCWSTR pszURL,IEnumChannels **pIEnumChannels);
  void __RPC_STUB IChannelMgr_EnumChannels_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumChannels_INTERFACE_DEFINED__
#define __IEnumChannels_INTERFACE_DEFINED__
  typedef enum _tagSubcriptionState {
    SUBSTATE_NOTSUBSCRIBED = 0,SUBSTATE_PARTIALSUBSCRIPTION,SUBSTATE_FULLSUBSCRIPTION
  } SUBSCRIPTIONSTATE;

  typedef struct _tagChannelInfo {
    LPOLESTR pszTitle;
    LPOLESTR pszPath;
    LPOLESTR pszURL;
    SUBSCRIPTIONSTATE stSubscriptionState;
  } CHANNELENUMINFO;

  EXTERN_C const IID IID_IEnumChannels;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumChannels : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,CHANNELENUMINFO *rgChanInf,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumChannels **ppenum) = 0;
  };
#else
  typedef struct IEnumChannelsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumChannels *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumChannels *This);
      ULONG (WINAPI *Release)(IEnumChannels *This);
      HRESULT (WINAPI *Next)(IEnumChannels *This,ULONG celt,CHANNELENUMINFO *rgChanInf,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumChannels *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumChannels *This);
      HRESULT (WINAPI *Clone)(IEnumChannels *This,IEnumChannels **ppenum);
    END_INTERFACE
  } IEnumChannelsVtbl;
  struct IEnumChannels {
    CONST_VTBL struct IEnumChannelsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumChannels_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumChannels_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumChannels_Release(This) (This)->lpVtbl->Release(This)
#define IEnumChannels_Next(This,celt,rgChanInf,pceltFetched) (This)->lpVtbl->Next(This,celt,rgChanInf,pceltFetched)
#define IEnumChannels_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumChannels_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumChannels_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumChannels_Next_Proxy(IEnumChannels *This,ULONG celt,CHANNELENUMINFO *rgChanInf,ULONG *pceltFetched);
  void __RPC_STUB IEnumChannels_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumChannels_Skip_Proxy(IEnumChannels *This,ULONG celt);
  void __RPC_STUB IEnumChannels_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumChannels_Reset_Proxy(IEnumChannels *This);
  void __RPC_STUB IEnumChannels_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumChannels_Clone_Proxy(IEnumChannels *This,IEnumChannels **ppenum);
  void __RPC_STUB IEnumChannels_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_ChannelMgr;
#ifdef __cplusplus
  class ChannelMgr;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
