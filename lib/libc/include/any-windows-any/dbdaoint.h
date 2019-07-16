/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _DBDAOINT_H_
#define _DBDAOINT_H_

#include <tchar.h>

struct _DAODBEngine;
#define DAODBEngine _DAODBEngine
struct DAOError;
struct _DAOCollection;
#define DAOCollection _DAOCollection
struct DAOErrors;
struct DAOProperty;
struct _DAODynaCollection;
#define DAODynaCollection _DAODynaCollection
struct DAOProperties;
struct DAOWorkspace;
struct DAOWorkspaces;
struct DAOConnection;
struct DAOConnections;
struct DAODatabase;
struct DAODatabases;
struct _DAOTableDef;
#define DAOTableDef _DAOTableDef
struct DAOTableDefs;
struct _DAOQueryDef;
#define DAOQueryDef _DAOQueryDef
struct DAOQueryDefs;
struct DAORecordset;
struct DAORecordsets;
struct _DAOField;
#define DAOField _DAOField
struct DAOFields;
struct _DAOIndex;
#define DAOIndex _DAOIndex
struct DAOIndexes;
struct DAOParameter;
struct DAOParameters;
struct _DAOUser;
#define DAOUser _DAOUser
struct DAOUsers;
struct _DAOGroup;
#define DAOGroup _DAOGroup
struct DAOGroups;
struct _DAORelation;
#define DAORelation _DAORelation
struct DAORelations;
struct DAOContainer;
struct DAOContainers;
struct DAODocument;
struct DAODocuments;
struct DAOIndexFields;

typedef enum RecordsetTypeEnum {
  dbOpenTable = 1,dbOpenDynaset = 2,dbOpenSnapshot = 4,dbOpenForwardOnly = 8,dbOpenDynamic = 16
} RecordsetTypeEnum;

typedef enum EditModeEnum {
  dbEditNone = 0,dbEditInProgress = 1,dbEditAdd = 2,dbEditChanged = 4,dbEditDeleted = 8,dbEditNew = 16
} EditModeEnum;

typedef enum RecordsetOptionEnum {
  dbDenyWrite = 0x1,dbDenyRead = 0x2,dbReadOnly = 0x4,dbAppendOnly = 0x8,dbInconsistent = 0x10,dbConsistent = 0x20,dbSQLPassThrough = 0x40,
  dbFailOnError = 0x80,dbForwardOnly = 0x100,dbSeeChanges = 0x200,dbRunAsync = 0x400,dbExecDirect = 0x800
} RecordsetOptionEnum;

typedef enum LockTypeEnum {
  dbPessimistic = 0x2,dbOptimistic = 0x3,dbOptimisticValue = 0x1,dbOptimisticBatch = 0x5
} LockTypeEnum;

typedef enum UpdateCriteriaEnum {
  dbCriteriaKey = 0x1,dbCriteriaModValues = 0x2,dbCriteriaAllCols = 0x4,dbCriteriaTimestamp = 0x8,dbCriteriaDeleteInsert = 0x10,
  dbCriteriaUpdate = 0x20
} UpdateCriteriaEnum;

typedef enum FieldAttributeEnum {
  dbFixedField = 0x1,dbVariableField = 0x2,dbAutoIncrField = 0x10,dbUpdatableField = 0x20,dbSystemField = 0x2000,dbHyperlinkField = 0x8000,
  dbDescending = 0x1
} FieldAttributeEnum;

typedef enum DataTypeEnum {
  dbBoolean = 1,dbByte = 2,dbInteger = 3,dbLong = 4,dbCurrency = 5,dbSingle = 6,dbDouble = 7,dbDate = 8,dbBinary = 9,dbText = 10,
  dbLongBinary = 11,dbMemo = 12,dbGUID = 15,dbBigInt = 16,dbVarBinary = 17,dbChar = 18,dbNumeric = 19,dbDecimal = 20,dbFloat = 21,
  dbTime = 22,dbTimeStamp = 23
} DataTypeEnum;

typedef enum RelationAttributeEnum {
  dbRelationUnique = 0x1,dbRelationDontEnforce = 0x2,dbRelationInherited = 0x4,dbRelationUpdateCascade = 0x100,dbRelationDeleteCascade = 0x1000,
  dbRelationLeft = 0x1000000,dbRelationRight = 0x2000000
} RelationAttributeEnum;

typedef enum TableDefAttributeEnum {
  dbAttachExclusive = 0x10000,dbAttachSavePWD = 0x20000,dbSystemObject = 0x80000002,dbAttachedTable = 0x40000000,dbAttachedODBC = 0x20000000,
  dbHiddenObject = 0x1
} TableDefAttributeEnum;

typedef enum QueryDefTypeEnum {
  dbQSelect = 0,dbQProcedure = 0xe0,dbQAction = 0xf0,dbQCrosstab = 0x10,dbQDelete = 0x20,dbQUpdate = 0x30,dbQAppend = 0x40,
  dbQMakeTable = 0x50,dbQDDL = 0x60,dbQSQLPassThrough = 0x70,dbQSetOperation = 0x80,dbQSPTBulk = 0x90,dbQCompound = 0xa0
} QueryDefTypeEnum;

typedef enum QueryDefStateEnum {
  dbQPrepare = 1,dbQUnprepare = 2
} QueryDefStateEnum;

typedef enum DatabaseTypeEnum {
  dbVersion10 = 1,dbEncrypt = 2,dbDecrypt = 4,dbVersion11 = 8,dbVersion20 = 16,dbVersion30 = 32,dbVersion40 = 64
} DatabaseTypeEnum;

typedef enum CollatingOrderEnum {
  dbSortNeutral = 0x400,dbSortArabic = 0x401,dbSortCyrillic = 0x419,dbSortCzech = 0x405,dbSortDutch = 0x413,dbSortGeneral = 0x409,
  dbSortGreek = 0x408,dbSortHebrew = 0x40d,dbSortHungarian = 0x40e,dbSortIcelandic = 0x40f,dbSortNorwdan = 0x406,dbSortPDXIntl = 0x409,
  dbSortPDXNor = 0x406,dbSortPDXSwe = 0x41d,dbSortPolish = 0x415,dbSortSpanish = 0x40a,dbSortSwedFin = 0x41d,dbSortTurkish = 0x41f,
  dbSortJapanese = 0x411,dbSortChineseSimplified = 0x804,dbSortChineseTraditional = 0x404,dbSortKorean = 0x412,dbSortThai = 0x41e,
  dbSortSlovenian = 0x424,dbSortUndefined = -1
} CollatingOrderEnum;

typedef enum IdleEnum {
  dbFreeLocks = 1,dbRefreshCache = 8
} IdleEnum;

typedef enum PermissionEnum {
  dbSecNoAccess = 0,dbSecFullAccess = 0xfffff,dbSecDelete = 0x10000,dbSecReadSec = 0x20000,dbSecWriteSec = 0x40000,dbSecWriteOwner = 0x80000,
  dbSecDBCreate = 0x1,dbSecDBOpen = 0x2,dbSecDBExclusive = 0x4,dbSecDBAdmin = 0x8,dbSecCreate = 0x1,dbSecReadDef = 0x4,dbSecWriteDef = 0x1000c,
  dbSecRetrieveData = 0x14,dbSecInsertData = 0x20,dbSecReplaceData = 0x40,dbSecDeleteData = 0x80
} PermissionEnum;

typedef enum SynchronizeTypeEnum {
  dbRepExportChanges = 0x1,dbRepImportChanges = 0x2,dbRepImpExpChanges = 0x4,dbRepSyncInternet = 0x10
} SynchronizeTypeEnum;

typedef enum ReplicaTypeEnum {
  dbRepMakeReadOnly = 0x2,dbRepMakePartial = 0x1
} ReplicaTypeEnum;

typedef enum WorkspaceTypeEnum {
  dbUseODBC = 1,dbUseJet = 2
} WorkspaceTypeEnum;

typedef enum CursorDriverEnum {
  dbUseDefaultCursor = -1,dbUseODBCCursor = 1,dbUseServerCursor = 2,dbUseClientBatchCursor = 3,dbUseNoCursor = 4
} CursorDriverEnum;

typedef enum DriverPromptEnum {
  dbDriverPrompt = 2,dbDriverNoPrompt = 1,dbDriverComplete = 0,dbDriverCompleteRequired = 3
} DriverPromptEnum;

typedef enum SetOptionEnum {
  dbPageTimeout = 6,dbLockRetry = 57,dbMaxBufferSize = 8,dbUserCommitSync = 58,dbImplicitCommitSync = 59,dbExclusiveAsyncDelay = 60,
  dbSharedAsyncDelay = 61,dbMaxLocksPerFile = 62,dbLockDelay = 63,dbRecycleLVs = 65,dbFlushTransactionTimeout = 66
} SetOptionEnum;

typedef enum ParameterDirectionEnum {
  dbParamInput = 1,dbParamOutput = 2,dbParamInputOutput = 3,dbParamReturnValue = 4
} ParameterDirectionEnum;

typedef enum UpdateTypeEnum {
  dbUpdateBatch = 4,dbUpdateRegular = 1,dbUpdateCurrentRecord = 2
} UpdateTypeEnum;

typedef enum RecordStatusEnum {
  dbRecordUnmodified = 0,dbRecordModified = 1,dbRecordNew = 2,dbRecordDeleted = 3,dbRecordDBDeleted = 4
} RecordStatusEnum;

typedef enum CommitTransOptionsEnum {
  dbForceOSFlush = 1
} CommitTransOptionsEnum;

typedef enum _DAOSuppHelp {
  LogMessages = 0,KeepLocal = 0,Replicable = 0,ReplicableBool = 0,V1xNullBehavior = 0
} _DAOSuppHelp;

#define dbLangArabic _T(";LANGID=0x0401;CP=1256;COUNTRY=0")
#define dbLangCzech _T(";LANGID=0x0405;CP=1250;COUNTRY=0")
#define dbLangDutch _T(";LANGID=0x0413;CP=1252;COUNTRY=0")
#define dbLangGeneral _T(";LANGID=0x0409;CP=1252;COUNTRY=0")
#define dbLangGreek _T(";LANGID=0x0408;CP=1253;COUNTRY=0")
#define dbLangHebrew _T(";LANGID=0x040D;CP=1255;COUNTRY=0")
#define dbLangHungarian _T(";LANGID=0x040E;CP=1250;COUNTRY=0")
#define dbLangIcelandic _T(";LANGID=0x040F;CP=1252;COUNTRY=0")
#define dbLangNordic _T(";LANGID=0x041D;CP=1252;COUNTRY=0")
#define dbLangNorwDan _T(";LANGID=0x0414;CP=1252;COUNTRY=0")
#define dbLangPolish _T(";LANGID=0x0415;CP=1250;COUNTRY=0")
#define dbLangCyrillic _T(";LANGID=0x0419;CP=1251;COUNTRY=0")
#define dbLangSpanish _T(";LANGID=0x040A;CP=1252;COUNTRY=0")
#define dbLangSwedFin _T(";LANGID=0x040B;CP=1252;COUNTRY=0")
#define dbLangTurkish _T(";LANGID=0x041F;CP=1254;COUNTRY=0")
#define dbLangJapanese _T(";LANGID=0x0411;CP=932;COUNTRY=0")
#define dbLangChineseSimplified _T(";LANGID=0x0804;CP=936;COUNTRY=0")
#define dbLangChineseTraditional _T(";LANGID=0x0404;CP=950;COUNTRY=0")
#define dbLangKorean _T(";LANGID=0x0412;CP=949;COUNTRY=0")
#define dbLangThai _T(";LANGID=0x041E;CP=874;COUNTRY=0")
#define dbLangSlovenian _T(";LANGID=0x0424;CP=1250;COUNTRY=0")

#undef INTERFACE
#define INTERFACE _DAOCollection
DECLARE_INTERFACE_(_DAOCollection,IDispatch) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
#endif
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
};

#undef INTERFACE
#define INTERFACE _DAODynaCollection
DECLARE_INTERFACE_(_DAODynaCollection,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
};

#undef INTERFACE
#define INTERFACE _DAO
DECLARE_INTERFACE_(_DAO,IDispatch) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
#endif
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ interface DAOProperties **ppprops) PURE;
};

#undef INTERFACE
#define INTERFACE _DAODBEngine
DECLARE_INTERFACE_(_DAODBEngine,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ interface DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Version) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_IniPath) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_IniPath) (THIS_ BSTR path) PURE;
  STDMETHOD(put_DefaultUser) (THIS_ BSTR user) PURE;
  STDMETHOD(put_DefaultPassword) (THIS_ BSTR pw) PURE;
  STDMETHOD(get_LoginTimeout) (THIS_ short *ps) PURE;
  STDMETHOD(put_LoginTimeout) (THIS_ short Timeout) PURE;
  STDMETHOD(get_Workspaces) (THIS_ interface DAOWorkspaces **ppworks) PURE;
  STDMETHOD(get_Errors) (THIS_ interface DAOErrors **pperrs) PURE;
  STDMETHOD(Idle) (THIS_ VARIANT Action) PURE;
  STDMETHOD(CompactDatabase) (THIS_ BSTR SrcName,BSTR DstName,VARIANT DstLocale,VARIANT Options,VARIANT SrcLocale) PURE;
  STDMETHOD(RepairDatabase) (THIS_ BSTR Name) PURE;
  STDMETHOD(RegisterDatabase) (THIS_ BSTR Dsn,BSTR Driver,VARIANT_BOOL Silent,BSTR Attributes) PURE;
  STDMETHOD(_30_CreateWorkspace) (THIS_ BSTR Name,BSTR UserName,BSTR Password, interface DAOWorkspace **ppwrk) PURE;
  STDMETHOD(OpenDatabase) (THIS_ BSTR Name,VARIANT Options,VARIANT ReadOnly,VARIANT Connect, interface DAODatabase **ppdb) PURE;
  STDMETHOD(CreateDatabase) (THIS_ BSTR Name,BSTR Locale,VARIANT Option, interface DAODatabase **ppdb) PURE;
  STDMETHOD(FreeLocks) (THIS) PURE;
  STDMETHOD(BeginTrans) (THIS) PURE;
  STDMETHOD(CommitTrans) (THIS_ __LONG32 Option) PURE;
  STDMETHOD(Rollback) (THIS) PURE;
  STDMETHOD(SetDefaultWorkspace) (THIS_ BSTR Name,BSTR Password) PURE;
  STDMETHOD(SetDataAccessOption) (THIS_ short Option,VARIANT Value) PURE;
  STDMETHOD(ISAMStats) (THIS_ __LONG32 StatNum,VARIANT Reset,__LONG32 *pl) PURE;
  STDMETHOD(get_SystemDB) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_SystemDB) (THIS_ BSTR SystemDBPath) PURE;
  STDMETHOD(CreateWorkspace) (THIS_ BSTR Name,BSTR UserName,BSTR Password,VARIANT UseType, interface DAOWorkspace **ppwrk) PURE;
  STDMETHOD(OpenConnection) (THIS_ BSTR Name,VARIANT Options,VARIANT ReadOnly,VARIANT Connect, interface DAOConnection **ppconn) PURE;
  STDMETHOD(get_DefaultType) (THIS_ __LONG32 *Option) PURE;
  STDMETHOD(put_DefaultType) (THIS_ __LONG32 Option) PURE;
  STDMETHOD(SetOption) (THIS_ LONG Option,VARIANT Value) PURE;
  STDMETHOD(DumpObjects) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(DebugPrint) (THIS_ BSTR bstr) PURE;
};

#undef INTERFACE
#define INTERFACE DAOError
DECLARE_INTERFACE_(DAOError,IDispatch) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
#endif
  /*** DAOError ***/
  STDMETHOD(get_Number) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_Source) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Description) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_HelpFile) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_HelpContext) (THIS_ __LONG32 *pl) PURE;
};

#undef INTERFACE
#define INTERFACE DAOErrors
DECLARE_INTERFACE_(DAOErrors,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOError **pperr) PURE;
};

#undef INTERFACE
#define INTERFACE DAOProperty
DECLARE_INTERFACE_(DAOProperty,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ interface DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Value) (THIS_ VARIANT *pval) PURE;
  STDMETHOD(put_Value) (THIS_ VARIANT val) PURE;
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Type) (THIS_ short *ptype) PURE;
  STDMETHOD(put_Type) (THIS_ short type) PURE;
  STDMETHOD(get_Inherited) (THIS_ VARIANT_BOOL *pb) PURE;
};

#undef INTERFACE
#define INTERFACE DAOProperties
DECLARE_INTERFACE_(DAOProperties,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOProperty **ppprop) PURE;
};

#undef INTERFACE
#define INTERFACE DAOWorkspace
DECLARE_INTERFACE_(DAOWorkspace,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR Name) PURE;
  STDMETHOD(get_UserName) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put__30_UserName) (THIS_ BSTR UserName) PURE;
  STDMETHOD(put__30_Password) (THIS_ BSTR Password) PURE;
  STDMETHOD(get_IsolateODBCTrans) (THIS_ short *ps) PURE;
  STDMETHOD(put_IsolateODBCTrans) (THIS_ short s) PURE;
  STDMETHOD(get_Databases) (THIS_ interface DAODatabases **ppdbs) PURE;
  STDMETHOD(get_Users) (THIS_ interface DAOUsers **ppusrs) PURE;
  STDMETHOD(get_Groups) (THIS_ interface DAOGroups **ppgrps) PURE;
  STDMETHOD(BeginTrans) (THIS) PURE;
  STDMETHOD(CommitTrans) (THIS_ __LONG32 Options) PURE;
  STDMETHOD(Close) (THIS) PURE;
  STDMETHOD(Rollback) (THIS) PURE;
  STDMETHOD(OpenDatabase) (THIS_ BSTR Name,VARIANT Options,VARIANT ReadOnly,VARIANT Connect, interface DAODatabase **ppdb) PURE;
  STDMETHOD(CreateDatabase) (THIS_ BSTR Name,BSTR Connect,VARIANT Option, interface DAODatabase **ppdb) PURE;
  STDMETHOD(CreateUser) (THIS_ VARIANT Name,VARIANT PID,VARIANT Password, interface DAOUser **ppusr) PURE;
  STDMETHOD(CreateGroup) (THIS_ VARIANT Name,VARIANT PID, interface DAOGroup **ppgrp) PURE;
  STDMETHOD(OpenConnection) (THIS_ BSTR Name,VARIANT Options,VARIANT ReadOnly,VARIANT Connect, interface DAOConnection **ppconn) PURE;
  STDMETHOD(get_LoginTimeout) (THIS_ __LONG32 *pTimeout) PURE;
  STDMETHOD(put_LoginTimeout) (THIS_ __LONG32 Timeout) PURE;
  STDMETHOD(get_DefaultCursorDriver) (THIS_ __LONG32 *pCursorType) PURE;
  STDMETHOD(put_DefaultCursorDriver) (THIS_ __LONG32 CursorType) PURE;
  STDMETHOD(get_hEnv) (THIS_ LONG *phEnv) PURE;
  STDMETHOD(get_Type) (THIS_ LONG *ptype) PURE;
  STDMETHOD(get_Connections) (THIS_ interface DAOConnections **ppcns) PURE;
};

#undef INTERFACE
#define INTERFACE DAOWorkspaces
DECLARE_INTERFACE_(DAOWorkspaces,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOWorkspace **ppwrk) PURE;
};

#undef INTERFACE
#define INTERFACE DAOConnection
DECLARE_INTERFACE_(DAOConnection,IDispatch) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Connect) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Database) (THIS_ interface DAODatabase **ppDb) PURE;
  STDMETHOD(get_hDbc) (THIS_ LONG *phDbc) PURE;
  STDMETHOD(get_QueryTimeout) (THIS_ SHORT *pSeconds) PURE;
  STDMETHOD(put_QueryTimeout) (THIS_ SHORT Seconds) PURE;
  STDMETHOD(get_Transactions) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_RecordsAffected) (THIS_ LONG *pRecords) PURE;
  STDMETHOD(get_StillExecuting) (THIS_ VARIANT_BOOL *pStillExec) PURE;
  STDMETHOD(get_Updatable) (THIS_ VARIANT_BOOL *pStillExec) PURE;
  STDMETHOD(get_QueryDefs) (THIS_ interface DAOQueryDefs **ppqdfs) PURE;
  STDMETHOD(get_Recordsets) (THIS_ interface DAORecordsets **pprsts) PURE;
  STDMETHOD(Cancel) (THIS) PURE;
  STDMETHOD(Close) (THIS) PURE;
  STDMETHOD(CreateQueryDef) (THIS_ VARIANT Name,VARIANT SQLText, interface DAOQueryDef **ppqdf) PURE;
  STDMETHOD(Execute) (THIS_ BSTR Query,VARIANT Options) PURE;
  STDMETHOD(OpenRecordset) (THIS_ BSTR Name,VARIANT Type,VARIANT Options,VARIANT LockEdit, interface DAORecordset **pprst) PURE;
};

#undef INTERFACE
#define INTERFACE DAOConnections
DECLARE_INTERFACE_(DAOConnections,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOConnection **ppconn) PURE;
};

#undef INTERFACE
#define INTERFACE DAODatabase
DECLARE_INTERFACE_(DAODatabase,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_CollatingOrder) (THIS_ LONG *pl) PURE;
  STDMETHOD(get_Connect) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_QueryTimeout) (THIS_ short *ps) PURE;
  STDMETHOD(put_QueryTimeout) (THIS_ short Timeout) PURE;
  STDMETHOD(get_Transactions) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Updatable) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Version) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_RecordsAffected) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_TableDefs) (THIS_ interface DAOTableDefs **pptdfs) PURE;
  STDMETHOD(get_QueryDefs) (THIS_ interface DAOQueryDefs **ppqdfs) PURE;
  STDMETHOD(get_Relations) (THIS_ interface DAORelations **pprls) PURE;
  STDMETHOD(get_Containers) (THIS_ interface DAOContainers **ppctns) PURE;
  STDMETHOD(get_Recordsets) (THIS_ interface DAORecordsets **pprsts) PURE;
  STDMETHOD(Close) (THIS) PURE;
  STDMETHOD(Execute) (THIS_ BSTR Query,VARIANT Options) PURE;
  STDMETHOD(_30_OpenRecordset) (THIS_ BSTR Name,VARIANT Type,VARIANT Options, interface DAORecordset **pprst) PURE;
  STDMETHOD(CreateProperty) (THIS_ VARIANT Name,VARIANT Type,VARIANT Value,VARIANT DDL,DAOProperty **pprp) PURE;
  STDMETHOD(CreateRelation) (THIS_ VARIANT Name,VARIANT Table,VARIANT ForeignTable,VARIANT Attributes, interface DAORelation **pprel) PURE;
  STDMETHOD(CreateTableDef) (THIS_ VARIANT Name,VARIANT Attributes,VARIANT SourceTablename,VARIANT Connect, interface DAOTableDef **pptdf) PURE;
  STDMETHOD(BeginTrans) (THIS) PURE;
  STDMETHOD(CommitTrans) (THIS_ __LONG32 Options) PURE;
  STDMETHOD(Rollback) (THIS) PURE;
  STDMETHOD(CreateDynaset) (THIS_ BSTR Name,VARIANT Options,VARIANT Inconsistent, interface DAORecordset **pprst) PURE;
  STDMETHOD(CreateQueryDef) (THIS_ VARIANT Name,VARIANT SQLText, interface DAOQueryDef **ppqdf) PURE;
  STDMETHOD(CreateSnapshot) (THIS_ BSTR Source,VARIANT Options, interface DAORecordset **pprst) PURE;
  STDMETHOD(DeleteQueryDef) (THIS_ BSTR Name) PURE;
  STDMETHOD(ExecuteSQL) (THIS_ BSTR SQL,__LONG32 *pl) PURE;
  STDMETHOD(ListFields) (THIS_ BSTR Name, interface DAORecordset **pprst) PURE;
  STDMETHOD(ListTables) (THIS_ interface DAORecordset **pprst) PURE;
  STDMETHOD(OpenQueryDef) (THIS_ BSTR Name, interface DAOQueryDef **ppqdf) PURE;
  STDMETHOD(OpenTable) (THIS_ BSTR Name,VARIANT Options, interface DAORecordset **pprst) PURE;
  STDMETHOD(get_ReplicaID) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_DesignMasterID) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_DesignMasterID) (THIS_ BSTR MasterID) PURE;
  STDMETHOD(Synchronize) (THIS_ BSTR DbPathName,VARIANT ExchangeType) PURE;
  STDMETHOD(MakeReplica) (THIS_ BSTR PathName,BSTR Description,VARIANT Options) PURE;
  STDMETHOD(put_Connect) (THIS_ BSTR ODBCConnnect) PURE;
  STDMETHOD(NewPassword) (THIS_ BSTR bstrOld,BSTR bstrNew) PURE;
  STDMETHOD(OpenRecordset) (THIS_ BSTR Name,VARIANT Type,VARIANT Options,VARIANT LockEdit, interface DAORecordset **pprst) PURE;
  STDMETHOD(get_Connection) (THIS_ DAOConnection **ppCn) PURE;
  STDMETHOD(PopulatePartial) (THIS_ BSTR DbPathName) PURE;
};

#undef INTERFACE
#define INTERFACE DAODatabases
DECLARE_INTERFACE_(DAODatabases,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAODatabase **ppdb) PURE;
};

#undef INTERFACE
#define INTERFACE _DAOTableDef
DECLARE_INTERFACE_(_DAOTableDef,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Attributes) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_Attributes) (THIS_ __LONG32 Attributes) PURE;
  STDMETHOD(get_Connect) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Connect) (THIS_ BSTR Connection) PURE;
  STDMETHOD(get_DateCreated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_LastUpdated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR Name) PURE;
  STDMETHOD(get_SourceTableName) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_SourceTableName) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Updatable) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_ValidationText) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_ValidationText) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_ValidationRule) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_ValidationRule) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_RecordCount) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_Fields) (THIS_ interface DAOFields **ppflds) PURE;
  STDMETHOD(get_Indexes) (THIS_ interface DAOIndexes **ppidxs) PURE;
  STDMETHOD(OpenRecordset) (THIS_ VARIANT Type,VARIANT Options, interface DAORecordset **pprst) PURE;
  STDMETHOD(RefreshLink) (THIS) PURE;
  STDMETHOD(CreateField) (THIS_ VARIANT Name,VARIANT Type,VARIANT Size, interface DAOField **ppfld) PURE;
  STDMETHOD(CreateIndex) (THIS_ VARIANT Name, interface DAOIndex **ppidx) PURE;
  STDMETHOD(CreateProperty) (THIS_ VARIANT Name,VARIANT Type,VARIANT Value,VARIANT DDL,DAOProperty **pprp) PURE;
  STDMETHOD(get_ConflictTable) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_ReplicaFilter) (THIS_ VARIANT *pFilter) PURE;
  STDMETHOD(put_ReplicaFilter) (THIS_ VARIANT Filter) PURE;
};

#undef INTERFACE
#define INTERFACE DAOTableDefs
DECLARE_INTERFACE_(DAOTableDefs,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOTableDef **pptdf) PURE;
};

#undef INTERFACE
#define INTERFACE _DAOQueryDef
DECLARE_INTERFACE_(_DAOQueryDef,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_DateCreated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_LastUpdated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_ODBCTimeout) (THIS_ short *ps) PURE;
  STDMETHOD(put_ODBCTimeout) (THIS_ short timeout) PURE;
  STDMETHOD(get_Type) (THIS_ short *pi) PURE;
  STDMETHOD(get_SQL) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_SQL) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Updatable) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Connect) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Connect) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_ReturnsRecords) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_ReturnsRecords) (THIS_ VARIANT_BOOL f) PURE;
  STDMETHOD(get_RecordsAffected) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_Fields) (THIS_ interface DAOFields **ppflds) PURE;
  STDMETHOD(get_Parameters) (THIS_ interface DAOParameters **ppprms) PURE;
  STDMETHOD(Close) (THIS) PURE;
  STDMETHOD(_30_OpenRecordset) (THIS_ VARIANT Type,VARIANT Options, interface DAORecordset **pprst) PURE;
  STDMETHOD(_30__OpenRecordset) (THIS_ VARIANT Type,VARIANT Options, interface DAORecordset **pprst) PURE;
  STDMETHOD(_Copy) (THIS_ DAOQueryDef **ppqdf) PURE;
  STDMETHOD(Execute) (THIS_ VARIANT Options) PURE;
  STDMETHOD(Compare) (THIS_ DAOQueryDef *pQdef,SHORT *lps) PURE;
  STDMETHOD(CreateDynaset) (THIS_ VARIANT Options,VARIANT Inconsistent, interface DAORecordset **pprst) PURE;
  STDMETHOD(CreateSnapshot) (THIS_ VARIANT Options, interface DAORecordset **pprst) PURE;
  STDMETHOD(ListParameters) (THIS_ interface DAORecordset **pprst) PURE;
  STDMETHOD(CreateProperty) (THIS_ VARIANT Name,VARIANT Type,VARIANT Value,VARIANT DDL,DAOProperty **pprp) PURE;
  STDMETHOD(OpenRecordset) (THIS_ VARIANT Type,VARIANT Options,VARIANT LockEdit, interface DAORecordset **pprst) PURE;
  STDMETHOD(_OpenRecordset) (THIS_ VARIANT Type,VARIANT Options,VARIANT LockEdit, interface DAORecordset **pprst) PURE;
  STDMETHOD(Cancel) (THIS) PURE;
  STDMETHOD(get_hStmt) (THIS_ LONG *phStmt) PURE;
  STDMETHOD(get_MaxRecords) (THIS_ LONG *pMxRecs) PURE;
  STDMETHOD(put_MaxRecords) (THIS_ LONG MxRecs) PURE;
  STDMETHOD(get_StillExecuting) (THIS_ VARIANT_BOOL *pStillExec) PURE;
  STDMETHOD(get_CacheSize) (THIS_ __LONG32 *lCacheSize) PURE;
  STDMETHOD(put_CacheSize) (THIS_ __LONG32 lCacheSize) PURE;
  STDMETHOD(get_Prepare) (THIS_ VARIANT *pb) PURE;
  STDMETHOD(put_Prepare) (THIS_ VARIANT f) PURE;
};

#undef INTERFACE
#define INTERFACE DAOQueryDefs
DECLARE_INTERFACE_(DAOQueryDefs,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOQueryDef **ppqdef) PURE;
};

#undef INTERFACE
#define INTERFACE DAORecordset
DECLARE_INTERFACE_(DAORecordset,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_BOF) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Bookmark) (THIS_ SAFEARRAY **ppsach) PURE;
  STDMETHOD(put_Bookmark) (THIS_ SAFEARRAY **psach) PURE;
  STDMETHOD(get_Bookmarkable) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_DateCreated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_EOF) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Filter) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Filter) (THIS_ BSTR Filter) PURE;
  STDMETHOD(get_Index) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Index) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_LastModified) (THIS_ SAFEARRAY **ppsa) PURE;
  STDMETHOD(get_LastUpdated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_LockEdits) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_LockEdits) (THIS_ VARIANT_BOOL Lock) PURE;
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_NoMatch) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Sort) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Sort) (THIS_ BSTR Sort) PURE;
  STDMETHOD(get_Transactions) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Type) (THIS_ short *ps) PURE;
  STDMETHOD(get_RecordCount) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_Updatable) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Restartable) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_ValidationText) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_ValidationRule) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_CacheStart) (THIS_ SAFEARRAY **ppsa) PURE;
  STDMETHOD(put_CacheStart) (THIS_ SAFEARRAY **psa) PURE;
  STDMETHOD(get_CacheSize) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_CacheSize) (THIS_ __LONG32 CacheSize) PURE;
  STDMETHOD(get_PercentPosition) (THIS_ float *pd) PURE;
  STDMETHOD(put_PercentPosition) (THIS_ float Position) PURE;
  STDMETHOD(get_AbsolutePosition) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_AbsolutePosition) (THIS_ __LONG32 Position) PURE;
  STDMETHOD(get_EditMode) (THIS_ short *pi) PURE;
  STDMETHOD(get_ODBCFetchCount) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_ODBCFetchDelay) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_Parent) (THIS_ DAODatabase **pdb) PURE;
  STDMETHOD(get_Fields) (THIS_ interface DAOFields **ppflds) PURE;
  STDMETHOD(get_Indexes) (THIS_ interface DAOIndexes **ppidxs) PURE;
  STDMETHOD(_30_CancelUpdate) (THIS) PURE;
  STDMETHOD(AddNew) (THIS) PURE;
  STDMETHOD(Close) (THIS) PURE;
  STDMETHOD(OpenRecordset) (THIS_ VARIANT Type,VARIANT Options,DAORecordset **pprst) PURE;
  STDMETHOD(Delete) (THIS) PURE;
  STDMETHOD(Edit) (THIS) PURE;
  STDMETHOD(FindFirst) (THIS_ BSTR Criteria) PURE;
  STDMETHOD(FindLast) (THIS_ BSTR Criteria) PURE;
  STDMETHOD(FindNext) (THIS_ BSTR Criteria) PURE;
  STDMETHOD(FindPrevious) (THIS_ BSTR Criteria) PURE;
  STDMETHOD(MoveFirst) (THIS) PURE;
  STDMETHOD(_30_MoveLast) (THIS) PURE;
  STDMETHOD(MoveNext) (THIS) PURE;
  STDMETHOD(MovePrevious) (THIS) PURE;
  STDMETHOD(Seek) (THIS_ BSTR Comparison,VARIANT Key1,VARIANT Key2,VARIANT Key3,VARIANT Key4,VARIANT Key5,VARIANT Key6,VARIANT Key7,VARIANT Key8,VARIANT Key9,VARIANT Key10,VARIANT Key11,VARIANT Key12,VARIANT Key13) PURE;
  STDMETHOD(_30_Update) (THIS) PURE;
  STDMETHOD(Clone) (THIS_ DAORecordset **pprst) PURE;
  STDMETHOD(Requery) (THIS_ VARIANT NewQueryDef) PURE;
  STDMETHOD(Move) (THIS_ __LONG32 Rows,VARIANT StartBookmark) PURE;
  STDMETHOD(FillCache) (THIS_ VARIANT Rows,VARIANT StartBookmark) PURE;
  STDMETHOD(CreateDynaset) (THIS_ VARIANT Options,VARIANT Inconsistent,DAORecordset **pprst) PURE;
  STDMETHOD(CreateSnapshot) (THIS_ VARIANT Options,DAORecordset **pprst) PURE;
  STDMETHOD(CopyQueryDef) (THIS_ DAOQueryDef **ppqdf) PURE;
  STDMETHOD(ListFields) (THIS_ DAORecordset **pprst) PURE;
  STDMETHOD(ListIndexes) (THIS_ DAORecordset **pprst) PURE;
  STDMETHOD(GetRows) (THIS_ VARIANT NumRows,VARIANT *pvar) PURE;
  STDMETHOD(get_Collect) (THIS_ VARIANT Item,VARIANT *pvar) PURE;
  STDMETHOD(put_Collect) (THIS_ VARIANT Item,VARIANT value) PURE;
  STDMETHOD(Cancel) (THIS) PURE;
  STDMETHOD(NextRecordset) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_hStmt) (THIS_ LONG *phStmt) PURE;
  STDMETHOD(get_StillExecuting) (THIS_ VARIANT_BOOL *pStillExec) PURE;
  STDMETHOD(get_BatchSize) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_BatchSize) (THIS_ __LONG32 BatchSize) PURE;
  STDMETHOD(get_BatchCollisionCount) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_BatchCollisions) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_Connection) (THIS_ DAOConnection **ppCn) PURE;
  STDMETHOD(putref_Connection) (THIS_ DAOConnection *pNewCn) PURE;
  STDMETHOD(get_RecordStatus) (THIS_ short *pi) PURE;
  STDMETHOD(get_UpdateOptions) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_UpdateOptions) (THIS_ __LONG32 l) PURE;
  STDMETHOD(CancelUpdate) (THIS_ __LONG32 UpdateType) PURE;
  STDMETHOD(Update) (THIS_ __LONG32 UpdateType,VARIANT_BOOL Force) PURE;
  STDMETHOD(MoveLast) (THIS_ __LONG32 Options) PURE;
};

#undef INTERFACE
#define INTERFACE DAORecordsets
DECLARE_INTERFACE_(DAORecordsets,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAORecordset **pprst) PURE;
};

#undef INTERFACE
#define INTERFACE _DAOField
DECLARE_INTERFACE_(_DAOField,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_CollatingOrder) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_Type) (THIS_ short *ps) PURE;
  STDMETHOD(put_Type) (THIS_ short Type) PURE;
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR Name) PURE;
  STDMETHOD(get_Size) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_Size) (THIS_ __LONG32 Size) PURE;
  STDMETHOD(get_SourceField) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_SourceTable) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Value) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(put_Value) (THIS_ VARIANT Val) PURE;
  STDMETHOD(get_Attributes) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_Attributes) (THIS_ __LONG32 Attr) PURE;
  STDMETHOD(get_OrdinalPosition) (THIS_ short *ps) PURE;
  STDMETHOD(put_OrdinalPosition) (THIS_ short Pos) PURE;
  STDMETHOD(get_ValidationText) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_ValidationText) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_ValidateOnSet) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_ValidateOnSet) (THIS_ VARIANT_BOOL Validate) PURE;
  STDMETHOD(get_ValidationRule) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_ValidationRule) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_DefaultValue) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(put_DefaultValue) (THIS_ VARIANT var) PURE;
  STDMETHOD(get_Required) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_Required) (THIS_ VARIANT_BOOL fReq) PURE;
  STDMETHOD(get_AllowZeroLength) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_AllowZeroLength) (THIS_ VARIANT_BOOL fAllow) PURE;
  STDMETHOD(get_DataUpdatable) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_ForeignName) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_ForeignName) (THIS_ BSTR bstr) PURE;
  STDMETHOD(AppendChunk) (THIS_ VARIANT Val) PURE;
  STDMETHOD(GetChunk) (THIS_ __LONG32 Offset,__LONG32 Bytes,VARIANT *pvar) PURE;
  STDMETHOD(_30_FieldSize) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(CreateProperty) (THIS_ VARIANT Name,VARIANT Type,VARIANT Value,VARIANT DDL,DAOProperty **pprp) PURE;
  STDMETHOD(get_CollectionIndex) (THIS_ short *i) PURE;
  STDMETHOD(get_OriginalValue) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_VisibleValue) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_FieldSize) (THIS_ __LONG32 *pl) PURE;
};

#undef INTERFACE
#define INTERFACE DAOFields
DECLARE_INTERFACE_(DAOFields,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOField **ppfld) PURE;
};

#undef INTERFACE
#define INTERFACE _DAOIndex
DECLARE_INTERFACE_(_DAOIndex,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Foreign) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(get_Unique) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_Unique) (THIS_ VARIANT_BOOL fUnique) PURE;
  STDMETHOD(get_Clustered) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_Clustered) (THIS_ VARIANT_BOOL fClustered) PURE;
  STDMETHOD(get_Required) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_Required) (THIS_ VARIANT_BOOL fRequired) PURE;
  STDMETHOD(get_IgnoreNulls) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_IgnoreNulls) (THIS_ VARIANT_BOOL fIgnoreNulls) PURE;
  STDMETHOD(get_Primary) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_Primary) (THIS_ VARIANT_BOOL fPrimary) PURE;
  STDMETHOD(get_DistinctCount) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(get_Fields) (THIS_ VARIANT *pv) PURE;
  STDMETHOD(put_Fields) (THIS_ VARIANT v) PURE;
  STDMETHOD(CreateField) (THIS_ VARIANT Name,VARIANT Type,VARIANT Size,DAOField **ppfld) PURE;
  STDMETHOD(CreateProperty) (THIS_ VARIANT Name,VARIANT Type,VARIANT Value,VARIANT DDL,DAOProperty **pprp) PURE;
};

#undef INTERFACE
#define INTERFACE DAOIndexes
DECLARE_INTERFACE_(DAOIndexes,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOIndex **ppidx) PURE;
};

#undef INTERFACE
#define INTERFACE DAOParameter
DECLARE_INTERFACE_(DAOParameter,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Value) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(put_Value) (THIS_ VARIANT val) PURE;
  STDMETHOD(get_Type) (THIS_ short *ps) PURE;
  STDMETHOD(put_Type) (THIS_ short s) PURE;
  STDMETHOD(get_Direction) (THIS_ short *pOption) PURE;
  STDMETHOD(put_Direction) (THIS_ short Option) PURE;
};

#undef INTERFACE
#define INTERFACE DAOParameters
DECLARE_INTERFACE_(DAOParameters,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOParameter **ppprm) PURE;
};

#undef INTERFACE
#define INTERFACE _DAOUser
DECLARE_INTERFACE_(_DAOUser,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR bstr) PURE;
  STDMETHOD(put_PID) (THIS_ BSTR bstr) PURE;
  STDMETHOD(put_Password) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Groups) (THIS_ interface DAOGroups **ppgrps) PURE;
  STDMETHOD(NewPassword) (THIS_ BSTR bstrOld,BSTR bstrNew) PURE;
  STDMETHOD(CreateGroup) (THIS_ VARIANT Name,VARIANT PID, interface DAOGroup **ppgrp) PURE;
};

#undef INTERFACE
#define INTERFACE DAOUsers
DECLARE_INTERFACE_(DAOUsers,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOUser **ppusr) PURE;
};

#undef INTERFACE
#define INTERFACE _DAOGroup
DECLARE_INTERFACE_(_DAOGroup,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR bstr) PURE;
  STDMETHOD(put_PID) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Users) (THIS_ DAOUsers **ppusrs) PURE;
  STDMETHOD(CreateUser) (THIS_ VARIANT Name,VARIANT PID,VARIANT Password,DAOUser **ppusr) PURE;
};

#undef INTERFACE
#define INTERFACE DAOGroups
DECLARE_INTERFACE_(DAOGroups,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOGroup **ppgrp) PURE;
};

#undef INTERFACE
#define INTERFACE _DAORelation
DECLARE_INTERFACE_(_DAORelation,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Name) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Table) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Table) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_ForeignTable) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_ForeignTable) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Attributes) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_Attributes) (THIS_ __LONG32 attr) PURE;
  STDMETHOD(get_Fields) (THIS_ DAOFields **ppflds) PURE;
  STDMETHOD(CreateField) (THIS_ VARIANT Name,VARIANT Type,VARIANT Size,DAOField **ppfld) PURE;
  STDMETHOD(get_PartialReplica) (THIS_ VARIANT_BOOL *pfPartialReplica) PURE;
  STDMETHOD(put_PartialReplica) (THIS_ VARIANT_BOOL fPartialReplica) PURE;
};

#undef INTERFACE
#define INTERFACE DAORelations
DECLARE_INTERFACE_(DAORelations,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAORelation **pprel) PURE;
};

#undef INTERFACE
#define INTERFACE DAOContainer
DECLARE_INTERFACE_(DAOContainer,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Owner) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Owner) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_UserName) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_UserName) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Permissions) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_Permissions) (THIS_ __LONG32 permissions) PURE;
  STDMETHOD(get_Inherit) (THIS_ VARIANT_BOOL *pb) PURE;
  STDMETHOD(put_Inherit) (THIS_ VARIANT_BOOL fInherit) PURE;
  STDMETHOD(get_Documents) (THIS_ struct DAODocuments **ppdocs) PURE;
  STDMETHOD(get_AllPermissions) (THIS_ __LONG32 *pl) PURE;
};

#undef INTERFACE
#define INTERFACE DAOContainers
DECLARE_INTERFACE_(DAOContainers,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAOContainer **ppctn) PURE;
};

#undef INTERFACE
#define INTERFACE DAODocument
DECLARE_INTERFACE_(DAODocument,_DAO) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAO ***/
  STDMETHOD(get_Properties) (THIS_ DAOProperties **ppprops) PURE;
#endif
  STDMETHOD(get_Name) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_Owner) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_Owner) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Container) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(get_UserName) (THIS_ BSTR *pbstr) PURE;
  STDMETHOD(put_UserName) (THIS_ BSTR bstr) PURE;
  STDMETHOD(get_Permissions) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(put_Permissions) (THIS_ __LONG32 permissions) PURE;
  STDMETHOD(get_DateCreated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_LastUpdated) (THIS_ VARIANT *pvar) PURE;
  STDMETHOD(get_AllPermissions) (THIS_ __LONG32 *pl) PURE;
  STDMETHOD(CreateProperty) (THIS_ VARIANT Name,VARIANT Type,VARIANT Value,VARIANT DDL,DAOProperty **pprp) PURE;
};

#undef INTERFACE
#define INTERFACE DAODocuments
DECLARE_INTERFACE_(DAODocuments,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,DAODocument **ppdoc) PURE;
};

#undef INTERFACE
#define INTERFACE DAOIndexFields
DECLARE_INTERFACE_(DAOIndexFields,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT Item,VARIANT *pvar) PURE;
};
#endif
