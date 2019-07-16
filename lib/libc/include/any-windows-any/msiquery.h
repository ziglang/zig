/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSIQUERY_H_
#define _MSIQUERY_H_

#include <_mingw_unicode.h>
#include "msi.h"

#define MSI_NULL_INTEGER 0x80000000

#define MSIDBOPEN_READONLY (LPCTSTR)0
#define MSIDBOPEN_TRANSACT (LPCTSTR)1
#define MSIDBOPEN_DIRECT (LPCTSTR)2
#define MSIDBOPEN_CREATE (LPCTSTR)3
#define MSIDBOPEN_CREATEDIRECT (LPCTSTR)4
#define MSIDBOPEN_PATCHFILE 32/sizeof(*MSIDBOPEN_READONLY)

typedef enum tagMSIDBSTATE {
  MSIDBSTATE_ERROR =-1,MSIDBSTATE_READ = 0,MSIDBSTATE_WRITE = 1
} MSIDBSTATE;

typedef enum tagMSIMODIFY {
  MSIMODIFY_SEEK =-1,MSIMODIFY_REFRESH = 0,MSIMODIFY_INSERT = 1,MSIMODIFY_UPDATE = 2,MSIMODIFY_ASSIGN = 3,MSIMODIFY_REPLACE = 4,
  MSIMODIFY_MERGE = 5,MSIMODIFY_DELETE = 6,MSIMODIFY_INSERT_TEMPORARY = 7,MSIMODIFY_VALIDATE = 8,MSIMODIFY_VALIDATE_NEW = 9,
  MSIMODIFY_VALIDATE_FIELD = 10,MSIMODIFY_VALIDATE_DELETE = 11
} MSIMODIFY;

typedef enum tagMSICOLINFO {
  MSICOLINFO_NAMES = 0,MSICOLINFO_TYPES = 1
} MSICOLINFO;

typedef enum tagMSICONDITION {
  MSICONDITION_FALSE = 0,MSICONDITION_TRUE = 1,MSICONDITION_NONE = 2,MSICONDITION_ERROR = 3
} MSICONDITION;

typedef enum tagMSICOSTTREE {
  MSICOSTTREE_SELFONLY = 0,MSICOSTTREE_CHILDREN = 1,MSICOSTTREE_PARENTS = 2,MSICOSTTREE_RESERVED = 3
} MSICOSTTREE;

typedef enum tagMSIDBERROR {
  MSIDBERROR_INVALIDARG = -3,MSIDBERROR_MOREDATA = -2,MSIDBERROR_FUNCTIONERROR = -1,MSIDBERROR_NOERROR = 0,MSIDBERROR_DUPLICATEKEY = 1,
  MSIDBERROR_REQUIRED = 2,MSIDBERROR_BADLINK = 3,MSIDBERROR_OVERFLOW = 4,MSIDBERROR_UNDERFLOW = 5,MSIDBERROR_NOTINSET = 6,
  MSIDBERROR_BADVERSION = 7,MSIDBERROR_BADCASE = 8,MSIDBERROR_BADGUID = 9,MSIDBERROR_BADWILDCARD = 10,MSIDBERROR_BADIDENTIFIER = 11,
  MSIDBERROR_BADLANGUAGE = 12,MSIDBERROR_BADFILENAME = 13,MSIDBERROR_BADPATH = 14,MSIDBERROR_BADCONDITION = 15,MSIDBERROR_BADFORMATTED = 16,
  MSIDBERROR_BADTEMPLATE = 17,MSIDBERROR_BADDEFAULTDIR = 18,MSIDBERROR_BADREGPATH = 19,MSIDBERROR_BADCUSTOMSOURCE = 20,MSIDBERROR_BADPROPERTY = 21,
  MSIDBERROR_MISSINGDATA = 22,MSIDBERROR_BADCATEGORY = 23,MSIDBERROR_BADKEYTABLE = 24,MSIDBERROR_BADMAXMINVALUES = 25,MSIDBERROR_BADCABINET = 26,
  MSIDBERROR_BADSHORTCUT = 27,MSIDBERROR_STRINGOVERFLOW = 28,MSIDBERROR_BADLOCALIZEATTRIB = 29
} MSIDBERROR;

typedef enum tagMSIRUNMODE {
  MSIRUNMODE_ADMIN = 0,MSIRUNMODE_ADVERTISE = 1,MSIRUNMODE_MAINTENANCE = 2,MSIRUNMODE_ROLLBACKENABLED = 3,MSIRUNMODE_LOGENABLED = 4,
  MSIRUNMODE_OPERATIONS = 5,MSIRUNMODE_REBOOTATEND = 6,MSIRUNMODE_REBOOTNOW = 7,MSIRUNMODE_CABINET = 8,MSIRUNMODE_SOURCESHORTNAMES= 9,
  MSIRUNMODE_TARGETSHORTNAMES= 10,MSIRUNMODE_RESERVED11 = 11,MSIRUNMODE_WINDOWS9X = 12,MSIRUNMODE_ZAWENABLED = 13,MSIRUNMODE_RESERVED14 = 14,
  MSIRUNMODE_RESERVED15 = 15,MSIRUNMODE_SCHEDULED = 16,MSIRUNMODE_ROLLBACK = 17,MSIRUNMODE_COMMIT = 18
} MSIRUNMODE;

#define INSTALLMESSAGE_TYPEMASK __MSABI_LONG(0xFF000000)

typedef enum tagMSITRANSFORM_ERROR {
  MSITRANSFORM_ERROR_ADDEXISTINGROW = 0x00000001,MSITRANSFORM_ERROR_DELMISSINGROW = 0x00000002,MSITRANSFORM_ERROR_ADDEXISTINGTABLE = 0x00000004,
  MSITRANSFORM_ERROR_DELMISSINGTABLE = 0x00000008,MSITRANSFORM_ERROR_UPDATEMISSINGROW = 0x00000010,MSITRANSFORM_ERROR_CHANGECODEPAGE = 0x00000020,
  MSITRANSFORM_ERROR_VIEWTRANSFORM = 0x00000100
} MSITRANSFORM_ERROR;

typedef enum tagMSITRANSFORM_VALIDATE {
  MSITRANSFORM_VALIDATE_LANGUAGE = 0x00000001,MSITRANSFORM_VALIDATE_PRODUCT = 0x00000002,MSITRANSFORM_VALIDATE_PLATFORM = 0x00000004,
  MSITRANSFORM_VALIDATE_MAJORVERSION = 0x00000008,MSITRANSFORM_VALIDATE_MINORVERSION = 0x00000010,MSITRANSFORM_VALIDATE_UPDATEVERSION = 0x00000020,
  MSITRANSFORM_VALIDATE_NEWLESSBASEVERSION = 0x00000040,MSITRANSFORM_VALIDATE_NEWLESSEQUALBASEVERSION = 0x00000080,
  MSITRANSFORM_VALIDATE_NEWEQUALBASEVERSION = 0x00000100,MSITRANSFORM_VALIDATE_NEWGREATEREQUALBASEVERSION = 0x00000200,
  MSITRANSFORM_VALIDATE_NEWGREATERBASEVERSION = 0x00000400,MSITRANSFORM_VALIDATE_UPGRADECODE = 0x00000800
} MSITRANSFORM_VALIDATE;

#ifdef __cplusplus
extern "C" {
#endif

  UINT WINAPI MsiDatabaseOpenViewA(MSIHANDLE hDatabase,LPCSTR szQuery,MSIHANDLE *phView);
  UINT WINAPI MsiDatabaseOpenViewW(MSIHANDLE hDatabase,LPCWSTR szQuery,MSIHANDLE *phView);
#define MsiDatabaseOpenView __MINGW_NAME_AW(MsiDatabaseOpenView)

  MSIDBERROR WINAPI MsiViewGetErrorA(MSIHANDLE hView,LPSTR szColumnNameBuffer,DWORD *pcchBuf);
  MSIDBERROR WINAPI MsiViewGetErrorW(MSIHANDLE hView,LPWSTR szColumnNameBuffer,DWORD *pcchBuf);
#define MsiViewGetError __MINGW_NAME_AW(MsiViewGetError)

  UINT WINAPI MsiViewExecute(MSIHANDLE hView,MSIHANDLE hRecord);
  UINT WINAPI MsiViewFetch(MSIHANDLE hView,MSIHANDLE *phRecord);
  UINT WINAPI MsiViewModify(MSIHANDLE hView,MSIMODIFY eModifyMode,MSIHANDLE hRecord);
  UINT WINAPI MsiViewGetColumnInfo(MSIHANDLE hView,MSICOLINFO eColumnInfo,MSIHANDLE *phRecord);
  UINT WINAPI MsiViewClose(MSIHANDLE hView);
  UINT WINAPI MsiDatabaseGetPrimaryKeysA(MSIHANDLE hDatabase,LPCSTR szTableName,MSIHANDLE *phRecord);
  UINT WINAPI MsiDatabaseGetPrimaryKeysW(MSIHANDLE hDatabase,LPCWSTR szTableName,MSIHANDLE *phRecord);
#define MsiDatabaseGetPrimaryKeys __MINGW_NAME_AW(MsiDatabaseGetPrimaryKeys)

  MSICONDITION WINAPI MsiDatabaseIsTablePersistentA(MSIHANDLE hDatabase,LPCSTR szTableName);
  MSICONDITION WINAPI MsiDatabaseIsTablePersistentW(MSIHANDLE hDatabase,LPCWSTR szTableName);
#define MsiDatabaseIsTablePersistent __MINGW_NAME_AW(MsiDatabaseIsTablePersistent)

  UINT WINAPI MsiGetSummaryInformationA(MSIHANDLE hDatabase,LPCSTR szDatabasePath,UINT uiUpdateCount,MSIHANDLE *phSummaryInfo);
  UINT WINAPI MsiGetSummaryInformationW(MSIHANDLE hDatabase,LPCWSTR szDatabasePath,UINT uiUpdateCount,MSIHANDLE *phSummaryInfo);
#define MsiGetSummaryInformation __MINGW_NAME_AW(MsiGetSummaryInformation)

  UINT WINAPI MsiSummaryInfoGetPropertyCount(MSIHANDLE hSummaryInfo,UINT *puiPropertyCount);
  UINT WINAPI MsiSummaryInfoSetPropertyA(MSIHANDLE hSummaryInfo,UINT uiProperty,UINT uiDataType,INT iValue,FILETIME *pftValue,LPCSTR szValue);
  UINT WINAPI MsiSummaryInfoSetPropertyW(MSIHANDLE hSummaryInfo,UINT uiProperty,UINT uiDataType,INT iValue,FILETIME *pftValue,LPCWSTR szValue);
#define MsiSummaryInfoSetProperty __MINGW_NAME_AW(MsiSummaryInfoSetProperty)

  UINT WINAPI MsiSummaryInfoGetPropertyA(MSIHANDLE hSummaryInfo,UINT uiProperty,UINT *puiDataType,INT *piValue,FILETIME *pftValue,LPSTR szValueBuf,DWORD *pcchValueBuf);
  UINT WINAPI MsiSummaryInfoGetPropertyW(MSIHANDLE hSummaryInfo,UINT uiProperty,UINT *puiDataType,INT *piValue,FILETIME *pftValue,LPWSTR szValueBuf,DWORD *pcchValueBuf);
#define MsiSummaryInfoGetProperty __MINGW_NAME_AW(MsiSummaryInfoGetProperty)

  UINT WINAPI MsiSummaryInfoPersist(MSIHANDLE hSummaryInfo);
  UINT WINAPI MsiOpenDatabaseA(LPCSTR szDatabasePath,LPCSTR szPersist,MSIHANDLE *phDatabase);
  UINT WINAPI MsiOpenDatabaseW(LPCWSTR szDatabasePath,LPCWSTR szPersist,MSIHANDLE *phDatabase);
#define MsiOpenDatabase __MINGW_NAME_AW(MsiOpenDatabase)

  UINT WINAPI MsiDatabaseImportA(MSIHANDLE hDatabase,LPCSTR szFolderPath,LPCSTR szFileName);
  UINT WINAPI MsiDatabaseImportW(MSIHANDLE hDatabase,LPCWSTR szFolderPath,LPCWSTR szFileName);
#define MsiDatabaseImport __MINGW_NAME_AW(MsiDatabaseImport)

  UINT WINAPI MsiDatabaseExportA(MSIHANDLE hDatabase,LPCSTR szTableName,LPCSTR szFolderPath,LPCSTR szFileName);
  UINT WINAPI MsiDatabaseExportW(MSIHANDLE hDatabase,LPCWSTR szTableName,LPCWSTR szFolderPath,LPCWSTR szFileName);
#define MsiDatabaseExport __MINGW_NAME_AW(MsiDatabaseExport)

  UINT WINAPI MsiDatabaseMergeA(MSIHANDLE hDatabase,MSIHANDLE hDatabaseMerge,LPCSTR szTableName);
  UINT WINAPI MsiDatabaseMergeW(MSIHANDLE hDatabase,MSIHANDLE hDatabaseMerge,LPCWSTR szTableName);
#define MsiDatabaseMerge __MINGW_NAME_AW(MsiDatabaseMerge)

  UINT WINAPI MsiDatabaseGenerateTransformA(MSIHANDLE hDatabase,MSIHANDLE hDatabaseReference,LPCSTR szTransformFile,int iReserved1,int iReserved2);
  UINT WINAPI MsiDatabaseGenerateTransformW(MSIHANDLE hDatabase,MSIHANDLE hDatabaseReference,LPCWSTR szTransformFile,int iReserved1,int iReserved2);
#define MsiDatabaseGenerateTransform __MINGW_NAME_AW(MsiDatabaseGenerateTransform)

  UINT WINAPI MsiDatabaseApplyTransformA(MSIHANDLE hDatabase,LPCSTR szTransformFile,int iErrorConditions);
  UINT WINAPI MsiDatabaseApplyTransformW(MSIHANDLE hDatabase,LPCWSTR szTransformFile,int iErrorConditions);
#define MsiDatabaseApplyTransform __MINGW_NAME_AW(MsiDatabaseApplyTransform)

  UINT WINAPI MsiCreateTransformSummaryInfoA(MSIHANDLE hDatabase,MSIHANDLE hDatabaseReference,LPCSTR szTransformFile,int iErrorConditions,int iValidation);
  UINT WINAPI MsiCreateTransformSummaryInfoW(MSIHANDLE hDatabase,MSIHANDLE hDatabaseReference,LPCWSTR szTransformFile,int iErrorConditions,int iValidation);
#define MsiCreateTransformSummaryInfo __MINGW_NAME_AW(MsiCreateTransformSummaryInfo)

  UINT WINAPI MsiDatabaseCommit(MSIHANDLE hDatabase);
  MSIDBSTATE WINAPI MsiGetDatabaseState(MSIHANDLE hDatabase);
  MSIHANDLE WINAPI MsiCreateRecord(UINT cParams);
  WINBOOL WINAPI MsiRecordIsNull(MSIHANDLE hRecord,UINT iField);
  UINT WINAPI MsiRecordDataSize(MSIHANDLE hRecord,UINT iField);
  UINT WINAPI MsiRecordSetInteger(MSIHANDLE hRecord,UINT iField,int iValue);
  int WINAPI MsiRecordGetInteger(MSIHANDLE hRecord,UINT iField);
  UINT WINAPI MsiRecordGetFieldCount(MSIHANDLE hRecord);
  UINT WINAPI MsiRecordReadStream(MSIHANDLE hRecord,UINT iField,char *szDataBuf,DWORD *pcbDataBuf);
  UINT WINAPI MsiRecordClearData(MSIHANDLE hRecord);
  MSIHANDLE WINAPI MsiGetActiveDatabase(MSIHANDLE hInstall);
  LANGID WINAPI MsiGetLanguage(MSIHANDLE hInstall);
  WINBOOL WINAPI MsiGetMode(MSIHANDLE hInstall,MSIRUNMODE eRunMode);
  UINT WINAPI MsiSetMode(MSIHANDLE hInstall,MSIRUNMODE eRunMode,WINBOOL fState);
  int WINAPI MsiProcessMessage(MSIHANDLE hInstall,INSTALLMESSAGE eMessageType,MSIHANDLE hRecord);

  UINT WINAPI MsiRecordSetStringA(MSIHANDLE hRecord,UINT iField,LPCSTR szValue);
  UINT WINAPI MsiRecordSetStringW(MSIHANDLE hRecord,UINT iField,LPCWSTR szValue);
#define MsiRecordSetString __MINGW_NAME_AW(MsiRecordSetString)

  UINT WINAPI MsiRecordGetStringA(MSIHANDLE hRecord,UINT iField,LPSTR szValueBuf,DWORD *pcchValueBuf);
  UINT WINAPI MsiRecordGetStringW(MSIHANDLE hRecord,UINT iField,LPWSTR szValueBuf,DWORD *pcchValueBuf);
#define MsiRecordGetString __MINGW_NAME_AW(MsiRecordGetString)

  UINT WINAPI MsiRecordSetStreamA(MSIHANDLE hRecord,UINT iField,LPCSTR szFilePath);
  UINT WINAPI MsiRecordSetStreamW(MSIHANDLE hRecord,UINT iField,LPCWSTR szFilePath);
#define MsiRecordSetStream __MINGW_NAME_AW(MsiRecordSetStream)

  UINT WINAPI MsiSetPropertyA(MSIHANDLE hInstall,LPCSTR szName,LPCSTR szValue);
  UINT WINAPI MsiSetPropertyW(MSIHANDLE hInstall,LPCWSTR szName,LPCWSTR szValue);
#define MsiSetProperty __MINGW_NAME_AW(MsiSetProperty)

  UINT WINAPI MsiGetPropertyA(MSIHANDLE hInstall,LPCSTR szName,LPSTR szValueBuf,DWORD *pcchValueBuf);
  UINT WINAPI MsiGetPropertyW(MSIHANDLE hInstall,LPCWSTR szName,LPWSTR szValueBuf,DWORD *pcchValueBuf);
#define MsiGetProperty __MINGW_NAME_AW(MsiGetProperty)

  UINT WINAPI MsiFormatRecordA(MSIHANDLE hInstall,MSIHANDLE hRecord,LPSTR szResultBuf,DWORD *pcchResultBuf);
  UINT WINAPI MsiFormatRecordW(MSIHANDLE hInstall,MSIHANDLE hRecord,LPWSTR szResultBuf,DWORD *pcchResultBuf);
#define MsiFormatRecord __MINGW_NAME_AW(MsiFormatRecord)

  UINT WINAPI MsiDoActionA(MSIHANDLE hInstall,LPCSTR szAction);
  UINT WINAPI MsiDoActionW(MSIHANDLE hInstall,LPCWSTR szAction);
#define MsiDoAction __MINGW_NAME_AW(MsiDoAction)

  UINT WINAPI MsiSequenceA(MSIHANDLE hInstall,LPCSTR szTable,INT iSequenceMode);
  UINT WINAPI MsiSequenceW(MSIHANDLE hInstall,LPCWSTR szTable,INT iSequenceMode);
#define MsiSequence __MINGW_NAME_AW(MsiSequence)

  MSICONDITION WINAPI MsiEvaluateConditionA(MSIHANDLE hInstall,LPCSTR szCondition);
  MSICONDITION WINAPI MsiEvaluateConditionW(MSIHANDLE hInstall,LPCWSTR szCondition);
#define MsiEvaluateCondition __MINGW_NAME_AW(MsiEvaluateCondition)

  UINT WINAPI MsiGetFeatureStateA(MSIHANDLE hInstall,LPCSTR szFeature,INSTALLSTATE *piInstalled,INSTALLSTATE *piAction);
  UINT WINAPI MsiGetFeatureStateW(MSIHANDLE hInstall,LPCWSTR szFeature,INSTALLSTATE *piInstalled,INSTALLSTATE *piAction);
#define MsiGetFeatureState __MINGW_NAME_AW(MsiGetFeatureState)

  UINT WINAPI MsiSetFeatureStateA(MSIHANDLE hInstall,LPCSTR szFeature,INSTALLSTATE iState);
  UINT WINAPI MsiSetFeatureStateW(MSIHANDLE hInstall,LPCWSTR szFeature,INSTALLSTATE iState);
#define MsiSetFeatureState __MINGW_NAME_AW(MsiSetFeatureState)

#if (_WIN32_MSI >= 110)
  UINT WINAPI MsiSetFeatureAttributesA(MSIHANDLE hInstall,LPCSTR szFeature,DWORD dwAttributes);
  UINT WINAPI MsiSetFeatureAttributesW(MSIHANDLE hInstall,LPCWSTR szFeature,DWORD dwAttributes);
#define MsiSetFeatureAttributes __MINGW_NAME_AW(MsiSetFeatureAttributes)
#endif

  UINT WINAPI MsiGetComponentStateA(MSIHANDLE hInstall,LPCSTR szComponent,INSTALLSTATE *piInstalled,INSTALLSTATE *piAction);
  UINT WINAPI MsiGetComponentStateW(MSIHANDLE hInstall,LPCWSTR szComponent,INSTALLSTATE *piInstalled,INSTALLSTATE *piAction);
#define MsiGetComponentState __MINGW_NAME_AW(MsiGetComponentState)

  UINT WINAPI MsiSetComponentStateA(MSIHANDLE hInstall,LPCSTR szComponent,INSTALLSTATE iState);
  UINT WINAPI MsiSetComponentStateW(MSIHANDLE hInstall,LPCWSTR szComponent,INSTALLSTATE iState);
#define MsiSetComponentState __MINGW_NAME_AW(MsiSetComponentState)

  UINT WINAPI MsiGetFeatureCostA(MSIHANDLE hInstall,LPCSTR szFeature,MSICOSTTREE iCostTree,INSTALLSTATE iState,INT *piCost);
  UINT WINAPI MsiGetFeatureCostW(MSIHANDLE hInstall,LPCWSTR szFeature,MSICOSTTREE iCostTree,INSTALLSTATE iState,INT *piCost);
#define MsiGetFeatureCost __MINGW_NAME_AW(MsiGetFeatureCost)

#if (_WIN32_MSI >= 150)
  UINT WINAPI MsiEnumComponentCostsA(MSIHANDLE hInstall,LPCSTR szComponent,DWORD dwIndex,INSTALLSTATE iState,LPSTR szDriveBuf,DWORD *pcchDriveBuf,INT *piCost,INT *piTempCost);
  UINT WINAPI MsiEnumComponentCostsW(MSIHANDLE hInstall,LPCWSTR szComponent,DWORD dwIndex,INSTALLSTATE iState,LPWSTR szDriveBuf,DWORD *pcchDriveBuf,INT *piCost,INT *piTempCost);
#define MsiEnumComponentCosts __MINGW_NAME_AW(MsiEnumComponentCosts)
#endif

  UINT WINAPI MsiSetInstallLevel(MSIHANDLE hInstall,int iInstallLevel);
  UINT WINAPI MsiVerifyDiskSpace(MSIHANDLE hInstall);
  UINT WINAPI MsiEnableUIPreview(MSIHANDLE hDatabase,MSIHANDLE *phPreview);
  MSIHANDLE WINAPI MsiGetLastErrorRecord();

  UINT WINAPI MsiGetFeatureValidStatesA(MSIHANDLE hInstall,LPCSTR szFeature,DWORD *dwInstallStates);
  UINT WINAPI MsiGetFeatureValidStatesW(MSIHANDLE hInstall,LPCWSTR szFeature,DWORD *dwInstallStates);
#define MsiGetFeatureValidStates __MINGW_NAME_AW(MsiGetFeatureValidStates)

  UINT WINAPI MsiGetSourcePathA(MSIHANDLE hInstall,LPCSTR szFolder,LPSTR szPathBuf,DWORD *pcchPathBuf);
  UINT WINAPI MsiGetSourcePathW(MSIHANDLE hInstall,LPCWSTR szFolder,LPWSTR szPathBuf,DWORD *pcchPathBuf);
#define MsiGetSourcePath __MINGW_NAME_AW(MsiGetSourcePath)

  UINT WINAPI MsiGetTargetPathA(MSIHANDLE hInstall,LPCSTR szFolder,LPSTR szPathBuf,DWORD *pcchPathBuf);
  UINT WINAPI MsiGetTargetPathW(MSIHANDLE hInstall,LPCWSTR szFolder,LPWSTR szPathBuf,DWORD *pcchPathBuf);
#define MsiGetTargetPath __MINGW_NAME_AW(MsiGetTargetPath)

  UINT WINAPI MsiSetTargetPathA(MSIHANDLE hInstall,LPCSTR szFolder,LPCSTR szFolderPath);
  UINT WINAPI MsiSetTargetPathW(MSIHANDLE hInstall,LPCWSTR szFolder,LPCWSTR szFolderPath);
#define MsiSetTargetPath __MINGW_NAME_AW(MsiSetTargetPath)

  UINT WINAPI MsiPreviewDialogA(MSIHANDLE hPreview,LPCSTR szDialogName);
  UINT WINAPI MsiPreviewDialogW(MSIHANDLE hPreview,LPCWSTR szDialogName);
#define MsiPreviewDialog __MINGW_NAME_AW(MsiPreviewDialog)

  UINT WINAPI MsiPreviewBillboardA(MSIHANDLE hPreview,LPCSTR szControlName,LPCSTR szBillboard);
  UINT WINAPI MsiPreviewBillboardW(MSIHANDLE hPreview,LPCWSTR szControlName,LPCWSTR szBillboard);
#define MsiPreviewBillboard __MINGW_NAME_AW(MsiPreviewBillboard)

#ifdef __cplusplus
}
#endif
#endif
