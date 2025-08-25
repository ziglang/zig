/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#if !defined (NTDDI_VERSION) || (NTDDI_VERSION < 0x06020000)
#include "adoint_backcompat.h"
#else

#ifndef _ADOINT_H_
#define _ADOINT_H_

#ifndef _INC_TCHAR
#include <tchar.h>
#endif

#ifndef DECLSPEC_UUID
#define DECLSPEC_UUID(x)
#endif

#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 500
#endif

#ifndef __REQUIRED_RPCSAL_H_VERSION__
#define __REQUIRED_RPCSAL_H_VERSION__ 100
#endif
#include "rpc.h"
#include "rpcndr.h"
#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif
#ifndef __ado10_h__
#define __ado10_h__

#ifndef ___ADOCollection_FWD_DEFINED__
#define ___ADOCollection_FWD_DEFINED__
typedef interface _ADOCollection _ADOCollection;
#endif
#ifndef ___ADODynaCollection_FWD_DEFINED__
#define ___ADODynaCollection_FWD_DEFINED__
typedef interface _ADODynaCollection _ADODynaCollection;
#endif
#ifndef ___ADO_FWD_DEFINED__
#define ___ADO_FWD_DEFINED__
typedef interface _ADO _ADO;
#endif
#ifndef __Error_FWD_DEFINED__
#define __Error_FWD_DEFINED__
typedef interface ADOError Error;
#endif
#ifndef __Errors_FWD_DEFINED__
#define __Errors_FWD_DEFINED__
typedef interface ADOErrors Errors;
#endif
#ifndef __Command15_FWD_DEFINED__
#define __Command15_FWD_DEFINED__
typedef interface Command15 Command15;
#endif
#ifndef __Command25_FWD_DEFINED__
#define __Command25_FWD_DEFINED__
typedef interface Command25 Command25;
#endif
#ifndef ___Command_FWD_DEFINED__
#define ___Command_FWD_DEFINED__
typedef interface _ADOCommand _Command;
#endif
#ifndef __ConnectionEventsVt_FWD_DEFINED__
#define __ConnectionEventsVt_FWD_DEFINED__
typedef interface ConnectionEventsVt ConnectionEventsVt;
#endif
#ifndef __RecordsetEventsVt_FWD_DEFINED__
#define __RecordsetEventsVt_FWD_DEFINED__
typedef interface RecordsetEventsVt RecordsetEventsVt;
#endif
#ifndef __ConnectionEvents_FWD_DEFINED__
#define __ConnectionEvents_FWD_DEFINED__
typedef interface ConnectionEvents ConnectionEvents;
#endif
#ifndef __RecordsetEvents_FWD_DEFINED__
#define __RecordsetEvents_FWD_DEFINED__
typedef interface RecordsetEvents RecordsetEvents;
#endif
#ifndef __Connection15_FWD_DEFINED__
#define __Connection15_FWD_DEFINED__
typedef interface Connection15 Connection15;
#endif
#ifndef ___Connection_FWD_DEFINED__
#define ___Connection_FWD_DEFINED__
typedef interface _ADOConnection _Connection;
#endif
#ifndef __ADOConnectionConstruction15_FWD_DEFINED__
#define __ADOConnectionConstruction15_FWD_DEFINED__
typedef interface ADOConnectionConstruction15 ADOConnectionConstruction15;
#endif
#ifndef __ADOConnectionConstruction_FWD_DEFINED__
#define __ADOConnectionConstruction_FWD_DEFINED__
typedef interface ADOConnectionConstruction ADOConnectionConstruction;
#endif
#ifndef __Connection_FWD_DEFINED__
#define __Connection_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOConnection Connection;
#else
typedef struct ADOConnection Connection;
#endif
#endif
#ifndef ___Record_FWD_DEFINED__
#define ___Record_FWD_DEFINED__
typedef interface _ADORecord _Record;
#endif
#ifndef __Record_FWD_DEFINED__
#define __Record_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADORecord Record;
#else
typedef struct ADORecord Record;
#endif
#endif
#ifndef ___Stream_FWD_DEFINED__
#define ___Stream_FWD_DEFINED__
typedef interface _ADOStream _Stream;
#endif
#ifndef __Stream_FWD_DEFINED__
#define __Stream_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOStream Stream;
#else
typedef struct ADOStream Stream;
#endif
#endif
#ifndef __ADORecordConstruction_FWD_DEFINED__
#define __ADORecordConstruction_FWD_DEFINED__
typedef interface ADORecordConstruction ADORecordConstruction;
#endif
#ifndef __ADOStreamConstruction_FWD_DEFINED__
#define __ADOStreamConstruction_FWD_DEFINED__
typedef interface ADOStreamConstruction ADOStreamConstruction;
#endif
#ifndef __ADOCommandConstruction_FWD_DEFINED__
#define __ADOCommandConstruction_FWD_DEFINED__
typedef interface ADOCommandConstruction ADOCommandConstruction;
#endif
#ifndef __Command_FWD_DEFINED__
#define __Command_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOCommand Command;
#else
typedef struct ADOCommand Command;
#endif
#endif
#ifndef __Recordset_FWD_DEFINED__
#define __Recordset_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADORecordset Recordset;
#else
typedef struct ADORecordset Recordset;
#endif
#endif
#ifndef __Recordset15_FWD_DEFINED__
#define __Recordset15_FWD_DEFINED__
typedef interface Recordset15 Recordset15;
#endif
#ifndef __Recordset20_FWD_DEFINED__
#define __Recordset20_FWD_DEFINED__
typedef interface Recordset20 Recordset20;
#endif
#ifndef __Recordset21_FWD_DEFINED__
#define __Recordset21_FWD_DEFINED__
typedef interface Recordset21 Recordset21;
#endif
#ifndef ___Recordset_FWD_DEFINED__
#define ___Recordset_FWD_DEFINED__
typedef interface _ADORecordset _Recordset;
#endif
#ifndef __ADORecordsetConstruction_FWD_DEFINED__
#define __ADORecordsetConstruction_FWD_DEFINED__
typedef interface ADORecordsetConstruction ADORecordsetConstruction;
#endif
#ifndef __Field15_FWD_DEFINED__
#define __Field15_FWD_DEFINED__
typedef interface Field15 Field15;
#endif
#ifndef __Field20_FWD_DEFINED__
#define __Field20_FWD_DEFINED__
typedef interface Field20 Field20;
#endif
#ifndef __Field_FWD_DEFINED__
#define __Field_FWD_DEFINED__
typedef interface ADOField Field;
#endif
#ifndef __Fields15_FWD_DEFINED__
#define __Fields15_FWD_DEFINED__
typedef interface Fields15 Fields15;
#endif
#ifndef __Fields20_FWD_DEFINED__
#define __Fields20_FWD_DEFINED__
typedef interface Fields20 Fields20;
#endif
#ifndef __Fields_FWD_DEFINED__
#define __Fields_FWD_DEFINED__
typedef interface ADOFields Fields;
#endif
#ifndef ___Parameter_FWD_DEFINED__
#define ___Parameter_FWD_DEFINED__
typedef interface _ADOParameter _Parameter;
#endif
#ifndef __Parameter_FWD_DEFINED__
#define __Parameter_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOParameter Parameter;
#else
typedef struct ADOParameter Parameter;
#endif
#endif
#ifndef __Parameters_FWD_DEFINED__
#define __Parameters_FWD_DEFINED__
typedef interface ADOParameters Parameters;
#endif
#ifndef __Property_FWD_DEFINED__
#define __Property_FWD_DEFINED__
typedef interface ADOProperty Property;
#endif
#ifndef __Properties_FWD_DEFINED__
#define __Properties_FWD_DEFINED__
typedef interface ADOProperties Properties;
#endif
#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN64

  typedef LONGLONG ADO_LONGPTR;
#else

  typedef LONG ADO_LONGPTR;
#endif
  extern RPC_IF_HANDLE __MIDL_itf_ado10_0000_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ado10_0000_0000_v0_0_s_ifspec;
#ifndef __ADODB_LIBRARY_DEFINED__
#define __ADODB_LIBRARY_DEFINED__

  typedef DECLSPEC_UUID ("0000051B-0000-0010-8000-00AA006D2EA4")
  enum CursorTypeEnum {
    adOpenUnspecified = -1,
    adOpenForwardOnly = 0,
    adOpenKeyset = 1,
    adOpenDynamic = 2,
    adOpenStatic = 3
  } CursorTypeEnum;
  typedef DECLSPEC_UUID ("0000051C-0000-0010-8000-00AA006D2EA4")
  enum CursorOptionEnum {
    adHoldRecords = 0x100,
    adMovePrevious = 0x200,
    adAddNew = 0x1000400,
    adDelete = 0x1000800,
    adUpdate = 0x1008000,
    adBookmark = 0x2000,
    adApproxPosition = 0x4000,
    adUpdateBatch = 0x10000,
    adResync = 0x20000,
    adNotify = 0x40000,
    adFind = 0x80000,
    adSeek = 0x400000,
    adIndex = 0x800000
  } CursorOptionEnum;
  typedef DECLSPEC_UUID ("0000051D-0000-0010-8000-00AA006D2EA4")
  enum LockTypeEnum {
    adLockUnspecified = -1,
    adLockReadOnly = 1,
    adLockPessimistic = 2,
    adLockOptimistic = 3,
    adLockBatchOptimistic = 4
  } LockTypeEnum;
  typedef DECLSPEC_UUID ("0000051E-0000-0010-8000-00AA006D2EA4")
  enum ExecuteOptionEnum {
    adOptionUnspecified = -1,
    adAsyncExecute = 0x10,
    adAsyncFetch = 0x20,
    adAsyncFetchNonBlocking = 0x40,
    adExecuteNoRecords = 0x80,
    adExecuteStream = 0x400,
    adExecuteRecord = 0x800
  } ExecuteOptionEnum;
  typedef DECLSPEC_UUID ("00000541-0000-0010-8000-00AA006D2EA4")
  enum ConnectOptionEnum {
    adConnectUnspecified = -1,
    adAsyncConnect = 0x10
  } ConnectOptionEnum;
  typedef DECLSPEC_UUID ("00000532-0000-0010-8000-00AA006D2EA4")
  enum ObjectStateEnum {
    adStateClosed = 0,
    adStateOpen = 0x1,
    adStateConnecting = 0x2,
    adStateExecuting = 0x4,
    adStateFetching = 0x8
  } ObjectStateEnum;
  typedef DECLSPEC_UUID ("0000052F-0000-0010-8000-00AA006D2EA4")
  enum CursorLocationEnum {
    adUseNone = 1,
    adUseServer = 2,
    adUseClient = 3,
    adUseClientBatch = 3
  } CursorLocationEnum;
  typedef DECLSPEC_UUID ("0000051F-0000-0010-8000-00AA006D2EA4")
  enum DataTypeEnum {
    adEmpty = 0,
    adTinyInt = 16,
    adSmallInt = 2,
    adInteger = 3,
    adBigInt = 20,
    adUnsignedTinyInt = 17,
    adUnsignedSmallInt = 18,
    adUnsignedInt = 19,
    adUnsignedBigInt = 21,
    adSingle = 4,
    adDouble = 5,
    adCurrency = 6,
    adDecimal = 14,
    adNumeric = 131,
    adBoolean = 11,
    adError = 10,
    adUserDefined = 132,
    adVariant = 12,
    adIDispatch = 9,
    adIUnknown = 13,
    adGUID = 72,
    adDate = 7,
    adDBDate = 133,
    adDBTime = 134,
    adDBTimeStamp = 135,
    adBSTR = 8,
    adChar = 129,
    adVarChar = 200,
    adLongVarChar = 201,
    adWChar = 130,
    adVarWChar = 202,
    adLongVarWChar = 203,
    adBinary = 128,
    adVarBinary = 204,
    adLongVarBinary = 205,
    adChapter = 136,
    adFileTime = 64,
    adPropVariant = 138,
    adVarNumeric = 139,
    adArray = 0x2000
  } DataTypeEnum;
  typedef DECLSPEC_UUID ("00000525-0000-0010-8000-00AA006D2EA4")
  enum FieldAttributeEnum {
    adFldUnspecified = -1,
    adFldMayDefer = 0x2,
    adFldUpdatable = 0x4,
    adFldUnknownUpdatable = 0x8,
    adFldFixed = 0x10,
    adFldIsNullable = 0x20,
    adFldMayBeNull = 0x40,
    adFldLong = 0x80,
    adFldRowID = 0x100,
    adFldRowVersion = 0x200,
    adFldCacheDeferred = 0x1000,
    adFldIsChapter = 0x2000,
    adFldNegativeScale = 0x4000,
    adFldKeyColumn = 0x8000,
    adFldIsRowURL = 0x10000,
    adFldIsDefaultStream = 0x20000,
    adFldIsCollection = 0x40000
  } FieldAttributeEnum;
  typedef DECLSPEC_UUID ("00000526-0000-0010-8000-00AA006D2EA4")
  enum EditModeEnum {
    adEditNone = 0,
    adEditInProgress = 0x1,
    adEditAdd = 0x2,
    adEditDelete = 0x4
  } EditModeEnum;
  typedef DECLSPEC_UUID ("00000527-0000-0010-8000-00AA006D2EA4")
  enum RecordStatusEnum {
    adRecOK = 0,
    adRecNew = 0x1,
    adRecModified = 0x2,
    adRecDeleted = 0x4,
    adRecUnmodified = 0x8,
    adRecInvalid = 0x10,
    adRecMultipleChanges = 0x40,
    adRecPendingChanges = 0x80,
    adRecCanceled = 0x100,
    adRecCantRelease = 0x400,
    adRecConcurrencyViolation = 0x800,
    adRecIntegrityViolation = 0x1000,
    adRecMaxChangesExceeded = 0x2000,
    adRecObjectOpen = 0x4000,
    adRecOutOfMemory = 0x8000,
    adRecPermissionDenied = 0x10000,
    adRecSchemaViolation = 0x20000,
    adRecDBDeleted = 0x40000
  } RecordStatusEnum;
  typedef DECLSPEC_UUID ("00000542-0000-0010-8000-00AA006D2EA4")
  enum GetRowsOptionEnum {
    adGetRowsRest = -1
  } GetRowsOptionEnum;
  typedef DECLSPEC_UUID ("00000528-0000-0010-8000-00AA006D2EA4")
  enum PositionEnum {
    adPosUnknown = -1,
    adPosBOF = -2,
    adPosEOF = -3
  } PositionEnum;
  typedef
  enum BookmarkEnum {
    adBookmarkCurrent = 0,
    adBookmarkFirst = 1,
    adBookmarkLast = 2
  } BookmarkEnum;
  typedef DECLSPEC_UUID ("00000540-0000-0010-8000-00AA006D2EA4")
  enum MarshalOptionsEnum {
    adMarshalAll = 0,
    adMarshalModifiedOnly = 1
  } MarshalOptionsEnum;
  typedef DECLSPEC_UUID ("00000543-0000-0010-8000-00AA006D2EA4")
  enum AffectEnum {
    adAffectCurrent = 1,
    adAffectGroup = 2,
    adAffectAll = 3,
    adAffectAllChapters = 4
  } AffectEnum;
  typedef DECLSPEC_UUID ("00000544-0000-0010-8000-00AA006D2EA4")
  enum ResyncEnum {
    adResyncUnderlyingValues = 1,
    adResyncAllValues = 2
  } ResyncEnum;
  typedef DECLSPEC_UUID ("00000545-0000-0010-8000-00AA006D2EA4")
  enum CompareEnum {
    adCompareLessThan = 0,
    adCompareEqual = 1,
    adCompareGreaterThan = 2,
    adCompareNotEqual = 3,
    adCompareNotComparable = 4
  } CompareEnum;
  typedef DECLSPEC_UUID ("00000546-0000-0010-8000-00AA006D2EA4")
  enum FilterGroupEnum {
    adFilterNone = 0,
    adFilterPendingRecords = 1,
    adFilterAffectedRecords = 2,
    adFilterFetchedRecords = 3,
    adFilterPredicate = 4,
    adFilterConflictingRecords = 5
  } FilterGroupEnum;
  typedef DECLSPEC_UUID ("00000547-0000-0010-8000-00AA006D2EA4")
  enum SearchDirectionEnum {
    adSearchForward = 1,
    adSearchBackward = -1
  } SearchDirectionEnum;
  typedef SearchDirectionEnum SearchDirection;
  typedef DECLSPEC_UUID ("00000548-0000-0010-8000-00AA006D2EA4")
  enum PersistFormatEnum {
    adPersistADTG = 0,
    adPersistXML = 1
  } PersistFormatEnum;
  typedef DECLSPEC_UUID ("00000549-0000-0010-8000-00AA006D2EA4")
  enum StringFormatEnum {
    adClipString = 2
  } StringFormatEnum;
  typedef DECLSPEC_UUID ("00000520-0000-0010-8000-00AA006D2EA4")
  enum ConnectPromptEnum {
    adPromptAlways = 1,
    adPromptComplete = 2,
    adPromptCompleteRequired = 3,
    adPromptNever = 4
  } ConnectPromptEnum;
  typedef DECLSPEC_UUID ("00000521-0000-0010-8000-00AA006D2EA4")
  enum ConnectModeEnum {
    adModeUnknown = 0,
    adModeRead = 1,
    adModeWrite = 2,
    adModeReadWrite = 3,
    adModeShareDenyRead = 4,
    adModeShareDenyWrite = 8,
    adModeShareExclusive = 0xc,
    adModeShareDenyNone = 0x10,
    adModeRecursive = 0x400000
  } ConnectModeEnum;
  typedef DECLSPEC_UUID ("00000570-0000-0010-8000-00AA006D2EA4")
  enum RecordCreateOptionsEnum {
    adCreateCollection = 0x2000,
    adCreateStructDoc = 0x80000000,
    adCreateNonCollection = 0,
    adOpenIfExists = 0x2000000,
    adCreateOverwrite = 0x4000000,
    adFailIfNotExists = -1
  } RecordCreateOptionsEnum;
  typedef DECLSPEC_UUID ("00000571-0000-0010-8000-00AA006D2EA4")
  enum RecordOpenOptionsEnum {
    adOpenRecordUnspecified = -1,
    adOpenSource = 0x800000,
    adOpenOutput = 0x800000,
    adOpenAsync = 0x1000,
    adDelayFetchStream = 0x4000,
    adDelayFetchFields = 0x8000,
    adOpenExecuteCommand = 0x10000
  } RecordOpenOptionsEnum;
  typedef DECLSPEC_UUID ("00000523-0000-0010-8000-00AA006D2EA4")
  enum IsolationLevelEnum {
    adXactUnspecified = 0xffffffff,
    adXactChaos = 0x10,
    adXactReadUncommitted = 0x100,
    adXactBrowse = 0x100,
    adXactCursorStability = 0x1000,
    adXactReadCommitted = 0x1000,
    adXactRepeatableRead = 0x10000,
    adXactSerializable = 0x100000,
    adXactIsolated = 0x100000
  } IsolationLevelEnum;
  typedef DECLSPEC_UUID ("00000524-0000-0010-8000-00AA006D2EA4")
  enum XactAttributeEnum {
    adXactCommitRetaining = 0x20000,
    adXactAbortRetaining = 0x40000,
    adXactAsyncPhaseOne = 0x80000,
    adXactSyncPhaseOne = 0x100000
  } XactAttributeEnum;
  typedef DECLSPEC_UUID ("00000529-0000-0010-8000-00AA006D2EA4")
  enum PropertyAttributesEnum {
    adPropNotSupported = 0,
    adPropRequired = 0x1,
    adPropOptional = 0x2,
    adPropRead = 0x200,
    adPropWrite = 0x400
  } PropertyAttributesEnum;
  typedef DECLSPEC_UUID ("0000052A-0000-0010-8000-00AA006D2EA4")
  enum ErrorValueEnum {
    adErrProviderFailed = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xbb8),
    adErrInvalidArgument = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xbb9),
    adErrOpeningFile = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xbba),
    adErrReadFile = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xbbb),
    adErrWriteFile = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xbbc),
    adErrNoCurrentRecord = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xbcd),
    adErrIllegalOperation = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xc93),
    adErrCantChangeProvider = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xc94),
    adErrInTransaction = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xcae),
    adErrFeatureNotAvailable = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xcb3),
    adErrItemNotFound = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xcc1),
    adErrObjectInCollection = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xd27),
    adErrObjectNotSet = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xd5c),
    adErrDataConversion = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xd5d),
    adErrObjectClosed = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe78),
    adErrObjectOpen = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe79),
    adErrProviderNotFound = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe7a),
    adErrBoundToCommand = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe7b),
    adErrInvalidParamInfo = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe7c),
    adErrInvalidConnection = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe7d),
    adErrNotReentrant = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe7e),
    adErrStillExecuting = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe7f),
    adErrOperationCancelled = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe80),
    adErrStillConnecting = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe81),
    adErrInvalidTransaction = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe82),
    adErrNotExecuting = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe83),
    adErrUnsafeOperation = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe84),
    adwrnSecurityDialog = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe85),
    adwrnSecurityDialogHeader = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe86),
    adErrIntegrityViolation = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe87),
    adErrPermissionDenied = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe88),
    adErrDataOverflow = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe89),
    adErrSchemaViolation = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe8a),
    adErrSignMismatch = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe8b),
    adErrCantConvertvalue = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe8c),
    adErrCantCreate = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe8d),
    adErrColumnNotOnThisRow = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe8e),
    adErrURLDoesNotExist = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe8f),
    adErrTreePermissionDenied = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe90),
    adErrInvalidURL = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe91),
    adErrResourceLocked = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe92),
    adErrResourceExists = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe93),
    adErrCannotComplete = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe94),
    adErrVolumeNotFound = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe95),
    adErrOutOfSpace = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe96),
    adErrResourceOutOfScope = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe97),
    adErrUnavailable = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe98),
    adErrURLNamedRowDoesNotExist = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe99),
    adErrDelResOutOfScope = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe9a),
    adErrPropInvalidColumn = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe9b),
    adErrPropInvalidOption = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe9c),
    adErrPropInvalidValue = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe9d),
    adErrPropConflicting = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe9e),
    adErrPropNotAllSettable = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xe9f),
    adErrPropNotSet = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea0),
    adErrPropNotSettable = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea1),
    adErrPropNotSupported = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea2),
    adErrCatalogNotSet = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea3),
    adErrCantChangeConnection = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea4),
    adErrFieldsUpdateFailed = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea5),
    adErrDenyNotSupported = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea6),
    adErrDenyTypeNotSupported = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea7),
    adErrProviderNotSpecified = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xea9),
    adErrConnectionStringTooLong = MAKE_HRESULT (SEVERITY_ERROR, FACILITY_CONTROL, 0xeaa)
  } ErrorValueEnum;
  typedef DECLSPEC_UUID ("0000052B-0000-0010-8000-00AA006D2EA4")
  enum ParameterAttributesEnum {
    adParamSigned = 0x10,
    adParamNullable = 0x40,
    adParamLong = 0x80
  } ParameterAttributesEnum;
  typedef DECLSPEC_UUID ("0000052C-0000-0010-8000-00AA006D2EA4")
  enum ParameterDirectionEnum {
    adParamUnknown = 0,
    adParamInput = 0x1,
    adParamOutput = 0x2,
    adParamInputOutput = 0x3,
    adParamReturnValue = 0x4
  } ParameterDirectionEnum;
  typedef DECLSPEC_UUID ("0000052E-0000-0010-8000-00AA006D2EA4")
  enum CommandTypeEnum {
    adCmdUnspecified = -1,
    adCmdUnknown = 0x8,
    adCmdText = 0x1,
    adCmdTable = 0x2,
    adCmdStoredProc = 0x4,
    adCmdFile = 0x100,
    adCmdTableDirect = 0x200
  } CommandTypeEnum;
  typedef DECLSPEC_UUID ("00000530-0000-0010-8000-00AA006D2EA4")
  enum EventStatusEnum {
    adStatusOK = 0x1,
    adStatusErrorsOccurred = 0x2,
    adStatusCantDeny = 0x3,
    adStatusCancel = 0x4,
    adStatusUnwantedEvent = 0x5
  } EventStatusEnum;
  typedef DECLSPEC_UUID ("00000531-0000-0010-8000-00AA006D2EA4")
  enum EventReasonEnum {
    adRsnAddNew = 1,
    adRsnDelete = 2,
    adRsnUpdate = 3,
    adRsnUndoUpdate = 4,
    adRsnUndoAddNew = 5,
    adRsnUndoDelete = 6,
    adRsnRequery = 7,
    adRsnResynch = 8,
    adRsnClose = 9,
    adRsnMove = 10,
    adRsnFirstChange = 11,
    adRsnMoveFirst = 12,
    adRsnMoveNext = 13,
    adRsnMovePrevious = 14,
    adRsnMoveLast = 15
  } EventReasonEnum;
  typedef DECLSPEC_UUID ("00000533-0000-0010-8000-00AA006D2EA4")
  enum SchemaEnum {
    adSchemaProviderSpecific = -1,
    adSchemaAsserts = 0,
    adSchemaCatalogs = 1,
    adSchemaCharacterSets = 2,
    adSchemaCollations = 3,
    adSchemaColumns = 4,
    adSchemaCheckConstraints = 5,
    adSchemaConstraintColumnUsage = 6,
    adSchemaConstraintTableUsage = 7,
    adSchemaKeyColumnUsage = 8,
    adSchemaReferentialContraints = 9,
    adSchemaReferentialConstraints = 9,
    adSchemaTableConstraints = 10,
    adSchemaColumnsDomainUsage = 11,
    adSchemaIndexes = 12,
    adSchemaColumnPrivileges = 13,
    adSchemaTablePrivileges = 14,
    adSchemaUsagePrivileges = 15,
    adSchemaProcedures = 16,
    adSchemaSchemata = 17,
    adSchemaSQLLanguages = 18,
    adSchemaStatistics = 19,
    adSchemaTables = 20,
    adSchemaTranslations = 21,
    adSchemaProviderTypes = 22,
    adSchemaViews = 23,
    adSchemaViewColumnUsage = 24,
    adSchemaViewTableUsage = 25,
    adSchemaProcedureParameters = 26,
    adSchemaForeignKeys = 27,
    adSchemaPrimaryKeys = 28,
    adSchemaProcedureColumns = 29,
    adSchemaDBInfoKeywords = 30,
    adSchemaDBInfoLiterals = 31,
    adSchemaCubes = 32,
    adSchemaDimensions = 33,
    adSchemaHierarchies = 34,
    adSchemaLevels = 35,
    adSchemaMeasures = 36,
    adSchemaProperties = 37,
    adSchemaMembers = 38,
    adSchemaTrustees = 39,
    adSchemaFunctions = 40,
    adSchemaActions = 41,
    adSchemaCommands = 42,
    adSchemaSets = 43
  } SchemaEnum;
  typedef DECLSPEC_UUID ("0000057E-0000-0010-8000-00AA006D2EA4")
  enum FieldStatusEnum {
    adFieldOK = 0,
    adFieldCantConvertValue = 2,
    adFieldIsNull = 3,
    adFieldTruncated = 4,
    adFieldSignMismatch = 5,
    adFieldDataOverflow = 6,
    adFieldCantCreate = 7,
    adFieldUnavailable = 8,
    adFieldPermissionDenied = 9,
    adFieldIntegrityViolation = 10,
    adFieldSchemaViolation = 11,
    adFieldBadStatus = 12,
    adFieldDefault = 13,
    adFieldIgnore = 15,
    adFieldDoesNotExist = 16,
    adFieldInvalidURL = 17,
    adFieldResourceLocked = 18,
    adFieldResourceExists = 19,
    adFieldCannotComplete = 20,
    adFieldVolumeNotFound = 21,
    adFieldOutOfSpace = 22,
    adFieldCannotDeleteSource = 23,
    adFieldReadOnly = 24,
    adFieldResourceOutOfScope = 25,
    adFieldAlreadyExists = 26,
    adFieldPendingInsert = 0x10000,
    adFieldPendingDelete = 0x20000,
    adFieldPendingChange = 0x40000,
    adFieldPendingUnknown = 0x80000,
    adFieldPendingUnknownDelete = 0x100000
  } FieldStatusEnum;
  typedef DECLSPEC_UUID ("00000552-0000-0010-8000-00AA006D2EA4")
  enum SeekEnum {
    adSeekFirstEQ = 0x1,
    adSeekLastEQ = 0x2,
    adSeekAfterEQ = 0x4,
    adSeekAfter = 0x8,
    adSeekBeforeEQ = 0x10,
    adSeekBefore = 0x20
  } SeekEnum;
#ifndef _COMMON_ADC_AND_ADO_PROPS_
#define _COMMON_ADC_AND_ADO_PROPS_
  typedef DECLSPEC_UUID ("0000054A-0000-0010-8000-00AA006D2EA4")
  enum ADCPROP_UPDATECRITERIA_ENUM {
    adCriteriaKey = 0,
    adCriteriaAllCols = 1,
    adCriteriaUpdCols = 2,
    adCriteriaTimeStamp = 3
  } ADCPROP_UPDATECRITERIA_ENUM;
  typedef DECLSPEC_UUID ("0000054B-0000-0010-8000-00AA006D2EA4")
  enum ADCPROP_ASYNCTHREADPRIORITY_ENUM {
    adPriorityLowest = 1,
    adPriorityBelowNormal = 2,
    adPriorityNormal = 3,
    adPriorityAboveNormal = 4,
    adPriorityHighest = 5
  } ADCPROP_ASYNCTHREADPRIORITY_ENUM;
  typedef DECLSPEC_UUID ("00000554-0000-0010-8000-00AA006D2EA4")
  enum ADCPROP_AUTORECALC_ENUM {
    adRecalcUpFront = 0,
    adRecalcAlways = 1
  } ADCPROP_AUTORECALC_ENUM;
  typedef DECLSPEC_UUID ("00000553-0000-0010-8000-00AA006D2EA4")
  enum ADCPROP_UPDATERESYNC_ENUM {
    adResyncNone = 0,
    adResyncAutoIncrement = 1,
    adResyncConflicts = 2,
    adResyncUpdates = 4,
    adResyncInserts = 8,
    adResyncAll = 15
  } ADCPROP_UPDATERESYNC_ENUM;
#endif
  typedef ADCPROP_UPDATERESYNC_ENUM CEResyncEnum;
  typedef DECLSPEC_UUID ("00000573-0000-0010-8000-00AA006D2EA4")
  enum MoveRecordOptionsEnum {
    adMoveUnspecified = -1,
    adMoveOverWrite = 1,
    adMoveDontUpdateLinks = 2,
    adMoveAllowEmulation = 4
  } MoveRecordOptionsEnum;
  typedef DECLSPEC_UUID ("00000574-0000-0010-8000-00AA006D2EA4")
  enum CopyRecordOptionsEnum {
    adCopyUnspecified = -1,
    adCopyOverWrite = 1,
    adCopyAllowEmulation = 4,
    adCopyNonRecursive = 2
  } CopyRecordOptionsEnum;
  typedef DECLSPEC_UUID ("00000576-0000-0010-8000-00AA006D2EA4")
  enum StreamTypeEnum {
    adTypeBinary = 1,
    adTypeText = 2
  } StreamTypeEnum;
  typedef DECLSPEC_UUID ("00000577-0000-0010-8000-00AA006D2EA4")
  enum LineSeparatorEnum {
    adLF = 10,
    adCR = 13,
    adCRLF = -1
  } LineSeparatorEnum;
  typedef DECLSPEC_UUID ("0000057A-0000-0010-8000-00AA006D2EA4")
  enum StreamOpenOptionsEnum {
    adOpenStreamUnspecified = -1,
    adOpenStreamAsync = 1,
    adOpenStreamFromRecord = 4
  } StreamOpenOptionsEnum;
  typedef DECLSPEC_UUID ("0000057B-0000-0010-8000-00AA006D2EA4")
  enum StreamWriteEnum {
    adWriteChar = 0,
    adWriteLine = 1,
    stWriteChar = 0,
    stWriteLine = 1
  } StreamWriteEnum;
  typedef DECLSPEC_UUID ("0000057C-0000-0010-8000-00AA006D2EA4")
  enum SaveOptionsEnum {
    adSaveCreateNotExist = 1,
    adSaveCreateOverWrite = 2
  } SaveOptionsEnum;
  typedef
  enum FieldEnum {
    adDefaultStream = -1,
    adRecordURL = -2
  } FieldEnum;
  typedef
  enum StreamReadEnum {
    adReadAll = -1,
    adReadLine = -2
  } StreamReadEnum;
  typedef DECLSPEC_UUID ("0000057D-0000-0010-8000-00AA006D2EA4")
  enum RecordTypeEnum {
    adSimpleRecord = 0,
    adCollectionRecord = 1,
    adStructDoc = 2
  } RecordTypeEnum;
  EXTERN_C const IID LIBID_ADODB;
#ifndef ___ADOCollection_INTERFACE_DEFINED__
#define ___ADOCollection_INTERFACE_DEFINED__

  EXTERN_C const IID IID__ADOCollection;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000512-0000-0010-8000-00AA006D2EA4")
  _ADOCollection : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Count (long *c) = 0;
    virtual HRESULT STDMETHODCALLTYPE _NewEnum (IUnknown **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Refresh (void) = 0;
  };
#else
  typedef struct _ADOCollectionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOCollection *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOCollection *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOCollection *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOCollection *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOCollection *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOCollection *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOCollection *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (_ADOCollection *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (_ADOCollection *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (_ADOCollection *This);
    END_INTERFACE
  } _ADOCollectionVtbl;
  interface _ADOCollection {
    CONST_VTBL struct _ADOCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _ADOCollection_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _ADOCollection_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _ADOCollection_Release(This) ((This)->lpVtbl ->Release (This))
#define _ADOCollection_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _ADOCollection_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _ADOCollection_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _ADOCollection_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Collection_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define _ADOCollection__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define _ADOCollection_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#endif
#endif
#endif
#ifndef ___ADODynaCollection_INTERFACE_DEFINED__
#define ___ADODynaCollection_INTERFACE_DEFINED__

  EXTERN_C const IID IID__ADODynaCollection;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000513-0000-0010-8000-00AA006D2EA4")
  _ADODynaCollection : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE Append (IDispatch *Object) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Index) = 0;
  };
#else
  typedef struct _ADODynaCollectionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADODynaCollection *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADODynaCollection *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADODynaCollection *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADODynaCollection *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADODynaCollection *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADODynaCollection *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADODynaCollection *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (_ADODynaCollection *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (_ADODynaCollection *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (_ADODynaCollection *This);
    HRESULT (STDMETHODCALLTYPE *Append) (_ADODynaCollection *This, IDispatch *Object);
    HRESULT (STDMETHODCALLTYPE *Delete) (_ADODynaCollection *This, VARIANT Index);
    END_INTERFACE
  } _ADODynaCollectionVtbl;
  interface _ADODynaCollection {
    CONST_VTBL struct _ADODynaCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _ADODynaCollection_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _ADODynaCollection_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _ADODynaCollection_Release(This) ((This)->lpVtbl ->Release (This))
#define _ADODynaCollection_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _ADODynaCollection_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _ADODynaCollection_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _ADODynaCollection_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _DynaCollection_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define _ADODynaCollection__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define _ADODynaCollection_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define _ADODynaCollection_Append(This, Object) ((This)->lpVtbl ->Append (This, Object))
#define _ADODynaCollection_Delete(This, Index) ((This)->lpVtbl ->Delete (This, Index))
#endif
#endif
#endif
#ifndef ___ADO_INTERFACE_DEFINED__
#define ___ADO_INTERFACE_DEFINED__

  EXTERN_C const IID IID__ADO;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000534-0000-0010-8000-00AA006D2EA4")
  _ADO : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Properties (ADOProperties **ppvObject) = 0;
  };
#else
  typedef struct _ADOVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADO *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADO *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADO *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADO *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADO *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADO *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADO *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADO *This, ADOProperties **ppvObject);
    END_INTERFACE
  } _ADOVtbl;
  interface _ADO {
    CONST_VTBL struct _ADOVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _ADO_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _ADO_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _ADO_Release(This) ((This)->lpVtbl ->Release (This))
#define _ADO_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _ADO_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _ADO_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _ADO_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _ADO_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#endif
#endif
#endif
#ifndef __Error_INTERFACE_DEFINED__
#define __Error_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Error;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000500-0000-0010-8000-00AA006D2EA4")
  ADOError : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Number (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Source (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Description (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_HelpFile (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_HelpContext (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_SQLState (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_NativeError (long *pl) = 0;
  };
#else
  typedef struct ErrorVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOError *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOError *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOError *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOError *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOError *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOError *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOError *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Number) (ADOError *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Source) (ADOError *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Description) (ADOError *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_HelpFile) (ADOError *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_HelpContext) (ADOError *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_SQLState) (ADOError *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_NativeError) (ADOError *This, long *pl);
    END_INTERFACE
  } ErrorVtbl;
  interface Error {
    CONST_VTBL struct ErrorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Error_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Error_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Error_Release(This) ((This)->lpVtbl ->Release (This))
#define Error_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Error_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Error_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Error_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Error_get_Number(This, pl) ((This)->lpVtbl ->get_Number (This, pl))
#define Error_get_Source(This, pbstr) ((This)->lpVtbl ->get_Source (This, pbstr))
#define Error_get_Description(This, pbstr) ((This)->lpVtbl ->get_Description (This, pbstr))
#define Error_get_HelpFile(This, pbstr) ((This)->lpVtbl ->get_HelpFile (This, pbstr))
#define Error_get_HelpContext(This, pl) ((This)->lpVtbl ->get_HelpContext (This, pl))
#define Error_get_SQLState(This, pbstr) ((This)->lpVtbl ->get_SQLState (This, pbstr))
#define Error_get_NativeError(This, pl) ((This)->lpVtbl ->get_NativeError (This, pl))
#endif
#endif
#endif
#ifndef __Errors_INTERFACE_DEFINED__
#define __Errors_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Errors;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000501-0000-0010-8000-00AA006D2EA4")
  ADOErrors : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, ADOError **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Clear (void) = 0;
  };
#else
  typedef struct ErrorsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOErrors *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOErrors *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOErrors *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOErrors *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOErrors *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOErrors *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOErrors *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOErrors *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOErrors *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOErrors *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOErrors *This, VARIANT Index, ADOError **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Clear) (ADOErrors *This);
    END_INTERFACE
  } ErrorsVtbl;
  interface Errors {
    CONST_VTBL struct ErrorsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Errors_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Errors_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Errors_Release(This) ((This)->lpVtbl ->Release (This))
#define Errors_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Errors_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Errors_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Errors_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Errors_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Errors__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Errors_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Errors_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#define Errors_Clear(This) ((This)->lpVtbl ->Clear (This))
#endif
#endif
#endif
#ifndef __Command15_INTERFACE_DEFINED__
#define __Command15_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Command15;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001508-0000-0010-8000-00AA006D2EA4")
  Command15 : public _ADO {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_ActiveConnection (_ADOConnection **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ActiveConnection (_ADOConnection *pCon) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ActiveConnection (VARIANT vConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CommandText (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CommandText (BSTR bstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CommandTimeout (LONG *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CommandTimeout (LONG Timeout) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Prepared (VARIANT_BOOL *pfPrepared) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Prepared (VARIANT_BOOL fPrepared) = 0;
    virtual HRESULT STDMETHODCALLTYPE Execute (VARIANT *RecordsAffected, VARIANT *Parameters, long Options, _ADORecordset **ppirs) = 0;
    virtual HRESULT STDMETHODCALLTYPE CreateParameter (BSTR Name, DataTypeEnum Type, ParameterDirectionEnum Direction, long Size, VARIANT Value, _ADOParameter **ppiprm) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Parameters (ADOParameters **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CommandType (CommandTypeEnum lCmdType) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CommandType (CommandTypeEnum *plCmdType) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstrName) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR bstrName) = 0;
  };
#else
  typedef struct Command15Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Command15 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Command15 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Command15 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Command15 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Command15 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Command15 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Command15 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Command15 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (Command15 *This, _ADOConnection **ppvObject);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (Command15 *This, _ADOConnection *pCon);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (Command15 *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_CommandText) (Command15 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_CommandText) (Command15 *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_CommandTimeout) (Command15 *This, LONG *pl);
    HRESULT (STDMETHODCALLTYPE *put_CommandTimeout) (Command15 *This, LONG Timeout);
    HRESULT (STDMETHODCALLTYPE *get_Prepared) (Command15 *This, VARIANT_BOOL *pfPrepared);
    HRESULT (STDMETHODCALLTYPE *put_Prepared) (Command15 *This, VARIANT_BOOL fPrepared);
    HRESULT (STDMETHODCALLTYPE *Execute) (Command15 *This, VARIANT *RecordsAffected, VARIANT *Parameters, long Options, _ADORecordset **ppirs);
    HRESULT (STDMETHODCALLTYPE *CreateParameter) (Command15 *This, BSTR Name, DataTypeEnum Type, ParameterDirectionEnum Direction, long Size, VARIANT Value, _ADOParameter **ppiprm);
    HRESULT (STDMETHODCALLTYPE *get_Parameters) (Command15 *This, ADOParameters **ppvObject);
    HRESULT (STDMETHODCALLTYPE *put_CommandType) (Command15 *This, CommandTypeEnum lCmdType);
    HRESULT (STDMETHODCALLTYPE *get_CommandType) (Command15 *This, CommandTypeEnum *plCmdType);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Command15 *This, BSTR *pbstrName);
    HRESULT (STDMETHODCALLTYPE *put_Name) (Command15 *This, BSTR bstrName);
    END_INTERFACE
  } Command15Vtbl;
  interface Command15 {
    CONST_VTBL struct Command15Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Command15_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Command15_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Command15_Release(This) ((This)->lpVtbl ->Release (This))
#define Command15_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Command15_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Command15_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Command15_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Command15_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Command15_get_ActiveConnection(This, ppvObject) ((This)->lpVtbl ->get_ActiveConnection (This, ppvObject))
#define Command15_putref_ActiveConnection(This, pCon) ((This)->lpVtbl ->putref_ActiveConnection (This, pCon))
#define Command15_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define Command15_get_CommandText(This, pbstr) ((This)->lpVtbl ->get_CommandText (This, pbstr))
#define Command15_put_CommandText(This, bstr) ((This)->lpVtbl ->put_CommandText (This, bstr))
#define Command15_get_CommandTimeout(This, pl) ((This)->lpVtbl ->get_CommandTimeout (This, pl))
#define Command15_put_CommandTimeout(This, Timeout) ((This)->lpVtbl ->put_CommandTimeout (This, Timeout))
#define Command15_get_Prepared(This, pfPrepared) ((This)->lpVtbl ->get_Prepared (This, pfPrepared))
#define Command15_put_Prepared(This, fPrepared) ((This)->lpVtbl ->put_Prepared (This, fPrepared))
#define Command15_Execute(This, RecordsAffected, Parameters, Options, ppirs) ((This)->lpVtbl ->Execute (This, RecordsAffected, Parameters, Options, ppirs))
#define Command15_CreateParameter(This, Name, Type, Direction, Size, Value, ppiprm) ((This)->lpVtbl ->CreateParameter (This, Name, Type, Direction, Size, Value, ppiprm))
#define Command15_get_Parameters(This, ppvObject) ((This)->lpVtbl ->get_Parameters (This, ppvObject))
#define Command15_put_CommandType(This, lCmdType) ((This)->lpVtbl ->put_CommandType (This, lCmdType))
#define Command15_get_CommandType(This, plCmdType) ((This)->lpVtbl ->get_CommandType (This, plCmdType))
#define Command15_get_Name(This, pbstrName) ((This)->lpVtbl ->get_Name (This, pbstrName))
#define Command15_put_Name(This, bstrName) ((This)->lpVtbl ->put_Name (This, bstrName))
#endif
#endif
#endif
#ifndef __Command25_INTERFACE_DEFINED__
#define __Command25_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Command25;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("0000154E-0000-0010-8000-00AA006D2EA4")
  Command25 : public Command15 {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_State (LONG *plObjState) = 0;
    virtual HRESULT STDMETHODCALLTYPE Cancel (void) = 0;
  };
#else
  typedef struct Command25Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Command25 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Command25 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Command25 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Command25 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Command25 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Command25 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Command25 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Command25 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (Command25 *This, _ADOConnection **ppvObject);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (Command25 *This, _ADOConnection *pCon);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (Command25 *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_CommandText) (Command25 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_CommandText) (Command25 *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_CommandTimeout) (Command25 *This, LONG *pl);
    HRESULT (STDMETHODCALLTYPE *put_CommandTimeout) (Command25 *This, LONG Timeout);
    HRESULT (STDMETHODCALLTYPE *get_Prepared) (Command25 *This, VARIANT_BOOL *pfPrepared);
    HRESULT (STDMETHODCALLTYPE *put_Prepared) (Command25 *This, VARIANT_BOOL fPrepared);
    HRESULT (STDMETHODCALLTYPE *Execute) (Command25 *This, VARIANT *RecordsAffected, VARIANT *Parameters, long Options, _ADORecordset **ppirs);
    HRESULT (STDMETHODCALLTYPE *CreateParameter) (Command25 *This, BSTR Name, DataTypeEnum Type, ParameterDirectionEnum Direction, long Size, VARIANT Value, _ADOParameter **ppiprm);
    HRESULT (STDMETHODCALLTYPE *get_Parameters) (Command25 *This, ADOParameters **ppvObject);
    HRESULT (STDMETHODCALLTYPE *put_CommandType) (Command25 *This, CommandTypeEnum lCmdType);
    HRESULT (STDMETHODCALLTYPE *get_CommandType) (Command25 *This, CommandTypeEnum *plCmdType);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Command25 *This, BSTR *pbstrName);
    HRESULT (STDMETHODCALLTYPE *put_Name) (Command25 *This, BSTR bstrName);
    HRESULT (STDMETHODCALLTYPE *get_State) (Command25 *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *Cancel) (Command25 *This);
    END_INTERFACE
  } Command25Vtbl;
  interface Command25 {
    CONST_VTBL struct Command25Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Command25_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Command25_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Command25_Release(This) ((This)->lpVtbl ->Release (This))
#define Command25_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Command25_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Command25_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Command25_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Command25_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Command25_get_ActiveConnection(This, ppvObject) ((This)->lpVtbl ->get_ActiveConnection (This, ppvObject))
#define Command25_putref_ActiveConnection(This, pCon) ((This)->lpVtbl ->putref_ActiveConnection (This, pCon))
#define Command25_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define Command25_get_CommandText(This, pbstr) ((This)->lpVtbl ->get_CommandText (This, pbstr))
#define Command25_put_CommandText(This, bstr) ((This)->lpVtbl ->put_CommandText (This, bstr))
#define Command25_get_CommandTimeout(This, pl) ((This)->lpVtbl ->get_CommandTimeout (This, pl))
#define Command25_put_CommandTimeout(This, Timeout) ((This)->lpVtbl ->put_CommandTimeout (This, Timeout))
#define Command25_get_Prepared(This, pfPrepared) ((This)->lpVtbl ->get_Prepared (This, pfPrepared))
#define Command25_put_Prepared(This, fPrepared) ((This)->lpVtbl ->put_Prepared (This, fPrepared))
#define Command25_Execute(This, RecordsAffected, Parameters, Options, ppirs) ((This)->lpVtbl ->Execute (This, RecordsAffected, Parameters, Options, ppirs))
#define Command25_CreateParameter(This, Name, Type, Direction, Size, Value, ppiprm) ((This)->lpVtbl ->CreateParameter (This, Name, Type, Direction, Size, Value, ppiprm))
#define Command25_get_Parameters(This, ppvObject) ((This)->lpVtbl ->get_Parameters (This, ppvObject))
#define Command25_put_CommandType(This, lCmdType) ((This)->lpVtbl ->put_CommandType (This, lCmdType))
#define Command25_get_CommandType(This, plCmdType) ((This)->lpVtbl ->get_CommandType (This, plCmdType))
#define Command25_get_Name(This, pbstrName) ((This)->lpVtbl ->get_Name (This, pbstrName))
#define Command25_put_Name(This, bstrName) ((This)->lpVtbl ->put_Name (This, bstrName))
#define Command25_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define Command25_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#endif
#endif
#endif
#ifndef ___Command_INTERFACE_DEFINED__
#define ___Command_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Command;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("986761E8-7269-4890-AA65-AD7C03697A6D")
  _ADOCommand : public Command25 {
    public:
    virtual HRESULT __stdcall putref_CommandStream (IUnknown *pStream) = 0;
    virtual HRESULT __stdcall get_CommandStream (VARIANT *pvStream) = 0;
    virtual HRESULT __stdcall put_Dialect (BSTR bstrDialect) = 0;
    virtual HRESULT __stdcall get_Dialect (BSTR *pbstrDialect) = 0;
    virtual HRESULT __stdcall put_NamedParameters (VARIANT_BOOL fNamedParameters) = 0;
    virtual HRESULT __stdcall get_NamedParameters (VARIANT_BOOL *pfNamedParameters) = 0;
  };
#else
  typedef struct _CommandVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOCommand *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOCommand *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOCommand *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOCommand *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOCommand *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOCommand *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOCommand *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOCommand *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (_ADOCommand *This, _ADOConnection **ppvObject);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (_ADOCommand *This, _ADOConnection *pCon);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (_ADOCommand *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_CommandText) (_ADOCommand *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_CommandText) (_ADOCommand *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_CommandTimeout) (_ADOCommand *This, LONG *pl);
    HRESULT (STDMETHODCALLTYPE *put_CommandTimeout) (_ADOCommand *This, LONG Timeout);
    HRESULT (STDMETHODCALLTYPE *get_Prepared) (_ADOCommand *This, VARIANT_BOOL *pfPrepared);
    HRESULT (STDMETHODCALLTYPE *put_Prepared) (_ADOCommand *This, VARIANT_BOOL fPrepared);
    HRESULT (STDMETHODCALLTYPE *Execute) (_ADOCommand *This, VARIANT *RecordsAffected, VARIANT *Parameters, long Options, _ADORecordset **ppirs);
    HRESULT (STDMETHODCALLTYPE *CreateParameter) (_ADOCommand *This, BSTR Name, DataTypeEnum Type, ParameterDirectionEnum Direction, long Size, VARIANT Value, _ADOParameter **ppiprm);
    HRESULT (STDMETHODCALLTYPE *get_Parameters) (_ADOCommand *This, ADOParameters **ppvObject);
    HRESULT (STDMETHODCALLTYPE *put_CommandType) (_ADOCommand *This, CommandTypeEnum lCmdType);
    HRESULT (STDMETHODCALLTYPE *get_CommandType) (_ADOCommand *This, CommandTypeEnum *plCmdType);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOCommand *This, BSTR *pbstrName);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOCommand *This, BSTR bstrName);
    HRESULT (STDMETHODCALLTYPE *get_State) (_ADOCommand *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *Cancel) (_ADOCommand *This);
    HRESULT (__stdcall *putref_CommandADOStream) (_ADOCommand *This, IUnknown *pStream);
    HRESULT (__stdcall *get_CommandStream) (_ADOCommand *This, VARIANT *pvStream);
    HRESULT (__stdcall *put_Dialect) (_ADOCommand *This, BSTR bstrDialect);
    HRESULT (__stdcall *get_Dialect) (_ADOCommand *This, BSTR *pbstrDialect);
    HRESULT (__stdcall *put_NamedParameters) (_ADOCommand *This, VARIANT_BOOL fNamedParameters);
    HRESULT (__stdcall *get_NamedParameters) (_ADOCommand *This, VARIANT_BOOL *pfNamedParameters);
    END_INTERFACE
  } _CommandVtbl;
  interface _Command {
    CONST_VTBL struct _CommandVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _Command_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Command_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Command_Release(This) ((This)->lpVtbl ->Release (This))
#define _Command_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Command_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Command_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Command_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Command_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Command_get_ActiveConnection(This, ppvObject) ((This)->lpVtbl ->get_ActiveConnection (This, ppvObject))
#define _Command_putref_ActiveConnection(This, pCon) ((This)->lpVtbl ->putref_ActiveConnection (This, pCon))
#define _Command_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define _Command_get_CommandText(This, pbstr) ((This)->lpVtbl ->get_CommandText (This, pbstr))
#define _Command_put_CommandText(This, bstr) ((This)->lpVtbl ->put_CommandText (This, bstr))
#define _Command_get_CommandTimeout(This, pl) ((This)->lpVtbl ->get_CommandTimeout (This, pl))
#define _Command_put_CommandTimeout(This, Timeout) ((This)->lpVtbl ->put_CommandTimeout (This, Timeout))
#define _Command_get_Prepared(This, pfPrepared) ((This)->lpVtbl ->get_Prepared (This, pfPrepared))
#define _Command_put_Prepared(This, fPrepared) ((This)->lpVtbl ->put_Prepared (This, fPrepared))
#define _Command_Execute(This, RecordsAffected, Parameters, Options, ppirs) ((This)->lpVtbl ->Execute (This, RecordsAffected, Parameters, Options, ppirs))
#define _Command_CreateParameter(This, Name, Type, Direction, Size, Value, ppiprm) ((This)->lpVtbl ->CreateParameter (This, Name, Type, Direction, Size, Value, ppiprm))
#define _Command_get_Parameters(This, ppvObject) ((This)->lpVtbl ->get_Parameters (This, ppvObject))
#define _Command_put_CommandType(This, lCmdType) ((This)->lpVtbl ->put_CommandType (This, lCmdType))
#define _Command_get_CommandType(This, plCmdType) ((This)->lpVtbl ->get_CommandType (This, plCmdType))
#define _Command_get_Name(This, pbstrName) ((This)->lpVtbl ->get_Name (This, pbstrName))
#define _Command_put_Name(This, bstrName) ((This)->lpVtbl ->put_Name (This, bstrName))
#define _Command_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define _Command_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#define _Command_putref_CommandStream(This, pStream) ((This)->lpVtbl ->putref_CommandStream (This, pStream))
#define _Command_get_CommandStream(This, pvStream) ((This)->lpVtbl ->get_CommandStream (This, pvStream))
#define _Command_put_Dialect(This, bstrDialect) ((This)->lpVtbl ->put_Dialect (This, bstrDialect))
#define _Command_get_Dialect(This, pbstrDialect) ((This)->lpVtbl ->get_Dialect (This, pbstrDialect))
#define _Command_put_NamedParameters(This, fNamedParameters) ((This)->lpVtbl ->put_NamedParameters (This, fNamedParameters))
#define _Command_get_NamedParameters(This, pfNamedParameters) ((This)->lpVtbl ->get_NamedParameters (This, pfNamedParameters))
#endif
#endif
#endif
#ifndef __ConnectionEventsVt_INTERFACE_DEFINED__
#define __ConnectionEventsVt_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ConnectionEventsVt;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001402-0000-0010-8000-00AA006D2EA4")
  ConnectionEventsVt : public IUnknown {
    public:
    virtual HRESULT STDMETHODCALLTYPE InfoMessage (ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE BeginTransComplete (LONG TransactionLevel, ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE CommitTransComplete (ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE RollbackTransComplete (ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE WillExecute (BSTR *Source, CursorTypeEnum *CursorType, LockTypeEnum *LockType, long *Options, EventStatusEnum *adStatus, _ADOCommand *pCommand, _ADORecordset *pRecordset, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE ExecuteComplete (LONG RecordsAffected, ADOError *pError, EventStatusEnum *adStatus, _ADOCommand *pCommand, _ADORecordset *pRecordset, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE WillConnect (BSTR *ConnectionString, BSTR *UserID, BSTR *Password, long *Options, EventStatusEnum *adStatus, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE ConnectComplete (ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE Disconnect (EventStatusEnum *adStatus, _ADOConnection *pConnection) = 0;
  };
#else
  typedef struct ConnectionEventsVtVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ConnectionEventsVt *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ConnectionEventsVt *This);
    ULONG (STDMETHODCALLTYPE *Release) (ConnectionEventsVt *This);
    HRESULT (STDMETHODCALLTYPE *InfoMessage) (ConnectionEventsVt *This, ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *BeginTransComplete) (ConnectionEventsVt *This, LONG TransactionLevel, ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *CommitTransComplete) (ConnectionEventsVt *This, ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *RollbackTransComplete) (ConnectionEventsVt *This, ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *WillExecute) (ConnectionEventsVt *This, BSTR *Source, CursorTypeEnum *CursorType, LockTypeEnum *LockType, long *Options, EventStatusEnum *adStatus, _ADOCommand *pCommand, _ADORecordset *pRecordset, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *ExecuteComplete) (ConnectionEventsVt *This, LONG RecordsAffected, ADOError *pError, EventStatusEnum *adStatus, _ADOCommand *pCommand, _ADORecordset *pRecordset, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *WillConnect) (ConnectionEventsVt *This, BSTR *ConnectionString, BSTR *UserID, BSTR *Password, long *Options, EventStatusEnum *adStatus, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *ConnectComplete) (ConnectionEventsVt *This, ADOError *pError, EventStatusEnum *adStatus, _ADOConnection *pConnection);
    HRESULT (STDMETHODCALLTYPE *Disconnect) (ConnectionEventsVt *This, EventStatusEnum *adStatus, _ADOConnection *pConnection);
    END_INTERFACE
  } ConnectionEventsVtVtbl;
  interface ConnectionEventsVt {
    CONST_VTBL struct ConnectionEventsVtVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ConnectionEventsVt_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ConnectionEventsVt_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ConnectionEventsVt_Release(This) ((This)->lpVtbl ->Release (This))
#define ConnectionEventsVt_InfoMessage(This, pError, adStatus, pConnection) ((This)->lpVtbl ->InfoMessage (This, pError, adStatus, pConnection))
#define ConnectionEventsVt_BeginTransComplete(This, TransactionLevel, pError, adStatus, pConnection) ((This)->lpVtbl ->BeginTransComplete (This, TransactionLevel, pError, adStatus, pConnection))
#define ConnectionEventsVt_CommitTransComplete(This, pError, adStatus, pConnection) ((This)->lpVtbl ->CommitTransComplete (This, pError, adStatus, pConnection))
#define ConnectionEventsVt_RollbackTransComplete(This, pError, adStatus, pConnection) ((This)->lpVtbl ->RollbackTransComplete (This, pError, adStatus, pConnection))
#define ConnectionEventsVt_WillExecute(This, Source, CursorType, LockType, Options, adStatus, pCommand, pRecordset, pConnection) ((This)->lpVtbl ->WillExecute (This, Source, CursorType, LockType, Options, adStatus, pCommand, pRecordset, pConnection))
#define ConnectionEventsVt_ExecuteComplete(This, RecordsAffected, pError, adStatus, pCommand, pRecordset, pConnection) ((This)->lpVtbl ->ExecuteComplete (This, RecordsAffected, pError, adStatus, pCommand, pRecordset, pConnection))
#define ConnectionEventsVt_WillConnect(This, ConnectionString, UserID, Password, Options, adStatus, pConnection) ((This)->lpVtbl ->WillConnect (This, ConnectionString, UserID, Password, Options, adStatus, pConnection))
#define ConnectionEventsVt_ConnectComplete(This, pError, adStatus, pConnection) ((This)->lpVtbl ->ConnectComplete (This, pError, adStatus, pConnection))
#define ConnectionEventsVt_Disconnect(This, adStatus, pConnection) ((This)->lpVtbl ->Disconnect (This, adStatus, pConnection))
#endif
#endif
#endif
#ifndef __RecordsetEventsVt_INTERFACE_DEFINED__
#define __RecordsetEventsVt_INTERFACE_DEFINED__

  EXTERN_C const IID IID_RecordsetEventsVt;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001403-0000-0010-8000-00AA006D2EA4")
  RecordsetEventsVt : public IUnknown {
    public:
    virtual HRESULT STDMETHODCALLTYPE WillChangeField (LONG cFields, VARIANT Fields, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE FieldChangeComplete (LONG cFields, VARIANT Fields, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE WillChangeRecord (EventReasonEnum adReason, LONG cRecords, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE RecordChangeComplete (EventReasonEnum adReason, LONG cRecords, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE WillChangeRecordset (EventReasonEnum adReason, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE RecordsetChangeComplete (EventReasonEnum adReason, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE WillMove (EventReasonEnum adReason, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE MoveComplete (EventReasonEnum adReason, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE EndOfRecordset (VARIANT_BOOL *fMoreData, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE FetchProgress (long Progress, long MaxProgress, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
    virtual HRESULT STDMETHODCALLTYPE FetchComplete (ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset) = 0;
  };
#else
  typedef struct RecordsetEventsVtVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (RecordsetEventsVt *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (RecordsetEventsVt *This);
    ULONG (STDMETHODCALLTYPE *Release) (RecordsetEventsVt *This);
    HRESULT (STDMETHODCALLTYPE *WillChangeADOField) (RecordsetEventsVt *This, LONG cFields, VARIANT Fields, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *FieldChangeComplete) (RecordsetEventsVt *This, LONG cFields, VARIANT Fields, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *WillChangeADORecord) (RecordsetEventsVt *This, EventReasonEnum adReason, LONG cRecords, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *RecordChangeComplete) (RecordsetEventsVt *This, EventReasonEnum adReason, LONG cRecords, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *WillChangeADORecordset) (RecordsetEventsVt *This, EventReasonEnum adReason, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *RecordsetChangeComplete) (RecordsetEventsVt *This, EventReasonEnum adReason, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *WillMove) (RecordsetEventsVt *This, EventReasonEnum adReason, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *MoveComplete) (RecordsetEventsVt *This, EventReasonEnum adReason, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *EndOfADORecordset) (RecordsetEventsVt *This, VARIANT_BOOL *fMoreData, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *FetchProgress) (RecordsetEventsVt *This, long Progress, long MaxProgress, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    HRESULT (STDMETHODCALLTYPE *FetchComplete) (RecordsetEventsVt *This, ADOError *pError, EventStatusEnum *adStatus, _ADORecordset *pRecordset);
    END_INTERFACE
  } RecordsetEventsVtVtbl;
  interface RecordsetEventsVt {
    CONST_VTBL struct RecordsetEventsVtVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define RecordsetEventsVt_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define RecordsetEventsVt_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define RecordsetEventsVt_Release(This) ((This)->lpVtbl ->Release (This))
#define RecordsetEventsVt_WillChangeField(This, cFields, Fields, adStatus, pRecordset) ((This)->lpVtbl ->WillChangeField (This, cFields, Fields, adStatus, pRecordset))
#define RecordsetEventsVt_FieldChangeComplete(This, cFields, Fields, pError, adStatus, pRecordset) ((This)->lpVtbl ->FieldChangeComplete (This, cFields, Fields, pError, adStatus, pRecordset))
#define RecordsetEventsVt_WillChangeRecord(This, adReason, cRecords, adStatus, pRecordset) ((This)->lpVtbl ->WillChangeRecord (This, adReason, cRecords, adStatus, pRecordset))
#define RecordsetEventsVt_RecordChangeComplete(This, adReason, cRecords, pError, adStatus, pRecordset) ((This)->lpVtbl ->RecordChangeComplete (This, adReason, cRecords, pError, adStatus, pRecordset))
#define RecordsetEventsVt_WillChangeRecordset(This, adReason, adStatus, pRecordset) ((This)->lpVtbl ->WillChangeRecordset (This, adReason, adStatus, pRecordset))
#define RecordsetEventsVt_RecordsetChangeComplete(This, adReason, pError, adStatus, pRecordset) ((This)->lpVtbl ->RecordsetChangeComplete (This, adReason, pError, adStatus, pRecordset))
#define RecordsetEventsVt_WillMove(This, adReason, adStatus, pRecordset) ((This)->lpVtbl ->WillMove (This, adReason, adStatus, pRecordset))
#define RecordsetEventsVt_MoveComplete(This, adReason, pError, adStatus, pRecordset) ((This)->lpVtbl ->MoveComplete (This, adReason, pError, adStatus, pRecordset))
#define RecordsetEventsVt_EndOfRecordset(This, fMoreData, adStatus, pRecordset) ((This)->lpVtbl ->EndOfRecordset (This, fMoreData, adStatus, pRecordset))
#define RecordsetEventsVt_FetchProgress(This, Progress, MaxProgress, adStatus, pRecordset) ((This)->lpVtbl ->FetchProgress (This, Progress, MaxProgress, adStatus, pRecordset))
#define RecordsetEventsVt_FetchComplete(This, pError, adStatus, pRecordset) ((This)->lpVtbl ->FetchComplete (This, pError, adStatus, pRecordset))
#endif
#endif
#endif
#ifndef __ConnectionEvents_DISPINTERFACE_DEFINED__
#define __ConnectionEvents_DISPINTERFACE_DEFINED__

  EXTERN_C const IID DIID_ConnectionEvents;
#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00001400-0000-0010-8000-00AA006D2EA4")
  ConnectionEvents : public IDispatch {
  };
#else
  typedef struct ConnectionEventsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ConnectionEvents *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ConnectionEvents *This);
    ULONG (STDMETHODCALLTYPE *Release) (ConnectionEvents *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ConnectionEvents *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ConnectionEvents *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ConnectionEvents *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ConnectionEvents *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    END_INTERFACE
  } ConnectionEventsVtbl;
  interface ConnectionEvents {
    CONST_VTBL struct ConnectionEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ConnectionEvents_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ConnectionEvents_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ConnectionEvents_Release(This) ((This)->lpVtbl ->Release (This))
#define ConnectionEvents_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define ConnectionEvents_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define ConnectionEvents_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define ConnectionEvents_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#endif
#endif
#endif
#ifndef __RecordsetEvents_DISPINTERFACE_DEFINED__
#define __RecordsetEvents_DISPINTERFACE_DEFINED__

  EXTERN_C const IID DIID_RecordsetEvents;
#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00001266-0000-0010-8000-00AA006D2EA4")
  RecordsetEvents : public IDispatch {
  };
#else
  typedef struct RecordsetEventsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (RecordsetEvents *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (RecordsetEvents *This);
    ULONG (STDMETHODCALLTYPE *Release) (RecordsetEvents *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (RecordsetEvents *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (RecordsetEvents *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (RecordsetEvents *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (RecordsetEvents *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    END_INTERFACE
  } RecordsetEventsVtbl;
  interface RecordsetEvents {
    CONST_VTBL struct RecordsetEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define RecordsetEvents_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define RecordsetEvents_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define RecordsetEvents_Release(This) ((This)->lpVtbl ->Release (This))
#define RecordsetEvents_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define RecordsetEvents_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define RecordsetEvents_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define RecordsetEvents_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#endif
#endif
#endif
#ifndef __Connection15_INTERFACE_DEFINED__
#define __Connection15_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Connection15;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001515-0000-0010-8000-00AA006D2EA4")
  Connection15 : public _ADO {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_ConnectionString (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ConnectionString (BSTR bstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CommandTimeout (LONG *plTimeout) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CommandTimeout (LONG lTimeout) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ConnectionTimeout (LONG *plTimeout) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ConnectionTimeout (LONG lTimeout) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Version (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE Close (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE Execute (BSTR CommandText, VARIANT *RecordsAffected, long Options, _ADORecordset **ppiRset) = 0;
    virtual HRESULT STDMETHODCALLTYPE BeginTrans (long *TransactionLevel) = 0;
    virtual HRESULT STDMETHODCALLTYPE CommitTrans (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE RollbackTrans (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE Open (BSTR ConnectionString = NULL, BSTR UserID = NULL, BSTR Password = NULL, long Options = adOptionUnspecified) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Errors (ADOErrors **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DefaultDatabase (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_DefaultDatabase (BSTR bstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_IsolationLevel (IsolationLevelEnum *Level) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_IsolationLevel (IsolationLevelEnum Level) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Attributes (long *plAttr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Attributes (long lAttr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CursorLocation (CursorLocationEnum *plCursorLoc) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CursorLocation (CursorLocationEnum lCursorLoc) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Mode (ConnectModeEnum *plMode) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Mode (ConnectModeEnum lMode) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Provider (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Provider (BSTR Provider) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_State (LONG *plObjState) = 0;
    virtual HRESULT STDMETHODCALLTYPE OpenSchema (SchemaEnum Schema, VARIANT Restrictions, VARIANT SchemaID, _ADORecordset **pprset) = 0;
  };
#else
  typedef struct Connection15Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Connection15 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Connection15 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Connection15 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Connection15 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Connection15 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Connection15 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Connection15 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Connection15 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ConnectionString) (Connection15 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_ConnectionString) (Connection15 *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_CommandTimeout) (Connection15 *This, LONG *plTimeout);
    HRESULT (STDMETHODCALLTYPE *put_CommandTimeout) (Connection15 *This, LONG lTimeout);
    HRESULT (STDMETHODCALLTYPE *get_ConnectionTimeout) (Connection15 *This, LONG *plTimeout);
    HRESULT (STDMETHODCALLTYPE *put_ConnectionTimeout) (Connection15 *This, LONG lTimeout);
    HRESULT (STDMETHODCALLTYPE *get_Version) (Connection15 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *Close) (Connection15 *This);
    HRESULT (STDMETHODCALLTYPE *Execute) (Connection15 *This, BSTR CommandText, VARIANT *RecordsAffected, long Options, _ADORecordset **ppiRset);
    HRESULT (STDMETHODCALLTYPE *BeginTrans) (Connection15 *This, long *TransactionLevel);
    HRESULT (STDMETHODCALLTYPE *CommitTrans) (Connection15 *This);
    HRESULT (STDMETHODCALLTYPE *RollbackTrans) (Connection15 *This);
    HRESULT (STDMETHODCALLTYPE *Open) (Connection15 *This, BSTR ConnectionString, BSTR UserID, BSTR Password, long Options);
    HRESULT (STDMETHODCALLTYPE *get_Errors) (Connection15 *This, ADOErrors **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_DefaultDatabase) (Connection15 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_DefaultDatabase) (Connection15 *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_IsolationLevel) (Connection15 *This, IsolationLevelEnum *Level);
    HRESULT (STDMETHODCALLTYPE *put_IsolationLevel) (Connection15 *This, IsolationLevelEnum Level);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (Connection15 *This, long *plAttr);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (Connection15 *This, long lAttr);
    HRESULT (STDMETHODCALLTYPE *get_CursorLocation) (Connection15 *This, CursorLocationEnum *plCursorLoc);
    HRESULT (STDMETHODCALLTYPE *put_CursorLocation) (Connection15 *This, CursorLocationEnum lCursorLoc);
    HRESULT (STDMETHODCALLTYPE *get_Mode) (Connection15 *This, ConnectModeEnum *plMode);
    HRESULT (STDMETHODCALLTYPE *put_Mode) (Connection15 *This, ConnectModeEnum lMode);
    HRESULT (STDMETHODCALLTYPE *get_Provider) (Connection15 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_Provider) (Connection15 *This, BSTR Provider);
    HRESULT (STDMETHODCALLTYPE *get_State) (Connection15 *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *OpenSchema) (Connection15 *This, SchemaEnum Schema, VARIANT Restrictions, VARIANT SchemaID, _ADORecordset **pprset);
    END_INTERFACE
  } Connection15Vtbl;
  interface Connection15 {
    CONST_VTBL struct Connection15Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Connection15_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Connection15_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Connection15_Release(This) ((This)->lpVtbl ->Release (This))
#define Connection15_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Connection15_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Connection15_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Connection15_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Connection15_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Connection15_get_ConnectionString(This, pbstr) ((This)->lpVtbl ->get_ConnectionString (This, pbstr))
#define Connection15_put_ConnectionString(This, bstr) ((This)->lpVtbl ->put_ConnectionString (This, bstr))
#define Connection15_get_CommandTimeout(This, plTimeout) ((This)->lpVtbl ->get_CommandTimeout (This, plTimeout))
#define Connection15_put_CommandTimeout(This, lTimeout) ((This)->lpVtbl ->put_CommandTimeout (This, lTimeout))
#define Connection15_get_ConnectionTimeout(This, plTimeout) ((This)->lpVtbl ->get_ConnectionTimeout (This, plTimeout))
#define Connection15_put_ConnectionTimeout(This, lTimeout) ((This)->lpVtbl ->put_ConnectionTimeout (This, lTimeout))
#define Connection15_get_Version(This, pbstr) ((This)->lpVtbl ->get_Version (This, pbstr))
#define Connection15_Close(This) ((This)->lpVtbl ->Close (This))
#define Connection15_Execute(This, CommandText, RecordsAffected, Options, ppiRset) ((This)->lpVtbl ->Execute (This, CommandText, RecordsAffected, Options, ppiRset))
#define Connection15_BeginTrans(This, TransactionLevel) ((This)->lpVtbl ->BeginTrans (This, TransactionLevel))
#define Connection15_CommitTrans(This) ((This)->lpVtbl ->CommitTrans (This))
#define Connection15_RollbackTrans(This) ((This)->lpVtbl ->RollbackTrans (This))
#define Connection15_Open(This, ConnectionString, UserID, Password, Options) ((This)->lpVtbl ->Open (This, ConnectionString, UserID, Password, Options))
#define Connection15_get_Errors(This, ppvObject) ((This)->lpVtbl ->get_Errors (This, ppvObject))
#define Connection15_get_DefaultDatabase(This, pbstr) ((This)->lpVtbl ->get_DefaultDatabase (This, pbstr))
#define Connection15_put_DefaultDatabase(This, bstr) ((This)->lpVtbl ->put_DefaultDatabase (This, bstr))
#define Connection15_get_IsolationLevel(This, Level) ((This)->lpVtbl ->get_IsolationLevel (This, Level))
#define Connection15_put_IsolationLevel(This, Level) ((This)->lpVtbl ->put_IsolationLevel (This, Level))
#define Connection15_get_Attributes(This, plAttr) ((This)->lpVtbl ->get_Attributes (This, plAttr))
#define Connection15_put_Attributes(This, lAttr) ((This)->lpVtbl ->put_Attributes (This, lAttr))
#define Connection15_get_CursorLocation(This, plCursorLoc) ((This)->lpVtbl ->get_CursorLocation (This, plCursorLoc))
#define Connection15_put_CursorLocation(This, lCursorLoc) ((This)->lpVtbl ->put_CursorLocation (This, lCursorLoc))
#define Connection15_get_Mode(This, plMode) ((This)->lpVtbl ->get_Mode (This, plMode))
#define Connection15_put_Mode(This, lMode) ((This)->lpVtbl ->put_Mode (This, lMode))
#define Connection15_get_Provider(This, pbstr) ((This)->lpVtbl ->get_Provider (This, pbstr))
#define Connection15_put_Provider(This, Provider) ((This)->lpVtbl ->put_Provider (This, Provider))
#define Connection15_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define Connection15_OpenSchema(This, Schema, Restrictions, SchemaID, pprset) ((This)->lpVtbl ->OpenSchema (This, Schema, Restrictions, SchemaID, pprset))
#endif
#endif
#endif
#ifndef ___Connection_INTERFACE_DEFINED__
#define ___Connection_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Connection;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001550-0000-0010-8000-00AA006D2EA4")
  _ADOConnection : public Connection15 {
    public:
    virtual HRESULT STDMETHODCALLTYPE Cancel (void) = 0;
  };
#else
  typedef struct _ConnectionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOConnection *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOConnection *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOConnection *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOConnection *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOConnection *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOConnection *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOConnection *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOConnection *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ConnectionString) (_ADOConnection *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_ConnectionString) (_ADOConnection *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_CommandTimeout) (_ADOConnection *This, LONG *plTimeout);
    HRESULT (STDMETHODCALLTYPE *put_CommandTimeout) (_ADOConnection *This, LONG lTimeout);
    HRESULT (STDMETHODCALLTYPE *get_ConnectionTimeout) (_ADOConnection *This, LONG *plTimeout);
    HRESULT (STDMETHODCALLTYPE *put_ConnectionTimeout) (_ADOConnection *This, LONG lTimeout);
    HRESULT (STDMETHODCALLTYPE *get_Version) (_ADOConnection *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *Close) (_ADOConnection *This);
    HRESULT (STDMETHODCALLTYPE *Execute) (_ADOConnection *This, BSTR CommandText, VARIANT *RecordsAffected, long Options, _ADORecordset **ppiRset);
    HRESULT (STDMETHODCALLTYPE *BeginTrans) (_ADOConnection *This, long *TransactionLevel);
    HRESULT (STDMETHODCALLTYPE *CommitTrans) (_ADOConnection *This);
    HRESULT (STDMETHODCALLTYPE *RollbackTrans) (_ADOConnection *This);
    HRESULT (STDMETHODCALLTYPE *Open) (_ADOConnection *This, BSTR ConnectionString, BSTR UserID, BSTR Password, long Options);
    HRESULT (STDMETHODCALLTYPE *get_Errors) (_ADOConnection *This, ADOErrors **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_DefaultDatabase) (_ADOConnection *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_DefaultDatabase) (_ADOConnection *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_IsolationLevel) (_ADOConnection *This, IsolationLevelEnum *Level);
    HRESULT (STDMETHODCALLTYPE *put_IsolationLevel) (_ADOConnection *This, IsolationLevelEnum Level);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (_ADOConnection *This, long *plAttr);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (_ADOConnection *This, long lAttr);
    HRESULT (STDMETHODCALLTYPE *get_CursorLocation) (_ADOConnection *This, CursorLocationEnum *plCursorLoc);
    HRESULT (STDMETHODCALLTYPE *put_CursorLocation) (_ADOConnection *This, CursorLocationEnum lCursorLoc);
    HRESULT (STDMETHODCALLTYPE *get_Mode) (_ADOConnection *This, ConnectModeEnum *plMode);
    HRESULT (STDMETHODCALLTYPE *put_Mode) (_ADOConnection *This, ConnectModeEnum lMode);
    HRESULT (STDMETHODCALLTYPE *get_Provider) (_ADOConnection *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_Provider) (_ADOConnection *This, BSTR Provider);
    HRESULT (STDMETHODCALLTYPE *get_State) (_ADOConnection *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *OpenSchema) (_ADOConnection *This, SchemaEnum Schema, VARIANT Restrictions, VARIANT SchemaID, _ADORecordset **pprset);
    HRESULT (STDMETHODCALLTYPE *Cancel) (_ADOConnection *This);
    END_INTERFACE
  } _ConnectionVtbl;
  interface _Connection {
    CONST_VTBL struct _ConnectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _Connection_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Connection_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Connection_Release(This) ((This)->lpVtbl ->Release (This))
#define _Connection_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Connection_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Connection_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Connection_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Connection_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Connection_get_ConnectionString(This, pbstr) ((This)->lpVtbl ->get_ConnectionString (This, pbstr))
#define _Connection_put_ConnectionString(This, bstr) ((This)->lpVtbl ->put_ConnectionString (This, bstr))
#define _Connection_get_CommandTimeout(This, plTimeout) ((This)->lpVtbl ->get_CommandTimeout (This, plTimeout))
#define _Connection_put_CommandTimeout(This, lTimeout) ((This)->lpVtbl ->put_CommandTimeout (This, lTimeout))
#define _Connection_get_ConnectionTimeout(This, plTimeout) ((This)->lpVtbl ->get_ConnectionTimeout (This, plTimeout))
#define _Connection_put_ConnectionTimeout(This, lTimeout) ((This)->lpVtbl ->put_ConnectionTimeout (This, lTimeout))
#define _Connection_get_Version(This, pbstr) ((This)->lpVtbl ->get_Version (This, pbstr))
#define _Connection_Close(This) ((This)->lpVtbl ->Close (This))
#define _Connection_Execute(This, CommandText, RecordsAffected, Options, ppiRset) ((This)->lpVtbl ->Execute (This, CommandText, RecordsAffected, Options, ppiRset))
#define _Connection_BeginTrans(This, TransactionLevel) ((This)->lpVtbl ->BeginTrans (This, TransactionLevel))
#define _Connection_CommitTrans(This) ((This)->lpVtbl ->CommitTrans (This))
#define _Connection_RollbackTrans(This) ((This)->lpVtbl ->RollbackTrans (This))
#define _Connection_Open(This, ConnectionString, UserID, Password, Options) ((This)->lpVtbl ->Open (This, ConnectionString, UserID, Password, Options))
#define _Connection_get_Errors(This, ppvObject) ((This)->lpVtbl ->get_Errors (This, ppvObject))
#define _Connection_get_DefaultDatabase(This, pbstr) ((This)->lpVtbl ->get_DefaultDatabase (This, pbstr))
#define _Connection_put_DefaultDatabase(This, bstr) ((This)->lpVtbl ->put_DefaultDatabase (This, bstr))
#define _Connection_get_IsolationLevel(This, Level) ((This)->lpVtbl ->get_IsolationLevel (This, Level))
#define _Connection_put_IsolationLevel(This, Level) ((This)->lpVtbl ->put_IsolationLevel (This, Level))
#define _Connection_get_Attributes(This, plAttr) ((This)->lpVtbl ->get_Attributes (This, plAttr))
#define _Connection_put_Attributes(This, lAttr) ((This)->lpVtbl ->put_Attributes (This, lAttr))
#define _Connection_get_CursorLocation(This, plCursorLoc) ((This)->lpVtbl ->get_CursorLocation (This, plCursorLoc))
#define _Connection_put_CursorLocation(This, lCursorLoc) ((This)->lpVtbl ->put_CursorLocation (This, lCursorLoc))
#define _Connection_get_Mode(This, plMode) ((This)->lpVtbl ->get_Mode (This, plMode))
#define _Connection_put_Mode(This, lMode) ((This)->lpVtbl ->put_Mode (This, lMode))
#define _Connection_get_Provider(This, pbstr) ((This)->lpVtbl ->get_Provider (This, pbstr))
#define _Connection_put_Provider(This, Provider) ((This)->lpVtbl ->put_Provider (This, Provider))
#define _Connection_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define _Connection_OpenSchema(This, Schema, Restrictions, SchemaID, pprset) ((This)->lpVtbl ->OpenSchema (This, Schema, Restrictions, SchemaID, pprset))
#define _Connection_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#endif
#endif
#endif
#ifndef __ADOConnectionConstruction15_INTERFACE_DEFINED__
#define __ADOConnectionConstruction15_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ADOConnectionConstruction15;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000516-0000-0010-8000-00AA006D2EA4")
  ADOConnectionConstruction15 : public IUnknown {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_DSO (IUnknown **ppDSO) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Session (IUnknown **ppSession) = 0;
    virtual HRESULT STDMETHODCALLTYPE WrapDSOandSession (IUnknown *pDSO, IUnknown *pSession) = 0;
  };
#else
  typedef struct ADOConnectionConstruction15Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOConnectionConstruction15 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOConnectionConstruction15 *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOConnectionConstruction15 *This);
    HRESULT (STDMETHODCALLTYPE *get_DSO) (ADOConnectionConstruction15 *This, IUnknown **ppDSO);
    HRESULT (STDMETHODCALLTYPE *get_Session) (ADOConnectionConstruction15 *This, IUnknown **ppSession);
    HRESULT (STDMETHODCALLTYPE *WrapDSOandSession) (ADOConnectionConstruction15 *This, IUnknown *pDSO, IUnknown *pSession);
    END_INTERFACE
  } ADOConnectionConstruction15Vtbl;
  interface ADOConnectionConstruction15 {
    CONST_VTBL struct ADOConnectionConstruction15Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ADOConnectionConstruction15_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ADOConnectionConstruction15_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ADOConnectionConstruction15_Release(This) ((This)->lpVtbl ->Release (This))
#define ADOConnectionConstruction15_get_DSO(This, ppDSO) ((This)->lpVtbl ->get_DSO (This, ppDSO))
#define ADOConnectionConstruction15_get_Session(This, ppSession) ((This)->lpVtbl ->get_Session (This, ppSession))
#define ADOConnectionConstruction15_WrapDSOandSession(This, pDSO, pSession) ((This)->lpVtbl ->WrapDSOandSession (This, pDSO, pSession))
#endif
#endif
#endif
#ifndef __ADOConnectionConstruction_INTERFACE_DEFINED__
#define __ADOConnectionConstruction_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ADOConnectionConstruction;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000551-0000-0010-8000-00AA006D2EA4")
  ADOConnectionConstruction : public ADOConnectionConstruction15 {
    public:
  };
#else
  typedef struct ADOConnectionConstructionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOConnectionConstruction *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOConnectionConstruction *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOConnectionConstruction *This);
    HRESULT (STDMETHODCALLTYPE *get_DSO) (ADOConnectionConstruction *This, IUnknown **ppDSO);
    HRESULT (STDMETHODCALLTYPE *get_Session) (ADOConnectionConstruction *This, IUnknown **ppSession);
    HRESULT (STDMETHODCALLTYPE *WrapDSOandSession) (ADOConnectionConstruction *This, IUnknown *pDSO, IUnknown *pSession);
    END_INTERFACE
  } ADOConnectionConstructionVtbl;
  interface ADOConnectionConstruction {
    CONST_VTBL struct ADOConnectionConstructionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ADOConnectionConstruction_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ADOConnectionConstruction_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ADOConnectionConstruction_Release(This) ((This)->lpVtbl ->Release (This))
#define ADOConnectionConstruction_get_DSO(This, ppDSO) ((This)->lpVtbl ->get_DSO (This, ppDSO))
#define ADOConnectionConstruction_get_Session(This, ppSession) ((This)->lpVtbl ->get_Session (This, ppSession))
#define ADOConnectionConstruction_WrapDSOandSession(This, pDSO, pSession) ((This)->lpVtbl ->WrapDSOandSession (This, pDSO, pSession))
#endif
#endif
#endif
  EXTERN_C const CLSID CLSID_Connection;
#ifdef __cplusplus
  Connection;
#endif
#ifndef ___Record_INTERFACE_DEFINED__
#define ___Record_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Record;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001562-0000-0010-8000-00AA006D2EA4")
  _ADORecord : public _ADO {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_ActiveConnection (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ActiveConnection (BSTR bstrConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ActiveConnection (_ADOConnection *Con) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_State (ObjectStateEnum *pState) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Source (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Source (BSTR Source) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_Source (IDispatch *Source) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Mode (ConnectModeEnum *pMode) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Mode (ConnectModeEnum Mode) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ParentURL (BSTR *pbstrParentURL) = 0;
    virtual HRESULT STDMETHODCALLTYPE MoveRecord (BSTR Source, BSTR Destination, BSTR UserName, BSTR Password, MoveRecordOptionsEnum Options, VARIANT_BOOL Async, BSTR *pbstrNewURL) = 0;
    virtual HRESULT STDMETHODCALLTYPE CopyRecord (BSTR Source, BSTR Destination, BSTR UserName, BSTR Password, CopyRecordOptionsEnum Options, VARIANT_BOOL Async, BSTR *pbstrNewURL) = 0;
    virtual HRESULT STDMETHODCALLTYPE DeleteRecord (BSTR Source = NULL, VARIANT_BOOL Async = 0) = 0;
    virtual HRESULT STDMETHODCALLTYPE Open (VARIANT Source, VARIANT ActiveConnection, ConnectModeEnum Mode = adModeUnknown, RecordCreateOptionsEnum CreateOptions = adFailIfNotExists, RecordOpenOptionsEnum Options = adOpenRecordUnspecified, BSTR UserName = NULL, BSTR Password = NULL) = 0;
    virtual HRESULT STDMETHODCALLTYPE Close (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Fields (ADOFields **ppFlds) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_RecordType (RecordTypeEnum *pType) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetChildren (_ADORecordset **ppRSet) = 0;
    virtual HRESULT STDMETHODCALLTYPE Cancel (void) = 0;
  };
#else
  typedef struct _RecordVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADORecord *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADORecord *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADORecord *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADORecord *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADORecord *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADORecord *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADORecord *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADORecord *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (_ADORecord *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (_ADORecord *This, BSTR bstrConn);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (_ADORecord *This, _ADOConnection *Con);
    HRESULT (STDMETHODCALLTYPE *get_State) (_ADORecord *This, ObjectStateEnum *pState);
    HRESULT (STDMETHODCALLTYPE *get_Source) (_ADORecord *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Source) (_ADORecord *This, BSTR Source);
    HRESULT (STDMETHODCALLTYPE *putref_Source) (_ADORecord *This, IDispatch *Source);
    HRESULT (STDMETHODCALLTYPE *get_Mode) (_ADORecord *This, ConnectModeEnum *pMode);
    HRESULT (STDMETHODCALLTYPE *put_Mode) (_ADORecord *This, ConnectModeEnum Mode);
    HRESULT (STDMETHODCALLTYPE *get_ParentURL) (_ADORecord *This, BSTR *pbstrParentURL);
    HRESULT (STDMETHODCALLTYPE *MoveADORecord) (_ADORecord *This, BSTR Source, BSTR Destination, BSTR UserName, BSTR Password, MoveRecordOptionsEnum Options, VARIANT_BOOL Async, BSTR *pbstrNewURL);
    HRESULT (STDMETHODCALLTYPE *CopyADORecord) (_ADORecord *This, BSTR Source, BSTR Destination, BSTR UserName, BSTR Password, CopyRecordOptionsEnum Options, VARIANT_BOOL Async, BSTR *pbstrNewURL);
    HRESULT (STDMETHODCALLTYPE *DeleteADORecord) (_ADORecord *This, BSTR Source, VARIANT_BOOL Async);
    HRESULT (STDMETHODCALLTYPE *Open) (_ADORecord *This, VARIANT Source, VARIANT ActiveConnection, ConnectModeEnum Mode, RecordCreateOptionsEnum CreateOptions, RecordOpenOptionsEnum Options, BSTR UserName, BSTR Password);
    HRESULT (STDMETHODCALLTYPE *Close) (_ADORecord *This);
    HRESULT (STDMETHODCALLTYPE *get_Fields) (_ADORecord *This, ADOFields **ppFlds);
    HRESULT (STDMETHODCALLTYPE *get_RecordType) (_ADORecord *This, RecordTypeEnum *pType);
    HRESULT (STDMETHODCALLTYPE *GetChildren) (_ADORecord *This, _ADORecordset **ppRSet);
    HRESULT (STDMETHODCALLTYPE *Cancel) (_ADORecord *This);
    END_INTERFACE
  } _RecordVtbl;
  interface _Record {
    CONST_VTBL struct _RecordVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _Record_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Record_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Record_Release(This) ((This)->lpVtbl ->Release (This))
#define _Record_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Record_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Record_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Record_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Record_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Record_get_ActiveConnection(This, pvar) ((This)->lpVtbl ->get_ActiveConnection (This, pvar))
#define _Record_put_ActiveConnection(This, bstrConn) ((This)->lpVtbl ->put_ActiveConnection (This, bstrConn))
#define _Record_putref_ActiveConnection(This, Con) ((This)->lpVtbl ->putref_ActiveConnection (This, Con))
#define _Record_get_State(This, pState) ((This)->lpVtbl ->get_State (This, pState))
#define _Record_get_Source(This, pvar) ((This)->lpVtbl ->get_Source (This, pvar))
#define _Record_put_Source(This, Source) ((This)->lpVtbl ->put_Source (This, Source))
#define _Record_putref_Source(This, Source) ((This)->lpVtbl ->putref_Source (This, Source))
#define _Record_get_Mode(This, pMode) ((This)->lpVtbl ->get_Mode (This, pMode))
#define _Record_put_Mode(This, Mode) ((This)->lpVtbl ->put_Mode (This, Mode))
#define _Record_get_ParentURL(This, pbstrParentURL) ((This)->lpVtbl ->get_ParentURL (This, pbstrParentURL))
#define _Record_MoveRecord(This, Source, Destination, UserName, Password, Options, Async, pbstrNewURL) ((This)->lpVtbl ->MoveRecord (This, Source, Destination, UserName, Password, Options, Async, pbstrNewURL))
#define _Record_CopyRecord(This, Source, Destination, UserName, Password, Options, Async, pbstrNewURL) ((This)->lpVtbl ->CopyRecord (This, Source, Destination, UserName, Password, Options, Async, pbstrNewURL))
#define _Record_DeleteRecord(This, Source, Async) ((This)->lpVtbl ->DeleteRecord (This, Source, Async))
#define _Record_Open(This, Source, ActiveConnection, Mode, CreateOptions, Options, UserName, Password) ((This)->lpVtbl ->Open (This, Source, ActiveConnection, Mode, CreateOptions, Options, UserName, Password))
#define _Record_Close(This) ((This)->lpVtbl ->Close (This))
#define _Record_get_Fields(This, ppFlds) ((This)->lpVtbl ->get_Fields (This, ppFlds))
#define _Record_get_RecordType(This, pType) ((This)->lpVtbl ->get_RecordType (This, pType))
#define _Record_GetChildren(This, ppRSet) ((This)->lpVtbl ->GetChildren (This, ppRSet))
#define _Record_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#endif
#endif
#endif
  EXTERN_C const CLSID CLSID_Record;
#ifdef __cplusplus
  Record;
#endif
#ifndef ___Stream_INTERFACE_DEFINED__
#define ___Stream_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Stream;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001565-0000-0010-8000-00AA006D2EA4")
  _ADOStream : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Size (long *pSize) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_EOS (VARIANT_BOOL *pEOS) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Position (long *pPos) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Position (long Position) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (StreamTypeEnum *pType) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Type (StreamTypeEnum Type) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_LineSeparator (LineSeparatorEnum *pLS) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_LineSeparator (LineSeparatorEnum LineSeparator) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_State (ObjectStateEnum *pState) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Mode (ConnectModeEnum *pMode) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Mode (ConnectModeEnum Mode) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Charset (BSTR *pbstrCharset) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Charset (BSTR Charset) = 0;
    virtual HRESULT STDMETHODCALLTYPE Read (long NumBytes, VARIANT *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE Open (VARIANT Source, ConnectModeEnum Mode = adModeUnknown, StreamOpenOptionsEnum Options = adOpenStreamUnspecified, BSTR UserName = NULL, BSTR Password = NULL) = 0;
    virtual HRESULT STDMETHODCALLTYPE Close (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE SkipLine (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE Write (VARIANT Buffer) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetEOS (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE CopyTo (_ADOStream *DestStream, long CharNumber = -1) = 0;
    virtual HRESULT STDMETHODCALLTYPE Flush (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE SaveToFile (BSTR FileName, SaveOptionsEnum Options = adSaveCreateNotExist) = 0;
    virtual HRESULT STDMETHODCALLTYPE LoadFromFile (BSTR FileName) = 0;
    virtual HRESULT STDMETHODCALLTYPE ReadText (long NumChars, BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE WriteText (BSTR Data, StreamWriteEnum Options = adWriteChar) = 0;
    virtual HRESULT STDMETHODCALLTYPE Cancel (void) = 0;
  };
#else
  typedef struct _StreamVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOStream *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOStream *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOStream *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOStream *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOStream *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOStream *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOStream *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Size) (_ADOStream *This, long *pSize);
    HRESULT (STDMETHODCALLTYPE *get_EOS) (_ADOStream *This, VARIANT_BOOL *pEOS);
    HRESULT (STDMETHODCALLTYPE *get_Position) (_ADOStream *This, long *pPos);
    HRESULT (STDMETHODCALLTYPE *put_Position) (_ADOStream *This, long Position);
    HRESULT (STDMETHODCALLTYPE *get_Type) (_ADOStream *This, StreamTypeEnum *pType);
    HRESULT (STDMETHODCALLTYPE *put_Type) (_ADOStream *This, StreamTypeEnum Type);
    HRESULT (STDMETHODCALLTYPE *get_LineSeparator) (_ADOStream *This, LineSeparatorEnum *pLS);
    HRESULT (STDMETHODCALLTYPE *put_LineSeparator) (_ADOStream *This, LineSeparatorEnum LineSeparator);
    HRESULT (STDMETHODCALLTYPE *get_State) (_ADOStream *This, ObjectStateEnum *pState);
    HRESULT (STDMETHODCALLTYPE *get_Mode) (_ADOStream *This, ConnectModeEnum *pMode);
    HRESULT (STDMETHODCALLTYPE *put_Mode) (_ADOStream *This, ConnectModeEnum Mode);
    HRESULT (STDMETHODCALLTYPE *get_Charset) (_ADOStream *This, BSTR *pbstrCharset);
    HRESULT (STDMETHODCALLTYPE *put_Charset) (_ADOStream *This, BSTR Charset);
    HRESULT (STDMETHODCALLTYPE *Read) (_ADOStream *This, long NumBytes, VARIANT *pVal);
    HRESULT (STDMETHODCALLTYPE *Open) (_ADOStream *This, VARIANT Source, ConnectModeEnum Mode, StreamOpenOptionsEnum Options, BSTR UserName, BSTR Password);
    HRESULT (STDMETHODCALLTYPE *Close) (_ADOStream *This);
    HRESULT (STDMETHODCALLTYPE *SkipLine) (_ADOStream *This);
    HRESULT (STDMETHODCALLTYPE *Write) (_ADOStream *This, VARIANT Buffer);
    HRESULT (STDMETHODCALLTYPE *SetEOS) (_ADOStream *This);
    HRESULT (STDMETHODCALLTYPE *CopyTo) (_ADOStream *This, _ADOStream *DestStream, long CharNumber);
    HRESULT (STDMETHODCALLTYPE *Flush) (_ADOStream *This);
    HRESULT (STDMETHODCALLTYPE *SaveToFile) (_ADOStream *This, BSTR FileName, SaveOptionsEnum Options);
    HRESULT (STDMETHODCALLTYPE *LoadFromFile) (_ADOStream *This, BSTR FileName);
    HRESULT (STDMETHODCALLTYPE *ReadText) (_ADOStream *This, long NumChars, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *WriteText) (_ADOStream *This, BSTR Data, StreamWriteEnum Options);
    HRESULT (STDMETHODCALLTYPE *Cancel) (_ADOStream *This);
    END_INTERFACE
  } _StreamVtbl;
  interface _Stream {
    CONST_VTBL struct _StreamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _Stream_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Stream_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Stream_Release(This) ((This)->lpVtbl ->Release (This))
#define _Stream_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Stream_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Stream_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Stream_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Stream_get_Size(This, pSize) ((This)->lpVtbl ->get_Size (This, pSize))
#define _Stream_get_EOS(This, pEOS) ((This)->lpVtbl ->get_EOS (This, pEOS))
#define _Stream_get_Position(This, pPos) ((This)->lpVtbl ->get_Position (This, pPos))
#define _Stream_put_Position(This, Position) ((This)->lpVtbl ->put_Position (This, Position))
#define _Stream_get_Type(This, pType) ((This)->lpVtbl ->get_Type (This, pType))
#define _Stream_put_Type(This, Type) ((This)->lpVtbl ->put_Type (This, Type))
#define _Stream_get_LineSeparator(This, pLS) ((This)->lpVtbl ->get_LineSeparator (This, pLS))
#define _Stream_put_LineSeparator(This, LineSeparator) ((This)->lpVtbl ->put_LineSeparator (This, LineSeparator))
#define _Stream_get_State(This, pState) ((This)->lpVtbl ->get_State (This, pState))
#define _Stream_get_Mode(This, pMode) ((This)->lpVtbl ->get_Mode (This, pMode))
#define _Stream_put_Mode(This, Mode) ((This)->lpVtbl ->put_Mode (This, Mode))
#define _Stream_get_Charset(This, pbstrCharset) ((This)->lpVtbl ->get_Charset (This, pbstrCharset))
#define _Stream_put_Charset(This, Charset) ((This)->lpVtbl ->put_Charset (This, Charset))
#define _Stream_Read(This, NumBytes, pVal) ((This)->lpVtbl ->Read (This, NumBytes, pVal))
#define _Stream_Open(This, Source, Mode, Options, UserName, Password) ((This)->lpVtbl ->Open (This, Source, Mode, Options, UserName, Password))
#define _Stream_Close(This) ((This)->lpVtbl ->Close (This))
#define _Stream_SkipLine(This) ((This)->lpVtbl ->SkipLine (This))
#define _Stream_Write(This, Buffer) ((This)->lpVtbl ->Write (This, Buffer))
#define _Stream_SetEOS(This) ((This)->lpVtbl ->SetEOS (This))
#define _Stream_CopyTo(This, DestStream, CharNumber) ((This)->lpVtbl ->CopyTo (This, DestStream, CharNumber))
#define _Stream_Flush(This) ((This)->lpVtbl ->Flush (This))
#define _Stream_SaveToFile(This, FileName, Options) ((This)->lpVtbl ->SaveToFile (This, FileName, Options))
#define _Stream_LoadFromFile(This, FileName) ((This)->lpVtbl ->LoadFromFile (This, FileName))
#define _Stream_ReadText(This, NumChars, pbstr) ((This)->lpVtbl ->ReadText (This, NumChars, pbstr))
#define _Stream_WriteText(This, Data, Options) ((This)->lpVtbl ->WriteText (This, Data, Options))
#define _Stream_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#endif
#endif
#endif
  EXTERN_C const CLSID CLSID_Stream;
#ifdef __cplusplus
  Stream;
#endif
#ifndef __ADORecordConstruction_INTERFACE_DEFINED__
#define __ADORecordConstruction_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ADORecordConstruction;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000567-0000-0010-8000-00AA006D2EA4")
  ADORecordConstruction : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Row (IUnknown **ppRow) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Row (IUnknown *pRow) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ParentRow (IUnknown *pRow) = 0;
  };
#else
  typedef struct ADORecordConstructionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADORecordConstruction *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADORecordConstruction *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADORecordConstruction *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADORecordConstruction *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADORecordConstruction *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADORecordConstruction *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADORecordConstruction *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Row) (ADORecordConstruction *This, IUnknown **ppRow);
    HRESULT (STDMETHODCALLTYPE *put_Row) (ADORecordConstruction *This, IUnknown *pRow);
    HRESULT (STDMETHODCALLTYPE *put_ParentRow) (ADORecordConstruction *This, IUnknown *pRow);
    END_INTERFACE
  } ADORecordConstructionVtbl;
  interface ADORecordConstruction {
    CONST_VTBL struct ADORecordConstructionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ADORecordConstruction_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ADORecordConstruction_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ADORecordConstruction_Release(This) ((This)->lpVtbl ->Release (This))
#define ADORecordConstruction_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define ADORecordConstruction_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define ADORecordConstruction_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define ADORecordConstruction_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define ADORecordConstruction_get_Row(This, ppRow) ((This)->lpVtbl ->get_Row (This, ppRow))
#define ADORecordConstruction_put_Row(This, pRow) ((This)->lpVtbl ->put_Row (This, pRow))
#define ADORecordConstruction_put_ParentRow(This, pRow) ((This)->lpVtbl ->put_ParentRow (This, pRow))
#endif
#endif
#endif
#ifndef __ADOStreamConstruction_INTERFACE_DEFINED__
#define __ADOStreamConstruction_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ADOStreamConstruction;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000568-0000-0010-8000-00AA006D2EA4")
  ADOStreamConstruction : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Stream (IUnknown **ppStm) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Stream (IUnknown *pStm) = 0;
  };
#else
  typedef struct ADOStreamConstructionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOStreamConstruction *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOStreamConstruction *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOStreamConstruction *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOStreamConstruction *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOStreamConstruction *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOStreamConstruction *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOStreamConstruction *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Stream) (ADOStreamConstruction *This, IUnknown **ppStm);
    HRESULT (STDMETHODCALLTYPE *put_Stream) (ADOStreamConstruction *This, IUnknown *pStm);
    END_INTERFACE
  } ADOStreamConstructionVtbl;
  interface ADOStreamConstruction {
    CONST_VTBL struct ADOStreamConstructionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ADOStreamConstruction_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ADOStreamConstruction_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ADOStreamConstruction_Release(This) ((This)->lpVtbl ->Release (This))
#define ADOStreamConstruction_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define ADOStreamConstruction_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define ADOStreamConstruction_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define ADOStreamConstruction_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define ADOStreamConstruction_get_Stream(This, ppStm) ((This)->lpVtbl ->get_Stream (This, ppStm))
#define ADOStreamConstruction_put_Stream(This, pStm) ((This)->lpVtbl ->put_Stream (This, pStm))
#endif
#endif
#endif
#ifndef __ADOCommandConstruction_INTERFACE_DEFINED__
#define __ADOCommandConstruction_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ADOCommandConstruction;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000517-0000-0010-8000-00AA006D2EA4")
  ADOCommandConstruction : public IUnknown {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_OLEDBCommand (IUnknown **ppOLEDBCommand) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_OLEDBCommand (IUnknown *pOLEDBCommand) = 0;
  };
#else
  typedef struct ADOCommandConstructionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOCommandConstruction *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOCommandConstruction *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOCommandConstruction *This);
    HRESULT (STDMETHODCALLTYPE *get_OLEDBCommand) (ADOCommandConstruction *This, IUnknown **ppOLEDBCommand);
    HRESULT (STDMETHODCALLTYPE *put_OLEDBCommand) (ADOCommandConstruction *This, IUnknown *pOLEDBCommand);
    END_INTERFACE
  } ADOCommandConstructionVtbl;
  interface ADOCommandConstruction {
    CONST_VTBL struct ADOCommandConstructionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ADOCommandConstruction_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ADOCommandConstruction_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ADOCommandConstruction_Release(This) ((This)->lpVtbl ->Release (This))
#define ADOCommandConstruction_get_OLEDBCommand(This, ppOLEDBCommand) ((This)->lpVtbl ->get_OLEDBCommand (This, ppOLEDBCommand))
#define ADOCommandConstruction_put_OLEDBCommand(This, pOLEDBCommand) ((This)->lpVtbl ->put_OLEDBCommand (This, pOLEDBCommand))
#endif
#endif
#endif
  EXTERN_C const CLSID CLSID_Command;
#ifdef __cplusplus
  Command;
#endif
  EXTERN_C const CLSID CLSID_Recordset;
#ifdef __cplusplus
  Recordset;
#endif
#ifndef __Recordset15_INTERFACE_DEFINED__
#define __Recordset15_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Recordset15;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("0000150E-0000-0010-8000-00AA006D2EA4")
  Recordset15 : public _ADO {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_AbsolutePosition (PositionEnum *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_AbsolutePosition (PositionEnum Position) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ActiveConnection (IDispatch *pconn) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ActiveConnection (VARIANT vConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ActiveConnection (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_BOF (VARIANT_BOOL *pb) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Bookmark (VARIANT *pvBookmark) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Bookmark (VARIANT vBookmark) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CacheSize (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CacheSize (long CacheSize) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CursorType (CursorTypeEnum *plCursorType) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CursorType (CursorTypeEnum lCursorType) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_EOF (VARIANT_BOOL *pb) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Fields (ADOFields **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_LockType (LockTypeEnum *plLockType) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_LockType (LockTypeEnum lLockType) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_MaxRecords (long *plMaxRecords) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_MaxRecords (long lMaxRecords) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_RecordCount (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_Source (IDispatch *pcmd) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Source (BSTR bstrConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Source (VARIANT *pvSource) = 0;
    virtual HRESULT STDMETHODCALLTYPE AddNew (VARIANT FieldList, VARIANT Values) = 0;
    virtual HRESULT STDMETHODCALLTYPE CancelUpdate (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE Close (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (AffectEnum AffectRecords = adAffectCurrent) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetRows (long Rows, VARIANT Start, VARIANT Fields, VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE Move (long NumRecords, VARIANT Start) = 0;
    virtual HRESULT STDMETHODCALLTYPE MoveNext (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE MovePrevious (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE MoveFirst (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE MoveLast (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE Open (VARIANT Source, VARIANT ActiveConnection, CursorTypeEnum CursorType = adOpenUnspecified, LockTypeEnum LockType = adLockUnspecified, LONG Options = adCmdUnspecified) = 0;
    virtual HRESULT STDMETHODCALLTYPE Requery (LONG Options = adOptionUnspecified) = 0;
    virtual HRESULT STDMETHODCALLTYPE _xResync (AffectEnum AffectRecords = adAffectAll) = 0;
    virtual HRESULT STDMETHODCALLTYPE Update (VARIANT Fields, VARIANT Values) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_AbsolutePage (PositionEnum *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_AbsolutePage (PositionEnum Page) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_EditMode (EditModeEnum *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Filter (VARIANT *Criteria) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Filter (VARIANT Criteria) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_PageCount (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_PageSize (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_PageSize (long PageSize) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Sort (BSTR *Criteria) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Sort (BSTR Criteria) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Status (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_State (LONG *plObjState) = 0;
    virtual HRESULT STDMETHODCALLTYPE _xClone (_ADORecordset **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE UpdateBatch (AffectEnum AffectRecords = adAffectAll) = 0;
    virtual HRESULT STDMETHODCALLTYPE CancelBatch (AffectEnum AffectRecords = adAffectAll) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CursorLocation (CursorLocationEnum *plCursorLoc) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_CursorLocation (CursorLocationEnum lCursorLoc) = 0;
    virtual HRESULT STDMETHODCALLTYPE NextRecordset (VARIANT *RecordsAffected, _ADORecordset **ppiRs) = 0;
    virtual HRESULT STDMETHODCALLTYPE Supports (CursorOptionEnum CursorOptions, VARIANT_BOOL *pb) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Collect (VARIANT Index, VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Collect (VARIANT Index, VARIANT value) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_MarshalOptions (MarshalOptionsEnum *peMarshal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_MarshalOptions (MarshalOptionsEnum eMarshal) = 0;
    virtual HRESULT STDMETHODCALLTYPE Find (BSTR Criteria, long SkipRecords, SearchDirectionEnum SearchDirection, VARIANT Start) = 0;
  };
#else
  typedef struct Recordset15Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Recordset15 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Recordset15 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Recordset15 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Recordset15 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Recordset15 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Recordset15 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Recordset15 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Recordset15 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePosition) (Recordset15 *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePosition) (Recordset15 *This, PositionEnum Position);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (Recordset15 *This, IDispatch *pconn);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (Recordset15 *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (Recordset15 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_BOF) (Recordset15 *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Bookmark) (Recordset15 *This, VARIANT *pvBookmark);
    HRESULT (STDMETHODCALLTYPE *put_Bookmark) (Recordset15 *This, VARIANT vBookmark);
    HRESULT (STDMETHODCALLTYPE *get_CacheSize) (Recordset15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_CacheSize) (Recordset15 *This, long CacheSize);
    HRESULT (STDMETHODCALLTYPE *get_CursorType) (Recordset15 *This, CursorTypeEnum *plCursorType);
    HRESULT (STDMETHODCALLTYPE *put_CursorType) (Recordset15 *This, CursorTypeEnum lCursorType);
    HRESULT (STDMETHODCALLTYPE *get_EOF) (Recordset15 *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Fields) (Recordset15 *This, ADOFields **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_LockType) (Recordset15 *This, LockTypeEnum *plLockType);
    HRESULT (STDMETHODCALLTYPE *put_LockType) (Recordset15 *This, LockTypeEnum lLockType);
    HRESULT (STDMETHODCALLTYPE *get_MaxRecords) (Recordset15 *This, long *plMaxRecords);
    HRESULT (STDMETHODCALLTYPE *put_MaxRecords) (Recordset15 *This, long lMaxRecords);
    HRESULT (STDMETHODCALLTYPE *get_RecordCount) (Recordset15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *putref_Source) (Recordset15 *This, IDispatch *pcmd);
    HRESULT (STDMETHODCALLTYPE *put_Source) (Recordset15 *This, BSTR bstrConn);
    HRESULT (STDMETHODCALLTYPE *get_Source) (Recordset15 *This, VARIANT *pvSource);
    HRESULT (STDMETHODCALLTYPE *AddNew) (Recordset15 *This, VARIANT FieldList, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *CancelUpdate) (Recordset15 *This);
    HRESULT (STDMETHODCALLTYPE *Close) (Recordset15 *This);
    HRESULT (STDMETHODCALLTYPE *Delete) (Recordset15 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *GetRows) (Recordset15 *This, long Rows, VARIANT Start, VARIANT Fields, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *Move) (Recordset15 *This, long NumRecords, VARIANT Start);
    HRESULT (STDMETHODCALLTYPE *MoveNext) (Recordset15 *This);
    HRESULT (STDMETHODCALLTYPE *MovePrevious) (Recordset15 *This);
    HRESULT (STDMETHODCALLTYPE *MoveFirst) (Recordset15 *This);
    HRESULT (STDMETHODCALLTYPE *MoveLast) (Recordset15 *This);
    HRESULT (STDMETHODCALLTYPE *Open) (Recordset15 *This, VARIANT Source, VARIANT ActiveConnection, CursorTypeEnum CursorType, LockTypeEnum LockType, LONG Options);
    HRESULT (STDMETHODCALLTYPE *Requery) (Recordset15 *This, LONG Options);
    HRESULT (STDMETHODCALLTYPE *_xResync) (Recordset15 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *Update) (Recordset15 *This, VARIANT Fields, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePage) (Recordset15 *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePage) (Recordset15 *This, PositionEnum Page);
    HRESULT (STDMETHODCALLTYPE *get_EditMode) (Recordset15 *This, EditModeEnum *pl);
    HRESULT (STDMETHODCALLTYPE *get_Filter) (Recordset15 *This, VARIANT *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Filter) (Recordset15 *This, VARIANT Criteria);
    HRESULT (STDMETHODCALLTYPE *get_PageCount) (Recordset15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_PageSize) (Recordset15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_PageSize) (Recordset15 *This, long PageSize);
    HRESULT (STDMETHODCALLTYPE *get_Sort) (Recordset15 *This, BSTR *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Sort) (Recordset15 *This, BSTR Criteria);
    HRESULT (STDMETHODCALLTYPE *get_Status) (Recordset15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_State) (Recordset15 *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *_xClone) (Recordset15 *This, _ADORecordset **ppvObject);
    HRESULT (STDMETHODCALLTYPE *UpdateBatch) (Recordset15 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *CancelBatch) (Recordset15 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *get_CursorLocation) (Recordset15 *This, CursorLocationEnum *plCursorLoc);
    HRESULT (STDMETHODCALLTYPE *put_CursorLocation) (Recordset15 *This, CursorLocationEnum lCursorLoc);
    HRESULT (STDMETHODCALLTYPE *NextADORecordset) (Recordset15 *This, VARIANT *RecordsAffected, _ADORecordset **ppiRs);
    HRESULT (STDMETHODCALLTYPE *Supports) (Recordset15 *This, CursorOptionEnum CursorOptions, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Collect) (Recordset15 *This, VARIANT Index, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Collect) (Recordset15 *This, VARIANT Index, VARIANT value);
    HRESULT (STDMETHODCALLTYPE *get_MarshalOptions) (Recordset15 *This, MarshalOptionsEnum *peMarshal);
    HRESULT (STDMETHODCALLTYPE *put_MarshalOptions) (Recordset15 *This, MarshalOptionsEnum eMarshal);
    HRESULT (STDMETHODCALLTYPE *Find) (Recordset15 *This, BSTR Criteria, long SkipRecords, SearchDirectionEnum SearchDirection, VARIANT Start);
    END_INTERFACE
  } Recordset15Vtbl;
  interface Recordset15 {
    CONST_VTBL struct Recordset15Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Recordset15_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Recordset15_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Recordset15_Release(This) ((This)->lpVtbl ->Release (This))
#define Recordset15_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Recordset15_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Recordset15_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Recordset15_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Recordset15_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Recordset15_get_AbsolutePosition(This, pl) ((This)->lpVtbl ->get_AbsolutePosition (This, pl))
#define Recordset15_put_AbsolutePosition(This, Position) ((This)->lpVtbl ->put_AbsolutePosition (This, Position))
#define Recordset15_putref_ActiveConnection(This, pconn) ((This)->lpVtbl ->putref_ActiveConnection (This, pconn))
#define Recordset15_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define Recordset15_get_ActiveConnection(This, pvar) ((This)->lpVtbl ->get_ActiveConnection (This, pvar))
#define Recordset15_get_BOF(This, pb) ((This)->lpVtbl ->get_BOF (This, pb))
#define Recordset15_get_Bookmark(This, pvBookmark) ((This)->lpVtbl ->get_Bookmark (This, pvBookmark))
#define Recordset15_put_Bookmark(This, vBookmark) ((This)->lpVtbl ->put_Bookmark (This, vBookmark))
#define Recordset15_get_CacheSize(This, pl) ((This)->lpVtbl ->get_CacheSize (This, pl))
#define Recordset15_put_CacheSize(This, CacheSize) ((This)->lpVtbl ->put_CacheSize (This, CacheSize))
#define Recordset15_get_CursorType(This, plCursorType) ((This)->lpVtbl ->get_CursorType (This, plCursorType))
#define Recordset15_put_CursorType(This, lCursorType) ((This)->lpVtbl ->put_CursorType (This, lCursorType))
#define Recordset15_get_EOF(This, pb) ((This)->lpVtbl ->get_EOF (This, pb))
#define Recordset15_get_Fields(This, ppvObject) ((This)->lpVtbl ->get_Fields (This, ppvObject))
#define Recordset15_get_LockType(This, plLockType) ((This)->lpVtbl ->get_LockType (This, plLockType))
#define Recordset15_put_LockType(This, lLockType) ((This)->lpVtbl ->put_LockType (This, lLockType))
#define Recordset15_get_MaxRecords(This, plMaxRecords) ((This)->lpVtbl ->get_MaxRecords (This, plMaxRecords))
#define Recordset15_put_MaxRecords(This, lMaxRecords) ((This)->lpVtbl ->put_MaxRecords (This, lMaxRecords))
#define Recordset15_get_RecordCount(This, pl) ((This)->lpVtbl ->get_RecordCount (This, pl))
#define Recordset15_putref_Source(This, pcmd) ((This)->lpVtbl ->putref_Source (This, pcmd))
#define Recordset15_put_Source(This, bstrConn) ((This)->lpVtbl ->put_Source (This, bstrConn))
#define Recordset15_get_Source(This, pvSource) ((This)->lpVtbl ->get_Source (This, pvSource))
#define Recordset15_AddNew(This, FieldList, Values) ((This)->lpVtbl ->AddNew (This, FieldList, Values))
#define Recordset15_CancelUpdate(This) ((This)->lpVtbl ->CancelUpdate (This))
#define Recordset15_Close(This) ((This)->lpVtbl ->Close (This))
#define Recordset15_Delete(This, AffectRecords) ((This)->lpVtbl ->Delete (This, AffectRecords))
#define Recordset15_GetRows(This, Rows, Start, Fields, pvar) ((This)->lpVtbl ->GetRows (This, Rows, Start, Fields, pvar))
#define Recordset15_Move(This, NumRecords, Start) ((This)->lpVtbl ->Move (This, NumRecords, Start))
#define Recordset15_MoveNext(This) ((This)->lpVtbl ->MoveNext (This))
#define Recordset15_MovePrevious(This) ((This)->lpVtbl ->MovePrevious (This))
#define Recordset15_MoveFirst(This) ((This)->lpVtbl ->MoveFirst (This))
#define Recordset15_MoveLast(This) ((This)->lpVtbl ->MoveLast (This))
#define Recordset15_Open(This, Source, ActiveConnection, CursorType, LockType, Options) ((This)->lpVtbl ->Open (This, Source, ActiveConnection, CursorType, LockType, Options))
#define Recordset15_Requery(This, Options) ((This)->lpVtbl ->Requery (This, Options))
#define Recordset15__xResync(This, AffectRecords) ((This)->lpVtbl ->_xResync (This, AffectRecords))
#define Recordset15_Update(This, Fields, Values) ((This)->lpVtbl ->Update (This, Fields, Values))
#define Recordset15_get_AbsolutePage(This, pl) ((This)->lpVtbl ->get_AbsolutePage (This, pl))
#define Recordset15_put_AbsolutePage(This, Page) ((This)->lpVtbl ->put_AbsolutePage (This, Page))
#define Recordset15_get_EditMode(This, pl) ((This)->lpVtbl ->get_EditMode (This, pl))
#define Recordset15_get_Filter(This, Criteria) ((This)->lpVtbl ->get_Filter (This, Criteria))
#define Recordset15_put_Filter(This, Criteria) ((This)->lpVtbl ->put_Filter (This, Criteria))
#define Recordset15_get_PageCount(This, pl) ((This)->lpVtbl ->get_PageCount (This, pl))
#define Recordset15_get_PageSize(This, pl) ((This)->lpVtbl ->get_PageSize (This, pl))
#define Recordset15_put_PageSize(This, PageSize) ((This)->lpVtbl ->put_PageSize (This, PageSize))
#define Recordset15_get_Sort(This, Criteria) ((This)->lpVtbl ->get_Sort (This, Criteria))
#define Recordset15_put_Sort(This, Criteria) ((This)->lpVtbl ->put_Sort (This, Criteria))
#define Recordset15_get_Status(This, pl) ((This)->lpVtbl ->get_Status (This, pl))
#define Recordset15_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define Recordset15__xClone(This, ppvObject) ((This)->lpVtbl ->_xClone (This, ppvObject))
#define Recordset15_UpdateBatch(This, AffectRecords) ((This)->lpVtbl ->UpdateBatch (This, AffectRecords))
#define Recordset15_CancelBatch(This, AffectRecords) ((This)->lpVtbl ->CancelBatch (This, AffectRecords))
#define Recordset15_get_CursorLocation(This, plCursorLoc) ((This)->lpVtbl ->get_CursorLocation (This, plCursorLoc))
#define Recordset15_put_CursorLocation(This, lCursorLoc) ((This)->lpVtbl ->put_CursorLocation (This, lCursorLoc))
#define Recordset15_NextRecordset(This, RecordsAffected, ppiRs) ((This)->lpVtbl ->NextRecordset (This, RecordsAffected, ppiRs))
#define Recordset15_Supports(This, CursorOptions, pb) ((This)->lpVtbl ->Supports (This, CursorOptions, pb))
#define Recordset15_get_Collect(This, Index, pvar) ((This)->lpVtbl ->get_Collect (This, Index, pvar))
#define Recordset15_put_Collect(This, Index, value) ((This)->lpVtbl ->put_Collect (This, Index, value))
#define Recordset15_get_MarshalOptions(This, peMarshal) ((This)->lpVtbl ->get_MarshalOptions (This, peMarshal))
#define Recordset15_put_MarshalOptions(This, eMarshal) ((This)->lpVtbl ->put_MarshalOptions (This, eMarshal))
#define Recordset15_Find(This, Criteria, SkipRecords, SearchDirection, Start) ((This)->lpVtbl ->Find (This, Criteria, SkipRecords, SearchDirection, Start))
#endif
#endif
#endif
#ifndef __Recordset20_INTERFACE_DEFINED__
#define __Recordset20_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Recordset20;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("0000154F-0000-0010-8000-00AA006D2EA4")
  Recordset20 : public Recordset15 {
    public:
    virtual HRESULT STDMETHODCALLTYPE Cancel (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DataSource (IUnknown **ppunkDataSource) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_DataSource (IUnknown *punkDataSource) = 0;
    virtual HRESULT STDMETHODCALLTYPE _xSave (BSTR FileName = NULL, PersistFormatEnum PersistFormat = adPersistADTG) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ActiveCommand (IDispatch **ppCmd) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_StayInSync (VARIANT_BOOL bStayInSync) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_StayInSync (VARIANT_BOOL *pbStayInSync) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetString (StringFormatEnum StringFormat, long NumRows, BSTR ColumnDelimeter, BSTR RowDelimeter, BSTR NullExpr, BSTR *pRetString) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DataMember (BSTR *pbstrDataMember) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_DataMember (BSTR bstrDataMember) = 0;
    virtual HRESULT STDMETHODCALLTYPE CompareBookmarks (VARIANT Bookmark1, VARIANT Bookmark2, CompareEnum *pCompare) = 0;
    virtual HRESULT STDMETHODCALLTYPE Clone (LockTypeEnum LockType, _ADORecordset **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Resync (AffectEnum AffectRecords = adAffectAll, ResyncEnum ResyncValues = adResyncAllValues) = 0;
  };
#else
  typedef struct Recordset20Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Recordset20 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Recordset20 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Recordset20 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Recordset20 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Recordset20 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Recordset20 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Recordset20 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePosition) (Recordset20 *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePosition) (Recordset20 *This, PositionEnum Position);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (Recordset20 *This, IDispatch *pconn);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (Recordset20 *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (Recordset20 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_BOF) (Recordset20 *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Bookmark) (Recordset20 *This, VARIANT *pvBookmark);
    HRESULT (STDMETHODCALLTYPE *put_Bookmark) (Recordset20 *This, VARIANT vBookmark);
    HRESULT (STDMETHODCALLTYPE *get_CacheSize) (Recordset20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_CacheSize) (Recordset20 *This, long CacheSize);
    HRESULT (STDMETHODCALLTYPE *get_CursorType) (Recordset20 *This, CursorTypeEnum *plCursorType);
    HRESULT (STDMETHODCALLTYPE *put_CursorType) (Recordset20 *This, CursorTypeEnum lCursorType);
    HRESULT (STDMETHODCALLTYPE *get_EOF) (Recordset20 *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Fields) (Recordset20 *This, ADOFields **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_LockType) (Recordset20 *This, LockTypeEnum *plLockType);
    HRESULT (STDMETHODCALLTYPE *put_LockType) (Recordset20 *This, LockTypeEnum lLockType);
    HRESULT (STDMETHODCALLTYPE *get_MaxRecords) (Recordset20 *This, long *plMaxRecords);
    HRESULT (STDMETHODCALLTYPE *put_MaxRecords) (Recordset20 *This, long lMaxRecords);
    HRESULT (STDMETHODCALLTYPE *get_RecordCount) (Recordset20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *putref_Source) (Recordset20 *This, IDispatch *pcmd);
    HRESULT (STDMETHODCALLTYPE *put_Source) (Recordset20 *This, BSTR bstrConn);
    HRESULT (STDMETHODCALLTYPE *get_Source) (Recordset20 *This, VARIANT *pvSource);
    HRESULT (STDMETHODCALLTYPE *AddNew) (Recordset20 *This, VARIANT FieldList, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *CancelUpdate) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *Close) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *Delete) (Recordset20 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *GetRows) (Recordset20 *This, long Rows, VARIANT Start, VARIANT Fields, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *Move) (Recordset20 *This, long NumRecords, VARIANT Start);
    HRESULT (STDMETHODCALLTYPE *MoveNext) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *MovePrevious) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *MoveFirst) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *MoveLast) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *Open) (Recordset20 *This, VARIANT Source, VARIANT ActiveConnection, CursorTypeEnum CursorType, LockTypeEnum LockType, LONG Options);
    HRESULT (STDMETHODCALLTYPE *Requery) (Recordset20 *This, LONG Options);
    HRESULT (STDMETHODCALLTYPE *_xResync) (Recordset20 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *Update) (Recordset20 *This, VARIANT Fields, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePage) (Recordset20 *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePage) (Recordset20 *This, PositionEnum Page);
    HRESULT (STDMETHODCALLTYPE *get_EditMode) (Recordset20 *This, EditModeEnum *pl);
    HRESULT (STDMETHODCALLTYPE *get_Filter) (Recordset20 *This, VARIANT *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Filter) (Recordset20 *This, VARIANT Criteria);
    HRESULT (STDMETHODCALLTYPE *get_PageCount) (Recordset20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_PageSize) (Recordset20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_PageSize) (Recordset20 *This, long PageSize);
    HRESULT (STDMETHODCALLTYPE *get_Sort) (Recordset20 *This, BSTR *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Sort) (Recordset20 *This, BSTR Criteria);
    HRESULT (STDMETHODCALLTYPE *get_Status) (Recordset20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_State) (Recordset20 *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *_xClone) (Recordset20 *This, _ADORecordset **ppvObject);
    HRESULT (STDMETHODCALLTYPE *UpdateBatch) (Recordset20 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *CancelBatch) (Recordset20 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *get_CursorLocation) (Recordset20 *This, CursorLocationEnum *plCursorLoc);
    HRESULT (STDMETHODCALLTYPE *put_CursorLocation) (Recordset20 *This, CursorLocationEnum lCursorLoc);
    HRESULT (STDMETHODCALLTYPE *NextADORecordset) (Recordset20 *This, VARIANT *RecordsAffected, _ADORecordset **ppiRs);
    HRESULT (STDMETHODCALLTYPE *Supports) (Recordset20 *This, CursorOptionEnum CursorOptions, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Collect) (Recordset20 *This, VARIANT Index, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Collect) (Recordset20 *This, VARIANT Index, VARIANT value);
    HRESULT (STDMETHODCALLTYPE *get_MarshalOptions) (Recordset20 *This, MarshalOptionsEnum *peMarshal);
    HRESULT (STDMETHODCALLTYPE *put_MarshalOptions) (Recordset20 *This, MarshalOptionsEnum eMarshal);
    HRESULT (STDMETHODCALLTYPE *Find) (Recordset20 *This, BSTR Criteria, long SkipRecords, SearchDirectionEnum SearchDirection, VARIANT Start);
    HRESULT (STDMETHODCALLTYPE *Cancel) (Recordset20 *This);
    HRESULT (STDMETHODCALLTYPE *get_DataSource) (Recordset20 *This, IUnknown **ppunkDataSource);
    HRESULT (STDMETHODCALLTYPE *putref_DataSource) (Recordset20 *This, IUnknown *punkDataSource);
    HRESULT (STDMETHODCALLTYPE *_xSave) (Recordset20 *This, BSTR FileName, PersistFormatEnum PersistFormat);
    HRESULT (STDMETHODCALLTYPE *get_ActiveCommand) (Recordset20 *This, IDispatch **ppCmd);
    HRESULT (STDMETHODCALLTYPE *put_StayInSync) (Recordset20 *This, VARIANT_BOOL bStayInSync);
    HRESULT (STDMETHODCALLTYPE *get_StayInSync) (Recordset20 *This, VARIANT_BOOL *pbStayInSync);
    HRESULT (STDMETHODCALLTYPE *GetString) (Recordset20 *This, StringFormatEnum StringFormat, long NumRows, BSTR ColumnDelimeter, BSTR RowDelimeter, BSTR NullExpr, BSTR *pRetString);
    HRESULT (STDMETHODCALLTYPE *get_DataMember) (Recordset20 *This, BSTR *pbstrDataMember);
    HRESULT (STDMETHODCALLTYPE *put_DataMember) (Recordset20 *This, BSTR bstrDataMember);
    HRESULT (STDMETHODCALLTYPE *CompareBookmarks) (Recordset20 *This, VARIANT Bookmark1, VARIANT Bookmark2, CompareEnum *pCompare);
    HRESULT (STDMETHODCALLTYPE *Clone) (Recordset20 *This, LockTypeEnum LockType, _ADORecordset **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Resync) (Recordset20 *This, AffectEnum AffectRecords, ResyncEnum ResyncValues);
    END_INTERFACE
  } Recordset20Vtbl;
  interface Recordset20 {
    CONST_VTBL struct Recordset20Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Recordset20_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Recordset20_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Recordset20_Release(This) ((This)->lpVtbl ->Release (This))
#define Recordset20_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Recordset20_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Recordset20_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Recordset20_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Recordset20_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Recordset20_get_AbsolutePosition(This, pl) ((This)->lpVtbl ->get_AbsolutePosition (This, pl))
#define Recordset20_put_AbsolutePosition(This, Position) ((This)->lpVtbl ->put_AbsolutePosition (This, Position))
#define Recordset20_putref_ActiveConnection(This, pconn) ((This)->lpVtbl ->putref_ActiveConnection (This, pconn))
#define Recordset20_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define Recordset20_get_ActiveConnection(This, pvar) ((This)->lpVtbl ->get_ActiveConnection (This, pvar))
#define Recordset20_get_BOF(This, pb) ((This)->lpVtbl ->get_BOF (This, pb))
#define Recordset20_get_Bookmark(This, pvBookmark) ((This)->lpVtbl ->get_Bookmark (This, pvBookmark))
#define Recordset20_put_Bookmark(This, vBookmark) ((This)->lpVtbl ->put_Bookmark (This, vBookmark))
#define Recordset20_get_CacheSize(This, pl) ((This)->lpVtbl ->get_CacheSize (This, pl))
#define Recordset20_put_CacheSize(This, CacheSize) ((This)->lpVtbl ->put_CacheSize (This, CacheSize))
#define Recordset20_get_CursorType(This, plCursorType) ((This)->lpVtbl ->get_CursorType (This, plCursorType))
#define Recordset20_put_CursorType(This, lCursorType) ((This)->lpVtbl ->put_CursorType (This, lCursorType))
#define Recordset20_get_EOF(This, pb) ((This)->lpVtbl ->get_EOF (This, pb))
#define Recordset20_get_Fields(This, ppvObject) ((This)->lpVtbl ->get_Fields (This, ppvObject))
#define Recordset20_get_LockType(This, plLockType) ((This)->lpVtbl ->get_LockType (This, plLockType))
#define Recordset20_put_LockType(This, lLockType) ((This)->lpVtbl ->put_LockType (This, lLockType))
#define Recordset20_get_MaxRecords(This, plMaxRecords) ((This)->lpVtbl ->get_MaxRecords (This, plMaxRecords))
#define Recordset20_put_MaxRecords(This, lMaxRecords) ((This)->lpVtbl ->put_MaxRecords (This, lMaxRecords))
#define Recordset20_get_RecordCount(This, pl) ((This)->lpVtbl ->get_RecordCount (This, pl))
#define Recordset20_putref_Source(This, pcmd) ((This)->lpVtbl ->putref_Source (This, pcmd))
#define Recordset20_put_Source(This, bstrConn) ((This)->lpVtbl ->put_Source (This, bstrConn))
#define Recordset20_get_Source(This, pvSource) ((This)->lpVtbl ->get_Source (This, pvSource))
#define Recordset20_AddNew(This, FieldList, Values) ((This)->lpVtbl ->AddNew (This, FieldList, Values))
#define Recordset20_CancelUpdate(This) ((This)->lpVtbl ->CancelUpdate (This))
#define Recordset20_Close(This) ((This)->lpVtbl ->Close (This))
#define Recordset20_Delete(This, AffectRecords) ((This)->lpVtbl ->Delete (This, AffectRecords))
#define Recordset20_GetRows(This, Rows, Start, Fields, pvar) ((This)->lpVtbl ->GetRows (This, Rows, Start, Fields, pvar))
#define Recordset20_Move(This, NumRecords, Start) ((This)->lpVtbl ->Move (This, NumRecords, Start))
#define Recordset20_MoveNext(This) ((This)->lpVtbl ->MoveNext (This))
#define Recordset20_MovePrevious(This) ((This)->lpVtbl ->MovePrevious (This))
#define Recordset20_MoveFirst(This) ((This)->lpVtbl ->MoveFirst (This))
#define Recordset20_MoveLast(This) ((This)->lpVtbl ->MoveLast (This))
#define Recordset20_Open(This, Source, ActiveConnection, CursorType, LockType, Options) ((This)->lpVtbl ->Open (This, Source, ActiveConnection, CursorType, LockType, Options))
#define Recordset20_Requery(This, Options) ((This)->lpVtbl ->Requery (This, Options))
#define Recordset20__xResync(This, AffectRecords) ((This)->lpVtbl ->_xResync (This, AffectRecords))
#define Recordset20_Update(This, Fields, Values) ((This)->lpVtbl ->Update (This, Fields, Values))
#define Recordset20_get_AbsolutePage(This, pl) ((This)->lpVtbl ->get_AbsolutePage (This, pl))
#define Recordset20_put_AbsolutePage(This, Page) ((This)->lpVtbl ->put_AbsolutePage (This, Page))
#define Recordset20_get_EditMode(This, pl) ((This)->lpVtbl ->get_EditMode (This, pl))
#define Recordset20_get_Filter(This, Criteria) ((This)->lpVtbl ->get_Filter (This, Criteria))
#define Recordset20_put_Filter(This, Criteria) ((This)->lpVtbl ->put_Filter (This, Criteria))
#define Recordset20_get_PageCount(This, pl) ((This)->lpVtbl ->get_PageCount (This, pl))
#define Recordset20_get_PageSize(This, pl) ((This)->lpVtbl ->get_PageSize (This, pl))
#define Recordset20_put_PageSize(This, PageSize) ((This)->lpVtbl ->put_PageSize (This, PageSize))
#define Recordset20_get_Sort(This, Criteria) ((This)->lpVtbl ->get_Sort (This, Criteria))
#define Recordset20_put_Sort(This, Criteria) ((This)->lpVtbl ->put_Sort (This, Criteria))
#define Recordset20_get_Status(This, pl) ((This)->lpVtbl ->get_Status (This, pl))
#define Recordset20_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define Recordset20__xClone(This, ppvObject) ((This)->lpVtbl ->_xClone (This, ppvObject))
#define Recordset20_UpdateBatch(This, AffectRecords) ((This)->lpVtbl ->UpdateBatch (This, AffectRecords))
#define Recordset20_CancelBatch(This, AffectRecords) ((This)->lpVtbl ->CancelBatch (This, AffectRecords))
#define Recordset20_get_CursorLocation(This, plCursorLoc) ((This)->lpVtbl ->get_CursorLocation (This, plCursorLoc))
#define Recordset20_put_CursorLocation(This, lCursorLoc) ((This)->lpVtbl ->put_CursorLocation (This, lCursorLoc))
#define Recordset20_NextRecordset(This, RecordsAffected, ppiRs) ((This)->lpVtbl ->NextRecordset (This, RecordsAffected, ppiRs))
#define Recordset20_Supports(This, CursorOptions, pb) ((This)->lpVtbl ->Supports (This, CursorOptions, pb))
#define Recordset20_get_Collect(This, Index, pvar) ((This)->lpVtbl ->get_Collect (This, Index, pvar))
#define Recordset20_put_Collect(This, Index, value) ((This)->lpVtbl ->put_Collect (This, Index, value))
#define Recordset20_get_MarshalOptions(This, peMarshal) ((This)->lpVtbl ->get_MarshalOptions (This, peMarshal))
#define Recordset20_put_MarshalOptions(This, eMarshal) ((This)->lpVtbl ->put_MarshalOptions (This, eMarshal))
#define Recordset20_Find(This, Criteria, SkipRecords, SearchDirection, Start) ((This)->lpVtbl ->Find (This, Criteria, SkipRecords, SearchDirection, Start))
#define Recordset20_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#define Recordset20_get_DataSource(This, ppunkDataSource) ((This)->lpVtbl ->get_DataSource (This, ppunkDataSource))
#define Recordset20_putref_DataSource(This, punkDataSource) ((This)->lpVtbl ->putref_DataSource (This, punkDataSource))
#define Recordset20__xSave(This, FileName, PersistFormat) ((This)->lpVtbl ->_xSave (This, FileName, PersistFormat))
#define Recordset20_get_ActiveCommand(This, ppCmd) ((This)->lpVtbl ->get_ActiveCommand (This, ppCmd))
#define Recordset20_put_StayInSync(This, bStayInSync) ((This)->lpVtbl ->put_StayInSync (This, bStayInSync))
#define Recordset20_get_StayInSync(This, pbStayInSync) ((This)->lpVtbl ->get_StayInSync (This, pbStayInSync))
#define Recordset20_GetString(This, StringFormat, NumRows, ColumnDelimeter, RowDelimeter, NullExpr, pRetString) ((This)->lpVtbl ->GetString (This, StringFormat, NumRows, ColumnDelimeter, RowDelimeter, NullExpr, pRetString))
#define Recordset20_get_DataMember(This, pbstrDataMember) ((This)->lpVtbl ->get_DataMember (This, pbstrDataMember))
#define Recordset20_put_DataMember(This, bstrDataMember) ((This)->lpVtbl ->put_DataMember (This, bstrDataMember))
#define Recordset20_CompareBookmarks(This, Bookmark1, Bookmark2, pCompare) ((This)->lpVtbl ->CompareBookmarks (This, Bookmark1, Bookmark2, pCompare))
#define Recordset20_Clone(This, LockType, ppvObject) ((This)->lpVtbl ->Clone (This, LockType, ppvObject))
#define Recordset20_Resync(This, AffectRecords, ResyncValues) ((This)->lpVtbl ->Resync (This, AffectRecords, ResyncValues))
#endif
#endif
#endif
#ifndef __Recordset21_INTERFACE_DEFINED__
#define __Recordset21_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Recordset21;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001555-0000-0010-8000-00AA006D2EA4")
  Recordset21 : public Recordset20 {
    public:
    virtual HRESULT STDMETHODCALLTYPE Seek (VARIANT KeyValues, SeekEnum SeekOption = adSeekFirstEQ) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Index (BSTR Index) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Index (BSTR *pbstrIndex) = 0;
  };
#else
  typedef struct Recordset21Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Recordset21 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Recordset21 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Recordset21 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Recordset21 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Recordset21 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Recordset21 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Recordset21 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePosition) (Recordset21 *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePosition) (Recordset21 *This, PositionEnum Position);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (Recordset21 *This, IDispatch *pconn);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (Recordset21 *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (Recordset21 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_BOF) (Recordset21 *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Bookmark) (Recordset21 *This, VARIANT *pvBookmark);
    HRESULT (STDMETHODCALLTYPE *put_Bookmark) (Recordset21 *This, VARIANT vBookmark);
    HRESULT (STDMETHODCALLTYPE *get_CacheSize) (Recordset21 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_CacheSize) (Recordset21 *This, long CacheSize);
    HRESULT (STDMETHODCALLTYPE *get_CursorType) (Recordset21 *This, CursorTypeEnum *plCursorType);
    HRESULT (STDMETHODCALLTYPE *put_CursorType) (Recordset21 *This, CursorTypeEnum lCursorType);
    HRESULT (STDMETHODCALLTYPE *get_EOF) (Recordset21 *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Fields) (Recordset21 *This, ADOFields **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_LockType) (Recordset21 *This, LockTypeEnum *plLockType);
    HRESULT (STDMETHODCALLTYPE *put_LockType) (Recordset21 *This, LockTypeEnum lLockType);
    HRESULT (STDMETHODCALLTYPE *get_MaxRecords) (Recordset21 *This, long *plMaxRecords);
    HRESULT (STDMETHODCALLTYPE *put_MaxRecords) (Recordset21 *This, long lMaxRecords);
    HRESULT (STDMETHODCALLTYPE *get_RecordCount) (Recordset21 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *putref_Source) (Recordset21 *This, IDispatch *pcmd);
    HRESULT (STDMETHODCALLTYPE *put_Source) (Recordset21 *This, BSTR bstrConn);
    HRESULT (STDMETHODCALLTYPE *get_Source) (Recordset21 *This, VARIANT *pvSource);
    HRESULT (STDMETHODCALLTYPE *AddNew) (Recordset21 *This, VARIANT FieldList, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *CancelUpdate) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *Close) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *Delete) (Recordset21 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *GetRows) (Recordset21 *This, long Rows, VARIANT Start, VARIANT Fields, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *Move) (Recordset21 *This, long NumRecords, VARIANT Start);
    HRESULT (STDMETHODCALLTYPE *MoveNext) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *MovePrevious) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *MoveFirst) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *MoveLast) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *Open) (Recordset21 *This, VARIANT Source, VARIANT ActiveConnection, CursorTypeEnum CursorType, LockTypeEnum LockType, LONG Options);
    HRESULT (STDMETHODCALLTYPE *Requery) (Recordset21 *This, LONG Options);
    HRESULT (STDMETHODCALLTYPE *_xResync) (Recordset21 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *Update) (Recordset21 *This, VARIANT Fields, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePage) (Recordset21 *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePage) (Recordset21 *This, PositionEnum Page);
    HRESULT (STDMETHODCALLTYPE *get_EditMode) (Recordset21 *This, EditModeEnum *pl);
    HRESULT (STDMETHODCALLTYPE *get_Filter) (Recordset21 *This, VARIANT *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Filter) (Recordset21 *This, VARIANT Criteria);
    HRESULT (STDMETHODCALLTYPE *get_PageCount) (Recordset21 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_PageSize) (Recordset21 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_PageSize) (Recordset21 *This, long PageSize);
    HRESULT (STDMETHODCALLTYPE *get_Sort) (Recordset21 *This, BSTR *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Sort) (Recordset21 *This, BSTR Criteria);
    HRESULT (STDMETHODCALLTYPE *get_Status) (Recordset21 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_State) (Recordset21 *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *_xClone) (Recordset21 *This, _ADORecordset **ppvObject);
    HRESULT (STDMETHODCALLTYPE *UpdateBatch) (Recordset21 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *CancelBatch) (Recordset21 *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *get_CursorLocation) (Recordset21 *This, CursorLocationEnum *plCursorLoc);
    HRESULT (STDMETHODCALLTYPE *put_CursorLocation) (Recordset21 *This, CursorLocationEnum lCursorLoc);
    HRESULT (STDMETHODCALLTYPE *NextADORecordset) (Recordset21 *This, VARIANT *RecordsAffected, _ADORecordset **ppiRs);
    HRESULT (STDMETHODCALLTYPE *Supports) (Recordset21 *This, CursorOptionEnum CursorOptions, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Collect) (Recordset21 *This, VARIANT Index, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Collect) (Recordset21 *This, VARIANT Index, VARIANT value);
    HRESULT (STDMETHODCALLTYPE *get_MarshalOptions) (Recordset21 *This, MarshalOptionsEnum *peMarshal);
    HRESULT (STDMETHODCALLTYPE *put_MarshalOptions) (Recordset21 *This, MarshalOptionsEnum eMarshal);
    HRESULT (STDMETHODCALLTYPE *Find) (Recordset21 *This, BSTR Criteria, long SkipRecords, SearchDirectionEnum SearchDirection, VARIANT Start);
    HRESULT (STDMETHODCALLTYPE *Cancel) (Recordset21 *This);
    HRESULT (STDMETHODCALLTYPE *get_DataSource) (Recordset21 *This, IUnknown **ppunkDataSource);
    HRESULT (STDMETHODCALLTYPE *putref_DataSource) (Recordset21 *This, IUnknown *punkDataSource);
    HRESULT (STDMETHODCALLTYPE *_xSave) (Recordset21 *This, BSTR FileName, PersistFormatEnum PersistFormat);
    HRESULT (STDMETHODCALLTYPE *get_ActiveCommand) (Recordset21 *This, IDispatch **ppCmd);
    HRESULT (STDMETHODCALLTYPE *put_StayInSync) (Recordset21 *This, VARIANT_BOOL bStayInSync);
    HRESULT (STDMETHODCALLTYPE *get_StayInSync) (Recordset21 *This, VARIANT_BOOL *pbStayInSync);
    HRESULT (STDMETHODCALLTYPE *GetString) (Recordset21 *This, StringFormatEnum StringFormat, long NumRows, BSTR ColumnDelimeter, BSTR RowDelimeter, BSTR NullExpr, BSTR *pRetString);
    HRESULT (STDMETHODCALLTYPE *get_DataMember) (Recordset21 *This, BSTR *pbstrDataMember);
    HRESULT (STDMETHODCALLTYPE *put_DataMember) (Recordset21 *This, BSTR bstrDataMember);
    HRESULT (STDMETHODCALLTYPE *CompareBookmarks) (Recordset21 *This, VARIANT Bookmark1, VARIANT Bookmark2, CompareEnum *pCompare);
    HRESULT (STDMETHODCALLTYPE *Clone) (Recordset21 *This, LockTypeEnum LockType, _ADORecordset **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Resync) (Recordset21 *This, AffectEnum AffectRecords, ResyncEnum ResyncValues);
    HRESULT (STDMETHODCALLTYPE *Seek) (Recordset21 *This, VARIANT KeyValues, SeekEnum SeekOption);
    HRESULT (STDMETHODCALLTYPE *put_Index) (Recordset21 *This, BSTR Index);
    HRESULT (STDMETHODCALLTYPE *get_Index) (Recordset21 *This, BSTR *pbstrIndex);
    END_INTERFACE
  } Recordset21Vtbl;
  interface Recordset21 {
    CONST_VTBL struct Recordset21Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Recordset21_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Recordset21_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Recordset21_Release(This) ((This)->lpVtbl ->Release (This))
#define Recordset21_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Recordset21_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Recordset21_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Recordset21_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Recordset21_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Recordset21_get_AbsolutePosition(This, pl) ((This)->lpVtbl ->get_AbsolutePosition (This, pl))
#define Recordset21_put_AbsolutePosition(This, Position) ((This)->lpVtbl ->put_AbsolutePosition (This, Position))
#define Recordset21_putref_ActiveConnection(This, pconn) ((This)->lpVtbl ->putref_ActiveConnection (This, pconn))
#define Recordset21_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define Recordset21_get_ActiveConnection(This, pvar) ((This)->lpVtbl ->get_ActiveConnection (This, pvar))
#define Recordset21_get_BOF(This, pb) ((This)->lpVtbl ->get_BOF (This, pb))
#define Recordset21_get_Bookmark(This, pvBookmark) ((This)->lpVtbl ->get_Bookmark (This, pvBookmark))
#define Recordset21_put_Bookmark(This, vBookmark) ((This)->lpVtbl ->put_Bookmark (This, vBookmark))
#define Recordset21_get_CacheSize(This, pl) ((This)->lpVtbl ->get_CacheSize (This, pl))
#define Recordset21_put_CacheSize(This, CacheSize) ((This)->lpVtbl ->put_CacheSize (This, CacheSize))
#define Recordset21_get_CursorType(This, plCursorType) ((This)->lpVtbl ->get_CursorType (This, plCursorType))
#define Recordset21_put_CursorType(This, lCursorType) ((This)->lpVtbl ->put_CursorType (This, lCursorType))
#define Recordset21_get_EOF(This, pb) ((This)->lpVtbl ->get_EOF (This, pb))
#define Recordset21_get_Fields(This, ppvObject) ((This)->lpVtbl ->get_Fields (This, ppvObject))
#define Recordset21_get_LockType(This, plLockType) ((This)->lpVtbl ->get_LockType (This, plLockType))
#define Recordset21_put_LockType(This, lLockType) ((This)->lpVtbl ->put_LockType (This, lLockType))
#define Recordset21_get_MaxRecords(This, plMaxRecords) ((This)->lpVtbl ->get_MaxRecords (This, plMaxRecords))
#define Recordset21_put_MaxRecords(This, lMaxRecords) ((This)->lpVtbl ->put_MaxRecords (This, lMaxRecords))
#define Recordset21_get_RecordCount(This, pl) ((This)->lpVtbl ->get_RecordCount (This, pl))
#define Recordset21_putref_Source(This, pcmd) ((This)->lpVtbl ->putref_Source (This, pcmd))
#define Recordset21_put_Source(This, bstrConn) ((This)->lpVtbl ->put_Source (This, bstrConn))
#define Recordset21_get_Source(This, pvSource) ((This)->lpVtbl ->get_Source (This, pvSource))
#define Recordset21_AddNew(This, FieldList, Values) ((This)->lpVtbl ->AddNew (This, FieldList, Values))
#define Recordset21_CancelUpdate(This) ((This)->lpVtbl ->CancelUpdate (This))
#define Recordset21_Close(This) ((This)->lpVtbl ->Close (This))
#define Recordset21_Delete(This, AffectRecords) ((This)->lpVtbl ->Delete (This, AffectRecords))
#define Recordset21_GetRows(This, Rows, Start, Fields, pvar) ((This)->lpVtbl ->GetRows (This, Rows, Start, Fields, pvar))
#define Recordset21_Move(This, NumRecords, Start) ((This)->lpVtbl ->Move (This, NumRecords, Start))
#define Recordset21_MoveNext(This) ((This)->lpVtbl ->MoveNext (This))
#define Recordset21_MovePrevious(This) ((This)->lpVtbl ->MovePrevious (This))
#define Recordset21_MoveFirst(This) ((This)->lpVtbl ->MoveFirst (This))
#define Recordset21_MoveLast(This) ((This)->lpVtbl ->MoveLast (This))
#define Recordset21_Open(This, Source, ActiveConnection, CursorType, LockType, Options) ((This)->lpVtbl ->Open (This, Source, ActiveConnection, CursorType, LockType, Options))
#define Recordset21_Requery(This, Options) ((This)->lpVtbl ->Requery (This, Options))
#define Recordset21__xResync(This, AffectRecords) ((This)->lpVtbl ->_xResync (This, AffectRecords))
#define Recordset21_Update(This, Fields, Values) ((This)->lpVtbl ->Update (This, Fields, Values))
#define Recordset21_get_AbsolutePage(This, pl) ((This)->lpVtbl ->get_AbsolutePage (This, pl))
#define Recordset21_put_AbsolutePage(This, Page) ((This)->lpVtbl ->put_AbsolutePage (This, Page))
#define Recordset21_get_EditMode(This, pl) ((This)->lpVtbl ->get_EditMode (This, pl))
#define Recordset21_get_Filter(This, Criteria) ((This)->lpVtbl ->get_Filter (This, Criteria))
#define Recordset21_put_Filter(This, Criteria) ((This)->lpVtbl ->put_Filter (This, Criteria))
#define Recordset21_get_PageCount(This, pl) ((This)->lpVtbl ->get_PageCount (This, pl))
#define Recordset21_get_PageSize(This, pl) ((This)->lpVtbl ->get_PageSize (This, pl))
#define Recordset21_put_PageSize(This, PageSize) ((This)->lpVtbl ->put_PageSize (This, PageSize))
#define Recordset21_get_Sort(This, Criteria) ((This)->lpVtbl ->get_Sort (This, Criteria))
#define Recordset21_put_Sort(This, Criteria) ((This)->lpVtbl ->put_Sort (This, Criteria))
#define Recordset21_get_Status(This, pl) ((This)->lpVtbl ->get_Status (This, pl))
#define Recordset21_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define Recordset21__xClone(This, ppvObject) ((This)->lpVtbl ->_xClone (This, ppvObject))
#define Recordset21_UpdateBatch(This, AffectRecords) ((This)->lpVtbl ->UpdateBatch (This, AffectRecords))
#define Recordset21_CancelBatch(This, AffectRecords) ((This)->lpVtbl ->CancelBatch (This, AffectRecords))
#define Recordset21_get_CursorLocation(This, plCursorLoc) ((This)->lpVtbl ->get_CursorLocation (This, plCursorLoc))
#define Recordset21_put_CursorLocation(This, lCursorLoc) ((This)->lpVtbl ->put_CursorLocation (This, lCursorLoc))
#define Recordset21_NextRecordset(This, RecordsAffected, ppiRs) ((This)->lpVtbl ->NextRecordset (This, RecordsAffected, ppiRs))
#define Recordset21_Supports(This, CursorOptions, pb) ((This)->lpVtbl ->Supports (This, CursorOptions, pb))
#define Recordset21_get_Collect(This, Index, pvar) ((This)->lpVtbl ->get_Collect (This, Index, pvar))
#define Recordset21_put_Collect(This, Index, value) ((This)->lpVtbl ->put_Collect (This, Index, value))
#define Recordset21_get_MarshalOptions(This, peMarshal) ((This)->lpVtbl ->get_MarshalOptions (This, peMarshal))
#define Recordset21_put_MarshalOptions(This, eMarshal) ((This)->lpVtbl ->put_MarshalOptions (This, eMarshal))
#define Recordset21_Find(This, Criteria, SkipRecords, SearchDirection, Start) ((This)->lpVtbl ->Find (This, Criteria, SkipRecords, SearchDirection, Start))
#define Recordset21_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#define Recordset21_get_DataSource(This, ppunkDataSource) ((This)->lpVtbl ->get_DataSource (This, ppunkDataSource))
#define Recordset21_putref_DataSource(This, punkDataSource) ((This)->lpVtbl ->putref_DataSource (This, punkDataSource))
#define Recordset21__xSave(This, FileName, PersistFormat) ((This)->lpVtbl ->_xSave (This, FileName, PersistFormat))
#define Recordset21_get_ActiveCommand(This, ppCmd) ((This)->lpVtbl ->get_ActiveCommand (This, ppCmd))
#define Recordset21_put_StayInSync(This, bStayInSync) ((This)->lpVtbl ->put_StayInSync (This, bStayInSync))
#define Recordset21_get_StayInSync(This, pbStayInSync) ((This)->lpVtbl ->get_StayInSync (This, pbStayInSync))
#define Recordset21_GetString(This, StringFormat, NumRows, ColumnDelimeter, RowDelimeter, NullExpr, pRetString) ((This)->lpVtbl ->GetString (This, StringFormat, NumRows, ColumnDelimeter, RowDelimeter, NullExpr, pRetString))
#define Recordset21_get_DataMember(This, pbstrDataMember) ((This)->lpVtbl ->get_DataMember (This, pbstrDataMember))
#define Recordset21_put_DataMember(This, bstrDataMember) ((This)->lpVtbl ->put_DataMember (This, bstrDataMember))
#define Recordset21_CompareBookmarks(This, Bookmark1, Bookmark2, pCompare) ((This)->lpVtbl ->CompareBookmarks (This, Bookmark1, Bookmark2, pCompare))
#define Recordset21_Clone(This, LockType, ppvObject) ((This)->lpVtbl ->Clone (This, LockType, ppvObject))
#define Recordset21_Resync(This, AffectRecords, ResyncValues) ((This)->lpVtbl ->Resync (This, AffectRecords, ResyncValues))
#define Recordset21_Seek(This, KeyValues, SeekOption) ((This)->lpVtbl ->Seek (This, KeyValues, SeekOption))
#define Recordset21_put_Index(This, Index) ((This)->lpVtbl ->put_Index (This, Index))
#define Recordset21_get_Index(This, pbstrIndex) ((This)->lpVtbl ->get_Index (This, pbstrIndex))
#endif
#endif
#endif
#ifndef ___Recordset_INTERFACE_DEFINED__
#define ___Recordset_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Recordset;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001556-0000-0010-8000-00AA006D2EA4")
  _ADORecordset : public Recordset21 {
    public:
    virtual HRESULT STDMETHODCALLTYPE Save (VARIANT Destination, PersistFormatEnum PersistFormat = adPersistADTG) = 0;
  };
#else
  typedef struct _RecordsetVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADORecordset *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADORecordset *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADORecordset *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADORecordset *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADORecordset *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADORecordset *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADORecordset *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePosition) (_ADORecordset *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePosition) (_ADORecordset *This, PositionEnum Position);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveADOConnection) (_ADORecordset *This, IDispatch *pconn);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (_ADORecordset *This, VARIANT vConn);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (_ADORecordset *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_BOF) (_ADORecordset *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Bookmark) (_ADORecordset *This, VARIANT *pvBookmark);
    HRESULT (STDMETHODCALLTYPE *put_Bookmark) (_ADORecordset *This, VARIANT vBookmark);
    HRESULT (STDMETHODCALLTYPE *get_CacheSize) (_ADORecordset *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_CacheSize) (_ADORecordset *This, long CacheSize);
    HRESULT (STDMETHODCALLTYPE *get_CursorType) (_ADORecordset *This, CursorTypeEnum *plCursorType);
    HRESULT (STDMETHODCALLTYPE *put_CursorType) (_ADORecordset *This, CursorTypeEnum lCursorType);
    HRESULT (STDMETHODCALLTYPE *get_EOF) (_ADORecordset *This, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Fields) (_ADORecordset *This, ADOFields **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_LockType) (_ADORecordset *This, LockTypeEnum *plLockType);
    HRESULT (STDMETHODCALLTYPE *put_LockType) (_ADORecordset *This, LockTypeEnum lLockType);
    HRESULT (STDMETHODCALLTYPE *get_MaxRecords) (_ADORecordset *This, long *plMaxRecords);
    HRESULT (STDMETHODCALLTYPE *put_MaxRecords) (_ADORecordset *This, long lMaxRecords);
    HRESULT (STDMETHODCALLTYPE *get_RecordCount) (_ADORecordset *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *putref_Source) (_ADORecordset *This, IDispatch *pcmd);
    HRESULT (STDMETHODCALLTYPE *put_Source) (_ADORecordset *This, BSTR bstrConn);
    HRESULT (STDMETHODCALLTYPE *get_Source) (_ADORecordset *This, VARIANT *pvSource);
    HRESULT (STDMETHODCALLTYPE *AddNew) (_ADORecordset *This, VARIANT FieldList, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *CancelUpdate) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *Close) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *Delete) (_ADORecordset *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *GetRows) (_ADORecordset *This, long Rows, VARIANT Start, VARIANT Fields, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *Move) (_ADORecordset *This, long NumRecords, VARIANT Start);
    HRESULT (STDMETHODCALLTYPE *MoveNext) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *MovePrevious) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *MoveFirst) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *MoveLast) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *Open) (_ADORecordset *This, VARIANT Source, VARIANT ActiveConnection, CursorTypeEnum CursorType, LockTypeEnum LockType, LONG Options);
    HRESULT (STDMETHODCALLTYPE *Requery) (_ADORecordset *This, LONG Options);
    HRESULT (STDMETHODCALLTYPE *_xResync) (_ADORecordset *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *Update) (_ADORecordset *This, VARIANT Fields, VARIANT Values);
    HRESULT (STDMETHODCALLTYPE *get_AbsolutePage) (_ADORecordset *This, PositionEnum *pl);
    HRESULT (STDMETHODCALLTYPE *put_AbsolutePage) (_ADORecordset *This, PositionEnum Page);
    HRESULT (STDMETHODCALLTYPE *get_EditMode) (_ADORecordset *This, EditModeEnum *pl);
    HRESULT (STDMETHODCALLTYPE *get_Filter) (_ADORecordset *This, VARIANT *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Filter) (_ADORecordset *This, VARIANT Criteria);
    HRESULT (STDMETHODCALLTYPE *get_PageCount) (_ADORecordset *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_PageSize) (_ADORecordset *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *put_PageSize) (_ADORecordset *This, long PageSize);
    HRESULT (STDMETHODCALLTYPE *get_Sort) (_ADORecordset *This, BSTR *Criteria);
    HRESULT (STDMETHODCALLTYPE *put_Sort) (_ADORecordset *This, BSTR Criteria);
    HRESULT (STDMETHODCALLTYPE *get_Status) (_ADORecordset *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_State) (_ADORecordset *This, LONG *plObjState);
    HRESULT (STDMETHODCALLTYPE *_xClone) (_ADORecordset *This, _ADORecordset **ppvObject);
    HRESULT (STDMETHODCALLTYPE *UpdateBatch) (_ADORecordset *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *CancelBatch) (_ADORecordset *This, AffectEnum AffectRecords);
    HRESULT (STDMETHODCALLTYPE *get_CursorLocation) (_ADORecordset *This, CursorLocationEnum *plCursorLoc);
    HRESULT (STDMETHODCALLTYPE *put_CursorLocation) (_ADORecordset *This, CursorLocationEnum lCursorLoc);
    HRESULT (STDMETHODCALLTYPE *NextADORecordset) (_ADORecordset *This, VARIANT *RecordsAffected, _ADORecordset **ppiRs);
    HRESULT (STDMETHODCALLTYPE *Supports) (_ADORecordset *This, CursorOptionEnum CursorOptions, VARIANT_BOOL *pb);
    HRESULT (STDMETHODCALLTYPE *get_Collect) (_ADORecordset *This, VARIANT Index, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Collect) (_ADORecordset *This, VARIANT Index, VARIANT value);
    HRESULT (STDMETHODCALLTYPE *get_MarshalOptions) (_ADORecordset *This, MarshalOptionsEnum *peMarshal);
    HRESULT (STDMETHODCALLTYPE *put_MarshalOptions) (_ADORecordset *This, MarshalOptionsEnum eMarshal);
    HRESULT (STDMETHODCALLTYPE *Find) (_ADORecordset *This, BSTR Criteria, long SkipRecords, SearchDirectionEnum SearchDirection, VARIANT Start);
    HRESULT (STDMETHODCALLTYPE *Cancel) (_ADORecordset *This);
    HRESULT (STDMETHODCALLTYPE *get_DataSource) (_ADORecordset *This, IUnknown **ppunkDataSource);
    HRESULT (STDMETHODCALLTYPE *putref_DataSource) (_ADORecordset *This, IUnknown *punkDataSource);
    HRESULT (STDMETHODCALLTYPE *_xSave) (_ADORecordset *This, BSTR FileName, PersistFormatEnum PersistFormat);
    HRESULT (STDMETHODCALLTYPE *get_ActiveCommand) (_ADORecordset *This, IDispatch **ppCmd);
    HRESULT (STDMETHODCALLTYPE *put_StayInSync) (_ADORecordset *This, VARIANT_BOOL bStayInSync);
    HRESULT (STDMETHODCALLTYPE *get_StayInSync) (_ADORecordset *This, VARIANT_BOOL *pbStayInSync);
    HRESULT (STDMETHODCALLTYPE *GetString) (_ADORecordset *This, StringFormatEnum StringFormat, long NumRows, BSTR ColumnDelimeter, BSTR RowDelimeter, BSTR NullExpr, BSTR *pRetString);
    HRESULT (STDMETHODCALLTYPE *get_DataMember) (_ADORecordset *This, BSTR *pbstrDataMember);
    HRESULT (STDMETHODCALLTYPE *put_DataMember) (_ADORecordset *This, BSTR bstrDataMember);
    HRESULT (STDMETHODCALLTYPE *CompareBookmarks) (_ADORecordset *This, VARIANT Bookmark1, VARIANT Bookmark2, CompareEnum *pCompare);
    HRESULT (STDMETHODCALLTYPE *Clone) (_ADORecordset *This, LockTypeEnum LockType, _ADORecordset **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Resync) (_ADORecordset *This, AffectEnum AffectRecords, ResyncEnum ResyncValues);
    HRESULT (STDMETHODCALLTYPE *Seek) (_ADORecordset *This, VARIANT KeyValues, SeekEnum SeekOption);
    HRESULT (STDMETHODCALLTYPE *put_Index) (_ADORecordset *This, BSTR Index);
    HRESULT (STDMETHODCALLTYPE *get_Index) (_ADORecordset *This, BSTR *pbstrIndex);
    HRESULT (STDMETHODCALLTYPE *Save) (_ADORecordset *This, VARIANT Destination, PersistFormatEnum PersistFormat);
    END_INTERFACE
  } _RecordsetVtbl;
  interface _Recordset {
    CONST_VTBL struct _RecordsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _Recordset_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Recordset_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Recordset_Release(This) ((This)->lpVtbl ->Release (This))
#define _Recordset_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Recordset_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Recordset_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Recordset_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Recordset_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Recordset_get_AbsolutePosition(This, pl) ((This)->lpVtbl ->get_AbsolutePosition (This, pl))
#define _Recordset_put_AbsolutePosition(This, Position) ((This)->lpVtbl ->put_AbsolutePosition (This, Position))
#define _Recordset_putref_ActiveConnection(This, pconn) ((This)->lpVtbl ->putref_ActiveConnection (This, pconn))
#define _Recordset_put_ActiveConnection(This, vConn) ((This)->lpVtbl ->put_ActiveConnection (This, vConn))
#define _Recordset_get_ActiveConnection(This, pvar) ((This)->lpVtbl ->get_ActiveConnection (This, pvar))
#define _Recordset_get_BOF(This, pb) ((This)->lpVtbl ->get_BOF (This, pb))
#define _Recordset_get_Bookmark(This, pvBookmark) ((This)->lpVtbl ->get_Bookmark (This, pvBookmark))
#define _Recordset_put_Bookmark(This, vBookmark) ((This)->lpVtbl ->put_Bookmark (This, vBookmark))
#define _Recordset_get_CacheSize(This, pl) ((This)->lpVtbl ->get_CacheSize (This, pl))
#define _Recordset_put_CacheSize(This, CacheSize) ((This)->lpVtbl ->put_CacheSize (This, CacheSize))
#define _Recordset_get_CursorType(This, plCursorType) ((This)->lpVtbl ->get_CursorType (This, plCursorType))
#define _Recordset_put_CursorType(This, lCursorType) ((This)->lpVtbl ->put_CursorType (This, lCursorType))
#define _Recordset_get_EOF(This, pb) ((This)->lpVtbl ->get_EOF (This, pb))
#define _Recordset_get_Fields(This, ppvObject) ((This)->lpVtbl ->get_Fields (This, ppvObject))
#define _Recordset_get_LockType(This, plLockType) ((This)->lpVtbl ->get_LockType (This, plLockType))
#define _Recordset_put_LockType(This, lLockType) ((This)->lpVtbl ->put_LockType (This, lLockType))
#define _Recordset_get_MaxRecords(This, plMaxRecords) ((This)->lpVtbl ->get_MaxRecords (This, plMaxRecords))
#define _Recordset_put_MaxRecords(This, lMaxRecords) ((This)->lpVtbl ->put_MaxRecords (This, lMaxRecords))
#define _Recordset_get_RecordCount(This, pl) ((This)->lpVtbl ->get_RecordCount (This, pl))
#define _Recordset_putref_Source(This, pcmd) ((This)->lpVtbl ->putref_Source (This, pcmd))
#define _Recordset_put_Source(This, bstrConn) ((This)->lpVtbl ->put_Source (This, bstrConn))
#define _Recordset_get_Source(This, pvSource) ((This)->lpVtbl ->get_Source (This, pvSource))
#define _Recordset_AddNew(This, FieldList, Values) ((This)->lpVtbl ->AddNew (This, FieldList, Values))
#define _Recordset_CancelUpdate(This) ((This)->lpVtbl ->CancelUpdate (This))
#define _Recordset_Close(This) ((This)->lpVtbl ->Close (This))
#define _Recordset_Delete(This, AffectRecords) ((This)->lpVtbl ->Delete (This, AffectRecords))
#define _Recordset_GetRows(This, Rows, Start, Fields, pvar) ((This)->lpVtbl ->GetRows (This, Rows, Start, Fields, pvar))
#define _Recordset_Move(This, NumRecords, Start) ((This)->lpVtbl ->Move (This, NumRecords, Start))
#define _Recordset_MoveNext(This) ((This)->lpVtbl ->MoveNext (This))
#define _Recordset_MovePrevious(This) ((This)->lpVtbl ->MovePrevious (This))
#define _Recordset_MoveFirst(This) ((This)->lpVtbl ->MoveFirst (This))
#define _Recordset_MoveLast(This) ((This)->lpVtbl ->MoveLast (This))
#define _Recordset_Open(This, Source, ActiveConnection, CursorType, LockType, Options) ((This)->lpVtbl ->Open (This, Source, ActiveConnection, CursorType, LockType, Options))
#define _Recordset_Requery(This, Options) ((This)->lpVtbl ->Requery (This, Options))
#define _Recordset__xResync(This, AffectRecords) ((This)->lpVtbl ->_xResync (This, AffectRecords))
#define _Recordset_Update(This, Fields, Values) ((This)->lpVtbl ->Update (This, Fields, Values))
#define _Recordset_get_AbsolutePage(This, pl) ((This)->lpVtbl ->get_AbsolutePage (This, pl))
#define _Recordset_put_AbsolutePage(This, Page) ((This)->lpVtbl ->put_AbsolutePage (This, Page))
#define _Recordset_get_EditMode(This, pl) ((This)->lpVtbl ->get_EditMode (This, pl))
#define _Recordset_get_Filter(This, Criteria) ((This)->lpVtbl ->get_Filter (This, Criteria))
#define _Recordset_put_Filter(This, Criteria) ((This)->lpVtbl ->put_Filter (This, Criteria))
#define _Recordset_get_PageCount(This, pl) ((This)->lpVtbl ->get_PageCount (This, pl))
#define _Recordset_get_PageSize(This, pl) ((This)->lpVtbl ->get_PageSize (This, pl))
#define _Recordset_put_PageSize(This, PageSize) ((This)->lpVtbl ->put_PageSize (This, PageSize))
#define _Recordset_get_Sort(This, Criteria) ((This)->lpVtbl ->get_Sort (This, Criteria))
#define _Recordset_put_Sort(This, Criteria) ((This)->lpVtbl ->put_Sort (This, Criteria))
#define _Recordset_get_Status(This, pl) ((This)->lpVtbl ->get_Status (This, pl))
#define _Recordset_get_State(This, plObjState) ((This)->lpVtbl ->get_State (This, plObjState))
#define _Recordset__xClone(This, ppvObject) ((This)->lpVtbl ->_xClone (This, ppvObject))
#define _Recordset_UpdateBatch(This, AffectRecords) ((This)->lpVtbl ->UpdateBatch (This, AffectRecords))
#define _Recordset_CancelBatch(This, AffectRecords) ((This)->lpVtbl ->CancelBatch (This, AffectRecords))
#define _Recordset_get_CursorLocation(This, plCursorLoc) ((This)->lpVtbl ->get_CursorLocation (This, plCursorLoc))
#define _Recordset_put_CursorLocation(This, lCursorLoc) ((This)->lpVtbl ->put_CursorLocation (This, lCursorLoc))
#define _Recordset_NextRecordset(This, RecordsAffected, ppiRs) ((This)->lpVtbl ->NextRecordset (This, RecordsAffected, ppiRs))
#define _Recordset_Supports(This, CursorOptions, pb) ((This)->lpVtbl ->Supports (This, CursorOptions, pb))
#define _Recordset_get_Collect(This, Index, pvar) ((This)->lpVtbl ->get_Collect (This, Index, pvar))
#define _Recordset_put_Collect(This, Index, value) ((This)->lpVtbl ->put_Collect (This, Index, value))
#define _Recordset_get_MarshalOptions(This, peMarshal) ((This)->lpVtbl ->get_MarshalOptions (This, peMarshal))
#define _Recordset_put_MarshalOptions(This, eMarshal) ((This)->lpVtbl ->put_MarshalOptions (This, eMarshal))
#define _Recordset_Find(This, Criteria, SkipRecords, SearchDirection, Start) ((This)->lpVtbl ->Find (This, Criteria, SkipRecords, SearchDirection, Start))
#define _Recordset_Cancel(This) ((This)->lpVtbl ->Cancel (This))
#define _Recordset_get_DataSource(This, ppunkDataSource) ((This)->lpVtbl ->get_DataSource (This, ppunkDataSource))
#define _Recordset_putref_DataSource(This, punkDataSource) ((This)->lpVtbl ->putref_DataSource (This, punkDataSource))
#define _Recordset__xSave(This, FileName, PersistFormat) ((This)->lpVtbl ->_xSave (This, FileName, PersistFormat))
#define _Recordset_get_ActiveCommand(This, ppCmd) ((This)->lpVtbl ->get_ActiveCommand (This, ppCmd))
#define _Recordset_put_StayInSync(This, bStayInSync) ((This)->lpVtbl ->put_StayInSync (This, bStayInSync))
#define _Recordset_get_StayInSync(This, pbStayInSync) ((This)->lpVtbl ->get_StayInSync (This, pbStayInSync))
#define _Recordset_GetString(This, StringFormat, NumRows, ColumnDelimeter, RowDelimeter, NullExpr, pRetString) ((This)->lpVtbl ->GetString (This, StringFormat, NumRows, ColumnDelimeter, RowDelimeter, NullExpr, pRetString))
#define _Recordset_get_DataMember(This, pbstrDataMember) ((This)->lpVtbl ->get_DataMember (This, pbstrDataMember))
#define _Recordset_put_DataMember(This, bstrDataMember) ((This)->lpVtbl ->put_DataMember (This, bstrDataMember))
#define _Recordset_CompareBookmarks(This, Bookmark1, Bookmark2, pCompare) ((This)->lpVtbl ->CompareBookmarks (This, Bookmark1, Bookmark2, pCompare))
#define _Recordset_Clone(This, LockType, ppvObject) ((This)->lpVtbl ->Clone (This, LockType, ppvObject))
#define _Recordset_Resync(This, AffectRecords, ResyncValues) ((This)->lpVtbl ->Resync (This, AffectRecords, ResyncValues))
#define _Recordset_Seek(This, KeyValues, SeekOption) ((This)->lpVtbl ->Seek (This, KeyValues, SeekOption))
#define _Recordset_put_Index(This, Index) ((This)->lpVtbl ->put_Index (This, Index))
#define _Recordset_get_Index(This, pbstrIndex) ((This)->lpVtbl ->get_Index (This, pbstrIndex))
#define _Recordset_Save(This, Destination, PersistFormat) ((This)->lpVtbl ->Save (This, Destination, PersistFormat))
#endif
#endif
#endif
#ifndef __ADORecordsetConstruction_INTERFACE_DEFINED__
#define __ADORecordsetConstruction_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ADORecordsetConstruction;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000283-0000-0010-8000-00AA006D2EA4")
  ADORecordsetConstruction : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Rowset (IUnknown **ppRowset) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Rowset (IUnknown *pRowset) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Chapter (ADO_LONGPTR *plChapter) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Chapter (ADO_LONGPTR lChapter) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_RowPosition (IUnknown **ppRowPos) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_RowPosition (IUnknown *pRowPos) = 0;
  };
#else
  typedef struct ADORecordsetConstructionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADORecordsetConstruction *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADORecordsetConstruction *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADORecordsetConstruction *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADORecordsetConstruction *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADORecordsetConstruction *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADORecordsetConstruction *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADORecordsetConstruction *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Rowset) (ADORecordsetConstruction *This, IUnknown **ppRowset);
    HRESULT (STDMETHODCALLTYPE *put_Rowset) (ADORecordsetConstruction *This, IUnknown *pRowset);
    HRESULT (STDMETHODCALLTYPE *get_Chapter) (ADORecordsetConstruction *This, ADO_LONGPTR *plChapter);
    HRESULT (STDMETHODCALLTYPE *put_Chapter) (ADORecordsetConstruction *This, ADO_LONGPTR lChapter);
    HRESULT (STDMETHODCALLTYPE *get_RowPosition) (ADORecordsetConstruction *This, IUnknown **ppRowPos);
    HRESULT (STDMETHODCALLTYPE *put_RowPosition) (ADORecordsetConstruction *This, IUnknown *pRowPos);
    END_INTERFACE
  } ADORecordsetConstructionVtbl;
  interface ADORecordsetConstruction {
    CONST_VTBL struct ADORecordsetConstructionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ADORecordsetConstruction_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ADORecordsetConstruction_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ADORecordsetConstruction_Release(This) ((This)->lpVtbl ->Release (This))
#define ADORecordsetConstruction_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define ADORecordsetConstruction_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define ADORecordsetConstruction_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define ADORecordsetConstruction_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define ADORecordsetConstruction_get_Rowset(This, ppRowset) ((This)->lpVtbl ->get_Rowset (This, ppRowset))
#define ADORecordsetConstruction_put_Rowset(This, pRowset) ((This)->lpVtbl ->put_Rowset (This, pRowset))
#define ADORecordsetConstruction_get_Chapter(This, plChapter) ((This)->lpVtbl ->get_Chapter (This, plChapter))
#define ADORecordsetConstruction_put_Chapter(This, lChapter) ((This)->lpVtbl ->put_Chapter (This, lChapter))
#define ADORecordsetConstruction_get_RowPosition(This, ppRowPos) ((This)->lpVtbl ->get_RowPosition (This, ppRowPos))
#define ADORecordsetConstruction_put_RowPosition(This, pRowPos) ((This)->lpVtbl ->put_RowPosition (This, pRowPos))
#endif
#endif
#endif
#ifndef __Field15_INTERFACE_DEFINED__
#define __Field15_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Field15;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001505-0000-0010-8000-00AA006D2EA4")
  Field15 : public _ADO {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_ActualSize (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Attributes (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DefinedSize (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (DataTypeEnum *pDataType) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Value (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Value (VARIANT Val) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Precision (BYTE *pbPrecision) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_NumericScale (BYTE *pbNumericScale) = 0;
    virtual HRESULT STDMETHODCALLTYPE AppendChunk (VARIANT Data) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetChunk (long Length, VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_OriginalValue (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_UnderlyingValue (VARIANT *pvar) = 0;
  };
#else
  typedef struct Field15Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Field15 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Field15 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Field15 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Field15 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Field15 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Field15 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Field15 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Field15 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActualSize) (Field15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (Field15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_DefinedSize) (Field15 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Field15 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Type) (Field15 *This, DataTypeEnum *pDataType);
    HRESULT (STDMETHODCALLTYPE *get_Value) (Field15 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Value) (Field15 *This, VARIANT Val);
    HRESULT (STDMETHODCALLTYPE *get_Precision) (Field15 *This, BYTE *pbPrecision);
    HRESULT (STDMETHODCALLTYPE *get_NumericScale) (Field15 *This, BYTE *pbNumericScale);
    HRESULT (STDMETHODCALLTYPE *AppendChunk) (Field15 *This, VARIANT Data);
    HRESULT (STDMETHODCALLTYPE *GetChunk) (Field15 *This, long Length, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_OriginalValue) (Field15 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_UnderlyingValue) (Field15 *This, VARIANT *pvar);
    END_INTERFACE
  } Field15Vtbl;
  interface Field15 {
    CONST_VTBL struct Field15Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Field15_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Field15_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Field15_Release(This) ((This)->lpVtbl ->Release (This))
#define Field15_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Field15_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Field15_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Field15_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Field15_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Field15_get_ActualSize(This, pl) ((This)->lpVtbl ->get_ActualSize (This, pl))
#define Field15_get_Attributes(This, pl) ((This)->lpVtbl ->get_Attributes (This, pl))
#define Field15_get_DefinedSize(This, pl) ((This)->lpVtbl ->get_DefinedSize (This, pl))
#define Field15_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Field15_get_Type(This, pDataType) ((This)->lpVtbl ->get_Type (This, pDataType))
#define Field15_get_Value(This, pvar) ((This)->lpVtbl ->get_Value (This, pvar))
#define Field15_put_Value(This, Val) ((This)->lpVtbl ->put_Value (This, Val))
#define Field15_get_Precision(This, pbPrecision) ((This)->lpVtbl ->get_Precision (This, pbPrecision))
#define Field15_get_NumericScale(This, pbNumericScale) ((This)->lpVtbl ->get_NumericScale (This, pbNumericScale))
#define Field15_AppendChunk(This, Data) ((This)->lpVtbl ->AppendChunk (This, Data))
#define Field15_GetChunk(This, Length, pvar) ((This)->lpVtbl ->GetChunk (This, Length, pvar))
#define Field15_get_OriginalValue(This, pvar) ((This)->lpVtbl ->get_OriginalValue (This, pvar))
#define Field15_get_UnderlyingValue(This, pvar) ((This)->lpVtbl ->get_UnderlyingValue (This, pvar))
#endif
#endif
#endif
#ifndef __Field20_INTERFACE_DEFINED__
#define __Field20_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Field20;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("0000154C-0000-0010-8000-00AA006D2EA4")
  Field20 : public _ADO {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_ActualSize (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Attributes (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DefinedSize (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (DataTypeEnum *pDataType) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Value (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Value (VARIANT Val) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Precision (BYTE *pbPrecision) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_NumericScale (BYTE *pbNumericScale) = 0;
    virtual HRESULT STDMETHODCALLTYPE AppendChunk (VARIANT Data) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetChunk (long Length, VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_OriginalValue (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_UnderlyingValue (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DataFormat (IUnknown **ppiDF) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_DataFormat (IUnknown *piDF) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Precision (BYTE bPrecision) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_NumericScale (BYTE bScale) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Type (DataTypeEnum DataType) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_DefinedSize (long lSize) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Attributes (long lAttributes) = 0;
  };
#else
  typedef struct Field20Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Field20 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Field20 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Field20 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Field20 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Field20 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Field20 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Field20 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Field20 *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActualSize) (Field20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (Field20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_DefinedSize) (Field20 *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Field20 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Type) (Field20 *This, DataTypeEnum *pDataType);
    HRESULT (STDMETHODCALLTYPE *get_Value) (Field20 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Value) (Field20 *This, VARIANT Val);
    HRESULT (STDMETHODCALLTYPE *get_Precision) (Field20 *This, BYTE *pbPrecision);
    HRESULT (STDMETHODCALLTYPE *get_NumericScale) (Field20 *This, BYTE *pbNumericScale);
    HRESULT (STDMETHODCALLTYPE *AppendChunk) (Field20 *This, VARIANT Data);
    HRESULT (STDMETHODCALLTYPE *GetChunk) (Field20 *This, long Length, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_OriginalValue) (Field20 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_UnderlyingValue) (Field20 *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_DataFormat) (Field20 *This, IUnknown **ppiDF);
    HRESULT (STDMETHODCALLTYPE *putref_DataFormat) (Field20 *This, IUnknown *piDF);
    HRESULT (STDMETHODCALLTYPE *put_Precision) (Field20 *This, BYTE bPrecision);
    HRESULT (STDMETHODCALLTYPE *put_NumericScale) (Field20 *This, BYTE bScale);
    HRESULT (STDMETHODCALLTYPE *put_Type) (Field20 *This, DataTypeEnum DataType);
    HRESULT (STDMETHODCALLTYPE *put_DefinedSize) (Field20 *This, long lSize);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (Field20 *This, long lAttributes);
    END_INTERFACE
  } Field20Vtbl;
  interface Field20 {
    CONST_VTBL struct Field20Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Field20_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Field20_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Field20_Release(This) ((This)->lpVtbl ->Release (This))
#define Field20_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Field20_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Field20_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Field20_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Field20_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Field20_get_ActualSize(This, pl) ((This)->lpVtbl ->get_ActualSize (This, pl))
#define Field20_get_Attributes(This, pl) ((This)->lpVtbl ->get_Attributes (This, pl))
#define Field20_get_DefinedSize(This, pl) ((This)->lpVtbl ->get_DefinedSize (This, pl))
#define Field20_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Field20_get_Type(This, pDataType) ((This)->lpVtbl ->get_Type (This, pDataType))
#define Field20_get_Value(This, pvar) ((This)->lpVtbl ->get_Value (This, pvar))
#define Field20_put_Value(This, Val) ((This)->lpVtbl ->put_Value (This, Val))
#define Field20_get_Precision(This, pbPrecision) ((This)->lpVtbl ->get_Precision (This, pbPrecision))
#define Field20_get_NumericScale(This, pbNumericScale) ((This)->lpVtbl ->get_NumericScale (This, pbNumericScale))
#define Field20_AppendChunk(This, Data) ((This)->lpVtbl ->AppendChunk (This, Data))
#define Field20_GetChunk(This, Length, pvar) ((This)->lpVtbl ->GetChunk (This, Length, pvar))
#define Field20_get_OriginalValue(This, pvar) ((This)->lpVtbl ->get_OriginalValue (This, pvar))
#define Field20_get_UnderlyingValue(This, pvar) ((This)->lpVtbl ->get_UnderlyingValue (This, pvar))
#define Field20_get_DataFormat(This, ppiDF) ((This)->lpVtbl ->get_DataFormat (This, ppiDF))
#define Field20_putref_DataFormat(This, piDF) ((This)->lpVtbl ->putref_DataFormat (This, piDF))
#define Field20_put_Precision(This, bPrecision) ((This)->lpVtbl ->put_Precision (This, bPrecision))
#define Field20_put_NumericScale(This, bScale) ((This)->lpVtbl ->put_NumericScale (This, bScale))
#define Field20_put_Type(This, DataType) ((This)->lpVtbl ->put_Type (This, DataType))
#define Field20_put_DefinedSize(This, lSize) ((This)->lpVtbl ->put_DefinedSize (This, lSize))
#define Field20_put_Attributes(This, lAttributes) ((This)->lpVtbl ->put_Attributes (This, lAttributes))
#endif
#endif
#endif
#ifndef __Field_INTERFACE_DEFINED__
#define __Field_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Field;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001569-0000-0010-8000-00AA006D2EA4")
  ADOField : public Field20 {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Status (long *pFStatus) = 0;
  };
#else
  typedef struct FieldVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOField *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOField *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOField *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOField *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOField *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOField *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOField *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (ADOField *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActualSize) (ADOField *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (ADOField *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_DefinedSize) (ADOField *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Name) (ADOField *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Type) (ADOField *This, DataTypeEnum *pDataType);
    HRESULT (STDMETHODCALLTYPE *get_Value) (ADOField *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Value) (ADOField *This, VARIANT Val);
    HRESULT (STDMETHODCALLTYPE *get_Precision) (ADOField *This, BYTE *pbPrecision);
    HRESULT (STDMETHODCALLTYPE *get_NumericScale) (ADOField *This, BYTE *pbNumericScale);
    HRESULT (STDMETHODCALLTYPE *AppendChunk) (ADOField *This, VARIANT Data);
    HRESULT (STDMETHODCALLTYPE *GetChunk) (ADOField *This, long Length, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_OriginalValue) (ADOField *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_UnderlyingValue) (ADOField *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *get_DataFormat) (ADOField *This, IUnknown **ppiDF);
    HRESULT (STDMETHODCALLTYPE *putref_DataFormat) (ADOField *This, IUnknown *piDF);
    HRESULT (STDMETHODCALLTYPE *put_Precision) (ADOField *This, BYTE bPrecision);
    HRESULT (STDMETHODCALLTYPE *put_NumericScale) (ADOField *This, BYTE bScale);
    HRESULT (STDMETHODCALLTYPE *put_Type) (ADOField *This, DataTypeEnum DataType);
    HRESULT (STDMETHODCALLTYPE *put_DefinedSize) (ADOField *This, long lSize);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (ADOField *This, long lAttributes);
    HRESULT (STDMETHODCALLTYPE *get_Status) (ADOField *This, long *pFStatus);
    END_INTERFACE
  } FieldVtbl;
  interface Field {
    CONST_VTBL struct FieldVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Field_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Field_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Field_Release(This) ((This)->lpVtbl ->Release (This))
#define Field_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Field_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Field_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Field_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Field_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Field_get_ActualSize(This, pl) ((This)->lpVtbl ->get_ActualSize (This, pl))
#define Field_get_Attributes(This, pl) ((This)->lpVtbl ->get_Attributes (This, pl))
#define Field_get_DefinedSize(This, pl) ((This)->lpVtbl ->get_DefinedSize (This, pl))
#define Field_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Field_get_Type(This, pDataType) ((This)->lpVtbl ->get_Type (This, pDataType))
#define Field_get_Value(This, pvar) ((This)->lpVtbl ->get_Value (This, pvar))
#define Field_put_Value(This, Val) ((This)->lpVtbl ->put_Value (This, Val))
#define Field_get_Precision(This, pbPrecision) ((This)->lpVtbl ->get_Precision (This, pbPrecision))
#define Field_get_NumericScale(This, pbNumericScale) ((This)->lpVtbl ->get_NumericScale (This, pbNumericScale))
#define Field_AppendChunk(This, Data) ((This)->lpVtbl ->AppendChunk (This, Data))
#define Field_GetChunk(This, Length, pvar) ((This)->lpVtbl ->GetChunk (This, Length, pvar))
#define Field_get_OriginalValue(This, pvar) ((This)->lpVtbl ->get_OriginalValue (This, pvar))
#define Field_get_UnderlyingValue(This, pvar) ((This)->lpVtbl ->get_UnderlyingValue (This, pvar))
#define Field_get_DataFormat(This, ppiDF) ((This)->lpVtbl ->get_DataFormat (This, ppiDF))
#define Field_putref_DataFormat(This, piDF) ((This)->lpVtbl ->putref_DataFormat (This, piDF))
#define Field_put_Precision(This, bPrecision) ((This)->lpVtbl ->put_Precision (This, bPrecision))
#define Field_put_NumericScale(This, bScale) ((This)->lpVtbl ->put_NumericScale (This, bScale))
#define Field_put_Type(This, DataType) ((This)->lpVtbl ->put_Type (This, DataType))
#define Field_put_DefinedSize(This, lSize) ((This)->lpVtbl ->put_DefinedSize (This, lSize))
#define Field_put_Attributes(This, lAttributes) ((This)->lpVtbl ->put_Attributes (This, lAttributes))
#define Field_get_Status(This, pFStatus) ((This)->lpVtbl ->get_Status (This, pFStatus))
#endif
#endif
#endif
#ifndef __Fields15_INTERFACE_DEFINED__
#define __Fields15_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Fields15;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001506-0000-0010-8000-00AA006D2EA4")
  Fields15 : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, ADOField **ppvObject) = 0;
  };
#else
  typedef struct Fields15Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Fields15 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Fields15 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Fields15 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Fields15 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Fields15 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Fields15 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Fields15 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Fields15 *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Fields15 *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Fields15 *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Fields15 *This, VARIANT Index, ADOField **ppvObject);
    END_INTERFACE
  } Fields15Vtbl;
  interface Fields15 {
    CONST_VTBL struct Fields15Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Fields15_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Fields15_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Fields15_Release(This) ((This)->lpVtbl ->Release (This))
#define Fields15_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Fields15_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Fields15_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Fields15_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Fields15_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Fields15__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Fields15_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Fields15_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif
#endif
#endif
#ifndef __Fields20_INTERFACE_DEFINED__
#define __Fields20_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Fields20;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("0000154D-0000-0010-8000-00AA006D2EA4")
  Fields20 : public Fields15 {
    public:
    virtual HRESULT STDMETHODCALLTYPE _Append (BSTR Name, DataTypeEnum Type, long DefinedSize = 0, FieldAttributeEnum Attrib = adFldUnspecified) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Index) = 0;
  };
#else
  typedef struct Fields20Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Fields20 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Fields20 *This);
    ULONG (STDMETHODCALLTYPE *Release) (Fields20 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Fields20 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Fields20 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Fields20 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Fields20 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Fields20 *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Fields20 *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Fields20 *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Fields20 *This, VARIANT Index, ADOField **ppvObject);
    HRESULT (STDMETHODCALLTYPE *_Append) (Fields20 *This, BSTR Name, DataTypeEnum Type, long DefinedSize, FieldAttributeEnum Attrib);
    HRESULT (STDMETHODCALLTYPE *Delete) (Fields20 *This, VARIANT Index);
    END_INTERFACE
  } Fields20Vtbl;
  interface Fields20 {
    CONST_VTBL struct Fields20Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Fields20_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Fields20_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Fields20_Release(This) ((This)->lpVtbl ->Release (This))
#define Fields20_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Fields20_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Fields20_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Fields20_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Fields20_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Fields20__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Fields20_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Fields20_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#define Fields20__Append(This, Name, Type, DefinedSize, Attrib) ((This)->lpVtbl ->_Append (This, Name, Type, DefinedSize, Attrib))
#define Fields20_Delete(This, Index) ((This)->lpVtbl ->Delete (This, Index))
#endif
#endif
#endif
#ifndef __Fields_INTERFACE_DEFINED__
#define __Fields_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Fields;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00001564-0000-0010-8000-00AA006D2EA4")
  ADOFields : public Fields20 {
    public:
    virtual HRESULT STDMETHODCALLTYPE Append (BSTR Name, DataTypeEnum Type, long DefinedSize, FieldAttributeEnum Attrib, VARIANT FieldValue) = 0;
    virtual HRESULT STDMETHODCALLTYPE Update (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE Resync (ResyncEnum ResyncValues = adResyncAllValues) = 0;
    virtual HRESULT STDMETHODCALLTYPE CancelUpdate (void) = 0;
  };
#else
  typedef struct FieldsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOFields *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOFields *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOFields *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOFields *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOFields *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOFields *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOFields *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOFields *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOFields *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOFields *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOFields *This, VARIANT Index, ADOField **ppvObject);
    HRESULT (STDMETHODCALLTYPE *_Append) (ADOFields *This, BSTR Name, DataTypeEnum Type, long DefinedSize, FieldAttributeEnum Attrib);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOFields *This, VARIANT Index);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOFields *This, BSTR Name, DataTypeEnum Type, long DefinedSize, FieldAttributeEnum Attrib, VARIANT FieldValue);
    HRESULT (STDMETHODCALLTYPE *Update) (ADOFields *This);
    HRESULT (STDMETHODCALLTYPE *Resync) (ADOFields *This, ResyncEnum ResyncValues);
    HRESULT (STDMETHODCALLTYPE *CancelUpdate) (ADOFields *This);
    END_INTERFACE
  } FieldsVtbl;
  interface Fields {
    CONST_VTBL struct FieldsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Fields_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Fields_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Fields_Release(This) ((This)->lpVtbl ->Release (This))
#define Fields_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Fields_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Fields_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Fields_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Fields_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Fields__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Fields_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Fields_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#define Fields__Append(This, Name, Type, DefinedSize, Attrib) ((This)->lpVtbl ->_Append (This, Name, Type, DefinedSize, Attrib))
#define Fields_Delete(This, Index) ((This)->lpVtbl ->Delete (This, Index))
#define Fields_Append(This, Name, Type, DefinedSize, Attrib, FieldValue) ((This)->lpVtbl ->Append (This, Name, Type, DefinedSize, Attrib, FieldValue))
#define Fields_Update(This) ((This)->lpVtbl ->Update (This))
#define Fields_Resync(This, ResyncValues) ((This)->lpVtbl ->Resync (This, ResyncValues))
#define Fields_CancelUpdate(This) ((This)->lpVtbl ->CancelUpdate (This))
#endif
#endif
#endif
#ifndef ___Parameter_INTERFACE_DEFINED__
#define ___Parameter_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Parameter;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("0000150C-0000-0010-8000-00AA006D2EA4")
  _ADOParameter : public _ADO {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR bstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Value (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Value (VARIANT val) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (DataTypeEnum *psDataType) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Type (DataTypeEnum sDataType) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Direction (ParameterDirectionEnum lParmDirection) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Direction (ParameterDirectionEnum *plParmDirection) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Precision (BYTE bPrecision) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Precision (BYTE *pbPrecision) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_NumericScale (BYTE bScale) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_NumericScale (BYTE *pbScale) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Size (long l) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Size (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE AppendChunk (VARIANT Val) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Attributes (LONG *plParmAttribs) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Attributes (LONG lParmAttribs) = 0;
  };
#else
  typedef struct _ParameterVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOParameter *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOParameter *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOParameter *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOParameter *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOParameter *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOParameter *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOParameter *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOParameter *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOParameter *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOParameter *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_Value) (_ADOParameter *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Value) (_ADOParameter *This, VARIANT val);
    HRESULT (STDMETHODCALLTYPE *get_Type) (_ADOParameter *This, DataTypeEnum *psDataType);
    HRESULT (STDMETHODCALLTYPE *put_Type) (_ADOParameter *This, DataTypeEnum sDataType);
    HRESULT (STDMETHODCALLTYPE *put_Direction) (_ADOParameter *This, ParameterDirectionEnum lParmDirection);
    HRESULT (STDMETHODCALLTYPE *get_Direction) (_ADOParameter *This, ParameterDirectionEnum *plParmDirection);
    HRESULT (STDMETHODCALLTYPE *put_Precision) (_ADOParameter *This, BYTE bPrecision);
    HRESULT (STDMETHODCALLTYPE *get_Precision) (_ADOParameter *This, BYTE *pbPrecision);
    HRESULT (STDMETHODCALLTYPE *put_NumericScale) (_ADOParameter *This, BYTE bScale);
    HRESULT (STDMETHODCALLTYPE *get_NumericScale) (_ADOParameter *This, BYTE *pbScale);
    HRESULT (STDMETHODCALLTYPE *put_Size) (_ADOParameter *This, long l);
    HRESULT (STDMETHODCALLTYPE *get_Size) (_ADOParameter *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *AppendChunk) (_ADOParameter *This, VARIANT Val);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (_ADOParameter *This, LONG *plParmAttribs);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (_ADOParameter *This, LONG lParmAttribs);
    END_INTERFACE
  } _ParameterVtbl;
  interface _Parameter {
    CONST_VTBL struct _ParameterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _Parameter_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Parameter_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Parameter_Release(This) ((This)->lpVtbl ->Release (This))
#define _Parameter_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Parameter_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Parameter_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Parameter_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Parameter_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Parameter_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define _Parameter_put_Name(This, bstr) ((This)->lpVtbl ->put_Name (This, bstr))
#define _Parameter_get_Value(This, pvar) ((This)->lpVtbl ->get_Value (This, pvar))
#define _Parameter_put_Value(This, val) ((This)->lpVtbl ->put_Value (This, val))
#define _Parameter_get_Type(This, psDataType) ((This)->lpVtbl ->get_Type (This, psDataType))
#define _Parameter_put_Type(This, sDataType) ((This)->lpVtbl ->put_Type (This, sDataType))
#define _Parameter_put_Direction(This, lParmDirection) ((This)->lpVtbl ->put_Direction (This, lParmDirection))
#define _Parameter_get_Direction(This, plParmDirection) ((This)->lpVtbl ->get_Direction (This, plParmDirection))
#define _Parameter_put_Precision(This, bPrecision) ((This)->lpVtbl ->put_Precision (This, bPrecision))
#define _Parameter_get_Precision(This, pbPrecision) ((This)->lpVtbl ->get_Precision (This, pbPrecision))
#define _Parameter_put_NumericScale(This, bScale) ((This)->lpVtbl ->put_NumericScale (This, bScale))
#define _Parameter_get_NumericScale(This, pbScale) ((This)->lpVtbl ->get_NumericScale (This, pbScale))
#define _Parameter_put_Size(This, l) ((This)->lpVtbl ->put_Size (This, l))
#define _Parameter_get_Size(This, pl) ((This)->lpVtbl ->get_Size (This, pl))
#define _Parameter_AppendChunk(This, Val) ((This)->lpVtbl ->AppendChunk (This, Val))
#define _Parameter_get_Attributes(This, plParmAttribs) ((This)->lpVtbl ->get_Attributes (This, plParmAttribs))
#define _Parameter_put_Attributes(This, lParmAttribs) ((This)->lpVtbl ->put_Attributes (This, lParmAttribs))
#endif
#endif
#endif
  EXTERN_C const CLSID CLSID_Parameter;
#ifdef __cplusplus
  Parameter;
#endif
#ifndef __Parameters_INTERFACE_DEFINED__
#define __Parameters_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Parameters;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("0000150D-0000-0010-8000-00AA006D2EA4")
  ADOParameters : public _ADODynaCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, _ADOParameter **ppvObject) = 0;
  };
#else
  typedef struct ParametersVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOParameters *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOParameters *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOParameters *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOParameters *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOParameters *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOParameters *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOParameters *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOParameters *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOParameters *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOParameters *This);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOParameters *This, IDispatch *Object);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOParameters *This, VARIANT Index);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOParameters *This, VARIANT Index, _ADOParameter **ppvObject);
    END_INTERFACE
  } ParametersVtbl;
  interface Parameters {
    CONST_VTBL struct ParametersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Parameters_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Parameters_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Parameters_Release(This) ((This)->lpVtbl ->Release (This))
#define Parameters_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Parameters_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Parameters_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Parameters_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Parameters_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Parameters__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Parameters_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Parameters_Append(This, Object) ((This)->lpVtbl ->Append (This, Object))
#define Parameters_Delete(This, Index) ((This)->lpVtbl ->Delete (This, Index))
#define Parameters_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif
#endif
#endif
#ifndef __Property_INTERFACE_DEFINED__
#define __Property_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Property;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000503-0000-0010-8000-00AA006D2EA4")
  ADOProperty : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Value (VARIANT *pval) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Value (VARIANT val) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (DataTypeEnum *ptype) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Attributes (long *plAttributes) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Attributes (long lAttributes) = 0;
  };
#else
  typedef struct PropertyVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOProperty *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOProperty *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOProperty *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOProperty *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOProperty *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOProperty *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOProperty *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Value) (ADOProperty *This, VARIANT *pval);
    HRESULT (STDMETHODCALLTYPE *put_Value) (ADOProperty *This, VARIANT val);
    HRESULT (STDMETHODCALLTYPE *get_Name) (ADOProperty *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Type) (ADOProperty *This, DataTypeEnum *ptype);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (ADOProperty *This, long *plAttributes);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (ADOProperty *This, long lAttributes);
    END_INTERFACE
  } PropertyVtbl;
  interface Property {
    CONST_VTBL struct PropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Property_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Property_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Property_Release(This) ((This)->lpVtbl ->Release (This))
#define Property_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Property_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Property_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Property_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Property_get_Value(This, pval) ((This)->lpVtbl ->get_Value (This, pval))
#define Property_put_Value(This, val) ((This)->lpVtbl ->put_Value (This, val))
#define Property_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Property_get_Type(This, ptype) ((This)->lpVtbl ->get_Type (This, ptype))
#define Property_get_Attributes(This, plAttributes) ((This)->lpVtbl ->get_Attributes (This, plAttributes))
#define Property_put_Attributes(This, lAttributes) ((This)->lpVtbl ->put_Attributes (This, lAttributes))
#endif
#endif
#endif
#ifndef __Properties_INTERFACE_DEFINED__
#define __Properties_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Properties;
#if defined (__cplusplus) && !defined (CINTERFACE)

  MIDL_INTERFACE ("00000504-0000-0010-8000-00AA006D2EA4")
  ADOProperties : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, ADOProperty **ppvObject) = 0;
  };
#else
  typedef struct PropertiesVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOProperties *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOProperties *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOProperties *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOProperties *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOProperties *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOProperties *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOProperties *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOProperties *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOProperties *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOProperties *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOProperties *This, VARIANT Index, ADOProperty **ppvObject);
    END_INTERFACE
  } PropertiesVtbl;
  interface Properties {
    CONST_VTBL struct PropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Properties_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Properties_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Properties_Release(This) ((This)->lpVtbl ->Release (This))
#define Properties_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Properties_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Properties_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Properties_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Properties_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Properties__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Properties_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Properties_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif
#endif
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_ado10_0000_0001_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ado10_0000_0001_v0_0_s_ifspec;
#ifdef __cplusplus
}
#endif
#endif
#define ADOCommand _ADOCommand
#define ADORecordset _ADORecordset
#define ADOTransaction _ADOTransaction
#define ADOParameter _ADOParameter
#define ADOConnection _ADOConnection
#define ADOCollection _ADOCollection
#define ADODynaCollection _ADODynaCollection
#define ADORecord _ADORecord
#define ADORecField _ADORecField
#define ADOStream _ADOStream
#endif

#endif
