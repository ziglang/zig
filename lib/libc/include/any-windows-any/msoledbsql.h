/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
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

#ifndef __msoledbsql_h__
#define __msoledbsql_h__

#ifndef __ICommandWithParameters_FWD_DEFINED__
#define __ICommandWithParameters_FWD_DEFINED__
typedef struct ICommandWithParameters ICommandWithParameters;
#endif

#ifndef __IUMSInitialize_FWD_DEFINED__
#define __IUMSInitialize_FWD_DEFINED__
typedef struct IUMSInitialize IUMSInitialize;
#endif

#ifndef __ISQLServerErrorInfo_FWD_DEFINED__
#define __ISQLServerErrorInfo_FWD_DEFINED__
typedef struct ISQLServerErrorInfo ISQLServerErrorInfo;
#endif

#ifndef __IRowsetFastLoad_FWD_DEFINED__
#define __IRowsetFastLoad_FWD_DEFINED__
typedef struct IRowsetFastLoad IRowsetFastLoad;
#endif

#ifndef __ISchemaLock_FWD_DEFINED__
#define __ISchemaLock_FWD_DEFINED__
typedef struct ISchemaLock ISchemaLock;
#endif

#ifndef __IBCPSession_FWD_DEFINED__
#define __IBCPSession_FWD_DEFINED__
typedef struct IBCPSession IBCPSession;
#endif

#ifndef __IBCPSession2_FWD_DEFINED__
#define __IBCPSession2_FWD_DEFINED__
typedef struct IBCPSession2 IBCPSession2;
#endif

#ifndef __ISSAbort_FWD_DEFINED__
#define __ISSAbort_FWD_DEFINED__
typedef struct ISSAbort ISSAbort;
#endif

#ifndef __ISSCommandWithParameters_FWD_DEFINED__
#define __ISSCommandWithParameters_FWD_DEFINED__
typedef struct ISSCommandWithParameters ISSCommandWithParameters;
#endif

#ifndef __IDBAsynchStatus_FWD_DEFINED__
#define __IDBAsynchStatus_FWD_DEFINED__
typedef struct IDBAsynchStatus IDBAsynchStatus;
#endif

#ifndef __ISSAsynchStatus_FWD_DEFINED__
#define __ISSAsynchStatus_FWD_DEFINED__
typedef struct ISSAsynchStatus ISSAsynchStatus;
#endif

#include "unknwn.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef MSOLEDBSQL_VER
#define MSOLEDBSQL_VER 1800
#endif

#if (MSOLEDBSQL_VER >= 1800)
#define MSOLEDBSQL_PRODUCT_NAME_FULL_ANSI "Microsoft OLE DB Driver for SQL Server"
#define MSOLEDBSQL_PRODUCT_NAME_SHORT_ANSI "OLE DB Driver for SQL Server"
#define MSOLEDBSQL_FILE_NAME_ANSI "msoledbsql"
#define MSOLEDBSQL_FILE_NAME_FULL_ANSI "msoledbsql.dll"
#define MSOLEDBSQL_PRODUCT_NAME_FULL_UNICODE L"Microsoft OLE DB Driver for SQL Server"
#define MSOLEDBSQL_PRODUCT_NAME_SHORT_UNICODE L"OLE DB Driver for SQL Server"
#define MSOLEDBSQL_FILE_NAME_UNICODE L"msoledbsql"
#define MSOLEDBSQL_FILE_NAME_FULL_UNICODE L"msoledbsql.dll"
#define MSOLEDBSQL_VI_PROG_ID_ANSI "MSOLEDBSQL"
#define MSOLEDBSQL_VI_ERROR_LOOKUP_PROG_ID_ANSI "MSOLEDBSQL.ErrorLookup"
#define MSOLEDBSQL_VI_ENUMERATOR_PROG_ID_ANSI "MSOLEDBSQL.Enumerator"
#define MSOLEDBSQL_PROG_ID_ANSI "MSOLEDBSQL.1"
#define MSOLEDBSQL_ERROR_LOOKUP_PROG_ID_ANSI "MSOLEDBSQL.ErrorLookup.1"
#define MSOLEDBSQL_ENUMERATOR_PROG_ID_ANSI "MSOLEDBSQL.Enumerator.1"
#define MSOLEDBSQL_VI_PROG_ID_UNICODE L"MSOLEDBSQL"
#define MSOLEDBSQL_VI_ERROR_LOOKUP_PROG_ID_UNICODE L"MSOLEDBSQL.ErrorLookup"
#define MSOLEDBSQL_VI_ENUMERATOR_PROG_ID_UNICODE L"MSOLEDBSQL.Enumerator"
#define MSOLEDBSQL_PROG_ID_UNICODE L"MSOLEDBSQL.1"
#define MSOLEDBSQL_ERROR_LOOKUP_PROG_ID_UNICODE L"MSOLEDBSQL.ErrorLookup.1"
#define MSOLEDBSQL_ENUMERATOR_PROG_ID_UNICODE L"MSOLEDBSQL.Enumerator.1"
#define MSOLEDBSQL_CLSID CLSID_MSOLEDBSQL
#define MSOLEDBSQL_ERROR_CLSID CLSID_MSOLEDBSQL_ERROR
#define MSOLEDBSQL_ENUMERATOR_CLSID CLSID_MSOLEDBSQL_ENUMERATOR
#endif

#if defined(_UNICODE) || defined(UNICODE)
#define MSOLEDBSQL_PRODUCT_NAME_FULL MSOLEDBSQL_PRODUCT_NAME_FULL_UNICODE
#define MSOLEDBSQL_PRODUCT_NAME_SHORT MSOLEDBSQL_PRODUCT_NAME_SHORT_UNICODE
#define MSOLEDBSQL_FILE_NAME MSOLEDBSQL_FILE_NAME_UNICODE
#define MSOLEDBSQL_FILE_NAME_FULL MSOLEDBSQL_FILE_NAME_FULL_UNICODE
#define MSOLEDBSQL_VI_PROG_ID MSOLEDBSQL_VI_PROG_ID_UNICODE
#define MSOLEDBSQL_VI_ERROR_LOOKUP_PROG_ID MSOLEDBSQL_VI_ERROR_LOOKUP_PROG_ID_UNICODE
#define MSOLEDBSQL_VI_ENUMERATOR_PROG_ID MSOLEDBSQL_VI_ENUMERATOR_PROG_ID_UNICODE
#define MSOLEDBSQL_PROG_ID MSOLEDBSQL_PROG_ID_UNICODE
#define MSOLEDBSQL_ERROR_LOOKUP_PROG_ID MSOLEDBSQL_ERROR_LOOKUP_PROG_ID_UNICODE
#define MSOLEDBSQL_ENUMERATOR_PROG_ID MSOLEDBSQL_ENUMERATOR_PROG_ID_UNICODE
#else
#define MSOLEDBSQL_PRODUCT_NAME_FULL MSOLEDBSQL_PRODUCT_NAME_FULL_ANSI
#define MSOLEDBSQL_PRODUCT_NAME_SHORT MSOLEDBSQL_PRODUCT_NAME_SHORT_ANSI
#define MSOLEDBSQL_FILE_NAME MSOLEDBSQL_FILE_NAME_ANSI
#define MSOLEDBSQL_FILE_NAME_FULL MSOLEDBSQL_FILE_NAME_FULL_ANSI
#define MSOLEDBSQL_VI_PROG_ID MSOLEDBSQL_VI_PROG_ID_ANSI
#define MSOLEDBSQL_VI_ERROR_LOOKUP_PROG_ID MSOLEDBSQL_VI_ERROR_LOOKUP_PROG_ID_ANSI
#define MSOLEDBSQL_VI_ENUMERATOR_PROG_ID MSOLEDBSQL_VI_ENUMERATOR_PROG_ID_ANSI
#define MSOLEDBSQL_PROG_ID MSOLEDBSQL_PROG_ID_ANSI
#define MSOLEDBSQL_ERROR_LOOKUP_PROG_ID MSOLEDBSQL_ERROR_LOOKUP_PROG_ID_ANSI
#define MSOLEDBSQL_ENUMERATOR_PROG_ID MSOLEDBSQL_ENUMERATOR_PROG_ID_ANSI
#endif

#ifndef __oledb_h__
#include <oledb.h>
#endif

#define V_SS_VT(X) ((X)->vt)
#define V_SS_UNION(X, Y) ((X)->Y)
#define V_SS_UI1(X) V_SS_UNION(X, bTinyIntVal)
#define V_SS_I2(X) V_SS_UNION(X, sShortIntVal)
#define V_SS_I4(X) V_SS_UNION(X, lIntVal)
#define V_SS_I8(X) V_SS_UNION(X, llBigIntVal)
#define V_SS_R4(X) V_SS_UNION(X, fltRealVal)
#define V_SS_R8(X) V_SS_UNION(X, dblFloatVal)
#define V_SS_UI4(X) V_SS_UNION(X, ulVal)
#define V_SS_MONEY(X) V_SS_UNION(X, cyMoneyVal)
#define V_SS_SMALLMONEY(X) V_SS_UNION(X, cyMoneyVal)
#define V_SS_WSTRING(X) V_SS_UNION(X, NCharVal)
#define V_SS_WVARSTRING(X) V_SS_UNION(X, NCharVal)
#define V_SS_STRING(X) V_SS_UNION(X, CharVal)
#define V_SS_VARSTRING(X) V_SS_UNION(X, CharVal)
#define V_SS_BIT(X) V_SS_UNION(X, fBitVal)
#define V_SS_GUID(X) V_SS_UNION(X, rgbGuidVal)
#define V_SS_NUMERIC(X) V_SS_UNION(X, numNumericVal)
#define V_SS_DECIMAL(X) V_SS_UNION(X, numNumericVal)
#define V_SS_BINARY(X) V_SS_UNION(X, BinaryVal)
#define V_SS_VARBINARY(X) V_SS_UNION(X, BinaryVal)
#define V_SS_DATETIME(X) V_SS_UNION(X, tsDateTimeVal)
#define V_SS_SMALLDATETIME(X) V_SS_UNION(X, tsDateTimeVal)
#define V_SS_UNKNOWN(X) V_SS_UNION(X, UnknownType)
#define V_SS_IMAGE(X) V_SS_UNION(X, ImageVal)
#define V_SS_TEXT(X) V_SS_UNION(X, TextVal)
#define V_SS_NTEXT(X) V_SS_UNION(X, NTextVal)
#define V_SS_DATE(X) V_SS_UNION(X, dDateVal)
#define V_SS_TIME2(X) V_SS_UNION(X, Time2Val)
#define V_SS_DATETIME2(X) V_SS_UNION(X, DateTimeVal)
#define V_SS_DATETIMEOFFSET(X) V_SS_UNION(X, DateTimeOffsetVal)

typedef enum DBTYPEENUM EOledbTypes;
#define DBTYPE_XML ((EOledbTypes) 141)
#define DBTYPE_TABLE ((EOledbTypes) 143)
#define DBTYPE_DBTIME2 ((EOledbTypes) 145)
#define DBTYPE_DBTIMESTAMPOFFSET ((EOledbTypes) 146)
#ifdef _SQLOLEDB_H_
#undef DBTYPE_SQLVARIANT
#endif
#define DBTYPE_SQLVARIANT ((EOledbTypes) 144)

#ifndef _SQLOLEDB_H_
enum SQLVARENUM {
  VT_SS_EMPTY = DBTYPE_EMPTY, VT_SS_NULL = DBTYPE_NULL, VT_SS_UI1 = DBTYPE_UI1,
  VT_SS_I2 = DBTYPE_I2, VT_SS_I4 = DBTYPE_I4, VT_SS_I8 = DBTYPE_I8,
  VT_SS_R4 = DBTYPE_R4, VT_SS_R8 = DBTYPE_R8, VT_SS_MONEY = DBTYPE_CY,
  VT_SS_SMALLMONEY = 200, VT_SS_WSTRING = 201, VT_SS_WVARSTRING = 202,
  VT_SS_STRING = 203, VT_SS_VARSTRING = 204, VT_SS_BIT = DBTYPE_BOOL,
  VT_SS_GUID = DBTYPE_GUID, VT_SS_NUMERIC = DBTYPE_NUMERIC, VT_SS_DECIMAL = 205,
  VT_SS_DATETIME = DBTYPE_DBTIMESTAMP, VT_SS_SMALLDATETIME = 206,
  VT_SS_BINARY = 207, VT_SS_VARBINARY = 208, VT_SS_UNKNOWN = 209,
  VT_SS_DATE = DBTYPE_DBDATE, VT_SS_TIME2 = DBTYPE_DBTIME2,
  VT_SS_DATETIME2 = 212, VT_SS_DATETIMEOFFSET = DBTYPE_DBTIMESTAMPOFFSET
};
typedef unsigned short SSVARTYPE;

enum DBPARAMFLAGSENUM_SS_100 {
  DBPARAMFLAGS_SS_ISVARIABLESCALE = 0x40000000
};
enum DBCOLUMNFLAGSENUM_SS_100 {
  DBCOLUMNFLAGS_SS_ISVARIABLESCALE = 0x40000000,
  DBCOLUMNFLAGS_SS_ISCOLUMNSET = 0x80000000
};

extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0001_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0001_v0_0_s_ifspec;

#ifndef __IUMSInitialize_INTERFACE_DEFINED__
#define __IUMSInitialize_INTERFACE_DEFINED__

EXTERN_C const IID IID_IUMSInitialize;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct IUMSInitialize : public IUnknown {
public:
  virtual HRESULT WINAPI Initialize(void *pUMS) = 0;
};
#else
typedef struct IUMSInitializeVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(IUMSInitialize *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(IUMSInitialize *This);
    ULONG (WINAPI *Release)(IUMSInitialize *This);
    HRESULT (WINAPI *Initialize)(IUMSInitialize *This, void *pUMS);
  END_INTERFACE
} IUMSInitializeVtbl;
struct IUMSInitialize {
  CONST_VTBL struct IUMSInitializeVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define IUMSInitialize_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IUMSInitialize_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IUMSInitialize_Release(This) (This)->lpVtbl->Release(This)
#define IUMSInitialize_Initialize(This,pUMS) (This)->lpVtbl->Initialize(This,pUMS)
#endif
#endif
#endif

typedef struct tagSSErrorInfo {
  LPOLESTR pwszMessage;
  LPOLESTR pwszServer;
  LPOLESTR pwszProcedure;
  LONG lNative;
  BYTE bState;
  BYTE bClass;
  WORD wLineNumber;
} SSERRORINFO;

extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0002_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0002_v0_0_s_ifspec;

#ifndef __ISQLServerErrorInfo_INTERFACE_DEFINED__
#define __ISQLServerErrorInfo_INTERFACE_DEFINED__

EXTERN_C const IID IID_ISQLServerErrorInfo;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct ISQLServerErrorInfo : public IUnknown {
public:
  virtual HRESULT WINAPI GetErrorInfo(SSERRORINFO **ppErrorInfo, OLECHAR **ppStringsBuffer) = 0;
};
#else
typedef struct ISQLServerErrorInfoVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(ISQLServerErrorInfo *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(ISQLServerErrorInfo *This);
    ULONG (WINAPI *Release)(ISQLServerErrorInfo *This);
    HRESULT (WINAPI *GetErrorInfo)(ISQLServerErrorInfo *This, SSERRORINFO **ppErrorInfo, OLECHAR **ppStringsBuffer);
  END_INTERFACE
} ISQLServerErrorInfoVtbl;
struct ISQLServerErrorInfo {
  CONST_VTBL struct ISQLServerErrorInfoVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define ISQLServerErrorInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISQLServerErrorInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISQLServerErrorInfo_Release(This) (This)->lpVtbl->Release(This)
#define ISQLServerErrorInfo_GetErrorInfo(This,ppErrorInfo,ppStringsBuffer) (This)->lpVtbl->GetErrorInfo(This,ppErrorInfo,ppStringsBuffer)
#endif
#endif
#endif

#ifndef __IRowsetFastLoad_INTERFACE_DEFINED__
#define __IRowsetFastLoad_INTERFACE_DEFINED__

EXTERN_C const IID IID_IRowsetFastLoad;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct IRowsetFastLoad : public IUnknown {
public:
  virtual HRESULT WINAPI InsertRow(HACCESSOR hAccessor, void *pData) = 0;
  virtual HRESULT WINAPI Commit(BOOL fDone) = 0;
};
#else
typedef struct IRowsetFastLoadVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(IRowsetFastLoad *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(IRowsetFastLoad *This);
    ULONG (WINAPI *Release)(IRowsetFastLoad *This);
    HRESULT (WINAPI *InsertRow)(IRowsetFastLoad *This, HACCESSOR hAccessor, void *pData);
    HRESULT (WINAPI *Commit)(IRowsetFastLoad *This, BOOL fDone);
  END_INTERFACE
} IRowsetFastLoadVtbl;
struct IRowsetFastLoad {
  CONST_VTBL struct IRowsetFastLoadVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define IRowsetFastLoad_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetFastLoad_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetFastLoad_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetFastLoad_InsertRow(This,hAccessor,pData) (This)->lpVtbl->InsertRow(This,hAccessor,pData)
#define IRowsetFastLoad_Commit(This,fDone) (This)->lpVtbl->Commit(This,fDone)
#endif
#endif
#endif

#include <pshpack8.h>

typedef struct tagDBTIME2 {
  USHORT hour;
  USHORT minute;
  USHORT second;
  ULONG fraction;
} DBTIME2;

typedef struct tagDBTIMESTAMPOFFSET {
  SHORT year;
  USHORT month;
  USHORT day;
  USHORT hour;
  USHORT minute;
  USHORT second;
  ULONG fraction;
  SHORT timezone_hour;
  SHORT timezone_minute;
} DBTIMESTAMPOFFSET;

#include <poppack.h>

/* The original msoledbsql.h header uses a Microsoft-specific "extension" which
 * allows Microsoft Visual C++ compiler to ignore the [class.union.anon]'s first
 * paragraph in the standard for C++.  To allow to use other compilers for this
 * header, we have to alter declaration the original `SSVARIANT` structure and
 * move declarations of some `struct`s out of the anonymous union inside the
 * `SSVARIANT` in the code below (yes -- breaking public API of the original
 * header).  Moreover, we must place those moved declarations in different
 * locations for C and C++ code.  To avoid code duplication we use the
 * `MSOLEDBSQL_H_DECL_SSVARIANT_STRUCTS` macro. */
#define MSOLEDBSQL_H_DECL_SSVARIANT_STRUCTS \
    struct _Time2Val { \
      DBTIME2 tTime2Val; \
      BYTE bScale; \
    }; \
    struct _DateTimeVal { \
      DBTIMESTAMP tsDateTimeVal; \
      BYTE bScale; \
    }; \
    struct _DateTimeOffsetVal { \
      DBTIMESTAMPOFFSET tsoDateTimeOffsetVal; \
      BYTE bScale; \
    }; \
    struct _NCharVal { \
      SHORT sActualLength; \
      SHORT sMaxLength; \
      WCHAR *pwchNCharVal; \
      BYTE rgbReserved[5]; \
      DWORD dwReserved; \
      WCHAR *pwchReserved; \
    }; \
    struct _CharVal { \
      SHORT sActualLength; \
      SHORT sMaxLength; \
      CHAR *pchCharVal; \
      BYTE rgbReserved[5]; \
      DWORD dwReserved; \
      WCHAR *pwchReserved; \
    }; \
    struct _BinaryVal { \
      SHORT sActualLength; \
      SHORT sMaxLength; \
      BYTE *prgbBinaryVal; \
      DWORD dwReserved; \
    }; \
    struct _UnknownType { \
      DWORD dwActualLength; \
      BYTE rgMetadata[16]; \
      BYTE *pUnknownData; \
    }; \
    struct _BLOBType { \
      DBOBJECT dbobj; \
      IUnknown *pUnk; \
    };
/* As it's already mentioned the original msoledbsql.h header defines members of
 * the `SSVARIANT::{unnamed union}` of structure types specifying those types
 * directly at the member definitions, which is fine for C, but not for C++ (see
 * commentaries above).  Therefore, we have to separate declaration of those
 * structure types from the definition of the union's members.
 * For C code (`-x c`/`-Tc`) we can't declare the structure types directly
 * inside definition of the `SSVARIANT` type.  Because: a) some C compilers know
 * about `-fms-extensions` option, and if the latter was specified when invoking
 * such compiler, a structure type declared within an enclosing structure type
 * becomes anonymous structure (changing memory layout of the enclosing `struct`
 * and disallowing several "nested" structure to have fields of the same name);
 * b) for all other C compilers there is no much sense to declare "nested"
 * structure types within an enclosing one, because semantically it declares all
 * those "nested" structure types at scope where this header is included (6.2.1
 * Scopes of identifiers). */
#ifndef __cplusplus
  MSOLEDBSQL_H_DECL_SSVARIANT_STRUCTS
#endif
struct SSVARIANT {
  SSVARTYPE vt;
  DWORD dwReserved1;
  DWORD dwReserved2;
  /* For C++ code (`-x c++`/`-Tp`) we may move the declarations here.  This, at
   * least, limits scope of the declarations to the `SSVARIANT` structure, if we
   * compare declaration of the structures at the global scope (as it's made for
   * C code).  Both variants break public API of the original header file, but
   * unfortunately that's unavoidable. */
#ifdef __cplusplus
  MSOLEDBSQL_H_DECL_SSVARIANT_STRUCTS
#endif
  union {
    BYTE bTinyIntVal;
    SHORT sShortIntVal;
    LONG lIntVal;
    LONGLONG llBigIntVal;
    FLOAT fltRealVal;
    DOUBLE dblFloatVal;
    CY cyMoneyVal;
    VARIANT_BOOL fBitVal;
    BYTE rgbGuidVal[16];
    DB_NUMERIC numNumericVal;
    DBDATE dDateVal;
    DBTIMESTAMP tsDateTimeVal;
    struct _Time2Val Time2Val;
    struct _DateTimeVal DateTimeVal;
    struct _DateTimeOffsetVal DateTimeOffsetVal;
    struct _NCharVal NCharVal;
    struct _CharVal CharVal;
    struct _BinaryVal BinaryVal;
    struct _UnknownType UnknownType;
    struct _BLOBType BLOBType;
  };
};
typedef DWORD LOCKMODE;

enum LOCKMODEENUM {
  LOCKMODE_INVALID = 0, LOCKMODE_EXCLUSIVE = (LOCKMODE_INVALID + 1),
  LOCKMODE_SHARED = (LOCKMODE_EXCLUSIVE + 1)
};

extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0004_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0004_v0_0_s_ifspec;

#ifndef __ISchemaLock_INTERFACE_DEFINED__
#define __ISchemaLock_INTERFACE_DEFINED__

EXTERN_C const IID IID_ISchemaLock;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct ISchemaLock : public IUnknown {
public:
  virtual HRESULT WINAPI GetSchemaLock(DBID *pTableID, LOCKMODE lmMode, HANDLE *phLockHandle, ULONGLONG *pTableVersion) = 0;
  virtual HRESULT WINAPI ReleaseSchemaLock(HANDLE hLockHandle) = 0;
};
#else
typedef struct ISchemaLockVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(ISchemaLock *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(ISchemaLock *This);
    ULONG (WINAPI *Release)(ISchemaLock *This);
    HRESULT (WINAPI *GetSchemaLock)(ISchemaLock *This, DBID *pTableID, LOCKMODE lmMode, HANDLE *phLockHandle, ULONGLONG *pTableVersion);
    HRESULT (WINAPI *ReleaseSchemaLock)(ISchemaLock *This, HANDLE hLockHandle);
  END_INTERFACE
} ISchemaLockVtbl;
struct ISchemaLock {
  CONST_VTBL struct ISchemaLockVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define ISchemaLock_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISchemaLock_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISchemaLock_Release(This) (This)->lpVtbl->Release(This)
#define ISchemaLock_GetSchemaLock(This,pTableID,lmMode,phLockHandle,pTableVersion) (This)->lpVtbl->GetSchemaLock(This,pTableID,lmMode,phLockHandle,pTableVersion)
#define ISchemaLock_ReleaseSchemaLock(This,hLockHandle) (This)->lpVtbl->ReleaseSchemaLock(This,hLockHandle)
#endif
#endif
#endif

#ifndef __IBCPSession_INTERFACE_DEFINED__
#define __IBCPSession_INTERFACE_DEFINED__

EXTERN_C const IID IID_IBCPSession;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct IBCPSession : public IUnknown {
public:
  virtual HRESULT WINAPI BCPColFmt(DBORDINAL idxUserDataCol, int eUserDataType, int cbIndicator, int cbUserData, BYTE *pbUserDataTerm, int cbUserDataTerm, DBORDINAL idxServerCol) = 0;
  virtual HRESULT WINAPI BCPColumns(DBCOUNTITEM nColumns) = 0;
  virtual HRESULT WINAPI BCPControl(int eOption, void *iValue) = 0;
  virtual HRESULT WINAPI BCPDone(void) = 0;
  virtual HRESULT WINAPI BCPExec(DBROWCOUNT *pRowsCopied) = 0;
  virtual HRESULT WINAPI BCPInit(const wchar_t *pwszTable, const wchar_t *pwszDataFile, const wchar_t *pwszErrorFile, int eDirection) = 0;
  virtual HRESULT WINAPI BCPReadFmt(const wchar_t *pwszFormatFile) = 0;
  virtual HRESULT WINAPI BCPWriteFmt(const wchar_t *pwszFormatFile) = 0;
};
#else
typedef struct IBCPSessionVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(IBCPSession *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(IBCPSession *This);
    ULONG (WINAPI *Release)(IBCPSession *This);
    HRESULT (WINAPI *BCPColFmt)(IBCPSession *This, DBORDINAL idxUserDataCol, int eUserDataType, int cbIndicator, int cbUserData, BYTE *pbUserDataTerm, int cbUserDataTerm, DBORDINAL idxServerCol);
    HRESULT (WINAPI *BCPColumns)(IBCPSession *This, DBCOUNTITEM nColumns);
    HRESULT (WINAPI *BCPControl)(IBCPSession *This, int eOption, void *iValue);
    HRESULT (WINAPI *BCPDone)(IBCPSession *This);
    HRESULT (WINAPI *BCPExec)(IBCPSession *This, DBROWCOUNT *pRowsCopied);
    HRESULT (WINAPI *BCPInit)(IBCPSession *This, const wchar_t *pwszTable, const wchar_t *pwszDataFile, const wchar_t *pwszErrorFile, int eDirection);
    HRESULT (WINAPI *BCPReadFmt)(IBCPSession *This, const wchar_t *pwszFormatFile);
    HRESULT (WINAPI *BCPWriteFmt)(IBCPSession *This, const wchar_t *pwszFormatFile);
  END_INTERFACE
} IBCPSessionVtbl;
struct IBCPSession {
  CONST_VTBL struct IBCPSessionVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define IBCPSession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBCPSession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBCPSession_Release(This) (This)->lpVtbl->Release(This)
#define IBCPSession_BCPColFmt(This,idxUserDataCol,eUserDataType,cbIndicator,cbUserData,pbUserDataTerm,cbUserDataTerm,idxServerCol) (This)->lpVtbl->BCPColFmt(This,idxUserDataCol,eUserDataType,cbIndicator,cbUserData,pbUserDataTerm,cbUserDataTerm,idxServerCol)
#define IBCPSession_BCPColumns(This,nColumns) (This)->lpVtbl->BCPColumns(This,nColumns)
#define IBCPSession_BCPControl(This,eOption,iValue) (This)->lpVtbl->BCPControl(This,eOption,iValue)
#define IBCPSession_BCPDone(This) (This)->lpVtbl->BCPDone(This)
#define IBCPSession_BCPExec(This,pRowsCopied) (This)->lpVtbl->BCPExec(This,pRowsCopied)
#define IBCPSession_BCPInit(This,pwszTable,pwszDataFile,pwszErrorFile,eDirection) (This)->lpVtbl->BCPInit(This,pwszTable,pwszDataFile,pwszErrorFile,eDirection)
#define IBCPSession_BCPReadFmt(This,pwszFormatFile) (This)->lpVtbl->BCPReadFmt(This,pwszFormatFile)
#define IBCPSession_BCPWriteFmt(This,pwszFormatFile) (This)->lpVtbl->BCPWriteFmt(This,pwszFormatFile)
#endif
#endif
#endif

#ifndef __IBCPSession2_INTERFACE_DEFINED__
#define __IBCPSession2_INTERFACE_DEFINED__

EXTERN_C const IID IID_IBCPSession2;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct IBCPSession2 : public IBCPSession {
public:
  virtual HRESULT WINAPI BCPSetBulkMode(int property, void *pField, int cbField, void *pRow, int cbRow) = 0;
};
#else
typedef struct IBCPSession2Vtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(IBCPSession2 *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(IBCPSession2 *This);
    ULONG (WINAPI *Release)(IBCPSession2 *This);
    HRESULT (WINAPI *BCPColFmt)(IBCPSession2 *This, DBORDINAL idxUserDataCol, int eUserDataType, int cbIndicator, int cbUserData, BYTE *pbUserDataTerm, int cbUserDataTerm, DBORDINAL idxServerCol);
    HRESULT (WINAPI *BCPColumns)(IBCPSession2 *This, DBCOUNTITEM nColumns);
    HRESULT (WINAPI *BCPControl)(IBCPSession2 *This, int eOption, void *iValue);
    HRESULT (WINAPI *BCPDone)(IBCPSession2 *This);
    HRESULT (WINAPI *BCPExec)(IBCPSession2 *This, DBROWCOUNT *pRowsCopied);
    HRESULT (WINAPI *BCPInit)(IBCPSession2 *This, const wchar_t *pwszTable, const wchar_t *pwszDataFile, const wchar_t *pwszErrorFile, int eDirection);
    HRESULT (WINAPI *BCPReadFmt)(IBCPSession2 *This, const wchar_t *pwszFormatFile);
    HRESULT (WINAPI *BCPWriteFmt)(IBCPSession2 *This, const wchar_t *pwszFormatFile);
    HRESULT (WINAPI *BCPSetBulkMode)(IBCPSession2 *This, int property, void *pField, int cbField, void *pRow, int cbRow);
  END_INTERFACE
} IBCPSession2Vtbl;
struct IBCPSession2 {
  CONST_VTBL struct IBCPSession2Vtbl *lpVtbl;
};
#ifdef COBJMACROS
#define IBCPSession2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBCPSession2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBCPSession2_Release(This) (This)->lpVtbl->Release(This)
#define IBCPSession2_BCPColFmt(This,idxUserDataCol,eUserDataType,cbIndicator,cbUserData,pbUserDataTerm,cbUserDataTerm,idxServerCol) (This)->lpVtbl->BCPColFmt(This,idxUserDataCol,eUserDataType,cbIndicator,cbUserData,pbUserDataTerm,cbUserDataTerm,idxServerCol)
#define IBCPSession2_BCPColumns(This,nColumns) (This)->lpVtbl->BCPColumns(This,nColumns)
#define IBCPSession2_BCPControl(This,eOption,iValue) (This)->lpVtbl->BCPControl(This,eOption,iValue)
#define IBCPSession2_BCPDone(This) (This)->lpVtbl->BCPDone(This)
#define IBCPSession2_BCPExec(This,pRowsCopied) (This)->lpVtbl->BCPExec(This,pRowsCopied)
#define IBCPSession2_BCPInit(This,pwszTable,pwszDataFile,pwszErrorFile,eDirection) (This)->lpVtbl->BCPInit(This,pwszTable,pwszDataFile,pwszErrorFile,eDirection)
#define IBCPSession2_BCPReadFmt(This,pwszFormatFile) (This)->lpVtbl->BCPReadFmt(This,pwszFormatFile)
#define IBCPSession2_BCPWriteFmt(This,pwszFormatFile) (This)->lpVtbl->BCPWriteFmt(This,pwszFormatFile)
#define IBCPSession2_BCPSetBulkMode(This,property,pField,cbField,pRow,cbRow) (This,property,pField,cbField,pRow,cbRow)
#endif
#endif
#endif
#endif /* not _SQLOLEDB_H_ */

#define ISOLATIONLEVEL_SNAPSHOT ((ISOLATIONLEVEL)(0x01000000))
#define DBPROPVAL_TI_SNAPSHOT 0x01000000L

extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0007_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0007_v0_0_s_ifspec;

#ifndef __ISSAbort_INTERFACE_DEFINED__
#define __ISSAbort_INTERFACE_DEFINED__

EXTERN_C const IID IID_ISSAbort;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct ISSAbort : public IUnknown {
public:
  virtual HRESULT WINAPI Abort(void) = 0;
};
#else
typedef struct ISSAbortVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(ISSAbort *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(ISSAbort *This);
    ULONG (WINAPI *Release)(ISSAbort *This);
    HRESULT (WINAPI *Abort)(ISSAbort *This);
  END_INTERFACE
} ISSAbortVtbl;
struct ISSAbort {
  CONST_VTBL struct ISSAbortVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define ISSAbort_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISSAbort_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISSAbort_Release(This) (This)->lpVtbl->Release(This)
#define ISSAbort_Abort(This) (This)->lpVtbl->Abort(This)
#endif
#endif
#endif

enum DBBINDFLAGENUM90 {
  DBBINDFLAG_OBJECT = 0x2
};

enum SSACCESSORFLAGS {
  SSACCESSOR_ROWDATA = 0x100
};

enum DBPROPFLAGSENUM90 {
  DBPROPFLAGS_PARAMETER = 0x10000
};

typedef struct tagSSPARAMPROPS {
  DBORDINAL iOrdinal;
  ULONG cPropertySets;
  DBPROPSET *rgPropertySets;
} SSPARAMPROPS;

extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0008_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0008_v0_0_s_ifspec;

#ifndef __ISSCommandWithParameters_INTERFACE_DEFINED__
#define __ISSCommandWithParameters_INTERFACE_DEFINED__

EXTERN_C const IID IID_ISSCommandWithParameters;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct ISSCommandWithParameters : public ICommandWithParameters {
public:
  virtual HRESULT WINAPI GetParameterProperties(DB_UPARAMS *pcParams, SSPARAMPROPS **prgParamProperties) = 0;
  virtual HRESULT WINAPI SetParameterProperties(DB_UPARAMS cParams, SSPARAMPROPS rgParamProperties[]) = 0;
};
#else
typedef struct ISSCommandWithParametersVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(ISSCommandWithParameters *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(ISSCommandWithParameters *This);
    ULONG (WINAPI *Release)(ISSCommandWithParameters *This);
    HRESULT (WINAPI *GetParameterInfo)(ISSCommandWithParameters *This, DB_UPARAMS *pcParams, DBPARAMINFO **prgParamInfo, OLECHAR **ppNamesBuffer);
    HRESULT (WINAPI *MapParameterNames)(ISSCommandWithParameters *This, DB_UPARAMS cParamNames, const OLECHAR *rgParamNames[], DB_LPARAMS rgParamOrdinals[]);
    HRESULT (WINAPI *SetParameterInfo)(ISSCommandWithParameters *This, DB_UPARAMS cParams, const DB_UPARAMS rgParamOrdinals[], const DBPARAMBINDINFO rgParamBindInfo[]);
    HRESULT (WINAPI *GetParameterProperties)(ISSCommandWithParameters *This, DB_UPARAMS *pcParams, SSPARAMPROPS **prgParamProperties);
    HRESULT (WINAPI *SetParameterProperties)(ISSCommandWithParameters *This, DB_UPARAMS cParams, SSPARAMPROPS rgParamProperties[]);
  END_INTERFACE
} ISSCommandWithParametersVtbl;
struct ISSCommandWithParameters {
  CONST_VTBL struct ISSCommandWithParametersVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define ISSCommandWithParameters_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISSCommandWithParameters_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISSCommandWithParameters_Release(This) (This)->lpVtbl->Release(This)
#define ISSCommandWithParameters_GetParameterInfo(This,pcParams,prgParamInfo,ppNamesBuffer) (This)->lpVtbl->GetParameterInfo(This,pcParams,prgParamInfo,ppNamesBuffer)
#define ISSCommandWithParameters_MapParameterNames(This,cParamNames,rgParamNames,rgParamOrdinals) (This)->lpVtbl->MapParameterNames(This,cParamNames,rgParamNames,rgParamOrdinals)
#define ISSCommandWithParameters_SetParameterInfo(This,cParams,rgParamOrdinals,rgParamBindInfo) (This)->lpVtbl->SetParameterInfo(This,cParams,rgParamOrdinals,rgParamBindInfo)
#define ISSCommandWithParameters_GetParameterProperties(This,pcParams,prgParamProperties) (This)->lpVtbl->GetParameterProperties(This,pcParams,prgParamProperties)
#define ISSCommandWithParameters_SetParameterProperties(This,cParams,rgParamProperties) (This)->lpVtbl->SetParameterProperties(This,cParams,rgParamProperties)
#endif
#endif
#endif

#ifndef __IDBAsynchStatus_INTERFACE_DEFINED__
#define __IDBAsynchStatus_INTERFACE_DEFINED__

EXTERN_C const IID IID_IDBAsynchStatus;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct IDBAsynchStatus : public IUnknown {
public:
  virtual HRESULT WINAPI Abort(HCHAPTER hChapter, DBASYNCHOP eOperation) = 0;
  virtual HRESULT WINAPI GetStatus(HCHAPTER hChapter, DBASYNCHOP eOperation, DBCOUNTITEM *pulProgress, DBCOUNTITEM *pulProgressMax, DBASYNCHPHASE *peAsynchPhase, LPOLESTR *ppwszStatusText) = 0;
};
#else
typedef struct IDBAsynchStatusVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(IDBAsynchStatus *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(IDBAsynchStatus *This);
    ULONG (WINAPI *Release)(IDBAsynchStatus *This);
    HRESULT (WINAPI *Abort)(IDBAsynchStatus *This, HCHAPTER hChapter, DBASYNCHOP eOperation);
    HRESULT (WINAPI *GetStatus)(IDBAsynchStatus *This, HCHAPTER hChapter, DBASYNCHOP eOperation, DBCOUNTITEM *pulProgress, DBCOUNTITEM *pulProgressMax, DBASYNCHPHASE *peAsynchPhase, LPOLESTR *ppwszStatusText);
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

HRESULT WINAPI IDBAsynchStatus_RemoteAbort_Proxy(IDBAsynchStatus *This, HCHAPTER hChapter, DBASYNCHOP eOperation, IErrorInfo **ppErrorInfoRem);
void __RPC_STUB IDBAsynchStatus_RemoteAbort_Stub(IRpcStubBuffer *This, IRpcChannelBuffer *_pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD *_pdwStubPhase);
HRESULT WINAPI IDBAsynchStatus_RemoteGetStatus_Proxy(IDBAsynchStatus *This, HCHAPTER hChapter, DBASYNCHOP eOperation, DBCOUNTITEM *pulProgress, DBCOUNTITEM *pulProgressMax, DBASYNCHPHASE *peAsynchPhase, LPOLESTR *ppwszStatusText, IErrorInfo **ppErrorInfoRem);
void __RPC_STUB IDBAsynchStatus_RemoteGetStatus_Stub(IRpcStubBuffer *This, IRpcChannelBuffer *_pRpcChannelBuffer, PRPC_MESSAGE _pRpcMessage, DWORD *_pdwStubPhase);
#endif

#ifndef __ISSAsynchStatus_INTERFACE_DEFINED__
#define __ISSAsynchStatus_INTERFACE_DEFINED__

EXTERN_C const IID IID_ISSAsynchStatus;

#if defined(__cplusplus) && !defined(CINTERFACE)
struct ISSAsynchStatus : public IDBAsynchStatus {
public:
  virtual HRESULT WINAPI WaitForAsynchCompletion(DWORD dwMillisecTimeOut) = 0;
};
#else
typedef struct ISSAsynchStatusVtbl {
  BEGIN_INTERFACE
    HRESULT (WINAPI *QueryInterface)(ISSAsynchStatus *This, REFIID riid, void **ppvObject);
    ULONG (WINAPI *AddRef)(ISSAsynchStatus *This);
    ULONG (WINAPI *Release)(ISSAsynchStatus *This);
    HRESULT (WINAPI *Abort)(ISSAsynchStatus *This, HCHAPTER hChapter, DBASYNCHOP eOperation);
    HRESULT (WINAPI *GetStatus)(ISSAsynchStatus *This, HCHAPTER hChapter, DBASYNCHOP eOperation, DBCOUNTITEM *pulProgress, DBCOUNTITEM *pulProgressMax, DBASYNCHPHASE *peAsynchPhase, LPOLESTR *ppwszStatusText);
    HRESULT (WINAPI *WaitForAsynchCompletion)(ISSAsynchStatus *This, DWORD dwMillisecTimeOut);
  END_INTERFACE
} ISSAsynchStatusVtbl;
struct ISSAsynchStatus {
  CONST_VTBL struct ISSAsynchStatusVtbl *lpVtbl;
};
#ifdef COBJMACROS
#define ISSAsynchStatus_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISSAsynchStatus_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISSAsynchStatus_Release(This) (This)->lpVtbl->Release(This)
#define ISSAsynchStatus_Abort(This,hChapter,eOperation) (This)->lpVtbl->Abort(This,hChapter,eOperation)
#define ISSAsynchStatus_GetStatus(This,hChapter,eOperation,pulProgress,pulProgressMax,peAsynchPhase,ppwszStatusText) (This)->lpVtbl->GetStatus(This,hChapter,eOperation,pulProgress,pulProgressMax,peAsynchPhase,ppwszStatusText)
#define ISSAsynchStatus_WaitForAsynchCompletion(This,dwMillisecTimeOut) (This)->lpVtbl->WaitForAsynchCompletion(This,dwMillisecTimeOut)
#endif
#endif
#endif

#define TABLE_HAS_UPDATE_INSTEAD_OF_TRIGGER 0x00000001
#define TABLE_HAS_DELETE_INSTEAD_OF_TRIGGER 0x00000002
#define TABLE_HAS_INSERT_INSTEAD_OF_TRIGGER 0x00000004
#define TABLE_HAS_AFTER_UPDATE_TRIGGER 0x00000008
#define TABLE_HAS_AFTER_DELETE_TRIGGER 0x00000010
#define TABLE_HAS_AFTER_INSERT_TRIGGER 0x00000020
#define TABLE_HAS_CASCADE_UPDATE 0x00000040
#define TABLE_HAS_CASCADE_DELETE 0x00000080

#if (OLEDBVER >= 0x0210)
#define DBPROP_INIT_GENERALTIMEOUT 0x11cL
#endif

#define SSPROP_ENABLEFASTLOAD 2
#define SSPROP_ENABLEBULKCOPY 3
#define SSPROP_UNICODELCID 2
#define SSPROP_UNICODECOMPARISONSTYLE 3
#define SSPROP_COLUMNLEVELCOLLATION 4
#define SSPROP_CHARACTERSET 5
#define SSPROP_SORTORDER 6
#define SSPROP_CURRENTCOLLATION 7
#define SSPROP_INTEGRATEDAUTHENTICATIONMETHOD 8
#define SSPROP_MUTUALLYAUTHENTICATED 9
#define SSPROP_INIT_CURRENTLANGUAGE 4
#define SSPROP_INIT_NETWORKADDRESS 5
#define SSPROP_INIT_NETWORKLIBRARY 6
#define SSPROP_INIT_USEPROCFORPREP 7
#define SSPROP_INIT_AUTOTRANSLATE 8
#define SSPROP_INIT_PACKETSIZE 9
#define SSPROP_INIT_APPNAME 10
#define SSPROP_INIT_WSID 11
#define SSPROP_INIT_FILENAME 12
#define SSPROP_INIT_ENCRYPT 13
#define SSPROP_AUTH_REPL_SERVER_NAME 14
#define SSPROP_INIT_TAGCOLUMNCOLLATION 15
#define SSPROP_INIT_MARSCONNECTION 16
#define SSPROP_INIT_FAILOVERPARTNER 18
#define SSPROP_AUTH_OLD_PASSWORD 19
#define SSPROP_INIT_DATATYPECOMPATIBILITY 20
#define SSPROP_INIT_TRUST_SERVER_CERTIFICATE 21
#define SSPROP_INIT_SERVERSPN 22
#define SSPROP_INIT_FAILOVERPARTNERSPN 23
#define SSPROP_INIT_APPLICATIONINTENT 24
#define SSPROP_INIT_MULTISUBNETFAILOVER 25
#define SSPROP_INIT_USEFMTONLY 26
#define SSPROPVAL_USEPROCFORPREP_OFF 0
#define SSPROPVAL_USEPROCFORPREP_ON 1
#define SSPROPVAL_USEPROCFORPREP_ON_DROP 2
#define SSPROPVAL_DATATYPECOMPATIBILITY_SQL2000 80
#define SSPROPVAL_DATATYPECOMPATIBILITY_DEFAULT 0
#define SSPROP_QUOTEDCATALOGNAMES 2
#define SSPROP_ALLOWNATIVEVARIANT 3
#define SSPROP_SQLXMLXPROGID 4
#define SSPROP_ASYNCH_BULKCOPY 5
#define SSPROP_MAXBLOBLENGTH 8
#define SSPROP_FASTLOADOPTIONS 9
#define SSPROP_FASTLOADKEEPNULLS 10
#define SSPROP_FASTLOADKEEPIDENTITY 11
#define SSPROP_CURSORAUTOFETCH 12
#define SSPROP_DEFERPREPARE 13
#define SSPROP_IRowsetFastLoad 14
#define SSPROP_QP_NOTIFICATION_TIMEOUT 17
#define SSPROP_QP_NOTIFICATION_MSGTEXT 18
#define SSPROP_QP_NOTIFICATION_OPTIONS 19
#define SSPROP_NOCOUNT_STATUS 20
#define SSPROP_COMPUTE_ID 21
#define SSPROP_COLUMN_ID 22
#define SSPROP_COMPUTE_BYLIST 23
#define SSPROP_ISSAsynchStatus 24
#define SSPROPVAL_DEFAULT_NOTIFICATION_TIMEOUT 432000
#define SSPROPVAL_MAX_NOTIFICATION_TIMEOUT 0x7FFFFFFF
#define MAX_NOTIFICATION_LEN 2000
#define SSPROP_COL_COLLATIONNAME 14
#define SSPROP_COL_UDT_CATALOGNAME 31
#define SSPROP_COL_UDT_SCHEMANAME 32
#define SSPROP_COL_UDT_NAME 33
#define SSPROP_COL_XML_SCHEMACOLLECTION_CATALOGNAME 34
#define SSPROP_COL_XML_SCHEMACOLLECTION_SCHEMANAME 35
#define SSPROP_COL_XML_SCHEMACOLLECTIONNAME 36
#define SSPROP_COL_COMPUTED 37
#define SSPROP_STREAM_XMLROOT 19
#define SSPROP_PARAM_XML_SCHEMACOLLECTION_CATALOGNAME 24
#define SSPROP_PARAM_XML_SCHEMACOLLECTION_SCHEMANAME 25
#define SSPROP_PARAM_XML_SCHEMACOLLECTIONNAME 26
#define SSPROP_PARAM_UDT_CATALOGNAME 27
#define SSPROP_PARAM_UDT_SCHEMANAME 28
#define SSPROP_PARAM_UDT_NAME 29
#define SSPROP_PARAM_TYPE_CATALOGNAME 38
#define SSPROP_PARAM_TYPE_SCHEMANAME 39
#define SSPROP_PARAM_TYPE_TYPENAME 40
#define SSPROP_PARAM_TABLE_DEFAULT_COLUMNS 41
#define SSPROP_PARAM_TABLE_COLUMN_SORT_ORDER 42
#define SSPROP_INDEX_XML 1
#define BCP_TYPE_DEFAULT 0x00
#define BCP_TYPE_SQLTEXT 0x23
#define BCP_TYPE_SQLVARBINARY 0x25
#define BCP_TYPE_SQLINTN 0x26
#define BCP_TYPE_SQLVARCHAR 0x27
#define BCP_TYPE_SQLBINARY 0x2d
#define BCP_TYPE_SQLIMAGE 0x22
#define BCP_TYPE_SQLCHARACTER 0x2f
#define BCP_TYPE_SQLINT1 0x30
#define BCP_TYPE_SQLBIT 0x32
#define BCP_TYPE_SQLINT2 0x34
#define BCP_TYPE_SQLINT4 0x38
#define BCP_TYPE_SQLMONEY 0x3c
#define BCP_TYPE_SQLDATETIME 0x3d
#define BCP_TYPE_SQLFLT8 0x3e
#define BCP_TYPE_SQLFLTN 0x6d
#define BCP_TYPE_SQLMONEYN 0x6e
#define BCP_TYPE_SQLDATETIMN 0x6f
#define BCP_TYPE_SQLFLT4 0x3b
#define BCP_TYPE_SQLMONEY4 0x7a
#define BCP_TYPE_SQLDATETIM4 0x3a
#define BCP_TYPE_SQLDECIMAL 0x6a
#define BCP_TYPE_SQLNUMERIC 0x6c
#define BCP_TYPE_SQLUNIQUEID 0x24
#define BCP_TYPE_SQLBIGCHAR 0xaf
#define BCP_TYPE_SQLBIGVARCHAR 0xa7
#define BCP_TYPE_SQLBIGBINARY 0xad
#define BCP_TYPE_SQLBIGVARBINARY
#define BCP_TYPE_SQLBITN 0x68
#define BCP_TYPE_SQLNCHAR 0xef
#define BCP_TYPE_SQLNVARCHAR 0xe7
#define BCP_TYPE_SQLNTEXT 0x63
#define BCP_TYPE_SQLDECIMALN 0x6a
#define BCP_TYPE_SQLNUMERICN 0x6c
#define BCP_TYPE_SQLINT8 0x7f
#define BCP_TYPE_SQLVARIANT 0x62
#define BCP_TYPE_SQLUDT 0xf0
#define BCP_TYPE_SQLXML 0xf1
#define BCP_TYPE_SQLDATE 0x28
#define BCP_TYPE_SQLTIME 0x29
#define BCP_TYPE_SQLDATETIME2 0x2a
#define BCP_TYPE_SQLDATETIMEOFFSET 0x2b
#define BCP_DIRECTION_IN 1
#define BCP_DIRECTION_OUT 2
#define BCP_OPTION_MAXERRS 1
#define BCP_OPTION_FIRST 2
#define BCP_OPTION_LAST 3
#define BCP_OPTION_BATCH 4
#define BCP_OPTION_KEEPNULLS 5
#define BCP_OPTION_ABORT 6
#define BCP_OPTION_KEEPIDENTITY 8
#define BCP_OPTION_HINTSA 10
#define BCP_OPTION_HINTSW 11
#define BCP_OPTION_FILECP 12
#define BCP_OPTION_UNICODEFILE 13
#define BCP_OPTION_TEXTFILE 14
#define BCP_OPTION_FILEFMT 15
#define BCP_OPTION_FMTXML 16
#define BCP_OPTION_FIRSTEX 17
#define BCP_OPTION_LASTEX 18
#define BCP_OPTION_ROWCOUNT 19
#define BCP_OPTION_DELAYREADFMT 20
#define BCP_OUT_CHARACTER_MODE 0x01
#define BCP_OUT_WIDE_CHARACTER_MODE 0x02
#define BCP_OUT_NATIVE_TEXT_MODE 0x03
#define BCP_OUT_NATIVE_MODE 0x04
#define BCP_FILECP_ACP 0
#define BCP_FILECP_OEMCP 1
#define BCP_FILECP_RAW (-1)
#ifdef UNICODE
#define BCP_OPTION_HINTS BCP_OPTION_HINTSW
#else
#define BCP_OPTION_HINTS BCP_OPTION_HINTSA
#endif
#define BCP_PREFIX_DEFAULT (-10)
#define BCP_LENGTH_NULL (-1)
#define BCP_LENGTH_VARIABLE (-10)

#if (MSOLEDBSQL_VER >= 1800)
#ifdef DBINITCONSTANTS
extern const GUID CLSID_MSOLEDBSQL = {0x5a23de84L,0x1d7b,0x4a16,{0x8d,0xed,0xb2,0x9c,0x9,0xcb,0x64,0x8d}};
extern const GUID CLSID_MSOLEDBSQL_ERROR = {0xecab1ccbL,0x116a,0x4541,{0xad,0xba,0x69,0xc,0xeb,0x9c,0xc8,0x43}};
extern const GUID CLSID_MSOLEDBSQL_ENUMERATOR = {0x720818d5L,0x1465,0x4812,{0x83,0x9f,0x9f,0x15,0xc3,0x8a,0x52,0xcb}};
#else
extern const GUID CLSID_MSOLEDBSQL;
extern const GUID CLSID_MSOLEDBSQL_ERROR;
extern const GUID CLSID_MSOLEDBSQL_ENUMERATOR;
#endif
#endif
#ifdef DBINITCONSTANTS
extern const GUID CLSID_ROWSET_TVP = {0xc7ef28d5L,0x7bee,0x443f,{0x86,0xda,0xe3,0x98,0x4f,0xcd,0x4d,0xf9}};
#else
extern const GUID CLSID_ROWSET_TVP;
#endif

#ifndef _SQLOLEDB_H_
#ifdef DBINITCONSTANTS
extern const GUID IID_ISQLServerErrorInfo = {0x5cf4ca12,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID IID_IRowsetFastLoad = {0x5cf4ca13,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID IID_IUMSInitialize = {0x5cf4ca14,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID IID_ISchemaLock = {0x4c2389fb,0x2511,0x11d4,{0xb2,0x58,0x0,0xc0,0x4f,0x79,0x71,0xce}};
extern const GUID IID_ISQLXMLHelper = {0xd22a7678L,0xf860,0x40cd,{0xa5,0x67,0x15,0x63,0xde,0xb4,0x6d,0x49}};
#else
extern const GUID IID_ISQLServerErrorInfo;
extern const GUID IID_IRowsetFastLoad;
extern const GUID IID_IUMSInitialize;
extern const GUID IID_ISchemaLock;
extern const GUID IID_ISQLXMLHelper;
#endif
#endif
#ifdef DBINITCONSTANTS
extern const GUID IID_ISSAbort = {0x5cf4ca15,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID IID_IBCPSession = {0x88352D80,0x42D1,0x42f0,{0xA1,0x70,0xAB,0x0F,0x8B,0x45,0xB9,0x39}};
extern const GUID IID_IBCPSession2 = {0xad79d3b6,0x59dd,0x46a3,{0xbf,0xc6,0xe6,0x2a,0x65,0xff,0x35,0x23}};
extern const GUID IID_ISSCommandWithParameters = {0xeec30162,0x6087,0x467c,{0xb9,0x95,0x7c,0x52,0x3c,0xe9,0x65,0x61}};
extern const GUID IID_ISSAsynchStatus = {0x1FF1F743,0x8BB0, 0x4c00,{0xAC,0xC4,0xC1,0x0E,0x43,0xB0,0x8F,0xC1}};
#else
extern const GUID IID_ISSAbort;
extern const GUID IID_IBCPSession;
extern const GUID IID_IBCPSession2;
extern const GUID IID_ISSCommandWithParameters;
extern const GUID IID_ISSAsynchStatus;
#endif

#ifndef _SQLOLEDB_H_
#ifdef DBINITCONSTANTS
extern const GUID DBSCHEMA_LINKEDSERVERS = {0x9093caf4,0x2eac,0x11d1,{0x98,0x9,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
#else
extern const GUID DBSCHEMA_LINKEDSERVERS;
#endif
#endif
#ifdef DBINITCONSTANTS
extern const GUID DBSCHEMA_SQL_ASSEMBLIES = {0x7c1112c8, 0xc2d3, 0x4f6e, {0x94, 0x9a, 0x98, 0x3d, 0x38, 0xa5, 0x8f, 0x46}};
extern const GUID DBSCHEMA_SQL_ASSEMBLY_DEPENDENCIES = {0xcb0f837b, 0x974c, 0x41b8, {0x90, 0x9d, 0x64, 0x9c, 0xaf, 0x45, 0xad, 0x2f}};
extern const GUID DBSCHEMA_SQL_USER_TYPES = {0xf1198bd8, 0xa424, 0x4ea3, {0x8d, 0x4c, 0x60, 0x7e, 0xee, 0x2b, 0xab, 0x60}};
extern const GUID DBSCHEMA_XML_COLLECTIONS = {0x56bfad8c, 0x6e8f, 0x480d, {0x91, 0xde, 0x35, 0x16, 0xd9, 0x9a, 0x5d, 0x10}};
extern const GUID DBSCHEMA_SQL_TABLE_TYPES = {0x4e26cde7, 0xaaa4, 0x41ed, {0x93, 0xdd, 0x37, 0x6e, 0x6d, 0x40, 0x9c, 0x17}};
extern const GUID DBSCHEMA_SQL_TABLE_TYPE_PRIMARY_KEYS = {0x9738faea, 0x31e8, 0x4f63, {0xae,  0xd, 0x61, 0x33, 0x16, 0x41, 0x8c, 0xdd}};
extern const GUID DBSCHEMA_SQL_TABLE_TYPE_COLUMNS = {0xa663d94b, 0xddf7, 0x4a7f, {0xa5, 0x37, 0xd6, 0x1f, 0x12, 0x36, 0x5d, 0x7c}};
extern const GUID DBSCHEMA_COLUMNS_EXTENDED = {0x66462f01, 0x633a, 0x44d9, {0xb0, 0xd0, 0xfe, 0x66, 0xf2, 0x1a, 0x0d, 0x24}};
extern const GUID DBSCHEMA_SPARSE_COLUMN_SET = {0x31a4837c, 0xf9ff, 0x405f, {0x89, 0x82, 0x02, 0x19, 0xaa, 0xaa, 0x4a, 0x12}};
#else
extern const GUID DBSCHEMA_SQL_ASSEMBLIES;
extern const GUID DBSCHEMA_SQL_ASSEMBLY_DEPENDENCIES;
extern const GUID DBSCHEMA_SQL_USER_TYPES;
extern const GUID DBSCHEMA_XML_COLLECTIONS;
extern const GUID DBSCHEMA_SQL_TABLE_TYPES;
extern const GUID DBSCHEMA_SQL_TABLE_TYPE_PRIMARY_KEYS;
extern const GUID DBSCHEMA_SQL_TABLE_TYPE_COLUMNS;
extern const GUID DBSCHEMA_COLUMNS_EXTENDED;
extern const GUID DBSCHEMA_SPARSE_COLUMN_SET;
#endif

#ifndef CRESTRICTIONS_DBSCHEMA_LINKEDSERVERS
#define CRESTRICTIONS_DBSCHEMA_LINKEDSERVERS 1
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_ASSEMBLIES
#define CRESTRICTIONS_DBSCHEMA_SQL_ASSEMBLIES 4
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_ASSEMBLY_DEPENDENCIES
#define CRESTRICTIONS_DBSCHEMA_SQL_ASSEMBLY_DEPENDENCIES 4
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_USER_TYPES
#define CRESTRICTIONS_DBSCHEMA_SQL_USER_TYPES 3
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_XML_COLLECTIONS
#define CRESTRICTIONS_DBSCHEMA_XML_COLLECTIONS 4
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_SQL_TABLE_TYPES
#define CRESTRICTIONS_DBSCHEMA_SQL_TABLE_TYPES 3
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_SQL_TABLE_TYPE_PRIMARY_KEYS
#define CRESTRICTIONS_DBSCHEMA_SQL_TABLE_TYPE_PRIMARY_KEYS 3
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_SQL_TABLE_TYPE_COLUMNS
#define CRESTRICTIONS_DBSCHEMA_SQL_TABLE_TYPE_COLUMNS 4
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_COLUMNS_EXTENDED
#define CRESTRICTIONS_DBSCHEMA_COLUMNS_EXTENDED 4
#endif
#ifndef CRESTRICTIONS_DBSCHEMA_SPARSE_COLUMN_SET
#define CRESTRICTIONS_DBSCHEMA_SPARSE_COLUMN_SET 4
#endif

#ifndef _SQLOLEDB_H_
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERDATASOURCE = {0x28efaee4,0x2d2c,0x11d1,{0x98,0x7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERDATASOURCEINFO= {0xdf10cb94,0x35f6,0x11d2,{0x9c,0x54,0x0,0xc0,0x4f,0x79,0x71,0xd3}};
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERDBINIT = {0x5cf4ca10,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERROWSET = {0x5cf4ca11,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERSESSION = {0x28efaee5,0x2d2c,0x11d1,{0x98,0x7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERCOLUMN = {0x3b63fb5e,0x3fbb,0x11d3,{0x9f,0x29,0x0,0xc0,0x4f,0x8e,0xe9,0xdc}};
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERSTREAM = {0x9f79c073,0x8a6d,0x4bca,{0xa8,0xa8,0xc9,0xb7,0x9a,0x9b,0x96,0x2d}};
#endif
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERPARAMETER = {0xfee09128,0xa67d,0x47ea,{0x8d,0x40,0x24,0xa1,0xd4,0x73,0x7e,0x8d}};
extern const GUID OLEDBDECLSPEC DBPROPSET_SQLSERVERINDEX = {0xE428B84E,0xA6B7,0x413a,{0x94,0x65,0x56,0x23,0x2E,0x0D,0x2B,0xEB}};
extern const GUID OLEDBDECLSPEC DBPROPSET_PARAMETERALL = {0x2cd2b7d8,0xe7c2,0x4f6c,{0x9b,0x30,0x75,0xe2,0x58,0x46,0x10,0x97}};

#define DBCOLUMN_SS_X_GUID {0x627bd890,0xed54,0x11d2,{0xb9,0x94,0x0,0xc0,0x4f,0x8c,0xa8,0x2c}}

#ifndef _SQLOLEDB_H_
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_COMPFLAGS = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)100};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_SORTID = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)101};
extern const DBID OLEDBDECLSPEC DBCOLUMN_BASETABLEINSTANCE = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)102};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_TDSCOLLATION = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)103};
#endif
extern const DBID OLEDBDECLSPEC DBCOLUMN_BASESERVERNAME = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)104};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_XML_SCHEMACOLLECTION_CATALOGNAME = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)105};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_XML_SCHEMACOLLECTION_SCHEMANAME = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)106};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_XML_SCHEMACOLLECTIONNAME = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)107};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_UDT_CATALOGNAME = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)108};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_UDT_SCHEMANAME = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)109};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_UDT_NAME = {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)110};
extern const DBID OLEDBDECLSPEC DBCOLUMN_SS_ASSEMBLY_TYPENAME= {DBCOLUMN_SS_X_GUID, DBKIND_GUID_PROPID, (LPOLESTR)111};

#ifndef SQL_FILESTREAM_DEFINED
#define SQL_FILESTREAM_DEFINED
typedef enum _SQL_FILESTREAM_DESIRED_ACCESS {
  SQL_FILESTREAM_READ = 0, SQL_FILESTREAM_WRITE = 1,
  SQL_FILESTREAM_READWRITE = 2
} SQL_FILESTREAM_DESIRED_ACCESS;
#define SQL_FILESTREAM_OPEN_FLAG_ASYNC 0x00000001L
#define SQL_FILESTREAM_OPEN_FLAG_NO_BUFFERING 0x00000002L
#define SQL_FILESTREAM_OPEN_FLAG_NO_WRITE_THROUGH 0x00000004L
#define SQL_FILESTREAM_OPEN_FLAG_SEQUENTIAL_SCAN 0x00000008L
#define SQL_FILESTREAM_OPEN_FLAG_RANDOM_ACCESS 0x00000010L
HANDLE __stdcall OpenSqlFilestream(LPCWSTR FilestreamPath, SQL_FILESTREAM_DESIRED_ACCESS DesiredAccess, ULONG OpenOptions, LPBYTE FilestreamTransactionContext, SSIZE_T FilestreamTransactionContextLength, PLARGE_INTEGER AllocationSize);
#define FSCTL_SQL_FILESTREAM_FETCH_OLD_CONTENT CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 2392, METHOD_BUFFERED, FILE_ANY_ACCESS)
#endif

#ifndef _SQLUSERINSTANCE_H_
#define _SQLUSERINSTANCE_H_

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LOCALDB_MAX_SQLCONNECTION_BUFFER_SIZE 260
typedef HRESULT __cdecl FnLocalDBCreateInstance(PCWSTR wszVersion, PCWSTR pInstanceName, DWORD dwFlags);
typedef FnLocalDBCreateInstance* PFnLocalDBCreateInstance;
typedef HRESULT __cdecl FnLocalDBStartInstance(PCWSTR pInstanceName, DWORD dwFlags, LPWSTR wszSqlConnection, LPDWORD lpcchSqlConnection);
typedef FnLocalDBStartInstance* PFnLocalDBStartInstance;
#define LOCALDB_TRUNCATE_ERR_MESSAGE 0x0001L
typedef HRESULT __cdecl FnLocalDBFormatMessage(HRESULT hrLocalDB, DWORD dwFlags, DWORD dwLanguageId, LPWSTR wszMessage, LPDWORD lpcchMessage);
typedef FnLocalDBFormatMessage* PFnLocalDBFormatMessage;
#define LOCALDB_ERROR_NOT_INSTALLED ((HRESULT)0x89C50116L)
FnLocalDBCreateInstance LocalDBCreateInstance;
FnLocalDBStartInstance LocalDBStartInstance;
typedef HRESULT __cdecl FnLocalDBStopInstance(PCWSTR pInstanceName, DWORD dwFlags, ULONG ulTimeout);
typedef FnLocalDBStopInstance* PFnLocalDBStopInstance;
#define LOCALDB_SHUTDOWN_KILL_PROCESS 0x0001L
#define LOCALDB_SHUTDOWN_WITH_NOWAIT 0x0002L
FnLocalDBStopInstance LocalDBStopInstance;
typedef HRESULT __cdecl FnLocalDBDeleteInstance(PCWSTR pInstanceName, DWORD dwFlags);
typedef FnLocalDBDeleteInstance* PFnLocalDBDeleteInstance;
FnLocalDBDeleteInstance LocalDBDeleteInstance;
FnLocalDBFormatMessage LocalDBFormatMessage;
#define MAX_LOCALDB_INSTANCE_NAME_LENGTH 128
#define MAX_LOCALDB_PARENT_INSTANCE_LENGTH MAX_INSTANCE_NAME
typedef WCHAR TLocalDBInstanceName[MAX_LOCALDB_INSTANCE_NAME_LENGTH + 1];
typedef TLocalDBInstanceName* PTLocalDBInstanceName;
typedef HRESULT __cdecl FnLocalDBGetInstances(PTLocalDBInstanceName pInstanceNames, LPDWORD lpdwNumberOfInstances);
typedef FnLocalDBGetInstances* PFnLocalDBGetInstances;
FnLocalDBGetInstances LocalDBGetInstances;
#define MAX_STRING_SID_LENGTH 186

#pragma pack(push,8)

typedef struct _LocalDBInstanceInfo {
  DWORD cbLocalDBInstanceInfoSize;
  TLocalDBInstanceName wszInstanceName;
  BOOL bExists;
  BOOL bConfigurationCorrupted;
  BOOL bIsRunning;
  DWORD dwMajor;
  DWORD dwMinor;
  DWORD dwBuild;
  DWORD dwRevision;
  FILETIME ftLastStartDateUTC;
  WCHAR wszConnection[LOCALDB_MAX_SQLCONNECTION_BUFFER_SIZE];
  BOOL bIsShared;
  TLocalDBInstanceName wszSharedInstanceName;
  WCHAR wszOwnerSID[MAX_STRING_SID_LENGTH + 1];
  BOOL bIsAutomatic;
} LocalDBInstanceInfo;

#pragma pack(pop)

typedef LocalDBInstanceInfo* PLocalDBInstanceInfo;
typedef HRESULT __cdecl FnLocalDBGetInstanceInfo(PCWSTR wszInstanceName, PLocalDBInstanceInfo pInfo, DWORD cbInfo);
typedef FnLocalDBGetInstanceInfo* PFnLocalDBGetInstanceInfo;
FnLocalDBGetInstanceInfo LocalDBGetInstanceInfo;
#define MAX_LOCALDB_VERSION_LENGTH 43
typedef WCHAR TLocalDBVersion[MAX_LOCALDB_VERSION_LENGTH + 1];
typedef TLocalDBVersion* PTLocalDBVersion;
typedef HRESULT __cdecl FnLocalDBGetVersions(PTLocalDBVersion pVersions, LPDWORD lpdwNumberOfVersions);
typedef FnLocalDBGetVersions* PFnLocalDBGetVersions;
FnLocalDBGetVersions LocalDBGetVersions;

#pragma pack(push,8)

typedef struct _LocalDBVersionInfo {
  DWORD cbLocalDBVersionInfoSize;
  TLocalDBVersion wszVersion;
  BOOL bExists;
  DWORD dwMajor;
  DWORD dwMinor;
  DWORD dwBuild;
  DWORD dwRevision;
} LocalDBVersionInfo;

#pragma pack(pop)

typedef LocalDBVersionInfo* PLocalDBVersionInfo;
typedef HRESULT __cdecl FnLocalDBGetVersionInfo(PCWSTR wszVersion, PLocalDBVersionInfo pVersionInfo, DWORD cbVersionInfo);
typedef FnLocalDBGetVersionInfo* PFnLocalDBGetVersionInfo;
FnLocalDBGetVersionInfo LocalDBGetVersionInfo;
typedef HRESULT __cdecl FnLocalDBStartTracing();
typedef FnLocalDBStartTracing* PFnLocalDBStartTracing;
FnLocalDBStartTracing LocalDBStartTracing;
typedef HRESULT __cdecl FnLocalDBStopTracing();
typedef FnLocalDBStopTracing* PFnFnLocalDBStopTracing;
FnLocalDBStopTracing LocalDBStopTracing;
typedef HRESULT __cdecl FnLocalDBShareInstance(PSID pOwnerSID, PCWSTR wszPrivateLocalDBInstanceName, PCWSTR wszSharedName, DWORD dwFlags);
typedef FnLocalDBShareInstance* PFnLocalDBShareInstance;
FnLocalDBShareInstance LocalDBShareInstance;
typedef HRESULT __cdecl FnLocalDBUnshareInstance(PCWSTR pInstanceName, DWORD dwFlags);
typedef FnLocalDBUnshareInstance* PFnLocalDBUnshareInstance;
FnLocalDBUnshareInstance LocalDBUnshareInstance;

#ifdef __cplusplus
} // extern "C"
#endif

#ifdef LOCALDB_DEFINE_PROXY_FUNCTIONS
#define LOCALDB_PROXY(LocalDBFn) static Fn##LocalDBFn* pfn##LocalDBFn = NULL; if (!pfn##LocalDBFn) {HRESULT hr = LocalDBGetPFn(#LocalDBFn, (FARPROC *)&pfn##LocalDBFn); if (FAILED(hr)) return hr;} return (*pfn##LocalDBFn)

typedef struct {
  DWORD dwComponent[2];
  WCHAR wszKeyName[256];
} Version;

static BOOL ParseVersion(Version * pVersion)
{
  pVersion->dwComponent[0] = 0;
  pVersion->dwComponent[1] = 0;
  WCHAR *pwch = pVersion->wszKeyName;

  for (int i = 0; i < 2; i++) {
    LONGLONG llVal = 0;
    BOOL fHaveDigit = FALSE;

    while (*pwch >= L'0' && *pwch <= L'9') {
        llVal = llVal * 10 + (*pwch++ - L'0');
        fHaveDigit = TRUE;
        if (llVal > 0x7fffffff) {
            return FALSE;
        }
    }

    if (!fHaveDigit)
        return FALSE;

    pVersion->dwComponent[i] = (DWORD)llVal;

    if (*pwch == L'\0')
        return TRUE;

    if (*pwch != L'.')
        return FALSE;

    pwch++;
  }
  return FALSE;
}

#include <assert.h>

static HRESULT LocalDBGetPFn(LPCSTR szLocalDBFn, FARPROC *pfnLocalDBFn)
{
  static volatile HMODULE hLocalDBDll = NULL;

  if (!hLocalDBDll) {
    LONG ec;
    HKEY hkeyVersions = NULL;
    HKEY hkeyVersion = NULL;
    Version verHigh = {0};
    Version verCurrent;
    DWORD cchKeyName;
    DWORD dwValueType;
    WCHAR wszLocalDBDll[MAX_PATH+1];
    DWORD cbLocalDBDll = sizeof(wszLocalDBDll) - sizeof(WCHAR);
    HMODULE hLocalDBDllTemp = NULL;

    if (ERROR_SUCCESS != (ec = RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Microsoft SQL Server Local DB\\Installed Versions", 0, KEY_READ, &hkeyVersions)))
      goto Cleanup;

    for (int i = 0; ; i++) {
      cchKeyName = 256;
      if (ERROR_SUCCESS != (ec = RegEnumKeyExW(hkeyVersions, i, verCurrent.wszKeyName, &cchKeyName, 0, NULL, NULL, NULL))) {
        if (ERROR_NO_MORE_ITEMS == ec)
          break;
        goto Cleanup;
      }

      if (!ParseVersion(&verCurrent))
        continue;

      if (verCurrent.dwComponent[0] > verHigh.dwComponent[0] ||
          (verCurrent.dwComponent[0] == verHigh.dwComponent[0] && verCurrent.dwComponent[1] > verHigh.dwComponent[1]))
        verHigh = verCurrent;
    }
    if (!verHigh.wszKeyName[0]) {
      assert(ec == ERROR_NO_MORE_ITEMS);

      ec = ERROR_FILE_NOT_FOUND;
      goto Cleanup;
    }

    if (ERROR_SUCCESS != (ec = RegOpenKeyExW(hkeyVersions, verHigh.wszKeyName, 0, KEY_READ, &hkeyVersion)))
      goto Cleanup;
    if (ERROR_SUCCESS != (ec = RegQueryValueExW(hkeyVersion, L"InstanceAPIPath", NULL, &dwValueType, (PBYTE) wszLocalDBDll, &cbLocalDBDll)))
      goto Cleanup;
    if (dwValueType != REG_SZ) {
      ec = ERROR_INVALID_DATA;
      goto Cleanup;
    }
    wszLocalDBDll[cbLocalDBDll/sizeof(WCHAR)] = L'\0';

    hLocalDBDllTemp = LoadLibraryW(wszLocalDBDll);
    if (NULL == hLocalDBDllTemp) {
      ec = GetLastError();
      goto Cleanup;
    }
    if (NULL == InterlockedCompareExchangePointer((volatile PVOID *)&hLocalDBDll, hLocalDBDllTemp, NULL))
      hLocalDBDllTemp = NULL;
    ec = ERROR_SUCCESS;
Cleanup:
    if (hLocalDBDllTemp)
      FreeLibrary(hLocalDBDllTemp);
    if (hkeyVersion)
      RegCloseKey(hkeyVersion);
    if (hkeyVersions)
      RegCloseKey(hkeyVersions);

    if (ec == ERROR_FILE_NOT_FOUND)
      return LOCALDB_ERROR_NOT_INSTALLED;

    if (ec != ERROR_SUCCESS)
      return HRESULT_FROM_WIN32(ec);
  }

  FARPROC pfn = GetProcAddress(hLocalDBDll, szLocalDBFn);

  if (!pfn)
     return HRESULT_FROM_WIN32(GetLastError());
  *pfnLocalDBFn = pfn;
  return S_OK;
}

HRESULT __cdecl LocalDBCreateInstance(PCWSTR wszVersion, PCWSTR pInstanceName, DWORD dwFlags)
{
  LOCALDB_PROXY(LocalDBCreateInstance)(wszVersion, pInstanceName, dwFlags);
}

HRESULT __cdecl LocalDBStartInstance(PCWSTR pInstanceName, DWORD dwFlags, LPWSTR wszSqlConnection, LPDWORD lpcchSqlConnection)
{
  LOCALDB_PROXY(LocalDBStartInstance)(pInstanceName, dwFlags, wszSqlConnection, lpcchSqlConnection);
}

HRESULT __cdecl LocalDBStopInstance(PCWSTR pInstanceName, DWORD dwFlags, ULONG ulTimeout)
{
  LOCALDB_PROXY(LocalDBStopInstance)(pInstanceName, dwFlags, ulTimeout);
}

HRESULT __cdecl LocalDBDeleteInstance(PCWSTR pInstanceName, DWORD dwFlags)
{
  LOCALDB_PROXY(LocalDBDeleteInstance)(pInstanceName, dwFlags);
}

HRESULT __cdecl LocalDBFormatMessage(HRESULT hrLocalDB, DWORD dwFlags, DWORD dwLanguageId, LPWSTR wszMessage, LPDWORD lpcchMessage)
{
  LOCALDB_PROXY(LocalDBFormatMessage)(hrLocalDB, dwFlags, dwLanguageId, wszMessage, lpcchMessage);
}

HRESULT __cdecl LocalDBGetInstances(PTLocalDBInstanceName pInstanceNames, LPDWORD lpdwNumberOfInstances)
{
  LOCALDB_PROXY(LocalDBGetInstances)(pInstanceNames, lpdwNumberOfInstances);
}

HRESULT __cdecl LocalDBGetInstanceInfo(PCWSTR wszInstanceName, PLocalDBInstanceInfo pInfo, DWORD cbInfo)
{
  LOCALDB_PROXY(LocalDBGetInstanceInfo)(wszInstanceName, pInfo, cbInfo);
}

HRESULT __cdecl LocalDBStartTracing()
{
  LOCALDB_PROXY(LocalDBStartTracing)();
}

HRESULT __cdecl LocalDBStopTracing()
{
  LOCALDB_PROXY(LocalDBStopTracing)();
}

HRESULT __cdecl LocalDBShareInstance(PSID pOwnerSID, PCWSTR wszLocalDBInstancePrivateName, PCWSTR wszSharedName, DWORD dwFlags)
{
  LOCALDB_PROXY(LocalDBShareInstance)(pOwnerSID, wszLocalDBInstancePrivateName, wszSharedName, dwFlags);
}

HRESULT __cdecl LocalDBGetVersions(PTLocalDBVersion pVersions, LPDWORD lpdwNumberOfVersions)
{
  LOCALDB_PROXY(LocalDBGetVersions)(pVersions, lpdwNumberOfVersions);
}

HRESULT __cdecl LocalDBUnshareInstance(PCWSTR pInstanceName, DWORD dwFlags)
{
  LOCALDB_PROXY(LocalDBUnshareInstance)(pInstanceName, dwFlags);
}

HRESULT __cdecl LocalDBGetVersionInfo(PCWSTR wszVersion, PLocalDBVersionInfo pVersionInfo, DWORD cbVersionInfo)
{
  LOCALDB_PROXY(LocalDBGetVersionInfo)(wszVersion, pVersionInfo, cbVersionInfo);
}
#endif
#endif

#ifndef _LOCALDB_MESSAGES_H_
#define _LOCALDB_MESSAGES_H_
#define FACILITY_LOCALDB 0x9C5
#define LOCALDB_SEVERITY_SUCCESS 0x0
#define LOCALDB_SEVERITY_ERROR 0x2
#define LOCALDB_ERROR_CANNOT_CREATE_INSTANCE_FOLDER ((HRESULT)0x89C50100L)
#define LOCALDB_ERROR_INVALID_PARAMETER ((HRESULT)0x89C50101L)
#define LOCALDB_ERROR_INSTANCE_EXISTS_WITH_LOWER_VERSION ((HRESULT)0x89C50102L)
#define LOCALDB_ERROR_CANNOT_GET_USER_PROFILE_FOLDER ((HRESULT)0x89C50103L)
#define LOCALDB_ERROR_INSTANCE_FOLDER_PATH_TOO_LONG ((HRESULT)0x89C50104L)
#define LOCALDB_ERROR_CANNOT_ACCESS_INSTANCE_FOLDER ((HRESULT)0x89C50105L)
#define LOCALDB_ERROR_CANNOT_ACCESS_INSTANCE_REGISTRY ((HRESULT)0x89C50106L)
#define LOCALDB_ERROR_UNKNOWN_INSTANCE ((HRESULT)0x89C50107L)
#define LOCALDB_ERROR_INTERNAL_ERROR ((HRESULT)0x89C50108L)
#define LOCALDB_ERROR_CANNOT_MODIFY_INSTANCE_REGISTRY ((HRESULT)0x89C50109L)
#define LOCALDB_ERROR_SQL_SERVER_STARTUP_FAILED ((HRESULT)0x89C5010AL)
#define LOCALDB_ERROR_INSTANCE_CONFIGURATION_CORRUPT ((HRESULT)0x89C5010BL)
#define LOCALDB_ERROR_CANNOT_CREATE_SQL_PROCESS ((HRESULT)0x89C5010CL)
#define LOCALDB_ERROR_UNKNOWN_VERSION ((HRESULT)0x89C5010DL)
#define LOCALDB_ERROR_UNKNOWN_LANGUAGE_ID ((HRESULT)0x89C5010EL)
#define LOCALDB_ERROR_INSTANCE_STOP_FAILED ((HRESULT)0x89C5010FL)
#define LOCALDB_ERROR_UNKNOWN_ERROR_CODE ((HRESULT)0x89C50110L)
#define LOCALDB_ERROR_VERSION_REQUESTED_NOT_INSTALLED ((HRESULT)0x89C50111L)
#define LOCALDB_ERROR_INSTANCE_BUSY ((HRESULT)0x89C50112L)
#define LOCALDB_ERROR_INVALID_OPERATION ((HRESULT)0x89C50113L)
#define LOCALDB_ERROR_INSUFFICIENT_BUFFER ((HRESULT)0x89C50114L)
#define LOCALDB_ERROR_WAIT_TIMEOUT ((HRESULT)0x89C50115L)
#define LOCALDB_ERROR_XEVENT_FAILED ((HRESULT)0x89C50117L)
#define LOCALDB_ERROR_AUTO_INSTANCE_CREATE_FAILED ((HRESULT)0x89C50118L)
#define LOCALDB_ERROR_SHARED_NAME_TAKEN ((HRESULT)0x89C50119L)
#define LOCALDB_ERROR_CALLER_IS_NOT_OWNER ((HRESULT)0x89C5011AL)
#define LOCALDB_ERROR_INVALID_INSTANCE_NAME ((HRESULT)0x89C5011BL)
#define LOCALDB_ERROR_INSTANCE_ALREADY_SHARED ((HRESULT)0x89C5011CL)
#define LOCALDB_ERROR_INSTANCE_NOT_SHARED ((HRESULT)0x89C5011DL)
#define LOCALDB_ERROR_ADMIN_RIGHTS_REQUIRED ((HRESULT)0x89C5011EL)
#define LOCALDB_ERROR_TOO_MANY_SHARED_INSTANCES ((HRESULT)0x89C5011FL)
#define LOCALDB_ERROR_CANNOT_GET_LOCAL_APP_DATA_PATH ((HRESULT)0x89C50120L)
#define LOCALDB_ERROR_CANNOT_LOAD_RESOURCES ((HRESULT)0x89C50121L)
#define LOCALDB_EDETAIL_DATADIRECTORY_IS_MISSING ((HRESULT)0x89C50200L)
#define LOCALDB_EDETAIL_CANNOT_ACCESS_INSTANCE_FOLDER ((HRESULT)0x89C50201L)
#define LOCALDB_EDETAIL_DATADIRECTORY_IS_TOO_LONG ((HRESULT)0x89C50202L)
#define LOCALDB_EDETAIL_PARENT_INSTANCE_IS_MISSING ((HRESULT)0x89C50203L)
#define LOCALDB_EDETAIL_PARENT_INSTANCE_IS_TOO_LONG ((HRESULT)0x89C50204L)
#define LOCALDB_EDETAIL_DATA_DIRECTORY_INVALID ((HRESULT)0x89C50205L)
#define LOCALDB_EDETAIL_XEVENT_ASSERT ((HRESULT)0x89C50206L)
#define LOCALDB_EDETAIL_XEVENT_ERROR ((HRESULT)0x89C50207L)
#define LOCALDB_EDETAIL_INSTALLATION_CORRUPTED ((HRESULT)0x89C50208L)
#define LOCALDB_EDETAIL_CANNOT_GET_PROGRAM_FILES_LOCATION ((HRESULT)0x89C50209L)
#define LOCALDB_EDETAIL_XEVENT_CANNOT_INITIALIZE ((HRESULT)0x89C5020AL)
#define LOCALDB_EDETAIL_XEVENT_CANNOT_FIND_CONF_FILE ((HRESULT)0x89C5020BL)
#define LOCALDB_EDETAIL_XEVENT_CANNOT_CONFIGURE ((HRESULT)0x89C5020CL)
#define LOCALDB_EDETAIL_XEVENT_CONF_FILE_NAME_TOO_LONG ((HRESULT)0x89C5020DL)
#define LOCALDB_EDETAIL_COINITIALIZEEX_FAILED ((HRESULT)0x89C5020EL)
#define LOCALDB_EDETAIL_PARENT_INSTANCE_VERSION_INVALID ((HRESULT)0x89C5020FL)
#define LOCALDB_EDETAIL_WINAPI_ERROR ((HRESULT)0xC9C50210L)
#define LOCALDB_EDETAIL_UNEXPECTED_RESULT ((HRESULT)0x89C50211L)
#endif

extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0011_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_msoledbsql_0000_0011_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
