/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
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

#ifndef __oledbdep_h__
#define __oledbdep_h__

#ifndef __IRowsetNextRowset_FWD_DEFINED__
#define __IRowsetNextRowset_FWD_DEFINED__
typedef struct IRowsetNextRowset IRowsetNextRowset;
#endif

#ifndef __IRowsetNewRowAfter_FWD_DEFINED__
#define __IRowsetNewRowAfter_FWD_DEFINED__
typedef struct IRowsetNewRowAfter IRowsetNewRowAfter;
#endif

#ifndef __IRowsetWithParameters_FWD_DEFINED__
#define __IRowsetWithParameters_FWD_DEFINED__
typedef struct IRowsetWithParameters IRowsetWithParameters;
#endif

#ifndef __IRowsetAsynch_FWD_DEFINED__
#define __IRowsetAsynch_FWD_DEFINED__
typedef struct IRowsetAsynch IRowsetAsynch;
#endif

#ifndef __IRowsetKeys_FWD_DEFINED__
#define __IRowsetKeys_FWD_DEFINED__
typedef struct IRowsetKeys IRowsetKeys;
#endif

#ifndef __IRowsetWatchAll_FWD_DEFINED__
#define __IRowsetWatchAll_FWD_DEFINED__
typedef struct IRowsetWatchAll IRowsetWatchAll;
#endif

#ifndef __IRowsetWatchNotify_FWD_DEFINED__
#define __IRowsetWatchNotify_FWD_DEFINED__
typedef struct IRowsetWatchNotify IRowsetWatchNotify;
#endif

#ifndef __IRowsetWatchRegion_FWD_DEFINED__
#define __IRowsetWatchRegion_FWD_DEFINED__
typedef struct IRowsetWatchRegion IRowsetWatchRegion;
#endif

#ifndef __IRowsetCopyRows_FWD_DEFINED__
#define __IRowsetCopyRows_FWD_DEFINED__
typedef struct IRowsetCopyRows IRowsetCopyRows;
#endif

#ifndef __IReadData_FWD_DEFINED__
#define __IReadData_FWD_DEFINED__
typedef struct IReadData IReadData;
#endif

#ifndef __ICommandCost_FWD_DEFINED__
#define __ICommandCost_FWD_DEFINED__
typedef struct ICommandCost ICommandCost;
#endif

#ifndef __ICommandValidate_FWD_DEFINED__
#define __ICommandValidate_FWD_DEFINED__
typedef struct ICommandValidate ICommandValidate;
#endif

#ifndef __ITableRename_FWD_DEFINED__
#define __ITableRename_FWD_DEFINED__
typedef struct ITableRename ITableRename;
#endif

#ifndef __IDBSchemaCommand_FWD_DEFINED__
#define __IDBSchemaCommand_FWD_DEFINED__
typedef struct IDBSchemaCommand IDBSchemaCommand;
#endif

#ifndef __IProvideMoniker_FWD_DEFINED__
#define __IProvideMoniker_FWD_DEFINED__
typedef struct IProvideMoniker IProvideMoniker;
#endif

#include "oledb.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifdef _WIN64
#include <pshpack8.h>
#else
#include <pshpack2.h>
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oledbdep_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledbdep_0000_v0_0_s_ifspec;

#ifndef __DBStructureDefinitionsDep_INTERFACE_DEFINED__
#define __DBStructureDefinitionsDep_INTERFACE_DEFINED__

#undef OLEDBDECLSPEC
#define OLEDBDECLSPEC __declspec(selectany)

#ifdef DBINITCONSTANTS
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_CHECK_OPTION = {0xc8b5220b,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_CONSTRAINT_CHECK_DEFERRED = {0xc8b521f0,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_DROP_CASCADE = {0xc8b521f3,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_UNIQUE = {0xc8b521f5,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_ON_COMMIT_PRESERVE_ROWS = {0xc8b52230,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_PRIMARY = {0xc8b521fc,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_CLUSTERED = {0xc8b521ff,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_NONCLUSTERED = {0xc8b52200,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_BTREE = {0xc8b52201,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_HASH = {0xc8b52202,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_FILLFACTOR = {0xc8b52203,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_INITIALSIZE = {0xc8b52204,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_DISALLOWNULL = {0xc8b52205,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_IGNORENULL = {0xc8b52206,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_IGNOREANYNULL = {0xc8b52207,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_SORTBOOKMARKS = {0xc8b52208,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_AUTOMATICUPDATE = {0xc8b52209,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DB_PROPERTY_EXPLICITUPDATE = {0xc8b5220a,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
#else
  extern const GUID DB_PROPERTY_CHECK_OPTION;
  extern const GUID DB_PROPERTY_CONSTRAINT_CHECK_DEFERRED;
  extern const GUID DB_PROPERTY_DROP_CASCADE;
  extern const GUID DB_PROPERTY_ON_COMMIT_PRESERVE_ROWS;
  extern const GUID DB_PROPERTY_UNIQUE;
  extern const GUID DB_PROPERTY_PRIMARY;
  extern const GUID DB_PROPERTY_CLUSTERED;
  extern const GUID DB_PROPERTY_NONCLUSTERED;
  extern const GUID DB_PROPERTY_BTREE;
  extern const GUID DB_PROPERTY_HASH;
  extern const GUID DB_PROPERTY_FILLFACTOR;
  extern const GUID DB_PROPERTY_INITIALSIZE;
  extern const GUID DB_PROPERTY_DISALLOWNULL;
  extern const GUID DB_PROPERTY_IGNORENULL;
  extern const GUID DB_PROPERTY_IGNOREANYNULL;
  extern const GUID DB_PROPERTY_SORTBOOKMARKS;
  extern const GUID DB_PROPERTY_AUTOMATICUPDATE;
  extern const GUID DB_PROPERTY_EXPLICITUPDATE;
#endif

  enum DBPROPENUM25_DEPRECATED {
    DBPROP_ICommandCost = 0x8d,DBPROP_ICommandTree = 0x8e,DBPROP_ICommandValidate = 0x8f,DBPROP_IDBSchemaCommand = 0x90,
    DBPROP_IProvideMoniker = 0x7d,DBPROP_IQuery = 0x92,DBPROP_IReadData = 0x93,DBPROP_IRowsetAsynch = 0x94,DBPROP_IRowsetCopyRows = 0x95,
    DBPROP_IRowsetKeys = 0x97,DBPROP_IRowsetNewRowAfter = 0x98,DBPROP_IRowsetNextRowset = 0x99,DBPROP_IRowsetWatchAll = 0x9b,
    DBPROP_IRowsetWatchNotify = 0x9c,DBPROP_IRowsetWatchRegion = 0x9d,DBPROP_IRowsetWithParameters = 0x9e
  };

  enum DBREASONENUM25 {
    DBREASON_ROWSET_ROWSADDED = DBREASON_ROW_ASYNCHINSERT + 1,
    DBREASON_ROWSET_POPULATIONCOMPLETE,DBREASON_ROWSET_POPULATIONSTOPPED
  };

  extern RPC_IF_HANDLE DBStructureDefinitionsDep_v0_0_c_ifspec;
  extern RPC_IF_HANDLE DBStructureDefinitionsDep_v0_0_s_ifspec;
#endif

#ifndef __IRowsetNextRowset_INTERFACE_DEFINED__
#define __IRowsetNextRowset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetNextRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetNextRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI GetNextRowset(IUnknown *pUnkOuter,REFIID riid,IUnknown **ppNextRowset) = 0;
  };
#else
  typedef struct IRowsetNextRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetNextRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetNextRowset *This);
      ULONG (WINAPI *Release)(IRowsetNextRowset *This);
      HRESULT (WINAPI *GetNextRowset)(IRowsetNextRowset *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppNextRowset);
    END_INTERFACE
  } IRowsetNextRowsetVtbl;
  struct IRowsetNextRowset {
    CONST_VTBL struct IRowsetNextRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetNextRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetNextRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetNextRowset_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetNextRowset_GetNextRowset(This,pUnkOuter,riid,ppNextRowset) (This)->lpVtbl->GetNextRowset(This,pUnkOuter,riid,ppNextRowset)
#endif
#endif
  HRESULT WINAPI IRowsetNextRowset_GetNextRowset_Proxy(IRowsetNextRowset *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppNextRowset);
  void __RPC_STUB IRowsetNextRowset_GetNextRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetNewRowAfter_INTERFACE_DEFINED__
#define __IRowsetNewRowAfter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetNewRowAfter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetNewRowAfter : public IUnknown {
  public:
    virtual HRESULT WINAPI SetNewDataAfter(HCHAPTER hChapter,ULONG cbbmPrevious,const BYTE *pbmPrevious,HACCESSOR hAccessor,BYTE *pData,HROW *phRow) = 0;
  };
#else
  typedef struct IRowsetNewRowAfterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetNewRowAfter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetNewRowAfter *This);
      ULONG (WINAPI *Release)(IRowsetNewRowAfter *This);
      HRESULT (WINAPI *SetNewDataAfter)(IRowsetNewRowAfter *This,HCHAPTER hChapter,ULONG cbbmPrevious,const BYTE *pbmPrevious,HACCESSOR hAccessor,BYTE *pData,HROW *phRow);
    END_INTERFACE
  } IRowsetNewRowAfterVtbl;
  struct IRowsetNewRowAfter {
    CONST_VTBL struct IRowsetNewRowAfterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetNewRowAfter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetNewRowAfter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetNewRowAfter_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetNewRowAfter_SetNewDataAfter(This,hChapter,cbbmPrevious,pbmPrevious,hAccessor,pData,phRow) (This)->lpVtbl->SetNewDataAfter(This,hChapter,cbbmPrevious,pbmPrevious,hAccessor,pData,phRow)
#endif
#endif
  HRESULT WINAPI IRowsetNewRowAfter_SetNewDataAfter_Proxy(IRowsetNewRowAfter *This,HCHAPTER hChapter,ULONG cbbmPrevious,const BYTE *pbmPrevious,HACCESSOR hAccessor,BYTE *pData,HROW *phRow);
  void __RPC_STUB IRowsetNewRowAfter_SetNewDataAfter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetWithParameters_INTERFACE_DEFINED__
#define __IRowsetWithParameters_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetWithParameters;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetWithParameters : public IUnknown {
  public:
    virtual HRESULT WINAPI GetParameterInfo(DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,OLECHAR **ppNamesBuffer) = 0;
    virtual HRESULT WINAPI Requery(DBPARAMS *pParams,ULONG *pulErrorParam,HCHAPTER *phReserved) = 0;
  };
#else
  typedef struct IRowsetWithParametersVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetWithParameters *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetWithParameters *This);
      ULONG (WINAPI *Release)(IRowsetWithParameters *This);
      HRESULT (WINAPI *GetParameterInfo)(IRowsetWithParameters *This,DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,OLECHAR **ppNamesBuffer);
      HRESULT (WINAPI *Requery)(IRowsetWithParameters *This,DBPARAMS *pParams,ULONG *pulErrorParam,HCHAPTER *phReserved);
    END_INTERFACE
  } IRowsetWithParametersVtbl;
  struct IRowsetWithParameters {
    CONST_VTBL struct IRowsetWithParametersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetWithParameters_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetWithParameters_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetWithParameters_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetWithParameters_GetParameterInfo(This,pcParams,prgParamInfo,ppNamesBuffer) (This)->lpVtbl->GetParameterInfo(This,pcParams,prgParamInfo,ppNamesBuffer)
#define IRowsetWithParameters_Requery(This,pParams,pulErrorParam,phReserved) (This)->lpVtbl->Requery(This,pParams,pulErrorParam,phReserved)
#endif
#endif
  HRESULT WINAPI IRowsetWithParameters_GetParameterInfo_Proxy(IRowsetWithParameters *This,DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,OLECHAR **ppNamesBuffer);
  void __RPC_STUB IRowsetWithParameters_GetParameterInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWithParameters_Requery_Proxy(IRowsetWithParameters *This,DBPARAMS *pParams,ULONG *pulErrorParam,HCHAPTER *phReserved);
  void __RPC_STUB IRowsetWithParameters_Requery_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetAsynch_INTERFACE_DEFINED__
#define __IRowsetAsynch_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetAsynch;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetAsynch : public IUnknown {
  public:
    virtual HRESULT WINAPI RatioFinished(DBCOUNTITEM *pulDenominator,DBCOUNTITEM *pulNumerator,DBCOUNTITEM *pcRows,WINBOOL *pfNewRows) = 0;
    virtual HRESULT WINAPI Stop(void) = 0;
  };
#else
  typedef struct IRowsetAsynchVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetAsynch *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetAsynch *This);
      ULONG (WINAPI *Release)(IRowsetAsynch *This);
      HRESULT (WINAPI *RatioFinished)(IRowsetAsynch *This,DBCOUNTITEM *pulDenominator,DBCOUNTITEM *pulNumerator,DBCOUNTITEM *pcRows,WINBOOL *pfNewRows);
      HRESULT (WINAPI *Stop)(IRowsetAsynch *This);
    END_INTERFACE
  } IRowsetAsynchVtbl;
  struct IRowsetAsynch {
    CONST_VTBL struct IRowsetAsynchVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetAsynch_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetAsynch_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetAsynch_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetAsynch_RatioFinished(This,pulDenominator,pulNumerator,pcRows,pfNewRows) (This)->lpVtbl->RatioFinished(This,pulDenominator,pulNumerator,pcRows,pfNewRows)
#define IRowsetAsynch_Stop(This) (This)->lpVtbl->Stop(This)
#endif
#endif
  HRESULT WINAPI IRowsetAsynch_RatioFinished_Proxy(IRowsetAsynch *This,DBCOUNTITEM *pulDenominator,DBCOUNTITEM *pulNumerator,DBCOUNTITEM *pcRows,WINBOOL *pfNewRows);
  void __RPC_STUB IRowsetAsynch_RatioFinished_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetAsynch_Stop_Proxy(IRowsetAsynch *This);
  void __RPC_STUB IRowsetAsynch_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetKeys_INTERFACE_DEFINED__
#define __IRowsetKeys_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetKeys;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetKeys : public IUnknown {
  public:
    virtual HRESULT WINAPI ListKeys(DBORDINAL *pcColumns,DBORDINAL **prgColumns) = 0;
  };
#else
  typedef struct IRowsetKeysVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetKeys *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetKeys *This);
      ULONG (WINAPI *Release)(IRowsetKeys *This);
      HRESULT (WINAPI *ListKeys)(IRowsetKeys *This,DBORDINAL *pcColumns,DBORDINAL **prgColumns);
    END_INTERFACE
  } IRowsetKeysVtbl;
  struct IRowsetKeys {
    CONST_VTBL struct IRowsetKeysVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetKeys_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetKeys_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetKeys_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetKeys_ListKeys(This,pcColumns,prgColumns) (This)->lpVtbl->ListKeys(This,pcColumns,prgColumns)
#endif
#endif
  HRESULT WINAPI IRowsetKeys_ListKeys_Proxy(IRowsetKeys *This,DBORDINAL *pcColumns,DBORDINAL **prgColumns);
  void __RPC_STUB IRowsetKeys_ListKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetWatchAll_INTERFACE_DEFINED__
#define __IRowsetWatchAll_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetWatchAll;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetWatchAll : public IUnknown {
  public:
    virtual HRESULT WINAPI Acknowledge(void) = 0;
    virtual HRESULT WINAPI Start(void) = 0;
    virtual HRESULT WINAPI StopWatching(void) = 0;
  };
#else
  typedef struct IRowsetWatchAllVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetWatchAll *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetWatchAll *This);
      ULONG (WINAPI *Release)(IRowsetWatchAll *This);
      HRESULT (WINAPI *Acknowledge)(IRowsetWatchAll *This);
      HRESULT (WINAPI *Start)(IRowsetWatchAll *This);
      HRESULT (WINAPI *StopWatching)(IRowsetWatchAll *This);
    END_INTERFACE
  } IRowsetWatchAllVtbl;
  struct IRowsetWatchAll {
    CONST_VTBL struct IRowsetWatchAllVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetWatchAll_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetWatchAll_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetWatchAll_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetWatchAll_Acknowledge(This) (This)->lpVtbl->Acknowledge(This)
#define IRowsetWatchAll_Start(This) (This)->lpVtbl->Start(This)
#define IRowsetWatchAll_StopWatching(This) (This)->lpVtbl->StopWatching(This)
#endif
#endif
  HRESULT WINAPI IRowsetWatchAll_Acknowledge_Proxy(IRowsetWatchAll *This);
  void __RPC_STUB IRowsetWatchAll_Acknowledge_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWatchAll_Start_Proxy(IRowsetWatchAll *This);
  void __RPC_STUB IRowsetWatchAll_Start_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWatchAll_StopWatching_Proxy(IRowsetWatchAll *This);
  void __RPC_STUB IRowsetWatchAll_StopWatching_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetWatchNotify_INTERFACE_DEFINED__
#define __IRowsetWatchNotify_INTERFACE_DEFINED__
  typedef DWORD DBWATCHNOTIFY;

  enum DBWATCHNOTIFYENUM {
    DBWATCHNOTIFY_ROWSCHANGED = 1,DBWATCHNOTIFY_QUERYDONE = 2,DBWATCHNOTIFY_QUERYREEXECUTED = 3
  };

  EXTERN_C const IID IID_IRowsetWatchNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetWatchNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI OnChange(IRowset *pRowset,DBWATCHNOTIFY eChangeReason) = 0;
  };
#else
  typedef struct IRowsetWatchNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetWatchNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetWatchNotify *This);
      ULONG (WINAPI *Release)(IRowsetWatchNotify *This);
      HRESULT (WINAPI *OnChange)(IRowsetWatchNotify *This,IRowset *pRowset,DBWATCHNOTIFY eChangeReason);
    END_INTERFACE
  } IRowsetWatchNotifyVtbl;
  struct IRowsetWatchNotify {
    CONST_VTBL struct IRowsetWatchNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetWatchNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetWatchNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetWatchNotify_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetWatchNotify_OnChange(This,pRowset,eChangeReason) (This)->lpVtbl->OnChange(This,pRowset,eChangeReason)
#endif
#endif
  HRESULT WINAPI IRowsetWatchNotify_OnChange_Proxy(IRowsetWatchNotify *This,IRowset *pRowset,DBWATCHNOTIFY eChangeReason);
  void __RPC_STUB IRowsetWatchNotify_OnChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetWatchRegion_INTERFACE_DEFINED__
#define __IRowsetWatchRegion_INTERFACE_DEFINED__
  typedef DWORD DBWATCHMODE;

  enum DBWATCHMODEENUM {
    DBWATCHMODE_ALL = 0x1,DBWATCHMODE_EXTEND = 0x2,DBWATCHMODE_MOVE = 0x4,DBWATCHMODE_COUNT = 0x8
  };
  typedef DWORD DBROWCHANGEKIND;

  enum DBROWCHANGEKINDENUM {
    DBROWCHANGEKIND_INSERT = 0,
    DBROWCHANGEKIND_DELETE,DBROWCHANGEKIND_UPDATE,DBROWCHANGEKIND_COUNT
  };

  typedef struct tagDBROWWATCHRANGE {
    HWATCHREGION hRegion;
    DBROWCHANGEKIND eChangeKind;
    HROW hRow;
    DBCOUNTITEM iRow;
  } DBROWWATCHCHANGE;

  EXTERN_C const IID IID_IRowsetWatchRegion;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetWatchRegion : public IRowsetWatchAll {
  public:
    virtual HRESULT WINAPI CreateWatchRegion(DBWATCHMODE dwWatchMode,HWATCHREGION *phRegion) = 0;
    virtual HRESULT WINAPI ChangeWatchMode(HWATCHREGION hRegion,DBWATCHMODE dwWatchMode) = 0;
    virtual HRESULT WINAPI DeleteWatchRegion(HWATCHREGION hRegion) = 0;
    virtual HRESULT WINAPI GetWatchRegionInfo(HWATCHREGION hRegion,DBWATCHMODE *pdwWatchMode,HCHAPTER *phChapter,DBBKMARK *pcbBookmark,BYTE **ppBookmark,DBROWCOUNT *pcRows) = 0;
    virtual HRESULT WINAPI Refresh(DBCOUNTITEM *pcChangesObtained,DBROWWATCHCHANGE **prgChanges) = 0;
    virtual HRESULT WINAPI ShrinkWatchRegion(HWATCHREGION hRegion,HCHAPTER hChapter,DBBKMARK cbBookmark,BYTE *pBookmark,DBROWCOUNT cRows) = 0;
  };
#else
  typedef struct IRowsetWatchRegionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetWatchRegion *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetWatchRegion *This);
      ULONG (WINAPI *Release)(IRowsetWatchRegion *This);
      HRESULT (WINAPI *Acknowledge)(IRowsetWatchRegion *This);
      HRESULT (WINAPI *Start)(IRowsetWatchRegion *This);
      HRESULT (WINAPI *StopWatching)(IRowsetWatchRegion *This);
      HRESULT (WINAPI *CreateWatchRegion)(IRowsetWatchRegion *This,DBWATCHMODE dwWatchMode,HWATCHREGION *phRegion);
      HRESULT (WINAPI *ChangeWatchMode)(IRowsetWatchRegion *This,HWATCHREGION hRegion,DBWATCHMODE dwWatchMode);
      HRESULT (WINAPI *DeleteWatchRegion)(IRowsetWatchRegion *This,HWATCHREGION hRegion);
      HRESULT (WINAPI *GetWatchRegionInfo)(IRowsetWatchRegion *This,HWATCHREGION hRegion,DBWATCHMODE *pdwWatchMode,HCHAPTER *phChapter,DBBKMARK *pcbBookmark,BYTE **ppBookmark,DBROWCOUNT *pcRows);
      HRESULT (WINAPI *Refresh)(IRowsetWatchRegion *This,DBCOUNTITEM *pcChangesObtained,DBROWWATCHCHANGE **prgChanges);
      HRESULT (WINAPI *ShrinkWatchRegion)(IRowsetWatchRegion *This,HWATCHREGION hRegion,HCHAPTER hChapter,DBBKMARK cbBookmark,BYTE *pBookmark,DBROWCOUNT cRows);
    END_INTERFACE
  } IRowsetWatchRegionVtbl;
  struct IRowsetWatchRegion {
    CONST_VTBL struct IRowsetWatchRegionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetWatchRegion_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetWatchRegion_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetWatchRegion_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetWatchRegion_Acknowledge(This) (This)->lpVtbl->Acknowledge(This)
#define IRowsetWatchRegion_Start(This) (This)->lpVtbl->Start(This)
#define IRowsetWatchRegion_StopWatching(This) (This)->lpVtbl->StopWatching(This)
#define IRowsetWatchRegion_CreateWatchRegion(This,dwWatchMode,phRegion) (This)->lpVtbl->CreateWatchRegion(This,dwWatchMode,phRegion)
#define IRowsetWatchRegion_ChangeWatchMode(This,hRegion,dwWatchMode) (This)->lpVtbl->ChangeWatchMode(This,hRegion,dwWatchMode)
#define IRowsetWatchRegion_DeleteWatchRegion(This,hRegion) (This)->lpVtbl->DeleteWatchRegion(This,hRegion)
#define IRowsetWatchRegion_GetWatchRegionInfo(This,hRegion,pdwWatchMode,phChapter,pcbBookmark,ppBookmark,pcRows) (This)->lpVtbl->GetWatchRegionInfo(This,hRegion,pdwWatchMode,phChapter,pcbBookmark,ppBookmark,pcRows)
#define IRowsetWatchRegion_Refresh(This,pcChangesObtained,prgChanges) (This)->lpVtbl->Refresh(This,pcChangesObtained,prgChanges)
#define IRowsetWatchRegion_ShrinkWatchRegion(This,hRegion,hChapter,cbBookmark,pBookmark,cRows) (This)->lpVtbl->ShrinkWatchRegion(This,hRegion,hChapter,cbBookmark,pBookmark,cRows)
#endif
#endif
  HRESULT WINAPI IRowsetWatchRegion_CreateWatchRegion_Proxy(IRowsetWatchRegion *This,DBWATCHMODE dwWatchMode,HWATCHREGION *phRegion);
  void __RPC_STUB IRowsetWatchRegion_CreateWatchRegion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWatchRegion_ChangeWatchMode_Proxy(IRowsetWatchRegion *This,HWATCHREGION hRegion,DBWATCHMODE dwWatchMode);
  void __RPC_STUB IRowsetWatchRegion_ChangeWatchMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWatchRegion_DeleteWatchRegion_Proxy(IRowsetWatchRegion *This,HWATCHREGION hRegion);
  void __RPC_STUB IRowsetWatchRegion_DeleteWatchRegion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWatchRegion_GetWatchRegionInfo_Proxy(IRowsetWatchRegion *This,HWATCHREGION hRegion,DBWATCHMODE *pdwWatchMode,HCHAPTER *phChapter,DBBKMARK *pcbBookmark,BYTE **ppBookmark,DBROWCOUNT *pcRows);
  void __RPC_STUB IRowsetWatchRegion_GetWatchRegionInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWatchRegion_Refresh_Proxy(IRowsetWatchRegion *This,DBCOUNTITEM *pcChangesObtained,DBROWWATCHCHANGE **prgChanges);
  void __RPC_STUB IRowsetWatchRegion_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetWatchRegion_ShrinkWatchRegion_Proxy(IRowsetWatchRegion *This,HWATCHREGION hRegion,HCHAPTER hChapter,DBBKMARK cbBookmark,BYTE *pBookmark,DBROWCOUNT cRows);
  void __RPC_STUB IRowsetWatchRegion_ShrinkWatchRegion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetCopyRows_INTERFACE_DEFINED__
#define __IRowsetCopyRows_INTERFACE_DEFINED__
  typedef WORD HSOURCE;

  EXTERN_C const IID IID_IRowsetCopyRows;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetCopyRows : public IUnknown {
  public:
    virtual HRESULT WINAPI CloseSource(HSOURCE hSourceID) = 0;
    virtual HRESULT WINAPI CopyByHROWS(HSOURCE hSourceID,HCHAPTER hReserved,DBROWCOUNT cRows,const HROW rghRows[],ULONG bFlags) = 0;
    virtual HRESULT WINAPI CopyRows(HSOURCE hSourceID,HCHAPTER hReserved,DBROWCOUNT cRows,ULONG bFlags,DBCOUNTITEM *pcRowsCopied) = 0;
    virtual HRESULT WINAPI DefineSource(const IRowset *pRowsetSource,const DBORDINAL cColIds,const DB_LORDINAL rgSourceColumns[],const DB_LORDINAL rgTargetColumns[],HSOURCE *phSourceID) = 0;
  };
#else
  typedef struct IRowsetCopyRowsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetCopyRows *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetCopyRows *This);
      ULONG (WINAPI *Release)(IRowsetCopyRows *This);
      HRESULT (WINAPI *CloseSource)(IRowsetCopyRows *This,HSOURCE hSourceID);
      HRESULT (WINAPI *CopyByHROWS)(IRowsetCopyRows *This,HSOURCE hSourceID,HCHAPTER hReserved,DBROWCOUNT cRows,const HROW rghRows[],ULONG bFlags);
      HRESULT (WINAPI *CopyRows)(IRowsetCopyRows *This,HSOURCE hSourceID,HCHAPTER hReserved,DBROWCOUNT cRows,ULONG bFlags,DBCOUNTITEM *pcRowsCopied);
      HRESULT (WINAPI *DefineSource)(IRowsetCopyRows *This,const IRowset *pRowsetSource,const DBORDINAL cColIds,const DB_LORDINAL rgSourceColumns[],const DB_LORDINAL rgTargetColumns[],HSOURCE *phSourceID);
    END_INTERFACE
  } IRowsetCopyRowsVtbl;
  struct IRowsetCopyRows {
    CONST_VTBL struct IRowsetCopyRowsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetCopyRows_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetCopyRows_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetCopyRows_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetCopyRows_CloseSource(This,hSourceID) (This)->lpVtbl->CloseSource(This,hSourceID)
#define IRowsetCopyRows_CopyByHROWS(This,hSourceID,hReserved,cRows,rghRows,bFlags) (This)->lpVtbl->CopyByHROWS(This,hSourceID,hReserved,cRows,rghRows,bFlags)
#define IRowsetCopyRows_CopyRows(This,hSourceID,hReserved,cRows,bFlags,pcRowsCopied) (This)->lpVtbl->CopyRows(This,hSourceID,hReserved,cRows,bFlags,pcRowsCopied)
#define IRowsetCopyRows_DefineSource(This,pRowsetSource,cColIds,rgSourceColumns,rgTargetColumns,phSourceID) (This)->lpVtbl->DefineSource(This,pRowsetSource,cColIds,rgSourceColumns,rgTargetColumns,phSourceID)
#endif
#endif
  HRESULT WINAPI IRowsetCopyRows_CloseSource_Proxy(IRowsetCopyRows *This,HSOURCE hSourceID);
  void __RPC_STUB IRowsetCopyRows_CloseSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetCopyRows_CopyByHROWS_Proxy(IRowsetCopyRows *This,HSOURCE hSourceID,HCHAPTER hReserved,DBROWCOUNT cRows,const HROW rghRows[],ULONG bFlags);
  void __RPC_STUB IRowsetCopyRows_CopyByHROWS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetCopyRows_CopyRows_Proxy(IRowsetCopyRows *This,HSOURCE hSourceID,HCHAPTER hReserved,DBROWCOUNT cRows,ULONG bFlags,DBCOUNTITEM *pcRowsCopied);
  void __RPC_STUB IRowsetCopyRows_CopyRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetCopyRows_DefineSource_Proxy(IRowsetCopyRows *This,const IRowset *pRowsetSource,const DBORDINAL cColIds,const DB_LORDINAL rgSourceColumns[],const DB_LORDINAL rgTargetColumns[],HSOURCE *phSourceID);
  void __RPC_STUB IRowsetCopyRows_DefineSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IReadData_INTERFACE_DEFINED__
#define __IReadData_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IReadData;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IReadData : public IUnknown {
  public:
    virtual HRESULT WINAPI ReadData(HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,HACCESSOR hAccessor,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,BYTE **ppFixedData,DBLENGTH *pcbVariableTotal,BYTE **ppVariableData) = 0;
    virtual HRESULT WINAPI ReleaseChapter(HCHAPTER hChapter) = 0;
  };
#else
  typedef struct IReadDataVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IReadData *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IReadData *This);
      ULONG (WINAPI *Release)(IReadData *This);
      HRESULT (WINAPI *ReadData)(IReadData *This,HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,HACCESSOR hAccessor,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,BYTE **ppFixedData,DBLENGTH *pcbVariableTotal,BYTE **ppVariableData);
      HRESULT (WINAPI *ReleaseChapter)(IReadData *This,HCHAPTER hChapter);
    END_INTERFACE
  } IReadDataVtbl;
  struct IReadData {
    CONST_VTBL struct IReadDataVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IReadData_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IReadData_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IReadData_Release(This) (This)->lpVtbl->Release(This)
#define IReadData_ReadData(This,hChapter,cbBookmark,pBookmark,lRowsOffset,hAccessor,cRows,pcRowsObtained,ppFixedData,pcbVariableTotal,ppVariableData) (This)->lpVtbl->ReadData(This,hChapter,cbBookmark,pBookmark,lRowsOffset,hAccessor,cRows,pcRowsObtained,ppFixedData,pcbVariableTotal,ppVariableData)
#define IReadData_ReleaseChapter(This,hChapter) (This)->lpVtbl->ReleaseChapter(This,hChapter)
#endif
#endif
  HRESULT WINAPI IReadData_ReadData_Proxy(IReadData *This,HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,HACCESSOR hAccessor,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,BYTE **ppFixedData,DBLENGTH *pcbVariableTotal,BYTE **ppVariableData);
  void __RPC_STUB IReadData_ReadData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IReadData_ReleaseChapter_Proxy(IReadData *This,HCHAPTER hChapter);
  void __RPC_STUB IReadData_ReleaseChapter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommandCost_INTERFACE_DEFINED__
#define __ICommandCost_INTERFACE_DEFINED__

  typedef DWORD DBRESOURCEKIND;

  enum DBRESOURCEKINDENUM {
    DBRESOURCE_INVALID = 0,DBRESOURCE_TOTAL = 1,DBRESOURCE_CPU = 2,DBRESOURCE_MEMORY = 3,DBRESOURCE_DISK = 4,DBRESOURCE_NETWORK = 5,
    DBRESOURCE_RESPONSE = 6,DBRESOURCE_ROWS = 7,DBRESOURCE_OTHER = 8
  };
  typedef DWORD DBCOSTUNIT;

  enum DBCOSTUNITENUM {
    DBUNIT_INVALID = 0,DBUNIT_WEIGHT = 0x1,DBUNIT_PERCENT = 0x2,DBUNIT_MAXIMUM = 0x4,DBUNIT_MINIMUM = 0x8,DBUNIT_MICRO_SECOND = 0x10,
    DBUNIT_MILLI_SECOND = 0x20,DBUNIT_SECOND = 0x40,DBUNIT_MINUTE = 0x80,DBUNIT_HOUR = 0x100,DBUNIT_BYTE = 0x200,DBUNIT_KILO_BYTE = 0x400,
    DBUNIT_MEGA_BYTE = 0x800,DBUNIT_GIGA_BYTE = 0x1000,DBUNIT_NUM_MSGS = 0x2000,DBUNIT_NUM_LOCKS = 0x4000,DBUNIT_NUM_ROWS = 0x8000,
    DBUNIT_OTHER = 0x10000
  };

  typedef struct tagDBCOST {
    DBRESOURCEKIND eKind;
    DBCOSTUNIT dwUnits;
    LONG lValue;
  } DBCOST;

  typedef DWORD DBEXECLIMITS;

  enum DBEXECLIMITSENUM {
    DBEXECLIMITS_ABORT = 1,DBEXECLIMITS_STOP = 2,DBEXECLIMITS_SUSPEND = 3
  };

  EXTERN_C const IID IID_ICommandCost;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandCost : public IUnknown {
  public:
    virtual HRESULT WINAPI GetAccumulatedCost(LPCOLESTR pwszRowsetName,ULONG *pcCostLimits,DBCOST **prgCostLimits) = 0;
    virtual HRESULT WINAPI GetCostEstimate(LPCOLESTR pwszRowsetName,ULONG *pcCostEstimates,DBCOST *prgCostEstimates) = 0;
    virtual HRESULT WINAPI GetCostGoals(LPCOLESTR pwszRowsetName,ULONG *pcCostGoals,DBCOST *prgCostGoals) = 0;
    virtual HRESULT WINAPI GetCostLimits(LPCOLESTR pwszRowsetName,ULONG *pcCostLimits,DBCOST *prgCostLimits) = 0;
    virtual HRESULT WINAPI SetCostGoals(LPCOLESTR pwszRowsetName,ULONG cCostGoals,const DBCOST rgCostGoals[]) = 0;
    virtual HRESULT WINAPI SetCostLimits(LPCOLESTR pwszRowsetName,ULONG cCostLimits,DBCOST *prgCostLimits,DBEXECLIMITS dwExecutionFlags) = 0;
  };
#else
  typedef struct ICommandCostVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandCost *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandCost *This);
      ULONG (WINAPI *Release)(ICommandCost *This);
      HRESULT (WINAPI *GetAccumulatedCost)(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostLimits,DBCOST **prgCostLimits);
      HRESULT (WINAPI *GetCostEstimate)(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostEstimates,DBCOST *prgCostEstimates);
      HRESULT (WINAPI *GetCostGoals)(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostGoals,DBCOST *prgCostGoals);
      HRESULT (WINAPI *GetCostLimits)(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostLimits,DBCOST *prgCostLimits);
      HRESULT (WINAPI *SetCostGoals)(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG cCostGoals,const DBCOST rgCostGoals[]);
      HRESULT (WINAPI *SetCostLimits)(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG cCostLimits,DBCOST *prgCostLimits,DBEXECLIMITS dwExecutionFlags);
    END_INTERFACE
  } ICommandCostVtbl;
  struct ICommandCost {
    CONST_VTBL struct ICommandCostVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandCost_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandCost_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandCost_Release(This) (This)->lpVtbl->Release(This)
#define ICommandCost_GetAccumulatedCost(This,pwszRowsetName,pcCostLimits,prgCostLimits) (This)->lpVtbl->GetAccumulatedCost(This,pwszRowsetName,pcCostLimits,prgCostLimits)
#define ICommandCost_GetCostEstimate(This,pwszRowsetName,pcCostEstimates,prgCostEstimates) (This)->lpVtbl->GetCostEstimate(This,pwszRowsetName,pcCostEstimates,prgCostEstimates)
#define ICommandCost_GetCostGoals(This,pwszRowsetName,pcCostGoals,prgCostGoals) (This)->lpVtbl->GetCostGoals(This,pwszRowsetName,pcCostGoals,prgCostGoals)
#define ICommandCost_GetCostLimits(This,pwszRowsetName,pcCostLimits,prgCostLimits) (This)->lpVtbl->GetCostLimits(This,pwszRowsetName,pcCostLimits,prgCostLimits)
#define ICommandCost_SetCostGoals(This,pwszRowsetName,cCostGoals,rgCostGoals) (This)->lpVtbl->SetCostGoals(This,pwszRowsetName,cCostGoals,rgCostGoals)
#define ICommandCost_SetCostLimits(This,pwszRowsetName,cCostLimits,prgCostLimits,dwExecutionFlags) (This)->lpVtbl->SetCostLimits(This,pwszRowsetName,cCostLimits,prgCostLimits,dwExecutionFlags)
#endif
#endif
  HRESULT WINAPI ICommandCost_GetAccumulatedCost_Proxy(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostLimits,DBCOST **prgCostLimits);
  void __RPC_STUB ICommandCost_GetAccumulatedCost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandCost_GetCostEstimate_Proxy(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostEstimates,DBCOST *prgCostEstimates);
  void __RPC_STUB ICommandCost_GetCostEstimate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandCost_GetCostGoals_Proxy(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostGoals,DBCOST *prgCostGoals);
  void __RPC_STUB ICommandCost_GetCostGoals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandCost_GetCostLimits_Proxy(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG *pcCostLimits,DBCOST *prgCostLimits);
  void __RPC_STUB ICommandCost_GetCostLimits_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandCost_SetCostGoals_Proxy(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG cCostGoals,const DBCOST rgCostGoals[]);
  void __RPC_STUB ICommandCost_SetCostGoals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandCost_SetCostLimits_Proxy(ICommandCost *This,LPCOLESTR pwszRowsetName,ULONG cCostLimits,DBCOST *prgCostLimits,DBEXECLIMITS dwExecutionFlags);
  void __RPC_STUB ICommandCost_SetCostLimits_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommandValidate_INTERFACE_DEFINED__
#define __ICommandValidate_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICommandValidate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandValidate : public IUnknown {
  public:
    virtual HRESULT WINAPI ValidateCompletely(void) = 0;
    virtual HRESULT WINAPI ValidateSyntax(void) = 0;
  };
#else
  typedef struct ICommandValidateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandValidate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandValidate *This);
      ULONG (WINAPI *Release)(ICommandValidate *This);
      HRESULT (WINAPI *ValidateCompletely)(ICommandValidate *This);
      HRESULT (WINAPI *ValidateSyntax)(ICommandValidate *This);
    END_INTERFACE
  } ICommandValidateVtbl;
  struct ICommandValidate {
    CONST_VTBL struct ICommandValidateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandValidate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandValidate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandValidate_Release(This) (This)->lpVtbl->Release(This)
#define ICommandValidate_ValidateCompletely(This) (This)->lpVtbl->ValidateCompletely(This)
#define ICommandValidate_ValidateSyntax(This) (This)->lpVtbl->ValidateSyntax(This)
#endif
#endif
  HRESULT WINAPI ICommandValidate_ValidateCompletely_Proxy(ICommandValidate *This);
  void __RPC_STUB ICommandValidate_ValidateCompletely_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandValidate_ValidateSyntax_Proxy(ICommandValidate *This);
  void __RPC_STUB ICommandValidate_ValidateSyntax_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITableRename_INTERFACE_DEFINED__
#define __ITableRename_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITableRename;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITableRename : public IUnknown {
  public:
    virtual HRESULT WINAPI RenameColumn(DBID *pTableId,DBID *pOldColumnId,DBID *pNewColumnId) = 0;
    virtual HRESULT WINAPI RenameTable(DBID *pOldTableId,DBID *pOldIndexId,DBID *pNewTableId,DBID *pNewIndexId) = 0;
  };
#else
  typedef struct ITableRenameVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITableRename *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITableRename *This);
      ULONG (WINAPI *Release)(ITableRename *This);
      HRESULT (WINAPI *RenameColumn)(ITableRename *This,DBID *pTableId,DBID *pOldColumnId,DBID *pNewColumnId);
      HRESULT (WINAPI *RenameTable)(ITableRename *This,DBID *pOldTableId,DBID *pOldIndexId,DBID *pNewTableId,DBID *pNewIndexId);
    END_INTERFACE
  } ITableRenameVtbl;
  struct ITableRename {
    CONST_VTBL struct ITableRenameVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITableRename_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITableRename_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITableRename_Release(This) (This)->lpVtbl->Release(This)
#define ITableRename_RenameColumn(This,pTableId,pOldColumnId,pNewColumnId) (This)->lpVtbl->RenameColumn(This,pTableId,pOldColumnId,pNewColumnId)
#define ITableRename_RenameTable(This,pOldTableId,pOldIndexId,pNewTableId,pNewIndexId) (This)->lpVtbl->RenameTable(This,pOldTableId,pOldIndexId,pNewTableId,pNewIndexId)
#endif
#endif
  HRESULT WINAPI ITableRename_RenameColumn_Proxy(ITableRename *This,DBID *pTableId,DBID *pOldColumnId,DBID *pNewColumnId);
  void __RPC_STUB ITableRename_RenameColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITableRename_RenameTable_Proxy(ITableRename *This,DBID *pOldTableId,DBID *pOldIndexId,DBID *pNewTableId,DBID *pNewIndexId);
  void __RPC_STUB ITableRename_RenameTable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBSchemaCommand_INTERFACE_DEFINED__
#define __IDBSchemaCommand_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBSchemaCommand;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBSchemaCommand : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCommand(IUnknown *pUnkOuter,REFGUID rguidSchema,ICommand **ppCommand) = 0;
    virtual HRESULT WINAPI GetSchemas(ULONG *pcSchemas,GUID **prgSchemas) = 0;
  };
#else
  typedef struct IDBSchemaCommandVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBSchemaCommand *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBSchemaCommand *This);
      ULONG (WINAPI *Release)(IDBSchemaCommand *This);
      HRESULT (WINAPI *GetCommand)(IDBSchemaCommand *This,IUnknown *pUnkOuter,REFGUID rguidSchema,ICommand **ppCommand);
      HRESULT (WINAPI *GetSchemas)(IDBSchemaCommand *This,ULONG *pcSchemas,GUID **prgSchemas);
    END_INTERFACE
  } IDBSchemaCommandVtbl;
  struct IDBSchemaCommand {
    CONST_VTBL struct IDBSchemaCommandVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBSchemaCommand_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBSchemaCommand_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBSchemaCommand_Release(This) (This)->lpVtbl->Release(This)
#define IDBSchemaCommand_GetCommand(This,pUnkOuter,rguidSchema,ppCommand) (This)->lpVtbl->GetCommand(This,pUnkOuter,rguidSchema,ppCommand)
#define IDBSchemaCommand_GetSchemas(This,pcSchemas,prgSchemas) (This)->lpVtbl->GetSchemas(This,pcSchemas,prgSchemas)
#endif
#endif
  HRESULT WINAPI IDBSchemaCommand_GetCommand_Proxy(IDBSchemaCommand *This,IUnknown *pUnkOuter,REFGUID rguidSchema,ICommand **ppCommand);
  void __RPC_STUB IDBSchemaCommand_GetCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBSchemaCommand_GetSchemas_Proxy(IDBSchemaCommand *This,ULONG *pcSchemas,GUID **prgSchemas);
  void __RPC_STUB IDBSchemaCommand_GetSchemas_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IProvideMoniker_INTERFACE_DEFINED__
#define __IProvideMoniker_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IProvideMoniker;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProvideMoniker : public IUnknown {
  public:
    virtual HRESULT WINAPI GetMoniker(IMoniker **ppIMoniker) = 0;
  };
#else
  typedef struct IProvideMonikerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IProvideMoniker *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IProvideMoniker *This);
      ULONG (WINAPI *Release)(IProvideMoniker *This);
      HRESULT (WINAPI *GetMoniker)(IProvideMoniker *This,IMoniker **ppIMoniker);
    END_INTERFACE
  } IProvideMonikerVtbl;
  struct IProvideMoniker {
    CONST_VTBL struct IProvideMonikerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProvideMoniker_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProvideMoniker_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProvideMoniker_Release(This) (This)->lpVtbl->Release(This)
#define IProvideMoniker_GetMoniker(This,ppIMoniker) (This)->lpVtbl->GetMoniker(This,ppIMoniker)
#endif
#endif
  HRESULT WINAPI IProvideMoniker_GetMoniker_Proxy(IProvideMoniker *This,IMoniker **ppIMoniker);
  void __RPC_STUB IProvideMoniker_GetMoniker_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#include <poppack.h>
  extern RPC_IF_HANDLE __MIDL_itf_oledbdep_0372_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledbdep_0372_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
