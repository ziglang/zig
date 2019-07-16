/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VSBACKUP
#define _INC_VSBACKUP

#include <vss.h>
#include <vswriter.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct VSS_COMPONENTINFO {
  VSS_COMPONENT_TYPE type;
  BSTR               bstrLogicalPath;
  BSTR               bstrComponentName;
  BSTR               bstrCaption;
  BYTE               *pbIcon;
  UINT               cbIcon;
  BOOLEAN            bRestoreMetadata;
  BOOLEAN            bNotifyOnBackupComplete;
  BOOLEAN            bSelectable;
  BOOLEAN            bSelectableForRestore;
  DWORD              dwComponentFlags;
  UINT               cFileCount;
  UINT               cDatabases;
  UINT               cLogFiles;
  UINT               cDependencies;
} VSS_COMPONENTINFO, *PVSSCOMPONENTINFO;

HRESULT WINAPI CreateVssBackupComponentsInternal(
  IVssBackupComponents **ppBackup
);

FORCEINLINE
HRESULT WINAPI CreateVssBackupComponents(
  IVssBackupComponents **ppBackup
){return CreateVssBackupComponentsInternal(ppBackup);}

HRESULT WINAPI CreateVssExamineWriterMetadataInternal(
  BSTR bstrXML,
  IVssExamineWriterMetadata **ppMetadata
);

FORCEINLINE
HRESULT WINAPI CreateVssExamineWriterMetadata(
  BSTR bstrXML,
  IVssExamineWriterMetadata **ppMetadata
){return CreateVssExamineWriterMetadataInternal(bstrXML,ppMetadata);}

HRESULT WINAPI IsVolumeSnapshottedInternal(
  VSS_PWSZ pwszVolumeName,
  BOOLEAN *pbSnapshotsPresent,
  LONG *plSnapshotCapability
);

FORCEINLINE
HRESULT WINAPI IsVolumeSnapshotted(
  VSS_PWSZ pwszVolumeName,
  BOOLEAN *pbSnapshotsPresent,
  LONG *plSnapshotCapability
){return IsVolumeSnapshottedInternal(pwszVolumeName,pbSnapshotsPresent,plSnapshotCapability);}

HRESULT WINAPI ShouldBlockRevertInternal(
  LPCWSTR wszVolumeName,
  BOOLEAN *pbBlock
);

FORCEINLINE
HRESULT WINAPI ShouldBlockRevert(
  LPCWSTR wszVolumeName,
  BOOLEAN *pbBlock
){return ShouldBlockRevertInternal(wszVolumeName,pbBlock);}

void WINAPI VssFreeSnapshotPropertiesInternal(
  VSS_SNAPSHOT_PROP *pProp
);

FORCEINLINE
void WINAPI VssFreeSnapshotProperties(
  VSS_SNAPSHOT_PROP *pProp
){VssFreeSnapshotPropertiesInternal(pProp);}

HRESULT WINAPI GetProviderMgmtInterfaceInternal(
  VSS_ID ProviderId,
  IID InterfaceId,
  IUnknown** ppItf
);

FORCEINLINE
HRESULT WINAPI GetProviderMgmtInterface(
  VSS_ID ProviderId,
  IID InterfaceId,
  IUnknown** ppItf
){return GetProviderMgmtInterfaceInternal(ProviderId,InterfaceId,ppItf);}

#ifdef __cplusplus
}
#endif

#undef  INTERFACE
#define INTERFACE IVssBackupComponents
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssBackupComponents,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssBackupComponents methods */
    STDMETHOD_(HRESULT,GetWriterComponentsCount)(THIS_ UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetWriterComponents)(THIS_ UINT iWriter,IVssWriterComponentsExt **pWriterComponents) PURE;
    STDMETHOD_(HRESULT,InitializeForBackup)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetBackupState)(THIS_ BOOLEAN bSelectComponents,BOOLEAN bBackupBootableSystemState,VSS_BACKUP_TYPE backupType,BOOLEAN bPartialFileSupport) PURE;
    STDMETHOD_(HRESULT,InitializeForRestore)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetRestoreState)(THIS_ VSS_RESTORE_TYPE restoreType) PURE;
    STDMETHOD_(HRESULT,GatherWriterMetadata)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadataCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadata)(THIS_ UINT iWriter,VSS_ID *pidWriterInstance,IVssExamineWriterMetadata **ppMetadata) PURE;
    STDMETHOD_(HRESULT,FreeWriterMetadata)(THIS) PURE;
    STDMETHOD_(HRESULT,AddComponent)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName) PURE;
    STDMETHOD_(HRESULT,PrepareForBackup)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AbortBackup)(THIS) PURE;
    STDMETHOD_(HRESULT,GatherWriterStatus)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterStatusCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,FreeWriterStatus)(THIS) PURE;
    STDMETHOD_(HRESULT,GetWriterStatus)(THIS_ UINT iWriter,VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriter,VSS_WRITER_STATE *pState,HRESULT *pHrResultFailure) PURE;
    STDMETHOD_(HRESULT,SetBackupSucceeded)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSucceeded) PURE;
    STDMETHOD_(HRESULT,SetBackupOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszBackupOptions) PURE;
    STDMETHOD_(HRESULT,SetSelectedForRestore)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSelectedForRestore) PURE;
    STDMETHOD_(HRESULT,SetRestoreOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszRestoreOptions) PURE;
    STDMETHOD_(HRESULT,SetAdditionalRestores)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bAdditionalResources) PURE;
    STDMETHOD_(HRESULT,SetPreviousBackupStamp)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPreviousBackupStamp) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,BackupComplete)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AddAlternativeLocationMapping)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszDestination) PURE;
    STDMETHOD_(HRESULT,AddRestoreSubcomponent)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszSubComponentLogicalPath,LPCWSTR wszSubComponentName,BOOLEAN bRepair) PURE;
    STDMETHOD_(HRESULT,SetFileRestoreStatus)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,VSS_FILE_RESTORE_STATUS status) PURE;
    STDMETHOD_(HRESULT,AddNewTarget)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFileName,BOOLEAN bRecursive,LPCWSTR wszAlternatePath) PURE;
    STDMETHOD_(HRESULT,SetRangesFilePath)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,UINT iPartialFile,LPCWSTR wszRangesFile) PURE;
    STDMETHOD_(HRESULT,PreRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,PostRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,SetContext)(THIS_ LONG lContext) PURE;
    STDMETHOD_(HRESULT,StartSnapshotSet)(THIS_ VSS_ID *pSnapshotSetId) PURE;
    STDMETHOD_(HRESULT,AddToSnapshotSet)(THIS_ VSS_PWSZ pwszVolumeName,VSS_ID ProviderId,VSS_ID *pidSnapshot) PURE;
    STDMETHOD_(HRESULT,DoSnapshotSet)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,DeleteSnapshots)(THIS_ VSS_ID SourceObjectId,VSS_OBJECT_TYPE eSourceObjectType,BOOLEAN bForceDelete,LONG *plDeletedSnapshots,VSS_ID *pNondeletedSnapshotID) PURE;
    STDMETHOD_(HRESULT,ImportSnapshots)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,BreakSnapshotSet)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,GetSnapshotProperties)(THIS_ VSS_ID SnapshotId,VSS_SNAPSHOT_PROP *pProp) PURE;
    STDMETHOD_(HRESULT,Query)(THIS_ VSS_ID QueriedObjectId,VSS_OBJECT_TYPE eQueriedObjectType,VSS_OBJECT_TYPE eReturnedObjectsType,IVssEnumObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,IsVolumeSupported)(THIS_ VSS_ID ProviderId,VSS_PWSZ pwszVolumeName,BOOLEAN *pbSupportedByThisProvider) PURE;
    STDMETHOD_(HRESULT,DisableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,EnableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,DisableWriterInstances)(THIS_ const VSS_ID *rgWriterInstanceId,UINT cInstanceId) PURE;
    STDMETHOD_(HRESULT,ExposeSnapshot)(THIS_ VSS_ID SnapshotId,VSS_PWSZ wszPathFromRoot,LONG lAttributes,VSS_PWSZ wszExpose,VSS_PWSZ *pwszExposed) PURE;
    STDMETHOD_(HRESULT,RevertToSnapshot)(THIS_ VSS_ID SnapshotId,BOOLEAN bForceDismount) PURE;
    STDMETHOD_(HRESULT,QueryRevertStatus)(THIS_ VSS_PWSZ pwszVolume,IVssAsync **ppAsync) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssBackupComponents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssBackupComponents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssBackupComponents_Release(This) (This)->lpVtbl->Release(This)
#define IVssBackupComponents_GetWriterComponentsCount(This,pcComponents) (This)->lpVtbl->GetWriterComponentsCount(This,pcComponents)
#define IVssBackupComponents_GetWriterComponents(This,iWriter,pWriterComponents) (This)->lpVtbl->GetWriterComponents(This,iWriter,pWriterComponents)
#define IVssBackupComponents_InitializeForBackup(This,bstrXML) (This)->lpVtbl->InitializeForBackup(This,bstrXML)
#define IVssBackupComponents_SetBackupState(This,bSelectComponents,bBackupBootableSystemState,backupType,bPartialFileSupport) (This)->lpVtbl->SetBackupState(This,bSelectComponents,bBackupBootableSystemState,backupType,bPartialFileSupport)
#define IVssBackupComponents_InitializeForRestore(This,bstrXML) (This)->lpVtbl->InitializeForRestore(This,bstrXML)
#define IVssBackupComponents_SetRestoreState(This,restoreType) (This)->lpVtbl->SetRestoreState(This,restoreType)
#define IVssBackupComponents_GatherWriterMetadata(This,ppAsync) (This)->lpVtbl->GatherWriterMetadata(This,ppAsync)
#define IVssBackupComponents_GetWriterMetadataCount(This,pcWriters) (This)->lpVtbl->GetWriterMetadataCount(This,pcWriters)
#define IVssBackupComponents_GetWriterMetadata(This,iWriter,pidWriterInstance,ppMetadata) (This)->lpVtbl->GetWriterMetadata(This,iWriter,pidWriterInstance,ppMetadata)
#define IVssBackupComponents_FreeWriterMetadata() (This)->lpVtbl->FreeWriterMetadata(This)
#define IVssBackupComponents_AddComponent(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName) (This)->lpVtbl->AddComponent(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName)
#define IVssBackupComponents_PrepareForBackup(This,ppAsync) (This)->lpVtbl->PrepareForBackup(This,ppAsync)
#define IVssBackupComponents_AbortBackup() (This)->lpVtbl->AbortBackup(This)
#define IVssBackupComponents_GatherWriterStatus(This,ppAsync) (This)->lpVtbl->GatherWriterStatus(This,ppAsync)
#define IVssBackupComponents_GetWriterStatusCount(This,pcWriters) (This)->lpVtbl->GetWriterStatusCount(This,pcWriters)
#define IVssBackupComponents_FreeWriterStatus() (This)->lpVtbl->FreeWriterStatus(This)
#define IVssBackupComponents_GetWriterStatus(This,iWriter,pidInstance,pidWriter,pbstrWriter,pState,pHrResultFailure) (This)->lpVtbl->GetWriterStatus(This,iWriter,pidInstance,pidWriter,pbstrWriter,pState,pHrResultFailure)
#define IVssBackupComponents_SetBackupSucceeded(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName,bSucceeded) (This)->lpVtbl->SetBackupSucceeded(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName,bSucceeded)
#define IVssBackupComponents_SetBackupOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszBackupOptions) (This)->lpVtbl->SetBackupOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszBackupOptions)
#define IVssBackupComponents_SetSelectedForRestore(This,writerId,componentType,wszLogicalPath,wszComponentName,bSelectedForRestore) (This)->lpVtbl->SetSelectedForRestore(This,writerId,componentType,wszLogicalPath,wszComponentName,bSelectedForRestore)
#define IVssBackupComponents_SetRestoreOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszRestoreOptions) (This)->lpVtbl->SetRestoreOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszRestoreOptions)
#define IVssBackupComponents_SetAdditionalRestores(This,writerId,componentType,wszLogicalPath,wszComponentName,bAdditionalResources) (This)->lpVtbl->SetAdditionalRestores(This,writerId,componentType,wszLogicalPath,wszComponentName,bAdditionalResources)
#define IVssBackupComponents_SetPreviousBackupStamp(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPreviousBackupStamp) (This)->lpVtbl->SetPreviousBackupStamp(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPreviousBackupStamp)
#define IVssBackupComponents_SaveAsXML(This,pbstrXML) (This)->lpVtbl->SaveAsXML(This,pbstrXML)
#define IVssBackupComponents_BackupComplete(This,ppAsync) (This)->lpVtbl->BackupComplete(This,ppAsync)
#define IVssBackupComponents_AddAlternativeLocationMapping(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPath,wszFilespec,bRecursive,wszDestination) (This)->lpVtbl->AddAlternativeLocationMapping(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPath,wszFilespec,bRecursive,wszDestination)
#define IVssBackupComponents_AddRestoreSubcomponent(This,writerId,componentType,wszLogicalPath,wszComponentName,wszSubComponentLogicalPath,wszSubComponentName,bRepair) (This)->lpVtbl->AddRestoreSubcomponent(This,writerId,componentType,wszLogicalPath,wszComponentName,wszSubComponentLogicalPath,wszSubComponentName,bRepair)
#define IVssBackupComponents_SetFileRestoreStatus(This,writerId,componentType,wszLogicalPath,wszComponentName,status) (This)->lpVtbl->SetFileRestoreStatus(This,writerId,componentType,wszLogicalPath,wszComponentName,status)
#define IVssBackupComponents_AddNewTarget(This,writerId,ct,wszLogicalPath,wszComponentName,wszPath,wszFileName,bRecursive,wszAlternatePath) (This)->lpVtbl->AddNewTarget(This,writerId,ct,wszLogicalPath,wszComponentName,wszPath,wszFileName,bRecursive,wszAlternatePath)
#define IVssBackupComponents_SetRangesFilePath(This,writerId,ct,wszLogicalPath,wszComponentName,iPartialFile,wszRangesFile) (This)->lpVtbl->SetRangesFilePath(This,writerId,ct,wszLogicalPath,wszComponentName,iPartialFile,wszRangesFile)
#define IVssBackupComponents_PreRestore(This,ppAsync) (This)->lpVtbl->PreRestore(This,ppAsync)
#define IVssBackupComponents_PostRestore(This,ppAsync) (This)->lpVtbl->PostRestore(This,ppAsync)
#define IVssBackupComponents_SetContext(This,lContext) (This)->lpVtbl->SetContext(This,lContext)
#define IVssBackupComponents_StartSnapshotSet(This,pSnapshotSetId) (This)->lpVtbl->StartSnapshotSet(This,pSnapshotSetId)
#define IVssBackupComponents_AddToSnapshotSet(This,pwszVolumeName,ProviderId,pidSnapshot) (This)->lpVtbl->AddToSnapshotSet(This,pwszVolumeName,ProviderId,pidSnapshot)
#define IVssBackupComponents_DoSnapshotSet(This,ppAsync) (This)->lpVtbl->DoSnapshotSet(This,ppAsync)
#define IVssBackupComponents_DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID) (This)->lpVtbl->DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID)
#define IVssBackupComponents_ImportSnapshots(This,ppAsync) (This)->lpVtbl->ImportSnapshots(This,ppAsync)
#define IVssBackupComponents_BreakSnapshotSet(This,SnapshotSetId) (This)->lpVtbl->BreakSnapshotSet(This,SnapshotSetId)
#define IVssBackupComponents_GetSnapshotProperties(This,SnapshotId,pProp) (This)->lpVtbl->GetSnapshotProperties(This,SnapshotId,pProp)
#define IVssBackupComponents_Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum) (This)->lpVtbl->Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum)
#define IVssBackupComponents_IsVolumeSupported(This,ProviderId,pwszVolumeName,pbSupportedByThisProvider) (This)->lpVtbl->IsVolumeSupported(This,ProviderId,pwszVolumeName,pbSupportedByThisProvider)
#define IVssBackupComponents_DisableWriterClasses(This,rgWriterClassId,cClassId) (This)->lpVtbl->DisableWriterClasses(This,rgWriterClassId,cClassId)
#define IVssBackupComponents_EnableWriterClasses(This,rgWriterClassId,cClassId) (This)->lpVtbl->EnableWriterClasses(This,rgWriterClassId,cClassId)
#define IVssBackupComponents_DisableWriterInstances(This,rgWriterInstanceId,cInstanceId) (This)->lpVtbl->DisableWriterInstances(This,rgWriterInstanceId,cInstanceId)
#define IVssBackupComponents_ExposeSnapshot(This,SnapshotId,wszPathFromRoot,lAttributes,wszExpose,pwszExposed) (This)->lpVtbl->ExposeSnapshot(This,SnapshotId,wszPathFromRoot,lAttributes,wszExpose,pwszExposed)
#define IVssBackupComponents_RevertToSnapshot(This,SnapshotId,bForceDismount) (This)->lpVtbl->RevertToSnapshot(This,SnapshotId,bForceDismount)
#define IVssBackupComponents_QueryRevertStatus(This,pwszVolume,ppAsync) (This)->lpVtbl->QueryRevertStatus(This,pwszVolume,ppAsync)
#endif /*COBJMACROS*/

#if (_WIN32_WINNT >= 0x0600)
#undef  INTERFACE
#define INTERFACE IVssBackupComponentsEx
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssBackupComponentsEx,IVssBackupComponents)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssBackupComponents methods */
    STDMETHOD_(HRESULT,GetWriterComponentsCount)(THIS_ UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetWriterComponents)(THIS_ UINT iWriter,IVssWriterComponentsExt **pWriterComponents) PURE;
    STDMETHOD_(HRESULT,InitializeForBackup)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetBackupState)(THIS_ BOOLEAN bSelectComponents,BOOLEAN bBackupBootableSystemState,VSS_BACKUP_TYPE backupType,BOOLEAN bPartialFileSupport) PURE;
    STDMETHOD_(HRESULT,InitializeForRestore)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetRestoreState)(THIS_ VSS_RESTORE_TYPE restoreType) PURE;
    STDMETHOD_(HRESULT,GatherWriterMetadata)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadataCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadata)(THIS_ UINT iWriter,VSS_ID *pidWriterInstance,IVssExamineWriterMetadata **ppMetadata) PURE;
    STDMETHOD_(HRESULT,FreeWriterMetadata)(THIS) PURE;
    STDMETHOD_(HRESULT,AddComponent)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName) PURE;
    STDMETHOD_(HRESULT,PrepareForBackup)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AbortBackup)(THIS) PURE;
    STDMETHOD_(HRESULT,GatherWriterStatus)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterStatusCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,FreeWriterStatus)(THIS) PURE;
    STDMETHOD_(HRESULT,GetWriterStatus)(THIS_ UINT iWriter,VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriter,VSS_WRITER_STATE *pState,HRESULT *pHrResultFailure) PURE;
    STDMETHOD_(HRESULT,SetBackupSucceeded)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSucceeded) PURE;
    STDMETHOD_(HRESULT,SetBackupOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszBackupOptions) PURE;
    STDMETHOD_(HRESULT,SetSelectedForRestore)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSelectedForRestore) PURE;
    STDMETHOD_(HRESULT,SetRestoreOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszRestoreOptions) PURE;
    STDMETHOD_(HRESULT,SetAdditionalRestores)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bAdditionalResources) PURE;
    STDMETHOD_(HRESULT,SetPreviousBackupStamp)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPreviousBackupStamp) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,BackupComplete)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AddAlternativeLocationMapping)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszDestination) PURE;
    STDMETHOD_(HRESULT,AddRestoreSubcomponent)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszSubComponentLogicalPath,LPCWSTR wszSubComponentName,BOOLEAN bRepair) PURE;
    STDMETHOD_(HRESULT,SetFileRestoreStatus)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,VSS_FILE_RESTORE_STATUS status) PURE;
    STDMETHOD_(HRESULT,AddNewTarget)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFileName,BOOLEAN bRecursive,LPCWSTR wszAlternatePath) PURE;
    STDMETHOD_(HRESULT,SetRangesFilePath)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,UINT iPartialFile,LPCWSTR wszRangesFile) PURE;
    STDMETHOD_(HRESULT,PreRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,PostRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,SetContext)(THIS_ LONG lContext) PURE;
    STDMETHOD_(HRESULT,StartSnapshotSet)(THIS_ VSS_ID *pSnapshotSetId) PURE;
    STDMETHOD_(HRESULT,AddToSnapshotSet)(THIS_ VSS_PWSZ pwszVolumeName,VSS_ID ProviderId,VSS_ID *pidSnapshot) PURE;
    STDMETHOD_(HRESULT,DoSnapshotSet)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,DeleteSnapshots)(THIS_ VSS_ID SourceObjectId,VSS_OBJECT_TYPE eSourceObjectType,BOOLEAN bForceDelete,LONG *plDeletedSnapshots,VSS_ID *pNondeletedSnapshotID) PURE;
    STDMETHOD_(HRESULT,ImportSnapshots)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,BreakSnapshotSet)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,GetSnapshotProperties)(THIS_ VSS_ID SnapshotId,VSS_SNAPSHOT_PROP *pProp) PURE;
    STDMETHOD_(HRESULT,Query)(THIS_ VSS_ID QueriedObjectId,VSS_OBJECT_TYPE eQueriedObjectType,VSS_OBJECT_TYPE eReturnedObjectsType,IVssEnumObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,IsVolumeSupported)(THIS_ VSS_ID ProviderId,VSS_PWSZ pwszVolumeName,BOOLEAN *pbSupportedByThisProvider) PURE;
    STDMETHOD_(HRESULT,DisableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,EnableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,DisableWriterInstances)(THIS_ const VSS_ID *rgWriterInstanceId,UINT cInstanceId) PURE;
    STDMETHOD_(HRESULT,ExposeSnapshot)(THIS_ VSS_ID SnapshotId,VSS_PWSZ wszPathFromRoot,LONG lAttributes,VSS_PWSZ wszExpose,VSS_PWSZ *pwszExposed) PURE;
    STDMETHOD_(HRESULT,RevertToSnapshot)(THIS_ VSS_ID SnapshotId,BOOLEAN bForceDismount) PURE;
    STDMETHOD_(HRESULT,QueryRevertStatus)(THIS_ VSS_PWSZ pwszVolume,IVssAsync **ppAsync) PURE;

    /* IVssBackupComponentsEx methods */
    STDMETHOD_(HRESULT,GetWriterMetadataEx)(THIS_ UINT iWriter,VSS_ID *pidInstance,IVssExamineWriterMetadataEx **ppMetadata) PURE;
    STDMETHOD_(HRESULT,SetSelectedForRestoreEx)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSelectedForRestore,VSS_ID instanceId) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssBackupComponentsEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssBackupComponentsEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssBackupComponentsEx_Release(This) (This)->lpVtbl->Release(This)
#define IVssBackupComponentsEx_GetWriterComponentsCount(This,pcComponents) (This)->lpVtbl->GetWriterComponentsCount(This,pcComponents)
#define IVssBackupComponentsEx_GetWriterComponents(This,iWriter,pWriterComponents) (This)->lpVtbl->GetWriterComponents(This,iWriter,pWriterComponents)
#define IVssBackupComponentsEx_InitializeForBackup(This,bstrXML) (This)->lpVtbl->InitializeForBackup(This,bstrXML)
#define IVssBackupComponentsEx_SetBackupState(This,bSelectComponents,bBackupBootableSystemState,backupType,bPartialFileSupport) (This)->lpVtbl->SetBackupState(This,bSelectComponents,bBackupBootableSystemState,backupType,bPartialFileSupport)
#define IVssBackupComponentsEx_InitializeForRestore(This,bstrXML) (This)->lpVtbl->InitializeForRestore(This,bstrXML)
#define IVssBackupComponentsEx_SetRestoreState(This,restoreType) (This)->lpVtbl->SetRestoreState(This,restoreType)
#define IVssBackupComponentsEx_GatherWriterMetadata(This,ppAsync) (This)->lpVtbl->GatherWriterMetadata(This,ppAsync)
#define IVssBackupComponentsEx_GetWriterMetadataCount(This,pcWriters) (This)->lpVtbl->GetWriterMetadataCount(This,pcWriters)
#define IVssBackupComponentsEx_GetWriterMetadata(This,iWriter,pidWriterInstance,ppMetadata) (This)->lpVtbl->GetWriterMetadata(This,iWriter,pidWriterInstance,ppMetadata)
#define IVssBackupComponentsEx_FreeWriterMetadata() (This)->lpVtbl->FreeWriterMetadata(This)
#define IVssBackupComponentsEx_AddComponent(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName) (This)->lpVtbl->AddComponent(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName)
#define IVssBackupComponentsEx_PrepareForBackup(This,ppAsync) (This)->lpVtbl->PrepareForBackup(This,ppAsync)
#define IVssBackupComponentsEx_AbortBackup() (This)->lpVtbl->AbortBackup(This)
#define IVssBackupComponentsEx_GatherWriterStatus(This,ppAsync) (This)->lpVtbl->GatherWriterStatus(This,ppAsync)
#define IVssBackupComponentsEx_GetWriterStatusCount(This,pcWriters) (This)->lpVtbl->GetWriterStatusCount(This,pcWriters)
#define IVssBackupComponentsEx_FreeWriterStatus() (This)->lpVtbl->FreeWriterStatus(This)
#define IVssBackupComponentsEx_GetWriterStatus(This,iWriter,pidInstance,pidWriter,pbstrWriter,pState,pHrResultFailure) (This)->lpVtbl->GetWriterStatus(This,iWriter,pidInstance,pidWriter,pbstrWriter,pState,pHrResultFailure)
#define IVssBackupComponentsEx_SetBackupSucceeded(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName,bSucceeded) (This)->lpVtbl->SetBackupSucceeded(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName,bSucceeded)
#define IVssBackupComponentsEx_SetBackupOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszBackupOptions) (This)->lpVtbl->SetBackupOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszBackupOptions)
#define IVssBackupComponentsEx_SetSelectedForRestore(This,writerId,componentType,wszLogicalPath,wszComponentName,bSelectedForRestore) (This)->lpVtbl->SetSelectedForRestore(This,writerId,componentType,wszLogicalPath,wszComponentName,bSelectedForRestore)
#define IVssBackupComponentsEx_SetRestoreOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszRestoreOptions) (This)->lpVtbl->SetRestoreOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszRestoreOptions)
#define IVssBackupComponentsEx_SetAdditionalRestores(This,writerId,componentType,wszLogicalPath,wszComponentName,bAdditionalResources) (This)->lpVtbl->SetAdditionalRestores(This,writerId,componentType,wszLogicalPath,wszComponentName,bAdditionalResources)
#define IVssBackupComponentsEx_SetPreviousBackupStamp(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPreviousBackupStamp) (This)->lpVtbl->SetPreviousBackupStamp(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPreviousBackupStamp)
#define IVssBackupComponentsEx_SaveAsXML(This,pbstrXML) (This)->lpVtbl->SaveAsXML(This,pbstrXML)
#define IVssBackupComponentsEx_BackupComplete(This,ppAsync) (This)->lpVtbl->BackupComplete(This,ppAsync)
#define IVssBackupComponentsEx_AddAlternativeLocationMapping(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPath,wszFilespec,bRecursive,wszDestination) (This)->lpVtbl->AddAlternativeLocationMapping(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPath,wszFilespec,bRecursive,wszDestination)
#define IVssBackupComponentsEx_AddRestoreSubcomponent(This,writerId,componentType,wszLogicalPath,wszComponentName,wszSubComponentLogicalPath,wszSubComponentName,bRepair) (This)->lpVtbl->AddRestoreSubcomponent(This,writerId,componentType,wszLogicalPath,wszComponentName,wszSubComponentLogicalPath,wszSubComponentName,bRepair)
#define IVssBackupComponentsEx_SetFileRestoreStatus(This,writerId,componentType,wszLogicalPath,wszComponentName,status) (This)->lpVtbl->SetFileRestoreStatus(This,writerId,componentType,wszLogicalPath,wszComponentName,status)
#define IVssBackupComponentsEx_AddNewTarget(This,writerId,ct,wszLogicalPath,wszComponentName,wszPath,wszFileName,bRecursive,wszAlternatePath) (This)->lpVtbl->AddNewTarget(This,writerId,ct,wszLogicalPath,wszComponentName,wszPath,wszFileName,bRecursive,wszAlternatePath)
#define IVssBackupComponentsEx_SetRangesFilePath(This,writerId,ct,wszLogicalPath,wszComponentName,iPartialFile,wszRangesFile) (This)->lpVtbl->SetRangesFilePath(This,writerId,ct,wszLogicalPath,wszComponentName,iPartialFile,wszRangesFile)
#define IVssBackupComponentsEx_PreRestore(This,ppAsync) (This)->lpVtbl->PreRestore(This,ppAsync)
#define IVssBackupComponentsEx_PostRestore(This,ppAsync) (This)->lpVtbl->PostRestore(This,ppAsync)
#define IVssBackupComponentsEx_SetContext(This,lContext) (This)->lpVtbl->SetContext(This,lContext)
#define IVssBackupComponentsEx_StartSnapshotSet(This,pSnapshotSetId) (This)->lpVtbl->StartSnapshotSet(This,pSnapshotSetId)
#define IVssBackupComponentsEx_AddToSnapshotSet(This,pwszVolumeName,ProviderId,pidSnapshot) (This)->lpVtbl->AddToSnapshotSet(This,pwszVolumeName,ProviderId,pidSnapshot)
#define IVssBackupComponentsEx_DoSnapshotSet(This,ppAsync) (This)->lpVtbl->DoSnapshotSet(This,ppAsync)
#define IVssBackupComponentsEx_DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID) (This)->lpVtbl->DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID)
#define IVssBackupComponentsEx_ImportSnapshots(This,ppAsync) (This)->lpVtbl->ImportSnapshots(This,ppAsync)
#define IVssBackupComponentsEx_BreakSnapshotSet(This,SnapshotSetId) (This)->lpVtbl->BreakSnapshotSet(This,SnapshotSetId)
#define IVssBackupComponentsEx_GetSnapshotProperties(This,SnapshotId,pProp) (This)->lpVtbl->GetSnapshotProperties(This,SnapshotId,pProp)
#define IVssBackupComponentsEx_Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum) (This)->lpVtbl->Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum)
#define IVssBackupComponentsEx_IsVolumeSupported(This,ProviderId,pwszVolumeName,pbSupportedByThisProvider) (This)->lpVtbl->IsVolumeSupported(This,ProviderId,pwszVolumeName,pbSupportedByThisProvider)
#define IVssBackupComponentsEx_DisableWriterClasses(This,rgWriterClassId,cClassId) (This)->lpVtbl->DisableWriterClasses(This,rgWriterClassId,cClassId)
#define IVssBackupComponentsEx_EnableWriterClasses(This,rgWriterClassId,cClassId) (This)->lpVtbl->EnableWriterClasses(This,rgWriterClassId,cClassId)
#define IVssBackupComponentsEx_DisableWriterInstances(This,rgWriterInstanceId,cInstanceId) (This)->lpVtbl->DisableWriterInstances(This,rgWriterInstanceId,cInstanceId)
#define IVssBackupComponentsEx_ExposeSnapshot(This,SnapshotId,wszPathFromRoot,lAttributes,wszExpose,pwszExposed) (This)->lpVtbl->ExposeSnapshot(This,SnapshotId,wszPathFromRoot,lAttributes,wszExpose,pwszExposed)
#define IVssBackupComponentsEx_RevertToSnapshot(This,SnapshotId,bForceDismount) (This)->lpVtbl->RevertToSnapshot(This,SnapshotId,bForceDismount)
#define IVssBackupComponentsEx_QueryRevertStatus(This,pwszVolume,ppAsync) (This)->lpVtbl->QueryRevertStatus(This,pwszVolume,ppAsync)
#define IVssBackupComponentsEx_GetWriterMetadataEx(This,iWriter,pidInstance,ppMetadata) (This)->lpVtbl->GetWriterMetadataEx(This,iWriter,pidInstance,ppMetadata)
#define IVssBackupComponentsEx_SetSelectedForRestoreEx(This,writerId,ct,wszLogicalPath,wszComponentName,bSelectedForRestore,instanceId) (This)->lpVtbl->SetSelectedForRestoreEx(This,writerId,ct,wszLogicalPath,wszComponentName,bSelectedForRestore,instanceId)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssBackupComponentsEx2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssBackupComponentsEx2,IVssBackupComponentsEx)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssBackupComponents methods */
    STDMETHOD_(HRESULT,GetWriterComponentsCount)(THIS_ UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetWriterComponents)(THIS_ UINT iWriter,IVssWriterComponentsExt **pWriterComponents) PURE;
    STDMETHOD_(HRESULT,InitializeForBackup)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetBackupState)(THIS_ BOOLEAN bSelectComponents,BOOLEAN bBackupBootableSystemState,VSS_BACKUP_TYPE backupType,BOOLEAN bPartialFileSupport) PURE;
    STDMETHOD_(HRESULT,InitializeForRestore)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetRestoreState)(THIS_ VSS_RESTORE_TYPE restoreType) PURE;
    STDMETHOD_(HRESULT,GatherWriterMetadata)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadataCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadata)(THIS_ UINT iWriter,VSS_ID *pidWriterInstance,IVssExamineWriterMetadata **ppMetadata) PURE;
    STDMETHOD_(HRESULT,FreeWriterMetadata)(THIS) PURE;
    STDMETHOD_(HRESULT,AddComponent)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName) PURE;
    STDMETHOD_(HRESULT,PrepareForBackup)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AbortBackup)(THIS) PURE;
    STDMETHOD_(HRESULT,GatherWriterStatus)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterStatusCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,FreeWriterStatus)(THIS) PURE;
    STDMETHOD_(HRESULT,GetWriterStatus)(THIS_ UINT iWriter,VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriter,VSS_WRITER_STATE *pState,HRESULT *pHrResultFailure) PURE;
    STDMETHOD_(HRESULT,SetBackupSucceeded)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSucceeded) PURE;
    STDMETHOD_(HRESULT,SetBackupOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszBackupOptions) PURE;
    STDMETHOD_(HRESULT,SetSelectedForRestore)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSelectedForRestore) PURE;
    STDMETHOD_(HRESULT,SetRestoreOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszRestoreOptions) PURE;
    STDMETHOD_(HRESULT,SetAdditionalRestores)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bAdditionalResources) PURE;
    STDMETHOD_(HRESULT,SetPreviousBackupStamp)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPreviousBackupStamp) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,BackupComplete)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AddAlternativeLocationMapping)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszDestination) PURE;
    STDMETHOD_(HRESULT,AddRestoreSubcomponent)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszSubComponentLogicalPath,LPCWSTR wszSubComponentName,BOOLEAN bRepair) PURE;
    STDMETHOD_(HRESULT,SetFileRestoreStatus)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,VSS_FILE_RESTORE_STATUS status) PURE;
    STDMETHOD_(HRESULT,AddNewTarget)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFileName,BOOLEAN bRecursive,LPCWSTR wszAlternatePath) PURE;
    STDMETHOD_(HRESULT,SetRangesFilePath)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,UINT iPartialFile,LPCWSTR wszRangesFile) PURE;
    STDMETHOD_(HRESULT,PreRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,PostRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,SetContext)(THIS_ LONG lContext) PURE;
    STDMETHOD_(HRESULT,StartSnapshotSet)(THIS_ VSS_ID *pSnapshotSetId) PURE;
    STDMETHOD_(HRESULT,AddToSnapshotSet)(THIS_ VSS_PWSZ pwszVolumeName,VSS_ID ProviderId,VSS_ID *pidSnapshot) PURE;
    STDMETHOD_(HRESULT,DoSnapshotSet)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,DeleteSnapshots)(THIS_ VSS_ID SourceObjectId,VSS_OBJECT_TYPE eSourceObjectType,BOOLEAN bForceDelete,LONG *plDeletedSnapshots,VSS_ID *pNondeletedSnapshotID) PURE;
    STDMETHOD_(HRESULT,ImportSnapshots)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,BreakSnapshotSet)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,GetSnapshotProperties)(THIS_ VSS_ID SnapshotId,VSS_SNAPSHOT_PROP *pProp) PURE;
    STDMETHOD_(HRESULT,Query)(THIS_ VSS_ID QueriedObjectId,VSS_OBJECT_TYPE eQueriedObjectType,VSS_OBJECT_TYPE eReturnedObjectsType,IVssEnumObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,IsVolumeSupported)(THIS_ VSS_ID ProviderId,VSS_PWSZ pwszVolumeName,BOOLEAN *pbSupportedByThisProvider) PURE;
    STDMETHOD_(HRESULT,DisableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,EnableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,DisableWriterInstances)(THIS_ const VSS_ID *rgWriterInstanceId,UINT cInstanceId) PURE;
    STDMETHOD_(HRESULT,ExposeSnapshot)(THIS_ VSS_ID SnapshotId,VSS_PWSZ wszPathFromRoot,LONG lAttributes,VSS_PWSZ wszExpose,VSS_PWSZ *pwszExposed) PURE;
    STDMETHOD_(HRESULT,RevertToSnapshot)(THIS_ VSS_ID SnapshotId,BOOLEAN bForceDismount) PURE;
    STDMETHOD_(HRESULT,QueryRevertStatus)(THIS_ VSS_PWSZ pwszVolume,IVssAsync **ppAsync) PURE;

    /* IVssBackupComponentsEx methods */
    STDMETHOD_(HRESULT,GetWriterMetadataEx)(THIS_ UINT iWriter,VSS_ID *pidInstance,IVssExamineWriterMetadataEx **ppMetadata) PURE;
    STDMETHOD_(HRESULT,SetSelectedForRestoreEx)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSelectedForRestore,VSS_ID instanceId) PURE;

    /* IVssBackupComponentsEx2 methods */
    STDMETHOD_(HRESULT,UnexposeSnapshot)(THIS_ VSS_ID snapshotId) PURE;
    STDMETHOD_(HRESULT,SetAuthoritativeRestore)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bAuth) PURE;
    STDMETHOD_(HRESULT,SetRollForward)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,VSS_ROLLFORWARD_TYPE rollType,LPCWSTR wszRollForwardPoint) PURE;
    STDMETHOD_(HRESULT,SetRestoreName)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszRestoreName) PURE;
    STDMETHOD_(HRESULT,BreakSnapshotSetEx)(THIS_ VSS_ID SnapshotSetID,DWORD dwBreakFlags,IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,PreFastRecovery)(THIS) PURE; /*Unsupported*/
    STDMETHOD_(HRESULT,FastRecovery)(THIS) PURE;    /*Unsupported*/

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssBackupComponentsEx2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssBackupComponentsEx2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssBackupComponentsEx2_Release(This) (This)->lpVtbl->Release(This)
#define IVssBackupComponentsEx2_GetWriterComponentsCount(This,pcComponents) (This)->lpVtbl->GetWriterComponentsCount(This,pcComponents)
#define IVssBackupComponentsEx2_GetWriterComponents(This,iWriter,pWriterComponents) (This)->lpVtbl->GetWriterComponents(This,iWriter,pWriterComponents)
#define IVssBackupComponentsEx2_InitializeForBackup(This,bstrXML) (This)->lpVtbl->InitializeForBackup(This,bstrXML)
#define IVssBackupComponentsEx2_SetBackupState(This,bSelectComponents,bBackupBootableSystemState,backupType,bPartialFileSupport) (This)->lpVtbl->SetBackupState(This,bSelectComponents,bBackupBootableSystemState,backupType,bPartialFileSupport)
#define IVssBackupComponentsEx2_InitializeForRestore(This,bstrXML) (This)->lpVtbl->InitializeForRestore(This,bstrXML)
#define IVssBackupComponentsEx2_SetRestoreState(This,restoreType) (This)->lpVtbl->SetRestoreState(This,restoreType)
#define IVssBackupComponentsEx2_GatherWriterMetadata(This,ppAsync) (This)->lpVtbl->GatherWriterMetadata(This,ppAsync)
#define IVssBackupComponentsEx2_GetWriterMetadataCount(This,pcWriters) (This)->lpVtbl->GetWriterMetadataCount(This,pcWriters)
#define IVssBackupComponentsEx2_GetWriterMetadata(This,iWriter,pidWriterInstance,ppMetadata) (This)->lpVtbl->GetWriterMetadata(This,iWriter,pidWriterInstance,ppMetadata)
#define IVssBackupComponentsEx2_FreeWriterMetadata() (This)->lpVtbl->FreeWriterMetadata(This)
#define IVssBackupComponentsEx2_AddComponent(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName) (This)->lpVtbl->AddComponent(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName)
#define IVssBackupComponentsEx2_PrepareForBackup(This,ppAsync) (This)->lpVtbl->PrepareForBackup(This,ppAsync)
#define IVssBackupComponentsEx2_AbortBackup() (This)->lpVtbl->AbortBackup(This)
#define IVssBackupComponentsEx2_GatherWriterStatus(This,ppAsync) (This)->lpVtbl->GatherWriterStatus(This,ppAsync)
#define IVssBackupComponentsEx2_GetWriterStatusCount(This,pcWriters) (This)->lpVtbl->GetWriterStatusCount(This,pcWriters)
#define IVssBackupComponentsEx2_FreeWriterStatus() (This)->lpVtbl->FreeWriterStatus(This)
#define IVssBackupComponentsEx2_GetWriterStatus(This,iWriter,pidInstance,pidWriter,pbstrWriter,pState,pHrResultFailure) (This)->lpVtbl->GetWriterStatus(This,iWriter,pidInstance,pidWriter,pbstrWriter,pState,pHrResultFailure)
#define IVssBackupComponentsEx2_SetBackupSucceeded(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName,bSucceeded) (This)->lpVtbl->SetBackupSucceeded(This,instanceId,writerId,componentType,wszLogicalPath,wszComponentName,bSucceeded)
#define IVssBackupComponentsEx2_SetBackupOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszBackupOptions) (This)->lpVtbl->SetBackupOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszBackupOptions)
#define IVssBackupComponentsEx2_SetSelectedForRestore(This,writerId,componentType,wszLogicalPath,wszComponentName,bSelectedForRestore) (This)->lpVtbl->SetSelectedForRestore(This,writerId,componentType,wszLogicalPath,wszComponentName,bSelectedForRestore)
#define IVssBackupComponentsEx2_SetRestoreOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszRestoreOptions) (This)->lpVtbl->SetRestoreOptions(This,writerId,componentType,wszLogicalPath,wszComponentName,wszRestoreOptions)
#define IVssBackupComponentsEx2_SetAdditionalRestores(This,writerId,componentType,wszLogicalPath,wszComponentName,bAdditionalResources) (This)->lpVtbl->SetAdditionalRestores(This,writerId,componentType,wszLogicalPath,wszComponentName,bAdditionalResources)
#define IVssBackupComponentsEx2_SetPreviousBackupStamp(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPreviousBackupStamp) (This)->lpVtbl->SetPreviousBackupStamp(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPreviousBackupStamp)
#define IVssBackupComponentsEx2_SaveAsXML(This,pbstrXML) (This)->lpVtbl->SaveAsXML(This,pbstrXML)
#define IVssBackupComponentsEx2_BackupComplete(This,ppAsync) (This)->lpVtbl->BackupComplete(This,ppAsync)
#define IVssBackupComponentsEx2_AddAlternativeLocationMapping(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPath,wszFilespec,bRecursive,wszDestination) (This)->lpVtbl->AddAlternativeLocationMapping(This,writerId,componentType,wszLogicalPath,wszComponentName,wszPath,wszFilespec,bRecursive,wszDestination)
#define IVssBackupComponentsEx2_AddRestoreSubcomponent(This,writerId,componentType,wszLogicalPath,wszComponentName,wszSubComponentLogicalPath,wszSubComponentName,bRepair) (This)->lpVtbl->AddRestoreSubcomponent(This,writerId,componentType,wszLogicalPath,wszComponentName,wszSubComponentLogicalPath,wszSubComponentName,bRepair)
#define IVssBackupComponentsEx2_SetFileRestoreStatus(This,writerId,componentType,wszLogicalPath,wszComponentName,status) (This)->lpVtbl->SetFileRestoreStatus(This,writerId,componentType,wszLogicalPath,wszComponentName,status)
#define IVssBackupComponentsEx2_AddNewTarget(This,writerId,ct,wszLogicalPath,wszComponentName,wszPath,wszFileName,bRecursive,wszAlternatePath) (This)->lpVtbl->AddNewTarget(This,writerId,ct,wszLogicalPath,wszComponentName,wszPath,wszFileName,bRecursive,wszAlternatePath)
#define IVssBackupComponentsEx2_SetRangesFilePath(This,writerId,ct,wszLogicalPath,wszComponentName,iPartialFile,wszRangesFile) (This)->lpVtbl->SetRangesFilePath(This,writerId,ct,wszLogicalPath,wszComponentName,iPartialFile,wszRangesFile)
#define IVssBackupComponentsEx2_PreRestore(This,ppAsync) (This)->lpVtbl->PreRestore(This,ppAsync)
#define IVssBackupComponentsEx2_PostRestore(This,ppAsync) (This)->lpVtbl->PostRestore(This,ppAsync)
#define IVssBackupComponentsEx2_SetContext(This,lContext) (This)->lpVtbl->SetContext(This,lContext)
#define IVssBackupComponentsEx2_StartSnapshotSet(This,pSnapshotSetId) (This)->lpVtbl->StartSnapshotSet(This,pSnapshotSetId)
#define IVssBackupComponentsEx2_AddToSnapshotSet(This,pwszVolumeName,ProviderId,pidSnapshot) (This)->lpVtbl->AddToSnapshotSet(This,pwszVolumeName,ProviderId,pidSnapshot)
#define IVssBackupComponentsEx2_DoSnapshotSet(This,ppAsync) (This)->lpVtbl->DoSnapshotSet(This,ppAsync)
#define IVssBackupComponentsEx2_DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID) (This)->lpVtbl->DeleteSnapshots(This,SourceObjectId,eSourceObjectType,bForceDelete,plDeletedSnapshots,pNondeletedSnapshotID)
#define IVssBackupComponentsEx2_ImportSnapshots(This,ppAsync) (This)->lpVtbl->ImportSnapshots(This,ppAsync)
#define IVssBackupComponentsEx2_BreakSnapshotSet(This,SnapshotSetId) (This)->lpVtbl->BreakSnapshotSet(This,SnapshotSetId)
#define IVssBackupComponentsEx2_GetSnapshotProperties(This,SnapshotId,pProp) (This)->lpVtbl->GetSnapshotProperties(This,SnapshotId,pProp)
#define IVssBackupComponentsEx2_Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum) (This)->lpVtbl->Query(This,QueriedObjectId,eQueriedObjectType,eReturnedObjectsType,ppEnum)
#define IVssBackupComponentsEx2_IsVolumeSupported(This,ProviderId,pwszVolumeName,pbSupportedByThisProvider) (This)->lpVtbl->IsVolumeSupported(This,ProviderId,pwszVolumeName,pbSupportedByThisProvider)
#define IVssBackupComponentsEx2_DisableWriterClasses(This,rgWriterClassId,cClassId) (This)->lpVtbl->DisableWriterClasses(This,rgWriterClassId,cClassId)
#define IVssBackupComponentsEx2_EnableWriterClasses(This,rgWriterClassId,cClassId) (This)->lpVtbl->EnableWriterClasses(This,rgWriterClassId,cClassId)
#define IVssBackupComponentsEx2_DisableWriterInstances(This,rgWriterInstanceId,cInstanceId) (This)->lpVtbl->DisableWriterInstances(This,rgWriterInstanceId,cInstanceId)
#define IVssBackupComponentsEx2_ExposeSnapshot(This,SnapshotId,wszPathFromRoot,lAttributes,wszExpose,pwszExposed) (This)->lpVtbl->ExposeSnapshot(This,SnapshotId,wszPathFromRoot,lAttributes,wszExpose,pwszExposed)
#define IVssBackupComponentsEx2_RevertToSnapshot(This,SnapshotId,bForceDismount) (This)->lpVtbl->RevertToSnapshot(This,SnapshotId,bForceDismount)
#define IVssBackupComponentsEx2_QueryRevertStatus(This,pwszVolume,ppAsync) (This)->lpVtbl->QueryRevertStatus(This,pwszVolume,ppAsync)
#define IVssBackupComponentsEx2_GetWriterMetadataEx(This,iWriter,pidInstance,ppMetadata) (This)->lpVtbl->GetWriterMetadataEx(This,iWriter,pidInstance,ppMetadata)
#define IVssBackupComponentsEx2_SetSelectedForRestoreEx(This,writerId,ct,wszLogicalPath,wszComponentName,bSelectedForRestore,instanceId) (This)->lpVtbl->SetSelectedForRestoreEx(This,writerId,ct,wszLogicalPath,wszComponentName,bSelectedForRestore,instanceId)
#define IVssBackupComponentsEx2_UnexposeSnapshot(This,snapshotId) (This)->lpVtbl->UnexposeSnapshot(This,snapshotId)
#define IVssBackupComponentsEx2_SetAuthoritativeRestore(This,writerId,ct,wszLogicalPath,wszComponentName,bAuth) (This)->lpVtbl->SetAuthoritativeRestore(This,writerId,ct,wszLogicalPath,wszComponentName,bAuth)
#define IVssBackupComponentsEx2_SetRollForward(This,writerId,ct,wszLogicalPath,wszComponentName,rollType,wszRollForwardPoint) (This)->lpVtbl->SetRollForward(This,writerId,ct,wszLogicalPath,wszComponentName,rollType,wszRollForwardPoint)
#define IVssBackupComponentsEx2_SetRestoreName(This,writerId,ct,wszLogicalPath,wszComponentName,wszRestoreName) (This)->lpVtbl->SetRestoreName(This,writerId,ct,wszLogicalPath,wszComponentName,wszRestoreName)
#define IVssBackupComponentsEx2_BreakSnapshotSetEx(This,SnapshotSetID,dwBreakFlags,ppAsync) (This)->lpVtbl->BreakSnapshotSetEx(This,SnapshotSetID,dwBreakFlags,ppAsync)
#define IVssBackupComponentsEx2_PreFastRecovery() (This)->lpVtbl->PreFastRecovery(This)
#define IVssBackupComponentsEx2_FastRecovery() (This)->lpVtbl->FastRecovery(This)
#endif /*COBJMACROS*/
#endif /*(_WIN32_WINNT >= 0x0600)*/

#if (_WIN32_WINNT >= 0x0601)
#undef  INTERFACE
#define INTERFACE IVssBackupComponentsEx3
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssBackupComponentsEx3,IVssBackupComponentsEx2)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssBackupComponents methods */
    STDMETHOD_(HRESULT,GetWriterComponentsCount)(THIS_ UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetWriterComponents)(THIS_ UINT iWriter,IVssWriterComponentsExt **pWriterComponents) PURE;
    STDMETHOD_(HRESULT,InitializeForBackup)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetBackupState)(THIS_ BOOLEAN bSelectComponents,BOOLEAN bBackupBootableSystemState,VSS_BACKUP_TYPE backupType,BOOLEAN bPartialFileSupport) PURE;
    STDMETHOD_(HRESULT,InitializeForRestore)(THIS_ BSTR bstrXML) PURE;
    STDMETHOD_(HRESULT,SetRestoreState)(THIS_ VSS_RESTORE_TYPE restoreType) PURE;
    STDMETHOD_(HRESULT,GatherWriterMetadata)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadataCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,GetWriterMetadata)(THIS_ UINT iWriter,VSS_ID *pidWriterInstance,IVssExamineWriterMetadata **ppMetadata) PURE;
    STDMETHOD_(HRESULT,FreeWriterMetadata)(THIS) PURE;
    STDMETHOD_(HRESULT,AddComponent)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName) PURE;
    STDMETHOD_(HRESULT,PrepareForBackup)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AbortBackup)(THIS) PURE;
    STDMETHOD_(HRESULT,GatherWriterStatus)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,GetWriterStatusCount)(THIS_ UINT *pcWriters) PURE;
    STDMETHOD_(HRESULT,FreeWriterStatus)(THIS) PURE;
    STDMETHOD_(HRESULT,GetWriterStatus)(THIS_ UINT iWriter,VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriter,VSS_WRITER_STATE *pState,HRESULT *pHrResultFailure) PURE;
    STDMETHOD_(HRESULT,SetBackupSucceeded)(THIS_ VSS_ID instanceId,VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSucceeded) PURE;
    STDMETHOD_(HRESULT,SetBackupOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszBackupOptions) PURE;
    STDMETHOD_(HRESULT,SetSelectedForRestore)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSelectedForRestore) PURE;
    STDMETHOD_(HRESULT,SetRestoreOptions)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszRestoreOptions) PURE;
    STDMETHOD_(HRESULT,SetAdditionalRestores)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bAdditionalResources) PURE;
    STDMETHOD_(HRESULT,SetPreviousBackupStamp)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPreviousBackupStamp) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,BackupComplete)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,AddAlternativeLocationMapping)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszDestination) PURE;
    STDMETHOD_(HRESULT,AddRestoreSubcomponent)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszSubComponentLogicalPath,LPCWSTR wszSubComponentName,BOOLEAN bRepair) PURE;
    STDMETHOD_(HRESULT,SetFileRestoreStatus)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,VSS_FILE_RESTORE_STATUS status) PURE;
    STDMETHOD_(HRESULT,AddNewTarget)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszPath,LPCWSTR wszFileName,BOOLEAN bRecursive,LPCWSTR wszAlternatePath) PURE;
    STDMETHOD_(HRESULT,SetRangesFilePath)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,UINT iPartialFile,LPCWSTR wszRangesFile) PURE;
    STDMETHOD_(HRESULT,PreRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,PostRestore)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,SetContext)(THIS_ LONG lContext) PURE;
    STDMETHOD_(HRESULT,StartSnapshotSet)(THIS_ VSS_ID *pSnapshotSetId) PURE;
    STDMETHOD_(HRESULT,AddToSnapshotSet)(THIS_ VSS_PWSZ pwszVolumeName,VSS_ID ProviderId,VSS_ID *pidSnapshot) PURE;
    STDMETHOD_(HRESULT,DoSnapshotSet)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,DeleteSnapshots)(THIS_ VSS_ID SourceObjectId,VSS_OBJECT_TYPE eSourceObjectType,BOOLEAN bForceDelete,LONG *plDeletedSnapshots,VSS_ID *pNondeletedSnapshotID) PURE;
    STDMETHOD_(HRESULT,ImportSnapshots)(THIS_ IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,BreakSnapshotSet)(THIS_ VSS_ID SnapshotSetId) PURE;
    STDMETHOD_(HRESULT,GetSnapshotProperties)(THIS_ VSS_ID SnapshotId,VSS_SNAPSHOT_PROP *pProp) PURE;
    STDMETHOD_(HRESULT,Query)(THIS_ VSS_ID QueriedObjectId,VSS_OBJECT_TYPE eQueriedObjectType,VSS_OBJECT_TYPE eReturnedObjectsType,IVssEnumObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,IsVolumeSupported)(THIS_ VSS_ID ProviderId,VSS_PWSZ pwszVolumeName,BOOLEAN *pbSupportedByThisProvider) PURE;
    STDMETHOD_(HRESULT,DisableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,EnableWriterClasses)(THIS_ const VSS_ID *rgWriterClassId,UINT cClassId) PURE;
    STDMETHOD_(HRESULT,DisableWriterInstances)(THIS_ const VSS_ID *rgWriterInstanceId,UINT cInstanceId) PURE;
    STDMETHOD_(HRESULT,ExposeSnapshot)(THIS_ VSS_ID SnapshotId,VSS_PWSZ wszPathFromRoot,LONG lAttributes,VSS_PWSZ wszExpose,VSS_PWSZ *pwszExposed) PURE;
    STDMETHOD_(HRESULT,RevertToSnapshot)(THIS_ VSS_ID SnapshotId,BOOLEAN bForceDismount) PURE;
    STDMETHOD_(HRESULT,QueryRevertStatus)(THIS_ VSS_PWSZ pwszVolume,IVssAsync **ppAsync) PURE;

    /* IVssBackupComponentsEx methods */
    STDMETHOD_(HRESULT,GetWriterMetadataEx)(THIS_ UINT iWriter,VSS_ID *pidInstance,IVssExamineWriterMetadataEx **ppMetadata) PURE;
    STDMETHOD_(HRESULT,SetSelectedForRestoreEx)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bSelectedForRestore,VSS_ID instanceId) PURE;

    /* IVssBackupComponentsEx2 methods */
    STDMETHOD_(HRESULT,UnexposeSnapshot)(THIS_ VSS_ID snapshotId) PURE;
    STDMETHOD_(HRESULT,SetAuthoritativeRestore)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,BOOLEAN bAuth) PURE;
    STDMETHOD_(HRESULT,SetRollForward)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,VSS_ROLLFORWARD_TYPE rollType,LPCWSTR wszRollForwardPoint) PURE;
    STDMETHOD_(HRESULT,SetRestoreName)(THIS_ VSS_ID writerId,VSS_COMPONENT_TYPE ct,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszRestoreName) PURE;
    STDMETHOD_(HRESULT,BreakSnapshotSetEx)(THIS_ VSS_ID SnapshotSetID,DWORD dwBreakFlags,IVssAsync **ppAsync) PURE;
    STDMETHOD_(HRESULT,PreFastRecovery)(THIS) PURE; /*Unsupported*/
    STDMETHOD_(HRESULT,FastRecovery)(THIS) PURE;    /*Unsupported*/

    /* IVssBackupComponentsEx3 methods */
    STDMETHOD_(HRESULT,AddSnapshotToRecoverySet)(THIS_ VSS_ID snapshotId,DWORD dwFlags,VSS_PWSZ pwszDestinationVolume) PURE;
    STDMETHOD_(HRESULT,GetSessionId)(THIS_ VSS_ID *idSession) PURE;
    STDMETHOD_(HRESULT,GetWriterStatusEx)(THIS_ UINT iWriter,VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriter,VSS_WRITER_STATE *pnStatus,HRESULT *phrFailureWriter,BSTR *pbstrApplicationMessage) PURE;
    STDMETHOD_(HRESULT,RecoverSet)(THIS_ DWORD dwFlags,IVssAsync **ppAsync) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssBackupComponentsEx3_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssBackupComponentsEx3_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssBackupComponentsEx3_Release(This) (This)->lpVtbl->Release(This)
#define IVssBackupComponentsEx3_AddSnapshotToRecoverySet(This,snapshotId,dwFlags,pwszDestinationVolume) (This)->lpVtbl->AddSnapshotToRecoverySet(This,snapshotId,dwFlags,pwszDestinationVolume)
#define IVssBackupComponentsEx3_GetSessionId(This,idSession) (This)->lpVtbl->GetSessionId(This,idSession)
#define IVssBackupComponentsEx3_GetWriterStatusEx(This,iWriter,pidInstance,pidWriter,pbstrWriter,pnStatus,phrFailureWriter,pbstrApplicationMessage) (This)->lpVtbl->GetWriterStatusEx(This,iWriter,pidInstance,pidWriter,pbstrWriter,pnStatus,phrFailureWriter,pbstrApplicationMessage)
#define IVssBackupComponentsEx3_RecoverSet(This,dwFlags,ppAsync) (This)->lpVtbl->RecoverSet(This,dwFlags,ppAsync)
#endif /*COBJMACROS*/
#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
/* Is a C++ interface instead of a COM */
#undef  INTERFACE
#define INTERFACE IVssExamineWriterMetadata
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssExamineWriterMetadata,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssExamineWriterMetadata methods */
    STDMETHOD_(HRESULT,GetIdentity)(THIS_ VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriterName,VSS_USAGE_TYPE *pUsage,VSS_SOURCE_TYPE *pSource) PURE;
    STDMETHOD_(HRESULT,GetFileCounts)(THIS_ UINT *pcIncludeFiles,UINT *pcExcludeFiles,UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetIncludeFile)(THIS) PURE;
    STDMETHOD_(HRESULT,GetExcludeFile)(THIS_ UINT iFile,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,GetComponent)(THIS_ UINT iComponent,IVssWMComponent **ppComponent) PURE;
    STDMETHOD_(HRESULT,GetRestoreMethod)(THIS_ VSS_RESTOREMETHOD_ENUM *pMethod,BSTR *pbstrService,BSTR *pbstrUserProcedure,VSS_WRITERRESTORE_ENUM *pwreWriterRestore,BOOLEAN *pbRebootRequired,UINT *piMappings) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMapping)(THIS_ UINT iMapping,IVssWMFiledesc **ppMapping) PURE;
    STDMETHOD_(HRESULT,GetBackupSchema)(THIS_ DWORD *pdsSchemaMask) PURE;
    STDMETHOD_(HRESULT,GetDocument)(THIS) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,LoadFromXML)(THIS_ BSTR bstrXML) PURE;

    END_INTERFACE
};

#if (_WIN32_WINNT >= 0x0600)
#undef  INTERFACE
#define INTERFACE IVssExamineWriterMetadataEx
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssExamineWriterMetadataEx,IVssExamineWriterMetadata)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssExamineWriterMetadata methods */
    STDMETHOD_(HRESULT,GetIdentity)(THIS_ VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriterName,VSS_USAGE_TYPE *pUsage,VSS_SOURCE_TYPE *pSource) PURE;
    STDMETHOD_(HRESULT,GetFileCounts)(THIS_ UINT *pcIncludeFiles,UINT *pcExcludeFiles,UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetIncludeFile)(THIS) PURE;
    STDMETHOD_(HRESULT,GetExcludeFile)(THIS_ UINT iFile,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,GetComponent)(THIS_ UINT iComponent,IVssWMComponent **ppComponent) PURE;
    STDMETHOD_(HRESULT,GetRestoreMethod)(THIS_ VSS_RESTOREMETHOD_ENUM *pMethod,BSTR *pbstrService,BSTR *pbstrUserProcedure,VSS_WRITERRESTORE_ENUM *pwreWriterRestore,BOOLEAN *pbRebootRequired,UINT *piMappings) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMapping)(THIS_ UINT iMapping,IVssWMFiledesc **ppMapping) PURE;
    STDMETHOD_(HRESULT,GetBackupSchema)(THIS_ DWORD *pdsSchemaMask) PURE;
    STDMETHOD_(HRESULT,GetDocument)(THIS) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,LoadFromXML)(THIS_ BSTR bstrXML) PURE;

    /* IVssExamineWriterMetadataEx methods */
    STDMETHOD_(HRESULT,GetIdentityEx)(THIS_ VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriterName,BSTR *pbstrInstanceName,VSS_USAGE_TYPE *pUsage,VSS_SOURCE_TYPE *pSource) PURE;

    END_INTERFACE
};

#undef  INTERFACE
#define INTERFACE IVssExamineWriterMetadataEx2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssExamineWriterMetadataEx2,IVssExamineWriterMetadataEx)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

/* IVssExamineWriterMetadata methods */
    STDMETHOD_(HRESULT,GetIdentity)(THIS_ VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriterName,VSS_USAGE_TYPE *pUsage,VSS_SOURCE_TYPE *pSource) PURE;
    STDMETHOD_(HRESULT,GetFileCounts)(THIS_ UINT *pcIncludeFiles,UINT *pcExcludeFiles,UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetIncludeFile)(THIS) PURE;
    STDMETHOD_(HRESULT,GetExcludeFile)(THIS_ UINT iFile,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,GetComponent)(THIS_ UINT iComponent,IVssWMComponent **ppComponent) PURE;
    STDMETHOD_(HRESULT,GetRestoreMethod)(THIS_ VSS_RESTOREMETHOD_ENUM *pMethod,BSTR *pbstrService,BSTR *pbstrUserProcedure,VSS_WRITERRESTORE_ENUM *pwreWriterRestore,BOOLEAN *pbRebootRequired,UINT *piMappings) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMapping)(THIS_ UINT iMapping,IVssWMFiledesc **ppMapping) PURE;
    STDMETHOD_(HRESULT,GetBackupSchema)(THIS_ DWORD *pdsSchemaMask) PURE;
    STDMETHOD_(HRESULT,GetDocument)(THIS) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,LoadFromXML)(THIS_ BSTR bstrXML) PURE;

    /* IVssExamineWriterMetadataEx methods */
    STDMETHOD_(HRESULT,GetIdentityEx)(THIS_ VSS_ID *pidInstance,VSS_ID *pidWriter,BSTR *pbstrWriterName,BSTR *pbstrInstanceName,VSS_USAGE_TYPE *pUsage,VSS_SOURCE_TYPE *pSource) PURE;

    /* IVssExamineWriterMetadataEx2 methods */
    STDMETHOD_(HRESULT,GetVersion)(THIS_ DWORD *pdwMajorVersion,DWORD *pdwMinorVersion) PURE;
    STDMETHOD_(HRESULT,GetExcludeFromSnapshotCount)(THIS_ UINT *pcExcludedFromSnapshot) PURE;
    STDMETHOD_(HRESULT,GetExcludeFromSnapshotFile)(THIS_ UINT iFile,IVssWMFiledesc **ppFiledesc) PURE;

    END_INTERFACE
};

#endif /*(_WIN32_WINNT >= 0x0600)*/

#undef  INTERFACE
#define INTERFACE IVssWMComponent
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssWMComponent,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssWMComponent methods */
    STDMETHOD_(HRESULT,GetComponentInfo)(THIS_ PVSSCOMPONENTINFO *ppInfo) PURE;
    STDMETHOD_(HRESULT,FreeComponentInfo)(THIS_ VSS_COMPONENTINFO *pInfo) PURE;
    STDMETHOD_(HRESULT,GetFile)(THIS_ UINT iFile,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,GetDatabaseFile)(THIS_ UINT iFile,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,GetDatabaseLogFile)(THIS_ UINT iFile,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,GetDependency)(THIS_ UINT iDependency,IVssWMDependency **ppDependency) PURE;

    END_INTERFACE
};

#undef  INTERFACE
#define INTERFACE IVssWriterComponentsExt
DECLARE_INTERFACE_(IVssWriterComponentsExt,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssWriterComponentsExt methods */
    /* No additional members */

    END_INTERFACE
};

#endif /*__cplusplus*/
#endif /*_INC_VSBACKUP*/
