/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __PSTORE_H__
#define __PSTORE_H__

typedef DWORD PST_PROVIDERCAPABILITIES;

#define PST_PC_PFX 0x00000001
#define PST_PC_HARDWARE 0x00000002
#define PST_PC_SMARTCARD 0x00000004
#define PST_PC_PCMCIA 0x00000008
#define PST_PC_MULTIPLE_REPOSITORIES 0x00000010
#define PST_PC_ROAMABLE 0x00000020

typedef DWORD PST_REPOSITORYCAPABILITIES;

#define PST_RC_REMOVABLE 0x80000000

typedef DWORD PST_KEY;

#define PST_KEY_CURRENT_USER 0x00000000
#define PST_KEY_LOCAL_MACHINE 0x00000001

#define PST_CF_DEFAULT 0x00000000
#define PST_CF_NONE 0x00000001
#define PST_PF_ALWAYS_SHOW 0x00000001
#define PST_PF_NEVER_SHOW 0x00000002
#define PST_NO_OVERWRITE 0x00000002
#define PST_UNRESTRICTED_ITEMDATA 0x00000004
#define PST_PROMPT_QUERY 0x00000008
#define PST_NO_UI_MIGRATION 0x00000010

typedef DWORD PST_ACCESSMODE;

#define PST_READ 0x0001
#define PST_WRITE 0x0002

typedef DWORD PST_ACCESSCLAUSETYPE;

#define PST_AUTHENTICODE 1
#define PST_BINARY_CHECK 2
#define PST_SECURITY_DESCRIPTOR 4
#define PST_SELF_RELATIVE_CLAUSE __MSABI_LONG(0x80000000)

#define PST_AC_SINGLE_CALLER 0
#define PST_AC_TOP_LEVEL_CALLER 1
#define PST_AC_IMMEDIATE_CALLER 2

#define PST_PP_FLUSH_PW_CACHE 0x1

#define MS_BASE_PSTPROVIDER_NAME L"System Protected Storage"

#define MS_BASE_PSTPROVIDER_ID { 0x8a078c30,0x3755,0x11d0,{ 0xa0,0xbd,0x0,0xaa,0x0,0x61,0x42,0x6a } }
#define MS_BASE_PSTPROVIDER_SZID L"8A078C30-3755-11d0-A0BD-00AA0061426A"

#define MS_PFX_PSTPROVIDER_NAME L"PFX Storage Provider"
#define MS_PFX_PSTPROVIDER_ID { 0x3ca94f30,0x7ac1,0x11d0,{0x8c,0x42,0x00,0xc0,0x4f,0xc2,0x99,0xeb} }
#define MS_PFX_PSTPROVIDER_SZID L"3ca94f30-7ac1-11d0-8c42-00c04fc299eb"

#define PST_CONFIGDATA_TYPE_STRING L"Configuration Data"
#define PST_CONFIGDATA_TYPE_GUID { 0x8ec99652,0x8909,0x11d0,{0x8c,0x4d,0x00,0xc0,0x4f,0xc2,0x97,0xeb} }

#define PST_PROTECTEDSTORAGE_SUBTYPE_STRING L"Protected Storage"
#define PST_PROTECTEDSTORAGE_SUBTYPE_GUID { 0xd3121b8e,0x8a7d,0x11d0,{0x8c,0x4f,0x00,0xc0,0x4f,0xc2,0x97,0xeb} }

#define PST_PSTORE_PROVIDERS_SUBTYPE_STRING L"Protected Storage Provider List"
#define PST_PSTORE_PROVIDERS_SUBTYPE_GUID { 0x8ed17a64,0x91d0,0x11d0,{0x8c,0x43,0x00,0xc0,0x4f,0xc2,0xc6,0x21} }

#ifndef PST_E_OK
#define PST_E_OK _HRESULT_TYPEDEF_(0x00000000)
#define PST_E_FAIL _HRESULT_TYPEDEF_(0x800C0001)
#define PST_E_PROV_DLL_NOT_FOUND _HRESULT_TYPEDEF_(0x800C0002)
#define PST_E_INVALID_HANDLE _HRESULT_TYPEDEF_(0x800C0003)
#define PST_E_TYPE_EXISTS _HRESULT_TYPEDEF_(0x800C0004)
#define PST_E_TYPE_NO_EXISTS _HRESULT_TYPEDEF_(0x800C0005)
#define PST_E_INVALID_RULESET _HRESULT_TYPEDEF_(0x800C0006)
#define PST_E_NO_PERMISSIONS _HRESULT_TYPEDEF_(0x800C0007)
#define PST_E_STORAGE_ERROR _HRESULT_TYPEDEF_(0x800C0008)
#define PST_E_CALLER_NOT_VERIFIED _HRESULT_TYPEDEF_(0x800C0009)
#define PST_E_WRONG_PASSWORD _HRESULT_TYPEDEF_(0x800C000A)
#define PST_E_DISK_IMAGE_MISMATCH _HRESULT_TYPEDEF_(0x800C000B)
#define PST_E_UNKNOWN_EXCEPTION _HRESULT_TYPEDEF_(0x800C000D)
#define PST_E_BAD_FLAGS _HRESULT_TYPEDEF_(0x800C000E)
#define PST_E_ITEM_EXISTS _HRESULT_TYPEDEF_(0x800C000F)
#define PST_E_ITEM_NO_EXISTS _HRESULT_TYPEDEF_(0x800C0010)
#define PST_E_SERVICE_UNAVAILABLE _HRESULT_TYPEDEF_(0x800C0011)
#define PST_E_NOTEMPTY _HRESULT_TYPEDEF_(0x800C0012)
#define PST_E_INVALID_STRING _HRESULT_TYPEDEF_(0x800C0013)
#define PST_E_STATE_INVALID _HRESULT_TYPEDEF_(0x800C0014)
#define PST_E_NOT_OPEN _HRESULT_TYPEDEF_(0x800C0015)
#define PST_E_ALREADY_OPEN _HRESULT_TYPEDEF_(0x800C0016)
#define PST_E_NYI _HRESULT_TYPEDEF_(0x800C0F00)

#define MIN_PST_ERROR 0x800C0001
#define MAX_PST_ERROR 0x800C0F00
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "wtypes.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef DWORD PST_PROVIDERCAPABILITIES;
  typedef DWORD PST_REPOSITORYCAPABILITIES;
  typedef DWORD PST_KEY;
  typedef DWORD PST_ACCESSMODE;
  typedef DWORD PST_ACCESSCLAUSETYPE;
  typedef GUID UUID;
  typedef ULARGE_INTEGER PST_PROVIDER_HANDLE;
  typedef GUID PST_PROVIDERID;
  typedef PST_PROVIDERID *PPST_PROVIDERID;

  typedef struct _PST_PROVIDERINFO {
    DWORD cbSize;
    PST_PROVIDERID ID;
    PST_PROVIDERCAPABILITIES Capabilities;
    LPWSTR szProviderName;
  } PST_PROVIDERINFO;

  typedef struct _PST_PROVIDERINFO *PPST_PROVIDERINFO;

  typedef struct _PST_TYPEINFO {
    DWORD cbSize;
    LPWSTR szDisplayName;
  } PST_TYPEINFO;

  typedef struct _PST_TYPEINFO *PPST_TYPEINFO;

  typedef struct _PST_PROMPTINFO {
    DWORD cbSize;
    DWORD dwPromptFlags;
    HWND hwndApp;
    LPCWSTR szPrompt;
  } PST_PROMPTINFO;

  typedef struct _PST_PROMPTINFO *PPST_PROMPTINFO;

  typedef struct _PST_ACCESSCLAUSE {
    DWORD cbSize;
    PST_ACCESSCLAUSETYPE ClauseType;
    DWORD cbClauseData;
    VOID *pbClauseData;
  } PST_ACCESSCLAUSE;

  typedef struct _PST_ACCESSCLAUSE *PPST_ACCESSCLAUSE;

  typedef struct _PST_ACCESSRULE {
    DWORD cbSize;
    PST_ACCESSMODE AccessModeFlags;
    DWORD cClauses;
    PST_ACCESSCLAUSE *rgClauses;
  } PST_ACCESSRULE;

  typedef struct _PST_ACCESSRULE *PPST_ACCESSRULE;

  typedef struct _PST_ACCESSRULESET {
    DWORD cbSize;
    DWORD cRules;
    PST_ACCESSRULE *rgRules;
  } PST_ACCESSRULESET;

  typedef struct _PST_ACCESSRULESET *PPST_ACCESSRULESET;

  typedef struct _PST_AUTHENTICODEDATA {
    DWORD cbSize;
    DWORD dwModifiers;
    LPCWSTR szRootCA;
    LPCWSTR szIssuer;
    LPCWSTR szPublisher;
    LPCWSTR szProgramName;
  } PST_AUTHENTICODEDATA;

  typedef struct _PST_AUTHENTICODEDATA *PPST_AUTHENTICODEDATA;
  typedef struct _PST_AUTHENTICODEDATA *LPPST_AUTHENTICODEDATA;

  typedef struct _PST_BINARYCHECKDATA {
    DWORD cbSize;
    DWORD dwModifiers;
    LPCWSTR szFilePath;
  } PST_BINARYCHECKDATA;

  typedef struct _PST_BINARYCHECKDATA *PPST_BINARYCHECKDATA;
  typedef struct _PST_BINARYCHECKDATA *LPPST_BINARYCHECKDATA;
  extern RPC_IF_HANDLE __MIDL__intf_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL__intf_0000_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __IEnumPStoreItems_FWD_DEFINED__
#define __IEnumPStoreItems_FWD_DEFINED__
  typedef struct IEnumPStoreItems IEnumPStoreItems;
#endif

#ifndef __IEnumPStoreTypes_FWD_DEFINED__
#define __IEnumPStoreTypes_FWD_DEFINED__
  typedef struct IEnumPStoreTypes IEnumPStoreTypes;
#endif

#ifndef __IPStore_FWD_DEFINED__
#define __IPStore_FWD_DEFINED__
  typedef struct IPStore IPStore;
#endif

#ifndef __IEnumPStoreProviders_FWD_DEFINED__
#define __IEnumPStoreProviders_FWD_DEFINED__
  typedef struct IEnumPStoreProviders IEnumPStoreProviders;
#endif

#include "oaidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __IEnumPStoreItems_INTERFACE_DEFINED__
#define __IEnumPStoreItems_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumPStoreItems;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumPStoreItems : public IUnknown {
public:
  virtual HRESULT WINAPI Next(DWORD celt,LPWSTR *rgelt,DWORD *pceltFetched) = 0;
  virtual HRESULT WINAPI Skip(DWORD celt) = 0;
  virtual HRESULT WINAPI Reset(void) = 0;
  virtual HRESULT WINAPI Clone(IEnumPStoreItems **ppenum) = 0;
  };
#else
  typedef struct IEnumPStoreItemsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumPStoreItems *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumPStoreItems *This);
      ULONG (WINAPI *Release)(IEnumPStoreItems *This);
      HRESULT (WINAPI *Next)(IEnumPStoreItems *This,DWORD celt,LPWSTR *rgelt,DWORD *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumPStoreItems *This,DWORD celt);
      HRESULT (WINAPI *Reset)(IEnumPStoreItems *This);
      HRESULT (WINAPI *Clone)(IEnumPStoreItems *This,IEnumPStoreItems **ppenum);
    END_INTERFACE
  } IEnumPStoreItemsVtbl;
  struct IEnumPStoreItems {
    CONST_VTBL struct IEnumPStoreItemsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumPStoreItems_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumPStoreItems_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumPStoreItems_Release(This) (This)->lpVtbl->Release(This)
#define IEnumPStoreItems_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumPStoreItems_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumPStoreItems_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumPStoreItems_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumPStoreItems_Next_Proxy(IEnumPStoreItems *This,DWORD celt,LPWSTR *rgelt,DWORD *pceltFetched);
  void __RPC_STUB IEnumPStoreItems_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreItems_Skip_Proxy(IEnumPStoreItems *This,DWORD celt);
  void __RPC_STUB IEnumPStoreItems_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreItems_Reset_Proxy(IEnumPStoreItems *This);
  void __RPC_STUB IEnumPStoreItems_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreItems_Clone_Proxy(IEnumPStoreItems *This,IEnumPStoreItems **ppenum);
  void __RPC_STUB IEnumPStoreItems_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumPStoreTypes_INTERFACE_DEFINED__
#define __IEnumPStoreTypes_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumPStoreTypes;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumPStoreTypes : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(DWORD celt,GUID *rgelt,DWORD *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(DWORD celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumPStoreTypes **ppenum) = 0;
  };
#else
  typedef struct IEnumPStoreTypesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumPStoreTypes *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumPStoreTypes *This);
      ULONG (WINAPI *Release)(IEnumPStoreTypes *This);
      HRESULT (WINAPI *Next)(IEnumPStoreTypes *This,DWORD celt,GUID *rgelt,DWORD *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumPStoreTypes *This,DWORD celt);
      HRESULT (WINAPI *Reset)(IEnumPStoreTypes *This);
      HRESULT (WINAPI *Clone)(IEnumPStoreTypes *This,IEnumPStoreTypes **ppenum);
    END_INTERFACE
  } IEnumPStoreTypesVtbl;
  struct IEnumPStoreTypes {
    CONST_VTBL struct IEnumPStoreTypesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumPStoreTypes_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumPStoreTypes_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumPStoreTypes_Release(This) (This)->lpVtbl->Release(This)
#define IEnumPStoreTypes_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumPStoreTypes_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumPStoreTypes_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumPStoreTypes_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumPStoreTypes_Next_Proxy(IEnumPStoreTypes *This,DWORD celt,GUID *rgelt,DWORD *pceltFetched);
  void __RPC_STUB IEnumPStoreTypes_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreTypes_Skip_Proxy(IEnumPStoreTypes *This,DWORD celt);
  void __RPC_STUB IEnumPStoreTypes_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreTypes_Reset_Proxy(IEnumPStoreTypes *This);
  void __RPC_STUB IEnumPStoreTypes_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreTypes_Clone_Proxy(IEnumPStoreTypes *This,IEnumPStoreTypes **ppenum);
  void __RPC_STUB IEnumPStoreTypes_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPStore_INTERFACE_DEFINED__
#define __IPStore_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPStore;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPStore : public IUnknown {
  public:
    virtual HRESULT WINAPI GetInfo(PPST_PROVIDERINFO *ppProperties) = 0;
    virtual HRESULT WINAPI GetProvParam(DWORD dwParam,DWORD *pcbData,BYTE **ppbData,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI SetProvParam(DWORD dwParam,DWORD cbData,BYTE *pbData,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI CreateType(PST_KEY Key,const GUID *pType,PPST_TYPEINFO pInfo,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI GetTypeInfo(PST_KEY Key,const GUID *pType,PPST_TYPEINFO *ppInfo,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI DeleteType(PST_KEY Key,const GUID *pType,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI CreateSubtype(PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_TYPEINFO pInfo,PPST_ACCESSRULESET pRules,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI GetSubtypeInfo(PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_TYPEINFO *ppInfo,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI DeleteSubtype(PST_KEY Key,const GUID *pType,const GUID *pSubtype,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI ReadAccessRuleset(PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_ACCESSRULESET *ppRules,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI WriteAccessRuleset(PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_ACCESSRULESET pRules,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI EnumTypes(PST_KEY Key,DWORD dwFlags,IEnumPStoreTypes **ppenum) = 0;
    virtual HRESULT WINAPI EnumSubtypes(PST_KEY Key,const GUID *pType,DWORD dwFlags,IEnumPStoreTypes **ppenum) = 0;
    virtual HRESULT WINAPI DeleteItem(PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI ReadItem(PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD *pcbData,BYTE **ppbData,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI WriteItem(PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD cbData,BYTE *pbData,PPST_PROMPTINFO pPromptInfo,DWORD dwDefaultConfirmationStyle,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI OpenItem(PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,PST_ACCESSMODE ModeFlags,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI CloseItem(PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI EnumItems(PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,DWORD dwFlags,IEnumPStoreItems **ppenum) = 0;
  };
#else
  typedef struct IPStoreVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPStore *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPStore *This);
      ULONG (WINAPI *Release)(IPStore *This);
      HRESULT (WINAPI *GetInfo)(IPStore *This,PPST_PROVIDERINFO *ppProperties);
      HRESULT (WINAPI *GetProvParam)(IPStore *This,DWORD dwParam,DWORD *pcbData,BYTE **ppbData,DWORD dwFlags);
      HRESULT (WINAPI *SetProvParam)(IPStore *This,DWORD dwParam,DWORD cbData,BYTE *pbData,DWORD dwFlags);
      HRESULT (WINAPI *CreateType)(IPStore *This,PST_KEY Key,const GUID *pType,PPST_TYPEINFO pInfo,DWORD dwFlags);
      HRESULT (WINAPI *GetTypeInfo)(IPStore *This,PST_KEY Key,const GUID *pType,PPST_TYPEINFO *ppInfo,DWORD dwFlags);
      HRESULT (WINAPI *DeleteType)(IPStore *This,PST_KEY Key,const GUID *pType,DWORD dwFlags);
      HRESULT (WINAPI *CreateSubtype)(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_TYPEINFO pInfo,PPST_ACCESSRULESET pRules,DWORD dwFlags);
      HRESULT (WINAPI *GetSubtypeInfo)(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_TYPEINFO *ppInfo,DWORD dwFlags);
      HRESULT (WINAPI *DeleteSubtype)(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,DWORD dwFlags);
      HRESULT (WINAPI *ReadAccessRuleset)(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_ACCESSRULESET *ppRules,DWORD dwFlags);
      HRESULT (WINAPI *WriteAccessRuleset)(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_ACCESSRULESET pRules,DWORD dwFlags);
      HRESULT (WINAPI *EnumTypes)(IPStore *This,PST_KEY Key,DWORD dwFlags,IEnumPStoreTypes **ppenum);
      HRESULT (WINAPI *EnumSubtypes)(IPStore *This,PST_KEY Key,const GUID *pType,DWORD dwFlags,IEnumPStoreTypes **ppenum);
      HRESULT (WINAPI *DeleteItem)(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags);
      HRESULT (WINAPI *ReadItem)(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD *pcbData,BYTE **ppbData,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags);
      HRESULT (WINAPI *WriteItem)(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD cbData,BYTE *pbData,PPST_PROMPTINFO pPromptInfo,DWORD dwDefaultConfirmationStyle,DWORD dwFlags);
      HRESULT (WINAPI *OpenItem)(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,PST_ACCESSMODE ModeFlags,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags);
      HRESULT (WINAPI *CloseItem)(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD dwFlags);
      HRESULT (WINAPI *EnumItems)(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,DWORD dwFlags,IEnumPStoreItems **ppenum);
    END_INTERFACE
  } IPStoreVtbl;
  struct IPStore {
    CONST_VTBL struct IPStoreVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPStore_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPStore_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPStore_Release(This) (This)->lpVtbl->Release(This)
#define IPStore_GetInfo(This,ppProperties) (This)->lpVtbl->GetInfo(This,ppProperties)
#define IPStore_GetProvParam(This,dwParam,pcbData,ppbData,dwFlags) (This)->lpVtbl->GetProvParam(This,dwParam,pcbData,ppbData,dwFlags)
#define IPStore_SetProvParam(This,dwParam,cbData,pbData,dwFlags) (This)->lpVtbl->SetProvParam(This,dwParam,cbData,pbData,dwFlags)
#define IPStore_CreateType(This,Key,pType,pInfo,dwFlags) (This)->lpVtbl->CreateType(This,Key,pType,pInfo,dwFlags)
#define IPStore_GetTypeInfo(This,Key,pType,ppInfo,dwFlags) (This)->lpVtbl->GetTypeInfo(This,Key,pType,ppInfo,dwFlags)
#define IPStore_DeleteType(This,Key,pType,dwFlags) (This)->lpVtbl->DeleteType(This,Key,pType,dwFlags)
#define IPStore_CreateSubtype(This,Key,pType,pSubtype,pInfo,pRules,dwFlags) (This)->lpVtbl->CreateSubtype(This,Key,pType,pSubtype,pInfo,pRules,dwFlags)
#define IPStore_GetSubtypeInfo(This,Key,pType,pSubtype,ppInfo,dwFlags) (This)->lpVtbl->GetSubtypeInfo(This,Key,pType,pSubtype,ppInfo,dwFlags)
#define IPStore_DeleteSubtype(This,Key,pType,pSubtype,dwFlags) (This)->lpVtbl->DeleteSubtype(This,Key,pType,pSubtype,dwFlags)
#define IPStore_ReadAccessRuleset(This,Key,pType,pSubtype,ppRules,dwFlags) (This)->lpVtbl->ReadAccessRuleset(This,Key,pType,pSubtype,ppRules,dwFlags)
#define IPStore_WriteAccessRuleset(This,Key,pType,pSubtype,pRules,dwFlags) (This)->lpVtbl->WriteAccessRuleset(This,Key,pType,pSubtype,pRules,dwFlags)
#define IPStore_EnumTypes(This,Key,dwFlags,ppenum) (This)->lpVtbl->EnumTypes(This,Key,dwFlags,ppenum)
#define IPStore_EnumSubtypes(This,Key,pType,dwFlags,ppenum) (This)->lpVtbl->EnumSubtypes(This,Key,pType,dwFlags,ppenum)
#define IPStore_DeleteItem(This,Key,pItemType,pItemSubtype,szItemName,pPromptInfo,dwFlags) (This)->lpVtbl->DeleteItem(This,Key,pItemType,pItemSubtype,szItemName,pPromptInfo,dwFlags)
#define IPStore_ReadItem(This,Key,pItemType,pItemSubtype,szItemName,pcbData,ppbData,pPromptInfo,dwFlags) (This)->lpVtbl->ReadItem(This,Key,pItemType,pItemSubtype,szItemName,pcbData,ppbData,pPromptInfo,dwFlags)
#define IPStore_WriteItem(This,Key,pItemType,pItemSubtype,szItemName,cbData,pbData,pPromptInfo,dwDefaultConfirmationStyle,dwFlags) (This)->lpVtbl->WriteItem(This,Key,pItemType,pItemSubtype,szItemName,cbData,pbData,pPromptInfo,dwDefaultConfirmationStyle,dwFlags)
#define IPStore_OpenItem(This,Key,pItemType,pItemSubtype,szItemName,ModeFlags,pPromptInfo,dwFlags) (This)->lpVtbl->OpenItem(This,Key,pItemType,pItemSubtype,szItemName,ModeFlags,pPromptInfo,dwFlags)
#define IPStore_CloseItem(This,Key,pItemType,pItemSubtype,szItemName,dwFlags) (This)->lpVtbl->CloseItem(This,Key,pItemType,pItemSubtype,szItemName,dwFlags)
#define IPStore_EnumItems(This,Key,pItemType,pItemSubtype,dwFlags,ppenum) (This)->lpVtbl->EnumItems(This,Key,pItemType,pItemSubtype,dwFlags,ppenum)
#endif
#endif
  HRESULT WINAPI IPStore_GetInfo_Proxy(IPStore *This,PPST_PROVIDERINFO *ppProperties);
  void __RPC_STUB IPStore_GetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_GetProvParam_Proxy(IPStore *This,DWORD dwParam,DWORD *pcbData,BYTE **ppbData,DWORD dwFlags);
  void __RPC_STUB IPStore_GetProvParam_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_SetProvParam_Proxy(IPStore *This,DWORD dwParam,DWORD cbData,BYTE *pbData,DWORD dwFlags);
  void __RPC_STUB IPStore_SetProvParam_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_CreateType_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,PPST_TYPEINFO pInfo,DWORD dwFlags);
  void __RPC_STUB IPStore_CreateType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_GetTypeInfo_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,PPST_TYPEINFO *ppInfo,DWORD dwFlags);
  void __RPC_STUB IPStore_GetTypeInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_DeleteType_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,DWORD dwFlags);
  void __RPC_STUB IPStore_DeleteType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_CreateSubtype_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_TYPEINFO pInfo,PPST_ACCESSRULESET pRules,DWORD dwFlags);
  void __RPC_STUB IPStore_CreateSubtype_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_GetSubtypeInfo_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_TYPEINFO *ppInfo,DWORD dwFlags);
  void __RPC_STUB IPStore_GetSubtypeInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_DeleteSubtype_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,DWORD dwFlags);
  void __RPC_STUB IPStore_DeleteSubtype_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_ReadAccessRuleset_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_ACCESSRULESET *ppRules,DWORD dwFlags);
  void __RPC_STUB IPStore_ReadAccessRuleset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_WriteAccessRuleset_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,const GUID *pSubtype,PPST_ACCESSRULESET pRules,DWORD dwFlags);
  void __RPC_STUB IPStore_WriteAccessRuleset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_EnumTypes_Proxy(IPStore *This,PST_KEY Key,DWORD dwFlags,IEnumPStoreTypes **ppenum);
  void __RPC_STUB IPStore_EnumTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_EnumSubtypes_Proxy(IPStore *This,PST_KEY Key,const GUID *pType,DWORD dwFlags,IEnumPStoreTypes **ppenum);
  void __RPC_STUB IPStore_EnumSubtypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_DeleteItem_Proxy(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags);
  void __RPC_STUB IPStore_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_ReadItem_Proxy(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD *pcbData,BYTE **ppbData,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags);
  void __RPC_STUB IPStore_ReadItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_WriteItem_Proxy(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD cbData,BYTE *pbData,PPST_PROMPTINFO pPromptInfo,DWORD dwDefaultConfirmationStyle,DWORD dwFlags);
  void __RPC_STUB IPStore_WriteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_OpenItem_Proxy(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,PST_ACCESSMODE ModeFlags,PPST_PROMPTINFO pPromptInfo,DWORD dwFlags);
  void __RPC_STUB IPStore_OpenItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_CloseItem_Proxy(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,LPCWSTR szItemName,DWORD dwFlags);
  void __RPC_STUB IPStore_CloseItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPStore_EnumItems_Proxy(IPStore *This,PST_KEY Key,const GUID *pItemType,const GUID *pItemSubtype,DWORD dwFlags,IEnumPStoreItems **ppenum);
  void __RPC_STUB IPStore_EnumItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumPStoreProviders_INTERFACE_DEFINED__
#define __IEnumPStoreProviders_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumPStoreProviders;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumPStoreProviders : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(DWORD celt,PST_PROVIDERINFO **rgelt,DWORD *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(DWORD celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumPStoreProviders **ppenum) = 0;
  };
#else
  typedef struct IEnumPStoreProvidersVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumPStoreProviders *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumPStoreProviders *This);
      ULONG (WINAPI *Release)(IEnumPStoreProviders *This);
      HRESULT (WINAPI *Next)(IEnumPStoreProviders *This,DWORD celt,PST_PROVIDERINFO **rgelt,DWORD *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumPStoreProviders *This,DWORD celt);
      HRESULT (WINAPI *Reset)(IEnumPStoreProviders *This);
      HRESULT (WINAPI *Clone)(IEnumPStoreProviders *This,IEnumPStoreProviders **ppenum);
    END_INTERFACE
  } IEnumPStoreProvidersVtbl;
  struct IEnumPStoreProviders {
    CONST_VTBL struct IEnumPStoreProvidersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumPStoreProviders_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumPStoreProviders_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumPStoreProviders_Release(This) (This)->lpVtbl->Release(This)
#define IEnumPStoreProviders_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumPStoreProviders_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumPStoreProviders_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumPStoreProviders_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumPStoreProviders_Next_Proxy(IEnumPStoreProviders *This,DWORD celt,PST_PROVIDERINFO **rgelt,DWORD *pceltFetched);
  void __RPC_STUB IEnumPStoreProviders_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreProviders_Skip_Proxy(IEnumPStoreProviders *This,DWORD celt);
  void __RPC_STUB IEnumPStoreProviders_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreProviders_Reset_Proxy(IEnumPStoreProviders *This);
  void __RPC_STUB IEnumPStoreProviders_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPStoreProviders_Clone_Proxy(IEnumPStoreProviders *This,IEnumPStoreProviders **ppenum);
  void __RPC_STUB IEnumPStoreProviders_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __PSTORECLib_LIBRARY_DEFINED__
#define __PSTORECLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_PSTORECLib;
#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_CPStore;
  class CPStore;
#endif
#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_CEnumTypes;
  class CEnumTypes;
#endif
#ifdef __cplusplus
  EXTERN_C const CLSID CLSID_CEnumItems;
  class CEnumItems;
#endif
#endif

  HRESULT WINAPI PStoreCreateInstance(IPStore **ppProvider,PST_PROVIDERID *pProviderID,void *pReserved,DWORD dwFlags);
  HRESULT WINAPI PStoreEnumProviders(DWORD dwFlags,IEnumPStoreProviders **ppenum);

  extern RPC_IF_HANDLE __MIDL__intf_0080_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL__intf_0080_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
