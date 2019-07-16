/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __SQLUCODE
#define __SQLUCODE

#ifdef __cplusplus
extern "C" {
#endif

#include <sqlext.h>

#define SQL_WCHAR (-8)
#define SQL_WVARCHAR (-9)
#define SQL_WLONGVARCHAR (-10)
#define SQL_C_WCHAR SQL_WCHAR

#if defined(UNICODE)
#define SQL_C_TCHAR SQL_C_WCHAR
#else
#define SQL_C_TCHAR SQL_C_CHAR
#endif

#define SQL_SQLSTATE_SIZEW 10

#ifndef RC_INVOKED
#ifdef _WIN64
  SQLRETURN SQL_API SQLColAttributeW(SQLHSTMT hstmt,SQLUSMALLINT iCol,SQLUSMALLINT iField,SQLPOINTER pCharAttr,SQLSMALLINT cbCharAttrMax,SQLSMALLINT *pcbCharAttr,SQLLEN *pNumAttr);
#else
  SQLRETURN SQL_API SQLColAttributeW(SQLHSTMT hstmt,SQLUSMALLINT iCol,SQLUSMALLINT iField,SQLPOINTER pCharAttr,SQLSMALLINT cbCharAttrMax,SQLSMALLINT *pcbCharAttr,SQLPOINTER pNumAttr);
#endif
  SQLRETURN SQL_API SQLColAttributesW(SQLHSTMT hstmt,SQLUSMALLINT icol,SQLUSMALLINT fDescType,SQLPOINTER rgbDesc,SQLSMALLINT cbDescMax,SQLSMALLINT *pcbDesc,SQLLEN *pfDesc);
  SQLRETURN SQL_API SQLConnectW(SQLHDBC hdbc,SQLWCHAR *szDSN,SQLSMALLINT cbDSN,SQLWCHAR *szUID,SQLSMALLINT cbUID,SQLWCHAR *szAuthStr,SQLSMALLINT cbAuthStr);
  SQLRETURN SQL_API SQLDescribeColW(SQLHSTMT hstmt,SQLUSMALLINT icol,SQLWCHAR *szColName,SQLSMALLINT cbColNameMax,SQLSMALLINT *pcbColName,SQLSMALLINT *pfSqlType,SQLULEN *pcbColDef,SQLSMALLINT *pibScale,SQLSMALLINT *pfNullable);
  SQLRETURN SQL_API SQLErrorW(SQLHENV henv,SQLHDBC hdbc,SQLHSTMT hstmt,SQLWCHAR *szSqlState,SQLINTEGER *pfNativeError,SQLWCHAR *szErrorMsg,SQLSMALLINT cbErrorMsgMax,SQLSMALLINT *pcbErrorMsg);
  SQLRETURN SQL_API SQLExecDirectW(SQLHSTMT hstmt,SQLWCHAR *szSqlStr,SQLINTEGER cbSqlStr);
  SQLRETURN SQL_API SQLGetConnectAttrW(SQLHDBC hdbc,SQLINTEGER fAttribute,SQLPOINTER rgbValue,SQLINTEGER cbValueMax,SQLINTEGER *pcbValue);
  SQLRETURN SQL_API SQLGetCursorNameW(SQLHSTMT hstmt,SQLWCHAR *szCursor,SQLSMALLINT cbCursorMax,SQLSMALLINT *pcbCursor);
#if (ODBCVER >= 0x0300)
  SQLRETURN SQL_API SQLSetDescFieldW(SQLHDESC DescriptorHandle,SQLSMALLINT RecNumber,SQLSMALLINT FieldIdentifier,SQLPOINTER Value,SQLINTEGER BufferLength);
  SQLRETURN SQL_API SQLGetDescFieldW(SQLHDESC hdesc,SQLSMALLINT iRecord,SQLSMALLINT iField,SQLPOINTER rgbValue,SQLINTEGER cbValueMax,SQLINTEGER *pcbValue);
  SQLRETURN SQL_API SQLGetDescRecW(SQLHDESC hdesc,SQLSMALLINT iRecord,SQLWCHAR *szName,SQLSMALLINT cbNameMax,SQLSMALLINT *pcbName,SQLSMALLINT *pfType,SQLSMALLINT *pfSubType,SQLLEN *pLength,SQLSMALLINT *pPrecision,SQLSMALLINT *pScale,SQLSMALLINT *pNullable);
  SQLRETURN SQL_API SQLGetDiagFieldW(SQLSMALLINT fHandleType,SQLHANDLE handle,SQLSMALLINT iRecord,SQLSMALLINT fDiagField,SQLPOINTER rgbDiagInfo,SQLSMALLINT cbDiagInfoMax,SQLSMALLINT *pcbDiagInfo);
  SQLRETURN SQL_API SQLGetDiagRecW(SQLSMALLINT fHandleType,SQLHANDLE handle,SQLSMALLINT iRecord,SQLWCHAR *szSqlState,SQLINTEGER *pfNativeError,SQLWCHAR *szErrorMsg,SQLSMALLINT cbErrorMsgMax,SQLSMALLINT *pcbErrorMsg);
#endif
  SQLRETURN SQL_API SQLPrepareW(SQLHSTMT hstmt,SQLWCHAR *szSqlStr,SQLINTEGER cbSqlStr);
  SQLRETURN SQL_API SQLSetConnectAttrW(SQLHDBC hdbc,SQLINTEGER fAttribute,SQLPOINTER rgbValue,SQLINTEGER cbValue);
  SQLRETURN SQL_API SQLSetCursorNameW(SQLHSTMT hstmt,SQLWCHAR *szCursor,SQLSMALLINT cbCursor);
  SQLRETURN SQL_API SQLColumnsW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szTableName,SQLSMALLINT cbTableName,SQLWCHAR *szColumnName,SQLSMALLINT cbColumnName);
  SQLRETURN SQL_API SQLGetConnectOptionW(SQLHDBC hdbc,SQLUSMALLINT fOption,SQLPOINTER pvParam);
  SQLRETURN SQL_API SQLGetInfoW(SQLHDBC hdbc,SQLUSMALLINT fInfoType,SQLPOINTER rgbInfoValue,SQLSMALLINT cbInfoValueMax,SQLSMALLINT *pcbInfoValue);
  SQLRETURN SQL_API SQLGetTypeInfoW(SQLHSTMT StatementHandle,SQLSMALLINT DataType);
  SQLRETURN SQL_API SQLSetConnectOptionW(SQLHDBC hdbc,SQLUSMALLINT fOption,SQLULEN vParam);
  SQLRETURN SQL_API SQLSpecialColumnsW(SQLHSTMT hstmt,SQLUSMALLINT fColType,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szTableName,SQLSMALLINT cbTableName,SQLUSMALLINT fScope,SQLUSMALLINT fNullable);
  SQLRETURN SQL_API SQLStatisticsW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szTableName,SQLSMALLINT cbTableName,SQLUSMALLINT fUnique,SQLUSMALLINT fAccuracy);
  SQLRETURN SQL_API SQLTablesW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szTableName,SQLSMALLINT cbTableName,SQLWCHAR *szTableType,SQLSMALLINT cbTableType);
  SQLRETURN SQL_API SQLDataSourcesW(SQLHENV henv,SQLUSMALLINT fDirection,SQLWCHAR *szDSN,SQLSMALLINT cbDSNMax,SQLSMALLINT *pcbDSN,SQLWCHAR *szDescription,SQLSMALLINT cbDescriptionMax,SQLSMALLINT *pcbDescription);
  SQLRETURN SQL_API SQLDriverConnectW(SQLHDBC hdbc,SQLHWND hwnd,SQLWCHAR *szConnStrIn,SQLSMALLINT cbConnStrIn,SQLWCHAR *szConnStrOut,SQLSMALLINT cbConnStrOutMax,SQLSMALLINT *pcbConnStrOut,SQLUSMALLINT fDriverCompletion);
  SQLRETURN SQL_API SQLBrowseConnectW(SQLHDBC hdbc,SQLWCHAR *szConnStrIn,SQLSMALLINT cbConnStrIn,SQLWCHAR *szConnStrOut,SQLSMALLINT cbConnStrOutMax,SQLSMALLINT *pcbConnStrOut);
  SQLRETURN SQL_API SQLColumnPrivilegesW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szTableName,SQLSMALLINT cbTableName,SQLWCHAR *szColumnName,SQLSMALLINT cbColumnName);
  SQLRETURN SQL_API SQLGetStmtAttrW(SQLHSTMT hstmt,SQLINTEGER fAttribute,SQLPOINTER rgbValue,SQLINTEGER cbValueMax,SQLINTEGER *pcbValue);
  SQLRETURN SQL_API SQLSetStmtAttrW(SQLHSTMT hstmt,SQLINTEGER fAttribute,SQLPOINTER rgbValue,SQLINTEGER cbValueMax);
  SQLRETURN SQL_API SQLForeignKeysW(SQLHSTMT hstmt,SQLWCHAR *szPkCatalogName,SQLSMALLINT cbPkCatalogName,SQLWCHAR *szPkSchemaName,SQLSMALLINT cbPkSchemaName,SQLWCHAR *szPkTableName,SQLSMALLINT cbPkTableName,SQLWCHAR *szFkCatalogName,SQLSMALLINT cbFkCatalogName,SQLWCHAR *szFkSchemaName,SQLSMALLINT cbFkSchemaName,SQLWCHAR *szFkTableName,SQLSMALLINT cbFkTableName);
  SQLRETURN SQL_API SQLNativeSqlW(SQLHDBC hdbc,SQLWCHAR *szSqlStrIn,SQLINTEGER cbSqlStrIn,SQLWCHAR *szSqlStr,SQLINTEGER cbSqlStrMax,SQLINTEGER *pcbSqlStr);
  SQLRETURN SQL_API SQLPrimaryKeysW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szTableName,SQLSMALLINT cbTableName);
  SQLRETURN SQL_API SQLProcedureColumnsW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szProcName,SQLSMALLINT cbProcName,SQLWCHAR *szColumnName,SQLSMALLINT cbColumnName);
  SQLRETURN SQL_API SQLProceduresW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szProcName,SQLSMALLINT cbProcName);
  SQLRETURN SQL_API SQLTablePrivilegesW(SQLHSTMT hstmt,SQLWCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLWCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLWCHAR *szTableName,SQLSMALLINT cbTableName);
  SQLRETURN SQL_API SQLDriversW(SQLHENV henv,SQLUSMALLINT fDirection,SQLWCHAR *szDriverDesc,SQLSMALLINT cbDriverDescMax,SQLSMALLINT *pcbDriverDesc,SQLWCHAR *szDriverAttributes,SQLSMALLINT cbDrvrAttrMax,SQLSMALLINT *pcbDrvrAttr);
#ifdef _WIN64
  SQLRETURN SQL_API SQLColAttributeA(SQLHSTMT hstmt,SQLSMALLINT iCol,SQLSMALLINT iField,SQLPOINTER pCharAttr,SQLSMALLINT cbCharAttrMax,SQLSMALLINT *pcbCharAttr,SQLLEN *pNumAttr);
#else
  SQLRETURN SQL_API SQLColAttributeA(SQLHSTMT hstmt,SQLSMALLINT iCol,SQLSMALLINT iField,SQLPOINTER pCharAttr,SQLSMALLINT cbCharAttrMax,SQLSMALLINT *pcbCharAttr,SQLPOINTER pNumAttr);
#endif
  SQLRETURN SQL_API SQLColAttributesA(SQLHSTMT hstmt,SQLUSMALLINT icol,SQLUSMALLINT fDescType,SQLPOINTER rgbDesc,SQLSMALLINT cbDescMax,SQLSMALLINT *pcbDesc,SQLLEN *pfDesc);
  SQLRETURN SQL_API SQLConnectA(SQLHDBC hdbc,SQLCHAR *szDSN,SQLSMALLINT cbDSN,SQLCHAR *szUID,SQLSMALLINT cbUID,SQLCHAR *szAuthStr,SQLSMALLINT cbAuthStr);
  SQLRETURN SQL_API SQLDescribeColA(SQLHSTMT hstmt,SQLUSMALLINT icol,SQLCHAR *szColName,SQLSMALLINT cbColNameMax,SQLSMALLINT *pcbColName,SQLSMALLINT *pfSqlType,SQLUINTEGER *pcbColDef,SQLSMALLINT *pibScale,SQLSMALLINT *pfNullable);
  SQLRETURN SQL_API SQLErrorA(SQLHENV henv,SQLHDBC hdbc,SQLHSTMT hstmt,SQLCHAR *szSqlState,SQLINTEGER *pfNativeError,SQLCHAR *szErrorMsg,SQLSMALLINT cbErrorMsgMax,SQLSMALLINT *pcbErrorMsg);
  SQLRETURN SQL_API SQLExecDirectA(SQLHSTMT hstmt,SQLCHAR *szSqlStr,SQLINTEGER cbSqlStr);
  SQLRETURN SQL_API SQLGetConnectAttrA(SQLHDBC hdbc,SQLINTEGER fAttribute,SQLPOINTER rgbValue,SQLINTEGER cbValueMax,SQLINTEGER *pcbValue);
  SQLRETURN SQL_API SQLGetCursorNameA(SQLHSTMT hstmt,SQLCHAR *szCursor,SQLSMALLINT cbCursorMax,SQLSMALLINT *pcbCursor);
#if (ODBCVER >= 0x0300)
  SQLRETURN SQL_API SQLGetDescFieldA(SQLHDESC hdesc,SQLSMALLINT iRecord,SQLSMALLINT iField,SQLPOINTER rgbValue,SQLINTEGER cbValueMax,SQLINTEGER *pcbValue);
  SQLRETURN SQL_API SQLGetDescRecA(SQLHDESC hdesc,SQLSMALLINT iRecord,SQLCHAR *szName,SQLSMALLINT cbNameMax,SQLSMALLINT *pcbName,SQLSMALLINT *pfType,SQLSMALLINT *pfSubType,SQLINTEGER *pLength,SQLSMALLINT *pPrecision,SQLSMALLINT *pScale,SQLSMALLINT *pNullable);
  SQLRETURN SQL_API SQLGetDiagFieldA(SQLSMALLINT fHandleType,SQLHANDLE handle,SQLSMALLINT iRecord,SQLSMALLINT fDiagField,SQLPOINTER rgbDiagInfo,SQLSMALLINT cbDiagInfoMax,SQLSMALLINT *pcbDiagInfo);
  SQLRETURN SQL_API SQLGetDiagRecA(SQLSMALLINT fHandleType,SQLHANDLE handle,SQLSMALLINT iRecord,SQLCHAR *szSqlState,SQLINTEGER *pfNativeError,SQLCHAR *szErrorMsg,SQLSMALLINT cbErrorMsgMax,SQLSMALLINT *pcbErrorMsg);
  SQLRETURN SQL_API SQLGetStmtAttrA(SQLHSTMT hstmt,SQLINTEGER fAttribute,SQLPOINTER rgbValue,SQLINTEGER cbValueMax,SQLINTEGER *pcbValue);
#endif
  SQLRETURN SQL_API SQLGetTypeInfoA(SQLHSTMT StatementHandle,SQLSMALLINT DataTyoe);
  SQLRETURN SQL_API SQLPrepareA(SQLHSTMT hstmt,SQLCHAR *szSqlStr,SQLINTEGER cbSqlStr);
  SQLRETURN SQL_API SQLSetConnectAttrA(SQLHDBC hdbc,SQLINTEGER fAttribute,SQLPOINTER rgbValue,SQLINTEGER cbValue);
  SQLRETURN SQL_API SQLSetCursorNameA(SQLHSTMT hstmt,SQLCHAR *szCursor,SQLSMALLINT cbCursor);
  SQLRETURN SQL_API SQLColumnsA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szTableName,SQLSMALLINT cbTableName,SQLCHAR *szColumnName,SQLSMALLINT cbColumnName);
  SQLRETURN SQL_API SQLGetConnectOptionA(SQLHDBC hdbc,SQLUSMALLINT fOption,SQLPOINTER pvParam);
  SQLRETURN SQL_API SQLGetInfoA(SQLHDBC hdbc,SQLUSMALLINT fInfoType,SQLPOINTER rgbInfoValue,SQLSMALLINT cbInfoValueMax,SQLSMALLINT *pcbInfoValue);
  SQLRETURN SQL_API SQLGetStmtOptionA(SQLHSTMT hstmt,SQLUSMALLINT fOption,SQLPOINTER pvParam);
  SQLRETURN SQL_API SQLSetConnectOptionA(SQLHDBC hdbc,SQLUSMALLINT fOption,SQLULEN vParam);
  SQLRETURN SQL_API SQLSetStmtOptionA(SQLHSTMT hstmt,SQLUSMALLINT fOption,SQLULEN vParam);
  SQLRETURN SQL_API SQLSpecialColumnsA(SQLHSTMT hstmt,SQLUSMALLINT fColType,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szTableName,SQLSMALLINT cbTableName,SQLUSMALLINT fScope,SQLUSMALLINT fNullable);
  SQLRETURN SQL_API SQLStatisticsA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szTableName,SQLSMALLINT cbTableName,SQLUSMALLINT fUnique,SQLUSMALLINT fAccuracy);
  SQLRETURN SQL_API SQLTablesA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szTableName,SQLSMALLINT cbTableName,SQLCHAR *szTableType,SQLSMALLINT cbTableType);
  SQLRETURN SQL_API SQLDataSourcesA(SQLHENV henv,SQLUSMALLINT fDirection,SQLCHAR *szDSN,SQLSMALLINT cbDSNMax,SQLSMALLINT *pcbDSN,SQLCHAR *szDescription,SQLSMALLINT cbDescriptionMax,SQLSMALLINT *pcbDescription);
  SQLRETURN SQL_API SQLDriverConnectA(SQLHDBC hdbc,SQLHWND hwnd,SQLCHAR *szConnStrIn,SQLSMALLINT cbConnStrIn,SQLCHAR *szConnStrOut,SQLSMALLINT cbConnStrOutMax,SQLSMALLINT *pcbConnStrOut,SQLUSMALLINT fDriverCompletion);
  SQLRETURN SQL_API SQLBrowseConnectA(SQLHDBC hdbc,SQLCHAR *szConnStrIn,SQLSMALLINT cbConnStrIn,SQLCHAR *szConnStrOut,SQLSMALLINT cbConnStrOutMax,SQLSMALLINT *pcbConnStrOut);
  SQLRETURN SQL_API SQLColumnPrivilegesA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szTableName,SQLSMALLINT cbTableName,SQLCHAR *szColumnName,SQLSMALLINT cbColumnName);
  SQLRETURN SQL_API SQLDescribeParamA(SQLHSTMT hstmt,SQLUSMALLINT ipar,SQLSMALLINT *pfSqlType,SQLUINTEGER *pcbParamDef,SQLSMALLINT *pibScale,SQLSMALLINT *pfNullable);
  SQLRETURN SQL_API SQLForeignKeysA(SQLHSTMT hstmt,SQLCHAR *szPkCatalogName,SQLSMALLINT cbPkCatalogName,SQLCHAR *szPkSchemaName,SQLSMALLINT cbPkSchemaName,SQLCHAR *szPkTableName,SQLSMALLINT cbPkTableName,SQLCHAR *szFkCatalogName,SQLSMALLINT cbFkCatalogName,SQLCHAR *szFkSchemaName,SQLSMALLINT cbFkSchemaName,SQLCHAR *szFkTableName,SQLSMALLINT cbFkTableName);
  SQLRETURN SQL_API SQLNativeSqlA(SQLHDBC hdbc,SQLCHAR *szSqlStrIn,SQLINTEGER cbSqlStrIn,SQLCHAR *szSqlStr,SQLINTEGER cbSqlStrMax,SQLINTEGER *pcbSqlStr);
  SQLRETURN SQL_API SQLPrimaryKeysA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szTableName,SQLSMALLINT cbTableName);
  SQLRETURN SQL_API SQLProcedureColumnsA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szProcName,SQLSMALLINT cbProcName,SQLCHAR *szColumnName,SQLSMALLINT cbColumnName);
  SQLRETURN SQL_API SQLProceduresA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szProcName,SQLSMALLINT cbProcName);
  SQLRETURN SQL_API SQLTablePrivilegesA(SQLHSTMT hstmt,SQLCHAR *szCatalogName,SQLSMALLINT cbCatalogName,SQLCHAR *szSchemaName,SQLSMALLINT cbSchemaName,SQLCHAR *szTableName,SQLSMALLINT cbTableName);
  SQLRETURN SQL_API SQLDriversA(SQLHENV henv,SQLUSMALLINT fDirection,SQLCHAR *szDriverDesc,SQLSMALLINT cbDriverDescMax,SQLSMALLINT *pcbDriverDesc,SQLCHAR *szDriverAttributes,SQLSMALLINT cbDrvrAttrMax,SQLSMALLINT *pcbDrvrAttr);

#ifndef SQL_NOUNICODEMAP
#if defined(UNICODE)
#define SQLColAttribute SQLColAttributeW
#define SQLColAttributes SQLColAttributesW
#define SQLConnect SQLConnectW
#define SQLDescribeCol SQLDescribeColW
#define SQLError SQLErrorW
#define SQLExecDirect SQLExecDirectW
#define SQLGetConnectAttr SQLGetConnectAttrW
#define SQLGetCursorName SQLGetCursorNameW
#define SQLGetDescField SQLGetDescFieldW
#define SQLGetDescRec SQLGetDescRecW
#define SQLGetDiagField SQLGetDiagFieldW
#define SQLGetDiagRec SQLGetDiagRecW
#define SQLPrepare SQLPrepareW
#define SQLSetConnectAttr SQLSetConnectAttrW
#define SQLSetCursorName SQLSetCursorNameW
#define SQLSetDescField SQLSetDescFieldW
#define SQLSetStmtAttr SQLSetStmtAttrW
#define SQLGetStmtAttr SQLGetStmtAttrW
#define SQLColumns SQLColumnsW
#define SQLGetConnectOption SQLGetConnectOptionW
#define SQLGetInfo SQLGetInfoW
#define SQLGetTypeInfo SQLGetTypeInfoW
#define SQLSetConnectOption SQLSetConnectOptionW
#define SQLSpecialColumns SQLSpecialColumnsW
#define SQLStatistics SQLStatisticsW
#define SQLTables SQLTablesW
#define SQLDataSources SQLDataSourcesW
#define SQLDriverConnect SQLDriverConnectW
#define SQLBrowseConnect SQLBrowseConnectW
#define SQLColumnPrivileges SQLColumnPrivilegesW
#define SQLForeignKeys SQLForeignKeysW
#define SQLNativeSql SQLNativeSqlW
#define SQLPrimaryKeys SQLPrimaryKeysW
#define SQLProcedureColumns SQLProcedureColumnsW
#define SQLProcedures SQLProceduresW
#define SQLTablePrivileges SQLTablePrivilegesW
#define SQLDrivers SQLDriversW
#endif
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
