/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 500
#endif

#ifndef __REQUIRED_RPCSAL_H_VERSION__
#define __REQUIRED_RPCSAL_H_VERSION__ 100
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of rpcndr.h header
#endif

#ifndef __adojet_h__
#define __adojet_h__

#ifndef __IReplica_FWD_DEFINED__
#define __IReplica_FWD_DEFINED__
typedef interface IReplica IReplica;
#endif

#ifndef __Filter_FWD_DEFINED__
#define __Filter_FWD_DEFINED__
typedef interface Filter Filter;
#endif

#ifndef __Filters_FWD_DEFINED__
#define __Filters_FWD_DEFINED__
typedef interface Filters Filters;
#endif

#ifndef __IJetEngine_FWD_DEFINED__
#define __IJetEngine_FWD_DEFINED__
typedef interface IJetEngine IJetEngine;
#endif

#ifndef __Replica_FWD_DEFINED__
#define __Replica_FWD_DEFINED__

#ifdef __cplusplus
typedef class Replica Replica;
#else
typedef struct Replica Replica;
#endif
#endif

#ifndef __JetEngine_FWD_DEFINED__
#define __JetEngine_FWD_DEFINED__

#ifdef __cplusplus
typedef class JetEngine JetEngine;
#else
typedef struct JetEngine JetEngine;
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

  extern RPC_IF_HANDLE __MIDL_itf_adojet_0000_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_adojet_0000_0000_v0_0_s_ifspec;

#ifndef __JRO_LIBRARY_DEFINED__
#define __JRO_LIBRARY_DEFINED__

  typedef DECLSPEC_UUID ("D2D139DF-B6CA-11d1-9F31-00C04FC29D52")
  enum ReplicaTypeEnum {
    jrRepTypeNotReplicable = 0,
    jrRepTypeDesignMaster = 0x1,
    jrRepTypeFull = 0x2,
    jrRepTypePartial = 0x3
  } ReplicaTypeEnum;

  typedef DECLSPEC_UUID ("6877D21A-B6CE-11d1-9F31-00C04FC29D52")
  enum VisibilityEnum {
    jrRepVisibilityGlobal = 0x1,
    jrRepVisibilityLocal = 0x2,
    jrRepVisibilityAnon = 0x4
  } VisibilityEnum;

  typedef DECLSPEC_UUID ("B42FBFF6-B6CF-11d1-9F31-00C04FC29D52")
  enum UpdatabilityEnum {
    jrRepUpdFull = 0,
    jrRepUpdReadOnly = 0x2
  } UpdatabilityEnum;

  typedef DECLSPEC_UUID ("60C05416-B6D0-11d1-9F31-00C04FC29D52")
  enum SyncTypeEnum {
    jrSyncTypeExport = 0x1,
    jrSyncTypeImport = 0x2,
    jrSyncTypeImpExp = 0x3
  } SyncTypeEnum;

  typedef DECLSPEC_UUID ("5EBA3970-061E-11d2-BB77-00C04FAE22DA")
  enum SyncModeEnum {
    jrSyncModeIndirect = 0x1,
    jrSyncModeDirect = 0x2,
    jrSyncModeInternet = 0x3
  } SyncModeEnum;

  typedef DECLSPEC_UUID ("72769F94-BF78-11d1-AC4D-00C04FC29F8F")
  enum FilterTypeEnum {
    jrFilterTypeTable = 0x1,
    jrFilterTypeRelationship = 0x2
  } FilterTypeEnum;

  EXTERN_C const IID LIBID_JRO;

#ifndef __IReplica_INTERFACE_DEFINED__
#define __IReplica_INTERFACE_DEFINED__

  EXTERN_C const IID IID_IReplica;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("D2D139E0-B6CA-11d1-9F31-00C04FC29D52")
  IReplica : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE putref_ActiveConnection (IDispatch *pconn) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ActiveConnection (VARIANT vConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ActiveConnection (IDispatch **ppconn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ConflictFunction (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ConflictFunction (BSTR bstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ConflictTables (_Recordset **pprset) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DesignMasterId (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_DesignMasterId (VARIANT var) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Priority (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ReplicaId (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ReplicaType (ReplicaTypeEnum *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_RetentionPeriod (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_RetentionPeriod (long l) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Visibility (VisibilityEnum *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE CreateReplica (BSTR replicaName, BSTR description, ReplicaTypeEnum replicaType = jrRepTypeFull, VisibilityEnum visibility = jrRepVisibilityGlobal, long priority = -1, UpdatabilityEnum updatability = jrRepUpdFull) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetObjectReplicability (BSTR objectName, BSTR objectType, VARIANT_BOOL *replicability) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetObjectReplicability (BSTR objectName, BSTR objectType, VARIANT_BOOL replicability) = 0;
    virtual HRESULT STDMETHODCALLTYPE MakeReplicable (BSTR connectionString = L"", VARIANT_BOOL columnTracking = -1) = 0;
    virtual HRESULT STDMETHODCALLTYPE PopulatePartial (BSTR FullReplica) = 0;
    virtual HRESULT STDMETHODCALLTYPE Synchronize (BSTR target, SyncTypeEnum syncType = jrSyncTypeImpExp, SyncModeEnum syncMode = jrSyncModeIndirect) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Filters (Filters **ppFilters) = 0;
  };
#else
  typedef struct IReplicaVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (IReplica *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (IReplica *This);
    ULONG (STDMETHODCALLTYPE *Release) (IReplica *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (IReplica *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (IReplica *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (IReplica *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (IReplica *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveConnection) (IReplica *This, IDispatch *pconn);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (IReplica *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (IReplica *This, IDispatch **ppconn);
    HRESULT (STDMETHODCALLTYPE *get_ConflictFunction) (IReplica *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_ConflictFunction) (IReplica *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_ConflictTables) (IReplica *This, _Recordset **pprset);
    HRESULT (STDMETHODCALLTYPE *get_DesignMasterId) (IReplica *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_DesignMasterId) (IReplica *This, VARIANT var);
    HRESULT (STDMETHODCALLTYPE *get_Priority) (IReplica *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_ReplicaId) (IReplica *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_ReplicaType) (IReplica *This, ReplicaTypeEnum *pl);
    HRESULT (STDMETHODCALLTYPE *get_RetentionPeriod) (IReplica *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_RetentionPeriod) (IReplica *This, long l);
    HRESULT (STDMETHODCALLTYPE *get_Visibility) (IReplica *This, VisibilityEnum *pl);
    HRESULT (STDMETHODCALLTYPE *CreateReplica) (IReplica *This, BSTR replicaName, BSTR description, ReplicaTypeEnum replicaType, VisibilityEnum visibility, long priority, UpdatabilityEnum updatability);
    HRESULT (STDMETHODCALLTYPE *GetObjectReplicability) (IReplica *This, BSTR objectName, BSTR objectType, VARIANT_BOOL *replicability);
    HRESULT (STDMETHODCALLTYPE *SetObjectReplicability) (IReplica *This, BSTR objectName, BSTR objectType, VARIANT_BOOL replicability);
    HRESULT (STDMETHODCALLTYPE *MakeReplicable) (IReplica *This, BSTR connectionString, VARIANT_BOOL columnTracking);
    HRESULT (STDMETHODCALLTYPE *PopulatePartial) (IReplica *This, BSTR FullReplica);
    HRESULT (STDMETHODCALLTYPE *Synchronize) (IReplica *This, BSTR target, SyncTypeEnum syncType, SyncModeEnum syncMode);
    HRESULT (STDMETHODCALLTYPE *get_Filters) (IReplica *This, Filters **ppFilters);
    END_INTERFACE
  } IReplicaVtbl;

  interface IReplica {
    CONST_VTBL struct IReplicaVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define IReplica_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define IReplica_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define IReplica_Release(This) ((This)->lpVtbl ->Release (This))
#define IReplica_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define IReplica_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define IReplica_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define IReplica_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define IReplica_putref_ActiveConnection(This, pconn) ((This)->lpVtbl ->putref_ActiveConnection (This, pconn))
#define IReplica_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define IReplica_get_ActiveConnection(This, ppconn) ((This)->lpVtbl ->get_ActiveConnection (This, ppconn))
#define IReplica_get_ConflictFunction(This, pbstr) ((This)->lpVtbl ->get_ConflictFunction (This, pbstr))
#define IReplica_put_ConflictFunction(This, bstr) ((This)->lpVtbl ->put_ConflictFunction (This, bstr))
#define IReplica_get_ConflictTables(This, pprset) ((This)->lpVtbl ->get_ConflictTables (This, pprset))
#define IReplica_get_DesignMasterId(This, pvar) ((This)->lpVtbl ->get_DesignMasterId (This, pvar))
#define IReplica_put_DesignMasterId(This, var) ((This)->lpVtbl ->put_DesignMasterId (This, var))
#define IReplica_get_Priority(This, pl) ((This)->lpVtbl ->get_Priority (This, pl))
#define IReplica_get_ReplicaId(This, pvar) ((This)->lpVtbl ->get_ReplicaId (This, pvar))
#define IReplica_get_ReplicaType(This, pl) ((This)->lpVtbl ->get_ReplicaType (This, pl))
#define IReplica_get_RetentionPeriod(This, pl) ((This)->lpVtbl ->get_RetentionPeriod (This, pl))
#define IReplica_put_RetentionPeriod(This, l) ((This)->lpVtbl ->put_RetentionPeriod (This, l))
#define IReplica_get_Visibility(This, pl) ((This)->lpVtbl ->get_Visibility (This, pl))
#define IReplica_CreateReplica(This, replicaName, description, replicaType, visibility, priority, updatability) ((This)->lpVtbl ->CreateReplica (This, replicaName, description, replicaType, visibility, priority, updatability))
#define IReplica_GetObjectReplicability(This, objectName, objectType, replicability) ((This)->lpVtbl ->GetObjectReplicability (This, objectName, objectType, replicability))
#define IReplica_SetObjectReplicability(This, objectName, objectType, replicability) ((This)->lpVtbl ->SetObjectReplicability (This, objectName, objectType, replicability))
#define IReplica_MakeReplicable(This, connectionString, columnTracking) ((This)->lpVtbl ->MakeReplicable (This, connectionString, columnTracking))
#define IReplica_PopulatePartial(This, FullReplica) ((This)->lpVtbl ->PopulatePartial (This, FullReplica))
#define IReplica_Synchronize(This, target, syncType, syncMode) ((This)->lpVtbl ->Synchronize (This, target, syncType, syncMode))
#define IReplica_get_Filters(This, ppFilters) ((This)->lpVtbl ->get_Filters (This, ppFilters))
#endif
#endif
#endif

#ifndef __Filter_INTERFACE_DEFINED__
#define __Filter_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Filter;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("D2D139E1-B6CA-11d1-9F31-00C04FC29D52")
  Filter : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_TableName (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_FilterType (FilterTypeEnum *ptype) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_FilterCriteria (BSTR *pbstr) = 0;
  };
#else
  typedef struct FilterVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Filter *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Filter *This);
    ULONG (STDMETHODCALLTYPE *Release) (Filter *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Filter *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Filter *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Filter *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Filter *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_TableName) (Filter *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_FilterType) (Filter *This, FilterTypeEnum *ptype);
    HRESULT (STDMETHODCALLTYPE *get_FilterCriteria) (Filter *This, BSTR *pbstr);
    END_INTERFACE
  } FilterVtbl;

  interface Filter {
    CONST_VTBL struct FilterVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Filter_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Filter_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Filter_Release(This) ((This)->lpVtbl ->Release (This))
#define Filter_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Filter_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Filter_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Filter_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Filter_get_TableName(This, pbstr) ((This)->lpVtbl ->get_TableName (This, pbstr))
#define Filter_get_FilterType(This, ptype) ((This)->lpVtbl ->get_FilterType (This, ptype))
#define Filter_get_FilterCriteria(This, pbstr) ((This)->lpVtbl ->get_FilterCriteria (This, pbstr))
#endif
#endif
#endif

#ifndef __Filters_INTERFACE_DEFINED__
#define __Filters_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Filters;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("D2D139E2-B6CA-11d1-9F31-00C04FC29D52")
  Filters : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE Refresh (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE _NewEnum (IUnknown **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Count (long *c) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, Filter **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (BSTR tableName, FilterTypeEnum filterType, BSTR filterCriteria) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Index) = 0;
  };
#else
  typedef struct FiltersVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Filters *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Filters *This);
    ULONG (STDMETHODCALLTYPE *Release) (Filters *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Filters *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Filters *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Filters *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Filters *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Filters *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Filters *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Filters *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Filters *This, VARIANT Index, Filter **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (Filters *This, BSTR tableName, FilterTypeEnum filterType, BSTR filterCriteria);
    HRESULT (STDMETHODCALLTYPE *Delete) (Filters *This, VARIANT Index);
    END_INTERFACE
  } FiltersVtbl;

  interface Filters {
    CONST_VTBL struct FiltersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Filters_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Filters_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Filters_Release(This) ((This)->lpVtbl ->Release (This))
#define Filters_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Filters_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Filters_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Filters_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Filters_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Filters__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Filters_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Filters_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#define Filters_Append(This, tableName, filterType, filterCriteria) ((This)->lpVtbl ->Append (This, tableName, filterType, filterCriteria))
#define Filters_Delete(This, Index) ((This)->lpVtbl ->Delete (This, Index))
#endif

#endif
#endif

#ifndef __IJetEngine_INTERFACE_DEFINED__
#define __IJetEngine_INTERFACE_DEFINED__

  EXTERN_C const IID IID_IJetEngine;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("9F63D980-FF25-11D1-BB6F-00C04FAE22DA")
  IJetEngine : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE CompactDatabase (BSTR SourceConnection, BSTR Destconnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE RefreshCache (_Connection *Connection) = 0;
  };
#else
  typedef struct IJetEngineVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (IJetEngine *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (IJetEngine *This);
    ULONG (STDMETHODCALLTYPE *Release) (IJetEngine *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (IJetEngine *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (IJetEngine *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (IJetEngine *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (IJetEngine *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *CompactDatabase) (IJetEngine *This, BSTR SourceConnection, BSTR Destconnection);
    HRESULT (STDMETHODCALLTYPE *RefreshCache) (IJetEngine *This, _Connection *Connection);
    END_INTERFACE
  } IJetEngineVtbl;

  interface IJetEngine {
    CONST_VTBL struct IJetEngineVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define IJetEngine_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define IJetEngine_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define IJetEngine_Release(This) ((This)->lpVtbl ->Release (This))
#define IJetEngine_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define IJetEngine_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define IJetEngine_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define IJetEngine_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define IJetEngine_CompactDatabase(This, SourceConnection, Destconnection) ((This)->lpVtbl ->CompactDatabase (This, SourceConnection, Destconnection))
#define IJetEngine_RefreshCache(This, Connection) ((This)->lpVtbl ->RefreshCache (This, Connection))
#endif

#endif
#endif

  EXTERN_C const CLSID CLSID_Replica;
#ifdef __cplusplus

  class DECLSPEC_UUID ("D2D139E3-B6CA-11d1-9F31-00C04FC29D52")
  Replica;

#endif

  EXTERN_C const CLSID CLSID_JetEngine;

#ifdef __cplusplus
  class DECLSPEC_UUID ("DE88C160-FF2C-11D1-BB6F-00C04FAE22DA")
  JetEngine;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
