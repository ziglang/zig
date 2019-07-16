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

#ifndef __oledb_h__
#define __oledb_h__

#ifndef __IAccessor_FWD_DEFINED__
#define __IAccessor_FWD_DEFINED__
typedef struct IAccessor IAccessor;
#endif

#ifndef __IRowset_FWD_DEFINED__
#define __IRowset_FWD_DEFINED__
typedef struct IRowset IRowset;
#endif

#ifndef __IRowsetInfo_FWD_DEFINED__
#define __IRowsetInfo_FWD_DEFINED__
typedef struct IRowsetInfo IRowsetInfo;
#endif

#ifndef __IRowsetLocate_FWD_DEFINED__
#define __IRowsetLocate_FWD_DEFINED__
typedef struct IRowsetLocate IRowsetLocate;
#endif

#ifndef __IRowsetResynch_FWD_DEFINED__
#define __IRowsetResynch_FWD_DEFINED__
typedef struct IRowsetResynch IRowsetResynch;
#endif

#ifndef __IRowsetScroll_FWD_DEFINED__
#define __IRowsetScroll_FWD_DEFINED__
typedef struct IRowsetScroll IRowsetScroll;
#endif

#ifndef __IChapteredRowset_FWD_DEFINED__
#define __IChapteredRowset_FWD_DEFINED__
typedef struct IChapteredRowset IChapteredRowset;
#endif

#ifndef __IRowsetFind_FWD_DEFINED__
#define __IRowsetFind_FWD_DEFINED__
typedef struct IRowsetFind IRowsetFind;
#endif

#ifndef __IRowPosition_FWD_DEFINED__
#define __IRowPosition_FWD_DEFINED__
typedef struct IRowPosition IRowPosition;
#endif

#ifndef __IRowPositionChange_FWD_DEFINED__
#define __IRowPositionChange_FWD_DEFINED__
typedef struct IRowPositionChange IRowPositionChange;
#endif

#ifndef __IViewRowset_FWD_DEFINED__
#define __IViewRowset_FWD_DEFINED__
typedef struct IViewRowset IViewRowset;
#endif

#ifndef __IViewChapter_FWD_DEFINED__
#define __IViewChapter_FWD_DEFINED__
typedef struct IViewChapter IViewChapter;
#endif

#ifndef __IViewSort_FWD_DEFINED__
#define __IViewSort_FWD_DEFINED__
typedef struct IViewSort IViewSort;
#endif

#ifndef __IViewFilter_FWD_DEFINED__
#define __IViewFilter_FWD_DEFINED__
typedef struct IViewFilter IViewFilter;
#endif

#ifndef __IRowsetView_FWD_DEFINED__
#define __IRowsetView_FWD_DEFINED__
typedef struct IRowsetView IRowsetView;
#endif

#ifndef __IRowsetExactScroll_FWD_DEFINED__
#define __IRowsetExactScroll_FWD_DEFINED__
typedef struct IRowsetExactScroll IRowsetExactScroll;
#endif

#ifndef __IRowsetChange_FWD_DEFINED__
#define __IRowsetChange_FWD_DEFINED__
typedef struct IRowsetChange IRowsetChange;
#endif

#ifndef __IRowsetUpdate_FWD_DEFINED__
#define __IRowsetUpdate_FWD_DEFINED__
typedef struct IRowsetUpdate IRowsetUpdate;
#endif

#ifndef __IRowsetIdentity_FWD_DEFINED__
#define __IRowsetIdentity_FWD_DEFINED__
typedef struct IRowsetIdentity IRowsetIdentity;
#endif

#ifndef __IRowsetNotify_FWD_DEFINED__
#define __IRowsetNotify_FWD_DEFINED__
typedef struct IRowsetNotify IRowsetNotify;
#endif

#ifndef __IRowsetIndex_FWD_DEFINED__
#define __IRowsetIndex_FWD_DEFINED__
typedef struct IRowsetIndex IRowsetIndex;
#endif

#ifndef __ICommand_FWD_DEFINED__
#define __ICommand_FWD_DEFINED__
typedef struct ICommand ICommand;
#endif

#ifndef __IMultipleResults_FWD_DEFINED__
#define __IMultipleResults_FWD_DEFINED__
typedef struct IMultipleResults IMultipleResults;
#endif

#ifndef __IConvertType_FWD_DEFINED__
#define __IConvertType_FWD_DEFINED__
typedef struct IConvertType IConvertType;
#endif

#ifndef __ICommandPrepare_FWD_DEFINED__
#define __ICommandPrepare_FWD_DEFINED__
typedef struct ICommandPrepare ICommandPrepare;
#endif

#ifndef __ICommandProperties_FWD_DEFINED__
#define __ICommandProperties_FWD_DEFINED__
typedef struct ICommandProperties ICommandProperties;
#endif

#ifndef __ICommandText_FWD_DEFINED__
#define __ICommandText_FWD_DEFINED__
typedef struct ICommandText ICommandText;
#endif

#ifndef __ICommandWithParameters_FWD_DEFINED__
#define __ICommandWithParameters_FWD_DEFINED__
typedef struct ICommandWithParameters ICommandWithParameters;
#endif

#ifndef __IColumnsRowset_FWD_DEFINED__
#define __IColumnsRowset_FWD_DEFINED__
typedef struct IColumnsRowset IColumnsRowset;
#endif

#ifndef __IColumnsInfo_FWD_DEFINED__
#define __IColumnsInfo_FWD_DEFINED__
typedef struct IColumnsInfo IColumnsInfo;
#endif

#ifndef __IDBCreateCommand_FWD_DEFINED__
#define __IDBCreateCommand_FWD_DEFINED__
typedef struct IDBCreateCommand IDBCreateCommand;
#endif

#ifndef __IDBCreateSession_FWD_DEFINED__
#define __IDBCreateSession_FWD_DEFINED__
typedef struct IDBCreateSession IDBCreateSession;
#endif

#ifndef __ISourcesRowset_FWD_DEFINED__
#define __ISourcesRowset_FWD_DEFINED__
typedef struct ISourcesRowset ISourcesRowset;
#endif

#ifndef __IDBProperties_FWD_DEFINED__
#define __IDBProperties_FWD_DEFINED__
typedef struct IDBProperties IDBProperties;
#endif

#ifndef __IDBInitialize_FWD_DEFINED__
#define __IDBInitialize_FWD_DEFINED__
typedef struct IDBInitialize IDBInitialize;
#endif

#ifndef __IDBInfo_FWD_DEFINED__
#define __IDBInfo_FWD_DEFINED__
typedef struct IDBInfo IDBInfo;
#endif

#ifndef __IDBDataSourceAdmin_FWD_DEFINED__
#define __IDBDataSourceAdmin_FWD_DEFINED__
typedef struct IDBDataSourceAdmin IDBDataSourceAdmin;
#endif

#ifndef __IDBAsynchNotify_FWD_DEFINED__
#define __IDBAsynchNotify_FWD_DEFINED__
typedef struct IDBAsynchNotify IDBAsynchNotify;
#endif

#ifndef __IDBAsynchStatus_FWD_DEFINED__
#define __IDBAsynchStatus_FWD_DEFINED__
typedef struct IDBAsynchStatus IDBAsynchStatus;
#endif

#ifndef __ISessionProperties_FWD_DEFINED__
#define __ISessionProperties_FWD_DEFINED__
typedef struct ISessionProperties ISessionProperties;
#endif

#ifndef __IIndexDefinition_FWD_DEFINED__
#define __IIndexDefinition_FWD_DEFINED__
typedef struct IIndexDefinition IIndexDefinition;
#endif

#ifndef __ITableDefinition_FWD_DEFINED__
#define __ITableDefinition_FWD_DEFINED__
typedef struct ITableDefinition ITableDefinition;
#endif

#ifndef __IOpenRowset_FWD_DEFINED__
#define __IOpenRowset_FWD_DEFINED__
typedef struct IOpenRowset IOpenRowset;
#endif

#ifndef __IDBSchemaRowset_FWD_DEFINED__
#define __IDBSchemaRowset_FWD_DEFINED__
typedef struct IDBSchemaRowset IDBSchemaRowset;
#endif

#ifndef __IMDDataset_FWD_DEFINED__
#define __IMDDataset_FWD_DEFINED__
typedef struct IMDDataset IMDDataset;
#endif

#ifndef __IMDFind_FWD_DEFINED__
#define __IMDFind_FWD_DEFINED__
typedef struct IMDFind IMDFind;
#endif

#ifndef __IMDRangeRowset_FWD_DEFINED__
#define __IMDRangeRowset_FWD_DEFINED__
typedef struct IMDRangeRowset IMDRangeRowset;
#endif

#ifndef __IAlterTable_FWD_DEFINED__
#define __IAlterTable_FWD_DEFINED__
typedef struct IAlterTable IAlterTable;
#endif

#ifndef __IAlterIndex_FWD_DEFINED__
#define __IAlterIndex_FWD_DEFINED__
typedef struct IAlterIndex IAlterIndex;
#endif

#ifndef __IRowsetChapterMember_FWD_DEFINED__
#define __IRowsetChapterMember_FWD_DEFINED__
typedef struct IRowsetChapterMember IRowsetChapterMember;
#endif

#ifndef __ICommandPersist_FWD_DEFINED__
#define __ICommandPersist_FWD_DEFINED__
typedef struct ICommandPersist ICommandPersist;
#endif

#ifndef __IRowsetRefresh_FWD_DEFINED__
#define __IRowsetRefresh_FWD_DEFINED__
typedef struct IRowsetRefresh IRowsetRefresh;
#endif

#ifndef __IParentRowset_FWD_DEFINED__
#define __IParentRowset_FWD_DEFINED__
typedef struct IParentRowset IParentRowset;
#endif

#ifndef __IErrorRecords_FWD_DEFINED__
#define __IErrorRecords_FWD_DEFINED__
typedef struct IErrorRecords IErrorRecords;
#endif

#ifndef __IErrorLookup_FWD_DEFINED__
#define __IErrorLookup_FWD_DEFINED__
typedef struct IErrorLookup IErrorLookup;
#endif

#ifndef __ISQLErrorInfo_FWD_DEFINED__
#define __ISQLErrorInfo_FWD_DEFINED__
typedef struct ISQLErrorInfo ISQLErrorInfo;
#endif

#ifndef __IGetDataSource_FWD_DEFINED__
#define __IGetDataSource_FWD_DEFINED__
typedef struct IGetDataSource IGetDataSource;
#endif

#ifndef __ITransactionLocal_FWD_DEFINED__
#define __ITransactionLocal_FWD_DEFINED__
typedef struct ITransactionLocal ITransactionLocal;
#endif

#ifndef __ITransactionJoin_FWD_DEFINED__
#define __ITransactionJoin_FWD_DEFINED__
typedef struct ITransactionJoin ITransactionJoin;
#endif

#ifndef __ITransactionObject_FWD_DEFINED__
#define __ITransactionObject_FWD_DEFINED__
typedef struct ITransactionObject ITransactionObject;
#endif

#ifndef __ITrusteeAdmin_FWD_DEFINED__
#define __ITrusteeAdmin_FWD_DEFINED__
typedef struct ITrusteeAdmin ITrusteeAdmin;
#endif

#ifndef __ITrusteeGroupAdmin_FWD_DEFINED__
#define __ITrusteeGroupAdmin_FWD_DEFINED__
typedef struct ITrusteeGroupAdmin ITrusteeGroupAdmin;
#endif

#ifndef __IObjectAccessControl_FWD_DEFINED__
#define __IObjectAccessControl_FWD_DEFINED__
typedef struct IObjectAccessControl IObjectAccessControl;
#endif

#ifndef __ISecurityInfo_FWD_DEFINED__
#define __ISecurityInfo_FWD_DEFINED__
typedef struct ISecurityInfo ISecurityInfo;
#endif

#ifndef __ITableCreation_FWD_DEFINED__
#define __ITableCreation_FWD_DEFINED__
typedef struct ITableCreation ITableCreation;
#endif

#ifndef __ITableDefinitionWithConstraints_FWD_DEFINED__
#define __ITableDefinitionWithConstraints_FWD_DEFINED__
typedef struct ITableDefinitionWithConstraints ITableDefinitionWithConstraints;
#endif

#ifndef __IRow_FWD_DEFINED__
#define __IRow_FWD_DEFINED__
typedef struct IRow IRow;
#endif

#ifndef __IRowChange_FWD_DEFINED__
#define __IRowChange_FWD_DEFINED__
typedef struct IRowChange IRowChange;
#endif

#ifndef __IRowSchemaChange_FWD_DEFINED__
#define __IRowSchemaChange_FWD_DEFINED__
typedef struct IRowSchemaChange IRowSchemaChange;
#endif

#ifndef __IGetRow_FWD_DEFINED__
#define __IGetRow_FWD_DEFINED__
typedef struct IGetRow IGetRow;
#endif

#ifndef __IBindResource_FWD_DEFINED__
#define __IBindResource_FWD_DEFINED__
typedef struct IBindResource IBindResource;
#endif

#ifndef __IScopedOperations_FWD_DEFINED__
#define __IScopedOperations_FWD_DEFINED__
typedef struct IScopedOperations IScopedOperations;
#endif

#ifndef __ICreateRow_FWD_DEFINED__
#define __ICreateRow_FWD_DEFINED__
typedef struct ICreateRow ICreateRow;
#endif

#ifndef __IDBBinderProperties_FWD_DEFINED__
#define __IDBBinderProperties_FWD_DEFINED__
typedef struct IDBBinderProperties IDBBinderProperties;
#endif

#ifndef __IColumnsInfo2_FWD_DEFINED__
#define __IColumnsInfo2_FWD_DEFINED__
typedef struct IColumnsInfo2 IColumnsInfo2;
#endif

#ifndef __IRegisterProvider_FWD_DEFINED__
#define __IRegisterProvider_FWD_DEFINED__
typedef struct IRegisterProvider IRegisterProvider;
#endif

#ifndef __IGetSession_FWD_DEFINED__
#define __IGetSession_FWD_DEFINED__
typedef struct IGetSession IGetSession;
#endif

#ifndef __IGetSourceRow_FWD_DEFINED__
#define __IGetSourceRow_FWD_DEFINED__
typedef struct IGetSourceRow IGetSourceRow;
#endif

#ifndef __IRowsetCurrentIndex_FWD_DEFINED__
#define __IRowsetCurrentIndex_FWD_DEFINED__
typedef struct IRowsetCurrentIndex IRowsetCurrentIndex;
#endif

#ifndef __ICommandStream_FWD_DEFINED__
#define __ICommandStream_FWD_DEFINED__
typedef struct ICommandStream ICommandStream;
#endif

#ifndef __IRowsetBookmark_FWD_DEFINED__
#define __IRowsetBookmark_FWD_DEFINED__
typedef struct IRowsetBookmark IRowsetBookmark;
#endif

#include "wtypes.h"
#include "oaidl.h"
#include "ocidl.h"
#include "propidl.h"
#include "transact.h"

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

#ifndef OLEDBVER
#define OLEDBVER 0x0270
#endif

#ifdef _WIN64
  typedef ULONGLONG DBLENGTH;
  typedef LONGLONG DBROWOFFSET;
  typedef LONGLONG DBROWCOUNT;
  typedef ULONGLONG DBCOUNTITEM;
  typedef ULONGLONG DBORDINAL;
  typedef LONGLONG DB_LORDINAL;
  typedef ULONGLONG DBBKMARK;
  typedef ULONGLONG DBBYTEOFFSET;
  typedef ULONG DBREFCOUNT;
  typedef ULONGLONG DB_UPARAMS;
  typedef LONGLONG DB_LPARAMS;
  typedef DWORDLONG DBHASHVALUE;
  typedef DWORDLONG DB_DWRESERVE;
  typedef LONGLONG DB_LRESERVE;
  typedef ULONGLONG DB_URESERVE;
#else
  typedef ULONG DBLENGTH;
  typedef LONG DBROWOFFSET;
  typedef LONG DBROWCOUNT;
  typedef ULONG DBCOUNTITEM;
  typedef ULONG DBORDINAL;
  typedef LONG DB_LORDINAL;
  typedef ULONG DBBKMARK;
  typedef ULONG DBBYTEOFFSET;
  typedef ULONG DBREFCOUNT;
  typedef ULONG DB_UPARAMS;
  typedef LONG DB_LPARAMS;
  typedef DWORD DBHASHVALUE;
  typedef DWORD DB_DWRESERVE;
  typedef LONG DB_LRESERVE;
  typedef ULONG DB_URESERVE;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0000_v0_0_s_ifspec;

#ifndef __DBStructureDefinitions_INTERFACE_DEFINED__
#define __DBStructureDefinitions_INTERFACE_DEFINED__
#undef OLEDBDECLSPEC
#define OLEDBDECLSPEC __declspec(selectany)
  typedef DWORD DBKIND;

  enum DBKINDENUM {
    DBKIND_GUID_NAME = 0,DBKIND_GUID_PROPID,DBKIND_NAME,DBKIND_PGUID_NAME,
    DBKIND_PGUID_PROPID,DBKIND_PROPID,DBKIND_GUID
  };

  typedef struct tagDBID {
    union {
      GUID guid;
      GUID *pguid;
    } uGuid;
    DBKIND eKind;
    union {
      LPOLESTR pwszName;
      ULONG ulPropid;
    } uName;
  } DBID;

  typedef struct tagDB_NUMERIC {
    BYTE precision;
    BYTE scale;
    BYTE sign;
    BYTE val[16 ];
  } DB_NUMERIC;

#ifndef _ULONGLONG_
  typedef hyper LONGLONG;
  typedef MIDL_uhyper ULONGLONG;
  typedef LONGLONG *PLONGLONG;
  typedef ULONGLONG *PULONGLONG;
#endif

#ifndef DECIMAL_NEG
#ifndef DECIMAL_SETZERO
  typedef struct tagDEC {
    USHORT wReserved;
    __C89_NAMELESS union {
      __C89_NAMELESS struct {
	BYTE scale;
	BYTE sign;
      };
      USHORT signscale;
    };
    ULONG Hi32;
    __C89_NAMELESS union {
      __C89_NAMELESS struct {
	ULONG Lo32;
	ULONG Mid32;
      };
      ULONGLONG Lo64;
    };
  } DECIMAL;

#define DECIMAL_NEG ((BYTE)0x80)
#define DECIMAL_SETZERO(dec) {(dec).Lo64 = 0; (dec).Hi32 = 0; (dec).signscale = 0;}
#endif
#endif

  typedef struct tagDBVECTOR {
    DBLENGTH size;
    void *ptr;
  } DBVECTOR;

  typedef struct tagDBDATE {
    SHORT year;
    USHORT month;
    USHORT day;
  } DBDATE;

  typedef struct tagDBTIME {
    USHORT hour;
    USHORT minute;
    USHORT second;
  } DBTIME;

  typedef struct tagDBTIMESTAMP {
    SHORT year;
    USHORT month;
    USHORT day;
    USHORT hour;
    USHORT minute;
    USHORT second;
    ULONG fraction;
  } DBTIMESTAMP;

#if (OLEDBVER >= 0x0200)
#if !defined(_WINBASE_) && !defined(_FILETIME_)
#define _FILETIME_
  typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
  } FILETIME;
#endif
  typedef signed char SBYTE;

  typedef struct tagDB_VARNUMERIC {
    BYTE precision;
    SBYTE scale;
    BYTE sign;
    BYTE val[1 ];
  } DB_VARNUMERIC;
#endif

#if (OLEDBVER >= 0x0210)
  typedef struct _SEC_OBJECT_ELEMENT {
    GUID guidObjectType;
    DBID ObjectID;
  } SEC_OBJECT_ELEMENT;

  typedef struct _SEC_OBJECT {
    DWORD cObjects;
    SEC_OBJECT_ELEMENT *prgObjects;
  } SEC_OBJECT;

  typedef struct tagDBIMPLICITSESSION {
    IUnknown *pUnkOuter;
    IID *piid;
    IUnknown *pSession;
  } DBIMPLICITSESSION;
#endif

  typedef WORD DBTYPE;

  enum DBTYPEENUM {
    DBTYPE_EMPTY = 0,DBTYPE_NULL = 1,DBTYPE_I2 = 2,DBTYPE_I4 = 3,DBTYPE_R4 = 4,DBTYPE_R8 = 5,DBTYPE_CY = 6,DBTYPE_DATE = 7,
    DBTYPE_BSTR = 8,DBTYPE_IDISPATCH = 9,DBTYPE_ERROR = 10,DBTYPE_BOOL = 11,DBTYPE_VARIANT = 12,DBTYPE_IUNKNOWN = 13,DBTYPE_DECIMAL = 14,
    DBTYPE_UI1 = 17,DBTYPE_ARRAY = 0x2000,DBTYPE_BYREF = 0x4000,DBTYPE_I1 = 16,DBTYPE_UI2 = 18,DBTYPE_UI4 = 19,DBTYPE_I8 = 20,DBTYPE_UI8 = 21,
    DBTYPE_GUID = 72,DBTYPE_VECTOR = 0x1000,DBTYPE_RESERVED = 0x8000,DBTYPE_BYTES = 128,DBTYPE_STR = 129,DBTYPE_WSTR = 130,DBTYPE_NUMERIC = 131,
    DBTYPE_UDT = 132,DBTYPE_DBDATE = 133,DBTYPE_DBTIME = 134,DBTYPE_DBTIMESTAMP = 135
  };

#ifdef _WIN64
#define DBTYPEFOR_DBLENGTH DBTYPE_UI8
#define DBTYPEFOR_DBROWCOUNT DBTYPE_I8
#define DBTYPEFOR_DBORDINAL DBTYPE_UI8
#else
#define DBTYPEFOR_DBLENGTH DBTYPE_UI4
#define DBTYPEFOR_DBROWCOUNT DBTYPE_I4
#define DBTYPEFOR_DBORDINAL DBTYPE_UI4
#endif

#if (OLEDBVER >= 0x0150)
  enum DBTYPEENUM15 {
    DBTYPE_HCHAPTER = 136
  };
#endif

#if (OLEDBVER >= 0x0200)
  enum DBTYPEENUM20 {
    DBTYPE_FILETIME = 64,DBTYPE_PROPVARIANT = 138,DBTYPE_VARNUMERIC = 139
  };
#endif

  typedef DWORD DBPART;

  enum DBPARTENUM {
    DBPART_INVALID = 0,DBPART_VALUE = 0x1,DBPART_LENGTH = 0x2,DBPART_STATUS = 0x4
  };
  typedef DWORD DBPARAMIO;

  enum DBPARAMIOENUM {
    DBPARAMIO_NOTPARAM = 0,DBPARAMIO_INPUT = 0x1,DBPARAMIO_OUTPUT = 0x2
  };

#if (OLEDBVER >= 0x0150)
  typedef DWORD DBBINDFLAG;

  enum DBBINDFLAGENUM {
    DBBINDFLAG_HTML = 0x1
  };
#endif

  typedef DWORD DBMEMOWNER;

  enum DBMEMOWNERENUM {
    DBMEMOWNER_CLIENTOWNED = 0,DBMEMOWNER_PROVIDEROWNED = 0x1
  };

  typedef struct tagDBOBJECT {
    DWORD dwFlags;
    IID iid;
  } DBOBJECT;

  typedef DWORD DBSTATUS;

  enum DBSTATUSENUM {
    DBSTATUS_S_OK = 0,DBSTATUS_E_BADACCESSOR = 1,DBSTATUS_E_CANTCONVERTVALUE = 2,DBSTATUS_S_ISNULL = 3,DBSTATUS_S_TRUNCATED = 4,
    DBSTATUS_E_SIGNMISMATCH = 5,DBSTATUS_E_DATAOVERFLOW = 6,DBSTATUS_E_CANTCREATE = 7,DBSTATUS_E_UNAVAILABLE = 8,DBSTATUS_E_PERMISSIONDENIED = 9,
    DBSTATUS_E_INTEGRITYVIOLATION = 10,DBSTATUS_E_SCHEMAVIOLATION = 11,DBSTATUS_E_BADSTATUS = 12,DBSTATUS_S_DEFAULT = 13
  };

#if (OLEDBVER >= 0x0200)
  enum DBSTATUSENUM20 {
    MDSTATUS_S_CELLEMPTY = 14,DBSTATUS_S_IGNORE = 15
  };
#endif

#if (OLEDBVER >= 0x0210)
  enum DBSTATUSENUM21 {
    DBSTATUS_E_DOESNOTEXIST = 16,DBSTATUS_E_INVALIDURL = 17,DBSTATUS_E_RESOURCELOCKED = 18,DBSTATUS_E_RESOURCEEXISTS = 19,
    DBSTATUS_E_CANNOTCOMPLETE = 20,DBSTATUS_E_VOLUMENOTFOUND = 21,DBSTATUS_E_OUTOFSPACE = 22,DBSTATUS_S_CANNOTDELETESOURCE = 23,
    DBSTATUS_E_READONLY = 24,DBSTATUS_E_RESOURCEOUTOFSCOPE = 25,DBSTATUS_S_ALREADYEXISTS = 26
  };
  typedef DWORD DBBINDURLFLAG;

  enum DBBINDURLFLAGENUM {
    DBBINDURLFLAG_READ = 0x1,DBBINDURLFLAG_WRITE = 0x2,DBBINDURLFLAG_READWRITE = 0x3,DBBINDURLFLAG_SHARE_DENY_READ = 0x4,
    DBBINDURLFLAG_SHARE_DENY_WRITE = 0x8,DBBINDURLFLAG_SHARE_EXCLUSIVE = 0xc,DBBINDURLFLAG_SHARE_DENY_NONE = 0x10,
    DBBINDURLFLAG_ASYNCHRONOUS = 0x1000,DBBINDURLFLAG_COLLECTION = 0x2000,DBBINDURLFLAG_DELAYFETCHSTREAM = 0x4000,
    DBBINDURLFLAG_DELAYFETCHCOLUMNS = 0x8000,DBBINDURLFLAG_RECURSIVE = 0x400000,DBBINDURLFLAG_OUTPUT = 0x800000,
    DBBINDURLFLAG_WAITFORINIT = 0x1000000,DBBINDURLFLAG_OPENIFEXISTS = 0x2000000,DBBINDURLFLAG_OVERWRITE = 0x4000000,
    DBBINDURLFLAG_ISSTRUCTUREDDOCUMENT = 0x8000000
  };
  typedef DWORD DBBINDURLSTATUS;

  enum DBBINDURLSTATUSENUM {
    DBBINDURLSTATUS_S_OK = 0,DBBINDURLSTATUS_S_DENYNOTSUPPORTED = 0x1,DBBINDURLSTATUS_S_DENYTYPENOTSUPPORTED = 0x4,
    DBBINDURLSTATUS_S_REDIRECTED = 0x8
  };
#endif

#if (OLEDBVER >= 0x0250)
  enum DBSTATUSENUM25 {
    DBSTATUS_E_CANCELED = 27,DBSTATUS_E_NOTCOLLECTION = 28
  };
#endif

  typedef struct tagDBBINDEXT {
    BYTE *pExtension;
    DBCOUNTITEM ulExtension;
  } DBBINDEXT;

  typedef struct tagDBBINDING {
    DBORDINAL iOrdinal;
    DBBYTEOFFSET obValue;
    DBBYTEOFFSET obLength;
    DBBYTEOFFSET obStatus;
    ITypeInfo *pTypeInfo;
    DBOBJECT *pObject;
    DBBINDEXT *pBindExt;
    DBPART dwPart;
    DBMEMOWNER dwMemOwner;
    DBPARAMIO eParamIO;
    DBLENGTH cbMaxLen;
    DWORD dwFlags;
    DBTYPE wType;
    BYTE bPrecision;
    BYTE bScale;
  } DBBINDING;

  typedef DWORD DBROWSTATUS;

  enum DBROWSTATUSENUM {
    DBROWSTATUS_S_OK = 0,DBROWSTATUS_S_MULTIPLECHANGES = 2,DBROWSTATUS_S_PENDINGCHANGES = 3,DBROWSTATUS_E_CANCELED = 4,DBROWSTATUS_E_CANTRELEASE = 6,
    DBROWSTATUS_E_CONCURRENCYVIOLATION = 7,DBROWSTATUS_E_DELETED = 8,DBROWSTATUS_E_PENDINGINSERT = 9,DBROWSTATUS_E_NEWLYINSERTED = 10,
    DBROWSTATUS_E_INTEGRITYVIOLATION = 11,DBROWSTATUS_E_INVALID = 12,DBROWSTATUS_E_MAXPENDCHANGESEXCEEDED = 13,DBROWSTATUS_E_OBJECTOPEN = 14,
    DBROWSTATUS_E_OUTOFMEMORY = 15,DBROWSTATUS_E_PERMISSIONDENIED = 16,DBROWSTATUS_E_LIMITREACHED = 17,DBROWSTATUS_E_SCHEMAVIOLATION = 18,
    DBROWSTATUS_E_FAIL = 19
  };

#if (OLEDBVER >= 0x0200)
  enum DBROWSTATUSENUM20 {
    DBROWSTATUS_S_NOCHANGE = 20
  };
#endif

#if (OLEDBVER >= 0x0260)
  enum DBSTATUSENUM26 {
    DBSTATUS_S_ROWSETCOLUMN = 29
  };
#endif

  typedef ULONG_PTR HACCESSOR;

#define DB_NULL_HACCESSOR 0x00
#define DB_INVALID_HACCESSOR 0x00
  typedef ULONG_PTR HROW;

#define DB_NULL_HROW 0x00
  typedef ULONG_PTR HWATCHREGION;

#define DBWATCHREGION_NULL NULL
  typedef ULONG_PTR HCHAPTER;

#define DB_NULL_HCHAPTER 0x00
#define DB_INVALID_HCHAPTER 0x00
  typedef struct tagDBFAILUREINFO {
    HROW hRow;
    DBORDINAL iColumn;
    HRESULT failure;
  } DBFAILUREINFO;

  typedef DWORD DBCOLUMNFLAGS;

  enum DBCOLUMNFLAGSENUM {
    DBCOLUMNFLAGS_ISBOOKMARK = 0x1,DBCOLUMNFLAGS_MAYDEFER = 0x2,DBCOLUMNFLAGS_WRITE = 0x4,DBCOLUMNFLAGS_WRITEUNKNOWN = 0x8,
    DBCOLUMNFLAGS_ISFIXEDLENGTH = 0x10,DBCOLUMNFLAGS_ISNULLABLE = 0x20,DBCOLUMNFLAGS_MAYBENULL = 0x40,DBCOLUMNFLAGS_ISLONG = 0x80,
    DBCOLUMNFLAGS_ISROWID = 0x100,DBCOLUMNFLAGS_ISROWVER = 0x200,DBCOLUMNFLAGS_CACHEDEFERRED = 0x1000
  };

#if (OLEDBVER >= 0x0200)
  enum DBCOLUMNFLAGSENUM20 {
    DBCOLUMNFLAGS_SCALEISNEGATIVE = 0x4000,DBCOLUMNFLAGS_RESERVED = 0x8000
  };
#endif

#ifdef deprecated
#if (OLEDBVER >= 0x0200)
  enum DBCOLUMNFLAGSDEPRECATED {
    DBCOLUMNFLAGS_KEYCOLUMN = 0x8000
  };
#endif
#endif

#if (OLEDBVER >= 0x0150)
  enum DBCOLUMNFLAGS15ENUM {
    DBCOLUMNFLAGS_ISCHAPTER = 0x2000
  };
#endif

#if (OLEDBVER >= 0x0210)
  enum DBCOLUMNFLAGSENUM21 {
    DBCOLUMNFLAGS_ISROWURL = 0x10000,DBCOLUMNFLAGS_ISDEFAULTSTREAM = 0x20000,DBCOLUMNFLAGS_ISCOLLECTION = 0x40000
  };
#endif

#if (OLEDBVER >= 0x0260)
  enum DBCOLUMNFLAGSENUM26 {
    DBCOLUMNFLAGS_ISSTREAM = 0x80000,DBCOLUMNFLAGS_ISROWSET = 0x100000,DBCOLUMNFLAGS_ISROW = 0x200000,DBCOLUMNFLAGS_ROWSPECIFICCOLUMN = 0x400000
  };

  enum DBTABLESTATISTICSTYPE26 {
    DBSTAT_HISTOGRAM = 0x1,DBSTAT_COLUMN_CARDINALITY = 0x2,DBSTAT_TUPLE_CARDINALITY = 0x4
  };
#endif

  typedef struct tagDBCOLUMNINFO {
    LPOLESTR pwszName;
    ITypeInfo *pTypeInfo;
    DBORDINAL iOrdinal;
    DBCOLUMNFLAGS dwFlags;
    DBLENGTH ulColumnSize;
    DBTYPE wType;
    BYTE bPrecision;
    BYTE bScale;
    DBID columnid;
  } DBCOLUMNINFO;

  typedef enum tagDBBOOKMARK {
    DBBMK_INVALID = 0,DBBMK_FIRST,DBBMK_LAST
  } DBBOOKMARK;

#define STD_BOOKMARKLENGTH 1
#ifdef __cplusplus
  static inline WINBOOL IsEqualGUIDBase(const GUID &rguid1,const GUID &rguid2) { return !memcmp(&(rguid1.Data2),&(rguid2.Data2),sizeof(GUID) - sizeof(rguid1.Data1)); }
#else
#define IsEqualGuidBase(rguid1,rguid2) (!memcmp(&((rguid1).Data2),&((rguid2).Data2),sizeof(GUID) - sizeof((rguid1).Data1)))
#endif
#ifdef _WIN64
#define DB_INVALIDCOLUMN _UI64_MAX
#else
#define DB_INVALIDCOLUMN ULONG_MAX
#endif
#define DBCIDGUID {0x0C733A81,0x2A1C,0x11CE,{0xAD,0xE5,0x00,0xAA,0x00,0x44,0x77,0x3D}}
#define DB_NULLGUID {0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}}
#ifdef DBINITCONSTANTS
  extern const OLEDBDECLSPEC DBID DB_NULLID = {DB_NULLGUID,0,(LPOLESTR)0};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_IDNAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)2};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_NAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)3};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_NUMBER = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)4};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_TYPE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)5};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_PRECISION = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)7};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_SCALE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)8};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_FLAGS = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)9};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_BASECOLUMNNAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)10};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_BASETABLENAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)11};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_COLLATINGSEQUENCE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)12};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_COMPUTEMODE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)13};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_DEFAULTVALUE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)14};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_DOMAINNAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)15};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_HASDEFAULT = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)16};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_ISAUTOINCREMENT = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)17};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_ISCASESENSITIVE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)18};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_ISSEARCHABLE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)20};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_ISUNIQUE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)21};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_BASECATALOGNAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)23};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_BASESCHEMANAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)24};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_GUID = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)29};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_PROPID = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)30};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_TYPEINFO = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)31};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_DOMAINCATALOG = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)32};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_DOMAINSCHEMA = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)33};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_DATETIMEPRECISION = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)34};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_NUMERICPRECISIONRADIX = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)35};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_OCTETLENGTH = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)36};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_COLUMNSIZE = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)37};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_CLSID = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)38};

#if (OLEDBVER >= 0x0150)
  extern const OLEDBDECLSPEC DBID DBCOLUMN_MAYSORT = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)39};
#endif
#else
  extern const DBID DB_NULLID;
  extern const DBID DBCOLUMN_IDNAME;
  extern const DBID DBCOLUMN_NAME;
  extern const DBID DBCOLUMN_NUMBER;
  extern const DBID DBCOLUMN_TYPE;
  extern const DBID DBCOLUMN_PRECISION;
  extern const DBID DBCOLUMN_SCALE;
  extern const DBID DBCOLUMN_FLAGS;
  extern const DBID DBCOLUMN_BASECOLUMNNAME;
  extern const DBID DBCOLUMN_BASETABLENAME;
  extern const DBID DBCOLUMN_COLLATINGSEQUENCE;
  extern const DBID DBCOLUMN_COMPUTEMODE;
  extern const DBID DBCOLUMN_DEFAULTVALUE;
  extern const DBID DBCOLUMN_DOMAINNAME;
  extern const DBID DBCOLUMN_HASDEFAULT;
  extern const DBID DBCOLUMN_ISAUTOINCREMENT;
  extern const DBID DBCOLUMN_ISCASESENSITIVE;
  extern const DBID DBCOLUMN_ISSEARCHABLE;
  extern const DBID DBCOLUMN_ISUNIQUE;
  extern const DBID DBCOLUMN_BASECATALOGNAME;
  extern const DBID DBCOLUMN_BASESCHEMANAME;
  extern const DBID DBCOLUMN_GUID;
  extern const DBID DBCOLUMN_PROPID;
  extern const DBID DBCOLUMN_TYPEINFO;
  extern const DBID DBCOLUMN_DOMAINCATALOG;
  extern const DBID DBCOLUMN_DOMAINSCHEMA;
  extern const DBID DBCOLUMN_DATETIMEPRECISION;
  extern const DBID DBCOLUMN_NUMERICPRECISIONRADIX;
  extern const DBID DBCOLUMN_OCTETLENGTH;
  extern const DBID DBCOLUMN_COLUMNSIZE;
  extern const DBID DBCOLUMN_CLSID;

#if (OLEDBVER >= 0x0150)
  extern const DBID DBCOLUMN_MAYSORT;
#endif
#endif
#ifdef DBINITCONSTANTS

#if (OLEDBVER >= 0x0260)
  extern const OLEDBDECLSPEC GUID MDSCHEMA_FUNCTIONS = {0xa07ccd07,0x8148,0x11d0,{0x87,0xbb,0x00,0xc0,0x4f,0xc3,0x39,0x42}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_ACTIONS = {0xa07ccd08,0x8148,0x11d0,{0x87,0xbb,0x00,0xc0,0x4f,0xc3,0x39,0x42}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_COMMANDS = {0xa07ccd09,0x8148,0x11d0,{0x87,0xbb,0x00,0xc0,0x4f,0xc3,0x39,0x42}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_SETS = {0xa07ccd0b,0x8148,0x11d0,{0x87,0xbb,0x00,0xc0,0x4f,0xc3,0x39,0x42}};
#endif

#if (OLEDBVER >= 0x0200)
  extern const OLEDBDECLSPEC GUID DBSCHEMA_TABLES_INFO = {0xc8b522e0,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID MDGUID_MDX = {0xa07cccd0,0x8148,0x11d0,{0x87,0xbb,0x00,0xc0,0x4f,0xc3,0x39,0x42}};
  extern const OLEDBDECLSPEC GUID DBGUID_MDX = {0xa07cccd0,0x8148,0x11d0,{0x87,0xbb,0x00,0xc0,0x4f,0xc3,0x39,0x42}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_CUBES = {0xc8b522d8,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_DIMENSIONS = {0xc8b522d9,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_HIERARCHIES = {0xc8b522da,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_LEVELS = {0xc8b522db,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_MEASURES = {0xc8b522dc,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_PROPERTIES = {0xc8b522dd,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID MDSCHEMA_MEMBERS = {0xc8b522de,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_BASETABLEVERSION = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)40};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_KEYCOLUMN = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)41};
#endif

#if (OLEDBVER >= 0x0210)
#define DBGUID_ROWURL {0x0C733AB6,0x2A1C,0x11CE,{0xAD,0xE5,0x00,0xAA,0x00,0x44,0x77,0x3D}}
#define DBGUID_ROWDEFAULTSTREAM {0x0C733AB7,0x2A1C,0x11CE,{0xAD,0xE5,0x00,0xAA,0x00,0x44,0x77,0x3D}}
  extern const OLEDBDECLSPEC GUID DBPROPSET_TRUSTEE = {0xc8b522e1,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_TABLE = {0xc8b522e2,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_COLUMN = {0xc8b522e4,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_DATABASE = {0xc8b522e5,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_PROCEDURE = {0xc8b522e6,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_VIEW = {0xc8b522e7,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_SCHEMA = {0xc8b522e8,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_DOMAIN = {0xc8b522e9,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_COLLATION = {0xc8b522ea,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_TRUSTEE = {0xc8b522eb,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_SCHEMAROWSET = {0xc8b522ec,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_CHARACTERSET = {0xc8b522ed,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBOBJECT_TRANSLATION = {0xc8b522ee,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_TRUSTEE = {0xc8b522ef,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_COLUMNALL = {0xc8b522f0,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_INDEXALL = {0xc8b522f1,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_TABLEALL = {0xc8b522f2,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_TRUSTEEALL = {0xc8b522f3,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_CONSTRAINTALL = {0xc8b522fa,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_DSO = {0xc8b522f4,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_SESSION = {0xc8b522f5,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_ROWSET = {0xc8b522f6,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_ROW = {0xc8b522f7,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_COMMAND = {0xc8b522f8,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_STREAM = {0xc8b522f9,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC DBID DBROWCOL_ROWURL = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)0};
  extern const OLEDBDECLSPEC DBID DBROWCOL_PARSENAME = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)2};
  extern const OLEDBDECLSPEC DBID DBROWCOL_PARENTNAME = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)3};
  extern const OLEDBDECLSPEC DBID DBROWCOL_ABSOLUTEPARSENAME = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)4};
  extern const OLEDBDECLSPEC DBID DBROWCOL_ISHIDDEN = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)5};
  extern const OLEDBDECLSPEC DBID DBROWCOL_ISREADONLY = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)6};
  extern const OLEDBDECLSPEC DBID DBROWCOL_CONTENTTYPE = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)7};
  extern const OLEDBDECLSPEC DBID DBROWCOL_CONTENTCLASS = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)8};
  extern const OLEDBDECLSPEC DBID DBROWCOL_CONTENTLANGUAGE = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)9};
  extern const OLEDBDECLSPEC DBID DBROWCOL_CREATIONTIME = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)10};
  extern const OLEDBDECLSPEC DBID DBROWCOL_LASTACCESSTIME = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)11};
  extern const OLEDBDECLSPEC DBID DBROWCOL_LASTWRITETIME = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)12};
  extern const OLEDBDECLSPEC DBID DBROWCOL_STREAMSIZE = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)13};
  extern const OLEDBDECLSPEC DBID DBROWCOL_ISCOLLECTION = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)14};
  extern const OLEDBDECLSPEC DBID DBROWCOL_ISSTRUCTUREDDOCUMENT = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)15};
  extern const OLEDBDECLSPEC DBID DBROWCOL_DEFAULTDOCUMENT = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)16};
  extern const OLEDBDECLSPEC DBID DBROWCOL_DISPLAYNAME = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)17};
  extern const OLEDBDECLSPEC DBID DBROWCOL_ISROOT = {DBGUID_ROWURL,DBKIND_GUID_PROPID,(LPOLESTR)18};
  extern const OLEDBDECLSPEC DBID DBROWCOL_DEFAULTSTREAM = {DBGUID_ROWDEFAULTSTREAM,DBKIND_GUID_PROPID,(LPOLESTR)0};
  extern const OLEDBDECLSPEC GUID DBGUID_CONTAINEROBJECT = {0xc8b522fb,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
#endif

  extern const OLEDBDECLSPEC GUID DBSCHEMA_ASSERTIONS = {0xc8b52210,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_CATALOGS = {0xc8b52211,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_CHARACTER_SETS = {0xc8b52212,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_COLLATIONS = {0xc8b52213,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_COLUMNS = {0xc8b52214,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_CHECK_CONSTRAINTS = {0xc8b52215,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_CONSTRAINT_COLUMN_USAGE = {0xc8b52216,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_CONSTRAINT_TABLE_USAGE = {0xc8b52217,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_KEY_COLUMN_USAGE = {0xc8b52218,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_REFERENTIAL_CONSTRAINTS = {0xc8b52219,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_TABLE_CONSTRAINTS = {0xc8b5221a,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_COLUMN_DOMAIN_USAGE = {0xc8b5221b,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_INDEXES = {0xc8b5221e,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_COLUMN_PRIVILEGES = {0xc8b52221,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_TABLE_PRIVILEGES = {0xc8b52222,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_USAGE_PRIVILEGES = {0xc8b52223,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_PROCEDURES = {0xc8b52224,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_SCHEMATA = {0xc8b52225,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_SQL_LANGUAGES = {0xc8b52226,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_STATISTICS = {0xc8b52227,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_TABLES = {0xc8b52229,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_TRANSLATIONS = {0xc8b5222a,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_PROVIDER_TYPES = {0xc8b5222c,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_VIEWS = {0xc8b5222d,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_VIEW_COLUMN_USAGE = {0xc8b5222e,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_VIEW_TABLE_USAGE = {0xc8b5222f,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_PROCEDURE_PARAMETERS = {0xc8b522b8,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_FOREIGN_KEYS = {0xc8b522c4,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_PRIMARY_KEYS = {0xc8b522c5,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_PROCEDURE_COLUMNS = {0xc8b522c9,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBCOL_SELFCOLUMNS = {0xc8b52231,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBCOL_SPECIALCOL = {0xc8b52232,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID PSGUID_QUERY = {0x49691c90,0x7e17,0x101a,{0xa9,0x1c,0x08,0x00,0x2b,0x2e,0xcd,0xa9}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_COLUMN = {0xc8b522b9,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_DATASOURCE = {0xc8b522ba,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_DATASOURCEINFO = {0xc8b522bb,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_DBINIT = {0xc8b522bc,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_INDEX = {0xc8b522bd,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_ROWSET = {0xc8b522be,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_TABLE = {0xc8b522bf,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_DATASOURCEALL = {0xc8b522c0,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_DATASOURCEINFOALL = {0xc8b522c1,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_ROWSETALL = {0xc8b522c2,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_SESSION = {0xc8b522c6,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_SESSIONALL = {0xc8b522c7,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_DBINITALL = {0xc8b522ca,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_PROPERTIESINERROR = {0xc8b522d4,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};

#if (OLEDBVER >= 0x0150)
  extern const OLEDBDECLSPEC GUID DBPROPSET_VIEW = {0xc8b522df,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
#endif

#if (OLEDBVER >= 0x0250)
  extern const OLEDBDECLSPEC GUID DBPROPSET_VIEWALL = {0xc8b522fc,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
#endif

#if (OLEDBVER >= 0x0260)
  extern const OLEDBDECLSPEC GUID DBPROPSET_STREAM = {0xc8b522fd,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBPROPSET_STREAMALL = {0xc8b522fe,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_TABLE_STATISTICS = {0xc8b522ff,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBSCHEMA_CHECK_CONSTRAINTS_BY_TABLE = {0xc8b52301,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_HISTOGRAM_ROWSET = {0xc8b52300,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC DBID DBCOLUMN_DERIVEDCOLUMNNAME = {DBCIDGUID,DBKIND_GUID_PROPID,(LPOLESTR)43};
#endif

  extern const OLEDBDECLSPEC GUID DBGUID_DBSQL = {0xc8b521fb,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_DEFAULT = {0xc8b521fb,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_SQL = {0xc8b522d7,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
#else

#if (OLEDBVER >= 0x0200)
  extern const GUID DBSCHEMA_TABLES_INFO;
  extern const GUID MDGUID_MDX;
  extern const GUID DBGUID_MDX;
  extern const GUID MDSCHEMA_CUBES;
  extern const GUID MDSCHEMA_DIMENSIONS;
  extern const GUID MDSCHEMA_HIERARCHIES;
  extern const GUID MDSCHEMA_LEVELS;
  extern const GUID MDSCHEMA_MEASURES;
  extern const GUID MDSCHEMA_PROPERTIES;
  extern const GUID MDSCHEMA_MEMBERS;
  extern const DBID DBCOLUMN_BASETABLEVERSION;
  extern const DBID DBCOLUMN_KEYCOLUMN;
#endif

#if (OLEDBVER >= 0x0210)
  extern const GUID DBPROPSET_TRUSTEE;
  extern const GUID DBOBJECT_TABLE;
  extern const GUID DBOBJECT_COLUMN;
  extern const GUID DBOBJECT_DATABASE;
  extern const GUID DBOBJECT_PROCEDURE;
  extern const GUID DBOBJECT_VIEW;
  extern const GUID DBOBJECT_SCHEMA;
  extern const GUID DBOBJECT_DOMAIN;
  extern const GUID DBOBJECT_COLLATION;
  extern const GUID DBOBJECT_TRUSTEE;
  extern const GUID DBOBJECT_SCHEMAROWSET;
  extern const GUID DBOBJECT_CHARACTERSET;
  extern const GUID DBOBJECT_TRANSLATION;
  extern const GUID DBSCHEMA_TRUSTEE;
  extern const GUID DBPROPSET_COLUMNALL;
  extern const GUID DBPROPSET_INDEXALL;
  extern const GUID DBPROPSET_TABLEALL;
  extern const GUID DBPROPSET_TRUSTEEALL;
  extern const GUID DBPROPSET_CONSTRAINTALL;
  extern const GUID DBGUID_DSO;
  extern const GUID DBGUID_SESSION;
  extern const GUID DBGUID_ROWSET;
  extern const GUID DBGUID_ROW;
  extern const GUID DBGUID_COMMAND;
  extern const GUID DBGUID_STREAM;
  extern const DBID DBROWCOL_ROWURL;
  extern const DBID DBROWCOL_PARSENAME;
  extern const DBID DBROWCOL_PARENTNAME;
  extern const DBID DBROWCOL_ABSOLUTEPARSENAME;
  extern const DBID DBROWCOL_ISHIDDEN;
  extern const DBID DBROWCOL_ISREADONLY;
  extern const DBID DBROWCOL_CONTENTTYPE;
  extern const DBID DBROWCOL_CONTENTCLASS;
  extern const DBID DBROWCOL_CONTENTLANGUAGE;
  extern const DBID DBROWCOL_CREATIONTIME;
  extern const DBID DBROWCOL_LASTACCESSTIME;
  extern const DBID DBROWCOL_LASTWRITETIME;
  extern const DBID DBROWCOL_STREAMSIZE;
  extern const DBID DBROWCOL_ISCOLLECTION;
  extern const DBID DBROWCOL_ISSTRUCTUREDDOCUMENT;
  extern const DBID DBROWCOL_DEFAULTDOCUMENT;
  extern const DBID DBROWCOL_DISPLAYNAME;
  extern const DBID DBROWCOL_ISROOT;
  extern const DBID DBROWCOL_DEFAULTSTREAM;
  extern const GUID DBGUID_CONTAINEROBJECT;
#endif

  extern const GUID DBSCHEMA_ASSERTIONS;
  extern const GUID DBSCHEMA_CATALOGS;
  extern const GUID DBSCHEMA_CHARACTER_SETS;
  extern const GUID DBSCHEMA_COLLATIONS;
  extern const GUID DBSCHEMA_COLUMNS;
  extern const GUID DBSCHEMA_CHECK_CONSTRAINTS;
  extern const GUID DBSCHEMA_CONSTRAINT_COLUMN_USAGE;
  extern const GUID DBSCHEMA_CONSTRAINT_TABLE_USAGE;
  extern const GUID DBSCHEMA_KEY_COLUMN_USAGE;
  extern const GUID DBSCHEMA_REFERENTIAL_CONSTRAINTS;
  extern const GUID DBSCHEMA_TABLE_CONSTRAINTS;
  extern const GUID DBSCHEMA_COLUMN_DOMAIN_USAGE;
  extern const GUID DBSCHEMA_INDEXES;
  extern const GUID DBSCHEMA_COLUMN_PRIVILEGES;
  extern const GUID DBSCHEMA_TABLE_PRIVILEGES;
  extern const GUID DBSCHEMA_USAGE_PRIVILEGES;
  extern const GUID DBSCHEMA_PROCEDURES;
  extern const GUID DBSCHEMA_SCHEMATA;
  extern const GUID DBSCHEMA_SQL_LANGUAGES;
  extern const GUID DBSCHEMA_STATISTICS;
  extern const GUID DBSCHEMA_TABLES;
  extern const GUID DBSCHEMA_TRANSLATIONS;
  extern const GUID DBSCHEMA_PROVIDER_TYPES;
  extern const GUID DBSCHEMA_VIEWS;
  extern const GUID DBSCHEMA_VIEW_COLUMN_USAGE;
  extern const GUID DBSCHEMA_VIEW_TABLE_USAGE;
  extern const GUID DBSCHEMA_PROCEDURE_PARAMETERS;
  extern const GUID DBSCHEMA_FOREIGN_KEYS;
  extern const GUID DBSCHEMA_PRIMARY_KEYS;
  extern const GUID DBSCHEMA_PROCEDURE_COLUMNS;
  extern const GUID DBCOL_SELFCOLUMNS;
  extern const GUID DBCOL_SPECIALCOL;
  extern const GUID PSGUID_QUERY;
  extern const GUID DBPROPSET_COLUMN;
  extern const GUID DBPROPSET_DATASOURCE;
  extern const GUID DBPROPSET_DATASOURCEINFO;
  extern const GUID DBPROPSET_DBINIT;
  extern const GUID DBPROPSET_INDEX;
  extern const GUID DBPROPSET_ROWSET;
  extern const GUID DBPROPSET_TABLE;
  extern const GUID DBPROPSET_DATASOURCEALL;
  extern const GUID DBPROPSET_DATASOURCEINFOALL;
  extern const GUID DBPROPSET_ROWSETALL;
  extern const GUID DBPROPSET_SESSION;
  extern const GUID DBPROPSET_SESSIONALL;
  extern const GUID DBPROPSET_DBINITALL;
  extern const GUID DBPROPSET_PROPERTIESINERROR;

#if (OLEDBVER >= 0x0150)
  extern const GUID DBPROPSET_VIEW;
#endif

#if (OLEDBVER >= 0x0250)
  extern const GUID DBPROPSET_VIEWALL;
#endif

#if (OLEDBVER >= 0x0260)
  extern const GUID DBPROPSET_STREAM;
  extern const GUID DBPROPSET_STREAMALL;
  extern const GUID DBSCHEMA_TABLE_STATISTICS;
  extern const GUID DBSCHEMA_CHECK_CONSTRAINTS_BY_TABLE;
  extern const GUID DBGUID_HISTOGRAM_ROWSET;
  extern const DBID DBCOLUMN_DERIVEDCOLUMNNAME;
  extern const GUID MDSCHEMA_FUNCTIONS;
  extern const GUID MDSCHEMA_ACTIONS;
  extern const GUID MDSCHEMA_COMMANDS;
  extern const GUID MDSCHEMA_SETS;
#endif

  extern const GUID DBGUID_DBSQL;
  extern const GUID DBGUID_DEFAULT;
  extern const GUID DBGUID_SQL;
#endif

  enum DBPROPENUM {
    DBPROP_ABORTPRESERVE = 0x2,DBPROP_ACTIVESESSIONS = 0x3,DBPROP_APPENDONLY = 0xbb,DBPROP_ASYNCTXNABORT = 0xa8,DBPROP_ASYNCTXNCOMMIT = 0x4,
    DBPROP_AUTH_CACHE_AUTHINFO = 0x5,DBPROP_AUTH_ENCRYPT_PASSWORD = 0x6,DBPROP_AUTH_INTEGRATED = 0x7,DBPROP_AUTH_MASK_PASSWORD = 0x8,
    DBPROP_AUTH_PASSWORD = 0x9,DBPROP_AUTH_PERSIST_ENCRYPTED = 0xa,DBPROP_AUTH_PERSIST_SENSITIVE_AUTHINFO = 0xb,DBPROP_AUTH_USERID = 0xc,
    DBPROP_BLOCKINGSTORAGEOBJECTS = 0xd,DBPROP_BOOKMARKS = 0xe,DBPROP_BOOKMARKSKIPPED = 0xf,DBPROP_BOOKMARKTYPE = 0x10,DBPROP_BYREFACCESSORS = 0x78,
    DBPROP_CACHEDEFERRED = 0x11,DBPROP_CANFETCHBACKWARDS = 0x12,DBPROP_CANHOLDROWS = 0x13,DBPROP_CANSCROLLBACKWARDS = 0x15,
    DBPROP_CATALOGLOCATION = 0x16,DBPROP_CATALOGTERM = 0x17,DBPROP_CATALOGUSAGE = 0x18,DBPROP_CHANGEINSERTEDROWS = 0xbc,
    DBPROP_COL_AUTOINCREMENT = 0x1a,DBPROP_COL_DEFAULT = 0x1b,DBPROP_COL_DESCRIPTION = 0x1c,DBPROP_COL_FIXEDLENGTH = 0xa7,
    DBPROP_COL_NULLABLE = 0x1d,DBPROP_COL_PRIMARYKEY = 0x1e,DBPROP_COL_UNIQUE = 0x1f,DBPROP_COLUMNDEFINITION = 0x20,DBPROP_COLUMNRESTRICT = 0x21,
    DBPROP_COMMANDTIMEOUT = 0x22,DBPROP_COMMITPRESERVE = 0x23,DBPROP_CONCATNULLBEHAVIOR = 0x24,DBPROP_CURRENTCATALOG = 0x25,
    DBPROP_DATASOURCENAME = 0x26,DBPROP_DATASOURCEREADONLY = 0x27,DBPROP_DBMSNAME = 0x28,DBPROP_DBMSVER = 0x29,DBPROP_DEFERRED = 0x2a,
    DBPROP_DELAYSTORAGEOBJECTS = 0x2b,DBPROP_DSOTHREADMODEL = 0xa9,DBPROP_GROUPBY = 0x2c,DBPROP_HETEROGENEOUSTABLES = 0x2d,DBPROP_IAccessor = 0x79,
    DBPROP_IColumnsInfo = 0x7a,DBPROP_IColumnsRowset = 0x7b,DBPROP_IConnectionPointContainer = 0x7c,DBPROP_IConvertType = 0xc2,
    DBPROP_IRowset = 0x7e,DBPROP_IRowsetChange = 0x7f,DBPROP_IRowsetIdentity = 0x80,DBPROP_IRowsetIndex = 0x9f,DBPROP_IRowsetInfo = 0x81,
    DBPROP_IRowsetLocate = 0x82,DBPROP_IRowsetResynch = 0x84,DBPROP_IRowsetScroll = 0x85,DBPROP_IRowsetUpdate = 0x86,
    DBPROP_ISupportErrorInfo = 0x87,DBPROP_ILockBytes = 0x88,DBPROP_ISequentialStream = 0x89,DBPROP_IStorage = 0x8a,DBPROP_IStream = 0x8b,
    DBPROP_IDENTIFIERCASE = 0x2e,DBPROP_IMMOBILEROWS = 0x2f,DBPROP_INDEX_AUTOUPDATE = 0x30,DBPROP_INDEX_CLUSTERED = 0x31,
    DBPROP_INDEX_FILLFACTOR = 0x32,DBPROP_INDEX_INITIALSIZE = 0x33,DBPROP_INDEX_NULLCOLLATION = 0x34,DBPROP_INDEX_NULLS = 0x35,
    DBPROP_INDEX_PRIMARYKEY = 0x36,DBPROP_INDEX_SORTBOOKMARKS = 0x37,DBPROP_INDEX_TEMPINDEX = 0xa3,DBPROP_INDEX_TYPE = 0x38,
    DBPROP_INDEX_UNIQUE = 0x39,DBPROP_INIT_DATASOURCE = 0x3b,DBPROP_INIT_HWND = 0x3c,DBPROP_INIT_IMPERSONATION_LEVEL = 0x3d,
    DBPROP_INIT_LCID = 0xba,DBPROP_INIT_LOCATION = 0x3e,DBPROP_INIT_MODE = 0x3f,DBPROP_INIT_PROMPT = 0x40,DBPROP_INIT_PROTECTION_LEVEL = 0x41,
    DBPROP_INIT_PROVIDERSTRING = 0xa0,DBPROP_INIT_TIMEOUT = 0x42,DBPROP_LITERALBOOKMARKS = 0x43,DBPROP_LITERALIDENTITY = 0x44,
    DBPROP_MAXINDEXSIZE = 0x46,DBPROP_MAXOPENROWS = 0x47,DBPROP_MAXPENDINGROWS = 0x48,DBPROP_MAXROWS = 0x49,DBPROP_MAXROWSIZE = 0x4a,
    DBPROP_MAXROWSIZEINCLUDESBLOB = 0x4b,DBPROP_MAXTABLESINSELECT = 0x4c,DBPROP_MAYWRITECOLUMN = 0x4d,DBPROP_MEMORYUSAGE = 0x4e,
    DBPROP_MULTIPLEPARAMSETS = 0xbf,DBPROP_MULTIPLERESULTS = 0xc4,DBPROP_MULTIPLESTORAGEOBJECTS = 0x50,DBPROP_MULTITABLEUPDATE = 0x51,
    DBPROP_NOTIFICATIONGRANULARITY = 0xc6,DBPROP_NOTIFICATIONPHASES = 0x52,DBPROP_NOTIFYCOLUMNSET = 0xab,DBPROP_NOTIFYROWDELETE = 0xad,
    DBPROP_NOTIFYROWFIRSTCHANGE = 0xae,DBPROP_NOTIFYROWINSERT = 0xaf,DBPROP_NOTIFYROWRESYNCH = 0xb1,DBPROP_NOTIFYROWSETCHANGED = 0xd3,
    DBPROP_NOTIFYROWSETRELEASE = 0xb2,DBPROP_NOTIFYROWSETFETCHPOSITIONCHANGE = 0xb3,DBPROP_NOTIFYROWUNDOCHANGE = 0xb4,
    DBPROP_NOTIFYROWUNDODELETE = 0xb5,DBPROP_NOTIFYROWUNDOINSERT = 0xb6,DBPROP_NOTIFYROWUPDATE = 0xb7,DBPROP_NULLCOLLATION = 0x53,
    DBPROP_OLEOBJECT = 0x54,DBPROP_ORDERBYCOLUMNSINSELECT = 0x55,DBPROP_ORDEREDBOOKMARKS = 0x56,DBPROP_OTHERINSERT = 0x57,
    DBPROP_OTHERUPDATEDELETE = 0x58,DBPROP_OUTPUTPARAMETERAVAILABILITY = 0xb8,DBPROP_OWNINSERT = 0x59,DBPROP_OWNUPDATEDELETE = 0x5a,
    DBPROP_PERSISTENTIDTYPE = 0xb9,DBPROP_PREPAREABORTBEHAVIOR = 0x5b,DBPROP_PREPARECOMMITBEHAVIOR = 0x5c,DBPROP_PROCEDURETERM = 0x5d,
    DBPROP_PROVIDERNAME = 0x60,DBPROP_PROVIDEROLEDBVER = 0x61,DBPROP_PROVIDERVER = 0x62,DBPROP_QUICKRESTART = 0x63,
    DBPROP_QUOTEDIDENTIFIERCASE = 0x64,DBPROP_REENTRANTEVENTS = 0x65,DBPROP_REMOVEDELETED = 0x66,DBPROP_REPORTMULTIPLECHANGES = 0x67,
    DBPROP_RETURNPENDINGINSERTS = 0xbd,DBPROP_ROWRESTRICT = 0x68,DBPROP_ROWSETCONVERSIONSONCOMMAND = 0xc0,DBPROP_ROWTHREADMODEL = 0x69,
    DBPROP_SCHEMATERM = 0x6a,DBPROP_SCHEMAUSAGE = 0x6b,DBPROP_SERVERCURSOR = 0x6c,DBPROP_SESS_AUTOCOMMITISOLEVELS = 0xbe,
    DBPROP_SQLSUPPORT = 0x6d,DBPROP_STRONGIDENTITY = 0x77,DBPROP_STRUCTUREDSTORAGE = 0x6f,DBPROP_SUBQUERIES = 0x70,DBPROP_SUPPORTEDTXNDDL = 0xa1,
    DBPROP_SUPPORTEDTXNISOLEVELS = 0x71,DBPROP_SUPPORTEDTXNISORETAIN = 0x72,DBPROP_TABLETERM = 0x73,DBPROP_TBL_TEMPTABLE = 0x8c,
    DBPROP_TRANSACTEDOBJECT = 0x74,DBPROP_UPDATABILITY = 0x75,DBPROP_USERNAME = 0x76
  };

#if (OLEDBVER >= 0x0150)
  enum DBPROPENUM15 {
    DBPROP_FILTERCOMPAREOPS = 0xd1,DBPROP_FINDCOMPAREOPS = 0xd2,DBPROP_IChapteredRowset = 0xca,DBPROP_IDBAsynchStatus = 0xcb,
    DBPROP_IRowsetFind = 0xcc,DBPROP_IRowsetView = 0xd4,DBPROP_IViewChapter = 0xd5,DBPROP_IViewFilter = 0xd6,DBPROP_IViewRowset = 0xd7,
    DBPROP_IViewSort = 0xd8,DBPROP_INIT_ASYNCH = 0xc8,DBPROP_MAXOPENCHAPTERS = 0xc7,DBPROP_MAXORSINFILTER = 0xcd,DBPROP_MAXSORTCOLUMNS = 0xce,
    DBPROP_ROWSET_ASYNCH = 0xc9,DBPROP_SORTONINDEX = 0xcf
  };
#endif

#if (OLEDBVER >= 0x0200)
#define DBPROP_PROVIDERFILENAME DBPROP_PROVIDERNAME
#define DBPROP_SERVER_NAME DBPROP_SERVERNAME

  enum DBPROPENUM20 {
    DBPROP_IMultipleResults = 0xd9,DBPROP_DATASOURCE_TYPE = 0xfb,MDPROP_AXES = 0xfc,MDPROP_FLATTENING_SUPPORT = 0xfd,MDPROP_MDX_JOINCUBES = 0xfe,
    MDPROP_NAMED_LEVELS = 0xff,MDPROP_RANGEROWSET = 0x100,MDPROP_MDX_SLICER = 0xda,MDPROP_MDX_CUBEQUALIFICATION = 0xdb,
    MDPROP_MDX_OUTERREFERENCE = 0xdc,MDPROP_MDX_QUERYBYPROPERTY = 0xdd,MDPROP_MDX_CASESUPPORT = 0xde,MDPROP_MDX_STRING_COMPOP = 0xe0,
    MDPROP_MDX_DESCFLAGS = 0xe1,MDPROP_MDX_SET_FUNCTIONS = 0xe2,MDPROP_MDX_MEMBER_FUNCTIONS = 0xe3,MDPROP_MDX_NUMERIC_FUNCTIONS = 0xe4,
    MDPROP_MDX_FORMULAS = 0xe5,MDPROP_AGGREGATECELL_UPDATE = 0xe6,MDPROP_MDX_AGGREGATECELL_UPDATE = MDPROP_AGGREGATECELL_UPDATE,
    MDPROP_MDX_OBJQUALIFICATION = 0x105,MDPROP_MDX_NONMEASURE_EXPRESSIONS = 0x106,DBPROP_ACCESSORDER = 0xe7,DBPROP_BOOKMARKINFO = 0xe8,
    DBPROP_INIT_CATALOG = 0xe9,DBPROP_ROW_BULKOPS = 0xea,DBPROP_PROVIDERFRIENDLYNAME = 0xeb,DBPROP_LOCKMODE = 0xec,
    DBPROP_MULTIPLECONNECTIONS = 0xed,DBPROP_UNIQUEROWS = 0xee,DBPROP_SERVERDATAONINSERT = 0xef,DBPROP_STORAGEFLAGS = 0xf0,
    DBPROP_CONNECTIONSTATUS = 0xf4,DBPROP_ALTERCOLUMN = 0xf5,DBPROP_COLUMNLCID = 0xf6,DBPROP_RESETDATASOURCE = 0xf7,
    DBPROP_INIT_OLEDBSERVICES = 0xf8,DBPROP_IRowsetRefresh = 0xf9,DBPROP_SERVERNAME = 0xfa,DBPROP_IParentRowset = 0x101,
    DBPROP_HIDDENCOLUMNS = 0x102,DBPROP_PROVIDERMEMORY = 0x103,DBPROP_CLIENTCURSOR = 0x104
  };
#endif

#if (OLEDBVER >= 0x0210)
  enum DBPROPENUM21 {
    DBPROP_TRUSTEE_USERNAME = 0xf1,DBPROP_TRUSTEE_AUTHENTICATION = 0xf2,DBPROP_TRUSTEE_NEWAUTHENTICATION = 0xf3,DBPROP_IRow = 0x107,
    DBPROP_IRowChange = 0x108,DBPROP_IRowSchemaChange = 0x109,DBPROP_IGetRow = 0x10a,DBPROP_IScopedOperations = 0x10b,
    DBPROP_IBindResource = 0x10c,DBPROP_ICreateRow = 0x10d,DBPROP_INIT_BINDFLAGS = 0x10e,DBPROP_INIT_LOCKOWNER = 0x10f,
    DBPROP_GENERATEURL = 0x111,DBPROP_IDBBinderProperties = 0x112,DBPROP_IColumnsInfo2 = 0x113,DBPROP_IRegisterProvider = 0x114,
    DBPROP_IGetSession = 0x115,DBPROP_IGetSourceRow = 0x116,DBPROP_IRowsetCurrentIndex = 0x117,DBPROP_OPENROWSETSUPPORT = 0x118,
    DBPROP_COL_ISLONG = 0x119
  };
#endif

#if (OLEDBVER >= 0x0250)
  enum DBPROPENUM25 {
    DBPROP_COL_SEED = 0x11a,DBPROP_COL_INCREMENT = 0x11b,DBPROP_INIT_GENERALTIMEOUT = 0x11c,DBPROP_COMSERVICES = 0x11d
  };
#endif

#if (OLEDBVER >= 0x0260)
  enum DBPROPENUM26 {
    DBPROP_OUTPUTSTREAM = 0x11e,DBPROP_OUTPUTENCODING = 0x11f,DBPROP_TABLESTATISTICS = 0x120,DBPROP_SKIPROWCOUNTRESULTS = 0x123,
    DBPROP_IRowsetBookmark = 0x124,MDPROP_VISUALMODE = 0x125
  };
#endif

#ifdef deprecated
  enum DBPROPENUMDEPRECATED {
    DBPROP_IRowsetExactScroll = 0x9a,DBPROP_MARSHALLABLE = 0xc5,DBPROP_FILTEROPS = 0xd0
  }
#endif

#define DBPROPVAL_BMK_NUMERIC __MSABI_LONG(0x00000001)
#define DBPROPVAL_BMK_KEY __MSABI_LONG(0x00000002)
#define DBPROPVAL_CL_START __MSABI_LONG(0x00000001)
#define DBPROPVAL_CL_END __MSABI_LONG(0x00000002)
#define DBPROPVAL_CU_DML_STATEMENTS __MSABI_LONG(0x00000001)
#define DBPROPVAL_CU_TABLE_DEFINITION __MSABI_LONG(0x00000002)
#define DBPROPVAL_CU_INDEX_DEFINITION __MSABI_LONG(0x00000004)
#define DBPROPVAL_CU_PRIVILEGE_DEFINITION __MSABI_LONG(0x00000008)
#define DBPROPVAL_CD_NOTNULL __MSABI_LONG(0x00000001)
#define DBPROPVAL_CB_NULL __MSABI_LONG(0x00000001)
#define DBPROPVAL_CB_NON_NULL __MSABI_LONG(0x00000002)
#define DBPROPVAL_FU_NOT_SUPPORTED __MSABI_LONG(0x00000001)
#define DBPROPVAL_FU_COLUMN __MSABI_LONG(0x00000002)
#define DBPROPVAL_FU_TABLE __MSABI_LONG(0x00000004)
#define DBPROPVAL_FU_CATALOG __MSABI_LONG(0x00000008)
#define DBPROPVAL_GB_NOT_SUPPORTED __MSABI_LONG(0x00000001)
#define DBPROPVAL_GB_EQUALS_SELECT __MSABI_LONG(0x00000002)
#define DBPROPVAL_GB_CONTAINS_SELECT __MSABI_LONG(0x00000004)
#define DBPROPVAL_GB_NO_RELATION __MSABI_LONG(0x00000008)
#define DBPROPVAL_HT_DIFFERENT_CATALOGS __MSABI_LONG(0x00000001)
#define DBPROPVAL_HT_DIFFERENT_PROVIDERS __MSABI_LONG(0x00000002)
#define DBPROPVAL_IC_UPPER __MSABI_LONG(0x00000001)
#define DBPROPVAL_IC_LOWER __MSABI_LONG(0x00000002)
#define DBPROPVAL_IC_SENSITIVE __MSABI_LONG(0x00000004)
#define DBPROPVAL_IC_MIXED __MSABI_LONG(0x00000008)

#ifdef deprecated
#define DBPROPVAL_LM_NONE __MSABI_LONG(0x00000001)
#define DBPROPVAL_LM_READ __MSABI_LONG(0x00000002)
#define DBPROPVAL_LM_INTENT __MSABI_LONG(0x00000004)
#define DBPROPVAL_LM_RITE __MSABI_LONG(0x00000008)
#endif

#define DBPROPVAL_NP_OKTODO __MSABI_LONG(0x00000001)
#define DBPROPVAL_NP_ABOUTTODO __MSABI_LONG(0x00000002)
#define DBPROPVAL_NP_SYNCHAFTER __MSABI_LONG(0x00000004)
#define DBPROPVAL_NP_FAILEDTODO __MSABI_LONG(0x00000008)
#define DBPROPVAL_NP_DIDEVENT __MSABI_LONG(0x00000010)
#define DBPROPVAL_NC_END __MSABI_LONG(0x00000001)
#define DBPROPVAL_NC_HIGH __MSABI_LONG(0x00000002)
#define DBPROPVAL_NC_LOW __MSABI_LONG(0x00000004)
#define DBPROPVAL_NC_START __MSABI_LONG(0x00000008)
#define DBPROPVAL_OO_BLOB __MSABI_LONG(0x00000001)
#define DBPROPVAL_OO_IPERSIST __MSABI_LONG(0x00000002)
#define DBPROPVAL_CB_DELETE __MSABI_LONG(0x00000001)
#define DBPROPVAL_CB_PRESERVE __MSABI_LONG(0x00000002)
#define DBPROPVAL_SU_DML_STATEMENTS __MSABI_LONG(0x00000001)
#define DBPROPVAL_SU_TABLE_DEFINITION __MSABI_LONG(0x00000002)
#define DBPROPVAL_SU_INDEX_DEFINITION __MSABI_LONG(0x00000004)
#define DBPROPVAL_SU_PRIVILEGE_DEFINITION __MSABI_LONG(0x00000008)
#define DBPROPVAL_SQ_CORRELATEDSUBQUERIES __MSABI_LONG(0x00000001)
#define DBPROPVAL_SQ_COMPARISON __MSABI_LONG(0x00000002)
#define DBPROPVAL_SQ_EXISTS __MSABI_LONG(0x00000004)
#define DBPROPVAL_SQ_IN __MSABI_LONG(0x00000008)
#define DBPROPVAL_SQ_QUANTIFIED __MSABI_LONG(0x00000010)
#define DBPROPVAL_SQ_TABLE __MSABI_LONG(0x00000020)
#define DBPROPVAL_SS_ISEQUENTIALSTREAM __MSABI_LONG(0x00000001)
#define DBPROPVAL_SS_ISTREAM __MSABI_LONG(0x00000002)
#define DBPROPVAL_SS_ISTORAGE __MSABI_LONG(0x00000004)
#define DBPROPVAL_SS_ILOCKBYTES __MSABI_LONG(0x00000008)
#define DBPROPVAL_TI_CHAOS __MSABI_LONG(0x00000010)
#define DBPROPVAL_TI_READUNCOMMITTED __MSABI_LONG(0x00000100)
#define DBPROPVAL_TI_BROWSE __MSABI_LONG(0x00000100)
#define DBPROPVAL_TI_CURSORSTABILITY __MSABI_LONG(0x00001000)
#define DBPROPVAL_TI_READCOMMITTED __MSABI_LONG(0x00001000)
#define DBPROPVAL_TI_REPEATABLEREAD __MSABI_LONG(0x00010000)
#define DBPROPVAL_TI_SERIALIZABLE __MSABI_LONG(0x00100000)
#define DBPROPVAL_TI_ISOLATED __MSABI_LONG(0x00100000)
#define DBPROPVAL_TR_COMMIT_DC __MSABI_LONG(0x00000001)
#define DBPROPVAL_TR_COMMIT __MSABI_LONG(0x00000002)
#define DBPROPVAL_TR_COMMIT_NO __MSABI_LONG(0x00000004)
#define DBPROPVAL_TR_ABORT_DC __MSABI_LONG(0x00000008)
#define DBPROPVAL_TR_ABORT __MSABI_LONG(0x00000010)
#define DBPROPVAL_TR_ABORT_NO __MSABI_LONG(0x00000020)
#define DBPROPVAL_TR_DONTCARE __MSABI_LONG(0x00000040)
#define DBPROPVAL_TR_BOTH __MSABI_LONG(0x00000080)
#define DBPROPVAL_TR_NONE __MSABI_LONG(0x00000100)
#define DBPROPVAL_TR_OPTIMISTIC __MSABI_LONG(0x00000200)
#define DBPROPVAL_RT_FREETHREAD __MSABI_LONG(0x00000001)
#define DBPROPVAL_RT_APTMTTHREAD __MSABI_LONG(0x00000002)
#define DBPROPVAL_RT_SINGLETHREAD __MSABI_LONG(0x00000004)
#define DBPROPVAL_UP_CHANGE __MSABI_LONG(0x00000001)
#define DBPROPVAL_UP_DELETE __MSABI_LONG(0x00000002)
#define DBPROPVAL_UP_INSERT __MSABI_LONG(0x00000004)
#define DBPROPVAL_SQL_NONE __MSABI_LONG(0x00000000)
#define DBPROPVAL_SQL_ODBC_MINIMUM __MSABI_LONG(0x00000001)
#define DBPROPVAL_SQL_ODBC_CORE __MSABI_LONG(0x00000002)
#define DBPROPVAL_SQL_ODBC_EXTENDED __MSABI_LONG(0x00000004)
#define DBPROPVAL_SQL_ANSI89_IEF __MSABI_LONG(0x00000008)
#define DBPROPVAL_SQL_ANSI92_ENTRY __MSABI_LONG(0x00000010)
#define DBPROPVAL_SQL_FIPS_TRANSITIONAL __MSABI_LONG(0x00000020)
#define DBPROPVAL_SQL_ANSI92_INTERMEDIATE __MSABI_LONG(0x00000040)
#define DBPROPVAL_SQL_ANSI92_FULL __MSABI_LONG(0x00000080)
#define DBPROPVAL_SQL_ESCAPECLAUSES __MSABI_LONG(0x00000100)
#define DBPROPVAL_IT_BTREE __MSABI_LONG(0x00000001)
#define DBPROPVAL_IT_HASH __MSABI_LONG(0x00000002)
#define DBPROPVAL_IT_CONTENT __MSABI_LONG(0x00000003)
#define DBPROPVAL_IT_OTHER __MSABI_LONG(0x00000004)
#define DBPROPVAL_IN_DISALLOWNULL __MSABI_LONG(0x00000001)
#define DBPROPVAL_IN_IGNORENULL __MSABI_LONG(0x00000002)
#define DBPROPVAL_IN_IGNOREANYNULL __MSABI_LONG(0x00000004)
#define DBPROPVAL_TC_NONE __MSABI_LONG(0x00000000)
#define DBPROPVAL_TC_DML __MSABI_LONG(0x00000001)
#define DBPROPVAL_TC_DDL_COMMIT __MSABI_LONG(0x00000002)
#define DBPROPVAL_TC_DDL_IGNORE __MSABI_LONG(0x00000004)
#define DBPROPVAL_TC_ALL __MSABI_LONG(0x00000008)
#define DBPROPVAL_NP_OKTODO __MSABI_LONG(0x00000001)
#define DBPROPVAL_NP_ABOUTTODO __MSABI_LONG(0x00000002)
#define DBPROPVAL_NP_SYNCHAFTER __MSABI_LONG(0x00000004)
#define DBPROPVAL_OA_NOTSUPPORTED __MSABI_LONG(0x00000001)
#define DBPROPVAL_OA_ATEXECUTE __MSABI_LONG(0x00000002)
#define DBPROPVAL_OA_ATROWRELEASE __MSABI_LONG(0x00000004)
#define DBPROPVAL_MR_NOTSUPPORTED __MSABI_LONG(0x00000000)
#define DBPROPVAL_MR_SUPPORTED __MSABI_LONG(0x00000001)
#define DBPROPVAL_MR_CONCURRENT __MSABI_LONG(0x00000002)
#define DBPROPVAL_PT_GUID_NAME __MSABI_LONG(0x00000001)
#define DBPROPVAL_PT_GUID_PROPID __MSABI_LONG(0x00000002)
#define DBPROPVAL_PT_NAME __MSABI_LONG(0x00000004)
#define DBPROPVAL_PT_GUID __MSABI_LONG(0x00000008)
#define DBPROPVAL_PT_PROPID __MSABI_LONG(0x00000010)
#define DBPROPVAL_PT_PGUID_NAME __MSABI_LONG(0x00000020)
#define DBPROPVAL_PT_PGUID_PROPID __MSABI_LONG(0x00000040)
#define DBPROPVAL_NT_SINGLEROW __MSABI_LONG(0x00000001)
#define DBPROPVAL_NT_MULTIPLEROWS __MSABI_LONG(0x00000002)

#if (OLEDBVER >= 0x0150)
#define DBPROPVAL_ASYNCH_INITIALIZE __MSABI_LONG(0x00000001)
#define DBPROPVAL_ASYNCH_SEQUENTIALPOPULATION __MSABI_LONG(0x00000002)
#define DBPROPVAL_ASYNCH_RANDOMPOPULATION __MSABI_LONG(0x00000004)
#define DBPROPVAL_OP_EQUAL __MSABI_LONG(0x00000001)
#define DBPROPVAL_OP_RELATIVE __MSABI_LONG(0x00000002)
#define DBPROPVAL_OP_STRING __MSABI_LONG(0x00000004)
#define DBPROPVAL_CO_EQUALITY __MSABI_LONG(0x00000001)
#define DBPROPVAL_CO_STRING __MSABI_LONG(0x00000002)
#define DBPROPVAL_CO_CASESENSITIVE __MSABI_LONG(0x00000004)
#define DBPROPVAL_CO_CASEINSENSITIVE __MSABI_LONG(0x00000008)
#endif

#if (OLEDBVER >= 0x0200)
#define DBPROPVAL_CO_CONTAINS __MSABI_LONG(0x00000010)
#define DBPROPVAL_CO_BEGINSWITH __MSABI_LONG(0x00000020)
#define DBPROPVAL_ASYNCH_BACKGROUNDPOPULATION __MSABI_LONG(0x00000008)
#define DBPROPVAL_ASYNCH_PREPOPULATE __MSABI_LONG(0x00000010)
#define DBPROPVAL_ASYNCH_POPULATEONDEMAND __MSABI_LONG(0x00000020)
#define DBPROPVAL_LM_NONE __MSABI_LONG(0x00000001)
#define DBPROPVAL_LM_SINGLEROW __MSABI_LONG(0x00000002)
#define DBPROPVAL_SQL_SUBMINIMUM __MSABI_LONG(0x00000200)
#define DBPROPVAL_DST_TDP __MSABI_LONG(0x00000001)
#define DBPROPVAL_DST_MDP __MSABI_LONG(0x00000002)
#define DBPROPVAL_DST_TDPANDMDP __MSABI_LONG(0x00000003)
#define MDPROPVAL_AU_UNSUPPORTED __MSABI_LONG(0x00000000)
#define MDPROPVAL_AU_UNCHANGED __MSABI_LONG(0x00000001)
#define MDPROPVAL_AU_UNKNOWN __MSABI_LONG(0x00000002)
#define MDPROPVAL_MF_WITH_CALCMEMBERS __MSABI_LONG(0x00000001)
#define MDPROPVAL_MF_WITH_NAMEDSETS __MSABI_LONG(0x00000002)
#define MDPROPVAL_MF_CREATE_CALCMEMBERS __MSABI_LONG(0x00000004)
#define MDPROPVAL_MF_CREATE_NAMEDSETS __MSABI_LONG(0x00000008)
#define MDPROPVAL_MF_SCOPE_SESSION __MSABI_LONG(0x00000010)
#define MDPROPVAL_MF_SCOPE_GLOBAL __MSABI_LONG(0x00000020)
#define MDPROPVAL_MMF_COUSIN __MSABI_LONG(0x00000001)
#define MDPROPVAL_MMF_PARALLELPERIOD __MSABI_LONG(0x00000002)
#define MDPROPVAL_MMF_OPENINGPERIOD __MSABI_LONG(0x00000004)
#define MDPROPVAL_MMF_CLOSINGPERIOD __MSABI_LONG(0x00000008)
#define MDPROPVAL_MNF_MEDIAN __MSABI_LONG(0x00000001)
#define MDPROPVAL_MNF_VAR __MSABI_LONG(0x00000002)
#define MDPROPVAL_MNF_STDDEV __MSABI_LONG(0x00000004)
#define MDPROPVAL_MNF_RANK __MSABI_LONG(0x00000008)
#define MDPROPVAL_MNF_AGGREGATE __MSABI_LONG(0x00000010)
#define MDPROPVAL_MNF_COVARIANCE __MSABI_LONG(0x00000020)
#define MDPROPVAL_MNF_CORRELATION __MSABI_LONG(0x00000040)
#define MDPROPVAL_MNF_LINREGSLOPE __MSABI_LONG(0x00000080)
#define MDPROPVAL_MNF_LINREGVARIANCE __MSABI_LONG(0x00000100)
#define MDPROPVAL_MNF_LINREG2 __MSABI_LONG(0x00000200)
#define MDPROPVAL_MNF_LINREGPOINT __MSABI_LONG(0x00000400)
#define MDPROPVAL_MNF_DRILLDOWNLEVEL __MSABI_LONG(0x00000800)
#define MDPROPVAL_MNF_DRILLDOWNMEMBERTOP __MSABI_LONG(0x00001000)
#define MDPROPVAL_MNF_DRILLDOWNMEMBERBOTTOM __MSABI_LONG(0x00002000)
#define MDPROPVAL_MNF_DRILLDOWNLEVELTOP __MSABI_LONG(0x00004000)
#define MDPROPVAL_MNF_DRILLDOWNLEVELBOTTOM __MSABI_LONG(0x00008000)
#define MDPROPVAL_MNF_DRILLUPMEMBER __MSABI_LONG(0x00010000)
#define MDPROPVAL_MNF_DRILLUPLEVEL __MSABI_LONG(0x00020000)
#define MDPROPVAL_MMF_COUSIN __MSABI_LONG(0x00000001)
#define MDPROPVAL_MMF_PARALLELPERIOD __MSABI_LONG(0x00000002)
#define MDPROPVAL_MMF_OPENINGPERIOD __MSABI_LONG(0x00000004)
#define MDPROPVAL_MMF_CLOSINGPERIOD __MSABI_LONG(0x00000008)
#define MDPROPVAL_MSF_TOPPERCENT __MSABI_LONG(0x00000001)
#define MDPROPVAL_MSF_BOTTOMPERCENT __MSABI_LONG(0x00000002)
#define MDPROPVAL_MSF_TOPSUM __MSABI_LONG(0x00000004)
#define MDPROPVAL_MSF_BOTTOMSUM __MSABI_LONG(0x00000008)
#define MDPROPVAL_MSF_PERIODSTODATE __MSABI_LONG(0x00000010)
#define MDPROPVAL_MSF_LASTPERIODS __MSABI_LONG(0x00000020)
#define MDPROPVAL_MSF_YTD __MSABI_LONG(0x00000040)
#define MDPROPVAL_MSF_QTD __MSABI_LONG(0x00000080)
#define MDPROPVAL_MSF_MTD __MSABI_LONG(0x00000100)
#define MDPROPVAL_MSF_WTD __MSABI_LONG(0x00000200)
#define MDPROPVAL_MSF_DRILLDOWNMEMBBER __MSABI_LONG(0x00000400)
#define MDPROPVAL_MSF_DRILLDOWNLEVEL __MSABI_LONG(0x00000800)
#define MDPROPVAL_MSF_DRILLDOWNMEMBERTOP __MSABI_LONG(0x00001000)
#define MDPROPVAL_MSF_DRILLDOWNMEMBERBOTTOM __MSABI_LONG(0x00002000)
#define MDPROPVAL_MSF_DRILLDOWNLEVELTOP __MSABI_LONG(0x00004000)
#define MDPROPVAL_MSF_DRILLDOWNLEVELBOTTOM __MSABI_LONG(0x00008000)
#define MDPROPVAL_MSF_DRILLUPMEMBER __MSABI_LONG(0x00010000)
#define MDPROPVAL_MSF_DRILLUPLEVEL __MSABI_LONG(0x00020000)
#define MDPROPVAL_MSF_TOGGLEDRILLSTATE __MSABI_LONG(0x00040000)

#define MDPROPVAL_MD_SELF __MSABI_LONG(0x00000001)
#define MDPROPVAL_MD_BEFORE __MSABI_LONG(0x00000002)
#define MDPROPVAL_MD_AFTER __MSABI_LONG(0x00000004)

#define MDPROPVAL_MSC_LESSTHAN __MSABI_LONG(0x00000001)
#define MDPROPVAL_MSC_GREATERTHAN __MSABI_LONG(0x00000002)
#define MDPROPVAL_MSC_LESSTHANEQUAL __MSABI_LONG(0x00000004)
#define MDPROPVAL_MSC_GREATERTHANEQUAL __MSABI_LONG(0x00000008)
#define MDPROPVAL_MC_SINGLECASE __MSABI_LONG(0x00000001)
#define MDPROPVAL_MC_SEARCHEDCASE __MSABI_LONG(0x00000002)
#define MDPROPVAL_MOQ_OUTERREFERENCE __MSABI_LONG(0x00000001)
#define MDPROPVAL_MOQ_DATASOURCE_CUBE __MSABI_LONG(0x00000001)
#define MDPROPVAL_MOQ_CATALOG_CUBE __MSABI_LONG(0x00000002)
#define MDPROPVAL_MOQ_SCHEMA_CUBE __MSABI_LONG(0x00000004)
#define MDPROPVAL_MOQ_CUBE_DIM __MSABI_LONG(0x00000008)
#define MDPROPVAL_MOQ_DIM_HIER __MSABI_LONG(0x00000010)
#define MDPROPVAL_MOQ_DIMHIER_LEVEL __MSABI_LONG(0x00000020)
#define MDPROPVAL_MOQ_LEVEL_MEMBER __MSABI_LONG(0x00000040)
#define MDPROPVAL_MOQ_MEMBER_MEMBER __MSABI_LONG(0x00000080)
#define MDPROPVAL_MOQ_DIMHIER_MEMBER __MSABI_LONG(0x00000100)
#define MDPROPVAL_FS_FULL_SUPPORT __MSABI_LONG(0x00000001)
#define MDPROPVAL_FS_GENERATED_COLUMN __MSABI_LONG(0x00000002)
#define MDPROPVAL_FS_GENERATED_DIMENSION __MSABI_LONG(0x00000003)
#define MDPROPVAL_FS_NO_SUPPORT __MSABI_LONG(0x00000004)
#define MDPROPVAL_NL_NAMEDLEVELS __MSABI_LONG(0x00000001)
#define MDPROPVAL_NL_NUMBEREDLEVELS __MSABI_LONG(0x00000002)
#define MDPROPVAL_MJC_SINGLECUBE __MSABI_LONG(0x00000001)
#define MDPROPVAL_MJC_MULTICUBES __MSABI_LONG(0x00000002)
#define MDPROPVAL_MJC_IMPLICITCUBE __MSABI_LONG(0x00000004)
#define MDPROPVAL_RR_NORANGEROWSET __MSABI_LONG(0x00000001)
#define MDPROPVAL_RR_READONLY __MSABI_LONG(0x00000002)
#define MDPROPVAL_RR_UPDATE __MSABI_LONG(0x00000004)
#define MDPROPVAL_MS_MULTIPLETUPLES __MSABI_LONG(0x00000001)
#define MDPROPVAL_MS_SINGLETUPLE __MSABI_LONG(0x00000002)
#define MDPROPVAL_NME_ALLDIMENSIONS __MSABI_LONG(0x00000000)
#define MDPROPVAL_NME_MEASURESONLY __MSABI_LONG(0x00000001)
#define DBPROPVAL_AO_SEQUENTIAL __MSABI_LONG(0x00000000)
#define DBPROPVAL_AO_SEQUENTIALSTORAGEOBJECTS __MSABI_LONG(0x00000001)
#define DBPROPVAL_AO_RANDOM __MSABI_LONG(0x00000002)
#define DBPROPVAL_BD_ROWSET __MSABI_LONG(0x00000000)
#define DBPROPVAL_BD_INTRANSACTION __MSABI_LONG(0x00000001)
#define DBPROPVAL_BD_XTRANSACTION __MSABI_LONG(0x00000002)
#define DBPROPVAL_BD_REORGANIZATION __MSABI_LONG(0x00000003)
#define BMK_DURABILITY_ROWSET DBPROPVAL_BD_ROWSET
#define BMK_DURABILITY_INTRANSACTION DBPROPVAL_BD_INTRANSACTION
#define BMK_DURABILITY_XTRANSACTION DBPROPVAL_BD_XTRANSACTION
#define BMK_DURABILITY_REORGANIZATION DBPROPVAL_BD_REORGANIZATION
#define DBPROPVAL_BO_NOLOG __MSABI_LONG(0x00000000)
#define DBPROPVAL_BO_NOINDEXUPDATE __MSABI_LONG(0x00000001)
#define DBPROPVAL_BO_REFINTEGRITY __MSABI_LONG(0x00000002)
#if !defined(_WINBASE_)
#define OF_READ 0x00000000
#define OF_WRITE 0x00000001
#define OF_READWRITE 0x00000002
#define OF_SHARE_COMPAT 0x00000000
#define OF_SHARE_EXCLUSIVE 0x00000010
#define OF_SHARE_DENY_WRITE 0x00000020
#define OF_SHARE_DENY_READ 0x00000030
#define OF_SHARE_DENY_NONE 0x00000040
#define OF_PARSE 0x00000100
#define OF_DELETE 0x00000200
#define OF_VERIFY 0x00000400
#define OF_CANCEL 0x00000800
#define OF_CREATE 0x00001000
#define OF_PROMPT 0x00002000
#define OF_EXIST 0x00004000
#define OF_REOPEN 0x00008000
#endif
#define DBPROPVAL_STGM_READ OF_READ
#define DBPROPVAL_STGM_WRITE OF_WRITE
#define DBPROPVAL_STGM_READWRITE OF_READWRITE
#define DBPROPVAL_STGM_SHARE_DENY_NONE OF_SHARE_DENY_NONE
#define DBPROPVAL_STGM_SHARE_DENY_READ OF_SHARE_DENY_READ
#define DBPROPVAL_STGM_SHARE_DENY_WRITE OF_SHARE_DENY_WRITE
#define DBPROPVAL_STGM_SHARE_EXCLUSIVE OF_SHARE_EXCLUSIVE
#define DBPROPVAL_STGM_DIRECT 0x00010000
#define DBPROPVAL_STGM_TRANSACTED 0x00020000
#define DBPROPVAL_STGM_CREATE OF_CREATE
#define DBPROPVAL_STGM_CONVERT 0x00040000
#define DBPROPVAL_STGM_FAILIFTHERE 0x00080000
#define DBPROPVAL_STGM_PRIORITY 0x00100000
#define DBPROPVAL_STGM_DELETEONRELEASE 0x00200000
#define DBPROPVAL_GB_COLLATE __MSABI_LONG(0x00000010)
#define DBPROPVAL_CS_UNINITIALIZED __MSABI_LONG(0x00000000)
#define DBPROPVAL_CS_INITIALIZED __MSABI_LONG(0x00000001)
#define DBPROPVAL_CS_COMMUNICATIONFAILURE __MSABI_LONG(0x00000002)
#define DBPROPVAL_RD_RESETALL __MSABI_LONG(0xffffffff)
#define DBPROPVAL_OS_RESOURCEPOOLING __MSABI_LONG(0x00000001)
#define DBPROPVAL_OS_TXNENLISTMENT __MSABI_LONG(0x00000002)
#define DBPROPVAL_OS_CLIENTCURSOR __MSABI_LONG(0x00000004)
#define DBPROPVAL_OS_ENABLEALL __MSABI_LONG(0xffffffff)
#define DBPROPVAL_BI_CROSSROWSET __MSABI_LONG(0x00000001)
#endif

#if (OLEDBVER >= 0x0210)
#define MDPROPVAL_NL_SCHEMAONLY __MSABI_LONG(0x00000004)
#define DBPROPVAL_OS_DISABLEALL __MSABI_LONG(0x00000000)
#define DBPROPVAL_OO_ROWOBJECT __MSABI_LONG(0x00000004)
#define DBPROPVAL_OO_SCOPED __MSABI_LONG(0x00000008)
#define DBPROPVAL_OO_DIRECTBIND __MSABI_LONG(0x00000010)
#define DBPROPVAL_DST_DOCSOURCE __MSABI_LONG(0x00000004)
#define DBPROPVAL_GU_NOTSUPPORTED __MSABI_LONG(0x00000001)
#define DBPROPVAL_GU_SUFFIX __MSABI_LONG(0x00000002)
#define DB_BINDFLAGS_DELAYFETCHCOLUMNS __MSABI_LONG(0x00000001)
#define DB_BINDFLAGS_DELAYFETCHSTREAM __MSABI_LONG(0x00000002)
#define DB_BINDFLAGS_RECURSIVE __MSABI_LONG(0x00000004)
#define DB_BINDFLAGS_OUTPUT __MSABI_LONG(0x00000008)
#define DB_BINDFLAGS_COLLECTION __MSABI_LONG(0x00000010)
#define DB_BINDFLAGS_OPENIFEXISTS __MSABI_LONG(0x00000020)
#define DB_BINDFLAGS_OVERWRITE __MSABI_LONG(0x00000040)
#define DB_BINDFLAGS_ISSTRUCTUREDDOCUMENT __MSABI_LONG(0x00000080)
#define DBPROPVAL_ORS_TABLE __MSABI_LONG(0x00000000)
#define DBPROPVAL_ORS_INDEX __MSABI_LONG(0x00000001)
#define DBPROPVAL_ORS_INTEGRATEDINDEX __MSABI_LONG(0x00000002)
#define DBPROPVAL_TC_DDL_LOCK __MSABI_LONG(0x00000010)
#define DBPROPVAL_ORS_STOREDPROC __MSABI_LONG(0x00000004)
#define DBPROPVAL_IN_ALLOWNULL __MSABI_LONG(0x00000000)
#endif

#if (OLEDBVER >= 0x0250)
#define DBPROPVAL_OO_SINGLETON __MSABI_LONG(0x00000020)
#define DBPROPVAL_OS_AGR_AFTERSESSION __MSABI_LONG(0x00000008)
#define DBPROPVAL_CM_TRANSACTIONS __MSABI_LONG(0x00000001)
#endif

#if (OLEDBVER >= 0x0260)
#define DBPROPVAL_TS_CARDINALITY __MSABI_LONG(0x00000001)
#define DBPROPVAL_TS_HISTOGRAM __MSABI_LONG(0x00000002)
#define DBPROPVAL_ORS_HISTOGRAM __MSABI_LONG(0x00000008)
#define MDPROPVAL_VISUAL_MODE_DEFAULT __MSABI_LONG(0x00000000)
#define MDPROPVAL_VISUAL_MODE_VISUAL __MSABI_LONG(0x00000001)
#define MDPROPVAL_VISUAL_MODE_VISUAL_OFF __MSABI_LONG(0x00000002)
#endif

#define DB_IMP_LEVEL_ANONYMOUS 0x00
#define DB_IMP_LEVEL_IDENTIFY 0x01
#define DB_IMP_LEVEL_IMPERSONATE 0x02
#define DB_IMP_LEVEL_DELEGATE 0x03
#define DBPROMPT_PROMPT 0x01
#define DBPROMPT_COMPLETE 0x02
#define DBPROMPT_COMPLETEREQUIRED 0x03
#define DBPROMPT_NOPROMPT 0x04
#define DB_PROT_LEVEL_NONE 0x00
#define DB_PROT_LEVEL_CONNECT 0x01
#define DB_PROT_LEVEL_CALL 0x02
#define DB_PROT_LEVEL_PKT 0x03
#define DB_PROT_LEVEL_PKT_INTEGRITY 0x04
#define DB_PROT_LEVEL_PKT_PRIVACY 0x05
#define DB_MODE_READ 0x01
#define DB_MODE_WRITE 0x02
#define DB_MODE_READWRITE 0x03
#define DB_MODE_SHARE_DENY_READ 0x04
#define DB_MODE_SHARE_DENY_WRITE 0x08
#define DB_MODE_SHARE_EXCLUSIVE 0x0c
#define DB_MODE_SHARE_DENY_NONE 0x10
#define DBCOMPUTEMODE_COMPUTED 0x01
#define DBCOMPUTEMODE_DYNAMIC 0x02
#define DBCOMPUTEMODE_NOTCOMPUTED 0x03
#define DBPROPVAL_DF_INITIALLY_DEFERRED 0x01
#define DBPROPVAL_DF_INITIALLY_IMMEDIATE 0x02
#define DBPROPVAL_DF_NOT_DEFERRABLE 0x03

  typedef struct tagDBPARAMS {
    void *pData;
    DB_UPARAMS cParamSets;
    HACCESSOR hAccessor;
  } DBPARAMS;

  typedef DWORD DBPARAMFLAGS;

  enum DBPARAMFLAGSENUM {
    DBPARAMFLAGS_ISINPUT = 0x1,DBPARAMFLAGS_ISOUTPUT = 0x2,DBPARAMFLAGS_ISSIGNED = 0x10,DBPARAMFLAGS_ISNULLABLE = 0x40,DBPARAMFLAGS_ISLONG = 0x80
  };

#if (OLEDBVER >= 0x0200)
  enum DBPARAMFLAGSENUM20 {
    DBPARAMFLAGS_SCALEISNEGATIVE = 0x100
  };
#endif

  typedef struct tagDBPARAMINFO {
    DBPARAMFLAGS dwFlags;
    DBORDINAL iOrdinal;
    LPOLESTR pwszName;
    ITypeInfo *pTypeInfo;
    DBLENGTH ulParamSize;
    DBTYPE wType;
    BYTE bPrecision;
    BYTE bScale;
  } DBPARAMINFO;

  typedef DWORD DBPROPID;

  typedef struct tagDBPROPIDSET {
    DBPROPID *rgPropertyIDs;
    ULONG cPropertyIDs;
    GUID guidPropertySet;
  } DBPROPIDSET;

  typedef DWORD DBPROPFLAGS;

  enum DBPROPFLAGSENUM {
    DBPROPFLAGS_NOTSUPPORTED = 0,DBPROPFLAGS_COLUMN = 0x1,DBPROPFLAGS_DATASOURCE = 0x2,DBPROPFLAGS_DATASOURCECREATE = 0x4,
    DBPROPFLAGS_DATASOURCEINFO = 0x8,DBPROPFLAGS_DBINIT = 0x10,DBPROPFLAGS_INDEX = 0x20,DBPROPFLAGS_ROWSET = 0x40,DBPROPFLAGS_TABLE = 0x80,
    DBPROPFLAGS_COLUMNOK = 0x100,DBPROPFLAGS_READ = 0x200,DBPROPFLAGS_WRITE = 0x400,DBPROPFLAGS_REQUIRED = 0x800,DBPROPFLAGS_SESSION = 0x1000
  };

#if (OLEDBVER >= 0x0210)
  enum DBPROPFLAGSENUM21 {
    DBPROPFLAGS_TRUSTEE = 0x2000
  };
#endif

#if (OLEDBVER >= 0x0250)
  enum DBPROPFLAGSENUM25 {
    DBPROPFLAGS_VIEW = 0x4000
  };
#endif

#if (OLEDBVER >= 0x0260)
  enum DBPROPFLAGSENUM26 {
    DBPROPFLAGS_STREAM = 0x8000
  };
#endif

  typedef struct tagDBPROPINFO {
    LPOLESTR pwszDescription;
    DBPROPID dwPropertyID;
    DBPROPFLAGS dwFlags;
    VARTYPE vtType;
    VARIANT vValues;
  } DBPROPINFO;

  typedef DBPROPINFO *PDBPROPINFO;

  typedef struct tagDBPROPINFOSET {
    PDBPROPINFO rgPropertyInfos;
    ULONG cPropertyInfos;
    GUID guidPropertySet;
  } DBPROPINFOSET;

  typedef DWORD DBPROPOPTIONS;

  enum DBPROPOPTIONSENUM {
    DBPROPOPTIONS_REQUIRED = 0,DBPROPOPTIONS_SETIFCHEAP = 0x1,DBPROPOPTIONS_OPTIONAL = 0x1
  };
  typedef DWORD DBPROPSTATUS;

  enum DBPROPSTATUSENUM {
    DBPROPSTATUS_OK = 0,DBPROPSTATUS_NOTSUPPORTED = 1,DBPROPSTATUS_BADVALUE = 2,DBPROPSTATUS_BADOPTION = 3,DBPROPSTATUS_BADCOLUMN = 4,
    DBPROPSTATUS_NOTALLSETTABLE = 5,DBPROPSTATUS_NOTSETTABLE = 6,DBPROPSTATUS_NOTSET = 7,DBPROPSTATUS_CONFLICTING = 8
  };

#if (OLEDBVER >= 0x0210)
  enum DBPROPSTATUSENUM21 {
    DBPROPSTATUS_NOTAVAILABLE = 9
  };
#endif

  typedef struct tagDBPROP {
    DBPROPID dwPropertyID;
    DBPROPOPTIONS dwOptions;
    DBPROPSTATUS dwStatus;
    DBID colid;
    VARIANT vValue;
  } DBPROP;

  typedef struct tagDBPROPSET {
    DBPROP *rgProperties;
    ULONG cProperties;
    GUID guidPropertySet;
  } DBPROPSET;

#define DBPARAMTYPE_INPUT 0x01
#define DBPARAMTYPE_INPUTOUTPUT 0x02
#define DBPARAMTYPE_OUTPUT 0x03
#define DBPARAMTYPE_RETURNVALUE 0x04
#define DB_PT_UNKNOWN 0x01
#define DB_PT_PROCEDURE 0x02
#define DB_PT_FUNCTION 0x03
#define DB_REMOTE 0x01
#define DB_LOCAL_SHARED 0x02
#define DB_LOCAL_EXCLUSIVE 0x03
#define DB_COLLATION_ASC 0x01
#define DB_COLLATION_DESC 0x02
#define DB_UNSEARCHABLE 0x01
#define DB_LIKE_ONLY 0x02
#define DB_ALL_EXCEPT_LIKE 0x03
#define DB_SEARCHABLE 0x04

#if (OLEDBVER >= 0x0200)
#define MDTREEOP_CHILDREN 0x01
#define MDTREEOP_SIBLINGS 0x02
#define MDTREEOP_PARENT 0x04
#define MDTREEOP_SELF 0x08
#define MDTREEOP_DESCENDANTS 0x10
#define MDTREEOP_ANCESTORS 0x20
#define MD_DIMTYPE_UNKNOWN 0x00
#define MD_DIMTYPE_TIME 0x01
#define MD_DIMTYPE_MEASURE 0x02
#define MD_DIMTYPE_OTHER 0x03
#define MDLEVEL_TYPE_UNKNOWN 0x0000
#define MDLEVEL_TYPE_REGULAR 0x0000
#define MDLEVEL_TYPE_ALL 0x0001
#define MDLEVEL_TYPE_CALCULATED 0x0002
#define MDLEVEL_TYPE_TIME 0x0004
#define MDLEVEL_TYPE_RESERVED1 0x0008
#define MDLEVEL_TYPE_TIME_YEARS 0x0014
#define MDLEVEL_TYPE_TIME_HALF_YEAR 0x0024
#define MDLEVEL_TYPE_TIME_QUARTERS 0x0044
#define MDLEVEL_TYPE_TIME_MONTHS 0x0084
#define MDLEVEL_TYPE_TIME_WEEKS 0x0104
#define MDLEVEL_TYPE_TIME_DAYS 0x0204
#define MDLEVEL_TYPE_TIME_HOURS 0x0304
#define MDLEVEL_TYPE_TIME_MINUTES 0x0404
#define MDLEVEL_TYPE_TIME_SECONDS 0x0804
#define MDLEVEL_TYPE_TIME_UNDEFINED 0x1004
#define MDMEASURE_AGGR_UNKNOWN 0x00
#define MDMEASURE_AGGR_SUM 0x01
#define MDMEASURE_AGGR_COUNT 0x02
#define MDMEASURE_AGGR_MIN 0x03
#define MDMEASURE_AGGR_MAX 0x04
#define MDMEASURE_AGGR_AVG 0x05
#define MDMEASURE_AGGR_VAR 0x06
#define MDMEASURE_AGGR_STD 0x07
#define MDMEASURE_AGGR_CALCULATED 0x7f
#define MDPROP_MEMBER 0x01
#define MDPROP_CELL 0x02
#define MDMEMBER_TYPE_UNKNOWN 0x00
#define MDMEMBER_TYPE_REGULAR 0x01
#define MDMEMBER_TYPE_ALL 0x02
#define MDMEMBER_TYPE_MEASURE 0x03
#define MDMEMBER_TYPE_FORMULA 0x04
#define MDMEMBER_TYPE_RESERVE1 0x05
#define MDMEMBER_TYPE_RESERVE2 0x06
#define MDMEMBER_TYPE_RESERVE3 0x07
#define MDMEMBER_TYPE_RESERVE4 0x08
#define MDDISPINFO_DRILLED_DOWN 0x00010000
#define MDDISPINFO_PARENT_SAME_AS_PREV 0x00020000
#endif

  typedef DWORD DBINDEX_COL_ORDER;

  enum DBINDEX_COL_ORDERENUM {
    DBINDEX_COL_ORDER_ASC = 0,DBINDEX_COL_ORDER_DESC = DBINDEX_COL_ORDER_ASC + 1
  };
  typedef struct tagDBINDEXCOLUMNDESC {
    DBID *pColumnID;
    DBINDEX_COL_ORDER eIndexColOrder;
  } DBINDEXCOLUMNDESC;

  typedef struct tagDBCOLUMNDESC {
    LPOLESTR pwszTypeName;
    ITypeInfo *pTypeInfo;
    DBPROPSET *rgPropertySets;
    CLSID *pclsid;
    ULONG cPropertySets;
    DBLENGTH ulColumnSize;
    DBID dbcid;
    DBTYPE wType;
    BYTE bPrecision;
    BYTE bScale;
  } DBCOLUMNDESC;

#if (OLEDBVER >= 0x0210)
  typedef struct tagDBCOLUMNACCESS {
    void *pData;
    DBID columnid;
    DBLENGTH cbDataLen;
    DBSTATUS dwStatus;
    DBLENGTH cbMaxLen;
    DB_DWRESERVE dwReserved;
    DBTYPE wType;
    BYTE bPrecision;
    BYTE bScale;
  } DBCOLUMNACCESS;
#endif

#if (OLEDBVER >= 0x0200)
  typedef DWORD DBCOLUMNDESCFLAGS;

  enum DBCOLUMNDESCFLAGSENUM {
    DBCOLUMNDESCFLAGS_TYPENAME = 0x1,DBCOLUMNDESCFLAGS_ITYPEINFO = 0x2,DBCOLUMNDESCFLAGS_PROPERTIES = 0x4,DBCOLUMNDESCFLAGS_CLSID = 0x8,
    DBCOLUMNDESCFLAGS_COLSIZE = 0x10,DBCOLUMNDESCFLAGS_DBCID = 0x20,DBCOLUMNDESCFLAGS_WTYPE = 0x40,DBCOLUMNDESCFLAGS_PRECISION = 0x80,
    DBCOLUMNDESCFLAGS_SCALE = 0x100
  };
#endif
  typedef DWORD DBEVENTPHASE;

  enum DBEVENTPHASEENUM {
    DBEVENTPHASE_OKTODO = 0,DBEVENTPHASE_ABOUTTODO,DBEVENTPHASE_SYNCHAFTER,
    DBEVENTPHASE_FAILEDTODO,DBEVENTPHASE_DIDEVENT
  };
  typedef DWORD DBREASON;

  enum DBREASONENUM {
    DBREASON_ROWSET_FETCHPOSITIONCHANGE = 0,DBREASON_ROWSET_RELEASE,
    DBREASON_COLUMN_SET,DBREASON_COLUMN_RECALCULATED,DBREASON_ROW_ACTIVATE,
    DBREASON_ROW_RELEASE,DBREASON_ROW_DELETE,DBREASON_ROW_FIRSTCHANGE,
    DBREASON_ROW_INSERT,DBREASON_ROW_RESYNCH,DBREASON_ROW_UNDOCHANGE,
    DBREASON_ROW_UNDOINSERT,DBREASON_ROW_UNDODELETE,DBREASON_ROW_UPDATE,
    DBREASON_ROWSET_CHANGED
  };

#if (OLEDBVER >= 0x0150)
  enum DBREASONENUM15 {
    DBREASON_ROWPOSITION_CHANGED = DBREASON_ROWSET_CHANGED + 1,
    DBREASON_ROWPOSITION_CHAPTERCHANGED,DBREASON_ROWPOSITION_CLEARED,
    DBREASON_ROW_ASYNCHINSERT
  };
#endif

#if (OLEDBVER >= 0x0150)
  typedef DWORD DBCOMPAREOP;

  enum DBCOMPAREOPSENUM {
    DBCOMPAREOPS_LT = 0,DBCOMPAREOPS_LE = 1,DBCOMPAREOPS_EQ = 2,DBCOMPAREOPS_GE = 3,DBCOMPAREOPS_GT = 4,DBCOMPAREOPS_BEGINSWITH = 5,
    DBCOMPAREOPS_CONTAINS = 6,DBCOMPAREOPS_NE = 7,DBCOMPAREOPS_IGNORE = 8,DBCOMPAREOPS_CASESENSITIVE = 0x1000,DBCOMPAREOPS_CASEINSENSITIVE = 0x2000
  };

#if (OLEDBVER >= 0x0200)
  enum DBCOMPAREOPSENUM20 {
    DBCOMPAREOPS_NOTBEGINSWITH = 9,DBCOMPAREOPS_NOTCONTAINS = 10
  };
#endif

  typedef DWORD DBASYNCHOP;

  enum DBASYNCHOPENUM {
    DBASYNCHOP_OPEN = 0
  };
  typedef DWORD DBASYNCHPHASE;

  enum DBASYNCHPHASEENUM {
    DBASYNCHPHASE_INITIALIZATION = 0,
    DBASYNCHPHASE_POPULATION,DBASYNCHPHASE_COMPLETE,DBASYNCHPHASE_CANCELED
  };
#define DB_COUNTUNAVAILABLE -1
#endif

  typedef DWORD DBSORT;

  enum DBSORTENUM {
    DBSORT_ASCENDING = 0,DBSORT_DESCENDING = DBSORT_ASCENDING + 1
  };
#if (OLEDBVER >= 0x0200)
  typedef DWORD DBCOMMANDPERSISTFLAG;

  enum DBCOMMANDPERSISTFLAGENUM {
    DBCOMMANDPERSISTFLAG_NOSAVE = 0x1
  };
#endif

#if (OLEDBVER >= 0x0210)
  enum DBCOMMANDPERSISTFLAGENUM21 {
    DBCOMMANDPERSISTFLAG_DEFAULT = 0,DBCOMMANDPERSISTFLAG_PERSISTVIEW = 0x2,DBCOMMANDPERSISTFLAG_PERSISTPROCEDURE = 0x4
  };
  typedef DWORD DBCONSTRAINTTYPE;

  enum DBCONSTRAINTTYPEENUM {
    DBCONSTRAINTTYPE_UNIQUE = 0,DBCONSTRAINTTYPE_FOREIGNKEY = 0x1,DBCONSTRAINTTYPE_PRIMARYKEY = 0x2,DBCONSTRAINTTYPE_CHECK = 0x3
  };
  typedef DWORD DBUPDELRULE;

  enum DBUPDELRULEENUM {
    DBUPDELRULE_NOACTION = 0,DBUPDELRULE_CASCADE = 0x1,DBUPDELRULE_SETNULL = 0x2,DBUPDELRULE_SETDEFAULT = 0x3
  };
  typedef DWORD DBMATCHTYPE;

  enum DBMATCHTYPEENUM {
    DBMATCHTYPE_FULL = 0,DBMATCHTYPE_NONE = 0x1,DBMATCHTYPE_PARTIAL = 0x2
  };
  typedef DWORD DBDEFERRABILITY;

  enum DBDEFERRABILITYENUM {
    DBDEFERRABILITY_DEFERRED = 0x1,DBDEFERRABILITY_DEFERRABLE = 0x2
  };
  typedef struct tagDBCONSTRAINTDESC {
    DBID *pConstraintID;
    DBCONSTRAINTTYPE ConstraintType;
    DBORDINAL cColumns;
    DBID *rgColumnList;
    DBID *pReferencedTableID;
    DBORDINAL cForeignKeyColumns;
    DBID *rgForeignKeyColumnList;
    OLECHAR *pwszConstraintText;
    DBUPDELRULE UpdateRule;
    DBUPDELRULE DeleteRule;
    DBMATCHTYPE MatchType;
    DBDEFERRABILITY Deferrability;
    DB_URESERVE cReserved;
    DBPROPSET *rgReserved;
  } DBCONSTRAINTDESC;
#endif

#if (OLEDBVER >= 0x0200)
#define MDFF_BOLD 0x01
#define MDFF_ITALIC 0x02
#define MDFF_UNDERLINE 0x04
#define MDFF_STRIKEOUT 0x08

  typedef struct tagMDAXISINFO {
    DBLENGTH cbSize;
    DBCOUNTITEM iAxis;
    DBCOUNTITEM cDimensions;
    DBCOUNTITEM cCoordinates;
    DBORDINAL *rgcColumns;
    LPOLESTR *rgpwszDimensionNames;
  } MDAXISINFO;

#define PMDAXISINFO_GETAT(rgAxisInfo,iAxis) ((MDAXISINFO *)(((BYTE *)(rgAxisInfo)) +((iAxis) *(rgAxisInfo)[0].cbSize)))
#define MDAXISINFO_GETAT(rgAxisInfo,iAxis) (*PMDAXISINFO_GETAT((rgAxisInfo),(iAxis)))
#define MDAXIS_COLUMNS 0x00000000
#define MDAXIS_ROWS 0x00000001
#define MDAXIS_PAGES 0x00000002
#define MDAXIS_SECTIONS 0x00000003
#define MDAXIS_CHAPTERS 0x00000004
#define MDAXIS_SLICERS 0xffffffff
#endif

  typedef struct tagRMTPACK {
    ISequentialStream *pISeqStream;
    ULONG cbData;
    ULONG cBSTR;
    BSTR *rgBSTR;
    ULONG cVARIANT;
    VARIANT *rgVARIANT;
    ULONG cIDISPATCH;
    IDispatch **rgIDISPATCH;
    ULONG cIUNKNOWN;
    IUnknown **rgIUNKNOWN;
    ULONG cPROPVARIANT;
    PROPVARIANT *rgPROPVARIANT;
    ULONG cArray;
    VARIANT *rgArray;
  } RMTPACK;

  extern RPC_IF_HANDLE DBStructureDefinitions_v0_0_c_ifspec;
  extern RPC_IF_HANDLE DBStructureDefinitions_v0_0_s_ifspec;
#endif

#ifndef __IAccessor_INTERFACE_DEFINED__
#define __IAccessor_INTERFACE_DEFINED__

  typedef DWORD DBACCESSORFLAGS;

  enum DBACCESSORFLAGSENUM {
    DBACCESSOR_INVALID = 0,DBACCESSOR_PASSBYREF = 0x1,DBACCESSOR_ROWDATA = 0x2,DBACCESSOR_PARAMETERDATA = 0x4,DBACCESSOR_OPTIMIZED = 0x8,
    DBACCESSOR_INHERITED = 0x10
  };
  typedef DWORD DBBINDSTATUS;

  enum DBBINDSTATUSENUM {
    DBBINDSTATUS_OK = 0,DBBINDSTATUS_BADORDINAL = 1,DBBINDSTATUS_UNSUPPORTEDCONVERSION = 2,DBBINDSTATUS_BADBINDINFO = 3,
    DBBINDSTATUS_BADSTORAGEFLAGS = 4,DBBINDSTATUS_NOINTERFACE = 5,DBBINDSTATUS_MULTIPLESTORAGE = 6
  };

  EXTERN_C const IID IID_IAccessor;

#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAccessor : public IUnknown {
  public:
    virtual HRESULT WINAPI AddRefAccessor(HACCESSOR hAccessor,DBREFCOUNT *pcRefCount) = 0;
    virtual HRESULT WINAPI CreateAccessor(DBACCESSORFLAGS dwAccessorFlags,DBCOUNTITEM cBindings,const DBBINDING rgBindings[],DBLENGTH cbRowSize,HACCESSOR *phAccessor,DBBINDSTATUS rgStatus[]) = 0;
    virtual HRESULT WINAPI GetBindings(HACCESSOR hAccessor,DBACCESSORFLAGS *pdwAccessorFlags,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings) = 0;
    virtual HRESULT WINAPI ReleaseAccessor(HACCESSOR hAccessor,DBREFCOUNT *pcRefCount) = 0;
  };
#else
  typedef struct IAccessorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAccessor *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAccessor *This);
      ULONG (WINAPI *Release)(IAccessor *This);
      HRESULT (WINAPI *AddRefAccessor)(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount);
      HRESULT (WINAPI *CreateAccessor)(IAccessor *This,DBACCESSORFLAGS dwAccessorFlags,DBCOUNTITEM cBindings,const DBBINDING rgBindings[],DBLENGTH cbRowSize,HACCESSOR *phAccessor,DBBINDSTATUS rgStatus[]);
      HRESULT (WINAPI *GetBindings)(IAccessor *This,HACCESSOR hAccessor,DBACCESSORFLAGS *pdwAccessorFlags,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings);
      HRESULT (WINAPI *ReleaseAccessor)(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount);
    END_INTERFACE
  } IAccessorVtbl;
  struct IAccessor {
    CONST_VTBL struct IAccessorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAccessor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAccessor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAccessor_Release(This) (This)->lpVtbl->Release(This)
#define IAccessor_AddRefAccessor(This,hAccessor,pcRefCount) (This)->lpVtbl->AddRefAccessor(This,hAccessor,pcRefCount)
#define IAccessor_CreateAccessor(This,dwAccessorFlags,cBindings,rgBindings,cbRowSize,phAccessor,rgStatus) (This)->lpVtbl->CreateAccessor(This,dwAccessorFlags,cBindings,rgBindings,cbRowSize,phAccessor,rgStatus)
#define IAccessor_GetBindings(This,hAccessor,pdwAccessorFlags,pcBindings,prgBindings) (This)->lpVtbl->GetBindings(This,hAccessor,pdwAccessorFlags,pcBindings,prgBindings)
#define IAccessor_ReleaseAccessor(This,hAccessor,pcRefCount) (This)->lpVtbl->ReleaseAccessor(This,hAccessor,pcRefCount)
#endif
#endif
  HRESULT WINAPI IAccessor_RemoteAddRefAccessor_Proxy(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IAccessor_RemoteAddRefAccessor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessor_RemoteCreateAccessor_Proxy(IAccessor *This,DBACCESSORFLAGS dwAccessorFlags,DBCOUNTITEM cBindings,DBBINDING *rgBindings,DBLENGTH cbRowSize,HACCESSOR *phAccessor,DBBINDSTATUS *rgStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IAccessor_RemoteCreateAccessor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessor_RemoteGetBindings_Proxy(IAccessor *This,HACCESSOR hAccessor,DBACCESSORFLAGS *pdwAccessorFlags,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IAccessor_RemoteGetBindings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessor_RemoteReleaseAccessor_Proxy(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IAccessor_RemoteReleaseAccessor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowset_INTERFACE_DEFINED__
#define __IRowset_INTERFACE_DEFINED__
  typedef DWORD DBROWOPTIONS;

  EXTERN_C const IID IID_IRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI AddRefRows(DBCOUNTITEM cRows,const HROW rghRows[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]) = 0;
    virtual HRESULT WINAPI GetData(HROW hRow,HACCESSOR hAccessor,void *pData) = 0;
    virtual HRESULT WINAPI GetNextRows(HCHAPTER hReserved,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows) = 0;
    virtual HRESULT WINAPI ReleaseRows(DBCOUNTITEM cRows,const HROW rghRows[],DBROWOPTIONS rgRowOptions[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]) = 0;
    virtual HRESULT WINAPI RestartPosition(HCHAPTER hReserved) = 0;
  };
#else
  typedef struct IRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowset *This);
      ULONG (WINAPI *Release)(IRowset *This);
      HRESULT (WINAPI *AddRefRows)(IRowset *This,DBCOUNTITEM cRows,const HROW rghRows[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *GetData)(IRowset *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *GetNextRows)(IRowset *This,HCHAPTER hReserved,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *ReleaseRows)(IRowset *This,DBCOUNTITEM cRows,const HROW rghRows[],DBROWOPTIONS rgRowOptions[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *RestartPosition)(IRowset *This,HCHAPTER hReserved);
    END_INTERFACE
  } IRowsetVtbl;
  struct IRowset {
    CONST_VTBL struct IRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowset_Release(This) (This)->lpVtbl->Release(This)
#define IRowset_AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus) (This)->lpVtbl->AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus)
#define IRowset_GetData(This,hRow,hAccessor,pData) (This)->lpVtbl->GetData(This,hRow,hAccessor,pData)
#define IRowset_GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows)
#define IRowset_ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus) (This)->lpVtbl->ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus)
#define IRowset_RestartPosition(This,hReserved) (This)->lpVtbl->RestartPosition(This,hReserved)
#endif
#endif
  HRESULT WINAPI IRowset_AddRefRows_Proxy(IRowset *This,DBCOUNTITEM cRows,const HROW rghRows[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
  void __RPC_STUB IRowset_AddRefRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowset_GetData_Proxy(IRowset *This,HROW hRow,HACCESSOR hAccessor,void *pData);
  void __RPC_STUB IRowset_GetData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowset_GetNextRows_Proxy(IRowset *This,HCHAPTER hReserved,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
  void __RPC_STUB IRowset_GetNextRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowset_ReleaseRows_Proxy(IRowset *This,DBCOUNTITEM cRows,const HROW rghRows[],DBROWOPTIONS rgRowOptions[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
  void __RPC_STUB IRowset_ReleaseRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowset_RestartPosition_Proxy(IRowset *This,HCHAPTER hReserved);
  void __RPC_STUB IRowset_RestartPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetInfo_INTERFACE_DEFINED__
#define __IRowsetInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetProperties(const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets) = 0;
    virtual HRESULT WINAPI GetReferencedRowset(DBORDINAL iOrdinal,REFIID riid,IUnknown **ppReferencedRowset) = 0;
    virtual HRESULT WINAPI GetSpecification(REFIID riid,IUnknown **ppSpecification) = 0;
  };
#else
  typedef struct IRowsetInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetInfo *This);
      ULONG (WINAPI *Release)(IRowsetInfo *This);
      HRESULT (WINAPI *GetProperties)(IRowsetInfo *This,const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
      HRESULT (WINAPI *GetReferencedRowset)(IRowsetInfo *This,DBORDINAL iOrdinal,REFIID riid,IUnknown **ppReferencedRowset);
      HRESULT (WINAPI *GetSpecification)(IRowsetInfo *This,REFIID riid,IUnknown **ppSpecification);
    END_INTERFACE
  } IRowsetInfoVtbl;
  struct IRowsetInfo {
    CONST_VTBL struct IRowsetInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetInfo_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetInfo_GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets) (This)->lpVtbl->GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets)
#define IRowsetInfo_GetReferencedRowset(This,iOrdinal,riid,ppReferencedRowset) (This)->lpVtbl->GetReferencedRowset(This,iOrdinal,riid,ppReferencedRowset)
#define IRowsetInfo_GetSpecification(This,riid,ppSpecification) (This)->lpVtbl->GetSpecification(This,riid,ppSpecification)
#endif
#endif
  HRESULT WINAPI IRowsetInfo_RemoteGetProperties_Proxy(IRowsetInfo *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowsetInfo_RemoteGetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetInfo_RemoteGetReferencedRowset_Proxy(IRowsetInfo *This,DBORDINAL iOrdinal,REFIID riid,IUnknown **ppReferencedRowset,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowsetInfo_RemoteGetReferencedRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetInfo_RemoteGetSpecification_Proxy(IRowsetInfo *This,REFIID riid,IUnknown **ppSpecification,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowsetInfo_RemoteGetSpecification_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetLocate_INTERFACE_DEFINED__
#define __IRowsetLocate_INTERFACE_DEFINED__
  typedef DWORD DBCOMPARE;

  enum DBCOMPAREENUM {
    DBCOMPARE_LT = 0,
    DBCOMPARE_EQ,DBCOMPARE_GT,DBCOMPARE_NE,DBCOMPARE_NOTCOMPARABLE
  };

  EXTERN_C const IID IID_IRowsetLocate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetLocate : public IRowset {
  public:
    virtual HRESULT WINAPI Compare(HCHAPTER hReserved,DBBKMARK cbBookmark1,const BYTE *pBookmark1,DBBKMARK cbBookmark2,const BYTE *pBookmark2,DBCOMPARE *pComparison) = 0;
    virtual HRESULT WINAPI GetRowsAt(HWATCHREGION hReserved1,HCHAPTER hReserved2,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows) = 0;
    virtual HRESULT WINAPI GetRowsByBookmark(HCHAPTER hReserved,DBCOUNTITEM cRows,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],HROW rghRows[],DBROWSTATUS rgRowStatus[]) = 0;
    virtual HRESULT WINAPI Hash(HCHAPTER hReserved,DBBKMARK cBookmarks,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],DBHASHVALUE rgHashedValues[],DBROWSTATUS rgBookmarkStatus[]) = 0;
  };
#else
  typedef struct IRowsetLocateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetLocate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetLocate *This);
      ULONG (WINAPI *Release)(IRowsetLocate *This);
      HRESULT (WINAPI *AddRefRows)(IRowsetLocate *This,DBCOUNTITEM cRows,const HROW rghRows[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *GetData)(IRowsetLocate *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *GetNextRows)(IRowsetLocate *This,HCHAPTER hReserved,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *ReleaseRows)(IRowsetLocate *This,DBCOUNTITEM cRows,const HROW rghRows[],DBROWOPTIONS rgRowOptions[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *RestartPosition)(IRowsetLocate *This,HCHAPTER hReserved);
      HRESULT (WINAPI *Compare)(IRowsetLocate *This,HCHAPTER hReserved,DBBKMARK cbBookmark1,const BYTE *pBookmark1,DBBKMARK cbBookmark2,const BYTE *pBookmark2,DBCOMPARE *pComparison);
      HRESULT (WINAPI *GetRowsAt)(IRowsetLocate *This,HWATCHREGION hReserved1,HCHAPTER hReserved2,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *GetRowsByBookmark)(IRowsetLocate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],HROW rghRows[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *Hash)(IRowsetLocate *This,HCHAPTER hReserved,DBBKMARK cBookmarks,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],DBHASHVALUE rgHashedValues[],DBROWSTATUS rgBookmarkStatus[]);
    END_INTERFACE
  } IRowsetLocateVtbl;
  struct IRowsetLocate {
    CONST_VTBL struct IRowsetLocateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetLocate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetLocate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetLocate_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetLocate_AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus) (This)->lpVtbl->AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus)
#define IRowsetLocate_GetData(This,hRow,hAccessor,pData) (This)->lpVtbl->GetData(This,hRow,hAccessor,pData)
#define IRowsetLocate_GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows)
#define IRowsetLocate_ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus) (This)->lpVtbl->ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus)
#define IRowsetLocate_RestartPosition(This,hReserved) (This)->lpVtbl->RestartPosition(This,hReserved)
#define IRowsetLocate_Compare(This,hReserved,cbBookmark1,pBookmark1,cbBookmark2,pBookmark2,pComparison) (This)->lpVtbl->Compare(This,hReserved,cbBookmark1,pBookmark1,cbBookmark2,pBookmark2,pComparison)
#define IRowsetLocate_GetRowsAt(This,hReserved1,hReserved2,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetRowsAt(This,hReserved1,hReserved2,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows)
#define IRowsetLocate_GetRowsByBookmark(This,hReserved,cRows,rgcbBookmarks,rgpBookmarks,rghRows,rgRowStatus) (This)->lpVtbl->GetRowsByBookmark(This,hReserved,cRows,rgcbBookmarks,rgpBookmarks,rghRows,rgRowStatus)
#define IRowsetLocate_Hash(This,hReserved,cBookmarks,rgcbBookmarks,rgpBookmarks,rgHashedValues,rgBookmarkStatus) (This)->lpVtbl->Hash(This,hReserved,cBookmarks,rgcbBookmarks,rgpBookmarks,rgHashedValues,rgBookmarkStatus)
#endif
#endif
  HRESULT WINAPI IRowsetLocate_Compare_Proxy(IRowsetLocate *This,HCHAPTER hReserved,DBBKMARK cbBookmark1,const BYTE *pBookmark1,DBBKMARK cbBookmark2,const BYTE *pBookmark2,DBCOMPARE *pComparison);
  void __RPC_STUB IRowsetLocate_Compare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetLocate_GetRowsAt_Proxy(IRowsetLocate *This,HWATCHREGION hReserved1,HCHAPTER hReserved2,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
  void __RPC_STUB IRowsetLocate_GetRowsAt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetLocate_GetRowsByBookmark_Proxy(IRowsetLocate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],HROW rghRows[],DBROWSTATUS rgRowStatus[]);
  void __RPC_STUB IRowsetLocate_GetRowsByBookmark_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetLocate_Hash_Proxy(IRowsetLocate *This,HCHAPTER hReserved,DBBKMARK cBookmarks,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],DBHASHVALUE rgHashedValues[],DBROWSTATUS rgBookmarkStatus[]);
  void __RPC_STUB IRowsetLocate_Hash_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetResynch_INTERFACE_DEFINED__
#define __IRowsetResynch_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetResynch;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetResynch : public IUnknown {
  public:
    virtual HRESULT WINAPI GetVisibleData(HROW hRow,HACCESSOR hAccessor,void *pData) = 0;
    virtual HRESULT WINAPI ResynchRows(DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRowsResynched,HROW **prghRowsResynched,DBROWSTATUS **prgRowStatus) = 0;
  };
#else
  typedef struct IRowsetResynchVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetResynch *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetResynch *This);
      ULONG (WINAPI *Release)(IRowsetResynch *This);
      HRESULT (WINAPI *GetVisibleData)(IRowsetResynch *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *ResynchRows)(IRowsetResynch *This,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRowsResynched,HROW **prghRowsResynched,DBROWSTATUS **prgRowStatus);
    END_INTERFACE
  } IRowsetResynchVtbl;
  struct IRowsetResynch {
    CONST_VTBL struct IRowsetResynchVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetResynch_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetResynch_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetResynch_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetResynch_GetVisibleData(This,hRow,hAccessor,pData) (This)->lpVtbl->GetVisibleData(This,hRow,hAccessor,pData)
#define IRowsetResynch_ResynchRows(This,cRows,rghRows,pcRowsResynched,prghRowsResynched,prgRowStatus) (This)->lpVtbl->ResynchRows(This,cRows,rghRows,pcRowsResynched,prghRowsResynched,prgRowStatus)
#endif
#endif
  HRESULT WINAPI IRowsetResynch_GetVisibleData_Proxy(IRowsetResynch *This,HROW hRow,HACCESSOR hAccessor,void *pData);
  void __RPC_STUB IRowsetResynch_GetVisibleData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetResynch_ResynchRows_Proxy(IRowsetResynch *This,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRowsResynched,HROW **prghRowsResynched,DBROWSTATUS **prgRowStatus);
  void __RPC_STUB IRowsetResynch_ResynchRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetScroll_INTERFACE_DEFINED__
#define __IRowsetScroll_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetScroll;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetScroll : public IRowsetLocate {
  public:
    virtual HRESULT WINAPI GetApproximatePosition(HCHAPTER hReserved,DBBKMARK cbBookmark,const BYTE *pBookmark,DBCOUNTITEM *pulPosition,DBCOUNTITEM *pcRows) = 0;
    virtual HRESULT WINAPI GetRowsAtRatio(HWATCHREGION hReserved1,HCHAPTER hReserved2,DBCOUNTITEM ulNumerator,DBCOUNTITEM ulDenominator,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows) = 0;
  };
#else
  typedef struct IRowsetScrollVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetScroll *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetScroll *This);
      ULONG (WINAPI *Release)(IRowsetScroll *This);
      HRESULT (WINAPI *AddRefRows)(IRowsetScroll *This,DBCOUNTITEM cRows,const HROW rghRows[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *GetData)(IRowsetScroll *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *GetNextRows)(IRowsetScroll *This,HCHAPTER hReserved,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *ReleaseRows)(IRowsetScroll *This,DBCOUNTITEM cRows,const HROW rghRows[],DBROWOPTIONS rgRowOptions[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *RestartPosition)(IRowsetScroll *This,HCHAPTER hReserved);
      HRESULT (WINAPI *Compare)(IRowsetScroll *This,HCHAPTER hReserved,DBBKMARK cbBookmark1,const BYTE *pBookmark1,DBBKMARK cbBookmark2,const BYTE *pBookmark2,DBCOMPARE *pComparison);
      HRESULT (WINAPI *GetRowsAt)(IRowsetScroll *This,HWATCHREGION hReserved1,HCHAPTER hReserved2,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *GetRowsByBookmark)(IRowsetScroll *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],HROW rghRows[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *Hash)(IRowsetScroll *This,HCHAPTER hReserved,DBBKMARK cBookmarks,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],DBHASHVALUE rgHashedValues[],DBROWSTATUS rgBookmarkStatus[]);
      HRESULT (WINAPI *GetApproximatePosition)(IRowsetScroll *This,HCHAPTER hReserved,DBBKMARK cbBookmark,const BYTE *pBookmark,DBCOUNTITEM *pulPosition,DBCOUNTITEM *pcRows);
      HRESULT (WINAPI *GetRowsAtRatio)(IRowsetScroll *This,HWATCHREGION hReserved1,HCHAPTER hReserved2,DBCOUNTITEM ulNumerator,DBCOUNTITEM ulDenominator,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
    END_INTERFACE
  } IRowsetScrollVtbl;
  struct IRowsetScroll {
    CONST_VTBL struct IRowsetScrollVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetScroll_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetScroll_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetScroll_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetScroll_AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus) (This)->lpVtbl->AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus)
#define IRowsetScroll_GetData(This,hRow,hAccessor,pData) (This)->lpVtbl->GetData(This,hRow,hAccessor,pData)
#define IRowsetScroll_GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows)
#define IRowsetScroll_ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus) (This)->lpVtbl->ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus)
#define IRowsetScroll_RestartPosition(This,hReserved) (This)->lpVtbl->RestartPosition(This,hReserved)
#define IRowsetScroll_Compare(This,hReserved,cbBookmark1,pBookmark1,cbBookmark2,pBookmark2,pComparison) (This)->lpVtbl->Compare(This,hReserved,cbBookmark1,pBookmark1,cbBookmark2,pBookmark2,pComparison)
#define IRowsetScroll_GetRowsAt(This,hReserved1,hReserved2,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetRowsAt(This,hReserved1,hReserved2,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows)
#define IRowsetScroll_GetRowsByBookmark(This,hReserved,cRows,rgcbBookmarks,rgpBookmarks,rghRows,rgRowStatus) (This)->lpVtbl->GetRowsByBookmark(This,hReserved,cRows,rgcbBookmarks,rgpBookmarks,rghRows,rgRowStatus)
#define IRowsetScroll_Hash(This,hReserved,cBookmarks,rgcbBookmarks,rgpBookmarks,rgHashedValues,rgBookmarkStatus) (This)->lpVtbl->Hash(This,hReserved,cBookmarks,rgcbBookmarks,rgpBookmarks,rgHashedValues,rgBookmarkStatus)
#define IRowsetScroll_GetApproximatePosition(This,hReserved,cbBookmark,pBookmark,pulPosition,pcRows) (This)->lpVtbl->GetApproximatePosition(This,hReserved,cbBookmark,pBookmark,pulPosition,pcRows)
#define IRowsetScroll_GetRowsAtRatio(This,hReserved1,hReserved2,ulNumerator,ulDenominator,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetRowsAtRatio(This,hReserved1,hReserved2,ulNumerator,ulDenominator,cRows,pcRowsObtained,prghRows)
#endif
#endif
  HRESULT WINAPI IRowsetScroll_GetApproximatePosition_Proxy(IRowsetScroll *This,HCHAPTER hReserved,DBBKMARK cbBookmark,const BYTE *pBookmark,DBCOUNTITEM *pulPosition,DBCOUNTITEM *pcRows);
  void __RPC_STUB IRowsetScroll_GetApproximatePosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetScroll_GetRowsAtRatio_Proxy(IRowsetScroll *This,HWATCHREGION hReserved1,HCHAPTER hReserved2,DBCOUNTITEM ulNumerator,DBCOUNTITEM ulDenominator,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
  void __RPC_STUB IRowsetScroll_GetRowsAtRatio_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#if (OLEDBVER >= 0x0150)
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0273_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0273_v0_0_s_ifspec;
#ifndef __IChapteredRowset_INTERFACE_DEFINED__
#define __IChapteredRowset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IChapteredRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IChapteredRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI AddRefChapter(HCHAPTER hChapter,DBREFCOUNT *pcRefCount) = 0;
    virtual HRESULT WINAPI ReleaseChapter(HCHAPTER hChapter,DBREFCOUNT *pcRefCount) = 0;
  };
#else
  typedef struct IChapteredRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IChapteredRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IChapteredRowset *This);
      ULONG (WINAPI *Release)(IChapteredRowset *This);
      HRESULT (WINAPI *AddRefChapter)(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount);
      HRESULT (WINAPI *ReleaseChapter)(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount);
    END_INTERFACE
  } IChapteredRowsetVtbl;
  struct IChapteredRowset {
    CONST_VTBL struct IChapteredRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IChapteredRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IChapteredRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IChapteredRowset_Release(This) (This)->lpVtbl->Release(This)
#define IChapteredRowset_AddRefChapter(This,hChapter,pcRefCount) (This)->lpVtbl->AddRefChapter(This,hChapter,pcRefCount)
#define IChapteredRowset_ReleaseChapter(This,hChapter,pcRefCount) (This)->lpVtbl->ReleaseChapter(This,hChapter,pcRefCount)
#endif
#endif
  HRESULT WINAPI IChapteredRowset_RemoteAddRefChapter_Proxy(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IChapteredRowset_RemoteAddRefChapter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IChapteredRowset_RemoteReleaseChapter_Proxy(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IChapteredRowset_RemoteReleaseChapter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetFind_INTERFACE_DEFINED__
#define __IRowsetFind_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetFind;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetFind : public IUnknown {
  public:
    virtual HRESULT WINAPI FindNextRow(HCHAPTER hChapter,HACCESSOR hAccessor,void *pFindValue,DBCOMPAREOP CompareOp,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows) = 0;
  };
#else
  typedef struct IRowsetFindVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetFind *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetFind *This);
      ULONG (WINAPI *Release)(IRowsetFind *This);
      HRESULT (WINAPI *FindNextRow)(IRowsetFind *This,HCHAPTER hChapter,HACCESSOR hAccessor,void *pFindValue,DBCOMPAREOP CompareOp,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
    END_INTERFACE
  } IRowsetFindVtbl;
  struct IRowsetFind {
    CONST_VTBL struct IRowsetFindVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetFind_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetFind_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetFind_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetFind_FindNextRow(This,hChapter,hAccessor,pFindValue,CompareOp,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->FindNextRow(This,hChapter,hAccessor,pFindValue,CompareOp,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows)
#endif
#endif
  HRESULT WINAPI IRowsetFind_FindNextRow_Proxy(IRowsetFind *This,HCHAPTER hChapter,HACCESSOR hAccessor,void *pFindValue,DBCOMPAREOP CompareOp,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
  void __RPC_STUB IRowsetFind_FindNextRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowPosition_INTERFACE_DEFINED__
#define __IRowPosition_INTERFACE_DEFINED__
  typedef DWORD DBPOSITIONFLAGS;

  enum DBPOSITIONFLAGSENUM {
    DBPOSITION_OK = 0,
    DBPOSITION_NOROW,DBPOSITION_BOF,DBPOSITION_EOF
  };

  EXTERN_C const IID IID_IRowPosition;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowPosition : public IUnknown {
  public:
    virtual HRESULT WINAPI ClearRowPosition(void) = 0;
    virtual HRESULT WINAPI GetRowPosition(HCHAPTER *phChapter,HROW *phRow,DBPOSITIONFLAGS *pdwPositionFlags) = 0;
    virtual HRESULT WINAPI GetRowset(REFIID riid,IUnknown **ppRowset) = 0;
    virtual HRESULT WINAPI Initialize(IUnknown *pRowset) = 0;
    virtual HRESULT WINAPI SetRowPosition(HCHAPTER hChapter,HROW hRow,DBPOSITIONFLAGS dwPositionFlags) = 0;
  };
#else
  typedef struct IRowPositionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowPosition *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowPosition *This);
      ULONG (WINAPI *Release)(IRowPosition *This);
      HRESULT (WINAPI *ClearRowPosition)(IRowPosition *This);
      HRESULT (WINAPI *GetRowPosition)(IRowPosition *This,HCHAPTER *phChapter,HROW *phRow,DBPOSITIONFLAGS *pdwPositionFlags);
      HRESULT (WINAPI *GetRowset)(IRowPosition *This,REFIID riid,IUnknown **ppRowset);
      HRESULT (WINAPI *Initialize)(IRowPosition *This,IUnknown *pRowset);
      HRESULT (WINAPI *SetRowPosition)(IRowPosition *This,HCHAPTER hChapter,HROW hRow,DBPOSITIONFLAGS dwPositionFlags);
    END_INTERFACE
  } IRowPositionVtbl;
  struct IRowPosition {
    CONST_VTBL struct IRowPositionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowPosition_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowPosition_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowPosition_Release(This) (This)->lpVtbl->Release(This)
#define IRowPosition_ClearRowPosition(This) (This)->lpVtbl->ClearRowPosition(This)
#define IRowPosition_GetRowPosition(This,phChapter,phRow,pdwPositionFlags) (This)->lpVtbl->GetRowPosition(This,phChapter,phRow,pdwPositionFlags)
#define IRowPosition_GetRowset(This,riid,ppRowset) (This)->lpVtbl->GetRowset(This,riid,ppRowset)
#define IRowPosition_Initialize(This,pRowset) (This)->lpVtbl->Initialize(This,pRowset)
#define IRowPosition_SetRowPosition(This,hChapter,hRow,dwPositionFlags) (This)->lpVtbl->SetRowPosition(This,hChapter,hRow,dwPositionFlags)
#endif
#endif
  HRESULT WINAPI IRowPosition_RemoteClearRowPosition_Proxy(IRowPosition *This,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowPosition_RemoteClearRowPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowPosition_RemoteGetRowPosition_Proxy(IRowPosition *This,HCHAPTER *phChapter,HROW *phRow,DBPOSITIONFLAGS *pdwPositionFlags,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowPosition_RemoteGetRowPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowPosition_RemoteGetRowset_Proxy(IRowPosition *This,REFIID riid,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowPosition_RemoteGetRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowPosition_RemoteInitialize_Proxy(IRowPosition *This,IUnknown *pRowset,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowPosition_RemoteInitialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowPosition_RemoteSetRowPosition_Proxy(IRowPosition *This,HCHAPTER hChapter,HROW hRow,DBPOSITIONFLAGS dwPositionFlags,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowPosition_RemoteSetRowPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowPositionChange_INTERFACE_DEFINED__
#define __IRowPositionChange_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowPositionChange;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowPositionChange : public IUnknown {
  public:
    virtual HRESULT WINAPI OnRowPositionChange(DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny) = 0;
  };
#else
  typedef struct IRowPositionChangeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowPositionChange *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowPositionChange *This);
      ULONG (WINAPI *Release)(IRowPositionChange *This);
      HRESULT (WINAPI *OnRowPositionChange)(IRowPositionChange *This,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
    END_INTERFACE
  } IRowPositionChangeVtbl;
  struct IRowPositionChange {
    CONST_VTBL struct IRowPositionChangeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowPositionChange_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowPositionChange_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowPositionChange_Release(This) (This)->lpVtbl->Release(This)
#define IRowPositionChange_OnRowPositionChange(This,eReason,ePhase,fCantDeny) (This)->lpVtbl->OnRowPositionChange(This,eReason,ePhase,fCantDeny)
#endif
#endif
  HRESULT WINAPI IRowPositionChange_RemoteOnRowPositionChange_Proxy(IRowPositionChange *This,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowPositionChange_RemoteOnRowPositionChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IViewRowset_INTERFACE_DEFINED__
#define __IViewRowset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IViewRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IViewRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSpecification(REFIID riid,IUnknown **ppObject) = 0;
    virtual HRESULT WINAPI OpenViewRowset(IUnknown *pUnkOuter,REFIID riid,IUnknown **ppRowset) = 0;
  };
#else
  typedef struct IViewRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IViewRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IViewRowset *This);
      ULONG (WINAPI *Release)(IViewRowset *This);
      HRESULT (WINAPI *GetSpecification)(IViewRowset *This,REFIID riid,IUnknown **ppObject);
      HRESULT (WINAPI *OpenViewRowset)(IViewRowset *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppRowset);
    END_INTERFACE
  } IViewRowsetVtbl;
  struct IViewRowset {
    CONST_VTBL struct IViewRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IViewRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IViewRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IViewRowset_Release(This) (This)->lpVtbl->Release(This)
#define IViewRowset_GetSpecification(This,riid,ppObject) (This)->lpVtbl->GetSpecification(This,riid,ppObject)
#define IViewRowset_OpenViewRowset(This,pUnkOuter,riid,ppRowset) (This)->lpVtbl->OpenViewRowset(This,pUnkOuter,riid,ppRowset)
#endif
#endif
  HRESULT WINAPI IViewRowset_RemoteGetSpecification_Proxy(IViewRowset *This,REFIID riid,IUnknown **ppObject,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IViewRowset_RemoteGetSpecification_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IViewRowset_RemoteOpenViewRowset_Proxy(IViewRowset *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IViewRowset_RemoteOpenViewRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IViewChapter_INTERFACE_DEFINED__
#define __IViewChapter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IViewChapter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IViewChapter : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSpecification(REFIID riid,IUnknown **ppRowset) = 0;
    virtual HRESULT WINAPI OpenViewChapter(HCHAPTER hSource,HCHAPTER *phViewChapter) = 0;
  };
#else
  typedef struct IViewChapterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IViewChapter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IViewChapter *This);
      ULONG (WINAPI *Release)(IViewChapter *This);
      HRESULT (WINAPI *GetSpecification)(IViewChapter *This,REFIID riid,IUnknown **ppRowset);
      HRESULT (WINAPI *OpenViewChapter)(IViewChapter *This,HCHAPTER hSource,HCHAPTER *phViewChapter);
    END_INTERFACE
  } IViewChapterVtbl;
  struct IViewChapter {
    CONST_VTBL struct IViewChapterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IViewChapter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IViewChapter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IViewChapter_Release(This) (This)->lpVtbl->Release(This)
#define IViewChapter_GetSpecification(This,riid,ppRowset) (This)->lpVtbl->GetSpecification(This,riid,ppRowset)
#define IViewChapter_OpenViewChapter(This,hSource,phViewChapter) (This)->lpVtbl->OpenViewChapter(This,hSource,phViewChapter)
#endif
#endif
  HRESULT WINAPI IViewChapter_RemoteGetSpecification_Proxy(IViewChapter *This,REFIID riid,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IViewChapter_RemoteGetSpecification_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IViewChapter_RemoteOpenViewChapter_Proxy(IViewChapter *This,HCHAPTER hSource,HCHAPTER *phViewChapter,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IViewChapter_RemoteOpenViewChapter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IViewSort_INTERFACE_DEFINED__
#define __IViewSort_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IViewSort;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IViewSort : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSortOrder(DBORDINAL *pcValues,DBORDINAL *prgColumns[],DBSORT *prgOrders[]) = 0;
    virtual HRESULT WINAPI SetSortOrder(DBORDINAL cValues,const DBORDINAL rgColumns[],const DBSORT rgOrders[]) = 0;
  };
#else
  typedef struct IViewSortVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IViewSort *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IViewSort *This);
      ULONG (WINAPI *Release)(IViewSort *This);
      HRESULT (WINAPI *GetSortOrder)(IViewSort *This,DBORDINAL *pcValues,DBORDINAL *prgColumns[],DBSORT *prgOrders[]);
      HRESULT (WINAPI *SetSortOrder)(IViewSort *This,DBORDINAL cValues,const DBORDINAL rgColumns[],const DBSORT rgOrders[]);
    END_INTERFACE
  } IViewSortVtbl;
  struct IViewSort {
    CONST_VTBL struct IViewSortVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IViewSort_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IViewSort_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IViewSort_Release(This) (This)->lpVtbl->Release(This)
#define IViewSort_GetSortOrder(This,pcValues,prgColumns,prgOrders) (This)->lpVtbl->GetSortOrder(This,pcValues,prgColumns,prgOrders)
#define IViewSort_SetSortOrder(This,cValues,rgColumns,rgOrders) (This)->lpVtbl->SetSortOrder(This,cValues,rgColumns,rgOrders)
#endif
#endif
  HRESULT WINAPI IViewSort_RemoteGetSortOrder_Proxy(IViewSort *This,DBORDINAL *pcValues,DBORDINAL **prgColumns,DBSORT **prgOrders,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IViewSort_RemoteGetSortOrder_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IViewSort_RemoteSetSortOrder_Proxy(IViewSort *This,DBORDINAL cValues,const DBORDINAL *rgColumns,const DBSORT *rgOrders,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IViewSort_RemoteSetSortOrder_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IViewFilter_INTERFACE_DEFINED__
#define __IViewFilter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IViewFilter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IViewFilter : public IUnknown {
  public:
    virtual HRESULT WINAPI GetFilter(HACCESSOR hAccessor,DBCOUNTITEM *pcRows,DBCOMPAREOP *pCompareOps[],void *pCriteriaData) = 0;
    virtual HRESULT WINAPI GetFilterBindings(DBCOUNTITEM *pcBindings,DBBINDING **prgBindings) = 0;
    virtual HRESULT WINAPI SetFilter(HACCESSOR hAccessor,DBCOUNTITEM cRows,DBCOMPAREOP CompareOps[],void *pCriteriaData) = 0;
  };
#else
  typedef struct IViewFilterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IViewFilter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IViewFilter *This);
      ULONG (WINAPI *Release)(IViewFilter *This);
      HRESULT (WINAPI *GetFilter)(IViewFilter *This,HACCESSOR hAccessor,DBCOUNTITEM *pcRows,DBCOMPAREOP *pCompareOps[],void *pCriteriaData);
      HRESULT (WINAPI *GetFilterBindings)(IViewFilter *This,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings);
      HRESULT (WINAPI *SetFilter)(IViewFilter *This,HACCESSOR hAccessor,DBCOUNTITEM cRows,DBCOMPAREOP CompareOps[],void *pCriteriaData);
    END_INTERFACE
  } IViewFilterVtbl;
  struct IViewFilter {
    CONST_VTBL struct IViewFilterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IViewFilter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IViewFilter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IViewFilter_Release(This) (This)->lpVtbl->Release(This)
#define IViewFilter_GetFilter(This,hAccessor,pcRows,pCompareOps,pCriteriaData) (This)->lpVtbl->GetFilter(This,hAccessor,pcRows,pCompareOps,pCriteriaData)
#define IViewFilter_GetFilterBindings(This,pcBindings,prgBindings) (This)->lpVtbl->GetFilterBindings(This,pcBindings,prgBindings)
#define IViewFilter_SetFilter(This,hAccessor,cRows,CompareOps,pCriteriaData) (This)->lpVtbl->SetFilter(This,hAccessor,cRows,CompareOps,pCriteriaData)
#endif
#endif
  HRESULT WINAPI IViewFilter_GetFilter_Proxy(IViewFilter *This,HACCESSOR hAccessor,DBCOUNTITEM *pcRows,DBCOMPAREOP *pCompareOps[],void *pCriteriaData);
  void __RPC_STUB IViewFilter_GetFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IViewFilter_RemoteGetFilterBindings_Proxy(IViewFilter *This,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IViewFilter_RemoteGetFilterBindings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IViewFilter_SetFilter_Proxy(IViewFilter *This,HACCESSOR hAccessor,DBCOUNTITEM cRows,DBCOMPAREOP CompareOps[],void *pCriteriaData);
  void __RPC_STUB IViewFilter_SetFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetView_INTERFACE_DEFINED__
#define __IRowsetView_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetView;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetView : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateView(IUnknown *pUnkOuter,REFIID riid,IUnknown **ppView) = 0;
    virtual HRESULT WINAPI GetView(HCHAPTER hChapter,REFIID riid,HCHAPTER *phChapterSource,IUnknown **ppView) = 0;
  };
#else
  typedef struct IRowsetViewVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetView *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetView *This);
      ULONG (WINAPI *Release)(IRowsetView *This);
      HRESULT (WINAPI *CreateView)(IRowsetView *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppView);
      HRESULT (WINAPI *GetView)(IRowsetView *This,HCHAPTER hChapter,REFIID riid,HCHAPTER *phChapterSource,IUnknown **ppView);
    END_INTERFACE
  } IRowsetViewVtbl;
  struct IRowsetView {
    CONST_VTBL struct IRowsetViewVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetView_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetView_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetView_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetView_CreateView(This,pUnkOuter,riid,ppView) (This)->lpVtbl->CreateView(This,pUnkOuter,riid,ppView)
#define IRowsetView_GetView(This,hChapter,riid,phChapterSource,ppView) (This)->lpVtbl->GetView(This,hChapter,riid,phChapterSource,ppView)
#endif
#endif
  HRESULT WINAPI IRowsetView_RemoteCreateView_Proxy(IRowsetView *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppView,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowsetView_RemoteCreateView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetView_RemoteGetView_Proxy(IRowsetView *This,HCHAPTER hChapter,REFIID riid,HCHAPTER *phChapterSource,IUnknown **ppView,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowsetView_RemoteGetView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifdef deprecated
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0282_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0282_v0_0_s_ifspec;
#ifndef __IRowsetExactScroll_INTERFACE_DEFINED__
#define __IRowsetExactScroll_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetExactScroll;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetExactScroll : public IRowsetScroll {
  public:
    virtual HRESULT WINAPI GetExactPosition(HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark,DBCOUNTITEM *pulPosition,DBCOUNTITEM *pcRows) = 0;
  };
#else
  typedef struct IRowsetExactScrollVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetExactScroll *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetExactScroll *This);
      ULONG (WINAPI *Release)(IRowsetExactScroll *This);
      HRESULT (WINAPI *AddRefRows)(IRowsetExactScroll *This,DBCOUNTITEM cRows,const HROW rghRows[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *GetData)(IRowsetExactScroll *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *GetNextRows)(IRowsetExactScroll *This,HCHAPTER hReserved,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *ReleaseRows)(IRowsetExactScroll *This,DBCOUNTITEM cRows,const HROW rghRows[],DBROWOPTIONS rgRowOptions[],DBREFCOUNT rgRefCounts[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *RestartPosition)(IRowsetExactScroll *This,HCHAPTER hReserved);
      HRESULT (WINAPI *Compare)(IRowsetExactScroll *This,HCHAPTER hReserved,DBBKMARK cbBookmark1,const BYTE *pBookmark1,DBBKMARK cbBookmark2,const BYTE *pBookmark2,DBCOMPARE *pComparison);
      HRESULT (WINAPI *GetRowsAt)(IRowsetExactScroll *This,HWATCHREGION hReserved1,HCHAPTER hReserved2,DBBKMARK cbBookmark,const BYTE *pBookmark,DBROWOFFSET lRowsOffset,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *GetRowsByBookmark)(IRowsetExactScroll *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],HROW rghRows[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *Hash)(IRowsetExactScroll *This,HCHAPTER hReserved,DBBKMARK cBookmarks,const DBBKMARK rgcbBookmarks[],const BYTE *rgpBookmarks[],DBHASHVALUE rgHashedValues[],DBROWSTATUS rgBookmarkStatus[]);
      HRESULT (WINAPI *GetApproximatePosition)(IRowsetExactScroll *This,HCHAPTER hReserved,DBBKMARK cbBookmark,const BYTE *pBookmark,DBCOUNTITEM *pulPosition,DBCOUNTITEM *pcRows);
      HRESULT (WINAPI *GetRowsAtRatio)(IRowsetExactScroll *This,HWATCHREGION hReserved1,HCHAPTER hReserved2,DBCOUNTITEM ulNumerator,DBCOUNTITEM ulDenominator,DBROWCOUNT cRows,DBCOUNTITEM *pcRowsObtained,HROW **prghRows);
      HRESULT (WINAPI *GetExactPosition)(IRowsetExactScroll *This,HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark,DBCOUNTITEM *pulPosition,DBCOUNTITEM *pcRows);
    END_INTERFACE
  } IRowsetExactScrollVtbl;
  struct IRowsetExactScroll {
    CONST_VTBL struct IRowsetExactScrollVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetExactScroll_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetExactScroll_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetExactScroll_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetExactScroll_AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus) (This)->lpVtbl->AddRefRows(This,cRows,rghRows,rgRefCounts,rgRowStatus)
#define IRowsetExactScroll_GetData(This,hRow,hAccessor,pData) (This)->lpVtbl->GetData(This,hRow,hAccessor,pData)
#define IRowsetExactScroll_GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetNextRows(This,hReserved,lRowsOffset,cRows,pcRowsObtained,prghRows)
#define IRowsetExactScroll_ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus) (This)->lpVtbl->ReleaseRows(This,cRows,rghRows,rgRowOptions,rgRefCounts,rgRowStatus)
#define IRowsetExactScroll_RestartPosition(This,hReserved) (This)->lpVtbl->RestartPosition(This,hReserved)
#define IRowsetExactScroll_Compare(This,hReserved,cbBookmark1,pBookmark1,cbBookmark2,pBookmark2,pComparison) (This)->lpVtbl->Compare(This,hReserved,cbBookmark1,pBookmark1,cbBookmark2,pBookmark2,pComparison)
#define IRowsetExactScroll_GetRowsAt(This,hReserved1,hReserved2,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetRowsAt(This,hReserved1,hReserved2,cbBookmark,pBookmark,lRowsOffset,cRows,pcRowsObtained,prghRows)
#define IRowsetExactScroll_GetRowsByBookmark(This,hReserved,cRows,rgcbBookmarks,rgpBookmarks,rghRows,rgRowStatus) (This)->lpVtbl->GetRowsByBookmark(This,hReserved,cRows,rgcbBookmarks,rgpBookmarks,rghRows,rgRowStatus)
#define IRowsetExactScroll_Hash(This,hReserved,cBookmarks,rgcbBookmarks,rgpBookmarks,rgHashedValues,rgBookmarkStatus) (This)->lpVtbl->Hash(This,hReserved,cBookmarks,rgcbBookmarks,rgpBookmarks,rgHashedValues,rgBookmarkStatus)
#define IRowsetExactScroll_GetApproximatePosition(This,hReserved,cbBookmark,pBookmark,pulPosition,pcRows) (This)->lpVtbl->GetApproximatePosition(This,hReserved,cbBookmark,pBookmark,pulPosition,pcRows)
#define IRowsetExactScroll_GetRowsAtRatio(This,hReserved1,hReserved2,ulNumerator,ulDenominator,cRows,pcRowsObtained,prghRows) (This)->lpVtbl->GetRowsAtRatio(This,hReserved1,hReserved2,ulNumerator,ulDenominator,cRows,pcRowsObtained,prghRows)
#define IRowsetExactScroll_GetExactPosition(This,hChapter,cbBookmark,pBookmark,pulPosition,pcRows) (This)->lpVtbl->GetExactPosition(This,hChapter,cbBookmark,pBookmark,pulPosition,pcRows)
#endif
#endif
  HRESULT WINAPI IRowsetExactScroll_GetExactPosition_Proxy(IRowsetExactScroll *This,HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark,DBCOUNTITEM *pulPosition,DBCOUNTITEM *pcRows);
  void __RPC_STUB IRowsetExactScroll_GetExactPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0283_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0283_v0_0_s_ifspec;
#ifndef __IRowsetChange_INTERFACE_DEFINED__
#define __IRowsetChange_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetChange;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetChange : public IUnknown {
  public:
    virtual HRESULT WINAPI DeleteRows(HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBROWSTATUS rgRowStatus[]) = 0;
    virtual HRESULT WINAPI SetData(HROW hRow,HACCESSOR hAccessor,void *pData) = 0;
    virtual HRESULT WINAPI InsertRow(HCHAPTER hReserved,HACCESSOR hAccessor,void *pData,HROW *phRow) = 0;
  };
#else
  typedef struct IRowsetChangeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetChange *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetChange *This);
      ULONG (WINAPI *Release)(IRowsetChange *This);
      HRESULT (WINAPI *DeleteRows)(IRowsetChange *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *SetData)(IRowsetChange *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *InsertRow)(IRowsetChange *This,HCHAPTER hReserved,HACCESSOR hAccessor,void *pData,HROW *phRow);
    END_INTERFACE
  } IRowsetChangeVtbl;
  struct IRowsetChange {
    CONST_VTBL struct IRowsetChangeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetChange_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetChange_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetChange_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetChange_DeleteRows(This,hReserved,cRows,rghRows,rgRowStatus) (This)->lpVtbl->DeleteRows(This,hReserved,cRows,rghRows,rgRowStatus)
#define IRowsetChange_SetData(This,hRow,hAccessor,pData) (This)->lpVtbl->SetData(This,hRow,hAccessor,pData)
#define IRowsetChange_InsertRow(This,hReserved,hAccessor,pData,phRow) (This)->lpVtbl->InsertRow(This,hReserved,hAccessor,pData,phRow)
#endif
#endif
  HRESULT WINAPI IRowsetChange_DeleteRows_Proxy(IRowsetChange *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBROWSTATUS rgRowStatus[]);
  void __RPC_STUB IRowsetChange_DeleteRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetChange_SetData_Proxy(IRowsetChange *This,HROW hRow,HACCESSOR hAccessor,void *pData);
  void __RPC_STUB IRowsetChange_SetData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetChange_InsertRow_Proxy(IRowsetChange *This,HCHAPTER hReserved,HACCESSOR hAccessor,void *pData,HROW *phRow);
  void __RPC_STUB IRowsetChange_InsertRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetUpdate_INTERFACE_DEFINED__
#define __IRowsetUpdate_INTERFACE_DEFINED__
  typedef DWORD DBPENDINGSTATUS;
  enum DBPENDINGSTATUSENUM {
    DBPENDINGSTATUS_NEW = 0x1,DBPENDINGSTATUS_CHANGED = 0x2,DBPENDINGSTATUS_DELETED = 0x4,DBPENDINGSTATUS_UNCHANGED = 0x8,
    DBPENDINGSTATUS_INVALIDROW = 0x10
  };

  EXTERN_C const IID IID_IRowsetUpdate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetUpdate : public IRowsetChange {
  public:
    virtual HRESULT WINAPI GetOriginalData(HROW hRow,HACCESSOR hAccessor,void *pData) = 0;
    virtual HRESULT WINAPI GetPendingRows(HCHAPTER hReserved,DBPENDINGSTATUS dwRowStatus,DBCOUNTITEM *pcPendingRows,HROW **prgPendingRows,DBPENDINGSTATUS **prgPendingStatus) = 0;
    virtual HRESULT WINAPI GetRowStatus(HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBPENDINGSTATUS rgPendingStatus[]) = 0;
    virtual HRESULT WINAPI Undo(HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRowsUndone,HROW **prgRowsUndone,DBROWSTATUS **prgRowStatus) = 0;
    virtual HRESULT WINAPI Update(HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRows,HROW **prgRows,DBROWSTATUS **prgRowStatus) = 0;
  };
#else
  typedef struct IRowsetUpdateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetUpdate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetUpdate *This);
      ULONG (WINAPI *Release)(IRowsetUpdate *This);
      HRESULT (WINAPI *DeleteRows)(IRowsetUpdate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBROWSTATUS rgRowStatus[]);
      HRESULT (WINAPI *SetData)(IRowsetUpdate *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *InsertRow)(IRowsetUpdate *This,HCHAPTER hReserved,HACCESSOR hAccessor,void *pData,HROW *phRow);
      HRESULT (WINAPI *GetOriginalData)(IRowsetUpdate *This,HROW hRow,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *GetPendingRows)(IRowsetUpdate *This,HCHAPTER hReserved,DBPENDINGSTATUS dwRowStatus,DBCOUNTITEM *pcPendingRows,HROW **prgPendingRows,DBPENDINGSTATUS **prgPendingStatus);
      HRESULT (WINAPI *GetRowStatus)(IRowsetUpdate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBPENDINGSTATUS rgPendingStatus[]);
      HRESULT (WINAPI *Undo)(IRowsetUpdate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRowsUndone,HROW **prgRowsUndone,DBROWSTATUS **prgRowStatus);
      HRESULT (WINAPI *Update)(IRowsetUpdate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRows,HROW **prgRows,DBROWSTATUS **prgRowStatus);
    END_INTERFACE
  } IRowsetUpdateVtbl;
  struct IRowsetUpdate {
    CONST_VTBL struct IRowsetUpdateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetUpdate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetUpdate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetUpdate_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetUpdate_DeleteRows(This,hReserved,cRows,rghRows,rgRowStatus) (This)->lpVtbl->DeleteRows(This,hReserved,cRows,rghRows,rgRowStatus)
#define IRowsetUpdate_SetData(This,hRow,hAccessor,pData) (This)->lpVtbl->SetData(This,hRow,hAccessor,pData)
#define IRowsetUpdate_InsertRow(This,hReserved,hAccessor,pData,phRow) (This)->lpVtbl->InsertRow(This,hReserved,hAccessor,pData,phRow)
#define IRowsetUpdate_GetOriginalData(This,hRow,hAccessor,pData) (This)->lpVtbl->GetOriginalData(This,hRow,hAccessor,pData)
#define IRowsetUpdate_GetPendingRows(This,hReserved,dwRowStatus,pcPendingRows,prgPendingRows,prgPendingStatus) (This)->lpVtbl->GetPendingRows(This,hReserved,dwRowStatus,pcPendingRows,prgPendingRows,prgPendingStatus)
#define IRowsetUpdate_GetRowStatus(This,hReserved,cRows,rghRows,rgPendingStatus) (This)->lpVtbl->GetRowStatus(This,hReserved,cRows,rghRows,rgPendingStatus)
#define IRowsetUpdate_Undo(This,hReserved,cRows,rghRows,pcRowsUndone,prgRowsUndone,prgRowStatus) (This)->lpVtbl->Undo(This,hReserved,cRows,rghRows,pcRowsUndone,prgRowsUndone,prgRowStatus)
#define IRowsetUpdate_Update(This,hReserved,cRows,rghRows,pcRows,prgRows,prgRowStatus) (This)->lpVtbl->Update(This,hReserved,cRows,rghRows,pcRows,prgRows,prgRowStatus)
#endif
#endif
  HRESULT WINAPI IRowsetUpdate_GetOriginalData_Proxy(IRowsetUpdate *This,HROW hRow,HACCESSOR hAccessor,void *pData);
  void __RPC_STUB IRowsetUpdate_GetOriginalData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetUpdate_GetPendingRows_Proxy(IRowsetUpdate *This,HCHAPTER hReserved,DBPENDINGSTATUS dwRowStatus,DBCOUNTITEM *pcPendingRows,HROW **prgPendingRows,DBPENDINGSTATUS **prgPendingStatus);
  void __RPC_STUB IRowsetUpdate_GetPendingRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetUpdate_GetRowStatus_Proxy(IRowsetUpdate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBPENDINGSTATUS rgPendingStatus[]);
  void __RPC_STUB IRowsetUpdate_GetRowStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetUpdate_Undo_Proxy(IRowsetUpdate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRowsUndone,HROW **prgRowsUndone,DBROWSTATUS **prgRowStatus);
  void __RPC_STUB IRowsetUpdate_Undo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetUpdate_Update_Proxy(IRowsetUpdate *This,HCHAPTER hReserved,DBCOUNTITEM cRows,const HROW rghRows[],DBCOUNTITEM *pcRows,HROW **prgRows,DBROWSTATUS **prgRowStatus);
  void __RPC_STUB IRowsetUpdate_Update_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetIdentity_INTERFACE_DEFINED__
#define __IRowsetIdentity_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetIdentity;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetIdentity : public IUnknown {
  public:
    virtual HRESULT WINAPI IsSameRow(HROW hThisRow,HROW hThatRow) = 0;
  };
#else
  typedef struct IRowsetIdentityVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetIdentity *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetIdentity *This);
      ULONG (WINAPI *Release)(IRowsetIdentity *This);
      HRESULT (WINAPI *IsSameRow)(IRowsetIdentity *This,HROW hThisRow,HROW hThatRow);
    END_INTERFACE
  } IRowsetIdentityVtbl;
  struct IRowsetIdentity {
    CONST_VTBL struct IRowsetIdentityVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetIdentity_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetIdentity_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetIdentity_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetIdentity_IsSameRow(This,hThisRow,hThatRow) (This)->lpVtbl->IsSameRow(This,hThisRow,hThatRow)
#endif
#endif
  HRESULT WINAPI IRowsetIdentity_RemoteIsSameRow_Proxy(IRowsetIdentity *This,HROW hThisRow,HROW hThatRow,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IRowsetIdentity_RemoteIsSameRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetNotify_INTERFACE_DEFINED__
#define __IRowsetNotify_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI OnFieldChange(IRowset *pRowset,HROW hRow,DBORDINAL cColumns,DBORDINAL rgColumns[],DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny) = 0;
    virtual HRESULT WINAPI OnRowChange(IRowset *pRowset,DBCOUNTITEM cRows,const HROW rghRows[],DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny) = 0;
    virtual HRESULT WINAPI OnRowsetChange(IRowset *pRowset,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny) = 0;
  };
#else
  typedef struct IRowsetNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetNotify *This);
      ULONG (WINAPI *Release)(IRowsetNotify *This);
      HRESULT (WINAPI *OnFieldChange)(IRowsetNotify *This,IRowset *pRowset,HROW hRow,DBORDINAL cColumns,DBORDINAL rgColumns[],DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
      HRESULT (WINAPI *OnRowChange)(IRowsetNotify *This,IRowset *pRowset,DBCOUNTITEM cRows,const HROW rghRows[],DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
      HRESULT (WINAPI *OnRowsetChange)(IRowsetNotify *This,IRowset *pRowset,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
    END_INTERFACE
  } IRowsetNotifyVtbl;
  struct IRowsetNotify {
    CONST_VTBL struct IRowsetNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetNotify_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetNotify_OnFieldChange(This,pRowset,hRow,cColumns,rgColumns,eReason,ePhase,fCantDeny) (This)->lpVtbl->OnFieldChange(This,pRowset,hRow,cColumns,rgColumns,eReason,ePhase,fCantDeny)
#define IRowsetNotify_OnRowChange(This,pRowset,cRows,rghRows,eReason,ePhase,fCantDeny) (This)->lpVtbl->OnRowChange(This,pRowset,cRows,rghRows,eReason,ePhase,fCantDeny)
#define IRowsetNotify_OnRowsetChange(This,pRowset,eReason,ePhase,fCantDeny) (This)->lpVtbl->OnRowsetChange(This,pRowset,eReason,ePhase,fCantDeny)
#endif
#endif
  HRESULT WINAPI IRowsetNotify_RemoteOnFieldChange_Proxy(IRowsetNotify *This,IRowset *pRowset,HROW hRow,DBORDINAL cColumns,DBORDINAL *rgColumns,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  void __RPC_STUB IRowsetNotify_RemoteOnFieldChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetNotify_RemoteOnRowChange_Proxy(IRowsetNotify *This,IRowset *pRowset,DBCOUNTITEM cRows,const HROW *rghRows,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  void __RPC_STUB IRowsetNotify_RemoteOnRowChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetNotify_RemoteOnRowsetChange_Proxy(IRowsetNotify *This,IRowset *pRowset,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  void __RPC_STUB IRowsetNotify_RemoteOnRowsetChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetIndex_INTERFACE_DEFINED__
#define __IRowsetIndex_INTERFACE_DEFINED__
  typedef DWORD DBSEEK;

  enum DBSEEKENUM {
    DBSEEK_INVALID = 0,DBSEEK_FIRSTEQ = 0x1,DBSEEK_LASTEQ = 0x2,DBSEEK_AFTEREQ = 0x4,DBSEEK_AFTER = 0x8,DBSEEK_BEFOREEQ = 0x10,
    DBSEEK_BEFORE = 0x20
  };
#define DBSEEK_GE DBSEEK_AFTEREQ
#define DBSEEK_GT DBSEEK_AFTER
#define DBSEEK_LE DBSEEK_BEFOREEQ
#define DBSEEK_LT DBSEEK_BEFORE
  typedef DWORD DBRANGE;

  enum DBRANGEENUM {
    DBRANGE_INCLUSIVESTART = 0,DBRANGE_INCLUSIVEEND = 0,DBRANGE_EXCLUSIVESTART = 0x1,DBRANGE_EXCLUSIVEEND = 0x2,
    DBRANGE_EXCLUDENULLS = 0x4,DBRANGE_PREFIX = 0x8,DBRANGE_MATCH = 0x10
  };

#if (OLEDBVER >= 0x0200)

  enum DBRANGEENUM20 {
    DBRANGE_MATCH_N_SHIFT = 0x18,DBRANGE_MATCH_N_MASK = 0xff
  };
#endif

  EXTERN_C const IID IID_IRowsetIndex;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetIndex : public IUnknown {
  public:
    virtual HRESULT WINAPI GetIndexInfo(DBORDINAL *pcKeyColumns,DBINDEXCOLUMNDESC **prgIndexColumnDesc,ULONG *pcIndexPropertySets,DBPROPSET **prgIndexPropertySets) = 0;
    virtual HRESULT WINAPI Seek(HACCESSOR hAccessor,DBORDINAL cKeyValues,void *pData,DBSEEK dwSeekOptions) = 0;
    virtual HRESULT WINAPI SetRange(HACCESSOR hAccessor,DBORDINAL cStartKeyColumns,void *pStartData,DBORDINAL cEndKeyColumns,void *pEndData,DBRANGE dwRangeOptions) = 0;
  };
#else
  typedef struct IRowsetIndexVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetIndex *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetIndex *This);
      ULONG (WINAPI *Release)(IRowsetIndex *This);
      HRESULT (WINAPI *GetIndexInfo)(IRowsetIndex *This,DBORDINAL *pcKeyColumns,DBINDEXCOLUMNDESC **prgIndexColumnDesc,ULONG *pcIndexPropertySets,DBPROPSET **prgIndexPropertySets);
      HRESULT (WINAPI *Seek)(IRowsetIndex *This,HACCESSOR hAccessor,DBORDINAL cKeyValues,void *pData,DBSEEK dwSeekOptions);
      HRESULT (WINAPI *SetRange)(IRowsetIndex *This,HACCESSOR hAccessor,DBORDINAL cStartKeyColumns,void *pStartData,DBORDINAL cEndKeyColumns,void *pEndData,DBRANGE dwRangeOptions);
    END_INTERFACE
  } IRowsetIndexVtbl;
  struct IRowsetIndex {
    CONST_VTBL struct IRowsetIndexVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetIndex_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetIndex_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetIndex_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetIndex_GetIndexInfo(This,pcKeyColumns,prgIndexColumnDesc,pcIndexPropertySets,prgIndexPropertySets) (This)->lpVtbl->GetIndexInfo(This,pcKeyColumns,prgIndexColumnDesc,pcIndexPropertySets,prgIndexPropertySets)
#define IRowsetIndex_Seek(This,hAccessor,cKeyValues,pData,dwSeekOptions) (This)->lpVtbl->Seek(This,hAccessor,cKeyValues,pData,dwSeekOptions)
#define IRowsetIndex_SetRange(This,hAccessor,cStartKeyColumns,pStartData,cEndKeyColumns,pEndData,dwRangeOptions) (This)->lpVtbl->SetRange(This,hAccessor,cStartKeyColumns,pStartData,cEndKeyColumns,pEndData,dwRangeOptions)
#endif
#endif
  HRESULT WINAPI IRowsetIndex_GetIndexInfo_Proxy(IRowsetIndex *This,DBORDINAL *pcKeyColumns,DBINDEXCOLUMNDESC **prgIndexColumnDesc,ULONG *pcIndexPropertySets,DBPROPSET **prgIndexPropertySets);
  void __RPC_STUB IRowsetIndex_GetIndexInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetIndex_Seek_Proxy(IRowsetIndex *This,HACCESSOR hAccessor,DBORDINAL cKeyValues,void *pData,DBSEEK dwSeekOptions);
  void __RPC_STUB IRowsetIndex_Seek_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetIndex_SetRange_Proxy(IRowsetIndex *This,HACCESSOR hAccessor,DBORDINAL cStartKeyColumns,void *pStartData,DBORDINAL cEndKeyColumns,void *pEndData,DBRANGE dwRangeOptions);
  void __RPC_STUB IRowsetIndex_SetRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommand_INTERFACE_DEFINED__
#define __ICommand_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICommand;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommand : public IUnknown {
  public:
    virtual HRESULT WINAPI Cancel(void) = 0;
    virtual HRESULT WINAPI Execute(IUnknown *pUnkOuter,REFIID riid,DBPARAMS *pParams,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset) = 0;
    virtual HRESULT WINAPI GetDBSession(REFIID riid,IUnknown **ppSession) = 0;
  };
#else
  typedef struct ICommandVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommand *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommand *This);
      ULONG (WINAPI *Release)(ICommand *This);
      HRESULT (WINAPI *Cancel)(ICommand *This);
      HRESULT (WINAPI *Execute)(ICommand *This,IUnknown *pUnkOuter,REFIID riid,DBPARAMS *pParams,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset);
      HRESULT (WINAPI *GetDBSession)(ICommand *This,REFIID riid,IUnknown **ppSession);
    END_INTERFACE
  } ICommandVtbl;
  struct ICommand {
    CONST_VTBL struct ICommandVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommand_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommand_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommand_Release(This) (This)->lpVtbl->Release(This)
#define ICommand_Cancel(This) (This)->lpVtbl->Cancel(This)
#define ICommand_Execute(This,pUnkOuter,riid,pParams,pcRowsAffected,ppRowset) (This)->lpVtbl->Execute(This,pUnkOuter,riid,pParams,pcRowsAffected,ppRowset)
#define ICommand_GetDBSession(This,riid,ppSession) (This)->lpVtbl->GetDBSession(This,riid,ppSession)
#endif
#endif
  HRESULT WINAPI ICommand_RemoteCancel_Proxy(ICommand *This,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommand_RemoteCancel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommand_RemoteExecute_Proxy(ICommand *This,IUnknown *pUnkOuter,REFIID riid,HACCESSOR hAccessor,DB_UPARAMS cParamSets,GUID *pGuid,ULONG ulGuidOffset,RMTPACK *pInputParams,RMTPACK *pOutputParams,DBCOUNTITEM cBindings,DBBINDING *rgBindings,DBSTATUS *rgStatus,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset);
  void __RPC_STUB ICommand_RemoteExecute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommand_RemoteGetDBSession_Proxy(ICommand *This,REFIID riid,IUnknown **ppSession,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommand_RemoteGetDBSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMultipleResults_INTERFACE_DEFINED__
#define __IMultipleResults_INTERFACE_DEFINED__
  typedef DB_LRESERVE DBRESULTFLAG;

  enum DBRESULTFLAGENUM {
    DBRESULTFLAG_DEFAULT = 0,DBRESULTFLAG_ROWSET = 1,DBRESULTFLAG_ROW = 2
  };

  EXTERN_C const IID IID_IMultipleResults;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMultipleResults : public IUnknown {
  public:
    virtual HRESULT WINAPI GetResult(IUnknown *pUnkOuter,DBRESULTFLAG lResultFlag,REFIID riid,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset) = 0;
  };
#else
  typedef struct IMultipleResultsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMultipleResults *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMultipleResults *This);
      ULONG (WINAPI *Release)(IMultipleResults *This);
      HRESULT (WINAPI *GetResult)(IMultipleResults *This,IUnknown *pUnkOuter,DBRESULTFLAG lResultFlag,REFIID riid,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset);
    END_INTERFACE
  } IMultipleResultsVtbl;
  struct IMultipleResults {
    CONST_VTBL struct IMultipleResultsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMultipleResults_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMultipleResults_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMultipleResults_Release(This) (This)->lpVtbl->Release(This)
#define IMultipleResults_GetResult(This,pUnkOuter,lResultFlag,riid,pcRowsAffected,ppRowset) (This)->lpVtbl->GetResult(This,pUnkOuter,lResultFlag,riid,pcRowsAffected,ppRowset)
#endif
#endif
  HRESULT WINAPI IMultipleResults_RemoteGetResult_Proxy(IMultipleResults *This,IUnknown *pUnkOuter,DBRESULTFLAG lResultFlag,REFIID riid,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IMultipleResults_RemoteGetResult_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IConvertType_INTERFACE_DEFINED__
#define __IConvertType_INTERFACE_DEFINED__
  typedef DWORD DBCONVERTFLAGS;

  enum DBCONVERTFLAGSENUM {
    DBCONVERTFLAGS_COLUMN = 0,DBCONVERTFLAGS_PARAMETER = 0x1
  };
#if (OLEDBVER >= 0x0200)
  enum DBCONVERTFLAGSENUM20 {
    DBCONVERTFLAGS_ISLONG = 0x2,DBCONVERTFLAGS_ISFIXEDLENGTH = 0x4,DBCONVERTFLAGS_FROMVARIANT = 0x8
  };
#endif

  EXTERN_C const IID IID_IConvertType;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IConvertType : public IUnknown {
  public:
    virtual HRESULT WINAPI CanConvert(DBTYPE wFromType,DBTYPE wToType,DBCONVERTFLAGS dwConvertFlags) = 0;
  };
#else
  typedef struct IConvertTypeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IConvertType *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IConvertType *This);
      ULONG (WINAPI *Release)(IConvertType *This);
      HRESULT (WINAPI *CanConvert)(IConvertType *This,DBTYPE wFromType,DBTYPE wToType,DBCONVERTFLAGS dwConvertFlags);
    END_INTERFACE
  } IConvertTypeVtbl;
  struct IConvertType {
    CONST_VTBL struct IConvertTypeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IConvertType_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IConvertType_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IConvertType_Release(This) (This)->lpVtbl->Release(This)
#define IConvertType_CanConvert(This,wFromType,wToType,dwConvertFlags) (This)->lpVtbl->CanConvert(This,wFromType,wToType,dwConvertFlags)
#endif
#endif
  HRESULT WINAPI IConvertType_RemoteCanConvert_Proxy(IConvertType *This,DBTYPE wFromType,DBTYPE wToType,DBCONVERTFLAGS dwConvertFlags,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IConvertType_RemoteCanConvert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommandPrepare_INTERFACE_DEFINED__
#define __ICommandPrepare_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICommandPrepare;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandPrepare : public IUnknown {
  public:
    virtual HRESULT WINAPI Prepare(ULONG cExpectedRuns) = 0;
    virtual HRESULT WINAPI Unprepare(void) = 0;
  };
#else
  typedef struct ICommandPrepareVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandPrepare *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandPrepare *This);
      ULONG (WINAPI *Release)(ICommandPrepare *This);
      HRESULT (WINAPI *Prepare)(ICommandPrepare *This,ULONG cExpectedRuns);
      HRESULT (WINAPI *Unprepare)(ICommandPrepare *This);
    END_INTERFACE
  } ICommandPrepareVtbl;
  struct ICommandPrepare {
    CONST_VTBL struct ICommandPrepareVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandPrepare_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandPrepare_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandPrepare_Release(This) (This)->lpVtbl->Release(This)
#define ICommandPrepare_Prepare(This,cExpectedRuns) (This)->lpVtbl->Prepare(This,cExpectedRuns)
#define ICommandPrepare_Unprepare(This) (This)->lpVtbl->Unprepare(This)
#endif
#endif
  HRESULT WINAPI ICommandPrepare_RemotePrepare_Proxy(ICommandPrepare *This,ULONG cExpectedRuns,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandPrepare_RemotePrepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandPrepare_RemoteUnprepare_Proxy(ICommandPrepare *This,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandPrepare_RemoteUnprepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommandProperties_INTERFACE_DEFINED__
#define __ICommandProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICommandProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI GetProperties(const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets) = 0;
    virtual HRESULT WINAPI SetProperties(ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
  };
#else
  typedef struct ICommandPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandProperties *This);
      ULONG (WINAPI *Release)(ICommandProperties *This);
      HRESULT (WINAPI *GetProperties)(ICommandProperties *This,const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
      HRESULT (WINAPI *SetProperties)(ICommandProperties *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
    END_INTERFACE
  } ICommandPropertiesVtbl;
  struct ICommandProperties {
    CONST_VTBL struct ICommandPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandProperties_Release(This) (This)->lpVtbl->Release(This)
#define ICommandProperties_GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets) (This)->lpVtbl->GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets)
#define ICommandProperties_SetProperties(This,cPropertySets,rgPropertySets) (This)->lpVtbl->SetProperties(This,cPropertySets,rgPropertySets)
#endif
#endif
  HRESULT WINAPI ICommandProperties_RemoteGetProperties_Proxy(ICommandProperties *This,const ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandProperties_RemoteGetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandProperties_RemoteSetProperties_Proxy(ICommandProperties *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandProperties_RemoteSetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommandText_INTERFACE_DEFINED__
#define __ICommandText_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICommandText;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandText : public ICommand {
  public:
    virtual HRESULT WINAPI GetCommandText(GUID *pguidDialect,LPOLESTR *ppwszCommand) = 0;
    virtual HRESULT WINAPI SetCommandText(REFGUID rguidDialect,LPCOLESTR pwszCommand) = 0;
  };
#else
  typedef struct ICommandTextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandText *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandText *This);
      ULONG (WINAPI *Release)(ICommandText *This);
      HRESULT (WINAPI *Cancel)(ICommandText *This);
      HRESULT (WINAPI *Execute)(ICommandText *This,IUnknown *pUnkOuter,REFIID riid,DBPARAMS *pParams,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset);
      HRESULT (WINAPI *GetDBSession)(ICommandText *This,REFIID riid,IUnknown **ppSession);
      HRESULT (WINAPI *GetCommandText)(ICommandText *This,GUID *pguidDialect,LPOLESTR *ppwszCommand);
      HRESULT (WINAPI *SetCommandText)(ICommandText *This,REFGUID rguidDialect,LPCOLESTR pwszCommand);
    END_INTERFACE
  } ICommandTextVtbl;
  struct ICommandText {
    CONST_VTBL struct ICommandTextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandText_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandText_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandText_Release(This) (This)->lpVtbl->Release(This)
#define ICommandText_Cancel(This) (This)->lpVtbl->Cancel(This)
#define ICommandText_Execute(This,pUnkOuter,riid,pParams,pcRowsAffected,ppRowset) (This)->lpVtbl->Execute(This,pUnkOuter,riid,pParams,pcRowsAffected,ppRowset)
#define ICommandText_GetDBSession(This,riid,ppSession) (This)->lpVtbl->GetDBSession(This,riid,ppSession)
#define ICommandText_GetCommandText(This,pguidDialect,ppwszCommand) (This)->lpVtbl->GetCommandText(This,pguidDialect,ppwszCommand)
#define ICommandText_SetCommandText(This,rguidDialect,pwszCommand) (This)->lpVtbl->SetCommandText(This,rguidDialect,pwszCommand)
#endif
#endif
  HRESULT WINAPI ICommandText_RemoteGetCommandText_Proxy(ICommandText *This,GUID *pguidDialect,LPOLESTR *ppwszCommand,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandText_RemoteGetCommandText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandText_RemoteSetCommandText_Proxy(ICommandText *This,REFGUID rguidDialect,LPCOLESTR pwszCommand,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandText_RemoteSetCommandText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommandWithParameters_INTERFACE_DEFINED__
#define __ICommandWithParameters_INTERFACE_DEFINED__
  typedef struct tagDBPARAMBINDINFO {
    LPOLESTR pwszDataSourceType;
    LPOLESTR pwszName;
    DBLENGTH ulParamSize;
    DBPARAMFLAGS dwFlags;
    BYTE bPrecision;
    BYTE bScale;
  } DBPARAMBINDINFO;

  EXTERN_C const IID IID_ICommandWithParameters;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandWithParameters : public IUnknown {
  public:
    virtual HRESULT WINAPI GetParameterInfo(DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,OLECHAR **ppNamesBuffer) = 0;
    virtual HRESULT WINAPI MapParameterNames(DB_UPARAMS cParamNames,const OLECHAR *rgParamNames[],DB_LPARAMS rgParamOrdinals[]) = 0;
    virtual HRESULT WINAPI SetParameterInfo(DB_UPARAMS cParams,const DB_UPARAMS rgParamOrdinals[],const DBPARAMBINDINFO rgParamBindInfo[]) = 0;
  };
#else
  typedef struct ICommandWithParametersVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandWithParameters *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandWithParameters *This);
      ULONG (WINAPI *Release)(ICommandWithParameters *This);
      HRESULT (WINAPI *GetParameterInfo)(ICommandWithParameters *This,DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,OLECHAR **ppNamesBuffer);
      HRESULT (WINAPI *MapParameterNames)(ICommandWithParameters *This,DB_UPARAMS cParamNames,const OLECHAR *rgParamNames[],DB_LPARAMS rgParamOrdinals[]);
      HRESULT (WINAPI *SetParameterInfo)(ICommandWithParameters *This,DB_UPARAMS cParams,const DB_UPARAMS rgParamOrdinals[],const DBPARAMBINDINFO rgParamBindInfo[]);
    END_INTERFACE
  } ICommandWithParametersVtbl;
  struct ICommandWithParameters {
    CONST_VTBL struct ICommandWithParametersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandWithParameters_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandWithParameters_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandWithParameters_Release(This) (This)->lpVtbl->Release(This)
#define ICommandWithParameters_GetParameterInfo(This,pcParams,prgParamInfo,ppNamesBuffer) (This)->lpVtbl->GetParameterInfo(This,pcParams,prgParamInfo,ppNamesBuffer)
#define ICommandWithParameters_MapParameterNames(This,cParamNames,rgParamNames,rgParamOrdinals) (This)->lpVtbl->MapParameterNames(This,cParamNames,rgParamNames,rgParamOrdinals)
#define ICommandWithParameters_SetParameterInfo(This,cParams,rgParamOrdinals,rgParamBindInfo) (This)->lpVtbl->SetParameterInfo(This,cParams,rgParamOrdinals,rgParamBindInfo)
#endif
#endif
  HRESULT WINAPI ICommandWithParameters_RemoteGetParameterInfo_Proxy(ICommandWithParameters *This,DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,DBBYTEOFFSET **prgNameOffsets,DBLENGTH *pcbNamesBuffer,OLECHAR **ppNamesBuffer,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandWithParameters_RemoteGetParameterInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandWithParameters_RemoteMapParameterNames_Proxy(ICommandWithParameters *This,DB_UPARAMS cParamNames,LPCOLESTR *rgParamNames,DB_LPARAMS *rgParamOrdinals,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandWithParameters_RemoteMapParameterNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandWithParameters_RemoteSetParameterInfo_Proxy(ICommandWithParameters *This,DB_UPARAMS cParams,const DB_UPARAMS *rgParamOrdinals,const DBPARAMBINDINFO *rgParamBindInfo,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ICommandWithParameters_RemoteSetParameterInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IColumnsRowset_INTERFACE_DEFINED__
#define __IColumnsRowset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IColumnsRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IColumnsRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI GetAvailableColumns(DBORDINAL *pcOptColumns,DBID **prgOptColumns) = 0;
    virtual HRESULT WINAPI GetColumnsRowset(IUnknown *pUnkOuter,DBORDINAL cOptColumns,const DBID rgOptColumns[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppColRowset) = 0;
  };
#else
  typedef struct IColumnsRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IColumnsRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IColumnsRowset *This);
      ULONG (WINAPI *Release)(IColumnsRowset *This);
      HRESULT (WINAPI *GetAvailableColumns)(IColumnsRowset *This,DBORDINAL *pcOptColumns,DBID **prgOptColumns);
      HRESULT (WINAPI *GetColumnsRowset)(IColumnsRowset *This,IUnknown *pUnkOuter,DBORDINAL cOptColumns,const DBID rgOptColumns[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppColRowset);
    END_INTERFACE
  } IColumnsRowsetVtbl;
  struct IColumnsRowset {
    CONST_VTBL struct IColumnsRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IColumnsRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IColumnsRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IColumnsRowset_Release(This) (This)->lpVtbl->Release(This)
#define IColumnsRowset_GetAvailableColumns(This,pcOptColumns,prgOptColumns) (This)->lpVtbl->GetAvailableColumns(This,pcOptColumns,prgOptColumns)
#define IColumnsRowset_GetColumnsRowset(This,pUnkOuter,cOptColumns,rgOptColumns,riid,cPropertySets,rgPropertySets,ppColRowset) (This)->lpVtbl->GetColumnsRowset(This,pUnkOuter,cOptColumns,rgOptColumns,riid,cPropertySets,rgPropertySets,ppColRowset)
#endif
#endif
  HRESULT WINAPI IColumnsRowset_RemoteGetAvailableColumns_Proxy(IColumnsRowset *This,DBORDINAL *pcOptColumns,DBID **prgOptColumns,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IColumnsRowset_RemoteGetAvailableColumns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IColumnsRowset_RemoteGetColumnsRowset_Proxy(IColumnsRowset *This,IUnknown *pUnkOuter,DBORDINAL cOptColumns,const DBID *rgOptColumns,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppColRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IColumnsRowset_RemoteGetColumnsRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IColumnsInfo_INTERFACE_DEFINED__
#define __IColumnsInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IColumnsInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IColumnsInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetColumnInfo(DBORDINAL *pcColumns,DBCOLUMNINFO **prgInfo,OLECHAR **ppStringsBuffer) = 0;
    virtual HRESULT WINAPI MapColumnIDs(DBORDINAL cColumnIDs,const DBID rgColumnIDs[],DBORDINAL rgColumns[]) = 0;
  };
#else
  typedef struct IColumnsInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IColumnsInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IColumnsInfo *This);
      ULONG (WINAPI *Release)(IColumnsInfo *This);
      HRESULT (WINAPI *GetColumnInfo)(IColumnsInfo *This,DBORDINAL *pcColumns,DBCOLUMNINFO **prgInfo,OLECHAR **ppStringsBuffer);
      HRESULT (WINAPI *MapColumnIDs)(IColumnsInfo *This,DBORDINAL cColumnIDs,const DBID rgColumnIDs[],DBORDINAL rgColumns[]);
    END_INTERFACE
  } IColumnsInfoVtbl;
  struct IColumnsInfo {
    CONST_VTBL struct IColumnsInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IColumnsInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IColumnsInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IColumnsInfo_Release(This) (This)->lpVtbl->Release(This)
#define IColumnsInfo_GetColumnInfo(This,pcColumns,prgInfo,ppStringsBuffer) (This)->lpVtbl->GetColumnInfo(This,pcColumns,prgInfo,ppStringsBuffer)
#define IColumnsInfo_MapColumnIDs(This,cColumnIDs,rgColumnIDs,rgColumns) (This)->lpVtbl->MapColumnIDs(This,cColumnIDs,rgColumnIDs,rgColumns)
#endif
#endif
  HRESULT WINAPI IColumnsInfo_RemoteGetColumnInfo_Proxy(IColumnsInfo *This,DBORDINAL *pcColumns,DBCOLUMNINFO **prgInfo,DBBYTEOFFSET **prgNameOffsets,DBBYTEOFFSET **prgcolumnidOffsets,DBLENGTH *pcbStringsBuffer,OLECHAR **ppStringsBuffer,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IColumnsInfo_RemoteGetColumnInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IColumnsInfo_RemoteMapColumnIDs_Proxy(IColumnsInfo *This,DBORDINAL cColumnIDs,const DBID *rgColumnIDs,DBORDINAL *rgColumns,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IColumnsInfo_RemoteMapColumnIDs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBCreateCommand_INTERFACE_DEFINED__
#define __IDBCreateCommand_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBCreateCommand;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBCreateCommand : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateCommand(IUnknown *pUnkOuter,REFIID riid,IUnknown **ppCommand) = 0;
  };
#else
  typedef struct IDBCreateCommandVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBCreateCommand *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBCreateCommand *This);
      ULONG (WINAPI *Release)(IDBCreateCommand *This);
      HRESULT (WINAPI *CreateCommand)(IDBCreateCommand *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppCommand);
    END_INTERFACE
  } IDBCreateCommandVtbl;
  struct IDBCreateCommand {
    CONST_VTBL struct IDBCreateCommandVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBCreateCommand_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBCreateCommand_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBCreateCommand_Release(This) (This)->lpVtbl->Release(This)
#define IDBCreateCommand_CreateCommand(This,pUnkOuter,riid,ppCommand) (This)->lpVtbl->CreateCommand(This,pUnkOuter,riid,ppCommand)
#endif
#endif
  HRESULT WINAPI IDBCreateCommand_RemoteCreateCommand_Proxy(IDBCreateCommand *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppCommand,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBCreateCommand_RemoteCreateCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBCreateSession_INTERFACE_DEFINED__
#define __IDBCreateSession_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBCreateSession;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBCreateSession : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateSession(IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession) = 0;
  };
#else
  typedef struct IDBCreateSessionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBCreateSession *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBCreateSession *This);
      ULONG (WINAPI *Release)(IDBCreateSession *This);
      HRESULT (WINAPI *CreateSession)(IDBCreateSession *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession);
    END_INTERFACE
  } IDBCreateSessionVtbl;
  struct IDBCreateSession {
    CONST_VTBL struct IDBCreateSessionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBCreateSession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBCreateSession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBCreateSession_Release(This) (This)->lpVtbl->Release(This)
#define IDBCreateSession_CreateSession(This,pUnkOuter,riid,ppDBSession) (This)->lpVtbl->CreateSession(This,pUnkOuter,riid,ppDBSession)
#endif
#endif
  HRESULT WINAPI IDBCreateSession_RemoteCreateSession_Proxy(IDBCreateSession *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBCreateSession_RemoteCreateSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISourcesRowset_INTERFACE_DEFINED__
#define __ISourcesRowset_INTERFACE_DEFINED__
  typedef DWORD DBSOURCETYPE;

  enum DBSOURCETYPEENUM {
    DBSOURCETYPE_DATASOURCE = 1,DBSOURCETYPE_ENUMERATOR = 2
  };

#if (OLEDBVER >= 0x0200)
  enum DBSOURCETYPEENUM20 {
    DBSOURCETYPE_DATASOURCE_TDP = 1,DBSOURCETYPE_DATASOURCE_MDP = 3
  };
#endif

#if (OLEDBVER >= 0x0250)
  enum DBSOURCETYPEENUM25 {
    DBSOURCETYPE_BINDER = 4
  };
#endif

  EXTERN_C const IID IID_ISourcesRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISourcesRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSourcesRowset(IUnknown *pUnkOuter,REFIID riid,ULONG cPropertySets,DBPROPSET rgProperties[],IUnknown **ppSourcesRowset) = 0;
  };
#else
  typedef struct ISourcesRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISourcesRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISourcesRowset *This);
      ULONG (WINAPI *Release)(ISourcesRowset *This);
      HRESULT (WINAPI *GetSourcesRowset)(ISourcesRowset *This,IUnknown *pUnkOuter,REFIID riid,ULONG cPropertySets,DBPROPSET rgProperties[],IUnknown **ppSourcesRowset);
    END_INTERFACE
  } ISourcesRowsetVtbl;
  struct ISourcesRowset {
    CONST_VTBL struct ISourcesRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISourcesRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISourcesRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISourcesRowset_Release(This) (This)->lpVtbl->Release(This)
#define ISourcesRowset_GetSourcesRowset(This,pUnkOuter,riid,cPropertySets,rgProperties,ppSourcesRowset) (This)->lpVtbl->GetSourcesRowset(This,pUnkOuter,riid,cPropertySets,rgProperties,ppSourcesRowset)
#endif
#endif
  HRESULT WINAPI ISourcesRowset_RemoteGetSourcesRowset_Proxy(ISourcesRowset *This,IUnknown *pUnkOuter,REFIID riid,ULONG cPropertySets,DBPROPSET *rgProperties,IUnknown **ppSourcesRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ISourcesRowset_RemoteGetSourcesRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBProperties_INTERFACE_DEFINED__
#define __IDBProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI GetProperties(ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets) = 0;
    virtual HRESULT WINAPI GetPropertyInfo(ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,OLECHAR **ppDescBuffer) = 0;
    virtual HRESULT WINAPI SetProperties(ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
  };
#else
  typedef struct IDBPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBProperties *This);
      ULONG (WINAPI *Release)(IDBProperties *This);
      HRESULT (WINAPI *GetProperties)(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
      HRESULT (WINAPI *GetPropertyInfo)(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,OLECHAR **ppDescBuffer);
      HRESULT (WINAPI *SetProperties)(IDBProperties *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
    END_INTERFACE
  } IDBPropertiesVtbl;
  struct IDBProperties {
    CONST_VTBL struct IDBPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBProperties_Release(This) (This)->lpVtbl->Release(This)
#define IDBProperties_GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets) (This)->lpVtbl->GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets)
#define IDBProperties_GetPropertyInfo(This,cPropertyIDSets,rgPropertyIDSets,pcPropertyInfoSets,prgPropertyInfoSets,ppDescBuffer) (This)->lpVtbl->GetPropertyInfo(This,cPropertyIDSets,rgPropertyIDSets,pcPropertyInfoSets,prgPropertyInfoSets,ppDescBuffer)
#define IDBProperties_SetProperties(This,cPropertySets,rgPropertySets) (This)->lpVtbl->SetProperties(This,cPropertySets,rgPropertySets)
#endif
#endif
  HRESULT WINAPI IDBProperties_RemoteGetProperties_Proxy(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBProperties_RemoteGetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBProperties_RemoteGetPropertyInfo_Proxy(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,ULONG *pcOffsets,DBBYTEOFFSET **prgDescOffsets,ULONG *pcbDescBuffer,OLECHAR **ppDescBuffer,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBProperties_RemoteGetPropertyInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBProperties_RemoteSetProperties_Proxy(IDBProperties *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBProperties_RemoteSetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBInitialize_INTERFACE_DEFINED__
#define __IDBInitialize_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBInitialize;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBInitialize : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(void) = 0;
    virtual HRESULT WINAPI Uninitialize(void) = 0;
  };
#else
  typedef struct IDBInitializeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBInitialize *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBInitialize *This);
      ULONG (WINAPI *Release)(IDBInitialize *This);
      HRESULT (WINAPI *Initialize)(IDBInitialize *This);
      HRESULT (WINAPI *Uninitialize)(IDBInitialize *This);
    END_INTERFACE
  } IDBInitializeVtbl;
  struct IDBInitialize {
    CONST_VTBL struct IDBInitializeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBInitialize_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBInitialize_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBInitialize_Release(This) (This)->lpVtbl->Release(This)
#define IDBInitialize_Initialize(This) (This)->lpVtbl->Initialize(This)
#define IDBInitialize_Uninitialize(This) (This)->lpVtbl->Uninitialize(This)
#endif
#endif
  HRESULT WINAPI IDBInitialize_RemoteInitialize_Proxy(IDBInitialize *This,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBInitialize_RemoteInitialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBInitialize_RemoteUninitialize_Proxy(IDBInitialize *This,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBInitialize_RemoteUninitialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBInfo_INTERFACE_DEFINED__
#define __IDBInfo_INTERFACE_DEFINED__
  typedef DWORD DBLITERAL;

  enum DBLITERALENUM {
    DBLITERAL_INVALID = 0,DBLITERAL_BINARY_LITERAL = 1,DBLITERAL_CATALOG_NAME = 2,DBLITERAL_CATALOG_SEPARATOR = 3,DBLITERAL_CHAR_LITERAL = 4,
    DBLITERAL_COLUMN_ALIAS = 5,DBLITERAL_COLUMN_NAME = 6,DBLITERAL_CORRELATION_NAME = 7,DBLITERAL_CURSOR_NAME = 8,DBLITERAL_ESCAPE_PERCENT = 9,
    DBLITERAL_ESCAPE_UNDERSCORE = 10,DBLITERAL_INDEX_NAME = 11,DBLITERAL_LIKE_PERCENT = 12,DBLITERAL_LIKE_UNDERSCORE = 13,DBLITERAL_PROCEDURE_NAME = 14,
    DBLITERAL_QUOTE = 15,DBLITERAL_SCHEMA_NAME = 16,DBLITERAL_TABLE_NAME = 17,DBLITERAL_TEXT_COMMAND = 18,DBLITERAL_USER_NAME = 19,
    DBLITERAL_VIEW_NAME = 20
  };

#if (OLEDBVER >= 0x0200)
#define DBLITERAL_QUOTE_PREFIX DBLITERAL_QUOTE
  enum DBLITERALENUM20 {
    DBLITERAL_CUBE_NAME = 21,DBLITERAL_DIMENSION_NAME = 22,DBLITERAL_HIERARCHY_NAME = 23,DBLITERAL_LEVEL_NAME = 24,DBLITERAL_MEMBER_NAME = 25,
    DBLITERAL_PROPERTY_NAME = 26,DBLITERAL_SCHEMA_SEPARATOR = 27,DBLITERAL_QUOTE_SUFFIX = 28
  };
#endif

#if (OLEDBVER >= 0x0210)
#define DBLITERAL_ESCAPE_PERCENT_PREFIX DBLITERAL_ESCAPE_PERCENT
#define DBLITERAL_ESCAPE_UNDERSCORE_PREFIX DBLITERAL_ESCAPE_UNDERSCORE

  enum DBLITERALENUM21 {
    DBLITERAL_ESCAPE_PERCENT_SUFFIX = 29,DBLITERAL_ESCAPE_UNDERSCORE_SUFFIX = 30
  };
#endif

  typedef struct tagDBLITERALINFO {
    LPOLESTR pwszLiteralValue;
    LPOLESTR pwszInvalidChars;
    LPOLESTR pwszInvalidStartingChars;
    DBLITERAL lt;
    WINBOOL fSupported;
    ULONG cchMaxLen;
  } DBLITERALINFO;

  EXTERN_C const IID IID_IDBInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetKeywords(LPOLESTR *ppwszKeywords) = 0;
    virtual HRESULT WINAPI GetLiteralInfo(ULONG cLiterals,const DBLITERAL rgLiterals[],ULONG *pcLiteralInfo,DBLITERALINFO **prgLiteralInfo,OLECHAR **ppCharBuffer) = 0;
  };
#else
  typedef struct IDBInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBInfo *This);
      ULONG (WINAPI *Release)(IDBInfo *This);
      HRESULT (WINAPI *GetKeywords)(IDBInfo *This,LPOLESTR *ppwszKeywords);
      HRESULT (WINAPI *GetLiteralInfo)(IDBInfo *This,ULONG cLiterals,const DBLITERAL rgLiterals[],ULONG *pcLiteralInfo,DBLITERALINFO **prgLiteralInfo,OLECHAR **ppCharBuffer);
    END_INTERFACE
  } IDBInfoVtbl;
  struct IDBInfo {
    CONST_VTBL struct IDBInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBInfo_Release(This) (This)->lpVtbl->Release(This)
#define IDBInfo_GetKeywords(This,ppwszKeywords) (This)->lpVtbl->GetKeywords(This,ppwszKeywords)
#define IDBInfo_GetLiteralInfo(This,cLiterals,rgLiterals,pcLiteralInfo,prgLiteralInfo,ppCharBuffer) (This)->lpVtbl->GetLiteralInfo(This,cLiterals,rgLiterals,pcLiteralInfo,prgLiteralInfo,ppCharBuffer)
#endif
#endif
  HRESULT WINAPI IDBInfo_RemoteGetKeywords_Proxy(IDBInfo *This,LPOLESTR *ppwszKeywords,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBInfo_RemoteGetKeywords_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBInfo_RemoteGetLiteralInfo_Proxy(IDBInfo *This,ULONG cLiterals,const DBLITERAL *rgLiterals,ULONG *pcLiteralInfo,DBLITERALINFO **prgLiteralInfo,DB_UPARAMS **prgLVOffsets,DB_UPARAMS **prgICOffsets,DB_UPARAMS **prgISCOffsets,ULONG *pcbCharBuffer,OLECHAR **ppCharBuffer,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBInfo_RemoteGetLiteralInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBDataSourceAdmin_INTERFACE_DEFINED__
#define __IDBDataSourceAdmin_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBDataSourceAdmin;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBDataSourceAdmin : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateDataSource(ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession) = 0;
    virtual HRESULT WINAPI DestroyDataSource(void) = 0;
    virtual HRESULT WINAPI GetCreationProperties(ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,OLECHAR **ppDescBuffer) = 0;
    virtual HRESULT WINAPI ModifyDataSource(ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
  };
#else
  typedef struct IDBDataSourceAdminVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBDataSourceAdmin *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBDataSourceAdmin *This);
      ULONG (WINAPI *Release)(IDBDataSourceAdmin *This);
      HRESULT (WINAPI *CreateDataSource)(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession);
      HRESULT (WINAPI *DestroyDataSource)(IDBDataSourceAdmin *This);
      HRESULT (WINAPI *GetCreationProperties)(IDBDataSourceAdmin *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,OLECHAR **ppDescBuffer);
      HRESULT (WINAPI *ModifyDataSource)(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
    END_INTERFACE
  } IDBDataSourceAdminVtbl;
  struct IDBDataSourceAdmin {
    CONST_VTBL struct IDBDataSourceAdminVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBDataSourceAdmin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBDataSourceAdmin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBDataSourceAdmin_Release(This) (This)->lpVtbl->Release(This)
#define IDBDataSourceAdmin_CreateDataSource(This,cPropertySets,rgPropertySets,pUnkOuter,riid,ppDBSession) (This)->lpVtbl->CreateDataSource(This,cPropertySets,rgPropertySets,pUnkOuter,riid,ppDBSession)
#define IDBDataSourceAdmin_DestroyDataSource(This) (This)->lpVtbl->DestroyDataSource(This)
#define IDBDataSourceAdmin_GetCreationProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertyInfoSets,prgPropertyInfoSets,ppDescBuffer) (This)->lpVtbl->GetCreationProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertyInfoSets,prgPropertyInfoSets,ppDescBuffer)
#define IDBDataSourceAdmin_ModifyDataSource(This,cPropertySets,rgPropertySets) (This)->lpVtbl->ModifyDataSource(This,cPropertySets,rgPropertySets)
#endif
#endif
  HRESULT WINAPI IDBDataSourceAdmin_RemoteCreateDataSource_Proxy(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBDataSourceAdmin_RemoteCreateDataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBDataSourceAdmin_RemoteDestroyDataSource_Proxy(IDBDataSourceAdmin *This,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBDataSourceAdmin_RemoteDestroyDataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBDataSourceAdmin_RemoteGetCreationProperties_Proxy(IDBDataSourceAdmin *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,DBCOUNTITEM *pcOffsets,DBBYTEOFFSET **prgDescOffsets,ULONG *pcbDescBuffer,OLECHAR **ppDescBuffer,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBDataSourceAdmin_RemoteGetCreationProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBDataSourceAdmin_RemoteModifyDataSource_Proxy(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBDataSourceAdmin_RemoteModifyDataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#if (OLEDBVER >= 0x0150)
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0304_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0304_v0_0_s_ifspec;

#ifndef __IDBAsynchNotify_INTERFACE_DEFINED__
#define __IDBAsynchNotify_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBAsynchNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBAsynchNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI OnLowResource(DB_DWRESERVE dwReserved) = 0;
    virtual HRESULT WINAPI OnProgress(HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM ulProgress,DBCOUNTITEM ulProgressMax,DBASYNCHPHASE eAsynchPhase,LPOLESTR pwszStatusText) = 0;
    virtual HRESULT WINAPI OnStop(HCHAPTER hChapter,DBASYNCHOP eOperation,HRESULT hrStatus,LPOLESTR pwszStatusText) = 0;
  };
#else
  typedef struct IDBAsynchNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBAsynchNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBAsynchNotify *This);
      ULONG (WINAPI *Release)(IDBAsynchNotify *This);
      HRESULT (WINAPI *OnLowResource)(IDBAsynchNotify *This,DB_DWRESERVE dwReserved);
      HRESULT (WINAPI *OnProgress)(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM ulProgress,DBCOUNTITEM ulProgressMax,DBASYNCHPHASE eAsynchPhase,LPOLESTR pwszStatusText);
      HRESULT (WINAPI *OnStop)(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,HRESULT hrStatus,LPOLESTR pwszStatusText);
    END_INTERFACE
  } IDBAsynchNotifyVtbl;
  struct IDBAsynchNotify {
    CONST_VTBL struct IDBAsynchNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBAsynchNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBAsynchNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBAsynchNotify_Release(This) (This)->lpVtbl->Release(This)
#define IDBAsynchNotify_OnLowResource(This,dwReserved) (This)->lpVtbl->OnLowResource(This,dwReserved)
#define IDBAsynchNotify_OnProgress(This,hChapter,eOperation,ulProgress,ulProgressMax,eAsynchPhase,pwszStatusText) (This)->lpVtbl->OnProgress(This,hChapter,eOperation,ulProgress,ulProgressMax,eAsynchPhase,pwszStatusText)
#define IDBAsynchNotify_OnStop(This,hChapter,eOperation,hrStatus,pwszStatusText) (This)->lpVtbl->OnStop(This,hChapter,eOperation,hrStatus,pwszStatusText)
#endif
#endif
  HRESULT WINAPI IDBAsynchNotify_RemoteOnLowResource_Proxy(IDBAsynchNotify *This,DB_DWRESERVE dwReserved);
  void __RPC_STUB IDBAsynchNotify_RemoteOnLowResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBAsynchNotify_RemoteOnProgress_Proxy(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM ulProgress,DBCOUNTITEM ulProgressMax,DBASYNCHPHASE eAsynchPhase,LPOLESTR pwszStatusText);
  void __RPC_STUB IDBAsynchNotify_RemoteOnProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBAsynchNotify_RemoteOnStop_Proxy(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,HRESULT hrStatus,LPOLESTR pwszStatusText);
  void __RPC_STUB IDBAsynchNotify_RemoteOnStop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBAsynchStatus_INTERFACE_DEFINED__
#define __IDBAsynchStatus_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBAsynchStatus;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBAsynchStatus : public IUnknown {
  public:
    virtual HRESULT WINAPI Abort(HCHAPTER hChapter,DBASYNCHOP eOperation) = 0;
    virtual HRESULT WINAPI GetStatus(HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM *pulProgress,DBCOUNTITEM *pulProgressMax,DBASYNCHPHASE *peAsynchPhase,LPOLESTR *ppwszStatusText) = 0;
  };
#else
  typedef struct IDBAsynchStatusVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBAsynchStatus *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBAsynchStatus *This);
      ULONG (WINAPI *Release)(IDBAsynchStatus *This);
      HRESULT (WINAPI *Abort)(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation);
      HRESULT (WINAPI *GetStatus)(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM *pulProgress,DBCOUNTITEM *pulProgressMax,DBASYNCHPHASE *peAsynchPhase,LPOLESTR *ppwszStatusText);
    END_INTERFACE
  } IDBAsynchStatusVtbl;
  struct IDBAsynchStatus {
    CONST_VTBL struct IDBAsynchStatusVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBAsynchStatus_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBAsynchStatus_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBAsynchStatus_Release(This) (This)->lpVtbl->Release(This)
#define IDBAsynchStatus_Abort(This,hChapter,eOperation) (This)->lpVtbl->Abort(This,hChapter,eOperation)
#define IDBAsynchStatus_GetStatus(This,hChapter,eOperation,pulProgress,pulProgressMax,peAsynchPhase,ppwszStatusText) (This)->lpVtbl->GetStatus(This,hChapter,eOperation,pulProgress,pulProgressMax,peAsynchPhase,ppwszStatusText)
#endif
#endif
  HRESULT WINAPI IDBAsynchStatus_RemoteAbort_Proxy(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBAsynchStatus_RemoteAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBAsynchStatus_RemoteGetStatus_Proxy(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM *pulProgress,DBCOUNTITEM *pulProgressMax,DBASYNCHPHASE *peAsynchPhase,LPOLESTR *ppwszStatusText,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBAsynchStatus_RemoteGetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0306_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0306_v0_0_s_ifspec;

#ifndef __ISessionProperties_INTERFACE_DEFINED__
#define __ISessionProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISessionProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISessionProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI GetProperties(ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets) = 0;
    virtual HRESULT WINAPI SetProperties(ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
  };
#else
  typedef struct ISessionPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISessionProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISessionProperties *This);
      ULONG (WINAPI *Release)(ISessionProperties *This);
      HRESULT (WINAPI *GetProperties)(ISessionProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
      HRESULT (WINAPI *SetProperties)(ISessionProperties *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
    END_INTERFACE
  } ISessionPropertiesVtbl;
  struct ISessionProperties {
    CONST_VTBL struct ISessionPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISessionProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISessionProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISessionProperties_Release(This) (This)->lpVtbl->Release(This)
#define ISessionProperties_GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets) (This)->lpVtbl->GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets)
#define ISessionProperties_SetProperties(This,cPropertySets,rgPropertySets) (This)->lpVtbl->SetProperties(This,cPropertySets,rgPropertySets)
#endif
#endif
  HRESULT WINAPI ISessionProperties_RemoteGetProperties_Proxy(ISessionProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ISessionProperties_RemoteGetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionProperties_RemoteSetProperties_Proxy(ISessionProperties *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ISessionProperties_RemoteSetProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IIndexDefinition_INTERFACE_DEFINED__
#define __IIndexDefinition_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIndexDefinition;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIndexDefinition : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateIndex(DBID *pTableID,DBID *pIndexID,DBORDINAL cIndexColumnDescs,const DBINDEXCOLUMNDESC rgIndexColumnDescs[],ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppIndexID) = 0;
    virtual HRESULT WINAPI DropIndex(DBID *pTableID,DBID *pIndexID) = 0;
  };
#else
  typedef struct IIndexDefinitionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIndexDefinition *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIndexDefinition *This);
      ULONG (WINAPI *Release)(IIndexDefinition *This);
      HRESULT (WINAPI *CreateIndex)(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID,DBORDINAL cIndexColumnDescs,const DBINDEXCOLUMNDESC rgIndexColumnDescs[],ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppIndexID);
      HRESULT (WINAPI *DropIndex)(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID);
    END_INTERFACE
  } IIndexDefinitionVtbl;
  struct IIndexDefinition {
    CONST_VTBL struct IIndexDefinitionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIndexDefinition_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIndexDefinition_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIndexDefinition_Release(This) (This)->lpVtbl->Release(This)
#define IIndexDefinition_CreateIndex(This,pTableID,pIndexID,cIndexColumnDescs,rgIndexColumnDescs,cPropertySets,rgPropertySets,ppIndexID) (This)->lpVtbl->CreateIndex(This,pTableID,pIndexID,cIndexColumnDescs,rgIndexColumnDescs,cPropertySets,rgPropertySets,ppIndexID)
#define IIndexDefinition_DropIndex(This,pTableID,pIndexID) (This)->lpVtbl->DropIndex(This,pTableID,pIndexID)
#endif
#endif
  HRESULT WINAPI IIndexDefinition_RemoteCreateIndex_Proxy(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID,DBORDINAL cIndexColumnDescs,const DBINDEXCOLUMNDESC *rgIndexColumnDescs,ULONG cPropertySets,DBPROPSET *rgPropertySets,DBID **ppIndexID,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IIndexDefinition_RemoteCreateIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIndexDefinition_RemoteDropIndex_Proxy(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IIndexDefinition_RemoteDropIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITableDefinition_INTERFACE_DEFINED__
#define __ITableDefinition_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITableDefinition;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITableDefinition : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateTable(IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,const DBCOLUMNDESC rgColumnDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset) = 0;
    virtual HRESULT WINAPI DropTable(DBID *pTableID) = 0;
    virtual HRESULT WINAPI AddColumn(DBID *pTableID,DBCOLUMNDESC *pColumnDesc,DBID **ppColumnID) = 0;
    virtual HRESULT WINAPI DropColumn(DBID *pTableID,DBID *pColumnID) = 0;
  };
#else
  typedef struct ITableDefinitionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITableDefinition *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITableDefinition *This);
      ULONG (WINAPI *Release)(ITableDefinition *This);
      HRESULT (WINAPI *CreateTable)(ITableDefinition *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,const DBCOLUMNDESC rgColumnDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset);
      HRESULT (WINAPI *DropTable)(ITableDefinition *This,DBID *pTableID);
      HRESULT (WINAPI *AddColumn)(ITableDefinition *This,DBID *pTableID,DBCOLUMNDESC *pColumnDesc,DBID **ppColumnID);
      HRESULT (WINAPI *DropColumn)(ITableDefinition *This,DBID *pTableID,DBID *pColumnID);
    END_INTERFACE
  } ITableDefinitionVtbl;
  struct ITableDefinition {
    CONST_VTBL struct ITableDefinitionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITableDefinition_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITableDefinition_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITableDefinition_Release(This) (This)->lpVtbl->Release(This)
#define ITableDefinition_CreateTable(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset) (This)->lpVtbl->CreateTable(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset)
#define ITableDefinition_DropTable(This,pTableID) (This)->lpVtbl->DropTable(This,pTableID)
#define ITableDefinition_AddColumn(This,pTableID,pColumnDesc,ppColumnID) (This)->lpVtbl->AddColumn(This,pTableID,pColumnDesc,ppColumnID)
#define ITableDefinition_DropColumn(This,pTableID,pColumnID) (This)->lpVtbl->DropColumn(This,pTableID,pColumnID)
#endif
#endif
  HRESULT WINAPI ITableDefinition_RemoteCreateTable_Proxy(ITableDefinition *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,const DBCOLUMNDESC *rgColumnDescs,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,DBID **ppTableID,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,WINBOOL *pfTableCreated,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITableDefinition_RemoteCreateTable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITableDefinition_RemoteDropTable_Proxy(ITableDefinition *This,DBID *pTableID,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITableDefinition_RemoteDropTable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITableDefinition_RemoteAddColumn_Proxy(ITableDefinition *This,DBID *pTableID,DBCOLUMNDESC *pColumnDesc,DBID **ppColumnID,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITableDefinition_RemoteAddColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITableDefinition_RemoteDropColumn_Proxy(ITableDefinition *This,DBID *pTableID,DBID *pColumnID,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITableDefinition_RemoteDropColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IOpenRowset_INTERFACE_DEFINED__
#define __IOpenRowset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IOpenRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IOpenRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI OpenRowset(IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset) = 0;
  };
#else
  typedef struct IOpenRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IOpenRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IOpenRowset *This);
      ULONG (WINAPI *Release)(IOpenRowset *This);
      HRESULT (WINAPI *OpenRowset)(IOpenRowset *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
    END_INTERFACE
  } IOpenRowsetVtbl;
  struct IOpenRowset {
    CONST_VTBL struct IOpenRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IOpenRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IOpenRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IOpenRowset_Release(This) (This)->lpVtbl->Release(This)
#define IOpenRowset_OpenRowset(This,pUnkOuter,pTableID,pIndexID,riid,cPropertySets,rgPropertySets,ppRowset) (This)->lpVtbl->OpenRowset(This,pUnkOuter,pTableID,pIndexID,riid,cPropertySets,rgPropertySets,ppRowset)
#endif
#endif
  HRESULT WINAPI IOpenRowset_RemoteOpenRowset_Proxy(IOpenRowset *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IOpenRowset_RemoteOpenRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBSchemaRowset_INTERFACE_DEFINED__
#define __IDBSchemaRowset_INTERFACE_DEFINED__

#define CRESTRICTIONS_DBSCHEMA_ASSERTIONS 3
#define CRESTRICTIONS_DBSCHEMA_CATALOGS 1
#define CRESTRICTIONS_DBSCHEMA_CHARACTER_SETS 3
#define CRESTRICTIONS_DBSCHEMA_COLLATIONS 3
#define CRESTRICTIONS_DBSCHEMA_COLUMNS 4
#define CRESTRICTIONS_DBSCHEMA_CHECK_CONSTRAINTS 3
#define CRESTRICTIONS_DBSCHEMA_CONSTRAINT_COLUMN_USAGE 4
#define CRESTRICTIONS_DBSCHEMA_CONSTRAINT_TABLE_USAGE 3
#define CRESTRICTIONS_DBSCHEMA_KEY_COLUMN_USAGE 7
#define CRESTRICTIONS_DBSCHEMA_REFERENTIAL_CONSTRAINTS 3
#define CRESTRICTIONS_DBSCHEMA_TABLE_CONSTRAINTS 7
#define CRESTRICTIONS_DBSCHEMA_COLUMN_DOMAIN_USAGE 4
#define CRESTRICTIONS_DBSCHEMA_INDEXES 5
#define CRESTRICTIONS_DBSCHEMA_OBJECT_ACTIONS 1
#define CRESTRICTIONS_DBSCHEMA_OBJECTS 1
#define CRESTRICTIONS_DBSCHEMA_COLUMN_PRIVILEGES 6
#define CRESTRICTIONS_DBSCHEMA_TABLE_PRIVILEGES 5
#define CRESTRICTIONS_DBSCHEMA_USAGE_PRIVILEGES 6
#define CRESTRICTIONS_DBSCHEMA_PROCEDURES 4
#define CRESTRICTIONS_DBSCHEMA_SCHEMATA 3
#define CRESTRICTIONS_DBSCHEMA_SQL_LANGUAGES 0
#define CRESTRICTIONS_DBSCHEMA_STATISTICS 3
#define CRESTRICTIONS_DBSCHEMA_TABLES 4
#define CRESTRICTIONS_DBSCHEMA_TRANSLATIONS 3
#define CRESTRICTIONS_DBSCHEMA_PROVIDER_TYPES 2
#define CRESTRICTIONS_DBSCHEMA_VIEWS 3
#define CRESTRICTIONS_DBSCHEMA_VIEW_COLUMN_USAGE 3
#define CRESTRICTIONS_DBSCHEMA_VIEW_TABLE_USAGE 3
#define CRESTRICTIONS_DBSCHEMA_PROCEDURE_PARAMETERS 4
#define CRESTRICTIONS_DBSCHEMA_FOREIGN_KEYS 6
#define CRESTRICTIONS_DBSCHEMA_PRIMARY_KEYS 3
#define CRESTRICTIONS_DBSCHEMA_PROCEDURE_COLUMNS 4

#if (OLEDBVER >= 0x0200)
#define CRESTRICTIONS_DBSCHEMA_TABLES_INFO 4
#define CRESTRICTIONS_MDSCHEMA_CUBES 3
#define CRESTRICTIONS_MDSCHEMA_DIMENSIONS 5
#define CRESTRICTIONS_MDSCHEMA_HIERARCHIES 6
#define CRESTRICTIONS_MDSCHEMA_LEVELS 7
#define CRESTRICTIONS_MDSCHEMA_MEASURES 5
#define CRESTRICTIONS_MDSCHEMA_PROPERTIES 9
#define CRESTRICTIONS_MDSCHEMA_MEMBERS 12
#endif

#if (OLEDBVER >= 0x0210)
#define CRESTRICTIONS_DBSCHEMA_TRUSTEE 4
#endif

#if (OLEDBVER >= 0x0260)
#define CRESTRICTIONS_DBSCHEMA_TABLE_STATISTICS 7
#define CRESTRICTIONS_DBSCHEMA_CHECK_CONSTRAINTS_BY_TABLE 6
#define CRESTRICTIONS_MDSCHEMA_FUNCTIONS 4
#define CRESTRICTIONS_MDSCHEMA_ACTIONS 8
#define CRESTRICTIONS_MDSCHEMA_COMMANDS 5
#define CRESTRICTIONS_MDSCHEMA_SETS 5
#endif

  EXTERN_C const IID IID_IDBSchemaRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBSchemaRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRowset(IUnknown *pUnkOuter,REFGUID rguidSchema,ULONG cRestrictions,const VARIANT rgRestrictions[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset) = 0;
    virtual HRESULT WINAPI GetSchemas(ULONG *pcSchemas,GUID **prgSchemas,ULONG **prgRestrictionSupport) = 0;
  };
#else
  typedef struct IDBSchemaRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBSchemaRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBSchemaRowset *This);
      ULONG (WINAPI *Release)(IDBSchemaRowset *This);
      HRESULT (WINAPI *GetRowset)(IDBSchemaRowset *This,IUnknown *pUnkOuter,REFGUID rguidSchema,ULONG cRestrictions,const VARIANT rgRestrictions[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
      HRESULT (WINAPI *GetSchemas)(IDBSchemaRowset *This,ULONG *pcSchemas,GUID **prgSchemas,ULONG **prgRestrictionSupport);
    END_INTERFACE
  } IDBSchemaRowsetVtbl;
  struct IDBSchemaRowset {
    CONST_VTBL struct IDBSchemaRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBSchemaRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBSchemaRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBSchemaRowset_Release(This) (This)->lpVtbl->Release(This)
#define IDBSchemaRowset_GetRowset(This,pUnkOuter,rguidSchema,cRestrictions,rgRestrictions,riid,cPropertySets,rgPropertySets,ppRowset) (This)->lpVtbl->GetRowset(This,pUnkOuter,rguidSchema,cRestrictions,rgRestrictions,riid,cPropertySets,rgPropertySets,ppRowset)
#define IDBSchemaRowset_GetSchemas(This,pcSchemas,prgSchemas,prgRestrictionSupport) (This)->lpVtbl->GetSchemas(This,pcSchemas,prgSchemas,prgRestrictionSupport)
#endif
#endif
  HRESULT WINAPI IDBSchemaRowset_RemoteGetRowset_Proxy(IDBSchemaRowset *This,IUnknown *pUnkOuter,REFGUID rguidSchema,ULONG cRestrictions,const VARIANT *rgRestrictions,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBSchemaRowset_RemoteGetRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDBSchemaRowset_RemoteGetSchemas_Proxy(IDBSchemaRowset *This,ULONG *pcSchemas,GUID **prgSchemas,ULONG **prgRestrictionSupport,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IDBSchemaRowset_RemoteGetSchemas_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#if (OLEDBVER >= 0x0200)
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0311_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0311_v0_0_s_ifspec;

#ifndef __IMDDataset_INTERFACE_DEFINED__
#define __IMDDataset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMDDataset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMDDataset : public IUnknown {
  public:
    virtual HRESULT WINAPI FreeAxisInfo(DBCOUNTITEM cAxes,MDAXISINFO *rgAxisInfo) = 0;
    virtual HRESULT WINAPI GetAxisInfo(DBCOUNTITEM *pcAxes,MDAXISINFO **prgAxisInfo) = 0;
    virtual HRESULT WINAPI GetAxisRowset(IUnknown *pUnkOuter,DBCOUNTITEM iAxis,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset) = 0;
    virtual HRESULT WINAPI GetCellData(HACCESSOR hAccessor,DBORDINAL ulStartCell,DBORDINAL ulEndCell,void *pData) = 0;
    virtual HRESULT WINAPI GetSpecification(REFIID riid,IUnknown **ppSpecification) = 0;
  };
#else
  typedef struct IMDDatasetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMDDataset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMDDataset *This);
      ULONG (WINAPI *Release)(IMDDataset *This);
      HRESULT (WINAPI *FreeAxisInfo)(IMDDataset *This,DBCOUNTITEM cAxes,MDAXISINFO *rgAxisInfo);
      HRESULT (WINAPI *GetAxisInfo)(IMDDataset *This,DBCOUNTITEM *pcAxes,MDAXISINFO **prgAxisInfo);
      HRESULT (WINAPI *GetAxisRowset)(IMDDataset *This,IUnknown *pUnkOuter,DBCOUNTITEM iAxis,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
      HRESULT (WINAPI *GetCellData)(IMDDataset *This,HACCESSOR hAccessor,DBORDINAL ulStartCell,DBORDINAL ulEndCell,void *pData);
      HRESULT (WINAPI *GetSpecification)(IMDDataset *This,REFIID riid,IUnknown **ppSpecification);
    END_INTERFACE
  } IMDDatasetVtbl;
  struct IMDDataset {
    CONST_VTBL struct IMDDatasetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMDDataset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMDDataset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMDDataset_Release(This) (This)->lpVtbl->Release(This)
#define IMDDataset_FreeAxisInfo(This,cAxes,rgAxisInfo) (This)->lpVtbl->FreeAxisInfo(This,cAxes,rgAxisInfo)
#define IMDDataset_GetAxisInfo(This,pcAxes,prgAxisInfo) (This)->lpVtbl->GetAxisInfo(This,pcAxes,prgAxisInfo)
#define IMDDataset_GetAxisRowset(This,pUnkOuter,iAxis,riid,cPropertySets,rgPropertySets,ppRowset) (This)->lpVtbl->GetAxisRowset(This,pUnkOuter,iAxis,riid,cPropertySets,rgPropertySets,ppRowset)
#define IMDDataset_GetCellData(This,hAccessor,ulStartCell,ulEndCell,pData) (This)->lpVtbl->GetCellData(This,hAccessor,ulStartCell,ulEndCell,pData)
#define IMDDataset_GetSpecification(This,riid,ppSpecification) (This)->lpVtbl->GetSpecification(This,riid,ppSpecification)
#endif
#endif
  HRESULT WINAPI IMDDataset_FreeAxisInfo_Proxy(IMDDataset *This,DBCOUNTITEM cAxes,MDAXISINFO *rgAxisInfo);
  void __RPC_STUB IMDDataset_FreeAxisInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMDDataset_GetAxisInfo_Proxy(IMDDataset *This,DBCOUNTITEM *pcAxes,MDAXISINFO **prgAxisInfo);
  void __RPC_STUB IMDDataset_GetAxisInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMDDataset_GetAxisRowset_Proxy(IMDDataset *This,IUnknown *pUnkOuter,DBCOUNTITEM iAxis,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
  void __RPC_STUB IMDDataset_GetAxisRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMDDataset_GetCellData_Proxy(IMDDataset *This,HACCESSOR hAccessor,DBORDINAL ulStartCell,DBORDINAL ulEndCell,void *pData);
  void __RPC_STUB IMDDataset_GetCellData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMDDataset_GetSpecification_Proxy(IMDDataset *This,REFIID riid,IUnknown **ppSpecification);
  void __RPC_STUB IMDDataset_GetSpecification_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMDFind_INTERFACE_DEFINED__
#define __IMDFind_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMDFind;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMDFind : public IUnknown {
  public:
    virtual HRESULT WINAPI FindCell(DBORDINAL ulStartingOrdinal,DBCOUNTITEM cMembers,LPCOLESTR *rgpwszMember,DBORDINAL *pulCellOrdinal) = 0;
    virtual HRESULT WINAPI FindTuple(ULONG ulAxisIdentifier,DBORDINAL ulStartingOrdinal,DBCOUNTITEM cMembers,LPCOLESTR *rgpwszMember,ULONG *pulTupleOrdinal) = 0;
  };
#else
  typedef struct IMDFindVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMDFind *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMDFind *This);
      ULONG (WINAPI *Release)(IMDFind *This);
      HRESULT (WINAPI *FindCell)(IMDFind *This,DBORDINAL ulStartingOrdinal,DBCOUNTITEM cMembers,LPCOLESTR *rgpwszMember,DBORDINAL *pulCellOrdinal);
      HRESULT (WINAPI *FindTuple)(IMDFind *This,ULONG ulAxisIdentifier,DBORDINAL ulStartingOrdinal,DBCOUNTITEM cMembers,LPCOLESTR *rgpwszMember,ULONG *pulTupleOrdinal);
    END_INTERFACE
  } IMDFindVtbl;
  struct IMDFind {
    CONST_VTBL struct IMDFindVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMDFind_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMDFind_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMDFind_Release(This) (This)->lpVtbl->Release(This)
#define IMDFind_FindCell(This,ulStartingOrdinal,cMembers,rgpwszMember,pulCellOrdinal) (This)->lpVtbl->FindCell(This,ulStartingOrdinal,cMembers,rgpwszMember,pulCellOrdinal)
#define IMDFind_FindTuple(This,ulAxisIdentifier,ulStartingOrdinal,cMembers,rgpwszMember,pulTupleOrdinal) (This)->lpVtbl->FindTuple(This,ulAxisIdentifier,ulStartingOrdinal,cMembers,rgpwszMember,pulTupleOrdinal)
#endif
#endif
  HRESULT WINAPI IMDFind_FindCell_Proxy(IMDFind *This,DBORDINAL ulStartingOrdinal,DBCOUNTITEM cMembers,LPCOLESTR *rgpwszMember,DBORDINAL *pulCellOrdinal);
  void __RPC_STUB IMDFind_FindCell_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMDFind_FindTuple_Proxy(IMDFind *This,ULONG ulAxisIdentifier,DBORDINAL ulStartingOrdinal,DBCOUNTITEM cMembers,LPCOLESTR *rgpwszMember,ULONG *pulTupleOrdinal);
  void __RPC_STUB IMDFind_FindTuple_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMDRangeRowset_INTERFACE_DEFINED__
#define __IMDRangeRowset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMDRangeRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMDRangeRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRangeRowset(IUnknown *pUnkOuter,DBORDINAL ulStartCell,DBORDINAL ulEndCell,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset) = 0;
  };
#else
  typedef struct IMDRangeRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMDRangeRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMDRangeRowset *This);
      ULONG (WINAPI *Release)(IMDRangeRowset *This);
      HRESULT (WINAPI *GetRangeRowset)(IMDRangeRowset *This,IUnknown *pUnkOuter,DBORDINAL ulStartCell,DBORDINAL ulEndCell,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
    END_INTERFACE
  } IMDRangeRowsetVtbl;
  struct IMDRangeRowset {
    CONST_VTBL struct IMDRangeRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMDRangeRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMDRangeRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMDRangeRowset_Release(This) (This)->lpVtbl->Release(This)
#define IMDRangeRowset_GetRangeRowset(This,pUnkOuter,ulStartCell,ulEndCell,riid,cPropertySets,rgPropertySets,ppRowset) (This)->lpVtbl->GetRangeRowset(This,pUnkOuter,ulStartCell,ulEndCell,riid,cPropertySets,rgPropertySets,ppRowset)
#endif
#endif
  HRESULT WINAPI IMDRangeRowset_GetRangeRowset_Proxy(IMDRangeRowset *This,IUnknown *pUnkOuter,DBORDINAL ulStartCell,DBORDINAL ulEndCell,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
  void __RPC_STUB IMDRangeRowset_GetRangeRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAlterTable_INTERFACE_DEFINED__
#define __IAlterTable_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAlterTable;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAlterTable : public IUnknown {
  public:
    virtual HRESULT WINAPI AlterColumn(DBID *pTableId,DBID *pColumnId,DBCOLUMNDESCFLAGS dwColumnDescFlags,DBCOLUMNDESC *pColumnDesc) = 0;
    virtual HRESULT WINAPI AlterTable(DBID *pTableId,DBID *pNewTableId,ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
  };
#else
  typedef struct IAlterTableVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAlterTable *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAlterTable *This);
      ULONG (WINAPI *Release)(IAlterTable *This);
      HRESULT (WINAPI *AlterColumn)(IAlterTable *This,DBID *pTableId,DBID *pColumnId,DBCOLUMNDESCFLAGS dwColumnDescFlags,DBCOLUMNDESC *pColumnDesc);
      HRESULT (WINAPI *AlterTable)(IAlterTable *This,DBID *pTableId,DBID *pNewTableId,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
    END_INTERFACE
  } IAlterTableVtbl;
  struct IAlterTable {
    CONST_VTBL struct IAlterTableVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAlterTable_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAlterTable_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAlterTable_Release(This) (This)->lpVtbl->Release(This)
#define IAlterTable_AlterColumn(This,pTableId,pColumnId,dwColumnDescFlags,pColumnDesc) (This)->lpVtbl->AlterColumn(This,pTableId,pColumnId,dwColumnDescFlags,pColumnDesc)
#define IAlterTable_AlterTable(This,pTableId,pNewTableId,cPropertySets,rgPropertySets) (This)->lpVtbl->AlterTable(This,pTableId,pNewTableId,cPropertySets,rgPropertySets)
#endif
#endif
  HRESULT WINAPI IAlterTable_AlterColumn_Proxy(IAlterTable *This,DBID *pTableId,DBID *pColumnId,DBCOLUMNDESCFLAGS dwColumnDescFlags,DBCOLUMNDESC *pColumnDesc);
  void __RPC_STUB IAlterTable_AlterColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAlterTable_AlterTable_Proxy(IAlterTable *This,DBID *pTableId,DBID *pNewTableId,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  void __RPC_STUB IAlterTable_AlterTable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAlterIndex_INTERFACE_DEFINED__
#define __IAlterIndex_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAlterIndex;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAlterIndex : public IUnknown {
  public:
    virtual HRESULT WINAPI AlterIndex(DBID *pTableId,DBID *pIndexId,DBID *pNewIndexId,ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
  };
#else
  typedef struct IAlterIndexVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAlterIndex *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAlterIndex *This);
      ULONG (WINAPI *Release)(IAlterIndex *This);
      HRESULT (WINAPI *AlterIndex)(IAlterIndex *This,DBID *pTableId,DBID *pIndexId,DBID *pNewIndexId,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
    END_INTERFACE
  } IAlterIndexVtbl;
  struct IAlterIndex {
    CONST_VTBL struct IAlterIndexVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAlterIndex_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAlterIndex_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAlterIndex_Release(This) (This)->lpVtbl->Release(This)
#define IAlterIndex_AlterIndex(This,pTableId,pIndexId,pNewIndexId,cPropertySets,rgPropertySets) (This)->lpVtbl->AlterIndex(This,pTableId,pIndexId,pNewIndexId,cPropertySets,rgPropertySets)
#endif
#endif
  HRESULT WINAPI IAlterIndex_AlterIndex_Proxy(IAlterIndex *This,DBID *pTableId,DBID *pIndexId,DBID *pNewIndexId,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  void __RPC_STUB IAlterIndex_AlterIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetChapterMember_INTERFACE_DEFINED__
#define __IRowsetChapterMember_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetChapterMember;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetChapterMember : public IUnknown {
  public:
    virtual HRESULT WINAPI IsRowInChapter(HCHAPTER hChapter,HROW hRow) = 0;
  };
#else
  typedef struct IRowsetChapterMemberVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetChapterMember *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetChapterMember *This);
      ULONG (WINAPI *Release)(IRowsetChapterMember *This);
      HRESULT (WINAPI *IsRowInChapter)(IRowsetChapterMember *This,HCHAPTER hChapter,HROW hRow);
    END_INTERFACE
  } IRowsetChapterMemberVtbl;
  struct IRowsetChapterMember {
    CONST_VTBL struct IRowsetChapterMemberVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetChapterMember_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetChapterMember_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetChapterMember_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetChapterMember_IsRowInChapter(This,hChapter,hRow) (This)->lpVtbl->IsRowInChapter(This,hChapter,hRow)
#endif
#endif
  HRESULT WINAPI IRowsetChapterMember_IsRowInChapter_Proxy(IRowsetChapterMember *This,HCHAPTER hChapter,HROW hRow);
  void __RPC_STUB IRowsetChapterMember_IsRowInChapter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICommandPersist_INTERFACE_DEFINED__
#define __ICommandPersist_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICommandPersist;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandPersist : public IUnknown {
  public:
    virtual HRESULT WINAPI DeleteCommand(DBID *pCommandID) = 0;
    virtual HRESULT WINAPI GetCurrentCommand(DBID **ppCommandID) = 0;
    virtual HRESULT WINAPI LoadCommand(DBID *pCommandID,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI SaveCommand(DBID *pCommandID,DWORD dwFlags) = 0;
  };
#else
  typedef struct ICommandPersistVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandPersist *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandPersist *This);
      ULONG (WINAPI *Release)(ICommandPersist *This);
      HRESULT (WINAPI *DeleteCommand)(ICommandPersist *This,DBID *pCommandID);
      HRESULT (WINAPI *GetCurrentCommand)(ICommandPersist *This,DBID **ppCommandID);
      HRESULT (WINAPI *LoadCommand)(ICommandPersist *This,DBID *pCommandID,DWORD dwFlags);
      HRESULT (WINAPI *SaveCommand)(ICommandPersist *This,DBID *pCommandID,DWORD dwFlags);
    END_INTERFACE
  } ICommandPersistVtbl;
  struct ICommandPersist {
    CONST_VTBL struct ICommandPersistVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandPersist_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandPersist_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandPersist_Release(This) (This)->lpVtbl->Release(This)
#define ICommandPersist_DeleteCommand(This,pCommandID) (This)->lpVtbl->DeleteCommand(This,pCommandID)
#define ICommandPersist_GetCurrentCommand(This,ppCommandID) (This)->lpVtbl->GetCurrentCommand(This,ppCommandID)
#define ICommandPersist_LoadCommand(This,pCommandID,dwFlags) (This)->lpVtbl->LoadCommand(This,pCommandID,dwFlags)
#define ICommandPersist_SaveCommand(This,pCommandID,dwFlags) (This)->lpVtbl->SaveCommand(This,pCommandID,dwFlags)
#endif
#endif
  HRESULT WINAPI ICommandPersist_DeleteCommand_Proxy(ICommandPersist *This,DBID *pCommandID);
  void __RPC_STUB ICommandPersist_DeleteCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandPersist_GetCurrentCommand_Proxy(ICommandPersist *This,DBID **ppCommandID);
  void __RPC_STUB ICommandPersist_GetCurrentCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandPersist_LoadCommand_Proxy(ICommandPersist *This,DBID *pCommandID,DWORD dwFlags);
  void __RPC_STUB ICommandPersist_LoadCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandPersist_SaveCommand_Proxy(ICommandPersist *This,DBID *pCommandID,DWORD dwFlags);
  void __RPC_STUB ICommandPersist_SaveCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetRefresh_INTERFACE_DEFINED__
#define __IRowsetRefresh_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetRefresh;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetRefresh : public IUnknown {
  public:
    virtual HRESULT WINAPI RefreshVisibleData(HCHAPTER hChapter,DBCOUNTITEM cRows,const HROW rghRows[],WINBOOL fOverWrite,DBCOUNTITEM *pcRowsRefreshed,HROW **prghRowsRefreshed,DBROWSTATUS **prgRowStatus) = 0;
    virtual HRESULT WINAPI GetLastVisibleData(HROW hRow,HACCESSOR hAccessor,void *pData) = 0;
  };
#else
  typedef struct IRowsetRefreshVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetRefresh *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetRefresh *This);
      ULONG (WINAPI *Release)(IRowsetRefresh *This);
      HRESULT (WINAPI *RefreshVisibleData)(IRowsetRefresh *This,HCHAPTER hChapter,DBCOUNTITEM cRows,const HROW rghRows[],WINBOOL fOverWrite,DBCOUNTITEM *pcRowsRefreshed,HROW **prghRowsRefreshed,DBROWSTATUS **prgRowStatus);
      HRESULT (WINAPI *GetLastVisibleData)(IRowsetRefresh *This,HROW hRow,HACCESSOR hAccessor,void *pData);
    END_INTERFACE
  } IRowsetRefreshVtbl;
  struct IRowsetRefresh {
    CONST_VTBL struct IRowsetRefreshVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetRefresh_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetRefresh_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetRefresh_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetRefresh_RefreshVisibleData(This,hChapter,cRows,rghRows,fOverWrite,pcRowsRefreshed,prghRowsRefreshed,prgRowStatus) (This)->lpVtbl->RefreshVisibleData(This,hChapter,cRows,rghRows,fOverWrite,pcRowsRefreshed,prghRowsRefreshed,prgRowStatus)
#define IRowsetRefresh_GetLastVisibleData(This,hRow,hAccessor,pData) (This)->lpVtbl->GetLastVisibleData(This,hRow,hAccessor,pData)
#endif
#endif
  HRESULT WINAPI IRowsetRefresh_RefreshVisibleData_Proxy(IRowsetRefresh *This,HCHAPTER hChapter,DBCOUNTITEM cRows,const HROW rghRows[],WINBOOL fOverWrite,DBCOUNTITEM *pcRowsRefreshed,HROW **prghRowsRefreshed,DBROWSTATUS **prgRowStatus);
  void __RPC_STUB IRowsetRefresh_RefreshVisibleData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetRefresh_GetLastVisibleData_Proxy(IRowsetRefresh *This,HROW hRow,HACCESSOR hAccessor,void *pData);
  void __RPC_STUB IRowsetRefresh_GetLastVisibleData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IParentRowset_INTERFACE_DEFINED__
#define __IParentRowset_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IParentRowset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IParentRowset : public IUnknown {
  public:
    virtual HRESULT WINAPI GetChildRowset(IUnknown *pUnkOuter,DBORDINAL iOrdinal,REFIID riid,IUnknown **ppRowset) = 0;
  };
#else
  typedef struct IParentRowsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IParentRowset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IParentRowset *This);
      ULONG (WINAPI *Release)(IParentRowset *This);
      HRESULT (WINAPI *GetChildRowset)(IParentRowset *This,IUnknown *pUnkOuter,DBORDINAL iOrdinal,REFIID riid,IUnknown **ppRowset);
    END_INTERFACE
  } IParentRowsetVtbl;
  struct IParentRowset {
    CONST_VTBL struct IParentRowsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IParentRowset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IParentRowset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IParentRowset_Release(This) (This)->lpVtbl->Release(This)
#define IParentRowset_GetChildRowset(This,pUnkOuter,iOrdinal,riid,ppRowset) (This)->lpVtbl->GetChildRowset(This,pUnkOuter,iOrdinal,riid,ppRowset)
#endif
#endif
  HRESULT WINAPI IParentRowset_GetChildRowset_Proxy(IParentRowset *This,IUnknown *pUnkOuter,DBORDINAL iOrdinal,REFIID riid,IUnknown **ppRowset);
  void __RPC_STUB IParentRowset_GetChildRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0320_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0320_v0_0_s_ifspec;

#ifndef __IErrorRecords_INTERFACE_DEFINED__
#define __IErrorRecords_INTERFACE_DEFINED__
#define IDENTIFIER_SDK_MASK 0xF0000000
#define IDENTIFIER_SDK_ERROR 0x10000000

  typedef struct tagERRORINFO {
    HRESULT hrError;
    DWORD dwMinor;
    CLSID clsid;
    IID iid;
    DISPID dispid;
  } ERRORINFO;

  EXTERN_C const IID IID_IErrorRecords;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IErrorRecords : public IUnknown {
  public:
    virtual HRESULT WINAPI AddErrorRecord(ERRORINFO *pErrorInfo,DWORD dwLookupID,DISPPARAMS *pdispparams,IUnknown *punkCustomError,DWORD dwDynamicErrorID) = 0;
    virtual HRESULT WINAPI GetBasicErrorInfo(ULONG ulRecordNum,ERRORINFO *pErrorInfo) = 0;
    virtual HRESULT WINAPI GetCustomErrorObject(ULONG ulRecordNum,REFIID riid,IUnknown **ppObject) = 0;
    virtual HRESULT WINAPI GetErrorInfo(ULONG ulRecordNum,LCID lcid,IErrorInfo **ppErrorInfo) = 0;
    virtual HRESULT WINAPI GetErrorParameters(ULONG ulRecordNum,DISPPARAMS *pdispparams) = 0;
    virtual HRESULT WINAPI GetRecordCount(ULONG *pcRecords) = 0;
  };
#else
  typedef struct IErrorRecordsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IErrorRecords *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IErrorRecords *This);
      ULONG (WINAPI *Release)(IErrorRecords *This);
      HRESULT (WINAPI *AddErrorRecord)(IErrorRecords *This,ERRORINFO *pErrorInfo,DWORD dwLookupID,DISPPARAMS *pdispparams,IUnknown *punkCustomError,DWORD dwDynamicErrorID);
      HRESULT (WINAPI *GetBasicErrorInfo)(IErrorRecords *This,ULONG ulRecordNum,ERRORINFO *pErrorInfo);
      HRESULT (WINAPI *GetCustomErrorObject)(IErrorRecords *This,ULONG ulRecordNum,REFIID riid,IUnknown **ppObject);
      HRESULT (WINAPI *GetErrorInfo)(IErrorRecords *This,ULONG ulRecordNum,LCID lcid,IErrorInfo **ppErrorInfo);
      HRESULT (WINAPI *GetErrorParameters)(IErrorRecords *This,ULONG ulRecordNum,DISPPARAMS *pdispparams);
      HRESULT (WINAPI *GetRecordCount)(IErrorRecords *This,ULONG *pcRecords);
    END_INTERFACE
  } IErrorRecordsVtbl;
  struct IErrorRecords {
    CONST_VTBL struct IErrorRecordsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IErrorRecords_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IErrorRecords_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IErrorRecords_Release(This) (This)->lpVtbl->Release(This)
#define IErrorRecords_AddErrorRecord(This,pErrorInfo,dwLookupID,pdispparams,punkCustomError,dwDynamicErrorID) (This)->lpVtbl->AddErrorRecord(This,pErrorInfo,dwLookupID,pdispparams,punkCustomError,dwDynamicErrorID)
#define IErrorRecords_GetBasicErrorInfo(This,ulRecordNum,pErrorInfo) (This)->lpVtbl->GetBasicErrorInfo(This,ulRecordNum,pErrorInfo)
#define IErrorRecords_GetCustomErrorObject(This,ulRecordNum,riid,ppObject) (This)->lpVtbl->GetCustomErrorObject(This,ulRecordNum,riid,ppObject)
#define IErrorRecords_GetErrorInfo(This,ulRecordNum,lcid,ppErrorInfo) (This)->lpVtbl->GetErrorInfo(This,ulRecordNum,lcid,ppErrorInfo)
#define IErrorRecords_GetErrorParameters(This,ulRecordNum,pdispparams) (This)->lpVtbl->GetErrorParameters(This,ulRecordNum,pdispparams)
#define IErrorRecords_GetRecordCount(This,pcRecords) (This)->lpVtbl->GetRecordCount(This,pcRecords)
#endif
#endif
  HRESULT WINAPI IErrorRecords_RemoteAddErrorRecord_Proxy(IErrorRecords *This,ERRORINFO *pErrorInfo,DWORD dwLookupID,DISPPARAMS *pdispparams,IUnknown *punkCustomError,DWORD dwDynamicErrorID,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorRecords_RemoteAddErrorRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IErrorRecords_RemoteGetBasicErrorInfo_Proxy(IErrorRecords *This,ULONG ulRecordNum,ERRORINFO *pErrorInfo,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorRecords_RemoteGetBasicErrorInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IErrorRecords_RemoteGetCustomErrorObject_Proxy(IErrorRecords *This,ULONG ulRecordNum,REFIID riid,IUnknown **ppObject,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorRecords_RemoteGetCustomErrorObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IErrorRecords_RemoteGetErrorInfo_Proxy(IErrorRecords *This,ULONG ulRecordNum,LCID lcid,IErrorInfo **ppErrorInfo,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorRecords_RemoteGetErrorInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IErrorRecords_RemoteGetErrorParameters_Proxy(IErrorRecords *This,ULONG ulRecordNum,DISPPARAMS *pdispparams,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorRecords_RemoteGetErrorParameters_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IErrorRecords_RemoteGetRecordCount_Proxy(IErrorRecords *This,ULONG *pcRecords,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorRecords_RemoteGetRecordCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IErrorLookup_INTERFACE_DEFINED__
#define __IErrorLookup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IErrorLookup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IErrorLookup : public IUnknown {
  public:
    virtual HRESULT WINAPI GetErrorDescription(HRESULT hrError,DWORD dwLookupID,DISPPARAMS *pdispparams,LCID lcid,BSTR *pbstrSource,BSTR *pbstrDescription) = 0;
    virtual HRESULT WINAPI GetHelpInfo(HRESULT hrError,DWORD dwLookupID,LCID lcid,BSTR *pbstrHelpFile,DWORD *pdwHelpContext) = 0;
    virtual HRESULT WINAPI ReleaseErrors(const DWORD dwDynamicErrorID) = 0;
  };
#else
  typedef struct IErrorLookupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IErrorLookup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IErrorLookup *This);
      ULONG (WINAPI *Release)(IErrorLookup *This);
      HRESULT (WINAPI *GetErrorDescription)(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,DISPPARAMS *pdispparams,LCID lcid,BSTR *pbstrSource,BSTR *pbstrDescription);
      HRESULT (WINAPI *GetHelpInfo)(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,LCID lcid,BSTR *pbstrHelpFile,DWORD *pdwHelpContext);
      HRESULT (WINAPI *ReleaseErrors)(IErrorLookup *This,const DWORD dwDynamicErrorID);
    END_INTERFACE
  } IErrorLookupVtbl;
  struct IErrorLookup {
    CONST_VTBL struct IErrorLookupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IErrorLookup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IErrorLookup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IErrorLookup_Release(This) (This)->lpVtbl->Release(This)
#define IErrorLookup_GetErrorDescription(This,hrError,dwLookupID,pdispparams,lcid,pbstrSource,pbstrDescription) (This)->lpVtbl->GetErrorDescription(This,hrError,dwLookupID,pdispparams,lcid,pbstrSource,pbstrDescription)
#define IErrorLookup_GetHelpInfo(This,hrError,dwLookupID,lcid,pbstrHelpFile,pdwHelpContext) (This)->lpVtbl->GetHelpInfo(This,hrError,dwLookupID,lcid,pbstrHelpFile,pdwHelpContext)
#define IErrorLookup_ReleaseErrors(This,dwDynamicErrorID) (This)->lpVtbl->ReleaseErrors(This,dwDynamicErrorID)
#endif
#endif
  HRESULT WINAPI IErrorLookup_RemoteGetErrorDescription_Proxy(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,DISPPARAMS *pdispparams,LCID lcid,BSTR *pbstrSource,BSTR *pbstrDescription,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorLookup_RemoteGetErrorDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IErrorLookup_RemoteGetHelpInfo_Proxy(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,LCID lcid,BSTR *pbstrHelpFile,DWORD *pdwHelpContext,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorLookup_RemoteGetHelpInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IErrorLookup_RemoteReleaseErrors_Proxy(IErrorLookup *This,const DWORD dwDynamicErrorID,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IErrorLookup_RemoteReleaseErrors_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISQLErrorInfo_INTERFACE_DEFINED__
#define __ISQLErrorInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISQLErrorInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISQLErrorInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSQLInfo(BSTR *pbstrSQLState,LONG *plNativeError) = 0;
  };
#else
  typedef struct ISQLErrorInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISQLErrorInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISQLErrorInfo *This);
      ULONG (WINAPI *Release)(ISQLErrorInfo *This);
      HRESULT (WINAPI *GetSQLInfo)(ISQLErrorInfo *This,BSTR *pbstrSQLState,LONG *plNativeError);
    END_INTERFACE
  } ISQLErrorInfoVtbl;
  struct ISQLErrorInfo {
    CONST_VTBL struct ISQLErrorInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISQLErrorInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISQLErrorInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISQLErrorInfo_Release(This) (This)->lpVtbl->Release(This)
#define ISQLErrorInfo_GetSQLInfo(This,pbstrSQLState,plNativeError) (This)->lpVtbl->GetSQLInfo(This,pbstrSQLState,plNativeError)
#endif
#endif
  HRESULT WINAPI ISQLErrorInfo_RemoteGetSQLInfo_Proxy(ISQLErrorInfo *This,BSTR *pbstrSQLState,LONG *plNativeError,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ISQLErrorInfo_RemoteGetSQLInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetDataSource_INTERFACE_DEFINED__
#define __IGetDataSource_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetDataSource;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetDataSource : public IUnknown {
  public:
    virtual HRESULT WINAPI GetDataSource(REFIID riid,IUnknown **ppDataSource) = 0;
  };
#else
  typedef struct IGetDataSourceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetDataSource *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetDataSource *This);
      ULONG (WINAPI *Release)(IGetDataSource *This);
      HRESULT (WINAPI *GetDataSource)(IGetDataSource *This,REFIID riid,IUnknown **ppDataSource);
    END_INTERFACE
  } IGetDataSourceVtbl;
  struct IGetDataSource {
    CONST_VTBL struct IGetDataSourceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetDataSource_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetDataSource_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetDataSource_Release(This) (This)->lpVtbl->Release(This)
#define IGetDataSource_GetDataSource(This,riid,ppDataSource) (This)->lpVtbl->GetDataSource(This,riid,ppDataSource)
#endif
#endif
  HRESULT WINAPI IGetDataSource_RemoteGetDataSource_Proxy(IGetDataSource *This,REFIID riid,IUnknown **ppDataSource,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB IGetDataSource_RemoteGetDataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionLocal_INTERFACE_DEFINED__
#define __ITransactionLocal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionLocal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionLocal : public ITransaction {
  public:
    virtual HRESULT WINAPI GetOptionsObject(ITransactionOptions **ppOptions) = 0;
    virtual HRESULT WINAPI StartTransaction(ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions,ULONG *pulTransactionLevel) = 0;
  };
#else
  typedef struct ITransactionLocalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionLocal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionLocal *This);
      ULONG (WINAPI *Release)(ITransactionLocal *This);
      HRESULT (WINAPI *Commit)(ITransactionLocal *This,WINBOOL fRetaining,DWORD grfTC,DWORD grfRM);
      HRESULT (WINAPI *Abort)(ITransactionLocal *This,BOID *pboidReason,WINBOOL fRetaining,WINBOOL fAsync);
      HRESULT (WINAPI *GetTransactionInfo)(ITransactionLocal *This,XACTTRANSINFO *pinfo);
      HRESULT (WINAPI *GetOptionsObject)(ITransactionLocal *This,ITransactionOptions **ppOptions);
      HRESULT (WINAPI *StartTransaction)(ITransactionLocal *This,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions,ULONG *pulTransactionLevel);
    END_INTERFACE
  } ITransactionLocalVtbl;
  struct ITransactionLocal {
    CONST_VTBL struct ITransactionLocalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionLocal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionLocal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionLocal_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionLocal_Commit(This,fRetaining,grfTC,grfRM) (This)->lpVtbl->Commit(This,fRetaining,grfTC,grfRM)
#define ITransactionLocal_Abort(This,pboidReason,fRetaining,fAsync) (This)->lpVtbl->Abort(This,pboidReason,fRetaining,fAsync)
#define ITransactionLocal_GetTransactionInfo(This,pinfo) (This)->lpVtbl->GetTransactionInfo(This,pinfo)
#define ITransactionLocal_GetOptionsObject(This,ppOptions) (This)->lpVtbl->GetOptionsObject(This,ppOptions)
#define ITransactionLocal_StartTransaction(This,isoLevel,isoFlags,pOtherOptions,pulTransactionLevel) (This)->lpVtbl->StartTransaction(This,isoLevel,isoFlags,pOtherOptions,pulTransactionLevel)
#endif
#endif
  HRESULT WINAPI ITransactionLocal_RemoteGetOptionsObject_Proxy(ITransactionLocal *This,ITransactionOptions **ppOptions,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITransactionLocal_RemoteGetOptionsObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionLocal_RemoteStartTransaction_Proxy(ITransactionLocal *This,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions,ULONG *pulTransactionLevel,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITransactionLocal_RemoteStartTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionJoin_INTERFACE_DEFINED__
#define __ITransactionJoin_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionJoin;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionJoin : public IUnknown {
  public:
    virtual HRESULT WINAPI GetOptionsObject(ITransactionOptions **ppOptions) = 0;
    virtual HRESULT WINAPI JoinTransaction(IUnknown *punkTransactionCoord,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions) = 0;
  };
#else
  typedef struct ITransactionJoinVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionJoin *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionJoin *This);
      ULONG (WINAPI *Release)(ITransactionJoin *This);
      HRESULT (WINAPI *GetOptionsObject)(ITransactionJoin *This,ITransactionOptions **ppOptions);
      HRESULT (WINAPI *JoinTransaction)(ITransactionJoin *This,IUnknown *punkTransactionCoord,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions);
    END_INTERFACE
  } ITransactionJoinVtbl;
  struct ITransactionJoin {
    CONST_VTBL struct ITransactionJoinVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionJoin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionJoin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionJoin_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionJoin_GetOptionsObject(This,ppOptions) (This)->lpVtbl->GetOptionsObject(This,ppOptions)
#define ITransactionJoin_JoinTransaction(This,punkTransactionCoord,isoLevel,isoFlags,pOtherOptions) (This)->lpVtbl->JoinTransaction(This,punkTransactionCoord,isoLevel,isoFlags,pOtherOptions)
#endif
#endif
  HRESULT WINAPI ITransactionJoin_RemoteGetOptionsObject_Proxy(ITransactionJoin *This,ITransactionOptions **ppOptions,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITransactionJoin_RemoteGetOptionsObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionJoin_RemoteJoinTransaction_Proxy(ITransactionJoin *This,IUnknown *punkTransactionCoord,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITransactionJoin_RemoteJoinTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionObject_INTERFACE_DEFINED__
#define __ITransactionObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionObject : public IUnknown {
  public:
    virtual HRESULT WINAPI GetTransactionObject(ULONG ulTransactionLevel,ITransaction **ppTransactionObject) = 0;
  };
#else
  typedef struct ITransactionObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionObject *This);
      ULONG (WINAPI *Release)(ITransactionObject *This);
      HRESULT (WINAPI *GetTransactionObject)(ITransactionObject *This,ULONG ulTransactionLevel,ITransaction **ppTransactionObject);
    END_INTERFACE
  } ITransactionObjectVtbl;
  struct ITransactionObject {
    CONST_VTBL struct ITransactionObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionObject_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionObject_GetTransactionObject(This,ulTransactionLevel,ppTransactionObject) (This)->lpVtbl->GetTransactionObject(This,ulTransactionLevel,ppTransactionObject)
#endif
#endif
  HRESULT WINAPI ITransactionObject_RemoteGetTransactionObject_Proxy(ITransactionObject *This,ULONG ulTransactionLevel,ITransaction **ppTransactionObject,IErrorInfo **ppErrorInfoRem);
  void __RPC_STUB ITransactionObject_RemoteGetTransactionObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#if (OLEDBVER >= 0x0210)
#ifndef UNDER_CE
#include <accctrl.h>

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0334_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0334_v0_0_s_ifspec;

#ifndef __ITrusteeAdmin_INTERFACE_DEFINED__
#define __ITrusteeAdmin_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITrusteeAdmin;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITrusteeAdmin : public IUnknown {
  public:
    virtual HRESULT WINAPI CompareTrustees(TRUSTEE_W *pTrustee1,TRUSTEE_W *pTrustee2) = 0;
    virtual HRESULT WINAPI CreateTrustee(TRUSTEE_W *pTrustee,ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
    virtual HRESULT WINAPI DeleteTrustee(TRUSTEE_W *pTrustee) = 0;
    virtual HRESULT WINAPI SetTrusteeProperties(TRUSTEE_W *pTrustee,ULONG cPropertySets,DBPROPSET rgPropertySets[]) = 0;
    virtual HRESULT WINAPI GetTrusteeProperties(TRUSTEE_W *pTrustee,const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets) = 0;
  };
#else
  typedef struct ITrusteeAdminVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITrusteeAdmin *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITrusteeAdmin *This);
      ULONG (WINAPI *Release)(ITrusteeAdmin *This);
      HRESULT (WINAPI *CompareTrustees)(ITrusteeAdmin *This,TRUSTEE_W *pTrustee1,TRUSTEE_W *pTrustee2);
      HRESULT (WINAPI *CreateTrustee)(ITrusteeAdmin *This,TRUSTEE_W *pTrustee,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
      HRESULT (WINAPI *DeleteTrustee)(ITrusteeAdmin *This,TRUSTEE_W *pTrustee);
      HRESULT (WINAPI *SetTrusteeProperties)(ITrusteeAdmin *This,TRUSTEE_W *pTrustee,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
      HRESULT (WINAPI *GetTrusteeProperties)(ITrusteeAdmin *This,TRUSTEE_W *pTrustee,const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
    END_INTERFACE
  } ITrusteeAdminVtbl;
  struct ITrusteeAdmin {
    CONST_VTBL struct ITrusteeAdminVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITrusteeAdmin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITrusteeAdmin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITrusteeAdmin_Release(This) (This)->lpVtbl->Release(This)
#define ITrusteeAdmin_CompareTrustees(This,pTrustee1,pTrustee2) (This)->lpVtbl->CompareTrustees(This,pTrustee1,pTrustee2)
#define ITrusteeAdmin_CreateTrustee(This,pTrustee,cPropertySets,rgPropertySets) (This)->lpVtbl->CreateTrustee(This,pTrustee,cPropertySets,rgPropertySets)
#define ITrusteeAdmin_DeleteTrustee(This,pTrustee) (This)->lpVtbl->DeleteTrustee(This,pTrustee)
#define ITrusteeAdmin_SetTrusteeProperties(This,pTrustee,cPropertySets,rgPropertySets) (This)->lpVtbl->SetTrusteeProperties(This,pTrustee,cPropertySets,rgPropertySets)
#define ITrusteeAdmin_GetTrusteeProperties(This,pTrustee,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets) (This)->lpVtbl->GetTrusteeProperties(This,pTrustee,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets)
#endif
#endif
  HRESULT WINAPI ITrusteeAdmin_CompareTrustees_Proxy(ITrusteeAdmin *This,TRUSTEE_W *pTrustee1,TRUSTEE_W *pTrustee2);
  void __RPC_STUB ITrusteeAdmin_CompareTrustees_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeAdmin_CreateTrustee_Proxy(ITrusteeAdmin *This,TRUSTEE_W *pTrustee,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  void __RPC_STUB ITrusteeAdmin_CreateTrustee_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeAdmin_DeleteTrustee_Proxy(ITrusteeAdmin *This,TRUSTEE_W *pTrustee);
  void __RPC_STUB ITrusteeAdmin_DeleteTrustee_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeAdmin_SetTrusteeProperties_Proxy(ITrusteeAdmin *This,TRUSTEE_W *pTrustee,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  void __RPC_STUB ITrusteeAdmin_SetTrusteeProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeAdmin_GetTrusteeProperties_Proxy(ITrusteeAdmin *This,TRUSTEE_W *pTrustee,const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
  void __RPC_STUB ITrusteeAdmin_GetTrusteeProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITrusteeGroupAdmin_INTERFACE_DEFINED__
#define __ITrusteeGroupAdmin_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITrusteeGroupAdmin;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITrusteeGroupAdmin : public IUnknown {
  public:
    virtual HRESULT WINAPI AddMember(TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee) = 0;
    virtual HRESULT WINAPI DeleteMember(TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee) = 0;
    virtual HRESULT WINAPI IsMember(TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee,WINBOOL *pfStatus) = 0;
    virtual HRESULT WINAPI GetMembers(TRUSTEE_W *pMembershipTrustee,ULONG *pcMembers,TRUSTEE_W **prgMembers) = 0;
    virtual HRESULT WINAPI GetMemberships(TRUSTEE_W *pTrustee,ULONG *pcMemberships,TRUSTEE_W **prgMemberships) = 0;
  };
#else
  typedef struct ITrusteeGroupAdminVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITrusteeGroupAdmin *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITrusteeGroupAdmin *This);
      ULONG (WINAPI *Release)(ITrusteeGroupAdmin *This);
      HRESULT (WINAPI *AddMember)(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee);
      HRESULT (WINAPI *DeleteMember)(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee);
      HRESULT (WINAPI *IsMember)(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee,WINBOOL *pfStatus);
      HRESULT (WINAPI *GetMembers)(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,ULONG *pcMembers,TRUSTEE_W **prgMembers);
      HRESULT (WINAPI *GetMemberships)(ITrusteeGroupAdmin *This,TRUSTEE_W *pTrustee,ULONG *pcMemberships,TRUSTEE_W **prgMemberships);
    END_INTERFACE
  } ITrusteeGroupAdminVtbl;
  struct ITrusteeGroupAdmin {
    CONST_VTBL struct ITrusteeGroupAdminVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITrusteeGroupAdmin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITrusteeGroupAdmin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITrusteeGroupAdmin_Release(This) (This)->lpVtbl->Release(This)
#define ITrusteeGroupAdmin_AddMember(This,pMembershipTrustee,pMemberTrustee) (This)->lpVtbl->AddMember(This,pMembershipTrustee,pMemberTrustee)
#define ITrusteeGroupAdmin_DeleteMember(This,pMembershipTrustee,pMemberTrustee) (This)->lpVtbl->DeleteMember(This,pMembershipTrustee,pMemberTrustee)
#define ITrusteeGroupAdmin_IsMember(This,pMembershipTrustee,pMemberTrustee,pfStatus) (This)->lpVtbl->IsMember(This,pMembershipTrustee,pMemberTrustee,pfStatus)
#define ITrusteeGroupAdmin_GetMembers(This,pMembershipTrustee,pcMembers,prgMembers) (This)->lpVtbl->GetMembers(This,pMembershipTrustee,pcMembers,prgMembers)
#define ITrusteeGroupAdmin_GetMemberships(This,pTrustee,pcMemberships,prgMemberships) (This)->lpVtbl->GetMemberships(This,pTrustee,pcMemberships,prgMemberships)
#endif
#endif
  HRESULT WINAPI ITrusteeGroupAdmin_AddMember_Proxy(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee);
  void __RPC_STUB ITrusteeGroupAdmin_AddMember_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeGroupAdmin_DeleteMember_Proxy(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee);
  void __RPC_STUB ITrusteeGroupAdmin_DeleteMember_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeGroupAdmin_IsMember_Proxy(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,TRUSTEE_W *pMemberTrustee,WINBOOL *pfStatus);
  void __RPC_STUB ITrusteeGroupAdmin_IsMember_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeGroupAdmin_GetMembers_Proxy(ITrusteeGroupAdmin *This,TRUSTEE_W *pMembershipTrustee,ULONG *pcMembers,TRUSTEE_W **prgMembers);
  void __RPC_STUB ITrusteeGroupAdmin_GetMembers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITrusteeGroupAdmin_GetMemberships_Proxy(ITrusteeGroupAdmin *This,TRUSTEE_W *pTrustee,ULONG *pcMemberships,TRUSTEE_W **prgMemberships);
  void __RPC_STUB ITrusteeGroupAdmin_GetMemberships_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectAccessControl_INTERFACE_DEFINED__
#define __IObjectAccessControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectAccessControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectAccessControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GetObjectAccessRights(SEC_OBJECT *pObject,ULONG *pcAccessEntries,EXPLICIT_ACCESS_W **prgAccessEntries) = 0;
    virtual HRESULT WINAPI GetObjectOwner(SEC_OBJECT *pObject,TRUSTEE_W **ppOwner) = 0;
    virtual HRESULT WINAPI IsObjectAccessAllowed(SEC_OBJECT *pObject,EXPLICIT_ACCESS_W *pAccessEntry,WINBOOL *pfResult) = 0;
    virtual HRESULT WINAPI SetObjectAccessRights(SEC_OBJECT *pObject,ULONG cAccessEntries,EXPLICIT_ACCESS_W *prgAccessEntries) = 0;
    virtual HRESULT WINAPI SetObjectOwner(SEC_OBJECT *pObject,TRUSTEE_W *pOwner) = 0;
  };
#else
  typedef struct IObjectAccessControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectAccessControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectAccessControl *This);
      ULONG (WINAPI *Release)(IObjectAccessControl *This);
      HRESULT (WINAPI *GetObjectAccessRights)(IObjectAccessControl *This,SEC_OBJECT *pObject,ULONG *pcAccessEntries,EXPLICIT_ACCESS_W **prgAccessEntries);
      HRESULT (WINAPI *GetObjectOwner)(IObjectAccessControl *This,SEC_OBJECT *pObject,TRUSTEE_W **ppOwner);
      HRESULT (WINAPI *IsObjectAccessAllowed)(IObjectAccessControl *This,SEC_OBJECT *pObject,EXPLICIT_ACCESS_W *pAccessEntry,WINBOOL *pfResult);
      HRESULT (WINAPI *SetObjectAccessRights)(IObjectAccessControl *This,SEC_OBJECT *pObject,ULONG cAccessEntries,EXPLICIT_ACCESS_W *prgAccessEntries);
      HRESULT (WINAPI *SetObjectOwner)(IObjectAccessControl *This,SEC_OBJECT *pObject,TRUSTEE_W *pOwner);
    END_INTERFACE
  } IObjectAccessControlVtbl;
  struct IObjectAccessControl {
    CONST_VTBL struct IObjectAccessControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectAccessControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectAccessControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectAccessControl_Release(This) (This)->lpVtbl->Release(This)
#define IObjectAccessControl_GetObjectAccessRights(This,pObject,pcAccessEntries,prgAccessEntries) (This)->lpVtbl->GetObjectAccessRights(This,pObject,pcAccessEntries,prgAccessEntries)
#define IObjectAccessControl_GetObjectOwner(This,pObject,ppOwner) (This)->lpVtbl->GetObjectOwner(This,pObject,ppOwner)
#define IObjectAccessControl_IsObjectAccessAllowed(This,pObject,pAccessEntry,pfResult) (This)->lpVtbl->IsObjectAccessAllowed(This,pObject,pAccessEntry,pfResult)
#define IObjectAccessControl_SetObjectAccessRights(This,pObject,cAccessEntries,prgAccessEntries) (This)->lpVtbl->SetObjectAccessRights(This,pObject,cAccessEntries,prgAccessEntries)
#define IObjectAccessControl_SetObjectOwner(This,pObject,pOwner) (This)->lpVtbl->SetObjectOwner(This,pObject,pOwner)
#endif
#endif
  HRESULT WINAPI IObjectAccessControl_GetObjectAccessRights_Proxy(IObjectAccessControl *This,SEC_OBJECT *pObject,ULONG *pcAccessEntries,EXPLICIT_ACCESS_W **prgAccessEntries);
  void __RPC_STUB IObjectAccessControl_GetObjectAccessRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectAccessControl_GetObjectOwner_Proxy(IObjectAccessControl *This,SEC_OBJECT *pObject,TRUSTEE_W **ppOwner);
  void __RPC_STUB IObjectAccessControl_GetObjectOwner_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectAccessControl_IsObjectAccessAllowed_Proxy(IObjectAccessControl *This,SEC_OBJECT *pObject,EXPLICIT_ACCESS_W *pAccessEntry,WINBOOL *pfResult);
  void __RPC_STUB IObjectAccessControl_IsObjectAccessAllowed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectAccessControl_SetObjectAccessRights_Proxy(IObjectAccessControl *This,SEC_OBJECT *pObject,ULONG cAccessEntries,EXPLICIT_ACCESS_W *prgAccessEntries);
  void __RPC_STUB IObjectAccessControl_SetObjectAccessRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectAccessControl_SetObjectOwner_Proxy(IObjectAccessControl *This,SEC_OBJECT *pObject,TRUSTEE_W *pOwner);
  void __RPC_STUB IObjectAccessControl_SetObjectOwner_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISecurityInfo_INTERFACE_DEFINED__
#define __ISecurityInfo_INTERFACE_DEFINED__
#if (OLEDBVER >= 0x0210)
  typedef DWORD ACCESS_MASK;

  enum ACCESS_MASKENUM {
    PERM_EXCLUSIVE = 0x200,PERM_READDESIGN = 0x400,PERM_WRITEDESIGN = 0x800,PERM_WITHGRANT = 0x1000,PERM_REFERENCE = 0x2000,
    PERM_CREATE = 0x4000,PERM_INSERT = 0x8000,PERM_DELETE = 0x10000,PERM_READCONTROL = 0x20000,PERM_WRITEPERMISSIONS = 0x40000,
    PERM_WRITEOWNER = 0x80000,PERM_MAXIMUM_ALLOWED = 0x2000000,PERM_ALL = 0x10000000,PERM_EXECUTE = 0x20000000,PERM_READ = 0x80000000,
    PERM_UPDATE = 0x40000000,PERM_DROP = 0x100
  };
#define PERM_DESIGN PERM_WRITEDESIGN
#endif

  EXTERN_C const IID IID_ISecurityInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISecurityInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCurrentTrustee(TRUSTEE_W **ppTrustee) = 0;
    virtual HRESULT WINAPI GetObjectTypes(ULONG *cObjectTypes,GUID **rgObjectTypes) = 0;
    virtual HRESULT WINAPI GetPermissions(GUID ObjectType,ACCESS_MASK *pPermissions) = 0;
  };
#else
  typedef struct ISecurityInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISecurityInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISecurityInfo *This);
      ULONG (WINAPI *Release)(ISecurityInfo *This);
      HRESULT (WINAPI *GetCurrentTrustee)(ISecurityInfo *This,TRUSTEE_W **ppTrustee);
      HRESULT (WINAPI *GetObjectTypes)(ISecurityInfo *This,ULONG *cObjectTypes,GUID **rgObjectTypes);
      HRESULT (WINAPI *GetPermissions)(ISecurityInfo *This,GUID ObjectType,ACCESS_MASK *pPermissions);
    END_INTERFACE
  } ISecurityInfoVtbl;
  struct ISecurityInfo {
    CONST_VTBL struct ISecurityInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISecurityInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISecurityInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISecurityInfo_Release(This) (This)->lpVtbl->Release(This)
#define ISecurityInfo_GetCurrentTrustee(This,ppTrustee) (This)->lpVtbl->GetCurrentTrustee(This,ppTrustee)
#define ISecurityInfo_GetObjectTypes(This,cObjectTypes,rgObjectTypes) (This)->lpVtbl->GetObjectTypes(This,cObjectTypes,rgObjectTypes)
#define ISecurityInfo_GetPermissions(This,ObjectType,pPermissions) (This)->lpVtbl->GetPermissions(This,ObjectType,pPermissions)
#endif
#endif
  HRESULT WINAPI ISecurityInfo_GetCurrentTrustee_Proxy(ISecurityInfo *This,TRUSTEE_W **ppTrustee);
  void __RPC_STUB ISecurityInfo_GetCurrentTrustee_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityInfo_GetObjectTypes_Proxy(ISecurityInfo *This,ULONG *cObjectTypes,GUID **rgObjectTypes);
  void __RPC_STUB ISecurityInfo_GetObjectTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityInfo_GetPermissions_Proxy(ISecurityInfo *This,GUID ObjectType,ACCESS_MASK *pPermissions);
  void __RPC_STUB ISecurityInfo_GetPermissions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0338_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0338_v0_0_s_ifspec;

#ifndef __ITableCreation_INTERFACE_DEFINED__
#define __ITableCreation_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITableCreation;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITableCreation : public ITableDefinition {
  public:
    virtual HRESULT WINAPI GetTableDefinition(DBID *pTableID,DBORDINAL *pcColumnDescs,DBCOLUMNDESC *prgColumnDescs[],ULONG *pcPropertySets,DBPROPSET *prgPropertySets[],ULONG *pcConstraintDescs,DBCONSTRAINTDESC *prgConstraintDescs[],OLECHAR **ppwszStringBuffer) = 0;
  };
#else
  typedef struct ITableCreationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITableCreation *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITableCreation *This);
      ULONG (WINAPI *Release)(ITableCreation *This);
      HRESULT (WINAPI *CreateTable)(ITableCreation *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,const DBCOLUMNDESC rgColumnDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset);
      HRESULT (WINAPI *DropTable)(ITableCreation *This,DBID *pTableID);
      HRESULT (WINAPI *AddColumn)(ITableCreation *This,DBID *pTableID,DBCOLUMNDESC *pColumnDesc,DBID **ppColumnID);
      HRESULT (WINAPI *DropColumn)(ITableCreation *This,DBID *pTableID,DBID *pColumnID);
      HRESULT (WINAPI *GetTableDefinition)(ITableCreation *This,DBID *pTableID,DBORDINAL *pcColumnDescs,DBCOLUMNDESC *prgColumnDescs[],ULONG *pcPropertySets,DBPROPSET *prgPropertySets[],ULONG *pcConstraintDescs,DBCONSTRAINTDESC *prgConstraintDescs[],OLECHAR **ppwszStringBuffer);
    END_INTERFACE
  } ITableCreationVtbl;
  struct ITableCreation {
    CONST_VTBL struct ITableCreationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITableCreation_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITableCreation_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITableCreation_Release(This) (This)->lpVtbl->Release(This)
#define ITableCreation_CreateTable(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset) (This)->lpVtbl->CreateTable(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset)
#define ITableCreation_DropTable(This,pTableID) (This)->lpVtbl->DropTable(This,pTableID)
#define ITableCreation_AddColumn(This,pTableID,pColumnDesc,ppColumnID) (This)->lpVtbl->AddColumn(This,pTableID,pColumnDesc,ppColumnID)
#define ITableCreation_DropColumn(This,pTableID,pColumnID) (This)->lpVtbl->DropColumn(This,pTableID,pColumnID)
#define ITableCreation_GetTableDefinition(This,pTableID,pcColumnDescs,prgColumnDescs,pcPropertySets,prgPropertySets,pcConstraintDescs,prgConstraintDescs,ppwszStringBuffer) (This)->lpVtbl->GetTableDefinition(This,pTableID,pcColumnDescs,prgColumnDescs,pcPropertySets,prgPropertySets,pcConstraintDescs,prgConstraintDescs,ppwszStringBuffer)
#endif
#endif
  HRESULT WINAPI ITableCreation_GetTableDefinition_Proxy(ITableCreation *This,DBID *pTableID,DBORDINAL *pcColumnDescs,DBCOLUMNDESC *prgColumnDescs[],ULONG *pcPropertySets,DBPROPSET *prgPropertySets[],ULONG *pcConstraintDescs,DBCONSTRAINTDESC *prgConstraintDescs[],OLECHAR **ppwszStringBuffer);
  void __RPC_STUB ITableCreation_GetTableDefinition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITableDefinitionWithConstraints_INTERFACE_DEFINED__
#define __ITableDefinitionWithConstraints_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITableDefinitionWithConstraints;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITableDefinitionWithConstraints : public ITableCreation {
  public:
    virtual HRESULT WINAPI AddConstraint(DBID *pTableID,DBCONSTRAINTDESC *pConstraintDesc) = 0;
    virtual HRESULT WINAPI CreateTableWithConstraints(IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,DBCOLUMNDESC rgColumnDescs[],ULONG cConstraintDescs,DBCONSTRAINTDESC rgConstraintDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset) = 0;
    virtual HRESULT WINAPI DropConstraint(DBID *pTableID,DBID *pConstraintID) = 0;
  };
#else
  typedef struct ITableDefinitionWithConstraintsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITableDefinitionWithConstraints *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITableDefinitionWithConstraints *This);
      ULONG (WINAPI *Release)(ITableDefinitionWithConstraints *This);
      HRESULT (WINAPI *CreateTable)(ITableDefinitionWithConstraints *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,const DBCOLUMNDESC rgColumnDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset);
      HRESULT (WINAPI *DropTable)(ITableDefinitionWithConstraints *This,DBID *pTableID);
      HRESULT (WINAPI *AddColumn)(ITableDefinitionWithConstraints *This,DBID *pTableID,DBCOLUMNDESC *pColumnDesc,DBID **ppColumnID);
      HRESULT (WINAPI *DropColumn)(ITableDefinitionWithConstraints *This,DBID *pTableID,DBID *pColumnID);
      HRESULT (WINAPI *GetTableDefinition)(ITableDefinitionWithConstraints *This,DBID *pTableID,DBORDINAL *pcColumnDescs,DBCOLUMNDESC *prgColumnDescs[],ULONG *pcPropertySets,DBPROPSET *prgPropertySets[],ULONG *pcConstraintDescs,DBCONSTRAINTDESC *prgConstraintDescs[],OLECHAR **ppwszStringBuffer);
      HRESULT (WINAPI *AddConstraint)(ITableDefinitionWithConstraints *This,DBID *pTableID,DBCONSTRAINTDESC *pConstraintDesc);
      HRESULT (WINAPI *CreateTableWithConstraints)(ITableDefinitionWithConstraints *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,DBCOLUMNDESC rgColumnDescs[],ULONG cConstraintDescs,DBCONSTRAINTDESC rgConstraintDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset);
      HRESULT (WINAPI *DropConstraint)(ITableDefinitionWithConstraints *This,DBID *pTableID,DBID *pConstraintID);
    END_INTERFACE
  } ITableDefinitionWithConstraintsVtbl;
  struct ITableDefinitionWithConstraints {
    CONST_VTBL struct ITableDefinitionWithConstraintsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITableDefinitionWithConstraints_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITableDefinitionWithConstraints_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITableDefinitionWithConstraints_Release(This) (This)->lpVtbl->Release(This)
#define ITableDefinitionWithConstraints_CreateTable(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset) (This)->lpVtbl->CreateTable(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset)
#define ITableDefinitionWithConstraints_DropTable(This,pTableID) (This)->lpVtbl->DropTable(This,pTableID)
#define ITableDefinitionWithConstraints_AddColumn(This,pTableID,pColumnDesc,ppColumnID) (This)->lpVtbl->AddColumn(This,pTableID,pColumnDesc,ppColumnID)
#define ITableDefinitionWithConstraints_DropColumn(This,pTableID,pColumnID) (This)->lpVtbl->DropColumn(This,pTableID,pColumnID)
#define ITableDefinitionWithConstraints_GetTableDefinition(This,pTableID,pcColumnDescs,prgColumnDescs,pcPropertySets,prgPropertySets,pcConstraintDescs,prgConstraintDescs,ppwszStringBuffer) (This)->lpVtbl->GetTableDefinition(This,pTableID,pcColumnDescs,prgColumnDescs,pcPropertySets,prgPropertySets,pcConstraintDescs,prgConstraintDescs,ppwszStringBuffer)
#define ITableDefinitionWithConstraints_AddConstraint(This,pTableID,pConstraintDesc) (This)->lpVtbl->AddConstraint(This,pTableID,pConstraintDesc)
#define ITableDefinitionWithConstraints_CreateTableWithConstraints(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,cConstraintDescs,rgConstraintDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset) (This)->lpVtbl->CreateTableWithConstraints(This,pUnkOuter,pTableID,cColumnDescs,rgColumnDescs,cConstraintDescs,rgConstraintDescs,riid,cPropertySets,rgPropertySets,ppTableID,ppRowset)
#define ITableDefinitionWithConstraints_DropConstraint(This,pTableID,pConstraintID) (This)->lpVtbl->DropConstraint(This,pTableID,pConstraintID)
#endif
#endif
  HRESULT WINAPI ITableDefinitionWithConstraints_AddConstraint_Proxy(ITableDefinitionWithConstraints *This,DBID *pTableID,DBCONSTRAINTDESC *pConstraintDesc);
  void __RPC_STUB ITableDefinitionWithConstraints_AddConstraint_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITableDefinitionWithConstraints_CreateTableWithConstraints_Proxy(ITableDefinitionWithConstraints *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,DBCOLUMNDESC rgColumnDescs[],ULONG cConstraintDescs,DBCONSTRAINTDESC rgConstraintDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset);
  void __RPC_STUB ITableDefinitionWithConstraints_CreateTableWithConstraints_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITableDefinitionWithConstraints_DropConstraint_Proxy(ITableDefinitionWithConstraints *This,DBID *pTableID,DBID *pConstraintID);
  void __RPC_STUB ITableDefinitionWithConstraints_DropConstraint_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef UNDER_CE
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0339_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0339_v0_0_s_ifspec;
#ifndef __IRow_INTERFACE_DEFINED__
#define __IRow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRow;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRow : public IUnknown {
  public:
    virtual HRESULT WINAPI GetColumns(DBORDINAL cColumns,DBCOLUMNACCESS rgColumns[]) = 0;
    virtual HRESULT WINAPI GetSourceRowset(REFIID riid,IUnknown **ppRowset,HROW *phRow) = 0;
    virtual HRESULT WINAPI Open(IUnknown *pUnkOuter,DBID *pColumnID,REFGUID rguidColumnType,DWORD dwBindFlags,REFIID riid,IUnknown **ppUnk) = 0;
  };
#else
  typedef struct IRowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRow *This);
      ULONG (WINAPI *Release)(IRow *This);
      HRESULT (WINAPI *GetColumns)(IRow *This,DBORDINAL cColumns,DBCOLUMNACCESS rgColumns[]);
      HRESULT (WINAPI *GetSourceRowset)(IRow *This,REFIID riid,IUnknown **ppRowset,HROW *phRow);
      HRESULT (WINAPI *Open)(IRow *This,IUnknown *pUnkOuter,DBID *pColumnID,REFGUID rguidColumnType,DWORD dwBindFlags,REFIID riid,IUnknown **ppUnk);
    END_INTERFACE
  } IRowVtbl;
  struct IRow {
    CONST_VTBL struct IRowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRow_Release(This) (This)->lpVtbl->Release(This)
#define IRow_GetColumns(This,cColumns,rgColumns) (This)->lpVtbl->GetColumns(This,cColumns,rgColumns)
#define IRow_GetSourceRowset(This,riid,ppRowset,phRow) (This)->lpVtbl->GetSourceRowset(This,riid,ppRowset,phRow)
#define IRow_Open(This,pUnkOuter,pColumnID,rguidColumnType,dwBindFlags,riid,ppUnk) (This)->lpVtbl->Open(This,pUnkOuter,pColumnID,rguidColumnType,dwBindFlags,riid,ppUnk)
#endif
#endif
  HRESULT WINAPI IRow_GetColumns_Proxy(IRow *This,DBORDINAL cColumns,DBCOLUMNACCESS rgColumns[]);
  void __RPC_STUB IRow_GetColumns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRow_GetSourceRowset_Proxy(IRow *This,REFIID riid,IUnknown **ppRowset,HROW *phRow);
  void __RPC_STUB IRow_GetSourceRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRow_Open_Proxy(IRow *This,IUnknown *pUnkOuter,DBID *pColumnID,REFGUID rguidColumnType,DWORD dwBindFlags,REFIID riid,IUnknown **ppUnk);
  void __RPC_STUB IRow_Open_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowChange_INTERFACE_DEFINED__
#define __IRowChange_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowChange;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowChange : public IUnknown {
  public:
    virtual HRESULT WINAPI SetColumns(DBORDINAL cColumns,DBCOLUMNACCESS rgColumns[]) = 0;
  };
#else
  typedef struct IRowChangeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowChange *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowChange *This);
      ULONG (WINAPI *Release)(IRowChange *This);
      HRESULT (WINAPI *SetColumns)(IRowChange *This,DBORDINAL cColumns,DBCOLUMNACCESS rgColumns[]);
    END_INTERFACE
  } IRowChangeVtbl;
  struct IRowChange {
    CONST_VTBL struct IRowChangeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowChange_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowChange_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowChange_Release(This) (This)->lpVtbl->Release(This)
#define IRowChange_SetColumns(This,cColumns,rgColumns) (This)->lpVtbl->SetColumns(This,cColumns,rgColumns)
#endif
#endif
  HRESULT WINAPI IRowChange_SetColumns_Proxy(IRowChange *This,DBORDINAL cColumns,DBCOLUMNACCESS rgColumns[]);
  void __RPC_STUB IRowChange_SetColumns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowSchemaChange_INTERFACE_DEFINED__
#define __IRowSchemaChange_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowSchemaChange;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowSchemaChange : public IRowChange {
  public:
    virtual HRESULT WINAPI DeleteColumns(DBORDINAL cColumns,const DBID rgColumnIDs[],DBSTATUS rgdwStatus[]) = 0;
    virtual HRESULT WINAPI AddColumns(DBORDINAL cColumns,const DBCOLUMNINFO rgNewColumnInfo[],DBCOLUMNACCESS rgColumns[]) = 0;
  };
#else
  typedef struct IRowSchemaChangeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowSchemaChange *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowSchemaChange *This);
      ULONG (WINAPI *Release)(IRowSchemaChange *This);
      HRESULT (WINAPI *SetColumns)(IRowSchemaChange *This,DBORDINAL cColumns,DBCOLUMNACCESS rgColumns[]);
      HRESULT (WINAPI *DeleteColumns)(IRowSchemaChange *This,DBORDINAL cColumns,const DBID rgColumnIDs[],DBSTATUS rgdwStatus[]);
      HRESULT (WINAPI *AddColumns)(IRowSchemaChange *This,DBORDINAL cColumns,const DBCOLUMNINFO rgNewColumnInfo[],DBCOLUMNACCESS rgColumns[]);
    END_INTERFACE
  } IRowSchemaChangeVtbl;
  struct IRowSchemaChange {
    CONST_VTBL struct IRowSchemaChangeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowSchemaChange_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowSchemaChange_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowSchemaChange_Release(This) (This)->lpVtbl->Release(This)
#define IRowSchemaChange_SetColumns(This,cColumns,rgColumns) (This)->lpVtbl->SetColumns(This,cColumns,rgColumns)
#define IRowSchemaChange_DeleteColumns(This,cColumns,rgColumnIDs,rgdwStatus) (This)->lpVtbl->DeleteColumns(This,cColumns,rgColumnIDs,rgdwStatus)
#define IRowSchemaChange_AddColumns(This,cColumns,rgNewColumnInfo,rgColumns) (This)->lpVtbl->AddColumns(This,cColumns,rgNewColumnInfo,rgColumns)
#endif
#endif
  HRESULT WINAPI IRowSchemaChange_DeleteColumns_Proxy(IRowSchemaChange *This,DBORDINAL cColumns,const DBID rgColumnIDs[],DBSTATUS rgdwStatus[]);
  void __RPC_STUB IRowSchemaChange_DeleteColumns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowSchemaChange_AddColumns_Proxy(IRowSchemaChange *This,DBORDINAL cColumns,const DBCOLUMNINFO rgNewColumnInfo[],DBCOLUMNACCESS rgColumns[]);
  void __RPC_STUB IRowSchemaChange_AddColumns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetRow_INTERFACE_DEFINED__
#define __IGetRow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetRow;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetRow : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRowFromHROW(IUnknown *pUnkOuter,HROW hRow,REFIID riid,IUnknown **ppUnk) = 0;
    virtual HRESULT WINAPI GetURLFromHROW(HROW hRow,LPOLESTR *ppwszURL) = 0;
  };
#else
  typedef struct IGetRowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetRow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetRow *This);
      ULONG (WINAPI *Release)(IGetRow *This);
      HRESULT (WINAPI *GetRowFromHROW)(IGetRow *This,IUnknown *pUnkOuter,HROW hRow,REFIID riid,IUnknown **ppUnk);
      HRESULT (WINAPI *GetURLFromHROW)(IGetRow *This,HROW hRow,LPOLESTR *ppwszURL);
    END_INTERFACE
  } IGetRowVtbl;
  struct IGetRow {
    CONST_VTBL struct IGetRowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetRow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetRow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetRow_Release(This) (This)->lpVtbl->Release(This)
#define IGetRow_GetRowFromHROW(This,pUnkOuter,hRow,riid,ppUnk) (This)->lpVtbl->GetRowFromHROW(This,pUnkOuter,hRow,riid,ppUnk)
#define IGetRow_GetURLFromHROW(This,hRow,ppwszURL) (This)->lpVtbl->GetURLFromHROW(This,hRow,ppwszURL)
#endif
#endif
  HRESULT WINAPI IGetRow_GetRowFromHROW_Proxy(IGetRow *This,IUnknown *pUnkOuter,HROW hRow,REFIID riid,IUnknown **ppUnk);
  void __RPC_STUB IGetRow_GetRowFromHROW_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IGetRow_GetURLFromHROW_Proxy(IGetRow *This,HROW hRow,LPOLESTR *ppwszURL);
  void __RPC_STUB IGetRow_GetURLFromHROW_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBindResource_INTERFACE_DEFINED__
#define __IBindResource_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBindResource;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBindResource : public IUnknown {
  public:
    virtual HRESULT WINAPI Bind(IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,DBIMPLICITSESSION *pImplSession,DBBINDURLSTATUS *pdwBindStatus,IUnknown **ppUnk) = 0;
  };
#else
  typedef struct IBindResourceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBindResource *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBindResource *This);
      ULONG (WINAPI *Release)(IBindResource *This);
      HRESULT (WINAPI *Bind)(IBindResource *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,DBIMPLICITSESSION *pImplSession,DBBINDURLSTATUS *pdwBindStatus,IUnknown **ppUnk);
    END_INTERFACE
  } IBindResourceVtbl;
  struct IBindResource {
    CONST_VTBL struct IBindResourceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBindResource_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBindResource_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBindResource_Release(This) (This)->lpVtbl->Release(This)
#define IBindResource_Bind(This,pUnkOuter,pwszURL,dwBindURLFlags,rguid,riid,pAuthenticate,pImplSession,pdwBindStatus,ppUnk) (This)->lpVtbl->Bind(This,pUnkOuter,pwszURL,dwBindURLFlags,rguid,riid,pAuthenticate,pImplSession,pdwBindStatus,ppUnk)
#endif
#endif
  HRESULT WINAPI IBindResource_RemoteBind_Proxy(IBindResource *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,IUnknown *pSessionUnkOuter,IID *piid,IUnknown **ppSession,DBBINDURLSTATUS *pdwBindStatus,IUnknown **ppUnk);
  void __RPC_STUB IBindResource_RemoteBind_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IScopedOperations_INTERFACE_DEFINED__
#define __IScopedOperations_INTERFACE_DEFINED__
  typedef DWORD DBCOPYFLAGS;

  enum DBCOPYFLAGSENUM {
    DBCOPY_ASYNC = 0x100,DBCOPY_REPLACE_EXISTING = 0x200,DBCOPY_ALLOW_EMULATION = 0x400,DBCOPY_NON_RECURSIVE = 0x800,DBCOPY_ATOMIC = 0x1000
  };
  typedef DWORD DBMOVEFLAGS;

  enum DBMOVEFLAGSENUM {
    DBMOVE_REPLACE_EXISTING = 0x1,DBMOVE_ASYNC = 0x100,DBMOVE_DONT_UPDATE_LINKS = 0x200,DBMOVE_ALLOW_EMULATION = 0x400,DBMOVE_ATOMIC = 0x1000
  };
  typedef DWORD DBDELETEFLAGS;

  enum DBDELETEFLAGSENUM {
    DBDELETE_ASYNC = 0x100,DBDELETE_ATOMIC = 0x1000
  };

  EXTERN_C const IID IID_IScopedOperations;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IScopedOperations : public IBindResource {
  public:
    virtual HRESULT WINAPI Copy(DBCOUNTITEM cRows,LPCOLESTR rgpwszSourceURLs[],LPCOLESTR rgpwszDestURLs[],DWORD dwCopyFlags,IAuthenticate *pAuthenticate,DBSTATUS rgdwStatus[],LPOLESTR rgpwszNewURLs[],OLECHAR **ppStringsBuffer) = 0;
    virtual HRESULT WINAPI Move(DBCOUNTITEM cRows,LPCOLESTR rgpwszSourceURLs[],LPCOLESTR rgpwszDestURLs[],DWORD dwMoveFlags,IAuthenticate *pAuthenticate,DBSTATUS rgdwStatus[],LPOLESTR rgpwszNewURLs[],OLECHAR **ppStringsBuffer) = 0;
    virtual HRESULT WINAPI Delete(DBCOUNTITEM cRows,LPCOLESTR rgpwszURLs[],DWORD dwDeleteFlags,DBSTATUS rgdwStatus[]) = 0;
    virtual HRESULT WINAPI OpenRowset(IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset) = 0;
  };
#else
  typedef struct IScopedOperationsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IScopedOperations *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IScopedOperations *This);
      ULONG (WINAPI *Release)(IScopedOperations *This);
      HRESULT (WINAPI *Bind)(IScopedOperations *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,DBIMPLICITSESSION *pImplSession,DBBINDURLSTATUS *pdwBindStatus,IUnknown **ppUnk);
      HRESULT (WINAPI *Copy)(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR rgpwszSourceURLs[],LPCOLESTR rgpwszDestURLs[],DWORD dwCopyFlags,IAuthenticate *pAuthenticate,DBSTATUS rgdwStatus[],LPOLESTR rgpwszNewURLs[],OLECHAR **ppStringsBuffer);
      HRESULT (WINAPI *Move)(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR rgpwszSourceURLs[],LPCOLESTR rgpwszDestURLs[],DWORD dwMoveFlags,IAuthenticate *pAuthenticate,DBSTATUS rgdwStatus[],LPOLESTR rgpwszNewURLs[],OLECHAR **ppStringsBuffer);
      HRESULT (WINAPI *Delete)(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR rgpwszURLs[],DWORD dwDeleteFlags,DBSTATUS rgdwStatus[]);
      HRESULT (WINAPI *OpenRowset)(IScopedOperations *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
    END_INTERFACE
  } IScopedOperationsVtbl;
  struct IScopedOperations {
    CONST_VTBL struct IScopedOperationsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IScopedOperations_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IScopedOperations_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IScopedOperations_Release(This) (This)->lpVtbl->Release(This)
#define IScopedOperations_Bind(This,pUnkOuter,pwszURL,dwBindURLFlags,rguid,riid,pAuthenticate,pImplSession,pdwBindStatus,ppUnk) (This)->lpVtbl->Bind(This,pUnkOuter,pwszURL,dwBindURLFlags,rguid,riid,pAuthenticate,pImplSession,pdwBindStatus,ppUnk)
#define IScopedOperations_Copy(This,cRows,rgpwszSourceURLs,rgpwszDestURLs,dwCopyFlags,pAuthenticate,rgdwStatus,rgpwszNewURLs,ppStringsBuffer) (This)->lpVtbl->Copy(This,cRows,rgpwszSourceURLs,rgpwszDestURLs,dwCopyFlags,pAuthenticate,rgdwStatus,rgpwszNewURLs,ppStringsBuffer)
#define IScopedOperations_Move(This,cRows,rgpwszSourceURLs,rgpwszDestURLs,dwMoveFlags,pAuthenticate,rgdwStatus,rgpwszNewURLs,ppStringsBuffer) (This)->lpVtbl->Move(This,cRows,rgpwszSourceURLs,rgpwszDestURLs,dwMoveFlags,pAuthenticate,rgdwStatus,rgpwszNewURLs,ppStringsBuffer)
#define IScopedOperations_Delete(This,cRows,rgpwszURLs,dwDeleteFlags,rgdwStatus) (This)->lpVtbl->Delete(This,cRows,rgpwszURLs,dwDeleteFlags,rgdwStatus)
#define IScopedOperations_OpenRowset(This,pUnkOuter,pTableID,pIndexID,riid,cPropertySets,rgPropertySets,ppRowset) (This)->lpVtbl->OpenRowset(This,pUnkOuter,pTableID,pIndexID,riid,cPropertySets,rgPropertySets,ppRowset)
#endif
#endif
  HRESULT WINAPI IScopedOperations_RemoteCopy_Proxy(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR *rgpwszSourceURLs,LPCOLESTR *rgpwszDestURLs,DWORD dwCopyFlags,IAuthenticate *pAuthenticate,DBSTATUS *rgdwStatus,DBBYTEOFFSET **prgulNewURLOffsets,ULONG *pcbStringsBuffer,OLECHAR **ppStringsBuffer);
  void __RPC_STUB IScopedOperations_RemoteCopy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScopedOperations_RemoteMove_Proxy(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR *rgpwszSourceURLs,LPCOLESTR *rgpwszDestURLs,DWORD dwMoveFlags,IAuthenticate *pAuthenticate,DBSTATUS *rgdwStatus,DBBYTEOFFSET **prgulNewURLOffsets,ULONG *pcbStringsBuffer,OLECHAR **ppStringsBuffer);
  void __RPC_STUB IScopedOperations_RemoteMove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScopedOperations_RemoteDelete_Proxy(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR *rgpwszURLs,DWORD dwDeleteFlags,DBSTATUS *rgdwStatus);
  void __RPC_STUB IScopedOperations_RemoteDelete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScopedOperations_RemoteOpenRowset_Proxy(IScopedOperations *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus);
  void __RPC_STUB IScopedOperations_RemoteOpenRowset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICreateRow_INTERFACE_DEFINED__
#define __ICreateRow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICreateRow;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICreateRow : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateRow(IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,DBIMPLICITSESSION *pImplSession,DBBINDURLSTATUS *pdwBindStatus,LPOLESTR *ppwszNewURL,IUnknown **ppUnk) = 0;
  };
#else
  typedef struct ICreateRowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICreateRow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICreateRow *This);
      ULONG (WINAPI *Release)(ICreateRow *This);
      HRESULT (WINAPI *CreateRow)(ICreateRow *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,DBIMPLICITSESSION *pImplSession,DBBINDURLSTATUS *pdwBindStatus,LPOLESTR *ppwszNewURL,IUnknown **ppUnk);
    END_INTERFACE
  } ICreateRowVtbl;
  struct ICreateRow {
    CONST_VTBL struct ICreateRowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICreateRow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICreateRow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICreateRow_Release(This) (This)->lpVtbl->Release(This)
#define ICreateRow_CreateRow(This,pUnkOuter,pwszURL,dwBindURLFlags,rguid,riid,pAuthenticate,pImplSession,pdwBindStatus,ppwszNewURL,ppUnk) (This)->lpVtbl->CreateRow(This,pUnkOuter,pwszURL,dwBindURLFlags,rguid,riid,pAuthenticate,pImplSession,pdwBindStatus,ppwszNewURL,ppUnk)
#endif
#endif
  HRESULT WINAPI ICreateRow_RemoteCreateRow_Proxy(ICreateRow *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,IUnknown *pSessionUnkOuter,IID *piid,IUnknown **ppSession,DBBINDURLSTATUS *pdwBindStatus,LPOLESTR *ppwszNewURL,IUnknown **ppUnk);
  void __RPC_STUB ICreateRow_RemoteCreateRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDBBinderProperties_INTERFACE_DEFINED__
#define __IDBBinderProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDBBinderProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDBBinderProperties : public IDBProperties {
  public:
    virtual HRESULT WINAPI Reset(void) = 0;
  };
#else
  typedef struct IDBBinderPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDBBinderProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDBBinderProperties *This);
      ULONG (WINAPI *Release)(IDBBinderProperties *This);
      HRESULT (WINAPI *GetProperties)(IDBBinderProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
      HRESULT (WINAPI *GetPropertyInfo)(IDBBinderProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,OLECHAR **ppDescBuffer);
      HRESULT (WINAPI *SetProperties)(IDBBinderProperties *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
      HRESULT (WINAPI *Reset)(IDBBinderProperties *This);
    END_INTERFACE
  } IDBBinderPropertiesVtbl;
  struct IDBBinderProperties {
    CONST_VTBL struct IDBBinderPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDBBinderProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDBBinderProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDBBinderProperties_Release(This) (This)->lpVtbl->Release(This)
#define IDBBinderProperties_GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets) (This)->lpVtbl->GetProperties(This,cPropertyIDSets,rgPropertyIDSets,pcPropertySets,prgPropertySets)
#define IDBBinderProperties_GetPropertyInfo(This,cPropertyIDSets,rgPropertyIDSets,pcPropertyInfoSets,prgPropertyInfoSets,ppDescBuffer) (This)->lpVtbl->GetPropertyInfo(This,cPropertyIDSets,rgPropertyIDSets,pcPropertyInfoSets,prgPropertyInfoSets,ppDescBuffer)
#define IDBBinderProperties_SetProperties(This,cPropertySets,rgPropertySets) (This)->lpVtbl->SetProperties(This,cPropertySets,rgPropertySets)
#define IDBBinderProperties_Reset(This) (This)->lpVtbl->Reset(This)
#endif
#endif
  HRESULT WINAPI IDBBinderProperties_Reset_Proxy(IDBBinderProperties *This);
  void __RPC_STUB IDBBinderProperties_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IColumnsInfo2_INTERFACE_DEFINED__
#define __IColumnsInfo2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IColumnsInfo2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IColumnsInfo2 : public IColumnsInfo {
  public:
    virtual HRESULT WINAPI GetRestrictedColumnInfo(DBORDINAL cColumnIDMasks,const DBID rgColumnIDMasks[],DWORD dwFlags,DBORDINAL *pcColumns,DBID **prgColumnIDs,DBCOLUMNINFO **prgColumnInfo,OLECHAR **ppStringsBuffer) = 0;
  };
#else
  typedef struct IColumnsInfo2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IColumnsInfo2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IColumnsInfo2 *This);
      ULONG (WINAPI *Release)(IColumnsInfo2 *This);
      HRESULT (WINAPI *GetColumnInfo)(IColumnsInfo2 *This,DBORDINAL *pcColumns,DBCOLUMNINFO **prgInfo,OLECHAR **ppStringsBuffer);
      HRESULT (WINAPI *MapColumnIDs)(IColumnsInfo2 *This,DBORDINAL cColumnIDs,const DBID rgColumnIDs[],DBORDINAL rgColumns[]);
      HRESULT (WINAPI *GetRestrictedColumnInfo)(IColumnsInfo2 *This,DBORDINAL cColumnIDMasks,const DBID rgColumnIDMasks[],DWORD dwFlags,DBORDINAL *pcColumns,DBID **prgColumnIDs,DBCOLUMNINFO **prgColumnInfo,OLECHAR **ppStringsBuffer);
    END_INTERFACE
  } IColumnsInfo2Vtbl;
  struct IColumnsInfo2 {
    CONST_VTBL struct IColumnsInfo2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IColumnsInfo2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IColumnsInfo2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IColumnsInfo2_Release(This) (This)->lpVtbl->Release(This)
#define IColumnsInfo2_GetColumnInfo(This,pcColumns,prgInfo,ppStringsBuffer) (This)->lpVtbl->GetColumnInfo(This,pcColumns,prgInfo,ppStringsBuffer)
#define IColumnsInfo2_MapColumnIDs(This,cColumnIDs,rgColumnIDs,rgColumns) (This)->lpVtbl->MapColumnIDs(This,cColumnIDs,rgColumnIDs,rgColumns)
#define IColumnsInfo2_GetRestrictedColumnInfo(This,cColumnIDMasks,rgColumnIDMasks,dwFlags,pcColumns,prgColumnIDs,prgColumnInfo,ppStringsBuffer) (This)->lpVtbl->GetRestrictedColumnInfo(This,cColumnIDMasks,rgColumnIDMasks,dwFlags,pcColumns,prgColumnIDs,prgColumnInfo,ppStringsBuffer)
#endif
#endif
  HRESULT WINAPI IColumnsInfo2_RemoteGetRestrictedColumnInfo_Proxy(IColumnsInfo2 *This,DBORDINAL cColumnIDMasks,const DBID *rgColumnIDMasks,DWORD dwFlags,DBORDINAL *pcColumns,DBID **prgColumnIDs,DBCOLUMNINFO **prgColumnInfo,DBBYTEOFFSET **prgNameOffsets,DBBYTEOFFSET **prgcolumnidOffsets,DBLENGTH *pcbStringsBuffer,OLECHAR **ppStringsBuffer);
  void __RPC_STUB IColumnsInfo2_RemoteGetRestrictedColumnInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRegisterProvider_INTERFACE_DEFINED__
#define __IRegisterProvider_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRegisterProvider;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRegisterProvider : public IUnknown {
  public:
    virtual HRESULT WINAPI GetURLMapping(LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,CLSID *pclsidProvider) = 0;
    virtual HRESULT WINAPI SetURLMapping(LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,REFCLSID rclsidProvider) = 0;
    virtual HRESULT WINAPI UnregisterProvider(LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,REFCLSID rclsidProvider) = 0;
  };
#else
  typedef struct IRegisterProviderVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRegisterProvider *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRegisterProvider *This);
      ULONG (WINAPI *Release)(IRegisterProvider *This);
      HRESULT (WINAPI *GetURLMapping)(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,CLSID *pclsidProvider);
      HRESULT (WINAPI *SetURLMapping)(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,REFCLSID rclsidProvider);
      HRESULT (WINAPI *UnregisterProvider)(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,REFCLSID rclsidProvider);
    END_INTERFACE
  } IRegisterProviderVtbl;
  struct IRegisterProvider {
    CONST_VTBL struct IRegisterProviderVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRegisterProvider_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRegisterProvider_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRegisterProvider_Release(This) (This)->lpVtbl->Release(This)
#define IRegisterProvider_GetURLMapping(This,pwszURL,dwReserved,pclsidProvider) (This)->lpVtbl->GetURLMapping(This,pwszURL,dwReserved,pclsidProvider)
#define IRegisterProvider_SetURLMapping(This,pwszURL,dwReserved,rclsidProvider) (This)->lpVtbl->SetURLMapping(This,pwszURL,dwReserved,rclsidProvider)
#define IRegisterProvider_UnregisterProvider(This,pwszURL,dwReserved,rclsidProvider) (This)->lpVtbl->UnregisterProvider(This,pwszURL,dwReserved,rclsidProvider)
#endif
#endif
  HRESULT WINAPI IRegisterProvider_RemoteGetURLMapping_Proxy(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,CLSID *pclsidProvider);
  void __RPC_STUB IRegisterProvider_RemoteGetURLMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRegisterProvider_SetURLMapping_Proxy(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,REFCLSID rclsidProvider);
  void __RPC_STUB IRegisterProvider_SetURLMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRegisterProvider_UnregisterProvider_Proxy(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,REFCLSID rclsidProvider);
  void __RPC_STUB IRegisterProvider_UnregisterProvider_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0349_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0349_v0_0_s_ifspec;
#ifndef __IGetSession_INTERFACE_DEFINED__
#define __IGetSession_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetSession;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetSession : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSession(REFIID riid,IUnknown **ppSession) = 0;
  };
#else
  typedef struct IGetSessionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetSession *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetSession *This);
      ULONG (WINAPI *Release)(IGetSession *This);
      HRESULT (WINAPI *GetSession)(IGetSession *This,REFIID riid,IUnknown **ppSession);
    END_INTERFACE
  } IGetSessionVtbl;
  struct IGetSession {
    CONST_VTBL struct IGetSessionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetSession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetSession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetSession_Release(This) (This)->lpVtbl->Release(This)
#define IGetSession_GetSession(This,riid,ppSession) (This)->lpVtbl->GetSession(This,riid,ppSession)
#endif
#endif
  HRESULT WINAPI IGetSession_GetSession_Proxy(IGetSession *This,REFIID riid,IUnknown **ppSession);
  void __RPC_STUB IGetSession_GetSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetSourceRow_INTERFACE_DEFINED__
#define __IGetSourceRow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetSourceRow;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetSourceRow : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSourceRow(REFIID riid,IUnknown **ppRow) = 0;
  };
#else
  typedef struct IGetSourceRowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetSourceRow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetSourceRow *This);
      ULONG (WINAPI *Release)(IGetSourceRow *This);
      HRESULT (WINAPI *GetSourceRow)(IGetSourceRow *This,REFIID riid,IUnknown **ppRow);
    END_INTERFACE
  } IGetSourceRowVtbl;
  struct IGetSourceRow {
    CONST_VTBL struct IGetSourceRowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetSourceRow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetSourceRow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetSourceRow_Release(This) (This)->lpVtbl->Release(This)
#define IGetSourceRow_GetSourceRow(This,riid,ppRow) (This)->lpVtbl->GetSourceRow(This,riid,ppRow)
#endif
#endif
  HRESULT WINAPI IGetSourceRow_GetSourceRow_Proxy(IGetSourceRow *This,REFIID riid,IUnknown **ppRow);
  void __RPC_STUB IGetSourceRow_GetSourceRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetCurrentIndex_INTERFACE_DEFINED__
#define __IRowsetCurrentIndex_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetCurrentIndex;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetCurrentIndex : public IRowsetIndex {
  public:
    virtual HRESULT WINAPI GetIndex(DBID **ppIndexID) = 0;
    virtual HRESULT WINAPI SetIndex(DBID *pIndexID) = 0;
  };
#else
  typedef struct IRowsetCurrentIndexVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetCurrentIndex *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetCurrentIndex *This);
      ULONG (WINAPI *Release)(IRowsetCurrentIndex *This);
      HRESULT (WINAPI *GetIndexInfo)(IRowsetCurrentIndex *This,DBORDINAL *pcKeyColumns,DBINDEXCOLUMNDESC **prgIndexColumnDesc,ULONG *pcIndexPropertySets,DBPROPSET **prgIndexPropertySets);
      HRESULT (WINAPI *Seek)(IRowsetCurrentIndex *This,HACCESSOR hAccessor,DBORDINAL cKeyValues,void *pData,DBSEEK dwSeekOptions);
      HRESULT (WINAPI *SetRange)(IRowsetCurrentIndex *This,HACCESSOR hAccessor,DBORDINAL cStartKeyColumns,void *pStartData,DBORDINAL cEndKeyColumns,void *pEndData,DBRANGE dwRangeOptions);
      HRESULT (WINAPI *GetIndex)(IRowsetCurrentIndex *This,DBID **ppIndexID);
      HRESULT (WINAPI *SetIndex)(IRowsetCurrentIndex *This,DBID *pIndexID);
    END_INTERFACE
  } IRowsetCurrentIndexVtbl;
  struct IRowsetCurrentIndex {
    CONST_VTBL struct IRowsetCurrentIndexVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetCurrentIndex_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetCurrentIndex_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetCurrentIndex_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetCurrentIndex_GetIndexInfo(This,pcKeyColumns,prgIndexColumnDesc,pcIndexPropertySets,prgIndexPropertySets) (This)->lpVtbl->GetIndexInfo(This,pcKeyColumns,prgIndexColumnDesc,pcIndexPropertySets,prgIndexPropertySets)
#define IRowsetCurrentIndex_Seek(This,hAccessor,cKeyValues,pData,dwSeekOptions) (This)->lpVtbl->Seek(This,hAccessor,cKeyValues,pData,dwSeekOptions)
#define IRowsetCurrentIndex_SetRange(This,hAccessor,cStartKeyColumns,pStartData,cEndKeyColumns,pEndData,dwRangeOptions) (This)->lpVtbl->SetRange(This,hAccessor,cStartKeyColumns,pStartData,cEndKeyColumns,pEndData,dwRangeOptions)
#define IRowsetCurrentIndex_GetIndex(This,ppIndexID) (This)->lpVtbl->GetIndex(This,ppIndexID)
#define IRowsetCurrentIndex_SetIndex(This,pIndexID) (This)->lpVtbl->SetIndex(This,pIndexID)
#endif
#endif
  HRESULT WINAPI IRowsetCurrentIndex_GetIndex_Proxy(IRowsetCurrentIndex *This,DBID **ppIndexID);
  void __RPC_STUB IRowsetCurrentIndex_GetIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetCurrentIndex_SetIndex_Proxy(IRowsetCurrentIndex *This,DBID *pIndexID);
  void __RPC_STUB IRowsetCurrentIndex_SetIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#if (OLEDBVER >= 0x0260)
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0353_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0353_v0_0_s_ifspec;
#ifndef __ICommandStream_INTERFACE_DEFINED__
#define __ICommandStream_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICommandStream;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandStream : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCommandStream(IID *piid,GUID *pguidDialect,IUnknown **ppCommandStream) = 0;
    virtual HRESULT WINAPI SetCommandStream(REFIID riid,REFGUID rguidDialect,IUnknown *pCommandStream) = 0;
  };
#else
  typedef struct ICommandStreamVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandStream *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandStream *This);
      ULONG (WINAPI *Release)(ICommandStream *This);
      HRESULT (WINAPI *GetCommandStream)(ICommandStream *This,IID *piid,GUID *pguidDialect,IUnknown **ppCommandStream);
      HRESULT (WINAPI *SetCommandStream)(ICommandStream *This,REFIID riid,REFGUID rguidDialect,IUnknown *pCommandStream);
    END_INTERFACE
  } ICommandStreamVtbl;
  struct ICommandStream {
    CONST_VTBL struct ICommandStreamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandStream_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandStream_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandStream_Release(This) (This)->lpVtbl->Release(This)
#define ICommandStream_GetCommandStream(This,piid,pguidDialect,ppCommandStream) (This)->lpVtbl->GetCommandStream(This,piid,pguidDialect,ppCommandStream)
#define ICommandStream_SetCommandStream(This,riid,rguidDialect,pCommandStream) (This)->lpVtbl->SetCommandStream(This,riid,rguidDialect,pCommandStream)
#endif
#endif
  HRESULT WINAPI ICommandStream_GetCommandStream_Proxy(ICommandStream *This,IID *piid,GUID *pguidDialect,IUnknown **ppCommandStream);
  void __RPC_STUB ICommandStream_GetCommandStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandStream_SetCommandStream_Proxy(ICommandStream *This,REFIID riid,REFGUID rguidDialect,IUnknown *pCommandStream);
  void __RPC_STUB ICommandStream_SetCommandStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRowsetBookmark_INTERFACE_DEFINED__
#define __IRowsetBookmark_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetBookmark;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetBookmark : public IUnknown {
  public:
    virtual HRESULT WINAPI PositionOnBookmark(HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark) = 0;
  };
#else
  typedef struct IRowsetBookmarkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetBookmark *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetBookmark *This);
      ULONG (WINAPI *Release)(IRowsetBookmark *This);
      HRESULT (WINAPI *PositionOnBookmark)(IRowsetBookmark *This,HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark);
    END_INTERFACE
  } IRowsetBookmarkVtbl;
  struct IRowsetBookmark {
    CONST_VTBL struct IRowsetBookmarkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetBookmark_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetBookmark_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetBookmark_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetBookmark_PositionOnBookmark(This,hChapter,cbBookmark,pBookmark) (This)->lpVtbl->PositionOnBookmark(This,hChapter,cbBookmark,pBookmark)
#endif
#endif
  HRESULT WINAPI IRowsetBookmark_PositionOnBookmark_Proxy(IRowsetBookmark *This,HCHAPTER hChapter,DBBKMARK cbBookmark,const BYTE *pBookmark);
  void __RPC_STUB IRowsetBookmark_PositionOnBookmark_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#include <poppack.h>

  extern RPC_IF_HANDLE __MIDL_itf_oledb_0355_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_oledb_0355_v0_0_s_ifspec;

#ifdef OLEDBPROXY
  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API LPSAFEARRAY_UserSize(ULONG *,ULONG,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserMarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserUnmarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  void __RPC_API LPSAFEARRAY_UserFree(ULONG *,LPSAFEARRAY *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

  HRESULT WINAPI IAccessor_AddRefAccessor_Proxy(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount);
  HRESULT WINAPI IAccessor_AddRefAccessor_Stub(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IAccessor_CreateAccessor_Proxy(IAccessor *This,DBACCESSORFLAGS dwAccessorFlags,DBCOUNTITEM cBindings,const DBBINDING rgBindings[],DBLENGTH cbRowSize,HACCESSOR *phAccessor,DBBINDSTATUS rgStatus[]);
  HRESULT WINAPI IAccessor_CreateAccessor_Stub(IAccessor *This,DBACCESSORFLAGS dwAccessorFlags,DBCOUNTITEM cBindings,DBBINDING *rgBindings,DBLENGTH cbRowSize,HACCESSOR *phAccessor,DBBINDSTATUS *rgStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IAccessor_GetBindings_Proxy(IAccessor *This,HACCESSOR hAccessor,DBACCESSORFLAGS *pdwAccessorFlags,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings);
  HRESULT WINAPI IAccessor_GetBindings_Stub(IAccessor *This,HACCESSOR hAccessor,DBACCESSORFLAGS *pdwAccessorFlags,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IAccessor_ReleaseAccessor_Proxy(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount);
  HRESULT WINAPI IAccessor_ReleaseAccessor_Stub(IAccessor *This,HACCESSOR hAccessor,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowsetInfo_GetProperties_Proxy(IRowsetInfo *This,const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
  HRESULT WINAPI IRowsetInfo_GetProperties_Stub(IRowsetInfo *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowsetInfo_GetReferencedRowset_Proxy(IRowsetInfo *This,DBORDINAL iOrdinal,REFIID riid,IUnknown **ppReferencedRowset);
  HRESULT WINAPI IRowsetInfo_GetReferencedRowset_Stub(IRowsetInfo *This,DBORDINAL iOrdinal,REFIID riid,IUnknown **ppReferencedRowset,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowsetInfo_GetSpecification_Proxy(IRowsetInfo *This,REFIID riid,IUnknown **ppSpecification);
  HRESULT WINAPI IRowsetInfo_GetSpecification_Stub(IRowsetInfo *This,REFIID riid,IUnknown **ppSpecification,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IChapteredRowset_AddRefChapter_Proxy(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount);
  HRESULT WINAPI IChapteredRowset_AddRefChapter_Stub(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IChapteredRowset_ReleaseChapter_Proxy(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount);
  HRESULT WINAPI IChapteredRowset_ReleaseChapter_Stub(IChapteredRowset *This,HCHAPTER hChapter,DBREFCOUNT *pcRefCount,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowPosition_ClearRowPosition_Proxy(IRowPosition *This);
  HRESULT WINAPI IRowPosition_ClearRowPosition_Stub(IRowPosition *This,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowPosition_GetRowPosition_Proxy(IRowPosition *This,HCHAPTER *phChapter,HROW *phRow,DBPOSITIONFLAGS *pdwPositionFlags);
  HRESULT WINAPI IRowPosition_GetRowPosition_Stub(IRowPosition *This,HCHAPTER *phChapter,HROW *phRow,DBPOSITIONFLAGS *pdwPositionFlags,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowPosition_GetRowset_Proxy(IRowPosition *This,REFIID riid,IUnknown **ppRowset);
  HRESULT WINAPI IRowPosition_GetRowset_Stub(IRowPosition *This,REFIID riid,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowPosition_Initialize_Proxy(IRowPosition *This,IUnknown *pRowset);
  HRESULT WINAPI IRowPosition_Initialize_Stub(IRowPosition *This,IUnknown *pRowset,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowPosition_SetRowPosition_Proxy(IRowPosition *This,HCHAPTER hChapter,HROW hRow,DBPOSITIONFLAGS dwPositionFlags);
  HRESULT WINAPI IRowPosition_SetRowPosition_Stub(IRowPosition *This,HCHAPTER hChapter,HROW hRow,DBPOSITIONFLAGS dwPositionFlags,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowPositionChange_OnRowPositionChange_Proxy(IRowPositionChange *This,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  HRESULT WINAPI IRowPositionChange_OnRowPositionChange_Stub(IRowPositionChange *This,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IViewRowset_GetSpecification_Proxy(IViewRowset *This,REFIID riid,IUnknown **ppObject);
  HRESULT WINAPI IViewRowset_GetSpecification_Stub(IViewRowset *This,REFIID riid,IUnknown **ppObject,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IViewRowset_OpenViewRowset_Proxy(IViewRowset *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppRowset);
  HRESULT WINAPI IViewRowset_OpenViewRowset_Stub(IViewRowset *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IViewChapter_GetSpecification_Proxy(IViewChapter *This,REFIID riid,IUnknown **ppRowset);
  HRESULT WINAPI IViewChapter_GetSpecification_Stub(IViewChapter *This,REFIID riid,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IViewChapter_OpenViewChapter_Proxy(IViewChapter *This,HCHAPTER hSource,HCHAPTER *phViewChapter);
  HRESULT WINAPI IViewChapter_OpenViewChapter_Stub(IViewChapter *This,HCHAPTER hSource,HCHAPTER *phViewChapter,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IViewSort_GetSortOrder_Proxy(IViewSort *This,DBORDINAL *pcValues,DBORDINAL *prgColumns[],DBSORT *prgOrders[]);
  HRESULT WINAPI IViewSort_GetSortOrder_Stub(IViewSort *This,DBORDINAL *pcValues,DBORDINAL **prgColumns,DBSORT **prgOrders,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IViewSort_SetSortOrder_Proxy(IViewSort *This,DBORDINAL cValues,const DBORDINAL rgColumns[],const DBSORT rgOrders[]);
  HRESULT WINAPI IViewSort_SetSortOrder_Stub(IViewSort *This,DBORDINAL cValues,const DBORDINAL *rgColumns,const DBSORT *rgOrders,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IViewFilter_GetFilterBindings_Proxy(IViewFilter *This,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings);
  HRESULT WINAPI IViewFilter_GetFilterBindings_Stub(IViewFilter *This,DBCOUNTITEM *pcBindings,DBBINDING **prgBindings,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowsetView_CreateView_Proxy(IRowsetView *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppView);
  HRESULT WINAPI IRowsetView_CreateView_Stub(IRowsetView *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppView,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowsetView_GetView_Proxy(IRowsetView *This,HCHAPTER hChapter,REFIID riid,HCHAPTER *phChapterSource,IUnknown **ppView);
  HRESULT WINAPI IRowsetView_GetView_Stub(IRowsetView *This,HCHAPTER hChapter,REFIID riid,HCHAPTER *phChapterSource,IUnknown **ppView,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowsetIdentity_IsSameRow_Proxy(IRowsetIdentity *This,HROW hThisRow,HROW hThatRow);
  HRESULT WINAPI IRowsetIdentity_IsSameRow_Stub(IRowsetIdentity *This,HROW hThisRow,HROW hThatRow,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IRowsetNotify_OnFieldChange_Proxy(IRowsetNotify *This,IRowset *pRowset,HROW hRow,DBORDINAL cColumns,DBORDINAL rgColumns[],DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  HRESULT WINAPI IRowsetNotify_OnFieldChange_Stub(IRowsetNotify *This,IRowset *pRowset,HROW hRow,DBORDINAL cColumns,DBORDINAL *rgColumns,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  HRESULT WINAPI IRowsetNotify_OnRowChange_Proxy(IRowsetNotify *This,IRowset *pRowset,DBCOUNTITEM cRows,const HROW rghRows[],DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  HRESULT WINAPI IRowsetNotify_OnRowChange_Stub(IRowsetNotify *This,IRowset *pRowset,DBCOUNTITEM cRows,const HROW *rghRows,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  HRESULT WINAPI IRowsetNotify_OnRowsetChange_Proxy(IRowsetNotify *This,IRowset *pRowset,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  HRESULT WINAPI IRowsetNotify_OnRowsetChange_Stub(IRowsetNotify *This,IRowset *pRowset,DBREASON eReason,DBEVENTPHASE ePhase,WINBOOL fCantDeny);
  HRESULT WINAPI ICommand_Cancel_Proxy(ICommand *This);
  HRESULT WINAPI ICommand_Cancel_Stub(ICommand *This,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommand_Execute_Proxy(ICommand *This,IUnknown *pUnkOuter,REFIID riid,DBPARAMS *pParams,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset);
  HRESULT WINAPI ICommand_Execute_Stub(ICommand *This,IUnknown *pUnkOuter,REFIID riid,HACCESSOR hAccessor,DB_UPARAMS cParamSets,GUID *pGuid,ULONG ulGuidOffset,RMTPACK *pInputParams,RMTPACK *pOutputParams,DBCOUNTITEM cBindings,DBBINDING *rgBindings,DBSTATUS *rgStatus,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset);
  HRESULT WINAPI ICommand_GetDBSession_Proxy(ICommand *This,REFIID riid,IUnknown **ppSession);
  HRESULT WINAPI ICommand_GetDBSession_Stub(ICommand *This,REFIID riid,IUnknown **ppSession,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IMultipleResults_GetResult_Proxy(IMultipleResults *This,IUnknown *pUnkOuter,DBRESULTFLAG lResultFlag,REFIID riid,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset);
  HRESULT WINAPI IMultipleResults_GetResult_Stub(IMultipleResults *This,IUnknown *pUnkOuter,DBRESULTFLAG lResultFlag,REFIID riid,DBROWCOUNT *pcRowsAffected,IUnknown **ppRowset,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IConvertType_CanConvert_Proxy(IConvertType *This,DBTYPE wFromType,DBTYPE wToType,DBCONVERTFLAGS dwConvertFlags);
  HRESULT WINAPI IConvertType_CanConvert_Stub(IConvertType *This,DBTYPE wFromType,DBTYPE wToType,DBCONVERTFLAGS dwConvertFlags,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandPrepare_Prepare_Proxy(ICommandPrepare *This,ULONG cExpectedRuns);
  HRESULT WINAPI ICommandPrepare_Prepare_Stub(ICommandPrepare *This,ULONG cExpectedRuns,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandPrepare_Unprepare_Proxy(ICommandPrepare *This);
  HRESULT WINAPI ICommandPrepare_Unprepare_Stub(ICommandPrepare *This,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandProperties_GetProperties_Proxy(ICommandProperties *This,const ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
  HRESULT WINAPI ICommandProperties_GetProperties_Stub(ICommandProperties *This,const ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandProperties_SetProperties_Proxy(ICommandProperties *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  HRESULT WINAPI ICommandProperties_SetProperties_Stub(ICommandProperties *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandText_GetCommandText_Proxy(ICommandText *This,GUID *pguidDialect,LPOLESTR *ppwszCommand);
  HRESULT WINAPI ICommandText_GetCommandText_Stub(ICommandText *This,GUID *pguidDialect,LPOLESTR *ppwszCommand,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandText_SetCommandText_Proxy(ICommandText *This,REFGUID rguidDialect,LPCOLESTR pwszCommand);
  HRESULT WINAPI ICommandText_SetCommandText_Stub(ICommandText *This,REFGUID rguidDialect,LPCOLESTR pwszCommand,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandWithParameters_GetParameterInfo_Proxy(ICommandWithParameters *This,DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,OLECHAR **ppNamesBuffer);
  HRESULT WINAPI ICommandWithParameters_GetParameterInfo_Stub(ICommandWithParameters *This,DB_UPARAMS *pcParams,DBPARAMINFO **prgParamInfo,DBBYTEOFFSET **prgNameOffsets,DBLENGTH *pcbNamesBuffer,OLECHAR **ppNamesBuffer,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandWithParameters_MapParameterNames_Proxy(ICommandWithParameters *This,DB_UPARAMS cParamNames,const OLECHAR *rgParamNames[],DB_LPARAMS rgParamOrdinals[]);
  HRESULT WINAPI ICommandWithParameters_MapParameterNames_Stub(ICommandWithParameters *This,DB_UPARAMS cParamNames,LPCOLESTR *rgParamNames,DB_LPARAMS *rgParamOrdinals,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ICommandWithParameters_SetParameterInfo_Proxy(ICommandWithParameters *This,DB_UPARAMS cParams,const DB_UPARAMS rgParamOrdinals[],const DBPARAMBINDINFO rgParamBindInfo[]);
  HRESULT WINAPI ICommandWithParameters_SetParameterInfo_Stub(ICommandWithParameters *This,DB_UPARAMS cParams,const DB_UPARAMS *rgParamOrdinals,const DBPARAMBINDINFO *rgParamBindInfo,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IColumnsRowset_GetAvailableColumns_Proxy(IColumnsRowset *This,DBORDINAL *pcOptColumns,DBID **prgOptColumns);
  HRESULT WINAPI IColumnsRowset_GetAvailableColumns_Stub(IColumnsRowset *This,DBORDINAL *pcOptColumns,DBID **prgOptColumns,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IColumnsRowset_GetColumnsRowset_Proxy(IColumnsRowset *This,IUnknown *pUnkOuter,DBORDINAL cOptColumns,const DBID rgOptColumns[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppColRowset);
  HRESULT WINAPI IColumnsRowset_GetColumnsRowset_Stub(IColumnsRowset *This,IUnknown *pUnkOuter,DBORDINAL cOptColumns,const DBID *rgOptColumns,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppColRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IColumnsInfo_GetColumnInfo_Proxy(IColumnsInfo *This,DBORDINAL *pcColumns,DBCOLUMNINFO **prgInfo,OLECHAR **ppStringsBuffer);
  HRESULT WINAPI IColumnsInfo_GetColumnInfo_Stub(IColumnsInfo *This,DBORDINAL *pcColumns,DBCOLUMNINFO **prgInfo,DBBYTEOFFSET **prgNameOffsets,DBBYTEOFFSET **prgcolumnidOffsets,DBLENGTH *pcbStringsBuffer,OLECHAR **ppStringsBuffer,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IColumnsInfo_MapColumnIDs_Proxy(IColumnsInfo *This,DBORDINAL cColumnIDs,const DBID rgColumnIDs[],DBORDINAL rgColumns[]);
  HRESULT WINAPI IColumnsInfo_MapColumnIDs_Stub(IColumnsInfo *This,DBORDINAL cColumnIDs,const DBID *rgColumnIDs,DBORDINAL *rgColumns,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBCreateCommand_CreateCommand_Proxy(IDBCreateCommand *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppCommand);
  HRESULT WINAPI IDBCreateCommand_CreateCommand_Stub(IDBCreateCommand *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppCommand,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBCreateSession_CreateSession_Proxy(IDBCreateSession *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession);
  HRESULT WINAPI IDBCreateSession_CreateSession_Stub(IDBCreateSession *This,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ISourcesRowset_GetSourcesRowset_Proxy(ISourcesRowset *This,IUnknown *pUnkOuter,REFIID riid,ULONG cPropertySets,DBPROPSET rgProperties[],IUnknown **ppSourcesRowset);
  HRESULT WINAPI ISourcesRowset_GetSourcesRowset_Stub(ISourcesRowset *This,IUnknown *pUnkOuter,REFIID riid,ULONG cPropertySets,DBPROPSET *rgProperties,IUnknown **ppSourcesRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBProperties_GetProperties_Proxy(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
  HRESULT WINAPI IDBProperties_GetProperties_Stub(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBProperties_GetPropertyInfo_Proxy(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,OLECHAR **ppDescBuffer);
  HRESULT WINAPI IDBProperties_GetPropertyInfo_Stub(IDBProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,ULONG *pcOffsets,DBBYTEOFFSET **prgDescOffsets,ULONG *pcbDescBuffer,OLECHAR **ppDescBuffer,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBProperties_SetProperties_Proxy(IDBProperties *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  HRESULT WINAPI IDBProperties_SetProperties_Stub(IDBProperties *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBInitialize_Initialize_Proxy(IDBInitialize *This);
  HRESULT WINAPI IDBInitialize_Initialize_Stub(IDBInitialize *This,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBInitialize_Uninitialize_Proxy(IDBInitialize *This);
  HRESULT WINAPI IDBInitialize_Uninitialize_Stub(IDBInitialize *This,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBInfo_GetKeywords_Proxy(IDBInfo *This,LPOLESTR *ppwszKeywords);
  HRESULT WINAPI IDBInfo_GetKeywords_Stub(IDBInfo *This,LPOLESTR *ppwszKeywords,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBInfo_GetLiteralInfo_Proxy(IDBInfo *This,ULONG cLiterals,const DBLITERAL rgLiterals[],ULONG *pcLiteralInfo,DBLITERALINFO **prgLiteralInfo,OLECHAR **ppCharBuffer);
  HRESULT WINAPI IDBInfo_GetLiteralInfo_Stub(IDBInfo *This,ULONG cLiterals,const DBLITERAL *rgLiterals,ULONG *pcLiteralInfo,DBLITERALINFO **prgLiteralInfo,DB_UPARAMS **prgLVOffsets,DB_UPARAMS **prgICOffsets,DB_UPARAMS **prgISCOffsets,ULONG *pcbCharBuffer,OLECHAR **ppCharBuffer,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBDataSourceAdmin_CreateDataSource_Proxy(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession);
  HRESULT WINAPI IDBDataSourceAdmin_CreateDataSource_Stub(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown *pUnkOuter,REFIID riid,IUnknown **ppDBSession,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBDataSourceAdmin_DestroyDataSource_Proxy(IDBDataSourceAdmin *This);
  HRESULT WINAPI IDBDataSourceAdmin_DestroyDataSource_Stub(IDBDataSourceAdmin *This,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBDataSourceAdmin_GetCreationProperties_Proxy(IDBDataSourceAdmin *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,OLECHAR **ppDescBuffer);
  HRESULT WINAPI IDBDataSourceAdmin_GetCreationProperties_Stub(IDBDataSourceAdmin *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertyInfoSets,DBPROPINFOSET **prgPropertyInfoSets,DBCOUNTITEM *pcOffsets,DBBYTEOFFSET **prgDescOffsets,ULONG *pcbDescBuffer,OLECHAR **ppDescBuffer,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBDataSourceAdmin_ModifyDataSource_Proxy(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  HRESULT WINAPI IDBDataSourceAdmin_ModifyDataSource_Stub(IDBDataSourceAdmin *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBAsynchNotify_OnLowResource_Proxy(IDBAsynchNotify *This,DB_DWRESERVE dwReserved);
  HRESULT WINAPI IDBAsynchNotify_OnLowResource_Stub(IDBAsynchNotify *This,DB_DWRESERVE dwReserved);
  HRESULT WINAPI IDBAsynchNotify_OnProgress_Proxy(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM ulProgress,DBCOUNTITEM ulProgressMax,DBASYNCHPHASE eAsynchPhase,LPOLESTR pwszStatusText);
  HRESULT WINAPI IDBAsynchNotify_OnProgress_Stub(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM ulProgress,DBCOUNTITEM ulProgressMax,DBASYNCHPHASE eAsynchPhase,LPOLESTR pwszStatusText);
  HRESULT WINAPI IDBAsynchNotify_OnStop_Proxy(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,HRESULT hrStatus,LPOLESTR pwszStatusText);
  HRESULT WINAPI IDBAsynchNotify_OnStop_Stub(IDBAsynchNotify *This,HCHAPTER hChapter,DBASYNCHOP eOperation,HRESULT hrStatus,LPOLESTR pwszStatusText);
  HRESULT WINAPI IDBAsynchStatus_Abort_Proxy(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation);
  HRESULT WINAPI IDBAsynchStatus_Abort_Stub(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBAsynchStatus_GetStatus_Proxy(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM *pulProgress,DBCOUNTITEM *pulProgressMax,DBASYNCHPHASE *peAsynchPhase,LPOLESTR *ppwszStatusText);
  HRESULT WINAPI IDBAsynchStatus_GetStatus_Stub(IDBAsynchStatus *This,HCHAPTER hChapter,DBASYNCHOP eOperation,DBCOUNTITEM *pulProgress,DBCOUNTITEM *pulProgressMax,DBASYNCHPHASE *peAsynchPhase,LPOLESTR *ppwszStatusText,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ISessionProperties_GetProperties_Proxy(ISessionProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET rgPropertyIDSets[],ULONG *pcPropertySets,DBPROPSET **prgPropertySets);
  HRESULT WINAPI ISessionProperties_GetProperties_Stub(ISessionProperties *This,ULONG cPropertyIDSets,const DBPROPIDSET *rgPropertyIDSets,ULONG *pcPropertySets,DBPROPSET **prgPropertySets,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ISessionProperties_SetProperties_Proxy(ISessionProperties *This,ULONG cPropertySets,DBPROPSET rgPropertySets[]);
  HRESULT WINAPI ISessionProperties_SetProperties_Stub(ISessionProperties *This,ULONG cPropertySets,DBPROPSET *rgPropertySets,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IIndexDefinition_CreateIndex_Proxy(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID,DBORDINAL cIndexColumnDescs,const DBINDEXCOLUMNDESC rgIndexColumnDescs[],ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppIndexID);
  HRESULT WINAPI IIndexDefinition_CreateIndex_Stub(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID,DBORDINAL cIndexColumnDescs,const DBINDEXCOLUMNDESC *rgIndexColumnDescs,ULONG cPropertySets,DBPROPSET *rgPropertySets,DBID **ppIndexID,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IIndexDefinition_DropIndex_Proxy(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID);
  HRESULT WINAPI IIndexDefinition_DropIndex_Stub(IIndexDefinition *This,DBID *pTableID,DBID *pIndexID,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITableDefinition_CreateTable_Proxy(ITableDefinition *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,const DBCOLUMNDESC rgColumnDescs[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],DBID **ppTableID,IUnknown **ppRowset);
  HRESULT WINAPI ITableDefinition_CreateTable_Stub(ITableDefinition *This,IUnknown *pUnkOuter,DBID *pTableID,DBORDINAL cColumnDescs,const DBCOLUMNDESC *rgColumnDescs,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,DBID **ppTableID,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,WINBOOL *pfTableCreated,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITableDefinition_DropTable_Proxy(ITableDefinition *This,DBID *pTableID);
  HRESULT WINAPI ITableDefinition_DropTable_Stub(ITableDefinition *This,DBID *pTableID,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITableDefinition_AddColumn_Proxy(ITableDefinition *This,DBID *pTableID,DBCOLUMNDESC *pColumnDesc,DBID **ppColumnID);
  HRESULT WINAPI ITableDefinition_AddColumn_Stub(ITableDefinition *This,DBID *pTableID,DBCOLUMNDESC *pColumnDesc,DBID **ppColumnID,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITableDefinition_DropColumn_Proxy(ITableDefinition *This,DBID *pTableID,DBID *pColumnID);
  HRESULT WINAPI ITableDefinition_DropColumn_Stub(ITableDefinition *This,DBID *pTableID,DBID *pColumnID,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IOpenRowset_OpenRowset_Proxy(IOpenRowset *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
  HRESULT WINAPI IOpenRowset_OpenRowset_Stub(IOpenRowset *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBSchemaRowset_GetRowset_Proxy(IDBSchemaRowset *This,IUnknown *pUnkOuter,REFGUID rguidSchema,ULONG cRestrictions,const VARIANT rgRestrictions[],REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
  HRESULT WINAPI IDBSchemaRowset_GetRowset_Stub(IDBSchemaRowset *This,IUnknown *pUnkOuter,REFGUID rguidSchema,ULONG cRestrictions,const VARIANT *rgRestrictions,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IDBSchemaRowset_GetSchemas_Proxy(IDBSchemaRowset *This,ULONG *pcSchemas,GUID **prgSchemas,ULONG **prgRestrictionSupport);
  HRESULT WINAPI IDBSchemaRowset_GetSchemas_Stub(IDBSchemaRowset *This,ULONG *pcSchemas,GUID **prgSchemas,ULONG **prgRestrictionSupport,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorRecords_AddErrorRecord_Proxy(IErrorRecords *This,ERRORINFO *pErrorInfo,DWORD dwLookupID,DISPPARAMS *pdispparams,IUnknown *punkCustomError,DWORD dwDynamicErrorID);
  HRESULT WINAPI IErrorRecords_AddErrorRecord_Stub(IErrorRecords *This,ERRORINFO *pErrorInfo,DWORD dwLookupID,DISPPARAMS *pdispparams,IUnknown *punkCustomError,DWORD dwDynamicErrorID,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorRecords_GetBasicErrorInfo_Proxy(IErrorRecords *This,ULONG ulRecordNum,ERRORINFO *pErrorInfo);
  HRESULT WINAPI IErrorRecords_GetBasicErrorInfo_Stub(IErrorRecords *This,ULONG ulRecordNum,ERRORINFO *pErrorInfo,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorRecords_GetCustomErrorObject_Proxy(IErrorRecords *This,ULONG ulRecordNum,REFIID riid,IUnknown **ppObject);
  HRESULT WINAPI IErrorRecords_GetCustomErrorObject_Stub(IErrorRecords *This,ULONG ulRecordNum,REFIID riid,IUnknown **ppObject,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorRecords_GetErrorInfo_Proxy(IErrorRecords *This,ULONG ulRecordNum,LCID lcid,IErrorInfo **ppErrorInfo);
  HRESULT WINAPI IErrorRecords_GetErrorInfo_Stub(IErrorRecords *This,ULONG ulRecordNum,LCID lcid,IErrorInfo **ppErrorInfo,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorRecords_GetErrorParameters_Proxy(IErrorRecords *This,ULONG ulRecordNum,DISPPARAMS *pdispparams);
  HRESULT WINAPI IErrorRecords_GetErrorParameters_Stub(IErrorRecords *This,ULONG ulRecordNum,DISPPARAMS *pdispparams,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorRecords_GetRecordCount_Proxy(IErrorRecords *This,ULONG *pcRecords);
  HRESULT WINAPI IErrorRecords_GetRecordCount_Stub(IErrorRecords *This,ULONG *pcRecords,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorLookup_GetErrorDescription_Proxy(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,DISPPARAMS *pdispparams,LCID lcid,BSTR *pbstrSource,BSTR *pbstrDescription);
  HRESULT WINAPI IErrorLookup_GetErrorDescription_Stub(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,DISPPARAMS *pdispparams,LCID lcid,BSTR *pbstrSource,BSTR *pbstrDescription,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorLookup_GetHelpInfo_Proxy(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,LCID lcid,BSTR *pbstrHelpFile,DWORD *pdwHelpContext);
  HRESULT WINAPI IErrorLookup_GetHelpInfo_Stub(IErrorLookup *This,HRESULT hrError,DWORD dwLookupID,LCID lcid,BSTR *pbstrHelpFile,DWORD *pdwHelpContext,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IErrorLookup_ReleaseErrors_Proxy(IErrorLookup *This,const DWORD dwDynamicErrorID);
  HRESULT WINAPI IErrorLookup_ReleaseErrors_Stub(IErrorLookup *This,const DWORD dwDynamicErrorID,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ISQLErrorInfo_GetSQLInfo_Proxy(ISQLErrorInfo *This,BSTR *pbstrSQLState,LONG *plNativeError);
  HRESULT WINAPI ISQLErrorInfo_GetSQLInfo_Stub(ISQLErrorInfo *This,BSTR *pbstrSQLState,LONG *plNativeError,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IGetDataSource_GetDataSource_Proxy(IGetDataSource *This,REFIID riid,IUnknown **ppDataSource);
  HRESULT WINAPI IGetDataSource_GetDataSource_Stub(IGetDataSource *This,REFIID riid,IUnknown **ppDataSource,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITransactionLocal_GetOptionsObject_Proxy(ITransactionLocal *This,ITransactionOptions **ppOptions);
  HRESULT WINAPI ITransactionLocal_GetOptionsObject_Stub(ITransactionLocal *This,ITransactionOptions **ppOptions,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITransactionLocal_StartTransaction_Proxy(ITransactionLocal *This,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions,ULONG *pulTransactionLevel);
  HRESULT WINAPI ITransactionLocal_StartTransaction_Stub(ITransactionLocal *This,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions,ULONG *pulTransactionLevel,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITransactionJoin_GetOptionsObject_Proxy(ITransactionJoin *This,ITransactionOptions **ppOptions);
  HRESULT WINAPI ITransactionJoin_GetOptionsObject_Stub(ITransactionJoin *This,ITransactionOptions **ppOptions,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITransactionJoin_JoinTransaction_Proxy(ITransactionJoin *This,IUnknown *punkTransactionCoord,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions);
  HRESULT WINAPI ITransactionJoin_JoinTransaction_Stub(ITransactionJoin *This,IUnknown *punkTransactionCoord,ISOLEVEL isoLevel,ULONG isoFlags,ITransactionOptions *pOtherOptions,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI ITransactionObject_GetTransactionObject_Proxy(ITransactionObject *This,ULONG ulTransactionLevel,ITransaction **ppTransactionObject);
  HRESULT WINAPI ITransactionObject_GetTransactionObject_Stub(ITransactionObject *This,ULONG ulTransactionLevel,ITransaction **ppTransactionObject,IErrorInfo **ppErrorInfoRem);
  HRESULT WINAPI IScopedOperations_Copy_Proxy(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR rgpwszSourceURLs[],LPCOLESTR rgpwszDestURLs[],DWORD dwCopyFlags,IAuthenticate *pAuthenticate,DBSTATUS rgdwStatus[],LPOLESTR rgpwszNewURLs[],OLECHAR **ppStringsBuffer);
  HRESULT WINAPI IScopedOperations_Copy_Stub(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR *rgpwszSourceURLs,LPCOLESTR *rgpwszDestURLs,DWORD dwCopyFlags,IAuthenticate *pAuthenticate,DBSTATUS *rgdwStatus,DBBYTEOFFSET **prgulNewURLOffsets,ULONG *pcbStringsBuffer,OLECHAR **ppStringsBuffer);
  HRESULT WINAPI IScopedOperations_Move_Proxy(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR rgpwszSourceURLs[],LPCOLESTR rgpwszDestURLs[],DWORD dwMoveFlags,IAuthenticate *pAuthenticate,DBSTATUS rgdwStatus[],LPOLESTR rgpwszNewURLs[],OLECHAR **ppStringsBuffer);
  HRESULT WINAPI IScopedOperations_Move_Stub(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR *rgpwszSourceURLs,LPCOLESTR *rgpwszDestURLs,DWORD dwMoveFlags,IAuthenticate *pAuthenticate,DBSTATUS *rgdwStatus,DBBYTEOFFSET **prgulNewURLOffsets,ULONG *pcbStringsBuffer,OLECHAR **ppStringsBuffer);
  HRESULT WINAPI IScopedOperations_Delete_Proxy(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR rgpwszURLs[],DWORD dwDeleteFlags,DBSTATUS rgdwStatus[]);
  HRESULT WINAPI IScopedOperations_Delete_Stub(IScopedOperations *This,DBCOUNTITEM cRows,LPCOLESTR *rgpwszURLs,DWORD dwDeleteFlags,DBSTATUS *rgdwStatus);
  HRESULT WINAPI IScopedOperations_OpenRowset_Proxy(IScopedOperations *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET rgPropertySets[],IUnknown **ppRowset);
  HRESULT WINAPI IScopedOperations_OpenRowset_Stub(IScopedOperations *This,IUnknown *pUnkOuter,DBID *pTableID,DBID *pIndexID,REFIID riid,ULONG cPropertySets,DBPROPSET *rgPropertySets,IUnknown **ppRowset,ULONG cTotalProps,DBPROPSTATUS *rgPropStatus);
  HRESULT WINAPI IBindResource_Bind_Proxy(IBindResource *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,DBIMPLICITSESSION *pImplSession,DBBINDURLSTATUS *pdwBindStatus,IUnknown **ppUnk);
  HRESULT WINAPI IBindResource_Bind_Stub(IBindResource *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,IUnknown *pSessionUnkOuter,IID *piid,IUnknown **ppSession,DBBINDURLSTATUS *pdwBindStatus,IUnknown **ppUnk);
  HRESULT WINAPI ICreateRow_CreateRow_Proxy(ICreateRow *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,DBIMPLICITSESSION *pImplSession,DBBINDURLSTATUS *pdwBindStatus,LPOLESTR *ppwszNewURL,IUnknown **ppUnk);
  HRESULT WINAPI ICreateRow_CreateRow_Stub(ICreateRow *This,IUnknown *pUnkOuter,LPCOLESTR pwszURL,DBBINDURLFLAG dwBindURLFlags,REFGUID rguid,REFIID riid,IAuthenticate *pAuthenticate,IUnknown *pSessionUnkOuter,IID *piid,IUnknown **ppSession,DBBINDURLSTATUS *pdwBindStatus,LPOLESTR *ppwszNewURL,IUnknown **ppUnk);
  HRESULT WINAPI IColumnsInfo2_GetRestrictedColumnInfo_Proxy(IColumnsInfo2 *This,DBORDINAL cColumnIDMasks,const DBID rgColumnIDMasks[],DWORD dwFlags,DBORDINAL *pcColumns,DBID **prgColumnIDs,DBCOLUMNINFO **prgColumnInfo,OLECHAR **ppStringsBuffer);
  HRESULT WINAPI IColumnsInfo2_GetRestrictedColumnInfo_Stub(IColumnsInfo2 *This,DBORDINAL cColumnIDMasks,const DBID *rgColumnIDMasks,DWORD dwFlags,DBORDINAL *pcColumns,DBID **prgColumnIDs,DBCOLUMNINFO **prgColumnInfo,DBBYTEOFFSET **prgNameOffsets,DBBYTEOFFSET **prgcolumnidOffsets,DBLENGTH *pcbStringsBuffer,OLECHAR **ppStringsBuffer);
  HRESULT WINAPI IRegisterProvider_GetURLMapping_Proxy(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,CLSID *pclsidProvider);
  HRESULT WINAPI IRegisterProvider_GetURLMapping_Stub(IRegisterProvider *This,LPCOLESTR pwszURL,DB_DWRESERVE dwReserved,CLSID *pclsidProvider);
#endif

#ifdef __cplusplus
}
#endif
#endif
