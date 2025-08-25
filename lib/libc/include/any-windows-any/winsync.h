/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __WINSYNC_H__
#define __WINSYNC_H__
#include <objbase.h>

#if (_WIN32_WINNT >= 0x0601)

typedef enum _CONFLICT_RESOLUTION_POLICY {
  CRP_NONE = 0,
  CRP_DESTINATION_PROVIDER_WINS,
  CRP_SOURCE_PROVIDER_WINS,
  CRP_LAST 
} CONFLICT_RESOLUTION_POLICY;

typedef enum _FILTERING_TYPE {
  FT_CURRENT_ITEMS_ONLY = 0
} FILTERING_TYPE;

typedef enum _KNOWLEDGE_COOKIE_COMPARISON_RESULT {
  KCCR_COOKIE_KNOWLEDGE_EQUAL = 0,
  KCCR_COOKIE_KNOWLEDGE_CONTAINED,
  KCCR_COOKIE_KNOWLEDGE_CONTAINS,
  KCCR_COOKIE_KNOWLEDGE_NOT_COMPARABLE 
} KNOWLEDGE_COOKIE_COMPARISON_RESULT;

typedef enum _SYNC_FULL_ENUMERATION_ACTION {
  SFEA_FULL_ENUMERATION = 0,
  SFEA_PARTIAL_SYNC,
  SFEA_ABORT 
} SYNC_FULL_ENUMERATION_ACTION;

typedef enum _SYNC_PROGRESS_STAGE {
  SPS_CHANGE_DETECTION = 0,
  SPS_CHANGE_ENUMERATION,
  SPS_CHANGE_APPLICATION 
} SYNC_PROGRESS_STAGE;

typedef enum _SYNC_PROVIDER_ROLE {
  SPR_SOURCE = 0,
  SPR_DESTINATION 
} SYNC_PROVIDER_ROLE;

typedef enum _SYNC_RESOLVE_ACTION {
  SRA_DEFER = 0,
  SRA_ACCEPT_DESTINATION_PROVIDER,
  SRA_ACCEPT_SOURCE_PROVIDER,
  SRA_MERGE,
  SRA_TRANSFER_AND_DEFER,
  SRA_LAST 
} SYNC_RESOLVE_ACTION;

typedef enum _SYNC_SERIALIZATION_VERSION {
  SYNC_SERIALIZATION_VERSION_V1 = 0,
  SYNC_SERIALIZATION_VERSION_V2 
} SYNC_SERIALIZATION_VERSION;

typedef enum _SYNC_STATISTICS {
  SYNC_STATISTICS_RANGE_COUNT = 0 
} SYNC_STATISTICS;

typedef struct _ID_PARAMETER_PAIR {
  WINBOOL fIsVariable;
  USHORT  cbIdSize;
} ID_PARAMETER_PAIR;

typedef struct _ID_PARAMETERS {
  DWORD             dwSize;
  ID_PARAMETER_PAIR replicaId;
  ID_PARAMETER_PAIR itemId;
  ID_PARAMETER_PAIR changeUnitId;
} ID_PARAMETERS;

typedef struct _SYNC_RANGE {
  BYTE * pbClosedLowerBound;
  BYTE * pbClosedUpperBound;
} SYNC_RANGE;

typedef struct _SYNC_SESSION_STATISTICS {
  DWORD dwChangesApplied;
  DWORD dwChangesFailed;
} SYNC_SESSION_STATISTICS;

typedef struct _SYNC_TIME {
  DWORD dwDate;
  DWORD dwTime;
} SYNC_TIME;

typedef struct _SYNC_VERSION {
  DWORD     dwLastUpdatingReplicaKey;
  ULONGLONG ullTickCount;
} SYNC_VERSION;

#ifndef __IAsynchronousDataRetriever_FWD_DEFINED__
#define __IAsynchronousDataRetriever_FWD_DEFINED__
typedef struct IAssociatedIdentityProvider IAssociatedIdentityProvider;
#endif

#ifndef __IDataRetrieverCallback_FWD_DEFINED__
#define __IDataRetrieverCallback_FWD_DEFINED__
typedef struct IDataRetrieverCallback IDataRetrieverCallback;
#endif

#ifndef __IChangeConflict_FWD_DEFINED__
#define __IChangeConflict_FWD_DEFINED__
typedef struct IChangeConflict IChangeConflict;
#endif

#ifndef __IChangeUnitException_FWD_DEFINED__
#define __IChangeUnitException_FWD_DEFINED__
typedef struct IChangeUnitException IChangeUnitException;
#endif

#ifndef __IChangeUnitListFilterInfo_FWD_DEFINED__
#define __IChangeUnitListFilterInfo_FWD_DEFINED__
typedef struct IChangeUnitListFilterInfo IChangeUnitListFilterInfo;
#endif

#ifndef __ISyncFilterInfo_FWD_DEFINED__
#define __ISyncFilterInfo_FWD_DEFINED__
typedef struct ISyncFilterInfo ISyncFilterInfo;
#endif

#ifndef __IClockVector_FWD_DEFINED__
#define __IClockVector_FWD_DEFINED__
typedef struct IClockVector IClockVector;
#endif

#ifndef __IClockVectorElement_FWD_DEFINED__
#define __IClockVectorElement_FWD_DEFINED__
typedef struct IClockVectorElement IClockVectorElement;
#endif

#ifndef __IConstructReplicaKeyMap_FWD_DEFINED__
#define __IConstructReplicaKeyMap_FWD_DEFINED__
typedef struct IConstructReplicaKeyMap IConstructReplicaKeyMap;
#endif

#ifndef __ICoreFragment_FWD_DEFINED__
#define __ICoreFragment_FWD_DEFINED__
typedef struct ICoreFragment ICoreFragment;
#endif

#ifndef __ILoadChangeContext_FWD_DEFINED__
#define __ILoadChangeContext_FWD_DEFINED__
typedef struct ILoadChangeContext ILoadChangeContext;
#endif

#ifndef __ISyncChange_FWD_DEFINED__
#define __ISyncChange_FWD_DEFINED__
typedef struct ISyncChange ISyncChange;
#endif

#ifndef __ISyncChangeUnit_FWD_DEFINED__
#define __ISyncChangeUnit_FWD_DEFINED__
typedef struct ISyncChangeUnit ISyncChangeUnit;
#endif

#ifndef __IRecoverableErrorData_FWD_DEFINED__
#define __IRecoverableErrorData_FWD_DEFINED__
typedef struct IRecoverableErrorData IRecoverableErrorData;
#endif

#ifndef __IEnumSyncChangeUnits_FWD_DEFINED__
#define __IEnumSyncChangeUnits_FWD_DEFINED__
typedef struct IEnumSyncChangeUnits IEnumSyncChangeUnits;
#endif

/* Fixme: ISyncKnowledge method list is missing from MSDN */
#ifndef __ISyncKnowledge_FWD_DEFINED__
#define __ISyncKnowledge_FWD_DEFINED__
typedef struct ISyncKnowledge ISyncKnowledge;
#endif

#undef  INTERFACE
#define INTERFACE IAsynchronousDataRetriever
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAsynchronousDataRetriever,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAsynchronousDataRetriever methods */
    STDMETHOD_(HRESULT,GetIdParameters)(THIS_ ID_PARAMETERS *pIdParameters) PURE;
    STDMETHOD_(HRESULT,LoadChangeData)(THIS_ ILoadChangeContext *pLoadChangeContext) PURE;
    STDMETHOD_(HRESULT,RegisterCallback)(THIS_ IDataRetrieverCallback *pDataRetrieverCallback) PURE;
    STDMETHOD_(HRESULT,RevokeCallback)(THIS_ IDataRetrieverCallback *pDataRetrieverCallback) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAsynchronousDataRetriever_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAsynchronousDataRetriever_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAsynchronousDataRetriever_Release(This) (This)->lpVtbl->Release(This)
#define IAsynchronousDataRetriever_GetIdParameters(This,pIdParameters) (This)->lpVtbl->GetIdParameters(This,pIdParameters)
#define IAsynchronousDataRetriever_LoadChangeData(This,pLoadChangeContext) (This)->lpVtbl->LoadChangeData(This,pLoadChangeContext)
#define IAsynchronousDataRetriever_RegisterCallback(This,pDataRetrieverCallback) (This)->lpVtbl->RegisterCallback(This,pDataRetrieverCallback)
#define IAsynchronousDataRetriever_RevokeCallback(This,pDataRetrieverCallback) (This)->lpVtbl->RevokeCallback(This,pDataRetrieverCallback)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDataRetrieverCallback
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDataRetrieverCallback,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDataRetrieverCallback methods */
    STDMETHOD_(HRESULT,LoadChangeDataComplete)(THIS_ IUnknown *pUnkData) PURE;
    STDMETHOD_(HRESULT,LoadChangeDataError)(THIS_ HRESULT hrError) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDataRetrieverCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDataRetrieverCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDataRetrieverCallback_Release(This) (This)->lpVtbl->Release(This)
#define IDataRetrieverCallback_LoadChangeDataComplete(This,pUnkData) (This)->lpVtbl->LoadChangeDataComplete(This,pUnkData)
#define IDataRetrieverCallback_LoadChangeDataError(This,hrError) (This)->lpVtbl->LoadChangeDataError(This,hrError)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IChangeConflict
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IChangeConflict,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IChangeConflict methods */
    STDMETHOD_(HRESULT,GetDestinationProviderConflictingChange)(THIS_ ISyncChange **ppConflictingChange) PURE;
    STDMETHOD_(HRESULT,GetDestinationProviderConflictingData)(THIS_ IUnknown **ppConflictingData) PURE;
    STDMETHOD_(HRESULT,GetResolveActionForChange)(THIS_ SYNC_RESOLVE_ACTION *pResolveAction) PURE;
    STDMETHOD_(HRESULT,GetResolveActionForChangeUnit)(THIS_ ISyncChangeUnit *pChangeUnit,SYNC_RESOLVE_ACTION *pResolveAction) PURE;
    STDMETHOD_(HRESULT,GetSourceProviderConflictingChange)(THIS_ ISyncChange **ppSyncChange) PURE;
    STDMETHOD_(HRESULT,GetSourceProviderConflictingData)(THIS_ IUnknown **ppConflictingData) PURE;
    STDMETHOD_(HRESULT,SetResolveActionForChange)(THIS_ SYNC_RESOLVE_ACTION resolveAction) PURE;
    STDMETHOD_(HRESULT,SetResolveActionForChangeUnit)(THIS_ ISyncChangeUnit *pChangeUnit,SYNC_RESOLVE_ACTION resolveAction) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IChangeConflict_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IChangeConflict_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IChangeConflict_Release(This) (This)->lpVtbl->Release(This)
#define IChangeConflict_GetDestinationProviderConflictingChange(This,ppConflictingChange) (This)->lpVtbl->GetDestinationProviderConflictingChange(This,ppConflictingChange)
#define IChangeConflict_GetDestinationProviderConflictingData(This,ppConflictingData) (This)->lpVtbl->GetDestinationProviderConflictingData(This,ppConflictingData)
#define IChangeConflict_GetResolveActionForChange(This,pResolveAction) (This)->lpVtbl->GetResolveActionForChange(This,pResolveAction)
#define IChangeConflict_GetResolveActionForChangeUnit(This,pChangeUnit,pResolveAction) (This)->lpVtbl->GetResolveActionForChangeUnit(This,pChangeUnit,pResolveAction)
#define IChangeConflict_GetSourceProviderConflictingChange(This,ppSyncChange) (This)->lpVtbl->GetSourceProviderConflictingChange(This,ppSyncChange)
#define IChangeConflict_GetSourceProviderConflictingData(This,ppConflictingData) (This)->lpVtbl->GetSourceProviderConflictingData(This,ppConflictingData)
#define IChangeConflict_SetResolveActionForChange(This,resolveAction) (This)->lpVtbl->SetResolveActionForChange(This,resolveAction)
#define IChangeConflict_SetResolveActionForChangeUnit(This,pChangeUnit,resolveAction) (This)->lpVtbl->SetResolveActionForChangeUnit(This,pChangeUnit,resolveAction)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IChangeUnitException
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IChangeUnitException,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IChangeUnitException methods */
    STDMETHOD_(HRESULT,GetChangeUnitId)(THIS_ DWORD *pcbIdSize) PURE;
    STDMETHOD_(HRESULT,GetClockVector)(THIS_ REFIID riid,void **ppUnk) PURE;
    STDMETHOD_(HRESULT,GetItemId)(THIS_ DWORD *pcbIdSize) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IChangeUnitException_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IChangeUnitException_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IChangeUnitException_Release(This) (This)->lpVtbl->Release(This)
#define IChangeUnitException_GetChangeUnitId(This,pcbIdSize) (This)->lpVtbl->GetChangeUnitId(This,pcbIdSize)
#define IChangeUnitException_GetClockVector(This,riid,ppUnk) (This)->lpVtbl->GetClockVector(This,riid,ppUnk)
#define IChangeUnitException_GetItemId(This,pcbIdSize) (This)->lpVtbl->GetItemId(This,pcbIdSize)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISyncFilterInfo
DECLARE_INTERFACE_(ISyncFilterInfo,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISyncFilterInfo methods */
    STDMETHOD_(HRESULT,Serialize)(THIS_ DWORD *pcbBuffer) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISyncFilterInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncFilterInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncFilterInfo_Release(This) (This)->lpVtbl->Release(This)
#define ISyncFilterInfo_Serialize(This,pcbBuffer) (This)->lpVtbl->Serialize(This,pcbBuffer)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IChangeUnitListFilterInfo
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IChangeUnitListFilterInfo,ISyncFilterInfo)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISyncFilterInfo methods */
    STDMETHOD_(HRESULT,Serialize)(THIS_ DWORD *pcbBuffer) PURE;

    /* IChangeUnitListFilterInfo methods */
    STDMETHOD_(HRESULT,GetChangeUnitId)(THIS_ DWORD dwChangeUnitIdIndex,DWORD *pcbIdSize) PURE;
    STDMETHOD_(HRESULT,GetChangeUnitIdCount)(THIS_ DWORD *pdwChangeUnitIdCount) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ const BYTE * const *ppbChangeUnitIds,DWORD dwChangeUnitCount) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IChangeUnitListFilterInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IChangeUnitListFilterInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IChangeUnitListFilterInfo_Release(This) (This)->lpVtbl->Release(This)
#define IChangeUnitListFilterInfo_Serialize(This,pcbBuffer) (This)->lpVtbl->Serialize(This,pcbBuffer)
#define IChangeUnitListFilterInfo_GetChangeUnitId(This,dwChangeUnitIdIndex,pcbIdSize) (This)->lpVtbl->GetChangeUnitId(This,dwChangeUnitIdIndex,pcbIdSize)
#define IChangeUnitListFilterInfo_GetChangeUnitIdCount(This,pdwChangeUnitIdCount) (This)->lpVtbl->GetChangeUnitIdCount(This,pdwChangeUnitIdCount)
#define IChangeUnitListFilterInfo_Initialize(This,ppbChangeUnitIds,dwChangeUnitCount) (This)->lpVtbl->Initialize(This,ppbChangeUnitIds,dwChangeUnitCount)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IClockVector
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IClockVector,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IClockVector methods */
    STDMETHOD_(HRESULT,GetClockVectorElementCount)(THIS_ DWORD *pdwCount) PURE;
    STDMETHOD_(HRESULT,GetClockVectorElements)(THIS_ REFIID riid,void **ppiEnumClockVector) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IClockVector_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClockVector_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClockVector_Release(This) (This)->lpVtbl->Release(This)
#define IClockVector_GetClockVectorElementCount(This,pdwCount) (This)->lpVtbl->GetClockVectorElementCount(This,pdwCount)
#define IClockVector_GetClockVectorElements(This,riid,ppiEnumClockVector) (This)->lpVtbl->GetClockVectorElements(This,riid,ppiEnumClockVector)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IClockVectorElement
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IClockVectorElement,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IClockVectorElement methods */
    STDMETHOD_(HRESULT,GetReplicaKey)(THIS_ DWORD *pdwReplicaKey) PURE;
    STDMETHOD_(HRESULT,GetTickCount)(THIS_ ULONGLONG *pullTickCount) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IClockVectorElement_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClockVectorElement_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClockVectorElement_Release(This) (This)->lpVtbl->Release(This)
#define IClockVectorElement_GetReplicaKey(This,pdwReplicaKey) (This)->lpVtbl->GetReplicaKey(This,pdwReplicaKey)
#define IClockVectorElement_GetTickCount(This,pullTickCount) (This)->lpVtbl->GetTickCount(This,pullTickCount)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IConstructReplicaKeyMap
DECLARE_INTERFACE_(IConstructReplicaKeyMap,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IConstructReplicaKeyMap methods */
    STDMETHOD_(HRESULT,FindOrAddReplica)(THIS_ BYTE *pbReplicaId,DWORD *pdwReplicaKey) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IConstructReplicaKeyMap_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IConstructReplicaKeyMap_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IConstructReplicaKeyMap_Release(This) (This)->lpVtbl->Release(This)
#define IConstructReplicaKeyMap_FindOrAddReplica(This,pbReplicaId,pdwReplicaKey) (This)->lpVtbl->FindOrAddReplica(This,pbReplicaId,pdwReplicaKey)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ICoreFragment
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ICoreFragment,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ICoreFragment methods */
    STDMETHOD_(HRESULT,GetColumnCount)(THIS_ DWORD *pColumnCount) PURE;
    STDMETHOD_(HRESULT,GetRangeCount)(THIS_ DWORD *pRangeCount) PURE;
    STDMETHOD_(HRESULT,NextColumn)(THIS_ DWORD *pChangeUnitIdSize) PURE;
    STDMETHOD_(HRESULT,NextRange)(THIS_ DWORD *pItemIdSize,IClockVector **piClockVector) PURE;
    STDMETHOD_(HRESULT,Reset)(THIS) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ICoreFragment_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICoreFragment_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICoreFragment_Release(This) (This)->lpVtbl->Release(This)
#define ICoreFragment_GetColumnCount(This,pColumnCount) (This)->lpVtbl->GetColumnCount(This,pColumnCount)
#define ICoreFragment_GetRangeCount(This,pRangeCount) (This)->lpVtbl->GetRangeCount(This,pRangeCount)
#define ICoreFragment_NextColumn(This,pChangeUnitIdSize) (This)->lpVtbl->NextColumn(This,pChangeUnitIdSize)
#define ICoreFragment_NextRange(This,pItemIdSize,piClockVector) (This)->lpVtbl->NextRange(This,pItemIdSize,piClockVector)
#define ICoreFragment_Reset() (This)->lpVtbl->Reset(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ILoadChangeContext
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ILoadChangeContext,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ILoadChangeContext methods */
    STDMETHOD_(HRESULT,GetSyncChange)(THIS_ ISyncChange **ppSyncChange) PURE;
    STDMETHOD_(HRESULT,SetRecoverableErrorOnChange)(THIS_ HRESULT hrError,IRecoverableErrorData *pErrorData) PURE;
    STDMETHOD_(HRESULT,SetRecoverableErrorOnChangeUnit)(THIS_ HRESULT hrError,ISyncChangeUnit *pChangeUnit,IRecoverableErrorData *pErrorData) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ILoadChangeContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ILoadChangeContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ILoadChangeContext_Release(This) (This)->lpVtbl->Release(This)
#define ILoadChangeContext_GetSyncChange(This,ppSyncChange) (This)->lpVtbl->GetSyncChange(This,ppSyncChange)
#define ILoadChangeContext_SetRecoverableErrorOnChange(This,hrError,pErrorData) (This)->lpVtbl->SetRecoverableErrorOnChange(This,hrError,pErrorData)
#define ILoadChangeContext_SetRecoverableErrorOnChangeUnit(This,hrError,pChangeUnit,pErrorData) (This)->lpVtbl->SetRecoverableErrorOnChangeUnit(This,hrError,pChangeUnit,pErrorData)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISyncChange
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISyncChange,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISyncChange methods */
    STDMETHOD_(HRESULT,GetChangeUnits)(THIS_ IEnumSyncChangeUnits **ppEnum) PURE;
    STDMETHOD_(HRESULT,GetChangeVersion)(THIS_ const BYTE *pbCurrentReplicaId,SYNC_VERSION *pVersion) PURE;
    STDMETHOD_(HRESULT,GetCreationVersion)(THIS_ const BYTE *pbCurrentReplicaId,SYNC_VERSION *pVersion) PURE;
    STDMETHOD_(HRESULT,GetFlags)(THIS_ DWORD *pdwFlags) PURE;
    STDMETHOD_(HRESULT,GetLearnedKnowledge)(THIS_ ISyncKnowledge **ppMadeWithKnowledge) PURE;
    STDMETHOD_(HRESULT,GetMadeWithKnowledge)(THIS_ ISyncKnowledge **ppMadeWithKnowledge) PURE;
    STDMETHOD_(HRESULT,GetOwnerReplicaId)(THIS_ DWORD *pcbIdSize) PURE;
    STDMETHOD_(HRESULT,GetRootItemId)(THIS_ DWORD *pcbIdSize) PURE;
    STDMETHOD_(HRESULT,GetWorkEstimate)(THIS_ DWORD *pdwWork) PURE;
    STDMETHOD_(HRESULT,SetWorkEstimate)(THIS_ DWORD dwWork) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISyncChange_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncChange_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncChange_Release(This) (This)->lpVtbl->Release(This)
#define ISyncChange_GetChangeUnits(This,ppEnum) (This)->lpVtbl->GetChangeUnits(This,ppEnum)
#define ISyncChange_GetChangeVersion(This,pbCurrentReplicaId,pVersion) (This)->lpVtbl->GetChangeVersion(This,pbCurrentReplicaId,pVersion)
#define ISyncChange_GetCreationVersion(This,pbCurrentReplicaId,pVersion) (This)->lpVtbl->GetCreationVersion(This,pbCurrentReplicaId,pVersion)
#define ISyncChange_GetFlags(This,pdwFlags) (This)->lpVtbl->GetFlags(This,pdwFlags)
#define ISyncChange_GetLearnedKnowledge(This,ppMadeWithKnowledge) (This)->lpVtbl->GetLearnedKnowledge(This,ppMadeWithKnowledge)
#define ISyncChange_GetMadeWithKnowledge(This,ppMadeWithKnowledge) (This)->lpVtbl->GetMadeWithKnowledge(This,ppMadeWithKnowledge)
#define ISyncChange_GetOwnerReplicaId(This,pcbIdSize) (This)->lpVtbl->GetOwnerReplicaId(This,pcbIdSize)
#define ISyncChange_GetRootItemId(This,pcbIdSize) (This)->lpVtbl->GetRootItemId(This,pcbIdSize)
#define ISyncChange_GetWorkEstimate(This,pdwWork) (This)->lpVtbl->GetWorkEstimate(This,pdwWork)
#define ISyncChange_SetWorkEstimate(This,dwWork) (This)->lpVtbl->SetWorkEstimate(This,dwWork)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISyncChangeUnit
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISyncChangeUnit,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISyncChangeUnit methods */
    STDMETHOD_(HRESULT,GetChangeUnitId)(THIS_ DWORD *pcbIdSize) PURE;
    STDMETHOD_(HRESULT,GetChangeUnitVersion)(THIS_ const BYTE *pbCurrentReplicaId,SYNC_VERSION *pVersion) PURE;
    STDMETHOD_(HRESULT,GetItemChange)(THIS_ ISyncChange **ppSyncChange) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISyncChangeUnit_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncChangeUnit_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncChangeUnit_Release(This) (This)->lpVtbl->Release(This)
#define ISyncChangeUnit_GetChangeUnitId(This,pcbIdSize) (This)->lpVtbl->GetChangeUnitId(This,pcbIdSize)
#define ISyncChangeUnit_GetChangeUnitVersion(This,pbCurrentReplicaId,pVersion) (This)->lpVtbl->GetChangeUnitVersion(This,pbCurrentReplicaId,pVersion)
#define ISyncChangeUnit_GetItemChange(This,ppSyncChange) (This)->lpVtbl->GetItemChange(This,ppSyncChange)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IRecoverableErrorData
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IRecoverableErrorData,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IRecoverableErrorData methods */
    STDMETHOD_(HRESULT,GetErrorDescription)(THIS_ DWORD *pcchErrorDescription) PURE;
    STDMETHOD_(HRESULT,GetItemDisplayName)(THIS_ DWORD *pcchItemDisplayName) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ LPCWSTR pcszItemDisplayName,LPCWSTR pcszErrorDescription) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IRecoverableErrorData_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRecoverableErrorData_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRecoverableErrorData_Release(This) (This)->lpVtbl->Release(This)
#define IRecoverableErrorData_GetErrorDescription(This,pcchErrorDescription) (This)->lpVtbl->GetErrorDescription(This,pcchErrorDescription)
#define IRecoverableErrorData_GetItemDisplayName(This,pcchItemDisplayName) (This)->lpVtbl->GetItemDisplayName(This,pcchItemDisplayName)
#define IRecoverableErrorData_Initialize(This,pcszItemDisplayName,pcszErrorDescription) (This)->lpVtbl->Initialize(This,pcszItemDisplayName,pcszErrorDescription)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IEnumSyncChangeUnits
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IEnumSyncChangeUnits,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IEnumSyncChangeUnits methods */
    STDMETHOD_(HRESULT,Clone)(THIS_ IEnumSyncChangeUnits **ppEnum) PURE;
    STDMETHOD_(HRESULT,Next)(THIS_ ULONG cChanges,ISyncChangeUnit **ppChangeUnit,ULONG *pcFetched) PURE;
    STDMETHOD_(HRESULT,Reset)(THIS) PURE;
    STDMETHOD_(HRESULT,Skip)(THIS_ ULONG cChanges) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IEnumSyncChangeUnits_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumSyncChangeUnits_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumSyncChangeUnits_Release(This) (This)->lpVtbl->Release(This)
#define IEnumSyncChangeUnits_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#define IEnumSyncChangeUnits_Next(This,cChanges,ppChangeUnit,pcFetched) (This)->lpVtbl->Next(This,cChanges,ppChangeUnit,pcFetched)
#define IEnumSyncChangeUnits_Reset() (This)->lpVtbl->Reset(This)
#define IEnumSyncChangeUnits_Skip(This,cChanges) (This)->lpVtbl->Skip(This,cChanges)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif /* __WINSYNC_H__ */
