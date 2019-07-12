/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "rpc.h"
#include "rpcndr.h"
#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __mergemod_h__
#define __mergemod_h__

#ifndef _WIN32_MSM
#define _WIN32_MSM 100
#endif

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __IEnumMsmString_FWD_DEFINED__
#define __IEnumMsmString_FWD_DEFINED__
  typedef struct IEnumMsmString IEnumMsmString;
#endif

#ifndef __IMsmStrings_FWD_DEFINED__
#define __IMsmStrings_FWD_DEFINED__
  typedef struct IMsmStrings IMsmStrings;
#endif

#ifndef __IMsmError_FWD_DEFINED__
#define __IMsmError_FWD_DEFINED__
  typedef struct IMsmError IMsmError;
#endif

#ifndef __IEnumMsmError_FWD_DEFINED__
#define __IEnumMsmError_FWD_DEFINED__
  typedef struct IEnumMsmError IEnumMsmError;
#endif

#ifndef __IMsmErrors_FWD_DEFINED__
#define __IMsmErrors_FWD_DEFINED__
  typedef struct IMsmErrors IMsmErrors;
#endif

#ifndef __IMsmDependency_FWD_DEFINED__
#define __IMsmDependency_FWD_DEFINED__
  typedef struct IMsmDependency IMsmDependency;
#endif

#ifndef __IEnumMsmDependency_FWD_DEFINED__
#define __IEnumMsmDependency_FWD_DEFINED__
  typedef struct IEnumMsmDependency IEnumMsmDependency;
#endif

#ifndef __IMsmDependencies_FWD_DEFINED__
#define __IMsmDependencies_FWD_DEFINED__
  typedef struct IMsmDependencies IMsmDependencies;
#endif

#ifndef __IMsmMerge_FWD_DEFINED__
#define __IMsmMerge_FWD_DEFINED__
  typedef struct IMsmMerge IMsmMerge;
#endif

#ifndef __IMsmGetFiles_FWD_DEFINED__
#define __IMsmGetFiles_FWD_DEFINED__
  typedef struct IMsmGetFiles IMsmGetFiles;
#endif

#ifndef __IMsmStrings_FWD_DEFINED__
#define __IMsmStrings_FWD_DEFINED__
  typedef struct IMsmStrings IMsmStrings;
#endif

#ifndef __IMsmError_FWD_DEFINED__
#define __IMsmError_FWD_DEFINED__
  typedef struct IMsmError IMsmError;
#endif

#ifndef __IMsmErrors_FWD_DEFINED__
#define __IMsmErrors_FWD_DEFINED__
  typedef struct IMsmErrors IMsmErrors;
#endif

#ifndef __IMsmDependency_FWD_DEFINED__
#define __IMsmDependency_FWD_DEFINED__
  typedef struct IMsmDependency IMsmDependency;
#endif

#ifndef __IMsmDependencies_FWD_DEFINED__
#define __IMsmDependencies_FWD_DEFINED__
  typedef struct IMsmDependencies IMsmDependencies;
#endif

#ifndef __IMsmGetFiles_FWD_DEFINED__
#define __IMsmGetFiles_FWD_DEFINED__
  typedef struct IMsmGetFiles IMsmGetFiles;
#endif

#if (_WIN32_MSM >= 150)

#ifndef __IMsmConfigurableItem_FWD_DEFINED__
#define __IMsmConfigurableItem_FWD_DEFINED__
  typedef struct IMsmConfigurableItem IMsmConfigurableItem;
#endif

#ifndef __IEnumMsmConfigurableItem_FWD_DEFINED__
#define __IEnumMsmConfigurableItem_FWD_DEFINED__
  typedef struct IEnumMsmConfigurableItem IEnumMsmConfigurableItem;
#endif

#ifndef __IMsmConfigurableItems_FWD_DEFINED__
#define __IMsmConfigurableItems_FWD_DEFINED__
  typedef struct IMsmConfigurableItems IMsmConfigurableItems;
#endif

#ifndef __IMsmMerge2_FWD_DEFINED__
#define __IMsmMerge2_FWD_DEFINED__
  typedef struct IMsmMerge2 IMsmMerge2;
#endif

#ifndef __IMsmConfigureModule_FWD_DEFINED__
#define __IMsmConfigureModule_FWD_DEFINED__
  typedef struct IMsmConfigureModule IMsmConfigureModule;
#endif

#ifndef __MsmMerge2_FWD_DEFINED__
#define __MsmMerge2_FWD_DEFINED__
#ifdef __cplusplus
  typedef class MsmMerge2 MsmMerge2;
#else
  typedef struct MsmMerge2 MsmMerge2;
#endif
#endif
#endif

#ifndef __MsmMerge_FWD_DEFINED__
#define __MsmMerge_FWD_DEFINED__
#ifdef __cplusplus
  typedef class MsmMerge MsmMerge;
#else
  typedef struct MsmMerge MsmMerge;
#endif
#endif

#include "oaidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __FORWARD_IID_IMSMMERGETYPELIB
#define __FORWARD_IID_IMSMMERGETYPELIB

  typedef enum msmErrorType {
    msmErrorLanguageUnsupported = 1,msmErrorLanguageFailed = 2,msmErrorExclusion = 3,msmErrorTableMerge = 4,msmErrorResequenceMerge = 5,
    msmErrorFileCreate = 6,msmErrorDirCreate = 7,msmErrorFeatureRequired = 8,
#if (_WIN32_MSM >= 150)
    msmErrorBadNullSubstitution = 9,msmErrorBadSubstitutionType = 10,msmErrorMissingConfigItem = 11,msmErrorBadNullResponse = 12,
    msmErrorDataRequestFailed = 13,msmErrorPlatformMismatch = 14
#endif
  } msmErrorType;

#if (_WIN32_MSM >= 150)
  typedef enum msmConfigurableItemFormat {
    msmConfigurableItemText = 0,msmConfigurableItemKey = 1,msmConfigurableItemInteger = 2,msmConfigurableItemBitfield = 3
  } msmConfigurableItemFormat;

  typedef enum msmConfigurableItemOptions {
    msmConfigurableOptionKeyNoOrphan = 1,msmConfigurableOptionNonNullable = 2
  } msmConfigurableItemOptions;
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_mergemod_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mergemod_0000_v0_0_s_ifspec;

#ifndef __IEnumMsmString_INTERFACE_DEFINED__
#define __IEnumMsmString_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumMsmString : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(unsigned __LONG32 cFetch,BSTR *rgbstrStrings,unsigned __LONG32 *pcFetched) = 0;
    virtual HRESULT WINAPI Skip(unsigned __LONG32 cSkip) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumMsmString **pemsmStrings) = 0;
  };
#else
  typedef struct IEnumMsmStringVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumMsmString *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumMsmString *This);
      ULONG (WINAPI *Release)(IEnumMsmString *This);
      HRESULT (WINAPI *Next)(IEnumMsmString *This,unsigned __LONG32 cFetch,BSTR *rgbstrStrings,unsigned __LONG32 *pcFetched);
      HRESULT (WINAPI *Skip)(IEnumMsmString *This,unsigned __LONG32 cSkip);
      HRESULT (WINAPI *Reset)(IEnumMsmString *This);
      HRESULT (WINAPI *Clone)(IEnumMsmString *This,IEnumMsmString **pemsmStrings);
    END_INTERFACE
  } IEnumMsmStringVtbl;
  struct IEnumMsmString {
    CONST_VTBL struct IEnumMsmStringVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumMsmString_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumMsmString_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumMsmString_Release(This) (This)->lpVtbl->Release(This)
#define IEnumMsmString_Next(This,cFetch,rgbstrStrings,pcFetched) (This)->lpVtbl->Next(This,cFetch,rgbstrStrings,pcFetched)
#define IEnumMsmString_Skip(This,cSkip) (This)->lpVtbl->Skip(This,cSkip)
#define IEnumMsmString_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumMsmString_Clone(This,pemsmStrings) (This)->lpVtbl->Clone(This,pemsmStrings)
#endif
#endif
  HRESULT WINAPI IEnumMsmString_Next_Proxy(IEnumMsmString *This,unsigned __LONG32 cFetch,BSTR *rgbstrStrings,unsigned __LONG32 *pcFetched);
  void __RPC_STUB IEnumMsmString_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmString_Skip_Proxy(IEnumMsmString *This,unsigned __LONG32 cSkip);
  void __RPC_STUB IEnumMsmString_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmString_Reset_Proxy(IEnumMsmString *This);
  void __RPC_STUB IEnumMsmString_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmString_Clone_Proxy(IEnumMsmString *This,IEnumMsmString **pemsmStrings);
  void __RPC_STUB IEnumMsmString_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmStrings_INTERFACE_DEFINED__
#define __IMsmStrings_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmStrings : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Item,BSTR *Return) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **NewEnum) = 0;
  };
#else
  typedef struct IMsmStringsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmStrings *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmStrings *This);
      ULONG (WINAPI *Release)(IMsmStrings *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmStrings *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmStrings *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmStrings *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmStrings *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IMsmStrings *This,__LONG32 Item,BSTR *Return);
      HRESULT (WINAPI *get_Count)(IMsmStrings *This,__LONG32 *Count);
      HRESULT (WINAPI *get__NewEnum)(IMsmStrings *This,IUnknown **NewEnum);
    END_INTERFACE
  } IMsmStringsVtbl;
  struct IMsmStrings {
    CONST_VTBL struct IMsmStringsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmStrings_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmStrings_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmStrings_Release(This) (This)->lpVtbl->Release(This)
#define IMsmStrings_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmStrings_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmStrings_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmStrings_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmStrings_get_Item(This,Item,Return) (This)->lpVtbl->get_Item(This,Item,Return)
#define IMsmStrings_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IMsmStrings_get__NewEnum(This,NewEnum) (This)->lpVtbl->get__NewEnum(This,NewEnum)
#endif
#endif
  HRESULT WINAPI IMsmStrings_get_Item_Proxy(IMsmStrings *This,__LONG32 Item,BSTR *Return);
  void __RPC_STUB IMsmStrings_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmStrings_get_Count_Proxy(IMsmStrings *This,__LONG32 *Count);
  void __RPC_STUB IMsmStrings_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmStrings_get__NewEnum_Proxy(IMsmStrings *This,IUnknown **NewEnum);
  void __RPC_STUB IMsmStrings_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmError_INTERFACE_DEFINED__
#define __IMsmError_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmError : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Type(msmErrorType *ErrorType) = 0;
    virtual HRESULT WINAPI get_Path(BSTR *ErrorPath) = 0;
    virtual HRESULT WINAPI get_Language(short *ErrorLanguage) = 0;
    virtual HRESULT WINAPI get_DatabaseTable(BSTR *ErrorTable) = 0;
    virtual HRESULT WINAPI get_DatabaseKeys(IMsmStrings **ErrorKeys) = 0;
    virtual HRESULT WINAPI get_ModuleTable(BSTR *ErrorTable) = 0;
    virtual HRESULT WINAPI get_ModuleKeys(IMsmStrings **ErrorKeys) = 0;
  };
#else
  typedef struct IMsmErrorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmError *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmError *This);
      ULONG (WINAPI *Release)(IMsmError *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmError *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmError *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmError *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmError *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Type)(IMsmError *This,msmErrorType *ErrorType);
      HRESULT (WINAPI *get_Path)(IMsmError *This,BSTR *ErrorPath);
      HRESULT (WINAPI *get_Language)(IMsmError *This,short *ErrorLanguage);
      HRESULT (WINAPI *get_DatabaseTable)(IMsmError *This,BSTR *ErrorTable);
      HRESULT (WINAPI *get_DatabaseKeys)(IMsmError *This,IMsmStrings **ErrorKeys);
      HRESULT (WINAPI *get_ModuleTable)(IMsmError *This,BSTR *ErrorTable);
      HRESULT (WINAPI *get_ModuleKeys)(IMsmError *This,IMsmStrings **ErrorKeys);
    END_INTERFACE
  } IMsmErrorVtbl;
  struct IMsmError {
    CONST_VTBL struct IMsmErrorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmError_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmError_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmError_Release(This) (This)->lpVtbl->Release(This)
#define IMsmError_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmError_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmError_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmError_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmError_get_Type(This,ErrorType) (This)->lpVtbl->get_Type(This,ErrorType)
#define IMsmError_get_Path(This,ErrorPath) (This)->lpVtbl->get_Path(This,ErrorPath)
#define IMsmError_get_Language(This,ErrorLanguage) (This)->lpVtbl->get_Language(This,ErrorLanguage)
#define IMsmError_get_DatabaseTable(This,ErrorTable) (This)->lpVtbl->get_DatabaseTable(This,ErrorTable)
#define IMsmError_get_DatabaseKeys(This,ErrorKeys) (This)->lpVtbl->get_DatabaseKeys(This,ErrorKeys)
#define IMsmError_get_ModuleTable(This,ErrorTable) (This)->lpVtbl->get_ModuleTable(This,ErrorTable)
#define IMsmError_get_ModuleKeys(This,ErrorKeys) (This)->lpVtbl->get_ModuleKeys(This,ErrorKeys)
#endif
#endif
  HRESULT WINAPI IMsmError_get_Type_Proxy(IMsmError *This,msmErrorType *ErrorType);
  void __RPC_STUB IMsmError_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmError_get_Path_Proxy(IMsmError *This,BSTR *ErrorPath);
  void __RPC_STUB IMsmError_get_Path_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmError_get_Language_Proxy(IMsmError *This,short *ErrorLanguage);
  void __RPC_STUB IMsmError_get_Language_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmError_get_DatabaseTable_Proxy(IMsmError *This,BSTR *ErrorTable);
  void __RPC_STUB IMsmError_get_DatabaseTable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmError_get_DatabaseKeys_Proxy(IMsmError *This,IMsmStrings **ErrorKeys);
  void __RPC_STUB IMsmError_get_DatabaseKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmError_get_ModuleTable_Proxy(IMsmError *This,BSTR *ErrorTable);
  void __RPC_STUB IMsmError_get_ModuleTable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmError_get_ModuleKeys_Proxy(IMsmError *This,IMsmStrings **ErrorKeys);
  void __RPC_STUB IMsmError_get_ModuleKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumMsmError_INTERFACE_DEFINED__
#define __IEnumMsmError_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumMsmError : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(unsigned __LONG32 cFetch,IMsmError **rgmsmErrors,unsigned __LONG32 *pcFetched) = 0;
    virtual HRESULT WINAPI Skip(unsigned __LONG32 cSkip) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumMsmError **pemsmErrors) = 0;
  };
#else
  typedef struct IEnumMsmErrorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumMsmError *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumMsmError *This);
      ULONG (WINAPI *Release)(IEnumMsmError *This);
      HRESULT (WINAPI *Next)(IEnumMsmError *This,unsigned __LONG32 cFetch,IMsmError **rgmsmErrors,unsigned __LONG32 *pcFetched);
      HRESULT (WINAPI *Skip)(IEnumMsmError *This,unsigned __LONG32 cSkip);
      HRESULT (WINAPI *Reset)(IEnumMsmError *This);
      HRESULT (WINAPI *Clone)(IEnumMsmError *This,IEnumMsmError **pemsmErrors);
    END_INTERFACE
  } IEnumMsmErrorVtbl;
  struct IEnumMsmError {
    CONST_VTBL struct IEnumMsmErrorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumMsmError_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumMsmError_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumMsmError_Release(This) (This)->lpVtbl->Release(This)
#define IEnumMsmError_Next(This,cFetch,rgmsmErrors,pcFetched) (This)->lpVtbl->Next(This,cFetch,rgmsmErrors,pcFetched)
#define IEnumMsmError_Skip(This,cSkip) (This)->lpVtbl->Skip(This,cSkip)
#define IEnumMsmError_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumMsmError_Clone(This,pemsmErrors) (This)->lpVtbl->Clone(This,pemsmErrors)
#endif
#endif
  HRESULT WINAPI IEnumMsmError_Next_Proxy(IEnumMsmError *This,unsigned __LONG32 cFetch,IMsmError **rgmsmErrors,unsigned __LONG32 *pcFetched);
  void __RPC_STUB IEnumMsmError_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmError_Skip_Proxy(IEnumMsmError *This,unsigned __LONG32 cSkip);
  void __RPC_STUB IEnumMsmError_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmError_Reset_Proxy(IEnumMsmError *This);
  void __RPC_STUB IEnumMsmError_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmError_Clone_Proxy(IEnumMsmError *This,IEnumMsmError **pemsmErrors);
  void __RPC_STUB IEnumMsmError_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmErrors_INTERFACE_DEFINED__
#define __IMsmErrors_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)

  struct IMsmErrors : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Item,IMsmError **Return) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **NewEnum) = 0;
  };
#else
  typedef struct IMsmErrorsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmErrors *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmErrors *This);
      ULONG (WINAPI *Release)(IMsmErrors *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmErrors *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmErrors *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmErrors *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmErrors *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IMsmErrors *This,__LONG32 Item,IMsmError **Return);
      HRESULT (WINAPI *get_Count)(IMsmErrors *This,__LONG32 *Count);
      HRESULT (WINAPI *get__NewEnum)(IMsmErrors *This,IUnknown **NewEnum);
    END_INTERFACE
  } IMsmErrorsVtbl;
  struct IMsmErrors {
    CONST_VTBL struct IMsmErrorsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmErrors_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmErrors_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmErrors_Release(This) (This)->lpVtbl->Release(This)
#define IMsmErrors_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmErrors_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmErrors_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmErrors_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmErrors_get_Item(This,Item,Return) (This)->lpVtbl->get_Item(This,Item,Return)
#define IMsmErrors_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IMsmErrors_get__NewEnum(This,NewEnum) (This)->lpVtbl->get__NewEnum(This,NewEnum)
#endif
#endif
  HRESULT WINAPI IMsmErrors_get_Item_Proxy(IMsmErrors *This,__LONG32 Item,IMsmError **Return);
  void __RPC_STUB IMsmErrors_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmErrors_get_Count_Proxy(IMsmErrors *This,__LONG32 *Count);
  void __RPC_STUB IMsmErrors_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmErrors_get__NewEnum_Proxy(IMsmErrors *This,IUnknown **NewEnum);
  void __RPC_STUB IMsmErrors_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmDependency_INTERFACE_DEFINED__
#define __IMsmDependency_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmDependency : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Module(BSTR *Module) = 0;
    virtual HRESULT WINAPI get_Language(short *Language) = 0;
    virtual HRESULT WINAPI get_Version(BSTR *Version) = 0;
  };
#else
  typedef struct IMsmDependencyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmDependency *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmDependency *This);
      ULONG (WINAPI *Release)(IMsmDependency *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmDependency *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmDependency *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmDependency *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmDependency *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Module)(IMsmDependency *This,BSTR *Module);
      HRESULT (WINAPI *get_Language)(IMsmDependency *This,short *Language);
      HRESULT (WINAPI *get_Version)(IMsmDependency *This,BSTR *Version);
    END_INTERFACE
  } IMsmDependencyVtbl;
  struct IMsmDependency {
    CONST_VTBL struct IMsmDependencyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmDependency_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmDependency_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmDependency_Release(This) (This)->lpVtbl->Release(This)
#define IMsmDependency_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmDependency_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmDependency_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmDependency_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmDependency_get_Module(This,Module) (This)->lpVtbl->get_Module(This,Module)
#define IMsmDependency_get_Language(This,Language) (This)->lpVtbl->get_Language(This,Language)
#define IMsmDependency_get_Version(This,Version) (This)->lpVtbl->get_Version(This,Version)
#endif
#endif
  HRESULT WINAPI IMsmDependency_get_Module_Proxy(IMsmDependency *This,BSTR *Module);
  void __RPC_STUB IMsmDependency_get_Module_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmDependency_get_Language_Proxy(IMsmDependency *This,short *Language);
  void __RPC_STUB IMsmDependency_get_Language_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmDependency_get_Version_Proxy(IMsmDependency *This,BSTR *Version);
  void __RPC_STUB IMsmDependency_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumMsmDependency_INTERFACE_DEFINED__
#define __IEnumMsmDependency_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumMsmDependency : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(unsigned __LONG32 cFetch,IMsmDependency **rgmsmDependencies,unsigned __LONG32 *pcFetched) = 0;
    virtual HRESULT WINAPI Skip(unsigned __LONG32 cSkip) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumMsmDependency **pemsmDependencies) = 0;
  };
#else
  typedef struct IEnumMsmDependencyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumMsmDependency *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumMsmDependency *This);
      ULONG (WINAPI *Release)(IEnumMsmDependency *This);
      HRESULT (WINAPI *Next)(IEnumMsmDependency *This,unsigned __LONG32 cFetch,IMsmDependency **rgmsmDependencies,unsigned __LONG32 *pcFetched);
      HRESULT (WINAPI *Skip)(IEnumMsmDependency *This,unsigned __LONG32 cSkip);
      HRESULT (WINAPI *Reset)(IEnumMsmDependency *This);
      HRESULT (WINAPI *Clone)(IEnumMsmDependency *This,IEnumMsmDependency **pemsmDependencies);
    END_INTERFACE
  } IEnumMsmDependencyVtbl;
  struct IEnumMsmDependency {
    CONST_VTBL struct IEnumMsmDependencyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumMsmDependency_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumMsmDependency_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumMsmDependency_Release(This) (This)->lpVtbl->Release(This)
#define IEnumMsmDependency_Next(This,cFetch,rgmsmDependencies,pcFetched) (This)->lpVtbl->Next(This,cFetch,rgmsmDependencies,pcFetched)
#define IEnumMsmDependency_Skip(This,cSkip) (This)->lpVtbl->Skip(This,cSkip)
#define IEnumMsmDependency_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumMsmDependency_Clone(This,pemsmDependencies) (This)->lpVtbl->Clone(This,pemsmDependencies)
#endif
#endif
  HRESULT WINAPI IEnumMsmDependency_Next_Proxy(IEnumMsmDependency *This,unsigned __LONG32 cFetch,IMsmDependency **rgmsmDependencies,unsigned __LONG32 *pcFetched);
  void __RPC_STUB IEnumMsmDependency_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmDependency_Skip_Proxy(IEnumMsmDependency *This,unsigned __LONG32 cSkip);
  void __RPC_STUB IEnumMsmDependency_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmDependency_Reset_Proxy(IEnumMsmDependency *This);
  void __RPC_STUB IEnumMsmDependency_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmDependency_Clone_Proxy(IEnumMsmDependency *This,IEnumMsmDependency **pemsmDependencies);
  void __RPC_STUB IEnumMsmDependency_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmDependencies_INTERFACE_DEFINED__
#define __IMsmDependencies_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmDependencies : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Item,IMsmDependency **Return) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **NewEnum) = 0;
  };
#else
  typedef struct IMsmDependenciesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmDependencies *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmDependencies *This);
      ULONG (WINAPI *Release)(IMsmDependencies *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmDependencies *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmDependencies *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmDependencies *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmDependencies *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IMsmDependencies *This,__LONG32 Item,IMsmDependency **Return);
      HRESULT (WINAPI *get_Count)(IMsmDependencies *This,__LONG32 *Count);
      HRESULT (WINAPI *get__NewEnum)(IMsmDependencies *This,IUnknown **NewEnum);
    END_INTERFACE
  } IMsmDependenciesVtbl;
  struct IMsmDependencies {
    CONST_VTBL struct IMsmDependenciesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmDependencies_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmDependencies_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmDependencies_Release(This) (This)->lpVtbl->Release(This)
#define IMsmDependencies_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmDependencies_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmDependencies_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmDependencies_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmDependencies_get_Item(This,Item,Return) (This)->lpVtbl->get_Item(This,Item,Return)
#define IMsmDependencies_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IMsmDependencies_get__NewEnum(This,NewEnum) (This)->lpVtbl->get__NewEnum(This,NewEnum)
#endif
#endif
  HRESULT WINAPI IMsmDependencies_get_Item_Proxy(IMsmDependencies *This,__LONG32 Item,IMsmDependency **Return);
  void __RPC_STUB IMsmDependencies_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmDependencies_get_Count_Proxy(IMsmDependencies *This,__LONG32 *Count);
  void __RPC_STUB IMsmDependencies_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmDependencies_get__NewEnum_Proxy(IMsmDependencies *This,IUnknown **NewEnum);
  void __RPC_STUB IMsmDependencies_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#if (_WIN32_MSM >= 150)
#ifndef __IMsmConfigurableItem_INTERFACE_DEFINED__
#define __IMsmConfigurableItem_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmConfigurableItem : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *Name) = 0;
    virtual HRESULT WINAPI get_Format(msmConfigurableItemFormat *Format) = 0;
    virtual HRESULT WINAPI get_Type(BSTR *Type) = 0;
    virtual HRESULT WINAPI get_Context(BSTR *Context) = 0;
    virtual HRESULT WINAPI get_DefaultValue(BSTR *DefaultValue) = 0;
    virtual HRESULT WINAPI get_Attributes(__LONG32 *Attributes) = 0;
    virtual HRESULT WINAPI get_DisplayName(BSTR *DisplayName) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *Description) = 0;
    virtual HRESULT WINAPI get_HelpLocation(BSTR *HelpLocation) = 0;
    virtual HRESULT WINAPI get_HelpKeyword(BSTR *HelpKeyword) = 0;
  };
#else
  typedef struct IMsmConfigurableItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmConfigurableItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmConfigurableItem *This);
      ULONG (WINAPI *Release)(IMsmConfigurableItem *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmConfigurableItem *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmConfigurableItem *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmConfigurableItem *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmConfigurableItem *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(IMsmConfigurableItem *This,BSTR *Name);
      HRESULT (WINAPI *get_Format)(IMsmConfigurableItem *This,msmConfigurableItemFormat *Format);
      HRESULT (WINAPI *get_Type)(IMsmConfigurableItem *This,BSTR *Type);
      HRESULT (WINAPI *get_Context)(IMsmConfigurableItem *This,BSTR *Context);
      HRESULT (WINAPI *get_DefaultValue)(IMsmConfigurableItem *This,BSTR *DefaultValue);
      HRESULT (WINAPI *get_Attributes)(IMsmConfigurableItem *This,__LONG32 *Attributes);
      HRESULT (WINAPI *get_DisplayName)(IMsmConfigurableItem *This,BSTR *DisplayName);
      HRESULT (WINAPI *get_Description)(IMsmConfigurableItem *This,BSTR *Description);
      HRESULT (WINAPI *get_HelpLocation)(IMsmConfigurableItem *This,BSTR *HelpLocation);
      HRESULT (WINAPI *get_HelpKeyword)(IMsmConfigurableItem *This,BSTR *HelpKeyword);
    END_INTERFACE
  } IMsmConfigurableItemVtbl;
  struct IMsmConfigurableItem {
    CONST_VTBL struct IMsmConfigurableItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmConfigurableItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmConfigurableItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmConfigurableItem_Release(This) (This)->lpVtbl->Release(This)
#define IMsmConfigurableItem_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmConfigurableItem_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmConfigurableItem_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmConfigurableItem_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmConfigurableItem_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#define IMsmConfigurableItem_get_Format(This,Format) (This)->lpVtbl->get_Format(This,Format)
#define IMsmConfigurableItem_get_Type(This,Type) (This)->lpVtbl->get_Type(This,Type)
#define IMsmConfigurableItem_get_Context(This,Context) (This)->lpVtbl->get_Context(This,Context)
#define IMsmConfigurableItem_get_DefaultValue(This,DefaultValue) (This)->lpVtbl->get_DefaultValue(This,DefaultValue)
#define IMsmConfigurableItem_get_Attributes(This,Attributes) (This)->lpVtbl->get_Attributes(This,Attributes)
#define IMsmConfigurableItem_get_DisplayName(This,DisplayName) (This)->lpVtbl->get_DisplayName(This,DisplayName)
#define IMsmConfigurableItem_get_Description(This,Description) (This)->lpVtbl->get_Description(This,Description)
#define IMsmConfigurableItem_get_HelpLocation(This,HelpLocation) (This)->lpVtbl->get_HelpLocation(This,HelpLocation)
#define IMsmConfigurableItem_get_HelpKeyword(This,HelpKeyword) (This)->lpVtbl->get_HelpKeyword(This,HelpKeyword)
#endif
#endif
  HRESULT WINAPI IMsmConfigurableItem_get_Name_Proxy(IMsmConfigurableItem *This,BSTR *Name);
  void __RPC_STUB IMsmConfigurableItem_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_Format_Proxy(IMsmConfigurableItem *This,msmConfigurableItemFormat *Format);
  void __RPC_STUB IMsmConfigurableItem_get_Format_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_Type_Proxy(IMsmConfigurableItem *This,BSTR *Type);
  void __RPC_STUB IMsmConfigurableItem_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_Context_Proxy(IMsmConfigurableItem *This,BSTR *Context);
  void __RPC_STUB IMsmConfigurableItem_get_Context_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_DefaultValue_Proxy(IMsmConfigurableItem *This,BSTR *DefaultValue);
  void __RPC_STUB IMsmConfigurableItem_get_DefaultValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_Attributes_Proxy(IMsmConfigurableItem *This,__LONG32 *Attributes);
  void __RPC_STUB IMsmConfigurableItem_get_Attributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_DisplayName_Proxy(IMsmConfigurableItem *This,BSTR *DisplayName);
  void __RPC_STUB IMsmConfigurableItem_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_Description_Proxy(IMsmConfigurableItem *This,BSTR *Description);
  void __RPC_STUB IMsmConfigurableItem_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_HelpLocation_Proxy(IMsmConfigurableItem *This,BSTR *HelpLocation);
  void __RPC_STUB IMsmConfigurableItem_get_HelpLocation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItem_get_HelpKeyword_Proxy(IMsmConfigurableItem *This,BSTR *HelpKeyword);
  void __RPC_STUB IMsmConfigurableItem_get_HelpKeyword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumMsmConfigurableItem_INTERFACE_DEFINED__
#define __IEnumMsmConfigurableItem_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumMsmConfigurableItem : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(unsigned __LONG32 cFetch,IMsmConfigurableItem **rgmsmItems,unsigned __LONG32 *pcFetched) = 0;
    virtual HRESULT WINAPI Skip(unsigned __LONG32 cSkip) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumMsmConfigurableItem **pemsmConfigurableItem) = 0;
  };
#else
  typedef struct IEnumMsmConfigurableItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumMsmConfigurableItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumMsmConfigurableItem *This);
      ULONG (WINAPI *Release)(IEnumMsmConfigurableItem *This);
      HRESULT (WINAPI *Next)(IEnumMsmConfigurableItem *This,unsigned __LONG32 cFetch,IMsmConfigurableItem **rgmsmItems,unsigned __LONG32 *pcFetched);
      HRESULT (WINAPI *Skip)(IEnumMsmConfigurableItem *This,unsigned __LONG32 cSkip);
      HRESULT (WINAPI *Reset)(IEnumMsmConfigurableItem *This);
      HRESULT (WINAPI *Clone)(IEnumMsmConfigurableItem *This,IEnumMsmConfigurableItem **pemsmConfigurableItem);
    END_INTERFACE
  } IEnumMsmConfigurableItemVtbl;
  struct IEnumMsmConfigurableItem {
    CONST_VTBL struct IEnumMsmConfigurableItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumMsmConfigurableItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumMsmConfigurableItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumMsmConfigurableItem_Release(This) (This)->lpVtbl->Release(This)
#define IEnumMsmConfigurableItem_Next(This,cFetch,rgmsmItems,pcFetched) (This)->lpVtbl->Next(This,cFetch,rgmsmItems,pcFetched)
#define IEnumMsmConfigurableItem_Skip(This,cSkip) (This)->lpVtbl->Skip(This,cSkip)
#define IEnumMsmConfigurableItem_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumMsmConfigurableItem_Clone(This,pemsmConfigurableItem) (This)->lpVtbl->Clone(This,pemsmConfigurableItem)
#endif
#endif
  HRESULT WINAPI IEnumMsmConfigurableItem_Next_Proxy(IEnumMsmConfigurableItem *This,unsigned __LONG32 cFetch,IMsmConfigurableItem **rgmsmItems,unsigned __LONG32 *pcFetched);
  void __RPC_STUB IEnumMsmConfigurableItem_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmConfigurableItem_Skip_Proxy(IEnumMsmConfigurableItem *This,unsigned __LONG32 cSkip);
  void __RPC_STUB IEnumMsmConfigurableItem_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmConfigurableItem_Reset_Proxy(IEnumMsmConfigurableItem *This);
  void __RPC_STUB IEnumMsmConfigurableItem_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMsmConfigurableItem_Clone_Proxy(IEnumMsmConfigurableItem *This,IEnumMsmConfigurableItem **pemsmConfigurableItem);
  void __RPC_STUB IEnumMsmConfigurableItem_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmConfigurableItems_INTERFACE_DEFINED__
#define __IMsmConfigurableItems_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmConfigurableItems : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Item,IMsmConfigurableItem **Return) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **NewEnum) = 0;
  };
#else
  typedef struct IMsmConfigurableItemsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmConfigurableItems *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmConfigurableItems *This);
      ULONG (WINAPI *Release)(IMsmConfigurableItems *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmConfigurableItems *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmConfigurableItems *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmConfigurableItems *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmConfigurableItems *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IMsmConfigurableItems *This,__LONG32 Item,IMsmConfigurableItem **Return);
      HRESULT (WINAPI *get_Count)(IMsmConfigurableItems *This,__LONG32 *Count);
      HRESULT (WINAPI *get__NewEnum)(IMsmConfigurableItems *This,IUnknown **NewEnum);
    END_INTERFACE
  } IMsmConfigurableItemsVtbl;
  struct IMsmConfigurableItems {
    CONST_VTBL struct IMsmConfigurableItemsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmConfigurableItems_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmConfigurableItems_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmConfigurableItems_Release(This) (This)->lpVtbl->Release(This)
#define IMsmConfigurableItems_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmConfigurableItems_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmConfigurableItems_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmConfigurableItems_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmConfigurableItems_get_Item(This,Item,Return) (This)->lpVtbl->get_Item(This,Item,Return)
#define IMsmConfigurableItems_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IMsmConfigurableItems_get__NewEnum(This,NewEnum) (This)->lpVtbl->get__NewEnum(This,NewEnum)
#endif
#endif
  HRESULT WINAPI IMsmConfigurableItems_get_Item_Proxy(IMsmConfigurableItems *This,__LONG32 Item,IMsmConfigurableItem **Return);
  void __RPC_STUB IMsmConfigurableItems_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItems_get_Count_Proxy(IMsmConfigurableItems *This,__LONG32 *Count);
  void __RPC_STUB IMsmConfigurableItems_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigurableItems_get__NewEnum_Proxy(IMsmConfigurableItems *This,IUnknown **NewEnum);
  void __RPC_STUB IMsmConfigurableItems_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmConfigureModule_INTERFACE_DEFINED__
#define __IMsmConfigureModule_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmConfigureModule : public IDispatch {
  public:
    virtual HRESULT WINAPI ProvideTextData(const BSTR Name,BSTR *ConfigData) = 0;
    virtual HRESULT WINAPI ProvideIntegerData(const BSTR Name,__LONG32 *ConfigData) = 0;
  };
#else
  typedef struct IMsmConfigureModuleVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmConfigureModule *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmConfigureModule *This);
      ULONG (WINAPI *Release)(IMsmConfigureModule *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmConfigureModule *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmConfigureModule *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmConfigureModule *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmConfigureModule *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ProvideTextData)(IMsmConfigureModule *This,const BSTR Name,BSTR *ConfigData);
      HRESULT (WINAPI *ProvideIntegerData)(IMsmConfigureModule *This,const BSTR Name,__LONG32 *ConfigData);
    END_INTERFACE
  } IMsmConfigureModuleVtbl;
  struct IMsmConfigureModule {
    CONST_VTBL struct IMsmConfigureModuleVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmConfigureModule_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmConfigureModule_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmConfigureModule_Release(This) (This)->lpVtbl->Release(This)
#define IMsmConfigureModule_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmConfigureModule_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmConfigureModule_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmConfigureModule_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmConfigureModule_ProvideTextData(This,Name,ConfigData) (This)->lpVtbl->ProvideTextData(This,Name,ConfigData)
#define IMsmConfigureModule_ProvideIntegerData(This,Name,ConfigData) (This)->lpVtbl->ProvideIntegerData(This,Name,ConfigData)
#endif
#endif
  HRESULT WINAPI IMsmConfigureModule_ProvideTextData_Proxy(IMsmConfigureModule *This,const BSTR Name,BSTR *ConfigData);
  void __RPC_STUB IMsmConfigureModule_ProvideTextData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmConfigureModule_ProvideIntegerData_Proxy(IMsmConfigureModule *This,const BSTR Name,__LONG32 *ConfigData);
  void __RPC_STUB IMsmConfigureModule_ProvideIntegerData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef __IMsmMerge_INTERFACE_DEFINED__
#define __IMsmMerge_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmMerge : public IDispatch {
  public:
    virtual HRESULT WINAPI OpenDatabase(const BSTR Path) = 0;
    virtual HRESULT WINAPI OpenModule(const BSTR Path,const short Language) = 0;
    virtual HRESULT WINAPI CloseDatabase(const VARIANT_BOOL Commit) = 0;
    virtual HRESULT WINAPI CloseModule(void) = 0;
    virtual HRESULT WINAPI OpenLog(const BSTR Path) = 0;
    virtual HRESULT WINAPI CloseLog(void) = 0;
    virtual HRESULT WINAPI Log(const BSTR Message) = 0;
    virtual HRESULT WINAPI get_Errors(IMsmErrors **Errors) = 0;
    virtual HRESULT WINAPI get_Dependencies(IMsmDependencies **Dependencies) = 0;
    virtual HRESULT WINAPI Merge(const BSTR Feature,const BSTR RedirectDir) = 0;
    virtual HRESULT WINAPI Connect(const BSTR Feature) = 0;
    virtual HRESULT WINAPI ExtractCAB(const BSTR FileName) = 0;
    virtual HRESULT WINAPI ExtractFiles(const BSTR Path) = 0;
  };
#else
  typedef struct IMsmMergeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmMerge *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmMerge *This);
      ULONG (WINAPI *Release)(IMsmMerge *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmMerge *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmMerge *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmMerge *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmMerge *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OpenDatabase)(IMsmMerge *This,const BSTR Path);
      HRESULT (WINAPI *OpenModule)(IMsmMerge *This,const BSTR Path,const short Language);
      HRESULT (WINAPI *CloseDatabase)(IMsmMerge *This,const VARIANT_BOOL Commit);
      HRESULT (WINAPI *CloseModule)(IMsmMerge *This);
      HRESULT (WINAPI *OpenLog)(IMsmMerge *This,const BSTR Path);
      HRESULT (WINAPI *CloseLog)(IMsmMerge *This);
      HRESULT (WINAPI *Log)(IMsmMerge *This,const BSTR Message);
      HRESULT (WINAPI *get_Errors)(IMsmMerge *This,IMsmErrors **Errors);
      HRESULT (WINAPI *get_Dependencies)(IMsmMerge *This,IMsmDependencies **Dependencies);
      HRESULT (WINAPI *Merge)(IMsmMerge *This,const BSTR Feature,const BSTR RedirectDir);
      HRESULT (WINAPI *Connect)(IMsmMerge *This,const BSTR Feature);
      HRESULT (WINAPI *ExtractCAB)(IMsmMerge *This,const BSTR FileName);
      HRESULT (WINAPI *ExtractFiles)(IMsmMerge *This,const BSTR Path);
    END_INTERFACE
  } IMsmMergeVtbl;
  struct IMsmMerge {
    CONST_VTBL struct IMsmMergeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmMerge_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmMerge_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmMerge_Release(This) (This)->lpVtbl->Release(This)
#define IMsmMerge_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmMerge_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmMerge_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmMerge_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmMerge_OpenDatabase(This,Path) (This)->lpVtbl->OpenDatabase(This,Path)
#define IMsmMerge_OpenModule(This,Path,Language) (This)->lpVtbl->OpenModule(This,Path,Language)
#define IMsmMerge_CloseDatabase(This,Commit) (This)->lpVtbl->CloseDatabase(This,Commit)
#define IMsmMerge_CloseModule(This) (This)->lpVtbl->CloseModule(This)
#define IMsmMerge_OpenLog(This,Path) (This)->lpVtbl->OpenLog(This,Path)
#define IMsmMerge_CloseLog(This) (This)->lpVtbl->CloseLog(This)
#define IMsmMerge_Log(This,Message) (This)->lpVtbl->Log(This,Message)
#define IMsmMerge_get_Errors(This,Errors) (This)->lpVtbl->get_Errors(This,Errors)
#define IMsmMerge_get_Dependencies(This,Dependencies) (This)->lpVtbl->get_Dependencies(This,Dependencies)
#define IMsmMerge_Merge(This,Feature,RedirectDir) (This)->lpVtbl->Merge(This,Feature,RedirectDir)
#define IMsmMerge_Connect(This,Feature) (This)->lpVtbl->Connect(This,Feature)
#define IMsmMerge_ExtractCAB(This,FileName) (This)->lpVtbl->ExtractCAB(This,FileName)
#define IMsmMerge_ExtractFiles(This,Path) (This)->lpVtbl->ExtractFiles(This,Path)
#endif
#endif
  HRESULT WINAPI IMsmMerge_OpenDatabase_Proxy(IMsmMerge *This,const BSTR Path);
  void __RPC_STUB IMsmMerge_OpenDatabase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_OpenModule_Proxy(IMsmMerge *This,const BSTR Path,const short Language);
  void __RPC_STUB IMsmMerge_OpenModule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_CloseDatabase_Proxy(IMsmMerge *This,const VARIANT_BOOL Commit);
  void __RPC_STUB IMsmMerge_CloseDatabase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_CloseModule_Proxy(IMsmMerge *This);
  void __RPC_STUB IMsmMerge_CloseModule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_OpenLog_Proxy(IMsmMerge *This,const BSTR Path);
  void __RPC_STUB IMsmMerge_OpenLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_CloseLog_Proxy(IMsmMerge *This);
  void __RPC_STUB IMsmMerge_CloseLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_Log_Proxy(IMsmMerge *This,const BSTR Message);
  void __RPC_STUB IMsmMerge_Log_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_get_Errors_Proxy(IMsmMerge *This,IMsmErrors **Errors);
  void __RPC_STUB IMsmMerge_get_Errors_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_get_Dependencies_Proxy(IMsmMerge *This,IMsmDependencies **Dependencies);
  void __RPC_STUB IMsmMerge_get_Dependencies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_Merge_Proxy(IMsmMerge *This,const BSTR Feature,const BSTR RedirectDir);
  void __RPC_STUB IMsmMerge_Merge_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_Connect_Proxy(IMsmMerge *This,const BSTR Feature);
  void __RPC_STUB IMsmMerge_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_ExtractCAB_Proxy(IMsmMerge *This,const BSTR FileName);
  void __RPC_STUB IMsmMerge_ExtractCAB_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge_ExtractFiles_Proxy(IMsmMerge *This,const BSTR Path);
  void __RPC_STUB IMsmMerge_ExtractFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMsmGetFiles_INTERFACE_DEFINED__
#define __IMsmGetFiles_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmGetFiles : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ModuleFiles(IMsmStrings **Files) = 0;
  };
#else
  typedef struct IMsmGetFilesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmGetFiles *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmGetFiles *This);
      ULONG (WINAPI *Release)(IMsmGetFiles *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmGetFiles *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmGetFiles *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmGetFiles *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmGetFiles *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ModuleFiles)(IMsmGetFiles *This,IMsmStrings **Files);
    END_INTERFACE
  } IMsmGetFilesVtbl;
  struct IMsmGetFiles {
    CONST_VTBL struct IMsmGetFilesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmGetFiles_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmGetFiles_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmGetFiles_Release(This) (This)->lpVtbl->Release(This)
#define IMsmGetFiles_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmGetFiles_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmGetFiles_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmGetFiles_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmGetFiles_get_ModuleFiles(This,Files) (This)->lpVtbl->get_ModuleFiles(This,Files)
#endif
#endif
  HRESULT WINAPI IMsmGetFiles_get_ModuleFiles_Proxy(IMsmGetFiles *This,IMsmStrings **Files);
  void __RPC_STUB IMsmGetFiles_get_ModuleFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#if (_WIN32_MSM >= 150)
#ifndef __IMsmMerge2_INTERFACE_DEFINED__
#define __IMsmMerge2_INTERFACE_DEFINED__
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMsmMerge2 : public IDispatch {
  public:
    virtual HRESULT WINAPI OpenDatabase(const BSTR Path) = 0;
    virtual HRESULT WINAPI OpenModule(const BSTR Path,const short Language) = 0;
    virtual HRESULT WINAPI CloseDatabase(const VARIANT_BOOL Commit) = 0;
    virtual HRESULT WINAPI CloseModule(void) = 0;
    virtual HRESULT WINAPI OpenLog(const BSTR Path) = 0;
    virtual HRESULT WINAPI CloseLog(void) = 0;
    virtual HRESULT WINAPI Log(const BSTR Message) = 0;
    virtual HRESULT WINAPI get_Errors(IMsmErrors **Errors) = 0;
    virtual HRESULT WINAPI get_Dependencies(IMsmDependencies **Dependencies) = 0;
    virtual HRESULT WINAPI Merge(const BSTR Feature,const BSTR RedirectDir) = 0;
    virtual HRESULT WINAPI Connect(const BSTR Feature) = 0;
    virtual HRESULT WINAPI ExtractCAB(const BSTR FileName) = 0;
    virtual HRESULT WINAPI ExtractFiles(const BSTR Path) = 0;
    virtual HRESULT WINAPI MergeEx(const BSTR Feature,const BSTR RedirectDir,IUnknown *pConfiguration) = 0;
    virtual HRESULT WINAPI ExtractFilesEx(const BSTR Path,VARIANT_BOOL fLongFileNames,IMsmStrings **pFilePaths) = 0;
    virtual HRESULT WINAPI get_ConfigurableItems(IMsmConfigurableItems **ConfigurableItems) = 0;
    virtual HRESULT WINAPI CreateSourceImage(const BSTR Path,VARIANT_BOOL fLongFileNames,IMsmStrings **pFilePaths) = 0;
    virtual HRESULT WINAPI get_ModuleFiles(IMsmStrings **Files) = 0;
  };
#else
  typedef struct IMsmMerge2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMsmMerge2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMsmMerge2 *This);
      ULONG (WINAPI *Release)(IMsmMerge2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMsmMerge2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMsmMerge2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMsmMerge2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMsmMerge2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OpenDatabase)(IMsmMerge2 *This,const BSTR Path);
      HRESULT (WINAPI *OpenModule)(IMsmMerge2 *This,const BSTR Path,const short Language);
      HRESULT (WINAPI *CloseDatabase)(IMsmMerge2 *This,const VARIANT_BOOL Commit);
      HRESULT (WINAPI *CloseModule)(IMsmMerge2 *This);
      HRESULT (WINAPI *OpenLog)(IMsmMerge2 *This,const BSTR Path);
      HRESULT (WINAPI *CloseLog)(IMsmMerge2 *This);
      HRESULT (WINAPI *Log)(IMsmMerge2 *This,const BSTR Message);
      HRESULT (WINAPI *get_Errors)(IMsmMerge2 *This,IMsmErrors **Errors);
      HRESULT (WINAPI *get_Dependencies)(IMsmMerge2 *This,IMsmDependencies **Dependencies);
      HRESULT (WINAPI *Merge)(IMsmMerge2 *This,const BSTR Feature,const BSTR RedirectDir);
      HRESULT (WINAPI *Connect)(IMsmMerge2 *This,const BSTR Feature);
      HRESULT (WINAPI *ExtractCAB)(IMsmMerge2 *This,const BSTR FileName);
      HRESULT (WINAPI *ExtractFiles)(IMsmMerge2 *This,const BSTR Path);
      HRESULT (WINAPI *MergeEx)(IMsmMerge2 *This,const BSTR Feature,const BSTR RedirectDir,IMsmConfigureModule *pConfiguration);
      HRESULT (WINAPI *ExtractFilesEx)(IMsmMerge2 *This,const BSTR Path,VARIANT_BOOL fLongFileNames,IMsmStrings **pFilePaths);
      HRESULT (WINAPI *get_ConfigurableItems)(IMsmMerge2 *This,IMsmConfigurableItems **ConfigurableItems);
      HRESULT (WINAPI *CreateSourceImage)(IMsmMerge2 *This,const BSTR Path,VARIANT_BOOL fLongFileNames,IMsmStrings **pFilePaths);
      HRESULT (WINAPI *get_ModuleFiles)(IMsmMerge2 *This,IMsmStrings **Files);
    END_INTERFACE
  } IMsmMerge2Vtbl;
  struct IMsmMerge2 {
    CONST_VTBL struct IMsmMerge2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMsmMerge2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMsmMerge2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMsmMerge2_Release(This) (This)->lpVtbl->Release(This)
#define IMsmMerge2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMsmMerge2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMsmMerge2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMsmMerge2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMsmMerge2_OpenDatabase(This,Path) (This)->lpVtbl->OpenDatabase(This,Path)
#define IMsmMerge2_OpenModule(This,Path,Language) (This)->lpVtbl->OpenModule(This,Path,Language)
#define IMsmMerge2_CloseDatabase(This,Commit) (This)->lpVtbl->CloseDatabase(This,Commit)
#define IMsmMerge2_CloseModule(This) (This)->lpVtbl->CloseModule(This)
#define IMsmMerge2_OpenLog(This,Path) (This)->lpVtbl->OpenLog(This,Path)
#define IMsmMerge2_CloseLog(This) (This)->lpVtbl->CloseLog(This)
#define IMsmMerge2_Log(This,Message) (This)->lpVtbl->Log(This,Message)
#define IMsmMerge2_get_Errors(This,Errors) (This)->lpVtbl->get_Errors(This,Errors)
#define IMsmMerge2_get_Dependencies(This,Dependencies) (This)->lpVtbl->get_Dependencies(This,Dependencies)
#define IMsmMerge2_Merge(This,Feature,RedirectDir) (This)->lpVtbl->Merge(This,Feature,RedirectDir)
#define IMsmMerge2_Connect(This,Feature) (This)->lpVtbl->Connect(This,Feature)
#define IMsmMerge2_ExtractCAB(This,FileName) (This)->lpVtbl->ExtractCAB(This,FileName)
#define IMsmMerge2_ExtractFiles(This,Path) (This)->lpVtbl->ExtractFiles(This,Path)
#define IMsmMerge2_MergeEx(This,Feature,RedirectDir,pConfiguration) (This)->lpVtbl->MergeEx(This,Feature,RedirectDir,pConfiguration)
#define IMsmMerge2_ExtractFilesEx(This,Path,fLongFileNames,pFilePaths) (This)->lpVtbl->ExtractFilesEx(This,Path,fLongFileNames,pFilePaths)
#define IMsmMerge2_get_ConfigurableItems(This,ConfigurableItems) (This)->lpVtbl->get_ConfigurableItems(This,ConfigurableItems)
#define IMsmMerge2_CreateSourceImage(This,Path,fLongFileNames,pFilePaths) (This)->lpVtbl->CreateSourceImage(This,Path,fLongFileNames,pFilePaths)
#define IMsmMerge2_get_ModuleFiles(This,Files) (This)->lpVtbl->get_ModuleFiles(This,Files)
#endif
#endif
  HRESULT WINAPI IMsmMerge2_OpenDatabase_Proxy(IMsmMerge2 *This,const BSTR Path);
  void __RPC_STUB IMsmMerge2_OpenDatabase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_OpenModule_Proxy(IMsmMerge2 *This,const BSTR Path,const short Language);
  void __RPC_STUB IMsmMerge2_OpenModule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_CloseDatabase_Proxy(IMsmMerge2 *This,const VARIANT_BOOL Commit);
  void __RPC_STUB IMsmMerge2_CloseDatabase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_CloseModule_Proxy(IMsmMerge2 *This);
  void __RPC_STUB IMsmMerge2_CloseModule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_OpenLog_Proxy(IMsmMerge2 *This,const BSTR Path);
  void __RPC_STUB IMsmMerge2_OpenLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_CloseLog_Proxy(IMsmMerge2 *This);
  void __RPC_STUB IMsmMerge2_CloseLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_Log_Proxy(IMsmMerge2 *This,const BSTR Message);
  void __RPC_STUB IMsmMerge2_Log_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_get_Errors_Proxy(IMsmMerge2 *This,IMsmErrors **Errors);
  void __RPC_STUB IMsmMerge2_get_Errors_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_get_Dependencies_Proxy(IMsmMerge2 *This,IMsmDependencies **Dependencies);
  void __RPC_STUB IMsmMerge2_get_Dependencies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_Merge_Proxy(IMsmMerge2 *This,const BSTR Feature,const BSTR RedirectDir);
  void __RPC_STUB IMsmMerge2_Merge_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_Connect_Proxy(IMsmMerge2 *This,const BSTR Feature);
  void __RPC_STUB IMsmMerge2_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_ExtractCAB_Proxy(IMsmMerge2 *This,const BSTR FileName);
  void __RPC_STUB IMsmMerge2_ExtractCAB_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_ExtractFiles_Proxy(IMsmMerge2 *This,const BSTR Path);
  void __RPC_STUB IMsmMerge2_ExtractFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_MergeEx_Proxy(IMsmMerge2 *This,const BSTR Feature,const BSTR RedirectDir,IMsmConfigureModule *pConfiguration);
  void __RPC_STUB IMsmMerge2_MergeEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_ExtractFilesEx_Proxy(IMsmMerge2 *This,const BSTR Path,VARIANT_BOOL fLongFileNames,IMsmStrings **pFilePaths);
  void __RPC_STUB IMsmMerge2_ExtractFilesEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_get_ConfigurableItems_Proxy(IMsmMerge2 *This,IMsmConfigurableItems **ConfigurableItems);
  void __RPC_STUB IMsmMerge2_get_ConfigurableItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_CreateSourceImage_Proxy(IMsmMerge2 *This,const BSTR Path,VARIANT_BOOL fLongFileNames,IMsmStrings **pFilePaths);
  void __RPC_STUB IMsmMerge2_CreateSourceImage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMsmMerge2_get_ModuleFiles_Proxy(IMsmMerge2 *This,IMsmStrings **Files);
  void __RPC_STUB IMsmMerge2_get_ModuleFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef __MsmMergeTypeLib_LIBRARY_DEFINED__
#define __MsmMergeTypeLib_LIBRARY_DEFINED__
#ifdef __cplusplus
  class MsmMerge;
#endif

#if (_WIN32_MSM >= 150)
#ifdef __cplusplus
  class MsmMerge2;
#endif
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif

DEFINE_GUID(IID_IEnumMsmString,0x0ADDA826,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IMsmStrings,0x0ADDA827,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IMsmError,0x0ADDA828,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IEnumMsmError,0x0ADDA829,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IMsmErrors,0x0ADDA82A,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IMsmDependency,0x0ADDA82B,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IEnumMsmDependency,0x0ADDA82C,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IMsmDependencies,0x0ADDA82D,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IMsmMerge,0x0ADDA82E,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(IID_IMsmGetFiles,0x7041ae26,0x2d78,0x11d2,0x88,0x8a,0x0,0xa0,0xc9,0x81,0xb0,0x15);
DEFINE_GUID(LIBID_MsmMergeTypeLib,0x0ADDA82F,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
DEFINE_GUID(CLSID_MsmMerge,0x0ADDA830,0x2C26,0x11D2,0xAD,0x65,0x00,0xA0,0xC9,0xAF,0x11,0xA6);
#if (_WIN32_MSM >= 150)
DEFINE_GUID(IID_IMsmMerge2,0x351A72AB,0x21CB,0x47AB,0xB7,0xAA,0xC4,0xD7,0xB0,0x2E,0xA3,0x05);
DEFINE_GUID(IID_IMsmConfigurableItem,0x4D6E6284,0xD21D,0x401E,0x84,0xF6,0x90,0x9E,0x00,0xB5,0x0F,0x71);
DEFINE_GUID(IID_IEnumMsmConfigurableItem,0x832C6969,0x4826,0x4C24,0xA3,0x97,0xB7,0x00,0x2D,0x81,0x96,0xE6);
DEFINE_GUID(IID_IMsmConfigurableItems,0x55BF723C,0x9A0D,0x463E,0xB4,0x2B,0xB4,0xFB,0xC7,0xBE,0x3C,0x7C);
DEFINE_GUID(IID_IMsmConfigureModule,0xAC013209,0x18A7,0x4851,0x8A,0x21,0x23,0x53,0x44,0x3D,0x70,0xA0);
DEFINE_GUID(CLSID_MsmMerge2,0xF94985D5,0x29F9,0x4743,0x98,0x05,0x99,0xBC,0x3F,0x35,0xB6,0x78);
#endif
#endif
