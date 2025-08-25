/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __SQLTYPES
#define __SQLTYPES

#ifndef ODBCVER
#define ODBCVER 0x0380
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef EXPORT
#define EXPORT
#endif

#if defined(_ARM_)
#define SQL_API
#else
#define SQL_API __stdcall
#endif

#ifndef RC_INVOKED

  typedef unsigned char SQLCHAR;
#if (ODBCVER >= 0x0300)
  typedef signed char SQLSCHAR;
  typedef unsigned char SQLDATE;
  typedef unsigned char SQLDECIMAL;
  typedef double SQLDOUBLE;
  typedef double SQLFLOAT;
#endif
  typedef __LONG32 SQLINTEGER;
  typedef unsigned __LONG32 SQLUINTEGER;

#ifdef _WIN64
  typedef INT64 SQLLEN;
  typedef UINT64 SQLULEN;
  typedef UINT64 SQLSETPOSIROW;
#else
#define SQLLEN SQLINTEGER
#define SQLULEN SQLUINTEGER
#define SQLSETPOSIROW SQLUSMALLINT
#endif

  typedef SQLULEN SQLROWCOUNT;
  typedef SQLULEN SQLROWSETSIZE;
  typedef SQLULEN SQLTRANSID;
  typedef SQLLEN SQLROWOFFSET;

#if (ODBCVER >= 0x0300)
  typedef unsigned char SQLNUMERIC;
#endif
  typedef void *SQLPOINTER;
#if (ODBCVER >= 0x0300)
  typedef float SQLREAL;
#endif
  typedef short SQLSMALLINT;
  typedef unsigned short SQLUSMALLINT;
#if (ODBCVER >= 0x0300)
  typedef unsigned char SQLTIME;
  typedef unsigned char SQLTIMESTAMP;
  typedef unsigned char SQLVARCHAR;
#endif

  typedef SQLSMALLINT SQLRETURN;

#if (ODBCVER >= 0x0300)
  typedef void *SQLHANDLE;
  typedef SQLHANDLE SQLHENV;
  typedef SQLHANDLE SQLHDBC;
  typedef SQLHANDLE SQLHSTMT;
  typedef SQLHANDLE SQLHDESC;
#else
  typedef void *SQLHENV;
  typedef void *SQLHDBC;
  typedef void *SQLHSTMT;
#endif

#ifndef BASETYPES
#define BASETYPES
  typedef unsigned __LONG32 ULONG;
  typedef ULONG *PULONG;
  typedef unsigned short USHORT;
  typedef USHORT *PUSHORT;
  typedef unsigned char UCHAR;
  typedef UCHAR *PUCHAR;
  typedef char *PSZ;
#endif

  typedef signed char SCHAR;
#if (ODBCVER < 0x0300)
  typedef SCHAR SQLSCHAR;
#endif
  typedef __LONG32 SDWORD;
  typedef short int SWORD;
  typedef unsigned __LONG32 UDWORD;
  typedef unsigned short int UWORD;

  typedef signed __LONG32 SLONG;
  typedef signed short SSHORT;
  typedef double SDOUBLE;
  typedef double LDOUBLE;
  typedef float SFLOAT;
  typedef void *PTR;
  typedef void *HENV;
  typedef void *HDBC;
  typedef void *HSTMT;
  typedef signed short RETCODE;
  typedef HWND SQLHWND;

#ifndef __SQLDATE
#define __SQLDATE

  typedef struct tagDATE_STRUCT {
    SQLSMALLINT year;
    SQLUSMALLINT month;
    SQLUSMALLINT day;
  } DATE_STRUCT;

#if (ODBCVER >= 0x0300)
  typedef DATE_STRUCT SQL_DATE_STRUCT;
#endif

  typedef struct tagTIME_STRUCT {
    SQLUSMALLINT hour;
    SQLUSMALLINT minute;
    SQLUSMALLINT second;
  } TIME_STRUCT;

#if (ODBCVER >= 0x0300)
  typedef TIME_STRUCT SQL_TIME_STRUCT;
#endif

  typedef struct tagTIMESTAMP_STRUCT {
    SQLSMALLINT year;
    SQLUSMALLINT month;
    SQLUSMALLINT day;
    SQLUSMALLINT hour;
    SQLUSMALLINT minute;
    SQLUSMALLINT second;
    SQLUINTEGER fraction;
  } TIMESTAMP_STRUCT;

#if (ODBCVER >= 0x0300)
  typedef TIMESTAMP_STRUCT SQL_TIMESTAMP_STRUCT;
#endif

#if (ODBCVER >= 0x0300)
  typedef enum {
    SQL_IS_YEAR = 1,SQL_IS_MONTH = 2,SQL_IS_DAY = 3,SQL_IS_HOUR = 4,SQL_IS_MINUTE = 5,SQL_IS_SECOND = 6,SQL_IS_YEAR_TO_MONTH = 7,
    SQL_IS_DAY_TO_HOUR = 8,SQL_IS_DAY_TO_MINUTE = 9,SQL_IS_DAY_TO_SECOND = 10,SQL_IS_HOUR_TO_MINUTE = 11,SQL_IS_HOUR_TO_SECOND = 12,
    SQL_IS_MINUTE_TO_SECOND = 13
  } SQLINTERVAL;
#endif

#if (ODBCVER >= 0x0300)
  typedef struct tagSQL_YEAR_MONTH {
    SQLUINTEGER year;
    SQLUINTEGER month;
  } SQL_YEAR_MONTH_STRUCT;

  typedef struct tagSQL_DAY_SECOND {
    SQLUINTEGER day;
    SQLUINTEGER hour;
    SQLUINTEGER minute;
    SQLUINTEGER second;
    SQLUINTEGER fraction;
  } SQL_DAY_SECOND_STRUCT;

  typedef struct tagSQL_INTERVAL_STRUCT {
    SQLINTERVAL interval_type;
    SQLSMALLINT interval_sign;
    union {
      SQL_YEAR_MONTH_STRUCT year_month;
      SQL_DAY_SECOND_STRUCT day_second;
    } intval;
  } SQL_INTERVAL_STRUCT;
#endif
#endif

#if (ODBCVER >= 0x0300)
#define ODBCINT64 /* __MINGW_EXTENSION */ __int64
  __MINGW_EXTENSION typedef ODBCINT64 SQLBIGINT;
  __MINGW_EXTENSION typedef unsigned ODBCINT64 SQLUBIGINT;
#endif

#if (ODBCVER >= 0x0300)
#define SQL_MAX_NUMERIC_LEN 16
  typedef struct tagSQL_NUMERIC_STRUCT {
    SQLCHAR precision;
    SQLSCHAR scale;
    SQLCHAR sign;
    SQLCHAR val[SQL_MAX_NUMERIC_LEN];
  } SQL_NUMERIC_STRUCT;
#endif

#if (ODBCVER >= 0x0350)
#ifdef GUID_DEFINED
  typedef GUID SQLGUID;
#else

  typedef struct tagSQLGUID {
    DWORD Data1;
    WORD Data2;
    WORD Data3;
    BYTE Data4[8 ];
  } SQLGUID;
#endif
#endif

  typedef SQLULEN BOOKMARK;

#ifdef _WCHAR_T_DEFINED
  typedef wchar_t SQLWCHAR;
#else
  typedef unsigned short SQLWCHAR;
#endif

#if defined(UNICODE)
  typedef SQLWCHAR SQLTCHAR;
#else
  typedef SQLCHAR SQLTCHAR;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
