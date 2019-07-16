/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VSPROV
#define _INC_VSPROV

#include <vss.h>
#include <vds.h>
#undef  INTERFACE
#define INTERFACE IVssHardwareSnapshotProvider
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssHardwareSnapshotProvider,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssHardwareSnapshotProvider methods */
    STDMETHOD_(HRESULT,AreLunsSupported)(THIS_ LONG lLunCount,LONG lContext,VSS_PWSZ *rgwszDevices,VDS_LUN_INFORMATION *pLunInformation,WINBOOL *pbIsSupported) PURE;
    STDMETHOD_(HRESULT,FillInLunInfo)(THIS_ VSS_PWSZ wszDeviceName,VDS_LUN_INFORMATION *pLunInfo,WINBOOL *pbIsSupported) PURE;
    STDMETHOD_(HRESULT,BeginPrepareSnapshot)(THIS_ VSS_ID SnapshotSetId,VSS_ID SnapshotId,LONG lContext,LONG lLunCount,VSS_PWSZ *rgDeviceNames,VDS_LUN_INFORMATION *rgLunInformation) PURE;
    STDMETHOD_(HRESULT,GetTargetLuns)(THIS_ LONG lLunCount,VSS_PWSZ *rgDeviceNames,VDS_LUN_INFORMATION *rgSourceLuns,VDS_LUN_INFORMATION *rgDestinationLuns) PURE;
    STDMETHOD_(HRESULT,LocateLuns)(THIS_ LONG lLunCount,VDS_LUN_INFORMATION *rgSourceLuns) PURE;
    STDMETHOD_(HRESULT,OnLunEmpty)(THIS_ VSS_PWSZ wszDeviceName,VDS_LUN_INFORMATION *pInformation) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssHardwareSnapshotProvider_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssHardwareSnapshotProvider_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssHardwareSnapshotProvider_Release(This) (This)->lpVtbl->Release(This)
#define IVssHardwareSnapshotProvider_AreLunsSupported(This,lLunCount,lContext,rgwszDevices,pLunInformation,pbIsSupported) (This)->lpVtbl->AreLunsSupported(This,lLunCount,lContext,rgwszDevices,pLunInformation,pbIsSupported)
#define IVssHardwareSnapshotProvider_FillInLunInfo(This,wszDeviceName,pLunInfo,pbIsSupported) (This)->lpVtbl->FillInLunInfo(This,wszDeviceName,pLunInfo,pbIsSupported)
#define IVssHardwareSnapshotProvider_BeginPrepareSnapshot(This,SnapshotSetId,SnapshotId,lContext,lLunCount,rgDeviceNames,rgLunInformation) (This)->lpVtbl->BeginPrepareSnapshot(This,SnapshotSetId,SnapshotId,lContext,lLunCount,rgDeviceNames,rgLunInformation)
#define IVssHardwareSnapshotProvider_GetTargetLuns(This,lLunCount,rgDeviceNames,rgSourceLuns,rgDestinationLuns) (This)->lpVtbl->GetTargetLuns(This,lLunCount,rgDeviceNames,rgSourceLuns,rgDestinationLuns)
#define IVssHardwareSnapshotProvider_LocateLuns(This,lLunCount,rgSourceLuns) (This)->lpVtbl->LocateLuns(This,lLunCount,rgSourceLuns)
#define IVssHardwareSnapshotProvider_OnLunEmpty(This,wszDeviceName,pInformation) (This)->lpVtbl->OnLunEmpty(This,wszDeviceName,pInformation)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssHardwareSnapshotProviderEx
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssHardwareSnapshotProviderEx,IVssHardwareSnapshotProvider)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssHardwareSnapshotProvider methods */
    STDMETHOD_(HRESULT,AreLunsSupported)(THIS_ LONG lLunCount,LONG lContext,VSS_PWSZ *rgwszDevices,VDS_LUN_INFORMATION *pLunInformation,WINBOOL *pbIsSupported) PURE;
    STDMETHOD_(HRESULT,FillInLunInfo)(THIS_ VSS_PWSZ wszDeviceName,VDS_LUN_INFORMATION *pLunInfo,WINBOOL *pbIsSupported) PURE;
    STDMETHOD_(HRESULT,BeginPrepareSnapshot)(THIS_ VSS_ID SnapshotSetId,VSS_ID SnapshotId,LONG lContext,LONG lLunCount,VSS_PWSZ *rgDeviceNames,VDS_LUN_INFORMATION *rgLunInformation) PURE;
    STDMETHOD_(HRESULT,GetTargetLuns)(THIS_ LONG lLunCount,VSS_PWSZ *rgDeviceNames,VDS_LUN_INFORMATION *rgSourceLuns,VDS_LUN_INFORMATION *rgDestinationLuns) PURE;
    STDMETHOD_(HRESULT,LocateLuns)(THIS_ LONG lLunCount,VDS_LUN_INFORMATION *rgSourceLuns) PURE;
    STDMETHOD_(HRESULT,OnLunEmpty)(THIS_ VSS_PWSZ wszDeviceName,VDS_LUN_INFORMATION *pInformation) PURE;

    /* IVssHardwareSnapshotProviderEx methods */
    STDMETHOD_(HRESULT,GetProviderCapabilities)(THIS) PURE;
    STDMETHOD_(HRESULT,OnLunStateChange)(THIS_ VDS_LUN_INFORMATION *pSnapshotLuns,VDS_LUN_INFORMATION *pOriginalLuns,DWORD dwCount,DWORD dwFlags) PURE;
    STDMETHOD_(HRESULT,OnReuseLuns)(THIS) PURE;
    STDMETHOD_(HRESULT,ResyncLuns)(THIS_ VDS_LUN_INFORMATION *pSourceLuns,VDS_LUN_INFORMATION *pTargetLuns,DWORD dwCount,IVssAsync **ppAsync) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssHardwareSnapshotProviderEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssHardwareSnapshotProviderEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssHardwareSnapshotProviderEx_Release(This) (This)->lpVtbl->Release(This)
#define IVssHardwareSnapshotProviderEx_AreLunsSupported(This,lLunCount,lContext,rgwszDevices,pLunInformation,pbIsSupported) (This)->lpVtbl->AreLunsSupported(This,lLunCount,lContext,rgwszDevices,pLunInformation,pbIsSupported)
#define IVssHardwareSnapshotProviderEx_FillInLunInfo(This,wszDeviceName,pLunInfo,pbIsSupported) (This)->lpVtbl->FillInLunInfo(This,wszDeviceName,pLunInfo,pbIsSupported)
#define IVssHardwareSnapshotProviderEx_BeginPrepareSnapshot(This,SnapshotSetId,SnapshotId,lContext,lLunCount,rgDeviceNames,rgLunInformation) (This)->lpVtbl->BeginPrepareSnapshot(This,SnapshotSetId,SnapshotId,lContext,lLunCount,rgDeviceNames,rgLunInformation)
#define IVssHardwareSnapshotProviderEx_GetTargetLuns(This,lLunCount,rgDeviceNames,rgSourceLuns,rgDestinationLuns) (This)->lpVtbl->GetTargetLuns(This,lLunCount,rgDeviceNames,rgSourceLuns,rgDestinationLuns)
#define IVssHardwareSnapshotProviderEx_LocateLuns(This,lLunCount,rgSourceLuns) (This)->lpVtbl->LocateLuns(This,lLunCount,rgSourceLuns)
#define IVssHardwareSnapshotProviderEx_OnLunEmpty(This,wszDeviceName,pInformation) (This)->lpVtbl->OnLunEmpty(This,wszDeviceName,pInformation)
#define IVssHardwareSnapshotProviderEx_GetProviderCapabilities() (This)->lpVtbl->GetProviderCapabilities(This)
#define IVssHardwareSnapshotProviderEx_OnLunStateChange(This,pSnapshotLuns,pOriginalLuns,dwCount,dwFlags) (This)->lpVtbl->OnLunStateChange(This,pSnapshotLuns,pOriginalLuns,dwCount,dwFlags)
#define IVssHardwareSnapshotProviderEx_OnReuseLuns() (This)->lpVtbl->OnReuseLuns(This)
#define IVssHardwareSnapshotProviderEx_ResyncLuns(This,pSourceLuns,pTargetLuns,dwCount,ppAsync) (This)->lpVtbl->ResyncLuns(This,pSourceLuns,pTargetLuns,dwCount,ppAsync)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssProviderCreateSnapshotSet
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssProviderCreateSnapshotSet,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssProviderCreateSnapshotSet methods */
    STDMETHOD_(HRESULT,EndPrepareSnapshots)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,PreCommitSnapshots)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,CommitSnapshots)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,PostCommitSnapshots)(THIS_ VSS_ID SnapshotSetId,LONG lSnapshotsCount) PURE;
    STDMETHOD_(HRESULT,PreFinalCommitSnapshots)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,PostFinalCommitSnapshots)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,AbortSnapshots)(THIS_ VSS_ID SnapshotSetId) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssProviderCreateSnapshotSet_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssProviderCreateSnapshotSet_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssProviderCreateSnapshotSet_Release(This) (This)->lpVtbl->Release(This)
#define IVssProviderCreateSnapshotSet_EndPrepareSnapshots(This,SnapshotSetId) (This)->lpVtbl->EndPrepareSnapshots(This,SnapshotSetId)
#define IVssProviderCreateSnapshotSet_PreCommitSnapshots(This,SnapshotSetId) (This)->lpVtbl->PreCommitSnapshots(This,SnapshotSetId)
#define IVssProviderCreateSnapshotSet_CommitSnapshots(This,SnapshotSetId) (This)->lpVtbl->CommitSnapshots(This,SnapshotSetId)
#define IVssProviderCreateSnapshotSet_PostCommitSnapshots(This,SnapshotSetId,lSnapshotsCount) (This)->lpVtbl->PostCommitSnapshots(This,SnapshotSetId,lSnapshotsCount)
#define IVssProviderCreateSnapshotSet_PreFinalCommitSnapshots(This,SnapshotSetId) (This)->lpVtbl->PreFinalCommitSnapshots(This,SnapshotSetId)
#define IVssProviderCreateSnapshotSet_PostFinalCommitSnapshots(This,SnapshotSetId) (This)->lpVtbl->PostFinalCommitSnapshots(This,SnapshotSetId)
#define IVssProviderCreateSnapshotSet_AbortSnapshots(This,SnapshotSetId) (This)->lpVtbl->AbortSnapshots(This,SnapshotSetId)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssProviderNotifications
DECLARE_INTERFACE_(IVssProviderNotifications,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssProviderNotifications methods */
    STDMETHOD_(HRESULT,OnLoad)(THIS_ IUnknown *pCallback) PURE;
    STDMETHOD_(HRESULT,OnUnload)(THIS_ WINBOOL bForceUnload) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssProviderNotifications_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssProviderNotifications_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssProviderNotifications_Release(This) (This)->lpVtbl->Release(This)
#define IVssProviderNotifications_OnLoad(This,pCallback) (This)->lpVtbl->OnLoad(This,pCallback)
#define IVssProviderNotifications_OnUnload(This,bForceUnload) (This)->lpVtbl->OnUnload(This,bForceUnload)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssSoftwareSnapshotProvider
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssSoftwareSnapshotProvider,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssSoftwareSnapshotProvider methods */
    STDMETHOD_(HRESULT,SetContext)(THIS_ LONG lContext) PURE;
    STDMETHOD_(HRESULT,GetSnapshotProperties)(THIS_ VSS_ID SnapshotId,VSS_SNAPSHOT_PROP *pProp) PURE;
    STDMETHOD_(HRESULT,Query)(THIS_ VSS_ID QueriedObjectId,VSS_OBJECT_TYPE eQueriedObjectType,VSS_OBJECT_TYPE eReturnedObjectsType,IVssEnumObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,DeleteSnapshots)(THIS_ VSS_ID SourceObjectId,VSS_OBJECT_TYPE eSourceObjectType,WINBOOL bForceDelete,LONG *plDeletedSnapshots,VSS_ID *pNondeletedSnapshotID) PURE;
    STDMETHOD_(HRESULT,BeginPrepareSnapshot)(THIS_ VSS_ID SnapshotSetId,VSS_ID SnapshotId,VSS_PWSZ pwszVolumeName,LONG lNewContext) PURE;
    STDMETHOD_(HRESULT,IsVolumeSupported)(THIS_ VSS_PWSZ pwszVolumeName,WINBOOL *pbSupportedByThisProvider) PURE;
    STDMETHOD_(HRESULT,IsVolumeSnapshotted)(THIS_ VSS_PWSZ pwszVolumeName,WINBOOL *pbSnapshotsPresent,LONG *plSnapshotCompatibility) PURE;
    STDMETHOD_(HRESULT,SetSnapshotProperty)(THIS_ VSS_ID SnapshotId,VSS_SNAPSHOT_PROPERTY_ID eSnapshotPropertyId,VARIANT vProperty) PURE;
    STDMETHOD_(HRESULT,RevertToSnapshot)(THIS_ VSS_ID SnapshotId) PURE;
    STDMETHOD_(HRESULT,QueryRevertStatus)(THIS_ VSS_PWSZ pwszVolume,IVssAsync **ppAsync) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssSoftwareSnapshotProvider_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssSoftwareSnapshotProvider_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssSoftwareSnapshotProvider_Release(This) (This)->lpVtbl->Release(This)
#define IVssSoftwareSnapshotProvider_SetContext(This,lContext) (This)->lpVtbl->SetContext(This,lContext)
#define IVssSoftwareSnapshotProvider_GetSnapshotProperties(This,SnapshotId,pProp) (This)->lpVtbl->GetSnapshotProperties(This,SnapshotId,pProp)
#define IVssSoftwareSnapshotProvider_Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum) (This)->lpVtbl->Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum)
#define IVssSoftwareSnapshotProvider_DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID) (This)->lpVtbl->DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID)
#define IVssSoftwareSnapshotProvider_BeginPrepareSnapshot(This,SnapshotSetId,SnapshotId,pwszVolumeName,lNewContext) (This)->lpVtbl->BeginPrepareSnapshot(This,SnapshotSetId,SnapshotId,pwszVolumeName,lNewContext)
#define IVssSoftwareSnapshotProvider_IsVolumeSupported(This,pwszVolumeName,pbSupportedByThisProvider) (This)->lpVtbl->IsVolumeSupported(This,pwszVolumeName,pbSupportedByThisProvider)
#define IVssSoftwareSnapshotProvider_IsVolumeSnapshotted(This,pwszVolumeName,pbSnapshotsPresent,plSnapshotCompatibility) (This)->lpVtbl->IsVolumeSnapshotted(This,pwszVolumeName,pbSnapshotsPresent,plSnapshotCompatibility)
#define IVssSoftwareSnapshotProvider_SetSnapshotProperty(This,SnapshotId,eSnapshotPropertyId,vProperty) (This)->lpVtbl->SetSnapshotProperty(This,SnapshotId,eSnapshotPropertyId,vProperty)
#define IVssSoftwareSnapshotProvider_RevertToSnapshot(This,SnapshotId) (This)->lpVtbl->RevertToSnapshot(This,SnapshotId)
#define IVssSoftwareSnapshotProvider_QueryRevertStatus(This,pwszVolume,ppAsync) (This)->lpVtbl->QueryRevertStatus(This,pwszVolume,ppAsync)
#endif /*COBJMACROS*/

#endif /*_INC_VSPROV*/
