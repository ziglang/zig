/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VSWRITER
#define _INC_VSWRITER

  typedef enum VSS_COMPONENT_FLAGS {
    VSS_CF_BACKUP_RECOVERY         = 0x00000001,
    VSS_CF_APP_ROLLBACK_RECOVERY   = 0x00000002,
    VSS_CF_NOT_SYSTEM_STATE        = 0x00000004 
  } VSS_COMPONENT_FLAGS;

  /* http://msdn.microsoft.com/en-us/library/aa384976%28v=VS.85%29.aspx */
  typedef enum VSS_USAGE_TYPE {
    VSS_UT_UNDEFINED             = 0,
    VSS_UT_BOOTABLESYSTEMSTATE   = 1,
    VSS_UT_SYSTEMSERVICE         = 2,
    VSS_UT_USERDATA              = 3,
    VSS_UT_OTHER                 = 4 
  } VSS_USAGE_TYPE;

typedef enum VSS_ALTERNATE_WRITER_STATE {
  VSS_AWS_UNDEFINED                  = 0,
  VSS_AWS_NO_ALTERNATE_WRITER        = 1,
  VSS_AWS_ALTERNATE_WRITER_EXISTS    = 2,
  VSS_AWS_THIS_IS_ALTERNATE_WRITER   = 3 
} VSS_ALTERNATE_WRITER_STATE;

typedef enum VSS_COMPONENT_TYPE {
  VSS_CT_UNDEFINED   = 0,
  VSS_CT_DATABASE    = 1,
  VSS_CT_FILEGROUP   = 2 
} VSS_COMPONENT_TYPE;

typedef enum VSS_FILE_RESTORE_STATUS {
  VSS_RS_UNDEFINED   = 0,
  VSS_RS_NONE        = 1,
  VSS_RS_ALL         = 2,
  VSS_RS_FAILED      = 3 
} VSS_FILE_RESTORE_STATUS;

typedef enum VSS_RESTORE_TARGET {
  VSS_RT_UNDEFINED           = 0,
  VSS_RT_ORIGINAL            = 1,
  VSS_RT_ALTERNATE           = 2,
  VSS_RT_DIRECTED            = 3,
  VSS_RT_ORIGINAL_LOCATION   = 4 
} VSS_RESTORE_TARGET;

typedef enum VSS_RESTOREMETHOD_ENUM {
  VSS_RME_UNDEFINED                             = 0,
  VSS_RME_RESTORE_IF_NOT_THERE                  = 1,
  VSS_RME_RESTORE_IF_CAN_REPLACE                = 2,
  VSS_RME_STOP_RESTORE_START                    = 3,
  VSS_RME_RESTORE_TO_ALTERNATE_LOCATION         = 4,
  VSS_RME_RESTORE_AT_REBOOT                     = 5,
  VSS_RME_RESTORE_AT_REBOOT_IF_CANNOT_REPLACE   = 6,
  VSS_RME_CUSTOM                                = 7,
  VSS_RME_RESTORE_STOP_START                    = 8 
} VSS_RESTOREMETHOD_ENUM;

typedef enum VSS_SOURCE_TYPE {
  VSS_ST_UNDEFINED         = 0,
  VSS_ST_TRANSACTEDDB      = 1,
  VSS_ST_NONTRANSACTEDDB   = 2,
  VSS_ST_OTHER             = 3 
} VSS_SOURCE_TYPE;

typedef enum VSS_SUBSCRIBE_MASK {
  VSS_SM_POST_SNAPSHOT_FLAG    = 0x00000001,
  VSS_SM_BACKUP_EVENTS_FLAG    = 0x00000002,
  VSS_SM_RESTORE_EVENTS_FLAG   = 0x00000004,
  VSS_SM_IO_THROTTLING_FLAG    = 0x00000008,
  VSS_SM_ALL_FLAGS             = 0xffffffff 
} VSS_SUBSCRIBE_MASK;

typedef enum VSS_WRITERRESTORE_ENUM {
  VSS_WRE_UNDEFINED          = 0,
  VSS_WRE_NEVER              = 1,
  VSS_WRE_IF_REPLACE_FAILS   = 2,
  VSS_WRE_ALWAYS             = 3 
} VSS_WRITERRESTORE_ENUM;

#include <vss.h>

#if (_WIN32_WINNT >= 0x601)
HRESULT WINAPI CreateVssExpressWriterInternal(
  IVssExpressWriter **ppWriter
);

FORCEINLINE
HRESULT WINAPI CreateVssExpressWriter(
  IVssExpressWriter **ppWriter
){return CreateVssExpressWriterInternal(ppWriter);}

#undef  INTERFACE
#define INTERFACE IVssCreateExpressWriterMetadata
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssCreateExpressWriterMetadata,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssCreateExpressWriterMetadata methods */
    STDMETHOD_(HRESULT,AddComponent)(THIS_ VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszCaption,const BYTE *pbIcon,UINT cbIcon,BOOLEAN bRestoreMetadata,BOOLEAN bNotifyOnBackupComplete,BOOLEAN bSelectable,BOOLEAN bSelectableForRestore,DWORD dwComponentFlags) PURE;
    STDMETHOD_(HRESULT,AddComponentDependency)(THIS_ LPCWSTR wszForLogicalPath,LPCWSTR wszForComponentName,VSS_ID onWriterId,LPCWSTR wszOnLogicalPath,LPCWSTR wszOnComponentName) PURE;
    STDMETHOD_(HRESULT,AddExcludeFiles)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,SetBackupSchema)(THIS_ DWORD dsSchemaMask) PURE;
    STDMETHOD_(HRESULT,SetRestoreMethod)(THIS_ VSS_RESTOREMETHOD_ENUM method,LPCWSTR wszService,LPCWSTR wszUserProcedure,VSS_WRITERRESTORE_ENUM wreWriterRestore,BOOLEAN bRebootRequired) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssCreateExpressWriterMetadata_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssCreateExpressWriterMetadata_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssCreateExpressWriterMetadata_Release(This) (This)->lpVtbl->Release(This)
#define IVssCreateExpressWriterMetadata_AddComponent(This,componentType,wszLogicalPath,wszComponentName,wszCaption,pbIcon,cbIcon,bRestoreMetadata,bNotifyOnBackupComplete,bSelectable,bSelectableForRestore,dwComponentFlags) (This)->lpVtbl->AddComponent(This,componentType,wszLogicalPath,wszComponentName,wszCaption,pbIcon,cbIcon,bRestoreMetadata,bNotifyOnBackupComplete,bSelectable,bSelectableForRestore,dwComponentFlags)
#define IVssCreateExpressWriterMetadata_AddFilesToFileGroup(This,wszLogicalPath,wszGroupName,wszPath,wszFilespec,bRecursive,wszAlternateLocation,dwBackupTypeMask) (This)->lpVtbl->AddFilesToFileGroup(This,wszLogicalPath,wszGroupName,wszPath,wszFilespec,bRecursive,wszAlternateLocation,dwBackupTypeMask)
#define IVssCreateExpressWriterMetadata_SaveAsXML(This,pbstrXML) (This)->lpVtbl->SaveAsXML(This,pbstrXML)
#define IVssCreateExpressWriterMetadata_SetBackupSchema(This,dsSchemaMask) (This)->lpVtbl->SetBackupSchema(This,dsSchemaMask)
#define IVssCreateExpressWriterMetadata_SetRestoreMethod(This,method,wszService,wszUserProcedure,wreWriterRestore,bRebootRequired) (This)->lpVtbl->SetRestoreMethod(This,method,wszService,wszUserProcedure,wreWriterRestore,bRebootRequired)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x601)*/

#ifdef __cplusplus
/* Is a C++ interface instead of a COM */
#undef  INTERFACE
#define INTERFACE IVssCreateWriterMetadata
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssCreateWriterMetadata,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssCreateWriterMetadata methods */
    STDMETHOD_(HRESULT,AddAlternateLocationMapping)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszDestination) PURE;
    STDMETHOD_(HRESULT,AddComponent)(THIS_ VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszCaption,const BYTE *pbIcon,UINT cbIcon,BOOLEAN bRestoreMetadata,BOOLEAN bNotifyOnBackupComplete,BOOLEAN bSelectable,BOOLEAN bSelectableForRestore,DWORD dwComponentFlags) PURE;
    STDMETHOD_(HRESULT,AddComponentDependency)(THIS_ LPCWSTR wszForLogicalPath,LPCWSTR wszForComponentName,VSS_ID onWriterId,LPCWSTR wszOnLogicalPath,LPCWSTR wszOnComponentName) PURE;
    STDMETHOD_(HRESULT,AddDatabaseFiles)(THIS_ LPCWSTR wszLogicalPath,LPCWSTR wszDatabaseName,LPCWSTR wszPath,LPCWSTR wszFilespec,DWORD dwBackupTypeMask) PURE;
    STDMETHOD_(HRESULT,AddDatabaseLogFiles)(THIS_ LPCWSTR wszLogicalPath,LPCWSTR wszDatabaseName,LPCWSTR wszPath,LPCWSTR wszFilespec,DWORD dwBackupTypeMask) PURE;
    STDMETHOD_(HRESULT,AddExcludeFiles)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive) PURE;
    STDMETHOD_(HRESULT,AddFilesToFileGroup)(THIS_ LPCWSTR wszLogicalPath,LPCWSTR wszGroupName,LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszAlternatePath,DWORD dwBackupTypeMask) PURE;
    STDMETHOD_(HRESULT,AddIncludeFiles)(THIS) PURE;
    STDMETHOD_(HRESULT,GetDocument)(THIS) PURE;
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,SetBackupSchema)(THIS_ DWORD dsSchemaMask) PURE;
    STDMETHOD_(HRESULT,SetRestoreMethod)(THIS_ VSS_RESTOREMETHOD_ENUM method,LPCWSTR wszService,LPCWSTR wszUserProcedure,VSS_WRITERRESTORE_ENUM wreWriterRestore,BOOLEAN bRebootRequired) PURE;

    END_INTERFACE
};

#if (_WIN32_WINNT >= 0x600)
#undef  INTERFACE
#define INTERFACE IVssCreateWriterMetadataEx
DECLARE_INTERFACE_(IVssCreateWriterMetadataEx,IVssCreateWriterMetadata)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssCreateWriterMetadata methods */
    STDMETHOD_(HRESULT,AddAlternateLocationMapping)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszDestination) PURE;
    STDMETHOD_(HRESULT,AddComponent)(THIS_ VSS_COMPONENT_TYPE componentType,LPCWSTR wszLogicalPath,LPCWSTR wszComponentName,LPCWSTR wszCaption,const BYTE *pbIcon,UINT cbIcon,BOOLEAN bRestoreMetadata,BOOLEAN bNotifyOnBackupComplete,BOOLEAN bSelectable,BOOLEAN bSelectableForRestore,DWORD dwComponentFlags) PURE;
    STDMETHOD_(HRESULT,AddComponentDependency)(THIS_ LPCWSTR wszForLogicalPath,LPCWSTR wszForComponentName,VSS_ID onWriterId,LPCWSTR wszOnLogicalPath,LPCWSTR wszOnComponentName) PURE;
    STDMETHOD_(HRESULT,AddDatabaseFiles)(THIS_ LPCWSTR wszLogicalPath,LPCWSTR wszDatabaseName,LPCWSTR wszPath,LPCWSTR wszFilespec,DWORD dwBackupTypeMask) PURE;
    STDMETHOD_(HRESULT,AddDatabaseLogFiles)(THIS_ LPCWSTR wszLogicalPath,LPCWSTR wszDatabaseName,LPCWSTR wszPath,LPCWSTR wszFilespec,DWORD dwBackupTypeMask) PURE;
    STDMETHOD_(HRESULT,AddExcludeFiles)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive) PURE;
    STDMETHOD_(HRESULT,AddFilesToFileGroup)(THIS_ LPCWSTR wszLogicalPath,LPCWSTR wszGroupName,LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive,LPCWSTR wszAlternatePath,DWORD dwBackupTypeMask) PURE;
    STDMETHOD_(HRESULT,AddIncludeFiles)(THIS) PURE; /*Not supported*/
    STDMETHOD_(HRESULT,GetDocument)(THIS) PURE;     /*Not supported*/
    STDMETHOD_(HRESULT,SaveAsXML)(THIS_ BSTR *pbstrXML) PURE;
    STDMETHOD_(HRESULT,SetBackupSchema)(THIS_ DWORD dsSchemaMask) PURE;
    STDMETHOD_(HRESULT,SetRestoreMethod)(THIS_ VSS_RESTOREMETHOD_ENUM method,LPCWSTR wszService,LPCWSTR wszUserProcedure,VSS_WRITERRESTORE_ENUM wreWriterRestore,BOOLEAN bRebootRequired) PURE;

    /* IVssCreateWriterMetadataEx methods */
    STDMETHOD_(HRESULT,AddExcludeFilesFromSnapshot)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,BOOLEAN bRecursive) PURE;

    END_INTERFACE
};
#endif /*(_WIN32_WINNT >= 0x600)*/
#endif /*__cplusplus*/

#if (_WIN32_WINNT >= 0x601)
#undef  INTERFACE
#define INTERFACE IVssExpressWriter
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssExpressWriter,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssExpressWriter methods */
    STDMETHOD_(HRESULT,CreateMetadata)(THIS_ VSS_ID writerId,LPCWSTR writerName,VSS_USAGE_TYPE usageType,DWORD versionMajor,DWORD versionMinor,DWORD reserved,IVssCreateWriterMetadataEx **ppMetadata) PURE;
    STDMETHOD_(HRESULT,Load)(THIS_ LPCWSTR metadata,DWORD reserved) PURE;
    STDMETHOD_(HRESULT,Register)(THIS) PURE;
    STDMETHOD_(HRESULT,Unregister)(THIS_ VSS_ID writerId) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssExpressWriter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssExpressWriter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssExpressWriter_Release(This) (This)->lpVtbl->Release(This)
#define IVssExpressWriter_CreateMetadata(This,writerId,writerName,usageType,versionMajor,versionMinor,reserved,ppMetadata) (This)->lpVtbl->CreateMetadata(This,writerId,writerName,usageType,versionMajor,versionMinor,reserved,ppMetadata)
#define IVssExpressWriter_Load(This,metadata,reserved) (This)->lpVtbl->Load(This,metadata,reserved)
#define IVssExpressWriter_Register() (This)->lpVtbl->Register(This)
#define IVssExpressWriter_Unregister(This,writerId) (This)->lpVtbl->Unregister(This,writerId)
#endif /*COBJMACROS*/
#endif /*(_WIN32_WINNT >= 0x601)*/

#ifdef __cplusplus
/* Is a C++ interface instead of a COM */
#undef  INTERFACE
#define INTERFACE IVssWriterComponents
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssWriterComponents,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssWriterComponents methods */
    STDMETHOD_(HRESULT,GetComponent)(THIS_ UINT iComponent,IVssComponent **ppComponent) PURE;
    STDMETHOD_(HRESULT,GetComponentCount)(THIS_ UINT *pcComponents) PURE;
    STDMETHOD_(HRESULT,GetWriterInfo)(THIS_ VSS_ID *pidInstance,VSS_ID *pidWriter) PURE;

    END_INTERFACE
};
#endif /*__cplusplus*/

#undef  INTERFACE
#define INTERFACE IVssComponent
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssComponent,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssComponent methods */
    STDMETHOD_(HRESULT,GetLogicalPath)(THIS_ BSTR *pbstrPath) PURE;
    STDMETHOD_(HRESULT,GetComponentType)(THIS_ VSS_COMPONENT_TYPE *pType) PURE;
    STDMETHOD_(HRESULT,GetComponentName)(THIS_ BSTR *pwszName) PURE;
    STDMETHOD_(HRESULT,GetBackupSucceeded)(THIS_ BOOLEAN *pbSucceeded) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMappingCount)(THIS_ UINT *pcMappings) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMapping)(THIS_ UINT iMapping,const IVssWMFiledesc **ppMapping) PURE;
    STDMETHOD_(HRESULT,SetBackupMetadata)(THIS_ BSTR bstrMetadata) PURE;
    STDMETHOD_(HRESULT,GetBackupMetadata)(THIS_ BSTR *pbstrMetadata) PURE;
    STDMETHOD_(HRESULT,AddPartialFile)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilename,LPCWSTR wszRanges,LPCWSTR wszMetadata) PURE;
    STDMETHOD_(HRESULT,GetPartialFileCount)(THIS_ UINT *pcPartialFiles) PURE;
    STDMETHOD_(HRESULT,GetPartialFile)(THIS_ UINT iPartialFile,BSTR *pbstrPath,BSTR *pbstrFilename,BSTR *pbstrRange,BSTR *pbstrMetadata) PURE;
    STDMETHOD_(HRESULT,IsSelectedForRestore)(THIS_ BOOLEAN *pbSelectedForRestore) PURE;
    STDMETHOD_(HRESULT,GetAdditionalRestores)(THIS_ BOOLEAN *pbAdditionalRestores) PURE;
    STDMETHOD_(HRESULT,GetNewTargetCount)(THIS_ UINT *pcNewTarget) PURE;
    STDMETHOD_(HRESULT,GetNewTarget)(THIS_ UINT iMapping,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,AddDirectedTarget)(THIS_ LPCWSTR wszSourcePath,LPCWSTR wszSourceFilename,LPCWSTR wszSourceRangeList,LPCWSTR wszDestinationPath,LPCWSTR wszDestinationFilename,LPCWSTR wszDestinationRangeList) PURE;
    STDMETHOD_(HRESULT,GetDirectedTargetCount)(THIS_ UINT *pcDirectedTarget) PURE;
    STDMETHOD_(HRESULT,GetDirectedTarget)(THIS_ UINT iDirectedTarget,BSTR *pbstrSourcePath,BSTR *pbstrSourceFileName,BSTR *pbstrSourceRangeList,BSTR *pbstrDestinationPath,BSTR *pbstrDestinationFilename,BSTR *pbstrDestinationRangeList) PURE;
    STDMETHOD_(HRESULT,SetRestoreMetadata)(THIS_ LPCWSTR wszRestoreMetadata) PURE;
    STDMETHOD_(HRESULT,GetRestoreMetadata)(THIS_ BSTR *pbstrRestoreMetadata) PURE;
    STDMETHOD_(HRESULT,SetRestoreTarget)(THIS_ VSS_RESTORE_TARGET target) PURE;
    STDMETHOD_(HRESULT,GetRestoreTarget)(THIS_ VSS_RESTORE_TARGET *pTarget) PURE;
    STDMETHOD_(HRESULT,SetPreRestoreFailureMsg)(THIS_ LPCWSTR wszPreRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPreRestoreFailureMsg)(THIS_ BSTR *pbstrPreRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetPostRestoreFailureMsg)(THIS_ LPCWSTR wszPostRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPostRestoreFailureMsg)(THIS_ BSTR *pbstrPostRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetBackupStamp)(THIS_ LPCWSTR wszBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetBackupStamp)(THIS_ BSTR *pbstrBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetPreviousBackupStamp)(THIS_ BSTR *pbstrBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetBackupOptions)(THIS_ BSTR *pbstrBackupOptions) PURE;
    STDMETHOD_(HRESULT,GetRestoreOptions)(THIS_ BSTR *pbstrRestoreOptions) PURE;
    STDMETHOD_(HRESULT,GetRestoreSubcomponentCount)(THIS_ UINT *pcRestoreSubcomponent) PURE;
    STDMETHOD_(HRESULT,GetRestoreSubcomponent)(THIS_ UINT iComponent,BSTR *pbstrLogicalPath,BSTR *pbstrComponentName,BOOLEAN *pbRepair) PURE;
    STDMETHOD_(HRESULT,GetFileRestoreStatus)(THIS_ VSS_FILE_RESTORE_STATUS *pStatus) PURE;
    STDMETHOD_(HRESULT,AddDifferencedFilesByLastModifyTime)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,WINBOOL bRecursive,FILETIME ftLastModifyTime) PURE;
    STDMETHOD_(HRESULT,AddDifferencedFilesByLastModifyLSN)(THIS) PURE;
    STDMETHOD_(HRESULT,GetDifferencedFilesCount)(THIS_ UINT *pcDifferencedFiles) PURE;
    STDMETHOD_(HRESULT,GetDifferencedFile)(THIS_ UINT iDifferencedFile,BSTR *pbstrPath,BSTR *pbstrFilespec,WINBOOL *pbRecursive,BSTR *pbstrLsnString,FILETIME *pftLastModifyTime) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssComponent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssComponent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssComponent_Release(This) (This)->lpVtbl->Release(This)
#define IVssComponent_GetLogicalPath(This,pbstrPath) (This)->lpVtbl->GetLogicalPath(This,pbstrPath)
#define IVssComponent_GetComponentType(This,pType) (This)->lpVtbl->GetComponentType(This,pType)
#define IVssComponent_GetComponentName(This,pwszName) (This)->lpVtbl->GetComponentName(This,pwszName)
#define IVssComponent_GetBackupSucceeded(This,pbSucceeded) (This)->lpVtbl->GetBackupSucceeded(This,pbSucceeded)
#define IVssComponent_GetAlternateLocationMappingCount(This,pcMappings) (This)->lpVtbl->GetAlternateLocationMappingCount(This,pcMappings)
#define IVssComponent_GetAlternateLocationMapping(This,iMapping,ppMapping) (This)->lpVtbl->GetAlternateLocationMapping(This,iMapping,ppMapping)
#define IVssComponent_SetBackupMetadata(This,bstrMetadata) (This)->lpVtbl->SetBackupMetadata(This,bstrMetadata)
#define IVssComponent_GetBackupMetadata(This,pbstrMetadata) (This)->lpVtbl->GetBackupMetadata(This,pbstrMetadata)
#define IVssComponent_AddPartialFile(This,wszPath,wszFilename,wszRanges,wszMetadata) (This)->lpVtbl->AddPartialFile(This,wszPath,wszFilename,wszRanges,wszMetadata)
#define IVssComponent_GetPartialFileCount(This,pcPartialFiles) (This)->lpVtbl->GetPartialFileCount(This,pcPartialFiles)
#define IVssComponent_GetPartialFile(This,iPartialFile,pbstrPath,pbstrFilename,pbstrRange,pbstrMetadata) (This)->lpVtbl->GetPartialFile(This,iPartialFile,pbstrPath,pbstrFilename,pbstrRange,pbstrMetadata)
#define IVssComponent_IsSelectedForRestore(This,pbSelectedForRestore) (This)->lpVtbl->IsSelectedForRestore(This,pbSelectedForRestore)
#define IVssComponent_GetAdditionalRestores(This,pbAdditionalRestores) (This)->lpVtbl->GetAdditionalRestores(This,pbAdditionalRestores)
#define IVssComponent_GetNewTargetCount(This,pcNewTarget) (This)->lpVtbl->GetNewTargetCount(This,pcNewTarget)
#define IVssComponent_GetNewTarget(This,iMapping,ppFiledesc) (This)->lpVtbl->GetNewTarget(This,iMapping,ppFiledesc)
#define IVssComponent_AddDirectedTarget(This,wszSourcePath,wszSourceFilename,wszSourceRangeList,wszDestinationPath,wszDestinationFilename,wszDestinationRangeList) (This)->lpVtbl->AddDirectedTarget(This,wszSourcePath,wszSourceFilename,wszSourceRangeList,wszDestinationPath,wszDestinationFilename,wszDestinationRangeList)
#define IVssComponent_GetDirectedTargetCount(This,pcDirectedTarget) (This)->lpVtbl->GetDirectedTargetCount(This,pcDirectedTarget)
#define IVssComponent_GetDirectedTarget(This,iDirectedTarget,pbstrSourcePath,pbstrSourceFileName,pbstrSourceRangeList,pbstrDestinationPath,pbstrDestinationFilename,pbstrDestinationRangeList) (This)->lpVtbl->GetDirectedTarget(This,iDirectedTarget,pbstrSourcePath,pbstrSourceFileName,pbstrSourceRangeList,pbstrDestinationPath,pbstrDestinationFilename,pbstrDestinationRangeList)
#define IVssComponent_SetRestoreMetadata(This,wszRestoreMetadata) (This)->lpVtbl->SetRestoreMetadata(This,wszRestoreMetadata)
#define IVssComponent_GetRestoreMetadata(This,pbstrRestoreMetadata) (This)->lpVtbl->GetRestoreMetadata(This,pbstrRestoreMetadata)
#define IVssComponent_SetRestoreTarget(This,target) (This)->lpVtbl->SetRestoreTarget(This,target)
#define IVssComponent_GetRestoreTarget(This,pTarget) (This)->lpVtbl->GetRestoreTarget(This,pTarget)
#define IVssComponent_SetPreRestoreFailureMsg(This,wszPreRestoreFailureMsg) (This)->lpVtbl->SetPreRestoreFailureMsg(This,wszPreRestoreFailureMsg)
#define IVssComponent_GetPreRestoreFailureMsg(This,pbstrPreRestoreFailureMsg) (This)->lpVtbl->GetPreRestoreFailureMsg(This,pbstrPreRestoreFailureMsg)
#define IVssComponent_SetPostRestoreFailureMsg(This,wszPostRestoreFailureMsg) (This)->lpVtbl->SetPostRestoreFailureMsg(This,wszPostRestoreFailureMsg)
#define IVssComponent_GetPostRestoreFailureMsg(This,pbstrPostRestoreFailureMsg) (This)->lpVtbl->GetPostRestoreFailureMsg(This,pbstrPostRestoreFailureMsg)
#define IVssComponent_SetBackupStamp(This,wszBackupStamp) (This)->lpVtbl->SetBackupStamp(This,wszBackupStamp)
#define IVssComponent_GetBackupStamp(This,pbstrBackupStamp) (This)->lpVtbl->GetBackupStamp(This,pbstrBackupStamp)
#define IVssComponent_GetPreviousBackupStamp(This,pbstrBackupStamp) (This)->lpVtbl->GetPreviousBackupStamp(This,pbstrBackupStamp)
#define IVssComponent_GetBackupOptions(This,pbstrBackupOptions) (This)->lpVtbl->GetBackupOptions(This,pbstrBackupOptions)
#define IVssComponent_GetRestoreOptions(This,pbstrRestoreOptions) (This)->lpVtbl->GetRestoreOptions(This,pbstrRestoreOptions)
#define IVssComponent_GetRestoreSubcomponentCount(This,pcRestoreSubcomponent) (This)->lpVtbl->GetRestoreSubcomponentCount(This,pcRestoreSubcomponent)
#define IVssComponent_GetRestoreSubcomponent(This,iComponent,pbstrLogicalPath,pbstrComponentName,pbRepair) (This)->lpVtbl->GetRestoreSubcomponent(This,iComponent,pbstrLogicalPath,pbstrComponentName,pbRepair)
#define IVssComponent_GetFileRestoreStatus(This,pStatus) (This)->lpVtbl->GetFileRestoreStatus(This,pStatus)
#define IVssComponent_AddDifferencedFilesByLastModifyTime(This,wszPath,wszFilespec,bRecursive,ftLastModifyTime) (This)->lpVtbl->AddDifferencedFilesByLastModifyTime(This,wszPath,wszFilespec,bRecursive,ftLastModifyTime)
#define IVssComponent_AddDifferencedFilesByLastModifyLSN() (This)->lpVtbl->AddDifferencedFilesByLastModifyLSN(This)
#define IVssComponent_GetDifferencedFilesCount(This,pcDifferencedFiles) (This)->lpVtbl->GetDifferencedFilesCount(This,pcDifferencedFiles)
#define IVssComponent_GetDifferencedFile(This,iDifferencedFile,pbstrPath,pbstrFilespec,pbRecursive,pbstrLsnString,pftLastModifyTime) (This)->lpVtbl->GetDifferencedFile(This,iDifferencedFile,pbstrPath,pbstrFilespec,pbRecursive,pbstrLsnString,pftLastModifyTime)
#endif /*COBJMACROS*/

#if (_WIN32_WINNT >= 0x600)
#undef  INTERFACE
#define INTERFACE IVssComponentEx
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssComponentEx,IVssComponent)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssComponent methods */
    STDMETHOD_(HRESULT,GetLogicalPath)(THIS_ BSTR *pbstrPath) PURE;
    STDMETHOD_(HRESULT,GetComponentType)(THIS_ VSS_COMPONENT_TYPE *pType) PURE;
    STDMETHOD_(HRESULT,GetComponentName)(THIS_ BSTR *pwszName) PURE;
    STDMETHOD_(HRESULT,GetBackupSucceeded)(THIS_ BOOLEAN *pbSucceeded) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMappingCount)(THIS_ UINT *pcMappings) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMapping)(THIS_ UINT iMapping,const IVssWMFiledesc **ppMapping) PURE;
    STDMETHOD_(HRESULT,SetBackupMetadata)(THIS_ BSTR bstrMetadata) PURE;
    STDMETHOD_(HRESULT,GetBackupMetadata)(THIS_ BSTR *pbstrMetadata) PURE;
    STDMETHOD_(HRESULT,AddPartialFile)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilename,LPCWSTR wszRanges,LPCWSTR wszMetadata) PURE;
    STDMETHOD_(HRESULT,GetPartialFileCount)(THIS_ UINT *pcPartialFiles) PURE;
    STDMETHOD_(HRESULT,GetPartialFile)(THIS_ UINT iPartialFile,BSTR *pbstrPath,BSTR *pbstrFilename,BSTR *pbstrRange,BSTR *pbstrMetadata) PURE;
    STDMETHOD_(HRESULT,IsSelectedForRestore)(THIS_ BOOLEAN *pbSelectedForRestore) PURE;
    STDMETHOD_(HRESULT,GetAdditionalRestores)(THIS_ BOOLEAN *pbAdditionalRestores) PURE;
    STDMETHOD_(HRESULT,GetNewTargetCount)(THIS_ UINT *pcNewTarget) PURE;
    STDMETHOD_(HRESULT,GetNewTarget)(THIS_ UINT iMapping,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,AddDirectedTarget)(THIS_ LPCWSTR wszSourcePath,LPCWSTR wszSourceFilename,LPCWSTR wszSourceRangeList,LPCWSTR wszDestinationPath,LPCWSTR wszDestinationFilename,LPCWSTR wszDestinationRangeList) PURE;
    STDMETHOD_(HRESULT,GetDirectedTargetCount)(THIS_ UINT *pcDirectedTarget) PURE;
    STDMETHOD_(HRESULT,GetDirectedTarget)(THIS_ UINT iDirectedTarget,BSTR *pbstrSourcePath,BSTR *pbstrSourceFileName,BSTR *pbstrSourceRangeList,BSTR *pbstrDestinationPath,BSTR *pbstrDestinationFilename,BSTR *pbstrDestinationRangeList) PURE;
    STDMETHOD_(HRESULT,SetRestoreMetadata)(THIS_ LPCWSTR wszRestoreMetadata) PURE;
    STDMETHOD_(HRESULT,GetRestoreMetadata)(THIS_ BSTR *pbstrRestoreMetadata) PURE;
    STDMETHOD_(HRESULT,SetRestoreTarget)(THIS_ VSS_RESTORE_TARGET target) PURE;
    STDMETHOD_(HRESULT,GetRestoreTarget)(THIS_ VSS_RESTORE_TARGET *pTarget) PURE;
    STDMETHOD_(HRESULT,SetPreRestoreFailureMsg)(THIS_ LPCWSTR wszPreRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPreRestoreFailureMsg)(THIS_ BSTR *pbstrPreRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetPostRestoreFailureMsg)(THIS_ LPCWSTR wszPostRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPostRestoreFailureMsg)(THIS_ BSTR *pbstrPostRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetBackupStamp)(THIS_ LPCWSTR wszBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetBackupStamp)(THIS_ BSTR *pbstrBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetPreviousBackupStamp)(THIS_ BSTR *pbstrBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetBackupOptions)(THIS_ BSTR *pbstrBackupOptions) PURE;
    STDMETHOD_(HRESULT,GetRestoreOptions)(THIS_ BSTR *pbstrRestoreOptions) PURE;
    STDMETHOD_(HRESULT,GetRestoreSubcomponentCount)(THIS_ UINT *pcRestoreSubcomponent) PURE;
    STDMETHOD_(HRESULT,GetRestoreSubcomponent)(THIS_ UINT iComponent,BSTR *pbstrLogicalPath,BSTR *pbstrComponentName,BOOLEAN *pbRepair) PURE;
    STDMETHOD_(HRESULT,GetFileRestoreStatus)(THIS_ VSS_FILE_RESTORE_STATUS *pStatus) PURE;
    STDMETHOD_(HRESULT,AddDifferencedFilesByLastModifyTime)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,WINBOOL bRecursive,FILETIME ftLastModifyTime) PURE;
    STDMETHOD_(HRESULT,AddDifferencedFilesByLastModifyLSN)(THIS) PURE;
    STDMETHOD_(HRESULT,GetDifferencedFilesCount)(THIS_ UINT *pcDifferencedFiles) PURE;
    STDMETHOD_(HRESULT,GetDifferencedFile)(THIS_ UINT iDifferencedFile,BSTR *pbstrPath,BSTR *pbstrFilespec,WINBOOL *pbRecursive,BSTR *pbstrLsnString,FILETIME *pftLastModifyTime) PURE;

    /* IVssComponentEx methods */
    STDMETHOD_(HRESULT,SetPrepareForBackupFailureMsg)(THIS_ LPCWSTR wszFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetPostSnapshotFailureMsg)(THIS_ LPCWSTR wszFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPrepareForBackupFailureMsg)(THIS_ BSTR *pbstrFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPostSnapshotFailureMsg)(THIS_ BSTR *pbstrFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetAuthoritativeRestore)(THIS_ BOOLEAN *pbAuth) PURE;
    STDMETHOD_(HRESULT,GetRollForward)(THIS_ VSS_ROLLFORWARD_TYPE *pRollType,BSTR *pbstrPoint) PURE;
    STDMETHOD_(HRESULT,GetRestoreName)(THIS_ BSTR *pbstrName) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssComponentEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssComponentEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssComponentEx_Release(This) (This)->lpVtbl->Release(This)
#define IVssComponentEx_GetLogicalPath(This,pbstrPath) (This)->lpVtbl->GetLogicalPath(This,pbstrPath)
#define IVssComponentEx_GetComponentType(This,pType) (This)->lpVtbl->GetComponentType(This,pType)
#define IVssComponentEx_GetComponentName(This,pwszName) (This)->lpVtbl->GetComponentName(This,pwszName)
#define IVssComponentEx_GetBackupSucceeded(This,pbSucceeded) (This)->lpVtbl->GetBackupSucceeded(This,pbSucceeded)
#define IVssComponentEx_GetAlternateLocationMappingCount(This,pcMappings) (This)->lpVtbl->GetAlternateLocationMappingCount(This,pcMappings)
#define IVssComponentEx_GetAlternateLocationMapping(This,iMapping,ppMapping) (This)->lpVtbl->GetAlternateLocationMapping(This,iMapping,ppMapping)
#define IVssComponentEx_SetBackupMetadata(This,bstrMetadata) (This)->lpVtbl->SetBackupMetadata(This,bstrMetadata)
#define IVssComponentEx_GetBackupMetadata(This,pbstrMetadata) (This)->lpVtbl->GetBackupMetadata(This,pbstrMetadata)
#define IVssComponentEx_AddPartialFile(This,wszPath,wszFilename,wszRanges,wszMetadata) (This)->lpVtbl->AddPartialFile(This,wszPath,wszFilename,wszRanges,wszMetadata)
#define IVssComponentEx_GetPartialFileCount(This,pcPartialFiles) (This)->lpVtbl->GetPartialFileCount(This,pcPartialFiles)
#define IVssComponentEx_GetPartialFile(This,iPartialFile,pbstrPath,pbstrFilename,pbstrRange,pbstrMetadata) (This)->lpVtbl->GetPartialFile(This,iPartialFile,pbstrPath,pbstrFilename,pbstrRange,pbstrMetadata)
#define IVssComponentEx_IsSelectedForRestore(This,pbSelectedForRestore) (This)->lpVtbl->IsSelectedForRestore(This,pbSelectedForRestore)
#define IVssComponentEx_GetAdditionalRestores(This,pbAdditionalRestores) (This)->lpVtbl->GetAdditionalRestores(This,pbAdditionalRestores)
#define IVssComponentEx_GetNewTargetCount(This,pcNewTarget) (This)->lpVtbl->GetNewTargetCount(This,pcNewTarget)
#define IVssComponentEx_GetNewTarget(This,iMapping,ppFiledesc) (This)->lpVtbl->GetNewTarget(This,iMapping,ppFiledesc)
#define IVssComponentEx_AddDirectedTarget(This,wszSourcePath,wszSourceFilename,wszSourceRangeList,wszDestinationPath,wszDestinationFilename,wszDestinationRangeList) (This)->lpVtbl->AddDirectedTarget(This,wszSourcePath,wszSourceFilename,wszSourceRangeList,wszDestinationPath,wszDestinationFilename,wszDestinationRangeList)
#define IVssComponentEx_GetDirectedTargetCount(This,pcDirectedTarget) (This)->lpVtbl->GetDirectedTargetCount(This,pcDirectedTarget)
#define IVssComponentEx_GetDirectedTarget(This,iDirectedTarget,pbstrSourcePath,pbstrSourceFileName,pbstrSourceRangeList,pbstrDestinationPath,pbstrDestinationFilename,pbstrDestinationRangeList) (This)->lpVtbl->GetDirectedTarget(This,iDirectedTarget,pbstrSourcePath,pbstrSourceFileName,pbstrSourceRangeList,pbstrDestinationPath,pbstrDestinationFilename,pbstrDestinationRangeList)
#define IVssComponentEx_SetRestoreMetadata(This,wszRestoreMetadata) (This)->lpVtbl->SetRestoreMetadata(This,wszRestoreMetadata)
#define IVssComponentEx_GetRestoreMetadata(This,pbstrRestoreMetadata) (This)->lpVtbl->GetRestoreMetadata(This,pbstrRestoreMetadata)
#define IVssComponentEx_SetRestoreTarget(This,target) (This)->lpVtbl->SetRestoreTarget(This,target)
#define IVssComponentEx_GetRestoreTarget(This,pTarget) (This)->lpVtbl->GetRestoreTarget(This,pTarget)
#define IVssComponentEx_SetPreRestoreFailureMsg(This,wszPreRestoreFailureMsg) (This)->lpVtbl->SetPreRestoreFailureMsg(This,wszPreRestoreFailureMsg)
#define IVssComponentEx_GetPreRestoreFailureMsg(This,pbstrPreRestoreFailureMsg) (This)->lpVtbl->GetPreRestoreFailureMsg(This,pbstrPreRestoreFailureMsg)
#define IVssComponentEx_SetPostRestoreFailureMsg(This,wszPostRestoreFailureMsg) (This)->lpVtbl->SetPostRestoreFailureMsg(This,wszPostRestoreFailureMsg)
#define IVssComponentEx_GetPostRestoreFailureMsg(This,pbstrPostRestoreFailureMsg) (This)->lpVtbl->GetPostRestoreFailureMsg(This,pbstrPostRestoreFailureMsg)
#define IVssComponentEx_SetBackupStamp(This,wszBackupStamp) (This)->lpVtbl->SetBackupStamp(This,wszBackupStamp)
#define IVssComponentEx_GetBackupStamp(This,pbstrBackupStamp) (This)->lpVtbl->GetBackupStamp(This,pbstrBackupStamp)
#define IVssComponentEx_GetPreviousBackupStamp(This,pbstrBackupStamp) (This)->lpVtbl->GetPreviousBackupStamp(This,pbstrBackupStamp)
#define IVssComponentEx_GetBackupOptions(This,pbstrBackupOptions) (This)->lpVtbl->GetBackupOptions(This,pbstrBackupOptions)
#define IVssComponentEx_GetRestoreOptions(This,pbstrRestoreOptions) (This)->lpVtbl->GetRestoreOptions(This,pbstrRestoreOptions)
#define IVssComponentEx_GetRestoreSubcomponentCount(This,pcRestoreSubcomponent) (This)->lpVtbl->GetRestoreSubcomponentCount(This,pcRestoreSubcomponent)
#define IVssComponentEx_GetRestoreSubcomponent(This,iComponent,pbstrLogicalPath,pbstrComponentName,pbRepair) (This)->lpVtbl->GetRestoreSubcomponent(This,iComponent,pbstrLogicalPath,pbstrComponentName,pbRepair)
#define IVssComponentEx_GetFileRestoreStatus(This,pStatus) (This)->lpVtbl->GetFileRestoreStatus(This,pStatus)
#define IVssComponentEx_AddDifferencedFilesByLastModifyTime(This,wszPath,wszFilespec,bRecursive,ftLastModifyTime) (This)->lpVtbl->AddDifferencedFilesByLastModifyTime(This,wszPath,wszFilespec,bRecursive,ftLastModifyTime)
#define IVssComponentEx_AddDifferencedFilesByLastModifyLSN() (This)->lpVtbl->AddDifferencedFilesByLastModifyLSN(This)
#define IVssComponentEx_GetDifferencedFilesCount(This,pcDifferencedFiles) (This)->lpVtbl->GetDifferencedFilesCount(This,pcDifferencedFiles)
#define IVssComponentEx_GetDifferencedFile(This,iDifferencedFile,pbstrPath,pbstrFilespec,pbRecursive,pbstrLsnString,pftLastModifyTime) (This)->lpVtbl->GetDifferencedFile(This,iDifferencedFile,pbstrPath,pbstrFilespec,pbRecursive,pbstrLsnString,pftLastModifyTime)
#define IVssComponentEx_SetPrepareForBackupFailureMsg(This,wszFailureMsg) (This)->lpVtbl->SetPrepareForBackupFailureMsg(This,wszFailureMsg)
#define IVssComponentEx_SetPostSnapshotFailureMsg(This,wszFailureMsg) (This)->lpVtbl->SetPostSnapshotFailureMsg(This,wszFailureMsg)
#define IVssComponentEx_GetPrepareForBackupFailureMsg(This,pbstrFailureMsg) (This)->lpVtbl->GetPrepareForBackupFailureMsg(This,pbstrFailureMsg)
#define IVssComponentEx_GetPostSnapshotFailureMsg(This,pbstrFailureMsg) (This)->lpVtbl->GetPostSnapshotFailureMsg(This,pbstrFailureMsg)
#define IVssComponentEx_GetAuthoritativeRestore(This,pbAuth) (This)->lpVtbl->GetAuthoritativeRestore(This,pbAuth)
#define IVssComponentEx_GetRollForward(This,pRollType,pbstrPoint) (This)->lpVtbl->GetRollForward(This,pRollType,pbstrPoint)
#define IVssComponentEx_GetRestoreName(This,pbstrName) (This)->lpVtbl->GetRestoreName(This,pbstrName)
#endif /*COBJMACROS*/
#endif /*(_WIN32_WINNT >= 0x600)*/

#if (_WIN32_WINNT >= 0x601)
#undef  INTERFACE
#define INTERFACE IVssComponentEx2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssComponentEx2,IVssComponentEx)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssComponent methods */
    STDMETHOD_(HRESULT,GetLogicalPath)(THIS_ BSTR *pbstrPath) PURE;
    STDMETHOD_(HRESULT,GetComponentType)(THIS_ VSS_COMPONENT_TYPE *pType) PURE;
    STDMETHOD_(HRESULT,GetComponentName)(THIS_ BSTR *pwszName) PURE;
    STDMETHOD_(HRESULT,GetBackupSucceeded)(THIS_ BOOLEAN *pbSucceeded) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMappingCount)(THIS_ UINT *pcMappings) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocationMapping)(THIS_ UINT iMapping,const IVssWMFiledesc **ppMapping) PURE;
    STDMETHOD_(HRESULT,SetBackupMetadata)(THIS_ BSTR bstrMetadata) PURE;
    STDMETHOD_(HRESULT,GetBackupMetadata)(THIS_ BSTR *pbstrMetadata) PURE;
    STDMETHOD_(HRESULT,AddPartialFile)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilename,LPCWSTR wszRanges,LPCWSTR wszMetadata) PURE;
    STDMETHOD_(HRESULT,GetPartialFileCount)(THIS_ UINT *pcPartialFiles) PURE;
    STDMETHOD_(HRESULT,GetPartialFile)(THIS_ UINT iPartialFile,BSTR *pbstrPath,BSTR *pbstrFilename,BSTR *pbstrRange,BSTR *pbstrMetadata) PURE;
    STDMETHOD_(HRESULT,IsSelectedForRestore)(THIS_ BOOLEAN *pbSelectedForRestore) PURE;
    STDMETHOD_(HRESULT,GetAdditionalRestores)(THIS_ BOOLEAN *pbAdditionalRestores) PURE;
    STDMETHOD_(HRESULT,GetNewTargetCount)(THIS_ UINT *pcNewTarget) PURE;
    STDMETHOD_(HRESULT,GetNewTarget)(THIS_ UINT iMapping,IVssWMFiledesc **ppFiledesc) PURE;
    STDMETHOD_(HRESULT,AddDirectedTarget)(THIS_ LPCWSTR wszSourcePath,LPCWSTR wszSourceFilename,LPCWSTR wszSourceRangeList,LPCWSTR wszDestinationPath,LPCWSTR wszDestinationFilename,LPCWSTR wszDestinationRangeList) PURE;
    STDMETHOD_(HRESULT,GetDirectedTargetCount)(THIS_ UINT *pcDirectedTarget) PURE;
    STDMETHOD_(HRESULT,GetDirectedTarget)(THIS_ UINT iDirectedTarget,BSTR *pbstrSourcePath,BSTR *pbstrSourceFileName,BSTR *pbstrSourceRangeList,BSTR *pbstrDestinationPath,BSTR *pbstrDestinationFilename,BSTR *pbstrDestinationRangeList) PURE;
    STDMETHOD_(HRESULT,SetRestoreMetadata)(THIS_ LPCWSTR wszRestoreMetadata) PURE;
    STDMETHOD_(HRESULT,GetRestoreMetadata)(THIS_ BSTR *pbstrRestoreMetadata) PURE;
    STDMETHOD_(HRESULT,SetRestoreTarget)(THIS_ VSS_RESTORE_TARGET target) PURE;
    STDMETHOD_(HRESULT,GetRestoreTarget)(THIS_ VSS_RESTORE_TARGET *pTarget) PURE;
    STDMETHOD_(HRESULT,SetPreRestoreFailureMsg)(THIS_ LPCWSTR wszPreRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPreRestoreFailureMsg)(THIS_ BSTR *pbstrPreRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetPostRestoreFailureMsg)(THIS_ LPCWSTR wszPostRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPostRestoreFailureMsg)(THIS_ BSTR *pbstrPostRestoreFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetBackupStamp)(THIS_ LPCWSTR wszBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetBackupStamp)(THIS_ BSTR *pbstrBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetPreviousBackupStamp)(THIS_ BSTR *pbstrBackupStamp) PURE;
    STDMETHOD_(HRESULT,GetBackupOptions)(THIS_ BSTR *pbstrBackupOptions) PURE;
    STDMETHOD_(HRESULT,GetRestoreOptions)(THIS_ BSTR *pbstrRestoreOptions) PURE;
    STDMETHOD_(HRESULT,GetRestoreSubcomponentCount)(THIS_ UINT *pcRestoreSubcomponent) PURE;
    STDMETHOD_(HRESULT,GetRestoreSubcomponent)(THIS_ UINT iComponent,BSTR *pbstrLogicalPath,BSTR *pbstrComponentName,BOOLEAN *pbRepair) PURE;
    STDMETHOD_(HRESULT,GetFileRestoreStatus)(THIS_ VSS_FILE_RESTORE_STATUS *pStatus) PURE;
    STDMETHOD_(HRESULT,AddDifferencedFilesByLastModifyTime)(THIS_ LPCWSTR wszPath,LPCWSTR wszFilespec,WINBOOL bRecursive,FILETIME ftLastModifyTime) PURE;
    STDMETHOD_(HRESULT,AddDifferencedFilesByLastModifyLSN)(THIS) PURE;
    STDMETHOD_(HRESULT,GetDifferencedFilesCount)(THIS_ UINT *pcDifferencedFiles) PURE;
    STDMETHOD_(HRESULT,GetDifferencedFile)(THIS_ UINT iDifferencedFile,BSTR *pbstrPath,BSTR *pbstrFilespec,WINBOOL *pbRecursive,BSTR *pbstrLsnString,FILETIME *pftLastModifyTime) PURE;

    /* IVssComponentEx methods */
    STDMETHOD_(HRESULT,SetPrepareForBackupFailureMsg)(THIS_ LPCWSTR wszFailureMsg) PURE;
    STDMETHOD_(HRESULT,SetPostSnapshotFailureMsg)(THIS_ LPCWSTR wszFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPrepareForBackupFailureMsg)(THIS_ BSTR *pbstrFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetPostSnapshotFailureMsg)(THIS_ BSTR *pbstrFailureMsg) PURE;
    STDMETHOD_(HRESULT,GetAuthoritativeRestore)(THIS_ BOOLEAN *pbAuth) PURE;
    STDMETHOD_(HRESULT,GetRollForward)(THIS_ VSS_ROLLFORWARD_TYPE *pRollType,BSTR *pbstrPoint) PURE;
    STDMETHOD_(HRESULT,GetRestoreName)(THIS_ BSTR *pbstrName) PURE;

    /* IVssComponentEx2 methods */
    STDMETHOD_(HRESULT,GetFailure)(THIS_ HRESULT *phr,HRESULT *phrApplication,BSTR *pbstrApplicationMessage,DWORD *pdwReserved) PURE;
    STDMETHOD_(HRESULT,SetFailure)(THIS_ HRESULT hr,HRESULT hrApplication,LPCWSTR wszApplicationMessage,DWORD dwReserved) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssComponentEx2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssComponentEx2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssComponentEx2_Release(This) (This)->lpVtbl->Release(This)
#define IVssComponentEx2_GetLogicalPath(This,pbstrPath) (This)->lpVtbl->GetLogicalPath(This,pbstrPath)
#define IVssComponentEx2_GetComponentType(This,pType) (This)->lpVtbl->GetComponentType(This,pType)
#define IVssComponentEx2_GetComponentName(This,pwszName) (This)->lpVtbl->GetComponentName(This,pwszName)
#define IVssComponentEx2_GetBackupSucceeded(This,pbSucceeded) (This)->lpVtbl->GetBackupSucceeded(This,pbSucceeded)
#define IVssComponentEx2_GetAlternateLocationMappingCount(This,pcMappings) (This)->lpVtbl->GetAlternateLocationMappingCount(This,pcMappings)
#define IVssComponentEx2_GetAlternateLocationMapping(This,iMapping,ppMapping) (This)->lpVtbl->GetAlternateLocationMapping(This,iMapping,ppMapping)
#define IVssComponentEx2_SetBackupMetadata(This,bstrMetadata) (This)->lpVtbl->SetBackupMetadata(This,bstrMetadata)
#define IVssComponentEx2_GetBackupMetadata(This,pbstrMetadata) (This)->lpVtbl->GetBackupMetadata(This,pbstrMetadata)
#define IVssComponentEx2_AddPartialFile(This,wszPath,wszFilename,wszRanges,wszMetadata) (This)->lpVtbl->AddPartialFile(This,wszPath,wszFilename,wszRanges,wszMetadata)
#define IVssComponentEx2_GetPartialFileCount(This,pcPartialFiles) (This)->lpVtbl->GetPartialFileCount(This,pcPartialFiles)
#define IVssComponentEx2_GetPartialFile(This,iPartialFile,pbstrPath,pbstrFilename,pbstrRange,pbstrMetadata) (This)->lpVtbl->GetPartialFile(This,iPartialFile,pbstrPath,pbstrFilename,pbstrRange,pbstrMetadata)
#define IVssComponentEx2_IsSelectedForRestore(This,pbSelectedForRestore) (This)->lpVtbl->IsSelectedForRestore(This,pbSelectedForRestore)
#define IVssComponentEx2_GetAdditionalRestores(This,pbAdditionalRestores) (This)->lpVtbl->GetAdditionalRestores(This,pbAdditionalRestores)
#define IVssComponentEx2_GetNewTargetCount(This,pcNewTarget) (This)->lpVtbl->GetNewTargetCount(This,pcNewTarget)
#define IVssComponentEx2_GetNewTarget(This,iMapping,ppFiledesc) (This)->lpVtbl->GetNewTarget(This,iMapping,ppFiledesc)
#define IVssComponentEx2_AddDirectedTarget(This,wszSourcePath,wszSourceFilename,wszSourceRangeList,wszDestinationPath,wszDestinationFilename,wszDestinationRangeList) (This)->lpVtbl->AddDirectedTarget(This,wszSourcePath,wszSourceFilename,wszSourceRangeList,wszDestinationPath,wszDestinationFilename,wszDestinationRangeList)
#define IVssComponentEx2_GetDirectedTargetCount(This,pcDirectedTarget) (This)->lpVtbl->GetDirectedTargetCount(This,pcDirectedTarget)
#define IVssComponentEx2_GetDirectedTarget(This,iDirectedTarget,pbstrSourcePath,pbstrSourceFileName,pbstrSourceRangeList,pbstrDestinationPath,pbstrDestinationFilename,pbstrDestinationRangeList) (This)->lpVtbl->GetDirectedTarget(This,iDirectedTarget,pbstrSourcePath,pbstrSourceFileName,pbstrSourceRangeList,pbstrDestinationPath,pbstrDestinationFilename,pbstrDestinationRangeList)
#define IVssComponentEx2_SetRestoreMetadata(This,wszRestoreMetadata) (This)->lpVtbl->SetRestoreMetadata(This,wszRestoreMetadata)
#define IVssComponentEx2_GetRestoreMetadata(This,pbstrRestoreMetadata) (This)->lpVtbl->GetRestoreMetadata(This,pbstrRestoreMetadata)
#define IVssComponentEx2_SetRestoreTarget(This,target) (This)->lpVtbl->SetRestoreTarget(This,target)
#define IVssComponentEx2_GetRestoreTarget(This,pTarget) (This)->lpVtbl->GetRestoreTarget(This,pTarget)
#define IVssComponentEx2_SetPreRestoreFailureMsg(This,wszPreRestoreFailureMsg) (This)->lpVtbl->SetPreRestoreFailureMsg(This,wszPreRestoreFailureMsg)
#define IVssComponentEx2_GetPreRestoreFailureMsg(This,pbstrPreRestoreFailureMsg) (This)->lpVtbl->GetPreRestoreFailureMsg(This,pbstrPreRestoreFailureMsg)
#define IVssComponentEx2_SetPostRestoreFailureMsg(This,wszPostRestoreFailureMsg) (This)->lpVtbl->SetPostRestoreFailureMsg(This,wszPostRestoreFailureMsg)
#define IVssComponentEx2_GetPostRestoreFailureMsg(This,pbstrPostRestoreFailureMsg) (This)->lpVtbl->GetPostRestoreFailureMsg(This,pbstrPostRestoreFailureMsg)
#define IVssComponentEx2_SetBackupStamp(This,wszBackupStamp) (This)->lpVtbl->SetBackupStamp(This,wszBackupStamp)
#define IVssComponentEx2_GetBackupStamp(This,pbstrBackupStamp) (This)->lpVtbl->GetBackupStamp(This,pbstrBackupStamp)
#define IVssComponentEx2_GetPreviousBackupStamp(This,pbstrBackupStamp) (This)->lpVtbl->GetPreviousBackupStamp(This,pbstrBackupStamp)
#define IVssComponentEx2_GetBackupOptions(This,pbstrBackupOptions) (This)->lpVtbl->GetBackupOptions(This,pbstrBackupOptions)
#define IVssComponentEx2_GetRestoreOptions(This,pbstrRestoreOptions) (This)->lpVtbl->GetRestoreOptions(This,pbstrRestoreOptions)
#define IVssComponentEx2_GetRestoreSubcomponentCount(This,pcRestoreSubcomponent) (This)->lpVtbl->GetRestoreSubcomponentCount(This,pcRestoreSubcomponent)
#define IVssComponentEx2_GetRestoreSubcomponent(This,iComponent,pbstrLogicalPath,pbstrComponentName,pbRepair) (This)->lpVtbl->GetRestoreSubcomponent(This,iComponent,pbstrLogicalPath,pbstrComponentName,pbRepair)
#define IVssComponentEx2_GetFileRestoreStatus(This,pStatus) (This)->lpVtbl->GetFileRestoreStatus(This,pStatus)
#define IVssComponentEx2_AddDifferencedFilesByLastModifyTime(This,wszPath,wszFilespec,bRecursive,ftLastModifyTime) (This)->lpVtbl->AddDifferencedFilesByLastModifyTime(This,wszPath,wszFilespec,bRecursive,ftLastModifyTime)
#define IVssComponentEx2_AddDifferencedFilesByLastModifyLSN() (This)->lpVtbl->AddDifferencedFilesByLastModifyLSN(This)
#define IVssComponentEx2_GetDifferencedFilesCount(This,pcDifferencedFiles) (This)->lpVtbl->GetDifferencedFilesCount(This,pcDifferencedFiles)
#define IVssComponentEx2_GetDifferencedFile(This,iDifferencedFile,pbstrPath,pbstrFilespec,pbRecursive,pbstrLsnString,pftLastModifyTime) (This)->lpVtbl->GetDifferencedFile(This,iDifferencedFile,pbstrPath,pbstrFilespec,pbRecursive,pbstrLsnString,pftLastModifyTime)
#define IVssComponentEx2_SetPrepareForBackupFailureMsg(This,wszFailureMsg) (This)->lpVtbl->SetPrepareForBackupFailureMsg(This,wszFailureMsg)
#define IVssComponentEx2_SetPostSnapshotFailureMsg(This,wszFailureMsg) (This)->lpVtbl->SetPostSnapshotFailureMsg(This,wszFailureMsg)
#define IVssComponentEx2_GetPrepareForBackupFailureMsg(This,pbstrFailureMsg) (This)->lpVtbl->GetPrepareForBackupFailureMsg(This,pbstrFailureMsg)
#define IVssComponentEx2_GetPostSnapshotFailureMsg(This,pbstrFailureMsg) (This)->lpVtbl->GetPostSnapshotFailureMsg(This,pbstrFailureMsg)
#define IVssComponentEx2_GetAuthoritativeRestore(This,pbAuth) (This)->lpVtbl->GetAuthoritativeRestore(This,pbAuth)
#define IVssComponentEx2_GetRollForward(This,pRollType,pbstrPoint) (This)->lpVtbl->GetRollForward(This,pRollType,pbstrPoint)
#define IVssComponentEx2_GetRestoreName(This,pbstrName) (This)->lpVtbl->GetRestoreName(This,pbstrName)
#define IVssComponentEx2_GetFailure(This,phr,phrApplication,pbstrApplicationMessage,pdwReserved) (This)->lpVtbl->GetFailure(This,phr,phrApplication,pbstrApplicationMessage,pdwReserved)
#define IVssComponentEx2_SetFailure(This,hr,hrApplication,wszApplicationMessage,dwReserved) (This)->lpVtbl->SetFailure(This,hr,hrApplication,wszApplicationMessage,dwReserved)
#endif /*COBJMACROS*/
#endif /*(_WIN32_WINNT >= 0x601)*/

#ifdef __cplusplus
/* Is a C++ interface instead of a COM */
#undef  INTERFACE
#define INTERFACE IVssWMDependency
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssWMDependency,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssWMDependency methods */
    STDMETHOD_(HRESULT,GetWriterId)(THIS_ VSS_ID *pWriterId) PURE;
    STDMETHOD_(HRESULT,GetLogicalPath)(THIS_ BSTR *pbstrLogicalPath) PURE;
    STDMETHOD_(HRESULT,GetComponentName)(THIS_ BSTR *pbstrComponentName) PURE;

    END_INTERFACE
};

#undef  INTERFACE
#define INTERFACE IVssWMFiledesc
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssWMFiledesc,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssWMFiledesc methods */
    STDMETHOD_(HRESULT,GetPath)(THIS_ BSTR *pbstrPath) PURE;
    STDMETHOD_(HRESULT,GetFilespec)(THIS_ BSTR *pbstrFilespec) PURE;
    STDMETHOD_(HRESULT,GetRecursive)(THIS_ BOOLEAN *pbRecursive) PURE;
    STDMETHOD_(HRESULT,GetAlternateLocation)(THIS_ BSTR *pbstrAlternateLocation) PURE;
    STDMETHOD_(HRESULT,GetBackupTypeMask)(THIS_ DWORD *pdwTypeMask) PURE;

    END_INTERFACE
};
#endif /*__cplusplus*/

#ifdef __cplusplus
#if __MINGW_GNUC_PREREQ(4,6)
/* We need __thiscall support */
class CVssWriter {
protected:
    bool WINAPI AreComponentsSelected() const;
    VSS_BACKUP_TYPE WINAPI GetBackupType() const;
    LONG WINAPI GetContext() const;
    VSS_APPLICATION_LEVEL WINAPI GetCurrentLevel() const;
    VSS_ID WINAPI GetCurrentSnapshotSetId() const;
    LPCWSTR* WINAPI GetCurrentVolumeArray() const;
    UINT WINAPI GetCurrentVolumeCount() const;
    VSS_RESTORE_TYPE WINAPI GetRestoreType() const;
    HRESULT WINAPI GetSnapshotDeviceName(
        LPCWSTR wszOriginalVolume,
        LPCWSTR *ppwszSnapshotDevice) const;
    bool WINAPI IsBootableSystemStateBackedUp() const;
    bool WINAPI IsPartialFileSupportEnabled() const;
    bool WINAPI IsPathAffected(
        LPCWSTR wszPath) const;
    HRESULT WINAPI SetWriterFailure(
        HRESULT hr);
public:
    //Pure virtuals
    virtual bool WINAPI OnAbort() = 0;
    virtual bool WINAPI OnFreeze() = 0;
    virtual bool WINAPI OnPrepareSnapshot() = 0;
    virtual bool WINAPI OnThaw() = 0;
    //Virtuals
    virtual __thiscall ~CVssWriter();
    virtual bool WINAPI OnBackupComplete(
        IVssWriterComponents *pComponent);
    virtual bool WINAPI OnBackupShutdown(
        VSS_ID SnapshotSetId);
    virtual bool WINAPI OnIdentify(
        IVssCreateWriterMetadata *pMetadata);
    virtual bool WINAPI OnPostRestore(
        IVssWriterComponents *pComponent);
    virtual bool WINAPI OnPostSnapshot(
        IVssWriterComponents *pComponent);
    virtual bool WINAPI OnPrepareBackup(
        IVssWriterComponents *pComponent);
    virtual bool WINAPI OnPreRestore(
        IVssWriterComponents *pComponent);
    //gendef says public: virtual bool __stdcall CVssWriter::OnBackOffIOOnVolume(unsigned short *,struct _GUID,struct _GUID)
    //Method unsupported
    virtual bool WINAPI OnBackOffIOOnVolume(
        VSS_PWSZ _vss_pwsz,
        VSS_ID _id1,
        VSS_ID _id2);
    //gendef says public: virtual bool __stdcall CVssWriter::OnContinueIOOnVolume(unsigned short *,struct _GUID,struct _GUID)
    //Method unsupported
    virtual bool WINAPI OnContinueIOOnVolume(
        VSS_PWSZ _vss_pwsz,
        VSS_ID _id1,
        VSS_ID _id2);
    //gendef says public: virtual bool __stdcall CVssWriter::OnVSSShutdown(void)
    //Method unsupported
    virtual bool WINAPI OnVssShutdown();
    //Non-virtuals
    __thiscall CVssWriter();
    HRESULT WINAPI Initialize(
        VSS_ID WriterId,
        LPCWSTR WriterName,
        VSS_USAGE_TYPE UsageType,
        VSS_SOURCE_TYPE SourceType,
        VSS_APPLICATION_LEVEL AppLevel,
        DWORD dwTimeoutFreeze = 60000,
        VSS_ALTERNATE_WRITER_STATE aws = VSS_AWS_NO_ALTERNATE_WRITER,
        bool bIOThrottlingOnly = false,
        LPCWSTR wszWriterInstanceName = NULL);
    HRESULT WINAPI Subscribe(
        DWORD dwEventFlags);
    HRESULT WINAPI Unsubscribe();
    //gendef says public: long __stdcall CVssWriter::InstallAlternateWriter(struct _GUID,struct _GUID)
    //Method unsupported
    HRESULT WINAPI InstallAlternateWriter(
        VSS_ID _id1,
        VSS_ID _id2);
};

class CVssWriterEx : public CVssWriter {
  protected:
    HRESULT WINAPI GetIdentifyInformation(
        IVssExamineWriterMetadata **ppMetadata) const;
    HRESULT WINAPI SubscribeEx(
        DWORD dwUnsubscribeTimeout,
        DWORD dwEventFlags);
  public:
    virtual bool WINAPI OnIdentifyEx(
        IVssCreateWriterMetadataEx *pMetadata) const;
    HRESULT WINAPI InitializeEx(
        VSS_ID WriterId,
        LPCWSTR wszWriterName,
        DWORD dwMajorVersion,
        DWORD dwMinorVersion,
        VSS_USAGE_TYPE ut,
        VSS_SOURCE_TYPE st,
        VSS_APPLICATION_LEVEL nLevel,
        DWORD dwTimeoutFreeze = 60000,
        VSS_ALTERNATE_WRITER_STATE aws = VSS_AWS_NO_ALTERNATE_WRITER,
        bool bIOThrottlingOnly = false,
        LPCWSTR wszWriterInstanceName = NULL);
};

class CVssWriterEx2: public CVssWriterEx {
  public:
    HRESULT WINAPI GetSessionId(
        VSS_ID *idSession) const;
    bool WINAPI IsWriterShuttingDown() const;
    HRESULT WINAPI SetWriterFailureEx(
        HRESULT hrWriter,
        HRESULT hrApplication,
        LPCWSTR wszApplicationMessage);
};
#endif /*__MINGW_GNUC_PREREQ(4,6)*/
#endif /*__cplusplus*/

#include <vsbackup.h>

#endif /*_INC_VSWRITER*/
